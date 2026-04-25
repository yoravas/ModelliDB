USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2'
  SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_uffici_pagatori]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_uffici_pagatori]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_uffici_pagatori (@pensioni_id BIGINT
, @abi VARCHAR(10)
, @cab VARCHAR(10)
, @data_operazione DATETIME
)
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_UfficioPagatore AS up WITH (UPDLOCK, HOLDLOCK)
        WHERE 1 = 1
        AND up.PensioniID = @pensioni_id
        AND up.ABI = @abi
        AND up.CAB = @cab)
    BEGIN


      INSERT INTO dbo.ND_UfficioPagatore (PensioniID
      , ABI
      , CAB
      , TipoUfficioPagatore
      , Descrizione
      , Comune
      , Provincia
      , DataInserimento
      , Indirizzo
      , RagioneSociale
      , CapUfficioPagatore)
        VALUES (@pensioni_id -- PensioniID - bigint NOT NULL
        , @abi -- ABI - varchar(10) NOT NULL
        , @cab -- CAB - varchar(10) NOT NULL
        , '-' -- TipoUfficioPagatore - varchar(10) NOT NULL
        , N'-' -- Descrizione - nvarchar(250) NOT NULL
        , N'-' -- Comune - nvarchar(100) NOT NULL
        , '-' -- Provincia - char(2) NOT NULL
        , @data_operazione -- 'YYYY-MM-DD hh:mm:ss[.nnn]'-- DataInserimento - datetime NOT NULL
        , N'-' -- Indirizzo - nvarchar(300) NOT NULL
        , N'-' -- RagioneSociale - nvarchar(200) NOT NULL
        , '-' -- CapUfficioPagatore - varchar(10) NOT NULL
        );

    END
  END
  TRY
  BEGIN
  CATCH
    THROW;
  END CATCH
END

SET
NOEXEC OFF
GO