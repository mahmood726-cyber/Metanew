# EvidenceOS PRIME - Main Shiny Application
# Complete meta-analysis and health economics platform

library(shiny)
library(bslib)
library(DT)
library(plotly)
library(shinyvalidate)
library(metafor)
library(netmeta)
library(dosresmeta)

# Source modules
source("modules/data_import.R")
source("modules/protocol.R")
source("modules/meta_pairwise.R")
source("modules/nma.R")
source("modules/dose_response.R")
source("modules/risk_of_bias.R")  # RoB 2.0 tool
source("modules/sensitivity.R")
source("modules/he_params.R")
source("modules/he_model.R")
source("modules/he_bcea.R")
source("modules/reporting.R")
source("modules/audit.R")
source("modules/ai_copilot.R")
source("modules/v2_features.R")

# Source utilities
source("utils/python_bridge.R")
source("utils/plotting.R")
source("utils/validators.R")
source("utils/rob2_tool.R")  # RoB 2.0 utility functions

# Define UI
ui <- page_navbar(
  title = "EvidenceOS PRIME",
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#0066CC",
    base_font = font_google("Inter")
  ),
  fillable = TRUE,

  # Tab: Data Import
  nav_panel(
    title = "Data",
    icon = icon("database"),
    data_import_ui("data_import")
  ),

  # Tab: Protocol
  nav_panel(
    title = "Protocol",
    icon = icon("file-text"),
    protocol_ui("protocol")
  ),

  # Tab: Risk of Bias (RoB 2.0)
  nav_panel(
    title = "Quality",
    icon = icon("clipboard-check"),
    risk_of_bias_ui("rob")
  ),

  # Tab: Analysis
  nav_panel(
    title = "Analysis",
    icon = icon("chart-line"),
    navset_card_tab(
      nav_panel(
        "Pairwise MA",
        meta_pairwise_ui("pairwise")
      ),
      nav_panel(
        "Network MA",
        nma_ui("nma")
      ),
      nav_panel(
        "Dose-Response",
        dose_response_ui("dose_response")
      )
    )
  ),

  # Tab: Sensitivity
  nav_panel(
    title = "Sensitivity",
    icon = icon("sliders"),
    sensitivity_ui("sensitivity")
  ),

  # Tab: Economics
  nav_panel(
    title = "Economics",
    icon = icon("pound-sign"),
    navset_card_tab(
      nav_panel(
        "Parameters",
        he_params_ui("he_params")
      ),
      nav_panel(
        "Model",
        he_model_ui("he_model")
      ),
      nav_panel(
        "Results (BCEA)",
        he_bcea_ui("he_bcea")
      )
    )
  ),

  # Tab: Reports & Export
  nav_panel(
    title = "Reports",
    icon = icon("file-pdf"),
    navset_card_tab(
      nav_panel(
        "Generate Reports",
        reporting_ui("reporting")
      ),
      nav_panel(
        "Audit Trail",
        audit_ui("audit")
      )
    )
  ),

  # Tab: Advanced (collapsed features)
  nav_menu(
    title = "Advanced",
    icon = icon("cog"),
    nav_panel(
      "AI Copilot",
      ai_copilot_ui("ai_copilot")
    ),
    nav_panel(
      "Beta Features",
      v2_features_ui("v2_features")
    )
  ),

  # Sidebar for global controls
  sidebar = sidebar(
    width = 250,
    h4("Session Info"),
    textOutput("session_info"),
    hr(),
    h5("Quick Actions"),
    actionButton("btn_save_session", "Save Session", class = "btn-primary w-100 mb-2"),
    actionButton("btn_load_session", "Load Session", class = "btn-secondary w-100 mb-2"),
    actionButton("btn_export_json", "Export JSON", class = "btn-info w-100 mb-2"),
    hr(),
    h5("API Status"),
    textOutput("api_status"),
    hr(),
    tags$small(
      class = "text-muted",
      "EvidenceOS PRIME v2.0.0",
      br(),
      "© 2025"
    )
  )
)

# Define Server
server <- function(input, output, session) {

  # Reactive values for global state
  rv <- reactiveValues(
    evidence_object = NULL,
    data = NULL,
    protocol = NULL,
    pairwise_results = list(),
    nma_results = list(),
    dr_results = list(),
    he_results = NULL,
    audit_log = list()
  )

  # Session info
  output$session_info <- renderText({
    paste0(
      "Session ID: ", substr(session$token, 1, 8), "\n",
      "Started: ", format(Sys.time(), "%H:%M:%S")
    )
  })

  # API status check
  output$api_status <- renderText({
    tryCatch({
      status <- check_api_health()
      if (status$healthy) {
        "✓ API Connected"
      } else {
        "✗ API Offline"
      }
    }, error = function(e) {
      "✗ API Unavailable"
    })
  })

  # Module servers
  data_results <- data_import_server("data_import", rv)
  protocol_results <- protocol_server("protocol", rv)
  rob_results <- risk_of_bias_server("rob", rv)  # RoB 2.0 module
  pairwise_results <- meta_pairwise_server("pairwise", rv)
  nma_results <- nma_server("nma", rv)
  dr_results <- dose_response_server("dose_response", rv)
  sensitivity_results <- sensitivity_server("sensitivity", rv)
  he_params_results <- he_params_server("he_params", rv)
  he_model_results <- he_model_server("he_model", rv)
  he_bcea_results <- he_bcea_server("he_bcea", rv)
  ai_copilot_results <- ai_copilot_server("ai_copilot", rv)
  reporting_results <- reporting_server("reporting", rv)
  audit_results <- audit_server("audit", rv)
  v2_results <- v2_features_server("v2_features", rv)

  # Save session handler
  observeEvent(input$btn_save_session, {
    tryCatch({
      # Create EvidenceObject
      eo <- create_evidence_object(rv)

      # Save to file
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      filename <- paste0("outputs/session_", timestamp, ".json")

      jsonlite::write_json(eo, filename, pretty = TRUE, auto_unbox = TRUE)

      showNotification(
        paste("Session saved:", filename),
        type = "message",
        duration = 5
      )

      # Add audit entry
      add_audit_entry(rv, "session_saved", list(file = filename))

    }, error = function(e) {
      showNotification(
        paste("Error saving session:", e$message),
        type = "error",
        duration = 10
      )
    })
  })

  # Load session handler
  observeEvent(input$btn_load_session, {
    showModal(modalDialog(
      title = "Load Session",
      fileInput("load_file", "Choose JSON file", accept = ".json"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("btn_load_confirm", "Load")
      )
    ))
  })

  # Export JSON handler
  observeEvent(input$btn_export_json, {
    tryCatch({
      eo <- create_evidence_object(rv)
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      filename <- paste0("outputs/evidence_", timestamp, ".json")

      jsonlite::write_json(eo, filename, pretty = TRUE, auto_unbox = TRUE)

      showNotification(
        paste("Evidence object exported:", filename),
        type = "message",
        duration = 5
      )

    }, error = function(e) {
      showNotification(
        paste("Error exporting:", e$message),
        type = "error",
        duration = 10
      )
    })
  })
}

# Helper function to create EvidenceObject
create_evidence_object <- function(rv) {
  list(
    evidence_id = paste0("EVO_", format(Sys.time(), "%Y%m%d_%H%M%S")),
    version = "2.0.0",
    created_at = Sys.time(),
    updated_at = Sys.time(),
    protocol = rv$protocol,
    studies = if (!is.null(rv$data)) unique(rv$data$study_id) else list(),
    observations = if (!is.null(rv$data)) nrow(rv$data) else 0,
    pairwise_results = rv$pairwise_results,
    nma_results = rv$nma_results,
    dose_response_results = rv$dr_results,
    economic_results = rv$he_results,
    audit_trail = rv$audit_log
  )
}

# Helper function to add audit entries
add_audit_entry <- function(rv, action, details = list()) {
  entry <- list(
    timestamp = Sys.time(),
    action = action,
    user = Sys.getenv("USER"),
    details = details
  )
  rv$audit_log[[length(rv$audit_log) + 1]] <- entry
}

# Run the application
shinyApp(ui = ui, server = server)
