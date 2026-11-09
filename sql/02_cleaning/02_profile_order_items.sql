-- Profile the order_items table (price and freight are in Brazilian reais)
-- Duplicate rows, Finding: 0
SELECT COUNT(*) - COUNT(DISTINCT order_id, order_item_id) AS duplicate_rows
FROM order_items;

-- Items whose order is missing from the orders table. Finding: 0
SELECT COUNT(*) AS orphan_items
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Price and freight sanity check.
-- Finding: price 0.85 to 6735 (avg 120.65), no zero or negative prices,
-- freight 0.00 to 409.68, 383 items with free shipping.
SELECT MIN(price)             AS min_price,
       MAX(price)             AS max_price,
       ROUND(AVG(price), 2)   AS avg_price,
       SUM(price <= 0)        AS zero_or_negative_price,
       MIN(freight_value)     AS min_freight,
       MAX(freight_value)     AS max_freight,
       SUM(freight_value = 0) AS zero_freight_rows
FROM order_items;

-- Top 10 most expensive items and their categories.
-- Finding: all plausible (computers, appliances, instruments, consoles).
-- Decision: keep outliers; use median alongside average in revenue analysis.
SELECT oi.order_id,
       oi.price,
       oi.freight_value,
       p.product_category_name
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
ORDER BY oi.price DESC
LIMIT 10;