# ============================================================================
# Dose-Response Meta-Analysis Module
# ============================================================================
# Complete implementation for dose-response meta-analysis
# Reference: Orsini et al. (2012), Crippa & Orsini (2016)
# ============================================================================

library(dosresmeta)
library(rms)
library(ggplot2)
library(dplyr)

#' Prepare Dose-Response Data
#'
#' Converts study data to dosresmeta format
#'
#' @param studies_data Data frame with study-level data
#' @param study_var Study identifier column
#' @param dose_var Dose/exposure variable
#' @param cases_var Number of cases (events)
#' @param n_var Total number of subjects
#' @param type Data type: "ir" (incidence rate), "cc" (case-control), "ci" (cumulative incidence)
#' @return Data frame in dosresmeta format
#' @export
prepare_doseresp_data <- function(studies_data,
                                  study_var = "study",
                                  dose_var = "dose",
                                  cases_var = "cases",
                                  n_var = "n",
                                  type = "ir") {

  # Validate columns
  required_cols <- c(study_var, dose_var, cases_var, n_var)
  missing_cols <- required_cols[!required_cols %in% names(studies_data)]

  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Rename to standard names for dosresmeta
  doseresp_data <- studies_data %>%
    rename(
      study = !!sym(study_var),
      dose = !!sym(dose_var),
      cases = !!sym(cases_var),
      n = !!sym(n_var)
    )

  # Calculate person-years if not provided
  if (!"peryears" %in% names(doseresp_data)) {
    doseresp_data$peryears <- doseresp_data$n  # Assume 1 year follow-up if not specified
  }

  # Add type
  doseresp_data$type <- type

  # Validate data quality
  if (any(doseresp_data$dose < 0)) {
    warning("Negative dose values detected")
  }

  if (any(doseresp_data$cases > doseresp_data$n)) {
    warning("Cases exceed total N in some rows")
  }

  # Check for reference group (dose = 0)
  studies_with_ref <- doseresp_data %>%
    group_by(study) %>%
    summarise(has_ref = any(dose == 0), .groups = "drop")

  if (!all(studies_with_ref$has_ref)) {
    warning("Some studies missing reference group (dose = 0)")
  }

  cat("\n=== Dose-Response Data Prepared ===\n")
  cat("Studies:", length(unique(doseresp_data$study)), "\n")
  cat("Total dose levels:", nrow(doseresp_data), "\n")
  cat("Dose range:", min(doseresp_data$dose), "to", max(doseresp_data$dose), "\n")
  cat("Type:", type, "\n\n")

  return(doseresp_data)
}


#' Fit Linear Dose-Response Model
#'
#' Simple linear trend test
#'
#' @param doseresp_data Prepared dose-response data
#' @return dosresmeta model object
#' @export
fit_linear_doseresp <- function(doseresp_data) {

  cat("\n=== Fitting Linear Dose-Response Model ===\n")

  model <- dosresmeta(
    formula = cases ~ dose,
    id = study,
    type = type,
    cases = cases,
    n = n,
    data = doseresp_data,
    proc = "1stage"
  )

  cat("Model fitted successfully\n")
  cat("\nLinear coefficient:\n")
  print(summary(model)$coefficients)
  cat("\n")

  return(model)
}


#' Fit Restricted Cubic Spline Dose-Response Model
#'
#' Flexible non-linear dose-response using splines
#'
#' @param doseresp_data Prepared dose-response data
#' @param knots Number or positions of knots (default: 3)
#' @return dosresmeta model object
#' @export
fit_spline_doseresp <- function(doseresp_data, knots = 3) {

  cat("\n=== Fitting Restricted Cubic Spline Model ===\n")
  cat("Knots:", knots, "\n\n")

  # Create spline terms
  model <- dosresmeta(
    formula = cases ~ rcs(dose, knots),
    id = study,
    type = type,
    cases = cases,
    n = n,
    data = doseresp_data,
    proc = "1stage"
  )

  cat("Spline model fitted successfully\n")
  cat("\nModel coefficients:\n")
  print(summary(model)$coefficients)
  cat("\n")

  return(model)
}


#' Fit Fractional Polynomial Dose-Response Model
#'
#' Flexible modeling with fractional polynomials
#'
#' @param doseresp_data Prepared dose-response data
#' @param powers Vector of powers (e.g., c(0, 1) for log-linear)
#' @return dosresmeta model object
#' @export
fit_fractional_polynomial_doseresp <- function(doseresp_data, powers = c(0, 1)) {

  cat("\n=== Fitting Fractional Polynomial Model ===\n")
  cat("Powers:", paste(powers, collapse = ", "), "\n\n")

  # Create fractional polynomial terms
  # Power 0 means log transformation
  if (length(powers) == 1) {
    if (powers[1] == 0) {
      doseresp_data$fp1 <- log(doseresp_data$dose + 1)
      formula <- cases ~ fp1
    } else {
      doseresp_data$fp1 <- (doseresp_data$dose + 1) ^ powers[1]
      formula <- cases ~ fp1
    }
  } else if (length(powers) == 2) {
    if (powers[1] == 0) {
      doseresp_data$fp1 <- log(doseresp_data$dose + 1)
    } else {
      doseresp_data$fp1 <- (doseresp_data$dose + 1) ^ powers[1]
    }

    if (powers[2] == 0) {
      doseresp_data$fp2 <- log(doseresp_data$dose + 1)
    } else if (powers[2] == powers[1]) {
      doseresp_data$fp2 <- doseresp_data$fp1 * log(doseresp_data$dose + 1)
    } else {
      doseresp_data$fp2 <- (doseresp_data$dose + 1) ^ powers[2]
    }

    formula <- cases ~ fp1 + fp2
  } else {
    stop("Only 1 or 2 powers supported")
  }

  model <- dosresmeta(
    formula = formula,
    id = study,
    type = type,
    cases = cases,
    n = n,
    data = doseresp_data,
    proc = "1stage"
  )

  cat("Fractional polynomial model fitted\n\n")

  return(model)
}


#' Predict Dose-Response Curve
#'
#' Generate predicted relative risks across dose range
#'
#' @param model dosresmeta model object
#' @param dose_range Vector of dose values to predict at
#' @return Data frame with predictions
#' @export
predict_doseresp_curve <- function(model, dose_range = NULL) {

  # Get dose range from model data if not specified
  if (is.null(dose_range)) {
    dose_min <- min(model$data$dose)
    dose_max <- max(model$data$dose)
    dose_range <- seq(dose_min, dose_max, length.out = 100)
  }

  # Create prediction data
  newdata <- data.frame(dose = dose_range)

  # Predict
  pred <- predict(model, newdata = newdata, expo = TRUE)

  result <- data.frame(
    dose = dose_range,
    RR = pred$pred,
    lower = pred$ci.lb,
    upper = pred$ci.ub
  )

  return(result)
}


#' Plot Dose-Response Curve
#'
#' Creates publication-quality dose-response plot
#'
#' @param model dosresmeta model object
#' @param dose_range Optional dose range for prediction
#' @param xlab X-axis label
#' @param ylab Y-axis label
#' @param title Plot title
#' @return ggplot object
#' @export
plot_doseresp_curve <- function(model,
                                dose_range = NULL,
                                xlab = "Dose",
                                ylab = "Relative Risk",
                                title = "Dose-Response Curve") {

  # Get predictions
  pred_data <- predict_doseresp_curve(model, dose_range)

  # Create plot
  p <- ggplot(pred_data, aes(x = dose, y = RR)) +
    geom_line(color = "blue", linewidth = 1) +
    geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2, fill = "blue") +
    geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
    labs(
      title = title,
      x = xlab,
      y = ylab
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      panel.grid.minor = element_blank()
    )

  return(p)
}


#' Run Complete Dose-Response Meta-Analysis
#'
#' Main workflow function
#'
#' @param studies_data Study-level data frame
#' @param model_type "linear", "spline", or "fractional_polynomial"
#' @param knots For spline: number of knots
#' @param powers For FP: vector of powers
#' @param ... Additional arguments passed to preparation
#' @return List with model, predictions, and plot
#' @export
run_doseresp_analysis <- function(studies_data,
                                  model_type = "spline",
                                  knots = 3,
                                  powers = c(0, 1),
                                  ...) {

  cat("\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║     EvidenceOS PRIME - Dose-Response Meta-Analysis v4.0     ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")

  # Step 1: Prepare data
  cat("\n--- Step 1: Preparing Data ---\n")
  doseresp_data <- prepare_doseresp_data(studies_data, ...)

  # Step 2: Fit model
  cat("\n--- Step 2: Fitting Model ---\n")

  model <- if (model_type == "linear") {
    fit_linear_doseresp(doseresp_data)
  } else if (model_type == "spline") {
    fit_spline_doseresp(doseresp_data, knots = knots)
  } else if (model_type == "fractional_polynomial") {
    fit_fractional_polynomial_doseresp(doseresp_data, powers = powers)
  } else {
    stop("model_type must be 'linear', 'spline', or 'fractional_polynomial'")
  }

  # Step 3: Generate predictions
  cat("\n--- Step 3: Generating Predictions ---\n")
  predictions <- predict_doseresp_curve(model)
  cat(sprintf("Predicted RR at median dose (%.1f): %.2f (95%% CI: %.2f-%.2f)\n",
              median(predictions$dose),
              predictions$RR[length(predictions$RR)/2],
              predictions$lower[length(predictions$lower)/2],
              predictions$upper[length(predictions$upper)/2]))

  # Step 4: Create plot
  cat("\n--- Step 4: Creating Visualization ---\n")
  plot <- plot_doseresp_curve(model)

  cat("\n╔══════════════════════════════════════════════════════════════╗\n")
  cat("║                    Analysis Complete!                        ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n\n")

  list(
    model = model,
    predictions = predictions,
    plot = plot,
    data = doseresp_data,
    model_type = model_type
  )
}


# ============================================================================
# Example Usage
# ============================================================================

# Example data (alcohol and breast cancer risk)
# studies_data <- data.frame(
#   study = rep(1:5, each = 3),
#   dose = rep(c(0, 10, 20), 5),  # grams/day of alcohol
#   cases = c(50, 55, 65, 40, 45, 52, 60, 68, 78, 35, 38, 44, 45, 50, 58),
#   n = rep(c(1000, 1200, 900, 800, 1100), each = 3)
# )
#
# # Linear model
# linear_results <- run_doseresp_analysis(
#   studies_data = studies_data,
#   model_type = "linear"
# )
#
# # Spline model (recommended)
# spline_results <- run_doseresp_analysis(
#   studies_data = studies_data,
#   model_type = "spline",
#   knots = 3
# )
#
# # View results
# print(spline_results$plot)
# print(spline_results$predictions)
