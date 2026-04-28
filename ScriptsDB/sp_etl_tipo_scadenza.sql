USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
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

SET NOEXEC OFF
GO