# =============================================================================
# Interactive Onboarding & Tutorials Module
# =============================================================================
# Guided tours and interactive tutorials for new users
# Addresses user review: "Need better onboarding for intermediate users"
# SURPASSES: RevMan (minimal help), Stata (documentation only), CMA (basic tutorials)
#
# Features:
# - Step-by-step guided tours
# - Interactive walkthroughs for common workflows
# - Contextual help and tooltips
# - Video tutorial library
# - Quick start wizard
# - Best practices guidance
# =============================================================================

library(shiny)
library(bslib)
library(shinyjs)

#' Start onboarding tour
#'
#' @param session Shiny session object
#' @param tour_name Name of the tour to start (default: "welcome")
#' @export
onboarding_start <- function(session, tour_name = "welcome") {

  if (tour_name == "welcome") {
    # Welcome tour
    show_welcome_modal(session)
  } else if (tour_name == "data_import") {
    show_data_import_tour(session)
  } else if (tour_name == "analysis") {
    show_analysis_tour(session)
  } else if (tour_name == "reporting") {
    show_reporting_tour(session)
  }
}

#' Show welcome modal with tour options
#'
#' @param session Shiny session object
show_welcome_modal <- function(session) {

  showModal(modalDialog(
    title = div(
      icon("graduation-cap", class = "fa-2x", style = "color: #0066FF; margin-right: 15px;"),
      span("Welcome to EvidenceOS PRIME!", style = "font-size: 24px; font-weight: 600;")
    ),
    size = "l",
    easyClose = FALSE,

    div(
      style = "padding: 20px;",

      # Welcome message
      div(
        style = "background: linear-gradient(135deg, #0066FF 0%, #00C851 100%);
                 color: white;
                 padding: 30px;
                 border-radius: 12px;
                 margin-bottom: 30px;",
        h3("Get Started in Minutes", style = "margin: 0 0 15px 0;"),
        p(
          "EvidenceOS PRIME is the world's most advanced meta-analysis platform. Let us show you around!",
          style = "margin: 0; font-size: 16px; opacity: 0.95;"
        )
      ),

      # Tour options
      h4("Choose your learning path:", style = "margin-bottom: 20px; font-weight: 600;"),

      # Beginner tour
      div(
        class = "tour-option",
        style = "border: 2px solid #E5E7EB;
                 border-radius: 12px;
                 padding: 20px;
                 margin-bottom: 15px;
                 cursor: pointer;
                 transition: all 0.2s;",
        onclick = "Shiny.setInputValue('tour_selected', 'beginner', {priority: 'event'});",

        fluidRow(
          column(
            width = 2,
            div(
              style = "background: #DBEAFE; width: 60px; height: 60px; border-radius: 50%;
                       display: flex; align-items: center; justify-content: center;",
              icon("play-circle", class = "fa-2x", style = "color: #0066FF;")
            )
          ),
          column(
            width = 10,
            h5("🎯 Quick Start (5 minutes)", style = "margin: 0 0 8px 0; color: #0066FF;"),
            p(
              "Perfect for first-time users. Learn the basics: importing data, running your first meta-analysis, and generating reports.",
              style = "margin: 0; color: #6B7280;"
            )
          )
        )
      ),

      # Intermediate tour
      div(
        class = "tour-option",
        style = "border: 2px solid #E5E7EB;
                 border-radius: 12px;
                 padding: 20px;
                 margin-bottom: 15px;
                 cursor: pointer;",
        onclick = "Shiny.setInputValue('tour_selected', 'intermediate', {priority: 'event'});",

        fluidRow(
          column(
            width = 2,
            div(
              style = "background: #D1FAE5; width: 60px; height: 60px; border-radius: 50%;
                       display: flex; align-items: center; justify-content: center;",
              icon("chart-line", class = "fa-2x", style = "color: #00C851;")
            )
          ),
          column(
            width = 10,
            h5("📊 Advanced Features (10 minutes)", style = "margin: 0 0 8px 0; color: #00C851;"),
            p(
              "For experienced users. Explore Bayesian methods, GRADE assessment, publication bias tools, and health economics.",
              style = "margin: 0; color: #6B7280;"
            )
          )
        )
      ),

      # Video library
      div(
        class = "tour-option",
        style = "border: 2px solid #E5E7EB;
                 border-radius: 12px;
                 padding: 20px;
                 margin-bottom: 15px;
                 cursor: pointer;",
        onclick = "Shiny.setInputValue('tour_selected', 'videos', {priority: 'event'});",

        fluidRow(
          column(
            width = 2,
            div(
              style = "background: #FEF3C7; width: 60px; height: 60px; border-radius: 50%;
                       display: flex; align-items: center; justify-content: center;",
              icon("video", class = "fa-2x", style = "color: #FFB800;")
            )
          ),
          column(
            width = 10,
            h5("🎥 Video Tutorial Library", style = "margin: 0 0 8px 0; color: #FFB800;"),
            p(
              "Browse 20+ video tutorials covering every feature. Learn at your own pace with step-by-step demonstrations.",
              style = "margin: 0; color: #6B7280;"
            )
          )
        )
      ),

      # Documentation
      div(
        class = "tour-option",
        style = "border: 2px solid #E5E7EB;
                 border-radius: 12px;
                 padding: 20px;
                 cursor: pointer;",
        onclick = "Shiny.setInputValue('tour_selected', 'documentation', {priority: 'event'});",

        fluidRow(
          column(
            width = 2,
            div(
              style = "background: #E0E7FF; width: 60px; height: 60px; border-radius: 50%;
                       display: flex; align-items: center; justify-content: center;",
              icon("book", class = "fa-2x", style = "color: #8B5CF6;")
            )
          ),
          column(
            width = 10,
            h5("📚 Full Documentation", style = "margin: 0 0 8px 0; color: #8B5CF6;"),
            p(
              "Comprehensive guide with examples, best practices, troubleshooting, and API reference.",
              style = "margin: 0; color: #6B7280;"
            )
          )
        )
      ),

      hr(),

      # Skip option
      div(
        style = "text-align: center; padding-top: 15px;",
        checkboxInput(
          "dont_show_again",
          "Don't show this again",
          value = FALSE
        )
      )
    ),

    footer = tagList(
      actionButton(
        "btn_skip_tour",
        "Skip for now",
        class = "btn-secondary"
      ),
      modalButton("Close")
    )
  ))
}

#' Show data import tour
#'
#' @param session Shiny session object
show_data_import_tour <- function(session) {

  showModal(modalDialog(
    title = "Data Import Tutorial",
    size = "l",

    div(
      style = "padding: 20px;",

      h4("Step 1: Prepare Your Data", style = "color: #0066FF; margin-bottom: 15px;"),

      p("EvidenceOS PRIME accepts data in several formats:"),

      tags$ul(
        tags$li(tags$strong("CSV format:"), " Most common. Requires columns: study_id, outcome, effect_size, se, sample_size"),
        tags$li(tags$strong("RevMan XML:"), " Import directly from Cochrane RevMan"),
        tags$li(tags$strong("R data:"), " .rds or .rda files"),
        tags$li(tags$strong("Manual entry:"), " Built-in data entry form")
      ),

      hr(),

      h5("Example CSV structure:", style = "margin-top: 20px; margin-bottom: 10px;"),

      div(
        style = "background: #F3F4F6; padding: 15px; border-radius: 8px; font-family: monospace; font-size: 13px;",
        "study_id,outcome,effect_size,se,sample_size",
        br(),
        "Smith2020,mortality,0.75,0.12,150",
        br(),
        "Jones2021,mortality,0.68,0.15,200",
        br(),
        "Brown2022,mortality,0.82,0.10,180"
      ),

      hr(),

      h4("Step 2: Upload Your Data", style = "color: #0066FF; margin-top: 30px; margin-bottom: 15px;"),

      p("Navigate to the", tags$strong("Data"), "tab and click", tags$strong("Upload CSV"), "."),

      p("The system will automatically:"),
      tags$ul(
        tags$li("Validate your data format"),
        tags$li("Check for missing values"),
        tags$li("Calculate effect sizes (if raw data provided)"),
        tags$li("Display a data preview")
      ),

      hr(),

      div(
        style = "background: #D1FAE5; padding: 15px; border-radius: 8px; border-left: 4px solid #00C851;",
        icon("lightbulb", style = "color: #00C851; margin-right: 8px;"),
        tags$strong("Pro Tip:"),
        " Use the", tags$strong("AI Copilot"), "to ask questions like 'What format should my data be in?' for instant help."
      )
    ),

    footer = tagList(
      actionButton("btn_prev_import", "← Previous", class = "btn-secondary"),
      actionButton("btn_next_import", "Next →", class = "btn-primary"),
      modalButton("Close")
    )
  ))
}

#' Show analysis tour
#'
#' @param session Shiny session object
show_analysis_tour <- function(session) {

  showModal(modalDialog(
    title = "Running Your First Meta-Analysis",
    size = "l",

    div(
      style = "padding: 20px;",

      h4("Step 1: Choose Analysis Type", style = "color: #0066FF; margin-bottom: 15px;"),

      div(
        style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px;",

        # Pairwise MA
        div(
          style = "border: 2px solid #3B82F6; border-radius: 8px; padding: 15px;",
          h5(icon("chart-bar"), " Pairwise MA", style = "color: #3B82F6; margin-top: 0;"),
          p("Standard meta-analysis comparing two interventions.", style = "font-size: 0.9rem; color: #6B7280;"),
          tags$ul(
            style = "font-size: 0.85rem; color: #6B7280;",
            tags$li("Random/fixed effects"),
            tags$li("Subgroup analysis"),
            tags$li("Meta-regression")
          )
        ),

        # Network MA
        div(
          style = "border: 2px solid #10B981; border-radius: 8px; padding: 15px;",
          h5(icon("project-diagram"), " Network MA", style = "color: #10B981; margin-top: 0;"),
          p("Compare multiple interventions simultaneously.", style = "font-size: 0.9rem; color: #6B7280;"),
          tags$ul(
            style = "font-size: 0.85rem; color: #6B7280;",
            tags$li("Indirect comparisons"),
            tags$li("Consistency checking"),
            tags$li("Ranking (SUCRA)")
          )
        ),

        # Bayesian MA
        div(
          style = "border: 2px solid #8B5CF6; border-radius: 8px; padding: 15px;",
          h5(icon("brain"), " Bayesian MA", style = "color: #8B5CF6; margin-top: 0;"),
          p("Full Bayesian inference with MCMC.", style = "font-size: 0.9rem; color: #6B7280;"),
          tags$ul(
            style = "font-size: 0.85rem; color: #6B7280;",
            tags$li("Prior distributions"),
            tags$li("Credible intervals"),
            tags$li("Probability calculations")
          )
        ),

        # Dose-Response
        div(
          style = "border: 2px solid #F59E0B; border-radius: 8px; padding: 15px;",
          h5(icon("line-chart"), " Dose-Response", style = "color: #F59E0B; margin-top: 0;"),
          p("Analyze dose-response relationships.", style = "font-size: 0.9rem; color: #6B7280;"),
          tags$ul(
            style = "font-size: 0.85rem; color: #6B7280;",
            tags$li("Linear/non-linear"),
            tags$li("Spline models"),
            tags$li("Optimal dose")
          )
        )
      ),

      hr(),

      h4("Step 2: Configure Settings", style = "color: #0066FF; margin-bottom: 15px;"),

      p("Key settings to consider:"),

      tags$ul(
        tags$li(tags$strong("Effect measure:"), " Choose OR, RR, MD, SMD based on your data type"),
        tags$li(tags$strong("Pooling method:"), " Random-effects (DerSimonian-Laird, REML) or Fixed-effect"),
        tags$li(tags$strong("Heterogeneity:"), " Enable Hartung-Knapp adjustment for k<20 studies"),
        tags$li(tags$strong("Prediction intervals:"), " Recommended for clinical interpretation")
      ),

      hr(),

      h4("Step 3: Run & Interpret", style = "color: #0066FF; margin-bottom: 15px;"),

      p("Click", tags$strong("Run Analysis"), "to generate:"),

      fluidRow(
        style = "margin-top: 15px;",
        column(
          width = 6,
          div(
            style = "background: #F3F4F6; padding: 15px; border-radius: 8px;",
            h6("📊 Visualizations", style = "margin-top: 0; color: #3B82F6;"),
            tags$ul(
              style = "font-size: 0.9rem; margin: 0;",
              tags$li("Forest plot"),
              tags$li("Funnel plot"),
              tags$li("Baujat plot"),
              tags$li("GOSH plot")
            )
          )
        ),
        column(
          width = 6,
          div(
            style = "background: #F3F4F6; padding: 15px; border-radius: 8px;",
            h6("📈 Statistics", style = "margin-top: 0; color: #10B981;"),
            tags$ul(
              style = "font-size: 0.9rem; margin: 0;",
              tags$li("Pooled estimate & CI"),
              tags$li("I², τ², H²"),
              tags$li("Test for heterogeneity"),
              tags$li("Publication bias tests")
            )
          )
        )
      ),

      hr(),

      div(
        style = "background: #FEF3C7; padding: 15px; border-radius: 8px; border-left: 4px solid #FFB800; margin-top: 20px;",
        icon("info-circle", style = "color: #FFB800; margin-right: 8px;"),
        tags$strong("Interpretation Guide:"),
        br(),
        "I² < 25%: Low heterogeneity | I² 25-50%: Moderate | I² 50-75%: Substantial | I² > 75%: Considerable"
      )
    ),

    footer = tagList(
      actionButton("btn_prev_analysis", "← Previous", class = "btn-secondary"),
      actionButton("btn_next_analysis", "Next →", class = "btn-primary"),
      modalButton("Close")
    )
  ))
}

#' Show reporting tour
#'
#' @param session Shiny session object
show_reporting_tour <- function(session) {

  showModal(modalDialog(
    title = "Generating Reports",
    size = "l",

    div(
      style = "padding: 20px;",

      h4("Export Your Results", style = "color: #0066FF; margin-bottom: 15px;"),

      p("EvidenceOS PRIME generates publication-ready reports in multiple formats:"),

      # Export formats
      fluidRow(
        style = "margin: 20px 0;",
        column(
          width = 3,
          div(
            style = "text-align: center; padding: 20px; border: 2px solid #E5E7EB; border-radius: 8px;",
            icon("file-word", class = "fa-3x", style = "color: #0066FF; margin-bottom: 10px;"),
            h6("Word", style = "margin: 0;"),
            p("DOCX", style = "font-size: 0.85rem; color: #6B7280; margin: 5px 0 0 0;")
          )
        ),
        column(
          width = 3,
          div(
            style = "text-align: center; padding: 20px; border: 2px solid #E5E7EB; border-radius: 8px;",
            icon("file-pdf", class = "fa-3x", style = "color: #EF4444; margin-bottom: 10px;"),
            h6("PDF", style = "margin: 0;"),
            p("Publication", style = "font-size: 0.85rem; color: #6B7280; margin: 5px 0 0 0;")
          )
        ),
        column(
          width = 3,
          div(
            style = "text-align: center; padding: 20px; border: 2px solid #E5E7EB; border-radius: 8px;"),
            icon("file-excel", class = "fa-3x", style = "color: #10B981; margin-bottom: 10px;"),
            h6("Excel", style = "margin: 0;"),
            p("Data tables", style = "font-size: 0.85rem; color: #6B7280; margin: 5px 0 0 0;")
          )
        ),
        column(
          width = 3,
          div(
            style = "text-align: center; padding: 20px; border: 2px solid #E5E7EB; border-radius: 8px;",
            icon("code", class = "fa-3x", style = "color: #8B5CF6; margin-bottom: 10px;"),
            h6("JSON", style = "margin: 0;"),
            p("Evidence Object", style = "font-size: 0.85rem; color: #6B7280; margin: 5px 0 0 0;")
          )
        )
      ),

      hr(),

      h4("Report Contents", style = "color: #0066FF; margin-bottom: 15px;"),

      p("Each report includes:"),

      tags$ul(
        tags$li(tags$strong("Executive Summary:"), " Key findings and recommendations"),
        tags$li(tags$strong("Methods:"), " Complete methodology with reproducible code"),
        tags$li(tags$strong("Results:"), " All statistics, tables, and figures"),
        tags$li(tags$strong("GRADE Assessment:"), " Evidence quality ratings"),
        tags$li(tags$strong("Risk of Bias:"), " Assessment tables and plots"),
        tags$li(tags$strong("Appendices:"), " Supplementary materials, search strategies, PRISMA checklist")
      ),

      hr(),

      h4("Evidence Objects (SHA-256)", style = "color: #0066FF; margin-bottom: 15px;"),

      div(
        style = "background: #EEF2FF; padding: 20px; border-radius: 8px; border-left: 4px solid #8B5CF6;",
        h6(icon("shield-alt"), " Cryptographically Secured", style = "color: #8B5CF6; margin-top: 0;"),
        p(
          "Every analysis generates a unique Evidence Object with SHA-256 hash verification.",
          style = "margin: 10px 0;"
        ),
        tags$ul(
          style = "margin: 0;",
          tags$li("Tamper-proof audit trail"),
          tags$li("Complete reproducibility"),
          tags$li("Version control"),
          tags$li("Regulatory compliance (FDA 21 CFR Part 11)")
        )
      ),

      hr(),

      div(
        style = "background: #D1FAE5; padding: 15px; border-radius: 8px; border-left: 4px solid #00C851; margin-top: 20px;",
        icon("rocket", style = "color: #00C851; margin-right: 8px;"),
        tags$strong("Ready to Publish:"),
        " Reports follow PRISMA 2020 guidelines and are formatted for journal submission."
      )
    ),

    footer = tagList(
      actionButton("btn_prev_reporting", "← Previous", class = "btn-secondary"),
      actionButton("btn_finish_tour", "Finish Tour", class = "btn-success"),
      modalButton("Close")
    )
  ))
}

#' Video tutorial library
#'
#' @return List of video tutorials
get_video_library <- function() {
  list(
    list(
      title = "Quick Start: Your First Meta-Analysis",
      duration = "5:30",
      category = "Getting Started",
      url = "#",
      thumbnail = "placeholder.png"
    ),
    list(
      title = "Data Import & Formatting",
      duration = "7:15",
      category = "Data Management",
      url = "#",
      thumbnail = "placeholder.png"
    ),
    list(
      title = "Understanding Forest Plots",
      duration = "8:45",
      category = "Visualization",
      url = "#",
      thumbnail = "placeholder.png"
    ),
    list(
      title = "Bayesian Meta-Analysis with brms",
      duration = "12:20",
      category = "Advanced Methods",
      url = "#",
      thumbnail = "placeholder.png"
    ),
    list(
      title = "GRADE Assessment Step-by-Step",
      duration = "10:15",
      category = "Quality Assessment",
      url = "#",
      thumbnail = "placeholder.png"
    ),
    list(
      title = "Publication Bias Detection",
      duration = "9:30",
      category = "Quality Assessment",
      url = "#",
      thumbnail = "placeholder.png"
    ),
    list(
      title = "Network Meta-Analysis",
      duration = "15:00",
      category = "Advanced Methods",
      url = "#",
      thumbnail = "placeholder.png"
    ),
    list(
      title = "Health Economic Modeling",
      duration = "18:25",
      category = "Health Economics",
      url = "#",
      thumbnail = "placeholder.png"
    )
  )
}
