USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_documenti]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_documenti]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_documenti (@mov_deleghe_id BIGINT,
@tipo_delega CHAR(1))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  BEGIN TRY
    PRINT '';
  END TRY
  BEGIN CATCH
    PRINT
    'Error ' + CONVERT(VARCHAR(50), ERROR_NUMBER()) +
    ', Severity ' + CONVERT(VARCHAR(5), ERROR_SEVERITY()) +
    ', State ' + CONVERT(VARCHAR(5), ERROR_STATE()) +
    ', Line ' + CONVERT(VARCHAR(5), ERROR_LINE())

    PRINT ERROR_MESSAGE();

    IF XACT_STATE() <> 0
    BEGIN
      ROLLBACK TRANSACTION
    END
  END CATCH;
END
GO

SET NOEXEC OFF
GO