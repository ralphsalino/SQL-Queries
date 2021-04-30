-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-12-11
-- Description:	Commission Salesperson Maintenance
-- =============================================

ALTER PROCEDURE dbo.sp_COMMSalesperson
    @Mode VARCHAR(100) = NULL,
	@SlpName VARCHAR(100) = NULL,
	@SlpCode VARCHAR(10) = NULL,
	@District VARCHAR(50) = NULL,
	@Position VARCHAR(50) = NULL,
	@Email VARCHAR(50) = NULL,
	@ComType VARCHAR(50) = NULL,
	@Atm VARCHAR(50) = NULL,
	@WhsCode VARCHAR(10) = NULL,
	@NoOfYrs INT = NULL,
	@SQualifier DECIMAL(18,2) = NULL,
	@CQualifier DECIMAL(18,2) = NULL,
	@CPerf DECIMAL(18,2) = NULL,
	@EmpID INT = NULL,
	@Year VARCHAR(10) = NULL,
	@Month INT = NULL,
	@Amt DECIMAL(18,2) = NULL


AS
	--DECLARE @LocMode VARCHAR(100) = @Mode,
	--		@LocSlpCode INT = @SlpCode,
	--		@LocYear INT = @Year

	BEGIN
		--Awit
		IF @Mode = 'LoadDDSalesTarget' SET @Mode = 'LoadSalesDropDown'
		IF @Mode = 'LoadSalesRep'
			BEGIN
				IF @SlpCode = 'ALL' SET @SlpCode = NULL
				SELECT	T2.SlpCode, T2.SlpName, ISNULL(T2.District, 'NOT SET') District,
						ISNULL(T2.Position, 'NOT SET') Position, ISNULL(T2.Email, 'NOT SET') Email,
						ISNULL(T2.Incentive, 0.00) Incentive, ISNULL(T2.ComType, '') ComType,
						ISNULL(T2.ATM, '') ATM, ISNULL(T2.WhsCode, '') WhsCode, ISNULL(T3.DateHired, '') DateStarted,
						ISNULL(DATEDIFF(YEAR, T3.DateHired, GETDATE()), 0) NoOfYrs, 
						ISNULL(T2.SalesQualifier, 0.00) SalesQualifier,
						ISNULL(T2.CallsQualifier, 0.00) CallsQualifier, ISNULL(T2.EmpID, '') EmpID
				FROM	HPDI..OSLP T1 WITH(NOLOCK)
						INNER JOIN OSLP T2 WITH(NOLOCK) ON T2.SlpCode = T1.SlpCode
						LEFT JOIN dbo.SCEmpNew T3 WITH(NOLOCK) ON T3.EmpCode = T2.EmpID
				WHERE	T2.SlpCode <> '-1'
						AND (@SlpCode IS NULL OR T2.SlpCode = @SlpCode)
			END

		ELSE IF @Mode = 'LoadSalesDropDown'
			BEGIN
				SELECT	'ALL' Code, 'ALL' [Desc]
				UNION ALL
				SELECT	CAST(T2.SlpCode AS VARCHAR(10)) Code, CAST(T2.SlpCode AS VARCHAR(10)) + ' - ' + T2.SlpName [Desc]
				FROM	HPDI..OSLP T1 WITH(NOLOCK)
						INNER JOIN OSLP T2 WITH(NOLOCK) ON T2.SlpCode = T1.SlpCode
				WHERE	T2.SlpCode <> '-1'
			END

		ELSE IF @Mode = 'LoadDistrict'
			BEGIN
				SELECT '' Code, '' [Desc]
				UNION ALL
				SELECT CAST(SDesc AS VARCHAR(100)) Code, SDesc [Desc] FROM dbo.SlpDist
			END

		ELSE IF @Mode = 'LoadPosition'
			BEGIN
				SELECT '' Code, '' [Desc]
				UNION ALL
				SELECT CAST(PDesc AS VARCHAR(100)) Code, PDesc [Desc] FROM dbo.SlpPos 
			END

		ELSE IF @Mode = 'LoadWhs'
			BEGIN
				SELECT '' Code, '' [Desc]
				UNION ALL
				SELECT Code, WhsName [Desc] FROM HPCOMMON..SAPSET WITH(NOLOCK) WHERE SLSStat = 'O'
			END

		ELSE IF @Mode = 'UpdateSalesRep'
			BEGIN
				UPDATE	dbo.OSLP
				SET		SlpName = @SlpName,
						District = @District,
						Position = @Position,
						Email = @Email,
						ComType = @ComType,
						ATM = @Atm,
						WhsCode = @WhsCode,
						NoOfYrs = @NoOfYrs,
						SalesQualifier = @SQualifier,
						CallsQualifier = @CQualifier,
						EmpID = @EmpID
				WHERE	SlpCode = @SlpCode
			END

		ELSE IF @Mode = 'AddSalesRep'
			BEGIN
				INSERT INTO dbo.OSLP
				        (SlpCode, SlpName, GroupCode, Locked, DataSource,
						ComType, ATM, WhsCode, District, Position, Email, NoOfYrs,
						SalesQualifier, EmpID, CallsQualifier)
				SELECT	T1.SlpCode, T1.SlpName, T1.GroupCode, T1.Locked, T1.DataSource,
						@ComType, @Atm, @WhsCode, @District, @Position, @Email, @NoOfYrs,
						@SQualifier, @EmpID, @CQualifier
				FROM	HPDI..OSLP	T1 WITH(NOLOCK)
						LEFT JOIN dbo.OSLP T2 WITH(NOLOCK) ON T2.SlpCode = T1.SlpCode
				WHERE	ISNULL(T2.SlpCode, '') = ''
						AND T1.SlpCode = @SlpCode
			END

		ELSE IF @Mode = 'LoadDDEmpList'
			BEGIN
				SELECT	CAST(0 AS VARCHAR(10)) Code, '' [Desc]
				UNION All		
				SELECT	T1.EmpCode Code, T1.EmpCode + ' - ' + UPPER(T1.EmpName) [Desc]
				FROM	dbo.SCEmpNew T1 
						LEFT JOIN dbo.OSLP T2 WITH(NOLOCK) ON T2.EmpID = T1.EmpCode
				WHERE	T1.DeptCode = 18
						AND ISNULL(T2.EmpID, '') = ''
			END
		ELSE IF @Mode = 'GetMaxSlpCode'
			BEGIN
				SELECT MAX(SlpCode) + 1 MaxSlpCode FROM HPDI..OSLP
			END

		ELSE IF @Mode = 'EmployeeList'
			BEGIN
				--SELECT	T1.EmpCode, UPPER(T1.EmpName) EmpName, T1.BranchCode,
				SELECT	T1.EmpCode, UPPER(T1.FName) + ' ' + UPPER(T1.MName) + ' ' + UPPER(T1.LName) EmpName, T1.BranchCode,
						ISNULL(T1.DateHired, '') DateStarted,
						CAST(ISNULL(DATEDIFF(YEAR, T1.DateHired, GETDATE()), 0) AS INT) NoOfYrs
				FROM	dbo.SCEmpNew T1 
						LEFT JOIN dbo.OSLP T2 WITH(NOLOCK) ON T2.EmpID = T1.EmpCode
				WHERE	T1.DeptCode = 18
						AND ISNULL(T2.EmpID, '') = ''
						AND	T1.EmpCode = @EmpID
			END

		ELSE IF @Mode = 'LoadSalesTarget'
			BEGIN
				--DECLARE @SlpCode INT = 1,
				--		@Year INT = 2020,
				--		@Month INT = NULL

				IF @Month = 0 SET @Month = NULL
				IF NOT OBJECT_ID('tempDB..#tmpCalendar') IS NULL DROP TABLE #tmpCalendar
				SELECT		Yr, Pd 
				INTO		#tmpCalendar
				FROM		dbo.Calendar 
				WHERE		(@Year IS NULL OR Yr = @Year)
				GROUP BY	Yr, Pd

				--
				IF NOT OBJECT_ID('tempDB..#tmpSalesTarget') IS NULL DROP TABLE #tmpSalesTarget
				SELECT		Slpcode, Yr, Pd, Amt 
				INTO		#tmpSalesTarget
				FROM		dbo.ComTargetdtl 
				WHERE		(@SlpCode IS NULL OR Slpcode = @SlpCode)
							AND (@Year IS NULL OR Yr = @Year)
							AND (@Month IS NULL OR Pd = @Month)

				--
				SELECT		T1.SlpCode, T1.SlpName, ISNULL(T1.District, 'NO DISTRICT') District, 
							T2.Yr, T2.Pd, ISNULL(T3.Amt, 0) Amt,
							CAST(CAST(T2.Pd AS VARCHAR(10)) + '/1/' + CAST(T2.Yr AS VARCHAR(10)) AS DATE) DateSet
				FROM		dbo.OSLP T1
							INNER JOIN #tmpCalendar T2 ON 1 = 1
							LEFT JOIN #tmpSalesTarget T3 ON T3.Slpcode = T1.SlpCode AND T3.Yr = T2.Yr AND T3.Pd = T2.Pd
				WHERE		(@SlpCode IS NULL OR T1.SlpCode = @SlpCode)
							AND (@Month IS NULL OR T2.Pd = @Month)
				ORDER BY	T1.SlpCode, T2.Yr, T2.Pd
			END

		ELSE IF @Mode = 'SaveSalesTarget'
			BEGIN

				IF EXISTS (SELECT Slpcode FROM dbo.ComTargetdtl WHERE Slpcode = @SlpCode AND Yr = @Year AND Pd = @Month)
					BEGIN
						UPDATE	dbo.ComTargetdtl
						SET		Amt = @Amt,
								UpdateDate = GETDATE()
						WHERE	Slpcode = @SlpCode
								AND Yr = @Year
								AND Pd = @Month
					END
				ELSE
					BEGIN
						INSERT INTO dbo.ComTargetdtl
						    (Slpcode, Yr, Pd,  Amt, Createdate)
						VALUES  
							(@SlpCode, @Year, @Month, @Amt, GETDATE())
					END

			END

		ELSE IF @Mode = 'LoadQualifiers'
			BEGIN
				IF @Month = 0 SET @Month = NULL

				IF NOT OBJECT_ID('tempDB..#tmpQCalendar') IS NULL DROP TABLE #tmpQCalendar
				SELECT		Yr, Pd 
				INTO		#tmpQCalendar
				FROM		dbo.Calendar
				GROUP BY	Yr, Pd

				--
				SELECT		T1.SlpCode,
							T1.SlpName,
							ISNULL(T3.SalesQualifier, 0) SalesQualifier,
							ISNULL(T3.CallsQualifier, 0) CallsQualifier,
							ISNULL(T3.CallsPerformance, 0) CallsPerformance,
							T2.Pd,
							T2.Yr 
				FROM		dbo.OSLP T1
							INNER JOIN #tmpQCalendar T2 ON 1 = 1
							LEFT JOIN dbo.RAC_CommQualifiers T3 ON T3.SlpCode = T1.SlpCode AND T3.Year = T2.Yr AND T3.Month = T2.Pd
				WHERE		T1.SlpCode = @SlpCode
							AND T2.Yr = @Year
							AND (@Month IS NULL OR T2.Pd = @Month)
				ORDER BY	T2.Yr DESC, 
							T2.Pd

				--
				DROP TABLE #tmpQCalendar
			END

		ELSE IF @Mode = 'SaveQualifiers'
			BEGIN
				IF EXISTS (SELECT * FROM dbo.RAC_CommQualifiers WHERE SlpCode = @SlpCode AND [Month] = @Month AND [Year] = @Year)
					BEGIN
						UPDATE	dbo.RAC_CommQualifiers
						SET		SalesQualifier = @SQualifier,
								CallsQualifier = @CQualifier,
								CallsPerformance = @CPerf,
								UpdatedBy = @EmpID,
								UpdatedDate = GETDATE()
						WHERE	SlpCode = @SlpCode
								AND [Month] = @Month
								AND [Year] = @Year
					END
				ELSE
					BEGIN
						INSERT INTO dbo.RAC_CommQualifiers
							(SlpCode, SalesQualifier, CallsQualifier, 
							 CallsPerformance, Month, Year, CreatedBy, CreatedDate)
						VALUES  
							(@SlpCode, @SQualifier, @CQualifier, @CPerf, @Month, @Year, @EmpID, GETDATE())
					END		
			END
	END    
GO
