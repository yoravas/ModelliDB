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

  DECLARE @movimentazione_warest_id BIGINT, @message NVARCHAR(MAX), @cod_esito_warest CHAR(3), @is_successful BIT;

  SET @movimentazione_warest_id = NULL;
  SET @message = '';
  SET @cod_esito_warest = '';
  SET @is_successful = 0;

  IF NOT EXISTS (SELECT
        1
      FROM dbo.ND_MovWMovD nmwd
      WHERE 1 = 1
      AND nmwd.MovDelegheID = @mov_deleghe_id)
  BEGIN

    SET @cod_esito_warest = LEFT(@esito_new_warest, 3);

    IF @cod_esito_warest = '000' BEGIN  
    	SET @is_successful = 1;
    END
    ELSE
    BEGIN
    	SET @is_successful = 0;
    END

    SET @message = @esito_new_warest;

    INSERT INTO dbo.ND_MovimentazioniWarest (PayloadJson
    , IsSuccessful
    , OperatoreID)
      VALUES (N'{}' -- PayloadJson - nvarchar(max) NOT NULL
      , @is_successful -- IsSuccessful - bit NOT NULL
      , @operatori_id -- OperatoreID - bigint
      );

    SET @movimentazione_warest_id = CONVERT(BIGINT, SCOPE_IDENTITY());

    INSERT INTO dbo.ND_MovWMovD (MovDelegheID
    , MovimentazioniWarestID)
      VALUES (@mov_deleghe_id -- MovDelegheID - bigint NOT NULL
      , @movimentazione_warest_id -- MovimentazioniWarestID - bigint NOT NULL
      );

    INSERT INTO dbo.ND_ResponseWarest (MovimentazioniWarestID
    , Message)
      VALUES (@movimentazione_warest_id -- MovimentazioniWarestID - bigint NOT NULL
      , @message -- Message - nvarchar(max)
      );

  END

END
GO

SET NOEXEC OFF
GO