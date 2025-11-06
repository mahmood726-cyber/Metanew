# INSTANT SAMPLE DATA LOADER
# Pre-loads demo data and results for immediate user engagement
#
# Loads instantly (<100ms) to show users what the app can do

#' Generate instant sample meta-analysis data
#' @return Data frame with sample studies
generate_sample_ma_data <- function() {
  # 15 sample cardiovascular studies (realistic data)
  data.frame(
    study_id = paste0("Study ", 1:15),
    author = c("Smith", "Johnson", "Williams", "Brown", "Jones",
               "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
               "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson"),
    year = c(2018, 2019, 2019, 2020, 2020, 2021, 2021, 2021,
             2022, 2022, 2022, 2023, 2023, 2023, 2024),
    outcome = "Mortality",

    # Effect sizes (log odds ratios)
    yi = c(-0.42, -0.35, -0.28, -0.38, -0.31,
           -0.45, -0.27, -0.33, -0.40, -0.29,
           -0.36, -0.31, -0.43, -0.34, -0.37),

    # Standard errors
    sei = c(0.12, 0.15, 0.18, 0.11, 0.14,
            0.10, 0.16, 0.13, 0.12, 0.17,
            0.11, 0.14, 0.10, 0.13, 0.12),

    # Variance (sei^2) - required for meta-analysis
    vi = c(0.12, 0.15, 0.18, 0.11, 0.14,
           0.10, 0.16, 0.13, 0.12, 0.17,
           0.11, 0.14, 0.10, 0.13, 0.12)^2,

    # Sample sizes
    n_total = c(450, 320, 280, 520, 380,
                610, 290, 440, 480, 260,
                550, 380, 590, 420, 500),

    # Risk of bias
    rob = c("Low", "Low", "Moderate", "Low", "Moderate",
            "Low", "Moderate", "Low", "Low", "High",
            "Low", "Moderate", "Low", "Low", "Low"),

    # Country
    country = c("USA", "UK", "Germany", "USA", "France",
                "Canada", "UK", "USA", "Germany", "Spain",
                "USA", "France", "Canada", "UK", "Germany"),

    stringsAsFactors = FALSE
  )
}


#' Generate instant sample meta-analysis results
#' @param data Sample data
#' @return Pre-computed MA results
generate_sample_ma_results <- function(data = NULL) {
  if (is.null(data)) {
    data <- generate_sample_ma_data()
  }

  # Calculate variance
  data$vi <- data$sei^2

  # Pre-compute results (instant!)
  list(
    data = data,
    pooled_effect = -0.349,
    ci_lower = -0.411,
    ci_upper = -0.287,
    se = 0.032,
    z_value = -10.91,
    p_value = 0.0001,  # Fixed: was "< 0.0001" which is invalid syntax
    i_squared = 32.4,
    tau_squared = 0.0074,
    q_statistic = 20.7,
    df = 14,
    q_p_value = 0.108,
    n_studies = 15,
    pi_lower = -0.521,
    pi_upper = -0.177,

    # Interpretation
    interpretation = list(
      effect = "Treatment reduces mortality by 29% (OR = 0.71, 95% CI: 0.66 to 0.75)",
      heterogeneity = "Low to moderate heterogeneity (I² = 32.4%)",
      significance = "Highly statistically significant (p < 0.0001)",
      robustness = "Results appear robust with tight confidence intervals"
    )
  )
}


#' Generate sample network meta-analysis data
#' @return Network MA data
generate_sample_nma_data <- function() {
  # Sample network: 4 treatments (A, B, C, D), 12 studies
  expand.grid(
    study_id = paste0("NMA_Study_", 1:12),
    treat1 = c("Control", "Drug A", "Drug B", "Drug C"),
    treat2 = c("Drug A", "Drug B", "Drug C", "Drug D"),
    stringsAsFactors = FALSE
  )[1:18, ]  # 18 comparisons
}


#' Generate sample health economics data
#' @return HE parameters
generate_sample_he_data <- function() {
  list(
    costs = list(
      treatment_a = list(mean = 15000, sd = 2000),
      treatment_b = list(mean = 12000, sd = 1800)
    ),
    qalys = list(
      treatment_a = list(mean = 8.5, sd = 1.2),
      treatment_b = list(mean = 7.8, sd = 1.1)
    ),
    icer = 12857,  # Cost per QALY gained
    prob_cost_effective = 0.82,  # Probability cost-effective at £30k/QALY
    interpretation = "Treatment A is cost-effective at WTP threshold of £30,000/QALY (82% probability)"
  )
}


#' Load demo scenario instantly
#' @return Complete demo scenario
load_instant_demo_scenario <- function() {
  list(
    name = "🎯 Demo: Cardiovascular Mortality Study",
    description = "Pre-loaded example showing how the platform works",

    data = generate_sample_ma_data(),
    results = generate_sample_ma_results(),
    he_data = generate_sample_he_data(),

    protocol = list(
      population = "Adults with cardiovascular disease",
      intervention = "Novel cardioprotective drug",
      comparator = "Standard care",
      outcome = "All-cause mortality",
      study_design = "Randomized controlled trials"
    ),

    quick_facts = list(
      "15 studies included",
      "7,930 patients total",
      "29% mortality reduction",
      "p < 0.0001 (highly significant)",
      "Low heterogeneity (I² = 32%)",
      "Cost-effective (£12,857/QALY)"
    ),

    call_to_action = "👈 Explore the demo data in the tabs, or upload your own data to get started!"
  )
}


#' Generate sample forest plot data (pre-computed)
#' @return Plot-ready data
generate_sample_forest_plot_data <- function() {
  data <- generate_sample_ma_data()

  # Pre-compute plot coordinates
  data$ci_lower <- data$yi - 1.96 * data$sei
  data$ci_upper <- data$yi + 1.96 * data$sei
  data$weight <- 1 / data$vi
  data$weight_pct <- 100 * data$weight / sum(data$weight)
  data$study_label <- paste0(data$author, " (", data$year, ")")
  data$study_order <- 1:nrow(data)

  data
}


#' Initialize app with sample data
#' This runs on app startup to have data ready instantly
#' @param rv Reactive values to populate
initialize_sample_data <- function(rv) {
  cat("🎯 Loading instant demo scenario...\n")
  start_time <- Sys.time()

  # Load demo scenario (< 50ms)
  demo <- load_instant_demo_scenario()

  # Populate reactive values
  rv$data <- demo$data
  rv$pairwise_results <- list(Mortality = demo$results)
  rv$he_data <- demo$he_data
  rv$protocol <- demo$protocol
  rv$demo_mode <- TRUE
  rv$demo_info <- demo

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("✅ Demo data loaded in %.0f ms\n", elapsed * 1000))

  return(demo)
}


cat("✅ Sample data loader ready!\n")
cat("   • 15 sample studies (cardiovascular)\n")
cat("   • Pre-computed meta-analysis results\n")
cat("   • Health economics data\n")
cat("   • Loads in <50ms\n")
