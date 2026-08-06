-- =============================================================================
-- sql/03_q1_value_and_control.sql
-- Objective: Q1 - Quantify value at risk and measure how the existing control
--            (isFlaggedFraud) actually performs.
--
-- Export result set 1 -> data/q1_value_control.csv
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Result 1: value and control performance by transaction type
-- -----------------------------------------------------------------------------

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


-- -----------------------------------------------------------------------------
-- Result 2: the headline reconciliation.
--
-- Do NOT add the two legs together. They are the same money observed twice as
-- it moves through the chain, so summing them would double count it. Report
-- how much was targeted and how much of it was successfully liquidated.
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
  targeted_value,                                            -- expect 6,067,213,184.01
  liquidated_value,                                          -- expect 5,989,202,243.83
  ROUND(SAFE_DIVIDE(liquidated_value, targeted_value) * 100, 1)
    AS liquidation_rate_pct,                                 -- expect 98.7
  fraud_transfers + fraud_cashouts AS total_fraud_legs,      -- expect 8,213
  flagged_by_system,                                         -- expect 16
  ROUND(SAFE_DIVIDE(flagged_by_system,
                    fraud_transfers + fraud_cashouts) * 100, 3)
    AS overall_recall_pct                                    -- expect 0.195
FROM legs;
