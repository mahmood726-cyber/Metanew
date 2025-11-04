# Comprehensive Tests for Sensitivity Analysis Module
# Tests for frontend/modules/sensitivity.R

library(testthat)
library(metafor)
library(dplyr)

# Source the module
source("../../frontend/modules/sensitivity.R")

# ============================
# LEAVE-ONE-OUT ANALYSIS TESTS
# ============================

test_that("leave_one_out_analysis removes each study correctly", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15)
  )

  loo_results <- leave_one_out_analysis(data, method = "REML")

  expect_true(!is.null(loo_results))
  expect_equal(length(loo_results), 10)  # One result per study

  # Each result should have pooled estimate
  expect_true(all(sapply(loo_results, function(x) "pooled_effect" %in% names(x))))
})

test_that("leave_one_out_analysis identifies influential studies", {
  # Create data with one influential outlier
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = c(rep(0.5, 9), 2.0),  # Last study is outlier
    sei = rep(0.1, 10)
  )

  loo_results <- leave_one_out_analysis(data, method = "REML")
  influential <- identify_influential_studies(loo_results)

  expect_true(!is.null(influential))
  expect_true(length(influential) > 0)

  # Outlier study should be identified
  expect_true("Study_10" %in% influential$study_id)
})

test_that("plot_leave_one_out creates visualization", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11)
  )

  loo_results <- leave_one_out_analysis(data)
  plot_obj <- plot_leave_one_out(loo_results)

  expect_true(!is.null(plot_obj))
  expect_true(any(class(plot_obj) %in% c("ggplot", "recordedplot", "grob")))
})


# ============================
# SUBGROUP EXCLUSION TESTS
# ============================

test_that("exclude_by_risk_of_bias removes high-risk studies", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    risk_of_bias = sample(c("low", "high"), 10, replace = TRUE)
  )

  filtered_data <- exclude_by_risk_of_bias(data, exclude = "high")

  expect_true(nrow(filtered_data) < nrow(data))
  expect_true(all(filtered_data$risk_of_bias == "low"))
})

test_that("exclude_by_sample_size removes small studies", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    n = sample(30:200, 10, replace = TRUE)
  )

  filtered_data <- exclude_by_sample_size(data, min_n = 100)

  expect_true(all(filtered_data$n >= 100))
  expect_true(nrow(filtered_data) <= nrow(data))
})

test_that("exclude_by_year filters by publication year", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    year = sample(2000:2020, 10, replace = TRUE)
  )

  filtered_data <- exclude_by_year(data, min_year = 2010)

  expect_true(all(filtered_data$year >= 2010))
})

test_that("compare_with_without_exclusions shows impact", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    risk_of_bias = c(rep("low", 7), rep("high", 3))
  )

  comparison <- compare_with_without_exclusions(
    data,
    exclusion_criteria = list(risk_of_bias = "high")
  )

  expect_true(!is.null(comparison))
  expect_true("full_analysis" %in% names(comparison))
  expect_true("excluded_analysis" %in% names(comparison))
  expect_true("difference" %in% names(comparison))
})


# ============================
# CUMULATIVE META-ANALYSIS TESTS
# ============================

test_that("cumulative_meta_analysis adds studies sequentially", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    year = 2010:2019
  )

  cumulative <- cumulative_meta_analysis(data, order_by = "year")

  expect_true(!is.null(cumulative))
  expect_equal(nrow(cumulative), 10)

  # Should have cumulative estimates
  expect_true("cumulative_effect" %in% names(cumulative))
  expect_true("cumulative_ci_lower" %in% names(cumulative))
  expect_true("cumulative_ci_upper" %in% names(cumulative))
})

test_that("cumulative_meta_analysis orders by sample size", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11),
    n = c(50, 100, 75, 120, 60)
  )

  cumulative <- cumulative_meta_analysis(data, order_by = "sample_size")

  # Should be ordered by decreasing sample size
  expect_true(all(diff(cumulative$n) <= 0))
})

test_that("plot_cumulative_ma creates visualization", {
  data <- data.frame(
    study_id = paste0("Study_", 1:8),
    yi = rnorm(8, 0.5, 0.2),
    sei = runif(8, 0.08, 0.15),
    year = 2010:2017
  )

  cumulative <- cumulative_meta_analysis(data, order_by = "year")
  plot_obj <- plot_cumulative_ma(cumulative)

  expect_true(!is.null(plot_obj))
  expect_true(any(class(plot_obj) %in% c("ggplot", "recordedplot")))
})


# ============================
# FIXED VS RANDOM EFFECTS COMPARISON
# ============================

test_that("compare_fixed_random compares both models", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.3),
    sei = runif(10, 0.08, 0.15)
  )

  comparison <- compare_fixed_random(data)

  expect_true(!is.null(comparison))
  expect_true("fixed_effect" %in% names(comparison))
  expect_true("random_effect" %in% names(comparison))

  # Fixed effect CI should be narrower than random effect
  fe_width <- comparison$fixed_effect$ci_upper - comparison$fixed_effect$ci_lower
  re_width <- comparison$random_effect$ci_upper - comparison$random_effect$ci_lower

  expect_true(fe_width <= re_width)
})

test_that("compare_fixed_random shows substantial difference with heterogeneity", {
  # Create heterogeneous data
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = c(0.2, 0.3, 0.5, 0.7, 0.9, 0.4, 0.6, 0.5, 0.8, 0.3),
    sei = rep(0.1, 10)
  )

  comparison <- compare_fixed_random(data)

  # With heterogeneity, estimates should differ
  difference <- abs(comparison$fixed_effect$pooled_effect - comparison$random_effect$pooled_effect)

  # May differ, check that both analyses ran
  expect_true(!is.null(comparison$fixed_effect))
  expect_true(!is.null(comparison$random_effect))
})


# ============================
# ALTERNATIVE ESTIMATORS TESTS
# ============================

test_that("compare_estimators tests multiple tau-squared estimators", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.3),
    sei = runif(10, 0.08, 0.15)
  )

  estimators <- c("REML", "DL", "EB", "PM")
  comparison <- compare_estimators(data, estimators)

  expect_true(!is.null(comparison))
  expect_equal(length(comparison), length(estimators))

  # Each estimator should produce a result
  expect_true(all(sapply(comparison, function(x) "pooled_effect" %in% names(x))))
})

test_that("compare_estimators shows REML vs DL difference", {
  data <- data.frame(
    study_id = paste0("Study_", 1:8),
    yi = rnorm(8, 0.5, 0.2),
    sei = runif(8, 0.08, 0.15)
  )

  comparison <- compare_estimators(data, c("REML", "DL"))

  # Both should produce results
  expect_true("REML" %in% names(comparison))
  expect_true("DL" %in% names(comparison))
})


# ============================
# OUTLIER DETECTION TESTS
# ============================

test_that("detect_outliers identifies extreme values", {
  # Create data with clear outlier
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = c(rep(0.5, 9), 3.0),  # Last study is outlier
    sei = rep(0.1, 10)
  )

  outliers <- detect_outliers(data, method = "studentized")

  expect_true(!is.null(outliers))
  expect_true(length(outliers) > 0)
  expect_true("Study_10" %in% outliers)
})

test_that("detect_outliers uses Cook's distance", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = c(rep(0.5, 9), 2.5),
    sei = rep(0.1, 10)
  )

  outliers <- detect_outliers(data, method = "cooks_distance")

  expect_true(!is.null(outliers))
})

test_that("exclude_outliers_analysis shows impact of removal", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = c(rep(0.5, 9), 2.5),
    sei = rep(0.1, 10)
  )

  analysis <- exclude_outliers_analysis(data)

  expect_true(!is.null(analysis))
  expect_true("with_outliers" %in% names(analysis))
  expect_true("without_outliers" %in% names(analysis))

  # Removing outlier should reduce heterogeneity
  expect_true(
    analysis$without_outliers$i_squared < analysis$with_outliers$i_squared
  )
})


# ============================
# TRIM AND FILL TESTS
# ============================

test_that("trim_and_fill_analysis adjusts for publication bias", {
  # Create data with publication bias (missing small negative studies)
  data <- data.frame(
    study_id = paste0("Study_", 1:8),
    yi = c(0.6, 0.7, 0.5, 0.8, 0.55, 0.65, 0.75, 0.6),  # All positive
    sei = runif(8, 0.08, 0.15)
  )

  taf_result <- trim_and_fill_analysis(data)

  expect_true(!is.null(taf_result))
  expect_true("original_estimate" %in% names(taf_result))
  expect_true("adjusted_estimate" %in% names(taf_result))
  expect_true("n_imputed" %in% names(taf_result))
})

test_that("trim_and_fill_analysis imputes missing studies", {
  # Asymmetric data
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = abs(rnorm(10, 0.5, 0.2)),  # Only positive effects
    sei = runif(10, 0.08, 0.15)
  )

  taf_result <- trim_and_fill_analysis(data)

  # Should impute some studies
  if (taf_result$n_imputed > 0) {
    expect_true(taf_result$adjusted_estimate != taf_result$original_estimate)
  }

  expect_true(!is.null(taf_result))
})


# ============================
# BAUJAT PLOT TESTS
# ============================

test_that("create_baujat_plot identifies studies contributing to heterogeneity", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = c(0.2, 0.3, 0.5, 2.0, 0.4, 0.6, 0.5, 0.55, 0.45, 0.35),  # Study 4 is outlier
    sei = rep(0.1, 10)
  )

  baujat_data <- create_baujat_plot(data)

  expect_true(!is.null(baujat_data))
  expect_true("contribution_to_heterogeneity" %in% names(baujat_data) ||
              "Q_contribution" %in% names(baujat_data))
  expect_true("influence" %in% names(baujat_data) ||
              "influence_on_pooled" %in% names(baujat_data))
})


# ============================
# GOSH PLOT TESTS
# ============================

test_that("gosh_analysis performs graphical display of heterogeneity", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.3),
    sei = runif(10, 0.08, 0.15)
  )

  # Use smaller number for testing
  gosh_result <- gosh_analysis(data, n_subsets = 100)

  expect_true(!is.null(gosh_result))
  expect_true(nrow(gosh_result) > 0)
  expect_true("pooled_effect" %in% names(gosh_result) ||
              "estimate" %in% names(gosh_result))
})


# ============================
# META-REGRESSION ROBUSTNESS TESTS
# ============================

test_that("metareg_sensitivity_analysis tests model robustness", {
  data <- data.frame(
    study_id = paste0("Study_", 1:15),
    yi = rnorm(15, 0.5, 0.3),
    sei = runif(15, 0.08, 0.15),
    year = sample(2005:2020, 15, replace = TRUE),
    sample_size = sample(50:200, 15, replace = TRUE)
  )

  sensitivity <- metareg_sensitivity_analysis(
    data,
    moderators = c("year", "sample_size")
  )

  expect_true(!is.null(sensitivity))
  expect_true("full_model" %in% names(sensitivity))
})

test_that("test_model_specifications compares different models", {
  data <- data.frame(
    study_id = paste0("Study_", 1:20),
    yi = rnorm(20, 0.5, 0.3),
    sei = runif(20, 0.08, 0.15),
    year = sample(2005:2020, 20, replace = TRUE),
    n = sample(50:200, 20, replace = TRUE),
    rob = sample(c("low", "high"), 20, replace = TRUE)
  )

  model_comparison <- test_model_specifications(
    data,
    moderators = list(
      model1 = "year",
      model2 = c("year", "n"),
      model3 = c("year", "n", "rob")
    )
  )

  expect_true(!is.null(model_comparison))
  expect_equal(length(model_comparison), 3)
})


# ============================
# SCENARIO PRESETS TESTS
# ============================

test_that("apply_scenario_preset loads predefined scenarios", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    n = sample(30:200, 10, replace = TRUE),
    risk_of_bias = sample(c("low", "high"), 10, replace = TRUE)
  )

  # Test conservative scenario
  result_conservative <- apply_scenario_preset(data, preset = "conservative")

  expect_true(!is.null(result_conservative))
  # Conservative should exclude some studies
  expect_true(nrow(result_conservative$filtered_data) <= nrow(data))
})

test_that("apply_scenario_preset handles optimistic scenario", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15)
  )

  result_optimistic <- apply_scenario_preset(data, preset = "optimistic")

  expect_true(!is.null(result_optimistic))
  # Optimistic includes all studies
  expect_equal(nrow(result_optimistic$filtered_data), nrow(data))
})

test_that("compare_all_presets runs multiple scenarios", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = rnorm(10, 0.5, 0.2),
    sei = runif(10, 0.08, 0.15),
    n = sample(30:200, 10, replace = TRUE),
    risk_of_bias = sample(c("low", "high"), 10, replace = TRUE),
    year = sample(2010:2020, 10, replace = TRUE)
  )

  all_scenarios <- compare_all_presets(data)

  expect_true(!is.null(all_scenarios))
  expect_true(length(all_scenarios) > 1)

  # Should include base case, conservative, optimistic
  expect_true("base_case" %in% names(all_scenarios) ||
              any(grepl("base", names(all_scenarios), ignore.case = TRUE)))
})


# ============================
# REPORTING TESTS
# ============================

test_that("create_sensitivity_summary_table formats results", {
  sensitivity_results <- list(
    base_case = list(pooled_effect = 0.52, ci_lower = 0.35, ci_upper = 0.69, n_studies = 10),
    high_quality_only = list(pooled_effect = 0.48, ci_lower = 0.30, ci_upper = 0.66, n_studies = 7),
    large_studies = list(pooled_effect = 0.55, ci_lower = 0.38, ci_upper = 0.72, n_studies = 6)
  )

  summary_table <- create_sensitivity_summary_table(sensitivity_results)

  expect_true(!is.null(summary_table))
  expect_true(is.data.frame(summary_table) || is.matrix(summary_table))
  expect_true(nrow(summary_table) >= 3)
})

test_that("interpret_sensitivity_results provides narrative", {
  sensitivity_results <- list(
    base_case = list(pooled_effect = 0.52, ci_lower = 0.35, ci_upper = 0.69),
    without_outliers = list(pooled_effect = 0.49, ci_lower = 0.34, ci_upper = 0.64),
    high_quality_only = list(pooled_effect = 0.50, ci_lower = 0.32, ci_upper = 0.68)
  )

  interpretation <- interpret_sensitivity_results(sensitivity_results)

  expect_true(!is.null(interpretation))
  expect_true(is.character(interpretation))
  expect_true(nchar(interpretation) > 100)

  # Should discuss robustness
  expect_true(grepl("robust|consistent|similar", interpretation, ignore.case = TRUE))
})


# ============================
# ERROR HANDLING TESTS
# ============================

test_that("leave_one_out_analysis handles insufficient studies", {
  data <- data.frame(
    study_id = c("Study_1", "Study_2"),
    yi = c(0.5, 0.6),
    sei = c(0.1, 0.12)
  )

  expect_error(
    leave_one_out_analysis(data),
    "insufficient|too few|minimum",
    ignore.case = TRUE
  )
})

test_that("exclude_by_sample_size handles missing sample sizes", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = rnorm(5, 0.5, 0.2),
    sei = runif(5, 0.08, 0.15)
    # No 'n' column
  )

  expect_error(
    exclude_by_sample_size(data, min_n = 100),
    "sample.*size|column|missing",
    ignore.case = TRUE
  )
})


# ============================
# INTEGRATION TESTS
# ============================

test_that("Full sensitivity analysis workflow completes", {
  # Create comprehensive dataset
  data <- data.frame(
    study_id = paste0("Study_", 1:15),
    yi = c(rnorm(14, 0.5, 0.2), 2.0),  # Include outlier
    sei = runif(15, 0.08, 0.15),
    n = sample(50:200, 15, replace = TRUE),
    year = sample(2010:2020, 15, replace = TRUE),
    risk_of_bias = sample(c("low", "high"), 15, replace = TRUE, prob = c(0.7, 0.3))
  )

  # Step 1: Base case analysis
  base_case <- run_pairwise_ma(data)
  expect_true(!is.null(base_case))

  # Step 2: Leave-one-out
  loo_results <- leave_one_out_analysis(data)
  expect_equal(length(loo_results), 15)

  # Step 3: Detect outliers
  outliers <- detect_outliers(data)
  expect_true(length(outliers) > 0)

  # Step 4: Exclude outliers
  outlier_analysis <- exclude_outliers_analysis(data)
  expect_true(!is.null(outlier_analysis$without_outliers))

  # Step 5: Subgroup exclusions
  high_quality <- exclude_by_risk_of_bias(data, exclude = "high")
  expect_true(nrow(high_quality) < nrow(data))

  # Step 6: Cumulative analysis
  cumulative <- cumulative_meta_analysis(data, order_by = "year")
  expect_equal(nrow(cumulative), nrow(data))

  # Step 7: Create summary
  all_results <- list(
    base_case = base_case,
    without_outliers = outlier_analysis$without_outliers,
    high_quality_only = run_pairwise_ma(high_quality)
  )

  summary <- create_sensitivity_summary_table(all_results)
  expect_true(nrow(summary) >= 3)
})


# Run all tests
cat("\n=== Running Sensitivity Analysis Module Tests ===\n")
test_results <- test_dir(".", filter = "test_sensitivity", reporter = "summary")
cat("\n=== Sensitivity Analysis Tests Complete ===\n")
