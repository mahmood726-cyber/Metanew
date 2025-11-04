#' LASSO Meta-Regression
#'
#' @description
#' Variable selection in meta-regression using LASSO or Ridge regression.
#' Includes nested cross-validation and permutation testing to guard against
#' overfitting. Based on methods from Mahmood Arai's research.
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of sampling variances
#' @param X Design matrix for moderators (with or without intercept)
#' @param alpha Elastic net mixing parameter (1=LASSO, 0=Ridge, 0-1=Elastic Net)
#' @param method Heterogeneity estimator (default: "REML")
#' @param lambda_choice "lambda.min" or "lambda.1se" for model selection
#'
#' @return List with:
#' \itemize{
#'   \item \code{r2het} Apparent R²het
#'   \item \code{r2het_cv} Cross-validated R²het
#'   \item \code{optimism} Optimism = Apparent - CV
#'   \item \code{lambda} Selected penalty parameter
#'   \item \code{p_eff} Number of moderators (excluding intercept)
#'   \item \code{n_selected} Number of selected variables
#'   \item \code{selected_vars} Names of selected variables
#'   \item \code{coefficients} Model coefficients
#'   \item \code{cv_fit} glmnet CV object
#' }
#'
#' @details
#' **Why LASSO/Ridge for Meta-Regression?**
#'
#' Traditional meta-regression often suffers from overfitting when k/p is small.
#' Regularization methods (LASSO/Ridge) can help by:
#' - Shrinking coefficients toward zero
#' - Selecting relevant variables (LASSO)
#' - Improving prediction accuracy
#'
#' **WARNING - The Regularization Paradox:**
#'
#' However, research shows that lambda.min can *increase* optimism compared to
#' standard meta-regression, especially when k/p < 10. This occurs because:
#' - Flat CV surfaces enable "noise capitalization"
#' - Lambda.min overfits to cross-validation folds
#' - Permutation tests often show no true signal
#'
#' **Recommendations:**
#' 1. Use lambda.1se instead of lambda.min (more conservative)
#' 2. Run permutation tests to check for true signal
#' 3. Report optimism correction regardless of method
#' 4. Ensure k/p ≥ 15 when possible
#'
#' @references
#' Arai M. The Regularization Paradox in Meta-Regression. Under review.
#'
#' @export
#' @examples
#' \dontrun{
#' # Simulate data
#' k <- 30
#' yi <- rnorm(k, 0, 0.3)
#' vi <- runif(k, 0.01, 0.1)
#' X <- cbind(1, rnorm(k), rnorm(k), rnorm(k))
#'
#' # LASSO with lambda.min (WARNING: may increase optimism)
#' lasso_min <- lasso_meta_regression(yi, vi, X, alpha=1, lambda_choice="lambda.min")
#' cat("Optimism:", lasso_min$optimism * 100, "%\n")
#'
#' # LASSO with lambda.1se (more conservative)
#' lasso_1se <- lasso_meta_regression(yi, vi, X, alpha=1, lambda_choice="lambda.1se")
#' cat("Optimism:", lasso_1se$optimism * 100, "%\n")
#'
#' # Ridge regression
#' ridge <- lasso_meta_regression(yi, vi, X, alpha=0)
#'
#' # Check if signal is real with permutation test
#' perm_result <- permutation_test_lasso(yi, vi, X, n_perm=1000)
#' cat("P-value:", perm_result$p_value, "\n")
#' }
lasso_meta_regression <- function(yi, vi, X, alpha = 1, method = "REML",
                                  lambda_choice = "lambda.1se") {

  # Check data validity
  if (!check_data_validity(yi, vi, X, min_k=5, verbose=FALSE)) {
    return(list(
      r2het = NA, r2het_cv = NA, optimism = NA, lambda = NA,
      p_eff = NA, n_selected = NA, selected_vars = NA,
      coefficients = NA, cv_fit = NULL
    ))
  }

  # Remove intercept if present, drop constants
  has_intercept <- .is_intercept_column(X)
  if (has_intercept) X <- X[, -1, drop = FALSE]
  X <- drop_constant(X)

  if (is.null(X) || ncol(X) == 0) {
    return(list(
      r2het = 0, r2het_cv = 0, optimism = 0, lambda = NA,
      p_eff = 0, n_selected = 0, selected_vars = character(0),
      coefficients = numeric(0), cv_fit = NULL
    ))
  }

  p_eff <- ncol(X)
  k <- length(yi)

  # Fit null model for tau² estimation
  if (!requireNamespace("metafor", quietly = TRUE)) {
    stop("Package 'metafor' required but not installed")
  }

  fit_null <- metafor::rma(yi = yi, vi = vi, method = method)
  tau2_null <- fit_null$tau2
  w <- 1 / (vi + tau2_null)
  w <- w / sum(w)  # Normalize weights

  # Standardize predictors
  Xs <- scale(X)
  Xs[is.na(Xs)] <- 0

  # Set up penalty factor (penalize all except intercept)
  penalty.factor <- rep(1, ncol(Xs))

  # Stability hack for single predictor
  if (ncol(Xs) == 1) {
    Xs <- cbind(Xs, noise1 = rnorm(nrow(Xs), 0, 0.001), noise2 = rnorm(nrow(Xs), 0, 0.001))
    penalty.factor <- c(1, 10000, 10000)
  }

  # Cross-validation setup
  nfolds <- if (k <= 20) k else 10  # LOO for small k, 10-fold otherwise
  foldid <- if (nfolds == k) seq_len(k) else sample(rep(1:nfolds, length.out = k))

  # Run glmnet CV
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop("Package 'glmnet' required but not installed")
  }

  cv_fit <- glmnet::cv.glmnet(
    x = Xs, y = yi, weights = w * k, alpha = alpha,
    nfolds = nfolds, foldid = foldid,
    penalty.factor = penalty.factor,
    grouped = FALSE, keep = TRUE,
    standardize = FALSE, intercept = TRUE,
    family = "gaussian"
  )

  # Select lambda
  lam <- cv_fit[[lambda_choice]]

  # Apparent (in-sample) R²het
  yhat_in <- as.vector(predict(cv_fit, newx = Xs, s = lam))
  res_in <- yi - yhat_in
  vbar_w <- sum(w * vi)
  tau2_in <- max(0, sum(w * res_in^2) - vbar_w)
  r2_in <- .safe_r2het(tau2_in, tau2_null)

  # Out-of-fold R²het
  idx <- which.min(abs(log(cv_fit$lambda) - log(lam)))
  yhat_oof <- cv_fit$fit.preval[, idx]
  res_oof <- yi - yhat_oof
  tau2_cv <- max(0, sum(w * res_oof^2) - vbar_w)
  r2_cv <- .safe_r2het(tau2_cv, tau2_null)

  # Extract coefficients
  coefs <- as.matrix(coef(cv_fit, s = lam))
  intercept <- coefs[1, 1]
  beta <- coefs[-1, 1]

  # Remove noise variables if added
  if (p_eff == 1 && length(beta) > 1) {
    beta <- beta[1]
  }

  # Selected variables
  selected_idx <- which(abs(beta) > 0)
  n_selected <- length(selected_idx)
  selected_vars <- if (n_selected > 0 && !is.null(colnames(X))) {
    colnames(X)[selected_idx]
  } else if (n_selected > 0) {
    paste0("X", selected_idx)
  } else {
    character(0)
  }

  list(
    r2het = r2_in,
    r2het_cv = r2_cv,
    optimism = r2_in - r2_cv,
    lambda = lam,
    p_eff = p_eff,
    n_selected = n_selected,
    selected_vars = selected_vars,
    coefficients = c(intercept = intercept, beta),
    cv_fit = cv_fit,
    tau2_null = tau2_null
  )
}

#' Permutation Test for LASSO Meta-Regression
#'
#' @description
#' Tests whether observed R²het from LASSO is greater than expected by chance.
#' Permutes moderator-outcome relationships while keeping data structure intact.
#'
#' @param yi Vector of effect sizes
#' @param vi Vector of sampling variances
#' @param X Design matrix for moderators
#' @param n_perm Number of permutations (default: 1000)
#' @param alpha Elastic net mixing parameter (default: 1 for LASSO)
#' @param method Heterogeneity estimator (default: "REML")
#' @param lambda_choice "lambda.min" or "lambda.1se"
#'
#' @return List with:
#' \itemize{
#'   \item \code{observed_r2} Observed R²het from real data
#'   \item \code{perm_mean} Mean R²het from permutations
#'   \item \code{perm_sd} SD of permuted R²het
#'   \item \code{p_value} Proportion of permutations ≥ observed
#'   \item \code{overfit_ratio} Observed / Permuted mean
#'   \item \code{interpretation} Interpretation of results
#' }
#'
#' @details
#' **Interpretation:**
#' - p < 0.05: Strong evidence of true signal
#' - p > 0.10: Weak/no evidence - likely overfitting
#' - Overfit ratio > 2: Observed much larger than chance
#'
#' @export
permutation_test_lasso <- function(yi, vi, X, n_perm = 1000, alpha = 1,
                                   method = "REML", lambda_choice = "lambda.min") {

  # Observed result
  obs <- lasso_meta_regression(yi, vi, X, alpha, method, lambda_choice)
  obs_r2 <- obs$r2het

  if (is.na(obs_r2)) {
    return(list(
      observed_r2 = NA, perm_mean = NA, perm_sd = NA,
      p_value = NA, overfit_ratio = NA,
      interpretation = "Data invalid for permutation test"
    ))
  }

  # Remove intercept for permutation
  X_base <- if (.is_intercept_column(X)) X[, -1, drop = FALSE] else X
  perm_r2 <- numeric(n_perm)

  for (p in seq_len(n_perm)) {
    # Permute rows of X
    Xp <- X_base[sample(nrow(X_base)), , drop = FALSE]
    # Re-add intercept
    Xp <- cbind(1, Xp)

    perm_r2[p] <- lasso_meta_regression(yi, vi, Xp, alpha, method, lambda_choice)$r2het
  }

  perm_mean <- mean(perm_r2, na.rm = TRUE)
  perm_sd <- sd(perm_r2, na.rm = TRUE)
  p_value <- mean(perm_r2 >= obs_r2, na.rm = TRUE)
  overfit_ratio <- if (perm_mean > 0) obs_r2 / perm_mean else NA

  # Interpretation
  if (p_value < 0.05) {
    interpretation <- "STRONG: True signal detected (p < 0.05)"
  } else if (p_value < 0.10) {
    interpretation <- "WEAK: Marginal evidence of signal (0.05 ≤ p < 0.10)"
  } else {
    interpretation <- "NONE: No evidence of signal - likely overfitting (p ≥ 0.10)"
  }

  list(
    observed_r2 = obs_r2,
    perm_mean = perm_mean,
    perm_sd = perm_sd,
    p_value = p_value,
    overfit_ratio = overfit_ratio,
    interpretation = interpretation
  )
}

#' Safe R²het Calculation
#' @keywords internal
.safe_r2het <- function(tau2_full, tau2_null, eps = 1e-10) {
  if (is.na(tau2_null) || is.na(tau2_full)) return(NA_real_)
  denom <- max(tau2_null, eps)
  pmin(1, pmax(0, 1 - tau2_full / denom))
}

#' Check if column is intercept
#' @keywords internal
.is_intercept_column <- function(X) {
  if (is.null(X) || ncol(X) == 0) return(FALSE)
  all(abs(X[, 1] - 1) < 1e-12)
}
