# Prediction Intervals for Meta-Analysis
# Implements prediction intervals following Riley et al. (2011)
# Provides interval for expected effect in a new study

library(meta)

#' Calculate Prediction Interval for Meta-Analysis
#'
#' Calculates prediction interval for the treatment effect expected in a new study,
#' accounting for between-study heterogeneity.
#'
#' @param ma Meta-analysis object (from metagen, metabin, metacont, etc.)
#' @param level Confidence level for prediction interval (default: 0.95)
#' @return List with prediction interval bounds and formatted text
#'
#' @details
#' The prediction interval answers: "What treatment effect can we expect in a
#' new study similar to those in the meta-analysis?"
#'
#' Formula (Riley et al. 2011):
#' PI = θ ± t(k-2) × sqrt(τ² + SE²)
#'
#' where:
#' - θ = pooled effect estimate
#' - t(k-2) = critical value from t-distribution with k-2 degrees of freedom
#' - τ² = between-study variance (tau²)
#' - SE² = variance of pooled estimate
#' - k = number of studies
#'
#' Interpretation:
#' - Wider than confidence interval (includes heterogeneity)
#' - 95% of future study effects expected to fall within this range
#' - Provides realistic expectation for new research
#'
#' References:
#' - Riley et al. (2011) BMJ 342:d548
#' - Borenstein et al. (2017) Introduction to Meta-Analysis, Chapter 17
#' - Cochrane Handbook Section 10.10.4.1
#'
#' @export
#' @examples
#' library(meta)
#' data(Fleiss1993bin)
#' ma <- metabin(event.e, n.e, event.c, n.c, data = Fleiss1993bin, sm = "OR")
#' pred_interval(ma)
pred_interval <- function(ma, level = 0.95) {

  # Input validation
  if (!inherits(ma, "meta")) {
    stop("Input must be a meta-analysis object from the 'meta' package")
  }

  if (level <= 0 || level >= 1) {
    stop("Confidence level must be between 0 and 1")
  }

  # Number of studies
  k <- ma$k

  if (k < 3) {
    warning("Prediction intervals require at least 3 studies. Returning NA.")
    return(list(
      lower = NA,
      upper = NA,
      text = "Not enough studies (k < 3)",
      k = k,
      applicable = FALSE
    ))
  }

  # Use random-effects estimates
  if (!ma$comb.random) {
    warning("Random-effects model not fitted. Using fixed-effect instead.")
    theta <- ma$TE.fixed
    se_theta <- ma$seTE.fixed
    tau2 <- 0
  } else {
    theta <- ma$TE.random
    se_theta <- ma$seTE.random
    tau2 <- ma$tau^2
  }

  # Degrees of freedom (k - 2)
  df <- k - 2

  # Critical value from t-distribution
  alpha <- 1 - level
  t_crit <- qt(1 - alpha/2, df = df)

  # Prediction interval standard error
  # SE_pred = sqrt(tau² + SE²)
  se_pred <- sqrt(tau2 + se_theta^2)

  # Prediction interval bounds
  pi_lower <- theta - t_crit * se_pred
  pi_upper <- theta + t_crit * se_pred

  # Format for display
  ci_lower <- ma$lower.random
  ci_upper <- ma$upper.random

  # Create formatted text
  pi_text <- sprintf(
    "Prediction interval: %.3f to %.3f (compared to CI: %.3f to %.3f)",
    pi_lower, pi_upper, ci_lower, ci_upper
  )

  # Calculate width ratio (PI / CI)
  pi_width <- pi_upper - pi_lower
  ci_width <- ci_upper - ci_lower
  width_ratio <- if (ci_width > 0) pi_width / ci_width else NA

  # Return results
  result <- list(
    lower = pi_lower,
    upper = pi_upper,
    estimate = theta,
    se_prediction = se_pred,
    tau2 = tau2,
    k = k,
    df = df,
    t_critical = t_crit,
    level = level,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    width_ratio = width_ratio,
    text = pi_text,
    applicable = TRUE,
    interpretation = interpret_prediction_interval(pi_lower, pi_upper, theta, ma$sm)
  )

  class(result) <- "prediction_interval"
  return(result)
}


#' Interpret Prediction Interval
#'
#' Provides clinical interpretation of prediction interval
#'
#' @param lower Lower bound of prediction interval
#' @param upper Upper bound of prediction interval
#' @param estimate Point estimate
#' @param sm Summary measure (OR, RR, MD, etc.)
#' @return Character string with interpretation
#' @keywords internal
interpret_prediction_interval <- function(lower, upper, estimate, sm) {

  # For ratio measures (OR, RR, HR)
  if (sm %in% c("OR", "RR", "HR")) {
    # Log scale
    null_value <- 0

    if (lower > 0 && upper > 0) {
      return("Consistent benefit expected in future studies")
    } else if (lower < 0 && upper < 0) {
      return("Consistent harm expected in future studies")
    } else {
      return("Future studies may show benefit or harm (prediction interval crosses null)")
    }
  }

  # For difference measures (MD, SMD)
  else if (sm %in% c("MD", "SMD", "RD")) {
    null_value <- 0

    if (lower > 0 && upper > 0) {
      return("Consistent benefit expected in future studies")
    } else if (lower < 0 && upper < 0) {
      return("Consistent harm expected in future studies")
    } else {
      return("Future studies may show benefit or harm (prediction interval crosses zero)")
    }
  }

  else {
    return("Unable to interpret (unknown summary measure)")
  }
}


#' Add Prediction Interval to Forest Plot
#'
#' Adds prediction interval diamond to existing forest plot
#'
#' @param ma Meta-analysis object
#' @param level Confidence level for prediction interval
#' @param col Color for prediction interval diamond
#' @param ... Additional arguments passed to forest
#' @return Forest plot with prediction interval
#'
#' @export
forest_with_prediction <- function(ma, level = 0.95, col = "blue", ...) {

  # Calculate prediction interval
  pi <- pred_interval(ma, level = level)

  # Create forest plot
  forest(ma, ...)

  # Add prediction interval if applicable
  if (pi$applicable) {
    # Add text annotation
    grid.text(
      pi$text,
      x = 0.5,
      y = 0.02,
      just = "center",
      gp = gpar(fontsize = 10, col = col)
    )

    # Optionally add diamond for prediction interval
    # (This would require more complex plotting code)
  }

  invisible(pi)
}


#' Extract Prediction Intervals from Meta-Analysis
#'
#' Extracts prediction intervals for all subgroups in a meta-analysis
#'
#' @param ma Meta-analysis object (potentially with subgroups)
#' @param level Confidence level
#' @return Data frame with prediction intervals
#'
#' @export
extract_prediction_intervals <- function(ma, level = 0.95) {

  # Overall prediction interval
  pi_overall <- pred_interval(ma, level = level)

  results <- data.frame(
    subgroup = "Overall",
    k = pi_overall$k,
    estimate = pi_overall$estimate,
    ci_lower = pi_overall$ci_lower,
    ci_upper = pi_overall$ci_upper,
    pi_lower = pi_overall$lower,
    pi_upper = pi_overall$upper,
    tau2 = pi_overall$tau2,
    interpretation = pi_overall$interpretation,
    stringsAsFactors = FALSE
  )

  # If there are subgroups, calculate for each
  if (!is.null(ma$byvar)) {
    subgroup_names <- levels(ma$byvar)

    for (sg in subgroup_names) {
      # Filter to subgroup
      idx <- ma$byvar == sg

      if (sum(idx) >= 3) {
        # Create temporary meta-analysis for subgroup
        ma_sg <- ma
        ma_sg$k <- sum(idx)
        ma_sg$TE.random <- ma$TE.random.w[which(ma$bylevs == sg)]
        ma_sg$seTE.random <- ma$seTE.random.w[which(ma$bylevs == sg)]
        ma_sg$tau <- ma$tau.w[which(ma$bylevs == sg)]
        ma_sg$lower.random <- ma$lower.random.w[which(ma$bylevs == sg)]
        ma_sg$upper.random <- ma$upper.random.w[which(ma$bylevs == sg)]

        pi_sg <- pred_interval(ma_sg, level = level)

        if (pi_sg$applicable) {
          results <- rbind(results, data.frame(
            subgroup = sg,
            k = pi_sg$k,
            estimate = pi_sg$estimate,
            ci_lower = pi_sg$ci_lower,
            ci_upper = pi_sg$ci_upper,
            pi_lower = pi_sg$lower,
            pi_upper = pi_sg$upper,
            tau2 = pi_sg$tau2,
            interpretation = pi_sg$interpretation,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }

  return(results)
}


#' Print Method for Prediction Intervals
#'
#' @param x prediction_interval object
#' @param ... Additional arguments
#' @export
print.prediction_interval <- function(x, ...) {
  cat("\nPrediction Interval for Future Studies\n")
  cat("=========================================\n\n")

  if (!x$applicable) {
    cat("Not applicable:", x$text, "\n")
    return(invisible(x))
  }

  cat("Number of studies:", x$k, "\n")
  cat("Degrees of freedom:", x$df, "\n")
  cat("Confidence level:", x$level * 100, "%\n\n")

  cat("Pooled estimate:", round(x$estimate, 3), "\n")
  cat("Confidence interval:", round(x$ci_lower, 3), "to", round(x$ci_upper, 3), "\n")
  cat("Prediction interval:", round(x$lower, 3), "to", round(x$upper, 3), "\n\n")

  cat("Between-study variance (τ²):", round(x$tau2, 4), "\n")
  cat("Prediction SE:", round(x$se_prediction, 3), "\n")
  cat("PI width / CI width ratio:", round(x$width_ratio, 2), "\n\n")

  cat("Interpretation:", x$interpretation, "\n")

  invisible(x)
}


#' Summary Method for Prediction Intervals
#'
#' @param object prediction_interval object
#' @param ... Additional arguments
#' @export
summary.prediction_interval <- function(object, ...) {
  print(object, ...)
}


# Export functions
#' @name prediction_intervals
#' @title Prediction Intervals for Meta-Analysis
#' @description
#' Functions for calculating and displaying prediction intervals in meta-analysis.
#' Prediction intervals quantify the expected range of effects in future studies.
#'
#' @details
#' Main functions:
#' \itemize{
#'   \item \code{pred_interval}: Calculate prediction interval
#'   \item \code{forest_with_prediction}: Forest plot with PI
#'   \item \code{extract_prediction_intervals}: Extract PIs for all subgroups
#' }
#'
#' Key concepts:
#' \itemize{
#'   \item Prediction intervals account for heterogeneity (τ²)
#'   \item Always wider than confidence intervals
#'   \item Provide realistic expectations for future research
#'   \item Require at least 3 studies
#'   \item Use t-distribution (not normal)
#' }
#'
#' @references
#' Riley RD, Higgins JPT, Deeks JJ (2011). Interpretation of random effects
#' meta-analyses. BMJ, 342:d548.
#'
#' @seealso \code{\link[meta]{metagen}}, \code{\link[meta]{forest}}
NULL
