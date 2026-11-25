# Progress Log



## Day 1 - 08 Nov 2026

- Done: Created GitHub repo, cloned it locally, set up folder structure, downloaded Olist dataset (9 CSVs), kept raw data out of Git via .gitignore

- Learned: Git basics (clone, add, commit, push)

- Next: Install MySQL and load the Olist tables

## Day 1 (update) - 08 Nov 2026

- Done: Created olist_db in MySQL, built 9 raw tables, loaded all CSVs (customers 99,441 / geolocation 1,000,163 / orders 99,441 / order_items 112,650 / order_payments 103,886 / order_reviews 99,224 / products 32,951 / sellers 3,095 / category translation 71). Row counts match the source files.

- Issues fixed: order_reviews failed to load because comments contain backslashes (fixed with ESCAPED BY '') and the file uses Windows line endings (fixed with '\\r\\n'). Blank values in orders and products are loaded as NULL.

- Learned: LOAD DATA INFILE only reads from the secure_file_priv folder; always check SHOW WARNINGS right after a load.

- Noticed: some geolocation coordinates fall outside Brazil, to handle in the cleaning step.

- Next: data profiling and cleaning (nulls, duplicates, outliers, orders with missing delivery dates)





## Day 2 - 09 Nov 2026

- Done: Installed MySQL Workbench and connected to the local server. Profiled the orders table: no duplicate order_ids, 99,441 orders, about 97% delivered. Saved the queries in sql/02_cleaning/01_profile_orders.sql.

- Found: 14 orders where status and delivery date disagree (8 delivered orders with no delivery date, 6 canceled orders that have one). Also 2,965 orders have no delivery date, which is explained by undelivered, canceled and unava

ilable orders.

- Decision: raw data stays untouched. Canceled and unavailable orders are excluded from revenue analysis, and orders without a delivery date are excluded from delivery-time analysis.

- Learned: a spelling mismatch in a text filter ('cancelled' vs 'canceled') returns fewer rows without any error, so always compare the row count with what is expected.

- Next: profile order_items and order_payments (duplicates, price outliers, payment totals vs item totals)

## Day 3 - Data profiling summary

- Done: Profiled order_items, order_payments and cross-checked items against payments. Queries are saved in sql/02_cleaning (files 02 to 04).

- Found:

  - order_items: no duplicate rows, no orphan items, no zero or negative prices. Prices range from 0.85 to 6,735 (avg 120.65). The top 10 items are plausible (computers, appliances, instruments), so outliers are kept. 383 items have free shipping.

  - order_payments: credit card is about 78% of payment value. 3 payments have type not_defined with value 0, 9 payments have value 0, and 2 payments have 0 installments. 1 delivered order has no payment record.

  - Items vs payments: 98,665 orders have both, and 98,362 of them match (99.7%). Of the 303 mismatches, 264 paid more (avg +11.63, likely installment interest) and 39 paid less (avg -5.10, unexplained).

  - 775 orders have no items (603 unavailable, 164 canceled, 8 other). No delivered order is missing items.

- Decisions: raw data stays untouched. Revenue = SUM(price) from order_items, with freight shown separately. Canceled and unavailable orders are excluded. Use median alongside average because of price outliers.

- Learned: aggregate each table to one row per order before joining, otherwise rows multiply and revenue is double-counted.

- Next: build cleaned views, then the revenue and customer analysis (monthly revenue trend, top categories, repeat customers)



## Day 4-6 - Revenue analysis

- Done: Built the vw_order_revenue view (98,199 valid orders, product revenue R$ 13,494,400.74, freight R$ 2,241,126.29). Then wrote the monthly revenue trend with MoM growth, year-over-year growth, top 10 categories, and a Pareto check. Queries are in sql/03_analysis (files 01 to 05).

- Findings:

  - Peak month is 2017-11 with 7,421 orders and R$ 1,003,862 revenue (+52.1% vs October).

  - Revenue stalled in 2018: March to August stayed between about R$ 840K and R$ 990K per month.

  - YoY growth fell from +687% (Jan 2018) to +49% (Aug 2018). Part of this is a small-base effect (Jan 2017 had only 787 orders).

  - Average order value stayed between about R$ 125 and R$ 150, so growth came from more orders, not bigger orders.

  - health_beauty is the top category (9.3% of revenue), then watches_gifts (8.9%) and bed_bath_table (7.7%). 18 of 74 category labels bring in 80% of revenue, and no category is above 10%.

  - Items with no category ("unknown") are 1.3% of revenue.

- Decisions: the analysis window is 2017-01 to 2018-08, because 2016 months (1 to 290 orders) and 2018-09 (1 order) make growth percentages meaningless.

- Issues fixed:

  - DATE_FORMAT with %M returned month names (2017-April) and broke the ordering that LAG depends on; %m gives 2017-04. Always check that a month label sorts in calendar order.

  - Two totals differed by R$ 2,007.69. The cause was a query that excluded canceled orders but not unavailable ones. When two totals disagree, compare the filters first.

  - Two query files were never saved before pushing. I now run dir to confirm files exist before every commit.

- Learned: LAG(revenue, 12) gives the same month last year only when no month is missing in the window; window functions (LAG, ROW_NUMBER, running SUM) and CTEs; aggregate before joining so rows do not multiply.

- Next: customer analysis (repeat customers, RFM segments), then delivery time vs review score



## Day 7 - Customers

- Done: Checked customer identity, calculated the repeat purchase rate, and built an RFM-style segmentation. Queries are in sql/03_analysis (files 06 and 07).

- Findings:

  - customer_id is created per order, so it cannot be used for customer analysis. 99,441 customer_ids map to only 96,096 real customers (customer_unique_id).

  - Retention is the weak spot: 94,983 customers placed valid orders, and only 2,887 (3.04%) bought more than once. Repeat customers bring 5.6% of revenue and spend about 1.9 times more per customer than one-time buyers (rough estimate).

  - Customer value depends on spend more than frequency: the upper-spend half of one-time buyers is about 47.5% of customers but 78% of revenue (avg spend about R$ 233, vs about R$ 47 for the lower half).

  - Biggest win-back target: 22,436 older-purchase high spenders holding 39% of revenue.

  - The top customer has 16 small orders (avg about R$ 46) and is kept in the analysis.

- Definition: "recent" means the last purchase was on or after 22 Jan 2018 (the median of last-purchase dates, orders before 2018-09-01 only); "lapsed" means earlier. This is a relative cutoff, not a proven churn rule.

- Caveat: NTILE(4) forces near-equal groups, so the sizes of the four one-time segments come from the method, not from the data.

- Learned: NTILE for quartile scoring, CASE for rule-based segments, and why the ID you count by decides the answer.

- Next: delivery time vs review score (hypothesis test), then Python charts



## Day 8 - Delivery vs reviews

- Done: Compared review scores of on-time and late delivered orders in SQL (sql/03_analysis/08_delivery_vs_reviews.sql), then repeated it in Python with a hypothesis test and a chart (python/01_delivery_vs_reviews.py, docs/delivery_vs_reviews.png).

- Findings (95,824 delivered orders with a review; late = after the estimated delivery date):

  - On time or early: 89,443 orders, average review 4.29, 9.2% low reviews (1-2 stars).

  - 1-7 days late: 3,600 orders, average review 2.72, 49.4% low reviews.

  - 8+ days late: 2,781 orders, average review 1.70, 79.2% low reviews.

  - Median review is 5 for on-time orders and 1 for late orders. Mann-Whitney U test: p < 0.001. An on-time order scores higher than a late one in about 82% of random pairs (ties counted as half).

  - Late orders are about 6.7% of the total, but their reviews are much lower.

- Caveat: this shows late delivery is associated with lower scores, not that it is the only cause. Only customers who left a review are included.

- Learned: SQL and Python gave identical numbers, which is a good cross-check. With a large sample the p-value is always tiny, so the effect size and medians matter more. Never store a password in code: the script asks for it with getpass.

- Next: Power BI dashboard (Revenue, Customers, Delivery pages)



## Day 8-11

- Built delivery vs reviews analysis (4.29 vs 1.70 avg review, 79.2% low reviews for 8+ days late).

- Python test (Mann-Whitney) confirmed the gap, p < 0.001.

- Built 3-page Power BI dashboard (Revenue, Customers, Delivery).

- Mistakes fixed: table column names got mismatched in Power BI, rebuilt the table. Checked 547 orders with multiple reviews, query already averages per order.

- Checked category concentration: top 3 categories are only 25.8% of revenue, so dropped the "concentration" recommendation.


