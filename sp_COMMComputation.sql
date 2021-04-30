-- =============================================
-- Author:		Ralph Salino
-- Create date: 2021-02911
-- Description:	Commission Computation
-- =============================================

ALTER PROCEDURE dbo.sp_COMMComputation
    @Mode VARCHAR(100) = NULL,
	@From DATE = NULL,
	@To DATE = NULL,
	@EmpID VARCHAR(20) = NULL,
	@GenID INT = NULL,
	@IsProcess INT = NULL,
	@SlpCode VARCHAR(1000) = NULL,
	@DocDate DATE = NULL,
	@GrossSales DECIMAL(18,2) = NULL,
	@PaidSales DECIMAL(18,2) = NULL,
	@SalesPerfPercentage DECIMAL(18,2) = NULL,
	@SalesNetPercentage DECIMAL(18,2) = NULL,
	@CallsNetPercentage DECIMAL(18,2) = NULL,
	@CommGross DECIMAL(18,2) = NULL,
	@CommNets DECIMAL(18,2) = NULL,
	@TransDate DATE = NULL,
	@SchmeCode INT = NULL,
	@UDTCommPaidDtl UDTCommPaidDtl READONLY,
	@UDTCommPaidHdr UDTCommPaidHdr READONLY,
	@HRecID INT = NULL

AS
    BEGIN
		IF @Mode = 'CommSynch'
			BEGIN

				--==================================================================================================
				IF NOT OBJECT_ID('tempDB..#tmpInvoice') IS NULL DROP TABLE #tmpInvoice
				SELECT T1.*
				INTO	#tmpInvoice
				FROM	(
							SELECT T1.DocEntry,
								   T1.Labno,
								   T1.CardCode,	   
								   T1.DocDate,
								   T2.itemcode,
								   T2.U_PackageNo,
								   T1.WhsCode,
								   T1.PMode,
								   SUM(T2.linetotal) Amount,
								   ISNULL(SUM(T3.AdjAmt),0) AdjAmt,
								   ISNULL(SUM(T4.Paid),0) Paid,
								   T2.U_DoctorCode, T2.u_paymenttyp,
								   T2.LineNum
							FROM OINV T1 WITH(NOLOCK) 
							INNER JOIN INV1 T2 WITH(NOLOCK) on T1.docentry = T2.docentry 
							LEFT JOIN (SELECT U_LabNo,WhsCode,ItemCode,SUM(LineTotal) AdjAmt
									   FROM HPDI..rin1 with(nolock) 
									   GROUP BY U_LabNo,WhsCode,ItemCode) T3 ON T3.u_labno = T2.u_labno and T3.Whscode = T2.whscode and T3.ItemCode = T2.itemcode 
							LEFT JOIN (SELECT DocEntry,LineNum,SUM(linetotal) Paid
									   FROM AOPDET2
									   GROUP BY DocEntry,LineNum) T4 ON T4.docentry = T1.docentry AND T4.LineNum = T2.LineNum	
							GROUP BY T1.docentry,T1.Labno,t1.cardcode,T1.PMode,T1.docdate,T1.whscode,t2.itemcode,T2.U_PackageNo, T2.U_DoctorCode, T2.u_paymenttyp, T2.LineNum
							HAVING SUM(T2.linetotal - ISNULL(T3.AdjAmt,0)) <> 0	
						) T1
				WHERE	T1.docdate BETWEEN @From AND @To
						AND T1.u_paymenttyp IN ('1', '3', '5', '7')


				--==================================================================================================
				IF NOT OBJECT_ID('tempDB..#tmpSPItem') IS NULL DROP TABLE #tmpSPItem
				SELECT DISTINCT
						IMH_CODE ,
						IMH_TYPE ,
						TI_TEST_GRP
				INTO    #tmpSPItem
				FROM    HPCOMMON..ITEM_MASTERH WITH(NOLOCK)
				WHERE   TI_TEST_GRP = 'SP'

				--==================================================================================================
				IF NOT OBJECT_ID('tempDB..#tmpInvoice2') IS NULL DROP TABLE #tmpInvoice2
				SELECT	T1.docentry,
						T1.docdate,
						T1.Labno,
						T1.itemcode,
						T1.whscode,
						T2.GroupCode,
						ISNULL(T1.Amount, 0) - ISNULL(T1.AdjAmt, 0) LineTotal,
						T1.Paid,
						T1.U_DoctorCode,
						T1.cardcode,
						T2.Address,
						T2.U_AccountType,
						CASE WHEN T2.GroupCode = 100
							THEN CASE WHEN T2.U_AccountType = '04'
									THEN 'Mission'
									ELSE 'Regular Account'
								 END
							ELSE ISNULL(T3.Hosp, '')
						END Hospital,
						ISNULL(T4.TI_TEST_GRP, 'REGULAR') TI_TEST_GRP,
						T1.LineNum
				INTO	#tmpInvoice2
				FROM	#tmpInvoice T1
						LEFT JOIN HPDI..OCRD T2 WITH(NOLOCK) ON T2.CardCode = T1.cardcode
						LEFT JOIN dbo.odrs T3 WITH(NOLOCK) ON T3.DCode = T1.U_DoctorCode
						LEFT JOIN #tmpSPItem T4 ON T4.IMH_CODE = T1.itemcode
				WHERE	T2.U_AccountType <> '06'


				--==================================================================================================
				IF NOT OBJECT_ID('tempDB..#tmpInvoice3') IS NULL DROP TABLE #tmpInvoice3
				SELECT t1.* --,CAST(t1.docentry AS VARCHAR(20)) + '-' + CAST(t1.LineNum AS VARCHAR(10)) RecDesc
				INTO #tmpInvoice3
				FROM (
				SELECT	t1.docentry,
						t1.docdate,
						--DATENAME(MONTH, t1.docdate) + ' ' + DATENAME(YEAR, t1.docdate) TransDate,
						t1.Labno, 
						t1.itemcode, 
						t1.whscode, 
						t2.SlpCode,
						t1.GroupCode, 
						t2.BPCode,
						t2.BPName,
						t1.Hospital, 
						t1.LineTotal LineAmnt,
						CASE WHEN t1.Hospital = 'INCIDENTAL' AND ISNULL(t1.TI_TEST_GRP, 'REGULAR') <> 'SP' THEN 0.00 ELSE CAST(t1.LineTotal AS DECIMAL(18,2)) END LineTotal,
						CASE WHEN t1.Hospital = 'INCIDENTAL' AND ISNULL(t1.TI_TEST_GRP, 'REGULAR') <> 'SP' THEN 0.00 ELSE CAST(t1.Paid AS DECIMAL(18,2)) END Paid,
						t1.TI_TEST_GRP,
						t1.LineNum
				--INTO	#tmpInvoice3
				FROM	#tmpInvoice2 t1 WITH(NOLOCK)
						LEFT JOIN dbo.BPSlp t2 WITH(NOLOCK) ON t2.SType = 100 AND t2.BPCode = t1.cardcode AND CAST(t1.docdate AS DATE) BETWEEN t2.SDate AND t2.EDate
				WHERE	t1.GroupCode = 100
						--AND t2.SlpCode = 1
				UNION ALL
				SELECT	t1.docentry,
						t1.docdate,
						--DATENAME(MONTH, t1.docdate) + ' ' + DATENAME(YEAR, t1.docdate) TransDate,
						t1.Labno, 
						t1.itemcode, 
						t1.whscode, 
						t2.SlpCode,
						t1.GroupCode, 
						t2.BPCode,
						t2.BPName,
						t1.Hospital, 
						t1.LineTotal LineAmnt,
						CASE WHEN t1.Hospital = 'INCIDENTAL' AND ISNULL(t1.TI_TEST_GRP, 'REGULAR') <> 'SP' THEN 0.00 ELSE CAST(t1.LineTotal AS DECIMAL(18,2)) END LineTotal,
						CASE WHEN t1.Hospital = 'INCIDENTAL' AND ISNULL(t1.TI_TEST_GRP, 'REGULAR') <> 'SP' THEN 0.00 ELSE CAST(t1.Paid AS DECIMAL(18,2)) END Paid,
						t1.TI_TEST_GRP,
						t1.LineNum
				FROM	#tmpInvoice2 t1 WITH(NOLOCK)
						LEFT JOIN dbo.BPSlp t2 WITH(NOLOCK) ON t2.SType = 102 AND t2.BPCode = t1.U_DoctorCode AND CAST(t1.docdate AS DATE) BETWEEN t2.SDate AND t2.EDate
				WHERE	t1.GroupCode = 102
						--AND t2.SlpCode = 1
						) t1

				--IF NOT OBJECT_ID('tempDB..#tmpInvoice3') IS NULL DROP TABLE #tmpInvoice3
				--SELECT	t1.docentry,
				--		t1.docdate,
				--		--DATENAME(MONTH, t1.docdate) + ' ' + DATENAME(YEAR, t1.docdate) TransDate,
				--		t1.Labno, 
				--		t1.itemcode, 
				--		t1.whscode, 
				--		t2.SlpCode,
				--		t1.GroupCode, 
				--		t2.BPCode,
				--		t2.BPName,
				--		t1.Hospital, 
				--		CASE WHEN t1.Hospital = 'INCIDENTAL' AND ISNULL(t1.TI_TEST_GRP, 'REGULAR') <> 'SP' THEN 0.00 ELSE CAST(t1.LineTotal AS DECIMAL(18,2)) END LineTotal,
				--		CASE WHEN t1.Hospital = 'INCIDENTAL' AND ISNULL(t1.TI_TEST_GRP, 'REGULAR') <> 'SP' THEN 0.00 ELSE CAST(t1.Paid AS DECIMAL(18,2)) END Paid,
				--		t1.TI_TEST_GRP,
				--		t1.LineNum
				--INTO	#tmpInvoice3
				--FROM	#tmpInvoice2 t1 WITH(NOLOCK)
				--		LEFT JOIN dbo.BPSlp t2 WITH(NOLOCK) ON t2.SType =  t1.GroupCode AND t1.cardcode = t2.BPCode AND t1.docdate BETWEEN t2.SDate AND t2.EDate

				--Insert into commission header
				INSERT INTO dbo.RAC_CommComputationHdr
				        ( DateFrom,
				          DateTo,
				          CreatedBy,
				          CreatedDate
				        )
				VALUES  ( @From,
				          @To,
				          @EmpID,
				          GETDATE()
				        )

				SET @GenID = SCOPE_IDENTITY()

				--Insert into commission details
				INSERT INTO dbo.RAC_CommComputationDtl
						(DocEntry, DocDate, LabNo, 
						LineNum, ItemCode, WhsCode, 
						SlpCode, GroupCode, BPCode,
						BPName, Hospital, LineTotal, 
						Paid, TI_TEST_GRP, IsProcess,
						RecDate, GenID)
				SELECT	docentry,
						docdate,
						Labno,
						LineNum,
						itemcode,
						whscode,
						SlpCode,
						GroupCode,
						BPCode,
						BPName,
						Hospital,
						LineTotal,
						Paid,
						TI_TEST_GRP,
						0,
						GETDATE(),
						@GenID
				FROM	#tmpInvoice3 

				--Update the data get from inv1
				UPDATE	dbo.inv1 
				SET		Commission = 1
				FROM	#tmpInvoice3 t2
				WHERE	dbo.inv1.docentry = t2.docentry
						AND dbo.inv1.LineNum = t2.LineNum
						AND dbo.inv1.itemcode = t2.itemcode

				DROP TABLE #tmpSPItem, #tmpInvoice, #tmpInvoice2, #tmpInvoice3
			END

		ELSE IF @Mode = 'LoadCommComp'
			BEGIN
				IF @GenID = 0 
					BEGIN 
						SET @GenID = NULL
						SET @IsProcess = 0
					END
				ELSE
					BEGIN
						SET @GenID = @GenID
						SET @IsProcess = 1
					END

				IF NOT OBJECT_ID('tempDB..#tmpCommission') IS NULL DROP TABLE #tmpCommission
				SELECT	t1.*
				INTO	#tmpCommission
				FROM 
						(
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Regular' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate) TransDate
							FROM	RAC_CommComputationDtl
							WHERE	Hospital <> 'Mission'
									AND (@GenID IS NULL OR GenID = @GenID)
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate)

							UNION ALL
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Mission' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate) TransDate
							FROM	RAC_CommComputationDtl
							WHERE	Hospital = 'Mission'
									AND (@GenID IS NULL OR GenID = @GenID)
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate)
						) t1
				ORDER BY t1.SlpCode, t1.Type DESC

				--
				SELECT	ISNULL(t1.SlpCode, '-1') [SlpCode], 
						ISNULL(t3.SlpName, '-No Sales Employee-') [SlpName],
						SUM(t1.TotalAmount) [TotalAmount], 
						SUM(t1.Paid) [Paid], 
						ISNULL(t2.SalesQualifier, 0.00) [SalesQualifier], 
						ISNULL(t2.CallsQualifier, 0.00) [CallsQualifier], 
						ISNULL(t2.CallsPerformance, 0.00) [CallsPerformance], 
						ISNULL(t4.Amt, 0.00) [TargetSales]
				FROM	#tmpCommission t1
						LEFT JOIN dbo.RAC_CommQualifiers t2 ON ISNULL(t1.SlpCode, '-1') = t2.SlpCode AND t1.Pd = t2.Month AND t1.Yr = t2.Year
						LEFT JOIN dbo.OSLP t3 ON ISNULL(t1.SlpCode, '-1') = t3.SlpCode
						LEFT JOIN dbo.ComTargetdtl t4 ON ISNULL(t1.SlpCode, '-1') = t4.Slpcode AND t1.Pd = t4.Pd AND t1.Yr = t4.Yr
				GROUP BY 
						ISNULL(t1.SlpCode, '-1'), ISNULL(t3.SlpName, '-No Sales Employee-'), --t1.TransDate, 
						t2.SalesQualifier, t2.CallsQualifier, t2.CallsPerformance, t4.Amt

			END

		ELSE IF @Mode = 'LoadCommCompDtl'
			BEGIN
				IF @GenID = 0 
					BEGIN 
						SET @GenID = NULL
						SET @IsProcess = 0
					END
				ELSE
					BEGIN
						SET @GenID = @GenID
						SET @IsProcess = 1
					END

				IF NOT OBJECT_ID('tempDB..#tmpCommissionDtl') IS NULL DROP TABLE #tmpCommissionDtl
				SELECT	t1.*
				INTO	#tmpCommissionDtl
				FROM 
						(
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Regular' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate) TransDate
							FROM	RAC_CommComputationDtl
							WHERE	Hospital <> 'Mission'
									AND SlpCode = @SlpCode
									AND (@GenID IS NULL OR GenID = @GenID)
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate)

							UNION ALL
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Mission' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate) TransDate
							FROM	RAC_CommComputationDtl
							WHERE	Hospital = 'Mission'
									AND SlpCode = @SlpCode
									AND (@GenID IS NULL OR GenID = @GenID)
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate)
						) t1
				ORDER BY t1.SlpCode, t1.Type DESC

				--
				SELECT	ISNULL(t1.SlpCode, '-1') [SlpCode], 
						ISNULL(t3.SlpName, '-No Sales Employee-') [SlpName],
						ISNULL(t1.TotalAmount, 0.00) [TotalAmount], 
						ISNULL(t1.Paid, 0.00) [Paid], 
						t1.Type,
						t1.TransDate,
						ISNULL(t2.SalesQualifier, 0.00) [SalesQualifier], 
						ISNULL(t2.CallsQualifier, 0.00) [CallsQualifier], 
						ISNULL(t2.CallsPerformance, 0.00) [CallsPerformance],
						ISNULL(t4.Amt, 0.00) [TargetSales]
				FROM	#tmpCommissionDtl t1
						LEFT JOIN dbo.RAC_CommQualifiers t2 ON t1.SlpCode = t2.SlpCode AND t1.Pd = t2.Month AND t1.Yr = t2.Year
						LEFT JOIN dbo.OSLP t3 ON t1.SlpCode = t3.SlpCode			
						LEFT JOIN dbo.ComTargetdtl t4 ON ISNULL(t1.SlpCode, '-1') = t4.Slpcode AND t1.Pd = t4.Pd AND t1.Yr = t4.Yr

			END


		ELSE IF @Mode = 'LoadGenID'
			BEGIN
				SELECT	0 [Code], 
						'UnProcess' [Desc],
						GETDATE() [DateFrom],
						GETDATE() [DateTo]
				UNION
				SELECT	GenID [Code], 
						CAST(GenID AS VARCHAR(20)) [Desc],
						DateFrom,
						DateTo
				FROM	dbo.RAC_CommComputationHdr
			END

		ELSE IF @Mode = 'GetForCommComputation'
			BEGIN
				--DECLARE @IsProcess INT = 0,
				--		@SlpCode VARCHAR(1000) = '1,3,4,5'

				IF NOT OBJECT_ID('tempDB..#tmpCommissionDtl_') IS NULL DROP TABLE #tmpCommissionDtl_
				SELECT	t1.*
				INTO	#tmpCommissionDtl_
				FROM 
						(
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Regular' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE) TransDate,
									GenID
							FROM	RAC_CommComputationDtl
							WHERE	Hospital <> 'Mission'
									AND SlpCode IN (SELECT Item FROM dbo.Split(@SlpCode, ','))
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE),
									GenID
									
							UNION ALL
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Mission' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE) TransDate,
									GenID
									--DATENAME(MONTH, docdate) + ' ' + DATENAME(YEAR, docdate) TransDate
							FROM	RAC_CommComputationDtl
							WHERE	Hospital = 'Mission'
									AND SlpCode IN (SELECT Item FROM dbo.Split(@SlpCode, ','))
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE),
									GenID
						) t1
				ORDER BY t1.SlpCode, t1.Type DESC
				
				--Details
				IF NOT OBJECT_ID('tempDB..#tmpCommDets') IS NULL DROP TABLE #tmpCommDets
				SELECT	ISNULL(t1.SlpCode, '-1') [SlpCode], 
						ISNULL(t3.SlpName, '-No Sales Employee-') [SlpName],
						ISNULL(t1.TotalAmount, 0.00) [TotalAmount], 
						ISNULL(t1.Paid, 0.00) [Paid], 
						t1.Type,
						t1.TransDate,
						t1.GenID,
						ISNULL(t2.SalesQualifier, 0.00) [SalesQualifier], 
						ISNULL(t2.CallsQualifier, 0.00) [CallsQualifier], 
						ISNULL(t2.CallsPerformance, 0.00) [CallsPerformance],
						ISNULL(t4.Amt, 0.00) [TargetSales]
				INTO	#tmpCommDets
				FROM	#tmpCommissionDtl_ t1
						LEFT JOIN dbo.RAC_CommQualifiers t2 ON t1.SlpCode = t2.SlpCode AND t1.Pd = t2.Month AND t1.Yr = t2.Year
						LEFT JOIN dbo.OSLP t3 ON t1.SlpCode = t3.SlpCode			
						LEFT JOIN dbo.ComTargetdtl t4 ON ISNULL(t1.SlpCode, '-1') = t4.Slpcode AND t1.Pd = t4.Pd AND t1.Yr = t4.Yr

				--Header
				SELECT	SlpCode,
						SlpName,
						CAST(SUM(TotalAmount) AS DECIMAL(18,2)) GrossAmnt,
						CAST(SUM(Paid) AS DECIMAL(18,2)) PaidAmnt,
						TransDate,
						CAST(SalesQualifier AS DECIMAL(18,2)) SalesQualifier,
						CAST(CallsQualifier AS DECIMAL(18,2)) CallsQualifier,
						CAST(CallsPerformance AS DECIMAL(18,2)) CallsPerformance,
						CAST(TargetSales AS DECIMAL(18,2)) TargetSales,
						GenID
				FROM	#tmpCommDets
				GROUP BY 
						SlpCode,
						SlpName,
						TransDate,
						SalesQualifier,
						CallsQualifier,
						CallsPerformance,
						TargetSales,
						GenID
			END

		ELSE IF @Mode = 'GetCommDets'
			BEGIN
				--DECLARE @IsProcess INT = 0,
				--		@SlpCode VARCHAR(1000) = '1'

				IF NOT OBJECT_ID('tempDB..#tmpCommissionDtl__') IS NULL DROP TABLE #tmpCommissionDtl__
				SELECT	t1.*
				INTO	#tmpCommissionDtl__
				FROM 
						(
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Regular' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE) TransDate,
									GenID
							FROM	RAC_CommComputationDtl
							WHERE	Hospital <> 'Mission'
									AND SlpCode IN (SELECT Item FROM dbo.Split(@SlpCode, ','))
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE),
									GenID

							UNION ALL
							SELECT	SlpCode,
									SUM(LineTotal) TotalAmount,
									SUM(Paid) Paid,
									'Mission' [Type],
									MONTH(docdate) Pd,
									YEAR(docdate) Yr,
									CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE) TransDate,
									GenID
							FROM	RAC_CommComputationDtl
							WHERE	Hospital = 'Mission'
									AND SlpCode IN (SELECT Item FROM dbo.Split(@SlpCode, ','))
									AND IsProcess = @IsProcess
							GROUP BY 
									SlpCode, MONTH(docdate), YEAR(docdate), CAST(CAST(MONTH(docdate) AS VARCHAR(5)) + '/01/' + CAST(YEAR(docdate) AS VARCHAR(5)) AS DATE),
									GenID
						) t1
				ORDER BY t1.SlpCode, t1.Type DESC
				
				--Details
				SELECT	ISNULL(t1.SlpCode, '-1') [SlpCode], 
						ISNULL(t3.SlpName, '-No Sales Employee-') [SlpName],
						ISNULL(t1.TotalAmount, 0.00) [TotalAmount], 
						ISNULL(t1.Paid, 0.00) [Paid], 
						t1.Type,
						t1.TransDate,
						t1.GenID
				FROM	#tmpCommissionDtl__ t1
						LEFT JOIN dbo.RAC_CommQualifiers t2 ON t1.SlpCode = t2.SlpCode AND t1.Pd = t2.Month AND t1.Yr = t2.Year
						LEFT JOIN dbo.OSLP t3 ON t1.SlpCode = t3.SlpCode			
						LEFT JOIN dbo.ComTargetdtl t4 ON ISNULL(t1.SlpCode, '-1') = t4.Slpcode AND t1.Pd = t4.Pd AND t1.Yr = t4.Yr

				DROP TABLE #tmpCommissionDtl__
			END

		ELSE IF @Mode = 'GetCommScheme'
			BEGIN
				SELECT	T2.SchemeCode, 
						CAST(T2.AmtFr AS DECIMAL(18,2)) AmtFr, 
						CAST(T2.AmtTo AS DECIMAL(18,2)) AmtTo,
						CAST(T2.Prcnt AS DECIMAL(18,2)) Prcnt, 
						T2.CommType, 
						T1.DateStarted,
						ISNULL(T1.DateEnded, '2099-12-31') DateEnded
				FROM	dbo.CommSchemeHdr T1 WITH(NOLOCK)
						INNER JOIN dbo.CommSchemeDtl T2 WITH(NOLOCK) ON T2.Schemecode = T1.SchemeCode
				WHERE	T2.isDeleted = 0
						AND @DocDate BETWEEN T1.DateStarted AND ISNULL(T1.DateEnded, '2099-12-31')
				ORDER BY 
						CASE WHEN T2.CommType <> 'MISSION' THEN	 1 ELSE 2 END, T2.OrderBy
			END

		ELSE IF @Mode = 'SaveCommPaidHdr'
			BEGIN
				--DECLARE @SlpCode INT = 1,
				--		@GrossSales DECIMAL(18,2) = NULL,
				--		@PaidSales DECIMAL(18,2) = NULL,
				--		@SalesPerfPercentage DECIMAL(18,2) = NULL,
				--		@SalesNetPercentage DECIMAL(18,2) = NULL,
				--		@CallsNetPercentage DECIMAL(18,2) = NULL,
				--		@CommGross DECIMAL(18,2) = NULL,
				--		@CommNets DECIMAL(18,2) = NULL,
				--		@GenID INT = NULL,
				--		@TransDate DATE = NULL,
				--		@EmpID VARCHAR(20) = NULL,
				--		@SchmeCode INT = NULL

				INSERT INTO dbo.RAC_CommPaidHdr
						( SlpCode,
						  GrossSales,
						  PaidSales,
						  SalesPerfPercentage,
						  SalesNetPercentage,
						  CallsNetPercentage,
						  CommGross,
						  CommNet,
						  GenID,
						  TransDate,
						  SchmeCode,
						  CreatedBy,
						  RecDate
						)
				VALUES  ( @SlpCode,
						  @GrossSales,
						  @PaidSales,
						  @SalesPerfPercentage,
						  @SalesNetPercentage,
						  @CallsNetPercentage,
						  @CommGross,
						  @CommNets,
						  @GenID,
						  @TransDate,
						  @SchmeCode,
						  @EmpID,
						  GETDATE()
						)
				SELECT SCOPE_IDENTITY() RecID
			END

		ELSE IF @Mode = 'SaveCommPaidDtl'
			BEGIN
				INSERT INTO dbo.RAC_CommPaidDtl
				        ( LineID,
				          SlpCode,
				          SchemeType,
				          SchemePercnt,
				          SchemeSales,
				          Commission,
				          Sales,
				          HRecID
				        )
				SELECT	LineID,
						SlpCode,
						SchemeType,
						SchemePercnt,
						SchemeSales,
						Commission,
						Sales,
						@HRecID
				FROM	@UDTCommPaidDtl
			END

		ELSE IF @Mode = 'SaveCommissionPaid'
			BEGIN

				DECLARE @GrossComm DECIMAL(18,2) = NULL
				DECLARE @TotalCommPercentage DECIMAL(18,2) = NULL
				DECLARE @CommNet DECIMAL(18,2) = NULL

				SET @GrossComm = (SELECT SUM(ISNULL(Commission, 0)) FROM @UDTCommPaidDtl)
				SET @TotalCommPercentage = (SELECT SalesNetPercentage + CallsNetPercentage FROM @UDTCommPaidHdr)
				SET @CommNet = (@TotalCommPercentage / 100 * @GrossComm)

				
				--Insert Header
				INSERT	dbo.RAC_CommPaidHdr
				        ( SlpCode ,
				          GrossSales ,
				          PaidSales ,
				          SalesPerfPercentage ,
				          SalesNetPercentage ,
				          CallsNetPercentage ,
				          CommGross ,
				          CommNet ,
				          GenID ,
				          TransDate ,
				          SchmeCode ,
				          CreatedBy ,
				          RecDate
				        )
				SELECT	SlpCode ,
						GrossSales ,
						PaidSales ,
						SalesPerfPercentage ,
						SalesNetPercentage ,
						CallsNetPercentage ,
						@GrossComm ,
						@CommNet ,
						GenID ,
						TransDate ,
						SchmeCode ,
						CreatedBy ,
						GETDATE() 
				FROM	@UDTCommPaidHdr
				SET		@HRecID = SCOPE_IDENTITY()

				--Insert Details
				INSERT	dbo.RAC_CommPaidDtl
				        ( LineID ,
				          SlpCode ,
				          SchemeType ,
				          SchemePercnt ,
				          SchemeSales ,
				          Commission ,
				          Sales ,
				          HRecID
				        )
				SELECT	LineID ,
						SlpCode ,
						SchemeType ,
						SchemePercnt ,
						SchemeSales ,
						Commission ,
						Sales ,
						@HRecID 
				FROM	@UDTCommPaidDtl

				--Update IsProcess
				UPDATE	dbo.RAC_CommComputationDtl
				SET		IsProcess = 1
				FROM	@UDTCommPaidHdr t1 
				WHERE	RAC_CommComputationDtl.GenID = t1.GenID
						AND RAC_CommComputationDtl.SlpCode = t1.SlpCode

			END
	END
GO
