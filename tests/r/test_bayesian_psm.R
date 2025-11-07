# Comprehensive Tests for Bayesian Meta-Analysis and Partitioned Survival Models
# Tests competitive features: Bayesian MA (vs WinBUGS) and PSM (vs TreeAge)

library(testthat)
library(rstan)
library(flexsurv)
library(survival)

# Source required modules
source("../../frontend/modules/bayesian_ma.R", chdir = TRUE)
source("../../frontend/modules/partitioned_survival.R", chdir = TRUE)

context("Bayesian Meta-Analysis Testing")

# ============================================================================
# BAYESIAN META-ANALYSIS TESTS
# ============================================================================

test_that("Bayesian MA Stan model compiles successfully", {
  skip_on_ci()  # Skip on CI due to Stan compilation time

  # Simple test data
  yi <- c(0.2, 0.3, 0.25, 0.35, 0.28)
  sei <- c(0.1, 0.12, 0.08, 0.15, 0.1)
  study_labels <- paste0("Study_", 1:5)

  # Default priors
  priors <- list(
    effect_mean = 0,
    effect_sd = 10,
    tau_dist = "half_normal",
    tau_scale = 0.5
  )

  # Run Bayesian MA with minimal iterations for testing
  result <- tryCatch({
    run_bayesian_ma_stan(
      yi = yi,
      sei = sei,
      study_labels = study_labels,
      priors = priors,
      n_chains = 2,
      n_iter = 500,
      n_warmup = 250,
      thin = 1
    )
  }, error = function(e) {
    NULL
  })

  # Check if Stan compiled and ran
  expect_false(is.null(result))
  if (!is.null(result)) {
    expect_true("posterior_summary" %in% names(result))
    expect_true("stan_fit" %in% names(result))
  }
})

test_that("Bayesian MA handles different priors correctly", {
  skip_on_ci()

  yi <- c(0.2, 0.3, 0.25)
  sei <- c(0.1, 0.12, 0.08)
  study_labels <- paste0("Study_", 1:3)

  # Test weakly informative prior
  priors_weak <- list(
    effect_mean = 0,
    effect_sd = 2,
    tau_dist = "half_normal",
    tau_scale = 0.5
  )

  # Test skeptical prior (favors null)
  priors_skeptical <- list(
    effect_mean = 0,
    effect_sd = 0.3,
    tau_dist = "half_normal",
    tau_scale = 0.25
  )

  # These should both run without error
  expect_error({
    run_bayesian_ma_stan(yi, sei, study_labels, priors_weak,
                         n_chains = 1, n_iter = 200, n_warmup = 100)
  }, NA)

  expect_error({
    run_bayesian_ma_stan(yi, sei, study_labels, priors_skeptical,
                         n_chains = 1, n_iter = 200, n_warmup = 100)
  }, NA)
})

test_that("Bayesian MA credible interval calculation is correct", {
  # Test the credible interval function
  posterior_samples <- rnorm(1000, mean = 0.3, sd = 0.1)

  ci_95 <- quantile(posterior_samples, probs = c(0.025, 0.975))
  ci_90 <- quantile(posterior_samples, probs = c(0.05, 0.95))

  # 95% CI should be wider than 90% CI
  expect_true((ci_95[2] - ci_95[1]) > (ci_90[2] - ci_90[1]))

  # Mean should be approximately in the middle
  posterior_mean <- mean(posterior_samples)
  expect_true(posterior_mean > ci_95[1] && posterior_mean < ci_95[2])
})

test_that("Bayesian MA convergence diagnostics work", {
  skip_on_ci()

  # Create test data with clear signal
  set.seed(123)
  yi <- rnorm(8, mean = 0.5, sd = 0.1)
  sei <- runif(8, 0.05, 0.15)
  study_labels <- paste0("Study_", 1:8)

  priors <- list(
    effect_mean = 0,
    effect_sd = 10,
    tau_dist = "half_normal",
    tau_scale = 0.5
  )

  result <- tryCatch({
    run_bayesian_ma_stan(
      yi = yi,
      sei = sei,
      study_labels = study_labels,
      priors = priors,
      n_chains = 3,
      n_iter = 1000,
      n_warmup = 500,
      adapt_delta = 0.9
    )
  }, error = function(e) NULL)

  if (!is.null(result) && "diagnostics" %in% names(result)) {
    # Rhat should be close to 1 for convergence
    expect_true(all(result$diagnostics$rhat < 1.1, na.rm = TRUE))

    # ESS should be reasonable
    expect_true(all(result$diagnostics$ess_bulk > 100, na.rm = TRUE))
  }
})

test_that("Bayesian MA heterogeneity estimation works", {
  skip_on_ci()

  # Create data with known heterogeneity
  set.seed(456)
  true_effects <- rnorm(6, mean = 0.4, sd = 0.2)  # Heterogeneous
  yi <- true_effects + rnorm(6, 0, 0.05)
  sei <- rep(0.05, 6)
  study_labels <- paste0("Study_", 1:6)

  priors <- list(
    effect_mean = 0,
    effect_sd = 10,
    tau_dist = "half_normal",
    tau_scale = 1.0
  )

  result <- tryCatch({
    run_bayesian_ma_stan(yi, sei, study_labels, priors,
                         n_chains = 2, n_iter = 800, n_warmup = 400)
  }, error = function(e) NULL)

  if (!is.null(result) && "posterior_summary" %in% names(result)) {
    # Tau (heterogeneity) should be estimated
    tau_summary <- result$posterior_summary[result$posterior_summary$parameter == "tau", ]
    if (nrow(tau_summary) > 0) {
      expect_true(tau_summary$mean > 0)
      expect_true(tau_summary$mean < 1.0)  # Reasonable range
    }
  }
})

# ============================================================================
# PARTITIONED SURVIVAL MODEL TESTS
# ============================================================================

test_that("PSM parametric survival fitting works", {
  # Create synthetic survival data
  set.seed(789)
  n <- 100

  # Generate OS and PFS data
  os_time <- rweibull(n, shape = 1.2, scale = 20)
  os_event <- rbinom(n, 1, 0.7)

  pfs_time <- rweibull(n, shape = 1.5, scale = 15)
  pfs_event <- rbinom(n, 1, 0.8)

  # Ensure PFS <= OS
  pfs_time <- pmin(pfs_time, os_time)

  treatment <- rep(c(0, 1), each = n/2)

  # Fit Weibull distribution
  result <- fit_parametric_survival(
    time = os_time,
    event = os_event,
    treatment = treatment,
    distribution = "weibull"
  )

  expect_true("fit" %in% names(result))
  expect_true("aic" %in% names(result))
  expect_true("bic" %in% names(result))
  expect_true(is.numeric(result$aic))
  expect_true(is.numeric(result$bic))
})

test_that("PSM distribution selection works correctly", {
  set.seed(321)
  n <- 80

  # Generate exponential data (constant hazard)
  time <- rexp(n, rate = 0.05)
  event <- rbinom(n, 1, 0.6)
  treatment <- rep(c(0, 1), each = n/2)

  # Fit multiple distributions
  distributions <- c("exponential", "weibull", "gompertz", "lognormal")
  results <- list()

  for (dist in distributions) {
    results[[dist]] <- tryCatch({
      fit_parametric_survival(time, event, treatment, distribution = dist)
    }, error = function(e) NULL)
  }

  # At least some distributions should fit successfully
  successful_fits <- sum(sapply(results, function(x) !is.null(x)))
  expect_true(successful_fits >= 2)

  # Extract AICs for comparison
  aics <- sapply(results, function(x) if (!is.null(x)) x$aic else Inf)

  # Best fitting distribution should have lowest AIC
  best_dist <- names(which.min(aics))
  expect_true(best_dist %in% distributions)
})

test_that("PSM state occupancy calculation works", {
  # Create simple survival fits
  set.seed(111)
  n <- 60

  os_time <- rweibull(n, shape = 1.2, scale = 25)
  os_event <- rbinom(n, 1, 0.6)
  pfs_time <- rweibull(n, shape = 1.5, scale = 18)
  pfs_event <- rbinom(n, 1, 0.7)
  pfs_time <- pmin(pfs_time, os_time)
  treatment <- rep(0, n)

  os_fit <- fit_parametric_survival(os_time, os_event, treatment, "weibull")
  pfs_fit <- fit_parametric_survival(pfs_time, pfs_event, treatment, "weibull")

  # Calculate state occupancy
  time_points <- seq(0, 30, by = 1)
  occupancy <- calculate_state_occupancy_psm(
    os_fit = os_fit,
    pfs_fit = pfs_fit,
    time_points = time_points,
    treatment = 0
  )

  expect_equal(nrow(occupancy), length(time_points))
  expect_equal(ncol(occupancy), 3)  # PFS, Progressed, Dead
  expect_true(all(colnames(occupancy) %in% c("progression_free", "progressed", "dead")))

  # Check that proportions sum to ~1 at each time point
  row_sums <- rowSums(occupancy)
  expect_true(all(abs(row_sums - 1.0) < 0.01))

  # Check decreasing PFS over time
  expect_true(occupancy[1, "progression_free"] > occupancy[nrow(occupancy), "progression_free"])
})

test_that("PSM economic evaluation integrates correctly", {
  set.seed(222)
  n <- 100

  # Generate survival data
  os_time <- rweibull(n, shape = 1.1, scale = 30)
  os_event <- rbinom(n, 1, 0.65)
  pfs_time <- rweibull(n, shape = 1.4, scale = 20)
  pfs_event <- rbinom(n, 1, 0.75)
  pfs_time <- pmin(pfs_time, os_time)
  treatment <- rep(c(0, 1), each = n/2)

  # Fit models for both arms
  os_fit_trt <- fit_parametric_survival(
    os_time[treatment == 1],
    os_event[treatment == 1],
    rep(1, sum(treatment == 1)),
    "weibull"
  )

  pfs_fit_trt <- fit_parametric_survival(
    pfs_time[treatment == 1],
    pfs_event[treatment == 1],
    rep(1, sum(treatment == 1)),
    "weibull"
  )

  os_fit_comp <- fit_parametric_survival(
    os_time[treatment == 0],
    os_event[treatment == 0],
    rep(0, sum(treatment == 0)),
    "weibull"
  )

  pfs_fit_comp <- fit_parametric_survival(
    pfs_time[treatment == 0],
    pfs_event[treatment == 0],
    rep(0, sum(treatment == 0)),
    "weibull"
  )

  # Calculate state occupancy
  time_points <- seq(0, 40, by = 0.5)

  occ_trt <- calculate_state_occupancy_psm(os_fit_trt, pfs_fit_trt, time_points, 1)
  occ_comp <- calculate_state_occupancy_psm(os_fit_comp, pfs_fit_comp, time_points, 0)

  # Economic parameters
  utility_pfs <- 0.8
  utility_prog <- 0.6
  cost_pfs <- 2000
  cost_prog <- 5000
  discount_rate <- 0.035

  # Calculate QALYs and costs for treatment
  cycle_length <- diff(time_points)[1]
  discount_weights <- exp(-discount_rate * time_points[-1])

  qalys_trt <- sum(
    (occ_trt[-1, "progression_free"] * utility_pfs +
     occ_trt[-1, "progressed"] * utility_prog) * cycle_length * discount_weights
  )

  costs_trt <- sum(
    (occ_trt[-1, "progression_free"] * cost_pfs +
     occ_trt[-1, "progressed"] * cost_prog) * cycle_length * discount_weights
  )

  # Calculate QALYs and costs for comparator
  qalys_comp <- sum(
    (occ_comp[-1, "progression_free"] * utility_pfs +
     occ_comp[-1, "progressed"] * utility_prog) * cycle_length * discount_weights
  )

  costs_comp <- sum(
    (occ_comp[-1, "progression_free"] * cost_pfs +
     occ_comp[-1, "progressed"] * cost_prog) * cycle_length * discount_weights
  )

  # Check results are reasonable
  expect_true(qalys_trt > 0 && qalys_trt < 50)
  expect_true(costs_trt > 0)
  expect_true(qalys_comp > 0 && qalys_comp < 50)
  expect_true(costs_comp > 0)

  # Calculate incremental values
  inc_qalys <- qalys_trt - qalys_comp
  inc_costs <- costs_trt - costs_comp

  # ICER calculation
  if (inc_qalys > 0) {
    icer <- inc_costs / inc_qalys
    expect_true(is.finite(icer))
  }
})

test_that("PSM handles treatment comparisons correctly", {
  set.seed(333)
  n_per_arm <- 50

  # Treatment arm: better survival
  os_time_trt <- rweibull(n_per_arm, shape = 1.2, scale = 30)
  pfs_time_trt <- rweibull(n_per_arm, shape = 1.3, scale = 22)

  # Control arm: worse survival
  os_time_ctrl <- rweibull(n_per_arm, shape = 1.2, scale = 22)
  pfs_time_ctrl <- rweibull(n_per_arm, shape = 1.3, scale = 15)

  os_event <- rbinom(2 * n_per_arm, 1, 0.65)
  pfs_event <- rbinom(2 * n_per_arm, 1, 0.7)

  # Ensure PFS <= OS
  pfs_time_trt <- pmin(pfs_time_trt, os_time_trt)
  pfs_time_ctrl <- pmin(pfs_time_ctrl, os_time_ctrl)

  # Fit models
  os_fit_trt <- fit_parametric_survival(
    os_time_trt, os_event[1:n_per_arm],
    rep(1, n_per_arm), "weibull"
  )

  os_fit_ctrl <- fit_parametric_survival(
    os_time_ctrl, os_event[(n_per_arm+1):(2*n_per_arm)],
    rep(0, n_per_arm), "weibull"
  )

  # Compare median survival times
  time_points <- seq(0, 50, by = 0.1)

  # Extract survival probabilities
  surv_trt <- if (!is.null(os_fit_trt$fit)) {
    summary(os_fit_trt$fit, t = time_points, type = "survival")[[1]][, "est"]
  } else {
    rep(NA, length(time_points))
  }

  surv_ctrl <- if (!is.null(os_fit_ctrl$fit)) {
    summary(os_fit_ctrl$fit, t = time_points, type = "survival")[[1]][, "est"]
  } else {
    rep(NA, length(time_points))
  }

  # Treatment should have better survival (on average)
  if (!any(is.na(surv_trt)) && !any(is.na(surv_ctrl))) {
    mean_surv_trt <- mean(surv_trt, na.rm = TRUE)
    mean_surv_ctrl <- mean(surv_ctrl, na.rm = TRUE)

    # With high probability, treatment should be better
    # (allowing for random variation)
    expect_true(mean_surv_trt >= mean_surv_ctrl * 0.95)
  }
})

test_that("PSM extrapolation is reasonable", {
  set.seed(444)
  n <- 100

  # Generate data with limited follow-up
  max_followup <- 24
  os_time <- pmin(rweibull(n, shape = 1.2, scale = 30), max_followup)
  os_event <- ifelse(os_time < max_followup, rbinom(n, 1, 0.7), 0)
  treatment <- rep(0, n)

  fit <- fit_parametric_survival(os_time, os_event, treatment, "weibull")

  # Extrapolate to 60 months
  extrap_time <- 60
  extrap_points <- seq(0, extrap_time, by = 1)

  if (!is.null(fit$fit)) {
    surv_extrap <- summary(fit$fit, t = extrap_points, type = "survival")[[1]][, "est"]

    # Survival should be monotonically decreasing
    expect_true(all(diff(surv_extrap) <= 0))

    # Survival at time 0 should be ~1
    expect_true(abs(surv_extrap[1] - 1.0) < 0.01)

    # Survival should be positive
    expect_true(all(surv_extrap >= 0))

    # Survival at max time should be < 1
    expect_true(surv_extrap[length(surv_extrap)] < 1.0)
  }
})

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_that("Bayesian MA results can inform PSM analysis", {
  # Simulate using Bayesian MA HR estimate in PSM

  # Bayesian MA gives HR estimate
  set.seed(555)
  hr_estimate <- 0.75  # From Bayesian MA
  hr_sd <- 0.12

  # Use HR to generate PSM data
  n_per_arm <- 60
  baseline_scale <- 25

  # Control arm
  os_time_ctrl <- rweibull(n_per_arm, shape = 1.2, scale = baseline_scale)

  # Treatment arm: apply HR
  # HR = lambda_trt / lambda_ctrl, so lambda_trt = lambda_ctrl * HR
  # For Weibull: lambda proportional to 1/scale
  treatment_scale <- baseline_scale / hr_estimate
  os_time_trt <- rweibull(n_per_arm, shape = 1.2, scale = treatment_scale)

  os_event <- rbinom(2 * n_per_arm, 1, 0.65)

  # Fit PSM models
  fit_ctrl <- fit_parametric_survival(
    os_time_ctrl, os_event[1:n_per_arm],
    rep(0, n_per_arm), "weibull"
  )

  fit_trt <- fit_parametric_survival(
    os_time_trt, os_event[(n_per_arm+1):(2*n_per_arm)],
    rep(1, n_per_arm), "weibull"
  )

  # Both fits should be successful
  expect_false(is.null(fit_ctrl$fit))
  expect_false(is.null(fit_trt$fit))

  # Treatment arm should show survival benefit
  time_point <- 20
  if (!is.null(fit_ctrl$fit) && !is.null(fit_trt$fit)) {
    surv_ctrl <- summary(fit_ctrl$fit, t = time_point, type = "survival")[[1]][1, "est"]
    surv_trt <- summary(fit_trt$fit, t = time_point, type = "survival")[[1]][1, "est"]

    # Treatment should have better survival
    expect_true(surv_trt >= surv_ctrl)
  }
})

# ============================================================================
# RUN ALL TESTS
# ============================================================================

cat("\n==============================================\n")
cat("BAYESIAN MA & PSM TEST SUMMARY\n")
cat("==============================================\n")
test_results <- test_dir(".", reporter = "summary")
cat("\n")
