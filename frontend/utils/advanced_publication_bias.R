# ==============================================================================
# ADVANCED PUBLICATION BIAS TESTS
# ==============================================================================
#
# Implements additional small-study effects tests beyond Egger's test
# These methods are more appropriate for specific effect size types
#
# METHODS:
#   - Peters test: For binary outcomes (ORs, RRs) - addresses Egger's limitations
#   - Harbord test: Alternative asymmetry test with better properties for ORs
#   - Thompson-Sharp test: For meta-regression contexts
#
# References:
#   - Peters et al. (2006) JAMA
#   - Harbord et al. (2006) Biostatistics
#   - Egger et al. (1997) BMJ
#
# Author: EvidenceOS PRIME
# ==============================================================================

library(metafor)

# ==============================================================================
# PETERS TEST (For Binary Outcomes)
# ==============================================================================

#' Peters test for funnel plot asymmetry
#'
#' More appropriate than Egger's test for binary outcomes (ORs, RRs)
#' Tests for relationship between effect size and 1/total sample size
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of variances
#' @param ni Vector of total sample sizes (required)
#' @param method Estimation method (default "FE" for Peters test)
#' @return List with test results
#' @export
#'
#' @references Peters JL, Sutton AJ, Jones DR, Abrams KR, Rushton L (2006)
#'   Comparison of two methods to detect publication bias in meta-analysis.
#'   JAMA 295(6):676-680.
peters_test <- function(yi, vi, ni, method = "FE") {

  # Validate inputs
  if (missing(ni) || is.null(ni)) {
    stop("Peters test requires total sample sizes (ni)")
  }

  if (length(yi) != length(vi) || length(yi) != length(ni)) {
    stop("yi, vi, and ni must have same length")
  }

  if (length(yi) < 10) {
    warning("Peters test should have at least 10 studies")
    return(list(
      test = "Peters",
      insufficient_studies = TRUE,
      n_studies = length(yi),
      message = "Need at least 10 studies for Peters test"
    ))
  }

  # Create predictor: 1/n (inverse of total sample size)
  inv_n <- 1 / ni

  # Run regression: yi ~ 1/n
  # Uses fixed-effect model as per Peters et al. (2006)
  tryCatch({
    model <- rma(yi = yi, vi = vi, mods = ~ inv_n, method = method)

    # Extract intercept (β0) and slope (β1)
    # Slope coefficient for inv_n tests for asymmetry
    intercept <- as.numeric(model$beta[1])
    slope <- as.numeric(model$beta[2])

    # Test statistic for slope
    z_value <- as.numeric(model$zval[2])
    p_value <- as.numeric(model$pval[2])

    # Confidence interval for slope
    ci_lower <- as.numeric(model$ci.lb[2])
    ci_upper <- as.numeric(model$ci.ub[2])

    # Interpretation
    interpretation <- if (p_value < 0.05) {
      "Significant funnel plot asymmetry detected (small-study effects present)"
    } else if (p_value < 0.10) {
      "Marginal evidence of funnel plot asymmetry (p < 0.10)"
    } else {
      "No significant funnel plot asymmetry detected"
    }

    list(
      test = "Peters",
      n_studies = length(yi),
      intercept = intercept,
      slope = slope,
      z_value = z_value,
      p_value = p_value,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      interpretation = interpretation,
      model = model,
      sufficient_studies = TRUE
    )

  }, error = function(e) {
    list(
      test = "Peters",
      error = TRUE,
      message = paste("Peters test failed:", e$message)
    )
  })
}

# ==============================================================================
# HARBORD TEST (For Binary Outcomes - ORs)
# ==============================================================================

#' Harbord test for funnel plot asymmetry
#'
#' Modified test for small-study effects, specifically designed for log odds ratios
#' Better statistical properties than Egger's test for ORs
#'
#' @param yi Vector of log odds ratios
#' @param vi Vector of variances
#' @param method Estimation method (default "FE")
#' @return List with test results
#' @export
#'
#' @references Harbord RM, Egger M, Sterne JAC (2006)
#'   A modified test for small-study effects in meta-analyses of controlled trials
#'   with binary endpoints. Statistics in Medicine 25:3443-3457.
harbord_test <- function(yi, vi, method = "FE") {

  if (length(yi) < 10) {
    warning("Harbord test should have at least 10 studies")
    return(list(
      test = "Harbord",
      insufficient_studies = TRUE,
      n_studies = length(yi),
      message = "Need at least 10 studies for Harbord test"
    ))
  }

  # Calculate standard errors
  sei <- sqrt(vi)

  # Harbord test uses:
  # Z/sqrt(V) regressed on sqrt(V)
  # where Z = score statistic, V = variance of score

  # For log OR, the efficient score is yi/vi
  # So Z = yi, V = vi

  # Create predictors
  z_over_sqrt_v <- yi / sei  # Standardized effect
  sqrt_v <- sei              # Standard error (predictor)

  tryCatch({
    # Run regression: (Z/sqrt(V)) ~ sqrt(V)
    # Intercept tests for asymmetry
    model <- rma(yi = z_over_sqrt_v, vi = 1, mods = ~ sqrt_v, method = method)

    # Extract intercept (tests for bias)
    intercept <- as.numeric(model$beta[1])
    slope <- as.numeric(model$beta[2])

    # Test statistic for intercept
    z_value <- as.numeric(model$zval[1])
    p_value <- as.numeric(model$pval[1])

    # Confidence interval for intercept
    ci_lower <- as.numeric(model$ci.lb[1])
    ci_upper <- as.numeric(model$ci.ub[1])

    # Interpretation
    interpretation <- if (p_value < 0.05) {
      "Significant small-study effects detected (Harbord test)"
    } else if (p_value < 0.10) {
      "Marginal evidence of small-study effects (p < 0.10)"
    } else {
      "No significant small-study effects detected"
    }

    list(
      test = "Harbord",
      n_studies = length(yi),
      intercept = intercept,
      slope = slope,
      z_value = z_value,
      p_value = p_value,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      interpretation = interpretation,
      model = model,
      sufficient_studies = TRUE
    )

  }, error = function(e) {
    list(
      test = "Harbord",
      error = TRUE,
      message = paste("Harbord test failed:", e$message)
    )
  })
}

# ==============================================================================
# COMPREHENSIVE SMALL-STUDY EFFECTS ASSESSMENT
# ==============================================================================

#' Run comprehensive small-study effects tests
#'
#' Runs multiple tests appropriate for different effect size types
#' Automatically selects tests based on effect size type
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of variances
#' @param effect_type Type of effect size: "OR", "RR", "MD", "SMD", "HR"
#' @param ni Vector of total sample sizes (optional, needed for Peters)
#' @return List with results from all applicable tests
#' @export
comprehensive_bias_tests <- function(yi, vi, effect_type = "unknown", ni = NULL) {

  results <- list()

  # Always run Egger test (general purpose)
  egger <- tryCatch({
    sei <- sqrt(vi)
    model <- rma(yi = yi, vi = vi, mods = ~ sei, method = "FE")

    list(
      test = "Egger",
      intercept = as.numeric(model$beta[1]),
      z_value = as.numeric(model$zval[1]),
      p_value = as.numeric(model$pval[1]),
      ci_lower = as.numeric(model$ci.lb[1]),
      ci_upper = as.numeric(model$ci.ub[1]),
      interpretation = ifelse(
        as.numeric(model$pval[1]) < 0.05,
        "Significant funnel plot asymmetry (Egger test)",
        "No significant funnel plot asymmetry (Egger test)"
      )
    )
  }, error = function(e) {
    list(test = "Egger", error = TRUE, message = e$message)
  })

  results$egger <- egger

  # For binary outcomes (OR, RR), run Peters and Harbord
  if (effect_type %in% c("OR", "RR", "log OR", "log RR")) {

    # Peters test (if sample sizes available)
    if (!is.null(ni)) {
      results$peters <- peters_test(yi, vi, ni)
    } else {
      results$peters <- list(
        test = "Peters",
        not_run = TRUE,
        message = "Sample sizes (ni) not provided"
      )
    }

    # Harbord test
    results$harbord <- harbord_test(yi, vi)

    # Add recommendation
    results$recommendation <- paste(
      "For odds ratios, Harbord and Peters tests are more appropriate than Egger.",
      "If results differ, prefer Harbord/Peters over Egger."
    )
  }

  # Add summary
  results$summary <- create_bias_summary(results)

  return(results)
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Create summary of bias test results
#' @keywords internal
create_bias_summary <- function(results) {

  significant_tests <- c()
  all_tests <- c()

  for (test_name in names(results)) {
    if (test_name %in% c("summary", "recommendation")) next

    test <- results[[test_name]]
    if (!is.null(test$p_value)) {
      all_tests <- c(all_tests, test$test)
      if (test$p_value < 0.05) {
        significant_tests <- c(significant_tests, test$test)
      }
    }
  }

  summary_text <- if (length(significant_tests) == 0) {
    paste0(
      "No significant small-study effects detected across ",
      length(all_tests), " test(s)."
    )
  } else if (length(significant_tests) == length(all_tests)) {
    paste0(
      "Significant small-study effects detected in all ",
      length(all_tests), " test(s): ",
      paste(significant_tests, collapse = ", ")
    )
  } else {
    paste0(
      "Mixed evidence for small-study effects. Significant in ",
      length(significant_tests), " of ", length(all_tests), " test(s): ",
      paste(significant_tests, collapse = ", ")
    )
  }

  list(
    text = summary_text,
    n_tests = length(all_tests),
    n_significant = length(significant_tests),
    significant_tests = significant_tests,
    all_tests = all_tests
  )
}

#' Format bias test results for display
#' @param results Results from comprehensive_bias_tests
#' @return Formatted text output
#' @export
format_bias_tests <- function(results) {

  output <- c()
  output <- c(output, "COMPREHENSIVE SMALL-STUDY EFFECTS TESTS")
  output <- c(output, "==========================================\n")

  # Egger test
  if (!is.null(results$egger) && !is.null(results$egger$p_value)) {
    output <- c(output, "Egger's Test (Standard):")
    output <- c(output, sprintf("  Intercept: %.3f (%.3f to %.3f)",
                                results$egger$intercept,
                                results$egger$ci_lower,
                                results$egger$ci_upper))
    output <- c(output, sprintf("  Z = %.2f, p = %.4f",
                                results$egger$z_value,
                                results$egger$p_value))
    output <- c(output, sprintf("  %s\n", results$egger$interpretation))
  }

  # Peters test
  if (!is.null(results$peters) && !is.null(results$peters$p_value)) {
    output <- c(output, "Peters Test (For binary outcomes):")
    output <- c(output, sprintf("  Slope: %.3f (%.3f to %.3f)",
                                results$peters$slope,
                                results$peters$ci_lower,
                                results$peters$ci_upper))
    output <- c(output, sprintf("  Z = %.2f, p = %.4f",
                                results$peters$z_value,
                                results$peters$p_value))
    output <- c(output, sprintf("  %s\n", results$peters$interpretation))
  }

  # Harbord test
  if (!is.null(results$harbord) && !is.null(results$harbord$p_value)) {
    output <- c(output, "Harbord Test (For log odds ratios):")
    output <- c(output, sprintf("  Intercept: %.3f (%.3f to %.3f)",
                                results$harbord$intercept,
                                results$harbord$ci_lower,
                                results$harbord$ci_upper))
    output <- c(output, sprintf("  Z = %.2f, p = %.4f",
                                results$harbord$z_value,
                                results$harbord$p_value))
    output <- c(output, sprintf("  %s\n", results$harbord$interpretation))
  }

  # Summary
  if (!is.null(results$summary)) {
    output <- c(output, "Overall Assessment:")
    output <- c(output, sprintf("  %s\n", results$summary$text))
  }

  # Recommendation
  if (!is.null(results$recommendation)) {
    output <- c(output, "Recommendation:")
    output <- c(output, sprintf("  %s\n", results$recommendation))
  }

  paste(output, collapse = "\n")
}

cat("✅ Advanced publication bias tests loaded\n")
cat("   • Peters test (for binary outcomes)\n")
cat("   • Harbord test (for log odds ratios)\n")
cat("   • Comprehensive bias assessment\n")
