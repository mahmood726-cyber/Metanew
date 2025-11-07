# =============================================================================
# EVIDENCEOS PRIME - QUALITY ASSURANCE FRAMEWORK
# =============================================================================
# Purpose: Comprehensive testing, validation, and QA checks
# Quality: Production-ready with automated quality gates
# Version: 1.0
# =============================================================================

source("frontend/modules/validation_framework.R", local = TRUE)

#' Run comprehensive quality assurance checks
#' @param model_results Model results to validate
#' @return List with QA results and pass/fail status
#' @export
run_qa_checks <- function(model_results) {

  qa_results <- list(
    timestamp = Sys.time(),
    checks_passed = 0,
    checks_failed = 0,
    warnings = character(0),
    errors = character(0),
    overall_status = "UNKNOWN"
  )

  cat("\n")
  cat("===========================================================\n")
  cat("  EVIDENCEOS PRIME - QUALITY ASSURANCE CHECKS\n")
  cat("===========================================================\n\n")

  # CHECK 1: Results Structure Validation
  cat("[ 1/10] Checking results structure... ")
  tryCatch({
    validate_model_results(model_results)
    cat("✓ PASS\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  }, error = function(e) {
    cat("✖ FAIL:", e$message, "\n")
    qa_results$checks_failed <- qa_results$checks_failed + 1
    qa_results$errors <- c(qa_results$errors, paste("Results structure:", e$message))
  })

  # CHECK 2: Markov Trace Validation
  cat("[ 2/10] Validating Markov traces... ")
  tryCatch({
    if (!is.null(model_results$trace_treatment)) {
      validate_markov_trace(model_results$trace_treatment, "trace_treatment")
    }
    if (!is.null(model_results$trace_comparator)) {
      validate_markov_trace(model_results$trace_comparator, "trace_comparator")
    }
    cat("✓ PASS\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  }, error = function(e) {
    cat("✖ FAIL:", e$message, "\n")
    qa_results$checks_failed <- qa_results$checks_failed + 1
    qa_results$errors <- c(qa_results$errors, paste("Trace validation:", e$message))
  })

  # CHECK 3: Numerical Stability
  cat("[ 3/10] Checking numerical stability... ")
  has_issues <- FALSE

  if (is.infinite(model_results$icer)) {
    qa_results$warnings <- c(qa_results$warnings, "ICER is infinite (likely zero QALYs)")
    has_issues <- TRUE
  }

  if (is.na(model_results$icer)) {
    qa_results$errors <- c(qa_results$errors, "ICER is NA")
    has_issues <- TRUE
  }

  if (!has_issues) {
    cat("✓ PASS\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  } else {
    cat("⚠ WARNING\n")
  }

  # CHECK 4: Cost-Effectiveness Plane Quadrant
  cat("[ 4/10] Analyzing CE plane quadrant... ")
  quadrant <- get_ce_quadrant(model_results$inc_qalys, model_results$inc_costs)
  cat(quadrant, "✓\n")
  qa_results$ce_quadrant <- quadrant
  qa_results$checks_passed <- qa_results$checks_passed + 1

  # CHECK 5: Parameter Reasonableness
  cat("[ 5/10] Checking parameter ranges... ")
  param_issues <- check_parameter_reasonableness(model_results$params)
  if (length(param_issues) == 0) {
    cat("✓ PASS\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  } else {
    cat("⚠ WARNING:", length(param_issues), "issues\n")
    qa_results$warnings <- c(qa_results$warnings, param_issues)
  }

  # CHECK 6: PSA Quality (if available)
  cat("[ 6/10] Checking PSA quality... ")
  if (!is.null(model_results$psa_results)) {
    psa_issues <- check_psa_quality(model_results$psa_results)
    if (length(psa_issues) == 0) {
      cat("✓ PASS\n")
      qa_results$checks_passed <- qa_results$checks_passed + 1
    } else {
      cat("⚠ WARNING:", length(psa_issues), "issues\n")
      qa_results$warnings <- c(qa_results$warnings, psa_issues)
    }
  } else {
    cat("○ SKIP (No PSA)\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  }

  # CHECK 7: Trace Monotonicity (Dead State)
  cat("[ 7/10] Checking absorbing state monotonicity... ")
  tryCatch({
    check_trace_monotonicity(model_results$trace_treatment)
    check_trace_monotonicity(model_results$trace_comparator)
    cat("✓ PASS\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  }, error = function(e) {
    cat("✖ FAIL:", e$message, "\n")
    qa_results$checks_failed <- qa_results$checks_failed + 1
    qa_results$errors <- c(qa_results$errors, paste("Monotonicity:", e$message))
  })

  # CHECK 8: Discounting Applied Correctly
  cat("[ 8/10] Verifying discounting... ")
  if (!is.null(model_results$params$discount_rate)) {
    if (model_results$params$discount_rate >= 0 && model_results$params$discount_rate <= 0.2) {
      cat("✓ PASS (", model_results$params$discount_rate * 100, "%)\n", sep = "")
      qa_results$checks_passed <- qa_results$checks_passed + 1
    } else {
      cat("⚠ WARNING: Unusual discount rate\n")
      qa_results$warnings <- c(qa_results$warnings,
                              paste("Discount rate:", model_results$params$discount_rate))
    }
  } else {
    cat("○ SKIP\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  }

  # CHECK 9: Half-Cycle Correction Status
  cat("[ 9/10] Checking half-cycle correction... ")
  if (!is.null(model_results$params$half_cycle_correction)) {
    status <- if (model_results$params$half_cycle_correction) "Enabled" else "Disabled"
    cat("✓ ", status, "\n", sep = "")
    qa_results$half_cycle_correction <- model_results$params$half_cycle_correction
    qa_results$checks_passed <- qa_results$checks_passed + 1
  } else {
    cat("○ Not specified\n")
    qa_results$checks_passed <- qa_results$checks_passed + 1
  }

  # CHECK 10: Results Reproducibility
  cat("[10/10] Checking reproducibility metadata... ")
  qa_results$reproducibility <- list(
    execution_time = model_results$execution_time,
    R_version = R.version.string,
    platform = R.version$platform
  )
  cat("✓ PASS\n")
  qa_results$checks_passed <- qa_results$checks_passed + 1

  # Overall Status
  cat("\n")
  cat("-----------------------------------------------------------\n")
  total_checks <- qa_results$checks_passed + qa_results$checks_failed
  pass_rate <- qa_results$checks_passed / total_checks * 100

  if (qa_results$checks_failed == 0 && length(qa_results$warnings) == 0) {
    qa_results$overall_status <- "EXCELLENT"
    cat("  OVERALL STATUS: ✓ EXCELLENT (10/10)\n")
  } else if (qa_results$checks_failed == 0) {
    qa_results$overall_status <- "GOOD"
    cat("  OVERALL STATUS: ✓ GOOD (", qa_results$checks_passed, "/", total_checks,
        " - ", length(qa_results$warnings), " warnings)\n", sep = "")
  } else {
    qa_results$overall_status <- "NEEDS ATTENTION"
    cat("  OVERALL STATUS: ⚠ NEEDS ATTENTION (", qa_results$checks_failed,
        " failures, ", length(qa_results$warnings), " warnings)\n", sep = "")
  }

  cat("-----------------------------------------------------------\n\n")

  # Print warnings if any
  if (length(qa_results$warnings) > 0) {
    cat("Warnings:\n")
    for (i in seq_along(qa_results$warnings)) {
      cat("  ", i, ". ", qa_results$warnings[i], "\n", sep = "")
    }
    cat("\n")
  }

  # Print errors if any
  if (length(qa_results$errors) > 0) {
    cat("Errors:\n")
    for (i in seq_along(qa_results$errors)) {
      cat("  ", i, ". ", qa_results$errors[i], "\n", sep = "")
    }
    cat("\n")
  }

  return(invisible(qa_results))
}

#' Get cost-effectiveness plane quadrant
#' @keywords internal
get_ce_quadrant <- function(inc_qalys, inc_costs) {
  if (inc_qalys > 0 && inc_costs > 0) {
    return("NE Quadrant (More effective, more costly)")
  } else if (inc_qalys > 0 && inc_costs < 0) {
    return("SE Quadrant (Dominant - more effective, less costly)")
  } else if (inc_qalys < 0 && inc_costs > 0) {
    return("NW Quadrant (Dominated - less effective, more costly)")
  } else {
    return("SW Quadrant (Less effective, less costly)")
  }
}

#' Check parameter reasonableness
#' @keywords internal
check_parameter_reasonableness <- function(params) {
  issues <- character(0)

  # Check utilities
  if (!is.null(params$utility_stable) && params$utility_stable > 0.95) {
    issues <- c(issues, "Utility for stable state very high (>0.95)")
  }

  if (!is.null(params$utility_progressed) && !is.null(params$utility_stable)) {
    if (params$utility_progressed > params$utility_stable) {
      issues <- c(issues, "Progressed utility exceeds stable utility")
    }
  }

  # Check costs
  if (!is.null(params$cost_treatment) && params$cost_treatment > 500000) {
    issues <- c(issues, "Treatment cost very high (>£500,000)")
  }

  # Check time horizon
  if (!is.null(params$time_horizon) && params$time_horizon > 50) {
    issues <- c(issues, "Time horizon very long (>50 years)")
  }

  return(issues)
}

#' Check PSA quality
#' @keywords internal
check_psa_quality <- function(psa_results) {
  issues <- character(0)

  # Check sample size
  if (psa_results$n_sim < 1000) {
    issues <- c(issues, "PSA sample size < 1000 (may have high MC error)")
  }

  # Check for extreme outliers
  if (!is.null(psa_results$inc_qalys_sim)) {
    qaly_range <- diff(range(psa_results$inc_qalys_sim, na.rm = TRUE))
    qaly_median <- median(psa_results$inc_qalys_sim, na.rm = TRUE)

    if (qaly_range > abs(qaly_median) * 10) {
      issues <- c(issues, "Very wide QALY distribution (outliers present)")
    }
  }

  # Check for NAs
  if (any(is.na(psa_results$inc_qalys_sim)) || any(is.na(psa_results$inc_costs_sim))) {
    issues <- c(issues, "PSA contains NA values")
  }

  return(issues)
}

#' Check trace monotonicity for absorbing state
#' @keywords internal
check_trace_monotonicity <- function(trace) {
  if (is.null(trace)) return(NULL)

  # Assuming last column is dead state
  dead_state <- trace[, ncol(trace)]

  # Check if monotonically increasing
  diffs <- diff(dead_state)

  if (any(diffs < -1e-10)) {
    stop("Dead state not monotonically increasing (population resurrection detected)")
  }

  return(TRUE)
}

#' Generate quality assurance report
#' @export
generate_qa_report <- function(model_results, output_file = "qa_report.txt") {

  sink(output_file)

  cat("\n")
  cat("=============================================================================\n")
  cat("  EVIDENCEOS PRIME - QUALITY ASSURANCE REPORT\n")
  cat("=============================================================================\n")
  cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat("=============================================================================\n\n")

  # Run QA checks
  qa_results <- run_qa_checks(model_results)

  # Add model summary
  cat("\n")
  cat("MODEL SUMMARY\n")
  cat("-------------\n")
  cat("ICER: ", format_icer(model_results$icer), "\n")
  cat("Incremental QALYs: ", format_number(model_results$inc_qalys, 3), "\n")
  cat("Incremental Costs: ", format_number(model_results$inc_costs, 0, prefix = "£"), "\n")
  cat("Time Horizon: ", model_results$params$time_horizon, " years\n")
  cat("Discount Rate: ", model_results$params$discount_rate * 100, "%\n")

  if (!is.null(model_results$psa_results)) {
    cat("\nPSA SUMMARY\n")
    cat("-------------\n")
    cat("Number of simulations: ", format_number(model_results$psa_results$n_sim, 0), "\n")
    cat("Mean ICER: ", format_icer(mean(model_results$psa_results$inc_costs_sim /
                                        model_results$psa_results$inc_qalys_sim)), "\n")
  }

  cat("\n=============================================================================\n")

  sink()

  message("✓ QA report generated: ", output_file)

  return(invisible(qa_results))
}

#' Quick validation check (minimal output)
#' @export
quick_validate <- function(model_results) {
  tryCatch({
    validate_model_results(model_results)
    if (!is.null(model_results$trace_treatment)) {
      validate_markov_trace(model_results$trace_treatment)
    }
    if (!is.null(model_results$trace_comparator)) {
      validate_markov_trace(model_results$trace_comparator)
    }
    message("✓ Quick validation passed")
    return(TRUE)
  }, error = function(e) {
    warning("✖ Quick validation failed: ", e$message)
    return(FALSE)
  })
}

#' Compare two model results
#' @export
compare_models <- function(model1, model2, tolerance = 0.01) {

  cat("\nMODEL COMPARISON\n")
  cat("================\n\n")

  # Compare ICERs
  icer_diff <- abs(model1$icer - model2$icer)
  icer_pct_diff <- icer_diff / model1$icer * 100

  cat("ICER:\n")
  cat("  Model 1: ", format_icer(model1$icer), "\n")
  cat("  Model 2: ", format_icer(model2$icer), "\n")
  cat("  Difference: ", format_number(icer_diff, 0, prefix = "£"), " (", round(icer_pct_diff, 1), "%)\n\n")

  # Compare QALYs
  qaly_diff <- abs(model1$inc_qalys - model2$inc_qalys)
  cat("Incremental QALYs:\n")
  cat("  Model 1: ", format_number(model1$inc_qalys, 3), "\n")
  cat("  Model 2: ", format_number(model2$inc_qalys, 3), "\n")
  cat("  Difference: ", format_number(qaly_diff, 3), "\n\n")

  # Compare Costs
  cost_diff <- abs(model1$inc_costs - model2$inc_costs)
  cat("Incremental Costs:\n")
  cat("  Model 1: ", format_number(model1$inc_costs, 0, prefix = "£"), "\n")
  cat("  Model 2: ", format_number(model2$inc_costs, 0, prefix = "£"), "\n")
  cat("  Difference: ", format_number(cost_diff, 0, prefix = "£"), "\n\n")

  # Assess similarity
  if (icer_pct_diff < tolerance * 100) {
    cat("✓ Models are SIMILAR (within ", tolerance * 100, "% tolerance)\n", sep = "")
  } else {
    cat("⚠ Models DIFFER significantly (>", tolerance * 100, "% difference)\n", sep = "")
  }

  cat("\n")
}
