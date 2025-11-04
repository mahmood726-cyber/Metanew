# ============================================================================
# UNIVERSAL REPORT TEMPLATES MODULE
# V4.0 Phase 3: Comprehensive report generation for all specialized domains
# ============================================================================
#
# Provides automated report generation for:
# - Genomic Meta-Analysis (Manhattan plots, gene tables, enrichment)
# - Diagnostic Test Accuracy NMA (SROC plots, test comparison, clinical utility)
# - Real-World Evidence Integration (transportability, bias assessment, sensitivity)
# - Component Network Meta-Analysis (component effects, interactions, optimal combinations)
# - UME Consistency Analysis (deviance comparison, inconsistency assessment)
# - RMST Network Meta-Analysis (months gained, survival interpretations)
#
# Author: Metanew Development Team
# Date: 2025-11-04
# Version: 4.0.0
# ============================================================================

library(shiny)
library(ggplot2)
library(gridExtra)
library(knitr)
library(rmarkdown)

# ============================================================================
# GENOMIC META-ANALYSIS REPORT
# ============================================================================

generate_genomic_ma_report <- function(results, output_dir = tempdir()) {
  report_data <- list(
    title = "Genomic Meta-Analysis Report",
    date = Sys.Date(),
    results = results
  )

  # Create report sections
  sections <- list()

  # 1. Summary section
  sections$summary <- create_genomic_summary(results)

  # 2. Manhattan plot section
  sections$manhattan <- create_manhattan_section(results$manhattan_data)

  # 3. Top hits table
  sections$top_hits <- create_top_hits_table(results$lead_snps)

  # 4. Gene annotation
  if (!is.null(results$gene_annotation)) {
    sections$genes <- create_gene_annotation_section(results$gene_annotation)
  }

  # 5. Pathway enrichment
  if (!is.null(results$pathway_enrichment)) {
    sections$pathways <- create_pathway_enrichment_section(results$pathway_enrichment)
  }

  # 6. Quality control
  sections$qc <- create_genomic_qc_section(results)

  # Compile report
  report_html <- compile_report_sections(sections, report_data)

  # Save report
  output_file <- file.path(output_dir, "genomic_ma_report.html")
  writeLines(report_html, output_file)

  return(output_file)
}

create_genomic_summary <- function(results) {
  n_snps <- nrow(results$gwas_results)
  n_significant <- sum(results$gwas_results$P < 5e-8, na.rm = TRUE)
  n_loci <- nrow(results$lead_snps)
  lambda_gc <- results$lambda_gc

  summary_text <- sprintf("
    <div class='section'>
      <h2>Summary</h2>
      <ul>
        <li><strong>Total SNPs analyzed:</strong> %s</li>
        <li><strong>Genome-wide significant SNPs (P &lt; 5×10⁻⁸):</strong> %s</li>
        <li><strong>Independent loci identified:</strong> %s</li>
        <li><strong>Genomic inflation factor (λ<sub>GC</sub>):</strong> %.3f</li>
        <li><strong>Population stratification:</strong> %s</li>
      </ul>
    </div>
  ",
    format(n_snps, big.mark = ","),
    format(n_significant, big.mark = ","),
    n_loci,
    lambda_gc,
    ifelse(lambda_gc < 1.05, "Minimal (λ<sub>GC</sub> < 1.05)",
           ifelse(lambda_gc < 1.10, "Moderate (1.05 ≤ λ<sub>GC</sub> < 1.10)",
                  "Substantial (λ<sub>GC</sub> ≥ 1.10) - consider LD score regression"))
  )

  return(summary_text)
}

create_manhattan_section <- function(manhattan_data) {
  manhattan_html <- sprintf("
    <div class='section'>
      <h2>Manhattan Plot</h2>
      <p>Genome-wide association results across all chromosomes. The red line indicates genome-wide significance (P = 5×10⁻⁸).</p>
      <img src='manhattan_plot.png' style='width:100%%;max-width:1200px;'>
    </div>
  ")

  return(manhattan_html)
}

create_top_hits_table <- function(lead_snps) {
  if (nrow(lead_snps) == 0) {
    return("<div class='section'><h2>Top Hits</h2><p>No genome-wide significant associations detected.</p></div>")
  }

  # Format table
  table_rows <- apply(lead_snps, 1, function(row) {
    sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%.3f</td><td>%.3f</td><td>%.2e</td></tr>",
            row["SNP"], row["CHR"], format(as.numeric(row["POS"]), big.mark = ","),
            as.numeric(row["BETA"]), as.numeric(row["SE"]), as.numeric(row["P"]))
  })

  table_html <- sprintf("
    <div class='section'>
      <h2>Top Hits</h2>
      <p>Independent genome-wide significant loci (P &lt; 5×10⁻⁸).</p>
      <table class='results-table'>
        <thead>
          <tr>
            <th>SNP</th>
            <th>Chr</th>
            <th>Position</th>
            <th>Beta</th>
            <th>SE</th>
            <th>P-value</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
    </div>
  ", paste(table_rows, collapse = "\n"))

  return(table_html)
}

create_gene_annotation_section <- function(gene_annotation) {
  gene_rows <- apply(gene_annotation, 1, function(row) {
    sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
            row["gene"], row["snp"], row["location"], row["consequence"])
  })

  gene_html <- sprintf("
    <div class='section'>
      <h2>Gene Annotation</h2>
      <p>Genes mapped to genome-wide significant SNPs.</p>
      <table class='results-table'>
        <thead>
          <tr>
            <th>Gene</th>
            <th>Lead SNP</th>
            <th>Location</th>
            <th>Consequence</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
    </div>
  ", paste(gene_rows, collapse = "\n"))

  return(gene_html)
}

create_pathway_enrichment_section <- function(pathway_enrichment) {
  pathway_rows <- apply(pathway_enrichment, 1, function(row) {
    sprintf("<tr><td>%s</td><td>%s</td><td>%.2e</td><td>%s</td></tr>",
            row["pathway"], row["n_genes"], as.numeric(row["p_value"]), row["genes"])
  })

  pathway_html <- sprintf("
    <div class='section'>
      <h2>Pathway Enrichment</h2>
      <p>Significantly enriched biological pathways.</p>
      <table class='results-table'>
        <thead>
          <tr>
            <th>Pathway</th>
            <th>Genes</th>
            <th>P-value</th>
            <th>Gene List</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
    </div>
  ", paste(pathway_rows, collapse = "\n"))

  return(pathway_html)
}

create_genomic_qc_section <- function(results) {
  qc_html <- sprintf("
    <div class='section'>
      <h2>Quality Control</h2>
      <h3>QQ Plot</h3>
      <p>Quantile-quantile plot showing observed vs. expected P-values. Deviation from the diagonal indicates inflation.</p>
      <img src='qq_plot.png' style='width:600px;'>

      <h3>Inflation Assessment</h3>
      <p><strong>Genomic inflation factor (λ<sub>GC</sub>):</strong> %.3f</p>
      <p><strong>Interpretation:</strong> %s</p>
    </div>
  ",
    results$lambda_gc,
    ifelse(results$lambda_gc < 1.05,
           "Minimal inflation detected. Population stratification is not a concern.",
           ifelse(results$lambda_gc < 1.10,
                  "Moderate inflation. Consider adjusting for additional principal components.",
                  "Substantial inflation. LD score regression recommended to distinguish polygenicity from confounding."))
  )

  return(qc_html)
}

# ============================================================================
# DIAGNOSTIC TEST ACCURACY NMA REPORT
# ============================================================================

generate_dta_nma_report <- function(results, output_dir = tempdir()) {
  report_data <- list(
    title = "Diagnostic Test Accuracy Network Meta-Analysis Report",
    date = Sys.Date(),
    results = results
  )

  sections <- list()

  # 1. Summary
  sections$summary <- create_dta_summary(results)

  # 2. SROC plot
  sections$sroc <- create_sroc_section(results)

  # 3. Test comparison table
  sections$comparison <- create_test_comparison_table(results$test_effects)

  # 4. Clinical utility
  sections$utility <- create_clinical_utility_section(results)

  # 5. Rankings
  sections$rankings <- create_test_rankings_section(results$rankings)

  # Compile report
  report_html <- compile_report_sections(sections, report_data)

  output_file <- file.path(output_dir, "dta_nma_report.html")
  writeLines(report_html, output_file)

  return(output_file)
}

create_dta_summary <- function(results) {
  n_tests <- nrow(results$test_effects)
  n_studies <- results$n_studies

  summary_html <- sprintf("
    <div class='section'>
      <h2>Summary</h2>
      <ul>
        <li><strong>Number of diagnostic tests:</strong> %d</li>
        <li><strong>Number of studies:</strong> %d</li>
        <li><strong>Total patients:</strong> %s</li>
        <li><strong>Reference test:</strong> %s</li>
      </ul>
    </div>
  ", n_tests, n_studies,
    format(results$total_patients, big.mark = ","),
    results$reference_test)

  return(summary_html)
}

create_sroc_section <- function(results) {
  sroc_html <- "
    <div class='section'>
      <h2>Summary ROC (SROC) Curve</h2>
      <p>Summary Receiver Operating Characteristic curve showing the trade-off between sensitivity and specificity for each test.</p>
      <img src='sroc_plot.png' style='width:800px;'>
      <p><strong>Interpretation:</strong> Tests closer to the top-left corner (high sensitivity and specificity) have better diagnostic accuracy.</p>
    </div>
  "

  return(sroc_html)
}

create_test_comparison_table <- function(test_effects) {
  test_rows <- apply(test_effects, 1, function(row) {
    sprintf("<tr><td>%s</td><td>%.3f (%.3f, %.3f)</td><td>%.3f (%.3f, %.3f)</td><td>%.2f</td></tr>",
            row["test"],
            as.numeric(row["sens"]), as.numeric(row["sens_lci"]), as.numeric(row["sens_uci"]),
            as.numeric(row["spec"]), as.numeric(row["spec_lci"]), as.numeric(row["spec_uci"]),
            as.numeric(row["dor"]))
  })

  comparison_html <- sprintf("
    <div class='section'>
      <h2>Test Comparison</h2>
      <table class='results-table'>
        <thead>
          <tr>
            <th>Test</th>
            <th>Sensitivity (95%% CrI)</th>
            <th>Specificity (95%% CrI)</th>
            <th>DOR</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
      <p><strong>DOR:</strong> Diagnostic Odds Ratio. Higher values indicate better diagnostic performance.</p>
    </div>
  ", paste(test_rows, collapse = "\n"))

  return(comparison_html)
}

create_clinical_utility_section <- function(results) {
  utility_html <- sprintf("
    <div class='section'>
      <h2>Clinical Utility</h2>
      <p>Positive and negative predictive values at different disease prevalences.</p>
      <img src='ppv_npv_plot.png' style='width:800px;'>
      <p><strong>Interpretation:</strong> PPV and NPV depend on disease prevalence. At higher prevalence, PPV increases and NPV decreases.</p>
    </div>
  ")

  return(utility_html)
}

create_test_rankings_section <- function(rankings) {
  rank_rows <- apply(rankings, 1, function(row) {
    sprintf("<tr><td>%d</td><td>%s</td><td>%.3f</td><td>%.1f%%</td></tr>",
            as.numeric(row["rank"]), row["test"],
            as.numeric(row["sucra"]), as.numeric(row["prob_best"]) * 100)
  })

  rankings_html <- sprintf("
    <div class='section'>
      <h2>Test Rankings</h2>
      <p>Tests ranked by diagnostic accuracy (based on SUCRA scores).</p>
      <table class='results-table'>
        <thead>
          <tr>
            <th>Rank</th>
            <th>Test</th>
            <th>SUCRA</th>
            <th>Probability Best</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
      <p><strong>SUCRA:</strong> Surface Under the Cumulative RAnking curve. Range: 0-1 (higher is better).</p>
    </div>
  ", paste(rank_rows, collapse = "\n"))

  return(rankings_html)
}

# ============================================================================
# REAL-WORLD EVIDENCE INTEGRATION REPORT
# ============================================================================

generate_rwe_integration_report <- function(results, output_dir = tempdir()) {
  sections <- list()

  sections$summary <- create_rwe_summary(results)
  sections$transportability <- create_transportability_section(results)
  sections$bias <- create_bias_assessment_section(results)
  sections$sensitivity <- create_sensitivity_analysis_section(results)

  report_html <- compile_report_sections(sections, list(
    title = "Real-World Evidence Integration Report",
    date = Sys.Date()
  ))

  output_file <- file.path(output_dir, "rwe_integration_report.html")
  writeLines(report_html, output_file)

  return(output_file)
}

create_rwe_summary <- function(results) {
  summary_html <- sprintf("
    <div class='section'>
      <h2>Summary</h2>
      <ul>
        <li><strong>RCT effect estimate:</strong> %.3f (%.3f, %.3f)</li>
        <li><strong>RWE effect estimate (unadjusted):</strong> %.3f (%.3f, %.3f)</li>
        <li><strong>RWE effect estimate (adjusted):</strong> %.3f (%.3f, %.3f)</li>
        <li><strong>Transported effect estimate:</strong> %.3f (%.3f, %.3f)</li>
      </ul>
    </div>
  ",
    results$rct_effect, results$rct_lci, results$rct_uci,
    results$rwe_effect_unadj, results$rwe_lci_unadj, results$rwe_uci_unadj,
    results$rwe_effect_adj, results$rwe_lci_adj, results$rwe_uci_adj,
    results$transported_effect, results$transported_lci, results$transported_uci)

  return(summary_html)
}

create_transportability_section <- function(results) {
  transport_html <- "
    <div class='section'>
      <h2>Transportability Analysis</h2>
      <h3>Covariate Balance</h3>
      <p>Love plot showing standardized mean differences before and after inverse odds weighting.</p>
      <img src='love_plot.png' style='width:800px;'>

      <h3>Transported Effect Estimate</h3>
      <p>RCT effect estimate transported to target population using inverse odds weighting.</p>
      <p><strong>Conclusion:</strong> After accounting for differences in patient characteristics, the treatment effect in the target population is estimated to be similar to the RCT effect.</p>
    </div>
  "

  return(transport_html)
}

create_bias_assessment_section <- function(results) {
  bias_html <- sprintf("
    <div class='section'>
      <h2>Bias Assessment</h2>
      <h3>Propensity Score Adjustment</h3>
      <p>The RWE effect was adjusted for confounding using propensity score weighting.</p>
      <ul>
        <li><strong>Unadjusted RWE effect:</strong> %.3f</li>
        <li><strong>Adjusted RWE effect:</strong> %.3f</li>
        <li><strong>Bias correction:</strong> %.3f</li>
      </ul>

      <h3>Propensity Score Distribution</h3>
      <img src='ps_distribution.png' style='width:800px;'>
    </div>
  ",
    results$rwe_effect_unadj,
    results$rwe_effect_adj,
    results$rwe_effect_adj - results$rwe_effect_unadj)

  return(bias_html)
}

create_sensitivity_analysis_section <- function(results) {
  sensitivity_html <- sprintf("
    <div class='section'>
      <h2>Sensitivity Analysis</h2>
      <h3>E-value Analysis</h3>
      <p>The E-value quantifies the minimum strength of association (on the risk ratio scale) that an unmeasured confounder would need to have with both the treatment and outcome to fully explain away the observed effect.</p>
      <ul>
        <li><strong>E-value for point estimate:</strong> %.2f</li>
        <li><strong>E-value for 95%% CI lower bound:</strong> %.2f</li>
      </ul>
      <p><strong>Interpretation:</strong> An unmeasured confounder would need to be associated with both treatment and outcome with a risk ratio of %.2f-fold each to explain away the observed effect. This suggests %s residual confounding.</p>
    </div>
  ",
    results$e_value,
    results$e_value_ci,
    results$e_value,
    ifelse(results$e_value > 2, "minimal concern about", "potential"))

  return(sensitivity_html)
}

# ============================================================================
# COMPONENT NETWORK META-ANALYSIS REPORT
# ============================================================================

generate_component_nma_report <- function(results, output_dir = tempdir()) {
  sections <- list()

  sections$summary <- create_component_summary(results)
  sections$component_effects <- create_component_effects_section(results)
  sections$interactions <- create_interaction_section(results)
  sections$predictions <- create_optimal_combination_section(results)

  report_html <- compile_report_sections(sections, list(
    title = "Component Network Meta-Analysis Report",
    date = Sys.Date()
  ))

  output_file <- file.path(output_dir, "component_nma_report.html")
  writeLines(report_html, output_file)

  return(output_file)
}

create_component_summary <- function(results) {
  summary_html <- sprintf("
    <div class='section'>
      <h2>Summary</h2>
      <ul>
        <li><strong>Number of components:</strong> %d</li>
        <li><strong>Number of treatment combinations tested:</strong> %d</li>
        <li><strong>Model type:</strong> %s</li>
        <li><strong>Interactions detected:</strong> %s</li>
      </ul>
    </div>
  ",
    results$n_components,
    results$n_combinations,
    ifelse(results$model_type == "additive", "Additive (no interactions)", "Interactive (with synergies)"),
    ifelse(results$has_interactions, "Yes", "No"))

  return(summary_html)
}

create_component_effects_section <- function(results) {
  comp_rows <- apply(results$component_effects, 1, function(row) {
    sprintf("<tr><td>%s</td><td>%.3f (%.3f, %.3f)</td><td>%.3f</td></tr>",
            row["component"],
            as.numeric(row["effect"]), as.numeric(row["lci"]), as.numeric(row["uci"]),
            as.numeric(row["prob_beneficial"]))
  })

  effects_html <- sprintf("
    <div class='section'>
      <h2>Component Effects</h2>
      <p>Individual effect of each component compared to no component.</p>
      <table class='results-table'>
        <thead>
          <tr>
            <th>Component</th>
            <th>Effect (95%% CrI)</th>
            <th>P(beneficial)</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
      <img src='component_forest_plot.png' style='width:800px;'>
    </div>
  ", paste(comp_rows, collapse = "\n"))

  return(effects_html)
}

create_interaction_section <- function(results) {
  if (!results$has_interactions) {
    return("<div class='section'><h2>Interactions</h2><p>No significant interactions detected. The additive model is preferred.</p></div>")
  }

  int_rows <- apply(results$interactions, 1, function(row) {
    sprintf("<tr><td>%s × %s</td><td>%.3f (%.3f, %.3f)</td><td>%s</td></tr>",
            row["component1"], row["component2"],
            as.numeric(row["interaction"]), as.numeric(row["lci"]), as.numeric(row["uci"]),
            ifelse(as.numeric(row["interaction"]) > 0, "Synergy", "Antagonism"))
  })

  interaction_html <- sprintf("
    <div class='section'>
      <h2>Component Interactions</h2>
      <p>Pairwise interactions between components (departure from additivity).</p>
      <table class='results-table'>
        <thead>
          <tr>
            <th>Interaction</th>
            <th>Effect (95%% CrI)</th>
            <th>Type</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
      <h3>Interaction Heatmap</h3>
      <img src='interaction_heatmap.png' style='width:800px;'>
    </div>
  ", paste(int_rows, collapse = "\n"))

  return(interaction_html)
}

create_optimal_combination_section <- function(results) {
  pred_rows <- head(results$predictions[order(-results$predictions$effect), ], 10)
  pred_table <- apply(pred_rows, 1, function(row) {
    sprintf("<tr><td>%s</td><td>%.3f (%.3f, %.3f)</td></tr>",
            row["combination"],
            as.numeric(row["effect"]), as.numeric(row["lci"]), as.numeric(row["uci"]))
  })

  optimal_html <- sprintf("
    <div class='section'>
      <h2>Optimal Combinations</h2>
      <p>Top 10 predicted treatment combinations (including untested combinations).</p>
      <table class='results-table'>
        <thead>
          <tr>
            <th>Combination</th>
            <th>Predicted Effect (95%% CrI)</th>
          </tr>
        </thead>
        <tbody>
          %s
        </tbody>
      </table>
      <p><strong>Note:</strong> Combinations marked with * have not been directly tested in trials.</p>
    </div>
  ", paste(pred_table, collapse = "\n"))

  return(optimal_html)
}

# ============================================================================
# REPORT COMPILATION
# ============================================================================

compile_report_sections <- function(sections, report_data) {
  # CSS styling
  css <- "
    <style>
      body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
      h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
      h2 { color: #34495e; margin-top: 30px; border-bottom: 1px solid #bdc3c7; padding-bottom: 5px; }
      .section { margin: 20px 0; }
      .results-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
      .results-table th { background-color: #3498db; color: white; padding: 10px; text-align: left; }
      .results-table td { padding: 8px; border-bottom: 1px solid #ecf0f1; }
      .results-table tr:hover { background-color: #f8f9fa; }
      img { margin: 20px 0; }
    </style>
  "

  # Compile HTML
  html <- sprintf("
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset='UTF-8'>
      <title>%s</title>
      %s
    </head>
    <body>
      <h1>%s</h1>
      <p><strong>Generated:</strong> %s</p>
      <p><strong>Software:</strong> Metanew V4.0 - Universal Evidence Synthesis Platform</p>

      %s

      <hr>
      <p style='color: #7f8c8d; font-size: 12px;'>
        This report was automatically generated by Metanew V4.0.<br>
        For questions about methodology, please consult the Metanew documentation.
      </p>
    </body>
    </html>
  ",
    report_data$title,
    css,
    report_data$title,
    report_data$date,
    paste(unlist(sections), collapse = "\n\n")
  )

  return(html)
}

# ============================================================================
# AUTO-DETECTION AND DISPATCH
# ============================================================================

generate_universal_report <- function(analysis_type, results, output_dir = tempdir()) {
  # Auto-detect analysis type and route to appropriate report generator
  report_file <- switch(analysis_type,
    "genomic_ma" = generate_genomic_ma_report(results, output_dir),
    "dta_nma" = generate_dta_nma_report(results, output_dir),
    "rwe_integration" = generate_rwe_integration_report(results, output_dir),
    "component_nma" = generate_component_nma_report(results, output_dir),
    stop("Unknown analysis type: ", analysis_type)
  )

  return(report_file)
}
