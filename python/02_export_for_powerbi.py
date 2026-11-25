"""Export small result tables from MySQL (olist_db) to CSV files for the Power BI dashboard.

Every query reads from vw_order_revenue or the raw tables and uses the same rules as the SQL
files in sql/03_analysis (canceled and unavailable orders excluded). CSVs are written to
data/powerbi/, which is ignored by Git. The password is asked at run time, never stored.
"""
import getpass
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

QUERIES = {
    "kpi": """
        SELECT COUNT(*)                      AS orders,
               ROUND(SUM(items_revenue), 2)  AS product_revenue,
               ROUND(SUM(freight_total), 2)  AS freight_revenue,
               ROUND(SUM(items_revenue) / COUNT(*), 2) AS avg_order_value
        FROM vw_order_revenue
    """,
    "monthly_revenue": """
        WITH monthly AS (
            SELECT order_month,
                   COUNT(*)           AS orders,
                   SUM(items_revenue) AS revenue
            FROM vw_order_revenue
            WHERE order_month BETWEEN '2017-01' AND '2018-08'
            GROUP BY order_month
        )
        SELECT order_month,
               CONCAT(order_month, '-01')  AS month_start,
               orders,
               ROUND(revenue, 2)           AS revenue,
               ROUND(revenue / orders, 2)  AS avg_order_value,
               ROUND((revenue - LAG(revenue) OVER (ORDER BY order_month))
                     / LAG(revenue) OVER (ORDER BY order_month) * 100, 1)     AS mom_growth_pct,
               ROUND((revenue - LAG(revenue, 12) OVER (ORDER BY order_month))
                     / LAG(revenue, 12) OVER (ORDER BY order_month) * 100, 1) AS yoy_growth_pct
        FROM monthly
        ORDER BY order_month
    """,
    "categories": """
        WITH category_revenue AS (
            SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
                   COUNT(DISTINCT oi.order_id) AS orders,
                   SUM(oi.price)               AS revenue
            FROM order_items oi
            JOIN orders o ON oi.order_id = o.order_id
            LEFT JOIN products p ON oi.product_id = p.product_id
            LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
            WHERE o.order_status NOT IN ('canceled', 'unavailable')
            GROUP BY category
        ),
        ranked AS (
            SELECT category, orders, revenue,
                   ROW_NUMBER() OVER (ORDER BY revenue DESC) AS revenue_rank,
                   SUM(revenue) OVER (ORDER BY revenue DESC
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue,
                   SUM(revenue) OVER () AS total_revenue
            FROM category_revenue
        )
        SELECT revenue_rank,
               category,
               orders,
               ROUND(revenue, 2)                          AS revenue,
               ROUND(revenue / total_revenue * 100, 2)    AS revenue_share_pct,
               ROUND(running_revenue / total_revenue * 100, 1) AS cumulative_share_pct
        FROM ranked
        ORDER BY revenue_rank
    """,
    "customer_segments": """
        WITH customer_orders AS (
            SELECT c.customer_unique_id,
                   MAX(v.order_purchase_timestamp) AS last_order,
                   COUNT(*)                        AS frequency,
                   SUM(v.items_revenue)            AS monetary
            FROM vw_order_revenue v
            JOIN customers c ON v.customer_id = c.customer_id
            WHERE v.order_purchase_timestamp < '2018-09-01'
            GROUP BY c.customer_unique_id
        ),
        scored AS (
            SELECT customer_unique_id, frequency, monetary,
                   NTILE(4) OVER (ORDER BY last_order) AS r_score,
                   NTILE(4) OVER (ORDER BY monetary)   AS m_score
            FROM customer_orders
        ),
        segmented AS (
            SELECT *,
                   CASE
                       WHEN frequency >= 2 AND r_score >= 3 THEN '1 Repeat - active'
                       WHEN frequency >= 2                  THEN '2 Repeat - lapsing'
                       WHEN r_score >= 3 AND m_score >= 3   THEN '3 Recent high spenders'
                       WHEN r_score >= 3                    THEN '4 Recent low spenders'
                       WHEN m_score >= 3                    THEN '5 Lapsed high spenders'
                       ELSE                                      '6 Lapsed low spenders'
                   END AS segment
            FROM scored
        )
        SELECT segment,
               COUNT(*)                                                     AS customers,
               ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1)             AS customer_share_pct,
               ROUND(SUM(monetary), 2)                                      AS revenue,
               ROUND(SUM(monetary) / SUM(SUM(monetary)) OVER () * 100, 1)   AS revenue_share_pct,
               ROUND(AVG(monetary), 2)                                      AS avg_spend
        FROM segmented
        GROUP BY segment
        ORDER BY segment
    """,
    "repeat_split": """
        WITH customer_orders AS (
            SELECT c.customer_unique_id,
                   COUNT(*)             AS orders,
                   SUM(v.items_revenue) AS revenue
            FROM vw_order_revenue v
            JOIN customers c ON v.customer_id = c.customer_id
            GROUP BY c.customer_unique_id
        )
        SELECT CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
               COUNT(*)                AS customers,
               ROUND(SUM(revenue), 2)  AS revenue
        FROM customer_orders
        GROUP BY customer_type
        ORDER BY customer_type
    """,
    "delivery_vs_reviews": """
        WITH review_per_order AS (
            SELECT order_id, AVG(review_score) AS review_score
            FROM order_reviews
            GROUP BY order_id
        ),
        delivered AS (
            SELECT v.order_id,
                   DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS days_vs_estimate,
                   r.review_score
            FROM vw_order_revenue v
            JOIN orders o ON v.order_id = o.order_id
            JOIN review_per_order r ON v.order_id = r.order_id
            WHERE v.order_status = 'delivered'
              AND o.order_delivered_customer_date IS NOT NULL
        )
        SELECT CASE WHEN days_vs_estimate <= 0 THEN '1 On time or early'
                    WHEN days_vs_estimate <= 7 THEN '2 1-7 days late'
                    ELSE                            '3 8+ days late'
               END                                               AS delivery_bucket,
               COUNT(*)                                          AS orders,
               ROUND(AVG(review_score), 2)                       AS avg_review,
               ROUND(SUM(review_score <= 2) / COUNT(*) * 100, 1) AS low_review_pct
        FROM delivered
        GROUP BY delivery_bucket
        ORDER BY delivery_bucket
    """,
    "state_delivery": """
        SELECT c.customer_state AS state,
               COUNT(*)         AS orders,
               SUM(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0) AS late_orders,
               ROUND(100 * AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0), 1) AS late_pct
        FROM orders o
        JOIN customers c ON o.customer_id = c.customer_id
        WHERE o.order_status = 'delivered'
          AND o.order_delivered_customer_date IS NOT NULL
        GROUP BY c.customer_state
        HAVING COUNT(*) >= 500
        ORDER BY late_pct DESC
    """,
}


def main():
    url = URL.create(
        "mysql+pymysql",
        username="root",
        password=getpass.getpass("MySQL root password: "),
        host="localhost",
        port=3306,
        database="olist_db",
    )
    engine = create_engine(url)
    out_dir = Path(__file__).resolve().parent.parent / "data" / "powerbi"
    out_dir.mkdir(parents=True, exist_ok=True)

    with engine.connect() as conn:
        for name, query in QUERIES.items():
            df = pd.read_sql(text(query), conn)
            df.to_csv(out_dir / f"{name}.csv", index=False)
            print(f"{name}: {len(df)} rows -> data/powerbi/{name}.csv")


if __name__ == "__main__":
    main()
