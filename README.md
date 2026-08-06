# PaySim Fraud Chain and Velocity Analysis

Mapping the transfer to cash out chain in mobile money fraud, measuring how fast the money leaves, and testing whether the proposed detection rules would actually survive contact with production.

**Tools:** Google BigQuery (SQL) · R (tidyverse, ggplot2) · Tableau Public
**Dataset:** PaySim synthetic mobile money transactions, 6,362,620 records across 744 simulated hours

---

## Executive Summary

Social engineering fraud does not end when the victim authorises a transfer. It ends when the money is cashed out, and that is where interception has to happen.

Across 6.36 million simulated transactions, **$6.07B in customer funds was targeted through fraudulent transfers and $5.99B of it was successfully liquidated, a 98.7% liquidation success rate.** Of the matched fraud chains, **99.2% completed the cash out within the same hour as the transfer.** No chain took longer than one hour.

The existing control caught **16 of 8,213 fraudulent transaction legs, an overall recall of 0.19%**, and caught none of the cash out leg at all.

The most useful result was negative. Account draining looked like a decisive signal at 97.6% recall, but measuring its false positive volume showed it would raise **148 alerts for every fraud case caught**. A single behavioural rule is not deployable. The analysis therefore ends with combined rule logic and honest precision figures rather than a headline signal.

---

## Live Dashboard

**[View the interactive Tableau Public dashboard](https://public.tableau.com/app/profile/abdulrashid.mustafa/viz/paysim-fraud-chain-analysisDashboard/Dashboard1)**

---

## 1. Business Task

**Problem.** A mobile money provider is losing funds to social engineering fraud. Victims are manipulated into authorising transfers to accounts controlled by fraudsters, who then cash out rapidly.

**Objective.** Map the financial flow, measure cash out velocity, evaluate how the existing rule performs, and design detection rules that interrupt the chain before liquidation completes.

**Stakeholders.** Fraud Operations, Risk Management, Executive Leadership.
**Audience.** Non technical decision makers, plus technical reviewers of the analysis itself.

**Guiding questions.**
1. How much value is at risk, and how effectively does the existing control perform?
2. What is the transaction chain, and the time window, between the fraudulent transfer and the cash out?
3. Do transaction amount and balance behaviour predict fraud risk well enough to build a rule on?

---

## 2. Data Sources and Limitations

**Source.** PaySim synthetic dataset by Edgar Lopez-Rojas, published on Kaggle under CC BY-SA 4.0, generated from real mobile money transaction logs of an African operator.

**Structure.** 6,362,620 rows, 11 columns, 744 hourly steps mapped to 31 simulated days, across five transaction types.

**ROCCC assessment.**

| Criterion | Assessment |
|---|---|
| Reliable | Derived from real operator logs, academically published, widely used as a fraud detection benchmark |
| Original | Primary synthetic generation, not a redistributed secondary extract |
| Comprehensive | Full ledger including balances, counterparties, and ground truth fraud labels |
| Current | Not recent, but the behavioural patterns it models remain valid |
| Cited | Licensed and attributed on Kaggle |

**Limitations, stated openly.**

1. **Fraud is simulation bound.** Fraud occurs only in TRANSFER and CASH_OUT by design. Question 1 is therefore framed around value at risk and control performance rather than where fraud occurs, which the data guarantees in advance.
2. **Rate denominators.** All fraud rate figures are computed within TRANSFER and CASH_OUT only (2,770,409 rows), not against the full 6.36M ledger. Rates against the full ledger would be far lower and would not describe the channels where fraud is possible.
3. **Simulation artifacts in daily volume.** 13 of 31 days contain near zero legitimate volume, the extremes being day 31 with 272 transactions and day 3 with 429. Fraud rate on those days is an artifact, not a trend, and is greyed out in figure 5.
4. **Ledger inconsistencies.** 53.06% of transfer records report zero origin balances before and after the transaction. These rows were preserved rather than dropped, because removing them would discard genuine fraud cases. This also inflates any ratio computed against the origin balance, which is why the drained ratio is reported as a median rather than a mean.
5. **Chain matching is approximate.** Account name linkage between fraudulent transfers and cash outs was tested first and found unreliable in PaySim, so chains are matched on amount equality within a one hour window. This yields 4,308 matches against 4,097 fraudulent transfers, a 5% over match from amount collisions.
6. **The velocity rule is untested for false positives.** Precision was measured for the amount and draining rules but not for the velocity rule, which requires chain reconstruction across the full ledger. This is listed as the first item under further exploration and should not be read as a validated recommendation.
7. **Privacy.** Not applicable. The data is entirely synthetic.

---

## 3. Data Cleaning and Feature Engineering

All transformation was performed in BigQuery, producing `paysim.cleaned_transactions`. Full code in `sql/02_cleaning.sql`.

| Transformation | Rationale |
|---|---|
| `step` mapped to `sim_day` (1 to 31) and `hour_of_day` (0 to 23) | The raw step is a linear hour counter with no calendar meaning |
| `is_orig_drained` binary flag | Captures complete liquidation of the origin balance, the behavioural signal tested in question 3 |
| `orig_balance_error`, `dest_balance_error` | Quantifies ledger inconsistency rather than silently ignoring it |
| Drained ratio computed at query time, not stored | Ratios against near zero balances explode, so the metric is only meaningful as a median on rows where the origin balance is positive |
| No rows dropped | Removing balance anomaly rows would remove genuine fraud cases and bias the result |

Row count was verified as unchanged after transformation, and the day and hour ranges were checked against expected bounds.

---

## 4. Analytical Findings

### Q1. Value at risk and control performance

| Metric | Value |
|---|---|
| Funds targeted (fraudulent TRANSFER) | $6,067,213,184 |
| Funds liquidated (fraudulent CASH_OUT) | $5,989,202,244 |
| Liquidation success rate | 98.7% |
| Fraudulent transaction legs | 8,213 (4,097 transfers, 4,116 cash outs) |
| Caught by `isFlaggedFraud` | 16 |
| Overall recall | 0.19% |

The two legs are **not** added together. They are the same money observed twice as it moves through the chain. Reporting $12B would double count it.

The native control flags single transfers above a fixed threshold. It caught 16 of 4,097 fraudulent transfers (0.39%) and **none** of the 4,116 cash outs. Its precision is perfect at 100%, which is the tell: the threshold is set so high that it fires almost never. A static monetary threshold applied to one leg of a two leg chain is structurally unable to detect this pattern.

### Q2. Chain velocity

Of 4,308 matched chains, **4,272 (99.2%) completed the cash out in the same hour as the transfer.** The remaining 36 completed within the following hour. None took longer.

The operational consequence is direct. Any control that depends on a human working a review queue arrives after the money is gone. Interception has to be automated and inline.

### Q3. Behaviour versus size, and what it costs

**Amount carries real but narrow signal.** Fraudulent transfers average $1.48M against $906k for legitimate transfers, and the overlap is heavy across most of the range. Only one band separates cleanly:

| Amount band | Transactions | Fraud rate | Lift vs baseline |
|---|---|---|---|
| under 1K | 7,801 | 0.743% | 2.5x |
| 1K to 10K | 71,040 | 0.310% | 1.0x |
| 10K to 100K | 757,271 | 0.189% | 0.6x |
| 100K to 1M | 1,803,790 | 0.211% | 0.7x |
| **over 1M** | **130,507** | **2.073%** | **7.0x** |

**Account draining looks decisive until you measure its cost.** Complete liquidation of the origin balance occurs in 97.55% of fraudulent transactions, but also in **42.72%** of legitimate ones. The behaviour is common in normal mobile money use, where customers routinely empty a wallet.

The sharper version of the signal is the ratio, not the flag. For fraudulent transactions the drained ratio has a median of **1.0 and a 90th percentile of 1.0**, meaning the origin balance is taken exactly and consistently. For legitimate transactions the median is 5.77 and the 90th percentile is 181.6, reflecting both genuine variation and the ledger inconsistencies noted above.

### Rule performance, measured

| Rule | Alerts | Caught | Precision | Recall | Alerts per catch |
|---|---|---|---|---|---|
| A. Fixed threshold (current control) | 16 | 16 | 100.0% | 0.19% | 1.0 |
| B. Account draining only | 1,188,074 | 8,012 | 0.67% | 97.55% | 148.3 |
| C. High value only (over 1M) | 130,507 | 2,706 | 2.07% | 32.95% | 48.2 |
| D. Draining AND high value | 65,466 | 2,548 | 3.89% | 31.02% | 25.7 |

No single rule tested here is production ready. Rule A almost never fires. Rule B would bury a fraud team under 1.19 million alerts. Combining conditions improves precision roughly sixfold over rule B and cuts alert volume by 94%, at the cost of two thirds of the recall.

That trade off is the actual finding. A recommendation that reports recall without reporting alert volume is not a recommendation, it is a demo.

### Temporal pattern, and a correction worth stating

Fraud rate appears to spike overnight, reaching 57.9% at 04:00. That spike is a **denominator effect, not a fraud surge.** Fraud volume is close to constant around the clock at 274 to 375 cases per hour. What changes is legitimate volume, which falls from 299,933 transactions at peak to 512 at 03:00.

The correct reading is that overnight is the highest signal to noise window, which makes it the highest yield period per analyst hour rather than the period of greatest fraud activity.

---

## 5. Visualisations

| Figure | Takeaway |
|---|---|
| `01_fraud_rate_by_hour.png` | Fraud rate peaks in the quietest hours, when monitoring is thinnest |
| `01b_fraud_volume_vs_rate.png` | The overnight spike is a denominator effect, not a fraud surge |
| `02_hours_to_cashout.png` | 99.2% of stolen funds exit within the same hour they arrive |
| `03_amount_distribution.png` | Only the over 1M band separates fraud from legitimate activity |
| `04_account_draining_signal.png` | Draining catches almost all fraud, and almost half of legitimate activity too |
| `05_daily_fraud_trend.png` | Daily rate is stable once simulation artifacts are excluded |
| `06_rule_tradeoff.png` | Precision and alert volume for each candidate rule |

---

## 6. Recommendations

**1. Automated inline velocity hold.** Hold any CASH_OUT initiated from an account that received a transfer within the preceding 60 minutes. Given that 99.2% of chains complete inside that window, this is the only control that operates where it matters. Caveat: precision for this rule was not measured in this analysis and must be quantified before deployment.

**2. Use combined conditions, never draining alone.** Account draining on its own reaches 97.6% recall at 0.67% precision, or 148 alerts per catch, which no operations team can absorb. Combining draining with the over 1M band raises precision to 3.9% and cuts alerts by 94%. Test the exact ratio variant as well: fraudulent transactions drain the balance at a ratio of exactly 1.0 with almost no variance, which may separate more sharply than the binary flag.

**3. Keep the fixed threshold as a reporting trigger, not a detection control.** It caught 0.19% of fraud and none of the cash out leg. Its perfect precision reflects how rarely it fires, not how well it works.

**4. Weight review capacity toward overnight hours.** Not because fraud increases at night, but because the ratio of fraudulent to legitimate activity is highest then, which is where each analyst hour returns the most.

---

## 7. Further Exploration

- **Measure velocity rule precision.** Reconstruct all transfer to cash out pairs across the full ledger, not just the fraudulent ones, and compute how many legitimate chains the 60 minute hold would catch. This is the single most important missing number.
- **Test the exact drain ratio rule.** Flag transactions where the drained ratio falls within a narrow band around 1.0 and compare its precision against the binary flag.
- **Network analysis of mule account clustering**, to detect coordinated rings rather than isolated chains.
- **Supervised model benchmarked against these rules**, to quantify how much lift a model adds over simple logic.
- **False positive cost modelling.** Each alert has a handling cost and each hold has a customer friction cost. The rule comparison above counts alerts but does not price them.
- **Validation against real dispute outcomes**, which synthetic data cannot provide.

---

## 8. How to Reproduce

1. Download the PaySim dataset from Kaggle
2. Load it into BigQuery as `paysim.raw_transactions`
3. Run `sql/01_profiling.sql` through `sql/07_rule_performance.sql` in order
4. Export each result set to `data/` using the filenames named in the script comments
5. From the project root, run `R/01_time_series.R` then `R/02_visuals.R`
6. Figures are written to `figures/` at 300 dpi

Required R packages: `tidyverse`, `scales`, `patchwork`

---

## 9. Repository Structure

```
paysim-fraud-chain-analysis/
├── README.md
├── data_dictionary.md
├── sql/         01 profiling, 02 cleaning, 03 to 07 analysis and exports
├── R/           01 time series, 02 visuals
├── data/        aggregated exports only, no raw data
├── figures/     300 dpi output
├── tableau/     dashboard link and screenshot
└── docs/        query result screenshots
```

---

## 10. Attribution

PaySim dataset by Edgar Lopez-Rojas, available on Kaggle under CC BY-SA 4.0. Analysis, code, and interpretation are my own.

## 11. AI Assistance

AI tools were used as pair programming assistants for SQL optimisation, R debugging, and review of analytical framing. All analytical decisions, feasibility testing, number reconciliation, and business recommendations were defined and validated independently.
