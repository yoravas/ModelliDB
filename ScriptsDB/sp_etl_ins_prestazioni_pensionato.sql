USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_prestazioni_pensionato]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_prestazioni_pensionato]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_prestazioni_pensionato (@mov_deleghe_id BIGINT
, @chiave_operazione NVARCHAR(500)
, @data_operazione DATETIME)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @categoriaPrestazione CHAR(3)
         ,@descrizione_categoria_prestazione NVARCHAR(MAX)
         ,@sede_prestazione CHAR(4)
         ,@certificato_prestazione CHAR(8)
         ,@codice_tipo_componente CHAR(1)
         ,@is_intestatario BIT
         ,@codice_identificativo_familiare CHAR(1)
         ,@data_decorrenza CHAR(10)       -- NON convertiamo DATA_DEC
         ,@ufficio_pagatore_abi VARCHAR(10)
         ,@ufficio_pagatore_cab VARCHAR(10)
         ,@codice_modalita_pagamento CHAR(1)
         ,@prestazione_id BIGINT;

  -- contesto utile per errore (riga corrente)
  DECLARE @CTX_cat CHAR(3) = NULL
         ,@CTX_sede CHAR(4) = NULL
         ,@CTX_cert CHAR(8) = NULL;

  -- costanti / default
  SET @codice_identificativo_familiare = NULL;

  -- gestione transazionale "safe"
  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_prestazioni_pensionato_sp';

  DECLARE cur_pensioni CURSOR LOCAL FAST_FORWARD FOR SELECT
    p.NCAT
   ,(p.CSED + p.CZON)
   ,p.NCRT
   ,p.CCMPTIP
   ,p.FTITPRN
   ,p.DESC_CAT_PENS
   ,p.DATA_DEC
   ,p.UFFPAGABI
   ,p.UFFPAGCAB
  FROM dbo.DEL_LOG_PENSIONI AS p
  WHERE p.CHIAVE_OPERAZIONE = @chiave_operazione
  ORDER BY p.NCAT
  , p.CSED
  , p.CZON
  , p.NCRT;

  BEGIN TRY
    /* =========================
       Validazioni minime
       ========================= */
    IF @mov_deleghe_id IS NULL
      OR @mov_deleghe_id <= 0
    BEGIN
      RAISERROR ('Parametro @mov_deleghe_id non valido.', 16, 1);
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

    OPEN cur_pensioni;

    FETCH NEXT FROM cur_pensioni INTO
    @categoriaPrestazione
    , @sede_prestazione
    , @certificato_prestazione
    , @codice_tipo_componente
    , @is_intestatario
    , @descrizione_categoria_prestazione
    , @data_decorrenza
    , @ufficio_pagatore_abi
    , @ufficio_pagatore_cab;

    WHILE @@FETCH_STATUS = 0
    BEGIN
    -- aggiorna contesto (se esplode una SP figlia sai su quale record eri)
    SET @CTX_cat = @categoriaPrestazione;
    SET @CTX_sede = @sede_prestazione;
    SET @CTX_cert = @certificato_prestazione;

    -- reset per iterazione
    SET @codice_modalita_pagamento = 'N';

    IF NULLIF(LTRIM(RTRIM(@ufficio_pagatore_abi)), '') IS NOT NULL
      SET @codice_modalita_pagamento = 'C';

    -- idempotenza / concorrenza (riduce race condition)
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_StoricoPrestazioni AS sp WITH (UPDLOCK, HOLDLOCK)
        WHERE sp.MovDelegheID = @mov_deleghe_id
        AND sp.CategoriaPrestazione = @categoriaPrestazione
        AND sp.SedePrestazione = @sede_prestazione
        AND sp.CertificatoPrestazione = @certificato_prestazione)
    BEGIN
      INSERT INTO dbo.ND_StoricoPrestazioni (CategoriaPrestazione
      , DescrizioneCategoriaPrestazione
      , SedePrestazione
      , CertificatoPrestazione
      , CodiceTipoComponente
      , CodiceIdentificativoFamiliare
      , DataDecorrenza
      , CodiceModalitaPagamento
      , DescModalitaPagamento
      , MovDelegheID
      , Intestatario)
        VALUES (@categoriaPrestazione, @descrizione_categoria_prestazione, @sede_prestazione, @certificato_prestazione, @codice_tipo_componente, @codice_identificativo_familiare, @data_decorrenza, @codice_modalita_pagamento, CASE WHEN @codice_modalita_pagamento = 'C' THEN 'Conto Corrente' ELSE 'Non definita' END, @mov_deleghe_id, @is_intestatario);

      SET @prestazione_id = CONVERT(BIGINT, SCOPE_IDENTITY());

      -- Se per qualche motivo non è identity/trigger, intercettiamo subito
      IF @prestazione_id IS NULL
      BEGIN
        RAISERROR ('SCOPE_IDENTITY() NULL: impossibile recuperare prestazione_id (MovDelegheID=%I64d, CAT=%s, SEDE=%s, CERT=%s).',
        16, 1, @mov_deleghe_id, @categoriaPrestazione, @sede_prestazione, @certificato_prestazione);
        RETURN;
      END

      EXEC dbo.sp_etl_ins_uffici_pagatori @prestazione_id
                                         ,@ufficio_pagatore_abi
                                         ,@ufficio_pagatore_cab
                                         ,@data_operazione;

      EXEC dbo.sp_etl_ins_contitolari @prestazione_id
                                     ,@chiave_operazione;
    END

    SET @prestazione_id = NULL;

    FETCH NEXT FROM cur_pensioni INTO
    @categoriaPrestazione
    , @sede_prestazione
    , @certificato_prestazione
    , @codice_tipo_componente
    , @is_intestatario
    , @descrizione_categoria_prestazione
    , @data_decorrenza
    , @ufficio_pagatore_abi
    , @ufficio_pagatore_cab;
    END

    -- chiusura cursore
    CLOSE cur_pensioni;
    DEALLOCATE cur_pensioni;

    -- commit solo se iniziata qui
    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ERROR_PROCEDURE()
           ,@XState INT = XACT_STATE();

    -- chiusura/deallocazione sicura del cursore
    DECLARE @cs INT = CURSOR_STATUS('local', 'cur_pensioni');
    IF @cs > -3
    BEGIN
      IF @cs > -1
        CLOSE cur_pensioni;
      DEALLOCATE cur_pensioni;
    END

    -- rollback "safe"
    IF @XState = -1
    BEGIN
      -- transazione non committabile: serve rollback totale (SQL Server non consente partial rollback)
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

    -- rilancio con RAISERROR + contesto
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_prestazioni_pensionato - Proc=' + ISNULL(@ErrProc, N'<n/a>') +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: MovDelegheID=' + CONVERT(NVARCHAR(30), @mov_deleghe_id) +
    N', CHIAVE_OPERAZIONE=' + ISNULL(@chiave_operazione, N'<null>') +
    N', CAT=' + ISNULL(@CTX_cat, N'<null>') +
    N', SEDE=' + ISNULL(@CTX_sede, N'<null>') +
    N', CERT=' + ISNULL(@CTX_cert, N'<null>') +
    N', prestazione_id=' + ISNULL(CONVERT(NVARCHAR(30), @prestazione_id), N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END;
GO

SET NOEXEC OFF
GO