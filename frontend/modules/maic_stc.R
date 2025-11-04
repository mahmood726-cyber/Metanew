# MAIC/STC Module - Population-Adjusted Indirect Comparisons
# =============================================================
#
# Shiny module for Matching-Adjusted Indirect Comparison (MAIC) and
# Simulated Treatment Comparison (STC) analyses.
#
# Critical for HTA submissions when no head-to-head RCT exists (27% of submissions).
#
# Features:
# - Upload IPD (your trial) and AgD (comparator trial)
# - Select matching variables with AI suggestions
# - Run MAIC with validation
# - Interactive balance plots
# - Downloadable report

library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(plotly)
library(httr)
library(jsonlite)

#' MAIC/STC UI
#' @param id Module namespace ID
maic_stc_ui <- function(id) {
  ns <- NS(id)

  page_fluid(
    h2("MAIC/STC - Population-Adjusted Indirect Comparisons"),

    helpText(
      tags$b("Purpose:"), " Compare treatments when no head-to-head RCT exists.",
      br(),
      "MAIC reweights your IPD to match the baseline characteristics of the comparator trial.",
      br(),
      tags$small("Required by NICE, CADTH, and other HTA bodies (TSD 18).")
    ),

    hr(),

    layout_columns(
      col_widths = c(4, 8),

      # Left panel: Inputs
      card(
        card_header("Step 1: Upload Data"),

        h5("Your Trial (IPD)"),
        fileInput(
          ns("ipd_file"),
          "Individual Patient Data (CSV):",
          accept = ".csv"
        ),
        helpText("Must include: patient-level covariates, treatment indicator, outcome"),

        hr(),

        h5("Comparator Trial (AgD)"),
        fileInput(
          ns("agd_baseline_file"),
          "Baseline Characteristics (CSV):",
          accept = ".csv"
        ),
        helpText("One row with mean values for each covariate"),

        numericInput(
          ns("agd_outcome_mean"),
          "Comparator Outcome (Mean):",
          value = NULL
        ),

        numericInput(
          ns("agd_outcome_se"),
          "Comparator Outcome (SE):",
          value = NULL
        ),

        hr(),

        card_header("Step 2: Configure Analysis"),

        selectInput(
          ns("outcome_var"),
          "Outcome Variable (IPD):",
          choices = NULL
        ),

        selectInput(
          ns("treatment_var"),
          "Treatment Indicator (IPD):",
          choices = NULL
        ),

        checkboxGroupInput(
          ns("matching_vars"),
          "Matching Variables:",
          choices = NULL
        ),

        actionButton(
          ns("suggest_vars"),
          "🤖 AI Suggest Variables",
          class = "btn-secondary btn-sm"
        ),

        hr(),

        actionButton(
          ns("run_maic"),
          "Run MAIC Analysis",
          class = "btn-primary w-100"
        )
      ),

      # Right panel: Results
      card(
        navset_card_tab(
          nav_panel(
            "Results Summary",

            card(
              h4("Treatment Effect Estimate"),

              uiOutput(ns("result_summary")),

              hr(),

              h5("Diagnostics"),
              verbatimTextOutput(ns("diagnostics")),

              hr(),

              downloadButton(ns("download_report"), "Download Full Report")
            )
          ),

          nav_panel(
            "Balance Diagnostics",

            card(
              h4("Covariate Balance"),

              helpText(
                "Standardized Mean Difference (SMD) < 0.1 indicates good balance.",
                br(),
                "Compare 'Before' vs 'After' weighting to assess MAIC performance."
              ),

              hr(),

              layout_columns(
                col_widths = c(6, 6),

                card(
                  card_header("Before Weighting"),
                  DTOutput(ns("balance_before_table")),
                  plotlyOutput(ns("balance_before_plot"))
                ),

                card(
                  card_header("After Weighting"),
                  DTOutput(ns("balance_after_table")),
                  plotlyOutput(ns("balance_after_plot"))
                )
              ),

              hr(),

              h5("AI Interpretation"),
              uiOutput(ns("ai_interpretation"))
            )
          ),

          nav_panel(
            "Weight Distribution",

            card(
              h4("Patient Weights"),

              helpText(
                "Examines the distribution of MAIC weights.",
                br(),
                "Extreme weights (> 5× mean) may indicate poor overlap between populations."
              ),

              hr(),

              plotlyOutput(ns("weight_histogram"), height = "400px"),

              hr(),

              verbatimTextOutput(ns("weight_stats"))
            )
          ),

          nav_panel(
            "Validation",

            card(
              h4("Validation Checks"),

              helpText(
                "Rule-based validation ensures MAIC results are trustworthy.",
                br(),
                "All checks should pass (✅) for high-confidence results."
              ),

              hr(),

              DTOutput(ns("validation_table"))
            )
          ),

          nav_panel(
            "Help & Examples",

            card(
              h4("What is MAIC?"),

              tags$p(
                tags$b("Matching-Adjusted Indirect Comparison (MAIC)"),
                " is a population-adjusted indirect comparison method used when:"
              ),

              tags$ul(
                tags$li("You have IPD from your trial"),
                tags$li("You only have aggregate data (AgD) from the comparator trial"),
                tags$li("No head-to-head RCT exists")
              ),

              tags$p(
                "MAIC reweights your IPD patients to match the baseline characteristics",
                " of the comparator trial, enabling valid indirect comparisons."
              ),

              hr(),

              h5("Example Data Format"),

              tags$b("IPD (your trial):"),
              verbatimTextOutput(ns("example_ipd")),

              tags$b("AgD Baseline (comparator trial):"),
              verbatimTextOutput(ns("example_agd_baseline")),

              tags$b("AgD Outcomes:"),
              tags$pre("Mean: 7.5\nSE: 0.8"),

              hr(),

              h5("References"),
              tags$ul(
                tags$li("Signorovitch et al. (2012) - MAIC methodology"),
                tags$li("NICE DSU TSD 18 - Population-adjusted indirect comparisons"),
                tags$li("Phillippo et al. (2020) - Simulated Treatment Comparison")
              )
            )
          )
        )
      )
    )
  )
}


#' MAIC/STC Server
#' @param id Module namespace ID
#' @param rv Reactive values from main app
maic_stc_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values for module state
    maic_state <- reactiveValues(
      ipd = NULL,
      agd_baseline = NULL,
      results = NULL,
      ai_interpretation = NULL
    )

    # Upload IPD
    observeEvent(input$ipd_file, {
      req(input$ipd_file)

      tryCatch({
        maic_state$ipd <- read.csv(input$ipd_file$datapath, stringsAsFactors = FALSE)

        # Update outcome and treatment variable choices
        numeric_vars <- names(maic_state$ipd)[sapply(maic_state$ipd, is.numeric)]
        updateSelectInput(session, "outcome_var", choices = numeric_vars)
        updateSelectInput(session, "treatment_var", choices = names(maic_state$ipd))

        # Update matching variable choices
        updateCheckboxGroupInput(session, "matching_vars", choices = numeric_vars)

        showNotification("✅ IPD uploaded successfully", type = "message")
      }, error = function(e) {
        showNotification(paste("❌ Error uploading IPD:", e$message), type = "error")
      })
    })

    # Upload AgD baseline
    observeEvent(input$agd_baseline_file, {
      req(input$agd_baseline_file)

      tryCatch({
        maic_state$agd_baseline <- read.csv(input$agd_baseline_file$datapath, stringsAsFactors = FALSE)
        showNotification("✅ AgD baseline uploaded successfully", type = "message")
      }, error = function(e) {
        showNotification(paste("❌ Error uploading AgD:", e$message), type = "error")
      })
    })

    # AI suggest matching variables
    observeEvent(input$suggest_vars, {
      req(maic_state$ipd, maic_state$agd_baseline)

      withProgress(message = "🤖 AI suggesting variables...", {
        tryCatch({
          # Call Python backend AI suggestion endpoint
          response <- POST(
            "http://ai-backend:8001/api/maic/suggest_variables",
            body = list(
              ipd_columns = names(maic_state$ipd),
              agd_columns = names(maic_state$agd_baseline)
            ),
            encode = "json",
            timeout(30)
          )

          if (status_code(response) == 200) {
            result <- content(response, as = "parsed")
            suggested_vars <- result$suggestions

            # Update checkboxes
            updateCheckboxGroupInput(
              session,
              "matching_vars",
              selected = suggested_vars
            )

            showNotification(
              paste("✅ AI suggested", length(suggested_vars), "variables"),
              type = "message"
            )
          } else {
            showNotification("⚠️ AI suggestion failed. Using defaults.", type = "warning")
          }
        }, error = function(e) {
          showNotification(
            paste("⚠️ AI suggestion failed:", e$message),
            type = "warning"
          )
        })
      })
    })

    # Run MAIC analysis
    observeEvent(input$run_maic, {
      req(
        maic_state$ipd,
        maic_state$agd_baseline,
        input$matching_vars,
        input$outcome_var,
        input$treatment_var,
        input$agd_outcome_mean
      )

      withProgress(message = "Running MAIC analysis...", {

        tryCatch({
          # Prepare data
          data <- list(
            ipd = maic_state$ipd,
            agd_baseline = maic_state$agd_baseline,
            agd_outcomes = list(
              mean = input$agd_outcome_mean,
              se = input$agd_outcome_se
            ),
            matching_vars = input$matching_vars,
            outcome_var = input$outcome_var,
            treatment_var = input$treatment_var
          )

          # Call Python backend MAIC engine
          response <- POST(
            "http://ai-backend:8001/api/maic/run",
            body = toJSON(data, auto_unbox = TRUE),
            content_type_json(),
            timeout(120)  # 2 minute timeout
          )

          if (status_code(response) == 200) {
            results <- content(response, as = "parsed")
            maic_state$results <- results

            # Get AI interpretation
            balance_after <- data.frame(results$balance_after)
            maic_state$ai_interpretation <- get_ai_interpretation(balance_after)

            showNotification("✅ MAIC analysis completed", type = "message")
          } else {
            error_msg <- content(response, as = "text")
            showNotification(
              paste("❌ MAIC failed:", error_msg),
              type = "error",
              duration = 10
            )
          }
        }, error = function(e) {
          showNotification(
            paste("❌ Error running MAIC:", e$message),
            type = "error",
            duration = 10
          )
        })
      })
    })

    # Helper: Get AI interpretation
    get_ai_interpretation <- function(balance_df) {
      tryCatch({
        response <- POST(
          "http://ai-backend:8001/api/maic/interpret_balance",
          body = toJSON(list(balance = balance_df), auto_unbox = TRUE),
          content_type_json(),
          timeout(30)
        )

        if (status_code(response) == 200) {
          result <- content(response, as = "parsed")
          return(result$interpretation)
        } else {
          return("AI interpretation unavailable")
        }
      }, error = function(e) {
        return(paste("AI interpretation error:", e$message))
      })
    }

    # Output: Results summary
    output$result_summary <- renderUI({
      req(maic_state$results)

      r <- maic_state$results

      # Determine significance
      ci_excludes_zero <- (r$ci_lower > 0 && r$ci_upper > 0) ||
                         (r$ci_lower < 0 && r$ci_upper < 0)

      sig_icon <- if(ci_excludes_zero) "✅" else "⚠️"
      sig_text <- if(ci_excludes_zero) {
        "Statistically significant (CI excludes 0)"
      } else {
        "Not statistically significant (CI includes 0)"
      }

      tagList(
        card(
          card_body(
            h3(
              sprintf("%.3f", r$treatment_effect),
              tags$small(
                sprintf(" (95%% CI: %.3f, %.3f)", r$ci_lower, r$ci_upper)
              )
            ),
            p(paste(sig_icon, sig_text)),
            hr(),
            p(
              tags$b("Interpretation:"),
              sprintf(
                "Your treatment shows a difference of %.3f compared to the comparator (after population adjustment).",
                r$treatment_effect
              )
            )
          )
        )
      )
    })

    # Output: Diagnostics
    output$diagnostics <- renderText({
      req(maic_state$results)

      d <- maic_state$results$diagnostics

      paste0(
        "Sample Size: ", d$n_patients, "\n",
        "Effective Sample Size (ESS): ", round(d$ess, 1), "\n",
        "ESS Ratio: ", round(d$ess_ratio * 100, 1), "%\n",
        "\n",
        "Weight Statistics:\n",
        "  Mean: ", round(d$mean_weight, 3), "\n",
        "  Min: ", round(d$min_weight, 3), "\n",
        "  Max: ", round(d$max_weight, 3), "\n",
        "  CV: ", round(d$weight_cv, 3)
      )
    })

    # Output: Balance before table
    output$balance_before_table <- renderDT({
      req(maic_state$results)

      df <- data.frame(maic_state$results$balance_before)

      datatable(
        df,
        options = list(
          pageLength = 10,
          dom = 't'
        ),
        rownames = FALSE
      ) %>%
        formatRound(columns = c('ipd_mean', 'agd_mean', 'smd'), digits = 3) %>%
        formatStyle(
          'balanced',
          backgroundColor = styleEqual(c(TRUE, FALSE), c('#d4edda', '#f8d7da'))
        )
    })

    # Output: Balance after table
    output$balance_after_table <- renderDT({
      req(maic_state$results)

      df <- data.frame(maic_state$results$balance_after)

      datatable(
        df,
        options = list(
          pageLength = 10,
          dom = 't'
        ),
        rownames = FALSE
      ) %>%
        formatRound(columns = c('ipd_mean', 'agd_mean', 'smd'), digits = 3) %>%
        formatStyle(
          'balanced',
          backgroundColor = styleEqual(c(TRUE, FALSE), c('#d4edda', '#f8d7da'))
        )
    })

    # Output: Balance before plot
    output$balance_before_plot <- renderPlotly({
      req(maic_state$results)

      df <- data.frame(maic_state$results$balance_before)

      p <- ggplot(df, aes(x = variable, y = smd, fill = balanced)) +
        geom_col() +
        geom_hline(yintercept = c(-0.1, 0.1), linetype = "dashed", color = "red") +
        scale_fill_manual(values = c("TRUE" = "#28a745", "FALSE" = "#dc3545")) +
        coord_flip() +
        labs(
          title = "Balance Before Weighting",
          x = "Variable",
          y = "Standardized Mean Difference (SMD)",
          fill = "Balanced"
        ) +
        theme_minimal()

      ggplotly(p)
    })

    # Output: Balance after plot
    output$balance_after_plot <- renderPlotly({
      req(maic_state$results)

      df <- data.frame(maic_state$results$balance_after)

      p <- ggplot(df, aes(x = variable, y = smd, fill = balanced)) +
        geom_col() +
        geom_hline(yintercept = c(-0.1, 0.1), linetype = "dashed", color = "red") +
        scale_fill_manual(values = c("TRUE" = "#28a745", "FALSE" = "#dc3545")) +
        coord_flip() +
        labs(
          title = "Balance After Weighting",
          x = "Variable",
          y = "Standardized Mean Difference (SMD)",
          fill = "Balanced"
        ) +
        theme_minimal()

      ggplotly(p)
    })

    # Output: Weight histogram
    output$weight_histogram <- renderPlotly({
      req(maic_state$results)

      weights <- unlist(maic_state$results$weights)

      p <- ggplot(data.frame(weight = weights), aes(x = weight)) +
        geom_histogram(bins = 30, fill = "#007bff", alpha = 0.7) +
        geom_vline(aes(xintercept = mean(weights)), color = "red", linetype = "dashed", size = 1) +
        labs(
          title = "Distribution of MAIC Weights",
          x = "Weight",
          y = "Frequency"
        ) +
        theme_minimal()

      ggplotly(p)
    })

    # Output: Weight statistics
    output$weight_stats <- renderText({
      req(maic_state$results)

      weights <- unlist(maic_state$results$weights)

      paste0(
        "Weight Statistics:\n",
        "  Min: ", round(min(weights), 3), "\n",
        "  Q1: ", round(quantile(weights, 0.25), 3), "\n",
        "  Median: ", round(median(weights), 3), "\n",
        "  Mean: ", round(mean(weights), 3), "\n",
        "  Q3: ", round(quantile(weights, 0.75), 3), "\n",
        "  Max: ", round(max(weights), 3), "\n",
        "\n",
        "Extreme Weights (> 5× mean): ",
        sum(weights > 5 * mean(weights))
      )
    })

    # Output: Validation table
    output$validation_table <- renderDT({
      req(maic_state$results)

      checks <- maic_state$results$validation_results

      df <- data.frame(
        Check = c(
          "Weights Positive",
          "ESS Reasonable (> 10)",
          "ESS Not Extreme (> 30% of N)",
          "Treatment Effect Finite",
          "CI Reasonable Width",
          "Covariates Balanced",
          "No Extreme Weights",
          "Overall Valid"
        ),
        Status = c(
          checks$weights_positive,
          checks$ess_reasonable,
          checks$ess_not_extreme,
          checks$effect_finite,
          checks$ci_reasonable,
          checks$covariates_balanced,
          checks$no_extreme_weights,
          checks$overall_valid
        )
      )

      df$Icon <- ifelse(df$Status, "✅", "❌")

      datatable(
        df[, c("Icon", "Check", "Status")],
        options = list(
          pageLength = 10,
          dom = 't'
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          'Status',
          backgroundColor = styleEqual(c(TRUE, FALSE), c('#d4edda', '#f8d7da'))
        )
    })

    # Output: AI interpretation
    output$ai_interpretation <- renderUI({
      req(maic_state$ai_interpretation)

      card(
        card_body(
          h5("🤖 AI Analysis"),
          p(maic_state$ai_interpretation)
        )
      )
    })

    # Output: Example IPD
    output$example_ipd <- renderText({
      "patient_id,age,sex,baseline_severity,treatment,outcome
1,62,1,48,1,9.2
2,58,0,52,1,10.5
3,65,1,45,1,8.7
..."
    })

    # Output: Example AgD baseline
    output$example_agd_baseline <- renderText({
      "age,sex,baseline_severity
55,0.6,50"
    })

    # Download handler: Full report
    output$download_report <- downloadHandler(
      filename = function() {
        paste0("MAIC_Report_", Sys.Date(), ".html")
      },
      content = function(file) {
        req(maic_state$results)

        # Generate HTML report
        report_html <- generate_maic_report(maic_state$results, input)

        writeLines(report_html, file)
      }
    )

    # Helper: Generate report
    generate_maic_report <- function(results, input_data) {
      # Simple HTML report template
      html <- paste0(
        "<html>",
        "<head><title>MAIC Analysis Report</title></head>",
        "<body>",
        "<h1>MAIC Analysis Report</h1>",
        "<p>Generated: ", Sys.time(), "</p>",
        "<hr>",
        "<h2>Treatment Effect</h2>",
        "<p><b>Estimate:</b> ", round(results$treatment_effect, 3), "</p>",
        "<p><b>95% CI:</b> (", round(results$ci_lower, 3), ", ", round(results$ci_upper, 3), ")</p>",
        "<h2>Effective Sample Size</h2>",
        "<p>", round(results$ess, 1), " (from ", results$diagnostics$n_patients, ")</p>",
        "<h2>Balance</h2>",
        # Add balance tables...
        "</body>",
        "</html>"
      )

      return(html)
    }

  })
}
