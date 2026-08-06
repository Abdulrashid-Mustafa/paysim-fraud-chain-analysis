# Data Dictionary: PaySim Dataset

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `step` | INTEGER | Unit of time in hours (1 step = 1 hour). Total 744 steps (~30 days). |
| `type` | STRING | Transaction type (`PAYMENT`, `TRANSFER`, `CASH_OUT`, `DEBIT`, `CASH_IN`). |
| `amount` | FLOAT | Amount of the transaction in local currency. |
| `nameOrig` | STRING | Customer ID who initiated the transaction. |
| `oldbalanceOrg` | FLOAT | Initial balance of origin account before transaction. |
| `newbalanceOrig` | FLOAT | New balance of origin account after transaction. |
| `nameDest` | STRING | Recipient account ID (Customer or Merchant). |
| `oldbalanceDest` | FLOAT | Initial balance of destination account before transaction (Not available for merchants). |
| `newbalanceDest` | FLOAT | New balance of destination account after transaction (Not available for merchants). |
| `isFraud` | INTEGER | Ground truth flag indicating fraud (1 = Fraud, 0 = Legitimate). |
| `isFlaggedFraud` | INTEGER | System control flag for illegal attempt (1 = Flagged, transfers > 200k). |
## Engineered columns in `paysim.cleaned_transactions`

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `sim_day` | INTEGER | Simulated day 1 to 31, derived from `step`. |
| `hour_of_day` | INTEGER | Hour of day 0 to 23, derived from `step`. |
| `is_orig_drained` | INTEGER | 1 when `oldbalanceOrg > 0` and `newbalanceOrig = 0`, meaning the origin balance was fully liquidated. |
| `orig_balance_error` | FLOAT | `(oldbalanceOrg - amount) - newbalanceOrig`. Non zero values indicate ledger inconsistency in the source data. |
| `dest_balance_error` | FLOAT | `(oldbalanceDest + amount) - newbalanceDest`. Same purpose for the destination account. |

Note: the drained ratio (`amount / oldbalanceOrg`) is deliberately not stored as a column. Ratios against near zero balances explode, so it is computed at query time and reported as a median rather than a mean.
