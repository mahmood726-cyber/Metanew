"""
Shiny Modules for Discrete Event Simulation

Pre-built Shiny modules for DES visualization and interaction.

Modules:
1. desSimulationUI/Server - Simulation setup and execution
2. desResultsUI/Server - Results visualization
3. desPSAUI/Server - PSA execution and visualization
4. desComparisonUI/Server - Intervention comparison

Usage:
    library(shiny)
    library(shinydashboard)
    library(plotly)
    library(DT)

    # In UI
    desSimulationUI("des_sim")
    desResultsUI("des_results")

    # In Server
    sim_results <- desSimulationServer("des_sim", api_client)
    desResultsServer("des_results", sim_results)
"""

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(ggplot2)


# ==================== MODULE 1: SIMULATION SETUP ====================

#' DES Simulation UI
#'
#' @param id Module ID
#' @export
desSimulationUI <- function(id) {
  ns <- NS(id)

  box(
    title = "Discrete Event Simulation Setup",
    width = 12,
    status = "primary",
    solidHeader = TRUE,

    fluidRow(
      # Left column: Model selection
      column(
        width = 4,
        h4("Model Selection"),
        selectInput(
          ns("model_type"),
          "Pre-built Model",
          choices = c(
            "Simple 3-State" = "3_state_model",
            "5-State Cancer" = "5_state_cancer",
            "HIV Treatment" = "hiv_treatment",
            "Diabetes Complications" = "diabetes_complications",
            "Custom Model" = "custom"
          )
        ),
        conditionalPanel(
          condition = sprintf("input['%s'] == 'custom'", ns("model_type")),
          actionButton(ns("configure_custom"), "Configure Custom Model", icon = icon("cog"))
        )
      ),

      # Middle column: Configuration
      column(
        width = 4,
        h4("Simulation Configuration"),
        numericInput(ns("time_horizon"), "Time Horizon (years)", value = 10, min = 1, max = 100),
        numericInput(ns("n_patients"), "Number of Patients", value = 1000, min = 1, max = 100000),
        sliderInput(ns("discount_rate"), "Discount Rate (%)", value = 3.5, min = 0, max = 10, step = 0.5),
        numericInput(ns("wtp"), "Willingness-to-Pay (£/QALY)", value = 30000, min = 0)
      ),

      # Right column: Actions
      column(
        width = 4,
        h4("Actions"),
        br(),
        actionButton(
          ns("run_sim"),
          "Run Simulation",
          icon = icon("play"),
          class = "btn-primary btn-lg btn-block"
        ),
        br(),
        checkboxInput(ns("run_psa"), "Run PSA (slower)", value = FALSE),
        conditionalPanel(
          condition = sprintf("input['%s']", ns("run_psa")),
          numericInput(ns("n_psa"), "PSA Iterations", value = 1000, min = 10, max = 10000)
        ),
        br(),
        uiOutput(ns("status"))
      )
    )
  )
}


#' DES Simulation Server
#'
#' @param id Module ID
#' @param api_client Reactive expression returning DES API client
#' @export
desSimulationServer <- function(id, api_client) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    results <- reactiveVal(NULL)
    psa_results <- reactiveVal(NULL)

    # Status output
    output$status <- renderUI({
      if (!is.null(results())) {
        tagList(
          icon("check", class = "text-success"),
          span(" Simulation complete", class = "text-success")
        )
      } else {
        tagList(
          icon("info-circle", class = "text-muted"),
          span(" Ready to run", class = "text-muted")
        )
      }
    })

    # Run simulation
    observeEvent(input$run_sim, {
      req(api_client())

      # Show progress
      withProgress(message = "Running simulation...", {

        tryCatch({
          # Get model
          if (input$model_type == "custom") {
            showNotification("Custom models not yet implemented", type = "warning")
            return()
          }

          example <- api_client()$get_example_model(input$model_type)

          # Update config
          config <- example$config
          config$time_horizon <- input$time_horizon
          config$n_patients <- input$n_patients
          config$discount_rate_costs <- input$discount_rate / 100
          config$discount_rate_qalys <- input$discount_rate / 100
          config$willingness_to_pay <- input$wtp

          setProgress(0.3, detail = "Executing simulation...")

          if (input$run_psa) {
            # Run PSA
            config$n_psa_iterations <- input$n_psa
            psa_res <- api_client()$run_psa(example$pathway, config)
            psa_results(psa_res)

            # Also run single simulation for deterministic results
            sim_res <- api_client()$run_simulation(example$pathway, config)
            results(sim_res)

          } else {
            # Run single simulation
            sim_res <- api_client()$run_simulation(example$pathway, config)
            results(sim_res)
            psa_results(NULL)
          }

          setProgress(1.0, detail = "Complete!")

          showNotification("Simulation complete!", type = "success")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    # Return results
    return(list(
      results = results,
      psa_results = psa_results
    ))
  })
}


# ==================== MODULE 2: RESULTS VISUALIZATION ====================

#' DES Results UI
#'
#' @param id Module ID
#' @export
desResultsUI <- function(id) {
  ns <- NS(id)

  box(
    title = "Simulation Results",
    width = 12,
    status = "success",
    solidHeader = TRUE,

    fluidRow(
      # Summary metrics
      column(
        width = 3,
        valueBoxOutput(ns("total_cost"), width = 12)
      ),
      column(
        width = 3,
        valueBoxOutput(ns("total_qalys"), width = 12)
      ),
      column(
        width = 3,
        valueBoxOutput(ns("cost_per_qaly"), width = 12)
      ),
      column(
        width = 3,
        valueBoxOutput(ns("cost_effective"), width = 12)
      )
    ),

    fluidRow(
      # State occupancy chart
      column(
        width = 6,
        h4("State Occupancy"),
        plotlyOutput(ns("state_occupancy_plot"))
      ),

      # Cost breakdown
      column(
        width = 6,
        h4("Cost Breakdown"),
        plotlyOutput(ns("cost_breakdown_plot"))
      )
    ),

    fluidRow(
      # Detailed results table
      column(
        width = 12,
        h4("Detailed Results"),
        DTOutput(ns("results_table"))
      )
    )
  )
}


#' DES Results Server
#'
#' @param id Module ID
#' @param sim_results Reactive expression returning simulation results
#' @export
desResultsServer <- function(id, sim_results) {
  moduleServer(id, function(input, output, session) {

    # Value boxes
    output$total_cost <- renderValueBox({
      req(sim_results()$results())

      valueBox(
        sprintf("£%s", format(sim_results()$results()$total_costs, big.mark = ",")),
        "Total Cost",
        icon = icon("pound-sign"),
        color = "blue"
      )
    })

    output$total_qalys <- renderValueBox({
      req(sim_results()$results())

      valueBox(
        sprintf("%.2f", sim_results()$results()$total_qalys),
        "Total QALYs",
        icon = icon("heart"),
        color = "green"
      )
    })

    output$cost_per_qaly <- renderValueBox({
      req(sim_results()$results())
      res <- sim_results()$results()

      cost_per_qaly <- res$total_costs / res$total_qalys

      valueBox(
        sprintf("£%s", format(round(cost_per_qaly), big.mark = ",")),
        "Cost per QALY",
        icon = icon("calculator"),
        color = "yellow"
      )
    })

    output$cost_effective <- renderValueBox({
      req(sim_results()$results())
      res <- sim_results()$results()

      is_ce <- !is.null(res$cost_effective) && res$cost_effective

      valueBox(
        ifelse(is_ce, "Yes", "—"),
        "Cost-Effective",
        icon = icon(ifelse(is_ce, "check", "question")),
        color = ifelse(is_ce, "green", "gray")
      )
    })

    # State occupancy plot
    output$state_occupancy_plot <- renderPlotly({
      req(sim_results()$results())

      occupancy <- sim_results()$results()$state_occupancy

      plot_ly(
        labels = names(occupancy),
        values = unlist(occupancy),
        type = "pie",
        textposition = "inside",
        textinfo = "label+percent"
      ) %>%
        layout(
          title = "Time Spent in Each State",
          showlegend = TRUE
        )
    })

    # Cost breakdown plot
    output$cost_breakdown_plot <- renderPlotly({
      req(sim_results()$results())

      costs <- sim_results()$results()$costs_by_category

      if (length(costs) == 0) {
        return(plotly_empty())
      }

      plot_ly(
        x = names(costs),
        y = unlist(costs),
        type = "bar",
        marker = list(color = "#3498db")
      ) %>%
        layout(
          title = "Cost Breakdown by Category",
          xaxis = list(title = "Category"),
          yaxis = list(title = "Cost (£)")
        )
    })

    # Results table
    output$results_table <- renderDT({
      req(sim_results()$results())

      format_simulation_results(sim_results()$results())
    }, options = list(dom = 't', paging = FALSE))
  })
}


# ==================== MODULE 3: PSA VISUALIZATION ====================

#' DES PSA UI
#'
#' @param id Module ID
#' @export
desPSAUI <- function(id) {
  ns <- NS(id)

  box(
    title = "Probabilistic Sensitivity Analysis",
    width = 12,
    status = "info",
    solidHeader = TRUE,

    fluidRow(
      # PSA summary metrics
      column(
        width = 4,
        h4("PSA Summary"),
        verbatimTextOutput(ns("psa_summary"))
      ),

      # Cost-effectiveness plane
      column(
        width = 8,
        h4("Cost-Effectiveness Plane"),
        plotlyOutput(ns("ce_plane"))
      )
    ),

    fluidRow(
      # CEAC (Cost-Effectiveness Acceptability Curve)
      column(
        width = 6,
        h4("Cost-Effectiveness Acceptability Curve (CEAC)"),
        plotlyOutput(ns("ceac"))
      ),

      # PSA iterations scatter
      column(
        width = 6,
        h4("PSA Iterations"),
        plotlyOutput(ns("psa_scatter"))
      )
    )
  )
}


#' DES PSA Server
#'
#' @param id Module ID
#' @param sim_results Reactive expression returning simulation results with PSA
#' @export
desPSAServer <- function(id, sim_results) {
  moduleServer(id, function(input, output, session) {

    # PSA summary
    output$psa_summary <- renderText({
      req(sim_results()$psa_results())

      psa <- sim_results()$psa_results()

      sprintf(
        "Iterations: %d\n\nMean Cost: £%s\n95%% CI: £%s - £%s\n\nMean QALYs: %.2f\n95%% CI: %.2f - %.2f\n\nP(Cost-Effective): %.1f%%",
        psa$n_iterations,
        format(psa$mean_cost, big.mark = ","),
        format(psa$cost_95ci_lower, big.mark = ","),
        format(psa$cost_95ci_upper, big.mark = ","),
        psa$mean_qalys,
        psa$qalys_95ci_lower,
        psa$qalys_95ci_upper,
        psa$probability_cost_effective * 100
      )
    })

    # Cost-effectiveness plane
    output$ce_plane <- renderPlotly({
      req(sim_results()$psa_results())

      psa <- sim_results()$psa_results()
      iterations <- do.call(rbind, psa$iterations)

      # Calculate incremental from first iteration as baseline
      baseline <- iterations[1, ]
      inc_costs <- iterations$cost - baseline$cost
      inc_qalys <- iterations$qalys - baseline$qalys

      plot_ly() %>%
        add_markers(
          x = inc_qalys,
          y = inc_costs,
          marker = list(
            color = "#3498db",
            opacity = 0.5
          ),
          name = "Iterations"
        ) %>%
        add_trace(
          x = c(0, 0),
          y = c(min(inc_costs), max(inc_costs)),
          type = "scatter",
          mode = "lines",
          line = list(color = "gray", dash = "dash"),
          showlegend = FALSE
        ) %>%
        add_trace(
          x = c(min(inc_qalys), max(inc_qalys)),
          y = c(0, 0),
          type = "scatter",
          mode = "lines",
          line = list(color = "gray", dash = "dash"),
          showlegend = FALSE
        ) %>%
        layout(
          title = "Cost-Effectiveness Plane",
          xaxis = list(title = "Incremental QALYs"),
          yaxis = list(title = "Incremental Cost (£)")
        )
    })

    # CEAC
    output$ceac <- renderPlotly({
      req(sim_results()$psa_results())

      psa <- sim_results()$psa_results()
      iterations <- do.call(rbind, psa$iterations)

      # Calculate probability cost-effective at different WTP thresholds
      wtp_range <- seq(0, 100000, by = 1000)

      prob_ce <- sapply(wtp_range, function(wtp) {
        mean(iterations$nmb > 0 & (iterations$cost / iterations$qalys) < wtp)
      })

      plot_ly(
        x = wtp_range,
        y = prob_ce * 100,
        type = "scatter",
        mode = "lines",
        line = list(color = "#2ecc71", width = 3)
      ) %>%
        add_trace(
          x = c(30000, 30000),
          y = c(0, 100),
          type = "scatter",
          mode = "lines",
          line = list(color = "red", dash = "dash"),
          name = "NICE threshold (£30k)"
        ) %>%
        layout(
          title = "Cost-Effectiveness Acceptability Curve",
          xaxis = list(title = "Willingness-to-Pay (£/QALY)"),
          yaxis = list(title = "Probability Cost-Effective (%)")
        )
    })

    # PSA scatter
    output$psa_scatter <- renderPlotly({
      req(sim_results()$psa_results())

      psa <- sim_results()$psa_results()
      iterations <- do.call(rbind, psa$iterations)

      plot_ly() %>%
        add_markers(
          x = iterations$qalys,
          y = iterations$cost,
          marker = list(
            color = iterations$nmb,
            colorscale = "RdYlGn",
            showscale = TRUE,
            colorbar = list(title = "NMB")
          ),
          text = sprintf("Iteration: %d<br>Cost: £%s<br>QALYs: %.2f<br>NMB: £%s",
                        seq_len(nrow(iterations)),
                        format(iterations$cost, big.mark = ","),
                        iterations$qalys,
                        format(iterations$nmb, big.mark = ",")),
          hoverinfo = "text"
        ) %>%
        layout(
          title = "PSA Iterations (colored by NMB)",
          xaxis = list(title = "QALYs"),
          yaxis = list(title = "Cost (£)")
        )
    })
  })
}


# ==================== MODULE 4: INTERVENTION COMPARISON ====================

#' DES Comparison UI
#'
#' @param id Module ID
#' @export
desComparisonUI <- function(id) {
  ns <- NS(id)

  box(
    title = "Intervention Comparison",
    width = 12,
    status = "warning",
    solidHeader = TRUE,

    h4("Comparison Results"),
    DTOutput(ns("comparison_table")),

    br(),

    fluidRow(
      column(
        width = 6,
        h4("Cost vs QALYs"),
        plotlyOutput(ns("cost_qaly_plot"))
      ),
      column(
        width = 6,
        h4("Net Monetary Benefit"),
        plotlyOutput(ns("nmb_plot"))
      )
    )
  )
}


#' DES Comparison Server
#'
#' @param id Module ID
#' @param comparison_results Reactive expression returning comparison results
#' @export
desComparisonServer <- function(id, comparison_results) {
  moduleServer(id, function(input, output, session) {

    # Comparison table
    output$comparison_table <- renderDT({
      req(comparison_results())

      format_comparison_results(comparison_results())
    }, options = list(pageLength = 10, dom = 'tp'))

    # Cost vs QALYs plot
    output$cost_qaly_plot <- renderPlotly({
      req(comparison_results())

      comparisons <- comparison_results()$comparisons

      costs <- sapply(comparisons, function(x) x$total_costs)
      qalys <- sapply(comparisons, function(x) x$total_qalys)
      names_vec <- sapply(comparisons, function(x) x$pathway_name)

      plot_ly(
        x = qalys,
        y = costs,
        type = "scatter",
        mode = "markers+text",
        text = names_vec,
        textposition = "top",
        marker = list(size = 15, color = "#e74c3c")
      ) %>%
        layout(
          title = "Cost vs QALYs by Intervention",
          xaxis = list(title = "QALYs"),
          yaxis = list(title = "Cost (£)")
        )
    })

    # NMB plot
    output$nmb_plot <- renderPlotly({
      req(comparison_results())

      comparisons <- comparison_results()$comparisons

      nmbs <- sapply(comparisons, function(x) x$nmb)
      names_vec <- sapply(comparisons, function(x) x$pathway_name)

      colors <- ifelse(nmbs > 0, "#2ecc71", "#e74c3c")

      plot_ly(
        x = names_vec,
        y = nmbs,
        type = "bar",
        marker = list(color = colors)
      ) %>%
        layout(
          title = "Net Monetary Benefit by Intervention",
          xaxis = list(title = "Intervention"),
          yaxis = list(title = "NMB (£)")
        )
    })
  })
}


# Example usage
if (FALSE) {
  library(shiny)
  library(shinydashboard)

  ui <- dashboardPage(
    dashboardHeader(title = "DES Example"),
    dashboardSidebar(),
    dashboardBody(
      fluidRow(
        desSimulationUI("des_sim"),
        desResultsUI("des_results"),
        desPSAUI("des_psa")
      )
    )
  )

  server <- function(input, output, session) {
    # Create API client
    api_client <- reactive({
      create_des_client(
        base_url = "http://localhost:8000",
        username = "admin",
        password = "admin-password"
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
}
