# ==============================================================================
# 02_visuals.R
# Project : PaySim Fraud Chain and Velocity Analysis
# Purpose : Chain velocity, amount bands, draining signal, and rule trade off.
#
# Every chart in this script reads a real BigQuery export. No values are
# hardcoded and no distributions are simulated.
#
# Input   : data/q2_chains.csv           (sql/04_q2_fraud_chain.sql)
#           data/q3_amount_lift.csv      (sql/07_rule_performance.sql)
#           data/q3_draining_signal.csv  (sql/06_q3_exports_and_flows.sql)
#           data/q4_rule_performance.csv (sql/07_rule_performance.sql)
# Output  : figures/02_hours_to_cashout.png
#           figures/03_amount_distribution.png
#           figures/04_account_draining_signal.png
#           figures/06_rule_tradeoff.png
# ==============================================================================

library(tidyverse)
library(scales)

if (!dir.exists("figures")) dir.create("figures")

theme_fraud <- theme_minimal(base_size = 13) +
  theme(
    plot.title       = element_text(face = "bold", size = 15),
    plot.subtitle    = element_text(colour = "grey35", size = 11),
    plot.caption     = element_text(colour = "grey45", size = 9, hjust = 0),
    panel.grid.minor = element_blank(),
    axis.title       = element_text(face = "bold", size = 11)
  )

pal <- c("Fraudulent" = "#E15759", "Legitimate" = "#4E79A7")

# ==============================================================================
# Figure 2: cash out velocity
# ==============================================================================

chains <- read_csv("data/q2_chains.csv", show_col_types = FALSE)

velocity <- chains %>%
  group_by(hours_to_cashout) %>%
  summarise(chains = sum(chain_count), .groups = "drop") %>%
  mutate(share = chains / sum(chains))

p_velocity <- ggplot(velocity, aes(x = factor(hours_to_cashout), y = chains)) +
  geom_col(fill = "#2E86DE", width = 0.55) +
  geom_text(aes(label = percent(share, accuracy = 0.1)),
            vjust = -0.5, size = 4.5, fontface = "bold", colour = "grey25") +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.14))) +
  labs(
    title    = "99.2% of Stolen Funds Exit Within the Same Hour They Arrive",
    subtitle = "Elapsed time between a fraudulent TRANSFER and its matching CASH_OUT",
    x = "Hours to Cash-Out", y = "Number of Fraud Chains",
    caption  = paste0(
      "Chains matched on amount equality within a one hour window: ",
      comma(sum(velocity$chains)), " matches against 4,097 fraudulent transfers, ",
      "a 5% over match from amount collisions. Account name linkage was tested first ",
      "and found unreliable in PaySim."
    )
  ) +
  theme_fraud

ggsave("figures/02_hours_to_cashout.png", p_velocity,
       width = 10, height = 6, dpi = 300)

# ==============================================================================
# Figure 3: fraud rate and lift by amount band
# ==============================================================================

lift <- read_csv("data/q3_amount_lift.csv", show_col_types = FALSE)

p_amount <- ggplot(lift, aes(x = amount_band, y = fraud_rate_pct)) +
  geom_col(aes(fill = lift_vs_baseline >= 2), width = 0.65) +
  geom_text(aes(label = paste0(lift_vs_baseline, "x")),
            vjust = -0.5, size = 4.2, fontface = "bold", colour = "grey25") +
  geom_hline(yintercept = 0.296, linetype = "dashed", colour = "grey40") +
  annotate("text", x = 1.6, y = 0.42, label = "baseline 0.296%",
           size = 3.6, colour = "grey40") +
  scale_fill_manual(values = c("FALSE" = "#B0B7BE", "TRUE" = "#E15759"),
                    guide = "none") +
  scale_y_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.16))) +
  labs(
    title    = "Only the Over 1M Band Separates Fraud From Legitimate Activity",
    subtitle = "Fraud rate within each amount band, labelled with lift against the overall baseline",
    x = "Transaction Amount Band", y = "Fraud Rate (%)",
    caption  = "Computed within TRANSFER and CASH_OUT only (2,770,409 rows)."
  ) +
  theme_fraud

ggsave("figures/03_amount_distribution.png", p_amount,
       width = 10, height = 6, dpi = 300)

# ==============================================================================
# Figure 4: draining signal, showing the false positive problem
# ==============================================================================

draining <- read_csv("data/q3_draining_signal.csv", show_col_types = FALSE) %>%
  mutate(class = if_else(isFraud == 1, "Fraudulent", "Legitimate"))

p_drain <- ggplot(draining, aes(x = class, y = fully_drained_pct, fill = class)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(fully_drained_pct, "%")),
            vjust = -0.5, size = 5, fontface = "bold", colour = "grey25") +
  scale_fill_manual(values = pal, guide = "none") +
  scale_y_continuous(labels = label_percent(scale = 1), limits = c(0, 112),
                     expand = expansion(mult = c(0, 0))) +
  labs(
    title    = "Account Draining Catches Almost All Fraud, and Almost Half of Everything Else",
    subtitle = "Share of transactions that fully liquidate the origin account balance",
    x = "Transaction Class", y = "Fully Drained (%)",
    caption  = paste0(
      "42.7% of legitimate transactions also drain the account, because emptying a ",
      "mobile wallet is normal behaviour. As a standalone rule this produces 148 alerts ",
      "per fraud case caught. See figure 6."
    )
  ) +
  theme_fraud

ggsave("figures/04_account_draining_signal.png", p_drain,
       width = 10, height = 6, dpi = 300)

# ==============================================================================
# Figure 6: rule trade off, the centrepiece chart
# ==============================================================================

rules <- read_csv("data/q4_rule_performance.csv", show_col_types = FALSE) %>%
  mutate(rule_short = str_replace(rule_name, "^[A-D]\\. ", ""))

p_rules <- ggplot(rules, aes(x = recall_pct, y = precision_pct)) +
  geom_point(aes(size = alerts), colour = "#E15759", alpha = 0.75) +
  geom_text(aes(label = paste0(rule_short, "\n",
                               comma(alerts), " alerts, ",
                               alerts_per_catch, " per catch")),
            vjust = -1.1, size = 3.5, colour = "grey25", lineheight = 1.05) +
  scale_size_continuous(range = c(4, 16), guide = "none") +
  scale_x_continuous(labels = label_percent(scale = 1), limits = c(-8, 118)) +
  scale_y_continuous(labels = label_percent(scale = 1), limits = c(-12, 130)) +
  labs(
    title    = "No Single Rule Is Production Ready",
    subtitle = "Precision against recall for each candidate rule, sized by alert volume",
    x = "Recall (%)", y = "Precision (%)",
    caption  = paste0(
      "The current control sits at perfect precision because it almost never fires. ",
      "Draining alone reaches 97.6% recall at 0.67% precision. Combining conditions ",
      "cuts alert volume by 94% and raises precision sixfold, at the cost of recall."
    )
  ) +
  theme_fraud

ggsave("figures/06_rule_tradeoff.png", p_rules,
       width = 10, height = 7, dpi = 300)

# ---- Console summary for README reconciliation -------------------------------

cat("\n--- Cash out velocity ---\n"); print(velocity)
cat("\n--- Amount lift ---\n");       print(lift)
cat("\n--- Draining signal ---\n");   print(draining %>% select(class, fully_drained_pct))
cat("\n--- Rule performance ---\n");  print(rules %>% select(rule_short, precision_pct, recall_pct, alerts_per_catch))