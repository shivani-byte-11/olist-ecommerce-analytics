\# Progress Log



\## Day 1 - 08 Nov 2026

\- Done: Created GitHub repo, cloned it locally, set up folder structure, downloaded Olist dataset (9 CSVs), kept raw data out of Git via .gitignore

\- Learned: Git basics (clone, add, commit, push)

\- Next: Install MySQL and load the Olist tables

## Day 1 (update) - 08 Nov 2026

\- Done: Created olist\_db in MySQL, built 9 raw tables, loaded all CSVs (customers 99,441 / geolocation 1,000,163 / orders 99,441 / order\_items 112,650 / order\_payments 103,886 / order\_reviews 99,224 / products 32,951 / sellers 3,095 / category translation 71). Row counts match the source files.

\- Issues fixed: order\_reviews failed to load because comments contain backslashes (fixed with ESCAPED BY '') and the file uses Windows line endings (fixed with '\\r\\n'). Blank values in orders and products are loaded as NULL.

\- Learned: LOAD DATA INFILE only reads from the secure\_file\_priv folder; always check SHOW WARNINGS right after a load.

\- Noticed: some geolocation coordinates fall outside Brazil, to handle in the cleaning step.

\- Next: data profiling and cleaning (nulls, duplicates, outliers, orders with missing delivery dates)





\## Day 2 - 09 Nov 2026

\- Done: Installed MySQL Workbench and connected to the local server. Profiled the orders table: no duplicate order\_ids, 99,441 orders, about 97% delivered. Saved the queries in sql/02\_cleaning/01\_profile\_orders.sql.

\- Found: 14 orders where status and delivery date disagree (8 delivered orders with no delivery date, 6 canceled orders that have one). Also 2,965 orders have no delivery date, which is explained by undelivered, canceled and unavailable orders.

\- Decision: raw data stays untouched. Canceled and unavailable orders are excluded from revenue analysis, and orders without a delivery date are excluded from delivery-time analysis.

\- Learned: a spelling mismatch in a text filter ('cancelled' vs 'canceled') returns fewer rows without any error, so always compare the row count with what is expected.

\- Next: profile order\_items and order\_payments (duplicates, price outliers, payment totals vs item totals)

## Day 3 - Data profiling summary

\- Done: Profiled order\_items, order\_payments and cross-checked items against payments. Queries are saved in sql/02\_cleaning (files 02 to 04).

\- Found:

&#x20; - order\_items: no duplicate rows, no orphan items, no zero or negative prices. Prices range from 0.85 to 6,735 (avg 120.65). The top 10 items are plausible (computers, appliances, instruments), so outliers are kept. 383 items have free shipping.

&#x20; - order\_payments: credit card is about 78% of payment value. 3 payments have type not\_defined with value 0, 9 payments have value 0, and 2 payments have 0 installments. 1 delivered order has no payment record.

&#x20; - Items vs payments: 98,665 orders have both, and 98,362 of them match (99.7%). Of the 303 mismatches, 264 paid more (avg +11.63, likely installment interest) and 39 paid less (avg -5.10, unexplained).

&#x20; - 775 orders have no items (603 unavailable, 164 canceled, 8 other). No delivered order is missing items.

\- Decisions: raw data stays untouched. Revenue = SUM(price) from order\_items, with freight shown separately. Canceled and unavailable orders are excluded. Use median alongside average because of price outliers.

\- Learned: aggregate each table to one row per order before joining, otherwise rows multiply and revenue is double-counted.

\- Next: build cleaned views, then the revenue and customer analysis (monthly revenue trend, top categories, repeat customers)

