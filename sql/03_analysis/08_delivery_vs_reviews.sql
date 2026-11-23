-- Delivery performance vs customer review score.
-- Late = delivered after the estimated delivery date. Only delivered orders with a delivery
-- date and a review are included. Reviews are averaged per order first, so one order = one row.
-- Findings (95,824 orders):
--   On time or early: 89,443 orders, avg review 4.29, 9.2% low reviews (1-2 stars).
--   1-7 days late:     3,600 orders, avg review 2.72, 49.4% low reviews.
--   8+ days late:      2,781 orders, avg review 1.70, 79.2% low reviews.
-- Late orders are about 6.7% of the total. Late delivery is associated with much lower
-- scores; this does not prove it is the only cause.

-- Check: does an order have more than one review row?
-- Result: 99,224 review rows, 98,673 orders with reviews (547 orders have 2+ reviews).
-- That is why reviews are averaged per order below.
SELECT COUNT(*) AS review_rows,
       COUNT(DISTINCT order_id) AS orders_with_reviews
FROM order_reviews;

WITH review_per_order AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews GROUP BY order_id
),
delivered AS (
    SELECT v.order_id,
           DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS days_vs_estimate,
           r.review_score
    FROM vw_order_revenue v
    JOIN orders o ON v.order_id = o.order_id
    JOIN review_per_order r ON v.order_id = r.order_id
    WHERE v.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN days_vs_estimate <= 0 THEN '1 on time or early'
            WHEN days_vs_estimate <= 7 THEN '2 1-7 days late'
            ELSE '3 8+ days late'
       END AS delivery_bucket,
       COUNT(*) AS orders,
       ROUND(AVG(review_score), 2) AS avg_review,
       ROUND(SUM(review_score <= 2) / COUNT(*) * 100, 1) AS low_review_pct
FROM delivered GROUP BY delivery_bucket ORDER BY delivery_bucket;