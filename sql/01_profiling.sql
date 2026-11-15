-- =============================================================================
-- sql/01_profiling.sql
-- Objective: profile the raw PaySim table before any transformation.
-- Run in BigQuery against paysim.raw_transactions.
-- =============================================================================

-- 1. Row count and time coverage.
--    The Kaggle description says 744 steps. The file actually contains 743
--    distinct steps (1 to 743), which still maps to 31 simulated days.
SELECT
  COUNT(*)             AS total_transactions,   -- 6,362,620
  MIN(step)            AS min_step,             -- 1
  MAX(step)            AS max_step,             -- 743
  COUNT(DISTINCT step) AS unique_steps          -- 743
FROM `paysim.raw_transactions`;

-- 2. Transaction types with fraud and flag counts.
--    Fraud exists only in TRANSFER and CASH_OUT.
SELECT
  type,
  COUNT(*)            AS transaction_count,
  SUM(isFraud)        AS fraud_count,
  SUM(isFlaggedFraud) AS flagged_fraud_count,
  ROUND(SUM(isFraud) * 100.0 / COUNT(*), 4) AS fraud_rate_pct
FROM `paysim.raw_transactions`
GROUP BY type
ORDER BY transaction_count DESC;

-- 3. Zero balance rows by type, a first look at ledger quality.
SELECT
  type,
  COUNT(*) AS total_count,
  COUNTIF(oldbalanceOrg = 0 AND newbalanceOrig = 0)  AS zero_orig_balances,
  COUNTIF(oldbalanceDest = 0 AND newbalanceDest = 0) AS zero_dest_balances
FROM `paysim.raw_transactions`
GROUP BY type;
