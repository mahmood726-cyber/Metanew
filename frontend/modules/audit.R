# Audit Module
# Dependencies: shiny (loaded in app.R)

audit_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header("Audit Trail"),
    DTOutput(ns("audit_table")),
    downloadButton(ns("btn_download"), "Download Audit Log")
  )
}

audit_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    output$audit_table <- renderDT({
      req(rv$audit_log)

      audit_df <- do.call(rbind, lapply(rv$audit_log, function(entry) {
        data.frame(
          Timestamp = format(entry$timestamp, "%Y-%m-%d %H:%M:%S"),
          Action = entry$action,
          User = entry$user,
          Details = jsonlite::toJSON(entry$details, auto_unbox = TRUE),
          stringsAsFactors = FALSE
        )
      }))

      datatable(audit_df, options = list(pageLength = 20, order = list(list(0, 'desc'))))
    })

    output$btn_download <- downloadHandler(
      filename = function() {
        paste0("audit_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".json")
      },
      content = function(file) {
        jsonlite::write_json(rv$audit_log, file, pretty = TRUE, auto_unbox = TRUE)
      }
    )

    return(reactive(rv$audit_log))
  })
}
