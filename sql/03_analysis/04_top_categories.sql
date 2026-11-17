-- Top 10 product categories by revenue (values in Brazilian reais).
-- Excludes canceled and unavailable orders, same rule as vw_order_revenue.
-- Reconciliation: item rows and total revenue match the view (112,101 items, 13,494,400.74).
-- Findings: health_beauty leads with 9.3% of revenue, then watches_gifts (8.9%) and bed_bath_table (7.7%).
-- The top 10 categories together bring in about 62% of revenue, and no single category exceeds 10%.
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(SUM(oi.price) / SUM(SUM(oi.price)) OVER () * 100, 1) AS revenue_share_pct
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;