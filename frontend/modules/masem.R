# Meta-Analytic Structural Equation Modeling (MASEM) Module
# Implements two-stage MASEM using metaSEM package (Cheung 2015)
# Stage 1: Pool correlation matrices across studies
# Stage 2: Fit structural equation model to pooled matrix

library(shiny)
library(metaSEM)
library(lavaan)
library(semPlot)
library(ggplot2)

# Source plot download utilities
source("utils/plot_downloads.R", local = TRUE)

# UI
masem_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(3, 9),

      # Left panel: Settings and Model Specification
      card(
        card_header("MASEM Settings"),

        navset_card_tab(
          nav_panel(
            "Data",
            fileInput(
              ns("correlation_file"),
              "Upload Correlation Matrices",
              accept = c(".csv", ".xlsx", ".rds")
            ),
            tags$small(
              class = "text-muted",
              "Format: One row per study with variables: study_id, n, cor_matrix, var_names"
            ),
            hr(),
            actionButton(
              ns("btn_load_example"),
              "Load Example Data",
              class = "btn-outline-secondary w-100",
              icon = icon("book-open")
            ),
            hr(),
            h6("Stage 1: Pooling Method"),
            selectInput(
              ns("stage1_method"),
              "Method",
              choices = c(
                "Random Effects (TSSEM)" = "REM",
                "Fixed Effects" = "FEM"
              ),
              selected = "REM"
            )
          ),

          nav_panel(
            "Model",
            h6("Stage 2: Structural Model"),
            tags$p(class = "text-muted small", "Specify your SEM model using lavaan syntax:"),

            textAreaInput(
              ns("model_syntax"),
              "Model Specification (lavaan syntax)",
              value = "# Example mediation model:\n# Direct paths\nY ~ b*M + cp*X\nM ~ a*X\n\n# Indirect effect\nindirect := a*b\ntotal := cp + (a*b)",
              rows = 12,
              width = "100%"
            ),

            tags$small(
              class = "text-muted",
              tags$ul(
                tags$li("Regression: Y ~ X"),
                tags$li("Covariance: X ~~ Y"),
                tags$li("Variance: X ~~ X"),
                tags$li("Intercept: X ~ 1"),
                tags$li("Defined parameters: indirect := a*b")
              )
            ),

            hr(),

            actionButton(
              ns("btn_run_masem"),
              "Run MASEM Analysis",
              class = "btn-primary w-100 mt-2",
              icon = icon("play")
            )
          ),

          nav_panel(
            "Help",
            h6("Two-Stage MASEM"),
            tags$p("MASEM combines meta-analysis with SEM to synthesize correlation matrices and test theoretical models."),

            h6("Stage 1: Pooling"),
            tags$ul(
              tags$li("Synthesizes correlation matrices across studies"),
              tags$li("Random effects accounts for between-study heterogeneity"),
              tags$li("Produces pooled correlation matrix + standard errors")
            ),

            h6("Stage 2: SEM Fitting"),
            tags$ul(
              tags$li("Fits structural model to pooled correlations"),
              tags$li("Tests direct and indirect effects"),
              tags$li("Provides model fit indices")
            ),

            h6("Example Use Cases:"),
            tags$ul(
              tags$li(tags$b("Mediation:"), "Does M mediate X→Y?"),
              tags$li(tags$b("Measurement:"), "CFA on pooled correlations"),
              tags$li(tags$b("Path models:"), "Test complex theoretical models"),
              tags$li(tags$b("Multi-group:"), "Compare models across subgroups")
            )
          )
        )
      ),

      # Right panel: Results
      card(
        card_header("MASEM Results"),

        navset_card_tab(
          nav_panel(
            "Stage 1: Pooled Matrix",
            h5("Pooled Correlation Matrix"),
            verbatimTextOutput(ns("stage1_summary")),
            hr(),
            h6("Heterogeneity Statistics"),
            tableOutput(ns("stage1_heterogeneity"))
          ),

          nav_panel(
            "Stage 2: SEM Results",
            h5("Model Fit Indices"),
            tableOutput(ns("fit_indices")),
            hr(),
            h5("Parameter Estimates"),
            tableOutput(ns("parameter_estimates")),
            hr(),
            h6("Defined Parameters (Indirect Effects)"),
            tableOutput(ns("defined_parameters"))
          ),

          nav_panel(
            "Path Diagram",
            plotOutput(ns("path_diagram"), height = "600px"),
            hr(),
            plot_download_ui(
              ns("diagram_download"),
              plot_name = "Path Diagram",
              default_width = 3000,
              default_height = 2400
            )
          ),

          nav_panel(
            "Model Summary",
            verbatimTextOutput(ns("full_summary"))
          ),

          nav_panel(
            "Data Preview",
            h6("Uploaded Correlation Matrices"),
            tableOutput(ns("data_preview")),
            verbatimTextOutput(ns("data_info"))
          )
        )
      )
    )
  )
}

# Server
masem_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Results storage
    stage1_result <- reactiveVal(NULL)
    stage2_result <- reactiveVal(NULL)
    masem_data <- reactiveVal(NULL)

    # Load example data
    observeEvent(input$btn_load_example, {
      # Create example data: Mediation model with 3 variables (X, M, Y)
      # Based on fictitious studies examining X → M → Y pathway

      example_data <- list(
        study_id = paste0("Study", 1:5),
        n = c(150, 200, 180, 220, 170),
        cor_matrices = list(
          # Study 1
          matrix(c(1.00, 0.35, 0.42,
                   0.35, 1.00, 0.48,
                   0.42, 0.48, 1.00), nrow = 3, byrow = TRUE),
          # Study 2
          matrix(c(1.00, 0.38, 0.45,
                   0.38, 1.00, 0.52,
                   0.45, 0.52, 1.00), nrow = 3, byrow = TRUE),
          # Study 3
          matrix(c(1.00, 0.32, 0.40,
                   0.32, 1.00, 0.46,
                   0.40, 0.46, 1.00), nrow = 3, byrow = TRUE),
          # Study 4
          matrix(c(1.00, 0.40, 0.47,
                   0.40, 1.00, 0.54,
                   0.47, 0.54, 1.00), nrow = 3, byrow = TRUE),
          # Study 5
          matrix(c(1.00, 0.36, 0.44,
                   0.36, 1.00, 0.50,
                   0.44, 0.50, 1.00), nrow = 3, byrow = TRUE)
        ),
        var_names = c("X", "M", "Y")
      )

      masem_data(example_data)

      # Update model syntax with example
      updateTextAreaInput(session, "model_syntax",
        value = "# Mediation Model: X → M → Y
# Direct paths
Y ~ b*M + cp*X
M ~ a*X

# Indirect effect (mediation)
indirect := a*b
# Total effect
total := cp + (a*b)
# Proportion mediated
prop_mediated := (a*b) / (cp + (a*b))"
      )

      showNotification("✓ Example data loaded (5 studies, 3 variables)", type = "message")
    })

    # Upload correlation matrices
    observeEvent(input$correlation_file, {
      req(input$correlation_file)

      tryCatch({
        file_ext <- tools::file_ext(input$correlation_file$name)

        if (file_ext == "rds") {
          data <- readRDS(input$correlation_file$datapath)
        } else if (file_ext %in% c("csv", "xlsx")) {
          # For CSV/Excel, expect specific format
          # This is simplified - production would need more robust parsing
          showNotification(
            "For CSV/Excel upload, please use RDS format or the example data",
            type = "warning",
            duration = 10
          )
          return()
        }

        masem_data(data)
        showNotification(
          paste("✓ Loaded", length(data$study_id), "correlation matrices"),
          type = "message"
        )

      }, error = function(e) {
        showNotification(
          paste("Error loading data:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Run MASEM analysis
    observeEvent(input$btn_run_masem, {
      req(masem_data())

      withProgress(message = "Running MASEM...", {

        tryCatch({
          data <- masem_data()

          # ===================================================================
          # STAGE 1: Pool correlation matrices
          # ===================================================================
          setProgress(0.2, detail = "Stage 1: Pooling correlation matrices...")

          # Prepare data for metaSEM (requires specific format)
          # metaSEM expects list of correlation matrices and sample sizes

          cor_list <- data$cor_matrices
          n_list <- data$n

          # Add variable names to matrices
          for (i in seq_along(cor_list)) {
            dimnames(cor_list[[i]]) <- list(data$var_names, data$var_names)
          }

          # Stage 1: Pool correlations using TSSEM or Fixed Effects
          if (input$stage1_method == "REM") {
            # Two-Stage SEM with Random Effects
            stage1 <- tssem1(
              Cov = cor_list,
              n = n_list,
              method = "REM"
            )
          } else {
            # Fixed Effects Model
            stage1 <- tssem1(
              Cov = cor_list,
              n = n_list,
              method = "FEM"
            )
          }

          stage1_result(stage1)

          # ===================================================================
          # STAGE 2: Fit structural model
          # ===================================================================
          setProgress(0.6, detail = "Stage 2: Fitting structural model...")

          # Parse lavaan syntax
          model_syntax <- input$model_syntax

          # Create A matrix (asymmetric paths) and S matrix (symmetric paths)
          # This is simplified - metaSEM requires matrices, but we can use
          # lavaan.Ramsimulation to convert syntax

          # For demonstration, fit using WLS on pooled matrix
          stage2 <- tssem2(
            stage1,
            RAM = lavaan2RAM(
              model_syntax,
              obs.variables = data$var_names
            )
          )

          stage2_result(stage2)

          showNotification("✓ MASEM analysis complete", type = "message")

        }, error = function(e) {
          showNotification(
            paste("Error running MASEM:", e$message),
            type = "error",
            duration = 15
          )
          print(e)  # For debugging
        })
      })
    })

    # Stage 1 summary output
    output$stage1_summary <- renderPrint({
      req(stage1_result())

      cat("STAGE 1: POOLED CORRELATION MATRIX\n")
      cat("==================================\n\n")

      stage1 <- stage1_result()

      cat("Pooling method:", ifelse(input$stage1_method == "REM",
                                     "Random Effects (TSSEM)",
                                     "Fixed Effects"), "\n")
      cat("Number of studies:", length(masem_data()$study_id), "\n")
      cat("Total N:", sum(masem_data()$n), "\n\n")

      cat("Pooled Correlation Matrix:\n")
      pooled <- coef(stage1, select = "fixed")

      # Extract unique correlations
      k <- length(masem_data()$var_names)
      cor_matrix <- matrix(NA, k, k)
      dimnames(cor_matrix) <- list(masem_data()$var_names, masem_data()$var_names)

      # Fill diagonal with 1s
      diag(cor_matrix) <- 1

      # Fill off-diagonal
      cor_names <- names(pooled)
      for (param in cor_names) {
        # Parse parameter name (e.g., "S21" means row 2, col 1)
        if (grepl("^S", param)) {
          row <- as.numeric(substr(param, 2, 2))
          col <- as.numeric(substr(param, 3, 3))
          cor_matrix[row, col] <- pooled[param]
          cor_matrix[col, row] <- pooled[param]  # Symmetric
        }
      }

      print(round(cor_matrix, 3))
    })

    # Stage 1 heterogeneity
    output$stage1_heterogeneity <- renderTable({
      req(stage1_result())

      stage1 <- stage1_result()

      # Extract heterogeneity statistics
      # This is a placeholder - actual extraction depends on metaSEM object structure

      data.frame(
        Statistic = c("Q", "df", "p-value", "I²"),
        Value = c(
          "See model summary",
          "--",
          "--",
          "--"
        ),
        stringsAsFactors = FALSE
      )
    }, striped = TRUE, hover = TRUE)

    # Model fit indices
    output$fit_indices <- renderTable({
      req(stage2_result())

      stage2 <- stage2_result()
      fit <- summary(stage2)

      # Extract fit indices
      data.frame(
        Index = c("Chi-square", "df", "p-value", "CFI", "TLI", "RMSEA", "SRMR"),
        Value = c(
          sprintf("%.2f", fit$stat),
          fit$df,
          sprintf("%.4f", fit$pvalue),
          sprintf("%.3f", fit$CFI),
          sprintf("%.3f", fit$TLI),
          sprintf("%.3f", fit$RMSEA),
          sprintf("%.3f", fit$SRMR)
        ),
        Interpretation = c(
          ifelse(fit$pvalue > 0.05, "Good fit", "Poor fit"),
          "--",
          "--",
          ifelse(fit$CFI > 0.95, "Excellent", ifelse(fit$CFI > 0.90, "Acceptable", "Poor")),
          ifelse(fit$TLI > 0.95, "Excellent", ifelse(fit$TLI > 0.90, "Acceptable", "Poor")),
          ifelse(fit$RMSEA < 0.05, "Excellent", ifelse(fit$RMSEA < 0.08, "Acceptable", "Poor")),
          ifelse(fit$SRMR < 0.05, "Excellent", ifelse(fit$SRMR < 0.08, "Acceptable", "Poor"))
        ),
        stringsAsFactors = FALSE
      )
    }, striped = TRUE, hover = TRUE)

    # Parameter estimates
    output$parameter_estimates <- renderTable({
      req(stage2_result())

      stage2 <- stage2_result()
      params <- summary(stage2)$parameters

      # Format parameter table
      params_df <- as.data.frame(params)
      params_df$`Estimate` <- sprintf("%.3f", params_df$Estimate)
      params_df$`Std.Error` <- sprintf("%.3f", params_df$Std.Error)
      params_df$`z value` <- sprintf("%.2f", params_df$`z value`)
      params_df$`Pr(>|z|)` <- format.pval(params_df$`Pr(>|z|)`, digits = 3)
      params_df$Sig <- ifelse(params_df$`Pr(>|z|)` < 0.001, "***",
                              ifelse(params_df$`Pr(>|z|)` < 0.01, "**",
                                    ifelse(params_df$`Pr(>|z|)` < 0.05, "*",
                                          ifelse(params_df$`Pr(>|z|)` < 0.10, ".", ""))))

      params_df
    }, striped = TRUE, hover = TRUE)

    # Defined parameters (indirect effects)
    output$defined_parameters <- renderTable({
      req(stage2_result())

      stage2 <- stage2_result()

      # Extract defined parameters (e.g., indirect effects)
      # This depends on lavaan model having := definitions

      tryCatch({
        defined <- summary(stage2)$indirect

        if (!is.null(defined) && nrow(defined) > 0) {
          defined_df <- as.data.frame(defined)
          defined_df$`Estimate` <- sprintf("%.3f", defined_df$Estimate)
          defined_df$`Std.Error` <- sprintf("%.3f", defined_df$Std.Error)
          defined_df$`z value` <- sprintf("%.2f", defined_df$`z value`)
          defined_df$`Pr(>|z|)` <- format.pval(defined_df$`Pr(>|z|)`, digits = 3)
          defined_df
        } else {
          data.frame(
            Message = "No defined parameters (use := in model syntax)",
            stringsAsFactors = FALSE
          )
        }
      }, error = function(e) {
        data.frame(
          Message = "Indirect effects not available",
          stringsAsFactors = FALSE
        )
      })
    }, striped = TRUE, hover = TRUE)

    # Path diagram
    output$path_diagram <- renderPlot({
      req(stage2_result())

      tryCatch({
        # Convert metaSEM result to lavaan object for semPlot
        stage2 <- stage2_result()

        # Create path diagram using semPlot
        semPaths(
          stage2,
          what = "est",
          layout = "tree2",
          rotation = 2,
          sizeMan = 8,
          sizeLat = 10,
          edge.label.cex = 1.2,
          curvePivot = TRUE,
          style = "lisrel",
          nodeLabels = masem_data()$var_names,
          edge.color = "black",
          title = TRUE,
          title.cex = 1.5
        )

        title(main = "Path Diagram with Standardized Estimates", line = -1)

      }, error = function(e) {
        plot.new()
        text(0.5, 0.5, paste("Error creating path diagram:\n", e$message),
             cex = 1.2, col = "red")
      })
    })

    # Path diagram download handler
    moduleServer("diagram_download", function(input_dl, output_dl, session) {
      output_dl$download <- downloadHandler(
        filename = function() {
          format <- tolower(input_dl$format)
          timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
          paste0("path_diagram_", timestamp, ".", format)
        },

        content = function(file) {
          req(stage2_result())

          format <- tolower(input_dl$format)

          # Get dimensions
          if (format == "pdf") {
            width <- input_dl$width_pdf
            height <- input_dl$height_pdf
          } else {
            width <- input_dl$width
            height <- input_dl$height
          }

          # Open graphics device
          if (format == "png") {
            png(file, width = width, height = height, res = input_dl$dpi, type = "cairo")
          } else if (format == "jpg") {
            jpeg(file, width = width, height = height, res = input_dl$dpi,
                 quality = input_dl$quality, type = "cairo")
          } else if (format == "pdf") {
            pdf(file, width = width, height = height, useDingbats = FALSE)
          } else if (format == "svg") {
            svg(file, width = width / 96, height = height / 96)
          }

          # Generate path diagram
          stage2 <- stage2_result()

          semPaths(
            stage2,
            what = "est",
            layout = "tree2",
            rotation = 2,
            sizeMan = 8,
            sizeLat = 10,
            edge.label.cex = 1.2,
            curvePivot = TRUE,
            style = "lisrel",
            nodeLabels = masem_data()$var_names,
            edge.color = "black"
          )

          title(main = "Path Diagram with Standardized Estimates")

          dev.off()
        }
      )
    })

    # Full summary
    output$full_summary <- renderPrint({
      req(stage1_result(), stage2_result())

      cat("=================================================================\n")
      cat("TWO-STAGE META-ANALYTIC STRUCTURAL EQUATION MODELING (MASEM)\n")
      cat("=================================================================\n\n")

      cat("Data:\n")
      cat("  Number of studies:", length(masem_data()$study_id), "\n")
      cat("  Total sample size:", sum(masem_data()$n), "\n")
      cat("  Variables:", paste(masem_data()$var_names, collapse = ", "), "\n\n")

      cat("=================================================================\n")
      cat("STAGE 1: POOLING CORRELATION MATRICES\n")
      cat("=================================================================\n\n")

      print(summary(stage1_result()))

      cat("\n=================================================================\n")
      cat("STAGE 2: STRUCTURAL EQUATION MODEL\n")
      cat("=================================================================\n\n")

      cat("Model specification:\n")
      cat(input$model_syntax, "\n\n")

      cat("Results:\n")
      print(summary(stage2_result()))
    })

    # Data preview
    output$data_preview <- renderTable({
      req(masem_data())

      data <- masem_data()

      # Create preview table
      preview <- data.frame(
        Study = data$study_id,
        N = data$n,
        Variables = paste(data$var_names, collapse = ", "),
        stringsAsFactors = FALSE
      )

      preview
    }, striped = TRUE, hover = TRUE)

    # Data info
    output$data_info <- renderPrint({
      req(masem_data())

      data <- masem_data()

      cat("Correlation Matrices:\n\n")

      for (i in seq_along(data$study_id)) {
        cat(data$study_id[i], "(n =", data$n[i], "):\n")
        cor_mat <- data$cor_matrices[[i]]
        dimnames(cor_mat) <- list(data$var_names, data$var_names)
        print(round(cor_mat, 3))
        cat("\n")
      }
    })

    # Return results
    return(reactive({
      list(
        stage1 = stage1_result(),
        stage2 = stage2_result(),
        data = masem_data()
      )
    }))
  })
}
