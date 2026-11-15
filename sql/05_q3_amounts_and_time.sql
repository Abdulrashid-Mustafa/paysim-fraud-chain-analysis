-- =============================================================================
-- sql/05_q3_amounts_and_time.sql
-- Objective: amount profile by class, plus hourly and daily fraud patterns.
-- All rates are computed within TRANSFER and CASH_OUT only.
-- =============================================================================


-- Export -> data/q3_amount_summary.csv
-- Average and median amount by type and class.
WITH base AS (
  SELECT
    type, isFraud, amount,
    PERCENTILE_CONT(amount, 0.5) OVER (PARTITION BY type, isFraud) AS median_amount
  FROM paysim.cleaned_transactions
  WHERE type IN ('TRANSFER', 'CASH_OUT')
)
SELECT
  type,
  isFraud,
  COUNT(*) AS total_transactions,
  ROUND(AVG(amount), 2) AS avg_amount,
  ROUND(ANY_VALUE(median_amount), 2) AS median_amount
FROM base
GROUP BY type, isFraud
ORDER BY type, isFraud DESC;


-- Export -> data/hourly_fraud.csv
-- legit_tx is reported separately, because total_tx includes the fraud rows.
SELECT
  hour_of_day,
  COUNT(*) AS total_tx,
  COUNTIF(isFraud = 1) AS fraud_tx,
  COUNTIF(isFraud = 0) AS legit_tx,
  ROUND(SAFE_DIVIDE(COUNTIF(isFraud = 1), COUNT(*)) * 100, 4) AS fraud_rate_pct
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY hour_of_day
ORDER BY hour_of_day;


-- Export -> data/daily_fraud.csv
SELECT
  sim_day,
  COUNT(*) AS total_tx,
  COUNTIF(isFraud = 1) AS fraud_tx,
  COUNTIF(isFraud = 0) AS legit_tx,
  ROUND(SAFE_DIVIDE(COUNTIF(isFraud = 1), COUNT(*)) * 100, 4) AS fraud_rate_pct
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY sim_day
ORDER BY sim_day;
