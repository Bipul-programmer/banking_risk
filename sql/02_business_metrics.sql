-- Dashboard-ready business metrics for Home Credit Default Risk.
-- Payment difficulty rate is TARGET=1 records / all labeled applications.

-- 1. Executive KPIs
SELECT
    COUNT(*) AS applications,
    COUNT(DISTINCT SK_ID_CURR) AS unique_customers,
    SUM(TARGET = 1) AS customers_with_payment_difficulty,
    SUM(TARGET = 0) AS customers_without_payment_difficulty,
    ROUND(100.0 * AVG(TARGET), 2) AS payment_difficulty_rate_pct,
    ROUND(AVG(AMT_INCOME_TOTAL), 2) AS average_income,
    ROUND(AVG(AMT_CREDIT), 2) AS average_credit,
    ROUND(AVG(AMT_ANNUITY), 2) AS average_annuity
FROM application_train
WHERE TARGET IS NOT NULL;

-- 2. Payment difficulty by age band
SELECT
    CASE
        WHEN -DAYS_BIRTH / 365.25 < 26 THEN '18-25'
        WHEN -DAYS_BIRTH / 365.25 < 36 THEN '26-35'
        WHEN -DAYS_BIRTH / 365.25 < 46 THEN '36-45'
        WHEN -DAYS_BIRTH / 365.25 < 56 THEN '46-55'
        WHEN -DAYS_BIRTH / 365.25 < 66 THEN '56-65'
        ELSE '66+'
    END AS age_band,
    COUNT(*) AS applications,
    SUM(TARGET = 1) AS payment_difficulty_count,
    ROUND(100.0 * AVG(TARGET), 2) AS payment_difficulty_rate_pct
FROM application_train
WHERE TARGET IS NOT NULL AND DAYS_BIRTH IS NOT NULL
GROUP BY age_band
ORDER BY MIN(-DAYS_BIRTH / 365.25);

-- 3. Payment difficulty by education
SELECT
    NAME_EDUCATION_TYPE AS education,
    COUNT(*) AS applications,
    SUM(TARGET = 1) AS payment_difficulty_count,
    ROUND(100.0 * AVG(TARGET), 2) AS payment_difficulty_rate_pct,
    ROUND(AVG(AMT_INCOME_TOTAL), 2) AS average_income,
    ROUND(AVG(AMT_CREDIT), 2) AS average_credit
FROM application_train
WHERE TARGET IS NOT NULL
GROUP BY NAME_EDUCATION_TYPE
ORDER BY payment_difficulty_rate_pct DESC;

-- 4. Payment difficulty by income band
SELECT
    CASE
        WHEN AMT_INCOME_TOTAL < 100000 THEN 'Under 100k'
        WHEN AMT_INCOME_TOTAL < 200000 THEN '100k-199k'
        WHEN AMT_INCOME_TOTAL < 500000 THEN '200k-499k'
        ELSE '500k+'
    END AS income_band,
    COUNT(*) AS applications,
    SUM(TARGET = 1) AS payment_difficulty_count,
    ROUND(100.0 * AVG(TARGET), 2) AS payment_difficulty_rate_pct,
    ROUND(AVG(AMT_CREDIT), 2) AS average_credit
FROM application_train
WHERE TARGET IS NOT NULL AND AMT_INCOME_TOTAL IS NOT NULL
GROUP BY income_band
ORDER BY MIN(AMT_INCOME_TOTAL);

-- 5. Payment difficulty by contract type and gender
SELECT
    NAME_CONTRACT_TYPE AS contract_type,
    CODE_GENDER AS gender,
    COUNT(*) AS applications,
    SUM(TARGET = 1) AS payment_difficulty_count,
    ROUND(100.0 * AVG(TARGET), 2) AS payment_difficulty_rate_pct
FROM application_train
WHERE TARGET IS NOT NULL
GROUP BY NAME_CONTRACT_TYPE, CODE_GENDER
ORDER BY payment_difficulty_rate_pct DESC;

-- 6. Customer-level bureau summary, then join to applications.
-- Aggregate bureau first to prevent one-to-many joins inflating application counts.
WITH bureau_by_customer AS (
    SELECT
        SK_ID_CURR,
        COUNT(*) AS bureau_accounts,
        SUM(CREDIT_ACTIVE = 'Active') AS active_bureau_accounts,
        AVG(AMT_CREDIT_SUM) AS avg_bureau_credit,
        SUM(AMT_CREDIT_SUM_DEBT) AS total_bureau_debt
    FROM bureau
    GROUP BY SK_ID_CURR
)
SELECT
    CASE WHEN COALESCE(b.bureau_accounts, 0) = 0 THEN 'No bureau history'
         WHEN b.bureau_accounts = 1 THEN '1 account'
         WHEN b.bureau_accounts BETWEEN 2 AND 4 THEN '2-4 accounts'
         ELSE '5+ accounts' END AS bureau_history_band,
    COUNT(*) AS applications,
    SUM(a.TARGET = 1) AS payment_difficulty_count,
    ROUND(100.0 * AVG(a.TARGET), 2) AS payment_difficulty_rate_pct,
    ROUND(AVG(b.total_bureau_debt), 2) AS average_bureau_debt
FROM application_train a
LEFT JOIN bureau_by_customer b ON b.SK_ID_CURR = a.SK_ID_CURR
WHERE a.TARGET IS NOT NULL
GROUP BY bureau_history_band
ORDER BY MIN(COALESCE(b.bureau_accounts, 0));

-- 7. Customer-level late installment summary, then join to applications.
WITH installments_by_customer AS (
    SELECT
        SK_ID_CURR,
        COUNT(*) AS installment_records,
        SUM(DAYS_ENTRY_PAYMENT > DAYS_INSTALMENT) AS late_payment_records,
        AVG(GREATEST(DAYS_ENTRY_PAYMENT - DAYS_INSTALMENT, 0)) AS avg_days_late
    FROM installments_payments
    GROUP BY SK_ID_CURR
)
SELECT
    CASE WHEN COALESCE(i.installment_records, 0) = 0 THEN 'No installment history'
         WHEN COALESCE(i.late_payment_records, 0) = 0 THEN 'No late installments'
         ELSE 'Has late installments' END AS installment_history_band,
    COUNT(*) AS applications,
    SUM(a.TARGET = 1) AS payment_difficulty_count,
    ROUND(100.0 * AVG(a.TARGET), 2) AS payment_difficulty_rate_pct,
    ROUND(AVG(i.avg_days_late), 2) AS average_days_late
FROM application_train a
LEFT JOIN installments_by_customer i ON i.SK_ID_CURR = a.SK_ID_CURR
WHERE a.TARGET IS NOT NULL
GROUP BY installment_history_band
ORDER BY payment_difficulty_rate_pct DESC;
