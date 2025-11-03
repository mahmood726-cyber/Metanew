# =============================================================================
# PRISMA 2020 Flow Diagram Generator
# =============================================================================
# ✅ STANDARD - Required by PRISMA 2020 guidelines
#
# Features:
# - PRISMA 2020 compliant flow diagram
# - Interactive number input with validation
# - Auto-calculation of derived numbers
# - Export to PNG/SVG/PDF
# - Customizable styling
# - Templates for different review types
# =============================================================================

library(shiny)
library(bslib)
library(DiagrammeR)
library(DiagrammeRsvg)
library(rsvg)
library(dplyr)

#' Generate PRISMA 2020 flow diagram
#'
#' @param identification List with database_records, other_records
#' @param screening List with duplicates_removed, records_screened, records_excluded
#' @param eligibility List with reports_sought, reports_assessed, reports_excluded, reasons
#' @param included List with studies_included, reports_included
#' @return DiagrammeR graph object
#' @export
generate_prisma_diagram <- function(identification, screening, eligibility, included) {

  # Calculate derived values
  records_after_dedup <- identification$database_records + identification$other_records - screening$duplicates_removed
  records_remaining <- records_after_dedup - screening$records_excluded
  reports_remaining <- eligibility$reports_sought - eligibility$reports_excluded

  # Build GraphViz DOT notation for PRISMA diagram
  dot_code <- sprintf('
digraph PRISMA {
  graph [layout = dot, rankdir = TB, fontname = Arial]
  node [shape = box, style = "filled,rounded", fontname = Arial, fontsize = 10]
  edge [fontname = Arial, fontsize = 9]

  // IDENTIFICATION
  subgraph cluster_identification {
    label = "Identification"
    style = filled
    color = "#E3F2FD"
    fontsize = 12
    fontname = "Arial Bold"

    id_db [label = "Records identified from\\nDatabases (n = %d)", fillcolor = "#BBDEFB"]
    id_other [label = "Records identified from\\nOther sources (n = %d)", fillcolor = "#BBDEFB"]
  }

  // SCREENING
  subgraph cluster_screening {
    label = "Screening"
    style = filled
    color = "#FFF9C4"
    fontsize = 12
    fontname = "Arial Bold"

    scr_dup [label = "Records removed before screening:\\nDuplicate records (n = %d)", fillcolor = "#FFF59D"]
    scr_screened [label = "Records screened\\n(n = %d)", fillcolor = "#FFF59D"]
    scr_excluded [label = "Records excluded\\n(n = %d)", fillcolor = "#FFEB3B", style = "filled,rounded,dashed"]
  }

  // ELIGIBILITY
  subgraph cluster_eligibility {
    label = "Eligibility"
    style = filled
    color = "#F3E5F5"
    fontsize = 12
    fontname = "Arial Bold"

    elig_sought [label = "Reports sought for retrieval\\n(n = %d)", fillcolor = "#E1BEE7"]
    elig_assessed [label = "Reports assessed for eligibility\\n(n = %d)", fillcolor = "#E1BEE7"]
    elig_excluded [label = "Reports excluded:\\n%s", fillcolor = "#CE93D8", style = "filled,rounded,dashed"]
  }

  // INCLUDED
  subgraph cluster_included {
    label = "Included"
    style = filled
    color = "#C8E6C9"
    fontsize = 12
    fontname = "Arial Bold"

    inc_studies [label = "Studies included in review\\n(n = %d)", fillcolor = "#A5D6A7"]
    inc_reports [label = "Reports of included studies\\n(n = %d)", fillcolor = "#A5D6A7"]
  }

  // Edges
  id_db -> scr_dup
  id_other -> scr_dup
  scr_dup -> scr_screened
  scr_screened -> scr_excluded [style = dashed]
  scr_screened -> elig_sought
  elig_sought -> elig_assessed
  elig_assessed -> elig_excluded [style = dashed]
  elig_assessed -> inc_studies
  inc_studies -> inc_reports
}
  ',
  identification$database_records,
  identification$other_records,
  screening$duplicates_removed,
  records_after_dedup,
  screening$records_excluded,
  records_remaining,
  eligibility$reports_assessed,
  eligibility$reasons,
  included$studies_included,
  included$reports_included
  )

  # Create diagram
  grViz(dot_code)
}

#' Format exclusion reasons for PRISMA diagram
#'
#' @param reasons_list List of exclusion reasons with counts
#' @return Formatted string for diagram
#' @export
format_exclusion_reasons <- function(reasons_list) {
  if (length(reasons_list) == 0) {
    return("Not specified (n = 0)")
  }

  # Format as "Reason 1 (n = X)\\nReason 2 (n = Y)"
  formatted <- sapply(names(reasons_list), function(reason) {
    sprintf("%s (n = %d)", reason, reasons_list[[reason]])
  })

  paste(formatted, collapse = "\\n")
}

#' UI for PRISMA flow diagram generator
#'
#' @param id Module ID
#' @export
prisma_flow_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      div(
        "PRISMA 2020 Flow Diagram Generator",
        span("✅ REQUIRED",
             style = "background: #EF4444; color: white; padding: 3px 8px;
                      border-radius: 4px; font-size: 11px; margin-left: 10px;")
      )
    ),

    p(
      "Generate a PRISMA 2020 compliant flow diagram for your systematic review. Required for journal submission.",
      style = "color: #6B7280; margin-bottom: 20px;"
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Input Form
      div(
        h5("PRISMA Flow Data", style = "color: #EC4899; margin-bottom: 15px;"),

        # Load template
        selectInput(
          ns("template"),
          "Load Template:",
          choices = c(
            "Blank" = "blank",
            "Typical SR (Database + Register)" = "typical",
            "Living SR" = "living",
            "Rapid Review" = "rapid"
          ),
          selected = "blank"
        ),

        hr(),

        # IDENTIFICATION
        h6("1. Identification", style = "color: #2196F3; margin-bottom: 10px;"),

        numericInput(
          ns("database_records"),
          "Records from databases:",
          value = 0,
          min = 0,
          step = 1
        ),

        numericInput(
          ns("other_records"),
          "Records from other sources:",
          value = 0,
          min = 0,
          step = 1
        ),

        # SCREENING
        h6("2. Screening", style = "color: #FFC107; margin-top: 20px; margin-bottom: 10px;"),

        numericInput(
          ns("duplicates_removed"),
          "Duplicates removed:",
          value = 0,
          min = 0,
          step = 1
        ),

        numericInput(
          ns("records_excluded"),
          "Records excluded (after screening):",
          value = 0,
          min = 0,
          step = 1
        ),

        # ELIGIBILITY
        h6("3. Eligibility", style = "color: #9C27B0; margin-top: 20px; margin-bottom: 10px;"),

        numericInput(
          ns("reports_sought"),
          "Reports sought for retrieval:",
          value = 0,
          min = 0,
          step = 1
        ),

        numericInput(
          ns("reports_not_retrieved"),
          "Reports not retrieved:",
          value = 0,
          min = 0,
          step = 1
        ),

        numericInput(
          ns("reports_excluded"),
          "Reports excluded:",
          value = 0,
          min = 0,
          step = 1
        ),

        textAreaInput(
          ns("exclusion_reasons"),
          "Exclusion reasons (one per line with count):",
          value = "Wrong population (n = 10)\nWrong intervention (n = 5)\nWrong outcome (n = 3)",
          rows = 4,
          placeholder = "Reason 1 (n = X)\nReason 2 (n = Y)"
        ),

        # INCLUDED
        h6("4. Included", style = "color: #4CAF50; margin-top: 20px; margin-bottom: 10px;"),

        numericInput(
          ns("studies_included"),
          "Studies included in review:",
          value = 0,
          min = 0,
          step = 1
        ),

        numericInput(
          ns("reports_included"),
          "Reports of included studies:",
          value = 0,
          min = 0,
          step = 1
        ),

        hr(),

        actionButton(
          ns("generate_diagram"),
          "Generate PRISMA Diagram",
          class = "btn-primary",
          icon = icon("project-diagram"),
          style = "width: 100%;"
        ),

        br(), br(),

        div(
          style = "background: #EFF6FF; border-left: 4px solid #3B82F6;
                   padding: 12px; border-radius: 6px;",
          div(
            strong(icon("info-circle", style = "color: #3B82F6; margin-right: 5px;"),
                   "PRISMA 2020"),
            style = "color: #1E40AF; margin-bottom: 8px;"
          ),
          p(
            "PRISMA 2020 guidelines require reporting the flow of studies through the review. This diagram shows how studies were identified, screened, and included.",
            style = "margin: 0; color: #1E40AF; font-size: 13px; line-height: 1.5;"
          )
        )
      ),

      # Diagram Display
      div(
        h5("PRISMA Flow Diagram", style = "color: #EC4899; margin-bottom: 15px;"),

        uiOutput(ns("validation_messages")),

        br(),

        # Diagram output
        div(
          style = "border: 2px solid #E5E7EB; border-radius: 8px; padding: 20px; background: white; min-height: 600px;",
          DiagrammeROutput(ns("prisma_diagram"), height = "700px")
        ),

        br(),

        # Export options
        div(
          style = "display: flex; gap: 10px; justify-content: center;",

          downloadButton(
            ns("download_png"),
            "Download PNG",
            class = "btn-success",
            icon = icon("image")
          ),

          downloadButton(
            ns("download_svg"),
            "Download SVG",
            class = "btn-info",
            icon = icon("vector-square")
          ),

          downloadButton(
            ns("download_pdf"),
            "Download PDF",
            class = "btn-danger",
            icon = icon("file-pdf")
          )
        )
      )
    ),

    hr(),

    div(
      style = "background: #FEF3C7; border-left: 4px solid #F59E0B;
               padding: 15px; border-radius: 6px;",

      div(
        strong(icon("lightbulb", style = "color: #F59E0B; margin-right: 5px;"),
               "Tips for PRISMA Flow Diagram"),
        style = "color: #92400E; margin-bottom: 8px;"
      ),

      tags$ul(
        style = "margin: 0; color: #92400E; font-size: 14px;",
        tags$li("Numbers should add up logically at each stage"),
        tags$li("Reports sought = Records after screening - Records excluded"),
        tags$li("All exclusion reasons should sum to total reports excluded"),
        tags$li("Studies vs reports: One study may have multiple reports"),
        tags$li("Export to PNG for manuscript submission")
      )
    )
  )
}

#' Server for PRISMA flow diagram generator
#'
#' @param id Module ID
#' @param rv Reactive values (not heavily used here)
#' @export
prisma_flow_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values for diagram
    prisma_data <- reactiveVal(NULL)

    # Load template
    observeEvent(input$template, {
      if (input$template == "typical") {
        updateNumericInput(session, "database_records", value = 1523)
        updateNumericInput(session, "other_records", value = 127)
        updateNumericInput(session, "duplicates_removed", value = 342)
        updateNumericInput(session, "records_excluded", value = 1215)
        updateNumericInput(session, "reports_sought", value = 93)
        updateNumericInput(session, "reports_not_retrieved", value = 8)
        updateNumericInput(session, "reports_excluded", value = 62)
        updateNumericInput(session, "studies_included", value = 23)
        updateNumericInput(session, "reports_included", value = 28)

      } else if (input$template == "living") {
        updateNumericInput(session, "database_records", value = 2341)
        updateNumericInput(session, "other_records", value = 89)
        updateNumericInput(session, "duplicates_removed", value = 456)
        updateNumericInput(session, "records_excluded", value = 1890)
        updateNumericInput(session, "reports_sought", value = 84)
        updateNumericInput(session, "reports_not_retrieved", value = 3)
        updateNumericInput(session, "reports_excluded", value = 47)
        updateNumericInput(session, "studies_included", value = 34)
        updateNumericInput(session, "reports_included", value = 41)

      } else if (input$template == "rapid") {
        updateNumericInput(session, "database_records", value = 876)
        updateNumericInput(session, "other_records", value = 42)
        updateNumericInput(session, "duplicates_removed", value = 198)
        updateNumericInput(session, "records_excluded", value = 695)
        updateNumericInput(session, "reports_sought", value = 25)
        updateNumericInput(session, "reports_not_retrieved", value = 2)
        updateNumericInput(session, "reports_excluded", value = 11)
        updateNumericInput(session, "studies_included", value = 12)
        updateNumericInput(session, "reports_included", value = 15)
      }
    })

    # Validate numbers
    validate_numbers <- reactive({
      messages <- list()

      # Calculate derived values
      total_records <- input$database_records + input$other_records
      records_after_dedup <- total_records - input$duplicates_removed
      records_remaining <- records_after_dedup - input$records_excluded

      # Check logical consistency
      if (input$duplicates_removed > total_records) {
        messages <- c(messages, "⚠️ Duplicates cannot exceed total records")
      }

      if (input$records_excluded > records_after_dedup) {
        messages <- c(messages, "⚠️ Excluded records cannot exceed records after deduplication")
      }

      if (input$reports_sought > records_remaining) {
        messages <- c(messages, "⚠️ Reports sought should not exceed records remaining after screening")
      }

      reports_assessed <- input$reports_sought - input$reports_not_retrieved

      if (input$reports_excluded > reports_assessed) {
        messages <- c(messages, "⚠️ Excluded reports cannot exceed reports assessed")
      }

      reports_final <- reports_assessed - input$reports_excluded

      if (input$studies_included > reports_final) {
        messages <- c(messages, "⚠️ Included studies cannot exceed reports remaining after exclusion")
      }

      if (input$reports_included < input$studies_included) {
        messages <- c(messages, "⚠️ Reports of included studies should be ≥ number of studies (one study may have multiple reports)")
      }

      # Success message if all valid
      if (length(messages) == 0) {
        messages <- c(messages, "✅ All numbers are logically consistent")
      }

      messages
    })

    # Display validation messages
    output$validation_messages <- renderUI({
      messages <- validate_numbers()

      is_valid <- !any(grepl("⚠️", messages))

      div(
        style = sprintf("background: %s; border: 1px solid %s; border-radius: 8px; padding: 12px;",
                        if (is_valid) "#D1FAE5" else "#FEF3C7",
                        if (is_valid) "#10B981" else "#F59E0B"),

        lapply(messages, function(msg) {
          p(msg, style = sprintf("margin: 3px 0; color: %s; font-size: 13px;",
                                  if (is_valid) "#065F46" else "#92400E"))
        })
      )
    })

    # Generate diagram
    observeEvent(input$generate_diagram, {

      # Collect data
      identification <- list(
        database_records = input$database_records,
        other_records = input$other_records
      )

      screening <- list(
        duplicates_removed = input$duplicates_removed,
        records_excluded = input$records_excluded
      )

      # Parse exclusion reasons
      reasons_text <- input$exclusion_reasons
      reasons_formatted <- gsub("\\n", "\\\\n", reasons_text)

      eligibility <- list(
        reports_sought = input$reports_sought,
        reports_assessed = input$reports_sought - input$reports_not_retrieved,
        reports_excluded = input$reports_excluded,
        reasons = reasons_formatted
      )

      included <- list(
        studies_included = input$studies_included,
        reports_included = input$reports_included
      )

      # Store data
      prisma_data(list(
        identification = identification,
        screening = screening,
        eligibility = eligibility,
        included = included
      ))
    })

    # Render diagram
    output$prisma_diagram <- renderDiagrammeR({
      req(prisma_data())

      data <- prisma_data()

      generate_prisma_diagram(
        identification = data$identification,
        screening = data$screening,
        eligibility = data$eligibility,
        included = data$included
      )
    })

    # Download PNG
    output$download_png <- downloadHandler(
      filename = function() {
        paste0("PRISMA_flow_diagram_", Sys.Date(), ".png")
      },
      content = function(file) {
        req(prisma_data())

        data <- prisma_data()

        diagram <- generate_prisma_diagram(
          identification = data$identification,
          screening = data$screening,
          eligibility = data$eligibility,
          included = data$included
        )

        # Export to SVG then convert to PNG
        svg_code <- export_svg(diagram)
        rsvg_png(charToRaw(svg_code), file, width = 1200, height = 1600)
      }
    )

    # Download SVG
    output$download_svg <- downloadHandler(
      filename = function() {
        paste0("PRISMA_flow_diagram_", Sys.Date(), ".svg")
      },
      content = function(file) {
        req(prisma_data())

        data <- prisma_data()

        diagram <- generate_prisma_diagram(
          identification = data$identification,
          screening = data$screening,
          eligibility = data$eligibility,
          included = data$included
        )

        svg_code <- export_svg(diagram)
        writeLines(svg_code, file)
      }
    )

    # Download PDF
    output$download_pdf <- downloadHandler(
      filename = function() {
        paste0("PRISMA_flow_diagram_", Sys.Date(), ".pdf")
      },
      content = function(file) {
        req(prisma_data())

        data <- prisma_data()

        diagram <- generate_prisma_diagram(
          identification = data$identification,
          screening = data$screening,
          eligibility = data$eligibility,
          included = data$included
        )

        # Export to SVG then convert to PDF
        svg_code <- export_svg(diagram)
        rsvg_pdf(charToRaw(svg_code), file, width = 8.5, height = 11)
      }
    )
  })
}
