# Meta-Regression Bubble Plot Module
# Interactive visualization for meta-regression analysis
# Part of Phase 3: Advanced Analytics

library(shiny)
library(bslib)
library(plotly)
library(ggplot2)
library(metafor)

# UI
metareg_bubble_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # Header
      card(
        card_header(
          tags$div(
            class = "d-flex justify-content-between align-items-center",
            tags$h4(class = "mb-0", icon("chart-scatter"), " Meta-Regression Bubble Plot"),
            actionButton(ns("btn_help"), icon("circle-question"),
                        class = "btn-sm btn-outline-secondary")
          )
        ),

        card_body(
          p(class = "text-muted",
            "Visualize meta-regression results with interactive bubble plots. Bubble size ",
            "represents study weight, regression line shows the moderator effect, and ",
            "prediction bands indicate uncertainty."
          ),

          layout_columns(
            col_widths = c(4, 4, 4),

            selectInput(ns("moderator"), "Moderator Variable",
                       choices = NULL),

            selectInput(ns("model_type"), "Model Type",
                       choices = c("Mixed Effects (REML)" = "REML",
                                 "Fixed Effects" = "FE",
                                 "Random Effects (DL)" = "DL")),

            checkboxGroupInput(ns("plot_options"), "Display Options",
                             choices = c("Prediction Interval" = "pred_int",
                                       "Residuals" = "residuals",
                                       "Study Labels" = "labels"),
                             selected = c("pred_int", "labels"))
          ),

          hr(),

          actionButton(ns("btn_run"), "Generate Bubble Plot",
                      icon = icon("play-circle"),
                      class = "btn-primary btn-lg w-100")
        )
      )
    ),

    # Results
    layout_columns(
      col_widths = c(12),

      uiOutput(ns("results_output"))
    )
  )
}

# Server
metareg_bubble_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    metareg_results <- reactiveVal(NULL)

    # Update moderator choices when data changes
    observe({
      req(rv$data)

      # Get numeric and categorical columns (excluding standard meta-analysis cols)
      exclude_cols <- c("study_id", "events_exp", "n_exp", "events_ctrl", "n_ctrl",
                       "mean_exp", "sd_exp", "mean_ctrl", "sd_ctrl",
                       "effect_size", "se", "ci_lower", "ci_upper", "weight")

      available_cols <- setdiff(names(rv$data), exclude_cols)
      moderator_cols <- available_cols[sapply(rv$data[available_cols], function(x) {
        is.numeric(x) || is.factor(x) || length(unique(x)) < 20
      })]

      if (length(moderator_cols) > 0) {
        updateSelectInput(session, "moderator", choices = moderator_cols)
      }
    })

    # Help modal
    observeEvent(input$btn_help, {
      showModal(modalDialog(
        title = tags$h4(icon("circle-question"), " Meta-Regression Bubble Plot Help"),
        size = "l",

        tags$div(
          tags$h5("What is Meta-Regression?"),
          tags$p("Meta-regression explores whether study-level characteristics (moderators) ",
                "explain heterogeneity in effect sizes. For example: Does publication year ",
                "affect treatment efficacy? Do studies with larger sample sizes show different ",
                "effects?"),

          tags$hr(),

          tags$h5("Bubble Plot Elements:"),
          tags$ul(
            tags$li(tags$strong("X-axis:"), " Moderator variable (e.g., year, dose, baseline risk)"),
            tags$li(tags$strong("Y-axis:"), " Effect size from each study"),
            tags$li(tags$strong("Bubble size:"), " Study weight (larger = more precise)"),
            tags$li(tags$strong("Regression line:"), " Estimated moderator effect"),
            tags$li(tags$strong("Confidence band:"), " 95% CI for regression line"),
            tags$li(tags$strong("Prediction interval:"), " Expected range for new studies (if enabled)")
          ),

          tags$hr(),

          tags$h5("Interpretation:"),
          tags$ul(
            tags$li(tags$strong("Positive slope:"), " Effect increases with moderator"),
            tags$li(tags$strong("Negative slope:"), " Effect decreases with moderator"),
            tags$li(tags$strong("Flat line (p > 0.05):"), " No significant moderator effect"),
            tags$li(tags$strong("Wide band:"), " Uncertain moderator effect"),
            tags$li(tags$strong("Studies off line:"), " Unexplained heterogeneity remains")
          ),

          tags$hr(),

          tags$h5("Model Types:"),
          tags$ul(
            tags$li(tags$strong("Mixed Effects (REML):"), " Accounts for residual heterogeneity (recommended)"),
            tags$li(tags$strong("Fixed Effects:"), " Assumes moderator explains all heterogeneity"),
            tags$li(tags$strong("Random Effects (DL):"), " Alternative variance estimator")
          ),

          tags$hr(),

          tags$h5("Use Cases:"),
          tags$ul(
            tags$li("Explore sources of heterogeneity"),
            tags$li("Test hypotheses about effect modifiers"),
            tags$li("Identify dose-response relationships"),
            tags$li("Temporal trends (publication year)"),
            tags$li("Methodological moderators (RoB, blinding)")
          )
        ),

        footer = modalButton("Close")
      ))
    })

    # Run meta-regression
    observeEvent(input$btn_run, {
      req(rv$data, input$moderator)

      tryCatch({
        # Prepare data
        data <- rv$data
        moderator_var <- data[[input$moderator]]

        # Check if we have effect sizes
        if (!"effect_size" %in% names(data) || !"se" %in% names(data)) {
          showNotification(
            "Please run a meta-analysis first to generate effect sizes",
            type = "warning",
            duration = 5
          )
          return()
        }

        # Run meta-regression
        results <- run_metaregression(
          effect_size = data$effect_size,
          se = data$se,
          moderator = moderator_var,
          study_ids = data$study_id %||% paste0("Study", 1:nrow(data)),
          model_type = input$model_type
        )

        metareg_results(results)

        showNotification(
          "Meta-regression completed successfully",
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        showNotification(
          paste("Error running meta-regression:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Render results
    output$results_output <- renderUI({
      req(metareg_results())

      results <- metareg_results()

      tagList(
        # Summary cards
        layout_columns(
          col_widths = c(3, 3, 3, 3),

          value_box(
            title = "Moderator Coefficient",
            value = sprintf("%.3f", results$beta),
            showcase = icon("arrow-trend-up"),
            theme = if (results$pval < 0.05) "success" else "secondary"
          ),

          value_box(
            title = "P-value",
            value = format.pval(results$pval, digits = 4, eps = 0.001),
            showcase = icon("calculator"),
            theme = if (results$pval < 0.05) "success" else "warning"
          ),

          value_box(
            title = "R² (Explained)",
            value = sprintf("%.1f%%", results$R2),
            showcase = icon("chart-pie"),
            theme = "info"
          ),

          value_box(
            title = "Residual τ²",
            value = sprintf("%.3f", results$tau2),
            showcase = icon("gauge"),
            theme = "secondary"
          )
        ),

        # Interpretation
        card(
          card_header("Interpretation"),
          card_body(
            uiOutput(ns("interpretation_text"))
          )
        ),

        # Bubble plot
        card(
          card_header(
            tags$h5(class = "mb-0", icon("chart-scatter"), " Meta-Regression Bubble Plot")
          ),
          card_body(
            plotlyOutput(ns("bubble_plot"), height = "600px"),
            hr(),
            p(class = "text-muted small",
              icon("info-circle"),
              " Bubble size represents study weight (inverse variance). ",
              "Regression line shows the moderator effect with 95% confidence band."
            )
          )
        ),

        # Residual plot
        if ("residuals" %in% input$plot_options) {
          card(
            card_header("Residual Diagnostics"),
            card_body(
              layout_columns(
                col_widths = c(6, 6),
                plotlyOutput(ns("residual_plot"), height = "400px"),
                plotlyOutput(ns("qq_plot"), height = "400px")
              )
            )
          )
        },

        # Summary table
        card(
          card_header("Meta-Regression Summary"),
          card_body(
            verbatimTextOutput(ns("summary_table"))
          )
        ),

        # Export
        card(
          card_header("Export"),
          card_body(
            layout_columns(
              col_widths = c(4, 4, 4),
              downloadButton(ns("download_plot"), "Plot (PNG)",
                           class = "btn-primary w-100"),
              downloadButton(ns("download_results"), "Results (CSV)",
                           class = "btn-secondary w-100"),
              downloadButton(ns("download_report"), "Report (TXT)",
                           class = "btn-info w-100")
            )
          )
        )
      )
    })

    # Interpretation text
    output$interpretation_text <- renderUI({
      req(metareg_results())
      results <- metareg_results()

      if (results$pval < 0.001) {
        significance <- "very strong"
        icon_type <- "check-circle"
        alert_class <- "alert-success"
      } else if (results$pval < 0.01) {
        significance <- "strong"
        icon_type <- "check-circle"
        alert_class <- "alert-success"
      } else if (results$pval < 0.05) {
        significance <- "significant"
        icon_type <- "check"
        alert_class <- "alert-info"
      } else if (results$pval < 0.10) {
        significance <- "marginally significant"
        icon_type <- "exclamation-circle"
        alert_class <- "alert-warning"
      } else {
        significance <- "not significant"
        icon_type <- "times-circle"
        alert_class <- "alert-secondary"
      }

      direction <- if (results$beta > 0) "increases" else "decreases"

      r2_interpretation <- if (results$R2 > 75) {
        "The moderator explains most of the heterogeneity."
      } else if (results$R2 > 50) {
        "The moderator explains a substantial portion of the heterogeneity."
      } else if (results$R2 > 25) {
        "The moderator explains some of the heterogeneity."
      } else {
        "The moderator explains little of the heterogeneity; other factors may be important."
      }

      tags$div(
        class = alert_class,
        icon(icon_type), " ",
        tags$strong(paste("The moderator effect is", significance, "(p =", format.pval(results$pval, digits = 3), ").")),
        tags$br(),
        sprintf("For each unit increase in the moderator, the effect size %s by %.3f.", direction, abs(results$beta)),
        tags$br(),
        sprintf("R² = %.1f%%: %s", results$R2, r2_interpretation),
        if (results$tau2 > 0) {
          tags$span(
            tags$br(),
            sprintf("Residual τ² = %.3f: Some unexplained heterogeneity remains.", results$tau2)
          )
        }
      )
    })

    # Bubble plot
    output$bubble_plot <- renderPlotly({
      req(metareg_results())
      results <- metareg_results()

      # Create prediction data for regression line
      x_range <- seq(min(results$moderator), max(results$moderator), length.out = 100)
      pred_y <- results$intercept + results$beta * x_range

      # Calculate CI bounds (±1.96 SE)
      se_slope <- sqrt(results$vcov[2,2])
      se_intercept <- sqrt(results$vcov[1,1])
      se_pred <- sqrt(se_intercept^2 + (x_range * se_slope)^2)

      ci_lower <- pred_y - 1.96 * se_pred
      ci_upper <- pred_y + 1.96 * se_pred

      # Create plot
      fig <- plot_ly()

      # Add confidence band
      fig <- fig %>%
        add_ribbons(
          x = c(x_range, rev(x_range)),
          y = c(ci_lower, rev(ci_upper)),
          fillcolor = "rgba(0, 100, 200, 0.2)",
          line = list(color = "transparent"),
          showlegend = FALSE,
          hoverinfo = "none",
          name = "95% CI"
        )

      # Add prediction interval (if selected)
      if ("pred_int" %in% input$plot_options && results$tau2 > 0) {
        pred_lower <- pred_y - 1.96 * sqrt(se_pred^2 + results$tau2)
        pred_upper <- pred_y + 1.96 * sqrt(se_pred^2 + results$tau2)

        fig <- fig %>%
          add_ribbons(
            x = c(x_range, rev(x_range)),
            y = c(pred_lower, rev(pred_upper)),
            fillcolor = "rgba(100, 100, 100, 0.1)",
            line = list(color = "gray", dash = "dash"),
            showlegend = FALSE,
            hoverinfo = "none",
            name = "Prediction Interval"
          )
      }

      # Add regression line
      fig <- fig %>%
        add_lines(
          x = x_range,
          y = pred_y,
          line = list(color = "darkblue", width = 3),
          name = "Regression Line",
          showlegend = TRUE
        )

      # Add bubble points
      text_labels <- if ("labels" %in% input$plot_options) {
        paste0(results$study_ids, "<br>",
              "Moderator: ", round(results$moderator, 2), "<br>",
              "Effect: ", round(results$effect_size, 3), "<br>",
              "Weight: ", round(results$weights, 1), "%")
      } else {
        paste0("Moderator: ", round(results$moderator, 2), "<br>",
              "Effect: ", round(results$effect_size, 3), "<br>",
              "Weight: ", round(results$weights, 1), "%")
      }

      fig <- fig %>%
        add_markers(
          x = results$moderator,
          y = results$effect_size,
          marker = list(
            size = sqrt(results$weights) * 2,  # Scale for visibility
            color = results$effect_size,
            colorscale = "RdYlBu",
            reversescale = TRUE,
            showscale = TRUE,
            colorbar = list(title = "Effect Size"),
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
          title = paste("Meta-Regression:", input$moderator),
          xaxis = list(title = input$moderator),
          yaxis = list(title = "Effect Size"),
          hovermode = "closest"
        )

      fig
    })

    # Residual plot
    output$residual_plot <- renderPlotly({
      req(metareg_results())
      results <- metareg_results()

      fig <- plot_ly(
        x = results$fitted,
        y = results$residuals,
        type = "scatter",
        mode = "markers",
        marker = list(size = 8, color = "steelblue"),
        text = results$study_ids,
        hoverinfo = "text"
      ) %>%
        add_lines(
          x = range(results$fitted),
          y = c(0, 0),
          line = list(color = "red", dash = "dash"),
          showlegend = FALSE
        ) %>%
        layout(
          title = "Residual Plot",
          xaxis = list(title = "Fitted Values"),
          yaxis = list(title = "Residuals")
        )

      fig
    })

    # QQ plot
    output$qq_plot <- renderPlotly({
      req(metareg_results())
      results <- metareg_results()

      # Standardized residuals
      std_resid <- results$residuals / sqrt(results$tau2 + results$se^2)

      # Theoretical quantiles
      n <- length(std_resid)
      theoretical <- qnorm((1:n - 0.5) / n)
      observed <- sort(std_resid)

      fig <- plot_ly(
        x = theoretical,
        y = observed,
        type = "scatter",
        mode = "markers",
        marker = list(size = 8, color = "steelblue")
      ) %>%
        add_lines(
          x = range(theoretical),
          y = range(theoretical),
          line = list(color = "red", dash = "dash"),
          showlegend = FALSE
        ) %>%
        layout(
          title = "Q-Q Plot (Normality Check)",
          xaxis = list(title = "Theoretical Quantiles"),
          yaxis = list(title = "Observed Quantiles")
        )

      fig
    })

    # Summary table
    output$summary_table <- renderPrint({
      req(metareg_results())
      results <- metareg_results()

      cat("Meta-Regression Summary\n")
      cat("=======================\n\n")
      cat(sprintf("Model: %s\n", input$model_type))
      cat(sprintf("Moderator: %s\n", input$moderator))
      cat(sprintf("Number of studies: %d\n\n", length(results$effect_size)))

      cat("Coefficients:\n")
      cat(sprintf("  Intercept: %.4f (SE = %.4f, p = %.4f)\n",
                 results$intercept, sqrt(results$vcov[1,1]), results$pval_intercept))
      cat(sprintf("  %s: %.4f (SE = %.4f, p = %.4f)\n",
                 input$moderator, results$beta, sqrt(results$vcov[2,2]), results$pval))

      cat(sprintf("\nGoodness of fit:\n"))
      cat(sprintf("  R² (proportion explained): %.1f%%\n", results$R2))
      cat(sprintf("  Residual τ²: %.4f\n", results$tau2))
      cat(sprintf("  Residual I²: %.1f%%\n", results$I2_resid))
      cat(sprintf("  Test for residual heterogeneity: Q = %.2f (df = %d, p = %.4f)\n",
                 results$Q_resid, results$df_resid, results$pval_Q_resid))
    })

    # Download handlers
    output$download_plot <- downloadHandler(
      filename = function() {
        paste0("metareg_bubble_", input$moderator, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(metareg_results())
        results <- metareg_results()

        # Create ggplot version for export
        p <- create_bubble_ggplot(results, input$moderator, input$plot_options)
        ggsave(file, p, width = 10, height = 7, dpi = 300)
      }
    )

    output$download_results <- downloadHandler(
      filename = function() {
        paste0("metareg_results_", input$moderator, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(metareg_results())
        results <- metareg_results()

        df <- data.frame(
          study_id = results$study_ids,
          moderator = results$moderator,
          effect_size = results$effect_size,
          se = results$se,
          weight = results$weights,
          fitted = results$fitted,
          residual = results$residuals
        )

        write.csv(df, file, row.names = FALSE)
      }
    )

    output$download_report <- downloadHandler(
      filename = function() {
        paste0("metareg_report_", input$moderator, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
      },
      content = function(file) {
        req(metareg_results())
        results <- metareg_results()

        report <- capture.output({
          cat("Meta-Regression Report\n")
          cat(paste(rep("=", 60), collapse = ""), "\n\n")
          cat(sprintf("Generated: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

          cat("Model Specification:\n")
          cat(sprintf("  Moderator: %s\n", input$moderator))
          cat(sprintf("  Model type: %s\n", input$model_type))
          cat(sprintf("  Number of studies: %d\n\n", length(results$effect_size)))

          cat("Results:\n")
          cat(sprintf("  Coefficient: %.4f (95%% CI: [%.4f, %.4f])\n",
                     results$beta,
                     results$beta - 1.96*sqrt(results$vcov[2,2]),
                     results$beta + 1.96*sqrt(results$vcov[2,2])))
          cat(sprintf("  P-value: %.4f\n", results$pval))
          cat(sprintf("  R²: %.1f%%\n", results$R2))
          cat(sprintf("  Residual τ²: %.4f\n\n", results$tau2))

          cat("Interpretation:\n")
          if (results$pval < 0.05) {
            cat(sprintf("  The moderator has a significant effect (p = %.4f).\n", results$pval))
            direction <- if (results$beta > 0) "increases" else "decreases"
            cat(sprintf("  Effect size %s by %.4f per unit increase in %s.\n",
                       direction, abs(results$beta), input$moderator))
          } else {
            cat(sprintf("  The moderator effect is not significant (p = %.4f).\n", results$pval))
          }

          if (results$R2 > 50) {
            cat(sprintf("  The moderator explains %.1f%% of heterogeneity.\n", results$R2))
          } else {
            cat(sprintf("  The moderator explains only %.1f%% of heterogeneity.\n", results$R2))
            cat("  Other factors may be important.\n")
          }
        })

        writeLines(report, file)
      }
    )

    # Return reactive values
    return(reactive({
      list(
        metareg_results = metareg_results()
      )
    }))
  })
}

# Helper: Run meta-regression
run_metaregression <- function(effect_size, se, moderator, study_ids, model_type = "REML") {
  # Fit meta-regression model
  fit <- metafor::rma(yi = effect_size, sei = se, mods = ~ moderator, method = model_type)

  # Extract results
  beta <- coef(fit)[2]
  intercept <- coef(fit)[1]
  vcov_matrix <- vcov(fit)
  pval <- fit$pval[2]
  pval_intercept <- fit$pval[1]

  # Goodness of fit
  R2 <- max(0, 100 * (1 - fit$tau2 / fit$tau2.f))  # % heterogeneity explained
  tau2 <- fit$tau2
  I2_resid <- max(0, 100 * (fit$tau2 / (fit$tau2 + typical_vi)))

  typical_vi <- mean(se^2)

  # Residuals and fitted values
  fitted_values <- predict(fit)$pred
  residuals <- effect_size - fitted_values

  # Weights (in percentage)
  weights <- 100 * fit$wi / sum(fit$wi)

  # Residual heterogeneity test
  Q_resid <- fit$QE
  df_resid <- fit$QEdf
  pval_Q_resid <- fit$QEp

  return(list(
    beta = beta,
    intercept = intercept,
    vcov = vcov_matrix,
    pval = pval,
    pval_intercept = pval_intercept,
    R2 = R2,
    tau2 = tau2,
    I2_resid = I2_resid,
    Q_resid = Q_resid,
    df_resid = df_resid,
    pval_Q_resid = pval_Q_resid,
    moderator = moderator,
    effect_size = effect_size,
    se = se,
    weights = weights,
    fitted = fitted_values,
    residuals = residuals,
    study_ids = study_ids
  ))
}

# Helper: Create ggplot version for export
create_bubble_ggplot <- function(results, moderator_name, plot_options) {
  # Create data frame
  df <- data.frame(
    moderator = results$moderator,
    effect_size = results$effect_size,
    weight = results$weights,
    study_id = results$study_ids
  )

  # Regression line data
  x_range <- seq(min(results$moderator), max(results$moderator), length.out = 100)
  pred_y <- results$intercept + results$beta * x_range

  se_slope <- sqrt(results$vcov[2,2])
  se_intercept <- sqrt(results$vcov[1,1])
  se_pred <- sqrt(se_intercept^2 + (x_range * se_slope)^2)

  ci_lower <- pred_y - 1.96 * se_pred
  ci_upper <- pred_y + 1.96 * se_pred

  regression_df <- data.frame(
    x = x_range,
    y = pred_y,
    ci_lower = ci_lower,
    ci_upper = ci_upper
  )

  # Create plot
  p <- ggplot(df, aes(x = moderator, y = effect_size)) +
    geom_ribbon(data = regression_df, aes(x = x, ymin = ci_lower, ymax = ci_upper),
               fill = "lightblue", alpha = 0.3, inherit.aes = FALSE) +
    geom_line(data = regression_df, aes(x = x, y = y),
             color = "darkblue", size = 1.2, inherit.aes = FALSE) +
    geom_point(aes(size = weight, color = effect_size), alpha = 0.7) +
    scale_size_continuous(range = c(3, 15), name = "Weight (%)") +
    scale_color_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0,
                         name = "Effect Size") +
    labs(
      title = paste("Meta-Regression Bubble Plot:", moderator_name),
      x = moderator_name,
      y = "Effect Size"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
      axis.text = element_text(size = 11),
      axis.title = element_text(size = 12, face = "bold"),
      legend.position = "right"
    )

  if ("labels" %in% plot_options) {
    p <- p + geom_text(aes(label = study_id), size = 3, vjust = -1)
  }

  return(p)
}

# Utility: Null coalescing operator
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}
