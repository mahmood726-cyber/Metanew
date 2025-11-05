# ML Ensemble Model Training Module
# Provides UI for training XGBoost, LightGBM, CatBoost ensemble models
library(shiny)
library(bslib)
library(DT)
library(plotly)
library(httr)
library(jsonlite)

source("utils/python_bridge.R")

ml_ensemble_ui <- function(id) {
  ns <- NS(id)

  card(
    full_screen = TRUE,
    card_header(
      class = "d-flex justify-content-between align-items-center",
      div(
        icon("brain", class = "me-2"),
        "Ensemble Model Training"
      ),
      div(
        uiOutput(ns("ml_status_badge"))
      )
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Training Configuration
      card(
        card_header("Configuration"),

        selectInput(
          ns("prediction_target"),
          "Prediction Target",
          choices = c(
            "Heterogeneity (I²)" = "heterogeneity",
            "Publication Bias" = "publication_bias",
            "Study Quality" = "study_quality",
            "Effect Direction" = "effect_direction"
          )
        ),

        hr(),

        h5("Select Models"),
        checkboxGroupInput(
          ns("models"),
          NULL,
          choices = c(
            "XGBoost (best regularization)" = "xgboost",
            "LightGBM (fastest)" = "lightgbm",
            "CatBoost (best for categorical)" = "catboost",
            "Random Forest (baseline)" = "random_forest"
          ),
          selected = c("xgboost", "lightgbm", "catboost")
        ),

        hr(),

        h5("Ensemble Method"),
        radioButtons(
          ns("ensemble_method"),
          NULL,
          choices = c(
            "Stacking (best accuracy)" = "stacking",
            "Voting (faster)" = "voting",
            "Best Single Model" = "single"
          ),
          selected = "stacking"
        ),

        hr(),

        h5("Training Data"),
        fileInput(
          ns("training_data"),
          "Upload Historical Data (CSV)",
          accept = c(".csv")
        ),

        p(class = "text-muted small",
          "CSV should contain: study_id, outcome_type, n, heterogeneity (0/1), etc."),

        hr(),

        sliderInput(
          ns("cv_folds"),
          "Cross-Validation Folds",
          min = 3,
          max = 10,
          value = 5,
          step = 1
        ),

        hr(),

        actionButton(
          ns("btn_train"),
          "Train Ensemble Model",
          class = "btn-primary w-100",
          icon = icon("play")
        ),

        hr(),

        verbatimTextOutput(ns("training_log"), placeholder = TRUE)
      ),

      # Results & Performance
      card(
        card_header("Results"),

        navset_card_pill(
          # Performance Tab
          nav_panel(
            title = "Performance",
            icon = icon("chart-line"),

            layout_columns(
              col_widths = c(6, 6),

              value_box(
                title = "Best Model",
                value = textOutput(ns("best_model_name")),
                theme = "primary",
                showcase = icon("trophy")
              ),

              value_box(
                title = "Best AUC",
                value = textOutput(ns("best_auc")),
                theme = "success",
                showcase = icon("star")
              )
            ),

            hr(),

            h5("Model Comparison"),
            plotlyOutput(ns("performance_plot"), height = "300px"),

            hr(),

            h5("Cross-Validation Scores"),
            DTOutput(ns("cv_table"))
          ),

          # Feature Importance Tab
          nav_panel(
            title = "Feature Importance",
            icon = icon("list-ol"),

            p(class = "text-muted",
              "Features most important for predictions:"),

            plotlyOutput(ns("importance_plot"), height = "400px"),

            hr(),

            DTOutput(ns("importance_table"))
          ),

          # Model Details Tab
          nav_panel(
            title = "Model Details",
            icon = icon("info-circle"),

            h5("Ensemble Configuration"),
            verbatimTextOutput(ns("model_config")),

            hr(),

            h5("Training Summary"),
            verbatimTextOutput(ns("training_summary")),

            hr(),

            h5("Model Files"),
            p(class = "text-muted",
              "Trained models are saved automatically for future use."),

            actionButton(
              ns("btn_save_model"),
              "Save Model to Registry",
              class = "btn-success",
              icon = icon("save")
            ),
            actionButton(
              ns("btn_load_model"),
              "Load Existing Model",
              class = "btn-secondary ms-2",
              icon = icon("folder-open")
            )
          ),

          # Prediction Tab
          nav_panel(
            title = "Test Predictions",
            icon = icon("magic"),

            p(class = "text-muted",
              "Test your trained model on new data:"),

            fileInput(
              ns("test_data"),
              "Upload Test Data (CSV)",
              accept = c(".csv")
            ),

            actionButton(
              ns("btn_predict"),
              "Generate Predictions",
              class = "btn-primary",
              icon = icon("wand-magic-sparkles")
            ),

            hr(),

            DTOutput(ns("predictions_table"))
          )
        )
      )
    )
  )
}

ml_ensemble_server <- function(id, api_url = "http://localhost:8000") {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    rv <- reactiveValues(
      ml_status = NULL,
      training_data = NULL,
      trained_model = NULL,
      performance_results = NULL,
      predictions = NULL
    )

    # Check ML system status
    observe({
      tryCatch({
        response <- GET(paste0(api_url, "/health/ml"))
        rv$ml_status <- content(response, "parsed")
      }, error = function(e) {
        rv$ml_status <- list(status = "error", error = as.character(e))
      })
    })

    # Status badge
    output$ml_status_badge <- renderUI({
      if (is.null(rv$ml_status)) {
        span(class = "badge bg-secondary", "Checking...")
      } else if (rv$ml_status$status == "healthy") {
        span(class = "badge bg-success",
             icon("check"), " ML Ready ",
             rv$ml_status$critical_components_available)
      } else if (rv$ml_status$status == "degraded") {
        span(class = "badge bg-warning",
             icon("exclamation-triangle"), " Degraded")
      } else {
        span(class = "badge bg-danger",
             icon("times"), " Unavailable")
      }
    })

    # Load training data
    observeEvent(input$training_data, {
      req(input$training_data)

      tryCatch({
        rv$training_data <- read.csv(input$training_data$datapath)

        output$training_log <- renderText({
          paste0(
            "✓ Loaded ", nrow(rv$training_data), " samples\n",
            "✓ Columns: ", paste(names(rv$training_data), collapse = ", ")
          )
        })
      }, error = function(e) {
        output$training_log <- renderText({
          paste("✗ Error loading data:", e$message)
        })
      })
    })

    # Train ensemble model
    observeEvent(input$btn_train, {
      req(rv$training_data)

      output$training_log <- renderText("⏳ Training ensemble model...")

      tryCatch({
        # Prepare request
        request_body <- list(
          data = rv$training_data,
          target = input$prediction_target,
          config = list(
            use_xgboost = "xgboost" %in% input$models,
            use_lightgbm = "lightgbm" %in% input$models,
            use_catboost = "catboost" %in% input$models,
            use_random_forest = "random_forest" %in% input$models,
            ensemble_method = input$ensemble_method,
            cv_folds = input$cv_folds
          )
        )

        # Call API
        response <- POST(
          paste0(api_url, "/ml/ensemble/train"),
          body = request_body,
          encode = "json",
          timeout(300)  # 5 minutes
        )

        if (status_code(response) == 200) {
          rv$performance_results <- content(response, "parsed")

          output$training_log <- renderText({
            paste0(
              "✓ Training complete!\n",
              "✓ Best model: ", rv$performance_results$best_model, "\n",
              "✓ AUC: ", round(rv$performance_results$best_auc, 4)
            )
          })

          # Update outputs
          update_performance_outputs()
        } else {
          error_msg <- content(response, "text")
          output$training_log <- renderText(paste("✗ Training failed:", error_msg))
        }

      }, error = function(e) {
        output$training_log <- renderText(paste("✗ Error:", e$message))
      })
    })

    # Update performance outputs
    update_performance_outputs <- function() {
      req(rv$performance_results)

      # Best model name
      output$best_model_name <- renderText({
        rv$performance_results$best_model
      })

      # Best AUC
      output$best_auc <- renderText({
        round(rv$performance_results$best_auc, 4)
      })

      # Performance plot
      output$performance_plot <- renderPlotly({
        models <- rv$performance_results$all_models

        plot_ly(
          x = names(models),
          y = sapply(models, function(m) m$auc),
          type = "bar",
          marker = list(
            color = sapply(models, function(m) m$auc),
            colorscale = "Blues",
            showscale = FALSE
          ),
          text = paste0("AUC: ", round(sapply(models, function(m) m$auc), 4)),
          textposition = "outside"
        ) %>%
          layout(
            title = "Model Performance Comparison",
            xaxis = list(title = "Model"),
            yaxis = list(title = "AUC-ROC", range = c(0, 1)),
            hovermode = "closest"
          )
      })

      # CV table
      output$cv_table <- renderDT({
        cv_data <- data.frame(
          Model = names(models),
          AUC = sapply(models, function(m) round(m$auc, 4)),
          F1 = sapply(models, function(m) round(m$f1, 4)),
          Accuracy = sapply(models, function(m) round(m$accuracy, 4)),
          CV_Mean = sapply(models, function(m) round(m$cv_mean, 4)),
          CV_Std = sapply(models, function(m) round(m$cv_std, 4))
        )

        datatable(
          cv_data,
          options = list(pageLength = 10, dom = 't'),
          rownames = FALSE
        )
      })

      # Feature importance
      if (!is.null(rv$performance_results$feature_importance)) {
        imp <- rv$performance_results$feature_importance

        output$importance_plot <- renderPlotly({
          plot_ly(
            x = imp$importance,
            y = reorder(imp$feature, imp$importance),
            type = "bar",
            orientation = "h",
            marker = list(color = "#3498db")
          ) %>%
            layout(
              title = "Feature Importance",
              xaxis = list(title = "Importance"),
              yaxis = list(title = "")
            )
        })

        output$importance_table <- renderDT({
          datatable(
            imp,
            options = list(pageLength = 20),
            rownames = FALSE
          )
        })
      }

      # Model config
      output$model_config <- renderText({
        config <- rv$performance_results$config
        paste0(
          "Ensemble Method: ", config$ensemble_method, "\n",
          "Base Models: ", paste(config$models, collapse = ", "), "\n",
          "CV Folds: ", config$cv_folds
        )
      })

      # Training summary
      output$training_summary <- renderText({
        paste0(
          "Training Samples: ", rv$performance_results$n_samples, "\n",
          "Features: ", rv$performance_results$n_features, "\n",
          "Training Time: ", round(rv$performance_results$training_time, 2), " seconds\n",
          "Timestamp: ", rv$performance_results$timestamp
        )
      })
    }

    # Test predictions
    observeEvent(input$btn_predict, {
      req(input$test_data, rv$trained_model)

      test_data <- read.csv(input$test_data$datapath)

      tryCatch({
        response <- POST(
          paste0(api_url, "/ml/ensemble/predict"),
          body = list(
            data = test_data,
            model_id = rv$trained_model$id
          ),
          encode = "json"
        )

        if (status_code(response) == 200) {
          predictions <- content(response, "parsed")

          output$predictions_table <- renderDT({
            pred_df <- data.frame(
              Study_ID = test_data$study_id,
              Prediction = predictions$predictions,
              Probability = round(predictions$probabilities, 4),
              Confidence = round(predictions$confidence, 4)
            )

            datatable(
              pred_df,
              options = list(pageLength = 20),
              rownames = FALSE
            ) %>%
              formatStyle(
                'Probability',
                background = styleColorBar(range(pred_df$Probability), '#3498db'),
                backgroundSize = '100% 90%',
                backgroundRepeat = 'no-repeat',
                backgroundPosition = 'center'
              )
          })
        }
      }, error = function(e) {
        showNotification(paste("Prediction error:", e$message), type = "error")
      })
    })

  })
}
