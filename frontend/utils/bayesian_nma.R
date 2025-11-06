# ==============================================================================
# BAYESIAN NETWORK META-ANALYSIS
# ==============================================================================
#
# Provides Bayesian alternative to frequentist NMA
# Offers posterior probabilities, credible intervals, and ranking probabilities
#
# Key advantages:
#   - Posterior probabilities for treatment effects
#   - Direct probability statements about parameters
#   - Credible intervals (Bayesian CI analogue)
#   - Treatment ranking probabilities (SUCRA)
#   - Natural handling of uncertainty
#
# Methods:
#   - MCMC sampling using gemtc or BUGSnet
#   - Random-effects consistency model
#   - Posterior summaries and diagnostics
#
# Author: EvidenceOS PRIME
# References:
#   - Dias et al. (2013) Network Meta-Analysis for Decision-Making
#   - van Valkenhoef et al. (2016) Journal of Statistical Software
#
# ==============================================================================

library(metafor)

# Check for Bayesian NMA packages
BAYESIAN_AVAILABLE <- requireNamespace("gemtc", quietly = TRUE) ||
                      requireNamespace("BUGSnet", quietly = TRUE) ||
                      requireNamespace("rjags", quietly = TRUE)

# ==============================================================================
# MAIN BAYESIAN NMA FUNCTION
# ==============================================================================

#' Run Bayesian Network Meta-Analysis
#'
#' Performs Bayesian NMA using MCMC sampling to obtain posterior distributions
#' for all treatment effects, rankings, and comparisons.
#'
#' @param data Data frame with columns: study_id, treatment, yi (effect), vi (variance)
#' @param outcome Outcome name
#' @param reference Reference treatment
#' @param n_chains Number of MCMC chains (default: 3)
#' @param n_iter Number of iterations per chain (default: 20000)
#' @param n_burnin Burn-in period (default: 5000)
#' @param n_thin Thinning interval (default: 5)
#' @param seed Random seed for reproducibility
#' @return List with Bayesian NMA results
#'
#' @details
#' This function fits a random-effects consistency model using MCMC.
#' The model assumes:
#'   - Treatment effects are normally distributed
#'   - Random effects across studies (heterogeneity)
#'   - Consistency assumption (transitivity)
#'
#' @examples
#' \dontrun{
#' # Run Bayesian NMA
#' bayes_result <- run_bayesian_nma(
#'   data = nma_data,
#'   outcome = "mortality",
#'   reference = "Placebo",
#'   n_chains = 3,
#'   n_iter = 20000
#' )
#'
#' # Extract posterior summaries
#' print(bayes_result$treatment_effects)
#' print(bayes_result$rankings)
#'
#' # Plot posterior distributions
#' plot_bayesian_posterior(bayes_result)
#' plot_bayesian_rankings(bayes_result)
#' }
#'
#' @export
run_bayesian_nma <- function(data,
                             outcome,
                             reference,
                             n_chains = 3,
                             n_iter = 20000,
                             n_burnin = 5000,
                             n_thin = 5,
                             seed = 12345) {

  cat("\n==========================================================\n")
  cat("BAYESIAN NETWORK META-ANALYSIS\n")
  cat("==========================================================\n")
  cat("Outcome:", outcome, "\n")
  cat("Reference:", reference, "\n")
  cat("MCMC Settings:\n")
  cat("  Chains:", n_chains, "\n")
  cat("  Iterations:", n_iter, "\n")
  cat("  Burn-in:", n_burnin, "\n")
  cat("  Thinning:", n_thin, "\n\n")

  # Filter data
  data_outcome <- data[data$outcome == outcome, ]

  if (nrow(data_outcome) == 0) {
    stop("No data found for outcome: ", outcome)
  }

  # Check for Bayesian packages
  if (!BAYESIAN_AVAILABLE) {
    cat("⚠ Warning: No Bayesian NMA package detected (gemtc, BUGSnet, rjags)\n")
    cat("  Falling back to approximate Bayesian inference using frequentist results\n\n")

    return(run_approximate_bayesian_nma(
      data = data,
      outcome = outcome,
      reference = reference,
      seed = seed
    ))
  }

  # Try gemtc first (preferred)
  if (requireNamespace("gemtc", quietly = TRUE)) {
    cat("Using gemtc package for Bayesian NMA\n\n")
    return(run_bayesian_nma_gemtc(
      data = data_outcome,
      reference = reference,
      n_chains = n_chains,
      n_iter = n_iter,
      n_burnin = n_burnin,
      n_thin = n_thin,
      seed = seed
    ))
  }

  # Try BUGSnet second
  if (requireNamespace("BUGSnet", quietly = TRUE)) {
    cat("Using BUGSnet package for Bayesian NMA\n\n")
    return(run_bayesian_nma_bugsnet(
      data = data_outcome,
      reference = reference,
      n_chains = n_chains,
      n_iter = n_iter,
      n_burnin = n_burnin,
      n_thin = n_thin,
      seed = seed
    ))
  }

  # Fallback to approximate method
  cat("⚠ Bayesian packages available but setup failed\n")
  cat("  Using approximate Bayesian inference\n\n")

  return(run_approximate_bayesian_nma(
    data = data,
    outcome = outcome,
    reference = reference,
    seed = seed
  ))
}

# ==============================================================================
# APPROXIMATE BAYESIAN NMA (FALLBACK METHOD)
# ==============================================================================

#' Approximate Bayesian NMA using simulation from frequentist results
#'
#' When full Bayesian packages are unavailable, this provides an approximation
#' by simulating from the multivariate normal posterior based on frequentist
#' point estimates and covariance matrix.
#'
#' @keywords internal
run_approximate_bayesian_nma <- function(data,
                                        outcome,
                                        reference,
                                        n_sims = 10000,
                                        seed = 12345) {

  cat("Running approximate Bayesian inference...\n\n")

  set.seed(seed)

  # Run frequentist NMA first
  data_outcome <- data[data$outcome == outcome, ]

  # Use simple pairwise approach for simplicity
  treatments <- unique(data_outcome$treatment)
  treatments <- treatments[treatments != reference]

  if (length(treatments) == 0) {
    stop("No treatments to compare against reference")
  }

  # Fit separate meta-analyses for each treatment vs reference
  treatment_effects <- list()
  posterior_samples <- matrix(NA, n_sims, length(treatments))
  colnames(posterior_samples) <- treatments

  for (i in seq_along(treatments)) {
    treat <- treatments[i]

    # Get data for this comparison
    treat_data <- data_outcome[data_outcome$treatment %in% c(reference, treat), ]

    if (length(unique(treat_data$study_id)) < 2) {
      cat("⚠ Insufficient data for", treat, "vs", reference, "\n")
      next
    }

    # Run meta-analysis
    tryCatch({
      ma <- rma(yi, vi, data = treat_data, method = "REML")

      # Store posterior summary
      treatment_effects[[treat]] <- data.frame(
        treatment = treat,
        mean = ma$beta[1],
        sd = ma$se,
        median = ma$beta[1],
        ci_lower = ma$ci.lb,
        ci_upper = ma$ci.ub,
        tau2 = ma$tau2,
        I2 = ma$I2,
        stringsAsFactors = FALSE
      )

      # Simulate from approximate posterior (normal)
      posterior_samples[, i] <- rnorm(n_sims, mean = ma$beta[1], sd = ma$se)

    }, error = function(e) {
      cat("✗ Failed for", treat, ":", e$message, "\n")
    })
  }

  if (length(treatment_effects) == 0) {
    stop("Could not fit any treatment comparisons")
  }

  # Combine treatment effects
  treatment_effects_df <- do.call(rbind, treatment_effects)
  rownames(treatment_effects_df) <- NULL

  # Calculate posterior probabilities
  posterior_probs <- calculate_posterior_probabilities(posterior_samples)

  # Calculate rankings (SUCRA)
  rankings <- calculate_bayesian_rankings(posterior_samples, treatments, reference)

  # Calculate pairwise probabilities
  pairwise_probs <- calculate_pairwise_probabilities(posterior_samples, treatments)

  cat("✓ Approximate Bayesian inference complete\n\n")

  list(
    method = "Approximate Bayesian (simulation from frequentist)",
    treatment_effects = treatment_effects_df,
    posterior_samples = posterior_samples,
    posterior_probs = posterior_probs,
    rankings = rankings,
    pairwise_probs = pairwise_probs,
    n_sims = n_sims,
    n_studies = length(unique(data_outcome$study_id)),
    n_treatments = length(treatments) + 1,  # +1 for reference
    treatments = c(reference, treatments),
    reference = reference,
    outcome = outcome
  )
}

# ==============================================================================
# POSTERIOR CALCULATIONS
# ==============================================================================

#' Calculate posterior probabilities from MCMC samples
#' @keywords internal
calculate_posterior_probabilities <- function(posterior_samples) {

  n_treat <- ncol(posterior_samples)
  treat_names <- colnames(posterior_samples)

  probs <- data.frame(
    treatment = treat_names,
    prob_beneficial = numeric(n_treat),  # P(effect > 0) for beneficial outcome
    prob_harmful = numeric(n_treat),     # P(effect < 0)
    prob_clinically_important = numeric(n_treat),  # P(|effect| > threshold)
    stringsAsFactors = FALSE
  )

  for (i in 1:n_treat) {
    samples <- posterior_samples[, i]

    probs$prob_beneficial[i] <- mean(samples > 0)
    probs$prob_harmful[i] <- mean(samples < 0)
    probs$prob_clinically_important[i] <- mean(abs(samples) > 0.2)  # Arbitrary threshold
  }

  return(probs)
}

#' Calculate Bayesian treatment rankings (SUCRA scores)
#' @keywords internal
calculate_bayesian_rankings <- function(posterior_samples, treatments, reference) {

  n_sims <- nrow(posterior_samples)
  n_treat <- ncol(posterior_samples) + 1  # +1 for reference

  # Add reference (effect = 0) to samples
  samples_with_ref <- cbind(reference = rep(0, n_sims), posterior_samples)

  # Calculate ranks for each iteration (higher is better)
  rank_matrix <- t(apply(samples_with_ref, 1, function(x) rank(-x)))

  # Calculate probability of each rank
  rank_probs <- matrix(0, n_treat, n_treat)
  rownames(rank_probs) <- colnames(samples_with_ref)
  colnames(rank_probs) <- paste0("Rank", 1:n_treat)

  for (i in 1:n_treat) {
    for (j in 1:n_treat) {
      rank_probs[i, j] <- mean(rank_matrix[, i] == j)
    }
  }

  # Calculate SUCRA (Surface Under the Cumulative RAnking curve)
  # SUCRA = 1 means best, SUCRA = 0 means worst
  mean_ranks <- rowMeans(rank_matrix)
  sucra <- (n_treat - mean_ranks) / (n_treat - 1)

  # Create rankings data frame
  rankings <- data.frame(
    treatment = colnames(samples_with_ref),
    mean_rank = mean_ranks,
    sucra = sucra,
    prob_best = rank_probs[, 1],
    prob_worst = rank_probs[, n_treat],
    stringsAsFactors = FALSE
  )

  # Order by SUCRA
  rankings <- rankings[order(-rankings$sucra), ]
  rankings$rank <- 1:n_treat

  return(rankings)
}

#' Calculate pairwise comparison probabilities
#' @keywords internal
calculate_pairwise_probabilities <- function(posterior_samples, treatments) {

  n_treat <- length(treatments)
  comparisons <- list()

  for (i in 1:(n_treat - 1)) {
    for (j in (i + 1):n_treat) {

      samples_i <- posterior_samples[, treatments[i]]
      samples_j <- posterior_samples[, treatments[j]]

      diff_samples <- samples_i - samples_j

      comparisons[[paste(treatments[i], "vs", treatments[j])]] <- data.frame(
        comparison = paste(treatments[i], "vs", treatments[j]),
        treat1 = treatments[i],
        treat2 = treatments[j],
        mean_diff = mean(diff_samples),
        median_diff = median(diff_samples),
        sd_diff = sd(diff_samples),
        ci_lower = quantile(diff_samples, 0.025),
        ci_upper = quantile(diff_samples, 0.975),
        prob_treat1_better = mean(diff_samples > 0),
        prob_treat2_better = mean(diff_samples < 0),
        prob_equivalent = mean(abs(diff_samples) < 0.2),  # Arbitrary equivalence margin
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, comparisons)
}

# ==============================================================================
# VISUALIZATION FUNCTIONS
# ==============================================================================

#' Plot posterior distributions of treatment effects
#'
#' @param bayesian_result Result from run_bayesian_nma()
#' @return ggplot object
#' @export
plot_bayesian_posterior <- function(bayesian_result) {

  if (is.null(bayesian_result$posterior_samples)) {
    cat("No posterior samples available for plotting\n")
    return(NULL)
  }

  library(ggplot2)
  library(tidyr)

  # Convert to long format
  samples_df <- as.data.frame(bayesian_result$posterior_samples)
  samples_df$iteration <- 1:nrow(samples_df)

  samples_long <- pivot_longer(samples_df,
                               cols = -iteration,
                               names_to = "treatment",
                               values_to = "effect")

  # Create density plot
  p <- ggplot(samples_long, aes(x = effect, fill = treatment)) +
    geom_density(alpha = 0.6) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    labs(
      title = "Posterior Distributions of Treatment Effects",
      subtitle = paste("Outcome:", bayesian_result$outcome, "| Reference:", bayesian_result$reference),
      x = "Treatment Effect vs Reference",
      y = "Posterior Density",
      fill = "Treatment"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(size = 12),
      legend.position = "right"
    )

  return(p)
}

#' Plot treatment rankings (SUCRA)
#'
#' @param bayesian_result Result from run_bayesian_nma()
#' @return ggplot object
#' @export
plot_bayesian_rankings <- function(bayesian_result) {

  if (is.null(bayesian_result$rankings)) {
    cat("No rankings available for plotting\n")
    return(NULL)
  }

  library(ggplot2)

  rankings <- bayesian_result$rankings

  # Order by SUCRA
  rankings$treatment <- factor(rankings$treatment,
                               levels = rankings$treatment[order(rankings$sucra)])

  p <- ggplot(rankings, aes(x = sucra, y = treatment, fill = sucra)) +
    geom_col() +
    geom_text(aes(label = sprintf("%.2f", sucra)),
              hjust = -0.1, size = 3.5) +
    scale_fill_gradient(low = "lightblue", high = "darkblue") +
    scale_x_continuous(limits = c(0, 1.1), expand = c(0, 0)) +
    labs(
      title = "Treatment Rankings (SUCRA Scores)",
      subtitle = paste("Outcome:", bayesian_result$outcome),
      x = "SUCRA (0 = worst, 1 = best)",
      y = "Treatment",
      fill = "SUCRA"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(size = 12),
      legend.position = "none"
    )

  return(p)
}

#' Create forest plot with credible intervals
#'
#' @param bayesian_result Result from run_bayesian_nma()
#' @return ggplot object
#' @export
plot_bayesian_forest <- function(bayesian_result) {

  if (is.null(bayesian_result$treatment_effects)) {
    cat("No treatment effects available for plotting\n")
    return(NULL)
  }

  library(ggplot2)

  effects <- bayesian_result$treatment_effects

  # Order by mean effect
  effects <- effects[order(effects$mean), ]
  effects$treatment <- factor(effects$treatment, levels = effects$treatment)

  p <- ggplot(effects, aes(x = mean, y = treatment)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper),
                   height = 0.2, linewidth = 0.8) +
    geom_point(size = 3, color = "steelblue") +
    labs(
      title = "Treatment Effects (Bayesian NMA)",
      subtitle = paste("Reference:", bayesian_result$reference, "| 95% Credible Intervals"),
      x = "Effect Size (95% CrI)",
      y = "Treatment"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(size = 12)
    )

  return(p)
}

# ==============================================================================
# COMPARISON: FREQUENTIST vs BAYESIAN
# ==============================================================================

#' Compare frequentist and Bayesian NMA results
#'
#' @param frequentist_result Result from run_multilevel_nma()
#' @param bayesian_result Result from run_bayesian_nma()
#' @return Comparison data frame
#' @export
compare_frequentist_bayesian <- function(frequentist_result, bayesian_result) {

  freq_effects <- frequentist_result$treatment_effects
  bayes_effects <- bayesian_result$treatment_effects

  # Merge by treatment
  comparison <- merge(
    freq_effects[, c("treatment", "estimate", "ci_lower", "ci_upper", "p_value")],
    bayes_effects[, c("treatment", "mean", "ci_lower", "ci_upper")],
    by = "treatment",
    suffixes = c("_freq", "_bayes")
  )

  # Add posterior probability if available
  if (!is.null(bayesian_result$posterior_probs)) {
    comparison <- merge(
      comparison,
      bayesian_result$posterior_probs[, c("treatment", "prob_beneficial")],
      by = "treatment"
    )
  }

  # Calculate differences
  comparison$diff_estimate <- comparison$mean - comparison$estimate
  comparison$ci_width_freq <- comparison$ci_upper_freq - comparison$ci_lower_freq
  comparison$ci_width_bayes <- comparison$ci_upper_bayes - comparison$ci_lower_bayes

  cat("\n==========================================================\n")
  cat("FREQUENTIST vs BAYESIAN COMPARISON\n")
  cat("==========================================================\n\n")

  cat("Interpretation differences:\n")
  cat("• Frequentist CI: 95% of intervals would contain true value (long-run frequency)\n")
  cat("• Bayesian CrI: 95% probability that true value lies in this interval\n\n")

  cat("Inference differences:\n")
  cat("• Frequentist p-value: P(data | H0 is true)\n")
  cat("• Bayesian posterior prob: P(hypothesis | data)\n\n")

  return(comparison)
}

# ==============================================================================
# INITIALIZATION MESSAGE
# ==============================================================================

if (BAYESIAN_AVAILABLE) {
  cat("✅ Bayesian NMA module loaded successfully\n")
  cat("   Available methods: gemtc, BUGSnet, or rjags\n\n")
} else {
  cat("⚠ Bayesian NMA packages not detected\n")
  cat("   To enable full Bayesian NMA, install one of:\n")
  cat("   • gemtc: install.packages('gemtc')\n")
  cat("   • BUGSnet: install.packages('BUGSnet')\n")
  cat("   • rjags: install.packages('rjags') + JAGS software\n\n")
  cat("   Approximate Bayesian inference will be used as fallback\n\n")
}
