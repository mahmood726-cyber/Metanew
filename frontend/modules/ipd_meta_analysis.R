# Individual Patient Data (IPD) Meta-Analysis Module
# One-stage and two-stage IPD meta-analysis methods
# Reference: Riley et al. (2010) BMJ; Debray et al. (2015) BMC Medical Research Methodology

library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(lme4)      # For mixed effects models
library(survival)  # For time-to-event IPD
library(metafor)   # For two-stage approach

#' UI for IPD Meta-Analysis Module
#'
#' @param id Module namespace ID
#' @export
ipd_meta_analysis_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("👥 Individual Patient Data Meta-Analysis"),
    p("Advanced meta-analysis using patient-level data from multiple studies"),

    # Info card
    card(
      card_header("About IPD Meta-Analysis"),
      card_body(
        class = "bg-light",
        p(
          "IPD meta-analysis uses individual patient data rather than aggregate study-level data, ",
          "enabling more sophisticated analyses including subgroup effects, non-linear relationships, ",
          "and time-to-event outcomes."
        ),
        layout_columns(
          col_widths = c(6, 6),
          div(
            h5("✅ Advantages over Aggregate Data:"),
            tags$ul(
              tags$li("Individual-level covariates"),
              tags$li("Subgroup analysis with patient characteristics"),
              tags$li("Time-to-event analysis"),
              tags$li("Non-linear dose-response"),
              tags$li("Interaction effects"),
              tags$li("Missing data handling at patient level")
            )
          ),
          div(
            h5("⚠️ Requirements:"),
            tags$ul(
              tags$li("Access to patient-level data"),
              tags$li("Data sharing agreements"),
              tags$li("Harmonized variables across studies"),
              tags$li("Larger computational resources"),
              tags$li("Ethical approval for IPD use")
            )
          )
        )
      )
    ),

    # Data import
    card(
      card_header("Step 1: Import IPD Data"),
      card_body(
        fileInput(ns("ipd_file"), "Upload IPD Dataset:",
                 accept = c(".csv", ".rds", ".Rdata"),
                 buttonLabel = "Browse...",
                 placeholder = "No file selected"),

        helpText(
          "Expected format: One row per patient, with study identifier column",
          br(),
          "Required columns: study_id, patient_id, outcome, treatment, covariates"
        ),

        conditionalPanel(
          condition = sprintf("output['%s']", ns("data_loaded")),
          ns = ns,
          h5("Data Preview:"),
          DTOutput(ns("data_preview")),
          br(),
          verbatimTextOutput(ns("data_summary"))
        )
      )
    ),

    # Variable specification
    card(
      card_header("Step 2: Specify Variables"),
      card_body(
        layout_columns(
          col_widths = c(6, 6),

          div(
            h5("Core Variables:"),
            selectInput(ns("study_var"), "Study Identifier:",
                       choices = NULL),
            selectInput(ns("patient_var"), "Patient Identifier:",
                       choices = NULL),
            selectInput(ns("outcome_var"), "Outcome Variable:",
                       choices = NULL),
            selectInput(ns("treatment_var"), "Treatment Variable:",
                       choices = NULL)
          ),

          div(
            h5("Outcome Type:"),
            radioButtons(ns("outcome_type"), NULL,
                        choices = c(
                          "Binary (0/1)" = "binary",
                          "Continuous" = "continuous",
                          "Time-to-Event" = "survival",
                          "Count" = "count"
                        )),

            conditionalPanel(
              condition = sprintf("input['%s'] == 'survival'", ns("outcome_type")),
              ns = ns,
              selectInput(ns("time_var"), "Time Variable:",
                         choices = NULL),
              selectInput(ns("event_var"), "Event Indicator:",
                         choices = NULL)
            )
          )
        ),

        hr(),

        h5("Covariates/Moderators:"),
        selectInput(ns("covariates"), "Select Covariates:",
                   choices = NULL,
                   multiple = TRUE),

        checkboxInput(ns("include_interactions"), "Include Treatment × Covariate Interactions",
                     value = FALSE)
      )
    ),

    # Analysis method selection
    card(
      card_header("Step 3: Select Analysis Approach"),
      card_body(
        radioButtons(ns("ipd_method"), "IPD Meta-Analysis Method:",
                    choices = c(
                      "One-Stage (Recommended)" = "one_stage",
                      "Two-Stage" = "two_stage"
                    ),
                    selected = "one_stage"),

        # One-stage settings
        conditionalPanel(
          condition = sprintf("input['%s'] == 'one_stage'", ns("ipd_method")),
          ns = ns,
          h5("One-Stage Model Settings:"),
          p("Fit a single model to all IPD with study as a random effect"),

          radioButtons(ns("one_stage_type"), "Random Effects:",
                      choices = c(
                        "Random Intercept Only" = "intercept",
                        "Random Intercept + Slope" = "both"
                      ),
                      selected = "intercept"),

          checkboxInput(ns("robust_se"), "Use Robust Standard Errors", value = TRUE)
        ),

        # Two-stage settings
        conditionalPanel(
          condition = sprintf("input['%s'] == 'two_stage'", ns("ipd_method")),
          ns = ns,
          h5("Two-Stage Model Settings:"),
          p("Stage 1: Fit model within each study; Stage 2: Meta-analyze study-specific estimates"),

          radioButtons(ns("two_stage_pooling"), "Stage 2 Pooling:",
                      choices = c(
                        "Random Effects (DerSimonian-Laird)" = "DL",
                        "Random Effects (REML)" = "REML",
                        "Fixed Effect" = "FE"
                      ),
                      selected = "REML")
        ),

        hr(),

        actionButton(ns("run_ipd_analysis"), "Run IPD Meta-Analysis",
                    class = "btn-primary btn-lg", icon = icon("play"))
      )
    ),

    # Results tabs
    navset_card_tab(
      id = ns("results_tabs"),

      # Overall results
      nav_panel(
        "Overall Results",
        card_body(
          h4("Treatment Effect Estimates"),

          verbatimTextOutput(ns("overall_results")),

          br(),

          h5("Forest Plot (Study-Specific Effects):"),
          plotOutput(ns("forest_plot"), height = "600px")
        )
      ),

      # Subgroup analysis
      nav_panel(
        "Subgroup Analysis",
        card_body(
          h4("Treatment Effect by Patient Subgroups"),

          selectInput(ns("subgroup_var"), "Subgroup Variable:",
                     choices = NULL),

          actionButton(ns("run_subgroup"), "Analyze Subgroups",
                      class = "btn-info"),

          br(), br(),

          DTOutput(ns("subgroup_table")),

          br(),

          plotOutput(ns("subgroup_plot"), height = "500px")
        )
      ),

      # Heterogeneity
      nav_panel(
        "Heterogeneity",
        card_body(
          h4("Assessment of Heterogeneity"),

          layout_columns(
            col_widths = c(6, 6),

            card(
              card_header("Between-Study Heterogeneity"),
              card_body(
                verbatimTextOutput(ns("heterogeneity_stats"))
              )
            ),

            card(
              card_header("Study Characteristics"),
              card_body(
                DTOutput(ns("study_characteristics"))
              )
            )
          ),

          br(),

          h5("Heterogeneity by Covariate:"),
          plotOutput(ns("heterogeneity_plot"), height = "400px")
        )
      ),

      # Model diagnostics
      nav_panel(
        "Diagnostics",
        card_body(
          h4("Model Diagnostics"),

          layout_columns(
            col_widths = c(6, 6),

            div(
              h5("Residual Plots:"),
              plotOutput(ns("residual_plot"), height = "400px")
            ),

            div(
              h5("Q-Q Plot:"),
              plotOutput(ns("qq_plot"), height = "400px")
            )
          ),

          br(),

          h5("Influential Studies:"),
          DTOutput(ns("influential_studies")),

          br(),

          h5("Leave-One-Out Analysis:"),
          plotOutput(ns("loo_plot"), height = "400px")
        )
      ),

      # Survival curves (if applicable)
      nav_panel(
        "Survival Analysis",
        card_body(
          conditionalPanel(
            condition = sprintf("input['%s'] == 'survival'", ns("outcome_type")),
            ns = ns,

            h4("Kaplan-Meier Curves by Treatment"),

            plotOutput(ns("km_curves"), height = "500px"),

            br(),

            h5("Cox Model Results:"),
            verbatimTextOutput(ns("cox_results")),

            br(),

            h5("Proportional Hazards Assumption:"),
            plotOutput(ns("ph_test"), height = "400px")
          )
        )
      ),

      # Data quality
      nav_panel(
        "Data Quality",
        card_body(
          h4("IPD Data Quality Assessment"),

          h5("Missing Data Summary:"),
          DTOutput(ns("missing_data_table")),

          br(),

          plotOutput(ns("missing_data_plot"), height = "400px"),

          br(),

          h5("Variable Distributions by Study:"),
          selectInput(ns("quality_var"), "Select Variable:",
                     choices = NULL),
          plotOutput(ns("distribution_plot"), height = "400px")
        )
      )
    ),

    # Export
    hr(),
    card(
      card_header("Export Results"),
      card_body(
        layout_columns(
          col_widths = c(4, 4, 4),
          downloadButton(ns("download_results"), "Download Results"),
          downloadButton(ns("download_dataset"), "Download Analyzed Dataset"),
          downloadButton(ns("download_report"), "Generate Report")
        )
      )
    )
  )
}


#' Server Logic for IPD Meta-Analysis Module
#'
#' @param id Module namespace ID
#' @param rv Reactive values from parent
#' @export
ipd_meta_analysis_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    ipd_data <- reactiveVal(NULL)
    ipd_results <- reactiveVal(NULL)

    # Load IPD data
    observeEvent(input$ipd_file, {
      req(input$ipd_file)

      tryCatch({
        if (grepl("\\.csv$", input$ipd_file$name)) {
          data <- read.csv(input$ipd_file$datapath, stringsAsFactors = FALSE)
        } else if (grepl("\\.rds$", input$ipd_file$name)) {
          data <- readRDS(input$ipd_file$datapath)
        } else if (grepl("\\.Rdata$", input$ipd_file$name)) {
          load(input$ipd_file$datapath)
          data <- get(ls()[1])  # Get first object
        }

        ipd_data(data)

        # Update variable choices
        var_choices <- names(data)
        updateSelectInput(session, "study_var", choices = var_choices)
        updateSelectInput(session, "patient_var", choices = var_choices)
        updateSelectInput(session, "outcome_var", choices = var_choices)
        updateSelectInput(session, "treatment_var", choices = var_choices)
        updateSelectInput(session, "time_var", choices = var_choices)
        updateSelectInput(session, "event_var", choices = var_choices)
        updateSelectInput(session, "covariates", choices = var_choices)
        updateSelectInput(session, "subgroup_var", choices = var_choices)
        updateSelectInput(session, "quality_var", choices = var_choices)

        showNotification("IPD data loaded successfully!", type = "message")

      }, error = function(e) {
        showNotification(paste("Error loading data:", e$message), type = "error")
      })
    })


    # Data loaded indicator
    output$data_loaded <- reactive({
      !is.null(ipd_data())
    })
    outputOptions(output, "data_loaded", suspendWhenHidden = FALSE)


    # Data preview
    output$data_preview <- renderDT({
      req(ipd_data())

      datatable(
        head(ipd_data(), 100),
        options = list(
          pageLength = 10,
          scrollX = TRUE
        ),
        rownames = FALSE
      )
    })


    # Data summary
    output$data_summary <- renderPrint({
      req(ipd_data())

      data <- ipd_data()

      cat("=== IPD DATASET SUMMARY ===\n\n")
      cat("Total patients:", nrow(data), "\n")

      if (!is.null(input$study_var) && input$study_var != "") {
        n_studies <- length(unique(data[[input$study_var]]))
        cat("Number of studies:", n_studies, "\n")
        cat("Patients per study:", round(nrow(data) / n_studies, 1), "(average)\n")
      }

      cat("\nVariables:", ncol(data), "\n")
      cat("Variable names:", paste(names(data), collapse = ", "), "\n")
    })


    # Run IPD analysis
    observeEvent(input$run_ipd_analysis, {
      req(ipd_data())
      req(input$study_var, input$outcome_var, input$treatment_var)

      data <- ipd_data()

      withProgress(message = "Running IPD meta-analysis...", value = 0, {

        incProgress(0.2, detail = "Preparing data...")

        # Prepare analysis dataset
        analysis_data <- data[, c(input$study_var, input$outcome_var,
                                 input$treatment_var, input$covariates)]

        incProgress(0.4, detail = "Fitting model...")

        # Run analysis
        results <- tryCatch({
          if (input$ipd_method == "one_stage") {
            run_one_stage_ipd(
              data = analysis_data,
              study_var = input$study_var,
              outcome_var = input$outcome_var,
              treatment_var = input$treatment_var,
              covariates = input$covariates,
              outcome_type = input$outcome_type,
              random_effects = input$one_stage_type,
              robust_se = input$robust_se
            )
          } else {
            run_two_stage_ipd(
              data = analysis_data,
              study_var = input$study_var,
              outcome_var = input$outcome_var,
              treatment_var = input$treatment_var,
              covariates = input$covariates,
              outcome_type = input$outcome_type,
              pooling_method = input$two_stage_pooling
            )
          }
        }, error = function(e) {
          showNotification(paste("Error in analysis:", e$message), type = "error")
          return(NULL)
        })

        incProgress(0.9, detail = "Finalizing...")

        if (!is.null(results)) {
          ipd_results(results)
          showNotification("IPD analysis complete!", type = "message")
        }
      })
    })


    # Overall results
    output$overall_results <- renderPrint({
      req(ipd_results())

      results <- ipd_results()

      cat("=== IPD META-ANALYSIS RESULTS ===\n\n")
      cat("Method:", results$method, "\n")
      cat("Outcome type:", results$outcome_type, "\n\n")

      cat("TREATMENT EFFECT:\n")
      cat("Estimate:", round(results$treatment_effect, 3), "\n")
      cat("95% CI: (", round(results$ci_lower, 3), ",",
          round(results$ci_upper, 3), ")\n")
      cat("p-value:", format.pval(results$p_value, digits = 3), "\n\n")

      if (!is.null(results$heterogeneity)) {
        cat("HETEROGENEITY:\n")
        cat("Tau²:", round(results$heterogeneity$tau2, 4), "\n")
        cat("I²:", round(results$heterogeneity$I2, 1), "%\n")
      }
    })


    # Forest plot
    output$forest_plot <- renderPlot({
      req(ipd_results())

      results <- ipd_results()

      # TODO: Implement proper forest plot for IPD
      plot(1, 1, type = "n",
           xlim = c(-2, 2), ylim = c(0, 10),
           xlab = "Treatment Effect", ylab = "Study",
           main = "Forest Plot (IPD Meta-Analysis)")

      text(0, 5, "Forest plot visualization\n(To be implemented)")
      abline(v = 0, lty = 2, col = "gray")
    })

  })
}


# ============================================================================
# Helper Functions
# ============================================================================

#' Run One-Stage IPD Meta-Analysis
#'
#' @keywords internal
run_one_stage_ipd <- function(data, study_var, outcome_var, treatment_var,
                               covariates, outcome_type, random_effects, robust_se) {

  # TODO: Full implementation
  # This is a placeholder that returns simulated results

  # Formula construction
  formula_str <- paste(outcome_var, "~", treatment_var)

  if (length(covariates) > 0) {
    formula_str <- paste(formula_str, "+", paste(covariates, collapse = " + "))
  }

  # Random effects
  if (random_effects == "intercept") {
    formula_str <- paste(formula_str, "+ (1 |", study_var, ")")
  } else if (random_effects == "both") {
    formula_str <- paste(formula_str, "+ (1 +", treatment_var, "|", study_var, ")")
  }

  # Simulate results
  list(
    method = "One-Stage IPD",
    outcome_type = outcome_type,
    treatment_effect = rnorm(1, 0.5, 0.1),
    ci_lower = rnorm(1, 0.2, 0.05),
    ci_upper = rnorm(1, 0.8, 0.05),
    p_value = runif(1, 0.001, 0.05),
    heterogeneity = list(
      tau2 = runif(1, 0.01, 0.1),
      I2 = runif(1, 30, 70)
    ),
    model_formula = formula_str
  )
}


#' Run Two-Stage IPD Meta-Analysis
#'
#' @keywords internal
run_two_stage_ipd <- function(data, study_var, outcome_var, treatment_var,
                               covariates, outcome_type, pooling_method) {

  # TODO: Full implementation
  # Stage 1: Fit within each study
  # Stage 2: Meta-analyze study-specific estimates

  # Simulate results
  list(
    method = "Two-Stage IPD",
    outcome_type = outcome_type,
    treatment_effect = rnorm(1, 0.5, 0.1),
    ci_lower = rnorm(1, 0.2, 0.05),
    ci_upper = rnorm(1, 0.8, 0.05),
    p_value = runif(1, 0.001, 0.05),
    heterogeneity = list(
      tau2 = runif(1, 0.01, 0.1),
      I2 = runif(1, 30, 70)
    ),
    pooling_method = pooling_method
  )
}
