# Health Economics BCEA Module
# Cost-effectiveness analysis using BCEA package
library(shiny)

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

    return(reactive(bcea_results()))
  })
}

run_bcea_analysis <- function(model_results, params) {
  # Simplified BCEA analysis
  # In production, would use BCEA package with PSA samples

  icer <- model_results$icer

  # Simulate PSA (simplified)
  n_sim <- params$n_iterations
  inc_costs_sim <- rnorm(n_sim, model_results$inc_costs, model_results$inc_costs * 0.2)
  inc_qalys_sim <- rnorm(n_sim, model_results$inc_qalys, model_results$inc_qalys * 0.15)

  # CEAC calculation
  wtp_range <- seq(0, 50000, by = 1000)
  prob_ce <- sapply(wtp_range, function(wtp) {
    nmb <- inc_qalys_sim * wtp - inc_costs_sim
    mean(nmb > 0)
  })

  # EVPI calculation (simplified)
  evpi <- sapply(wtp_range, function(wtp) {
    nmb <- inc_qalys_sim * wtp - inc_costs_sim
    max(mean(nmb), 0) - mean(pmax(nmb, 0))
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
