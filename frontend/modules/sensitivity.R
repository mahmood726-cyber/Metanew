# Sensitivity Analysis Module - Enhanced with Scenario Compare
library(shiny)
library(bslib)
library(DT)
library(plotly)
library(ggplot2)
library(jsonlite)

sensitivity_ui <- function(id) {
  ns <- NS(id)

  layout_columns(
    col_widths = c(12),

    # Scenario Management Card
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex justify-content-between align-items-center",
        div(
          icon("sliders", class = "me-2"),
          "Sensitivity & Scenario Explorer"
        ),
        div(
          actionButton(ns("btn_save_scenario"), "Save Scenario",
                       class = "btn-sm btn-primary", icon = icon("save")),
          actionButton(ns("btn_load_scenario"), "Load Scenario",
                       class = "btn-sm btn-secondary ms-1", icon = icon("folder-open")),
          actionButton(ns("btn_compare"), "Compare Scenarios",
                       class = "btn-sm btn-info ms-1", icon = icon("columns"))
        )
      ),

      navset_card_tab(
        id = ns("sensitivity_tabs"),

        # Tab 1: Single Scenario
        nav_panel(
          title = "Sensitivity Analysis",
          icon = icon("filter"),
          layout_columns(
            col_widths = c(3, 9),
            card(
              card_header("Scenario Settings"),
              textInput(ns("scenario_name"), "Scenario Name",
                        value = "Base Case", placeholder = "e.g., High ROB Excluded"),
              hr(),
              h5("Filters"),
              checkboxGroupInput(ns("exclude_rob"), "Exclude Risk of Bias",
                                 choices = c("High", "Unclear", "Low")),
              sliderInput(ns("min_sample"), "Minimum Sample Size", 0, 1000, 0),
              sliderInput(ns("max_year"), "Max Publication Year", 1990, 2024, 2024),
              checkboxInput(ns("only_rct"), "RCTs Only", FALSE),
              hr(),
              h5("Analysis Options"),
              selectInput(ns("estimator"), "Pooling Method",
                          choices = c("REML", "DL", "FE"),
                          selected = "REML"),
              checkboxInput(ns("leave_one_out"), "Leave-One-Out Analysis", FALSE),
              hr(),
              actionButton(ns("btn_apply"), "Apply & Re-run",
                           class = "btn-success w-100", icon = icon("play"))
            ),
            card(
              card_header("Results"),
              uiOutput(ns("scenario_summary")),
              hr(),
              plotlyOutput(ns("sensitivity_forest"), height = "400px"),
              hr(),
              DTOutput(ns("sensitivity_table"))
            )
          )
        ),

        # Tab 2: Saved Scenarios
        nav_panel(
          title = "Saved Scenarios",
          icon = icon("folder"),
          card(
            card_header("Manage Saved Scenarios"),
            p(class = "text-muted",
              "Save and manage different analysis scenarios for comparison."),
            DTOutput(ns("saved_scenarios_table")),
            hr(),
            div(
              class = "d-flex gap-2",
              actionButton(ns("btn_delete_scenario"), "Delete Selected",
                           class = "btn-danger", icon = icon("trash")),
              actionButton(ns("btn_export_scenarios"), "Export All",
                           class = "btn-secondary", icon = icon("download"))
            )
          )
        ),

        # Tab 3: Leave-One-Out Analysis
        nav_panel(
          title = "Leave-One-Out",
          icon = icon("ban"),
          card(
            card_header(
              div(
                icon("ban", class = "me-2"),
                "Leave-One-Out Sensitivity Analysis"
              )
            ),
            p(class = "text-muted",
              "Assess the influence of individual studies by removing each one at a time. ",
              "Helps identify studies that disproportionately affect the pooled estimate."
            ),
            actionButton(
              ns("btn_run_loo"),
              "Run Leave-One-Out Analysis",
              icon = icon("play-circle"),
              class = "btn-primary btn-lg mb-3"
            ),
            uiOutput(ns("loo_summary")),
            hr(),
            h5("Influence Analysis Table"),
            p(class = "text-muted",
              "Shows the pooled effect estimate when each study is excluded."
            ),
            DTOutput(ns("loo_table")),
            hr(),
            h5("Influence Plot"),
            p(class = "text-muted",
              "Visualize how the pooled effect changes when excluding each study."
            ),
            plotOutput(ns("loo_plot"), height = "500px")
          )
        ),

        # Tab 4: Scenario Comparison
        nav_panel(
          title = "Compare",
          icon = icon("columns"),
          card(
            card_header("Scenario Comparison"),
            p(class = "text-muted mb-3",
              "Compare two saved scenarios side-by-side."),
            layout_columns(
              col_widths = c(6, 6),
              card(
                card_header("Select Scenarios to Compare"),
                selectInput(ns("compare_scenario_1"), "Scenario 1",
                            choices = NULL),
                selectInput(ns("compare_scenario_2"), "Scenario 2",
                            choices = NULL),
                actionButton(ns("btn_run_comparison"), "Compare",
                             class = "btn-primary w-100 mt-2", icon = icon("balance-scale"))
              ),
              card(
                card_header("Comparison Summary"),
                uiOutput(ns("comparison_summary"))
              )
            ),
            hr(),
            h5("Settings Differences"),
            DTOutput(ns("comparison_diff_table")),
            hr(),
            h5("Results Comparison"),
            layout_columns(
              col_widths = c(6, 6),
              card(
                card_header(textOutput(ns("scenario1_title"))),
                uiOutput(ns("scenario1_stats"))
              ),
              card(
                card_header(textOutput(ns("scenario2_title"))),
                uiOutput(ns("scenario2_stats"))
              )
            ),
            hr(),
            h5("Side-by-Side Forest Plots"),
            plotOutput(ns("comparison_forest_plots"), height = "600px")
          )
        )
      )
    )
  )
}

sensitivity_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values for scenarios
    saved_scenarios <- reactiveVal(list())
    current_scenario_results <- reactiveVal(NULL)

    # Filtered data based on current settings
    filtered_data <- reactive({
      req(rv$data)
      data <- rv$data

      # Apply filters
      if (length(input$exclude_rob) > 0 && "risk_of_bias" %in% names(data)) {
        data <- data[!data$risk_of_bias %in% input$exclude_rob, ]
      }

      if (input$min_sample > 0 && "n" %in% names(data)) {
        data <- data[data$n >= input$min_sample, ]
      }

      if ("year" %in% names(data)) {
        data <- data[data$year <= input$max_year, ]
      }

      if (input$only_rct && "study_type" %in% names(data)) {
        data <- data[data$study_type == "RCT", ]
      }

      data
    })

    # Apply sensitivity analysis
    observeEvent(input$btn_apply, {
      req(rv$data)

      filtered <- filtered_data()

      if (nrow(filtered) == 0) {
        showNotification("⚠ No studies match the selected criteria",
                         type = "warning", duration = 3)
        return()
      }

      # Run meta-analysis on filtered data
      tryCatch({
        # Assuming binary data with yi/sei columns
        if ("yi" %in% names(filtered) && "sei" %in% names(filtered)) {
          library(metafor)

          # BUG FIX #7: Better error handling for meta-analysis
          if (nrow(filtered) < 2) {
            showNotification(
              "⚠ Need at least 2 studies for meta-analysis. Current filters result in only 1 study.",
              type = "warning",
              duration = 5
            )
            return()
          }

          # Check for zero variance (all studies have same effect)
          if (sd(filtered$yi, na.rm = TRUE) < 1e-10) {
            showNotification(
              "⚠ All studies have identical effects. Meta-analysis not meaningful.",
              type = "warning",
              duration = 5
            )
            return()
          }

          ma_result <- rma(
            yi = filtered$yi,
            sei = filtered$sei,
            method = input$estimator,
            data = filtered
          )

          results <- list(
            scenario_name = input$scenario_name,
            n_studies = nrow(filtered),
            pooled_effect = ma_result$beta[1],
            se = ma_result$se,
            ci_lower = ma_result$ci.lb,
            ci_upper = ma_result$ci.ub,
            p_value = ma_result$pval,
            i2 = ma_result$I2,
            tau2 = ma_result$tau2,
            settings = list(
              exclude_rob = input$exclude_rob,
              min_sample = input$min_sample,
              max_year = input$max_year,
              only_rct = input$only_rct,
              estimator = input$estimator,
              leave_one_out = input$leave_one_out
            ),
            data = filtered,
            ma_object = ma_result,
            timestamp = Sys.time()
          )

          current_scenario_results(results)

          showNotification(
            sprintf("✓ Scenario '%s' - %d studies, Effect: %.3f [%.3f, %.3f]",
                    input$scenario_name, nrow(filtered),
                    ma_result$beta[1], ma_result$ci.lb, ma_result$ci.ub),
            type = "message",
            duration = 5
          )

        } else {
          showNotification("⚠ Data must have 'yi' and 'sei' columns for meta-analysis",
                           type = "warning", duration = 3)
        }

      }, error = function(e) {
        # BUG FIX #7 (continued): User-friendly error messages
        error_msg <- conditionMessage(e)

        if (grepl("singularity", error_msg, ignore.case = TRUE)) {
          user_msg <- "⚠ Meta-analysis failed: Studies have too little variation. Try fixed-effects model or different estimator."
        } else if (grepl("convergence", error_msg, ignore.case = TRUE)) {
          user_msg <- "⚠ Meta-analysis didn't converge. Try a different estimator (REML/DL/FE) or check your data."
        } else if (grepl("insufficient", error_msg, ignore.case = TRUE)) {
          user_msg <- "⚠ Insufficient data for meta-analysis. Need at least 2 studies with valid effect sizes."
        } else {
          user_msg <- paste("⚠ Meta-analysis error:", error_msg)
        }

        showNotification(user_msg, type = "error", duration = 7)
      })
    })

    # Scenario summary
    output$scenario_summary <- renderUI({
      req(current_scenario_results())
      res <- current_scenario_results()

      div(
        class = "p-3 bg-light rounded",
        h5(class = "mb-3", res$scenario_name),
        tags$table(
          class = "table table-sm",
          tags$tr(
            tags$td(strong("Studies:")),
            tags$td(res$n_studies)
          ),
          tags$tr(
            tags$td(strong("Pooled Effect:")),
            tags$td(sprintf("%.3f [%.3f, %.3f]", res$pooled_effect,
                            res$ci_lower, res$ci_upper))
          ),
          tags$tr(
            tags$td(strong("p-value:")),
            tags$td(sprintf("%.4f", res$p_value))
          ),
          tags$tr(
            tags$td(strong("I² (Heterogeneity):")),
            tags$td(sprintf("%.1f%%", res$i2))
          ),
          tags$tr(
            tags$td(strong("τ²:")),
            tags$td(sprintf("%.4f", res$tau2))
          )
        )
      )
    })

    # Sensitivity forest plot
    output$sensitivity_forest <- renderPlotly({
      req(current_scenario_results())
      res <- current_scenario_results()

      data <- res$data
      if (!"study_id" %in% names(data)) {
        data$study_id <- paste0("Study_", seq_len(nrow(data)))
      }

      p <- plot_ly(data, type = "scatter", mode = "markers") %>%
        add_trace(
          x = ~yi,
          y = ~study_id,
          error_x = list(
            type = "data",
            symmetric = FALSE,
            array = ~(yi + 1.96 * sei) - yi,
            arrayminus = ~yi - (yi - 1.96 * sei)
          ),
          marker = list(size = 8, color = "steelblue"),
          name = "Studies"
        ) %>%
        add_trace(
          x = c(res$pooled_effect, res$pooled_effect),
          y = c(0.5, nrow(data) + 0.5),
          mode = "lines",
          line = list(color = "red", dash = "dash", width = 2),
          name = "Pooled Effect"
        ) %>%
        layout(
          title = paste("Forest Plot:", res$scenario_name),
          xaxis = list(title = "Effect Size"),
          yaxis = list(title = ""),
          showlegend = TRUE
        )

      p
    })

    # Sensitivity table
    output$sensitivity_table <- renderDT({
      req(current_scenario_results())
      res <- current_scenario_results()

      data <- res$data
      if (!"study_id" %in% names(data)) {
        data$study_id <- paste0("Study_", seq_len(nrow(data)))
      }

      display_data <- data.frame(
        Study = data$study_id,
        Effect = sprintf("%.3f", data$yi),
        SE = sprintf("%.3f", data$sei),
        CI_95 = sprintf("[%.3f, %.3f]",
                        data$yi - 1.96 * data$sei,
                        data$yi + 1.96 * data$sei),
        stringsAsFactors = FALSE
      )

      datatable(
        display_data,
        options = list(pageLength = 10, dom = 'tp'),
        rownames = FALSE
      )
    })

    # Save scenario
    observeEvent(input$btn_save_scenario, {
      req(current_scenario_results())

      if (input$scenario_name == "") {
        showNotification("⚠ Please provide a scenario name",
                         type = "warning", duration = 3)
        return()
      }

      res <- current_scenario_results()

      # Add to saved scenarios
      scenarios <- saved_scenarios()
      scenario_id <- paste0("SCN_", format(Sys.time(), "%Y%m%d_%H%M%S"))

      scenarios[[scenario_id]] <- list(
        id = scenario_id,
        name = res$scenario_name,
        n_studies = res$n_studies,
        pooled_effect = res$pooled_effect,
        ci_lower = res$ci_lower,
        ci_upper = res$ci_upper,
        p_value = res$p_value,
        i2 = res$i2,
        tau2 = res$tau2,
        settings = res$settings,
        data = res$data,
        created_at = Sys.time()
      )

      saved_scenarios(scenarios)

      # Update comparison dropdowns
      scenario_choices <- sapply(scenarios, function(s) s$name)
      names(scenario_choices) <- names(scenarios)

      updateSelectInput(session, "compare_scenario_1", choices = scenario_choices)
      updateSelectInput(session, "compare_scenario_2", choices = scenario_choices)

      showNotification(sprintf("✓ Scenario '%s' saved", res$scenario_name),
                       type = "message", duration = 3)
    })

    # Load scenario
    observeEvent(input$btn_load_scenario, {
      scenarios <- saved_scenarios()

      if (length(scenarios) == 0) {
        showNotification("No saved scenarios",
                         type = "message", duration = 2)
        return()
      }

      showModal(modalDialog(
        title = "Load Scenario",
        selectInput(ns("load_scenario_select"), "Select Scenario",
                    choices = sapply(scenarios, function(s) s$name)),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("btn_load_confirm"), "Load", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_load_confirm, {
      req(input$load_scenario_select)

      scenarios <- saved_scenarios()
      selected_name <- input$load_scenario_select

      # Find scenario by name
      scenario <- scenarios[[which(sapply(scenarios, function(s) s$name == selected_name))]]

      if (!is.null(scenario)) {
        # Restore settings
        updateTextInput(session, "scenario_name", value = scenario$name)
        updateCheckboxGroupInput(session, "exclude_rob", selected = scenario$settings$exclude_rob)
        updateSliderInput(session, "min_sample", value = scenario$settings$min_sample)
        updateSliderInput(session, "max_year", value = scenario$settings$max_year)
        updateCheckboxInput(session, "only_rct", value = scenario$settings$only_rct)
        updateSelectInput(session, "estimator", selected = scenario$settings$estimator)

        # Restore results
        current_scenario_results(list(
          scenario_name = scenario$name,
          n_studies = scenario$n_studies,
          pooled_effect = scenario$pooled_effect,
          ci_lower = scenario$ci_lower,
          ci_upper = scenario$ci_upper,
          p_value = scenario$p_value,
          i2 = scenario$i2,
          tau2 = scenario$tau2,
          settings = scenario$settings,
          data = scenario$data
        ))

        removeModal()
        showNotification(sprintf("✓ Loaded scenario '%s'", scenario$name),
                         type = "message", duration = 3)
      }
    })

    # Saved scenarios table
    output$saved_scenarios_table <- renderDT({
      scenarios <- saved_scenarios()

      # BUG FIX #2: Proper empty state handling
      if (length(scenarios) == 0) {
        df <- data.frame(
          Name = character(),
          Studies = integer(),
          Effect = character(),
          I2 = character(),
          Created = character(),
          stringsAsFactors = FALSE
        )
        return(datatable(
          df,
          options = list(
            pageLength = 10,
            dom = 'tp',
            language = list(emptyTable = "No saved scenarios. Run an analysis and click 'Save Scenario' to add one.")
          ),
          rownames = FALSE
        ))
      }

      df <- do.call(rbind, lapply(scenarios, function(s) {
        data.frame(
          Name = s$name,
          Studies = s$n_studies,
          Effect = sprintf("%.3f [%.3f, %.3f]", s$pooled_effect,
                           s$ci_lower, s$ci_upper),
          I2 = sprintf("%.1f%%", s$i2),
          Created = format(s$created_at, "%Y-%m-%d %H:%M"),
          stringsAsFactors = FALSE
        )
      }))

      datatable(
        df,
        options = list(pageLength = 10, dom = 'tp'),
        rownames = FALSE
      )
    })

    # Run comparison
    comparison_results <- reactiveVal(NULL)

    observeEvent(input$btn_run_comparison, {
      req(input$compare_scenario_1, input$compare_scenario_2)

      scenarios <- saved_scenarios()
      scn1 <- scenarios[[input$compare_scenario_1]]
      scn2 <- scenarios[[input$compare_scenario_2]]

      if (is.null(scn1) || is.null(scn2)) {
        showNotification("⚠ Please select two scenarios to compare",
                         type = "warning", duration = 3)
        return()
      }

      comparison_results(list(
        scenario1 = scn1,
        scenario2 = scn2
      ))

      showNotification("✓ Comparison generated",
                       type = "message", duration = 2)
    })

    # Comparison summary
    output$comparison_summary <- renderUI({
      req(comparison_results())
      comp <- comparison_results()

      effect_diff <- abs(comp$scenario1$pooled_effect - comp$scenario2$pooled_effect)
      i2_diff <- abs(comp$scenario1$i2 - comp$scenario2$i2)

      div(
        class = "p-3 bg-light rounded",
        h5("Key Differences"),
        tags$ul(
          tags$li(sprintf("Effect size difference: %.3f", effect_diff)),
          tags$li(sprintf("I² difference: %.1f%%", i2_diff)),
          tags$li(sprintf("Study count: %d vs %d",
                          comp$scenario1$n_studies,
                          comp$scenario2$n_studies))
        )
      )
    })

    # Scenario titles
    output$scenario1_title <- renderText({
      req(comparison_results())
      comparison_results()$scenario1$name
    })

    output$scenario2_title <- renderText({
      req(comparison_results())
      comparison_results()$scenario2$name
    })

    # Scenario stats
    output$scenario1_stats <- renderUI({
      req(comparison_results())
      scn <- comparison_results()$scenario1

      tags$table(
        class = "table table-sm",
        tags$tr(tags$td(strong("Studies:")), tags$td(scn$n_studies)),
        tags$tr(tags$td(strong("Effect:")), tags$td(sprintf("%.3f", scn$pooled_effect))),
        tags$tr(tags$td(strong("95% CI:")), tags$td(sprintf("[%.3f, %.3f]",
                                                             scn$ci_lower, scn$ci_upper))),
        tags$tr(tags$td(strong("p-value:")), tags$td(sprintf("%.4f", scn$p_value))),
        tags$tr(tags$td(strong("I²:")), tags$td(sprintf("%.1f%%", scn$i2))),
        tags$tr(tags$td(strong("τ²:")), tags$td(sprintf("%.4f", scn$tau2)))
      )
    })

    output$scenario2_stats <- renderUI({
      req(comparison_results())
      scn <- comparison_results()$scenario2

      tags$table(
        class = "table table-sm",
        tags$tr(tags$td(strong("Studies:")), tags$td(scn$n_studies)),
        tags$tr(tags$td(strong("Effect:")), tags$td(sprintf("%.3f", scn$pooled_effect))),
        tags$tr(tags$td(strong("95% CI:")), tags$td(sprintf("[%.3f, %.3f]",
                                                             scn$ci_lower, scn$ci_upper))),
        tags$tr(tags$td(strong("p-value:")), tags$td(sprintf("%.4f", scn$p_value))),
        tags$tr(tags$td(strong("I²:")), tags$td(sprintf("%.1f%%", scn$i2))),
        tags$tr(tags$td(strong("τ²:")), tags$td(sprintf("%.4f", scn$tau2)))
      )
    })

    # Comparison diff table
    output$comparison_diff_table <- renderDT({
      req(comparison_results())
      comp <- comparison_results()

      settings1 <- comp$scenario1$settings
      settings2 <- comp$scenario2$settings

      df <- data.frame(
        Setting = c("Exclude ROB", "Min Sample Size", "Max Year", "RCTs Only", "Estimator"),
        Scenario1 = c(
          paste(settings1$exclude_rob, collapse = ", "),
          settings1$min_sample,
          settings1$max_year,
          ifelse(settings1$only_rct, "Yes", "No"),
          settings1$estimator
        ),
        Scenario2 = c(
          paste(settings2$exclude_rob, collapse = ", "),
          settings2$min_sample,
          settings2$max_year,
          ifelse(settings2$only_rct, "Yes", "No"),
          settings2$estimator
        ),
        stringsAsFactors = FALSE
      )

      # Mark differences
      df$Different <- ifelse(df$Scenario1 == df$Scenario2, "", "✓")

      datatable(
        df,
        options = list(dom = 't', pageLength = 10),
        rownames = FALSE
      ) %>%
        formatStyle(
          'Different',
          backgroundColor = styleEqual("✓", "#fff3cd")
        )
    })

    # Side-by-side forest plots
    output$comparison_forest_plots <- renderPlot({
      req(comparison_results())
      comp <- comparison_results()

      library(ggplot2)
      library(gridExtra)

      # Plot 1
      data1 <- comp$scenario1$data
      if (!"study_id" %in% names(data1)) {
        data1$study_id <- paste0("Study_", seq_len(nrow(data1)))
      }

      p1 <- ggplot(data1, aes(x = yi, y = reorder(study_id, yi))) +
        geom_point(color = "steelblue", size = 3) +
        geom_errorbarh(aes(xmin = yi - 1.96 * sei, xmax = yi + 1.96 * sei),
                       height = 0.2, color = "steelblue") +
        geom_vline(xintercept = comp$scenario1$pooled_effect,
                   color = "red", linetype = "dashed", size = 1) +
        geom_vline(xintercept = 0, linetype = "dotted") +
        labs(
          title = paste("Scenario 1:", comp$scenario1$name),
          subtitle = sprintf("Effect: %.3f [%.3f, %.3f], I²=%.1f%%",
                             comp$scenario1$pooled_effect,
                             comp$scenario1$ci_lower,
                             comp$scenario1$ci_upper,
                             comp$scenario1$i2),
          x = "Effect Size",
          y = ""
        ) +
        theme_minimal() +
        theme(axis.text.y = element_text(size = 8))

      # Plot 2
      data2 <- comp$scenario2$data
      if (!"study_id" %in% names(data2)) {
        data2$study_id <- paste0("Study_", seq_len(nrow(data2)))
      }

      p2 <- ggplot(data2, aes(x = yi, y = reorder(study_id, yi))) +
        geom_point(color = "steelblue", size = 3) +
        geom_errorbarh(aes(xmin = yi - 1.96 * sei, xmax = yi + 1.96 * sei),
                       height = 0.2, color = "steelblue") +
        geom_vline(xintercept = comp$scenario2$pooled_effect,
                   color = "red", linetype = "dashed", size = 1) +
        geom_vline(xintercept = 0, linetype = "dotted") +
        labs(
          title = paste("Scenario 2:", comp$scenario2$name),
          subtitle = sprintf("Effect: %.3f [%.3f, %.3f], I²=%.1f%%",
                             comp$scenario2$pooled_effect,
                             comp$scenario2$ci_lower,
                             comp$scenario2$ci_upper,
                             comp$scenario2$i2),
          x = "Effect Size",
          y = ""
        ) +
        theme_minimal() +
        theme(axis.text.y = element_text(size = 8))

      grid.arrange(p1, p2, ncol = 2)
    })

    # Leave-One-Out Analysis
    loo_results <- reactiveVal(NULL)

    observeEvent(input$btn_run_loo, {
      req(rv$data)

      # Check if data has yi and sei columns
      if (!all(c("yi", "sei") %in% names(rv$data))) {
        showNotification(
          "⚠ Data must have 'yi' and 'sei' columns for leave-one-out analysis. Please compute effect sizes first.",
          type = "warning",
          duration = 5
        )
        return()
      }

      withProgress(message = "Running leave-one-out analysis...", {

        tryCatch({
          library(metafor)

          data <- rv$data
          if (nrow(data) < 3) {
            showNotification(
              "⚠ Need at least 3 studies for meaningful leave-one-out analysis",
              type = "warning",
              duration = 4
            )
            return()
          }

          # Run base meta-analysis
          ma_base <- rma(yi = data$yi, sei = data$sei, method = "REML", data = data)

          # Run leave-one-out analysis
          loo_ma <- leave1out(ma_base, digits = 4)

          # Create results table
          if (!"study_id" %in% names(data)) {
            data$study_id <- paste0("Study_", seq_len(nrow(data)))
          }

          loo_table <- data.frame(
            Study_Omitted = data$study_id,
            Estimate = loo_ma$estimate,
            SE = loo_ma$se,
            CI_Lower = loo_ma$ci.lb,
            CI_Upper = loo_ma$ci.ub,
            p_value = loo_ma$pval,
            I2 = loo_ma$I2,
            tau2 = loo_ma$tau2,
            stringsAsFactors = FALSE
          )

          # Calculate influence metrics
          loo_table$Diff_from_Base <- loo_table$Estimate - ma_base$beta[1]
          loo_table$Pct_Change <- 100 * loo_table$Diff_from_Base / ma_base$beta[1]

          results <- list(
            base_effect = ma_base$beta[1],
            base_ci_lower = ma_base$ci.lb,
            base_ci_upper = ma_base$ci.ub,
            base_i2 = ma_base$I2,
            loo_table = loo_table,
            n_studies = nrow(data),
            max_influence_study = loo_table$Study_Omitted[which.max(abs(loo_table$Diff_from_Base))],
            max_influence_pct = max(abs(loo_table$Pct_Change))
          )

          loo_results(results)

          showNotification(
            sprintf("✓ Leave-one-out analysis complete. Most influential study: %s (%.1f%% change)",
                    results$max_influence_study, results$max_influence_pct),
            type = "message",
            duration = 6
          )

        }, error = function(e) {
          showNotification(
            paste("⚠ Error running leave-one-out analysis:", e$message),
            type = "error",
            duration = 7
          )
        })
      })
    })

    # Leave-one-out summary
    output$loo_summary <- renderUI({
      req(loo_results())
      res <- loo_results()

      div(
        class = "alert alert-info",
        h5(class = "mb-3", "Summary"),
        tags$ul(
          tags$li(tags$strong("Base model (all studies):"),
                  sprintf("Effect = %.3f [%.3f, %.3f], I² = %.1f%%",
                          res$base_effect, res$base_ci_lower, res$base_ci_upper, res$base_i2)),
          tags$li(tags$strong("Number of studies:"), res$n_studies),
          tags$li(tags$strong("Most influential study:"),
                  sprintf("%s (%.1f%% change in pooled effect)",
                          res$max_influence_study, res$max_influence_pct))
        ),
        tags$hr(),
        tags$p(class = "mb-0",
               tags$small("Studies with large influence (>10% change) should be investigated. ",
                          "Check for outliers, data errors, or genuine differences."))
      )
    })

    # Leave-one-out table
    output$loo_table <- renderDT({
      req(loo_results())
      res <- loo_results()

      display_table <- res$loo_table
      display_table$Estimate <- sprintf("%.3f", display_table$Estimate)
      display_table$SE <- sprintf("%.3f", display_table$SE)
      display_table$CI_95 <- sprintf("[%.3f, %.3f]",
                                      res$loo_table$CI_Lower,
                                      res$loo_table$CI_Upper)
      display_table$p_value <- sprintf("%.4f", display_table$p_value)
      display_table$I2 <- sprintf("%.1f%%", display_table$I2)
      display_table$tau2 <- sprintf("%.4f", display_table$tau2)
      display_table$Diff <- sprintf("%.3f", display_table$Diff_from_Base)
      display_table$Change <- sprintf("%.1f%%", display_table$Pct_Change)

      display_table <- display_table[, c("Study_Omitted", "Estimate", "CI_95",
                                          "p_value", "I2", "Diff", "Change")]
      colnames(display_table) <- c("Study Omitted", "Pooled Effect", "95% CI",
                                     "p-value", "I²", "Difference", "% Change")

      datatable(
        display_table,
        options = list(
          pageLength = 15,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel')
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          "% Change",
          backgroundColor = styleInterval(c(-10, 10), c("#ffe6e6", "white", "white", "#ffe6e6"))
        )
    })

    # Leave-one-out plot
    output$loo_plot <- renderPlot({
      req(loo_results())
      res <- loo_results()

      loo_table <- res$loo_table
      loo_table$Study_Omitted <- factor(loo_table$Study_Omitted,
                                          levels = loo_table$Study_Omitted)

      ggplot(loo_table, aes(x = Estimate, y = Study_Omitted)) +
        geom_vline(xintercept = res$base_effect, linetype = "dashed",
                   color = "blue", size = 1.2, alpha = 0.7) +
        geom_point(size = 3, color = "darkred") +
        geom_errorbarh(aes(xmin = CI_Lower, xmax = CI_Upper),
                       height = 0.2, color = "darkred", alpha = 0.7) +
        labs(
          title = "Leave-One-Out Influence Analysis",
          subtitle = sprintf("Blue dashed line = base model effect (%.3f)", res$base_effect),
          x = "Pooled Effect Estimate (with 95% CI)",
          y = "Study Omitted"
        ) +
        theme_minimal() +
        theme(
          axis.text.y = element_text(size = 10),
          plot.title = element_text(face = "bold"),
          panel.grid.major.y = element_line(color = "grey90")
        )
    })

    # Delete scenario
    observeEvent(input$btn_delete_scenario, {
      # Implementation for deleting selected scenario
      showNotification("Delete functionality - select scenario from table first",
                       type = "message", duration = 3)
    })

    # Export scenarios
    observeEvent(input$btn_export_scenarios, {
      scenarios <- saved_scenarios()

      if (length(scenarios) == 0) {
        showNotification("No scenarios to export",
                         type = "message", duration = 2)
        return()
      }

      # Save to JSON
      filename <- file.path("outputs", paste0("scenarios_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".json"))
      write_json(scenarios, filename, pretty = TRUE, auto_unbox = TRUE)

      showNotification(paste("✓ Scenarios exported to:", filename),
                       type = "message", duration = 5)
    })

    return(reactive(list(
      filtered_data = filtered_data(),
      current_results = current_scenario_results(),
      saved_scenarios = saved_scenarios()
    )))
  })
}
