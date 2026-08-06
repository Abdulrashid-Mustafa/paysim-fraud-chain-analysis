-- =============================================================================
-- sql/06_q3_exports_and_flows.sql
-- Purpose : Export the evidence files behind the Q3 claims in the README, and
--           rebuild the flow table used by the Tableau dashboard.
--
-- Column names below match the actual paysim.cleaned_transactions schema:
--   is_orig_drained      (not is_orig_fully_drained)
--   orig_balance_error   (not orig_balance_discrepancy)
--   dest_balance_error   (not dest_balance_discrepancy)
--   There is no stored drained-ratio column, so it is computed inline below
--   from amount and oldbalanceOrg.
--
-- If your dataset/table name differs from paysim.cleaned_transactions,
-- replace it throughout before running.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Export 1 -> data/q3_draining_signal.csv
-- Backs the README claim: fraud drains the origin account at a far higher
-- rate than legitimate activity.
-- -----------------------------------------------------------------------------

SELECT
  isFraud,
  COUNT(*) AS total_transactions,
  COUNTIF(is_orig_drained = 1) AS fully_drained_count,
  ROUND(SAFE_DIVIDE(COUNTIF(is_orig_drained = 1), COUNT(*)) * 100, 2)
    AS fully_drained_pct,
  ROUND(AVG(SAFE_DIVIDE(amount, NULLIF(oldbalanceOrg, 0))), 4)
    AS avg_drained_ratio
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY isFraud
ORDER BY isFraud DESC;


-- -----------------------------------------------------------------------------
-- Export 2 -> data/q3_amount_buckets.csv
-- Backs the README claim: fraudulent amounts overlap heavily with legitimate
-- high value activity, so a static threshold cannot separate them.
-- -----------------------------------------------------------------------------

SELECT
  CASE
    WHEN amount <    1000 THEN 'a. under 1K'
    WHEN amount <   10000 THEN 'b. 1K to 10K'
    WHEN amount <  100000 THEN 'c. 10K to 100K'
    WHEN amount < 1000000 THEN 'd. 100K to 1M'
    ELSE                       'e. over 1M'
  END AS amount_bucket,
  isFraud,
  COUNT(*) AS txns,
  ROUND(SUM(amount), 2) AS total_amount
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY amount_bucket, isFraud
ORDER BY amount_bucket, isFraud DESC;


-- -----------------------------------------------------------------------------
-- Export 3 -> data/q3_ledger_anomalies.csv
-- Backs the README claim about the share of records carrying zero origin
-- balances, and now also reports the balance_error columns directly.
-- -----------------------------------------------------------------------------

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


-- -----------------------------------------------------------------------------
-- Export 4 -> data/q2_flows.csv  (REPLACES the broken CASH_OUT -> CASH_OUT file)
--
-- Models the two real legs of the chain instead of a hardcoded target that
-- produced a meaningless self loop for CASH_OUT rows.
-- -----------------------------------------------------------------------------

SELECT 'Victim account' AS source_channel,
       'Mule account'   AS target_channel,
       1                AS leg_order,
       COUNT(*)         AS transaction_count,
       ROUND(SUM(amount), 2) AS volume
FROM paysim.cleaned_transactions
WHERE isFraud = 1 AND type = 'TRANSFER'

UNION ALL

SELECT 'Mule account'  AS source_channel,
       'Cash-out exit' AS target_channel,
       2               AS leg_order,
       COUNT(*)        AS transaction_count,
       ROUND(SUM(amount), 2) AS volume
FROM paysim.cleaned_transactions
WHERE isFraud = 1 AND type = 'CASH_OUT'

ORDER BY leg_order;


-- -----------------------------------------------------------------------------
-- Reconciliation query: the corrected headline number.
-- Do NOT add the two legs together — they are the same money observed twice
-- as it moves through the chain. Run this once and use its output to fill
-- the <<INSERT>> placeholders in README section 4 (Q1) and Q3.
-- -----------------------------------------------------------------------------

WITH legs AS (
  SELECT
    ROUND(SUM(CASE WHEN type = 'TRANSFER' THEN amount END), 2) AS targeted_value,
    ROUND(SUM(CASE WHEN type = 'CASH_OUT' THEN amount END), 2) AS liquidated_value,
    COUNTIF(type = 'TRANSFER') AS fraud_transfers,
    COUNTIF(type = 'CASH_OUT') AS fraud_cashouts,
    SUM(isFlaggedFraud) AS flagged_by_system
  FROM paysim.cleaned_transactions
  WHERE isFraud = 1
)
SELECT
  targeted_value,
  liquidated_value,
  ROUND(SAFE_DIVIDE(liquidated_value, targeted_value) * 100, 1) AS liquidation_rate_pct,
  fraud_transfers + fraud_cashouts AS total_fraud_legs,
  flagged_by_system,
  ROUND(SAFE_DIVIDE(flagged_by_system, fraud_transfers + fraud_cashouts) * 100, 3)
    AS overall_recall_pct
FROM legs;