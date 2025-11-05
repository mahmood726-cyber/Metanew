# AutoML Wizard Module
# Automated hyperparameter optimization with Optuna
library(shiny)
library(bslib)
library(DT)
library(plotly)
library(httr)
library(jsonlite)

ml_automl_ui <- function(id) {
  ns <- NS(id)

  card(
    full_screen = TRUE,
    card_header(
      class = "d-flex justify-content-between align-items-center",
      div(
        icon("magic", class = "me-2"),
        "AutoML: Automated Model Optimization"
      ),
      div(
        uiOutput(ns("automl_status"))
      )
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Configuration Wizard
      card(
        card_header("Step-by-Step Configuration"),

        navset_card_pill(
          id = ns("wizard_tabs"),

          # Step 1: Data
          nav_panel(
            title = "1. Data",
            icon = icon("database"),
            value = "step1",

            h5("Upload Training Data"),

            fileInput(
              ns("train_data"),
              "Training Dataset (CSV)",
              accept = c(".csv")
            ),

            p(class = "text-muted small",
              "Required columns: features + target variable"),

            hr(),

            conditionalPanel(
              condition = "output.data_loaded",
              ns = ns,

              value_box(
                title = "Samples",
                value = textOutput(ns("n_samples")),
                theme = "primary"
              ),

              value_box(
                title = "Features",
                value = textOutput(ns("n_features")),
                theme = "info"
              ),

              hr(),

              h5("Preview"),
              DTOutput(ns("data_preview"))
            ),

            hr(),

            actionButton(
              ns("btn_next_1"),
              "Next: Task & Metric →",
              class = "btn-primary w-100",
              icon = icon("arrow-right")
            )
          ),

          # Step 2: Task
          nav_panel(
            title = "2. Task",
            icon = icon("bullseye"),
            value = "step2",

            h5("ML Task Type"),

            radioButtons(
              ns("task_type"),
              NULL,
              choices = c(
                "Classification" = "classification",
                "Regression" = "regression"
              ),
              selected = "classification"
            ),

            hr(),

            h5("Target Variable"),

            selectInput(
              ns("target_column"),
              NULL,
              choices = NULL  # Populated from data
            ),

            hr(),

            h5("Optimization Metric"),

            conditionalPanel(
              condition = "input.task_type == 'classification'",
              ns = ns,

              selectInput(
                ns("metric_classification"),
                NULL,
                choices = c(
                  "AUC-ROC (recommended)" = "roc_auc",
                  "F1 Score" = "f1",
                  "Accuracy" = "accuracy",
                  "Precision" = "precision",
                  "Recall" = "recall"
                ),
                selected = "roc_auc"
              )
            ),

            conditionalPanel(
              condition = "input.task_type == 'regression'",
              ns = ns,

              selectInput(
                ns("metric_regression"),
                NULL,
                choices = c(
                  "RMSE (recommended)" = "rmse",
                  "MAE" = "mae",
                  "R²" = "r2"
                ),
                selected = "rmse"
              )
            ),

            hr(),

            layout_columns(
              col_widths = c(6, 6),

              actionButton(
                ns("btn_prev_2"),
                "← Previous",
                class = "btn-secondary w-100"
              ),

              actionButton(
                ns("btn_next_2"),
                "Next: Models →",
                class = "btn-primary w-100",
                icon = icon("arrow-right")
              )
            )
          ),

          # Step 3: Models
          nav_panel(
            title = "3. Models",
            icon = icon("cube"),
            value = "step3",

            h5("Select Models to Optimize"),

            checkboxGroupInput(
              ns("models"),
              NULL,
              choices = c(
                "XGBoost (best overall)" = "xgboost",
                "LightGBM (fastest)" = "lightgbm",
                "CatBoost (best for categorical)" = "catboost",
                "Random Forest" = "random_forest"
              ),
              selected = c("xgboost", "lightgbm", "catboost")
            ),

            p(class = "text-muted small",
              "💡 Tip: Select multiple models to compare. XGBoost is recommended for most tasks."),

            hr(),

            h5("Optimization Budget"),

            sliderInput(
              ns("n_trials"),
              "Number of Trials per Model",
              min = 10,
              max = 100,
              value = 50,
              step = 10
            ),

            p(class = "text-muted small",
              "More trials = better optimization but longer time. ",
              "50 trials ≈ 5-10 minutes."),

            hr(),

            h5("Hardware"),

            checkboxInput(
              ns("use_gpu"),
              "Use GPU if available",
              value = FALSE
            ),

            hr(),

            layout_columns(
              col_widths = c(6, 6),

              actionButton(
                ns("btn_prev_3"),
                "← Previous",
                class = "btn-secondary w-100"
              ),

              actionButton(
                ns("btn_next_3"),
                "Next: Validation →",
                class = "btn-primary w-100",
                icon = icon("arrow-right")
              )
            )
          ),

          # Step 4: Validation
          nav_panel(
            title = "4. Validation",
            icon = icon("check-double"),
            value = "step4",

            h5("Cross-Validation"),

            sliderInput(
              ns("cv_folds"),
              "Number of CV Folds",
              min = 3,
              max = 10,
              value = 5,
              step = 1
            ),

            p(class = "text-muted small",
              "5-fold CV is standard. Use 10-fold for small datasets (<200 samples)."),

            hr(),

            h5("Train/Test Split"),

            sliderInput(
              ns("test_size"),
              "Test Set Size (%)",
              min = 10,
              max = 40,
              value = 20,
              step = 5
            ),

            hr(),

            h5("Random Seed"),

            numericInput(
              ns("random_seed"),
              "Random Seed (for reproducibility)",
              value = 42,
              min = 1,
              max = 9999
            ),

            hr(),

            layout_columns(
              col_widths = c(6, 6),

              actionButton(
                ns("btn_prev_4"),
                "← Previous",
                class = "btn-secondary w-100"
              ),

              actionButton(
                ns("btn_start"),
                "🚀 Start Optimization",
                class = "btn-success w-100",
                icon = icon("play")
              )
            )
          )
        )
      ),

      # Results & Progress
      card(
        card_header("Optimization Results"),

        conditionalPanel(
          condition = "!output.optimization_running && !output.optimization_complete",
          ns = ns,

          div(
            class = "text-center",
            style = "padding-top: 150px;",
            icon("magic", style = "font-size: 64px; color: #ccc;"),
            h4(class = "text-muted mt-3", "Configure AutoML and Start Optimization"),
            p(class = "text-muted", "Follow the steps on the left to get started")
          )
        ),

        conditionalPanel(
          condition = "output.optimization_running",
          ns = ns,

          h5("Optimization in Progress..."),

          layout_columns(
            col_widths = c(6, 6),

            value_box(
              title = "Current Trial",
              value = textOutput(ns("current_trial")),
              theme = "primary",
              showcase = icon("flask")
            ),

            value_box(
              title = "Best Score",
              value = textOutput(ns("best_score_running")),
              theme = "success",
              showcase = icon("trophy")
            )
          ),

          hr(),

          h5("Progress"),
          uiOutput(ns("progress_bars")),

          hr(),

          h5("Live Optimization Plot"),
          plotlyOutput(ns("live_optimization"), height = "300px"),

          hr(),

          h5("Log"),
          verbatimTextOutput(ns("optimization_log"), placeholder = TRUE)
        ),

        conditionalPanel(
          condition = "output.optimization_complete",
          ns = ns,

          h5("✓ Optimization Complete!"),

          layout_columns(
            col_widths = c(4, 4, 4),

            value_box(
              title = "Best Model",
              value = textOutput(ns("best_model")),
              theme = "primary",
              showcase = icon("trophy")
            ),

            value_box(
              title = "Best Score",
              value = textOutput(ns("best_score")),
              theme = "success",
              showcase = icon("star")
            ),

            value_box(
              title = "Time",
              value = textOutput(ns("optimization_time")),
              theme = "info",
              showcase = icon("clock")
            )
          ),

          hr(),

          navset_card_tab(
            nav_panel(
              "Model Comparison",

              plotlyOutput(ns("model_comparison"), height = "350px"),

              hr(),

              DTOutput(ns("results_table"))
            ),

            nav_panel(
              "Optimization History",

              plotlyOutput(ns("optimization_history"), height = "350px"),

              hr(),

              h5("Best Hyperparameters"),
              verbatimTextOutput(ns("best_params"))
            ),

            nav_panel(
              "Model Evaluation",

              plotlyOutput(ns("confusion_matrix"), height = "350px"),

              hr(),

              h5("Metrics"),
              verbatimTextOutput(ns("detailed_metrics"))
            )
          ),

          hr(),

          layout_columns(
            col_widths = c(4, 4, 4),

            actionButton(
              ns("btn_deploy"),
              "Deploy Best Model",
              class = "btn-success w-100",
              icon = icon("rocket")
            ),

            actionButton(
              ns("btn_download"),
              "Download Model",
              class = "btn-primary w-100",
              icon = icon("download")
            ),

            actionButton(
              ns("btn_new"),
              "New Optimization",
              class = "btn-secondary w-100",
              icon = icon("refresh")
            )
          )
        )
      )
    )
  )
}

ml_automl_server <- function(id, api_url = "http://localhost:8000") {
  moduleServer(id, function(input, output, session) {

    rv <- reactiveValues(
      train_data = NULL,
      optimization_running = FALSE,
      optimization_complete = FALSE,
      optimization_results = NULL,
      current_trial = 0,
      best_score_current = 0,
      trial_history = list()
    )

    # Load data
    observeEvent(input$train_data, {
      req(input$train_data)

      rv$train_data <- read.csv(input$train_data$datapath)

      output$n_samples <- renderText({
        nrow(rv$train_data)
      })

      output$n_features <- renderText({
        ncol(rv$train_data) - 1  # Exclude target
      })

      output$data_preview <- renderDT({
        datatable(
          head(rv$train_data, 10),
          options = list(scrollX = TRUE, pageLength = 10),
          rownames = FALSE
        )
      })

      # Update target column choices
      updateSelectInput(
        session,
        "target_column",
        choices = names(rv$train_data)
      )

      output$data_loaded <- reactive({ TRUE })
      outputOptions(output, "data_loaded", suspendWhenHidden = FALSE)
    })

    # Wizard navigation
    observeEvent(input$btn_next_1, {
      updateNavs("wizard_tabs", selected = "step2")
    })

    observeEvent(input$btn_next_2, {
      updateNavs("wizard_tabs", selected = "step3")
    })

    observeEvent(input$btn_next_3, {
      updateNavs("wizard_tabs", selected = "step4")
    })

    observeEvent(input$btn_prev_2, {
      updateNavs("wizard_tabs", selected = "step1")
    })

    observeEvent(input$btn_prev_3, {
      updateNavs("wizard_tabs", selected = "step2")
    })

    observeEvent(input$btn_prev_4, {
      updateNavs("wizard_tabs", selected = "step3")
    })

    # Start optimization
    observeEvent(input$btn_start, {
      req(rv$train_data)

      rv$optimization_running <- TRUE
      rv$optimization_complete <- FALSE
      rv$trial_history <- list()

      output$optimization_log <- renderText("🚀 Starting AutoML optimization...")

      tryCatch({
        # Prepare request
        metric <- if (input$task_type == "classification") {
          input$metric_classification
        } else {
          input$metric_regression
        }

        request_body <- list(
          data = rv$train_data,
          target_column = input$target_column,
          task_type = input$task_type,
          metric = metric,
          models = input$models,
          n_trials = input$n_trials,
          cv_folds = input$cv_folds,
          test_size = input$test_size / 100,
          random_state = input$random_seed,
          use_gpu = input$use_gpu
        )

        # Call AutoML API
        response <- POST(
          paste0(api_url, "/ml/automl/optimize"),
          body = request_body,
          encode = "json",
          timeout(600)  # 10 minutes
        )

        if (status_code(response) == 200) {
          rv$optimization_results <- content(response, "parsed")
          rv$optimization_running <- FALSE
          rv$optimization_complete <- TRUE

          output$optimization_log <- renderText({
            paste0(
              "✓ Optimization complete!\n",
              "✓ Best model: ", rv$optimization_results$best_model_type, "\n",
              "✓ Best score: ", round(rv$optimization_results$best_score, 4)
            )
          })

          update_results_ui()

        } else {
          rv$optimization_running <- FALSE
          output$optimization_log <- renderText("❌ Optimization failed")
        }

      }, error = function(e) {
        rv$optimization_running <- FALSE
        output$optimization_log <- renderText(paste("❌ Error:", e$message))
      })
    })

    # Update results UI
    update_results_ui <- function() {
      req(rv$optimization_results)

      results <- rv$optimization_results

      # Best model info
      output$best_model <- renderText(results$best_model_type)
      output$best_score <- renderText(round(results$best_score, 4))
      output$optimization_time <- renderText(paste(round(results$total_time, 1), "sec"))

      # Model comparison plot
      output$model_comparison <- renderPlotly({
        models <- results$all_results

        plot_ly(
          x = names(models),
          y = sapply(models, function(m) m$score),
          type = "bar",
          marker = list(color = sapply(models, function(m) m$score),
                       colorscale = "Viridis")
        ) %>%
          layout(
            title = "Model Performance Comparison",
            xaxis = list(title = "Model"),
            yaxis = list(title = paste("Score (", results$metric, ")"))
          )
      })

      # Results table
      output$results_table <- renderDT({
        results_df <- data.frame(
          Model = names(models),
          Score = sapply(models, function(m) round(m$score, 4)),
          Time = sapply(models, function(m) round(m$optimization_time, 1)),
          Trials = sapply(models, function(m) m$n_trials)
        )

        datatable(results_df, options = list(pageLength = 10), rownames = FALSE)
      })

      # Best hyperparameters
      output$best_params <- renderText({
        params <- results$best_params
        paste0(
          "Model: ", results$best_model_type, "\n\n",
          "Hyperparameters:\n",
          paste(names(params), "=", params, collapse = "\n")
        )
      })
    }

    # Status outputs
    output$optimization_running <- reactive({ rv$optimization_running })
    output$optimization_complete <- reactive({ rv$optimization_complete })

    outputOptions(output, "optimization_running", suspendWhenHidden = FALSE)
    outputOptions(output, "optimization_complete", suspendWhenHidden = FALSE)

  })
}
