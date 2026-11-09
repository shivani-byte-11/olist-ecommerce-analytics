USE olist_db;

-- 1. Total orders, expected: 99441
SELECT COUNT(*) AS total_orders
FROM orders;

-- 2. Duplicate order IDs.
-- Finding: 0, so each row is one order.
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids
FROM orders;

-- 3. Order status breakdown. Decides which statuses belong in revenue analysis.
-- Finding: about 97% delivered; canceled (625) and unavailable (609) never brought in revenue.
SELECT order_status,
       COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 4. Missing timestamps. NULL dates must be understood before computing delivery time.
-- Finding: approved 160, carrier 1783, delivered 2965.
SELECT SUM(order_approved_at IS NULL)             AS missing_approved,
       SUM(order_delivered_carrier_date IS NULL)  AS missing_carrier,
       SUM(order_delivered_customer_date IS NULL) AS missing_delivered
FROM orders;

-- 5. Does order_status agree with the delivery date?
-- Finding: 8 delivered orders have no delivery date, 6 canceled orders have one.
SELECT order_status,
       COUNT(*) AS total_orders,
       SUM(order_delivered_customer_date IS NULL)     AS missing_delivery_date,
       SUM(order_delivered_customer_date IS NOT NULL) AS has_delivery_date
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- 6. Inspect the 14 orders where status and delivery date disagree.
-- Decision: keep them in raw data; exclude canceled orders from revenue and
-- exclude orders without a delivery date from delivery-time analysis.
SELECT order_id,
       order_status,
       order_purchase_timestamp,
       order_delivered_carrier_date,
       order_delivered_customer_date,
       order_estimated_delivery_date
FROM orders
WHERE (order_status = 'delivered' AND order_delivered_customer_date IS NULL)
   OR (order_status = 'canceled'  AND order_delivered_customer_date IS NOT NULL)
ORDER BY order_status, order_purchase_timestamp;