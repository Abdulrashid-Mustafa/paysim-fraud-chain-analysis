-- =============================================================================
-- sql/08_validation_checks.sql
-- Objective: one file of reconciliation checks behind the README claims,
--            including why the earlier chain method was replaced.
-- =============================================================================


-- Export -> data/validation_checks.csv
WITH ft AS (
  SELECT step, amount FROM paysim.cleaned_transactions
  WHERE type = 'TRANSFER' AND isFraud = 1
),
fc AS (
  SELECT step, amount FROM paysim.cleaned_transactions
  WHERE type = 'CASH_OUT' AND isFraud = 1
),
old_join AS (
  -- The earlier method: raw join rows inside a one hour window
  SELECT ft.amount, fc.step - ft.step AS lag
  FROM ft JOIN fc
    ON fc.amount = ft.amount AND fc.step >= ft.step AND fc.step <= ft.step + 1
)
SELECT 'total_rows' AS check_name, CAST(COUNT(*) AS FLOAT64) AS check_value,
       'Rows in the raw file' AS note
FROM paysim.cleaned_transactions
UNION ALL
SELECT 'distinct_steps', CAST(COUNT(DISTINCT step) AS FLOAT64),
       'The source says 744, the file holds 743'
FROM paysim.cleaned_transactions
UNION ALL
SELECT 'transfer_and_cashout_rows', CAST(COUNTIF(type IN ('TRANSFER', 'CASH_OUT')) AS FLOAT64),
       'Denominator for every rate'
FROM paysim.cleaned_transactions
UNION ALL
SELECT 'fraud_legs', CAST(COUNTIF(isFraud = 1) AS FLOAT64), 'Fraudulent TRANSFER plus CASH_OUT rows'
FROM paysim.cleaned_transactions
UNION ALL
SELECT 'name_linked_accounts', CAST(COUNT(*) AS FLOAT64),
       'Transfer destinations that later start a fraudulent cash out'
FROM (SELECT DISTINCT nameDest AS acct FROM paysim.cleaned_transactions
      WHERE type = 'TRANSFER' AND isFraud = 1) t
JOIN (SELECT DISTINCT nameOrig AS acct FROM paysim.cleaned_transactions
      WHERE type = 'CASH_OUT' AND isFraud = 1) c USING (acct)
UNION ALL
SELECT 'old_method_join_rows', CAST(COUNT(*) AS FLOAT64),
       'Earlier chain count: join rows, not distinct chains'
FROM old_join
UNION ALL
SELECT 'old_method_matched_value', ROUND(SUM(amount), 2),
       'Larger than all fraudulent transfer value, proof of duplicate matches'
FROM old_join
UNION ALL
SELECT 'old_method_later_hour_rows', CAST(COUNTIF(lag = 1) AS FLOAT64),
       'Rows the earlier chart showed as cashed out one hour later'
FROM old_join
UNION ALL
SELECT 'old_method_later_hour_rows_at_10M', CAST(COUNTIF(lag = 1 AND amount = 10000000) AS FLOAT64),
       'All of them carry the 10,000,000 amount, so they are collisions'
FROM old_join
UNION ALL
SELECT 'fraud_transfers_at_10M', CAST(COUNTIF(amount = 10000000) AS FLOAT64),
       'Fraudulent transfers of exactly 10,000,000'
FROM ft
UNION ALL
SELECT 'legit_rows_amount_equals_balance',
       CAST(COUNTIF(isFraud = 0 AND oldbalanceOrg > 0 AND amount = oldbalanceOrg) AS FLOAT64),
       'Legitimate rows that move exactly the origin balance'
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
UNION ALL
SELECT 'legit_drained_rows', CAST(COUNTIF(isFraud = 0 AND is_orig_drained = 1) AS FLOAT64),
       'Legitimate rows reported as emptying the origin balance'
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
UNION ALL
SELECT 'legit_drained_rows_amount_above_balance',
       CAST(COUNTIF(isFraud = 0 AND is_orig_drained = 1 AND amount > oldbalanceOrg) AS FLOAT64),
       'Of those, rows whose amount exceeds the balance: a ledger inconsistency'
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT');
