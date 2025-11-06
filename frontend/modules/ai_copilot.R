# AI Copilot Module - Natural Language Assistant for Meta-Analysis
# Dependencies: shiny, bslib, httr, jsonlite (loaded in app.R)

ai_copilot_ui <- function(id) {
  ns <- NS(id)

  card(
    full_screen = TRUE,
    card_header(
      class = "d-flex justify-content-between align-items-center",
      div(
        icon("robot", class = "me-2"),
        "AI Copilot"
      ),
      div(
        uiOutput(ns("llm_status_badge")),
        actionButton(ns("btn_clear_chat"), "Clear Chat",
                     class = "btn-sm btn-outline-secondary ms-2",
                     icon = icon("trash"))
      )
    ),

    layout_columns(
      col_widths = c(8, 4),

      # Chat interface
      card(
        card_header("Ask Me Anything About Your Analysis"),
        div(
          style = "height: 500px; overflow-y: auto; background-color: #f8f9fa; padding: 15px; border-radius: 5px;",
          id = ns("chat_container"),
          uiOutput(ns("chat_messages"))
        ),
        hr(),
        layout_columns(
          col_widths = c(10, 2),
          textInput(ns("user_query"), NULL,
                    placeholder = "e.g., 'Is there significant heterogeneity?' or 'Show me the forest plot'",
                    width = "100%"),
          actionButton(ns("btn_send"), "Send",
                       class = "btn-primary w-100",
                       icon = icon("paper-plane"))
        )
      ),

      # Quick actions & suggestions
      card(
        card_header("Quick Actions"),
        p(class = "text-muted small",
          "Click to auto-fill common queries:"),

        navset_card_pill(
          nav_panel(
            title = "Analysis",
            icon = icon("chart-line"),
            actionButton(ns("q_run_meta"), "Run meta-analysis",
                         class = "btn-sm btn-outline-primary w-100 mb-2"),
            actionButton(ns("q_forest"), "Show forest plot",
                         class = "btn-sm btn-outline-primary w-100 mb-2"),
            actionButton(ns("q_funnel"), "Show funnel plot",
                         class = "btn-sm btn-outline-primary w-100 mb-2"),
            actionButton(ns("q_heterogeneity"), "Interpret heterogeneity",
                         class = "btn-sm btn-outline-primary w-100 mb-2")
          ),
          nav_panel(
            title = "Economics",
            icon = icon("pound-sign"),
            actionButton(ns("q_icer"), "Calculate ICER",
                         class = "btn-sm btn-outline-success w-100 mb-2"),
            actionButton(ns("q_ceac"), "Show CEAC",
                         class = "btn-sm btn-outline-success w-100 mb-2"),
            actionButton(ns("q_cost_effective"), "Check cost-effectiveness at £30k",
                         class = "btn-sm btn-outline-success w-100 mb-2")
          ),
          nav_panel(
            title = "Scenarios",
            icon = icon("sliders"),
            actionButton(ns("q_compare"), "Compare scenarios",
                         class = "btn-sm btn-outline-info w-100 mb-2"),
            actionButton(ns("q_sensitivity"), "Suggest sensitivity analyses",
                         class = "btn-sm btn-outline-info w-100 mb-2")
          )
        ),

        hr(),

        card_header("Analysis Context"),
        p(class = "text-muted small",
          "Copilot can see your current analysis:"),
        tags$table(
          class = "table table-sm table-borderless",
          tags$tr(
            tags$td(strong("Studies:")),
            tags$td(textOutput(ns("ctx_n_studies"), inline = TRUE))
          ),
          tags$tr(
            tags$td(strong("Outcomes:")),
            tags$td(textOutput(ns("ctx_outcomes"), inline = TRUE))
          ),
          tags$tr(
            tags$td(strong("Last Action:")),
            tags$td(textOutput(ns("ctx_last_action"), inline = TRUE))
          )
        )
      )
    ),

    hr(),

    # API connection settings
    card(
      card_header("API Connection"),
      layout_columns(
        col_widths = c(6, 3, 3),
        textInput(ns("api_url"), "API Endpoint",
                  value = "http://localhost:8001",
                  placeholder = "http://localhost:8001"),
        actionButton(ns("btn_test_connection"), "Test Connection",
                     class = "btn-sm btn-outline-secondary w-100"),
        uiOutput(ns("connection_status"))
      )
    )
  )
}

ai_copilot_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    chat_history <- reactiveVal(list())
    llm_available <- reactiveVal(FALSE)
    last_action <- reactiveVal("None")
    last_send_time <- reactiveVal(Sys.time() - 10)  # Initialize to 10s ago

    # Check LLM availability on start
    observe({
      check_api_connection()
    })

    # LLM status badge
    output$llm_status_badge <- renderUI({
      if (llm_available()) {
        span(class = "badge bg-success", icon("check-circle"), " LLM Active")
      } else {
        span(class = "badge bg-warning", icon("exclamation-triangle"), " Rule-Based")
      }
    })

    # Context display
    output$ctx_n_studies <- renderText({
      if (!is.null(rv$data)) {
        length(unique(rv$data$study_id))
      } else {
        "0"
      }
    })

    output$ctx_outcomes <- renderText({
      if (!is.null(rv$pairwise_results) && length(rv$pairwise_results) > 0) {
        paste(names(rv$pairwise_results), collapse = ", ")
      } else {
        "None"
      }
    })

    output$ctx_last_action <- renderText({
      last_action()
    })

    # Check API connection
    check_api_connection <- function() {
      tryCatch({
        response <- GET(paste0(input$api_url, "/health"))

        if (status_code(response) == 200) {
          health <- content(response)
          llm_available(health$llm_available)
          return(TRUE)
        } else {
          llm_available(FALSE)
          return(FALSE)
        }
      }, error = function(e) {
        llm_available(FALSE)
        return(FALSE)
      })
    }

    # Test connection button
    observeEvent(input$btn_test_connection, {
      if (check_api_connection()) {
        showNotification("✓ API connection successful",
                         type = "message", duration = 3)
      } else {
        showNotification("✗ API connection failed. Make sure FastAPI is running on port 8001.",
                         type = "error", duration = 5)
      }
    })

    output$connection_status <- renderUI({
      if (llm_available()) {
        span(class = "badge bg-success", "Connected")
      } else {
        span(class = "badge bg-danger", "Disconnected")
      }
    })

    # Quick action buttons
    observeEvent(input$q_run_meta, {
      updateTextInput(session, "user_query", value = "Run meta-analysis")
    })

    observeEvent(input$q_forest, {
      updateTextInput(session, "user_query", value = "Show me the forest plot")
    })

    observeEvent(input$q_funnel, {
      updateTextInput(session, "user_query", value = "Generate funnel plot")
    })

    observeEvent(input$q_heterogeneity, {
      updateTextInput(session, "user_query", value = "Is there significant heterogeneity?")
    })

    observeEvent(input$q_icer, {
      updateTextInput(session, "user_query", value = "Calculate the ICER")
    })

    observeEvent(input$q_ceac, {
      updateTextInput(session, "user_query", value = "Show the cost-effectiveness acceptability curve")
    })

    observeEvent(input$q_cost_effective, {
      updateTextInput(session, "user_query", value = "Is it cost-effective at £30,000/QALY?")
    })

    observeEvent(input$q_compare, {
      updateTextInput(session, "user_query", value = "Compare my saved scenarios")
    })

    observeEvent(input$q_sensitivity, {
      updateTextInput(session, "user_query", value = "What sensitivity analyses should I run?")
    })

    # Send query
    observeEvent(input$btn_send, {
      query <- trimws(input$user_query)

      if (query == "") {
        showNotification("Please enter a query", type = "warning", duration = 2)
        return()
      }

      # BUG FIX #1: Add cooldown to prevent spam on API failure
      time_since_last <- as.numeric(difftime(Sys.time(), last_send_time(), units = "secs"))
      if (time_since_last < 3) {
        showNotification(
          sprintf("Please wait %.0f seconds before sending another query",
                  3 - time_since_last),
          type = "warning",
          duration = 2
        )
        return()
      }
      last_send_time(Sys.time())

      # Add user message to chat
      history <- chat_history()
      history[[length(history) + 1]] <- list(
        role = "user",
        content = query,
        timestamp = Sys.time()
      )
      chat_history(history)

      # Clear input
      updateTextInput(session, "user_query", value = "")

      # Send to API
      tryCatch({
        # Build context
        context <- build_analysis_context(rv)

        # Call NLQ endpoint
        response <- POST(
          paste0(input$api_url, "/nlq"),
          body = list(
            query = query,
            context = context,
            user_id = Sys.getenv("USER"),
            session_id = session$token
          ),
          encode = "json",
          timeout = 10
        )

        if (status_code(response) == 200) {
          nlq_response <- content(response)

          # Add assistant response to chat
          history <- chat_history()
          history[[length(history) + 1]] <- list(
            role = "assistant",
            content = nlq_response$explanation,
            action = nlq_response$action,
            parameters = nlq_response$parameters,
            confidence = nlq_response$confidence,
            code_snippet = nlq_response$code_snippet,
            timestamp = Sys.time()
          )
          chat_history(history)

          # Execute action if applicable
          execute_action(nlq_response$action, nlq_response$parameters)
          last_action(nlq_response$action)

        } else {
          # Error response
          history <- chat_history()
          history[[length(history) + 1]] <- list(
            role = "error",
            content = paste("API error:", status_code(response)),
            timestamp = Sys.time()
          )
          chat_history(history)
        }

      }, error = function(e) {
        history <- chat_history()
        history[[length(history) + 1]] <- list(
          role = "error",
          content = paste("Connection error:", e$message,
                          "\n\nMake sure the FastAPI server is running:\n",
                          "cd backend/api && python nlq.py"),
          timestamp = Sys.time()
        )
        chat_history(history)
      })
    })

    # Allow Enter key to send
    observeEvent(input$user_query, {
      # This would need JavaScript to detect Enter key
      # For now, user clicks Send button
    })

    # Clear chat
    observeEvent(input$btn_clear_chat, {
      chat_history(list())
      last_action("None")
    })

    # Render chat messages
    output$chat_messages <- renderUI({
      history <- chat_history()

      if (length(history) == 0) {
        return(div(
          class = "text-center text-muted p-4",
          icon("robot", style = "font-size: 48px; opacity: 0.3;"),
          h5("AI Copilot Ready", class = "mt-3"),
          p("Ask me anything about your meta-analysis or health economic model.",
            style = "font-size: 14px;"),
          hr(),
          p(strong("Example queries:"), style = "font-size: 13px;"),
          tags$ul(
            class = "text-start",
            style = "font-size: 12px;",
            tags$li("Is there significant heterogeneity in the mortality outcome?"),
            tags$li("Show me the forest plot"),
            tags$li("What's the ICER at £30,000/QALY?"),
            tags$li("Compare base case vs high ROB excluded"),
            tags$li("What sensitivity analyses should I run?")
          )
        ))
      }

      # Render messages
      messages_html <- lapply(history, function(msg) {
        if (msg$role == "user") {
          div(
            class = "mb-3 text-end",
            div(
              class = "d-inline-block bg-primary text-white rounded p-2",
              style = "max-width: 70%;",
              msg$content
            ),
            div(
              class = "small text-muted",
              format(msg$timestamp, "%H:%M:%S")
            )
          )
        } else if (msg$role == "assistant") {
          div(
            class = "mb-3",
            div(
              class = "d-inline-block bg-light rounded p-2",
              style = "max-width: 70%; border-left: 3px solid #0066CC;",
              div(
                icon("robot", class = "me-1"),
                strong("AI Copilot")
              ),
              p(msg$content, class = "mb-1"),
              if (!is.null(msg$code_snippet)) {
                div(
                  class = "mt-2 p-2 bg-dark text-white rounded",
                  style = "font-family: monospace; font-size: 12px;",
                  pre(msg$code_snippet, style = "margin: 0; color: #00ff00;")
                )
              },
              if (!is.null(msg$confidence) && msg$confidence < 0.7) {
                div(
                  class = "small text-warning mt-1",
                  icon("exclamation-triangle"),
                  sprintf(" Low confidence (%.0f%%)", msg$confidence * 100)
                )
              }
            ),
            div(
              class = "small text-muted",
              sprintf("Action: %s | %s",
                      msg$action,
                      format(msg$timestamp, "%H:%M:%S"))
            )
          )
        } else if (msg$role == "error") {
          div(
            class = "mb-3",
            div(
              class = "alert alert-danger",
              icon("exclamation-circle"),
              " ", msg$content
            )
          )
        }
      })

      do.call(tagList, messages_html)
    })

    # Build analysis context
    build_analysis_context <- function(rv) {
      context <- list()

      if (!is.null(rv$data)) {
        context$n_studies <- length(unique(rv$data$study_id))
        context$n_observations <- nrow(rv$data)
      }

      if (!is.null(rv$pairwise_results) && length(rv$pairwise_results) > 0) {
        context$outcomes <- names(rv$pairwise_results)
        context$current_outcome <- names(rv$pairwise_results)[1]

        # Add latest result stats
        latest <- rv$pairwise_results[[1]]
        if (!is.null(latest)) {
          context$i_squared <- latest$i_squared
          context$tau_squared <- latest$tau_squared
          context$pooled_effect <- latest$pooled_effect
          context$p_value <- latest$p_value
        }
      }

      if (!is.null(rv$he_results)) {
        context$icer <- rv$he_results$icer
        context$has_economic_model <- TRUE
      }

      return(context)
    }

    # Execute action based on NLQ response
    execute_action <- function(action, parameters) {
      message(sprintf("Executing action: %s with parameters: %s",
                      action, toJSON(parameters, auto_unbox = TRUE)))

      # These would trigger the appropriate module actions
      # For now, just log the action

      if (action == "interpret_heterogeneity" && !is.null(rv$pairwise_results)) {
        # Could trigger a modal with detailed heterogeneity interpretation
        result <- rv$pairwise_results[[1]]
        if (!is.null(result)) {
          showModal(modalDialog(
            title = "Heterogeneity Interpretation",
            h5("I² Statistic"),
            p(sprintf("I² = %.1f%%", result$i_squared)),
            if (result$i_squared < 25) {
              p(class = "text-success", "✓ Low heterogeneity - effects are consistent across studies")
            } else if (result$i_squared < 50) {
              p(class = "text-warning", "⚠ Moderate heterogeneity - some variation in effects")
            } else if (result$i_squared < 75) {
              p(class = "text-danger", "⚠ Substantial heterogeneity - consider subgroup analysis")
            } else {
              p(class = "text-danger", "⚠ Considerable heterogeneity - pooling may not be appropriate")
            },
            hr(),
            h5("Between-Study Variance"),
            p(sprintf("τ² = %.4f", result$tau_squared)),
            hr(),
            h5("Reference"),
            p(class = "small text-muted",
              "Higgins & Thompson (2002). Quantifying heterogeneity in a meta-analysis. Stat Med. ",
              "I² thresholds: <25% (low), 25-50% (moderate), 50-75% (substantial), >75% (considerable)"),
            footer = modalButton("Close")
          ))
        }
      }

      # Other actions would be handled similarly
    }

    return(reactive(list(
      chat_history = chat_history(),
      last_action = last_action(),
      llm_available = llm_available()
    )))
  })
}
