# EvidenceOS PRIME v2.0 - Best-in-Class Meta-Analysis Platform
# Revolutionary UI/UX that surpasses RevMan, Stata, and CMA
# Modern, beautiful, intuitive design for intermediate users

library(shiny)
library(bslib)
library(bs4Dash)
library(DT)
library(plotly)
library(shinyvalidate)
library(shinyWidgets)
library(shinydashboard)
library(waiter) # Loading animations
library(sever) # Disconnection handling
library(shinyjs) # JavaScript utilities

# Source all modules
source("modules/data_import.R")
source("modules/protocol.R")
source("modules/meta_pairwise.R")
source("modules/meta_pairwise_enhanced.R")  # Enhanced version with methodologist suggestions
source("modules/nma.R")
source("modules/dose_response.R")
source("modules/sensitivity.R")
source("modules/he_params.R")
source("modules/he_model.R")
source("modules/he_bcea.R")
source("modules/reporting.R")
source("modules/audit.R")
source("modules/ai_copilot.R")
source("modules/v2_features.R")

# NEW BEST-IN-CLASS MODULES (SURPASS REVMAN, STATA, CMA)
source("modules/grade.R")                      # GRADE Summary of Findings
source("modules/rob_tools.R")                  # Risk of Bias (ROB 2.0, ROBINS-I, QUADAS-2)
source("modules/bayesian_ma.R")                # Bayesian Meta-Analysis with brms/Stan
source("modules/publication_bias_advanced.R")  # PET-PEESE, selection models, p-curve
source("modules/partitioned_survival.R")       # Partitioned Survival for oncology HTA
source("modules/multivariate_ma.R")            # Multivariate MA - NEW!
source("modules/evppi.R")                      # Value of Information (EVPPI) - NEW!
source("modules/onboarding.R")                 # Interactive tutorials - NEW!

# V2.1 ENHANCEMENT MODULES (User & Methodologist Feedback)
source("modules/keyboard_shortcuts.R")         # Power user keyboard shortcuts - NEW!
source("modules/examples_templates.R")         # Example datasets & templates - NEW!
source("modules/export_enhanced.R")            # Excel/CSV export options - NEW!
source("modules/power_analysis.R")             # Sample size & power analysis - NEW!
source("modules/diagnostic_plots_enhanced.R")  # Enhanced diagnostic plots - NEW!

# V3.0 CBAMMR/powerNMA INTEGRATION (Cutting-Edge 2024-2025 Methods)
source("modules/clinical_interpretation.R")    # NNT & E-values ✅ STANDARD
source("modules/voi_enhanced.R")               # EVPI calculator ✅ STANDARD
source("modules/quality_weighted_ma.R")        # Quality-weighted MA ✅ BEST PRACTICE
source("modules/transportability.R")           # Population adjustment ⚠️ NOVEL

# V3.1 CBAMMR/powerNMA COMPLETION (Advanced Methods)
source("modules/loto_sensitivity.R")           # LOTO sensitivity for NMA ✅ STANDARD
source("modules/bootstrap_ci.R")               # Bootstrap BCa intervals ✅ STANDARD
source("modules/sucra_rankings.R")             # SUCRA rankings for NMA ✅ STANDARD
source("modules/quantile_metaanalysis.R")      # Quantile MA - personalized medicine ⚠️ NOVEL
source("modules/individual_prediction.R")      # Individual effect prediction ⚠️ NOVEL

# V3.2 QUICK WINS (Essential Workflow & Robustness)
source("modules/permutation_tests.R")          # Permutation testing ✅ STANDARD
source("modules/threshold_analysis.R")         # Threshold analysis ✅ STANDARD
source("modules/prisma_flow.R")                # PRISMA 2020 flow diagram ✅ REQUIRED
source("modules/auto_tables.R")                # Automated table generation ✅ STANDARD
source("modules/decision_curve.R")             # Decision curve analysis ✅ STANDARD
source("modules/robust_variance.R")            # Robust variance estimation ✅ STANDARD

# source("modules/collaboration.R")            # TODO: Real-time collaboration (future)

# Source utilities
source("utils/python_bridge.R")
source("utils/plotting.R")
source("utils/validators.R")
source("utils/theme_config.R")  # Custom theme

# Custom CSS for best-in-class design
custom_css <- "
/* Modern Design System */
:root {
  --primary: #0066FF;
  --primary-dark: #0052CC;
  --success: #00C851;
  --warning: #FFB800;
  --danger: #FF4444;
  --text-primary: #1A1A1A;
  --text-secondary: #6B7280;
  --bg-primary: #FFFFFF;
  --bg-secondary: #F9FAFB;
  --border: #E5E7EB;
  --shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
}

/* Typography */
body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  color: var(--text-primary);
  font-size: 15px;
  line-height: 1.6;
}

h1, h2, h3, h4, h5, h6 {
  font-weight: 600;
  letter-spacing: -0.01em;
}

/* Glassmorphism Cards */
.card {
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(229, 231, 235, 0.5);
  border-radius: 12px;
  box-shadow: var(--shadow);
  transition: all 0.3s ease;
}

.card:hover {
  box-shadow: var(--shadow-lg);
  transform: translateY(-2px);
}

/* Modern Buttons */
.btn-primary {
  background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-weight: 500;
  letter-spacing: 0.01em;
  transition: all 0.2s ease;
  box-shadow: 0 4px 6px -1px rgb(0 102 255 / 0.3);
}

.btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 15px -3px rgb(0 102 255 / 0.4);
}

/* Progress Bars */
.progress {
  height: 8px;
  border-radius: 4px;
  background: var(--bg-secondary);
}

.progress-bar {
  background: linear-gradient(90deg, var(--primary) 0%, #00C851 100%);
  border-radius: 4px;
  transition: width 0.4s ease;
}

/* Tooltips */
.tooltip-inner {
  background: var(--text-primary);
  border-radius: 6px;
  padding: 8px 12px;
  font-size: 13px;
}

/* Tables */
.dataTable {
  border-radius: 8px;
  overflow: hidden;
}

.dataTable thead th {
  background: var(--bg-secondary);
  font-weight: 600;
  color: var(--text-primary);
  border-bottom: 2px solid var(--border);
}

/* Sidebar */
.sidebar {
  background: linear-gradient(180deg, #0066FF 0%, #0052CC 100%);
  color: white;
}

.sidebar .nav-link {
  color: rgba(255, 255, 255, 0.8);
  transition: all 0.2s ease;
  border-radius: 6px;
  margin: 4px 8px;
}

.sidebar .nav-link:hover {
  background: rgba(255, 255, 255, 0.1);
  color: white;
}

.sidebar .nav-link.active {
  background: rgba(255, 255, 255, 0.2);
  color: white;
}

/* Quick Stats Bar */
.stats-bar {
  background: var(--bg-secondary);
  border-top: 1px solid var(--border);
  padding: 12px 20px;
  display: flex;
  justify-content: space-around;
  align-items: center;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.stat-label {
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 500;
}

.stat-value {
  color: var(--primary);
  font-size: 18px;
  font-weight: 600;
}

/* Animations */
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.fade-in {
  animation: fadeIn 0.3s ease;
}

/* Dark Mode Support */
@media (prefers-color-scheme: dark) {
  :root {
    --bg-primary: #1A1A1A;
    --bg-secondary: #2D2D2D;
    --text-primary: #FFFFFF;
    --text-secondary: #A0A0A0;
    --border: #404040;
  }
}

/* Mobile Responsive */
@media (max-width: 768px) {
  .sidebar {
    display: none;
  }

  .card {
    margin: 8px;
  }

  .btn {
    width: 100%;
    margin: 4px 0;
  }
}

/* Loading Animation */
.loading-overlay {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(5px);
}

.spinner-border {
  color: var(--primary);
}

/* Command Palette */
.command-palette {
  position: fixed;
  top: 20%;
  left: 50%;
  transform: translateX(-50%);
  width: 600px;
  max-width: 90vw;
  background: white;
  border-radius: 12px;
  box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1);
  z-index: 9999;
}

.command-input {
  border: none;
  border-bottom: 1px solid var(--border);
  font-size: 16px;
  padding: 16px 20px;
  width: 100%;
}

.command-input:focus {
  outline: none;
  border-bottom-color: var(--primary);
}

/* Success Celebrations */
@keyframes celebrate {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

.celebrate {
  animation: celebrate 0.5s ease;
}
"

# Define UI with modern design
ui <- page_navbar(
  title = div(
    img(src = "logo.png", height = "32px", style = "margin-right: 12px;"),
    span("EvidenceOS PRIME", style = "font-weight: 600; font-size: 20px;")
  ),

  # Modern theme
  theme = bs_theme(
    version = 5,
    bg = "#FFFFFF",
    fg = "#1A1A1A",
    primary = "#0066FF",
    success = "#00C851",
    warning = "#FFB800",
    danger = "#FF4444",
    base_font = font_google("Inter"),
    code_font = font_google("IBM Plex Mono"),
    heading_font = font_google("Inter")
  ),

  # Custom CSS
  tags$head(
    tags$style(HTML(custom_css)),
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap", rel = "stylesheet")
  ),

  # Enable shinyjs for interactivity
  useShinyjs(),

  # Loading overlay
  use_waiter(),
  waiter_show_on_load(
    html = tagList(
      spin_flower(),
      h3("Loading EvidenceOS PRIME...", style = "color: #0066FF; margin-top: 20px;")
    ),
    color = "rgba(255, 255, 255, 0.95)"
  ),

  # Disconnect handling
  use_sever(),

  fillable = TRUE,

  # ==========================================================================
  # NAVIGATION TABS
  # ==========================================================================

  # Tab 1: Home Dashboard (NEW!)
  nav_panel(
    title = "Home",
    icon = icon("home"),
    value = "home",
    uiOutput("home_dashboard")
  ),

  # Tab 2: Data Import
  nav_panel(
    title = "Data",
    icon = icon("database"),
    value = "data",
    data_import_ui("data_import")
  ),

  # Tab 3: Protocol & PRISMA
  nav_panel(
    title = "Protocol",
    icon = icon("file-alt"),
    value = "protocol",
    protocol_ui("protocol")
  ),

  # Tab 4: Risk of Bias (NEW - SURPASSES REVMAN!)
  nav_panel(
    title = "Risk of Bias",
    icon = icon("balance-scale"),
    value = "rob",
    rob_tools_ui("rob_tools")
  ),

  # Tab 5: Analysis
  nav_menu(
    title = "Analysis",
    icon = icon("chart-line"),

    nav_panel(
      "Pairwise MA",
      meta_pairwise_ui("pairwise")
    ),
    nav_panel(
      "Network MA",
      nma_ui("nma")
    ),
    nav_panel(
      "Bayesian MA",
      bayesian_ma_ui("bayesian")  # NEW!
    ),
    nav_panel(
      "Multivariate MA",
      multivariate_ma_ui("multivariate")  # NEW!
    ),
    nav_panel(
      "Dose-Response",
      dose_response_ui("dose_response")
    )
  ),

  # Tab 6: Publication Bias (Enhanced)
  nav_panel(
    title = "Publication Bias",
    icon = icon("filter"),
    value = "pub_bias",
    pub_bias_advanced_ui("pub_bias")  # NEW - PET-PEESE, selection models, p-curve
  ),

  # Tab 7: Sensitivity & Scenarios
  nav_panel(
    title = "Sensitivity",
    icon = icon("sliders-h"),
    value = "sensitivity",
    sensitivity_ui("sensitivity")
  ),

  # Tab 8: GRADE (NEW - SURPASSES REVMAN!)
  nav_panel(
    title = "GRADE",
    icon = icon("star"),
    value = "grade",
    grade_ui("grade")
  ),

  # Tab 9: Health Economics
  nav_menu(
    title = "Economics",
    icon = icon("pound-sign"),

    nav_panel(
      "Parameters",
      he_params_ui("he_params")
    ),
    nav_panel(
      "Markov Model",
      he_model_ui("he_model")
    ),
    nav_panel(
      "Partitioned Survival",
      partitioned_survival_ui("survival_ps")  # NEW - For oncology HTA!
    ),
    nav_panel(
      "Results (BCEA)",
      he_bcea_ui("he_bcea")
    ),
    nav_panel(
      "Value of Information (EVPPI)",
      evppi_ui("evppi")  # NEW - EVPPI!
    ),
    nav_panel(
      "EVPI Calculator",
      voi_tools_ui("voi_enhanced")  # NEW V3.0 - EVPI!
    )
  ),

  # Tab 10: Diagnostic Plots (NEW - Enhanced!)
  nav_panel(
    title = "Diagnostics",
    icon = icon("chart-area"),
    value = "diagnostics",
    diagnostic_plots_ui("diagnostics")
  ),

  # Tab 11: Power Analysis (NEW!)
  nav_panel(
    title = "Power Analysis",
    icon = icon("calculator"),
    value = "power",
    power_analysis_ui("power_analysis")
  ),

  # Tab 12: Examples & Templates (NEW!)
  nav_panel(
    title = "Examples",
    icon = icon("lightbulb"),
    value = "examples",
    examples_templates_ui("examples")
  ),

  # V3.0 CUTTING-EDGE FEATURES (CBAMMR/powerNMA Integration)

  # Tab 13: Clinical Interpretation (NEW V3.0!)
  nav_panel(
    title = "Clinical Tools",
    icon = icon("user-md"),
    value = "clinical",
    clinical_interp_ui("clinical_interp")
  ),

  # Tab 14: Quality-Weighted MA (NEW V3.0!)
  nav_panel(
    title = "Quality-Weighted MA",
    icon = icon("balance-scale"),
    value = "quality_weighted",
    quality_weighted_ma_ui("quality_weighted")
  ),

  # Tab 15: Transportability (NEW V3.0 - NOVEL!)
  nav_panel(
    title = "Transportability",
    icon = icon("globe-americas"),
    value = "transportability",
    transportability_ui("transportability")
  ),

  # V3.1 ADVANCED FEATURES (CBAMMR/powerNMA Completion)

  # Tab 16: LOTO Sensitivity (NEW V3.1!)
  nav_panel(
    title = "LOTO Sensitivity",
    icon = icon("sync"),
    value = "loto",
    loto_sensitivity_ui("loto_sensitivity")
  ),

  # Tab 17: Bootstrap CI (NEW V3.1!)
  nav_panel(
    title = "Bootstrap CI",
    icon = icon("random"),
    value = "bootstrap_ci",
    bootstrap_ci_ui("bootstrap_ci")
  ),

  # Tab 18: SUCRA Rankings (NEW V3.1!)
  nav_panel(
    title = "SUCRA Rankings",
    icon = icon("chart-bar"),
    value = "sucra",
    sucra_rankings_ui("sucra_rankings")
  ),

  # Tab 19: Quantile Meta-Analysis (NEW V3.1 - NOVEL!)
  nav_panel(
    title = "Quantile MA",
    icon = icon("chart-line"),
    value = "quantile_ma",
    quantile_metaanalysis_ui("quantile_ma")
  ),

  # Tab 20: Individual Prediction (NEW V3.1 - NOVEL!)
  nav_panel(
    title = "Individual Prediction",
    icon = icon("user"),
    value = "individual_pred",
    individual_prediction_ui("individual_pred")
  ),

  # V3.2 ESSENTIAL WORKFLOW & ROBUSTNESS

  # Tab 21: Permutation Tests (NEW V3.2!)
  nav_panel(
    title = "Permutation Tests",
    icon = icon("random"),
    value = "permutation",
    permutation_tests_ui("permutation")
  ),

  # Tab 22: Threshold Analysis (NEW V3.2!)
  nav_panel(
    title = "Threshold Analysis",
    icon = icon("crosshairs"),
    value = "threshold",
    threshold_analysis_ui("threshold")
  ),

  # Tab 23: PRISMA Flow (NEW V3.2!)
  nav_panel(
    title = "PRISMA Flow",
    icon = icon("project-diagram"),
    value = "prisma",
    prisma_flow_ui("prisma")
  ),

  # Tab 24: Auto Tables (NEW V3.2!)
  nav_panel(
    title = "Auto Tables",
    icon = icon("table"),
    value = "auto_tables",
    auto_tables_ui("auto_tables")
  ),

  # Tab 25: Decision Curve (NEW V3.2!)
  nav_panel(
    title = "Decision Curve",
    icon = icon("chart-area"),
    value = "decision_curve",
    decision_curve_ui("decision_curve")
  ),

  # Tab 26: AI Copilot
  nav_panel(
    title = "AI Copilot",
    icon = icon("robot"),
    value = "ai",
    ai_copilot_ui("ai_copilot")
  ),

  # Tab 14: Collaboration (TODO - Future)
  # nav_panel(
  #   title = "Collaborate",
  #   icon = icon("users"),
  #   value = "collab",
  #   collaboration_ui("collaboration")
  # ),

  # Tab 15: Reports & Export (Enhanced!)
  nav_menu(
    title = "Export",
    icon = icon("file-export"),

    nav_panel(
      "Word/PDF Reports",
      reporting_ui("reporting")
    ),
    nav_panel(
      "Excel/CSV Export",
      export_enhanced_ui("export_enhanced")
    )
  ),

  # Tab 13: Audit Trail
  nav_panel(
    title = "Audit",
    icon = icon("history"),
    value = "audit",
    audit_ui("audit")
  ),

  # ==========================================================================
  # SIDEBAR (Always Visible)
  # ==========================================================================

  sidebar = sidebar(
    width = 280,
    class = "sidebar",

    # Session Info Card
    card(
      card_header(
        icon("info-circle"),
        "Session Info",
        style = "background: transparent; color: white; border: none;"
      ),
      card_body(
        style = "color: rgba(255,255,255,0.9);",
        textOutput("session_info"),
        hr(style = "border-color: rgba(255,255,255,0.2);"),
        htmlOutput("project_stats")
      )
    ),

    # Quick Actions
    h5(icon("bolt"), "Quick Actions", style = "color: white; margin-top: 20px; margin-bottom: 12px;"),

    actionButton(
      "btn_new_project",
      "New Project",
      icon = icon("plus"),
      class = "btn-primary w-100 mb-2",
      style = "background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3);"
    ),

    actionButton(
      "btn_save_session",
      "Save Session",
      icon = icon("save"),
      class = "btn-outline-light w-100 mb-2"
    ),

    actionButton(
      "btn_load_session",
      "Load Session",
      icon = icon("folder-open"),
      class = "btn-outline-light w-100 mb-2"
    ),

    actionButton(
      "btn_export_json",
      "Export Evidence Object",
      icon = icon("download"),
      class = "btn-outline-light w-100 mb-2"
    ),

    hr(style = "border-color: rgba(255,255,255,0.2);"),

    # Keyboard Shortcuts
    actionButton(
      "btn_shortcuts",
      "Keyboard Shortcuts",
      icon = icon("keyboard"),
      class = "btn-outline-light w-100 mb-2",
      onclick = "Shiny.setInputValue('show_shortcuts', Math.random());"
    ),

    # Interactive Tutorial
    actionButton(
      "btn_tutorial",
      "Interactive Tutorial",
      icon = icon("graduation-cap"),
      class = "btn-outline-light w-100 mb-2"
    ),

    hr(style = "border-color: rgba(255,255,255,0.2);"),

    # API Status
    h5(icon("server"), "API Status", style = "color: white; margin-top: 12px; margin-bottom: 8px;"),
    htmlOutput("api_status"),

    hr(style = "border-color: rgba(255,255,255,0.2);"),

    # Version Info
    tags$div(
      style = "color: rgba(255,255,255,0.6); font-size: 13px; text-align: center;",
      tags$strong("EvidenceOS PRIME v2.0"),
      br(),
      "Best-in-Class Meta-Analysis",
      br(),
      "© 2025 • ",
      tags$a(href = "#", "Help", style = "color: rgba(255,255,255,0.8);"),
      " • ",
      tags$a(href = "#", "Docs", style = "color: rgba(255,255,255,0.8);")
    )
  ),

  # ==========================================================================
  # BOTTOM STATS BAR (Always Visible)
  # ==========================================================================

  footer = div(
    class = "stats-bar",
    div(
      class = "stat-item",
      icon("database", style = "color: var(--primary);"),
      span(class = "stat-label", "Studies:"),
      span(class = "stat-value", textOutput("stat_n_studies", inline = TRUE))
    ),
    div(
      class = "stat-item",
      icon("chart-line", style = "color: var(--success);"),
      span(class = "stat-label", "I²:"),
      span(class = "stat-value", textOutput("stat_i2", inline = TRUE))
    ),
    div(
      class = "stat-item",
      icon("pound-sign", style = "color: var(--warning);"),
      span(class = "stat-label", "ICER:"),
      span(class = "stat-value", textOutput("stat_icer", inline = TRUE))
    ),
    div(
      class = "stat-item",
      icon("clock", style = "color: var(--text-secondary);"),
      span(class = "stat-label", "Last saved:"),
      span(class = "stat-value", textOutput("stat_last_saved", inline = TRUE))
    )
  )
)

# ==========================================================================
# SERVER LOGIC
# ==========================================================================

server <- function(input, output, session) {

  # Hide loading overlay
  waiter_hide()

  # ==========================================================================
  # REACTIVE VALUES (Global State)
  # ==========================================================================

  rv <- reactiveValues(
    evidence_object = NULL,
    data = NULL,
    protocol = NULL,
    pairwise_results = list(),
    nma_results = list(),
    bayesian_results = list(),  # NEW - Bayesian MA results
    multivariate_results = list(),  # NEW - Multivariate MA results
    dr_results = list(),
    he_results = NULL,
    survival_ps_results = NULL,  # NEW - Partitioned survival results
    evppi_results = NULL,  # NEW - EVPPI results
    rob_assessments = list(),  # NEW - Risk of bias assessments
    grade_ratings = list(),  # NEW - GRADE ratings
    pub_bias_results = list(),  # NEW - Advanced publication bias results
    audit_log = list(),
    # collaborators = list(),  # TODO
    project_name = "Untitled Project",
    last_saved = NULL
  )

  # ==========================================================================
  # HOME DASHBOARD
  # ==========================================================================

  output$home_dashboard <- renderUI({
    tagList(
      # Hero Section
      div(
        class = "hero-section fade-in",
        style = "background: linear-gradient(135deg, #0066FF 0%, #00C851 100%);
                 padding: 60px 40px;
                 border-radius: 16px;
                 color: white;
                 margin: 20px;",
        h1("Welcome to Evidence OS PRIME", style = "font-size: 36px; font-weight: 700; margin-bottom: 12px;"),
        p("The world's most advanced meta-analysis platform", style = "font-size: 18px; opacity: 0.9; margin-bottom: 24px;"),
        div(
          actionButton(
            "btn_new_analysis",
            "Start New Analysis",
            icon = icon("rocket"),
            class = "btn-light btn-lg",
            style = "margin-right: 12px; padding: 12px 32px; font-size: 16px; font-weight: 600;"
          ),
          actionButton(
            "btn_load_example",
            "Load Example",
            icon = icon("book-open"),
            class = "btn-outline-light btn-lg",
            style = "padding: 12px 32px; font-size: 16px; font-weight: 600;"
          )
        )
      ),

      # Features Grid
      div(
        style = "padding: 20px;",

        h2("What Makes Us Different", style = "margin-bottom: 24px; font-weight: 600;"),

        layout_columns(
          col_widths = c(3, 3, 3, 3),

          # Feature 1
          card(
            full_screen = FALSE,
            card_header(
              icon("star", class = "fa-2x", style = "color: #FFB800;"),
              style = "text-align: center; padding-top: 24px;"
            ),
            card_body(
              h4("GRADE Integration", style = "text-align: center; margin-bottom: 12px;"),
              p("Automated GRADE assessment with evidence certainty ratings. Surpasses RevMan.",
                style = "text-align: center; color: var(--text-secondary); font-size: 14px;")
            )
          ),

          # Feature 2
          card(
            card_header(
              icon("brain", class = "fa-2x", style = "color: #0066FF;"),
              style = "text-align: center; padding-top: 24px;"
            ),
            card_body(
              h4("AI Copilot", style = "text-align: center; margin-bottom: 12px;"),
              p("Natural language queries and smart insights. The only meta-analysis AI assistant.",
                style = "text-align: center; color: var(--text-secondary); font-size: 14px;")
            )
          ),

          # Feature 3
          card(
            card_header(
              icon("chart-network", class = "fa-2x", style = "color: #00C851;"),
              style = "text-align: center; padding-top: 24px;"
            ),
            card_body(
              h4("Bayesian Methods", style = "text-align: center; margin-bottom: 12px;"),
              p("Full Bayesian inference with MCMC. Power of Stata with ease of CMA.",
                style = "text-align: center; color: var(--text-secondary); font-size: 14px;")
            )
          ),

          # Feature 4
          card(
            card_header(
              icon("users", class = "fa-2x", style = "color: #FF4444;"),
              style = "text-align: center; padding-top: 24px;"
            ),
            card_body(
              h4("Real-Time Collaboration", style = "text-align: center; margin-bottom: 12px;"),
              p("Work together simultaneously. Comment, review, and approve in real-time.",
                style = "text-align: center; color: var(--text-secondary); font-size: 14px;")
            )
          )
        ),

        # Recent Projects
        h2("Recent Projects", style = "margin-top: 40px; margin-bottom: 24px; font-weight: 600;"),

        uiOutput("recent_projects")
      )
    )
  })

  # Recent Projects List
  output$recent_projects <- renderUI({
    # Placeholder - would load from database
    card(
      card_body(
        p("No recent projects. Start your first analysis!",
          style = "text-align: center; color: var(--text-secondary); padding: 40px;")
      )
    )
  })

  # ==========================================================================
  # SESSION INFO & STATS
  # ==========================================================================

  output$session_info <- renderText({
    paste0(
      "Project: ", rv$project_name, "\n",
      "Session ID: ", substr(session$token, 1, 8), "\n",
      "Started: ", format(Sys.time(), "%H:%M:%S")
    )
  })

  output$project_stats <- renderUI({
    n_studies <- if (!is.null(rv$data)) length(unique(rv$data$study_id)) else 0
    n_outcomes <- if (!is.null(rv$pairwise_results)) length(rv$pairwise_results) else 0

    tagList(
      p(strong(n_studies), " studies loaded", style = "margin-bottom: 4px;"),
      p(strong(n_outcomes), " outcomes analyzed", style = "margin-bottom: 0;")
    )
  })

  # Bottom Stats Bar
  output$stat_n_studies <- renderText({
    if (!is.null(rv$data)) {
      as.character(length(unique(rv$data$study_id)))
    } else {
      "0"
    }
  })

  output$stat_i2 <- renderText({
    if (length(rv$pairwise_results) > 0) {
      # Get first result's I²
      first_result <- rv$pairwise_results[[1]]
      if (!is.null(first_result$I2)) {
        paste0(round(first_result$I2, 1), "%")
      } else {
        "—"
      }
    } else {
      "—"
    }
  })

  output$stat_icer <- renderText({
    if (!is.null(rv$he_results) && !is.null(rv$he_results$icer)) {
      paste0("£", format(round(rv$he_results$icer), big.mark = ","))
    } else {
      "—"
    }
  })

  output$stat_last_saved <- renderText({
    if (!is.null(rv$last_saved)) {
      format(rv$last_saved, "%H:%M")
    } else {
      "Never"
    }
  })

  # API Status
  output$api_status <- renderUI({
    tryCatch({
      status <- check_api_health()
      if (status$healthy) {
        div(
          icon("check-circle", style = "color: #00C851; margin-right: 8px;"),
          span("API Connected", style = "color: rgba(255,255,255,0.9);")
        )
      } else {
        div(
          icon("times-circle", style = "color: #FF4444; margin-right: 8px;"),
          span("API Offline", style = "color: rgba(255,255,255,0.9);")
        )
      }
    }, error = function(e) {
      div(
        icon("exclamation-triangle", style = "color: #FFB800; margin-right: 8px;"),
        span("API Unavailable", style = "color: rgba(255,255,255,0.9);")
      )
    })
  })

  # ==========================================================================
  # MODULE SERVERS
  # ==========================================================================

  data_results <- data_import_server("data_import", rv)
  protocol_results <- protocol_server("protocol", rv)

  # Risk of Bias (NEW!)
  rob_results <- rob_tools_server("rob_tools", rv)

  # Analysis Modules
  pairwise_results <- meta_pairwise_server("pairwise", rv)
  nma_results <- nma_server("nma", rv)
  bayesian_results <- bayesian_ma_server("bayesian", rv)  # NEW - Bayesian MA with brms/Stan
  multivariate_results <- multivariate_ma_server("multivariate", rv)  # NEW - Multivariate MA
  dr_results <- dose_response_server("dose_response", rv)

  # Publication Bias (Enhanced)
  pub_bias_results <- pub_bias_advanced_server("pub_bias", rv)  # NEW - PET-PEESE, selection models

  # Sensitivity
  sensitivity_results <- sensitivity_server("sensitivity", rv)

  # GRADE (NEW!)
  grade_results <- grade_server("grade", rv)

  # Health Economics
  he_params_results <- he_params_server("he_params", rv)
  he_model_results <- he_model_server("he_model", rv)
  survival_ps_results <- partitioned_survival_server("survival_ps", rv)  # NEW - Partitioned survival for HTA
  he_bcea_results <- he_bcea_server("he_bcea", rv)
  evppi_results <- evppi_server("evppi", rv)  # NEW - EVPPI

  # V2.1 Enhancement Modules (User & Methodologist Feedback)
  diagnostic_plots_results <- diagnostic_plots_server("diagnostics", rv)  # NEW - Enhanced diagnostic plots
  power_analysis_results <- power_analysis_server("power_analysis", rv)  # NEW - Power & sample size
  examples_results <- examples_templates_server("examples", rv)  # NEW - Examples & templates
  export_enhanced_results <- export_enhanced_server("export_enhanced", rv)  # NEW - Excel/CSV export
  keyboard_shortcuts_results <- keyboard_shortcuts_server("keyboard_shortcuts", rv)  # NEW - Keyboard shortcuts

  # V3.0 CBAMMR/powerNMA Integration (Cutting-Edge 2024-2025 Methods)
  clinical_interp_results <- clinical_interp_server("clinical_interp", rv)  # NEW V3.0 - NNT & E-values
  voi_enhanced_results <- voi_tools_server("voi_enhanced", rv)  # NEW V3.0 - EVPI calculator
  quality_weighted_results <- quality_weighted_ma_server("quality_weighted", rv)  # NEW V3.0 - Quality weighting
  transportability_results <- transportability_server("transportability", rv)  # NEW V3.0 - Population adjustment

  # V3.1 CBAMMR/powerNMA Completion (Advanced Methods)
  loto_results <- loto_sensitivity_server("loto_sensitivity", rv)  # NEW V3.1 - LOTO sensitivity
  bootstrap_ci_results <- bootstrap_ci_server("bootstrap_ci", rv)  # NEW V3.1 - Bootstrap BCa
  sucra_results <- sucra_rankings_server("sucra_rankings", rv)  # NEW V3.1 - SUCRA rankings
  quantile_ma_results <- quantile_metaanalysis_server("quantile_ma", rv)  # NEW V3.1 - Quantile MA
  individual_pred_results <- individual_prediction_server("individual_pred", rv)  # NEW V3.1 - Individual prediction

  # V3.2 Essential Workflow & Robustness
  permutation_results <- permutation_tests_server("permutation", rv)  # NEW V3.2 - Permutation testing
  threshold_results <- threshold_analysis_server("threshold", rv)  # NEW V3.2 - Threshold analysis
  prisma_results <- prisma_flow_server("prisma", rv)  # NEW V3.2 - PRISMA flow diagram
  auto_tables_results <- auto_tables_server("auto_tables", rv)  # NEW V3.2 - Auto table generation
  decision_curve_results <- decision_curve_server("decision_curve", rv)  # NEW V3.2 - Decision curve analysis
  # Note: robust_variance is a utility enhancement, not a standalone server module

  # AI Copilot
  ai_copilot_results <- ai_copilot_server("ai_copilot", rv)

  # Collaboration (NEW!) - TODO
  # collaboration_results <- collaboration_server("collaboration", rv)

  # Reporting & Audit
  reporting_results <- reporting_server("reporting", rv)
  audit_results <- audit_server("audit", rv)

  # ==========================================================================
  # QUICK ACTION HANDLERS
  # ==========================================================================

  # New Project
  observeEvent(input$btn_new_project, {
    showModal(modalDialog(
      title = "Create New Project",
      textInput("new_project_name", "Project Name", "Untitled Project"),
      selectInput("new_project_type", "Project Type",
                  choices = c(
                    "Systematic Review & Meta-Analysis",
                    "Network Meta-Analysis",
                    "Health Technology Assessment",
                    "Dose-Response Meta-Analysis",
                    "Living Systematic Review"
                  )),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_new_project", "Create", class = "btn-primary")
      )
    ))
  })

  observeEvent(input$confirm_new_project, {
    rv$project_name <- input$new_project_name
    # Reset state
    rv$data <- NULL
    rv$pairwise_results <- list()
    rv$nma_results <- list()

    removeModal()

    showNotification(
      paste("Created new project:", input$new_project_name),
      type = "message",
      duration = 3
    )
  })

  # Save Session
  observeEvent(input$btn_save_session, {
    withProgress(message = "Saving session...", value = 0, {
      tryCatch({
        incProgress(0.3, detail = "Creating Evidence Object")

        # Create EvidenceObject
        eo <- create_evidence_object(rv)

        incProgress(0.3, detail = "Writing to file")

        # Save to file
        timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
        filename <- paste0("outputs/session_", timestamp, ".json")

        jsonlite::write_json(eo, filename, pretty = TRUE, auto_unbox = TRUE)

        rv$last_saved <- Sys.time()

        incProgress(0.4, detail = "Done!")

        showNotification(
          div(
            icon("check-circle", style = "color: #00C851; margin-right: 8px;"),
            paste("Session saved:", filename)
          ),
          type = "message",
          duration = 5
        )

        # Add audit entry
        add_audit_entry(rv, "session_saved", list(file = filename))

      }, error = function(e) {
        showNotification(
          div(
            icon("times-circle", style = "color: #FF4444; margin-right: 8px;"),
            paste("Error saving session:", e$message)
          ),
          type = "error",
          duration = 10
        )
      })
    })
  })

  # Load Session
  observeEvent(input$btn_load_session, {
    showModal(modalDialog(
      title = "Load Session",
      fileInput("load_file", "Choose Evidence Object (JSON)", accept = ".json"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("btn_load_confirm", "Load", class = "btn-primary")
      )
    ))
  })

  # Export JSON
  observeEvent(input$btn_export_json, {
    tryCatch({
      eo <- create_evidence_object(rv)
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      filename <- paste0("outputs/evidence_", timestamp, ".json")

      jsonlite::write_json(eo, filename, pretty = TRUE, auto_unbox = TRUE)

      showNotification(
        div(
          icon("download", style = "color: #0066FF; margin-right: 8px;"),
          paste("Evidence object exported:", filename)
        ),
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

  # Keyboard Shortcuts Modal
  observeEvent(input$show_shortcuts, {
    showModal(modalDialog(
      title = div(icon("keyboard"), "Keyboard Shortcuts"),
      size = "l",
      easyClose = TRUE,

      tags$table(
        class = "table table-hover",
        style = "margin-top: 20px;",
        tags$thead(
          tags$tr(
            tags$th("Shortcut"),
            tags$th("Action")
          )
        ),
        tags$tbody(
          tags$tr(tags$td(tags$kbd("Ctrl + N")), tags$td("New Project")),
          tags$tr(tags$td(tags$kbd("Ctrl + S")), tags$td("Save Session")),
          tags$tr(tags$td(tags$kbd("Ctrl + R")), tags$td("Run Analysis")),
          tags$tr(tags$td(tags$kbd("Ctrl + /")), tags$td("Open AI Copilot")),
          tags$tr(tags$td(tags$kbd("Ctrl + K")), tags$td("Command Palette")),
          tags$tr(tags$td(tags$kbd("Ctrl + E")), tags$td("Export Report")),
          tags$tr(tags$td(tags$kbd("Esc")), tags$td("Close Modal"))
        )
      ),

      footer = modalButton("Close")
    ))
  })

  # Tutorial
  observeEvent(input$btn_tutorial, {
    # Launch interactive tutorial
    onboarding_start(session)
  })

  # ==========================================================================
  # KEYBOARD SHORTCUTS (JavaScript)
  # ==========================================================================

  observeEvent("", {
    runjs("
      document.addEventListener('keydown', function(e) {
        // Ctrl+N: New Project
        if (e.ctrlKey && e.key === 'n') {
          e.preventDefault();
          document.getElementById('btn_new_project').click();
        }

        // Ctrl+S: Save Session
        if (e.ctrlKey && e.key === 's') {
          e.preventDefault();
          document.getElementById('btn_save_session').click();
        }

        // Ctrl+K: Command Palette (TODO: Implement)
        if (e.ctrlKey && e.key === 'k') {
          e.preventDefault();
          alert('Command Palette coming soon!');
        }

        // Esc: Close modals
        if (e.key === 'Escape') {
          $('.modal').modal('hide');
        }
      });
    ")
  }, once = TRUE)
}

# ==========================================================================
# HELPER FUNCTIONS
# ==========================================================================

# Create EvidenceObject
create_evidence_object <- function(rv) {
  list(
    evidence_id = paste0("EVO_", format(Sys.time(), "%Y%m%d_%H%M%S")),
    version = "2.0.0",
    created_at = Sys.time(),
    updated_at = Sys.time(),
    project_name = rv$project_name,
    protocol = rv$protocol,
    studies = if (!is.null(rv$data)) unique(rv$data$study_id) else list(),
    observations = if (!is.null(rv$data)) nrow(rv$data) else 0,
    rob_assessments = rv$rob_assessments,  # NEW - Risk of bias
    grade_ratings = rv$grade_ratings,  # NEW - GRADE
    pairwise_results = rv$pairwise_results,
    nma_results = rv$nma_results,
    bayesian_results = rv$bayesian_results,  # NEW - Bayesian MA
    multivariate_results = rv$multivariate_results,  # NEW - Multivariate MA
    pub_bias_results = rv$pub_bias_results,  # NEW - Advanced publication bias
    dose_response_results = rv$dr_results,
    economic_results = rv$he_results,
    survival_ps_results = rv$survival_ps_results,  # NEW - Partitioned survival
    evppi_results = rv$evppi_results,  # NEW - EVPPI
    audit_trail = rv$audit_log
    # collaborators = rv$collaborators  # TODO
  )
}

# Add audit entry
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
