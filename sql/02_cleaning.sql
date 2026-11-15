-- =============================================================================
-- sql/02_cleaning.sql
-- Objective: build paysim.cleaned_transactions with time and ledger features.
--
-- No rows are dropped. The drained ratio (amount / oldbalanceOrg) is not
-- stored, because it explodes when the origin balance is near zero. It is
-- computed at query time and reported as a median.
--
-- Important: the dataset owner states that fraud transactions are cancelled
-- in the simulation and that the four balance columns must not be used for
-- fraud detection. The balance features below are kept so that this effect
-- can be measured and disclosed (see sql/06), not to build a production rule.
-- =============================================================================

CREATE OR REPLACE TABLE paysim.cleaned_transactions AS
SELECT
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

  -- Time mapping. step is a linear hour counter starting at 1.
  -- Treating step 1 as 00:00 is an assumption: the source does not state the
  -- clock time of the first step, but the daily volume cycle supports it.
  CAST(FLOOR((step - 1) / 24) + 1 AS INT64) AS sim_day,
  MOD(step - 1, 24)                         AS hour_of_day,

  -- Origin balance reported as fully emptied
  CASE WHEN oldbalanceOrg > 0 AND newbalanceOrig = 0 THEN 1 ELSE 0 END
    AS is_orig_drained,

  -- Ledger consistency: expected balance minus reported balance
  ROUND((oldbalanceOrg - amount) - newbalanceOrig, 2) AS orig_balance_error,
  ROUND((oldbalanceDest + amount) - newbalanceDest, 2) AS dest_balance_error

FROM paysim.raw_transactions;


-- Verification: row count unchanged and derived columns inside their bounds.
SELECT
  COUNT(*)         AS total_rows,   -- 6,362,620
  MIN(sim_day)     AS min_day,      -- 1
  MAX(sim_day)     AS max_day,      -- 31
  MIN(hour_of_day) AS min_hour,     -- 0
  MAX(hour_of_day) AS max_hour      -- 23
FROM paysim.cleaned_transactions;
