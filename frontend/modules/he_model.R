# Health Economics Model Module - FIXED: Now uses MA results
library(shiny)

he_model_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Markov Model: 3-State (Stable → Progressed → Dead)"),
      layout_columns(
        col_widths = c(4, 8),
        card(
          h5("MA Results Integration"),
          selectInput(ns("ma_outcome_progression"), "Use MA for Progression HR",
                      choices = NULL),
          selectInput(ns("ma_outcome_death"), "Use MA for Death HR",
                      choices = NULL),
          hr(),
          helpText("Select meta-analysis results to use for transition probabilities."),
          helpText("If no MA selected, uses parameters from HE Parameters tab."),
          hr(),
          h5("Baseline Probabilities"),
          numericInput(ns("base_prog"), "Annual P(Progression)", 0.15, min = 0, max = 1, step = 0.01),
          numericInput(ns("base_death"), "Annual P(Death from Progressed)", 0.25, min = 0, max = 1, step = 0.01),
          hr(),
          actionButton(ns("btn_run"), "Run Model", class = "btn-primary btn-lg w-100")
        ),
        card(
          uiOutput(ns("ma_summary")),
          navset_card_tab(
            nav_panel("Deterministic", verbatimTextOutput(ns("det_results"))),
            nav_panel("Trace", plotOutput(ns("trace_plot"))),
            nav_panel("Parameters Used", verbatimTextOutput(ns("params_used")))
          )
        )
      )
    )
  )
}

he_model_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    model_results <- reactiveVal(NULL)

    # Update MA outcome choices when available
    observe({
      req(rv$pairwise_results)
      outcomes <- names(rv$pairwise_results)
      updateSelectInput(session, "ma_outcome_progression",
                        choices = c("Use manual parameters" = "", outcomes),
                        selected = "")
      updateSelectInput(session, "ma_outcome_death",
                        choices = c("Use manual parameters" = "", outcomes),
                        selected = "")
    })

    # Show MA results being used
    output$ma_summary <- renderUI({
      ma_prog <- input$ma_outcome_progression
      ma_death <- input$ma_outcome_death

      if (ma_prog == "" && ma_death == "") {
        div(
          class = "alert alert-info",
          icon("info-circle"),
          " Using manual HR parameters from HE Parameters tab"
        )
      } else {
        tagList(
          if (ma_prog != "") {
            ma_res <- rv$pairwise_results[[ma_prog]]
            div(
              class = "alert alert-success",
              icon("link"),
              sprintf(" Progression HR from MA '%s': %.3f (%.3f to %.3f)",
                      ma_prog, exp(ma_res$pooled_effect),
                      exp(ma_res$ci_lower), exp(ma_res$ci_upper))
            )
          },
          if (ma_death != "") {
            ma_res <- rv$pairwise_results[[ma_death]]
            div(
              class = "alert alert-success",
              icon("link"),
              sprintf(" Death HR from MA '%s': %.3f (%.3f to %.3f)",
                      ma_death, exp(ma_res$pooled_effect),
                      exp(ma_res$ci_lower), exp(ma_res$ci_upper))
            )
          }
        )
      }
    })

    observeEvent(input$btn_run, {
      req(rv$he_params)

      withProgress(message = "Running Markov model with MA results...", {
        tryCatch({
          # Extract HRs from MA if selected
          hr_progression <- if (input$ma_outcome_progression != "") {
            ma_res <- rv$pairwise_results[[input$ma_outcome_progression]]
            list(
              hr = exp(ma_res$pooled_effect),
              ci_lower = exp(ma_res$ci_lower),
              ci_upper = exp(ma_res$ci_upper),
              se_log = ma_res$se,
              source = paste("MA:", input$ma_outcome_progression)
            )
          } else {
            list(
              hr = rv$he_params$hr_progression,
              ci_lower = NA,
              ci_upper = NA,
              se_log = 0.15,  # Assumed if not from MA
              source = "Manual parameter"
            )
          }

          hr_death <- if (input$ma_outcome_death != "") {
            ma_res <- rv$pairwise_results[[input$ma_outcome_death]]
            list(
              hr = exp(ma_res$pooled_effect),
              ci_lower = exp(ma_res$ci_lower),
              ci_upper = exp(ma_res$ci_upper),
              se_log = ma_res$se,
              source = paste("MA:", input$ma_outcome_death)
            )
          } else {
            list(
              hr = rv$he_params$hr_death,
              ci_lower = NA,
              ci_upper = NA,
              se_log = 0.15,
              source = "Manual parameter"
            )
          }

          results <- run_markov_model(
            rv$he_params,
            input$base_prog,
            input$base_death,
            hr_progression,
            hr_death
          )

          model_results(results)
          rv$he_model_results <- results
          showNotification("✓ Markov model complete", type = "message")
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
      cat(sprintf("  ICER: £%.2f per QALY\n\n", res$icer))

      if (res$inc_qalys > 0 && res$inc_costs > 0) {
        wtp <- rv$he_params$wtp_threshold
        if (res$icer < wtp) {
          cat(sprintf("✓ Cost-effective at £%.0f WTP threshold\n", wtp))
        } else {
          cat(sprintf("✗ Not cost-effective at £%.0f WTP threshold\n", wtp))
        }
      }
    })

    output$trace_plot <- renderPlot({
      req(model_results())
      res <- model_results()

      par(mfrow = c(1, 2))

      # Comparator trace
      matplot(0:nrow(res$trace_comparator), res$trace_comparator,
              type = "l", lwd = 2, lty = 1,
              col = c("steelblue", "orange", "red"),
              xlab = "Year", ylab = "Proportion in State",
              main = "Markov Trace: Comparator",
              ylim = c(0, 1))
      legend("right", legend = c("Stable", "Progressed", "Dead"),
             col = c("steelblue", "orange", "red"), lty = 1, lwd = 2)
      grid()

      # Treatment trace
      matplot(0:nrow(res$trace_treatment), res$trace_treatment,
              type = "l", lwd = 2, lty = 1,
              col = c("steelblue", "orange", "red"),
              xlab = "Year", ylab = "Proportion in State",
              main = "Markov Trace: Treatment",
              ylim = c(0, 1))
      legend("right", legend = c("Stable", "Progressed", "Dead"),
             col = c("steelblue", "orange", "red"), lty = 1, lwd = 2)
      grid()
    })

    output$params_used <- renderPrint({
      req(model_results())
      res <- model_results()

      cat("PARAMETERS USED IN MODEL\n")
      cat("========================\n\n")

      cat("Source of HRs:\n")
      cat(sprintf("  Progression HR: %s\n", res$hr_progression$source))
      cat(sprintf("    HR = %.3f", res$hr_progression$hr))
      if (!is.na(res$hr_progression$ci_lower)) {
        cat(sprintf(" (95%% CI: %.3f to %.3f)", res$hr_progression$ci_lower, res$hr_progression$ci_upper))
      }
      cat("\n")

      cat(sprintf("  Death HR: %s\n", res$hr_death$source))
      cat(sprintf("    HR = %.3f", res$hr_death$hr))
      if (!is.na(res$hr_death$ci_lower)) {
        cat(sprintf(" (95%% CI: %.3f to %.3f)", res$hr_death$ci_lower, res$hr_death$ci_upper))
      }
      cat("\n\n")

      cat("Baseline Transition Probabilities (Comparator):\n")
      cat(sprintf("  Annual P(Stable → Progressed) = %.4f\n", res$base_prob_prog))
      cat(sprintf("  Annual P(Progressed → Dead) = %.4f\n\n", res$base_prob_death))

      cat("Treatment Transition Probabilities:\n")
      cat(sprintf("  Annual P(Stable → Progressed) = %.4f (%.1f%% reduction)\n",
                  res$base_prob_prog * res$hr_progression$hr,
                  100 * (1 - res$hr_progression$hr)))
      cat(sprintf("  Annual P(Progressed → Dead) = %.4f (%.1f%% reduction)\n\n",
                  res$base_prob_death * res$hr_death$hr,
                  100 * (1 - res$hr_death$hr)))

      cat("Utilities:\n")
      cat(sprintf("  Stable: %.2f\n", res$params$utility_stable))
      cat(sprintf("  Progressed: %.2f\n", res$params$utility_progressed))
      cat(sprintf("  Dead: %.2f\n\n", res$params$utility_dead))

      cat("Annual Costs:\n")
      cat(sprintf("  Stable state: £%.2f\n", res$params$cost_stable))
      cat(sprintf("  Progressed state: £%.2f\n", res$params$cost_progressed))
      cat(sprintf("  Treatment drug cost: £%.2f\n", res$params$cost_treatment))
      cat(sprintf("  Comparator drug cost: £%.2f\n\n", res$params$cost_comparator))

      cat("Model Settings:\n")
      cat(sprintf("  Time horizon: %d years\n", res$params$time_horizon))
      cat(sprintf("  Discount rate: %.1f%%\n", res$params$discount_rate * 100))
    })

    return(reactive(model_results()))
  })
}

run_markov_model <- function(params, base_prob_prog, base_prob_death,
                               hr_progression, hr_death) {
  # 3-state Markov model with MA-derived HRs
  horizon <- params$time_horizon
  discount <- params$discount_rate

  # Apply HRs to baseline probabilities
  p_stable_prog_comp <- base_prob_prog
  p_prog_dead_comp <- base_prob_death
  p_stable_dead <- 0.02  # Background mortality

  p_stable_prog_trt <- p_stable_prog_comp * hr_progression$hr
  p_prog_dead_trt <- p_prog_dead_comp * hr_death$hr

  # Trace for comparator
  trace_comp <- matrix(0, nrow = horizon + 1, ncol = 3)
  colnames(trace_comp) <- c("Stable", "Progressed", "Dead")
  trace_comp[1, ] <- c(1, 0, 0)

  for (t in 1:horizon) {
    stable_t <- trace_comp[t, 1]
    prog_t <- trace_comp[t, 2]
    dead_t <- trace_comp[t, 3]

    trace_comp[t + 1, 1] <- stable_t * (1 - p_stable_prog_comp - p_stable_dead)
    trace_comp[t + 1, 2] <- stable_t * p_stable_prog_comp + prog_t * (1 - p_prog_dead_comp)
    trace_comp[t + 1, 3] <- stable_t * p_stable_dead + prog_t * p_prog_dead_comp + dead_t
  }

  # Trace for treatment
  trace_trt <- matrix(0, nrow = horizon + 1, ncol = 3)
  colnames(trace_trt) <- c("Stable", "Progressed", "Dead")
  trace_trt[1, ] <- c(1, 0, 0)

  for (t in 1:horizon) {
    stable_t <- trace_trt[t, 1]
    prog_t <- trace_trt[t, 2]
    dead_t <- trace_trt[t, 3]

    trace_trt[t + 1, 1] <- stable_t * (1 - p_stable_prog_trt - p_stable_dead)
    trace_trt[t + 1, 2] <- stable_t * p_stable_prog_trt + prog_t * (1 - p_prog_dead_trt)
    trace_trt[t + 1, 3] <- stable_t * p_stable_dead + prog_t * p_prog_dead_trt + dead_t
  }

  # Calculate QALYs and Costs with discounting
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
    trace_comparator = trace_comp,
    hr_progression = hr_progression,
    hr_death = hr_death,
    base_prob_prog = base_prob_prog,
    base_prob_death = base_prob_death,
    params = params
  )
}
