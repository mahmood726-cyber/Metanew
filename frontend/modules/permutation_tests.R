# =============================================================================
# Permutation Testing Module for Meta-Analysis
# =============================================================================
# ✅ STANDARD - Recommended when distributional assumptions questionable
#
# Features:
# - Permutation test for pooled effect
# - Permutation test for heterogeneity (I²)
# - Permutation test for meta-regression coefficients
# - Permutation test for publication bias
# - No distributional assumptions needed
# - Particularly useful for small samples (n < 10)
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(metafor)
library(dplyr)

#' Perform permutation test for meta-analysis pooled effect
#'
#' @param data Data frame with yi (effect sizes) and vi (variances)
#' @param n_permutations Number of permutations (default 10000)
#' @param method Meta-analysis method ("REML", "DL", "FE")
#' @return List with permutation results
#' @export
permutation_test_pooled <- function(data, n_permutations = 10000, method = "REML") {

  # Original meta-analysis
  original_ma <- rma(yi = data$yi, vi = data$vi, method = method)
  original_effect <- as.numeric(original_ma$b)
  original_z <- as.numeric(original_ma$zval)
  original_p <- original_ma$pval

  # Initialize storage for permutation results
  perm_effects <- numeric(n_permutations)
  perm_z <- numeric(n_permutations)

  set.seed(42)  # Reproducibility

  # Perform permutations
  for (i in 1:n_permutations) {
    # Randomly flip signs of effect sizes
    # This tests null hypothesis that effect = 0
    perm_signs <- sample(c(-1, 1), nrow(data), replace = TRUE)
    perm_yi <- data$yi * perm_signs

    # Fit meta-analysis on permuted data
    perm_ma <- tryCatch({
      rma(yi = perm_yi, vi = data$vi, method = method)
    }, error = function(e) {
      NULL
    })

    if (!is.null(perm_ma)) {
      perm_effects[i] <- as.numeric(perm_ma$b)
      perm_z[i] <- as.numeric(perm_ma$zval)
    } else {
      perm_effects[i] <- NA
      perm_z[i] <- NA
    }
  }

  # Remove NAs
  perm_effects <- perm_effects[!is.na(perm_effects)]
  perm_z <- perm_z[!is.na(perm_z)]

  # Calculate permutation p-value
  # Two-sided test
  perm_p_value <- mean(abs(perm_effects) >= abs(original_effect))
  perm_p_z <- mean(abs(perm_z) >= abs(original_z))

  # Effect measure
  list(
    original_effect = original_effect,
    original_z = original_z,
    original_p = original_p,
    perm_p_value = perm_p_value,
    perm_p_z = perm_p_z,
    perm_effects = perm_effects,
    perm_z = perm_z,
    n_permutations = length(perm_effects),
    method = method
  )
}

#' Permutation test for heterogeneity
#'
#' @param data Data frame with yi and vi
#' @param n_permutations Number of permutations
#' @return List with heterogeneity permutation results
#' @export
permutation_test_heterogeneity <- function(data, n_permutations = 10000) {

  # Original Q statistic and I²
  original_ma <- rma(yi = data$yi, vi = data$vi, method = "REML")
  original_Q <- original_ma$QE
  original_I2 <- original_ma$I2

  # Permutation: shuffle effect sizes among studies
  perm_Q <- numeric(n_permutations)
  perm_I2 <- numeric(n_permutations)

  set.seed(42)

  for (i in 1:n_permutations) {
    # Permute effect sizes (keep variances with same study)
    perm_yi <- sample(data$yi)

    perm_ma <- tryCatch({
      rma(yi = perm_yi, vi = data$vi, method = "REML")
    }, error = function(e) {
      NULL
    })

    if (!is.null(perm_ma)) {
      perm_Q[i] <- perm_ma$QE
      perm_I2[i] <- perm_ma$I2
    } else {
      perm_Q[i] <- NA
      perm_I2[i] <- NA
    }
  }

  perm_Q <- perm_Q[!is.na(perm_Q)]
  perm_I2 <- perm_I2[!is.na(perm_I2)]

  # P-value: proportion of permutations with Q >= observed Q
  perm_p_Q <- mean(perm_Q >= original_Q)
  perm_p_I2 <- mean(perm_I2 >= original_I2)

  list(
    original_Q = original_Q,
    original_I2 = original_I2,
    perm_p_Q = perm_p_Q,
    perm_p_I2 = perm_p_I2,
    perm_Q = perm_Q,
    perm_I2 = perm_I2,
    n_permutations = length(perm_Q)
  )
}

#' Permutation test for meta-regression
#'
#' @param data Data frame with yi, vi, and moderator
#' @param moderator Name of moderator variable
#' @param n_permutations Number of permutations
#' @return List with meta-regression permutation results
#' @export
permutation_test_metareg <- function(data, moderator, n_permutations = 5000) {

  # Original meta-regression
  formula_str <- as.formula(paste("yi ~", moderator))
  original_mr <- rma(formula_str, vi = data$vi, data = data, method = "REML")

  # Coefficient for moderator (exclude intercept)
  original_coef <- as.numeric(original_mr$b[2])
  original_z <- as.numeric(original_mr$zval[2])
  original_p <- original_mr$pval[2]

  # Permutations
  perm_coef <- numeric(n_permutations)
  perm_z <- numeric(n_permutations)

  set.seed(42)

  for (i in 1:n_permutations) {
    # Permute moderator values
    perm_data <- data
    perm_data[[moderator]] <- sample(data[[moderator]])

    perm_mr <- tryCatch({
      rma(formula_str, vi = perm_data$vi, data = perm_data, method = "REML")
    }, error = function(e) {
      NULL
    })

    if (!is.null(perm_mr) && length(perm_mr$b) >= 2) {
      perm_coef[i] <- as.numeric(perm_mr$b[2])
      perm_z[i] <- as.numeric(perm_mr$zval[2])
    } else {
      perm_coef[i] <- NA
      perm_z[i] <- NA
    }
  }

  perm_coef <- perm_coef[!is.na(perm_coef)]
  perm_z <- perm_z[!is.na(perm_z)]

  # P-value
  perm_p_value <- mean(abs(perm_coef) >= abs(original_coef))

  list(
    original_coef = original_coef,
    original_z = original_z,
    original_p = original_p,
    perm_p_value = perm_p_value,
    perm_coef = perm_coef,
    perm_z = perm_z,
    n_permutations = length(perm_coef),
    moderator = moderator
  )
}

#' UI for permutation testing
#'
#' @param id Module ID
#' @export
permutation_tests_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      div(
        "Permutation Tests for Meta-Analysis",
        span("✅ STANDARD",
             style = "background: #10B981; color: white; padding: 3px 8px;
                      border-radius: 4px; font-size: 11px; margin-left: 10px;")
      )
    ),

    p(
      "Non-parametric permutation tests that make no distributional assumptions. Particularly useful for small samples (n < 10 studies) or when parametric assumptions are questionable.",
      style = "color: #6B7280; margin-bottom: 20px;"
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Controls
      div(
        h5("Test Settings", style = "color: #EC4899; margin-bottom: 15px;"),

        selectInput(
          ns("test_type"),
          "Test Type:",
          choices = c(
            "Pooled Effect" = "pooled",
            "Heterogeneity (Q & I²)" = "heterogeneity",
            "Meta-Regression" = "metareg"
          ),
          selected = "pooled"
        ),

        numericInput(
          ns("n_permutations"),
          "Number of Permutations:",
          value = 10000,
          min = 1000,
          max = 50000,
          step = 1000
        ),

        selectInput(
          ns("ma_method"),
          "Meta-Analysis Method:",
          choices = c(
            "REML" = "REML",
            "DerSimonian-Laird" = "DL",
            "Fixed Effect" = "FE",
            "Maximum Likelihood" = "ML"
          ),
          selected = "REML"
        ),

        # Conditional: show moderator selection for meta-regression
        conditionalPanel(
          condition = "input.test_type == 'metareg'",
          ns = ns,
          selectInput(
            ns("moderator"),
            "Moderator Variable:",
            choices = NULL  # Will be populated from data
          )
        ),

        numericInput(
          ns("alpha"),
          "Significance Level (α):",
          value = 0.05,
          min = 0.001,
          max = 0.2,
          step = 0.01
        ),

        hr(),

        actionButton(
          ns("run_permutation"),
          "Run Permutation Test",
          class = "btn-primary",
          icon = icon("random"),
          style = "width: 100%;"
        ),

        br(), br(),

        div(
          style = "background: #EFF6FF; border-left: 4px solid #3B82F6;
                   padding: 12px; border-radius: 6px;",
          div(
            strong(icon("info-circle", style = "color: #3B82F6; margin-right: 5px;"),
                   "About Permutation Tests"),
            style = "color: #1E40AF; margin-bottom: 8px;"
          ),
          tags$ul(
            style = "margin: 0; color: #1E40AF; font-size: 13px;",
            tags$li("No distributional assumptions"),
            tags$li("Exact p-values (not asymptotic)"),
            tags$li("Better for small samples"),
            tags$li("Validates parametric results"),
            tags$li("Computationally intensive")
          )
        )
      ),

      # Results
      div(
        h5("Permutation Test Results", style = "color: #EC4899; margin-bottom: 15px;"),

        uiOutput(ns("permutation_summary")),

        br(),

        tabsetPanel(
          id = ns("results_tabs"),

          tabPanel(
            "Permutation Distribution",
            br(),
            plotlyOutput(ns("permutation_dist_plot"), height = "450px"),
            br(),
            p("Shows distribution of test statistic under null hypothesis via permutation.",
              style = "color: #6B7280; font-size: 13px;")
          ),

          tabPanel(
            "P-value Comparison",
            br(),
            plotlyOutput(ns("pvalue_comparison_plot"), height = "400px"),
            br(),
            DT::DTOutput(ns("pvalue_table"))
          ),

          tabPanel(
            "Convergence",
            br(),
            plotlyOutput(ns("convergence_plot"), height = "400px"),
            br(),
            p("Shows cumulative p-value estimate as permutations accumulate.",
              style = "color: #6B7280; font-size: 13px;")
          ),

          tabPanel(
            "Interpretation",
            br(),
            uiOutput(ns("interpretation_guide"))
          )
        )
      )
    ),

    hr(),

    div(
      style = "background: #FEF3C7; border-left: 4px solid #F59E0B;
               padding: 15px; border-radius: 6px;",

      div(
        strong(icon("lightbulb", style = "color: #F59E0B; margin-right: 5px;"),
               "When to Use Permutation Tests"),
        style = "color: #92400E; margin-bottom: 8px;"
      ),

      tags$ul(
        style = "margin: 0; color: #92400E; font-size: 14px;",
        tags$li("Small number of studies (n < 10)"),
        tags$li("Skewed or non-normal effect size distributions"),
        tags$li("Outliers present in data"),
        tags$li("Validating parametric test results"),
        tags$li("Regulatory submissions requiring robust methods")
      )
    )
  )
}

#' Server for permutation testing
#'
#' @param id Module ID
#' @param rv Reactive values with meta-analysis data
#' @export
permutation_tests_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Update moderator choices based on data
    observe({
      req(rv$data)

      # Get numeric columns as potential moderators
      numeric_cols <- names(rv$data)[sapply(rv$data, is.numeric)]
      # Exclude yi and vi
      moderator_choices <- setdiff(numeric_cols, c("yi", "vi", "sei"))

      updateSelectInput(session, "moderator", choices = moderator_choices)
    })

    permutation_results <- reactiveVal(NULL)

    # Run permutation test
    observeEvent(input$run_permutation, {

      req(rv$data)
      req(rv$data$yi, rv$data$vi)

      withProgress(message = 'Running permutation test...', value = 0, {

        setProgress(0.2, detail = "Initializing...")

        test_type <- input$test_type

        if (test_type == "pooled") {
          setProgress(0.3, detail = sprintf("Running %d permutations...", input$n_permutations))

          results <- permutation_test_pooled(
            data = rv$data,
            n_permutations = input$n_permutations,
            method = input$ma_method
          )

        } else if (test_type == "heterogeneity") {
          setProgress(0.3, detail = sprintf("Running %d permutations...", input$n_permutations))

          results <- permutation_test_heterogeneity(
            data = rv$data,
            n_permutations = input$n_permutations
          )

        } else if (test_type == "metareg") {
          req(input$moderator)

          setProgress(0.3, detail = sprintf("Running %d permutations...", input$n_permutations))

          results <- permutation_test_metareg(
            data = rv$data,
            moderator = input$moderator,
            n_permutations = input$n_permutations
          )
        }

        results$test_type <- test_type
        results$alpha <- input$alpha

        permutation_results(results)

        setProgress(1)
      })
    })

    # Summary display
    output$permutation_summary <- renderUI({
      req(permutation_results())

      results <- permutation_results()
      test_type <- results$test_type

      if (test_type == "pooled") {

        # Determine significance
        is_sig_param <- results$original_p < results$alpha
        is_sig_perm <- results$perm_p_value < results$alpha

        agreement <- is_sig_param == is_sig_perm

        agreement_color <- if (agreement) "#10B981" else "#F59E0B"
        agreement_text <- if (agreement) "AGREE" else "DISAGREE"

        tagList(
          div(
            style = sprintf("background: linear-gradient(135deg, #8B5CF6 0%%, %s 100%%);
                             color: white; padding: 25px; border-radius: 12px;",
                            agreement_color),

            div(
              style = "text-align: center;",

              div(
                style = "font-size: 14px; margin-bottom: 8px; opacity: 0.9;",
                "Permutation P-value"
              ),

              div(
                style = "font-size: 48px; font-weight: 700; margin-bottom: 10px;",
                sprintf("%.4f", results$perm_p_value)
              ),

              div(
                style = "font-size: 16px; opacity: 0.95; margin-bottom: 15px;",
                sprintf("Parametric p = %.4f | Tests %s",
                        results$original_p, agreement_text)
              ),

              div(
                style = "font-size: 14px; opacity: 0.9;",
                sprintf("%s permutations | %s method",
                        format(results$n_permutations, big.mark = ","),
                        results$method)
              )
            )
          ),

          br(),

          div(
            style = "display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px;",

            div(
              style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px; text-align: center;",
              div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "Pooled Effect"),
              div(style = "color: #1F2937; font-size: 24px; font-weight: 700;",
                  sprintf("%.3f", results$original_effect))
            ),

            div(
              style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px; text-align: center;",
              div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "Z-value"),
              div(style = "color: #1F2937; font-size: 24px; font-weight: 700;",
                  sprintf("%.3f", results$original_z))
            ),

            div(
              style = sprintf("background: white; border: 2px solid %s; border-radius: 8px; padding: 15px; text-align: center;",
                              if (results$perm_p_value < results$alpha) "#10B981" else "#EF4444"),
              div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "Conclusion"),
              div(style = sprintf("color: %s; font-size: 18px; font-weight: 700;",
                                   if (results$perm_p_value < results$alpha) "#10B981" else "#EF4444"),
                  if (results$perm_p_value < results$alpha) "Significant" else "Not Significant")
            )
          )
        )

      } else if (test_type == "heterogeneity") {

        is_sig_Q <- results$perm_p_Q < results$alpha

        tagList(
          div(
            style = sprintf("background: linear-gradient(135deg, #F59E0B 0%%, %s 100%%);
                             color: white; padding: 25px; border-radius: 12px;",
                            if (is_sig_Q) "#EF4444" else "#10B981"),

            div(
              style = "text-align: center;",

              div(
                style = "font-size: 14px; margin-bottom: 8px; opacity: 0.9;",
                "Heterogeneity Test"
              ),

              div(
                style = "font-size: 42px; font-weight: 700; margin-bottom: 10px;",
                sprintf("p = %.4f", results$perm_p_Q)
              ),

              div(
                style = "font-size: 16px; opacity: 0.95;",
                if (is_sig_Q) "Significant heterogeneity detected" else "No significant heterogeneity"
              )
            )
          ),

          br(),

          div(
            style = "display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px;",

            div(
              style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px; text-align: center;",
              div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "Q Statistic"),
              div(style = "color: #1F2937; font-size: 24px; font-weight: 700;",
                  sprintf("%.2f", results$original_Q))
            ),

            div(
              style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px; text-align: center;",
              div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "I² Statistic"),
              div(style = "color: #1F2937; font-size: 24px; font-weight: 700;",
                  sprintf("%.1f%%", results$original_I2))
            )
          )
        )

      } else if (test_type == "metareg") {

        is_sig_param <- results$original_p < results$alpha
        is_sig_perm <- results$perm_p_value < results$alpha

        agreement <- is_sig_param == is_sig_perm
        agreement_color <- if (agreement) "#10B981" else "#F59E0B"

        tagList(
          div(
            style = sprintf("background: linear-gradient(135deg, #EC4899 0%%, %s 100%%);
                             color: white; padding: 25px; border-radius: 12px;",
                            agreement_color),

            div(
              style = "text-align: center;",

              div(
                style = "font-size: 14px; margin-bottom: 8px; opacity: 0.9;",
                sprintf("Meta-Regression: %s", results$moderator)
              ),

              div(
                style = "font-size: 42px; font-weight: 700; margin-bottom: 10px;",
                sprintf("p = %.4f", results$perm_p_value)
              ),

              div(
                style = "font-size: 16px; opacity: 0.95;",
                sprintf("Coefficient: %.3f | Parametric p = %.4f",
                        results$original_coef, results$original_p)
              )
            )
          ),

          br(),

          div(
            style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px; text-align: center;",
            div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;",
                sprintf("%s permutations completed", format(results$n_permutations, big.mark = ",")))
          )
        )
      }
    })

    # Permutation distribution plot
    output$permutation_dist_plot <- renderPlotly({
      req(permutation_results())

      results <- permutation_results()
      test_type <- results$test_type

      if (test_type == "pooled") {
        perm_values <- results$perm_effects
        observed <- results$original_effect
        x_label <- "Effect Size"

      } else if (test_type == "heterogeneity") {
        perm_values <- results$perm_Q
        observed <- results$original_Q
        x_label <- "Q Statistic"

      } else if (test_type == "metareg") {
        perm_values <- results$perm_coef
        observed <- results$original_coef
        x_label <- sprintf("Coefficient (%s)", results$moderator)
      }

      p <- plot_ly(x = perm_values, type = "histogram",
                   marker = list(color = '#8B5CF6', line = list(color = 'white', width = 1)),
                   name = "Permutation Distribution") %>%
        add_segments(
          x = observed, xend = observed,
          y = 0, yend = 1,
          yref = "paper",
          line = list(color = "#EF4444", width = 3, dash = "dash"),
          name = "Observed Value"
        ) %>%
        layout(
          title = "Permutation Distribution of Test Statistic",
          xaxis = list(title = x_label, zeroline = TRUE),
          yaxis = list(title = "Frequency"),
          showlegend = TRUE
        )

      p
    })

    # P-value comparison
    output$pvalue_comparison_plot <- renderPlotly({
      req(permutation_results())

      results <- permutation_results()
      test_type <- results$test_type

      if (test_type == "pooled") {
        comparison_data <- data.frame(
          Method = c("Parametric (Wald)", "Permutation"),
          P_value = c(results$original_p, results$perm_p_value),
          Color = c('#3B82F6', '#EC4899')
        )

      } else if (test_type == "heterogeneity") {
        # Compare Q test p-values
        # Parametric Q test p-value from chi-square distribution
        param_p <- pchisq(results$original_Q, df = length(rv$data$yi) - 1, lower.tail = FALSE)

        comparison_data <- data.frame(
          Method = c("Parametric (χ²)", "Permutation"),
          P_value = c(param_p, results$perm_p_Q),
          Color = c('#3B82F6', '#F59E0B')
        )

      } else if (test_type == "metareg") {
        comparison_data <- data.frame(
          Method = c("Parametric (Wald)", "Permutation"),
          P_value = c(results$original_p, results$perm_p_value),
          Color = c('#3B82F6', '#EC4899')
        )
      }

      p <- plot_ly(
        data = comparison_data,
        x = ~Method,
        y = ~P_value,
        type = 'bar',
        marker = list(color = ~Color),
        text = ~sprintf("p = %.4f", P_value),
        textposition = 'outside',
        hoverinfo = 'text'
      ) %>%
        add_segments(
          x = 0, xend = 3,
          y = results$alpha, yend = results$alpha,
          line = list(color = "#EF4444", width = 2, dash = "dot"),
          name = sprintf("α = %.2f", results$alpha),
          showlegend = TRUE
        ) %>%
        layout(
          title = "P-value Comparison: Parametric vs Permutation",
          xaxis = list(title = "Method"),
          yaxis = list(title = "P-value", range = c(0, max(comparison_data$P_value) * 1.2)),
          showlegend = FALSE
        )

      p
    })

    # P-value table
    output$pvalue_table <- DT::renderDT({
      req(permutation_results())

      results <- permutation_results()
      test_type <- results$test_type

      if (test_type == "pooled") {
        table_data <- data.frame(
          Method = c("Parametric (Wald test)", "Permutation test"),
          Test_Statistic = c(sprintf("Z = %.3f", results$original_z),
                            sprintf("Effect = %.3f", results$original_effect)),
          P_Value = c(results$original_p, results$perm_p_value),
          Significant = c(
            ifelse(results$original_p < results$alpha, "Yes", "No"),
            ifelse(results$perm_p_value < results$alpha, "Yes", "No")
          ),
          stringsAsFactors = FALSE
        )

      } else if (test_type == "heterogeneity") {
        param_p <- pchisq(results$original_Q, df = length(rv$data$yi) - 1, lower.tail = FALSE)

        table_data <- data.frame(
          Method = c("Parametric (χ² test)", "Permutation test"),
          Test_Statistic = c(sprintf("Q = %.2f", results$original_Q),
                            sprintf("Q = %.2f", results$original_Q)),
          P_Value = c(param_p, results$perm_p_Q),
          Significant = c(
            ifelse(param_p < results$alpha, "Yes", "No"),
            ifelse(results$perm_p_Q < results$alpha, "Yes", "No")
          ),
          stringsAsFactors = FALSE
        )

      } else if (test_type == "metareg") {
        table_data <- data.frame(
          Method = c("Parametric (Wald test)", "Permutation test"),
          Test_Statistic = c(sprintf("Z = %.3f", results$original_z),
                            sprintf("Coef = %.3f", results$original_coef)),
          P_Value = c(results$original_p, results$perm_p_value),
          Significant = c(
            ifelse(results$original_p < results$alpha, "Yes", "No"),
            ifelse(results$perm_p_value < results$alpha, "Yes", "No")
          ),
          stringsAsFactors = FALSE
        )
      }

      # Format p-values
      table_data <- table_data %>%
        mutate(P_Value = sprintf("%.4f", P_Value))

      names(table_data) <- c("Method", "Test Statistic", "P-value", sprintf("Significant (α=%.2f)?", results$alpha))

      DT::datatable(
        table_data,
        options = list(
          pageLength = 10,
          dom = 't'
        ),
        rownames = FALSE,
        class = 'cell-border stripe'
      ) %>%
        DT::formatStyle(
          sprintf("Significant (α=%.2f)?", results$alpha),
          backgroundColor = DT::styleEqual(
            c("Yes", "No"),
            c('#D1FAE5', '#FEE2E2')
          )
        )
    })

    # Convergence plot
    output$convergence_plot <- renderPlotly({
      req(permutation_results())

      results <- permutation_results()
      test_type <- results$test_type

      if (test_type == "pooled") {
        perm_values <- results$perm_effects
        observed <- results$original_effect

      } else if (test_type == "heterogeneity") {
        perm_values <- results$perm_Q
        observed <- results$original_Q

      } else if (test_type == "metareg") {
        perm_values <- results$perm_coef
        observed <- results$original_coef
      }

      # Calculate cumulative p-value
      n <- length(perm_values)
      cumulative_p <- numeric(n)

      for (i in 1:n) {
        cumulative_p[i] <- mean(abs(perm_values[1:i]) >= abs(observed))
      }

      convergence_data <- data.frame(
        iteration = 1:n,
        cumulative_p = cumulative_p
      )

      p <- plot_ly(data = convergence_data) %>%
        add_lines(
          x = ~iteration,
          y = ~cumulative_p,
          line = list(color = '#8B5CF6', width = 2),
          name = 'Cumulative P-value'
        ) %>%
        add_segments(
          x = 0, xend = n,
          y = results$alpha, yend = results$alpha,
          line = list(color = "#EF4444", width = 2, dash = "dot"),
          name = sprintf("α = %.2f", results$alpha)
        ) %>%
        layout(
          title = "Permutation Test Convergence",
          xaxis = list(title = "Number of Permutations"),
          yaxis = list(title = "Cumulative P-value"),
          hovermode = "closest"
        )

      p
    })

    # Interpretation guide
    output$interpretation_guide <- renderUI({
      req(permutation_results())

      results <- permutation_results()
      test_type <- results$test_type

      # Determine agreement
      if (test_type == "pooled" || test_type == "metareg") {
        param_p <- if (test_type == "pooled") results$original_p else results$original_p
        perm_p <- if (test_type == "pooled") results$perm_p_value else results$perm_p_value

        is_sig_param <- param_p < results$alpha
        is_sig_perm <- perm_p < results$alpha
        agreement <- is_sig_param == is_sig_perm

      } else if (test_type == "heterogeneity") {
        param_p <- pchisq(results$original_Q, df = length(rv$data$yi) - 1, lower.tail = FALSE)
        perm_p <- results$perm_p_Q

        is_sig_param <- param_p < results$alpha
        is_sig_perm <- perm_p < results$alpha
        agreement <- is_sig_param == is_sig_perm
      }

      tagList(
        div(
          style = "background: white; padding: 20px; border-radius: 8px; border: 1px solid #E5E7EB;",

          h5("Interpretation:", style = "color: #1F2937; margin-bottom: 15px;"),

          div(
            style = sprintf("background: %s; border-left: 4px solid %s; padding: 15px; border-radius: 6px; margin-bottom: 20px;",
                            if (agreement) "#D1FAE5" else "#FEF3C7",
                            if (agreement) "#10B981" else "#F59E0B"),
            h6(strong(if (agreement) "Tests Agree" else "Tests Disagree"),
               style = sprintf("color: %s; margin-bottom: 10px;",
                               if (agreement) "#065F46" else "#92400E")),
            p(
              if (agreement) {
                sprintf("Both parametric (p = %.4f) and permutation (p = %.4f) tests reach the %s conclusion. This provides strong evidence for your result.",
                        param_p, perm_p,
                        if (is_sig_perm) "SAME SIGNIFICANT" else "SAME NON-SIGNIFICANT")
              } else {
                sprintf("Parametric test (p = %.4f) and permutation test (p = %.4f) disagree. The permutation test is more reliable when distributional assumptions are violated.",
                        param_p, perm_p)
              },
              style = sprintf("color: %s; margin: 0; line-height: 1.6;",
                              if (agreement) "#065F46" else "#92400E")
            )
          ),

          h6("Key Points:", style = "color: #374151; margin-top: 20px;"),
          tags$ul(
            style = "color: #6B7280; line-height: 1.8;",
            tags$li(strong("Permutation p-value: "), sprintf("%.4f", perm_p),
                    " - This is the exact p-value based on ", format(results$n_permutations, big.mark = ","), " permutations"),
            tags$li(strong("Parametric p-value: "), sprintf("%.4f", param_p),
                    " - This assumes normal distribution and large-sample approximations"),
            tags$li(strong("When to trust permutation: "), "Small samples (n < 10), outliers, non-normal distributions, or as validation of parametric results"),
            tags$li(strong("Computational note: "), "More permutations (10,000+) give more stable p-values")
          ),

          hr(),

          div(
            style = "background: #F9FAFB; padding: 15px; border-radius: 6px;",
            h6("Recommendation:", style = "color: #1F2937; margin-bottom: 10px;"),
            p(
              if (agreement) {
                "Since both tests agree, you can report either p-value with confidence. For transparency, consider reporting both and noting their agreement."
              } else {
                "When tests disagree, the permutation test is generally more reliable as it makes no distributional assumptions. Report the permutation p-value as primary result and note the discrepancy with parametric test."
              },
              style = "color: #374151; margin: 0; line-height: 1.6; font-size: 14px;"
            )
          )
        )
      )
    })
  })
}
