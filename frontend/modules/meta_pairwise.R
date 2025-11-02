# Pairwise Meta-Analysis Module
# Performs fixed and random effects meta-analysis using metafor

library(shiny)
library(metafor)
library(plotly)

# UI
meta_pairwise_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(3, 9),

      # Left panel: Settings
      card(
        card_header("Analysis Settings"),
        selectInput(
          ns("outcome"),
          "Outcome",
          choices = NULL
        ),
        selectInput(
          ns("method"),
          "Method",
          choices = c(
            "REML" = "REML",
            "DerSimonian-Laird" = "DL",
            "Maximum Likelihood" = "ML",
            "Empirical Bayes" = "EB",
            "Hunter-Schmidt" = "HS"
          ),
          selected = "REML"
        ),
        selectInput(
          ns("model"),
          "Model",
          choices = c(
            "Random Effects" = "random",
            "Fixed Effect" = "fixed"
          ),
          selected = "random"
        ),
        checkboxInput(ns("subgroup"), "Subgroup Analysis", FALSE),
        conditionalPanel(
          condition = "input.subgroup == true",
          ns = ns,
          selectInput(ns("subgroup_var"), "Subgroup Variable", choices = NULL)
        ),
        checkboxInput(ns("meta_regression"), "Meta-Regression", FALSE),
        conditionalPanel(
          condition = "input.meta_regression == true",
          ns = ns,
          selectInput(ns("moderator_vars"), "Moderators", choices = NULL, multiple = TRUE)
        ),
        actionButton(
          ns("btn_run"),
          "Run Analysis",
          class = "btn-primary w-100 mt-3"
        )
      ),

      # Right panel: Results
      card(
        card_header("Results"),
        navset_card_tab(
          nav_panel(
            "Summary",
            verbatimTextOutput(ns("summary"))
          ),
          nav_panel(
            "Forest Plot",
            plotlyOutput(ns("forest_plot"), height = "600px")
          ),
          nav_panel(
            "Funnel Plot",
            plotlyOutput(ns("funnel_plot"), height = "500px")
          ),
          nav_panel(
            "Heterogeneity",
            uiOutput(ns("heterogeneity"))
          ),
          nav_panel(
            "Publication Bias",
            verbatimTextOutput(ns("egger_test")),
            plotOutput(ns("trim_fill_plot"))
          )
        )
      )
    )
  )
}

# Server
meta_pairwise_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Results storage
    ma_result <- reactiveVal(NULL)

    # Update outcome choices when data is loaded
    observe({
      req(rv$data)

      # Look for yi column or outcome column
      if ("outcome" %in% names(rv$data)) {
        outcomes <- unique(rv$data$outcome)
        updateSelectInput(session, "outcome", choices = outcomes)
      }

      # Update subgroup variable choices
      categorical_vars <- names(rv$data)[sapply(rv$data, function(x) {
        is.character(x) || is.factor(x)
      })]
      updateSelectInput(session, "subgroup_var", choices = categorical_vars)

      # Update moderator choices (numeric or categorical)
      potential_moderators <- names(rv$data)[!names(rv$data) %in% c("yi", "sei", "vi", "study_id")]
      updateSelectInput(session, "moderator_vars", choices = potential_moderators)
    })

    # Run meta-analysis
    observeEvent(input$btn_run, {
      req(rv$data)

      withProgress(message = "Running meta-analysis...", {

        tryCatch({
          result <- run_pairwise_ma(
            data = rv$data,
            outcome = input$outcome,
            method = input$method,
            model = input$model,
            subgroup = if (input$subgroup) input$subgroup_var else NULL,
            moderators = if (input$meta_regression) input$moderator_vars else NULL
          )

          ma_result(result)
          rv$pairwise_results[[input$outcome]] <- result

          showNotification("✓ Meta-analysis complete", type = "message")

        }, error = function(e) {
          showNotification(
            paste("Error running meta-analysis:", e$message),
            type = "error",
            duration = 10
          )
        })
      })
    })

    # Summary output
    output$summary <- renderPrint({
      req(ma_result())

      cat("PAIRWISE META-ANALYSIS RESULTS\n")
      cat("==============================\n\n")

      result <- ma_result()

      cat("Outcome:", input$outcome, "\n")
      cat("Method:", input$method, "\n")
      cat("Model:", input$model, "\n")
      cat("Studies:", result$n_studies, "\n\n")

      cat("Pooled Effect:\n")
      cat(sprintf("  Estimate: %.3f (%.3f to %.3f)\n",
                  result$pooled_effect,
                  result$ci_lower,
                  result$ci_upper))
      cat(sprintf("  SE: %.3f\n", result$se))
      cat(sprintf("  Z = %.2f, p = %.4f\n", result$z_value, result$p_value))
      cat("\n")

      cat("Heterogeneity:\n")
      cat(sprintf("  Q = %.2f, df = %d, p = %.4f\n",
                  result$q_statistic, result$df, result$q_p_value))
      cat(sprintf("  I² = %.1f%%\n", result$i_squared))
      cat(sprintf("  τ² = %.3f\n", result$tau_squared))
      cat(sprintf("  Prediction interval: %.3f to %.3f\n",
                  result$pi_lower, result$pi_upper))
      cat("\n")

      # Subgroup results if applicable
      if (!is.null(result$subgroup_results)) {
        cat("Subgroup Analysis:\n")
        for (subgroup in names(result$subgroup_results)) {
          sg <- result$subgroup_results[[subgroup]]
          cat(sprintf("  %s: %.3f (%.3f to %.3f), k=%d\n",
                      subgroup, sg$estimate, sg$ci_lower, sg$ci_upper, sg$k))
        }
        cat("\n")
      }

      # Meta-regression if applicable
      if (!is.null(result$meta_regression)) {
        cat("\nMeta-Regression:\n")
        print(result$meta_regression)
      }
    })

    # Forest plot
    output$forest_plot <- renderPlotly({
      req(ma_result())

      create_forest_plot(ma_result(), input$outcome)
    })

    # Funnel plot
    output$funnel_plot <- renderPlotly({
      req(ma_result())

      create_funnel_plot(ma_result())
    })

    # Heterogeneity details
    output$heterogeneity <- renderUI({
      req(ma_result())

      result <- ma_result()

      card(
        card_body(
          h4("Heterogeneity Assessment"),
          hr(),

          layout_columns(
            col_widths = c(6, 6),

            # Q statistic
            value_box(
              title = "Q Statistic",
              value = sprintf("%.2f", result$q_statistic),
              showcase = icon("chart-line"),
              theme = "primary",
              p(sprintf("df = %d, p = %.4f", result$df, result$q_p_value))
            ),

            # I-squared
            value_box(
              title = "I² Statistic",
              value = sprintf("%.1f%%", result$i_squared),
              showcase = icon("percentage"),
              theme = if (result$i_squared < 25) "success" else if (result$i_squared < 75) "warning" else "danger",
              p(interpret_i_squared(result$i_squared))
            )
          ),

          layout_columns(
            col_widths = c(6, 6),

            # Tau-squared
            value_box(
              title = "τ² (Between-study variance)",
              value = sprintf("%.3f", result$tau_squared),
              showcase = icon("random"),
              theme = "info"
            ),

            # Prediction interval
            value_box(
              title = "95% Prediction Interval",
              value = sprintf("%.2f to %.2f", result$pi_lower, result$pi_upper),
              showcase = icon("arrows-alt-h"),
              theme = "secondary",
              p("Expected range for a new study")
            )
          )
        )
      )
    })

    # Egger's test
    output$egger_test <- renderPrint({
      req(ma_result())

      result <- ma_result()

      cat("PUBLICATION BIAS ASSESSMENT\n")
      cat("===========================\n\n")

      if (!is.null(result$egger_test)) {
        cat("Egger's Test for Funnel Plot Asymmetry:\n")
        cat(sprintf("  Intercept: %.3f (%.3f to %.3f)\n",
                    result$egger_test$estimate,
                    result$egger_test$ci_lower,
                    result$egger_test$ci_upper))
        cat(sprintf("  t = %.2f, p = %.4f\n",
                    result$egger_test$t_value,
                    result$egger_test$p_value))

        if (result$egger_test$p_value < 0.05) {
          cat("\n⚠ Significant asymmetry detected (possible publication bias)\n")
        } else {
          cat("\n✓ No significant asymmetry detected\n")
        }
      } else {
        cat("Egger's test not available (insufficient studies)\n")
      }
    })

    # Return results
    return(reactive({
      ma_result()
    }))
  })
}

# Helper function: Run pairwise meta-analysis
run_pairwise_ma <- function(data, outcome = NULL, method = "REML", model = "random",
                             subgroup = NULL, moderators = NULL) {

  # Filter by outcome if specified
  if (!is.null(outcome) && "outcome" %in% names(data)) {
    data <- data[data$outcome == outcome, ]
  }

  # Check required columns
  if (!all(c("yi", "sei") %in% names(data))) {
    stop("Data must contain yi (effect size) and sei (standard error) columns")
  }

  # Calculate variance if not present
  if (!"vi" %in% names(data)) {
    data$vi <- data$sei^2
  }

  # Run meta-analysis
  if (!is.null(moderators) && length(moderators) > 0) {
    # Meta-regression
    formula_str <- paste("yi ~", paste(moderators, collapse = " + "))
    ma <- rma(as.formula(formula_str), vi = vi, data = data, method = method)

    meta_reg_result <- summary(ma)
  } else if (!is.null(subgroup)) {
    # Subgroup analysis
    ma <- rma(yi, vi, data = data, method = method)

    # Run separate MA for each subgroup
    subgroup_results <- list()
    for (sg in unique(data[[subgroup]])) {
      sg_data <- data[data[[subgroup]] == sg, ]
      if (nrow(sg_data) >= 2) {
        sg_ma <- rma(yi, vi, data = sg_data, method = method)
        subgroup_results[[as.character(sg)]] <- list(
          estimate = as.numeric(sg_ma$beta),
          ci_lower = as.numeric(sg_ma$ci.lb),
          ci_upper = as.numeric(sg_ma$ci.ub),
          k = sg_ma$k
        )
      }
    }
  } else {
    # Simple pooled analysis
    ma <- rma(yi, vi, data = data, method = method)
    subgroup_results <- NULL
    meta_reg_result <- NULL
  }

  # Extract results
  result <- list(
    pooled_effect = as.numeric(ma$beta),
    ci_lower = as.numeric(ma$ci.lb),
    ci_upper = as.numeric(ma$ci.ub),
    se = as.numeric(ma$se),
    z_value = as.numeric(ma$zval),
    p_value = as.numeric(ma$pval),
    i_squared = as.numeric(ma$I2),
    tau_squared = as.numeric(ma$tau2),
    q_statistic = as.numeric(ma$QE),
    df = as.numeric(ma$k - 1),
    q_p_value = as.numeric(ma$QEp),
    n_studies = as.numeric(ma$k),
    pi_lower = as.numeric(predict(ma)$pi.lb),
    pi_upper = as.numeric(predict(ma)$pi.ub),
    model_object = ma,
    data = data,
    subgroup_results = subgroup_results,
    meta_regression = meta_reg_result
  )

  # Egger's test (if ≥10 studies)
  if (ma$k >= 10) {
    egger <- tryCatch({
      egger_ma <- rma(yi, vi, mods = ~ sei, data = data, method = method)
      list(
        estimate = as.numeric(egger_ma$beta[1]),
        ci_lower = as.numeric(egger_ma$ci.lb[1]),
        ci_upper = as.numeric(egger_ma$ci.ub[1]),
        t_value = as.numeric(egger_ma$zval[1]),
        p_value = as.numeric(egger_ma$pval[1])
      )
    }, error = function(e) NULL)

    result$egger_test <- egger
  }

  return(result)
}

# Helper: Interpret I²
interpret_i_squared <- function(i_squared) {
  if (i_squared < 25) {
    "Low heterogeneity"
  } else if (i_squared < 50) {
    "Moderate heterogeneity"
  } else if (i_squared < 75) {
    "Substantial heterogeneity"
  } else {
    "Considerable heterogeneity"
  }
}
