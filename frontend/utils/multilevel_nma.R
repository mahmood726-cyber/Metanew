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
