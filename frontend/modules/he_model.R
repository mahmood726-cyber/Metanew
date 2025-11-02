# Health Economics Model Module - Markov Model
library(shiny)

he_model_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Markov Model: 3-State (Stable → Progressed → Dead)"),
      actionButton(ns("btn_run"), "Run Model", class = "btn-primary btn-lg"),
      hr(),
      navset_card_tab(
        nav_panel("Deterministic", verbatimTextOutput(ns("det_results"))),
        nav_panel("PSA", plotOutput(ns("psa_plot"))),
        nav_panel("Trace", plotOutput(ns("trace_plot")))
      )
    )
  )
}

he_model_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    model_results <- reactiveVal(NULL)

    observeEvent(input$btn_run, {
      req(rv$he_params)

      withProgress(message = "Running Markov model...", {
        tryCatch({
          results <- run_markov_model(rv$he_params)
          model_results(results)
          rv$he_model_results <- results
          showNotification("✓ Model complete", type = "message")
        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    output$det_results <- renderPrint({
      req(model_results())
      res <- model_results()

      cat("DETERMINISTIC RESULTS\n")
      cat("=====================\n\n")
      cat("Treatment:\n")
      cat(sprintf("  Total QALYs: %.3f\n", res$qalys_treatment))
      cat(sprintf("  Total Costs: £%.2f\n", res$costs_treatment))
      cat("\nComparator:\n")
      cat(sprintf("  Total QALYs: %.3f\n", res$qalys_comparator))
      cat(sprintf("  Total Costs: £%.2f\n", res$costs_comparator))
      cat("\nIncremental:\n")
      cat(sprintf("  ΔQALYs: %.3f\n", res$inc_qalys))
      cat(sprintf("  ΔCosts: £%.2f\n", res$inc_costs))
      cat(sprintf("  ICER: £%.2f per QALY\n", res$icer))
    })

    return(reactive(model_results()))
  })
}

run_markov_model <- function(params) {
  # Simple 3-state Markov model simulation
  horizon <- params$time_horizon
  discount <- params$discount_rate

  # Transition probabilities (annual, simplified)
  p_stable_prog <- 0.1
  p_prog_dead <- 0.2
  p_stable_dead <- 0.05

  # Apply HRs for treatment
  p_stable_prog_trt <- p_stable_prog * params$hr_progression
  p_prog_dead_trt <- p_prog_dead * params$hr_death

  # Trace for comparator
  trace_comp <- matrix(0, nrow = horizon + 1, ncol = 3)
  colnames(trace_comp) <- c("Stable", "Progressed", "Dead")
  trace_comp[1, ] <- c(1, 0, 0)  # All start stable

  for (t in 1:horizon) {
    trace_comp[t + 1, 1] <- trace_comp[t, 1] * (1 - p_stable_prog - p_stable_dead)
    trace_comp[t + 1, 2] <- trace_comp[t, 1] * p_stable_prog + trace_comp[t, 2] * (1 - p_prog_dead)
    trace_comp[t + 1, 3] <- trace_comp[t, 1] * p_stable_dead + trace_comp[t, 2] * p_prog_dead + trace_comp[t, 3]
  }

  # Trace for treatment
  trace_trt <- matrix(0, nrow = horizon + 1, ncol = 3)
  colnames(trace_trt) <- c("Stable", "Progressed", "Dead")
  trace_trt[1, ] <- c(1, 0, 0)

  for (t in 1:horizon) {
    trace_trt[t + 1, 1] <- trace_trt[t, 1] * (1 - p_stable_prog_trt - p_stable_dead)
    trace_trt[t + 1, 2] <- trace_trt[t, 1] * p_stable_prog_trt + trace_trt[t, 2] * (1 - p_prog_dead_trt)
    trace_trt[t + 1, 3] <- trace_trt[t, 1] * p_stable_dead + trace_trt[t, 2] * p_prog_dead_trt + trace_trt[t, 3]
  }

  # Calculate QALYs and Costs
  discount_vec <- (1 / (1 + discount))^(0:horizon)

  qalys_comp <- sum(
    (trace_comp[, 1] * params$utility_stable +
       trace_comp[, 2] * params$utility_progressed) * discount_vec
  )
  qalys_trt <- sum(
    (trace_trt[, 1] * params$utility_stable +
       trace_trt[, 2] * params$utility_progressed) * discount_vec
  )

  costs_comp <- sum(
    (trace_comp[, 1] * params$cost_stable +
       trace_comp[, 2] * params$cost_progressed) * discount_vec
  ) + params$cost_comparator

  costs_trt <- sum(
    (trace_trt[, 1] * params$cost_stable +
       trace_trt[, 2] * params$cost_progressed) * discount_vec
  ) + params$cost_treatment

  inc_qalys <- qalys_trt - qalys_comp
  inc_costs <- costs_trt - costs_comp
  icer <- inc_costs / inc_qalys

  list(
    qalys_treatment = qalys_trt,
    qalys_comparator = qalys_comp,
    costs_treatment = costs_trt,
    costs_comparator = costs_comp,
    inc_qalys = inc_qalys,
    inc_costs = inc_costs,
    icer = icer,
    trace_treatment = trace_trt,
    trace_comparator = trace_comp
  )
}
