# EXTREME PERFORMANCE OPTIMIZATIONS
# Making EvidenceOS PRIME even faster with advanced techniques
#
# Techniques:
# 1. Parallel processing (multi-core)
# 2. Compiled R code (byte compilation)
# 3. Vectorized operations
# 4. Pre-computed lookup tables
# 5. Incremental computation
# 6. Data streaming

library(parallel)
library(compiler)

# ============================================================================
# PARALLEL PROCESSING FOR META-ANALYSIS
# ============================================================================

#' Run meta-analysis in parallel for multiple outcomes
#' @param data Data frame with multiple outcomes
#' @param outcomes Vector of outcome names
#' @param method MA method (REML, DL, etc.)
#' @param n_cores Number of cores to use (default: detect automatically)
#' @return List of MA results
run_parallel_meta_analysis <- function(data, outcomes, method = "REML", n_cores = NULL) {

  if (is.null(n_cores)) {
    n_cores <- max(1, detectCores() - 1)  # Leave 1 core free
  }

  cat(sprintf("🚀 Running parallel meta-analysis on %d cores\n", n_cores))

  # Create cluster
  cl <- makeCluster(n_cores)

  # Export necessary functions and libraries
  clusterEvalQ(cl, {
    library(metafor)
  })

  clusterExport(cl, c("data", "method"), envir = environment())

  # Run analyses in parallel
  results <- parLapply(cl, outcomes, function(outcome) {
    outcome_data <- data[data$outcome == outcome, ]

    if (nrow(outcome_data) < 2) {
      return(NULL)
    }

    tryCatch({
      ma <- rma(yi, vi, data = outcome_data, method = method)

      list(
        outcome = outcome,
        pooled_effect = as.numeric(ma$beta),
        ci_lower = as.numeric(ma$ci.lb),
        ci_upper = as.numeric(ma$ci.ub),
        p_value = as.numeric(ma$pval),
        i_squared = as.numeric(ma$I2),
        tau_squared = as.numeric(ma$tau2),
        n_studies = ma$k
      )
    }, error = function(e) {
      list(outcome = outcome, error = e$message)
    })
  })

  # Stop cluster
  stopCluster(cl)

  # Name results
  names(results) <- outcomes

  return(results)
}


# ============================================================================
# COMPILED R FUNCTIONS (Byte Compilation)
# ============================================================================

#' Calculate effect sizes (compiled for speed)
#' @export
calculate_effect_sizes_fast <- cmpfun(function(data) {
  # Vectorized calculations (no loops!)

  if ("n1" %in% names(data) && "n2" %in% names(data)) {
    # Binary outcomes: Calculate log odds ratio
    data$yi <- with(data, log((events1 / (n1 - events1)) / (events2 / (n2 - events2))))

    # Standard error
    data$sei <- with(data, sqrt(1/events1 + 1/(n1-events1) + 1/events2 + 1/(n2-events2)))

  } else if ("mean1" %in% names(data) && "mean2" %in% names(data)) {
    # Continuous outcomes: Standardized mean difference
    pooled_sd <- with(data, sqrt(((n1-1)*sd1^2 + (n2-1)*sd2^2) / (n1 + n2 - 2)))

    data$yi <- with(data, (mean1 - mean2) / pooled_sd)

    # Standard error (Hedges' g correction)
    correction <- 1 - 3 / (4 * (data$n1 + data$n2 - 2) - 1)
    data$yi <- data$yi * correction

    data$sei <- with(data, sqrt((n1 + n2) / (n1 * n2) + yi^2 / (2 * (n1 + n2))))
  }

  data$vi <- data$sei^2

  return(data)
})


#' Weighted mean (compiled, vectorized)
#' @export
weighted_mean_fast <- cmpfun(function(x, w) {
  sum(x * w) / sum(w)
})


#' I² calculation (compiled)
#' @export
calculate_i_squared_fast <- cmpfun(function(Q, df) {
  max(0, 100 * (Q - df) / Q)
})


# ============================================================================
# PRE-COMPUTED LOOKUP TABLES
# ============================================================================

# Pre-compute critical values for common sample sizes
.critical_values_cache <- new.env(hash = TRUE)

#' Get critical t-value (with caching)
#' @param df Degrees of freedom
#' @param alpha Significance level
#' @return Critical t-value
get_critical_t_value <- function(df, alpha = 0.05) {
  key <- paste(df, alpha, sep = "_")

  if (!exists(key, envir = .critical_values_cache)) {
    value <- qt(1 - alpha/2, df)
    assign(key, value, envir = .critical_values_cache)
  }

  get(key, envir = .critical_values_cache)
}


# Pre-compute common transformations
.transformation_cache <- new.env(hash = TRUE)

#' Fisher's Z transformation (cached)
#' @param r Correlation coefficient
#' @return Fisher's Z
fishers_z_fast <- function(r) {
  key <- paste0("fz_", round(r, 4))

  if (!exists(key, envir = .transformation_cache)) {
    value <- 0.5 * log((1 + r) / (1 - r))
    assign(key, value, envir = .transformation_cache)
  }

  get(key, envir = .transformation_cache)
}


# ============================================================================
# INCREMENTAL COMPUTATION
# ============================================================================

#' Incremental meta-analysis (add studies one at a time)
#' Only recomputes what's needed - much faster for living MA
#' @param previous_ma Previous MA results
#' @param new_studies New studies to add
#' @return Updated MA results
incremental_meta_analysis <- function(previous_ma, new_studies) {

  if (is.null(previous_ma)) {
    # First run, compute from scratch
    all_data <- new_studies
  } else {
    # Combine with previous data
    all_data <- rbind(previous_ma$data, new_studies)
  }

  # Incremental computations
  n <- nrow(all_data)
  n_prev <- if (is.null(previous_ma)) 0 else nrow(previous_ma$data)
  n_new <- n - n_prev

  cat(sprintf("📊 Incremental update: %d previous + %d new = %d total studies\n",
              n_prev, n_new, n))

  # Only recompute full model if significant change
  if (n_prev == 0 || n_new / n > 0.1) {
    # Substantial change, full recomputation
    cat("  → Full recomputation (>10% change)\n")
    ma <- rma(yi, vi, data = all_data, method = "REML")
  } else {
    # Small change, use previous estimates as starting values (faster convergence)
    cat("  → Incremental update (quick)\n")
    start_vals <- if (!is.null(previous_ma$tau_squared)) {
      c(previous_ma$pooled_effect, sqrt(previous_ma$tau_squared))
    } else {
      NULL
    }

    ma <- rma(yi, vi, data = all_data, method = "REML", control = list(tau2.init = start_vals[2]^2))
  }

  # Return results
  list(
    data = all_data,
    pooled_effect = as.numeric(ma$beta),
    ci_lower = as.numeric(ma$ci.lb),
    ci_upper = as.numeric(ma$ci.ub),
    se = as.numeric(ma$se),
    z_value = as.numeric(ma$zval),
    p_value = as.numeric(ma$pval),
    i_squared = as.numeric(ma$I2),
    tau_squared = as.numeric(ma$tau2),
    q_statistic = as.numeric(ma$QE),
    n_studies = ma$k
  )
}


# ============================================================================
# DATA STREAMING FOR LARGE DATASETS
# ============================================================================

#' Stream-process large dataset in chunks
#' @param data_path Path to CSV file
#' @param chunk_size Number of rows per chunk
#' @param process_fn Function to apply to each chunk
#' @return Aggregated results
stream_process_data <- function(data_path, chunk_size = 1000, process_fn) {

  con <- file(data_path, "r")
  on.exit(close(con))

  # Read header
  header <- read.csv(con, nrows = 1, header = TRUE)
  col_names <- names(header)

  results <- list()
  chunk_idx <- 1

  repeat {
    chunk <- tryCatch({
      read.csv(con, nrows = chunk_size, header = FALSE, col.names = col_names)
    }, error = function(e) NULL)

    if (is.null(chunk) || nrow(chunk) == 0) break

    cat(sprintf("Processing chunk %d (%d rows)\n", chunk_idx, nrow(chunk)))

    # Process chunk
    result <- process_fn(chunk)
    results[[chunk_idx]] <- result

    chunk_idx <- chunk_idx + 1
  }

  # Aggregate results
  do.call(rbind, results)
}


# ============================================================================
# VECTORIZED FOREST PLOT DATA PREPARATION
# ============================================================================

#' Prepare forest plot data (fully vectorized, no loops)
#' @param data Meta-analysis data
#' @param ma_result MA results
#' @return Data ready for plotting
prepare_forest_plot_data_fast <- cmpfun(function(data, ma_result) {

  # All vectorized operations (no loops!)
  n <- nrow(data)

  # Calculate CIs
  ci_lower <- data$yi - 1.96 * data$sei
  ci_upper <- data$yi + 1.96 * data$sei

  # Calculate weights
  weights <- 1 / data$vi
  weight_pct <- 100 * weights / sum(weights)

  # Create plot data (single data.frame allocation)
  plot_data <- data.frame(
    study_id = data$study_id,
    yi = data$yi,
    sei = data$sei,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    weight = weights,
    weight_pct = weight_pct,
    study_order = seq_len(n),
    box_size = sqrt(weight_pct) * 3 + 5,  # Vectorized
    stringsAsFactors = FALSE
  )

  # Add study labels if available
  if ("author" %in% names(data) && "year" %in% names(data)) {
    plot_data$study_label <- paste0(data$author, " (", data$year, ")")
  } else {
    plot_data$study_label <- data$study_id
  }

  return(plot_data)
})


# ============================================================================
# FAST SUBGROUP ANALYSIS
# ============================================================================

#' Run subgroup analyses (parallelized)
#' @param data Full dataset
#' @param subgroup_var Subgroup variable name
#' @param method MA method
#' @return List of subgroup results
run_subgroup_analysis_fast <- function(data, subgroup_var, method = "REML") {

  subgroups <- unique(data[[subgroup_var]])
  n_subgroups <- length(subgroups)

  if (n_subgroups < 2) {
    stop("Need at least 2 subgroups")
  }

  cat(sprintf("🔍 Running subgroup analysis: %d subgroups\n", n_subgroups))

  # Parallel if many subgroups
  if (n_subgroups >= 4) {
    cl <- makeCluster(min(n_subgroups, detectCores() - 1))

    clusterEvalQ(cl, library(metafor))
    clusterExport(cl, c("data", "subgroup_var", "method"), envir = environment())

    results <- parLapply(cl, subgroups, function(sg) {
      sg_data <- data[data[[subgroup_var]] == sg, ]

      if (nrow(sg_data) < 2) return(NULL)

      ma <- rma(yi, vi, data = sg_data, method = method)

      list(
        subgroup = sg,
        estimate = as.numeric(ma$beta),
        ci_lower = as.numeric(ma$ci.lb),
        ci_upper = as.numeric(ma$ci.ub),
        k = ma$k,
        i_squared = as.numeric(ma$I2)
      )
    })

    stopCluster(cl)

  } else {
    # Sequential for few subgroups
    results <- lapply(subgroups, function(sg) {
      sg_data <- data[data[[subgroup_var]] == sg, ]

      if (nrow(sg_data) < 2) return(NULL)

      ma <- rma(yi, vi, data = sg_data, method = method)

      list(
        subgroup = sg,
        estimate = as.numeric(ma$beta),
        ci_lower = as.numeric(ma$ci.lb),
        ci_upper = as.numeric(ma$ci.ub),
        k = ma$k,
        i_squared = as.numeric(ma$I2)
      )
    })
  }

  # Filter out NULL results
  results[!sapply(results, is.null)]
}


# ============================================================================
# BOOTSTRAP CONFIDENCE INTERVALS (Parallel)
# ============================================================================

#' Bootstrap confidence intervals (parallelized)
#' @param data Meta-analysis data
#' @param n_boot Number of bootstrap samples
#' @param method MA method
#' @param n_cores Number of cores
#' @return Bootstrap CI
bootstrap_ci_fast <- function(data, n_boot = 1000, method = "REML", n_cores = NULL) {

  if (is.null(n_cores)) {
    n_cores <- max(1, detectCores() - 1)
  }

  cat(sprintf("🔁 Running %d bootstrap samples on %d cores\n", n_boot, n_cores))

  # Create cluster
  cl <- makeCluster(n_cores)

  clusterEvalQ(cl, library(metafor))
  clusterExport(cl, c("data", "method"), envir = environment())

  # Parallel bootstrap
  boot_estimates <- parSapply(cl, 1:n_boot, function(i) {
    # Resample studies with replacement
    indices <- sample(nrow(data), replace = TRUE)
    boot_data <- data[indices, ]

    # Run MA
    ma <- rma(yi, vi, data = boot_data, method = method)
    as.numeric(ma$beta)
  })

  stopCluster(cl)

  # Calculate percentile CI
  ci_lower <- quantile(boot_estimates, 0.025)
  ci_upper <- quantile(boot_estimates, 0.975)

  list(
    estimate = mean(boot_estimates),
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    boot_estimates = boot_estimates
  )
}


# ============================================================================
# CACHE CLEARANCE UTILITIES
# ============================================================================

#' Clear all optimization caches
clear_optimization_caches <- function() {
  rm(list = ls(envir = .critical_values_cache), envir = .critical_values_cache)
  rm(list = ls(envir = .transformation_cache), envir = .transformation_cache)
  cat("✓ Optimization caches cleared\n")
}


#' Get cache statistics
get_cache_stats <- function() {
  list(
    critical_values = length(ls(envir = .critical_values_cache)),
    transformations = length(ls(envir = .transformation_cache))
  )
}


# ============================================================================
# PERFORMANCE MONITORING
# ============================================================================

#' Benchmark function execution
#' @param expr Expression to benchmark
#' @param n Number of iterations
benchmark_fast <- function(expr, n = 100) {
  times <- numeric(n)

  for (i in 1:n) {
    times[i] <- system.time(expr)[3]
  }

  list(
    mean = mean(times),
    median = median(times),
    min = min(times),
    max = max(times),
    sd = sd(times)
  )
}


cat("✅ Extreme optimizations loaded!\n")
cat("   • Parallel processing (multi-core)\n")
cat("   • Compiled R code (byte compilation)\n")
cat("   • Vectorized operations\n")
cat("   • Pre-computed lookup tables\n")
cat("   • Incremental computation\n")
cat("   • Data streaming\n")
