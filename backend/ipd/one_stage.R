# ============================================================================
# IPD Meta-Analysis - One-Stage Models Module
# ============================================================================
# One-stage IPD meta-analysis using mixed effects models
# Reference: Debray et al. (2015), Riley et al. (2010)
# ============================================================================

library(lme4)
library(survival)
library(coxme)
library(emmeans)

#' Fit One-Stage Binary Outcome IPD Model
#'
#' Uses glmer() for binary outcomes with random effects by study
#'
#' @param ipd_prep Prepared IPD data from prepare_ipd_for_analysis()
#' @param formula Model formula (if NULL, uses default)
#' @param random_effects Type: "intercept_only", "intercept_slope", or "complex"
#' @param verbose Print progress messages
#' @return glmer model object with IPD metadata
#' @export
fit_binary_outcome_ipd <- function(ipd_prep,
                                   formula = NULL,
                                   random_effects = "intercept_slope",
                                   verbose = TRUE) {

  if (ipd_prep$outcome_type != "binary") {
    stop("This function is for binary outcomes. Outcome type is: ", ipd_prep$outcome_type)
  }

  data <- ipd_prep$data
  study_var <- ipd_prep$study_var
  outcome_var <- ipd_prep$outcome_var
  treatment_var <- ipd_prep$treatment_var
  covariates <- ipd_prep$covariates

  # Build formula if not provided
  if (is.null(formula)) {
    # Fixed effects
    fixed_terms <- treatment_var

    if (!is.null(covariates) && length(covariates) > 0) {
      fixed_terms <- c(fixed_terms, covariates)
    }

    fixed_part <- paste(fixed_terms, collapse = " + ")

    # Random effects
    if (random_effects == "intercept_only") {
      random_part <- sprintf("(1 | %s)", study_var)
    } else if (random_effects == "intercept_slope") {
      random_part <- sprintf("(1 + %s | %s)", treatment_var, study_var)
    } else if (random_effects == "complex") {
      # All fixed effects vary by study
      random_part <- sprintf("(1 + %s | %s)", fixed_part, study_var)
    }

    formula_string <- sprintf("%s ~ %s + %s", outcome_var, fixed_part, random_part)
    formula <- as.formula(formula_string)
  }

  if (verbose) {
    cat("\n=== One-Stage Binary IPD Meta-Analysis ===\n")
    cat("Formula:", deparse(formula), "\n")
    cat("Patients:", nrow(data), "\n")
    cat("Studies:", ipd_prep$n_studies, "\n")
    cat("\nFitting mixed effects logistic regression...\n")
  }

  # Fit model
  start_time <- Sys.time()

  fit <- tryCatch({
    glmer(
      formula = formula,
      data = data,
      family = binomial(link = "logit"),
      control = glmerControl(
        optimizer = "bobyqa",
        optCtrl = list(maxfun = 100000)
      )
    )
  }, error = function(e) {
    # Try alternative optimizer if bobyqa fails
    warning("bobyqa optimizer failed, trying nloptwrap...")
    glmer(
      formula = formula,
      data = data,
      family = binomial(link = "logit"),
      control = glmerControl(
        optimizer = "nloptwrap",
        optCtrl = list(maxfun = 100000)
      )
    )
  })

  elapsed <- difftime(Sys.time(), start_time, units = "secs")

  if (verbose) {
    cat("Fitting completed in", round(elapsed, 2), "seconds\n")
    cat("\nFixed Effects:\n")
    print(summary(fit)$coefficients)
    cat("\nRandom Effects:\n")
    print(VarCorr(fit))
  }

  # Add metadata
  fit$ipd_metadata <- list(
    ipd_prep = ipd_prep,
    elapsed_time = elapsed,
    timestamp = Sys.time(),
    model_type = "one_stage_binary",
    random_effects = random_effects
  )

  class(fit) <- c("ipd_glmer", class(fit))

  return(fit)
}


#' Fit One-Stage Continuous Outcome IPD Model
#'
#' Uses lmer() for continuous outcomes
#'
#' @param ipd_prep Prepared IPD data
#' @param formula Model formula (if NULL, uses default)
#' @param random_effects Type: "intercept_only", "intercept_slope", or "complex"
#' @param verbose Print progress
#' @return lmer model object
#' @export
fit_continuous_outcome_ipd <- function(ipd_prep,
                                       formula = NULL,
                                       random_effects = "intercept_slope",
                                       verbose = TRUE) {

  if (ipd_prep$outcome_type != "continuous") {
    stop("This function is for continuous outcomes. Outcome type is: ", ipd_prep$outcome_type)
  }

  data <- ipd_prep$data
  study_var <- ipd_prep$study_var
  outcome_var <- ipd_prep$outcome_var
  treatment_var <- ipd_prep$treatment_var
  covariates <- ipd_prep$covariates

  # Build formula if not provided
  if (is.null(formula)) {
    fixed_terms <- treatment_var

    if (!is.null(covariates) && length(covariates) > 0) {
      fixed_terms <- c(fixed_terms, covariates)
    }

    fixed_part <- paste(fixed_terms, collapse = " + ")

    # Random effects
    if (random_effects == "intercept_only") {
      random_part <- sprintf("(1 | %s)", study_var)
    } else if (random_effects == "intercept_slope") {
      random_part <- sprintf("(1 + %s | %s)", treatment_var, study_var)
    } else if (random_effects == "complex") {
      random_part <- sprintf("(1 + %s | %s)", fixed_part, study_var)
    }

    formula_string <- sprintf("%s ~ %s + %s", outcome_var, fixed_part, random_part)
    formula <- as.formula(formula_string)
  }

  if (verbose) {
    cat("\n=== One-Stage Continuous IPD Meta-Analysis ===\n")
    cat("Formula:", deparse(formula), "\n")
    cat("Patients:", nrow(data), "\n")
    cat("Studies:", ipd_prep$n_studies, "\n")
    cat("\nFitting mixed effects linear regression...\n")
  }

  # Fit model
  start_time <- Sys.time()

  fit <- lmer(
    formula = formula,
    data = data,
    control = lmerControl(optimizer = "bobyqa")
  )

  elapsed <- difftime(Sys.time(), start_time, units = "secs")

  if (verbose) {
    cat("Fitting completed in", round(elapsed, 2), "seconds\n")
    cat("\nFixed Effects:\n")
    print(summary(fit)$coefficients)
    cat("\nRandom Effects:\n")
    print(VarCorr(fit))
  }

  # Add metadata
  fit$ipd_metadata <- list(
    ipd_prep = ipd_prep,
    elapsed_time = elapsed,
    timestamp = Sys.time(),
    model_type = "one_stage_continuous",
    random_effects = random_effects
  )

  class(fit) <- c("ipd_lmer", class(fit))

  return(fit)
}


#' Fit One-Stage Survival Outcome IPD Model
#'
#' Uses coxme() for time-to-event outcomes
#'
#' @param ipd_prep Prepared IPD data (must have time and event variables)
#' @param formula Model formula (if NULL, uses default)
#' @param time_var Name of time variable (default: "time")
#' @param event_var Name of event indicator (default: "event")
#' @param verbose Print progress
#' @return coxme model object
#' @export
fit_survival_outcome_ipd <- function(ipd_prep,
                                     formula = NULL,
                                     time_var = "time",
                                     event_var = "event",
                                     verbose = TRUE) {

  if (ipd_prep$outcome_type != "survival") {
    stop("This function is for survival outcomes. Outcome type is: ", ipd_prep$outcome_type)
  }

  data <- ipd_prep$data
  study_var <- ipd_prep$study_var
  treatment_var <- ipd_prep$treatment_var
  covariates <- ipd_prep$covariates

  # Check required variables
  if (!time_var %in% names(data)) {
    stop("Time variable '", time_var, "' not found in data")
  }
  if (!event_var %in% names(data)) {
    stop("Event variable '", event_var, "' not found in data")
  }

  # Build formula if not provided
  if (is.null(formula)) {
    fixed_terms <- treatment_var

    if (!is.null(covariates) && length(covariates) > 0) {
      fixed_terms <- c(fixed_terms, covariates)
    }

    fixed_part <- paste(fixed_terms, collapse = " + ")
    random_part <- sprintf("(1 | %s)", study_var)

    formula_string <- sprintf("Surv(%s, %s) ~ %s + %s", time_var, event_var, fixed_part, random_part)
    formula <- as.formula(formula_string)
  }

  if (verbose) {
    cat("\n=== One-Stage Survival IPD Meta-Analysis ===\n")
    cat("Formula:", deparse(formula), "\n")
    cat("Patients:", nrow(data), "\n")
    cat("Studies:", ipd_prep$n_studies, "\n")
    cat("Events:", sum(data[[event_var]]), sprintf("(%.1f%%)", 100 * mean(data[[event_var]])), "\n")
    cat("\nFitting Cox mixed effects model...\n")
  }

  # Fit model
  start_time <- Sys.time()

  fit <- coxme(formula = formula, data = data)

  elapsed <- difftime(Sys.time(), start_time, units = "secs")

  if (verbose) {
    cat("Fitting completed in", round(elapsed, 2), "seconds\n")
    cat("\nFixed Effects (Hazard Ratios):\n")
    hr_table <- data.frame(
      Coefficient = coef(fit),
      HR = exp(coef(fit)),
      SE = sqrt(diag(vcov(fit)))
    )
    hr_table$`z value` <- hr_table$Coefficient / hr_table$SE
    hr_table$`Pr(>|z|)` <- 2 * pnorm(-abs(hr_table$`z value`))
    print(hr_table)
    cat("\nRandom Effects:\n")
    print(VarCorr(fit))
  }

  # Add metadata
  fit$ipd_metadata <- list(
    ipd_prep = ipd_prep,
    elapsed_time = elapsed,
    timestamp = Sys.time(),
    model_type = "one_stage_survival",
    time_var = time_var,
    event_var = event_var
  )

  class(fit) <- c("ipd_coxme", class(fit))

  return(fit)
}


#' Fit One-Stage Count Outcome IPD Model
#'
#' Uses glmer() with Poisson or negative binomial family
#'
#' @param ipd_prep Prepared IPD data
#' @param formula Model formula
#' @param family "poisson" or "neg binomial"
#' @param offset_var Optional offset variable (e.g., log(person-time))
#' @param verbose Print progress
#' @return glmer model object
#' @export
fit_count_outcome_ipd <- function(ipd_prep,
                                  formula = NULL,
                                  family = "poisson",
                                  offset_var = NULL,
                                  verbose = TRUE) {

  if (ipd_prep$outcome_type != "count") {
    stop("This function is for count outcomes. Outcome type is: ", ipd_prep$outcome_type)
  }

  data <- ipd_prep$data
  study_var <- ipd_prep$study_var
  outcome_var <- ipd_prep$outcome_var
  treatment_var <- ipd_prep$treatment_var
  covariates <- ipd_prep$covariates

  # Build formula
  if (is.null(formula)) {
    fixed_terms <- treatment_var

    if (!is.null(covariates) && length(covariates) > 0) {
      fixed_terms <- c(fixed_terms, covariates)
    }

    fixed_part <- paste(fixed_terms, collapse = " + ")
    random_part <- sprintf("(1 + %s | %s)", treatment_var, study_var)

    if (!is.null(offset_var) && offset_var %in% names(data)) {
      offset_part <- sprintf(" + offset(log(%s))", offset_var)
    } else {
      offset_part <- ""
    }

    formula_string <- sprintf("%s ~ %s%s + %s", outcome_var, fixed_part, offset_part, random_part)
    formula <- as.formula(formula_string)
  }

  if (verbose) {
    cat("\n=== One-Stage Count IPD Meta-Analysis ===\n")
    cat("Formula:", deparse(formula), "\n")
    cat("Family:", family, "\n")
    cat("Patients:", nrow(data), "\n")
    cat("Studies:", ipd_prep$n_studies, "\n")
  }

  # Select family
  if (family == "poisson") {
    fam <- poisson(link = "log")
  } else {
    # For negative binomial, would need glmer.nb from MASS
    stop("Negative binomial not yet implemented. Use family = 'poisson'")
  }

  # Fit model
  start_time <- Sys.time()

  fit <- glmer(
    formula = formula,
    data = data,
    family = fam,
    control = glmerControl(optimizer = "bobyqa")
  )

  elapsed <- difftime(Sys.time(), start_time, units = "secs")

  if (verbose) {
    cat("Fitting completed in", round(elapsed, 2), "seconds\n")
    cat("\nFixed Effects:\n")
    print(summary(fit)$coefficients)
  }

  # Add metadata
  fit$ipd_metadata <- list(
    ipd_prep = ipd_prep,
    elapsed_time = elapsed,
    timestamp = Sys.time(),
    model_type = "one_stage_count",
    family = family
  )

  class(fit) <- c("ipd_glmer", class(fit))

  return(fit)
}


#' Extract Treatment Effect from IPD Model
#'
#' Gets treatment effect estimate with confidence interval
#'
#' @param fit IPD model object (lmer, glmer, or coxme)
#' @param treatment_var Treatment variable name
#' @param conf_level Confidence level (default: 0.95)
#' @return Data frame with effect estimate and CI
#' @export
extract_treatment_effect <- function(fit, treatment_var = "treatment", conf_level = 0.95) {

  # Get fixed effects
  if (inherits(fit, "lmerMod") || inherits(fit, "glmerMod")) {
    coefs <- summary(fit)$coefficients
    treatment_row <- grep(treatment_var, rownames(coefs), value = TRUE)[1]

    if (is.na(treatment_row)) {
      stop("Treatment variable not found in model")
    }

    estimate <- coefs[treatment_row, "Estimate"]
    se <- coefs[treatment_row, "Std. Error"]

    # Calculate CI
    z_crit <- qnorm(1 - (1 - conf_level) / 2)
    ci_lower <- estimate - z_crit * se
    ci_upper <- estimate + z_crit * se

    # For logistic regression, exponentiate to get OR
    if (inherits(fit, "glmerMod") && family(fit)$family == "binomial") {
      result <- data.frame(
        log_OR = estimate,
        OR = exp(estimate),
        CI_lower = exp(ci_lower),
        CI_upper = exp(ci_upper),
        SE = se,
        p_value = coefs[treatment_row, "Pr(>|z|)"]
      )
    } else {
      result <- data.frame(
        estimate = estimate,
        CI_lower = ci_lower,
        CI_upper = ci_upper,
        SE = se
      )
    }

  } else if (inherits(fit, "coxme")) {
    treatment_row <- grep(treatment_var, names(coef(fit)), value = TRUE)[1]

    estimate <- coef(fit)[treatment_row]
    se <- sqrt(diag(vcov(fit)))[treatment_row]

    z_crit <- qnorm(1 - (1 - conf_level) / 2)
    ci_lower <- estimate - z_crit * se
    ci_upper <- estimate + z_crit * se

    result <- data.frame(
      log_HR = estimate,
      HR = exp(estimate),
      CI_lower = exp(ci_lower),
      CI_upper = exp(ci_upper),
      SE = se
    )
  }

  result$model_type <- fit$ipd_metadata$model_type

  return(result)
}


#' Get Study-Specific Effects
#'
#' Extract random effects (BLUPs) for each study
#'
#' @param fit IPD model object
#' @param study_var Study identifier variable name
#' @return Data frame with study-specific effects
#' @export
get_study_specific_effects <- function(fit, study_var = "study_id") {

  if (inherits(fit, "lmerMod") || inherits(fit, "glmerMod")) {
    ranef_list <- ranef(fit, condVar = TRUE)
    study_effects <- ranef_list[[study_var]]

    # Get standard errors
    se_vals <- sqrt(unlist(lapply(attr(ranef_list[[study_var]], "postVar"), function(x) diag(x))))

    study_effects$SE <- se_vals

  } else if (inherits(fit, "coxme")) {
    study_effects <- data.frame(ranef(fit))
    # coxme doesn't provide SE for random effects easily
    study_effects$SE <- NA
  }

  study_effects$study <- rownames(study_effects)
  rownames(study_effects) <- NULL

  return(study_effects)
}
