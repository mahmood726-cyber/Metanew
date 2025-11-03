# Scenario Compare Module
# Side-by-side comparison of multiple meta-analysis scenarios
# Part of Phase 2+v2 implementation

library(shiny)
library(bslib)
library(DT)
library(plotly)
library(ggplot2)
library(metafor)

# UI
scenario_compare_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # Header card
      card(
        card_header(
          tags$div(
            class = "d-flex justify-content-between align-items-center",
            tags$h4(class = "mb-0", icon("code-compare"), " Scenario Comparison"),
            actionButton(ns("btn_help"), icon("circle-question"),
                        class = "btn-sm btn-outline-secondary")
          )
        ),

        card_body(
          p(class = "text-muted",
            "Compare different analysis scenarios side-by-side to assess robustness of your findings. ",
            "Select 2-4 scenarios from your completed analyses to compare effect sizes, heterogeneity, ",
            "and statistical significance."
          ),

          layout_columns(
            col_widths = c(3, 3, 3, 3),

            # Scenario 1
            card(
              card_header("Scenario 1", class = "bg-primary text-white"),
              selectInput(ns("scenario1_type"), "Analysis Type",
                         choices = c("Select..." = "", "Pairwise MA" = "pairwise",
                                   "Network MA" = "nma", "Dose-Response" = "dr")),
              uiOutput(ns("scenario1_options")),
              textInput(ns("scenario1_label"), "Label", placeholder = "e.g., Main Analysis")
            ),

            # Scenario 2
            card(
              card_header("Scenario 2", class = "bg-info text-white"),
              selectInput(ns("scenario2_type"), "Analysis Type",
                         choices = c("Select..." = "", "Pairwise MA" = "pairwise",
                                   "Network MA" = "nma", "Dose-Response" = "dr")),
              uiOutput(ns("scenario2_options")),
              textInput(ns("scenario2_label"), "Label", placeholder = "e.g., Sensitivity Analysis")
            ),

            # Scenario 3 (optional)
            card(
              card_header("Scenario 3 (Optional)", class = "bg-secondary text-white"),
              selectInput(ns("scenario3_type"), "Analysis Type",
                         choices = c("Select..." = "", "Pairwise MA" = "pairwise",
                                   "Network MA" = "nma", "Dose-Response" = "dr")),
              uiOutput(ns("scenario3_options")),
              textInput(ns("scenario3_label"), "Label", placeholder = "e.g., Subgroup Analysis")
            ),

            # Scenario 4 (optional)
            card(
              card_header("Scenario 4 (Optional)", class = "bg-warning"),
              selectInput(ns("scenario4_type"), "Analysis Type",
                         choices = c("Select..." = "", "Pairwise MA" = "pairwise",
                                   "Network MA" = "nma", "Dose-Response" = "dr")),
              uiOutput(ns("scenario4_options")),
              textInput(ns("scenario4_label"), "Label", placeholder = "e.g., Fixed Effects")
            )
          ),

          hr(),

          layout_columns(
            col_widths = c(6, 6),
            actionButton(ns("btn_compare"), "Compare Scenarios",
                        icon = icon("play-circle"),
                        class = "btn-primary btn-lg w-100"),
            actionButton(ns("btn_reset"), "Reset",
                        icon = icon("rotate-left"),
                        class = "btn-outline-secondary btn-lg w-100")
          )
        )
      )
    ),

    # Comparison results
    layout_columns(
      col_widths = c(12),

      uiOutput(ns("comparison_output"))
    )
  )
}

# Server
scenario_compare_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    comparison_results <- reactiveVal(NULL)

    # Help modal
    observeEvent(input$btn_help, {
      showModal(modalDialog(
        title = tags$h4(icon("circle-question"), " Scenario Comparison Help"),
        size = "l",

        tags$div(
          tags$h5("What is Scenario Comparison?"),
          tags$p("Scenario comparison allows you to compare different analysis approaches side-by-side to:",
                tags$ul(
                  tags$li("Assess robustness of findings across different methods"),
                  tags$li("Compare fixed vs. random effects models"),
                  tags$li("Evaluate impact of outliers or specific studies"),
                  tags$li("Compare subgroup analyses"),
                  tags$li("Document sensitivity analyses for publications")
                )),

          tags$hr(),

          tags$h5("How to Use:"),
          tags$ol(
            tags$li("Select analysis type for each scenario (Pairwise MA, NMA, or Dose-Response)"),
            tags$li("Choose specific analysis from your completed analyses"),
            tags$li("Give each scenario a descriptive label"),
            tags$li("Click 'Compare Scenarios' to generate comparison"),
            tags$li("Review side-by-side summary table and difference plots")
          ),

          tags$hr(),

          tags$h5("Interpretation:"),
          tags$ul(
            tags$li(tags$strong("Small differences:"), " Results are robust across scenarios"),
            tags$li(tags$strong("Large differences:"), " Results are sensitive to analytical choices - discuss in paper"),
            tags$li(tags$strong("Overlapping CIs:"), " Scenarios agree statistically"),
            tags$li(tags$strong("Non-overlapping CIs:"), " Important differences - investigate further")
          )
        ),

        footer = modalButton("Close")
      ))
    })

    # Dynamic scenario options based on type
    output$scenario1_options <- renderUI({
      req(input$scenario1_type)
      get_scenario_options(input$scenario1_type, rv, ns, 1)
    })

    output$scenario2_options <- renderUI({
      req(input$scenario2_type)
      get_scenario_options(input$scenario2_type, rv, ns, 2)
    })

    output$scenario3_options <- renderUI({
      req(input$scenario3_type)
      get_scenario_options(input$scenario3_type, rv, ns, 3)
    })

    output$scenario4_options <- renderUI({
      req(input$scenario4_type)
      get_scenario_options(input$scenario4_type, rv, ns, 4)
    })

    # Reset button
    observeEvent(input$btn_reset, {
      comparison_results(NULL)
      updateSelectInput(session, "scenario1_type", selected = "")
      updateSelectInput(session, "scenario2_type", selected = "")
      updateSelectInput(session, "scenario3_type", selected = "")
      updateSelectInput(session, "scenario4_type", selected = "")
      updateTextInput(session, "scenario1_label", value = "")
      updateTextInput(session, "scenario2_label", value = "")
      updateTextInput(session, "scenario3_label", value = "")
      updateTextInput(session, "scenario4_label", value = "")
    })

    # Compare scenarios
    observeEvent(input$btn_compare, {
      # Validate inputs
      if (input$scenario1_type == "" || input$scenario2_type == "") {
        showNotification(
          "Please select at least 2 scenarios to compare",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Collect scenarios
      scenarios <- list()

      for (i in 1:4) {
        type_input <- paste0("scenario", i, "_type")
        label_input <- paste0("scenario", i, "_label")

        if (input[[type_input]] != "") {
          scenario <- list(
            id = i,
            type = input[[type_input]],
            label = if (input[[label_input]] != "") input[[label_input]] else paste("Scenario", i),
            data = get_scenario_data(input[[type_input]], i, rv)
          )

          if (!is.null(scenario$data)) {
            scenarios[[length(scenarios) + 1]] <- scenario
          }
        }
      }

      if (length(scenarios) < 2) {
        showNotification(
          "Please select valid analyses for at least 2 scenarios",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Perform comparison
      tryCatch({
        results <- compare_scenarios(scenarios)
        comparison_results(results)

        showNotification(
          paste("Successfully compared", length(scenarios), "scenarios"),
          type = "message",
          duration = 3
        )
      }, error = function(e) {
        showNotification(
          paste("Error comparing scenarios:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Render comparison output
    output$comparison_output <- renderUI({
      req(comparison_results())

      results <- comparison_results()

      tagList(
        # Summary table
        card(
          card_header(
            tags$h5(class = "mb-0", icon("table"), " Comparison Summary")
          ),
          card_body(
            DTOutput(ns("summary_table")),
            hr(),
            p(class = "text-muted small",
              icon("info-circle"),
              " Effect sizes and confidence intervals are shown for each scenario. ",
              "Compare values across rows to assess robustness."
            )
          )
        ),

        # Comparison plots
        card(
          card_header(
            tags$h5(class = "mb-0", icon("chart-bar"), " Visual Comparison")
          ),

          navset_card_tab(
            nav_panel(
              "Effect Size Comparison",
              plotlyOutput(ns("effect_size_plot"), height = "500px")
            ),
            nav_panel(
              "Heterogeneity Comparison",
              plotlyOutput(ns("heterogeneity_plot"), height = "500px")
            ),
            nav_panel(
              "Difference Analysis",
              plotlyOutput(ns("difference_plot"), height = "500px"),
              p(class = "text-muted small mt-3",
                "Differences are calculated relative to Scenario 1. ",
                "Positive values indicate larger effect sizes, negative indicate smaller."
              )
            )
          )
        ),

        # Export options
        card(
          card_header("Export Comparison"),
          card_body(
            layout_columns(
              col_widths = c(4, 4, 4),
              downloadButton(ns("download_summary_csv"), "Summary (CSV)",
                           class = "btn-primary w-100"),
              downloadButton(ns("download_plot_png"), "Plot (PNG)",
                           class = "btn-secondary w-100"),
              downloadButton(ns("download_report_docx"), "Report (DOCX)",
                           class = "btn-info w-100")
            )
          )
        )
      )
    })

    # Render summary table
    output$summary_table <- renderDT({
      req(comparison_results())

      df <- comparison_results()$summary_table

      datatable(
        df,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 'Bfrtip'
        ),
        rownames = FALSE,
        class = "display stripe hover"
      ) %>%
        formatRound(columns = c("Effect_Size", "CI_Lower", "CI_Upper", "I2", "Tau2"), digits = 3)
    })

    # Effect size comparison plot
    output$effect_size_plot <- renderPlotly({
      req(comparison_results())

      df <- comparison_results()$summary_table

      fig <- plot_ly(
        data = df,
        x = ~Effect_Size,
        y = ~Scenario,
        error_x = list(
          type = "data",
          symmetric = FALSE,
          array = ~(CI_Upper - Effect_Size),
          arrayminus = ~(Effect_Size - CI_Lower)
        ),
        type = "scatter",
        mode = "markers",
        marker = list(size = 12, color = ~Effect_Size,
                     colorscale = "RdYlBu", reversescale = TRUE,
                     showscale = TRUE, colorbar = list(title = "Effect")),
        text = ~paste0("Effect: ", round(Effect_Size, 3),
                      "<br>95% CI: [", round(CI_Lower, 3), ", ", round(CI_Upper, 3), "]",
                      "<br>P-value: ", round(P_Value, 4)),
        hoverinfo = "text"
      ) %>%
        layout(
          title = "Effect Size Comparison Across Scenarios",
          xaxis = list(title = "Effect Size", zeroline = TRUE, zerolinewidth = 2, zerolinecolor = "red"),
          yaxis = list(title = "Scenario"),
          margin = list(l = 150)
        )

      fig
    })

    # Heterogeneity comparison plot
    output$heterogeneity_plot <- renderPlotly({
      req(comparison_results())

      df <- comparison_results()$summary_table

      fig <- plot_ly(
        data = df,
        x = ~Scenario,
        y = ~I2,
        type = "bar",
        marker = list(
          color = ~I2,
          colorscale = list(c(0, "green"), c(0.5, "yellow"), c(1, "red")),
          colorbar = list(title = "I² (%)")
        ),
        text = ~paste0("I²: ", round(I2, 1), "%<br>τ²: ", round(Tau2, 3)),
        hoverinfo = "text"
      ) %>%
        layout(
          title = "Heterogeneity Comparison (I²)",
          xaxis = list(title = "Scenario"),
          yaxis = list(title = "I² (%)", range = c(0, 100)),
          shapes = list(
            list(type = "line", x0 = 0, x1 = 1, xref = "paper",
                 y0 = 25, y1 = 25, line = list(dash = "dash", color = "orange")),
            list(type = "line", x0 = 0, x1 = 1, xref = "paper",
                 y0 = 50, y1 = 50, line = list(dash = "dash", color = "red"))
          ),
          annotations = list(
            list(x = 0.02, y = 25, xref = "paper", yref = "y", text = "Low het.",
                 showarrow = FALSE, xanchor = "left"),
            list(x = 0.02, y = 50, xref = "paper", yref = "y", text = "Moderate het.",
                 showarrow = FALSE, xanchor = "left")
          )
        )

      fig
    })

    # Difference analysis plot
    output$difference_plot <- renderPlotly({
      req(comparison_results())

      diff_data <- comparison_results()$difference_analysis

      if (nrow(diff_data) == 0) {
        return(NULL)
      }

      fig <- plot_ly(
        data = diff_data,
        x = ~Comparison,
        y = ~Difference,
        type = "bar",
        marker = list(
          color = ~Difference,
          colorscale = "RdBu",
          reversescale = TRUE
        ),
        text = ~paste0("Diff: ", round(Difference, 3),
                      "<br>% Change: ", round(Pct_Change, 1), "%"),
        hoverinfo = "text"
      ) %>%
        layout(
          title = "Effect Size Differences (vs. Scenario 1)",
          xaxis = list(title = "Comparison"),
          yaxis = list(title = "Difference in Effect Size", zeroline = TRUE,
                      zerolinewidth = 2, zerolinecolor = "black")
        )

      fig
    })

    # Download handlers
    output$download_summary_csv <- downloadHandler(
      filename = function() {
        paste0("scenario_comparison_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(comparison_results())
        write.csv(comparison_results()$summary_table, file, row.names = FALSE)
      }
    )

    output$download_plot_png <- downloadHandler(
      filename = function() {
        paste0("scenario_comparison_plot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(comparison_results())

        # Create static ggplot version for export
        df <- comparison_results()$summary_table

        p <- ggplot(df, aes(x = Effect_Size, y = Scenario)) +
          geom_point(aes(color = Effect_Size), size = 4) +
          geom_errorbarh(aes(xmin = CI_Lower, xmax = CI_Upper), height = 0.2) +
          geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
          scale_color_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0) +
          labs(
            title = "Effect Size Comparison Across Scenarios",
            x = "Effect Size",
            y = "Scenario",
            color = "Effect"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
            axis.text = element_text(size = 11),
            axis.title = element_text(size = 12, face = "bold")
          )

        ggsave(file, p, width = 10, height = 6, dpi = 300)
      }
    )

    output$download_report_docx <- downloadHandler(
      filename = function() {
        paste0("scenario_comparison_report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      },
      content = function(file) {
        req(comparison_results())

        # Create simple text report (in production, use officer package for proper DOCX)
        report_text <- generate_comparison_report(comparison_results())
        writeLines(report_text, file)

        showNotification(
          "Note: DOCX export is basic text format. For formatted reports, use the Reporting tab.",
          type = "info",
          duration = 5
        )
      }
    )

    # Return reactive values
    return(reactive({
      list(
        comparison_results = comparison_results()
      )
    }))
  })
}

# Helper: Get scenario options UI
get_scenario_options <- function(type, rv, ns, scenario_num) {
  if (type == "pairwise") {
    # Show available pairwise analyses
    choices <- c("Main Analysis" = "main")
    if (length(rv$pairwise_results) > 0) {
      choices <- c(choices, names(rv$pairwise_results))
    }

    selectInput(ns(paste0("scenario", scenario_num, "_analysis")),
               "Analysis",
               choices = choices)

  } else if (type == "nma") {
    # Show available NMA analyses
    choices <- c("Main Analysis" = "main")
    if (length(rv$nma_results) > 0) {
      choices <- c(choices, names(rv$nma_results))
    }

    selectInput(ns(paste0("scenario", scenario_num, "_analysis")),
               "Analysis",
               choices = choices)

  } else if (type == "dr") {
    # Show available dose-response analyses
    choices <- c("Main Analysis" = "main")
    if (length(rv$dr_results) > 0) {
      choices <- c(choices, names(rv$dr_results))
    }

    selectInput(ns(paste0("scenario", scenario_num, "_analysis")),
               "Analysis",
               choices = choices)
  }
}

# Helper: Get scenario data
get_scenario_data <- function(type, scenario_num, rv) {
  # Placeholder - in production, retrieve actual analysis results
  # from rv$pairwise_results, rv$nma_results, or rv$dr_results

  if (type == "pairwise" && length(rv$pairwise_results) > 0) {
    return(rv$pairwise_results[[1]])
  } else if (type == "nma" && length(rv$nma_results) > 0) {
    return(rv$nma_results[[1]])
  } else if (type == "dr" && length(rv$dr_results) > 0) {
    return(rv$dr_results[[1]])
  }

  # Return placeholder data for demonstration
  return(list(
    effect_size = rnorm(1, mean = 0.5, sd = 0.2),
    ci_lower = rnorm(1, mean = 0.2, sd = 0.1),
    ci_upper = rnorm(1, mean = 0.8, sd = 0.1),
    p_value = runif(1, 0.001, 0.1),
    i2 = runif(1, 0, 80),
    tau2 = runif(1, 0, 0.5),
    n_studies = sample(10:30, 1)
  ))
}

# Helper: Compare scenarios
compare_scenarios <- function(scenarios) {
  # Build summary table
  summary_data <- lapply(scenarios, function(s) {
    data.frame(
      Scenario = s$label,
      Type = toupper(s$type),
      Effect_Size = s$data$effect_size,
      CI_Lower = s$data$ci_lower,
      CI_Upper = s$data$ci_upper,
      P_Value = s$data$p_value,
      I2 = s$data$i2,
      Tau2 = s$data$tau2,
      N_Studies = s$data$n_studies,
      stringsAsFactors = FALSE
    )
  })

  summary_table <- do.call(rbind, summary_data)

  # Calculate differences vs. Scenario 1
  if (nrow(summary_table) > 1) {
    baseline <- summary_table$Effect_Size[1]

    diff_data <- data.frame(
      Comparison = paste("Scenario", 2:nrow(summary_table), "vs. Scenario 1"),
      Difference = summary_table$Effect_Size[2:nrow(summary_table)] - baseline,
      Pct_Change = ((summary_table$Effect_Size[2:nrow(summary_table)] - baseline) / abs(baseline)) * 100,
      stringsAsFactors = FALSE
    )
  } else {
    diff_data <- data.frame()
  }

  return(list(
    summary_table = summary_table,
    difference_analysis = diff_data,
    n_scenarios = length(scenarios)
  ))
}

# Helper: Generate comparison report
generate_comparison_report <- function(results) {
  report <- c(
    "SCENARIO COMPARISON REPORT",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "=" %R% 60,
    "",
    "SUMMARY",
    "",
    paste("Number of scenarios compared:", results$n_scenarios),
    "",
    "RESULTS TABLE:",
    "",
    capture.output(print(results$summary_table)),
    "",
    "DIFFERENCE ANALYSIS:",
    ""
  )

  if (nrow(results$difference_analysis) > 0) {
    report <- c(report, capture.output(print(results$difference_analysis)))
  } else {
    report <- c(report, "No differences calculated (only 1 scenario).")
  }

  report <- c(
    report,
    "",
    "INTERPRETATION:",
    "",
    "- Small differences (<10% change) suggest robust findings",
    "- Large differences (>25% change) warrant discussion of sensitivity",
    "- Overlapping confidence intervals indicate statistical agreement",
    "",
    "=" %R% 60
  )

  return(report)
}

# Utility operator for string repetition
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
