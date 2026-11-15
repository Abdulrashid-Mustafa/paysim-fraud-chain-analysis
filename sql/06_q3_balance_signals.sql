-- =============================================================================
-- sql/06_q3_balance_signals.sql
-- Objective: Q3. Test amount and balance behaviour as fraud signals, and
--            measure how much of the balance signal is a simulation artifact.
--
-- Context: the dataset owner states that fraud transactions are cancelled in
-- the simulation and that oldbalanceOrg, newbalanceOrig, oldbalanceDest and
-- newbalanceDest must not be used for fraud detection. The exports below
-- show why, using the data itself.
-- =============================================================================


-- Export -> data/q3_draining_signal.csv
-- Share of rows whose origin balance is reported as fully emptied.
SELECT
  isFraud,
  COUNT(*) AS total_transactions,
  COUNTIF(is_orig_drained = 1) AS fully_drained_count,
  ROUND(SAFE_DIVIDE(COUNTIF(is_orig_drained = 1), COUNT(*)) * 100, 2)
    AS fully_drained_pct
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY isFraud
ORDER BY isFraud DESC;


-- Export -> data/q3_balance_artifacts.csv
-- How the simulator writes balances for each class.
--   amount_equals_balance_pct : amount is exactly the origin balance
--   dest_zero_pct             : destination balance 0 before and after
--   drained_pct               : origin balance reported as emptied
--   drained_amount_above_balance : drained rows where the amount is larger
--                                  than the balance it supposedly emptied
SELECT
  type,
  isFraud,
  COUNT(*) AS total_transactions,
  ROUND(SAFE_DIVIDE(COUNTIF(oldbalanceOrg > 0 AND amount = oldbalanceOrg),
                    COUNT(*)) * 100, 2) AS amount_equals_balance_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(oldbalanceDest = 0 AND newbalanceDest = 0),
                    COUNT(*)) * 100, 2) AS dest_zero_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(is_orig_drained = 1), COUNT(*)) * 100, 2)
    AS drained_pct,
  COUNTIF(is_orig_drained = 1) AS drained_rows,
  COUNTIF(is_orig_drained = 1 AND amount > oldbalanceOrg)
    AS drained_amount_above_balance
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY type, isFraud
ORDER BY type, isFraud DESC;


-- Export -> data/q3_drain_ratio.csv
-- Exact median and 90th percentile of amount / oldbalanceOrg, on rows where
-- the origin balance is positive. A ratio above 1 means the amount is larger
-- than the balance it came from, which is a ledger inconsistency.
WITH ratios AS (
  SELECT
    isFraud,
    PERCENTILE_CONT(amount / oldbalanceOrg, 0.5) OVER (PARTITION BY isFraud) AS median_ratio,
    PERCENTILE_CONT(amount / oldbalanceOrg, 0.9) OVER (PARTITION BY isFraud) AS p90_ratio
  FROM paysim.cleaned_transactions
  WHERE type IN ('TRANSFER', 'CASH_OUT') AND oldbalanceOrg > 0
)
SELECT
  isFraud,
  COUNT(*) AS rows_with_positive_balance,
  ROUND(ANY_VALUE(median_ratio), 2) AS median_drained_ratio,
  ROUND(ANY_VALUE(p90_ratio), 2) AS p90_drained_ratio
FROM ratios
GROUP BY isFraud
ORDER BY isFraud DESC;


-- Export -> data/q3_amount_buckets.csv
-- Count and value by amount band and class.
SELECT
  CASE
    WHEN amount <    1000 THEN 'a. under 1K'
    WHEN amount <   10000 THEN 'b. 1K to 10K'
    WHEN amount <  100000 THEN 'c. 10K to 100K'
    WHEN amount < 1000000 THEN 'd. 100K to 1M'
    ELSE                       'e. 1M and over'
  END AS amount_bucket,
  isFraud,
  COUNT(*) AS txns,
  ROUND(SUM(amount), 2) AS total_amount
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY amount_bucket, isFraud
ORDER BY amount_bucket, isFraud DESC;


-- Export -> data/q3_ledger_anomalies.csv
-- Zero origin balance rows and balance errors, by transaction type.
SELECT
  type,
  COUNT(*) AS total_rows,
  COUNTIF(oldbalanceOrg = 0 AND newbalanceOrig = 0) AS zero_orig_balance_rows,
  ROUND(SAFE_DIVIDE(COUNTIF(oldbalanceOrg = 0 AND newbalanceOrig = 0),
                    COUNT(*)) * 100, 2) AS zero_orig_balance_pct,
  COUNTIF(ABS(orig_balance_error) > 0.01) AS orig_error_rows,
  COUNTIF(ABS(dest_balance_error) > 0.01) AS dest_error_rows
FROM paysim.cleaned_transactions
GROUP BY type
ORDER BY zero_orig_balance_pct DESC;
