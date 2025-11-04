#' Validate Meta-Analysis Data
#'
#' @description
#' Comprehensive data validation for meta-analysis and meta-regression.
#' Checks for common errors and enforces minimum quality standards.
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of sampling variances
#' @param X Design matrix for moderators (optional)
#' @param min_k Minimum number of studies required (default: 3)
#' @param min_kp_ratio Minimum k/p ratio for meta-regression (default: 3)
#' @param verbose Print detailed warnings? (default: TRUE)
#'
#' @return TRUE if data is valid, FALSE otherwise (with warnings if verbose=TRUE)
#'
#' @details
#' **Validation Checks:**
#' \itemize{
#'   \item Length matching (yi vs vi)
#'   \item Missing values (NA/NULL)
#'   \item Positive variances (vi > 0)
#'   \item Sufficient sample size (k ≥ min_k)
#'   \item Adequate k/p ratio for meta-regression
#'   \item Constant column detection (in X)
#'   \item Multicollinearity warning (if appropriate)
#' }
#'
#' @export
#' @examples
#' # Valid data
#' yi <- c(0.5, 0.3, 0.8, 0.2)
#' vi <- c(0.01, 0.02, 0.01, 0.03)
#' check_data_validity(yi, vi)  # TRUE
#'
#' # Invalid: mismatched lengths
#' check_data_validity(yi, vi[1:3])  # FALSE with warning
#'
#' # With moderators
#' X <- cbind(1, rnorm(4))
#' check_data_validity(yi, vi, X, min_kp_ratio=5)  # May warn if k/p < 5
check_data_validity <- function(yi, vi, X = NULL, min_k = 3,
                                min_kp_ratio = 3, verbose = TRUE) {

  valid <- TRUE

  # Check 1: Length matching
  if (length(yi) != length(vi)) {
    if (verbose) warning("Length mismatch: length(yi) = ", length(yi),
                        ", length(vi) = ", length(vi))
    return(FALSE)
  }

  k <- length(yi)

  # Check 2: Missing values
  if (any(is.na(yi))) {
    if (verbose) warning("Missing values detected in yi (", sum(is.na(yi)), " NAs)")
    valid <- FALSE
  }

  if (any(is.na(vi))) {
    if (verbose) warning("Missing values detected in vi (", sum(is.na(vi)), " NAs)")
    valid <- FALSE
  }

  # Check 3: Positive variances
  if (any(vi[!is.na(vi)] <= 0)) {
    if (verbose) warning("Non-positive variances detected (",
                        sum(vi[!is.na(vi)] <= 0), " values)")
    valid <- FALSE
  }

  # Check 4: Minimum sample size
  if (k < min_k) {
    if (verbose) warning("Insufficient studies: k = ", k, " < required minimum = ", min_k)
    valid <- FALSE
  }

  # Check 5: Meta-regression checks (if moderators provided)
  if (!is.null(X)) {
    X_clean <- drop_constant(drop_intercept(X))
    p <- if (is.null(X_clean)) 0 else ncol(X_clean)

    if (p > 0) {
      kp_ratio <- k / (p + 1)  # +1 for intercept
      min_k_required <- max(min_k, ceiling(min_kp_ratio * (p + 1)))

      if (k < min_k_required) {
        if (verbose) warning(
          "Insufficient studies for meta-regression: k = ", k,
          ", p = ", p + 1, " (incl. intercept), k/p = ", round(kp_ratio, 2),
          "\nMinimum required: k ≥ ", min_k_required,
          " (k/p ≥ ", min_kp_ratio, ")"
        )
        valid <- FALSE
      } else if (kp_ratio < 10) {
        if (verbose) warning(
          "Low k/p ratio (", round(kp_ratio, 2), " < 10). ",
          "Meta-regression results may be unstable. ",
          "Consider check_overfitting() for detailed assessment."
        )
      }
    }
  }

  return(valid)
}

#' Drop Intercept Column from Design Matrix
#'
#' @param X Design matrix
#' @return Matrix without intercept column
#' @keywords internal
drop_intercept <- function(X) {
  if (is.null(X) || ncol(X) == 0) return(NULL)

  # Check for intercept by name
  name_hits <- which(grepl("(^\\(Intercept\\)$)|(^Intercept$)|(^intrcpt$)",
                           colnames(X), ignore.case = TRUE))
  if (length(name_hits) > 0) {
    return(X[, -name_hits[1], drop = FALSE])
  }

  # Check for constant column of 1s
  const_one <- which(apply(X, 2, function(x) {
    length(unique(x)) == 1 && abs(unique(x) - 1) < 1e-12
  }))

  if (length(const_one) > 0) {
    X <- X[, -const_one[1], drop = FALSE]
  }

  X
}

#' Drop Constant Columns from Design Matrix
#'
#' @param X Design matrix
#' @return Matrix without constant columns
#' @keywords internal
drop_constant <- function(X) {
  if (is.null(X) || ncol(X) == 0) return(NULL)
  X <- as.matrix(X)

  keep <- apply(X, 2, function(x) {
    length(unique(x)) > 1 && var(x, na.rm = TRUE) > 1e-12
  })

  if (!any(keep)) return(NULL)

  X[, keep, drop = FALSE]
}

#' Calculate Weight Diagnostics
#'
#' @description
#' Compute weight dispersion metrics to assess meta-analysis quality
#' and guide cross-validation method selection.
#'
#' @param weights Vector of meta-analysis weights
#'
#' @return List with:
#' \itemize{
#'   \item \code{cv} Coefficient of variation (SD/mean)
#'   \item \code{gini} Gini coefficient (0-1, inequality measure)
#'   \item \code{max_pct} Percentage of total weight from largest study
#'   \item \code{interpretation} Guidance for CV method selection
#' }
#'
#' @details
#' **Coefficient of Variation (CV):**
#' \itemize{
#'   \item CV < 0.3: Low dispersion → Use precision-weighted CV
#'   \item CV 0.3-0.6: Moderate dispersion → Compare both methods
#'   \item CV > 0.6: High dispersion → Consider unweighted CV
#' }
#'
#' **Gini Coefficient:**
#' \itemize{
#'   \item 0 = Perfect equality (all weights equal)
#'   \item 1 = Maximum inequality (one study dominates)
#'   \item > 0.5 = High inequality, check for dominance
#' }
#'
#' @export
#' @examples
#' # Low dispersion example
#' weights1 <- runif(20, 0.8, 1.2)
#' weight_diagnostics(weights1)
#'
#' # High dispersion example (one dominant study)
#' weights2 <- c(100, rep(1, 19))
#' weight_diagnostics(weights2)
weight_diagnostics <- function(weights) {

  weights <- weights[!is.na(weights)]

  if (length(weights) == 0) {
    return(list(
      cv = NA_real_,
      gini = NA_real_,
      max_pct = NA_real_,
      interpretation = "No valid weights"
    ))
  }

  # Coefficient of variation
  cv <- sd(weights) / mean(weights)

  # Gini coefficient
  weights_sorted <- sort(weights)
  n <- length(weights_sorted)
  gini <- (2 * sum(weights_sorted * seq_len(n)) / (n * sum(weights_sorted))) - (n + 1) / n
  gini <- max(0, min(1, gini))

  # Max weight percentage
  max_pct <- max(weights) / sum(weights) * 100

  # Interpretation
  if (cv < 0.3) {
    interpretation <- "Low dispersion (CV < 0.3): Use precision-weighted cross-validation"
  } else if (cv < 0.6) {
    interpretation <- "Moderate dispersion (0.3 ≤ CV < 0.6): Compare weighted and unweighted CV"
  } else {
    interpretation <- "High dispersion (CV ≥ 0.6): Consider unweighted cross-validation"
  }

  if (gini > 0.5 || max_pct > 30) {
    interpretation <- paste0(
      interpretation,
      " WARNING: High inequality (Gini = ", round(gini, 2),
      ", max weight = ", round(max_pct, 1), "%). Check for dominant studies."
    )
  }

  list(
    cv = cv,
    gini = gini,
    max_pct = max_pct,
    interpretation = interpretation
  )
}
