-- Cross-check order_items against order_payments (values in Brazilian reais)
-- Rule: aggregate each table to one row per order first, then join, so rows do not multiply.

-- Do items total and paid total agree?
-- Finding: 98,665 orders have both items and payments; 98,362 match (99.7%), 303 do not.
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM order_items
    GROUP BY order_id
),
pay_totals AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM order_payments
    GROUP BY order_id
)
SELECT COUNT(*)                                        AS orders_compared,
       SUM(ABS(i.items_total - p.paid_total) <= 0.01)  AS matching,
       SUM(ABS(i.items_total - p.paid_total) > 0.01)   AS mismatching
FROM item_totals i
JOIN pay_totals p ON i.order_id = p.order_id;

-- Direction of the 303 mismatches.
-- Finding: 264 paid more (avg +11.63, likely installment interest), 39 paid less (avg -5.10, unexplained).
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM order_items
    GROUP BY order_id
),
pay_totals AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM order_payments
    GROUP BY order_id
)
SELECT CASE WHEN p.paid_total > i.items_total THEN 'paid more' ELSE 'paid less' END AS direction,
       COUNT(*)                                    AS orders,
       ROUND(AVG(p.paid_total - i.items_total), 2) AS avg_difference,
       ROUND(MIN(p.paid_total - i.items_total), 2) AS min_difference,
       ROUND(MAX(p.paid_total - i.items_total), 2) AS max_difference
FROM item_totals i
JOIN pay_totals p ON i.order_id = p.order_id
WHERE ABS(i.items_total - p.paid_total) > 0.01
GROUP BY direction;

-- Orders with no items. Finding: 775 (unavailable 603, canceled 164, created 5, invoiced 2, shipped 1).
-- No delivered order is missing items.
SELECT o.order_status,
       COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_items DESC;