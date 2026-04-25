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
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_storico_dati_delegato (@mov_deleghe_id BIGINT
, @codice_arca CHAR(3)
, @progressivo_arca CHAR(10)
, @codice_fiscale_delegato CHAR(16)
, @nome VARCHAR(50)
, @cognome VARCHAR(50)
, @cognome_acquisito VARCHAR(50) = NULL
, @sesso CHAR(1)
, @data_nascita DATETIME
, @comune_nascita VARCHAR(50)
, @provincia_nascita CHAR(2)
, @indirizzo_residenza VARCHAR(150)
, @comune_residenza VARCHAR(50)
, @provincia_residenza VARCHAR(10) = NULL
, @cap_residenza VARCHAR(10) = nyll
, @stato_residenza VARCHAR(50))
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_StoricoAnagraficaDelegato sad
        where 1 = 1
        AND sad.MovDelegheID = @mov_deleghe_id
        AND sad.CodiceFicaleDelegato = @codice_fiscale_delegato)
    BEGIN
      PRINT 'l''anagrafica del delegato non esiste pertanto verrà inserita.';

      INSERT INTO dbo.ND_StoricoAnagraficaDelegato (MovDelegheID
      , CodArca
      , ProgressivoArca
      , CodiceFicaleDelegato
      , Nome
      , Cognome
      , CognomeAcquisito
      , Sesso
      , DataNascita
      , ComuneNascita
      , ProvinciaNascita
      , IndirizzoResidenza
      , ComuneResidenza
      , ProvinciaResidenza
      , CapResidenza
      , StatoResidenza)
        VALUES (@mov_deleghe_id -- MovDelegheID - bigint NOT NULL
        , @codice_arca -- CodArca - char(3) NOT NULL
        , @progressivo_arca -- ProgressivoArca - char(10) NOT NULL
        , @codice_fiscale_delegato -- CodiceFicaleDelegato - char(16) NOT NULL
        , @nome -- Nome - varchar(50) NOT NULL
        , @cognome -- Cognome - varchar(50) NOT NULL
        , @cognome_acquisito -- CognomeAcquisito - varchar(50)
        , @sesso -- Sesso - char(1) NOT NULL
        , @data_nascita -- 'YYYY-MM-DD hh:mm:ss[.nnn]'-- DataNascita - datetime NOT NULL
        , @comune_nascita -- ComuneNascita - varchar(50) NOT NULL
        , @provincia_nascita -- ProvinciaNascita - char(2) NOT NULL
        , @indirizzo_residenza -- IndirizzoResidenza - varchar(150) NOT NULL
        , @comune_residenza -- ComuneResidenza - varchar(50) NOT NULL
        , @provincia_residenza -- ProvinciaResidenza - varchar(10)
        , @cap_residenza -- CapResidenza - varchar(10)
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