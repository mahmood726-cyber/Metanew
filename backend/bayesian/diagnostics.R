# ============================================================================
# Bayesian NMA - Convergence Diagnostics Module
# ============================================================================
# Comprehensive MCMC convergence diagnostics
# Reference: Vehtari et al. (2021) - Rank-normalized split R-hat
# ============================================================================

library(brms)
library(posterior)
library(bayesplot)
library(ggplot2)

#' Compute R-hat Statistics
#'
#' Gelman-Rubin convergence diagnostic (should be < 1.01)
#'
#' @param fit brmsfit object
#' @return data.frame with R-hat for each parameter
#' @export
compute_rhat_statistics <- function(fit) {

  rhat_vals <- rhat(fit)

  rhat_df <- data.frame(
    parameter = names(rhat_vals),
    rhat = as.numeric(rhat_vals),
    stringsAsFactors = FALSE
  ) %>%
    arrange(desc(rhat))

  # Flag problematic parameters
  rhat_df$status <- ifelse(rhat_df$rhat < 1.01, "OK",
                            ifelse(rhat_df$rhat < 1.05, "WARNING", "FAIL"))

  # Summary
  summary_stats <- list(
    max_rhat = max(rhat_df$rhat, na.rm = TRUE),
    n_failed = sum(rhat_df$status == "FAIL", na.rm = TRUE),
    n_warning = sum(rhat_df$status == "WARNING", na.rm = TRUE),
    n_ok = sum(rhat_df$status == "OK", na.rm = TRUE),
    pct_converged = mean(rhat_df$rhat < 1.01, na.rm = TRUE) * 100
  )

  list(
    rhat_df = rhat_df,
    summary = summary_stats,
    converged = summary_stats$max_rhat < 1.01
  )
}


#' Compute Effective Sample Size
#'
#' ESS should be > 400 for reliable inference
#'
#' @param fit brmsfit object
#' @param type "bulk" (default) or "tail"
#' @return data.frame with ESS for each parameter
#' @export
compute_effective_sample_size <- function(fit, type = "bulk") {

  if (type == "bulk") {
    ess_vals <- ess_bulk(fit)
  } else {
    ess_vals <- ess_tail(fit)
  }

  ess_df <- data.frame(
    parameter = names(ess_vals),
    ess = as.numeric(ess_vals),
    stringsAsFactors = FALSE
  ) %>%
    arrange(ess)

  # Flag low ESS
  ess_df$status <- ifelse(ess_df$ess >= 400, "OK",
                          ifelse(ess_df$ess >= 200, "WARNING", "FAIL"))

  summary_stats <- list(
    min_ess = min(ess_df$ess, na.rm = TRUE),
    median_ess = median(ess_df$ess, na.rm = TRUE),
    n_failed = sum(ess_df$status == "FAIL", na.rm = TRUE),
    pct_adequate = mean(ess_df$ess >= 400, na.rm = TRUE) * 100
  )

  list(
    ess_df = ess_df,
    summary = summary_stats,
    adequate = summary_stats$min_ess >= 200
  )
}


#' Check for Divergent Transitions
#'
#' Divergent transitions indicate problematic posterior geometry
#'
#' @param fit brmsfit object
#' @return List with divergence information
#' @export
check_divergent_transitions <- function(fit) {

  np <- nuts_params(fit)

  if (is.null(np)) {
    return(list(
      n_divergent = 0,
      pct_divergent = 0,
      has_divergences = FALSE,
      recommendation = "No divergence information available"
    ))
  }

  n_total <- nrow(np)
  n_divergent <- sum(subset(np, Parameter == "divergent__")$Value)
  pct_divergent <- (n_divergent / n_total) * 100

  recommendation <- if (n_divergent == 0) {
    "No divergent transitions detected. Good!"
  } else if (pct_divergent < 1) {
    "Few divergent transitions (<1%). May be acceptable but investigate."
  } else {
    "Many divergent transitions (≥1%). Increase adapt_delta or reparameterize model."
  }

  list(
    n_divergent = n_divergent,
    n_total = n_total,
    pct_divergent = pct_divergent,
    has_divergences = n_divergent > 0,
    recommendation = recommendation
  )
}


#' Check Maximum Tree Depth
#'
#' Hitting max treedepth indicates inefficient sampling
#'
#' @param fit brmsfit object
#' @return List with treedepth information
#' @export
check_max_treedepth <- function(fit) {

  np <- nuts_params(fit)

  if (is.null(np)) {
    return(list(
      n_max_treedepth = 0,
      pct_max_treedepth = 0,
      has_issues = FALSE
    ))
  }

  n_total <- nrow(np)
  n_max <- sum(subset(np, Parameter == "treedepth__")$Value >= 10)
  pct_max <- (n_max / n_total) * 100

  recommendation <- if (n_max == 0) {
    "No max treedepth issues."
  } else {
    "Some iterations hit max treedepth. Increase max_treedepth parameter."
  }

  list(
    n_max_treedepth = n_max,
    pct_max_treedepth = pct_max,
    has_issues = n_max > 0,
    recommendation = recommendation
  )
}


#' Create Trace Plots
#'
#' Visual inspection of MCMC chains
#'
#' @param fit brmsfit object
#' @param pars Parameters to plot (default: treatment effects)
#' @return ggplot object
#' @export
create_trace_plots <- function(fit, pars = NULL) {

  if (is.null(pars)) {
    # Default to treatment effects
    all_pars <- variables(fit)
    pars <- grep("^b_treat", all_pars, value = TRUE)
  }

  if (length(pars) > 12) {
    warning("Too many parameters (", length(pars), "). Showing first 12.")
    pars <- pars[1:12]
  }

  posterior_draws <- as_draws_df(fit)

  plot <- mcmc_trace(posterior_draws, pars = pars) +
    theme_minimal() +
    labs(
      title = "MCMC Trace Plots",
      subtitle = "Chains should mix well (overlap) and be stationary",
      x = "Iteration",
      y = "Parameter Value"
    )

  return(plot)
}


#' Create Rank Histogram (Rhat diagnostic)
#'
#' Visual assessment of chain mixing
#'
#' @param fit brmsfit object
#' @param pars Parameters to plot
#' @return ggplot object
#' @export
create_rank_histogram <- function(fit, pars = NULL) {

  if (is.null(pars)) {
    all_pars <- variables(fit)
    pars <- grep("^b_treat", all_pars, value = TRUE)
  }

  posterior_draws <- as_draws_df(fit)

  plot <- mcmc_rank_hist(posterior_draws, pars = pars) +
    theme_minimal() +
    labs(
      title = "Rank Histograms",
      subtitle = "Should be uniform if chains are mixing well"
    )

  return(plot)
}


#' Create Autocorrelation Plots
#'
#' Check for autocorrelation in chains
#'
#' @param fit brmsfit object
#' @param pars Parameters to plot
#' @param lags Number of lags to show
#' @return ggplot object
#' @export
create_autocorrelation_plots <- function(fit, pars = NULL, lags = 20) {

  if (is.null(pars)) {
    all_pars <- variables(fit)
    pars <- grep("^b_treat", all_pars, value = TRUE)[1:min(6, length(all_pars))]
  }

  posterior_draws <- as_draws_df(fit)

  plot <- mcmc_acf(posterior_draws, pars = pars, lags = lags) +
    theme_minimal() +
    labs(
      title = "Autocorrelation Function",
      subtitle = "Should decay quickly to zero"
    )

  return(plot)
}


#' Create Posterior Density Plots
#'
#' Overlay of chains for visual convergence check
#'
#' @param fit brmsfit object
#' @param pars Parameters to plot
#' @return ggplot object
#' @export
create_density_overlay <- function(fit, pars = NULL) {

  if (is.null(pars)) {
    all_pars <- variables(fit)
    pars <- grep("^b_treat", all_pars, value = TRUE)
  }

  posterior_draws <- as_draws_df(fit)

  plot <- mcmc_dens_overlay(posterior_draws, pars = pars) +
    theme_minimal() +
    labs(
      title = "Posterior Density Overlay by Chain",
      subtitle = "Chains should overlap completely"
    )

  return(plot)
}


#' Comprehensive Convergence Report
#'
#' Complete diagnostic assessment
#'
#' @param fit brmsfit object
#' @param verbose Print detailed report
#' @return List with all diagnostics
#' @export
run_convergence_diagnostics <- function(fit, verbose = TRUE) {

  if (verbose) {
    cat("\n=====================================\n")
    cat("  Convergence Diagnostics Report\n")
    cat("=====================================\n\n")
  }

  # R-hat
  rhat_check <- compute_rhat_statistics(fit)

  if (verbose) {
    cat("R-hat Statistics:\n")
    cat(sprintf("  Max R-hat: %.4f\n", rhat_check$summary$max_rhat))
    cat(sprintf("  Parameters converged (R-hat < 1.01): %.1f%%\n",
                rhat_check$summary$pct_converged))
    cat(sprintf("  Status: %s\n",
                ifelse(rhat_check$converged, "✓ PASS", "✗ FAIL")))
    cat("\n")
  }

  # ESS
  ess_check <- compute_effective_sample_size(fit)

  if (verbose) {
    cat("Effective Sample Size:\n")
    cat(sprintf("  Min ESS: %.0f\n", ess_check$summary$min_ess))
    cat(sprintf("  Median ESS: %.0f\n", ess_check$summary$median_ess))
    cat(sprintf("  Parameters with ESS ≥ 400: %.1f%%\n",
                ess_check$summary$pct_adequate))
    cat(sprintf("  Status: %s\n",
                ifelse(ess_check$adequate, "✓ PASS", "✗ FAIL")))
    cat("\n")
  }

  # Divergences
  div_check <- check_divergent_transitions(fit)

  if (verbose) {
    cat("Divergent Transitions:\n")
    cat(sprintf("  Count: %d (%.2f%% of %d)\n",
                div_check$n_divergent,
                div_check$pct_divergent,
                div_check$n_total))
    cat(sprintf("  Status: %s\n",
                ifelse(!div_check$has_divergences, "✓ PASS", "⚠ WARNING")))
    cat(sprintf("  %s\n", div_check$recommendation))
    cat("\n")
  }

  # Tree depth
  tree_check <- check_max_treedepth(fit)

  if (verbose) {
    cat("Maximum Tree Depth:\n")
    cat(sprintf("  Iterations hitting max: %d (%.2f%%)\n",
                tree_check$n_max_treedepth,
                tree_check$pct_max_treedepth))
    cat(sprintf("  Status: %s\n",
                ifelse(!tree_check$has_issues, "✓ PASS", "⚠ WARNING")))
    cat("\n")
  }

  # Overall assessment
  overall_pass <- rhat_check$converged &&
                  ess_check$adequate &&
                  !div_check$has_divergences

  if (verbose) {
    cat("=====================================\n")
    cat("Overall Assessment: ")
    if (overall_pass) {
      cat("✓ PASS - Results are reliable\n")
    } else {
      cat("✗ FAIL - Results may not be reliable\n")
      cat("\nRecommendations:\n")
      if (!rhat_check$converged) {
        cat("  • Increase iterations (double current)\n")
      }
      if (!ess_check$adequate) {
        cat("  • Increase iterations or reduce thinning\n")
      }
      if (div_check$has_divergences) {
        cat("  • Increase adapt_delta to 0.99\n")
        cat("  • Consider model reparameterization\n")
      }
    }
    cat("=====================================\n\n")
  }

  list(
    rhat = rhat_check,
    ess = ess_check,
    divergences = div_check,
    treedepth = tree_check,
    overall_pass = overall_pass
  )
}


#' Export Diagnostic Report
#'
#' Save diagnostics to file
#'
#' @param fit brmsfit object
#' @param output_file Path to save report
#' @export
export_diagnostic_report <- function(fit, output_file = NULL) {

  if (is.null(output_file)) {
    dir.create("outputs/bayesian/diagnostics", recursive = TRUE, showWarnings = FALSE)
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    output_file <- file.path("outputs/bayesian/diagnostics",
                             paste0("convergence_report_", timestamp, ".txt"))
  }

  # Capture output
  sink(output_file)
  diagnostics <- run_convergence_diagnostics(fit, verbose = TRUE)
  sink()

  cat("Diagnostic report saved to:", output_file, "\n")

  return(diagnostics)
}
