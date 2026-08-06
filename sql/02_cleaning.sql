-- =============================================================================
-- sql/02_cleaning.sql
-- Objective: Build paysim.cleaned_transactions with engineered behavioural
--            and ledger features.
--
-- IMPORTANT: the column names below match the table that the rest of this
-- repository queries. An earlier version of this script created columns named
-- is_orig_fully_drained / orig_drained_ratio / orig_balance_discrepancy, which
-- do not match the live table and would break scripts 05 to 07. Use this file.
--
-- The drained ratio is deliberately NOT stored. Ratios computed against near
-- zero origin balances explode (the legitimate mean comes out above 277), so
-- the metric is only meaningful as a median on rows where oldbalanceOrg > 0.
-- It is therefore computed at query time in 06 and 07.
-- =============================================================================

CREATE OR REPLACE TABLE paysim.cleaned_transactions AS
SELECT
  -- 1. Base transactional columns
  step,
  type,
  amount,
  nameOrig,
  oldbalanceOrg,
  newbalanceOrig,
  nameDest,
  oldbalanceDest,
  newbalanceDest,
  isFraud,
  isFlaggedFraud,

  -- 2. Time mapping: linear step hours to simulated day and hour of day
  CAST(FLOOR((step - 1) / 24) + 1 AS INT64) AS sim_day,
  MOD(step - 1, 24) AS hour_of_day,

  -- 3. Behavioural feature: complete liquidation of the origin balance
  CASE
    WHEN oldbalanceOrg > 0 AND newbalanceOrig = 0 THEN 1
    ELSE 0
  END AS is_orig_drained,

  -- 4. Ledger consistency: expected balance minus reported balance
  ROUND((oldbalanceOrg - amount) - newbalanceOrig, 2) AS orig_balance_error,
  ROUND((oldbalanceDest + amount) - newbalanceDest, 2) AS dest_balance_error

FROM paysim.raw_transactions;


-- -----------------------------------------------------------------------------
-- Verification: row count must match the raw table, and the derived time
-- columns must fall inside their expected bounds.
-- -----------------------------------------------------------------------------

SELECT
  COUNT(*) AS total_rows,          -- expect 6,362,620
  MIN(sim_day) AS min_day,         -- expect 1
  MAX(sim_day) AS max_day,         -- expect 31
  MIN(hour_of_day) AS min_hour,    -- expect 0
  MAX(hour_of_day) AS max_hour     -- expect 23
FROM paysim.cleaned_transactions;
