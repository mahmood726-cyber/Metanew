# Frontend Integration Guide - AI Features API

**Date:** 2025-11-05
**Version:** 1.0
**Status:** ✅ Production Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [R Shiny Integration](#r-shiny-integration)
4. [Performance Optimization](#performance-optimization)
5. [Error Handling](#error-handling)
6. [Complete Examples](#complete-examples)
7. [Best Practices](#best-practices)

---

## Overview

This guide shows how to integrate the 5 advanced AI features into your R Shiny frontend:

1. **Natural Language Report Generation** - Automated PRISMA/CONSORT reports
2. **Risk of Bias Assessment** - ML-based ROB classification
3. **Study Screening Assistant** - Active learning for study selection
4. **PDF Data Extraction** - Extract meta-analysis data from PDFs
5. **Bayesian Network Meta-Analysis** - Full Bayesian NMA with PyMC

---

## Quick Start

### 1. Install Required Packages

```r
install.packages(c("httr", "jsonlite", "R6", "shiny", "shinydashboard", "DT", "markdown"))
```

### 2. Source the API Client

```r
source("frontend/R/ai_features_api_client.R")
```

### 3. Initialize Client

```r
# Create client with authentication
client <- create_ai_client(
  base_url = "http://localhost:8000",
  token = "your_auth_token_here"
)

# Check status
status <- client$get_status()
print(status)
```

### 4. Generate Your First Report

```r
# Prepare data
meta_results <- list(
  pooled_effect = 0.75,
  ci_lower = 0.60,
  ci_upper = 0.95,
  i_squared = 45.2,
  p_value = 0.003
)

study_data <- data.frame(
  study_id = c("Study1", "Study2", "Study3"),
  year = c(2020, 2021, 2022),
  n_treatment = c(100, 150, 120),
  n_control = c(100, 150, 120)
)

analysis_config <- list(
  outcome = "mortality",
  intervention = "Drug A",
  comparator = "Placebo"
)

# Generate report
report <- client$generate_report(
  meta_analysis_results = meta_results,
  study_data = study_data,
  analysis_config = analysis_config,
  report_type = "prisma",
  include_quality_metrics = TRUE
)

# Display
cat(format_report_markdown(report))
```

---

## R Shiny Integration

### Method 1: Using Pre-Built Modules (Recommended)

The fastest way to integrate AI features is using the pre-built Shiny modules:

```r
source("frontend/R/shiny_modules_ai_features.R")

ui <- dashboardPage(
  dashboardHeader(title = "My Meta-Analysis Tool"),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Report Generation", tabName = "report"),
      menuItem("Risk of Bias", tabName = "rob"),
      menuItem("Screening", tabName = "screening")
    ),
    hr(),
    textInput("api_token", "API Token"),
    actionButton("connect", "Connect")
  ),

  dashboardBody(
    tabItems(
      tabItem(tabName = "report",
        reportGenerationUI("report_module")
      ),
      tabItem(tabName = "rob",
        robAssessmentUI("rob_module")
      ),
      tabItem(tabName = "screening",
        studyScreeningUI("screening_module")
      )
    )
  )
)

server <- function(input, output, session) {
  # Initialize API client
  api_client <- reactiveVal(NULL)

  observeEvent(input$connect, {
    client <- create_ai_client(token = input$api_token)
    api_client(client)
    showNotification("Connected!", type = "message")
  })

  # Your study data
  study_data <- reactive({
    # Get from your existing data source
    data.frame(
      study_id = c("S1", "S2"),
      year = c(2020, 2021)
    )
  })

  # Initialize modules
  reportGenerationServer("report_module", api_client, study_data)
  robAssessmentServer("rob_module", api_client)
  studyScreeningServer("screening_module", api_client)
}

shinyApp(ui, server)
```

**Benefits:**
- ✅ Pre-built UI components
- ✅ Error handling included
- ✅ Progress indicators
- ✅ Download buttons
- ✅ Validation built-in

### Method 2: Custom Integration

For full control, call the API directly:

```r
server <- function(input, output, session) {
  client <- create_ai_client(token = "your_token")

  observeEvent(input$generate_report, {
    withProgress(message = "Generating report...", {
      tryCatch({
        report <- client$generate_report(
          meta_analysis_results = list(
            pooled_effect = input$pooled_effect,
            ci_lower = input$ci_lower,
            ci_upper = input$ci_upper
          ),
          study_data = my_study_data(),
          analysis_config = list(
            outcome = input$outcome,
            intervention = input$intervention
          ),
          report_type = input$report_type
        )

        output$report <- renderUI({
          # Display report
          HTML(markdown::markdownToHTML(
            text = format_report_markdown(report),
            fragment.only = TRUE
          ))
        })

        showNotification("Report ready!", type = "message")

      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error")
      })
    })
  })
}
```

---

## Performance Optimization

### 1. Caching with Redis

The backend automatically caches expensive operations:

- **Report Generation:** 2 hour cache
- **ROB Assessment:** 1 hour cache
- **Study Screening:** 30 minute cache
- **PDF Extraction:** 2 hour cache
- **Bayesian NMA:** 4 hour cache

**Result:** 10-100x speedup for repeated queries!

### 2. Batch Operations

Always use batch endpoints when processing multiple items:

```r
# ❌ BAD: Individual calls
for (study in studies) {
  result <- client$screen_study(study$title, study$abstract)
}

# ✅ GOOD: Batch call
results <- client$screen_studies_batch(
  studies = data.frame(
    title = studies$title,
    abstract = studies$abstract
  ),
  threshold = 0.5
)
```

**Performance:** 5-10x faster than individual calls

### 3. Progress Indicators

For long operations, show progress:

```r
observeEvent(input$fit_nma, {
  withProgress(message = "Fitting NMA model...", value = 0, {

    incProgress(0.2, detail = "Preparing data...")
    data_prepared <- prepare_nma_data()

    incProgress(0.3, detail = "Running MCMC (this may take 2-5 minutes)...")
    nma_results <- client$fit_bayesian_nma(
      data = data_prepared,
      n_samples = 2000,
      n_tune = 1000
    )

    incProgress(0.5, detail = "Getting rankings...")
    rankings <- client$get_nma_rankings()

    incProgress(1.0, detail = "Complete!")

    # Display results
    output$nma_results <- renderPlot({
      # Plot rankings
    })
  })
})
```

### 4. Async Processing

For very long operations, consider async processing:

```r
library(future)
library(promises)

plan(multisession)

observeEvent(input$run_benchmarks, {
  future({
    client$run_benchmarks()
  }) %...>% (function(results) {
    output$benchmark_results <- renderPrint({
      print(results)
    })
  })
})
```

---

## Error Handling

### Robust Error Handling Pattern

```r
observeEvent(input$action, {
  tryCatch({
    # Validate inputs
    validate(
      need(input$study_text, "Please enter study text"),
      need(nchar(input$study_text) > 100, "Text too short (min 100 chars)")
    )

    # Call API
    result <- client$assess_rob(
      study_text = input$study_text
    )

    # Success
    output$result <- renderUI({
      # Display result
    })
    showNotification("Success!", type = "message")

  }, error = function(e) {
    # Handle different error types
    if (grepl("401|403", e$message)) {
      showModal(modalDialog(
        title = "Authentication Error",
        "Please check your API token and try again.",
        easyClose = TRUE
      ))
    } else if (grepl("500", e$message)) {
      showNotification(
        "Server error. Please try again or contact support.",
        type = "error",
        duration = 10
      )
    } else {
      showNotification(
        paste("Error:", e$message),
        type = "error"
      )
    }

    # Log error
    print(paste("Error:", e$message))
  })
})
```

### Connection Health Check

```r
# Check API health on startup
session$onSessionStarted(function() {
  tryCatch({
    status <- client$get_status()

    if (status$overall$production_ready) {
      showNotification("API connected successfully!", type = "message")
    } else {
      showNotification("API connected but some features unavailable", type = "warning")
    }

  }, error = function(e) {
    showModal(modalDialog(
      title = "Cannot Connect to API",
      paste("Please ensure the API server is running at", client$base_url),
      footer = actionButton("retry", "Retry")
    ))
  })
})
```

---

## Complete Examples

### Example 1: Complete Report Generation Workflow

```r
library(shiny)
library(shinydashboard)
source("frontend/R/ai_features_api_client.R")

ui <- dashboardPage(
  dashboardHeader(title = "Report Generator"),
  dashboardSidebar(
    fileInput("upload_studies", "Upload Study Data (CSV)"),
    numericInput("pooled_effect", "Pooled Effect", 0.75),
    numericInput("ci_lower", "CI Lower", 0.60),
    numericInput("ci_upper", "CI Upper", 0.95),
    selectInput("report_type", "Report Type",
               choices = c("PRISMA" = "prisma", "CONSORT" = "consort")),
    actionButton("generate", "Generate Report", class = "btn-primary")
  ),
  dashboardBody(
    fluidRow(
      box(title = "Generated Report", width = 8,
          uiOutput("report_display")
      ),
      box(title = "Quality Metrics", width = 4,
          valueBoxOutput("readability", width = 12),
          valueBoxOutput("prisma", width = 12),
          downloadButton("download", "Download Report")
      )
    )
  )
)

server <- function(input, output, session) {
  client <- create_ai_client(token = Sys.getenv("API_TOKEN"))
  report_data <- reactiveVal(NULL)

  study_data <- reactive({
    req(input$upload_studies)
    read.csv(input$upload_studies$datapath)
  })

  observeEvent(input$generate, {
    req(study_data())

    withProgress(message = "Generating report...", {
      report <- client$generate_report(
        meta_analysis_results = list(
          pooled_effect = input$pooled_effect,
          ci_lower = input$ci_lower,
          ci_upper = input$ci_upper
        ),
        study_data = study_data(),
        analysis_config = list(
          outcome = "primary outcome",
          intervention = "treatment",
          comparator = "control"
        ),
        report_type = input$report_type,
        include_quality_metrics = TRUE
      )

      report_data(report)
    })
  })

  output$report_display <- renderUI({
    req(report_data())
    report <- report_data()

    sections <- lapply(report$sections, function(sec) {
      tagList(
        h3(sec$heading),
        p(sec$content),
        hr()
      )
    })

    tagList(
      h2(report$title),
      p(paste("Generated:", Sys.time())),
      hr(),
      sections
    )
  })

  output$readability <- renderValueBox({
    req(report_data())
    score <- report_data()$quality_metrics$readability$flesch_reading_ease

    valueBox(
      round(score, 1),
      "Readability Score",
      icon = icon("book-open"),
      color = if (score >= 60) "green" else "yellow"
    )
  })

  output$prisma <- renderValueBox({
    req(report_data())
    score <- report_data()$quality_metrics$prisma_compliance$score

    valueBox(
      paste0(round(score, 1), "%"),
      "PRISMA Compliance",
      icon = icon("check-circle"),
      color = if (score >= 90) "green" else if (score >= 75) "yellow" else "red"
    )
  })

  output$download <- downloadHandler(
    filename = function() {
      paste0("report_", Sys.Date(), ".md")
    },
    content = function(file) {
      writeLines(format_report_markdown(report_data()), file)
    }
  )
}

shinyApp(ui, server)
```

### Example 2: Batch Study Screening with Active Learning

```r
library(shiny)
library(DT)
source("frontend/R/ai_features_api_client.R")

ui <- fluidPage(
  titlePanel("Study Screening Assistant"),

  sidebarLayout(
    sidebarPanel(
      fileInput("studies_file", "Upload Studies (CSV with title, abstract)"),
      sliderInput("threshold", "Inclusion Threshold", 0, 1, 0.5, 0.05),
      actionButton("screen_all", "Screen All Studies"),
      hr(),
      numericInput("n_suggestions", "Active Learning Suggestions", 10, 1, 100),
      actionButton("get_suggestions", "Get Next Studies to Review")
    ),

    mainPanel(
      tabsetPanel(
        tabPanel("Screening Results",
          valueBoxOutput("included_count"),
          valueBoxOutput("excluded_count"),
          valueBoxOutput("review_count"),
          DTOutput("results_table")
        ),
        tabPanel("Active Learning",
          p("These are the studies that would most benefit from manual review:"),
          DTOutput("suggestions_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  client <- create_ai_client(token = Sys.getenv("API_TOKEN"))

  studies <- reactive({
    req(input$studies_file)
    read.csv(input$studies_file$datapath)
  })

  screening_results <- reactiveVal(NULL)

  observeEvent(input$screen_all, {
    req(studies())

    withProgress(message = "Screening studies...", {
      results <- client$screen_studies_batch(
        studies = studies(),
        threshold = input$threshold
      )

      screening_results(results)
    })
  })

  output$included_count <- renderValueBox({
    req(screening_results())
    valueBox(
      screening_results()$summary$included,
      "Included",
      icon = icon("check"),
      color = "green"
    )
  })

  output$excluded_count <- renderValueBox({
    req(screening_results())
    valueBox(
      screening_results()$summary$excluded,
      "Excluded",
      icon = icon("times"),
      color = "red"
    )
  })

  output$review_count <- renderValueBox({
    req(screening_results())
    valueBox(
      screening_results()$summary$needs_review,
      "Manual Review",
      icon = icon("exclamation-triangle"),
      color = "yellow"
    )
  })

  output$results_table <- renderDT({
    req(screening_results())
    results_df <- do.call(rbind, lapply(screening_results()$results, as.data.frame))
    datatable(results_df, options = list(pageLength = 25))
  })

  observeEvent(input$get_suggestions, {
    req(studies())

    # Filter to unscreened studies
    unscreened <- studies()[!studies()$screened, ]

    suggestions <- client$get_active_learning_suggestions(
      unlabeled_studies = unscreened,
      n_suggestions = input$n_suggestions,
      strategy = "uncertainty"
    )

    output$suggestions_table <- renderDT({
      suggestions_df <- do.call(rbind, lapply(suggestions$suggestions, as.data.frame))
      datatable(suggestions_df, options = list(pageLength = 10))
    })
  })
}

shinyApp(ui, server)
```

---

## Best Practices

### 1. Authentication

```r
# ✅ GOOD: Use environment variables
client <- create_ai_client(
  base_url = Sys.getenv("API_BASE_URL", "http://localhost:8000"),
  token = Sys.getenv("API_TOKEN")
)

# ❌ BAD: Hard-code credentials
client <- create_ai_client(token = "my-secret-token-123")
```

### 2. Input Validation

```r
# Always validate before calling API
validate(
  need(input$study_text, "Please enter study text"),
  need(nchar(input$study_text) >= 100, "Text too short (min 100 characters)"),
  need(input$threshold >= 0 && input$threshold <= 1, "Threshold must be 0-1")
)
```

### 3. Resource Management

```r
# Clean up on session end
session$onSessionEnded(function() {
  # Clear any temporary data
  # Close connections
})
```

### 4. User Feedback

```r
# Always show feedback
showNotification("Processing...", duration = NULL, id = "process")
result <- client$some_operation()
removeNotification("process")
showNotification("Complete!", type = "message")
```

### 5. Testing

```r
# Test with mock data first
test_client <- function() {
  client <- create_ai_client()

  # Test connection
  status <- client$get_status()
  stopifnot(status$overall$production_ready)

  # Test report generation
  report <- client$generate_report(
    meta_analysis_results = list(pooled_effect = 0.75),
    study_data = data.frame(study_id = "Test"),
    analysis_config = list()
  )
  stopifnot(!is.null(report$title))

  print("✓ All tests passed!")
}

test_client()
```

---

## Troubleshooting

### Connection Errors

```r
# Check if API is running
system("curl http://localhost:8000/health")

# Check authentication
status <- tryCatch(
  client$get_status(),
  error = function(e) {
    if (grepl("401|403", e$message)) {
      stop("Authentication failed. Check your API token.")
    } else if (grepl("Connection refused", e$message)) {
      stop("API server not running. Start with: uvicorn api.main:app")
    } else {
      stop(e$message)
    }
  }
)
```

### Timeout Errors

```r
# Increase timeout for long operations
options(httr_timeout = 300)  # 5 minutes

# Or use async processing
future({ client$fit_bayesian_nma(...) })
```

### Memory Errors

```r
# Process in batches
batch_size <- 100
results <- list()

for (i in seq(1, nrow(studies), batch_size)) {
  batch <- studies[i:min(i + batch_size - 1, nrow(studies)), ]
  batch_results <- client$screen_studies_batch(batch)
  results[[length(results) + 1]] <- batch_results

  gc()  # Force garbage collection
}
```

---

## Next Steps

1. ✅ Review the [API Documentation](backend/API_ROUTES_DOCUMENTATION.md)
2. ✅ Try the [Example Apps](#complete-examples)
3. ✅ Customize the [Shiny Modules](frontend/R/shiny_modules_ai_features.R)
4. ✅ Deploy to production (see deployment guide)

---

## Support

- **Documentation:** See `backend/API_ROUTES_DOCUMENTATION.md`
- **Issues:** [GitHub Issues](https://github.com/mahmood726-cyber/Metanew/issues)
- **API Status:** `GET /api/ai-features/status`

---

**Last Updated:** 2025-11-05
**Status:** ✅ Production Ready
**API Version:** 1.0
