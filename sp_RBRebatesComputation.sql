-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-11-13
-- Description:	Rebates computation
-- =============================================

ALTER PROCEDURE dbo.sp_RBRebatesComputation
    @Mode VARCHAR(50) = NULL,
	@GenID INT = NULL,
	@PostGenID INT = NULL,
	@TranDate DATE = NULL,
	@isForPayment INT = NULL,
	@WhsCode VARCHAR(MAX) = NULL,
	@EmpID VARCHAR(20) = NULL,
	@PCode VARCHAR(MAX) = NULL,
	@SDate DATE = NULL,
	@EDate DATE = NULL,
	@RebDets UDTRebDets READONLY,
	@RebPayment UDTRebPayment READONLY
AS
    BEGIN
		IF @Mode = 'GetRebatesHdr'
			BEGIN
			--Current Rebates======================================================================================================================================================
				--Actual Rebates
				IF NOT OBJECT_ID('tempDB..#tmpActReb') IS NULL DROP TABLE #tmpActReb
				SELECT	GenID, WhsCode, SUM(ActualRebates) ActualRebates 
				INTO	#tmpActReb
				FROM	dbo.RAC_RBPayments 
				WHERE	GenID = @GenID
				GROUP BY 
						GenID, WhsCode

				--Get Aging Rebates
				IF NOT OBJECT_ID('tempDB..#tmpAgingRebs') IS NULL DROP TABLE #tmpAgingRebs
				SELECT	GenID, WhsCode, 
						SUM(AmountPaid) TotAmountPaid
				INTO	#tmpAgingRebs
				FROM	dbo.RAC_RBAgingHistory 
				WHERE	GenID = @GenID
				GROUP BY 
						GenID, WhsCode

				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPayees') IS NULL DROP TABLE #tmpPayees
				SELECT	DISTINCT 
							PID ,
							PName ,
							Class ,
							AcctNum ,
							Add1 ,
							SlpCode ,
							Hosp ,
							TelNo,
							Actype,
							Periodtype,
							DispatchType,
							IsCrossCheck,
							IsSpecialTest,
							IsActive
				INTO		#tmpPayees
				FROM		dbo.RB_Payees
				WHERE		IsActive = 1
								
				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPayeeScheme') IS NULL DROP TABLE #tmpPayeeScheme
				SELECT		T2.[Desc] PayeeType, T1.Whs, T1.RangeFrom, T1.RangeTo, T1.Percnt, T1.AmntExclusion 
				INTO		#tmpPayeeScheme
				FROM		dbo.RAC_PayeeScheme T1
							LEFT JOIN dbo.RAC_MaintenanceCode T2 ON T2.Type = 'PayeeType' AND T2.Code = T1.PayeeType
				
				--Get the rebates details
				IF NOT OBJECT_ID('tempDB..#tmpRebatesDets') IS NULL DROP TABLE #tmpRebatesDets
				SELECT		T1.GenID, T1.U_PayCode, T1.WhsCode, T1.isForPayment, SUM(T1.RebatesAmnt) RebatesAmnt
				INTO		#tmpRebatesDets
				FROM		dbo.RAC_RBDetailsTrans T1
				WHERE		T1.GenID = @GenID
				GROUP BY	T1.GenID, T1.U_PayCode, T1.WhsCode, T1.isForPayment

				--Get the rebates with schema
				IF NOT OBJECT_ID('tempDB..#tmpActualRebates') IS NULL DROP TABLE #tmpActualRebates
				SELECT		T1.GenID, 
							T1.U_PayCode, 
							ISNULL(T2.PName, '') PName, 
							ISNULL(T2.Add1, '') Add1, 
							ISNULL(T2.Class, '') Class, 
							ISNULL(T2.Actype, '') Actype, 
							ISNULL(T2.Periodtype, '') Periodtype, 
							ISNULL(T2.SlpCode, '') SlpCode, 
							ISNULL(T3.SlpName, '') SlpName, 
							LTRIM(RTRIM(T1.WhsCode)) WhsCode, 
							ISNULL(T1.RebatesAmnt, 0) RebatesAmnt,
							ISNULL(T4.Percnt, 100) Percnt, 
							ISNULL(T5.AmntExclusion, 0) AmntExclusion,
							CAST(ISNULL(T1.RebatesAmnt, 0) * ISNULL(T4.Percnt, 100) / 100 AS DECIMAL(18,2)) ActualReb, 
							T1.isForPayment
				INTO		#tmpActualRebates
				FROM		#tmpRebatesDets T1 WITH(NOLOCK)
							LEFT JOIN #tmpPayees T2 WITH(NOLOCK) ON T2.PID = T1.U_PayCode COLLATE DATABASE_DEFAULT
							LEFT JOIN dbo.OSLP T3 WITH(NOLOCK) ON T3.SlpCode = T2.SlpCode
							LEFT JOIN #tmpPayeeScheme T4 WITH(NOLOCK) ON T4.Whs = T1.WhsCode AND T4.PayeeType = T2.Actype COLLATE DATABASE_DEFAULT 
								AND T1.RebatesAmnt BETWEEN T4.RangeFrom AND T4.RangeTo
							LEFT JOIN (
										SELECT	PayeeType, Whs, AmntExclusion 
										FROM	#tmpPayeeScheme
										GROUP BY 
												PayeeType, Whs, AmntExclusion											
									  ) T5 ON T5.Whs = T1.WhsCode AND T5.PayeeType = T2.Actype COLLATE DATABASE_DEFAULT

				--Get the rebates per branch
				IF NOT OBJECT_ID('tempDB..#tmpTotRebs') IS NULL DROP TABLE #tmpTotRebs
				SELECT		GenID, LTRIM(RTRIM(WhsCode)) WhsCode, SUM(RebatesAmnt) RebatesAmnt
				INTO		#tmpTotRebs
				FROM		RAC_RBDetailsTrans WITH(NOLOCK)
				WHERE		GenID = @GenID
				GROUP BY	GenID, WhsCode
				ORDER BY	CAST(WhsCode AS INT)

				--Get the budget and rebates of branch
				SELECT	T1.GenID,
						T1.WhsCode,
						T3.WhsName,
						ISNULL(T2.Sales, 0.00) Sales,
						ISNULL(T2.BudgetAmnt, 0.00) BudgetAmnt,
						ISNULL(T1.RebatesAmnt, 0.00) RebatesAmnt,
						ISNULL(T4.TotActualReb, 0.00) [ComputedReb],
						ISNULL(T6.ActualRebates, 0.00) TotActualReb,
						ISNULL(T5.TotAmountPaid, 0.00) TotAgingReb,
						ISNULL(CASE WHEN T2.BudgetAmnt - (ISNULL(T6.ActualRebates, 0.00) + ISNULL(T5.TotAmountPaid, 0.00)) >= 0 
								THEN 0 
								ELSE ABS(T2.BudgetAmnt - (ISNULL(T6.ActualRebates, 0.00) + ISNULL(T5.TotAmountPaid, 0.00))) 
							END, 0.00) Excess
				FROM	#tmpTotRebs T1 WITH(NOLOCK)
						LEFT JOIN RAC_BudgetHierarchy T2 WITH(NOLOCK) ON T2.GenID = T1.GenID AND T2.WhsCode = T1.WhsCode
						LEFT JOIN dbo.SAPSet T3 WITH(NOLOCK) ON T3.Code = T1.WhsCode COLLATE DATABASE_DEFAULT
						LEFT JOIN (
									SELECT GenID, WhsCode, SUM(ActualReb) TotActualReb 
									FROM #tmpActualRebates
									WHERE isForPayment = 1
									GROUP BY GenID, WhsCode						
								  ) T4 ON T4.GenID = T1.GenID AND T4.WhsCode = T1.WhsCode
						LEFT JOIN #tmpAgingRebs T5 ON T5.GenID = T1.GenID AND T5.WhsCode = T1.WhsCode
						LEFT JOIN #tmpActReb T6 ON T6.GenID = T1.GenID AND T6.WhsCode = T1.WhsCode
				WHERE	T1.GenID = @GenID

				DROP TABLE #tmpActReb, #tmpAgingRebs, #tmpPayees, #tmpPayeeScheme, #tmpRebatesDets, #tmpActualRebates, #tmpTotRebs
			END

		ELSE IF @Mode = 'GetRebatesDtl'
			BEGIN
				--Get Aging Rebates
				IF NOT OBJECT_ID('tempDB..#tmpAgingRebsD') IS NULL DROP TABLE #tmpAgingRebsD
				SELECT	GenID, WhsCode, PCode, 
						SUM(AmountPaid) TotAmountPaid
				INTO	#tmpAgingRebsD
				FROM	dbo.RAC_RBAgingHistory 
				WHERE	GenID = @GenID
				GROUP BY 
						GenID, WhsCode, PCode

				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPayeeScheme1') IS NULL DROP TABLE #tmpPayeeScheme1
				SELECT		T2.[Desc] PayeeType, T1.Whs, T1.RangeFrom, T1.RangeTo, T1.Percnt, T1.AmntExclusion 
				INTO		#tmpPayeeScheme1
				FROM		dbo.RAC_PayeeScheme T1
							LEFT JOIN dbo.RAC_MaintenanceCode T2 ON T2.Type = 'PayeeType' AND T2.Code = T1.PayeeType
				
				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPayees1') IS NULL DROP TABLE #tmpPayees1
				SELECT	DISTINCT 
							PID ,
							PName ,
							Class ,
							AcctNum ,
							Add1 ,
							SlpCode ,
							Hosp ,
							TelNo,
							Actype,
							Periodtype,
							DispatchType,
							IsCrossCheck,
							IsSpecialTest,
							IsActive
				INTO		#tmpPayees1
				FROM		dbo.RB_Payees
				WHERE		IsActive = 1

				--Get the rebates details
				IF NOT OBJECT_ID('tempDB..#tmpRebatesDets1') IS NULL DROP TABLE #tmpRebatesDets1
				SELECT		T1.GenID, T1.U_PayCode, T1.WhsCode, T1.isForPayment, T1.Stat, SUM(T1.RebatesAmnt) RebatesAmnt
				INTO		#tmpRebatesDets1
				FROM		dbo.RAC_RBDetailsTrans T1
				WHERE		T1.GenID = @GenID
							AND (ISNULL(@WhsCode, '') = '' OR T1.WhsCode = @WhsCode)
				GROUP BY	T1.GenID, T1.U_PayCode, T1.WhsCode, T1.isForPayment, T1.Stat

				--Get the rebates with schema
				SELECT		ISNULL(T1.Stat, 0) [Status], T1.GenID, T1.U_PayCode, ISNULL(T2.PName, '') PName, 
							ISNULL(T2.Add1, '') Add1, ISNULL(T2.Class, '') Class, 
							ISNULL(T2.Actype, '') Actype, ISNULL(T2.Periodtype, '') Periodtype, 
							ISNULL(T2.SlpCode, '') SlpCode, ISNULL(T3.SlpName, '') SlpName, 
							LTRIM(RTRIM(T1.WhsCode)) WhsCode, ISNULL(T1.RebatesAmnt, 0) RebatesAmnt,	
							ISNULL(T4.Percnt, 100) Percnt, ISNULL(T5.AmntExclusion, 0) AmntExclusion,
							ISNULL(CAST(ISNULL(T1.RebatesAmnt, 0) * ISNULL(T4.Percnt, 100) / 100 AS DECIMAL(18,2)), 0) ActualReb,
							ISNULL(T7.TotAmountPaid, 0) AgingReb, T1.isForPayment
				FROM		#tmpRebatesDets1 T1 WITH(NOLOCK)
							LEFT JOIN #tmpPayees1 T2 WITH(NOLOCK) ON T2.PID = T1.U_PayCode COLLATE DATABASE_DEFAULT
							LEFT JOIN dbo.OSLP T3 WITH(NOLOCK) ON T3.SlpCode = T2.SlpCode
							LEFT JOIN #tmpPayeeScheme1 T4 WITH(NOLOCK) ON T4.Whs = T1.WhsCode AND T4.PayeeType = T2.Actype COLLATE DATABASE_DEFAULT 
								AND T1.RebatesAmnt BETWEEN T4.RangeFrom AND T4.RangeTo
							LEFT JOIN (
										SELECT PayeeType, Whs, AmntExclusion 
										FROM #tmpPayeeScheme1
										GROUP BY PayeeType, Whs, AmntExclusion											
									  ) T5 ON T5.Whs = T1.WhsCode AND T5.PayeeType = T2.Actype COLLATE DATABASE_DEFAULT
							--LEFT JOIN dbo.RAC_RBPayments T6 WITH(NOLOCK) ON T6.GenID = T1.GenID AND T6.WhsCode = T1.WhsCode AND T6.PCode = T1.U_PayCode
							LEFT JOIN #tmpAgingRebsD T7 WITH(NOLOCK) ON T7.GenID = T1.GenID AND T7.WhsCode = T1.WhsCode AND T7.PCode = T1.U_PayCode

			END

		ELSE IF @Mode = 'GetPerPayeeRebates'
			BEGIN
				--DECLARE @GenID INT = '107'
				--DECLARE @WhsCode VARCHAR(250) = '002,003,004,006,009,011'

				--Get Aging Rebates
				IF NOT OBJECT_ID('tempDB..#tmpA') IS NULL DROP TABLE #tmpA
				SELECT	GenID, WhsCode, PCode, 
						SUM(AmountPaid) TotAmountPaid
				INTO	#tmpA
				FROM	dbo.RAC_RBAgingHistory 
				WHERE	GenID = @GenID
				GROUP BY 
						GenID, WhsCode, PCode

				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPScheme') IS NULL DROP TABLE #tmpPScheme
				SELECT		T2.[Desc] PayeeType, T1.Whs, T1.RangeFrom, T1.RangeTo, T1.Percnt, T1.AmntExclusion 
				INTO		#tmpPScheme
				FROM		dbo.RAC_PayeeScheme T1
							LEFT JOIN dbo.RAC_MaintenanceCode T2 ON T2.Type = 'PayeeType' AND T2.Code = T1.PayeeType
				
				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpP') IS NULL DROP TABLE #tmpP
				SELECT	DISTINCT 
							PID ,
							PName ,
							Class ,
							AcctNum ,
							Add1 ,
							SlpCode ,
							Hosp ,
							TelNo,
							Actype,
							Periodtype,
							DispatchType,
							IsCrossCheck,
							IsSpecialTest,
							IsActive
				INTO		#tmpP
				FROM		dbo.RB_Payees
				WHERE		IsActive = 1

				
				--Get the rebates details
				IF NOT OBJECT_ID('tempDB..#tmpRBDets1') IS NULL DROP TABLE #tmpRBDets1
				SELECT		T1.GenID, T1.U_PayCode, SUM(T1.RebatesAmnt) RebatesAmnt
				INTO		#tmpRBDets1
				FROM		dbo.RAC_RBDetailsTrans T1
				WHERE		T1.GenID = @GenID
							AND T1.WhsCode IN (SELECT Item FROM  dbo.Split(@WhsCode,','))
							AND ISNULL(T1.Stat, 0) = 0
				GROUP BY	T1.GenID, T1.U_PayCode

				--Final Query
				SELECT	t1.GenID ,
                        t1.U_PayCode ,
						ISNULL(t2.PName, '') PName,
						ISNULL(t1.RebatesAmnt, 0.00) RebatesAmnt,
						ISNULL(t2.Class, '') Class,
						ISNULL(t2.Add1, '') Add1,
						ISNULL(t2.AcctNum, '') AcctNum,
						ISNULL(t2.SlpCode, -1) SlpCode,
						ISNULL(t3.SlpName, '-No Sales Employee-') SlpName,
						ISNULL(t2.Hosp, '') Hosp,
						ISNULL(t2.Periodtype, '') Periodtype,
						ISNULL(t2.DispatchType, '') DispatchType,
						ISNULL(t2.IsCrossCheck, 0) IsCrossCheck,
						ISNULL(t2.IsSpecialTest, 0) IsSpecialTest,
						0 ForPayment
				FROM	#tmpRBDets1 t1
						LEFT JOIN #tmpP t2 ON t2.PID = t1.U_PayCode COLLATE DATABASE_DEFAULT
						LEFT JOIN dbo.OSLP t3 ON t3.SlpCode = t2.SlpCode 

				DROP TABLE #tmpA, #tmpPScheme, #tmpP, #tmpRBDets1
			END

		ELSE IF @Mode = 'PostToChequeMod'
			BEGIN
				--DECLARE @GenID INT = '107'
				--DECLARE @WhsCode VARCHAR(MAX) = '003'
				--DECLARE @TranDate DATE = '3/1/2021'

				--===============================================================
				IF NOT OBJECT_ID('tempDB..#tmpP') IS NULL DROP TABLE #tmpP
				SELECT	DISTINCT 
							PID ,
							PName ,
							Class ,
							AcctNum ,
							Add1 ,
							SlpCode ,
							Hosp ,
							TelNo,
							Actype,
							Periodtype,
							DispatchType,
							IsCrossCheck,
							IsSpecialTest,
							IsActive
				INTO		#tmpP2
				FROM		dbo.RB_Payees
				WHERE		IsActive = 1

				--===============================================================
				IF NOT OBJECT_ID('tempDB..#tmpD') IS NULL DROP TABLE #tmpD
				SELECT 		T1.GenID, T1.U_PayCode, T1.WhsCode, T1.isForPayment, 
							ISNULL(T1.Stat, 0) Stat, SUM(T1.RebatesAmnt) RebatesAmnt
				INTO		#tmpD2
				FROM		dbo.RAC_RBDetailsTrans T1		
				WHERE		T1.GenID = @GenID
							AND T1.WhsCode IN (SELECT Item FROM  dbo.Split(@WhsCode,','))
							AND ISNULL(T1.Stat, 0) = 1
				GROUP BY	T1.GenID, T1.U_PayCode, T1.WhsCode, T1.isForPayment, T1.Stat

				--===============================================================
				--Insert to RAC_ChequeHdr
				INSERT INTO dbo.RAC_ChequeHdr
						(PID, Payment, isCrossCheq, RecDate, TranDate, SlpCode, Stat, GenID)
				SELECT	t1.U_PayCode,
						SUM(t1.RebatesAmnt) RebatesAmnt,
						ISNULL(t2.IsCrossCheck, 0) IsCrossCheck,
						GETDATE() RecDate,
						@TranDate,
						t2.SlpCode,
						3 Stat,
						t1.GenID
				FROM	#tmpD2 t1
						LEFT JOIN #tmpP2 t2 ON t2.PID = t1.U_PayCode COLLATE DATABASE_DEFAULT
				GROUP BY 
						t1.U_PayCode, t2.IsCrossCheck, t2.SlpCode, t1.GenID

				--===============================================================
				--Insert to RAC_ChequeDtl
				INSERT INTO dbo.RAC_ChequeDtl
				        (PID, LineTotal, WhsCode, GenID)
				SELECT	U_PayCode, 
						RebatesAmnt,
						WhsCode,
						GenID
				FROM	#tmpD2
				
				--===============================================================
				--Drop temp table
				DROP TABLE #tmpP2, #tmpD2
			END

		ELSE IF @Mode = 'PaymentPerPayeeReb'
			BEGIN
				--DECLARE @GenID INT = '107'
				--DECLARE @WhsCode VARCHAR(MAX) = '002,003,004,006,009,011'
				--DECLARE @PCode VARCHAR(MAX) = '11261,11481,11166'

				UPDATE		dbo.RAC_RBDetailsTrans
				SET			isForPayment = 1,
							Stat = 1
				FROM		dbo.RAC_RBDetailsTrans T1
				WHERE		T1.GenID = @GenID
							AND T1.U_PayCode IN (SELECT Item FROM dbo.Split(@PCode, ','))
							AND T1.WhsCode IN (SELECT Item FROM  dbo.Split(@WhsCode,','))
							AND ISNULL(T1.Stat, 0) = 0
			END

		ELSE IF @Mode = 'LoadGenID'
			BEGIN
				IF NOT OBJECT_ID('tempDB..#tmpGenIDHdr') IS NULL DROP TABLE #tmpGenIDHdr
				SELECT T1.Code, T1.[Desc], T1.FDate, T1.TDate
				INTO #tmpGenIDHdr
				FROM (
						SELECT	MAX(GenID) + 1 [Code],  'Next GenID - ' + CAST(MAX(GenID) + 1 AS VARCHAR(20)) [Desc], GETDATE() FDate, GETDATE() TDate
						FROM	dbo.SOADate 
						UNION ALL	
						SELECT	GenID [Code], CAST(GenID AS VARCHAR(20)) [Desc], FDate, TDate
						FROM	dbo.SOADate
					) T1
				ORDER BY CAST(T1.Code AS INT) DESC

				--
				SELECT	T1.Code,
						T1.[Desc],
						T1.FDate,
						T1.TDate,
						CASE WHEN T2.paymentDate IS NULL THEN 0 ELSE 1 END isPaid
				FROM	#tmpGenIDHdr T1
						LEFT JOIN dbo.SOADate T2 ON T2.GenID = T1.Code
				ORDER BY CAST(T1.Code AS INT) DESC

				DROP TABLE #tmpGenIDHdr
			END

		ELSE IF @Mode = 'ApplyAmntExclusion'
			BEGIN
				UPDATE	dbo.RAC_RBDetailsTrans
				SET		isForPayment = T1.isForPayment
				FROM	@RebDets T1
				WHERE	dbo.RAC_RBDetailsTrans.GenID = T1.GenID
						AND	dbo.RAC_RBDetailsTrans.WhsCode = T1.WhsCode
						AND	dbo.RAC_RBDetailsTrans.U_PayCode = T1.PCode
						--AND dbo.RAC_RBDetailsTrans.GenID = @GenID

			
			END

		ELSE IF @Mode = 'ApplyAmntExclusion2'
			BEGIN
				UPDATE	dbo.RAC_RBDetailsTrans
				SET		isForPayment = @isForPayment
				FROM	@RebDets T1
				WHERE	dbo.RAC_RBDetailsTrans.GenID = T1.GenID
						AND	dbo.RAC_RBDetailsTrans.WhsCode = T1.WhsCode
						AND	dbo.RAC_RBDetailsTrans.U_PayCode = T1.PCode
						AND dbo.RAC_RBDetailsTrans.GenID = @GenID
			END

		ELSE IF @Mode = 'ApplyPayment'
			BEGIN
				--
				--INSERT INTO dbo.RAC_RBPayments
				--		(GenID, WhsCode, PCode, GrossRebates,
				--		Percentage, ActualRebates, UnPaidRebates,
				--		Status, CreatedBy, CreatedDate)
				--SELECT	GenID,
				--		WhsCode,
				--		PCode,
				--		GrossRebates,
				--		Percentage,
				--		ActualRebates,
				--		UnPaidRebates,
				--		Status,
				--		@EmpID,
				--		GETDATE()
				--FROM	@RebPayment
				
				--Update Status for Apply Payment
				UPDATE	dbo.RAC_RBDetailsTrans
				SET		Stat = 1
				FROM	@RebPayment t1
				WHERE	dbo.RAC_RBDetailsTrans.GenID = t1.GenID
						AND	dbo.RAC_RBDetailsTrans.WhsCode = t1.WhsCode
						AND dbo.RAC_RBDetailsTrans.U_PayCode = t1.PCode
			END
			
		ELSE IF @Mode = 'PostGenID'		
			BEGIN
				DECLARE @RebDetails UDTRebDets 

				INSERT INTO @RebDetails
							(Status, GenID, PCode, PName, Address, Class, Actype, PeriodType,
							SlpCode, SlpName, WhsCode, RebatesAmnt, Percnt, AmntExclusion,
							ActualReb, AgingReb, isForPayment)

				EXEC		sp_RBRebatesComputation @Mode = 'GetRebatesDtl', @GenID = @PostGenID


				IF NOT OBJECT_ID('tempDB..#tmpRbDets') IS NULL DROP TABLE #tmpRbDets
				SELECT		PCode,
							ISNULL(ActualReb, 0.00) + ISNULL(AgingReb, 0.00) LineTotal,
							WhsCode,
							SlpCode,
							GenID
				INTO		#tmpRbDets
				FROM		@RebDetails
				WHERE		Status = 1
							AND isForPayment = 1
							AND ISNULL(ActualReb, 0.00) + ISNULL(AgingReb, 0.00) <> 0

				--Insert into cheque header table
				INSERT INTO dbo.RAC_ChequeHdr
							(PID, Payment, isCrossCheq, RecDate,
							TranDate, SlpCode, Stat, GenID)
				SELECT		T1.PCode,
							SUM(T1.LineTotal) Payment,
							ISNULL(T2.IsCrossCheck, 0) IsCrossCheck,
							GETDATE() RecDate,
							@TranDate,
							T1.SlpCode,
							3 Stat,
							T1.GenID 
				FROM		#tmpRbDets T1
							LEFT JOIN dbo.RB_Payees T2 ON T2.PID = T1.PCode COLLATE DATABASE_DEFAULT
				GROUP BY	T1.PCode, 
							T1.SlpCode, 
							T1.GenID,
							T2.IsCrossCheck


				--Insert into cheque details table
				INSERT INTO dbo.RAC_ChequeDtl
							(PID, LineTotal, WhsCode, RecID, GenID)
				SELECT		PCode ,
							LineTotal ,
							WhsCode ,
							0,
							GenID 
				FROM		#tmpRbDets 
				
				--Update payment date of genid
				UPDATE dbo.SOADate SET paymentDate = GETDATE() WHERE GenID = @PostGenID         
			END

		ELSE IF @Mode = 'CheckingIfPosted'
			BEGIN
				SELECT TOP 1 GenID FROM dbo.RAC_RBDetailsTrans WHERE GenID = @GenID AND ISNULL(Stat, 0) = 2
			END

		ELSE IF @Mode = 'ResetGenID'
			BEGIN
				DELETE FROM dbo.RAC_RBDetailsTrans WHERE GenID = @GenID
				DELETE dbo.SOADate WHERE GenID = @GenID

				UPDATE dbo.inv1 SET	Rebate = NULL
				FROM dbo.oinv t1 
				WHERE dbo.inv1.docentry = t1.docentry
				AND CAST(t1.ReconDate AS DATE) BETWEEN @SDate AND @EDate
			END

		ELSE IF @Mode = 'GetPerPayeePayment'
			BEGIN
				--DECLARE @GenID INT = '108'

				--Get Aging Rebates
				IF NOT OBJECT_ID('tempDB..#tmpAR') IS NULL DROP TABLE #tmpAR
				SELECT	GenID, WhsCode, PCode, 
						SUM(AmountPaid) TotAmountPaid
				INTO	#tmpAR
				FROM	dbo.RAC_RBAgingHistory 
				WHERE	GenID = @GenID
				GROUP BY 
						GenID, WhsCode, PCode

				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPScheme1') IS NULL DROP TABLE #tmpPScheme1
				SELECT		T2.[Desc] PayeeType, T1.Whs, T1.RangeFrom, T1.RangeTo, T1.Percnt, T1.AmntExclusion 
				INTO		#tmpPScheme1
				FROM		dbo.RAC_PayeeScheme T1
							LEFT JOIN dbo.RAC_MaintenanceCode T2 ON T2.Type = 'PayeeType' AND T2.Code = T1.PayeeType
				
				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPS') IS NULL DROP TABLE #tmpPS
				SELECT	DISTINCT 
							PID ,
							PName ,
							Class ,
							AcctNum ,
							Add1 ,
							SlpCode ,
							Hosp ,
							TelNo,
							Actype,
							Periodtype,
							DispatchType,
							IsCrossCheck,
							IsSpecialTest,
							IsActive
				INTO		#tmpPS
				FROM		dbo.RB_Payees
				WHERE		IsActive = 1

				
				--Get the rebates details
				IF NOT OBJECT_ID('tempDB..#tmpRBDets11') IS NULL DROP TABLE #tmpRBDets11
				SELECT		T1.GenID, T1.U_PayCode, SUM(T1.RebatesAmnt) RebatesAmnt
				INTO		#tmpRBDets11
				FROM		dbo.RAC_RBDetailsTrans T1
				WHERE		T1.GenID = @GenID
							AND ISNULL(T1.Stat, 0) = 1
				GROUP BY	T1.GenID, T1.U_PayCode
				
				--Final Query
				SELECT	t1.GenID ,
                        t1.U_PayCode ,
						ISNULL(t2.PName, '') PName,
						ISNULL(t1.RebatesAmnt, 0.00) RebatesAmnt,
						ISNULL(t2.Class, '') Class,
						ISNULL(t2.Add1, '') Add1,
						ISNULL(t2.AcctNum, '') AcctNum,
						ISNULL(t2.SlpCode, -1) SlpCode,
						ISNULL(t3.SlpName, '-No Sales Employee-') SlpName,
						ISNULL(t2.Hosp, '') Hosp,
						ISNULL(t2.Periodtype, '') Periodtype,
						ISNULL(t2.DispatchType, '') DispatchType,
						ISNULL(t2.IsCrossCheck, 0) IsCrossCheck,
						ISNULL(t2.IsSpecialTest, 0) IsSpecialTest,
						0 ForPayment
				FROM	#tmpRBDets11 t1
						LEFT JOIN #tmpPS t2 ON t2.PID = t1.U_PayCode COLLATE DATABASE_DEFAULT
						LEFT JOIN dbo.OSLP t3 ON t3.SlpCode = t2.SlpCode 

				DROP TABLE #tmpAR, #tmpPScheme1, #tmpPS, #tmpRBDets11
			END
	END
GO
