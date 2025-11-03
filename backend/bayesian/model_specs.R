# ============================================================================
# Bayesian NMA - Model Specification Module
# ============================================================================
# Defines brms formulas and priors for Bayesian network meta-analysis
# Reference: Bürkner (2021) brms paper, gemtc package
# ============================================================================

library(brms)
library(dplyr)

#' Build brms Formula for NMA
#'
#' Constructs appropriate brms formula based on model type and data structure
#'
#' @param model_type "fixed" or "random" effects
#' @param outcome_type "continuous", "binary", "count", "time_to_event"
#' @param include_study_effects Logical, include study-specific intercepts
#' @return brmsformula object
#' @export
build_nma_brms_formula <- function(model_type = "random",
                                   outcome_type = "continuous",
                                   include_study_effects = TRUE) {

  if (outcome_type == "continuous") {
    # Contrast-based model for continuous outcomes

    if (model_type == "fixed") {
      # Fixed effects NMA
      formula <- bf(
        contrast | se(seTE) ~ 0 + treat2_id,
        family = gaussian()
      )

    } else if (model_type == "random") {
      # Random effects NMA with between-study heterogeneity
      if (include_study_effects) {
        formula <- bf(
          contrast | se(seTE) ~ 0 + treat2_id + (1 | study),
          family = gaussian()
        )
      } else {
        # Simpler version without study random effects
        formula <- bf(
          contrast | se(seTE) ~ 0 + treat2_id,
          sigma ~ 1,  # Allow heterogeneity estimation
          family = gaussian()
        )
      }
    }

  } else if (outcome_type == "binary") {
    # ARM-based model for binary outcomes (logistic regression)

    if (model_type == "fixed") {
      formula <- bf(
        events | trials(total) ~ 0 + treat_id,
        family = binomial(link = "logit")
      )

    } else {
      formula <- bf(
        events | trials(total) ~ 0 + treat_id + (1 | study),
        family = binomial(link = "logit")
      )
    }

  } else if (outcome_type == "count") {
    # Poisson or negative binomial for count outcomes

    if (model_type == "fixed") {
      formula <- bf(
        events ~ 0 + treat_id + offset(log(person_years)),
        family = poisson()
      )

    } else {
      formula <- bf(
        events ~ 0 + treat_id + offset(log(person_years)) + (1 | study),
        family = negbinomial()  # Overdispersion
      )
    }

  } else {
    stop("outcome_type must be one of: continuous, binary, count")
  }

  return(formula)
}


#' Specify Prior Distributions for NMA
#'
#' Creates appropriate prior specifications for treatment effects and heterogeneity
#'
#' @param prior_type "vague", "weakly_informative", "informative", or "custom"
#' @param n_treatments Number of treatments in network
#' @param custom_priors Optional list of custom prior specifications
#' @return brmsprior object
#' @export
specify_nma_priors <- function(prior_type = "weakly_informative",
                               n_treatments,
                               custom_priors = NULL) {

  if (prior_type == "vague") {
    # Very flat priors (not recommended but sometimes needed)
    priors <- c(
      prior(normal(0, 10), class = b),        # Treatment effects
      prior(cauchy(0, 5), class = sd)         # Between-study heterogeneity
    )

  } else if (prior_type == "weakly_informative") {
    # Recommended default: mildly informative but broad
    priors <- c(
      prior(normal(0, 1.5), class = b),       # Treatment effects (log scale)
      prior(cauchy(0, 0.5), class = sd),      # Heterogeneity (skeptical)
      prior(normal(0, 1), class = Intercept)  # Study intercepts if present
    )

  } else if (prior_type == "informative") {
    # Based on external evidence (e.g., Cochrane empirical distributions)
    # Turner et al. (2012) - typical heterogeneity by outcome type

    priors <- c(
      prior(normal(0, 0.8), class = b),       # Treatment effects
      prior(normal(0, 0.3), class = sd,       # Heterogeneity for subjective outcomes
            lb = 0),                          # Lower bound at 0
      prior(normal(0, 1), class = Intercept)
    )

  } else if (prior_type == "custom" && !is.null(custom_priors)) {
    # User-specified priors
    priors <- do.call(c, custom_priors)

  } else {
    stop("Invalid prior_type or missing custom_priors")
  }

  return(priors)
}


#' Build Full brms Model Specification
#'
#' Combines formula and priors into complete model specification
#'
#' @param brms_data Data from data_prep.R
#' @param model_type "fixed" or "random"
#' @param outcome_type Type of outcome
#' @param prior_type Prior specification
#' @param custom_priors Optional custom priors
#' @return List with formula, priors, and data ready for brm()
#' @export
build_full_nma_model <- function(brms_data,
                                 model_type = "random",
                                 outcome_type = "continuous",
                                 prior_type = "weakly_informative",
                                 custom_priors = NULL) {

  # Get treatment count
  treat_map <- attr(brms_data, "treatment_map")
  n_treatments <- nrow(treat_map)

  # Build formula
  formula <- build_nma_brms_formula(
    model_type = model_type,
    outcome_type = outcome_type,
    include_study_effects = TRUE
  )

  # Specify priors
  priors <- specify_nma_priors(
    prior_type = prior_type,
    n_treatments = n_treatments,
    custom_priors = custom_priors
  )

  # Return complete specification
  list(
    formula = formula,
    priors = priors,
    data = brms_data,
    treat_map = treat_map,
    model_type = model_type,
    outcome_type = outcome_type
  )
}


#' Create Inconsistency Model Formula
#'
#' For node-splitting or design-inconsistency models
#'
#' @param base_formula Base consistency model formula
#' @param inconsistency_type "node_split" or "design"
#' @return Modified formula with inconsistency parameters
#' @export
add_inconsistency_terms <- function(base_formula, inconsistency_type = "node_split") {

  # TODO: Implement inconsistency model extensions
  # This is complex and requires careful handling of:
  # 1. Direct vs indirect evidence separation
  # 2. Additional random effects for inconsistency
  # 3. Proper parameterization to avoid identifiability issues

  stop("Inconsistency models not yet implemented in brms backend.")
  stop("Use netmeta::netsplit() or gemtc package for inconsistency assessment.")
}


#' Get Recommended MCMC Settings
#'
#' Provides recommended sampling parameters based on network complexity
#'
#' @param n_treatments Number of treatments
#' @param n_studies Number of studies
#' @param model_type "fixed" or "random"
#' @return List with recommended chains, iter, warmup, thin
#' @export
get_recommended_mcmc_settings <- function(n_treatments, n_studies, model_type = "random") {

  # Base settings
  chains <- 4
  cores <- min(4, parallel::detectCores() - 1)

  # Adjust based on complexity
  if (n_treatments <= 5 && n_studies <= 20) {
    # Simple network
    iter <- 4000
    warmup <- 2000
    thin <- 1

  } else if (n_treatments <= 10 && n_studies <= 50) {
    # Medium network
    iter <- 6000
    warmup <- 3000
    thin <- 2

  } else {
    # Complex network
    iter <- 10000
    warmup <- 5000
    thin <- 4
  }

  # Fixed effects models converge faster
  if (model_type == "fixed") {
    iter <- iter * 0.6
    warmup <- warmup * 0.6
  }

  list(
    chains = chains,
    cores = cores,
    iter = round(iter),
    warmup = round(warmup),
    thin = thin,
    control = list(
      adapt_delta = 0.95,        # Higher for complex posteriors
      max_treedepth = 12         # Increase if needed
    )
  )
}


#' Validate Model Specification
#'
#' Checks if model specification is sensible before sampling
#'
#' @param model_spec List from build_full_nma_model
#' @return List with is_valid (logical) and messages (character vector)
#' @export
validate_model_specification <- function(model_spec) {

  messages <- character(0)
  is_valid <- TRUE

  # Check formula
  if (is.null(model_spec$formula)) {
    messages <- c(messages, "Formula is NULL")
    is_valid <- FALSE
  }

  # Check priors
  if (is.null(model_spec$priors)) {
    messages <- c(messages, "Priors are NULL")
    is_valid <- FALSE
  }

  # Check data
  if (nrow(model_spec$data) < 3) {
    messages <- c(messages, "Insufficient data (< 3 comparisons)")
    is_valid <- FALSE
  }

  # Check for disconnected network
  conn_matrix <- create_connectivity_matrix(model_spec$data)
  conn_check <- validate_network_connectivity(conn_matrix)

  if (!conn_check$is_connected) {
    messages <- c(messages,
                 paste("Network is disconnected. Components:", conn_check$n_components),
                 paste("Disconnected treatments:", paste(conn_check$disconnected_treatments, collapse = ", ")))
    is_valid <- FALSE
  }

  # Check for multi-arm trials
  multi_arm <- handle_multi_arm_trials(model_spec$data)
  if (multi_arm$has_multi_arm) {
    messages <- c(messages,
                 paste("Warning: Multi-arm trials detected (n =", multi_arm$n_multi_arm, ")"),
                 "Multi-arm trial handling not fully implemented. Results may be biased.")
    # Don't set is_valid = FALSE, just warn
  }

  list(
    is_valid = is_valid,
    messages = messages,
    warnings = if (multi_arm$has_multi_arm) multi_arm else NULL
  )
}
