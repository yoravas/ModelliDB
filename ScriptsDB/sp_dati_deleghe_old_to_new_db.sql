USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_old_to_new_deleghe]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_old_to_new_deleghe]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_old_to_new_deleghe (@Da DATE)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @CHIAVE_OPERAZIONE VARCHAR(100)
         ,@TIPO_OPERAZIONE VARCHAR(3)
         ,@STORICO VARCHAR(50)
         ,@StartedTran BIT = 0;

  PRINT 'Data nel parametro di ricerca: ' + CONVERT(VARCHAR(10), @Da, 23);
  PRINT '---------------------------------------';

  SELECT
    @STORICO = nen.NomeEnte
  FROM ND_EntiNazionali nen
  WHERE 1 = 1
  AND nen.EntiID = 4;
  PRINT 'Valore ente: ' + @STORICO;
  PRINT '----------------------------------'

  DECLARE curOperazioni CURSOR LOCAL FAST_FORWARD FOR 
  SELECT DISTINCT
    o.CHIAVE_OPERAZIONE
   ,t.TIPO_OPERAZIONE
  FROM dbo.DEL_LOG_OPERAZIONI AS o
  INNER JOIN dbo.DEL_LOG_T32 AS t
    ON t.CHIAVE_OPERAZIONE = o.CHIAVE_OPERAZIONE
  WHERE o.DATA_OPERAZIONE >= @Da
  ORDER BY o.CHIAVE_OPERAZIONE;

  BEGIN
  TRY

    IF @@TRANCOUNT = 0
    BEGIN
      SET @StartedTran = 1;
      BEGIN TRAN;
    END

    SET @CHIAVE_OPERAZIONE = NULL;
    SET @TIPO_OPERAZIONE = NULL;

    OPEN curOperazioni;
    FETCH NEXT FROM curOperazioni INTO @CHIAVE_OPERAZIONE, @TIPO_OPERAZIONE;

    WHILE @@FETCH_STATUS = 0
    BEGIN
    PRINT 'Chiave operazione: ' + ISNULL(@CHIAVE_OPERAZIONE, '(NULL)');
    PRINT 'Tipo operazione: ' + ISNULL(@TIPO_OPERAZIONE, '(NULL)');
    PRINT '---------------------------------------';
    PRINT 'Dati operazione:';
    --*****************Dati Operazione************************
    DECLARE @CODICE_OPERATORE VARCHAR(50)
           ,@DATA_OPERAZIONE DATETIME
           ,@CODICE_FISCALE_PENSIONATO VARCHAR(50)
           ,@COGNOME_PENSIONATO VARCHAR(100)
           ,@NOME_PENSIONATO VARCHAR(100)
           ,@COGNOME_ACQ_PENSIONATO VARCHAR(100)
           ,@DATA_NASCITA_PENSIONATO DATETIME
           ,@DATA_NASCITA_PENSIONATO_DT DATETIME
           ,@SESSO_PENSIONATO CHAR(1)
           ,@SEDE_OPERAZIONE VARCHAR(100)
           ,@IND_RES_PENSIONATO VARCHAR(100)
           ,@CapResidenza VARCHAR(10)
           ,@ComuneResidenza VARCHAR(100)
           ,@PROV_RES VARCHAR(10)
           ,@EsitoWarest VARCHAR(50);

    SET @CODICE_OPERATORE = NULL;
    SET @DATA_OPERAZIONE = NULL;
    SET @CODICE_FISCALE_PENSIONATO = NULL;
    SET @COGNOME_PENSIONATO = NULL;
    SET @NOME_PENSIONATO = NULL;
    SET @COGNOME_ACQ_PENSIONATO = NULL;
    SET @DATA_NASCITA_PENSIONATO = NULL;
    SET @SESSO_PENSIONATO = NULL;
    SET @SEDE_OPERAZIONE = NULL;
    SET @IND_RES_PENSIONATO = NULL;
    SET @CapResidenza = NULL;
    SET @ComuneResidenza = NULL;
    SET @PROV_RES = NULL;
    SET @EsitoWarest = NULL;
    SET @DATA_NASCITA_PENSIONATO_DT = NULL;



    SELECT TOP(1)
      @CODICE_OPERATORE = o.CODICE_OPERATORE
     ,@DATA_OPERAZIONE = o.DATA_OPERAZIONE
     ,@CODICE_FISCALE_PENSIONATO = o.CODICE_FISCALE_PENSIONATO
     ,@COGNOME_PENSIONATO = o.COGNOME_PENSIONATO
     ,@NOME_PENSIONATO = o.NOME_PENSIONATO
     ,@COGNOME_ACQ_PENSIONATO = o.COGNOME_ACQ_PENSIONATO
     ,@DATA_NASCITA_PENSIONATO = TRY_CONVERT(DATETIME, o.DATA_NASCITA_PENSIONATO)
     ,@SESSO_PENSIONATO = o.SESSO_PENSIONATO
     ,@SEDE_OPERAZIONE = o.SEDE_OPERAZIONE
     ,@IND_RES_PENSIONATO = o.IND_RES_PENSIONATO
     ,@CapResidenza = o.CAP
     ,@ComuneResidenza = o.COM_RES
     ,@PROV_RES = o.PROV_RES
     ,@EsitoWarest = o.ESITO_HOST
    FROM [Deleghe2].[dbo].[DEL_LOG_OPERAZIONI] AS o
    WHERE o.CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE;


    SET @DATA_NASCITA_PENSIONATO_DT =
    COALESCE(
    TRY_CONVERT(DATETIME, @DATA_NASCITA_PENSIONATO, 103), -- dd/MM/yyyy
    TRY_CONVERT(DATETIME, @DATA_NASCITA_PENSIONATO, 120), -- yyyy-mm-dd hh:mm:ss
    '19000101'                                -- ✅ data minima scelta
    );




    PRINT 'Codice operatore: ' + @CODICE_OPERATORE;
    --PRINT 'Data operazione: ' + CONVERT(VARCHAR, @DATA_OPERAZIONE, 120);
    --PRINT 'Codice fiscale pensionato: ' + @CODICE_FISCALE_PENSIONATO;
    --PRINT 'Cognome pensionato: ' + @COGNOME_PENSIONATO;
    --PRINT 'Nome pensionato: ' + @NOME_PENSIONATO;
    --PRINT 'Cognome acquisito pensionato: ' + @COGNOME_ACQ_PENSIONATO;
    --PRINT 'Data nascita pensionato: ' + @DATA_NASCITA_PENSIONATO;
    --PRINT 'Sesso pensionato: ' + @SESSO_PENSIONATO;
    PRINT 'Sede operazione: ' + @SEDE_OPERAZIONE;
    --PRINT 'Indirizzo residenza pensionato: ' + @IND_RES_PENSIONATO;
    --PRINT 'CAP residenza pensionato: ' + @CapResidenza;
    --PRINT 'Comune residenza pensionato: ' + @ComuneResidenza;
    --PRINT 'Provincia residenza pensionato: ' + @PROV_RES;
    PRINT 'Esito Warest: ' + @EsitoWarest;
    --**************FINE Dati Operazione***********************
    PRINT '---------------------------------------';
    PRINT 'Dati anagrafici delegato:';
    --*************DATI ANAGRAFICI DELEGATO************************
    DECLARE @CF_CAUNCFCCC1 NCHAR(10)
           ,@NAUNPRG NCHAR(10)
           ,@CODICE_FISCALE_DEL NCHAR(16)
           ,@COGNOME VARCHAR(50)
           ,@NOME VARCHAR(50)
           ,@DATA_NASCITA DATETIME
           ,@data_nascita_dt DATETIME
           ,@ComuneNascita VARCHAR(50)
           ,@PROV_NASCITA NCHAR(10)
           ,@INDIRIZZO_RES VARCHAR(100)
           ,@COMUNE_RES NVARCHAR(100)
           ,@PROV_RES_DELEGATO NCHAR(10)
           ,@CAP_RES NCHAR(10)
           ,@STATO_RES NVARCHAR(100)
           ,@SESSO CHAR(1)
           ,@COGNOME_ACQ VARCHAR(50);

    SET @CF_CAUNCFCCC1 = NULL;
    SET @NAUNPRG = NULL;
    SET @CODICE_FISCALE_DEL = NULL;
    SET @COGNOME = NULL;
    SET @NOME = NULL;
    SET @COGNOME_ACQ = NULL;
    SET @DATA_NASCITA = NULL;
    SET @ComuneNascita = NULL;
    SET @PROV_NASCITA = NULL;
    SET @INDIRIZZO_RES = NULL;
    SET @COMUNE_RES = NULL;
    SET @PROV_RES_DELEGATO = NULL;
    SET @CAP_RES = NULL;
    SET @STATO_RES = NULL;
    SET @SESSO = NULL;
    SET @data_nascita_dt = NULL;

    SELECT
      @CF_CAUNCFCCC1 = dda.CF_CAUNCFCCC1
     ,@NAUNPRG = dda.NAUNPRG
     ,@CODICE_FISCALE_DEL = dda.CODICE_FISCALE_DEL
     ,@COGNOME = dda.COGNOME
     ,@NOME = dda.NOME
     ,@COGNOME_ACQ = dda.COGNOME_ACQ
     ,@DATA_NASCITA = TRY_CONVERT(DATETIME, DATA_NASCITA)
     ,@ComuneNascita = DECO_COMU
     ,@PROV_NASCITA = PROV_NASCITA
     ,@INDIRIZZO_RES = INDIRIZZO_RES
     ,@COMUNE_RES = COMUNE_RES
     ,@PROV_RES_DELEGATO = PROV_RES
     ,@CAP_RES = CAP_RES
     ,@STATO_RES = STATO_RES
     ,@SESSO = SESSO
    FROM dbo.DEL_LOG_DATIDELANAGRAFICI AS dda
    WHERE CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE;


    SET @data_nascita_dt =
    COALESCE(
    TRY_CONVERT(DATETIME, @DATA_NASCITA, 103), -- dd/MM/yyyy
    TRY_CONVERT(DATETIME, @DATA_NASCITA, 120), -- yyyy-mm-dd hh:mm:ss
    '19000101'                                -- ✅ data minima scelta
    );


    --PRINT 'Cognome: ' + @COGNOME;
    --PRINT 'Nome: ' + @NOME;
    --PRINT 'Data nascita: ' + @DATA_NASCITA;
    --PRINT 'Comune nascita: ' + @ComuneNascita;
    --PRINT 'Provincia nascita: ' + @PROV_NASCITA;
    --**************FINE DATI ANAGRAFICI PENSIONATO***********************

    --**************INIZIO DATI T32***************************************
    DECLARE @NCAT NCHAR(3)
           ,@CSED NCHAR(2)
           ,@CZON NCHAR(2)
           ,@NCRT NCHAR(8)
           ,@FAMIGLIA_DELEGA NCHAR(1)
           ,@TIPO_DELEGA NCHAR(1)
           ,@DATA_SCADENZA VARCHAR(10)
           ,@COD_FISC_DELEGATO NCHAR(16)
           ,@TIPO_OPERAZIONE_T32 NCHAR(3);


    SET @NCAT = NULL;
    SET @CSED = NULL;
    SET @CZON = NULL;
    SET @NCRT = NULL;
    SET @FAMIGLIA_DELEGA = NULL;
    SET @TIPO_DELEGA = NULL;
    SET @DATA_SCADENZA = NULL;
    SET @COD_FISC_DELEGATO = NULL;
    SET @TIPO_OPERAZIONE_T32 = NULL;

    SELECT
      @NCAT = dlt.NCAT
     ,@CSED = dlt.CSED
     ,@CZON = dlt.CZON
     ,@NCRT = dlt.NCRT
     ,@FAMIGLIA_DELEGA = dlt.CIDEFAM
     ,@TIPO_DELEGA = dlt.CCMPTIP
     ,@DATA_SCADENZA = dlt.MRVSFAMSCA
     ,@COD_FISC_DELEGATO = dlt.CCDF
     ,@TIPO_OPERAZIONE_T32 = dlt.TIPO_OPERAZIONE
    FROM DEL_LOG_T32 dlt
    WHERE 1 = 1
    AND dlt.CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE
    AND dlt.TIPO_OPERAZIONE = @TIPO_OPERAZIONE

    PRINT 'Lettura della tabella: DEL_LOG_T32';
    --PRINT 'NCAT: ' + @NCAT;

    --**************FINE DATI T32*****************************************

    --****************INIZIO SCRITTURA DATI STORICI***********************

    DECLARE @IDOPERATORE BIGINT;

    PRINT 'Lettura dati operatori per il codice operatore: ' + @CODICE_OPERATORE + ' e per la sede di competenza: ' + @SEDE_OPERAZIONE;

    SET @IDOPERATORE = 0;

    SELECT
      @IDOPERATORE = no.OperatoreID
    FROM ND_Operatori no
    WHERE 1 = 1
    AND no.MatricolaOperatore = @CODICE_OPERATORE
    AND no.SedeCompetenza = @SEDE_OPERAZIONE;

    PRINT 'Valore idOperazione letto: ' + TRY_CONVERT(VARCHAR, @IDOPERATORE);

    DECLARE @ID_TIPO_DELEGA INT
           ,@SET_TIPO_MOVIMENTO_ID INT
           ,@MOV_DELGHE_ID BIGINT
           ,@FK_MOV_DELEGHE_ID BIGINT;

    SET @ID_TIPO_DELEGA = 0;
    SET @SET_TIPO_MOVIMENTO_ID = 0;
    SET @FK_MOV_DELEGHE_ID = NULL;

    SET @ID_TIPO_DELEGA =
    CASE UPPER(LTRIM(RTRIM(@TIPO_DELEGA)))
      WHEN N'A' THEN 1
      WHEN N'D' THEN 2
      WHEN N'L' THEN 3
      WHEN N'U' THEN 4
      WHEN N'X' THEN 5
    END

    PRINT '@ID_TIPO_DELEGA: ' + TRY_CONVERT(VARCHAR, @ID_TIPO_DELEGA);

    SET @SET_TIPO_MOVIMENTO_ID =
    CASE UPPER(LTRIM(RTRIM(@TIPO_OPERAZIONE)))
      WHEN N'INS' THEN 1
      WHEN N'CAN' THEN 2
    END

    PRINT '@SET_TIPO_MOVIMENTO_ID: ' + TRY_CONVERT(VARCHAR, @SET_TIPO_MOVIMENTO_ID);

    IF @IDOPERATORE > 0
    BEGIN
      PRINT 'idOperazione trovato: ' + TRY_CONVERT(VARCHAR, @IDOPERATORE);

      PRINT '@DATA_SCADENZA: ' + TRY_CONVERT(VARCHAR, @DATA_SCADENZA);
      --Qui inserisce i movimenti
      EXEC dbo.sp_etl_tipo_scadenza @DATA_SCADENZA
                                   ,@TIPO_DELEGA
                                   ,@DATA_OPERAZIONE
                                   ,@ID_TIPO_DELEGA
                                   ,@SET_TIPO_MOVIMENTO_ID
                                   ,@IDOPERATORE
                                   ,@FK_MOV_DELEGHE_ID
                                   ,@MOV_DELGHE_ID OUTPUT;

      PRINT '---------------------------------------------'
    END
    ELSE
    BEGIN
      PRINT 'idOperazione non trovato';

      INSERT INTO dbo.ND_Operatori (MatricolaOperatore
      , SedeCompetenza
      , RuoliID
      , EntiID)
        VALUES (@CODICE_OPERATORE -- MatricolaOperatore - varchar(30) NOT NULL           
        , @SEDE_OPERAZIONE -- SedeCompetenza - char(6) NOT NULL
        , 1 -- RuoliID - tinyint NOT NULL
        , 4 -- EntiID - tinyint NOT NULL
        );

      PRINT 'Inserito nuovo operatore';

      SET @IDOPERATORE = SCOPE_IDENTITY();

      PRINT 'IDOperatore creato: ' + TRY_CONVERT(VARCHAR, @IDOPERATORE);

      PRINT '@DATA_SCADENZA: ' + TRY_CONVERT(VARCHAR, @DATA_SCADENZA);
      --Qui inserisce i movimenti
      EXEC dbo.sp_etl_tipo_scadenza @DATA_SCADENZA
                                   ,@TIPO_DELEGA
                                   ,@DATA_OPERAZIONE
                                   ,@ID_TIPO_DELEGA
                                   ,@SET_TIPO_MOVIMENTO_ID
                                   ,@IDOPERATORE
                                   ,@FK_MOV_DELEGHE_ID
                                   ,@MOV_DELGHE_ID OUTPUT;

    END
    --***************INSERIMENTO DATI STORICI DEL DELEGATO****************
    EXEC dbo.sp_etl_ins_storico_dati_delegato @MOV_DELGHE_ID
                                             ,@CF_CAUNCFCCC1
                                             ,@NAUNPRG
                                             ,@CODICE_FISCALE_DEL
                                             ,@NOME
                                             ,@COGNOME
                                             ,@COGNOME_ACQ
                                             ,@SESSO
                                             ,@data_nascita_dt
                                             ,@ComuneNascita
                                             ,@PROV_NASCITA
                                             ,@INDIRIZZO_RES
                                             ,@COMUNE_RES
                                             ,@PROV_RES_DELEGATO
                                             ,@CAP_RES
                                             ,@STATO_RES;
    --***************FINE INSERIMENTO DATI STORICI DEL DELEGATO***********

    --***************INSERIMENTO DATI STORICI PENSIONATO******************
    EXEC dbo.sp_etl_ins_storico_dati_pensionato @MOV_DELGHE_ID
                                               ,@CODICE_FISCALE_PENSIONATO
                                               ,@NOME_PENSIONATO
                                               ,@COGNOME_PENSIONATO
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
    --***************FINE INSERIMENTO DATI STORICI PENSIONATO*************

    --***************INIZIO INSERIMENTO DATI STORICI PRESTAZIONI**********
    EXEC dbo.sp_etl_ins_prestazioni_pensionato @MOV_DELGHE_ID
                                              ,@CHIAVE_OPERAZIONE
                                              ,@DATA_OPERAZIONE;
    --***************FINE INSERIMENTO DATI STORICI PRESTAZIONI************


    --***************FINE SCRITTURA DATI STORICI**************************

    FETCH
    NEXT FROM curOperazioni INTO @CHIAVE_OPERAZIONE, @TIPO_OPERAZIONE;
    END

    CLOSE
    curOperazioni;
    DEALLOCATE curOperazioni;

    IF @StartedTran = 1
      COMMIT TRAN;

  END TRY

  BEGIN
  CATCH

    -- Chiudiamo cursor in caso di errore
    IF CURSOR_STATUS('local', 'curOperazioni') >= -1
    BEGIN
      CLOSE curOperazioni;
      DEALLOCATE curOperazioni;
    END

    IF XACT_STATE() <> 0
      AND @StartedTran = 1
      ROLLBACK TRAN;

    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrSev INT = ERROR_SEVERITY()
           ,@ErrSta INT = ERROR_STATE();

    RAISERROR (@ErrMsg, @ErrSev, @ErrSta);
    RETURN;
  END CATCH
END;
GO

SET NOEXEC OFF
GO