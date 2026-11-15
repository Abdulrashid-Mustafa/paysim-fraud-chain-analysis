-- =============================================================================
-- sql/03_q1_value_and_control.sql
-- Objective: Q1. Value at risk, and how the existing control (isFlaggedFraud)
--            actually behaves. Amounts are in the simulator's local currency.
-- =============================================================================


-- Export -> data/q1_value_control.csv
-- Value and control performance by transaction type.
SELECT
  type,
  COUNT(*) AS total_transactions,
  ROUND(SUM(amount), 2) AS total_amount,
  COUNTIF(isFraud = 1) AS fraud_count,
  ROUND(SUM(CASE WHEN isFraud = 1 THEN amount ELSE 0 END), 2) AS fraud_amount,
  COUNTIF(isFlaggedFraud = 1) AS flagged_count,
  COUNTIF(isFraud = 1 AND isFlaggedFraud = 1) AS correctly_flagged_fraud,
  ROUND(SAFE_DIVIDE(COUNTIF(isFraud = 1 AND isFlaggedFraud = 1),
                    COUNTIF(isFraud = 1)) * 100, 4) AS recall_detection_rate_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(isFraud = 1), COUNT(*)) * 100, 4) AS fraud_rate_pct
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY type
ORDER BY fraud_amount DESC;


-- Export -> data/q1_headline.csv
-- The two legs are the same money observed twice, so they are never added.
SELECT
  ROUND(SUM(CASE WHEN type = 'TRANSFER' THEN amount END), 2) AS transfer_value,
  ROUND(SUM(CASE WHEN type = 'CASH_OUT' THEN amount END), 2) AS cashout_value,
  ROUND(SAFE_DIVIDE(SUM(CASE WHEN type = 'CASH_OUT' THEN amount END),
                    SUM(CASE WHEN type = 'TRANSFER' THEN amount END)) * 100, 1)
    AS cashout_to_transfer_value_pct,
  COUNTIF(type = 'TRANSFER') AS fraud_transfers,
  COUNTIF(type = 'CASH_OUT') AS fraud_cashouts,
  COUNT(*) AS total_fraud_legs,
  SUM(isFlaggedFraud) AS flagged_by_system,
  ROUND(SAFE_DIVIDE(SUM(isFlaggedFraud), COUNT(*)) * 100, 2) AS overall_recall_pct,
  ROUND(SAFE_DIVIDE(SUM(isFlaggedFraud), COUNTIF(type = 'TRANSFER')) * 100, 2)
    AS transfer_recall_pct
FROM paysim.cleaned_transactions
WHERE isFraud = 1;


-- Export -> data/q1_flag_behaviour.csv
-- The dataset documents the flag as firing on any transfer above 200,000.
-- This query tests that claim, and checks what happened when it did fire.
SELECT
  COUNTIF(type = 'TRANSFER' AND amount > 200000) AS transfers_over_200k,
  COUNTIF(type = 'TRANSFER' AND amount > 200000 AND isFraud = 1)
    AS fraud_transfers_over_200k,
  COUNTIF(isFlaggedFraud = 1) AS flagged_transfers,
  COUNTIF(isFlaggedFraud = 1 AND isFraud = 1) AS flagged_that_are_fraud,
  COUNTIF(isFlaggedFraud = 1 AND oldbalanceOrg = newbalanceOrig)
    AS flagged_with_origin_balance_unchanged,
  COUNTIF(type = 'CASH_OUT' AND isFraud = 1 AND amount = 0)
    AS fraud_cashouts_of_zero,
  ROUND(MIN(CASE WHEN isFlaggedFraud = 1 THEN amount END), 2) AS min_flagged_amount,
  ROUND(MAX(CASE WHEN isFlaggedFraud = 1 THEN amount END), 2) AS max_flagged_amount
FROM paysim.cleaned_transactions;
