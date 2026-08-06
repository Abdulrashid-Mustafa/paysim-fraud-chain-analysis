-- =============================================================================
-- sql/04_q2_fraud_chain.sql
-- Objective: Q2 - Reconstruct the TRANSFER to CASH_OUT chain and measure how
--            long the money stays in the mule account before it exits.
--
-- Export result set 2 -> data/q2_chains.csv
-- Export result set 3 -> data/q2_flows.csv
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Result 1: FEASIBILITY CHECK. Run this before anything else.
--
-- The intuitive approach is to link the nameDest of a fraudulent TRANSFER to
-- the nameOrig of a fraudulent CASH_OUT. In PaySim that linkage does not hold:
-- the simulation generates the two legs as paired events but does not carry the
-- account identity across them. This query proves it rather than assuming it,
-- and the result is reported as a limitation in the README.
-- -----------------------------------------------------------------------------

SELECT COUNT(*) AS name_linked_accounts
FROM (
  SELECT DISTINCT nameDest AS acct
  FROM paysim.cleaned_transactions
  WHERE type = 'TRANSFER' AND isFraud = 1
) t
JOIN (
  SELECT DISTINCT nameOrig AS acct
  FROM paysim.cleaned_transactions
  WHERE type = 'CASH_OUT' AND isFraud = 1
) c
USING (acct);


-- -----------------------------------------------------------------------------
-- Result 2 -> data/q2_chains.csv
--
-- Because account name linkage fails, chains are matched on amount equality
-- within a one hour window. This over matches by roughly 5% (4,308 matches
-- against 4,097 fraudulent transfers) where two chains share an amount in the
-- same window. The over match is disclosed in the README rather than hidden.
-- -----------------------------------------------------------------------------

WITH fraud_transfers AS (
  SELECT step, nameOrig AS victim_account, nameDest AS transfer_destination,
         amount, sim_day, hour_of_day
  FROM paysim.cleaned_transactions
  WHERE type = 'TRANSFER' AND isFraud = 1
),
fraud_cashouts AS (
  SELECT step, nameOrig AS cashout_account, nameDest AS cashout_destination,
         amount, sim_day, hour_of_day
  FROM paysim.cleaned_transactions
  WHERE type = 'CASH_OUT' AND isFraud = 1
)
SELECT
  t.sim_day     AS transfer_day,
  t.hour_of_day AS transfer_hour,
  (c.step - t.step) AS hours_to_cashout,
  COUNT(*) AS chain_count,
  ROUND(SUM(t.amount), 2) AS total_chained_amount,
  ROUND(AVG(t.amount), 2) AS avg_chain_amount
FROM fraud_transfers t
JOIN fraud_cashouts c
  ON t.amount = c.amount
 AND c.step >= t.step
 AND c.step <= t.step + 1
GROUP BY 1, 2, 3
ORDER BY hours_to_cashout ASC, chain_count DESC;


-- -----------------------------------------------------------------------------
-- Result 3 -> data/q2_flows.csv
--
-- Models the two real legs of the chain. An earlier version hardcoded
-- 'CASH_OUT' as the target for every row, which produced a meaningless
-- CASH_OUT to CASH_OUT self loop on the dashboard.
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
