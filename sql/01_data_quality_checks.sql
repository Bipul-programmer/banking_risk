-- Run these checks after loading the Home Credit CSVs into MySQL.
-- Assumes the source table names are preserved (application_train, bureau, etc.).

-- 1. Confirm the application table has one row per application/customer.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT SK_ID_CURR) AS unique_customers,
    SUM(SK_ID_CURR IS NULL) AS missing_customer_ids,
    SUM(TARGET IS NULL) AS missing_targets,
    SUM(TARGET = 1) AS customers_with_payment_difficulty,
    ROUND(100.0 * AVG(TARGET), 2) AS payment_difficulty_rate_pct
FROM application_train;

-- 2. Check duplicate application IDs (expected: no rows).
SELECT SK_ID_CURR, COUNT(*) AS row_count
FROM application_train
GROUP BY SK_ID_CURR
HAVING COUNT(*) > 1
ORDER BY row_count DESC
LIMIT 100;

-- 3. Compare row counts and key coverage across the source tables.
-- Counts need not match: the history tables are one-to-many by design.
SELECT 'application_train' AS table_name, COUNT(*) AS row_count,
       COUNT(DISTINCT SK_ID_CURR) AS distinct_customers FROM application_train
UNION ALL
SELECT 'application_test', COUNT(*), COUNT(DISTINCT SK_ID_CURR) FROM application_test
UNION ALL
SELECT 'bureau', COUNT(*), COUNT(DISTINCT SK_ID_CURR) FROM bureau
UNION ALL
SELECT 'previous_application', COUNT(*), COUNT(DISTINCT SK_ID_CURR) FROM previous_application
UNION ALL
SELECT 'POS_CASH_balance', COUNT(*), COUNT(DISTINCT SK_ID_CURR) FROM POS_CASH_balance
UNION ALL
SELECT 'credit_card_balance', COUNT(*), COUNT(DISTINCT SK_ID_CURR) FROM credit_card_balance
UNION ALL
SELECT 'installments_payments', COUNT(*), COUNT(DISTINCT SK_ID_CURR) FROM installments_payments;

-- 4. Check for history rows whose customer is absent from application_train.
-- A non-zero count can be valid because history tables may include test customers.
SELECT 'bureau' AS source_table, COUNT(*) AS unmatched_rows
FROM bureau b
LEFT JOIN application_train a ON a.SK_ID_CURR = b.SK_ID_CURR
WHERE a.SK_ID_CURR IS NULL
UNION ALL
SELECT 'previous_application', COUNT(*)
FROM previous_application p
LEFT JOIN application_train a ON a.SK_ID_CURR = p.SK_ID_CURR
WHERE a.SK_ID_CURR IS NULL;

-- 5. Check relationship keys for history tables.
SELECT 'bureau: missing SK_ID_BUREAU' AS check_name, SUM(SK_ID_BUREAU IS NULL) AS issue_count FROM bureau
UNION ALL
SELECT 'bureau_balance: missing SK_ID_BUREAU', SUM(SK_ID_BUREAU IS NULL) FROM bureau_balance
UNION ALL
SELECT 'previous_application: missing SK_ID_PREV', SUM(SK_ID_PREV IS NULL) FROM previous_application
UNION ALL
SELECT 'POS_CASH_balance: missing SK_ID_PREV', SUM(SK_ID_PREV IS NULL) FROM POS_CASH_balance
UNION ALL
SELECT 'credit_card_balance: missing SK_ID_PREV', SUM(SK_ID_PREV IS NULL) FROM credit_card_balance
UNION ALL
SELECT 'installments_payments: missing SK_ID_PREV', SUM(SK_ID_PREV IS NULL) FROM installments_payments;
