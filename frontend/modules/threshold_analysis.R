# Threshold Analysis Module
# One-way and multi-way threshold analysis for health economic parameters
# Identifies break-even points for cost-effectiveness decisions

library(shiny)
library(ggplot2)

threshold_analysis_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("sliders-h", class = "me-2"),
          "Threshold Analysis"
        )
      ),

      layout_columns(
        col_widths = c(4, 8),

        # Settings panel
        card(
          card_header("Analysis Settings"),

          selectInput(ns("analysis_type"), "Analysis Type",
                     choices = c(
                       "One-Way Threshold" = "one_way",
                       "Two-Way Threshold" = "two_way",
                       "Tornado Diagram" = "tornado",
                       "Break-Even Analysis" = "breakeven"
                     )),

          hr(),

          # One-way threshold settings
          conditionalPanel(
            condition = "input.analysis_type == 'one_way'",
            ns = ns,

            h5("Select Parameter to Vary"),
            selectInput(ns("parameter_select"), "Parameter",
                       choices = c(
                         "Treatment Cost" = "cost_treatment",
                         "Comparator Cost" = "cost_comparator",
                         "Treatment Utility" = "utility_stable",
                         "HR Progression" = "hr_progression",
                         "HR Death" = "hr_death",
                         "Discount Rate" = "discount_rate",
                         "Time Horizon" = "time_horizon"
                       )),

            numericInput(ns("param_min"), "Minimum Value", 0),
            numericInput(ns("param_max"), "Maximum Value", 100),
            numericInput(ns("param_step"), "Step Size", 10),

            hr(),

            h5("Decision Threshold"),
            numericInput(ns("wtp_threshold_analysis"), "WTP Threshold",
                        30000, min = 0, step = 5000),
            helpText("The cost-effectiveness threshold for decision-making")
          ),

          # Two-way threshold settings
          conditionalPanel(
            condition = "input.analysis_type == 'two_way'",
            ns = ns,

            h5("Select Two Parameters"),
            selectInput(ns("param_x"), "X-Axis Parameter",
                       choices = c(
                         "Treatment Cost" = "cost_treatment",
                         "HR Progression" = "hr_progression",
                         "Utility Stable" = "utility_stable"
                       )),
            selectInput(ns("param_y"), "Y-Axis Parameter",
                       choices = c(
                         "Comparator Cost" = "cost_comparator",
                         "HR Death" = "hr_death",
                         "Discount Rate" = "discount_rate"
                       ),
                       selected = "cost_comparator"),

            numericInput(ns("wtp_threshold_2way"), "WTP Threshold",
                        30000, min = 0, step = 5000)
          ),

          # Tornado settings
          conditionalPanel(
            condition = "input.analysis_type == 'tornado'",
            ns = ns,

            h5("Tornado Diagram Settings"),
            p("Varies all parameters ±20% from base case"),

            selectInput(ns("tornado_outcome"), "Outcome Measure",
                       choices = c(
                         "ICER" = "icer",
                         "Incremental QALYs" = "inc_qalys",
                         "Incremental Costs" = "inc_costs",
                         "Net Monetary Benefit" = "nmb"
                       )),

            numericInput(ns("wtp_tornado"), "WTP Threshold (for NMB)",
                        30000, min = 0, step = 5000),

            numericInput(ns("variation_pct"), "Variation %",
                        20, min = 5, max = 50, step = 5)
          ),

          hr(),

          actionButton(ns("btn_analyze"), "Run Threshold Analysis",
                      class = "btn-primary w-100",
                      icon = icon("play"))
        ),

        # Results panel
        card(
          card_header("Threshold Analysis Results"),

          navset_card_tab(
            nav_panel("Plot", plotOutput(ns("threshold_plot"), height = "600px")),
            nav_panel("Summary", uiOutput(ns("threshold_summary"))),
            nav_panel("Table", DTOutput(ns("threshold_table"))),
            nav_panel("Interpretation", uiOutput(ns("interpretation")))
          )
        )
      )
    )
  )
}

threshold_analysis_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    threshold_results <- reactiveVal(NULL)

    # Run threshold analysis
    observeEvent(input$btn_analyze, {
      req(rv$he_model_results, rv$he_params)

      withProgress(message = "Running threshold analysis...", {

        tryCatch({
          if (input$analysis_type == "one_way") {
            results <- run_one_way_threshold(
              params = rv$he_params,
              base_results = rv$he_model_results,
              parameter = input$parameter_select,
              param_range = seq(input$param_min, input$param_max, by = input$param_step),
              wtp_threshold = input$wtp_threshold_analysis
            )
          } else if (input$analysis_type == "two_way") {
            results <- run_two_way_threshold(
              params = rv$he_params,
              base_results = rv$he_model_results,
              param_x = input$param_x,
              param_y = input$param_y,
              wtp_threshold = input$wtp_threshold_2way
            )
          } else if (input$analysis_type == "tornado") {
            results <- run_tornado_analysis(
              params = rv$he_params,
              base_results = rv$he_model_results,
              outcome = input$tornado_outcome,
              wtp_threshold = input$wtp_tornado,
              variation_pct = input$variation_pct / 100
            )
          } else {
            results <- run_breakeven_analysis(
              params = rv$he_params,
              base_results = rv$he_model_results,
              wtp_threshold = input$wtp_threshold_analysis
            )
          }

          threshold_results(results)
          rv$threshold_analysis <- results

          showNotification("✓ Threshold analysis complete", type = "message")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    # Plot output
    output$threshold_plot <- renderPlot({
      req(threshold_results())
      plot_threshold_results(threshold_results(), input$analysis_type)
    })

    # Summary output
    output$threshold_summary <- renderUI({
      req(threshold_results())
      results <- threshold_results()

      if (input$analysis_type == "one_way") {
        tagList(
          h4("One-Way Threshold Analysis Results"),

          if (!is.null(results$threshold_value)) {
            div(
              class = "alert alert-success",
              h5("Threshold Value Found"),
              p(sprintf("Break-even value for %s: %.2f", input$parameter_select, results$threshold_value)),
              p("Below this value, the intervention is cost-effective at the specified WTP threshold.")
            )
          } else {
            div(
              class = "alert alert-warning",
              "No threshold crossing found in the specified parameter range. ",
              "The intervention is ", if (results$always_cost_effective) "always" else "never",
              " cost-effective across this range."
            )
          },

          hr(),

          h5("Key Findings"),
          tags$ul(
            tags$li("Parameter analyzed: ", input$parameter_select),
            tags$li("Range tested: ", sprintf("%.2f to %.2f", input$param_min, input$param_max)),
            tags$li("WTP threshold: ", sprintf("$%,.0f/QALY", input$wtp_threshold_analysis)),
            tags$li("Base case ICER: ", sprintf("$%,.0f/QALY", results$base_icer))
          )
        )
      } else if (input$analysis_type == "tornado") {
        tagList(
          h4("Tornado Diagram Summary"),

          p("Parameters ranked by impact on ", input$tornado_outcome),

          tags$table(
            class = "table table-striped",
            tags$thead(
              tags$tr(
                tags$th("Rank"),
                tags$th("Parameter"),
                tags$th("Impact Range"),
                tags$th("Impact Magnitude")
              )
            ),
            tags$tbody(
              lapply(1:min(5, nrow(results$ranking)), function(i) {
                row <- results$ranking[i, ]
                tags$tr(
                  tags$td(i),
                  tags$td(row$parameter),
                  tags$td(sprintf("%.2f to %.2f", row$low_value, row$high_value)),
                  tags$td(sprintf("%.2f", row$impact_magnitude))
                )
              })
            )
          ),

          p(class = "text-muted", "Top 5 most influential parameters shown.")
        )
      }
    })

    # Table output
    output$threshold_table <- renderDT({
      req(threshold_results())
      results <- threshold_results()

      if (input$analysis_type == "one_way") {
        datatable(results$results_table,
                 options = list(pageLength = 25, scrollX = TRUE),
                 caption = "One-Way Threshold Analysis Results")
      } else if (input$analysis_type == "tornado") {
        datatable(results$ranking,
                 options = list(pageLength = 20, scrollX = TRUE),
                 caption = "Parameter Sensitivity Ranking")
      } else {
        datatable(results$results_table,
                 options = list(pageLength = 25, scrollX = TRUE))
      }
    })

    # Interpretation
    output$interpretation <- renderUI({
      req(threshold_results())
      results <- threshold_results()

      tagList(
        h4("Interpretation Guide"),

        card(
          card_header("Understanding Threshold Analysis"),

          if (input$analysis_type == "one_way") {
            tagList(
              h5("One-Way Threshold Analysis"),
              p("This analysis identifies the \"break-even\" value for a single parameter where the ICER equals the WTP threshold."),

              tags$ul(
                tags$li("Points below the threshold: intervention is cost-effective"),
                tags$li("Points above the threshold: intervention is not cost-effective"),
                tags$li("The crossing point is the maximum (for costs) or minimum (for effects) value at which the decision changes")
              ),

              h5("Decision-Making Implications"),
              if (!is.null(results$threshold_value)) {
                p(sprintf("The intervention remains cost-effective as long as %s stays %s %.2f",
                         input$parameter_select,
                         if (grepl("cost", input$parameter_select)) "below" else "above",
                         results$threshold_value))
              } else {
                p("The decision is robust to this parameter across the entire range tested. ",
                  "Either the intervention is always or never cost-effective within this range.")
              }
            )
          } else if (input$analysis_type == "two_way") {
            tagList(
              h5("Two-Way Threshold Analysis"),
              p("This shows combinations of two parameters that result in cost-effectiveness."),

              p("Use this to understand:"),
              tags$ul(
                tags$li("Trade-offs between parameters"),
                tags$li("Feasible parameter space for cost-effectiveness"),
                tags$li("Combinations that maintain favorable cost-effectiveness")
              )
            )
          } else if (input$analysis_type == "tornado") {
            tagList(
              h5("Tornado Diagram"),
              p("Shows which parameters have the greatest impact on results."),

              p("Key insights:"),
              tags$ul(
                tags$li("Parameters at the top have the most influence"),
                tags$li("Wider bars = greater uncertainty/sensitivity"),
                tags$li("Focus data collection efforts on high-impact parameters"),
                tags$li("Parameters with narrow bars are less critical to the decision")
              ),

              div(class = "alert alert-info",
                  icon("lightbulb"),
                  " Consider conducting further research or collecting better data for the top 3-5 most influential parameters.")
            )
          }
        )
      )
    })

    return(reactive(threshold_results()))
  })
}

#' Run one-way threshold analysis
run_one_way_threshold <- function(params, base_results, parameter, param_range, wtp_threshold) {

  results_list <- list()
  icers <- numeric(length(param_range))
  cost_effective <- logical(length(param_range))

  for (i in seq_along(param_range)) {
    # Create modified parameters
    params_mod <- params
    params_mod[[parameter]] <- param_range[i]

    # Re-run model (simplified - in practice would call full model)
    # For demo, approximate the effect
    mod_results <- approximate_results_change(base_results, parameter, param_range[i], params[[parameter]])

    icers[i] <- mod_results$icer
    cost_effective[i] <- icers[i] < wtp_threshold
  }

  # Find threshold value (where ICER crosses WTP threshold)
  threshold_value <- NULL
  if (any(cost_effective) && any(!cost_effective)) {
    # Find crossing point via interpolation
    cross_idx <- which(diff(cost_effective) != 0)[1]
    if (!is.na(cross_idx)) {
      x1 <- param_range[cross_idx]
      x2 <- param_range[cross_idx + 1]
      y1 <- icers[cross_idx]
      y2 <- icers[cross_idx + 1]

      # Linear interpolation
      threshold_value <- x1 + (wtp_threshold - y1) * (x2 - x1) / (y2 - y1)
    }
  }

  results_table <- data.frame(
    Parameter_Value = param_range,
    ICER = icers,
    Cost_Effective = cost_effective,
    Difference_from_WTP = icers - wtp_threshold
  )

  list(
    results_table = results_table,
    threshold_value = threshold_value,
    always_cost_effective = all(cost_effective),
    never_cost_effective = all(!cost_effective),
    base_icer = base_results$icer,
    parameter = parameter,
    wtp_threshold = wtp_threshold
  )
}

#' Run two-way threshold analysis
run_two_way_threshold <- function(params, base_results, param_x, param_y, wtp_threshold) {

  # Create grid
  x_range <- seq(params[[param_x]] * 0.5, params[[param_x]] * 1.5, length.out = 50)
  y_range <- seq(params[[param_y]] * 0.5, params[[param_y]] * 1.5, length.out = 50)

  grid <- expand.grid(x = x_range, y = y_range)
  grid$icer <- NA
  grid$cost_effective <- NA

  for (i in 1:nrow(grid)) {
    params_mod <- params
    params_mod[[param_x]] <- grid$x[i]
    params_mod[[param_y]] <- grid$y[i]

    mod_results <- approximate_results_change_2way(base_results, param_x, grid$x[i], param_y, grid$y[i], params)

    grid$icer[i] <- mod_results$icer
    grid$cost_effective[i] <- mod_results$icer < wtp_threshold
  }

  list(
    grid = grid,
    param_x = param_x,
    param_y = param_y,
    wtp_threshold = wtp_threshold
  )
}

#' Run tornado analysis
run_tornado_analysis <- function(params, base_results, outcome, wtp_threshold, variation_pct = 0.2) {

  # Parameters to vary
  parameters <- c("cost_treatment", "cost_comparator", "utility_stable", "utility_progressed",
                 "hr_progression", "hr_death", "discount_rate")

  results <- data.frame(
    parameter = character(),
    low_value = numeric(),
    high_value = numeric(),
    impact_magnitude = numeric(),
    stringsAsFactors = FALSE
  )

  base_value <- switch(outcome,
    "icer" = base_results$icer,
    "inc_qalys" = base_results$inc_qalys,
    "inc_costs" = base_results$inc_costs,
    "nmb" = base_results$inc_qalys * wtp_threshold - base_results$inc_costs,
    base_results$icer
  )

  for (param in parameters) {
    if (is.null(params[[param]])) next

    # Low scenario (-20%)
    params_low <- params
    params_low[[param]] <- params[[param]] * (1 - variation_pct)
    results_low <- approximate_results_change(base_results, param, params_low[[param]], params[[param]])
    value_low <- switch(outcome,
      "icer" = results_low$icer,
      "inc_qalys" = results_low$inc_qalys,
      "inc_costs" = results_low$inc_costs,
      "nmb" = results_low$inc_qalys * wtp_threshold - results_low$inc_costs,
      results_low$icer
    )

    # High scenario (+20%)
    params_high <- params
    params_high[[param]] <- params[[param]] * (1 + variation_pct)
    results_high <- approximate_results_change(base_results, param, params_high[[param]], params[[param]])
    value_high <- switch(outcome,
      "icer" = results_high$icer,
      "inc_qalys" = results_high$inc_qalys,
      "inc_costs" = results_high$inc_costs,
      "nmb" = results_high$inc_qalys * wtp_threshold - results_high$inc_costs,
      results_high$icer
    )

    results <- rbind(results, data.frame(
      parameter = param,
      low_value = value_low,
      high_value = value_high,
      impact_magnitude = abs(value_high - value_low),
      stringsAsFactors = FALSE
    ))
  }

  # Sort by impact magnitude
  results <- results[order(-results$impact_magnitude), ]

  list(
    ranking = results,
    base_value = base_value,
    outcome = outcome,
    variation_pct = variation_pct
  )
}

#' Approximate results change for threshold analysis
#'
#' @description
#' Uses linear approximation to estimate model outcomes when parameters change.
#' This provides fast threshold analysis suitable for interactive exploration.
#'
#' @details
#' **Approximation Method**:
#' - Cost parameters: Linear scaling of costs (ACCURATE for cost changes)
#' - Utility parameters: Linear scaling of QALYs (APPROXIMATE - assumes proportional effect)
#' - Hazard ratios: Dampened linear scaling (APPROXIMATE - nonlinear effects simplified)
#'
#' **Limitations**:
#' - Does not re-run full Markov simulation
#' - Assumes linear/proportional relationships
#' - May underestimate threshold uncertainty for HR parameters
#'
#' **When to use full model re-run**:
#' For final threshold estimates or sensitivity analysis for publication,
#' re-run the full Markov model with modified parameters to get exact results.
#' This approximation is for rapid screening and interactive use.
#'
#' @param base_results Base case model results
#' @param parameter Parameter name being varied
#' @param new_value New parameter value
#' @param old_value Original parameter value
#' @return Modified results with approximated outcomes
approximate_results_change <- function(base_results, parameter, new_value, old_value) {

  ratio <- new_value / old_value
  mod_results <- base_results

  if (grepl("cost", parameter)) {
    # Cost parameter - ACCURATE linear approximation
    # Costs scale directly with parameter changes
    if (parameter == "cost_treatment") {
      mod_results$costs_treatment <- base_results$costs_treatment * ratio
      mod_results$inc_costs <- mod_results$costs_treatment - base_results$costs_comparator
    } else if (parameter == "cost_comparator") {
      mod_results$costs_comparator <- base_results$costs_comparator * ratio
      mod_results$inc_costs <- base_results$costs_treatment - mod_results$costs_comparator
    } else {
      # State costs
      # Approximate impact by scaling total costs
      mod_results$costs_treatment <- base_results$costs_treatment * ratio
      mod_results$costs_comparator <- base_results$costs_comparator * ratio
      mod_results$inc_costs <- mod_results$costs_treatment - mod_results$costs_comparator
    }

  } else if (grepl("utility", parameter)) {
    # Utility parameter - APPROXIMATE linear scaling
    # Assumes proportional effect on QALYs (reasonable for small changes)
    mod_results$qalys_treatment <- base_results$qalys_treatment * ratio
    mod_results$inc_qalys <- mod_results$qalys_treatment - base_results$qalys_comparator

  } else if (grepl("hr|hazard", tolower(parameter))) {
    # Hazard ratio - APPROXIMATE with dampening
    # HRs have nonlinear effects on survival/QALYs
    # Use dampened ratio to approximate (50% of linear effect)
    # More accurate would require re-running Markov model
    effect_ratio <- (ratio - 1) * 0.5 + 1  # Dampened effect
    mod_results$qalys_treatment <- base_results$qalys_treatment * effect_ratio
    mod_results$inc_qalys <- mod_results$qalys_treatment - base_results$qalys_comparator

  } else {
    # Unknown parameter - assume proportional effect on QALYs
    warning(paste("Unknown parameter type:", parameter, "- using proportional approximation"))
    mod_results$qalys_treatment <- base_results$qalys_treatment * ratio
    mod_results$inc_qalys <- mod_results$qalys_treatment - base_results$qalys_comparator
  }

  # Recalculate ICER
  mod_results$icer <- mod_results$inc_costs / mod_results$inc_qalys

  return(mod_results)
}

#' Approximate results change for two parameters
approximate_results_change_2way <- function(base_results, param_x, val_x, param_y, val_y, params) {
  # Apply both parameter changes
  temp_results <- approximate_results_change(base_results, param_x, val_x, params[[param_x]])
  final_results <- approximate_results_change(temp_results, param_y, val_y, params[[param_y]])
  return(final_results)
}

#' Plot threshold analysis results
plot_threshold_results <- function(results, analysis_type) {
  library(ggplot2)

  if (analysis_type == "one_way") {
    data <- results$results_table

    ggplot(data, aes(x = Parameter_Value, y = ICER)) +
      geom_line(size = 1.2, color = "steelblue") +
      geom_point(aes(color = Cost_Effective), size = 2) +
      geom_hline(yintercept = results$wtp_threshold, linetype = "dashed", color = "red", size = 1) +
      scale_color_manual(values = c("TRUE" = "green", "FALSE" = "red"),
                        labels = c("TRUE" = "Cost-Effective", "FALSE" = "Not Cost-Effective")) +
      annotate("text", x = mean(data$Parameter_Value), y = results$wtp_threshold,
              label = sprintf("WTP Threshold: $%,.0f", results$wtp_threshold),
              vjust = -0.5, color = "red") +
      labs(title = "One-Way Threshold Analysis",
           subtitle = paste("Parameter:", results$parameter),
           x = "Parameter Value",
           y = "ICER ($/QALY)",
           color = "") +
      theme_minimal() +
      theme(legend.position = "bottom")

  } else if (analysis_type == "two_way") {
    ggplot(results$grid, aes(x = x, y = y, fill = cost_effective)) +
      geom_tile() +
      scale_fill_manual(values = c("TRUE" = "#4CAF50", "FALSE" = "#F44336"),
                       labels = c("TRUE" = "Cost-Effective", "FALSE" = "Not Cost-Effective")) +
      labs(title = "Two-Way Threshold Analysis",
           x = results$param_x,
           y = results$param_y,
           fill = "") +
      theme_minimal() +
      theme(legend.position = "bottom")

  } else if (analysis_type == "tornado") {
    data <- results$ranking
    data$parameter <- factor(data$parameter, levels = rev(data$parameter))

    ggplot(data, aes(y = parameter)) +
      geom_segment(aes(x = low_value, xend = high_value, yend = parameter),
                  size = 8, color = "steelblue") +
      geom_vline(xintercept = results$base_value, linetype = "dashed", color = "red", size = 1) +
      labs(title = "Tornado Diagram",
           subtitle = paste("Outcome:", results$outcome),
           x = "Outcome Value",
           y = "Parameter") +
      theme_minimal()
  }
}
