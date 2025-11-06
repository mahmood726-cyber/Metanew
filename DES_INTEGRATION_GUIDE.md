# DES Integration Guide for R Shiny

Complete guide for integrating Discrete Event Simulation into R Shiny applications.

---

## 📦 Quick Start

### 1. Installation

```r
# Required packages
install.packages(c(
  "R6",          # Object-oriented programming
  "httr",        # HTTP requests
  "jsonlite",    # JSON parsing
  "shiny",       # Shiny framework
  "shinydashboard", # Dashboard UI
  "plotly",      # Interactive plots
  "DT",          # Data tables
  "ggplot2"      # Static plots
))
```

### 2. Load DES Client

```r
# Source the DES API client
source("frontend/R/des_api_client.R")
source("frontend/R/shiny_modules_des.R")
```

### 3. Create Authenticated Client

```r
# Create client with authentication
client <- create_des_client(
  base_url = "http://localhost:8000",
  username = "admin",
  password = "your-password"
)

# Or without authentication (if API allows)
client <- DESClient$new(base_url = "http://localhost:8000")
```

---

## 🚀 Method 1: Pre-built Shiny Modules (Fastest)

### Complete Example App

```r
library(shiny)
library(shinydashboard)
library(plotly)
library(DT)

# Source DES modules
source("frontend/R/des_api_client.R")
source("frontend/R/shiny_modules_des.R")

ui <- dashboardPage(
  dashboardHeader(title = "DES Application"),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Simulation", tabName = "simulation", icon = icon("play")),
      menuItem("Results", tabName = "results", icon = icon("chart-bar")),
      menuItem("PSA", tabName = "psa", icon = icon("dice"))
    )
  ),

  dashboardBody(
    tabItems(
      # Simulation tab
      tabItem(
        tabName = "simulation",
        desSimulationUI("des_sim")
      ),

      # Results tab
      tabItem(
        tabName = "results",
        desResultsUI("des_results")
      ),

      # PSA tab
      tabItem(
        tabName = "psa",
        desPSAUI("des_psa")
      )
    )
  )
)

server <- function(input, output, session) {
  # Create API client
  api_client <- reactive({
    create_des_client(
      base_url = "http://localhost:8000",
      username = Sys.getenv("API_USERNAME"),
      password = Sys.getenv("API_PASSWORD")
    )
  })

  # Simulation module
  sim_results <- desSimulationServer("des_sim", api_client)

  # Results module
  desResultsServer("des_results", sim_results)

  # PSA module
  desPSAServer("des_psa", sim_results)
}

shinyApp(ui, server)
```

**Run the app:**
```r
# Set credentials (or use .Renviron file)
Sys.setenv(API_USERNAME = "admin")
Sys.setenv(API_PASSWORD = "your-password")

# Run app
shiny::runApp("path/to/app.R")
```

---

## 🛠️ Method 2: Custom Integration

### Basic Workflow

```r
library(shiny)
source("frontend/R/des_api_client.R")

ui <- fluidPage(
  titlePanel("Custom DES Integration"),

  sidebarLayout(
    sidebarPanel(
      h3("Simulation Setup"),

      numericInput("n_patients", "Number of Patients", value = 1000),
      numericInput("time_horizon", "Time Horizon (years)", value = 10),
      numericInput("discount_rate", "Discount Rate (%)", value = 3.5),

      actionButton("run", "Run Simulation", class = "btn-primary")
    ),

    mainPanel(
      h3("Results"),
      verbatimTextOutput("results_summary"),
      plotOutput("state_occupancy")
    )
  )
)

server <- function(input, output, session) {
  # Create client
  client <- create_des_client(
    base_url = "http://localhost:8000",
    username = "admin",
    password = "password"
  )

  # Run simulation
  results <- eventReactive(input$run, {
    withProgress(message = "Running simulation...", {
      # Get example model
      example <- client$get_example_model("3_state_model")

      # Update configuration
      config <- example$config
      config$n_patients <- input$n_patients
      config$time_horizon <- input$time_horizon
      config$discount_rate_costs <- input$discount_rate / 100
      config$discount_rate_qalys <- input$discount_rate / 100

      # Run simulation
      client$run_simulation(example$pathway, config)
    })
  })

  # Display results
  output$results_summary <- renderPrint({
    req(results())

    cat(sprintf("Total Cost: £%s\n", format(results()$total_costs, big.mark = ",")))
    cat(sprintf("Total QALYs: %.2f\n", results()$total_qalys))
    cat(sprintf("Cost per QALY: £%s\n",
                format(round(results()$total_costs / results()$total_qalys),
                       big.mark = ",")))
  })

  # State occupancy plot
  output$state_occupancy <- renderPlot({
    req(results())

    occupancy <- results()$state_occupancy
    df <- data.frame(
      state = names(occupancy),
      proportion = unlist(occupancy)
    )

    barplot(
      df$proportion,
      names.arg = df$state,
      main = "State Occupancy",
      ylab = "Proportion of Time",
      col = "steelblue"
    )
  })
}

shinyApp(ui, server)
```

---

## 📊 Common Use Cases

### 1. Run Simple Simulation

```r
# Get example model
example <- client$get_example_model("3_state_model")

# Run simulation
results <- client$run_simulation(
  pathway = example$pathway,
  config = example$config
)

# View results
print(format_simulation_results(results))
print(format_state_occupancy(results))
```

### 2. Run PSA

```r
# Configure PSA
config <- example$config
config$n_psa_iterations <- 1000

# Run PSA
psa <- client$run_psa(
  pathway = example$pathway,
  config = config
)

# View PSA summary
cat(sprintf("Mean cost: £%s (95%% CI: £%s - £%s)\n",
            format(psa$mean_cost, big.mark = ","),
            format(psa$cost_95ci_lower, big.mark = ","),
            format(psa$cost_95ci_upper, big.mark = ",")))

cat(sprintf("Probability cost-effective: %.1f%%\n",
            psa$probability_cost_effective * 100))
```

### 3. Compare Interventions

```r
# Define pathways
standard_care <- example$pathway

# Create intervention pathway (modify costs/utilities)
intervention <- example$pathway
intervention$pathway_id <- "intervention_a"
intervention$pathway_name <- "Intervention A"
intervention$states[[2]]$cost_per_cycle <- 3000  # Lower cost

# Compare
comparison <- client$compare_interventions(
  pathways = list(standard_care, intervention),
  config = example$config,
  comparator_index = 0
)

# View comparison
print(format_comparison_results(comparison))
```

### 4. Custom Pathway

```r
# Define custom states
states <- list(
  list(
    state_id = "healthy",
    state_name = "Healthy",
    utility = 1.0,
    cost_per_cycle = 200,
    transition_probabilities = list(
      disease = 0.08,
      death = 0.02
    )
  ),
  list(
    state_id = "disease",
    state_name = "Disease",
    utility = 0.6,
    cost_per_cycle = 10000,
    transition_probabilities = list(
      death = 0.15
    )
  ),
  list(
    state_id = "death",
    state_name = "Death",
    utility = 0.0,
    cost_per_cycle = 0,
    absorbing = TRUE
  )
)

# Create pathway
custom_pathway <- list(
  pathway_id = "my_custom_model",
  pathway_name = "My Custom Model",
  states = states,
  initial_state = "healthy",
  time_horizon = 15
)

# Create config
custom_config <- list(
  time_horizon = 15,
  n_patients = 2000,
  discount_rate_costs = 0.035,
  discount_rate_qalys = 0.035,
  willingness_to_pay = 30000
)

# Run simulation
results <- client$run_simulation(custom_pathway, custom_config)
```

---

## 📈 Visualization Examples

### 1. Cost-Effectiveness Plane (PSA)

```r
library(ggplot2)

# Run PSA
psa <- client$run_psa(pathway, config)

# Extract iterations
iterations <- do.call(rbind, psa$iterations)

# Calculate incremental (vs baseline)
baseline <- iterations[1, ]
inc_costs <- iterations$cost - baseline$cost
inc_qalys <- iterations$qalys - baseline$qalys

# Plot
ggplot(data.frame(inc_qalys, inc_costs), aes(x = inc_qalys, y = inc_costs)) +
  geom_point(alpha = 0.5, color = "steelblue") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(
    title = "Cost-Effectiveness Plane",
    x = "Incremental QALYs",
    y = "Incremental Cost (£)"
  ) +
  theme_minimal()
```

### 2. CEAC (Cost-Effectiveness Acceptability Curve)

```r
# Calculate probability cost-effective at different WTP thresholds
wtp_range <- seq(0, 100000, by = 1000)

prob_ce <- sapply(wtp_range, function(wtp) {
  mean(iterations$nmb > 0)
})

# Plot
plot(wtp_range, prob_ce * 100,
     type = "l",
     lwd = 2,
     col = "darkgreen",
     main = "Cost-Effectiveness Acceptability Curve",
     xlab = "Willingness-to-Pay (£/QALY)",
     ylab = "Probability Cost-Effective (%)")
abline(v = 30000, col = "red", lty = 2)  # NICE threshold
legend("bottomright", legend = "NICE threshold (£30k)",
       col = "red", lty = 2)
```

### 3. State Occupancy Over Time

```r
library(plotly)

# Get state occupancy
occupancy <- results$state_occupancy

# Create pie chart
plot_ly(
  labels = names(occupancy),
  values = unlist(occupancy),
  type = "pie",
  textposition = "inside",
  textinfo = "label+percent"
) %>%
  layout(title = "State Occupancy")
```

---

## 🎨 Shiny Module Reference

### desSimulationUI/Server

**Purpose:** Simulation setup and execution

**UI Parameters:**
- `id` - Module namespace ID

**Server Parameters:**
- `id` - Module namespace ID
- `api_client` - Reactive expression returning DES client

**Returns:**
- List with `results` and `psa_results` reactive values

**Example:**
```r
# UI
desSimulationUI("sim_module")

# Server
sim_results <- desSimulationServer("sim_module", api_client)
```

---

### desResultsUI/Server

**Purpose:** Results visualization (value boxes, charts, tables)

**UI Parameters:**
- `id` - Module namespace ID

**Server Parameters:**
- `id` - Module namespace ID
- `sim_results` - Reactive expression with results

**Returns:** None (displays results)

**Example:**
```r
# UI
desResultsUI("results_module")

# Server
desResultsServer("results_module", sim_results)
```

---

### desPSAUI/Server

**Purpose:** PSA visualization (CE plane, CEAC, scatter)

**UI Parameters:**
- `id` - Module namespace ID

**Server Parameters:**
- `id` - Module namespace ID
- `sim_results` - Reactive expression with PSA results

**Returns:** None (displays PSA results)

**Example:**
```r
# UI
desPSAUI("psa_module")

# Server
desPSAServer("psa_module", sim_results)
```

---

### desComparisonUI/Server

**Purpose:** Intervention comparison visualization

**UI Parameters:**
- `id` - Module namespace ID

**Server Parameters:**
- `id` - Module namespace ID
- `comparison_results` - Reactive expression with comparison results

**Returns:** None (displays comparison)

**Example:**
```r
# UI
desComparisonUI("comparison_module")

# Server
desComparisonServer("comparison_module", comparison_results)
```

---

## 🔧 Helper Functions

### format_simulation_results(results)

Formats simulation results as data frame.

**Input:** Results from `run_simulation()`
**Output:** Data frame with metrics

### format_state_occupancy(results)

Formats state occupancy as data frame.

**Input:** Simulation results
**Output:** Data frame with state percentages

### format_comparison_results(comparison)

Formats comparison results as data frame.

**Input:** Results from `compare_interventions()`
**Output:** Data frame with ICERs and decisions

---

## 🎯 Best Practices

### 1. Error Handling

```r
results <- tryCatch({
  client$run_simulation(pathway, config)
}, error = function(e) {
  showNotification(paste("Error:", e$message), type = "error")
  return(NULL)
})

if (is.null(results)) {
  return()  # Exit early
}
```

### 2. Progress Indicators

```r
withProgress(message = "Running simulation...", {
  setProgress(0.3, detail = "Setting up...")

  results <- client$run_simulation(pathway, config)

  setProgress(0.9, detail = "Processing results...")

  # Format results
  formatted <- format_simulation_results(results)

  setProgress(1.0, detail = "Complete!")
})
```

### 3. Reactive Dependencies

```r
# Good - explicit dependencies
results <- eventReactive(input$run_button, {
  req(input$n_patients, input$time_horizon)
  client$run_simulation(pathway, config)
})

# Avoid - implicit dependencies
observe({
  results <- client$run_simulation(pathway, config)  # Runs on every change
})
```

### 4. Caching Results

```r
# Cache expensive simulations
simulation_cache <- reactiveValues(results = NULL)

observeEvent(input$run, {
  # Check if already run with same parameters
  cache_key <- paste(input$n_patients, input$time_horizon, sep = "_")

  if (is.null(simulation_cache$results[[cache_key]])) {
    results <- client$run_simulation(pathway, config)
    simulation_cache$results[[cache_key]] <- results
  }
})
```

### 5. Large PSA Simulations

```r
# Use async for large PSA (requires future/promises)
library(future)
library(promises)

plan(multisession)  # Enable parallel processing

psa_promise <- future({
  client$run_psa(pathway, config)
}) %...>% {
  # This runs when PSA completes
  psa_results(.)
}

# Meanwhile, UI remains responsive
```

---

## 📋 Troubleshooting

### Connection Errors

```r
# Test connection
tryCatch({
  status <- client$get_status()
  message("✓ API connection successful")
}, error = function(e) {
  message("✗ API connection failed: ", e$message)
  message("  Check that backend is running on ", client$base_url)
})
```

### Authentication Issues

```r
# Verify token
if (is.null(client$token)) {
  warning("No authentication token - some endpoints may fail")
}

# Refresh token if expired
# (Implement token refresh logic here)
```

### Memory Issues (Large PSA)

```r
# Limit iterations for testing
config$n_psa_iterations <- 100  # Start small

# Increase gradually
config$n_psa_iterations <- 1000  # Production

# Monitor memory
pryr::mem_used()
```

---

## 🚀 Production Deployment

### 1. Environment Configuration

```r
# Use .Renviron file for credentials
API_BASE_URL=https://api.example.com
API_USERNAME=production_user
API_PASSWORD=secure_password
```

### 2. Security

```r
# Don't hardcode credentials
# Use environment variables
client <- create_des_client(
  base_url = Sys.getenv("API_BASE_URL"),
  username = Sys.getenv("API_USERNAME"),
  password = Sys.getenv("API_PASSWORD")
)
```

### 3. Performance

```r
# Preload example models
example_models <- list(
  three_state = client$get_example_model("3_state_model"),
  cancer = client$get_example_model("5_state_cancer")
)

# Use in app
results <- client$run_simulation(
  example_models$three_state$pathway,
  example_models$three_state$config
)
```

---

## 📚 Additional Resources

- **API Documentation:** See `backend/api/des_routes.py` for endpoint details
- **Example Models:** See `backend/ml/des_examples.py` for model implementations
- **Test Suite:** See `backend/tests/test_des.py` for usage examples

---

## ✅ Quick Checklist

Before deploying your DES integration:

- [ ] API backend running and accessible
- [ ] Authentication working (test with `get_status()`)
- [ ] Required R packages installed
- [ ] DES client and modules sourced
- [ ] Error handling implemented
- [ ] Progress indicators added
- [ ] Results visualization working
- [ ] PSA visualizations (if using)
- [ ] Production credentials in .Renviron
- [ ] Memory usage tested for large simulations

---

**Status:** ✅ R Shiny DES integration complete!
**Version:** 1.0.0
**Date:** 2025-11-06
