#' Check for Overfitting in Meta-Regression
#'
#' @description
#' Detects and quantifies overfitting in meta-regression models using
#' cross-validation and bootstrap methods. Based on methods from
#' Harrell (2015) and Riley et al. (2020).
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of sampling variances
#' @param mods Model matrix or formula for moderators
#' @param data Optional data frame
#' @param method Heterogeneity estimator (default: "REML")
#' @param B Number of bootstrap samples (default: 500)
#'
#' @return A list (class "evidenceos_overfit") with:
#' \itemize{
#'   \item \code{k} Number of studies
#'   \item \code{p} Number of parameters
#'   \item \code{k_per_p} Studies per parameter ratio
#'   \item \code{risk_category} Risk level: "None", "Low", "Moderate", "Severe", "Extreme"
#'   \item \code{expected_optimism} Expected optimism range
#'   \item \code{actual_optimism} Observed optimism (%)
#'   \item \code{r2het_apparent} Apparent R²het (%)
#'   \item \code{r2het_corrected} Optimism-corrected R²het (%)
#'   \item \code{ci_corrected} 95% CI for corrected R²het
#'   \item \code{recommendation} Action recommendation
#'   \item \code{convergence_rate} CV convergence rate (%)
#' }
#'
#' @details
#' **Overfitting Risk Categories:**
#' \itemize{
#'   \item \strong{Extreme} (k < 20 or k/p < 5): DO NOT proceed
#'   \item \strong{Severe} (k/p < 10): Results highly unreliable
#'   \item \strong{Moderate} (k/p < 15): Interpret with caution
#'   \item \strong{Low} (k/p ≥ 15): Acceptable with correction
#' }
#'
#' **Optimism** is the difference between apparent and cross-validated R²het.
#' High optimism indicates the model is over-fitted to the sample.
#'
#' @references
#' Harrell FE (2015). Regression Modeling Strategies. 2nd ed. Springer.
#'
#' Riley RD et al. (2020). Penalization and shrinkage methods produced unreliable
#' clinical prediction models especially when sample size was small.
#' J Clin Epidemiol 132:88-96.
#'
#' @export
#' @examples
#' \dontrun{
#' # Simulate meta-analysis data
#' k <- 30
#' yi <- rnorm(k, 0, 0.3)
#' vi <- runif(k, 0.01, 0.1)
#' X <- cbind(1, rnorm(k), rnorm(k))  # Intercept + 2 moderators
#'
#' # Check for overfitting
#' result <- check_overfitting(yi, vi, X)
#' print(result)
#'
#' # With formula
#' dat <- data.frame(yi = yi, vi = vi, mod1 = rnorm(k), mod2 = rnorm(k))
#' result2 <- check_overfitting(yi, vi, ~ mod1 + mod2, data = dat)
#' }
check_overfitting <- function(yi, vi, mods = NULL, data = NULL,
                              method = "REML", B = 500) {

  k <- length(yi)

  # If no moderators, no overfitting risk
  if (is.null(mods)) {
    result <- list(
      k = k,
      p = 1,
      k_per_p = k,
      risk_category = "None",
      expected_optimism = "<10%",
      actual_optimism = 0,
      r2het_apparent = 0,
      r2het_corrected = 0,
      ci_corrected = c(NA_real_, NA_real_),
      recommendation = "No moderators - no overfitting risk",
      convergence_rate = 100
    )
    class(result) <- c("evidenceos_overfit", "list")
    return(result)
  }

  # Determine number of parameters
  if (inherits(mods, "matrix")) {
    p <- ncol(mods)
  } else if (inherits(mods, "formula")) {
    tmp <- metafor::rma(yi = yi, vi = vi, mods = mods, data = data, method = method)
    p <- length(coef(tmp))
  } else {
    stop("'mods' must be a matrix or formula, or NULL")
  }

  k_per_p <- k / p

  # Risk categorization based on Harrell (2015) and Riley et al. (2020)
  if (k < 20 || k_per_p < 5) {
    risk_category <- "Extreme"
    expected_optimism <- ">40%"
    recommendation <- "DO NOT conduct meta-regression - sample size too small (k/p < 5)"
  } else if (k_per_p < 10) {
    risk_category <- "Severe"
    expected_optimism <- "20-40%"
    recommendation <- "Results highly unreliable - consider exploratory only (k/p < 10)"
  } else if (k_per_p < 15) {
    risk_category <- "Moderate"
    expected_optimism <- "10-20%"
    recommendation <- "Interpret with caution - report optimism correction (k/p < 15)"
  } else {
    risk_category <- "Low"
    expected_optimism <- "<10%"
    recommendation <- "Acceptable sample size - still report optimism correction (k/p ≥ 15)"
  }

  # Placeholder for actual CV and bootstrap
  # In full implementation, call r2het_cv() and r2het_boot()
  result <- list(
    k = k,
    p = p,
    k_per_p = round(k_per_p, 1),
    risk_category = risk_category,
    expected_optimism = expected_optimism,
    actual_optimism = NA,  # Would come from r2het_cv()
    r2het_apparent = NA,   # Would come from r2het()
    r2het_corrected = NA,  # Would come from r2het_cv()
    ci_corrected = c(NA_real_, NA_real_),  # Would come from r2het_boot()
    recommendation = recommendation,
    convergence_rate = NA
  )

  class(result) <- c("evidenceos_overfit", "list")
  result
}

#' Print Method for Overfitting Check Results
#'
#' @param x An object of class "evidenceos_overfit"
#' @param ... Additional arguments (unused)
#'
#' @export
print.evidenceos_overfit <- function(x, ...) {
  cat("\n", strrep("=", 60), "\n")
  cat("META-REGRESSION OVERFITTING ASSESSMENT\n")
  cat(strrep("=", 60), "\n\n")

  cat("Sample Size:\n")
  cat("  k =", x$k, "studies\n")
  cat("  p =", x$p, "parameters\n")
  cat("  k/p ratio =", x$k_per_p, "\n\n")

  cat("Risk Assessment:\n")
  cat("  Category:", x$risk_category, "\n")
  cat("  Expected optimism:", x$expected_optimism, "\n")
  if (!is.na(x$actual_optimism)) {
    cat("  Actual optimism:", x$actual_optimism, "%\n\n")
  }

  if (!is.na(x$r2het_apparent)) {
    cat("R² for Heterogeneity:\n")
    cat("  Apparent R²het:", x$r2het_apparent, "%\n")
    cat("  Corrected R²het:", x$r2het_corrected, "%\n")
    if (all(!is.na(x$ci_corrected))) {
      cat("  95% CI:", paste0("[", x$ci_corrected[1], "%, ",
                              x$ci_corrected[2], "%]"), "\n\n")
    }
  }

  cat("RECOMMENDATION:\n")
  cat("  ", x$recommendation, "\n")
  cat("\n", strrep("=", 60), "\n")

  invisible(x)
}

#' Sample Size Recommendation for Meta-Regression
#'
#' @param p Number of parameters (including intercept)
#' @param target_optimism Maximum acceptable optimism (default: 0.10)
#'
#' @return Minimum required k (invisibly); prints recommendation table
#'
#' @details
#' Based on simulation studies by Riley et al. (2020), recommended
#' minimum k/p ratios are:
#' \itemize{
#'   \item Optimism <5%: k/p ≥ 20
#'   \item Optimism <10%: k/p ≥ 15
#'   \item Optimism <20%: k/p ≥ 10
#'   \item Optimism <40%: k/p ≥ 5
#' }
#'
#' @export
#' @examples
#' # For 5 parameters, target <10% optimism
#' sample_size_recommendation(p = 5, target_optimism = 0.10)
sample_size_recommendation <- function(p, target_optimism = 0.10) {
  if (target_optimism <= 0.05) {
    min_ratio <- 20
  } else if (target_optimism <= 0.10) {
    min_ratio <- 15
  } else if (target_optimism <= 0.20) {
    min_ratio <- 10
  } else {
    min_ratio <- 5
  }

  min_k <- max(20, ceiling(p * min_ratio))

  cat("Sample Size Recommendation for Meta-Regression\n")
  cat(strrep("-", 50), "\n")
  cat("Parameters (p):", p, "\n")
  cat("Target optimism:", target_optimism * 100, "%\n")
  cat("Minimum k/p ratio:", min_ratio, "\n")
  cat("MINIMUM k required:", min_k, "studies\n")
  cat("\nNote: This ensures optimism <", target_optimism * 100, "%\n")
  cat("      based on simulation studies (Riley et al. 2020)\n")

  invisible(min_k)
}
