
USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_tipo_scadenza]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_tipo_scadenza]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_tipo_scadenza (@DATA_SCADENZA VARCHAR(10),
@TIPO_DELEGA CHAR(1),
@DATA_OPERAZIONE DATETIME,
@ID_TIPO_DELEGA INT,
@TIPO_MOVIMENTO_ID INT,
@IDOPERATORE BIGINT,
@FK_MOV_DELEGHE_ID BIGINT = NULL,
@RET_MOVIMENTAZIONE_ID BIGINT OUTPUT)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @SET_DATA_SCADENZA DATE
         ,@SET_TEMPO_INDETERMINATO BIT
         ,@SET_MAGGIORE_ETA BIT
         ,@ID_MOVIMENTAZIONE BIGINT;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_tipo_scadenza_sp';

  -- Nuove variabili per validazione
  DECLARE @DATA_SCADENZA_TRIM VARCHAR(10);
  DECLARE @DATA_SCADENZA_DATE DATE;

  -- init
  SET @SET_DATA_SCADENZA = NULL;
  SET @SET_TEMPO_INDETERMINATO = 0;
  SET @SET_MAGGIORE_ETA = 0;
  SET @ID_MOVIMENTAZIONE = NULL;
  SET @RET_MOVIMENTAZIONE_ID = NULL;

  BEGIN TRY
    -- Transazione "safe"
    IF @@TRANCOUNT = 0
    BEGIN
      SET @StartedTran = 1;
      BEGIN TRANSACTION;
    END
    ELSE
    BEGIN
      SAVE TRANSACTION @SavePointName;
    END

    -------------------------------------------------------------------
    -- Normalizzazione e conversione “preventiva”
    -------------------------------------------------------------------
    SET @DATA_SCADENZA_TRIM = NULLIF(LTRIM(RTRIM(@DATA_SCADENZA)), '');

    -- atteso: @DATA_SCADENZA = 'yyyymm' -> aggiungo '01' e converto con 112 (yyyymmdd)
    SET @DATA_SCADENZA_DATE = TRY_CONVERT(DATE, @DATA_SCADENZA_TRIM + '01', 112);

    -------------------------------------------------------------------
    -- IF entra SOLO se: valorizzata + non placeholder + tipo delega valido + convertibile
    -------------------------------------------------------------------
    IF @DATA_SCADENZA_TRIM IS NOT NULL
      AND @DATA_SCADENZA_TRIM NOT IN ('999999', '0')
      AND UPPER(LTRIM(RTRIM(@TIPO_DELEGA))) IN ('A', 'L')
      AND @DATA_SCADENZA_DATE IS NOT NULL
    BEGIN
      PRINT 'Il TIPO_DELEGA CON DATA SCADENZA: ' + @TIPO_DELEGA;

      -- ora è sicuro: @DATA_SCADENZA_DATE è valida
      SET @SET_DATA_SCADENZA = EOMONTH(@DATA_SCADENZA_DATE);

      IF UPPER(LTRIM(RTRIM(@TIPO_DELEGA))) = N'A'
      BEGIN
        SET @SET_TEMPO_INDETERMINATO = 0;
        SET @SET_MAGGIORE_ETA = 0;
      END
      ELSE
      IF UPPER(LTRIM(RTRIM(@TIPO_DELEGA))) = N'L'
      BEGIN
        SET @SET_TEMPO_INDETERMINATO = 0;
        SET @SET_MAGGIORE_ETA = 1;
      END

      PRINT 'Data scadenza con giorno ultimo del mese: ' + CONVERT(VARCHAR(10), @SET_DATA_SCADENZA, 120);

      EXEC dbo.sp_etl_ins_ND_MovimentazioniDeleghe @DATA_OPERAZIONE
                                                  ,@SET_TEMPO_INDETERMINATO
                                                  ,@SET_MAGGIORE_ETA
                                                  ,@SET_DATA_SCADENZA
                                                  ,@ID_TIPO_DELEGA
                                                  ,@TIPO_MOVIMENTO_ID
                                                  ,@IDOPERATORE
                                                  ,@FK_MOV_DELEGHE_ID
                                                  ,@ID_MOVIMENTAZIONE OUTPUT;
    END
    ELSE
    BEGIN
      PRINT 'Data di scadenza non valorizzata o non convertibile -> tempo indeterminato';
      PRINT 'Il TIPO_DELEGA NO DATA SCADENZA: ' + @TIPO_DELEGA;

      SET @SET_TEMPO_INDETERMINATO = 1;
      SET @SET_MAGGIORE_ETA = 0;

      EXEC dbo.sp_etl_ins_ND_MovimentazioniDeleghe @DATA_OPERAZIONE
                                                  ,@SET_TEMPO_INDETERMINATO
                                                  ,@SET_MAGGIORE_ETA
                                                  ,@SET_DATA_SCADENZA
                                                  ,   -- NULL
                                                   @ID_TIPO_DELEGA
                                                  ,@TIPO_MOVIMENTO_ID
                                                  ,@IDOPERATORE
                                                  ,@FK_MOV_DELEGHE_ID
                                                  ,@ID_MOVIMENTAZIONE OUTPUT;
    END

    SET @RET_MOVIMENTAZIONE_ID = @ID_MOVIMENTAZIONE;

    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

    IF XACT_STATE() = -1
      ROLLBACK TRANSACTION;
    ELSE
    IF XACT_STATE() = 1
    BEGIN
      IF @StartedTran = 1
        ROLLBACK TRANSACTION;
      ELSE
        ROLLBACK TRANSACTION @SavePointName;
    END

    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in ' + ISNULL(@ErrProc, N'<procedura sconosciuta>') +
    N' (linea ' + CONVERT(NVARCHAR(10), @ErrLine) + N') - ' +
    N'Err ' + CONVERT(NVARCHAR(10), @ErrNum) + N': ' + @ErrMsg;

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_ND_MovimentazioniDeleghe]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_ND_MovimentazioniDeleghe (@DATA_OPERAZIONE DATETIME,
@TEMPO_INDETERMINATO BIT,
@MAGGIORE_ETA BIT,
@DATA_SCADENZA DATE,
@ID_TIPO_DELEGA INT,
@TIPO_MOVIMENTO_ID INT,
@IDOPERATORE BIGINT,
@FK_MOV_DELEGHE_ID BIGINT = NULL,
@ID_MOVIMENTAZIONE BIGINT OUTPUT)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_ND_MovDeleghe_sp';

  -- (Facoltativo ma utile) init output
  SET @ID_MOVIMENTAZIONE = NULL;

  BEGIN TRY
    /* =========================
       Validazioni minime (facoltative ma consigliate)
       ========================= */
    IF @DATA_OPERAZIONE IS NULL
    BEGIN
      RAISERROR ('Parametro @DATA_OPERAZIONE NULL non ammesso.', 16, 1);
      RETURN;
    END

    IF @ID_TIPO_DELEGA IS NULL
      OR @TIPO_MOVIMENTO_ID IS NULL
      OR @IDOPERATORE IS NULL
    BEGIN
      RAISERROR ('Parametri obbligatori mancanti (@ID_TIPO_DELEGA/@TIPO_MOVIMENTO_ID/@IDOPERATORE).', 16, 1);
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

    /* =========================
       Insert
       ========================= */
    INSERT INTO dbo.ND_MovimentazioniDeleghe (TimeStamp,
    IsTempoIndeterminato,
    IsFinoMaggioreEta,
    DataScadenzaDelega,
    TipoDelegheDelegatiID,
    TipoMovimentoID,
    FK_MovDelegheID,
    OperatoreID)
      VALUES (@DATA_OPERAZIONE, @TEMPO_INDETERMINATO, @MAGGIORE_ETA, @DATA_SCADENZA, @ID_TIPO_DELEGA, @TIPO_MOVIMENTO_ID, @FK_MOV_DELEGHE_ID, @IDOPERATORE);

    -- Se la PK è IDENTITY:
    SET @ID_MOVIMENTAZIONE = CONVERT(BIGINT, SCOPE_IDENTITY());

    IF @ID_MOVIMENTAZIONE IS NULL
    BEGIN
      RAISERROR ('Impossibile recuperare l''ID della movimentazione (SCOPE_IDENTITY() = NULL). Verifica che la PK sia IDENTITY.', 16, 1);
      RETURN;
    END

    /* =========================
       Commit solo se iniziata qui
       ========================= */
    IF @StartedTran = 1
      COMMIT TRANSACTION;

    -- Facoltativo: resultset per debug
    SELECT
      @ID_MOVIMENTAZIONE AS ID_MOVIMENTAZIONE;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

    /* =========================
       Rollback "safe"
       ========================= */
    IF XACT_STATE() = -1
    BEGIN
      -- transazione non committabile -> rollback totale (necessario)
      ROLLBACK TRANSACTION;
    END
    ELSE
    IF XACT_STATE() = 1
    BEGIN
      IF @StartedTran = 1
        ROLLBACK TRANSACTION;
      ELSE
        ROLLBACK TRANSACTION @SavePointName;
    END

    /* =========================
       Rilancio errore con RAISERROR
       ========================= */
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in ' + ISNULL(@ErrProc, N'<procedura sconosciuta>') +
    N' (linea ' + CONVERT(NVARCHAR(10), @ErrLine) + N') - ' +
    N'Err ' + CONVERT(NVARCHAR(10), @ErrNum) + N': ' + @ErrMsg;

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END;
GO
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_storico_dati_delegato]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_storico_dati_delegato (@mov_deleghe_id BIGINT,
@codice_arca CHAR(3),
@progressivo_arca CHAR(10),
@codice_fiscale_delegato CHAR(16),
@nome VARCHAR(50),
@cognome VARCHAR(50),
@cognome_acquisito VARCHAR(50) = NULL,
@sesso CHAR(1),
@data_nascita DATETIME,
@comune_nascita VARCHAR(50),
@provincia_nascita CHAR(2),
@indirizzo_residenza VARCHAR(150),
@comune_residenza VARCHAR(50),
@provincia_residenza VARCHAR(10) = NULL,
@cap_residenza VARCHAR(10) = NULL,     -- FIX: era "nyll"
@stato_residenza VARCHAR(50))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_storico_dati_delegato_sp';

  BEGIN TRY
    /* =========================
       Validazioni minime (consigliate)
       ========================= */
    IF @mov_deleghe_id IS NULL
      OR @mov_deleghe_id <= 0
    BEGIN
      RAISERROR ('Parametro @mov_deleghe_id non valido.', 16, 1);
      RETURN;
    END

    IF NULLIF(LTRIM(RTRIM(@codice_fiscale_delegato)), '') IS NULL
    BEGIN
      RAISERROR ('Parametro @codice_fiscale_delegato mancante/non valido.', 16, 1);
      RETURN;
    END

    /* =========================
       Transazione "safe" (non rompe transazioni esterne)
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

    /* =========================
       Evita race condition: EXISTS con lock
       ========================= */
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_StoricoAnagraficaDelegato sad WITH (UPDLOCK, HOLDLOCK)
        WHERE sad.MovDelegheID = @mov_deleghe_id
        AND sad.CodiceFicaleDelegato = @codice_fiscale_delegato)
    BEGIN
      -- Se vuoi messaggi immediati in job/ETL, meglio RAISERROR severity 10 + NOWAIT
      RAISERROR ('Inserisco anagrafica delegato (MovDelegheID=%I64d, CF=%s)', 10, 1, @mov_deleghe_id, @codice_fiscale_delegato) WITH NOWAIT;

      INSERT INTO dbo.ND_StoricoAnagraficaDelegato (MovDelegheID,
      CodArca,
      ProgressivoArca,
      CodiceFicaleDelegato,
      Nome,
      Cognome,
      CognomeAcquisito,
      Sesso,
      DataNascita,
      ComuneNascita,
      ProvinciaNascita,
      IndirizzoResidenza,
      ComuneResidenza,
      ProvinciaResidenza,
      CapResidenza,
      StatoResidenza)
        VALUES (@mov_deleghe_id, @codice_arca, @progressivo_arca, @codice_fiscale_delegato, @nome, @cognome, @cognome_acquisito, @sesso, @data_nascita, @comune_nascita, @provincia_nascita, @indirizzo_residenza, @comune_residenza, @provincia_residenza, @cap_residenza, @stato_residenza);
    END
    ELSE
    BEGIN
      -- Facoltativo: log che esiste già
      RAISERROR ('Anagrafica delegato già presente (MovDelegheID=%I64d, CF=%s)', 10, 1, @mov_deleghe_id, @codice_fiscale_delegato) WITH NOWAIT;
    END

    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ERROR_PROCEDURE()
           ,@XState INT = XACT_STATE();

    /* Rollback safe */
    IF @XState = -1
    BEGIN
      -- transazione non committabile
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

    /* Rilancio (no THROW) con contesto */
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_storico_dati_delegato - Proc=' + ISNULL(@ErrProc, N'<n/a>') +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: MovDelegheID=' + CONVERT(NVARCHAR(30), @mov_deleghe_id) +
    N', CF=' + ISNULL(@codice_fiscale_delegato, N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_storico_dati_pensionato]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_storico_dati_pensionato
(
    @mov_deleghe_id            BIGINT,
    @codice_fiscale_pensionato CHAR(16),
    @nome                      VARCHAR(50),
    @cognome                   VARCHAR(50),
    @sesso                     CHAR(1),
    @cognome_acq               VARCHAR(50) = NULL,
    @data_nascita              DATETIME,
    @comune_nascita            VARCHAR(100),
    @provincia_nascita         CHAR(2),
    @indirizzo_residenza       VARCHAR(250),
    @comune_residenza          VARCHAR(100),
    @provincia_residenza       CHAR(2),
    @cap_residenza             CHAR(5) = NULL,
    @stato_residenza           VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @StartedTran   BIT = 0,
        @SavePointName SYSNAME = N'sp_etl_ins_storico_dati_pensionato_sp';

    BEGIN TRY
        /* =========================
           Validazioni minime (consigliate)
           ========================= */
        IF @mov_deleghe_id IS NULL OR @mov_deleghe_id <= 0
        BEGIN
            RAISERROR('Parametro @mov_deleghe_id non valido.', 16, 1);
            RETURN;
        END

        IF NULLIF(LTRIM(RTRIM(@codice_fiscale_pensionato)), '') IS NULL
        BEGIN
            RAISERROR('Parametro @codice_fiscale_pensionato mancante/non valido.', 16, 1);
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
		/* =========================
           Normalizzazione campi residenza:
           se NULL o vuoto -> '-'
           ========================= */
        SET @sesso = COALESCE(NULLIF(LTRIM(RTRIM(@sesso)), ''), '-');        
        SET @comune_nascita = COALESCE(NULLIF(LTRIM(RTRIM(@comune_nascita)), ''), '-');        
        SET @provincia_nascita = COALESCE(NULLIF(LTRIM(RTRIM(@provincia_nascita)), ''), '-');
        SET @indirizzo_residenza = COALESCE(NULLIF(LTRIM(RTRIM(@indirizzo_residenza)), ''), '-');
        SET @comune_residenza    = COALESCE(NULLIF(LTRIM(RTRIM(@comune_residenza)), ''), '-');
        SET @provincia_residenza = COALESCE(NULLIF(LTRIM(RTRIM(@provincia_residenza)), ''), '-');
        SET @cap_residenza       = COALESCE(NULLIF(LTRIM(RTRIM(@cap_residenza)), ''), '-');
        SET @stato_residenza     = COALESCE(NULLIF(LTRIM(RTRIM(@stato_residenza)), ''), '-');
        
        /* =========================
           Evita race condition su NOT EXISTS
           ========================= */
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.ND_StoricoAngraficaPensionato AS sap WITH (UPDLOCK, HOLDLOCK)
            WHERE sap.MovDelegheID = @mov_deleghe_id
        )
        BEGIN
            -- Messaggio informativo (non blocca): severity 10
            RAISERROR('Inserisco anagrafica pensionato (MovDelegheID=%I64d, CF=%s)', 10, 1,
                      @mov_deleghe_id, @codice_fiscale_pensionato) WITH NOWAIT;

            INSERT INTO dbo.ND_StoricoAngraficaPensionato
            (
                MovDelegheID,
                CodiceFiscalePensionato,
                Nome,
                Cognome,
                Sesso,
                CognomeAcquisito,
                DataNascita,
                ComuneNascita,
                ProvinciaNascita,
                IndirizzoResidenza,
                ComuneResidenza,
                ProvinciaResidenza,
                CapResidenza,
                StatoResidenza
            )
            VALUES
            (
                @mov_deleghe_id,
                @codice_fiscale_pensionato,
                @nome,
                @cognome,
                @sesso,
                @cognome_acq,
                @data_nascita,
                @comune_nascita,
                @provincia_nascita,
                @indirizzo_residenza,
                @comune_residenza,
                @provincia_residenza,
                @cap_residenza,
                @stato_residenza
            );
        END
        ELSE
        BEGIN
            -- Idempotente: già presente
            RAISERROR('Anagrafica pensionato già presente (MovDelegheID=%I64d)', 10, 1, @mov_deleghe_id) WITH NOWAIT;
        END

        IF @StartedTran = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        DECLARE
            @ErrNum      INT = ERROR_NUMBER(),
            @ErrMsg      NVARCHAR(4000) = ERROR_MESSAGE(),
            @ErrLine     INT = ERROR_LINE(),
            @ErrProc     NVARCHAR(200) = ERROR_PROCEDURE(),
            @XState      INT = XACT_STATE();

        /* =========================
           Rollback "safe"
           ========================= */
        IF @XState = -1
        BEGIN
            -- transazione non committabile
            ROLLBACK TRANSACTION;
        END
        ELSE IF @XState = 1
        BEGIN
            IF @StartedTran = 1
                ROLLBACK TRANSACTION;
            ELSE
                ROLLBACK TRANSACTION @SavePointName;
        END

        /* =========================
           Rilancio con RAISERROR + contesto
           ========================= */
        DECLARE @RaisMsg NVARCHAR(4000) =
            N'Errore in sp_etl_ins_storico_dati_pensionato - Proc=' + ISNULL(@ErrProc, N'<n/a>') +
            N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
            N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
            N' | CTX: MovDelegheID=' + CONVERT(NVARCHAR(30), @mov_deleghe_id) +
            N', CF=' + ISNULL(@codice_fiscale_pensionato, N'<null>');

        RAISERROR(@RaisMsg, 16, 1);
        RETURN;
    END CATCH
END
GO
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
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
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_contitolari]')
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
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_uffici_pagatori]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_uffici_pagatori (@pensioni_id BIGINT,
@abi VARCHAR(10),
@cab VARCHAR(10),
@data_operazione DATETIME)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRY
    -----------------------------------------------------------------
    -- Normalizzazione ABI/CAB:
    -- se solo una delle 2 è vuota -> l'altra resta e quella vuota = '0'
    -- se entrambe vuote -> entrambe = '0'
    -----------------------------------------------------------------
    SET @abi = NULLIF(LTRIM(RTRIM(@abi)), '');
    SET @cab = NULLIF(LTRIM(RTRIM(@cab)), '');

    IF (@abi IS NULL
      AND @cab IS NOT NULL)
      SET @abi = '0';
    IF (@cab IS NULL
      AND @abi IS NOT NULL)
      SET @cab = '0';

    IF (@abi IS NULL
      AND @cab IS NULL)
    BEGIN
      SET @abi = '0';
      SET @cab = '0';
    END

    -----------------------------------------------------------------
    -- Insert idempotente
    -----------------------------------------------------------------
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_UfficioPagatore AS up WITH (UPDLOCK, HOLDLOCK)
        WHERE up.PensioniID = @pensioni_id
        AND up.ABI = @abi
        AND up.CAB = @cab)
    BEGIN
      INSERT INTO dbo.ND_UfficioPagatore (PensioniID,
      ABI,
      CAB,
      TipoUfficioPagatore,
      Descrizione,
      Comune,
      Provincia,
      DataInserimento,
      Indirizzo,
      RagioneSociale,
      CapUfficioPagatore)
        VALUES (@pensioni_id, @abi, @cab, '-', N'-', N'-', '-', @data_operazione, N'-', N'-', '-');
    END
  END TRY
  BEGIN CATCH
    -- Se vuoi restare coerente con il resto (no THROW), posso convertirlo a RAISERROR
    -- Qui mantengo il tuo stile minimale: ma se THROW ti dà problemi, dimmelo.
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ISNULL(ERROR_PROCEDURE(), N'?');

    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_uffici_pagatori - Proc=' + @ErrProc +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: PensioniID=' + CONVERT(NVARCHAR(30), @pensioni_id) +
    N', ABI=' + ISNULL(@abi, N'<null>') +
    N', CAB=' + ISNULL(@cab, N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_esito_warest]')
GO
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_esito_warest (@mov_deleghe_id BIGINT,
@operatori_id BIGINT,
@esito_new_warest NVARCHAR(MAX))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @movimentazione_warest_id BIGINT = NULL
         ,@message NVARCHAR(MAX) = N''
         ,@cod_esito_warest CHAR(3) = ''
         ,@is_successful BIT = 0;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_esito_warest_sp';

  BEGIN TRY
    /* =========================
       Validazioni minime (consigliate)
       ========================= */
    IF @mov_deleghe_id IS NULL
      OR @mov_deleghe_id <= 0
    BEGIN
      RAISERROR ('Parametro @mov_deleghe_id non valido.', 16, 1);
      RETURN;
    END

    IF @operatori_id IS NULL
      OR @operatori_id <= 0
    BEGIN
      RAISERROR ('Parametro @operatori_id non valido.', 16, 1);
      RETURN;
    END

    -- Normalizza input
    SET @message = ISNULL(@esito_new_warest, N'');
    SET @cod_esito_warest = LEFT(@message, 3);

    SET @is_successful =
    CASE
      WHEN @cod_esito_warest = '000' THEN 1
      ELSE 0
    END;

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

    /* =========================
       Idempotenza (riduce race condition)
       ========================= */
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_MovWMovD nmwd WITH (UPDLOCK, HOLDLOCK)
        WHERE nmwd.MovDelegheID = @mov_deleghe_id)
    BEGIN
      INSERT INTO dbo.ND_MovimentazioniWarest (PayloadJson,
      IsSuccessful,
      OperatoreID)
        VALUES (N'{}', @is_successful, @operatori_id);

      SET @movimentazione_warest_id = CONVERT(BIGINT, SCOPE_IDENTITY());

      IF @movimentazione_warest_id IS NULL
      BEGIN
        RAISERROR ('SCOPE_IDENTITY() NULL: impossibile recuperare MovimentazioniWarestID (MovDelegheID=%I64d).',
        16, 1, @mov_deleghe_id);
        RETURN;
      END

      INSERT INTO dbo.ND_MovWMovD (MovDelegheID,
      MovimentazioniWarestID)
        VALUES (@mov_deleghe_id, @movimentazione_warest_id);

      INSERT INTO dbo.ND_ResponseWarest (MovimentazioniWarestID,
      Message)
        VALUES (@movimentazione_warest_id, @message);
    END
    -- else: già esiste -> idempotente, non faccio nulla

    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(126) = ISNULL(ERROR_PROCEDURE(), N'?')
           ,@XState INT = XACT_STATE();

    /* =========================
       Rollback "safe"
       ========================= */
    IF @XState = -1
    BEGIN
      -- transazione non committabile -> rollback totale
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

    /* =========================
       Rilancio con RAISERROR + contesto (NO THROW)
       ========================= */
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_esito_warest - Proc=' + @ErrProc +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: MovDelegheID=' + CONVERT(NVARCHAR(30), @mov_deleghe_id) +
    N', OperatoreID=' + CONVERT(NVARCHAR(30), @operatori_id) +
    N', CodEsito=' + ISNULL(@cod_esito_warest, N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_documenti]')
GO

CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_documenti (@mov_deleghe_id BIGINT,
@tipo_delega_id INT,
@tipo_movimento_id BIGINT,
@codice_operatore VARCHAR(50),
@chiave_operazione VARCHAR(100),
@codice_fiscale_delegato CHAR(16))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @modello_documento_id TINYINT
         ,@codice_tipo_delega CHAR(1)
         ,@desc_movimento VARCHAR(50)
         ,@documento VARBINARY(MAX);

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_documenti_sp';

  BEGIN TRY
    -- =========================
    -- Gestione transazione "safe"
    -- =========================
    IF @@TRANCOUNT = 0
    BEGIN
      SET @StartedTran = 1;
      BEGIN TRANSACTION;
    END
    ELSE
    BEGIN
      SAVE TRANSACTION @SavePointName;
    END

    -- =========================
    -- Lookup dati necessari
    -- =========================
    SELECT
      @codice_tipo_delega = td.CodiceTipoDelega
    FROM dbo.ND_TipoDelega AS td
    WHERE td.TipoDelegaID = @tipo_delega_id;

    IF @codice_tipo_delega IS NULL
    BEGIN
      RAISERROR ('TipoDelega non trovato per TipoDelegaID passato.', 16, 1);
      RETURN;
    END

    SELECT TOP (1)
      @modello_documento_id = nmd.ModelloDocumentoID
    FROM dbo.ND_ModelloDocumento AS nmd
    WHERE nmd.TipoMovimentoID = @tipo_movimento_id
    AND nmd.TipoDelegaID = @tipo_delega_id;

    IF @modello_documento_id IS NULL
    BEGIN
      RAISERROR ('ModelloDocumento non trovato per TipoMovimentoID/TipoDelegaID passati.', 16, 1);
      RETURN;
    END

    SELECT
      @desc_movimento = ntm.DescMovimento
    FROM dbo.ND_TipoMovimento AS ntm
    WHERE ntm.TipoMovimentoID = @tipo_movimento_id;

    IF @desc_movimento IS NULL
    BEGIN
      RAISERROR ('TipoMovimento non trovato per TipoMovimentoID passato.', 16, 1);
      RETURN;
    END

    SELECT
      @documento = s.Pdf
    FROM dbo.DEL_STAMPA AS s
    WHERE s.CODICE_OPERATORE = @codice_operatore
    AND s.CHIAVE_OPERAZIONE = @chiave_operazione
    AND s.CODICE_FISCALE_DEL = @codice_fiscale_delegato
    AND s.TIPO_OPERAZIONE = @desc_movimento
    AND s.TIPO_DELEGA = @codice_tipo_delega;

    PRINT 'Documento - @codice_operatore: ' + @codice_operatore;
    PRINT 'Documento - @chiave_operazione: ' + @chiave_operazione;    
    PRINT 'Documento - @codice_fiscale_delegato: ' + @codice_fiscale_delegato;    
    PRINT 'Documento - @desc_movimento: ' + @desc_movimento;    
    PRINT 'Documento - @codice_tipo_delega: ' + @codice_tipo_delega;

    IF @documento IS NULL
    BEGIN
      --RAISERROR ('Documento PDF non trovato su DEL_STAMPA con i parametri forniti.', 16, 1);
      PRINT 'Documento PDF non trovato su DEL_STAMPA con i parametri forniti.';
      RETURN;
    END

    -- =========================
    -- Insert documento
    -- =========================
    INSERT INTO dbo.ND_Documenti (MovDelegheID,
    NomeFile,
    Estensione,
    Dimensione,
    Contenuto,
    Descrizione,
    TipiMimeID,
    ModelloDocumentoID)
      VALUES (@mov_deleghe_id, N'Documento da archivio storico', N'Pdf', 0, @documento, NULL, 1, @modello_documento_id);

    -- =========================
    -- Commit solo se l'hai iniziata tu
    -- =========================
    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrState INT = ERROR_STATE()
           ,@ErrSeverity INT = ERROR_SEVERITY()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ERROR_PROCEDURE();

    -- Rollback "safe"
    IF XACT_STATE() = -1
    BEGIN
      -- transazione non committabile -> rollback totale
      ROLLBACK TRANSACTION;
    END
    ELSE
    IF XACT_STATE() = 1
    BEGIN
      IF @StartedTran = 1
        ROLLBACK TRANSACTION;
      ELSE
        ROLLBACK TRANSACTION @SavePointName;
    END

    -- Rilancio con RAISERROR (senza THROW)
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in ' + ISNULL(@ErrProc, N'<procedura sconosciuta>') +
    N' (linea ' + CONVERT(NVARCHAR(10), @ErrLine) + N') - ' +
    N'Err ' + CONVERT(NVARCHAR(10), @ErrNum) + N': ' + @ErrMsg;

    -- Metto severity almeno 16 per far fallire la chiamata
    RAISERROR (@RaisMsg, 16, 1);

    RETURN;
  END CATCH
END
GO
----------------------------------------------------
----------------------------------------------------
----------------------------------------------------
PRINT (N'Create or alter procedure [dbo].[sp_etl_old_to_new_deleghe_START]')
GO

CREATE OR ALTER PROCEDURE dbo.sp_etl_old_to_new_deleghe_START (@Da DATE = NULL)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @CHIAVE_OPERAZIONE VARCHAR(100)
         ,@codice_operatore VARCHAR(50)
         ,@tipo_operazione_tab_operazioni VARCHAR(50)
         ,@anno_mese_competenza VARCHAR(6)
         ,@data_operazione DATETIME
         ,@codice_fiscale_pensionato NCHAR(16)
         ,@chiave_arca NCHAR(3)
         ,@progressivo_arca NCHAR(10)
         ,@cognome_pensionato VARCHAR(50)
         ,@nome_pensionato VARCHAR(50)
         ,@data_nascita_pensionato VARCHAR(10)
         ,@esito_host VARCHAR(200)
         ,@codice_fiscale_delegato NCHAR(16)
         ,@cognome_delegato VARCHAR(50)
         ,@nome_delegato VARCHAR(50)
         ,@tipo_delega CHAR(1)
         ,@data_scadenza_delega NCHAR(6)
         ,@TIPO_OPERAZIONE VARCHAR(3)
         ,@STORICO VARCHAR(50)
         ,@data_da_reale DATE;

  -------------------------------------------------------------------------
  -- BATCHING: dimensione batch e contatori
  -------------------------------------------------------------------------
  DECLARE @BatchSize INT = 500;
  DECLARE @BatchCount INT = 0;
  DECLARE @TranOpen BIT = 0;

  -- Contesto utile in caso di errore (dove eri arrivato)
  DECLARE @CTX_CHIAVE_OPERAZIONE VARCHAR(100) = NULL;
  DECLARE @CTX_TIPO_OPERAZIONE VARCHAR(3) = NULL;
  DECLARE @CTX_DATA_OPERAZIONE DATETIME = NULL;

  SET @data_da_reale = ISNULL(@Da, CONVERT(DATE, '19000101'));

  PRINT 'Data nel parametro di ricerca: ' + CONVERT(VARCHAR(10), @data_da_reale, 23);
  PRINT '---------------------------------------';

  SELECT
    @STORICO = nen.NomeEnte
  FROM ND_EntiNazionali nen
  WHERE nen.EntiID = 4;

  PRINT 'Valore ente: ' + @STORICO;
  PRINT '----------------------------------';

  DECLARE curOperazioni CURSOR LOCAL FAST_FORWARD FOR SELECT
    o.CHIAVE_OPERAZIONE
   ,o.CODICE_OPERATORE
   ,o.TIPO_OPERAZIONE AS tipoOperazioniTabOperazioni
   ,o.ANNOMESE_COMPETENZA
   ,o.DATA_OPERAZIONE
   ,o.CODICE_FISCALE_PENSIONATO
   ,RTRIM(o.CF_CAUNCFCCC1) AS ChiaveArca
   ,RTRIM(o.NAUNPRG) AS ProgressivoArca
   ,o.COGNOME_PENSIONATO
   ,o.NOME_PENSIONATO
   ,o.DATA_NASCITA_PENSIONATO
   ,o.ESITO_HOST
   ,dda.CODICE_FISCALE_DEL
   ,dda.COGNOME AS CognomeDelegato
   ,dda.NOME AS NomeDelegato
   ,t32.CCMPTIP AS TipoDelega
   ,t32.MRVSFAMSCA AS DataScadenzaDelega
   ,t32.TIPO_OPERAZIONE AS TipoOperazione
  FROM dbo.DEL_LOG_OPERAZIONI o
  INNER JOIN dbo.DEL_LOG_DATIDELANAGRAFICI dda
    ON o.CHIAVE_OPERAZIONE = dda.CHIAVE_OPERAZIONE
  INNER JOIN dbo.DEL_LOG_T32 t32
    ON t32.CHIAVE_OPERAZIONE = dda.CHIAVE_OPERAZIONE
  WHERE o.DATA_OPERAZIONE >= @data_da_reale
  GROUP BY o.CHIAVE_OPERAZIONE
          ,o.CODICE_OPERATORE
          ,o.TIPO_OPERAZIONE
          ,o.ANNOMESE_COMPETENZA
          ,o.DATA_OPERAZIONE
          ,o.CODICE_FISCALE_PENSIONATO
          ,o.CF_CAUNCFCCC1
          ,o.NAUNPRG
          ,o.COGNOME_PENSIONATO
          ,o.NOME_PENSIONATO
          ,o.DATA_NASCITA_PENSIONATO
          ,o.ESITO_HOST
          ,dda.CODICE_FISCALE_DEL
          ,dda.COGNOME
          ,dda.NOME
          ,t32.CCMPTIP
          ,t32.MRVSFAMSCA
          ,t32.TIPO_OPERAZIONE
  ORDER BY o.DATA_OPERAZIONE DESC;

  BEGIN TRY
    OPEN curOperazioni;

    FETCH NEXT FROM curOperazioni INTO
    @CHIAVE_OPERAZIONE,
    @codice_operatore,
    @tipo_operazione_tab_operazioni,
    @anno_mese_competenza,
    @data_operazione,
    @codice_fiscale_pensionato,
    @chiave_arca,
    @progressivo_arca,
    @cognome_pensionato,
    @nome_pensionato,
    @data_nascita_pensionato,
    @esito_host,
    @codice_fiscale_delegato,
    @cognome_delegato,
    @nome_delegato,
    @tipo_delega,
    @data_scadenza_delega,
    @TIPO_OPERAZIONE;

    WHILE @@FETCH_STATUS = 0
    BEGIN
    -------------------------------------------------------------------
    -- Apre transazione per il batch se non è già aperta
    -------------------------------------------------------------------
    IF @TranOpen = 0
    BEGIN
      BEGIN TRAN;
      SET @TranOpen = 1;
      SET @BatchCount = 0;
    END

    -- Aggiorno contesto (utile se esplode una SP figlia)
    SET @CTX_CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE;
    SET @CTX_TIPO_OPERAZIONE = @TIPO_OPERAZIONE;
    SET @CTX_DATA_OPERAZIONE = @data_operazione;

    -------------------------------------------------------------------
    -- Inizio elaborazione
    -------------------------------------------------------------------
    PRINT 'Chiave operazione: ' + ISNULL(@CHIAVE_OPERAZIONE, '(NULL)');
    PRINT 'Tipo operazione: ' + ISNULL(@TIPO_OPERAZIONE, '(NULL)');

    DECLARE @COGNOME_ACQ_PENSIONATO VARCHAR(100)
           ,@DATA_NASCITA_PENSIONATO_DT DATETIME
           ,@SESSO_PENSIONATO CHAR(1)
           ,@SEDE_OPERAZIONE VARCHAR(100)
           ,@IND_RES_PENSIONATO VARCHAR(100)
           ,@CapResidenza VARCHAR(10)
           ,@ComuneResidenza VARCHAR(100)
           ,@PROV_RES VARCHAR(10);

    SET @COGNOME_ACQ_PENSIONATO = NULL;
    SET @SESSO_PENSIONATO = NULL;
    SET @SEDE_OPERAZIONE = NULL;
    SET @IND_RES_PENSIONATO = NULL;
    SET @CapResidenza = NULL;
    SET @ComuneResidenza = NULL;
    SET @PROV_RES = NULL;

    SELECT TOP (1)
      @COGNOME_ACQ_PENSIONATO = o.COGNOME_ACQ_PENSIONATO
     ,@SESSO_PENSIONATO = o.SESSO_PENSIONATO
     ,@SEDE_OPERAZIONE = o.SEDE_OPERAZIONE
     ,@IND_RES_PENSIONATO = o.IND_RES_PENSIONATO
     ,@CapResidenza = o.CAP
     ,@ComuneResidenza = o.COM_RES
     ,@PROV_RES = o.PROV_RES
    FROM dbo.DEL_LOG_OPERAZIONI o
    WHERE o.CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE
    AND o.CODICE_OPERATORE = @codice_operatore
    AND o.DATA_OPERAZIONE = @data_operazione
    AND o.CODICE_FISCALE_PENSIONATO = @codice_fiscale_pensionato;

    SET @DATA_NASCITA_PENSIONATO_DT =
    COALESCE(
    TRY_CONVERT(DATETIME, @data_nascita_pensionato, 103),
    TRY_CONVERT(DATETIME, @data_nascita_pensionato, 120),
    CONVERT(DATETIME, '19000101')
    );

    -------------------------------------------------------------------
    -- Delegato
    -------------------------------------------------------------------
    DECLARE @CF_CAUNCFCCC1_delegato NCHAR(10)
           ,@NAUNPRG_delegato NCHAR(10)
           ,@DATA_NASCITA_delegato_raw VARCHAR(50)
           ,@data_nascita_delegato_dt DATETIME
           ,@ComuneNascita_delegato VARCHAR(50)
           ,@PROV_NASCITA_delegato NCHAR(10)
           ,@INDIRIZZO_RES_delegato VARCHAR(100)
           ,@COMUNE_RES_delegato NVARCHAR(100)
           ,@PROV_RES_DELEGATO NCHAR(10)
           ,@CAP_RES_delegato NCHAR(10)
           ,@STATO_RES_delegato NVARCHAR(100)
           ,@SESSO_delegato CHAR(1)
           ,@COGNOME_ACQ_delegato VARCHAR(50);

    SELECT TOP (1)
      @CF_CAUNCFCCC1_delegato = dda.CF_CAUNCFCCC1
     ,@NAUNPRG_delegato = dda.NAUNPRG
     ,@COGNOME_ACQ_delegato = dda.COGNOME_ACQ
     ,@DATA_NASCITA_delegato_raw = dda.DATA_NASCITA
     ,@ComuneNascita_delegato = dda.DECO_COMU
     ,@PROV_NASCITA_delegato = dda.PROV_NASCITA
     ,@INDIRIZZO_RES_delegato = dda.INDIRIZZO_RES
     ,@COMUNE_RES_delegato = dda.COMUNE_RES
     ,@PROV_RES_DELEGATO = dda.PROV_RES
     ,@CAP_RES_delegato = dda.CAP_RES
     ,@STATO_RES_delegato = dda.STATO_RES
     ,@SESSO_delegato = dda.SESSO
    FROM dbo.DEL_LOG_DATIDELANAGRAFICI dda
    WHERE dda.CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE
    AND dda.CODICE_FISCALE_DEL = @codice_fiscale_delegato;

    SET @data_nascita_delegato_dt =
    COALESCE(
    TRY_CONVERT(DATETIME, @DATA_NASCITA_delegato_raw, 103),
    TRY_CONVERT(DATETIME, @DATA_NASCITA_delegato_raw, 120),
    CONVERT(DATETIME, '19000101')
    );

    -------------------------------------------------------------------
    -- Lettura operatore + inserimento movimenti + chiamate SP figlie
    -------------------------------------------------------------------
    DECLARE @IDOPERATORE BIGINT = 0;

    SELECT
      @IDOPERATORE = no.OperatoreID
    FROM ND_Operatori no
    WHERE no.MatricolaOperatore = @codice_operatore
    AND no.SedeCompetenza = @SEDE_OPERAZIONE;

    DECLARE @ID_TIPO_DELEGA INT
           ,@SET_TIPO_MOVIMENTO_ID INT
           ,@MOV_DELGHE_ID BIGINT
           ,@FK_MOV_DELEGHE_ID BIGINT;

    SET @FK_MOV_DELEGHE_ID = NULL;

    SET @ID_TIPO_DELEGA =
    CASE UPPER(LTRIM(RTRIM(@tipo_delega)))
      WHEN N'A' THEN 1
      WHEN N'D' THEN 2
      WHEN N'L' THEN 3
      WHEN N'U' THEN 4
      WHEN N'X' THEN 5
    END;

    SET @SET_TIPO_MOVIMENTO_ID =
    CASE UPPER(LTRIM(RTRIM(@TIPO_OPERAZIONE)))
      WHEN N'INS' THEN 1
      WHEN N'CAN' THEN 2
    END;

    -- (Opzionale ma utile) blocco "input incoerente"
    IF @ID_TIPO_DELEGA IS NULL
    BEGIN
      RAISERROR ('Tipo delega non gestito: %s (CHIAVE_OPERAZIONE=%s).', 16, 1, @tipo_delega, @CHIAVE_OPERAZIONE);
      RETURN;
    END

    IF @SET_TIPO_MOVIMENTO_ID IS NULL
    BEGIN
      RAISERROR ('Tipo operazione non gestito: %s (CHIAVE_OPERAZIONE=%s).', 16, 1, @TIPO_OPERAZIONE, @CHIAVE_OPERAZIONE);
      RETURN;
    END

    IF @IDOPERATORE <= 0
    BEGIN
      INSERT INTO dbo.ND_Operatori (MatricolaOperatore, SedeCompetenza, RuoliID, EntiID)
        VALUES (@codice_operatore, @SEDE_OPERAZIONE, 1, 4);

      SET @IDOPERATORE = CONVERT(BIGINT, SCOPE_IDENTITY());
    END

    EXEC dbo.sp_etl_tipo_scadenza @data_scadenza_delega
                                 ,@tipo_delega
                                 ,@data_operazione
                                 ,@ID_TIPO_DELEGA
                                 ,@SET_TIPO_MOVIMENTO_ID
                                 ,@IDOPERATORE
                                 ,@FK_MOV_DELEGHE_ID
                                 ,@MOV_DELGHE_ID OUTPUT;

    PRINT '@MOV_DELGHE_ID output da sp_etl_tipo_scadenza: ' + TRY_CONVERT(VARCHAR, @MOV_DELGHE_ID);

    EXEC dbo.sp_etl_ins_storico_dati_delegato @MOV_DELGHE_ID
                                             ,@CF_CAUNCFCCC1_delegato
                                             ,@NAUNPRG_delegato
                                             ,@codice_fiscale_delegato
                                             ,@nome_delegato
                                             ,@cognome_delegato
                                             ,@COGNOME_ACQ_delegato
                                             ,@SESSO_delegato
                                             ,@data_nascita_delegato_dt
                                             ,@ComuneNascita_delegato
                                             ,@PROV_NASCITA_delegato
                                             ,@INDIRIZZO_RES_delegato
                                             ,@COMUNE_RES_delegato
                                             ,@PROV_RES_DELEGATO
                                             ,@CAP_RES_delegato
                                             ,@STATO_RES_delegato;

    EXEC dbo.sp_etl_ins_storico_dati_pensionato @MOV_DELGHE_ID
                                               ,@codice_fiscale_pensionato
                                               ,@nome_pensionato
                                               ,@cognome_pensionato
                                               ,@SESSO_PENSIONATO
                                               ,@COGNOME_ACQ_PENSIONATO
                                               ,@DATA_NASCITA_PENSIONATO_DT
                                               ,'-'
                                               ,'-'
                                               ,@IND_RES_PENSIONATO
                                               ,@ComuneResidenza
                                               ,@PROV_RES
                                               ,@CapResidenza
                                               ,'-';

    EXEC dbo.sp_etl_ins_prestazioni_pensionato @MOV_DELGHE_ID
                                              ,@CHIAVE_OPERAZIONE
                                              ,@data_operazione;

    EXEC dbo.sp_etl_ins_esito_warest @MOV_DELGHE_ID
                                    ,@IDOPERATORE
                                    ,@esito_host;

    EXEC dbo.sp_etl_ins_documenti @MOV_DELGHE_ID
                                 ,@ID_TIPO_DELEGA
                                 ,@SET_TIPO_MOVIMENTO_ID
                                 ,@codice_operatore
                                 ,@CHIAVE_OPERAZIONE
                                 ,@codice_fiscale_delegato;

    -------------------------------------------------------------------
    -- Incrementa contatore batch e commit a soglia
    -------------------------------------------------------------------
    SET @BatchCount += 1;

    IF @BatchCount >= @BatchSize
    BEGIN
      COMMIT TRAN;
      SET @TranOpen = 0;
      SET @BatchCount = 0;
    END

    FETCH NEXT FROM curOperazioni INTO
    @CHIAVE_OPERAZIONE,
    @codice_operatore,
    @tipo_operazione_tab_operazioni,
    @anno_mese_competenza,
    @data_operazione,
    @codice_fiscale_pensionato,
    @chiave_arca,
    @progressivo_arca,
    @cognome_pensionato,
    @nome_pensionato,
    @data_nascita_pensionato,
    @esito_host,
    @codice_fiscale_delegato,
    @cognome_delegato,
    @nome_delegato,
    @tipo_delega,
    @data_scadenza_delega,
    @TIPO_OPERAZIONE;
    END

    CLOSE curOperazioni;
    DEALLOCATE curOperazioni;

    IF @TranOpen = 1
    BEGIN
      COMMIT TRAN;
      SET @TranOpen = 0;
    END
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ERROR_PROCEDURE()
           ,@XState INT = XACT_STATE();

    -- 1) Chiudi/dealloca cursore in modo sicuro
    DECLARE @cs INT = CURSOR_STATUS('local', 'curOperazioni');
    IF @cs > -3
    BEGIN
      IF @cs > -1  -- open
        CLOSE curOperazioni;
      DEALLOCATE curOperazioni;
    END

    -- 2) Rollback transazione batch (se esiste)
    IF @XState = -1
    BEGIN
      -- transazione non committabile
      ROLLBACK TRAN;
      SET @TranOpen = 0;
    END
    ELSE
    IF @XState = 1
    BEGIN
      IF @TranOpen = 1
        AND @@TRANCOUNT > 0
      BEGIN
        ROLLBACK TRAN;
        SET @TranOpen = 0;
      END
    END

    -- 3) Messaggio dettagliato al chiamante (NO THROW)
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'ERRORE ETL sp_etl_old_to_new_deleghe_START - ' +
    N'Proc=' + ISNULL(@ErrProc, N'<n/a>') +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: CHIAVE_OPERAZIONE=' + ISNULL(@CTX_CHIAVE_OPERAZIONE, N'<null>') +
    N', TIPO_OPERAZIONE=' + ISNULL(@CTX_TIPO_OPERAZIONE, N'<null>') +
    N', DATA_OPERAZIONE=' + ISNULL(CONVERT(NVARCHAR(19), @CTX_DATA_OPERAZIONE, 120), N'<null>') +
    N', BatchCount=' + CONVERT(NVARCHAR(10), @BatchCount);

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END;
GO
SET NOEXEC OFF
GO
