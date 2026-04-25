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

  DECLARE @SET_DATA_SCADENZA DATE
         ,@SET_TEMPO_INDETERMINATO BIT
         ,@SET_MAGGIORE_ETA BIT
         ,@ID_MOVIMENTAZIONE BIGINT;


  SET @SET_DATA_SCADENZA = NULL;
  SET @SET_TEMPO_INDETERMINATO = 0;
  SET @SET_MAGGIORE_ETA = 0;

  IF LTRIM(RTRIM(@DATA_SCADENZA)) IS NOT NULL
    AND LTRIM(RTRIM(@DATA_SCADENZA)) <> '999999'
    AND LTRIM(RTRIM(@DATA_SCADENZA)) <> '0'
    AND LTRIM(RTRIM(@DATA_SCADENZA)) <> ''
    AND UPPER(LTRIM(RTRIM(@TIPO_DELEGA))) IN ('A', 'L')
  BEGIN
    PRINT 'Il TIPO_DELEGA CON DATA SCADENZA: ' + @TIPO_DELEGA;

    SET @SET_DATA_SCADENZA = EOMONTH(
    TRY_CONVERT(DATE, @DATA_SCADENZA + '01', 112)  -- 112 = YYYYMMDD
    );

    IF UPPER(LTRIM(RTRIM(@TIPO_DELEGA))) = N'A'
    BEGIN
      SET @SET_TEMPO_INDETERMINATO = 0;
      SET @SET_MAGGIORE_ETA = 0
    END
    ELSE
    IF UPPER(LTRIM(RTRIM(@TIPO_DELEGA))) = N'L'
    BEGIN
      SET @SET_TEMPO_INDETERMINATO = 0;
      SET @SET_MAGGIORE_ETA = 1
    END

    PRINT 'Data scadenza con giorno ultimo del mese: ' + TRY_CONVERT(VARCHAR, @SET_DATA_SCADENZA);

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
    PRINT 'Data di scadenza non valorizzata';

    PRINT 'Il TIPO_DELEGA NO DATA SCADENZA: ' + @TIPO_DELEGA;

    SET @SET_TEMPO_INDETERMINATO = 1;
    SET @SET_MAGGIORE_ETA = 0;

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

  SET @RET_MOVIMENTAZIONE_ID = @ID_MOVIMENTAZIONE;

END
GO

SET NOEXEC OFF
GO