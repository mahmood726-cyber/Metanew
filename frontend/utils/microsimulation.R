# Patient-Level Microsimulation Engine
# Discrete event simulation for health economic models
# Allows individual patient characteristics and heterogeneity

library(dplyr)
library(tidyr)

#' Run patient-level microsimulation
#'
#' @param params HE parameters list
#' @param base_prob_prog Baseline annual progression probability
#' @param base_prob_death Baseline annual death probability
#' @param hr_progression Hazard ratio for progression (list with hr, se_log)
#' @param hr_death Hazard ratio for death (list with hr, se_log)
#' @param n_patients Number of patients to simulate (default from params)
#' @param seed Random seed for reproducibility
#' @return List with patient-level and summary results
run_microsimulation <- function(params, base_prob_prog, base_prob_death,
                                 hr_progression, hr_death,
                                 n_patients = NULL, seed = 42) {

  set.seed(seed)

  if (is.null(n_patients)) {
    n_patients <- params$n_patients_microsim
    if (is.null(n_patients)) n_patients <- 1000
  }

  horizon <- params$time_horizon
  discount <- params$discount_rate

  message(sprintf("Running microsimulation for %d patients over %d years...", n_patients, horizon))

  # Initialize patient cohort
  patients <- initialize_patient_cohort(n_patients, params)

  # Run simulation for treatment arm
  results_treatment <- simulate_cohort(
    patients, horizon, base_prob_prog, base_prob_death,
    hr_progression$hr, hr_death$hr,
    params, arm = "treatment"
  )

  # Run simulation for comparator arm
  results_comparator <- simulate_cohort(
    patients, horizon, base_prob_prog, base_prob_death,
    1.0, 1.0,  # No treatment effect
    params, arm = "comparator"
  )

  # Calculate summary statistics
  summary_results <- calculate_microsim_summary(
    results_treatment, results_comparator, params
  )

  return(list(
    treatment = results_treatment,
    comparator = results_comparator,
    summary = summary_results,
    patients = patients,
    n_patients = n_patients,
    params = params,
    hr_progression = hr_progression,
    hr_death = hr_death
  ))
}

#' Initialize patient cohort with heterogeneity
#' @param n_patients Number of patients
#' @param params Parameter list
#' @return Data frame of patient characteristics
initialize_patient_cohort <- function(n_patients, params) {
  # Generate patient-specific characteristics
  patients <- data.frame(
    patient_id = 1:n_patients,
    # Age at baseline (normal distribution around base age)
    age = rnorm(n_patients, mean = params$base_age, sd = 5),
    # Sex (50/50 unless specified)
    sex = sample(c("male", "female"), n_patients, replace = TRUE,
                prob = if (params$sex == "male") c(1, 0) else if (params$sex == "female") c(0, 1) else c(0.5, 0.5)),
    # Baseline utility (beta distribution around mean)
    baseline_utility = rbeta(n_patients,
                            shape1 = params$utility_stable * 50,
                            shape2 = (1 - params$utility_stable) * 50),
    # Progressed utility (beta distribution)
    progressed_utility = rbeta(n_patients,
                              shape1 = params$utility_progressed * 50,
                              shape2 = (1 - params$utility_progressed) * 50),
    # Comorbidity burden (affects costs and mortality)
    comorbidity_index = rgamma(n_patients, shape = 2, rate = 2),  # Mean = 1, represents multiplier
    stringsAsFactors = FALSE
  )

  # Ensure age is within reasonable bounds
  patients$age <- pmax(0, pmin(110, patients$age))

  return(patients)
}

#' Simulate cohort through Markov process
#' @param patients Patient data frame
#' @param horizon Time horizon
#' @param base_prob_prog Base progression probability
#' @param base_prob_death Base death probability
#' @param hr_prog HR for progression
#' @param hr_death HR for death
#' @param params Parameter list
#' @param arm Treatment arm name
#' @return Patient-level results
simulate_cohort <- function(patients, horizon, base_prob_prog, base_prob_death,
                             hr_prog, hr_death, params, arm) {

  n_patients <- nrow(patients)

  # Initialize tracking matrices
  # States: 1 = Stable, 2 = Progressed, 3 = Dead
  state_history <- matrix(1, nrow = n_patients, ncol = horizon + 1)
  colnames(state_history) <- paste0("year_", 0:horizon)

  qalys_by_patient <- numeric(n_patients)
  costs_by_patient <- numeric(n_patients)

  # Get mortality tables
  if (!exists("get_mortality_rate")) {
    source("utils/mortality_tables.R", local = TRUE)
  }

  # Simulate each patient
  for (i in 1:n_patients) {
    patient <- patients[i, ]

    current_state <- 1  # Start in Stable state
    patient_qalys <- 0
    patient_costs <- 0

    # Simulate year by year
    for (year in 1:horizon) {
      # Age this year
      current_age <- patient$age + year - 1

      # Get age-specific background mortality
      bg_mortality <- get_mortality_rate(current_age, patient$sex, params$country_code)
      # Adjust for comorbidity
      bg_mortality <- adjust_mortality_smr(bg_mortality, patient$comorbidity_index * params$mortality_smr)

      # Convert base probabilities to rates and apply HRs
      rate_prog <- -log(1 - base_prob_prog)
      rate_death_prog <- -log(1 - base_prob_death)

      rate_prog_adj <- rate_prog * hr_prog
      rate_death_prog_adj <- rate_death_prog * hr_death

      prob_prog <- 1 - exp(-rate_prog_adj)
      prob_death_prog <- 1 - exp(-rate_death_prog_adj)

      # State transitions based on current state
      if (current_state == 3) {
        # Dead - stay dead
        next_state <- 3
        utility_this_year <- 0
        cost_this_year <- 0

      } else if (current_state == 1) {
        # Stable state
        # Check transitions: Stable -> Dead, Stable -> Progressed
        rand_val <- runif(1)

        if (rand_val < bg_mortality) {
          # Background death
          next_state <- 3
        } else if (rand_val < (bg_mortality + prob_prog)) {
          # Progress to diseased state
          next_state <- 2
        } else {
          # Stay stable
          next_state <- 1
        }

        # Utility and costs for stable state
        utility_this_year <- patient$baseline_utility
        cost_this_year <- params$cost_stable * patient$comorbidity_index

      } else if (current_state == 2) {
        # Progressed state
        # Check transitions: Progressed -> Dead
        rand_val <- runif(1)

        if (rand_val < (bg_mortality + prob_death_prog)) {
          # Death from progressed state
          next_state <- 3
        } else {
          # Stay in progressed state
          next_state <- 2
        }

        # Utility and costs for progressed state
        utility_this_year <- patient$progressed_utility
        cost_this_year <- params$cost_progressed * patient$comorbidity_index
      }

      # Add drug costs
      if (arm == "treatment") {
        cost_this_year <- cost_this_year + params$cost_treatment
      } else {
        cost_this_year <- cost_this_year + params$cost_comparator
      }

      # Apply discounting
      discount_factor <- 1 / (1 + params$discount_rate)^year

      # Apply half-cycle correction if enabled
      if (!is.null(params$half_cycle_correction) && params$half_cycle_correction) {
        if (year == 1 || year == horizon) {
          discount_factor <- discount_factor * 0.5
        }
      }

      # Accumulate QALYs and costs
      patient_qalys <- patient_qalys + utility_this_year * discount_factor
      patient_costs <- patient_costs + cost_this_year * discount_factor

      # Update state
      current_state <- next_state
      state_history[i, year + 1] <- current_state
    }

    qalys_by_patient[i] <- patient_qalys
    costs_by_patient[i] <- patient_costs
  }

  # Return results
  list(
    state_history = state_history,
    qalys = qalys_by_patient,
    costs = costs_by_patient,
    arm = arm
  )
}

#' Calculate summary statistics from microsimulation
#' @param results_treatment Treatment results
#' @param results_comparator Comparator results
#' @param params Parameters
#' @return Summary statistics
calculate_microsim_summary <- function(results_treatment, results_comparator, params) {

  # Mean QALYs and costs
  mean_qalys_trt <- mean(results_treatment$qalys)
  mean_qalys_comp <- mean(results_comparator$qalys)
  mean_costs_trt <- mean(results_treatment$costs)
  mean_costs_comp <- mean(results_comparator$costs)

  # Incremental
  inc_qalys <- mean_qalys_trt - mean_qalys_comp
  inc_costs <- mean_costs_trt - mean_costs_comp
  icer <- inc_costs / inc_qalys

  # Standard errors (for PSA)
  se_qalys_trt <- sd(results_treatment$qalys) / sqrt(length(results_treatment$qalys))
  se_qalys_comp <- sd(results_comparator$qalys) / sqrt(length(results_comparator$qalys))
  se_costs_trt <- sd(results_treatment$costs) / sqrt(length(results_treatment$costs))
  se_costs_comp <- sd(results_comparator$costs) / sqrt(length(results_comparator$costs))

  # Calculate state occupancy over time
  horizon <- ncol(results_treatment$state_history) - 1
  state_occupancy_trt <- calculate_state_occupancy(results_treatment$state_history)
  state_occupancy_comp <- calculate_state_occupancy(results_comparator$state_history)

  # Survival curves
  survival_trt <- calculate_survival(results_treatment$state_history)
  survival_comp <- calculate_survival(results_comparator$state_history)

  list(
    qalys_treatment = mean_qalys_trt,
    qalys_comparator = mean_qalys_comp,
    costs_treatment = mean_costs_trt,
    costs_comparator = mean_costs_comp,
    inc_qalys = inc_qalys,
    inc_costs = inc_costs,
    icer = icer,
    se_qalys_treatment = se_qalys_trt,
    se_qalys_comparator = se_qalys_comp,
    se_costs_treatment = se_costs_trt,
    se_costs_comparator = se_costs_comp,
    state_occupancy_treatment = state_occupancy_trt,
    state_occupancy_comparator = state_occupancy_comp,
    survival_treatment = survival_trt,
    survival_comparator = survival_comp,
    # Patient-level distributions for CEA
    inc_qalys_distribution = results_treatment$qalys - results_comparator$qalys,
    inc_costs_distribution = results_treatment$costs - results_comparator$costs
  )
}

#' Calculate state occupancy over time
#' @param state_history Matrix of states over time
#' @return Matrix of proportions in each state over time
calculate_state_occupancy <- function(state_history) {
  n_years <- ncol(state_history)
  occupancy <- matrix(0, nrow = n_years, ncol = 3)
  colnames(occupancy) <- c("Stable", "Progressed", "Dead")

  for (t in 1:n_years) {
    states_at_t <- state_history[, t]
    occupancy[t, 1] <- sum(states_at_t == 1) / nrow(state_history)
    occupancy[t, 2] <- sum(states_at_t == 2) / nrow(state_history)
    occupancy[t, 3] <- sum(states_at_t == 3) / nrow(state_history)
  }

  return(occupancy)
}

#' Calculate survival curve
#' @param state_history Matrix of states
#' @return Vector of survival proportions over time
calculate_survival <- function(state_history) {
  n_years <- ncol(state_history)
  survival <- numeric(n_years)

  for (t in 1:n_years) {
    survival[t] <- sum(state_history[, t] != 3) / nrow(state_history)
  }

  return(survival)
}

#' Plot microsimulation results
#' @param microsim_results Results from run_microsimulation
#' @return List of ggplot objects
plot_microsimulation_results <- function(microsim_results) {
  library(ggplot2)
  library(tidyr)

  # 1. State occupancy plot
  horizon <- nrow(microsim_results$summary$state_occupancy_treatment)
  years <- 0:(horizon - 1)

  # Treatment occupancy
  occ_trt <- as.data.frame(microsim_results$summary$state_occupancy_treatment)
  occ_trt$year <- years
  occ_trt$arm <- "Treatment"

  # Comparator occupancy
  occ_comp <- as.data.frame(microsim_results$summary$state_occupancy_comparator)
  occ_comp$year <- years
  occ_comp$arm <- "Comparator"

  occ_df <- rbind(occ_trt, occ_comp) %>%
    pivot_longer(cols = c("Stable", "Progressed", "Dead"),
                names_to = "State", values_to = "Proportion")

  p1 <- ggplot(occ_df, aes(x = year, y = Proportion, fill = State)) +
    geom_area(alpha = 0.7) +
    facet_wrap(~arm) +
    scale_fill_manual(values = c("Stable" = "#4CAF50",
                                 "Progressed" = "#FF9800",
                                 "Dead" = "#F44336")) +
    labs(title = "State Occupancy Over Time (Microsimulation)",
         x = "Year", y = "Proportion of Cohort") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # 2. Survival curves
  survival_df <- data.frame(
    year = years,
    Treatment = microsim_results$summary$survival_treatment,
    Comparator = microsim_results$summary$survival_comparator
  ) %>%
    pivot_longer(cols = c("Treatment", "Comparator"),
                names_to = "Arm", values_to = "Survival")

  p2 <- ggplot(survival_df, aes(x = year, y = Survival, color = Arm)) +
    geom_line(size = 1.2) +
    scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
    scale_color_manual(values = c("Treatment" = "#2196F3", "Comparator" = "#9E9E9E")) +
    labs(title = "Survival Curves (Microsimulation)",
         x = "Year", y = "Survival Probability") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # 3. QALY distribution
  qaly_df <- data.frame(
    Treatment = microsim_results$treatment$qalys,
    Comparator = microsim_results$comparator$qalys
  ) %>%
    pivot_longer(cols = everything(), names_to = "Arm", values_to = "QALYs")

  p3 <- ggplot(qaly_df, aes(x = QALYs, fill = Arm)) +
    geom_density(alpha = 0.5) +
    scale_fill_manual(values = c("Treatment" = "#2196F3", "Comparator" = "#9E9E9E")) +
    labs(title = "Distribution of QALYs (Patient-Level)",
         x = "Total QALYs", y = "Density") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # 4. Cost distribution
  cost_df <- data.frame(
    Treatment = microsim_results$treatment$costs,
    Comparator = microsim_results$comparator$costs
  ) %>%
    pivot_longer(cols = everything(), names_to = "Arm", values_to = "Costs")

  p4 <- ggplot(cost_df, aes(x = Costs, fill = Arm)) +
    geom_density(alpha = 0.5) +
    scale_fill_manual(values = c("Treatment" = "#2196F3", "Comparator" = "#9E9E9E")) +
    scale_x_continuous(labels = scales::dollar) +
    labs(title = "Distribution of Costs (Patient-Level)",
         x = "Total Costs", y = "Density") +
    theme_minimal() +
    theme(legend.position = "bottom")

  list(
    state_occupancy = p1,
    survival = p2,
    qaly_distribution = p3,
    cost_distribution = p4
  )
}

#' Compare cohort vs microsimulation results
#' @param cohort_results Results from run_markov_model
#' @param microsim_results Results from run_microsimulation
#' @return Comparison data frame
compare_model_types <- function(cohort_results, microsim_results) {
  comparison <- data.frame(
    Metric = c("QALYs Treatment", "QALYs Comparator", "Costs Treatment",
               "Costs Comparator", "Incremental QALYs", "Incremental Costs", "ICER"),
    Cohort = c(
      cohort_results$qalys_treatment,
      cohort_results$qalys_comparator,
      cohort_results$costs_treatment,
      cohort_results$costs_comparator,
      cohort_results$inc_qalys,
      cohort_results$inc_costs,
      cohort_results$icer
    ),
    Microsimulation = c(
      microsim_results$summary$qalys_treatment,
      microsim_results$summary$qalys_comparator,
      microsim_results$summary$costs_treatment,
      microsim_results$summary$costs_comparator,
      microsim_results$summary$inc_qalys,
      microsim_results$summary$inc_costs,
      microsim_results$summary$icer
    ),
    stringsAsFactors = FALSE
  )

  comparison$Difference <- comparison$Microsimulation - comparison$Cohort
  comparison$Pct_Difference <- (comparison$Difference / comparison$Cohort) * 100

  return(comparison)
}
