-- =============================================================================
-- sql/07_rule_performance.sql
-- Objective: score every candidate rule on alerts, precision and recall.
--
-- A rule with high recall and tiny precision is unusable in production, so
-- alert volume is reported for every rule. Each rule is also labelled with
-- whether it reads the balance columns the dataset owner says not to use.
--
-- Scope: rules A to D and F run on both fraud legs (8,213 fraudulent rows).
-- Rule E only fires on CASH_OUT, so its recall is measured against the
-- 4,116 fraudulent cash outs.
-- =============================================================================


-- Export -> data/q4_rule_performance.csv
WITH transfer_keys AS (
  -- Every TRANSFER, fraudulent or not: the rule cannot see the label
  SELECT DISTINCT step, amount, 1 AS has_transfer
  FROM paysim.cleaned_transactions
  WHERE type = 'TRANSFER'
),
scored AS (
  SELECT
    c.type,
    c.isFraud,
    c.isFlaggedFraud AS rule_a,
    c.is_orig_drained AS rule_b,
    CASE WHEN c.amount >= 1000000 THEN 1 ELSE 0 END AS rule_c,
    CASE WHEN c.is_orig_drained = 1 AND c.amount >= 1000000 THEN 1 ELSE 0 END AS rule_d,
    CASE WHEN c.type = 'CASH_OUT' AND k.has_transfer = 1 THEN 1 ELSE 0 END AS rule_e,
    CASE WHEN c.oldbalanceOrg > 0 AND c.amount = c.oldbalanceOrg THEN 1 ELSE 0 END AS rule_f
  FROM paysim.cleaned_transactions c
  LEFT JOIN transfer_keys k
    ON k.step = c.step AND k.amount = c.amount
  WHERE c.type IN ('TRANSFER', 'CASH_OUT')
),
metrics AS (
  SELECT 'A. Fixed threshold (current control)' AS rule_name, 'no' AS uses_balance_columns,
         COUNTIF(isFraud = 1) AS fraud_in_scope,
         COUNTIF(rule_a = 1) AS alerts, COUNTIF(rule_a = 1 AND isFraud = 1) AS true_positives
  FROM scored
  UNION ALL
  SELECT 'B. Account draining only', 'yes', COUNTIF(isFraud = 1),
         COUNTIF(rule_b = 1), COUNTIF(rule_b = 1 AND isFraud = 1) FROM scored
  UNION ALL
  SELECT 'C. High value only (1M and over)', 'no', COUNTIF(isFraud = 1),
         COUNTIF(rule_c = 1), COUNTIF(rule_c = 1 AND isFraud = 1) FROM scored
  UNION ALL
  SELECT 'D. Draining AND high value', 'yes', COUNTIF(isFraud = 1),
         COUNTIF(rule_d = 1), COUNTIF(rule_d = 1 AND isFraud = 1) FROM scored
  UNION ALL
  SELECT 'E. Cash out mirrors a transfer in the same hour', 'no',
         COUNTIF(isFraud = 1 AND type = 'CASH_OUT'),
         COUNTIF(rule_e = 1), COUNTIF(rule_e = 1 AND isFraud = 1) FROM scored
  UNION ALL
  SELECT 'F. Amount equals origin balance (leakage check)', 'yes', COUNTIF(isFraud = 1),
         COUNTIF(rule_f = 1), COUNTIF(rule_f = 1 AND isFraud = 1) FROM scored
)
SELECT
  rule_name,
  uses_balance_columns,
  fraud_in_scope,
  alerts,
  true_positives,
  alerts - true_positives AS false_positives,
  ROUND(SAFE_DIVIDE(true_positives, alerts) * 100, 2) AS precision_pct,
  ROUND(SAFE_DIVIDE(true_positives, fraud_in_scope) * 100, 2) AS recall_pct,
  ROUND(SAFE_DIVIDE(alerts, NULLIF(true_positives, 0)), 1) AS alerts_per_catch
FROM metrics
ORDER BY rule_name;


-- Export -> data/q3_amount_lift.csv
-- Fraud rate and lift by amount band against the overall baseline.
WITH banded AS (
  SELECT
    CASE
      WHEN amount <    1000 THEN 'a. under 1K'
      WHEN amount <   10000 THEN 'b. 1K to 10K'
      WHEN amount <  100000 THEN 'c. 10K to 100K'
      WHEN amount < 1000000 THEN 'd. 100K to 1M'
      ELSE                       'e. 1M and over'
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
  ROUND(ANY_VALUE(base.baseline_rate) * 100, 3) AS baseline_rate_pct,
  ROUND(SAFE_DIVIDE(SAFE_DIVIDE(COUNTIF(b.isFraud = 1), COUNT(*)),
                    ANY_VALUE(base.baseline_rate)), 2) AS lift_vs_baseline
FROM banded b CROSS JOIN base
GROUP BY b.amount_band
ORDER BY b.amount_band;


-- Export -> data/q4_rule_by_hour.csv
-- The same amount rule (C) scored overnight and in the daytime. Uses no
-- balance columns. Hour bands assume step 1 starts at 00:00.
SELECT
  CASE WHEN hour_of_day <= 6 THEN 'a. 00:00 to 06:59' ELSE 'b. 07:00 to 23:59' END
    AS hour_band,
  COUNT(*) AS txns,
  COUNTIF(isFraud = 1) AS fraud_txns,
  COUNTIF(amount >= 1000000) AS rule_c_alerts,
  COUNTIF(amount >= 1000000 AND isFraud = 1) AS rule_c_true_positives,
  ROUND(SAFE_DIVIDE(COUNTIF(amount >= 1000000 AND isFraud = 1),
                    COUNTIF(amount >= 1000000)) * 100, 2) AS rule_c_precision_pct
FROM paysim.cleaned_transactions
WHERE type IN ('TRANSFER', 'CASH_OUT')
GROUP BY hour_band
ORDER BY hour_band;
