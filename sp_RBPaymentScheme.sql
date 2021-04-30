-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-11-05
-- Description:	Rebates Payment Scheme
-- =============================================

ALTER PROCEDURE dbo.sp_RBPaymentScheme
    @Mode VARCHAR(100) = NULL,
	@PayeeTypName VARCHAR(100) = NULL,
	@LineNum INT = NULL,
	@PayeeTypeCode INT = NULL,
	@Whs VARCHAR(30) = NULL,
	@RangeFrom DECIMAL(18,2) = NULL,
	@RangeTo DECIMAL(18,2) = NULL,
	@Percnt DECIMAL(18,2) = NULL,
	@AmntExclusion DECIMAL(18,2) = NULL,
	@CreatedBy VARCHAR(20) = NULL

AS
    BEGIN
		IF @Mode = 'LoadPayeeType'
			BEGIN
				SELECT 'All' Code, 'All' [Desc] 
				UNION All
				SELECT [Desc] Code, [Desc] FROM dbo.RAC_MaintenanceCode WHERE Type = 'PayeeType'
			END

		ELSE IF @Mode = 'LoadPayeeTypeDets'
			BEGIN
				IF @PayeeTypName = 'All' BEGIN SET @PayeeTypName = NULL END
				SELECT	Code, [Desc] 
				FROM	dbo.RAC_MaintenanceCode 
				WHERE	Type = 'PayeeType' 
						AND RecID NOT IN (32, 30) 
						AND (@PayeeTypName IS NULL OR [Desc] = @PayeeTypName)
			END

		ELSE IF @Mode = 'LoadBranches'
			BEGIN
				SELECT 'All' Code, 'All' [Desc]
				UNION ALL
				SELECT Code, WhsName [Desc] FROM dbo.SAPSet WHERE Stat = 'O'
			END

		ELSE IF @Mode = 'LoadPayeeSchemeDets'
			BEGIN
				IF @Whs = 'All' SET @Whs = NULL
				SELECT	T1.LineNum,
						T1.PayeeType Code,
						T2.[Desc] Name,
						T1.Whs,
						T1.RangeFrom,
						T1.RangeTo,
						T1.Percnt,
						T1.AmntExclusion
				FROM	dbo.RAC_PayeeScheme T1
						LEFT JOIN dbo.RAC_MaintenanceCode T2 ON T1.PayeeType = T2.Code AND T2.Type = 'PayeeType'
				WHERE	T1.PayeeType = @PayeeTypeCode
						AND (@Whs IS NULL OR T1.Whs = @Whs)
			END

		ELSE IF @Mode = 'DeleteScheme'
			BEGIN
				IF @Whs = 'All' SET @Whs = NULL
				DELETE RAC_PayeeScheme WHERE PayeeType = @PayeeTypeCode AND (@Whs IS NULL OR Whs = @Whs)
			END

		ELSE IF @Mode = 'SaveScheme'
			BEGIN
				INSERT INTO dbo.RAC_PayeeScheme
					(LineNum, PayeeType, Whs, RangeFrom, RangeTo, Percnt, AmntExclusion, CreatedBy, CreatedDate)
				VALUES  
					(@LineNum, @PayeeTypeCode, @Whs, @RangeFrom, @RangeTo, @Percnt, @AmntExclusion, @CreatedBy, GETDATE())
			END
	END
GO
