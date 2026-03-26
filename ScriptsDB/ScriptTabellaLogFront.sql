USE GapeInternet;
GO

-- Evita esecuzioni sul DB sbagliato
IF DB_NAME() <> N'GapeInternet' SET NOEXEC ON;
GO

SET NOCOUNT ON;

PRINT (N'DROP & CREATE della tabella [dbo].[NGW_FrontLog].');

-- 1) Elimina tabella se esiste
IF OBJECT_ID(N'dbo.NGW_FrontLog', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.NGW_FrontLog;
END
GO

-- 2) Ricrea tabella con LogEvent = nvarchar(max)
CREATE TABLE dbo.NGW_FrontLog (
  Id bigint IDENTITY,
  Level nvarchar(128) NULL,
  TimeStamp datetime2 NOT NULL,
  Message nvarchar(max) NULL,
  MessageTemplate nvarchar(max) NULL,
  Exception nvarchar(max) NULL,
  Properties nvarchar(max) NULL,
  LogEvent nvarchar(max) NULL,                -- <- aggiornato a nvarchar(max)
  Url nvarchar(1000) NULL,
  CONSTRAINT PK_NGW_FrontLog PRIMARY KEY CLUSTERED (Id)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY];
GO

SET NOEXEC OFF;
GO