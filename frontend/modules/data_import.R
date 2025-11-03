# Data Import Module
# Handles CSV/Excel uploads, validation, and data preview

library(shiny)
library(DT)
library(readxl)

# UI
data_import_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(4, 8),

      # Left panel: Upload and settings
      card(
        card_header("Upload Data"),
        fileInput(
          ns("file_upload"),
          "Choose CSV or Excel file",
          accept = c(".csv", ".xlsx", ".xls")
        ),

        # Example datasets section
        div(
          class = "mb-3 p-3 border rounded bg-light",
          h6(
            icon("lightbulb"),
            " Or try an example dataset",
            class = "mb-2"
          ),
          selectInput(
            ns("example_dataset"),
            "Example Dataset",
            choices = c(
              "Choose an example..." = "",
              "Binary - Mortality (RCTs of beta-blockers)" = "binary",
              "Continuous - Blood Pressure (Antihypertensives)" = "continuous",
              "Network MA - Smoking Cessation (4 treatments)" = "nma"
            ),
            width = "100%"
          ),
          actionButton(
            ns("btn_load_example"),
            "Load Example",
            icon = icon("download"),
            class = "btn-outline-primary w-100"
          ),
          tags$small(
            class = "text-muted mt-2 d-block",
            "Example datasets help you explore features quickly"
          )
        ),

        selectInput(
          ns("data_type"),
          "Data Type",
          choices = c(
            "Auto-detect" = "auto",
            "Binary (events/n)" = "binary",
            "Continuous (mean/SD)" = "continuous",
            "Time-to-event (HR)" = "tte",
            "Pre-computed (yi/sei)" = "effect_size"
          )
        ),
        selectInput(
          ns("measure"),
          "Effect Measure",
          choices = c("OR", "RR", "RD", "MD", "SMD", "HR")
        ),
        checkboxInput(ns("has_header"), "File has header row", TRUE),
        actionButton(
          ns("btn_validate"),
          "Validate Data",
          class = "btn-primary w-100 mt-3"
        ),
        actionButton(
          ns("btn_compute_yi"),
          "Compute Effect Sizes",
          class = "btn-success w-100 mt-2"
        )
      ),

      # Right panel: Preview and validation
      card(
        card_header("Data Preview"),
        navset_card_tab(
          nav_panel(
            "Data",
            DTOutput(ns("data_preview"))
          ),
          nav_panel(
            "Summary",
            verbatimTextOutput(ns("data_summary"))
          ),
          nav_panel(
            "Validation",
            uiOutput(ns("validation_results"))
          )
        )
      )
    )
  )
}

# Server
data_import_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive data storage
    uploaded_data <- reactiveVal(NULL)
    validation_result <- reactiveVal(NULL)

    # Handle file upload
    observeEvent(input$file_upload, {
      req(input$file_upload)

      tryCatch({
        ext <- tools::file_ext(input$file_upload$name)

        if (ext == "csv") {
          data <- read.csv(
            input$file_upload$datapath,
            header = input$has_header,
            stringsAsFactors = FALSE
          )
        } else if (ext %in% c("xlsx", "xls")) {
          data <- read_excel(input$file_upload$datapath)
        } else {
          stop("Unsupported file format")
        }

        uploaded_data(data)
        rv$data <- data

        showNotification(
          paste("Loaded", nrow(data), "rows,", ncol(data), "columns"),
          type = "message"
        )

      }, error = function(e) {
        showNotification(
          paste("Error loading file:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Load example dataset
    observeEvent(input$btn_load_example, {
      req(input$example_dataset)

      if (input$example_dataset == "") {
        showNotification(
          "Please select an example dataset first",
          type = "warning"
        )
        return()
      }

      tryCatch({
        # Map selection to file path
        example_file <- switch(
          input$example_dataset,
          "binary" = "data/examples/example_binary_mortality.csv",
          "continuous" = "data/examples/example_continuous_bp.csv",
          "nma" = "data/examples/example_nma_smoking.csv"
        )

        # Get full path (adjust based on working directory)
        # Try multiple potential paths
        possible_paths <- c(
          file.path("..", example_file),  # From frontend/
          file.path("../..", example_file),  # From frontend/modules/
          example_file  # Direct path
        )

        file_path <- NULL
        for (path in possible_paths) {
          if (file.exists(path)) {
            file_path <- path
            break
          }
        }

        if (is.null(file_path)) {
          stop("Example file not found. Please ensure example datasets are in data/examples/")
        }

        # Load the CSV
        data <- read.csv(file_path, stringsAsFactors = FALSE)

        uploaded_data(data)
        rv$data <- data

        # Set appropriate data type based on example
        if (input$example_dataset == "binary") {
          updateSelectInput(session, "data_type", selected = "binary")
          updateSelectInput(session, "measure", selected = "OR")
        } else if (input$example_dataset == "continuous") {
          updateSelectInput(session, "data_type", selected = "continuous")
          updateSelectInput(session, "measure", selected = "MD")
        } else if (input$example_dataset == "nma") {
          updateSelectInput(session, "data_type", selected = "effect_size")
          updateSelectInput(session, "measure", selected = "OR")
        }

        # Show success message with dataset description
        example_description <- switch(
          input$example_dataset,
          "binary" = "12 RCTs of beta-blockers for heart failure (mortality outcome)",
          "continuous" = "12 trials of antihypertensives (systolic BP reduction)",
          "nma" = "25 trials, 4 treatments for smoking cessation"
        )

        showNotification(
          div(
            tags$strong("Example dataset loaded!"),
            br(),
            example_description,
            br(),
            paste(nrow(data), "rows,", ncol(data), "columns")
          ),
          type = "message",
          duration = 8
        )

      }, error = function(e) {
        showNotification(
          paste("Error loading example:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Data preview
    output$data_preview <- renderDT({
      req(uploaded_data())

      datatable(
        uploaded_data(),
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 'Bfrtip'
        ),
        filter = "top",
        class = "compact stripe hover"
      )
    })

    # Data summary
    output$data_summary <- renderPrint({
      req(uploaded_data())

      data <- uploaded_data()

      cat("Dataset Summary\n")
      cat("===============\n\n")
      cat("Rows:", nrow(data), "\n")
      cat("Columns:", ncol(data), "\n\n")
      cat("Column Names:\n")
      cat(paste("-", names(data)), sep = "\n")
      cat("\n")

      # Check for required columns
      cat("\nRequired Column Check:\n")
      if ("study_id" %in% names(data)) {
        cat("✓ study_id found\n")
        cat("  Unique studies:", length(unique(data$study_id)), "\n")
      } else {
        cat("✗ study_id missing\n")
      }

      if ("treatment" %in% names(data)) {
        cat("✓ treatment found\n")
        cat("  Unique treatments:", length(unique(data$treatment)), "\n")
      } else {
        cat("✗ treatment missing\n")
      }

      # Data type specific checks
      data_type <- if (input$data_type == "auto") {
        detect_data_type(data)
      } else {
        input$data_type
      }

      cat("\nDetected/Selected Type:", data_type, "\n")

      # Smart recommendations based on data
      cat("\n")
      cat("═══════════════════════════════════════\n")
      cat("SMART RECOMMENDATIONS\n")
      cat("═══════════════════════════════════════\n\n")

      # Recommend data type if auto-detect
      if (input$data_type == "auto") {
        cat(sprintf("✓ Auto-detected data type: %s\n", data_type))
        if (data_type == "binary") {
          cat("  Recommended effect measure: OR or RR\n")
          cat("  Tip: Use OR for case-control, RR for cohort/RCTs\n")
        } else if (data_type == "continuous") {
          cat("  Recommended effect measure: MD or SMD\n")
          cat("  Tip: Use MD if same scale, SMD if different scales\n")
        } else if (data_type == "tte") {
          cat("  Recommended effect measure: HR\n")
          cat("  Tip: Ensure HR is on natural scale (not log-transformed)\n")
        }
      }

      # Check sample size adequacy
      if ("n" %in% names(data)) {
        median_n <- median(data$n, na.rm = TRUE)
        min_n <- min(data$n, na.rm = TRUE)
        if (median_n < 50) {
          cat("\n⚠ Small sample sizes detected (median n =", round(median_n), ")\n")
          cat("  Recommendation: Use REML for τ² estimation (more robust)\n")
        }
        if (min_n < 10) {
          cat("\n⚠ Very small sample in some studies (min n =", min_n, ")\n")
          cat("  Recommendation: Consider excluding very small studies in sensitivity analysis\n")
        }
      }

      # Check number of studies
      n_studies <- if ("study_id" %in% names(data)) {
        length(unique(data$study_id))
      } else {
        nrow(data)
      }

      if (n_studies < 5) {
        cat("\n⚠ Small number of studies (n =", n_studies, ")\n")
        cat("  Recommendation: Random-effects may be unstable\n")
        cat("  Consider: Report both fixed and random-effects\n")
      } else if (n_studies >= 10) {
        cat("\n✓ Adequate number of studies (n =", n_studies, ")\n")
        cat("  Recommendation: Random-effects model appropriate\n")
        cat("  Consider: Publication bias assessment (Egger's test, trim-and-fill)\n")
      }

      # Check for year column (for cumulative MA)
      if ("year" %in% names(data)) {
        year_range <- range(data$year, na.rm = TRUE)
        cat("\n✓ Publication years available:", year_range[1], "-", year_range[2], "\n")
        cat("  Tip: Enable 'Cumulative Meta-Analysis' to assess temporal trends\n")
      } else {
        cat("\n⭗ No 'year' column found\n")
        cat("  Tip: Add publication years to enable cumulative meta-analysis\n")
      }

      # Check for potential moderators
      potential_moderators <- names(data)[!names(data) %in%
        c("study_id", "treatment", "yi", "sei", "vi", "events", "n", "mean", "sd")]
      if (length(potential_moderators) > 0 && n_studies >= 10) {
        cat("\n✓ Potential moderators detected:", paste(head(potential_moderators, 3), collapse = ", "), "\n")
        cat("  Tip: Consider meta-regression if expecting heterogeneity\n")
      }

      cat("\n")

      # Missing data summary
      cat("Missing Data:\n")
      missing_counts <- colSums(is.na(data))
      missing_counts <- missing_counts[missing_counts > 0]
      if (length(missing_counts) > 0) {
        for (col in names(missing_counts)) {
          cat(sprintf("  %s: %d (%.1f%%)\n",
                      col,
                      missing_counts[col],
                      100 * missing_counts[col] / nrow(data)))
        }
      } else {
        cat("  No missing data\n")
      }
    })

    # Validate data
    observeEvent(input$btn_validate, {
      req(uploaded_data())

      withProgress(message = "Validating data...", {

        data_type <- if (input$data_type == "auto") {
          detect_data_type(uploaded_data())
        } else {
          input$data_type
        }

        # Call Python validation API
        result <- tryCatch({
          validate_via_api(uploaded_data(), data_type)
        }, error = function(e) {
          # Fallback to R validation if API unavailable
          validate_data_r(uploaded_data(), data_type)
        })

        validation_result(result)

        if (result$is_valid) {
          showNotification("✓ Data validation passed", type = "message")
        } else {
          n_errors <- sum(sapply(result$problems, function(p) p$severity == "error"))
          showNotification(
            paste("✗ Validation failed with", n_errors, "errors"),
            type = "error",
            duration = 10
          )
        }
      })
    })

    # Display validation results
    output$validation_results <- renderUI({
      req(validation_result())

      result <- validation_result()

      # Calculate data quality score
      data <- uploaded_data()
      quality_score <- 100

      # Deduct points for issues
      quality_score <- quality_score - (result$summary$errors * 15)
      quality_score <- quality_score - (result$summary$warnings * 5)
      quality_score <- max(0, quality_score)  # Don't go below 0

      # Add quality indicators
      quality_indicators <- list()

      if ("year" %in% names(data)) {
        quality_indicators <- c(quality_indicators, "Publication years available")
      }

      if ("n" %in% names(data)) {
        median_n <- median(data$n, na.rm = TRUE)
        if (median_n >= 50) {
          quality_indicators <- c(quality_indicators, "Adequate sample sizes")
        }
      }

      n_studies <- if ("study_id" %in% names(data)) {
        length(unique(data$study_id))
      } else {
        nrow(data)
      }

      if (n_studies >= 5) {
        quality_indicators <- c(quality_indicators, "Sufficient number of studies")
      }

      # Check missing data
      missing_pct <- mean(is.na(data)) * 100
      if (missing_pct < 5) {
        quality_indicators <- c(quality_indicators, "Minimal missing data")
      }

      # Determine quality badge color
      badge_color <- if (quality_score >= 85) {
        "success"
      } else if (quality_score >= 70) {
        "warning"
      } else {
        "danger"
      }

      if (result$is_valid) {
        div(
          class = "alert alert-success",
          icon("check-circle"),
          " Data validation passed!",
          hr(),
          div(
            class = "d-flex justify-content-between align-items-center mb-3",
            h5(class = "mb-0", "Data Quality Score:"),
            tags$span(
              class = paste0("badge bg-", badge_color, " fs-4"),
              paste0(quality_score, "/100")
            )
          ),
          if (length(quality_indicators) > 0) {
            div(
              h6("Quality Indicators:"),
              tags$ul(
                class = "mb-3",
                lapply(quality_indicators, function(ind) {
                  tags$li(icon("check"), " ", ind)
                })
              )
            )
          },
          hr(),
          h6("Summary:"),
          tags$ul(
            tags$li(paste("Rows:", nrow(uploaded_data()))),
            tags$li(paste("Studies:", length(unique(uploaded_data()$study_id)))),
            tags$li(paste("Warnings:", result$summary$warnings)),
            tags$li(paste("Info messages:", result$summary$info))
          ),
          if (result$summary$warnings > 0 || result$summary$info > 0) {
            div(
              hr(),
              h6("Issues:"),
              tagList(
                lapply(result$problems, function(p) {
                  if (p$severity %in% c("warning", "info")) {
                    class_name <- if (p$severity == "warning") "alert-warning" else "alert-info"
                    div(
                      class = paste("alert", class_name, "py-2 px-3 mb-2"),
                      tags$strong(toupper(p$severity), ": "),
                      p$message,
                      if (!is.null(p$study_id)) {
                        tags$small(paste(" (Study:", p$study_id, ")"))
                      }
                    )
                  }
                })
              )
            )
          }
        )
      } else {
        div(
          div(
            class = "alert alert-danger",
            icon("exclamation-triangle"),
            sprintf(" %d errors, %d warnings",
                    result$summary$errors,
                    result$summary$warnings)
          ),
          hr(),
          h5("Problems:"),
          tagList(
            lapply(result$problems, function(p) {
              class_name <- switch(p$severity,
                                   "error" = "alert-danger",
                                   "warning" = "alert-warning",
                                   "info" = "alert-info")
              div(
                class = paste("alert", class_name, "py-2 px-3 mb-2"),
                tags$strong(p$severity, ": "),
                p$message,
                if (!is.null(p$study_id)) {
                  tags$small(paste(" (Study:", p$study_id, ")"))
                }
              )
            })
          )
        )
      }
    })

    # Compute effect sizes
    observeEvent(input$btn_compute_yi, {
      req(uploaded_data())

      withProgress(message = "Computing effect sizes...", {

        tryCatch({
          # Call Python API to compute yi/sei
          result <- compute_yi_via_api(uploaded_data(), input$measure)

          if (!is.null(result$data)) {
            uploaded_data(result$data)
            rv$data <- result$data

            showNotification(
              paste("✓ Effect sizes computed for", result$n_observations, "observations"),
              type = "message"
            )
          }

        }, error = function(e) {
          showNotification(
            paste("Error computing effect sizes:", e$message),
            type = "error",
            duration = 10
          )
        })
      })
    })

    # Return reactive data
    return(reactive({
      list(
        data = uploaded_data(),
        validation = validation_result()
      )
    }))
  })
}

# Helper: Detect data type
detect_data_type <- function(data) {
  cols <- tolower(names(data))

  if (any(c("events", "n") %in% cols)) {
    return("binary")
  } else if (any(c("mean", "sd") %in% cols)) {
    return("continuous")
  } else if (any(c("hr", "hazard") %in% cols)) {
    return("tte")
  } else if (all(c("yi", "sei") %in% cols)) {
    return("effect_size")
  } else {
    return("unknown")
  }
}

# Helper: R-based validation (fallback)
validate_data_r <- function(data, data_type) {
  problems <- list()

  # Check required columns
  if (!"study_id" %in% names(data)) {
    problems[[length(problems) + 1]] <- list(
      severity = "error",
      field = "study_id",
      message = "Missing required column: study_id"
    )
  }

  if (!"treatment" %in% names(data)) {
    problems[[length(problems) + 1]] <- list(
      severity = "error",
      field = "treatment",
      message = "Missing required column: treatment"
    )
  }

  # Data type specific validation
  if (data_type == "binary") {
    if (!all(c("yi", "sei") %in% names(data))) {
      if (!all(c("events", "n") %in% names(data))) {
        problems[[length(problems) + 1]] <- list(
          severity = "error",
          field = "data",
          message = "Binary data requires (events, n) or (yi, sei)"
        )
      }
    }
  }

  is_valid <- sum(sapply(problems, function(p) p$severity == "error")) == 0

  list(
    is_valid = is_valid,
    problems = problems,
    summary = list(
      errors = sum(sapply(problems, function(p) p$severity == "error")),
      warnings = sum(sapply(problems, function(p) p$severity == "warning")),
      info = sum(sapply(problems, function(p) p$severity == "info"))
    )
  )
}
