USE [GapeInternet];
GO

/* ============================================
   TABELLA: NGW_AccessiOperatore
   ============================================ */



IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'NGW_AccessiOperatore')
BEGIN
    CREATE TABLE [NGW_AccessiOperatore]
    (
        [AcessiOperatoreID] BIGINT IDENTITY(1,1) NOT NULL,
        [TimeStamp] DATETIME2 NOT NULL,
        [CodiceFiscale] CHAR(16) NULL,
        [Nominativo] VARCHAR(150) NULL,
        [Email] NVARCHAR(150) NULL,
        [UserTypeId] INT NULL,
        [IstitutionCode] NVARCHAR(100) NULL,
        [IstitutionDescription] NVARCHAR(200) NULL,
        [OfficeCode] NVARCHAR(100) NULL,
        [FPNazione] BIT DEFAULT 0 NOT NULL,
        [FPRegioni] NVARCHAR(500) NULL,
        [FPProvince] NVARCHAR(500) NULL,
        [FPComuni] NVARCHAR(500) NULL,
        [R_DELEG] BIT DEFAULT 0 NOT NULL,
        [R_MODPAG] BIT DEFAULT 0 NOT NULL,
        [R_TITOL] BIT DEFAULT 0 NOT NULL,
        [R_IMPORT] BIT DEFAULT 0 NOT NULL,
        [R_TUTORE] BIT DEFAULT 0 NOT NULL
    );

    ALTER TABLE [NGW_AccessiOperatore]
        ADD CONSTRAINT [PK_NGW_AccessiOperatore] PRIMARY KEY ([AcessiOperatoreID]);
END;
GO

/* ===== Indici NGW_AccessiOperatore ===== */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxTs')
    CREATE INDEX [idxTs] ON [NGW_AccessiOperatore] ([TimeStamp] DESC);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxCF')
    CREATE INDEX [idxCF] ON [NGW_AccessiOperatore] ([CodiceFiscale]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxNom')
    CREATE INDEX [idxNom] ON [NGW_AccessiOperatore] ([Nominativo]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxEmail')
    CREATE INDEX [idxEmail] ON [NGW_AccessiOperatore] ([Email]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxFpN')
    CREATE INDEX [idxFpN] ON [NGW_AccessiOperatore] ([FPNazione]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxReg')
    CREATE INDEX [idxReg] ON [NGW_AccessiOperatore] ([FPRegioni]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxProv')
    CREATE INDEX [idxProv] ON [NGW_AccessiOperatore] ([FPProvince]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxCom')
    CREATE INDEX [idxCom] ON [NGW_AccessiOperatore] ([FPComuni]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxRDeleg')
    CREATE INDEX [idxRDeleg] ON [NGW_AccessiOperatore] ([R_DELEG]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxRModPag')
    CREATE INDEX [idxRModPag] ON [NGW_AccessiOperatore] ([R_MODPAG]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxRTitol')
    CREATE INDEX [idxRTitol] ON [NGW_AccessiOperatore] ([R_TITOL]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxRImport')
    CREATE INDEX [idxRImport] ON [NGW_AccessiOperatore] ([R_IMPORT]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idxRTutore')
    CREATE INDEX [idxRTutore] ON [NGW_AccessiOperatore] ([R_TUTORE]);
GO


/* ============================================
   TABELLA: NGW_FrontLog
   ============================================ */

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'NGW_FrontLog')
BEGIN
    CREATE TABLE [NGW_FrontLog]
    (
        [Id] BIGINT IDENTITY(1,1) NOT NULL,
        [Level] NVARCHAR(128) NULL,
        [TimeStamp] DATETIME2 NOT NULL,
        [Message] NVARCHAR(MAX) NULL,
        [MessageTemplate] NVARCHAR(MAX) NULL,
        [Exception] NVARCHAR(MAX) NULL,
        [Properties] NVARCHAR(MAX) NULL,
        [LogEvent] VARBINARY(MAX) NULL,
        [Url] NVARCHAR(1000) NULL
    );

    ALTER TABLE [NGW_FrontLog]
        ADD CONSTRAINT [PK_NGW_FrontLog] PRIMARY KEY ([Id]);
END;
GO

