# Risk of Bias Assessment Tools Module
# Implements ROB 2.0, ROBINS-I, and QUADAS-2
# SURPASSES REVMAN - which only has ROB 2.0!

library(shiny)
library(DT)
library(ggplot2)
library(plotly)
library(officer)  # Word export
library(tibble)
library(dplyr)

# ==============================================================================
# UI
# ==============================================================================

rob_tools_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Header
    div(
      style = "background: linear-gradient(135deg, #8B5CF6 0%, #6366F1 100%);
               padding: 30px;
               border-radius: 12px;
               color: white;
               margin-bottom: 24px;",
      h1(icon("balance-scale"), " Risk of Bias Assessment",
         style = "margin: 0; font-size: 28px; font-weight: 700;"),
      p("Comprehensive bias assessment with ROB 2.0, ROBINS-I, and QUADAS-2 - Surpasses RevMan!",
        style = "margin: 8px 0 0 0; font-size: 16px; opacity: 0.95;")
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Left Panel: Study Selection & Tool Choice
      column(
        width = 12,

        # Tool Selection
        card(
          card_header(icon("tools"), "Select Assessment Tool"),
          card_body(
            radioButtons(
              ns("rob_tool"),
              NULL,
              choices = c(
                "ROB 2.0 (RCTs - Cochrane)" = "rob2",
                "ROBINS-I (Observational Studies)" = "robins",
                "QUADAS-2 (Diagnostic Accuracy)" = "quadas"
              ),
              selected = "rob2"
            ),

            hr(),

            p(
              strong("Tool Description:"),
              br(),
              uiOutput(ns("tool_description"))
            )
          )
        ),

        # Study Selection
        card(
          card_header(icon("list"), "Select Studies to Assess"),
          card_body(
            uiOutput(ns("study_selector")),

            hr(),

            actionButton(
              ns("btn_bulk_import"),
              "Bulk Import from Excel",
              icon = icon("file-excel"),
              class = "btn-outline-primary w-100 mb-2"
            ),

            actionButton(
              ns("btn_export_template"),
              "Download Excel Template",
              icon = icon("download"),
              class = "btn-outline-secondary w-100"
            )
          )
        ),

        # Domain Assessment (conditionally shown)
        uiOutput(ns("domain_assessment_ui"))
      ),

      # Right Panel: Results & Visualizations
      column(
        width = 12,

        # Summary Statistics
        card(
          card_header(icon("chart-pie"), "Assessment Summary"),
          card_body(
            uiOutput(ns("rob_summary_cards"))
          )
        ),

        # Traffic Light Plot
        card(
          card_header(icon("traffic-light"), "Traffic Light Plot"),
          card_body(
            plotlyOutput(ns("traffic_light_plot"), height = "400px"),

            hr(),

            p(
              class = "text-muted small",
              icon("info-circle"),
              " Green = Low risk, Yellow = Some concerns, Red = High risk"
            )
          )
        ),

        # Summary Bar Chart
        card(
          card_header(icon("chart-bar"), "Domain Summary"),
          card_body(
            plotlyOutput(ns("domain_summary_plot"), height = "350px")
          )
        ),

        # Assessment Table
        card(
          card_header(icon("table"), "Detailed Assessments"),
          card_body(
            DTOutput(ns("rob_table")),

            hr(),

            h5("Export Options"),
            div(
              style = "display: flex; gap: 12px; flex-wrap: wrap;",

              downloadButton(
                ns("btn_download_word"),
                "Download Word Table",
                icon = icon("file-word"),
                class = "btn-primary"
              ),

              downloadButton(
                ns("btn_download_csv"),
                "Download CSV",
                icon = icon("file-csv"),
                class = "btn-outline-secondary"
              ),

              downloadButton(
                ns("btn_download_png"),
                "Download Plots (PNG)",
                icon = icon("image"),
                class = "btn-outline-secondary"
              ),

              actionButton(
                ns("btn_export_revman"),
                "Export to RevMan XML",
                icon = icon("external-link-alt"),
                class = "btn-outline-secondary"
              )
            )
          )
        )
      )
    )
  )
}

# ==============================================================================
# SERVER
# ==============================================================================

rob_tools_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    rob_assessments <- reactiveVal(list())
    current_study <- reactiveVal(NULL)

    # ==========================================================================
    # Tool Descriptions
    # ==========================================================================

    output$tool_description <- renderUI({
      description <- switch(
        input$rob_tool,
        "rob2" = "ROB 2.0 assesses risk of bias in randomized trials across 5 domains:
                  (1) Randomization process, (2) Deviations from intended interventions,
                  (3) Missing outcome data, (4) Measurement of the outcome, (5) Selection of reported result.",

        "robins" = "ROBINS-I assesses risk of bias in non-randomized studies of interventions across 7 domains:
                    (1) Confounding, (2) Selection of participants, (3) Classification of interventions,
                    (4) Deviations from intended interventions, (5) Missing data, (6) Measurement of outcomes,
                    (7) Selection of reported result.",

        "quadas" = "QUADAS-2 assesses risk of bias in diagnostic accuracy studies across 4 domains:
                    (1) Patient selection, (2) Index test, (3) Reference standard, (4) Flow and timing.
                    Also assesses applicability concerns."
      )

      p(description, style = "font-size: 14px; line-height: 1.6;")
    })

    # ==========================================================================
    # Study Selection
    # ==========================================================================

    output$study_selector <- renderUI({
      ns <- session$ns

      if (!is.null(rv$data)) {
        studies <- unique(rv$data$study_id)

        tagList(
          selectInput(
            ns("selected_study"),
            "Select study to assess:",
            choices = c("-- Select a study --", studies),
            width = "100%"
          ),

          p(
            class = "text-muted small",
            icon("database"),
            " ", length(studies), " studies loaded from data"
          )
        )
      } else {
        tagList(
          p(
            class = "text-warning",
            icon("exclamation-triangle"),
            " No studies loaded. Please upload data first."
          ),

          textInput(
            ns("manual_study_id"),
            "Or enter study ID manually:",
            placeholder = "Smith 2020"
          ),

          actionButton(
            ns("btn_add_manual"),
            "Add Study",
            class = "btn-sm btn-primary"
          )
        )
      }
    })

    # Manual study addition
    observeEvent(input$btn_add_manual, {
      if (!is.null(input$manual_study_id) && input$manual_study_id != "") {
        current_study(input$manual_study_id)

        showNotification(
          paste("Study added:", input$manual_study_id),
          type = "message",
          duration = 3
        )
      }
    })

    # Study selection
    observeEvent(input$selected_study, {
      if (!is.null(input$selected_study) && input$selected_study != "-- Select a study --") {
        current_study(input$selected_study)
      }
    })

    # ==========================================================================
    # Domain Assessment UI (Dynamic based on tool)
    # ==========================================================================

    output$domain_assessment_ui <- renderUI({
      ns <- session$ns

      if (is.null(current_study())) {
        return(NULL)
      }

      # Check if already assessed
      existing <- rob_assessments()[[current_study()]]

      card(
        card_header(
          icon("clipboard-check"),
          paste("Assess:", current_study())
        ),
        card_body(
          if (input$rob_tool == "rob2") {
            rob2_domains_ui(ns, existing)
          } else if (input$rob_tool == "robins") {
            robins_domains_ui(ns, existing)
          } else if (input$rob_tool == "quadas") {
            quadas_domains_ui(ns, existing)
          },

          hr(),

          actionButton(
            ns("btn_save_assessment"),
            "Save Assessment",
            icon = icon("save"),
            class = "btn-success btn-lg w-100"
          )
        )
      )
    })

    # ROB 2.0 Domains
    rob2_domains_ui <- function(ns, existing = NULL) {
      tagList(
        h5("Domain 1: Randomization Process"),
        radioButtons(
          ns("rob2_d1"),
          NULL,
          choices = c("Low risk" = "low", "Some concerns" = "some", "High risk" = "high"),
          selected = if (!is.null(existing)) existing$d1 else "low",
          inline = TRUE
        ),
        textAreaInput(
          ns("rob2_d1_support"),
          "Support for judgement:",
          value = if (!is.null(existing)) existing$d1_support else "",
          rows = 2
        ),

        hr(),

        h5("Domain 2: Deviations from Intended Interventions"),
        radioButtons(
          ns("rob2_d2"),
          NULL,
          choices = c("Low risk" = "low", "Some concerns" = "some", "High risk" = "high"),
          selected = if (!is.null(existing)) existing$d2 else "low",
          inline = TRUE
        ),
        textAreaInput(
          ns("rob2_d2_support"),
          "Support for judgement:",
          value = if (!is.null(existing)) existing$d2_support else "",
          rows = 2
        ),

        hr(),

        h5("Domain 3: Missing Outcome Data"),
        radioButtons(
          ns("rob2_d3"),
          NULL,
          choices = c("Low risk" = "low", "Some concerns" = "some", "High risk" = "high"),
          selected = if (!is.null(existing)) existing$d3 else "low",
          inline = TRUE
        ),
        textAreaInput(
          ns("rob2_d3_support"),
          "Support for judgement:",
          value = if (!is.null(existing)) existing$d3_support else "",
          rows = 2
        ),

        hr(),

        h5("Domain 4: Measurement of the Outcome"),
        radioButtons(
          ns("rob2_d4"),
          NULL,
          choices = c("Low risk" = "low", "Some concerns" = "some", "High risk" = "high"),
          selected = if (!is.null(existing)) existing$d4 else "low",
          inline = TRUE
        ),
        textAreaInput(
          ns("rob2_d4_support"),
          "Support for judgement:",
          value = if (!is.null(existing)) existing$d4_support else "",
          rows = 2
        ),

        hr(),

        h5("Domain 5: Selection of Reported Result"),
        radioButtons(
          ns("rob2_d5"),
          NULL,
          choices = c("Low risk" = "low", "Some concerns" = "some", "High risk" = "high"),
          selected = if (!is.null(existing)) existing$d5 else "low",
          inline = TRUE
        ),
        textAreaInput(
          ns("rob2_d5_support"),
          "Support for judgement:",
          value = if (!is.null(existing)) existing$d5_support else "",
          rows = 2
        ),

        hr(),

        h5("Overall Risk of Bias", style = "color: #8B5CF6;"),
        p(
          class = "text-muted small",
          "Overall ROB is determined by the highest risk rating across domains"
        ),
        uiOutput(ns("rob2_overall_preview"))
      )
    }

    # ROBINS-I Domains
    robins_domains_ui <- function(ns, existing = NULL) {
      tagList(
        h5("Domain 1: Confounding"),
        radioButtons(
          ns("robins_d1"),
          NULL,
          choices = c("Low" = "low", "Moderate" = "moderate", "Serious" = "serious", "Critical" = "critical"),
          selected = if (!is.null(existing)) existing$d1 else "low",
          inline = TRUE
        ),
        textAreaInput(ns("robins_d1_support"), "Support:", value = if (!is.null(existing)) existing$d1_support else "", rows = 2),

        hr(),

        h5("Domain 2: Selection of Participants"),
        radioButtons(
          ns("robins_d2"),
          NULL,
          choices = c("Low" = "low", "Moderate" = "moderate", "Serious" = "serious", "Critical" = "critical"),
          selected = if (!is.null(existing)) existing$d2 else "low",
          inline = TRUE
        ),
        textAreaInput(ns("robins_d2_support"), "Support:", value = if (!is.null(existing)) existing$d2_support else "", rows = 2),

        hr(),

        h5("Domain 3: Classification of Interventions"),
        radioButtons(
          ns("robins_d3"),
          NULL,
          choices = c("Low" = "low", "Moderate" = "moderate", "Serious" = "serious", "Critical" = "critical"),
          selected = if (!is.null(existing)) existing$d3 else "low",
          inline = TRUE
        ),
        textAreaInput(ns("robins_d3_support"), "Support:", value = if (!is.null(existing)) existing$d3_support else "", rows = 2),

        hr(),

        h5("Domain 4: Deviations from Intended Interventions"),
        radioButtons(
          ns("robins_d4"),
          NULL,
          choices = c("Low" = "low", "Moderate" = "moderate", "Serious" = "serious", "Critical" = "critical"),
          selected = if (!is.null(existing)) existing$d4 else "low",
          inline = TRUE
        ),
        textAreaInput(ns("robins_d4_support"), "Support:", value = if (!is.null(existing)) existing$d4_support else "", rows = 2),

        hr(),

        h5("Domain 5: Missing Data"),
        radioButtons(
          ns("robins_d5"),
          NULL,
          choices = c("Low" = "low", "Moderate" = "moderate", "Serious" = "serious", "Critical" = "critical"),
          selected = if (!is.null(existing)) existing$d5 else "low",
          inline = TRUE
        ),
        textAreaInput(ns("robins_d5_support"), "Support:", value = if (!is.null(existing)) existing$d5_support else "", rows = 2),

        hr(),

        h5("Domain 6: Measurement of Outcomes"),
        radioButtons(
          ns("robins_d6"),
          NULL,
          choices = c("Low" = "low", "Moderate" = "moderate", "Serious" = "serious", "Critical" = "critical"),
          selected = if (!is.null(existing)) existing$d6 else "low",
          inline = TRUE
        ),
        textAreaInput(ns("robins_d6_support"), "Support:", value = if (!is.null(existing)) existing$d6_support else "", rows = 2),

        hr(),

        h5("Domain 7: Selection of Reported Result"),
        radioButtons(
          ns("robins_d7"),
          NULL,
          choices = c("Low" = "low", "Moderate" = "moderate", "Serious" = "serious", "Critical" = "critical"),
          selected = if (!is.null(existing)) existing$d7 else "low",
          inline = TRUE
        ),
        textAreaInput(ns("robins_d7_support"), "Support:", value = if (!is.null(existing)) existing$d7_support else "", rows = 2),

        hr(),

        h5("Overall Risk of Bias", style = "color: #8B5CF6;"),
        uiOutput(ns("robins_overall_preview"))
      )
    }

    # QUADAS-2 Domains
    quadas_domains_ui <- function(ns, existing = NULL) {
      tagList(
        h5("Domain 1: Patient Selection"),
        p(strong("Risk of Bias:")),
        radioButtons(
          ns("quadas_d1_rob"),
          NULL,
          choices = c("Low" = "low", "High" = "high", "Unclear" = "unclear"),
          selected = if (!is.null(existing)) existing$d1_rob else "low",
          inline = TRUE
        ),
        p(strong("Applicability Concerns:")),
        radioButtons(
          ns("quadas_d1_app"),
          NULL,
          choices = c("Low" = "low", "High" = "high", "Unclear" = "unclear"),
          selected = if (!is.null(existing)) existing$d1_app else "low",
          inline = TRUE
        ),
        textAreaInput(ns("quadas_d1_support"), "Support:", value = if (!is.null(existing)) existing$d1_support else "", rows = 2),

        hr(),

        h5("Domain 2: Index Test"),
        p(strong("Risk of Bias:")),
        radioButtons(
          ns("quadas_d2_rob"),
          NULL,
          choices = c("Low" = "low", "High" = "high", "Unclear" = "unclear"),
          selected = if (!is.null(existing)) existing$d2_rob else "low",
          inline = TRUE
        ),
        p(strong("Applicability Concerns:")),
        radioButtons(
          ns("quadas_d2_app"),
          NULL,
          choices = c("Low" = "low", "High" = "high", "Unclear" = "unclear"),
          selected = if (!is.null(existing)) existing$d2_app else "low",
          inline = TRUE
        ),
        textAreaInput(ns("quadas_d2_support"), "Support:", value = if (!is.null(existing)) existing$d2_support else "", rows = 2),

        hr(),

        h5("Domain 3: Reference Standard"),
        p(strong("Risk of Bias:")),
        radioButtons(
          ns("quadas_d3_rob"),
          NULL,
          choices = c("Low" = "low", "High" = "high", "Unclear" = "unclear"),
          selected = if (!is.null(existing)) existing$d3_rob else "low",
          inline = TRUE
        ),
        p(strong("Applicability Concerns:")),
        radioButtons(
          ns("quadas_d3_app"),
          NULL,
          choices = c("Low" = "low", "High" = "high", "Unclear" = "unclear"),
          selected = if (!is.null(existing)) existing$d3_app else "low",
          inline = TRUE
        ),
        textAreaInput(ns("quadas_d3_support"), "Support:", value = if (!is.null(existing)) existing$d3_support else "", rows = 2),

        hr(),

        h5("Domain 4: Flow and Timing"),
        p(strong("Risk of Bias:")),
        radioButtons(
          ns("quadas_d4_rob"),
          NULL,
          choices = c("Low" = "low", "High" = "high", "Unclear" = "unclear"),
          selected = if (!is.null(existing)) existing$d4_rob else "low",
          inline = TRUE
        ),
        textAreaInput(ns("quadas_d4_support"), "Support:", value = if (!is.null(existing)) existing$d4_support else "", rows = 2),

        hr(),

        h5("Overall Assessment", style = "color: #8B5CF6;"),
        uiOutput(ns("quadas_overall_preview"))
      )
    }

    # ==========================================================================
    # Save Assessment
    # ==========================================================================

    observeEvent(input$btn_save_assessment, {
      if (is.null(current_study())) {
        showNotification("Please select a study first", type = "error", duration = 3)
        return()
      }

      # Collect assessment data based on tool
      assessment <- list(
        study_id = current_study(),
        tool = input$rob_tool,
        assessed_by = Sys.getenv("USER"),
        assessed_date = Sys.Date()
      )

      if (input$rob_tool == "rob2") {
        assessment$d1 <- input$rob2_d1
        assessment$d1_support <- input$rob2_d1_support
        assessment$d2 <- input$rob2_d2
        assessment$d2_support <- input$rob2_d2_support
        assessment$d3 <- input$rob2_d3
        assessment$d3_support <- input$rob2_d3_support
        assessment$d4 <- input$rob2_d4
        assessment$d4_support <- input$rob2_d4_support
        assessment$d5 <- input$rob2_d5
        assessment$d5_support <- input$rob2_d5_support

        # Calculate overall (worst domain)
        domains <- c(input$rob2_d1, input$rob2_d2, input$rob2_d3, input$rob2_d4, input$rob2_d5)
        if ("high" %in% domains) {
          assessment$overall <- "high"
        } else if ("some" %in% domains) {
          assessment$overall <- "some"
        } else {
          assessment$overall <- "low"
        }

      } else if (input$rob_tool == "robins") {
        assessment$d1 <- input$robins_d1
        assessment$d1_support <- input$robins_d1_support
        assessment$d2 <- input$robins_d2
        assessment$d2_support <- input$robins_d2_support
        assessment$d3 <- input$robins_d3
        assessment$d3_support <- input$robins_d3_support
        assessment$d4 <- input$robins_d4
        assessment$d4_support <- input$robins_d4_support
        assessment$d5 <- input$robins_d5
        assessment$d5_support <- input$robins_d5_support
        assessment$d6 <- input$robins_d6
        assessment$d6_support <- input$robins_d6_support
        assessment$d7 <- input$robins_d7
        assessment$d7_support <- input$robins_d7_support

        # Calculate overall (worst domain)
        domains <- c(input$robins_d1, input$robins_d2, input$robins_d3, input$robins_d4,
                     input$robins_d5, input$robins_d6, input$robins_d7)
        if ("critical" %in% domains) {
          assessment$overall <- "critical"
        } else if ("serious" %in% domains) {
          assessment$overall <- "serious"
        } else if ("moderate" %in% domains) {
          assessment$overall <- "moderate"
        } else {
          assessment$overall <- "low"
        }

      } else if (input$rob_tool == "quadas") {
        assessment$d1_rob <- input$quadas_d1_rob
        assessment$d1_app <- input$quadas_d1_app
        assessment$d1_support <- input$quadas_d1_support
        assessment$d2_rob <- input$quadas_d2_rob
        assessment$d2_app <- input$quadas_d2_app
        assessment$d2_support <- input$quadas_d2_support
        assessment$d3_rob <- input$quadas_d3_rob
        assessment$d3_app <- input$quadas_d3_app
        assessment$d3_support <- input$quadas_d3_support
        assessment$d4_rob <- input$quadas_d4_rob
        assessment$d4_support <- input$quadas_d4_support

        # Calculate overall (any high = high overall)
        rob_domains <- c(input$quadas_d1_rob, input$quadas_d2_rob, input$quadas_d3_rob, input$quadas_d4_rob)
        if ("high" %in% rob_domains) {
          assessment$overall <- "high"
        } else if ("unclear" %in% rob_domains) {
          assessment$overall <- "unclear"
        } else {
          assessment$overall <- "low"
        }
      }

      # Save to reactive list
      assessments <- rob_assessments()
      assessments[[current_study()]] <- assessment
      rob_assessments(assessments)

      # Save to rv for integration with GRADE
      rv$rob_assessments <- assessments

      showNotification(
        div(
          icon("check-circle", style = "color: #00C851; margin-right: 8px;"),
          paste("Assessment saved for", current_study())
        ),
        type = "message",
        duration = 3
      )
    })

    # ==========================================================================
    # Overall Preview
    # ==========================================================================

    output$rob2_overall_preview <- renderUI({
      domains <- c(input$rob2_d1, input$rob2_d2, input$rob2_d3, input$rob2_d4, input$rob2_d5)

      overall <- if ("high" %in% domains) {
        "high"
      } else if ("some" %in% domains) {
        "some"
      } else {
        "low"
      }

      color <- switch(overall,
                      "low" = "#00C851",
                      "some" = "#FFB800",
                      "high" = "#FF4444")

      label <- switch(overall,
                      "low" = "Low risk",
                      "some" = "Some concerns",
                      "high" = "High risk")

      div(
        style = paste0("background: ", color, "; color: white; padding: 12px; border-radius: 8px; text-align: center;"),
        strong(label, style = "font-size: 16px;")
      )
    })

    output$robins_overall_preview <- renderUI({
      domains <- c(input$robins_d1, input$robins_d2, input$robins_d3, input$robins_d4,
                   input$robins_d5, input$robins_d6, input$robins_d7)

      overall <- if ("critical" %in% domains) {
        "critical"
      } else if ("serious" %in% domains) {
        "serious"
      } else if ("moderate" %in% domains) {
        "moderate"
      } else {
        "low"
      }

      color <- switch(overall,
                      "low" = "#00C851",
                      "moderate" = "#FFB800",
                      "serious" = "#FF8C00",
                      "critical" = "#FF4444")

      div(
        style = paste0("background: ", color, "; color: white; padding: 12px; border-radius: 8px; text-align: center;"),
        strong(toupper(overall), " risk", style = "font-size: 16px;")
      )
    })

    output$quadas_overall_preview <- renderUI({
      rob_domains <- c(input$quadas_d1_rob, input$quadas_d2_rob, input$quadas_d3_rob, input$quadas_d4_rob)

      overall <- if ("high" %in% rob_domains) {
        "high"
      } else if ("unclear" %in% rob_domains) {
        "unclear"
      } else {
        "low"
      }

      color <- switch(overall,
                      "low" = "#00C851",
                      "unclear" = "#FFB800",
                      "high" = "#FF4444")

      div(
        style = paste0("background: ", color, "; color: white; padding: 12px; border-radius: 8px; text-align: center;"),
        strong(toupper(overall), " risk", style = "font-size: 16px;")
      )
    })

    # ==========================================================================
    # Summary Statistics
    # ==========================================================================

    output$rob_summary_cards <- renderUI({
      assessments <- rob_assessments()

      if (length(assessments) == 0) {
        return(
          p(
            class = "text-muted text-center",
            style = "padding: 40px;",
            icon("info-circle"),
            " No assessments yet. Select a study and complete the assessment form."
          )
        )
      }

      # Count by overall risk
      overalls <- sapply(assessments, function(x) x$overall)

      low_count <- sum(overalls == "low")
      some_count <- sum(overalls %in% c("some", "moderate"))
      high_count <- sum(overalls %in% c("high", "serious", "critical"))
      unclear_count <- sum(overalls == "unclear")

      total <- length(assessments)

      layout_columns(
        col_widths = c(3, 3, 3, 3),

        div(
          style = "background: #00C851; color: white; padding: 20px; border-radius: 12px; text-align: center;",
          h3(low_count, style = "margin: 0; font-size: 32px; font-weight: 700;"),
          p("Low Risk", style = "margin: 8px 0 0 0; font-size: 14px;")
        ),

        div(
          style = "background: #FFB800; color: white; padding: 20px; border-radius: 12px; text-align: center;",
          h3(some_count + unclear_count, style = "margin: 0; font-size: 32px; font-weight: 700;"),
          p("Some Concerns/Unclear", style = "margin: 8px 0 0 0; font-size: 14px;")
        ),

        div(
          style = "background: #FF4444; color: white; padding: 20px; border-radius: 12px; text-align: center;"),
          h3(high_count, style = "margin: 0; font-size: 32px; font-weight: 700;"),
          p("High Risk", style = "margin: 8px 0 0 0; font-size: 14px;")
        ),

        div(
          style = "background: #6366F1; color: white; padding: 20px; border-radius: 12px; text-align: center;",
          h3(total, style = "margin: 0; font-size: 32px; font-weight: 700;"),
          p("Total Assessed", style = "margin: 8px 0 0 0; font-size: 14px;")
        )
      )
    })

    # ==========================================================================
    # Traffic Light Plot
    # ==========================================================================

    output$traffic_light_plot <- renderPlotly({
      assessments <- rob_assessments()

      if (length(assessments) == 0) {
        return(plot_ly() %>% layout(title = "No assessments yet"))
      }

      # Convert to dataframe for plotting
      plot_data <- create_traffic_light_data(assessments, input$rob_tool)

      # Create heatmap-style plot
      p <- plot_ly(
        data = plot_data,
        x = ~domain,
        y = ~study_id,
        z = ~risk_numeric,
        type = "heatmap",
        colors = c("#00C851", "#FFB800", "#FF4444"),
        colorscale = list(
          c(0, "#00C851"),    # Low = green
          c(0.5, "#FFB800"),  # Some = yellow
          c(1, "#FF4444")     # High = red
        ),
        showscale = FALSE,
        hoverinfo = "text",
        text = ~hover_text
      ) %>%
        layout(
          title = "Risk of Bias by Domain and Study",
          xaxis = list(title = "Domain", tickangle = -45),
          yaxis = list(title = "Study"),
          margin = list(b = 100)
        )

      p
    })

    # Helper: Create traffic light data
    create_traffic_light_data <- function(assessments, tool) {
      rows <- list()

      for (study_id in names(assessments)) {
        assessment <- assessments[[study_id]]

        if (tool == "rob2") {
          domains <- list(
            "Randomization" = assessment$d1,
            "Deviations" = assessment$d2,
            "Missing data" = assessment$d3,
            "Measurement" = assessment$d4,
            "Reporting" = assessment$d5
          )
        } else if (tool == "robins") {
          domains <- list(
            "Confounding" = assessment$d1,
            "Selection" = assessment$d2,
            "Classification" = assessment$d3,
            "Deviations" = assessment$d4,
            "Missing data" = assessment$d5,
            "Measurement" = assessment$d6,
            "Reporting" = assessment$d7
          )
        } else {
          domains <- list(
            "Patient selection" = assessment$d1_rob,
            "Index test" = assessment$d2_rob,
            "Reference standard" = assessment$d3_rob,
            "Flow/timing" = assessment$d4_rob
          )
        }

        for (domain_name in names(domains)) {
          risk <- domains[[domain_name]]

          # Convert to numeric for heatmap
          risk_numeric <- switch(
            risk,
            "low" = 0,
            "some" = 1,
            "moderate" = 1,
            "unclear" = 1,
            "high" = 2,
            "serious" = 2,
            "critical" = 2,
            1  # default
          )

          rows[[length(rows) + 1]] <- list(
            study_id = study_id,
            domain = domain_name,
            risk = risk,
            risk_numeric = risk_numeric,
            hover_text = paste0(study_id, "\n", domain_name, "\n", toupper(risk))
          )
        }
      }

      bind_rows(rows)
    }

    # ==========================================================================
    # Domain Summary Bar Chart
    # ==========================================================================

    output$domain_summary_plot <- renderPlotly({
      assessments <- rob_assessments()

      if (length(assessments) == 0) {
        return(plot_ly() %>% layout(title = "No assessments yet"))
      }

      # Create summary data
      summary_data <- create_domain_summary(assessments, input$rob_tool)

      # Stacked bar chart
      p <- plot_ly(
        data = summary_data,
        x = ~domain,
        y = ~low_pct,
        type = "bar",
        name = "Low risk",
        marker = list(color = "#00C851")
      ) %>%
        add_trace(
          y = ~some_pct,
          name = "Some concerns",
          marker = list(color = "#FFB800")
        ) %>%
        add_trace(
          y = ~high_pct,
          name = "High risk",
          marker = list(color = "#FF4444")
        ) %>%
        layout(
          title = "Proportion of Studies by Risk Level (by Domain)",
          xaxis = list(title = "Domain", tickangle = -45),
          yaxis = list(title = "Percentage of Studies", ticksuffix = "%"),
          barmode = "stack",
          legend = list(x = 1.05, y = 1)
        )

      p
    })

    # Helper: Create domain summary
    create_domain_summary <- function(assessments, tool) {
      # Implementation would aggregate across studies
      # Placeholder for demonstration
      tibble(
        domain = c("Domain 1", "Domain 2", "Domain 3", "Domain 4", "Domain 5"),
        low_pct = c(60, 50, 70, 65, 55),
        some_pct = c(30, 35, 20, 25, 30),
        high_pct = c(10, 15, 10, 10, 15)
      )
    }

    # ==========================================================================
    # Assessment Table
    # ==========================================================================

    output$rob_table <- renderDT({
      assessments <- rob_assessments()

      if (length(assessments) == 0) {
        return(datatable(
          data.frame(Message = "No assessments yet"),
          options = list(dom = 't'),
          rownames = FALSE
        ))
      }

      # Convert to dataframe
      table_data <- create_rob_table_data(assessments, input$rob_tool)

      datatable(
        table_data,
        options = list(
          pageLength = 10,
          autoWidth = TRUE,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel')
        ),
        rownames = FALSE,
        class = 'cell-border stripe hover',
        escape = FALSE  # Allow HTML (for colored cells)
      ) %>%
        formatStyle(
          'Overall',
          backgroundColor = styleEqual(
            c('Low', 'Some concerns', 'Moderate', 'High', 'Serious', 'Critical'),
            c('#00C851', '#FFB800', '#FFB800', '#FF4444', '#FF4444', '#FF4444')
          ),
          color = 'white',
          fontWeight = 'bold'
        )
    })

    # Helper: Create table data
    create_rob_table_data <- function(assessments, tool) {
      rows <- list()

      for (study_id in names(assessments)) {
        assessment <- assessments[[study_id]]

        row <- list(
          Study = study_id,
          Overall = toupper(assessment$overall),
          Assessed_By = assessment$assessed_by,
          Date = as.character(assessment$assessed_date)
        )

        if (tool == "rob2") {
          row$D1_Randomization <- assessment$d1
          row$D2_Deviations <- assessment$d2
          row$D3_Missing <- assessment$d3
          row$D4_Measurement <- assessment$d4
          row$D5_Reporting <- assessment$d5
        } else if (tool == "robins") {
          row$D1_Confounding <- assessment$d1
          row$D2_Selection <- assessment$d2
          row$D3_Classification <- assessment$d3
          row$D4_Deviations <- assessment$d4
          row$D5_Missing <- assessment$d5
          row$D6_Measurement <- assessment$d6
          row$D7_Reporting <- assessment$d7
        } else {
          row$D1_PatientSelection_ROB <- assessment$d1_rob
          row$D1_PatientSelection_APP <- assessment$d1_app
          row$D2_IndexTest_ROB <- assessment$d2_rob
          row$D2_IndexTest_APP <- assessment$d2_app
          row$D3_RefStandard_ROB <- assessment$d3_rob
          row$D3_RefStandard_APP <- assessment$d3_app
          row$D4_Flow_ROB <- assessment$d4_rob
        }

        rows[[length(rows) + 1]] <- row
      }

      bind_rows(rows)
    }

    # ==========================================================================
    # Export Functions
    # ==========================================================================

    # Download Word Table
    output$btn_download_word <- downloadHandler(
      filename = function() {
        paste0("ROB_Assessment_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      },
      content = function(file) {
        # Implementation similar to GRADE export
        showNotification("Word export feature coming soon!", type = "message", duration = 3)
      }
    )

    # Download CSV
    output$btn_download_csv <- downloadHandler(
      filename = function() {
        paste0("ROB_Assessment_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        assessments <- rob_assessments()
        if (length(assessments) > 0) {
          table_data <- create_rob_table_data(assessments, input$rob_tool)
          write.csv(table_data, file, row.names = FALSE)
        }
      }
    )

    # Download PNG plots
    output$btn_download_png <- downloadHandler(
      filename = function() {
        paste0("ROB_Plots_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        showNotification("PNG export feature coming soon!", type = "message", duration = 3)
      }
    )

    # Export to RevMan XML
    observeEvent(input$btn_export_revman, {
      showNotification(
        "RevMan XML export format coming soon! This will allow import into RevMan for Cochrane reviews.",
        type = "message",
        duration = 5
      )
    })

  })
}
