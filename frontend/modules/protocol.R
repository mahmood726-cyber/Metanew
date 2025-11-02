# Protocol Module - PICO Entry
library(shiny)

protocol_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header("Research Protocol (PICO)"),
    layout_columns(
      col_widths = c(6, 6),
      card(
        textInput(ns("title"), "Protocol Title"),
        textAreaInput(ns("population"), "Population", rows = 3),
        textAreaInput(ns("intervention"), "Intervention", rows = 3),
        textAreaInput(ns("comparator"), "Comparator", rows = 3),
        textAreaInput(ns("outcomes"), "Outcomes (comma-separated)", rows = 2)
      ),
      card(
        textAreaInput(ns("inclusion"), "Inclusion Criteria (one per line)", rows = 4),
        textAreaInput(ns("exclusion"), "Exclusion Criteria (one per line)", rows = 4),
        actionButton(ns("btn_save"), "Save Protocol", class = "btn-primary w-100")
      )
    )
  )
}

protocol_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    observeEvent(input$btn_save, {
      protocol <- list(
        protocol_id = paste0("PROT_", format(Sys.time(), "%Y%m%d_%H%M%S")),
        title = input$title,
        population = input$population,
        intervention = input$intervention,
        comparator = input$comparator,
        outcomes = strsplit(input$outcomes, ",")[[1]],
        inclusion_criteria = strsplit(input$inclusion, "\n")[[1]],
        exclusion_criteria = strsplit(input$exclusion, "\n")[[1]],
        created_at = Sys.time(),
        version = "1.0"
      )

      rv$protocol <- protocol
      showNotification("✓ Protocol saved", type = "message")
    })

    return(reactive(rv$protocol))
  })
}
