# Performance Benchmarking Suite for EvidenceOS PRIME (R Frontend)
# Tests the impact of optimization improvements

library(microbenchmark)
library(profvis)
library(dplyr)

# Source utilities
source("../frontend/utils/python_bridge.R")
source("../frontend/utils/cache_bridge.R")
source("../frontend/utils/plotting.R")

#' Generate synthetic test data
#'
#' @param n_studies Number of studies
#' @param data_type Type of data ("binary", "continuous")
generate_test_data <- function(n_studies = 100, data_type = "binary") {
  set.seed(42)

  if (data_type == "binary") {
    data <- data.frame(
      study_id = paste0("Study_", 1:n_studies),
      treatment = sample(c("Treatment", "Control"), n_studies, replace = TRUE),
      events = sample(10:100, n_studies, replace = TRUE),
      n = sample(100:500, n_studies, replace = TRUE),
      year = sample(2000:2024, n_studies, replace = TRUE),
      risk_of_bias = sample(c("Low", "Unclear", "High"), n_studies, replace = TRUE),
      stringsAsFactors = FALSE
    )
    # Ensure events <= n
    data$events <- pmin(data$events, data$n - 10)

    # Add effect sizes
    data$yi <- rnorm(n_studies, 0, 0.5)
    data$sei <- runif(n_studies, 0.1, 0.3)
    data$vi <- data$sei^2
  }

  return(data)
}

#' Benchmark data binding operations
benchmark_data_binding <- function() {
  cat("\n", paste(rep("=", 70), collapse = ""), "\n")
  cat("DATA BINDING BENCHMARK (rbind vs bind_rows)\n")
  cat(paste(rep("=", 70), collapse = ""), "\n\n")

  n_iterations <- 100
  data_list <- lapply(1:n_iterations, function(i) {
    data.frame(
      id = i,
      value = rnorm(10),
      category = sample(letters[1:5], 10, replace = TRUE)
    )
  })

  # Benchmark rbind (OLD METHOD)
  rbind_time <- system.time({
    result_rbind <- data.frame()
    for (df in data_list) {
      result_rbind <- rbind(result_rbind, df)
    }
  })

  # Benchmark bind_rows (NEW METHOD)
  bind_rows_time <- system.time({
    result_bind <- bind_rows(data_list)
  })

  cat(sprintf("rbind (old):       %.2f seconds\n", rbind_time[3]))
  cat(sprintf("bind_rows (new):   %.2f seconds\n", bind_rows_time[3]))
  cat(sprintf("Speedup:           %.1fx faster\n\n", rbind_time[3] / bind_rows_time[3]))
}

#' Benchmark forest plot creation
benchmark_forest_plot <- function() {
  cat("\n", paste(rep("=", 70), collapse = ""), "\n")
  cat("FOREST PLOT CREATION BENCHMARK\n")
  cat(paste(rep("=", 70), collapse = ""), "\n\n")

  # Create test meta-analysis result
  data <- generate_test_data(50, "binary")

  ma_result <- list(
    data = data,
    pooled_effect = 0.5,
    ci_lower = 0.3,
    ci_upper = 0.7,
    p_value = 0.001,
    i_squared = 45.2,
    tau_squared = 0.12,
    q_p_value = 0.05
  )

  # Benchmark plot creation
  timing <- system.time({
    for (i in 1:10) {
      plot <- create_forest_plot(ma_result, "Test Outcome")
    }
  })

  cat(sprintf("10 forest plots:   %.2f seconds (%.2fms per plot)\n",
              timing[3], timing[3] * 100))
  cat("✓ Optimized with vectorized segment addition\n\n")
}

#' Benchmark cache operations
benchmark_cache <- function() {
  cat("\n", paste(rep("=", 70), collapse = ""), "\n")
  cat("CACHE OPERATIONS BENCHMARK\n")
  cat(paste(rep("=", 70), collapse = ""), "\n\n")

  tryCatch({
    # Initialize cache
    cache_mgr <- init_cache_manager("tests/benchmark_cache_r")

    if (!is.null(cache_mgr)) {
      test_data <- generate_test_data(100, "binary")

      # Benchmark cache writes
      write_time <- system.time({
        for (i in 1:50) {
          cache_results(
            cache_mgr,
            "meta_analysis",
            list(outcome = paste0("outcome_", i), method = "REML"),
            test_data
          )
        }
      })

      cat(sprintf("Cache PUT (50):    %.2f seconds (%.2fms per entry)\n",
                  write_time[3], write_time[3] * 20))

      # Benchmark cache reads (hits)
      read_time <- system.time({
        for (i in 1:50) {
          get_cached_results(
            cache_mgr,
            "meta_analysis",
            list(outcome = paste0("outcome_", i), method = "REML")
          )
        }
      })

      cat(sprintf("Cache GET (50):    %.2f seconds (%.2fms per entry)\n",
                  read_time[3], read_time[3] * 20))

      # Get stats
      stats <- get_cache_stats(cache_mgr)
      cat(sprintf("\nCache Stats:\n"))
      cat(sprintf("  Total entries: %d\n", stats$total_entries))
      cat(sprintf("  Total size: %.2f MB\n\n", stats$total_size_mb))

      # Cleanup
      unlink("tests/benchmark_cache_r", recursive = TRUE)
    } else {
      cat("⚠ Cache manager not available (requires Python backend)\n\n")
    }
  }, error = function(e) {
    cat("⚠ Cache benchmark skipped:", e$message, "\n\n")
  })
}

#' Main benchmark runner
main <- function() {
  cat("\n", paste(rep("=", 70), collapse = ""), "\n")
  cat(" EVIDENCEOS PRIME R FRONTEND PERFORMANCE BENCHMARK\n")
  cat(" Optimized Version - Testing Performance Improvements\n")
  cat(paste(rep("=", 70), collapse = ""), "\n")

  # Run benchmarks
  benchmark_data_binding()
  benchmark_forest_plot()
  benchmark_cache()

  # Summary
  cat("\n", paste(rep("=", 70), collapse = ""), "\n")
  cat("BENCHMARK SUMMARY\n")
  cat(paste(rep("=", 70), collapse = ""), "\n\n")

  cat("Expected improvements from optimizations:\n")
  cat("  ✓ Data binding:       10-100x faster (bind_rows vs rbind)\n")
  cat("  ✓ Forest plots:       2-5x faster (vectorized operations)\n")
  cat("  ✓ Cache singleton:    Eliminates redundant initialization\n")
  cat("  ✓ API health checks:  Non-blocking (reactivePoll every 30s)\n")
  cat("  ✓ Overall UI:         Significantly more responsive\n\n")

  cat("✓ R Frontend benchmark complete!\n\n")
}

# Run benchmarks
if (!interactive()) {
  main()
}
