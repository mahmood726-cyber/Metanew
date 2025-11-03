# PRISMA 2020 Flow Diagram Generator
# Automated generation of PRISMA flowcharts following PRISMA 2020 statement
# Reference: Page et al. (2021) BMJ 372:n71

library(DiagrammeR)
library(ggplot2)

#' Generate PRISMA 2020 Flow Diagram
#'
#' Creates a PRISMA-compliant flow diagram showing study selection process
#'
#' @param n_database Number of records identified through database searching
#' @param n_registers Number of records identified through registers
#' @param n_websites Number of records identified through websites
#' @param n_organisations Number of records identified through organisations
#' @param n_citations Number of records identified through citation searching
#' @param n_other Number of records identified through other methods
#' @param n_duplicates Number of duplicate records removed
#' @param n_marked_ineligible Number of records marked as ineligible by automation tools
#' @param n_excluded Number of records excluded after title/abstract screening
#' @param exclusion_reasons Named vector of exclusion reasons and counts
#' @param n_not_retrieved Number of reports not retrieved
#' @param n_sought Number of reports sought for retrieval
#' @param n_excluded_full_text Number of reports excluded after full-text review
#' @param full_text_exclusion_reasons Named vector of full-text exclusion reasons
#' @param n_included Number of studies included in synthesis
#' @param n_new_studies Number of new studies included (for updates)
#' @param n_previous_studies Number of studies from previous version
#' @return PRISMA flow diagram (DiagrammeR object)
#'
#' @export
generate_prisma_flowchart <- function(
  n_database = 0,
  n_registers = 0,
  n_websites = 0,
  n_organisations = 0,
  n_citations = 0,
  n_other = 0,
  n_duplicates = 0,
  n_marked_ineligible = 0,
  n_excluded = 0,
  exclusion_reasons = NULL,
  n_not_retrieved = 0,
  n_sought = 0,
  n_excluded_full_text = 0,
  full_text_exclusion_reasons = NULL,
  n_included = 0,
  n_new_studies = 0,
  n_previous_studies = 0
) {

  # Calculate derived values
  n_identification <- n_database + n_registers + n_websites +
                      n_organisations + n_citations + n_other

  n_after_duplicates <- n_identification - n_duplicates

  n_screened <- n_after_duplicates - n_marked_ineligible

  n_retrieved <- n_sought - n_not_retrieved

  n_assessed_full_text <- n_retrieved

  n_included_total <- n_included + n_new_studies + n_previous_studies

  # Build flowchart nodes
  nodes <- sprintf("
graph TB

  %% Identification section
  ID_DB[\"<b>Records identified from:</b><br/>
  Databases (n = %d)<br/>
  Registers (n = %d)\"]

  ID_OTHER[\"<b>Records identified from:</b><br/>
  Websites (n = %d)<br/>
  Organisations (n = %d)<br/>
  Citation searching (n = %d)<br/>
  Other (n = %d)\"]

  ID_DUP[\"Records removed before screening:<br/>
  Duplicate records removed (n = %d)<br/>
  Records marked as ineligible<br/>
  by automation tools (n = %d)\"]

  ID_SCREENED[\"<b>Records screened</b><br/>(n = %d)\"]

  ID_EXCLUDED[\"Records excluded<br/>(n = %d)%s\"]

  %% Screening section
  SCREEN_SOUGHT[\"<b>Reports sought for retrieval</b><br/>(n = %d)\"]

  SCREEN_NOT[\"Reports not retrieved<br/>(n = %d)\"]

  %% Included section
  FULL_ASSESSED[\"<b>Reports assessed for eligibility</b><br/>(n = %d)\"]

  FULL_EXCLUDED[\"Reports excluded:<br/>(n = %d)%s\"]

  %% Final inclusion
  STUDIES[\"<b>Studies included in review</b><br/>(n = %d)%s\"]

  %% Connections
  ID_DB --> ID_SCREENED
  ID_OTHER --> ID_SCREENED
  ID_DUP -.-> ID_SCREENED
  ID_SCREENED --> SCREEN_SOUGHT
  ID_EXCLUDED -.-> SCREEN_SOUGHT
  SCREEN_SOUGHT --> FULL_ASSESSED
  SCREEN_NOT -.-> FULL_ASSESSED
  FULL_ASSESSED --> STUDIES
  FULL_EXCLUDED -.-> STUDIES

  %% Styling
  classDef identification fill:#E1F5FE,stroke:#01579B,stroke-width:2px
  classDef screening fill:#F3E5F5,stroke:#4A148C,stroke-width:2px
  classDef included fill:#E8F5E9,stroke:#1B5E20,stroke-width:2px
  classDef excluded fill:#FFEBEE,stroke:#B71C1C,stroke-width:2px

  class ID_DB,ID_OTHER identification
  class ID_SCREENED,SCREEN_SOUGHT,FULL_ASSESSED screening
  class STUDIES included
  class ID_EXCLUDED,SCREEN_NOT,FULL_EXCLUDED excluded
  ",
  n_database,
  n_registers,
  n_websites,
  n_organisations,
  n_citations,
  n_other,
  n_duplicates,
  n_marked_ineligible,
  n_screened,
  n_excluded,
  format_exclusion_reasons(exclusion_reasons),
  n_sought,
  n_not_retrieved,
  n_assessed_full_text,
  n_excluded_full_text,
  format_exclusion_reasons(full_text_exclusion_reasons),
  n_included,
  format_included_studies(n_new_studies, n_previous_studies)
  )

  # Generate diagram
  diagram <- DiagrammeR::grViz(nodes)

  return(diagram)
}


#' Format Exclusion Reasons for Display
#'
#' @param reasons Named vector of exclusion reasons
#' @return Formatted string
#' @keywords internal
format_exclusion_reasons <- function(reasons) {
  if (is.null(reasons) || length(reasons) == 0) {
    return("")
  }

  formatted <- paste(
    sprintf("<br/>%s (n = %d)", names(reasons), reasons),
    collapse = ""
  )

  return(formatted)
}


#' Format Included Studies Information
#'
#' @param n_new Number of new studies
#' @param n_previous Number of previous studies
#' @return Formatted string
#' @keywords internal
format_included_studies <- function(n_new, n_previous) {
  if (n_new == 0 && n_previous == 0) {
    return("")
  }

  parts <- character()

  if (n_new > 0) {
    parts <- c(parts, sprintf("<br/>New studies (n = %d)", n_new))
  }

  if (n_previous > 0) {
    parts <- c(parts, sprintf("<br/>Previous studies (n = %d)", n_previous))
  }

  return(paste(parts, collapse = ""))
}


#' Create PRISMA Data Template
#'
#' Creates a template data frame for tracking PRISMA data
#'
#' @return Data frame template
#' @export
create_prisma_template <- function() {
  template <- data.frame(
    stage = c(
      "identification_databases",
      "identification_registers",
      "identification_websites",
      "identification_organisations",
      "identification_citations",
      "identification_other",
      "duplicates_removed",
      "records_marked_ineligible",
      "records_screened",
      "records_excluded",
      "reports_sought",
      "reports_not_retrieved",
      "reports_assessed_full_text",
      "reports_excluded_full_text",
      "studies_included",
      "new_studies",
      "previous_studies"
    ),
    count = NA_integer_,
    notes = NA_character_,
    stringsAsFactors = FALSE
  )

  return(template)
}


#' Track Study Selection Process
#'
#' Interactive tracking of study selection with automatic PRISMA data generation
#'
#' @param screening_data Data frame with screening results
#' @param study_col Column name for study ID
#' @param decision_col Column name for inclusion decision
#' @param reason_col Column name for exclusion reason
#' @param stage Column name for screening stage
#' @return List with PRISMA data
#' @export
track_study_selection <- function(
  screening_data,
  study_col = "study_id",
  decision_col = "decision",
  reason_col = "reason",
  stage_col = "stage"
) {

  # Count by stage and decision
  title_abstract <- screening_data[screening_data[[stage_col]] == "title_abstract", ]
  full_text <- screening_data[screening_data[[stage_col]] == "full_text", ]

  # Title/abstract screening
  n_screened <- nrow(title_abstract)
  n_excluded_ta <- sum(title_abstract[[decision_col]] == "exclude", na.rm = TRUE)
  n_sought <- sum(title_abstract[[decision_col]] == "include", na.rm = TRUE)

  # Exclusion reasons at title/abstract
  ta_exclusions <- table(title_abstract[[reason_col]][
    title_abstract[[decision_col]] == "exclude"
  ])

  # Full-text screening
  n_assessed <- nrow(full_text)
  n_excluded_ft <- sum(full_text[[decision_col]] == "exclude", na.rm = TRUE)
  n_included <- sum(full_text[[decision_col]] == "include", na.rm = TRUE)

  # Exclusion reasons at full-text
  ft_exclusions <- table(full_text[[reason_col]][
    full_text[[decision_col]] == "exclude"
  ])

  # Compile PRISMA data
  prisma_data <- list(
    n_screened = n_screened,
    n_excluded = n_excluded_ta,
    exclusion_reasons = as.vector(ta_exclusions),
    exclusion_reason_names = names(ta_exclusions),
    n_sought = n_sought,
    n_assessed_full_text = n_assessed,
    n_excluded_full_text = n_excluded_ft,
    full_text_exclusion_reasons = as.vector(ft_exclusions),
    full_text_exclusion_reason_names = names(ft_exclusions),
    n_included = n_included
  )

  class(prisma_data) <- "prisma_tracking"
  return(prisma_data)
}


#' Export PRISMA Data to CSV
#'
#' @param prisma_data PRISMA tracking data
#' @param file File path for export
#' @export
export_prisma_data <- function(prisma_data, file) {

  # Create summary data frame
  summary <- data.frame(
    metric = c(
      "Records screened",
      "Records excluded (title/abstract)",
      "Reports sought for retrieval",
      "Reports assessed for eligibility",
      "Reports excluded (full text)",
      "Studies included in review"
    ),
    count = c(
      prisma_data$n_screened,
      prisma_data$n_excluded,
      prisma_data$n_sought,
      prisma_data$n_assessed_full_text,
      prisma_data$n_excluded_full_text,
      prisma_data$n_included
    ),
    stringsAsFactors = FALSE
  )

  # Add exclusion reasons
  if (length(prisma_data$exclusion_reasons) > 0) {
    ta_reasons <- data.frame(
      metric = paste("  -", prisma_data$exclusion_reason_names),
      count = prisma_data$exclusion_reasons,
      stringsAsFactors = FALSE
    )
    summary <- rbind(summary[1:2, ], ta_reasons, summary[3:6, ])
  }

  if (length(prisma_data$full_text_exclusion_reasons) > 0) {
    ft_reasons <- data.frame(
      metric = paste("  -", prisma_data$full_text_exclusion_reason_names),
      count = prisma_data$full_text_exclusion_reasons,
      stringsAsFactors = FALSE
    )
    rows_before <- which(summary$metric == "Reports excluded (full text)")
    summary <- rbind(
      summary[1:rows_before, ],
      ft_reasons,
      summary[(rows_before + 1):nrow(summary), ]
    )
  }

  write.csv(summary, file, row.names = FALSE)
  message("PRISMA data exported to: ", file)
}


#' Print Method for PRISMA Tracking
#'
#' @param x prisma_tracking object
#' @param ... Additional arguments
#' @export
print.prisma_tracking <- function(x, ...) {
  cat("\nPRISMA Study Selection Summary\n")
  cat("================================\n\n")

  cat("Title/Abstract Screening:\n")
  cat("  Records screened:", x$n_screened, "\n")
  cat("  Records excluded:", x$n_excluded, "\n")

  if (length(x$exclusion_reasons) > 0) {
    cat("  Exclusion reasons:\n")
    for (i in seq_along(x$exclusion_reasons)) {
      cat("    -", x$exclusion_reason_names[i], ":",
          x$exclusion_reasons[i], "\n")
    }
  }

  cat("\nFull-Text Assessment:\n")
  cat("  Reports assessed:", x$n_assessed_full_text, "\n")
  cat("  Reports excluded:", x$n_excluded_full_text, "\n")

  if (length(x$full_text_exclusion_reasons) > 0) {
    cat("  Exclusion reasons:\n")
    for (i in seq_along(x$full_text_exclusion_reasons)) {
      cat("    -", x$full_text_exclusion_reason_names[i], ":",
          x$full_text_exclusion_reasons[i], "\n")
    }
  }

  cat("\nFinal Inclusion:\n")
  cat("  Studies included:", x$n_included, "\n")

  invisible(x)
}


#' Generate Simplified PRISMA Flowchart
#'
#' Creates a simplified text-based PRISMA flowchart for quick review
#'
#' @param prisma_data PRISMA tracking data or manual counts
#' @return Character vector with flowchart
#' @export
prisma_text_flow <- function(prisma_data) {

  flow <- c(
    "",
    "PRISMA Flow Diagram",
    "==================",
    "",
    "IDENTIFICATION",
    sprintf("  Records identified: %d", prisma_data$n_identified %||% 0),
    sprintf("  Duplicates removed: %d", prisma_data$n_duplicates %||% 0),
    "",
    "SCREENING",
    sprintf("  Records screened: %d", prisma_data$n_screened),
    sprintf("  Records excluded: %d", prisma_data$n_excluded),
    "",
    "ELIGIBILITY",
    sprintf("  Full-text assessed: %d", prisma_data$n_assessed_full_text),
    sprintf("  Full-text excluded: %d", prisma_data$n_excluded_full_text),
    "",
    "INCLUDED",
    sprintf("  Studies included: %d", prisma_data$n_included),
    ""
  )

  cat(paste(flow, collapse = "\n"))
  invisible(flow)
}


# Helper for null coalescing
`%||%` <- function(x, y) if (is.null(x)) y else x


#' Example Usage
#'
#' @examples
#' \dontrun{
#' # Manual specification
#' diagram <- generate_prisma_flowchart(
#'   n_database = 5234,
#'   n_registers = 312,
#'   n_citations = 47,
#'   n_duplicates = 1893,
#'   n_screened = 3700,
#'   n_excluded = 3520,
#'   exclusion_reasons = c(
#'     "Wrong population" = 1250,
#'     "Wrong intervention" = 890,
#'     "Wrong outcome" = 710,
#'     "Not RCT" = 670
#'   ),
#'   n_sought = 180,
#'   n_not_retrieved = 8,
#'   n_excluded_full_text = 148,
#'   full_text_exclusion_reasons = c(
#'     "Wrong population" = 45,
#'     "Insufficient data" = 38,
#'     "Duplicate" = 35,
#'     "Other" = 30
#'   ),
#'   n_included = 24
#' )
#'
#' # Display
#' print(diagram)
#'
#' # Export as PNG
#' DiagrammeR::export_graph(diagram, "prisma_flowchart.png")
#'
#' # Automated from screening data
#' screening_data <- read.csv("screening_decisions.csv")
#' prisma_tracking <- track_study_selection(screening_data)
#' print(prisma_tracking)
#' export_prisma_data(prisma_tracking, "prisma_data.csv")
#' }
#' @name prisma_examples
NULL
