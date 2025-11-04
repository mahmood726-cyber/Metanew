# ============================================================================
# SPECIALIZED VISUALIZATIONS MODULE
# V4.0 Phase 3: Domain-specific advanced plotting functions
# ============================================================================
#
# Provides publication-quality visualizations for:
# - Genomic Meta-Analysis (Manhattan, QQ, LocusZoom-style regional plots)
# - Diagnostic Test Accuracy (SROC with confidence regions, Fagan nomograms)
# - Real-World Evidence (Love plots, propensity score distributions)
# - Component NMA (Contribution plots, interaction heatmaps)
# - Advanced NMA (Deviance comparison, RMST gains, UME inconsistency)
#
# Author: Metanew Development Team
# Date: 2025-11-04
# Version: 4.0.0
# ============================================================================

library(ggplot2)
library(gridExtra)
library(scales)
library(viridis)
library(ggrepel)
library(patchwork)

# ============================================================================
# GENOMIC VISUALIZATION FUNCTIONS
# ============================================================================

plot_manhattan <- function(gwas_results, significance_threshold = 5e-8,
                          highlight_snps = NULL, title = "Manhattan Plot") {
  # Prepare data
  gwas_results$CHR <- as.numeric(gwas_results$CHR)
  gwas_results <- gwas_results[order(gwas_results$CHR, gwas_results$POS), ]
  gwas_results$log10p <- -log10(gwas_results$P)

  # Calculate chromosome positions for x-axis
  gwas_results$BPcum <- NA
  s <- 0
  chr_centers <- numeric()
  for (chr in unique(gwas_results$CHR)) {
    chr_data <- gwas_results[gwas_results$CHR == chr, ]
    gwas_results$BPcum[gwas_results$CHR == chr] <- chr_data$POS + s
    chr_centers[chr] <- s + median(chr_data$POS)
    s <- s + max(chr_data$POS)
  }

  # Create plot
  p <- ggplot(gwas_results, aes(x = BPcum, y = log10p, color = factor(CHR %% 2))) +
    geom_point(alpha = 0.6, size = 1.3) +
    scale_color_manual(values = c("#2c3e50", "#3498db"), guide = "none") +
    scale_x_continuous(
      name = "Chromosome",
      breaks = chr_centers,
      labels = names(chr_centers)
    ) +
    scale_y_continuous(name = expression(-log[10](italic(P)))) +
    geom_hline(yintercept = -log10(significance_threshold),
               linetype = "dashed", color = "red", size = 1) +
    labs(title = title) +
    theme_minimal() +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16)
    )

  # Highlight specific SNPs if provided
  if (!is.null(highlight_snps)) {
    highlight_data <- gwas_results[gwas_results$SNP %in% highlight_snps, ]
    p <- p +
      geom_point(data = highlight_data, aes(x = BPcum, y = log10p),
                color = "#e74c3c", size = 3) +
      geom_text_repel(
        data = highlight_data,
        aes(x = BPcum, y = log10p, label = SNP),
        size = 3, color = "black",
        box.padding = 0.5,
        point.padding = 0.3
      )
  }

  return(p)
}

plot_qq <- function(pvalues, title = "QQ Plot") {
  # Calculate expected and observed
  observed <- sort(-log10(pvalues))
  n <- length(observed)
  expected <- -log10(ppoints(n))

  # Calculate lambda GC
  lambda_gc <- median(qchisq(1 - pvalues, 1), na.rm = TRUE) / qchisq(0.5, 1)

  # Create plot
  qq_data <- data.frame(expected = expected, observed = observed)

  p <- ggplot(qq_data, aes(x = expected, y = observed)) +
    geom_point(alpha = 0.5, color = "#3498db") +
    geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
    labs(
      title = title,
      subtitle = sprintf("λGC = %.3f", lambda_gc),
      x = expression(Expected~~-log[10](italic(P))),
      y = expression(Observed~~-log[10](italic(P)))
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 12)
    )

  return(p)
}

plot_regional_locus <- function(gwas_results, lead_snp, window_kb = 500,
                                gene_annotations = NULL) {
  # Extract region around lead SNP
  lead_data <- gwas_results[gwas_results$SNP == lead_snp, ]
  chr <- lead_data$CHR[1]
  pos <- lead_data$POS[1]

  region_data <- gwas_results[
    gwas_results$CHR == chr &
    gwas_results$POS >= (pos - window_kb * 1000) &
    gwas_results$POS <= (pos + window_kb * 1000),
  ]

  region_data$log10p <- -log10(region_data$P)

  # Create plot
  p <- ggplot(region_data, aes(x = POS / 1e6, y = log10p)) +
    geom_point(aes(color = log10p), size = 2, alpha = 0.7) +
    scale_color_viridis(option = "plasma", direction = -1, guide = "none") +
    geom_point(
      data = region_data[region_data$SNP == lead_snp, ],
      aes(x = POS / 1e6, y = log10p),
      color = "#e74c3c", size = 5, shape = 18
    ) +
    labs(
      title = sprintf("Regional Plot: %s (Chr %s)", lead_snp, chr),
      x = sprintf("Position on Chr %s (Mb)", chr),
      y = expression(-log[10](italic(P)))
    ) +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5, face = "bold"))

  # Add gene annotations if provided
  if (!is.null(gene_annotations)) {
    # Gene track at bottom
    p <- p + geom_segment(
      data = gene_annotations,
      aes(x = start / 1e6, xend = end / 1e6, y = -1, yend = -1),
      color = "#2c3e50", size = 2
    )
  }

  return(p)
}

# ============================================================================
# DIAGNOSTIC TEST ACCURACY VISUALIZATIONS
# ============================================================================

plot_sroc <- function(test_effects, confidence_regions = TRUE) {
  # Create SROC plot
  p <- ggplot(test_effects, aes(x = 1 - spec, y = sens)) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray50") +
    scale_x_continuous(
      name = "1 - Specificity (False Positive Rate)",
      limits = c(0, 1),
      breaks = seq(0, 1, 0.2)
    ) +
    scale_y_continuous(
      name = "Sensitivity (True Positive Rate)",
      limits = c(0, 1),
      breaks = seq(0, 1, 0.2)
    ) +
    labs(title = "Summary ROC Curve") +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      aspect.ratio = 1
    )

  # Add confidence regions if requested
  if (confidence_regions) {
    p <- p + geom_errorbar(
      aes(ymin = sens_lci, ymax = sens_uci),
      width = 0.02, alpha = 0.5
    ) +
    geom_errorbarh(
      aes(xmin = 1 - spec_uci, xmax = 1 - spec_lci),
      height = 0.02, alpha = 0.5
    )
  }

  # Add points for each test
  p <- p +
    geom_point(aes(color = test), size = 4) +
    geom_text_repel(
      aes(label = test),
      size = 3,
      box.padding = 0.5
    ) +
    scale_color_viridis(discrete = TRUE, option = "viridis") +
    guides(color = guide_legend(title = "Test"))

  return(p)
}

plot_fagan_nomogram <- function(pretest_prob, lr_plus, lr_minus) {
  # Fagan nomogram for clinical utility
  # Calculate post-test probabilities
  pretest_odds <- pretest_prob / (1 - pretest_prob)
  posttest_odds_plus <- pretest_odds * lr_plus
  posttest_odds_minus <- pretest_odds * lr_minus

  posttest_prob_plus <- posttest_odds_plus / (1 + posttest_odds_plus)
  posttest_prob_minus <- posttest_odds_minus / (1 + posttest_odds_minus)

  # Create nomogram data
  nomogram_data <- data.frame(
    x = c(0, 1, 2),
    y_pretest = rep(pretest_prob, 3),
    y_posttest_plus = c(pretest_prob, NA, posttest_prob_plus),
    y_posttest_minus = c(pretest_prob, NA, posttest_prob_minus)
  )

  # Plot
  p <- ggplot() +
    geom_segment(aes(x = 0, y = 0, xend = 0, yend = 1), size = 1) +
    geom_segment(aes(x = 2, y = 0, xend = 2, yend = 1), size = 1) +
    geom_point(aes(x = 0, y = pretest_prob), size = 4, color = "#3498db") +
    geom_point(aes(x = 2, y = posttest_prob_plus), size = 4, color = "#27ae60") +
    geom_point(aes(x = 2, y = posttest_prob_minus), size = 4, color = "#e74c3c") +
    geom_segment(aes(x = 0, y = pretest_prob, xend = 2, yend = posttest_prob_plus),
                linetype = "dashed", color = "#27ae60") +
    geom_segment(aes(x = 0, y = pretest_prob, xend = 2, yend = posttest_prob_minus),
                linetype = "dashed", color = "#e74c3c") +
    scale_x_continuous(limits = c(-0.5, 2.5), breaks = c(0, 2),
                      labels = c("Pre-test", "Post-test")) +
    scale_y_continuous(limits = c(0, 1), labels = percent) +
    labs(
      title = "Fagan Nomogram",
      y = "Probability"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.title.x = element_blank()
    )

  return(p)
}

plot_ppv_npv_curves <- function(test_effects, prevalence_range = seq(0.01, 0.99, 0.01)) {
  # Calculate PPV and NPV across prevalence range
  ppv_npv_data <- data.frame()

  for (test in test_effects$test) {
    test_data <- test_effects[test_effects$test == test, ]
    sens <- test_data$sens
    spec <- test_data$spec

    ppv <- (sens * prevalence_range) /
           (sens * prevalence_range + (1 - spec) * (1 - prevalence_range))
    npv <- (spec * (1 - prevalence_range)) /
           ((1 - sens) * prevalence_range + spec * (1 - prevalence_range))

    ppv_npv_data <- rbind(
      ppv_npv_data,
      data.frame(
        test = test,
        prevalence = prevalence_range,
        value = ppv,
        metric = "PPV"
      ),
      data.frame(
        test = test,
        prevalence = prevalence_range,
        value = npv,
        metric = "NPV"
      )
    )
  }

  # Create plot
  p <- ggplot(ppv_npv_data, aes(x = prevalence, y = value, color = test, linetype = metric)) +
    geom_line(size = 1) +
    scale_x_continuous(name = "Disease Prevalence", labels = percent) +
    scale_y_continuous(name = "Predictive Value", labels = percent) +
    scale_color_viridis(discrete = TRUE) +
    labs(
      title = "PPV and NPV vs. Disease Prevalence",
      color = "Test",
      linetype = "Metric"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      legend.position = "right"
    )

  return(p)
}

# ============================================================================
# REAL-WORLD EVIDENCE VISUALIZATIONS
# ============================================================================

plot_love_plot <- function(covariate_balance, threshold = 0.1) {
  # Love plot showing standardized mean differences
  covariate_balance$covariate <- factor(
    covariate_balance$covariate,
    levels = covariate_balance$covariate[order(abs(covariate_balance$smd_before))]
  )

  # Reshape for plotting
  love_data <- rbind(
    data.frame(
      covariate = covariate_balance$covariate,
      smd = covariate_balance$smd_before,
      timing = "Before Adjustment"
    ),
    data.frame(
      covariate = covariate_balance$covariate,
      smd = covariate_balance$smd_after,
      timing = "After Adjustment"
    )
  )

  # Create plot
  p <- ggplot(love_data, aes(x = smd, y = covariate, color = timing, shape = timing)) +
    geom_vline(xintercept = 0, linetype = "solid", color = "gray30") +
    geom_vline(xintercept = c(-threshold, threshold),
              linetype = "dashed", color = "red", alpha = 0.5) +
    geom_point(size = 3) +
    geom_line(aes(group = covariate), color = "gray70") +
    scale_color_manual(values = c("#e74c3c", "#27ae60")) +
    scale_shape_manual(values = c(16, 17)) +
    labs(
      title = "Covariate Balance: Love Plot",
      subtitle = "Dashed lines indicate ±0.1 standardized mean difference threshold",
      x = "Standardized Mean Difference",
      y = "Covariate",
      color = "",
      shape = ""
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 10),
      legend.position = "bottom"
    )

  return(p)
}

plot_propensity_distribution <- function(ps_data, treatment_var) {
  # Propensity score distribution by treatment group
  p <- ggplot(ps_data, aes(x = propensity_score, fill = factor(get(treatment_var)))) +
    geom_density(alpha = 0.5) +
    scale_fill_manual(
      values = c("#3498db", "#e74c3c"),
      labels = c("Control", "Treated")
    ) +
    labs(
      title = "Propensity Score Distribution",
      x = "Propensity Score",
      y = "Density",
      fill = "Group"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      legend.position = "bottom"
    )

  return(p)
}

plot_e_value_sensitivity <- function(rr_observed, e_value) {
  # E-value sensitivity contour
  confounder_strength <- seq(1, e_value + 2, 0.1)
  observed_rr_grid <- seq(0.5, 3, 0.1)

  sensitivity_data <- expand.grid(
    confounder = confounder_strength,
    observed_rr = observed_rr_grid
  )

  sensitivity_data$bias_adjusted_rr <- sensitivity_data$observed_rr /
    (sensitivity_data$confounder * sensitivity_data$confounder)

  # Create contour plot
  p <- ggplot(sensitivity_data, aes(x = confounder, y = observed_rr, z = bias_adjusted_rr)) +
    geom_contour_filled(bins = 15) +
    geom_hline(yintercept = rr_observed, linetype = "dashed", color = "white", size = 1) +
    geom_vline(xintercept = e_value, linetype = "dashed", color = "white", size = 1) +
    annotate("point", x = e_value, y = rr_observed, color = "red", size = 4) +
    labs(
      title = "E-value Sensitivity Analysis",
      subtitle = sprintf("E-value = %.2f (dashed lines)", e_value),
      x = "Confounder Strength (RR)",
      y = "Observed Risk Ratio",
      fill = "Bias-Adjusted RR"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 10)
    )

  return(p)
}

# ============================================================================
# COMPONENT NMA VISUALIZATIONS
# ============================================================================

plot_component_forest <- function(component_effects) {
  # Forest plot of component effects
  component_effects$component <- factor(
    component_effects$component,
    levels = component_effects$component[order(component_effects$effect)]
  )

  p <- ggplot(component_effects, aes(x = effect, y = component)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(
      aes(xmin = lci, xmax = uci),
      height = 0.2,
      color = "#3498db"
    ) +
    geom_point(size = 3, color = "#2c3e50") +
    labs(
      title = "Component Effects",
      x = "Effect Size (95% CrI)",
      y = "Component"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16)
    )

  return(p)
}

plot_interaction_heatmap <- function(interaction_matrix) {
  # Heatmap of component interactions
  # Convert to long format
  n_comp <- nrow(interaction_matrix)
  comp_names <- rownames(interaction_matrix)

  heatmap_data <- data.frame()
  for (i in 1:n_comp) {
    for (j in 1:n_comp) {
      heatmap_data <- rbind(
        heatmap_data,
        data.frame(
          comp1 = comp_names[i],
          comp2 = comp_names[j],
          interaction = interaction_matrix[i, j]
        )
      )
    }
  }

  # Create heatmap
  p <- ggplot(heatmap_data, aes(x = comp1, y = comp2, fill = interaction)) +
    geom_tile(color = "white") +
    geom_text(aes(label = sprintf("%.2f", interaction)), color = "white", size = 3) +
    scale_fill_gradient2(
      low = "#3498db",
      mid = "white",
      high = "#e74c3c",
      midpoint = 0,
      name = "Interaction\nEffect"
    ) +
    labs(
      title = "Component Interaction Heatmap",
      x = "Component",
      y = "Component"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )

  return(p)
}

# ============================================================================
# ADVANCED NMA VISUALIZATIONS
# ============================================================================

plot_ume_deviance_comparison <- function(consistency_deviance, ume_deviance, df_diff) {
  # Deviance comparison plot
  comparison_data <- data.frame(
    model = c("Consistency", "UME"),
    deviance = c(consistency_deviance, ume_deviance)
  )

  p <- ggplot(comparison_data, aes(x = model, y = deviance, fill = model)) +
    geom_bar(stat = "identity", width = 0.6) +
    geom_text(aes(label = sprintf("%.1f", deviance)), vjust = -0.5, size = 5) +
    scale_fill_manual(values = c("#3498db", "#e74c3c"), guide = "none") +
    labs(
      title = "Model Deviance Comparison",
      subtitle = sprintf("Deviance difference = %.1f (df = %d)",
                        consistency_deviance - ume_deviance, df_diff),
      x = "Model",
      y = "Deviance"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 12)
    )

  return(p)
}

plot_rmst_gains <- function(rmst_results) {
  # Forest plot of RMST gains (months gained)
  rmst_results$treatment <- factor(
    rmst_results$treatment,
    levels = rmst_results$treatment[order(rmst_results$rmst_diff)]
  )

  p <- ggplot(rmst_results, aes(x = rmst_diff, y = treatment)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(
      aes(xmin = rmst_diff_lci, xmax = rmst_diff_uci),
      height = 0.2,
      color = "#27ae60"
    ) +
    geom_point(size = 3, color = "#2c3e50") +
    labs(
      title = "Restricted Mean Survival Time Gains",
      x = "Months Gained (95% CrI)",
      y = "Treatment"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 16)
    )

  return(p)
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

save_publication_plot <- function(plot, filename, width = 10, height = 8, dpi = 300) {
  ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    units = "in"
  )
}
