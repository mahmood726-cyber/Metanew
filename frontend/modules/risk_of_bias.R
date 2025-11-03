# Risk of Bias Assessment Module (RoB 2.0)
# Cochrane Risk of Bias tool for randomized trials

library(shiny)
library(DT)
library(ggplot2)

# Source RoB 2.0 utility functions
source("utils/rob2_tool.R", local = TRUE)

# UI
risk_of_bias_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("Risk of Bias Assessment (RoB 2.0)",
       style = "margin-bottom: 20px;"),

    p(class = "text-muted",
      icon("info-circle"),
      "Cochrane Risk of Bias tool version 2.0 (Sterne et al. 2019). ",
      "Assess bias across five domains for each randomized controlled trial.",
      style = "margin-bottom: 20px;"),

    layout_columns(
      col_widths = c(4, 8),

      # Left panel: Assessment controls
      card(
        card_header(
          "Assessment Tools",
          class = "bg-primary text-white"
        ),

        # Study selection
        selectInput(
          ns("study_select"),
          tags$span(
            "Select Study",
            bslib::tooltip(
              icon("circle-question"),
              "Choose a study from your dataset to assess"
            )
          ),
          choices = NULL
        ),

        hr(),

        # Assessment buttons
        actionButton(
          ns("btn_create_template"),
          "Create Assessment Template",
          icon = icon("file-lines"),
          class = "btn-success w-100 mb-3"
        ),

        actionButton(
          ns("btn_upload_assessments"),
          "Upload Completed Assessments",
          icon = icon("upload"),
          class = "btn-info w-100 mb-3"
        ),

        fileInput(
          ns("rob_file"),
          NULL,
          accept = c(".csv", ".xlsx")
        ),

        hr(),

        # Analysis actions
        h5("Analysis Actions"),

        checkboxInput(
          ns("show_traffic_light"),
          "Show traffic light plot",
          value = TRUE
        ),

        actionButton(
          ns("btn_sensitivity"),
          "Run Sensitivity Analysis by RoB",
          icon = icon("chart-line"),
          class = "btn-warning w-100 mb-2",
          title = "Meta-analysis excluding high risk of bias studies"
        ),

        actionButton(
          ns("btn_export_rob"),
          "Export RoB Assessments",
          icon = icon("download"),
          class = "btn-secondary w-100"
        )
      ),

      # Right panel: Results
      card(
        card_header(
          "Risk of Bias Results",
          class = "bg-info text-white"
        ),
        navset_card_tab(
          # Tab 1: Assessment Form
          nav_panel(
            "Assessment Form",
            icon = icon("clipboard-check"),

            conditionalPanel(
              condition = "input.study_select != ''",
              ns = ns,

              h4("Study: ", textOutput(ns("current_study"), inline = TRUE)),

              hr(),

              # Domain 1: Randomization
              h5(
                icon("1", class = "fas"),
                " Bias from randomization process",
                bslib::tooltip(
                  icon("circle-question"),
                  "Was the allocation sequence random? Was allocation concealed?"
                )
              ),
              radioButtons(
                ns("d1_rating"),
                NULL,
                choices = c("Low" = "Low", "Some concerns" = "Some concerns", "High" = "High"),
                inline = TRUE
              ),
              textAreaInput(ns("d1_notes"), "Notes:", rows = 2),

              hr(),

              # Domain 2: Deviations
              h5(
                icon("2", class = "fas"),
                " Bias from deviations from intended interventions",
                bslib::tooltip(
                  icon("circle-question"),
                  "Were participants and personnel blind? Were there deviations?"
                )
              ),
              radioButtons(
                ns("d2_rating"),
                NULL,
                choices = c("Low" = "Low", "Some concerns" = "Some concerns", "High" = "High"),
                inline = TRUE
              ),
              textAreaInput(ns("d2_notes"), "Notes:", rows = 2),

              hr(),

              # Domain 3: Missing data
              h5(
                icon("3", class = "fas"),
                " Bias from missing outcome data",
                bslib::tooltip(
                  icon("circle-question"),
                  "Were outcome data available for all participants?"
                )
              ),
              radioButtons(
                ns("d3_rating"),
                NULL,
                choices = c("Low" = "Low", "Some concerns" = "Some concerns", "High" = "High"),
                inline = TRUE
              ),
              textAreaInput(ns("d3_notes"), "Notes:", rows = 2),

              hr(),

              # Domain 4: Measurement
              h5(
                icon("4", class = "fas"),
                " Bias in measurement of the outcome",
                bslib::tooltip(
                  icon("circle-question"),
                  "Was outcome measurement appropriate and consistent?"
                )
              ),
              radioButtons(
                ns("d4_rating"),
                NULL,
                choices = c("Low" = "Low", "Some concerns" = "Some concerns", "High" = "High"),
                inline = TRUE
              ),
              textAreaInput(ns("d4_notes"), "Notes:", rows = 2),

              hr(),

              # Domain 5: Reporting
              h5(
                icon("5", class = "fas"),
                " Bias in selection of reported result",
                bslib::tooltip(
                  icon("circle-question"),
                  "Was the result likely selected for reporting?"
                )
              ),
              radioButtons(
                ns("d5_rating"),
                NULL,
                choices = c("Low" = "Low", "Some concerns" = "Some concerns", "High" = "High"),
                inline = TRUE
              ),
              textAreaInput(ns("d5_notes"), "Notes:", rows = 2),

              hr(),

              # Overall rating (auto-calculated)
              h4(
                "Overall Risk of Bias: ",
                textOutput(ns("overall_rating"), inline = TRUE),
                style = "margin-top: 20px;"
              ),

              actionButton(
                ns("btn_save_assessment"),
                "Save Assessment",
                icon = icon("save"),
                class = "btn-primary w-100 mt-3"
              )
            )
          ),

          # Tab 2: Summary Table
          nav_panel(
            "Summary Table",
            icon = icon("table"),
            DTOutput(ns("rob_summary_table")),
            p(class = "text-muted mt-3",
              icon("lightbulb"),
              strong("Interpretation: "),
              "Overall risk is the highest risk across all domains. ",
              "Any 'High' → Overall 'High'. Any 'Some concerns' → Overall 'Some concerns'."
            )
          ),

          # Tab 3: Traffic Light Plot
          nav_panel(
            "Traffic Light Plot",
            icon = icon("traffic-light"),
            plotOutput(ns("traffic_light_plot"), height = "600px"),
            p(class = "text-muted mt-3",
              icon("palette"),
              "Green = Low risk, Yellow = Some concerns, Red = High risk"
            )
          ),

          # Tab 4: Sensitivity Analysis
          nav_panel(
            "Sensitivity Analysis",
            icon = icon("chart-line"),

            p(class = "alert alert-info",
              icon("info-circle"),
              "Compare meta-analysis results including all studies vs. ",
              "excluding studies with high risk of bias."
            ),

            selectInput(
              ns("exclude_risk_level"),
              "Exclude studies with:",
              choices = c(
                "High risk of bias" = "High",
                "High or Some concerns" = "High_or_Some"
              ),
              selected = "High"
            ),

            verbatimTextOutput(ns("sensitivity_results")),

            plotOutput(ns("sensitivity_forest_plot"), height = "500px")
          )
        )
      )
    )
  )
}

# Server
risk_of_bias_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive value for RoB assessments
    rob_data <- reactiveVal(NULL)

    # Update study choices when data is loaded
    observe({
      req(rv$data)

      if ("study_id" %in% names(rv$data)) {
        studies <- unique(rv$data$study_id)
        updateSelectInput(session, "study_select", choices = c("", studies))
      }
    })

    # Display current study
    output$current_study <- renderText({
      req(input$study_select)
      input$study_select
    })

    # Calculate overall rating based on domain ratings
    overall_rating <- reactive({
      req(input$d1_rating, input$d2_rating, input$d3_rating,
          input$d4_rating, input$d5_rating)

      ratings <- c(input$d1_rating, input$d2_rating, input$d3_rating,
                   input$d4_rating, input$d5_rating)

      if ("High" %in% ratings) {
        "High"
      } else if ("Some concerns" %in% ratings) {
        "Some concerns"
      } else {
        "Low"
      }
    })

    output$overall_rating <- renderText({
      rating <- overall_rating()

      color <- switch(rating,
        "Low" = "success",
        "Some concerns" = "warning",
        "High" = "danger",
        "secondary"
      )

      paste0("<span class='badge bg-", color, "'>", rating, "</span>")
    })
    outputOptions(output, "overall_rating", suspendWhenHidden = FALSE)

    # Save assessment
    observeEvent(input$btn_save_assessment, {
      req(input$study_select)

      # Create assessment entry
      assessment <- data.frame(
        study_id = input$study_select,
        domain = c("D1", "D2", "D3", "D4", "D5", "Overall"),
        domain_name = c(
          "Randomization",
          "Deviations",
          "Missing data",
          "Measurement",
          "Selection",
          "Overall"
        ),
        rating = c(
          input$d1_rating,
          input$d2_rating,
          input$d3_rating,
          input$d4_rating,
          input$d5_rating,
          overall_rating()
        ),
        notes = c(
          input$d1_notes,
          input$d2_notes,
          input$d3_notes,
          input$d4_notes,
          input$d5_notes,
          ""
        ),
        stringsAsFactors = FALSE
      )

      # Update rob_data
      current_rob <- rob_data()
      if (is.null(current_rob)) {
        rob_data(assessment)
      } else {
        # Remove existing assessments for this study
        current_rob <- current_rob[current_rob$study_id != input$study_select, ]
        rob_data(rbind(current_rob, assessment))
      }

      # Store in reactive values
      rv$rob_assessments <- rob_data()

      showNotification(
        paste("Assessment saved for", input$study_select),
        type = "message"
      )
    })

    # Create template
    observeEvent(input$btn_create_template, {
      req(rv$data)

      tryCatch({
        studies <- unique(rv$data$study_id)
        template <- create_rob2_template(studies)

        filename <- paste0("outputs/rob2_template_",
                          format(Sys.time(), "%Y%m%d_%H%M%S"),
                          ".csv")
        write.csv(template, filename, row.names = FALSE)

        showNotification(
          paste("Template created:", filename),
          type = "message",
          duration = 10
        )

      }, error = function(e) {
        showNotification(
          paste("Error creating template:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Upload assessments
    observeEvent(input$rob_file, {
      req(input$rob_file)

      tryCatch({
        file_ext <- tools::file_ext(input$rob_file$name)

        if (file_ext == "csv") {
          uploaded_rob <- read.csv(input$rob_file$datapath, stringsAsFactors = FALSE)
        } else if (file_ext %in% c("xlsx", "xls")) {
          uploaded_rob <- readxl::read_excel(input$rob_file$datapath)
        }

        rob_data(uploaded_rob)
        rv$rob_assessments <- uploaded_rob

        showNotification(
          paste("Loaded", length(unique(uploaded_rob$study_id)), "study assessments"),
          type = "message"
        )

      }, error = function(e) {
        showNotification(
          paste("Error loading file:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Summary table
    output$rob_summary_table <- renderDT({
      req(rob_data())

      # Get overall ratings only
      summary <- rob_data()[rob_data()$domain == "Overall", ]

      # Color code
      datatable(
        summary[, c("study_id", "rating")],
        colnames = c("Study", "Overall Risk of Bias"),
        options = list(
          pageLength = 25,
          dom = 't'
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          'rating',
          backgroundColor = styleEqual(
            c("Low", "Some concerns", "High"),
            c('#d4edda', '#fff3cd', '#f8d7da')
          )
        )
    })

    # Traffic light plot
    output$traffic_light_plot <- renderPlot({
      req(rob_data(), input$show_traffic_light)

      tryCatch({
        rob2_traffic_light(rob_data())
      }, error = function(e) {
        plot.new()
        text(0.5, 0.5, paste("Error creating plot:", e$message))
      })
    })

    # Sensitivity analysis
    observeEvent(input$btn_sensitivity, {
      req(rv$pairwise_results, rob_data())

      tryCatch({
        # Get latest meta-analysis result
        if (length(rv$pairwise_results) == 0) {
          showNotification(
            "Please run a meta-analysis first",
            type = "warning"
          )
          return()
        }

        ma <- rv$pairwise_results[[1]]

        # Run sensitivity analysis
        result <- rob2_sensitivity_analysis(
          ma = ma,
          rob_data = rob_data(),
          exclude_risk = input$exclude_risk_level
        )

        # Store result
        rv$rob_sensitivity <- result

        showNotification(
          "Sensitivity analysis complete",
          type = "message"
        )

      }, error = function(e) {
        showNotification(
          paste("Error in sensitivity analysis:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Sensitivity results text
    output$sensitivity_results <- renderPrint({
      req(rv$rob_sensitivity)

      result <- rv$rob_sensitivity

      cat("SENSITIVITY ANALYSIS BY RISK OF BIAS\n")
      cat("=====================================\n\n")

      cat("Original (all studies):\n")
      cat(sprintf("  k = %d studies\n", result$original$k))
      cat(sprintf("  Pooled effect: %.3f (95%% CI: %.3f to %.3f)\n",
                  result$original$TE.random,
                  result$original$lower.random,
                  result$original$upper.random))
      cat(sprintf("  Heterogeneity: I² = %.1f%%, τ² = %.3f\n",
                  result$original$I2, result$original$tau2))

      cat("\nAdjusted (excluding", input$exclude_risk_level, "studies):\n")
      cat(sprintf("  k = %d studies\n", result$adjusted$k))
      cat(sprintf("  Pooled effect: %.3f (95%% CI: %.3f to %.3f)\n",
                  result$adjusted$TE.random,
                  result$adjusted$lower.random,
                  result$adjusted$upper.random))
      cat(sprintf("  Heterogeneity: I² = %.1f%%, τ² = %.3f\n",
                  result$adjusted$I2, result$adjusted$tau2))

      cat("\nInterpretation:\n")
      if (abs(result$original$TE.random - result$adjusted$TE.random) < 0.1) {
        cat("  ✓ Results are robust to risk of bias exclusion\n")
      } else {
        cat("  ⚠ Results change substantially when excluding high-risk studies\n")
        cat("  Consider interpreting with caution\n")
      }
    })

    # Sensitivity forest plot
    output$sensitivity_forest_plot <- renderPlot({
      req(rv$rob_sensitivity)

      result <- rv$rob_sensitivity

      # Create comparison plot
      par(mfrow = c(2, 1))

      # Original
      meta::forest(result$original,
                   main = "Original (all studies)",
                   colgap.forest.left = "1cm")

      # Adjusted
      meta::forest(result$adjusted,
                   main = paste("Adjusted (excluding", input$exclude_risk_level, ")"),
                   colgap.forest.left = "1cm")
    })

    # Export assessments
    observeEvent(input$btn_export_rob, {
      req(rob_data())

      tryCatch({
        filename <- paste0("outputs/rob2_assessments_",
                          format(Sys.time(), "%Y%m%d_%H%M%S"),
                          ".csv")
        write.csv(rob_data(), filename, row.names = FALSE)

        showNotification(
          paste("Assessments exported:", filename),
          type = "message",
          duration = 10
        )

      }, error = function(e) {
        showNotification(
          paste("Error exporting:", e$message),
          type = "error"
        )
      })
    })

    return(reactive(rob_data()))
  })
}
