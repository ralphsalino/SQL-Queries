-- =============================================
-- Author:		Ralph Salino
-- Create date: 2019-08-02
-- Description:	Cheque Module
-- =============================================

ALTER PROCEDURE dbo.sp_RBCheque
		@Mode AS VARCHAR(50) = NULL,
		@PID AS VARCHAR(20) = NULL,
		@Payment AS VARCHAR(20) = NULL,
		@SlpCode AS VARCHAR(10) = NULL,
		@TranDate AS DATE = NULL,
		@ChkNum AS VARCHAR(20) = NULL,
		@CheqDate AS DATE = NULL,
		@ClearDate AS DATE = NULL,
		@IsCrossCheq AS INT = NULL,
		@RecID AS BIGINT = NULL,
		@FromChq AS VARCHAR(20) = NULL,
		@ToChq AS VARCHAR(20) = NULL,
		@VoidType AS INT = NULL,
		@Remarks AS VARCHAR(500) = NULL,
		@LineTotal AS NUMERIC(18,2) = NULL,
		@WhsCode AS VARCHAR(10) = NULL,
		@EmpID AS VARCHAR(15) = NULL,
		@AcctNo AS VARCHAR(30) = NULL,
		@PName AS VARCHAR(120) = NULL,
		@Docline AS INT = NULL,
		@FormatCode AS VARCHAR(50) = NULL,
		@GenID AS INT = NULL,
		@DocEntry AS INT = NULL

AS
BEGIN
		DECLARE @Date AS DATE = NULL

		IF @Mode = 'GetPayeeDetails'
			BEGIN
								SELECT	DISTINCT
										T1.Actype,
										T1.Class,
										T1.PID,
										T1.PName,
										T1.Add1,
										T2.SlpCode,
										T2.SlpName,
										T2.District
								FROM	dbo.RB_Payees T1
										LEFT JOIN dbo.OSLP T2 ON T1.SlpCode = T2.SlpCode
								WHERE	T1.PID = @PID
										AND T1.IsActive = 1
			END
			
		ELSE IF @Mode= 'InsertCheqHdr'
			BEGIN
								INSERT dbo.RAC_ChequeHdr
									(PID, Payment, RecDate, TranDate, isCrossCheq, Stat)
								VALUES
									(@PID, @Payment, GETDATE(), @TranDate, 1, 3)
								SELECT SCOPE_IDENTITY()									
			END

		ELSE IF @Mode = 'InsertCheqDtl'
			BEGIN
							   INSERT INTO dbo.RAC_ChequeDtl
									(PID, LineTotal, WhsCode, RecID)
							   VALUES
									(@PID, @LineTotal, @WhsCode, @RecID)
							   SELECT @@ROWCOUNT
			END

		ELSE IF @Mode = 'UpdateCheqToProcessed'
			BEGIN
								UPDATE	dbo.RAC_ChequeHdr
								SET		Stat = 4
								WHERE	GenID = @GenID
										AND CheqNum = @ChkNum
										AND AcctNo = @AcctNo
								SELECT @@ROWCOUNT
			END

		ELSE IF @Mode = 'SavePayeeDetails'
			BEGIN
								INSERT dbo.RAC_ChequeHdr
									(PID, Payment, RecDate, TranDate, isCrossCheq)
								VALUES
									(@PID, @Payment, GETDATE(), @TranDate, 1)					
			END

		ELSE IF @Mode = 'ChequeHeader'
			BEGIN
								--DECLARE @TranDate AS DATE = '2019-11-03'
								--DECLARE @Date AS DATE = NULL
								SET		@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))
								
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

								--Get the Cheque Header Monitoring
								IF NOT OBJECT_ID('tempDB..#tmpCheqHdr') IS NULL DROP TABLE #tmpCheqHdr
								SELECT		T1.PID,
											UPPER(T2.PName) [PName],
											SUM(T1.Payment) [Payment] ,
											T1.CheqNum,
											T1.CheqDate,
											T1.isCrossCheq,
											T1.TranDate,
											T3.SlpCode,
											UPPER(T3.SlpName) [SlpName],
											T1.Stat,
											T1.AcctNo,
											T1.GenID
								INTO		#tmpCheqHdr
								FROM		dbo.RAC_ChequeHdr T1
											LEFT JOIN #tmpPayees T2 ON T1.PID = T2.PID
											LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								WHERE		DATEADD(m, DATEDIFF(m, 0, T1.TranDate), 0) = @Date
								GROUP BY	T1.PID,
											T2.PName,
											T1.CheqNum,
											T1.CheqDate,
											T1.isCrossCheq,
											T1.TranDate,
											T3.SlpCode,
											T3.SlpName,
											T1.Stat,
											T1.AcctNo,
											T1.GenID
								
								--Final Query
								SELECT		T1.SlpCode,
											UPPER(T2.SlpName) [SlpName],
											CAST(CAST(COUNT(CASE WHEN T1.Stat = 4 THEN 1 ELSE NULL END) AS VARCHAR(10)) + ' / ' + CAST(COUNT(T1.PID)AS VARCHAR(10)) AS VARCHAR(10)) Total
								FROM		dbo.#tmpCheqHdr T1
											LEFT JOIN dbo.OSLP T2 ON T1.SlpCode = T2.SlpCode
											LEFT JOIN #tmpPayees T3 ON T1.PID = T3.PID
								GROUP BY	T1.SlpCode,
											T2.SlpName
								ORDER BY	T1.SlpCode

								DROP TABLE #tmpPayees, #tmpCheqHdr
			END
			
		ELSE IF @Mode = 'ChequeDetails'
			BEGIN
								--DECLARE @TranDate AS DATE = '2019-07-03'
								--DECLARE @Date AS DATE = NULL
								--DECLARE @SlpCode AS VARCHAR(10) = '-1'
								SET	@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))

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

								--Get the Cheque Header Monitoring
								IF NOT OBJECT_ID('tempDB..#tmpCheqHdr') IS NULL DROP TABLE #tmpCheqHdr
								SELECT		ISNULL(T1.CheqNum, '') [CheqNum],
											ISNULL(T1.PID, '') [PID],
											ISNULL(UPPER(T2.PName), '') [PName],
											ISNULL(SUM(T1.Payment), '0.00') [Payment],
											ISNULL(T1.CheqDate,'') CheqDate,
											ISNULL(T1.isCrossCheq, 0) isCrossCheq,
											ISNULL(T2.Add1, '') Add1,
											ISNULL(T1.Stat, 3) Stat,
											T1.GenID,
											T1.AcctNo
								FROM		dbo.RAC_ChequeHdr T1
											LEFT JOIN #tmpPayees1 T2 ON T1.PID = T2.PID
											LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								WHERE		T3.SlpCode = @SlpCode
											AND DATEADD(m, DATEDIFF(m, 0, T1.TranDate), 0) = @Date
								GROUP BY	T1.CheqNum,
											T1.PID,
											T2.PName,
											T1.CheqDate,
											T1.isCrossCheq,
											T2.Add1,
											T1.Stat,
											T1.GenID,
											T1.AcctNo

								DROP TABLE #tmpPayees1
			END
		
		ELSE IF @Mode = 'GetChequeList'
			BEGIN
								IF		@ChkNum = NULL BEGIN SET @ChkNum = '' END
								SELECT	T1.ID,
										T1.MinChk,
										T1.MaxChk,
										T2.ChkNUm,
										T2.OPNum,
										T2.Stat,
										T2.Remarks
								FROM	dbo.Checkbook T1
										INNER JOIN dbo.CheckBookDtl T2 ON T1.ID = T2.ID
								WHERE	T1.Acctype = 'OA'
										AND T1.Whscode = '011'
										AND T2.Stat = 0
										AND T2.ChkNUm LIKE '%' + @ChkNum + '%'
			END
			
		ELSE IF @Mode = 'ValidateCheqNum'
			BEGIN
								SELECT	T1.AcctNo
								FROM	dbo.Checkbook T1 WITH(NOLOCK)
										INNER JOIN dbo.CheckBookDtl T2 WITH(NOLOCK) ON	T2.ID = T1.ID
								WHERE	T1.AcctNo = @AcctNo
										AND T2.ChkNUm = @ChkNum
										AND T2.Stat = 0
			END
			
		ELSE IF @Mode = 'SaveCheqDetail'
			BEGIN
								UPDATE	dbo.RAC_ChequeHdr
								SET		CheqDate = @CheqDate,
										isCrossCheq = @IsCrossCheq,
										Payment = @Payment,
										SlpCode = @SlpCode
								WHERE	PID = @PID
										AND GenID = @GenID

								--UPDATE	dbo.CheckBookDtl
								--SET		Stat = 1
								--WHERE	ChkNUm = @ChkNum					
			END

		ELSE IF @Mode = 'SaveCheqDetailBulk'
			BEGIN
								UPDATE	dbo.RAC_ChequeHdr
								SET		CheqNum = @ChkNum,
										CheqDate = @CheqDate,
										isCrossCheq = @IsCrossCheq,
										SlpCode = @SlpCode,
										AcctNo = @AcctNo
								WHERE	PID = @PID
										AND GenID = @GenID

								UPDATE	dbo.CheckBookDtl
								SET		Stat = 1
								FROM	dbo.Checkbook T1 
								WHERE	dbo.CheckBookDtl.ID = T1.ID
										AND T1.AcctNo = @AcctNo
										AND dbo.CheckBookDtl.ChkNUm = @ChkNum
								SELECT	@@ROWCOUNT		
			END

		ELSE IF @Mode = 'VoidChequeNum'
			BEGIN
								--Insert log to void table
								INSERT INTO dbo.RAC_ChequeVoided
								(
										PID,
										Payment,
										CheqNum,
										CheqDate,
										isCrossCheq,
										TranID,
										RecDate,
										SlpCode,
										VoidType,
										Remarks,
										VoidedBy,
										AcctNo
								)
								SELECT	PID, 
										Payment, 
										CheqNum, 
										CheqDate, 
										isCrossCheq, 
										RecID, 
										GETDATE(), 
										SlpCode,
										@VoidType,
										@Remarks,
										@EmpID,
										AcctNo
								FROM	dbo.RAC_ChequeHdr 
								WHERE	GenID = @GenID
										AND CheqNum = @ChkNum
										AND AcctNo = @AcctNo

								--Reset Transaction
								UPDATE	dbo.RAC_ChequeHdr
								SET		CheqNum = NULL,
										CheqDate = NULL,
										AcctNo = NULL,
										Stat = 3
								WHERE	GenID = @GenID
										AND CheqNum = @ChkNum
										AND AcctNo = @AcctNo


								IF @VoidType = '2' --Staled
									BEGIN
										--Update Remarks in Cheque Table
										UPDATE	dbo.CheckBookDtl
										SET		Remarks = @Remarks
										FROM	dbo.Checkbook T1 
										WHERE	dbo.CheckBookDtl.ID = T1.ID
												AND T1.AcctNo = @AcctNo
												AND dbo.CheckBookDtl.ChkNUm = @ChkNum
									END
								ELSE IF @VoidType = '1' --Cancel
									BEGIN
										--Update Stat in Cheque Table
										UPDATE	dbo.CheckBookDtl
										SET		Stat = 0,
												Remarks = @Remarks
										FROM	dbo.Checkbook T1 
										WHERE	dbo.CheckBookDtl.ID = T1.ID
												AND T1.AcctNo = @AcctNo
												AND dbo.CheckBookDtl.ChkNUm = @ChkNum
									END

			END

		ELSE IF @Mode = 'SummaryTransmittal'
			BEGIN
								SET		@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))

								IF NOT OBJECT_ID('tempDB..#tmpPayees2') IS NULL DROP TABLE #tmpPayees2
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
								INTO		#tmpPayees2
								FROM		dbo.RB_Payees
								WHERE		IsActive = 1

								SELECT	ISNULL(T1.CheqNum, '') CheqNum,
										ISNULL(T1.PID, '') PID,
										ISNULL(T2.PName, '') PName,
										ISNULL(T1.Payment, '0.00') Payment,
										ISNULL(T1.CheqDate,'') CheqDate,
										ISNULL(T1.isCrossCheq, 0) isCrossCheq,
										ISNULL(T2.Add1, '') Add1,
										T3.SlpName,
										T1.RecID
								FROM	dbo.RAC_ChequeHdr T1
										LEFT JOIN #tmpPayees2 T2 ON T1.PID = T2.PID
										LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								WHERE	T3.SlpCode = @SlpCode
										AND DATEADD(m, DATEDIFF(m, 0, T1.TranDate), 0) = @Date
										AND ISNULL(T1.CheqNum, 0) > 0
			END

		ELSE IF @Mode = 'DashboardDet'
			BEGIN
								--DECLARE @TranDate AS DATE = '2019-07-03'
								--DECLARE @Date AS DATE = NULL

								SET	@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))

								IF NOT OBJECT_ID('tempDB..#tmpPayees3') IS NULL DROP TABLE #tmpPayees3
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
								INTO		#tmpPayees3
								FROM		dbo.RB_Payees
								WHERE		IsActive = 1

								--Get the Cheque Header Monitoring
								IF NOT OBJECT_ID('tempDB..#tmpChequeHdr') IS NULL DROP TABLE #tmpChequeHdr
								SELECT		ISNULL(T1.CheqNum, '') [CheqNum],
											ISNULL(T1.PID, '') [PID],
											ISNULL(UPPER(T2.PName), '') [PName],
											ISNULL(SUM(T1.Payment), '0.00') [Payment],
											ISNULL(T1.CheqDate,'') CheqDate,
											ISNULL(T1.isCrossCheq, 0) isCrossCheq,
											ISNULL(T2.Add1, '') Add1,
											ISNULL(T1.Stat, 3) Stat,
											T1.GenID,
											T1.AcctNo
								INTO		#tmpChequeHdr
								FROM		dbo.RAC_ChequeHdr T1
											LEFT JOIN #tmpPayees3 T2 ON T1.PID = T2.PID
											LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								WHERE		DATEADD(m, DATEDIFF(m, 0, T1.TranDate), 0) = @Date
								GROUP BY	T1.CheqNum,
											T1.PID,
											T2.PName,
											T1.CheqDate,
											T1.isCrossCheq,
											T2.Add1,
											T1.Stat,
											T1.GenID,
											T1.AcctNo
								
								
								--Processed
								IF NOT OBJECT_ID('tempDB..#tmpProcessed') IS NULL DROP TABLE #tmpProcessed
								SELECT		ISNULL(COUNT(*) , 0)[Processed]
								INTO		#tmpProcessed
								FROM		dbo.#tmpChequeHdr 
								WHERE		ISNULL(Stat, 3) = 4
										


								--Pending
								IF NOT OBJECT_ID('tempDB..#tmpPending') IS NULL DROP TABLE #tmpPending
								SELECT		ISNULL(COUNT(*) , 0) [Pending]
								INTO		#tmpPending
								FROM		dbo.#tmpChequeHdr 
								WHERE		ISNULL(Stat, 3) = 3
								

								--Void
								IF NOT OBJECT_ID('tempDB..#tmpVoidDets') IS NULL DROP TABLE #tmpVoidDets
								SELECT		ISNULL(T2.CheqNum, 0) [New ChequeNo], T1.CheqNum [Old ChequeNo], T1.PID, T3.PName, SUM(T1.Payment) [Amount] ,
											T1.CheqDate, T1.isCrossCheq, T3.Add1, T2.TranDate, T4.[Desc] [VoidType], T1.Remarks, T1.VoidedBy, T5.SlpName
								INTO		#tmpVoidDets
								FROM		dbo.RAC_ChequeVoided T1
											LEFT JOIN dbo.RAC_ChequeHdr T2 ON T1.TranID = T2.RecID
											LEFT JOIN #tmpPayees3 T3 ON T1.PID = T3.PID
											LEFT JOIN dbo.RAC_MaintenanceCode T4 ON T1.VoidType = T4.Code AND T4.Type = 'VoidType'
											LEFT JOIN dbo.OSLP T5 ON T5.SlpCode = T1.SlpCode
								WHERE		DATEADD(m, DATEDIFF(m, 0, TranDate), 0) = @Date --T1.TranID IN (3159, 3160)
								GROUP BY	T2.CheqNum, T1.CheqNum, T1.PID, T3.PName, T1.CheqDate, T1.isCrossCheq, T3.Add1, 
											T2.TranDate, T4.[Desc], T1.Remarks, T1.VoidedBy, T5.SlpName
								
								IF NOT OBJECT_ID('tempDB..#tmpVoid') IS NULL DROP TABLE #tmpVoid
								SELECT		ISNULL(COUNT(*), 0) [Void]
								INTO		#tmpVoid
								FROM		#tmpVoidDets

								
								--Final Query
								SELECT	T1.Processed, T2.Pending, T3.Void
								FROM	#tmpProcessed T1,  #tmpPending T2, #tmpVoid T3
			END

		ELSE IF @Mode = 'GetProcessed'
			BEGIN
								--DECLARE @TranDate AS DATE = '2019-07-03'
								--DECLARE @Date AS DATE = NULL
								
								SET	@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))
								IF NOT OBJECT_ID('tempDB..#tmpPayees4') IS NULL DROP TABLE #tmpPayees4
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
								INTO		#tmpPayees4
								FROM		dbo.RB_Payees
								WHERE		IsActive = 1


								--Get the Cheque Header Monitoring
								IF NOT OBJECT_ID('tempDB..#tmpCheqHdr') IS NULL DROP TABLE #tmpCheqHdr
								SELECT		ISNULL(T1.CheqNum, '') [CheqNum],
											ISNULL(T1.PID, '') [PID],
											ISNULL(UPPER(T2.PName), '') [PName],
											ISNULL(SUM(T1.Payment), '0.00') [Payment],
											ISNULL(T1.CheqDate,'') CheqDate,
											ISNULL(T1.isCrossCheq, 0) isCrossCheq,
											ISNULL(T2.Add1, '') Add1,
											T3.SlpName,
											T1.SlpCode,
											T1.GenID
								FROM		dbo.RAC_ChequeHdr T1
											LEFT JOIN #tmpPayees4 T2 ON T1.PID = T2.PID
											LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								WHERE		ISNULL(T1.Stat, 3) = 4
											AND DATEADD(m, DATEDIFF(m, 0, T1.TranDate), 0) = @Date
								GROUP BY	T1.CheqNum,
											T1.PID,
											T2.PName,
											T1.CheqDate,
											T1.isCrossCheq,
											T2.Add1,
											T3.SlpName,
											T1.SlpCode,
											T1.GenID

								--SET		@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))
								--SELECT	ISNULL(T1.CheqNum, '') CheqNum,
								--		ISNULL(T1.PID, '') PID,
								--		ISNULL(T2.PName, '') PName,
								--		ISNULL(T1.Payment, '0.00') Payment,
								--		ISNULL(T1.CheqDate,'') CheqDate,
								--		ISNULL(T1.isCrossCheq, 0) isCrossCheq,
								--		ISNULL(T2.Add1, '') Add1,
								--		T3.SlpName,
								--		T3.SlpCode,
								--		T1.RecID
								--FROM	dbo.RAC_ChequeHdr T1
								--		LEFT JOIN dbo.RB_Payees T2 ON T1.PID = T2.PID
								--		LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								--WHERE	ISNULL(T1.Stat, 3) = 4
								--		AND DATEADD(m, DATEDIFF(m, 0, TranDate), 0) = @Date
			END

		ELSE IF @Mode = 'GetPending'
			BEGIN
								--DECLARE @TranDate AS DATE = '2019-07-03'
								--DECLARE @Date AS DATE = NULL
								
								SET	@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))

								IF NOT OBJECT_ID('tempDB..#tmpPayees5') IS NULL DROP TABLE #tmpPayees5
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
								INTO		#tmpPayees5
								FROM		dbo.RB_Payees
								WHERE		IsActive = 1

								--Get the Cheque Header Monitoring
								IF NOT OBJECT_ID('tempDB..#tmpCheqHdr') IS NULL DROP TABLE #tmpCheqHdr
								SELECT		ISNULL(T1.CheqNum, '') [CheqNum],
											ISNULL(T1.PID, '') [PID],
											ISNULL(UPPER(T2.PName), '') [PName],
											ISNULL(SUM(T1.Payment), '0.00') [Payment],
											ISNULL(T1.CheqDate,'') CheqDate,
											ISNULL(T1.isCrossCheq, 0) isCrossCheq,
											ISNULL(T2.Add1, '') Add1,
											T3.SlpName,
											T1.SlpCode,
											T1.GenID
								FROM		dbo.RAC_ChequeHdr T1
											LEFT JOIN #tmpPayees5 T2 ON T1.PID = T2.PID
											LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								WHERE		ISNULL(T1.Stat, 3) = 3
											AND DATEADD(m, DATEDIFF(m, 0, T1.TranDate), 0) = @Date
								GROUP BY	T1.CheqNum,
											T1.PID,
											T2.PName,
											T1.CheqDate,
											T1.isCrossCheq,
											T2.Add1,
											T3.SlpName,
											T1.SlpCode,
											T1.GenID


								--SET		@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))
								--SELECT	ISNULL(T1.CheqNum, '') CheqNum,
								--		ISNULL(T1.PID, '') PID,
								--		ISNULL(T2.PName, '') PName,
								--		ISNULL(T1.Payment, '0.00') Payment,
								--		ISNULL(T1.CheqDate,'') CheqDate,
								--		ISNULL(T1.isCrossCheq, 0) isCrossCheq,
								--		ISNULL(T2.Add1, '') Add1,
								--		T3.SlpName,
								--		T3.SlpCode,
								--		T1.RecID
								--FROM	dbo.RAC_ChequeHdr T1
								--		LEFT JOIN dbo.RB_Payees T2 ON T1.PID = T2.PID
								--		LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
								--WHERE	ISNULL(T1.Stat, 3) = 3
								--		AND DATEADD(m, DATEDIFF(m, 0, TranDate), 0) = @Date
			END
		ELSE IF @Mode = 'GetVoided'
			BEGIN
								--DECLARE @TranDate AS DATE = '2019-07-03'
								--DECLARE @Date AS DATE = NULL

								SET	@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))

								IF NOT OBJECT_ID('tempDB..#tmpPayees6') IS NULL DROP TABLE #tmpPayees6
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
								INTO		#tmpPayees6
								FROM		dbo.RB_Payees
								WHERE		IsActive = 1

								SELECT		ISNULL(T2.CheqNum, 0) [NewCheqNum], T1.CheqNum [OldCheqNum], T1.PID, T3.PName, SUM(T1.Payment) [Payment] ,
											T1.CheqDate, T1.isCrossCheq, T3.Add1, T2.TranDate, T4.[Desc] [VoidType], T1.Remarks, T1.VoidedBy, T5.SlpName
								FROM		dbo.RAC_ChequeVoided T1
											LEFT JOIN dbo.RAC_ChequeHdr T2 ON T1.TranID = T2.RecID
											LEFT JOIN #tmpPayees6 T3 ON T1.PID = T3.PID
											LEFT JOIN dbo.RAC_MaintenanceCode T4 ON T1.VoidType = T4.Code AND T4.Type = 'VoidType'
											LEFT JOIN dbo.OSLP T5 ON T5.SlpCode = T1.SlpCode
								WHERE		DATEADD(m, DATEDIFF(m, 0, TranDate), 0) = @Date 
								GROUP BY	T2.CheqNum, T1.CheqNum, T1.PID, T3.PName, T1.CheqDate, T1.isCrossCheq, T3.Add1, 
											T2.TranDate, T4.[Desc], T1.Remarks, T1.VoidedBy, T5.SlpName

								--SET		@Date = (SELECT DATEADD(m, DATEDIFF(m, 0, @TranDate), 0))
								--SELECT	ISNULL(T2.CheqNum, 0) [NewCheqNum],
								--		ISNULL(T1.CheqNum, 0) [OldCheqNum],
								--		ISNULL(T1.PID, '') PID,
								--		ISNULL(T3.PName, '') PName,
								--		ISNULL(T1.Payment, '0.00') Payment,
								--		ISNULL(T1.CheqDate,'') CheqDate,
								--		ISNULL(T1.isCrossCheq, 0) isCrossCheq,
								--		ISNULL(T3.Add1, '') Add1,
								--		T2.TranDate,
								--		T5.[Desc] [VoidType],
								--		T1.Remarks,
								--		T1.VoidedBy,
								--		T4.SlpName,
								--		T1.TranID 
								--FROM	dbo.RAC_ChequeVoided T1
								--		LEFT JOIN dbo.RAC_ChequeHdr T2 ON T1.TranID = T2.RecID
								--		LEFT JOIN dbo.RB_Payees T3 ON T1.PID = T3.PID
								--		LEFT JOIN dbo.OSLP T4 ON T1.SlpCode = T4.SlpCode
								--		LEFT JOIN dbo.RAC_MaintenanceCode T5 ON T5.Type = 'VoidType' AND T1.VoidType = T5.Code
								--WHERE	DATEADD(m, DATEDIFF(m, 0, TranDate), 0) = @Date
								--ORDER BY 
								--		T3.PName
			END

		ELSE IF @Mode = 'LoadVoidType'
			BEGIN
								SELECT	Code, [Desc] 
								FROM	dbo.RAC_MaintenanceCode
								WHERE	Module = 'Cheque Monitoring'
										AND Type = 'VoidType'
			END

		ELSE IF @Mode = 'LoadChequeAccountNo'
			BEGIN
								SELECT DISTINCT AcctNo FROM dbo.Checkbook WHERE Whscode = '011' AND ChkType = 'Rebates'
			END

		ELSE IF @Mode = 'LoadCheque'
			BEGIN
								SELECT	T1.ID,
										T1.MinChk,
										T1.MaxChk,
										T2.ChkNUm,
										T2.OPNum,
										T2.Stat,
										T1.AcctNo,
										T2.Remarks
								FROM	dbo.Checkbook T1
										INNER JOIN dbo.CheckBookDtl T2 ON T1.ID = T2.ID
								WHERE	T1.Acctype = 'OA'
										AND T1.Whscode = '011'
										AND T1.ChkType = 'Rebates'
										AND	T1.AcctNo = @AcctNo
										AND T2.Stat = 0
			END
			
		ELSE IF @Mode = 'LoadClearCheque'
			BEGIN

								IF NOT OBJECT_ID('tempDB..#tmpPayees7') IS NULL DROP TABLE #tmpPayees7
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
								INTO		#tmpPayees7
								FROM		dbo.RB_Payees
								WHERE		IsActive = 1

								--Get the for clearing cheque
								IF NOT OBJECT_ID('tempDB..#tmpForClearing') IS NULL DROP TABLE #tmpForClearing
								SELECT		PID, SUM(Payment) [Payment], CheqNum, CheqDate, isCrossCheq,
											SlpCode, Stat, AcctNo, GenID
								INTO		#tmpForClearing
								FROM		dbo.RAC_ChequeHdr 
								WHERE		Stat = 4
								GROUP BY	PID, CheqNum, CheqDate, isCrossCheq,
											SlpCode, Stat, AcctNo, GenID

								--Get the cleared cheque
								IF NOT OBJECT_ID('tempDB..#tmpCleared') IS NULL DROP TABLE #tmpCleared
								SELECT		T1.PID, T3.PName, T1.AcctNo, T1.CheqNum, T1.CheqDate, T2.ChkDate [ClearDate], T1.Payment,
											T1.GenID, T1.Payment - T2.Credit - T2.Debit [Bal]
								INTO		#tmpCleared
								FROM		dbo.#tmpForClearing T1 WITH(NOLOCK)
											INNER JOIN BIR..UBPpassBook T2 WITH(NOLOCK) ON T1.AcctNo = T2.AcctNo COLLATE DATABASE_DEFAULT  AND CAST(T1.CheqNum AS VARCHAR(50)) = T2.ChkNum 
											LEFT JOIN #tmpPayees7 T3  WITH(NOLOCK) ON T1.PID = T3.PID
								WHERE		T1.Stat = 4

								--Final query
								SELECT		* 
								FROM		#tmpCleared
								WHERE		Bal = 0


								--UPDATE		dbo.RAC_ChequeHdr 
								--SET			RAC_ChequeHdr.Stat = 5
								--FROM		#tmpCleared T1
								--WHERE		T1.CheqNum = dbo.RAC_ChequeHdr.CheqNum
								--			AND T1.AcctNo = dbo.RAC_ChequeHdr.AcctNo

								--SELECT	T1.PID, T3.PName, T1.AcctNo, T1.CheqNum, T1.CheqDate, T2.ChkDate [ClearDate], T1.Payment, T1.RecID
								--FROM	dbo.RAC_ChequeHdr T1 WITH(NOLOCK)
								--		INNER JOIN BIR..UBPpassBook T2 WITH(NOLOCK) ON T1.AcctNo = T2.AcctNo COLLATE DATABASE_DEFAULT  AND T1.CheqNum = T2.ChkNum 
								--		LEFT JOIN dbo.RB_Payees T3  WITH(NOLOCK) ON T1.PID = T3.PID
								--WHERE	T1.Stat = 4
								--		AND T1.Payment = (T2.Credit - T2.Debit)
								--ORDER BY 
								--		T1.CheqNum
			END

		ELSE IF @Mode = 'InsertCheqHdrJE'
			BEGIN
								INSERT INTO Bookkeeping..RebatesHdr
									(BenefName, ChkNum, ChkDate, ChkAmt, TotalAmt, ClearDate, TransID, Stat, Cancelled, BDRemarks, BDStat, AcctNo)
								VALUES
									(@PName, @ChkNum, @CheqDate, @Payment, @Payment, @ClearDate, NULL, 'C', '0', NULL, NULL, @AcctNo)
								SELECT SCOPE_IDENTITY()
			END

		ELSE IF @Mode = 'LoadChequeDtl'
			BEGIN
								SELECT		T2.PID, T2.LineTotal ,T2.WhsCode 
								FROM		dbo.RAC_ChequeHdr T1
											LEFT JOIN dbo.RAC_ChequeDtl T2 ON T1.GenID = T2.GenID AND T2.PID = T1.PID COLLATE DATABASE_DEFAULT
								WHERE		T1.PID = @PID
											AND	T1.CheqNum = @ChkNum
											AND T1.AcctNo = @AcctNo
											AND T1.GenID = @GenID
								ORDER BY	CAST(T2.WhsCode AS INT)

								--SELECT	PID, LineTotal, WhsCode
								--FROM	dbo.RAC_ChequeDtl 
								--WHERE	RecID = @RecID
								--ORDER BY 
								--		CAST(WhsCode AS INT)
			END

		ELSE IF @Mode = 'InsertCheqDtlJE'
			BEGIN
								INSERT INTO Bookkeeping..RebatesDtl
									(Docentry, DocLine, ChkNum, WhsCode, Amt)
								VALUES
									(@DocEntry, @Docline, @ChkNum, @WhsCode, @LineTotal)
								SELECT @@ROWCOUNT            
			END

		ELSE IF @Mode = 'GetAccountName'
			BEGIN
								SELECT AcctName FROM HPDI..OACT WHERE FormatCode = @FormatCode
			END

		ELSE IF @Mode = 'ForJournalEntry'
			BEGIN
								SELECT	T1.DocEntry, T1.TransID, T1.BenefName, 
										T1.ChkNum, T1.ChkDate, T2.WhsCode, 
										T2.Amt, T1.ClearDate,T1.AcctNo,
										T3.BankCode + '011000' [BankCode]
								FROM	Bookkeeping..RebatesHdr T1 WITH(NOLOCK)
										INNER JOIN Bookkeeping..RebatesDtl T2 WITH(NOLOCK) ON T1.DocEntry = T2.Docentry
										LEFT JOIN Bookkeeping..BkAccts T3 WITH(NOLOCK) ON T1.AcctNo = T3.AcctNo
								WHERE	T1.TransID IS NULL 
										AND T1.ClearDate IS NOT NULL 
										AND T1.ClearDate != '1900-01-02 00:00:00.000'
										AND T1.ChkDate >= DATEADD(DAY, 1, DATEADD(MONTH, - 6, GETDATE())) 
								ORDER BY 
										T1.ChkNum
			END

END    
GO
