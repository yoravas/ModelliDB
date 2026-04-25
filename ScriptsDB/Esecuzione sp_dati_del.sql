USE Deleghe2
GO


DECLARE @RC int
DECLARE @Da date

SET @Da = '2026-01-01'  --'YYYY-MM-DD' 

EXECUTE @RC = dbo.sp_etl_old_to_new_deleghe @Da
GO