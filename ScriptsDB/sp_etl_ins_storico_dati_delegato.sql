USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_storico_dati_delegato]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_storico_dati_delegato]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_storico_dati_delegato (@mov_deleghe_id BIGINT,
@codice_arca CHAR(3),
@progressivo_arca CHAR(10),
@codice_fiscale_delegato CHAR(16),
@nome VARCHAR(50),
@cognome VARCHAR(50),
@cognome_acquisito VARCHAR(50) = NULL,
@sesso CHAR(1),
@data_nascita DATETIME,
@comune_nascita VARCHAR(50),
@provincia_nascita CHAR(2),
@indirizzo_residenza VARCHAR(150),
@comune_residenza VARCHAR(50),
@provincia_residenza VARCHAR(10) = NULL,
@cap_residenza VARCHAR(10) = NULL,     -- FIX: era "nyll"
@stato_residenza VARCHAR(50))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_storico_dati_delegato_sp';

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

    IF NULLIF(LTRIM(RTRIM(@codice_fiscale_delegato)), '') IS NULL
    BEGIN
      RAISERROR ('Parametro @codice_fiscale_delegato mancante/non valido.', 16, 1);
      RETURN;
    END

    /* =========================
       Transazione "safe" (non rompe transazioni esterne)
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
       Evita race condition: EXISTS con lock
       ========================= */
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_StoricoAnagraficaDelegato sad WITH (UPDLOCK, HOLDLOCK)
        WHERE sad.MovDelegheID = @mov_deleghe_id
        AND sad.CodiceFicaleDelegato = @codice_fiscale_delegato)
    BEGIN
      -- Se vuoi messaggi immediati in job/ETL, meglio RAISERROR severity 10 + NOWAIT
      RAISERROR ('Inserisco anagrafica delegato (MovDelegheID=%I64d, CF=%s)', 10, 1, @mov_deleghe_id, @codice_fiscale_delegato) WITH NOWAIT;

      INSERT INTO dbo.ND_StoricoAnagraficaDelegato (MovDelegheID,
      CodArca,
      ProgressivoArca,
      CodiceFicaleDelegato,
      Nome,
      Cognome,
      CognomeAcquisito,
      Sesso,
      DataNascita,
      ComuneNascita,
      ProvinciaNascita,
      IndirizzoResidenza,
      ComuneResidenza,
      ProvinciaResidenza,
      CapResidenza,
      StatoResidenza)
        VALUES (@mov_deleghe_id, @codice_arca, @progressivo_arca, @codice_fiscale_delegato, @nome, @cognome, @cognome_acquisito, @sesso, @data_nascita, @comune_nascita, @provincia_nascita, @indirizzo_residenza, @comune_residenza, @provincia_residenza, @cap_residenza, @stato_residenza);
    END
    ELSE
    BEGIN
      -- Facoltativo: log che esiste già
      RAISERROR ('Anagrafica delegato già presente (MovDelegheID=%I64d, CF=%s)', 10, 1, @mov_deleghe_id, @codice_fiscale_delegato) WITH NOWAIT;
    END

    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ERROR_PROCEDURE()
           ,@XState INT = XACT_STATE();

    /* Rollback safe */
    IF @XState = -1
    BEGIN
      -- transazione non committabile
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

    /* Rilancio (no THROW) con contesto */
    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_storico_dati_delegato - Proc=' + ISNULL(@ErrProc, N'<n/a>') +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: MovDelegheID=' + CONVERT(NVARCHAR(30), @mov_deleghe_id) +
    N', CF=' + ISNULL(@codice_fiscale_delegato, N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO

SET NOEXEC OFF
GO