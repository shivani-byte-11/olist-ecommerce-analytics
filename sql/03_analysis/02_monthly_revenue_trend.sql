-- Monthly revenue trend with month-over-month growth (values in Brazilian reais).
-- Analysis window: 2017-01 to 2018-08. 2016 months (1 to 290 orders) and 2018-09 (1 order)
-- are excluded because their tiny base makes growth percentages meaningless.
-- Findings:
--   Peak: 2017-11, 7,421 orders and 1,003,862 revenue (+52.1% vs October).
--   Growth stalled in 2018: Mar to Aug stayed between about 840K and 990K.
--   Average order value stayed in a narrow band (about 125 to 150), so growth is volume-driven.
WITH monthly AS (
    SELECT order_month,
           COUNT(*) AS orders,
           SUM(items_revenue) AS revenue
    FROM vw_order_revenue
    WHERE order_month BETWEEN '2017-01' AND '2018-08'
    GROUP BY order_month
)
SELECT order_month,
       orders,
       ROUND(revenue, 2) AS revenue,
       ROUND(revenue / orders, 2) AS avg_order_value,
       ROUND(LAG(revenue) OVER (ORDER BY order_month), 2) AS previous_month_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY order_month))
             / LAG(revenue) OVER (ORDER BY order_month) * 100, 1) AS mom_growth_pct
FROM monthly
ORDER BY order_month;