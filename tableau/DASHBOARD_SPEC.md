# Tableau Dashboard Build Notes
### PaySim Fraud Chain and Velocity: Executive Dashboard

Fixed size 1400 x 1000 px. Audience: fraud operations and risk leadership.

Every number on the dashboard comes from a CSV in `data/`. No values are typed in except the four KPI tiles, and each of those is copied from the file named below.

---

## Data sources

| Source | File | Used by |
|---|---|---|
| A | `q2_flows.csv` | Flow strip |
| B | `hourly_fraud.csv` | Hourly chart |
| C | `q4_rule_performance.csv` | Rule scatter |
| D | `q2_chain_outcomes.csv` | Chain outcome chart |

Keep them as separate connections. No joins are needed.

---

## Row 1: KPI tiles

| Value | Label | Source |
|---|---|---|
| 6.07B | Fraudulent transfer value (local currency) | `q1_headline.csv`, transfer_value |
| 98.7% | Cash out value as a share of transfer value | `q1_headline.csv`, cashout_to_transfer_value_pct |
| 99.46% | Fraudulent transfers cashed out within the same hour | `q2_chain_outcomes.csv`, share_of_transfers_pct |
| 0.19% | Fraudulent rows flagged by the existing control | `q1_headline.csv`, overall_recall_pct |

No currency symbol: the dataset does not name its currency.

## Row 2: Flow strip

Horizontal stacked bar from source A, one segment per leg, sorted by `leg_order`. Title: *Two legs, one pot of money. 6.07B transferred, 5.99B cashed out.*

## Row 3, left: Chain outcomes

Horizontal bar from source D: `transfers` by outcome, labelled with `share_of_transfers_pct`. One highlight colour for the same hour bar, grey for the rest. Title: *99.46% cashed out within the same hour*. Caption: *One row per transfer, matched to the earliest same amount cash out with no time limit.*

## Row 3, right: Hourly volume

Two panes on separate axes, no dual axis: `SUM(fraud_tx)` above, `SUM(legit_tx)` below, by `hour_of_day` 0 to 23. Title: *The overnight spike is a denominator effect, not a fraud surge.*

## Row 4: Rule trade off

Scatter from source C: `recall_pct` against `precision_pct`, size by `alerts`, shape by `uses_balance_columns`, label by `rule_name`. Axes fixed 0 to 100. Title: *The two near perfect rules are both simulation artifacts.*

## Footer

*Source: PaySim synthetic dataset (Kaggle, CC BY-SA 4.0). Analysis: BigQuery, R, Tableau. All rates computed within TRANSFER and CASH_OUT only.*
