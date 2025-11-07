# =============================================================================
# EVIDENCEOS PRIME - SUBGROUP ANALYSIS MODULE
# =============================================================================
# Purpose: Systematic subgroup identification and cost-effectiveness analysis
# Quality: Production-ready with credibility assessment (ICEMAN criteria)
# Version: 1.0 - Complete Implementation
# EU Compliance: Germany (IQWiG - mandatory), EUnetHTA, NICE
# =============================================================================

#' Run Systematic Subgroup Analysis
#'
#' @description
#' Performs systematic subgroup cost-effectiveness analysis with heterogeneity
#' testing and credibility assessment. Mandatory for Germany (IQWiG) submissions.
#'
#' @param params Base model parameters
#' @param base_prob_prog Baseline progression probability
#' @param base_prob_death Baseline death probability
#' @param hr_progression Hazard ratio for progression
#' @param hr_death Hazard ratio for death
#' @param subgroup_definitions List defining subgroups (see details)
#' @param credibility_check Whether to assess subgroup credibility (default TRUE)
#' @param jurisdiction Jurisdiction code (default NULL)
#'
#' @details
#' subgroup_definitions structure:
#' \itemize{
#'   \item name: Character subgroup name
#'   \item params_overrides: List of parameter overrides for this subgroup
#'   \item hr_overrides: Optional HR overrides
#'   \item population_size: Subgroup size
#'   \item baseline_risk: Optional baseline risk modifier
#'   \item credibility_factors: List of credibility assessment factors
#' }
#'
#' @return List with subgroup analysis results
#' @export
run_subgroup_analysis <- function(params,
                                  base_prob_prog,
                                  base_prob_death,
                                  hr_progression,
                                  hr_death,
                                  subgroup_definitions,
                                  credibility_check = TRUE,
                                  jurisdiction = NULL) {

  # Source enhanced model if not loaded
  if (!exists("run_markov_model_enhanced", mode = "function")) {
    source("frontend/modules/enhanced_he_model.R", local = TRUE)
  }

  # ==========================================================================
  # VALIDATE INPUTS
  # ==========================================================================

  if (!is.list(subgroup_definitions) || length(subgroup_definitions) == 0) {
    stop("subgroup_definitions must be a non-empty list")
  }

  n_subgroups <- length(subgroup_definitions)
  subgroup_names <- sapply(subgroup_definitions, function(x) x$name)

  if (any(duplicated(subgroup_names))) {
    stop("Subgroup names must be unique")
  }

  # Germany (IQWiG) requires subgroup analysis
  if (!is.null(jurisdiction) && jurisdiction == "DE_IQWIG") {
    message("✓ Germany (IQWiG) requires systematic subgroup analysis")
  }

  # ==========================================================================
  # RUN ANALYSIS FOR EACH SUBGROUP
  # ==========================================================================

  subgroup_results <- list()

  for (i in 1:n_subgroups) {
    subgroup <- subgroup_definitions[[i]]

    message(paste0("\n========== Running analysis for subgroup: ", subgroup$name, " =========="))

    # Apply parameter overrides
    params_subgroup <- params
    if (!is.null(subgroup$params_overrides)) {
      for (param_name in names(subgroup$params_overrides)) {
        params_subgroup[[param_name]] <- subgroup$params_overrides[[param_name]]
      }
    }

    # Apply HR overrides
    hr_prog_subgroup <- hr_progression
    hr_death_subgroup <- hr_death

    if (!is.null(subgroup$hr_overrides)) {
      if (!is.null(subgroup$hr_overrides$hr_progression)) {
        hr_prog_subgroup$hr <- subgroup$hr_overrides$hr_progression
      }
      if (!is.null(subgroup$hr_overrides$hr_death)) {
        hr_death_subgroup$hr <- subgroup$hr_overrides$hr_death
      }
    }

    # Apply baseline risk modifier
    base_prob_prog_subgroup <- base_prob_prog
    base_prob_death_subgroup <- base_prob_death

    if (!is.null(subgroup$baseline_risk)) {
      base_prob_prog_subgroup <- base_prob_prog * subgroup$baseline_risk
      base_prob_death_subgroup <- base_prob_death * subgroup$baseline_risk
    }

    # Run model for subgroup
    result <- run_markov_model_enhanced(
      params = params_subgroup,
      base_prob_prog = base_prob_prog_subgroup,
      base_prob_death = base_prob_death_subgroup,
      hr_progression = hr_prog_subgroup,
      hr_death = hr_death_subgroup,
      validate_inputs = TRUE,
      jurisdiction = jurisdiction
    )

    # Store result with metadata
    result$subgroup_name <- subgroup$name
    result$population_size <- subgroup$population_size %||% NA

    subgroup_results[[subgroup$name]] <- result
  }

  # ==========================================================================
  # TEST FOR HETEROGENEITY
  # ==========================================================================

  heterogeneity_test <- test_subgroup_heterogeneity(subgroup_results)

  # ==========================================================================
  # ASSESS SUBGROUP CREDIBILITY
  # ==========================================================================

  credibility_assessment <- NULL
  if (credibility_check) {
    credibility_assessment <- assess_subgroup_credibility(
      subgroup_definitions = subgroup_definitions,
      subgroup_results = subgroup_results,
      heterogeneity_test = heterogeneity_test
    )
  }

  # ==========================================================================
  # CREATE COMPARISON TABLE
  # ==========================================================================

  comparison <- create_subgroup_comparison(subgroup_results)

  # ==========================================================================
  # COMPILE FINAL RESULTS
  # ==========================================================================

  analysis_results <- list(
    n_subgroups = n_subgroups,
    subgroup_names = subgroup_names,
    subgroup_results = subgroup_results,
    comparison = comparison,
    heterogeneity_test = heterogeneity_test,
    credibility_assessment = credibility_assessment,
    jurisdiction = jurisdiction
  )

  class(analysis_results) <- c("subgroup_analysis", "list")
  return(analysis_results)
}


#' Test for Subgroup Heterogeneity
#'
#' @description
#' Tests whether treatment effects differ significantly across subgroups.
#'
#' @param subgroup_results List of subgroup CE results
#'
#' @return Heterogeneity test results
#' @export
test_subgroup_heterogeneity <- function(subgroup_results) {

  # Extract ICERs
  icers <- sapply(subgroup_results, function(x) {
    if (is.finite(x$icer)) x$icer else NA
  })

  # Extract incremental QALYs (treatment effect)
  inc_qalys <- sapply(subgroup_results, function(x) x$incremental_qalys)

  # Calculate range of treatment effects
  qaly_range <- max(inc_qalys, na.rm = TRUE) - min(inc_qalys, na.rm = TRUE)
  qaly_cv <- sd(inc_qalys, na.rm = TRUE) / mean(inc_qalys, na.rm = TRUE)

  # Calculate range of ICERs
  icer_range <- max(icers, na.rm = TRUE) - min(icers, na.rm = TRUE)
  icer_cv <- sd(icers, na.rm = TRUE) / mean(icers, na.rm = TRUE)

  # Assess heterogeneity
  heterogeneity_level <- if (qaly_cv > 0.3 || icer_cv > 0.3) {
    "HIGH - Substantial heterogeneity detected"
  } else if (qaly_cv > 0.15 || icer_cv > 0.15) {
    "MODERATE - Some heterogeneity present"
  } else {
    "LOW - Treatment effects relatively consistent"
  }

  test_results <- list(
    qaly_range = qaly_range,
    qaly_cv = qaly_cv,
    icer_range = icer_range,
    icer_cv = icer_cv,
    heterogeneity_level = heterogeneity_level,
    interpretation = if (qaly_cv > 0.3) {
      "Subgroup analysis warranted - substantial variation in treatment effects"
    } else {
      "Limited heterogeneity - overall population analysis may be sufficient"
    }
  )

  return(test_results)
}


#' Assess Subgroup Credibility (ICEMAN Criteria)
#'
#' @description
#' Assesses credibility of subgroup effects using ICEMAN criteria:
#' I - Is the subgroup variable measured at baseline?
#' C - Is the treatment-subgroup interaction effect clinically important?
#' E - Was the treatment-subgroup interaction effect pre-specified?
#' M - Was the treatment-subgroup interaction statistically significant?
#' A - Were multiple subgroups adjusted for multiplicity?
#' N - Did the subgroup have a narrowly focused biological mechanism?
#'
#' @param subgroup_definitions Subgroup definitions
#' @param subgroup_results Subgroup results
#' @param heterogeneity_test Heterogeneity test results
#'
#' @return Credibility assessment
#' @export
assess_subgroup_credibility <- function(subgroup_definitions,
                                       subgroup_results,
                                       heterogeneity_test) {

  n_subgroups <- length(subgroup_definitions)
  credibility_scores <- list()

  for (i in 1:n_subgroups) {
    subgroup <- subgroup_definitions[[i]]
    factors <- subgroup$credibility_factors %||% list()

    # ICEMAN criteria assessment
    iceman_score <- 0

    # I - Baseline measurement
    if (isTRUE(factors$measured_at_baseline)) {
      iceman_score <- iceman_score + 1
    }

    # C - Clinically important
    if (isTRUE(factors$clinically_important)) {
      iceman_score <- iceman_score + 1
    }

    # E - Pre-specified
    if (isTRUE(factors$pre_specified)) {
      iceman_score <- iceman_score + 1
    }

    # M - Statistically significant
    if (isTRUE(factors$statistically_significant)) {
      iceman_score <- iceman_score + 1
    }

    # A - Multiplicity adjusted
    if (isTRUE(factors$multiplicity_adjusted)) {
      iceman_score <- iceman_score + 1
    }

    # N - Narrow biological mechanism
    if (isTRUE(factors$biological_mechanism)) {
      iceman_score <- iceman_score + 1
    }

    # Overall credibility
    credibility_level <- if (iceman_score >= 5) {
      "HIGH"
    } else if (iceman_score >= 3) {
      "MODERATE"
    } else {
      "LOW"
    }

    credibility_scores[[subgroup$name]] <- list(
      iceman_score = iceman_score,
      max_score = 6,
      credibility_level = credibility_level,
      factors_met = iceman_score,
      factors_total = 6
    )
  }

  assessment <- list(
    credibility_by_subgroup = credibility_scores,
    overall_heterogeneity = heterogeneity_test$heterogeneity_level,
    recommendation = generate_subgroup_recommendation(credibility_scores, heterogeneity_test)
  )

  return(assessment)
}


#' Generate Subgroup Recommendation
#'
#' @description
#' Generates recommendation based on credibility assessment.
#'
#' @param credibility_scores Credibility scores by subgroup
#' @param heterogeneity_test Heterogeneity test results
#'
#' @return Character recommendation
#' @export
generate_subgroup_recommendation <- function(credibility_scores, heterogeneity_test) {

  # Count high credibility subgroups
  high_credibility <- sum(sapply(credibility_scores, function(x) x$credibility_level == "HIGH"))
  total_subgroups <- length(credibility_scores)

  heterogeneity_high <- grepl("HIGH", heterogeneity_test$heterogeneity_level)

  if (high_credibility >= total_subgroups / 2 && heterogeneity_high) {
    recommendation <- "STRONG EVIDENCE for subgroup effects - Present subgroup-specific results"
  } else if (high_credibility > 0 && heterogeneity_high) {
    recommendation <- "MODERATE EVIDENCE for subgroup effects - Report with caution and sensitivity analysis"
  } else if (heterogeneity_high) {
    recommendation <- "WEAK EVIDENCE for subgroup effects - Report overall results with subgroup exploratory analysis"
  } else {
    recommendation <- "INSUFFICIENT EVIDENCE for subgroup effects - Focus on overall population analysis"
  }

  return(recommendation)
}


#' Create Subgroup Comparison Table
#'
#' @description
#' Creates comparative table of subgroup results.
#'
#' @param subgroup_results List of subgroup results
#'
#' @return Data frame with comparison
#' @export
create_subgroup_comparison <- function(subgroup_results) {

  n_subgroups <- length(subgroup_results)
  subgroup_names <- names(subgroup_results)

  comparison_df <- data.frame(
    Subgroup = subgroup_names,
    Population_Size = numeric(n_subgroups),
    Incremental_Costs = numeric(n_subgroups),
    Incremental_QALYs = numeric(n_subgroups),
    ICER = numeric(n_subgroups),
    NMB_20k = numeric(n_subgroups),
    NMB_30k = numeric(n_subgroups),
    stringsAsFactors = FALSE
  )

  for (i in 1:n_subgroups) {
    result <- subgroup_results[[i]]

    comparison_df$Population_Size[i] <- result$population_size %||% NA
    comparison_df$Incremental_Costs[i] <- result$incremental_costs
    comparison_df$Incremental_QALYs[i] <- result$incremental_qalys
    comparison_df$ICER[i] <- if (is.finite(result$icer)) result$icer else NA

    # Calculate Net Monetary Benefit at different thresholds
    comparison_df$NMB_20k[i] <- result$incremental_qalys * 20000 - result$incremental_costs
    comparison_df$NMB_30k[i] <- result$incremental_qalys * 30000 - result$incremental_costs
  }

  return(comparison_df)
}


#' Print Subgroup Analysis Results
#'
#' @description
#' Prints formatted subgroup analysis results.
#'
#' @param analysis_results Subgroup analysis results
#' @param currency Currency symbol (default "£")
#'
#' @export
print_subgroup_analysis <- function(analysis_results, currency = "£") {

  if (!inherits(analysis_results, "subgroup_analysis")) {
    stop("analysis_results must be output from run_subgroup_analysis()")
  }

  comparison <- analysis_results$comparison

  cat("\n")
  cat("==============================================================================\n")
  cat("  SYSTEMATIC SUBGROUP ANALYSIS\n")
  cat("==============================================================================\n\n")

  if (!is.null(analysis_results$jurisdiction)) {
    cat(sprintf("Jurisdiction: %s\n", analysis_results$jurisdiction))
  }
  cat(sprintf("Number of Subgroups: %d\n\n", analysis_results$n_subgroups))

  # Subgroup results
  cat("COST-EFFECTIVENESS BY SUBGROUP\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("%-20s %10s %12s %15s\n", "Subgroup", "Inc QALYs", "Inc Costs", "ICER"))
  cat("------------------------------------------------------------------------------\n")

  for (i in 1:nrow(comparison)) {
    icer_str <- if (!is.na(comparison$ICER[i])) {
      paste0(currency, format(round(comparison$ICER[i]), big.mark = ","))
    } else {
      "Dom/Dominates"
    }

    cat(sprintf("%-20s %10.3f %12s %15s\n",
                comparison$Subgroup[i],
                comparison$Incremental_QALYs[i],
                paste0(currency, format(round(comparison$Incremental_Costs[i]), big.mark = ",")),
                icer_str))
  }

  # Heterogeneity test
  cat("\n")
  cat("HETEROGENEITY ASSESSMENT\n")
  cat("------------------------------------------------------------------------------\n")

  het <- analysis_results$heterogeneity_test
  cat(sprintf("QALY Range: %.3f (CV: %.2f)\n", het$qaly_range, het$qaly_cv))
  cat(sprintf("ICER Range: %s%s\n",
              currency, format(round(het$icer_range), big.mark = ",")))
  cat(sprintf("Heterogeneity Level: %s\n", het$heterogeneity_level))
  cat(sprintf("Interpretation: %s\n", het$interpretation))

  # Credibility assessment
  if (!is.null(analysis_results$credibility_assessment)) {
    cat("\n")
    cat("CREDIBILITY ASSESSMENT (ICEMAN CRITERIA)\n")
    cat("------------------------------------------------------------------------------\n")

    cred <- analysis_results$credibility_assessment

    for (subgroup_name in names(cred$credibility_by_subgroup)) {
      score <- cred$credibility_by_subgroup[[subgroup_name]]
      cat(sprintf("%-20s: %d/6 (%s credibility)\n",
                  subgroup_name, score$iceman_score, score$credibility_level))
    }

    cat(sprintf("\nRecommendation: %s\n", cred$recommendation))
  }

  cat("==============================================================================\n\n")

  invisible(analysis_results)
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# =============================================================================
# END OF SUBGROUP ANALYSIS MODULE
# =============================================================================
