-- Pareto check: how concentrated is revenue across product categories (Brazilian reais).
-- Excludes canceled and unavailable orders, same rule as vw_order_revenue.
-- Findings: 18 of 74 category labels (about 24%) bring in 80% of revenue; the top 10 bring in 62.4%.
-- Revenue is spread out: no single category is above 10%.
-- Data quality: items with no category ("unknown") are 1.3% of revenue and are kept visible, not hidden.
WITH category_revenue AS (
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable') GROUP BY category
),
ranked AS (
    SELECT category, revenue,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rnk,
           SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue,
           SUM(revenue) OVER () AS total_revenue
    FROM category_revenue
)
SELECT rnk,
       category,
       ROUND(revenue, 2) AS revenue,
       ROUND(running_revenue / total_revenue * 100, 1) AS cumulative_share_pct
FROM ranked ORDER BY rnk LIMIT 25;

-- Number of category labels with sales (including "unknown"). Result: 74
SELECT COUNT(DISTINCT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')) AS categories_with_sales
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable');