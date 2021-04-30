-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-11-24
-- Description:	Rebates Aging
-- =============================================

ALTER PROCEDURE dbo.sp_RBAgingComp
    @Mode VARCHAR(100) = NULL,
	@WhsCode VARCHAR(10) = NULL,
	@PCode VARCHAR(10) = NULL,
	@EmpID VARCHAR(20) = NULL,
	@UTblAging UDT_RBAgingHistory READONLY

AS
DECLARE @MaxGenID INT
    BEGIN
		IF @Mode = 'GetMaxGenID'
			BEGIN
				SELECT GenID, FDate, TDate FROM dbo.SOADate WHERE GenID IN 
				(SELECT MAX(GenID) FROM dbo.SOADate WHERE ISNULL(CAST(paymentDate AS VARCHAR(50)), '') = '' )
			END

		ELSE IF @Mode = 'AgingHdr'
			BEGIN
				SET @MaxGenID = (SELECT MAX(GenID) FROM dbo.SOADate WHERE ISNULL(CAST(paymentDate AS VARCHAR(50)), '') = '')
				--SET @MaxGenID = 103

				--1
				IF NOT OBJECT_ID('tempDB..#tmpAgingHistoryH') IS NULL DROP TABLE #tmpAgingHistoryH
				SELECT	WhsCode, 
						SUM(AmountPaid) AmountPaid
				INTO	#tmpAgingHistoryH
				FROM	dbo.RAC_RBAgingHistory
				WHERE	GenID = @MaxGenID
				GROUP BY
						WhsCode, ABS(CAST(CAST(paymentDate AS DATETIME) - CreatedDate AS INT))

				--2
				IF NOT OBJECT_ID('tempDB..#tmpPaymentsH') IS NULL DROP TABLE #tmpPaymentsH
				SELECT	T1.WhsCode,
						ABS(CAST(CAST(T3.paymentDate AS DATETIME) - GETDATE() AS INT)) NoDays,
						SUM(T1.UnPaidRebates) UnPaidRebates
				INTO	#tmpPaymentsH
				FROM	dbo.RAC_RBPayments T1
						LEFT JOIN dbo.SOADate T3 ON T3.GenID = T1.GenID
				WHERE	ISNULL(T1.UnPaidRebates, 0) <> 0 
						AND	T1.Status = 2
				GROUP BY 
						T1.WhsCode, CAST(CAST(T3.paymentDate AS DATETIME) - GETDATE() AS INT)

				--3
				IF NOT OBJECT_ID('tempDB..#tmpHDR') IS NULL DROP TABLE #tmpHDR
				SELECT	T1.WhsCode, 
						T1.NoDays, ISNULL(T2.AmountPaid, 0.00) AmountPaid, 
						ISNULL(ISNULL(T1.UnPaidRebates, 0.00) - ISNULL(T2.AmountPaid, 0.00), 0.00) UnPaidRebates
				INTO	#tmpHDR
				FROM	#tmpPaymentsH T1
						LEFT JOIN #tmpAgingHistoryH T2 ON T2.WhsCode = T1.WhsCode


				--Get the actual rebates
				IF NOT OBJECT_ID('tempDB..#tmpCurrRebs') IS NULL DROP TABLE #tmpCurrRebs
				SELECT		WhsCode, SUM(ActualRebates) ActualRebates
				INTO		#tmpCurrRebs
				FROM		dbo.RAC_RBPayments 
				WHERE		GenID = @MaxGenID AND ActualRebates <> 0 AND Status = 1
				GROUP BY	WhsCode

				--
				IF NOT OBJECT_ID('tempDB..#tmpAging') IS NULL DROP TABLE #tmpAging
				SELECT	WhsCode,
						NoDays,
						SUM(AmountPaid) AmountPaid,
						SUM(UnPaidRebates) UnPaidRebates,
						CASE WHEN CAST(NoDays AS INT) BETWEEN 0 AND 30 THEN 'D01_30'
								WHEN CAST(NoDays AS INT) BETWEEN 31 AND 60 THEN 'D31_60'
								WHEN CAST(NoDays AS INT) BETWEEN 61 AND 90 THEN 'D61_90'
								WHEN CAST(NoDays AS INT) BETWEEN 91 AND 120 THEN 'D91_120'
								WHEN CAST(NoDays AS INT) > 120 THEN 'Over120' END Aging
				INTO	#tmpAging
				FROM	#tmpHDR
				GROUP BY
						WhsCode, NoDays

				--
				IF NOT OBJECT_ID('tempDB..#tempCols') IS NULL DROP TABLE #tempCols
				SELECT	T1.*
				INTO	#tempCols
				FROM	(SELECT 'D01_30' Aging
						UNION
						SELECT 'D31_60' Aging 
						UNION
						SELECT 'D61_90' Aging
						UNION
						SELECT 'D91_120' Aging
						UNION
						SELECT 'Over120' Aging)T1


				--
				SELECT	PT1.WhsCode,
						PT1.WhsName,
						PT1.AmountPaid TotAmntToPay,
						CAST(ISNULL(PT1.BudgetAmnt, 0.00) AS DECIMAL(18,2)) BudgetAmnt,
						CAST(ISNULL(PT1.ActualRebates, 0.00) AS DECIMAL(18,2)) CurrRebs,
						CAST(0.00 AS DECIMAL(18,2)) TotExcess,
						CAST(ISNULL(PT1.D01_30, 0.00) AS DECIMAL(18,2)) D01_30,
						CAST(ISNULL(PT1.D31_60, 0.00) AS DECIMAL(18,2)) D31_60,
						CAST(ISNULL(PT1.D61_90, 0.00) AS DECIMAL(18,2)) D61_90,
						CAST(ISNULL(PT1.D91_120, 0.00) AS DECIMAL(18,2)) D91_120,
						CAST(ISNULL(PT1.Over120, 0.00) AS DECIMAL(18,2)) Over120, 
						CAST(ISNULL(PT1.D01_30, 0.00) AS DECIMAL(18,2)) + CAST(ISNULL(PT1.D31_60, 0.00) AS DECIMAL(18,2)) + 
						CAST(ISNULL(PT1.D61_90, 0.00) AS DECIMAL(18,2)) + CAST(ISNULL(PT1.D91_120, 0.00) AS DECIMAL(18,2)) + 
						CAST(ISNULL(PT1.Over120, 0.00) AS DECIMAL(18,2)) TotalAging
				FROM 
						(
						SELECT	T1.WhsCode,
								T3.WhsName,
								T1.AmountPaid,
								T5.BudgetAmnt,
								T4.ActualRebates,
								T1.NoDays,
								T1.UnPaidRebates,
								T1.Aging 
						FROM	#tmpAging T1
								INNER JOIN #tempCols T2 ON T2.Aging = T1.Aging
								LEFT JOIN dbo.SAPSet T3 ON T3.Code = T1.WhsCode COLLATE DATABASE_DEFAULT
								LEFT JOIN #tmpCurrRebs T4 ON T4.WhsCode = T1.WhsCode
								LEFT JOIN dbo.RAC_BudgetHierarchy T5 ON T5.GenID = @MaxGenID AND T5.WhsCode = T1.WhsCode
						) T1
				PIVOT	(SUM(UnPaidRebates) FOR Aging IN ([D01_30], [D31_60], [D61_90], [D91_120], [Over120])) AS PT1
			END

		ELSE IF @Mode = 'AgingDtl'
			BEGIN
				SET @MaxGenID = (SELECT MAX(GenID) FROM dbo.SOADate WHERE ISNULL(CAST(paymentDate AS VARCHAR(50)), '') = '')
				--SET @MaxGenID = 103
			
				--1
				IF NOT OBJECT_ID('tempDB..#tmpAgingHistory') IS NULL DROP TABLE #tmpAgingHistory
				SELECT	PCode, 
						WhsCode, 
						ABS(CAST(CAST(PaymentDate AS DATETIME) - CreatedDate AS INT)) NoDays,
						SUM(AmountPaid) AmountPaid
				INTO	#tmpAgingHistory
				FROM	dbo.RAC_RBAgingHistory
				WHERE	GenID = @MaxGenID
				GROUP BY
						PCode, WhsCode, ABS(CAST(CAST(paymentDate AS DATETIME) - CreatedDate AS INT))
				

				--2
				IF NOT OBJECT_ID('tempDB..#tmpPayments') IS NULL DROP TABLE #tmpPayments
				SELECT	T1.PCode,
						T1.WhsCode,
						ABS(CAST(CAST(T3.paymentDate AS DATETIME) - GETDATE() AS INT)) NoDays,
						SUM(T1.UnPaidRebates) UnPaidRebates
				INTO	#tmpPayments
				FROM	dbo.RAC_RBPayments T1
						LEFT JOIN dbo.SOADate T3 ON T3.GenID = T1.GenID
				WHERE	ISNULL(T1.UnPaidRebates, 0) <> 0 
						AND	T1.Status = 2
				GROUP BY 
						T1.PCode, T1.WhsCode, CAST(CAST(T3.paymentDate AS DATETIME) - GETDATE() AS INT)
				

				--3
				IF NOT OBJECT_ID('tempDB..#tmpDTL') IS NULL DROP TABLE #tmpDTL
				SELECT	T1.PCode, T1.WhsCode, --ISNULL(T1.Stat, T2.Stat) Stat,
						T1.NoDays, ISNULL(T2.AmountPaid, 0.00) AmountPaid, 
						ISNULL(ISNULL(T1.UnPaidRebates, 0.00) - ISNULL(T2.AmountPaid, 0.00), 0.00) UnPaidRebates,
						CASE WHEN ISNULL(T2.AmountPaid, 0.00) > 0.00 THEN 1 ELSE 0 END Stat
				INTO	#tmpDTL
				FROM	#tmpPayments T1
						LEFT JOIN #tmpAgingHistory T2 ON T2.PCode = T1.PCode AND T2.WhsCode = T1.WhsCode
				

				--====================================================================================================================================================
				--Get the actual rebates
				IF NOT OBJECT_ID('tempDB..#tmpCurrRebsDet') IS NULL DROP TABLE #tmpCurrRebsDet
				SELECT		WhsCode, PCode, SUM(ActualRebates) ActualRebates
				INTO		#tmpCurrRebsDet
				FROM		dbo.RAC_RBPayments 
				WHERE		GenID = @MaxGenID AND ActualRebates <> 0 AND Status = 1
				GROUP BY	WhsCode, PCode


				--
				IF NOT OBJECT_ID('tempDB..#tmpAgingDtl') IS NULL DROP TABLE #tmpAgingDtl
				SELECT	WhsCode,
						PCode,
						NoDays,
						SUM(AmountPaid) AmountPaid,
						SUM(UnPaidRebates) UnPaidRebates,
						CASE WHEN CAST(NoDays AS INT) BETWEEN 0 AND 30 THEN 'D01_30'
							 WHEN CAST(NoDays AS INT) BETWEEN 31 AND 60 THEN 'D31_60'
							 WHEN CAST(NoDays AS INT) BETWEEN 61 AND 90 THEN 'D61_90'
							 WHEN CAST(NoDays AS INT) BETWEEN 91 AND 120 THEN 'D91_120'
							 WHEN CAST(NoDays AS INT) > 120 THEN 'Over120' END Aging,
						Stat
				INTO	#tmpAgingDtl
				FROM	#tmpDTL
				GROUP BY
						WhsCode, PCode, NoDays, Stat

				
				--
				IF NOT OBJECT_ID('tempDB..#tempColsDtl') IS NULL DROP TABLE #tempColsDtl
				SELECT	T1.*
				INTO	#tempColsDtl
				FROM	(SELECT 'D01_30' Aging
						UNION
						SELECT 'D31_60' Aging 
						UNION
						SELECT 'D61_90' Aging
						UNION
						SELECT 'D91_120' Aging
						UNION
						SELECT 'Over120' Aging)T1


				--
				SELECT	PT1.PCode,
						PT1.PName,
						PT1.WhsCode,
						CAST(PT1.AmountPaid AS DECIMAL(18,2)) AmntToPay,
						CAST(ISNULL(PT1.ActualRebates, 0.00) AS DECIMAL(18,2)) CurrRebs,
						CAST(CAST(ISNULL(PT1.D01_30, 0.00) AS DECIMAL(18,2)) + 
							CAST(ISNULL(PT1.D31_60, 0.00) AS DECIMAL(18,2)) + 
							CAST(ISNULL(PT1.D61_90, 0.00) AS DECIMAL(18,2)) + 
							CAST(ISNULL(PT1.D91_120, 0.00) AS DECIMAL(18,2)) + 
							CAST(ISNULL(PT1.Over120, 0.00) AS DECIMAL(18,2)) AS DECIMAL(18,2)) TotAgingDets,
						CAST(ISNULL(PT1.D01_30, 0.00) AS DECIMAL(18,2)) D01_30,
						CAST(ISNULL(PT1.D31_60, 0.00) AS DECIMAL(18,2)) D31_60,
						CAST(ISNULL(PT1.D61_90, 0.00) AS DECIMAL(18,2)) D61_90,
						CAST(ISNULL(PT1.D91_120, 0.00) AS DECIMAL(18,2)) D91_120,
						CAST(ISNULL(PT1.Over120, 0.00) AS DECIMAL(18,2)) Over120,
						PT1.Class,
						PT1.Add1,
						PT1.Hosp,
						PT1.Actype,
						PT1.Stat
				FROM 
						(
						SELECT T1.WhsCode,
							   T1.PCode,
							   T5.PName,
							   T1.AmountPaid,
							   T4.ActualRebates,
							   T1.NoDays,
							   T1.UnPaidRebates,
							   T1.Aging,
							   T5.Class,
							   T5.Add1,
							   T5.Hosp,
							   T5.Actype,
							   T1.Stat
						FROM #tmpAgingDtl T1
						INNER JOIN #tempColsDtl T2 ON T2.Aging = T1.Aging
						LEFT JOIN #tmpCurrRebsDet T4 ON T4.WhsCode = T1.WhsCode AND T4.PCode = T1.PCode
						LEFT JOIN dbo.RB_Payees T5 ON T5.PID = T1.PCode COLLATE DATABASE_DEFAULT
						) T1
				PIVOT	(SUM(UnPaidRebates) FOR Aging IN ([D01_30], [D31_60], [D61_90], [D91_120], [Over120])) AS PT1
			END

		ELSE IF @Mode = 'GetAgingData'
			BEGIN
				SELECT	T1.RecID, T1.GenID, T1.WhsCode, T1.PCode, 
						T1.UnPaidRebates, 0.00 AmntToPay, T2.paymentDate
				FROM	dbo.RAC_RBPayments T1
						LEFT JOIN dbo.SOADate T2 ON T2.GenID = T1.GenID
				WHERE	T1.Status = 2 AND T1.PCode = @PCode AND T1.WhsCode = @WhsCode
				ORDER BY 
						T2.paymentDate ASC
			END

		ELSE IF @Mode = 'CreatePayment'
			BEGIN
				INSERT INTO dbo.RAC_RBAgingHistory
				        (DocID, GenID, WhsCode,
				        PCode, UnPaidRebates, AmountPaid,
				        PaymentDate, CreatedBy, CreatedDate)
				SELECT	DocID,
						GenID,
						WhsCode,
						PCode,
						UnPaidRebates,
						AmountPaid,
						PaymentDate,
						@EmpID,
						GETDATE()
				FROM	@UTblAging

				UPDATE	RAC_RBPayments
				SET		Status = 1
				FROM	@UTblAging T1
				WHERE	dbo.RAC_RBPayments.RecID = T1.DocID
						AND (dbo.RAC_RBPayments.UnPaidRebates - T1.AmountPaid) = 0
			END

	END
GO
