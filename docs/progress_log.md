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

