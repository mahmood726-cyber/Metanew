# QA Dashboard Module
# Automated quality checks and method guardrails for meta-analysis data

library(shiny)
library(DT)

# UI
qa_dashboard_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # QA Summary Card
      card(
        card_header(
          div(
            icon("shield-halved"),
            " Data Quality & Method Guardrails"
          )
        ),

        p(class = "text-muted",
          "Automated checks to ensure data quality and appropriate methodology. ",
          "Critical errors will block analysis; warnings require your attention."),

        actionButton(
          ns("btn_run_qa"),
          "Run Quality Checks",
          icon = icon("play-circle"),
          class = "btn-primary btn-lg mb-3"
        ),

        uiOutput(ns("qa_summary")),

        hr(),

        navset_card_tab(
          nav_panel(
            "Data Quality",
            icon = icon("database"),
            h5("Data Structure & Integrity Checks"),
            DTOutput(ns("data_checks_table")),
            hr(),
            h6("Failed Checks"),
            uiOutput(ns("data_failures"))
          ),

          nav_panel(
            "Statistical Validity",
            icon = icon("chart-line"),
            h5("Statistical Method Appropriateness"),
            DTOutput(ns("stats_checks_table")),
            hr(),
            h6("Recommendations"),
            uiOutput(ns("stats_recommendations"))
          ),

          nav_panel(
            "Sample Size",
            icon = icon("users"),
            h5("Sample Size Adequacy Assessment"),
            plotOutput(ns("sample_size_plot"), height = "400px"),
            hr(),
            verbatimTextOutput(ns("sample_size_summary"))
          ),

          nav_panel(
            "Outliers",
            icon = icon("exclamation-triangle"),
            h5("Potential Outliers & Influential Studies"),
            plotOutput(ns("outlier_plot"), height = "400px"),
            hr(),
            DTOutput(ns("outlier_table"))
          )
        )
      )
    )
  )
}

# Server
qa_dashboard_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    qa_results <- reactiveVal(NULL)

    # Run QA checks
    observeEvent(input$btn_run_qa, {
      req(rv$data)

      withProgress(message = "Running quality checks...", {

        tryCatch({
          data <- rv$data

          # Run comprehensive QA
          results <- run_qa_checks(data)

          qa_results(results)

          # Show summary notification
          if (results$overall_status == "pass") {
            showNotification(
              sprintf("✓ All checks passed! Quality score: %d/100", results$quality_score),
              type = "message",
              duration = 5
            )
          } else if (results$overall_status == "warning") {
            showNotification(
              sprintf("⚠ %d warnings found. Quality score: %d/100",
                      results$n_warnings, results$quality_score),
              type = "warning",
              duration = 7
            )
          } else {
            showNotification(
              sprintf("✗ %d critical errors found. Analysis blocked.",
                      results$n_errors),
              type = "error",
              duration = 10
            )
          }

        }, error = function(e) {
          showNotification(
            paste("Error running QA checks:", e$message),
            type = "error",
            duration = 10
          )
        })
      })
    })

    # QA Summary
    output$qa_summary <- renderUI({
      req(qa_results())
      results <- qa_results()

      # Determine badge color
      badge_class <- if (results$quality_score >= 85) {
        "bg-success"
      } else if (results$quality_score >= 70) {
        "bg-warning"
      } else {
        "bg-danger"
      }

      # Determine status icon
      status_icon <- if (results$overall_status == "pass") {
        icon("check-circle", class = "text-success")
      } else if (results$overall_status == "warning") {
        icon("exclamation-triangle", class = "text-warning")
      } else {
        icon("times-circle", class = "text-danger")
      }

      div(
        class = "alert alert-light border",

        # Quality Score
        div(
          class = "d-flex justify-content-between align-items-center mb-3",
          div(
            h4(class = "mb-0", status_icon, " Overall Status: ",
               tags$span(class = "text-capitalize", results$overall_status))
          ),
          tags$span(
            class = paste("badge", badge_class, "fs-3"),
            sprintf("%d/100", results$quality_score)
          )
        ),

        hr(),

        # Check counts
        div(
          class = "row",
          div(
            class = "col-md-4",
            div(
              class = "text-center p-3",
              h5(icon("check-circle", class = "text-success"), " Passed"),
              h3(results$n_passed)
            )
          ),
          div(
            class = "col-md-4",
            div(
              class = "text-center p-3",
              h5(icon("exclamation-triangle", class = "text-warning"), " Warnings"),
              h3(results$n_warnings)
            )
          ),
          div(
            class = "col-md-4",
            div(
              class = "text-center p-3",
              h5(icon("times-circle", class = "text-danger"), " Errors"),
              h3(results$n_errors)
            )
          )
        ),

        if (results$n_errors > 0) {
          div(
            class = "alert alert-danger mt-3",
            icon("ban"),
            tags$strong(" Analysis Blocked: "),
            sprintf("%d critical error(s) must be fixed before proceeding.", results$n_errors)
          )
        }
      )
    })

    # Data checks table
    output$data_checks_table <- renderDT({
      req(qa_results())
      results <- qa_results()

      display_table <- results$data_checks
      display_table$status_icon <- sapply(display_table$status, function(s) {
        switch(s,
               "pass" = "✓",
               "warning" = "⚠",
               "error" = "✗")
      })

      display_table <- display_table[, c("status_icon", "check_name", "description", "status")]
      colnames(display_table) <- c("", "Check", "Description", "Status")

      datatable(
        display_table,
        options = list(
          pageLength = 15,
          dom = 't'
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          "Status",
          backgroundColor = styleEqual(
            c("pass", "warning", "error"),
            c("#d4edda", "#fff3cd", "#f8d7da")
          )
        )
    })

    # Data failures
    output$data_failures <- renderUI({
      req(qa_results())
      results <- qa_results()

      failures <- results$data_checks[results$data_checks$status %in% c("warning", "error"), ]

      if (nrow(failures) == 0) {
        return(div(
          class = "alert alert-success",
          icon("check-circle"),
          " All data quality checks passed!"
        ))
      }

      tagList(
        lapply(1:nrow(failures), function(i) {
          check <- failures[i, ]
          class_name <- if (check$status == "error") "alert-danger" else "alert-warning"

          div(
            class = paste("alert", class_name, "py-2 px-3 mb-2"),
            tags$strong(toupper(check$status), ": ", check$check_name),
            br(),
            check$description,
            if (!is.null(check$recommendation)) {
              tagList(
                br(),
                tags$small(icon("lightbulb"), " ", tags$em(check$recommendation))
              )
            }
          )
        })
      )
    })

    # Statistical checks table
    output$stats_checks_table <- renderDT({
      req(qa_results())
      results <- qa_results()

      display_table <- results$stats_checks
      display_table$status_icon <- sapply(display_table$status, function(s) {
        switch(s,
               "pass" = "✓",
               "warning" = "⚠",
               "info" = "ℹ")
      })

      display_table <- display_table[, c("status_icon", "check_name", "value", "recommendation")]
      colnames(display_table) <- c("", "Metric", "Value", "Recommendation")

      datatable(
        display_table,
        options = list(
          pageLength = 15,
          dom = 't'
        ),
        rownames = FALSE
      )
    })

    # Statistical recommendations
    output$stats_recommendations <- renderUI({
      req(qa_results())
      results <- qa_results()

      recs <- results$stats_checks[!is.na(results$stats_checks$recommendation), ]

      if (nrow(recs) == 0) {
        return(div(
          class = "alert alert-info",
          icon("info-circle"),
          " No specific statistical recommendations."
        ))
      }

      tagList(
        lapply(1:nrow(recs), function(i) {
          rec <- recs[i, ]

          div(
            class = "alert alert-info py-2 px-3 mb-2",
            icon("lightbulb"),
            tags$strong(" ", rec$check_name, ":"),
            br(),
            rec$recommendation
          )
        })
      )
    })

    # Sample size plot
    output$sample_size_plot <- renderPlot({
      req(qa_results())
      results <- qa_results()
      data <- rv$data

      if (!"n" %in% names(data)) {
        plot.new()
        text(0.5, 0.5, "Sample size data (n) not available", cex = 1.2)
        return()
      }

      # Histogram of sample sizes
      par(mfrow = c(1, 2))

      # Histogram
      hist(data$n,
           breaks = 20,
           col = "steelblue",
           border = "white",
           main = "Distribution of Sample Sizes",
           xlab = "Sample Size (n)",
           ylab = "Frequency")
      abline(v = median(data$n, na.rm = TRUE), col = "red", lwd = 2, lty = 2)
      legend("topright", legend = paste("Median =", round(median(data$n, na.rm = TRUE))),
             col = "red", lty = 2, lwd = 2)

      # Box plot
      boxplot(data$n,
              col = "lightblue",
              main = "Sample Size Distribution",
              ylab = "Sample Size (n)",
              horizontal = FALSE)
      abline(h = 50, col = "green", lty = 2, lwd = 2)
      text(1.3, 50, "Adequate (n≥50)", col = "green", cex = 0.8)
    })

    # Sample size summary
    output$sample_size_summary <- renderPrint({
      req(qa_results())
      data <- rv$data

      if (!"n" %in% names(data)) {
        cat("Sample size data not available\n")
        return()
      }

      cat("Sample Size Assessment\n")
      cat("======================\n\n")
      cat(sprintf("Studies:           %d\n", nrow(data)))
      cat(sprintf("Median n:          %d\n", round(median(data$n, na.rm = TRUE))))
      cat(sprintf("Mean n:            %.1f\n", mean(data$n, na.rm = TRUE)))
      cat(sprintf("Min n:             %d\n", min(data$n, na.rm = TRUE)))
      cat(sprintf("Max n:             %d\n", max(data$n, na.rm = TRUE)))
      cat(sprintf("Studies with n<20: %d (%.1f%%)\n",
                  sum(data$n < 20, na.rm = TRUE),
                  100 * sum(data$n < 20, na.rm = TRUE) / nrow(data)))
      cat(sprintf("Studies with n≥50: %d (%.1f%%)\n",
                  sum(data$n >= 50, na.rm = TRUE),
                  100 * sum(data$n >= 50, na.rm = TRUE) / nrow(data)))
    })

    # Outlier plot
    output$outlier_plot <- renderPlot({
      req(qa_results())
      results <- qa_results()
      data <- rv$data

      if (!"yi" %in% names(data)) {
        plot.new()
        text(0.5, 0.5, "Effect size data (yi) not available\nRun meta-analysis first", cex = 1.2)
        return()
      }

      # Effect size plot with outliers highlighted
      yi <- data$yi
      sei <- data$sei

      # Calculate IQR-based outliers
      Q1 <- quantile(yi, 0.25, na.rm = TRUE)
      Q3 <- quantile(yi, 0.75, na.rm = TRUE)
      IQR <- Q3 - Q1
      lower_bound <- Q1 - 3 * IQR
      upper_bound <- Q3 + 3 * IQR

      outliers <- yi < lower_bound | yi > upper_bound

      plot(1:length(yi), yi,
           pch = ifelse(outliers, 17, 19),
           col = ifelse(outliers, "red", "steelblue"),
           cex = ifelse(outliers, 1.5, 1),
           main = "Effect Sizes with Potential Outliers",
           xlab = "Study Index",
           ylab = "Effect Size (yi)",
           ylim = range(yi, na.rm = TRUE) * 1.2)
      abline(h = median(yi, na.rm = TRUE), col = "blue", lwd = 2)
      abline(h = c(lower_bound, upper_bound), col = "red", lty = 2, lwd = 2)
      legend("topright",
             legend = c("Normal", "Potential outlier", "Median", "3×IQR bounds"),
             pch = c(19, 17, NA, NA),
             col = c("steelblue", "red", "blue", "red"),
             lty = c(NA, NA, 1, 2),
             lwd = c(NA, NA, 2, 2))
    })

    # Outlier table
    output$outlier_table <- renderDT({
      req(qa_results())
      results <- qa_results()

      if (is.null(results$outliers) || nrow(results$outliers) == 0) {
        return(datatable(data.frame(Message = "No outliers detected"), options = list(dom = 't')))
      }

      outliers <- results$outliers
      outliers$Effect_Size <- sprintf("%.3f", outliers$yi)
      outliers$SE <- sprintf("%.3f", outliers$sei)
      outliers$Deviation <- sprintf("%.2f SD", outliers$deviation_sd)

      display <- outliers[, c("study_id", "Effect_Size", "SE", "Deviation", "recommendation")]
      colnames(display) <- c("Study", "Effect Size", "SE", "Deviation", "Recommendation")

      datatable(
        display,
        options = list(
          pageLength = 10,
          dom = 'frtip'
        ),
        rownames = FALSE
      )
    })

    return(reactive({
      qa_results()
    }))
  })
}

# Helper: Run comprehensive QA checks
run_qa_checks <- function(data) {

  results <- list()
  results$data_checks <- data.frame(
    check_name = character(),
    description = character(),
    status = character(),
    recommendation = character(),
    stringsAsFactors = FALSE
  )

  results$stats_checks <- data.frame(
    check_name = character(),
    value = character(),
    status = character(),
    recommendation = character(),
    stringsAsFactors = FALSE
  )

  # Data quality checks
  add_data_check <- function(name, desc, status, rec = NA) {
    results$data_checks <<- rbind(results$data_checks,
                                   data.frame(check_name = name,
                                             description = desc,
                                             status = status,
                                             recommendation = rec,
                                             stringsAsFactors = FALSE))
  }

  # 1. Duplicate study IDs
  if ("study_id" %in% names(data)) {
    n_unique <- length(unique(data$study_id))
    n_total <- nrow(data)
    if (n_unique < n_total) {
      add_data_check("Duplicate Study IDs",
                     sprintf("%d duplicate study IDs found", n_total - n_unique),
                     "error",
                     "Each study must have a unique ID. Check for copy-paste errors.")
    } else {
      add_data_check("Duplicate Study IDs", "All study IDs are unique", "pass", NA)
    }
  }

  # 2. Missing critical data
  if ("yi" %in% names(data) && "sei" %in% names(data)) {
    n_missing <- sum(is.na(data$yi) | is.na(data$sei))
    if (n_missing > 0) {
      add_data_check("Missing Effect Sizes",
                     sprintf("%d studies missing yi or sei", n_missing),
                     "error",
                     "Effect sizes (yi) and standard errors (sei) are required for all studies.")
    } else {
      add_data_check("Missing Effect Sizes", "No missing effect sizes", "pass", NA)
    }
  }

  # 3. Negative standard errors
  if ("sei" %in% names(data)) {
    n_negative <- sum(data$sei <= 0, na.rm = TRUE)
    if (n_negative > 0) {
      add_data_check("Invalid Standard Errors",
                     sprintf("%d studies with negative or zero SE", n_negative),
                     "error",
                     "Standard errors must be positive. Check your data entry.")
    } else {
      add_data_check("Invalid Standard Errors", "All SEs are positive", "pass", NA)
    }
  }

  # 4. Extreme effect sizes
  if ("yi" %in% names(data)) {
    n_extreme <- sum(abs(data$yi) > 10, na.rm = TRUE)
    if (n_extreme > 0) {
      add_data_check("Extreme Effect Sizes",
                     sprintf("%d studies with |yi| > 10", n_extreme),
                     "warning",
                     "Very large effect sizes may indicate data entry errors. Verify these studies.")
    } else {
      add_data_check("Extreme Effect Sizes", "No extreme effect sizes", "pass", NA)
    }
  }

  # 5. Binary data consistency
  if (all(c("events", "n") %in% names(data))) {
    n_invalid <- sum(data$events > data$n, na.rm = TRUE)
    if (n_invalid > 0) {
      add_data_check("Events > N",
                     sprintf("%d studies where events exceed sample size", n_invalid),
                     "error",
                     "Events cannot exceed total sample size. Check data entry.")
    } else {
      add_data_check("Events > N", "All event counts valid", "pass", NA)
    }
  }

  # Statistical appropriateness checks
  add_stats_check <- function(name, value, status, rec = NA) {
    results$stats_checks <<- rbind(results$stats_checks,
                                    data.frame(check_name = name,
                                              value = value,
                                              status = status,
                                              recommendation = rec,
                                              stringsAsFactors = FALSE))
  }

  # 1. Number of studies
  n_studies <- nrow(data)
  if (n_studies < 5) {
    add_stats_check("Number of Studies", as.character(n_studies), "warning",
                    "Small meta-analyses (k<5) have unstable estimates. Consider reporting both fixed and random effects.")
  } else if (n_studies >= 10) {
    add_stats_check("Number of Studies", as.character(n_studies), "pass",
                    "Adequate sample size for random-effects meta-analysis. Consider publication bias assessment.")
  } else {
    add_stats_check("Number of Studies", as.character(n_studies), "pass", NA)
  }

  # 2. Sample size adequacy
  if ("n" %in% names(data)) {
    median_n <- median(data$n, na.rm = TRUE)
    if (median_n < 20) {
      add_stats_check("Median Sample Size", sprintf("%.0f", median_n), "warning",
                      "Small sample sizes may have low precision. Use REML for τ² estimation.")
    } else if (median_n >= 50) {
      add_stats_check("Median Sample Size", sprintf("%.0f", median_n), "pass", NA)
    } else {
      add_stats_check("Median Sample Size", sprintf("%.0f", median_n), "info",
                      "Moderate sample sizes. REML recommended.")
    }
  }

  # 3. Outlier detection
  if ("yi" %in% names(data) && nrow(data) >= 5) {
    yi <- data$yi[!is.na(data$yi)]
    Q1 <- quantile(yi, 0.25)
    Q3 <- quantile(yi, 0.75)
    IQR <- Q3 - Q1
    n_outliers <- sum(yi < Q1 - 3*IQR | yi > Q3 + 3*IQR)

    if (n_outliers > 0) {
      results$outliers <- data[data$yi < Q1 - 3*IQR | data$yi > Q3 + 3*IQR, ]
      results$outliers$deviation_sd <- (results$outliers$yi - median(yi)) / sd(yi)
      results$outliers$recommendation <- "Consider sensitivity analysis excluding this study"

      add_stats_check("Potential Outliers", as.character(n_outliers), "warning",
                      sprintf("%d potential outlier(s) detected. Run leave-one-out sensitivity analysis.", n_outliers))
    } else {
      results$outliers <- data.frame()
      add_stats_check("Potential Outliers", "0", "pass", NA)
    }
  }

  # Calculate overall quality score
  n_pass <- sum(results$data_checks$status == "pass")
  n_warn <- sum(results$data_checks$status == "warning")
  n_err <- sum(results$data_checks$status == "error")

  quality_score <- 100 - (n_err * 20) - (n_warn * 5)
  quality_score <- max(0, quality_score)

  overall_status <- if (n_err > 0) {
    "error"
  } else if (n_warn > 0) {
    "warning"
  } else {
    "pass"
  }

  results$quality_score <- quality_score
  results$overall_status <- overall_status
  results$n_passed <- n_pass
  results$n_warnings <- n_warn
  results$n_errors <- n_err

  return(results)
}
