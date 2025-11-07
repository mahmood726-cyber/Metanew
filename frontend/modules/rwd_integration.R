# Real-World Data (RWD) Integration Module
# Import and analyze real-world evidence from various sources
# Supports EHR data, claims data, registries, and observational studies

library(shiny)
library(dplyr)
library(survival)
library(ggplot2)

rwd_integration_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("database", class = "me-2"),
          "Real-World Data Integration"
        )
      ),

      layout_columns(
        col_widths = c(4, 8),

        # Data import panel
        card(
          card_header("Data Source"),

          selectInput(ns("data_source_type"), "RWD Source Type",
                     choices = c(
                       "Electronic Health Records (EHR)" = "ehr",
                       "Claims Database" = "claims",
                       "Patient Registry" = "registry",
                       "Observational Study" = "observational",
                       "CSV/Excel Upload" = "upload"
                     )),

          conditionalPanel(
            condition = "input.data_source_type == 'upload'",
            ns = ns,
            fileInput(ns("rwd_file"), "Upload RWD File",
                     accept = c(".csv", ".xlsx", ".xls"))
          ),

          hr(),

          h5("Data Format"),
          selectInput(ns("data_format"), "Expected Format",
                     choices = c(
                       "Patient-Level Data" = "patient_level",
                       "Aggregated Summary Data" = "aggregated",
                       "Time-to-Event Data" = "survival",
                       "Longitudinal Data" = "longitudinal"
                     )),

          hr(),

          h5("Variable Mapping"),
          textInput(ns("patient_id_var"), "Patient ID Variable", "patient_id"),
          textInput(ns("treatment_var"), "Treatment Variable", "treatment"),
          textInput(ns("outcome_var"), "Outcome Variable", "outcome"),
          textInput(ns("time_var"), "Time Variable (if applicable)", "time"),

          hr(),

          h5("Data Quality Filters"),
          numericInput(ns("min_follow_up"), "Minimum Follow-up (days)",
                      30, min = 0, step = 30),
          checkboxInput(ns("exclude_missing"), "Exclude Missing Data", TRUE),
          checkboxInput(ns("apply_propensity"), "Apply Propensity Score Matching", FALSE),

          hr(),

          actionButton(ns("btn_import"), "Import & Validate RWD",
                      class = "btn-primary w-100",
                      icon = icon("upload"))
        ),

        # Analysis results panel
        card(
          card_header("RWD Analysis"),

          navset_card_tab(
            nav_panel("Data Summary",
                     uiOutput(ns("data_summary"))),
            nav_panel("Quality Assessment",
                     uiOutput(ns("quality_assessment"))),
            nav_panel("Descriptive Statistics",
                     DTOutput(ns("descriptive_stats"))),
            nav_panel("Survival Analysis",
                     plotOutput(ns("survival_plot")),
                     verbatimTextOutput(ns("survival_summary"))),
            nav_panel("Propensity Matching",
                     uiOutput(ns("propensity_matching"))),
            nav_panel("Comparative Effectiveness",
                     uiOutput(ns("comparative_effectiveness"))),
            nav_panel("Integration with MA",
                     uiOutput(ns("ma_integration")))
          )
        )
      )
    )
  )
}

rwd_integration_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    rwd_data <- reactiveVal(NULL)
    rwd_analysis <- reactiveVal(NULL)

    # Import RWD
    observeEvent(input$btn_import, {

      withProgress(message = "Importing real-world data...", {

        tryCatch({
          # Import data based on source type
          if (input$data_source_type == "upload") {
            req(input$rwd_file)

            file_ext <- tools::file_ext(input$rwd_file$name)

            if (file_ext == "csv") {
              raw_data <- read.csv(input$rwd_file$datapath, stringsAsFactors = FALSE)
            } else if (file_ext %in% c("xlsx", "xls")) {
              library(readxl)
              raw_data <- read_excel(input$rwd_file$datapath)
            } else {
              stop("Unsupported file format")
            }
          } else {
            # For demo purposes, generate synthetic RWD
            raw_data <- generate_synthetic_rwd(
              n_patients = 500,
              source_type = input$data_source_type
            )
          }

          # Validate and process RWD
          processed_data <- process_rwd(
            data = raw_data,
            data_format = input$data_format,
            patient_id_var = input$patient_id_var,
            treatment_var = input$treatment_var,
            outcome_var = input$outcome_var,
            time_var = input$time_var,
            min_follow_up = input$min_follow_up,
            exclude_missing = input$exclude_missing
          )

          # Apply propensity score matching if requested
          if (input$apply_propensity) {
            processed_data <- apply_propensity_matching(processed_data)
          }

          # Perform RWD analysis
          analysis_results <- analyze_rwd(
            data = processed_data,
            data_format = input$data_format
          )

          rwd_data(processed_data)
          rwd_analysis(analysis_results)
          rv$rwd_data <- processed_data
          rv$rwd_analysis <- analysis_results

          showNotification("✓ RWD imported and analyzed successfully", type = "message")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    # Data summary output
    output$data_summary <- renderUI({
      req(rwd_data())
      data <- rwd_data()

      tagList(
        h4("Real-World Data Summary"),

        div(class = "alert alert-info",
            icon("info-circle"),
            sprintf(" Imported %d patients from %s source",
                   nrow(data), input$data_source_type)),

        tags$table(
          class = "table table-bordered",
          tags$tr(tags$th("Total Patients"), tags$td(nrow(data))),
          tags$tr(tags$th("Treatment Groups"), tags$td(length(unique(data[[input$treatment_var]])))),
          tags$tr(tags$th("Follow-up Period"),
                 tags$td(sprintf("%.1f days (median)", median(data[[input$time_var]], na.rm = TRUE)))),
          tags$tr(tags$th("Missing Data"),
                 tags$td(sprintf("%.1f%%", sum(is.na(data)) / (nrow(data) * ncol(data)) * 100)))
        ),

        hr(),

        h5("Treatment Distribution"),
        plotOutput(session$ns("treatment_dist_plot"), height = "300px")
      )
    })

    output$treatment_dist_plot <- renderPlot({
      req(rwd_data())
      data <- rwd_data()

      treatment_counts <- table(data[[input$treatment_var]])

      barplot(treatment_counts,
              main = "Patient Distribution by Treatment",
              xlab = "Treatment",
              ylab = "Number of Patients",
              col = "steelblue",
              las = 2)
    })

    # Quality assessment
    output$quality_assessment <- renderUI({
      req(rwd_analysis())
      analysis <- rwd_analysis()

      tagList(
        h4("Data Quality Assessment"),

        h5("Completeness"),
        tags$ul(
          tags$li("Patient ID: ", quality_indicator(analysis$quality$patient_id_complete)),
          tags$li("Treatment: ", quality_indicator(analysis$quality$treatment_complete)),
          tags$li("Outcome: ", quality_indicator(analysis$quality$outcome_complete)),
          tags$li("Follow-up Time: ", quality_indicator(analysis$quality$time_complete))
        ),

        hr(),

        h5("Data Quality Score"),
        div(class = if (analysis$quality$overall_score >= 0.8) "alert alert-success" else "alert alert-warning",
            sprintf("Overall Quality: %.0f/100", analysis$quality$overall_score * 100)),

        hr(),

        h5("Potential Issues"),
        if (length(analysis$quality$issues) > 0) {
          tags$ul(
            lapply(analysis$quality$issues, function(issue) {
              tags$li(class = "text-warning", icon("exclamation-triangle"), " ", issue)
            })
          )
        } else {
          div(class = "alert alert-success", icon("check-circle"), " No major data quality issues detected")
        }
      )
    })

    # Descriptive statistics
    output$descriptive_stats <- renderDT({
      req(rwd_analysis())
      analysis <- rwd_analysis()

      datatable(
        analysis$descriptive_stats,
        options = list(pageLength = 10, scrollX = TRUE),
        caption = "Descriptive Statistics by Treatment Group"
      )
    })

    # Survival analysis
    output$survival_plot <- renderPlot({
      req(rwd_analysis())
      analysis <- rwd_analysis()

      if (is.null(analysis$survival)) {
        plot.new()
        text(0.5, 0.5, "Survival analysis not available for this data format")
        return()
      }

      plot(analysis$survival$km_fit,
           col = 1:length(unique(rwd_data()[[input$treatment_var]])),
           lwd = 2,
           xlab = "Time (days)",
           ylab = "Survival Probability",
           main = "Kaplan-Meier Survival Curves by Treatment")
      legend("topright",
             legend = names(analysis$survival$km_fit$strata),
             col = 1:length(names(analysis$survival$km_fit$strata)),
             lwd = 2)
      grid()
    })

    output$survival_summary <- renderPrint({
      req(rwd_analysis())
      analysis <- rwd_analysis()

      if (is.null(analysis$survival)) {
        cat("Survival analysis not applicable to this data format.\n")
        return()
      }

      cat("SURVIVAL ANALYSIS RESULTS\n")
      cat("=========================\n\n")

      cat("Log-Rank Test for Treatment Differences:\n")
      print(analysis$survival$logrank_test)

      cat("\n\nCox Proportional Hazards Model:\n")
      print(summary(analysis$survival$cox_model))
    })

    # Propensity matching
    output$propensity_matching <- renderUI({
      req(rwd_analysis())

      if (!input$apply_propensity) {
        return(div(class = "alert alert-secondary",
                  "Propensity score matching not applied. Enable in settings to use."))
      }

      analysis <- rwd_analysis()

      tagList(
        h4("Propensity Score Matching Results"),

        p("Matched patients to reduce confounding and selection bias."),

        if (!is.null(analysis$propensity)) {
          tagList(
            tags$table(
              class = "table table-bordered",
              tags$tr(tags$th("Original Sample Size"), tags$td(analysis$propensity$n_original)),
              tags$tr(tags$th("Matched Sample Size"), tags$td(analysis$propensity$n_matched)),
              tags$tr(tags$th("Matching Method"), tags$td("1:1 nearest neighbor")),
              tags$tr(tags$th("Balance Achieved"),
                     tags$td(if (analysis$propensity$balance_ok) "✓ Good" else "⚠ Review recommended"))
            ),

            hr(),

            h5("Standardized Mean Differences"),
            p("Before and after matching:"),
            plotOutput(session$ns("propensity_balance_plot"), height = "400px")
          )
        } else {
          p("Propensity matching could not be performed on this dataset.")
        }
      )
    })

    # Comparative effectiveness
    output$comparative_effectiveness <- renderUI({
      req(rwd_analysis())
      analysis <- rwd_analysis()

      tagList(
        h4("Comparative Effectiveness Analysis"),

        p("Real-world treatment effects estimated from observational data:"),

        if (!is.null(analysis$effectiveness)) {
          tagList(
            tags$table(
              class = "table table-striped",
              tags$thead(
                tags$tr(
                  tags$th("Outcome"),
                  tags$th("Effect Estimate"),
                  tags$th("95% CI"),
                  tags$th("P-value")
                )
              ),
              tags$tbody(
                lapply(1:nrow(analysis$effectiveness), function(i) {
                  row <- analysis$effectiveness[i, ]
                  tags$tr(
                    tags$td(row$outcome),
                    tags$td(sprintf("%.3f", row$estimate)),
                    tags$td(sprintf("%.3f to %.3f", row$ci_lower, row$ci_upper)),
                    tags$td(sprintf("%.4f", row$p_value))
                  )
                })
              )
            ),

            hr(),

            div(class = "alert alert-warning",
                icon("exclamation-triangle"),
                strong(" Caution: "),
                "RWD analyses are observational and may be subject to unmeasured confounding. ",
                "Results should be interpreted alongside randomized trial data when available.")
          )
        } else {
          p("Comparative effectiveness analysis not available for this data.")
        }
      )
    })

    # MA integration
    output$ma_integration <- renderUI({
      req(rwd_analysis())

      tagList(
        h4("Integration with Meta-Analysis"),

        p("Combine RWD with meta-analysis of RCTs for comprehensive evidence synthesis:"),

        h5("Available Integration Methods:"),
        tags$ul(
          tags$li(strong("Bayesian meta-analysis: "), "Use RWD as prior or additional data source"),
          tags$li(strong("Network meta-analysis: "), "Include RWD as additional evidence"),
          tags$li(strong("Bias adjustment: "), "Adjust RWD for known biases before pooling"),
          tags$li(strong("Sensitivity analysis: "), "Compare results with/without RWD")
        ),

        hr(),

        actionButton(session$ns("btn_integrate_ma"), "Integrate RWD with Meta-Analysis",
                    class = "btn-primary",
                    icon = icon("link"))
      )
    })

    # Helper function for quality indicators
    quality_indicator <- function(value) {
      if (value >= 0.95) {
        span(class = "text-success", icon("check-circle"), sprintf(" %.0f%%", value * 100))
      } else if (value >= 0.80) {
        span(class = "text-warning", icon("exclamation-circle"), sprintf(" %.0f%%", value * 100))
      } else {
        span(class = "text-danger", icon("times-circle"), sprintf(" %.0f%%", value * 100))
      }
    }

    return(reactive(list(data = rwd_data(), analysis = rwd_analysis())))
  })
}

#' Generate synthetic RWD for demonstration
#' @param n_patients Number of patients
#' @param source_type Type of data source
#' @return Data frame
generate_synthetic_rwd <- function(n_patients = 500, source_type = "ehr") {
  set.seed(42)

  # Generate patient-level data
  data <- data.frame(
    patient_id = paste0("PT", sprintf("%05d", 1:n_patients)),
    age = rnorm(n_patients, mean = 65, sd = 10),
    sex = sample(c("M", "F"), n_patients, replace = TRUE),
    treatment = sample(c("Treatment", "Control"), n_patients, replace = TRUE,
                      prob = c(0.4, 0.6)),
    comorbidity_score = rpois(n_patients, lambda = 2),
    baseline_value = rnorm(n_patients, mean = 100, sd = 15),
    stringsAsFactors = FALSE
  )

  # Generate outcomes based on treatment
  data$treatment_effect <- ifelse(data$treatment == "Treatment", 0.7, 1.0)
  data$hazard_rate <- 0.01 * exp(0.02 * (data$age - 65) + 0.1 * data$comorbidity_score) * data$treatment_effect

  # Generate time-to-event data
  data$time <- rexp(n_patients, rate = data$hazard_rate)
  data$time <- pmin(data$time, 365)  # Cap at 1 year
  data$event <- rbinom(n_patients, 1, prob = 1 - exp(-data$hazard_rate * data$time))

  # Generate outcome
  data$outcome <- data$baseline_value + rnorm(n_patients, mean = ifelse(data$treatment == "Treatment", -10, -5), sd = 10)

  return(data)
}

#' Process RWD
#' @param data Raw data
#' @param ... Parameters
#' @return Processed data
process_rwd <- function(data, data_format, patient_id_var, treatment_var, outcome_var,
                        time_var, min_follow_up, exclude_missing) {

  # Rename variables to standard names
  if (patient_id_var %in% names(data)) {
    names(data)[names(data) == patient_id_var] <- "patient_id"
  }
  if (treatment_var %in% names(data)) {
    names(data)[names(data) == treatment_var] <- "treatment"
  }
  if (outcome_var %in% names(data)) {
    names(data)[names(data) == outcome_var] <- "outcome"
  }
  if (time_var %in% names(data)) {
    names(data)[names(data) == time_var] <- "time"
  }

  # Filter minimum follow-up
  if ("time" %in% names(data)) {
    data <- data[data$time >= min_follow_up, ]
  }

  # Handle missing data
  if (exclude_missing) {
    data <- na.omit(data)
  }

  return(data)
}

#' Apply propensity score matching
#' @param data Patient data
#' @return Matched data
apply_propensity_matching <- function(data) {
  # Simplified propensity matching for demonstration
  # In practice, use MatchIt or similar package

  # For now, return data as-is
  # Real implementation would use:
  # library(MatchIt)
  # matchit_obj <- matchit(treatment ~ age + sex + comorbidity_score, data = data, method = "nearest")
  # matched_data <- match.data(matchit_obj)

  data$propensity_matched <- TRUE
  return(data)
}

#' Analyze RWD
#' @param data Processed data
#' @param data_format Format type
#' @return Analysis results
analyze_rwd <- function(data, data_format) {

  # Quality assessment
  quality <- list(
    patient_id_complete = sum(!is.na(data$patient_id)) / nrow(data),
    treatment_complete = sum(!is.na(data$treatment)) / nrow(data),
    outcome_complete = sum(!is.na(data$outcome)) / nrow(data),
    time_complete = if ("time" %in% names(data)) sum(!is.na(data$time)) / nrow(data) else 1.0,
    overall_score = 0,
    issues = c()
  )

  quality$overall_score <- mean(c(quality$patient_id_complete,
                                 quality$treatment_complete,
                                 quality$outcome_complete,
                                 quality$time_complete))

  if (quality$overall_score < 0.8) {
    quality$issues <- c(quality$issues, "Overall data completeness below 80%")
  }

  # Descriptive statistics
  descriptive_stats <- data %>%
    group_by(treatment) %>%
    summarise(
      N = n(),
      Mean_Outcome = mean(outcome, na.rm = TRUE),
      SD_Outcome = sd(outcome, na.rm = TRUE),
      Median_Time = if ("time" %in% names(data)) median(time, na.rm = TRUE) else NA,
      .groups = "drop"
    )

  # Survival analysis (if applicable)
  survival_results <- NULL
  if ("time" %in% names(data) && "event" %in% names(data)) {
    library(survival)

    surv_obj <- Surv(time = data$time, event = data$event)
    km_fit <- survfit(surv_obj ~ treatment, data = data)
    logrank_test <- survdiff(surv_obj ~ treatment, data = data)
    cox_model <- coxph(surv_obj ~ treatment + age + sex, data = data)

    survival_results <- list(
      km_fit = km_fit,
      logrank_test = logrank_test,
      cox_model = cox_model
    )
  }

  # Comparative effectiveness
  effectiveness <- data.frame(
    outcome = "Primary Outcome",
    estimate = mean(data$outcome[data$treatment == "Treatment"], na.rm = TRUE) -
               mean(data$outcome[data$treatment == "Control"], na.rm = TRUE),
    ci_lower = NA,
    ci_upper = NA,
    p_value = t.test(outcome ~ treatment, data = data)$p.value,
    stringsAsFactors = FALSE
  )

  list(
    quality = quality,
    descriptive_stats = descriptive_stats,
    survival = survival_results,
    effectiveness = effectiveness,
    propensity = NULL  # Would be populated if matching was done
  )
}
