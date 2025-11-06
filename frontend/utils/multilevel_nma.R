# Multi-Level Network Meta-Analysis
# Handles multi-arm trials, correlated effects, and hierarchical structures
# Uses metafor::rma.mv() for proper modeling of dependencies
#
# Author: EvidenceOS PRIME
# Key advantages over standard NMA:
#   - Handles multi-arm trials without splitting into pairwise comparisons
#   - Models within-study correlations properly
#   - Allows for nested random effects
#   - More flexible variance-covariance structures

library(metafor)
library(Matrix)

# ============================================================================
# MULTI-LEVEL NMA CORE FUNCTIONS
# ============================================================================

#' Run multi-level network meta-analysis
#' @param data Data frame with study-level data
#' @param outcome Outcome variable name
#' @param reference Reference treatment
#' @param correlation Assumed within-study correlation (default 0.5)
#' @param struct Variance structure: "UN" (unstructured), "CS" (compound symmetry), "AR" (autoregressive)
#' @param method Estimation method: "REML" or "ML"
#' @return Multi-level NMA results
run_multilevel_nma <- function(data,
                                outcome,
                                reference,
                                correlation = 0.5,
                                struct = "UN",
                                method = "REML") {

  # Filter by outcome
  data_outcome <- data[data$outcome == outcome, ]

  if (nrow(data_outcome) == 0) {
    stop("No data found for outcome: ", outcome)
  }

  # Prepare contrast-based data structure
  contrast_data <- prepare_contrast_data(data_outcome, reference)

  if (nrow(contrast_data) == 0) {
    stop("Could not create contrast data. Check data structure.")
  }

  # Construct variance-covariance matrix
  V <- construct_vcov_matrix(contrast_data, correlation)

  # Create design matrix for treatment effects
  X <- model.matrix(~ treatment - 1, data = contrast_data)

  # Fit multi-level model
  # Level 1: Within-study sampling error (V matrix)
  # Level 2: Between-study heterogeneity (random effects)
  model <- tryCatch({
    rma.mv(
      yi = yi,
      V = V,
      mods = ~ treatment - 1,
      random = ~ treatment | study_id,
      struct = struct,
      data = contrast_data,
      method = method,
      sparse = TRUE
    )
  }, error = function(e) {
    # If complex structure fails, try simpler model
    warning("Complex model failed, trying simpler structure")
    rma.mv(
      yi = yi,
      V = V,
      mods = ~ treatment - 1,
      random = ~ 1 | study_id,
      data = contrast_data,
      method = method
    )
  })

  # Extract treatment effects (relative to reference)
  treatments <- unique(contrast_data$treatment)
  treatment_effects <- extract_treatment_effects(model, treatments, reference)

  # Calculate all pairwise comparisons
  pairwise_comparisons <- calculate_pairwise_comparisons(treatment_effects)

  # Calculate rankings (P-scores)
  rankings <- calculate_rankings_multilevel(treatment_effects)

  # Model diagnostics
  diagnostics <- extract_diagnostics(model, contrast_data)

  # Check for inconsistency (if applicable)
  inconsistency <- check_inconsistency_multilevel(model, contrast_data)

  list(
    model = model,
    treatment_effects = treatment_effects,
    pairwise_comparisons = pairwise_comparisons,
    rankings = rankings,
    diagnostics = diagnostics,
    inconsistency = inconsistency,
    n_studies = length(unique(contrast_data$study_id)),
    n_treatments = length(treatments),
    treatments = c(reference, treatments),
    reference = reference,
    method = "Multi-level (rma.mv)",
    correlation_assumed = correlation,
    structure = struct
  )
}

# ============================================================================
# DATA PREPARATION
# ============================================================================

#' Prepare contrast-based data structure for multi-level NMA
#' @param data Study-level data
#' @param reference Reference treatment
#' @return Contrast data frame
prepare_contrast_data <- function(data, reference) {

  contrast_list <- list()

  studies <- unique(data$study_id)

  for (study in studies) {
    study_data <- data[data$study_id == study, ]

    treatments <- study_data$treatment
    n_arms <- length(treatments)

    if (n_arms < 2) {
      # Skip single-arm studies
      next
    }

    # Check if reference is in this study
    has_reference <- reference %in% treatments

    if (has_reference) {
      # Reference-based contrasts
      ref_data <- study_data[study_data$treatment == reference, ]

      for (i in 1:nrow(study_data)) {
        if (study_data$treatment[i] != reference) {
          contrast_list[[length(contrast_list) + 1]] <- data.frame(
            study_id = study,
            contrast_id = paste0(study, "_", study_data$treatment[i], "_vs_", reference),
            treatment = study_data$treatment[i],
            yi = study_data$yi[i] - ref_data$yi[1],
            vi = study_data$vi[i] + ref_data$vi[1],
            n_arms = n_arms,
            stringsAsFactors = FALSE
          )
        }
      }
    } else {
      # Multi-arm study without reference: use first arm as within-study reference
      ref_arm <- study_data[1, ]

      for (i in 2:nrow(study_data)) {
        contrast_list[[length(contrast_list) + 1]] <- data.frame(
          study_id = study,
          contrast_id = paste0(study, "_", study_data$treatment[i], "_vs_", ref_arm$treatment),
          treatment = study_data$treatment[i],
          yi = study_data$yi[i] - ref_arm$yi,
          vi = study_data$vi[i] + ref_arm$vi,
          n_arms = n_arms,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(contrast_list) == 0) {
    return(data.frame())
  }

  do.call(rbind, contrast_list)
}

# ============================================================================
# VARIANCE-COVARIANCE MATRIX CONSTRUCTION
# ============================================================================

#' Construct variance-covariance matrix accounting for within-study correlations
#' @param contrast_data Contrast-based data
#' @param rho Within-study correlation
#' @return Variance-covariance matrix
construct_vcov_matrix <- function(contrast_data, rho = 0.5) {

  n <- nrow(contrast_data)
  V <- matrix(0, n, n)

  # Diagonal elements: sampling variances
  diag(V) <- contrast_data$vi

  # Off-diagonal elements: covariances for contrasts within same study
  studies <- unique(contrast_data$study_id)

  for (study in studies) {
    study_idx <- which(contrast_data$study_id == study)

    if (length(study_idx) > 1) {
      # Contrasts from same study share a common reference arm
      # This induces correlation of approximately 0.5
      for (i in study_idx) {
        for (j in study_idx) {
          if (i != j) {
            # Covariance = rho * sqrt(var_i * var_j)
            V[i, j] <- rho * sqrt(contrast_data$vi[i] * contrast_data$vi[j])
          }
        }
      }
    }
  }

  # Ensure positive definiteness
  V <- as.matrix(nearPD(V, corr = FALSE)$mat)

  return(V)
}

# ============================================================================
# RESULTS EXTRACTION
# ============================================================================

#' Extract treatment effects from multi-level model
#' @param model Fitted rma.mv model
#' @param treatments Treatment names (excluding reference)
#' @param reference Reference treatment name
#' @return Data frame with treatment effects
extract_treatment_effects <- function(model, treatments, reference) {

  coefs <- coef(model)
  vcov_mat <- vcov(model)
  se <- sqrt(diag(vcov_mat))

  # Extract treatment coefficients
  treatment_idx <- grep("treatment", names(coefs))

  if (length(treatment_idx) == 0) {
    stop("Could not extract treatment effects from model")
  }

  effects <- data.frame(
    treatment = gsub("treatment", "", names(coefs[treatment_idx])),
    estimate = coefs[treatment_idx],
    se = se[treatment_idx],
    stringsAsFactors = FALSE
  )

  # Calculate CI and p-value
  effects$ci_lower <- effects$estimate - 1.96 * effects$se
  effects$ci_upper <- effects$estimate + 1.96 * effects$se
  effects$z <- effects$estimate / effects$se
  effects$p_value <- 2 * pnorm(-abs(effects$z))

  # Add reference treatment (estimate = 0)
  ref_row <- data.frame(
    treatment = reference,
    estimate = 0,
    se = 0,
    ci_lower = 0,
    ci_upper = 0,
    z = 0,
    p_value = 1,
    stringsAsFactors = FALSE
  )

  effects <- rbind(ref_row, effects)
  rownames(effects) <- NULL

  return(effects)
}

#' Calculate all pairwise treatment comparisons
#' @param treatment_effects Treatment effects data frame
#' @return Data frame with all pairwise comparisons
calculate_pairwise_comparisons <- function(treatment_effects) {

  treatments <- treatment_effects$treatment
  n_treat <- length(treatments)

  comparisons <- list()

  for (i in 1:(n_treat - 1)) {
    for (j in (i + 1):n_treat) {
      # Difference in effects
      diff <- treatment_effects$estimate[i] - treatment_effects$estimate[j]

      # Standard error of difference (approximate)
      se_diff <- sqrt(treatment_effects$se[i]^2 + treatment_effects$se[j]^2)

      comparisons[[length(comparisons) + 1]] <- data.frame(
        comparison = paste(treatments[i], "vs", treatments[j]),
        treat1 = treatments[i],
        treat2 = treatments[j],
        estimate = diff,
        se = se_diff,
        ci_lower = diff - 1.96 * se_diff,
        ci_upper = diff + 1.96 * se_diff,
        p_value = 2 * pnorm(-abs(diff / se_diff)),
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, comparisons)
}

#' Calculate treatment rankings (P-scores)
#' @param treatment_effects Treatment effects data frame
#' @return Rankings data frame
calculate_rankings_multilevel <- function(treatment_effects) {

  # Order by estimate (higher is better, assuming positive = beneficial)
  treatment_effects <- treatment_effects[order(-treatment_effects$estimate), ]

  # Calculate P-scores using simulation
  n_sims <- 10000
  n_treat <- nrow(treatment_effects)

  # Simulate from posterior (approximate normal)
  sims <- matrix(NA, n_sims, n_treat)
  for (i in 1:n_treat) {
    sims[, i] <- rnorm(n_sims,
                       mean = treatment_effects$estimate[i],
                       sd = treatment_effects$se[i])
  }

  # Calculate ranks for each simulation
  rank_matrix <- t(apply(sims, 1, function(x) rank(-x)))

  # P-score: mean rank scaled to 0-1
  mean_ranks <- colMeans(rank_matrix)
  p_scores <- (n_treat - mean_ranks) / (n_treat - 1)

  rankings <- data.frame(
    treatment = treatment_effects$treatment,
    estimate = treatment_effects$estimate,
    se = treatment_effects$se,
    mean_rank = mean_ranks,
    p_score = p_scores,
    stringsAsFactors = FALSE
  )

  # Order by P-score
  rankings <- rankings[order(-rankings$p_score), ]
  rankings$rank <- 1:n_treat

  return(rankings)
}

# ============================================================================
# DIAGNOSTICS & INCONSISTENCY
# ============================================================================

#' Extract model diagnostics
#' @param model Fitted rma.mv model
#' @param contrast_data Contrast data
#' @return List of diagnostic metrics
extract_diagnostics <- function(model, contrast_data) {

  list(
    tau2 = model$sigma2,  # Between-study variance
    I2 = (model$sigma2[1] / (model$sigma2[1] + mean(contrast_data$vi))) * 100,
    QE = model$QE,  # Test for residual heterogeneity
    QEp = model$QEp,
    AIC = AIC(model),
    BIC = BIC(model),
    logLik = logLik(model),
    n_parameters = model$p
  )
}

#' Check for inconsistency in multi-level NMA
#' @param model Fitted model
#' @param contrast_data Contrast data
#' @return Inconsistency assessment
check_inconsistency_multilevel <- function(model, contrast_data) {

  # For multi-level models, inconsistency can be assessed by:
  # 1. Comparing direct vs indirect evidence (node-splitting)
  # 2. Checking residual heterogeneity
  # 3. Using design-by-treatment interaction

  # Simplified approach: Check if residual heterogeneity is significant
  inconsistency_detected <- model$QEp < 0.05

  list(
    method = "Residual heterogeneity test",
    Q = model$QE,
    df = model$k - model$p,
    p_value = model$QEp,
    inconsistency_detected = inconsistency_detected,
    interpretation = if (inconsistency_detected) {
      "Significant residual heterogeneity detected. This may indicate inconsistency between direct and indirect evidence."
    } else {
      "No significant residual heterogeneity. Network assumptions appear reasonable."
    }
  )
}

# ============================================================================
# LEAGUE TABLE GENERATION
# ============================================================================

#' Generate league table for multi-level NMA
#' @param pairwise_comparisons Data frame of pairwise comparisons
#' @param treatments Vector of treatment names
#' @return League table matrix
generate_league_table_multilevel <- function(pairwise_comparisons, treatments) {

  n_treat <- length(treatments)
  league <- matrix("", n_treat, n_treat)
  rownames(league) <- treatments
  colnames(league) <- treatments

  # Upper triangle: effect estimates with CI
  for (i in 1:(n_treat - 1)) {
    for (j in (i + 1):n_treat) {
      comp <- pairwise_comparisons[
        pairwise_comparisons$treat1 == treatments[i] &
        pairwise_comparisons$treat2 == treatments[j],
      ]

      if (nrow(comp) > 0) {
        league[i, j] <- sprintf("%.2f (%.2f, %.2f)",
                               comp$estimate[1],
                               comp$ci_lower[1],
                               comp$ci_upper[1])
      }
    }
  }

  # Lower triangle: reverse comparisons
  for (i in 2:n_treat) {
    for (j in 1:(i - 1)) {
      comp <- pairwise_comparisons[
        pairwise_comparisons$treat1 == treatments[j] &
        pairwise_comparisons$treat2 == treatments[i],
      ]

      if (nrow(comp) > 0) {
        league[i, j] <- sprintf("%.2f (%.2f, %.2f)",
                               -comp$estimate[1],
                               -comp$ci_upper[1],
                               -comp$ci_lower[1])
      }
    }
  }

  # Diagonal: treatment names
  diag(league) <- treatments

  return(league)
}

# ============================================================================
# FOREST PLOT FOR MULTI-LEVEL NMA
# ============================================================================

#' Generate forest plot for multi-level NMA results
#' @param treatment_effects Treatment effects data frame
#' @param reference Reference treatment
#' @return ggplot object
plot_multilevel_nma_forest <- function(treatment_effects, reference) {

  library(ggplot2)

  # Remove reference (effect = 0)
  plot_data <- treatment_effects[treatment_effects$treatment != reference, ]

  # Order by estimate
  plot_data <- plot_data[order(plot_data$estimate), ]
  plot_data$treatment <- factor(plot_data$treatment, levels = plot_data$treatment)

  ggplot(plot_data, aes(x = estimate, y = treatment)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper),
                   height = 0.2, linewidth = 0.8) +
    geom_point(size = 3, color = "steelblue") +
    labs(
      title = "Treatment Effects (Multi-Level NMA)",
      subtitle = paste("Reference:", reference),
      x = "Effect Size (95% CI)",
      y = "Treatment"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(size = 12),
      axis.text = element_text(size = 10)
    )
}

# ============================================================================
# COMPARISON: STANDARD vs MULTI-LEVEL NMA
# ============================================================================

#' Compare standard NMA vs multi-level NMA results
#' @param standard_result Results from netmeta
#' @param multilevel_result Results from rma.mv
#' @return Comparison table
compare_nma_methods <- function(standard_result, multilevel_result) {

  comparison <- data.frame(
    Metric = c(
      "Method",
      "Number of Studies",
      "Number of Treatments",
      "Between-study heterogeneity (τ²)",
      "I² statistic",
      "Handles multi-arm properly",
      "Models within-study correlation",
      "Inconsistency check"
    ),
    Standard_NMA = c(
      "netmeta (contrast-based)",
      standard_result$n_studies,
      standard_result$n_treatments,
      sprintf("%.3f", standard_result$heterogeneity$tau2),
      sprintf("%.1f%%", standard_result$heterogeneity$I2),
      "Splits into pairwise",
      "Approximate",
      ifelse(!is.null(standard_result$inconsistency), "Available", "N/A")
    ),
    Multilevel_NMA = c(
      "rma.mv (multi-level)",
      multilevel_result$n_studies,
      multilevel_result$n_treatments,
      sprintf("%.3f", multilevel_result$diagnostics$tau2[1]),
      sprintf("%.1f%%", multilevel_result$diagnostics$I2),
      "Proper modeling",
      sprintf("ρ = %.2f", multilevel_result$correlation_assumed),
      "Residual heterogeneity"
    ),
    stringsAsFactors = FALSE
  )

  return(comparison)
}

# ============================================================================
# CORRELATION SENSITIVITY ANALYSIS
# ============================================================================

#' Perform sensitivity analysis for within-study correlation assumption
#'
#' Multi-level NMA assumes a correlation between treatment effects within
#' multi-arm trials (default ρ = 0.5). This function tests robustness of
#' results to this assumption by re-running analyses with different values.
#'
#' @param data Study-level data
#' @param outcome Outcome variable name
#' @param reference Reference treatment
#' @param correlations Vector of correlation values to test (default: c(0.3, 0.5, 0.7))
#' @param struct Variance structure
#' @param method Estimation method
#' @return List with sensitivity analysis results
#' @references
#'   Higgins JPT, Jackson D, Barrett JK, Lu G, Ades AE, White IR. (2012)
#'   Consistency and inconsistency in network meta-analysis. Stat Med 31(27):3893-3904.
#'
#' @examples
#' \dontrun{
#' # Test sensitivity to correlation assumption
#' sensitivity <- correlation_sensitivity_analysis(
#'   data = nma_data,
#'   outcome = "mortality",
#'   reference = "Placebo",
#'   correlations = c(0.3, 0.5, 0.7)
#' )
#'
#' # Check if results are stable
#' print(sensitivity$summary)
#' print(sensitivity$recommendation)
#'
#' # Visualize sensitivity
#' plot_correlation_sensitivity(sensitivity)
#' }
correlation_sensitivity_analysis <- function(data,
                                            outcome,
                                            reference,
                                            correlations = c(0.3, 0.5, 0.7),
                                            struct = "UN",
                                            method = "REML") {

  cat("\n==========================================================\n")
  cat("CORRELATION SENSITIVITY ANALYSIS\n")
  cat("==========================================================\n")
  cat("Outcome:", outcome, "\n")
  cat("Reference:", reference, "\n")
  cat("Testing correlations:", paste(correlations, collapse = ", "), "\n\n")

  # Check that we have multi-arm trials
  data_outcome <- data[data$outcome == outcome, ]
  arms_per_study <- table(data_outcome$study_id)
  multi_arm_studies <- sum(arms_per_study > 2)

  if (multi_arm_studies == 0) {
    cat("⚠ No multi-arm trials detected (all studies have ≤2 arms).\n")
    cat("  Correlation assumption does not affect results.\n")
    cat("  Sensitivity analysis not needed.\n\n")

    return(list(
      sensitivity_needed = FALSE,
      reason = "No multi-arm trials in network",
      n_studies = length(unique(data_outcome$study_id)),
      n_multi_arm = 0
    ))
  }

  cat("✓ Multi-arm trials detected:", multi_arm_studies, "out of",
      length(unique(data_outcome$study_id)), "studies\n")
  cat("  Correlation assumption matters - proceeding with sensitivity analysis\n\n")

  # Run analysis for each correlation value
  results_list <- list()
  treatment_effects_list <- list()

  for (rho in correlations) {
    cat("Running analysis with ρ =", rho, "... ")

    tryCatch({
      result <- run_multilevel_nma(
        data = data,
        outcome = outcome,
        reference = reference,
        correlation = rho,
        struct = struct,
        method = method
      )

      results_list[[as.character(rho)]] <- result
      treatment_effects_list[[as.character(rho)]] <- result$treatment_effects

      cat("✓ Complete\n")

    }, error = function(e) {
      cat("✗ Failed:", e$message, "\n")
      results_list[[as.character(rho)]] <- NULL
      treatment_effects_list[[as.character(rho)]] <- NULL
    })
  }

  if (length(results_list) == 0) {
    stop("All analyses failed. Check data structure and model specification.")
  }

  cat("\n")

  # Create summary comparing results across correlations
  summary_table <- create_correlation_sensitivity_summary(
    treatment_effects_list,
    correlations,
    reference
  )

  # Check ranking stability
  ranking_stability <- check_ranking_stability(results_list, correlations)

  # Create recommendation
  recommendation <- create_correlation_recommendation(
    summary_table,
    ranking_stability,
    multi_arm_studies
  )

  # Return comprehensive results
  list(
    sensitivity_needed = TRUE,
    n_studies = length(unique(data_outcome$study_id)),
    n_multi_arm = multi_arm_studies,
    correlations_tested = correlations,
    results = results_list,
    treatment_effects = treatment_effects_list,
    summary = summary_table,
    ranking_stability = ranking_stability,
    recommendation = recommendation,
    outcome = outcome,
    reference = reference
  )
}

#' Create summary table comparing treatment effects across correlations
#' @keywords internal
create_correlation_sensitivity_summary <- function(treatment_effects_list,
                                                   correlations,
                                                   reference) {

  if (length(treatment_effects_list) == 0) {
    return(data.frame())
  }

  # Get all treatments
  treatments <- treatment_effects_list[[1]]$treatment

  # Initialize summary data frame
  summary_list <- list()

  for (treat in treatments) {
    if (treat == reference) next  # Skip reference (always 0)

    estimates <- numeric(length(correlations))
    ci_lowers <- numeric(length(correlations))
    ci_uppers <- numeric(length(correlations))

    for (i in seq_along(correlations)) {
      rho <- as.character(correlations[i])
      effects <- treatment_effects_list[[rho]]

      treat_row <- effects[effects$treatment == treat, ]

      if (nrow(treat_row) > 0) {
        estimates[i] <- treat_row$estimate
        ci_lowers[i] <- treat_row$ci_lower
        ci_uppers[i] <- treat_row$ci_upper
      } else {
        estimates[i] <- NA
        ci_lowers[i] <- NA
        ci_uppers[i] <- NA
      }
    }

    # Calculate variability metrics
    estimate_range <- max(estimates, na.rm = TRUE) - min(estimates, na.rm = TRUE)
    estimate_sd <- sd(estimates, na.rm = TRUE)
    relative_variability <- estimate_sd / abs(mean(estimates, na.rm = TRUE)) * 100

    # Check if significance changes
    sig_at_05 <- (ci_lowers > 0 | ci_uppers < 0)
    significance_changes <- length(unique(sig_at_05)) > 1

    summary_list[[treat]] <- data.frame(
      treatment = treat,
      estimate_min = min(estimates, na.rm = TRUE),
      estimate_max = max(estimates, na.rm = TRUE),
      estimate_mean = mean(estimates, na.rm = TRUE),
      estimate_sd = estimate_sd,
      estimate_range = estimate_range,
      relative_variability_pct = relative_variability,
      significance_changes = significance_changes,
      stringsAsFactors = FALSE
    )
  }

  summary_df <- do.call(rbind, summary_list)
  rownames(summary_df) <- NULL

  # Order by relative variability
  summary_df <- summary_df[order(-summary_df$relative_variability_pct), ]

  return(summary_df)
}

#' Check stability of treatment rankings across correlations
#' @keywords internal
check_ranking_stability <- function(results_list, correlations) {

  if (length(results_list) == 0) {
    return(list(stable = NA, kendall_tau = NA))
  }

  # Extract rankings for each correlation
  ranking_matrices <- list()

  for (i in seq_along(correlations)) {
    rho <- as.character(correlations[i])
    if (!is.null(results_list[[rho]])) {
      rankings <- results_list[[rho]]$rankings
      ranking_matrices[[rho]] <- rankings[order(rankings$treatment), ]
    }
  }

  if (length(ranking_matrices) < 2) {
    return(list(stable = NA, kendall_tau = NA, reason = "Insufficient results"))
  }

  # Compare rankings using Kendall's tau
  correlations_vec <- numeric()
  comparisons <- list()

  rho_names <- names(ranking_matrices)

  for (i in 1:(length(rho_names) - 1)) {
    for (j in (i + 1):length(rho_names)) {
      rank1 <- ranking_matrices[[i]]$rank
      rank2 <- ranking_matrices[[j]]$rank

      # Ensure same treatments in same order
      treat1 <- ranking_matrices[[i]]$treatment
      treat2 <- ranking_matrices[[j]]$treatment

      if (identical(treat1, treat2)) {
        tau <- cor(rank1, rank2, method = "kendall")
        correlations_vec <- c(correlations_vec, tau)

        comparisons[[paste(rho_names[i], "vs", rho_names[j])]] <- data.frame(
          rho1 = rho_names[i],
          rho2 = rho_names[j],
          kendall_tau = tau,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  mean_tau <- mean(correlations_vec, na.rm = TRUE)

  # Interpretation
  # τ > 0.9: Very stable
  # τ > 0.7: Moderately stable
  # τ < 0.7: Unstable

  stable <- if (is.na(mean_tau)) {
    NA
  } else if (mean_tau > 0.9) {
    "Very stable"
  } else if (mean_tau > 0.7) {
    "Moderately stable"
  } else {
    "Unstable"
  }

  list(
    stable = stable,
    mean_kendall_tau = mean_tau,
    comparisons = do.call(rbind, comparisons),
    interpretation = if (is.na(mean_tau)) {
      "Could not assess stability"
    } else if (mean_tau > 0.9) {
      "Rankings are very stable across correlation assumptions (τ > 0.9)"
    } else if (mean_tau > 0.7) {
      "Rankings are moderately stable (τ > 0.7)"
    } else {
      "Rankings change substantially with correlation assumption (τ < 0.7)"
    }
  )
}

#' Create recommendation based on sensitivity analysis
#' @keywords internal
create_correlation_recommendation <- function(summary_table,
                                             ranking_stability,
                                             n_multi_arm) {

  if (nrow(summary_table) == 0) {
    return("Could not create recommendation - insufficient data")
  }

  # Assess overall sensitivity
  max_rel_var <- max(summary_table$relative_variability_pct, na.rm = TRUE)
  mean_rel_var <- mean(summary_table$relative_variability_pct, na.rm = TRUE)

  # Check if any treatment has high sensitivity
  high_sensitivity_treatments <- summary_table[
    summary_table$relative_variability_pct > 20,
  ]

  # Check if significance changes
  significance_changes <- any(summary_table$significance_changes)

  # Build recommendation
  recommendation <- list()

  recommendation$overall_sensitivity <- if (max_rel_var < 10) {
    "LOW"
  } else if (max_rel_var < 20) {
    "MODERATE"
  } else {
    "HIGH"
  }

  recommendation$ranking_stability <- ranking_stability$stable

  recommendation$interpretation <- if (max_rel_var < 10 && !significance_changes) {
    paste0(
      "✓ RESULTS ARE ROBUST\n\n",
      "Results show low sensitivity to correlation assumption (max relative variability: ",
      sprintf("%.1f%%", max_rel_var), ").\n",
      "Treatment effect estimates are stable across tested correlations.\n",
      "Statistical significance does not change.\n",
      if (!is.na(ranking_stability$stable) && ranking_stability$stable %in% c("Very stable", "Moderately stable")) {
        paste0("Treatment rankings are ", tolower(ranking_stability$stable), ".\n")
      } else "",
      "\n",
      "RECOMMENDATION: Standard reporting with ρ = 0.5 is appropriate.\n",
      "Briefly mention sensitivity analysis confirmed robustness."
    )
  } else if (max_rel_var < 20 && !significance_changes) {
    paste0(
      "⚠ MODERATE SENSITIVITY DETECTED\n\n",
      "Some treatment effects show moderate sensitivity (max relative variability: ",
      sprintf("%.1f%%", max_rel_var), ").\n",
      if (nrow(high_sensitivity_treatments) > 0) {
        paste0(
          "Treatments with higher sensitivity:\n",
          paste("  •", high_sensitivity_treatments$treatment,
                sprintf("(%.1f%% variability)", high_sensitivity_treatments$relative_variability_pct),
                collapse = "\n"),
          "\n"
        )
      } else "",
      "However, statistical significance remains consistent.\n",
      "\n",
      "RECOMMENDATION: Report primary results with ρ = 0.5.\n",
      "Include sensitivity analysis in supplementary materials.\n",
      "Discuss uncertainty around correlation assumption."
    )
  } else {
    paste0(
      "⚠ HIGH SENSITIVITY DETECTED\n\n",
      "Results are substantially affected by correlation assumption (max relative variability: ",
      sprintf("%.1f%%", max_rel_var), ").\n",
      if (nrow(high_sensitivity_treatments) > 0) {
        paste0(
          "Treatments with high sensitivity:\n",
          paste("  •", high_sensitivity_treatments$treatment,
                sprintf("(%.1f%% variability)", high_sensitivity_treatments$relative_variability_pct),
                collapse = "\n"),
          "\n"
        )
      } else "",
      if (significance_changes) "Statistical significance changes depending on correlation.\n" else "",
      if (!is.na(ranking_stability$stable) && ranking_stability$stable == "Unstable") {
        "Treatment rankings are unstable.\n"
      } else "",
      "\n",
      "RECOMMENDATION: Report results for multiple correlation values.\n",
      "Present range of estimates: ρ = 0.3 (conservative) to 0.7 (liberal).\n",
      "Emphasize uncertainty in conclusions.\n",
      "Consider obtaining empirical correlation data from multi-arm trials."
    )
  }

  recommendation$action_items <- if (max_rel_var < 10) {
    c(
      "✓ Use ρ = 0.5 for primary analysis",
      "✓ Mention sensitivity analysis in methods",
      "✓ State results were robust to correlation assumption"
    )
  } else if (max_rel_var < 20) {
    c(
      "✓ Use ρ = 0.5 for primary analysis",
      "✓ Present sensitivity analysis in supplement",
      "✓ Discuss limitation of correlation assumption",
      "✓ Report range of estimates for sensitive treatments"
    )
  } else {
    c(
      "⚠ Report results for ρ = 0.3, 0.5, and 0.7",
      "⚠ Present all estimates in main text or detailed supplement",
      "⚠ Avoid strong conclusions for sensitive treatments",
      "⚠ Clearly communicate uncertainty",
      "⚠ Consider additional analyses or external correlation data"
    )
  }

  recommendation$multi_arm_context <- paste0(
    "Note: ", n_multi_arm, " multi-arm trials in network.\n",
    "Correlation assumption only affects these studies."
  )

  return(recommendation)
}

#' Plot sensitivity of treatment effects to correlation assumption
#'
#' @param sensitivity_result Result from correlation_sensitivity_analysis()
#' @return ggplot object
#' @export
plot_correlation_sensitivity <- function(sensitivity_result) {

  if (!sensitivity_result$sensitivity_needed) {
    cat("No sensitivity plot needed - no multi-arm trials in network\n")
    return(NULL)
  }

  library(ggplot2)

  # Prepare data for plotting
  plot_data_list <- list()

  correlations <- sensitivity_result$correlations_tested
  treatment_effects_list <- sensitivity_result$treatment_effects
  reference <- sensitivity_result$reference

  for (rho in as.character(correlations)) {
    if (!is.null(treatment_effects_list[[rho]])) {
      effects <- treatment_effects_list[[rho]]

      # Remove reference
      effects <- effects[effects$treatment != reference, ]

      effects$correlation <- as.numeric(rho)

      plot_data_list[[rho]] <- effects
    }
  }

  plot_data <- do.call(rbind, plot_data_list)

  if (nrow(plot_data) == 0) {
    cat("No data available for plotting\n")
    return(NULL)
  }

  # Create line plot showing how estimates change with correlation
  p <- ggplot(plot_data, aes(x = correlation, y = estimate, color = treatment, group = treatment)) +
    geom_line(linewidth = 1) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                  width = 0.02, alpha = 0.6) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    labs(
      title = "Sensitivity of Treatment Effects to Within-Study Correlation",
      subtitle = paste("Outcome:", sensitivity_result$outcome, "| Reference:", reference),
      x = "Within-Study Correlation (ρ)",
      y = "Treatment Effect vs Reference (95% CI)",
      color = "Treatment"
    ) +
    scale_x_continuous(breaks = correlations) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 11),
      axis.title = element_text(size = 12),
      axis.text = element_text(size = 10),
      legend.position = "right",
      legend.title = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )

  return(p)
}
