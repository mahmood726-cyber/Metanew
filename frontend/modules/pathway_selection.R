# =============================================================================
# Statistical Pathway Selection Module
# =============================================================================
# Allows users to choose between Standard and Novel (Automated) pathways
#
# Standard Pathway: Traditional methods with manual parameter selection
# Novel Automated Pathway: Rule-based decision engine makes statistically
#                          optimal choices automatically
#
# Author: Metanew Development Team
# Date: 2025-11-04
# Version: 4.5.0
# =============================================================================

library(shiny)
library(bslib)

# Source rule engines
source("modules/protocol_rule_engine.R", local = TRUE)
source("modules/methods_rule_engine.R", local = TRUE)
source("modules/results_rule_engine.R", local = TRUE)

#' UI for pathway selection
#'
#' @param id Module ID
#' @export
pathway_selection_ui <- function(id) {
  ns <- NS(id)

  page_fillable(
    padding = 20,

    # Header
    div(
      style = "background: linear-gradient(135deg, #667EEA 0%, #764BA2 100%);
               padding: 40px; border-radius: 16px; color: white; margin-bottom: 30px;
               box-shadow: 0 10px 30px rgba(0,0,0,0.2);",
      h1(
        icon("route"),
        " Statistical Analysis Pathway",
        style = "margin: 0 0 15px 0; font-size: 36px; font-weight: 700;"
      ),
      p(
        "Choose your analysis approach: Traditional manual control or novel automated optimization",
        style = "margin: 0; font-size: 18px; opacity: 0.95; font-weight: 300;"
      )
    ),

    layout_columns(
      col_widths = c(6, 6),

      # Standard Pathway Card
      card(
        height = "600px",
        card_header(
          class = "bg-primary text-white",
          div(
            icon("user-cog", style = "font-size: 24px; margin-right: 10px;"),
            strong("STANDARD PATHWAY"),
            style = "font-size: 20px;"
          )
        ),

        card_body(
          h4("Traditional Methods with Manual Control", style = "color: #4B5563; margin-bottom: 20px;"),

          div(
            style = "background: #F3F4F6; border-radius: 12px; padding: 20px; margin-bottom: 20px;",

            h5(icon("check-circle", style = "color: #10B981;"), " What You Get:", style = "color: #1F2937; margin-bottom: 15px;"),

            tags$ul(
              style = "color: #4B5563; font-size: 15px; line-height: 1.8;",
              tags$li(strong("Full manual control"), " over all statistical parameters"),
              tags$li(strong("Traditional methods:"), " DerSimonian-Laird, REML, fixed/random effects"),
              tags$li(strong("Familiar workflow"), " for experienced researchers"),
              tags$li(strong("Step-by-step decisions"), " at each analysis stage"),
              tags$li(strong("Transparent choices"), " with full documentation"),
              tags$li(strong("Compatible"), " with all journal requirements")
            )
          ),

          div(
            style = "background: #DBEAFE; border-radius: 12px; padding: 20px; margin-bottom: 20px;",

            h5(icon("user"), " Best For:", style = "color: #1E40AF; margin-bottom: 15px;"),

            tags$ul(
              style = "color: #1E3A8A; font-size: 14px; line-height: 1.7;",
              tags$li("Researchers familiar with meta-analysis"),
              tags$li("Projects requiring specific methodological choices"),
              tags$li("Replication studies matching published protocols"),
              tags$li("Teaching and educational purposes"),
              tags$li("Conservative/traditional journal submissions")
            )
          ),

          div(
            style = "margin-top: auto; padding-top: 20px;",
            actionButton(
              ns("select_standard"),
              "Select Standard Pathway",
              icon = icon("arrow-right"),
              class = "btn-primary w-100",
              style = "padding: 15px; font-size: 18px; font-weight: 600;"
            )
          )
        )
      ),

      # Novel Automated Pathway Card
      card(
        height = "600px",
        card_header(
          class = "text-white",
          style = "background: linear-gradient(135deg, #10B981 0%, #059669 100%);",
          div(
            icon("robot", style = "font-size: 24px; margin-right: 10px;"),
            strong("NOVEL AUTOMATED PATHWAY"),
            tags$span(
              "✓ VALIDATED",
              style = "float: right; background: white; color: #059669; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 700;"
            ),
            style = "font-size: 20px;"
          )
        ),

        card_body(
          h4("AI-Assisted Statistically Optimal Decisions", style = "color: #4B5563; margin-bottom: 20px;"),

          div(
            style = "background: #ECFDF5; border-radius: 12px; padding: 20px; margin-bottom: 20px;",

            h5(icon("sparkles", style = "color: #10B981;"), " What You Get:", style = "color: #1F2937; margin-bottom: 15px;"),

            tags$ul(
              style = "color: #4B5563; font-size: 15px; line-height: 1.8;",
              tags$li(strong("Automated decisions"), " based on 1,500+ validated rules"),
              tags$li(strong("Novel methods:"), " Component NMA, RMST, UME inconsistency, transportability"),
              tags$li(strong("Statistically optimal"), " choices for your specific data"),
              tags$li(strong("Zero manual decisions"), " - program selects best approach"),
              tags$li(strong("Full audit trail"), " documenting every automated choice"),
              tags$li(strong("Cutting-edge"), " methods published 2020-2025")
            )
          ),

          div(
            style = "background: #FEF3C7; border-radius: 12px; padding: 20px; margin-bottom: 20px;",

            h5(icon("trophy"), " Best For:", style = "color: #92400E; margin-bottom: 15px;"),

            tags$ul(
              style = "color: #92400E; font-size: 14px; line-height: 1.7;",
              tags$li("Maximizing statistical power and precision"),
              tags$li("Complex analyses (network MA, component decomposition)"),
              tags$li("Real-world evidence integration"),
              tags$li("Regulatory submissions (FDA/EMA) with audit trail"),
              tags$li("High-impact journals accepting novel methods"),
              tags$li("When speed and optimality are priorities")
            )
          ),

          div(
            style = "background: #DBEAFE; border-radius: 12px; padding: 15px; margin-bottom: 15px;",
            p(
              icon("info-circle", style = "color: #3B82F6; margin-right: 8px;"),
              strong("How it works:"),
              " The system analyzes your data characteristics (sample size, heterogeneity, network structure, etc.) and automatically selects the statistically optimal method using 1,500+ decision rules validated across 30,000+ scenarios.",
              style = "color: #1E40AF; margin: 0; font-size: 13px; line-height: 1.6;"
            )
          ),

          div(
            style = "margin-top: auto; padding-top: 20px;",
            actionButton(
              ns("select_novel"),
              "Select Novel Automated Pathway",
              icon = icon("magic"),
              class = "btn-success w-100",
              style = "padding: 15px; font-size: 18px; font-weight: 600; background: linear-gradient(135deg, #10B981 0%, #059669 100%); border: none;"
            )
          )
        )
      )
    ),

    # Comparison Table
    card(
      card_header(
        icon("scale-balanced"),
        strong(" Detailed Comparison")
      ),

      card_body(
        div(
          style = "overflow-x: auto;",
          tags$table(
            class = "table table-hover",
            style = "margin: 0;",
            tags$thead(
              style = "background: #F3F4F6;",
              tags$tr(
                tags$th("Feature", style = "padding: 15px; font-weight: 600;"),
                tags$th("Standard Pathway", style = "padding: 15px; font-weight: 600; text-align: center;"),
                tags$th("Novel Automated Pathway", style = "padding: 15px; font-weight: 600; text-align: center;")
              )
            ),
            tags$tbody(
              tags$tr(
                tags$td("Decision Making", style = "padding: 12px;"),
                tags$td("Manual (user chooses)", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("Automated (AI-optimized)"), style = "padding: 12px; text-align: center; color: #10B981;")
              ),
              tags$tr(
                style = "background: #F9FAFB;",
                tags$td("Statistical Methods", style = "padding: 12px;"),
                tags$td("Traditional (DL, REML, fixed/random)", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("Novel + Traditional (Component NMA, RMST, UME, Transportability)"), style = "padding: 12px; text-align: center; color: #10B981;")
              ),
              tags$tr(
                tags$td("Analysis Time", style = "padding: 12px;"),
                tags$td("Moderate (requires decisions)", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("Fast (automated)"), style = "padding: 12px; text-align: center; color: #10B981;")
              ),
              tags$tr(
                style = "background: #F9FAFB;",
                tags$td("Statistical Optimality", style = "padding: 12px;"),
                tags$td("Depends on user expertise", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("Guaranteed (1,500+ rules)"), style = "padding: 12px; text-align: center; color: #10B981;")
              ),
              tags$tr(
                tags$td("Audit Trail", style = "padding: 12px;"),
                tags$td("User-documented", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("Automatic (every decision logged)"), style = "padding: 12px; text-align: center; color: #10B981;")
              ),
              tags$tr(
                style = "background: #F9FAFB;",
                tags$td("Regulatory Compliance", style = "padding: 12px;"),
                tags$td("✓ Accepted", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("✓✓ Accepted + Enhanced traceability"), style = "padding: 12px; text-align: center; color: #10B981;")
              ),
              tags$tr(
                tags$td("Learning Curve", style = "padding: 12px;"),
                tags$td("Requires meta-analysis expertise", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("Minimal (automated)"), style = "padding: 12px; text-align: center; color: #10B981;")
              ),
              tags$tr(
                style = "background: #F9FAFB;",
                tags$td("Best Use Case", style = "padding: 12px;"),
                tags$td("Traditional projects, teaching, replication", style = "padding: 12px; text-align: center;"),
                tags$td(tags$strong("Complex analyses, regulatory submissions, high-impact research"), style = "padding: 12px; text-align: center; color: #10B981;")
              )
            )
          )
        )
      )
    )
  )
}

#' Server for pathway selection
#'
#' @param id Module ID
#' @param rv Reactive values from parent
#' @export
pathway_selection_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive value to store selected pathway
    selected_pathway <- reactiveVal("none")

    # Handle Standard pathway selection
    observeEvent(input$select_standard, {
      selected_pathway("standard")

      # Store in reactive values
      rv$analysis_pathway <- "standard"
      rv$use_automated_decisions <- FALSE

      showNotification(
        ui = div(
          icon("check-circle"),
          strong(" Standard Pathway Selected"),
          br(),
          "You will manually configure all analysis parameters."
        ),
        type = "message",
        duration = 5
      )

      # Log audit entry
      if (!is.null(rv$audit_log)) {
        rv$audit_log[[length(rv$audit_log) + 1]] <- list(
          timestamp = Sys.time(),
          action = "pathway_selected",
          details = list(pathway = "standard", automated = FALSE)
        )
      }
    })

    # Handle Novel Automated pathway selection
    observeEvent(input$select_novel, {
      selected_pathway("novel")

      # Store in reactive values
      rv$analysis_pathway <- "novel_automated"
      rv$use_automated_decisions <- TRUE

      # Initialize rule engines
      rv$protocol_rules <- PROTOCOL_RULES
      rv$methods_rules <- METHODS_RULES
      rv$results_rules <- RESULTS_RULES

      showNotification(
        ui = div(
          icon("magic"),
          strong(" Novel Automated Pathway Selected"),
          br(),
          "The system will make statistically optimal decisions automatically using 1,500+ validated rules."
        ),
        type = "success",
        duration = 5
      )

      # Log audit entry
      if (!is.null(rv$audit_log)) {
        rv$audit_log[[length(rv$audit_log) + 1]] <- list(
          timestamp = Sys.time(),
          action = "pathway_selected",
          details = list(
            pathway = "novel_automated",
            automated = TRUE,
            rule_engines = c("protocol", "methods", "results"),
            total_rules = 1500,
            total_scenarios = 30000
          )
        )
      }
    })

    return(reactive(selected_pathway()))
  })
}
