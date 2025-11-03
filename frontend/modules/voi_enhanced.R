# =============================================================================
# Enhanced Value of Information Module
# =============================================================================
# Extends existing EVPPI with EVPI (Expected Value of Perfect Information)
# From CBAMMR - VALIDATED ✅ STANDARD for HTA
#
# Features:
# - EVPI (Expected Value of Perfect Information) - overall decision uncertainty
# - Complements existing EVPPI module
# - Population-level VOI calculations
# - Research prioritization with monetary values
# - Time horizon and discounting
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)

#' Calculate EVPI from cost-effectiveness analysis
#'
#' @param nmb_samples Matrix of net monetary benefit samples (rows = iterations, cols = treatments)
#' @param population_size Affected population size
#' @param time_horizon Time horizon in years
#' @param discount_rate Annual discount rate (default 0.035 = 3.5%)
#' @param incidence_rate Annual incidence rate (proportion of population per year)
#' @return List with EVPI per person and population EVPI
#' @export
calculate_evpi <- function(nmb_samples,
                           population_size,
                           time_horizon = 10,
                           discount_rate = 0.035,
                           incidence_rate = NULL) {

  # nmb_samples should be a matrix: rows = Monte Carlo iterations, columns = treatment options

  # For each iteration, find the best treatment
  best_per_iteration <- apply(nmb_samples, 1, max)

  # Expected value with perfect information
  ev_perfect_info <- mean(best_per_iteration)

  # Expected value with current information (best treatment on average)
  mean_nmb_per_treatment <- colMeans(nmb_samples)
  ev_current_info <- max(mean_nmb_per_treatment)

  # EVPI per person
  evpi_per_person <- ev_perfect_info - ev_current_info

  # Calculate effective population over time horizon
  if (is.null(incidence_rate)) {
    # Prevalence-based: fixed population
    discount_factors <- (1 / (1 + discount_rate))^(0:(time_horizon - 1))
    effective_population <- population_size * sum(discount_factors)
  } else {
    # Incidence-based: new patients each year
    discount_factors <- (1 / (1 + discount_rate))^(0:(time_horizon - 1))
    annual_new_cases <- population_size * incidence_rate
    effective_population <- annual_new_cases * sum(discount_factors)
  }

  # Population EVPI
  evpi_population <- evpi_per_person * effective_population

  list(
    evpi_per_person = evpi_per_person,
    evpi_population = evpi_population,
    ev_perfect_info = ev_perfect_info,
    ev_current_info = ev_current_info,
    decision_uncertainty = evpi_per_person,
    effective_population = effective_population,
    time_horizon = time_horizon,
    discount_rate = discount_rate
  )
}

#' UI for enhanced VOI tools
#'
#' @param id Module ID
#' @export
voi_tools_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("EVPI Calculator (Overall Decision Uncertainty)"),

    p(
      "Calculate the Expected Value of Perfect Information - the maximum value of eliminating all uncertainty in the decision.",
      style = "color: #6B7280; margin-bottom: 20px;"
    ),

    layout_columns(
      col_widths = c(6, 6),

      # Inputs
      div(
        h5("Decision Context", style = "color: #EC4899; margin-bottom: 15px;"),

        numericInput(
          ns("population_size"),
          "Affected Population Size:",
          value = 50000,
          min = 100,
          step = 1000
        ),

        numericInput(
          ns("time_horizon"),
          "Time Horizon (years):",
          value = 10,
          min = 1,
          max = 30,
          step = 1
        ),

        numericInput(
          ns("discount_rate"),
          "Discount Rate (%):",
          value = 3.5,
          min = 0,
          max = 10,
          step = 0.5
        ),

        radioButtons(
          ns("population_type"),
          "Population Type:",
          choices = c(
            "Prevalence-based (fixed population)" = "prevalence",
            "Incidence-based (new cases each year)" = "incidence"
          ),
          selected = "prevalence"
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'incidence'", ns("population_type")),
          numericInput(
            ns("incidence_rate"),
            "Annual Incidence Rate (%):",
            value = 10,
            min = 0.1,
            max = 100,
            step = 0.1
          )
        ),

        hr(),

        actionButton(
          ns("calculate_evpi"),
          "Calculate EVPI",
          class = "btn-primary",
          icon = icon("calculator"),
          style = "width: 100%;"
        )
      ),

      # Results
      div(
        h5("EVPI Results", style = "color: #EC4899; margin-bottom: 15px;"),

        uiOutput(ns("evpi_display"))
      )
    ),

    hr(),

    div(
      style = "background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 15px; border-radius: 6px;",

      div(
        strong(icon("info-circle", style = "color: #F59E0B; margin-right: 5px;"), "About EVPI"),
        style = "color: #92400E; margin-bottom: 8px;"
      ),

      tags$ul(
        style = "margin: 0; color: #92400E; font-size: 14px;",
        tags$li("EVPI represents the maximum value of conducting ANY further research"),
        tags$li("It's the upper bound on the value of research - actual VOI will be less"),
        tags$li("If EVPI < cost of research, further research is not cost-effective"),
        tags$li("EVPI = 0 when there's no decision uncertainty (clear best option)"),
        tags$li("Use EVPPI to identify which specific parameters to research")
      )
    )
  )
}

#' Server for enhanced VOI tools
#'
#' @param id Module ID
#' @param rv Reactive values with CE analysis results
#' @export
voi_tools_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    evpi_results <- reactiveVal(NULL)

    # Calculate EVPI
    observeEvent(input$calculate_evpi, {
      req(rv$he_results$nmb_samples)  # Requires PSA results

      withProgress(message = 'Calculating EVPI...', value = 0, {

        incidence <- if (input$population_type == "incidence") {
          input$incidence_rate / 100
        } else {
          NULL
        }

        evpi <- calculate_evpi(
          nmb_samples = rv$he_results$nmb_samples,
          population_size = input$population_size,
          time_horizon = input$time_horizon,
          discount_rate = input$discount_rate / 100,
          incidence_rate = incidence
        )

        evpi_results(evpi)

        setProgress(1)
      })
    })

    # Display EVPI results
    output$evpi_display <- renderUI({
      req(evpi_results())

      evpi <- evpi_results()

      tagList(
        div(
          style = "background: linear-gradient(135deg, #EC4899 0%, #8B5CF6 100%);
                   color: white; padding: 25px; border-radius: 12px; margin-bottom: 20px;",

          div(
            style = "text-align: center;",

            div(
              style = "font-size: 14px; margin-bottom: 8px; opacity: 0.9;",
              "EVPI (Per Person)"
            ),

            div(
              style = "font-size: 36px; font-weight: 700; margin-bottom: 15px;",
              sprintf("£%.2f", evpi$evpi_per_person)
            ),

            div(
              style = "font-size: 14px; margin-bottom: 5px; opacity: 0.9;",
              "Population EVPI"
            ),

            div(
              style = "font-size: 28px; font-weight: 600;",
              sprintf("£%.2f million", evpi$evpi_population / 1000000)
            )
          )
        ),

        div(
          style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px;",

          tags$dl(
            style = "margin: 0; display: grid; grid-template-columns: 2fr 1fr; gap: 10px;",

            tags$dt(style = "color: #6B7280;", "Effective Population:"),
            tags$dd(style = "color: #1F2937; font-weight: 600; text-align: right;",
                    format(round(evpi$effective_population), big.mark = ",")),

            tags$dt(style = "color: #6B7280;", "Time Horizon:"),
            tags$dd(style = "color: #1F2937; font-weight: 600; text-align: right;",
                    sprintf("%d years", evpi$time_horizon)),

            tags$dt(style = "color: #6B7280;", "Discount Rate:"),
            tags$dd(style = "color: #1F2937; font-weight: 600; text-align: right;",
                    sprintf("%.1f%%", evpi$discount_rate * 100)),

            tags$dt(style = "color: #6B7280;", "EV with Perfect Info:"),
            tags$dd(style = "color: #1F2937; font-weight: 600; text-align: right;",
                    sprintf("£%.0f", evpi$ev_perfect_info)),

            tags$dt(style = "color: #6B7280;", "EV with Current Info:"),
            tags$dd(style = "color: #1F2937; font-weight: 600; text-align: right;",
                    sprintf("£%.0f", evpi$ev_current_info))
          )
        ),

        div(
          style = "margin-top: 20px; background: #F9FAFB; padding: 15px; border-radius: 8px;",

          h6("Research Recommendation:", style = "color: #1F2937; margin-bottom: 10px;"),

          if (evpi$evpi_population > 5000000) {
            div(
              style = "background: #DCFCE7; border-left: 4px solid #10B981; padding: 12px; border-radius: 4px;",
              div(
                strong(icon("check-circle", style = "color: #10B981; margin-right: 5px;"), "HIGH PRIORITY"),
                style = "color: #065F46; margin-bottom: 5px;"
              ),
              p(
                sprintf("Population EVPI of £%.1fM suggests further research is likely cost-effective. Proceed with EVPPI analysis to identify key parameters.",
                        evpi$evpi_population / 1000000),
                style = "margin: 0; color: #065F46; font-size: 14px;"
              )
            )
          } else if (evpi$evpi_population > 1000000) {
            div(
              style = "background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 12px; border-radius: 4px;",
              div(
                strong(icon("exclamation-circle", style = "color: #F59E0B; margin-right: 5px;"), "MODERATE PRIORITY"),
                style = "color: #92400E; margin-bottom: 5px;"
              ),
              p(
                sprintf("Population EVPI of £%.1fM suggests research may be cost-effective if focused on high-value parameters.",
                        evpi$evpi_population / 1000000),
                style = "margin: 0; color: #92400E; font-size: 14px;"
              )
            )
          } else {
            div(
              style = "background: #FEE2E2; border-left: 4px solid #EF4444; padding: 12px; border-radius: 4px;",
              div(
                strong(icon("times-circle", style = "color: #EF4444; margin-right: 5px;"), "LOW PRIORITY"),
                style = "color: #991B1B; margin-bottom: 5px;"
              ),
              p(
                sprintf("Population EVPI of £%.1fM suggests limited value from further research. Current evidence may be sufficient for decision-making.",
                        evpi$evpi_population / 1000000),
                style = "margin: 0; color: #991B1B; font-size: 14px;"
              )
            )
          }
        )
      )
    })
  })
}
