"""Delivery performance vs review score: hypothesis test and chart.

Reads delivered orders that have a review from MySQL (olist_db), compares the review
scores of on-time and late orders with a Mann-Whitney U test, and saves a chart to docs/.
The password is asked when the script runs and is never stored in the code.
"""
import getpass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from scipy.stats import mannwhitneyu
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

QUERY = """
WITH review_per_order AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT v.order_id,
       DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS days_vs_estimate,
       r.review_score
FROM vw_order_revenue v
JOIN orders o ON v.order_id = o.order_id
JOIN review_per_order r ON v.order_id = r.order_id
WHERE v.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
"""

LABELS = ["On time or early", "1-7 days late", "8+ days late"]


def load_data():
    url = URL.create(
        "mysql+pymysql",
        username="root",
        password=getpass.getpass("MySQL root password: "),
        host="localhost",
        port=3306,
        database="olist_db",
    )
    engine = create_engine(url)
    with engine.connect() as conn:
        return pd.read_sql(text(QUERY), conn)


def add_bucket(df):
    # same buckets as the SQL file: <= 0, 1 to 7, more than 7 days after the estimate
    df["bucket"] = pd.cut(
        df["days_vs_estimate"],
        bins=[-float("inf"), 0, 7, float("inf")],
        labels=LABELS,
    )
    return df


def summarize(df):
    return (
        df.groupby("bucket", observed=True)
        .agg(
            orders=("order_id", "count"),
            avg_review=("review_score", "mean"),
            low_review_pct=("review_score", lambda s: (s <= 2).mean() * 100),
        )
        .round(2)
    )


def run_test(df):
    on_time = df.loc[df["days_vs_estimate"] <= 0, "review_score"]
    late = df.loc[df["days_vs_estimate"] > 0, "review_score"]
    # H0: on-time and late orders have the same review score distribution
    # H1: on-time orders tend to get higher scores
    u_stat, p_value = mannwhitneyu(on_time, late, alternative="greater")
    prob_higher = u_stat / (len(on_time) * len(late))
    return on_time, late, p_value, prob_higher


def save_chart(summary, path):
    fig, axes = plt.subplots(1, 2, figsize=(10, 4))
    axes[0].bar(summary.index.astype(str), summary["avg_review"], color="#4C78A8")
    axes[0].set_title("Average review score")
    axes[0].set_ylim(0, 5)
    axes[1].bar(summary.index.astype(str), summary["low_review_pct"], color="#E45756")
    axes[1].set_title("Share of 1-2 star reviews (%)")
    axes[1].set_ylim(0, 100)
    for ax, col in zip(axes, ["avg_review", "low_review_pct"]):
        for i, value in enumerate(summary[col]):
            ax.text(i, value, f"{value:.1f}", ha="center", va="bottom")
        ax.tick_params(axis="x", labelrotation=15)
    fig.suptitle("Late delivery vs customer reviews (Olist, delivered orders)")
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def main():
    df = add_bucket(load_data())
    print(f"Orders analysed: {len(df):,}")

    summary = summarize(df)
    print(summary)

    on_time, late, p_value, prob_higher = run_test(df)
    print(f"On time: {len(on_time):,} orders, median review {on_time.median():.1f}")
    print(f"Late:    {len(late):,} orders, median review {late.median():.1f}")
    print(f"Mann-Whitney U p-value: {p_value:.3g}")
    print(f"Chance an on-time order scores higher than a late one: {prob_higher:.1%}")

    out_dir = Path(__file__).resolve().parent.parent / "docs"
    out_dir.mkdir(exist_ok=True)
    save_chart(summary, out_dir / "delivery_vs_reviews.png")
    print("Chart saved to docs/delivery_vs_reviews.png")


if __name__ == "__main__":
    main()