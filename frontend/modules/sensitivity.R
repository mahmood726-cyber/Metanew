# Sensitivity Analysis Module
library(shiny)

sensitivity_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Interactive Sensitivity Explorer"),
      layout_columns(
        col_widths = c(3, 9),
        card(
          h5("Filters"),
          checkboxGroupInput(ns("exclude_rob"), "Exclude Risk of Bias",
                             choices = c("High", "Unclear", "Low")),
          sliderInput(ns("min_sample"), "Minimum Sample Size", 0, 1000, 0),
          checkboxInput(ns("leave_one_out"), "Leave-One-Out Analysis", FALSE),
          actionButton(ns("btn_apply"), "Apply & Re-run", class = "btn-success w-100")
        ),
        card(
          plotlyOutput(ns("sensitivity_forest")),
          DTOutput(ns("sensitivity_table"))
        )
      )
    )
  )
}

sensitivity_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    filtered_data <- reactive({
      req(rv$data)
      data <- rv$data

      if (length(input$exclude_rob) > 0 && "risk_of_bias" %in% names(data)) {
        data <- data[!data$risk_of_bias %in% input$exclude_rob, ]
      }

      if (input$min_sample > 0 && "n" %in% names(data)) {
        data <- data[data$n >= input$min_sample, ]
      }

      data
    })

    observeEvent(input$btn_apply, {
      showNotification(paste("Re-running with", nrow(filtered_data()), "studies"), type = "message")
      rv$data_filtered <- filtered_data()
    })

    return(reactive(filtered_data()))
  })
}
