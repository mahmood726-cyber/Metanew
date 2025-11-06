# Data Import Module
# Handles CSV/Excel uploads, validation, and data preview
# Dependencies: shiny, DT, readxl (loaded in app.R)
# Utilities: data_validation.R (sourced in app.R)

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
        ),
        hr(),
        tags$div(
          class = "text-center",
          tags$small(class = "text-muted", "Or try a demo:"),
          actionButton(
            ns("btn_load_demo"),
            "⚡ Load Demo Data",
            class = "btn-info w-100 mt-2",
            icon = icon("bolt")
          )
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
    preprocessing_report <- reactiveVal(NULL)  # Store preprocessing report

    # Handle file upload WITH INTELLIGENT PREPROCESSING
    observeEvent(input$file_upload, {
      req(input$file_upload)

      # File size validation (max 50MB)
      file_size_mb <- file.info(input$file_upload$datapath)$size / (1024^2)

      if (file_size_mb > 50) {
        showNotification(
          paste0("✗ File too large: ", round(file_size_mb, 1), " MB. Maximum size is 50 MB."),
          type = "error",
          duration = 10
        )
        return()
      }

      withProgress(message = "Loading and preprocessing data...", {

        tryCatch({
          setProgress(0.1, detail = "Validating file...")

          # Security: Check file extension
          ext <- tools::file_ext(input$file_upload$name)

          if (!ext %in% c("csv", "xlsx", "xls")) {
            stop("Invalid file type. Only CSV and Excel files are allowed.")
          }

          setProgress(0.2, detail = "Reading file...")

          if (ext == "csv") {
            raw_data <- read.csv(
              input$file_upload$datapath,
              header = input$has_header,
              stringsAsFactors = FALSE,
              na.strings = c("", " ", "NA", "N/A", "na", "n/a", "NULL", "null", "-", "--", ".")
            )
          } else if (ext %in% c("xlsx", "xls")) {
            raw_data <- read_excel(input$file_upload$datapath)
          } else {
            stop("Unsupported file format")
          }

          setProgress(0.4, detail = "Cleaning and validating...")

          # Determine analysis type
          analysis_type <- if (input$data_type == "auto") {
            detect_data_type(raw_data)
          } else {
            input$data_type
          }

          # Run comprehensive preprocessing
          preprocess_result <- preprocess_data(
            df = raw_data,
            analysis_type = "pairwise",  # Default - covers most cases
            expected_columns = NULL
          )

          setProgress(0.7, detail = "Finalizing...")

          # Store results
          preprocessing_report(preprocess_result$report)

          if (preprocess_result$success) {
            # Use cleaned data
            uploaded_data(preprocess_result$data)
            rv$data <- preprocess_result$data

            # Generate user-friendly report
            report_text <- generate_report_text(preprocess_result)

            showNotification(
              paste("✓ Data loaded successfully!",
                    nrow(preprocess_result$data), "studies,",
                    ncol(preprocess_result$data), "variables"),
              type = "message",
              duration = 8
            )

            if (preprocess_result$has_warnings) {
              showNotification(
                paste("⚠", length(preprocess_result$report$warnings), "warnings - check Validation tab"),
                type = "warning",
                duration = 10
              )
            }

            # Print report to console for debugging
            cat("\n")
            cat(report_text)
            cat("\n")

          } else {
            # Validation failed
            showNotification(
              paste("✗ Data validation failed:", length(preprocess_result$report$errors), "errors"),
              type = "error",
              duration = 15
            )

            # Still store the data for inspection
            uploaded_data(preprocess_result$data)

            # Generate error report
            report_text <- generate_report_text(preprocess_result)
            cat("\n")
            cat(report_text)
            cat("\n")
          }

        }, error = function(e) {
          showNotification(
            paste("Error loading file:", e$message),
            type = "error",
            duration = 15
          )
          print(e)  # Debugging
        })
      })
    })

    # Load demo data
    observeEvent(input$btn_load_demo, {
      tryCatch({
        # Generate sample meta-analysis data (from sample_data_loader.R)
        data <- generate_sample_ma_data()

        uploaded_data(data)
        rv$data <- data

        showNotification(
          "⚡ Demo data loaded! (15 cardiovascular studies)",
          type = "message",
          duration = 5
        )

      }, error = function(e) {
        showNotification(
          paste("Error loading demo data:", e$message),
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

      # Missing data summary
      cat("\nMissing Data:\n")
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

    # Display validation results - NEW COMPREHENSIVE VERSION
    output$validation_results <- renderUI({

      if (!is.null(preprocessing_report())) {
        # Use new preprocessing report
        report <- preprocessing_report()

        # Header with overall status
        status_div <- if (report$validation$valid) {
          div(
            class = "alert alert-success",
            icon("check-circle"),
            tags$strong(" Data Validation PASSED"),
            tags$p(class = "mb-0 mt-2",
                   sprintf("✓ %d studies × %d variables ready for analysis",
                          report$final_rows, report$final_cols))
          )
        } else {
          div(
            class = "alert alert-danger",
            icon("exclamation-triangle"),
            tags$strong(" Data Validation FAILED"),
            tags$p(class = "mb-0 mt-2",
                   sprintf("%d errors must be fixed before analysis",
                          length(report$errors)))
          )
        }

        # Column changes section
        column_changes <- if (!is.null(report$column_changes)) {
          changed <- report$column_changes[report$column_changes$changed, ]
          if (nrow(changed) > 0) {
            div(
              class = "card mb-3",
              div(class = "card-header bg-info text-white",
                  icon("edit"), " Column Name Corrections"),
              div(
                class = "card-body",
                tags$p(class = "text-muted",
                       "The following columns were automatically renamed to R-compatible format:"),
                tags$table(
                  class = "table table-sm",
                  tags$thead(
                    tags$tr(
                      tags$th("Original"),
                      tags$th("→"),
                      tags$th("New Name")
                    )
                  ),
                  tags$tbody(
                    lapply(1:nrow(changed), function(i) {
                      tags$tr(
                        tags$td(tags$code(changed$original[i])),
                        tags$td("→"),
                        tags$td(tags$code(class = "text-success", changed$new[i]))
                      )
                    })
                  )
                )
              )
            )
          }
        }

        # Missing data section
        missing_div <- if (report$missing_data$overall_pct > 0) {
          severity_class <- if (report$missing_data$overall_pct > 30) {
            "warning"
          } else if (report$missing_data$overall_pct > 10) {
            "info"
          } else {
            "secondary"
          }

          div(
            class = "card mb-3",
            div(class = paste("card-header bg-", severity_class, " text-white"),
                icon("database"), " Missing Data Analysis"),
            div(
              class = "card-body",
              tags$p(
                tags$strong(sprintf("Overall: %.1f%% missing",
                                   report$missing_data$overall_pct))
              ),
              if (length(report$missing_data$recommendations) > 0) {
                tags$ul(
                  lapply(report$missing_data$recommendations, function(rec) {
                    tags$li(rec)
                  })
                )
              }
            )
          )
        }

        # Errors section
        errors_div <- if (length(report$errors) > 0) {
          div(
            class = "card mb-3",
            div(class = "card-header bg-danger text-white",
                icon("times-circle"), " Errors (Must Fix)"),
            div(
              class = "card-body",
              tags$ul(
                lapply(report$errors, function(err) {
                  tags$li(class = "text-danger", err)
                })
              )
            )
          )
        }

        # Warnings section
        warnings_div <- if (length(report$warnings) > 0) {
          div(
            class = "card mb-3",
            div(class = "card-header bg-warning",
                icon("exclamation-triangle"), " Warnings"),
            div(
              class = "card-body",
              tags$ul(
                lapply(report$warnings, function(warn) {
                  tags$li(class = "text-warning", warn)
                })
              )
            )
          )
        }

        # Suggestions section
        suggestions_div <- if (length(report$suggestions) > 0) {
          div(
            class = "card mb-3",
            div(class = "card-header bg-light",
                icon("lightbulb"), " Helpful Suggestions"),
            div(
              class = "card-body",
              tags$ul(
                lapply(report$suggestions, function(sug) {
                  tags$li(class = "text-muted", sug)
                })
              )
            )
          )
        }

        # Combine all sections
        tagList(
          status_div,
          column_changes,
          missing_div,
          errors_div,
          warnings_div,
          suggestions_div
        )

      } else if (!is.null(validation_result())) {
        # Fallback to old validation system
        result <- validation_result()

        if (result$is_valid) {
          div(
            class = "alert alert-success",
            icon("check-circle"),
            " Data validation passed!",
            hr(),
            h5("Summary:"),
            tags$ul(
              tags$li(paste("Rows:", nrow(uploaded_data()))),
              tags$li(paste("Studies:", length(unique(uploaded_data()$study_id)))),
              tags$li(paste("Warnings:", result$summary$warnings))
            )
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
      } else {
        div(
          class = "alert alert-info",
          icon("info-circle"),
          " Upload data to see validation results"
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
