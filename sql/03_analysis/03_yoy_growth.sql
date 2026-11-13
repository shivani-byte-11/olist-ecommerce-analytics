-- Year-over-year revenue growth (values in Brazilian reais).
-- Window: 2017-01 to 2018-08 (20 consecutive months, so LAG(..., 12) is the same month last year).
-- 2017 months have no prior-year data in this window, so their YoY is NULL.
-- Findings: YoY growth fell from +687% (Jan 2018) to +49% (Aug 2018).
-- Part of this is a small-base effect (Jan 2017 had only 787 orders); revenue level
-- stayed roughly flat in 2018 (about 840K to 990K per month).
WITH monthly AS (
    SELECT order_month,
           COUNT(*)           AS orders,
           SUM(items_revenue) AS revenue
    FROM vw_order_revenue
    WHERE order_month BETWEEN '2017-01' AND '2018-08'
    GROUP BY order_month
)
SELECT order_month,
       orders,
       ROUND(revenue, 2)                                      AS revenue,
       ROUND(LAG(revenue, 12) OVER (ORDER BY order_month), 2) AS same_month_last_year,
       ROUND((revenue - LAG(revenue, 12) OVER (ORDER BY order_month))
             / LAG(revenue, 12) OVER (ORDER BY order_month) * 100, 1) AS yoy_growth_pct
FROM monthly
ORDER BY order_month;