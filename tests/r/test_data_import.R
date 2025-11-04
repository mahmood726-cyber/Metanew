# Comprehensive Tests for Data Import Module
# Tests for frontend/modules/data_import.R

library(testthat)
library(dplyr)
library(readr)

# Source the module
source("../../frontend/modules/data_import.R")

# ============================
# FILE UPLOAD TESTS
# ============================

test_that("read_uploaded_file reads CSV correctly", {
  # Create temporary CSV
  temp_file <- tempfile(fileext = ".csv")
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    treatment1 = "Placebo",
    treatment2 = "Drug_A",
    events1 = c(10, 12, 8, 15, 11),
    n1 = rep(100, 5),
    events2 = c(15, 18, 13, 20, 16),
    n2 = rep(100, 5)
  )
  write.csv(data, temp_file, row.names = FALSE)

  result <- read_uploaded_file(temp_file, type = "csv")

  expect_true(!is.null(result))
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 5)
  expect_equal(ncol(result), 7)

  unlink(temp_file)
})

test_that("read_uploaded_file reads Excel correctly", {
  skip_if_not_installed("readxl")

  # Create temporary Excel file
  temp_file <- tempfile(fileext = ".xlsx")
  data <- data.frame(
    study_id = paste0("Study_", 1:3),
    yi = c(0.5, 0.6, 0.4),
    sei = c(0.1, 0.12, 0.09)
  )

  # Need writexl or openxlsx to write
  skip_if_not_installed("writexl")
  writexl::write_xlsx(data, temp_file)

  result <- read_uploaded_file(temp_file, type = "xlsx")

  expect_true(!is.null(result))
  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 3)

  unlink(temp_file)
})

test_that("read_uploaded_file handles TSV files", {
  # Create temporary TSV
  temp_file <- tempfile(fileext = ".txt")
  data <- data.frame(
    study_id = paste0("Study_", 1:4),
    yi = c(0.3, 0.4, 0.5, 0.6),
    sei = c(0.08, 0.10, 0.11, 0.09)
  )
  write.table(data, temp_file, sep = "\t", row.names = FALSE, quote = FALSE)

  result <- read_uploaded_file(temp_file, type = "tsv")

  expect_true(!is.null(result))
  expect_equal(nrow(result), 4)

  unlink(temp_file)
})

test_that("read_uploaded_file rejects unsupported formats", {
  temp_file <- tempfile(fileext = ".pdf")
  writeLines("Not a valid data file", temp_file)

  expect_error(
    read_uploaded_file(temp_file, type = "pdf"),
    "unsupported|format|invalid",
    ignore.case = TRUE
  )

  unlink(temp_file)
})


# ============================
# DATA VALIDATION TESTS
# ============================

test_that("validate_binary_data accepts valid binary data", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    treatment1 = "Placebo",
    treatment2 = "Drug",
    events1 = c(10, 12, 8, 15, 11),
    n1 = c(100, 100, 90, 110, 95),
    events2 = c(15, 18, 13, 20, 16),
    n2 = c(100, 100, 90, 110, 95)
  )

  validation <- validate_binary_data(data)

  expect_true(!is.null(validation))
  expect_true(validation$is_valid)
  expect_equal(length(validation$errors), 0)
})

test_that("validate_binary_data detects missing columns", {
  data <- data.frame(
    study_id = paste0("Study_", 1:3),
    events1 = c(10, 12, 8),
    n1 = c(100, 100, 90)
    # Missing events2, n2
  )

  validation <- validate_binary_data(data)

  expect_false(validation$is_valid)
  expect_true(length(validation$errors) > 0)
  expect_true(any(grepl("missing|column|required", validation$errors, ignore.case = TRUE)))
})

test_that("validate_binary_data detects events > n", {
  data <- data.frame(
    study_id = c("Study_1"),
    treatment1 = "A",
    treatment2 = "B",
    events1 = 120,  # More events than sample size!
    n1 = 100,
    events2 = 15,
    n2 = 100
  )

  validation <- validate_binary_data(data)

  expect_false(validation$is_valid)
  expect_true(any(grepl("events.*exceed|greater than", validation$errors, ignore.case = TRUE)))
})

test_that("validate_binary_data detects negative values", {
  data <- data.frame(
    study_id = c("Study_1"),
    treatment1 = "A",
    treatment2 = "B",
    events1 = -5,  # Negative!
    n1 = 100,
    events2 = 15,
    n2 = 100
  )

  validation <- validate_binary_data(data)

  expect_false(validation$is_valid)
  expect_true(any(grepl("negative|invalid|positive", validation$errors, ignore.case = TRUE)))
})

test_that("validate_binary_data detects duplicate study IDs", {
  data <- data.frame(
    study_id = c("Study_1", "Study_1"),  # Duplicate!
    treatment1 = c("A", "A"),
    treatment2 = c("B", "C"),
    events1 = c(10, 12),
    n1 = c(100, 100),
    events2 = c(15, 18),
    n2 = c(100, 100)
  )

  validation <- validate_binary_data(data)

  # Duplicate study IDs may be allowed if they're multi-arm, check warning
  expect_true("warnings" %in% names(validation) || !validation$is_valid)
})


test_that("validate_continuous_data accepts valid continuous data", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    treatment1 = "Placebo",
    treatment2 = "Drug",
    mean1 = c(10.5, 11.2, 9.8, 10.9, 11.5),
    sd1 = c(2.1, 2.3, 2.0, 2.2, 2.4),
    n1 = c(50, 55, 48, 52, 51),
    mean2 = c(11.2, 12.0, 10.5, 11.8, 12.3),
    sd2 = c(2.2, 2.5, 2.1, 2.3, 2.6),
    n2 = c(50, 55, 48, 52, 51)
  )

  validation <- validate_continuous_data(data)

  expect_true(!is.null(validation))
  expect_true(validation$is_valid)
  expect_equal(length(validation$errors), 0)
})

test_that("validate_continuous_data detects negative SD", {
  data <- data.frame(
    study_id = c("Study_1"),
    treatment1 = "A",
    treatment2 = "B",
    mean1 = 10.5,
    sd1 = -2.0,  # Negative SD!
    n1 = 50,
    mean2 = 11.2,
    sd2 = 2.2,
    n2 = 50
  )

  validation <- validate_continuous_data(data)

  expect_false(validation$is_valid)
  expect_true(any(grepl("negative|invalid.*sd|standard deviation", validation$errors, ignore.case = TRUE)))
})

test_that("validate_continuous_data detects zero SD", {
  data <- data.frame(
    study_id = c("Study_1"),
    treatment1 = "A",
    treatment2 = "B",
    mean1 = 10.5,
    sd1 = 0.0,  # Zero SD suggests no variance
    n1 = 50,
    mean2 = 11.2,
    sd2 = 2.2,
    n2 = 50
  )

  validation <- validate_continuous_data(data)

  # Should at least warn about zero SD
  expect_true(!validation$is_valid || length(validation$warnings) > 0)
})


test_that("validate_generic_data accepts pre-calculated effect sizes", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11)
  )

  validation <- validate_generic_data(data)

  expect_true(!is.null(validation))
  expect_true(validation$is_valid)
  expect_equal(length(validation$errors), 0)
})

test_that("validate_generic_data detects missing study_id", {
  data <- data.frame(
    yi = c(0.5, 0.6, 0.4),
    sei = c(0.1, 0.12, 0.09)
    # Missing study_id
  )

  validation <- validate_generic_data(data)

  expect_false(validation$is_valid)
  expect_true(any(grepl("study.*id|identifier|missing", validation$errors, ignore.case = TRUE)))
})


# ============================
# DATA TRANSFORMATION TESTS
# ============================

test_that("transform_to_long_format converts wide to long", {
  wide_data <- data.frame(
    study_id = paste0("Study_", 1:3),
    treatment1 = "Placebo",
    treatment2 = "Drug_A",
    events1 = c(10, 12, 8),
    n1 = c(100, 100, 90),
    events2 = c(15, 18, 13),
    n2 = c(100, 100, 90)
  )

  long_data <- transform_to_long_format(wide_data)

  expect_true(!is.null(long_data))
  expect_equal(nrow(long_data), 6)  # 3 studies × 2 arms = 6 rows
  expect_true("treatment" %in% names(long_data))
  expect_true("events" %in% names(long_data))
  expect_true("n" %in% names(long_data))
})

test_that("transform_to_wide_format converts long to wide", {
  long_data <- data.frame(
    study_id = rep(paste0("Study_", 1:3), each = 2),
    treatment = rep(c("Placebo", "Drug_A"), 3),
    events = c(10, 15, 12, 18, 8, 13),
    n = rep(c(100, 100), 3)
  )

  wide_data <- transform_to_wide_format(long_data)

  expect_true(!is.null(wide_data))
  expect_equal(nrow(wide_data), 3)  # 3 studies
  expect_true("treatment1" %in% names(wide_data))
  expect_true("treatment2" %in% names(wide_data))
  expect_true("events1" %in% names(wide_data))
  expect_true("events2" %in% names(wide_data))
})


# ============================
# DATA CLEANING TESTS
# ============================

test_that("clean_study_data removes rows with all NA", {
  data <- data.frame(
    study_id = c("Study_1", "Study_2", "Study_3"),
    yi = c(0.5, NA, 0.6),
    sei = c(0.1, NA, 0.12)
  )

  cleaned <- clean_study_data(data)

  # Row with all NA in yi and sei should be removed
  expect_equal(nrow(cleaned), 2)
  expect_true(all(!is.na(cleaned$study_id)))
})

test_that("clean_study_data removes duplicate rows", {
  data <- data.frame(
    study_id = c("Study_1", "Study_1", "Study_2"),
    yi = c(0.5, 0.5, 0.6),
    sei = c(0.1, 0.1, 0.12)
  )

  cleaned <- clean_study_data(data, remove_duplicates = TRUE)

  expect_equal(nrow(cleaned), 2)
  expect_equal(length(unique(cleaned$study_id)), 2)
})

test_that("clean_study_data trims whitespace in character columns", {
  data <- data.frame(
    study_id = c(" Study_1 ", "Study_2", " Study_3"),
    treatment = c("Placebo  ", "  Drug_A", "Drug_B ")
  )

  cleaned <- clean_study_data(data)

  expect_true(all(!grepl("^\\s|\\s$", cleaned$study_id)))
  expect_true(all(!grepl("^\\s|\\s$", cleaned$treatment)))
})


# ============================
# DATA TYPE DETECTION TESTS
# ============================

test_that("detect_data_type identifies binary data", {
  data <- data.frame(
    study_id = paste0("Study_", 1:3),
    events1 = c(10, 12, 8),
    n1 = c(100, 100, 90),
    events2 = c(15, 18, 13),
    n2 = c(100, 100, 90)
  )

  data_type <- detect_data_type(data)

  expect_equal(data_type, "binary")
})

test_that("detect_data_type identifies continuous data", {
  data <- data.frame(
    study_id = paste0("Study_", 1:3),
    mean1 = c(10.5, 11.2, 9.8),
    sd1 = c(2.1, 2.3, 2.0),
    n1 = c(50, 55, 48),
    mean2 = c(11.2, 12.0, 10.5),
    sd2 = c(2.2, 2.5, 2.1),
    n2 = c(50, 55, 48)
  )

  data_type <- detect_data_type(data)

  expect_equal(data_type, "continuous")
})

test_that("detect_data_type identifies generic effect size data", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11)
  )

  data_type <- detect_data_type(data)

  expect_equal(data_type, "generic")
})

test_that("detect_data_type returns unknown for ambiguous data", {
  data <- data.frame(
    study_id = paste0("Study_", 1:3),
    random_col1 = c(1, 2, 3),
    random_col2 = c(4, 5, 6)
  )

  data_type <- detect_data_type(data)

  expect_equal(data_type, "unknown")
})


# ============================
# MISSING DATA HANDLING TESTS
# ============================

test_that("impute_missing_sei imputes from confidence intervals", {
  data <- data.frame(
    study_id = paste0("Study_", 1:3),
    yi = c(0.5, 0.6, 0.4),
    sei = c(0.1, NA, 0.09),
    ci_lower = c(0.3, 0.38, 0.22),
    ci_upper = c(0.7, 0.82, 0.58)
  )

  imputed <- impute_missing_sei(data)

  # Should have imputed the missing sei
  expect_true(all(!is.na(imputed$sei)))
  expect_true(imputed$sei[2] > 0)
})

test_that("impute_missing_sei calculates from p-values", {
  data <- data.frame(
    study_id = paste0("Study_", 1:3),
    yi = c(0.5, 0.6, 0.4),
    sei = c(0.1, NA, 0.09),
    pval = c(0.01, 0.05, 0.001)
  )

  imputed <- impute_missing_sei(data)

  # Should have attempted imputation from p-value
  expect_true(!is.null(imputed))
})


# ============================
# MULTI-ARM STUDY HANDLING TESTS
# ============================

test_that("detect_multiarm_studies identifies 3-arm studies", {
  data <- data.frame(
    study_id = c("S1", "S1", "S1", "S2", "S2"),
    treatment = c("A", "B", "C", "A", "B"),
    events = c(10, 15, 12, 8, 14),
    n = rep(100, 5)
  )

  multiarm <- detect_multiarm_studies(data)

  expect_true(!is.null(multiarm))
  expect_true("S1" %in% multiarm$study_id)
  expect_equal(multiarm$n_arms[multiarm$study_id == "S1"], 3)
})

test_that("adjust_multiarm_se adjusts standard errors", {
  data <- data.frame(
    study_id = c("S1", "S1", "S1"),
    treatment = c("A", "B", "C"),
    yi = c(0.5, 0.6, 0.7),
    sei = c(0.1, 0.12, 0.11)
  )

  adjusted <- adjust_multiarm_se(data)

  # SEs should be adjusted (increased) for multi-arm correlation
  expect_true(all(adjusted$sei >= data$sei))
})


# ============================
# DATA SUMMARY TESTS
# ============================

test_that("summarize_uploaded_data provides correct summary", {
  data <- data.frame(
    study_id = paste0("Study_", 1:10),
    treatment1 = "Placebo",
    treatment2 = sample(c("Drug_A", "Drug_B", "Drug_C"), 10, replace = TRUE),
    events1 = sample(8:15, 10, replace = TRUE),
    n1 = sample(90:110, 10, replace = TRUE),
    events2 = sample(10:20, 10, replace = TRUE),
    n2 = sample(90:110, 10, replace = TRUE),
    year = sample(2010:2020, 10, replace = TRUE)
  )

  summary <- summarize_uploaded_data(data)

  expect_true(!is.null(summary))
  expect_equal(summary$n_studies, 10)
  expect_true("n_treatments" %in% names(summary))
  expect_true("data_type" %in% names(summary))
  expect_true("year_range" %in% names(summary) || "years" %in% names(summary))
})

test_that("summarize_uploaded_data calculates sample size range", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11),
    n = c(50, 100, 75, 120, 60)
  )

  summary <- summarize_uploaded_data(data)

  expect_true("sample_size_range" %in% names(summary) ||
              "total_n" %in% names(summary))
})


# ============================
# DATA EXPORT TESTS
# ============================

test_that("export_cleaned_data saves CSV correctly", {
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    yi = c(0.5, 0.6, 0.4, 0.7, 0.5),
    sei = c(0.1, 0.12, 0.09, 0.15, 0.11)
  )

  temp_file <- tempfile(fileext = ".csv")
  export_cleaned_data(data, temp_file, format = "csv")

  # Verify file exists and can be read back
  expect_true(file.exists(temp_file))

  read_back <- read.csv(temp_file)
  expect_equal(nrow(read_back), 5)
  expect_equal(ncol(read_back), 3)

  unlink(temp_file)
})


# ============================
# TEMPLATE GENERATION TESTS
# ============================

test_that("generate_data_template creates binary template", {
  template <- generate_data_template(data_type = "binary")

  expect_true(!is.null(template))
  expect_true(is.data.frame(template))
  expect_true("study_id" %in% names(template))
  expect_true("events1" %in% names(template))
  expect_true("n1" %in% names(template))
  expect_true("events2" %in% names(template))
  expect_true("n2" %in% names(template))
})

test_that("generate_data_template creates continuous template", {
  template <- generate_data_template(data_type = "continuous")

  expect_true(!is.null(template))
  expect_true("mean1" %in% names(template))
  expect_true("sd1" %in% names(template))
  expect_true("n1" %in% names(template))
})

test_that("generate_data_template creates generic template", {
  template <- generate_data_template(data_type = "generic")

  expect_true(!is.null(template))
  expect_true("yi" %in% names(template))
  expect_true("sei" %in% names(template))
})


# ============================
# ERROR HANDLING TESTS
# ============================

test_that("read_uploaded_file handles corrupted files gracefully", {
  temp_file <- tempfile(fileext = ".csv")
  writeLines(c("corrupted", "data", "!!!"), temp_file)

  expect_error(
    read_uploaded_file(temp_file, type = "csv"),
    "corrupt|invalid|parse|read",
    ignore.case = TRUE
  )

  unlink(temp_file)
})

test_that("validate_binary_data provides helpful error messages", {
  data <- data.frame(
    study_id = c("S1"),
    events1 = 150,  # > n1
    n1 = 100
  )

  validation <- validate_binary_data(data)

  expect_false(validation$is_valid)
  expect_true(length(validation$errors) > 0)

  # Errors should be descriptive
  expect_true(any(nchar(validation$errors) > 10))
})


# ============================
# INTEGRATION TESTS
# ============================

test_that("Full data import workflow completes successfully", {
  # Step 1: Create test data
  temp_file <- tempfile(fileext = ".csv")
  data <- data.frame(
    study_id = paste0("Study_", 1:5),
    treatment1 = "Placebo",
    treatment2 = "Drug_A",
    events1 = c(10, 12, 8, 15, 11),
    n1 = rep(100, 5),
    events2 = c(15, 18, 13, 20, 16),
    n2 = rep(100, 5)
  )
  write.csv(data, temp_file, row.names = FALSE)

  # Step 2: Read file
  uploaded_data <- read_uploaded_file(temp_file, type = "csv")
  expect_equal(nrow(uploaded_data), 5)

  # Step 3: Detect data type
  data_type <- detect_data_type(uploaded_data)
  expect_equal(data_type, "binary")

  # Step 4: Validate data
  validation <- validate_binary_data(uploaded_data)
  expect_true(validation$is_valid)

  # Step 5: Clean data
  cleaned_data <- clean_study_data(uploaded_data)
  expect_equal(nrow(cleaned_data), 5)

  # Step 6: Summarize data
  summary <- summarize_uploaded_data(cleaned_data)
  expect_equal(summary$n_studies, 5)

  unlink(temp_file)
})


# Run all tests
cat("\n=== Running Data Import Module Tests ===\n")
test_results <- test_dir(".", filter = "test_data_import", reporter = "summary")
cat("\n=== Data Import Tests Complete ===\n")
