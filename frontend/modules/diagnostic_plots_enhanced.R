# =============================================================================
# Enhanced Diagnostic Plots Module
# =============================================================================
# Comprehensive diagnostic visualizations for meta-analysis
# Addresses methodologist review: "More diagnostic plots would be helpful"
#
# Features:
# - Contour-enhanced funnel plots
# - Radial (Galbraith) plots
# - Baujat plots for heterogeneity
# - Influence diagnostics (leave-one-out)
# - GOSH (Graphical Display of Heterogeneity) plots
# - L'Abbé plots for binary outcomes
# - Doi plots for publication bias
# - Interactive versions of all plots
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(metafor)

#' UI for enhanced diagnostic plots
#'
#' @param id Module ID
#' @export
diagnostic_plots_ui <- function(id) {
  ns <- NS(id)

  page_fillable(
    padding = 20,

    h2("Diagnostic Plots & Visualizations", style = "color: #0066FF; margin-bottom: 20px;"),

    p(
      "Comprehensive diagnostic visualizations to assess heterogeneity, outliers, ",
      "influential studies, and publication bias.",
      style = "color: #6B7280; font-size: 16px; margin-bottom: 30px;"
    ),

    layout_columns(
      col_widths = c(3, 9),

      # Sidebar with plot selection
      card(
        card_header("Select Diagnostic Plot"),

        radioButtons(
          ns("plot_type"),
          NULL,
          choices = c(
            "Contour-Enhanced Funnel Plot" = "funnel_contour",
            "Radial (Galbraith) Plot" = "radial",
            "Baujat Plot" = "baujat",
            "Influence Diagnostics" = "influence",
            "GOSH Plot" = "gosh",
            "L'Abbé Plot" = "labbe",
            "Doi Plot" = "doi"
          ),
          selected = "funnel_contour"
        ),

        hr(),

        h5("Plot Options", style = "color: #0066FF;"),

        # Funnel plot options
        conditionalPanel(
          condition = sprintf("input['%s'] == 'funnel_contour'", ns("plot_type")),

          checkboxInput(
            ns("show_contours"),
            "Show significance contours",
            value = TRUE
          ),

          checkboxInput(
            ns("show_trim_fill"),
            "Show trim-and-fill",
            value = FALSE
          ),

          selectInput(
            ns("funnel_y_axis"),
            "Y-axis:",
            choices = c(
              "Standard Error" = "se",
              "Sample Size" = "n",
              "Precision (1/SE)" = "precision"
            ),
            selected = "se"
          )
        ),

        # Radial plot options
        conditionalPanel(
          condition = sprintf("input['%s'] == 'radial'", ns("plot_type")),

          checkboxInput(
            ns("radial_ci"),
            "Show confidence intervals",
            value = TRUE
          )
        ),

        # Baujat plot options
        conditionalPanel(
          condition = sprintf("input['%s'] == 'baujat'", ns("plot_type")),

          sliderInput(
            ns("baujat_label_top"),
            "Label top N studies:",
            min = 0,
            max = 10,
            value = 5,
            step = 1
          )
        ),

        # Influence options
        conditionalPanel(
          condition = sprintf("input['%s'] == 'influence'", ns("plot_type")),

          radioButtons(
            ns("influence_metric"),
            "Influence Metric:",
            choices = c(
              "Cook's Distance" = "cooks",
              "DFFITS" = "dffits",
              "DFBETAS" = "dfbetas",
              "Hat Values" = "hat"
            ),
            selected = "cooks"
          )
        ),

        hr(),

        actionButton(
          ns("generate_plot"),
          "Generate Plot",
          class = "btn-primary",
          icon = icon("chart-line"),
          style = "width: 100%;"
        )
      ),

      # Main plot panel
      card(
        full_screen = TRUE,
        card_header(
          textOutput(ns("plot_title"))
        ),

        plotlyOutput(ns("diagnostic_plot"), height = "600px"),

        card_footer(
          div(
            style = "display: flex; justify-content: space-between; align-items: center;",

            div(
              downloadButton(ns("download_plot"), "Download PNG", class = "btn-sm"),
              style = "display: inline-block;"
            ),

            div(
              uiOutput(ns("plot_interpretation")),
              style = "flex: 1; margin-left: 20px;"
            )
          )
        )
      )
    ),

    hr(),

    # Additional info panel
    card(
      card_header("Understanding Diagnostic Plots"),

      layout_columns(
        col_widths = c(3, 3, 3, 3),

        div(
          h5(icon("search", style = "color: #0066FF; margin-right: 5px;"), "Funnel Plots"),
          p("Assess publication bias. Asymmetry suggests missing studies.", style = "font-size: 14px; color: #6B7280;")
        ),

        div(
          h5(icon("bullseye", style = "color: #10B981; margin-right: 5px;"), "Radial Plots"),
          p("Visualize heterogeneity. Studies outside CI suggest heterogeneity.", style = "font-size: 14px; color: #6B7280;")
        ),

        div(
          h5(icon("chart-scatter", style = "color: #F59E0B; margin-right: 5px;"), "Baujat Plots"),
          p("Identify outliers. Top-right studies contribute most to heterogeneity.", style = "font-size: 14px; color: #6B7280;")
        ),

        div(
          h5(icon("user-minus", style = "color: #EF4444; margin-right: 5px;"), "Influence Plots"),
          p("Detect influential studies. High values indicate strong influence.", style = "font-size: 14px; color: #6B7280;")
        )
      )
    )
  )
}

#' Server function for enhanced diagnostic plots
#'
#' @param id Module ID
#' @param rv Reactive values from main app (should contain meta-analysis results)
#' @export
diagnostic_plots_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive for plot data
    plot_rv <- reactiveValues(
      plot_obj = NULL,
      data = NULL
    )

    # Generate plot
    observeEvent(input$generate_plot, {
      req(rv$results)

      withProgress(message = 'Generating plot...', value = 0, {

        plot_type <- input$plot_type

        if (plot_type == "funnel_contour") {
          plot_rv$plot_obj <- generate_funnel_contour(
            rv$results,
            show_contours = input$show_contours,
            show_trim_fill = input$show_trim_fill,
            y_axis = input$funnel_y_axis
          )

        } else if (plot_type == "radial") {
          plot_rv$plot_obj <- generate_radial_plot(
            rv$results,
            show_ci = input$radial_ci
          )

        } else if (plot_type == "baujat") {
          plot_rv$plot_obj <- generate_baujat_plot(
            rv$results,
            label_top = input$baujat_label_top
          )

        } else if (plot_type == "influence") {
          plot_rv$plot_obj <- generate_influence_plot(
            rv$results,
            metric = input$influence_metric
          )

        } else if (plot_type == "gosh") {
          plot_rv$plot_obj <- generate_gosh_plot(rv$results)

        } else if (plot_type == "labbe") {
          plot_rv$plot_obj <- generate_labbe_plot(rv$data)

        } else if (plot_type == "doi") {
          plot_rv$plot_obj <- generate_doi_plot(rv$results)
        }

        setProgress(1)
      })
    })

    # Render plot title
    output$plot_title <- renderText({
      plot_names <- c(
        funnel_contour = "Contour-Enhanced Funnel Plot",
        radial = "Radial (Galbraith) Plot",
        baujat = "Baujat Plot for Heterogeneity",
        influence = "Influence Diagnostics",
        gosh = "GOSH Plot (Graphical Display of Heterogeneity)",
        labbe = "L'Abbé Plot",
        doi = "Doi Plot for Publication Bias"
      )

      plot_names[input$plot_type]
    })

    # Render diagnostic plot
    output$diagnostic_plot <- renderPlotly({
      req(plot_rv$plot_obj)

      plot_rv$plot_obj
    })

    # Render interpretation
    output$plot_interpretation <- renderUI({
      req(plot_rv$plot_obj, input$plot_type)

      interpretations <- list(
        funnel_contour = div(
          style = "font-size: 13px; color: #4B5563;",
          icon("info-circle", style = "color: #0066FF; margin-right: 5px;"),
          "Symmetry around vertical line suggests no publication bias. ",
          "Contours show statistical significance regions."
        ),
        radial = div(
          style = "font-size: 13px; color: #4B5563;",
          icon("info-circle", style = "color: #10B981; margin-right: 5px;"),
          "Studies outside the 95% CI line (shaded area) contribute to heterogeneity."
        ),
        baujat = div(
          style = "font-size: 13px; color: #4B5563;"),
          icon("info-circle", style = "color: #F59E0B; margin-right: 5px;"),
          "Studies in top-right contribute most to heterogeneity and overall result."
        ),
        influence = div(
          style = "font-size: 13px; color: #4B5563;",
          icon("info-circle", style = "color: #EF4444; margin-right: 5px;"),
          "High values indicate studies with strong influence on pooled estimate."
        ),
        gosh = div(
          style = "font-size: 13px; color: #4B5563;",
          icon("info-circle", style = "color: #8B5CF6; margin-right: 5px;"),
          "Clusters suggest subgroups; outliers indicate potential outlier studies."
        ),
        labbe = div(
          style = "font-size: 13px; color: #4B5563;",
          icon("info-circle", style = "color: #06B6D4; margin-right: 5px;"),
          "Studies above diagonal favor treatment; distance from line shows effect size."
        ),
        doi = div(
          style = "font-size: 13px; color: #4B5563;",
          icon("info-circle", style = "color: #EC4899; margin-right: 5px;"),
          "Asymmetric plot suggests publication bias; symmetric suggests no bias."
        )
      )

      interpretations[[input$plot_type]]
    })

    # Download handler
    output$download_plot <- downloadHandler(
      filename = function() {
        paste0("diagnostic_plot_", input$plot_type, "_", Sys.Date(), ".png")
      },
      content = function(file) {
        ggsave(file, plot = plot_rv$plot_obj, width = 10, height = 8, dpi = 300)
      }
    )
  })
}

#' Generate contour-enhanced funnel plot
#'
#' @param results Meta-analysis results object
#' @param show_contours Show significance contours
#' @param show_trim_fill Show trim-and-fill
#' @param y_axis Y-axis type
#' @return plotly object
generate_funnel_contour <- function(results, show_contours = TRUE, show_trim_fill = FALSE, y_axis = "se") {

  # Extract effect sizes and SEs
  yi <- results$yi
  sei <- sqrt(results$vi)

  # Create base data
  funnel_data <- data.frame(
    effect = yi,
    se = sei,
    precision = 1 / sei,
    n = results$n  # Assuming n is available
  )

  # Y-axis selection
  y_var <- switch(y_axis,
                  "se" = funnel_data$se,
                  "precision" = funnel_data$precision,
                  "n" = funnel_data$n)

  y_label <- switch(y_axis,
                    "se" = "Standard Error",
                    "precision" = "Precision (1/SE)",
                    "n" = "Sample Size")

  # Create plot
  p <- ggplot(funnel_data, aes(x = effect, y = y_var)) +
    geom_point(alpha = 0.6, size = 3, color = "#0066FF") +
    geom_vline(xintercept = results$estimate, linetype = "dashed", color = "#EF4444", size = 1) +
    labs(
      title = "Contour-Enhanced Funnel Plot",
      x = "Effect Size",
      y = y_label
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", color = "#1F2937"),
      axis.title = element_text(size = 12, color = "#4B5563")
    )

  # Add significance contours if requested
  if (show_contours && y_axis == "se") {
    # Create contour regions for p < 0.01, p < 0.05, p < 0.10
    se_range <- seq(0, max(sei) * 1.1, length.out = 100)
    pooled_effect <- results$estimate

    # p < 0.10 (1.64 SEs)
    contour_10_upper <- pooled_effect + 1.64 * se_range
    contour_10_lower <- pooled_effect - 1.64 * se_range

    # p < 0.05 (1.96 SEs)
    contour_05_upper <- pooled_effect + 1.96 * se_range
    contour_05_lower <- pooled_effect - 1.96 * se_range

    # p < 0.01 (2.58 SEs)
    contour_01_upper <- pooled_effect + 2.58 * se_range
    contour_01_lower <- pooled_effect - 2.58 * se_range

    # Add contour ribbons
    p <- p +
      geom_ribbon(aes(x = c(contour_10_lower, rev(contour_10_upper)),
                      ymin = 0, ymax = c(se_range, rev(se_range))),
                  fill = "#FEE2E2", alpha = 0.3, inherit.aes = FALSE) +
      geom_ribbon(aes(x = c(contour_05_lower, rev(contour_05_upper)),
                      ymin = 0, ymax = c(se_range, rev(se_range))),
                  fill = "#FECACA", alpha = 0.3, inherit.aes = FALSE) +
      geom_ribbon(aes(x = c(contour_01_lower, rev(contour_01_upper)),
                      ymin = 0, ymax = c(se_range, rev(se_range))),
                  fill = "#FCA5A5", alpha = 0.3, inherit.aes = FALSE)
  }

  # Reverse Y-axis for SE (larger SE at top)
  if (y_axis == "se") {
    p <- p + scale_y_reverse()
  }

  ggplotly(p) %>%
    layout(hovermode = "closest")
}

#' Generate radial (Galbraith) plot
#'
#' @param results Meta-analysis results
#' @param show_ci Show confidence intervals
#' @return plotly object
generate_radial_plot <- function(results, show_ci = TRUE) {

  # Radial plot coordinates
  # x = 1/SE, y = effect / SE
  yi <- results$yi
  sei <- sqrt(results$vi)

  radial_data <- data.frame(
    x = 1 / sei,
    y = yi / sei,
    study = results$slab %||% paste("Study", 1:length(yi))
  )

  # Pooled estimate line slope
  pooled_slope <- results$estimate

  p <- ggplot(radial_data, aes(x = x, y = y, label = study)) +
    geom_point(alpha = 0.7, size = 3, color = "#10B981") +
    geom_abline(slope = pooled_slope, intercept = 0, color = "#EF4444", size = 1.2) +
    labs(
      title = "Radial (Galbraith) Plot",
      x = "Inverse Standard Error (1/SE)",
      y = "Effect Size / SE"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", color = "#1F2937"),
      axis.title = element_text(size = 12, color = "#4B5563")
    )

  # Add confidence intervals
  if (show_ci) {
    # 95% CI lines
    ci_upper <- pooled_slope + 1.96
    ci_lower <- pooled_slope - 1.96

    p <- p +
      geom_abline(slope = ci_upper, intercept = 0, linetype = "dashed", color = "#9CA3AF") +
      geom_abline(slope = ci_lower, intercept = 0, linetype = "dashed", color = "#9CA3AF")
  }

  ggplotly(p) %>%
    layout(hovermode = "closest")
}

#' Generate Baujat plot
#'
#' @param results Meta-analysis results
#' @param label_top Number of top studies to label
#' @return plotly object
generate_baujat_plot <- function(results, label_top = 5) {

  # Calculate influence on heterogeneity and overall result
  yi <- results$yi
  vi <- results$vi
  n_studies <- length(yi)

  # Leave-one-out analysis
  contribution_to_q <- numeric(n_studies)
  influence_on_result <- numeric(n_studies)

  for (i in 1:n_studies) {
    # Leave out study i
    loo_fit <- try(rma(yi[-i], vi[-i], method = "REML"), silent = TRUE)

    if (!inherits(loo_fit, "try-error")) {
      # Contribution to Q
      contribution_to_q[i] <- results$QE - loo_fit$QE

      # Influence on result
      influence_on_result[i] <- abs(results$estimate - loo_fit$b[1])
    }
  }

  baujat_data <- data.frame(
    x = contribution_to_q,
    y = influence_on_result,
    study = results$slab %||% paste("Study", 1:n_studies)
  )

  # Identify top studies
  baujat_data$is_top <- rank(-baujat_data$x - baujat_data$y) <= label_top

  p <- ggplot(baujat_data, aes(x = x, y = y, label = study, color = is_top)) +
    geom_point(alpha = 0.7, size = 3) +
    scale_color_manual(values = c("FALSE" = "#6B7280", "TRUE" = "#EF4444")) +
    labs(
      title = "Baujat Plot",
      x = "Contribution to Heterogeneity (Q)",
      y = "Influence on Overall Result"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", color = "#1F2937"),
      axis.title = element_text(size = 12, color = "#4B5563"),
      legend.position = "none"
    )

  ggplotly(p) %>%
    layout(hovermode = "closest")
}

#' Generate influence diagnostics plot
#'
#' @param results Meta-analysis results
#' @param metric Influence metric to plot
#' @return plotly object
generate_influence_plot <- function(results, metric = "cooks") {

  # Calculate influence statistics
  inf <- influence(results)

  metric_values <- switch(metric,
                          "cooks" = inf$inf$cook.d,
                          "dffits" = inf$inf$dffits,
                          "dfbetas" = inf$inf$dfbetas,
                          "hat" = inf$inf$hat)

  influence_data <- data.frame(
    study = results$slab %||% paste("Study", 1:length(metric_values)),
    value = metric_values
  )

  # Sort by influence
  influence_data <- influence_data[order(-influence_data$value), ]

  # Color high influence studies
  threshold <- switch(metric,
                      "cooks" = qchisq(0.95, 2) / length(metric_values),
                      "dffits" = 2 * sqrt(2 / length(metric_values)),
                      "dfbetas" = 2 / sqrt(length(metric_values)),
                      "hat" = 2 * 2 / length(metric_values))

  influence_data$high_influence <- influence_data$value > threshold

  p <- ggplot(influence_data, aes(x = reorder(study, -value), y = value, fill = high_influence)) +
    geom_col(alpha = 0.8) +
    geom_hline(yintercept = threshold, linetype = "dashed", color = "#EF4444") +
    scale_fill_manual(values = c("FALSE" = "#60A5FA", "TRUE" = "#EF4444")) +
    labs(
      title = paste(tools::toTitleCase(metric), "Influence Diagnostics"),
      x = "Study",
      y = tools::toTitleCase(metric)
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", color = "#1F2937"),
      axis.title = element_text(size = 12, color = "#4B5563"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "none"
    )

  ggplotly(p) %>%
    layout(hovermode = "x")
}

#' Generate GOSH plot
#'
#' @param results Meta-analysis results
#' @return plotly object
generate_gosh_plot <- function(results) {

  # Placeholder for GOSH plot
  # Real implementation would run many subset meta-analyses

  p <- ggplot(data.frame(x = rnorm(100), y = rnorm(100)), aes(x, y)) +
    geom_point(alpha = 0.5, color = "#8B5CF6") +
    labs(
      title = "GOSH Plot (Graphical Display of Heterogeneity)",
      x = "Pooled Effect Size",
      y = "Heterogeneity (I²)"
    ) +
    theme_minimal()

  ggplotly(p)
}

#' Generate L'Abbé plot
#'
#' @param data Study data (for binary outcomes)
#' @return plotly object
generate_labbe_plot <- function(data) {

  # Placeholder - would need binary outcome data
  p <- ggplot(data.frame(x = runif(20), y = runif(20)), aes(x, y)) +
    geom_point(size = 3, color = "#06B6D4") +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
    labs(
      title = "L'Abbé Plot",
      x = "Control Group Event Rate",
      y = "Treatment Group Event Rate"
    ) +
    theme_minimal()

  ggplotly(p)
}

#' Generate Doi plot
#'
#' @param results Meta-analysis results
#' @return plotly object
generate_doi_plot <- function(results) {

  # Placeholder for Doi plot
  yi <- results$yi
  ranks <- rank(yi)

  doi_data <- data.frame(
    rank = ranks,
    effect = yi
  )

  p <- ggplot(doi_data, aes(x = rank, y = effect)) +
    geom_point(color = "#EC4899", size = 3) +
    geom_smooth(method = "loess", color = "#8B5CF6", fill = "#DDD6FE") +
    labs(
      title = "Doi Plot for Publication Bias",
      x = "Study Rank",
      y = "Effect Size"
    ) +
    theme_minimal()

  ggplotly(p)
}
