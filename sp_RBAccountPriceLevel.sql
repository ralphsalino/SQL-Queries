-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-02-14
-- Description:	Rebates Main Dashboard
-- =============================================

ALTER PROCEDURE dbo.sp_RBAccountPriceLevel
    @Mode VARCHAR(100) = NULL,
	@Date DATE = NULL,
	@CardCode VARCHAR(20) = NULL,
	@CardName VARCHAR(50) = NULL,
	@ExpiryDate DATE = NULL,
	@IsTagged INT = NULL

AS
    BEGIN
			IF @Mode = 'LoadAccountPriceLevel'
					BEGIN
									--DECLARE @Date DATE  = '2018-01-01'
									--DECLARE @CardCode VARCHAR(20) = NULL
									--DECLARE @CardName VARCHAR(50) = NULL
									--DECLARE @IsTagged INT = NULL

									--Get the pricelevel of accounts
									IF NOT OBJECT_ID('tempDB..#tmpCustMasterOrcl') IS NULL DROP TABLE #tmpCustMasterOrcl
									SELECT		DBCODE, MAX(FOLDER_ID) FOLDER_ID
									INTO		#tmpCustMasterOrcl
									FROM		dbo.CUST_MASTER_ORCL 
									GROUP BY	DBCODE


									--Get the active accounts base of transaction
									IF NOT OBJECT_ID('tempDB..#tmpOINV') IS NULL DROP TABLE #tmpOINV
									SELECT		DISTINCT CardCode 
									INTO		#tmpOINV
									FROM		HPDI..OINV
									WHERE		CAST(docdate AS DATE) > @Date
									
									
									--Final query
									SELECT		T1.CardCode, T1.U_CardName, T3.DBCODE, T1.RebRates, 
												ISNULL(T3.FOLDER_ID, '') [FOLDER_ID], 
												CASE WHEN ISNULL(T1.RbPrcLvl, 0) = 0 THEN 'NOT TAG' ELSE 'TAGGED' END [RbPrcLvl],
												CASE WHEN ISNULL(T1.RbExpDt, '') = '' THEN '' ELSE T1.RbExpDt END [ExpiryDate],
												CASE WHEN ISNULL(T1.RbDateTagged, '') = '' THEN '' ELSE T1.RbDateTagged END [RbDateTagged]
									FROM		dbo.OCRD T1
												INNER JOIN HPDI..OCRD T2 ON T1.CardCode = T2.CardCode
												INNER JOIN #tmpCustMasterOrcl T3 ON T1.CardCode = T3.DBCODE
												INNER JOIN #tmpOINV T4 ON T1.CardCode = T4.CardCode
									WHERE		ISNULL(T1.RebRates, 0) <> 0 
												AND T1.isActive = 1
												AND ISNULL(T1.RbPrcLvl, 0) = @IsTagged
												AND (@CardCode IS NULL OR T1.CardCode LIKE '%' + @CardCode + '%')
												AND (@CardName IS NULL OR T1.U_CardName LIKE '%' + @CardName + '%')
												AND T1.U_CardName NOT LIKE '%TESTING%'
					END

			ELSE IF @Mode = 'IncludeAccounts'
					BEGIN
									UPDATE		dbo.OCRD 
									SET			RbPrcLvl = 1,
												RbExpDt = @ExpiryDate,
												RbDateTagged = GETDATE()
									WHERE		CardCode = @CardCode
					END

			ELSE IF @Mode = 'ExcludeAccounts'
					BEGIN
									UPDATE		dbo.OCRD 
									SET			RbPrcLvl = 0,
												RbExpDt = GETDATE(),
												RbDateTagged = GETDATE()
									WHERE		CardCode = @CardCode
					END
	END
GO
