# =============================================================================
# EVIDENCEOS PRIME - SCENARIO ANALYSIS FRAMEWORK (NICE COMPLIANCE)
# =============================================================================
# Purpose: Systematic scenario analysis for NICE submissions
# Quality: Production-ready with comprehensive NICE guidance
# Version: 1.0
# =============================================================================

source("frontend/modules/enhanced_he_model.R", local = TRUE)

#' Run Systematic Scenario Analyses (NICE-specific)
#'
#' @description
#' Performs comprehensive scenario analyses required by NICE, including:
#' - Alternative discount rates
#' - Alternative time horizons
#' - Alternative utility sources
#' - Societal perspective (with productivity costs)
#' - Extreme parameter values
#' - Treatment effect duration
#'
#' @param base_params Base case parameter list
#' @param base_prob_prog Baseline probability of progression
#' @param base_prob_death Baseline probability of death
#' @param hr_progression Hazard ratio for progression
#' @param hr_death Hazard ratio for death
#' @param scenarios Character vector of scenarios to run (default: all)
#' @param progress_callback Function to call with progress updates
#'
#' @return List with scenario results
#' @export
run_scenario_analyses <- function(base_params,
                                  base_prob_prog,
                                  base_prob_death,
                                  hr_progression,
                                  hr_death,
                                  scenarios = c("all"),
                                  progress_callback = NULL) {

  # Define all available scenarios
  all_scenarios <- c(
    "discount_rate_equal",      # Equal 3.5% for costs and health
    "discount_rate_0",          # No discounting
    "discount_rate_6",          # 6% for both (pessimistic)
    "time_horizon_10",          # 10-year horizon
    "time_horizon_30",          # 30-year horizon
    "time_horizon_lifetime",    # Lifetime horizon (50 years)
    "utility_range_lower",      # Lower bound of utility estimates
    "utility_range_upper",      # Upper bound of utility estimates
    "societal_perspective",     # Include productivity costs
    "treatment_effect_waning",  # Treatment effect wanes over time
    "comparator_costs_vary"     # Alternative comparator cost assumptions
  )

  # Expand "all" to specific scenarios
  if ("all" %in% scenarios) {
    scenarios_to_run <- all_scenarios
  } else {
    scenarios_to_run <- scenarios
  }

  results <- list(
    base_case = NULL,
    scenarios = list(),
    summary_table = NULL
  )

  # Run base case
  if (!is.null(progress_callback)) {
    progress_callback("Running base case analysis...")
  }

  results$base_case <- run_markov_model_enhanced(
    params = base_params,
    base_prob_prog = base_prob_prog,
    base_prob_death = base_prob_death,
    hr_progression = hr_progression,
    hr_death = hr_death,
    validate_inputs = TRUE,
    nice_compliant = FALSE  # Scenarios may violate NICE compliance
  )

  # Run each scenario
  for (scenario in scenarios_to_run) {
    if (!is.null(progress_callback)) {
      progress_callback(paste0("Running scenario: ", scenario))
    }

    scenario_params <- create_scenario_params(base_params, scenario)

    scenario_result <- tryCatch({
      run_markov_model_enhanced(
        params = scenario_params$params,
        base_prob_prog = scenario_params$base_prob_prog %||% base_prob_prog,
        base_prob_death = scenario_params$base_prob_death %||% base_prob_death,
        hr_progression = scenario_params$hr_progression %||% hr_progression,
        hr_death = scenario_params$hr_death %||% hr_death,
        validate_inputs = TRUE,
        nice_compliant = FALSE
      )
    }, error = function(e) {
      warning(paste0("Scenario '", scenario, "' failed: ", e$message))
      NULL
    })

    if (!is.null(scenario_result)) {
      results$scenarios[[scenario]] <- scenario_result
    }
  }

  # Create summary table
  results$summary_table <- create_scenario_summary_table(results)

  return(results)
}

#' Create modified parameters for a specific scenario
#' @keywords internal
create_scenario_params <- function(base_params, scenario) {

  params <- base_params
  result <- list(
    params = params,
    base_prob_prog = NULL,
    base_prob_death = NULL,
    hr_progression = NULL,
    hr_death = NULL
  )

  if (scenario == "discount_rate_equal") {
    # Equal 3.5% discounting for both costs and health
    result$params$discount_rate_costs <- 0.035
    result$params$discount_rate_health <- 0.035
    result$params$scenario_description <- "Equal discount rate (3.5% for costs and health)"

  } else if (scenario == "discount_rate_0") {
    # No discounting
    result$params$discount_rate_costs <- 0.0
    result$params$discount_rate_health <- 0.0
    result$params$scenario_description <- "No discounting"

  } else if (scenario == "discount_rate_6") {
    # 6% discounting (pessimistic)
    result$params$discount_rate_costs <- 0.06
    result$params$discount_rate_health <- 0.06
    result$params$scenario_description <- "Higher discount rate (6%)"

  } else if (scenario == "time_horizon_10") {
    # 10-year horizon
    result$params$time_horizon <- 10
    result$params$scenario_description <- "10-year time horizon"

  } else if (scenario == "time_horizon_30") {
    # 30-year horizon
    result$params$time_horizon <- 30
    result$params$scenario_description <- "30-year time horizon"

  } else if (scenario == "time_horizon_lifetime") {
    # Lifetime horizon (50 years)
    result$params$time_horizon <- 50
    result$params$lifetime_horizon <- TRUE
    result$params$scenario_description <- "Lifetime horizon (50 years)"

  } else if (scenario == "utility_range_lower") {
    # Lower bound utilities (conservative)
    if (!is.null(result$params$utility_stable_lower)) {
      result$params$utility_stable <- result$params$utility_stable_lower
    } else {
      result$params$utility_stable <- result$params$utility_stable * 0.90
    }
    if (!is.null(result$params$utility_progressed_lower)) {
      result$params$utility_progressed <- result$params$utility_progressed_lower
    } else {
      result$params$utility_progressed <- result$params$utility_progressed * 0.90
    }
    result$params$scenario_description <- "Lower bound utility values"

  } else if (scenario == "utility_range_upper") {
    # Upper bound utilities (optimistic)
    if (!is.null(result$params$utility_stable_upper)) {
      result$params$utility_stable <- result$params$utility_stable_upper
    } else {
      result$params$utility_stable <- min(1.0, result$params$utility_stable * 1.10)
    }
    if (!is.null(result$params$utility_progressed_upper)) {
      result$params$utility_progressed <- result$params$utility_progressed_upper
    } else {
      result$params$utility_progressed <- min(1.0, result$params$utility_progressed * 1.10)
    }
    result$params$scenario_description <- "Upper bound utility values"

  } else if (scenario == "societal_perspective") {
    # Societal perspective with productivity costs
    result$params$cost_perspective <- "societal"

    # Add productivity costs if not already present
    if (is.null(result$params$cost_productivity_stable)) {
      result$params$cost_productivity_stable <- 5000  # Example annual productivity cost
    }
    if (is.null(result$params$cost_productivity_progressed)) {
      result$params$cost_productivity_progressed <- 10000
    }

    # Add productivity costs to state costs
    result$params$cost_stable <- result$params$cost_stable + result$params$cost_productivity_stable
    result$params$cost_progressed <- result$params$cost_progressed + result$params$cost_productivity_progressed

    result$params$scenario_description <- "Societal perspective (incl. productivity costs)"

  } else if (scenario == "treatment_effect_waning") {
    # Treatment effect wanes after 5 years (example)
    # This would require time-varying HR implementation
    # For now, use reduced HR as approximation
    result$hr_progression <- result$hr_progression %||% list()
    result$hr_death <- result$hr_death %||% list()

    if (!is.null(result$hr_progression$hr)) {
      result$hr_progression$hr <- result$hr_progression$hr * 1.20  # 20% less effective
    }
    if (!is.null(result$hr_death$hr)) {
      result$hr_death$hr <- result$hr_death$hr * 1.20
    }

    result$params$scenario_description <- "Treatment effect waning (20% reduction)"

  } else if (scenario == "comparator_costs_vary") {
    # Alternative comparator costs
    if (!is.null(result$params$cost_comparator_alternative)) {
      result$params$cost_comparator <- result$params$cost_comparator_alternative
    } else {
      result$params$cost_comparator <- result$params$cost_comparator * 1.50  # 50% higher
    }
    result$params$scenario_description <- "Alternative comparator costs (50% higher)"
  }

  return(result)
}

#' Create summary table of scenario results
#' @keywords internal
create_scenario_summary_table <- function(results) {

  scenarios_run <- names(results$scenarios)

  if (length(scenarios_run) == 0) {
    return(NULL)
  }

  summary <- data.frame(
    Scenario = character(),
    Description = character(),
    Inc_QALYs = numeric(),
    Inc_Costs = numeric(),
    ICER = numeric(),
    vs_BaseCase_ICER_Diff = numeric(),
    vs_BaseCase_ICER_PctDiff = numeric(),
    stringsAsFactors = FALSE
  )

  base_icer <- results$base_case$icer

  for (scenario_name in scenarios_run) {
    scenario_result <- results$scenarios[[scenario_name]]

    if (!is.null(scenario_result)) {
      icer_diff <- scenario_result$icer - base_icer
      icer_pct_diff <- if (is.finite(base_icer) && base_icer != 0) {
        (icer_diff / base_icer) * 100
      } else {
        NA
      }

      summary <- rbind(summary, data.frame(
        Scenario = scenario_name,
        Description = scenario_result$params$scenario_description %||% scenario_name,
        Inc_QALYs = scenario_result$inc_qalys,
        Inc_Costs = scenario_result$inc_costs,
        ICER = scenario_result$icer,
        vs_BaseCase_ICER_Diff = icer_diff,
        vs_BaseCase_ICER_PctDiff = icer_pct_diff,
        stringsAsFactors = FALSE
      ))
    }
  }

  return(summary)
}

#' Print scenario analysis summary
#' @export
print_scenario_summary <- function(scenario_results) {

  cat("\n")
  cat("==================================================================\n")
  cat("  SCENARIO ANALYSIS SUMMARY\n")
  cat("==================================================================\n\n")

  # Base case
  cat("BASE CASE:\n")
  cat("  ICER: ", format_icer(scenario_results$base_case$icer), "\n")
  cat("  Incremental QALYs: ", format_number(scenario_results$base_case$inc_qalys, 3), "\n")
  cat("  Incremental Costs: ", format_number(scenario_results$base_case$inc_costs, 0, prefix = "£"), "\n\n")

  # Scenarios
  if (!is.null(scenario_results$summary_table) && nrow(scenario_results$summary_table) > 0) {
    cat("SCENARIOS:\n")
    cat("------------------------------------------------------------------\n")

    for (i in 1:nrow(scenario_results$summary_table)) {
      row <- scenario_results$summary_table[i, ]

      cat(sprintf("[%d] %s\n", i, row$Description))
      cat(sprintf("    ICER: %s", format_icer(row$ICER)))

      if (!is.na(row$vs_BaseCase_ICER_PctDiff)) {
        direction <- if (row$vs_BaseCase_ICER_PctDiff > 0) "↑" else "↓"
        cat(sprintf(" (%s%.1f%% vs base case)\n", direction, abs(row$vs_BaseCase_ICER_PctDiff)))
      } else {
        cat("\n")
      }

      cat(sprintf("    Inc QALYs: %s | Inc Costs: %s\n\n",
                 format_number(row$Inc_QALYs, 3),
                 format_number(row$Inc_Costs, 0, prefix = "£")))
    }
  }

  cat("==================================================================\n\n")
}

#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
