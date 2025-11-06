# ==============================================================================
# EvidenceOS PRIME - Main Application (bs4Dash)
# ==============================================================================
#
# Professional admin dashboard for meta-analysis and health economics
# Built with bs4Dash (AdminLTE 3) for polished, production-ready interface
#
# AUTHOR: EvidenceOS Development Team
# LAST UPDATED: 2025-11-06
# ==============================================================================

# ==============================================================================
# REQUIRED LIBRARIES - All dependencies loaded here (not in modules)
# ==============================================================================

# Core Shiny
library(shiny)
library(bs4Dash)
library(bslib)       # Modern UI components (value_box, cards)
library(DT)          # Data tables
library(shinyvalidate) # Input validation

# Visualization
library(plotly)      # Interactive plots
library(ggplot2)     # Static plots
library(gridExtra)   # Plot arrangements
library(colourpicker) # Color picker input

# Meta-analysis
library(metafor)     # Core meta-analysis
library(netmeta)     # Network meta-analysis
library(dosresmeta)  # Dose-response meta-analysis
library(lavaan)      # Structural equation modeling
library(metaSEM)     # Meta-analytic SEM
library(semPlot)     # SEM plotting

# Data manipulation
library(dplyr)       # Data manipulation
suppressMessages(library(tidyr))  # Data reshaping
library(Matrix)      # Matrix operations

# Publication tools
library(gt)          # GRADE tables
library(readxl)      # Excel file reading
library(officer)     # Word document generation
library(rmarkdown)   # Report generation

# API & JSON (for AI Copilot)
library(httr)        # HTTP requests
library(jsonlite)    # JSON parsing

# ==============================================================================
# LOGGING & OPTIMIZATION SETUP
# ==============================================================================

# Initialize logging system first
source("utils/logging.R")
set_log_level("INFO")
set_log_output("console")
log_session_start()

# Load optimization utilities
log_info("Loading performance optimizations...")
source("utils/ui_optimizations.R", local = TRUE)
source("utils/publication_cache.R", local = TRUE)
source("utils/extreme_optimizations.R", local = TRUE)

# Pre-compile functions for speed
log_info("Pre-compiling functions for faster execution...")
precompile_functions()

# Initialize caches
log_info("Initializing publication cache...")
precompute_publication_cache(NULL)

# Source modules
source("modules/data_import.R")
source("modules/protocol.R")
source("modules/meta_pairwise.R")
source("modules/nma.R")
source("modules/dose_response.R")
source("modules/masem.R")  # Meta-Analytic SEM
source("modules/sensitivity.R")
source("modules/he_params.R")
source("modules/he_model.R")
source("modules/he_bcea.R")
source("modules/he_budget_impact.R")
source("modules/reporting.R")
source("modules/audit.R")
source("modules/ai_copilot.R")
source("modules/v2_features.R")
source("modules/client_portal.R")
source("modules/living_ma.R")

# Publication Tools Modules (NEW)
source("modules/prisma_generator.R")
source("modules/rob_assessment.R")
source("modules/grade_profile.R")
source("modules/interactive_plots.R")

# Source utilities
source("utils/python_bridge.R")
source("utils/plotting.R")
source("utils/validators.R")
source("utils/sample_data_loader.R")

# ==============================================================================
# UI
# ==============================================================================

ui <- dashboardPage(
  # ============================================================================
  # HEADER
  # ============================================================================
  header = dashboardHeader(
    title = dashboardBrand(
      title = "EvidenceOS PRIME",
      color = "primary",
      href = "#",
      image = NULL
    ),

    # Right-side controls
    rightUi = tagList(
      # Theme customizer button
      dropdownMenu(
        type = "messages",
        badgeStatus = NULL,
        icon = icon("palette"),
        headerText = "Theme Customizer",

        dropdownMenuItem(
          text = "Professional Blue",
          icon = icon("circle", class = "text-primary"),
          inputId = "theme_professional"
        ),
        dropdownMenuItem(
          text = "Academic Green",
          icon = icon("circle", class = "text-success"),
          inputId = "theme_academic"
        ),
        dropdownMenuItem(
          text = "Medical Red",
          icon = icon("circle", class = "text-danger"),
          inputId = "theme_medical"
        ),
        dropdownMenuItem(
          text = "Modern Purple",
          icon = icon("circle", class = "text-purple"),
          inputId = "theme_modern"
        ),
        dropdownMenuItem(
          divider = TRUE
        ),
        dropdownMenuItem(
          text = "Toggle Dark Mode",
          icon = icon("moon"),
          inputId = "toggle_dark_mode"
        )
      ),

      # User menu
      dropdownMenu(
        type = "notifications",
        icon = icon("user-circle"),
        badgeStatus = NULL,
        headerText = "Session Info",

        dropdownMenuItem(
          text = "Save Session",
          icon = icon("save"),
          inputId = "save_session_header"
        ),
        dropdownMenuItem(
          text = "Load Session",
          icon = icon("folder-open"),
          inputId = "load_session_header"
        ),
        dropdownMenuItem(
          divider = TRUE
        ),
        dropdownMenuItem(
          text = "Export JSON",
          icon = icon("download"),
          inputId = "export_json_header"
        )
      )
    )
  ),

  # ============================================================================
  # SIDEBAR
  # ============================================================================
  sidebar = dashboardSidebar(
    skin = "light",
    status = "primary",
    elevation = 2,
    collapsed = FALSE,
    minified = TRUE,
    expandOnHover = TRUE,

    sidebarMenu(
      id = "sidebar_menu",

      # Dashboard Home
      menuItem(
        "Dashboard",
        tabName = "dashboard",
        icon = icon("tachometer-alt")
      ),

      # Data Section
      sidebarHeader("DATA MANAGEMENT"),
      menuItem(
        "Data Import",
        tabName = "data_import",
        icon = icon("database")
      ),
      menuItem(
        "Protocol",
        tabName = "protocol",
        icon = icon("file-contract")
      ),

      # Analysis Section
      sidebarHeader("ANALYSIS"),
      menuItem(
        "Meta-Analysis",
        icon = icon("chart-line"),
        startExpanded = FALSE,
        menuSubItem("Pairwise MA", tabName = "pairwise_ma", icon = icon("arrow-right")),
        menuSubItem("Network MA", tabName = "network_ma", icon = icon("project-diagram")),
        menuSubItem("Dose-Response", tabName = "dose_response", icon = icon("pills")),
        menuSubItem("MASEM", tabName = "masem", icon = icon("diagram-project"),
                    badgeLabel = "NEW", badgeColor = "info")
      ),
      menuItem(
        "Sensitivity Analysis",
        tabName = "sensitivity",
        icon = icon("sliders-h")
      ),
      menuItem(
        "Living MA",
        tabName = "living_ma",
        icon = icon("arrows-rotate"),
        badgeLabel = "NEW",
        badgeColor = "success"
      ),

      # Health Economics Section
      sidebarHeader("HEALTH ECONOMICS"),
      menuItem(
        "HE Parameters",
        tabName = "he_params",
        icon = icon("calculator")
      ),
      menuItem(
        "HE Model",
        tabName = "he_model",
        icon = icon("sitemap")
      ),
      menuItem(
        "Cost-Effectiveness",
        tabName = "he_bcea",
        icon = icon("chart-area")
      ),
      menuItem(
        "Budget Impact",
        tabName = "budget_impact",
        icon = icon("money-bill-trend-up"),
        badgeLabel = "NEW",
        badgeColor = "success"
      ),

      # Tools Section
      sidebarHeader("TOOLS & REPORTS"),
      menuItem(
        "AI Copilot",
        tabName = "ai_copilot",
        icon = icon("robot"),
        badgeLabel = "AI",
        badgeColor = "info"
      ),
      menuItem(
        "Reports",
        tabName = "reports",
        icon = icon("file-pdf")
      ),
      menuItem(
        "Client Portal",
        tabName = "client_portal",
        icon = icon("globe"),
        badgeLabel = "NEW",
        badgeColor = "success"
      ),

      # Publication Tools Section (NEW)
      sidebarHeader("PUBLICATION TOOLS"),
      menuItem(
        "PRISMA Diagram",
        tabName = "prisma_generator",
        icon = icon("diagram-project"),
        badgeLabel = "NEW",
        badgeColor = "success"
      ),
      menuItem(
        "Risk of Bias",
        tabName = "rob_assessment",
        icon = icon("shield-alt"),
        badgeLabel = "NEW",
        badgeColor = "success"
      ),
      menuItem(
        "GRADE Profile",
        tabName = "grade_profile",
        icon = icon("star"),
        badgeLabel = "NEW",
        badgeColor = "success"
      ),
      menuItem(
        "Interactive Plots",
        tabName = "interactive_plots",
        icon = icon("chart-line"),
        badgeLabel = "NEW",
        badgeColor = "success"
      ),

      # System Section
      sidebarHeader("SYSTEM"),
      menuItem(
        "Audit Trail",
        tabName = "audit",
        icon = icon("history")
      ),
      menuItem(
        "V2 Features",
        tabName = "v2_features",
        icon = icon("rocket"),
        badgeLabel = "BETA",
        badgeColor = "warning"
      )
    ),

    # Sidebar footer
    tags$div(
      class = "sidebar-footer p-3 text-center",
      style = "position: absolute; bottom: 0; width: 100%;",
      tags$small(
        class = "text-muted",
        "EvidenceOS PRIME v2.0.0",
        br(),
        "© 2025"
      )
    )
  ),

  # ============================================================================
  # BODY
  # ============================================================================
  body = dashboardBody(
    # Custom CSS
    tags$head(
      tags$style(HTML("
        /* Professional improvements */
        .main-header .navbar {
          background: linear-gradient(135deg, #0066CC 0%, #004d99 100%) !important;
        }

        .brand-link {
          font-weight: 600;
          letter-spacing: 0.5px;
        }

        .sidebar-menu .nav-link {
          transition: all 0.3s ease;
        }

        .sidebar-menu .nav-link:hover {
          background: rgba(0, 102, 204, 0.1);
          padding-left: 20px;
        }

        .box {
          box-shadow: 0 2px 4px rgba(0,0,0,0.08);
          border-radius: 8px;
          transition: all 0.3s ease;
        }

        .box:hover {
          box-shadow: 0 4px 12px rgba(0,0,0,0.12);
          transform: translateY(-2px);
        }

        /* Glassmorphism for cards */
        .card {
          backdrop-filter: blur(10px);
          background: rgba(255, 255, 255, 0.95) !important;
        }

        /* Dark mode */
        .dark-mode .content-wrapper {
          background: #1a1a1a;
        }

        .dark-mode .card {
          background: rgba(30, 30, 30, 0.95) !important;
          border-color: rgba(255, 255, 255, 0.1);
          color: #e0e0e0;
        }

        /* Value boxes */
        .small-box {
          border-radius: 8px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.1);
          transition: all 0.3s ease;
        }

        .small-box:hover {
          transform: translateY(-4px);
          box-shadow: 0 4px 16px rgba(0,0,0,0.15);
        }
      "))
    ),

    tabItems(
      # ========================================================================
      # DASHBOARD HOME
      # ========================================================================
      tabItem(
        tabName = "dashboard",

        h2("Dashboard Overview"),

        # Summary boxes
        fluidRow(
          valueBox(
            value = textOutput("n_studies"),
            subtitle = "Studies Loaded",
            icon = icon("database"),
            color = "primary",
            width = 3
          ),
          valueBox(
            value = textOutput("n_analyses"),
            subtitle = "Analyses Completed",
            icon = icon("chart-line"),
            color = "success",
            width = 3
          ),
          valueBox(
            value = textOutput("n_reports"),
            subtitle = "Reports Generated",
            icon = icon("file-pdf"),
            color = "info",
            width = 3
          ),
          valueBox(
            value = textOutput("api_status_dash"),
            subtitle = "API Status",
            icon = icon("server"),
            color = "warning",
            width = 3
          )
        ),

        # Quick start guide
        fluidRow(
          box(
            title = "Quick Start Guide",
            status = "primary",
            solidHeader = TRUE,
            collapsible = TRUE,
            width = 6,

            tags$ol(
              tags$li(
                icon("database"), " ",
                tags$strong("Import Data:"), " Upload your CSV/Excel file or load demo data"
              ),
              tags$li(
                icon("file-contract"), " ",
                tags$strong("Define Protocol:"), " Set your research question and inclusion criteria"
              ),
              tags$li(
                icon("chart-line"), " ",
                tags$strong("Run Analysis:"), " Choose from pairwise, network, or dose-response MA"
              ),
              tags$li(
                icon("calculator"), " ",
                tags$strong("Health Economics:"), " Add cost-effectiveness analysis"
              ),
              tags$li(
                icon("file-pdf"), " ",
                tags$strong("Generate Report:"), " Create publication-ready documents"
              )
            ),

            hr(),

            actionButton(
              "start_demo",
              "⚡ Load Demo Data & Start",
              class = "btn-primary btn-lg btn-block",
              icon = icon("play")
            )
          ),

          box(
            title = "Recent Activity",
            status = "info",
            solidHeader = TRUE,
            collapsible = TRUE,
            width = 6,

            DTOutput("recent_activity_table")
          )
        ),

        # Platform features
        fluidRow(
          box(
            title = "Platform Capabilities",
            status = "success",
            solidHeader = TRUE,
            width = 12,

            fluidRow(
              column(
                width = 4,
                h4(icon("chart-line"), " Meta-Analysis"),
                tags$ul(
                  tags$li("Pairwise meta-analysis"),
                  tags$li("Network meta-analysis"),
                  tags$li("Dose-response meta-analysis"),
                  tags$li("Meta-Analytic SEM (MASEM)"),
                  tags$li("Living meta-analysis"),
                  tags$li("Subgroup & sensitivity analysis")
                )
              ),
              column(
                width = 4,
                h4(icon("calculator"), " Health Economics"),
                tags$ul(
                  tags$li("Cost-effectiveness analysis"),
                  tags$li("Budget impact analysis"),
                  tags$li("BCEA integration"),
                  tags$li("Probabilistic sensitivity"),
                  tags$li("Value of information")
                )
              ),
              column(
                width = 4,
                h4(icon("tools"), " Advanced Tools"),
                tags$ul(
                  tags$li("AI-powered copilot"),
                  tags$li("Automated reporting"),
                  tags$li("Client portals"),
                  tags$li("Audit trail"),
                  tags$li("Protocol management")
                )
              )
            )
          )
        )
      ),

      # ========================================================================
      # DATA IMPORT
      # ========================================================================
      tabItem(
        tabName = "data_import",
        h2("Data Import"),
        data_import_ui("data_import")
      ),

      # ========================================================================
      # PROTOCOL
      # ========================================================================
      tabItem(
        tabName = "protocol",
        h2("Protocol Definition"),
        protocol_ui("protocol")
      ),

      # ========================================================================
      # PAIRWISE MA
      # ========================================================================
      tabItem(
        tabName = "pairwise_ma",
        h2("Pairwise Meta-Analysis"),
        meta_pairwise_ui("pairwise")
      ),

      # ========================================================================
      # NETWORK MA
      # ========================================================================
      tabItem(
        tabName = "network_ma",
        h2("Network Meta-Analysis"),
        nma_ui("nma")
      ),

      # ========================================================================
      # DOSE-RESPONSE
      # ========================================================================
      tabItem(
        tabName = "dose_response",
        h2("Dose-Response Meta-Analysis"),
        dose_response_ui("dose_response")
      ),

      # ========================================================================
      # MASEM (Meta-Analytic SEM)
      # ========================================================================
      tabItem(
        tabName = "masem",
        h2("Meta-Analytic Structural Equation Modeling"),
        masem_ui("masem")
      ),

      # ========================================================================
      # SENSITIVITY
      # ========================================================================
      tabItem(
        tabName = "sensitivity",
        h2("Sensitivity Analysis"),
        sensitivity_ui("sensitivity")
      ),

      # ========================================================================
      # LIVING MA
      # ========================================================================
      tabItem(
        tabName = "living_ma",
        h2("Living Meta-Analysis"),
        living_ma_ui("living_ma")
      ),

      # ========================================================================
      # HE PARAMETERS
      # ========================================================================
      tabItem(
        tabName = "he_params",
        h2("Health Economics Parameters"),
        he_params_ui("he_params")
      ),

      # ========================================================================
      # HE MODEL
      # ========================================================================
      tabItem(
        tabName = "he_model",
        h2("Health Economics Model"),
        he_model_ui("he_model")
      ),

      # ========================================================================
      # HE BCEA
      # ========================================================================
      tabItem(
        tabName = "he_bcea",
        h2("Cost-Effectiveness Analysis (BCEA)"),
        he_bcea_ui("he_bcea")
      ),

      # ========================================================================
      # BUDGET IMPACT
      # ========================================================================
      tabItem(
        tabName = "budget_impact",
        h2("Budget Impact Analysis"),
        he_budget_impact_ui("budget_impact")
      ),

      # ========================================================================
      # AI COPILOT
      # ========================================================================
      tabItem(
        tabName = "ai_copilot",
        h2("AI Copilot"),
        ai_copilot_ui("ai_copilot")
      ),

      # ========================================================================
      # REPORTS
      # ========================================================================
      tabItem(
        tabName = "reports",
        h2("Report Generation"),
        reporting_ui("reporting")
      ),

      # ========================================================================
      # CLIENT PORTAL
      # ========================================================================
      tabItem(
        tabName = "client_portal",
        h2("Client Portal Generator"),
        client_portal_ui("client_portal")
      ),

      # ========================================================================
      # AUDIT
      # ========================================================================
      tabItem(
        tabName = "audit",
        h2("Audit Trail"),
        audit_ui("audit")
      ),

      # ========================================================================
      # V2 FEATURES
      # ========================================================================
      tabItem(
        tabName = "v2_features",
        h2("V2 Features (Beta)"),
        v2_features_ui("v2_features")
      ),

      # ========================================================================
      # PUBLICATION TOOLS (NEW)
      # ========================================================================

      # PRISMA Generator
      tabItem(
        tabName = "prisma_generator",
        h2("PRISMA 2020 Flow Diagram Generator"),
        prisma_generator_ui("prisma_generator")
      ),

      # Risk of Bias Assessment
      tabItem(
        tabName = "rob_assessment",
        h2("Risk of Bias Assessment (RoB 2.0 & ROBINS-I)"),
        rob_assessment_ui("rob_assessment")
      ),

      # GRADE Evidence Profile
      tabItem(
        tabName = "grade_profile",
        h2("GRADE Evidence Profile Generator"),
        grade_profile_ui("grade_profile")
      ),

      # Interactive Plots
      tabItem(
        tabName = "interactive_plots",
        h2("Interactive Forest & Funnel Plots"),
        interactive_plots_ui("interactive_plots")
      )
    )
  ),

  # ============================================================================
  # FOOTER
  # ============================================================================
  footer = dashboardFooter(
    left = "EvidenceOS PRIME v2.0.0 - Meta-Analysis & Health Economics Platform",
    right = "© 2025 - Built with R Shiny & bs4Dash"
  ),

  # Theme
  dark = FALSE,
  help = FALSE,
  scrollToTop = TRUE
)

# ==============================================================================
# SERVER
# ==============================================================================

server <- function(input, output, session) {

  # Reactive values for global state
  rv <- reactiveValues(
    evidence_object = NULL,
    data = NULL,
    protocol = NULL,
    pairwise_results = list(),
    ma_results = list(),  # Alias for pairwise_results (used by publication tools)
    nma_results = list(),
    dr_results = list(),
    he_results = NULL,
    audit_log = list()
  )

  # Keep ma_results synchronized with pairwise_results (with proper event trigger)
  observeEvent(rv$pairwise_results, {
    rv$ma_results <- isolate(rv$pairwise_results)
  }, ignoreInit = FALSE, ignoreNULL = FALSE)

  # ============================================================================
  # DASHBOARD METRICS
  # ============================================================================

  output$n_studies <- renderText({
    if (is.null(rv$data)) {
      "0"
    } else {
      as.character(length(unique(rv$data$study_id)))
    }
  })

  output$n_analyses <- renderText({
    n <- length(rv$pairwise_results) + length(rv$nma_results) + length(rv$dr_results)
    as.character(n)
  })

  output$n_reports <- renderText({
    # Count reports generated (from audit log)
    n_reports <- sum(sapply(rv$audit_log, function(x) x$action == "report_generated"))
    as.character(n_reports)
  })

  output$api_status_dash <- renderText({
    tryCatch({
      status <- check_api_health()
      if (status$healthy) "✓ Online" else "✗ Offline"
    }, error = function(e) "✗ Offline")
  })

  # Recent activity table
  output$recent_activity_table <- renderDT({
    if (length(rv$audit_log) == 0) {
      data.frame(
        Time = character(),
        Action = character(),
        Details = character()
      )
    } else {
      # Get last 10 entries
      recent <- tail(rv$audit_log, 10)
      data.frame(
        Time = sapply(recent, function(x) format(x$timestamp, "%H:%M:%S")),
        Action = sapply(recent, function(x) x$action),
        Details = sapply(recent, function(x) {
          if (length(x$details) > 0) paste(names(x$details), collapse = ", ") else ""
        })
      )
    }
  }, options = list(pageLength = 5, dom = 't'))

  # Quick start demo button
  observeEvent(input$start_demo, {
    # Load demo data
    demo_data <- generate_sample_ma_data()
    rv$data <- demo_data

    # Switch to data import tab
    updateTabItems(session, "sidebar_menu", "data_import")

    showNotification(
      "⚡ Demo data loaded! Ready to explore features.",
      type = "message",
      duration = 5
    )
  })

  # ============================================================================
  # MODULE SERVERS
  # ============================================================================

  data_results <- data_import_server("data_import", rv)
  protocol_results <- protocol_server("protocol", rv)
  pairwise_results <- meta_pairwise_server("pairwise", rv)
  nma_results <- nma_server("nma", rv)
  dr_results <- dose_response_server("dose_response", rv)
  masem_results <- masem_server("masem", rv)  # Meta-Analytic SEM
  sensitivity_results <- sensitivity_server("sensitivity", rv)
  he_params_results <- he_params_server("he_params", rv)
  he_model_results <- he_model_server("he_model", rv)
  he_bcea_results <- he_bcea_server("he_bcea", rv)
  budget_impact_results <- he_budget_impact_server("budget_impact", rv)
  ai_copilot_results <- ai_copilot_server("ai_copilot", rv)
  reporting_results <- reporting_server("reporting", rv)
  audit_results <- audit_server("audit", rv)
  v2_results <- v2_features_server("v2_features", rv)
  client_portal_results <- client_portal_server("client_portal", rv)
  living_ma_results <- living_ma_server("living_ma", rv)

  # Publication Tools Servers (NEW)
  prisma_results <- prisma_generator_server("prisma_generator", rv)
  rob_results <- rob_assessment_server("rob_assessment", rv)
  grade_results <- grade_profile_server("grade_profile", rv)
  interactive_plots_results <- interactive_plots_server("interactive_plots", rv)

  # ============================================================================
  # HEADER ACTIONS
  # ============================================================================

  # Theme switching
  observeEvent(input$theme_professional, {
    updatebs4Dash(session, skin = "blue")
    showNotification("✓ Applied Professional Blue theme", type = "message")
  })

  observeEvent(input$theme_academic, {
    updatebs4Dash(session, skin = "green")
    showNotification("✓ Applied Academic Green theme", type = "message")
  })

  observeEvent(input$theme_medical, {
    updatebs4Dash(session, skin = "red")
    showNotification("✓ Applied Medical Red theme", type = "message")
  })

  observeEvent(input$theme_modern, {
    updatebs4Dash(session, skin = "purple")
    showNotification("✓ Applied Modern Purple theme", type = "message")
  })

  # Dark mode toggle
  observeEvent(input$toggle_dark_mode, {
    # Toggle dark mode (would need custom implementation)
    showNotification("🌙 Dark mode toggled", type = "message")
  })

  # Session actions
  observeEvent(input$save_session_header, {
    # Save session
    tryCatch({
      eo <- create_evidence_object(rv)
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      filename <- paste0("outputs/session_", timestamp, ".json")
      jsonlite::write_json(eo, filename, pretty = TRUE, auto_unbox = TRUE)

      showNotification(paste("✓ Session saved:", filename), type = "message", duration = 5)
      add_audit_entry(rv, "session_saved", list(file = filename))
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error", duration = 10)
    })
  })

  observeEvent(input$export_json_header, {
    # Export JSON
    tryCatch({
      eo <- create_evidence_object(rv)
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      filename <- paste0("outputs/evidence_", timestamp, ".json")
      jsonlite::write_json(eo, filename, pretty = TRUE, auto_unbox = TRUE)

      showNotification(paste("✓ Exported:", filename), type = "message", duration = 5)
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error", duration = 10)
    })
  })
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Create EvidenceObject
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

# Add audit entries
add_audit_entry <- function(rv, action, details = list()) {
  entry <- list(
    timestamp = Sys.time(),
    action = action,
    user = Sys.getenv("USER"),
    details = details
  )
  rv$audit_log[[length(rv$audit_log) + 1]] <- entry
}

# ==============================================================================
# RUN APP
# ==============================================================================

shinyApp(ui = ui, server = server)
