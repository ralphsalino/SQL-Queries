--SET QUOTED_IDENTIFIER ON|OFF
--SET ANSI_NULLS ON|OFF
--GO
ALTER PROCEDURE dbo.sp_RBDoctorMaintenance
    	
	@Mode AS VARCHAR(100) = NULL,
	@SlpCode AS VARCHAR(50) = NULL,
	@DCode AS VARCHAR(50) = NULL,
	@DName AS VARCHAR(100) = NULL,
	@Hosp AS VARCHAR(250) = NULL,
	@HospLoc AS VARCHAR(250) = NULL,
	@Address AS VARCHAR(250) = NULL,
	@Sched AS VARCHAR(250) = NULL,
	@Specialization AS VARCHAR(250) = NULL,
	@AcctNo AS VARCHAR(250) = NULL,
	@BDate AS DATETIME = NULL,
	@Phone AS VARCHAR(100) = NULL,
	@Email AS VARCHAR(250) = NULL,
	@Remarks AS VARCHAR(250) = NULL,
	@TaggedDate AS DATE = NULL,
	@PCode AS VARCHAR(20) = NULL,
	@PID VARCHAR(10) = NULL,
	@PName VARCHAR(100) = NULL, 
	@PayeeType VARCHAR(50) = NULL,
	@Class VARCHAR(50) = NULL, 
	@PeriodType VARCHAR(50) = NULL,
	@Share DECIMAL(18,2) = NULL,
	@Branch VARCHAR(10) = NULL
	
AS
    BEGIN
	DECLARE @BranchName VARCHAR(50) = (SELECT Blk FROM dbo.SAPSet WHERE Code = @Branch)

		IF @Mode = 'LoadDoctorList'
			BEGIN
							SELECT		TOP 100 ISNULL(T1.DCode, '') DCode, ISNULL(T1.DName, '') DName, ISNULL(T1.Hosp, '') Hosp,  
										ISNULL(T1.U_Location, '') U_Location, ISNULL(T1.Add1, '') Add1, ISNULL(T1.Sched, '') Sched, 
										ISNULL(T1.SlpCode + '-' + T2.SlpName, 'NO SETUP') [SlpName], ISNULL(T1.Specialization, '') Specialization, ISNULL(T1.AcctNo, '') AcctNo, 
										ISNULL(T1.BDate, '') BDate, ISNULL(T1.Phone1, '') Phone1, ISNULL(T1.Email, '') Email, ISNULL(T1.Remarks, '') Remarks,
										T2.SlpCode
							FROM		dbo.odrs T1
										LEFT JOIN dbo.OSLP T2 ON T1.SlpCode = T2.SlpCode
							WHERE		@DName IS NULL OR ISNULL(DName, '') LIKE '%' + @DName + '%'
			END

		ELSE IF @Mode = 'GetSAPSlpCode'
			BEGIN
							SELECT		COUNT(*) 
							FROM		HPDI..OSLP 
							WHERE		SlpCode = @SlpCode
			END

		ELSE IF @Mode = 'ValidateDoctor'
			BEGIN
							SELECT		COUNT(*)
							FROM		dbo.odrs
							WHERE		DCode = @DCode
			END
			
		ELSE IF @Mode = 'AddDoctor'
			BEGIN
							DECLARE @rowCnt INT
							DECLARE @whsCodeDoc VARCHAR(10)
							DECLARE @whsNameDoc VARCHAR(20)

							INSERT INTO dbo.odrs
							(
								DCode, DName, Hosp, U_Location, Add1, Sched, 
								Specialization, AcctNo, BDate, 
								Phone1, Email, Remarks
							)
							VALUES
							(
								@DCode, @DName, @Hosp, @HospLoc, @Address, @Sched,
								@Specialization, @AcctNo, @BDate,
								@Phone, @Email, @Remarks
							)
							SET @rowCnt = @@ROWCOUNT

							IF @rowCnt > 0
								BEGIN

									INSERT INTO dbo.RB_Payees
											(PID, PName, Class, AcctNum, Add1, Hosp, TelNo, Actype, Periodtype)
									VALUES
											(@DCode, @DName, 'Clinician', @AcctNo, @Address, @Hosp, @Phone, 'CLINICIAN', 'MONTHLY')

									DECLARE cur_loop CURSOR LOCAL FOR
										SELECT Code, Blk FROM dbo.SAPSet WHERE Stat = 'O'
									OPEN cur_loop 
									FETCH NEXT FROM cur_loop INTO @whsCodeDoc, @whsNameDoc
									WHILE @@FETCH_STATUS = 0
										BEGIN
											INSERT INTO dbo.OACS1
												(Code, LineId, Object, LogInst, U_PayCode, U_PayName, U_Branch, U_BName, U_Class, U_AcntNo, U_Share)		
											VALUES
												(
													@DCode, 
													(SELECT dbo.fn_GetMaxID('GetMaxLineId', @DCode)), 
													'FTOACS', 
													NULL, 
													@DCode, 
													@DName, 
													@whsCodeDoc, 
													@whsNameDoc, 
													'Clinician', 
													@AcctNo, 
													'100'
												)								
											FETCH NEXT FROM cur_loop INTO @whsCodeDoc, @whsNameDoc
										END	
									CLOSE cur_loop
									DEALLOCATE cur_loop
								END
							SELECT @rowCnt
			END

		ELSE IF @Mode = 'EditDoctor'
			BEGIN
							UPDATE		dbo.odrs
							SET			DName = @DName,
										Hosp = @Hosp,
										U_Location = @HospLoc,
										Add1 = @Address,
										Sched = @Sched,
										Specialization = @Specialization,
										AcctNo = @AcctNo,
										BDate = @BDate,
										Phone1 = @Phone,
										Email = @Email,
										Remarks = @Remarks
							WHERE		DCode = @DCode
							SELECT @@ROWCOUNT
			END

		ELSE IF @Mode = 'GetTaggedSalesRep'
			BEGIN
							SELECT		T1.DCode, T1.DName, T2.SlpCode, 
										UPPER(T3.SlpName) [SlpName], 
										T2.SDate, T2.EDate, T2.EncodeDate
							FROM		dbo.odrs T1
										LEFT JOIN dbo.BPSlp T2 ON T1.DCode = T2.BPCode AND T2.SType = 102
										LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
							WHERE		T1.DCode = @DCode
							ORDER BY	CAST(T2.SDate AS DATE)
			END

		ELSE IF @Mode = 'LoadSalesRepList'
			BEGIN
							SELECT		SlpCode [Code],
										UPPER(CAST(SlpCode AS VARCHAR(10)) + ' -			' + SlpName) [Desc] 
							FROM		dbo.OSLP            
			END

		ELSE IF @Mode = 'TaggedSalesRep'
			BEGIN
							--DECLARE @SlpCode AS INT	= 94
							--DECLARE @DCode AS VARCHAR(50) = '00000'
							--DECLARE @DName AS VARCHAR(100) = NULL
							--DECLARE @TaggedDate AS DATE = NULL
							DECLARE @Date AS INT = NULL
							DECLARE @SDate AS DATE = NULL
							DECLARE @EDate AS DATE = NULL
							DECLARE @ErrorMsg AS VARCHAR(100) = 'Transaction Failed'
							DECLARE @MaxDocEntry AS BIGINT = NULL
							DECLARE @PrevSlpCode AS VARCHAR(10) = NULL

							SET @Date = (SELECT DAY(@TaggedDate))

							--Get the startdate and endate of salesrep tagged in doctor
							IF @Date <= 15
								BEGIN
										SET @SDate = (SELECT DATEADD(m, DATEDIFF(m, 0, @TaggedDate), 0))
										SET @EDate = (SELECT DATEADD(DAY,-1,DATEADD(m, DATEDIFF(m, 0, @TaggedDate), 0)))
								END
							ELSE IF @Date >= 16
								BEGIN
										SET @SDate = (SELECT DATEADD(m, DATEDIFF(m, -1, CURRENT_TIMESTAMP), 0))
										SET @EDate = (SELECT DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,@TaggedDate)+1,0)))
								END


							--Get the previous sales rep
							SET @PrevSlpCode = (SELECT		SlpCode
												FROM		dbo.BPSlp 
												WHERE		SType = 102
															AND BPCode = @DCode
															AND EDate = '2099-12-31')

							
							IF NOT EXISTS	(SELECT		BPCode
												FROM		dbo.BPSlp 
												WHERE		SType = 102
														AND BPCode = @DCode
														AND SlpCode = @SlpCode
														AND EDate = '2099-12-31')
										BEGIN
											BEGIN TRY
												BEGIN TRAN
															UPDATE dbo.BPSlp SET EDate = @EDate WHERE SType = '102' AND BPCode = @DCode AND EDate = '2099-12-31'
			
															INSERT INTO dbo.BPSlp
																(SType, BPCode, SlpCode, EncodeDate, SDate, EDate, BPName)
															VALUES
																(102, @DCode, @SlpCode, GETDATE(), @SDate, '2099-12-31', @DName)

															UPDATE dbo.odrs SET	SlpCode = @SlpCode WHERE DCode = @DCode
															
															UPDATE dbo.RB_Payees SET SlpCode = @SlpCode WHERE PID = @DCode

															SET @MaxDocEntry = (SELECT ISNULL(MAX(Docentry),0) + 1 FROM dbo.SlpUpdLogs)
															INSERT INTO dbo.SlpUpdLogs
																(Docentry, Cardcode, [From], [To], Recom, ModifyDate, Remarks, EffDate, UpdatedBy, tbl)
															VALUES
																(@MaxDocEntry, @DCode, @PrevSlpCode, @SlpCode, '', GETDATE(), @SlpCode, GETDATE(), '', 'ODRS')
															SELECT 'Done.'
												COMMIT TRAN
											END TRY
											BEGIN CATCH
												ROLLBACK TRAN
												RAISERROR(@ErrorMsg, 1 , 1)
											END CATCH
										END
							ELSE
								BEGIN
										SELECT 'Invalid Transaction'
								END
			END

		ELSE IF @Mode = 'LoadPayeeType'
			BEGIN
							SELECT DISTINCT 
										UPPER(T1.PayDesc) [CODE] ,
										UPPER(T1.PayDesc) [DESC] 
							FROM		dbo.rbPayType T1 WITH(NOLOCK)
							ORDER BY	[DESC]            
			END

		ELSE IF @Mode = 'LoadPeriodType'
			BEGIN
							SELECT		Pname [CODE],
										Pname [DESC]
							FROM		dbo.RB_period WITH(NOLOCK)
			END

		ELSE IF @Mode = 'LoadSalesRep'
			BEGIN
							SELECT		SlpCode [Code], 
										SlpName [Desc]
							FROM		HPDI..OSLP WITH(NOLOCK)
							ORDER BY	SlpCode
			END

		ELSE IF @Mode = 'LoadClassType'
			BEGIN
							SELECT		[Desc] [Code],
										[Desc] 
							FROM		dbo.RAC_MaintenanceCode 
							WHERE		Module = 'PayeeSetup' 
										AND [Type] = 'Class Type'
			END

		ELSE IF @Mode = 'GetDoctorsPayee'
			BEGIN
							--Get doctors payee
							IF NOT OBJECT_ID('tempDB..#tmpPayee') IS NULL DROP TABLE #tmpPayee
							SELECT		Code, U_PayCode, U_PayName, UPPER(U_Class) U_Class
							INTO		#tmpPayee
							FROM		dbo.OACS1 
							WHERE		Code = @DCode
							GROUP BY	Code, U_PayCode, U_PayName, UPPER(U_Class)


							--Final Query
							SELECT		T1.Code, T2.PID, T2.PName, T1.U_Class, 
										T2.AcctNum, T2.TelNo, T2.Hosp, T2.Add1, 
										T3.SlpName, T2.Actype, T2.Periodtype, T3.SlpCode
							FROM		#tmpPayee T1
										LEFT JOIN dbo.RB_Payees T2 ON T1.U_PayCode = T2.PID
										LEFT JOIN dbo.OSLP T3 ON T2.SlpCode = T3.SlpCode
			END

		ELSE IF @Mode = 'GetPayeeDetails'
			BEGIN
							SELECT		U_PayCode, U_PayName, U_Branch + ' - ' + U_BName [Branch],
										UPPER(U_Class) [Class], U_Share, U_Branch
							FROM		OACS1 
							WHERE		U_PayCode = @PCode
			END

		ELSE IF @Mode = 'LoadBranch'
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

		ELSE IF @Mode = 'CreateNewPayee'
			BEGIN
							DECLARE @Cntr INT = NULL
							DECLARE @Cnt INT = 0

							IF @Branch = 'All'
								BEGIN
									IF NOT EXISTS(SELECT * FROM dbo.RB_Payees WHERE PID = @PID)
										BEGIN
													INSERT INTO dbo.RB_Payees
															(PID, PName, Class, AcctNum, Add1, SlpCode, Hosp, TelNo, Actype, Periodtype)
													VALUES
															(@PID, @PName, @Class, @AcctNo, @Address, @SlpCode, @Hosp, @Phone, @PayeeType, @PeriodType)
													SET @Cntr = @@ROWCOUNT

									IF @Cntr > 0
										BEGIN 
												BEGIN TRY
														BEGIN TRAN
															DECLARE @Ctr INT = 0
															DECLARE @Whs VARCHAR(10) 
															DECLARE @WhsName VARCHAR(100)

															DECLARE cur CURSOR LOCAL FOR
																SELECT Code, Blk FROM dbo.SAPSet WHERE Stat = 'O'
															OPEN cur

															FETCH NEXT FROM cur INTO @Whs, @WhsName
															WHILE @@FETCH_STATUS = 0
																BEGIN
																	IF NOT EXISTS(SELECT * FROM dbo.OACS1 WHERE U_PayCode = @PID AND U_Branch = @Whs)
																		BEGIN
																				--Add new payee sharing
																				INSERT INTO dbo.OACS1
																					(Code, LineId, Object, LogInst, U_PayCode, U_PayName, U_Branch, U_BName, U_Class, U_AcntNo, U_Share)
																				VALUES
																					(
																						@PCode, 
																						(SELECT dbo.fn_GetMaxID('GetMaxLineId', @PID)), 
																						'FTOACS', 
																						NULL, 
																						@PID, 
																						@PName, 
																						@Whs, 
																						@WhsName, 
																						@Class, 
																						@AcctNo, 
																						@Share
																					)

																				--Update sharing rate
																				UPDATE dbo.OACS1 SET U_Share = U_Share - @Share WHERE Code = @PCode AND U_PayCode = @PCode AND U_Branch = @Whs
																				SET @Ctr = @Ctr + @@ROWCOUNT
																		END	

																FETCH NEXT FROM cur INTO @Whs, @WhsName
																END	
															CLOSE cur
															DEALLOCATE cur
														COMMIT TRAN
														SELECT 'Done'
												END TRY
												BEGIN CATCH
														ROLLBACK TRAN
														RAISERROR('Error in processing', 1, 1)
												END CATCH
		
										END
										END

									ELSE
										BEGIN
													SELECT 'This PayeeID is already existing.'
										END


								END
							ELSE
								BEGIN
									IF NOT EXISTS(SELECT * FROM dbo.RB_Payees WHERE PID = @PID)
										BEGIN
													INSERT INTO dbo.RB_Payees
															(PID, PName, Class, AcctNum, Add1, SlpCode, Hosp, TelNo, Actype, Periodtype)
													VALUES
															(@PID, @PName, @Class, @AcctNo, @Address, @SlpCode, @Hosp, @Phone, @PayeeType, @PeriodType)
													SET @Cntr = @@ROWCOUNT

													IF @Cntr > 0
														BEGIN
															IF NOT EXISTS(SELECT * FROM dbo.OACS1 WHERE U_PayCode = @PID AND U_Branch = @Branch)
																BEGIN
																		--Add new payee sharing
																		INSERT INTO dbo.OACS1
																			(Code, LineId, Object, LogInst, U_PayCode, U_PayName, U_Branch, U_BName, U_Class, U_AcntNo, U_Share)
																		VALUES
																			(
																				@PCode, 
																				(SELECT dbo.fn_GetMaxID('GetMaxLineId', @PID)), 
																				'FTOACS', 
																				NULL, 
																				@PID, 
																				@PName, 
																				@Branch, 
																				@BranchName, 
																				@Class, 
																				@AcctNo, 
																				@Share
																			)

																		--Update sharing rate
																		UPDATE dbo.OACS1 SET U_Share = U_Share - @Share WHERE Code = @PCode AND U_PayCode = @PCode AND U_Branch = @Branch
																		SET @Ctr = @Ctr + @@ROWCOUNT
																END	
														END
										END
									
									ELSE
										BEGIN
													SELECT 'This PayeeID is already existing.'
										END
								END
			END
			
		ELSE IF @Mode = 'AddNewPayeeRate'
			BEGIN
								IF @Branch = 'All'
									BEGIN
											DECLARE @Whs2 VARCHAR(10) 
											DECLARE @WhsName2 VARCHAR(100)
											DECLARE @ctr2 INT = 0

											DECLARE cur CURSOR LOCAL FOR
												SELECT Code, Blk FROM dbo.SAPSet WHERE SlsStat = 'O'
											OPEN cur
											FETCH NEXT FROM cur INTO @Whs2, @WhsName2
											WHILE @@FETCH_STATUS = 0
												BEGIN
													IF NOT EXISTS(SELECT * FROM dbo.OACS1 WHERE Code = @PCode AND U_PayCode = @PID AND U_Branch = @Whs2)
														BEGIN
																--Add new payee sharing
																INSERT INTO dbo.OACS1
																	(Code, LineId, Object, LogInst, U_PayCode, U_PayName, U_Branch, U_BName, U_Class, U_AcntNo, U_Share)
																SELECT	TOP 1 Code, dbo.fn_GetMaxID('GetMaxLineId', @PID), Object, 
																		LogInst, U_PayCode, U_PayName, @Whs2, @WhsName2, 
																		U_Class, U_AcntNo, @Share
																FROM	dbo.OACS1 
																WHERE	Code = @PCode 
																		AND U_PayCode = @PID 
																SET @ctr2 = @@ROWCOUNT

																IF @ctr2 > 0
																	BEGIN
																		--Update sharing rate
																		UPDATE	dbo.OACS1 
																		SET		U_Share = U_Share - @Share
																		WHERE	Code = @PCode
																				AND U_PayCode = @PCode 
																				AND U_Branch = @Whs2
																	END					
														END
													FETCH NEXT FROM cur INTO @Whs2, @WhsName2
												END
											CLOSE cur
											DEALLOCATE cur
											IF @ctr2 > 0 BEGIN SELECT 'Done.' END
									END
								ELSE 
									BEGIN
										IF NOT EXISTS(SELECT * FROM dbo.OACS1 WHERE Code = @PCode AND U_PayCode = @PID AND U_Branch = @Branch)
											BEGIN
													--Add new payee sharing
													INSERT INTO dbo.OACS1
														(Code, LineId, Object, LogInst, U_PayCode, U_PayName, U_Branch, U_BName, U_Class, U_AcntNo, U_Share)
													SELECT	TOP 1 Code, dbo.fn_GetMaxID('GetMaxLineId', @PID), Object, 
															LogInst, U_PayCode, U_PayName, @Branch, @BranchName, 
															U_Class, U_AcntNo, @Share
													FROM	dbo.OACS1 
													WHERE	Code = @PCode 
															AND U_PayCode = @PID 
													SET @ctr2 = @@ROWCOUNT

													IF @ctr2 > 0
														BEGIN
															--Update sharing rate
															UPDATE	dbo.OACS1 
															SET		U_Share = U_Share - @Share 
															WHERE	Code = @PCode 
																	AND U_PayCode = @PCode 
																	AND U_Branch = @Branch
															SELECT 'Done.'
														END
											END
										ELSE
											BEGIN
													SELECT 'This payeeID ' + @PID + ' with branch code' + @Branch + ' is already existing.'
											END

									END
			END

		ELSE IF @Mode = 'UpdateImportedPayee'
			BEGIN
								UPDATE	dbo.RB_Payees
								SET		PName = @PName,
										Class = @Class,
										AcctNum = @AcctNo,
										Add1 = @Address,
										SlpCode = @DCode,
										Hosp = @Hosp,
										Actype = @PayeeType,
										Periodtype = @PeriodType
								WHERE	PID = @Pid
								SELECT @@ROWCOUNT
			END
	END
GO
