-- =============================================
-- Author:		Ralph Salino
-- Create date: 2019-10-14
-- Description:	Rebates Test Maintenance
-- =============================================

ALTER PROCEDURE dbo.sp_RBTestMntnce
    @Mode AS VARCHAR(100) = NULL,
	@ItemDesc AS VARCHAR(350) = NULL,
	@Whs AS VARCHAR(10) = NULL,
	@Rate AS NUMERIC(18,2) = NULL,
	@Amnt AS NUMERIC(18,2) = NULL,
	@PkgItm AS VARCHAR(20) = NULL,
	@ImhCode AS VARCHAR(20) = NULL,
	@Search VARCHAR(250) = NULL,
	@SearchBy VARCHAR(20) = NULL,
	@GType INT = NULL,
	@IType VARCHAR(20) = NULL,
	@ItemCode VARCHAR(30) = NULL,
	@ItemName VARCHAR(300) = NULL,
	@CardCode VARCHAR(30) = NULL,
	@CardName VARCHAR(100) = NULL,
	@GrpCode VARCHAR(50) = NULL

	
AS
BEGIN
	
	IF @Whs = 'All' BEGIN SET @Whs = NULL END
	
	IF @Mode = 'LoadDefaultTest'
		BEGIN
						SELECT	TOP 500 T1.IMH_CODE,
								T1.IMH_DESC,
								T2.IMD_PKG_CODE,
								T2.IMD_PKG_ITEM,
								ISNULL(T3.RATE,'0.00') RATE,
								ISNULL(T3.AMNT, '0.00') AMNT,
								T1.WHSCODE
						FROM	dbo.ITEM_MASTERH T1
								LEFT JOIN dbo.ITEM_MASTERD T2 ON T1.IMH_CODE = T2.IMD_PKG_CODE AND T2.WHSCODE = T1.WHSCODE
								LEFT JOIN dbo.RAC_RebTestMntnce T3 ON T1.IMH_CODE = T3.IMH_CODE AND T1.WHSCODE = T3.WHSCODE
						ORDER BY
								T1.IMH_CODE DESC,
								T1.WHSCODE
		END

	ELSE IF @Mode = 'LoadTestDetails'
		BEGIN
						SELECT	T1.IMH_CODE,
								T1.IMH_DESC,
								T2.IMD_PKG_CODE,
								T2.IMD_PKG_ITEM,
								ISNULL(T3.RATE,'0.00') RATE,
								ISNULL(T3.AMNT, '0.00') AMNT,
								T1.WHSCODE
						FROM	dbo.ITEM_MASTERH T1
								LEFT JOIN dbo.ITEM_MASTERD T2 ON T1.IMH_CODE = T2.IMD_PKG_CODE AND T2.WHSCODE = T1.WHSCODE
								LEFT JOIN dbo.RAC_RebTestMntnce T3 ON T1.IMH_CODE = T3.IMH_CODE AND T1.WHSCODE = T3.WHSCODE
						WHERE	T1.IMH_DESC LIKE '%' + @ItemDesc + '%'
								AND (@Whs IS NULL OR T1.WHSCODE = @Whs)
								AND T2.IMD_PKG_CODE IS NULL
						ORDER BY
								T1.IMH_CODE DESC,
								T1.WHSCODE
		END

	ELSE IF @Mode = 'LoadPkgTestDetails'
		BEGIN
						SELECT	T1.IMH_CODE,
								T1.IMH_DESC,
								T2.IMD_PKG_CODE,
								T2.IMD_PKG_ITEM,
								ISNULL(T3.RATE,'0.00') RATE,
								ISNULL(T3.AMNT, '0.00') AMNT,
								T1.WHSCODE
						FROM	dbo.ITEM_MASTERH T1
								LEFT JOIN dbo.ITEM_MASTERD T2 ON T1.IMH_CODE = T2.IMD_PKG_CODE AND T2.WHSCODE = T1.WHSCODE
								LEFT JOIN dbo.RAC_RebTestMntnce T3 ON T1.IMH_CODE = T3.IMH_CODE AND T1.WHSCODE = T3.WHSCODE AND T2.IMD_PKG_ITEM = T3.IMD_PKG_ITEM
						WHERE	T1.IMH_DESC LIKE '%' + @ItemDesc + '%'
								AND (@Whs IS NULL OR T1.WHSCODE = @Whs)
								AND T2.IMD_PKG_CODE IS NOT NULL
						ORDER BY
								T1.IMH_CODE DESC,
								T1.WHSCODE
		END

	ELSE IF @Mode = 'LoadWhs'
		BEGIN
						SELECT 'All' [Code], 'All' [Desc], 1 [Seq]
						UNION
						SELECT	Code, Code + ' - ' + Blk [Desc], 2 [Seq]
						FROM	dbo.SAPSet
						WHERE	Stat = 'O'
						ORDER BY
								Seq
		END
	
	ELSE IF @Mode = 'AddUpdRateAmnt'
		BEGIN
						IF @PkgItm = '' BEGIN SET @PkgItm = NULL END
						IF EXISTS(SELECT IMH_CODE FROM dbo.RAC_RebTestMntnce WHERE IMH_CODE = @ImhCode AND WHSCODE = @Whs AND (@PkgItm IS NULL OR  IMD_PKG_ITEM  = @PkgItm))
							BEGIN
									UPDATE	dbo.RAC_RebTestMntnce 
									SET		RATE = @Rate,
											AMNT = @Amnt
									WHERE	IMH_CODE = @ImhCode
											AND WHSCODE = @Whs
											AND (@PkgItm IS NULL OR  IMD_PKG_ITEM  = @PkgItm)
									SELECT	@@ROWCOUNT
							END
						ELSE
							BEGIN
									INSERT INTO dbo.RAC_RebTestMntnce
										(IMH_CODE, IMD_PKG_ITEM, WHSCODE, RATE, AMNT, STAT)
									VALUES
										(@ImhCode, @PkgItm, @Whs, @Rate, @Amnt, 1)
									SELECT	@@ROWCOUNT
							END
		END

	ELSE IF @Mode = 'LoadSpecialInHouseTest'
		BEGIN
						--EXEC dbo.sp_RBTestMntnce @Mode = 'LoadSpecialInHouseTest',
						--                         @Search = NULL,   -- varchar(250)
						--                         @SearchBy = 'Account Code', -- varchar(20)
						--                         @GType = 0,     -- int
						--                         @IType = 'All'     -- varchar(20)
						
						IF @SearchBy = 'Item Code'
							BEGIN
								SET @ItemCode = @Search
							END
						ELSE IF @SearchBy = 'Item Name'
							BEGIN
								SET @ItemName = @Search
							END
						ELSE IF @SearchBy = 'Account Code'
							BEGIN
								SET @CardCode = @Search
							END
						ELSE IF @SearchBy = 'Account Name'
							BEGIN
								SET @CardName = @Search
							END
	
						IF @GType = 0 BEGIN SET @GType = NULL END
						IF @IType = 'All' BEGIN SET @IType = NULL END

						SELECT TOP 16 	T1.ItemCode, T1.ItemName, T1.GrpCode, CASE WHEN	T1.ItemType = 'S' THEN	'Single' ELSE 'Package' END ItemType, 
										T1.CardCode, ISNULL(T2.CardName, '') CardName
						FROM			dbo.SpclInhouse T1 WITH(NOLOCK)
										LEFT JOIN HPDI..OCRD T2 WITH(NOLOCK) ON T2.CardCode = T1.CardCode
						WHERE			(@ItemCode IS NULL OR T1.ItemCode = @ItemCode)
										AND (@ItemName IS NULL OR T1.ItemName LIKE '%' + @ItemName + '%')
										AND (@CardCode IS NULL OR T1.CardCode = @CardCode)
										AND (@CardName IS NULL OR T2.CardName LIKE '%' + @CardName + '%')
										AND (@GType IS NULL OR T1.GrpCode = @GType)
										AND (@IType IS NULL OR T1.ItemType = @IType)
						GROUP BY		T1.ItemCode, T1.ItemName, T1.GrpCode, T1.ItemType, T1.CardCode, ISNULL(T2.CardName, '')
		END

	ELSE IF @Mode = 'LoadSPTestDetails'
		BEGIN
						
						SELECT		T1.ItemCode, T1.ItemName, T1.WhsCode, T1.Rate, T1.Amt, T1.GrpCode, T1.ItemType, 
									T1.CardCode, ISNULL(T2.CardName, '') CardName
						FROM		dbo.SpclInhouse T1 WITH(NOLOCK)
									LEFT JOIN HPDI..OCRD T2 WITH(NOLOCK) ON T2.CardCode = T1.CardCode
						WHERE		T1.ItemCode = @ItemCode
									AND T1.ItemName = @ItemName
									--AND (@CardCode = '' OR T1.CardCode = @CardCode)
									AND ISNULL(T2.CardCode, '') = ISNULL(@CardCode,'')
									AND ISNULL(t1.ItemType, '') = ISNULL(@IType, '')
						ORDER BY	T1.ItemCode, T1.CardCode, T1.WhsCode
		END

	ELSE IF @Mode = 'LoadItems'
		BEGIN
						--EXEC dbo.sp_RBTestMntnce @Mode = 'LoadItems',
						--                         @Search = NULL,
						--                         @SearchBy = NULL,
						--                         @IType = 'All'
						DECLARE @Code VARCHAR(50) = NULL
						DECLARE @Desc VARCHAR(50) = NULL

						IF @SearchBy = 'Code'
							BEGIN
								SET @Code = @Search
								SET @Desc = NULL
							END
						ELSE IF @SearchBy = 'Name'
							BEGIN
								SET @Desc = @Search
								SET @Code = NULL
							END
						ELSE IF @SearchBy = 'All'
							BEGIN
								SET @Code = NULL
								SET @Desc = NULL
							END

						IF @IType = 'All' BEGIN SET @IType = NULL END

						SELECT	TOP 1000 T1.*
						FROM (
								--Single
								SELECT	ItemCode Code, 
										ItemName [Desc], 'S' [ItemType]
								FROM	HPDI..OITM 
								WHERE	InvntItem = 'N'

								UNION ALL

								--Package
								SELECT	IMH_CODE Code, 
										IMH_DESC [Desc], 'P' [ItemType]
								FROM	dbo.ITEM_MASTERH WITH(NOLOCK) 
								WHERE	IMH_TYPE = 'P' 
										AND ISNULL(IMH_DESC, '') <> '') T1
						WHERE	(@IType IS NULL OR T1.ItemType = @IType)
								AND	(@Code IS NULL OR T1.Code LIKE '%' + @Code + '%')
								AND	(@Desc IS NULL OR T1.[Desc] LIKE '%' + @Desc + '%')
		END

	ELSE IF @Mode = 'LoadCustomer'
		BEGIN
						IF @SearchBy = 'Code'
							BEGIN
								SET @Code = @Search
								SET @Desc = NULL
							END
						ELSE IF @SearchBy = 'Name'
							BEGIN
								SET @Desc = @Search
								SET @Code = NULL
							END
						ELSE IF @SearchBy = 'All'
							BEGIN
								SET @Code = NULL
								SET @Desc = NULL
							END

						IF @GrpCode = 'All' BEGIN SET @GrpCode = NULL END

						SELECT	TOP 1000 CardCode [Code], CardName [Desc]
						FROM	HPDI..OCRD WITH(NOLOCK)
						WHERE	CardType = 'C' 
								AND (@GrpCode IS NULL OR GroupCode = @GrpCode)
								AND (@Code IS NULL OR CardCode = @Code)
								AND	(@Desc IS NULL OR CardName LIKE '%' + @Desc + '%')
		END
		
	ELSE IF @Mode = 'GetAllActiveBranch'
		BEGIN
					SELECT Code, WhsName FROM dbo.SAPSet WHERE Stat = 'O' ORDER BY CAST(Code AS INT)
		END

	ELSE IF @Mode = 'CheckSpecialTest'
		BEGIN
					SELECT	ItemCode,
							ItemName,
							WhsCode,
							Rate,
							Amt,
							GrpCode,
							ItemType,
							CardCode 
					FROM	dbo.SpclInhouse 
					WHERE	ItemCode = @ItemCode
							AND ItemName = @ItemDesc
							AND CardCode = @CardCode
		END

	ELSE IF @Mode = 'AddSpecialInhouse'
		BEGIN
						INSERT INTO dbo.SpclInhouse
							(ItemCode, ItemName, WhsCode, Rate, Amt, GrpCode, ItemType, CardCode)
						VALUES
							(@ItemCode, @ItemName, @Whs, @Rate, @Amnt, @GrpCode, @IType, @CardCode)
		END

	ELSE IF @Mode = 'UpdateSpecialInhouse'
		BEGIN
						UPDATE	dbo.SpclInhouse
						SET		Rate = @Rate,
								Amt = @Amnt
						WHERE	ItemCode = @ItemCode
								AND ItemName = @ItemName
								AND WhsCode = @Whs
								AND GrpCode = @GrpCode
								AND	ItemType = @IType
								AND @CardCode IS NULL OR ISNULL(CardCode, '') = @CardCode
		END
END    
GO
