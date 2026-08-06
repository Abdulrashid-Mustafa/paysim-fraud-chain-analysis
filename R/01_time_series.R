# ==============================================================================
# 01_time_series.R
# Project : PaySim Fraud Chain & Velocity Analysis
# Purpose : Temporal analysis of fraud activity across hours and simulated days.
#
# Analytical note:
#   Fraud COUNT is near constant around the clock (274-375 cases per hour).
#   Legitimate volume collapses overnight (299,933 down to 512 transactions).
#   All rates are computed within TRANSFER and CASH_OUT only (2.77M rows).
#   The overnight spike in fraud RATE is a denominator effect, not a surge in
#   fraud activity. Both panels are plotted so the chart cannot be misread.
#
# Input   : data/hourly_fraud.csv, data/daily_fraud.csv
# Output  : figures/01_fraud_rate_by_hour.png
#           figures/01b_fraud_volume_vs_rate.png
#           figures/05_daily_fraud_trend.png
# ==============================================================================

library(tidyverse)
library(scales)
library(patchwork)

# ---- Load aggregated exports -------------------------------------------------

hourly <- read_csv("data/hourly_fraud.csv", show_col_types = FALSE)
daily  <- read_csv("data/daily_fraud.csv",  show_col_types = FALSE)

# ---- Shared theme ------------------------------------------------------------

theme_fraud <- theme_minimal(base_size = 13) +
  theme(
    plot.title       = element_text(face = "bold", size = 15),
    plot.subtitle    = element_text(colour = "grey35", size = 11),
    plot.caption     = element_text(colour = "grey45", size = 9, hjust = 0),
    panel.grid.minor = element_blank(),
    axis.title       = element_text(face = "bold", size = 11)
  )

# ---- Figure 1: fraud rate by hour of day ------------------------------------

p_rate <- ggplot(hourly, aes(x = factor(hour_of_day), y = fraud_rate_pct)) +
  geom_col(fill = "#E15759", width = 0.75) +
  scale_y_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(
    title    = "Fraud Rate Peaks in the Quietest Hours, When Monitoring Is Thinnest",
    subtitle = "Fraudulent share of TRANSFER and CASH_OUT transactions, by hour of day (0 to 23)",
    x = "Hour of Day", y = "Fraud Rate (%)"
  ) +
  theme_fraud

ggsave("figures/01_fraud_rate_by_hour.png", p_rate,
       width = 10, height = 6, dpi = 300)

# ---- Figure 1b: volume vs rate, the honest version ---------------------------

p_count <- ggplot(hourly, aes(x = factor(hour_of_day), y = fraud_tx)) +
  geom_col(fill = "#4E79A7", width = 0.75) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.08))) +
  labs(subtitle = "Fraud volume stays flat all day (274 to 375 cases per hour)",
       x = NULL, y = "Fraud Cases") +
  theme_fraud

p_total <- ggplot(hourly, aes(x = factor(hour_of_day), y = total_tx)) +
  geom_col(fill = "#B0B7BE", width = 0.75) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.08))) +
  labs(subtitle = "Legitimate volume collapses overnight, and that drives the rate spike",
       x = "Hour of Day", y = "Total Transactions") +
  theme_fraud

p_combined <- (p_count / p_total) +
  plot_annotation(
    title   = "The Overnight Spike Is a Denominator Effect, Not a Fraud Surge",
    caption = "Signal to noise is highest between 01:00 and 05:00: nearly 6 in 10 transactions at 04:00 are fraudulent.",
    theme   = theme_fraud
  )

ggsave("figures/01b_fraud_volume_vs_rate.png", p_combined,
       width = 10, height = 8, dpi = 300)

# ---- Figure 5: daily trend with simulation artifacts marked ------------------

artifact_days <- daily %>% filter(total_tx < 20000) %>% pull(sim_day)

p_daily <- ggplot(daily, aes(x = sim_day, y = fraud_rate_pct)) +
  geom_col(aes(fill = sim_day %in% artifact_days), width = 0.75) +
  scale_fill_manual(values = c("FALSE" = "#4E79A7", "TRUE" = "#D9D9D9"),
                    labels = c("Interpretable", "Simulation artifact"),
                    name   = NULL) +
  scale_y_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(
    title    = "Daily Fraud Rate Is Stable Once Simulation Artifacts Are Excluded",
    subtitle = "Grey bars mark days with near zero legitimate volume, where the rate is not meaningful",
    x = "Simulated Day", y = "Fraud Rate (%)",
    caption  = paste0("Artifact days excluded from interpretation: ",
                      paste(artifact_days, collapse = ", "))
  ) +
  theme_fraud +
  theme(legend.position = "top")

ggsave("figures/05_daily_fraud_trend.png", p_daily,
       width = 10, height = 6, dpi = 300)

# ---- Console summary for README reconciliation -------------------------------

cat("\n--- Hourly summary ---\n")
hourly %>%
  summarise(
    fraud_min = min(fraud_tx),
    fraud_max = max(fraud_tx),
    total_min = min(total_tx),
    total_max = max(total_tx),
    peak_hour = hour_of_day[which.max(fraud_rate_pct)],
    peak_rate = max(fraud_rate_pct)
  ) %>% print()

cat("\n--- Simulation artifact days (total_tx < 20,000) ---\n")
print(artifact_days)