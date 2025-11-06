# Plot Recommendation and Styling System
# Intelligent plot suggestions for different analyses and audiences
# Journal-specific and commissioner-friendly styling
#
# Author: EvidenceOS PRIME
# Purpose: Guide users to appropriate visualizations with proper styling

library(ggplot2)

# ============================================================================
# PLOT RECOMMENDATIONS BY ANALYSIS TYPE
# ============================================================================

#' Get recommended plots for an analysis type
#' @param analysis_type Type of analysis
#' @param result_summary Summary of results (for conditional recommendations)
#' @return List of recommended plots with priorities
get_plot_recommendations <- function(analysis_type, result_summary = NULL) {

  recommendations <- switch(analysis_type,
    "pairwise" = list(
      essential = c("forest_plot", "funnel_plot"),
      recommended = c("forest_plot_subgroup", "cumulative_forest", "influence_plot"),
      optional = c("radial_plot", "l_abbe_plot", "baujat_plot"),
      conditional = list(
        high_heterogeneity = c("galbraith_plot", "meta_regression_plot"),
        publication_bias = c("trim_fill_plot", "egger_test_plot"),
        subgroup_analysis = c("forest_plot_subgroup", "subgroup_comparison_plot")
      )
    ),

    "network" = list(
      essential = c("network_graph", "league_table", "forest_plot_nma"),
      recommended = c("rankogram", "sucra_plot", "comparison_adjusted_funnel"),
      optional = c("network_heatmap", "contribution_matrix"),
      conditional = list(
        inconsistency = c("splitting_plot", "node_splitting_forest"),
        many_treatments = c("clustered_ranking", "treatment_hierarchy")
      )
    ),

    "masem" = list(
      essential = c("path_diagram", "fit_indices_plot"),
      recommended = c("correlation_heatmap", "indirect_effects_plot"),
      optional = c("modification_indices_plot", "residual_plot"),
      conditional = list(
        multigroup = c("multigroup_comparison", "invariance_plot"),
        mediation = c("mediation_diagram", "bootstrap_distribution")
      )
    ),

    "hta" = list(
      essential = c("ce_plane", "ceac", "incremental_analysis"),
      recommended = c("evpi_plot", "tornado_diagram", "budget_impact"),
      optional = c("scatter_ce", "ceaf", "net_benefit_plot"),
      conditional = list(
        multiple_comparators = c("frontier_plot", "multi_ceac"),
        subgroup_analysis = c("subgroup_icer", "ce_plane_by_group")
      )
    ),

    "dose_response" = list(
      essential = c("dose_response_curve", "spline_plot"),
      recommended = c("confidence_bands", "study_overlay"),
      optional = c("residual_plot", "influence_dose_response"),
      conditional = list(
        nonlinear = c("knot_selection_plot", "linearity_test_plot")
      )
    ),

    "living_ma" = list(
      essential = c("cumulative_forest", "timeline_plot"),
      recommended = c("evidence_accrual", "stability_plot"),
      optional = c("updating_schedule", "trigger_analysis"),
      conditional = list(
        trend_over_time = c("time_trend_plot", "year_meta_regression")
      )
    ),

    # Default for other types
    list(
      essential = c("forest_plot"),
      recommended = c("funnel_plot"),
      optional = c()
    )
  )

  # Add conditional recommendations based on result summary
  if (!is.null(result_summary)) {
    if (!is.null(result_summary$heterogeneity) && result_summary$heterogeneity$I2 > 50) {
      recommendations$active_conditional <- c(recommendations$active_conditional,
                                              recommendations$conditional$high_heterogeneity)
    }

    if (!is.null(result_summary$publication_bias) && result_summary$publication_bias$significant) {
      recommendations$active_conditional <- c(recommendations$active_conditional,
                                              recommendations$conditional$publication_bias)
    }

    if (!is.null(result_summary$subgroup) && result_summary$subgroup$performed) {
      recommendations$active_conditional <- c(recommendations$active_conditional,
                                              recommendations$conditional$subgroup_analysis)
    }
  }

  return(recommendations)
}

# ============================================================================
# JOURNAL-SPECIFIC STYLING CONFIGURATIONS
# ============================================================================

#' Get journal-specific plot styling guidelines
#' @param journal Journal name or "commissioner" for policy reports
#' @return List of styling parameters
get_journal_style <- function(journal = "default") {

  styles <- list(

    # New England Journal of Medicine
    "nejm" = list(
      name = "New England Journal of Medicine",
      figure_width = 3.5,  # inches (single column)
      figure_width_wide = 7,  # inches (double column)
      figure_height = 3.5,
      dpi = 300,
      font_family = "Arial",
      font_size_base = 8,
      font_size_title = 9,
      font_size_axis = 7,
      color_palette = c("#000000", "#4d4d4d", "#999999"),  # Grayscale preferred
      line_width = 0.5,
      point_size = 2,
      background = "white",
      grid = FALSE,
      guidelines = "Figures should be clear in grayscale. Avoid color unless essential. Use sans-serif fonts."
    ),

    # The Lancet
    "lancet" = list(
      name = "The Lancet",
      figure_width = 3.27,  # inches (single column)
      figure_width_wide = 6.69,  # inches (double column)
      figure_height = 3.27,
      dpi = 300,
      font_family = "Arial",
      font_size_base = 8,
      font_size_title = 10,
      font_size_axis = 7,
      color_palette = c("#DC143C", "#0072B2", "#009E73", "#F0E442"),  # Lancet colors
      line_width = 0.75,
      point_size = 2,
      background = "white",
      grid = TRUE,
      grid_color = "#F0F0F0",
      guidelines = "Use Lancet colors. Clear legends. Accessible to colorblind readers."
    ),

    # British Medical Journal
    "bmj" = list(
      name = "British Medical Journal",
      figure_width = 3.35,
      figure_width_wide = 7,
      figure_height = 3.35,
      dpi = 300,
      font_family = "Arial",
      font_size_base = 9,
      font_size_title = 10,
      font_size_axis = 8,
      color_palette = c("#377eb8", "#e41a1c", "#4daf4a", "#984ea3"),
      line_width = 0.8,
      point_size = 2.5,
      background = "white",
      grid = TRUE,
      guidelines = "Simple, clean figures. Avoid 3D. Clear axis labels."
    ),

    # JAMA
    "jama" = list(
      name = "Journal of the American Medical Association",
      figure_width = 3.25,
      figure_width_wide = 6.75,
      figure_height = 3.25,
      dpi = 300,
      font_family = "Helvetica",
      font_size_base = 8,
      font_size_title = 9,
      font_size_axis = 7,
      color_palette = c("#374E55", "#DF8F44", "#00A1D5", "#B24745"),  # JAMA colors
      line_width = 0.6,
      point_size = 2,
      background = "white",
      grid = FALSE,
      guidelines = "Conservative styling. Professional appearance. Color for emphasis only."
    ),

    # Nature/Science (high-impact)
    "nature" = list(
      name = "Nature",
      figure_width = 3.5,
      figure_width_wide = 7,
      figure_height = 3.5,
      dpi = 600,  # Higher resolution
      font_family = "Helvetica",
      font_size_base = 7,
      font_size_title = 8,
      font_size_axis = 6,
      color_palette = c("#E64B35", "#4DBBD5", "#00A087", "#3C5488"),
      line_width = 0.5,
      point_size = 1.5,
      background = "white",
      grid = FALSE,
      guidelines = "Highest quality. Multi-panel figures common. Publication-ready."
    ),

    # Healthcare Commissioners / Policy Reports
    "commissioner" = list(
      name = "Healthcare Commissioner Report",
      figure_width = 6,
      figure_width_wide = 8,
      figure_height = 4.5,
      dpi = 150,  # Lower DPI for reports
      font_family = "Arial",
      font_size_base = 12,  # Larger for readability
      font_size_title = 14,
      font_size_axis = 11,
      color_palette = c("#2E86AB", "#A23B72", "#F18F01", "#06A77D"),  # Bold, distinct
      line_width = 1.2,  # Thicker lines
      point_size = 4,  # Larger points
      background = "white",
      grid = TRUE,
      grid_color = "#E5E5E5",
      guidelines = "Large, clear text. Bold colors. Emphasize key findings. Minimal jargon."
    ),

    # Plain Language / Patient-Facing
    "plain" = list(
      name = "Plain Language Report",
      figure_width = 7,
      figure_width_wide = 7,
      figure_height = 5,
      dpi = 150,
      font_family = "Arial",
      font_size_base = 14,  # Very large for accessibility
      font_size_title = 16,
      font_size_axis = 12,
      color_palette = c("#1f77b4", "#ff7f0e", "#2ca02c", "#d62728"),  # Simple, familiar
      line_width = 1.5,
      point_size = 5,
      background = "white",
      grid = TRUE,
      grid_color = "#DDDDDD",
      guidelines = "Maximum clarity. Avoid technical terms. Large text. Simple layouts."
    ),

    # Default academic
    "default" = list(
      name = "Standard Academic",
      figure_width = 6,
      figure_width_wide = 8,
      figure_height = 4.5,
      dpi = 300,
      font_family = "sans",
      font_size_base = 10,
      font_size_title = 12,
      font_size_axis = 9,
      color_palette = c("#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"),
      line_width = 0.8,
      point_size = 2.5,
      background = "white",
      grid = TRUE,
      guidelines = "Standard academic figure guidelines."
    )
  )

  if (!(journal %in% names(styles))) {
    warning("Journal '", journal, "' not found. Using default style.")
    return(styles$default)
  }

  return(styles[[journal]])
}

# ============================================================================
# REPORT FORMAT SPECIFICATIONS
# ============================================================================

#' Get report format specifications
#' @param format Report format type
#' @return List of format specifications
get_report_format <- function(format = "full_paper") {

  formats <- list(

    # Abstract (conference, database)
    "abstract" = list(
      name = "Abstract",
      word_limit = 250,
      sections = c("background", "methods_brief", "results_brief", "conclusion"),
      max_figures = 0,
      max_tables = 0,
      style = "technical",
      guidelines = "Structured abstract. No figures/tables. Key findings only."
    ),

    # Short report (rapid communication)
    "short_report" = list(
      name = "Short Report",
      word_limit = 1500,
      sections = c("introduction_brief", "methods", "results", "discussion_brief"),
      max_figures = 2,
      max_tables = 1,
      style = "technical",
      guidelines = "Concise. Essential methods. Key results. Brief discussion."
    ),

    # Full paper (standard journal article)
    "full_paper" = list(
      name = "Full Research Paper",
      word_limit = 5000,
      sections = c("introduction", "methods", "results", "discussion", "conclusion"),
      max_figures = 6,
      max_tables = 4,
      style = "technical",
      guidelines = "Complete methodology. Comprehensive results. Full discussion."
    ),

    # Essay (review, commentary)
    "essay" = list(
      name = "Essay / Commentary",
      word_limit = 3000,
      sections = c("introduction", "main_argument", "evidence", "implications", "conclusion"),
      max_figures = 3,
      max_tables = 2,
      style = "balanced",
      guidelines = "Narrative style. Synthesize evidence. Practical implications."
    ),

    # Dissertation chapter
    "dissertation" = list(
      name = "Dissertation Chapter",
      word_limit = 10000,
      sections = c("introduction", "literature_review", "methods_detailed", "results_comprehensive",
                   "discussion_detailed", "limitations", "conclusion", "future_work"),
      max_figures = 12,
      max_tables = 8,
      style = "technical",
      guidelines = "Exhaustive. All methodological details. Complete results. Extensive discussion."
    ),

    # Policy brief (healthcare commissioners)
    "policy_brief" = list(
      name = "Policy Brief",
      word_limit = 2000,
      sections = c("executive_summary", "key_findings", "implications", "recommendations"),
      max_figures = 4,
      max_tables = 2,
      style = "plain",
      guidelines = "Decision-focused. Clear recommendations. Visual emphasis. Minimal jargon."
    ),

    # Technical report (HTA agencies)
    "technical_report" = list(
      name = "Technical HTA Report",
      word_limit = 15000,
      sections = c("executive_summary", "background", "methods_detailed", "results_detailed",
                   "economic_evaluation", "budget_impact", "discussion", "recommendations"),
      max_figures = 15,
      max_tables = 10,
      style = "technical",
      guidelines = "Comprehensive HTA. All evidence. Economic analysis. Policy recommendations."
    ),

    # Patient information
    "patient_info" = list(
      name = "Patient Information Sheet",
      word_limit = 800,
      sections = c("what_we_found", "what_this_means", "what_to_discuss"),
      max_figures = 2,
      max_tables = 0,
      style = "plain",
      guidelines = "Plain language. Large text. Visual aids. Actionable information."
    )
  )

  if (!(format %in% names(formats))) {
    warning("Format '", format, "' not found. Using full_paper.")
    return(formats$full_paper)
  }

  return(formats[[format]])
}

# ============================================================================
# PLOT DESCRIPTION GENERATOR
# ============================================================================

#' Generate descriptions for recommended plots
#' @param plot_name Name of the plot
#' @param analysis_type Type of analysis
#' @return Description text
get_plot_description <- function(plot_name, analysis_type = NULL) {

  descriptions <- list(
    # Meta-analysis plots
    "forest_plot" = "Shows effect sizes and confidence intervals for each study and the pooled estimate. Essential for visualizing meta-analysis results.",
    "funnel_plot" = "Scatter plot for detecting publication bias. Asymmetry suggests missing studies.",
    "forest_plot_subgroup" = "Forest plot with studies grouped by subgroup variable. Shows subgroup-specific pooled estimates.",
    "cumulative_forest" = "Shows how pooled estimate changes as studies are added chronologically. Useful for living meta-analyses.",
    "influence_plot" = "Identifies influential studies that substantially affect pooled estimate when removed.",
    "radial_plot" = "Circular representation showing study precision and effects. Alternative to funnel plot.",
    "galbraith_plot" = "Helps identify sources of heterogeneity by showing studies outside confidence bounds.",
    "trim_fill_plot" = "Funnel plot with imputed studies (red points) showing adjusted estimate accounting for publication bias.",

    # Network meta-analysis plots
    "network_graph" = "Network diagram showing which treatments have been compared directly. Node size indicates number of patients.",
    "league_table" = "Matrix showing all pairwise treatment comparisons with effect sizes and confidence intervals.",
    "rankogram" = "Probability distributions showing likelihood each treatment ranks 1st, 2nd, 3rd, etc.",
    "sucra_plot" = "Bar chart of SUCRA values (Surface Under Cumulative Ranking curve). Higher = better treatment.",
    "comparison_adjusted_funnel" = "Funnel plot for network meta-analysis to detect small-study effects and bias.",
    "network_heatmap" = "Heatmap showing relative effects between all treatment pairs. Color intensity = effect magnitude.",

    # MASEM plots
    "path_diagram" = "Structural equation model diagram showing relationships between variables with path coefficients.",
    "fit_indices_plot" = "Bar chart of model fit indices (CFI, TLI, RMSEA, SRMR) with cutoff lines for good fit.",
    "correlation_heatmap" = "Heatmap of pooled correlations between all variables in the model.",
    "indirect_effects_plot" = "Bar chart showing indirect effects with confidence intervals. Useful for mediation models.",
    "multigroup_comparison" = "Side-by-side comparison of path coefficients across groups with significance tests.",
    "invariance_plot" = "Line plot showing model fit across invariance levels (configural, metric, scalar, strict).",

    # Health economics plots
    "ce_plane" = "Cost-effectiveness plane showing incremental costs (y-axis) vs incremental effects (x-axis). Quadrants indicate dominance.",
    "ceac" = "Cost-effectiveness acceptability curve showing probability treatment is cost-effective at different willingness-to-pay thresholds.",
    "evpi_plot" = "Expected value of perfect information curve. Shows value of future research at different WTP thresholds.",
    "tornado_diagram" = "Horizontal bar chart showing which parameters have largest impact on ICER (one-way sensitivity analysis).",
    "budget_impact" = "Stacked bar chart showing budget impact over time with different adoption scenarios.",

    # Dose-response plots
    "dose_response_curve" = "Shows relationship between dose/exposure level and outcome. May be linear or non-linear (spline).",
    "spline_plot" = "Flexible dose-response curve using restricted cubic splines. Shows non-linear relationships."
  )

  if (plot_name %in% names(descriptions)) {
    return(descriptions[[plot_name]])
  } else {
    return("Visualization for analysis results.")
  }
}

# ============================================================================
# INTEGRATED PLOT RECOMMENDATIONS WITH STYLING
# ============================================================================

#' Generate complete plot recommendations with descriptions and styling
#' @param analysis_type Type of analysis
#' @param journal Target journal or audience
#' @param report_format Report format type
#' @param result_summary Summary of results
#' @return Complete recommendations
generate_plot_guidance <- function(analysis_type,
                                   journal = "default",
                                   report_format = "full_paper",
                                   result_summary = NULL) {

  # Get recommendations
  plots <- get_plot_recommendations(analysis_type, result_summary)

  # Get styling
  style <- get_journal_style(journal)

  # Get format limits
  format_spec <- get_report_format(report_format)

  # Build guidance
  guidance <- list(
    analysis_type = analysis_type,
    journal = style$name,
    format = format_spec$name,
    max_figures = format_spec$max_figures,
    style = style
  )

  # Essential plots (always include up to max)
  guidance$essential_plots <- lapply(plots$essential, function(plot_name) {
    list(
      name = plot_name,
      priority = "essential",
      description = get_plot_description(plot_name, analysis_type),
      recommended_size = if (grepl("wide|league|heatmap", plot_name)) {
        list(width = style$figure_width_wide, height = style$figure_height)
      } else {
        list(width = style$figure_width, height = style$figure_height)
      }
    )
  })

  # Recommended plots (include if space allows)
  guidance$recommended_plots <- lapply(plots$recommended, function(plot_name) {
    list(
      name = plot_name,
      priority = "recommended",
      description = get_plot_description(plot_name, analysis_type),
      recommended_size = list(width = style$figure_width, height = style$figure_height)
    )
  })

  # Optional plots
  guidance$optional_plots <- lapply(plots$optional, function(plot_name) {
    list(
      name = plot_name,
      priority = "optional",
      description = get_plot_description(plot_name, analysis_type),
      recommended_size = list(width = style$figure_width, height = style$figure_height)
    )
  })

  # Active conditional plots (based on results)
  if (!is.null(plots$active_conditional)) {
    guidance$conditional_plots <- lapply(plots$active_conditional, function(plot_name) {
      list(
        name = plot_name,
        priority = "conditional",
        description = get_plot_description(plot_name, analysis_type),
        reason = "Recommended based on your specific results",
        recommended_size = list(width = style$figure_width, height = style$figure_height)
      )
    })
  }

  # Styling guidelines summary
  guidance$styling_notes <- style$guidelines

  # Format-specific advice
  guidance$format_advice <- sprintf(
    "For %s format: Include up to %d figures (max %d tables). %s",
    format_spec$name,
    format_spec$max_figures,
    format_spec$max_tables,
    format_spec$guidelines
  )

  return(guidance)
}

# ============================================================================
# HUMAN-READABLE PLOT GUIDANCE REPORT
# ============================================================================

#' Generate formatted plot guidance report
#' @param guidance Output from generate_plot_guidance()
#' @return Formatted text report
format_plot_guidance <- function(guidance) {

  lines <- c()

  lines <- c(lines, "═══════════════════════════════════════════════════════════")
  lines <- c(lines, "PLOT RECOMMENDATIONS & STYLING GUIDE")
  lines <- c(lines, "═══════════════════════════════════════════════════════════")
  lines <- c(lines, "")
  lines <- c(lines, sprintf("Analysis Type: %s", guidance$analysis_type))
  lines <- c(lines, sprintf("Target Journal/Audience: %s", guidance$journal))
  lines <- c(lines, sprintf("Report Format: %s", guidance$format))
  lines <- c(lines, sprintf("Maximum Figures Allowed: %d", guidance$max_figures))
  lines <- c(lines, "")

  lines <- c(lines, "───────────────────────────────────────────────────────────")
  lines <- c(lines, "ESSENTIAL PLOTS (Must Include)")
  lines <- c(lines, "───────────────────────────────────────────────────────────")
  lines <- c(lines, "")

  for (i in seq_along(guidance$essential_plots)) {
    plot <- guidance$essential_plots[[i]]
    lines <- c(lines, sprintf("%d. %s", i, plot$name))
    lines <- c(lines, sprintf("   %s", plot$description))
    lines <- c(lines, sprintf("   Size: %.1f × %.1f inches at %d DPI",
                             plot$recommended_size$width,
                             plot$recommended_size$height,
                             guidance$style$dpi))
    lines <- c(lines, "")
  }

  if (length(guidance$recommended_plots) > 0) {
    lines <- c(lines, "───────────────────────────────────────────────────────────")
    lines <- c(lines, "RECOMMENDED PLOTS (Include if Space Allows)")
    lines <- c(lines, "───────────────────────────────────────────────────────────")
    lines <- c(lines, "")

    for (i in seq_along(guidance$recommended_plots)) {
      plot <- guidance$recommended_plots[[i]]
      lines <- c(lines, sprintf("• %s", plot$name))
      lines <- c(lines, sprintf("  %s", plot$description))
      lines <- c(lines, "")
    }
  }

  if (!is.null(guidance$conditional_plots) && length(guidance$conditional_plots) > 0) {
    lines <- c(lines, "───────────────────────────────────────────────────────────")
    lines <- c(lines, "SUGGESTED BASED ON YOUR RESULTS")
    lines <- c(lines, "───────────────────────────────────────────────────────────")
    lines <- c(lines, "")

    for (i in seq_along(guidance$conditional_plots)) {
      plot <- guidance$conditional_plots[[i]]
      lines <- c(lines, sprintf("⚡ %s", plot$name))
      lines <- c(lines, sprintf("   %s", plot$description))
      lines <- c(lines, sprintf("   Why: %s", plot$reason))
      lines <- c(lines, "")
    }
  }

  lines <- c(lines, "───────────────────────────────────────────────────────────")
  lines <- c(lines, "STYLING GUIDELINES")
  lines <- c(lines, "───────────────────────────────────────────────────────────")
  lines <- c(lines, "")
  lines <- c(lines, sprintf("Font: %s, %d pt (base)", guidance$style$font_family, guidance$style$font_size_base))
  lines <- c(lines, sprintf("Resolution: %d DPI", guidance$style$dpi))
  lines <- c(lines, sprintf("Line Width: %.1f pt", guidance$style$line_width))
  lines <- c(lines, sprintf("Point Size: %.1f", guidance$style$point_size))
  lines <- c(lines, sprintf("Background: %s", guidance$style$background))
  lines <- c(lines, sprintf("Grid: %s", ifelse(guidance$style$grid, "Yes", "No")))
  lines <- c(lines, "")
  lines <- c(lines, sprintf("Guidelines: %s", guidance$styling_notes))
  lines <- c(lines, "")

  lines <- c(lines, "───────────────────────────────────────────────────────────")
  lines <- c(lines, "FORMAT-SPECIFIC ADVICE")
  lines <- c(lines, "───────────────────────────────────────────────────────────")
  lines <- c(lines, "")
  lines <- c(lines, guidance$format_advice)
  lines <- c(lines, "")

  lines <- c(lines, "═══════════════════════════════════════════════════════════")

  return(paste(lines, collapse = "\n"))
}
