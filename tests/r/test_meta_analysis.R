# Tests for meta-analysis functions
library(testthat)
library(metafor)

# Source the module
source("../../frontend/modules/meta_pairwise.R")

test_that("run_pairwise_ma works with valid data", {
  # Create sample data
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11),
    outcome = rep("Mortality", 5)
  )

  result <- run_pairwise_ma(data, outcome = "Mortality", method = "REML")

  expect_true(!is.null(result))
  expect_true("pooled_effect" %in% names(result))
  expect_true("i_squared" %in% names(result))
  expect_true("tau_squared" %in% names(result))
  expect_equal(result$n_studies, 5)
})

test_that("run_pairwise_ma calculates correct pooled effect", {
  # Simple test with known result
  data <- data.frame(
    study_id = c("S1", "S2"),
    yi = c(0.5, 0.5),
    sei = c(0.1, 0.1)
  )

  data$vi <- data$sei^2

  result <- run_pairwise_ma(data, method = "REML")

  # With identical effects and SEs, pooled should be close to 0.5
  expect_equal(result$pooled_effect, 0.5, tolerance = 0.01)
})

test_that("run_pairwise_ma handles heterogeneity", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    yi = c(0.2, 0.3, 0.5, 0.7, 0.9, 0.4, 0.6, 0.5, 0.8, 0.3),
    sei = rep(0.1, 10)
  )

  data$vi <- data$sei^2

  result <- run_pairwise_ma(data, method = "REML")

  # Should detect heterogeneity
  expect_true(result$i_squared > 0)
  expect_true(result$tau_squared >= 0)
})

test_that("interpret_i_squared works correctly", {
  source("../../frontend/modules/meta_pairwise.R")

  expect_equal(interpret_i_squared(20), "Low heterogeneity")
  expect_equal(interpret_i_squared(40), "Moderate heterogeneity")
  expect_equal(interpret_i_squared(60), "Substantial heterogeneity")
  expect_equal(interpret_i_squared(80), "Considerable heterogeneity")
})

# Run tests
test_dir(".", reporter = "summary")
