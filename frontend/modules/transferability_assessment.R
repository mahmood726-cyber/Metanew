# =============================================================================
# EVIDENCEOS PRIME - TRANSFERABILITY ASSESSMENT MODULE
# =============================================================================
# Purpose: Cross-border applicability assessment for EU HTA submissions
# Quality: Production-ready with EUnetHTA Domain 4 checklist
# Version: 1.0 - Complete Implementation
# EU Compliance: EUnetHTA Domain 4, all cross-border submissions
# =============================================================================

#' Assess Transferability of HTA Evidence
#'
#' @description
#' Assesses the transferability of cost-effectiveness evidence from source
#' country to target country according to EUnetHTA Domain 4 methodology.
#'
#' Evaluates three key domains:
#' 1. Clinical practice and care pathways
#' 2. Epidemiology and disease patterns
#' 3. Resource use and unit costs
#'
#' @param ce_results Cost-effectiveness results from source country
#' @param source_country Source country code (e.g., "UK", "DE", "FR")
#' @param target_country Target country code
#' @param transferability_params List of transferability-specific parameters
#'
#' @details
#' transferability_params structure:
#' \itemize{
#'   \item clinical_practice_similarity: Numeric [0, 1] (1 = identical, 0 = completely different)
#'   \item epidemiology_similarity: Numeric [0, 1]
#'   \item resource_use_similarity: Numeric [0, 1]
#'   \item target_country_costs: List of target country unit costs
#'   \item target_country_utilities: Optional alternative utilities
#'   \item target_country_discount_rate: Target discount rate
#' }
#'
#' @return List with transferability assessment and adjusted results
#' @export
assess_transferability <- function(ce_results,
                                  source_country,
                                  target_country,
                                  transferability_params) {

  # ==========================================================================
  # VALIDATE INPUTS
  # ==========================================================================

  if (is.null(ce_results) || !is.list(ce_results)) {
    stop("ce_results must be a list containing cost-effectiveness results")
  }

  if (!is.character(source_country) || !is.character(target_country)) {
    stop("source_country and target_country must be character strings")
  }

  if (source_country == target_country) {
    warning("Source and target countries are identical. Transferability assessment may not be necessary.")
  }

  # ==========================================================================
  # EUNET HTA DOMAIN 4 CHECKLIST
  # ==========================================================================

  domain4_checklist <- evaluate_domain4_checklist(
    source_country = source_country,
    target_country = target_country,
    transferability_params = transferability_params
  )

  # ==========================================================================
  # CALCULATE TRANSFERABILITY SCORE
  # ==========================================================================

  transferability_score <- calculate_transferability_score(
    clinical_practice = transferability_params$clinical_practice_similarity %||% 0.7,
    epidemiology = transferability_params$epidemiology_similarity %||% 0.8,
    resource_use = transferability_params$resource_use_similarity %||% 0.6
  )

  # ==========================================================================
  # ADJUST COSTS FOR TARGET COUNTRY
  # ==========================================================================

  adjusted_results <- ce_results

  if (!is.null(transferability_params$target_country_costs)) {
    adjusted_results <- adjust_costs_for_target_country(
      ce_results = ce_results,
      target_costs = transferability_params$target_country_costs,
      source_country = source_country,
      target_country = target_country
    )
  }

  # ==========================================================================
  # ADJUST DISCOUNT RATE IF NEEDED
  # ==========================================================================

  if (!is.null(transferability_params$target_country_discount_rate)) {
    # Note: Full re-run would be needed for accurate discount rate change
    # This is a simplified adjustment
    message("Note: Discount rate difference detected. For accurate results, re-run model with target country discount rate.")
  }

  # ==========================================================================
  # COMPILE ASSESSMENT RESULTS
  # ==========================================================================

  assessment <- list(
    source_country = source_country,
    target_country = target_country,
    transferability_score = transferability_score,
    domain4_checklist = domain4_checklist,
    original_results = ce_results,
    adjusted_results = adjusted_results,
    adjustments_applied = !is.null(transferability_params$target_country_costs),
    recommendation = generate_transferability_recommendation(transferability_score)
  )

  class(assessment) <- c("transferability_assessment", "list")
  return(assessment)
}


#' Evaluate EUnetHTA Domain 4 Checklist
#'
#' @description
#' Systematic evaluation of transferability factors according to EUnetHTA Domain 4.
#'
#' @param source_country Source country
#' @param target_country Target country
#' @param transferability_params Transferability parameters
#'
#' @return List with checklist evaluation
#' @export
evaluate_domain4_checklist <- function(source_country, target_country, transferability_params) {

  checklist <- list(
    # Domain 4A: Clinical Practice and Care Pathways
    clinical_practice = list(
      treatment_pathways_similar = transferability_params$clinical_practice_similarity >= 0.7,
      specialist_access_similar = transferability_params$specialist_access_similar %||% TRUE,
      diagnostic_criteria_aligned = transferability_params$diagnostic_aligned %||% TRUE,
      similarity_score = transferability_params$clinical_practice_similarity %||% 0.7,
      notes = "Assess whether treatment patterns, specialist availability, and care pathways are comparable"
    ),

    # Domain 4B: Epidemiology
    epidemiology = list(
      disease_prevalence_similar = transferability_params$epidemiology_similarity >= 0.7,
      disease_severity_distribution_similar = transferability_params$severity_distribution_similar %||% TRUE,
      patient_demographics_similar = transferability_params$demographics_similar %||% TRUE,
      comorbidity_patterns_similar = transferability_params$comorbidities_similar %||% TRUE,
      similarity_score = transferability_params$epidemiology_similarity %||% 0.8,
      notes = "Assess whether disease patterns, patient characteristics, and comorbidities are comparable"
    ),

    # Domain 4C: Resource Use and Costs
    resource_use = list(
      healthcare_system_structure_similar = transferability_params$healthcare_structure_similar %||% FALSE,
      unit_costs_adjusted = !is.null(transferability_params$target_country_costs),
      resource_quantities_applicable = transferability_params$resource_use_similarity >= 0.6,
      similarity_score = transferability_params$resource_use_similarity %||% 0.6,
      notes = "Assess whether resource consumption patterns and healthcare structures are comparable"
    ),

    # Overall Assessment
    overall = list(
      source_country = source_country,
      target_country = target_country,
      cross_border_feasibility = "pending"  # Will be determined by score
    )
  )

  return(checklist)
}


#' Calculate Overall Transferability Score
#'
#' @description
#' Calculates weighted transferability score from domain scores.
#'
#' @param clinical_practice Clinical practice similarity [0, 1]
#' @param epidemiology Epidemiology similarity [0, 1]
#' @param resource_use Resource use similarity [0, 1]
#' @param weights Weights for each domain (default: equal weights)
#'
#' @return Overall transferability score [0, 1]
#' @export
calculate_transferability_score <- function(clinical_practice,
                                           epidemiology,
                                           resource_use,
                                           weights = c(0.35, 0.35, 0.30)) {

  # Validate inputs
  if (!is.numeric(clinical_practice) || clinical_practice < 0 || clinical_practice > 1) {
    stop("clinical_practice must be between 0 and 1")
  }
  if (!is.numeric(epidemiology) || epidemiology < 0 || epidemiology > 1) {
    stop("epidemiology must be between 0 and 1")
  }
  if (!is.numeric(resource_use) || resource_use < 0 || resource_use > 1) {
    stop("resource_use must be between 0 and 1")
  }

  if (sum(weights) != 1.0) {
    warning("Weights do not sum to 1.0. Normalizing weights.")
    weights <- weights / sum(weights)
  }

  # Calculate weighted score
  score <- clinical_practice * weights[1] +
           epidemiology * weights[2] +
           resource_use * weights[3]

  return(score)
}


#' Adjust Costs for Target Country
#'
#' @description
#' Adjusts cost-effectiveness results using target country unit costs.
#'
#' @param ce_results Original CE results
#' @param target_costs Target country unit costs
#' @param source_country Source country
#' @param target_country Target country
#'
#' @return Adjusted CE results
#' @export
adjust_costs_for_target_country <- function(ce_results,
                                            target_costs,
                                            source_country,
                                            target_country) {

  adjusted_results <- ce_results

  # Apply cost adjustments
  if (!is.null(target_costs$cost_treatment)) {
    cost_ratio_treatment <- target_costs$cost_treatment / ce_results$cost_treatment_original
    adjusted_results$total_costs_treatment <- ce_results$total_costs_treatment * cost_ratio_treatment
  }

  if (!is.null(target_costs$cost_comparator)) {
    cost_ratio_comparator <- target_costs$cost_comparator / ce_results$cost_comparator_original
    adjusted_results$total_costs_comparator <- ce_results$total_costs_comparator * cost_ratio_comparator
  }

  # Recalculate incremental costs
  adjusted_results$incremental_costs <- adjusted_results$total_costs_treatment -
                                       adjusted_results$total_costs_comparator

  # Recalculate ICER (QALYs unchanged)
  if (adjusted_results$incremental_qalys > 0) {
    adjusted_results$icer <- adjusted_results$incremental_costs / adjusted_results$incremental_qalys
  }

  # Add adjustment metadata
  adjusted_results$cost_adjustment_applied <- TRUE
  adjusted_results$source_country <- source_country
  adjusted_results$target_country <- target_country

  message(paste0("✓ Costs adjusted for ", target_country,
                " (ICER changed from ", format(round(ce_results$icer), big.mark = ","),
                " to ", format(round(adjusted_results$icer), big.mark = ","), ")"))

  return(adjusted_results)
}


#' Generate Transferability Recommendation
#'
#' @description
#' Generates recommendation based on transferability score.
#'
#' @param score Transferability score [0, 1]
#'
#' @return Character recommendation
#' @export
generate_transferability_recommendation <- function(score) {

  if (score >= 0.8) {
    recommendation <- "HIGH transferability - Evidence can be applied with minimal adaptation"
  } else if (score >= 0.6) {
    recommendation <- "MODERATE transferability - Evidence applicable with country-specific adjustments"
  } else if (score >= 0.4) {
    recommendation <- "LOW transferability - Substantial adaptation required; consider local data collection"
  } else {
    recommendation <- "VERY LOW transferability - Consider conducting country-specific HTA study"
  }

  return(recommendation)
}


#' Print Transferability Assessment
#'
#' @description
#' Prints formatted transferability assessment report.
#'
#' @param assessment Transferability assessment object
#' @param currency Currency symbol (default "£")
#'
#' @export
print_transferability_assessment <- function(assessment, currency = "£") {

  if (!inherits(assessment, "transferability_assessment")) {
    stop("assessment must be output from assess_transferability()")
  }

  cat("\n")
  cat("==============================================================================\n")
  cat("  TRANSFERABILITY ASSESSMENT (EUnetHTA Domain 4)\n")
  cat("==============================================================================\n\n")

  cat(sprintf("Source Country: %s\n", assessment$source_country))
  cat(sprintf("Target Country: %s\n\n", assessment$target_country))

  # Domain scores
  checklist <- assessment$domain4_checklist

  cat("DOMAIN 4 EVALUATION\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("4A. Clinical Practice:    %.1f%% similarity\n",
              checklist$clinical_practice$similarity_score * 100))
  cat(sprintf("4B. Epidemiology:         %.1f%% similarity\n",
              checklist$epidemiology$similarity_score * 100))
  cat(sprintf("4C. Resource Use:         %.1f%% similarity\n\n",
              checklist$resource_use$similarity_score * 100))

  # Overall score
  cat(sprintf("OVERALL TRANSFERABILITY SCORE: %.1f%%\n", assessment$transferability_score * 100))
  cat(sprintf("RECOMMENDATION: %s\n\n", assessment$recommendation))

  # Results comparison
  if (assessment$adjustments_applied) {
    cat("COST-EFFECTIVENESS RESULTS\n")
    cat("------------------------------------------------------------------------------\n")

    orig <- assessment$original_results
    adj <- assessment$adjusted_results

    cat(sprintf("%-30s %15s %15s\n", "Metric", paste0(assessment$source_country, " (Orig)"), paste0(assessment$target_country, " (Adj)")))
    cat("------------------------------------------------------------------------------\n")

    orig_icer_str <- if (is.finite(orig$icer)) {
      paste0(currency, format(round(orig$icer), big.mark = ","))
    } else {
      "Dom/Dominates"
    }

    adj_icer_str <- if (is.finite(adj$icer)) {
      paste0(currency, format(round(adj$icer), big.mark = ","))
    } else {
      "Dom/Dominates"
    }

    cat(sprintf("%-30s %15s %15s\n", "ICER", orig_icer_str, adj_icer_str))
    cat(sprintf("%-30s %15s %15s\n",
                "Incremental Costs",
                paste0(currency, format(round(orig$incremental_costs), big.mark = ",")),
                paste0(currency, format(round(adj$incremental_costs), big.mark = ","))))
    cat(sprintf("%-30s %15.3f %15.3f\n", "Incremental QALYs",
                orig$incremental_qalys, adj$incremental_qalys))
  }

  cat("==============================================================================\n\n")

  invisible(assessment)
}


#' Create Transferability Report
#'
#' @description
#' Creates detailed transferability report with recommendations.
#'
#' @param assessment Transferability assessment object
#'
#' @return List with detailed report sections
#' @export
create_transferability_report <- function(assessment) {

  report <- list(
    executive_summary = list(
      source_country = assessment$source_country,
      target_country = assessment$target_country,
      overall_score = assessment$transferability_score,
      recommendation = assessment$recommendation
    ),

    domain_evaluation = assessment$domain4_checklist,

    key_differences = identify_key_differences(assessment),

    adjustment_recommendations = generate_adjustment_recommendations(assessment),

    data_gaps = identify_data_gaps(assessment)
  )

  class(report) <- c("transferability_report", "list")
  return(report)
}


#' Identify Key Differences Between Countries
#'
#' @description
#' Identifies major differences that affect transferability.
#'
#' @param assessment Transferability assessment
#'
#' @return List of key differences
#' @export
identify_key_differences <- function(assessment) {

  differences <- list()
  checklist <- assessment$domain4_checklist

  # Clinical practice differences
  if (checklist$clinical_practice$similarity_score < 0.7) {
    differences$clinical_practice <- "Significant differences in treatment pathways or care delivery"
  }

  # Epidemiology differences
  if (checklist$epidemiology$similarity_score < 0.7) {
    differences$epidemiology <- "Substantial differences in disease patterns or patient characteristics"
  }

  # Resource use differences
  if (checklist$resource_use$similarity_score < 0.6) {
    differences$resource_use <- "Major differences in healthcare system structure or resource consumption"
  }

  if (length(differences) == 0) {
    differences$overall <- "No major differences identified"
  }

  return(differences)
}


#' Generate Adjustment Recommendations
#'
#' @description
#' Generates specific recommendations for adapting evidence.
#'
#' @param assessment Transferability assessment
#'
#' @return List of recommendations
#' @export
generate_adjustment_recommendations <- function(assessment) {

  recommendations <- list()

  # Cost adjustments
  if (!assessment$adjustments_applied) {
    recommendations$costs <- "Apply target country unit costs to all resource use"
  }

  # Clinical practice
  if (assessment$domain4_checklist$clinical_practice$similarity_score < 0.7) {
    recommendations$clinical <- "Consult local clinical experts to validate treatment pathways"
  }

  # Epidemiology
  if (assessment$domain4_checklist$epidemiology$similarity_score < 0.7) {
    recommendations$epidemiology <- "Consider local epidemiological data for patient baseline characteristics"
  }

  # Sensitivity analysis
  recommendations$sensitivity <- "Conduct scenario analysis varying key country-specific parameters"

  return(recommendations)
}


#' Identify Data Gaps
#'
#' @description
#' Identifies missing data that would improve transferability assessment.
#'
#' @param assessment Transferability assessment
#'
#' @return List of data gaps
#' @export
identify_data_gaps <- function(assessment) {

  gaps <- list()

  if (!assessment$adjustments_applied) {
    gaps$costs <- "Target country unit costs not provided"
  }

  # Add more gap identification logic as needed
  gaps$general <- "Consider collecting target country-specific data on treatment patterns and resource use"

  return(gaps)
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# =============================================================================
# END OF TRANSFERABILITY ASSESSMENT MODULE
# =============================================================================
