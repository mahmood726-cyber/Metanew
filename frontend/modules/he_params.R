# Health Economics Parameters Module
library(shiny)

# Load config loader utility
source("utils/config_loader.R", local = TRUE)

he_params_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Health Economic Parameters"),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("General Settings"),
          selectInput(ns("country"), "Country",
                      choices = c("UK" = "uk", "US" = "us", "Germany" = "germany",
                                "France" = "france", "Canada" = "canada"),
                      selected = "uk"),
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

    # Load country config when country selection changes
    observeEvent(input$country, {
      tryCatch({
        config <- load_country_config(input$country)

        # Update all inputs with config values
        updateNumericInput(session, "wtp",
                          value = config$wtp$primary_threshold)
        updateNumericInput(session, "discount",
                          value = config$discounting$costs * 100)  # Convert to %
        updateNumericInput(session, "horizon",
                          value = config$time_horizon$default)
        updateNumericInput(session, "util_stable",
                          value = config$utilities$stable_disease)
        updateNumericInput(session, "util_prog",
                          value = config$utilities$progressed_disease)
        updateNumericInput(session, "cost_stable",
                          value = config$costs$health_state_stable$default)
        updateNumericInput(session, "cost_prog",
                          value = config$costs$health_state_progressed$default)
        updateNumericInput(session, "cost_treatment",
                          value = config$costs$drug_treatment$default)
        updateNumericInput(session, "cost_comparator",
                          value = config$costs$drug_comparator$default)
        updateNumericInput(session, "psa_iter",
                          value = config$psa$n_iterations)

        showNotification(
          sprintf("✓ Loaded %s parameters", config$country),
          type = "message", duration = 3
        )
      }, error = function(e) {
        showNotification(
          paste("Error loading config:", e$message),
          type = "warning", duration = 5
        )
      })
    }, ignoreInit = FALSE)  # Run on initialization to load default (UK)

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
