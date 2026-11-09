-- Profile the order_payments table (values in Brazilian reais)

-- Payment type breakdown.
-- Finding: credit card is about 78% of value, then boleto, voucher, debit card.
-- 3 rows have type not_defined with value 0.00.
SELECT payment_type,
       COUNT(*)                     AS payments,
       ROUND(SUM(payment_value), 2) AS total_value
FROM order_payments
GROUP BY payment_type
ORDER BY payments DESC;

-- Zero values and installments.
-- Finding: 9 zero-value payments, 2 payments with 0 installments, max 24 installments.
SELECT SUM(payment_value <= 0)        AS zero_or_negative_value,
       SUM(payment_installments = 0)  AS zero_installments,
       MAX(payment_installments)      AS max_installments,
       ROUND(AVG(payment_value), 2)   AS avg_payment
FROM order_payments;

-- Orders with no payment record. Finding: 1 order (delivered, Sep 2016).
SELECT COUNT(*) AS orders_without_payment
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- Inspect the suspicious payments.
-- Decision: keep them (zero-value rows do not change totals); treat 0 installments as 1.
SELECT p.order_id,
       o.order_status,
       p.payment_type,
       p.payment_installments,
       p.payment_value
FROM order_payments p
JOIN orders o ON p.order_id = o.order_id
WHERE p.payment_value <= 0
   OR p.payment_installments = 0
ORDER BY p.payment_type, p.payment_value;