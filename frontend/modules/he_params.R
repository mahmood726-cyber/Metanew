# Health Economics Parameters Module
library(shiny)

he_params_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Health Economic Parameters"),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("General Settings"),
          selectInput(ns("country"), "Country", choices = c("UK", "US", "Germany", "France")),
          numericInput(ns("wtp"), "Willingness-to-Pay Threshold", 20000, min = 0),
          numericInput(ns("discount"), "Discount Rate (%)", 3.5, min = 0, max = 10),
          numericInput(ns("horizon"), "Time Horizon (years)", 10, min = 1, max = 50)
        ),
        card(
          card_header("Utilities"),
          numericInput(ns("util_stable"), "Utility: Stable", 0.80, min = 0, max = 1, step = 0.01),
          numericInput(ns("util_prog"), "Utility: Progressed", 0.50, min = 0, max = 1, step = 0.01),
          numericInput(ns("util_dead"), "Utility: Dead", 0.0, min = 0, max = 1, step = 0.01)
        )
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("Costs (Annual)"),
          numericInput(ns("cost_stable"), "Cost: Stable State", 1000, min = 0),
          numericInput(ns("cost_prog"), "Cost: Progressed State", 5000, min = 0),
          numericInput(ns("cost_treatment"), "Cost: Treatment", 10000, min = 0),
          numericInput(ns("cost_comparator"), "Cost: Comparator", 2000, min = 0)
        ),
        card(
          card_header("Transition Parameters"),
          numericInput(ns("hr_prog"), "HR: Progression", 0.70, min = 0, max = 2, step = 0.01),
          numericInput(ns("hr_death"), "HR: Death", 0.80, min = 0, max = 2, step = 0.01),
          numericInput(ns("psa_iter"), "PSA Iterations", 1000, min = 100, max = 10000, step = 100)
        )
      ),
      actionButton(ns("btn_save"), "Save Parameters", class = "btn-primary")
    )
  )
}

he_params_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    observeEvent(input$btn_save, {
      params <- list(
        country = input$country,
        wtp_threshold = input$wtp,
        discount_rate = input$discount / 100,
        time_horizon = input$horizon,
        utility_stable = input$util_stable,
        utility_progressed = input$util_prog,
        utility_dead = input$util_dead,
        cost_stable = input$cost_stable,
        cost_progressed = input$cost_prog,
        cost_treatment = input$cost_treatment,
        cost_comparator = input$cost_comparator,
        hr_progression = input$hr_prog,
        hr_death = input$hr_death,
        n_iterations = input$psa_iter
      )

      rv$he_params <- params
      showNotification("✓ Parameters saved", type = "message")
    })

    return(reactive(rv$he_params))
  })
}
