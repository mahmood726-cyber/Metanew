# Publication Tools for Systematic Reviews & Meta-Analysis
# Complete toolkit for publication-ready outputs
# PRISMA, RoB, ROBINS-I, GRADE, Demographics Tables, Study Characteristics
#
# Author: EvidenceOS PRIME
# Coverage: All essential components for SR/MA publication

library(dplyr)
library(ggplot2)
library(gt)
library(gridExtra)
library(PRISMAstatement)  # For PRISMA diagrams

# ============================================================================
# PRISMA FLOW DIAGRAM
# ============================================================================

#' Generate PRISMA 2020 flow diagram data
#' @param n_identified Records identified through database searching
#' @param n_other Records identified through other sources
#' @param n_duplicates Duplicate records removed
#' @param n_screened Records screened
#' @param n_excluded_screening Records excluded at screening
#' @param n_full_text Full-text articles assessed
#' @param n_excluded_full_text Full-text articles excluded
#' @param exclusion_reasons List of exclusion reasons with counts
#' @param n_included Studies included in qualitative synthesis
#' @param n_meta_analysis Studies included in quantitative synthesis (meta-analysis)
#' @return PRISMA diagram object
create_prisma_data <- function(n_identified,
                                n_other = 0,
                                n_duplicates,
                                n_screened,
                                n_excluded_screening,
                                n_full_text,
                                n_excluded_full_text,
                                exclusion_reasons = NULL,
                                n_included,
                                n_meta_analysis) {

  list(
    identification = list(
      database_records = n_identified,
      other_sources = n_other,
      total = n_identified + n_other
    ),
    screening = list(
      after_duplicates = n_screened,
      duplicates_removed = n_duplicates,
      excluded_screening = n_excluded_screening,
      full_text_assessed = n_full_text
    ),
    eligibility = list(
      full_text_assessed = n_full_text,
      excluded_full_text = n_excluded_full_text,
      exclusion_reasons = exclusion_reasons
    ),
    included = list(
      qualitative = n_included,
      quantitative = n_meta_analysis
    )
  )
}

#' Generate PRISMA flow diagram plot
#' @param prisma_data PRISMA data from create_prisma_data()
#' @param style "standard", "detailed", "simple"
#' @return ggplot object
generate_prisma_diagram <- function(prisma_data, style = "standard") {

  # Calculate totals
  total_records <- prisma_data$identification$total
  after_duplicates <- prisma_data$screening$after_duplicates
  excluded_screening <- prisma_data$screening$excluded_screening
  full_text <- prisma_data$screening$full_text_assessed
  excluded_full_text <- prisma_data$eligibility$excluded_full_text
  included_qual <- prisma_data$included$qualitative
  included_quant <- prisma_data$included$quantitative

  # Create boxes data
  boxes <- data.frame(
    x = c(2, 4, 2, 4, 2, 4, 2, 2),
    y = c(8, 8, 6.5, 6.5, 5, 5, 3, 1.5),
    label = c(
      sprintf("Records identified through\ndatabase searching\n(n = %d)",
              prisma_data$identification$database_records),
      sprintf("Additional records identified\nthrough other sources\n(n = %d)",
              prisma_data$identification$other_sources),
      sprintf("Records after duplicates removed\n(n = %d)", after_duplicates),
      sprintf("Records excluded\n(n = %d)", excluded_screening),
      sprintf("Full-text articles assessed\nfor eligibility\n(n = %d)", full_text),
      sprintf("Full-text articles excluded\n(n = %d)", excluded_full_text),
      sprintf("Studies included in\nqualitative synthesis\n(n = %d)", included_qual),
      sprintf("Studies included in\nquantitative synthesis\n(meta-analysis)\n(n = %d)",
              included_quant)
    ),
    width = c(1.8, 1.8, 1.8, 1.8, 1.8, 1.8, 1.8, 1.8),
    height = c(1, 1, 1, 1, 1, 1, 0.8, 0.8),
    section = c("Identification", "Identification", "Screening", "Screening",
                "Eligibility", "Eligibility", "Included", "Included")
  )

  # Create plot
  p <- ggplot(boxes) +
    geom_rect(aes(xmin = x - width/2, xmax = x + width/2,
                  ymin = y - height/2, ymax = y + height/2,
                  fill = section),
              color = "black", linewidth = 0.5) +
    geom_text(aes(x = x, y = y, label = label),
              size = 3.5, lineheight = 0.9) +
    scale_fill_manual(values = c(
      "Identification" = "#E8F4F8",
      "Screening" = "#D4E6F1",
      "Eligibility" = "#AED6F1",
      "Included" = "#85C1E2"
    )) +
    # Arrows
    geom_segment(aes(x = 2, y = 7.5, xend = 2, yend = 7),
                 arrow = arrow(length = unit(0.2, "cm"))) +
    geom_segment(aes(x = 4, y = 7.5, xend = 4, yend = 7),
                 arrow = arrow(length = unit(0.2, "cm"))) +
    geom_segment(aes(x = 2, y = 6, xend = 2, yend = 5.5),
                 arrow = arrow(length = unit(0.2, "cm"))) +
    geom_segment(aes(x = 2, y = 4.5, xend = 2, yend = 3.4),
                 arrow = arrow(length = unit(0.2, "cm"))) +
    geom_segment(aes(x = 2, y = 2.6, xend = 2, yend = 1.9),
                 arrow = arrow(length = unit(0.2, "cm"))) +
    # Side arrows for exclusions
    geom_segment(aes(x = 2.9, y = 6.5, xend = 3.1, yend = 6.5),
                 arrow = arrow(length = unit(0.2, "cm"))) +
    geom_segment(aes(x = 2.9, y = 5, xend = 3.1, yend = 5),
                 arrow = arrow(length = unit(0.2, "cm"))) +
    coord_cartesian(xlim = c(0, 6), ylim = c(0, 9)) +
    theme_void() +
    theme(legend.position = "none",
          plot.margin = margin(10, 10, 10, 10))

  return(p)
}

#' Generate PRISMA 2020 checklist
#' @param completed_items Vector of item numbers that are completed (1-27)
#' @return Data frame with checklist
generate_prisma_checklist <- function(completed_items = 1:27) {

  checklist <- data.frame(
    Section = c(
      rep("TITLE", 1),
      rep("ABSTRACT", 1),
      rep("INTRODUCTION", 2),
      rep("METHODS", 14),
      rep("RESULTS", 7),
      rep("DISCUSSION", 2)
    ),
    Item = c(
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
      17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27
    ),
    Topic = c(
      "Title",
      "Abstract",
      "Rationale",
      "Objectives",
      "Eligibility criteria",
      "Information sources",
      "Search strategy",
      "Selection process",
      "Data collection process",
      "Data items",
      "Study risk of bias assessment",
      "Effect measures",
      "Synthesis methods",
      "Reporting bias assessment",
      "Certainty assessment",
      "Study selection",
      "Study characteristics",
      "Risk of bias in studies",
      "Results of individual studies",
      "Results of syntheses",
      "Reporting biases",
      "Certainty of evidence",
      "Discussion",
      "Limitations",
      "Funding",
      "Registration",
      "Protocol"
    ),
    Description = c(
      "Identify the report as a systematic review",
      "Provide a structured summary including background, objectives, methods, results, conclusions",
      "Describe the rationale for the review in the context of existing knowledge",
      "Provide an explicit statement of all objectives or questions the review addresses",
      "Specify inclusion and exclusion criteria for the review",
      "Specify all databases, registers, websites, organisations, etc. searched",
      "Present full search strategies for all databases and registers",
      "Specify the methods used to decide whether a study met inclusion criteria",
      "Specify methods used to collect data from reports, including how many reviewers collected data",
      "List and define all outcomes for which data were sought",
      "Specify the methods used to assess risk of bias in the included studies",
      "Specify for each outcome the effect measure(s) used",
      "Describe the processes used to decide which studies were eligible for each synthesis",
      "Describe any methods used to assess risk of bias due to missing results",
      "Describe methods used to assess certainty (or confidence) in the body of evidence",
      "Describe results of the search and selection process",
      "Cite each included study and present its characteristics",
      "Present assessments of risk of bias for each included study",
      "For all outcomes, present for each study: summary statistics, effect estimates and confidence intervals",
      "Present results of all statistical syntheses conducted",
      "Present assessments of risk of bias due to missing results",
      "Present assessments of certainty in the body of evidence",
      "Provide a general interpretation of the results in context of other evidence",
      "Discuss limitations at study and outcome level, and at review level",
      "Specify funding sources and other support for the review",
      "Provide registration information for the review",
      "Indicate if a review protocol exists and where it can be accessed"
    ),
    Completed = c(
      ifelse(1:27 %in% completed_items, "✓", "")
    ),
    Page = rep("", 27)  # User fills this in
  )

  return(checklist)
}

# ============================================================================
# STUDY CHARACTERISTICS TABLES
# ============================================================================

#' Generate study characteristics table
#' @param data Data frame with study information
#' @param style "standard", "nejm", "lancet", "bmj"
#' @param include_cols Columns to include
#' @return gt table object
generate_study_characteristics_table <- function(data,
                                                  style = "standard",
                                                  include_cols = c("author", "year", "country",
                                                                  "design", "n", "intervention",
                                                                  "control", "outcome")) {

  # Select and format columns
  if ("author" %in% names(data) && "year" %in% names(data)) {
    data$study <- paste0(data$author, " (", data$year, ")")
  } else if ("study_id" %in% names(data)) {
    data$study <- data$study_id
  }

  # Create base table
  table_data <- data %>%
    select(any_of(c("study", include_cols)))

  # Create gt table
  tbl <- gt(table_data) %>%
    tab_header(
      title = "Characteristics of Included Studies"
    )

  # Apply journal-specific styling
  if (style == "nejm") {
    tbl <- tbl %>%
      tab_options(
        table.font.names = "Arial",
        table.font.size = px(9),
        heading.background.color = "white",
        column_labels.background.color = "white",
        column_labels.border.top.style = "solid",
        column_labels.border.top.width = px(2),
        column_labels.border.bottom.style = "solid",
        column_labels.border.bottom.width = px(1),
        table_body.border.bottom.style = "solid",
        table_body.border.bottom.width = px(2)
      ) %>%
      tab_style(
        style = cell_text(weight = "bold"),
        locations = cells_column_labels()
      )
  } else if (style == "lancet") {
    tbl <- tbl %>%
      tab_options(
        table.font.names = "Arial",
        table.font.size = px(9),
        heading.background.color = "#DC143C",
        heading.title.font.size = px(12),
        heading.title.font.weight = "bold",
        column_labels.background.color = "#F0F0F0"
      )
  } else if (style == "bmj") {
    tbl <- tbl %>%
      tab_options(
        table.font.names = "Arial",
        table.font.size = px(10),
        table.border.top.style = "solid",
        table.border.top.width = px(3),
        table.border.top.color = "#0066CC",
        column_labels.border.bottom.style = "solid",
        column_labels.border.bottom.width = px(2)
      )
  }

  return(tbl)
}

#' Generate population demographics table
#' @param data Data frame with demographic information
#' @param style Journal style
#' @param stratify_by Optional grouping variable
#' @return gt table object
generate_demographics_table <- function(data,
                                         style = "nejm",
                                         stratify_by = NULL) {

  # Calculate summary statistics
  demographics <- data.frame(
    Characteristic = character(),
    Overall = character(),
    stringsAsFactors = FALSE
  )

  # Age
  if ("age_mean" %in% names(data) && "age_sd" %in% names(data)) {
    demographics <- rbind(demographics, data.frame(
      Characteristic = "Age, years",
      Overall = sprintf("%.1f (%.1f)",
                       weighted.mean(data$age_mean, data$n, na.rm = TRUE),
                       sqrt(weighted.mean(data$age_sd^2, data$n, na.rm = TRUE)))
    ))
  }

  # Sex
  if ("female_pct" %in% names(data)) {
    demographics <- rbind(demographics, data.frame(
      Characteristic = "Female, %",
      Overall = sprintf("%.1f",
                       weighted.mean(data$female_pct, data$n, na.rm = TRUE))
    ))
  }

  # Sample size
  demographics <- rbind(demographics, data.frame(
    Characteristic = "Total sample size",
    Overall = as.character(sum(data$n, na.rm = TRUE))
  ))

  # Number of studies
  demographics <- rbind(demographics, data.frame(
    Characteristic = "Number of studies",
    Overall = as.character(nrow(data))
  ))

  # Create gt table
  tbl <- gt(demographics) %>%
    tab_header(
      title = "Population Characteristics",
      subtitle = "Values are mean (SD) or %"
    )

  # Apply journal styling
  if (style == "nejm") {
    tbl <- tbl %>%
      tab_options(
        table.font.names = "Arial",
        table.font.size = px(9),
        column_labels.border.top.width = px(2),
        column_labels.border.bottom.width = px(1),
        table_body.border.bottom.width = px(2)
      ) %>%
      tab_style(
        style = cell_text(weight = "bold"),
        locations = cells_column_labels()
      )
  }

  return(tbl)
}

# ============================================================================
# RISK OF BIAS (RoB 2.0) CHARTS
# ============================================================================

#' Create Risk of Bias 2.0 assessment data
#' @param studies Vector of study IDs
#' @param randomization Risk of bias ratings for randomization domain
#' @param deviations Risk of bias ratings for deviations from intended interventions
#' @param missing_outcome Risk of bias ratings for missing outcome data
#' @param outcome_measurement Risk of bias ratings for measurement of the outcome
#' @param selection_reported Risk of bias ratings for selection of reported result
#' @return Data frame with RoB assessments
create_rob2_data <- function(studies,
                              randomization,
                              deviations,
                              missing_outcome,
                              outcome_measurement,
                              selection_reported) {

  data.frame(
    Study = studies,
    Randomization = randomization,
    Deviations = deviations,
    Missing_Outcome = missing_outcome,
    Outcome_Measurement = outcome_measurement,
    Selection_Reported = selection_reported,
    stringsAsFactors = FALSE
  )
}

#' Generate Risk of Bias 2.0 traffic light plot
#' @param rob_data RoB data from create_rob2_data()
#' @param style "traffic_light", "summary", "bar"
#' @return ggplot object
generate_rob2_plot <- function(rob_data, style = "traffic_light") {

  # Reshape data for plotting
  rob_long <- rob_data %>%
    tidyr::pivot_longer(
      cols = -Study,
      names_to = "Domain",
      values_to = "Rating"
    ) %>%
    mutate(
      Domain = factor(Domain, levels = c(
        "Randomization", "Deviations", "Missing_Outcome",
        "Outcome_Measurement", "Selection_Reported"
      )),
      Rating = factor(Rating, levels = c("Low", "Some concerns", "High"))
    )

  # Color mapping
  rob_colors <- c(
    "Low" = "#00AA00",
    "Some concerns" = "#FFCC00",
    "High" = "#CC0000"
  )

  if (style == "traffic_light") {
    # Traffic light plot
    p <- ggplot(rob_long, aes(x = Domain, y = Study, fill = Rating)) +
      geom_tile(color = "white", linewidth = 1) +
      scale_fill_manual(values = rob_colors, drop = FALSE) +
      scale_x_discrete(
        labels = c(
          "Randomization\nProcess",
          "Deviations from\nIntended Interventions",
          "Missing\nOutcome Data",
          "Measurement of\nthe Outcome",
          "Selection of\nReported Result"
        )
      ) +
      labs(
        title = "Risk of Bias Assessment (RoB 2.0)",
        x = NULL,
        y = NULL,
        fill = "Risk of Bias"
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 0, hjust = 0.5, size = 9),
        axis.text.y = element_text(size = 9),
        legend.position = "bottom",
        panel.grid = element_blank()
      )
  } else if (style == "summary") {
    # Summary bar chart
    summary_data <- rob_long %>%
      group_by(Domain, Rating) %>%
      summarise(count = n(), .groups = "drop") %>%
      group_by(Domain) %>%
      mutate(pct = count / sum(count) * 100)

    p <- ggplot(summary_data, aes(x = Domain, y = pct, fill = Rating)) +
      geom_bar(stat = "identity", position = "stack") +
      scale_fill_manual(values = rob_colors, drop = FALSE) +
      scale_y_continuous(labels = function(x) paste0(x, "%")) +
      labs(
        title = "Risk of Bias Summary",
        x = NULL,
        y = "Percentage of Studies",
        fill = "Risk of Bias"
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom"
      )
  }

  return(p)
}

# ============================================================================
# ROBINS-I (Risk of Bias in Non-randomized Studies)
# ============================================================================

#' Create ROBINS-I assessment data
#' @param studies Vector of study IDs
#' @param confounding Bias due to confounding
#' @param selection Bias in selection of participants
#' @param classification Bias in classification of interventions
#' @param deviations Bias due to deviations from intended interventions
#' @param missing_data Bias due to missing data
#' @param outcome_measurement Bias in measurement of outcomes
#' @param selection_reported Bias in selection of reported result
#' @return Data frame with ROBINS-I assessments
create_robins_i_data <- function(studies,
                                  confounding,
                                  selection,
                                  classification,
                                  deviations,
                                  missing_data,
                                  outcome_measurement,
                                  selection_reported) {

  data.frame(
    Study = studies,
    Confounding = confounding,
    Selection = selection,
    Classification = classification,
    Deviations = deviations,
    Missing_Data = missing_data,
    Outcome_Measurement = outcome_measurement,
    Selection_Reported = selection_reported,
    stringsAsFactors = FALSE
  )
}

#' Generate ROBINS-I traffic light plot
#' @param robins_data ROBINS-I data
#' @return ggplot object
generate_robins_i_plot <- function(robins_data) {

  # Reshape data
  robins_long <- robins_data %>%
    tidyr::pivot_longer(
      cols = -Study,
      names_to = "Domain",
      values_to = "Rating"
    ) %>%
    mutate(
      Rating = factor(Rating, levels = c(
        "Low", "Moderate", "Serious", "Critical", "No information"
      ))
    )

  # Color mapping
  robins_colors <- c(
    "Low" = "#00AA00",
    "Moderate" = "#FFCC00",
    "Serious" = "#FF8800",
    "Critical" = "#CC0000",
    "No information" = "#CCCCCC"
  )

  p <- ggplot(robins_long, aes(x = Domain, y = Study, fill = Rating)) +
    geom_tile(color = "white", linewidth = 1) +
    scale_fill_manual(values = robins_colors, drop = FALSE) +
    scale_x_discrete(
      labels = c(
        "Confounding",
        "Selection",
        "Classification",
        "Deviations",
        "Missing\nData",
        "Outcome\nMeasurement",
        "Selection\nReported"
      )
    ) +
    labs(
      title = "Risk of Bias Assessment (ROBINS-I)",
      x = NULL,
      y = NULL,
      fill = "Risk of Bias"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
      axis.text.y = element_text(size = 9),
      legend.position = "bottom",
      panel.grid = element_blank()
    )

  return(p)
}

# ============================================================================
# GRADE (Grading of Recommendations Assessment)
# ============================================================================

#' Create GRADE evidence profile
#' @param outcomes Vector of outcomes
#' @param n_studies Number of studies per outcome
#' @param n_participants Total participants per outcome
#' @param risk_of_bias Risk of bias rating (0 = no serious, -1 = serious, -2 = very serious)
#' @param inconsistency Inconsistency rating
#' @param indirectness Indirectness rating
#' @param imprecision Imprecision rating
#' @param publication_bias Publication bias rating
#' @param effect_size Effect size description
#' @param certainty Overall certainty (High/Moderate/Low/Very Low)
#' @return Data frame with GRADE assessments
create_grade_profile <- function(outcomes,
                                  n_studies,
                                  n_participants,
                                  risk_of_bias,
                                  inconsistency,
                                  indirectness,
                                  imprecision,
                                  publication_bias,
                                  effect_size,
                                  certainty) {

  data.frame(
    Outcome = outcomes,
    N_Studies = n_studies,
    N_Participants = n_participants,
    Risk_of_Bias = risk_of_bias,
    Inconsistency = inconsistency,
    Indirectness = indirectness,
    Imprecision = imprecision,
    Publication_Bias = publication_bias,
    Effect = effect_size,
    Certainty = factor(certainty, levels = c("High", "Moderate", "Low", "Very Low")),
    stringsAsFactors = FALSE
  )
}

#' Generate GRADE Summary of Findings table
#' @param grade_data GRADE profile data
#' @param comparison Intervention vs comparator description
#' @param style "standard", "cochrane", "who"
#' @return gt table object
generate_grade_sof_table <- function(grade_data,
                                      comparison = "Intervention vs Control",
                                      style = "standard") {

  # Format for display
  sof_data <- grade_data %>%
    mutate(
      Studies = paste0(N_Studies, " studies\n(", N_Participants, " participants)"),
      Quality_Rating = case_when(
        Risk_of_Bias == 0 & Inconsistency == 0 &
          Indirectness == 0 & Imprecision == 0 &
          Publication_Bias == 0 ~ "⊕⊕⊕⊕ HIGH",
        Risk_of_Bias + Inconsistency + Indirectness +
          Imprecision + Publication_Bias == -1 ~ "⊕⊕⊕◯ MODERATE",
        Risk_of_Bias + Inconsistency + Indirectness +
          Imprecision + Publication_Bias == -2 ~ "⊕⊕◯◯ LOW",
        TRUE ~ "⊕◯◯◯ VERY LOW"
      ),
      Reasons = paste(
        ifelse(Risk_of_Bias < 0, "Risk of bias;", ""),
        ifelse(Inconsistency < 0, "Inconsistency;", ""),
        ifelse(Indirectness < 0, "Indirectness;", ""),
        ifelse(Imprecision < 0, "Imprecision;", ""),
        ifelse(Publication_Bias < 0, "Publication bias;", "")
      ) %>% trimws()
    ) %>%
    select(Outcome, Studies, Effect, Quality_Rating, Reasons)

  # Create gt table
  tbl <- gt(sof_data) %>%
    tab_header(
      title = "Summary of Findings",
      subtitle = comparison
    ) %>%
    cols_label(
      Outcome = "Outcome",
      Studies = "No. of Studies\n(Participants)",
      Effect = "Effect Size",
      Quality_Rating = "Certainty of Evidence\n(GRADE)",
      Reasons = "Reasons for Downgrading"
    )

  # Color-code certainty
  tbl <- tbl %>%
    tab_style(
      style = cell_fill(color = "#D4EDDA"),
      locations = cells_body(
        columns = Quality_Rating,
        rows = grepl("HIGH", Quality_Rating)
      )
    ) %>%
    tab_style(
      style = cell_fill(color = "#FFF3CD"),
      locations = cells_body(
        columns = Quality_Rating,
        rows = grepl("MODERATE", Quality_Rating)
      )
    ) %>%
    tab_style(
      style = cell_fill(color = "#F8D7DA"),
      locations = cells_body(
        columns = Quality_Rating,
        rows = grepl("LOW|VERY LOW", Quality_Rating)
      )
    )

  if (style == "cochrane") {
    tbl <- tbl %>%
      tab_options(
        table.font.names = "Arial",
        table.font.size = px(9),
        table.border.top.style = "solid",
        table.border.top.width = px(2),
        column_labels.background.color = "#E8F4F8"
      )
  }

  return(tbl)
}

#' Generate GRADE evidence profile plot
#' @param grade_data GRADE profile data
#' @return ggplot object
generate_grade_plot <- function(grade_data) {

  # Create rating summary
  certainty_summary <- grade_data %>%
    group_by(Certainty) %>%
    summarise(count = n(), .groups = "drop") %>%
    mutate(pct = count / sum(count) * 100)

  # Color mapping
  grade_colors <- c(
    "High" = "#28A745",
    "Moderate" = "#FFC107",
    "Low" = "#FD7E14",
    "Very Low" = "#DC3545"
  )

  p <- ggplot(certainty_summary, aes(x = "", y = pct, fill = Certainty)) +
    geom_bar(stat = "identity", width = 1) +
    coord_polar(theta = "y") +
    scale_fill_manual(values = grade_colors, drop = FALSE) +
    labs(
      title = "GRADE Certainty of Evidence",
      fill = "Certainty"
    ) +
    theme_void() +
    theme(
      legend.position = "right",
      plot.title = element_text(hjust = 0.5, face = "bold")
    )

  return(p)
}

# ============================================================================
# COMPLETE PUBLICATION PACKAGE GENERATOR
# ============================================================================

#' Generate complete publication package
#' @param data Study data
#' @param prisma_data PRISMA flow data
#' @param rob_data Risk of bias data
#' @param grade_data GRADE data
#' @param style Journal style
#' @return List of all publication components
generate_publication_package <- function(data,
                                          prisma_data = NULL,
                                          rob_data = NULL,
                                          robins_data = NULL,
                                          grade_data = NULL,
                                          style = "standard") {

  package <- list()

  # PRISMA
  if (!is.null(prisma_data)) {
    package$prisma_diagram <- generate_prisma_diagram(prisma_data)
    package$prisma_checklist <- generate_prisma_checklist()
  }

  # Study characteristics
  package$study_characteristics <- generate_study_characteristics_table(data, style)

  # Demographics
  if (all(c("age_mean", "age_sd", "female_pct") %in% names(data))) {
    package$demographics <- generate_demographics_table(data, style)
  }

  # Risk of Bias
  if (!is.null(rob_data)) {
    package$rob_traffic_light <- generate_rob2_plot(rob_data, "traffic_light")
    package$rob_summary <- generate_rob2_plot(rob_data, "summary")
  }

  # ROBINS-I
  if (!is.null(robins_data)) {
    package$robins_i <- generate_robins_i_plot(robins_data)
  }

  # GRADE
  if (!is.null(grade_data)) {
    package$grade_sof <- generate_grade_sof_table(grade_data, style = style)
    package$grade_plot <- generate_grade_plot(grade_data)
  }

  package$metadata <- list(
    generated_at = Sys.time(),
    style = style,
    n_studies = nrow(data)
  )

  return(package)
}

#' Save publication package to files
#' @param package Publication package from generate_publication_package()
#' @param output_dir Directory to save files
#' @param format "png", "pdf", "both"
#' @param dpi Resolution for images
save_publication_package <- function(package,
                                      output_dir = "publication_outputs",
                                      format = "both",
                                      dpi = 300) {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Save plots
  plot_names <- c("prisma_diagram", "rob_traffic_light", "rob_summary",
                  "robins_i", "grade_plot")

  for (plot_name in plot_names) {
    if (!is.null(package[[plot_name]])) {
      if (format %in% c("png", "both")) {
        ggsave(
          filename = file.path(output_dir, paste0(plot_name, ".png")),
          plot = package[[plot_name]],
          width = 10,
          height = 8,
          dpi = dpi
        )
      }
      if (format %in% c("pdf", "both")) {
        ggsave(
          filename = file.path(output_dir, paste0(plot_name, ".pdf")),
          plot = package[[plot_name]],
          width = 10,
          height = 8
        )
      }
    }
  }

  # Save tables as HTML and CSV
  table_names <- c("study_characteristics", "demographics", "grade_sof", "prisma_checklist")

  for (table_name in table_names) {
    if (!is.null(package[[table_name]])) {
      # HTML
      if (inherits(package[[table_name]], "gt_tbl")) {
        gtsave(package[[table_name]],
               filename = file.path(output_dir, paste0(table_name, ".html")))
      } else {
        write.csv(package[[table_name]],
                  file = file.path(output_dir, paste0(table_name, ".csv")),
                  row.names = FALSE)
      }
    }
  }

  message(sprintf("Publication package saved to: %s", output_dir))
}
