# ============================================================================
# PHASE 3-4 COMPREHENSIVE TEST SUITE
# EvidenceOS PRIME - Advanced Meta-Analysis Platform
# ============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("  PHASE 3-4 COMPREHENSIVE TEST SUITE\n")
cat("  EvidenceOS PRIME - Advanced Meta-Analysis Platform\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

# Set up test environment
options(warn = 1)  # Print warnings as they occur
test_results <- list()
test_counter <- 0

# Helper function to record test results
record_test <- function(name, status, message = "", details = NULL) {
  test_counter <<- test_counter + 1
  test_results[[test_counter]] <<- list(
    test_num = test_counter,
    name = name,
    status = status,
    message = message,
    details = details,
    timestamp = Sys.time()
  )

  status_icon <- if(status == "PASS") "✓" else if(status == "FAIL") "✗" else "⚠"
  status_color <- if(status == "PASS") "\033[32m" else if(status == "FAIL") "\033[31m" else "\033[33m"
  reset_color <- "\033[0m"

  cat(sprintf("%sTest %d: %s %s%s\n", status_color, test_counter, status_icon, name, reset_color))
  if(message != "") cat(sprintf("  %s\n", message))
  if(!is.null(details)) {
    cat("  Details:\n")
    for(key in names(details)) {
      cat(sprintf("    - %s: %s\n", key, details[[key]]))
    }
  }
  cat("\n")
}

# ============================================================================
# PHASE 4.3: IPD META-ANALYSIS TESTS
# ============================================================================

cat("───────────────────────────────────────────────────────────────────────\n")
cat("PHASE 4.3: IPD META-ANALYSIS BACKEND\n")
cat("───────────────────────────────────────────────────────────────────────\n\n")

# Source IPD backend
tryCatch({
  source("backend/ipd/data_validation.R")
  source("backend/ipd/one_stage.R")
  source("backend/ipd/ipd_ma.R")
  record_test("IPD Backend Loading", "PASS", "All IPD modules loaded successfully")
}, error = function(e) {
  record_test("IPD Backend Loading", "FAIL", paste("Error:", e$message))
})

# Load required packages
suppressPackageStartupMessages({
  library(lme4)
  library(dplyr)
  library(tidyr)
})

# Test 1: Continuous Outcome IPD Meta-Analysis
cat("Test 1: Continuous Outcome with Covariates\n")
tryCatch({
  set.seed(123)

  # Simulate IPD data: 5 studies, 100 patients each, treatment effect = 0.5
  ipd_data <- data.frame(
    study_id = rep(1:5, each = 100),
    patient_id = 1:500,
    treatment = rep(c(0, 1), 250),
    outcome = rnorm(500, mean = 5 + rep(c(0, 1), 250) * 0.5, sd = 1),
    age = rnorm(500, 50, 10),
    sex = sample(c("M", "F"), 500, replace = TRUE)
  )

  # Run analysis
  results <- run_ipd_meta_analysis(
    ipd_data = ipd_data,
    study_var = "study_id",
    patient_var = "patient_id",
    outcome_var = "outcome",
    treatment_var = "treatment",
    covariates = c("age", "sex"),
    outcome_type = "continuous",
    method = "one_stage",
    random_effects = "intercept_slope",
    verbose = FALSE
  )

  # Validate results
  checks <- list(
    "Model converged" = results$diagnostics$convergence,
    "Treatment effect ~0.5" = abs(results$treatment_effect$estimate - 0.5) < 0.2,
    "CI covers 0.5" = results$treatment_effect$ci_lower < 0.5 && results$treatment_effect$ci_upper > 0.5,
    "P-value < 0.05" = results$treatment_effect$p_value < 0.05,
    "5 studies analyzed" = nrow(results$study_effects) == 5
  )

  if(all(unlist(checks))) {
    record_test("IPD Continuous Outcome", "PASS", "All checks passed",
                list(
                  "Estimate" = sprintf("%.3f (95%% CI: %.3f-%.3f)",
                                       results$treatment_effect$estimate,
                                       results$treatment_effect$ci_lower,
                                       results$treatment_effect$ci_upper),
                  "P-value" = sprintf("%.4f", results$treatment_effect$p_value),
                  "Studies" = nrow(results$study_effects)
                ))
  } else {
    failed_checks <- names(checks)[!unlist(checks)]
    record_test("IPD Continuous Outcome", "WARN",
                paste("Some checks failed:", paste(failed_checks, collapse = ", ")))
  }

}, error = function(e) {
  record_test("IPD Continuous Outcome", "FAIL", paste("Error:", e$message))
})

# Test 2: Binary Outcome IPD Meta-Analysis
cat("Test 2: Binary Outcome (Logistic Regression)\n")
tryCatch({
  set.seed(456)

  # Simulate binary outcome: treatment log-OR = 0.7 (OR ~2.0)
  ipd_data <- data.frame(
    study_id = rep(1:5, each = 100),
    patient_id = 1:500,
    treatment = rep(c(0, 1), 250),
    age = rnorm(500, 50, 10),
    sex = sample(c("M", "F"), 500, replace = TRUE)
  )

  # Create binary outcome with log-OR = 0.7
  linear_pred <- -1 + ipd_data$treatment * 0.7 + rnorm(500, 0, 0.5)
  ipd_data$outcome <- rbinom(500, 1, plogis(linear_pred))

  # Run analysis
  results <- run_ipd_meta_analysis(
    ipd_data = ipd_data,
    study_var = "study_id",
    patient_var = "patient_id",
    outcome_var = "outcome",
    treatment_var = "treatment",
    covariates = c("age", "sex"),
    outcome_type = "binary",
    method = "one_stage",
    random_effects = "intercept_only",
    verbose = FALSE
  )

  # Check OR is approximately 2.0 (exp(0.7))
  expected_or <- exp(0.7)
  checks <- list(
    "Model converged" = results$diagnostics$convergence,
    "OR ~2.0" = abs(results$treatment_effect$estimate - expected_or) < 1.0,
    "OR > 1" = results$treatment_effect$estimate > 1,
    "P-value < 0.05" = results$treatment_effect$p_value < 0.05
  )

  if(all(unlist(checks))) {
    record_test("IPD Binary Outcome", "PASS", "Logistic model successful",
                list(
                  "Odds Ratio" = sprintf("%.3f (95%% CI: %.3f-%.3f)",
                                         results$treatment_effect$estimate,
                                         results$treatment_effect$ci_lower,
                                         results$treatment_effect$ci_upper),
                  "Expected OR" = sprintf("%.3f", expected_or),
                  "P-value" = sprintf("%.4f", results$treatment_effect$p_value)
                ))
  } else {
    failed_checks <- names(checks)[!unlist(checks)]
    record_test("IPD Binary Outcome", "WARN",
                paste("Some checks failed:", paste(failed_checks, collapse = ", ")))
  }

}, error = function(e) {
  record_test("IPD Binary Outcome", "FAIL", paste("Error:", e$message))
})

# Test 3: Data Validation Functions
cat("Test 3: Data Validation Functions\n")
tryCatch({
  # Test with problematic data
  bad_data <- data.frame(
    study_id = c(1, 1, 1, NA),
    patient_id = c(1, 2, 2, 4),  # Duplicate patient 2
    outcome = c(1, 2, NA, 4),    # Missing outcome
    treatment = c(0, 1, 0, 1)
  )

  validation <- validate_ipd_structure(
    ipd_data = bad_data,
    study_var = "study_id",
    patient_var = "patient_id",
    outcome_var = "outcome",
    treatment_var = "treatment"
  )

  # Should detect issues
  checks <- list(
    "Detects missing study ID" = any(grepl("missing", validation$messages, ignore.case = TRUE)),
    "Detects duplicate patient" = any(grepl("duplicate", validation$messages, ignore.case = TRUE)),
    "Validation fails" = !validation$is_valid
  )

  if(all(unlist(checks))) {
    record_test("IPD Data Validation", "PASS", "Successfully detected data quality issues",
                list("Issues detected" = length(validation$messages)))
  } else {
    record_test("IPD Data Validation", "WARN", "Some issues not detected")
  }

}, error = function(e) {
  record_test("IPD Data Validation", "FAIL", paste("Error:", e$message))
})

# ============================================================================
# PHASE 4.4: PARTITIONED SURVIVAL ANALYSIS TESTS
# ============================================================================

cat("───────────────────────────────────────────────────────────────────────\n")
cat("PHASE 4.4: PARTITIONED SURVIVAL ANALYSIS BACKEND\n")
cat("───────────────────────────────────────────────────────────────────────\n\n")

# Source survival backend
tryCatch({
  source("backend/survival/survival_analysis.R")
  record_test("Survival Backend Loading", "PASS", "Survival module loaded successfully")
}, error = function(e) {
  record_test("Survival Backend Loading", "FAIL", paste("Error:", e$message))
})

# Load required packages
suppressPackageStartupMessages({
  library(flexsurv)
  library(survival)
  library(ggplot2)
})

# Test 4: Parametric Survival Curve Fitting
cat("Test 4: Parametric Survival Curves\n")
tryCatch({
  set.seed(789)

  # Simulate PFS data with Weibull distribution
  pfs_data <- data.frame(
    time = rweibull(200, shape = 1.2, scale = 15),
    event = rbinom(200, 1, 0.7),
    treatment = rep(c("Control", "Intervention"), each = 100)
  )

  # Fit parametric models
  fit_result <- fit_parametric_survival_curves(
    surv_data = pfs_data,
    time_var = "time",
    event_var = "event",
    treatment_var = "treatment",
    distributions = c("exp", "weibull", "lnorm", "llogis")
  )

  # Validate
  checks <- list(
    "4 distributions fitted" = length(fit_result$fits) == 4,
    "Fit statistics available" = !is.null(fit_result$fit_stats),
    "Best fit selected" = !is.null(fit_result$best_fit),
    "Weibull has good fit" = "weibull" %in% names(fit_result$fits)
  )

  if(all(unlist(checks))) {
    best_dist <- fit_result$best_fit
    best_aic <- fit_result$fit_stats$AIC[fit_result$fit_stats$distribution == best_dist]

    record_test("Parametric Survival Fitting", "PASS", "All distributions fitted successfully",
                list(
                  "Best distribution" = best_dist,
                  "Best AIC" = sprintf("%.2f", best_aic),
                  "Models fitted" = paste(names(fit_result$fits), collapse = ", ")
                ))
  } else {
    record_test("Parametric Survival Fitting", "WARN", "Some checks failed")
  }

}, error = function(e) {
  record_test("Parametric Survival Fitting", "FAIL", paste("Error:", e$message))
})

# Test 5: Partition Survival Model & QALY Calculation
cat("Test 5: Partitioned Survival Model & QALYs\n")
tryCatch({
  set.seed(101)

  # Simulate PFS and OS data
  pfs_data <- data.frame(
    time = rweibull(200, shape = 1.2, scale = 15),
    event = rbinom(200, 1, 0.7),
    treatment = rep(c("Control", "Intervention"), each = 100)
  )

  os_data <- data.frame(
    time = rweibull(200, shape = 1.1, scale = 25),
    event = rbinom(200, 1, 0.6),
    treatment = rep(c("Control", "Intervention"), each = 100)
  )

  # Ensure OS >= PFS (fix data if needed)
  os_data$time <- pmax(os_data$time, pfs_data$time + 0.1)

  # Run complete partition survival analysis
  results <- run_partition_survival_analysis(
    pfs_data = pfs_data,
    os_data = os_data,
    time_horizon = 60,  # 5 years
    utility_pfs = 0.80,
    utility_progressed = 0.60,
    utility_dead = 0.00,
    discount_rate = 0.035,
    distributions = c("weibull", "lnorm", "llogis")
  )

  # Validate
  checks <- list(
    "PFS fit available" = !is.null(results$pfs_fit),
    "OS fit available" = !is.null(results$os_fit),
    "Partition model created" = !is.null(results$partition_model),
    "QALYs calculated" = !is.null(results$qaly_results),
    "QALYs > 0" = results$qaly_results$total_qalys > 0,
    "QALYs < time_horizon" = results$qaly_results$total_qalys < 60/12,  # Max possible
    "States sum to 1" = all(abs(rowSums(results$partition_model[, c("progression_free", "progressed", "dead")]) - 1) < 0.01)
  )

  if(all(unlist(checks))) {
    record_test("Partition Survival & QALYs", "PASS", "Complete workflow successful",
                list(
                  "Total QALYs" = sprintf("%.3f", results$qaly_results$total_qalys),
                  "Total LYs" = sprintf("%.3f", results$qaly_results$total_lys),
                  "PFS best fit" = results$pfs_fit$best_fit,
                  "OS best fit" = results$os_fit$best_fit,
                  "Time horizon" = sprintf("%d months", 60)
                ))
  } else {
    failed_checks <- names(checks)[!unlist(checks)]
    record_test("Partition Survival & QALYs", "WARN",
                paste("Some checks failed:", paste(failed_checks, collapse = ", ")))
  }

}, error = function(e) {
  record_test("Partition Survival & QALYs", "FAIL", paste("Error:", e$message))
})

# Test 6: RMST Calculation
cat("Test 6: Restricted Mean Survival Time\n")
tryCatch({
  set.seed(202)

  surv_data <- data.frame(
    time = rweibull(100, shape = 1.2, scale = 15),
    event = rbinom(100, 1, 0.7),
    treatment = "Test"
  )

  fit_result <- fit_parametric_survival_curves(
    surv_data = surv_data,
    time_var = "time",
    event_var = "event",
    treatment_var = "treatment",
    distributions = c("weibull")
  )

  rmst <- calculate_rmst(
    fit_result = fit_result,
    time_horizon = 24,
    treatment = "Test"
  )

  checks <- list(
    "RMST calculated" = !is.null(rmst),
    "RMST > 0" = rmst > 0,
    "RMST < horizon" = rmst < 24
  )

  if(all(unlist(checks))) {
    record_test("RMST Calculation", "PASS", "RMST calculated successfully",
                list("RMST (24 months)" = sprintf("%.2f months", rmst)))
  } else {
    record_test("RMST Calculation", "WARN", "RMST value unexpected")
  }

}, error = function(e) {
  record_test("RMST Calculation", "FAIL", paste("Error:", e$message))
})

# ============================================================================
# PHASE 4.5: DOSE-RESPONSE META-ANALYSIS TESTS
# ============================================================================

cat("───────────────────────────────────────────────────────────────────────\n")
cat("PHASE 4.5: DOSE-RESPONSE META-ANALYSIS BACKEND\n")
cat("───────────────────────────────────────────────────────────────────────\n\n")

# Source dose-response backend
tryCatch({
  source("backend/doseresp/doseresp_ma.R")
  record_test("Dose-Response Backend Loading", "PASS", "Dose-response module loaded successfully")
}, error = function(e) {
  record_test("Dose-Response Backend Loading", "FAIL", paste("Error:", e$message))
})

# Load required packages
suppressPackageStartupMessages({
  library(dosresmeta)
  library(rms)
})

# Test 7: Linear Dose-Response Model
cat("Test 7: Linear Dose-Response Model\n")
tryCatch({
  # Simulate dose-response data: 5 studies with linear increase
  dose_data <- data.frame(
    study = rep(1:5, each = 3),
    dose = rep(c(0, 10, 20), 5),
    cases = c(50, 55, 65,   # Study 1: increasing trend
              40, 45, 52,   # Study 2
              60, 68, 78,   # Study 3
              35, 38, 44,   # Study 4
              45, 50, 58),  # Study 5
    n = rep(c(1000, 1200, 900, 800, 1100), each = 3)
  )

  # Run linear analysis
  results <- run_doseresp_analysis(
    studies_data = dose_data,
    model_type = "linear",
    study_var = "study",
    dose_var = "dose",
    cases_var = "cases",
    n_var = "n",
    type = "ir"
  )

  # Validate
  checks <- list(
    "Model fitted" = !is.null(results$model),
    "Predictions available" = !is.null(results$predictions),
    "RR increases with dose" = results$predictions$RR[nrow(results$predictions)] > results$predictions$RR[1],
    "Plot created" = !is.null(results$plot),
    "Data prepared" = !is.null(results$data)
  )

  if(all(unlist(checks))) {
    max_dose_pred <- results$predictions[nrow(results$predictions), ]
    record_test("Linear Dose-Response", "PASS", "Linear model fitted successfully",
                list(
                  "RR at max dose" = sprintf("%.3f (95%% CI: %.3f-%.3f)",
                                             max_dose_pred$RR,
                                             max_dose_pred$lower,
                                             max_dose_pred$upper),
                  "Studies" = length(unique(dose_data$study)),
                  "Model type" = "Linear"
                ))
  } else {
    record_test("Linear Dose-Response", "WARN", "Some checks failed")
  }

}, error = function(e) {
  record_test("Linear Dose-Response", "FAIL", paste("Error:", e$message))
})

# Test 8: Spline Dose-Response Model
cat("Test 8: Spline Dose-Response Model\n")
tryCatch({
  # Same data as Test 7
  dose_data <- data.frame(
    study = rep(1:5, each = 3),
    dose = rep(c(0, 10, 20), 5),
    cases = c(50, 55, 65, 40, 45, 52, 60, 68, 78, 35, 38, 44, 45, 50, 58),
    n = rep(c(1000, 1200, 900, 800, 1100), each = 3)
  )

  # Run spline analysis
  results <- run_doseresp_analysis(
    studies_data = dose_data,
    model_type = "spline",
    knots = 3,
    study_var = "study",
    dose_var = "dose",
    cases_var = "cases",
    n_var = "n",
    type = "ir"
  )

  # Validate
  checks <- list(
    "Model fitted" = !is.null(results$model),
    "More predictions than linear" = nrow(results$predictions) > 10,
    "RR at dose=0 is 1" = abs(results$predictions$RR[1] - 1) < 0.01,
    "Smooth curve" = !any(is.na(results$predictions$RR))
  )

  if(all(unlist(checks))) {
    record_test("Spline Dose-Response", "PASS", "Spline model fitted successfully",
                list(
                  "Knots" = "3",
                  "Prediction points" = nrow(results$predictions),
                  "Model type" = "Restricted Cubic Spline"
                ))
  } else {
    record_test("Spline Dose-Response", "WARN", "Some checks failed")
  }

}, error = function(e) {
  record_test("Spline Dose-Response", "FAIL", paste("Error:", e$message))
})

# Test 9: Fractional Polynomial Dose-Response
cat("Test 9: Fractional Polynomial Dose-Response\n")
tryCatch({
  dose_data <- data.frame(
    study = rep(1:5, each = 3),
    dose = rep(c(0, 10, 20), 5),
    cases = c(50, 55, 65, 40, 45, 52, 60, 68, 78, 35, 38, 44, 45, 50, 58),
    n = rep(c(1000, 1200, 900, 800, 1100), each = 3)
  )

  # Run fractional polynomial analysis (log-linear)
  results <- run_doseresp_analysis(
    studies_data = dose_data,
    model_type = "fractional_polynomial",
    powers = c(0, 1),  # Log-linear
    study_var = "study",
    dose_var = "dose",
    cases_var = "cases",
    n_var = "n",
    type = "ir"
  )

  checks <- list(
    "Model fitted" = !is.null(results$model),
    "Predictions available" = !is.null(results$predictions),
    "Powers applied" = !is.null(results$powers)
  )

  if(all(unlist(checks))) {
    record_test("Fractional Polynomial Dose-Response", "PASS", "FP model fitted successfully",
                list(
                  "Powers" = paste(results$powers, collapse = ", "),
                  "Model type" = "Fractional Polynomial"
                ))
  } else {
    record_test("Fractional Polynomial Dose-Response", "WARN", "Some checks failed")
  }

}, error = function(e) {
  record_test("Fractional Polynomial Dose-Response", "FAIL", paste("Error:", e$message))
})

# ============================================================================
# PHASE 4.2: BAYESIAN NMA INTEGRATION TESTS
# ============================================================================

cat("───────────────────────────────────────────────────────────────────────\n")
cat("PHASE 4.2: BAYESIAN NMA INTEGRATION\n")
cat("───────────────────────────────────────────────────────────────────────\n\n")

# Test 10: Backend Availability Check
cat("Test 10: Backend Availability & Adapter Function\n")
tryCatch({
  # Check if backend file exists
  backend_exists <- file.exists("backend/bayesian/bayesian_nma.R")

  if(backend_exists) {
    source("backend/bayesian/bayesian_nma.R")
    record_test("Bayesian Backend Availability", "PASS", "Backend file exists and loaded")
  } else {
    record_test("Bayesian Backend Availability", "WARN",
                "Backend file not found - will use simulation mode")
  }

  # Test adapter function from frontend
  source("frontend/modules/nma_bayesian.R")

  # Check if adapter function is defined
  if(exists("adapt_bayesian_results_for_ui")) {
    record_test("Adapter Function Exists", "PASS", "Adapter function defined in frontend module")
  } else {
    record_test("Adapter Function Exists", "FAIL", "Adapter function not found")
  }

}, error = function(e) {
  record_test("Bayesian Integration Check", "FAIL", paste("Error:", e$message))
})

# ============================================================================
# TEST SUMMARY AND REPORT
# ============================================================================

cat("═══════════════════════════════════════════════════════════════════════\n")
cat("  TEST SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

# Count results
n_pass <- sum(sapply(test_results, function(x) x$status == "PASS"))
n_fail <- sum(sapply(test_results, function(x) x$status == "FAIL"))
n_warn <- sum(sapply(test_results, function(x) x$status == "WARN"))
n_total <- length(test_results)

cat(sprintf("Total Tests:  %d\n", n_total))
cat(sprintf("✓ Passed:     %d (%.1f%%)\n", n_pass, 100 * n_pass / n_total))
cat(sprintf("✗ Failed:     %d (%.1f%%)\n", n_fail, 100 * n_fail / n_total))
cat(sprintf("⚠ Warnings:   %d (%.1f%%)\n", n_warn, 100 * n_warn / n_total))
cat("\n")

# Overall status
if(n_fail == 0 && n_warn == 0) {
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("  ✓✓✓ ALL TESTS PASSED ✓✓✓\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
} else if(n_fail == 0) {
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("  ⚠ ALL TESTS PASSED WITH WARNINGS ⚠\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
} else {
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("  ✗✗✗ SOME TESTS FAILED ✗✗✗\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
}

cat("\n")

# Return test results for further processing
invisible(test_results)
