USE Deleghe2
GO

IF DB_NAME() <> N'Deleghe2' SET NOEXEC ON
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

--
-- Create or alter procedure [dbo].[sp_etl_old_to_new_deleghe]
--
GO
PRINT (N'Create or alter procedure [dbo].[sp_etl_old_to_new_deleghe]')
GO
CREATE OR ALTER PROCEDURE dbo.sp_etl_old_to_new_deleghe
(
	@Da date
)
AS 
begin
	set nocount on;
	
DECLARE 
        @CHIAVE_OPERAZIONE  varchar(100),
        @TIPO_OPERAZIONE    varchar(50)

print 'Data nel paramentro di ricerca: ' + CONVERT(VARCHAR, @Da);
print '---------------------------------------';

DECLARE curOperazioni CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT
            o.CHIAVE_OPERAZIONE,
            t.TIPO_OPERAZIONE
        FROM dbo.DEL_LOG_OPERAZIONI AS o
        INNER JOIN dbo.DEL_LOG_T32 AS t
            ON t.CHIAVE_OPERAZIONE = o.CHIAVE_OPERAZIONE
        WHERE o.DATA_OPERAZIONE >= @Da
        ORDER BY o.CHIAVE_OPERAZIONE;

begin
	try 
	OPEN curOperazioni;
	FETCH NEXT FROM curOperazioni INTO @CHIAVE_OPERAZIONE, @TIPO_OPERAZIONE;

    WHILE @@FETCH_STATUS = 0
    begin
        print 'Chiave operazione: ' + @CHIAVE_OPERAZIONE;
        print 'Tipo operazione: ' + @TIPO_OPERAZIONE;
        print '---------------------------------------';
        print 'Dati operazione:';
        --*****************Dati Operazione************************
        DECLARE
            @CODICE_OPERATORE varchar(50),
            @DATA_OPERAZIONE datetime,
            @CODICE_FISCALE_PENSIONATO varchar(50),
            @COGNOME_PENSIONATO varchar(100),
            @NOME_PENSIONATO varchar(100),
            @COGNOME_ACQ_PENSIONATO varchar(100),
            @DATA_NASCITA_PENSIONATO varchar(50),
            @SESSO_PENSIONATO char(1),
            @SEDE_OPERAZIONE varchar(100),
            @IND_RES_PENSIONATO varchar(100),
            @CapResidenza varchar(10),
            @ComuneResidenza varchar(100),
            @PROV_RES varchar(10),
            @EsitoWarest varchar(50);

        SELECT
            @CODICE_OPERATORE = o.CODICE_OPERATORE,
            @DATA_OPERAZIONE = o.DATA_OPERAZIONE,
            @CODICE_FISCALE_PENSIONATO = o.CODICE_FISCALE_PENSIONATO,
            @COGNOME_PENSIONATO = o.COGNOME_PENSIONATO,
            @NOME_PENSIONATO = o.NOME_PENSIONATO,
            @COGNOME_ACQ_PENSIONATO = o.COGNOME_ACQ_PENSIONATO,
            @DATA_NASCITA_PENSIONATO = o.DATA_NASCITA_PENSIONATO,
            @SESSO_PENSIONATO = o.SESSO_PENSIONATO,
            @SEDE_OPERAZIONE = o.SEDE_OPERAZIONE,
            @IND_RES_PENSIONATO = o.IND_RES_PENSIONATO,
            @CapResidenza = o.CAP,
            @ComuneResidenza = o.COM_RES,
            @PROV_RES = o.PROV_RES,
            @EsitoWarest = o.ESITO_HOST
        FROM [Deleghe2].[dbo].[DEL_LOG_OPERAZIONI] AS o
        WHERE o.CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE;

        print 'Codice operatore: ' + @CODICE_OPERATORE;
        print 'Data operazione: ' + CONVERT(varchar, @DATA_OPERAZIONE, 120);
        print 'Codice fiscale pensionato: ' + @CODICE_FISCALE_PENSIONATO;
        print 'Cognome pensionato: ' + @COGNOME_PENSIONATO;
        print 'Nome pensionato: ' + @NOME_PENSIONATO;
        print 'Cognome acquisito pensionato: ' + @COGNOME_ACQ_PENSIONATO;
        print 'Data nascita pensionato: ' + @DATA_NASCITA_PENSIONATO;
        print 'Sesso pensionato: ' + @SESSO_PENSIONATO;
        print 'Sede operazione: ' + @SEDE_OPERAZIONE;
        print 'Indirizzo residenza pensionato: ' + @IND_RES_PENSIONATO;
        print 'CAP residenza pensionato: ' + @CapResidenza;
        print 'Comune residenza pensionato: ' + @ComuneResidenza;
        print 'Provincia residenza pensionato: ' + @PROV_RES;
        print 'Esito Warest: ' + @EsitoWarest;
        --**************FINE Dati Operazione***********************
        print '---------------------------------------';
        print 'Dati anagrafici delegato:';
        --*************DATI ANAGRAFICI DELEGATO************************
        DECLARE 
            @CF_CAUNCFCCC1 nchar(10),
            @NAUNPRG nchar(10),
            @CODICE_FISCALE_DEL nchar(16),
            @COGNOME varchar(50),
            @NOME varchar(50),
            @DATA_NASCITA varchar(50),
            @ComuneNascita varchar(50),
            @PROV_NASCITA nchar(10),
            @INDIRIZZO_RES varchar(100),
            @COMUNE_RES nvarchar(100),
            @PROV_RES_DELEGATO nchar(10),
            @CAP_RES nchar(10),
            @STATO_RES nvarchar(100),
            @SESSO char(1);

        SELECT 
            @CF_CAUNCFCCC1 = CF_CAUNCFCCC1,
            @NAUNPRG = NAUNPRG,
            @CODICE_FISCALE_DEL = CODICE_FISCALE_DEL,
            @COGNOME = COGNOME,
            @NOME = NOME,
            @DATA_NASCITA = DATA_NASCITA,
            @ComuneNascita = DECO_COMU,
            @PROV_NASCITA = PROV_NASCITA,
            @INDIRIZZO_RES = INDIRIZZO_RES,
            @COMUNE_RES = COMUNE_RES,
            @PROV_RES_DELEGATO = PROV_RES,
            @CAP_RES = CAP_RES,
            @STATO_RES = STATO_RES,
            @SESSO = SESSO
        FROM dbo.DEL_LOG_DATIDELANAGRAFICI
        WHERE CHIAVE_OPERAZIONE = @CHIAVE_OPERAZIONE;

        print 'Cognome: ' + @COGNOME;
        print 'Nome: ' + @NOME;
        print 'Data nascita: ' + @DATA_NASCITA;
        print 'Comune nascita: ' + @ComuneNascita;
        print 'Provincia nascita: ' + @PROV_NASCITA;
        --**************FINE DATI ANAGRAFICI PENSIONATO***********************
        
        FETCH NEXT FROM curOperazioni INTO @CHIAVE_OPERAZIONE, @TIPO_OPERAZIONE;
    end
    
    CLOSE curOperazioni;
    DEALLOCATE curOperazioni;
END TRY
BEGIN
	CATCH
    
        -- Chiudiamo cursor in caso di errore
        IF CURSOR_STATUS('local', 'curOperazioni') >= -1
        BEGIN
            CLOSE curOperazioni;
            DEALLOCATE curOperazioni;
        END

        DECLARE 
            @ErrMsg nvarchar(4000) = ERROR_MESSAGE(),
            @ErrSev int = ERROR_SEVERITY(),
            @ErrSta int = ERROR_STATE();

        RAISERROR(@ErrMsg, @ErrSev, @ErrSta);
        RETURN;
END CATCH
end;
GO

SET NOEXEC OFF
GO