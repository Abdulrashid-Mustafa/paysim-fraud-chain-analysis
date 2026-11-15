# Data Dictionary: PaySim Dataset

## Source columns

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `step` | INTEGER | Unit of time in hours (1 step = 1 hour). The source says 744 steps. The file holds 743 (1 to 743), covering 31 simulated days. |
| `type` | STRING | Transaction type (`PAYMENT`, `TRANSFER`, `CASH_OUT`, `DEBIT`, `CASH_IN`). |
| `amount` | FLOAT | Amount of the transaction in local currency. The currency is not named. |
| `nameOrig` | STRING | Customer ID who started the transaction. |
| `oldbalanceOrg` | FLOAT | Origin balance before the transaction. Not valid for fraud detection (see note). |
| `newbalanceOrig` | FLOAT | Origin balance after the transaction. Not valid for fraud detection (see note). |
| `nameDest` | STRING | Recipient account ID (customer or merchant). |
| `oldbalanceDest` | FLOAT | Destination balance before the transaction. Not available for merchants. Not valid for fraud detection. |
| `newbalanceDest` | FLOAT | Destination balance after the transaction. Not available for merchants. Not valid for fraud detection. |
| `isFraud` | INTEGER | Ground truth label: 1 for transactions made by the fraudulent agents in the simulation, 0 otherwise. |
| `isFlaggedFraud` | INTEGER | Existing control flag. Documented as firing on transfers above 200,000, but it fired on only 16 of 409,110 such transfers. |

**Note on the balance columns.** The dataset description states that fraud transactions are cancelled in the simulation and that the four balance columns must not be used for fraud detection. This project measures that effect in `data/q3_balance_artifacts.csv` and does not recommend any rule built on them.

## Engineered columns in `paysim.cleaned_transactions`

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `sim_day` | INTEGER | Simulated day 1 to 31, derived from `step`. |
| `hour_of_day` | INTEGER | Hour of day 0 to 23, derived from `step`, assuming step 1 starts at 00:00. |
| `is_orig_drained` | INTEGER | 1 when `oldbalanceOrg > 0` and `newbalanceOrig = 0`, meaning the origin balance is reported as emptied. |
| `orig_balance_error` | FLOAT | `(oldbalanceOrg - amount) - newbalanceOrig`. Non zero values indicate ledger inconsistency. |
| `dest_balance_error` | FLOAT | `(oldbalanceDest + amount) - newbalanceDest`. Same purpose for the destination account. |

The drained ratio (`amount / oldbalanceOrg`) is not stored. Ratios against near zero balances explode, so it is computed at query time and reported as a median.

## Exported files in `data/`

| File | Produced by | Contents |
| :--- | :--- | :--- |
| `q1_value_control.csv` | sql/03 | Value, fraud and flag counts by type |
| `q1_headline.csv` | sql/03 | Transfer and cash out value, legs, flag recall |
| `q1_flag_behaviour.csv` | sql/03 | How the existing flag actually behaves |
| `q2_chain_outcomes.csv` | sql/04 | Outcome of each fraudulent transfer, one row per transfer |
| `q2_flows.csv` | sql/04 | The two legs of the chain, for the dashboard |
| `q3_amount_summary.csv` | sql/05 | Average and median amount by type and class |
| `hourly_fraud.csv` | sql/05 | Fraud and legitimate rows by hour of day |
| `daily_fraud.csv` | sql/05 | Fraud and legitimate rows by simulated day |
| `q3_draining_signal.csv` | sql/06 | Share of rows reported as draining the origin balance |
| `q3_balance_artifacts.csv` | sql/06 | How the simulator writes balances for each class |
| `q3_drain_ratio.csv` | sql/06 | Median and 90th percentile of amount over origin balance |
| `q3_amount_buckets.csv` | sql/06 | Count and value by amount band and class |
| `q3_ledger_anomalies.csv` | sql/06 | Zero balance rows and balance errors by type |
| `q4_rule_performance.csv` | sql/07 | Alerts, precision and recall for rules A to F |
| `q3_amount_lift.csv` | sql/07 | Fraud rate and lift by amount band |
| `q4_rule_by_hour.csv` | sql/07 | The amount rule scored overnight and in the daytime |
| `validation_checks.csv` | sql/08 | Reconciliation checks behind the README claims |
