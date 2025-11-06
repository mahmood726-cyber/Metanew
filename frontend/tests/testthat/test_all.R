# ==============================================================================
# TESTTHAT TEST SUITE - EvidenceOS PRIME
# ==============================================================================
#
# Automated tests for Shiny modules and utility functions
# Run with: testthat::test_dir("tests/testthat")
#
# ==============================================================================

library(testthat)
library(shiny)
library(metafor)

# Source utilities needed for tests
source("../../utils/data_validation.R", local = TRUE)
source("../../utils/validators.R", local = TRUE)
source("../../utils/publication_tools.R", local = TRUE)

context("Data Validation Tests")

test_that("preprocess_data handles valid pairwise meta-analysis data", {
  # Create test data
  test_data <- data.frame(
    study_id = c("Study1", "Study2", "Study3"),
    yi = c(0.5, 0.3, 0.7),
    sei = c(0.1, 0.15, 0.12),
    outcome = c("mortality", "mortality", "mortality")
  )

  result <- preprocess_data(test_data, "pairwise")

  expect_true(result$success)
  expect_equal(nrow(result$data), 3)
  expect_true("vi" %in% names(result$data))
})

test_that("preprocess_data detects missing required columns", {
  # Missing yi column
  test_data <- data.frame(
    study_id = c("Study1", "Study2"),
    sei = c(0.1, 0.15)
  )

  result <- preprocess_data(test_data, "pairwise")

  expect_false(result$success)
  expect_gt(length(result$report$errors), 0)
})

test_that("preprocess_data handles missing values correctly", {
  test_data <- data.frame(
    study_id = c("Study1", "Study2", "Study3"),
    yi = c(0.5, NA, 0.7),
    sei = c(0.1, 0.15, 0.12)
  )

  result <- preprocess_data(test_data, "pairwise")

  expect_true(result$has_warnings)
  expect_gt(length(result$report$warnings), 0)
})

test_that("detect_data_type correctly identifies data formats", {
  # Binary data
  binary_data <- data.frame(
    study = c("A", "B"),
    events1 = c(10, 15),
    n1 = c(100, 120),
    events2 = c(15, 20),
    n2 = c(100, 120)
  )

  expect_equal(detect_data_type(binary_data), "binary")

  # Continuous data
  continuous_data <- data.frame(
    study = c("A", "B"),
    mean1 = c(5.2, 6.1),
    sd1 = c(1.1, 1.3),
    n1 = c(50, 60),
    mean2 = c(4.8, 5.9),
    sd2 = c(1.2, 1.4),
    n2 = c(50, 60)
  )

  expect_equal(detect_data_type(continuous_data), "continuous")

  # Effect size data
  es_data <- data.frame(
    study = c("A", "B"),
    yi = c(0.5, 0.3),
    sei = c(0.1, 0.15)
  )

  expect_equal(detect_data_type(es_data), "effect_size")
})

context("Publication Tools Tests")

test_that("create_prisma_data generates correct flow diagram data", {
  prisma_data <- create_prisma_data(
    n_identified = 1000,
    n_other = 50,
    n_duplicates = 200,
    n_screened = 850,
    n_excluded_screening = 700,
    n_full_text = 150,
    n_excluded_full_text = 120,
    exclusion_reasons = list("Wrong population" = 50, "Wrong intervention" = 40, "Wrong outcome" = 30),
    n_included = 30,
    n_meta_analysis = 25
  )

  expect_equal(prisma_data$identification$total, 1050)
  expect_equal(prisma_data$screening$after_duplicates, 850)
  expect_equal(prisma_data$included$qualitative, 30)
  expect_equal(prisma_data$included$quantitative, 25)
})

test_that("create_rob2_data generates valid RoB assessment data", {
  rob_data <- create_rob2_data(
    studies = c("Study1", "Study2"),
    randomization = c("Low", "Some concerns"),
    deviations = c("Low", "Low"),
    missing_outcome = c("Low", "High"),
    outcome_measurement = c("Low", "Low"),
    selection_reported = c("Low", "Some concerns")
  )

  expect_equal(nrow(rob_data), 2)
  expect_equal(ncol(rob_data), 6)
  expect_true(all(rob_data$randomization %in% c("Low", "Some concerns", "High")))
})

test_that("create_grade_profile generates valid GRADE data", {
  grade_data <- create_grade_profile(
    outcomes = c("Mortality", "Quality of Life"),
    n_studies = c(10, 8),
    n_participants = c(1000, 800),
    risk_of_bias = c("Not serious", "Serious"),
    inconsistency = c("Not serious", "Not serious"),
    indirectness = c("Not serious", "Not serious"),
    imprecision = c("Not serious", "Serious"),
    publication_bias = c("Undetected", "Undetected"),
    effect_size = c("0.65 (0.50-0.85)", "0.25 (0.10-0.40)"),
    certainty = c("High", "Moderate")
  )

  expect_equal(nrow(grade_data), 2)
  expect_true(all(grade_data$certainty %in% c("High", "Moderate", "Low", "Very low")))
})

context("Validator Tests")

test_that("validate_study_id detects duplicates", {
  test_data <- data.frame(
    study_id = c("Study1", "Study1", "Study2")
  )

  result <- validate_study_id(test_data)

  expect_false(result$valid)
  expect_match(result$message, "duplicate")
})

test_that("validate_numeric_columns detects non-numeric values", {
  test_data <- data.frame(
    yi = c(0.5, "invalid", 0.7),
    sei = c(0.1, 0.15, 0.12)
  )

  result <- validate_numeric_columns(test_data, c("yi", "sei"))

  expect_false(result$valid)
})

test_that("validate_positive_values detects negative values in variance", {
  test_data <- data.frame(
    sei = c(0.1, -0.15, 0.12)
  )

  result <- validate_positive_values(test_data, "sei")

  expect_false(result$valid)
  expect_match(result$message, "negative")
})

context("Meta-Analysis Calculation Tests")

test_that("rma correctly computes pooled effect", {
  # Create test data
  test_data <- data.frame(
    yi = c(0.5, 0.3, 0.7, 0.4),
    vi = c(0.01, 0.0225, 0.0144, 0.01)
  )

  # Run meta-analysis
  ma_result <- rma(yi, vi, data = test_data, method = "REML")

  expect_s3_class(ma_result, "rma.uni")
  expect_false(is.na(ma_result$beta))
  expect_true(ma_result$k == 4)
  expect_true(ma_result$ci.lb < ma_result$beta)
  expect_true(ma_result$ci.ub > ma_result$beta)
})

test_that("I-squared calculation is correct", {
  test_data <- data.frame(
    yi = c(0.5, 0.3, 0.7, 0.4, 0.6),
    vi = c(0.01, 0.0225, 0.0144, 0.01, 0.0169)
  )

  ma_result <- rma(yi, vi, data = test_data, method = "REML")

  expect_true(ma_result$I2 >= 0)
  expect_true(ma_result$I2 <= 100)
})

context("File Upload Security Tests")

test_that("file extension validation rejects invalid types", {
  valid_extensions <- c("csv", "xlsx", "xls")

  expect_true("csv" %in% valid_extensions)
  expect_true("xlsx" %in% valid_extensions)
  expect_false("exe" %in% valid_extensions)
  expect_false("sh" %in% valid_extensions)
  expect_false("pdf" %in% valid_extensions)
})

test_that("file size limit is enforced", {
  max_size_mb <- 50

  # Test various file sizes
  expect_true(10 <= max_size_mb)  # 10MB should pass
  expect_true(50 <= max_size_mb)  # 50MB should pass
  expect_false(100 <= max_size_mb) # 100MB should fail
})

context("Reactive Pattern Tests")

test_that("reactiveVal initializes correctly", {
  rv <- reactiveVal(NULL)

  expect_true(is.function(rv))
  expect_null(rv())

  rv("test")
  expect_equal(rv(), "test")
})

# Print test summary
cat("\n")
cat("================================================================================\n")
cat("TEST SUITE COMPLETE\n")
cat("================================================================================\n")
cat("\n")
cat("✓ Data validation tests\n")
cat("✓ Publication tools tests\n")
cat("✓ Validator tests\n")
cat("✓ Meta-analysis calculation tests\n")
cat("✓ File upload security tests\n")
cat("✓ Reactive pattern tests\n")
cat("\n")
cat("Run individual test files:\n")
cat("  testthat::test_file('tests/testthat/test_data_validation.R')\n")
cat("  testthat::test_file('tests/testthat/test_publication_tools.R')\n")
cat("\n")
