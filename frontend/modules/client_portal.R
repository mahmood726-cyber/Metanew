# Client-Facing Portal Module - White-label Read-only View
library(shiny)

client_portal_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Client Portal: Publish & Share"),
      layout_columns(
        col_widths = c(5, 7),
        card(
          h5("Portal Settings"),
          textInput(ns("portal_title"), "Portal Title", "Meta-Analysis Results"),
          textInput(ns("client_name"), "Client Name", ""),
          selectInput(ns("branding_color"), "Brand Color",
                      choices = c("Blue" = "#0066CC", "Green" = "#28a745",
                                 "Red" = "#dc3545", "Purple" = "#6f42c1")),
          textInput(ns("logo_url"), "Logo URL (optional)", ""),
          hr(),
          h5("Content to Include"),
          checkboxGroupInput(ns("include_content"),
                            "Select Content",
                            choices = c("Forest Plots" = "forest",
                                       "Funnel Plots" = "funnel",
                                       "Results Tables" = "tables",
                                       "HE Analysis" = "economics",
                                       "Protocol" = "protocol"),
                            selected = c("forest", "tables")),
          hr(),
          h5("Access Control"),
          checkboxInput(ns("password_protect"), "Password Protection", FALSE),
          conditionalPanel(
            condition = "input.password_protect == true",
            ns = ns,
            passwordInput(ns("portal_password"), "Portal Password")
          ),
          hr(),
          actionButton(ns("btn_generate"), "Generate Portal", class = "btn-success w-100 mb-2"),
          actionButton(ns("btn_preview"), "Preview", class = "btn-secondary w-100")
        ),
        card(
          h5("Generated Portals"),
          DTOutput(ns("portals_table")),
          hr(),
          uiOutput(ns("portal_info"))
        )
      )
    )
  )
}

client_portal_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    portals <- reactiveVal(data.frame(
      ID = character(),
      Title = character(),
      Client = character(),
      Created = character(),
      URL = character(),
      stringsAsFactors = FALSE
    ))

    observeEvent(input$btn_generate, {
      req(input$portal_title)

      withProgress(message = "Generating client portal...", {
        tryCatch({
          # Generate unique portal ID
          portal_id <- paste0("portal_", format(Sys.time(), "%Y%m%d_%H%M%S"))

          # Create portal directory
          portal_dir <- file.path("outputs", "portals", portal_id)
          dir.create(portal_dir, recursive = TRUE, showWarnings = FALSE)

          # Generate portal app
          generate_portal_app(
            portal_dir = portal_dir,
            title = input$portal_title,
            client_name = input$client_name,
            branding_color = input$branding_color,
            logo_url = input$logo_url,
            include_content = input$include_content,
            password_protected = input$password_protect,
            password = if (input$password_protect) input$portal_password else NULL,
            data = rv
          )

          # Add to portals table
          new_portal <- data.frame(
            ID = portal_id,
            Title = input$portal_title,
            Client = input$client_name,
            Created = format(Sys.time(), "%Y-%m-%d %H:%M"),
            URL = file.path("portals", portal_id, "app.R"),
            stringsAsFactors = FALSE
          )

          portals(rbind(portals(), new_portal))

          showNotification(
            paste("✓ Portal generated:", portal_id),
            type = "message",
            duration = 10
          )

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    observeEvent(input$btn_preview, {
      showModal(modalDialog(
        title = "Portal Preview",
        size = "l",
        generate_portal_preview(input, rv),
        footer = modalButton("Close")
      ))
    })

    output$portals_table <- renderDT({
      datatable(portals(), selection = "single", options = list(pageLength = 10))
    })

    output$portal_info <- renderUI({
      if (nrow(portals()) == 0) {
        return(div(class = "alert alert-info",
                   icon("info-circle"), " No portals generated yet."))
      }

      selected <- input$portals_table_rows_selected
      if (length(selected) == 0) {
        return(div(class = "alert alert-secondary",
                   "Select a portal to view details"))
      }

      portal <- portals()[selected, ]

      div(
        class = "alert alert-success",
        h5(icon("globe"), " Portal Details"),
        tags$ul(
          tags$li(tags$strong("ID:"), portal$ID),
          tags$li(tags$strong("Title:"), portal$Title),
          tags$li(tags$strong("Client:"), portal$Client),
          tags$li(tags$strong("Created:"), portal$Created)
        ),
        hr(),
        h6("Access Instructions:"),
        p("Share the following command with your client:"),
        tags$code(
          sprintf("shiny::runApp('%s')", file.path("outputs/portals", portal$ID))
        ),
        hr(),
        actionButton(session$ns("btn_open"), "Open Portal", class = "btn-primary w-100")
      )
    })

    return(reactive(portals()))
  })
}

generate_portal_app <- function(portal_dir, title, client_name, branding_color,
                                 logo_url, include_content, password_protected,
                                 password, data) {

  # Create app.R for portal
  app_content <- sprintf('
library(shiny)
library(bslib)
library(DT)
library(plotly)

# Portal Configuration
PORTAL_TITLE <- "%s"
CLIENT_NAME <- "%s"
BRANDING_COLOR <- "%s"
PASSWORD_PROTECTED <- %s
PORTAL_PASSWORD <- "%s"

ui <- page_navbar(
  title = PORTAL_TITLE,
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = BRANDING_COLOR),
  fillable = TRUE,

  nav_panel(
    title = "Overview",
    icon = icon("home"),
    card(
      card_header(paste("Meta-Analysis Results for", CLIENT_NAME)),
      p("This portal provides read-only access to the meta-analysis results."),
      p("Use the tabs above to explore different aspects of the analysis."),
      hr(),
      p(tags$small("Generated:", format(Sys.time(), "%%Y-%%m-%%d %%H:%%M")))
    )
  ),

  %s

  nav_spacer(),
  nav_item(tags$small(paste("Client:", CLIENT_NAME)))
)

server <- function(input, output, session) {
  # Authentication if enabled
  if (PASSWORD_PROTECTED) {
    observeEvent(session$input$password_submit, {
      if (input$password != PORTAL_PASSWORD) {
        showNotification("Invalid password", type = "error")
      }
    })
  }

  # Server logic would go here
}

shinyApp(ui = ui, server = server)
', title, client_name, branding_color,
    ifelse(password_protected, "TRUE", "FALSE"),
    ifelse(password_protected, password, ""),
    generate_portal_tabs(include_content))

  # Write app.R
  writeLines(app_content, file.path(portal_dir, "app.R"))

  # Save data objects
  if (!is.null(data$pairwise_results)) {
    saveRDS(data$pairwise_results, file.path(portal_dir, "results.rds"))
  }

  # Copy plots if they exist
  plot_dir <- file.path(portal_dir, "plots")
  dir.create(plot_dir, showWarnings = FALSE)

  return(portal_dir)
}

generate_portal_tabs <- function(include_content) {
  tabs <- list()

  if ("forest" %in% include_content) {
    tabs[[length(tabs) + 1]] <- '
  nav_panel(
    title = "Forest Plots",
    icon = icon("chart-bar"),
    card(plotlyOutput("forest_plot"))
  )'
  }

  if ("tables" %in% include_content) {
    tabs[[length(tabs) + 1]] <- '
  nav_panel(
    title = "Results Tables",
    icon = icon("table"),
    card(DTOutput("results_table"))
  )'
  }

  if ("economics" %in% include_content) {
    tabs[[length(tabs) + 1]] <- '
  nav_panel(
    title = "Health Economics",
    icon = icon("pound-sign"),
    card(
      verbatimTextOutput("he_results")
    )
  )'
  }

  paste(tabs, collapse = ",\n  ")
}

generate_portal_preview <- function(input, rv) {
  tagList(
    div(
      style = paste0("background-color: ", input$branding_color, "; color: white; padding: 20px;"),
      h3(input$portal_title),
      if (nchar(input$client_name) > 0) p(paste("Client:", input$client_name))
    ),
    hr(),
    h5("Content Included:"),
    tags$ul(
      lapply(input$include_content, function(x) {
        tags$li(switch(x,
                      "forest" = "Forest Plots",
                      "funnel" = "Funnel Plots",
                      "tables" = "Results Tables",
                      "economics" = "Health Economics Analysis",
                      "protocol" = "Research Protocol"))
      })
    ),
    if (input$password_protect) {
      div(class = "alert alert-warning",
          icon("lock"), " Password protection enabled")
    }
  )
}
