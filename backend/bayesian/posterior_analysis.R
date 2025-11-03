# ============================================================================
# Bayesian NMA - Posterior Analysis Module
# ============================================================================
# Extracts treatment effects, rankings, SUCRA scores, and probability statements
# Reference: Salanti et al. (2011) SUCRA methodology
# ============================================================================

library(brms)
library(dplyr)
library(tidyr)
library(posterior)

#' Extract Treatment Effects from Posterior
#'
#' Get relative treatment effects (vs reference) with credible intervals
#'
#' @param fit brmsfit object from run_brms_nma()
#' @param reference_treatment Name of reference treatment (default: first alphabetically)
#' @param prob Credible interval probability (default: 0.95)
#' @return data.frame with treatment effects and CrIs
#' @export
extract_treatment_effects <- function(fit, reference_treatment = NULL, prob = 0.95) {

  # Get treatment mapping
  treat_map <- fit$evidenceos_meta$model_spec$treat_map

  if (is.null(reference_treatment)) {
    reference_treatment <- treat_map$treatment[1]
    message("Using ", reference_treatment, " as reference treatment")
  }

  # Extract fixed effects (treatment coefficients)
  # These are log-OR, log-RR, or mean differences depending on outcome type
  posterior_draws <- as_draws_df(fit)

  # Get treatment effect columns
  treat_cols <- grep("^b_treat", names(posterior_draws), value = TRUE)

  if (length(treat_cols) == 0) {
    stop("No treatment effects found in posterior. Check model specification.")
  }

  # Calculate summary statistics
  effects_summary <- posterior_draws %>%
    select(all_of(treat_cols)) %>%
    summarise(across(
      everything(),
      list(
        mean = ~mean(.x),
        median = ~median(.x),
        sd = ~sd(.x),
        lower = ~quantile(.x, probs = (1 - prob) / 2),
        upper = ~quantile(.x, probs = 1 - (1 - prob) / 2)
      ),
      .names = "{.col}_{.fn}"
    ))

  # Reshape to long format
  effects_long <- effects_summary %>%
    pivot_longer(
      everything(),
      names_to = c("parameter", ".value"),
      names_pattern = "(.*)_(mean|median|sd|lower|upper)"
    ) %>%
    mutate(
      treatment = gsub("b_treat2_id", "", parameter),
      treatment = treat_map$treatment[as.numeric(treatment)]
    )

  # Add reference treatment (effect = 0)
  ref_row <- data.frame(
    parameter = paste0("b_treat2_id", which(treat_map$treatment == reference_treatment)),
    mean = 0,
    median = 0,
    sd = 0,
    lower = 0,
    upper = 0,
    treatment = reference_treatment
  )

  effects_final <- bind_rows(ref_row, effects_long) %>%
    arrange(mean) %>%
    select(treatment, mean, median, sd, lower, upper)

  return(effects_final)
}


#' Calculate Treatment Rankings
#'
#' Rank treatments based on posterior samples (1 = best)
#'
#' @param fit brmsfit object
#' @param direction "higher_better" (e.g., efficacy) or "lower_better" (e.g., adverse events)
#' @return Matrix [iterations × treatments] with ranks
#' @export
calculate_treatment_rankings <- function(fit, direction = "higher_better") {

  # Extract posterior samples
  posterior_draws <- as_draws_df(fit)
  treat_cols <- grep("^b_treat", names(posterior_draws), value = TRUE)

  if (length(treat_cols) == 0) {
    stop("No treatment effects found")
  }

  # Extract treatment effects matrix [iterations × treatments]
  effects_matrix <- as.matrix(posterior_draws[, treat_cols])

  # Rank each iteration
  n_iter <- nrow(effects_matrix)
  n_treat <- ncol(effects_matrix)

  rankings <- matrix(NA, nrow = n_iter, ncol = n_treat)

  for (i in 1:n_iter) {
    if (direction == "higher_better") {
      # Higher effect = better (rank 1)
      rankings[i, ] <- rank(-effects_matrix[i, ], ties.method = "average")
    } else {
      # Lower effect = better (rank 1)
      rankings[i, ] <- rank(effects_matrix[i, ], ties.method = "average")
    }
  }

  # Add treatment names
  treat_map <- fit$evidenceos_meta$model_spec$treat_map
  colnames(rankings) <- treat_map$treatment

  return(rankings)
}


#' Compute SUCRA Scores
#'
#' Surface Under the Cumulative Ranking curve
#' SUCRA = 1 (best possible), SUCRA = 0 (worst possible)
#'
#' @param rankings Matrix from calculate_treatment_rankings()
#' @return data.frame with SUCRA scores and mean ranks
#' @export
compute_sucra_scores <- function(rankings) {

  n_treat <- ncol(rankings)

  sucra_scores <- data.frame(
    treatment = colnames(rankings),
    mean_rank = colMeans(rankings),
    median_rank = apply(rankings, 2, median),
    sucra = NA,
    stringsAsFactors = FALSE
  )

  # SUCRA formula: (n-1 - sum of cumulative ranks) / (n-1)
  # Or equivalently: 1 - (mean_rank - 1) / (n_treat - 1)
  sucra_scores$sucra <- 1 - (sucra_scores$mean_rank - 1) / (n_treat - 1)

  # Ensure SUCRA in [0, 1]
  sucra_scores$sucra <- pmax(0, pmin(1, sucra_scores$sucra))

  # Sort by SUCRA (descending)
  sucra_scores <- sucra_scores %>%
    arrange(desc(sucra))

  return(sucra_scores)
}


#' Generate Rankogram
#'
#' Probability of each treatment being at each rank
#'
#' @param rankings Matrix from calculate_treatment_rankings()
#' @return data.frame with probabilities for plotting
#' @export
generate_rankogram_data <- function(rankings) {

  n_treat <- ncol(rankings)

  rankogram <- data.frame()

  for (treat_idx in 1:n_treat) {
    treatment <- colnames(rankings)[treat_idx]

    for (rank in 1:n_treat) {
      prob <- mean(rankings[, treat_idx] == rank)

      rankogram <- bind_rows(rankogram, data.frame(
        treatment = treatment,
        rank = rank,
        probability = prob
      ))
    }
  }

  return(rankogram)
}


#' Calculate Probability Statements
#'
#' Probability that treatment A is better than treatment B
#'
#' @param fit brmsfit object
#' @param treatment_a Name of treatment A
#' @param treatment_b Name of treatment B
#' @param direction "higher_better" or "lower_better"
#' @return Numeric probability [0, 1]
#' @export
calculate_probability_better <- function(fit, treatment_a, treatment_b, direction = "higher_better") {

  # Extract posterior samples
  posterior_draws <- as_draws_df(fit)
  treat_map <- fit$evidenceos_meta$model_spec$treat_map

  # Find treatment IDs
  id_a <- which(treat_map$treatment == treatment_a)
  id_b <- which(treat_map$treatment == treatment_b)

  if (length(id_a) == 0 || length(id_b) == 0) {
    stop("Treatment not found in model")
  }

  # Extract effects
  effect_a <- posterior_draws[[paste0("b_treat2_id", id_a)]]
  effect_b <- posterior_draws[[paste0("b_treat2_id", id_b)]]

  # Calculate probability
  if (direction == "higher_better") {
    prob <- mean(effect_a > effect_b)
  } else {
    prob <- mean(effect_a < effect_b)
  }

  return(prob)
}


#' Create League Table
#'
#' Pairwise comparisons with credible intervals
#'
#' @param fit brmsfit object
#' @param prob Credible interval probability
#' @return Matrix of pairwise comparisons
#' @export
create_league_table <- function(fit, prob = 0.95) {

  treat_map <- fit$evidenceos_meta$model_spec$treat_map
  n_treat <- nrow(treat_map)
  treatments <- treat_map$treatment

  # Initialize matrix
  league <- matrix("", nrow = n_treat, ncol = n_treat)
  rownames(league) <- colnames(league) <- treatments

  # Extract posterior samples
  posterior_draws <- as_draws_df(fit)

  # Fill upper triangle with comparisons
  for (i in 1:(n_treat - 1)) {
    for (j in (i + 1):n_treat) {

      treat_i <- treatments[i]
      treat_j <- treatments[j]

      # Get effects
      effect_i <- posterior_draws[[paste0("b_treat2_id", i)]]
      effect_j <- posterior_draws[[paste0("b_treat2_id", j)]]

      # Calculate difference (i vs j)
      diff <- effect_i - effect_j

      # Summary statistics
      mean_diff <- mean(diff)
      lower_diff <- quantile(diff, probs = (1 - prob) / 2)
      upper_diff <- quantile(diff, probs = 1 - (1 - prob) / 2)

      # Format as string
      league[i, j] <- sprintf("%.2f (%.2f, %.2f)", mean_diff, lower_diff, upper_diff)

      # Mirror for lower triangle (j vs i)
      league[j, i] <- sprintf("%.2f (%.2f, %.2f)", -mean_diff, -upper_diff, -lower_diff)
    }
  }

  # Diagonal is treatment names
  diag(league) <- treatments

  return(league)
}


#' Extract Heterogeneity Parameter
#'
#' Between-study standard deviation (tau) for random effects models
#'
#' @param fit brmsfit object
#' @param prob Credible interval probability
#' @return data.frame with tau estimates
#' @export
extract_heterogeneity <- function(fit) {

  model_type <- fit$evidenceos_meta$model_spec$model_type

  if (model_type == "fixed") {
    return(data.frame(
      parameter = "tau",
      estimate = 0,
      lower = 0,
      upper = 0,
      note = "Fixed effects model (no heterogeneity)"
    ))
  }

  # Extract between-study SD
  tau_samples <- as_draws_df(fit) %>%
    select(matches("sd_study__Intercept|sigma"))

  if (ncol(tau_samples) == 0) {
    warning("Could not extract heterogeneity parameter")
    return(NULL)
  }

  tau_summary <- tau_samples %>%
    summarise(across(
      everything(),
      list(
        mean = ~mean(.x),
        median = ~median(.x),
        sd = ~sd(.x),
        lower = ~quantile(.x, probs = 0.025),
        upper = ~quantile(.x, probs = 0.975)
      )
    ))

  return(tau_summary)
}


#' Calculate Predictive Interval
#'
#' Predictive interval for effect in a new study
#'
#' @param fit brmsfit object
#' @param treatment Treatment to predict
#' @param prob Interval probability
#' @return Predictive interval bounds
#' @export
calculate_predictive_interval <- function(fit, treatment, prob = 0.95) {

  # TODO: Implement proper predictive distribution
  # This requires:
  # 1. Extracting posterior of mean effect
  # 2. Extracting posterior of tau (heterogeneity)
  # 3. Sampling from t-distribution with mean ~ Normal(theta, tau^2)

  stop("Predictive intervals not yet implemented")
  stop("Use posterior_predict() from brms for new predictions")
}


#' Create Posterior Summary Report
#'
#' Comprehensive summary of posterior inference
#'
#' @param fit brmsfit object
#' @param direction "higher_better" or "lower_better"
#' @return List with all posterior summaries
#' @export
create_posterior_summary <- function(fit, direction = "higher_better") {

  # Treatment effects
  effects <- extract_treatment_effects(fit)

  # Rankings and SUCRA
  rankings <- calculate_treatment_rankings(fit, direction = direction)
  sucra <- compute_sucra_scores(rankings)
  rankogram <- generate_rankogram_data(rankings)

  # League table
  league <- create_league_table(fit)

  # Heterogeneity
  heterogeneity <- extract_heterogeneity(fit)

  # Model info
  model_info <- list(
    model_type = fit$evidenceos_meta$model_spec$model_type,
    outcome_type = fit$evidenceos_meta$model_spec$outcome_type,
    n_treatments = nrow(fit$evidenceos_meta$model_spec$treat_map),
    n_studies = length(unique(fit$evidenceos_meta$model_spec$data$study)),
    elapsed_time_mins = fit$evidenceos_meta$elapsed_time_mins
  )

  list(
    treatment_effects = effects,
    sucra_scores = sucra,
    rankogram_data = rankogram,
    league_table = league,
    heterogeneity = heterogeneity,
    model_info = model_info,
    rankings_matrix = rankings
  )
}
