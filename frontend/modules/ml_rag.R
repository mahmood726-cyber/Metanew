# ML RAG (Retrieval-Augmented Generation) Module
# Query medical literature knowledge base with local Llama 3
library(shiny)
library(bslib)
library(DT)
library(httr)
library(jsonlite)

ml_rag_ui <- function(id) {
  ns <- NS(id)

  card(
    full_screen = TRUE,
    card_header(
      class = "d-flex justify-content-between align-items-center",
      div(
        icon("books", class = "me-2"),
        "RAG: Medical Literature Q&A"
      ),
      div(
        uiOutput(ns("rag_status_badge")),
        actionButton(ns("btn_manage_kb"), "Manage Knowledge Base",
                    class = "btn-sm btn-outline-secondary ms-2",
                    icon = icon("database"))
      )
    ),

    layout_columns(
      col_widths = c(8, 4),

      # Chat Interface
      card(
        card_header("Ask Questions About Medical Literature"),

        # Chat messages area
        div(
          id = ns("chat_area"),
          style = "height: 550px; overflow-y: auto; background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px;",
          uiOutput(ns("chat_messages"))
        ),

        # Query input
        layout_columns(
          col_widths = c(10, 2),

          textInput(
            ns("query"),
            NULL,
            placeholder = "e.g., 'What are risk factors for high heterogeneity in cardiovascular trials?'",
            width = "100%"
          ),

          actionButton(
            ns("btn_send"),
            "Send",
            class = "btn-primary w-100",
            icon = icon("paper-plane")
          )
        ),

        hr(),

        # Quick queries
        p(class = "text-muted small", "Quick queries:"),
        layout_column_wrap(
          width = "250px",
          actionButton(ns("q1"), "Heterogeneity factors", class = "btn-sm btn-outline-primary w-100"),
          actionButton(ns("q2"), "Publication bias detection", class = "btn-sm btn-outline-primary w-100"),
          actionButton(ns("q3"), "Network meta-analysis methods", class = "btn-sm btn-outline-primary w-100"),
          actionButton(ns("q4"), "GRADE guidelines", class = "btn-sm btn-outline-primary w-100")
        )
      ),

      # Knowledge Base & Settings
      card(
        card_header("Knowledge Base"),

        navset_card_pill(
          nav_panel(
            title = "Statistics",
            icon = icon("chart-pie"),

            value_box(
              title = "Documents",
              value = textOutput(ns("kb_n_documents")),
              theme = "primary",
              showcase = icon("file-alt")
            ),

            value_box(
              title = "Embeddings",
              value = textOutput(ns("kb_n_embeddings")),
              theme = "info",
              showcase = icon("vector-square")
            ),

            value_box(
              title = "Retrieval Method",
              value = textOutput(ns("kb_method")),
              theme = "success",
              showcase = icon("search")
            ),

            hr(),

            h5("Recent Sources"),
            DTOutput(ns("recent_sources"))
          ),

          nav_panel(
            title = "Add Documents",
            icon = icon("plus"),

            h5("Upload Literature"),

            fileInput(
              ns("upload_docs"),
              "Upload CSV with abstracts",
              accept = c(".csv"),
              multiple = FALSE
            ),

            p(class = "text-muted small",
              "CSV should contain columns: id, title, abstract, authors, year, doi"),

            hr(),

            h5("Or Load from Studies"),
            p(class = "text-muted small",
              "Add current analysis studies to knowledge base:"),

            actionButton(
              ns("btn_add_studies"),
              "Add Current Studies",
              class = "btn-success w-100",
              icon = icon("file-import")
            ),

            hr(),

            h5("Add Individual Document"),

            textInput(ns("doc_id"), "Document ID"),
            textAreaInput(ns("doc_text"), "Text", rows = 5),

            actionButton(
              ns("btn_add_doc"),
              "Add Document",
              class = "btn-primary w-100",
              icon = icon("plus")
            )
          ),

          nav_panel(
            title = "Settings",
            icon = icon("cog"),

            sliderInput(
              ns("top_k"),
              "Documents to Retrieve (k)",
              min = 1,
              max = 10,
              value = 5,
              step = 1
            ),

            selectInput(
              ns("retrieval_method"),
              "Retrieval Method",
              choices = c(
                "Auto (best available)" = "auto",
                "Semantic (neural embeddings)" = "semantic",
                "TF-IDF (keyword matching)" = "tfidf"
              ),
              selected = "auto"
            ),

            hr(),

            h5("LLM Settings"),

            checkboxInput(
              ns("use_llm"),
              "Use Local Llama 3 LLM",
              value = TRUE
            ),

            conditionalPanel(
              condition = "input.use_llm",
              ns = ns,

              sliderInput(
                ns("max_tokens"),
                "Max Response Tokens",
                min = 128,
                max = 1024,
                value = 512,
                step = 64
              ),

              sliderInput(
                ns("temperature"),
                "Temperature (creativity)",
                min = 0,
                max = 1,
                value = 0.7,
                step = 0.1
              )
            ),

            hr(),

            checkboxInput(
              ns("show_sources"),
              "Show Source Citations",
              value = TRUE
            ),

            checkboxInput(
              ns("show_relevance"),
              "Show Relevance Scores",
              value = TRUE
            )
          )
        )
      )
    )
  )
}

ml_rag_server <- function(id, api_url = "http://localhost:8000", shared_data = NULL) {
  moduleServer(id, function(input, output, session) {

    rv <- reactiveValues(
      chat_history = list(),
      kb_stats = NULL,
      recent_queries = list()
    )

    # Check RAG status
    observe({
      tryCatch({
        response <- GET(paste0(api_url, "/ml/rag/status"))
        status <- content(response, "parsed")

        output$rag_status_badge <- renderUI({
          if (status$available) {
            span(class = "badge bg-success",
                icon("check"), " RAG Ready")
          } else {
            span(class = "badge bg-warning",
                icon("exclamation-triangle"), " Limited Mode")
          }
        })

        rv$kb_stats <- status$knowledge_base

      }, error = function(e) {
        output$rag_status_badge <- renderUI({
          span(class = "badge bg-danger",
              icon("times"), " Offline")
        })
      })
    })

    # Update KB stats
    observe({
      if (!is.null(rv$kb_stats)) {
        output$kb_n_documents <- renderText({
          rv$kb_stats$n_documents
        })

        output$kb_n_embeddings <- renderText({
          rv$kb_stats$n_embeddings
        })

        output$kb_method <- renderText({
          rv$kb_stats$method
        })

        if (!is.null(rv$kb_stats$recent_docs)) {
          output$recent_sources <- renderDT({
            datatable(
              rv$kb_stats$recent_docs,
              options = list(pageLength = 5, dom = 't'),
              rownames = FALSE
            )
          })
        }
      }
    })

    # Send query
    send_query <- function(query_text) {
      req(query_text != "")

      # Add user message to chat
      rv$chat_history <- c(rv$chat_history, list(list(
        role = "user",
        message = query_text,
        timestamp = Sys.time()
      )))

      update_chat_ui()

      # Show loading
      rv$chat_history <- c(rv$chat_history, list(list(
        role = "assistant",
        message = "⏳ Searching knowledge base and generating response...",
        timestamp = Sys.time(),
        loading = TRUE
      )))

      update_chat_ui()

      # Call RAG API
      tryCatch({
        request_body <- list(
          query = query_text,
          top_k = input$top_k,
          method = input$retrieval_method,
          use_llm = input$use_llm,
          max_tokens = if (input$use_llm) input$max_tokens else 0,
          temperature = if (input$use_llm) input$temperature else 0.7
        )

        response <- POST(
          paste0(api_url, "/ml/rag/query"),
          body = request_body,
          encode = "json",
          timeout(60)
        )

        if (status_code(response) == 200) {
          result <- content(response, "parsed")

          # Remove loading message
          rv$chat_history <- rv$chat_history[-length(rv$chat_history)]

          # Add assistant response
          response_text <- result$response

          if (input$show_sources && length(result$sources) > 0) {
            response_text <- paste0(
              response_text,
              "\n\n📚 **Sources:**\n",
              paste(sapply(1:min(3, length(result$sources)), function(i) {
                src <- result$sources[[i]]
                relevance_text <- if (input$show_relevance) {
                  paste0(" (relevance: ", round(src$relevance_score, 2), ")")
                } else ""
                paste0(i, ". ", src$id, relevance_text)
              }), collapse = "\n")
            )
          }

          rv$chat_history <- c(rv$chat_history, list(list(
            role = "assistant",
            message = response_text,
            timestamp = Sys.time(),
            sources = result$sources,
            method = result$retrieval_method
          )))

          update_chat_ui()

        } else {
          # Error response
          rv$chat_history <- rv$chat_history[-length(rv$chat_history)]
          rv$chat_history <- c(rv$chat_history, list(list(
            role = "error",
            message = "❌ Error generating response. Please try again.",
            timestamp = Sys.time()
          )))
          update_chat_ui()
        }

      }, error = function(e) {
        rv$chat_history <- rv$chat_history[-length(rv$chat_history)]
        rv$chat_history <- c(rv$chat_history, list(list(
          role = "error",
          message = paste("❌ Error:", e$message),
          timestamp = Sys.time()
        )))
        update_chat_ui()
      })

      # Clear input
      updateTextInput(session, "query", value = "")
    }

    # Update chat UI
    update_chat_ui <- function() {
      output$chat_messages <- renderUI({
        if (length(rv$chat_history) == 0) {
          return(div(
            class = "text-center text-muted",
            style = "padding-top: 200px;",
            icon("comments", style = "font-size: 48px;"),
            h4("Ask me anything about medical literature"),
            p("I have access to your studies and can search medical knowledge.")
          ))
        }

        messages <- lapply(rv$chat_history, function(msg) {
          if (msg$role == "user") {
            div(
              class = "mb-3",
              div(
                class = "d-flex justify-content-end",
                div(
                  class = "bg-primary text-white p-3 rounded-3",
                  style = "max-width: 80%;",
                  msg$message
                )
              ),
              div(
                class = "text-end text-muted small mt-1",
                format(msg$timestamp, "%H:%M")
              )
            )
          } else if (msg$role == "assistant") {
            div(
              class = "mb-3",
              div(
                class = "d-flex justify-content-start",
                div(
                  class = "bg-light p-3 rounded-3 border",
                  style = "max-width: 80%;",
                  if (!is.null(msg$loading) && msg$loading) {
                    div(
                      span(class = "spinner-border spinner-border-sm me-2"),
                      msg$message
                    )
                  } else {
                    HTML(markdown::renderMarkdown(text = msg$message))
                  }
                )
              ),
              div(
                class = "text-start text-muted small mt-1",
                icon("robot", class = "me-1"),
                format(msg$timestamp, "%H:%M"),
                if (!is.null(msg$method)) {
                  span(class = "ms-2", paste("•", msg$method))
                }
              )
            )
          } else {  # error
            div(
              class = "mb-3",
              div(
                class = "alert alert-danger",
                msg$message
              )
            )
          }
        })

        do.call(tagList, messages)
      })

      # Auto-scroll to bottom
      session$sendCustomMessage("scrollToBottom", list(id = "chat_area"))
    }

    # Event handlers
    observeEvent(input$btn_send, {
      send_query(input$query)
    })

    observeEvent(input$query, {
      if (grepl("\\n$", input$query)) {  # Enter key
        send_query(trimws(input$query))
      }
    })

    # Quick queries
    observeEvent(input$q1, {
      send_query("What are the main factors that contribute to high heterogeneity in meta-analyses?")
    })

    observeEvent(input$q2, {
      send_query("What are the best methods for detecting publication bias in systematic reviews?")
    })

    observeEvent(input$q3, {
      send_query("Explain the differences between frequentist and Bayesian network meta-analysis.")
    })

    observeEvent(input$q4, {
      send_query("What are the GRADE criteria for assessing quality of evidence?")
    })

    # Add documents
    observeEvent(input$upload_docs, {
      req(input$upload_docs)

      docs <- read.csv(input$upload_docs$datapath)

      showNotification("Uploading documents to knowledge base...", type = "message")

      tryCatch({
        response <- POST(
          paste0(api_url, "/ml/rag/add_documents"),
          body = list(documents = docs),
          encode = "json"
        )

        if (status_code(response) == 200) {
          result <- content(response, "parsed")
          showNotification(
            paste("✓ Added", result$n_documents, "documents to knowledge base"),
            type = "message"
          )

          # Refresh KB stats
          observe(rv$kb_stats)
        }
      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error")
      })
    })

    # Add current studies
    observeEvent(input$btn_add_studies, {
      if (!is.null(shared_data) && !is.null(shared_data$studies)) {
        tryCatch({
          response <- POST(
            paste0(api_url, "/ml/rag/add_studies"),
            body = list(studies = shared_data$studies),
            encode = "json"
          )

          if (status_code(response) == 200) {
            result <- content(response, "parsed")
            showNotification(
              paste("✓ Added", result$n_studies, "studies to knowledge base"),
              type = "message"
            )
          }
        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error")
        })
      } else {
        showNotification("No studies loaded yet", type = "warning")
      }
    })

  })
}
