# ============================================================================
# IPD Meta-Analysis - Main Integration Module
# ============================================================================
# High-level interface for IPD meta-analysis
# Integrates data validation, one-stage, and two-stage approaches
# ============================================================================

# Source all backend modules
source("backend/ipd/data_validation.R")
source("backend/ipd/one_stage.R")

#' Run Complete IPD Meta-Analysis
#'
#' Main function for IPD meta-analysis with automatic workflow
#'
#' @param ipd_data Individual patient data frame
#' @param study_var Study identifier column name
#' @param patient_var Patient identifier column name
#' @param outcome_var Outcome variable column name
#' @param treatment_var Treatment variable column name
#' @param covariates Vector of covariate names to adjust for
#' @param outcome_type "binary", "continuous", "survival", or "count"
#' @param method "one_stage" (recommended) or "two_stage"
#' @param random_effects "intercept_only", "intercept_slope", or "complex"
#' @param time_var For survival: time variable name
#' @param event_var For survival: event indicator name
#' @param verbose Print progress messages
#' @return List with fit, results summary, and diagnostics
#' @export
run_ipd_meta_analysis <- function(ipd_data,
                                  study_var = "study_id",
                                  patient_var = "patient_id",
                                  outcome_var = "outcome",
                                  treatment_var = "treatment",
                                  covariates = NULL,
                                  outcome_type = "continuous",
                                  method = "one_stage",
                                  random_effects = "intercept_slope",
                                  time_var = "time",
                                  event_var = "event",
                                  verbose = TRUE) {

  if (verbose) {
    cat("\n")
    cat("╔══════════════════════════════════════════════════════════════╗\n")
    cat("║         EvidenceOS PRIME - IPD Meta-Analysis v4.0           ║\n")
    cat("╚══════════════════════════════════════════════════════════════╝\n")
    cat("\n")
  }

  # =====================
  # STEP 1: Data Validation & Preparation
  # =====================
  if (verbose) cat("⏳ Step 1/4: Validating and preparing IPD data...\n")

  ipd_prep <- prepare_ipd_for_analysis(
    ipd_data = ipd_data,
    study_var = study_var,
    patient_var = patient_var,
    outcome_var = outcome_var,
    treatment_var = treatment_var,
    covariates = covariates,
    outcome_type = outcome_type
  )

  if (verbose) {
    cat(sprintf("  ✓ Patients: %d\n", ipd_prep$n_patients))
    cat(sprintf("  ✓ Studies: %d\n", ipd_prep$n_studies))
    if (ipd_prep$n_removed > 0) {
      cat(sprintf("  ⚠ Removed %d patients with missing data\n", ipd_prep$n_removed))
    }
    cat("\n")
  }

  # =====================
  # STEP 2: Check Data Quality
  # =====================
  if (verbose) cat("⏳ Step 2/4: Checking data quality...\n")

  quality_check <- check_data_quality(
    ipd_prep$data,
    outcome_var = outcome_var,
    treatment_var = treatment_var,
    continuous_vars = covariates
  )

  if (verbose) {
    if (quality_check$n_issues > 0) {
      cat(sprintf("  ⚠ Found %d data quality issues:\n", quality_check$n_issues))
      for (issue in names(quality_check$issues)) {
        cat(sprintf("    - %s\n", quality_check$issues[[issue]]))
      }
    } else {
      cat("  ✓ No major data quality issues\n")
    }
    cat("\n")
  }

  # =====================
  # STEP 3: Fit IPD Model
  # =====================
  if (verbose) cat(sprintf("⏳ Step 3/4: Fitting %s model...\n", method))

  if (method == "one_stage") {

    fit <- if (outcome_type == "binary") {
      fit_binary_outcome_ipd(ipd_prep, random_effects = random_effects, verbose = verbose)
    } else if (outcome_type == "continuous") {
      fit_continuous_outcome_ipd(ipd_prep, random_effects = random_effects, verbose = verbose)
    } else if (outcome_type == "survival") {
      fit_survival_outcome_ipd(ipd_prep, time_var = time_var, event_var = event_var, verbose = verbose)
    } else if (outcome_type == "count") {
      fit_count_outcome_ipd(ipd_prep, verbose = verbose)
    } else {
      stop("Unsupported outcome_type: ", outcome_type)
    }

  } else if (method == "two_stage") {
    # Two-stage implementation
    stop("Two-stage method not yet fully implemented")
    # TODO: Implement two-stage approach
    # Stage 1: Analyze each study separately
    # Stage 2: Meta-analyze study-level estimates with metafor

  } else {
    stop("Method must be 'one_stage' or 'two_stage'")
  }

  if (verbose) cat("\n")

  # =====================
  # STEP 4: Extract Results
  # =====================
  if (verbose) cat("⏳ Step 4/4: Extracting results and diagnostics...\n")

  # Treatment effect
  treatment_effect <- extract_treatment_effect(fit, treatment_var = treatment_var)

  # Study-specific effects
  study_effects <- get_study_specific_effects(fit, study_var = study_var)

  # Model diagnostics
  diagnostics <- list(
    convergence = if (inherits(fit, "lmerMod") || inherits(fit, "glmerMod")) {
      fit@optinfo$conv$opt == 0
    } else TRUE,

    warnings = if (inherits(fit, "lmerMod") || inherits(fit, "glmerMod")) {
      fit@optinfo$warnings
    } else NULL
  )

  if (verbose) {
    cat("  ✓ Treatment effect extracted\n")
    cat("  ✓ Study-specific effects computed\n")
    cat("  ✓ Diagnostics completed\n\n")
  }

  # =====================
  # Final Summary
  # =====================
  if (verbose) {
    cat("╔══════════════════════════════════════════════════════════════╗\n")
    cat("║                    Analysis Complete!                        ║\n")
    cat("╚══════════════════════════════════════════════════════════════╝\n")
    cat("\n")

    cat("Treatment Effect:\n")
    print(treatment_effect, digits = 3)
    cat("\n")

    if (!diagnostics$convergence) {
      cat("⚠️ Warning: Model did not converge properly\n")
    } else {
      cat("✅ Model converged successfully\n")
    }
    cat("\n")
  }

  # =====================
  # Return Results
  # =====================
  results <- list(
    fit = fit,
    treatment_effect = treatment_effect,
    study_effects = study_effects,
    ipd_prep = ipd_prep,
    quality_check = quality_check,
    diagnostics = diagnostics,
    method = method,
    outcome_type = outcome_type
  )

  class(results) <- c("ipd_ma_results", "list")

  return(results)
}


#' Print Method for IPD MA Results
#'
#' @param x ipd_ma_results object
#' @export
print.ipd_ma_results <- function(x, ...) {
  cat("\nIPD Meta-Analysis Results\n")
  cat("=========================\n\n")

  cat("Data:\n")
  cat(sprintf("  Patients: %d\n", x$ipd_prep$n_patients))
  cat(sprintf("  Studies: %d\n", x$ipd_prep$n_studies))
  cat(sprintf("  Outcome type: %s\n", x$outcome_type))
  cat(sprintf("  Method: %s\n", x$method))
  cat("\n")

  cat("Treatment Effect:\n")
  print(x$treatment_effect, row.names = FALSE, digits = 3)
  cat("\n")

  cat("Convergence:", ifelse(x$diagnostics$convergence, "✓ Yes", "✗ No"), "\n\n")

  cat("Use summary() for detailed results\n")
}


#' Summary Method for IPD MA Results
#'
#' @param object ipd_ma_results object
#' @export
summary.ipd_ma_results <- function(object, ...) {
  cat("\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║         IPD Meta-Analysis Summary                            ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")

  # Data summary
  cat("Data Summary:\n")
  cat(sprintf("  Total patients: %d\n", object$ipd_prep$n_patients))
  cat(sprintf("  Number of studies: %d\n", object$ipd_prep$n_studies))
  cat(sprintf("  Outcome type: %s\n", object$outcome_type))
  cat(sprintf("  Analysis method: %s\n", object$method))
  if (length(object$ipd_prep$covariates) > 0) {
    cat("  Covariates:", paste(object$ipd_prep$covariates, collapse = ", "), "\n")
  }
  cat("\n")

  # Study-level summary
  cat("Patients per Study:\n")
  print(object$ipd_prep$study_summary, row.names = FALSE)
  cat("\n")

  # Treatment effect
  cat("Overall Treatment Effect:\n")
  print(object$treatment_effect, row.names = FALSE, digits = 3)
  cat("\n")

  # Study-specific effects
  cat("Study-Specific Effects (Random Effects):\n")
  print(head(object$study_effects, 10), row.names = FALSE, digits = 3)
  if (nrow(object$study_effects) > 10) {
    cat(sprintf("... and %d more studies\n", nrow(object$study_effects) - 10))
  }
  cat("\n")

  # Data quality
  if (object$quality_check$n_issues > 0) {
    cat("Data Quality Issues:\n")
    for (issue in names(object$quality_check$issues)) {
      cat(sprintf("  ⚠ %s\n", object$quality_check$issues[[issue]]))
    }
    cat("\n")
  }

  # Convergence
  cat("Model Diagnostics:\n")
  cat("  Convergence:", ifelse(object$diagnostics$convergence, "✓ Yes", "✗ No"), "\n")
  if (!object$diagnostics$convergence && !is.null(object$diagnostics$warnings)) {
    cat("  Warnings:", paste(object$diagnostics$warnings, collapse = "; "), "\n")
  }

  cat("\n")
}


#' Quick IPD Meta-Analysis
#'
#' Convenience function with sensible defaults
#'
#' @param ipd_data IPD data frame
#' @param outcome_type Type of outcome
#' @param ... Additional arguments passed to run_ipd_meta_analysis()
#' @export
quick_ipd_ma <- function(ipd_data, outcome_type = "continuous", ...) {
  run_ipd_meta_analysis(
    ipd_data = ipd_data,
    outcome_type = outcome_type,
    method = "one_stage",
    random_effects = "intercept_slope",
    verbose = TRUE,
    ...
  )
}


# ============================================================================
# Example Usage
# ============================================================================

# Example 1: Continuous outcome
# ipd_data <- read.csv("my_ipd_data.csv")
# results <- run_ipd_meta_analysis(
#   ipd_data = ipd_data,
#   study_var = "study_id",
#   outcome_var = "response",
#   treatment_var = "treatment",
#   covariates = c("age", "sex", "baseline_severity"),
#   outcome_type = "continuous"
# )
# print(results)
# summary(results)

# Example 2: Binary outcome
# results <- run_ipd_meta_analysis(
#   ipd_data = ipd_data,
#   outcome_var = "event",
#   treatment_var = "treatment",
#   outcome_type = "binary",
#   random_effects = "intercept_slope"
# )

# Example 3: Survival outcome
# results <- run_ipd_meta_analysis(
#   ipd_data = ipd_data,
#   outcome_type = "survival",
#   time_var = "followup_time",
#   event_var = "death"
# )
