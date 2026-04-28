USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_ND_MovimentazioniDeleghe]
--
GO
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

SET NOEXEC OFF
GO