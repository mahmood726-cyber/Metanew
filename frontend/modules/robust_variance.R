# =============================================================================
# Robust Variance Estimation Enhancement
# =============================================================================
# ✅ STANDARD - Heteroscedasticity-consistent standard errors
#
# Features:
# - HC3 and HC4 robust variance estimators
# - Better performance with small samples (k < 10)
# - Robust to variance misspecification
# - Integration with meta-regression
# =============================================================================

library(metafor)
library(sandwich)

#' Calculate robust variance-covariance matrix
#'
#' @param rma_model Fitted rma model object
#' @param type Type of robust variance ("HC3" or "HC4")
#' @return Robust variance-covariance matrix
#' @export
robust_vcov <- function(rma_model, type = "HC3") {

  # Extract residuals and weights
  res <- resid(rma_model)
  W <- diag(weights(rma_model))
  X <- model.matrix(rma_model)

  # Calculate leverage
  H <- X %*% solve(t(X) %*% W %*% X) %*% t(X) %*% W
  h <- diag(H)

  # HC3 adjustment
  if (type == "HC3") {
    omega <- diag(res^2 / (1 - h)^2)
  }
  # HC4 adjustment
  else if (type == "HC4") {
    delta <- pmin(4, h / mean(h))
    omega <- diag(res^2 / (1 - h)^delta)
  }
  else {
    stop("Type must be 'HC3' or 'HC4'")
  }

  # Robust variance-covariance matrix
  vcov_robust <- solve(t(X) %*% W %*% X) %*% t(X) %*% W %*% omega %*% W %*% X %*%
                  solve(t(X) %*% W %*% X)

  return(vcov_robust)
}

#' Perform meta-regression with robust variance
#'
#' @param data Data frame with yi, vi, and moderators
#' @param moderators Formula for moderators
#' @param robust_type Type of robust variance ("HC3" or "HC4")
#' @return List with results
#' @export
meta_regression_robust <- function(data, moderators, robust_type = "HC3") {

  # Fit standard meta-regression
  model <- rma(moderators, vi = data$vi, data = data, method = "REML")

  # Calculate robust variance
  vcov_robust <- robust_vcov(model, type = robust_type)

  # Robust standard errors
  se_robust <- sqrt(diag(vcov_robust))

  # Robust z-values and p-values
  z_robust <- coef(model) / se_robust
  p_robust <- 2 * pnorm(abs(z_robust), lower.tail = FALSE)

  # Robust confidence intervals
  ci_lower_robust <- coef(model) - qnorm(0.975) * se_robust
  ci_upper_robust <- coef(model) + qnorm(0.975) * se_robust

  # Create results table
  results <- data.frame(
    coefficient = names(coef(model)),
    estimate = as.numeric(coef(model)),
    se_standard = model$se,
    se_robust = se_robust,
    z_standard = as.numeric(model$zval),
    z_robust = z_robust,
    p_standard = model$pval,
    p_robust = p_robust,
    ci_lower_standard = model$ci.lb,
    ci_upper_standard = model$ci.ub,
    ci_lower_robust = ci_lower_robust,
    ci_upper_robust = ci_upper_robust
  )

  list(
    model = model,
    vcov_robust = vcov_robust,
    results = results,
    robust_type = robust_type
  )
}

#' UI component for robust variance option
#'
#' @param id Module ID
#' @export
robust_variance_ui <- function(id) {
  ns <- NS(id)

  div(
    style = "margin-top: 15px;",

    checkboxInput(
      ns("use_robust_var"),
      "Use Robust Variance Estimation (HC3/HC4)",
      value = FALSE
    ),

    conditionalPanel(
      condition = "input.use_robust_var",
      ns = ns,

      selectInput(
        ns("robust_type"),
        "Robust Variance Type:",
        choices = c(
          "HC3 (Recommended for k < 10)" = "HC3",
          "HC4 (More conservative)" = "HC4"
        ),
        selected = "HC3"
      ),

      div(
        style = "background: #EFF6FF; border-left: 4px solid #3B82F6;
                 padding: 10px; border-radius: 4px; margin-top: 10px;",
        p(
          style = "margin: 0; color: #1E40AF; font-size: 12px;",
          icon("info-circle", style = "margin-right: 5px;"),
          "Robust variance estimates are recommended for meta-regression with few studies (k < 10).
          They provide better control of Type I error rates."
        )
      )
    )
  )
}

#' Server component for robust variance
#'
#' @param id Module ID
#' @param rma_model Reactive rma model
#' @export
robust_variance_server <- function(id, rma_model) {
  moduleServer(id, function(input, output, session) {

    robust_results <- reactive({
      req(rma_model())
      req(input$use_robust_var)

      if (input$use_robust_var) {
        # Calculate robust variance
        vcov_rob <- robust_vcov(rma_model(), type = input$robust_type)

        # Extract robust SEs
        se_robust <- sqrt(diag(vcov_rob))

        list(
          use_robust = TRUE,
          vcov = vcov_rob,
          se = se_robust,
          type = input$robust_type
        )
      } else {
        list(use_robust = FALSE)
      }
    })

    return(robust_results)
  })
}

#' Display comparison of standard vs robust results
#'
#' @param results Results from meta_regression_robust
#' @return Formatted table
#' @export
display_robust_comparison <- function(results) {

  comparison <- results$results %>%
    select(
      Coefficient = coefficient,
      Estimate = estimate,
      `SE (Standard)` = se_standard,
      `SE (Robust)` = se_robust,
      `P (Standard)` = p_standard,
      `P (Robust)` = p_robust
    ) %>%
    mutate(
      Estimate = round(Estimate, 3),
      `SE (Standard)` = round(`SE (Standard)`, 3),
      `SE (Robust)` = round(`SE (Robust)`, 3),
      `P (Standard)` = format.pval(`P (Standard)`, digits = 3),
      `P (Robust)` = format.pval(`P (Robust)`, digits = 3)
    )

  comparison
}
