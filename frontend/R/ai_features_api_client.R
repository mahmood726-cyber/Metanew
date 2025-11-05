# AI Features API Client for R Shiny
# Provides easy-to-use functions for calling AI features endpoints
#
# Usage:
#   client <- AIFeaturesClient$new(base_url = "http://localhost:8000", token = "your_token")
#   report <- client$generate_report(meta_results, study_data)
#

library(httr)
library(jsonlite)
library(R6)

#' AI Features API Client
#'
#' R6 class for interacting with AI Features API endpoints
#'
#' @examples
#' \dontrun{
#' # Initialize client
#' client <- AIFeaturesClient$new(
#'   base_url = "http://localhost:8000",
#'   token = "your_auth_token"
#' )
#'
#' # Generate report
#' report <- client$generate_report(
#'   meta_analysis_results = list(pooled_effect = 0.75, ci_lower = 0.60, ci_upper = 0.95),
#'   study_data = data.frame(study_id = c("S1", "S2"), year = c(2020, 2021)),
#'   analysis_config = list(outcome = "mortality", intervention = "Drug A")
#' )
#'
#' # Assess risk of bias
#' rob <- client$assess_rob(
#'   study_text = "This randomized controlled trial...",
#'   study_metadata = list(title = "Study Title", year = 2022)
#' )
#'
#' # Screen study
#' screening <- client$screen_study(
#'   title = "Study Title",
#'   abstract = "Study abstract...",
#'   threshold = 0.5
#' )
#' }
#'
#' @export
AIFeaturesClient <- R6Class(
  "AIFeaturesClient",

  public = list(
    #' @field base_url API base URL
    base_url = NULL,

    #' @field token Authentication token
    token = NULL,

    #' @description
    #' Initialize API client
    #' @param base_url API base URL (default: http://localhost:8000)
    #' @param token Bearer authentication token
    initialize = function(base_url = "http://localhost:8000", token = NULL) {
      self$base_url <- paste0(base_url, "/api/ai-features")
      self$token <- token
    },

    # ==================== PRIVATE METHODS ====================

    #' @description
    #' Make API request with error handling
    #' @param method HTTP method (GET, POST)
    #' @param endpoint API endpoint
    #' @param body Request body (for POST)
    .request = function(method, endpoint, body = NULL) {
      url <- paste0(self$base_url, endpoint)

      headers <- add_headers(
        "Content-Type" = "application/json"
      )

      if (!is.null(self$token)) {
        headers <- add_headers(
          "Content-Type" = "application/json",
          "Authorization" = paste("Bearer", self$token)
        )
      }

      tryCatch({
        if (method == "GET") {
          response <- GET(url, headers, timeout(60))
        } else {
          response <- POST(
            url,
            headers,
            body = toJSON(body, auto_unbox = TRUE),
            encode = "json",
            timeout(120)  # Longer timeout for expensive operations
          )
        }

        # Check status
        if (status_code(response) >= 400) {
          error_msg <- tryCatch({
            content(response, "parsed")$detail
          }, error = function(e) {
            paste("HTTP", status_code(response))
          })
          stop(paste("API Error:", error_msg))
        }

        # Parse response
        result <- content(response, "parsed")
        return(result)

      }, error = function(e) {
        stop(paste("Request failed:", e$message))
      })
    },

    # ==================== REPORT GENERATION ====================

    #' @description
    #' Generate natural language meta-analysis report
    #' @param meta_analysis_results Meta-analysis results (pooled_effect, ci_lower, ci_upper, etc.)
    #' @param study_data Study data as data.frame
    #' @param analysis_config Analysis configuration (outcome, intervention, comparator, etc.)
    #' @param report_type Report type ("prisma", "consort", "grade")
    #' @param include_quality_metrics Include quality metrics (default: TRUE)
    #' @return Report with sections and quality metrics
    generate_report = function(
      meta_analysis_results,
      study_data,
      analysis_config = list(),
      report_type = "prisma",
      include_quality_metrics = TRUE
    ) {
      # Convert data.frame to list format
      if (is.data.frame(study_data)) {
        study_data <- as.list(study_data)
      }

      body <- list(
        meta_analysis_results = meta_analysis_results,
        study_data = study_data,
        analysis_config = analysis_config,
        report_type = report_type,
        include_quality_metrics = include_quality_metrics
      )

      self$.request("POST", "/report/generate", body)
    },

    #' @description
    #' Calculate quality metrics for text
    #' @param text Text to analyze
    #' @param report_sections Report sections (abstract, methods, results, discussion)
    #' @return Quality metrics (readability, PRISMA compliance, etc.)
    calculate_quality_metrics = function(text, report_sections = NULL) {
      body <- list(
        text = text,
        report_sections = report_sections
      )

      self$.request("POST", "/report/quality-metrics", body)
    },

    # ==================== RISK OF BIAS ====================

    #' @description
    #' Assess risk of bias for a study
    #' @param study_text Full text or abstract of the study
    #' @param study_metadata Study metadata (title, year, journal, etc.)
    #' @param return_probabilities Return domain probabilities (default: TRUE)
    #' @return ROB assessment with judgments for all domains
    assess_rob = function(
      study_text,
      study_metadata = NULL,
      return_probabilities = TRUE
    ) {
      body <- list(
        study_text = study_text,
        study_metadata = study_metadata,
        return_probabilities = return_probabilities
      )

      self$.request("POST", "/rob/assess", body)
    },

    #' @description
    #' Assess risk of bias for multiple studies
    #' @param studies List of studies with 'text' and optional 'metadata'
    #' @param parallel Process in parallel (default: TRUE)
    #' @return Batch assessment results with summary
    assess_rob_batch = function(studies, parallel = TRUE) {
      body <- list(
        studies = studies,
        parallel = parallel
      )

      self$.request("POST", "/rob/assess-batch", body)
    },

    #' @description
    #' Train ROB model on labeled data
    #' @param training_data Data frame with 'text' and domain columns
    #' @return Training results (accuracy, precision, recall, etc.)
    train_rob_model = function(training_data) {
      body <- as.list(training_data)
      self$.request("POST", "/rob/train", body)
    },

    # ==================== STUDY SCREENING ====================

    #' @description
    #' Screen a study for inclusion/exclusion
    #' @param title Study title
    #' @param abstract Study abstract
    #' @param threshold Classification threshold (0-1, default: 0.5)
    #' @return Screening decision with confidence
    screen_study = function(title, abstract = "", threshold = 0.5) {
      body <- list(
        title = title,
        abstract = abstract,
        threshold = threshold
      )

      self$.request("POST", "/screening/screen-study", body)
    },

    #' @description
    #' Screen multiple studies at once
    #' @param studies Data frame or list with 'title' and 'abstract'
    #' @param threshold Classification threshold
    #' @return Batch screening results with summary
    screen_studies_batch = function(studies, threshold = 0.5) {
      if (is.data.frame(studies)) {
        studies <- lapply(1:nrow(studies), function(i) {
          list(
            title = as.character(studies$title[i]),
            abstract = as.character(studies$abstract[i])
          )
        })
      }

      body <- list(
        studies = studies,
        threshold = threshold
      )

      self$.request("POST", "/screening/screen-batch", body)
    },

    #' @description
    #' Train screening model on labeled studies
    #' @param labeled_studies Data frame with 'title', 'abstract', 'include' (0/1)
    #' @param validation_split Validation split (0-1, default: 0.2)
    #' @return Training results
    train_screening_model = function(labeled_studies, validation_split = 0.2) {
      body <- list(
        labeled_studies = as.list(labeled_studies),
        validation_split = validation_split
      )

      self$.request("POST", "/screening/train", body)
    },

    #' @description
    #' Get active learning suggestions
    #' @param unlabeled_studies Data frame with 'title' and 'abstract'
    #' @param n_suggestions Number of suggestions (default: 10)
    #' @param strategy Strategy: "uncertainty", "diversity", "hybrid"
    #' @return Suggested studies to review next
    get_active_learning_suggestions = function(
      unlabeled_studies,
      n_suggestions = 10,
      strategy = "uncertainty"
    ) {
      body <- list(
        unlabeled_studies = as.list(unlabeled_studies),
        n_suggestions = n_suggestions,
        strategy = strategy
      )

      self$.request("POST", "/screening/active-learning", body)
    },

    # ==================== PDF EXTRACTION ====================

    #' @description
    #' Extract meta-analysis data from PDF text
    #' @param pdf_text Extracted PDF text content
    #' @param extract_tables Extract tables (default: TRUE)
    #' @param extract_metadata Extract metadata (default: TRUE)
    #' @return Extracted data (sample_sizes, effect_sizes, statistics, tables, metadata)
    extract_from_pdf_text = function(
      pdf_text,
      extract_tables = TRUE,
      extract_metadata = TRUE
    ) {
      body <- list(
        pdf_text = pdf_text,
        extract_tables = extract_tables,
        extract_metadata = extract_metadata
      )

      self$.request("POST", "/pdf/extract-text", body)
    },

    #' @description
    #' Extract data from PDF file
    #' @param pdf_path Path to PDF file
    #' @return Extracted data
    extract_from_pdf_file = function(pdf_path) {
      # Note: File upload requires different handling
      # This is a simplified version - full implementation would use upload_file()
      warning("PDF file upload not yet fully implemented in R client. Use extract_from_pdf_text() with pre-extracted text.")
      stop("Use extract_from_pdf_text() instead")
    },

    # ==================== BAYESIAN NMA ====================

    #' @description
    #' Fit Bayesian Network Meta-Analysis model
    #' @param data Data frame with study, treatment, events/mean, total/sd
    #' @param outcome_type Outcome type ("binary", "continuous", "rate")
    #' @param model_type Model type ("random", "fixed")
    #' @param n_samples Number of MCMC samples (default: 2000)
    #' @param n_tune Number of tuning samples (default: 1000)
    #' @return NMA results with treatment effects and convergence
    fit_bayesian_nma = function(
      data,
      outcome_type = "binary",
      model_type = "random",
      n_samples = 2000,
      n_tune = 1000
    ) {
      body <- list(
        data = as.list(data),
        outcome_type = outcome_type,
        model_type = model_type,
        n_samples = n_samples,
        n_tune = n_tune
      )

      self$.request("POST", "/nma/fit", body)
    },

    #' @description
    #' Get treatment rankings (SUCRA scores)
    #' @return Treatment rankings
    get_nma_rankings = function() {
      self$.request("POST", "/nma/rankings", list())
    },

    #' @description
    #' Get league table with pairwise comparisons
    #' @return League table
    get_nma_league_table = function() {
      self$.request("POST", "/nma/league-table", list())
    },

    #' @description
    #' Get convergence diagnostics
    #' @return Diagnostics (R-hat, ESS, etc.)
    get_nma_diagnostics = function() {
      self$.request("GET", "/nma/diagnostics", NULL)
    },

    # ==================== BENCHMARKING & STATUS ====================

    #' @description
    #' Run comprehensive benchmarks for all features
    #' @return Benchmark results
    run_benchmarks = function() {
      self$.request("POST", "/benchmark/all", list())
    },

    #' @description
    #' Get benchmark report
    #' @param format Format ("markdown" or "html")
    #' @return Formatted benchmark report
    get_benchmark_report = function(format = "markdown") {
      endpoint <- paste0("/benchmark/report?format=", format)
      self$.request("GET", endpoint, NULL)
    },

    #' @description
    #' Get features status
    #' @return Status of all AI features
    get_status = function() {
      self$.request("GET", "/status", NULL)
    }
  )
)


#' Create AI Features API client
#'
#' Convenience function to create client instance
#'
#' @param base_url API base URL
#' @param token Authentication token
#' @return AIFeaturesClient instance
#' @export
create_ai_client <- function(base_url = "http://localhost:8000", token = NULL) {
  AIFeaturesClient$new(base_url = base_url, token = token)
}


#' Format report for display
#'
#' Convert API report response to formatted Markdown
#'
#' @param report Report from generate_report()
#' @return Markdown formatted text
#' @export
format_report_markdown <- function(report) {
  lines <- c(
    paste0("# ", report$title),
    "",
    paste0("**Generated:** ", Sys.time()),
    ""
  )

  # Add sections
  for (section in report$sections) {
    lines <- c(
      lines,
      paste0("## ", section$heading),
      "",
      section$content,
      ""
    )
  }

  # Add quality metrics if present
  if (!is.null(report$quality_metrics)) {
    qm <- report$quality_metrics
    lines <- c(
      lines,
      "---",
      "## Quality Metrics",
      "",
      paste0("- **Readability (Flesch Reading Ease):** ", round(qm$readability$flesch_reading_ease, 1)),
      paste0("- **Grade Level:** ", qm$readability$grade_level),
      paste0("- **Target Met:** ", ifelse(qm$readability$target_met, "✓ Yes", "✗ No"))
    )

    if (!is.null(qm$prisma_compliance)) {
      lines <- c(
        lines,
        paste0("- **PRISMA Compliance:** ", round(qm$prisma_compliance$score, 1), "%"),
        paste0("- **Coverage:** ", round(qm$prisma_compliance$coverage * 100, 1), "%")
      )
    }
  }

  paste(lines, collapse = "\n")
}


#' Format ROB assessment for display
#'
#' Convert ROB assessment to readable format
#'
#' @param rob ROB assessment from assess_rob()
#' @return Formatted text
#' @export
format_rob_assessment <- function(rob) {
  lines <- c(
    paste0("**Overall:** ", rob$overall_judgment, " (", round(rob$overall_confidence * 100), "% confidence)"),
    "",
    "**Domains:**"
  )

  for (domain_name in names(rob$domains)) {
    domain <- rob$domains[[domain_name]]
    lines <- c(
      lines,
      paste0("- **", tools::toTitleCase(gsub("_", " ", domain_name)), ":** ",
             domain$judgment, " (", round(domain$confidence * 100), "% confidence)")
    )
  }

  if (!is.null(rob$recommendations)) {
    lines <- c(
      lines,
      "",
      "**Recommendations:**"
    )
    for (rec in rob$recommendations) {
      lines <- c(lines, paste0("- ", rec))
    }
  }

  paste(lines, collapse = "\n")
}


# Example usage in Shiny app:
if (FALSE) {
  library(shiny)

  ui <- fluidPage(
    titlePanel("AI Features Demo"),

    sidebarLayout(
      sidebarPanel(
        textInput("api_token", "API Token", ""),
        actionButton("generate", "Generate Report")
      ),

      mainPanel(
        verbatimTextOutput("report")
      )
    )
  )

  server <- function(input, output, session) {
    client <- reactive({
      create_ai_client(token = input$api_token)
    })

    observeEvent(input$generate, {
      report <- client()$generate_report(
        meta_analysis_results = list(pooled_effect = 0.75, ci_lower = 0.60, ci_upper = 0.95),
        study_data = data.frame(study_id = c("S1", "S2"), year = c(2020, 2021)),
        analysis_config = list(outcome = "mortality", intervention = "Drug A")
      )

      output$report <- renderText({
        format_report_markdown(report)
      })
    })
  }

  shinyApp(ui, server)
}
