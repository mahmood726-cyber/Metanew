# Parametric Survival Analysis Module
# Fits parametric survival models using flexsurv package

library(shiny)
library(flexsurv)
library(survival)
library(ggplot2)

parametric_survival_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header("Parametric Survival Analysis"),
      layout_columns(
        col_widths = c(4, 8),

        # Settings panel
        card(
          h5("Model Selection"),
          checkboxGroupInput(ns("distributions"),
                           "Distributions to Fit:",
                           choices = c(
                             "Exponential" = "exp",
                             "Weibull" = "weibull",
                             "Log-normal" = "lognormal",
                             "Log-logistic" = "llogis",
                             "Gompertz" = "gompertz",
                             "Gamma" = "gamma",
                             "Generalized Gamma" = "gengamma"
                           ),
                           selected = c("exp", "weibull", "lognormal", "llogis")),
          hr(),

          h5("Data Configuration"),
          selectInput(ns("time_var"), "Time Variable:", choices = NULL),
          selectInput(ns("event_var"), "Event Variable:", choices = NULL),
          selectInput(ns("treatment_var"), "Treatment Variable:", choices = NULL),
          hr(),

          numericInput(ns("time_horizon"), "Time Horizon (years):",
                      value = 10, min = 1, max = 30),

          actionButton(ns("fit_models"), "Fit Models",
                      class = "btn-primary w-100 mt-3")
        ),

        # Results panel
        card(
          navset_card_tab(
            nav_panel("Model Comparison",
                     DTOutput(ns("model_comparison_table")),
                     plotOutput(ns("aic_plot"))),
            nav_panel("Best Fit",
                     verbatimTextOutput(ns("best_model_summary")),
                     plotOutput(ns("best_model_plot"))),
            nav_panel("All Models",
                     plotOutput(ns("all_models_plot"), height = "700px")),
            nav_panel("Extrapolation",
                     plotOutput(ns("extrapolation_plot")),
                     verbatimTextOutput(ns("extrapolation_summary"))),
            nav_panel("Restricted Mean",
                     plotOutput(ns("rmst_plot")),
                     verbatimTextOutput(ns("rmst_summary")))
          )
        )
      )
    )
  )
}

parametric_survival_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    fitted_models <- reactiveVal(NULL)

    # Update variable choices
    observe({
      req(rv$data)

      vars <- names(rv$data)
      updateSelectInput(session, "time_var", choices = vars)
      updateSelectInput(session, "event_var", choices = vars)
      updateSelectInput(session, "treatment_var", choices = vars)
    })

    observeEvent(input$fit_models, {
      req(rv$data, input$time_var, input$event_var, input$treatment_var)
      req(length(input$distributions) > 0)

      withProgress(message = "Fitting parametric models...", {
        tryCatch({

          data <- rv$data

          # Prepare survival object
          surv_obj <- Surv(time = data[[input$time_var]],
                          event = data[[input$event_var]])

          # Fit models for each distribution
          models <- list()
          model_fits <- list()

          distributions <- input$distributions

          for (i in seq_along(distributions)) {
            dist <- distributions[i]

            setProgress(i / length(distributions),
                       detail = paste("Fitting", dist, "model..."))

            fit <- tryCatch({
              if (dist == "exp") {
                flexsurvreg(surv_obj ~ data[[input$treatment_var]], dist = "exponential")
              } else if (dist == "weibull") {
                flexsurvreg(surv_obj ~ data[[input$treatment_var]], dist = "weibull")
              } else if (dist == "lognormal") {
                flexsurvreg(surv_obj ~ data[[input$treatment_var]], dist = "lognormal")
              } else if (dist == "llogis") {
                flexsurvreg(surv_obj ~ data[[input$treatment_var]], dist = "llogis")
              } else if (dist == "gompertz") {
                flexsurvreg(surv_obj ~ data[[input$treatment_var]], dist = "gompertz")
              } else if (dist == "gamma") {
                flexsurvreg(surv_obj ~ data[[input$treatment_var]], dist = "gamma")
              } else if (dist == "gengamma") {
                flexsurvreg(surv_obj ~ data[[input$treatment_var]], dist = "gengamma")
              }
            }, error = function(e) {
              message(paste("Failed to fit", dist, ":", e$message))
              NULL
            })

            if (!is.null(fit)) {
              models[[dist]] <- fit
              model_fits[[dist]] <- list(
                dist = dist,
                aic = AIC(fit),
                bic = BIC(fit),
                loglik = logLik(fit)[1],
                n_params = length(coef(fit))
              )
            }
          }

          # Rank by AIC
          aic_values <- sapply(model_fits, function(x) x$aic)
          best_model_name <- names(which.min(aic_values))

          results <- list(
            models = models,
            model_fits = do.call(rbind, lapply(model_fits, as.data.frame)),
            best_model = models[[best_model_name]],
            best_model_name = best_model_name,
            surv_obj = surv_obj,
            treatment_var = input$treatment_var,
            data = data
          )

          fitted_models(results)

          showNotification(
            paste("✓ Fitted", length(models), "models. Best:", best_model_name),
            type = "message"
          )

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    # Model comparison table
    output$model_comparison_table <- renderDT({
      req(fitted_models())

      df <- fitted_models()$model_fits
      df$delta_aic <- df$aic - min(df$aic)
      df <- df[order(df$aic), ]

      datatable(df,
               rownames = FALSE,
               options = list(pageLength = 10)) %>%
        formatRound(c("aic", "bic", "loglik", "delta_aic"), 2)
    })

    output$aic_plot <- renderPlot({
      req(fitted_models())

      df <- fitted_models()$model_fits
      df$dist <- factor(df$dist, levels = df$dist[order(df$aic)])

      ggplot(df, aes(x = dist, y = aic)) +
        geom_bar(stat = "identity", fill = "#0066CC") +
        geom_text(aes(label = round(aic, 1)), vjust = -0.5) +
        labs(title = "Model Comparison by AIC",
             subtitle = "Lower is better",
             x = "Distribution",
             y = "AIC") +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    })

    # Best model summary
    output$best_model_summary <- renderPrint({
      req(fitted_models())

      cat("BEST FITTING MODEL\n")
      cat("==================\n\n")

      cat(sprintf("Distribution: %s\n", fitted_models()$best_model_name))
      cat(sprintf("AIC: %.2f\n", AIC(fitted_models()$best_model)))
      cat(sprintf("BIC: %.2f\n\n", BIC(fitted_models()$best_model)))

      cat("Model Summary:\n")
      print(fitted_models()$best_model)
    })

    output$best_model_plot <- renderPlot({
      req(fitted_models())

      plot(fitted_models()$best_model,
           ci = TRUE,
           col = c("#0066CC", "#FF6B35"),
           lwd = 2,
           main = paste("Best Fit:", fitted_models()$best_model_name))
    })

    # All models plot
    output$all_models_plot <- renderPlot({
      req(fitted_models())

      models <- fitted_models()$models
      times <- seq(0, input$time_horizon, length.out = 200)

      # Get treatment levels
      treatments <- unique(fitted_models()$data[[fitted_models()$treatment_var]])

      par(mfrow = c(ceiling(length(models) / 2), 2))

      for (dist_name in names(models)) {
        model <- models[[dist_name]]

        # Plot for each treatment
        plot(model,
             t = times,
             ci = FALSE,
             col = rainbow(length(treatments)),
             lwd = 2,
             main = paste("Distribution:", dist_name),
             xlab = "Time (years)",
             ylab = "Survival Probability")

        legend("topright",
              legend = treatments,
              col = rainbow(length(treatments)),
              lwd = 2,
              cex = 0.8)
      }
    })

    # Extrapolation plot
    output$extrapolation_plot <- renderPlot({
      req(fitted_models())

      best_model <- fitted_models()$best_model
      times <- seq(0, input$time_horizon, length.out = 200)

      # Observed data
      km_fit <- survfit(fitted_models()$surv_obj ~ fitted_models()$data[[fitted_models()$treatment_var]])

      # Plot
      plot(km_fit,
           conf.int = FALSE,
           col = c("black", "gray"),
           lwd = 2,
           xlab = "Time (years)",
           ylab = "Survival Probability",
           main = "Extrapolation: KM vs Best Parametric Model")

      # Add parametric curves
      lines(best_model,
            t = times,
            ci = FALSE,
            col = c("#0066CC", "#FF6B35"),
            lwd = 2,
            lty = 2)

      legend("topright",
            legend = c("KM (Obs)", "Parametric (Extrap)"),
            lty = c(1, 2),
            lwd = 2,
            cex = 0.9)
    })

    output$extrapolation_summary <- renderPrint({
      req(fitted_models())

      cat("EXTRAPOLATION SUMMARY\n")
      cat("=====================\n\n")

      best_model <- fitted_models()$best_model
      max_obs_time <- max(fitted_models()$data[[input$time_var]])

      cat(sprintf("Maximum observed time: %.2f years\n", max_obs_time))
      cat(sprintf("Extrapolation to: %.2f years\n", input$time_horizon))
      cat(sprintf("Extrapolation period: %.2f years\n\n", input$time_horizon - max_obs_time))

      # Survival at time horizon
      surv_horizon <- summary(best_model,
                             t = input$time_horizon,
                             type = "survival")

      cat(sprintf("Predicted survival at %d years:\n", input$time_horizon))
      print(surv_horizon)
    })

    # Restricted mean survival time
    output$rmst_plot <- renderPlot({
      req(fitted_models())

      models <- fitted_models()$models

      # Calculate RMST for each model
      rmst_results <- list()

      for (dist_name in names(models)) {
        model <- models[[dist_name]]

        rmst <- summary(model,
                       t = input$time_horizon,
                       type = "rmst")

        rmst_results[[dist_name]] <- data.frame(
          distribution = dist_name,
          treatment = rownames(rmst[[1]]),
          rmst = rmst[[1]][, "est"],
          stringsAsFactors = FALSE
        )
      }

      rmst_df <- do.call(rbind, rmst_results)

      ggplot(rmst_df, aes(x = distribution, y = rmst, fill = treatment)) +
        geom_bar(stat = "identity", position = "dodge") +
        labs(title = "Restricted Mean Survival Time",
             subtitle = paste("Up to", input$time_horizon, "years"),
             x = "Distribution",
             y = "RMST (years)",
             fill = "Treatment") +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    })

    output$rmst_summary <- renderPrint({
      req(fitted_models())

      cat("RESTRICTED MEAN SURVIVAL TIME\n")
      cat("==============================\n\n")

      best_model <- fitted_models()$best_model

      rmst <- summary(best_model,
                     t = input$time_horizon,
                     type = "rmst")

      cat(sprintf("Time horizon: %d years\n", input$time_horizon))
      cat(sprintf("Distribution: %s\n\n", fitted_models()$best_model_name))

      print(rmst)
    })

    return(reactive(fitted_models()))
  })
}
