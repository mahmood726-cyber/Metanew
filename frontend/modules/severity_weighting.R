# =============================================================================
# EVIDENCEOS PRIME - SEVERITY WEIGHTING AND PROPORTIONAL SHORTFALL MODULE
# =============================================================================
# Purpose: Severity-based QALY weighting for EU HTA submissions
# Quality: Production-ready with multiple severity metrics
# Version: 1.0 - Complete Implementation
# EU Compliance: Netherlands (ZIN), Sweden (TLV), Norway (NOMA)
# =============================================================================

#' Calculate Proportional Shortfall (Dutch Method)
#'
#' @description
#' Calculates proportional shortfall according to Netherlands (ZIN) methodology.
#' Proportional shortfall represents the proportion of potential healthy life years
#' lost due to disease, used to weight QALYs based on disease severity.
#'
#' @param healthy_life_expectancy Healthy life expectancy in population (years)
#' @param actual_life_expectancy Actual life expectancy with disease (years)
#' @param healthy_utility Utility value for full health (default 1.0)
#' @param actual_utility Average utility with disease [0, 1]
#'
#' @details
#' Proportional shortfall formula (ZIN):
#' \deqn{PS = \frac{(QALE_{healthy} - QALE_{disease})}{QALE_{healthy}}}
#'
#' Where:
#' \itemize{
#'   \item QALE = Quality-Adjusted Life Expectancy
#'   \item QALE_healthy = healthy_life_expectancy × healthy_utility
#'   \item QALE_disease = actual_life_expectancy × actual_utility
#' }
#'
#' Severity categories (ZIN):
#' \itemize{
#'   \item < 0.1: Very low severity
#'   \item 0.1-0.4: Low severity
#'   \item 0.4-0.7: Moderate severity
#'   \item > 0.7: High severity
#' }
#'
#' @return Numeric proportional shortfall value [0, 1]
#' @export
#'
#' @examples
#' \dontrun{
#' # Severe disease example
#' ps <- calculate_proportional_shortfall(
#'   healthy_life_expectancy = 80,
#'   actual_life_expectancy = 50,
#'   healthy_utility = 1.0,
#'   actual_utility = 0.65
#' )
#' # ps ≈ 0.59 (moderate-high severity)
#' }
calculate_proportional_shortfall <- function(healthy_life_expectancy,
                                            actual_life_expectancy,
                                            healthy_utility = 1.0,
                                            actual_utility) {

  # Validate inputs
  if (!is.numeric(healthy_life_expectancy) || healthy_life_expectancy <= 0) {
    stop("healthy_life_expectancy must be positive")
  }

  if (!is.numeric(actual_life_expectancy) || actual_life_expectancy < 0) {
    stop("actual_life_expectancy must be non-negative")
  }

  if (!is.numeric(healthy_utility) || healthy_utility < 0 || healthy_utility > 1) {
    stop("healthy_utility must be between 0 and 1")
  }

  if (!is.numeric(actual_utility) || actual_utility < 0 || actual_utility > 1) {
    stop("actual_utility must be between 0 and 1")
  }

  # Calculate Quality-Adjusted Life Expectancies
  qale_healthy <- healthy_life_expectancy * healthy_utility
  qale_disease <- actual_life_expectancy * actual_utility

  # Calculate proportional shortfall
  if (qale_healthy == 0) {
    warning("Healthy QALE is zero. Returning proportional shortfall of 0.")
    return(0)
  }

  proportional_shortfall <- (qale_healthy - qale_disease) / qale_healthy

  # Ensure bounds [0, 1]
  proportional_shortfall <- max(0, min(1, proportional_shortfall))

  return(proportional_shortfall)
}


#' Calculate Absolute Shortfall
#'
#' @description
#' Calculates absolute shortfall in quality-adjusted life years.
#'
#' @param healthy_life_expectancy Healthy life expectancy (years)
#' @param actual_life_expectancy Actual life expectancy with disease (years)
#' @param healthy_utility Utility for full health (default 1.0)
#' @param actual_utility Average utility with disease [0, 1]
#'
#' @return Numeric absolute shortfall in QALYs
#' @export
calculate_absolute_shortfall <- function(healthy_life_expectancy,
                                        actual_life_expectancy,
                                        healthy_utility = 1.0,
                                        actual_utility) {

  qale_healthy <- healthy_life_expectancy * healthy_utility
  qale_disease <- actual_life_expectancy * actual_utility

  absolute_shortfall <- qale_healthy - qale_disease

  return(max(0, absolute_shortfall))
}


#' Apply Proportional Shortfall QALY Weighting
#'
#' @description
#' Applies proportional shortfall-based weighting to QALYs according to
#' Netherlands (ZIN) methodology. Higher severity diseases receive higher QALY weights.
#'
#' @param qalys Incremental QALYs (unweighted)
#' @param proportional_shortfall Proportional shortfall value [0, 1]
#' @param alpha Severity weighting parameter (default 1.2 for Netherlands)
#'
#' @details
#' Weighting formula (ZIN):
#' \deqn{Weight = 1 + \alpha \times PS}
#'
#' Where:
#' \itemize{
#'   \item α (alpha) = 1.2 (standard ZIN value)
#'   \item PS = proportional shortfall
#' }
#'
#' Examples:
#' \itemize{
#'   \item PS = 0.0 (no severity): Weight = 1.0 (no adjustment)
#'   \item PS = 0.5 (moderate): Weight = 1.6 (60% increase)
#'   \item PS = 0.8 (high): Weight = 1.96 (96% increase)
#' }
#'
#' @return Weighted QALYs
#' @export
apply_proportional_shortfall_weighting <- function(qalys, proportional_shortfall, alpha = 1.2) {

  if (!is.numeric(qalys)) {
    stop("qalys must be numeric")
  }

  if (!is.numeric(proportional_shortfall) || proportional_shortfall < 0 || proportional_shortfall > 1) {
    stop("proportional_shortfall must be between 0 and 1")
  }

  if (!is.numeric(alpha) || alpha < 0) {
    stop("alpha must be non-negative")
  }

  # Calculate weight
  weight <- 1 + alpha * proportional_shortfall

  # Apply weight
  weighted_qalys <- qalys * weight

  return(weighted_qalys)
}


#' Calculate Severity-Adjusted ICER
#'
#' @description
#' Calculates ICER using severity-weighted QALYs (Netherlands/Sweden approach).
#'
#' @param incremental_costs Incremental costs
#' @param incremental_qalys Incremental QALYs (unweighted)
#' @param proportional_shortfall Proportional shortfall [0, 1]
#' @param alpha Severity weighting parameter (default 1.2)
#'
#' @return List with weighted_qalys, weighted_icer, weight_factor
#' @export
calculate_severity_adjusted_icer <- function(incremental_costs,
                                            incremental_qalys,
                                            proportional_shortfall,
                                            alpha = 1.2) {

  # Calculate weight
  weight <- 1 + alpha * proportional_shortfall

  # Apply weighting
  weighted_qalys <- incremental_qalys * weight

  # Calculate severity-adjusted ICER
  if (weighted_qalys == 0) {
    weighted_icer <- Inf
  } else {
    weighted_icer <- incremental_costs / weighted_qalys
  }

  # Calculate standard ICER for comparison
  standard_icer <- if (incremental_qalys == 0) Inf else incremental_costs / incremental_qalys

  results <- list(
    weighted_qalys = weighted_qalys,
    unweighted_qalys = incremental_qalys,
    weight_factor = weight,
    proportional_shortfall = proportional_shortfall,
    alpha = alpha,
    weighted_icer = weighted_icer,
    standard_icer = standard_icer,
    icer_reduction_percent = if (is.finite(standard_icer) && standard_icer > 0) {
      ((standard_icer - weighted_icer) / standard_icer) * 100
    } else {
      NA
    }
  )

  class(results) <- c("severity_adjusted_icer", "list")
  return(results)
}


#' Calculate Swedish Severity Weighting
#'
#' @description
#' Calculates severity weighting according to Swedish TLV methodology.
#' Sweden uses a different approach based on severity categories and
#' ethical platform considerations.
#'
#' @param proportional_shortfall Proportional shortfall [0, 1]
#' @param severity_category Optional severity category override ("low", "moderate", "high")
#'
#' @details
#' Swedish severity categories and weights:
#' \itemize{
#'   \item Low severity (PS < 0.3): Weight = 1.0 (no adjustment)
#'   \item Moderate severity (0.3 ≤ PS < 0.7): Weight = 1.3-1.5
#'   \item High severity (PS ≥ 0.7): Weight = 1.5-2.0
#' }
#'
#' Note: Swedish system is more qualitative and considers broader ethical factors
#' beyond quantitative shortfall calculations.
#'
#' @return List with weight, severity_category, proportional_shortfall
#' @export
calculate_swedish_severity_weight <- function(proportional_shortfall, severity_category = NULL) {

  if (!is.numeric(proportional_shortfall) || proportional_shortfall < 0 || proportional_shortfall > 1) {
    stop("proportional_shortfall must be between 0 and 1")
  }

  # Determine severity category if not provided
  if (is.null(severity_category)) {
    if (proportional_shortfall < 0.3) {
      severity_category <- "low"
    } else if (proportional_shortfall < 0.7) {
      severity_category <- "moderate"
    } else {
      severity_category <- "high"
    }
  }

  # Assign weight based on category
  weight <- switch(severity_category,
                  "low" = 1.0,
                  "moderate" = 1.4,  # Midpoint of 1.3-1.5 range
                  "high" = 1.75,     # Midpoint of 1.5-2.0 range
                  stop(paste0("Invalid severity category: ", severity_category)))

  results <- list(
    weight = weight,
    severity_category = severity_category,
    proportional_shortfall = proportional_shortfall,
    method = "Swedish TLV"
  )

  class(results) <- c("swedish_severity", "list")
  return(results)
}


#' Classify Disease Severity
#'
#' @description
#' Classifies disease severity based on proportional shortfall thresholds
#' used by different European HTA agencies.
#'
#' @param proportional_shortfall Proportional shortfall [0, 1]
#' @param jurisdiction Jurisdiction code ("NL_ZIN", "SE_TLV", "NO_NOMA")
#'
#' @return Character severity classification
#' @export
classify_disease_severity <- function(proportional_shortfall, jurisdiction = "NL_ZIN") {

  if (!is.numeric(proportional_shortfall) || proportional_shortfall < 0 || proportional_shortfall > 1) {
    stop("proportional_shortfall must be between 0 and 1")
  }

  # Netherlands (ZIN) thresholds
  if (jurisdiction == "NL_ZIN") {
    if (proportional_shortfall < 0.1) {
      return("Very Low")
    } else if (proportional_shortfall < 0.4) {
      return("Low")
    } else if (proportional_shortfall < 0.7) {
      return("Moderate")
    } else {
      return("High")
    }
  }

  # Sweden (TLV) thresholds
  if (jurisdiction == "SE_TLV") {
    if (proportional_shortfall < 0.3) {
      return("Low")
    } else if (proportional_shortfall < 0.7) {
      return("Moderate")
    } else {
      return("High")
    }
  }

  # Norway (NOMA) - similar to Sweden
  if (jurisdiction == "NO_NOMA") {
    if (proportional_shortfall < 0.3) {
      return("Low")
    } else if (proportional_shortfall < 0.7) {
      return("Moderate")
    } else {
      return("High")
    }
  }

  # Default classification
  if (proportional_shortfall < 0.4) {
    return("Low-Moderate")
  } else {
    return("Moderate-High")
  }
}


#' Print Severity-Adjusted Results
#'
#' @description
#' Prints severity-adjusted cost-effectiveness results in formatted table.
#'
#' @param severity_results Results from calculate_severity_adjusted_icer()
#' @param currency Currency symbol (default "£")
#'
#' @export
print_severity_adjusted_results <- function(severity_results, currency = "£") {

  if (!inherits(severity_results, "severity_adjusted_icer")) {
    stop("severity_results must be output from calculate_severity_adjusted_icer()")
  }

  cat("\n")
  cat("==============================================================================\n")
  cat("  SEVERITY-ADJUSTED COST-EFFECTIVENESS RESULTS\n")
  cat("==============================================================================\n\n")

  cat("SEVERITY METRICS\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("Proportional Shortfall: %.3f (%.1f%%)\n",
              severity_results$proportional_shortfall,
              severity_results$proportional_shortfall * 100))
  cat(sprintf("Severity Weight (α=%.2f): %.3f\n",
              severity_results$alpha,
              severity_results$weight_factor))
  cat("\n")

  cat("QALY COMPARISON\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("Unweighted QALYs:  %.3f\n", severity_results$unweighted_qalys))
  cat(sprintf("Weighted QALYs:    %.3f (%.1f%% increase)\n",
              severity_results$weighted_qalys,
              ((severity_results$weighted_qalys / severity_results$unweighted_qalys) - 1) * 100))
  cat("\n")

  cat("ICER COMPARISON\n")
  cat("------------------------------------------------------------------------------\n")

  standard_icer_str <- if (is.finite(severity_results$standard_icer)) {
    paste0(currency, format(round(severity_results$standard_icer), big.mark = ","), "/QALY")
  } else {
    "Dominated/Dominates"
  }

  weighted_icer_str <- if (is.finite(severity_results$weighted_icer)) {
    paste0(currency, format(round(severity_results$weighted_icer), big.mark = ","), "/QALY")
  } else {
    "Dominated/Dominates"
  }

  cat(sprintf("Standard ICER:         %s\n", standard_icer_str))
  cat(sprintf("Severity-Adjusted ICER: %s\n", weighted_icer_str))

  if (!is.na(severity_results$icer_reduction_percent)) {
    cat(sprintf("\nICER Reduction: %.1f%%\n", severity_results$icer_reduction_percent))
  }

  cat("==============================================================================\n\n")

  invisible(severity_results)
}


#' Run Severity Weighting Scenario Analysis
#'
#' @description
#' Runs multiple scenarios with different severity assumptions and alpha values.
#'
#' @param incremental_costs Incremental costs
#' @param incremental_qalys Incremental QALYs
#' @param proportional_shortfall Base proportional shortfall
#' @param alpha_values Vector of alpha values to test (default: c(1.0, 1.2, 1.5))
#'
#' @return List of scenario results
#' @export
run_severity_scenarios <- function(incremental_costs,
                                  incremental_qalys,
                                  proportional_shortfall,
                                  alpha_values = c(1.0, 1.2, 1.5)) {

  scenario_results <- list()

  for (alpha in alpha_values) {
    scenario_name <- paste0("alpha_", alpha)

    scenario_results[[scenario_name]] <- calculate_severity_adjusted_icer(
      incremental_costs = incremental_costs,
      incremental_qalys = incremental_qalys,
      proportional_shortfall = proportional_shortfall,
      alpha = alpha
    )
  }

  class(scenario_results) <- c("severity_scenarios", "list")
  return(scenario_results)
}


#' Print Severity Scenario Comparison
#'
#' @description
#' Prints comparison table across multiple severity weighting scenarios.
#'
#' @param severity_scenarios Severity scenarios object from run_severity_scenarios()
#' @param currency Currency symbol (default "£")
#'
#' @export
print_severity_scenarios <- function(severity_scenarios, currency = "£") {

  if (!inherits(severity_scenarios, "severity_scenarios")) {
    stop("severity_scenarios must be output from run_severity_scenarios()")
  }

  scenario_names <- names(severity_scenarios)

  cat("\n")
  cat("==============================================================================\n")
  cat("  SEVERITY WEIGHTING SCENARIO ANALYSIS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("%-15s %10s %12s %15s %15s\n",
              "Scenario", "Alpha", "Weight", "Weighted QALYs", "Weighted ICER"))
  cat("------------------------------------------------------------------------------\n")

  for (scenario_name in scenario_names) {
    result <- severity_scenarios[[scenario_name]]

    icer_str <- if (is.finite(result$weighted_icer)) {
      paste0(currency, format(round(result$weighted_icer), big.mark = ","))
    } else {
      "Dom/Dominates"
    }

    cat(sprintf("%-15s %10.2f %12.3f %15.3f %15s\n",
                scenario_name,
                result$alpha,
                result$weight_factor,
                result$weighted_qalys,
                icer_str))
  }

  cat("==============================================================================\n\n")

  invisible(severity_scenarios)
}


#' Calculate Fair Innings-Based Severity Weight
#'
#' @description
#' Alternative severity weighting based on "fair innings" concept.
#' Younger patients who haven't reached expected lifespan may receive higher weights.
#'
#' @param current_age Current age of patient
#' @param expected_remaining_life Expected remaining life years
#' @param fair_innings_threshold Age threshold for "fair innings" (default 70)
#'
#' @details
#' Fair innings concept: Everyone should have opportunity to reach a certain age
#' before severity weighting tapers off. Common in Norway and some UK contexts.
#'
#' @return Weight factor based on fair innings
#' @export
calculate_fair_innings_weight <- function(current_age,
                                         expected_remaining_life,
                                         fair_innings_threshold = 70) {

  if (!is.numeric(current_age) || current_age < 0) {
    stop("current_age must be non-negative")
  }

  if (!is.numeric(expected_remaining_life) || expected_remaining_life < 0) {
    stop("expected_remaining_life must be non-negative")
  }

  expected_age_at_death <- current_age + expected_remaining_life

  # If patient won't reach fair innings threshold, apply higher weight
  if (expected_age_at_death < fair_innings_threshold) {
    shortfall_years <- fair_innings_threshold - expected_age_at_death
    # Weight increases with years short of fair innings
    weight <- 1 + (shortfall_years / fair_innings_threshold) * 0.5
  } else {
    weight <- 1.0  # Already at or above fair innings
  }

  return(weight)
}

# =============================================================================
# END OF SEVERITY WEIGHTING MODULE
# =============================================================================
