# =============================================================================
# Enhanced Protocol Generation Module
# =============================================================================
# Adds additional controls to protocol generation:
# - PROSPERO compliance mode
# - Controllable section lengths (brief/standard/detailed)
# - Multiple export formats
#
# Author: Metanew Development Team
# Date: 2025-11-04
# Version: 4.6.0
# =============================================================================

library(shiny)
library(bslib)

# Source base protocol rule engine
source("modules/protocol_rule_engine.R", local = TRUE)

# =============================================================================
# Section Length Configuration
# =============================================================================

SECTION_LENGTH_CONFIG <- list(
  brief = list(
    search_strategy = list(max_paragraphs = 2, max_databases = 5, detail_level = "minimal"),
    eligibility = list(max_items = 3, inclusion_detail = "brief", exclusion_detail = "brief"),
    rob_assessment = list(max_paragraphs = 2, domains_detail = "list"),
    data_extraction = list(max_paragraphs = 2, variables_detail = "summary"),
    statistical_methods = list(max_paragraphs = 3, technical_detail = "minimal")
  ),
  standard = list(
    search_strategy = list(max_paragraphs = 4, max_databases = 8, detail_level = "standard"),
    eligibility = list(max_items = 5, inclusion_detail = "standard", exclusion_detail = "standard"),
    rob_assessment = list(max_paragraphs = 4, domains_detail = "detailed"),
    data_extraction = list(max_paragraphs = 4, variables_detail = "detailed"),
    statistical_methods = list(max_paragraphs = 6, technical_detail = "standard")
  ),
  detailed = list(
    search_strategy = list(max_paragraphs = 8, max_databases = 12, detail_level = "exhaustive"),
    eligibility = list(max_items = 10, inclusion_detail = "exhaustive", exclusion_detail = "exhaustive"),
    rob_assessment = list(max_paragraphs = 8, domains_detail = "exhaustive"),
    data_extraction = list(max_paragraphs = 8, variables_detail = "exhaustive"),
    statistical_methods = list(max_paragraphs = 12, technical_detail = "exhaustive")
  )
)

# =============================================================================
# PROSPERO Compliance Checker
# =============================================================================

#' Check if protocol meets PROSPERO requirements
#'
#' @param protocol_content Generated protocol content
#' @return List with compliance status and missing elements
#' @export
check_prospero_compliance <- function(protocol_content) {

  # Required PROSPERO sections
  required_sections <- c(
    "Review question",
    "Searches",
    "Types of study to be included",
    "Condition or domain being studied",
    "Participants/population",
    "Intervention(s), exposure(s)",
    "Comparator(s)/control",
    "Outcome(s)",
    "Data extraction",
    "Risk of bias assessment",
    "Strategy for data synthesis"
  )

  # Check presence of each section
  missing_sections <- character()
  present_sections <- character()

  for (section in required_sections) {
    # Check if section title or content exists
    section_pattern <- tolower(gsub(" ", ".*", section))
    if (!grepl(section_pattern, tolower(protocol_content))) {
      missing_sections <- c(missing_sections, section)
    } else {
      present_sections <- c(present_sections, section)
    }
  }

  compliance_score <- length(present_sections) / length(required_sections) * 100

  return(list(
    compliant = length(missing_sections) == 0,
    compliance_score = compliance_score,
    present_sections = present_sections,
    missing_sections = missing_sections,
    recommendation = if (compliance_score >= 100) {
      "✓ Fully compliant with PROSPERO requirements"
    } else if (compliance_score >= 80) {
      "⚠ Mostly compliant. Add missing sections for full compliance"
    } else {
      "✗ Not compliant. Multiple required sections missing"
    }
  ))
}

#' Generate PROSPERO-compliant protocol
#'
#' @param params Protocol parameters
#' @param length_mode Section length mode ("brief", "standard", "detailed")
#' @param enforce_prospero Whether to enforce PROSPERO compliance
#' @return Protocol content with PROSPERO formatting
#' @export
generate_prospero_protocol <- function(params, length_mode = "standard", enforce_prospero = TRUE) {

  # Get length configuration
  length_config <- SECTION_LENGTH_CONFIG[[length_mode]]

  # Add length configuration to params
  params$length_config <- length_config
  params$enforce_prospero <- enforce_prospero

  # Generate protocol using base engine
  protocol <- generate_protocol(params)

  # If PROSPERO enforcement enabled, add required sections if missing
  if (enforce_prospero) {
    protocol <- ensure_prospero_sections(protocol, params)
  }

  # Check compliance
  compliance <- check_prospero_compliance(protocol)

  # Add compliance report
  protocol <- paste0(
    protocol,
    "\n\n",
    "<!-- PROSPERO COMPLIANCE REPORT\n",
    sprintf("Compliance Score: %.1f%%\n", compliance$compliance_score),
    sprintf("Status: %s\n", compliance$recommendation),
    sprintf("Present Sections: %d/%d\n", length(compliance$present_sections),
            length(compliance$present_sections) + length(compliance$missing_sections)),
    if (length(compliance$missing_sections) > 0) {
      paste0("Missing Sections: ", paste(compliance$missing_sections, collapse = ", "), "\n")
    } else {
      ""
    },
    "-->\n"
  )

  return(list(
    content = protocol,
    compliance = compliance,
    length_mode = length_mode
  ))
}

#' Ensure all PROSPERO required sections are present
#'
#' @param protocol Existing protocol content
#' @param params Protocol parameters
#' @return Protocol with all required sections
#' @export
ensure_prospero_sections <- function(protocol, params) {

  sections_to_add <- list()

  # Check for Review Question
  if (!grepl("review question|research question", tolower(protocol))) {
    sections_to_add$review_question <- sprintf(
      "## Review Question\n\n%s\n\n",
      params$research_question %||% "What is the effect of [intervention] on [outcome] in [population]?"
    )
  }

  # Check for PICO explicitly
  if (!grepl("participants|population", tolower(protocol))) {
    sections_to_add$population <- sprintf(
      "## Participants/Population\n\n%s\n\n",
      params$population %||% "Not specified"
    )
  }

  # Check for intervention
  if (!grepl("intervention|exposure", tolower(protocol))) {
    sections_to_add$intervention <- sprintf(
      "## Intervention(s)\n\n%s\n\n",
      params$intervention %||% "Not specified"
    )
  }

  # Check for comparator
  if (!grepl("comparator|control|comparison", tolower(protocol))) {
    sections_to_add$comparator <- sprintf(
      "## Comparator(s)/Control\n\n%s\n\n",
      params$comparator %||% "Not specified"
    )
  }

  # Check for outcomes
  if (!grepl("outcome", tolower(protocol))) {
    sections_to_add$outcomes <- sprintf(
      "## Outcome(s)\n\n**Primary:** %s\n\n**Secondary:** %s\n\n",
      params$primary_outcome %||% "Not specified",
      params$secondary_outcomes %||% "Not specified"
    )
  }

  # Add missing sections at the beginning
  if (length(sections_to_add) > 0) {
    additional_content <- paste(unlist(sections_to_add), collapse = "\n")
    protocol <- paste0("# PROSPERO-Compliant Systematic Review Protocol\n\n",
                      additional_content,
                      "\n---\n\n",
                      protocol)
  }

  return(protocol)
}

# =============================================================================
# Results Section Length Control
# =============================================================================

#' Generate results section with controllable length
#'
#' @param results Meta-analysis results object
#' @param length_mode Length mode ("brief", "standard", "detailed")
#' @param include_grade Whether to include GRADE assessment
#' @return Formatted results section
#' @export
generate_results_section <- function(results, length_mode = "standard", include_grade = TRUE) {

  length_config <- SECTION_LENGTH_CONFIG[[length_mode]]$statistical_methods

  output <- "## Results\n\n"

  # Study Selection (length-controlled)
  if (length_mode == "brief") {
    output <- paste0(output, sprintf(
      "We identified %d studies (%d participants) meeting eligibility criteria.\n\n",
      results$n_studies, results$n_participants
    ))
  } else if (length_mode == "standard") {
    output <- paste0(output, sprintf(
      "### Study Selection\n\nOur systematic search identified %d studies enrolling %d participants. Studies were published between %s and %s. The majority of studies (%d%%) were randomized controlled trials.\n\n",
      results$n_studies,
      results$n_participants,
      results$year_range[1],
      results$year_range[2],
      results$pct_rct
    ))
  } else {  # detailed
    output <- paste0(output, sprintf(
      "### Study Selection and Characteristics\n\nOur comprehensive systematic search across %d databases identified %d potentially relevant records. After removing %d duplicates and screening %d records, %d full-text articles were assessed for eligibility. Ultimately, %d studies enrolling %d participants met our inclusion criteria and were included in the quantitative synthesis.\n\nIncluded studies were published between %s and %s, with a median publication year of %s. The majority of studies (%d%%) were randomized controlled trials, with %d%% being open-label and %d%% double-blind designs. Studies were conducted across %d countries, with the largest proportions from %s.\n\n",
      results$n_databases,
      results$n_records_identified,
      results$n_duplicates,
      results$n_screened,
      results$n_full_text,
      results$n_studies,
      results$n_participants,
      results$year_range[1],
      results$year_range[2],
      results$median_year,
      results$pct_rct,
      results$pct_open_label,
      results$pct_double_blind,
      results$n_countries,
      results$top_countries
    ))
  }

  # Main Findings (length-controlled)
  if (length_mode == "brief") {
    output <- paste0(output, sprintf(
      "**Primary Outcome:** %s showed %s (95%% CI: %s to %s; p=%s; I²=%s%%).\n\n",
      results$primary_outcome,
      results$effect_direction,
      round(results$ci_lower, 2),
      round(results$ci_upper, 2),
      format.pval(results$p_value, digits = 3),
      round(results$i_squared, 0)
    ))
  } else if (length_mode == "standard") {
    output <- paste0(output, sprintf(
      "### Primary Outcome: %s\n\nMeta-analysis of %d studies showed %s. The pooled %s was %s (95%% CI: %s to %s; p=%s). Between-study heterogeneity was %s (I²=%s%%, τ²=%s).\n\n",
      results$primary_outcome,
      results$n_studies_primary,
      results$effect_direction,
      results$effect_measure,
      round(results$pooled_effect, 2),
      round(results$ci_lower, 2),
      round(results$ci_upper, 2),
      format.pval(results$p_value, digits = 3),
      results$heterogeneity_interpretation,
      round(results$i_squared, 0),
      round(results$tau_squared, 3)
    ))
  } else {  # detailed
    output <- paste0(output, sprintf(
      "### Primary Outcome: %s\n\n#### Overall Effect\n\nMeta-analysis of %d studies (%d participants) demonstrated %s. Using a %s model, the pooled %s was %s (95%% CI: %s to %s; p=%s), indicating %s.\n\n#### Heterogeneity Assessment\n\nBetween-study heterogeneity was %s (I²=%s%%, τ²=%s, prediction interval: %s to %s). The I² statistic suggests that %s%% of the total variability is attributable to heterogeneity rather than sampling error.\n\n#### Sensitivity Analyses\n\nLeave-one-out sensitivity analysis showed %s. Restricting to studies at low risk of bias (%d studies) yielded a similar effect (%s, 95%% CI: %s to %s).\n\n",
      results$primary_outcome,
      results$n_studies_primary,
      results$n_participants_primary,
      results$effect_direction,
      results$model_type,
      results$effect_measure,
      round(results$pooled_effect, 2),
      round(results$ci_lower, 2),
      round(results$ci_upper, 2),
      format.pval(results$p_value, digits = 3),
      results$clinical_interpretation,
      results$heterogeneity_interpretation,
      round(results$i_squared, 0),
      round(results$tau_squared, 3),
      round(results$pi_lower, 2),
      round(results$pi_upper, 2),
      round(results$i_squared, 0),
      results$sensitivity_interpretation,
      results$n_low_rob,
      round(results$low_rob_effect, 2),
      round(results$low_rob_ci_lower, 2),
      round(results$low_rob_ci_upper, 2)
    ))
  }

  # GRADE assessment (if included)
  if (include_grade && !is.null(results$grade)) {
    if (length_mode == "brief") {
      output <- paste0(output, sprintf(
        "**Certainty of Evidence:** %s (%s)\n\n",
        results$grade$certainty,
        results$grade$summary
      ))
    } else {
      output <- paste0(output,
        "### Certainty of Evidence (GRADE)\n\n",
        sprintf("Overall certainty: **%s**\n\n", results$grade$certainty),
        "**Reasons for downgrading:**\n",
        paste0("- ", results$grade$downgrade_reasons, collapse = "\n"),
        "\n\n"
      )
    }
  }

  return(output)
}

# =============================================================================
# Methods Section Length Control
# =============================================================================

#' Generate methods section with controllable length
#'
#' @param methods_params Methods parameters
#' @param length_mode Length mode ("brief", "standard", "detailed")
#' @return Formatted methods section
#' @export
generate_methods_section <- function(methods_params, length_mode = "standard") {

  length_config <- SECTION_LENGTH_CONFIG[[length_mode]]$statistical_methods

  output <- "## Methods\n\n"

  # Search Strategy
  if (length_mode == "brief") {
    output <- paste0(output, sprintf(
      "### Search Strategy\n\nWe searched %s through %s.\n\n",
      paste(head(methods_params$databases, 3), collapse = ", "),
      format(Sys.Date(), "%B %Y")
    ))
  } else if (length_mode == "standard") {
    output <- paste0(output, sprintf(
      "### Search Strategy\n\nWe conducted a comprehensive search of %s from inception through %s. The search strategy combined MeSH terms and keywords for population, intervention, comparator, and outcomes. We also searched trial registries and contacted experts to identify unpublished studies.\n\n",
      paste(methods_params$databases, collapse = ", "),
      format(Sys.Date(), "%B %Y")
    ))
  } else {  # detailed
    output <- paste0(output, sprintf(
      "### Search Strategy\n\n#### Electronic Databases\n\nWe systematically searched the following electronic databases from inception through %s: %s. No date or language restrictions were applied. The full search strategy for each database is provided in Supplementary Appendix 1.\n\n#### Search Terms\n\nOur search strategy combined Medical Subject Headings (MeSH) terms and free-text keywords organized around the PICO framework:\n- **Population:** %s\n- **Intervention:** %s\n- **Comparator:** %s\n- **Outcomes:** %s\n\nTerms were combined using Boolean operators (AND, OR) and proximity operators (NEAR, ADJ) as appropriate for each database.\n\n#### Additional Sources\n\nWe searched trial registries (%s), conference proceedings from major relevant conferences (%s), and contacted international experts in the field to identify ongoing or unpublished studies. Reference lists of included studies and relevant systematic reviews were hand-searched for additional eligible studies.\n\n",
      format(Sys.Date(), "%B %d, %Y"),
      paste(methods_params$databases, collapse = ", "),
      methods_params$population_terms,
      methods_params$intervention_terms,
      methods_params$comparator_terms,
      methods_params$outcome_terms,
      paste(methods_params$registries, collapse = ", "),
      paste(methods_params$conferences, collapse = ", ")
    ))
  }

  # Statistical Analysis
  if (length_mode == "brief") {
    output <- paste0(output, sprintf(
      "### Statistical Analysis\n\nWe performed %s meta-analysis using %s. Heterogeneity was assessed using I².\n\n",
      methods_params$model_type,
      methods_params$software
    ))
  } else if (length_mode == "standard") {
    output <- paste0(output, sprintf(
      "### Statistical Analysis\n\nWe conducted %s meta-analysis using %s. Effect estimates are presented as %s with 95%% confidence intervals. Between-study heterogeneity was quantified using I² and τ². We explored sources of heterogeneity through subgroup analyses and meta-regression when ≥10 studies were available. Publication bias was assessed using funnel plots and Egger's test.\n\n",
      methods_params$model_type,
      methods_params$software,
      methods_params$effect_measure
    ))
  } else {  # detailed
    output <- paste0(output, sprintf(
      "### Statistical Analysis\n\n#### Meta-Analysis Approach\n\nWe synthesized data using %s meta-analysis with the %s estimator in %s. This approach was selected because %s. Effect estimates are presented as %s with 95%% confidence intervals.\n\n#### Heterogeneity Assessment\n\nBetween-study heterogeneity was quantified using Cochran's Q test, I² statistic, and τ². We calculated 95%% prediction intervals to estimate the range of true effects in similar future studies. I² values of 25%%, 50%%, and 75%% were interpreted as low, moderate, and high heterogeneity, respectively.\n\n#### Subgroup and Sensitivity Analyses\n\nWe conducted pre-specified subgroup analyses by: %s. Meta-regression was performed when ≥10 studies were available to investigate continuous moderators. Sensitivity analyses included: (1) leave-one-out analysis, (2) restriction to studies at low risk of bias, (3) restriction to studies with adequate allocation concealment, and (4) comparison of fixed- vs. random-effects models.\n\n#### Publication Bias\n\nPublication bias was assessed using funnel plots (visual inspection), Egger's regression test (statistical test for asymmetry), and trim-and-fill analysis (estimating effect of missing studies). We planned Copas selection model if substantial asymmetry was detected.\n\n#### Software\n\nAll analyses were conducted in %s version %s using packages: %s. Statistical significance was set at two-sided α=0.05.\n\n",
      methods_params$model_type,
      methods_params$estimator,
      methods_params$software,
      methods_params$model_justification,
      methods_params$effect_measure,
      paste(methods_params$subgroups, collapse = ", "),
      methods_params$software,
      methods_params$software_version,
      paste(methods_params$packages, collapse = ", ")
    ))
  }

  return(output)
}

# Note: Extend with UI components as needed for integration with Shiny app
