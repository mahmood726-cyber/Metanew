# EvidenceOS PRIME - R Frontend Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Module Reference](#module-reference)
4. [Utilities Reference](#utilities-reference)
5. [Development Guide](#development-guide)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The EvidenceOS PRIME frontend is built with R Shiny and provides an interactive interface for:
- Meta-analysis (pairwise, network, dose-response)
- Health economics modeling
- Living meta-analysis
- AI-powered analysis assistance
- Report generation

### Technology Stack

- **Framework**: R Shiny 1.8.0+
- **UI**: bslib (Bootstrap 5)
- **Visualization**: plotly, ggplot2
- **Data**: DT (DataTables)
- **Validation**: shinyvalidate
- **Analysis**: metafor, netmeta, dosresmeta, BCEA

---

## Architecture

### Application Structure

```
frontend/
├── app.R                  # Main application entry point
├── modules/              # Shiny modules for features
│   ├── data_import.R     # Data import and management
│   ├── protocol.R        # Protocol management
│   ├── meta_pairwise.R   # Pairwise meta-analysis
│   ├── nma.R             # Network meta-analysis
│   ├── dose_response.R   # Dose-response meta-analysis
│   ├── sensitivity.R     # Sensitivity analysis
│   ├── he_params.R       # Health economics parameters
│   ├── he_model.R        # Health economics models
│   ├── he_bcea.R         # Cost-effectiveness analysis
│   ├── he_budget_impact.R # Budget impact analysis
│   ├── living_ma.R       # Living meta-analysis
│   ├── reporting.R       # Report generation
│   ├── audit.R           # Audit trail
│   ├── ai_copilot.R      # AI assistant
│   ├── client_portal.R   # Client interface
│   └── v2_features.R     # V2.0 features
└── utils/                # Utility functions
    ├── python_bridge.R   # Python API communication
    ├── cache_bridge.R    # Cache management
    ├── plotting.R        # Visualization utilities
    ├── validators.R      # Data validation
    ├── config_loader.R   # Configuration management
    ├── protocol_diff.R   # Protocol comparison
    ├── living_ma_tracker.R # Living MA tracking
    ├── scenario_presets.R  # Scenario management
    └── advanced_he.R     # Advanced HE calculations
```

### Module Pattern

All feature modules follow the Shiny module pattern:

```r
# UI Function
feature_ui <- function(id) {
  ns <- NS(id)
  # UI elements with namespaced IDs
}

# Server Function
feature_server <- function(id, shared_data) {
  moduleServer(id, function(input, output, session) {
    # Server logic
  })
}
```

---

## Module Reference

### 1. Data Import Module (`data_import.R`)

**Purpose**: Handle data ingestion from CSV, Excel, and manual entry.

**Key Functions**:

```r
data_import_ui(id)
# Creates UI for data import tab

data_import_server(id)
# Handles file uploads, validation, and data storage
# Returns: reactive data object
```

**Usage Example**:
```r
# In UI
data_import_ui("data_import")

# In server
imported_data <- data_import_server("data_import")
```

**Features**:
- Multiple file format support (CSV, XLSX)
- Data preview and validation
- Column mapping
- Data type detection
- Manual data entry

---

### 2. Pairwise Meta-Analysis Module (`meta_pairwise.R`)

**Purpose**: Perform traditional pairwise meta-analysis.

**Key Functions**:

```r
meta_pairwise_ui(id)
# Creates UI for pairwise meta-analysis

meta_pairwise_server(id, data)
# Performs meta-analysis using metafor
# Returns: analysis results
```

**Analysis Methods**:
- Fixed-effects model
- Random-effects model (DerSimonian-Laird, REML)
- Subgroup analysis
- Meta-regression
- Publication bias assessment (funnel plots, Egger's test)
- Sensitivity analysis

**Example**:
```r
# Continuous outcomes
ma_results <- rma(
  yi = effect_size,
  vi = variance,
  data = data,
  method = "REML",
  measure = "MD"  # Mean Difference
)

# Binary outcomes
ma_results <- rma(
  ai = events_treatment,
  bi = n_treatment - events_treatment,
  ci = events_control,
  di = n_control - events_control,
  data = data,
  measure = "RR"  # Risk Ratio
)
```

---

### 3. Network Meta-Analysis Module (`nma.R`)

**Purpose**: Perform network meta-analysis for multiple treatments.

**Key Functions**:

```r
nma_ui(id)
# Creates UI for network meta-analysis

nma_server(id, data)
# Performs NMA using netmeta
# Returns: NMA results including ranking
```

**Features**:
- Network plot generation
- Treatment ranking (SUCRA)
- Inconsistency assessment
- League tables
- Forest plots by comparison

**Example**:
```r
nma_results <- netmeta(
  TE = effect_size,
  seTE = standard_error,
  treat1 = treatment1,
  treat2 = treatment2,
  studlab = study_id,
  data = data,
  sm = "MD",
  reference = "Placebo"
)

# Get treatment rankings
rankings <- netrank(nma_results)
```

---

### 4. Health Economics Model Module (`he_model.R`)

**Purpose**: Build health economics models (Markov, decision trees).

**Key Functions**:

```r
he_model_ui(id)
# Creates UI for HE model building

he_model_server(id, parameters)
# Runs HE model simulation
# Returns: model results (costs, QALYs)
```

**Model Types**:
- Markov cohort models
- Decision trees
- Microsimulation (planned)

**Example Markov Model**:
```r
# Define states
states <- c("Healthy", "Sick", "Dead")

# Transition matrix
trans_matrix <- matrix(c(
  0.90, 0.08, 0.02,  # From Healthy
  0.05, 0.85, 0.10,  # From Sick
  0.00, 0.00, 1.00   # From Dead
), nrow = 3, byrow = TRUE)

# Run model
results <- run_markov_model(
  trans_matrix = trans_matrix,
  costs = c(0, 5000, 0),
  utilities = c(1.0, 0.6, 0),
  cycles = 20,
  discount_rate = 0.03
)
```

---

### 5. Cost-Effectiveness Analysis Module (`he_bcea.R`)

**Purpose**: Perform cost-effectiveness analysis using BCEA.

**Key Functions**:

```r
he_bcea_ui(id)
# Creates UI for CEA

he_bcea_server(id, he_results)
# Performs CEA using BCEA package
# Returns: CEA results, ICER, CEAC, etc.
```

**Features**:
- ICER calculation
- Cost-effectiveness plane
- CEAC (Cost-Effectiveness Acceptability Curve)
- EVPI (Expected Value of Perfect Information)
- PSA (Probabilistic Sensitivity Analysis)

**Example**:
```r
library(BCEA)

# Prepare data
costs <- matrix(c(costs_treatment, costs_comparator), ncol = 2)
effects <- matrix(c(qalys_treatment, qalys_comparator), ncol = 2)

# Run CEA
cea <- bcea(
  e = effects,
  c = costs,
  ref = 2,  # Comparator
  interventions = c("Treatment", "Comparator"),
  Kmax = 100000  # Max WTP threshold
)

# Generate plots
plot(cea)  # CE plane
ceac.plot(cea)  # CEAC
```

---

### 6. AI Copilot Module (`ai_copilot.R`)

**Purpose**: Provide AI-powered assistance for analysis.

**Key Functions**:

```r
ai_copilot_ui(id)
# Creates UI for AI assistant

ai_copilot_server(id, app_state)
# Processes natural language queries
# Returns: AI responses and suggestions
```

**Features**:
- Natural language query parsing
- Analysis suggestions
- Result interpretation
- Method recommendations
- Error troubleshooting

**Example Queries**:
- "Show me the forest plot"
- "What's the pooled effect size?"
- "Run subgroup analysis by study quality"
- "Is there publication bias?"

---

### 7. Living Meta-Analysis Module (`living_ma.R`)

**Purpose**: Manage living/continuously updated meta-analyses.

**Key Functions**:

```r
living_ma_ui(id)
# Creates UI for living MA management

living_ma_server(id, data)
# Tracks updates and triggers re-analysis
# Returns: versioned results
```

**Features**:
- Automated update detection
- Version control for analyses
- Change tracking
- Alert system for significant changes
- Cumulative meta-analysis

---

## Utilities Reference

### Python Bridge (`python_bridge.R`)

**Purpose**: Communicate with Python backend API.

**Key Functions**:

```r
call_python_api(endpoint, method = "GET", body = NULL)
# Make HTTP request to Python API
# Returns: parsed JSON response

validate_data_python(data)
# Send data to Python for validation
# Returns: validation results

transform_data_python(data, transformation)
# Send data to Python for transformation
# Returns: transformed data
```

**Example**:
```r
# Validate data
validation_result <- call_python_api(
  endpoint = "/api/validate",
  method = "POST",
  body = list(
    data = data,
    validation_rules = list(
      required_cols = c("study_id", "effect_size"),
      numeric_cols = c("effect_size", "se")
    )
  )
)

if (validation_result$is_valid) {
  # Proceed with analysis
}
```

---

### Cache Bridge (`cache_bridge.R`)

**Purpose**: Manage caching of analysis results.

**Key Functions**:

```r
create_cache_key(params)
# Generate unique cache key from parameters
# Returns: cache key string

get_cached_results(params)
# Retrieve results from cache
# Returns: cached data or NULL

save_to_cache(params, results)
# Save results to cache
# Returns: cache ID

clear_cache()
# Clear all cached results
```

**Example**:
```r
# Check cache before analysis
cache_key <- create_cache_key(list(
  outcome = "mortality",
  model = "random_effects",
  studies = study_ids
))

cached <- get_cached_results(cache_key)

if (is.null(cached)) {
  # Run analysis
  results <- run_meta_analysis(data)

  # Save to cache
  save_to_cache(cache_key, results)
} else {
  # Use cached results
  results <- cached
}
```

---

### Plotting Utilities (`plotting.R`)

**Purpose**: Create publication-quality visualizations.

**Key Functions**:

```r
create_forest_plot(ma_results, options = list())
# Create forest plot from MA results
# Returns: plotly object

create_funnel_plot(ma_results)
# Create funnel plot for publication bias assessment
# Returns: plotly object

create_network_plot(nma_results)
# Create network diagram
# Returns: plotly object

create_cea_plane(costs, effects)
# Create cost-effectiveness plane
# Returns: ggplot object
```

**Example**:
```r
# Forest plot with custom options
forest <- create_forest_plot(
  ma_results,
  options = list(
    title = "Effect of Treatment on Mortality",
    xlab = "Risk Ratio (95% CI)",
    sort_by = "effect_size",
    show_weights = TRUE,
    color_scheme = "viridis"
  )
)

# Display in Shiny
output$forest_plot <- renderPlotly(forest)
```

---

### Validators (`validators.R`)

**Purpose**: Data validation and quality checks.

**Key Functions**:

```r
validate_columns(data, required_cols)
# Check for required columns
# Returns: validation result

validate_numeric(data, col_names)
# Validate numeric columns
# Returns: validation result with errors

validate_study_ids(data)
# Check for unique study identifiers
# Returns: validation result

check_missing_data(data)
# Identify missing data patterns
# Returns: missing data report
```

**Example**:
```r
# Comprehensive validation
validation <- validate_columns(data, c("study_id", "effect_size", "se"))

if (!validation$valid) {
  showNotification(
    paste("Validation failed:", validation$message),
    type = "error"
  )
  return(NULL)
}

# Check for missing data
missing_report <- check_missing_data(data)
if (missing_report$has_missing) {
  showModal(modalDialog(
    title = "Missing Data Detected",
    HTML(missing_report$html_summary),
    easyClose = TRUE
  ))
}
```

---

## Development Guide

### Adding a New Module

1. **Create module file** in `frontend/modules/`:

```r
# my_feature.R

#' My Feature UI
#'
#' @param id Module ID
#' @return Shiny UI
my_feature_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header("My Feature"),
      card_body(
        # UI elements
        textInput(ns("input1"), "Input 1"),
        actionButton(ns("run"), "Run Analysis"),
        plotlyOutput(ns("plot1"))
      )
    )
  )
}

#' My Feature Server
#'
#' @param id Module ID
#' @param data Reactive data
#' @return Reactive results
my_feature_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    # Server logic

    results <- eventReactive(input$run, {
      # Perform analysis
      req(data())

      # Your code here
      analyze_data(data())
    })

    output$plot1 <- renderPlotly({
      req(results())
      create_plot(results())
    })

    return(results)
  })
}
```

2. **Source module in app.R**:

```r
source("modules/my_feature.R")
```

3. **Add to UI**:

```r
nav_panel(
  title = "My Feature",
  icon = icon("chart-bar"),
  my_feature_ui("my_feature")
)
```

4. **Add to server**:

```r
my_feature_results <- my_feature_server("my_feature", imported_data)
```

---

### Best Practices

#### 1. Module Design

- **Single Responsibility**: Each module should have one clear purpose
- **Namespacing**: Always use `NS(id)` for IDs
- **Reactive Programming**: Use reactive expressions for efficiency
- **Error Handling**: Always validate inputs and handle errors gracefully

#### 2. Performance Optimization

```r
# Cache expensive computations
results <- reactive({
  # Use caching
  cache_key <- digest::digest(input$params)
  cached <- cache_get(cache_key)

  if (!is.null(cached)) {
    return(cached)
  }

  # Expensive computation
  new_results <- expensive_analysis()
  cache_set(cache_key, new_results)

  new_results
})

# Use req() to prevent unnecessary computation
output$plot <- renderPlot({
  req(data(), input$variable)
  plot_data(data(), input$variable)
})
```

#### 3. User Experience

- **Progress Indicators**: Use `withProgress()` for long operations
- **Input Validation**: Validate immediately with `shinyvalidate`
- **Helpful Messages**: Provide clear error messages and guidance
- **Responsive Design**: Ensure UI works on different screen sizes

#### 4. Code Organization

```r
# Group related reactive expressions
data_processing <- reactiveValues(
  raw = NULL,
  cleaned = NULL,
  transformed = NULL
)

# Use modules for complex features
# Use utility functions for common operations
# Document functions with roxygen2 comments
```

---

## Troubleshooting

### Common Issues

#### 1. Module Not Responding

**Problem**: Module server function not executing

**Solution**:
```r
# Ensure module is sourced
source("modules/my_module.R")

# Check ID consistency
my_module_ui("my_id")  # In UI
my_module_server("my_id", data)  # In server - must match!

# Verify reactive dependencies
observe({
  print(paste("Data rows:", nrow(data())))  # Debug reactive
})
```

#### 2. Python API Connection Errors

**Problem**: Cannot connect to Python backend

**Solution**:
```r
# Check API is running
api_status <- tryCatch(
  httr::GET("http://localhost:8000/health"),
  error = function(e) NULL
)

if (is.null(api_status)) {
  showNotification(
    "Python API is not running. Please start it first.",
    type = "error",
    duration = NULL
  )
}

# Set correct API URL in config
Sys.setenv(API_BASE_URL = "http://localhost:8000")
```

#### 3. Performance Issues

**Problem**: Application is slow

**Solutions**:
```r
# 1. Profile your code
profvis::profvis({
  # Your slow code
  slow_function()
})

# 2. Use caching aggressively
# 3. Limit reactive invalidation
data_cached <- reactive({
  data()  # Only invalidates when data changes
}) %>% bindCache(input$data_version)

# 4. Use async processing for long operations
future::plan(multisession)
results <- future({
  long_computation()
})
```

---

## API Integration

### Calling Python Backend

All Python API calls should use the utility functions:

```r
# Example: Validate data
validation_response <- validate_data_python(my_data)

if (validation_response$is_valid) {
  # Proceed
} else {
  # Show errors
  lapply(validation_response$problems, function(problem) {
    showNotification(problem$message, type = "warning")
  })
}

# Example: Transform data
transformed <- transform_data_python(
  data = my_data,
  transformation = "effect_size",
  params = list(outcome_type = "continuous")
)
```

---

## Testing

### Unit Testing R Modules

```r
library(testthat)

test_that("my_feature validates input correctly", {
  # Test with valid data
  valid_data <- data.frame(
    study_id = c("S1", "S2"),
    effect_size = c(0.5, 0.8)
  )

  result <- validate_input(valid_data)
  expect_true(result$valid)

  # Test with invalid data
  invalid_data <- data.frame(
    wrong_col = c(1, 2)
  )

  result <- validate_input(invalid_data)
  expect_false(result$valid)
})
```

---

## Additional Resources

- [Shiny Documentation](https://shiny.rstudio.com/)
- [metafor Package](https://wviechtb.github.io/metafor/)
- [netmeta Package](https://github.com/guido-s/netmeta)
- [BCEA Package](https://sites.google.com/site/bceaweb/)
- [EvidenceOS Wiki](https://github.com/yourusername/evidenceos/wiki)

---

## Support

For questions or issues:
- GitHub Issues: [github.com/yourusername/evidenceos/issues](https://github.com/yourusername/evidenceos/issues)
- Documentation: See `docs/` directory
- Email: support@evidenceos.com
