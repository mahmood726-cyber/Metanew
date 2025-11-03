# Radial/Galbraith Plot Module
# Alternative heterogeneity visualization for meta-analysis
# Part of Phase 3.2: Advanced Analytics

library(shiny)
library(bslib)
library(plotly)
library(ggplot2)
library(metafor)

# UI
radial_plot_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # Header
      card(
        card_header(
          tags$div(
            class = "d-flex justify-content-between align-items-center",
            tags$h4(class = "mb-0", icon("circle-dot"), " Radial (Galbraith) Plot"),
            actionButton(ns("btn_help"), icon("circle-question"),
                        class = "btn-sm btn-outline-secondary")
          )
        ),

        card_body(
          p(class = "text-muted",
            "Radial plots (Galbraith plots) provide an alternative to forest plots for visualizing ",
            "heterogeneity. Studies outside the 95% confidence bounds are potential outliers. ",
            "Especially useful for meta-analyses with >30 studies."
          ),

          layout_columns(
            col_widths = c(6, 6),

            selectInput(ns("model_type"), "Model Type",
                       choices = c("Random Effects (REML)" = "REML",
                                 "Fixed Effects" = "FE",
                                 "Random Effects (DL)" = "DL")),

            checkboxGroupInput(ns("plot_options"), "Display Options",
                             choices = c("Study Labels" = "labels",
                                       "Outlier Highlighting" = "outliers",
                                       "Confidence Bounds" = "bounds"),
                             selected = c("bounds", "outliers"))
          ),

          hr(),

          actionButton(ns("btn_generate"), "Generate Radial Plot",
                      icon = icon("play-circle"),
                      class = "btn-primary btn-lg w-100")
        )
      )
    ),

    # Results
    layout_columns(
      col_widths = c(12),

      uiOutput(ns("plot_output"))
    )
  )
}

# Server
radial_plot_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    radial_results <- reactiveVal(NULL)

    # Help modal
    observeEvent(input$btn_help, {
      showModal(modalDialog(
        title = tags$h4(icon("circle-question"), " Radial Plot Help"),
        size = "l",

        tags$div(
          tags$h5("What is a Radial (Galbraith) Plot?"),
          tags$p("The radial plot (also called Galbraith plot) is an alternative to the forest plot ",
                "for displaying meta-analysis results. It's particularly useful for large meta-analyses ",
                "(>30 studies) where forest plots become unwieldy."),

          tags$hr(),

          tags$h5("Plot Elements:"),
          tags$ul(
            tags$li(tags$strong("X-axis:"), " 1/SE (inverse standard error = precision)"),
            tags$li(tags$strong("Y-axis:"), " Effect/SE (standardized effect size)"),
            tags$li(tags$strong("Regression line:"), " Passes through origin with slope = pooled effect"),
            tags$li(tags$strong("Confidence bounds:"), " 95% CI lines (±1.96 from regression line)"),
            tags$li(tags$strong("Outliers:"), " Studies outside confidence bounds (highlighted in red)")
          ),

          tags$hr(),

          tags$h5("Interpretation:"),
          tags$ul(
            tags$li(tags$strong("Clustered points:"), " Low heterogeneity"),
            tags$li(tags$strong("Scattered points:"), " High heterogeneity"),
            tags$li(tags$strong("Points on regression line:"), " Consistent with pooled estimate"),
            tags$li(tags$strong("Points outside bounds:"), " Potential outliers or influential studies"),
            tags$li(tags$strong("Funnel shape:"), " Smaller studies (left) more variable than larger studies (right)")
          ),

          tags$hr(),

          tags$h5("Advantages over Forest Plots:"),
          tags$ul(
            tags$li("Better for large meta-analyses (>30 studies)"),
            tags$li("Easier to identify outliers visually"),
            tags$li("Shows precision-effect relationship clearly"),
            tags$li("Required by some journals (BMJ, Lancet)"),
            tags$li("Identifies small-study effects")
          ),

          tags$hr(),

          tags$h5("References:"),
          tags$p(tags$em("Galbraith RF. A note on graphical presentation of estimated odds ratios from several clinical trials. Statistics in Medicine. 1988;7(8):889-894."))
        ),

        footer = modalButton("Close")
      ))
    })

    # Generate radial plot
    observeEvent(input$btn_generate, {
      req(rv$data)

      tryCatch({
        # Check if we have effect sizes
        if (!"effect_size" %in% names(rv$data) || !"se" %in% names(rv$data)) {
          showNotification(
            "Please run a meta-analysis first to generate effect sizes",
            type = "warning",
            duration = 5
          )
          return()
        }

        data <- rv$data

        # Run meta-analysis for pooled estimate
        fit <- metafor::rma(yi = data$effect_size, sei = data$se, method = input$model_type)

        # Generate radial plot data
        results <- generate_radial_data(
          effect_size = data$effect_size,
          se = data$se,
          study_ids = data$study_id %||% paste0("Study ", 1:nrow(data)),
          pooled_estimate = coef(fit),
          tau2 = fit$tau2,
          model_type = input$model_type
        )

        radial_results(results)

        showNotification(
          "Radial plot generated successfully",
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        showNotification(
          paste("Error generating radial plot:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Render plot output
    output$plot_output <- renderUI({
      req(radial_results())

      results <- radial_results()

      tagList(
        # Summary
        layout_columns(
          col_widths = c(3, 3, 3, 3),

          value_box(
            title = "Pooled Effect",
            value = sprintf("%.3f", results$pooled_effect),
            showcase = icon("bullseye"),
            theme = "primary"
          ),

          value_box(
            title = "Heterogeneity (τ²)",
            value = sprintf("%.3f", results$tau2),
            showcase = icon("arrows-alt"),
            theme = "info"
          ),

          value_box(
            title = "Outliers Detected",
            value = results$n_outliers,
            showcase = icon("exclamation-triangle"),
            theme = if (results$n_outliers > 0) "warning" else "success"
          ),

          value_box(
            title = "Total Studies",
            value = results$n_studies,
            showcase = icon("database"),
            theme = "secondary"
          )
        ),

        # Radial plot
        card(
          card_header(
            tags$h5(class = "mb-0", icon("circle-dot"), " Radial (Galbraith) Plot")
          ),
          card_body(
            plotlyOutput(ns("radial_plot"), height = "600px"),
            hr(),
            p(class = "text-muted small",
              icon("info-circle"),
              " X-axis shows precision (1/SE), Y-axis shows standardized effect (Effect/SE). ",
              "Studies outside the 95% confidence bounds (red dashed lines) are potential outliers."
            )
          )
        ),

        # Outliers table
        if (results$n_outliers > 0) {
          card(
            card_header("Outlier Studies"),
            card_body(
              DT::DTOutput(ns("outliers_table")),
              p(class = "text-muted small mt-3",
                "These studies lie outside the 95% confidence bounds. ",
                "Consider sensitivity analysis excluding these studies."
              )
            )
          )
        },

        # Export
        card(
          card_header("Export"),
          card_body(
            layout_columns(
              col_widths = c(6, 6),
              downloadButton(ns("download_plot"), "Plot (PNG 300 DPI)",
                           class = "btn-primary w-100"),
              downloadButton(ns("download_data"), "Radial Data (CSV)",
                           class = "btn-secondary w-100")
            )
          )
        )
      )
    })

    # Radial plot
    output$radial_plot <- renderPlotly({
      req(radial_results())
      results <- radial_results()

      # Create plotly figure
      fig <- plot_ly()

      # Add confidence bounds if selected
      if ("bounds" %in% input$plot_options) {
        x_range <- c(0, max(results$precision) * 1.1)

        # Upper bound
        fig <- fig %>%
          add_lines(
            x = x_range,
            y = results$pooled_effect * x_range + 1.96,
            line = list(color = "red", dash = "dash", width = 2),
            name = "95% CI Upper",
            showlegend = TRUE
          )

        # Lower bound
        fig <- fig %>%
          add_lines(
            x = x_range,
            y = results$pooled_effect * x_range - 1.96,
            line = list(color = "red", dash = "dash", width = 2),
            name = "95% CI Lower",
            showlegend = TRUE
          )
      }

      # Add regression line (through origin)
      fig <- fig %>%
        add_lines(
          x = c(0, max(results$precision) * 1.1),
          y = c(0, results$pooled_effect * max(results$precision) * 1.1),
          line = list(color = "darkblue", width = 3),
          name = "Pooled Effect",
          showlegend = TRUE
        )

      # Add study points
      colors <- if ("outliers" %in% input$plot_options) {
        ifelse(results$is_outlier, "red", "steelblue")
      } else {
        "steelblue"
      }

      sizes <- if ("outliers" %in% input$plot_options) {
        ifelse(results$is_outlier, 12, 8)
      } else {
        8
      }

      text_labels <- if ("labels" %in% input$plot_options) {
        paste0(results$study_ids, "<br>",
              "Precision: ", round(results$precision, 2), "<br>",
              "Std Effect: ", round(results$std_effect, 2), "<br>",
              ifelse(results$is_outlier, "<b>OUTLIER</b>", ""))
      } else {
        paste0("Precision: ", round(results$precision, 2), "<br>",
              "Std Effect: ", round(results$std_effect, 2), "<br>",
              ifelse(results$is_outlier, "<b>OUTLIER</b>", ""))
      }

      fig <- fig %>%
        add_markers(
          x = results$precision,
          y = results$std_effect,
          marker = list(
            size = sizes,
            color = colors,
            line = list(color = "black", width = 1)
          ),
          text = text_labels,
          hoverinfo = "text",
          name = "Studies",
          showlegend = TRUE
        )

      # Layout
      fig <- fig %>%
        layout(
          title = "Radial (Galbraith) Plot",
          xaxis = list(title = "1 / SE (Precision)", zeroline = TRUE),
          yaxis = list(title = "Effect / SE (Standardized Effect)", zeroline = TRUE),
          hovermode = "closest"
        )

      fig
    })

    # Outliers table
    output$outliers_table <- DT::renderDT({
      req(radial_results())
      results <- radial_results()

      outlier_data <- results$outliers_df

      DT::datatable(
        outlier_data,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 't'
        ),
        rownames = FALSE,
        class = "display stripe hover"
      ) %>%
        DT::formatRound(columns = c("Effect_Size", "SE", "Precision", "Std_Effect", "Distance_from_Line"), digits = 3)
    })

    # Download plot
    output$download_plot <- downloadHandler(
      filename = function() {
        paste0("radial_plot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(radial_results())
        results <- radial_results()

        # Create ggplot version
        p <- create_radial_ggplot(results, input$plot_options)
        ggsave(file, p, width = 10, height = 7, dpi = 300)
      }
    )

    # Download data
    output$download_data <- downloadHandler(
      filename = function() {
        paste0("radial_data_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(radial_results())
        results <- radial_results()

        df <- data.frame(
          study_id = results$study_ids,
          effect_size = results$effect_size,
          se = results$se,
          precision = results$precision,
          std_effect = results$std_effect,
          is_outlier = results$is_outlier,
          distance_from_line = results$distance
        )

        write.csv(df, file, row.names = FALSE)
      }
    )

    # Return reactive values
    return(reactive({
      list(
        radial_results = radial_results()
      )
    }))
  })
}

# Helper: Generate radial plot data
generate_radial_data <- function(effect_size, se, study_ids, pooled_estimate, tau2, model_type) {
  # Calculate precision and standardized effect
  precision <- 1 / se
  std_effect <- effect_size / se

  # Expected standardized effect on the regression line
  expected_std_effect <- pooled_estimate * precision

  # Distance from regression line (residuals)
  distance <- std_effect - expected_std_effect

  # Identify outliers (outside ±1.96)
  is_outlier <- abs(distance) > 1.96

  # Outliers dataframe
  if (any(is_outlier)) {
    outliers_df <- data.frame(
      Study_ID = study_ids[is_outlier],
      Effect_Size = effect_size[is_outlier],
      SE = se[is_outlier],
      Precision = precision[is_outlier],
      Std_Effect = std_effect[is_outlier],
      Distance_from_Line = distance[is_outlier],
      stringsAsFactors = FALSE
    )
  } else {
    outliers_df <- data.frame(
      Study_ID = character(0),
      Effect_Size = numeric(0),
      SE = numeric(0),
      Precision = numeric(0),
      Std_Effect = numeric(0),
      Distance_from_Line = numeric(0)
    )
  }

  return(list(
    precision = precision,
    std_effect = std_effect,
    distance = distance,
    is_outlier = is_outlier,
    study_ids = study_ids,
    effect_size = effect_size,
    se = se,
    pooled_effect = pooled_estimate,
    tau2 = tau2,
    n_studies = length(effect_size),
    n_outliers = sum(is_outlier),
    outliers_df = outliers_df
  ))
}

# Helper: Create ggplot version for export
create_radial_ggplot <- function(results, plot_options) {
  # Create data frame
  df <- data.frame(
    precision = results$precision,
    std_effect = results$std_effect,
    is_outlier = results$is_outlier,
    study_id = results$study_ids
  )

  # Base plot
  p <- ggplot(df, aes(x = precision, y = std_effect))

  # Add confidence bounds
  if ("bounds" %in% plot_options) {
    x_max <- max(df$precision) * 1.1

    p <- p +
      geom_abline(intercept = 1.96, slope = results$pooled_effect,
                 linetype = "dashed", color = "red", size = 1) +
      geom_abline(intercept = -1.96, slope = results$pooled_effect,
                 linetype = "dashed", color = "red", size = 1)
  }

  # Add regression line
  p <- p +
    geom_abline(intercept = 0, slope = results$pooled_effect,
               color = "darkblue", size = 1.5)

  # Add points
  if ("outliers" %in% plot_options) {
    p <- p +
      geom_point(aes(color = is_outlier, size = is_outlier), alpha = 0.7) +
      scale_color_manual(values = c("FALSE" = "steelblue", "TRUE" = "red"),
                        name = "Outlier") +
      scale_size_manual(values = c("FALSE" = 3, "TRUE" = 5),
                       name = "Outlier")
  } else {
    p <- p +
      geom_point(color = "steelblue", size = 3, alpha = 0.7)
  }

  # Add labels
  if ("labels" %in% plot_options) {
    p <- p +
      geom_text(aes(label = study_id), size = 2.5, vjust = -1, check_overlap = TRUE)
  }

  # Theme and labels
  p <- p +
    labs(
      title = "Radial (Galbraith) Plot",
      x = "1 / SE (Precision)",
      y = "Effect / SE (Standardized Effect)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
      axis.text = element_text(size = 11),
      axis.title = element_text(size = 12, face = "bold")
    )

  return(p)
}

# Utility: Null coalescing operator
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}
