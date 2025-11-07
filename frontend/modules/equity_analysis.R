# =============================================================================
# EVIDENCEOS PRIME - EQUITY ANALYSIS MODULE
# =============================================================================
# Purpose: Distributional cost-effectiveness and health inequality analysis
# Quality: Production-ready with extended CEA framework
# Version: 1.0 - Complete Implementation
# EU Compliance: France (HAS), Belgium (KCE), EUnetHTA ethical considerations
# =============================================================================

#' Run Distributional Cost-Effectiveness Analysis
#'
#' @description
#' Performs distributional cost-effectiveness analysis (DCEA) to assess
#' how health effects are distributed across different population subgroups.
#' Required for France (HAS) and Belgium (KCE) submissions.
#'
#' @param ce_results_by_subgroup List of CE results for each subgroup
#' @param subgroup_sizes Vector of subgroup population sizes
#' @param equity_weights Optional equity weights for subgroups (default: equal)
#' @param reference_group Optional reference subgroup for comparison
#'
#' @details
#' Equity considerations:
#' \itemize{
#'   \item Absolute inequality: Differences in health outcomes between groups
#'   \item Relative inequality: Proportional differences
#'   \item Concentration index: Socioeconomic gradient in health
#'   \item Equity-efficiency tradeoffs: Cost per QALY vs distributional impact
#' }
#'
#' @return List with distributional analysis results
#' @export
run_distributional_cea <- function(ce_results_by_subgroup,
                                  subgroup_sizes,
                                  equity_weights = NULL,
                                  reference_group = NULL) {

  # ==========================================================================
  # VALIDATE INPUTS
  # ==========================================================================

  if (!is.list(ce_results_by_subgroup) || length(ce_results_by_subgroup) == 0) {
    stop("ce_results_by_subgroup must be a non-empty list")
  }

  n_subgroups <- length(ce_results_by_subgroup)
  subgroup_names <- names(ce_results_by_subgroup)

  if (length(subgroup_sizes) != n_subgroups) {
    stop(paste0("subgroup_sizes must have same length as ce_results_by_subgroup (", n_subgroups, ")"))
  }

  # Default equal weights if not provided
  if (is.null(equity_weights)) {
    equity_weights <- rep(1, n_subgroups)
    message("Note: Using equal equity weights for all subgroups. Specify equity_weights for differential weighting.")
  }

  if (length(equity_weights) != n_subgroups) {
    stop(paste0("equity_weights must have same length as number of subgroups (", n_subgroups, ")"))
  }

  # ==========================================================================
  # EXTRACT SUBGROUP RESULTS
  # ==========================================================================

  subgroup_summary <- data.frame(
    Subgroup = subgroup_names,
    Population_Size = subgroup_sizes,
    Equity_Weight = equity_weights,
    Incremental_Costs = numeric(n_subgroups),
    Incremental_QALYs = numeric(n_subgroups),
    ICER = numeric(n_subgroups),
    Total_QALYs_Gained = numeric(n_subgroups),
    Weighted_QALYs = numeric(n_subgroups),
    stringsAsFactors = FALSE
  )

  for (i in 1:n_subgroups) {
    result <- ce_results_by_subgroup[[i]]

    subgroup_summary$Incremental_Costs[i] <- result$incremental_costs
    subgroup_summary$Incremental_QALYs[i] <- result$incremental_qalys
    subgroup_summary$ICER[i] <- if (is.finite(result$icer)) result$icer else NA
    subgroup_summary$Total_QALYs_Gained[i] <- result$incremental_qalys * subgroup_sizes[i]
    subgroup_summary$Weighted_QALYs[i] <- result$incremental_qalys * subgroup_sizes[i] * equity_weights[i]
  }

  # ==========================================================================
  # CALCULATE INEQUALITY METRICS
  # ==========================================================================

  inequality_metrics <- calculate_inequality_metrics(subgroup_summary)

  # ==========================================================================
  # ASSESS EQUITY-EFFICIENCY TRADEOFF
  # ==========================================================================

  tradeoff_analysis <- assess_equity_efficiency_tradeoff(subgroup_summary, reference_group)

  # ==========================================================================
  # COMPILE RESULTS
  # ==========================================================================

  dcea_results <- list(
    n_subgroups = n_subgroups,
    subgroup_names = subgroup_names,
    subgroup_summary = subgroup_summary,
    inequality_metrics = inequality_metrics,
    tradeoff_analysis = tradeoff_analysis,
    total_population_qalys = sum(subgroup_summary$Total_QALYs_Gained),
    equity_weighted_qalys = sum(subgroup_summary$Weighted_QALYs),
    reference_group = reference_group
  )

  class(dcea_results) <- c("dcea_results", "list")
  return(dcea_results)
}


#' Calculate Inequality Metrics
#'
#' @description
#' Calculates various inequality metrics for distributional analysis.
#'
#' @param subgroup_summary Data frame with subgroup results
#'
#' @return List with inequality metrics
#' @export
calculate_inequality_metrics <- function(subgroup_summary) {

  qalys_per_capita <- subgroup_summary$Incremental_QALYs

  # Absolute inequality: Range
  absolute_range <- max(qalys_per_capita, na.rm = TRUE) - min(qalys_per_capita, na.rm = TRUE)

  # Absolute inequality: Standard deviation
  absolute_sd <- sd(qalys_per_capita, na.rm = TRUE)

  # Relative inequality: Coefficient of variation
  mean_qalys <- mean(qalys_per_capita, na.rm = TRUE)
  relative_cv <- if (mean_qalys > 0) absolute_sd / mean_qalys else NA

  # Gini coefficient (simplified)
  gini <- calculate_gini_coefficient(qalys_per_capita, subgroup_summary$Population_Size)

  metrics <- list(
    absolute_range = absolute_range,
    absolute_sd = absolute_sd,
    relative_cv = relative_cv,
    gini_coefficient = gini,
    interpretation = list(
      absolute_range = paste0("Health gains range from ",
                             round(min(qalys_per_capita), 3), " to ",
                             round(max(qalys_per_capita), 3), " QALYs per person"),
      gini = if (!is.na(gini)) {
        if (gini < 0.2) "Low inequality"
        else if (gini < 0.4) "Moderate inequality"
        else "High inequality"
      } else "Unable to calculate"
    )
  )

  return(metrics)
}


#' Calculate Gini Coefficient
#'
#' @description
#' Calculates Gini coefficient for health distribution.
#'
#' @param values Vector of health values (QALYs per capita)
#' @param weights Population weights
#'
#' @return Gini coefficient [0, 1]
#' @export
calculate_gini_coefficient <- function(values, weights) {

  # Remove NA values
  valid_idx <- !is.na(values)
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) < 2) {
    return(NA)
  }

  # Sort by values
  order_idx <- order(values)
  values <- values[order_idx]
  weights <- weights[order_idx]

  # Normalize weights
  weights <- weights / sum(weights)

  # Calculate cumulative proportions
  cum_weights <- cumsum(weights)
  cum_values <- cumsum(values * weights) / sum(values * weights)

  # Gini = 1 - 2 * area under Lorenz curve
  gini <- 1 - sum((cum_weights[-length(cum_weights)] + cum_weights[-1]) *
                  diff(cum_values))

  return(gini)
}


#' Assess Equity-Efficiency Tradeoff
#'
#' @description
#' Assesses tradeoffs between cost-effectiveness (efficiency) and
#' distributional impact (equity).
#'
#' @param subgroup_summary Subgroup summary data frame
#' @param reference_group Optional reference group
#'
#' @return List with tradeoff analysis
#' @export
assess_equity_efficiency_tradeoff <- function(subgroup_summary, reference_group = NULL) {

  # Identify most and least cost-effective subgroups
  valid_icers <- !is.na(subgroup_summary$ICER) & is.finite(subgroup_summary$ICER)

  if (sum(valid_icers) == 0) {
    return(list(
      assessment = "Unable to assess tradeoff - no valid ICERs",
      most_efficient = NA,
      least_efficient = NA
    ))
  }

  most_efficient_idx <- which.min(subgroup_summary$ICER[valid_icers])
  least_efficient_idx <- which.max(subgroup_summary$ICER[valid_icers])

  most_efficient <- subgroup_summary$Subgroup[valid_icers][most_efficient_idx]
  least_efficient <- subgroup_summary$Subgroup[valid_icers][least_efficient_idx]

  # Identify subgroups with largest health gains
  largest_gain_idx <- which.max(subgroup_summary$Total_QALYs_Gained)
  largest_gain_subgroup <- subgroup_summary$Subgroup[largest_gain_idx]

  tradeoff <- list(
    most_cost_effective = most_efficient,
    least_cost_effective = least_efficient,
    largest_absolute_gain = largest_gain_subgroup,
    efficiency_equity_alignment = (most_efficient == largest_gain_subgroup),
    interpretation = if (most_efficient == largest_gain_subgroup) {
      "Efficiency and equity aligned - most cost-effective group also receives largest health gains"
    } else {
      "Efficiency-equity tradeoff present - most cost-effective group differs from group with largest gains"
    }
  )

  return(tradeoff)
}


#' Print Distributional CEA Results
#'
#' @description
#' Prints formatted distributional cost-effectiveness results.
#'
#' @param dcea_results DCEA results from run_distributional_cea()
#' @param currency Currency symbol (default "£")
#'
#' @export
print_distributional_cea <- function(dcea_results, currency = "£") {

  if (!inherits(dcea_results, "dcea_results")) {
    stop("dcea_results must be output from run_distributional_cea()")
  }

  summary <- dcea_results$subgroup_summary

  cat("\n")
  cat("==============================================================================\n")
  cat("  DISTRIBUTIONAL COST-EFFECTIVENESS ANALYSIS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("Number of Subgroups: %d\n", dcea_results$n_subgroups))
  cat(sprintf("Total Population QALYs Gained: %.1f\n", dcea_results$total_population_qalys))
  cat(sprintf("Equity-Weighted QALYs: %.1f\n\n", dcea_results$equity_weighted_qalys))

  # Subgroup results
  cat("RESULTS BY SUBGROUP\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("%-20s %10s %10s %10s %15s\n",
              "Subgroup", "Pop Size", "Inc QALYs", "Total QALYs", "ICER"))
  cat("------------------------------------------------------------------------------\n")

  for (i in 1:nrow(summary)) {
    icer_str <- if (!is.na(summary$ICER[i])) {
      paste0(currency, format(round(summary$ICER[i]), big.mark = ","))
    } else {
      "Dom/Dominates"
    }

    cat(sprintf("%-20s %10s %10.3f %10.1f %15s\n",
                summary$Subgroup[i],
                format(summary$Population_Size[i], big.mark = ","),
                summary$Incremental_QALYs[i],
                summary$Total_QALYs_Gained[i],
                icer_str))
  }

  # Inequality metrics
  cat("\n")
  cat("INEQUALITY METRICS\n")
  cat("------------------------------------------------------------------------------\n")

  metrics <- dcea_results$inequality_metrics

  cat(sprintf("Absolute Range: %.3f QALYs\n", metrics$absolute_range))
  cat(sprintf("Standard Deviation: %.3f QALYs\n", metrics$absolute_sd))
  if (!is.na(metrics$relative_cv)) {
    cat(sprintf("Coefficient of Variation: %.3f\n", metrics$relative_cv))
  }
  if (!is.na(metrics$gini_coefficient)) {
    cat(sprintf("Gini Coefficient: %.3f (%s)\n",
                metrics$gini_coefficient,
                metrics$interpretation$gini))
  }

  # Equity-efficiency tradeoff
  cat("\n")
  cat("EQUITY-EFFICIENCY TRADEOFF\n")
  cat("------------------------------------------------------------------------------\n")

  tradeoff <- dcea_results$tradeoff_analysis

  if (!is.na(tradeoff$most_cost_effective)) {
    cat(sprintf("Most cost-effective subgroup: %s\n", tradeoff$most_cost_effective))
    cat(sprintf("Largest absolute health gain: %s\n", tradeoff$largest_absolute_gain))
    cat(sprintf("\nInterpretation: %s\n", tradeoff$interpretation))
  }

  cat("==============================================================================\n\n")

  invisible(dcea_results)
}


#' Run Extended Cost-Effectiveness Analysis
#'
#' @description
#' Extended CEA (ECEA) framework that explicitly values health maximization
#' and distributional concerns simultaneously.
#'
#' @param ce_results_by_subgroup CE results for each subgroup
#' @param subgroup_sizes Population sizes
#' @param social_value_function Function defining social preferences (default: utilitarian)
#'
#' @return ECEA results
#' @export
run_extended_cea <- function(ce_results_by_subgroup,
                             subgroup_sizes,
                             social_value_function = "utilitarian") {

  # Run distributional CEA first
  dcea_results <- run_distributional_cea(ce_results_by_subgroup, subgroup_sizes)

  # Apply social value function
  if (social_value_function == "utilitarian") {
    # Maximize total QALYs
    social_value <- dcea_results$total_population_qalys

  } else if (social_value_function == "prioritarian") {
    # Give extra weight to worst-off groups
    # Apply concave transformation to give diminishing returns to higher health
    qalys <- dcea_results$subgroup_summary$Incremental_QALYs
    sizes <- dcea_results$subgroup_summary$Population_Size
    prioritarian_weights <- 1 / sqrt(qalys + 1)  # Higher weight for lower QALY groups
    social_value <- sum(qalys * sizes * prioritarian_weights)

  } else if (social_value_function == "egalitarian") {
    # Maximize minimum health gain (maximin)
    min_qalys <- min(dcea_results$subgroup_summary$Incremental_QALYs, na.rm = TRUE)
    social_value <- min_qalys * sum(subgroup_sizes)

  } else {
    stop(paste0("Unknown social value function: ", social_value_function))
  }

  ecea_results <- list(
    dcea_results = dcea_results,
    social_value_function = social_value_function,
    social_value = social_value
  )

  class(ecea_results) <- c("ecea_results", "list")
  return(ecea_results)
}


#' Calculate Health Inequality Impact
#'
#' @description
#' Calculates the impact of an intervention on health inequalities.
#'
#' @param baseline_health Vector of baseline health by subgroup
#' @param treatment_effect Vector of treatment effects by subgroup
#' @param subgroup_sizes Population sizes
#'
#' @return Health inequality impact assessment
#' @export
calculate_health_inequality_impact <- function(baseline_health,
                                               treatment_effect,
                                               subgroup_sizes) {

  # Health after intervention
  post_intervention_health <- baseline_health + treatment_effect

  # Inequality before
  inequality_before <- calculate_inequality_metrics(
    data.frame(Incremental_QALYs = baseline_health, Population_Size = subgroup_sizes)
  )

  # Inequality after
  inequality_after <- calculate_inequality_metrics(
    data.frame(Incremental_QALYs = post_intervention_health, Population_Size = subgroup_sizes)
  )

  # Change in inequality
  inequality_change <- list(
    gini_before = inequality_before$gini_coefficient,
    gini_after = inequality_after$gini_coefficient,
    gini_change = inequality_after$gini_coefficient - inequality_before$gini_coefficient,
    interpretation = if (inequality_after$gini_coefficient < inequality_before$gini_coefficient) {
      "Intervention REDUCES health inequality"
    } else if (inequality_after$gini_coefficient > inequality_before$gini_coefficient) {
      "Intervention INCREASES health inequality"
    } else {
      "Intervention has NEUTRAL effect on health inequality"
    }
  )

  return(inequality_change)
}

# =============================================================================
# END OF EQUITY ANALYSIS MODULE
# =============================================================================
