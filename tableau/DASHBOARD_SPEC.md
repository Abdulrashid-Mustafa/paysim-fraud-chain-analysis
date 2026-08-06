# Tableau Dashboard Build Specification
### PaySim Fraud Chain and Velocity: Executive Dashboard

Target size: 1400 x 1000 px, fixed. Audience: fraud operations and risk leadership, non technical.

---

## Data sources to connect

Connect these four CSVs from `data/`. Do not connect to the 6.36M row raw table, the dashboard needs none of it.

| Source | File | Used by |
|---|---|---|
| A | `q2_flows.csv` | Flow strip |
| B | `hourly_fraud.csv` | Hourly chart |
| C | `q4_rule_performance.csv` | Rule scatter, KPI |
| D | `q2_chains.csv` | Velocity chart |

Keep them as four separate connections. No joins are needed and joining them will produce wrong row multiplication.

---

## Row 1: KPI band

Four text tiles across the top, no borders, dark grey label above a large black value.

| Tile | Value | Label beneath |
|---|---|---|
| 1 | **$6.07B** | Customer funds targeted |
| 2 | **98.7%** | Successfully liquidated |
| 3 | **99.2%** | Cashed out within the same hour |
| 4 | **0.19%** | Caught by the existing control |

Build each as a blank worksheet with a single text mark, or as four floating text objects. Do not use the raw sum of fraud amount, since adding both legs double counts the money. Type these values directly and note the source query in the tooltip.

**Critical:** remove the old KPI reading `Total Fraud Volume: $12.06B`. That figure double counts the two legs.

---

## Row 2: The fraud chain

**Chart type:** horizontal stacked bar, one row, acting as a flow strip.

- Source: A (`q2_flows.csv`)
- Columns: `SUM(volume)`
- Colour: `source_channel`
- Sort by `leg_order` ascending
- Label: `source_channel` + " → " + `target_channel`, with volume formatted as $#.##B

The result reads: **Victim account → Mule account ($6.07B)** then **Mule account → Cash-out exit ($5.99B)**.

If you want the true Sankey later, this strip is the honest interim. It is better to ship a correct bar than a decorative Sankey built on a broken flow table.

**Critical:** the previous version showed `CASH_OUT → CASH_OUT`, which is a meaningless self loop. Confirm the new file is connected before publishing.

Title: **Two legs, one pot of money. $6.07B targeted, $5.99B out the door.**

---

## Row 3, left: Cash out velocity

**Chart type:** vertical bar, two bars only.

- Source: D (`q2_chains.csv`)
- Columns: `hours_to_cashout` (discrete dimension)
- Rows: `SUM(chain_count)`
- Label each bar with percent of total: 99.2% and 0.8%
- Colour: single blue, no gradient

Title: **Nothing takes longer than an hour**
Subtitle: Elapsed time between the fraudulent transfer and its matching cash out

Caption at the bottom of the tile: *Chains matched on amount within a one hour window: 4,308 matches against 4,097 fraudulent transfers, a 5% over match.*

---

## Row 3, right: Hourly signal to noise

**Chart type:** dual axis, bar plus line.

- Source: B (`hourly_fraud.csv`)
- Columns: `hour_of_day` (continuous, 0 to 23)
- Rows, axis 1: `SUM(fraud_tx)` as **bars**, grey
- Rows, axis 2: `AVG(fraud_rate_pct)` as **line**, red
- Right click the axis → Synchronise is OFF. These are different units.
- Fix the x axis to 0 to 23. The current dashboard shows -2 to 24, which is not a valid hour range.

Title: **The overnight spike is a denominator effect, not a fraud surge**
Subtitle: Fraud volume is flat at 274 to 375 cases per hour. Legitimate volume collapses overnight.

This dual axis is the single most important fix on the dashboard. The bar and the line together make the point that neither makes alone.

---

## Row 4: Rule trade off

**Chart type:** scatter plot.

- Source: C (`q4_rule_performance.csv`)
- Columns: `recall_pct`
- Rows: `precision_pct`
- Size: `alerts`
- Label: `rule_name`
- Tooltip: alerts, true positives, false positives, alerts per catch
- Fix both axes with padding so labels do not clip: x from -8 to 118, y from -12 to 130

Title: **No single rule is production ready**
Subtitle: Precision against recall for each candidate rule, sized by alert volume

This is the chart that separates the project from a student exercise. Most portfolio dashboards show what a signal catches. This one shows what it costs.

---

## Remove or fix

| Item | Action |
|---|---|
| `Total Fraud Volume: $12.06B` | Delete. Replace with the four KPI tiles above. |
| `CASH_OUT → CASH_OUT` flow bar | Delete. Reconnect to the new `q2_flows.csv`. |
| Daily Fraud Trend with the 100% spike | Either delete, or keep and grey out the 13 artifact days with a caption reading *Days with near zero legitimate volume are simulation artifacts, not trends.* |
| Hourly x axis showing -2 and 24 | Fix to 0 through 23. |

---

## Formatting

- Font: Tableau Book throughout. Titles bold 16, subtitles regular 11 grey, body 10.
- Colour: one red for fraud (#E15759), one blue for volume (#4E79A7), grey for context (#B0B7BE). Nothing else.
- Remove all gradient colour legends. They add nothing here and read as decoration.
- Every worksheet needs a title that states a conclusion, not a description. "Hourly Fraud Rate" describes. "The overnight spike is a denominator effect" concludes.
- Turn off tooltips on the KPI tiles. Leave them on everywhere else.
- Add a footer text object: *Source: PaySim synthetic dataset (Kaggle, CC BY-SA 4.0). Analysis: BigQuery, R, Tableau. All rates computed within TRANSFER and CASH_OUT only.*

---

## Publishing checklist

1. Every number on the dashboard matches a CSV in `data/`. Open both side by side and check each one.
2. The URL in README has no `?publish=yes` suffix.
3. "Allow downloads" is enabled so reviewers can inspect the workbook.
4. The dashboard title matches the repo name so the two are recognisably one project.
5. Take a fresh PNG screenshot into `tableau/` after all fixes, replacing the current one.
