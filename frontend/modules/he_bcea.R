# Health Economics BCEA Module
# Cost-effectiveness analysis using BCEA package
library(shiny)
library(mgcv)  # For GAM-based EVPPI
library(DT)

he_bcea_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Cost-Effectiveness Analysis (BCEA)"),
      layout_columns(
        col_widths = c(12),
        value_box(
          title = "ICER",
          value = textOutput(ns("icer_value")),
          showcase = icon("pound-sign"),
          theme = "primary"
        )
      ),
      navset_card_tab(
        nav_panel("CE Plane", plotOutput(ns("ce_plane"))),
        nav_panel("CEAC", plotOutput(ns("ceac"))),
        nav_panel("EVPI", plotOutput(ns("evpi"))),
        nav_panel("EVPPI",
          layout_columns(
            col_widths = c(4, 8),
            card(
              card_header("EVPPI Settings"),
              selectInput(ns("evppi_param"), "Parameter of Interest",
                         choices = c(
                           "HR Progression" = "hr_progression",
                           "HR Death" = "hr_death",
                           "Utility (Stable)" = "utility_stable",
                           "Utility (Progressed)" = "utility_progressed",
                           "Cost (Stable)" = "cost_stable",
                           "Cost (Progressed)" = "cost_progressed",
                           "Cost (Treatment)" = "cost_treatment",
                           "Discount Rate" = "discount_rate"
                         )),
              numericInput(ns("evppi_wtp"), "WTP Threshold (£)",
                          value = 20000, min = 0, max = 100000, step = 1000),
              actionButton(ns("btn_calc_evppi"), "Calculate EVPPI",
                          class = "btn-primary w-100",
                          icon = icon("calculator"))
            ),
            card(
              card_header("EVPPI Results"),
              plotOutput(ns("evppi_plot"), height = "400px"),
              verbatimTextOutput(ns("evppi_summary")),
              DTOutput(ns("evppi_table"))
            )
          )
        ),
        nav_panel("Summary", verbatimTextOutput(ns("summary")))
      )
    )
  )
}

he_bcea_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    bcea_results <- reactive({
      req(rv$he_model_results)
      run_bcea_analysis(rv$he_model_results, rv$he_params)
    })

    output$icer_value <- renderText({
      req(bcea_results())
      sprintf("£%.0f per QALY", bcea_results()$icer)
    })

    output$ce_plane <- renderPlot({
      req(bcea_results())
      plot_ce_plane(bcea_results())
    })

    output$ceac <- renderPlot({
      req(bcea_results())
      plot_ceac(bcea_results())
    })

    output$evpi <- renderPlot({
      req(bcea_results())
      plot_evpi(bcea_results())
    })

    output$summary <- renderPrint({
      req(bcea_results())
      cat("COST-EFFECTIVENESS SUMMARY\n")
      cat("==========================\n\n")
      res <- bcea_results()
      cat(sprintf("ICER: £%.2f per QALY\n", res$icer))
      cat(sprintf("Probability cost-effective at £20k: %.1f%%\n",
                  res$prob_cost_effective * 100))
    })

    # EVPPI Calculation
    evppi_results <- reactiveVal(NULL)

    observeEvent(input$btn_calc_evppi, {
      req(bcea_results(), rv$he_model_results)

      tryCatch({
        # Get PSA results
        bcea <- bcea_results()

        # Extract parameter samples from model results
        if (!is.null(rv$he_model_results$psa_results)) {
          param_samples <- rv$he_model_results$psa_results$param_samples
        } else {
          showNotification("PSA results not available. Please run model with PSA enabled.",
                          type = "warning", duration = 5)
          return(NULL)
        }

        # Calculate EVPPI using GAM regression method
        evppi_res <- calculate_evppi_gam(
          param_samples = param_samples,
          inc_costs = bcea$inc_costs_sim,
          inc_qalys = bcea$inc_qalys_sim,
          parameter = input$evppi_param,
          wtp = input$evppi_wtp
        )

        evppi_results(evppi_res)

        showNotification("EVPPI calculation complete!", type = "message", duration = 3)

      }, error = function(e) {
        showNotification(paste("Error calculating EVPPI:", e$message),
                        type = "error", duration = 10)
      })
    })

    output$evppi_plot <- renderPlot({
      req(evppi_results())

      evppi_res <- evppi_results()

      par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))

      # Plot 1: EVPPI vs parameter values
      plot(evppi_res$param_values, evppi_res$conditional_nmb,
           xlab = evppi_res$param_name,
           ylab = "Expected NMB (£)",
           main = "Conditional NMB",
           pch = 16, col = rgb(0, 0, 1, 0.3))
      lines(evppi_res$fitted$param_grid, evppi_res$fitted$predicted_nmb,
            col = "red", lwd = 2)
      grid()

      # Plot 2: EVPPI bar chart
      barplot(c(evppi_res$evppi, bcea_results()$evpi$evpi[bcea_results()$wtp_range == input$evppi_wtp]),
              names.arg = c("EVPPI", "EVPI"),
              col = c("steelblue", "darkgreen"),
              main = "Value of Information",
              ylab = "Value (£ per patient)",
              ylim = c(0, max(evppi_res$evppi, bcea_results()$evpi$evpi) * 1.2))
      grid()
    })

    output$evppi_summary <- renderPrint({
      req(evppi_results())

      evppi_res <- evppi_results()
      bcea <- bcea_results()

      cat("========================================\n")
      cat("EVPPI ANALYSIS SUMMARY\n")
      cat("========================================\n\n")

      cat(sprintf("Parameter: %s\n", evppi_res$param_name))
      cat(sprintf("WTP Threshold: £%s\n", format(input$evppi_wtp, big.mark = ",")))
      cat("\n")

      cat(sprintf("EVPPI (per patient): £%.2f\n", evppi_res$evppi))
      evpi_value <- bcea$evpi$evpi[bcea$wtp_range == input$evppi_wtp]
      cat(sprintf("EVPI (per patient): £%.2f\n", evpi_value))
      cat(sprintf("EVPPI as %% of EVPI: %.1f%%\n",
                 (evppi_res$evppi / evpi_value) * 100))

      cat("\n")
      cat("Population EVPPI (5-year horizon, 10,000 patients/year):\n")
      pop_evppi <- evppi_res$evppi * 10000 * 5
      cat(sprintf("  Total: £%.2f million\n", pop_evppi / 1e6))

      cat("\n")
      cat("INTERPRETATION:\n")
      if (evppi_res$evppi > 1000) {
        cat("HIGH priority for further research\n")
      } else if (evppi_res$evppi > 100) {
        cat("MEDIUM priority for further research\n")
      } else {
        cat("LOW priority for further research\n")
      }

      cat("\n")
      cat("Model Fit Statistics:\n")
      cat(sprintf("  R-squared: %.3f\n", evppi_res$fitted$r_squared))
      cat(sprintf("  Explained deviance: %.1f%%\n", evppi_res$fitted$dev_explained * 100))
    })

    output$evppi_table <- renderDT({
      req(evppi_results())

      evppi_res <- evppi_results()

      # Create summary table
      df <- data.frame(
        Metric = c("EVPPI (per patient)", "EVPI (per patient)",
                  "EVPPI as % of EVPI", "Population EVPPI (5yr, 10k/yr)",
                  "Research Priority"),
        Value = c(
          paste0("£", format(round(evppi_res$evppi, 2), big.mark = ",")),
          paste0("£", format(round(bcea_results()$evpi$evpi[
            bcea_results()$wtp_range == input$evppi_wtp], 2), big.mark = ",")),
          paste0(round((evppi_res$evppi / bcea_results()$evpi$evpi[
            bcea_results()$wtp_range == input$evppi_wtp]) * 100, 1), "%"),
          paste0("£", format(round(evppi_res$evppi * 10000 * 5 / 1e6, 2), big.mark = ","), "M"),
          if (evppi_res$evppi > 1000) "HIGH" else if (evppi_res$evppi > 100) "MEDIUM" else "LOW"
        )
      )

      datatable(
        df,
        options = list(dom = 't', pageLength = 10),
        rownames = FALSE,
        caption = paste("EVPPI for", evppi_res$param_name)
      )
    })

    return(reactive(bcea_results()))
  })
}

run_bcea_analysis <- function(model_results, params) {
  # BCEA analysis with PSA using MA confidence intervals
  # If MA results were used, we have proper SE from meta-analysis

  icer <- model_results$icer

  # Simulate PSA
  n_sim <- params$n_iterations

  # For costs: use coefficient of variation approach
  # If we have specific cost SE from model, use it; otherwise assume 20% CV
  cost_se <- if (!is.null(model_results$inc_costs_se)) {
    model_results$inc_costs_se
  } else {
    abs(model_results$inc_costs * 0.2)
  }

  # For QALYs: extract SE from MA if available
  # The model results may contain se_qalys from MA-derived HRs
  qaly_se <- if (!is.null(model_results$inc_qalys_se)) {
    model_results$inc_qalys_se
  } else {
    # Fallback: use approximate SE from QALY estimate
    abs(model_results$inc_qalys * 0.15)
  }

  # Use PSA results from model if available (preferred - uses MA SEs properly)
  # Otherwise, sample costs and QALYs using approximate SEs
  if (!is.null(model_results$psa_results)) {
    # Use pre-computed PSA from Markov model (includes MA uncertainty)
    inc_costs_sim <- model_results$psa_results$inc_costs_sim
    inc_qalys_sim <- model_results$psa_results$inc_qalys_sim
    n_sim <- model_results$psa_results$n_sim
  } else {
    # Fallback: sample independently
    inc_costs_sim <- rnorm(n_sim, model_results$inc_costs, cost_se)
    inc_qalys_sim <- rnorm(n_sim, model_results$inc_qalys, qaly_se)
  }

  # CEAC calculation
  wtp_range <- seq(0, 50000, by = 1000)
  prob_ce <- sapply(wtp_range, function(wtp) {
    nmb <- inc_qalys_sim * wtp - inc_costs_sim
    mean(nmb > 0)
  })

  # EVPI calculation (FIXED: correct formula)
  # EVPI = E[max(NMB)] - max(E[NMB])
  # Expected value with perfect information minus expected value with current information
  evpi <- sapply(wtp_range, function(wtp) {
    nmb <- inc_qalys_sim * wtp - inc_costs_sim
    # Expected value with perfect information (average of best decision in each iteration)
    expected_with_perfect_info <- mean(pmax(nmb, 0))
    # Expected value with current information (best expected decision)
    expected_with_current_info <- max(mean(nmb), 0)
    # EVPI per patient
    expected_with_perfect_info - expected_with_current_info
  })

  list(
    icer = icer,
    inc_costs = model_results$inc_costs,
    inc_qalys = model_results$inc_qalys,
    inc_costs_sim = inc_costs_sim,
    inc_qalys_sim = inc_qalys_sim,
    wtp_range = wtp_range,
    prob_cost_effective = prob_ce[wtp_range == params$wtp_threshold],
    ceac = data.frame(wtp = wtp_range, prob = prob_ce),
    evpi = data.frame(wtp = wtp_range, evpi = abs(evpi))
  )
}

plot_ce_plane <- function(bcea) {
  plot(bcea$inc_qalys_sim, bcea$inc_costs_sim,
       xlab = "Incremental QALYs", ylab = "Incremental Costs (£)",
       main = "Cost-Effectiveness Plane",
       pch = 16, col = rgb(0, 0, 1, 0.3))
  abline(h = 0, v = 0, lty = 2)
  abline(a = 0, b = 20000, col = "red", lwd = 2)  # WTP threshold
  points(bcea$inc_qalys, bcea$inc_costs, pch = 18, col = "red", cex = 2)
}

plot_ceac <- function(bcea) {
  plot(bcea$ceac$wtp, bcea$ceac$prob,
       type = "l", lwd = 2, col = "steelblue",
       xlab = "Willingness-to-Pay (£)", ylab = "Probability Cost-Effective",
       main = "Cost-Effectiveness Acceptability Curve")
  abline(h = 0.5, lty = 2, col = "gray")
  grid()
}

plot_evpi <- function(bcea) {
  plot(bcea$evpi$wtp, bcea$evpi$evpi,
       type = "l", lwd = 2, col = "darkgreen",
       xlab = "Willingness-to-Pay (£)", ylab = "EVPI (£)",
       main = "Expected Value of Perfect Information")
  grid()
}

# ============================================================================
# EVPPI CALCULATION USING GAM REGRESSION METHOD
# ============================================================================

calculate_evppi_gam <- function(param_samples, inc_costs, inc_qalys,
                                 parameter, wtp) {
  #' Calculate EVPPI using Generalized Additive Model regression
  #'
  #' This implements the efficient GAM-based method for EVPPI calculation
  #' as described in Strong et al. (2014) and implemented in BCEA package
  #'
  #' @param param_samples List of parameter samples from PSA
  #' @param inc_costs Vector of incremental costs from PSA
  #' @param inc_qalys Vector of incremental QALYs from PSA
  #' @param parameter Name of parameter to calculate EVPPI for
  #' @param wtp Willingness-to-pay threshold
  #'
  #' @return List containing EVPPI value and related statistics

  # Extract parameter of interest from samples
  if (!parameter %in% names(param_samples)) {
    stop(paste("Parameter", parameter, "not found in PSA results"))
  }

  param_values <- param_samples[[parameter]]
  n_sim <- length(param_values)

  # Calculate NMB for each simulation
  nmb <- inc_qalys * wtp - inc_costs

  # Create data frame for GAM
  gam_data <- data.frame(
    param = param_values,
    nmb = nmb
  )

  # Fit GAM model: NMB ~ s(parameter)
  # Use adaptive smoothing with cross-validation
  tryCatch({
    gam_fit <- gam(nmb ~ s(param, bs = "cr"), data = gam_data, method = "REML")
  }, error = function(e) {
    # Fallback to simpler model if GAM fails
    gam_fit <- gam(nmb ~ param, data = gam_data)
  })

  # Predict conditional NMB for each parameter value
  predicted_nmb <- predict(gam_fit, newdata = gam_data)

  # EVPPI calculation
  # EVPPI = E_theta[max(E_phi|theta[NMB], 0)] - max(E[NMB], 0)
  # Where theta is the parameter of interest, phi is all other parameters

  # Expected value with perfect information about this parameter
  expected_with_partial_info <- mean(pmax(predicted_nmb, 0))

  # Expected value with current information
  expected_with_current_info <- max(mean(nmb), 0)

  # EVPPI
  evppi <- expected_with_partial_info - expected_with_current_info

  # Ensure non-negative (can be slightly negative due to numerical error)
  evppi <- max(evppi, 0)

  # Model fit statistics
  r_squared <- summary(gam_fit)$r.sq
  dev_explained <- summary(gam_fit)$dev.expl

  # Create prediction grid for plotting
  param_grid <- seq(min(param_values), max(param_values), length.out = 100)
  predicted_grid <- predict(gam_fit, newdata = data.frame(param = param_grid))

  # Parameter name mapping
  param_name_map <- list(
    hr_progression = "HR (Progression)",
    hr_death = "HR (Death)",
    utility_stable = "Utility (Stable)",
    utility_progressed = "Utility (Progressed)",
    cost_stable = "Cost (Stable)",
    cost_progressed = "Cost (Progressed)",
    cost_treatment = "Cost (Treatment)",
    discount_rate = "Discount Rate"
  )

  param_name <- if (parameter %in% names(param_name_map)) {
    param_name_map[[parameter]]
  } else {
    parameter
  }

  # Return results
  list(
    evppi = evppi,
    param_name = param_name,
    param_values = param_values,
    conditional_nmb = nmb,
    fitted = list(
      param_grid = param_grid,
      predicted_nmb = predicted_grid,
      r_squared = r_squared,
      dev_explained = dev_explained,
      gam_model = gam_fit
    ),
    wtp = wtp,
    expected_with_partial_info = expected_with_partial_info,
    expected_with_current_info = expected_with_current_info
  )
}

# ============================================================================
# MULTI-PARAMETER EVPPI (SIMULTANEOUS)
# ============================================================================

calculate_multi_param_evppi <- function(param_samples, inc_costs, inc_qalys,
                                         parameters, wtp) {
  #' Calculate EVPPI for multiple parameters simultaneously
  #'
  #' @param parameters Vector of parameter names
  #' @return Data frame with EVPPI for each parameter

  results <- lapply(parameters, function(param) {
    tryCatch({
      res <- calculate_evppi_gam(param_samples, inc_costs, inc_qalys, param, wtp)
      data.frame(
        Parameter = res$param_name,
        EVPPI = res$evppi,
        R_squared = res$fitted$r_squared,
        Dev_Explained = res$fitted$dev_explained * 100,
        Priority = if (res$evppi > 1000) "HIGH" else if (res$evppi > 100) "MEDIUM" else "LOW",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      data.frame(
        Parameter = param,
        EVPPI = NA,
        R_squared = NA,
        Dev_Explained = NA,
        Priority = "ERROR",
        stringsAsFactors = FALSE
      )
    })
  })

  do.call(rbind, results)
}
