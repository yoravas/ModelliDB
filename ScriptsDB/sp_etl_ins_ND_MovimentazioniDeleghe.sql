USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_ND_MovimentazioniDeleghe]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_ND_MovimentazioniDeleghe]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_ND_MovimentazioniDeleghe
(
    @DATA_OPERAZIONE       DATETIME,
    @TEMPO_INDETERMINATO   BIT,
    @MAGGIORE_ETA          BIT,
    @DATA_SCADENZA         DATE,
    @ID_TIPO_DELEGA        INT,
    @TIPO_MOVIMENTO_ID     INT,
    @IDOPERATORE           BIGINT,
    @FK_MOV_DELEGHE_ID     BIGINT = NULL,
    @ID_MOVIMENTAZIONE     BIGINT OUTPUT   -- <<< ID che vuoi “riportare fuori”
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        -- 1) Cerca l’ID esistente (con lock per evitare race condition)
        SELECT TOP (1)
            @ID_MOVIMENTAZIONE = md.MovDelegheID
        FROM dbo.ND_MovimentazioniDeleghe AS md WITH (UPDLOCK, HOLDLOCK)
        WHERE md.TimeStamp = @DATA_OPERAZIONE
          AND md.IsTempoIndeterminato = @TEMPO_INDETERMINATO
          AND md.IsFinoMaggioreEta = @MAGGIORE_ETA
          AND md.DataScadenzaDelega = @DATA_SCADENZA
          AND md.TipoDelegheDelegatiID = @ID_TIPO_DELEGA
          AND md.TipoMovimentoID = @TIPO_MOVIMENTO_ID
          AND md.OperatoreID = @IDOPERATORE
          AND (
                (md.FK_MovDelegheID = @FK_MOV_DELEGHE_ID)
             OR (md.FK_MovDelegheID IS NULL AND @FK_MOV_DELEGHE_ID IS NULL)
              );

        -- 2) Se non esiste, inserisci e prendi l’ID creato
        IF @ID_MOVIMENTAZIONE IS NULL
        BEGIN
            INSERT INTO dbo.ND_MovimentazioniDeleghe
            (
                TimeStamp,
                IsTempoIndeterminato,
                IsFinoMaggioreEta,
                DataScadenzaDelega,
                TipoDelegheDelegatiID,
                TipoMovimentoID,
                FK_MovDelegheID,
                OperatoreID
            )
            VALUES
            (
                @DATA_OPERAZIONE,
                @TEMPO_INDETERMINATO,
                @MAGGIORE_ETA,
                @DATA_SCADENZA,
                @ID_TIPO_DELEGA,
                @TIPO_MOVIMENTO_ID,
                @FK_MOV_DELEGHE_ID,
                @IDOPERATORE
            );

            -- Se la PK è IDENTITY:
            SET @ID_MOVIMENTAZIONE = CONVERT(BIGINT, SCOPE_IDENTITY());
        END
        
        COMMIT;

        -- 3) Facoltativo: ritorna anche come resultset (comodo in debug)
        SELECT @ID_MOVIMENTAZIONE AS ID_MOVIMENTAZIONE;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        
        THROW;
    END CATCH
END;
GO

SET NOEXEC OFF
GO