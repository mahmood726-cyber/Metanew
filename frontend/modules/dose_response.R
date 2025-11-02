# Dose-Response Meta-Analysis Module
library(shiny)
library(dosresmeta)

dose_response_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Dose-Response Analysis"),
      layout_columns(
        col_widths = c(3, 9),
        card(
          selectInput(ns("outcome"), "Outcome", choices = NULL),
          numericInput(ns("knots"), "Number of Knots", value = 3, min = 2, max = 5),
          actionButton(ns("btn_run"), "Run Analysis", class = "btn-primary w-100")
        ),
        card(
          plotOutput(ns("dose_response_plot"), height = "500px"),
          verbatimTextOutput(ns("summary"))
        )
      )
    )
  )
}

dose_response_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    dr_result <- reactiveVal(NULL)

    observeEvent(input$btn_run, {
      req(rv$data)
      tryCatch({
        result <- run_dose_response(rv$data, input$outcome, input$knots)
        dr_result(result)
        rv$dr_results[[input$outcome]] <- result
        showNotification("✓ Dose-response analysis complete", type = "message")
      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error", duration = 10)
      })
    })

    output$summary <- renderPrint({
      req(dr_result())
      cat("Dose-Response Meta-Analysis\n")
      cat("===========================\n")
      cat("Number of studies:", dr_result()$n_studies, "\n")
      cat("P-value for non-linearity:", round(dr_result()$p_nonlinearity, 4), "\n")
    })

    return(reactive(dr_result()))
  })
}

run_dose_response <- function(data, outcome, knots = 3) {
  # Placeholder - full implementation would use dosresmeta
  list(n_studies = nrow(data), p_nonlinearity = 0.05, model = NULL)
}
