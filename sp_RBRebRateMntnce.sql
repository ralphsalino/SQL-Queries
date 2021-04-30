-- =============================================
-- Author:		Ralph Salino
-- Create date: 2019-10-07
-- Description:	Rebates Maintenance
-- =============================================

ALTER PROCEDURE dbo.sp_RBRebRateMntnce
    @Mode AS VARCHAR(100) = NULL,
	@RateDesc AS VARCHAR(100) = NULL,
	@PMode AS VARCHAR(5) = NULL,
	@AcctType AS VARCHAR(5) = NULL,
	@Senior AS VARCHAR(5) = NULL,
	@PckType AS VARCHAR(5) = NULL,
	@PrcLvl AS VARCHAR(5) = NULL,
	@Whs AS VARCHAR(5) = NULL,
	@TestGrp AS VARCHAR(20) = NULL,
	@Rate AS DECIMAL(18,2) = NULL,
	@Amount AS DECIMAL(18,2) = NULL,
	@Type AS INT = NULL,
	@RebRate UDTRebRate READONLY

AS
BEGIN
	IF @Mode = 'ImportCombination'
		BEGIN
					INSERT INTO dbo.RAC_RebRateCombination
					(
						RateDesc,
						PMode,
						AcctType,
						Senior,
						PckType,
						PrcLvl,
						Whs,
						TestGrp,
						Rate,
						Amount
					)
					VALUES
					(   
						@RateDesc, -- RateDesc - varchar(100)
						@PMode, -- PMode - varchar(5)
						@AcctType, -- AcctType - varchar(5)
						@Senior,  -- Senior - int
						@PckType,  -- PckType - int
						@PrcLvl,  -- PrcLvl - int
						@Whs, -- Whs - varchar(5)
						@TestGrp,  -- TestGrp - varchar(20)
						@Rate,
						@Amount
					)
					 SELECT @@ROWCOUNT
		END

	ELSE IF @Mode = 'LoadRatesCombo'
		BEGIN
					IF @PMode = 'All' BEGIN SET @PMode = NULL END
					IF @AcctType = 'All' BEGIN SET @AcctType = NULL END
					IF @Senior = 'All' BEGIN SET @Senior = NULL END
					IF @PckType = 'All' BEGIN SET @PckType = NULL END
					IF @PrcLvl = 'All' BEGIN SET @PrcLvl = NULL END
					IF @Whs = 'All' BEGIN SET @Whs = NULL END
					IF @TestGrp = 'All' BEGIN SET @TestGrp = NULL END

					SELECT	TOP 1000 
							T1.RateCode,
							T1.RateDesc,
							T2.U_PayDesc [PMode],
							T3.AcctName [AcctType],
							T4.[Desc] [Senior],
							T5.[Desc] [PckType],
							T6.[Desc] [PrcLvl],
							T7.Blk [Whs],
							T8.TG_NAME [TestGrp],
							T1.Rate,
							T1.Amount,
							T1.Type
					FROM	dbo.RAC_RebRateCombination T1 WITH(NOLOCK)
							LEFT JOIN dbo.OPYT T2 WITH(NOLOCK) ON T2.U_PayCode = T1.PMode
							LEFT JOIN AcctType T3 WITH(NOLOCK) ON T3.AcctCode = T1.AcctType
							LEFT JOIN RAC_MaintenanceCode T4 WITH(NOLOCK) ON T4.[Group] = 'Senior' AND T4.Code = T1.Senior
							LEFT JOIN dbo.RAC_MaintenanceCode T5 WITH(NOLOCK) ON T5.[Group] = 'Package' AND T5.Code = T1.PckType
							LEFT JOIN dbo.RAC_MaintenanceCode T6 WITH(NOLOCK) ON T6.[Group] = 'PrcLvlType' AND T6.Code = T1.PrcLvl
							LEFT JOIN dbo.SAPSet T7 WITH(NOLOCK) ON T7.Code = T1.Whs
							LEFT JOIN dbo.TEST_GROUP T8 WITH(NOLOCK) ON T8.TG_CODE = T1.TestGrp
					WHERE	T1.Type = @Type
							AND CHARINDEX(ISNULL(@PMode, 'a'), CASE WHEN @PMode IS NULL THEN 'a' ELSE T1.PMode END, 0) > 0
							AND CHARINDEX(ISNULL(@AcctType, 'a'), CASE WHEN @AcctType IS NULL THEN 'a' ELSE T1.AcctType END, 0) > 0 
							AND CHARINDEX(ISNULL(@Senior, '0'), CASE WHEN @Senior IS NULL THEN '0' ELSE T1.Senior END, 0) > 0
							AND CHARINDEX(ISNULL(@PckType, '0'), CASE WHEN @PckType IS NULL THEN '0' ELSE T1.PckType END, 0) > 0
							AND CHARINDEX(ISNULL(@PrcLvl, '0'), CASE WHEN @PrcLvl IS NULL THEN '0' ELSE T1.PrcLvl END, 0) > 0
							AND CHARINDEX(ISNULL(@Whs, 'a'), CASE WHEN @Whs IS NULL THEN 'a' ELSE T1.Whs END, 0) > 0
							AND CHARINDEX(ISNULL(@TestGrp, 'a'), CASE WHEN @TestGrp IS NULL THEN 'a' ELSE T1.TestGrp END, 0) > 0
		END

	ELSE IF @Mode = 'LoadPmode'
		BEGIN
					SELECT	T1.Code, T1.[Desc]
					FROM	(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
							UNION
							SELECT	U_PayCode [Code], U_PayCode + ' - ' + U_PayDesc [Desc], 2 [Seq]
							FROM	dbo.OPYT) T1
					ORDER BY
							T1.Seq
					
		END
		
	ELSE IF @Mode = 'LoadAccntType'
		BEGIN
					SELECT	T1.Code, T1.[Desc]
					FROM	(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
							UNION
							SELECT	AcctCode [Code], AcctCode + ' - ' + AcctName [Desc], 2 [Seq]
							FROM	dbo.AcctType) T1
					ORDER BY
							T1.Seq
		END

	ELSE IF @Mode = 'LoadDiscount'
		BEGIN
					SELECT	T1.Code, T1.[Desc]
					FROM	(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
							UNION
							SELECT	Code, Code + ' - ' + [Desc] [Desc], 2 [Seq] 
							FROM	dbo.RAC_MaintenanceCode 
							WHERE	[Group] = 'Senior') T1
					ORDER BY
							T1.Seq
		END

	ELSE IF @Mode = 'LoadPckType'
		BEGIN
					SELECT	T1.Code, T1.[Desc]
					FROM	(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
							UNION
							SELECT	Code, Code + ' - ' + [Desc] [Desc], 2 [Seq] 
							FROM	dbo.RAC_MaintenanceCode 
							WHERE	[Group] = 'Package') T1
					ORDER BY
							T1.Seq
					       
		END

	ELSE IF @Mode = 'LoadPrcLvl'
		BEGIN
					SELECT	T1.Code, T1.[Desc]
					FROM	(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
							UNION
							SELECT	Code, Code + ' - ' + [Desc], 2 [Seq]  
							FROM	dbo.RAC_MaintenanceCode 
							WHERE	[Group] = 'PrcLvlType') T1
					ORDER BY
							T1.Seq
					       
		END

	ELSE IF @Mode = 'LoadBranch'
		BEGIN
					SELECT	T1.Code, T1.[Desc]
					FROM	(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
							UNION
							SELECT	Code, WhsName [Desc], 2 [Seq] 
							FROM	dbo.SAPSet 
							WHERE	Stat = 'O') T1
					ORDER BY
							T1.Seq
					       
		END

	ELSE IF @Mode = 'LoadTestGrp'
		BEGIN
					SELECT	T1.Code, T1.[Desc]
					FROM	(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
							UNION
							SELECT	TG_CODE [Code], TG_CODE + ' - ' + TG_NAME [Desc], 2 [Seq] 
							FROM	dbo.TEST_GROUP) T1
					ORDER BY
							T1.Seq
					       
		END

	ELSE IF @Mode = 'LoadType'
		BEGIN
					SELECT	Code, [Desc]
					FROM	dbo.RAC_MaintenanceCode
					WHERE	[Group] = 'Type' AND Module = 'RebRateMntnce' 
							AND Type = 'Criteria Type'	
		END

	ELSE IF @Mode = 'UpdateRateAmount'
		BEGIN
					IF @PMode = 'All' BEGIN SET @PMode = NULL END
					IF @AcctType = 'All' BEGIN SET @AcctType = NULL END
					IF @Senior = 'All' BEGIN SET @Senior = NULL END
					IF @PckType = 'All' BEGIN SET @PckType = NULL END
					IF @PrcLvl = 'All' BEGIN SET @PrcLvl = NULL END
					IF @Whs = 'All' BEGIN SET @Whs = NULL END
					IF @TestGrp = 'All' BEGIN SET @TestGrp = NULL END

					UPDATE	dbo.RAC_RebRateCombination
					SET		dbo.RAC_RebRateCombination.Rate = @Rate,
							dbo.RAC_RebRateCombination.Amount = @Amount
					WHERE	dbo.RAC_RebRateCombination.Type = @Type
							AND CHARINDEX(ISNULL(@PMode, 'a'), CASE WHEN @PMode IS NULL THEN 'a' ELSE dbo.RAC_RebRateCombination.PMode END, 0) > 0
							AND CHARINDEX(ISNULL(@AcctType, 'a'), CASE WHEN @AcctType IS NULL THEN 'a' ELSE dbo.RAC_RebRateCombination.AcctType END, 0) > 0 
							AND CHARINDEX(ISNULL(@Senior, '0'), CASE WHEN @Senior IS NULL THEN '0' ELSE dbo.RAC_RebRateCombination.Senior END, 0) > 0
							AND CHARINDEX(ISNULL(@PckType, '0'), CASE WHEN @PckType IS NULL THEN '0' ELSE dbo.RAC_RebRateCombination.PckType END, 0) > 0
							AND CHARINDEX(ISNULL(@PrcLvl, '0'), CASE WHEN @PrcLvl IS NULL THEN '0' ELSE dbo.RAC_RebRateCombination.PrcLvl END, 0) > 0
							AND CHARINDEX(ISNULL(@Whs, 'a'), CASE WHEN @Whs IS NULL THEN 'a' ELSE dbo.RAC_RebRateCombination.Whs END, 0) > 0
							AND CHARINDEX(ISNULL(@TestGrp, 'a'), CASE WHEN @TestGrp IS NULL THEN 'a' ELSE dbo.RAC_RebRateCombination.TestGrp END, 0) > 0
		END

	ELSE IF @Mode = 'UpdateLessThan1K'
		BEGIN
				UPDATE		dbo.RAC_RebRateCombination
				SET			dbo.RAC_RebRateCombination.Rate = @Rate,
							dbo.RAC_RebRateCombination.Amount = @Amount
				FROM		@RebRate T2
				WHERE		dbo.RAC_RebRateCombination.Type = @Type
							AND	dbo.RAC_RebRateCombination.PMode = T2.PMode COLLATE DATABASE_DEFAULT
							AND	dbo.RAC_RebRateCombination.AcctType = T2.AcctType COLLATE DATABASE_DEFAULT
							AND dbo.RAC_RebRateCombination.Senior = T2.Senior COLLATE DATABASE_DEFAULT
							AND	dbo.RAC_RebRateCombination.PckType = T2.PckType COLLATE DATABASE_DEFAULT
							AND	dbo.RAC_RebRateCombination.PrcLvl = T2.PrcLvl COLLATE DATABASE_DEFAULT
							AND dbo.RAC_RebRateCombination.Whs = T2.Whs COLLATE DATABASE_DEFAULT
							AND dbo.RAC_RebRateCombination.TestGrp = T2.TestGrp COLLATE DATABASE_DEFAULT
		END

END    
GO
