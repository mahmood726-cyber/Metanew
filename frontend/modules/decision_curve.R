# =============================================================================
# Decision Curve Analysis Module
# =============================================================================
# ✅ STANDARD - Widely used in clinical decision-making
#
# Features:
# - Net benefit calculation across threshold probabilities
# - Compare multiple strategies (treat all, treat none, model-based)
# - Clinical utility assessment
# - Patient preference incorporation
# - Diagnostic/prognostic test evaluation
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(dplyr)

#' Calculate net benefit for decision curve analysis
#'
#' @param sensitivity Sensitivity of test/model
#' @param specificity Specificity of test/model
#' @param prevalence Prevalence/baseline risk
#' @param threshold_prob Threshold probability
#' @return Net benefit
#' @export
calculate_net_benefit <- function(sensitivity, specificity, prevalence, threshold_prob) {

  # True positive rate
  tp_rate <- sensitivity * prevalence

  # False positive rate
  fp_rate <- (1 - specificity) * (1 - prevalence)

  # Net benefit formula
  # NB = (TP/N) - (FP/N) * (pt/(1-pt))
  # where pt = threshold probability

  net_benefit <- tp_rate - fp_rate * (threshold_prob / (1 - threshold_prob))

  return(net_benefit)
}

#' Generate decision curve
#'
#' @param models List of models with sensitivity/specificity
#' @param prevalence Prevalence
#' @param threshold_range Range of threshold probabilities
#' @return Data frame with net benefits
#' @export
generate_decision_curve <- function(models, prevalence, threshold_range = seq(0.01, 0.99, by = 0.01)) {

  # Initialize results
  results <- data.frame()

  for (pt in threshold_range) {

    # Strategy 1: Treat All
    nb_treat_all <- prevalence - (1 - prevalence) * (pt / (1 - pt))

    # Strategy 2: Treat None
    nb_treat_none <- 0

    # Add to results
    row <- data.frame(
      threshold = pt,
      strategy = "Treat All",
      net_benefit = nb_treat_all
    )
    results <- rbind(results, row)

    row <- data.frame(
      threshold = pt,
      strategy = "Treat None",
      net_benefit = nb_treat_none
    )
    results <- rbind(results, row)

    # Models
    for (model_name in names(models)) {
      model <- models[[model_name]]

      nb_model <- calculate_net_benefit(
        sensitivity = model$sensitivity,
        specificity = model$specificity,
        prevalence = prevalence,
        threshold_prob = pt
      )

      row <- data.frame(
        threshold = pt,
        strategy = model_name,
        net_benefit = nb_model
      )
      results <- rbind(results, row)
    }
  }

  results
}

#' UI for decision curve analysis
#'
#' @param id Module ID
#' @export
decision_curve_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      div(
        "Decision Curve Analysis",
        span("✅ STANDARD",
             style = "background: #10B981; color: white; padding: 3px 8px;
                      border-radius: 4px; font-size: 11px; margin-left: 10px;")
      )
    ),

    p("Evaluate clinical utility of diagnostic or prognostic models by comparing net benefit across threshold probabilities.",
      style = "color: #6B7280; margin-bottom: 20px;"),

    layout_columns(
      col_widths = c(4, 8),

      # Controls
      div(
        h5("Model Parameters", style = "color: #EC4899; margin-bottom: 15px;"),

        numericInput(
          ns("prevalence"),
          "Prevalence / Baseline Risk (%):",
          value = 20,
          min = 1,
          max = 99,
          step = 1
        ),

        hr(),

        h6("Model 1", style = "color: #374151;"),
        numericInput(ns("sens1"), "Sensitivity (%):", value = 85, min = 0, max = 100),
        numericInput(ns("spec1"), "Specificity (%):", value = 80, min = 0, max = 100),

        hr(),

        h6("Model 2 (Optional)", style = "color: #374151;"),
        checkboxInput(ns("include_model2"), "Include Model 2", value = FALSE),

        conditionalPanel(
          condition = "input.include_model2",
          ns = ns,
          numericInput(ns("sens2"), "Sensitivity (%):", value = 90, min = 0, max = 100),
          numericInput(ns("spec2"), "Specificity (%):", value = 70, min = 0, max = 100)
        ),

        hr(),

        sliderInput(
          ns("threshold_range"),
          "Threshold Probability Range:",
          min = 0,
          max = 100,
          value = c(5, 80),
          step = 1,
          post = "%"
        ),

        actionButton(
          ns("run_dca"),
          "Run Decision Curve Analysis",
          class = "btn-primary",
          icon = icon("chart-line"),
          style = "width: 100%;"
        )
      ),

      # Results
      div(
        h5("Decision Curve", style = "color: #EC4899; margin-bottom: 15px;"),

        plotlyOutput(ns("decision_curve_plot"), height = "450px"),

        br(),

        div(
          style = "background: #F9FAFB; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px;",

          h6("Interpretation:", style = "color: #1F2937; margin-bottom: 10px;"),

          tags$ul(
            style = "color: #6B7280; line-height: 1.8; margin: 0; font-size: 14px;",
            tags$li(strong("Treat All:"), " Assume everyone has condition, treat everyone"),
            tags$li(strong("Treat None:"), " Assume no one has condition, treat no one"),
            tags$li(strong("Model:"), " Use model to decide who to treat"),
            tags$li(strong("Net Benefit:"), " Higher is better at each threshold"),
            tags$li(strong("Crossing:"), " Model loses utility when it crosses 'Treat All' or 'Treat None'")
          )
        )
      )
    )
  )
}

#' Server for decision curve analysis
#'
#' @param id Module ID
#' @param rv Reactive values
#' @export
decision_curve_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    dca_results <- reactiveVal(NULL)

    observeEvent(input$run_dca, {

      # Build models list
      models <- list(
        "Model 1" = list(
          sensitivity = input$sens1 / 100,
          specificity = input$spec1 / 100
        )
      )

      if (input$include_model2) {
        models[["Model 2"]] <- list(
          sensitivity = input$sens2 / 100,
          specificity = input$spec2 / 100
        )
      }

      # Generate decision curve
      threshold_range <- seq(input$threshold_range[1]/100,
                            input$threshold_range[2]/100,
                            by = 0.01)

      results <- generate_decision_curve(
        models = models,
        prevalence = input$prevalence / 100,
        threshold_range = threshold_range
      )

      dca_results(results)
    })

    output$decision_curve_plot <- renderPlotly({
      req(dca_results())

      df <- dca_results()

      # Create plot
      p <- ggplot(df, aes(x = threshold * 100, y = net_benefit, color = strategy, group = strategy)) +
        geom_line(size = 1.2) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
        scale_color_manual(
          values = c("Treat All" = "#EF4444",
                    "Treat None" = "#3B82F6",
                    "Model 1" = "#10B981",
                    "Model 2" = "#F59E0B")
        ) +
        labs(
          title = "Decision Curve Analysis",
          x = "Threshold Probability (%)",
          y = "Net Benefit",
          color = "Strategy"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(face = "bold", size = 14),
          legend.position = "right"
        )

      ggplotly(p) %>%
        layout(hovermode = "x unified")
    })
  })
}
