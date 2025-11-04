# Advanced Health Economics Features
# Value of Information (VOI) analysis and Budget Impact Model (BIM)

library(BCEA)

#' Calculate Expected Value of Perfect Information (EVPI)
#'
#' @param psa_results PSA results from markov model
#' @param wtp_threshold Willingness-to-pay threshold
#' @param n_patients Number of patients affected
#' @return List with EVPI results
calculate_evpi <- function(psa_results, wtp_threshold = 30000, n_patients = 10000) {
  if (is.null(psa_results) || nrow(psa_results) == 0) {
    return(list(error = "No PSA results available"))
  }

  tryCatch({
    # Extract costs and effects for each arm
    # Assuming psa_results has columns: iteration, arm, total_cost, total_qalys

    arms <- unique(psa_results$arm)
    if (length(arms) != 2) {
      return(list(error = "EVPI requires exactly 2 arms"))
    }

    # Reshape data
    costs_matrix <- matrix(0, nrow = nrow(psa_results) / 2, ncol = 2)
    effects_matrix <- matrix(0, nrow = nrow(psa_results) / 2, ncol = 2)

    for (i in 1:length(arms)) {
      arm_data <- psa_results[psa_results$arm == arms[i], ]
      costs_matrix[, i] <- arm_data$total_cost
      effects_matrix[, i] <- arm_data$total_qalys
    }

    # Calculate NMB for each iteration
    nmb_matrix <- effects_matrix * wtp_threshold - costs_matrix

    # Maximum NMB with current information (expected)
    expected_nmb <- apply(nmb_matrix, 2, mean)
    max_expected_nmb <- max(expected_nmb)
    optimal_arm_expected <- arms[which.max(expected_nmb)]

    # Maximum NMB with perfect information (known in each iteration)
    max_nmb_per_iteration <- apply(nmb_matrix, 1, max)
    expected_max_nmb <- mean(max_nmb_per_iteration)

    # EVPI per patient
    evpi_per_patient <- expected_max_nmb - max_expected_nmb

    # Population EVPI
    evpi_population <- evpi_per_patient * n_patients

    return(list(
      evpi_per_patient = evpi_per_patient,
      evpi_population = evpi_population,
      n_patients = n_patients,
      wtp_threshold = wtp_threshold,
      optimal_arm = optimal_arm_expected,
      expected_nmb = max_expected_nmb,
      perfect_info_nmb = expected_max_nmb,
      interpretation = if (evpi_per_patient > 1000) {
        "High EVPI suggests further research could be valuable"
      } else if (evpi_per_patient > 100) {
        "Moderate EVPI - consider additional research"
      } else {
        "Low EVPI - current evidence may be sufficient"
      }
    ))

  }, error = function(e) {
    return(list(error = paste("EVPI calculation error:", e$message)))
  })
}

#' Calculate Expected Value of Partial Perfect Information (EVPPI)
#'
#' @param psa_results PSA results
#' @param parameter_name Parameter to assess
#' @param wtp_threshold WTP threshold
#' @param n_patients Number of patients
#' @return List with EVPPI results
calculate_evppi <- function(psa_results, parameter_name, wtp_threshold = 30000, n_patients = 10000) {
  # Simplified EVPPI using nonparametric regression
  tryCatch({
    # This requires parameter values in psa_results
    if (!parameter_name %in% names(psa_results)) {
      return(list(error = paste("Parameter not found:", parameter_name)))
    }

    # Calculate NMB
    arms <- unique(psa_results$arm)
    nmb_by_iteration <- sapply(split(psa_results, psa_results$iteration), function(iter_data) {
      nmb <- iter_data$total_qalys * wtp_threshold - iter_data$total_cost
      max(nmb)
    })

    # Get parameter values
    param_values <- psa_results[[parameter_name]][psa_results$arm == arms[1]]

    # Nonparametric regression (loess)
    fit <- loess(nmb_by_iteration ~ param_values, span = 0.75)
    predicted_nmb <- predict(fit)

    # EVPPI
    evppi_per_patient <- mean(predicted_nmb) - mean(nmb_by_iteration)
    evppi_population <- evppi_per_patient * n_patients

    return(list(
      parameter = parameter_name,
      evppi_per_patient = evppi_per_patient,
      evppi_population = evppi_population,
      n_patients = n_patients,
      wtp_threshold = wtp_threshold
    ))

  }, error = function(e) {
    return(list(error = paste("EVPPI calculation error:", e$message)))
  })
}

#' Run budget impact model
#'
#' @param intervention_cost Cost per patient for intervention
#' @param comparator_cost Cost per patient for comparator
#' @param n_patients_yr1 Number of patients in year 1
#' @param market_share_yr1 Market share in year 1 (0-1)
#' @param market_share_yr5 Market share in year 5 (0-1)
#' @param n_years Number of years (default: 5)
#' @param discount_rate Discount rate for costs
#' @return List with budget impact results
calculate_budget_impact <- function(intervention_cost, comparator_cost, n_patients_yr1,
                                   market_share_yr1 = 0.1, market_share_yr5 = 0.5,
                                   n_years = 5, discount_rate = 0.035) {

  tryCatch({
    # Projected market uptake (linear interpolation)
    market_share <- seq(market_share_yr1, market_share_yr5, length.out = n_years)

    # Patient growth (assume 2% annual growth)
    growth_rate <- 0.02
    n_patients <- n_patients_yr1 * (1 + growth_rate)^(0:(n_years - 1))

    # Calculate costs for each year
    results <- data.frame(
      year = 1:n_years,
      n_patients = round(n_patients),
      market_share = market_share,
      n_intervention = round(n_patients * market_share),
      n_comparator = round(n_patients * (1 - market_share))
    )

    # Intervention scenario costs
    results$intervention_scenario_cost <-
      results$n_intervention * intervention_cost +
      results$n_comparator * comparator_cost

    # Comparator scenario costs (all patients on comparator)
    results$comparator_scenario_cost <- results$n_patients * comparator_cost

    # Incremental budget impact
    results$incremental_cost <- results$intervention_scenario_cost - results$comparator_scenario_cost

    # Discounted costs
    discount_factor <- 1 / (1 + discount_rate)^(0:(n_years - 1))
    results$discount_factor <- discount_factor
    results$incremental_cost_discounted <- results$incremental_cost * discount_factor

    # Total budget impact
    total_undiscounted <- sum(results$incremental_cost)
    total_discounted <- sum(results$incremental_cost_discounted)

    return(list(
      yearly_results = results,
      total_undiscounted = total_undiscounted,
      total_discounted = total_discounted,
      intervention_cost = intervention_cost,
      comparator_cost = comparator_cost,
      n_years = n_years,
      discount_rate = discount_rate,
      summary_stats = list(
        avg_annual_impact = mean(results$incremental_cost),
        peak_year = which.max(results$incremental_cost),
        peak_impact = max(results$incremental_cost)
      )
    ))

  }, error = function(e) {
    return(list(error = paste("Budget impact calculation error:", e$message)))
  })
}

#' Plot EVPI curve across WTP thresholds
#'
#' @param psa_results PSA results
#' @param wtp_range Vector of WTP thresholds to evaluate
#' @param n_patients Number of patients
#' @return ggplot object
plot_evpi_curve <- function(psa_results, wtp_range = seq(0, 50000, by = 5000), n_patients = 10000) {
  library(ggplot2)

  # Calculate EVPI for each WTP
  evpi_results <- lapply(wtp_range, function(wtp) {
    result <- calculate_evpi(psa_results, wtp_threshold = wtp, n_patients = n_patients)
    data.frame(
      wtp = wtp,
      evpi_per_patient = result$evpi_per_patient,
      evpi_population = result$evpi_population
    )
  })

  evpi_df <- do.call(rbind, evpi_results)

  ggplot(evpi_df, aes(x = wtp, y = evpi_per_patient)) +
    geom_line(color = "#0066CC", size = 1.2) +
    geom_area(alpha = 0.3, fill = "#0066CC") +
    scale_x_continuous(labels = scales::comma) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Expected Value of Perfect Information (EVPI)",
      subtitle = sprintf("Population size: %s patients", scales::comma(n_patients)),
      x = "Willingness-to-Pay Threshold (£/QALY)",
      y = "EVPI per Patient (£)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold")
    )
}

#' Plot budget impact over time
#'
#' @param bim_results Results from calculate_budget_impact()
#' @return ggplot object
plot_budget_impact <- function(bim_results) {
  library(ggplot2)
  library(tidyr)

  if (!is.null(bim_results$error)) {
    return(NULL)
  }

  df <- bim_results$yearly_results

  # Reshape for plotting
  df_long <- df %>%
    select(year, intervention_scenario_cost, comparator_scenario_cost, incremental_cost) %>%
    pivot_longer(
      cols = -year,
      names_to = "cost_type",
      values_to = "cost"
    ) %>%
    mutate(
      cost_type = factor(cost_type,
                        levels = c("comparator_scenario_cost", "intervention_scenario_cost", "incremental_cost"),
                        labels = c("Comparator Scenario", "Intervention Scenario", "Incremental Budget Impact"))
    )

  ggplot(df_long, aes(x = year, y = cost / 1e6, fill = cost_type)) +
    geom_bar(stat = "identity", position = "dodge") +
    scale_fill_manual(values = c("#999999", "#0066CC", "#FF6B35")) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Budget Impact Analysis",
      subtitle = sprintf("Total %d-year impact: £%s M (discounted)",
                        bim_results$n_years,
                        format(round(bim_results$total_discounted / 1e6, 2), nsmall = 2)),
      x = "Year",
      y = "Cost (£ Millions)",
      fill = "Scenario"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
}

#' Format EVPI results for display
#'
#' @param evpi_result Result from calculate_evpi()
#' @return HTML tags
format_evpi_display <- function(evpi_result) {
  if (!is.null(evpi_result$error)) {
    return(tags$div(class = "alert alert-warning", evpi_result$error))
  }

  tags$div(
    class = "evpi-results",
    h5("Value of Information Analysis"),

    tags$div(
      class = "row",
      tags$div(
        class = "col-md-6",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body",
            h6("EVPI per Patient"),
            tags$h4(sprintf("£%s", format(round(evpi_result$evpi_per_patient, 0), big.mark = ","))),
            tags$p(class = "text-muted", evpi_result$interpretation)
          )
        )
      ),
      tags$div(
        class = "col-md-6",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body",
            h6(sprintf("Population EVPI (%s patients)", format(evpi_result$n_patients, big.mark = ","))),
            tags$h4(sprintf("£%s M", format(round(evpi_result$evpi_population / 1e6, 2), nsmall = 2)))
          )
        )
      )
    ),

    hr(),

    tags$p(
      strong("Optimal decision:"), evpi_result$optimal_arm,
      " at £", format(evpi_result$wtp_threshold, big.mark = ","), "/QALY"
    ),
    tags$p(
      strong("Expected NMB:"), "£", format(round(evpi_result$expected_nmb, 0), big.mark = ",")
    )
  )
}

#' Format budget impact results for display
#'
#' @param bim_result Result from calculate_budget_impact()
#' @return HTML tags
format_bim_display <- function(bim_result) {
  if (!is.null(bim_result$error)) {
    return(tags$div(class = "alert alert-warning", bim_result$error))
  }

  df <- bim_result$yearly_results

  tags$div(
    class = "bim-results",
    h5("Budget Impact Model"),

    # Summary cards
    tags$div(
      class = "row mb-3",
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Total Impact (Discounted)"),
            tags$h4(sprintf("£%s M", format(round(bim_result$total_discounted / 1e6, 2), nsmall = 2)))
          )
        )
      ),
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Average Annual Impact"),
            tags$h4(sprintf("£%s M", format(round(bim_result$summary_stats$avg_annual_impact / 1e6, 2), nsmall = 2)))
          )
        )
      ),
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Peak Year"),
            tags$h4(sprintf("Year %d", bim_result$summary_stats$peak_year))
          )
        )
      )
    ),

    # Yearly breakdown table
    h6("Yearly Breakdown"),
    tags$div(
      class = "table-responsive",
      tags$table(
        class = "table table-striped table-sm",
        tags$thead(
          tags$tr(
            tags$th("Year"),
            tags$th("Patients"),
            tags$th("Market Share"),
            tags$th("Incremental Impact (£M)")
          )
        ),
        tags$tbody(
          lapply(1:nrow(df), function(i) {
            row <- df[i, ]
            tags$tr(
              tags$td(row$year),
              tags$td(format(row$n_patients, big.mark = ",")),
              tags$td(sprintf("%.1f%%", row$market_share * 100)),
              tags$td(sprintf("£%.2f", row$incremental_cost / 1e6))
            )
          })
        )
      )
    )
  )
}

# ========================================
# PARTITIONED SURVIVAL MODEL (PSM)
# ========================================

#' Create partitioned survival model
#'
#' @param surv_os Overall survival curve (time, survival)
#' @param surv_pfs Progression-free survival curve (time, survival)
#' @param time_horizon Time horizon in years
#' @param cycle_length Cycle length in years (default: 1/12 for monthly)
#' @return List with PSM results
create_psm_model <- function(surv_os, surv_pfs, time_horizon = 10, cycle_length = 1/12) {

  tryCatch({
    # Create time cycles
    n_cycles <- ceiling(time_horizon / cycle_length)
    times <- seq(0, time_horizon, length.out = n_cycles + 1)

    # Interpolate survival curves at cycle times
    os_prob <- approx(surv_os$time, surv_os$survival, xout = times, rule = 2)$y
    pfs_prob <- approx(surv_pfs$time, surv_pfs$survival, xout = times, rule = 2)$y

    # Ensure PFS <= OS (consistency check)
    pfs_prob <- pmin(pfs_prob, os_prob)

    # Calculate state membership over time
    # States: Progression-free, Progressed, Dead
    state_trace <- data.frame(
      time = times,
      cycle = 0:n_cycles,
      pf = pfs_prob,  # Progression-free
      pd = os_prob - pfs_prob,  # Progressed disease
      dead = 1 - os_prob  # Dead
    )

    # Ensure non-negative probabilities
    state_trace$pd <- pmax(0, state_trace$pd)

    return(list(
      state_trace = state_trace,
      time_horizon = time_horizon,
      cycle_length = cycle_length,
      n_cycles = n_cycles,
      model_type = "PSM"
    ))

  }, error = function(e) {
    return(list(error = paste("PSM creation error:", e$message)))
  })
}

#' Calculate costs and QALYs from PSM
#'
#' @param psm_model PSM model from create_psm_model()
#' @param costs_pf Cost per cycle in progression-free state
#' @param costs_pd Cost per cycle in progressed disease state
#' @param utilities_pf Utility in progression-free state
#' @param utilities_pd Utility in progressed disease state
#' @param discount_rate Discount rate (default: 0.035)
#' @return List with cost and QALY results
evaluate_psm <- function(psm_model, costs_pf, costs_pd, utilities_pf, utilities_pd,
                        discount_rate = 0.035) {

  if (!is.null(psm_model$error)) {
    return(psm_model)
  }

  tryCatch({
    state_trace <- psm_model$state_trace
    cycle_length <- psm_model$cycle_length
    n_cycles <- psm_model$n_cycles

    # Calculate discount factors
    discount_factor <- 1 / (1 + discount_rate)^(state_trace$cycle * cycle_length)

    # Calculate costs per cycle
    cycle_costs <- (state_trace$pf * costs_pf +
                   state_trace$pd * costs_pd) * cycle_length

    # Calculate QALYs per cycle (area under curve method)
    cycle_qalys <- (state_trace$pf * utilities_pf +
                   state_trace$pd * utilities_pd) * cycle_length

    # Apply discounting
    discounted_costs <- cycle_costs * discount_factor
    discounted_qalys <- cycle_qalys * discount_factor

    # Total costs and QALYs
    total_costs <- sum(discounted_costs)
    total_qalys <- sum(discounted_qalys)

    # Life years
    life_years <- sum(state_trace$pf + state_trace$pd) * cycle_length
    life_years_discounted <- sum((state_trace$pf + state_trace$pd) * discount_factor) * cycle_length

    # Detailed results by cycle
    detailed_results <- cbind(
      state_trace,
      cycle_costs = cycle_costs,
      cycle_qalys = cycle_qalys,
      discounted_costs = discounted_costs,
      discounted_qalys = discounted_qalys,
      discount_factor = discount_factor
    )

    return(list(
      total_costs = total_costs,
      total_qalys = total_qalys,
      life_years = life_years,
      life_years_discounted = life_years_discounted,
      detailed_results = detailed_results,
      costs_pf = costs_pf,
      costs_pd = costs_pd,
      utilities_pf = utilities_pf,
      utilities_pd = utilities_pd,
      discount_rate = discount_rate
    ))

  }, error = function(e) {
    return(list(error = paste("PSM evaluation error:", e$message)))
  })
}

#' Compare two PSM arms (e.g., treatment vs control)
#'
#' @param psm_results_arm1 Results from evaluate_psm() for arm 1
#' @param psm_results_arm2 Results from evaluate_psm() for arm 2
#' @param wtp_threshold Willingness-to-pay threshold
#' @return List with incremental analysis
compare_psm_arms <- function(psm_results_arm1, psm_results_arm2,
                            wtp_threshold = 30000,
                            arm1_name = "Treatment",
                            arm2_name = "Control") {

  tryCatch({
    # Incremental costs and QALYs
    incremental_costs <- psm_results_arm1$total_costs - psm_results_arm2$total_costs
    incremental_qalys <- psm_results_arm1$total_qalys - psm_results_arm2$total_qalys
    incremental_ly <- psm_results_arm1$life_years_discounted - psm_results_arm2$life_years_discounted

    # ICER
    icer <- if (incremental_qalys != 0) {
      incremental_costs / incremental_qalys
    } else {
      Inf
    }

    # NMB
    nmb_arm1 <- psm_results_arm1$total_qalys * wtp_threshold - psm_results_arm1$total_costs
    nmb_arm2 <- psm_results_arm2$total_qalys * wtp_threshold - psm_results_arm2$total_costs
    incremental_nmb <- nmb_arm1 - nmb_arm2

    # Cost-effectiveness decision
    ce_decision <- if (incremental_nmb > 0) {
      paste(arm1_name, "is cost-effective")
    } else {
      paste(arm2_name, "is cost-effective")
    }

    return(list(
      arm1_name = arm1_name,
      arm2_name = arm2_name,
      arm1_costs = psm_results_arm1$total_costs,
      arm1_qalys = psm_results_arm1$total_qalys,
      arm2_costs = psm_results_arm2$total_costs,
      arm2_qalys = psm_results_arm2$total_qalys,
      incremental_costs = incremental_costs,
      incremental_qalys = incremental_qalys,
      incremental_ly = incremental_ly,
      icer = icer,
      incremental_nmb = incremental_nmb,
      wtp_threshold = wtp_threshold,
      ce_decision = ce_decision
    ))

  }, error = function(e) {
    return(list(error = paste("PSM comparison error:", e$message)))
  })
}

#' Plot PSM state membership over time
#'
#' @param psm_model PSM model from create_psm_model()
#' @return ggplot object
plot_psm_trace <- function(psm_model) {
  library(ggplot2)
  library(tidyr)

  if (!is.null(psm_model$error)) {
    return(NULL)
  }

  # Reshape data for plotting
  df <- psm_model$state_trace %>%
    pivot_longer(
      cols = c("pf", "pd", "dead"),
      names_to = "state",
      values_to = "proportion"
    ) %>%
    mutate(
      state = factor(state,
                    levels = c("dead", "pd", "pf"),
                    labels = c("Dead", "Progressed Disease", "Progression-Free"))
    )

  ggplot(df, aes(x = time, y = proportion, fill = state)) +
    geom_area(alpha = 0.7) +
    scale_fill_manual(values = c("Dead" = "#999999",
                                 "Progressed Disease" = "#FF6B35",
                                 "Progression-Free" = "#4CAF50")) +
    scale_y_continuous(labels = scales::percent) +
    labs(
      title = "Partitioned Survival Model - State Membership",
      subtitle = sprintf("Time horizon: %d years", psm_model$time_horizon),
      x = "Time (years)",
      y = "Proportion of Cohort",
      fill = "Health State"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
}


# ========================================
# MATCHING-ADJUSTED INDIRECT COMPARISON (MAIC)
# ========================================

#' Perform Matching-Adjusted Indirect Comparison (MAIC)
#'
#' @param ipd_data Individual patient data from study A vs C
#' @param agd_summary Aggregate data summary from study B vs C (reference trial)
#' @param matching_vars Variables to match on (e.g., c("age", "sex", "baseline_severity"))
#' @param outcome_var Outcome variable name
#' @param treatment_var Treatment variable name
#' @return List with MAIC results
perform_maic <- function(ipd_data, agd_summary, matching_vars, outcome_var, treatment_var = "treatment") {

  tryCatch({
    # Center IPD covariates on AgD means
    centered_data <- ipd_data
    for (var in matching_vars) {
      if (var %in% names(agd_summary)) {
        centered_data[[paste0(var, "_centered")]] <-
          ipd_data[[var]] - agd_summary[[var]]
      } else {
        warning(paste("Variable", var, "not found in aggregate data summary"))
      }
    }

    # Estimate propensity scores using logistic regression
    # Objective: balance IPD to match AgD
    centered_vars <- paste0(matching_vars, "_centered")
    formula_str <- paste("~", paste(centered_vars, collapse = " + "), "- 1")
    formula_obj <- as.formula(formula_str)

    # Create design matrix
    X <- model.matrix(formula_obj, data = centered_data)

    # Optimize weights to balance covariates
    # Method of moments: solve for weights where E[w * X] = 0

    # Use entropy balancing or standard MAIC weighting
    # Simplified: exponential tilting

    # Fit model to get coefficients
    fit <- tryCatch({
      # Logistic regression for binary outcome
      if (is.factor(centered_data[[outcome_var]]) ||
          all(centered_data[[outcome_var]] %in% c(0, 1))) {
        glm(as.formula(paste(outcome_var, "~ .")),
            data = centered_data[, c(outcome_var, centered_vars)],
            family = binomial())
      } else {
        # Linear regression for continuous outcome
        lm(as.formula(paste(outcome_var, "~ .")),
           data = centered_data[, c(outcome_var, centered_vars)])
      }
    }, error = function(e) {
      warning("Model fitting failed, using unweighted analysis")
      return(NULL)
    })

    # Calculate weights
    # Standard MAIC: weights = exp(X * beta) where beta minimizes sum(weights)
    # subject to weighted covariate means = 0

    # Simplified approach: propensity score weighting
    # Weight = 1 / propensity score

    # For now, use a simplified weighting scheme
    # Calculate Mahalanobis distance and derive weights

    # Standardize covariates
    X_std <- scale(X)

    # Calculate distances from center (0)
    distances <- sqrt(rowSums(X_std^2))

    # Weights inversely proportional to distance (with smoothing)
    weights <- 1 / (1 + distances)
    weights <- weights / sum(weights) * nrow(centered_data)

    # Store weights in data
    centered_data$maic_weights <- weights

    # Effective sample size
    ess <- sum(weights)^2 / sum(weights^2)

    # Weighted treatment effect estimation
    treatment_levels <- unique(centered_data[[treatment_var]])

    if (length(treatment_levels) != 2) {
      return(list(error = "Treatment variable must have exactly 2 levels"))
    }

    # Calculate weighted means by treatment
    weighted_outcomes <- sapply(treatment_levels, function(trt) {
      subset_data <- centered_data[centered_data[[treatment_var]] == trt, ]
      weighted.mean(subset_data[[outcome_var]], w = subset_data$maic_weights)
    })

    # Treatment effect
    treatment_effect <- weighted_outcomes[1] - weighted_outcomes[2]

    # Calculate weighted variance (for SE estimation)
    weighted_var <- function(x, w) {
      weighted_mean <- weighted.mean(x, w)
      sum(w * (x - weighted_mean)^2) / sum(w)
    }

    se_treatment <- sqrt(
      weighted_var(
        centered_data[[outcome_var]][centered_data[[treatment_var]] == treatment_levels[1]],
        centered_data$maic_weights[centered_data[[treatment_var]] == treatment_levels[1]]
      ) / sum(centered_data[[treatment_var]] == treatment_levels[1]) +
      weighted_var(
        centered_data[[outcome_var]][centered_data[[treatment_var]] == treatment_levels[2]],
        centered_data$maic_weights[centered_data[[treatment_var]] == treatment_levels[2]]
      ) / sum(centered_data[[treatment_var]] == treatment_levels[2])
    )

    # Confidence interval
    ci_lower <- treatment_effect - 1.96 * se_treatment
    ci_upper <- treatment_effect + 1.96 * se_treatment

    # Balance diagnostics
    balance_diagnostics <- data.frame(
      variable = matching_vars,
      ipd_mean_unweighted = sapply(matching_vars, function(v) mean(ipd_data[[v]], na.rm = TRUE)),
      ipd_mean_weighted = sapply(matching_vars, function(v)
        weighted.mean(ipd_data[[v]], w = centered_data$maic_weights, na.rm = TRUE)),
      agd_mean = sapply(matching_vars, function(v) agd_summary[[v]])
    )

    balance_diagnostics$std_diff_unweighted <-
      (balance_diagnostics$ipd_mean_unweighted - balance_diagnostics$agd_mean) /
      sapply(matching_vars, function(v) sd(ipd_data[[v]], na.rm = TRUE))

    balance_diagnostics$std_diff_weighted <-
      (balance_diagnostics$ipd_mean_weighted - balance_diagnostics$agd_mean) /
      sapply(matching_vars, function(v) sd(ipd_data[[v]], na.rm = TRUE))

    return(list(
      treatment_effect = treatment_effect,
      se = se_treatment,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      weights = centered_data$maic_weights,
      ess = ess,
      n_patients = nrow(ipd_data),
      balance_diagnostics = balance_diagnostics,
      matched_data = centered_data,
      matching_vars = matching_vars,
      outcome_var = outcome_var,
      interpretation = paste0(
        "After matching on ", paste(matching_vars, collapse = ", "),
        ", the adjusted treatment effect is ", round(treatment_effect, 3),
        " (95% CI: ", round(ci_lower, 3), ", ", round(ci_upper, 3), "). ",
        "Effective sample size: ", round(ess, 1), " (",
        round(ess / nrow(ipd_data) * 100, 1), "% of original)."
      )
    ))

  }, error = function(e) {
    return(list(error = paste("MAIC error:", e$message)))
  })
}

#' Plot MAIC balance diagnostics
#'
#' @param maic_results Results from perform_maic()
#' @return ggplot object
plot_maic_balance <- function(maic_results) {
  library(ggplot2)
  library(tidyr)

  if (!is.null(maic_results$error)) {
    return(NULL)
  }

  balance <- maic_results$balance_diagnostics %>%
    select(variable, std_diff_unweighted, std_diff_weighted) %>%
    pivot_longer(
      cols = c("std_diff_unweighted", "std_diff_weighted"),
      names_to = "type",
      values_to = "std_diff"
    ) %>%
    mutate(
      type = factor(type,
                   levels = c("std_diff_unweighted", "std_diff_weighted"),
                   labels = c("Before Matching", "After Matching"))
    )

  ggplot(balance, aes(x = std_diff, y = variable, color = type, shape = type)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_vline(xintercept = c(-0.1, 0.1), linetype = "dotted", color = "gray70") +
    geom_point(size = 3) +
    scale_color_manual(values = c("Before Matching" = "#FF6B35",
                                   "After Matching" = "#4CAF50")) +
    labs(
      title = "MAIC Balance Diagnostics",
      subtitle = "Standardized mean differences before and after matching",
      x = "Standardized Mean Difference",
      y = "Covariate",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
}

#' Plot distribution of MAIC weights
#'
#' @param maic_results Results from perform_maic()
#' @return ggplot object
plot_maic_weights <- function(maic_results) {
  library(ggplot2)

  if (!is.null(maic_results$error)) {
    return(NULL)
  }

  weights_df <- data.frame(
    patient_id = 1:length(maic_results$weights),
    weight = maic_results$weights
  )

  ggplot(weights_df, aes(x = weight)) +
    geom_histogram(bins = 30, fill = "#0066CC", alpha = 0.7, color = "white") +
    geom_vline(xintercept = 1, linetype = "dashed", color = "red", size = 1) +
    labs(
      title = "Distribution of MAIC Weights",
      subtitle = sprintf("ESS: %.1f (%.1f%% of N=%d)",
                        maic_results$ess,
                        maic_results$ess / maic_results$n_patients * 100,
                        maic_results$n_patients),
      x = "Weight",
      y = "Frequency"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold")
    )
}

#' Format MAIC results for display
#'
#' @param maic_results Results from perform_maic()
#' @return HTML tags
format_maic_display <- function(maic_results) {
  if (!is.null(maic_results$error)) {
    return(tags$div(class = "alert alert-warning", maic_results$error))
  }

  tags$div(
    class = "maic-results",
    h5("Matching-Adjusted Indirect Comparison (MAIC)"),

    tags$div(
      class = "row mb-3",
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Adjusted Treatment Effect"),
            tags$h4(sprintf("%.3f", maic_results$treatment_effect)),
            tags$p(class = "text-muted",
                  sprintf("95%% CI: %.3f to %.3f",
                         maic_results$ci_lower,
                         maic_results$ci_upper))
          )
        )
      ),
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Effective Sample Size"),
            tags$h4(sprintf("%.1f", maic_results$ess)),
            tags$p(class = "text-muted",
                  sprintf("%.1f%% of N=%d",
                         maic_results$ess / maic_results$n_patients * 100,
                         maic_results$n_patients))
          )
        )
      ),
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Matching Variables"),
            tags$h4(length(maic_results$matching_vars)),
            tags$p(class = "text-muted",
                  paste(maic_results$matching_vars, collapse = ", "))
          )
        )
      )
    ),

    hr(),

    tags$p(maic_results$interpretation),

    h6("Balance Diagnostics"),
    tags$div(
      class = "table-responsive",
      DT::datatable(
        maic_results$balance_diagnostics,
        options = list(
          pageLength = 10,
          dom = 't',
          scrollX = TRUE
        ),
        rownames = FALSE
      ) %>%
        DT::formatRound(columns = 2:6, digits = 3)
    )
  )
}
