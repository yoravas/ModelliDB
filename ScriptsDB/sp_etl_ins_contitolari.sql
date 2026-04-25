USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_contitolari]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_contitolari]')
GO
USE Deleghe2
GO

CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_contitolari (@prestazioni_id BIGINT
, @chiave_operazione VARCHAR(300))
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRY
    -- Inserisce tutti i contitolari della chiave operazione per quella prestazione,
    -- evitando duplicati (PensioniID + CodiceFiscale)
    INSERT INTO dbo.ND_Contitolari (CodiceFiscale
    , Cognome
    , CognomeAcquisito
    , Nome
    , DataNascita
    , ComuneNascita
    , ProvinciaNascita
    , PensioniID)
      SELECT
        t.CODICE_FISCALE AS CodiceFiscale
       ,t.COGNOME AS Cognome
       ,t.COGNOME_ACQ AS CognomeAcquisito
       ,t.NOME AS Nome
       ,t.DATA_NASCITA AS DataNascita
       ,t.DECO_COMU AS ComuneNascita
       ,t.PROV_NASCITA AS ProvinciaNascita
       ,@prestazioni_id AS PensioniID
      FROM dbo.DEL_LOG_DATICONTANAGRAFICI AS t
      WHERE t.CHIAVE_OPERAZIONE = @chiave_operazione
      AND NOT EXISTS (SELECT
          1
        FROM dbo.ND_Contitolari AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.PensioniID = @prestazioni_id
        AND c.CodiceFiscale = t.CODICE_FISCALE)
      ORDER BY t.NCAT
      , t.CSEDE
      , t.CZON
      , t.NCRT;

  END TRY
  BEGIN CATCH
    THROW;
  END CATCH
END
GO


SET NOEXEC OFF
GO