# PET-PEESE Publication Bias Correction
# Precision-Effect Test (PET) and Precision-Effect Estimate with Standard Error (PEESE)
# Following Stanley & Doucouliagos (2014) and modern best practices

library(meta)
library(metafor)

#' PET-PEESE Publication Bias Correction
#'
#' Implements Precision-Effect Test (PET) and Precision-Effect Estimate with
#' Standard Error (PEESE) to detect and correct for publication bias.
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of variances
#' @param sei Vector of standard errors (alternative to vi)
#' @param alpha Significance level for PET test (default: 0.10)
#' @return List with PET and PEESE results
#'
#' @details
#' PET-PEESE is a two-stage procedure:
#'
#' Stage 1 - PET (Precision-Effect Test):
#' - Regress effect size on standard error: yi = β0 + β1*SE
#' - Test if β0 significantly different from zero
#' - If p < alpha: use PEESE; if p >= alpha: use PET estimate
#'
#' Stage 2 - PEESE (Precision-Effect Estimate with Standard Error):
#' - Regress effect size on variance: yi = β0 + β1*SE²
#' - β0 is the bias-corrected estimate
#'
#' Selection rule (Stanley & Doucouliagos 2014):
#' - If PET shows no effect (p >= 0.10): use PET estimate
#' - If PET shows effect (p < 0.10): use PEESE estimate
#'   (PEESE has better properties when true effect exists)
#'
#' Advantages:
#' - Does not assume symmetric funnel plot
#' - Corrects for small-study effects
#' - Easy to implement and interpret
#' - Works with continuous and binary outcomes
#'
#' Limitations:
#' - Assumes linear relationship between effect and precision
#' - May overcorrect with few studies
#' - Sensitive to heterogeneity
#'
#' References:
#' - Stanley & Doucouliagos (2014) J Econ Surveys 28:639-672
#' - Stanley (2017) Res Synth Methods 8:279-293
#' - Carter et al. (2019) Res Synth Methods 10:351-366
#'
#' @export
#' @examples
#' # Simulated data with publication bias
#' set.seed(123)
#' yi <- rnorm(20, mean = 0.3, sd = 0.2)
#' sei <- runif(20, 0.05, 0.3)
#' result <- pet_peese(yi, sei = sei)
#' print(result)
pet_peese <- function(yi, vi = NULL, sei = NULL, alpha = 0.10) {

  # Input validation
  if (is.null(vi) && is.null(sei)) {
    stop("Either vi (variance) or sei (standard error) must be provided")
  }

  if (!is.null(vi) && !is.null(sei)) {
    warning("Both vi and sei provided. Using sei.")
    vi <- sei^2
  }

  if (is.null(vi)) {
    vi <- sei^2
  }

  if (is.null(sei)) {
    sei <- sqrt(vi)
  }

  n <- length(yi)

  if (n < 10) {
    warning("PET-PEESE requires at least 10 studies for reliable results. Proceeding with caution.")
  }

  # 1. PET: Regress yi on SE
  # Model: yi = β0 + β1*SE + εi
  pet_model <- lm(yi ~ sei)
  pet_intercept <- coef(pet_model)[1]
  pet_se <- summary(pet_model)$coefficients[1, 2]
  pet_t <- summary(pet_model)$coefficients[1, 3]
  pet_p <- summary(pet_model)$coefficients[1, 4]
  pet_ci_lower <- pet_intercept - 1.96 * pet_se
  pet_ci_upper <- pet_intercept + 1.96 * pet_se

  # 2. PEESE: Regress yi on variance (SE²)
  # Model: yi = β0 + β1*SE² + εi
  peese_model <- lm(yi ~ vi)
  peese_intercept <- coef(peese_model)[1]
  peese_se <- summary(peese_model)$coefficients[1, 2]
  peese_t <- summary(peese_model)$coefficients[1, 3]
  peese_p <- summary(peese_model)$coefficients[1, 4]
  peese_ci_lower <- peese_intercept - 1.96 * peese_se
  peese_ci_upper <- peese_intercept + 1.96 * peese_se

  # 3. Selection rule: Choose PET or PEESE
  # If PET not significant (p >= alpha), use PET
  # If PET significant (p < alpha), use PEESE
  if (pet_p >= alpha) {
    recommended_estimate <- pet_intercept
    recommended_se <- pet_se
    recommended_ci_lower <- pet_ci_lower
    recommended_ci_upper <- pet_ci_upper
    recommendation <- "PET"
    reason <- paste0("PET p-value (", round(pet_p, 4), ") >= ", alpha, ", indicating no evidence of genuine effect")
  } else {
    recommended_estimate <- peese_intercept
    recommended_se <- peese_se
    recommended_ci_lower <- peese_ci_lower
    recommended_ci_upper <- peese_ci_upper
    recommendation <- "PEESE"
    reason <- paste0("PET p-value (", round(pet_p, 4), ") < ", alpha, ", indicating genuine effect exists")
  }

  # 4. Conventional meta-analysis for comparison
  ma_conventional <- metafor::rma(yi = yi, vi = vi, method = "REML")

  # 5. Egger's test for comparison
  egger_model <- lm(yi/sei ~ I(1/sei))
  egger_intercept <- coef(egger_model)[1]
  egger_p <- summary(egger_model)$coefficients[1, 4]

  # 6. Interpretation
  interpretation <- interpret_petpeese(
    recommended_estimate,
    ma_conventional$beta,
    pet_p,
    peese_p,
    recommendation
  )

  # Compile results
  result <- list(
    # PET results
    pet_estimate = pet_intercept,
    pet_se = pet_se,
    pet_ci_lower = pet_ci_lower,
    pet_ci_upper = pet_ci_upper,
    pet_t = pet_t,
    pet_p = pet_p,

    # PEESE results
    peese_estimate = peese_intercept,
    peese_se = peese_se,
    peese_ci_lower = peese_ci_lower,
    peese_ci_upper = peese_ci_upper,
    peese_t = peese_t,
    peese_p = peese_p,

    # Recommended estimate
    recommended_estimate = recommended_estimate,
    recommended_se = recommended_se,
    recommended_ci_lower = recommended_ci_lower,
    recommended_ci_upper = recommended_ci_upper,
    recommendation = recommendation,
    reason = reason,

    # Comparison with conventional MA
    conventional_estimate = ma_conventional$beta[1],
    conventional_se = ma_conventional$se,
    conventional_ci_lower = ma_conventional$ci.lb,
    conventional_ci_upper = ma_conventional$ci.ub,
    conventional_tau2 = ma_conventional$tau2,

    # Additional tests
    egger_intercept = egger_intercept,
    egger_p = egger_p,

    # Study characteristics
    n_studies = n,
    alpha = alpha,

    # Models for further inspection
    pet_model = pet_model,
    peese_model = peese_model,

    # Interpretation
    interpretation = interpretation
  )

  class(result) <- "petpeese"
  return(result)
}


#' Interpret PET-PEESE Results
#'
#' Provides interpretation of PET-PEESE analysis
#'
#' @param corrected_estimate Bias-corrected estimate
#' @param conventional_estimate Conventional meta-analysis estimate
#' @param pet_p PET p-value
#' @param peese_p PEESE p-value
#' @param recommendation Which method was selected
#' @return Character string with interpretation
#' @keywords internal
interpret_petpeese <- function(corrected_estimate, conventional_estimate,
                               pet_p, peese_p, recommendation) {

  # Magnitude of correction
  difference <- conventional_estimate - corrected_estimate
  pct_change <- if (conventional_estimate != 0) {
    abs(difference / conventional_estimate) * 100
  } else {
    NA
  }

  interpretation <- paste0(
    "PET-PEESE Analysis:\n",
    "- Recommendation: Use ", recommendation, " estimate\n",
    "- Conventional estimate: ", round(conventional_estimate, 3), "\n",
    "- Bias-corrected estimate: ", round(corrected_estimate, 3), "\n"
  )

  if (!is.na(pct_change)) {
    interpretation <- paste0(
      interpretation,
      "- Correction magnitude: ", round(pct_change, 1), "%\n"
    )
  }

  if (recommendation == "PET" && pet_p >= 0.10) {
    interpretation <- paste0(
      interpretation,
      "- Conclusion: No evidence of genuine effect after correcting for publication bias"
    )
  } else if (recommendation == "PEESE") {
    if (abs(corrected_estimate) < abs(conventional_estimate)) {
      interpretation <- paste0(
        interpretation,
        "- Conclusion: Evidence of publication bias. True effect likely smaller than conventional estimate."
      )
    } else {
      interpretation <- paste0(
        interpretation,
        "- Conclusion: Genuine effect detected, but check for heterogeneity and other biases."
      )
    }
  }

  return(interpretation)
}


#' Funnel Plot with PET-PEESE Lines
#'
#' Creates funnel plot with PET and PEESE regression lines
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of variances
#' @param sei Vector of standard errors
#' @param ... Additional arguments passed to funnel plot
#' @export
funnel_petpeese <- function(yi, vi = NULL, sei = NULL, ...) {

  if (is.null(vi) && is.null(sei)) {
    stop("Either vi or sei must be provided")
  }

  if (is.null(sei)) {
    sei <- sqrt(vi)
  }

  # Run PET-PEESE
  result <- pet_peese(yi, sei = sei)

  # Create funnel plot
  plot(sei, yi,
       xlab = "Standard Error",
       ylab = "Effect Size",
       main = "Funnel Plot with PET-PEESE",
       pch = 19,
       col = "darkgray",
       ...)

  # Add PET line (intercept from regression on SE)
  pet_slope <- coef(result$pet_model)[2]
  abline(a = result$pet_estimate, b = pet_slope, col = "blue", lwd = 2, lty = 2)

  # Add PEESE line (approximate)
  # For visualization, show trend
  sei_range <- range(sei)
  sei_seq <- seq(min(sei_range), max(sei_range), length.out = 100)
  vi_seq <- sei_seq^2
  peese_slope <- coef(result$peese_model)[2]
  peese_line <- result$peese_estimate + peese_slope * vi_seq
  lines(sei_seq, peese_line, col = "red", lwd = 2)

  # Add legend
  legend("topright",
         legend = c(paste("PET estimate:", round(result$pet_estimate, 3)),
                   paste("PEESE estimate:", round(result$peese_estimate, 3)),
                   paste("Recommended:", result$recommendation)),
         col = c("blue", "red", "black"),
         lty = c(2, 1, 0),
         lwd = c(2, 2, 0),
         bty = "n")

  invisible(result)
}


#' Print Method for PET-PEESE Results
#'
#' @param x petpeese object
#' @param ... Additional arguments
#' @export
print.petpeese <- function(x, ...) {
  cat("\nPET-PEESE Publication Bias Analysis\n")
  cat("======================================\n\n")

  cat("Number of studies:", x$n_studies, "\n")
  cat("Selection alpha:", x$alpha, "\n\n")

  cat("PET (Precision-Effect Test)\n")
  cat("---------------------------\n")
  cat("Estimate:", round(x$pet_estimate, 3),
      "(95% CI:", round(x$pet_ci_lower, 3), "to", round(x$pet_ci_upper, 3), ")\n")
  cat("t-statistic:", round(x$pet_t, 3), "\n")
  cat("p-value:", format.pval(x$pet_p, digits = 4), "\n\n")

  cat("PEESE (Precision-Effect Estimate with SE)\n")
  cat("------------------------------------------\n")
  cat("Estimate:", round(x$peese_estimate, 3),
      "(95% CI:", round(x$peese_ci_lower, 3), "to", round(x$peese_ci_upper, 3), ")\n")
  cat("t-statistic:", round(x$peese_t, 3), "\n")
  cat("p-value:", format.pval(x$peese_p, digits = 4), "\n\n")

  cat("RECOMMENDATION\n")
  cat("--------------\n")
  cat("Use:", x$recommendation, "estimate =", round(x$recommended_estimate, 3), "\n")
  cat("Reason:", x$reason, "\n\n")

  cat("Comparison with Conventional Meta-Analysis\n")
  cat("-------------------------------------------\n")
  cat("Conventional estimate:", round(x$conventional_estimate, 3),
      "(95% CI:", round(x$conventional_ci_lower, 3), "to",
      round(x$conventional_ci_upper, 3), ")\n")
  cat("Bias-corrected estimate:", round(x$recommended_estimate, 3),
      "(95% CI:", round(x$recommended_ci_lower, 3), "to",
      round(x$recommended_ci_upper, 3), ")\n")

  difference <- x$conventional_estimate - x$recommended_estimate
  pct_change <- if (x$conventional_estimate != 0) {
    abs(difference / x$conventional_estimate) * 100
  } else NA

  if (!is.na(pct_change)) {
    cat("Change:", round(pct_change, 1), "%\n\n")
  }

  cat("Egger's Test\n")
  cat("------------\n")
  cat("Intercept:", round(x$egger_intercept, 3), "\n")
  cat("p-value:", format.pval(x$egger_p, digits = 4), "\n\n")

  cat(x$interpretation, "\n")

  invisible(x)
}


#' Sensitivity Analysis for PET-PEESE
#'
#' Tests robustness of PET-PEESE results to alpha choice
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of variances
#' @param sei Vector of standard errors
#' @param alphas Vector of alpha values to test (default: c(0.05, 0.10, 0.15))
#' @return Data frame with results for each alpha
#' @export
petpeese_sensitivity <- function(yi, vi = NULL, sei = NULL,
                                  alphas = c(0.05, 0.10, 0.15)) {

  results <- lapply(alphas, function(a) {
    res <- pet_peese(yi, vi = vi, sei = sei, alpha = a)
    data.frame(
      alpha = a,
      recommendation = res$recommendation,
      estimate = res$recommended_estimate,
      se = res$recommended_se,
      ci_lower = res$recommended_ci_lower,
      ci_upper = res$recommended_ci_upper,
      pet_p = res$pet_p,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}


# Export documentation
#' @name pet_peese
#' @title PET-PEESE Publication Bias Correction
#' @description
#' Implements Precision-Effect Test (PET) and Precision-Effect Estimate with
#' Standard Error (PEESE) for detecting and correcting publication bias.
#'
#' @details
#' PET-PEESE is an alternative to trim-and-fill and other funnel plot methods.
#' It uses meta-regression to estimate the true effect after accounting for
#' small-study effects (publication bias).
#'
#' Key advantages:
#' \itemize{
#'   \item No assumption of funnel plot symmetry
#'   \item Handles heterogeneity better than Egger's test
#'   \item Provides bias-corrected effect estimate
#'   \item Automatic selection between PET and PEESE
#' }
#'
#' Recommended use:
#' \itemize{
#'   \item At least 10 studies
#'   \item Supplement with other bias detection methods
#'   \item Consider heterogeneity sources
#'   \item Check for influential studies
#' }
#'
#' @references
#' Stanley TD, Doucouliagos H (2014). Meta-regression approximations to reduce
#' publication selection bias. Research Synthesis Methods, 5:60-78.
#'
#' Stanley TD (2017). Limitations of PET-PEESE and other meta-analysis methods.
#' Social Psychological and Personality Science, 8:581-591.
#'
#' @seealso \code{\link[metafor]{regtest}}, \code{\link[meta]{metabias}}
NULL
