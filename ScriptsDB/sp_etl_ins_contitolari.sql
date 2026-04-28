USE Deleghe2
GO

CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_contitolari (@prestazioni_id BIGINT
, @chiave_operazione VARCHAR(300))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_contitolari_sp';

  -- Contesto per messaggi/errore
  DECLARE @CTX_CodiceFiscale VARCHAR(50) = NULL;

  -- Data minima “standard ETL”
  DECLARE @MinDate DATETIME = CONVERT(DATETIME, '19000101', 112);

  -- Variabili di riga (lettura da DEL_LOG_DATICONTANAGRAFICI)
  DECLARE @CodiceFiscale VARCHAR(16)
         ,@Cognome VARCHAR(100)
         ,@CognomeAcquisito VARCHAR(100)
         ,@Nome VARCHAR(100)
         ,@DataNascitaRaw VARCHAR(50)
         ,@DataNascitaDT DATETIME
         ,@ComuneNascita VARCHAR(100)
         ,@ProvinciaNascita VARCHAR(10);

  DECLARE cur_contitolari CURSOR LOCAL FAST_FORWARD FOR SELECT
    t.CODICE_FISCALE
   ,t.COGNOME
   ,t.COGNOME_ACQ
   ,t.NOME
   ,t.DATA_NASCITA      -- spesso è varchar nei log
   ,t.DECO_COMU
   ,t.PROV_NASCITA
  FROM dbo.DEL_LOG_DATICONTANAGRAFICI AS t
  WHERE t.CHIAVE_OPERAZIONE = @chiave_operazione
  ORDER BY t.NCAT, t.CSEDE, t.CZON, t.NCRT;

  BEGIN TRY
    /* =========================
       Validazioni minime
       ========================= */
    IF @prestazioni_id IS NULL
      OR @prestazioni_id <= 0
    BEGIN
      RAISERROR ('Parametro @prestazioni_id non valido.', 16, 1);
      RETURN;
    END

    IF NULLIF(LTRIM(RTRIM(@chiave_operazione)), '') IS NULL
    BEGIN
      RAISERROR ('Parametro @chiave_operazione mancante/non valido.', 16, 1);
      RETURN;
    END

    /* =========================
       Transazione "safe"
       ========================= */
    IF @@TRANCOUNT = 0
    BEGIN
      SET @StartedTran = 1;
      BEGIN TRANSACTION;
    END
    ELSE
    BEGIN
      SAVE TRANSACTION @SavePointName;
    END

    OPEN cur_contitolari;

    FETCH NEXT FROM cur_contitolari INTO
    @CodiceFiscale
    , @Cognome
    , @CognomeAcquisito
    , @Nome
    , @DataNascitaRaw
    , @ComuneNascita
    , @ProvinciaNascita;

    WHILE @@FETCH_STATUS = 0
    BEGIN
    -- contesto corrente (utile nel CATCH)
    SET @CTX_CodiceFiscale = @CodiceFiscale;

    -- se CF mancante, salta (oppure puoi far fallire: a scelta)
    IF NULLIF(LTRIM(RTRIM(@CodiceFiscale)), '') IS NULL
    BEGIN
      RAISERROR ('Contitolare scartato: CodiceFiscale NULL/vuoto (PensioniID=%I64d, CHIAVE_OPERAZIONE=%s).',
      10, 1, @prestazioni_id, @chiave_operazione) WITH NOWAIT;

      FETCH NEXT FROM cur_contitolari INTO
      @CodiceFiscale
      , @Cognome
      , @CognomeAcquisito
      , @Nome
      , @DataNascitaRaw
      , @ComuneNascita
      , @ProvinciaNascita;

      CONTINUE;
    END

    /* =========================
       Validazione DataNascita:
       - prova più formati (103 = dd/MM/yyyy, 120 = yyyy-mm-dd hh:mi:ss)
       - se non convertibile -> data minima
       ========================= */
    SET @DataNascitaDT =
    COALESCE(
    TRY_CONVERT(DATETIME, @DataNascitaRaw, 103),
    TRY_CONVERT(DATETIME, @DataNascitaRaw, 120),
    TRY_CONVERT(DATETIME, @DataNascitaRaw),   -- fallback generico
    @MinDate
    );

    /* =========================
       Insert idempotente
       ========================= */
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_Contitolari AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.PensioniID = @prestazioni_id
        AND c.CodiceFiscale = @CodiceFiscale)
    BEGIN
      INSERT INTO dbo.ND_Contitolari (CodiceFiscale
      , Cognome
      , CognomeAcquisito
      , Nome
      , DataNascita
      , ComuneNascita
      , ProvinciaNascita
      , PensioniID)
        VALUES (@CodiceFiscale, @Cognome, @CognomeAcquisito, @Nome, @DataNascitaDT, @ComuneNascita, @ProvinciaNascita, @prestazioni_id);
    END

    FETCH NEXT FROM cur_contitolari INTO
    @CodiceFiscale
    , @Cognome
    , @CognomeAcquisito
    , @Nome
    , @DataNascitaRaw
    , @ComuneNascita
    , @ProvinciaNascita;
    END

    CLOSE cur_contitolari;
    DEALLOCATE cur_contitolari;

    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ISNULL(ERROR_PROCEDURE(), N'?')
           ,@XState INT = XACT_STATE();

    -- chiusura cursore safe
    DECLARE @cs INT = CURSOR_STATUS('local', 'cur_contitolari');
    IF @cs > -3
    BEGIN
      IF @cs > -1
        CLOSE cur_contitolari;
      DEALLOCATE cur_contitolari;
    END

    -- rollback safe
    IF @XState = -1
    BEGIN
      ROLLBACK TRANSACTION;
    END
    ELSE
    IF @XState = 1
    BEGIN
      IF @StartedTran = 1
        ROLLBACK TRANSACTION;
      ELSE
        ROLLBACK TRANSACTION @SavePointName;
    END

    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_contitolari - Proc=' + @ErrProc +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: PensioniID=' + CONVERT(NVARCHAR(30), @prestazioni_id) +
    N', CHIAVE_OPERAZIONE=' + ISNULL(@chiave_operazione, N'<null>') +
    N', CodiceFiscale=' + ISNULL(@CTX_CodiceFiscale, N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO