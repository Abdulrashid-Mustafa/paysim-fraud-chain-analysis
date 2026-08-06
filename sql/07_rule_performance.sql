-- =============================================================================
-- sql/07_rule_performance.sql
-- Purpose : Test each proposed detection rule on its own, then combined, and
--           report precision, recall and alert volume for each.
--
-- Why this matters: a rule with 97% recall and 0.7% precision is unusable in
-- production. Any recommendation that does not report false positive volume
-- is incomplete. This query produces the evidence for README section 6.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Export -> data/q4_rule_performance.csv
-- -----------------------------------------------------------------------------

WITH scored AS (
  SELECT
    isFraud,
    -- Rule A: existing control (fixed monetary threshold)
    isFlaggedFraud AS rule_threshold,

    -- Rule B: account draining
    is_orig_drained AS rule_draining,

    -- Rule C: high value band (over 1M, the only band with real lift)
    CASE WHEN amount >= 1000000 THEN 1 ELSE 0 END AS rule_high_value,

    -- Rule D: draining AND high value combined
    CASE WHEN is_orig_drained = 1 AND amount >= 1000000
         THEN 1 ELSE 0 END AS rule_combined
  FROM paysim.cleaned_transactions
  WHERE type IN ('TRANSFER', 'CASH_OUT')
),

metrics AS (
  SELECT 'A. Fixed threshold (current control)' AS rule_name,
         COUNTIF(rule_threshold = 1) AS alerts,
         COUNTIF(rule_threshold = 1 AND isFraud = 1) AS true_positives,
         COUNTIF(rule_threshold = 1 AND isFraud = 0) AS false_positives
  FROM scored
  UNION ALL
  SELECT 'B. Account draining only',
         COUNTIF(rule_draining = 1),
         COUNTIF(rule_draining = 1 AND isFraud = 1),
         COUNTIF(rule_draining = 1 AND isFraud = 0)
  FROM scored
  UNION ALL
  SELECT 'C. High value only (>= 1M)',
         COUNTIF(rule_high_value = 1),
         COUNTIF(rule_high_value = 1 AND isFraud = 1),
         COUNTIF(rule_high_value = 1 AND isFraud = 0)
  FROM scored
  UNION ALL
  SELECT 'D. Draining AND high value',
         COUNTIF(rule_combined = 1),
         COUNTIF(rule_combined = 1 AND isFraud = 1),
         COUNTIF(rule_combined = 1 AND isFraud = 0)
  FROM scored
)

SELECT
  rule_name,
  alerts,
  true_positives,
  false_positives,
  ROUND(SAFE_DIVIDE(true_positives, alerts) * 100, 3) AS precision_pct,
  ROUND(SAFE_DIVIDE(true_positives, 8213) * 100, 2)   AS recall_pct,
  ROUND(SAFE_DIVIDE(alerts, NULLIF(true_positives, 0)), 1) AS alerts_per_catch
FROM metrics
ORDER BY rule_name;


-- -----------------------------------------------------------------------------
-- Supporting query -> data/q3_amount_lift.csv
-- Fraud rate and lift by amount band. Shows that amount is not useless: the
-- over-1M band carries roughly 7x the baseline fraud rate, which is what makes
-- it a viable second condition alongside the draining signal.
-- -----------------------------------------------------------------------------

WITH banded AS (
  SELECT
    CASE
      WHEN amount <    1000 THEN 'a. under 1K'
      WHEN amount <   10000 THEN 'b. 1K to 10K'
      WHEN amount <  100000 THEN 'c. 10K to 100K'
      WHEN amount < 1000000 THEN 'd. 100K to 1M'
      ELSE                       'e. over 1M'
    END AS amount_band,
    isFraud
  FROM paysim.cleaned_transactions
  WHERE type IN ('TRANSFER', 'CASH_OUT')
),
base AS (
  SELECT SAFE_DIVIDE(COUNTIF(isFraud = 1), COUNT(*)) AS baseline_rate FROM banded
)

SELECT
  b.amount_band,
  COUNT(*) AS txns,
  COUNTIF(b.isFraud = 1) AS fraud_txns,
  ROUND(SAFE_DIVIDE(COUNTIF(b.isFraud = 1), COUNT(*)) * 100, 3) AS fraud_rate_pct,
  ROUND(SAFE_DIVIDE(SAFE_DIVIDE(COUNTIF(b.isFraud = 1), COUNT(*)),
                    ANY_VALUE(base.baseline_rate)), 2) AS lift_vs_baseline
FROM banded b CROSS JOIN base
GROUP BY b.amount_band
ORDER BY b.amount_band;


-- -----------------------------------------------------------------------------
-- Note on avg_drained_ratio
--
-- The average drained ratio for legitimate transactions came back as 277.37,
-- which is not a meaningful average. It is inflated by rows where
-- oldbalanceOrg is near zero, making amount/oldbalanceOrg explode. Use the
-- median instead, and report it that way in the README.
-- -----------------------------------------------------------------------------

SELECT
  isFraud,
  ROUND(APPROX_QUANTILES(SAFE_DIVIDE(amount, NULLIF(oldbalanceOrg, 0)), 100)[OFFSET(50)], 4)
    AS median_drained_ratio,
  ROUND(APPROX_QUANTILES(SAFE_DIVIDE(amount, NULLIF(oldbalanceOrg, 0)), 100)[OFFSET(90)], 4)
    AS p90_drained_ratio
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
  AND oldbalanceOrg > 0
GROUP BY isFraud
ORDER BY isFraud DESC;