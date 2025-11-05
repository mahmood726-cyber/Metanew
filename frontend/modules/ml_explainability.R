# ML Explainability Module - SHAP & LIME
# Provides interpretable explanations for ML predictions
library(shiny)
library(bslib)
library(DT)
library(plotly)
library(httr)
library(jsonlite)

ml_explainability_ui <- function(id) {
  ns <- NS(id)

  card(
    full_screen = TRUE,
    card_header(
      class = "d-flex justify-content-between align-items-center",
      div(
        icon("lightbulb", class = "me-2"),
        "Model Explainability (SHAP & LIME)"
      ),
      div(
        actionButton(ns("btn_refresh"), "Refresh", class = "btn-sm btn-outline-secondary",
                    icon = icon("refresh"))
      )
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Configuration
      card(
        card_header("Configuration"),

        selectInput(
          ns("model_select"),
          "Select Trained Model",
          choices = NULL  # Populated dynamically
        ),

        hr(),

        fileInput(
          ns("data_file"),
          "Upload Data to Explain",
          accept = c(".csv")
        ),

        sliderInput(
          ns("instance_idx"),
          "Select Instance to Explain",
          min = 1,
          max = 100,
          value = 1,
          step = 1
        ),

        hr(),

        h5("Explanation Methods"),

        checkboxInput(
          ns("use_shap"),
          "SHAP (SHapley Additive exPlanations)",
          value = TRUE
        ),

        p(class = "text-muted small ms-4",
          "✓ Theoretically grounded",
          br(),
          "✓ Global & local explanations",
          br(),
          "✓ Consistent feature attribution"),

        checkboxInput(
          ns("use_lime"),
          "LIME (Local Interpretable Model-agnostic)",
          value = TRUE
        ),

        p(class = "text-muted small ms-4",
          "✓ Model-agnostic",
          br(),
          "✓ Local fidelity",
          br(),
          "✓ Human-readable"),

        hr(),

        sliderInput(
          ns("top_features"),
          "Top Features to Show",
          min = 5,
          max = 20,
          value = 10,
          step = 1
        ),

        hr(),

        actionButton(
          ns("btn_explain"),
          "Generate Explanations",
          class = "btn-primary w-100",
          icon = icon("magic")
        )
      ),

      # Explanations
      card(
        card_header("Explanations"),

        navset_card_pill(
          # SHAP Tab
          nav_panel(
            title = "SHAP",
            icon = icon("chart-bar"),

            conditionalPanel(
              condition = "input.use_shap",
              ns = ns,

              layout_columns(
                col_widths = c(6, 6),

                value_box(
                  title = "Prediction",
                  value = textOutput(ns("shap_prediction")),
                  theme = "primary",
                  showcase = icon("bullseye")
                ),

                value_box(
                  title = "Confidence",
                  value = textOutput(ns("shap_confidence")),
                  theme = "success",
                  showcase = icon("percent")
                )
              ),

              hr(),

              h5("SHAP Waterfall Plot"),
              p(class = "text-muted small",
                "Shows how each feature pushes the prediction from base value:"),

              plotlyOutput(ns("shap_waterfall"), height = "400px"),

              hr(),

              h5("SHAP Force Plot"),
              p(class = "text-muted small",
                "Visualizes feature contributions to this specific prediction:"),

              plotlyOutput(ns("shap_force"), height = "250px"),

              hr(),

              h5("SHAP Summary"),
              verbatimTextOutput(ns("shap_summary"))
            )
          ),

          # LIME Tab
          nav_panel(
            title = "LIME",
            icon = icon("pie-chart"),

            conditionalPanel(
              condition = "input.use_lime",
              ns = ns,

              layout_columns(
                col_widths = c(6, 6),

                value_box(
                  title = "Model Score",
                  value = textOutput(ns("lime_score")),
                  theme = "info",
                  showcase = icon("star")
                ),

                value_box(
                  title = "Intercept",
                  value = textOutput(ns("lime_intercept")),
                  theme = "warning",
                  showcase = icon("anchor")
                )
              ),

              hr(),

              h5("LIME Feature Contributions"),
              p(class = "text-muted small",
                "Local linear approximation of model behavior:"),

              plotlyOutput(ns("lime_contributions"), height = "400px"),

              hr(),

              h5("LIME Explanation"),
              verbatimTextOutput(ns("lime_explanation"))
            )
          ),

          # Feature Importance Tab
          nav_panel(
            title = "Global Importance",
            icon = icon("globe"),

            h5("Global Feature Importance"),
            p(class = "text-muted",
              "Overall importance across all predictions:"),

            plotlyOutput(ns("global_importance"), height = "450px"),

            hr(),

            DTOutput(ns("importance_table"))
          ),

          # Clinical Narrative Tab
          nav_panel(
            title = "Clinical Narrative",
            icon = icon("file-medical"),

            h5("Patient/Study-Specific Explanation"),
            p(class = "text-muted",
              "Human-readable explanation for clinicians:"),

            card(
              class = "bg-light",
              card_body(
                verbatimTextOutput(ns("clinical_narrative"), placeholder = TRUE)
              )
            ),

            hr(),

            h5("Study Context"),
            DTOutput(ns("study_context")),

            hr(),

            h5("Risk Assessment"),
            verbatimTextOutput(ns("risk_assessment")),

            hr(),

            actionButton(
              ns("btn_export_narrative"),
              "Export to Report",
              class = "btn-success",
              icon = icon("file-export")
            )
          ),

          # Compare Methods Tab
          nav_panel(
            title = "Method Comparison",
            icon = icon("balance-scale"),

            h5("SHAP vs LIME Feature Ranking"),
            p(class = "text-muted",
              "How do different methods rank feature importance?"),

            plotlyOutput(ns("method_comparison"), height = "400px"),

            hr(),

            h5("Agreement Score"),
            value_box(
              title = "Methods Agreement",
              value = textOutput(ns("agreement_score")),
              theme = "success",
              showcase = icon("handshake")
            ),

            p(class = "text-muted small mt-3",
              "High agreement (>80%) indicates robust explanations. ",
              "Low agreement may indicate model instability.")
          )
        )
      )
    )
  )
}

ml_explainability_server <- function(id, api_url = "http://localhost:8000") {
  moduleServer(id, function(input, output, session) {

    rv <- reactiveValues(
      available_models = NULL,
      loaded_data = NULL,
      shap_results = NULL,
      lime_results = NULL,
      global_importance = NULL
    )

    # Load available models
    observe({
      tryCatch({
        response <- GET(paste0(api_url, "/ml/models/list"))
        rv$available_models <- content(response, "parsed")

        updateSelectInput(
          session,
          "model_select",
          choices = setNames(
            sapply(rv$available_models, function(m) m$id),
            sapply(rv$available_models, function(m) paste(m$name, "-", m$version))
          )
        )
      }, error = function(e) {
        showNotification("Error loading models", type = "error")
      })
    })

    # Load data
    observeEvent(input$data_file, {
      req(input$data_file)

      rv$loaded_data <- read.csv(input$data_file$datapath)

      updateSliderInput(
        session,
        "instance_idx",
        max = nrow(rv$loaded_data)
      )

      showNotification(
        paste("Loaded", nrow(rv$loaded_data), "instances"),
        type = "message"
      )
    })

    # Generate explanations
    observeEvent(input$btn_explain, {
      req(rv$loaded_data, input$model_select)

      showNotification("Generating explanations... This may take 10-30 seconds.",
                      type = "message", duration = 30)

      tryCatch({
        # Prepare request
        request_body <- list(
          model_id = input$model_select,
          data = rv$loaded_data,
          instance_idx = input$instance_idx - 1,  # 0-indexed
          use_shap = input$use_shap,
          use_lime = input$use_lime,
          top_features = input$top_features
        )

        # Call API
        response <- POST(
          paste0(api_url, "/ml/explain/comprehensive"),
          body = request_body,
          encode = "json",
          timeout(60)  # 1 minute
        )

        if (status_code(response) == 200) {
          results <- content(response, "parsed")

          if (input$use_shap && !is.null(results$shap)) {
            rv$shap_results <- results$shap
            update_shap_outputs()
          }

          if (input$use_lime && !is.null(results$lime)) {
            rv$lime_results <- results$lime
            update_lime_outputs()
          }

          if (!is.null(results$global)) {
            rv$global_importance <- results$global
            update_global_outputs()
          }

          update_comparison_outputs()
          update_narrative_outputs()

          showNotification("✓ Explanations generated successfully!", type = "message")

        } else {
          showNotification("Error generating explanations", type = "error")
        }

      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error")
      })
    })

    # Update SHAP outputs
    update_shap_outputs <- function() {
      req(rv$shap_results)

      output$shap_prediction <- renderText({
        rv$shap_results$prediction
      })

      output$shap_confidence <- renderText({
        paste0(round(rv$shap_results$confidence * 100, 1), "%")
      })

      # SHAP Waterfall
      output$shap_waterfall <- renderPlotly({
        importance <- rv$shap_results$feature_importance

        # Sort by absolute value
        importance_sorted <- importance[order(abs(importance$value), decreasing = TRUE), ]
        importance_sorted <- head(importance_sorted, input$top_features)

        plot_ly(
          y = reorder(importance_sorted$feature, abs(importance_sorted$value)),
          x = importance_sorted$value,
          type = "bar",
          orientation = "h",
          marker = list(
            color = ifelse(importance_sorted$value > 0, "#e74c3c", "#3498db")
          ),
          text = paste0(round(importance_sorted$value, 4)),
          textposition = "outside"
        ) %>%
          layout(
            title = "SHAP Values (Feature Contributions)",
            xaxis = list(title = "SHAP Value (impact on prediction)"),
            yaxis = list(title = ""),
            hovermode = "closest"
          )
      })

      # SHAP Force plot (cumulative)
      output$shap_force <- renderPlotly({
        importance <- rv$shap_results$feature_importance
        cumsum_values <- cumsum(importance$value[order(importance$value)])

        plot_ly(
          x = 1:length(cumsum_values),
          y = cumsum_values,
          type = "scatter",
          mode = "lines+markers",
          fill = "tonexty",
          fillcolor = "rgba(52, 152, 219, 0.3)",
          line = list(color = "#3498db", width = 3),
          marker = list(size = 8)
        ) %>%
          layout(
            title = "Cumulative SHAP Contribution",
            xaxis = list(title = "Feature Rank"),
            yaxis = list(title = "Cumulative SHAP Value"),
            hovermode = "closest"
          )
      })

      output$shap_summary <- renderText({
        rv$shap_results$explanation_text
      })
    }

    # Update LIME outputs
    update_lime_outputs <- function() {
      req(rv$lime_results)

      output$lime_score <- renderText({
        round(rv$lime_results$score, 4)
      })

      output$lime_intercept <- renderText({
        round(rv$lime_results$intercept, 4)
      })

      # LIME Contributions
      output$lime_contributions <- renderPlotly({
        contributions <- rv$lime_results$feature_importance

        plot_ly(
          y = reorder(contributions$feature, abs(contributions$value)),
          x = contributions$value,
          type = "bar",
          orientation = "h",
          marker = list(
            color = ifelse(contributions$value > 0, "#27ae60", "#e74c3c")
          ),
          text = paste0(round(contributions$value, 4)),
          textposition = "outside"
        ) %>%
          layout(
            title = "LIME Feature Weights",
            xaxis = list(title = "Weight (local linear approximation)"),
            yaxis = list(title = ""),
            hovermode = "closest"
          )
      })

      output$lime_explanation <- renderText({
        rv$lime_results$explanation_text
      })
    }

    # Update global outputs
    update_global_outputs <- function() {
      req(rv$global_importance)

      output$global_importance <- renderPlotly({
        importance <- rv$global_importance$feature_importance

        plot_ly(
          y = reorder(importance$feature, importance$value),
          x = importance$value,
          type = "bar",
          orientation = "h",
          marker = list(color = "#9b59b6")
        ) %>%
          layout(
            title = "Global Feature Importance",
            xaxis = list(title = "Importance"),
            yaxis = list(title = "")
          )
      })

      output$importance_table <- renderDT({
        datatable(
          rv$global_importance$feature_importance,
          options = list(pageLength = 20),
          rownames = FALSE
        )
      })
    }

    # Update comparison outputs
    update_comparison_outputs <- function() {
      if (!is.null(rv$shap_results) && !is.null(rv$lime_results)) {
        # Compare rankings
        shap_ranks <- rank(-abs(rv$shap_results$feature_importance$value))
        lime_ranks <- rank(-abs(rv$lime_results$feature_importance$value))

        # Calculate agreement (Spearman correlation)
        agreement <- cor(shap_ranks, lime_ranks, method = "spearman")

        output$agreement_score <- renderText({
          paste0(round(agreement * 100, 1), "%")
        })

        # Comparison plot
        output$method_comparison <- renderPlotly({
          features <- rv$shap_results$feature_importance$feature

          plot_ly() %>%
            add_trace(
              x = shap_ranks,
              y = features,
              type = "scatter",
              mode = "markers",
              name = "SHAP",
              marker = list(size = 10, color = "#3498db")
            ) %>%
            add_trace(
              x = lime_ranks,
              y = features,
              type = "scatter",
              mode = "markers",
              name = "LIME",
              marker = list(size = 10, color = "#e74c3c")
            ) %>%
            layout(
              title = "Feature Ranking Comparison",
              xaxis = list(title = "Rank (1 = most important)"),
              yaxis = list(title = ""),
              hovermode = "closest"
            )
        })
      }
    }

    # Update narrative outputs
    update_narrative_outputs <- function() {
      if (!is.null(rv$shap_results)) {
        # Generate clinical narrative
        output$clinical_narrative <- renderText({
          instance <- rv$loaded_data[input$instance_idx, ]
          shap <- rv$shap_results

          paste0(
            "=== PREDICTION FOR INSTANCE #", input$instance_idx, " ===\n\n",
            "Prediction: ", shap$prediction, "\n",
            "Confidence: ", round(shap$confidence * 100, 1), "%\n\n",
            "KEY CONTRIBUTING FACTORS:\n",
            shap$explanation_text, "\n\n",
            "CLINICAL INTERPRETATION:\n",
            generate_clinical_interpretation(shap, instance)
          )
        })

        # Study context
        output$study_context <- renderDT({
          instance_data <- rv$loaded_data[input$instance_idx, , drop = FALSE]

          datatable(
            data.frame(
              Variable = names(instance_data),
              Value = as.character(t(instance_data)[, 1])
            ),
            options = list(pageLength = 20, dom = 't'),
            rownames = FALSE
          )
        })

        # Risk assessment
        output$risk_assessment <- renderText({
          confidence <- rv$shap_results$confidence

          if (confidence > 0.8) {
            "✓ HIGH CONFIDENCE: This prediction is highly reliable."
          } else if (confidence > 0.6) {
            "⚠ MODERATE CONFIDENCE: Consider additional clinical factors."
          } else {
            "⚠ LOW CONFIDENCE: Use with caution. Prediction uncertain."
          }
        })
      }
    }

    # Helper: Generate clinical interpretation
    generate_clinical_interpretation <- function(shap, instance) {
      prediction <- shap$prediction
      top_features <- head(shap$feature_importance, 3)

      interpretation <- paste0(
        "The model predicts '", prediction, "' primarily based on:\n\n"
      )

      for (i in 1:nrow(top_features)) {
        feat <- top_features[i, ]
        direction <- if (feat$value > 0) "increases" else "decreases"
        interpretation <- paste0(
          interpretation,
          i, ". ", feat$feature, " ", direction, " the prediction\n",
          "   (contribution: ", round(feat$value, 4), ")\n\n"
        )
      }

      interpretation <- paste0(
        interpretation,
        "\nRECOMMENDATION: ",
        if (prediction == "high") {
          "Consider random-effects model and subgroup analyses."
        } else {
          "Fixed-effects model may be appropriate."
        }
      )

      interpretation
    }

  })
}
