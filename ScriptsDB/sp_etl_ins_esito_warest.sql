USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_esito_warest]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_esito_warest]')
GO

CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_esito_warest (@mov_deleghe_id BIGINT,
@operatori_id BIGINT,
@esito_new_warest NVARCHAR(MAX))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @movimentazione_warest_id BIGINT
         ,@message NVARCHAR(MAX)
         ,@cod_esito_warest CHAR(3)
         ,@is_successful BIT;

  SET @movimentazione_warest_id = NULL;
  SET @message = N'';
  SET @cod_esito_warest = '';
  SET @is_successful = 0;

  DECLARE @startedTran BIT = 0;

  BEGIN TRY
    -- Se siamo già dentro una transazione, non la chiudiamo: usiamo SAVEPOINT
    IF @@TRANCOUNT = 0
    BEGIN
      SET @startedTran = 1;
      BEGIN TRAN;
    END
    ELSE
    BEGIN
      SAVE TRAN sp_etl_ins_esito_warest_Save;
    END

    -- Check esistenza: con lock per evitare race condition (2 sessioni che passano insieme)
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_MovWMovD nmwd WITH (UPDLOCK, HOLDLOCK)
        WHERE nmwd.MovDelegheID = @mov_deleghe_id)
    BEGIN
      SET @cod_esito_warest = LEFT(@esito_new_warest, 3);

      IF @cod_esito_warest = '000'
        SET @is_successful = 1;
      ELSE
        SET @is_successful = 0;

      SET @message = @esito_new_warest;

      INSERT INTO dbo.ND_MovimentazioniWarest (PayloadJson,
      IsSuccessful,
      OperatoreID)
        VALUES (N'{}', @is_successful, @operatori_id);

      SET @movimentazione_warest_id = CONVERT(BIGINT, SCOPE_IDENTITY());

      INSERT INTO dbo.ND_MovWMovD (MovDelegheID,
      MovimentazioniWarestID)
        VALUES (@mov_deleghe_id, @movimentazione_warest_id);

      INSERT INTO dbo.ND_ResponseWarest (MovimentazioniWarestID,
      Message)
        VALUES (@movimentazione_warest_id, @message);
    END

    IF @startedTran = 1
      COMMIT TRAN;
  -- se non l'abbiamo iniziata noi, lasciamo la transazione al chiamante
  END TRY
  BEGIN CATCH

    DECLARE @ErrorNumber INT = ERROR_NUMBER()
           ,@ErrorSeverity INT = ERROR_SEVERITY()
           ,@ErrorState INT = ERROR_STATE()
           ,@ErrorLine INT = ERROR_LINE()
           ,@ErrorProc NVARCHAR(126) = ISNULL(ERROR_PROCEDURE(), N'?')
           ,@ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();

    -- Rollback sicuro: se la transazione è “committable” o “uncommittable”
    IF XACT_STATE() = -1
    BEGIN
      -- transazione irrecuperabile: rollback completo
      ROLLBACK TRAN;
    END
    ELSE
    IF XACT_STATE() = 1
    BEGIN
      IF @startedTran = 1
        ROLLBACK TRAN;
      ELSE
        ROLLBACK TRAN sp_etl_ins_esito_warest_Save;
    END

    -- Rilancio errore (con info proc/linea), mantenendo severity/state originali
    RAISERROR (
    N'Errore %d (Proc=%s, Line=%d): %s',
    @ErrorSeverity,
    @ErrorState,
    @ErrorNumber, @ErrorProc, @ErrorLine, @ErrorMessage
    );

  END CATCH
END

GO

SET NOEXEC OFF
GO