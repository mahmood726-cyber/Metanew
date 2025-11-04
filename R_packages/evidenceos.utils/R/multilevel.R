#' Three-Level Meta-Analysis Utilities
#'
#' @description
#' Functions for conducting three-level (multilevel) meta-analysis where
#' effects are nested within studies, which are nested within reviews/analyses.
#' Extracted from MLM501 package by Mahmood Arai.
#'
#' **When to Use Three-Level Meta-Analysis:**
#' - Multiple effect sizes per study (e.g., multiple outcomes, time points)
#' - Meta-analysis of meta-analyses
#' - Dependent effect sizes within studies
#' - Clustered data structures
#'
#' **Model Structure:**
#' Level 1: Sampling variance (vi)
#' Level 2: Within-study heterogeneity (between effects in same study)
#' Level 3: Between-study heterogeneity (between studies)
#'
#' @references
#' Van den Noortgate et al. (2013). Three-level meta-analysis of dependent effect sizes.
#' Cheung (2014). Modeling dependent effect sizes with three-level meta-analyses.
#'
#' @name multilevel
NULL

#' Fit Three-Level Meta-Analysis Model
#'
#' @description
#' Fits a three-level random-effects meta-analysis model using metafor::rma.mv()
#' with nested random effects for study_id and a higher grouping (e.g., review_id).
#'
#' @param yi Vector or formula for effect sizes
#' @param vi Vector or formula for sampling variances (or V for variance-covariance matrix)
#' @param data Data frame containing the variables
#' @param study_id Variable name (string) for study identifier (Level 2)
#' @param cluster_id Variable name (string) for cluster identifier (Level 3, e.g., review_id, analysis_id)
#' @param method Heterogeneity estimator (default: "REML")
#' @param robust Logical: use cluster-robust standard errors (default: TRUE)
#' @param club_vcov If robust=TRUE, vcov method for clubSandwich (default: "CR2")
#'
#' @return List with:
#' \itemize{
#'   \item \code{fit} - metafor rma.mv object
#'   \item \code{robust_test} - cluster-robust tests (if robust=TRUE)
#'   \item \code{sigma2_level2} - Within-study variance component
#'   \item \code{sigma2_level3} - Between-study variance component
#'   \item \code{I2_level2} - Percentage of variance at Level 2
#'   \item \code{I2_level3} - Percentage of variance at Level 3
#' }
#'
#' @details
#' **Random Effects Structure:**
#' The model includes two random effects:
#' - ~1 | cluster_id/study_id (nested structure for studies within clusters)
#' - ~1 | unique_effect_id (effect-level random effect if needed)
#'
#' **Cluster-Robust Inference:**
#' When robust=TRUE, uses clubSandwich::coef_test() with CR2 variance estimator
#' to account for clustering and small-sample bias.
#'
#' @export
#' @examples
#' \dontrun{
#' # Simulate three-level data
#' dat <- data.frame(
#'   review_id = rep(1:5, each=20),
#'   study_id = rep(1:20, 5),
#'   yi = rnorm(100, 0.3, 0.5),
#'   vi = runif(100, 0.01, 0.2)
#' )
#'
#' # Fit three-level model
#' res <- fit_threelevel_meta(
#'   yi = yi, vi = vi, data = dat,
#'   study_id = "study_id", cluster_id = "review_id"
#' )
#'
#' # Check variance components
#' cat("Level 2 I²:", res$I2_level2, "%\n")
#' cat("Level 3 I²:", res$I2_level3, "%\n")
#'
#' # View robust inference
#' print(res$robust_test)
#' }
fit_threelevel_meta <- function(yi, vi, data, study_id, cluster_id,
                                method = "REML", robust = TRUE,
                                club_vcov = "CR2") {

  if (!requireNamespace("metafor", quietly = TRUE)) {
    stop("Package 'metafor' required but not installed. Install with: install.packages('metafor')")
  }

  # Convert column names to formulas if character
  if (is.character(yi)) yi <- as.formula(paste("~", yi))
  if (is.character(vi)) vi <- as.formula(paste("~", vi))

  # Create nested grouping variable
  data$nested_group <- interaction(data[[cluster_id]], data[[study_id]])

  # Fit three-level model
  # Random structure: effects nested in studies, studies nested in clusters
  fit <- metafor::rma.mv(
    yi = yi,
    V = vi,
    random = list(
      ~ 1 | data[[cluster_id]] / data[[study_id]],
      ~ 1 | nested_group
    ),
    data = data,
    method = method
  )

  # Extract variance components
  sigma2_level3 <- fit$sigma2[1]  # Between-study variance
  sigma2_level2 <- fit$sigma2[2]  # Within-study variance

  # Calculate I² for each level
  total_var <- sum(fit$sigma2) + mean(data[[all.vars(vi)[1]]], na.rm = TRUE)
  I2_level2 <- (sigma2_level2 / total_var) * 100
  I2_level3 <- (sigma2_level3 / total_var) * 100

  result <- list(
    fit = fit,
    sigma2_level2 = sigma2_level2,
    sigma2_level3 = sigma2_level3,
    I2_level2 = I2_level2,
    I2_level3 = I2_level3,
    robust_test = NULL
  )

  # Cluster-robust inference if requested
  if (robust) {
    if (!requireNamespace("clubSandwich", quietly = TRUE)) {
      warning("Package 'clubSandwich' not installed. Skipping robust inference.")
    } else {
      result$robust_test <- clubSandwich::coef_test(
        fit,
        vcov = club_vcov,
        cluster = data[[cluster_id]]
      )
    }
  }

  class(result) <- c("threelevel_meta", "list")
  result
}

#' Select Coherent Cohort for Analysis
#'
#' @description
#' Filters a dataset to a specific outcome type and effect measure,
#' removing rows with missing or invalid data. Useful for preparing
#' data for multilevel meta-analysis.
#'
#' @param df Data frame with meta-analysis effects
#' @param outcome Character vector of outcome types to include (e.g., "DICH", "CONT", "GENSUM")
#' @param measure Character vector of effect measures (e.g., "logOR", "MD", "SMD", "GIV")
#' @param TE_col Name of effect size column (default: "TE")
#' @param seTE_col Name of standard error column (default: "seTE")
#' @param drop_na Logical: drop rows with NA or non-finite TE/seTE (default: TRUE)
#'
#' @return Filtered data frame
#'
#' @export
#' @examples
#' \dontrun{
#' # Load effects data
#' df <- read.csv("meta_effects.csv")
#'
#' # Get cohort of dichotomous outcomes with log odds ratios
#' cohort_or <- get_meta_cohort(
#'   df, outcome = "DICH", measure = "logOR"
#' )
#'
#' # Get cohort of continuous outcomes with mean differences
#' cohort_md <- get_meta_cohort(
#'   df, outcome = c("CONT", "GENSUM"), measure = c("MD", "SMD")
#' )
#' }
get_meta_cohort <- function(df, outcome, measure,
                            TE_col = "TE", seTE_col = "seTE",
                            drop_na = TRUE) {

  stopifnot(is.data.frame(df))

  # Filter by outcome type and measure
  if ("outcome_type" %in% names(df)) {
    df <- df[df$outcome_type %in% outcome, , drop = FALSE]
  }
  if ("measure" %in% names(df)) {
    df <- df[df$measure %in% measure, , drop = FALSE]
  }

  # Drop missing/invalid data if requested
  if (drop_na && TE_col %in% names(df) && seTE_col %in% names(df)) {
    df <- df[is.finite(df[[TE_col]]) & is.finite(df[[seTE_col]]) & df[[seTE_col]] > 0, , drop = FALSE]
  }

  df
}

#' Cap Extreme Values
#'
#' @description
#' Caps extreme effect sizes at a percentile threshold to reduce
#' influence of outliers. Common in meta-analysis of large datasets.
#'
#' @param x Numeric vector
#' @param upper_percentile Upper percentile to cap at (default: 0.99)
#' @param lower_percentile Lower percentile to cap at (default: 0.01)
#' @param min_cap Minimum cap value (default: 10)
#'
#' @return Numeric vector with capped values
#'
#' @export
#' @examples
#' \dontrun{
#' yi <- c(rnorm(100, 0, 1), 10, -15)  # Outliers
#' yi_capped <- cap_extreme_effects(yi)
#' }
cap_extreme_effects <- function(x, upper_percentile = 0.99,
                                lower_percentile = 0.01, min_cap = 10) {

  q_upper <- stats::quantile(x, upper_percentile, na.rm = TRUE, names = FALSE)
  q_lower <- stats::quantile(x, lower_percentile, na.rm = TRUE, names = FALSE)

  cap_upper <- max(min_cap, q_upper)
  cap_lower <- min(-min_cap, q_lower)

  x[x > cap_upper] <- cap_upper
  x[x < cap_lower] <- cap_lower

  x
}

#' Calculate Intraclass Correlation (ICC)
#'
#' @description
#' Computes ICC for a three-level meta-analysis, showing what proportion
#' of total variance is at each level.
#'
#' @param threelevel_fit Output from fit_threelevel_meta()
#'
#' @return Data frame with variance components and ICCs
#'
#' @export
calculate_icc <- function(threelevel_fit) {

  if (!inherits(threelevel_fit, "threelevel_meta")) {
    stop("Input must be output from fit_threelevel_meta()")
  }

  sigma2_level2 <- threelevel_fit$sigma2_level2
  sigma2_level3 <- threelevel_fit$sigma2_level3

  # Approximate sampling variance (Level 1)
  fit <- threelevel_fit$fit
  mean_vi <- mean(1/fit$weights, na.rm = TRUE)

  total_var <- sigma2_level2 + sigma2_level3 + mean_vi

  data.frame(
    Level = c("Level 1 (Sampling)", "Level 2 (Within-study)", "Level 3 (Between-study)"),
    Variance = c(mean_vi, sigma2_level2, sigma2_level3),
    Percentage = c(
      (mean_vi / total_var) * 100,
      (sigma2_level2 / total_var) * 100,
      (sigma2_level3 / total_var) * 100
    ),
    ICC = c(
      NA,
      sigma2_level2 / (sigma2_level2 + sigma2_level3),
      sigma2_level3 / (sigma2_level2 + sigma2_level3)
    )
  )
}

#' Print Method for Three-Level Meta-Analysis
#'
#' @param x Output from fit_threelevel_meta()
#' @param ... Additional arguments (ignored)
#'
#' @export
print.threelevel_meta <- function(x, ...) {
  cat("=== Three-Level Meta-Analysis ===\n\n")

  cat("Pooled Effect Estimate:\n")
  cat(sprintf("  Estimate: %.4f\n", x$fit$beta[1]))
  cat(sprintf("  SE: %.4f\n", x$fit$se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n", x$fit$ci.lb, x$fit$ci.ub))
  cat(sprintf("  Z: %.4f, p = %.4f\n\n", x$fit$zval, x$fit$pval))

  cat("Variance Components:\n")
  cat(sprintf("  Level 2 (Within-study): %.4f (I² = %.1f%%)\n",
              x$sigma2_level2, x$I2_level2))
  cat(sprintf("  Level 3 (Between-study): %.4f (I² = %.1f%%)\n\n",
              x$sigma2_level3, x$I2_level3))

  if (!is.null(x$robust_test)) {
    cat("Cluster-Robust Inference:\n")
    print(x$robust_test)
  }

  invisible(x)
}
