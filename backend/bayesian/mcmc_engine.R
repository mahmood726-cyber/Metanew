# ============================================================================
# Bayesian NMA - MCMC Sampling Engine
# ============================================================================
# Executes Bayesian MCMC sampling using brms/Stan backend
# Handles parallel chains, convergence monitoring, and error recovery
# ============================================================================

library(brms)
library(parallel)
library(future)

#' Run Bayesian NMA with brms
#'
#' Main function to execute MCMC sampling for network meta-analysis
#'
#' @param model_spec Complete model specification from build_full_nma_model()
#' @param chains Number of MCMC chains (default: 4)
#' @param iter Total iterations per chain (default: 4000)
#' @param warmup Warmup/burn-in iterations (default: 2000)
#' @param thin Thinning interval (default: 1)
#' @param cores Number of CPU cores to use (default: auto-detect)
#' @param seed Random seed for reproducibility
#' @param verbose Show sampling progress (default: TRUE)
#' @return brmsfit object with posterior samples
#' @export
run_brms_nma <- function(model_spec,
                        chains = 4,
                        iter = 4000,
                        warmup = 2000,
                        thin = 1,
                        cores = NULL,
                        seed = 12345,
                        verbose = TRUE) {

  # Validate model specification first
  validation <- validate_model_specification(model_spec)
  if (!validation$is_valid) {
    stop("Model specification invalid:\n", paste(validation$messages, collapse = "\n"))
  }

  # Print warnings if any
  if (length(validation$messages) > 0) {
    message("Validation warnings:")
    message(paste(validation$messages, collapse = "\n"))
  }

  # Auto-detect cores if not specified
  if (is.null(cores)) {
    cores <- min(chains, parallel::detectCores() - 1)
  }

  if (verbose) {
    cat("\n========================================\n")
    cat("Bayesian Network Meta-Analysis\n")
    cat("========================================\n\n")
    cat("Model type:", model_spec$model_type, "effects\n")
    cat("Outcome type:", model_spec$outcome_type, "\n")
    cat("Treatments:", nrow(model_spec$treat_map), "\n")
    cat("Studies:", length(unique(model_spec$data$study)), "\n")
    cat("Comparisons:", nrow(model_spec$data), "\n\n")
    cat("MCMC Settings:\n")
    cat("  Chains:", chains, "\n")
    cat("  Iterations:", iter, "\n")
    cat("  Warmup:", warmup, "\n")
    cat("  Thin:", thin, "\n")
    cat("  Cores:", cores, "\n")
    cat("  Seed:", seed, "\n\n")
    cat("Starting MCMC sampling...\n")
    cat("(This may take 5-30 minutes depending on network complexity)\n\n")
  }

  # Execute brms sampling
  start_time <- Sys.time()

  fit <- tryCatch({
    brm(
      formula = model_spec$formula,
      data = model_spec$data,
      prior = model_spec$priors,
      chains = chains,
      iter = iter,
      warmup = warmup,
      thin = thin,
      cores = cores,
      seed = seed,
      control = list(
        adapt_delta = 0.95,      # Higher acceptance rate for complex posteriors
        max_treedepth = 12       # Deeper trees if needed
      ),
      backend = "rstan",          # Use rstan backend
      silent = !verbose,
      refresh = if (verbose) 100 else 0,
      save_pars = save_pars(all = TRUE)  # Save all parameters
    )
  }, error = function(e) {
    # Enhanced error handling
    error_msg <- conditionMessage(e)

    if (grepl("divergent transitions", error_msg, ignore.case = TRUE)) {
      message("\n⚠️ Divergent transitions detected!")
      message("Try increasing adapt_delta (e.g., to 0.99) or reparameterizing the model")
    } else if (grepl("max_treedepth", error_msg, ignore.case = TRUE)) {
      message("\n⚠️ Maximum tree depth exceeded!")
      message("Try increasing max_treedepth to 15 or simplifying the model")
    } else if (grepl("initialization", error_msg, ignore.case = TRUE)) {
      message("\n⚠️ Initialization failed!")
      message("Try different initial values or check data for issues")
    }

    stop("MCMC sampling failed: ", error_msg)
  })

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "mins"))

  if (verbose) {
    cat("\n========================================\n")
    cat("Sampling completed successfully!\n")
    cat("Elapsed time:", round(elapsed, 2), "minutes\n")
    cat("========================================\n\n")
  }

  # Add metadata to fit object
  fit$evidenceos_meta <- list(
    model_spec = model_spec,
    elapsed_time_mins = elapsed,
    timestamp = Sys.time(),
    version = "EvidenceOS PRIME v4.0"
  )

  return(fit)
}


#' Run NMA with Automatic Convergence Checking
#'
#' Iteratively runs MCMC with increasing iterations until convergence
#'
#' @param model_spec Model specification
#' @param max_iter Maximum total iterations to try (default: 20000)
#' @param max_attempts Maximum number of re-runs (default: 3)
#' @param rhat_threshold Convergence threshold for R-hat (default: 1.01)
#' @return brmsfit object
#' @export
run_nma_with_auto_convergence <- function(model_spec,
                                         max_iter = 20000,
                                         max_attempts = 3,
                                         rhat_threshold = 1.01) {

  iter_sequence <- c(4000, 8000, 12000, 20000)
  warmup_sequence <- iter_sequence / 2

  for (attempt in 1:max_attempts) {
    iter <- min(iter_sequence[attempt], max_iter)
    warmup <- warmup_sequence[attempt]

    cat(sprintf("\nAttempt %d: Running %d iterations (%d warmup)...\n",
                attempt, iter, warmup))

    fit <- run_brms_nma(
      model_spec = model_spec,
      chains = 4,
      iter = iter,
      warmup = warmup,
      verbose = TRUE
    )

    # Check convergence
    rhat_vals <- rhat(fit)
    max_rhat <- max(rhat_vals, na.rm = TRUE)

    cat(sprintf("Max R-hat: %.4f (threshold: %.4f)\n", max_rhat, rhat_threshold))

    if (max_rhat < rhat_threshold) {
      cat("✓ Convergence achieved!\n")
      return(fit)
    } else {
      cat("⚠️ Convergence not achieved, increasing iterations...\n")
    }
  }

  warning("Failed to achieve convergence after ", max_attempts, " attempts")
  warning("Max R-hat: ", max_rhat, " (threshold: ", rhat_threshold, ")")
  warning("Results may not be reliable. Consider model reparameterization.")

  return(fit)
}


#' Parallel MCMC for Large Networks
#'
#' Distributes MCMC chains across multiple machines or cores
#'
#' @param model_spec Model specification
#' @param chains Total number of chains
#' @param parallel_strategy "multicore", "multisession", or "cluster"
#' @return brmsfit object
#' @export
run_parallel_nma <- function(model_spec,
                            chains = 8,
                            parallel_strategy = "multicore") {

  library(future)
  library(future.apply)

  # Set up parallel backend
  if (parallel_strategy == "multicore") {
    plan(multicore, workers = min(chains, availableCores() - 1))
  } else if (parallel_strategy == "multisession") {
    plan(multisession, workers = min(chains, availableCores() - 1))
  } else if (parallel_strategy == "cluster") {
    # TODO: Set up cluster workers
    stop("Cluster parallelization not yet implemented")
  }

  # Run with future backend
  fit <- run_brms_nma(
    model_spec = model_spec,
    chains = chains,
    cores = chains,
    verbose = TRUE
  )

  return(fit)
}


#' Resume Failed MCMC Sampling
#'
#' Continue sampling from a previous run that failed or was interrupted
#'
#' @param previous_fit Incomplete brmsfit object
#' @param additional_iter Additional iterations to run
#' @return Updated brmsfit object
#' @export
resume_nma_sampling <- function(previous_fit, additional_iter = 2000) {

  # Use brms update() to continue sampling
  updated_fit <- update(
    previous_fit,
    iter = additional_iter,
    recompile = FALSE,
    refresh = 100
  )

  return(updated_fit)
}


#' Save and Load MCMC Results
#'
#' Efficient storage of brmsfit objects
#'
#' @param fit brmsfit object
#' @param file_path Path to save (default: outputs/bayesian/[timestamp].rds)
#' @export
save_nma_results <- function(fit, file_path = NULL) {

  if (is.null(file_path)) {
    dir.create("outputs/bayesian", recursive = TRUE, showWarnings = FALSE)
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    file_path <- file.path("outputs/bayesian", paste0("nma_fit_", timestamp, ".rds"))
  }

  # Save fit object
  saveRDS(fit, file_path, compress = "xz")

  cat("Results saved to:", file_path, "\n")
  cat("File size:", round(file.size(file_path) / 1024^2, 2), "MB\n")

  return(file_path)
}


#' @rdname save_nma_results
#' @param file_path Path to load from
#' @export
load_nma_results <- function(file_path) {
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }

  fit <- readRDS(file_path)

  if (!inherits(fit, "brmsfit")) {
    stop("File does not contain a brmsfit object")
  }

  return(fit)
}


#' Extract Posterior Samples (Raw)
#'
#' Get raw MCMC samples for custom analysis
#'
#' @param fit brmsfit object
#' @param pars Parameters to extract (default: all)
#' @return Array of posterior samples [iterations, chains, parameters]
#' @export
extract_raw_samples <- function(fit, pars = NULL) {

  samples <- as.array(fit, pars = pars)
  return(samples)
}


#' Monitor MCMC Progress in Real-Time
#'
#' Create live dashboard of sampling progress
#'
#' @param fit brmsfit object (can be incomplete)
#' @return Summary of current sampling state
#' @export
monitor_mcmc_progress <- function(fit) {

  # TODO: Implement real-time monitoring dashboard
  # Could use shiny or plotly for live updates
  # Show: iterations completed, R-hat evolution, trace plots

  stop("Real-time monitoring not yet implemented")
  stop("Use refresh > 0 in run_brms_nma() for basic progress updates")
}
