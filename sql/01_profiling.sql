-- sql/01_profiling.sql
-- Goal: Data Profiling & Initial Inspection for PaySim Dataset

-- 1. Total records and time coverage check
SELECT 
    COUNT(*) AS total_transactions,
    MIN(step) AS min_step,
    MAX(step) AS max_step,
    COUNT(DISTINCT step) AS unique_steps
FROM `paysim.raw_transactions`;

-- 2. Transaction types breakdown with fraud distribution
SELECT 
    type,
    COUNT(*) AS transaction_count,
    SUM(isFraud) AS fraud_count,
    SUM(isFlaggedFraud) AS flagged_fraud_count,
    ROUND(SUM(isFraud) * 100.0 / COUNT(*), 4) AS fraud_rate_pct
FROM `paysim.raw_transactions`
GROUP BY type
ORDER BY transaction_count DESC;

-- 3. Balance anomaly inspection (Check for 0 balance destination accounts)
SELECT 
    type,
    COUNT(*) AS total_count,
    COUNTIF(oldbalanceOrg = 0 AND newbalanceOrig = 0) AS zero_orig_balances,
    COUNTIF(oldbalanceDest = 0 AND newbalanceDest = 0) AS zero_dest_balances
FROM `paysim.raw_transactions`
GROUP BY type;