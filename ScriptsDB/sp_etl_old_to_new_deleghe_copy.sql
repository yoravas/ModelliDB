USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_old_to_new_deleghe_copy]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_old_to_new_deleghe_copy]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_old_to_new_deleghe_copy (@Da DATE)
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
         ,@STORICO VARCHAR(50);

  -------------------------------------------------------------------------
  -- BATCHING: dimensione batch e contatori
  -------------------------------------------------------------------------
  DECLARE @BatchSize INT = 500;      -- <<< limite commit
  DECLARE @BatchCount INT = 0;       -- righe processate nel batch corrente
  DECLARE @TranOpen BIT = 0;         -- indica se abbiamo una tran aperta

  PRINT 'Data nel parametro di ricerca: ' + CONVERT(VARCHAR(10), @Da, 23);
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
  WHERE o.DATA_OPERAZIONE >= @Da
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

    -- ✅ Data minima se non convertibile
    SET @DATA_NASCITA_PENSIONATO_DT =
    COALESCE(
    TRY_CONVERT(DATETIME, @data_nascita_pensionato, 103),
    TRY_CONVERT(DATETIME, @data_nascita_pensionato, 120),
    '19000101'
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
     ,     -- <- prendo raw stringa
      @ComuneNascita_delegato = dda.DECO_COMU
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

    -- ✅ Converti in sicurezza + data minima
    SET @data_nascita_delegato_dt =
    COALESCE(
    TRY_CONVERT(DATETIME, @DATA_NASCITA_delegato_raw, 103),
    TRY_CONVERT(DATETIME, @DATA_NASCITA_delegato_raw, 120),
    '19000101'
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

    SET @ID_TIPO_DELEGA = 0;
    SET @SET_TIPO_MOVIMENTO_ID = 0;
    SET @MOV_DELGHE_ID = 0;
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

    IF @IDOPERATORE <= 0
    BEGIN
      INSERT INTO dbo.ND_Operatori (MatricolaOperatore, SedeCompetenza, RuoliID, EntiID)
        VALUES (@codice_operatore, @SEDE_OPERAZIONE, 1, 4);

      SET @IDOPERATORE = CONVERT(BIGINT, SCOPE_IDENTITY());
    END

    -------------------------------------------------------------------------------------------------
    -- Gestione della scadenza con la tipologia della delega ed inserimento delle movimentazioni
    -------------------------------------------------------------------------------------------------

    EXEC dbo.sp_etl_tipo_scadenza @data_scadenza_delega
                                 ,@tipo_delega
                                 ,@data_operazione
                                 ,@ID_TIPO_DELEGA
                                 ,@SET_TIPO_MOVIMENTO_ID
                                 ,@IDOPERATORE
                                 ,@FK_MOV_DELEGHE_ID
                                 ,@MOV_DELGHE_ID OUTPUT;

    PRINT '@MOV_DELGHE_ID output da sp_etl_tipo_scadenza: ' + TRY_CONVERT(VARCHAR, @MOV_DELGHE_ID);

    -------------------------------------------------------------------------------------------------
    -- Storico del delegato
    -------------------------------------------------------------------------------------------------

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

    -------------------------------------------------------------------------------------------------
    -- Storico dati del pensionato
    -------------------------------------------------------------------------------------------------

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

    -------------------------------------------------------------------------------------------------
    -- Prestazioni del pensionato
    -------------------------------------------------------------------------------------------------

    EXEC dbo.sp_etl_ins_prestazioni_pensionato @MOV_DELGHE_ID
                                              ,@CHIAVE_OPERAZIONE
                                              ,@data_operazione;

    ------------------------------------------------------------------------------------------------
    -- Esito nuovo servizio che sostituisce warest
    ------------------------------------------------------------------------------------------------

    EXEC dbo.sp_etl_ins_esito_warest @MOV_DELGHE_ID
                                    ,@IDOPERATORE
                                    ,@esito_host;

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

    -- Commit ultimo batch rimasto aperto
    IF @TranOpen = 1
    BEGIN
      COMMIT TRAN;
      SET @TranOpen = 0;
    END
  END TRY
  BEGIN CATCH
    -- chiusura cursor se necessario
    IF CURSOR_STATUS('local', 'curOperazioni') >= -1
    BEGIN
      CLOSE curOperazioni;
      DEALLOCATE curOperazioni;
    END

    IF XACT_STATE() <> 0
      ROLLBACK TRAN;

    THROW;
  END CATCH
END;
GO

SET NOEXEC OFF
GO