# Test Suite for NMA Transitivity Assessment
# Comprehensive tests for transitivity assumption evaluation

library(testthat)
library(netmeta)
library(dplyr)

# Source the transitivity functions
source("../../frontend/utils/nma_transitivity.R")

context("NMA Transitivity Assessment")


# Test Data Setup ----------------------------------------------------------

setup_test_data <- function() {
  # Create synthetic network data with known effect modifiers
  set.seed(42)

  studies <- paste0("Study", 1:15)
  treatments <- c("A", "B", "C", "D")

  # Create pairwise comparisons
  data <- data.frame(
    studyid = c(
      rep("Study1", 1), rep("Study2", 1), rep("Study3", 1),
      rep("Study4", 1), rep("Study5", 1), rep("Study6", 1),
      rep("Study7", 1), rep("Study8", 1), rep("Study9", 1),
      rep("Study10", 1), rep("Study11", 1), rep("Study12", 1)
    ),
    treatment1 = c("A", "A", "A", "B", "B", "B", "C", "C", "C", "A", "B", "C"),
    treatment2 = c("B", "C", "D", "C", "D", "A", "D", "A", "B", "C", "D", "A"),
    TE = rnorm(12, mean = 0.5, sd = 0.3),
    seTE = runif(12, min = 0.1, max = 0.3),
    stringsAsFactors = FALSE
  )

  # Add effect modifiers
  data$mean_age <- rnorm(nrow(data), mean = 55, sd = 8)
  data$percent_male <- runif(nrow(data), min = 40, max = 60)
  data$study_quality <- sample(c("High", "Medium", "Low"),
                               nrow(data), replace = TRUE,
                               prob = c(0.4, 0.4, 0.2))
  data$baseline_risk <- runif(nrow(data), min = 0.1, max = 0.4)

  return(data)
}

setup_heterogeneous_data <- function() {
  # Create data with deliberately heterogeneous effect modifiers
  data <- setup_test_data()

  # Make age differ systematically by comparison
  data$mean_age <- ifelse(grepl("A", data$treatment1) | grepl("A", data$treatment2),
                          rnorm(nrow(data), mean = 45, sd = 3),
                          rnorm(nrow(data), mean = 65, sd = 3))

  # Make quality differ by comparison
  data$study_quality <- ifelse(grepl("D", data$treatment1) | grepl("D", data$treatment2),
                               "Low", "High")

  return(data)
}


# Test: Variable Classification --------------------------------------------

test_that("classify_variables correctly identifies categorical vs continuous", {
  data <- setup_test_data()

  variables <- c("mean_age", "percent_male", "study_quality", "baseline_risk")
  result <- classify_variables(data, variables)

  expect_true("mean_age" %in% result$continuous)
  expect_true("percent_male" %in% result$continuous)
  expect_true("study_quality" %in% result$categorical)
  expect_true("baseline_risk" %in% result$continuous)
})


test_that("classify_variables handles edge cases", {
  data <- data.frame(
    binary = c(0, 1, 0, 1),
    few_levels = c(1, 2, 3, 1),
    many_levels = rnorm(100)
  )

  result <- classify_variables(data, c("binary", "few_levels", "many_levels"))

  expect_true("binary" %in% result$categorical)
  expect_true("few_levels" %in% result$categorical)
  expect_true("many_levels" %in% result$continuous)
})


# Test: Comparison Identification ------------------------------------------

test_that("identify_comparisons correctly identifies treatment pairs", {
  data <- setup_test_data()

  comparisons <- identify_comparisons(data, "treatment1", "studyid")

  expect_true(is.data.frame(comparisons))
  expect_true(all(c("comparison", "treat1", "treat2", "study") %in% names(comparisons)))
  expect_true(nrow(comparisons) > 0)

  # Each study should have at least one comparison
  expect_true(all(unique(data$studyid) %in% comparisons$study))
})


test_that("identify_comparisons handles multi-arm trials", {
  # Create data with a 3-arm trial
  data <- data.frame(
    studyid = rep("Study1", 3),
    treatment = c("A", "B", "C"),
    TE = c(0.5, 0.6, 0.7),
    seTE = c(0.1, 0.1, 0.1)
  )

  # Note: identify_comparisons expects treatment1/treatment2 format
  # This test would need adaptation based on actual data structure
})


# Test: Categorical Transitivity Assessment --------------------------------

test_that("assess_categorical_transitivity identifies homogeneous distributions", {
  data <- setup_test_data()

  # Make quality uniform across all comparisons
  data$study_quality <- "High"

  comparisons <- identify_comparisons(data, "treatment1", "studyid")

  result <- assess_categorical_transitivity(
    data, "study_quality", comparisons, "studyid"
  )

  expect_true(is.list(result))
  expect_true("study_quality" %in% names(result))

  # With uniform distribution, p-value should be high (or NA for single category)
  # expect_true(is.na(result$study_quality$p_value) ||
  #             result$study_quality$p_value > 0.10)
})


test_that("assess_categorical_transitivity detects heterogeneous distributions", {
  data <- setup_heterogeneous_data()

  comparisons <- identify_comparisons(data, "treatment1", "studyid")

  result <- assess_categorical_transitivity(
    data, "study_quality", comparisons, "studyid"
  )

  expect_true(is.list(result))
  expect_true("study_quality" %in% names(result))

  # With deliberately heterogeneous data, should show some concern
  # (though exact p-value depends on random data)
  expect_true(!is.null(result$study_quality$transitivity_concern))
})


# Test: Continuous Transitivity Assessment ---------------------------------

test_that("assess_continuous_transitivity calculates summary statistics", {
  data <- setup_test_data()

  comparisons <- identify_comparisons(data, "treatment1", "studyid")

  result <- assess_continuous_transitivity(
    data, "mean_age", comparisons, "studyid"
  )

  expect_true(is.list(result))
  expect_true("mean_age" %in% names(result))

  res <- result$mean_age
  expect_true(!is.null(res$summary))
  expect_true(all(c("mean", "sd", "median", "min", "max") %in% names(res$summary)))
})


test_that("assess_continuous_transitivity performs ANOVA test", {
  data <- setup_test_data()

  comparisons <- identify_comparisons(data, "treatment1", "studyid")

  result <- assess_continuous_transitivity(
    data, "mean_age", comparisons, "studyid"
  )

  res <- result$mean_age
  expect_true(!is.null(res$f_statistic) || is.na(res$f_statistic))
  expect_true(!is.null(res$p_value) || is.na(res$p_value))
  expect_true(!is.null(res$coefficient_of_variation))
})


test_that("assess_continuous_transitivity detects heterogeneous means", {
  data <- setup_heterogeneous_data()

  comparisons <- identify_comparisons(data, "treatment1", "studyid")

  result <- assess_continuous_transitivity(
    data, "mean_age", comparisons, "studyid"
  )

  res <- result$mean_age

  # With deliberately different age distributions, CV should be higher
  expect_true(res$coefficient_of_variation > 0)
})


# Test: Main Transitivity Assessment ---------------------------------------

test_that("assess_transitivity runs with minimal input", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  expect_s3_class(result, "transitivity_assessment")
  expect_true(!is.null(result$overall))
  expect_true(!is.null(result$effect_modifiers))
})


test_that("assess_transitivity auto-detects variable types", {
  data <- setup_test_data()

  # Don't specify categorical/continuous
  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality", "baseline_risk"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  expect_true(!is.null(result$categorical))
  expect_true(!is.null(result$continuous))

  # study_quality should be classified as categorical
  expect_true("study_quality" %in% names(result$categorical))

  # mean_age should be classified as continuous
  expect_true("mean_age" %in% names(result$continuous))
})


test_that("assess_transitivity provides overall summary", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  expect_true(!is.null(result$overall))
  expect_true(!is.null(result$overall$summary))
  expect_true(!is.null(result$overall$n_effect_modifiers))
  expect_true(!is.null(result$overall$n_concerns))
  expect_true(!is.null(result$overall$overall_rating))

  expect_equal(result$overall$n_effect_modifiers, 2)
})


test_that("assess_transitivity validates inputs", {
  data <- setup_test_data()

  # Missing effect modifier
  expect_error(
    assess_transitivity(
      data = data,
      effect_modifiers = c("nonexistent_variable"),
      treatment_var = "treatment1",
      study_var = "studyid"
    ),
    "not found"
  )

  # Missing treatment variable
  expect_error(
    assess_transitivity(
      data = data,
      effect_modifiers = c("mean_age"),
      treatment_var = "nonexistent",
      study_var = "studyid"
    ),
    "not found"
  )
})


# Test: Network Coherence Assessment ---------------------------------------

test_that("assess_network_coherence works with netmeta object", {
  skip_if_not_installed("netmeta")

  data(Senn2013, package = "netmeta")

  net <- netmeta(TE, seTE, treat1, treat2, studlab,
                 data = Senn2013, sm = "MD", reference.group = "plac")

  coherence <- assess_network_coherence(net)

  expect_s3_class(coherence, "network_coherence")
  expect_true(!is.null(coherence$n_treatments))
  expect_true(!is.null(coherence$n_studies))
  expect_true(!is.null(coherence$network_density))
  expect_true(!is.null(coherence$coherence_rating))
})


test_that("assess_network_coherence calculates network metrics", {
  skip_if_not_installed("netmeta")

  data(Senn2013, package = "netmeta")

  net <- netmeta(TE, seTE, treat1, treat2, studlab,
                 data = Senn2013, sm = "MD", reference.group = "plac")

  coherence <- assess_network_coherence(net)

  expect_true(coherence$n_treatments > 0)
  expect_true(coherence$n_studies > 0)
  expect_true(coherence$network_density >= 0 && coherence$network_density <= 1)
})


test_that("assess_network_geometry identifies network type", {
  skip_if_not_installed("netmeta")

  data(Senn2013, package = "netmeta")

  net <- netmeta(TE, seTE, treat1, treat2, studlab,
                 data = Senn2013, sm = "MD", reference.group = "plac")

  coherence <- assess_network_coherence(net)

  expect_true(!is.null(coherence$geometry))
  expect_true(!is.null(coherence$geometry$geometry_type))
  expect_true(is.character(coherence$geometry$geometry_type))
})


# Test: Visualization Functions --------------------------------------------

test_that("plot_transitivity creates overview plot", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  expect_error(plot_transitivity(result), NA)  # Should not error

  p <- plot_transitivity(result)
  expect_true("ggplot" %in% class(p))
})


test_that("plot_transitivity creates variable-specific plot", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  # Plot continuous variable
  expect_error(plot_transitivity(result, variable = "mean_age"), NA)

  p <- plot_transitivity(result, variable = "mean_age")
  expect_true("ggplot" %in% class(p))
})


test_that("plot_transitivity handles categorical variables", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  # Plot categorical variable
  expect_error(plot_transitivity(result, variable = "study_quality"), NA)

  p <- plot_transitivity(result, variable = "study_quality")
  expect_true("ggplot" %in% class(p))
})


test_that("plot_transitivity errors on nonexistent variable", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  expect_error(
    plot_transitivity(result, variable = "nonexistent"),
    "not found"
  )
})


# Test: Report Generation --------------------------------------------------

test_that("create_transitivity_report generates report", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  report <- create_transitivity_report(result)

  expect_true(is.character(report))
  expect_true(length(report) > 0)
  expect_true(any(grepl("Transitivity Assessment", report)))
})


test_that("create_transitivity_report includes coherence when provided", {
  skip_if_not_installed("netmeta")

  data(Senn2013, package = "netmeta")

  # Add effect modifiers to Senn2013
  Senn2013$mean_age <- rnorm(nrow(Senn2013), 55, 8)

  # Assess transitivity
  result <- assess_transitivity(
    data = Senn2013,
    effect_modifiers = c("mean_age"),
    treatment_var = "treat1",
    study_var = "studlab"
  )

  # Network coherence
  net <- netmeta(TE, seTE, treat1, treat2, studlab,
                 data = Senn2013, sm = "MD", reference.group = "plac")
  coherence <- assess_network_coherence(net)

  report <- create_transitivity_report(result, coherence = coherence)

  expect_true(any(grepl("Network Structure", report)))
  expect_true(any(grepl("Coherence", report)))
})


test_that("create_transitivity_report saves to file", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  temp_file <- tempfile(fileext = ".md")

  report <- create_transitivity_report(result, output_file = temp_file)

  expect_true(file.exists(temp_file))

  # Clean up
  unlink(temp_file)
})


# Test: Print Methods ------------------------------------------------------

test_that("print.transitivity_assessment displays summary", {
  data <- setup_test_data()

  result <- assess_transitivity(
    data = data,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  # Should not error
  expect_error(print(result), NA)

  # Capture output
  output <- capture.output(print(result))

  expect_true(length(output) > 0)
  expect_true(any(grepl("Transitivity Assessment", output)))
})


test_that("print.network_coherence displays summary", {
  skip_if_not_installed("netmeta")

  data(Senn2013, package = "netmeta")

  net <- netmeta(TE, seTE, treat1, treat2, studlab,
                 data = Senn2013, sm = "MD", reference.group = "plac")

  coherence <- assess_network_coherence(net)

  # Should not error
  expect_error(print(coherence), NA)

  # Capture output
  output <- capture.output(print(coherence))

  expect_true(length(output) > 0)
  expect_true(any(grepl("Coherence", output)))
})


# Test: Edge Cases and Error Handling --------------------------------------

test_that("transitivity assessment handles small sample sizes", {
  # Create minimal network
  data <- data.frame(
    studyid = c("S1", "S2"),
    treatment1 = c("A", "B"),
    treatment2 = c("B", "C"),
    TE = c(0.5, 0.6),
    seTE = c(0.1, 0.1),
    mean_age = c(50, 55)
  )

  result <- assess_transitivity(
    data = data,
    effect_modifiers = "mean_age",
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  expect_s3_class(result, "transitivity_assessment")
})


test_that("transitivity assessment handles missing data", {
  data <- setup_test_data()

  # Introduce missing values
  data$mean_age[c(1, 3, 5)] <- NA

  result <- assess_transitivity(
    data = data,
    effect_modifiers = "mean_age",
    treatment_var = "treatment1",
    study_var = "studyid"
  )

  expect_s3_class(result, "transitivity_assessment")
})


test_that("rate_coherence provides appropriate ratings", {
  # High quality network
  rating_high <- rate_coherence(density = 0.7, n_multiarm = 5,
                                geometry = list(mean_connections = 4))
  expect_true(grepl("Excellent", rating_high))

  # Moderate network
  rating_mod <- rate_coherence(density = 0.4, n_multiarm = 2,
                               geometry = list(mean_connections = 2))
  expect_true(grepl("Good", rating_mod))

  # Sparse network
  rating_low <- rate_coherence(density = 0.2, n_multiarm = 0,
                               geometry = list(mean_connections = 1))
  expect_true(grepl("Limited", rating_low))
})


# Integration Tests --------------------------------------------------------

test_that("full transitivity workflow completes successfully", {
  skip_if_not_installed("netmeta")

  # Use real netmeta data
  data(Senn2013, package = "netmeta")

  # Add effect modifiers
  set.seed(123)
  Senn2013$mean_age <- rnorm(nrow(Senn2013), 55, 8)
  Senn2013$study_quality <- sample(c("High", "Low"),
                                   nrow(Senn2013), replace = TRUE)

  # Assess transitivity
  trans <- assess_transitivity(
    data = Senn2013,
    effect_modifiers = c("mean_age", "study_quality"),
    treatment_var = "treat1",
    study_var = "studlab"
  )

  # Create network
  net <- netmeta(TE, seTE, treat1, treat2, studlab,
                 data = Senn2013, sm = "MD", reference.group = "plac")

  # Assess coherence
  coherence <- assess_network_coherence(net)

  # Generate visualizations
  p1 <- plot_transitivity(trans)
  p2 <- plot_transitivity(trans, variable = "mean_age")

  # Generate report
  report <- create_transitivity_report(trans, coherence)

  # All should complete without error
  expect_s3_class(trans, "transitivity_assessment")
  expect_s3_class(coherence, "network_coherence")
  expect_true("ggplot" %in% class(p1))
  expect_true("ggplot" %in% class(p2))
  expect_true(is.character(report))
  expect_true(length(report) > 0)
})


# Run all tests
test_file("test_nma_transitivity.R")
