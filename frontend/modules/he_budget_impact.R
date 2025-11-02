# Budget Impact Analysis Module
library(shiny)

he_budget_impact_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(
      card_header("Budget Impact Analysis"),
      layout_columns(
        col_widths = c(4, 8),
        card(
          h5("Population & Uptake"),
          numericInput(ns("population"), "Eligible Population", 10000, min = 1),
          numericInput(ns("horizon"), "Time Horizon (years)", 5, min = 1, max = 10),
          hr(),
          h5("Uptake Scenarios"),
          sliderInput(ns("uptake_year1"), "Year 1 Uptake (%)", 0, 100, 10, step = 5),
          sliderInput(ns("uptake_year5"), "Year 5 Uptake (%)", 0, 100, 50, step = 5),
          hr(),
          numericInput(ns("cost_per_patient"), "Annual Cost per Patient (Treatment)", 10000, min = 0),
          numericInput(ns("cost_comparator"), "Annual Cost per Patient (Comparator)", 2000, min = 0),
          hr(),
          actionButton(ns("btn_run"), "Run Budget Impact Analysis", class = "btn-primary w-100")
        ),
        card(
          navset_card_tab(
            nav_panel("Budget Impact", plotOutput(ns("bia_plot"))),
            nav_panel("Summary Table", DTOutput(ns("bia_table"))),
            nav_panel("Tornado", plotOutput(ns("tornado_plot"))),
            nav_panel("Details", verbatimTextOutput(ns("bia_summary")))
          )
        )
      )
    )
  )
}

he_budget_impact_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    bia_result <- reactiveVal(NULL)

    observeEvent(input$btn_run, {
      withProgress(message = "Running budget impact analysis...", {
        tryCatch({
          result <- run_budget_impact(
            population = input$population,
            horizon = input$horizon,
            uptake_year1 = input$uptake_year1 / 100,
            uptake_year5 = input$uptake_year5 / 100,
            cost_treatment = input$cost_per_patient,
            cost_comparator = input$cost_comparator,
            qaly_benefit = if (!is.null(rv$he_model_results)) rv$he_model_results$inc_qalys else 0.5
          )

          bia_result(result)
          rv$bia_results <- result
          showNotification("✓ Budget impact analysis complete", type = "message")
        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    output$bia_plot <- renderPlot({
      req(bia_result())
      result <- bia_result()

      par(mfrow = c(1, 2))

      # Cost plot
      barplot(
        rbind(result$cost_comparator, result$cost_treatment),
        beside = TRUE,
        names.arg = paste("Year", 1:result$horizon),
        col = c("steelblue", "orange"),
        main = "Annual Budget",
        ylab = "Cost (£)",
        legend.text = c("Comparator", "Treatment"),
        args.legend = list(x = "topleft")
      )
      grid()

      # Incremental cost plot
      barplot(
        result$incremental_cost,
        names.arg = paste("Year", 1:result$horizon),
        col = ifelse(result$incremental_cost > 0, "red", "green"),
        main = "Incremental Budget Impact",
        ylab = "Incremental Cost (£)"
      )
      abline(h = 0, lty = 2)
      grid()
    })

    output$bia_table <- renderDT({
      req(bia_result())
      result <- bia_result()

      bia_df <- data.frame(
        Year = 1:result$horizon,
        `Uptake (%)` = round(result$uptake * 100, 1),
        `N Treated` = result$n_treated,
        `Cost Comparator (£)` = format(result$cost_comparator, big.mark = ","),
        `Cost Treatment (£)` = format(result$cost_treatment, big.mark = ","),
        `Incremental Cost (£)` = format(result$incremental_cost, big.mark = ","),
        `Cum. Incremental (£)` = format(cumsum(result$incremental_cost), big.mark = ","),
        check.names = FALSE
      )

      datatable(bia_df, options = list(dom = 't', pageLength = 10))
    })

    output$tornado_plot <- renderPlot({
      req(bia_result())
      result <- bia_result()

      # Tornado diagram for sensitivity
      params <- c("Population", "Uptake Year 5", "Treatment Cost", "Comparator Cost")
      base_values <- c(input$population, input$uptake_year5, input$cost_per_patient, input$cost_comparator)

      # Vary each parameter by ±20%
      low_impact <- numeric(length(params))
      high_impact <- numeric(length(params))

      for (i in 1:length(params)) {
        # Low scenario (-20%)
        test_values_low <- base_values
        test_values_low[i] <- base_values[i] * 0.8
        result_low <- run_budget_impact(
          test_values_low[1], input$horizon, input$uptake_year1/100, test_values_low[2]/100,
          test_values_low[3], test_values_low[4], 0.5
        )
        low_impact[i] <- sum(result_low$incremental_cost)

        # High scenario (+20%)
        test_values_high <- base_values
        test_values_high[i] <- base_values[i] * 1.2
        result_high <- run_budget_impact(
          test_values_high[1], input$horizon, input$uptake_year1/100, test_values_high[2]/100,
          test_values_high[3], test_values_high[4], 0.5
        )
        high_impact[i] <- sum(result_high$incremental_cost)
      }

      # Sort by impact range
      impact_range <- abs(high_impact - low_impact)
      ord <- order(impact_range, decreasing = TRUE)

      par(mar = c(5, 10, 4, 2))
      y_pos <- 1:length(params)

      plot(NULL, xlim = range(c(low_impact, high_impact)), ylim = c(0.5, length(params) + 0.5),
           xlab = "Total 5-Year Budget Impact (£)", ylab = "", yaxt = "n",
           main = "Tornado Diagram: Sensitivity Analysis")

      for (i in 1:length(params)) {
        idx <- ord[i]
        segments(low_impact[idx], i, high_impact[idx], i, lwd = 8, col = "steelblue")
        points(c(low_impact[idx], high_impact[idx]), c(i, i), pch = 19, cex = 1.5, col = "darkblue")
      }

      axis(2, at = y_pos, labels = params[ord], las = 1)
      abline(v = sum(result$incremental_cost), lty = 2, col = "red", lwd = 2)
      legend("topright", legend = c("Base Case", "±20% Range"), lty = c(2, 1),
             lwd = c(2, 8), col = c("red", "steelblue"))
      grid()
    })

    output$bia_summary <- renderPrint({
      req(bia_result())
      result <- bia_result()

      cat("BUDGET IMPACT ANALYSIS SUMMARY\n")
      cat("===============================\n\n")

      cat("Population:\n")
      cat(sprintf("  Eligible population: %s\n", format(input$population, big.mark = ",")))
      cat(sprintf("  Time horizon: %d years\n\n", result$horizon))

      cat("Uptake:\n")
      cat(sprintf("  Year 1: %.1f%%\n", result$uptake[1] * 100))
      cat(sprintf("  Year %d: %.1f%%\n\n", result$horizon, result$uptake[result$horizon] * 100))

      cat("Costs:\n")
      cat(sprintf("  Treatment: £%s per patient per year\n",
                  format(input$cost_per_patient, big.mark = ",")))
      cat(sprintf("  Comparator: £%s per patient per year\n\n",
                  format(input$cost_comparator, big.mark = ",")))

      cat("Total Budget Impact:\n")
      total_inc <- sum(result$incremental_cost)
      cat(sprintf("  5-year cumulative: £%s\n", format(round(total_inc), big.mark = ",")))
      cat(sprintf("  Average per year: £%s\n\n", format(round(total_inc / result$horizon), big.mark = ",")))

      if (total_inc > 0) {
        cat("⚠ Treatment increases budget\n")
      } else {
        cat("✓ Treatment reduces budget (cost-saving)\n")
      }

      if (!is.null(result$qaly_benefit) && result$qaly_benefit > 0) {
        cat(sprintf("\nQALY Gains: %.3f QALYs per patient\n", result$qaly_benefit))
        cat(sprintf("Total QALYs gained: %.0f over %d years\n",
                    result$qaly_benefit * sum(result$n_treated), result$horizon))
      }
    })

    return(reactive(bia_result()))
  })
}

run_budget_impact <- function(population, horizon, uptake_year1, uptake_year5,
                                cost_treatment, cost_comparator, qaly_benefit = 0) {

  # Linear uptake growth
  uptake <- seq(uptake_year1, uptake_year5, length.out = horizon)

  # Number treated each year
  n_treated <- round(population * uptake)
  n_comparator <- population - n_treated

  # Annual costs
  cost_treatment_total <- n_treated * cost_treatment
  cost_comparator_total <- n_comparator * cost_comparator

  # Incremental cost
  incremental_cost <- cost_treatment_total - (population * cost_comparator)

  list(
    horizon = horizon,
    uptake = uptake,
    n_treated = n_treated,
    cost_treatment = cost_treatment_total,
    cost_comparator = rep(population * cost_comparator, horizon),
    incremental_cost = incremental_cost,
    qaly_benefit = qaly_benefit
  )
}
