-- =============================================
-- Author:		Ralph Salino
-- Create date: 2019-09-27
-- Description:	Rebates Maintenance
-- =============================================


ALTER PROCEDURE dbo.sp_RBMaintenance
    @Mode AS VARCHAR(50) = NULL,
	@WhsCode AS VARCHAR(10) = NULL,
	@SchemeCode AS BIGINT = NULL,
	@CriteriaCode AS BIGINT = NULL,
	@SchemeDesc AS VARCHAR(300) = NULL,
	@Cash AS NUMERIC(18,2) = NULL,
	@CreditCard AS NUMERIC(18,2) = NULL

AS
BEGIN
	IF @Mode = 'LoadRebScheme'
		BEGIN
							SELECT	T1.SchemeCode,
									T1.SchemeDesc,
									T1.WhsCode,
									T3.CriteriaDesc,
									T2.Cash,
									T2.CreditCard ,
									T3.CriteriaCode
							FROM	dbo.RAC_RebSchemeHdr T1 WITH(NOLOCK)
									INNER JOIN dbo.RAC_RebSchemeDtl T2 WITH(NOLOCK) ON T1.SchemeCode = T2.SchemeCode
									INNER JOIN dbo.RAC_RebSchemeCriteria T3 WITH(NOLOCK) ON T2.CriteriaCode = T3.CriteriaCode
							WHERE	T1.SchemeCode = @SchemeCode
									AND T1.Stat = 1
									AND T2.Stat = 1
									AND T3.Stat = 1
							ORDER BY
									T1.SchemeCode
		END
		
	ELSE IF @Mode = 'LoadRebSchemeType'
		BEGIN
							SELECT	SchemeCode,
									SchemeDesc,
									WhsCode 
							FROM	dbo.RAC_RebSchemeHdr WITH(NOLOCK)
							WHERE	Stat = 1
		END

	ELSE IF @Mode = 'HeaderInsert'
		BEGIN
							INSERT INTO dbo.RAC_RebSchemeHdr
								(SchemeDesc, WhsCode, Stat)
							VALUES
								(@SchemeDesc, @WhsCode, 1)
							SELECT SCOPE_IDENTITY()
		END

	ELSE IF @Mode = 'InsertCash'
		BEGIN
							INSERT INTO dbo.RAC_RebSchemeDtl
								(SchemeCode, CriteriaCode, Cash, Stat)
							VALUES
								(@SchemeCode, @CriteriaCode, @Cash, 1)
							SELECT @@ROWCOUNT
		END
		
	ELSE IF @Mode = 'HeaderUpdate'
		BEGIN
							UPDATE	dbo.RAC_RebSchemeHdr
							SET		SchemeDesc = @SchemeDesc
							WHERE	SchemeCode = @SchemeCode
							SELECT	@@ROWCOUNT
		END

	ELSE IF @Mode = 'CashUpdate'
		BEGIN
							UPDATE	dbo.RAC_RebSchemeDtl
							SET		Cash = @Cash
							WHERE	SchemeCode = @SchemeCode
									AND CriteriaCode = @CriteriaCode
							SELECT	@@ROWCOUNT	
		END

	ELSE IF @Mode = 'CreditCardUpdate'
		BEGIN
							UPDATE	dbo.RAC_RebSchemeDtl
							SET		CreditCard = @CreditCard
							WHERE	SchemeCode = @SchemeCode
									AND CriteriaCode = @CriteriaCode
							SELECT	@@ROWCOUNT
		END

	ELSE IF @Mode = 'LoadBranch'
		BEGIN
							SELECT	'000' [Code], '000 - Default Rate' [Whs], '000' [WhsCode]
							UNION
							SELECT	T1.Code,
									T1.Code + ' - ' + T1.Blk [Whs],
									T2.WhsCode
							FROM	dbo.SAPSet T1
									LEFT JOIN dbo.RAC_RebSchemeHdr T2 ON T1.Code = T2.WhsCode
							WHERE	T1.Stat = 'O'
		END

	ELSE IF @Mode = 'LoadSpecificBranch'
		BEGIN
							SELECT	'000' [Code], '000 - Default Rate' [Whs], '000' [WhsCode]
							UNION
							SELECT	T1.Code,
									T1.Code + ' - ' + T1.Blk [Whs],
									T2.WhsCode
							FROM	dbo.SAPSet T1
									LEFT JOIN dbo.RAC_RebSchemeHdr T2 ON T1.Code = T2.WhsCode
							WHERE	T1.Stat = 'O'
									AND T2.SchemeCode = @SchemeCode
		END

END    
GO
