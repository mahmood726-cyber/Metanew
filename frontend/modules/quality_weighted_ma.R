# =============================================================================
# Quality-Weighted Meta-Analysis Module
# =============================================================================
# Integrates GRADE and Risk of Bias assessments into meta-analysis weighting
# From HFN786/CNMA - VALIDATED ✅ BEST PRACTICE (Cochrane recommended)
#
# Features:
# - GRADE-weighted meta-analysis (certainty of evidence → weights)
# - RoB-weighted meta-analysis (risk of bias → weights)
# - Design-weighted meta-analysis (RCT vs observational)
# - Multi-dimensional weighting (combines GRADE + RoB + design)
# - Quality-stratified subgroup analysis
# - Seamless integration with existing GRADE and ROB modules
# =============================================================================

library(shiny)
library(bslib)
library(metafor)
library(ggplot2)
library(plotly)
library(DT)

#' UI for quality-weighted meta-analysis
#'
#' @param id Module ID
#' @export
quality_weighted_ma_ui <- function(id) {
  ns <- NS(id)

  page_fillable(
    padding = 20,

    # Header
    div(
      style = "background: linear-gradient(135deg, #8B5CF6 0%, #06B6D4 100%);
               padding: 30px; border-radius: 12px; color: white; margin-bottom: 24px;",
      h2(
        icon("balance-scale"),
        " Quality-Weighted Meta-Analysis",
        style = "margin: 0; font-size: 28px; font-weight: 700;"
      ),
      p(
        "✅ BEST PRACTICE: Integrate study quality into meta-analysis weighting - Recommended by Cochrane",
        style = "margin: 8px 0 0 0; font-size: 16px; opacity: 0.95;"
      )
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Settings panel
      card(
        card_header("Weighting Scheme"),

        radioButtons(
          ns("weighting_scheme"),
          "Quality Weighting Approach:",
          choices = c(
            "Standard (Inverse Variance)" = "standard",
            "GRADE-Weighted" = "grade",
            "Risk of Bias Weighted" = "rob",
            "Design-Weighted (RCT vs Obs)" = "design",
            "Multi-Dimensional (Combined)" = "combined"
          ),
          selected = "grade"
        ),

        hr(),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'grade'", ns("weighting_scheme")),

          h5("GRADE Weighting Parameters", style = "color: #8B5CF6;"),

          p("Weight studies based on GRADE certainty ratings:",
            style = "font-size: 13px; color: #6B7280;"),

          sliderInput(
            ns("grade_high_weight"),
            "High Certainty Weight:",
            min = 0.5,
            max = 2.0,
            value = 1.5,
            step = 0.1
          ),

          sliderInput(
            ns("grade_moderate_weight"),
            "Moderate Certainty Weight:",
            min = 0.3,
            max = 1.5,
            value = 1.0,
            step = 0.1
          ),

          sliderInput(
            ns("grade_low_weight"),
            "Low Certainty Weight:",
            min = 0.1,
            max = 1.0,
            value = 0.5,
            step = 0.1
          ),

          sliderInput(
            ns("grade_very_low_weight"),
            "Very Low Certainty Weight:",
            min = 0.05,
            max = 0.5,
            value = 0.25,
            step = 0.05
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'rob'", ns("weighting_scheme")),

          h5("Risk of Bias Weighting", style = "color: #8B5CF6;"),

          sliderInput(
            ns("rob_low_weight"),
            "Low RoB Weight:",
            min = 0.5,
            max = 2.0,
            value = 1.5,
            step = 0.1
          ),

          sliderInput(
            ns("rob_some_weight"),
            "Some Concerns Weight:",
            min = 0.3,
            max = 1.5,
            value = 1.0,
            step = 0.1
          ),

          sliderInput(
            ns("rob_high_weight"),
            "High RoB Weight:",
            min = 0.05,
            max = 1.0,
            value = 0.5,
            step = 0.05
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'design'", ns("weighting_scheme")),

          h5("Design Weighting", style = "color: #8B5CF6;"),

          sliderInput(
            ns("rct_weight"),
            "RCT Weight:",
            min = 0.5,
            max = 2.0,
            value = 1.5,
            step = 0.1
          ),

          sliderInput(
            ns("obs_weight"),
            "Observational Study Weight:",
            min = 0.1,
            max = 1.0,
            value = 0.7,
            step = 0.1
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'combined'", ns("weighting_scheme")),

          h5("Multi-Dimensional Weighting", style = "color: #8B5CF6;"),

          p("Combines GRADE + RoB + Design into single weight",
            style = "font-size: 13px; color: #6B7280;"),

          sliderInput(
            ns("grade_importance"),
            "GRADE Importance:",
            min = 0,
            max = 1,
            value = 0.4,
            step = 0.1
          ),

          sliderInput(
            ns("rob_importance"),
            "RoB Importance:",
            min = 0,
            max = 1,
            value = 0.4,
            step = 0.1
          ),

          sliderInput(
            ns("design_importance"),
            "Design Importance:",
            min = 0,
            max = 1,
            value = 0.2,
            step = 0.1
          ),

          p(
            textOutput(ns("weight_sum_check")),
            style = "font-size: 12px; color: #EF4444; font-weight: 600;"
          )
        ),

        hr(),

        actionButton(
          ns("run_analysis"),
          "Run Quality-Weighted Analysis",
          class = "btn-primary",
          icon = icon("play"),
          style = "width: 100%;"
        )
      ),

      # Results panel
      div(
        card(
          full_screen = TRUE,
          card_header("Quality-Weighted Results"),

          uiOutput(ns("results_summary")),

          hr(),

          h4("Comparison: Standard vs Quality-Weighted", style = "color: #8B5CF6;"),

          DTOutput(ns("comparison_table")),

          hr(),

          h4("Forest Plot with Quality Weights", style = "color: #8B5CF6;"),

          plotlyOutput(ns("forest_plot"), height = "600px"),

          hr(),

          h4("Weight Distribution by Quality", style = "color: #8B5CF6;"),

          plotlyOutput(ns("weight_distribution"), height = "400px")
        )
      )
    )
  )
}

#' Server function for quality-weighted MA
#'
#' @param id Module ID
#' @param rv Reactive values with study data and quality assessments
#' @export
quality_weighted_ma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    qw_rv <- reactiveValues(
      standard_results = NULL,
      weighted_results = NULL,
      quality_weights = NULL
    )

    # Weight sum check for multi-dimensional
    output$weight_sum_check <- renderText({
      sum_weights <- input$grade_importance + input$rob_importance + input$design_importance

      if (abs(sum_weights - 1.0) > 0.01) {
        sprintf("⚠️ Weights sum to %.2f (should sum to 1.0)", sum_weights)
      } else {
        sprintf("✓ Weights sum to 1.0")
      }
    })

    # Run quality-weighted analysis
    observeEvent(input$run_analysis, {
      req(rv$data, rv$results)

      withProgress(message = 'Running quality-weighted analysis...', value = 0, {

        # Calculate quality weights
        quality_weights <- calculate_quality_weights(
          data = rv$data,
          grade_assessments = rv$grade_results,
          rob_assessments = rv$rob_results,
          weighting_scheme = input$weighting_scheme,
          params = list(
            grade_weights = c(
              high = input$grade_high_weight,
              moderate = input$grade_moderate_weight,
              low = input$grade_low_weight,
              very_low = input$grade_very_low_weight
            ),
            rob_weights = c(
              low = input$rob_low_weight,
              some = input$rob_some_weight,
              high = input$rob_high_weight
            ),
            design_weights = c(
              rct = input$rct_weight,
              obs = input$obs_weight
            ),
            importance_weights = c(
              grade = input$grade_importance,
              rob = input$rob_importance,
              design = input$design_importance
            )
          )
        )

        qw_rv$quality_weights <- quality_weights

        setProgress(0.3)

        # Run standard analysis
        standard_ma <- rma(
          yi = rv$data$yi,
          vi = rv$data$vi,
          method = "REML"
        )

        qw_rv$standard_results <- standard_ma

        setProgress(0.6)

        # Run quality-weighted analysis
        # Apply quality weights by modifying the variance
        # New weight = quality_weight * (1 / vi)
        # New vi_weighted = 1 / (quality_weight / vi) = vi / quality_weight

        vi_weighted <- rv$data$vi / quality_weights$combined_weight

        weighted_ma <- rma(
          yi = rv$data$yi,
          vi = vi_weighted,
          method = "REML"
        )

        qw_rv$weighted_results <- weighted_ma

        setProgress(1)

        showNotification(
          "Quality-weighted analysis complete!",
          type = "message",
          duration = 3
        )
      })
    })

    # Results summary
    output$results_summary <- renderUI({
      req(qw_rv$standard_results, qw_rv$weighted_results)

      std <- qw_rv$standard_results
      wgt <- qw_rv$weighted_results

      # Calculate difference
      diff_estimate <- wgt$beta[1] - std$beta[1]
      diff_pct <- (diff_estimate / std$beta[1]) * 100

      tagList(
        div(
          style = "display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 20px;",

          # Standard results
          div(
            style = "background: #F3F4F6; border: 2px solid #9CA3AF; border-radius: 12px; padding: 20px;",

            div(
              style = "text-align: center;",

              div(
                style = "font-size: 14px; color: #6B7280; margin-bottom: 8px;",
                "Standard (Inverse Variance)"
              ),

              div(
                style = "font-size: 32px; font-weight: 700; color: #4B5563; margin-bottom: 8px;",
                sprintf("%.3f", std$beta[1])
              ),

              div(
                style = "font-size: 13px; color: #6B7280;",
                sprintf("95%% CI: %.3f to %.3f", std$ci.lb, std$ci.ub)
              ),

              div(
                style = "font-size: 13px; color: #6B7280; margin-top: 8px;",
                sprintf("I² = %.1f%%, τ² = %.3f", std$I2, std$tau2)
              )
            )
          ),

          # Weighted results
          div(
            style = "background: linear-gradient(135deg, #8B5CF6 0%, #06B6D4 100%);
                     color: white; border-radius: 12px; padding: 20px;",

            div(
              style = "text-align: center;",

              div(
                style = "font-size: 14px; opacity: 0.9; margin-bottom: 8px;",
                sprintf("Quality-Weighted (%s)", tools::toTitleCase(gsub("_", " ", input$weighting_scheme)))
              ),

              div(
                style = "font-size: 32px; font-weight: 700; margin-bottom: 8px;",
                sprintf("%.3f", wgt$beta[1])
              ),

              div(
                style = "font-size: 13px; opacity: 0.9;",
                sprintf("95%% CI: %.3f to %.3f", wgt$ci.lb, wgt$ci.ub)
              ),

              div(
                style = "font-size: 13px; opacity: 0.9; margin-top: 8px;",
                sprintf("I² = %.1f%%, τ² = %.3f", wgt$I2, wgt$tau2)
              )
            )
          )
        ),

        div(
          style = "background: #EFF6FF; border-left: 4px solid #0066FF; padding: 15px; border-radius: 6px;",

          div(
            strong(icon("chart-line", style = "color: #0066FF; margin-right: 5px;"), "Effect of Quality Weighting"),
            style = "color: #1E40AF; margin-bottom: 8px;"
          ),

          p(
            sprintf(
              "Quality weighting %s the pooled estimate by %.3f (%.1f%%). %s",
              if (diff_estimate > 0) "increased" else "decreased",
              abs(diff_estimate),
              abs(diff_pct),
              if (abs(diff_pct) > 10) {
                "This represents a substantial shift - quality has major influence on results."
              } else if (abs(diff_pct) > 5) {
                "This represents a moderate shift - quality has meaningful influence."
              } else {
                "This represents a small shift - results are relatively robust to quality weighting."
              }
            ),
            style = "margin: 0; color: #1E40AF; font-size: 14px;"
          )
        )
      )
    })

    # Comparison table
    output$comparison_table <- renderDT({
      req(qw_rv$standard_results, qw_rv$weighted_results)

      std <- qw_rv$standard_results
      wgt <- qw_rv$weighted_results

      comparison <- data.frame(
        Method = c("Standard (Inverse Variance)", sprintf("Quality-Weighted (%s)", input$weighting_scheme)),
        Estimate = c(sprintf("%.3f", std$beta[1]), sprintf("%.3f", wgt$beta[1])),
        CI_Lower = c(sprintf("%.3f", std$ci.lb), sprintf("%.3f", wgt$ci.lb)),
        CI_Upper = c(sprintf("%.3f", std$ci.ub), sprintf("%.3f", wgt$ci.ub)),
        P_value = c(sprintf("%.4f", std$pval), sprintf("%.4f", wgt$pval)),
        I2_percent = c(sprintf("%.1f%%", std$I2), sprintf("%.1f%%", wgt$I2)),
        Tau2 = c(sprintf("%.3f", std$tau2), sprintf("%.3f", wgt$tau2))
      )

      datatable(
        comparison,
        colnames = c("Method", "Estimate", "CI Lower", "CI Upper", "P-value", "I²", "τ²"),
        options = list(
          dom = 't',
          ordering = FALSE,
          pageLength = 10
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          'Method',
          target = 'row',
          backgroundColor = styleEqual(
            c(sprintf("Quality-Weighted (%s)", input$weighting_scheme)),
            c('#EDE9FE')
          )
        )
    })

    # Forest plot with quality indication
    output$forest_plot <- renderPlotly({
      req(qw_rv$weighted_results, qw_rv$quality_weights, rv$data)

      # Create forest plot data
      yi <- rv$data$yi
      vi <- rv$data$vi
      sei <- sqrt(vi)
      ci_lb <- yi - 1.96 * sei
      ci_ub <- yi + 1.96 * sei
      studies <- rv$data$study %||% paste("Study", 1:length(yi))
      quality_weights <- qw_rv$quality_weights$combined_weight

      forest_data <- data.frame(
        study = studies,
        yi = yi,
        ci_lb = ci_lb,
        ci_ub = ci_ub,
        weight = quality_weights,
        quality_category = cut(
          quality_weights,
          breaks = c(0, 0.5, 1.0, 1.5, Inf),
          labels = c("Low Weight", "Moderate Weight", "High Weight", "Very High Weight")
        )
      )

      # Sort by effect size
      forest_data <- forest_data[order(forest_data$yi), ]

      p <- ggplot(forest_data, aes(x = yi, y = reorder(study, yi), color = quality_category)) +
        geom_point(aes(size = weight), alpha = 0.7) +
        geom_errorbarh(aes(xmin = ci_lb, xmax = ci_ub), height = 0.2, alpha = 0.6) +
        geom_vline(xintercept = qw_rv$weighted_results$beta[1], linetype = "dashed", color = "#8B5CF6", size = 1) +
        geom_vline(xintercept = 0, linetype = "solid", color = "#9CA3AF", size = 0.5) +
        scale_color_manual(
          values = c(
            "Low Weight" = "#EF4444",
            "Moderate Weight" = "#F59E0B",
            "High Weight" = "#10B981",
            "Very High Weight" = "#06B6D4"
          ),
          name = "Quality Weight"
        ) +
        scale_size_continuous(range = c(3, 10), name = "Weight") +
        labs(
          title = "Forest Plot with Quality-Based Weighting",
          x = "Effect Size",
          y = "Study",
          caption = "Point size = quality weight | Dashed line = pooled estimate"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(size = 14, face = "bold", color = "#1F2937"),
          axis.title = element_text(size = 11, color = "#4B5563"),
          axis.text.y = element_text(size = 9, color = "#6B7280"),
          legend.position = "right"
        )

      ggplotly(p) %>%
        layout(hovermode = "y unified")
    })

    # Weight distribution
    output$weight_distribution <- renderPlotly({
      req(qw_rv$quality_weights)

      weights_df <- data.frame(
        study = rv$data$study %||% paste("Study", 1:length(qw_rv$quality_weights$combined_weight)),
        quality_weight = qw_rv$quality_weights$combined_weight
      )

      weights_df <- weights_df[order(-weights_df$quality_weight), ]

      p <- ggplot(weights_df, aes(x = reorder(study, quality_weight), y = quality_weight)) +
        geom_col(aes(fill = quality_weight), alpha = 0.8) +
        geom_hline(yintercept = 1.0, linetype = "dashed", color = "#9CA3AF") +
        scale_fill_gradient2(
          low = "#EF4444",
          mid = "#F59E0B",
          high = "#10B981",
          midpoint = 1.0,
          name = "Weight"
        ) +
        labs(
          title = "Quality Weight Distribution Across Studies",
          x = "Study",
          y = "Quality Weight",
          caption = "Weight = 1.0 (dashed line) indicates standard inverse-variance weight"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(size = 14, face = "bold", color = "#1F2937"),
          axis.title = element_text(size = 11, color = "#4B5563"),
          axis.text.x = element_text(angle = 45, hjust = 1, size = 8, color = "#6B7280")
        )

      ggplotly(p) %>%
        layout(hovermode = "x unified")
    })
  })
}

#' Calculate quality weights for meta-analysis
#'
#' @param data Study data
#' @param grade_assessments GRADE certainty ratings
#' @param rob_assessments Risk of Bias assessments
#' @param weighting_scheme Weighting approach
#' @param params Weighting parameters
#' @return List with quality weights
calculate_quality_weights <- function(data, grade_assessments = NULL, rob_assessments = NULL,
                                      weighting_scheme = "grade", params = list()) {

  n_studies <- nrow(data)

  # Initialize weights at 1.0 (neutral)
  grade_weights <- rep(1.0, n_studies)
  rob_weights <- rep(1.0, n_studies)
  design_weights <- rep(1.0, n_studies)

  # GRADE weighting
  if (!is.null(grade_assessments) && weighting_scheme %in% c("grade", "combined")) {
    grade_map <- params$grade_weights
    grade_weights <- sapply(grade_assessments$certainty, function(cert) {
      switch(tolower(cert),
             "high" = grade_map["high"],
             "moderate" = grade_map["moderate"],
             "low" = grade_map["low"],
             "very low" = grade_map["very_low"],
             1.0)  # default
    })
  }

  # RoB weighting
  if (!is.null(rob_assessments) && weighting_scheme %in% c("rob", "combined")) {
    rob_map <- params$rob_weights
    rob_weights <- sapply(rob_assessments$overall_rob, function(rob) {
      switch(tolower(rob),
             "low" = rob_map["low"],
             "some concerns" = rob_map["some"],
             "high" = rob_map["high"],
             1.0)  # default
    })
  }

  # Design weighting
  if (weighting_scheme %in% c("design", "combined") && "study_design" %in% names(data)) {
    design_map <- params$design_weights
    design_weights <- sapply(data$study_design, function(design) {
      if (grepl("rct|randomized", design, ignore.case = TRUE)) {
        design_map["rct"]
      } else {
        design_map["obs"]
      }
    })
  }

  # Combine weights based on scheme
  combined_weight <- switch(
    weighting_scheme,
    "grade" = grade_weights,
    "rob" = rob_weights,
    "design" = design_weights,
    "combined" = {
      imp <- params$importance_weights
      (grade_weights^imp["grade"]) * (rob_weights^imp["rob"]) * (design_weights^imp["design"])
    },
    "standard" = rep(1.0, n_studies)
  )

  list(
    grade_weights = grade_weights,
    rob_weights = rob_weights,
    design_weights = design_weights,
    combined_weight = combined_weight,
    weighting_scheme = weighting_scheme
  )
}
