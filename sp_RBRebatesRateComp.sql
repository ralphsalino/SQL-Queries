-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-11-11
-- Description:	Rebates rate computation
-- =============================================

ALTER PROCEDURE dbo.sp_RBRebatesRateComp
	@Mode VARCHAR(50) = NULL,
	@GenID INT = NULL,
	@SDate DATE = NULL,
	@EDate DATE = NULL

AS
    BEGIN
		IF @Mode = 'RebatesRateComp'
			BEGIN
				--========================================================================================================================================================================
				--Get the invoice transaction of rebates
				IF NOT OBJECT_ID('tempDB..#tmpRBInv') IS NULL DROP TABLE #tmpRBInv
				SELECT	T1.DocEntry,
						T2.LineNum,
						T2.WhsCode,
						T2.ItemCode,
						rtrim(T2.u_labno) U_LabNo,
						T1.CardCode,
						T1.CardName,
						rtrim(T2.U_DoctorCode) U_DoctorCode,
						rtrim(isnull(T2.U_PackageNo, '')) U_PackageNo,
						T3.GroupCode,
						'' ComType,
						T2.LineTotal,
						0 IP,
						0 CM,
						NULL Rate,
						NULL Amt,
						T1.PMode,
						T2.u_paymenttyp,
						CASE WHEN ISNULL(T4.RBSenior,0) = 1 OR ISNULL(T4.Member,0) = 1 OR ISNULL(T4.PWD,0) = 1
								THEN 1 ELSE 0 
						END [RBSenior],
						T5.PrcLvlType,
						ISNULL(T4.RbPrcLvl,0) [RbPrcLvl]
				INTO	#tmpRBInv
				FROM	dbo.oinv T1 WITH (NOLOCK)
						INNER JOIN dbo.inv1 T2 WITH (NOLOCK) ON T1.docentry = T2.docentry
						INNER JOIN hpdi..OCRD T3 WITH (NOLOCK) ON T3.CardCode = T1.cardcode
						INNER JOIN dbo.OCRD T4 WITH(NOLOCK) ON T3.CardCode = T4.CardCode
						LEFT JOIN dbo.RAC_RebPrcLvlMntnce T5 WITH(NOLOCK) ON T1.whscode = T5.Whs
				WHERE	T1.recondate between @SDate and @EDate 
						AND T3.CardType <> 'S'
						AND ISNULL(T2.Rebate, '') = ''
						AND LEFT(ISNULL(T2.u_source, ''), 2) <> 'HP'
						AND T2.u_paymenttyp NOT IN ('5', '6', '8')
				
				--========================================================================================================================================================================
				--Payees
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

				--Create temp table for special test/in-house

				--SP grp with special in-house
				IF NOT OBJECT_ID('tempDB..#tmpSPGrpWithInHouse') IS NULL DROP TABLE #tmpSPGrpWithInHouse
				SELECT	T1.IMH_CODE,
						T1.WHSCODE,
						T3.ItemCode,
						T1.TI_TEST_GRP,
						T1.IMH_TYPE
				INTO	#tmpSPGrpWithInHouse
				FROM	dbo.ITEM_MASTERH T1 WITH(NOLOCK)
						LEFT JOIN dbo.ITEM_MASTERD T2 WITH(NOLOCK) ON T1.IMH_CODE = T2.IMD_PKG_CODE AND T2.WHSCODE = T1.WHSCODE
						LEFT JOIN dbo.SpclInhouse T3 WITH(NOLOCK) ON T1.IMH_CODE = T3.ItemCode AND T1.WHSCODE = T3.WhsCode
				WHERE	T1.TI_TEST_GRP = 'SP'

				--Not SP grp with special in-house
				IF NOT OBJECT_ID('tempDB..#tmpNotSPGrpWithInHouse') IS NULL DROP TABLE #tmpNotSPGrpWithInHouse
				SELECT	T1.IMH_CODE,
						T1.WHSCODE,
						T3.ItemCode,
						T1.TI_TEST_GRP,
						T1.IMH_TYPE
				INTO	#tmpNotSPGrpWithInHouse
				FROM	dbo.ITEM_MASTERH T1 WITH(NOLOCK)
						LEFT JOIN dbo.ITEM_MASTERD T2 WITH(NOLOCK) ON T1.IMH_CODE = T2.IMD_PKG_CODE AND T2.WHSCODE = T1.WHSCODE
						LEFT JOIN dbo.SpclInhouse T3 WITH(NOLOCK) ON T1.IMH_CODE = T3.ItemCode AND T1.WHSCODE = T3.WhsCode
				WHERE	T1.TI_TEST_GRP <> 'SP' AND T3.ItemCode IS NOT NULL

				--Final Query for special test/ in-house
				IF NOT OBJECT_ID('tempDB..#tmpSpecialTest') IS NULL DROP TABLE #tmpSpecialTest
				SELECT	T1.IMH_CODE, T1.WHSCODE
				INTO	#tmpSpecialTest
				FROM	(SELECT	IMH_CODE, WHSCODE 
						FROM	#tmpNotSPGrpWithInHouse
						UNION ALL
						SELECT	IMH_CODE, WHSCODE 
						FROM	#tmpSPGrpWithInHouse) T1
				GROUP BY
						T1.IMH_CODE, T1.WHSCODE

				--========================================================================================================================================================================
				--Get the rebates rate combination
				CREATE TABLE #tmpRBInvoice(DocEntry INT, LineNum INT, WhsCode VARCHAR(5), ItemCode VARCHAR(20), U_LabNo VARCHAR(30), CardCode VARCHAR(30), CardName VARCHAR(100), 
							U_DoctorCode VARCHAR(20), U_PackageNo VARCHAR(20), GroupCode SMALLINT, ComType VARCHAR(20), LineTotal NUMERIC, IP INT, CM INT,
							Rate NUMERIC, Amt NUMERIC, RateComb VARCHAR(20), RbPrcLvl INT)

				INSERT INTO #tmpRBInvoice
					(DocEntry, LineNum, WhsCode, ItemCode, U_LabNo, CardCode, CardName, U_DoctorCode, U_PackageNo, GroupCode, ComType, LineTotal, IP, CM, 
					 Rate, Amt, RateComb, RbPrcLvl)
				SELECT	T1.DocEntry,
						T1.LineNum,
						T1.WhsCode,
						T1.ItemCode,
						T1.U_LabNo,
						T1.CardCode,
						T1.CardName,
						T1.U_DoctorCode,
						T1.U_PackageNo,
						T1.GroupCode,
						T1.ComType,
						T1.LineTotal,
						T1.IP,
						T1.CM,
						T1.Rate,
						T1.Amt,
						CASE WHEN T1.GroupCode = '102' THEN --Clinician RateCombination
 							CAST(CAST(T1.PMode AS VARCHAR(20)) +
								RIGHT('00'+ CAST(T1.u_paymenttyp AS VARCHAR(20)),2)  +
								CAST(T1.RBSenior AS VARCHAR(2))+
								CAST(CASE WHEN T1.U_PackageNo = '' THEN '0'
									ELSE 
										CASE WHEN ISNULL(T3.IMH_CODE, '0') <> '0' THEN '3' ELSE '2' END
								END AS VARCHAR(2)) +
								CAST(T1.PrcLvlType AS VARCHAR(20)) +
								CAST(T1.whscode AS VARCHAR(10)) +
								CAST(T4.TI_TEST_GRP AS VARCHAR(20)) AS varchar(100))                       
							 ELSE --Account Combination
 								CAST(RIGHT('00'+ CAST(T1.u_paymenttyp AS VARCHAR(20)),2)  +
									CAST(T1.RBSenior AS VARCHAR(2))+
									CAST(CASE WHEN T1.U_PackageNo = '' THEN '0'
										ELSE 
											CASE WHEN ISNULL(T3.IMH_CODE, '0') <> '0' THEN '3' ELSE '2' END
									END AS VARCHAR(2)) +
									CAST(T4.TI_TEST_GRP AS VARCHAR(20)) AS varchar(100)) 
							 END [RateComb],
						T1.RbPrcLvl
				FROM	#tmpRBInv T1 WITH(NOLOCK)
						LEFT JOIN #tmpSpecialTest T3 WITH(NOLOCK) ON T1.ItemCode = T3.IMH_CODE AND T1.whscode = T3.whscode
						LEFT JOIN dbo.ITEM_MASTERH T4 WITH(NOLOCK) ON T1.ItemCode = T4.IMH_CODE AND T1.whscode = T4.WHSCODE
				WHERE	T4.IMH_BILLCODE NOT IN ('5000', '5010') --Delete HS/Supplies 
						AND T1.cardcode <> '110019' --Remove Health Card Promo
						
				--========================================================================================================================================================================
				--Remove Clin - '00'
				DELETE #tmpRBInvoice WHERE GroupCode = '102' AND U_DoctorCode = '00'
				
				--Remove clin No Rebates
				DELETE	#tmpRBInvoice 
				WHERE	U_DoctorCode COLLATE DATABASE_DEFAULT IN (SELECT CardCode FROM dbo.RB_NoRebate WITH(NOLOCK) WHERE GroupCode = '102' ) 
						AND #tmpRBInvoice.GroupCode = '102' 

				--Remove acct No Rebates
				DELETE #tmpRBInvoice WHERE GroupCode = '100' AND ISNULL(RbPrcLvl, 0) = 0

				--Linked CM
				UPDATE	#tmpRBInvoice
				SET		#tmpRBInvoice.cm = T1.cm
				FROM	(
							SELECT BaseRef,
								BaseLine,
								SUM(LineTotal) CM
							FROM HPDI..rin1 WITH (NOLOCK)
							WHERE baseline IS NOT NULL
							GROUP BY BaseRef,
								BaseLine
						) T1
				WHERE	T1.baseref = #tmpRBInvoice.docentry 
						AND T1.baseline = #tmpRBInvoice.linenum

				--UnLinked CM
				UPDATE	#tmpRBInvoice
				SET		#tmpRBInvoice.cm = #tmpRBInvoice.cm + T1.cm
				FROM	(
							SELECT WhsCode,
								ItemCode,
								U_LabNo,
								SUM(LineTotal) CM
							FROM HPDI..rin1 WITH (NOLOCK)
							WHERE baseline IS NULL
							GROUP BY WhsCode,
								ItemCode,
								U_LabNo
						) T1
				WHERE	T1.WhsCode = #tmpRBInvoice.whscode COLLATE DATABASE_DEFAULT 
						AND T1.ItemCode = #tmpRBInvoice.itemcode COLLATE DATABASE_DEFAULT 
						AND T1.U_LabNo = #tmpRBInvoice.u_labno COLLATE DATABASE_DEFAULT

				IF NOT OBJECT_ID('tempDB..#tmp1') IS NULL DROP TABLE #tmp1
				SELECT	T1.DocEntry,
						T1.LineNum,
						SUM(T1.linetotal) amt
				INTO	#tmp1
				FROM	dbo.AOPDet2 T1
						INNER JOIN 
							(
								SELECT DISTINCT		
										T3.docnum,
										T3.DocEntry,
										T5.linenum LineNum
								FROM	hpdi..JDT1 T1
										INNER JOIN hpdi..oact T2 WITH(NOLOCK) ON T2.acctcode = T1.account
										INNER JOIN hpdi..rct2 T3 WITH(NOLOCK) ON T3.DocNum = T1.BaseRef
										INNER JOIN hpdi..orct T4 WITH(NOLOCK) ON T4.DocNum = T3.DocNum AND T4.Canceled = 'N'
										INNER JOIN #tmpRBInvoice T5 WITH(NOLOCK) ON T3.DocEntry = T5.docentry
								WHERE	TransType = 24 AND segment_0 = '40100'
							)	T2 ON T2.DocEntry = T1.DocEntry AND T2.DocNum = T1.DocNum AND T2.LineNum = T1.LineNum
				GROUP BY 
						T1.DocEntry,
						T1.LineNum

				UPDATE	#tmpRBInvoice
				SET		#tmpRBInvoice.ip = T1.amt
				FROM	#tmp1 T1
				WHERE	T1.DocEntry = #tmpRBInvoice.DocEntry AND T1.LineNum = #tmpRBInvoice.LineNum

				--Remove 0 LineTotal
				DELETE #tmpRBInvoice WHERE ((linetotal - CM) - ip) <= 0

				--========================================================================================================================================================================
				--Get the specified rate of transaction

				--(Clinician) Special In-House Test with specific rate/amount - CLI10001
				UPDATE	#tmpRBInvoice
				SET		#tmpRBInvoice.Rate = CAST(T1.Rate AS DECIMAL),
						#tmpRBInvoice.Amt = T1.Amt,
						#tmpRBInvoice.ComType = 'CLI10001'
				FROM	dbo.SpclInhouse T1 
				WHERE	#tmpRBInvoice.ItemCode = T1.ItemCode COLLATE DATABASE_DEFAULT
						AND #tmpRBInvoice.WhsCode = T1.WhsCode COLLATE DATABASE_DEFAULT
						AND #tmpRBInvoice.GroupCode = '102' COLLATE DATABASE_DEFAULT
						AND GroupCode = '102' COLLATE DATABASE_DEFAULT

				--(Clinician) Combination computation - CLI10002
				UPDATE	#tmpRBInvoice 
				SET		#tmpRBInvoice.Rate = T1.Rate,
						#tmpRBInvoice.Amt = T1.Amount,
						#tmpRBInvoice.ComType = 'CLI10002'
				FROM	dbo.RAC_RebRateCombination T1 
				WHERE	#tmpRBInvoice.RateComb = T1.RateDesc COLLATE DATABASE_DEFAULT
						AND #tmpRBInvoice.GroupCode = '102'
						AND T1.Type = '102'
						AND (ISNULL(#tmpRBInvoice.Rate, '0.00') = '0.00' AND ISNULL(#tmpRBInvoice.Amt, '0.00') = '0.00')

				--(Account) Special In-House Test with specific rate/amount - ACC10001
				UPDATE	#tmpRBInvoice
				SET		#tmpRBInvoice.Rate = T1.Rate,
						#tmpRBInvoice.Amt = T1.Amt,
						#tmpRBInvoice.ComType = 'ACC10001'
				FROM	dbo.SpclInhouse T1
				WHERE	#tmpRBInvoice.ItemCode = T1.ItemCode COLLATE DATABASE_DEFAULT
						AND #tmpRBInvoice.WhsCode = T1.WhsCode COLLATE DATABASE_DEFAULT
						AND #tmpRBInvoice.GroupCode = '100' COLLATE DATABASE_DEFAULT
						AND GroupCode = '100' COLLATE DATABASE_DEFAULT
						AND (ISNULL(#tmpRBInvoice.Rate, '0.00') = '0.00' AND ISNULL(#tmpRBInvoice.Amt, '0.00') = '0.00')

				--(Account) Branch price level computation - ACC10002
				UPDATE	#tmpRBInvoice
				SET		#tmpRBInvoice.Rate = T1.RebRates,
						#tmpRBInvoice.ComType = 'ACC10002'
				FROM	dbo.OCRD T1
				WHERE	#tmpRBInvoice.CardCode = T1.CardCode COLLATE DATABASE_DEFAULT
						AND ISNULL(#tmpRBInvoice.RbPrcLvl, 0) <> 0
						AND #tmpRBInvoice.GroupCode = '100'
						AND (ISNULL(#tmpRBInvoice.Rate, '0.00') = '0.00' AND ISNULL(#tmpRBInvoice.Amt, '0.00') = '0.00')

				--(Account) Branch price level computation - ACC10003
				UPDATE	#tmpRBInvoice 
				SET		#tmpRBInvoice.Rate = T1.Rate,
						#tmpRBInvoice.Amt = T1.Amount,
						#tmpRBInvoice.ComType = 'ACC10003'
				FROM	dbo.RAC_RebRateCombination T1
				WHERE	#tmpRBInvoice.RateComb = T1.RateDesc COLLATE DATABASE_DEFAULT
						AND #tmpRBInvoice.GroupCode = '100'
						AND T1.Type = '100'
						AND (ISNULL(#tmpRBInvoice.Rate, '0.00') = '0.00' AND ISNULL(#tmpRBInvoice.Amt, '0.00') = '0.00')
												
				--========================================================================================================================================================================						
				CREATE TABLE #tmpRebatesDetail
					(
						GenID INT, DocEntry INT, LineNum INT, 
						U_PackageNo VARCHAR(20), ItemCode VARCHAR(20), WhsCode VARCHAR(8), CardCode VARCHAR(15), 
						CardName VARCHAR(100), U_LabNo VARCHAR(30), U_DoctorCode VARCHAR(10), GroupCode SMALLINT, 
						U_PayCode VARCHAR(30), U_PayName VARCHAR(150), ComType VARCHAR(100), ObjType INT, 
						LineTotal NUMERIC, U_Rate NUMERIC, U_Amount NUMERIC, U_Share NUMERIC, Fund NUMERIC, DedAmt NUMERIC
					)
					
				--Sharing Rate
				IF NOT OBJECT_ID('tempDB..#tmpSharing') IS NULL DROP TABLE #tmpSharing
				SELECT t1.Code, t1.PID, t1.PName, t2.Rate, t2.Fund
				INTO #tmpSharing
				FROM dbo.RB_Payees t1
				INNER JOIN dbo.RAC_RBSharing t2 ON t2.Code = t1.Code AND t2.PID = t1.PID COLLATE DATABASE_DEFAULT
				
				--Get the Account Rebates
				INSERT INTO #tmpRebatesDetail
				        (GenID, DocEntry, LineNum, U_PackageNo, ItemCode, WhsCode, CardCode, CardName,
				         U_LabNo, U_DoctorCode, GroupCode, U_PayCode, U_PayName, ComType, ObjType,
				         LineTotal, U_Rate, U_Amount, U_Share, Fund, DedAmt)
				SELECT	@GenID,
						T1.DocEntry,
						T1.LineNum,
						U_PackageNo,
						ItemCode,
						WhsCode,
						T1.CardCode,
						CardName,
						U_LabNo,
						U_DoctorCode,
						GroupCode,
						T3.PID,
						T3.PName,
						--T3.U_PayCode,
						--U_PayName,
						ComType,
						13 ObjType,
						LineTotal,
						T1.Rate,
						Amt,
						T3.Rate [U_Share],
						T3.Fund,
						--T3.U_Share,
						0 DedAmt
				FROM	#tmpRBInvoice T1 WITH (NOLOCK)
						INNER JOIN dbo.OCRD T2 WITH (NOLOCK) ON T1.cardcode = T2.CardCode COLLATE DATABASE_DEFAULT
						INNER JOIN #tmpSharing T3 WITH (NOLOCK) ON T2.CardCode = T3.Code COLLATE DATABASE_DEFAULT
						--INNER JOIN HPCommon..OACS1 T3 WITH (NOLOCK) ON T2.CardCode = T3.Code AND T3.U_Branch = T1.whscode COLLATE DATABASE_DEFAULT
				WHERE	T1.groupcode = '100'
						AND (ISNULL(T1.Rate, 0) <> 0 OR ISNULL(T1.Amt, 0) <> 0)


				--Get the Clinician Rebates
				INSERT INTO #tmpRebatesDetail
				        (GenID, DocEntry, LineNum, U_PackageNo, ItemCode, WhsCode, CardCode, CardName,
				        U_LabNo, U_DoctorCode, GroupCode, U_PayCode, U_PayName, ComType, ObjType,
				        LineTotal, U_Rate, U_Amount, U_Share, Fund, DedAmt)
				SELECT	@GenID,
						T1.DocEntry,
						T1.LineNum,
						T1.U_PackageNo,
						T1.ItemCode,
						T1.WhsCode,
						T1.CardCode,
						T1.CardName,
						T1.U_LabNo,
						T1.U_DoctorCode,
						T1.GroupCode,
						T3.PID,
						T3.PName,
						--T3.U_PayCode,
						--T3.U_PayName,
						T1.ComType,
						13 ObjType,
						T1.LineTotal,
						T1.Rate,
						T1.Amt,
						T3.Rate [U_Share],
						t3.Fund,
						--T3.U_Share,
						0 DedAmt
				FROM	#tmpRBInvoice T1 WITH (NOLOCK)
						INNER JOIN dbo.odrs T2 WITH (NOLOCK) ON T1.u_doctorcode = T2.DCode COLLATE DATABASE_DEFAULT
						INNER JOIN #tmpSharing T3 WITH (NOLOCK) ON T2.DCode = T3.Code COLLATE DATABASE_DEFAULT
						--INNER JOIN HPCommon..OACS1 T3 WITH (NOLOCK) ON T2.DCode = T3.Code AND T3.U_Branch = T1.whscode COLLATE DATABASE_DEFAULT
				WHERE	T1.groupcode = '102'
						AND (ISNULL(T1.Rate, 0) <> 0 OR ISNULL(T1.Amt, 0) <> 0)

				--Create Rebates Rate	
				INSERT INTO dbo.RAC_RBDetailsTrans
				        (GenID, DocEntry, LineNum, U_PackageNo, ItemCode, WhsCode,
				        CardCode, U_LabNo, U_DoctorCode, GroupCode, U_PayCode,
				        ComType, ObjType, LineTotal, U_Rate, U_Amount, U_Share,
				        ReconDate, DocDate, DedAmt, RebatesAmnt, Fund)
				SELECT	T1.GenID, T1.DocEntry, T1.LineNum, T1.U_PackageNo, T1.ItemCode, REPLACE(REPLACE(LTRIM(RTRIM(T1.WhsCode)), CHAR(13), ''), CHAR(10), ''),
						T1.CardCode, T1.U_LabNo, T1.U_DoctorCode, T1.GroupCode, T1.U_PayCode,
						T1.ComType, T1.ObjType, T1.LineTotal, T1.U_Rate, T1.U_Amount, T1.U_Share,
						CASE WHEN T1.ObjType = 13 THEN T2.ReconDate ELSE T3.ReconDate END ReconDate,
						CASE WHEN T1.ObjType = 13 THEN T2.docdate ELSE T3.docdate END DocDate,
						ISNULL(DedAmt, 0),
						CAST((ISNULL(LineTotal, 0) * (ISNULL(U_Rate, 0) / 100) + ISNULL(U_Amount, 0)) * (ISNULL(U_Share, 0) / 100) AS DECIMAL(18,2)),
						CAST((ISNULL(LineTotal, 0) * (ISNULL(U_Rate, 0) / 100) + ISNULL(U_Amount, 0)) * (ISNULL(T1.Fund, 0) / 100) AS DECIMAL(18,2))
				FROM	#tmpRebatesDetail T1 WITH (NOLOCK)
						LEFT JOIN oinv T2 WITH (NOLOCK) ON T1.ObjType = 13 and T2.DocEntry = T1.DocEntry
						LEFT JOIN orin T3 WITH (NOLOCK) ON T1.ObjType = 14 and T3.DocEntry = T1.DocEntry
					

				--========================================================================================================================================================================						
				--Get the payee scheme
				IF NOT OBJECT_ID('tempDB..#tmpPScheme') IS NULL DROP TABLE #tmpPScheme
				SELECT		T2.[Desc] PayeeType, T1.Whs, T1.RangeFrom, T1.RangeTo, T1.Percnt, T1.AmntExclusion 
				INTO		#tmpPScheme
				FROM		dbo.RAC_PayeeScheme T1
							LEFT JOIN dbo.RAC_MaintenanceCode T2 ON T2.Type = 'PayeeType' AND T2.Code = T1.PayeeType
				
				--Get the rebates details
				IF NOT OBJECT_ID('tempDB..#tmpRebDets') IS NULL DROP TABLE #tmpRebDets
				SELECT		T1.GenID, T1.U_PayCode, T1.WhsCode, SUM(T1.RebatesAmnt) RebatesAmnt
				INTO		#tmpRebDets
				FROM		dbo.RAC_RBDetailsTrans T1
				WHERE		T1.GenID = @GenID
				GROUP BY	T1.GenID, T1.U_PayCode, T1.WhsCode
				
				--Get the rebates with schema
				IF NOT OBJECT_ID('tempDB..#tmpForPayment') IS NULL DROP TABLE #tmpForPayment
				SELECT		T1.GenID, T1.U_PayCode, ISNULL(T2.PName, '') PName, 
							ISNULL(T2.Add1, '') Add1, ISNULL(T2.Class, '') Class, 
							ISNULL(T2.Actype, '') Actype, ISNULL(T2.Periodtype, '') Periodtype, 
							ISNULL(T2.SlpCode, '') SlpCode, ISNULL(T3.SlpName, '') SlpName, 
							LTRIM(RTRIM(T1.WhsCode)) WhsCode, ISNULL(T1.RebatesAmnt, 0) RebatesAmnt,
							ISNULL(T4.Percnt, 100) Percnt, ISNULL(T5.AmntExclusion, 0) AmntExclusion,
							CAST(ISNULL(T1.RebatesAmnt, 0) * ISNULL(T4.Percnt, 100) / 100 AS DECIMAL(18,2)) ActualReb,
							CASE WHEN T1.RebatesAmnt >= ISNULL(T5.AmntExclusion, 0) THEN 1 ELSE 0 END isForPayment
				INTO		#tmpForPayment
				FROM		#tmpRebDets T1 WITH(NOLOCK)
							LEFT JOIN #tmpPayees T2 WITH(NOLOCK) ON T2.PID = T1.U_PayCode COLLATE DATABASE_DEFAULT
							LEFT JOIN dbo.OSLP T3 WITH(NOLOCK) ON T3.SlpCode = T2.SlpCode
							LEFT JOIN #tmpPScheme T4 WITH(NOLOCK) ON T4.Whs = T1.WhsCode AND T4.PayeeType = T2.Actype COLLATE DATABASE_DEFAULT 
								AND T1.RebatesAmnt BETWEEN T4.RangeFrom AND T4.RangeTo
							LEFT JOIN (
										SELECT PayeeType, Whs, AmntExclusion 
										FROM #tmpPScheme
										GROUP BY PayeeType, Whs, AmntExclusion											
									  ) T5 ON T5.Whs = T1.WhsCode AND T5.PayeeType = T2.Actype COLLATE DATABASE_DEFAULT


				--Update Rebates for payment
				UPDATE	dbo.RAC_RBDetailsTrans
				SET		dbo.RAC_RBDetailsTrans.isForPayment = T1.isForPayment
				FROM	#tmpForPayment T1
				WHERE	dbo.RAC_RBDetailsTrans.GenID = T1.GenID
						AND	dbo.RAC_RBDetailsTrans.WhsCode = T1.WhsCode
						AND	dbo.RAC_RBDetailsTrans.U_PayCode = T1.U_PayCode
						AND	T1.GenID = @GenID

				--Insert new GenID
				INSERT INTO dbo.SOADate 
					(FDate, TDate, GenID, AsOfDate)
				VALUES  
					(@SDate, @EDate, @GenID , @EDate)

				--========================================================================================================================================================================						
				--Update inv1 Rebates Data
				UPDATE	dbo.inv1 
				SET		Rebate = @GenID
				FROM	dbo.RAC_RBDetailsTrans T1 WITH(NOLOCK)
				WHERE	T1.DocEntry = dbo.inv1.docentry
						AND	T1.LineNum = dbo.inv1.LineNum
						AND ISNULL(dbo.inv1.Rebate, '') = ''
						AND T1.GenID = @GenID
				
				--========================================================================================================================================================================						
				DROP TABLE	#tmpRBInv, #tmpPayees, #tmpSPGrpWithInHouse, #tmpNotSPGrpWithInHouse, #tmpSpecialTest, #tmpRBInvoice, 
							#tmp1, #tmpRebatesDetail, #tmpSharing, #tmpPScheme, #tmpRebDets, #tmpForPayment
			END
	END
GO
