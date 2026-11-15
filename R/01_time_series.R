# ==============================================================================
# 01_time_series.R
# Project : PaySim Fraud Chain and Velocity Analysis
# Purpose : Hourly and daily fraud patterns.
#
# Every value comes from a BigQuery export in data/. Nothing is hardcoded.
# All rates are computed within TRANSFER and CASH_OUT only (2,770,409 rows).
# Hour of day assumes step 1 starts at 00:00, which the source does not state.
#
# Input   : data/hourly_fraud.csv, data/daily_fraud.csv
# Output  : figures/01_fraud_rate_by_hour.png
#           figures/01b_fraud_volume_vs_rate.png
#           figures/05_daily_fraud_trend.png
# ==============================================================================

library(tidyverse)
library(scales)

if (!dir.exists("figures")) dir.create("figures")

hourly <- read_csv("data/hourly_fraud.csv", show_col_types = FALSE)
daily  <- read_csv("data/daily_fraud.csv",  show_col_types = FALSE)

highlight <- "#2E5E8C"
context   <- "#B0B7BE"

theme_fraud <- theme_minimal(base_size = 13) +
  theme(
    plot.title         = element_text(face = "bold", size = 15),
    plot.subtitle      = element_text(colour = "grey35", size = 11),
    plot.caption       = element_text(colour = "grey40", size = 9.5, hjust = 0),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.title         = element_text(size = 11),
    strip.text         = element_text(face = "bold", size = 11, hjust = 0)
  )

# ---- Figure 1: fraud rate by hour of day -------------------------------------

peak <- hourly %>% slice_max(fraud_rate_pct, n = 1)

p_rate <- ggplot(hourly, aes(x = factor(hour_of_day), y = fraud_rate_pct)) +
  geom_col(aes(fill = hour_of_day <= 6), width = 0.75) +
  scale_fill_manual(values = c("TRUE" = highlight, "FALSE" = context), guide = "none") +
  geom_text(data = peak,
            aes(label = paste0(number(fraud_rate_pct, accuracy = 0.1), "%")),
            vjust = -0.5, size = 4, colour = "grey20") +
  scale_y_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = "Fraud Rate Peaks Overnight, When Legitimate Volume Is Lowest",
    subtitle = "Fraudulent share of TRANSFER and CASH_OUT rows by hour of day, 00:00 to 06:59 highlighted",
    x = "Hour of day", y = "Fraud rate",
    caption  = "Hour of day assumes simulation step 1 starts at 00:00."
  ) +
  theme_fraud

ggsave("figures/01_fraud_rate_by_hour.png", p_rate, width = 10, height = 6, dpi = 300, bg = "white")

# ---- Figure 1b: fraud and legitimate volume, side by side --------------------

hourly_long <- hourly %>%
  select(hour_of_day, fraud_tx, legit_tx) %>%
  pivot_longer(-hour_of_day, names_to = "class", values_to = "rows") %>%
  mutate(class = factor(class, levels = c("fraud_tx", "legit_tx"),
                        labels = c(paste0("Fraudulent rows per hour (",
                                          min(hourly$fraud_tx), " to ", max(hourly$fraud_tx), ")"),
                                   "Legitimate rows per hour")))

h3 <- hourly %>% filter(hour_of_day == 3)
h4 <- hourly %>% filter(hour_of_day == 4)

p_split <- ggplot(hourly_long, aes(x = factor(hour_of_day), y = rows, fill = class)) +
  geom_col(width = 0.75) +
  facet_wrap(~ class, ncol = 1, scales = "free_y") +
  scale_fill_manual(values = c(highlight, context), guide = "none") +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.08))) +
  labs(
    title    = "The Overnight Spike Is a Denominator Effect, Not a Fraud Surge",
    subtitle = "Fraud volume barely moves across the day. Legitimate volume collapses overnight.",
    x = "Hour of day", y = NULL,
    caption  = paste0(
      "At 03:00 there are ", comma(h3$fraud_tx), " fraudulent rows against ", comma(h3$legit_tx),
      " legitimate ones, and at 04:00 ", comma(h4$fraud_tx), " against ", comma(h4$legit_tx),
      ". Separate y axes: the panels count different things."
    )
  ) +
  theme_fraud

ggsave("figures/01b_fraud_volume_vs_rate.png", p_split, width = 10, height = 8, dpi = 300, bg = "white")

# ---- Figure 5: daily volume, showing where the simulation thins out ----------

daily_long <- daily %>%
  select(sim_day, fraud_tx, legit_tx) %>%
  pivot_longer(-sim_day, names_to = "class", values_to = "rows") %>%
  mutate(class = factor(class, levels = c("legit_tx", "fraud_tx"),
                        labels = c("Legitimate rows per day", "Fraudulent rows per day")))

full_days <- daily %>% filter(sim_day <= 17, !sim_day %in% c(3, 4, 5))
late_days <- daily %>% filter(sim_day >= 18, sim_day <= 30)

p_daily <- ggplot(daily_long, aes(x = sim_day, y = rows, fill = class)) +
  geom_col(width = 0.75) +
  facet_wrap(~ class, ncol = 1, scales = "free_y") +
  scale_fill_manual(values = c(context, highlight), guide = "none") +
  scale_x_continuous(breaks = c(1, 5, 10, 15, 17, 20, 25, 31)) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.08))) +
  labs(
    title    = "Legitimate Volume Collapses After Day 17, While Fraud Keeps Its Pace",
    subtitle = "Daily rows within TRANSFER and CASH_OUT. Daily fraud rates are only comparable inside the full volume days.",
    x = "Simulated day", y = NULL,
    caption  = paste0(
      "Days 1 to 17 (except 3 to 5): fraud rate ", number(min(full_days$fraud_rate_pct), accuracy = 0.01),
      "% to ", number(max(full_days$fraud_rate_pct), accuracy = 0.01), "%. ",
      "Days 18 to 30: ", comma(min(late_days$legit_tx)), " to ", comma(max(late_days$legit_tx)),
      " legitimate rows a day, and day 31 has none at all."
    )
  ) +
  theme_fraud

ggsave("figures/05_daily_fraud_trend.png", p_daily, width = 10, height = 7, dpi = 300, bg = "white")

# ---- Console summary for README reconciliation -------------------------------

cat("\n--- Hourly ---\n")
hourly %>% summarise(fraud_min = min(fraud_tx), fraud_max = max(fraud_tx),
                     legit_min = min(legit_tx), legit_max = max(legit_tx),
                     peak_hour = hour_of_day[which.max(fraud_rate_pct)],
                     peak_rate = max(fraud_rate_pct)) %>% print()
cat("\n--- Daily ---\n")
print(full_days %>% summarise(rate_min = min(fraud_rate_pct), rate_max = max(fraud_rate_pct)))
print(late_days %>% summarise(legit_min = min(legit_tx), legit_max = max(legit_tx)))
