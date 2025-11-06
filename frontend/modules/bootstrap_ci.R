# =============================================================================
# Bootstrap Confidence Intervals Module (BCa Method)
# =============================================================================
# ✅ STANDARD - Recommended by statistical literature for non-normal distributions
#
# Features:
# - BCa (Bias-Corrected and Accelerated) bootstrap intervals
# - More accurate than Wald intervals for skewed distributions
# - Handles small sample sizes better
# - Provides percentile and studentized intervals as alternatives
# - Visualization of bootstrap distributions
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(boot)
library(metafor)

#' Calculate BCa bootstrap confidence intervals for meta-analysis
#'
#' @param data Data frame with yi (effect sizes) and vi (variances)
#' @param conf_level Confidence level (default 0.95)
#' @param n_bootstrap Number of bootstrap replications (default 10000)
#' @param method Meta-analysis method ("REML", "DL", "FE")
#' @return List with bootstrap results and confidence intervals
#' @export
bootstrap_meta_ci <- function(data, conf_level = 0.95, n_bootstrap = 10000,
                               method = "REML") {

  # Define statistic function for bootstrapping
  meta_statistic <- function(data, indices) {
    boot_data <- data[indices, ]

    # Fit meta-analysis model
    tryCatch({
      if (method == "FE") {
        fit <- rma(yi = boot_data$yi, vi = boot_data$vi, method = "FE")
      } else {
        fit <- rma(yi = boot_data$yi, vi = boot_data$vi, method = method)
      }

      c(estimate = as.numeric(fit$b),
        tau2 = fit$tau2,
        I2 = fit$I2)

    }, error = function(e) {
      c(estimate = NA, tau2 = NA, I2 = NA)
    })
  }

  # Run bootstrap
  set.seed(42)  # For reproducibility
  boot_results <- boot(
    data = data,
    statistic = meta_statistic,
    R = n_bootstrap,
    parallel = "no"  # Can be "multicore" on Unix systems
  )

  # Calculate different types of confidence intervals
  alpha <- 1 - conf_level

  # BCa interval for pooled estimate
  bca_ci_estimate <- tryCatch({
    boot.ci(boot_results, conf = conf_level, type = "bca", index = 1)$bca[4:5]
  }, error = function(e) {
    c(NA, NA)
  })

  # Percentile interval for comparison
  perc_ci_estimate <- tryCatch({
    boot.ci(boot_results, conf = conf_level, type = "perc", index = 1)$percent[4:5]
  }, error = function(e) {
    c(NA, NA)
  })

  # Normal approximation (Wald) interval
  normal_ci_estimate <- tryCatch({
    boot.ci(boot_results, conf = conf_level, type = "norm", index = 1)$normal[2:3]
  }, error = function(e) {
    c(NA, NA)
  })

  # Original meta-analysis for comparison
  original_fit <- rma(yi = data$yi, vi = data$vi, method = method)

  # Bootstrap distribution statistics
  boot_dist <- boot_results$t[, 1]
  boot_dist <- boot_dist[!is.na(boot_dist)]

  boot_stats <- list(
    mean = mean(boot_dist),
    median = median(boot_dist),
    sd = sd(boot_dist),
    skewness = calculate_skewness(boot_dist),
    kurtosis = calculate_kurtosis(boot_dist),
    percentile_2.5 = quantile(boot_dist, probs = alpha/2),
    percentile_97.5 = quantile(boot_dist, probs = 1 - alpha/2)
  )

  list(
    boot_results = boot_results,
    original_estimate = as.numeric(original_fit$b),
    original_ci = c(original_fit$ci.lb, original_fit$ci.ub),
    bca_ci = bca_ci_estimate,
    percentile_ci = perc_ci_estimate,
    normal_ci = normal_ci_estimate,
    boot_stats = boot_stats,
    n_bootstrap = n_bootstrap,
    conf_level = conf_level,
    method = method
  )
}

#' Calculate skewness
#' @param x Numeric vector
#' @return Skewness value
calculate_skewness <- function(x) {
  n <- length(x)
  mean_x <- mean(x)
  sd_x <- sd(x)
  skew <- (sum((x - mean_x)^3) / n) / (sd_x^3)
  return(skew)
}

#' Calculate excess kurtosis
#' @param x Numeric vector
#' @return Kurtosis value
calculate_kurtosis <- function(x) {
  n <- length(x)
  mean_x <- mean(x)
  sd_x <- sd(x)
  kurt <- (sum((x - mean_x)^4) / n) / (sd_x^4) - 3
  return(kurt)
}

#' UI for bootstrap confidence intervals
#'
#' @param id Module ID
#' @export
bootstrap_ci_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      div(
        "Bootstrap Confidence Intervals (BCa Method)",
        span("✅ STANDARD",
             style = "background: #10B981; color: white; padding: 3px 8px;
                      border-radius: 4px; font-size: 11px; margin-left: 10px;")
      )
    ),

    p(
      "Calculate bias-corrected and accelerated (BCa) bootstrap confidence intervals - more accurate than standard Wald intervals, especially for skewed distributions or small samples.",
      style = "color: #6B7280; margin-bottom: 20px;"
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Controls
      div(
        h5("Bootstrap Settings", style = "color: #EC4899; margin-bottom: 15px;"),

        numericInput(
          ns("n_bootstrap"),
          "Number of Bootstrap Replications:",
          value = 10000,
          min = 1000,
          max = 50000,
          step = 1000
        ),

        numericInput(
          ns("confidence_level"),
          "Confidence Level (%):",
          value = 95,
          min = 90,
          max = 99,
          step = 1
        ),

        selectInput(
          ns("meta_method"),
          "Meta-Analysis Method:",
          choices = c(
            "REML (Restricted Maximum Likelihood)" = "REML",
            "DerSimonian-Laird" = "DL",
            "Fixed Effect" = "FE",
            "Maximum Likelihood" = "ML",
            "Empirical Bayes" = "EB"
          ),
          selected = "REML"
        ),

        checkboxGroupInput(
          ns("ci_types"),
          "Interval Types to Display:",
          choices = c(
            "BCa (Bias-Corrected Accelerated)" = "bca",
            "Percentile" = "percentile",
            "Normal (Wald)" = "normal",
            "Original Meta-Analysis" = "original"
          ),
          selected = c("bca", "original")
        ),

        hr(),

        actionButton(
          ns("run_bootstrap"),
          "Run Bootstrap Analysis",
          class = "btn-primary",
          icon = icon("random"),
          style = "width: 100%;"
        ),

        br(), br(),

        div(
          style = "background: #EFF6FF; border-left: 4px solid #3B82F6;
                   padding: 12px; border-radius: 6px;",
          div(
            strong(icon("lightbulb", style = "color: #3B82F6; margin-right: 5px;"),
                   "Why Bootstrap?"),
            style = "color: #1E40AF; margin-bottom: 8px;"
          ),
          tags$ul(
            style = "margin: 0; color: #1E40AF; font-size: 13px;",
            tags$li("Better coverage for skewed distributions"),
            tags$li("More accurate with small sample sizes"),
            tags$li("No normality assumptions needed"),
            tags$li("BCa corrects for bias and skewness"),
            tags$li("Recommended for important decisions")
          )
        )
      ),

      # Results
      div(
        h5("Bootstrap Results", style = "color: #EC4899; margin-bottom: 15px;"),

        uiOutput(ns("bootstrap_summary")),

        br(),

        tabsetPanel(
          id = ns("results_tabs"),

          tabPanel(
            "Confidence Intervals",
            br(),
            plotlyOutput(ns("ci_comparison_plot"), height = "400px"),
            br(),
            DT::DTOutput(ns("ci_table"))
          ),

          tabPanel(
            "Bootstrap Distribution",
            br(),
            plotlyOutput(ns("bootstrap_dist_plot"), height = "400px"),
            br(),
            uiOutput(ns("distribution_stats"))
          ),

          tabPanel(
            "Convergence Diagnostic",
            br(),
            plotlyOutput(ns("convergence_plot"), height = "400px"),
            br(),
            p("Shows cumulative mean and SD to assess bootstrap convergence.",
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
        strong(icon("info-circle", style = "color: #F59E0B; margin-right: 5px;"),
               "About BCa Intervals"),
        style = "color: #92400E; margin-bottom: 8px;"
      ),

      tags$ul(
        style = "margin: 0; color: #92400E; font-size: 14px;",
        tags$li("BCa = Bias-Corrected and Accelerated bootstrap"),
        tags$li("Automatically adjusts for skewness in the bootstrap distribution"),
        tags$li("Generally more accurate than percentile or normal bootstrap"),
        tags$li("Requires sufficient replications (≥10,000 recommended)"),
        tags$li("May fail with very small samples or extreme skewness")
      )
    )
  )
}

#' Server for bootstrap confidence intervals
#'
#' @param id Module ID
#' @param rv Reactive values with meta-analysis data
#' @export
bootstrap_ci_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    bootstrap_results <- reactiveVal(NULL)

    # Run bootstrap analysis
    observeEvent(input$run_bootstrap, {

      req(rv$data)
      req(rv$data$yi, rv$data$vi)

      withProgress(message = 'Running bootstrap analysis...', value = 0, {

        setProgress(0.2, detail = "Initializing...")

        # Prepare data
        boot_data <- data.frame(
          yi = rv$data$yi,
          vi = rv$data$vi
        )

        setProgress(0.3, detail = sprintf("Running %d bootstrap replications...",
                                          input$n_bootstrap))

        # Run bootstrap
        results <- bootstrap_meta_ci(
          data = boot_data,
          conf_level = input$confidence_level / 100,
          n_bootstrap = input$n_bootstrap,
          method = input$meta_method
        )

        bootstrap_results(results)

        setProgress(1, detail = "Complete!")
      })
    })

    # Summary display
    output$bootstrap_summary <- renderUI({
      req(bootstrap_results())

      results <- bootstrap_results()

      # Determine if BCa is substantially different from original
      bca_diff <- abs(diff(results$bca_ci) - diff(results$original_ci))
      ci_width_original <- diff(results$original_ci)
      relative_diff <- (bca_diff / ci_width_original) * 100

      improvement_flag <- if (relative_diff > 10) "SUBSTANTIAL" else if (relative_diff > 5) "MODERATE" else "MINIMAL"

      improvement_color <- if (improvement_flag == "SUBSTANTIAL") "#EC4899"
                           else if (improvement_flag == "MODERATE") "#F59E0B"
                           else "#10B981"

      tagList(
        div(
          style = "background: linear-gradient(135deg, #8B5CF6 0%, #EC4899 100%);
                   color: white; padding: 25px; border-radius: 12px;",

          div(
            style = "text-align: center;",

            div(
              style = "font-size: 14px; margin-bottom: 8px; opacity: 0.9;",
              "BCa Bootstrap Estimate"
            ),

            div(
              style = "font-size: 42px; font-weight: 700; margin-bottom: 10px;",
              sprintf("%.3f", results$boot_stats$mean)
            ),

            div(
              style = "font-size: 16px; opacity: 0.95; margin-bottom: 15px;",
              sprintf("95%% BCa CI: [%.3f, %.3f]",
                      results$bca_ci[1], results$bca_ci[2])
            ),

            div(
              style = "font-size: 13px; opacity: 0.85;",
              sprintf("%s bootstrap replications | %s method",
                      format(results$n_bootstrap, big.mark = ","),
                      results$method)
            )
          )
        ),

        br(),

        div(
          style = "display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px;",

          div(
            style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px; text-align: center;",
            div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "Original Estimate"),
            div(style = "color: #1F2937; font-size: 20px; font-weight: 600;",
                sprintf("%.3f", results$original_estimate)),
            div(style = "color: #6B7280; font-size: 11px; margin-top: 3px;",
                sprintf("[%.3f, %.3f]", results$original_ci[1], results$original_ci[2]))
          ),

          div(
            style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 15px; text-align: center;",
            div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "Skewness"),
            div(style = sprintf("color: %s; font-size: 20px; font-weight: 600;",
                                 if (abs(results$boot_stats$skewness) > 0.5) "#EF4444" else "#10B981"),
                sprintf("%.2f", results$boot_stats$skewness)),
            div(style = "color: #6B7280; font-size: 11px; margin-top: 3px;",
                if (abs(results$boot_stats$skewness) > 0.5) "Skewed" else "Symmetric")
          ),

          div(
            style = sprintf("background: white; border: 2px solid %s; border-radius: 8px; padding: 15px; text-align: center;",
                            improvement_color),
            div(style = "color: #6B7280; font-size: 13px; margin-bottom: 5px;", "CI Difference"),
            div(style = sprintf("color: %s; font-size: 20px; font-weight: 600;", improvement_color),
                improvement_flag),
            div(style = "color: #6B7280; font-size: 11px; margin-top: 3px;",
                sprintf("%.1f%% change", relative_diff))
          )
        )
      )
    })

    # CI comparison plot
    output$ci_comparison_plot <- renderPlotly({
      req(bootstrap_results())

      results <- bootstrap_results()

      # Prepare data for plotting
      ci_data <- data.frame(
        method = character(),
        estimate = numeric(),
        lower = numeric(),
        upper = numeric(),
        stringsAsFactors = FALSE
      )

      if ("bca" %in% input$ci_types) {
        ci_data <- rbind(ci_data, data.frame(
          method = "BCa Bootstrap",
          estimate = results$boot_stats$mean,
          lower = results$bca_ci[1],
          upper = results$bca_ci[2]
        ))
      }

      if ("percentile" %in% input$ci_types) {
        ci_data <- rbind(ci_data, data.frame(
          method = "Percentile Bootstrap",
          estimate = results$boot_stats$median,
          lower = results$percentile_ci[1],
          upper = results$percentile_ci[2]
        ))
      }

      if ("normal" %in% input$ci_types) {
        ci_data <- rbind(ci_data, data.frame(
          method = "Normal Bootstrap",
          estimate = results$boot_stats$mean,
          lower = results$normal_ci[1],
          upper = results$normal_ci[2]
        ))
      }

      if ("original" %in% input$ci_types) {
        ci_data <- rbind(ci_data, data.frame(
          method = "Original (Wald)",
          estimate = results$original_estimate,
          lower = results$original_ci[1],
          upper = results$original_ci[2]
        ))
      }

      # Color scheme
      ci_data$color <- c("#EC4899", "#8B5CF6", "#3B82F6", "#10B981")[1:nrow(ci_data)]

      p <- plot_ly(data = ci_data, type = 'scatter', mode = 'markers') %>%
        add_segments(
          x = ~lower, xend = ~upper,
          y = ~method, yend = ~method,
          line = list(width = 4),
          color = ~method,
          colors = ci_data$color,
          showlegend = FALSE
        ) %>%
        add_markers(
          x = ~estimate,
          y = ~method,
          marker = list(size = 12, symbol = "diamond"),
          color = ~method,
          colors = ci_data$color,
          showlegend = FALSE
        ) %>%
        layout(
          title = "Confidence Interval Comparison",
          xaxis = list(title = "Effect Size", zeroline = TRUE),
          yaxis = list(title = ""),
          hovermode = "closest",
          margin = list(l = 150)
        )

      p
    })

    # CI table
    output$ci_table <- DT::renderDT({
      req(bootstrap_results())

      results <- bootstrap_results()

      table_data <- data.frame(
        Method = c("Original (Wald)", "BCa Bootstrap", "Percentile Bootstrap", "Normal Bootstrap"),
        Estimate = c(results$original_estimate,
                     results$boot_stats$mean,
                     results$boot_stats$median,
                     results$boot_stats$mean),
        Lower_CI = c(results$original_ci[1],
                     results$bca_ci[1],
                     results$percentile_ci[1],
                     results$normal_ci[1]),
        Upper_CI = c(results$original_ci[2],
                     results$bca_ci[2],
                     results$percentile_ci[2],
                     results$normal_ci[2]),
        Width = c(diff(results$original_ci),
                  diff(results$bca_ci),
                  diff(results$percentile_ci),
                  diff(results$normal_ci)),
        stringsAsFactors = FALSE
      )

      table_data <- table_data %>%
        mutate(
          Estimate = round(Estimate, 4),
          Lower_CI = round(Lower_CI, 4),
          Upper_CI = round(Upper_CI, 4),
          Width = round(Width, 4)
        )

      names(table_data) <- c("Method", "Estimate", "Lower CI", "Upper CI", "CI Width")

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
          'Method',
          target = 'row',
          backgroundColor = DT::styleEqual(
            c("BCa Bootstrap"),
            c('#FDF2F8')
          )
        )
    })

    # Bootstrap distribution plot
    output$bootstrap_dist_plot <- renderPlotly({
      req(bootstrap_results())

      results <- bootstrap_results()
      boot_dist <- results$boot_results$t[, 1]
      boot_dist <- boot_dist[!is.na(boot_dist)]

      # Create histogram
      p <- plot_ly(x = boot_dist, type = "histogram",
                   marker = list(color = '#8B5CF6', line = list(color = 'white', width = 1)),
                   name = "Bootstrap Distribution") %>%
        add_segments(
          x = results$original_estimate, xend = results$original_estimate,
          y = 0, yend = 1,
          yref = "paper",
          line = list(color = "#EF4444", width = 2, dash = "dash"),
          name = "Original Estimate"
        ) %>%
        add_segments(
          x = results$bca_ci[1], xend = results$bca_ci[1],
          y = 0, yend = 1,
          yref = "paper",
          line = list(color = "#10B981", width = 2, dash = "dot"),
          name = "BCa Lower"
        ) %>%
        add_segments(
          x = results$bca_ci[2], xend = results$bca_ci[2],
          y = 0, yend = 1,
          yref = "paper",
          line = list(color = "#10B981", width = 2, dash = "dot"),
          name = "BCa Upper"
        ) %>%
        layout(
          title = "Bootstrap Distribution of Pooled Effect",
          xaxis = list(title = "Effect Size"),
          yaxis = list(title = "Frequency"),
          showlegend = TRUE
        )

      p
    })

    # Distribution statistics
    output$distribution_stats <- renderUI({
      req(bootstrap_results())

      stats <- bootstrap_results()$boot_stats

      div(
        style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin-top: 15px;",

        h6("Distribution Statistics:", style = "color: #1F2937; margin-bottom: 15px;"),

        tags$dl(
          style = "display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin: 0;",

          tags$dt(style = "color: #6B7280;", "Mean:"),
          tags$dd(style = "color: #1F2937; font-weight: 600;", sprintf("%.4f", stats$mean)),

          tags$dt(style = "color: #6B7280;", "Median:"),
          tags$dd(style = "color: #1F2937; font-weight: 600;", sprintf("%.4f", stats$median)),

          tags$dt(style = "color: #6B7280;", "Standard Deviation:"),
          tags$dd(style = "color: #1F2937; font-weight: 600;", sprintf("%.4f", stats$sd)),

          tags$dt(style = "color: #6B7280;", "Skewness:"),
          tags$dd(style = sprintf("color: %s; font-weight: 600;",
                                  if (abs(stats$skewness) > 0.5) "#EF4444" else "#10B981"),
                  sprintf("%.3f %s", stats$skewness,
                          if (abs(stats$skewness) < 0.5) "(Symmetric)" else "(Skewed)")),

          tags$dt(style = "color: #6B7280;", "Excess Kurtosis:"),
          tags$dd(style = "color: #1F2937; font-weight: 600;",
                  sprintf("%.3f %s", stats$kurtosis,
                          if (abs(stats$kurtosis) < 1) "(Normal-like)" else "(Heavy-tailed)"))
        )
      )
    })

    # Convergence plot
    output$convergence_plot <- renderPlotly({
      req(bootstrap_results())

      boot_dist <- bootstrap_results()$boot_results$t[, 1]
      boot_dist <- boot_dist[!is.na(boot_dist)]

      # Calculate cumulative mean and SD
      n <- length(boot_dist)
      cumulative_mean <- cumsum(boot_dist) / (1:n)
      cumulative_sd <- sapply(1:n, function(i) sd(boot_dist[1:i]))

      convergence_data <- data.frame(
        iteration = 1:n,
        cumulative_mean = cumulative_mean,
        cumulative_sd = cumulative_sd
      )

      # Plot cumulative mean
      plot_ly(convergence_data, x = ~iteration) %>%
        add_lines(y = ~cumulative_mean, name = "Cumulative Mean",
                  line = list(color = '#EC4899', width = 2)) %>%
        layout(
          title = "Bootstrap Convergence Diagnostic",
          xaxis = list(title = "Bootstrap Iteration"),
          yaxis = list(title = "Cumulative Mean"),
          hovermode = "closest"
        )
    })

    # Interpretation guide
    output$interpretation_guide <- renderUI({
      req(bootstrap_results())

      results <- bootstrap_results()
      skew <- results$boot_stats$skewness

      tagList(
        div(
          style = "background: white; padding: 20px; border-radius: 8px; border: 1px solid #E5E7EB;",

          h5("Interpretation Guide:", style = "color: #1F2937; margin-bottom: 15px;"),

          h6("1. When to Trust BCa Intervals:", style = "color: #374151; margin-top: 15px;"),
          tags$ul(
            style = "color: #6B7280; line-height: 1.8;",
            tags$li(strong("Use BCa"), " when the bootstrap distribution is skewed (|skewness| > 0.5)"),
            tags$li(strong("Use BCa"), " with small samples (n < 20 studies)"),
            tags$li(strong("Use BCa"), " for important clinical or policy decisions"),
            tags$li(strong("Standard Wald OK"), " when distribution is symmetric and n ≥ 20")
          ),

          h6("2. Your Results:", style = "color: #374151; margin-top: 15px;"),
          p(
            if (abs(skew) > 0.5) {
              sprintf("Your bootstrap distribution shows %s skewness (%.2f). BCa intervals are RECOMMENDED
                      as they will provide more accurate coverage than standard Wald intervals.",
                      if (skew > 0) "positive" else "negative", skew)
            } else {
              sprintf("Your bootstrap distribution is relatively symmetric (skewness = %.2f).
                      Both BCa and standard Wald intervals should perform similarly.", skew)
            },
            style = "color: #374151; line-height: 1.6;"
          ),

          h6("3. Practical Recommendations:", style = "color: #374151; margin-top: 15px;"),
          tags$ul(
            style = "color: #6B7280; line-height: 1.8;",
            tags$li("Report BCa intervals as primary results"),
            tags$li("Compare with original Wald intervals for transparency"),
            tags$li("If BCa and Wald differ substantially, investigate why (skewness, outliers, small n)"),
            tags$li("Use ≥10,000 replications for stable BCa estimates"),
            tags$li("Bootstrap provides empirical evidence of uncertainty - no distributional assumptions")
          ),

          hr(),

          div(
            style = "background: #F9FAFB; padding: 15px; border-radius: 6px;",
            h6("Statistical Note:", style = "color: #1F2937; margin-bottom: 10px;"),
            p(
              "BCa intervals automatically adjust for both bias (difference between bootstrap mean and original estimate)
              and skewness in the sampling distribution. This makes them second-order accurate compared to
              first-order accurate percentile intervals.",
              style = "color: #6B7280; margin: 0; font-size: 14px; line-height: 1.6;"
            )
          )
        )
      )
    })
  })
}
