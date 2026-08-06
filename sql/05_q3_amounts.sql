-- =============================================================================
-- sql/05_q3_amounts.sql  (CORRECTED — matches actual schema)
-- Objective: Q3 - Analyze Behavioral Signals (Account Draining) vs Amount
--
-- Fixes applied vs. the original file:
--   is_orig_fully_drained -> is_orig_drained
--   orig_drained_ratio    -> computed inline (no such stored column exists)
-- =============================================================================

-- Section 1: Core Q3 Analysis - Account Draining vs Monetary Amount
SELECT
  type,
  isFraud,
  COUNT(*) AS total_transactions,
  ROUND(AVG(amount), 2) AS avg_amount,
  ROUND(STDDEV(amount), 2) AS std_dev_amount,
  COUNTIF(is_orig_drained = 1) AS fully_drained_count,
  ROUND(SAFE_DIVIDE(COUNTIF(is_orig_drained = 1), COUNT(*)) * 100, 2)
    AS fully_drained_pct,
  ROUND(AVG(SAFE_DIVIDE(amount, NULLIF(oldbalanceOrg, 0))), 4)
    AS avg_drained_ratio
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY type, isFraud
ORDER BY type, isFraud DESC;


-- Section 2: Hourly Fraud Aggregation (Export to data/hourly_fraud.csv)
SELECT
  hour_of_day,
  COUNT(*) AS total_tx,
  COUNTIF(isFraud = 1) AS fraud_tx,
  ROUND(SAFE_DIVIDE(COUNTIF(isFraud = 1), COUNT(*)) * 100, 4) AS fraud_rate_pct
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY hour_of_day
ORDER BY hour_of_day;


-- Section 3: Daily Fraud Aggregation (Export to data/daily_fraud.csv)
SELECT
  sim_day,
  COUNT(*) AS total_tx,
  COUNTIF(isFraud = 1) AS fraud_tx,
  ROUND(SAFE_DIVIDE(COUNTIF(isFraud = 1), COUNT(*)) * 100, 4) AS fraud_rate_pct
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY sim_day
ORDER BY sim_day;