# Three-Level / Multilevel Meta-Analysis Module
# For handling dependent effect sizes (multiple outcomes per study, subgroups, etc.)
# Reference: Cheung (2014) Modeling dependent effect sizes with three-level meta-analyses
# Reference: Van den Noortgate et al. (2013) Three-level meta-analysis of dependent effect sizes

library(shiny)
library(metafor)
library(bslib)
library(plotly)

multilevel_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(3, 9),

      # Left panel: Settings
      card(
        card_header("Three-Level Meta-Analysis"),
        helpText(
          "Use three-level models when you have:",
          tags$ul(
            tags$li("Multiple effect sizes per study"),
            tags$li("Different outcomes from the same sample"),
            tags$li("Subgroups within studies"),
            tags$li("Longitudinal measurements")
          )
        ),

        selectInput(ns("outcome"), "Outcome Variable",
                    choices = NULL),

        selectInput(ns("method"), "Estimation Method",
                    choices = c("REML" = "REML",
                                "ML" = "ML"),
                    selected = "REML"),

        checkboxInput(ns("moderators"), "Include Moderators", FALSE),
        conditionalPanel(
          condition = "input.moderators == true",
          ns = ns,
          selectInput(ns("moderator_vars"), "Moderator Variables",
                      choices = NULL, multiple = TRUE)
        ),

        hr(),
        helpText(
          strong("Model Structure:"),
          br(),
          "Level 1: Sampling variance (within effect)",
          br(),
          "Level 2: Within-study variance (between effects within study)",
          br(),
          "Level 3: Between-study variance"
        ),

        hr(),
        actionButton(ns("btn_run"), "Run Three-Level MA",
                     class = "btn-primary w-100 mt-2", icon = icon("layer-group"))
      ),

      # Right panel: Results
      card(
        card_header("Three-Level MA Results"),
        navset_card_tab(
          nav_panel(
            "Summary",
            icon = icon("info-circle"),
            verbatimTextOutput(ns("summary"))
          ),
          nav_panel(
            "Variance Components",
            icon = icon("chart-pie"),
            plotOutput(ns("variance_plot"), height = "400px"),
            hr(),
            verbatimTextOutput(ns("variance_summary"))
          ),
          nav_panel(
            "Forest Plot",
            icon = icon("tree"),
            plotlyOutput(ns("forest_plot"), height = "600px")
          ),
          nav_panel(
            "Model Comparison",
            icon = icon("balance-scale"),
            verbatimTextOutput(ns("model_comparison")),
            hr(),
            helpText("Comparison of three-level model vs. standard two-level model")
          ),
          nav_panel(
            "Diagnostics",
            icon = icon("stethoscope"),
            plotOutput(ns("diagnostic_plot"), height = "500px")
          )
        )
      )
    )
  )
}

multilevel_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Results storage
    ml_result <- reactiveVal(NULL)

    # Update choices when data is loaded
    observe({
      req(rv$data)

      if ("outcome" %in% names(rv$data)) {
        outcomes <- unique(rv$data$outcome)
        updateSelectInput(session, "outcome", choices = outcomes)
      }

      # Potential moderators
      potential_moderators <- names(rv$data)[!names(rv$data) %in%
                                               c("yi", "sei", "vi", "study_id", "effect_id")]
      updateSelectInput(session, "moderator_vars", choices = potential_moderators)
    })

    # Run three-level meta-analysis
    observeEvent(input$btn_run, {
      req(rv$data)

      withProgress(message = "Running three-level meta-analysis...", {

        tryCatch({
          # Filter by outcome if specified
          data <- if (!is.null(input$outcome) && input$outcome != "" && "outcome" %in% names(rv$data)) {
            rv$data[rv$data$outcome == input$outcome, ]
          } else {
            rv$data
          }

          # Check required columns
          if (!all(c("yi", "sei", "study_id") %in% names(data))) {
            stop("Data must contain yi, sei, and study_id columns")
          }

          # Create effect_id if not present (unique ID for each effect size)
          if (!"effect_id" %in% names(data)) {
            data$effect_id <- 1:nrow(data)
          }

          # Calculate variance if not present
          if (!"vi" %in% names(data)) {
            data$vi <- data$sei^2
          }

          # Run three-level meta-analysis
          result <- run_threelevel_ma(
            data = data,
            method = input$method,
            moderators = if (input$moderators) input$moderator_vars else NULL
          )

          ml_result(result)
          rv$multilevel_results[[input$outcome]] <- result

          showNotification("✓ Three-level meta-analysis complete", type = "message")

        }, error = function(e) {
          showNotification(
            paste("Error:", e$message),
            type = "error",
            duration = 10
          )
        })
      })
    })

    # Summary output
    output$summary <- renderPrint({
      req(ml_result())
      result <- ml_result()

      cat("THREE-LEVEL META-ANALYSIS RESULTS\n")
      cat("==================================\n\n")

      cat("Model Structure:\n")
      cat("  Level 1: Sampling variance (known)\n")
      cat(sprintf("  Level 2: Within-study variance (σ²_within) = %.4f\n",
                  result$sigma2_level2))
      cat(sprintf("  Level 3: Between-study variance (σ²_between) = %.4f\n",
                  result$sigma2_level3))
      cat("\n")

      cat("Pooled Effect Estimate:\n")
      cat(sprintf("  Estimate: %.3f (95%% CI: %.3f to %.3f)\n",
                  result$pooled_effect, result$ci_lower, result$ci_upper))
      cat(sprintf("  SE: %.3f\n", result$se))
      cat(sprintf("  z = %.2f, p = %.4f\n", result$z_value, result$p_value))
      cat("\n")

      cat("Variance Decomposition:\n")
      cat(sprintf("  %% variance at Level 2 (within-study): %.1f%%\n",
                  result$pct_var_level2))
      cat(sprintf("  %% variance at Level 3 (between-study): %.1f%%\n",
                  result$pct_var_level3))
      cat("\n")

      cat("Model Fit:\n")
      cat(sprintf("  Log-likelihood: %.2f\n", result$loglik))
      cat(sprintf("  AIC: %.2f\n", result$aic))
      cat(sprintf("  BIC: %.2f\n", result$bic))

      # Display convergence status
      if (!is.null(result$converged)) {
        if (result$converged) {
          cat("  ✓ Model converged successfully\n")
        } else {
          cat("  ⚠ WARNING: Model did not converge\n")
        }
      }
      cat("\n")

      cat(sprintf("Number of studies: %d\n", result$n_studies))
      cat(sprintf("Number of effect sizes: %d\n", result$n_effects))
      cat(sprintf("Average effects per study: %.1f\n",
                  result$n_effects / result$n_studies))

      # Moderator results if applicable
      if (!is.null(result$moderator_results)) {
        cat("\n")
        cat("Moderator Analysis:\n")
        cat("===================\n")
        print(result$moderator_results)
      }

      cat("\n")
      cat("Reference: Cheung (2014) Modeling dependent effect sizes\n")
      cat("           Psychological Methods, 19(2), 211-229\n")
    })

    # Variance components plot
    output$variance_plot <- renderPlot({
      req(ml_result())
      result <- ml_result()

      # Create pie chart of variance components
      var_data <- data.frame(
        Component = c("Level 2\n(Within-Study)", "Level 3\n(Between-Study)"),
        Variance = c(result$sigma2_level2, result$sigma2_level3),
        Percentage = c(result$pct_var_level2, result$pct_var_level3)
      )

      ggplot(var_data, aes(x = "", y = Percentage, fill = Component)) +
        geom_bar(stat = "identity", width = 1) +
        coord_polar("y") +
        scale_fill_manual(values = c("#87CEEB", "#90EE90")) +
        labs(
          title = "Variance Decomposition",
          subtitle = "Three-level meta-analysis model"
        ) +
        theme_void() +
        theme(
          plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
          plot.subtitle = element_text(size = 10, hjust = 0.5),
          legend.position = "right"
        ) +
        geom_text(aes(label = sprintf("%.1f%%\n(σ² = %.3f)",
                                       Percentage, Variance)),
                  position = position_stack(vjust = 0.5),
                  size = 5)
    })

    # Variance summary
    output$variance_summary <- renderPrint({
      req(ml_result())
      result <- ml_result()

      cat("VARIANCE COMPONENTS INTERPRETATION\n")
      cat("===================================\n\n")

      cat("Level 2 (Within-Study) Variance:\n")
      cat(sprintf("  σ²_within = %.4f (%.1f%% of total variance)\n",
                  result$sigma2_level2, result$pct_var_level2))
      cat("  → Represents heterogeneity among effect sizes within the same study\n")
      cat("  → Could be due to: different outcomes, subgroups, time points\n\n")

      cat("Level 3 (Between-Study) Variance:\n")
      cat(sprintf("  σ²_between = %.4f (%.1f%% of total variance)\n",
                  result$sigma2_level3, result$pct_var_level3))
      cat("  → Represents heterogeneity among different studies\n")
      cat("  → Could be due to: population differences, interventions, settings\n\n")

      # Interpretation guidance
      if (result$pct_var_level2 > 70) {
        cat("⚠ Most variance is within-study. Consider:\n")
        cat("   - Are different outcomes measuring different constructs?\n")
        cat("   - Are there systematic differences between subgroups?\n\n")
      } else if (result$pct_var_level3 > 70) {
        cat("⚠ Most variance is between-study. Consider:\n")
        cat("   - Exploring study-level moderators\n")
        cat("   - Examining if studies are sufficiently similar\n\n")
      } else {
        cat("✓ Variance is distributed across both levels.\n")
        cat("  This is common and suggests both within- and between-study\n")
        cat("  heterogeneity contribute to overall variability.\n\n")
      }

      # Intraclass correlation coefficient (ICC)
      # ICC = σ²_between / (σ²_within + σ²_between)
      icc <- result$sigma2_level3 / (result$sigma2_level2 + result$sigma2_level3)
      cat(sprintf("Intraclass Correlation (ICC) = %.3f\n", icc))
      cat("  → Proportion of total variance between studies\n")
      cat(sprintf("  → Effect sizes from the same study are %.1f%% more similar\n",
                  icc * 100))
      cat("    than effect sizes from different studies\n")
    })

    # Forest plot
    output$forest_plot <- renderPlotly({
      req(ml_result())
      result <- ml_result()

      data <- result$data

      # Sort by study_id and effect_id for better visualization
      data <- data[order(data$study_id, data$effect_id), ]

      # Create forest plot with study grouping
      p <- plot_ly()

      # Add effect sizes colored by study
      studies <- unique(data$study_id)
      colors <- rainbow(length(studies), alpha = 0.7)
      names(colors) <- studies

      for (i in 1:nrow(data)) {
        study <- data$study_id[i]
        p <- p %>%
          add_trace(
            x = data$yi[i],
            y = i,
            error_x = list(
              type = "data",
              symmetric = FALSE,
              array = data$yi[i] + 1.96 * data$sei[i] - data$yi[i],
              arrayminus = data$yi[i] - (data$yi[i] - 1.96 * data$sei[i])
            ),
            type = "scatter",
            mode = "markers",
            marker = list(
              color = colors[study],
              size = 10,
              line = list(color = "white", width = 1)
            ),
            name = study,
            text = sprintf("<b>%s</b><br>Effect: %.3f (%.3f to %.3f)",
                           study, data$yi[i],
                           data$yi[i] - 1.96 * data$sei[i],
                           data$yi[i] + 1.96 * data$sei[i]),
            hovertemplate = '%{text}<extra></extra>',
            showlegend = (i == which(data$study_id == study)[1])  # Show legend only once per study
          )
      }

      # Add pooled estimate
      p <- p %>%
        add_segments(
          x = result$pooled_effect, xend = result$pooled_effect,
          y = 0, yend = nrow(data) + 1,
          line = list(color = "red", width = 3, dash = "solid"),
          name = "Pooled Effect (3-Level)",
          showlegend = TRUE
        ) %>%
        add_segments(
          x = 0, xend = 0,
          y = 0, yend = nrow(data) + 1,
          line = list(color = "black", width = 2, dash = "dash"),
          name = "Null Effect",
          showlegend = TRUE
        )

      p <- p %>%
        layout(
          title = list(text = "<b>Three-Level Meta-Analysis Forest Plot</b>",
                       font = list(size = 16)),
          xaxis = list(title = "Effect Size", zeroline = TRUE),
          yaxis = list(title = "", showticklabels = FALSE, showgrid = FALSE),
          hovermode = "closest"
        )

      p
    })

    # Model comparison
    output$model_comparison <- renderPrint({
      req(ml_result())
      result <- ml_result()

      cat("MODEL COMPARISON\n")
      cat("================\n\n")

      cat("Three-Level Model:\n")
      cat(sprintf("  Pooled effect: %.3f (%.3f to %.3f)\n",
                  result$pooled_effect, result$ci_lower, result$ci_upper))
      cat(sprintf("  Log-likelihood: %.2f\n", result$loglik))
      cat(sprintf("  AIC: %.2f\n", result$aic))
      cat(sprintf("  BIC: %.2f\n", result$bic))
      cat("\n")

      if (!is.null(result$two_level_comparison)) {
        two_level <- result$two_level_comparison
        cat("Standard Two-Level Model (for comparison):\n")
        cat(sprintf("  Pooled effect: %.3f (%.3f to %.3f)\n",
                    two_level$pooled_effect, two_level$ci_lower, two_level$ci_upper))
        cat(sprintf("  Log-likelihood: %.2f\n", two_level$loglik))
        cat(sprintf("  AIC: %.2f\n", two_level$aic))
        cat(sprintf("  BIC: %.2f\n", two_level$bic))
        cat("\n")

        # Likelihood ratio test
        lr_test <- result$lr_test
        cat("Likelihood Ratio Test:\n")
        cat(sprintf("  LR χ² = %.2f, df = %d, p = %.4f\n",
                    lr_test$statistic, lr_test$df, lr_test$p_value))

        if (lr_test$p_value < 0.05) {
          cat("\n✓ Three-level model significantly better (p < 0.05)\n")
          cat("  → Within-study dependence is present and should be accounted for\n")
        } else {
          cat("\n  Three-level model not significantly better (p ≥ 0.05)\n")
          cat("  → Standard two-level model may be sufficient\n")
        }
      }

      cat("\nInterpretation:\n")
      cat("  - Three-level models account for dependence among effect sizes\n")
      cat("    from the same study\n")
      cat("  - Ignoring dependence can lead to:\n")
      cat("    • Underestimated standard errors\n")
      cat("    • Overly narrow confidence intervals\n")
      cat("    • Inflated Type I error rates\n")
    })

    # Diagnostic plot
    output$diagnostic_plot <- renderPlot({
      req(ml_result())
      result <- ml_result()

      par(mfrow = c(2, 2))

      # 1. Residuals vs fitted
      plot(result$fitted, result$residuals,
           xlab = "Fitted Values", ylab = "Residuals",
           main = "Residuals vs Fitted",
           pch = 19, col = alpha("steelblue", 0.6))
      abline(h = 0, col = "red", lty = 2)

      # 2. Q-Q plot
      qqnorm(result$residuals, main = "Normal Q-Q Plot",
             pch = 19, col = alpha("steelblue", 0.6))
      qqline(result$residuals, col = "red", lty = 2)

      # 3. Scale-location plot
      plot(result$fitted, sqrt(abs(result$residuals)),
           xlab = "Fitted Values", ylab = "√|Residuals|",
           main = "Scale-Location Plot",
           pch = 19, col = alpha("steelblue", 0.6))
      abline(h = median(sqrt(abs(result$residuals))), col = "red", lty = 2)

      # 4. Histogram of residuals
      hist(result$residuals, breaks = 20,
           xlab = "Residuals", main = "Histogram of Residuals",
           col = "lightblue", border = "white")
      curve(dnorm(x, mean(result$residuals), sd(result$residuals)) *
              length(result$residuals) * diff(range(result$residuals)) / 20,
            add = TRUE, col = "red", lwd = 2)
    })

    return(reactive(ml_result()))
  })
}

# Helper function: Run three-level meta-analysis
# Reference: Cheung (2014) Modeling dependent effect sizes
run_threelevel_ma <- function(data, method = "REML", moderators = NULL) {

  # Ensure effect_id exists
  if (!"effect_id" %in% names(data)) {
    data$effect_id <- 1:nrow(data)
  }

  # Three-level model using rma.mv
  # Level 1: Sampling variance (vi) - known, fixed
  # Level 2: Within-study random effects (effect_id nested in study_id)
  # Level 3: Between-study random effects (study_id)

  if (!is.null(moderators) && length(moderators) > 0) {
    # With moderators
    formula_str <- paste("yi ~", paste(moderators, collapse = " + "))
    ml_model <- rma.mv(
      yi = yi,
      V = vi,
      mods = as.formula(formula_str),
      random = ~ 1 | study_id/effect_id,
      data = data,
      method = method
    )
  } else {
    # Without moderators
    ml_model <- rma.mv(
      yi = yi,
      V = vi,
      random = ~ 1 | study_id/effect_id,
      data = data,
      method = method
    )
  }

  # Convergence check for three-level model
  # Reference: Viechtbauer (2010) Journal of Statistical Software
  if (!ml_model$converged) {
    warning(paste("Three-level model did not converge after", ml_model$iter, "iterations.",
                  "Results may be unreliable. Consider using a different method or simplifying the model."))
  }

  # Extract variance components
  # ml_model$sigma2 gives variance at each level
  # Level 3 (study_id) is first, Level 2 (effect_id within study) is second
  sigma2_level3 <- ml_model$sigma2[1]  # Between-study variance
  sigma2_level2 <- ml_model$sigma2[2]  # Within-study variance

  total_var <- sigma2_level2 + sigma2_level3
  pct_var_level2 <- (sigma2_level2 / total_var) * 100
  pct_var_level3 <- (sigma2_level3 / total_var) * 100

  # Fitted values and residuals
  fitted_values <- fitted(ml_model)
  residuals <- residuals(ml_model)

  # For comparison, fit standard two-level model
  two_level_model <- tryCatch({
    rma(yi, vi, data = data, method = method)
  }, error = function(e) NULL)

  two_level_comparison <- if (!is.null(two_level_model)) {
    list(
      pooled_effect = as.numeric(two_level_model$beta),
      ci_lower = as.numeric(two_level_model$ci.lb),
      ci_upper = as.numeric(two_level_model$ci.ub),
      loglik = as.numeric(logLik(two_level_model)),
      aic = AIC(two_level_model),
      bic = BIC(two_level_model)
    )
  } else {
    NULL
  }

  # Likelihood ratio test comparing models
  lr_test <- if (!is.null(two_level_comparison)) {
    lr_stat <- 2 * (as.numeric(logLik(ml_model)) - two_level_comparison$loglik)
    df <- 1  # One additional variance component
    p_val <- pchisq(lr_stat, df, lower.tail = FALSE)
    list(statistic = lr_stat, df = df, p_value = p_val)
  } else {
    NULL
  }

  # Extract moderator results if applicable
  moderator_results <- if (!is.null(moderators) && length(moderators) > 0) {
    summary(ml_model)
  } else {
    NULL
  }

  list(
    pooled_effect = as.numeric(ml_model$beta[1]),
    ci_lower = as.numeric(ml_model$ci.lb[1]),
    ci_upper = as.numeric(ml_model$ci.ub[1]),
    se = as.numeric(ml_model$se),
    z_value = as.numeric(ml_model$zval[1]),
    p_value = as.numeric(ml_model$pval[1]),
    sigma2_level2 = sigma2_level2,
    sigma2_level3 = sigma2_level3,
    pct_var_level2 = pct_var_level2,
    pct_var_level3 = pct_var_level3,
    n_studies = length(unique(data$study_id)),
    n_effects = nrow(data),
    loglik = as.numeric(logLik(ml_model)),
    aic = AIC(ml_model),
    bic = BIC(ml_model),
    model_object = ml_model,
    data = data,
    fitted = fitted_values,
    residuals = residuals,
    two_level_comparison = two_level_comparison,
    lr_test = lr_test,
    moderator_results = moderator_results,
    converged = ml_model$converged
  )
}
