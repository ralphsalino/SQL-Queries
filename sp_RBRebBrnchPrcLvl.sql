-- =============================================
-- Author:		Ralph Salino
-- Create date: 2019-10-10
-- Description:	Rebates Maintenance for Branch Price level type
-- =============================================

ALTER PROCEDURE dbo.sp_RBRebBrnchPrcLvl
    @Mode AS VARCHAR(50) = NULL,
	@Whs AS VARCHAR(10) = NULL,
	@PrcLvlType AS INT = NULL

AS

BEGIN
	IF @Mode = 'LoadPrcLvlDetails'
		BEGIN
						SELECT	ISNULL(T3.PrcLvlType, 3) PrcLvlType,
								ISNULL(T4.[Desc], '') [Desc], 
								T1.Code, 
								T1.Blk, 
								T2.Price_Level1, 
								T2.Price_Level2, 
								ISNULL(T2.Price_Level3, '') Price_Level3
						FROM	SAPSET T1
								INNER JOIN dbo.Price_Level_Hdr T2 ON T2.Company = T1.LisGrp
								LEFT JOIN dbo.RAC_RebPrcLvlMntnce T3 ON T1.Code = T3.Whs
								LEFT JOIN dbo.RAC_MaintenanceCode T4 ON T3.PrcLvlType = T4.Code AND T4.Module = 'RebRateMntnce' AND T4.[Group] = 'PrcLvlType'
						WHERE	T1.STAT = 'O' 
								AND T1.SlsStat = 'O'
								AND T2.PriceType = 'N'
		END

	ELSE IF @Mode = 'LoadDrpDwnPrcLvl'
		BEGIN
						SELECT	Code,
								CAST(CAST(Code AS VARCHAR(10)) + ' - ' + [Desc] AS VARCHAR(50)) [Desc]
						FROM	dbo.RAC_MaintenanceCode 
						WHERE	Module = 'RebRateMntnce' 
								AND [Group] = 'PrcLvlType'
		END

	ELSE IF @Mode = 'AddNewBrnchPrcLvl'
		BEGIN
						INSERT INTO dbo.RAC_RebPrcLvlMntnce
							(Whs, PrcLvlType)
						VALUES
							(@Whs, @PrcLvlType)
						SELECT @@ROWCOUNT
		END

	ELSE IF @Mode = 'UpdateBrnchPrcLvl'
		BEGIN
						UPDATE	dbo.RAC_RebPrcLvlMntnce 
						SET		PrcLvlType = @PrcLvlType
						WHERE	Whs = @Whs
						SELECT @@ROWCOUNT
		END
END
     
GO
