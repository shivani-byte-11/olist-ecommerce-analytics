-- Customer identity check and repeat purchase rate.
-- customer_id is created per order; customer_unique_id identifies the real person,
-- so all customer analysis uses customer_unique_id.

-- The trap: 99,441 customer_ids but only 96,096 real customers.
SELECT COUNT(*)                           AS customer_rows,
       COUNT(DISTINCT customer_id)        AS distinct_customer_ids,
       COUNT(DISTINCT customer_unique_id) AS distinct_real_customers
FROM customers;

-- Repeat purchase rate (valid orders only, via vw_order_revenue).
-- Findings: 94,983 customers; 2,887 repeat customers (3.04%), who bring 5.6% of revenue.
-- Roughly R$ 262 per repeat customer vs R$ 138 per one-time customer (rough estimate).
-- Retention is the weak spot: 97% of customers buy only once.
WITH customer_orders AS (
    SELECT c.customer_unique_id,
        COUNT(*)  AS orders,
        SUM(v.items_revenue) AS revenue
    FROM vw_order_revenue v
    JOIN customers c ON v.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS customers,
    SUM(orders = 1) AS one_time_customers,
    SUM(orders >= 2) AS repeat_customers,
    ROUND(SUM(orders >= 2) / COUNT(*) * 100, 2) AS repeat_rate_pct,
    ROUND(SUM(CASE WHEN orders >= 2 THEN revenue ELSE 0 END) / SUM(revenue) * 100, 1) AS repeat_revenue_share_pct,
    MAX(orders) AS max_orders
FROM customer_orders;