-- =============================================================================
-- sql/04_q2_fraud_chain.sql
-- Objective: Q2. Reconstruct the TRANSFER to CASH_OUT chain and measure how
--            long the money stays before it exits.
-- =============================================================================


-- Feasibility check: can the two legs be linked by account?
-- Result: 0. No account that receives a fraudulent TRANSFER ever starts a
-- fraudulent CASH_OUT, so chains have to be matched on amount and time.
-- (Also recorded in data/validation_checks.csv by sql/08.)
SELECT COUNT(*) AS name_linked_accounts
FROM (SELECT DISTINCT nameDest AS acct FROM paysim.cleaned_transactions
      WHERE type = 'TRANSFER' AND isFraud = 1) t
JOIN (SELECT DISTINCT nameOrig AS acct FROM paysim.cleaned_transactions
      WHERE type = 'CASH_OUT' AND isFraud = 1) c
USING (acct);


-- Export -> data/q2_chain_outcomes.csv
--
-- One row per fraudulent transfer, never one row per join match. For each
-- transfer, look for a fraudulent cash out of exactly the same amount at the
-- same step or ANY later step (no upper time limit), and keep the earliest.
--
-- Flagged transfers are classified first. They were stopped: their origin
-- balance never moved, and the simulator records a fraudulent cash out of 0
-- in the same hour. A few of them carry a 10,000,000 amount, which collides
-- with other chains, so amount matching alone would wrongly count them.
WITH fraud_transfers AS (
  SELECT step, nameOrig, nameDest, amount, isFlaggedFraud
  FROM paysim.cleaned_transactions
  WHERE type = 'TRANSFER' AND isFraud = 1
),
fraud_cashouts AS (
  SELECT DISTINCT step, amount
  FROM paysim.cleaned_transactions
  WHERE type = 'CASH_OUT' AND isFraud = 1
),
per_transfer AS (
  SELECT
    t.step, t.nameOrig, t.nameDest, t.amount, t.isFlaggedFraud,
    MIN(c.step - t.step) AS hours_to_cashout
  FROM fraud_transfers t
  LEFT JOIN fraud_cashouts c
    ON c.amount = t.amount
   AND c.step >= t.step
  GROUP BY t.step, t.nameOrig, t.nameDest, t.amount, t.isFlaggedFraud
),
classified AS (
  SELECT
    CASE
      WHEN isFlaggedFraud = 1        THEN 'b. Stopped by existing control'
      WHEN hours_to_cashout IS NULL  THEN 'c. No matching cash out'
      WHEN hours_to_cashout = 0      THEN 'a. Cashed out in the same hour'
      ELSE                                'a2. Cashed out in a later hour'
    END AS outcome,
    CASE WHEN isFlaggedFraud = 1 THEN NULL ELSE hours_to_cashout END
      AS hours_to_cashout,
    amount
  FROM per_transfer
)
SELECT
  outcome,
  hours_to_cashout,
  COUNT(*) AS transfers,
  ROUND(SUM(amount), 2) AS transfer_value,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS share_of_transfers_pct
FROM classified
GROUP BY outcome, hours_to_cashout
ORDER BY outcome;


-- Export -> data/q2_flows.csv
-- The two legs of the chain, used by the dashboard flow strip.
SELECT 'Victim account' AS source_channel,
       'Mule account'   AS target_channel,
       1                AS leg_order,
       COUNT(*)         AS transaction_count,
       ROUND(SUM(amount), 2) AS volume
FROM paysim.cleaned_transactions
WHERE isFraud = 1 AND type = 'TRANSFER'
UNION ALL
SELECT 'Mule account', 'Cash out exit', 2, COUNT(*), ROUND(SUM(amount), 2)
FROM paysim.cleaned_transactions
WHERE isFraud = 1 AND type = 'CASH_OUT'
ORDER BY leg_order;
