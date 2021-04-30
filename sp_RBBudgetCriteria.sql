-- =============================================
-- Author:		Ralph Salino
-- Create date: 2019-12-11
-- Description:	Rebates Budget Criteria
-- =============================================

ALTER PROCEDURE dbo.sp_RBBudgetCriteria
    @Mode AS VARCHAR(100) = NULL,
	@AccountType AS VARCHAR(50) = NULL,
	@WhsCode AS VARCHAR(10) = NULL,
	@AmntExcluded AS DECIMAL(18,2) = NULL,
	@GenID VARCHAR(10) = NULL,
	@Percentage DECIMAL(18,2) = 3,
	@SDate DATE = '',
	@EDate DATE = '',
	@AsOfDate DATE = ''

AS
    BEGIN
			IF @Mode = 'LoadAccountType'
				BEGIN
								SELECT		DISTINCT Actype [Code], 
											Actype [Desc] 
								FROM		dbo.RB_Payees
				END

			ELSE IF @Mode = 'LoadBranch'
				BEGIN
								SELECT		T1.Code, T1.[Desc]
								FROM		(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
											UNION
											SELECT	Code, WhsName [Desc], 2 [Seq] 
											FROM	dbo.SAPSet 
											WHERE	Stat = 'O') T1
								ORDER BY	T1.Seq
				END

			ELSE IF @Mode = 'AddBudgetCriteria'
				BEGIN
								
								IF @WhsCode = 'All'
									BEGIN
												DECLARE @ctr INT  = 0
												DECLARE @Code AS VARCHAR(10)

												DECLARE cur CURSOR LOCAL FOR
													SELECT Code FROM dbo.SAPSet WHERE Stat = 'O'
												OPEN cur

												FETCH NEXT FROM cur INTO @Code
												WHILE @@FETCH_STATUS = 0
													BEGIN
														IF NOT EXISTS (SELECT WhsCode FROM dbo.RAC_BudgetCriteria WHERE WhsCode = @Code AND AccountType = @AccountType)
															BEGIN
																	INSERT INTO dbo.RAC_BudgetCriteria 
																			(AccountType, WhsCode, AmntExcluded)
																	VALUES
																			(@AccountType, @Code, @AmntExcluded)
																	SET @ctr = @ctr + @@ROWCOUNT	
															END
													FETCH NEXT FROM cur INTO @Code
	
													END
												CLOSE cur
												DEALLOCATE cur
												SELECT @ctr
									END

								ELSE
									BEGIN
												IF NOT EXISTS (SELECT * FROM dbo.RAC_BudgetCriteria WHERE AccountType = @AccountType AND WhsCode = @WhsCode)
													BEGIN
															INSERT INTO dbo.RAC_BudgetCriteria 
																	(AccountType, WhsCode, AmntExcluded)
															VALUES
																	(@AccountType, @WhsCode, @AmntExcluded)
															SELECT @@ROWCOUNT
													END					
									END

				END

			ELSE IF @Mode = 'UpdateBudgetCriteria'
				BEGIN
								UPDATE		dbo.RAC_BudgetCriteria
								SET			AmntExcluded = @AmntExcluded
								WHERE		AccountType = @AccountType 
											AND WhsCode = @WhsCode
				END

			ELSE IF @Mode = 'LoadBudgetCriteria'
				BEGIN
								IF @AccountType = '' BEGIN SET @AccountType = NULL END 
								IF @WhsCode = '' BEGIN SET @WhsCode = NULL END ELSE IF @WhsCode = 'All' BEGIN SET @WhsCode = NULL END

								SELECT		T1.AccountType,
											T1.WhsCode,
											T2.WhsName,
											T1.AmntExcluded 
								FROM		dbo.RAC_BudgetCriteria T1
											LEFT JOIN  dbo.SAPSet T2 WITH(NOLOCK) ON T1.WhsCode = T2.Code COLLATE DATABASE_DEFAULT
								WHERE		(@AccountType IS NULL OR T1.AccountType = @AccountType)
											AND (@WhsCode IS NULL OR  T1.WhsCode = @WhsCode)
				END

			ELSE IF @Mode = 'LoadGenIDDetails'
				BEGIN
								SELECT		GenID [Code], GenID [Desc], 
											CAST(DATENAME(MONTH, FDate) AS VARCHAR(50)) + ' ' + 
											CAST(DAY(FDate) AS VARCHAR(10)) + ' - ' + 
											CAST(DAY(TDate) AS VARCHAR(10)) + ', ' + 
											CAST(DATENAME(YEAR, FDate) AS VARCHAR(50)) [DateRange]
								FROM		dbo.SOADate	
								ORDER BY	GenID DESC
				END

			ELSE IF @Mode = 'CheckingBudget'
				BEGIN
								SELECT DISTINCT GenID FROM dbo.RAC_BudgetHierarchy WHERE GenID = @GenID
				END

			ELSE IF @Mode = 'CreateBudgetHierarchy'
				BEGIN
								--Get the parameter dates
								SET @SDate = (SELECT FDate FROM dbo.SOADate WHERE GenID = @GenID)
								SET @EDate = (SELECT TDate FROM dbo.SOADate WHERE GenID = @GenID)
								SET @AsOfDate = (SELECT AsOfDate FROM dbo.SOADate WHERE GenID = @GenID)

								--Get the sales total
								IF NOT OBJECT_ID('tempDB..#tmp1') IS null DROP TABLE #tmp1
								CREATE TABLE  #tmp1 (
									yr INT,
									mo INT,
									WhsCode VARCHAR(20) COLLATE SQL_Latin1_General_CP850_CI_AS,
									ItemName VARCHAR(50) COLLATE SQL_Latin1_General_CP850_CI_AS,
									ItemCode VARCHAR(200) COLLATE SQL_Latin1_General_CP850_CI_AS,
									qty DECIMAL(18,2),
									amt DECIMAL(18,2) )

								INSERT INTO #tmp1(yr, mo, WhsCode, ItemName, ItemCode, qty, amt)
								EXEC dbo.sp_GenCensus @SDate = @SDate,
													  @EDate = @EDate 


								--Get Sales per Branch
								IF NOT OBJECT_ID('tempDB..#tmpSales') IS NULL DROP TABLE #tmpSales
								SELECT		WhsCode, SUM(amt) [Sales]
								INTO		#tmpSales
								FROM		#tmp1
								GROUP BY	WhsCode
								ORDER BY	CAST(WhsCode AS INT)


								--Get Rebates Detail for specified genid
								SELECT		T1.WhsCode, T1.Rebate
								INTO		#tmp2
								FROM		dbo.RBDets T1 WITH(NOLOCK)
								WHERE		ISNULL(T1.ComType, '') <> ''
											AND ISNULL(T1.isForPaymnt, 0) = 0
											AND GenID BETWEEN @GenID - 1 AND @GenID


								--Get Rebate per branch
								IF NOT OBJECT_ID('tempDB..#tmpRebates') IS NULL DROP TABLE #tmpRebates
								SELECT		WhsCode, SUM(ISNULL(Rebate, 0)) [Rebate]
								INTO		#tmpRebates
								FROM		#tmp2
								GROUP BY	WhsCode


								--Budget Details
								IF NOT OBJECT_ID('tempDB..#tmpBudgetDets') IS NULL DROP TABLE #tmpBudgetDets
								SELECT		T1.WhsCode, T3.WhsName, T1.Sales, 2 [Percent], T1.Sales * 0.02 [BudgetAmnt],  T2.Rebate,
											CASE WHEN (T1.Sales * 0.02) - T2.Rebate >= 0 THEN 0 ELSE ABS((T1.Sales * 0.02) - T2.Rebate) END [Excess],
											(T2.Rebate / T1.Sales) * 100 [PercentToActSales]
								INTO		#tmpBudgetDets
								FROM		#tmpSales T1
											LEFT JOIN #tmpRebates T2 ON T2.WhsCode = T1.WhsCode
											LEFT JOIN dbo.SAPSet T3 ON T3.Code = T1.WhsCode
								
								--Final Query
								INSERT INTO dbo.RAC_BudgetHierarchy(GenID, WhsCode, Sales, Prcent, BudgetAmnt, Rebates, ExcessToBudget, PrcntToSales)
								SELECT	@GenID, WhsCode, Sales, [Percent], BudgetAmnt, Rebate, Excess, PercentToActSales 
								FROM	#tmpBudgetDets
				END

			ELSE IF @Mode = 'LoadBudgetHierarchyDets'
				BEGIN
								SELECT	T1.WhsCode, T2.WhsName, ISNULL(T1.Sales, 0) Sales, 
										T1.Prcent, ISNULL(T1.BudgetAmnt, 0) BudgetAmnt,
										ISNULL(T1.Rebates, 0) Rebates, ISNULL(T1.ExcessToBudget, 0) ExcessToBudget, 
										ISNULL(T1.PrcntToSales, 0) PrcntToSales, T1.GenID
								FROM	dbo.RAC_BudgetHierarchy T1 WITH(NOLOCK)
										LEFT JOIN dbo.SAPSet T2 WITH(NOLOCK) ON T2.Code = T1.WhsCode COLLATE DATABASE_DEFAULT
								WHERE	T1.GenID = @GenID
				END


			ELSE IF @Mode = 'UpdateBudget'
				BEGIN
								UPDATE	RAC_BudgetHierarchy 
								SET		Prcent = @Percentage,
										BudgetAmnt = Sales * @Percentage / 100,
										ExcessToBudget = CASE WHEN (Sales * @Percentage / 100) - Rebates >= 0 
																THEN 0 
																ELSE ABS((Sales * @Percentage / 100) - Rebates) 
														END
								WHERE	GenID = @GenID AND RTRIM(LTRIM(WhsCode)) = @WhsCode
				END

			ELSE IF @Mode = 'ResetBudget'
				BEGIN
								DELETE dbo.RAC_BudgetHierarchy WHERE GenID = @GenID
				END
	END
GO
