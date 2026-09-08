USE DS05259_PNRR36_DataQuality;
GO

IF DB_NAME() <> N'DS05259_PNRR36_DataQuality'
    SET NOEXEC ON;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

------------------------------------------------------------------------------
-- Create table [dbo].[DEP_PreVariazioneAnagraficaArca]
------------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.DEP_PreVariazioneAnagraficaArca', N'U') IS NULL
BEGIN
    PRINT N'Create table [dbo].[DEP_PreVariazioneAnagraficaArca]';

    CREATE TABLE dbo.DEP_PreVariazioneAnagraficaArca
    (
        ID bigint NOT NULL,
        Nome varchar(50) NOT NULL,
        Cognome varchar(50) NOT NULL,
        CodiceFiscale char(16) NULL,
        DescrizioneSesso varchar(15) NULL,
        TipoValidazioneCodiceFiscale varchar(5) NULL,
        DescrizioneTipoValidazioneCodiceFiscale varchar(100) NULL,
        CFCCC1F char(3) NOT NULL,
        PROGRF int NOT NULL,

        CONSTRAINT PK_DEP_AnagraficaArcaVar
            PRIMARY KEY CLUSTERED (ID)
    );
END
GO

------------------------------------------------------------------------------
-- Create index [idx_CF_AnagraficaArcaVar]
------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'idx_CF_AnagraficaArcaVar'
      AND object_id = OBJECT_ID(N'dbo.DEP_PreVariazioneAnagraficaArca')
)
BEGIN
    PRINT N'Create index [idx_CF_AnagraficaArcaVar]';

    CREATE INDEX idx_CF_AnagraficaArcaVar
        ON dbo.DEP_PreVariazioneAnagraficaArca (CodiceFiscale);
END
GO

------------------------------------------------------------------------------
-- Create index [idx_ChiaveArca]
------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'idx_ChiaveArca'
      AND object_id = OBJECT_ID(N'dbo.DEP_PreVariazioneAnagraficaArca')
)
BEGIN
    PRINT N'Create index [idx_ChiaveArca]';

    CREATE INDEX idx_ChiaveArca
        ON dbo.DEP_PreVariazioneAnagraficaArca (CFCCC1F, PROGRF);
END
GO

------------------------------------------------------------------------------
-- Create index [idx_TipoValCodFisc]
------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'idx_TipoValCodFisc'
      AND object_id = OBJECT_ID(N'dbo.DEP_PreVariazioneAnagraficaArca')
)
BEGIN
    PRINT N'Create index [idx_TipoValCodFisc]';

    CREATE INDEX idx_TipoValCodFisc
        ON dbo.DEP_PreVariazioneAnagraficaArca (TipoValidazioneCodiceFiscale);
END
GO

------------------------------------------------------------------------------
-- Create foreign key [R_AA_VAA]
------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = N'R_AA_VAA'
)
BEGIN
    PRINT N'Create foreign key [R_AA_VAA]';

    ALTER TABLE dbo.DEP_PreVariazioneAnagraficaArca
    ADD CONSTRAINT R_AA_VAA
        FOREIGN KEY (ID)
        REFERENCES dbo.DEP_AnagraficaArca (ID)
        ON DELETE CASCADE;
END
GO

SET NOEXEC OFF;
GO

------------------------------------------------------------------------------
-- Create or alter view [dbo].[DEP_V_FlussiElaborati]
------------------------------------------------------------------------------
PRINT N'Create or alter view [dbo].[DEP_V_FlussiElaborati]';
GO

CREATE OR ALTER VIEW dbo.DEP_V_FlussiElaborati
AS
SELECT DISTINCT
       FE.AnagraficaArcaID,
       EAF.CFCCC1_EV0 AS CFCCC1,
       EAF.PROGR_EV0 AS PROGR,
       AA.Nome,
       AA.Cognome,
       AA.CodiceFiscale AS CodiceFiscaleNew,
       FE.CodiceFiscaleOld,
       AA.CodiceCittadinanza AS CodiceCittadinanzaNew,
       FE.CodiceCittadinanzaOld,
       AA.Cittadinanza AS CittadinanzaNew,
       FE.CittadinanzaOld,
       AA.CodiceTipoIndirizzo AS CodiceTipoIndirizzoNew,
       AA.DescrizioneTipoIndirizzo AS DescrizioneTipoIndirizzoNew,
       AA.Nazionalita AS NazionalitaNew,
       FE.NazionalitaOld,
       TE.TipologiaEventiID,
       TE.DescrizioneEvento,
       FE.TipoEvento,
       FE.Inviato,
       EAF.LogFlussiID,
       EAF.TIMEST1_EV0,
       AA.DataVariazioneIndirizzo AS DataDecorrenzaIrr,
       PVA.TipoValidazioneCodiceFiscale,
       PVA.DescrizioneTipoValidazioneCodiceFiscale
FROM dbo.DEP_FlussiElaborati AS FE
INNER JOIN dbo.DEP_TipologiaEventi AS TE
    ON TE.TipologiaEventiID = FE.TipologiaEventiID
INNER JOIN dbo.DEP_AnagraficaArca AS AA
    ON AA.ID = FE.AnagraficaArcaID
INNER JOIN dbo.DEP_EventiArca_Flussi AS EAF
    ON EAF.ID = AA.ID
LEFT JOIN dbo.DEP_PreVariazioneAnagraficaArca AS PVA
    ON PVA.ID = AA.ID
WHERE FE.Inviato = 0;
GO

SET NOEXEC OFF;
GO

------------------------------------------------------------------------------
-- Insert DEP_SubSteps
------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DEP_SubSteps
    WHERE SubStepsID = 1
)
BEGIN
    INSERT INTO dbo.DEP_SubSteps
    (
        SubStepsID,
        Descrizione
    )
    VALUES
    (
        1,
        'LetturaDatiAnagrafici'
    );
END
GO

------------------------------------------------------------------------------
-- Insert DEP_ConfigFlussiSubSteps
------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DEP_ConfigFlussiSubSteps
    WHERE ConfigFlussiID = 2
      AND SubStepsID = 1
)
BEGIN
    INSERT INTO dbo.DEP_ConfigFlussiSubSteps
    (
        ConfigFlussiID,
        SubStepsID,
        Valore
    )
    VALUES
    (
        2,
        1,
        1
    );
END
GO
