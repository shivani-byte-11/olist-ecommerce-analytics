-- State-level view of revenue and late delivery (customer_state = where the order was delivered).
-- Findings:
--   Revenue: SP is 38.3% of product revenue (R$ 5.07M); SP + RJ + MG are 63.3%.
--   Late delivery: 6.8% of delivered orders arrive after the estimate (6,534 of 96,470).
--   RJ has 12.1% late (1,495 of 12,350) and BA has 12.2% (396 of 3,256), about 1.8x the average.
--   RJ has 12.8% of orders but 22.9% of all late orders. RJ + BA are about 29% of late orders.
--   SP has the most late orders (1,820) but only 4.5% late, below the average.
-- Caveats: correlation only, no cause. Order counts differ slightly between query 1 and the
-- delivery queries because the delivery queries need a delivery date.

-- 1. Revenue by state (top 10)
SELECT c.customer_state AS state,
       COUNT(DISTINCT v.order_id) AS orders,
       ROUND(SUM(v.items_revenue), 0) AS revenue,
       ROUND(100 * SUM(v.items_revenue) / SUM(SUM(v.items_revenue)) OVER (), 1) AS share_pct
FROM vw_order_revenue v
JOIN customers c ON v.customer_id = c.customer_id
WHERE v.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- 2. Baseline late share, all delivered orders
SELECT COUNT(*) AS orders,
       SUM(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0) AS late_orders,
       ROUND(100 * AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0), 1) AS late_pct
FROM orders o
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL;

-- 3. Late share and delivery time by state (states with 500+ orders)
SELECT c.customer_state AS state,
       COUNT(*) AS orders,
       ROUND(100 * AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0), 1) AS late_pct,
       ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 500
ORDER BY late_pct DESC
LIMIT 10;

-- 4. Number of late orders by state
SELECT c.customer_state AS state,
       COUNT(*) AS orders,
       SUM(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0) AS late_orders,
       ROUND(100 * AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0), 1) AS late_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_orders DESC
LIMIT 10;