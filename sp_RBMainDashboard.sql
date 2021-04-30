-- =============================================
-- Author:		Ralph Salino
-- Create date: 2020-02-12
-- Description:	Rebates Main Dashboard
-- =============================================

ALTER PROCEDURE dbo.sp_RBMainDashboard
    @Mode VARCHAR(100) = NULL,
	@Date DATE = NULL

AS
	BEGIN
		DECLARE @SDate DATE = NULL

			IF @Mode = 'LoadDashBoardHeader'
					BEGIN
									SET @SDate = (SELECT DATEADD(m, DATEDIFF(m, 0, @Date), 0))
									SELECT		T1.GenID,
												T1.StartDate,
												T1.EndDate,
												CAST(SUM(ISNULL(T2.Sales, '0.00')) AS DECIMAL(11,2)) TotalSales,
												CAST(SUM(ISNULL(T2.BudgetAmt, '0.00')) AS DECIMAL(11,2)) TotalBudget,
												CAST(SUM(ISNULL(T2.Rebates, '0.00')) AS DECIMAL(11,2)) TotalRebate,
												CAST(SUM(ISNULL(T2.BudgetAmt, '0.00')) - SUM(ISNULL(T2.Rebates, '0.00')) AS DECIMAL(11,2)) TotalExcess,
												CAST(SUM(ISNULL(T2.Rebates, '0.00')) / SUM(ISNULL(T2.Sales, '0.00')) * 100 AS DECIMAL(11,2)) TotalPrcntToSales
									FROM		dbo.RAC_RebBudgetHdr T1 WITH(NOLOCK)
												INNER JOIN dbo.RAC_RebBudgetDtl T2 WITH(NOLOCK) ON T1.GenID = T2.GenID
									WHERE		T1.StartDate = @SDate
									GROUP BY	T1.GenID,
												T1.StartDate,
												T1.EndDate
					END
	END    
GO
