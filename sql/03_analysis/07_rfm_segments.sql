-- RFM-style customer segmentation (Brazilian reais).
-- Window: orders before 2018-09-01 (the last months of the data are incomplete).
-- Frequency is split into 1 order vs 2+ because 97% of customers bought once.
-- Recency and spend use NTILE(4), so "recent" = newer half and "high" = upper half by spend.
-- Findings:
--   High spenders (segments 3 and 5): 47.5% of customers, 78% of revenue (avg spend about R$ 233).
--   Low spenders (segments 4 and 6): 49.5% of customers, 16.4% of revenue (avg spend about R$ 47).
--   Repeat customers: 3.1% of customers, 5.6% of revenue (avg spend about R$ 260).
--   Biggest win-back target: 22,436 older-purchase high spenders holding 39% of revenue.
-- Caveat: NTILE forces near-equal groups, so the sizes of the four one-time segments are a
-- result of the method, not a finding. "Lost" means an older last purchase, not proven churn.
WITH customer_orders AS (
    SELECT c.customer_unique_id,
        MAX(v.order_purchase_timestamp) AS last_order,
        COUNT(*) AS frequency,
        SUM(v.items_revenue) AS monetary
    FROM vw_order_revenue v
    JOIN customers c ON v.customer_id = c.customer_id
    WHERE v.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT customer_unique_id,  frequency, monetary,
        NTILE(4) OVER (ORDER BY last_order) AS r_score,
        NTILE(4) OVER (ORDER BY monetary)   AS m_score
    FROM customer_orders
),
segmented AS (
    SELECT *,
           CASE
               WHEN frequency >= 2 AND r_score >= 3 THEN '1 Repeat - active'
               WHEN frequency >= 2 THEN '2 Repeat - lapsing'
               WHEN r_score >= 3 AND m_score >= 3 THEN '3 Recent high spenders'
               WHEN r_score >= 3 THEN '4 Recent low spenders'
               WHEN m_score >= 3 THEN '5 Lost high spenders'
               ELSE '6 Lost low spenders'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*) AS customers,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS customer_share_pct,
       ROUND(SUM(monetary), 2) AS revenue,
       ROUND(SUM(monetary) / SUM(SUM(monetary)) OVER () * 100, 1) AS revenue_share_pct,
       ROUND(AVG(monetary), 2) AS avg_spend
FROM segmented GROUP BY segment ORDER BY segment;