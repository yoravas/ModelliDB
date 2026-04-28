USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

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

SET NOEXEC OFF
GO