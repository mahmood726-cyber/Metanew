# ============================================================================
# Bayesian NMA - Main Integration Module
# ============================================================================
# High-level interface for Bayesian network meta-analysis
# This module integrates all backend components into a simple API
# ============================================================================

# Source all backend modules
source("backend/bayesian/data_prep.R")
source("backend/bayesian/model_specs.R")
source("backend/bayesian/mcmc_engine.R")
source("backend/bayesian/posterior_analysis.R")
source("backend/bayesian/diagnostics.R")

#' Run Complete Bayesian NMA Analysis
#'
#' One-stop function for Bayesian network meta-analysis
#' Handles data prep, model fitting, posterior analysis, and diagnostics
#'
#' @param nma_data netmeta object or pairwise data.frame
#' @param model_type "fixed" or "random" effects
#' @param outcome_type "continuous", "binary", or "count"
#' @param prior_type "vague", "weakly_informative", "informative", or "custom"
#' @param chains Number of MCMC chains (default: 4)
#' @param iter Total iterations per chain (default: 4000)
#' @param warmup Warmup iterations (default: 2000)
#' @param direction "higher_better" or "lower_better" for rankings
#' @param reference_treatment Reference treatment name (default: first)
#' @param auto_convergence Logical, automatically increase iterations if needed
#' @param run_diagnostics Logical, run full convergence diagnostics
#' @param save_results Logical, save results to disk
#' @param verbose Print progress messages
#' @return List with fit, posterior_summary, and diagnostics
#' @export
run_bayesian_nma <- function(nma_data,
                             model_type = "random",
                             outcome_type = "continuous",
                             prior_type = "weakly_informative",
                             chains = 4,
                             iter = 4000,
                             warmup = 2000,
                             direction = "higher_better",
                             reference_treatment = NULL,
                             auto_convergence = TRUE,
                             run_diagnostics = TRUE,
                             save_results = FALSE,
                             verbose = TRUE) {

  if (verbose) {
    cat("\n")
    cat("╔══════════════════════════════════════════════════════════════╗\n")
    cat("║         EvidenceOS PRIME - Bayesian NMA v4.0                ║\n")
    cat("╚══════════════════════════════════════════════════════════════╝\n")
    cat("\n")
  }

  # =====================
  # STEP 1: Data Preparation
  # =====================
  if (verbose) cat("⏳ Step 1/5: Preparing data...\n")

  brms_data <- prepare_nma_data_for_brms(nma_data)

  # Validate network connectivity
  conn_matrix <- create_connectivity_matrix(brms_data)
  conn_check <- validate_network_connectivity(conn_matrix)

  if (!conn_check$is_connected) {
    stop("Network is disconnected. ", conn_check$n_components, " separate components detected.")
  }

  if (verbose) {
    treat_map <- attr(brms_data, "treatment_map")
    cat(sprintf("  ✓ Treatments: %d\n", nrow(treat_map)))
    cat(sprintf("  ✓ Studies: %d\n", length(unique(brms_data$study))))
    cat(sprintf("  ✓ Comparisons: %d\n", nrow(brms_data)))
    cat(sprintf("  ✓ Network: %s\n", ifelse(conn_check$is_connected, "Connected", "Disconnected")))
    cat("\n")
  }

  # =====================
  # STEP 2: Model Specification
  # =====================
  if (verbose) cat("⏳ Step 2/5: Specifying Bayesian model...\n")

  model_spec <- build_full_nma_model(
    brms_data = brms_data,
    model_type = model_type,
    outcome_type = outcome_type,
    prior_type = prior_type
  )

  # Validate model
  validation <- validate_model_specification(model_spec)
  if (!validation$is_valid) {
    stop("Model validation failed:\n", paste(validation$messages, collapse = "\n"))
  }

  if (verbose) {
    cat(sprintf("  ✓ Model: %s effects\n", model_type))
    cat(sprintf("  ✓ Outcome: %s\n", outcome_type))
    cat(sprintf("  ✓ Priors: %s\n", prior_type))
    cat("\n")
  }

  # =====================
  # STEP 3: MCMC Sampling
  # =====================
  if (verbose) cat("⏳ Step 3/5: Running MCMC sampling...\n")
  if (verbose) cat("  (This may take 5-30 minutes)\n\n")

  if (auto_convergence) {
    # Automatically increase iterations if needed
    fit <- run_nma_with_auto_convergence(
      model_spec = model_spec,
      max_iter = iter * 3,
      rhat_threshold = 1.01
    )
  } else {
    # Single run with specified iterations
    fit <- run_brms_nma(
      model_spec = model_spec,
      chains = chains,
      iter = iter,
      warmup = warmup,
      verbose = verbose
    )
  }

  if (verbose) cat("\n  ✓ Sampling completed\n\n")

  # =====================
  # STEP 4: Posterior Analysis
  # =====================
  if (verbose) cat("⏳ Step 4/5: Analyzing posterior distributions...\n")

  posterior_summary <- create_posterior_summary(fit, direction = direction)

  if (verbose) {
    cat(sprintf("  ✓ Treatment effects extracted\n"))
    cat(sprintf("  ✓ SUCRA scores calculated\n"))
    cat(sprintf("  ✓ League table generated\n"))
    cat(sprintf("  ✓ Heterogeneity estimated\n"))
    cat("\n")
  }

  # =====================
  # STEP 5: Convergence Diagnostics
  # =====================
  diagnostics <- NULL
  if (run_diagnostics) {
    if (verbose) cat("⏳ Step 5/5: Running convergence diagnostics...\n\n")

    diagnostics <- run_convergence_diagnostics(fit, verbose = verbose)

    if (!diagnostics$overall_pass) {
      warning("\n⚠️ Convergence diagnostics indicate potential issues")
      warning("Results may not be reliable. See diagnostics for details.\n")
    }
  } else {
    if (verbose) cat("⏭️ Step 5/5: Skipping diagnostics (run_diagnostics = FALSE)\n\n")
  }

  # =====================
  # Optional: Save Results
  # =====================
  file_path <- NULL
  if (save_results) {
    if (verbose) cat("💾 Saving results...\n")
    file_path <- save_nma_results(fit)
    if (verbose) cat("\n")
  }

  # =====================
  # Final Report
  # =====================
  if (verbose) {
    cat("╔══════════════════════════════════════════════════════════════╗\n")
    cat("║                    Analysis Complete!                        ║\n")
    cat("╚══════════════════════════════════════════════════════════════╝\n")
    cat("\n")

    cat("Top 3 Treatments (by SUCRA):\n")
    top3 <- head(posterior_summary$sucra_scores, 3)
    for (i in 1:nrow(top3)) {
      cat(sprintf("  %d. %s (SUCRA = %.3f, Mean Rank = %.2f)\n",
                  i,
                  top3$treatment[i],
                  top3$sucra[i],
                  top3$mean_rank[i]))
    }
    cat("\n")

    if (!is.null(diagnostics)) {
      if (diagnostics$overall_pass) {
        cat("✅ Convergence: PASS - Results are reliable\n")
      } else {
        cat("⚠️ Convergence: FAIL - Results may not be reliable\n")
      }
    }

    if (!is.null(file_path)) {
      cat("\n📁 Results saved to:", file_path, "\n")
    }

    cat("\n")
  }

  # =====================
  # Return Results
  # =====================
  results <- list(
    fit = fit,
    posterior_summary = posterior_summary,
    diagnostics = diagnostics,
    model_spec = model_spec,
    data = brms_data,
    file_path = file_path,
    status = if (!is.null(diagnostics)) diagnostics$overall_pass else NA
  )

  class(results) <- c("bayesian_nma_results", "list")

  return(results)
}


#' Print Method for Bayesian NMA Results
#'
#' @param x bayesian_nma_results object
#' @export
print.bayesian_nma_results <- function(x, ...) {
  cat("\nBayesian Network Meta-Analysis Results\n")
  cat("=======================================\n\n")

  cat("Model Information:\n")
  cat(sprintf("  Type: %s effects\n", x$model_spec$model_type))
  cat(sprintf("  Treatments: %d\n", x$posterior_summary$model_info$n_treatments))
  cat(sprintf("  Studies: %d\n", x$posterior_summary$model_info$n_studies))
  cat(sprintf("  Runtime: %.1f minutes\n", x$posterior_summary$model_info$elapsed_time_mins))
  cat("\n")

  cat("Top 3 Treatments (SUCRA):\n")
  top3 <- head(x$posterior_summary$sucra_scores, 3)
  print(top3[, c("treatment", "sucra", "mean_rank")], row.names = FALSE)
  cat("\n")

  if (!is.null(x$diagnostics)) {
    cat("Convergence Status:", ifelse(x$status, "✓ PASS", "✗ FAIL"), "\n")
  }

  cat("\nUse summary() for detailed results\n")
}


#' Summary Method for Bayesian NMA Results
#'
#' @param object bayesian_nma_results object
#' @export
summary.bayesian_nma_results <- function(object, ...) {
  cat("\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║         Bayesian Network Meta-Analysis Summary              ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")

  # Model info
  cat("Model Specification:\n")
  cat(sprintf("  Model type: %s effects\n", object$model_spec$model_type))
  cat(sprintf("  Outcome type: %s\n", object$model_spec$outcome_type))
  cat(sprintf("  Treatments: %d\n", object$posterior_summary$model_info$n_treatments))
  cat(sprintf("  Studies: %d\n", object$posterior_summary$model_info$n_studies))
  cat(sprintf("  Runtime: %.1f minutes\n", object$posterior_summary$model_info$elapsed_time_mins))
  cat("\n")

  # Treatment effects
  cat("Treatment Effects (vs reference):\n")
  print(object$posterior_summary$treatment_effects, row.names = FALSE, digits = 3)
  cat("\n")

  # SUCRA scores
  cat("Treatment Rankings (SUCRA):\n")
  print(object$posterior_summary$sucra_scores, row.names = FALSE, digits = 3)
  cat("\n")

  # Heterogeneity
  if (!is.null(object$posterior_summary$heterogeneity)) {
    cat("Between-Study Heterogeneity:\n")
    print(object$posterior_summary$heterogeneity, row.names = FALSE, digits = 3)
    cat("\n")
  }

  # Convergence
  if (!is.null(object$diagnostics)) {
    cat("Convergence Diagnostics:\n")
    cat(sprintf("  R-hat (max): %.4f %s\n",
                object$diagnostics$rhat$summary$max_rhat,
                ifelse(object$diagnostics$rhat$converged, "✓", "✗")))
    cat(sprintf("  ESS (min): %.0f %s\n",
                object$diagnostics$ess$summary$min_ess,
                ifelse(object$diagnostics$ess$adequate, "✓", "✗")))
    cat(sprintf("  Divergences: %d %s\n",
                object$diagnostics$divergences$n_divergent,
                ifelse(!object$diagnostics$divergences$has_divergences, "✓", "⚠")))
    cat(sprintf("  Overall: %s\n",
                ifelse(object$status, "PASS ✓", "FAIL ✗")))
  }

  cat("\n")
}


#' Quick Bayesian NMA (with defaults)
#'
#' Convenience function for quick analysis with sensible defaults
#'
#' @param nma_data netmeta object or data frame
#' @param ... Additional arguments passed to run_bayesian_nma()
#' @export
quick_bayesian_nma <- function(nma_data, ...) {
  run_bayesian_nma(
    nma_data = nma_data,
    model_type = "random",
    outcome_type = "continuous",
    prior_type = "weakly_informative",
    chains = 4,
    iter = 4000,
    warmup = 2000,
    auto_convergence = TRUE,
    run_diagnostics = TRUE,
    save_results = TRUE,
    verbose = TRUE,
    ...
  )
}


#' Compare Multiple Prior Specifications
#'
#' Sensitivity analysis across different priors
#'
#' @param nma_data netmeta object or data frame
#' @param prior_types Vector of prior types to compare
#' @return List of results for each prior
#' @export
compare_priors <- function(nma_data, prior_types = c("vague", "weakly_informative", "informative")) {

  results_list <- list()

  for (prior in prior_types) {
    cat(sprintf("\n=== Running with %s priors ===\n", prior))

    results_list[[prior]] <- run_bayesian_nma(
      nma_data = nma_data,
      prior_type = prior,
      run_diagnostics = FALSE,  # Skip for speed
      save_results = FALSE,
      verbose = FALSE
    )
  }

  # Compare SUCRA scores across priors
  comparison <- data.frame()
  for (prior in prior_types) {
    sucra <- results_list[[prior]]$posterior_summary$sucra_scores
    sucra$prior <- prior
    comparison <- rbind(comparison, sucra)
  }

  list(
    results = results_list,
    sucra_comparison = comparison
  )
}


# ============================================================================
# Example Usage
# ============================================================================

# Example 1: Basic usage
# library(netmeta)
# data(Senn2013)
# net <- netmeta(TE, seTE, treat1, treat2, studlab, data = Senn2013, sm = "MD")
# results <- run_bayesian_nma(net, verbose = TRUE)
# print(results)
# summary(results)

# Example 2: Quick analysis
# results <- quick_bayesian_nma(net)

# Example 3: Prior sensitivity
# prior_comparison <- compare_priors(net)

# Example 4: Manual control
# results <- run_bayesian_nma(
#   nma_data = net,
#   model_type = "random",
#   chains = 6,
#   iter = 10000,
#   warmup = 5000,
#   direction = "higher_better",
#   auto_convergence = FALSE
# )
