USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_ins_prestazioni_pensionato]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_ins_prestazioni_pensionato]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_prestazioni_pensionato
(
      @mov_deleghe_id     BIGINT
    , @chiave_operazione  NVARCHAR(500)
    , @data_operazione DATETIME
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @categoriaPrestazione               CHAR(3)
        , @descrizione_categoria_prestazione  NVARCHAR(MAX)
        , @sede_prestazione                   CHAR(4)
        , @certificato_prestazione            CHAR(8)
        , @codice_tipo_componente             CHAR(1)
        , @is_intestatario                    BIT
        , @codice_identificativo_familiare    CHAR(1)
        , @data_decorrenza                    CHAR(10)       -- <-- NON convertiamo DATA_DEC, ma deve combaciare col tipo di ND_StoricoPrestazioni
        , @ufficio_pagatore_abi               VARCHAR(10)
        , @ufficio_pagatore_cab               VARCHAR(10)
        , @codice_modalita_pagamento          CHAR(1)
        , @prestazione_id BIGINT;

    -- (Opzionale) valori di default costanti
    SET @codice_identificativo_familiare = NULL;
    

    DECLARE cur_pensioni CURSOR LOCAL FAST_FORWARD FOR
        SELECT
              p.NCAT
            , (p.CSED + p.CZON)
            , p.NCRT
            , p.CCMPTIP
            , p.FTITPRN
            , p.DESC_CAT_PENS
            , p.DATA_DEC         -- ✅ NON CONVERTITA
            , p.UFFPAGABI
            , p.UFFPAGCAB
        FROM dbo.DEL_LOG_PENSIONI AS p
        WHERE p.CHIAVE_OPERAZIONE = @chiave_operazione
        ORDER BY
              p.NCAT
            , p.CSED
            , p.CZON
            , p.NCRT;

    BEGIN TRY
        BEGIN TRAN;

        OPEN cur_pensioni;

        FETCH NEXT FROM cur_pensioni INTO
              @categoriaPrestazione
            , @sede_prestazione
            , @certificato_prestazione
            , @codice_tipo_componente
            , @is_intestatario
            , @descrizione_categoria_prestazione
            , @data_decorrenza
            , @ufficio_pagatore_abi
            , @ufficio_pagatore_cab;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -----------------------------------------------------------------
            -- Reset per iterazione: evita che valori della riga precedente
            -- “contaminino” la successiva
            -----------------------------------------------------------------
            SET @codice_modalita_pagamento = 'N';

            IF NULLIF(LTRIM(RTRIM(@ufficio_pagatore_abi)), '') IS NOT NULL
                SET @codice_modalita_pagamento = 'C';

            -----------------------------------------------------------------
            -- Inserisco SOLO se non esiste già
            -- Lock hint per ridurre race condition in concorrenza
            -----------------------------------------------------------------
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.ND_StoricoPrestazioni AS sp WITH (UPDLOCK, HOLDLOCK)
                WHERE sp.MovDelegheID            = @mov_deleghe_id
                  AND sp.CategoriaPrestazione   = @categoriaPrestazione
                  AND sp.SedePrestazione        = @sede_prestazione
                  AND sp.CertificatoPrestazione = @certificato_prestazione
            )
            BEGIN
                INSERT INTO dbo.ND_StoricoPrestazioni
                (
                      CategoriaPrestazione
                    , DescrizioneCategoriaPrestazione
                    , SedePrestazione
                    , CertificatoPrestazione
                    , CodiceTipoComponente
                    , CodiceIdentificativoFamiliare
                    , DataDecorrenza
                    , CodiceModalitaPagamento
                    , DescModalitaPagamento
                    , MovDelegheID
                    , Intestatario
                )
                VALUES
                (
                      @categoriaPrestazione
                    , @descrizione_categoria_prestazione
                    , @sede_prestazione
                    , @certificato_prestazione
                    , @codice_tipo_componente
                    , @codice_identificativo_familiare
                    , @data_decorrenza                 -- ✅ come arriva
                    , @codice_modalita_pagamento
                    , CASE WHEN @codice_modalita_pagamento = 'C'
                           THEN 'Conto Corrente'
                           ELSE 'Non definita'
                      END
                    , @mov_deleghe_id
                    , @is_intestatario
                );

                SET @prestazione_id = CONVERT(BIGINT, SCOPE_IDENTITY());

                --*****************Inserimento uffici pagatori*********************
                EXEC dbo.sp_etl_ins_uffici_pagatori @prestazione_id, @ufficio_pagatore_abi, @ufficio_pagatore_cab, @data_operazione;
                --*****************Fine inserimento uffici pagatori****************

                --*****************Inserimento contitolari*************************
                EXEC dbo.sp_etl_ins_contitolari @prestazione_id, @chiave_operazione;
                --*****************Fine inserimento contitolari********************
            END

            SET @prestazione_id = null;

            FETCH NEXT FROM cur_pensioni INTO
                  @categoriaPrestazione
                , @sede_prestazione
                , @certificato_prestazione
                , @codice_tipo_componente
                , @is_intestatario
                , @descrizione_categoria_prestazione
                , @data_decorrenza
                , @ufficio_pagatore_abi
                , @ufficio_pagatore_cab;
        END

        CLOSE cur_pensioni;
        DEALLOCATE cur_pensioni;

        COMMIT;
    END TRY
    BEGIN CATCH
        -- chiusura/deallocazione sicura del cursore anche in errore
        IF CURSOR_STATUS('local', 'cur_pensioni') > -3
        BEGIN
            CLOSE cur_pensioni;
            DEALLOCATE cur_pensioni;
        END

        IF XACT_STATE() <> 0
            ROLLBACK;

        THROW;
    END CATCH
END;
GO

SET NOEXEC OFF
GO