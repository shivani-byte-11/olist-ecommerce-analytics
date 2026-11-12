-- Order-level revenue view used by all analysis queries (values in Brazilian reais).
-- Rules: one row per order; canceled and unavailable orders excluded;
-- orders without items excluded; items aggregated before joining to avoid double counting.
-- Check: 98,199 orders, product revenue 13,494,400.74, freight 2,241,126.29.
CREATE OR REPLACE VIEW vw_order_revenue AS
SELECT o.order_id,
       o.customer_id,
       o.order_status,
       o.order_purchase_timestamp,
       DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
       i.items_revenue,
       i.freight_total,
       i.item_count,
       DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days
FROM orders o
JOIN (
    SELECT order_id,
           SUM(price)         AS items_revenue,
           SUM(freight_value) AS freight_total,
           COUNT(*)           AS item_count
    FROM order_items
    GROUP BY order_id
) i ON o.order_id = i.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable');