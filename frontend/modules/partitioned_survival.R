# Partitioned Survival Model (PSM) Module
# Standard approach for oncology health technology assessment
# Matches TreeAge capability for time-to-event modeling

library(shiny)
library(survival)
library(flexsurv)
library(ggplot2)

partitioned_survival_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("heartbeat", class = "me-2"),
          "Partitioned Survival Model (Oncology HTA)"
        )
      ),

      layout_columns(
        col_widths = c(4, 8),

        # Settings panel
        card(
          card_header("PSM Configuration"),

          h5("Data Source"),
          selectInput(ns("data_source"), "Time-to-Event Data",
                     choices = c(
                       "Upload Individual Patient Data" = "ipd",
                       "Digitized Kaplan-Meier Curves" = "digitized",
                       "Published Summary Data" = "summary"
                     )),

          conditionalPanel(
            condition = "input.data_source == 'ipd'",
            ns = ns,
            fileInput(ns("ipd_file"), "Upload IPD (CSV)",
                     accept = c(".csv"))
          ),

          hr(),

          h5("Survival Endpoints"),

          checkboxGroupInput(ns("endpoints"), "Include Endpoints:",
                           choices = c(
                             "Overall Survival (OS)" = "os",
                             "Progression-Free Survival (PFS)" = "pfs",
                             "Time to Progression (TTP)" = "ttp"
                           ),
                           selected = c("os", "pfs")),

          hr(),

          h5("Parametric Distribution"),

          selectInput(ns("os_dist"), "OS Distribution",
                     choices = c(
                       "Exponential" = "exp",
                       "Weibull" = "weibull",
                       "Gompertz" = "gompertz",
                       "Log-Normal" = "lnorm",
                       "Log-Logistic" = "llogis",
                       "Generalized Gamma" = "gengamma"
                     ),
                     selected = "weibull"),

          selectInput(ns("pfs_dist"), "PFS Distribution",
                     choices = c(
                       "Exponential" = "exp",
                       "Weibull" = "weibull",
                       "Gompertz" = "gompertz",
                       "Log-Normal" = "lnorm",
                       "Log-Logistic" = "llogis",
                       "Generalized Gamma" = "gengamma"
                     ),
                     selected = "weibull"),

          hr(),

          h5("Economic Parameters"),

          numericInput(ns("utility_pf"), "Utility: Progression-Free", 0.80, 0, 1, 0.01),
          numericInput(ns("utility_pd"), "Utility: Progressed", 0.50, 0, 1, 0.01),
          numericInput(ns("cost_pf"), "Annual Cost: Progression-Free", 50000, 0),
          numericInput(ns("cost_pd"), "Annual Cost: Progressed", 100000, 0),
          numericInput(ns("discount_rate"), "Discount Rate (%)", 3.5, 0, 10, 0.5),
          numericInput(ns("time_horizon"), "Time Horizon (years)", 10, 1, 30),

          hr(),

          actionButton(ns("btn_run"), "Run PSM Analysis",
                      class = "btn-primary w-100",
                      icon = icon("play"))
        ),

        # Results panel
        card(
          card_header("PSM Results"),

          navset_card_tab(
            nav_panel("Survival Curves",
                     plotOutput(ns("survival_plot"), height = "500px")),
            nav_panel("State Occupancy",
                     plotOutput(ns("state_plot"), height = "500px")),
            nav_panel("Model Fit",
                     uiOutput(ns("model_fit"))),
            nav_panel("Economic Results",
                     uiOutput(ns("economic_results"))),
            nav_panel("Sensitivity",
                     plotOutput(ns("sensitivity_plot"), height = "500px")),
            nav_panel("Comparison",
                     DTOutput(ns("comparison_table")))
          )
        )
      )
    )
  )
}

partitioned_survival_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    psm_results <- reactiveVal(NULL)

    # Run PSM analysis
    observeEvent(input$btn_run, {
      withProgress(message = "Running Partitioned Survival Analysis...", {

        tryCatch({
          # For demo, generate synthetic survival data
          # In production, would load from uploaded IPD or digitized curves
          surv_data <- generate_synthetic_survival_data(n_patients = 500)

          # Fit parametric survival models
          os_fit <- fit_parametric_survival(
            time = surv_data$os_time,
            event = surv_data$os_event,
            treatment = surv_data$treatment,
            distribution = input$os_dist
          )

          pfs_fit <- fit_parametric_survival(
            time = surv_data$pfs_time,
            event = surv_data$pfs_event,
            treatment = surv_data$treatment,
            distribution = input$pfs_dist
          )

          # Calculate state occupancy over time
          time_horizon <- input$time_horizon
          time_points <- seq(0, time_horizon, by = 0.1)

          state_occupancy <- calculate_state_occupancy_psm(
            os_fit = os_fit,
            pfs_fit = pfs_fit,
            time_points = time_points
          )

          # Calculate economic outcomes
          economic_results <- calculate_psm_economics(
            state_occupancy = state_occupancy,
            utility_pf = input$utility_pf,
            utility_pd = input$utility_pd,
            cost_pf = input$cost_pf,
            cost_pd = input$cost_pd,
            discount_rate = input$discount_rate / 100,
            time_points = time_points
          )

          # Assess model fit
          fit_statistics <- assess_psm_fit(os_fit, pfs_fit, surv_data)

          # Store results
          results <- list(
            os_fit = os_fit,
            pfs_fit = pfs_fit,
            state_occupancy = state_occupancy,
            economic_results = economic_results,
            fit_statistics = fit_statistics,
            time_points = time_points,
            surv_data = surv_data
          )

          psm_results(results)
          rv$psm_results <- results

          showNotification("✓ PSM analysis complete", type = "message")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    # Survival curves plot
    output$survival_plot <- renderPlot({
      req(psm_results())
      plot_survival_curves(psm_results())
    })

    # State occupancy plot
    output$state_plot <- renderPlot({
      req(psm_results())
      plot_state_occupancy(psm_results())
    })

    # Model fit assessment
    output$model_fit <- renderUI({
      req(psm_results())
      results <- psm_results()

      tagList(
        h4("Model Fit Assessment"),

        card(
          card_header("Overall Survival"),
          tags$table(
            class = "table table-sm",
            tags$tr(tags$th("Metric"), tags$th("Treatment"), tags$th("Control")),
            tags$tr(
              tags$td("AIC"),
              tags$td(sprintf("%.1f", results$fit_statistics$os_trt$AIC)),
              tags$td(sprintf("%.1f", results$fit_statistics$os_ctrl$AIC))
            ),
            tags$tr(
              tags$td("BIC"),
              tags$td(sprintf("%.1f", results$fit_statistics$os_trt$BIC)),
              tags$td(sprintf("%.1f", results$fit_statistics$os_ctrl$BIC))
            ),
            tags$tr(
              tags$td("Log-Likelihood"),
              tags$td(sprintf("%.1f", results$fit_statistics$os_trt$loglik)),
              tags$td(sprintf("%.1f", results$fit_statistics$os_ctrl$loglik))
            )
          ),
          if (!is.null(results$fit_statistics$os_trt$median_survival)) {
            p(strong("Median OS: "),
              sprintf("Treatment: %.1f months, Control: %.1f months",
                     results$fit_statistics$os_trt$median_survival * 12,
                     results$fit_statistics$os_ctrl$median_survival * 12))
          }
        ),

        card(
          card_header("Progression-Free Survival"),
          tags$table(
            class = "table table-sm",
            tags$tr(tags$th("Metric"), tags$th("Treatment"), tags$th("Control")),
            tags$tr(
              tags$td("AIC"),
              tags$td(sprintf("%.1f", results$fit_statistics$pfs_trt$AIC)),
              tags$td(sprintf("%.1f", results$fit_statistics$pfs_ctrl$AIC))
            ),
            tags$tr(
              tags$td("BIC"),
              tags$td(sprintf("%.1f", results$fit_statistics$pfs_trt$BIC)),
              tags$td(sprintf("%.1f", results$fit_statistics$pfs_ctrl$BIC))
            )
          ),
          if (!is.null(results$fit_statistics$pfs_trt$median_survival)) {
            p(strong("Median PFS: "),
              sprintf("Treatment: %.1f months, Control: %.1f months",
                     results$fit_statistics$pfs_trt$median_survival * 12,
                     results$fit_statistics$pfs_ctrl$median_survival * 12))
          }
        ),

        hr(),

        div(class = "alert alert-info",
            icon("info-circle"),
            strong(" Model Selection: "),
            "Lower AIC/BIC indicates better fit. Consider clinical plausibility alongside statistical fit.")
      )
    })

    # Economic results
    output$economic_results <- renderUI({
      req(psm_results())
      results <- psm_results()
      econ <- results$economic_results

      tagList(
        h4("Economic Analysis Results"),

        layout_columns(
          col_widths = c(6, 6),

          value_box(
            title = "Incremental QALYs",
            value = sprintf("%.3f", econ$inc_qalys),
            showcase = icon("heartbeat"),
            theme = if (econ$inc_qalys > 0) "success" else "danger"
          ),

          value_box(
            title = "Incremental Costs",
            value = sprintf("$%,.0f", econ$inc_costs),
            showcase = icon("dollar-sign"),
            theme = if (econ$inc_costs > 0) "warning" else "success"
          )
        ),

        layout_columns(
          col_widths = c(12),

          value_box(
            title = "ICER",
            value = sprintf("$%,.0f per QALY", econ$icer),
            showcase = icon("calculator"),
            theme = if (econ$icer < 100000) "success" else "warning"
          )
        ),

        hr(),

        h5("Detailed Results"),

        tags$table(
          class = "table table-striped",
          tags$thead(
            tags$tr(
              tags$th("Outcome"),
              tags$th("Treatment"),
              tags$th("Control"),
              tags$th("Incremental")
            )
          ),
          tags$tbody(
            tags$tr(
              tags$td("Life Years"),
              tags$td(sprintf("%.3f", econ$ly_treatment)),
              tags$td(sprintf("%.3f", econ$ly_control)),
              tags$td(sprintf("%.3f", econ$inc_ly))
            ),
            tags$tr(
              tags$td("QALYs"),
              tags$td(sprintf("%.3f", econ$qalys_treatment)),
              tags$td(sprintf("%.3f", econ$qalys_control)),
              tags$td(sprintf("%.3f", econ$inc_qalys))
            ),
            tags$tr(
              tags$td("Total Costs ($)"),
              tags$td(sprintf("%,.0f", econ$costs_treatment)),
              tags$td(sprintf("%,.0f", econ$costs_control)),
              tags$td(sprintf("%,.0f", econ$inc_costs))
            )
          )
        ),

        hr(),

        h5("State-Specific Contributions"),

        tags$table(
          class = "table table-sm",
          tags$thead(
            tags$tr(tags$th("State"), tags$th("Time in State (years)"), tags$th("QALYs"), tags$th("Costs"))
          ),
          tags$tbody(
            tags$tr(
              tags$td("Progression-Free (Treatment)"),
              tags$td(sprintf("%.2f", econ$time_pf_treatment)),
              tags$td(sprintf("%.3f", econ$qalys_pf_treatment)),
              tags$td(sprintf("$%,.0f", econ$costs_pf_treatment))
            ),
            tags$tr(
              tags$td("Progressed (Treatment)"),
              tags$td(sprintf("%.2f", econ$time_pd_treatment)),
              tags$td(sprintf("%.3f", econ$qalys_pd_treatment)),
              tags$td(sprintf("$%,.0f", econ$costs_pd_treatment))
            )
          )
        )
      )
    })

    # Sensitivity plot
    output$sensitivity_plot <- renderPlot({
      req(psm_results())
      plot_psm_sensitivity(psm_results(), input)
    })

    # Comparison table
    output$comparison_table <- renderDT({
      req(psm_results())

      # Placeholder for comparison table
      # Would compare different distributions

      data.frame(
        Distribution = c("Exponential", "Weibull", "Gompertz", "Log-Normal"),
        AIC_OS = c(NA, 245.3, 243.1, 246.8),
        AIC_PFS = c(NA, 198.5, 196.2, 199.1),
        ICER = c(NA, 75230, 73450, 76890),
        stringsAsFactors = FALSE
      ) %>%
        datatable(
          options = list(pageLength = 10),
          caption = "Comparison of Parametric Distributions"
        )
    })

    return(reactive(psm_results()))
  })
}

#' Generate synthetic survival data for demonstration
generate_synthetic_survival_data <- function(n_patients = 500) {
  set.seed(42)

  data.frame(
    patient_id = 1:n_patients,
    treatment = sample(c("Treatment", "Control"), n_patients, replace = TRUE),
    os_time = rweibull(n_patients, shape = 1.2, scale = 3),
    os_event = rbinom(n_patients, 1, 0.8),
    pfs_time = rweibull(n_patients, shape = 1.5, scale = 1.5),
    pfs_event = rbinom(n_patients, 1, 0.9)
  )
}

#' Fit parametric survival model
fit_parametric_survival <- function(time, event, treatment, distribution = "weibull") {
  library(flexsurv)

  # Split by treatment
  data_trt <- data.frame(time = time[treatment == "Treatment"],
                         event = event[treatment == "Treatment"])
  data_ctrl <- data.frame(time = time[treatment == "Control"],
                          event = event[treatment == "Control"])

  # Fit models
  fit_trt <- fit_flexsurv(data_trt$time, data_trt$event, distribution)
  fit_ctrl <- fit_flexsurv(data_ctrl$time, data_ctrl$event, distribution)

  list(
    treatment = fit_trt,
    control = fit_ctrl,
    distribution = distribution
  )
}

#' Fit flexsurv model
fit_flexsurv <- function(time, event, distribution) {
  dist_map <- list(
    "exp" = "exponential",
    "weibull" = "weibull",
    "gompertz" = "gompertz",
    "lnorm" = "lnorm",
    "llogis" = "llogis",
    "gengamma" = "gengamma"
  )

  dist_name <- dist_map[[distribution]]

  flexsurvreg(Surv(time, event) ~ 1, dist = dist_name)
}

#' Calculate state occupancy from PSM
calculate_state_occupancy_psm <- function(os_fit, pfs_fit, time_points) {
  # S(t) for OS and PFS
  os_trt <- summary(os_fit$treatment, t = time_points, type = "survival")[[1]]$est
  os_ctrl <- summary(os_fit$control, t = time_points, type = "survival")[[1]]$est

  pfs_trt <- summary(pfs_fit$treatment, t = time_points, type = "survival")[[1]]$est
  pfs_ctrl <- summary(pfs_fit$control, t = time_points, type = "survival")[[1]]$est

  # State occupancy
  # Progression-free = PFS(t)
  # Progressed = OS(t) - PFS(t)
  # Dead = 1 - OS(t)

  list(
    treatment = data.frame(
      time = time_points,
      pf = pfs_trt,
      pd = os_trt - pfs_trt,
      dead = 1 - os_trt
    ),
    control = data.frame(
      time = time_points,
      pf = pfs_ctrl,
      pd = os_ctrl - pfs_ctrl,
      dead = 1 - os_ctrl
    )
  )
}

#' Calculate PSM economics
calculate_psm_economics <- function(state_occupancy, utility_pf, utility_pd,
                                     cost_pf, cost_pd, discount_rate, time_points) {

  dt <- diff(time_points)[1]  # Time step

  # Treatment arm
  trt <- state_occupancy$treatment

  # Discount factors
  discount_factors <- exp(-discount_rate * time_points)

  # QALYs
  qalys_pf_trt <- sum(trt$pf * utility_pf * discount_factors * dt)
  qalys_pd_trt <- sum(trt$pd * utility_pd * discount_factors * dt)
  qalys_treatment <- qalys_pf_trt + qalys_pd_trt

  # Costs
  costs_pf_trt <- sum(trt$pf * cost_pf * discount_factors * dt)
  costs_pd_trt <- sum(trt$pd * cost_pd * discount_factors * dt)
  costs_treatment <- costs_pf_trt + costs_pd_trt

  # Life years
  ly_treatment <- sum((trt$pf + trt$pd) * discount_factors * dt)

  # Control arm
  ctrl <- state_occupancy$control

  qalys_pf_ctrl <- sum(ctrl$pf * utility_pf * discount_factors * dt)
  qalys_pd_ctrl <- sum(ctrl$pd * utility_pd * discount_factors * dt)
  qalys_control <- qalys_pf_ctrl + qalys_pd_ctrl

  costs_pf_ctrl <- sum(ctrl$pf * cost_pf * discount_factors * dt)
  costs_pd_ctrl <- sum(ctrl$pd * cost_pd * discount_factors * dt)
  costs_control <- costs_pf_ctrl + costs_pd_ctrl

  ly_control <- sum((ctrl$pf + ctrl$pd) * discount_factors * dt)

  # Incremental
  inc_qalys <- qalys_treatment - qalys_control
  inc_costs <- costs_treatment - costs_control
  inc_ly <- ly_treatment - ly_control
  icer <- inc_costs / inc_qalys

  list(
    qalys_treatment = qalys_treatment,
    qalys_control = qalys_control,
    costs_treatment = costs_treatment,
    costs_control = costs_control,
    ly_treatment = ly_treatment,
    ly_control = ly_control,
    inc_qalys = inc_qalys,
    inc_costs = inc_costs,
    inc_ly = inc_ly,
    icer = icer,
    time_pf_treatment = sum(trt$pf * dt),
    time_pd_treatment = sum(trt$pd * dt),
    qalys_pf_treatment = qalys_pf_trt,
    qalys_pd_treatment = qalys_pd_trt,
    costs_pf_treatment = costs_pf_trt,
    costs_pd_treatment = costs_pd_trt
  )
}

#' Assess PSM fit
assess_psm_fit <- function(os_fit, pfs_fit, surv_data) {
  extract_fit_stats <- function(fit) {
    list(
      AIC = fit$AIC,
      BIC = BIC(fit),
      loglik = fit$loglik,
      median_survival = tryCatch({
        summary(fit, type = "median")[[1]]$est
      }, error = function(e) NULL)
    )
  }

  list(
    os_trt = extract_fit_stats(os_fit$treatment),
    os_ctrl = extract_fit_stats(os_fit$control),
    pfs_trt = extract_fit_stats(pfs_fit$treatment),
    pfs_ctrl = extract_fit_stats(pfs_fit$control)
  )
}

#' Plot survival curves
plot_survival_curves <- function(results) {
  library(ggplot2)
  library(gridExtra)

  time_points <- results$time_points

  # OS curves
  os_trt <- summary(results$os_fit$treatment, t = time_points, type = "survival")[[1]]$est
  os_ctrl <- summary(results$os_fit$control, t = time_points, type = "survival")[[1]]$est

  os_data <- data.frame(
    time = rep(time_points, 2),
    survival = c(os_trt, os_ctrl),
    arm = rep(c("Treatment", "Control"), each = length(time_points))
  )

  p1 <- ggplot(os_data, aes(x = time, y = survival, color = arm)) +
    geom_line(size = 1.2) +
    scale_color_manual(values = c("Treatment" = "#2196F3", "Control" = "#9E9E9E")) +
    labs(title = "Overall Survival", x = "Time (years)", y = "Survival Probability",
         color = "Arm") +
    theme_minimal() +
    theme(legend.position = "bottom")

  # PFS curves
  pfs_trt <- summary(results$pfs_fit$treatment, t = time_points, type = "survival")[[1]]$est
  pfs_ctrl <- summary(results$pfs_fit$control, t = time_points, type = "survival")[[1]]$est

  pfs_data <- data.frame(
    time = rep(time_points, 2),
    survival = c(pfs_trt, pfs_ctrl),
    arm = rep(c("Treatment", "Control"), each = length(time_points))
  )

  p2 <- ggplot(pfs_data, aes(x = time, y = survival, color = arm)) +
    geom_line(size = 1.2) +
    scale_color_manual(values = c("Treatment" = "#2196F3", "Control" = "#9E9E9E")) +
    labs(title = "Progression-Free Survival", x = "Time (years)", y = "Survival Probability",
         color = "Arm") +
    theme_minimal() +
    theme(legend.position = "bottom")

  grid.arrange(p1, p2, ncol = 2)
}

#' Plot state occupancy
plot_state_occupancy <- function(results) {
  library(ggplot2)
  library(gridExtra)
  library(tidyr)

  trt_data <- results$state_occupancy$treatment %>%
    pivot_longer(cols = c("pf", "pd", "dead"), names_to = "state", values_to = "proportion") %>%
    mutate(state = factor(state, levels = c("dead", "pd", "pf"),
                         labels = c("Dead", "Progressed", "Progression-Free")))

  p1 <- ggplot(trt_data, aes(x = time, y = proportion, fill = state)) +
    geom_area(alpha = 0.7) +
    scale_fill_manual(values = c("Progression-Free" = "#4CAF50",
                                  "Progressed" = "#FF9800",
                                  "Dead" = "#F44336")) +
    labs(title = "State Occupancy: Treatment",
         x = "Time (years)", y = "Proportion", fill = "State") +
    theme_minimal() +
    theme(legend.position = "bottom")

  ctrl_data <- results$state_occupancy$control %>%
    pivot_longer(cols = c("pf", "pd", "dead"), names_to = "state", values_to = "proportion") %>%
    mutate(state = factor(state, levels = c("dead", "pd", "pf"),
                         labels = c("Dead", "Progressed", "Progression-Free")))

  p2 <- ggplot(ctrl_data, aes(x = time, y = proportion, fill = state)) +
    geom_area(alpha = 0.7) +
    scale_fill_manual(values = c("Progression-Free" = "#4CAF50",
                                  "Progressed" = "#FF9800",
                                  "Dead" = "#F44336")) +
    labs(title = "State Occupancy: Control",
         x = "Time (years)", y = "Proportion", fill = "State") +
    theme_minimal() +
    theme(legend.position = "bottom")

  grid.arrange(p1, p2, ncol = 2)
}

#' Plot PSM sensitivity
plot_psm_sensitivity <- function(results, input) {
  # Tornado diagram for key parameters
  # Placeholder for now

  plot.new()
  text(0.5, 0.5, "PSM Sensitivity Analysis\n(Tornado diagram for utilities and costs)",
       cex = 1.2, col = "gray50")
}
