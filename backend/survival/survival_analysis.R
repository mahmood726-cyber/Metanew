# ============================================================================
# Partitioned Survival Analysis - Main Module
# ============================================================================
# Complete implementation for partitioned survival modeling in HTA
# Reference: Latimer (2013), Williams et al. (2017), NICE DSU TSD 14
# ============================================================================

library(flexsurv)
library(survival)
library(ggplot2)
library(dplyr)

#' Fit Parametric Survival Curves
#'
#' Fits multiple parametric distributions to survival data
#'
#' @param surv_data Data frame with time and event columns
#' @param time_var Name of time variable
#' @param event_var Name of event indicator (1=event, 0=censored)
#' @param treatment_var Optional treatment variable for stratified fits
#' @param distributions Vector of distributions to fit
#' @return List of flexsurvreg objects with fit statistics
#' @export
fit_parametric_survival_curves <- function(surv_data,
                                           time_var = "time",
                                           event_var = "event",
                                           treatment_var = NULL,
                                           distributions = c("exp", "weibull", "lnorm", "llogis", "gompertz", "gengamma")) {

  # Validate data
  if (!time_var %in% names(surv_data)) stop("Time variable not found: ", time_var)
  if (!event_var %in% names(surv_data)) stop("Event variable not found: ", event_var)

  # Build formula
  if (is.null(treatment_var)) {
    formula <- as.formula(paste0("Surv(", time_var, ", ", event_var, ") ~ 1"))
  } else {
    formula <- as.formula(paste0("Surv(", time_var, ", ", event_var, ") ~ ", treatment_var))
  }

  cat("\n=== Fitting Parametric Survival Curves ===\n")
  cat("Observations:", nrow(surv_data), "\n")
  cat("Events:", sum(surv_data[[event_var]]), sprintf("(%.1f%%)\n", 100*mean(surv_data[[event_var]])))
  cat("Distributions:", paste(distributions, collapse = ", "), "\n\n")

  # Fit each distribution
  fits <- list()
  fit_stats <- data.frame()

  for (dist in distributions) {
    cat(sprintf("Fitting %s distribution...", dist))

    fit <- tryCatch({
      flexsurvreg(formula = formula, data = surv_data, dist = dist)
    }, error = function(e) {
      cat(" FAILED\n")
      NULL
    })

    if (!is.null(fit)) {
      fits[[dist]] <- fit

      fit_stats <- rbind(fit_stats, data.frame(
        distribution = dist,
        AIC = fit$AIC,
        BIC = fit$AIC + (log(nrow(surv_data)) - 2) * length(fit$coefficients),
        loglik = fit$loglik,
        n_params = length(fit$coefficients)
      ))

      cat(" ✓\n")
    }
  }

  # Rank by AIC
  fit_stats <- fit_stats %>%
    arrange(AIC) %>%
    mutate(
      delta_AIC = AIC - min(AIC),
      AIC_weight = exp(-0.5 * delta_AIC) / sum(exp(-0.5 * delta_AIC))
    )

  cat("\n=== Model Fit Statistics ===\n")
  print(fit_stats, digits = 3, row.names = FALSE)
  cat("\nBest fit by AIC:", fit_stats$distribution[1], "\n\n")

  list(
    fits = fits,
    fit_stats = fit_stats,
    best_fit = fits[[fit_stats$distribution[1]]],
    formula = formula,
    data = surv_data
  )
}


#' Extrapolate Survival Curves
#'
#' Predict survival probabilities over extended time horizon
#'
#' @param fit_result Result from fit_parametric_survival_curves()
#' @param time_horizon Maximum time to extrapolate to
#' @param times Specific time points (if NULL, creates sequence)
#' @param treatment Treatment level (for stratified models)
#' @return Data frame with predicted survival at each time
#' @export
extrapolate_survival <- function(fit_result,
                                 time_horizon = 120,
                                 times = NULL,
                                 treatment = NULL) {

  if (is.null(times)) {
    times <- seq(0, time_horizon, length.out = 100)
  }

  best_fit <- fit_result$best_fit

  # Create new data for prediction
  if (!is.null(treatment)) {
    newdata <- data.frame(treatment = rep(treatment, length(times)))
  } else {
    newdata <- data.frame(time = times)
  }

  # Predict survival
  surv_pred <- summary(best_fit, type = "survival", t = times, newdata = newdata, ci = TRUE)

  result <- data.frame(
    time = times,
    survival = surv_pred[[1]]$est,
    lower = surv_pred[[1]]$lcl,
    upper = surv_pred[[1]]$ucl,
    distribution = fit_result$fit_stats$distribution[1]
  )

  return(result)
}


#' Calculate Restricted Mean Survival Time
#'
#' Area under survival curve up to time horizon
#'
#' @param fit_result Result from fit_parametric_survival_curves()
#' @param time_horizon Time horizon for RMST calculation
#' @return RMST value with confidence interval
#' @export
calculate_rmst <- function(fit_result, time_horizon = 120) {

  best_fit <- fit_result$best_fit

  rmst_result <- tryCatch({
    rmst_flexsurv(best_fit, t = time_horizon, ci = TRUE)
  }, error = function(e) {
    # Manual integration if rmst_flexsurv fails
    times <- seq(0, time_horizon, length.out = 1000)
    surv_pred <- summary(best_fit, type = "survival", t = times, ci = FALSE)
    rmst <- sum(surv_pred[[1]]$est) * (time_horizon / 1000)
    list(est = rmst, lcl = NA, ucl = NA)
  })

  data.frame(
    RMST = rmst_result$est,
    lower = rmst_result$lcl,
    upper = rmst_result$ucl,
    time_horizon = time_horizon
  )
}


#' Build Partitioned Survival Model
#'
#' Combines PFS and OS curves to create state membership over time
#'
#' @param pfs_fit_result PFS curve fit result
#' @param os_fit_result OS curve fit result
#' @param time_horizon Maximum time for model
#' @param times Specific time points
#' @return Data frame with proportion in each state over time
#' @export
build_partition_survival_model <- function(pfs_fit_result,
                                           os_fit_result,
                                           time_horizon = 120,
                                           times = NULL) {

  if (is.null(times)) {
    times <- seq(0, time_horizon, by = 1)
  }

  cat("\n=== Building Partitioned Survival Model ===\n")
  cat("Time horizon:", time_horizon, "months\n")
  cat("Time points:", length(times), "\n\n")

  # Extract survival probabilities
  pfs_surv <- extrapolate_survival(pfs_fit_result, time_horizon = time_horizon, times = times)
  os_surv <- extrapolate_survival(os_fit_result, time_horizon = time_horizon, times = times)

  # Calculate state membership
  # State 1: Progression-free (PFS)
  # State 2: Progressed (OS - PFS)
  # State 3: Dead (1 - OS)

  partition_model <- data.frame(
    time = times,
    PFS = pfs_surv$survival,
    OS = os_surv$survival,
    state_progression_free = pfs_surv$survival,
    state_progressed = os_surv$survival - pfs_surv$survival,
    state_dead = 1 - os_surv$survival
  )

  # Ensure states are non-negative (numerical issues)
  partition_model$state_progressed <- pmax(0, partition_model$state_progressed)

  # Verify states sum to 1
  row_sums <- partition_model$state_progression_free +
              partition_model$state_progressed +
              partition_model$state_dead

  if (any(abs(row_sums - 1) > 0.01)) {
    warning("State probabilities do not sum to 1. Check PFS/OS consistency.")
  }

  cat("✓ Partitioned survival model created\n")
  cat(sprintf("  Proportion still progression-free at t=%d: %.1f%%\n",
              time_horizon, 100 * tail(partition_model$state_progression_free, 1)))
  cat(sprintf("  Proportion alive at t=%d: %.1f%%\n",
              time_horizon, 100 * tail(partition_model$OS, 1)))
  cat("\n")

  return(partition_model)
}


#' Calculate QALYs from Partitioned Survival
#'
#' Computes quality-adjusted life years by health state
#'
#' @param partition_model Result from build_partition_survival_model()
#' @param utility_pfs Utility weight for progression-free state
#' @param utility_progressed Utility weight for progressed state
#' @param utility_dead Utility weight for dead state (always 0)
#' @param discount_rate Annual discount rate (e.g., 0.035 for 3.5%)
#' @param cycle_length Length of each time cycle in years
#' @return List with total QALYs and QALYs by state
#' @export
calculate_qalys <- function(partition_model,
                           utility_pfs = 0.8,
                           utility_progressed = 0.6,
                           utility_dead = 0,
                           discount_rate = 0.035,
                           cycle_length = 1/12) {  # 1 month in years

  cat("\n=== Calculating QALYs ===\n")
  cat("Utility weights:\n")
  cat(sprintf("  Progression-free: %.2f\n", utility_pfs))
  cat(sprintf("  Progressed: %.2f\n", utility_progressed))
  cat(sprintf("Discount rate: %.1f%%\n", discount_rate * 100))
  cat(sprintf("Cycle length: %.3f years\n\n", cycle_length))

  # Calculate discount factors
  partition_model$discount_factor <- 1 / ((1 + discount_rate) ^ (partition_model$time * cycle_length))

  # Calculate QALYs by state (area under curve with utility weights and discounting)
  partition_model$qaly_pfs <- partition_model$state_progression_free * utility_pfs * partition_model$discount_factor * cycle_length
  partition_model$qaly_progressed <- partition_model$state_progressed * utility_progressed * partition_model$discount_factor * cycle_length
  partition_model$qaly_dead <- 0  # Always 0

  # Total QALYs
  total_qaly_pfs <- sum(partition_model$qaly_pfs)
  total_qaly_progressed <- sum(partition_model$qaly_progressed)
  total_qalys <- total_qaly_pfs + total_qaly_progressed

  # Life years (undiscounted, no utility weights)
  partition_model$ly_pfs <- partition_model$state_progression_free * cycle_length
  partition_model$ly_progressed <- partition_model$state_progressed * cycle_length

  total_ly_pfs <- sum(partition_model$ly_pfs)
  total_ly_progressed <- sum(partition_model$ly_progressed)
  total_lys <- total_ly_pfs + total_ly_progressed

  cat("Results:\n")
  cat(sprintf("  Total Life Years: %.3f\n", total_lys))
  cat(sprintf("    - Progression-free: %.3f (%.1f%%)\n", total_ly_pfs, 100*total_ly_pfs/total_lys))
  cat(sprintf("    - Progressed: %.3f (%.1f%%)\n", total_ly_progressed, 100*total_ly_progressed/total_lys))
  cat(sprintf("  Total QALYs: %.3f\n", total_qalys))
  cat(sprintf("    - Progression-free: %.3f (%.1f%%)\n", total_qaly_pfs, 100*total_qaly_pfs/total_qalys))
  cat(sprintf("    - Progressed: %.3f (%.1f%%)\n\n", total_qaly_progressed, 100*total_qaly_progressed/total_qalys))

  list(
    total_qalys = total_qalys,
    total_lys = total_lys,
    qaly_by_state = data.frame(
      state = c("progression_free", "progressed"),
      QALYs = c(total_qaly_pfs, total_qaly_progressed),
      LYs = c(total_ly_pfs, total_ly_progressed)
    ),
    partition_model = partition_model,
    utilities = c(pfs = utility_pfs, progressed = utility_progressed)
  )
}


#' Run Complete Partitioned Survival Analysis
#'
#' Main workflow function for partitioned survival modeling
#'
#' @param pfs_data PFS survival data (time, event)
#' @param os_data OS survival data (time, event)
#' @param time_horizon Time horizon for extrapolation (months)
#' @param utility_pfs Utility for PFS state
#' @param utility_progressed Utility for progressed state
#' @param discount_rate Annual discount rate
#' @param distributions Distributions to try
#' @return List with all results
#' @export
run_partition_survival_analysis <- function(pfs_data,
                                           os_data,
                                           time_horizon = 120,
                                           utility_pfs = 0.8,
                                           utility_progressed = 0.6,
                                           discount_rate = 0.035,
                                           distributions = c("exp", "weibull", "lnorm", "llogis", "gompertz")) {

  cat("\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║      EvidenceOS PRIME - Partitioned Survival v4.0           ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")

  # Step 1: Fit PFS curves
  cat("\n--- Step 1: Fitting PFS Curves ---\n")
  pfs_fits <- fit_parametric_survival_curves(pfs_data, distributions = distributions)

  # Step 2: Fit OS curves
  cat("\n--- Step 2: Fitting OS Curves ---\n")
  os_fits <- fit_parametric_survival_curves(os_data, distributions = distributions)

  # Step 3: Build partitioned model
  cat("\n--- Step 3: Building Partitioned Model ---\n")
  partition_model <- build_partition_survival_model(pfs_fits, os_fits, time_horizon = time_horizon)

  # Step 4: Calculate QALYs
  cat("\n--- Step 4: Calculating QALYs ---\n")
  qaly_results <- calculate_qalys(
    partition_model = partition_model,
    utility_pfs = utility_pfs,
    utility_progressed = utility_progressed,
    discount_rate = discount_rate
  )

  cat("╔══════════════════════════════════════════════════════════════╗\n")
  cat("║                    Analysis Complete!                        ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")

  list(
    pfs_fits = pfs_fits,
    os_fits = os_fits,
    partition_model = partition_model,
    qaly_results = qaly_results,
    parameters = list(
      time_horizon = time_horizon,
      utilities = c(pfs = utility_pfs, progressed = utility_progressed),
      discount_rate = discount_rate
    )
  )
}


# ============================================================================
# Example Usage
# ============================================================================

# Example:
# pfs_data <- read.csv("pfs_data.csv")  # Columns: time, event
# os_data <- read.csv("os_data.csv")    # Columns: time, event
#
# results <- run_partition_survival_analysis(
#   pfs_data = pfs_data,
#   os_data = os_data,
#   time_horizon = 120,  # 10 years
#   utility_pfs = 0.85,
#   utility_progressed = 0.65,
#   discount_rate = 0.035
# )
#
# # View QALYs
# results$qaly_results$total_qalys
# results$qaly_results$qaly_by_state
