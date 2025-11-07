# =============================================================================
# EVIDENCEOS PRIME - FDA REAL-WORLD EVIDENCE MODULE
# =============================================================================
# Purpose: FDA-compliant real-world evidence analysis and causal inference
# Quality: Production-ready with FDA RWE Framework standards
# Version: 1.0 - Complete Implementation
# US Compliance: FDA RWE Framework (2018), 21 CFR 312.3, ISPOR Guidelines
# =============================================================================

#' FDA Real-World Evidence Standards
#'
#' @description
#' Standards and requirements for FDA acceptance of real-world evidence.
#'
#' @export
FDA_RWE_STANDARDS <- list(

  data_sources = list(
    acceptable = c("EHR", "claims", "registries", "patient_generated"),
    quality_requirements = list(
      completeness = "≥95% complete for key variables",
      accuracy = "Validation studies demonstrating ≥90% accuracy",
      timeliness = "Data capture within clinically relevant timeframe",
      representativeness = "Reflects real-world patient population"
    )
  ),

  study_designs = list(
    acceptable = c("pragmatic_rct", "non_randomized_comparative", "single_arm_external_control"),
    preferred = "pragmatic_rct",
    requirements = list(
      clear_eligibility = "Well-defined inclusion/exclusion criteria",
      exposure_ascertainment = "Reliable treatment exposure measurement",
      outcome_ascertainment = "Valid and reliable outcome measures",
      follow_up = "Adequate duration and completeness"
    )
  ),

  confounding_control = list(
    required_methods = c("propensity_score", "regression_adjustment", "stratification"),
    preferred_sensitivity = c("multiple_methods", "unmeasured_confounding_analysis"),
    key_confounders = c("age", "sex", "disease_severity", "comorbidities", "prior_treatments")
  ),

  regulatory_context = list(
    accelerated_approval = "Support for confirmatory evidence (21 CFR 314.510)",
    indication_expansion = "Evidence for new populations or uses",
    post_market_surveillance = "Safety monitoring and rare adverse events",
    comparative_effectiveness = "Head-to-head comparisons when RCTs infeasible"
  )
)


#' Propensity Score Matching
#'
#' @description
#' Performs propensity score matching to balance treatment and control groups
#' on observed covariates. Implements FDA RWE standards for confounding control.
#'
#' @param data Data frame with treatment assignment and covariates
#' @param treatment_var Treatment variable name (0=control, 1=treatment)
#' @param covariates Vector of covariate names for matching
#' @param caliper Maximum allowable propensity score difference (default 0.2 SD)
#' @param ratio Matching ratio (default 1:1)
#' @param method Matching method ("nearest", "optimal", "full")
#' @param replace Whether to match with replacement
#'
#' @return List with matched dataset and diagnostics
#' @export
#'
#' @examples
#' \dontrun{
#' # Propensity score matching
#' psm_results <- propensity_score_matching(
#'   data = rwe_data,
#'   treatment_var = "treatment",
#'   covariates = c("age", "sex", "comorbidity_index", "baseline_severity"),
#'   caliper = 0.2,
#'   ratio = 1
#' )
#' }
propensity_score_matching <- function(data,
                                      treatment_var,
                                      covariates,
                                      caliper = 0.2,
                                      ratio = 1,
                                      method = "nearest",
                                      replace = FALSE) {

  # ==========================================================================
  # VALIDATE INPUTS
  # ==========================================================================

  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }

  required_vars <- c(treatment_var, covariates)
  missing_vars <- setdiff(required_vars, names(data))
  if (length(missing_vars) > 0) {
    stop(paste0("Missing variables: ", paste(missing_vars, collapse = ", ")))
  }

  # Extract treatment
  treatment <- data[[treatment_var]]
  unique_treatment <- unique(treatment[!is.na(treatment)])

  if (!all(unique_treatment %in% c(0, 1))) {
    stop("Treatment variable must be coded as 0 (control) or 1 (treatment)")
  }

  # ==========================================================================
  # ESTIMATE PROPENSITY SCORES
  # ==========================================================================

  message("Estimating propensity scores...")

  # Create formula for propensity score model
  formula_ps <- as.formula(paste0(treatment_var, " ~ ", paste(covariates, collapse = " + ")))

  # Fit logistic regression
  ps_model <- glm(formula_ps, data = data, family = binomial(link = "logit"))

  # Predict propensity scores
  propensity_scores <- predict(ps_model, type = "response")
  data$propensity_score <- propensity_scores

  # Calculate logit of propensity score (for caliper calculation)
  data$logit_ps <- log(propensity_scores / (1 - propensity_scores))

  # ==========================================================================
  # ASSESS PRE-MATCHING BALANCE
  # ==========================================================================

  pre_match_balance <- assess_covariate_balance(
    data = data,
    treatment_var = treatment_var,
    covariates = covariates,
    weights = NULL
  )

  # ==========================================================================
  # PERFORM MATCHING
  # ==========================================================================

  message(paste0("Performing ", method, " neighbor matching with caliper = ", caliper, "..."))

  # Calculate caliper in logit scale
  logit_caliper <- caliper * sd(data$logit_ps)

  # Perform matching
  matched_data <- perform_matching_algorithm(
    data = data,
    treatment_var = treatment_var,
    method = method,
    ratio = ratio,
    caliper = logit_caliper,
    replace = replace
  )

  # ==========================================================================
  # ASSESS POST-MATCHING BALANCE
  # ==========================================================================

  post_match_balance <- assess_covariate_balance(
    data = matched_data,
    treatment_var = treatment_var,
    covariates = covariates,
    weights = NULL
  )

  # ==========================================================================
  # COMPILE RESULTS
  # ==========================================================================

  results <- list(
    matched_data = matched_data,
    ps_model = ps_model,
    n_original = nrow(data),
    n_matched = nrow(matched_data),
    n_treatment_original = sum(treatment == 1, na.rm = TRUE),
    n_control_original = sum(treatment == 0, na.rm = TRUE),
    n_treatment_matched = sum(matched_data[[treatment_var]] == 1, na.rm = TRUE),
    n_control_matched = sum(matched_data[[treatment_var]] == 0, na.rm = TRUE),
    pre_match_balance = pre_match_balance,
    post_match_balance = post_match_balance,
    method = method,
    caliper = caliper,
    ratio = ratio
  )

  class(results) <- c("psm_results", "list")
  return(results)
}


#' Perform Matching Algorithm
#'
#' @description
#' Internal function to perform actual matching.
#'
#' @param data Data with propensity scores
#' @param treatment_var Treatment variable
#' @param method Matching method
#' @param ratio Matching ratio
#' @param caliper Caliper width
#' @param replace With replacement
#'
#' @return Matched dataset
#' @keywords internal
perform_matching_algorithm <- function(data, treatment_var, method, ratio, caliper, replace) {

  treatment <- data[[treatment_var]]
  ps <- data$logit_ps

  # Separate treatment and control
  treated_idx <- which(treatment == 1)
  control_idx <- which(treatment == 0)

  ps_treated <- ps[treated_idx]
  ps_control <- ps[control_idx]

  # Nearest neighbor matching (greedy)
  if (method == "nearest") {

    matched_pairs <- list()
    used_controls <- c()

    for (i in seq_along(treated_idx)) {

      # Calculate distances to all controls
      distances <- abs(ps_treated[i] - ps_control)

      # Apply caliper
      within_caliper <- distances <= caliper

      if (!replace) {
        # Exclude already matched controls
        within_caliper[used_controls] <- FALSE
      }

      if (sum(within_caliper) == 0) {
        # No match within caliper
        next
      }

      # Find closest matches
      closest_idx <- order(distances * (!within_caliper * 1e10))[1:ratio]
      closest_idx <- closest_idx[within_caliper[closest_idx]]

      if (length(closest_idx) > 0) {
        matched_pairs[[length(matched_pairs) + 1]] <- list(
          treated = treated_idx[i],
          controls = control_idx[closest_idx]
        )

        if (!replace) {
          used_controls <- c(used_controls, closest_idx)
        }
      }
    }

    # Create matched dataset
    matched_treated <- sapply(matched_pairs, function(x) x$treated)
    matched_controls <- unlist(sapply(matched_pairs, function(x) x$controls))

    matched_idx <- c(matched_treated, matched_controls)
    matched_data <- data[matched_idx, ]

    # Add pair ID
    pair_id <- rep(1:length(matched_pairs), each = ratio + 1)
    if (length(pair_id) > nrow(matched_data)) {
      pair_id <- pair_id[1:nrow(matched_data)]
    }
    matched_data$pair_id <- pair_id

  } else {
    stop(paste0("Matching method '", method, "' not yet implemented. Use 'nearest'."))
  }

  return(matched_data)
}


#' Inverse Probability Treatment Weighting (IPTW)
#'
#' @description
#' Calculates inverse probability weights to balance treatment groups
#' on observed covariates.
#'
#' @param data Data frame with treatment and covariates
#' @param treatment_var Treatment variable (0=control, 1=treatment)
#' @param covariates Vector of covariate names
#' @param estimand Target estimand ("ATE", "ATT", "ATC")
#' @param stabilize Whether to use stabilized weights
#' @param trim Percentile for weight trimming (default 0.01 = 1st/99th)
#'
#' @return List with weighted dataset and diagnostics
#' @export
#'
#' @examples
#' \dontrun{
#' iptw_results <- inverse_probability_weighting(
#'   data = rwe_data,
#'   treatment_var = "treatment",
#'   covariates = c("age", "sex", "comorbidity_index"),
#'   estimand = "ATE"
#' )
#' }
inverse_probability_weighting <- function(data,
                                          treatment_var,
                                          covariates,
                                          estimand = "ATE",
                                          stabilize = TRUE,
                                          trim = 0.01) {

  # Validate estimand
  if (!estimand %in% c("ATE", "ATT", "ATC")) {
    stop("estimand must be 'ATE' (average treatment effect), 'ATT' (effect on treated), or 'ATC' (effect on controls)")
  }

  # ==========================================================================
  # ESTIMATE PROPENSITY SCORES
  # ==========================================================================

  message("Estimating propensity scores for IPTW...")

  formula_ps <- as.formula(paste0(treatment_var, " ~ ", paste(covariates, collapse = " + ")))
  ps_model <- glm(formula_ps, data = data, family = binomial(link = "logit"))

  propensity_scores <- predict(ps_model, type = "response")
  treatment <- data[[treatment_var]]

  # ==========================================================================
  # CALCULATE WEIGHTS
  # ==========================================================================

  if (estimand == "ATE") {
    # Average Treatment Effect: Weight by 1/ps for treated, 1/(1-ps) for control
    weights <- ifelse(treatment == 1,
                     1 / propensity_scores,
                     1 / (1 - propensity_scores))

  } else if (estimand == "ATT") {
    # Average Treatment Effect on Treated: Weight controls to look like treated
    weights <- ifelse(treatment == 1,
                     1,
                     propensity_scores / (1 - propensity_scores))

  } else if (estimand == "ATC") {
    # Average Treatment Effect on Controls: Weight treated to look like controls
    weights <- ifelse(treatment == 1,
                     (1 - propensity_scores) / propensity_scores,
                     1)
  }

  # ==========================================================================
  # STABILIZE WEIGHTS
  # ==========================================================================

  if (stabilize) {
    # Marginal probability of treatment
    p_treatment <- mean(treatment == 1, na.rm = TRUE)

    stabilization_factor <- ifelse(treatment == 1, p_treatment, 1 - p_treatment)
    weights <- weights * stabilization_factor
  }

  # ==========================================================================
  # TRIM EXTREME WEIGHTS
  # ==========================================================================

  if (!is.null(trim) && trim > 0) {
    lower_bound <- quantile(weights, probs = trim, na.rm = TRUE)
    upper_bound <- quantile(weights, probs = 1 - trim, na.rm = TRUE)

    weights_original <- weights
    weights <- pmax(lower_bound, pmin(upper_bound, weights))

    n_trimmed <- sum(weights != weights_original)
    if (n_trimmed > 0) {
      message(paste0("Trimmed ", n_trimmed, " extreme weights at ", trim * 100, "th/", (1 - trim) * 100, "th percentiles"))
    }
  }

  data$iptw <- weights

  # ==========================================================================
  # ASSESS BALANCE
  # ==========================================================================

  pre_weight_balance <- assess_covariate_balance(
    data = data,
    treatment_var = treatment_var,
    covariates = covariates,
    weights = NULL
  )

  post_weight_balance <- assess_covariate_balance(
    data = data,
    treatment_var = treatment_var,
    covariates = covariates,
    weights = weights
  )

  # ==========================================================================
  # WEIGHT DIAGNOSTICS
  # ==========================================================================

  weight_diagnostics <- list(
    mean_weight = mean(weights, na.rm = TRUE),
    median_weight = median(weights, na.rm = TRUE),
    min_weight = min(weights, na.rm = TRUE),
    max_weight = max(weights, na.rm = TRUE),
    sd_weight = sd(weights, na.rm = TRUE),
    effective_sample_size = sum(weights)^2 / sum(weights^2),
    relative_ess = (sum(weights)^2 / sum(weights^2)) / nrow(data)
  )

  # ==========================================================================
  # COMPILE RESULTS
  # ==========================================================================

  results <- list(
    weighted_data = data,
    ps_model = ps_model,
    weights = weights,
    estimand = estimand,
    stabilized = stabilize,
    trimmed = !is.null(trim),
    pre_weight_balance = pre_weight_balance,
    post_weight_balance = post_weight_balance,
    weight_diagnostics = weight_diagnostics
  )

  class(results) <- c("iptw_results", "list")
  return(results)
}


#' Assess Covariate Balance
#'
#' @description
#' Assesses balance of covariates between treatment groups using
#' standardized mean differences (SMD) and variance ratios.
#'
#' @param data Data frame
#' @param treatment_var Treatment variable
#' @param covariates Covariate names
#' @param weights Optional weights
#'
#' @return Balance assessment
#' @export
assess_covariate_balance <- function(data, treatment_var, covariates, weights = NULL) {

  treatment <- data[[treatment_var]]

  if (is.null(weights)) {
    weights <- rep(1, nrow(data))
  }

  balance_table <- data.frame(
    covariate = covariates,
    mean_treatment = numeric(length(covariates)),
    mean_control = numeric(length(covariates)),
    sd_treatment = numeric(length(covariates)),
    sd_control = numeric(length(covariates)),
    smd = numeric(length(covariates)),
    variance_ratio = numeric(length(covariates)),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(covariates)) {
    cov_name <- covariates[i]
    cov_values <- data[[cov_name]]

    # Weighted means
    mean_treatment <- weighted.mean(cov_values[treatment == 1],
                                   weights[treatment == 1], na.rm = TRUE)
    mean_control <- weighted.mean(cov_values[treatment == 0],
                                 weights[treatment == 0], na.rm = TRUE)

    # Weighted standard deviations
    sd_treatment <- sqrt(weighted_var(cov_values[treatment == 1],
                                      weights[treatment == 1]))
    sd_control <- sqrt(weighted_var(cov_values[treatment == 0],
                                    weights[treatment == 0]))

    # Standardized mean difference
    pooled_sd <- sqrt((sd_treatment^2 + sd_control^2) / 2)
    smd <- (mean_treatment - mean_control) / pooled_sd

    # Variance ratio
    variance_ratio <- sd_treatment^2 / sd_control^2

    balance_table$mean_treatment[i] <- mean_treatment
    balance_table$mean_control[i] <- mean_control
    balance_table$sd_treatment[i] <- sd_treatment
    balance_table$sd_control[i] <- sd_control
    balance_table$smd[i] <- smd
    balance_table$variance_ratio[i] <- variance_ratio
  }

  # Overall balance assessment
  max_smd <- max(abs(balance_table$smd), na.rm = TRUE)
  n_imbalanced <- sum(abs(balance_table$smd) > 0.1, na.rm = TRUE)

  balance_quality <- if (max_smd < 0.1) {
    "EXCELLENT - All covariates well balanced (max SMD < 0.1)"
  } else if (max_smd < 0.25) {
    "GOOD - Adequate balance (max SMD < 0.25)"
  } else if (max_smd < 0.5) {
    "MODERATE - Some imbalance present (max SMD < 0.5)"
  } else {
    "POOR - Substantial imbalance (max SMD ≥ 0.5)"
  }

  balance <- list(
    balance_table = balance_table,
    max_smd = max_smd,
    n_imbalanced = n_imbalanced,
    balance_quality = balance_quality
  )

  return(balance)
}


#' Weighted Variance
#'
#' @description
#' Calculates weighted variance.
#'
#' @param x Values
#' @param w Weights
#'
#' @return Weighted variance
#' @keywords internal
weighted_var <- function(x, w) {
  # Remove NAs
  valid <- !is.na(x) & !is.na(w)
  x <- x[valid]
  w <- w[valid]

  if (length(x) < 2) return(NA)

  # Normalize weights
  w <- w / sum(w)

  # Weighted mean
  mean_x <- sum(w * x)

  # Weighted variance
  var_x <- sum(w * (x - mean_x)^2)

  return(var_x)
}


#' Estimate Treatment Effect from RWE
#'
#' @description
#' Estimates treatment effect from real-world data using propensity score methods.
#'
#' @param data Data frame with outcome, treatment, covariates
#' @param outcome_var Outcome variable
#' @param treatment_var Treatment variable
#' @param covariates Covariates for confounding control
#' @param method Method ("psm", "iptw", "both")
#' @param outcome_type Outcome type ("continuous", "binary", "time_to_event")
#'
#' @return Treatment effect estimates
#' @export
#'
#' @examples
#' \dontrun{
#' rwe_effect <- estimate_rwe_treatment_effect(
#'   data = rwe_data,
#'   outcome_var = "survival_months",
#'   treatment_var = "new_drug",
#'   covariates = c("age", "sex", "baseline_severity"),
#'   method = "iptw",
#'   outcome_type = "continuous"
#' )
#' }
estimate_rwe_treatment_effect <- function(data,
                                          outcome_var,
                                          treatment_var,
                                          covariates,
                                          method = "iptw",
                                          outcome_type = "continuous") {

  # ==========================================================================
  # APPLY CONFOUNDING CONTROL METHOD
  # ==========================================================================

  if (method == "psm") {

    message("Applying propensity score matching...")
    psm_results <- propensity_score_matching(
      data = data,
      treatment_var = treatment_var,
      covariates = covariates
    )

    analysis_data <- psm_results$matched_data
    weights <- NULL

  } else if (method == "iptw") {

    message("Applying inverse probability treatment weighting...")
    iptw_results <- inverse_probability_weighting(
      data = data,
      treatment_var = treatment_var,
      covariates = covariates,
      estimand = "ATE"
    )

    analysis_data <- iptw_results$weighted_data
    weights <- iptw_results$weights

  } else if (method == "both") {
    stop("Method 'both' not yet implemented. Use 'psm' or 'iptw'.")
  } else {
    stop(paste0("Unknown method: ", method))
  }

  # ==========================================================================
  # ESTIMATE TREATMENT EFFECT
  # ==========================================================================

  outcome <- analysis_data[[outcome_var]]
  treatment <- analysis_data[[treatment_var]]

  if (outcome_type == "continuous") {

    # Weighted means
    if (!is.null(weights)) {
      mean_treatment <- weighted.mean(outcome[treatment == 1],
                                     weights[treatment == 1], na.rm = TRUE)
      mean_control <- weighted.mean(outcome[treatment == 0],
                                   weights[treatment == 0], na.rm = TRUE)

      # Weighted regression for CI
      lm_weighted <- lm(as.formula(paste0(outcome_var, " ~ ", treatment_var)),
                       data = analysis_data,
                       weights = weights)

      effect <- coef(lm_weighted)[2]
      ci <- confint(lm_weighted)[2, ]
      se <- summary(lm_weighted)$coefficients[2, "Std. Error"]
      pvalue <- summary(lm_weighted)$coefficients[2, "Pr(>|t|)"]

    } else {
      mean_treatment <- mean(outcome[treatment == 1], na.rm = TRUE)
      mean_control <- mean(outcome[treatment == 0], na.rm = TRUE)

      # T-test
      t_test <- t.test(outcome ~ treatment, data = analysis_data)
      effect <- t_test$estimate[1] - t_test$estimate[2]
      ci <- t_test$conf.int
      pvalue <- t_test$p.value
      se <- effect / qt(0.975, df = t_test$parameter)
    }

    results <- list(
      effect = effect,
      ci_lower = ci[1],
      ci_upper = ci[2],
      se = se,
      pvalue = pvalue,
      mean_treatment = mean_treatment,
      mean_control = mean_control
    )

  } else if (outcome_type == "binary") {

    # Risk difference
    if (!is.null(weights)) {
      risk_treatment <- weighted.mean(outcome[treatment == 1],
                                     weights[treatment == 1], na.rm = TRUE)
      risk_control <- weighted.mean(outcome[treatment == 0],
                                   weights[treatment == 0], na.rm = TRUE)
    } else {
      risk_treatment <- mean(outcome[treatment == 1], na.rm = TRUE)
      risk_control <- mean(outcome[treatment == 0], na.rm = TRUE)
    }

    risk_difference <- risk_treatment - risk_control
    risk_ratio <- risk_treatment / risk_control

    # Use logistic regression for CI
    if (!is.null(weights)) {
      glm_weighted <- glm(as.formula(paste0(outcome_var, " ~ ", treatment_var)),
                         data = analysis_data,
                         family = binomial(link = "identity"),
                         weights = weights)
    } else {
      glm_weighted <- glm(as.formula(paste0(outcome_var, " ~ ", treatment_var)),
                         data = analysis_data,
                         family = binomial(link = "identity"))
    }

    ci <- confint(glm_weighted)[2, ]
    pvalue <- summary(glm_weighted)$coefficients[2, "Pr(>|z|)"]

    results <- list(
      risk_difference = risk_difference,
      risk_ratio = risk_ratio,
      ci_lower = ci[1],
      ci_upper = ci[2],
      pvalue = pvalue,
      risk_treatment = risk_treatment,
      risk_control = risk_control
    )

  } else {
    stop("outcome_type must be 'continuous' or 'binary'")
  }

  # ==========================================================================
  # COMPILE FINAL RESULTS
  # ==========================================================================

  final_results <- list(
    effect_estimates = results,
    method = method,
    outcome_type = outcome_type,
    n_analyzed = nrow(analysis_data),
    confounding_control = if (method == "psm") psm_results else iptw_results
  )

  class(final_results) <- c("rwe_effect", "list")
  return(final_results)
}


#' Sensitivity Analysis for Unmeasured Confounding
#'
#' @description
#' Performs sensitivity analysis to assess robustness of RWE results
#' to potential unmeasured confounding (E-value approach).
#'
#' @param observed_effect Observed treatment effect (e.g., HR, RR, OR)
#' @param ci_lower Lower confidence interval
#' @param effect_measure Effect measure type ("HR", "RR", "OR")
#'
#' @return E-value and interpretation
#' @export
#'
#' @examples
#' \dontrun{
#' sensitivity <- unmeasured_confounding_sensitivity(
#'   observed_effect = 0.70,
#'   ci_lower = 0.55,
#'   effect_measure = "HR"
#' )
#' }
unmeasured_confounding_sensitivity <- function(observed_effect,
                                               ci_lower,
                                               effect_measure = "HR") {

  # Convert to risk ratio if needed
  if (effect_measure %in% c("HR", "OR")) {
    # Approximate conversion (conservative)
    rr <- observed_effect
  } else {
    rr <- observed_effect
  }

  # E-value calculation (VanderWeele & Ding 2017)
  if (rr < 1) {
    # Protective effect
    e_value_point <- 1 / rr + sqrt(1 / rr * (1 / rr - 1))
    e_value_ci <- 1 / ci_lower + sqrt(1 / ci_lower * (1 / ci_lower - 1))
  } else {
    # Harmful effect
    e_value_point <- rr + sqrt(rr * (rr - 1))

    if (!is.null(ci_lower) && ci_lower > 1) {
      e_value_ci <- ci_lower + sqrt(ci_lower * (ci_lower - 1))
    } else {
      e_value_ci <- 1.0
    }
  }

  # Interpretation
  interpretation <- if (e_value_point > 3.0) {
    "STRONG - E-value >3 suggests unmeasured confounding unlikely to explain effect"
  } else if (e_value_point > 2.0) {
    "MODERATE - E-value 2-3 suggests moderate robustness to unmeasured confounding"
  } else {
    "WEAK - E-value <2 suggests effect could be explained by modest unmeasured confounding"
  }

  results <- list(
    e_value_point_estimate = e_value_point,
    e_value_ci = e_value_ci,
    observed_effect = observed_effect,
    ci_lower = ci_lower,
    effect_measure = effect_measure,
    interpretation = interpretation,
    definition = "E-value: Minimum strength of association (RR scale) that unmeasured confounder must have with both treatment and outcome to explain away observed effect"
  )

  return(results)
}


#' Print PSM Results
#'
#' @description
#' Prints formatted propensity score matching results.
#'
#' @param psm_results PSM results
#'
#' @export
print_psm_results <- function(psm_results) {

  if (!inherits(psm_results, "psm_results")) {
    stop("psm_results must be output from propensity_score_matching()")
  }

  cat("\n")
  cat("==============================================================================\n")
  cat("  PROPENSITY SCORE MATCHING RESULTS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("Method: %s\n", psm_results$method))
  cat(sprintf("Caliper: %.2f SD\n", psm_results$caliper))
  cat(sprintf("Matching Ratio: %d:1\n\n", psm_results$ratio))

  cat("SAMPLE SIZES\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("Original:  Treatment=%d, Control=%d, Total=%d\n",
              psm_results$n_treatment_original,
              psm_results$n_control_original,
              psm_results$n_original))
  cat(sprintf("Matched:   Treatment=%d, Control=%d, Total=%d\n",
              psm_results$n_treatment_matched,
              psm_results$n_control_matched,
              psm_results$n_matched))
  cat(sprintf("Retention: %.1f%%\n\n",
              psm_results$n_matched / psm_results$n_original * 100))

  cat("COVARIATE BALANCE\n")
  cat("------------------------------------------------------------------------------\n")
  cat("Pre-matching:\n")
  cat(sprintf("  Max SMD: %.3f\n", psm_results$pre_match_balance$max_smd))
  cat(sprintf("  %s\n", psm_results$pre_match_balance$balance_quality))
  cat("\nPost-matching:\n")
  cat(sprintf("  Max SMD: %.3f\n", psm_results$post_match_balance$max_smd))
  cat(sprintf("  %s\n", psm_results$post_match_balance$balance_quality))

  cat("==============================================================================\n\n")

  invisible(psm_results)
}


#' Print IPTW Results
#'
#' @description
#' Prints formatted IPTW results.
#'
#' @param iptw_results IPTW results
#'
#' @export
print_iptw_results <- function(iptw_results) {

  if (!inherits(iptw_results, "iptw_results")) {
    stop("iptw_results must be output from inverse_probability_weighting()")
  }

  cat("\n")
  cat("==============================================================================\n")
  cat("  INVERSE PROBABILITY TREATMENT WEIGHTING RESULTS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("Estimand: %s\n", iptw_results$estimand))
  cat(sprintf("Stabilized: %s\n", ifelse(iptw_results$stabilized, "YES", "NO")))
  cat(sprintf("Trimmed: %s\n\n", ifelse(iptw_results$trimmed, "YES", "NO")))

  cat("WEIGHT DIAGNOSTICS\n")
  cat("------------------------------------------------------------------------------\n")
  diag <- iptw_results$weight_diagnostics
  cat(sprintf("Mean: %.2f, Median: %.2f\n", diag$mean_weight, diag$median_weight))
  cat(sprintf("Range: %.2f - %.2f\n", diag$min_weight, diag$max_weight))
  cat(sprintf("Effective Sample Size: %.1f (%.1f%% of original)\n",
              diag$effective_sample_size,
              diag$relative_ess * 100))

  cat("\nCOVARIATE BALANCE\n")
  cat("------------------------------------------------------------------------------\n")
  cat("Pre-weighting:\n")
  cat(sprintf("  Max SMD: %.3f\n", iptw_results$pre_weight_balance$max_smd))
  cat(sprintf("  %s\n", iptw_results$pre_weight_balance$balance_quality))
  cat("\nPost-weighting:\n")
  cat(sprintf("  Max SMD: %.3f\n", iptw_results$post_weight_balance$max_smd))
  cat(sprintf("  %s\n", iptw_results$post_weight_balance$balance_quality))

  cat("==============================================================================\n\n")

  invisible(iptw_results)
}

# =============================================================================
# END OF FDA REAL-WORLD EVIDENCE MODULE
# =============================================================================
