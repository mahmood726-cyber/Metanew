# Partitioned Survival Analysis Module
# For health economic modeling with multiple health states
# Common in oncology HTA (Progression-Free, Progressed, Dead)
# Reference: Latimer (2013) Medical Decision Making; Williams et al. (2017) Value in Health

library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(survival)
library(flexsurv)  # For parametric survival models

#' UI for Partitioned Survival Module
#'
#' @param id Module namespace ID
#' @export
partition_survival_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("⏱️ Partitioned Survival Analysis"),
    p("Economic modeling with partitioned survival for multiple health states"),

    # ⚠️ CRITICAL WARNING - FRAMEWORK ONLY
    card(
      card_body(
        class = "bg-warning text-dark border-danger",
        style = "border-width: 3px;",
        h4(class = "text-danger", "⚠️ FRAMEWORK ONLY - NOT PRODUCTION READY"),
        p(class = "mb-0",
          strong("WARNING:"), " This module is a ",
          strong("framework/prototype with simulated curve fits."),
          " It does NOT perform actual parametric survival modeling with flexsurv. ",
          "Results shown are placeholders and ",
          strong("MUST NOT be used for real analysis, HTA submissions, or decision-making."),
          br(), br(),
          "Full implementation requires flexsurv backend integration for parametric curve fitting (see source code for details)."
        )
      )
    ),

    # Info card
    card(
      card_header("About Partitioned Survival Models"),
      card_body(
        class = "bg-light",
        p(
          "Partitioned survival models divide the patient journey into distinct health states ",
          "(e.g., Progression-Free, Progressed, Dead) and model survival for each partition. ",
          "Commonly used in oncology HTAs for NICE, CADTH, and other agencies."
        ),
        layout_columns(
          col_widths = c(6, 6),
          div(
            h5("✅ Use Cases:"),
            tags$ul(
              tags$li("Oncology health economics"),
              tags$li("Cost-effectiveness modeling"),
              tags$li("Long-term extrapolation"),
              tags$li("Quality-adjusted life years (QALYs)"),
              tags$li("Budget impact with survival states")
            )
          ),
          div(
            h5("🎯 Key Features:"),
            tags$ul(
              tags$li("Multiple parametric curves"),
              tags$li("Goodness-of-fit comparison (AIC, BIC)"),
              tags$li("Long-term extrapolation"),
              tags$li("State membership over time"),
              tags$li("QALY calculation by state")
            )
          )
        )
      )
    ),

    # State definition
    card(
      card_header("Step 1: Define Health States"),
      card_body(
        p("Define the health states for your partitioned survival model"),

        numericInput(ns("n_states"), "Number of Health States:",
                    value = 3, min = 2, max = 5),

        uiOutput(ns("state_definitions")),

        hr(),

        h5("Example: Standard 3-State Oncology Model"),
        tags$ul(
          tags$li("State 1: Progression-Free Survival (PFS)"),
          tags$li("State 2: Progressed Disease (PD)"),
          tags$li("State 3: Dead")
        )
      )
    ),

    # Data import
    card(
      card_header("Step 2: Import Survival Data"),
      card_body(
        p("Upload time-to-event data for each transition"),

        layout_columns(
          col_widths = c(6, 6),

          div(
            h5("Upload PFS Data:"),
            fileInput(ns("pfs_file"), NULL,
                     accept = ".csv",
                     buttonLabel = "Browse PFS..."),
            helpText("Columns: time, event, treatment")
          ),

          div(
            h5("Upload OS Data:"),
            fileInput(ns("os_file"), NULL,
                     accept = ".csv",
                     buttonLabel = "Browse OS..."),
            helpText("Columns: time, event, treatment")
          )
        ),

        conditionalPanel(
          condition = sprintf("output['%s']", ns("data_loaded")),
          ns = ns,

          hr(),

          h5("Data Summary:"),
          verbatimTextOutput(ns("data_summary"))
        )
      )
    ),

    # Curve fitting
    card(
      card_header("Step 3: Fit Parametric Survival Curves"),
      card_body(
        h5("Select Parametric Distributions to Fit:"),
        p("Multiple distributions will be fitted and compared"),

        checkboxGroupInput(ns("distributions"), NULL,
                          choices = c(
                            "Exponential" = "exp",
                            "Weibull" = "weibull",
                            "Log-Normal" = "lnorm",
                            "Log-Logistic" = "llogis",
                            "Gompertz" = "gompertz",
                            "Generalized Gamma" = "gengamma",
                            "Royston-Parmar Splines" = "splines"
                          ),
                          selected = c("exp", "weibull", "lnorm", "llogis")),

        hr(),

        h5("Treatment Groups:"),
        selectInput(ns("treatment_var"), "Treatment Variable:",
                   choices = NULL),

        hr(),

        actionButton(ns("fit_curves"), "Fit Survival Curves",
                    class = "btn-primary btn-lg", icon = icon("chart-line"))
      )
    ),

    # Results tabs
    navset_card_tab(
      id = ns("results_tabs"),

      # Model fit comparison
      nav_panel(
        "Model Fit",
        card_body(
          h4("Parametric Model Comparison"),

          layout_columns(
            col_widths = c(6, 6),

            div(
              h5("PFS Curves:"),
              DTOutput(ns("pfs_fit_table"))
            ),

            div(
              h5("OS Curves:"),
              DTOutput(ns("os_fit_table"))
            )
          ),

          helpText(
            "Lower AIC/BIC indicates better fit. ",
            "Select best-fitting distribution for each endpoint."
          ),

          br(),

          layout_columns(
            col_widths = c(6, 6),

            selectInput(ns("selected_pfs_dist"), "Selected PFS Distribution:",
                       choices = NULL),

            selectInput(ns("selected_os_dist"), "Selected OS Distribution:",
                       choices = NULL)
          )
        )
      ),

      # Survival curves
      nav_panel(
        "Survival Curves",
        card_body(
          h4("Fitted Survival Curves"),

          layout_columns(
            col_widths = c(6, 6),

            div(
              h5("Progression-Free Survival:"),
              plotOutput(ns("pfs_curves"), height = "400px")
            ),

            div(
              h5("Overall Survival:"),
              plotOutput(ns("os_curves"), height = "400px")
            )
          ),

          br(),

          h5("Kaplan-Meier vs Parametric Fit:"),
          plotOutput(ns("km_vs_parametric"), height = "500px")
        )
      ),

      # State membership
      nav_panel(
        "State Membership",
        card_body(
          h4("Partitioned Survival: State Membership Over Time"),

          numericInput(ns("time_horizon"), "Time Horizon (years):",
                      value = 10, min = 1, max = 50),

          actionButton(ns("calculate_states"), "Calculate State Membership",
                      class = "btn-info"),

          br(), br(),

          plotOutput(ns("state_membership_plot"), height = "500px"),

          br(),

          h5("Area Under Curve (Time in Each State):"),
          DTOutput(ns("auc_table"))
        )
      ),

      # Life years & QALYs
      nav_panel(
        "Life Years & QALYs",
        card_body(
          h4("Quality-Adjusted Life Years Calculation"),

          p("Specify utility values for each health state"),

          uiOutput(ns("utility_inputs")),

          hr(),

          h5("Discount Rate:"),
          numericInput(ns("discount_rate"), "Annual Discount Rate (%):",
                      value = 3.5, min = 0, max = 10, step = 0.5),

          br(),

          actionButton(ns("calculate_qalys"), "Calculate QALYs",
                      class = "btn-success"),

          br(), br(),

          layout_columns(
            col_widths = c(6, 6),

            card(
              card_header("Life Years"),
              card_body(
                DTOutput(ns("life_years_table"))
              )
            ),

            card(
              card_header("QALYs"),
              card_body(
                DTOutput(ns("qalys_table"))
              )
            )
          ),

          br(),

          plotOutput(ns("qaly_breakdown"), height = "400px")
        )
      ),

      # Extrapolation validation
      nav_panel(
        "Extrapolation",
        card_body(
          h4("Long-Term Extrapolation Assessment"),

          p("Assess the plausibility of long-term survival extrapolation"),

          layout_columns(
            col_widths = c(6, 6),

            div(
              h5("External Validation Data (Optional):"),
              fileInput(ns("validation_file"), "Upload Registry/External Data:",
                       accept = ".csv"),
              helpText("For comparison with long-term extrapolation")
            ),

            div(
              h5("Clinical Plausibility Checks:"),
              numericInput(ns("expected_median_pfs"), "Expected Median PFS (months):",
                          value = 12, min = 1),
              numericInput(ns("expected_5yr_os"), "Expected 5-Year OS (%):",
                          value = 30, min = 0, max = 100)
            )
          ),

          br(),

          h5("Extrapolated Survival at Key Time Points:"),
          DTOutput(ns("extrapolation_table")),

          br(),

          h5("Comparison with Clinical Expectations:"),
          plotOutput(ns("plausibility_plot"), height = "400px")
        )
      ),

      # Sensitivity analysis
      nav_panel(
        "Sensitivity",
        card_body(
          h4("Sensitivity Analysis on Curve Selection"),

          p("Compare outcomes across different parametric distributions"),

          plotOutput(ns("sensitivity_tornado"), height = "500px"),

          br(),

          h5("QALY Range by Distribution Choice:"),
          DTOutput(ns("sensitivity_table"))
        )
      )
    ),

    # Export
    hr(),
    card(
      card_header("Export Results"),
      card_body(
        layout_columns(
          col_widths = c(4, 4, 4),
          downloadButton(ns("download_curves"), "Download Fitted Curves"),
          downloadButton(ns("download_qalys"), "Download QALY Estimates"),
          downloadButton(ns("download_report"), "Generate HTA Report")
        )
      )
    )
  )
}


#' Server Logic for Partitioned Survival Module
#'
#' @param id Module namespace ID
#' @param rv Reactive values from parent
#' @export
partition_survival_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    pfs_data <- reactiveVal(NULL)
    os_data <- reactiveVal(NULL)
    fitted_models <- reactiveVal(NULL)
    state_membership <- reactiveVal(NULL)
    qaly_results <- reactiveVal(NULL)

    # Dynamic state definitions
    output$state_definitions <- renderUI({
      n <- input$n_states

      lapply(1:n, function(i) {
        textInput(
          session$ns(paste0("state_", i)),
          paste("State", i, "Name:"),
          value = switch(i,
                        "1" = "Progression-Free",
                        "2" = "Progressed",
                        "3" = "Dead",
                        paste("State", i))
        )
      })
    })


    # Load PFS data
    observeEvent(input$pfs_file, {
      req(input$pfs_file)

      tryCatch({
        data <- read.csv(input$pfs_file$datapath)
        pfs_data(data)

        updateSelectInput(session, "treatment_var", choices = names(data))

        showNotification("PFS data loaded", type = "message")
      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error")
      })
    })


    # Load OS data
    observeEvent(input$os_file, {
      req(input$os_file)

      tryCatch({
        data <- read.csv(input$os_file$datapath)
        os_data(data)

        showNotification("OS data loaded", type = "message")
      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error")
      })
    })


    # Data loaded indicator
    output$data_loaded <- reactive({
      !is.null(pfs_data()) && !is.null(os_data())
    })
    outputOptions(output, "data_loaded", suspendWhenHidden = FALSE)


    # Data summary
    output$data_summary <- renderPrint({
      req(pfs_data(), os_data())

      cat("=== SURVIVAL DATA SUMMARY ===\n\n")

      cat("PFS DATA:\n")
      cat("  Patients:", nrow(pfs_data()), "\n")
      cat("  Events:", sum(pfs_data()$event), "\n")
      cat("  Median follow-up:", round(median(pfs_data()$time), 1), "months\n\n")

      cat("OS DATA:\n")
      cat("  Patients:", nrow(os_data()), "\n")
      cat("  Events:", sum(os_data()$event), "\n")
      cat("  Median follow-up:", round(median(os_data()$time), 1), "months\n")
    })


    # Fit parametric curves
    observeEvent(input$fit_curves, {
      req(pfs_data(), os_data())
      req(input$distributions)

      withProgress(message = "Fitting survival curves...", value = 0, {

        incProgress(0.3, detail = "Fitting PFS curves...")

        pfs_fits <- fit_parametric_curves(
          data = pfs_data(),
          distributions = input$distributions,
          treatment_var = input$treatment_var
        )

        incProgress(0.6, detail = "Fitting OS curves...")

        os_fits <- fit_parametric_curves(
          data = os_data(),
          distributions = input$distributions,
          treatment_var = input$treatment_var
        )

        incProgress(0.9, detail = "Finalizing...")

        fitted_models(list(
          pfs = pfs_fits,
          os = os_fits
        ))

        # Update distribution choices
        dist_names <- names(pfs_fits$fit_statistics)
        updateSelectInput(session, "selected_pfs_dist", choices = dist_names, selected = dist_names[1])
        updateSelectInput(session, "selected_os_dist", choices = dist_names, selected = dist_names[1])

        showNotification("Curve fitting complete!", type = "message")
      })
    })


    # PFS fit table
    output$pfs_fit_table <- renderDT({
      req(fitted_models())

      fits <- fitted_models()$pfs$fit_statistics

      datatable(
        fits,
        options = list(pageLength = 10),
        rownames = FALSE
      ) %>%
        formatRound(columns = c("AIC", "BIC"), digits = 2)
    })


    # OS fit table
    output$os_fit_table <- renderDT({
      req(fitted_models())

      fits <- fitted_models()$os$fit_statistics

      datatable(
        fits,
        options = list(pageLength = 10),
        rownames = FALSE
      ) %>%
        formatRound(columns = c("AIC", "BIC"), digits = 2)
    })


    # PFS curves plot
    output$pfs_curves <- renderPlot({
      req(fitted_models())

      fits <- fitted_models()$pfs

      # TODO: Plot fitted curves
      plot(1, 1, type = "n",
           xlim = c(0, max(pfs_data()$time)),
           ylim = c(0, 1),
           xlab = "Time (months)",
           ylab = "Progression-Free Survival",
           main = "PFS Parametric Curves")

      # Placeholder
      text(mean(par("usr")[1:2]), 0.5,
           "PFS curves visualization\n(Multiple distributions)", cex = 1.2)
    })


    # OS curves plot
    output$os_curves <- renderPlot({
      req(fitted_models())

      fits <- fitted_models()$os

      plot(1, 1, type = "n",
           xlim = c(0, max(os_data()$time)),
           ylim = c(0, 1),
           xlab = "Time (months)",
           ylab = "Overall Survival",
           main = "OS Parametric Curves")

      text(mean(par("usr")[1:2]), 0.5,
           "OS curves visualization\n(Multiple distributions)", cex = 1.2)
    })


    # Utility inputs
    output$utility_inputs <- renderUI({
      n <- input$n_states

      lapply(1:(n-1), function(i) {  # Exclude "Dead" state
        state_name <- input[[paste0("state_", i)]]
        numericInput(
          session$ns(paste0("utility_", i)),
          paste("Utility for", state_name, ":"),
          value = switch(i, "1" = 0.80, "2" = 0.60, 0.50),
          min = 0, max = 1, step = 0.01
        )
      })
    })


    # Calculate state membership
    observeEvent(input$calculate_states, {
      req(fitted_models())
      req(input$selected_pfs_dist, input$selected_os_dist)

      # TODO: Calculate area under curves for each state
      # Placeholder
      state_membership(data.frame(
        Time = seq(0, input$time_horizon, by = 0.1),
        PFS = runif(input$time_horizon * 10 + 1, 0.3, 0.7),
        Progressed = runif(input$time_horizon * 10 + 1, 0.2, 0.4),
        Dead = runif(input$time_horizon * 10 + 1, 0.1, 0.3)
      ))

      showNotification("State membership calculated", type = "message")
    })


    # State membership plot
    output$state_membership_plot <- renderPlot({
      req(state_membership())

      states <- state_membership()

      # Placeholder stacked area chart
      plot(states$Time, states$PFS, type = "l", col = "darkgreen", lwd = 2,
           ylim = c(0, 1), xlab = "Time (years)", ylab = "Proportion in State",
           main = "Partitioned Survival: State Membership Over Time")

      polygon(c(states$Time, rev(states$Time)),
              c(rep(0, nrow(states)), rev(states$PFS)),
              col = rgb(0, 0.5, 0, 0.3), border = NA)

      legend("topright",
             legend = c("Progression-Free", "Progressed", "Dead"),
             fill = c("darkgreen", "orange", "red"),
             bty = "n")
    })

  })
}


# ============================================================================
# Helper Functions
# ============================================================================

#' Fit Multiple Parametric Survival Curves
#'
#' @keywords internal
fit_parametric_curves <- function(data, distributions, treatment_var = NULL) {

  # TODO: Actual curve fitting using flexsurv
  # This is a placeholder that returns simulated fit statistics

  fit_stats <- data.frame(
    Distribution = distributions,
    AIC = runif(length(distributions), 500, 700),
    BIC = runif(length(distributions), 510, 720),
    stringsAsFactors = FALSE
  )

  # Sort by AIC (best first)
  fit_stats <- fit_stats[order(fit_stats$AIC), ]

  list(
    fit_statistics = fit_stats,
    models = list()  # Would store fitted flexsurv objects
  )
}
