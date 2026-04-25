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
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_storico_dati_pensionato (@mov_deleghe_id BIGINT
, @codice_fiscale_pensionato CHAR(16)
, @nome VARCHAR(50)
, @cognome VARCHAR(50)
, @sesso CHAR(1)
, @cognome_acq VARCHAR(50) = NULL
, @data_nascita DATETIME
, @comune_nascita VARCHAR(100)
, @provincia_nascita CHAR(2)
, @indirizzo_residenza VARCHAR(250)
, @comune_residenza VARCHAR(100)
, @provincia_residenza CHAR(2)
, @cap_residenza CHAR(5) = NULL
, @stato_residenza VARCHAR(50))
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_StoricoAngraficaPensionato AS sap
        WHERE 1 = 1
        AND sap.MovDelegheID = @mov_deleghe_id)
    BEGIN

      INSERT INTO dbo.ND_StoricoAngraficaPensionato (MovDelegheID
      , CodiceFiscalePensionato
      , Nome
      , Cognome
      , Sesso
      , CognomeAcquisito
      , DataNascita
      , ComuneNascita
      , ProvinciaNascita
      , IndirizzoResidenza
      , ComuneResidenza
      , ProvinciaResidenza
      , CapResidenza
      , StatoResidenza)
        VALUES (@mov_deleghe_id -- MovDelegheID - bigint NOT NULL
        , @codice_fiscale_pensionato -- CodiceFiscalePensionato - char(16) NOT NULL
        , @nome -- Nome - varchar(50) NOT NULL
        , @cognome -- Cognome - varchar(50) NOT NULL
        , @sesso -- Sesso - char(1) NOT NULL
        , @cognome_acq -- CognomeAcquisito - varchar(50)
        , @data_nascita -- 'YYYY-MM-DD hh:mm:ss[.nnn]'-- DataNascita - datetime NOT NULL
        , @comune_nascita -- ComuneNascita - varchar(100) NOT NULL
        , @provincia_nascita -- ProvinciaNascita - char(2) NOT NULL
        , @indirizzo_residenza -- IndirizzoResidenza - varchar(250) NOT NULL
        , @comune_residenza -- ComuneResidenza - varchar(100) NOT NULL
        , @provincia_residenza -- ProvinciaResidenza - char(2) NOT NULL
        , @cap_residenza -- CapResidenza - char(5)
        , @stato_residenza -- StatoResidenza - varchar(50) NOT NULL
        );

    END
  END TRY
  BEGIN CATCH
    THROW;
  END CATCH
END
GO

SET NOEXEC OFF
GO