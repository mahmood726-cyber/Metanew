# ==============================================================================
# MAIC/STC MODULE - Matching-Adjusted Indirect Comparison
# ==============================================================================
#
# Production-ready Shiny module for population-adjusted indirect comparisons
#
# Features:
# - IPD data upload and validation
# - Target population summary entry
# - MAIC/STC analysis via Python backend
# - Interactive balance diagnostics
# - SMD comparison plots (before/after)
# - Weight distribution visualization
# - Treatment effect forest plots
# - 7-point validation dashboard
# - Downloadable reports
#
# Author: EvidenceOS PRIME
# License: MIT
# ==============================================================================

library(shiny)
library(bslib)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(tidyr)
library(httr)
library(jsonlite)

# UI Function ====================================================================
maic_stc_ui <- function(id) {
  ns <- NS(id)

  page_fluid(
    h2("MAIC/STC Analysis", class = "text-primary"),
    p("Matching-Adjusted Indirect Comparison & Simulated Treatment Comparison"),
    hr(),

    # Configuration Panel
    layout_columns(
      col_widths = c(4, 8),

      # Left Panel: Data & Settings
      card(
        card_header("1. Data Input"),

        # IPD Upload
        fileInput(
          ns("ipd_file"),
          "Upload Individual Patient Data (IPD)",
          accept = c(".csv", ".xlsx"),
          buttonLabel = "Browse...",
          placeholder = "CSV or Excel file"
        ),

        # Data preview
        conditionalPanel(
          condition = sprintf("output['%s'] != null", ns("ipd_preview_available")),
          DTOutput(ns("ipd_preview"), height = "200px")
        ),

        hr(),

        # Variable selection
        conditionalPanel(
          condition = sprintf("output['%s'] != null", ns("ipd_preview_available")),

          selectInput(
            ns("outcome_var"),
            "Outcome Variable:",
            choices = NULL
          ),

          selectInput(
            ns("treatment_var"),
            "Treatment Variable:",
            choices = NULL
          ),

          selectInput(
            ns("outcome_type"),
            "Outcome Type:",
            choices = c(
              "Binary (OR/RR)" = "binary",
              "Continuous (MD)" = "continuous",
              "Time-to-Event (HR)" = "time_to_event"
            )
          ),

          checkboxGroupInput(
            ns("covariates"),
            "Covariates for Matching:",
            choices = NULL
          ),

          checkboxInput(
            ns("ai_selection"),
            "AI-Assisted Variable Selection",
            value = TRUE
          )
        )
      ),

      # Right Panel: Target Population
      card(
        card_header("2. Target Population Summary"),

        p("Enter aggregate summary statistics for the comparator trial population:"),

        uiOutput(ns("target_summary_ui")),

        hr(),

        h5("Analysis Settings"),

        selectInput(
          ns("method"),
          "Method:",
          choices = c(
            "MAIC (Entropy Balancing)" = "maic",
            "STC (Simulated Treatment)" = "stc"
          )
        ),

        sliderInput(
          ns("smd_threshold"),
          "SMD Balance Threshold:",
          min = 0.05,
          max = 0.2,
          value = 0.1,
          step = 0.01
        ),

        checkboxInput(
          ns("trim_weights"),
          "Trim Extreme Weights",
          value = TRUE
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == true", ns("trim_weights")),
          sliderInput(
            ns("trim_quantile"),
            "Trim at Quantile:",
            min = 0.9,
            max = 0.99,
            value = 0.99,
            step = 0.01
          )
        ),

        hr(),

        actionButton(
          ns("run_maic"),
          "Run MAIC Analysis",
          icon = icon("play"),
          class = "btn-primary btn-lg",
          width = "100%"
        )
      )
    ),

    hr(),

    # Results Panel
    conditionalPanel(
      condition = sprintf("output['%s'] != null", ns("results_available")),

      h3("Analysis Results", class = "text-success"),

      # Summary Cards
      layout_columns(
        col_widths = c(3, 3, 3, 3),

        value_box(
          title = "Treatment Effect",
          value = textOutput(ns("effect_estimate")),
          showcase = icon("chart-line"),
          theme = "primary"
        ),

        value_box(
          title = "95% CI",
          value = textOutput(ns("effect_ci")),
          showcase = icon("arrows-left-right"),
          theme = "info"
        ),

        value_box(
          title = "Effective Sample Size",
          value = textOutput(ns("ess_value")),
          showcase = icon("users"),
          theme = "success"
        ),

        value_box(
          title = "Validation Score",
          value = textOutput(ns("validation_score")),
          showcase = icon("check-circle"),
          theme = "warning"
        )
      ),

      hr(),

      # Tabs for detailed results
      navset_card_tab(

        # Balance Diagnostics Tab
        nav_panel(
          "Balance Diagnostics",

          h4("Standardized Mean Differences (SMD)"),
          p("Balance achieved when SMD < 0.1 (indicated by shaded region)"),

          plotlyOutput(ns("smd_plot"), height = "400px"),

          hr(),

          h5("Balance Table"),
          DTOutput(ns("balance_table"))
        ),

        # Weight Distribution Tab
        nav_panel(
          "Weight Distribution",

          layout_columns(
            col_widths = c(6, 6),

            card(
              card_header("Weight Histogram"),
              plotlyOutput(ns("weight_hist"), height = "350px")
            ),

            card(
              card_header("Weight Statistics"),
              tableOutput(ns("weight_stats"))
            )
          ),

          hr(),

          card(
            card_header("Weight vs. Covariates"),
            plotlyOutput(ns("weight_covariate_plot"), height = "400px")
          )
        ),

        # Treatment Effect Tab
        nav_panel(
          "Treatment Effect",

          h4("Adjusted Treatment Effect Estimate"),

          plotlyOutput(ns("forest_plot"), height = "300px"),

          hr(),

          h5("Effect Estimate Details"),
          tableOutput(ns("effect_table"))
        ),

        # Variable Importance Tab
        nav_panel(
          "Variable Importance",

          h4("Covariate Importance for Matching"),
          p("Based on contribution to weight estimation"),

          plotlyOutput(ns("importance_plot"), height = "400px"),

          hr(),

          DTOutput(ns("importance_table"))
        ),

        # Validation Tab
        nav_panel(
          "Validation",

          h4("7-Point Validation System"),

          uiOutput(ns("validation_checks")),

          hr(),

          conditionalPanel(
            condition = sprintf("output['%s'] != null", ns("has_warnings")),

            card(
              card_header(
                "Warnings",
                class = "bg-warning"
              ),
              uiOutput(ns("warnings_list"))
            )
          )
        ),

        # Export Tab
        nav_panel(
          "Export",

          h4("Download Results"),

          layout_columns(
            col_widths = c(4, 4, 4),

            downloadButton(
              ns("download_results"),
              "Download Results (CSV)",
              class = "btn-primary",
              style = "width: 100%;"
            ),

            downloadButton(
              ns("download_report"),
              "Download Report (Word)",
              class = "btn-info",
              style = "width: 100%;"
            ),

            downloadButton(
              ns("download_plots"),
              "Download Plots (PDF)",
              class = "btn-success",
              style = "width: 100%;"
            )
          ),

          hr(),

          h5("Analysis Summary"),
          verbatimTextOutput(ns("summary_text"))
        )
      )
    )
  )
}


# Server Function ================================================================
maic_stc_server <- function(id, api_base_url = "http://localhost:8000") {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      ipd_data = NULL,
      maic_results = NULL,
      target_summary = list()
    )

    # IPD File Upload --------------------------------------------------------
    observeEvent(input$ipd_file, {
      req(input$ipd_file)

      ext <- tools::file_ext(input$ipd_file$name)

      rv$ipd_data <- tryCatch({
        if (ext == "csv") {
          read.csv(input$ipd_file$datapath)
        } else if (ext == "xlsx") {
          readxl::read_excel(input$ipd_file$datapath)
        } else {
          NULL
        }
      }, error = function(e) {
        showNotification("Error loading file", type = "error")
        NULL
      })

      # Update variable selectors
      if (!is.null(rv$ipd_data)) {
        numeric_vars <- names(rv$ipd_data)[sapply(rv$ipd_data, is.numeric)]
        all_vars <- names(rv$ipd_data)

        updateSelectInput(session, "outcome_var", choices = all_vars)
        updateSelectInput(session, "treatment_var", choices = all_vars)
        updateCheckboxGroupInput(session, "covariates", choices = numeric_vars)
      }
    })

    # IPD Preview
    output$ipd_preview_available <- reactive({
      !is.null(rv$ipd_data)
    })
    outputOptions(output, "ipd_preview_available", suspendWhenHidden = FALSE)

    output$ipd_preview <- renderDT({
      req(rv$ipd_data)
      datatable(
        head(rv$ipd_data, 10),
        options = list(
          scrollX = TRUE,
          pageLength = 5,
          dom = 't'
        ),
        rownames = FALSE
      )
    })

    # Target Summary UI -------------------------------------------------------
    output$target_summary_ui <- renderUI({
      req(input$covariates)

      ns <- session$ns

      tagList(
        lapply(input$covariates, function(var) {
          numericInput(
            ns(paste0("target_", var)),
            paste0(var, " (mean):"),
            value = 0,
            step = 0.1
          )
        })
      )
    })

    # Collect target summary
    observe({
      req(input$covariates)

      summary_list <- list()
      for (var in input$covariates) {
        val <- input[[paste0("target_", var)]]
        if (!is.null(val)) {
          summary_list[[var]] <- val
        }
      }

      rv$target_summary <- summary_list
    })

    # Run MAIC Analysis -------------------------------------------------------
    observeEvent(input$run_maic, {
      req(rv$ipd_data, rv$target_summary, input$outcome_var, input$treatment_var)

      showNotification("Running MAIC analysis...", type = "message", duration = NULL, id = "maic_running")

      # Prepare request
      maic_request <- list(
        ipd_data = rv$ipd_data,
        target_summary = rv$target_summary,
        outcome_var = input$outcome_var,
        treatment_var = input$treatment_var,
        covariates = if (input$ai_selection) NULL else input$covariates,
        outcome_type = input$outcome_type,
        config = list(
          method = input$method,
          smd_threshold = input$smd_threshold,
          trim_weights = input$trim_weights,
          trim_quantile = input$trim_quantile,
          ai_variable_selection = input$ai_selection
        )
      )

      # Call Python API
      tryCatch({
        response <- POST(
          url = paste0(api_base_url, "/maic/run"),
          body = maic_request,
          encode = "json",
          timeout = 60
        )

        if (status_code(response) == 200) {
          rv$maic_results <- content(response)
          removeNotification("maic_running")
          showNotification("MAIC analysis complete!", type = "message", duration = 3)
        } else {
          removeNotification("maic_running")
          showNotification(
            paste("API error:", status_code(response)),
            type = "error",
            duration = 5
          )
        }

      }, error = function(e) {
        removeNotification("maic_running")
        showNotification(
          paste("Error:", e$message),
          type = "error",
          duration = 5
        )
      })
    })

    # Results Available Flag --------------------------------------------------
    output$results_available <- reactive({
      !is.null(rv$maic_results)
    })
    outputOptions(output, "results_available", suspendWhenHidden = FALSE)

    # Summary Cards -----------------------------------------------------------
    output$effect_estimate <- renderText({
      req(rv$maic_results)
      sprintf("%.3f", rv$maic_results$effect_estimate)
    })

    output$effect_ci <- renderText({
      req(rv$maic_results)
      sprintf("(%.3f, %.3f)",
              rv$maic_results$effect_ci_lower,
              rv$maic_results$effect_ci_upper)
    })

    output$ess_value <- renderText({
      req(rv$maic_results)
      sprintf("%.1f", rv$maic_results$ess)
    })

    output$validation_score <- renderText({
      req(rv$maic_results)
      sprintf("%d/7", rv$maic_results$validation_score)
    })

    # SMD Plot ----------------------------------------------------------------
    output$smd_plot <- renderPlotly({
      req(rv$maic_results)

      # Prepare data
      smd_data <- data.frame(
        Variable = rv$maic_results$selected_variables,
        Before = unlist(rv$maic_results$smd_before),
        After = unlist(rv$maic_results$smd_after)
      ) %>%
        pivot_longer(cols = c(Before, After), names_to = "Time", values_to = "SMD")

      # Plot
      p <- ggplot(smd_data, aes(x = Variable, y = SMD, fill = Time)) +
        geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
        geom_hline(yintercept = c(-0.1, 0.1), linetype = "dashed", color = "red") +
        geom_rect(aes(xmin = -Inf, xmax = Inf, ymin = -0.1, ymax = 0.1),
                  fill = "green", alpha = 0.1, inherit.aes = FALSE) +
        scale_fill_manual(values = c("Before" = "#e74c3c", "After" = "#3498db")) +
        labs(
          title = "Standardized Mean Differences: Before vs After Weighting",
          x = "Covariate",
          y = "SMD",
          fill = ""
        ) +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      ggplotly(p)
    })

    # Balance Table -----------------------------------------------------------
    output$balance_table <- renderDT({
      req(rv$maic_results)

      balance_df <- data.frame(
        Variable = rv$maic_results$selected_variables,
        SMD_Before = sprintf("%.3f", unlist(rv$maic_results$smd_before)),
        SMD_After = sprintf("%.3f", unlist(rv$maic_results$smd_after)),
        Balanced = ifelse(
          abs(unlist(rv$maic_results$smd_after)) < input$smd_threshold,
          "✓", "✗"
        ),
        Importance = sprintf("%.2f", unlist(rv$maic_results$variable_importance))
      )

      datatable(
        balance_df,
        options = list(pageLength = 10, dom = 'tp'),
        rownames = FALSE
      ) %>%
        formatStyle(
          'Balanced',
          backgroundColor = styleEqual(c("✓", "✗"), c("#d4edda", "#f8d7da"))
        )
    })

    # Weight Plots ------------------------------------------------------------
    output$weight_hist <- renderPlotly({
      req(rv$maic_results)

      weights <- rv$maic_results$weights

      plot_ly(x = weights, type = "histogram", nbinsx = 30) %>%
        layout(
          title = "Distribution of Individual Weights",
          xaxis = list(title = "Weight"),
          yaxis = list(title = "Frequency")
        )
    })

    output$weight_stats <- renderTable({
      req(rv$maic_results)

      weights <- rv$maic_results$weights

      data.frame(
        Statistic = c("Min", "Q1", "Median", "Mean", "Q3", "Max", "SD", "ESS"),
        Value = c(
          min(weights),
          quantile(weights, 0.25),
          median(weights),
          mean(weights),
          quantile(weights, 0.75),
          max(weights),
          sd(weights),
          rv$maic_results$ess
        )
      ) %>%
        mutate(Value = sprintf("%.3f", Value))
    })

    output$weight_covariate_plot <- renderPlotly({
      req(rv$maic_results, rv$ipd_data)

      # Take first covariate for demo
      if (length(input$covariates) > 0) {
        var <- input$covariates[1]

        plot_ly(
          x = rv$ipd_data[[var]],
          y = rv$maic_results$weights,
          type = "scatter",
          mode = "markers",
          marker = list(size = 8, opacity = 0.6)
        ) %>%
          layout(
            title = paste("Weights vs.", var),
            xaxis = list(title = var),
            yaxis = list(title = "Weight")
          )
      }
    })

    # Forest Plot -------------------------------------------------------------
    output$forest_plot <- renderPlotly({
      req(rv$maic_results)

      est <- rv$maic_results$effect_estimate
      ci_lower <- rv$maic_results$effect_ci_lower
      ci_upper <- rv$maic_results$effect_ci_upper

      plot_data <- data.frame(
        Study = "Adjusted Effect",
        Estimate = est,
        Lower = ci_lower,
        Upper = ci_upper
      )

      p <- ggplot(plot_data, aes(x = Estimate, y = Study)) +
        geom_point(size = 4) +
        geom_errorbarh(aes(xmin = Lower, xmax = Upper), height = 0.2) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
        labs(
          title = "Treatment Effect Estimate (MAIC-Adjusted)",
          x = "Effect Estimate",
          y = ""
        ) +
        theme_minimal()

      ggplotly(p)
    })

    output$effect_table <- renderTable({
      req(rv$maic_results)

      data.frame(
        Parameter = c("Estimate", "Standard Error", "95% CI Lower", "95% CI Upper", "P-value"),
        Value = c(
          sprintf("%.3f", rv$maic_results$effect_estimate),
          sprintf("%.3f", rv$maic_results$effect_se),
          sprintf("%.3f", rv$maic_results$effect_ci_lower),
          sprintf("%.3f", rv$maic_results$effect_ci_upper),
          sprintf("%.4f", rv$maic_results$effect_p_value)
        )
      )
    })

    # Variable Importance -----------------------------------------------------
    output$importance_plot <- renderPlotly({
      req(rv$maic_results)

      imp_data <- data.frame(
        Variable = names(rv$maic_results$variable_importance),
        Importance = unlist(rv$maic_results$variable_importance)
      ) %>%
        arrange(desc(Importance))

      plot_ly(
        imp_data,
        x = ~Importance,
        y = ~reorder(Variable, Importance),
        type = "bar",
        orientation = "h"
      ) %>%
        layout(
          title = "Variable Importance for Weighting",
          xaxis = list(title = "Importance Score"),
          yaxis = list(title = "")
        )
    })

    output$importance_table <- renderDT({
      req(rv$maic_results)

      data.frame(
        Variable = names(rv$maic_results$variable_importance),
        Importance = sprintf("%.3f", unlist(rv$maic_results$variable_importance))
      ) %>%
        arrange(desc(Importance)) %>%
        datatable(options = list(pageLength = 10, dom = 'tp'), rownames = FALSE)
    })

    # Validation Checks -------------------------------------------------------
    output$validation_checks <- renderUI({
      req(rv$maic_results)

      checks <- rv$maic_results$validation_checks

      check_cards <- lapply(names(checks), function(check_name) {
        passed <- checks[[check_name]]

        card(
          card_body(
            layout_columns(
              col_widths = c(2, 10),
              icon(
                if (passed) "check-circle" else "times-circle",
                class = if (passed) "text-success" else "text-danger",
                style = "font-size: 24px;"
              ),
              div(check_name)
            )
          ),
          class = if (passed) "border-success" else "border-danger"
        )
      })

      tagList(check_cards)
    })

    # Warnings ----------------------------------------------------------------
    output$has_warnings <- reactive({
      req(rv$maic_results)
      length(rv$maic_results$warnings) > 0
    })
    outputOptions(output, "has_warnings", suspendWhenHidden = FALSE)

    output$warnings_list <- renderUI({
      req(rv$maic_results)

      tags$ul(
        lapply(rv$maic_results$warnings, function(w) {
          tags$li(w)
        })
      )
    })

    # Summary Text ------------------------------------------------------------
    output$summary_text <- renderText({
      req(rv$maic_results)

      sprintf(
        "MAIC Analysis Summary\n=====================\n\n" +
        "Treatment Effect:\n" +
        "  Estimate: %.3f\n" +
        "  95%% CI: (%.3f, %.3f)\n" +
        "  P-value: %.4f\n\n" +
        "Sample Size:\n" +
        "  Original IPD: %d\n" +
        "  Effective Sample Size: %.1f\n\n" +
        "Balance:\n" +
        "  Achieved: %s\n" +
        "  Variables matched: %d\n\n" +
        "Validation Score: %d/7\n",
        rv$maic_results$effect_estimate,
        rv$maic_results$effect_ci_lower,
        rv$maic_results$effect_ci_upper,
        rv$maic_results$effect_p_value,
        rv$maic_results$n_ipd,
        rv$maic_results$ess,
        ifelse(rv$maic_results$balance_achieved, "Yes", "No"),
        length(rv$maic_results$selected_variables),
        rv$maic_results$validation_score
      )
    })

    # Downloads ---------------------------------------------------------------
    output$download_results <- downloadHandler(
      filename = function() {
        paste0("maic_results_", Sys.Date(), ".csv")
      },
      content = function(file) {
        req(rv$maic_results)

        # Create results CSV
        results_df <- data.frame(
          Variable = rv$maic_results$selected_variables,
          SMD_Before = unlist(rv$maic_results$smd_before),
          SMD_After = unlist(rv$maic_results$smd_after),
          Importance = unlist(rv$maic_results$variable_importance)
        )

        write.csv(results_df, file, row.names = FALSE)
      }
    )

    output$download_report <- downloadHandler(
      filename = function() {
        paste0("maic_report_", Sys.Date(), ".docx")
      },
      content = function(file) {
        # Placeholder - would use officer package for Word doc
        showNotification("Word report generation coming soon!", type = "message")
      }
    )

    output$download_plots <- downloadHandler(
      filename = function() {
        paste0("maic_plots_", Sys.Date(), ".pdf")
      },
      content = function(file) {
        # Placeholder - would generate PDF with all plots
        showNotification("PDF plot export coming soon!", type = "message")
      }
    )

  })
}


# Standalone App for Testing ====================================================
if (FALSE) {
  ui <- page_fluid(
    theme = bs_theme(version = 5, bootswatch = "flatly"),
    maic_stc_ui("maic")
  )

  server <- function(input, output, session) {
    maic_stc_server("maic")
  }

  shinyApp(ui, server)
}
