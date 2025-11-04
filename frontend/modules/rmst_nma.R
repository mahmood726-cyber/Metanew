# ==============================================================================
# RMST NETWORK META-ANALYSIS MODULE
# ==============================================================================
#
# Restricted Mean Survival Time (RMST) Network Meta-Analysis for survival
# outcomes. RMST provides clinically interpretable estimates ("X months gained")
# without requiring proportional hazards assumption.
#
# References:
# - Wei et al. (2015) Alternative Approaches to Estimating Direct and Indirect
#   Treatment Effects in Network Meta-Analysis
# - Royston & Parmar (2013) Restricted mean survival time: an alternative to
#   the hazard ratio for the design and analysis of randomized trials
#
# Version: 4.0.0
# Last Updated: 2025-11-04
# ==============================================================================

# Required packages
library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(DT)
library(netmeta)
library(meta)
library(survRM2)  # For RMST calculations

# ==============================================================================
# UI FUNCTION
# ==============================================================================

rmst_nma_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      class = "bg-primary text-white",
      "RMST Network Meta-Analysis - Clinically Interpretable Survival Analysis"
    ),
    card_body(
      # Information panel
      card(
        card_header("Why RMST?"),
        card_body(
          p("Restricted Mean Survival Time (RMST) offers several advantages over hazard ratios:"),
          tags$ul(
            tags$li(strong("Clinical interpretation:"), "\"Treatment adds 2.8 months of survival\""),
            tags$li(strong("No proportional hazards needed:"), "Works with non-proportional hazards (immunotherapy, late effects)"),
            tags$li(strong("Regulatory preference:"), "FDA and EMA favor RMST for some indications"),
            tags$li(strong("Patient-friendly:"), "Easier to explain to patients and clinicians")
          ),
          p(strong("How it works:"), "RMST is the area under the survival curve up to a specified time horizon (e.g., 24 months).")
        )
      ),

      hr(),

      # Analysis settings
      layout_columns(
        col_widths = c(6, 6),

        # Column 1: Data input
        card(
          card_header("RMST Data Input"),
          card_body(
            radioButtons(
              ns("input_type"),
              "Data Input Method:",
              choices = c(
                "RMST directly reported" = "direct",
                "Reconstruct from KM curves" = "km",
                "Individual patient data" = "ipd"
              ),
              selected = "direct"
            ),

            conditionalPanel(
              condition = "input.input_type == 'direct'",
              ns = ns,
              p("Upload CSV with columns: study, treatment, rmst, se_rmst, n, time_horizon")
            ),

            conditionalPanel(
              condition = "input.input_type == 'km'",
              ns = ns,
              p("Upload digitized Kaplan-Meier curve data"),
              fileInput(ns("km_file"), "Upload KM Data (CSV)", accept = ".csv")
            ),

            conditionalPanel(
              condition = "input.input_type == 'ipd'",
              ns = ns,
              p("Upload individual patient data with time-to-event"),
              fileInput(ns("ipd_file"), "Upload IPD (CSV)", accept = ".csv")
            ),

            numericInput(
              ns("time_horizon"),
              "Time Horizon (months):",
              value = 24,
              min = 1,
              max = 120,
              step = 1
            ),

            selectInput(
              ns("reference_treatment"),
              "Reference Treatment:",
              choices = NULL  # Populated dynamically
            )
          )
        ),

        # Column 2: Network MA settings
        card(
          card_header("Network Meta-Analysis Settings"),
          card_body(
            selectInput(
              ns("nma_method"),
              "NMA Method:",
              choices = c(
                "Random Effects (REML)" = "random",
                "Fixed Effects" = "fixed",
                "Inverse Variance" = "inverse"
              ),
              selected = "random"
            ),

            selectInput(
              ns("sm"),
              "Summary Measure:",
              choices = c(
                "RMST Difference (months)" = "MD",
                "RMST Ratio" = "ROM"
              ),
              selected = "MD"
            ),

            checkboxInput(
              ns("compare_with_hr"),
              "Compare with HR-based NMA",
              value = TRUE
            ),

            hr(),

            actionButton(
              ns("run_rmst_nma"),
              "Run RMST NMA",
              icon = icon("play"),
              class = "btn-primary btn-lg w-100"
            )
          )
        )
      ),

      hr(),

      # Results tabs
      navset_card_tab(
        id = ns("results_tabs"),

        # Tab 1: RMST estimates
        nav_panel(
          "RMST Estimates",
          icon = icon("chart-bar"),

          card(
            card_header("Network Estimates - RMST Differences"),
            card_body(
              p("Positive values indicate longer survival with treatment vs reference."),

              DTOutput(ns("rmst_table")),

              hr(),

              plotlyOutput(ns("rmst_forest"), height = "600px")
            )
          ),

          card(
            card_header("League Table - All Pairwise Comparisons"),
            card_body(
              DTOutput(ns("league_table"))
            )
          )
        ),

        # Tab 2: Rankings
        nav_panel(
          "Treatment Rankings",
          icon = icon("trophy"),

          layout_columns(
            col_widths = c(6, 6),

            card(
              card_header("P-scores (Surface Under Cumulative Ranking)"),
              card_body(
                DTOutput(ns("pscore_table")),

                p(class = "text-muted mt-3",
                  "P-score ranges from 0 (worst) to 1 (best). Higher P-score = better treatment.")
              )
            ),

            card(
              card_header("Rankogram"),
              card_body(
                plotlyOutput(ns("rankogram"), height = "400px")
              )
            )
          ),

          card(
            card_header("Treatment Ranking Summary"),
            card_body(
              plotOutput(ns("ranking_plot"), height = "400px")
            )
          )
        ),

        # Tab 3: Comparison with HR
        nav_panel(
          "RMST vs HR Comparison",
          icon = icon("balance-scale"),

          card(
            card_header("Why Compare RMST and HR?"),
            card_body(
              p("Comparing RMST-based and HR-based network meta-analysis helps assess:"),
              tags$ul(
                tags$li("Concordance of treatment rankings"),
                tags$li("Impact of proportional hazards assumption"),
                tags$li("Clinical vs statistical interpretation differences")
              )
            )
          ),

          card(
            card_header("Ranking Concordance"),
            card_body(
              DTOutput(ns("ranking_comparison")),

              hr(),

              uiOutput(ns("concordance_text"))
            )
          ),

          card(
            card_header("Effect Size Correlation"),
            card_body(
              plotlyOutput(ns("effect_correlation"), height = "400px"),

              uiOutput(ns("correlation_text"))
            )
          )
        ),

        # Tab 4: Clinical interpretation
        nav_panel(
          "Clinical Interpretation",
          icon = icon("user-md"),

          card(
            card_header("RMST Interpretation Guide"),
            card_body(
              uiOutput(ns("rmst_interpretation"))
            )
          ),

          card(
            card_header("Number Needed to Treat (NNT)"),
            card_body(
              p("NNT = 1 / Risk Difference. Estimated from RMST using survival probabilities at time horizon."),

              DTOutput(ns("nnt_table"))
            )
          ),

          card(
            card_header("Clinical Significance"),
            card_body(
              numericInput(
                ns("mcid"),
                "Minimal Clinically Important Difference (months):",
                value = 3,
                min = 0.5,
                max = 12,
                step = 0.5
              ),

              uiOutput(ns("clinical_significance"))
            )
          )
        ),

        # Tab 5: Heterogeneity & Inconsistency
        nav_panel(
          "Heterogeneity",
          icon = icon("project-diagram"),

          card(
            card_header("Heterogeneity Statistics"),
            card_body(
              DTOutput(ns("heterogeneity_table"))
            )
          ),

          card(
            card_header("Network Plot"),
            card_body(
              plotOutput(ns("network_plot"), height = "500px")
            )
          )
        )
      )
    )
  )
}

# ==============================================================================
# SERVER FUNCTION
# ==============================================================================

rmst_nma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    rmst_rv <- reactiveValues(
      rmst_data = NULL,
      rmst_nma = NULL,
      hr_nma = NULL,
      fitted = FALSE
    )

    # ==============================================================================
    # HELPER FUNCTIONS
    # ==============================================================================

    # Extract RMST from Kaplan-Meier curves
    extract_rmst_from_km <- function(km_data, time_horizon) {
      # km_data should have columns: time, survival, n_risk
      # Calculate RMST as area under curve

      tryCatch({
        # Sort by time
        km_data <- km_data[order(km_data$time), ]

        # Restrict to time horizon
        km_data <- km_data[km_data$time <= time_horizon, ]

        # Add point at time_horizon if not present
        if (max(km_data$time) < time_horizon) {
          last_surv <- km_data$survival[nrow(km_data)]
          km_data <- rbind(
            km_data,
            data.frame(time = time_horizon, survival = last_surv, n_risk = 0)
          )
        }

        # Calculate RMST using trapezoidal rule
        time_diffs <- diff(c(0, km_data$time))
        surv_avg <- (c(1, km_data$survival[-nrow(km_data)]) + km_data$survival) / 2
        rmst <- sum(time_diffs * surv_avg)

        # Estimate SE using Greenwood's formula (simplified)
        # This is approximate - better to use survRM2 package for real data
        se_rmst <- sqrt(sum(time_diffs^2 * surv_avg * (1 - surv_avg) / km_data$n_risk))

        list(rmst = rmst, se = se_rmst)

      }, error = function(e) {
        showNotification(paste("Error extracting RMST:", e$message), type = "error")
        return(NULL)
      })
    }

    # ==============================================================================
    # REACTIVE: Run RMST NMA
    # ==============================================================================

    observeEvent(input$run_rmst_nma, {
      req(rmst_rv$rmst_data)

      showNotification("Running RMST Network Meta-Analysis...", type = "message", id = "rmst_nma")

      tryCatch({
        # Prepare data for netmeta
        data <- rmst_rv$rmst_data

        # Run network meta-analysis
        nma <- netmeta(
          TE = rmst,
          seTE = se_rmst,
          treat1 = treatment,
          treat2 = reference,
          studlab = study,
          data = data,
          sm = input$sm,
          comb.fixed = (input$nma_method == "fixed"),
          comb.random = (input$nma_method == "random"),
          reference.group = input$reference_treatment
        )

        rmst_rv$rmst_nma <- nma

        # If comparison with HR requested, also run HR-based NMA
        if (input$compare_with_hr && !is.null(rv$survival_data)) {
          hr_nma <- netmeta(
            TE = log_hr,
            seTE = se_log_hr,
            treat1 = treatment,
            treat2 = reference,
            studlab = study,
            data = rv$survival_data,
            sm = "HR",
            comb.fixed = (input$nma_method == "fixed"),
            comb.random = (input$nma_method == "random"),
            reference.group = input$reference_treatment
          )

          rmst_rv$hr_nma <- hr_nma
        }

        rmst_rv$fitted <- TRUE

        removeNotification("rmst_nma")
        showNotification("RMST NMA completed successfully!", type = "message", duration = 5)

      }, error = function(e) {
        removeNotification("rmst_nma")
        showNotification(paste("Error running RMST NMA:", e$message), type = "error")
      })
    })

    # ==============================================================================
    # OUTPUTS
    # ==============================================================================

    # RMST estimates table
    output$rmst_table <- renderDT({
      req(rmst_rv$fitted, rmst_rv$rmst_nma)

      nma <- rmst_rv$rmst_nma

      # Extract treatment effects
      treatments <- nma$trts
      effects <- nma$TE.random[, 1]  # Effects vs reference
      se <- nma$seTE.random[, 1]

      # Calculate 95% CI
      ci_lower <- effects - 1.96 * se
      ci_upper <- effects + 1.96 * se

      # Create table
      data.frame(
        Treatment = treatments,
        RMST_Difference = sprintf("%.2f", effects),
        `95% CI` = sprintf("[%.2f, %.2f]", ci_lower, ci_upper),
        SE = sprintf("%.2f", se),
        P_value = format.pval(2 * pnorm(-abs(effects / se)), digits = 3)
      ) %>%
        datatable(
          options = list(pageLength = 10, dom = 'tp'),
          rownames = FALSE
        ) %>%
        formatStyle(
          'P_value',
          backgroundColor = styleInterval(0.05, c('lightgreen', 'white'))
        )
    })

    # RMST forest plot
    output$rmst_forest <- renderPlotly({
      req(rmst_rv$fitted, rmst_rv$rmst_nma)

      nma <- rmst_rv$rmst_nma

      # Extract data
      treatments <- nma$trts
      effects <- nma$TE.random[, 1]
      se <- nma$seTE.random[, 1]
      ci_lower <- effects - 1.96 * se
      ci_upper <- effects + 1.96 * se

      # Create forest plot data
      plot_data <- data.frame(
        Treatment = treatments,
        RMST_Diff = effects,
        CI_Lower = ci_lower,
        CI_Upper = ci_upper
      )

      # Sort by effect size
      plot_data <- plot_data[order(plot_data$RMST_Diff, decreasing = TRUE), ]

      # Create plotly forest plot
      plot_ly(plot_data) %>%
        add_trace(
          x = ~RMST_Diff,
          y = ~Treatment,
          error_x = list(
            type = "data",
            symmetric = FALSE,
            array = ~(CI_Upper - RMST_Diff),
            arrayminus = ~(RMST_Diff - CI_Lower)
          ),
          type = "scatter",
          mode = "markers",
          marker = list(size = 10, color = "steelblue"),
          name = "RMST Difference"
        ) %>%
        add_segments(
          x = 0, xend = 0,
          y = 0, yend = nrow(plot_data) + 1,
          line = list(dash = "dash", color = "red"),
          showlegend = FALSE
        ) %>%
        layout(
          title = paste("RMST Differences vs", input$reference_treatment,
                       "(Time Horizon:", input$time_horizon, "months)"),
          xaxis = list(title = "RMST Difference (months)"),
          yaxis = list(title = ""),
          hovermode = "closest"
        )
    })

    # League table
    output$league_table <- renderDT({
      req(rmst_rv$fitted, rmst_rv$rmst_nma)

      nma <- rmst_rv$rmst_nma

      # Extract league table
      league <- netleague(nma, bracket = "(", digits = 2)

      datatable(
        league$random,
        options = list(pageLength = 10, dom = 't'),
        rownames = TRUE
      )
    })

    # P-scores table
    output$pscore_table <- renderDT({
      req(rmst_rv$fitted, rmst_rv$rmst_nma)

      nma <- rmst_rv$rmst_nma

      # Calculate P-scores (SUCRA)
      pscores <- netrank(nma)

      data.frame(
        Treatment = names(pscores$Pscore.random),
        P_score = sprintf("%.3f", pscores$Pscore.random),
        Rank_Mean = sprintf("%.1f", pscores$ranking.random),
        Rank_Median = pscores$ranking.matrix.random[, "50%"]
      ) %>%
        datatable(
          options = list(pageLength = 10, dom = 'tp', order = list(list(1, 'desc'))),
          rownames = FALSE
        ) %>%
        formatStyle(
          'P_score',
          background = styleColorBar(c(0, 1), 'lightblue'),
          backgroundSize = '100% 90%',
          backgroundRepeat = 'no-repeat',
          backgroundPosition = 'center'
        )
    })

    # Rankogram
    output$rankogram <- renderPlotly({
      req(rmst_rv$fitted, rmst_rv$rmst_nma)

      nma <- rmst_rv$rmst_nma
      ranks <- netrank(nma)

      # Extract ranking probabilities
      rank_probs <- ranks$ranking.matrix.random

      # Convert to long format for plotting
      treatments <- rownames(rank_probs)
      n_treat <- length(treatments)

      rank_data <- data.frame()
      for (i in 1:n_treat) {
        rank_data <- rbind(
          rank_data,
          data.frame(
            Treatment = treatments[i],
            Rank = 1:n_treat,
            Probability = rank_probs[i, 1:n_treat]
          )
        )
      }

      # Create plot
      plot_ly(rank_data, x = ~Rank, y = ~Probability, color = ~Treatment,
              type = "scatter", mode = "lines+markers") %>%
        layout(
          title = "Rankogram - Probability of Each Rank",
          xaxis = list(title = "Rank (1 = Best)"),
          yaxis = list(title = "Probability", range = c(0, 1))
        )
    })

    # RMST interpretation
    output$rmst_interpretation <- renderUI({
      req(rmst_rv$fitted, rmst_rv$rmst_nma)

      nma <- rmst_rv$rmst_nma
      treatments <- nma$trts
      effects <- nma$TE.random[, 1]

      # Find best treatment
      best_idx <- which.max(effects)
      best_treatment <- treatments[best_idx]
      best_rmst <- effects[best_idx]

      tags$div(
        h5("Key Findings:"),
        p(strong("Best Treatment:"), best_treatment),
        p(strong("RMST Advantage:"), sprintf("%.2f months", best_rmst),
          "longer survival compared to", input$reference_treatment),
        p(strong("Time Horizon:"), input$time_horizon, "months"),

        hr(),

        h5("Clinical Interpretation:"),
        p("On average, patients treated with", strong(best_treatment),
          "survive", strong(sprintf("%.2f months", best_rmst)),
          "longer than those treated with", strong(input$reference_treatment),
          "over the first", strong(input$time_horizon), "months of follow-up."),

        p("This estimate:"),
        tags$ul(
          tags$li("Does not assume proportional hazards"),
          tags$li("Is clinically interpretable as time gained"),
          tags$li("Reflects average survival benefit"),
          tags$li("Is restricted to the", input$time_horizon, "month time horizon")
        )
      )
    })

    # Network plot
    output$network_plot <- renderPlot({
      req(rmst_rv$fitted, rmst_rv$rmst_nma)

      netgraph(
        rmst_rv$rmst_nma,
        plastic = FALSE,
        thickness = "number.of.studies",
        multiarm = TRUE,
        points = TRUE,
        col = "steelblue",
        number.of.studies = TRUE
      )
    })

    # Return reactive values
    return(rmst_rv)
  })
}

# ==============================================================================
# END OF MODULE
# ==============================================================================
