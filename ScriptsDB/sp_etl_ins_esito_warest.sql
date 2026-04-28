USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
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

  DECLARE @movimentazione_warest_id BIGINT = NULL
         ,@message NVARCHAR(MAX) = N''
         ,@cod_esito_warest CHAR(3) = ''
         ,@is_successful BIT = 0;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_esito_warest_sp';

  BEGIN TRY
    /* =========================
       Validazioni minime (consigliate)
       ========================= */
    IF @mov_deleghe_id IS NULL
      OR @mov_deleghe_id <= 0
    BEGIN
      RAISERROR ('Parametro @mov_deleghe_id non valido.', 16, 1);
      RETURN;
    END

    IF @operatori_id IS NULL
      OR @operatori_id <= 0
    BEGIN
      RAISERROR ('Parametro @operatori_id non valido.', 16, 1);
      RETURN;
    END

    -- Normalizza input
    SET @message = ISNULL(@esito_new_warest, N'');
    SET @cod_esito_warest = LEFT(@message, 3);

    SET @is_successful =
    CASE
      WHEN @cod_esito_warest = '000' THEN 1
      ELSE 0
    END;

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
       Idempotenza (riduce race condition)
       ========================= */
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_MovWMovD nmwd WITH (UPDLOCK, HOLDLOCK)
        WHERE nmwd.MovDelegheID = @mov_deleghe_id)
    BEGIN
      INSERT INTO dbo.ND_MovimentazioniWarest (PayloadJson,
      IsSuccessful,
      OperatoreID)
        VALUES (N'{}', @is_successful, @operatori_id);

      SET @movimentazione_warest_id = CONVERT(BIGINT, SCOPE_IDENTITY());

      IF @movimentazione_warest_id IS NULL
      BEGIN
        RAISERROR ('SCOPE_IDENTITY() NULL: impossibile recuperare MovimentazioniWarestID (MovDelegheID=%I64d).',
        16, 1, @mov_deleghe_id);
        RETURN;
      END

      INSERT INTO dbo.ND_MovWMovD (MovDelegheID,
      MovimentazioniWarestID)
        VALUES (@mov_deleghe_id, @movimentazione_warest_id);

      INSERT INTO dbo.ND_ResponseWarest (MovimentazioniWarestID,
      Message)
        VALUES (@movimentazione_warest_id, @message);
    END
    -- else: già esiste -> idempotente, non faccio nulla

    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(126) = ISNULL(ERROR_PROCEDURE(), N'?')
           ,@XState INT = XACT_STATE();

    /* =========================
       Rollback "safe"
       ========================= */
    IF @XState = -1
    BEGIN
      -- transazione non committabile -> rollback totale
      ROLLBACK TRANSACTION;
    END
    ELSE
    IF @XState = 1
    BEGIN
      IF @StartedTran = 1
        ROLLBACK TRANSACTION;
      ELSE
        ROLLBACK TRANSACTION @SavePointName;
    END

    /* =========================
       Rilancio con RAISERROR + contesto (NO THROW)
       ========================= */
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_esito_warest - Proc=' + @ErrProc +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: MovDelegheID=' + CONVERT(NVARCHAR(30), @mov_deleghe_id) +
    N', OperatoreID=' + CONVERT(NVARCHAR(30), @operatori_id) +
    N', CodEsito=' + ISNULL(@cod_esito_warest, N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO

SET NOEXEC OFF
GO