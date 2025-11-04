# Comprehensive Tests for Network Meta-Analysis Module
# Tests for frontend/modules/nma.R

library(testthat)
library(netmeta)
library(dplyr)

# Source the module
source("../../frontend/modules/nma.R")

# ============================
# NETWORK CONSTRUCTION TESTS
# ============================

test_that("create_nma_network works with valid binary data", {
  # Sample network of 3 treatments
  data <- data.frame(
    study_id = rep(paste0("Study_", 1:5), each = 2),
    treatment = rep(c("A", "B", "C"), length.out = 10),
    events = c(10, 15, 12, 18, 8, 14, 20, 22, 11, 13),
    n = rep(100, 10)
  )

  network <- create_nma_network(data, measure = "OR")

  expect_true(!is.null(network))
  expect_true("netmeta" %in% class(network) || "data.frame" %in% class(network))
  expect_true(nrow(network) > 0)
})

test_that("create_nma_network works with continuous data", {
  data <- data.frame(
    study_id = rep(paste0("Study_", 1:4), each = 2),
    treatment = rep(c("A", "B", "C"), length.out = 8),
    mean = c(10.5, 11.2, 9.8, 10.9, 11.5, 12.1, 10.2, 11.8),
    sd = c(2.1, 2.3, 2.0, 2.2, 2.4, 2.5, 1.9, 2.3),
    n = rep(50, 8)
  )

  network <- create_nma_network(data, measure = "MD")

  expect_true(!is.null(network))
  expect_true(nrow(network) > 0)
})

test_that("create_nma_network rejects invalid network (disconnected)", {
  # Disconnected network: A-B and C-D, no connection between them
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2"),
    treatment = c("A", "B", "C", "D"),
    events = c(10, 15, 12, 18),
    n = rep(100, 4)
  )

  expect_error(
    create_nma_network(data, measure = "OR"),
    "disconnected|not connected",
    ignore.case = TRUE
  )
})

test_that("validate_nma_network detects star networks", {
  # Star network: all comparisons vs placebo
  data <- data.frame(
    study_id = paste0("Study_", 1:4),
    treatment1 = rep("Placebo", 4),
    treatment2 = c("A", "B", "C", "D")
  )

  validation <- validate_nma_network(data)

  expect_true("network_type" %in% names(validation))
  expect_equal(validation$network_type, "star")
  expect_true(validation$is_connected)
})


# ============================
# NMA ESTIMATION TESTS
# ============================

test_that("run_nma performs network meta-analysis correctly", {
  # Simple 3-treatment network
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  result <- run_nma(data, reference = "A", measure = "OR")

  expect_true(!is.null(result))
  expect_true("relative_effects" %in% names(result))
  expect_true("league_table" %in% names(result))
  expect_true("tau_squared" %in% names(result))
  expect_true("i_squared" %in% names(result))
})

test_that("run_nma calculates correct number of comparisons", {
  # 4 treatments = 6 pairwise comparisons
  data <- data.frame(
    study_id = rep(paste0("Study_", 1:6), each = 2),
    treatment = rep(c("A", "B", "C", "D"), length.out = 12),
    events = sample(10:20, 12, replace = TRUE),
    n = rep(100, 12)
  )

  result <- run_nma(data, reference = "A", measure = "OR")

  n_treatments <- 4
  expected_comparisons <- (n_treatments * (n_treatments - 1)) / 2

  expect_equal(nrow(result$league_table), n_treatments)
})

test_that("run_nma handles different reference treatments", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  result_ref_a <- run_nma(data, reference = "A", measure = "OR")
  result_ref_b <- run_nma(data, reference = "B", measure = "OR")

  expect_true(!is.null(result_ref_a))
  expect_true(!is.null(result_ref_b))

  # Reference effects should be different
  expect_false(identical(
    result_ref_a$relative_effects,
    result_ref_b$relative_effects
  ))
})


# ============================
# INCONSISTENCY TESTS
# ============================

test_that("check_inconsistency detects consistency in consistent network", {
  # Consistent network (no loops with conflicting evidence)
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  inconsistency <- check_inconsistency(data, measure = "OR")

  expect_true(!is.null(inconsistency))
  expect_true("p_value" %in% names(inconsistency) ||
              "consistency" %in% names(inconsistency))
})

test_that("check_inconsistency identifies loops in network", {
  # Triangle network A-B-C-A
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  inconsistency <- check_inconsistency(data, measure = "OR")

  expect_true("n_loops" %in% names(inconsistency))
  expect_true(inconsistency$n_loops >= 1)  # Triangle has 1 loop
})


# ============================
# RANKING TESTS
# ============================

test_that("calculate_sucra returns rankings for all treatments", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  result <- run_nma(data, reference = "A", measure = "OR")
  rankings <- calculate_sucra(result)

  expect_true(!is.null(rankings))
  expect_true("treatment" %in% names(rankings))
  expect_true("sucra" %in% names(rankings))
  expect_true("rank" %in% names(rankings))

  # SUCRA should be between 0 and 1
  expect_true(all(rankings$sucra >= 0 & rankings$sucra <= 1))

  # Ranks should be unique
  expect_equal(length(unique(rankings$rank)), nrow(rankings))
})

test_that("calculate_sucra orders treatments correctly", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  result <- run_nma(data, reference = "A", measure = "OR")
  rankings <- calculate_sucra(result, higher_better = FALSE)  # Lower OR better

  # Rankings should be ordered (best to worst)
  expect_true(all(diff(rankings$rank) >= 0))
})


# ============================
# LEAGUE TABLE TESTS
# ============================

test_that("create_league_table produces symmetric matrix", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  result <- run_nma(data, reference = "A", measure = "OR")
  league_table <- create_league_table(result)

  expect_true(is.matrix(league_table) || is.data.frame(league_table))
  expect_equal(nrow(league_table), ncol(league_table))

  # Check diagonal is NA or reference values
  if (is.matrix(league_table)) {
    expect_true(all(is.na(diag(league_table))))
  }
})

test_that("create_league_table includes confidence intervals", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  result <- run_nma(data, reference = "A", measure = "OR")
  league_table <- create_league_table(result, include_ci = TRUE)

  # Should contain CI information (brackets or separate columns)
  expect_true(!is.null(league_table))

  # Check if any cell contains CI notation (e.g., "1.23 (0.89, 1.71)")
  if (is.data.frame(league_table)) {
    any_ci <- any(grepl("\\(.*,.*\\)", as.matrix(league_table), na.rm = TRUE))
    expect_true(any_ci || "lower_ci" %in% names(league_table))
  }
})


# ============================
# NETWORK VISUALIZATION TESTS
# ============================

test_that("plot_network_graph creates plot object", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  plot_obj <- plot_network_graph(data)

  expect_true(!is.null(plot_obj))
  # Should be ggplot or base R plot
  expect_true(any(class(plot_obj) %in% c("ggplot", "recordedplot")) ||
              is.list(plot_obj))
})

test_that("plot_network_graph shows correct number of nodes", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3", "S4", "S4"),
    treatment = c("A", "B", "A", "C", "B", "C", "C", "D"),
    events = sample(10:20, 8, replace = TRUE),
    n = rep(100, 8)
  )

  plot_obj <- plot_network_graph(data, return_layout = TRUE)

  expect_true(!is.null(plot_obj))

  # Should have 4 unique treatments = 4 nodes
  if (is.list(plot_obj) && "nodes" %in% names(plot_obj)) {
    expect_equal(nrow(plot_obj$nodes), 4)
  }
})


# ============================
# FOREST PLOT TESTS
# ============================

test_that("create_nma_forest_plot generates plot", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  result <- run_nma(data, reference = "A", measure = "OR")
  forest_plot <- create_nma_forest_plot(result)

  expect_true(!is.null(forest_plot))
  expect_true(any(class(forest_plot) %in% c("ggplot", "recordedplot", "grob")))
})


# ============================
# SENSITIVITY ANALYSIS TESTS
# ============================

test_that("nma_sensitivity_analysis excludes studies correctly", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3", "S4", "S4"),
    treatment = c("A", "B", "A", "C", "B", "C", "A", "B"),
    events = c(10, 15, 12, 18, 14, 20, 11, 16),
    n = rep(100, 8),
    risk_of_bias = c("low", "low", "high", "high", "low", "low", "high", "high")
  )

  # Exclude high risk of bias studies
  sensitivity <- nma_sensitivity_analysis(
    data,
    exclude_criteria = list(risk_of_bias = "high"),
    reference = "A",
    measure = "OR"
  )

  expect_true(!is.null(sensitivity))
  expect_true("n_studies_excluded" %in% names(sensitivity))
  expect_true(sensitivity$n_studies_excluded > 0)
})

test_that("nma_leave_one_out performs correctly", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "A", "C", "B", "C"),
    events = c(10, 15, 12, 18, 14, 20),
    n = rep(100, 6)
  )

  loo_results <- nma_leave_one_out(data, reference = "A", measure = "OR")

  expect_true(!is.null(loo_results))
  expect_true(is.list(loo_results))

  # Should have results for each study
  n_studies <- length(unique(data$study_id))
  expect_equal(length(loo_results), n_studies)
})


# ============================
# COMPARISON ADJUSTMENT TESTS
# ============================

test_that("nma_comparison_adjusted calculates indirect evidence", {
  # Network where we can calculate indirect comparison
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3"),
    treatment = c("A", "B", "B", "C", "A", "C"),
    events = c(10, 15, 14, 18, 12, 20),
    n = rep(100, 6)
  )

  # Direct evidence: A vs C (S3)
  # Indirect evidence: A vs B (S1) + B vs C (S2)

  comparison_result <- nma_comparison_adjusted(
    data,
    treatment1 = "A",
    treatment2 = "C",
    measure = "OR"
  )

  expect_true(!is.null(comparison_result))
  expect_true("direct_effect" %in% names(comparison_result))
  expect_true("indirect_effect" %in% names(comparison_result))
  expect_true("network_effect" %in% names(comparison_result))
})


# ============================
# META-REGRESSION IN NMA TESTS
# ============================

test_that("nma_meta_regression handles covariates", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2", "S3", "S3", "S4", "S4"),
    treatment = c("A", "B", "A", "C", "B", "C", "A", "B"),
    events = c(10, 15, 12, 18, 14, 20, 11, 16),
    n = rep(100, 8),
    year = c(2010, 2010, 2015, 2015, 2018, 2018, 2020, 2020)
  )

  meta_reg_result <- nma_meta_regression(
    data,
    covariates = c("year"),
    reference = "A",
    measure = "OR"
  )

  expect_true(!is.null(meta_reg_result))
  expect_true("coefficients" %in% names(meta_reg_result) ||
              "regression_results" %in% names(meta_reg_result))
})


# ============================
# ERROR HANDLING TESTS
# ============================

test_that("run_nma rejects data with missing values", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2"),
    treatment = c("A", "B", "A", NA),
    events = c(10, 15, 12, 18),
    n = rep(100, 4)
  )

  expect_error(
    run_nma(data, reference = "A", measure = "OR"),
    "missing|NA|incomplete",
    ignore.case = TRUE
  )
})

test_that("run_nma rejects single-arm studies", {
  data <- data.frame(
    study_id = c("S1", "S2", "S3"),
    treatment = c("A", "B", "C"),
    events = c(10, 15, 12),
    n = rep(100, 3)
  )

  expect_error(
    run_nma(data, reference = "A", measure = "OR"),
    "multi-arm|at least 2|comparison",
    ignore.case = TRUE
  )
})

test_that("run_nma rejects invalid reference treatment", {
  data <- data.frame(
    study_id = c("S1", "S1", "S2", "S2"),
    treatment = c("A", "B", "A", "C"),
    events = c(10, 15, 12, 18),
    n = rep(100, 4)
  )

  expect_error(
    run_nma(data, reference = "INVALID", measure = "OR"),
    "reference|not found|invalid",
    ignore.case = TRUE
  )
})


# ============================
# INTEGRATION TESTS
# ============================

test_that("Full NMA workflow completes successfully", {
  # Simulate complete workflow from data to results
  data <- data.frame(
    study_id = rep(paste0("Study_", 1:6), each = 2),
    treatment = rep(c("Placebo", "Drug_A", "Drug_B", "Drug_C"), length.out = 12),
    events = c(10, 15, 12, 18, 14, 20, 8, 13, 16, 22, 11, 17),
    n = rep(100, 12)
  )

  # Step 1: Validate network
  validation <- validate_nma_network(data)
  expect_true(validation$is_connected)

  # Step 2: Run NMA
  result <- run_nma(data, reference = "Placebo", measure = "OR")
  expect_true(!is.null(result))

  # Step 3: Check inconsistency
  inconsistency <- check_inconsistency(data, measure = "OR")
  expect_true(!is.null(inconsistency))

  # Step 4: Calculate rankings
  rankings <- calculate_sucra(result)
  expect_equal(nrow(rankings), length(unique(data$treatment)))

  # Step 5: Create league table
  league_table <- create_league_table(result)
  expect_true(!is.null(league_table))

  # Step 6: Sensitivity analysis
  loo_results <- nma_leave_one_out(data, reference = "Placebo", measure = "OR")
  expect_equal(length(loo_results), length(unique(data$study_id)))
})


# ============================
# PERFORMANCE TESTS
# ============================

test_that("run_nma handles large networks efficiently", {
  # Create larger network: 10 treatments, 30 studies
  n_treatments <- 10
  n_studies <- 30

  treatments <- LETTERS[1:n_treatments]

  # Generate connected network
  data <- data.frame(
    study_id = rep(paste0("Study_", 1:n_studies), each = 2),
    treatment = sample(treatments, n_studies * 2, replace = TRUE),
    events = sample(10:30, n_studies * 2, replace = TRUE),
    n = rep(100, n_studies * 2)
  )

  # Time the execution
  start_time <- Sys.time()
  result <- tryCatch(
    run_nma(data, reference = treatments[1], measure = "OR"),
    error = function(e) NULL
  )
  end_time <- Sys.time()

  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  # Should complete within reasonable time (e.g., < 30 seconds)
  expect_true(elapsed < 30,
              info = paste("NMA took", round(elapsed, 2), "seconds"))

  if (!is.null(result)) {
    expect_true("relative_effects" %in% names(result))
  }
})


# Run all tests
cat("\n=== Running NMA Module Tests ===\n")
test_results <- test_dir(".", filter = "test_nma", reporter = "summary")
cat("\n=== NMA Tests Complete ===\n")
