-- =============================================
-- Author:		Ralph Salino
-- Create date: 2019-11-20
-- Description:	Rebates Computation
-- =============================================

ALTER PROCEDURE dbo.sp_RBRebComputation
    @Mode AS VARCHAR(100) = NULL,
	@GenID AS INT = NULL,
	@PayCode AS VARCHAR(50) = NULL,
	@CutOffDate AS DATE = NULL,
	@PayName AS VARCHAR(100) = NULL,
	@StartDate AS DATE = NULL,
	@EndDate AS DATE = NULL,
	@AsOfDate AS DATE = NULL,
	@PerCent AS DECIMAL(10,2) = NULL,
	@WhsCode AS VARCHAR(10) = NULL,
	@DocEntry AS INT = NULL,
	@Payment AS DECIMAL(18,2) = NULL,
	@LineTotal AS DECIMAL(18,2) = NULL,
	@TranDate AS DATE = NULL,
	@SlpCode AS VARCHAR(10) = NULL, 
	@Stat AS INT = NULL,
	@PayeeType AS VARCHAR(10) = NULL,
	@RecID AS INT = NULL,
	@BudgetCri AS DECIMAL(18,2) = NULL,
	@Enabled INT = NULL,
	@IsEnabled INT = NULL,
	@SchedStartDate INT = NULL,
	@SchedEndDate INT = NULL,
	@SchedStartTime VARCHAR(10) = NULL,
	@GenStartDate DATE = NULL,
	@GenEndDate DATE = NULL,
	@GenAsOfDate DATE = NULL,
	@CreatedBy VARCHAR(50) = NULL,
	@CreatedDate DATE = NULL,
	@UpdatedBy VARCHAR(50) = NULL,
	@UpdatedDate DATE = NULL,
	@EmpID VARCHAR(20) = NULL

AS


DECLARE @NextGenID INT = NULL
DECLARE @ReturnValue INT = NULL
DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
DECLARE @ErrorState INT = ERROR_STATE()
DECLARE @PaymentDate DATE = NULL

    BEGIN

	DECLARE @LocMode AS VARCHAR(100) = @Mode
	DECLARE @LocGenID AS INT = @GenID
	DECLARE @LocPayCode AS VARCHAR(50) = @PayCode
	DECLARE @LocCutOffDate AS DATE = (SELECT AsOfDate FROM dbo.SOADate WHERE GenID = @LocGenID)
	DECLARE @LocPayName AS VARCHAR(100) = @PayName
	DECLARE @LocStartDate AS DATE = @StartDate
	DECLARE @LocEndDate AS DATE = @EndDate
	DECLARE @LocAsOfDate AS DATE = @AsOfDate
	DECLARE @LocPerCent AS DECIMAL(10,2) = @PerCent
	DECLARE @LocWhsCode AS VARCHAR(10) = @WhsCode
	DECLARE @LocNextGenID AS INT = @LocGenID + 1
	DECLARE @LocPayeeType AS VARCHAR(50) = @PayeeType
	DECLARE @LocBudgetCri AS DECIMAL(18,2) = @BudgetCri
	

	IF @LocWhsCode = 'All' BEGIN SET @LocWhsCode = NULL END

		IF @LocMode = 'LoadBranch'
			BEGIN
								SELECT		T1.Code, T1.[Desc]
								FROM		(SELECT	'All' [Code], 'All' [Desc], 1 [Seq]
											UNION
											SELECT	Code, WhsName [Desc], 2 [Seq] 
											FROM	dbo.SAPSet 
											WHERE	Stat = 'O') T1
								ORDER BY
											T1.Seq
			END

		ELSE IF @LocMode = 'LoadGenID'
			BEGIN
								SELECT		GenID [Code], GenID [Desc]
								FROM		dbo.SOADate	
								ORDER BY	GenID DESC				
			END

		ELSE IF @LocMode = 'LoadGenIDBudget'
			BEGIN
								SELECT		GenID [Code], GenID [Desc]
								FROM		dbo.RAC_RebBudgetHdr
			END

		ELSE IF @LocMode = 'LoadPayees'
			BEGIN
								SELECT		PID [Code],
											PID + ' - ' + PName + ' - ' + Class [Desc]
								FROM		dbo.RB_Payees
								WHERE		PName NOT LIKE '%DONT%'
			END

		ELSE IF @LocMode = 'NextGenID'
			BEGIN
								SELECT		MAX(GenID) + 1 [NextGenId] 
								FROM		dbo.SOADate
			END
			
		ELSE IF @Mode = 'LoadGenIDWithOutPayment'
			BEGIN
								SELECT		T1.Code, T1.[Desc], T1.[Order] 
								FROM		(SELECT		0 [Code], 'Next GenID - ' +  CAST(MAX(GenID) + 1 AS VARCHAR(10)) [Desc], 1 [Order]
												FROM		dbo.SOADate
												UNION
												SELECT		GenID [Code], CAST(GenID AS VARCHAR(10)) [Desc], 2 [Order]
												FROM		dbo.SOADate
												WHERE		paymentDate IS NULL ) T1
								ORDER BY	T1.[Order], T1.Code DESC
			END

		ELSE IF @Mode = 'LoadPayeeType'
			BEGIN
								SELECT DISTINCT 
											UPPER(T1.PayDesc) [CODE] ,
											UPPER(T1.PayDesc) [DESC] 
								FROM		dbo.rbPayType T1 WITH(NOLOCK)
								ORDER BY	[DESC]
			END
			
		ELSE IF @LocMode = 'GetForPaymentPerPayee'
			BEGIN
								--EXEC dbo.sp_RBRebComputation @Mode = 'GetForPaymentPerPayee', @PayeeType = 'CLINICIAN', @GenID = 93, @WhsCode = 'All', @BudgetCri = '1000.00'
								--DECLARE @LocGenID AS INT = 93
								--DECLARE @LocWhsCode AS VARCHAR(10) = 'All'
								--DECLARE @LocPayeeType AS VARCHAR(10) = 'CLINICIAN'
								--DECLARE @LocCutOffDate AS DATE = (SELECT AsOfDate FROM dbo.SOADate WHERE GenID = @LocGenID)
								--DECLARE @LocBudgetCri AS DECIMAL(18,2) = '0.00'
								--IF @LocWhsCode = 'All' SET @LocWhsCode = NULL

								IF NOT OBJECT_ID('tempDB..#tmpRbDets') IS NULL DROP TABLE #tmpRbDets
								SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, CAST(Cast(@LocCutOffDate AS DATETIME) - ReconDate AS INT) NDys, 
											T1.U_DoctorCode, T1.GroupCode, T2.Actype, T1.Rebate, ISNULL(T1.isExcluded, 0) [isExcluded], T1.GenID, 
											ISNULL(T1.isForPaymnt, '0') [isForPaymnt]
								INTO		#tmpRbDets
								FROM		dbo.RBDets T1
											LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
								WHERE		(@LocWhsCode IS NULL OR T1.WhsCode = @LocWhsCode) 
											AND T2.Actype = @LocPayeeType
											AND ISNULL(T1.ComType, '') <> ''
											AND ISNULL(T1.isForPaymnt, 0)  = 0
											AND GenID BETWEEN 92 AND @LocGenID
								

								--=========Get the transaction passed in budget
								--1.
								IF NOT OBJECT_ID('tempDB..#tmpRebatesBudget') IS NULL DROP TABLE #tmpRebatesBudget
								SELECT		U_PayCode,
											WhsCode,
											Actype,
											SUM(Rebate) [Rebate],
											isForPaymnt
								INTO		#tmpRebatesBudget
								FROM		#tmpRbDets
								GROUP BY	U_PayCode,
											Actype,
											WhsCode,
											isForPaymnt
								
								
								--2.
								IF NOT OBJECT_ID('tempDB..#tmpRebatesTotal') IS NULL DROP TABLE #tmpRebatesTotal
								SELECT		T1.U_PayCode,
											T1.Actype,
											T1.Rebate,
											ISNULL(T2.AmntExcluded, '0.00') [AmntExcluded],
											CASE WHEN T1.Rebate > ISNULL(T2.AmntExcluded, '0.00') THEN 1 ELSE 0 END [BudgetStat],
											T1.isForPaymnt
								INTO		#tmpRebatesTotal
								FROM		#tmpRebatesBudget T1
											LEFT JOIN dbo.RAC_BudgetCriteria T2 ON T1.WhsCode = T2.WhsCode COLLATE DATABASE_DEFAULT 
												AND T1.Actype = T2.AccountType COLLATE DATABASE_DEFAULT
								
								--3
								IF NOT OBJECT_ID('tempDB..#tmpRebGTotal') IS NULL DROP TABLE #tmpRebGTotal
								SELECT		U_PayCode,
											Actype,
											SUM(Rebate) [Rebate],
											isForPaymnt
								INTO		#tmpRebGTotal
								FROM		#tmpRebatesTotal 
								WHERE		BudgetStat = 1
								GROUP BY	U_PayCode,
											Actype,
											isForPaymnt
								
								
								--=========Get the Aging of Rebates
								--1. Identify the number of days of rebates aging
								IF NOT OBJECT_ID('tempDB..#tmpAgingIdentifyCol') IS NULL DROP TABLE #tmpAgingIdentifyCol
								SELECT		U_PayCode,
											SUM(ISNULL(Rebate,0)) [Rebate],
											NDys,
											CASE WHEN NDys < 0 THEN 'Curr' 
												 WHEN NDys BETWEEN 0 AND 30 THEN 'D01_30'
												 WHEN NDys BETWEEN 31 AND 60 THEN 'D31_60'
												 WHEN NDys BETWEEN 61 AND 90 THEN 'D61_90'
												 WHEN NDys BETWEEN 91 AND 120 THEN 'D91_120'
												 WHEN NDys > 120 THEN 'Over120' END [Aging]
								INTO		#tmpAgingIdentifyCol
								FROM		#tmpRbDets
								GROUP BY	U_PayCode, NDys
								

								--2. Create the columns for aging
								IF NOT OBJECT_ID('tempDB..#tempCols') IS NULL DROP TABLE #tempCols
								SELECT		T1.*
								INTO		#tempCols
								FROM		(SELECT 'D01_30' Aging
											UNION
											SELECT 'D31_60' Aging 
											UNION
											SELECT 'D61_90' Aging
											UNION
											SELECT 'D91_120' Aging
											UNION
											SELECT 'Over120' Aging)T1
								

								--3. Pivot the Columns
								IF NOT OBJECT_ID('tempDB..#tmpAgingTbl') IS NULL DROP TABLE #tmpAgingTbl
								SELECT		*
								INTO		#tmpAgingTbl
								FROM		(SELECT		T1.U_PayCode,
														T1.Rebate,
														T1.Aging
											FROM		#tmpAgingIdentifyCol T1
														INNER JOIN	#tempCols T2 ON T2.Aging = T1.Aging) t
								PIVOT		(SUM(Rebate) FOR Aging IN ([Curr], [D01_30], [D31_60], [D61_90], [D91_120], [Over120])) AS pivot_table


								--=========Final Query
								SELECT		T1.U_PayCode [Paycode],
											ISNULL(T3.PName, 'NO SETUP') [Payname],
											ISNULL(T1.Rebate, '0.00') [Budget],
											ISNULL(T2.D01_30, '0.00') [D01_30],
											ISNULL(T2.D31_60, '0.00') [D31_60], 
											ISNULL(T2.D61_90, '0.00') [D61_90], 
											ISNULL(T2.D91_120, '0.00') [D91_120], 
											ISNULL(T2.Over120, '0.00') [Over120],
											ISNULL(T3.Add1, '') [Add1],
											ISNULL(T4.SlpName, '') [SlpName],
											ISNULL(T3.AcctNum, '') [AcctNum],
											ISNULL(T3.TelNo, '') [TelNo],
											T4.SlpCode,
											T1.Actype,
											T1.isForPaymnt
								FROM		#tmpRebGTotal T1
											LEFT JOIN #tmpAgingTbl T2 ON T2.U_PayCode = T1.U_PayCode
											LEFT JOIN dbo.RB_Payees T3 ON T3.PID = T1.U_PayCode
											LEFT JOIN dbo.OSLP T4 ON T4.SlpCode = T3.SlpCode
								WHERE		(@LocBudgetCri IS NULL OR ISNULL(T1.Rebate, '0.00') > @LocBudgetCri)
								
			END

		ELSE IF @Mode = 'GetPaymentDets'
			BEGIN
								IF NOT OBJECT_ID('tempDB..#tmpRbDets1') IS NULL DROP TABLE #tmpRbDets1
								SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, CAST(Cast(@LocCutOffDate AS DATETIME) - ReconDate AS INT) NDys, 
											T1.U_DoctorCode, T1.GroupCode, T2.Actype, T1.Rebate, ISNULL(T1.isExcluded, 0) [isExcluded]
								INTO		#tmpRbDets1
								FROM		dbo.RBDets T1
											LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
								WHERE		(@LocWhsCode IS NULL OR T1.WhsCode = @LocWhsCode) 
											AND T1.U_PayCode = @LocPayCode
											AND ISNULL(T1.ComType, '') <> ''
											AND GenID BETWEEN @LocGenID AND @LocNextGenID		
								

								--Get the No of days for aging
								IF NOT OBJECT_ID('tempDB..#tmpAging1') IS NULL DROP TABLE #tmpAging1
								SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
											T1.GroupCode, T1.Actype, NDys, SUM(T1.Rebate ) [Rebate], T1.isExcluded
								INTO		#tmpAging1
								FROM		#tmpRbDets1 T1 WITH(NOLOCK)
								GROUP BY	T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
											T1.GroupCode, T1.Actype, NDys, T1.isExcluded


								--Get the transaction passed in budget criteria
								IF NOT OBJECT_ID('tempDB..#tmpRebWithBudget1') IS NULL DROP TABLE #tmpRebWithBudget1
								SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
											T1.GroupCode, T1.NDys, T1.Rebate, ISNULL(T2.AmntExcluded, '0.00') [AmntExcluded], 
											CASE WHEN T1.Rebate > ISNULL(T2.AmntExcluded, '0.00') THEN 0 ELSE 1 END [BudgetStat], T1.isExcluded
								INTO		#tmpRebWithBudget1
								FROM		#tmpAging1 T1 WITH(NOLOCK)
											LEFT JOIN dbo.RAC_BudgetCriteria T2 WITH(NOLOCK) ON T1.Actype = T2.AccountType COLLATE DATABASE_DEFAULT
												AND T1.WhsCode = T2.WhsCode COLLATE DATABASE_DEFAULT

								--Final Query
								SELECT		DocEntry, U_PayCode, U_LabNo, CardCode, WhsCode, U_DoctorCode, GroupCode, 
											NDys, SUM(Rebate) [Rebate], BudgetStat, isExcluded
								FROM		#tmpRebWithBudget1
								GROUP BY	DocEntry, U_PayCode, U_LabNo, CardCode, WhsCode, U_DoctorCode, GroupCode, 
											NDys, BudgetStat, isExcluded
			END

		ELSE IF @Mode = 'GetPaymentDetsPerWhs'
			BEGIN
								--28023
								--EXEC dbo.sp_RBRebComputation @Mode = 'GetPaymentDetsPerWhs', @GenID = 93, @WhsCode = '004', @PayCode = '15588'
								--DECLARE @LocGenID AS INT = 93
								--DECLARE @LocWhsCode AS VARCHAR(10) = 'All'
								--DECLARE @LocPayCode AS VARCHAR(50) = '28023'
								--DECLARE @LocCutOffDate AS DATE = (SELECT AsOfDate FROM dbo.SOADate WHERE GenID = @LocGenID)

								IF @LocWhsCode = 'All' SET @LocWhsCode = NULL

								--Get 
								IF NOT OBJECT_ID('tempDB..#tmpRbDets44') IS NULL DROP TABLE #tmpRbDets44
								SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, CAST(Cast(@LocCutOffDate AS DATETIME) - ReconDate AS INT) NDys, 
											T1.U_DoctorCode, T1.GroupCode, T2.Actype, T1.Rebate, ISNULL(T1.isExcluded, 0) [isExcluded]
								INTO		#tmpRbDets44
								FROM		dbo.RBDets T1
											LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
								WHERE		(@LocWhsCode IS NULL OR T1.WhsCode = @LocWhsCode) 
											AND T2.Actype = @LocPayeeType
											AND ISNULL(T1.ComType, '') <> ''
											AND ISNULL(T1.isForPaymnt, 0)  = 0
											AND GenID BETWEEN 92 AND @LocGenID	
											AND T1.U_PayCode = @LocPayCode
								
								
								--Get the rebate pass in budget criteria
								--1.
								IF NOT OBJECT_ID('tempDB..#tmpReb44') IS NULL DROP TABLE #tmpReb44
								SELECT		U_PayCode,
											WhsCode,
											Actype,
											SUM(Rebate) [Rebate]
								INTO		#tmpReb44
								FROM		#tmpRbDets44
								GROUP BY	U_PayCode,
											WhsCode,
											Actype


								--2. Final Query
								SELECT		T1.U_PayCode,
											T1.WhsCode,
											T1.Actype,
											T1.Rebate,
											ISNULL(T2.AmntExcluded, '0.00') [AmntExcluded],
											CASE WHEN T1.Rebate > ISNULL(T2.AmntExcluded, '0.00') THEN 1 ELSE 0 END [BudgetStat]
								FROM		#tmpReb44 T1
											LEFT JOIN dbo.RAC_BudgetCriteria T2 ON T1.WhsCode = T2.WhsCode COLLATE DATABASE_DEFAULT 
												AND T1.Actype = T2.AccountType COLLATE DATABASE_DEFAULT
			END

		ELSE IF @Mode = 'ExcludeTran'
			BEGIN
								UPDATE		dbo.RBDets
								SET			isExcluded = 1
								WHERE		DocEntry = @DocEntry
											AND GenID = @GenID
								SELECT @@ROWCOUNT
			END
			
		ELSE IF @LocMode = 'GenerateRebates'
			BEGIN
								--EXEC dbo.sp_RBRebComputation @LocMode = 'GenerateRebates', @LocGenID = 93, @LocStartDate = '2019-07-01', @LocEndDate = '2019-07-01', @LocAsOfDate = '2019-08-10'
								IF @LocGenID = 0 BEGIN	SET @LocGenID = (SELECT MAX(GenID) + 1 FROM dbo.SOADate) END

								--Insert New GenID
								INSERT INTO dbo.SOADate
									(FDate, TDate, GenID, AsOfDate)
								VALUES
									(@LocStartDate, @LocEndDate, @LocGenID, @LocAsOfDate)
								SELECT @@ROWCOUNT
			END

		ELSE IF @Mode = 'ResetRebatesGen'
			BEGIN
								--DECLARE @GenID INT = 89
								--DECLARE @StartDate DATE = NULL
								--DECLARE @EndDate DATE = NULL
								--DECLARE @PaymentDate DATE = NULL
								--DECLARE @StartDateDate DATE = NULL
								--DECLARE @EndDateDate DATE = NULL
								
								SET @PaymentDate = (SELECT paymentDate FROM dbo.SOADate WHERE GenID = @GenID)
								SET @StartDate = (SELECT FDate FROM dbo.SOADate WHERE GenID = @GenID)
								SET @EndDate = (SELECT TDate FROM dbo.SOADate WHERE GenID = @GenID)

								IF @PaymentDate IS NULL
									BEGIN
										--Delete the header of Rebates Generation
										DELETE dbo.SOADate WHERE GenID = @GenID
										
										--Delete the details of Rebates
										DELETE dbo.RBDets WHERE GenID = @GenID

										--Update the Invoices 
										UPDATE	dbo.inv1
										SET		Rebate = NULL
										FROM	dbo.oinv T1
										WHERE	T1.docentry = dbo.inv1.docentry
												AND dbo.inv1.Rebate = @GenID
												AND T1.ReconDate BETWEEN @StartDate AND @EndDate

										SELECT 'Done'
									END
								ELSE 
									BEGIN
										SELECT 'Cant reset this GenID due to this was already paid'
									END
			END

		ELSE IF @LocMode = 'CreateBudget'
			BEGIN
								--DECLARE @LocGenID AS INT = 93 
								--DECLARE @LocStartDate AS DATE = NULL
								--DECLARE @LocEndDate AS DATE = NULL
								--DECLARE @LocCutOffDate AS DATE = (SELECT AsOfDate FROM dbo.SOADate WHERE GenID = @LocGenID)

								IF EXISTS(SELECT * FROM dbo.RAC_RebBudgetHdr WHERE GenID = @LocGenID) 
									BEGIN
											DELETE dbo.RAC_RebBudgetHdr WHERE GenID = @LocGenID
											DELETE dbo.RAC_RebBudgetDtl WHERE GenID = @LocGenID
									END

								--==================Sales
								--1. Extacting sales per branch
								SET @LocStartDate = (SELECT FDate FROM dbo.SOADate WHERE GenID = @LocGenID)
								SET @LocEndDate = (SELECT TDate FROM dbo.SOADate WHERE GenID = @LocGenID)

								IF NOT OBJECT_ID('tempDB..#tmpSales') IS NULL DROP TABLE #tmpSales
								SELECT		T1.Segment_1, 
											SUM(T0.[Credit]) - SUM(T0.[Debit]) [Sales]
								INTO		#tmpSales
								FROM		HPDI..JDT1 T0 WITH(NOLOCK)
											INNER JOIN HPDI..OJDT T6 WITH(NOLOCK) ON T0.TransID = T6.TransID 
											INNER JOIN HPDI..OACT T1 WITH(NOLOCK) ON T0.Account = T1.AcctCode 
								WHERE		T1.Segment_0 = '40100'
											AND T6.[RefDate] BETWEEN @LocStartDate AND @LocEndDate
								GROUP BY 	Segment_1
												
												
								--2. Extracting total Sales
								IF NOT OBJECT_ID('tempDB..#tmpTotSales') IS NULL DROP TABLE #tmpTotSales
								SELECT		CAST(SUM(Sales) AS DECIMAL(11,2)) [TotalSales], 
											@LocGenID [GenID] 
								INTO		#tmpTotSales
								FROM		#tmpSales
								

								--==================Rebates
								--Get Rebates Detail for specified genid
								IF NOT OBJECT_ID('tempDB..#tmpRbDets444') IS NULL DROP TABLE #tmpRbDets444
								SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, CAST(Cast(@LocCutOffDate AS DATETIME) - ReconDate AS INT) NDys, 
											T1.U_DoctorCode, T1.GroupCode, T2.Actype, T1.Rebate, ISNULL(T1.isExcluded, 0) [isExcluded]
								INTO		#tmpRbDets444
								FROM		dbo.RBDets T1
											LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
								WHERE		ISNULL(T1.ComType, '') <> ''
											AND ISNULL(T1.isForPaymnt, 0) = 0
											AND GenID BETWEEN 92 AND @LocGenID	
								

								--Get the rebate pass in budget criteria
								--1.
								IF NOT OBJECT_ID('tempDB..#tmpReb444') IS NULL DROP TABLE #tmpReb444
								SELECT		U_PayCode,
											WhsCode,
											Actype,
											SUM(Rebate) [Rebate]
								INTO		#tmpReb444
								FROM		#tmpRbDets444
								GROUP BY	U_PayCode,
											WhsCode,
											Actype
								

								--2. 
								IF NOT OBJECT_ID('tempDB..#tmpFQry') IS NULL DROP TABLE #tmpFQry
								SELECT		T1.U_PayCode,
											T1.WhsCode,
											T1.Actype,
											T1.Rebate,
											ISNULL(T2.AmntExcluded, '0.00') [AmntExcluded],
											CASE WHEN T1.Rebate > ISNULL(T2.AmntExcluded, '0.00') THEN 1 ELSE 0 END [BudgetStat]
								INTO		#tmpFQry
								FROM		#tmpReb444 T1
											LEFT JOIN dbo.RAC_BudgetCriteria T2 ON T1.WhsCode = T2.WhsCode COLLATE DATABASE_DEFAULT 
												AND T1.Actype = T2.AccountType COLLATE DATABASE_DEFAULT

								--3. Get the rebates per branch
								IF NOT OBJECT_ID('tempDB..#tmpRebates') IS NULL DROP TABLE #tmpRebates
								SELECT		WhsCode,
											SUM(Rebate) [Rebate]
								INTO		#tmpRebates
								FROM		#tmpFQry
								WHERE		BudgetStat = 1
								GROUP BY	WhsCode


								--4. Get total rebates
								IF NOT OBJECT_ID('tempDB..#tmpTotReb') IS NULL DROP TABLE #tmpTotReb
								SELECT		@LocGenID [GenID],
											SUM(Rebate) [Rebate]
								INTO		#tmpTotReb
								FROM		#tmpFQry


								--==================Final Query
								--1. Header
								INSERT INTO dbo.RAC_RebBudgetHdr
											(GenID, StartDate, EndDate, TotalSales, TotalRebate, RecDate)
								SELECT		T1.GenID, @LocStartDate, @LocEndDate, T1.TotalSales, ISNULL(T2.Rebate, '0.00'), GETDATE()
								FROM		#tmpTotSales T1 
											LEFT JOIN #tmpTotReb T2 ON T2.GenID = T1.GenID
															

								--2. Detail
								IF @@ROWCOUNT > 0
									BEGIN 
											INSERT INTO	dbo.RAC_RebBudgetDtl
												(GenID, WhsCode, Sales, Percnt, BudgetAmt, Rebates)
											SELECT		@LocGenID,
														T1.Segment_1,
														CAST(T1.Sales AS DECIMAL(11,2)) [Sales],
														2 [Percent],
														CAST(CAST(T1.Sales AS DECIMAL(11,2)) * 2 / 100 AS DECIMAL(11,2)) [Budget],
														ISNULL(T2.Rebate, '0.00') 
											FROM		#tmpSales T1 WITH(NOLOCK)
														LEFT JOIN #tmpRebates T2 ON T1.Segment_1 = T2.WhsCode
											SELECT @@ROWCOUNT
									END
			END

		ELSE IF @LocMode = 'LoadBudgetHdr'
			BEGIN
									IF NOT OBJECT_ID('tempDB..#tmpBudgetCurr') IS NULL DROP TABLE #tmpBudgetCurr
									SELECT		T1.GenID,
												T1.StartDate,
												T1.EndDate,
												CAST(SUM(ISNULL(T2.Sales, '0.00')) AS DECIMAL(11,2)) TotalSales,
												CAST(SUM(ISNULL(T2.BudgetAmt, '0.00')) AS DECIMAL(11,2)) TotalBudget,
												CAST(SUM(ISNULL(T2.Rebates, '0.00')) AS DECIMAL(11,2)) TotalRebate,
												CAST(SUM(ISNULL(T2.BudgetAmt, '0.00')) - SUM(ISNULL(T2.Rebates, '0.00')) AS DECIMAL(11,2)) TotalExcess,
												CAST(SUM(ISNULL(T2.Rebates, '0.00')) / SUM(ISNULL(T2.Sales, '0.00')) * 100 AS DECIMAL(11,2)) TotalPrcntToSales
									FROM		dbo.RAC_RebBudgetHdr T1 WITH(NOLOCK)
												INNER JOIN dbo.RAC_RebBudgetDtl T2 WITH(NOLOCK) ON T1.GenID = T2.GenID
									WHERE		T1.GenID = @LocGenID
									GROUP BY	T1.GenID,
												T1.StartDate,
												T1.EndDate
			END

		ELSE IF @LocMode = 'LoadBudget'
			BEGIN
									SELECT		RTRIM(T1.WhsCode) [BranchCode],
												T2.Blk [BranchName],
												T1.Sales,
												ISNULL(T1.Percnt, 0) [Percnt],
												ISNULL(T1.BudgetAmt, 0) [BudgAmt],
												ISNULL(T1.Rebates, 0) [Rebates],
												ISNULL(T1.BudgetAmt, 0) - ISNULL(T1.Rebates, 0) [Excess],
												CAST(ISNULL(T1.Rebates, 0) / ISNULL(T1.Sales,0) * 100 AS DECIMAL(10,2)) [PercntOfActSales]
									FROM		dbo.RAC_RebBudgetDtl T1 WITH(NOLOCK)
												LEFT JOIN dbo.SAPSet T2 WITH(NOLOCK) ON T1.WhsCode = T2.Code COLLATE DATABASE_DEFAULT
									ORDER BY	T1.WhsCode
			END

		ELSE IF @LocMode = 'UpdBudgtPrcnt'
			BEGIN
									UPDATE		dbo.RAC_RebBudgetDtl
									SET			Percnt = @LocPerCent
									WHERE		GenID = @LocGenID AND WhsCode = @LocWhsCode
									SELECT @@ROWCOUNT


									IF @@ROWCOUNT > 0
										BEGIN
												UPDATE		dbo.RAC_RebBudgetDtl
												SET			BudgetAmt = CAST(CAST(sales AS DECIMAL(11,2)) * Percnt / 100 AS DECIMAL(11,2))
												WHERE		GenID = @LocGenID AND WhsCode = @LocWhsCode
										END

			END

		ELSE IF @LocMode = 'GeneratePaymentHdr'
			BEGIN

									--EXEC sp_rbrebcomputation @Mode = 'GeneratePaymentHdr', @WhsCode = '004', @GenID = 93

									--
									IF NOT OBJECT_ID('tempDB..#tmpRbDets2') IS NULL DROP TABLE #tmpRbDets2
									SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, CAST(Cast(@LocCutOffDate AS DATETIME) - ReconDate AS INT) NDys, 
												T1.U_DoctorCode, T1.GroupCode, T2.Actype, T1.Rebate, ISNULL(T1.isExcluded, 0) [isExcluded], T2.SlpCode, T1.GenID
									INTO		#tmpRbDets2
									FROM		dbo.RBDets T1
												LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
									WHERE		(@LocWhsCode IS NULL OR T1.WhsCode = @LocWhsCode) 
												AND ISNULL(T1.ComType, '') <> ''
												AND GenID = @LocGenID
								

									--Get the No of days for aging
									IF NOT OBJECT_ID('tempDB..#tmpAging2') IS NULL DROP TABLE #tmpAging2
									SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
												T1.GroupCode, T1.Actype, NDys, SUM(T1.Rebate ) [Rebate], T1.isExcluded, T1.SlpCode, T1.GenID
									INTO		#tmpAging2
									FROM		#tmpRbDets2 T1 WITH(NOLOCK)
									GROUP BY	T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
												T1.GroupCode, T1.Actype, NDys, T1.isExcluded, T1.SlpCode, T1.GenID


									--Get the transaction passed in budget criteria
									IF NOT OBJECT_ID('tempDB..#tmpRebWithBudget2') IS NULL DROP TABLE #tmpRebWithBudget2
									SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
												T1.GroupCode, T1.NDys, T1.Rebate, ISNULL(T2.AmntExcluded, '0.00') [AmntExcluded], 
												CASE WHEN T1.Rebate > ISNULL(T2.AmntExcluded, '0.00') THEN 1 ELSE 0 END [BudgetStat], T1.isExcluded, T1.SlpCode, T1.GenID
									INTO		#tmpRebWithBudget2
									FROM		#tmpAging2 T1 WITH(NOLOCK)
												LEFT JOIN dbo.RAC_BudgetCriteria T2 WITH(NOLOCK) ON T1.Actype = T2.AccountType COLLATE DATABASE_DEFAULT
													AND T1.WhsCode = T2.WhsCode COLLATE DATABASE_DEFAULT

									--
									IF NOT OBJECT_ID('tempDB..#tmpPayment2') IS NULL DROP TABLE #tmpPayment2
									SELECT		DocEntry, U_PayCode, U_LabNo, CardCode, WhsCode, U_DoctorCode, GroupCode, 
												NDys, SUM(Rebate) [Rebate], BudgetStat, isExcluded, SlpCode, GenID
									INTO		#tmpPayment2
									FROM		#tmpRebWithBudget2
									WHERE		BudgetStat = 1 AND isExcluded = 0
									GROUP BY	DocEntry, U_PayCode, U_LabNo, CardCode, WhsCode, U_DoctorCode, GroupCode, 
												NDys, BudgetStat, isExcluded, SlpCode, GenID


									--Header for cheque payment
									SELECT		T1.U_PayCode, SUM(T1.Rebate) [Payment], GETDATE() [RecDate], T2.FDate [TranDate],
												T1.SlpCode, 3 [Stat]
									FROM		#tmpPayment2 T1
												LEFT JOIN dbo.SOADate T2 ON T2.GenID = T1.GenID
									GROUP BY	T1.U_PayCode, T1.SlpCode, T2.FDate
			END

		ELSE IF @LocMode = 'GeneratePaymentDtl'
			BEGIN

									--EXEC sp_rbrebcomputation @Mode = 'GeneratePaymentDtl', @WhsCode = '004', @GenID = 93, @PayCode = '11447'

									--
									IF NOT OBJECT_ID('tempDB..#tmpRbDets3') IS NULL DROP TABLE #tmpRbDets3
									SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, CAST(Cast(@LocCutOffDate AS DATETIME) - ReconDate AS INT) NDys, 
												T1.U_DoctorCode, T1.GroupCode, T2.Actype, T1.Rebate, ISNULL(T1.isExcluded, 0) [isExcluded], T2.SlpCode, T1.GenID
									INTO		#tmpRbDets3
									FROM		dbo.RBDets T1
												LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
									WHERE		(@LocWhsCode IS NULL OR T1.WhsCode = @LocWhsCode)
												AND T1.U_PayCode = @PayCode
												AND ISNULL(T1.ComType, '') <> ''
												AND GenID = @LocGenID

								
									--Get the No of days for aging
									IF NOT OBJECT_ID('tempDB..#tmpAging3') IS NULL DROP TABLE #tmpAging3
									SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
												T1.GroupCode, T1.Actype, NDys, SUM(T1.Rebate ) [Rebate], T1.isExcluded, T1.SlpCode, T1.GenID
									INTO		#tmpAging3
									FROM		#tmpRbDets3 T1 WITH(NOLOCK)
									GROUP BY	T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
												T1.GroupCode, T1.Actype, NDys, T1.isExcluded, T1.SlpCode, T1.GenID


									--Get the transaction passed in budget criteria
									IF NOT OBJECT_ID('tempDB..#tmpRebWithBudget3') IS NULL DROP TABLE #tmpRebWithBudget3
									SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, T1.U_DoctorCode,
												T1.GroupCode, T1.NDys, T1.Rebate, ISNULL(T2.AmntExcluded, '0.00') [AmntExcluded], 
												CASE WHEN T1.Rebate > ISNULL(T2.AmntExcluded, '0.00') THEN 1 ELSE 0 END [BudgetStat], T1.isExcluded, T1.SlpCode, T1.GenID
									INTO		#tmpRebWithBudget3
									FROM		#tmpAging3 T1 WITH(NOLOCK)
												LEFT JOIN dbo.RAC_BudgetCriteria T2 WITH(NOLOCK) ON T1.Actype = T2.AccountType COLLATE DATABASE_DEFAULT
													AND T1.WhsCode = T2.WhsCode COLLATE DATABASE_DEFAULT

								
									--Detail for cheque payment
									SELECT		U_PayCode, WhsCode, SUM(Rebate) [Rebate]
									FROM		#tmpRebWithBudget3
									WHERE		BudgetStat = 1 AND isExcluded = 0
									GROUP BY	U_PayCode, WhsCode
			END

		ELSE IF @Mode = 'GenerateCheqHdr'
			BEGIN
									INSERT INTO	dbo.RAC_ChequeHdr
											(PID, Payment, isCrossCheq, RecDate, TranDate, SlpCode, Stat, GenID)
									VALUES
											(@PayCode, @Payment, 1, GETDATE(), @TranDate, @SlpCode, 3, @GenID)
									SELECT	SCOPE_IDENTITY()
			END
			
		ELSE IF @Mode = 'GenerateCheqDtl'
			BEGIN
									INSERT INTO dbo.RAC_ChequeDtl
											(PID, LineTotal, WhsCode, RecID)
									VALUES
											(@PayCode, @LineTotal, @WhsCode, @RecID)
									SELECT	@@ROWCOUNT
			END


		ELSE IF @Mode = 'UpdatePaymentDetails'
			BEGIN
									--DECLARE @LocWhsCode AS VARCHAR(10) = '023'
									--DECLARE @LocGenID AS INT = 93
									--DECLARE @LocPayCode AS VARCHAR(50) = '28324'
									--DECLARE @LocPayeeType AS VARCHAR(50) = 'CLINICIAN'
									--DECLARE @LocCutOffDate AS DATE = (SELECT AsOfDate FROM dbo.SOADate WHERE GenID = @LocGenID)
									
									--Get the the details for payment
									IF NOT OBJECT_ID('tempDB..#tmpRbDets6') IS NULL DROP TABLE #tmpRbDets6
									SELECT		T1.DocEntry, T1.U_PayCode, T1.U_LabNo, T1.CardCode, T1.WhsCode, CAST(Cast(@LocCutOffDate AS DATETIME) - ReconDate AS INT) NDys, 
												T1.U_DoctorCode, T1.GroupCode, T2.Actype, T1.Rebate, ISNULL(T1.isExcluded, 0) [isExcluded]
									INTO		#tmpRbDets6
									FROM		dbo.RBDets T1
												LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
									WHERE		T1.WhsCode = @LocWhsCode
												AND T1.GenID = @LocGenID
												AND T1.U_PayCode = @LocPayCode
												AND	T2.Actype = @LocPayeeType

									--Get the docentry of the following details for payment
									IF NOT OBJECT_ID('tempDB..#tmpForPayment') IS NULL DROP TABLE #tmpForPayment
									SELECT		DocEntry
									INTO		#tmpForPayment
									FROM		#tmpRbDets6
									GROUP BY	DocEntry

									--Update the isForPayment column of selected docentry (Ready for payment - Cheque Module)
									UPDATE		dbo.RBDets
									SET			isForPaymnt = 1
									FROM		#tmpForPayment T1
									WHERE		dbo.RBDets.DocEntry = T1.DocEntry
									SELECT		@@ROWCOUNT									
			END

		ELSE IF @Mode = 'GetActualBudget'
			BEGIN
									--DECLARE @LocGenID AS INT = 93
									--DECLARE @LocWhsCode AS VARCHAR(10) = 'All'
									--DECLARE @LocPayeeType AS VARCHAR(10) = 'CLINICIAN'
									--DECLARE @LocCutOffDate AS DATE = (SELECT AsOfDate FROM dbo.SOADate WHERE GenID = @LocGenID)
									IF @LocWhsCode = 'All' SET @LocWhsCode = NULL

									--Get the the list of for payment
									IF NOT OBJECT_ID('tempDB..#tmpRbDetsPaid') IS NULL DROP TABLE #tmpRbDetsPaid
									SELECT		T1.GenID, T2.Actype, ISNULL(SUM(T1.Rebate),0) [Rebate]
									INTO		#tmpRbDetsPaid
									FROM		dbo.RBDets T1
												LEFT JOIN dbo.RB_Payees T2 WITH(NOLOCK) ON T1.U_PayCode = T2.PID COLLATE DATABASE_DEFAULT
									WHERE		(@LocWhsCode IS NULL OR T1.WhsCode = @LocWhsCode) 
												AND T2.Actype = @LocPayeeType
												AND ISNULL(T1.ComType, '') <> ''
												AND ISNULL(T1.isForPaymnt, 0)  = 1
												AND GenID BETWEEN 92 AND @LocGenID
									GROUP BY	T1.GenID, T2.Actype

									
									--Get the list of 
									IF NOT OBJECT_ID('tempDB..#tmpRebBudgetDtl') IS NULL DROP TABLE #tmpRebBudgetDtl
									SELECT		ISNULL(SUM(T1.Sales), 0) [ToTSales],
												ISNULL(SUM(T1.BudgetAmt), 0) [TotBudget],
												T1.GenID
									INTO		#tmpRebBudgetDtl
									FROM		dbo.RAC_RebBudgetDtl T1
									WHERE		T1.GenID = @LocGenID
												AND (@LocWhsCode IS NULL OR T1.WhsCode = @LocWhsCode)
									GROUP BY	T1.GenID
											
									--Final Query
									IF EXISTS(SELECT * FROM #tmpRbDetsPaid WHERE GenID = @LocGenID)
										BEGIN
												--with paid rebates
												SELECT		T1.ToTSales, T1.TotBudget - T2.Rebate [TotBudget], T1.GenID
												FROM		#tmpRebBudgetDtl T1
															LEFT JOIN #tmpRbDetsPaid T2 ON T1.GenID = T2.GenID
										END
									ELSE
										BEGIN
												--without paid rebates
												SELECT		ToTSales, TotBudget, GenID 
												FROM		#tmpRebBudgetDtl
										END

			END

		ELSE IF @Mode = 'GetTranDate'
			BEGIN
									SELECT FDate FROM dbo.SOADate WHERE GenID = @LocGenID
			END

		ELSE IF @Mode = 'LoadSchedGenID'
			BEGIN
									SELECT		T1.Code, T1.[Desc], T1.[Order] 
									FROM		(SELECT		0 [Code], 'Next GenID - ' +  CAST(MAX(GenID) + 1 AS VARCHAR(10)) [Desc], 1 [Order]
												 FROM		dbo.SOADate
												 UNION
												 SELECT		GenID [Code], CAST(GenID AS VARCHAR(10)) [Desc], 2 [Order]
												 FROM		dbo.SOADate) T1
									ORDER BY	T1.[Order], T1.Code DESC	
			END
			
		ELSE IF @Mode = 'CreateSchedRebatesGen'
			BEGIN
									--BEGIN TRY
												SET @SchedStartTime = (SELECT REPLACE(@SchedStartTime, ':', '') + '00')
												IF @GenID = 0 BEGIN	SET @GenID = (SELECT MAX(GenID) + 1 FROM dbo.SOADate) END

												IF NOT EXISTS (SELECT * FROM dbo.SOADate WHERE GenID = @GenID)
													BEGIN
																--Update the schedule of jobs for generation of rebates
																EXEC msdb.dbo.sp_update_schedule @schedule_id = 31, 
																								 @enabled = @IsEnabled, 
																								 @active_start_date = @SchedStartDate,
																								 @active_end_date = @SchedEndDate,
																								 @active_start_time = @SchedStartTime
																					
																IF @@ROWCOUNT > 0
																	BEGIN
																			--Create header for rebates generation (SOADate)
																			INSERT INTO dbo.SOADate
																				(FDate, TDate, GenID, AsOfDate)
																			VALUES
																				(@GenStartDate, @GenEndDate, @GenID, @GenAsOfDate)
																	END

																IF @@ROWCOUNT > 0 
																	BEGIN
																			--Create schedule of rebates generation (RAC_RebSchedGeneration)
																			INSERT INTO dbo.RAC_RebSchedGeneration
																				(GenID, SchedStartDate, SchedEndDate, SchedStartTime, isEnabled, CreatedBy, CreatedDate)
																			VALUES
																				(@GenID, @SchedStartDate, @SchedEndDate, @SchedStartTime, @IsEnabled, @EmpID, GETDATE())
																	END
																IF @@ROWCOUNT > 0 BEGIN SET @ReturnValue = 1 END ELSE BEGIN SET @ReturnValue = 0 END
													END
												ELSE
													BEGIN
																--Update the schedule of jobs for generation of rebates
																EXEC msdb.dbo.sp_update_schedule @schedule_id = 31, 
																									@enabled = @IsEnabled, 
																									@active_start_date = @SchedStartDate,
																									@active_end_date = @SchedEndDate,
																									@active_start_time = @SchedStartTime

																IF @@ROWCOUNT > 0
																	BEGIN
																			--Update header for rebates generation (SOADate)
																			UPDATE	dbo.SOADate
																			SET		FDate = @GenStartDate,
																					TDate = @GenEndDate,
																					AsOfDate = @GenAsOfDate
																			WHERE	GenID = @GenID
																	END

																IF @@ROWCOUNT > 0
																	BEGIN
																			--Update schedule of rebates generation (RAC_RebSchedGeneration)
																			UPDATE	dbo.RAC_RebSchedGeneration 
																			SET		SchedStartDate = @SchedStartDate,
																					SchedEndDate = @SchedEndDate,
																					SchedStartTime = @SchedStartTime,
																					isEnabled = @IsEnabled,
																					UpdatedBy = @EmpID,
																					UpdatedDate = GETDATE()
																			WHERE	GenID = @GenID
																	END
																IF @@ROWCOUNT > 0 BEGIN SET @ReturnValue = 1 END ELSE BEGIN SET @ReturnValue = 0 END
													END
												SELECT @ReturnValue
									--END TRY
									--BEGIN CATCH
									--	RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState)
									--END CATCH
			END

		ELSE IF @Mode = 'ExecSchedRebatesGen'
			BEGIN
									DECLARE @GenIDSched INT = NULL
									DECLARE @StartDateSched DATE = NULL
									DECLARE @EndDateSched DATE = NULL
									DECLARE @AsOfDateSched DATE = NULL


									IF NOT OBJECT_ID('tempDB..#tmpSchedDate') IS NULL DROP TABLE #tmpSchedDate
									SELECT	T1.GenID, T1.FDate, T1.TDate, T1.AsOfDate, T2.SchedStartDate,
											T2.SchedEndDate, T2.SchedStartTime, T2.CreatedBy, T2.CreatedDate,
											T2.UpdatedBy, T2.UpdatedDate, T2.isEnabled
									INTO	#tmpSchedDate
									FROM	dbo.SOADate T1
											INNER JOIN dbo.RAC_RebSchedGeneration T2 ON T1.GenID = T2.GenID
									WHERE	T2.isEnabled = 1

									--
									SET @GenIDSched = (SELECT GenID FROM #tmpSchedDate)
									SET @StartDateSched = (SELECT FDate FROM #tmpSchedDate)
									SET @EndDateSched = (SELECT TDate FROM #tmpSchedDate)
									SET @AsOfDateSched = (SELECT AsOfDate FROM #tmpSchedDate)
									--SELECT @GenID, @StartDate, @EndDate, @AsOfDate

									--
									EXEC dbo.RB_Insert_RBINV_NEW @SDate = @StartDateSched,
																 @EDate = @EndDateSched,
																 @AsOfDate = @AsOfDateSched,
																 @GenID = @GenIDSched

									EXEC dbo.RB_11_InsertDet
			END

		ELSE IF @Mode = 'GenerateGenIDDetails'
			BEGIN
									SELECT	ISNULL(T1.GenID, '') [GenID], ISNULL(T1.FDate, '') [FDate], ISNULL(T1.TDate, '') [TDate], ISNULL(T1.AsOfDate, '') [AsOfDate], 
											ISNULL(CONVERT(DATETIME, CONVERT(VARCHAR(10), T2.SchedStartDate)), '') [SchedStartDate], 
											ISNULL(CONVERT(DATETIME, CONVERT(VARCHAR(10), T2.SchedEndDate)), '') [SchedEndDate], 
											ISNULL(CAST(STUFF(STUFF(STUFF(cast(CAST(T2.SchedStartTime AS VARCHAR(10)) + '00' as varchar),3,0,':'),6,0,':'),9,0,'.') AS TIME), '') [SchedStartTime], 
											T2.isEnabled
									FROM	dbo.SOADate T1
											INNER JOIN dbo.RAC_RebSchedGeneration T2 ON T1.GenID = T2.GenID
									WHERE	T1.GenID = @GenID
			END
	END
GO
