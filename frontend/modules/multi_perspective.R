# =============================================================================
# EVIDENCEOS PRIME - MULTI-PERSPECTIVE ANALYSIS MODULE
# =============================================================================
# Purpose: Parallel healthcare and societal perspective cost-effectiveness analysis
# Quality: Production-ready with comprehensive comparison
# Version: 1.0 - Complete Implementation
# EU Compliance: Netherlands (ZIN - mandatory dual), Belgium (KCE), France (HAS)
# =============================================================================

#' Run Multi-Perspective Analysis
#'
#' @description
#' Runs cost-effectiveness analysis from multiple perspectives simultaneously.
#' Required for Netherlands (ZIN) submissions which mandate both healthcare
#' and societal perspectives.
#'
#' @param params Base model parameters (from enhanced_he_model.R)
#' @param base_prob_prog Baseline progression probability
#' @param base_prob_death Baseline death probability
#' @param hr_progression Hazard ratio for progression
#' @param hr_death Hazard ratio for death
#' @param perspectives Character vector of perspectives to analyze (default: c("healthcare", "societal"))
#' @param societal_costs List of additional costs for societal perspective (productivity, caregiver, etc.)
#' @param jurisdiction Jurisdiction code for compliance checking
#'
#' @details
#' Perspectives supported:
#' \itemize{
#'   \item healthcare: Healthcare payer perspective (costs to healthcare system only)
#'   \item societal: Societal perspective (healthcare + productivity + caregiver costs)
#'   \item NHS_PSS: UK NHS/PSS perspective
#'   \item SHI: German Statutory Health Insurance
#' }
#'
#' @return List with results for each perspective and comparative analysis
#' @export
#'
#' @examples
#' \dontrun{
#' # Netherlands (ZIN) - Mandatory dual perspective
#' societal_costs <- list(
#'   productivity_loss_stable = 2000,
#'   productivity_loss_progressed = 5000,
#'   caregiver_cost_stable = 500,
#'   caregiver_cost_progressed = 2000
#' )
#'
#' results <- run_multi_perspective_analysis(
#'   params, base_prob_prog, base_prob_death, hr_prog, hr_death,
#'   perspectives = c("healthcare", "societal"),
#'   societal_costs = societal_costs,
#'   jurisdiction = "NL_ZIN"
#' )
#' }
run_multi_perspective_analysis <- function(params,
                                          base_prob_prog,
                                          base_prob_death,
                                          hr_progression,
                                          hr_death,
                                          perspectives = c("healthcare", "societal"),
                                          societal_costs = NULL,
                                          jurisdiction = NULL) {

  # Source enhanced model if not already loaded
  if (!exists("run_markov_model_enhanced", mode = "function")) {
    source("frontend/modules/enhanced_he_model.R", local = TRUE)
  }

  # ==========================================================================
  # VALIDATE INPUTS
  # ==========================================================================

  if (!is.character(perspectives) || length(perspectives) == 0) {
    stop("perspectives must be a character vector with at least one perspective")
  }

  valid_perspectives <- c("healthcare", "societal", "NHS_PSS", "SHI", "payer", "healthcare_system")
  invalid <- setdiff(perspectives, valid_perspectives)
  if (length(invalid) > 0) {
    stop(paste0("Invalid perspectives: ", paste(invalid, collapse = ", "),
                ". Valid options: ", paste(valid_perspectives, collapse = ", ")))
  }

  # Check for mandatory dual perspective (Netherlands)
  if (!is.null(jurisdiction) && jurisdiction == "NL_ZIN") {
    if (length(perspectives) < 2 || !all(c("healthcare", "societal") %in% perspectives)) {
      warning(paste0("Netherlands (ZIN) requires BOTH healthcare and societal perspectives. ",
                    "You specified: ", paste(perspectives, collapse = ", "), ". ",
                    "Adding missing perspective(s)."))
      perspectives <- unique(c(perspectives, "healthcare", "societal"))
    }
  }

  # Validate societal costs if societal perspective included
  if ("societal" %in% perspectives && is.null(societal_costs)) {
    message("Note: Societal perspective specified but no societal_costs provided. ",
           "Only healthcare costs will be included. Consider providing productivity and caregiver costs.")
  }

  # ==========================================================================
  # RUN ANALYSIS FOR EACH PERSPECTIVE
  # ==========================================================================

  results_by_perspective <- list()

  for (perspective in perspectives) {
    message(paste0("\n========== Running analysis for ", toupper(perspective), " perspective =========="))

    # Create perspective-specific parameters
    params_perspective <- params
    params_perspective$cost_perspective <- perspective

    # Add societal costs if societal perspective
    if (perspective == "societal" && !is.null(societal_costs)) {
      # Add productivity costs
      if (!is.null(societal_costs$productivity_loss_stable)) {
        params_perspective$cost_stable <- params$cost_stable + societal_costs$productivity_loss_stable
      }
      if (!is.null(societal_costs$productivity_loss_progressed)) {
        params_perspective$cost_progressed <- params$cost_progressed + societal_costs$productivity_loss_progressed
      }

      # Add caregiver costs
      if (!is.null(societal_costs$caregiver_cost_stable)) {
        params_perspective$cost_stable <- params_perspective$cost_stable + societal_costs$caregiver_cost_stable
      }
      if (!is.null(societal_costs$caregiver_cost_progressed)) {
        params_perspective$cost_progressed <- params_perspective$cost_progressed + societal_costs$caregiver_cost_progressed
      }

      message(paste0("✓ Societal costs added: ",
                    "Stable state = £", format(params_perspective$cost_stable - params$cost_stable, big.mark = ","), " extra, ",
                    "Progressed = £", format(params_perspective$cost_progressed - params$cost_progressed, big.mark = ","), " extra"))
    }

    # Run model
    result <- run_markov_model_enhanced(
      params = params_perspective,
      base_prob_prog = base_prob_prog,
      base_prob_death = base_prob_death,
      hr_progression = hr_progression,
      hr_death = hr_death,
      validate_inputs = TRUE,
      progress_callback = NULL,
      jurisdiction = jurisdiction
    )

    # Store result
    results_by_perspective[[perspective]] <- result
  }

  # ==========================================================================
  # CREATE COMPARATIVE ANALYSIS
  # ==========================================================================

  comparison <- create_perspective_comparison(results_by_perspective, perspectives)

  # ==========================================================================
  # COMPILE FINAL RESULTS
  # ==========================================================================

  multi_perspective_results <- list(
    perspectives = perspectives,
    results_by_perspective = results_by_perspective,
    comparison = comparison,
    societal_costs_applied = !is.null(societal_costs),
    societal_costs = societal_costs,
    jurisdiction = jurisdiction
  )

  class(multi_perspective_results) <- c("multi_perspective_results", "list")
  return(multi_perspective_results)
}


#' Create Perspective Comparison Table
#'
#' @description
#' Creates comparative analysis across multiple perspectives.
#'
#' @param results_by_perspective List of results for each perspective
#' @param perspectives Character vector of perspective names
#'
#' @return List with comparison metrics
#' @export
create_perspective_comparison <- function(results_by_perspective, perspectives) {

  comparison <- list()

  # Extract key metrics for each perspective
  for (perspective in perspectives) {
    result <- results_by_perspective[[perspective]]

    comparison[[perspective]] <- list(
      total_costs_treatment = result$total_costs_treatment,
      total_costs_comparator = result$total_costs_comparator,
      incremental_costs = result$incremental_costs,
      total_qalys_treatment = result$total_qalys_treatment,
      total_qalys_comparator = result$total_qalys_comparator,
      incremental_qalys = result$incremental_qalys,
      icer = result$icer
    )
  }

  # Calculate differences between perspectives
  if (length(perspectives) >= 2) {
    perspective1 <- perspectives[1]
    perspective2 <- perspectives[2]

    comparison$difference <- list(
      perspective1 = perspective1,
      perspective2 = perspective2,
      incremental_costs_diff = comparison[[perspective2]]$incremental_costs - comparison[[perspective1]]$incremental_costs,
      icer_diff = comparison[[perspective2]]$icer - comparison[[perspective1]]$icer,
      icer_percent_change = if (is.finite(comparison[[perspective1]]$icer) && comparison[[perspective1]]$icer > 0) {
        ((comparison[[perspective2]]$icer - comparison[[perspective1]]$icer) / comparison[[perspective1]]$icer) * 100
      } else {
        NA
      }
    )
  }

  return(comparison)
}


#' Print Multi-Perspective Results
#'
#' @description
#' Prints formatted comparison of results across perspectives.
#'
#' @param multi_perspective_results Results from run_multi_perspective_analysis()
#' @param currency Currency symbol (default "£")
#'
#' @export
print_multi_perspective_results <- function(multi_perspective_results, currency = "£") {

  if (!inherits(multi_perspective_results, "multi_perspective_results")) {
    stop("multi_perspective_results must be output from run_multi_perspective_analysis()")
  }

  perspectives <- multi_perspective_results$perspectives
  comparison <- multi_perspective_results$comparison

  cat("\n")
  cat("==============================================================================\n")
  cat("  MULTI-PERSPECTIVE COST-EFFECTIVENESS ANALYSIS\n")
  cat("==============================================================================\n\n")

  if (!is.null(multi_perspective_results$jurisdiction)) {
    cat(sprintf("Jurisdiction: %s\n", multi_perspective_results$jurisdiction))
    cat(sprintf("Perspectives Analyzed: %s\n\n", paste(perspectives, collapse = ", ")))
  }

  # Print results for each perspective
  cat("RESULTS BY PERSPECTIVE\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("%-20s %15s %12s %15s\n", "Perspective", "Inc. Costs", "Inc. QALYs", "ICER"))
  cat("------------------------------------------------------------------------------\n")

  for (perspective in perspectives) {
    result <- comparison[[perspective]]

    inc_costs_str <- paste0(currency, format(round(result$incremental_costs), big.mark = ","))
    inc_qalys_str <- sprintf("%.3f", result$incremental_qalys)

    icer_str <- if (is.finite(result$icer)) {
      paste0(currency, format(round(result$icer), big.mark = ","), "/QALY")
    } else {
      "Dom/Dominates"
    }

    cat(sprintf("%-20s %15s %12s %15s\n", perspective, inc_costs_str, inc_qalys_str, icer_str))
  }

  # Print comparison if multiple perspectives
  if (length(perspectives) >= 2 && !is.null(comparison$difference)) {
    cat("\n")
    cat("PERSPECTIVE COMPARISON\n")
    cat("------------------------------------------------------------------------------\n")

    diff <- comparison$difference
    cat(sprintf("Comparing: %s vs %s\n\n", diff$perspective2, diff$perspective1))

    diff_costs_str <- paste0(currency, format(round(diff$incremental_costs_diff), big.mark = ","))
    cat(sprintf("Additional incremental costs (%s): %s\n", diff$perspective2, diff_costs_str))

    if (!is.na(diff$icer_percent_change)) {
      cat(sprintf("ICER change: %.1f%%\n", diff$icer_percent_change))
    }

    # Interpretation
    if (diff$incremental_costs_diff > 0) {
      cat(sprintf("\n✓ %s perspective includes additional societal costs\n", diff$perspective2))
    }
  }

  # Societal costs breakdown
  if (multi_perspective_results$societal_costs_applied && !is.null(multi_perspective_results$societal_costs)) {
    cat("\n")
    cat("SOCIETAL COSTS APPLIED\n")
    cat("------------------------------------------------------------------------------\n")

    sc <- multi_perspective_results$societal_costs
    if (!is.null(sc$productivity_loss_stable)) {
      cat(sprintf("Productivity loss (stable): %s%s\n", currency, format(sc$productivity_loss_stable, big.mark = ",")))
    }
    if (!is.null(sc$productivity_loss_progressed)) {
      cat(sprintf("Productivity loss (progressed): %s%s\n", currency, format(sc$productivity_loss_progressed, big.mark = ",")))
    }
    if (!is.null(sc$caregiver_cost_stable)) {
      cat(sprintf("Caregiver costs (stable): %s%s\n", currency, format(sc$caregiver_cost_stable, big.mark = ",")))
    }
    if (!is.null(sc$caregiver_cost_progressed)) {
      cat(sprintf("Caregiver costs (progressed): %s%s\n", currency, format(sc$caregiver_cost_progressed, big.mark = ",")))
    }
  }

  cat("==============================================================================\n\n")

  invisible(multi_perspective_results)
}


#' Create Multi-Perspective Summary Table
#'
#' @description
#' Creates exportable data frame with multi-perspective results.
#'
#' @param multi_perspective_results Results from run_multi_perspective_analysis()
#'
#' @return Data frame with perspective comparison
#' @export
create_multi_perspective_summary <- function(multi_perspective_results) {

  perspectives <- multi_perspective_results$perspectives
  comparison <- multi_perspective_results$comparison

  summary_df <- data.frame(
    Perspective = character(0),
    Total_Costs_Treatment = numeric(0),
    Total_Costs_Comparator = numeric(0),
    Incremental_Costs = numeric(0),
    Total_QALYs_Treatment = numeric(0),
    Total_QALYs_Comparator = numeric(0),
    Incremental_QALYs = numeric(0),
    ICER = numeric(0),
    stringsAsFactors = FALSE
  )

  for (perspective in perspectives) {
    result <- comparison[[perspective]]

    summary_df <- rbind(summary_df, data.frame(
      Perspective = perspective,
      Total_Costs_Treatment = round(result$total_costs_treatment),
      Total_Costs_Comparator = round(result$total_costs_comparator),
      Incremental_Costs = round(result$incremental_costs),
      Total_QALYs_Treatment = round(result$total_qalys_treatment, 3),
      Total_QALYs_Comparator = round(result$total_qalys_comparator, 3),
      Incremental_QALYs = round(result$incremental_qalys, 3),
      ICER = if (is.finite(result$icer)) round(result$icer) else NA,
      stringsAsFactors = FALSE
    ))
  }

  return(summary_df)
}


#' Calculate Societal Costs from Employment Data
#'
#' @description
#' Calculates productivity costs based on employment rates and wage data.
#'
#' @param annual_wage Annual wage for patient population
#' @param employment_rate Employment rate in patient population [0, 1]
#' @param absenteeism_days_per_year Days of work lost per year
#' @param presenteeism_factor Productivity reduction factor when at work [0, 1]
#' @param working_days_per_year Working days per year (default 220)
#'
#' @return Annual productivity cost per patient
#' @export
calculate_productivity_costs <- function(annual_wage,
                                        employment_rate,
                                        absenteeism_days_per_year = 0,
                                        presenteeism_factor = 0,
                                        working_days_per_year = 220) {

  # Validate inputs
  if (!is.numeric(annual_wage) || annual_wage < 0) {
    stop("annual_wage must be non-negative")
  }
  if (!is.numeric(employment_rate) || employment_rate < 0 || employment_rate > 1) {
    stop("employment_rate must be between 0 and 1")
  }
  if (!is.numeric(absenteeism_days_per_year) || absenteeism_days_per_year < 0) {
    stop("absenteeism_days_per_year must be non-negative")
  }
  if (!is.numeric(presenteeism_factor) || presenteeism_factor < 0 || presenteeism_factor > 1) {
    stop("presenteeism_factor must be between 0 and 1")
  }

  # Calculate daily wage
  daily_wage <- annual_wage / working_days_per_year

  # Absenteeism cost (days completely lost)
  absenteeism_cost <- absenteeism_days_per_year * daily_wage

  # Presenteeism cost (reduced productivity while at work)
  days_at_work <- working_days_per_year - absenteeism_days_per_year
  presenteeism_cost <- days_at_work * daily_wage * presenteeism_factor

  # Total productivity loss
  total_productivity_loss <- (absenteeism_cost + presenteeism_cost) * employment_rate

  return(total_productivity_loss)
}


#' Calculate Caregiver Costs
#'
#' @description
#' Calculates informal caregiver costs based on time input and valuation method.
#'
#' @param hours_per_week Hours of informal care per week
#' @param hourly_rate Hourly rate for valuation (replacement cost or opportunity cost)
#' @param weeks_per_year Weeks of care per year (default 52)
#'
#' @return Annual caregiver cost
#' @export
calculate_caregiver_costs <- function(hours_per_week,
                                      hourly_rate,
                                      weeks_per_year = 52) {

  if (!is.numeric(hours_per_week) || hours_per_week < 0) {
    stop("hours_per_week must be non-negative")
  }
  if (!is.numeric(hourly_rate) || hourly_rate < 0) {
    stop("hourly_rate must be non-negative")
  }

  annual_caregiver_cost <- hours_per_week * weeks_per_year * hourly_rate

  return(annual_caregiver_cost)
}


#' Run Netherlands-Compliant Dual Perspective Analysis
#'
#' @description
#' Convenience function for Netherlands (ZIN) mandatory dual perspective analysis.
#'
#' @param params Base model parameters
#' @param base_prob_prog Baseline progression probability
#' @param base_prob_death Baseline death probability
#' @param hr_progression Hazard ratio for progression
#' @param hr_death Hazard ratio for death
#' @param productivity_costs List with productivity_loss_stable and productivity_loss_progressed
#' @param caregiver_costs List with caregiver_cost_stable and caregiver_cost_progressed
#'
#' @return Multi-perspective results with healthcare and societal perspectives
#' @export
run_netherlands_dual_perspective <- function(params,
                                            base_prob_prog,
                                            base_prob_death,
                                            hr_progression,
                                            hr_death,
                                            productivity_costs = NULL,
                                            caregiver_costs = NULL) {

  # Combine societal costs
  societal_costs <- list()

  if (!is.null(productivity_costs)) {
    societal_costs$productivity_loss_stable <- productivity_costs$productivity_loss_stable
    societal_costs$productivity_loss_progressed <- productivity_costs$productivity_loss_progressed
  }

  if (!is.null(caregiver_costs)) {
    societal_costs$caregiver_cost_stable <- caregiver_costs$caregiver_cost_stable
    societal_costs$caregiver_cost_progressed <- caregiver_costs$caregiver_cost_progressed
  }

  # Run dual perspective analysis
  results <- run_multi_perspective_analysis(
    params = params,
    base_prob_prog = base_prob_prog,
    base_prob_death = base_prob_death,
    hr_progression = hr_progression,
    hr_death = hr_death,
    perspectives = c("healthcare", "societal"),
    societal_costs = if (length(societal_costs) > 0) societal_costs else NULL,
    jurisdiction = "NL_ZIN"
  )

  return(results)
}

# =============================================================================
# END OF MULTI-PERSPECTIVE ANALYSIS MODULE
# =============================================================================
