# Shiny Modules for AI Features
# Ready-to-use UI and server modules for each AI feature
#
# Usage:
#   - Drop these modules into your Shiny app
#   - Each module is self-contained with UI and server logic
#   - Connect to API using AIFeaturesClient
#

library(shiny)
library(shinydashboard)
library(DT)
source("ai_features_api_client.R")


# ==================== REPORT GENERATION MODULE ====================

#' Report Generation Module UI
#'
#' @param id Module namespace ID
#' @export
reportGenerationUI <- function(id) {
  ns <- NS(id)

  box(
    title = "Natural Language Report Generation",
    status = "primary",
    solidHeader = TRUE,
    width = 12,

    fluidRow(
      column(6,
        h4("Meta-Analysis Results"),
        numericInput(ns("pooled_effect"), "Pooled Effect", value = 0.75, step = 0.01),
        numericInput(ns("ci_lower"), "CI Lower", value = 0.60, step = 0.01),
        numericInput(ns("ci_upper"), "CI Upper", value = 0.95, step = 0.01),
        numericInput(ns("i_squared"), "I² (%)", value = 45.2, step = 0.1)
      ),
      column(6,
        h4("Analysis Configuration"),
        textInput(ns("outcome"), "Outcome", value = "mortality"),
        textInput(ns("intervention"), "Intervention", value = "Drug A"),
        textInput(ns("comparator"), "Comparator", value = "Placebo"),
        selectInput(ns("report_type"), "Report Type",
                   choices = c("PRISMA" = "prisma", "CONSORT" = "consort", "GRADE" = "grade"))
      )
    ),

    actionButton(ns("generate"), "Generate Report", class = "btn-primary"),

    hr(),

    conditionalPanel(
      condition = paste0("output['", ns("report_ready"), "']"),
      h4("Generated Report"),
      downloadButton(ns("download_md"), "Download Markdown"),
      downloadButton(ns("download_html"), "Download HTML"),
      hr(),
      uiOutput(ns("report_output")),
      hr(),
      h4("Quality Metrics"),
      verbatimTextOutput(ns("quality_metrics"))
    )
  )
}


#' Report Generation Module Server
#'
#' @param id Module namespace ID
#' @param api_client Reactive API client
#' @param study_data Reactive study data (data.frame)
#' @export
reportGenerationServer <- function(id, api_client, study_data) {
  moduleServer(id, function(input, output, session) {

    report_data <- reactiveVal(NULL)

    observeEvent(input$generate, {
      req(api_client())

      withProgress(message = "Generating report...", {
        tryCatch({
          report <- api_client()$generate_report(
            meta_analysis_results = list(
              pooled_effect = input$pooled_effect,
              ci_lower = input$ci_lower,
              ci_upper = input$ci_upper,
              i_squared = input$i_squared
            ),
            study_data = study_data(),
            analysis_config = list(
              outcome = input$outcome,
              intervention = input$intervention,
              comparator = input$comparator
            ),
            report_type = input$report_type,
            include_quality_metrics = TRUE
          )

          report_data(report)
          showNotification("Report generated successfully!", type = "message")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error")
        })
      })
    })

    output$report_ready <- reactive({
      !is.null(report_data())
    })
    outputOptions(output, "report_ready", suspendWhenHidden = FALSE)

    output$report_output <- renderUI({
      req(report_data())
      report <- report_data()

      sections <- lapply(report$sections, function(sec) {
        tagList(
          h3(sec$heading),
          p(sec$content)
        )
      })

      tagList(
        h2(report$title),
        sections
      )
    })

    output$quality_metrics <- renderPrint({
      req(report_data())
      report <- report_data()

      if (!is.null(report$quality_metrics)) {
        qm <- report$quality_metrics
        cat("Readability (Flesch Reading Ease):", round(qm$readability$flesch_reading_ease, 1), "\n")
        cat("Grade Level:", qm$readability$grade_level, "\n")
        cat("Target Met:", ifelse(qm$readability$target_met, "✓ Yes", "✗ No"), "\n\n")

        if (!is.null(qm$prisma_compliance)) {
          cat("PRISMA Compliance:", round(qm$prisma_compliance$score, 1), "%\n")
          cat("Coverage:", round(qm$prisma_compliance$coverage * 100, 1), "%\n")
        }
      }
    })

    output$download_md <- downloadHandler(
      filename = function() { paste0("report_", Sys.Date(), ".md") },
      content = function(file) {
        writeLines(format_report_markdown(report_data()), file)
      }
    )

    output$download_html <- downloadHandler(
      filename = function() { paste0("report_", Sys.Date(), ".html") },
      content = function(file) {
        markdown_text <- format_report_markdown(report_data())
        html <- markdown::markdownToHTML(text = markdown_text, fragment.only = TRUE)
        writeLines(html, file)
      }
    )
  })
}


# ==================== RISK OF BIAS MODULE ====================

#' Risk of Bias Assessment Module UI
#'
#' @param id Module namespace ID
#' @export
robAssessmentUI <- function(id) {
  ns <- NS(id)

  box(
    title = "Risk of Bias Assessment",
    status = "warning",
    solidHeader = TRUE,
    width = 12,

    fluidRow(
      column(12,
        textAreaInput(ns("study_text"), "Study Text (abstract or full text)",
                     rows = 10,
                     placeholder = "Paste the study abstract or full text here...")
      )
    ),

    fluidRow(
      column(4, textInput(ns("title"), "Study Title")),
      column(4, numericInput(ns("year"), "Year", value = 2022, min = 1900, max = 2100)),
      column(4, textInput(ns("journal"), "Journal"))
    ),

    actionButton(ns("assess"), "Assess Risk of Bias", class = "btn-warning"),

    hr(),

    conditionalPanel(
      condition = paste0("output['", ns("rob_ready"), "']"),
      h4("Assessment Results"),
      valueBoxOutput(ns("overall_judgment"), width = 12),
      plotOutput(ns("domain_plot")),
      verbatimTextOutput(ns("rob_details"))
    )
  )
}


#' Risk of Bias Assessment Module Server
#'
#' @param id Module namespace ID
#' @param api_client Reactive API client
#' @export
robAssessmentServer <- function(id, api_client) {
  moduleServer(id, function(input, output, session) {

    rob_data <- reactiveVal(NULL)

    observeEvent(input$assess, {
      req(api_client(), input$study_text)

      withProgress(message = "Assessing risk of bias...", {
        tryCatch({
          rob <- api_client()$assess_rob(
            study_text = input$study_text,
            study_metadata = list(
              title = input$title,
              year = input$year,
              journal = input$journal
            ),
            return_probabilities = TRUE
          )

          rob_data(rob)
          showNotification("Assessment complete!", type = "message")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error")
        })
      })
    })

    output$rob_ready <- reactive({
      !is.null(rob_data())
    })
    outputOptions(output, "rob_ready", suspendWhenHidden = FALSE)

    output$overall_judgment <- renderValueBox({
      req(rob_data())
      rob <- rob_data()

      color <- switch(rob$overall_judgment,
        "Low" = "green",
        "Some concerns" = "yellow",
        "High" = "red",
        "gray"
      )

      valueBox(
        rob$overall_judgment,
        paste0("Overall Risk of Bias (", round(rob$overall_confidence * 100), "% confidence)"),
        icon = icon("check-circle"),
        color = color
      )
    })

    output$domain_plot <- renderPlot({
      req(rob_data())
      rob <- rob_data()

      domains <- names(rob$domains)
      judgments <- sapply(domains, function(d) rob$domains[[d]]$judgment)
      confidences <- sapply(domains, function(d) rob$domains[[d]]$confidence)

      # Create color mapping
      colors <- ifelse(judgments == "Low", "green",
                ifelse(judgments == "Some concerns", "yellow", "red"))

      par(mar = c(8, 5, 2, 2))
      barplot(
        confidences,
        names.arg = tools::toTitleCase(gsub("_", " ", domains)),
        col = colors,
        main = "Domain-Level Confidence",
        ylab = "Confidence",
        ylim = c(0, 1),
        las = 2
      )
      abline(h = 0.7, lty = 2, col = "gray")
      legend("topright",
             legend = c("Low", "Some concerns", "High"),
             fill = c("green", "yellow", "red"))
    })

    output$rob_details <- renderPrint({
      req(rob_data())
      cat(format_rob_assessment(rob_data()))
    })
  })
}


# ==================== STUDY SCREENING MODULE ====================

#' Study Screening Module UI
#'
#' @param id Module namespace ID
#' @export
studyScreeningUI <- function(id) {
  ns <- NS(id)

  box(
    title = "Study Screening Assistant",
    status = "info",
    solidHeader = TRUE,
    width = 12,

    tabsetPanel(
      tabPanel("Single Study",
        br(),
        textInput(ns("title"), "Study Title"),
        textAreaInput(ns("abstract"), "Abstract", rows = 8),
        sliderInput(ns("threshold"), "Inclusion Threshold",
                   min = 0, max = 1, value = 0.5, step = 0.05),
        actionButton(ns("screen"), "Screen Study", class = "btn-info"),
        hr(),
        uiOutput(ns("screening_result"))
      ),

      tabPanel("Batch Screening",
        br(),
        fileInput(ns("upload"), "Upload CSV (title, abstract columns)",
                 accept = ".csv"),
        sliderInput(ns("batch_threshold"), "Inclusion Threshold",
                   min = 0, max = 1, value = 0.5, step = 0.05),
        actionButton(ns("screen_batch"), "Screen All", class = "btn-info"),
        hr(),
        verbatimTextOutput(ns("batch_summary")),
        DTOutput(ns("batch_results"))
      ),

      tabPanel("Active Learning",
        br(),
        p("Upload unlabeled studies and get suggestions for which to review next"),
        fileInput(ns("unlabeled"), "Upload Unlabeled Studies (CSV)",
                 accept = ".csv"),
        numericInput(ns("n_suggestions"), "Number of Suggestions",
                    value = 10, min = 1, max = 100),
        selectInput(ns("strategy"), "Strategy",
                   choices = c("Uncertainty" = "uncertainty",
                              "Diversity" = "diversity",
                              "Hybrid" = "hybrid")),
        actionButton(ns("suggest"), "Get Suggestions", class = "btn-info"),
        hr(),
        DTOutput(ns("suggestions"))
      )
    )
  )
}


#' Study Screening Module Server
#'
#' @param id Module namespace ID
#' @param api_client Reactive API client
#' @export
studyScreeningServer <- function(id, api_client) {
  moduleServer(id, function(input, output, session) {

    # Single study screening
    observeEvent(input$screen, {
      req(api_client(), input$title)

      tryCatch({
        result <- api_client()$screen_study(
          title = input$title,
          abstract = input$abstract,
          threshold = input$threshold
        )

        output$screening_result <- renderUI({
          decision_color <- ifelse(result$decision == "include", "success", "danger")
          alert_class <- paste0("alert alert-", decision_color)

          tagList(
            div(class = alert_class,
              h4(paste0("Decision: ", toupper(result$decision))),
              p(paste0("Confidence: ", round(result$confidence * 100), "%")),
              if (result$requires_manual_review) {
                p(strong("⚠ Manual review recommended (low confidence)"))
              }
            )
          )
        })

      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error")
      })
    })

    # Batch screening
    batch_data <- reactiveVal(NULL)

    observeEvent(input$screen_batch, {
      req(api_client(), input$upload)

      studies <- read.csv(input$upload$datapath)
      req("title" %in% names(studies))

      if (!"abstract" %in% names(studies)) {
        studies$abstract <- ""
      }

      withProgress(message = "Screening studies...", {
        tryCatch({
          result <- api_client()$screen_studies_batch(
            studies = studies,
            threshold = input$batch_threshold
          )

          batch_data(result)

          output$batch_summary <- renderPrint({
            cat("Total Studies:", result$total_studies, "\n")
            cat("Included:", result$summary$included, "\n")
            cat("Excluded:", result$summary$excluded, "\n")
            cat("Manual Review:", result$summary$needs_review, "\n")
          })

          output$batch_results <- renderDT({
            results_df <- do.call(rbind, lapply(result$results, as.data.frame))
            datatable(results_df, options = list(pageLength = 25))
          })

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error")
        })
      })
    })

    # Active learning
    observeEvent(input$suggest, {
      req(api_client(), input$unlabeled)

      unlabeled <- read.csv(input$unlabeled$datapath)
      req("title" %in% names(unlabeled))

      withProgress(message = "Generating suggestions...", {
        tryCatch({
          result <- api_client()$get_active_learning_suggestions(
            unlabeled_studies = unlabeled,
            n_suggestions = input$n_suggestions,
            strategy = input$strategy
          )

          output$suggestions <- renderDT({
            suggestions_df <- do.call(rbind, lapply(result$suggestions, as.data.frame))
            datatable(suggestions_df, options = list(pageLength = 10))
          })

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error")
        })
      })
    })
  })
}


# ==================== EXAMPLE APP ====================

# Example Shiny app using all modules
if (FALSE) {
  library(shinydashboard)

  ui <- dashboardPage(
    dashboardHeader(title = "AI Features"),

    dashboardSidebar(
      sidebarMenu(
        menuItem("Report Generation", tabName = "report"),
        menuItem("Risk of Bias", tabName = "rob"),
        menuItem("Study Screening", tabName = "screening")
      ),
      hr(),
      textInput("api_token", "API Token", ""),
      actionButton("connect", "Connect to API")
    ),

    dashboardBody(
      tabItems(
        tabItem(tabName = "report",
          reportGenerationUI("report_module")
        ),
        tabItem(tabName = "rob",
          robAssessmentUI("rob_module")
        ),
        tabItem(tabName = "screening",
          studyScreeningUI("screening_module")
        )
      )
    )
  )

  server <- function(input, output, session) {
    # Create API client
    api_client <- reactiveVal(NULL)

    observeEvent(input$connect, {
      client <- create_ai_client(token = input$api_token)
      api_client(client)
      showNotification("Connected to API", type = "message")
    })

    # Sample study data
    study_data <- reactive({
      data.frame(
        study_id = c("Study1", "Study2", "Study3"),
        year = c(2020, 2021, 2022),
        n_treatment = c(100, 150, 120),
        n_control = c(100, 150, 120)
      )
    })

    # Initialize modules
    reportGenerationServer("report_module", api_client, study_data)
    robAssessmentServer("rob_module", api_client)
    studyScreeningServer("screening_module", api_client)
  }

  shinyApp(ui, server)
}
