#' Component Network Meta-Analysis Shiny Module
#'
#' Interactive module for Component NMA analysis of complex interventions.
#' Allows users to decompose treatment effects into component contributions.
#'
#' Features:
#' - Define treatment components
#' - Upload study data
#' - Run additive component models
#' - Visualize component effects
#' - Predict treatment effects
#' - Analyze dismantling studies
#' - Optimal treatment design
#'
#' @name component_nma_module
NULL


#' Component NMA UI
#'
#' @param id Module namespace ID
#' @export
component_nma_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      column(12,
        box(
          title = "Component Network Meta-Analysis",
          width = 12,
          status = "primary",
          solidHeader = TRUE,
          collapsible = TRUE,

          fluidRow(
            column(4,
              h4("Component Definitions", class = "box-title"),

              textAreaInput(ns("component_definitions"),
                           "Define Treatment Components (JSON format)",
                           rows = 10,
                           value = '{\n  "Control": [],\n  "Treatment A": ["Component 1", "Component 2"],\n  "Treatment B": ["Component 1", "Component 3"]\n}',
                           placeholder = "Enter treatment component definitions..."),

              actionButton(ns("parse_components"),
                          "Parse Components",
                          icon = icon("check"),
                          class = "btn-info btn-block"),

              hr(),

              h5("Component Matrix Preview"),
              plotOutput(ns("component_matrix_preview"), height = "200px")
            ),

            column(4,
              h4("Study Data", class = "box-title"),

              fileInput(ns("upload_studies"), "Upload Studies (CSV)",
                       accept = c(".csv", ".xlsx")),

              actionButton(ns("load_example"), "Load Example Data",
                          icon = icon("file-import"), class = "btn-info btn-block"),

              hr(),

              h5("Data Summary"),
              verbatimTextOutput(ns("data_summary"))
            ),

            column(4,
              h4("Analysis Settings", class = "box-title"),

              selectInput(ns("engine"),
                         "Estimation Engine",
                         choices = c(
                           "Frequentist" = "freq",
                           "Bayesian" = "bayes"
                         ),
                         selected = "freq"),

              checkboxInput(ns("include_interactions"),
                           "Include Component Interactions",
                           value = FALSE),

              conditionalPanel(
                condition = sprintf("input['%s'] == 'bayes'", ns("engine")),
                numericInput(ns("prior_scale"),
                            "Prior Scale",
                            value = 2.5,
                            min = 0.1,
                            max = 10,
                            step = 0.1)
              ),

              hr(),

              actionButton(ns("run_cnma"),
                          "Run Component NMA",
                          icon = icon("play"),
                          class = "btn-success btn-lg btn-block"),

              hr(),

              h5("Analysis Status"),
              verbatimTextOutput(ns("analysis_status"))
            )
          )
        )
      )
    ),

    # Results tabs
    fluidRow(
      column(12,
        tabBox(
          width = 12,
          id = ns("results_tabs"),

          # Component Effects tab
          tabPanel(
            "Component Effects",
            icon = icon("puzzle-piece"),
            fluidRow(
              column(6,
                h4("Forest Plot: Component Effects"),
                plotOutput(ns("forest_plot"), height = "500px")
              ),
              column(6,
                h4("Component Effects Table"),
                DTOutput(ns("effects_table")),
                hr(),
                h5("Model Summary"),
                verbatimTextOutput(ns("model_summary"))
              )
            )
          ),

          # Component Contributions tab
          tabPanel(
            "Contributions",
            icon = icon("chart-bar"),
            fluidRow(
              column(6,
                h4("Component Contributions"),
                plotOutput(ns("contributions_plot"), height = "500px"),
                hr(),
                p("Contribution = Component Effect × Prevalence in Treatments")
              ),
              column(6,
                h4("Contributions Table"),
                DTOutput(ns("contributions_table")),
                hr(),
                h5("Ranking Interpretation"),
                verbatimTextOutput(ns("ranking_interpretation"))
              )
            )
          ),

          # Interactions tab
          tabPanel(
            "Interactions",
            icon = icon("project-diagram"),
            conditionalPanel(
              condition = sprintf("input['%s'] == true", ns("include_interactions")),
              fluidRow(
                column(12,
                  h4("Component Interaction Effects"),
                  DTOutput(ns("interactions_table"))
                )
              ),
              hr(),
              fluidRow(
                column(12,
                  h4("Interaction Network"),
                  plotOutput(ns("interaction_network"), height = "600px")
                )
              )
            ),
            conditionalPanel(
              condition = sprintf("input['%s'] == false", ns("include_interactions")),
              h4("Component Interactions Not Included"),
              p("Enable 'Include Component Interactions' to fit interaction model.")
            )
          ),

          # Treatment Prediction tab
          tabPanel(
            "Predict Treatment",
            icon = icon("magic"),
            fluidRow(
              column(6,
                h4("Select Components for Treatment"),
                uiOutput(ns("component_checkboxes")),
                hr(),
                actionButton(ns("predict_treatment"),
                            "Predict Treatment Effect",
                            icon = icon("calculator"),
                            class = "btn-primary btn-block")
              ),
              column(6,
                h4("Predicted Effect"),
                verbatimTextOutput(ns("predicted_effect")),
                hr(),
                plotOutput(ns("predicted_effect_plot"), height = "300px")
              )
            )
          ),

          # Dismantling Analysis tab
          tabPanel(
            "Dismantling",
            icon = icon("scissors"),
            fluidRow(
              column(6,
                h4("Dismantling Analysis Setup"),
                selectInput(ns("full_treatment"),
                           "Full Treatment",
                           choices = NULL),
                selectInput(ns("reduced_treatment"),
                           "Reduced Treatment",
                           choices = NULL),
                hr(),
                actionButton(ns("run_dismantling"),
                            "Analyze Dismantling",
                            icon = icon("cut"),
                            class = "btn-warning btn-block")
              ),
              column(6,
                h4("Dismantling Results"),
                verbatimTextOutput(ns("dismantling_results")),
                hr(),
                h5("Removed Components"),
                verbatimTextOutput(ns("removed_components"))
              )
            )
          ),

          # Optimal Design tab
          tabPanel(
            "Optimal Design",
            icon = icon("trophy"),
            fluidRow(
              column(6,
                h4("Optimization Constraints"),
                numericInput(ns("max_components"),
                            "Maximum Number of Components",
                            value = NULL,
                            min = 1,
                            max = 10),
                checkboxInput(ns("use_budget"),
                             "Apply Budget Constraint",
                             value = FALSE),
                conditionalPanel(
                  condition = sprintf("input['%s'] == true", ns("use_budget")),
                  numericInput(ns("budget"),
                              "Budget",
                              value = 1000,
                              min = 0),
                  textAreaInput(ns("component_costs"),
                               "Component Costs (JSON)",
                               value = '{"Component 1": 100, "Component 2": 200}',
                               rows = 5)
                ),
                hr(),
                actionButton(ns("find_optimal"),
                            "Find Optimal Treatment",
                            icon = icon("search"),
                            class = "btn-success btn-block")
              ),
              column(6,
                h4("Optimal Treatment Design"),
                verbatimTextOutput(ns("optimal_design")),
                hr(),
                plotOutput(ns("optimal_components_plot"), height = "400px")
              )
            )
          ),

          # Component Matrix tab
          tabPanel(
            "Component Matrix",
            icon = icon("table"),
            fluidRow(
              column(12,
                h4("Component × Treatment Matrix"),
                plotOutput(ns("component_matrix_heatmap"), height = "600px")
              )
            ),
            hr(),
            fluidRow(
              column(12,
                h4("Matrix Table"),
                DTOutput(ns("component_matrix_table"))
              )
            )
          ),

          # Diagnostics tab
          tabPanel(
            "Diagnostics",
            icon = icon("stethoscope"),
            fluidRow(
              column(6,
                h4("Model Diagnostics"),
                verbatimTextOutput(ns("diagnostics_text"))
              ),
              column(6,
                h4("Heterogeneity"),
                plotOutput(ns("heterogeneity_plot"), height = "300px")
              )
            ),
            hr(),
            fluidRow(
              column(12,
                h4("Residual Plots"),
                plotOutput(ns("residual_plots"), height = "400px")
              )
            )
          )
        )
      )
    )
  )
}


#' Component NMA Server
#'
#' @param id Module namespace ID
#' @export
component_nma_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      components = NULL,
      treatments = NULL,
      component_matrix = NULL,
      study_data = NULL,
      results = NULL,
      cnma_object = NULL
    )

    # Parse component definitions
    observeEvent(input$parse_components, {
      tryCatch({
        # Parse JSON
        component_defs <- jsonlite::fromJSON(input$component_definitions)

        # Validate
        if (!is.list(component_defs)) {
          stop("Component definitions must be a JSON object")
        }

        # Create component matrix using R implementation
        source("R/component_nma.R", local = TRUE)

        comp_matrix <- create_component_matrix(component_defs)

        rv$component_matrix <- comp_matrix
        rv$components <- rownames(comp_matrix)
        rv$treatments <- colnames(comp_matrix)

        showNotification(
          sprintf("Parsed %d components and %d treatments",
                  length(rv$components), length(rv$treatments)),
          type = "success"
        )

      }, error = function(e) {
        showNotification(
          paste("Error parsing components:", e$message),
          type = "error"
        )
      })
    })

    # Component matrix preview
    output$component_matrix_preview <- renderPlot({
      req(rv$component_matrix)

      par(mar = c(4, 8, 2, 1))
      image(t(rv$component_matrix),
            col = c("white", "steelblue"),
            xlab = "", ylab = "",
            main = "Component Matrix",
            axes = FALSE)

      axis(1, at = seq(0, 1, length.out = nrow(rv$component_matrix)),
           labels = rv$components, las = 2, cex.axis = 0.8)
      axis(2, at = seq(0, 1, length.out = ncol(rv$component_matrix)),
           labels = rv$treatments, las = 1, cex.axis = 0.8)

      box()
    })

    # Load example data
    observeEvent(input$load_example, {
      showNotification("Loading example data...", type = "info")

      # Example: Smoking cessation
      component_defs <- list(
        "Control" = character(),
        "Self-help" = c("Written materials"),
        "Brief advice" = c("Counseling"),
        "Individual counseling" = c("Counseling", "Individual sessions"),
        "Group therapy" = c("Counseling", "Group sessions"),
        "NRT" = c("Pharmacotherapy"),
        "Counseling + NRT" = c("Counseling", "Pharmacotherapy"),
        "Group + NRT" = c("Counseling", "Group sessions", "Pharmacotherapy")
      )

      source("R/component_nma.R", local = TRUE)

      comp_matrix <- create_component_matrix(component_defs)

      rv$component_matrix <- comp_matrix
      rv$components <- rownames(comp_matrix)
      rv$treatments <- colnames(comp_matrix)

      # Generate example studies
      set.seed(123)
      studies <- data.frame()

      active_treatments <- setdiff(rv$treatments, "Control")

      study_id <- 1
      for (trt in active_treatments) {
        n_studies <- sample(3:5, 1)

        for (i in 1:n_studies) {
          # Simulate effect
          n_comp <- sum(comp_matrix[, trt])
          effect <- 0.3 * n_comp + rnorm(1, 0, 0.2)
          se <- runif(1, 0.15, 0.35)

          studies <- rbind(studies, data.frame(
            study_id = paste0("Study", study_id),
            treatment = trt,
            comparison = "Control",
            effect = effect,
            se = se,
            n = sample(100:500, 1),
            stringsAsFactors = FALSE
          ))

          study_id <- study_id + 1
        }
      }

      rv$study_data <- studies

      updateTextAreaInput(session, "component_definitions",
                         value = jsonlite::toJSON(component_defs, pretty = TRUE))

      showNotification("Example data loaded!", type = "success")
    })

    # Upload studies
    observeEvent(input$upload_studies, {
      req(input$upload_studies)

      tryCatch({
        if (grepl("\\.csv$", input$upload_studies$name)) {
          rv$study_data <- read.csv(input$upload_studies$datapath)
        } else if (grepl("\\.xlsx$", input$upload_studies$name)) {
          rv$study_data <- readxl::read_excel(input$upload_studies$datapath)
        }
        showNotification("Study data uploaded!", type = "success")
      }, error = function(e) {
        showNotification(paste("Error loading data:", e$message), type = "error")
      })
    })

    # Data summary
    output$data_summary <- renderPrint({
      req(rv$study_data)

      cat("STUDY DATA SUMMARY\n")
      cat("══════════════════\n")
      cat(sprintf("Number of studies: %d\n", nrow(rv$study_data)))
      cat(sprintf("Treatments: %d\n", length(unique(rv$study_data$treatment))))
      cat(sprintf("Comparisons: %s\n",
                  paste(unique(rv$study_data$comparison), collapse = ", ")))
      cat("\n")
      cat("Effect sizes:\n")
      cat(sprintf("  Range: [%.3f, %.3f]\n",
                  min(rv$study_data$effect), max(rv$study_data$effect)))
      cat(sprintf("  Mean: %.3f\n", mean(rv$study_data$effect)))
    })

    # Run Component NMA
    observeEvent(input$run_cnma, {
      req(rv$component_matrix, rv$study_data)

      showNotification("Running Component NMA...", type = "info", duration = NULL, id = "cnma_analysis")

      tryCatch({
        source("R/component_nma.R", local = TRUE)

        # Create ComponentNMA object
        cnma_obj <- ComponentNMA$new(
          data = rv$study_data,
          component_matrix = rv$component_matrix
        )

        # Fit model
        results <- cnma_obj$fit_additive(
          engine = input$engine,
          interactions = input$include_interactions,
          prior_scale = if (input$engine == "bayes") input$prior_scale else 2.5
        )

        rv$results <- results
        rv$cnma_object <- cnma_obj

        removeNotification(id = "cnma_analysis")
        showNotification("Component NMA completed!", type = "success")

      }, error = function(e) {
        removeNotification(id = "cnma_analysis")
        showNotification(paste("Error:", e$message), type = "error", duration = 10)
      })
    })

    # Analysis status
    output$analysis_status <- renderPrint({
      if (!is.null(rv$results)) {
        cat("✓ Analysis complete\n")
        cat(sprintf("Components: %d\n", length(rv$components)))
        cat(sprintf("τ: %.3f\n", rv$results$tau))
      } else {
        cat("ℹ No analysis run yet\n")
      }
    })

    # Forest plot
    output$forest_plot <- renderPlot({
      req(rv$results)

      comp_eff <- rv$results$component_effects

      y_pos <- nrow(comp_eff):1

      par(mar = c(5, 10, 4, 2))
      plot(comp_eff$mean, y_pos,
           xlim = range(c(comp_eff$lower_95, comp_eff$upper_95)),
           ylim = c(0.5, nrow(comp_eff) + 0.5),
           pch = 18, cex = 2,
           col = ifelse(comp_eff$lower_95 > 0, "green3",
                       ifelse(comp_eff$upper_95 < 0, "red", "gray50")),
           xlab = "Component Effect",
           ylab = "",
           yaxt = "n",
           main = "Component Effects (Forest Plot)")

      # Add CIs
      segments(comp_eff$lower_95, y_pos,
               comp_eff$upper_95, y_pos, lwd = 2)

      # Add labels
      axis(2, at = y_pos, labels = comp_eff$component, las = 1)

      # Null line
      abline(v = 0, lty = 2, col = "red")

      # Legend
      legend("topright",
             legend = c("Beneficial", "Harmful", "Not significant"),
             col = c("green3", "red", "gray50"),
             pch = 18,
             bty = "n")
    })

    # Effects table
    output$effects_table <- renderDT({
      req(rv$results)

      datatable(rv$results$component_effects,
                options = list(pageLength = 10, dom = 't'),
                rownames = FALSE) %>%
        formatRound(c("mean", "sd", "lower_95", "upper_95", "z", "p"), 3)
    })

    # Model summary
    output$model_summary <- renderPrint({
      req(rv$results)

      cat("MODEL SUMMARY\n")
      cat("═════════════\n")
      cat(sprintf("Model: %s\n", rv$results$model))
      cat(sprintf("τ (heterogeneity): %.3f\n", rv$results$tau))
      cat(sprintf("Components: %d\n", length(rv$components)))

      # Count significant
      sig_count <- sum(rv$results$component_effects$p < 0.05)
      cat(sprintf("\nSignificant components: %d/%d\n",
                  sig_count, length(rv$components)))
    })

    # Contributions plot
    output$contributions_plot <- renderPlot({
      req(rv$results)

      contrib <- rv$results$contributions

      par(mar = c(5, 10, 4, 2))
      barplot(contrib$contribution,
              names.arg = contrib$component,
              horiz = TRUE,
              las = 1,
              col = ifelse(contrib$contribution > 0, "steelblue", "coral"),
              xlab = "Contribution to Treatment Effects",
              main = "Component Contributions (Effect × Prevalence)")

      abline(v = 0, lty = 2)
    })

    # Contributions table
    output$contributions_table <- renderDT({
      req(rv$results)

      datatable(rv$results$contributions,
                options = list(pageLength = 10, dom = 't'),
                rownames = FALSE) %>%
        formatRound(c("effect", "prevalence", "contribution", "importance"), 3)
    })

    # Ranking interpretation
    output$ranking_interpretation <- renderPrint({
      req(rv$results)

      contrib <- rv$results$contributions

      cat("COMPONENT RANKING\n")
      cat("═════════════════\n\n")

      cat("Top 3 contributors:\n")
      for (i in 1:min(3, nrow(contrib))) {
        cat(sprintf("%d. %s (contribution: %.3f)\n",
                    i, contrib$component[i], contrib$contribution[i]))
      }

      cat("\nInterpretation:\n")
      cat("Higher contribution → More impact on treatment effects\n")
      cat("Contribution = Effect size × Prevalence in treatments\n")
    })

    # Component matrix heatmap
    output$component_matrix_heatmap <- renderPlot({
      req(rv$component_matrix)

      par(mar = c(8, 8, 4, 2))
      image(t(rv$component_matrix),
            col = c("white", "steelblue"),
            xlab = "", ylab = "",
            main = "Component × Treatment Matrix",
            axes = FALSE)

      axis(1, at = seq(0, 1, length.out = nrow(rv$component_matrix)),
           labels = rv$components, las = 2)
      axis(2, at = seq(0, 1, length.out = ncol(rv$component_matrix)),
           labels = rv$treatments, las = 1)

      # Add grid
      abline(h = seq(-0.5/(ncol(rv$component_matrix)-1),
                     1 + 0.5/(ncol(rv$component_matrix)-1),
                     length.out = ncol(rv$component_matrix) + 1),
             col = "gray80")
      abline(v = seq(-0.5/(nrow(rv$component_matrix)-1),
                     1 + 0.5/(nrow(rv$component_matrix)-1),
                     length.out = nrow(rv$component_matrix) + 1),
             col = "gray80")

      box()
    })

    # Component matrix table
    output$component_matrix_table <- renderDT({
      req(rv$component_matrix)

      df <- as.data.frame(rv$component_matrix)
      df$Component <- rownames(rv$component_matrix)
      df <- df[, c("Component", colnames(rv$component_matrix))]

      datatable(df,
                options = list(pageLength = 20, dom = 't'),
                rownames = FALSE)
    })

    # Model diagnostics
    output$diagnostics_text <- renderPrint({
      req(rv$results)

      cat("MODEL DIAGNOSTICS\n")
      cat("═════════════════\n\n")

      cat(sprintf("Heterogeneity (τ): %.3f\n", rv$results$tau))

      cat("\nModel assumptions:\n")
      cat("✓ Additive component effects\n")
      if (input$include_interactions) {
        cat("✓ Pairwise component interactions\n")
      }
      cat("✓ Random effects for studies\n")

      cat("\nWarnings:\n")
      if (rv$results$tau > 0.5) {
        cat("⚠ High heterogeneity detected\n")
      } else {
        cat("✓ No major issues detected\n")
      }
    })

    # Heterogeneity plot
    output$heterogeneity_plot <- renderPlot({
      req(rv$results)

      tau <- rv$results$tau

      par(mar = c(4, 4, 3, 2))
      barplot(tau, ylim = c(0, max(1, tau * 1.2)),
              main = "Between-Study Heterogeneity (τ)",
              ylab = "τ",
              col = ifelse(tau < 0.3, "green3",
                          ifelse(tau < 0.5, "orange", "red")))

      abline(h = c(0.3, 0.5), lty = 2, col = c("orange", "red"))
      text(1, tau + 0.05, sprintf("τ = %.3f", tau), cex = 1.2)
    })

  })
}
