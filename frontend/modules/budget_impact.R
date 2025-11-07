# =============================================================================
# EVIDENCEOS PRIME - BUDGET IMPACT ANALYSIS MODULE
# =============================================================================
# Purpose: Population-level budget impact analysis for EU HTA submissions
# Quality: Production-ready with comprehensive scenario analysis
# Version: 1.0 - Complete Implementation
# EU Compliance: Netherlands (ZIN), France (HAS), Belgium (KCE), Spain (AEMPS)
# =============================================================================

#' Run Budget Impact Analysis
#'
#' @description
#' Performs population-level budget impact analysis over 3-5 year time horizon.
#' Required for many EU HTA submissions (Netherlands, France, Belgium).
#'
#' @param params List of model parameters (from enhanced_he_model.R)
#' @param bia_params Budget impact specific parameters (see details)
#' @param ce_results Cost-effectiveness results (optional, for consistency)
#'
#' @details
#' Required bia_params structure:
#' \itemize{
#'   \item time_horizon_years: Integer 1-10 (typically 3-5 for BIA)
#'   \item eligible_population_year1: Numeric >= 0 (total eligible population)
#'   \item population_growth_rate: Numeric (annual growth rate, e.g., 0.02 for 2%)
#'   \item market_share_treatment_year1: Numeric [0, 1] (initial market share)
#'   \item market_share_treatment_year5: Numeric [0, 1] (final market share)
#'   \item treatment_duration_years: Numeric > 0 (average treatment duration)
#'   \item currency: Character (e.g., "GBP", "EUR", "SEK")
#' }
#'
#' Optional parameters:
#' \itemize{
#'   \item current_treatment_costs: Numeric (current standard of care costs)
#'   \item displacement_pattern: Character ("linear", "sigmoid", "stepwise")
#'   \item include_indirect_costs: Logical (productivity costs - for societal)
#'   \item discount_rate_bia: Numeric [0, 0.1] (typically lower than CEA or 0%)
#' }
#'
#' @return List with budget impact results and detailed breakdown
#' @export
#'
#' @examples
#' \dontrun{
#' # Netherlands (ZIN) - Mandatory BIA
#' bia_params_nl <- list(
#'   time_horizon_years = 5,
#'   eligible_population_year1 = 50000,
#'   population_growth_rate = 0.01,
#'   market_share_treatment_year1 = 0.05,
#'   market_share_treatment_year5 = 0.30,
#'   treatment_duration_years = 3,
#'   currency = "EUR",
#'   displacement_pattern = "sigmoid"
#' )
#'
#' bia_results <- run_budget_impact_analysis(params, bia_params_nl)
#' print_budget_impact_results(bia_results)
#' }
run_budget_impact_analysis <- function(params, bia_params, ce_results = NULL) {

  # ==========================================================================
  # STEP 1: VALIDATE BIA PARAMETERS
  # ==========================================================================

  if (!is.list(bia_params)) {
    stop("bia_params must be a list")
  }

  # Required parameters
  required_bia <- c("time_horizon_years", "eligible_population_year1",
                    "market_share_treatment_year1", "market_share_treatment_year5")

  missing_bia <- setdiff(required_bia, names(bia_params))
  if (length(missing_bia) > 0) {
    stop(paste0("Missing required BIA parameters: ", paste(missing_bia, collapse = ", ")))
  }

  # Validate time horizon (typically 3-5 years for BIA)
  time_horizon <- bia_params$time_horizon_years
  if (!is.numeric(time_horizon) || time_horizon < 1 || time_horizon > 10) {
    stop("time_horizon_years must be between 1 and 10. Typical range: 3-5 years.")
  }
  time_horizon <- as.integer(time_horizon)

  # Validate population
  pop_year1 <- bia_params$eligible_population_year1
  if (!is.numeric(pop_year1) || pop_year1 < 0) {
    stop("eligible_population_year1 must be non-negative")
  }

  # Validate market shares
  ms_year1 <- bia_params$market_share_treatment_year1
  if (!is.numeric(ms_year1) || ms_year1 < 0 || ms_year1 > 1) {
    stop("market_share_treatment_year1 must be between 0 and 1")
  }

  ms_year_final <- bia_params$market_share_treatment_year5
  if (!is.numeric(ms_year_final) || ms_year_final < 0 || ms_year_final > 1) {
    stop("market_share_treatment_year5 must be between 0 and 1")
  }

  # Default parameters
  pop_growth_rate <- if (!is.null(bia_params$population_growth_rate)) {
    bia_params$population_growth_rate
  } else {
    0  # No growth by default
  }

  treatment_duration <- if (!is.null(bia_params$treatment_duration_years)) {
    bia_params$treatment_duration_years
  } else {
    1  # Annual treatment by default
  }

  displacement <- if (!is.null(bia_params$displacement_pattern)) {
    bia_params$displacement_pattern
  } else {
    "linear"
  }

  discount_rate_bia <- if (!is.null(bia_params$discount_rate_bia)) {
    bia_params$discount_rate_bia
  } else {
    0  # No discounting for BIA by default (common practice)
  }

  currency <- if (!is.null(bia_params$currency)) {
    bia_params$currency
  } else {
    "GBP"
  }

  # ==========================================================================
  # STEP 2: CALCULATE ELIGIBLE POPULATION OVER TIME
  # ==========================================================================

  eligible_population <- numeric(time_horizon)
  eligible_population[1] <- pop_year1

  for (year in 2:time_horizon) {
    eligible_population[year] <- eligible_population[year - 1] * (1 + pop_growth_rate)
  }

  # ==========================================================================
  # STEP 3: CALCULATE MARKET SHARE TRAJECTORY
  # ==========================================================================

  market_share_treatment <- calculate_market_share_trajectory(
    ms_year1, ms_year_final, time_horizon, displacement
  )

  market_share_comparator <- 1 - market_share_treatment

  # ==========================================================================
  # STEP 4: CALCULATE NUMBER OF PATIENTS
  # ==========================================================================

  # Incident patients (new starts each year)
  incident_patients_treatment <- eligible_population * market_share_treatment
  incident_patients_comparator <- eligible_population * market_share_comparator

  # Prevalent patients (accounting for treatment duration)
  prevalent_patients_treatment <- numeric(time_horizon)
  prevalent_patients_comparator <- numeric(time_horizon)

  for (year in 1:time_horizon) {
    # Prevalent = incident in this year + carryover from previous years
    if (year == 1) {
      prevalent_patients_treatment[year] <- incident_patients_treatment[year]
      prevalent_patients_comparator[year] <- incident_patients_comparator[year]
    } else {
      # Add new incident + fraction of previous patients still on treatment
      years_back <- min(year - 1, floor(treatment_duration))
      carryover_treatment <- 0
      carryover_comparator <- 0

      for (y_back in 1:years_back) {
        fraction_remaining <- max(0, 1 - (y_back / treatment_duration))
        carryover_treatment <- carryover_treatment +
          incident_patients_treatment[year - y_back] * fraction_remaining
        carryover_comparator <- carryover_comparator +
          incident_patients_comparator[year - y_back] * fraction_remaining
      }

      prevalent_patients_treatment[year] <- incident_patients_treatment[year] + carryover_treatment
      prevalent_patients_comparator[year] <- incident_patients_comparator[year] + carryover_comparator
    }
  }

  # ==========================================================================
  # STEP 5: CALCULATE COSTS
  # ==========================================================================

  # Extract cost parameters
  cost_treatment_annual <- params$cost_treatment
  cost_comparator_annual <- params$cost_comparator
  cost_stable <- if (!is.null(params$cost_stable)) params$cost_stable else 0
  cost_progressed <- if (!is.null(params$cost_progressed)) params$cost_progressed else 0

  # Total treatment costs include drug cost + disease management costs
  total_cost_treatment_per_patient <- cost_treatment_annual + cost_stable
  total_cost_comparator_per_patient <- cost_comparator_annual + cost_stable

  # Annual total costs
  annual_cost_treatment_arm <- prevalent_patients_treatment * total_cost_treatment_per_patient
  annual_cost_comparator_arm <- prevalent_patients_comparator * total_cost_comparator_per_patient

  # Total costs (with vs without new treatment)
  total_cost_with_treatment <- annual_cost_treatment_arm + annual_cost_comparator_arm
  total_cost_without_treatment <- eligible_population * total_cost_comparator_per_patient

  # Incremental budget impact
  incremental_budget_impact <- total_cost_with_treatment - total_cost_without_treatment

  # ==========================================================================
  # STEP 6: APPLY DISCOUNTING (IF SPECIFIED)
  # ==========================================================================

  if (discount_rate_bia > 0) {
    discount_factors <- (1 + discount_rate_bia) ^ (0:(time_horizon - 1))
    incremental_budget_impact_discounted <- incremental_budget_impact / discount_factors
  } else {
    incremental_budget_impact_discounted <- incremental_budget_impact
  }

  # ==========================================================================
  # STEP 7: CALCULATE CUMULATIVE BUDGET IMPACT
  # ==========================================================================

  cumulative_budget_impact <- cumsum(incremental_budget_impact_discounted)

  # Total over entire time horizon
  total_budget_impact <- sum(incremental_budget_impact_discounted)

  # ==========================================================================
  # STEP 8: COMPILE RESULTS
  # ==========================================================================

  results <- list(
    # Summary metrics
    total_budget_impact = total_budget_impact,
    total_budget_impact_3yr = if (time_horizon >= 3) cumulative_budget_impact[3] else NA,
    total_budget_impact_5yr = if (time_horizon >= 5) cumulative_budget_impact[5] else NA,
    currency = currency,

    # Annual breakdown
    years = 1:time_horizon,
    eligible_population = eligible_population,
    market_share_treatment = market_share_treatment,
    market_share_comparator = market_share_comparator,

    # Patient numbers
    incident_patients_treatment = incident_patients_treatment,
    incident_patients_comparator = incident_patients_comparator,
    prevalent_patients_treatment = prevalent_patients_treatment,
    prevalent_patients_comparator = prevalent_patients_comparator,

    # Costs
    annual_cost_treatment_arm = annual_cost_treatment_arm,
    annual_cost_comparator_arm = annual_cost_comparator_arm,
    total_cost_with_treatment = total_cost_with_treatment,
    total_cost_without_treatment = total_cost_without_treatment,
    incremental_budget_impact = incremental_budget_impact,
    incremental_budget_impact_discounted = incremental_budget_impact_discounted,
    cumulative_budget_impact = cumulative_budget_impact,

    # Parameters
    bia_params = bia_params,
    discount_rate_bia = discount_rate_bia
  )

  class(results) <- c("bia_results", "list")
  return(results)
}


#' Calculate Market Share Trajectory
#'
#' @description
#' Calculates market share evolution over time using different displacement patterns.
#'
#' @param ms_initial Initial market share [0, 1]
#' @param ms_final Final market share [0, 1]
#' @param time_horizon Number of years
#' @param pattern Displacement pattern: "linear", "sigmoid", "stepwise"
#'
#' @return Numeric vector of market shares for each year
#' @export
calculate_market_share_trajectory <- function(ms_initial, ms_final, time_horizon, pattern = "linear") {

  market_share <- numeric(time_horizon)

  if (pattern == "linear") {
    # Linear uptake from initial to final
    for (year in 1:time_horizon) {
      fraction <- (year - 1) / (time_horizon - 1)
      market_share[year] <- ms_initial + (ms_final - ms_initial) * fraction
    }

  } else if (pattern == "sigmoid") {
    # S-shaped (sigmoid) uptake - more realistic
    # Slow start, rapid middle, plateau at end
    midpoint <- time_horizon / 2
    steepness <- 4 / time_horizon  # Controls curve steepness

    for (year in 1:time_horizon) {
      # Logistic function centered at midpoint
      x <- (year - midpoint) * steepness
      sigmoid_value <- 1 / (1 + exp(-x))
      market_share[year] <- ms_initial + (ms_final - ms_initial) * sigmoid_value
    }

  } else if (pattern == "stepwise") {
    # Stepwise uptake - sudden increase at midpoint
    midpoint <- ceiling(time_horizon / 2)

    for (year in 1:time_horizon) {
      if (year < midpoint) {
        market_share[year] <- ms_initial
      } else {
        # Linear ramp after midpoint
        fraction <- (year - midpoint) / (time_horizon - midpoint)
        market_share[year] <- ms_initial + (ms_final - ms_initial) * fraction
      }
    }

  } else {
    stop(paste0("Unknown displacement pattern: '", pattern, "'. ",
               "Valid options: 'linear', 'sigmoid', 'stepwise'"))
  }

  # Ensure bounds [0, 1]
  market_share <- pmax(0, pmin(1, market_share))

  return(market_share)
}


#' Print Budget Impact Results
#'
#' @description
#' Formats and prints budget impact analysis results in a clear table format.
#'
#' @param bia_results Budget impact results object from run_budget_impact_analysis()
#' @param detailed Whether to print detailed year-by-year breakdown (default TRUE)
#'
#' @export
print_budget_impact_results <- function(bia_results, detailed = TRUE) {

  if (!inherits(bia_results, "bia_results")) {
    stop("bia_results must be output from run_budget_impact_analysis()")
  }

  currency_symbol <- switch(bia_results$currency,
                            "GBP" = "£",
                            "EUR" = "€",
                            "USD" = "$",
                            "SEK" = "SEK",
                            "DKK" = "DKK",
                            "NOK" = "NOK",
                            bia_results$currency)

  cat("\n")
  cat("==============================================================================\n")
  cat("  BUDGET IMPACT ANALYSIS RESULTS\n")
  cat("==============================================================================\n\n")

  # Summary metrics
  cat("SUMMARY METRICS\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("Total Budget Impact (%d years): %s%s\n",
              length(bia_results$years),
              currency_symbol,
              format(round(bia_results$total_budget_impact), big.mark = ",")))

  if (!is.na(bia_results$total_budget_impact_3yr)) {
    cat(sprintf("Total Budget Impact (3 years):  %s%s\n",
                currency_symbol,
                format(round(bia_results$total_budget_impact_3yr), big.mark = ",")))
  }

  if (!is.na(bia_results$total_budget_impact_5yr)) {
    cat(sprintf("Total Budget Impact (5 years):  %s%s\n",
                currency_symbol,
                format(round(bia_results$total_budget_impact_5yr), big.mark = ",")))
  }

  cat(sprintf("\nDiscount Rate: %.1f%%\n", bia_results$discount_rate_bia * 100))
  cat(sprintf("Currency: %s\n", bia_results$currency))

  # Year-by-year breakdown
  if (detailed) {
    cat("\n")
    cat("YEAR-BY-YEAR BREAKDOWN\n")
    cat("------------------------------------------------------------------------------\n")
    cat(sprintf("%-6s %12s %10s %12s %15s %15s\n",
                "Year", "Eligible Pop", "Mkt Share", "Prevalent Pts", "Annual Cost",
                "Cumulative BI"))
    cat("------------------------------------------------------------------------------\n")

    for (i in 1:length(bia_results$years)) {
      cat(sprintf("%-6d %12s %9.1f%% %12s %s%14s %s%14s\n",
                  bia_results$years[i],
                  format(round(bia_results$eligible_population[i]), big.mark = ","),
                  bia_results$market_share_treatment[i] * 100,
                  format(round(bia_results$prevalent_patients_treatment[i]), big.mark = ","),
                  currency_symbol,
                  format(round(bia_results$incremental_budget_impact_discounted[i]), big.mark = ","),
                  currency_symbol,
                  format(round(bia_results$cumulative_budget_impact[i]), big.mark = ",")))
    }
  }

  cat("==============================================================================\n\n")

  invisible(bia_results)
}


#' Create Budget Impact Summary Table
#'
#' @description
#' Creates a summary data frame for export to reports or visualization.
#'
#' @param bia_results Budget impact results object
#'
#' @return Data frame with budget impact summary
#' @export
create_bia_summary_table <- function(bia_results) {

  summary_table <- data.frame(
    Year = bia_results$years,
    Eligible_Population = round(bia_results$eligible_population),
    Market_Share_Percent = round(bia_results$market_share_treatment * 100, 1),
    Incident_Patients = round(bia_results$incident_patients_treatment),
    Prevalent_Patients = round(bia_results$prevalent_patients_treatment),
    Annual_Budget_Impact = round(bia_results$incremental_budget_impact_discounted),
    Cumulative_Budget_Impact = round(bia_results$cumulative_budget_impact),
    stringsAsFactors = FALSE
  )

  return(summary_table)
}


#' Run Budget Impact Scenario Analysis
#'
#' @description
#' Runs multiple budget impact scenarios with varying assumptions.
#' Common scenarios: optimistic uptake, pessimistic uptake, alternative population sizes.
#'
#' @param params Model parameters
#' @param bia_params_base Base case BIA parameters
#' @param scenarios Character vector of scenario names (see details)
#'
#' @details
#' Built-in scenarios:
#' \itemize{
#'   \item "low_uptake" - Conservative market share (50% of base)
#'   \item "high_uptake" - Optimistic market share (150% of base, max 1)
#'   \item "low_population" - 75% of base eligible population
#'   \item "high_population" - 125% of base eligible population
#'   \item "no_growth" - Zero population growth
#'   \item "high_growth" - Double population growth rate
#' }
#'
#' @return List of scenario results
#' @export
run_bia_scenarios <- function(params, bia_params_base, scenarios = NULL) {

  if (is.null(scenarios)) {
    scenarios <- c("low_uptake", "high_uptake", "low_population", "high_population")
  }

  scenario_results <- list()
  scenario_results$base_case <- run_budget_impact_analysis(params, bia_params_base)

  for (scenario_name in scenarios) {
    bia_params_scenario <- bia_params_base

    if (scenario_name == "low_uptake") {
      bia_params_scenario$market_share_treatment_year1 <-
        bia_params_base$market_share_treatment_year1 * 0.5
      bia_params_scenario$market_share_treatment_year5 <-
        bia_params_base$market_share_treatment_year5 * 0.5

    } else if (scenario_name == "high_uptake") {
      bia_params_scenario$market_share_treatment_year1 <-
        min(1, bia_params_base$market_share_treatment_year1 * 1.5)
      bia_params_scenario$market_share_treatment_year5 <-
        min(1, bia_params_base$market_share_treatment_year5 * 1.5)

    } else if (scenario_name == "low_population") {
      bia_params_scenario$eligible_population_year1 <-
        bia_params_base$eligible_population_year1 * 0.75

    } else if (scenario_name == "high_population") {
      bia_params_scenario$eligible_population_year1 <-
        bia_params_base$eligible_population_year1 * 1.25

    } else if (scenario_name == "no_growth") {
      bia_params_scenario$population_growth_rate <- 0

    } else if (scenario_name == "high_growth") {
      bia_params_scenario$population_growth_rate <-
        (bia_params_base$population_growth_rate %||% 0) * 2

    } else {
      warning(paste0("Unknown scenario: '", scenario_name, "'. Skipping."))
      next
    }

    scenario_results[[scenario_name]] <- run_budget_impact_analysis(params, bia_params_scenario)
  }

  class(scenario_results) <- c("bia_scenarios", "list")
  return(scenario_results)
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}


#' Print Budget Impact Scenario Comparison
#'
#' @description
#' Prints comparison table across multiple BIA scenarios.
#'
#' @param bia_scenarios BIA scenarios object from run_bia_scenarios()
#'
#' @export
print_bia_scenarios <- function(bia_scenarios) {

  if (!inherits(bia_scenarios, "bia_scenarios")) {
    stop("bia_scenarios must be output from run_bia_scenarios()")
  }

  scenario_names <- names(bia_scenarios)
  currency <- bia_scenarios[[1]]$currency
  currency_symbol <- switch(currency,
                           "GBP" = "£",
                           "EUR" = "€",
                           "USD" = "$",
                           currency)

  cat("\n")
  cat("==============================================================================\n")
  cat("  BUDGET IMPACT SCENARIO ANALYSIS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("%-20s %20s %20s\n", "Scenario", "3-Year Impact", "5-Year Impact"))
  cat("------------------------------------------------------------------------------\n")

  for (scenario_name in scenario_names) {
    result <- bia_scenarios[[scenario_name]]

    impact_3yr <- if (!is.na(result$total_budget_impact_3yr)) {
      paste0(currency_symbol, format(round(result$total_budget_impact_3yr), big.mark = ","))
    } else {
      "N/A"
    }

    impact_5yr <- if (!is.na(result$total_budget_impact_5yr)) {
      paste0(currency_symbol, format(round(result$total_budget_impact_5yr), big.mark = ","))
    } else {
      "N/A"
    }

    cat(sprintf("%-20s %20s %20s\n", scenario_name, impact_3yr, impact_5yr))
  }

  cat("==============================================================================\n\n")

  invisible(bia_scenarios)
}

# =============================================================================
# END OF BUDGET IMPACT ANALYSIS MODULE
# =============================================================================
