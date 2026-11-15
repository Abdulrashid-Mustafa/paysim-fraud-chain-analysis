# ==============================================================================
# 02_visuals.R
# Project : PaySim Fraud Chain and Velocity Analysis
# Purpose : Chain outcomes, amount bands, the balance artifact, rule trade off.
#
# Every chart reads a BigQuery export in data/. Nothing is hardcoded.
#
# Input   : data/q2_chain_outcomes.csv    (sql/04_q2_fraud_chain.sql)
#           data/q3_amount_lift.csv       (sql/07_rule_performance.sql)
#           data/q3_balance_artifacts.csv (sql/06_q3_balance_signals.sql)
#           data/q4_rule_performance.csv  (sql/07_rule_performance.sql)
# Output  : figures/02_chain_outcomes.png
#           figures/03_amount_distribution.png
#           figures/04_account_draining_signal.png
#           figures/06_rule_tradeoff.png
# ==============================================================================

library(tidyverse)
library(scales)

if (!dir.exists("figures")) dir.create("figures")

highlight <- "#2E5E8C"
context   <- "#B0B7BE"

theme_fraud <- theme_minimal(base_size = 13) +
  theme(
    plot.title            = element_text(face = "bold", size = 15),
    plot.subtitle         = element_text(colour = "grey35", size = 11),
    plot.caption          = element_text(colour = "grey40", size = 9.5, hjust = 0),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    panel.grid.minor      = element_blank(),
    axis.title            = element_text(size = 11),
    strip.text            = element_text(face = "bold", size = 11, hjust = 0)
  )

# ==============================================================================
# Figure 2: what happened to each fraudulent transfer
# ==============================================================================

outcomes <- read_csv("data/q2_chain_outcomes.csv", show_col_types = FALSE) %>%
  mutate(label = str_remove(outcome, "^[a-z0-9]+\\. "),
         label = fct_reorder(label, transfers))

same_hour <- outcomes %>% filter(str_detect(outcome, "same hour"))

p_chain <- ggplot(outcomes, aes(x = transfers, y = label)) +
  geom_col(aes(fill = str_detect(outcome, "same hour")), width = 0.6) +
  geom_text(aes(label = paste0(comma(transfers), " (", share_of_transfers_pct, "%)")),
            hjust = -0.1, size = 4.2, colour = "grey20") +
  scale_fill_manual(values = c("TRUE" = highlight, "FALSE" = context), guide = "none") +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.22))) +
  labs(
    title    = paste0(same_hour$share_of_transfers_pct,
                      "% of Fraudulent Transfers Were Cashed Out Within the Same Hour"),
    subtitle = "Outcome of each of the 4,097 fraudulent transfers, one row per transfer",
    x = "Fraudulent transfers", y = NULL,
    caption  = str_wrap(paste0(
      "Each transfer is matched to the earliest fraudulent cash out of the same amount, with no upper time limit. ",
      "None was found in a later hour. Account linkage between the two legs does not exist in PaySim, ",
      "and same hour means the same simulation step."), 130)
  ) +
  theme_fraud +
  theme(panel.grid.major.y = element_blank())

ggsave("figures/02_chain_outcomes.png", p_chain, width = 10, height = 5, dpi = 300, bg = "white")

# ==============================================================================
# Figure 3: fraud rate and lift by amount band
# ==============================================================================

lift <- read_csv("data/q3_amount_lift.csv", show_col_types = FALSE)
baseline <- unique(lift$baseline_rate_pct)
small_band <- lift %>% filter(amount_band == "a. under 1K")

p_amount <- ggplot(lift, aes(x = amount_band, y = fraud_rate_pct)) +
  geom_col(aes(fill = amount_band == "e. 1M and over"), width = 0.65) +
  geom_text(aes(label = paste0(lift_vs_baseline, "x")),
            vjust = -0.5, size = 4.2, colour = "grey20") +
  geom_hline(yintercept = baseline, linetype = "dashed", colour = "grey40") +
  scale_fill_manual(values = c("TRUE" = highlight, "FALSE" = context), guide = "none") +
  scale_y_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.16))) +
  labs(
    title    = "The 1M and Over Band Carries 7x the Baseline Fraud Rate",
    subtitle = paste0("Fraud rate within each amount band, labelled with lift. Dashed line: overall baseline of ", baseline, "%"),
    x = "Transaction amount band (local currency)", y = "Fraud rate",
    caption  = paste0("The under 1K band also shows lift (", small_band$lift_vs_baseline,
                      "x) but holds only ", small_band$fraud_txns,
                      " fraud cases. Computed within TRANSFER and CASH_OUT only (2,770,409 rows).")
  ) +
  theme_fraud +
  theme(panel.grid.major.x = element_blank())

ggsave("figures/03_amount_distribution.png", p_amount, width = 10, height = 6, dpi = 300, bg = "white")

# ==============================================================================
# Figure 4: the draining signal is a balance artifact
# ==============================================================================

artifacts <- read_csv("data/q3_balance_artifacts.csv", show_col_types = FALSE) %>%
  mutate(class = if_else(isFraud == 1, "Fraudulent", "Legitimate")) %>%
  select(type, class, drained_pct, amount_equals_balance_pct) %>%
  pivot_longer(c(drained_pct, amount_equals_balance_pct), names_to = "metric", values_to = "pct") %>%
  mutate(metric = factor(metric, levels = c("drained_pct", "amount_equals_balance_pct"),
                         labels = c("Origin balance reported as emptied",
                                    "Amount exactly equals the origin balance")))

p_drain <- ggplot(artifacts, aes(x = class, y = pct, fill = class)) +
  geom_col(width = 0.55) +
  geom_text(aes(label = paste0(pct, "%")), vjust = -0.4, size = 3.8, colour = "grey20") +
  facet_grid(type ~ metric) +
  scale_fill_manual(values = c("Fraudulent" = highlight, "Legitimate" = context), guide = "none") +
  scale_y_continuous(labels = label_percent(scale = 1), limits = c(0, 115),
                     breaks = c(0, 50, 100)) +
  labs(
    title    = "Legitimate Rows Never Move Their Exact Balance. Fraud Rows Almost Always Do.",
    subtitle = "The 42% of legitimate rows that look drained all move more than the balance they came from",
    x = NULL, y = NULL,
    caption  = str_wrap(paste0(
      "The dataset owner states that fraud transactions are cancelled in the simulation and that the balance ",
      "columns must not be used for detection. Both bars on the right are a property of how the simulator ",
      "writes balances, not customer behaviour."), 130)
  ) +
  theme_fraud +
  theme(panel.grid.major.x = element_blank())

ggsave("figures/04_account_draining_signal.png", p_drain, width = 10, height = 7, dpi = 300, bg = "white")

# ==============================================================================
# Figure 6: rule trade off
# ==============================================================================

rules <- read_csv("data/q4_rule_performance.csv", show_col_types = FALSE) %>%
  mutate(rule_id = str_sub(rule_name, 1, 1),
         balance = if_else(uses_balance_columns == "yes",
                           "Reads balance columns (not valid for detection)",
                           "No balance columns"),
         label = paste0(rule_id, ". ", comma(alerts), " alerts, precision ", precision_pct, "%"))

# Manual label offsets so close points do not collide
nudges <- tibble(rule_id = c("A", "B", "C", "D", "E", "F"),
                 dx = c(3, -3, 3, 3, -3, -3), dy = c(-6, 7, 9, -6, 7, -6),
                 hj = c(0, 1, 0, 0, 1, 1))
rules <- rules %>% left_join(nudges, by = "rule_id")

p_rules <- ggplot(rules, aes(x = recall_pct, y = precision_pct)) +
  geom_point(aes(size = alerts, shape = balance), colour = highlight, stroke = 1.3, alpha = 0.85) +
  geom_text(aes(x = recall_pct + dx, y = precision_pct + dy, label = label, hjust = hj),
            size = 3.5, colour = "grey20") +
  scale_shape_manual(values = c("No balance columns" = 16,
                                "Reads balance columns (not valid for detection)" = 1),
                     name = NULL) +
  scale_size_continuous(range = c(3, 14), guide = "none") +
  scale_x_continuous(labels = label_percent(scale = 1), limits = c(-5, 105), breaks = seq(0, 100, 25)) +
  scale_y_continuous(labels = label_percent(scale = 1), limits = c(-12, 112), breaks = seq(0, 100, 25)) +
  labs(
    title    = "The Two Near Perfect Rules Are Both Simulation Artifacts",
    subtitle = "Precision against recall for each candidate rule, sized by alert volume",
    x = "Recall", y = "Precision",
    caption  = str_wrap(paste0(
      "A: existing flag. B: draining. C: amount 1M and over. D: B and C combined. ",
      "E: cash out with the same amount as a transfer in the same hour (recall on the 4,116 fraudulent cash outs). ",
      "F: amount equals origin balance, shown only as a leakage check. ",
      "E is near perfect because PaySim mirrors the exact amount across both legs. F uses columns the dataset owner says not to use."), 140)
  ) +
  theme_fraud +
  theme(legend.position = "top")

ggsave("figures/06_rule_tradeoff.png", p_rules, width = 11, height = 7.5, dpi = 300, bg = "white")

# ---- Console summary for README reconciliation -------------------------------

cat("\n--- Chain outcomes ---\n"); print(outcomes %>% select(outcome, transfers, share_of_transfers_pct))
cat("\n--- Amount lift ---\n");    print(lift)
cat("\n--- Rules ---\n");          print(rules %>% select(rule_name, alerts, precision_pct, recall_pct, alerts_per_catch))
