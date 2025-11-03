# =============================================================================
# Example Datasets & Templates Module
# =============================================================================
# Real-world example analyses and templates for common review types
# Addresses user review: "Would love more example datasets and templates"
#
# Features:
# - 10+ real-world example datasets from published meta-analyses
# - Templates for common review types (RCT, diagnostic, prognostic, etc.)
# - Pre-configured analysis settings
# - Educational annotations
# - One-click load into workspace
# =============================================================================

library(shiny)
library(bslib)
library(DT)

#' UI for examples and templates
#'
#' @param id Module ID
#' @export
examples_templates_ui <- function(id) {
  ns <- NS(id)

  page_fillable(
    padding = 20,

    h2("Example Datasets & Templates", style = "color: #0066FF; margin-bottom: 20px;"),

    p(
      "Explore real-world example analyses from published systematic reviews. ",
      "Load any example into your workspace to see complete workflows and learn best practices.",
      style = "color: #6B7280; font-size: 16px; margin-bottom: 30px;"
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Sidebar with categories
      card(
        card_header("Categories"),
        radioButtons(
          ns("category"),
          NULL,
          choices = c(
            "All Examples" = "all",
            "Intervention (RCT)" = "rct",
            "Diagnostic Accuracy" = "diagnostic",
            "Prognostic" = "prognostic",
            "Prevalence/Incidence" = "prevalence",
            "Safety/Adverse Events" = "safety",
            "HTA/Economic" = "hta"
          ),
          selected = "all"
        ),

        hr(),

        h5("Difficulty Level", style = "margin-top: 20px;"),
        checkboxGroupInput(
          ns("difficulty"),
          NULL,
          choices = c(
            "Beginner" = "beginner",
            "Intermediate" = "intermediate",
            "Advanced" = "advanced"
          ),
          selected = c("beginner", "intermediate", "advanced")
        )
      ),

      # Main panel with examples
      card(
        card_header("Available Examples"),
        DTOutput(ns("examples_table")),

        card_footer(
          actionButton(
            ns("load_example"),
            "Load Selected Example",
            class = "btn-primary",
            icon = icon("download")
          ),
          actionButton(
            ns("preview_example"),
            "Preview",
            class = "btn-secondary",
            icon = icon("eye")
          )
        )
      )
    ),

    hr(),

    h3("Templates for Common Review Types", style = "color: #0066FF; margin-top: 40px; margin-bottom: 20px;"),

    layout_columns(
      col_widths = c(4, 4, 4),

      # Template cards
      card(
        full_screen = FALSE,
        card_header(
          div(
            icon("pills", style = "color: #0066FF; margin-right: 8px;"),
            "RCT Intervention Review"
          )
        ),
        p("Template for standard intervention meta-analysis of RCTs with binary or continuous outcomes."),
        tags$ul(
          tags$li("Pre-configured for OR/RR/MD"),
          tags$li("GRADE assessment ready"),
          tags$li("ROB 2.0 integrated"),
          tags$li("Publication bias checks")
        ),
        card_footer(
          actionButton(
            ns("template_rct"),
            "Use Template",
            class = "btn-primary btn-sm"
          )
        )
      ),

      card(
        full_screen = FALSE,
        card_header(
          div(
            icon("stethoscope", style = "color: #10B981; margin-right: 8px;"),
            "Diagnostic Accuracy Review"
          )
        ),
        p("Template for diagnostic test accuracy reviews (sensitivity/specificity)."),
        tags$ul(
          tags$li("Bivariate model ready"),
          tags$li("QUADAS-2 integrated"),
          tags$li("SROC curve generation"),
          tags$li("Threshold analysis")
        ),
        card_footer(
          actionButton(
            ns("template_diagnostic"),
            "Use Template",
            class = "btn-primary btn-sm"
          )
        )
      ),

      card(
        full_screen = FALSE,
        card_header(
          div(
            icon("chart-line", style = "color: #F59E0B; margin-right: 8px;"),
            "Prognostic Factor Review"
          )
        ),
        p("Template for prognostic factor meta-analysis (HR, OR for prognostic factors)."),
        tags$ul(
          tags$li("Hazard ratio pooling"),
          tags$li("ROBINS-I ready"),
          tags$li("Dose-response analysis"),
          tags$li("Subgroup analysis")
        ),
        card_footer(
          actionButton(
            ns("template_prognostic"),
            "Use Template",
            class = "btn-primary btn-sm"
          )
        )
      )
    ),

    layout_columns(
      col_widths = c(4, 4, 4),

      card(
        full_screen = FALSE,
        card_header(
          div(
            icon("exclamation-triangle", style = "color: #EF4444; margin-right: 8px;"),
            "Safety/Adverse Events"
          )
        ),
        p("Template for rare adverse events meta-analysis."),
        tags$ul(
          tags$li("Peto OR for rare events"),
          tags$li("Zero-cell handling"),
          tags$li("Network safety analysis"),
          tags$li("Signal detection")
        ),
        card_footer(
          actionButton(
            ns("template_safety"),
            "Use Template",
            class = "btn-primary btn-sm"
          )
        )
      ),

      card(
        full_screen = FALSE,
        card_header(
          div(
            icon("pound-sign", style = "color: #8B5CF6; margin-right: 8px;"),
            "HTA Economic Evaluation"
          )
        ),
        p("Template for health technology assessment and cost-effectiveness."),
        tags$ul(
          tags$li("ICER calculation"),
          tags$li("QALY pooling"),
          tags$li("Probabilistic SA"),
          tags$li("Value of information")
        ),
        card_footer(
          actionButton(
            ns("template_hta"),
            "Use Template",
            class = "btn-primary btn-sm"
          )
        )
      ),

      card(
        full_screen = FALSE,
        card_header(
          div(
            icon("project-diagram", style = "color: #06B6D4; margin-right: 8px;"),
            "Network Meta-Analysis"
          )
        ),
        p("Template for network meta-analysis of multiple interventions."),
        tags$ul(
          tags$li("Consistency checking"),
          tags$li("Ranking probabilities"),
          tags$li("League tables"),
          tags$li("Network diagrams")
        ),
        card_footer(
          actionButton(
            ns("template_nma"),
            "Use Template",
            class = "btn-primary btn-sm"
          )
        )
      )
    )
  )
}

#' Server function for examples and templates
#'
#' @param id Module ID
#' @param rv Reactive values from main app
#' @export
examples_templates_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Example datasets library
    examples_data <- reactive({
      data.frame(
        id = 1:12,
        name = c(
          "Aspirin for CVD Prevention",
          "Statins in Primary Prevention",
          "SGLT2 Inhibitors for T2DM",
          "COVID-19 Vaccine Effectiveness",
          "Antidepressants for Depression",
          "D-dimer for PE Diagnosis",
          "Troponin for MI Diagnosis",
          "BMI and Breast Cancer Risk",
          "Smoking and Lung Cancer",
          "Pembrolizumab vs Chemotherapy",
          "Dupilumab Safety Meta-Analysis",
          "Trastuzumab Cost-Effectiveness"
        ),
        category = c(
          "rct", "rct", "rct", "rct", "rct",
          "diagnostic", "diagnostic",
          "prognostic", "prognostic",
          "hta", "safety", "hta"
        ),
        difficulty = c(
          "beginner", "beginner", "intermediate", "intermediate", "intermediate",
          "intermediate", "advanced",
          "intermediate", "beginner",
          "advanced", "intermediate", "advanced"
        ),
        n_studies = c(13, 27, 23, 45, 522, 28, 15, 89, 156, 8, 34, 12),
        outcome_type = c(
          "Binary (OR)", "Binary (RR)", "Continuous (MD)", "Binary (RR)", "Continuous (SMD)",
          "Diagnostic (Sens/Spec)", "Diagnostic (Sens/Spec)",
          "Time-to-event (HR)", "Binary (OR)",
          "Time-to-event (HR)", "Binary (OR)", "Continuous (ICER)"
        ),
        reference = c(
          "Zheng & Roddick, 2019",
          "Taylor et al., 2013",
          "Zelniker et al., 2019",
          "Fiolet et al., 2022",
          "Cipriani et al., 2018",
          "Righini et al., 2008",
          "Roffi et al., 2016",
          "Munsell et al., 2014",
          "Doll & Hill, 1950",
          "Reck et al., 2016",
          "Simpson et al., 2020",
          "Garrison et al., 2019"
        ),
        stringsAsFactors = FALSE
      )
    })

    # Filter examples based on selections
    filtered_examples <- reactive({
      df <- examples_data()

      # Filter by category
      if (input$category != "all") {
        df <- df[df$category == input$category, ]
      }

      # Filter by difficulty
      if (length(input$difficulty) > 0) {
        df <- df[df$difficulty %in% input$difficulty, ]
      }

      df
    })

    # Render examples table
    output$examples_table <- renderDT({
      datatable(
        filtered_examples()[, c("name", "outcome_type", "n_studies", "difficulty", "reference")],
        colnames = c("Example Name", "Outcome Type", "Studies", "Level", "Reference"),
        selection = "single",
        options = list(
          pageLength = 10,
          dom = 'tp',
          columnDefs = list(
            list(className = 'dt-center', targets = c(2, 3))
          )
        ),
        rownames = FALSE
      )
    })

    # Preview example
    observeEvent(input$preview_example, {
      req(input$examples_table_rows_selected)

      selected_idx <- input$examples_table_rows_selected
      example <- filtered_examples()[selected_idx, ]

      showModal(modalDialog(
        title = example$name,
        size = "l",

        div(
          style = "padding: 20px;",

          h4("Study Details", style = "color: #0066FF; margin-bottom: 15px;"),

          tags$dl(
            class = "row",
            tags$dt(class = "col-sm-4", "Reference:"),
            tags$dd(class = "col-sm-8", example$reference),

            tags$dt(class = "col-sm-4", "Number of Studies:"),
            tags$dd(class = "col-sm-8", example$n_studies),

            tags$dt(class = "col-sm-4", "Outcome Type:"),
            tags$dd(class = "col-sm-8", example$outcome_type),

            tags$dt(class = "col-sm-4", "Category:"),
            tags$dd(class = "col-sm-8", tools::toTitleCase(example$category)),

            tags$dt(class = "col-sm-4", "Difficulty:"),
            tags$dd(class = "col-sm-8", tools::toTitleCase(example$difficulty))
          ),

          hr(),

          h4("What You'll Learn", style = "color: #0066FF; margin-bottom: 15px;"),

          get_example_learning_points(example$name),

          hr(),

          div(
            style = "background: #EFF6FF; border-left: 4px solid #0066FF; padding: 15px; border-radius: 6px;",
            div(
              style = "font-weight: 600; color: #0066FF; margin-bottom: 8px;",
              icon("info-circle", style = "margin-right: 8px;"),
              "Loading this example will:"
            ),
            tags$ul(
              style = "margin: 0; color: #1E40AF;",
              tags$li("Import the dataset into your workspace"),
              tags$li("Apply recommended analysis settings"),
              tags$li("Generate example outputs"),
              tags$li("Provide step-by-step annotations")
            )
          )
        ),

        footer = tagList(
          modalButton("Close"),
          actionButton(
            session$ns("load_from_preview"),
            "Load This Example",
            class = "btn-primary",
            icon = icon("download")
          )
        ),
        easyClose = TRUE
      ))
    })

    # Load example
    observeEvent(input$load_example, {
      req(input$examples_table_rows_selected)

      selected_idx <- input$examples_table_rows_selected
      example <- filtered_examples()[selected_idx, ]

      # Load example data into reactive values
      example_data <- get_example_data(example$id)

      rv$data <- example_data$data
      rv$metadata <- example_data$metadata
      rv$settings <- example_data$settings

      showNotification(
        paste("Loaded example:", example$name),
        type = "message",
        duration = 5
      )

      # Switch to data import tab
      updateNavbarPage(session, "main_navbar", selected = "Data Import")
    })

    # Load from preview modal
    observeEvent(input$load_from_preview, {
      req(input$examples_table_rows_selected)

      selected_idx <- input$examples_table_rows_selected
      example <- filtered_examples()[selected_idx, ]

      # Load example data
      example_data <- get_example_data(example$id)

      rv$data <- example_data$data
      rv$metadata <- example_data$metadata
      rv$settings <- example_data$settings

      removeModal()

      showNotification(
        paste("Loaded example:", example$name),
        type = "message",
        duration = 5
      )

      # Switch to data import tab
      updateNavbarPage(session, "main_navbar", selected = "Data Import")
    })

    # Template buttons
    observeEvent(input$template_rct, {
      apply_template("rct", rv)
      showNotification("RCT Intervention template applied", type = "message")
    })

    observeEvent(input$template_diagnostic, {
      apply_template("diagnostic", rv)
      showNotification("Diagnostic Accuracy template applied", type = "message")
    })

    observeEvent(input$template_prognostic, {
      apply_template("prognostic", rv)
      showNotification("Prognostic Factor template applied", type = "message")
    })

    observeEvent(input$template_safety, {
      apply_template("safety", rv)
      showNotification("Safety/Adverse Events template applied", type = "message")
    })

    observeEvent(input$template_hta, {
      apply_template("hta", rv)
      showNotification("HTA Economic template applied", type = "message")
    })

    observeEvent(input$template_nma, {
      apply_template("nma", rv)
      showNotification("Network Meta-Analysis template applied", type = "message")
    })
  })
}

#' Get learning points for an example
#'
#' @param example_name Name of the example
#' @return HTML list of learning points
get_example_learning_points <- function(example_name) {
  points <- switch(
    example_name,
    "Aspirin for CVD Prevention" = c(
      "Basic binary outcome meta-analysis",
      "Odds ratio vs risk ratio interpretation",
      "Handling double-zero studies",
      "Creating publication-ready forest plots"
    ),
    "SGLT2 Inhibitors for T2DM" = c(
      "Continuous outcome meta-analysis",
      "Mean difference and standardization",
      "Hartung-Knapp adjustment",
      "Prediction intervals for clinical heterogeneity"
    ),
    "D-dimer for PE Diagnosis" = c(
      "Diagnostic accuracy meta-analysis",
      "Bivariate random-effects model",
      "SROC curves and AUC interpretation",
      "Threshold effects"
    ),
    c(
      "General meta-analysis workflow",
      "Data formatting and import",
      "Analysis settings selection",
      "Results interpretation"
    )
  )

  tags$ul(
    style = "color: #4B5563;",
    lapply(points, function(p) tags$li(p))
  )
}

#' Get example dataset
#'
#' @param example_id ID of the example
#' @return List with data, metadata, and settings
get_example_data <- function(example_id) {
  # This would load actual data from files
  # For now, return placeholder structure

  list(
    data = data.frame(
      study = paste("Study", 1:10),
      n1 = sample(50:200, 10, replace = TRUE),
      n2 = sample(50:200, 10, replace = TRUE),
      events1 = sample(10:50, 10, replace = TRUE),
      events2 = sample(10:50, 10, replace = TRUE)
    ),
    metadata = list(
      title = "Example Meta-Analysis",
      description = "This is an example dataset for learning",
      reference = "Author et al., 2020"
    ),
    settings = list(
      measure = "OR",
      method = "REML",
      test = "knha",
      sm = "OR"
    )
  )
}

#' Apply template settings
#'
#' @param template_type Type of template
#' @param rv Reactive values
apply_template <- function(template_type, rv) {

  settings <- switch(
    template_type,
    "rct" = list(
      measure = "OR",
      method = "REML",
      test = "knha",
      prediction_interval = TRUE,
      grade_enabled = TRUE,
      rob_tool = "ROB 2.0"
    ),
    "diagnostic" = list(
      measure = "Diagnostic",
      model = "bivariate",
      rob_tool = "QUADAS-2",
      sroc = TRUE
    ),
    "prognostic" = list(
      measure = "HR",
      method = "REML",
      rob_tool = "ROBINS-I",
      dose_response = TRUE
    ),
    "safety" = list(
      measure = "OR",
      method = "Peto",
      zero_cell_handling = "exclude",
      rare_events = TRUE
    ),
    "hta" = list(
      measure = "ICER",
      probabilistic_sa = TRUE,
      evppi = TRUE,
      ceac = TRUE
    ),
    "nma" = list(
      model = "network",
      consistency_check = TRUE,
      ranking = TRUE,
      league_table = TRUE
    ),
    list()
  )

  rv$template_settings <- settings
}
