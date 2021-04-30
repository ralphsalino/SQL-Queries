-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-01-09
-- Description:	Rebates Payee Setup
-- =============================================

ALTER PROCEDURE dbo.sp_RBPayeeSetup
    @Mode AS VARCHAR(100) = NULL,
	@PName AS VARCHAR(100) = NULL,
	@PID AS VARCHAR(10) = NULL,
	@Class AS VARCHAR(15) = NULL,
	@AcctNum AS VARCHAR(50) = NULL,
	@Address AS VARCHAR(300) = NULL,
	@SlpCode AS VARCHAR(10) = NULL,
	@Hosp AS VARCHAR(100) = NULL,
	@TelNo AS VARCHAR(20) = NULL,
	@PayeeType AS VARCHAR(50) = NULL,
	@PeriodType AS VARCHAR(50) = NULL,
	@SearchType VARCHAR(10) = NULL,
	@Search VARCHAR(100) = NULL,
	@DropDownType VARCHAR(50) = NULL,
	@IsActive INT = NULL,
	@Dispatch VARCHAR(50) = NULL, 
	@IsCrossCheck INT = NULL, 
	@IsSpecialTest INT = NULL,
	@ClassType VARCHAR(20) = NULL,
	@PCode VARCHAR(20) = NULL,
	@Code VARCHAR(10) = NULL,
	@Rate DECIMAL(18,2) = NULL,
	@Fund DECIMAL(18,2) = NULL,
	@EmpID VARCHAR(50) = NULL

AS
    BEGIN


			IF @Mode = 'LoadDropDown'
				BEGIN
									SELECT	Code, [Desc] 
									FROM	dbo.RAC_MaintenanceCode 
									WHERE	Module = 'PayeeSetup' 
											AND isActive = 1 
											AND Type = @DropDownType
				END

			ELSE IF @Mode = 'CheckingPayee'
				BEGIN
									SELECT DISTINCT PID FROM RB_Payees WHERE Class <> 'Fund'
				END

			ELSE IF @Mode = 'GetMainPayee'
				BEGIN
									SELECT DISTINCT PID, PName 
									FROM dbo.RB_Payees
									WHERE ISNULL(Class, '') <> 'Secretary'
									AND PID = @PID
									--DECLARE @Length INT
									--SET @Length = CHARINDEX('-', @PID)
									--IF @Length = 0
									--	BEGIN
									--		SELECT PID + ' - ' + PName [PayeeName] FROM dbo.RB_Payees WHERE PID = @PID
									--	END
									--ELSE
									--	BEGIN
									--		SELECT PID + ' - ' + PName [PayeeName] FROM dbo.RB_Payees WHERE PID = LEFT(@PID, CHARINDEX('-', @PID) - 1)
									--	END
				END

			ELSE IF @Mode = 'LoadPayeeList'
				BEGIN
									IF @SearchType = 'Payee Name' 
										BEGIN 
											SET @PName = @Search
											SET @PID = NULL
										END

									IF @SearchType = 'Payee ID' 
										BEGIN 
											SET @PID = @Search
											SET @PName = NULL
										END


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
									--WHERE		Class <> 'Secretary'
									WHERE		(@ClassType IS NULL OR Class LIKE '%' + @ClassType + '%')
												AND (@PName IS NULL OR PName LIKE '%' + @PName + '%')
												AND (@PID IS NULL OR PID = @PID)
												AND IsActive = @IsActive

									--Final Qry
									SELECT		T1.PID,
												ISNULL(T1.PName, '') PName,
												ISNULL(UPPER(T1.Class), '') Class,
												ISNULL(AcctNum, '') AcctNum,
												ISNULL(TelNo, '') Telno,
												ISNULL(Hosp, '') Hosp,
												ISNULL(Add1, '') [Address],
												ISNULL(t2.SlpName, '') SlpName,
												ISNULL(UPPER(CAST(T1.SlpCode AS VARCHAR(20)) + ' - ' + T2.SlpName), '') SalesRep,
												ISNULL(Actype, '') PayeeType,
												ISNULL(Periodtype, '') PeriodType,
												ISNULL(T1.SlpCode, '') SlpCode,
												ISNULL(T1.DispatchType, '') Dispatch,
												ISNULL(T1.IsCrossCheck, 0) IsCrossCheck,
												ISNULL(T1.IsSpecialTest, 1) IsSpecialTest,
												ISNULL(T1.IsActive, 1) IsActive
									FROM		#tmpPayees t1
												LEFT JOIN HPDI..OSLP t2 ON t2.SlpCode = t1.SlpCode
				END

			ELSE IF @Mode = 'AddPayee'
				BEGIN
									
									INSERT INTO dbo.RB_Payees
											(PID, PName, Class, AcctNum, Add1, Hosp, TelNo, Actype, 
											 Periodtype, DispatchType, IsCrossCheck, IsSpecialTest, IsActive, Code)
									VALUES
											(@PID, @PName, @Class, @AcctNum, @Address, @Hosp, @TelNo, @PayeeType, 
											 @PeriodType, @Dispatch, @IsCrossCheck, @IsSpecialTest, 1, @Code)

									--
									IF NOT EXISTS(SELECT * FROM dbo.RAC_RBSharing WHERE Code = @Code AND PID = @PID)
										BEGIN
											INSERT INTO dbo.RAC_RBSharing
												(Code, PID, Rate, Fund, CreatedBy, RecDate)
											VALUES  
												(@Code, @PID, @Rate, @Fund, @EmpID, GETDATE())
										END
				END

			ELSE IF @Mode = 'UpdatePayee'
				BEGIN
									UPDATE		dbo.RB_Payees
									SET			PName = @PName,
												Class = @Class,
												AcctNum = @AcctNum,
												Add1 = @Address,
												Hosp = @Hosp,
												TelNo = @TelNo,
												Actype = @PayeeType,
												Periodtype = @PeriodType,
												DispatchType = @Dispatch,
												IsCrossCheck = @IsCrossCheck,
												IsSpecialTest = @IsSpecialTest
									WHERE		PID = @PID

									--
									UPDATE		dbo.RAC_RBSharing
									SET			Rate = @Rate,
												Fund = @Fund
									WHERE		Code = @Code
												AND PID = @PID

									--UPDATE		dbo.RB_Payees
									--SET			PName = @PName,
									--			Class = @Class,
									--			AcctNum = @AcctNum,
									--			Add1 = @Address,
									--			Hosp = @Hosp,
									--			TelNo = @TelNo,
									--			Actype = @PayeeType,
									--			Periodtype = @PeriodType,
									--			DispatchType = @Dispatch,
									--			IsCrossCheck = @IsCrossCheck,
									--			IsSpecialTest = @IsSpecialTest
									--WHERE		Code = @Code 
									--			AND PID = @PID

									--
									--UPDATE		dbo.RAC_RBSharing
									--SET			Rate = @Rate,
									--			Fund = @Fund
									--WHERE		Code = @Code
									--			AND PID = @PID

				END

			ELSE IF @Mode = 'Details'
				BEGIN 
									--DECLARE @PCode VARCHAR(20) = '22753',
									--		@Class VARCHAR(20) = 'Clinician'

									IF @Class = 'Clinician'
										BEGIN
											--Clinician
											IF NOT OBJECT_ID('tempDB..#tmpClinician1') IS NULL DROP TABLE #tmpClinician1
											SELECT	t1.PID, 
													t1.PName, 
													t1.Class, 
													ISNULL(t1.AcctNum, '') AcctNum, 
													ISNULL(t1.TelNo, '') TelNo, 
													ISNULL(t1.Hosp, '') Hosp, 
													ISNULL(t1.Add1, '') Add1,
													t1.SlpCode, 
													ISNULL(t1.Actype, '') Actype, 
													ISNULL(t1.Periodtype, '') Periodtype,  
													ISNULL(t1.DispatchType, '') DispatchType, 
													ISNULL(t2.Rate, 0.00) Rate, 
													ISNULL(t2.Fund, 0.00) Fund,
													t1.IsCrossCheck,
													t1.IsSpecialTest,
													t1.Code
											INTO	#tmpClinician1
											FROM	dbo.RB_Payees t1
													LEFT JOIN dbo.RAC_RBSharing t2 ON t2.Code = t1.Code AND t2.PID = t1.PID COLLATE DATABASE_DEFAULT
											WHERE	t1.Code = @PCode
													AND	t1.Class = 'Clinician'
											
											--Secretary
											IF NOT OBJECT_ID('tempDB..#tmpSecretary1') IS NULL DROP TABLE #tmpSecretary1
											SELECT	t1.PID, 
													t1.PName, 
													t1.Class, 
													ISNULL(t1.AcctNum, '') AcctNum, 
													ISNULL(t1.TelNo, '') TelNo, 
													ISNULL(t1.Hosp, '') Hosp, 
													ISNULL(t1.Add1, '') Add1,
													t1.SlpCode, 
													ISNULL(t1.Actype, '') Actype, 
													ISNULL(t1.Periodtype, '') Periodtype,  
													ISNULL(t1.DispatchType, '') DispatchType, 
													ISNULL(t2.Rate, 0.00) Rate, 
													ISNULL(t2.Fund, 0.00) Fund,
													t1.Code
											INTO	#tmpSecretary1
											FROM	dbo.RB_Payees t1
													LEFT JOIN dbo.RAC_RBSharing t2 ON t2.Code = t1.Code AND t2.PID = t1.PID COLLATE DATABASE_DEFAULT
											WHERE	t1.Code = @PCode
													AND	t1.Class = 'Secretary'
											
											
											--
											SELECT	ISNULL(t1.PID, '') DocCode,
													ISNULL(t1.PName, '') DocName,
													ISNULL(t2.PID, '') SecCode,
													ISNULL(t2.PName, '') SecName,
													ISNULL(t1.Class, '') Class,
													ISNULL(t1.AcctNum, '') AcctNum,
													ISNULL(t1.TelNo, '') TelNo, 
													ISNULL(t1.Hosp, '') Hosp, 
													ISNULL(t1.Add1, '') Add1,
													ISNULL(t1.SlpCode, -1) SlpCode,
													ISNULL(t3.SlpName, '-No Sales Employee-') SlpName,
													ISNULL(t1.Actype, '') Actype, 
													ISNULL(t1.Periodtype, '') Periodtype,  
													ISNULL(t1.DispatchType, '') DispatchType,
													ISNULL(t1.IsCrossCheck, 0) IsCrossCheck, 
													ISNULL(t1.IsSpecialTest, 0) IsSpecialTest,
													ISNULL(t1.Rate, 0.00) DocRate,
													ISNULL(t2.Rate, 0.00) SecRate,
													ISNULL(t1.Fund, 0.00) DocFund,
													t1.Code,
													dbo.fn_GetMainPayee(t1.Code) CodeName
											FROM	#tmpClinician1 t1
													LEFT JOIN #tmpSecretary1 t2 ON t2.Code = t1.Code COLLATE DATABASE_DEFAULT
													LEFT JOIN dbo.OSLP t3 ON t3.SlpCode = t1.SlpCode

											DROP TABLE #tmpClinician1, #tmpSecretary1
										END
									ELSE IF @Class = 'Secretary'
										BEGIN
											--Clinician
											IF NOT OBJECT_ID('tempDB..#tmpClinician') IS NULL DROP TABLE #tmpClinician
											SELECT	PID, PName, Class, AcctNum, Add1,
													SlpCode, Hosp, TelNo, Actype, Periodtype,
													DispatchType, IsCrossCheck, IsSpecialTest,
													IsActive, Code, RecID 
											INTO	#tmpClinician
											FROM	dbo.RB_Payees 
											WHERE	Code IN (SELECT Code FROM dbo.RB_Payees WHERE PID = @PCode) 
													AND Class = 'Clinician'
													AND	IsActive = 1
										
										
											--Secretary
											IF NOT OBJECT_ID('tempDB..#tmpSecretary') IS NULL DROP TABLE #tmpSecretary
											SELECT	PID, PName, Class, AcctNum, Add1,
													SlpCode, Hosp, TelNo, Actype, Periodtype,
													DispatchType, IsCrossCheck, IsSpecialTest,
													IsActive, Code, RecID 
											INTO	#tmpSecretary
											FROM	dbo.RB_Payees 
											WHERE	Code IN (SELECT Code FROM dbo.RB_Payees WHERE PID = @PCode) 
													AND Class = 'Secretary' 
													AND PID = @PCode
													AND	IsActive = 1

											--Final Query
											SELECT	ISNULL(t1.Code, '') DocCode, 
													ISNULL(t2.PName, '') DocName,
													ISNULL(t1.PID, '') SecCode, 
													ISNULL(t1.PName, '') SecName, 
													ISNULL(t1.Class, '') Class,
													ISNULL(t1.AcctNum, '') AcctNum,
													ISNULL(t1.TelNo, '') TelNo, 
													ISNULL(t1.Hosp, '') Hosp, 
													ISNULL(t1.Add1, '') Add1,
													ISNULL(t1.SlpCode, -1) SlpCode,
													ISNULL(t5.SlpName, '-No Sales Employee-') SlpName, 
													ISNULL(t1.Actype, '') Actype, 
													ISNULL(t1.Periodtype, '') Periodtype,  
													ISNULL(t1.DispatchType, '') DispatchType, 
													ISNULL(t1.IsCrossCheck, 0) IsCrossCheck,
													ISNULL(t1.IsSpecialTest, 0) IsSpecialTest,
													ISNULL(t4.Rate, 0.00) DocRate,
													ISNULL(t3.Rate, 0.00) SecRate,  
													ISNULL(t4.Fund, 0.00) DocFund,
													t2.Code,
													dbo.fn_GetMainPayee(t2.Code) CodeName
											FROM	#tmpSecretary t1
													LEFT JOIN #tmpClinician t2 ON t2.PID = t1.Code COLLATE DATABASE_DEFAULT
													LEFT JOIN dbo.RAC_RBSharing t3 ON t3.Code = t1.Code AND t3.PID = t1.PID COLLATE DATABASE_DEFAULT
													LEFT JOIN dbo.RAC_RBSharing t4 ON t4.Code = t2.Code AND t4.PID = t2.PID COLLATE DATABASE_DEFAULT
													LEFT JOIN dbo.OSLP t5 ON t5.SlpCode = t1.SlpCode

											DROP TABLE #tmpSecretary, #tmpClinician

										END	               
				END
	END
GO
