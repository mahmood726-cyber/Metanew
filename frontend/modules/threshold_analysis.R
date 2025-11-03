# =============================================================================
# Threshold Analysis Module
# =============================================================================
# ✅ STANDARD - Recommended by sensitivity analysis guidelines
#
# Features:
# - "How wrong would results need to be to change conclusions?"
# - Statistical significance thresholds
# - Clinical significance thresholds (MCID)
# - Robustness regions
# - Fragility analysis
# - Decision stability assessment
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(metafor)
library(dplyr)

#' Calculate threshold for statistical significance
#'
#' @param ma_result Meta-analysis result from rma()
#' @param alpha Significance level (default 0.05)
#' @return Threshold effect size for significance
#' @export
calculate_statistical_threshold <- function(ma_result, alpha = 0.05) {

  # Critical z-value for two-sided test
  z_crit <- qnorm(1 - alpha/2)

  # Current estimate and SE
  estimate <- as.numeric(ma_result$b)
  se <- ma_result$se

  # Threshold: estimate where CI just touches zero
  # For positive effects: threshold = z_crit * SE
  # For negative effects: threshold = -z_crit * SE

  if (estimate > 0) {
    threshold <- z_crit * se
    distance <- estimate - threshold
  } else {
    threshold <- -z_crit * se
    distance <- abs(estimate) - abs(threshold)
  }

  # How much would estimate need to change?
  pct_change <- (distance / abs(estimate)) * 100

  list(
    current_estimate = estimate,
    threshold = threshold,
    distance_to_threshold = distance,
    pct_change_needed = pct_change,
    robust = distance > 0,  # TRUE if currently significant
    se = se,
    ci_lower = ma_result$ci.lb,
    ci_upper = ma_result$ci.ub
  )
}

#' Calculate threshold for clinical significance
#'
#' @param ma_result Meta-analysis result
#' @param mcid Minimum clinically important difference
#' @return Threshold analysis for clinical significance
#' @export
calculate_clinical_threshold <- function(ma_result, mcid) {

  estimate <- as.numeric(ma_result$b)
  ci_lower <- ma_result$ci.lb
  ci_upper <- ma_result$ci.ub

  # Is effect clinically significant?
  # For positive effects: CI lower bound > MCID
  # For negative effects: CI upper bound < -MCID

  if (estimate > 0) {
    clinically_significant <- ci_lower > mcid
    distance_to_mcid <- estimate - mcid
    ci_distance_to_mcid <- ci_lower - mcid
  } else {
    clinically_significant <- ci_upper < -mcid
    distance_to_mcid <- abs(estimate) - mcid
    ci_distance_to_mcid <- abs(ci_upper) - mcid
  }

  # How much would estimate need to decrease to lose clinical significance?
  pct_change <- (distance_to_mcid / abs(estimate)) * 100

  list(
    current_estimate = estimate,
    mcid = mcid,
    clinically_significant = clinically_significant,
    distance_to_mcid = distance_to_mcid,
    ci_distance_to_mcid = ci_distance_to_mcid,
    pct_change_needed = pct_change,
    ci_lower = ci_lower,
    ci_upper = ci_upper
  )
}

#' Fragility analysis - how many studies needed to flip conclusion
#'
#' @param data Data frame with yi and vi
#' @param ma_result Meta-analysis result
#' @param alpha Significance level
#' @return Fragility index and analysis
#' @export
calculate_fragility_index <- function(data, ma_result, alpha = 0.05) {

  current_p <- ma_result$pval
  is_significant <- current_p < alpha

  if (!is_significant) {
    # If not significant, calculate how many studies needed to become significant
    # This is complex - return NA for now
    return(list(
      fragility_index = NA,
      direction = "not_applicable",
      interpretation = "Result is not statistically significant"
    ))
  }

  # If significant, calculate how many studies with null effect would make it non-significant
  # Add hypothetical studies with effect = 0

  fragility_index <- 0
  max_attempts <- 50  # Don't search forever

  for (i in 1:max_attempts) {
    # Add i null studies with median variance
    median_vi <- median(data$vi)

    null_data <- data.frame(
      yi = rep(0, i),
      vi = rep(median_vi, i)
    )

    combined_data <- rbind(data, null_data)

    # Re-run MA
    new_ma <- tryCatch({
      rma(yi = combined_data$yi, vi = combined_data$vi, method = ma_result$method)
    }, error = function(e) {
      NULL
    })

    if (!is.null(new_ma)) {
      if (new_ma$pval >= alpha) {
        fragility_index <- i
        break
      }
    }
  }

  if (fragility_index == 0) {
    fragility_index <- max_attempts
    interpretation <- sprintf("Very robust - requires > %d null studies to lose significance", max_attempts)
  } else {
    interpretation <- sprintf("Adding %d null studies would make result non-significant", fragility_index)
  }

  list(
    fragility_index = fragility_index,
    direction = "null_studies",
    interpretation = interpretation,
    robust = fragility_index > 5  # Rule of thumb: FI > 5 is robust
  )
}

#' UI for threshold analysis
#'
#' @param id Module ID
#' @export
threshold_analysis_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      div(
        "Threshold Analysis - Decision Robustness",
        span("✅ STANDARD",
             style = "background: #10B981; color: white; padding: 3px 8px;
                      border-radius: 4px; font-size: 11px; margin-left: 10px;")
      )
    ),

    p(
      "Assess how robust your conclusions are by identifying critical thresholds: 'How wrong would the results need to be to change our conclusions?'",
      style = "color: #6B7280; margin-bottom: 20px;"
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Controls
      div(
        h5("Threshold Settings", style = "color: #EC4899; margin-bottom: 15px;"),

        numericInput(
          ns("alpha"),
          "Significance Level (α):",
          value = 0.05,
          min = 0.001,
          max = 0.2,
          step = 0.01
        ),

        numericInput(
          ns("mcid"),
          "Minimum Clinically Important Difference (MCID):",
          value = 0.2,
          step = 0.05
        ),

        selectInput(
          ns("ma_method"),
          "Meta-Analysis Method:",
          choices = c(
            "REML" = "REML",
            "DerSimonian-Laird" = "DL",
            "Fixed Effect" = "FE"
          ),
          selected = "REML"
        ),

        checkboxGroupInput(
          ns("analyses"),
          "Threshold Analyses:",
          choices = c(
            "Statistical Significance" = "statistical",
            "Clinical Significance (MCID)" = "clinical",
            "Fragility Index" = "fragility"
          ),
          selected = c("statistical", "clinical", "fragility")
        ),

        hr(),

        actionButton(
          ns("run_threshold"),
          "Run Threshold Analysis",
          class = "btn-primary",
          icon = icon("crosshairs"),
          style = "width: 100%;"
        ),

        br(), br(),

        div(
          style = "background: #EFF6FF; border-left: 4px solid #3B82F6;
                   padding: 12px; border-radius: 6px;",
          div(
            strong(icon("info-circle", style = "color: #3B82F6; margin-right: 5px;"),
                   "What is Threshold Analysis?"),
            style = "color: #1E40AF; margin-bottom: 8px;"
          ),
          tags$ul(
            style = "margin: 0; color: #1E40AF; font-size: 13px;",
            tags$li("Quantifies decision robustness"),
            tags$li("Identifies critical effect sizes"),
            tags$li("Assesses fragility to changes"),
            tags$li("Supports sensitivity analysis"),
            tags$li("Essential for HTA decisions")
          )
        )
      ),

      # Results
      div(
        h5("Threshold Analysis Results", style = "color: #EC4899; margin-bottom: 15px;"),

        uiOutput(ns("threshold_summary")),

        br(),

        tabsetPanel(
          id = ns("results_tabs"),

          tabPanel(
            "Statistical Threshold",
            br(),
            plotlyOutput(ns("statistical_threshold_plot"), height = "400px"),
            br(),
            uiOutput(ns("statistical_interpretation"))
          ),

          tabPanel(
            "Clinical Threshold",
            br(),
            plotlyOutput(ns("clinical_threshold_plot"), height = "400px"),
            br(),
            uiOutput(ns("clinical_interpretation"))
          ),

          tabPanel(
            "Fragility Analysis",
            br(),
            plotlyOutput(ns("fragility_plot"), height = "400px"),
            br(),
            uiOutput(ns("fragility_interpretation"))
          ),

          tabPanel(
            "Robustness Map",
            br(),
            plotlyOutput(ns("robustness_map"), height = "500px"),
            br(),
            p("Shows regions of statistical and clinical significance.",
              style = "color: #6B7280; font-size: 13px;")
          ),

          tabPanel(
            "Decision Guide",
            br(),
            uiOutput(ns("decision_guide"))
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
               "Interpretation Guide"),
        style = "color: #92400E; margin-bottom: 8px;"
      ),

      tags$ul(
        style = "margin: 0; color: #92400E; font-size: 14px;",
        tags$li(strong("Fragility Index < 3:"), " Results are fragile - small changes could flip conclusions"),
        tags$li(strong("Fragility Index 3-10:"), " Moderate robustness - interpret with appropriate caution"),
        tags$li(strong("Fragility Index > 10:"), " Robust results - unlikely to change with minor modifications"),
        tags$li(strong("Distance to MCID:"), " Large distance = confident in clinical importance"),
        tags$li(strong("Threshold %:"), " Smaller % = more fragile to changes in estimates")
      )
    )
  )
}

#' Server for threshold analysis
#'
#' @param id Module ID
#' @param rv Reactive values with meta-analysis data
#' @export
threshold_analysis_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    threshold_results <- reactiveVal(NULL)

    # Run threshold analysis
    observeEvent(input$run_threshold, {

      req(rv$data)
      req(rv$data$yi, rv$data$vi)

      withProgress(message = 'Running threshold analysis...', value = 0, {

        setProgress(0.3, detail = "Calculating meta-analysis...")

        # Run meta-analysis
        ma_result <- rma(
          yi = rv$data$yi,
          vi = rv$data$vi,
          method = input$ma_method
        )

        results <- list(
          ma_result = ma_result
        )

        # Statistical threshold
        if ("statistical" %in% input$analyses) {
          setProgress(0.5, detail = "Calculating statistical threshold...")
          results$statistical <- calculate_statistical_threshold(ma_result, input$alpha)
        }

        # Clinical threshold
        if ("clinical" %in% input$analyses) {
          setProgress(0.7, detail = "Calculating clinical threshold...")
          results$clinical <- calculate_clinical_threshold(ma_result, input$mcid)
        }

        # Fragility index
        if ("fragility" %in% input$analyses) {
          setProgress(0.9, detail = "Calculating fragility index...")
          results$fragility <- calculate_fragility_index(rv$data, ma_result, input$alpha)
        }

        results$alpha <- input$alpha
        results$mcid <- input$mcid

        threshold_results(results)

        setProgress(1)
      })
    })

    # Summary display
    output$threshold_summary <- renderUI({
      req(threshold_results())

      results <- threshold_results()

      # Overall robustness score (0-100)
      robustness_components <- c()

      if (!is.null(results$statistical)) {
        stat_robust <- if (results$statistical$robust) 1 else 0
        robustness_components <- c(robustness_components, stat_robust * 40)
      }

      if (!is.null(results$clinical)) {
        clin_robust <- if (results$clinical$clinically_significant) 1 else 0
        robustness_components <- c(robustness_components, clin_robust * 30)
      }

      if (!is.null(results$fragility)) {
        if (!is.na(results$fragility$fragility_index)) {
          frag_score <- min(results$fragility$fragility_index / 10, 1) * 30
          robustness_components <- c(robustness_components, frag_score)
        }
      }

      overall_robustness <- sum(robustness_components)

      robustness_color <- if (overall_robustness >= 70) "#10B981"
                          else if (overall_robustness >= 40) "#F59E0B"
                          else "#EF4444"

      robustness_text <- if (overall_robustness >= 70) "ROBUST"
                         else if (overall_robustness >= 40) "MODERATE"
                         else "FRAGILE"

      tagList(
        div(
          style = sprintf("background: linear-gradient(135deg, %s 0%%, #8B5CF6 100%%);
                           color: white; padding: 25px; border-radius: 12px;",
                          robustness_color),

          div(
            style = "text-align: center;",

            div(
              style = "font-size: 14px; margin-bottom: 8px; opacity: 0.9;",
              "Overall Robustness Score"
            ),

            div(
              style = "font-size: 48px; font-weight: 700; margin-bottom: 10px;",
              sprintf("%.0f/100", overall_robustness)
            ),

            div(
              style = "font-size: 20px; font-weight: 600; opacity: 0.95; margin-bottom: 15px;",
              robustness_text
            ),

            div(
              style = "font-size: 14px; opacity: 0.9;",
              sprintf("Estimate: %.3f | Method: %s",
                      as.numeric(results$ma_result$b),
                      results$ma_result$method)
            )
          )
        ),

        br(),

        div(
          style = "display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px;",

          if (!is.null(results$statistical)) {
            div(
              style = sprintf("background: white; border: 2px solid %s; border-radius: 8px; padding: 15px; text-align: center;",
                              if (results$statistical$robust) "#10B981" else "#EF4444"),
              div(style = "color: #6B7280; font-size: 12px; margin-bottom: 5px;", "Statistical"),
              div(style = sprintf("color: %s; font-size: 20px; font-weight: 700;",
                                   if (results$statistical$robust) "#10B981" else "#EF4444"),
                  if (results$statistical$robust) "Significant" else "Not Significant"),
              div(style = "color: #6B7280; font-size: 11px; margin-top: 3px;",
                  sprintf("%.1f%% buffer", results$statistical$pct_change_needed))
            )
          },

          if (!is.null(results$clinical)) {
            div(
              style = sprintf("background: white; border: 2px solid %s; border-radius: 8px; padding: 15px; text-align: center;",
                              if (results$clinical$clinically_significant) "#10B981" else "#F59E0B"),
              div(style = "color: #6B7280; font-size: 12px; margin-bottom: 5px;", "Clinical (MCID)"),
              div(style = sprintf("color: %s; font-size: 20px; font-weight: 700;",
                                   if (results$clinical$clinically_significant) "#10B981" else "#F59E0B"),
                  if (results$clinical$clinically_significant) "Important" else "Unclear"),
              div(style = "color: #6B7280; font-size: 11px; margin-top: 3px;",
                  sprintf("Distance: %.3f", results$clinical$distance_to_mcid))
            )
          },

          if (!is.null(results$fragility) && !is.na(results$fragility$fragility_index)) {
            div(
              style = sprintf("background: white; border: 2px solid %s; border-radius: 8px; padding: 15px; text-align: center;",
                              if (results$fragility$robust) "#10B981" else "#EF4444"),
              div(style = "color: #6B7280; font-size: 12px; margin-bottom: 5px;", "Fragility Index"),
              div(style = sprintf("color: %s; font-size: 24px; font-weight: 700;",
                                   if (results$fragility$robust) "#10B981" else "#EF4444"),
                  results$fragility$fragility_index),
              div(style = "color: #6B7280; font-size: 11px; margin-top: 3px;",
                  if (results$fragility$robust) "Robust" else "Fragile")
            )
          }
        )
      )
    })

    # Statistical threshold plot
    output$statistical_threshold_plot <- renderPlotly({
      req(threshold_results())
      req(threshold_results()$statistical)

      stat <- threshold_results()$statistical

      # Create plot showing current estimate, CI, and threshold
      plot_data <- data.frame(
        category = c("Threshold for\nSignificance", "Current\nEstimate"),
        estimate = c(stat$threshold, stat$current_estimate),
        lower = c(NA, stat$ci_lower),
        upper = c(NA, stat$ci_upper),
        color = c("#F59E0B", "#8B5CF6")
      )

      p <- plot_ly() %>%
        # Current estimate with CI
        add_segments(
          data = plot_data[2, ],
          x = ~lower, xend = ~upper,
          y = ~category, yend = ~category,
          line = list(color = '#8B5CF6', width = 8),
          name = '95% CI'
        ) %>%
        add_markers(
          data = plot_data[2, ],
          x = ~estimate,
          y = ~category,
          marker = list(size = 16, color = '#EC4899', symbol = 'diamond',
                       line = list(color = 'white', width = 2)),
          name = 'Estimate'
        ) %>%
        # Threshold
        add_markers(
          data = plot_data[1, ],
          x = ~estimate,
          y = ~category,
          marker = list(size = 16, color = '#F59E0B', symbol = 'x',
                       line = list(color = 'white', width = 2)),
          name = 'Threshold'
        ) %>%
        # Zero line
        add_segments(
          x = 0, xend = 0,
          y = 0.5, yend = 2.5,
          line = list(color = '#1F2937', width = 2, dash = 'dot'),
          name = 'Null Effect'
        ) %>%
        layout(
          title = "Statistical Significance Threshold",
          xaxis = list(title = "Effect Size", zeroline = FALSE),
          yaxis = list(title = ""),
          showlegend = FALSE,
          margin = list(l = 150)
        )

      p
    })

    # Statistical interpretation
    output$statistical_interpretation <- renderUI({
      req(threshold_results())
      req(threshold_results()$statistical)

      stat <- threshold_results()$statistical

      div(
        style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin-top: 15px;",

        h6("Statistical Threshold Analysis:", style = "color: #1F2937; margin-bottom: 15px;"),

        tags$dl(
          style = "display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 15px;",

          tags$dt(style = "color: #6B7280;", "Current Estimate:"),
          tags$dd(style = "color: #1F2937; font-weight: 600;", sprintf("%.3f", stat$current_estimate)),

          tags$dt(style = "color: #6B7280;", "Significance Threshold:"),
          tags$dd(style = "color: #F59E0B; font-weight: 600;", sprintf("%.3f", stat$threshold)),

          tags$dt(style = "color: #6B7280;", "Distance to Threshold:"),
          tags$dd(style = sprintf("color: %s; font-weight: 600;",
                                  if (stat$robust) "#10B981" else "#EF4444"),
                  sprintf("%.3f (%.1f%%)", stat$distance_to_threshold, stat$pct_change_needed)),

          tags$dt(style = "color: #6B7280;", "Currently Significant?"),
          tags$dd(style = sprintf("color: %s; font-weight: 600;",
                                  if (stat$robust) "#10B981" else "#EF4444"),
                  if (stat$robust) "Yes" else "No")
        ),

        hr(),

        p(
          strong("Interpretation: "),
          if (stat$robust) {
            sprintf("The effect estimate (%.3f) would need to decrease by %.1f%% to lose statistical significance. This suggests moderate-to-strong robustness.",
                    stat$current_estimate, stat$pct_change_needed)
          } else {
            sprintf("The effect estimate (%.3f) is not statistically significant at α = %.2f. The estimate would need to increase by %.1f%% to become significant.",
                    stat$current_estimate, threshold_results()$alpha, abs(stat$pct_change_needed))
          },
          style = "color: #374151; margin: 0; line-height: 1.6;"
        )
      )
    })

    # Clinical threshold plot
    output$clinical_threshold_plot <- renderPlotly({
      req(threshold_results())
      req(threshold_results()$clinical)

      clin <- threshold_results()$clinical

      # Create zones for clinical significance
      plot_data <- data.frame(
        category = c("MCID", "Lower CI", "Estimate", "Upper CI"),
        value = c(clin$mcid, clin$ci_lower, clin$current_estimate, clin$ci_upper),
        color = c("#F59E0B", "#8B5CF6", "#EC4899", "#8B5CF6")
      )

      p <- plot_ly(data = plot_data) %>%
        add_bars(
          x = ~value,
          y = ~category,
          orientation = 'h',
          marker = list(color = ~color),
          text = ~sprintf("%.3f", value),
          textposition = 'outside',
          showlegend = FALSE
        ) %>%
        layout(
          title = "Clinical Significance Threshold (MCID)",
          xaxis = list(title = "Effect Size", zeroline = TRUE),
          yaxis = list(title = ""),
          margin = list(l = 100)
        )

      p
    })

    # Clinical interpretation
    output$clinical_interpretation <- renderUI({
      req(threshold_results())
      req(threshold_results()$clinical)

      clin <- threshold_results()$clinical

      div(
        style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin-top: 15px;",

        h6("Clinical Significance Analysis:", style = "color: #1F2937; margin-bottom: 15px;"),

        tags$dl(
          style = "display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 15px;",

          tags$dt(style = "color: #6B7280;", "Current Estimate:"),
          tags$dd(style = "color: #1F2937; font-weight: 600;", sprintf("%.3f", clin$current_estimate)),

          tags$dt(style = "color: #6B7280;", "MCID:"),
          tags$dd(style = "color: #F59E0B; font-weight: 600;", sprintf("%.3f", clin$mcid)),

          tags$dt(style = "color: #6B7280;", "Distance to MCID:"),
          tags$dd(style = "color: #1F2937; font-weight: 600;", sprintf("%.3f", clin$distance_to_mcid)),

          tags$dt(style = "color: #6B7280;", "CI Distance to MCID:"),
          tags$dd(style = sprintf("color: %s; font-weight: 600;",
                                  if (clin$ci_distance_to_mcid > 0) "#10B981" else "#EF4444"),
                  sprintf("%.3f", clin$ci_distance_to_mcid)),

          tags$dt(style = "color: #6B7280;", "Clinically Important?"),
          tags$dd(style = sprintf("color: %s; font-weight: 600;",
                                  if (clin$clinically_significant) "#10B981" else "#F59E0B"),
                  if (clin$clinically_significant) "Yes (CI > MCID)" else "Uncertain (CI crosses MCID)")
        ),

        hr(),

        p(
          strong("Interpretation: "),
          if (clin$clinically_significant) {
            sprintf("The confidence interval lower bound (%.3f) exceeds the MCID (%.3f). We can be confident the effect is clinically important.",
                    clin$ci_lower, clin$mcid)
          } else {
            sprintf("The confidence interval includes values below the MCID. Clinical importance is uncertain. The estimate would need to increase by %.1f%% for confident clinical significance.",
                    clin$current_estimate, abs(clin$pct_change_needed))
          },
          style = "color: #374151; margin: 0; line-height: 1.6;"
        )
      )
    })

    # Fragility plot
    output$fragility_plot <- renderPlotly({
      req(threshold_results())
      req(threshold_results()$fragility)
      req(!is.na(threshold_results()$fragility$fragility_index))

      frag <- threshold_results()$fragility

      # Simulate adding null studies
      n_studies <- nrow(rv$data)
      n_null_range <- 0:min(frag$fragility_index + 5, 30)

      # Create visual representation
      plot_data <- data.frame(
        n_null_studies = n_null_range,
        significant = ifelse(n_null_range < frag$fragility_index, "Yes", "No")
      )

      p <- plot_ly(data = plot_data) %>%
        add_bars(
          x = ~n_null_studies,
          y = rep(1, length(n_null_range)),
          marker = list(
            color = ~ifelse(significant == "Yes", '#10B981', '#EF4444'),
            line = list(color = 'white', width = 1)
          ),
          showlegend = FALSE
        ) %>%
        add_segments(
          x = frag$fragility_index, xend = frag$fragility_index,
          y = 0, yend = 1.2,
          line = list(color = '#1F2937', width = 3, dash = 'dash'),
          name = 'Fragility Threshold'
        ) %>%
        layout(
          title = sprintf("Fragility Index = %d", frag$fragility_index),
          xaxis = list(title = "Number of Null Studies Added"),
          yaxis = list(title = "", showticklabels = FALSE),
          annotations = list(
            list(
              x = frag$fragility_index,
              y = 1.3,
              text = sprintf("Significance lost\nat %d null studies", frag$fragility_index),
              showarrow = FALSE,
              font = list(size = 12, color = "#1F2937")
            )
          )
        )

      p
    })

    # Fragility interpretation
    output$fragility_interpretation <- renderUI({
      req(threshold_results())
      req(threshold_results()$fragility)

      frag <- threshold_results()$fragility

      if (is.na(frag$fragility_index)) {
        return(
          div(
            style = "background: #F3F4F6; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin-top: 15px;",
            p("Fragility analysis not applicable for non-significant results.",
              style = "color: #6B7280; margin: 0;")
          )
        )
      }

      div(
        style = "background: white; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin-top: 15px;",

        h6("Fragility Analysis:", style = "color: #1F2937; margin-bottom: 15px;"),

        div(
          style = sprintf("background: %s; border-left: 4px solid %s; padding: 15px; border-radius: 6px; margin-bottom: 15px;",
                          if (frag$robust) "#D1FAE5" else "#FEE2E2",
                          if (frag$robust) "#10B981" else "#EF4444"),
          p(
            strong(sprintf("Fragility Index: %d", frag$fragility_index)),
            br(),
            frag$interpretation,
            style = sprintf("color: %s; margin: 0; line-height: 1.6;",
                            if (frag$robust) "#065F46" else "#991B1B")
          )
        ),

        p(
          strong("Interpretation: "),
          if (frag$robust) {
            sprintf("A fragility index of %d suggests robust findings. It would require adding %d studies with null effects (effect size = 0) to lose statistical significance.",
                    frag$fragility_index, frag$fragility_index)
          } else {
            sprintf("A fragility index of %d suggests fragile findings. Adding just %d studies with null effects would make the result non-significant. Interpret with caution.",
                    frag$fragility_index, frag$fragility_index)
          },
          style = "color: #374151; margin: 0; line-height: 1.6;"
        )
      )
    })

    # Robustness map
    output$robustness_map <- renderPlotly({
      req(threshold_results())

      # Create 2D map showing regions of statistical and clinical significance
      effect_range <- seq(-1, 1, by = 0.02)
      se_range <- seq(0.01, 0.5, by = 0.01)

      grid <- expand.grid(effect = effect_range, se = se_range)

      # Calculate significance zones
      z_crit <- qnorm(1 - threshold_results()$alpha/2)
      mcid <- threshold_results()$mcid

      grid$statistical_sig <- abs(grid$effect) > z_crit * grid$se
      grid$clinical_sig <- abs(grid$effect) > mcid

      grid$zone <- ifelse(grid$statistical_sig & grid$clinical_sig, "Both Significant",
                   ifelse(grid$statistical_sig, "Statistically Significant Only",
                   ifelse(grid$clinical_sig, "Clinically Important Only", "Neither")))

      # Current estimate
      current_effect <- as.numeric(threshold_results()$ma_result$b)
      current_se <- threshold_results()$ma_result$se

      p <- plot_ly(
        data = grid,
        x = ~effect,
        y = ~se,
        z = ~as.numeric(factor(zone)),
        type = "contour",
        colorscale = list(
          c(0, '#FEE2E2'),
          c(0.33, '#FEF3C7'),
          c(0.67, '#DBEAFE'),
          c(1, '#D1FAE5')
        ),
        showscale = FALSE
      ) %>%
        add_markers(
          x = current_effect,
          y = current_se,
          marker = list(size = 15, color = '#EC4899', symbol = 'star',
                       line = list(color = 'white', width = 2)),
          name = 'Current Estimate',
          showlegend = TRUE
        ) %>%
        layout(
          title = "Robustness Map: Statistical & Clinical Significance Zones",
          xaxis = list(title = "Effect Size", zeroline = TRUE),
          yaxis = list(title = "Standard Error")
        )

      p
    })

    # Decision guide
    output$decision_guide <- renderUI({
      req(threshold_results())

      results <- threshold_results()

      # Determine overall recommendation
      stat_sig <- if (!is.null(results$statistical)) results$statistical$robust else NA
      clin_sig <- if (!is.null(results$clinical)) results$clinical$clinically_significant else NA
      frag_robust <- if (!is.null(results$fragility) && !is.na(results$fragility$fragility_index)) {
        results$fragility$robust
      } else {
        NA
      }

      tagList(
        div(
          style = "background: white; padding: 20px; border-radius: 8px; border: 1px solid #E5E7EB;",

          h5("Decision-Making Guide:", style = "color: #1F2937; margin-bottom: 15px;"),

          h6("Summary of Findings:", style = "color: #374151; margin-top: 15px;"),
          tags$ul(
            style = "color: #6B7280; line-height: 1.8;",

            if (!is.na(stat_sig)) {
              tags$li(
                strong("Statistical Significance: "),
                if (stat_sig) {
                  sprintf("Effect is statistically significant with %.1f%% buffer to threshold. Robust to moderate changes.",
                          results$statistical$pct_change_needed)
                } else {
                  "Effect is not statistically significant. Results sensitive to changes."
                }
              )
            },

            if (!is.na(clin_sig)) {
              tags$li(
                strong("Clinical Significance: "),
                if (clin_sig) {
                  sprintf("Effect exceeds MCID (%.3f). Clinically important with confidence.",
                          results$mcid)
                } else {
                  sprintf("Uncertain if effect is clinically important. CI includes values below MCID (%.3f).",
                          results$mcid)
                }
              )
            },

            if (!is.na(frag_robust)) {
              tags$li(
                strong("Fragility: "),
                if (frag_robust) {
                  sprintf("Fragility index of %d suggests robust findings.",
                          results$fragility$fragility_index)
                } else {
                  sprintf("Fragility index of %d suggests results are fragile to changes.",
                          results$fragility$fragility_index)
                }
              )
            }
          ),

          h6("Recommendations:", style = "color: #374151; margin-top: 20px;"),

          if (!is.na(stat_sig) && !is.na(clin_sig)) {
            if (stat_sig && clin_sig) {
              div(
                style = "background: #D1FAE5; border-left: 4px solid #10B981; padding: 15px; border-radius: 6px;",
                p(
                  strong("Strong Evidence: "),
                  "Results are both statistically significant and clinically important. Proceed with implementation, monitoring outcomes.",
                  style = "color: #065F46; margin: 0; line-height: 1.6;"
                )
              )
            } else if (stat_sig && !clin_sig) {
              div(
                style = "background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 15px; border-radius: 6px;",
                p(
                  strong("Uncertain Clinical Importance: "),
                  "Statistically significant but clinical importance unclear. Consider patient values, costs, and alternatives before implementation.",
                  style = "color: #92400E; margin: 0; line-height: 1.6;"
                )
              )
            } else {
              div(
                style = "background: #FEE2E2; border-left: 4px solid #EF4444; padding: 15px; border-radius: 6px;",
                p(
                  strong("Insufficient Evidence: "),
                  "Results do not provide strong evidence for effect. Consider additional research before implementation.",
                  style = "color: #991B1B; margin: 0; line-height: 1.6;"
                )
              )
            }
          },

          hr(),

          div(
            style = "background: #F9FAFB; padding: 15px; border-radius: 6px;",
            h6("Next Steps:", style = "color: #1F2937; margin-bottom: 10px;"),
            tags$ol(
              style = "color: #6B7280; line-height: 1.8; margin: 0;",
              tags$li("Review all threshold analyses for consistency"),
              tags$li("Consider conducting additional sensitivity analyses"),
              tags$li("Assess external validity and generalizability"),
              tags$li("Document robustness findings in report"),
              tags$li("Use findings to inform strength of recommendations")
            )
          )
        )
      )
    })
  })
}
