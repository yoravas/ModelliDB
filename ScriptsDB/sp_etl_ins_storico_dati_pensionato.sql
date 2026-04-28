USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_storico_dati_pensionato]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_storico_dati_pensionato]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_storico_dati_pensionato (@mov_deleghe_id BIGINT,
@codice_fiscale_pensionato CHAR(16),
@nome VARCHAR(50),
@cognome VARCHAR(50),
@sesso CHAR(1),
@cognome_acq VARCHAR(50) = NULL,
@data_nascita DATETIME,
@comune_nascita VARCHAR(100),
@provincia_nascita CHAR(2),
@indirizzo_residenza VARCHAR(250),
@comune_residenza VARCHAR(100),
@provincia_residenza CHAR(2),
@cap_residenza CHAR(5) = NULL,
@stato_residenza VARCHAR(50))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @StartedTran BIT = 0
         ,@SavePointName SYSNAME = N'sp_etl_ins_storico_dati_pensionato_sp';

  BEGIN TRY
    /* =========================
       Validazione MINIMA indispensabile
       (senza MovDelegheID non ha senso)
       ========================= */
    IF @mov_deleghe_id IS NULL
      OR @mov_deleghe_id <= 0
    BEGIN
      RAISERROR ('Parametro @mov_deleghe_id non valido.', 16, 1);
      RETURN;
    END

    /* =========================
       Normalizzazione parametri per evitare crash su NOT NULL
       ========================= */

    -- CF: se NULL/vuoto -> '-'
    SET @codice_fiscale_pensionato =
    CASE
      WHEN NULLIF(LTRIM(RTRIM(@codice_fiscale_pensionato)), '') IS NULL THEN '-'
      ELSE @codice_fiscale_pensionato
    END;

    -- stringhe obbligatorie -> '-'
    SET @nome = COALESCE(NULLIF(LTRIM(RTRIM(@nome)), ''), '-');
    SET @cognome = COALESCE(NULLIF(LTRIM(RTRIM(@cognome)), ''), '-');

    -- sesso: se NULL/vuoto -> '-'
    SET @sesso = COALESCE(NULLIF(LTRIM(RTRIM(@sesso)), ''), '-');

    -- cognome acquisito: se vuoto -> NULL (colonna probabilmente nullable)
    SET @cognome_acq = NULLIF(LTRIM(RTRIM(@cognome_acq)), '');

    -- data nascita: se NULL -> data minima
    -- (minimo “standard ETL” usato da te: 1900-01-01)
    SET @data_nascita = COALESCE(@data_nascita, CONVERT(DATETIME, '19000101', 112));

    -- luogo nascita/residenza: '-' se vuoto
    SET @comune_nascita = COALESCE(NULLIF(LTRIM(RTRIM(@comune_nascita)), ''), '-');
    SET @indirizzo_residenza = COALESCE(NULLIF(LTRIM(RTRIM(@indirizzo_residenza)), ''), '-');
    SET @comune_residenza = COALESCE(NULLIF(LTRIM(RTRIM(@comune_residenza)), ''), '-');
    SET @stato_residenza = COALESCE(NULLIF(LTRIM(RTRIM(@stato_residenza)), ''), '-');

    -- province (CHAR(2)): se vuote -> '--' o '-'? scelgo '--' per rispettare lunghezza 2
    SET @provincia_nascita = COALESCE(NULLIF(LTRIM(RTRIM(@provincia_nascita)), ''), '--');
    SET @provincia_residenza = COALESCE(NULLIF(LTRIM(RTRIM(@provincia_residenza)), ''), '--');

    -- CAP (CHAR(5)): se vuoto -> '-----' o '-'? scelgo '-----' per rispettare lunghezza 5
    SET @cap_residenza = COALESCE(NULLIF(LTRIM(RTRIM(@cap_residenza)), ''), '-----');

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
       Idempotenza
       ========================= */
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_StoricoAngraficaPensionato AS sap WITH (UPDLOCK, HOLDLOCK)
        WHERE sap.MovDelegheID = @mov_deleghe_id)
    BEGIN
      -- Messaggio informativo (non blocca)
      RAISERROR ('Inserisco anagrafica pensionato (MovDelegheID=%I64d, CF=%s)', 10, 1,
      @mov_deleghe_id, @codice_fiscale_pensionato) WITH NOWAIT;

      INSERT INTO dbo.ND_StoricoAngraficaPensionato (MovDelegheID,
      CodiceFiscalePensionato,
      Nome,
      Cognome,
      Sesso,
      CognomeAcquisito,
      DataNascita,
      ComuneNascita,
      ProvinciaNascita,
      IndirizzoResidenza,
      ComuneResidenza,
      ProvinciaResidenza,
      CapResidenza,
      StatoResidenza)
        VALUES (@mov_deleghe_id, @codice_fiscale_pensionato, @nome, @cognome, @sesso, @cognome_acq, @data_nascita, @comune_nascita, @provincia_nascita, @indirizzo_residenza, @comune_residenza, @provincia_residenza, @cap_residenza, @stato_residenza);
    END
    ELSE
    BEGIN
      RAISERROR ('Anagrafica pensionato già presente (MovDelegheID=%I64d)', 10, 1, @mov_deleghe_id) WITH NOWAIT;
    END

    IF @StartedTran = 1
      COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ISNULL(ERROR_PROCEDURE(), N'<n/a>')
           ,@XState INT = XACT_STATE();

    -- Rollback safe
    IF @XState = -1
    BEGIN
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

    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_storico_dati_pensionato - Proc=' + @ErrProc +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: MovDelegheID=' + CONVERT(NVARCHAR(30), @mov_deleghe_id);

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO


SET NOEXEC OFF
GO