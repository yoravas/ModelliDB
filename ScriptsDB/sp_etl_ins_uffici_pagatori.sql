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
CREATE OR ALTER PROCEDURE dbo.sp_etl_ins_uffici_pagatori (@pensioni_id BIGINT,
@abi VARCHAR(10),
@cab VARCHAR(10),
@data_operazione DATETIME)
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRY
    -----------------------------------------------------------------
    -- Normalizzazione ABI/CAB:
    -- se solo una delle 2 è vuota -> l'altra resta e quella vuota = '0'
    -- se entrambe vuote -> entrambe = '0'
    -----------------------------------------------------------------
    SET @abi = NULLIF(LTRIM(RTRIM(@abi)), '');
    SET @cab = NULLIF(LTRIM(RTRIM(@cab)), '');

    IF (@abi IS NULL
      AND @cab IS NOT NULL)
      SET @abi = '0';
    IF (@cab IS NULL
      AND @abi IS NOT NULL)
      SET @cab = '0';

    IF (@abi IS NULL
      AND @cab IS NULL)
    BEGIN
      SET @abi = '0';
      SET @cab = '0';
    END

    -----------------------------------------------------------------
    -- Insert idempotente
    -----------------------------------------------------------------
    IF NOT EXISTS (SELECT
          1
        FROM dbo.ND_UfficioPagatore AS up WITH (UPDLOCK, HOLDLOCK)
        WHERE up.PensioniID = @pensioni_id
        AND up.ABI = @abi
        AND up.CAB = @cab)
    BEGIN
      INSERT INTO dbo.ND_UfficioPagatore (PensioniID,
      ABI,
      CAB,
      TipoUfficioPagatore,
      Descrizione,
      Comune,
      Provincia,
      DataInserimento,
      Indirizzo,
      RagioneSociale,
      CapUfficioPagatore)
        VALUES (@pensioni_id, @abi, @cab, '-', N'-', N'-', '-', @data_operazione, N'-', N'-', '-');
    END
  END TRY
  BEGIN CATCH
    -- Se vuoi restare coerente con il resto (no THROW), posso convertirlo a RAISERROR
    -- Qui mantengo il tuo stile minimale: ma se THROW ti dà problemi, dimmelo.
    DECLARE @ErrNum INT = ERROR_NUMBER()
           ,@ErrMsg NVARCHAR(4000) = ERROR_MESSAGE()
           ,@ErrLine INT = ERROR_LINE()
           ,@ErrProc NVARCHAR(200) = ISNULL(ERROR_PROCEDURE(), N'?');

    DECLARE @RaisMsg NVARCHAR(4000) =
    N'Errore in sp_etl_ins_uffici_pagatori - Proc=' + @ErrProc +
    N', Line=' + CONVERT(NVARCHAR(10), @ErrLine) +
    N', Err=' + CONVERT(NVARCHAR(10), @ErrNum) + N' - ' + @ErrMsg +
    N' | CTX: PensioniID=' + CONVERT(NVARCHAR(30), @pensioni_id) +
    N', ABI=' + ISNULL(@abi, N'<null>') +
    N', CAB=' + ISNULL(@cab, N'<null>');

    RAISERROR (@RaisMsg, 16, 1);
    RETURN;
  END CATCH
END
GO

SET
NOEXEC OFF
GO

SET NOEXEC OFF
GO