# AI Assistant Module - Ollama Integration
# Local LLM-powered features for evidence synthesis

library(shiny)
library(httr)
library(jsonlite)
library(DT)

#' AI Assistant UI
#'
#' Provides interface for AI-powered features:
#' - Citation screening
#' - Data extraction
#' - Protocol summarization
#' - Query answering
ai_assistant_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header("AI Assistant (Powered by Ollama)"),

      navset_card_tab(
        # Tab 1: Citation Screening
        nav_panel(
          "Citation Screening",
          layout_columns(
            col_widths = c(4, 8),

            # Settings
            card(
              h5("Screening Settings"),

              selectInput(
                ns("screening_model"),
                "Model:",
                choices = c("Llama 3 (8B)" = "llama3",
                           "Mistral (7B)" = "mistral",
                           "BioMistral (7B)" = "biomistral"),
                selected = "llama3"
              ),

              textAreaInput(
                ns("inclusion_criteria"),
                "Inclusion Criteria (PICO):",
                value = "Population: Adults with type 2 diabetes\nIntervention: Metformin\nComparator: Placebo\nOutcome: Cardiovascular events\nStudy Design: RCTs",
                rows = 6,
                width = "100%"
              ),

              sliderInput(
                ns("confidence_threshold"),
                "Auto-Decision Threshold:",
                min = 50,
                max = 95,
                value = 80,
                step = 5,
                post = "%"
              ),

              hr(),

              fileInput(
                ns("citations_file"),
                "Upload Citations (CSV/RIS):",
                accept = c(".csv", ".ris", ".txt")
              ),

              actionButton(
                ns("start_screening"),
                "Start AI Screening",
                class = "btn-primary w-100"
              ),

              hr(),

              h6("Progress:"),
              progressBar(
                id = ns("screening_progress"),
                value = 0,
                display_pct = TRUE
              ),

              textOutput(ns("screening_status"))
            ),

            # Results
            card(
              navset_tab(
                nav_panel(
                  "Results",
                  DTOutput(ns("screening_results"))
                ),
                nav_panel(
                  "Summary",
                  plotOutput(ns("screening_summary_plot")),
                  verbatimTextOutput(ns("screening_summary_text"))
                ),
                nav_panel(
                  "Validation",
                  helpText("Compare AI decisions to human screening for validation"),
                  fileInput(ns("human_decisions"), "Upload Human Decisions (CSV)"),
                  actionButton(ns("validate"), "Validate AI Performance"),
                  verbatimTextOutput(ns("validation_results"))
                )
              )
            )
          )
        ),

        # Tab 2: Data Extraction
        nav_panel(
          "Data Extraction",
          layout_columns(
            col_widths = c(4, 8),

            card(
              h5("Extraction Settings"),

              selectInput(
                ns("extraction_model"),
                "Model:",
                choices = c("Llama 3 (8B)" = "llama3",
                           "Mistral (7B)" = "mistral"),
                selected = "llama3"
              ),

              textAreaInput(
                ns("study_text"),
                "Study Text (Abstract or Full Text):",
                rows = 10,
                width = "100%",
                placeholder = "Paste study text here..."
              ),

              checkboxGroupInput(
                ns("fields_to_extract"),
                "Fields to Extract:",
                choices = c(
                  "Sample size" = "sample_size",
                  "Mean age" = "mean_age",
                  "Percent female" = "percent_female",
                  "Intervention dose" = "dose",
                  "Outcome mean (intervention)" = "outcome_mean_int",
                  "Outcome SD (intervention)" = "outcome_sd_int",
                  "Outcome mean (control)" = "outcome_mean_ctrl",
                  "Outcome SD (control)" = "outcome_sd_ctrl",
                  "Adverse events" = "adverse_events"
                ),
                selected = c("sample_size", "mean_age", "outcome_mean_int",
                            "outcome_sd_int", "outcome_mean_ctrl", "outcome_sd_ctrl")
              ),

              actionButton(
                ns("extract_data"),
                "Extract Data",
                class = "btn-primary w-100"
              )
            ),

            card(
              h5("Extracted Data"),
              DTOutput(ns("extracted_data_table")),
              hr(),
              h6("Raw JSON:"),
              verbatimTextOutput(ns("extracted_data_json")),
              hr(),
              downloadButton(ns("download_extracted"), "Download as CSV")
            )
          )
        ),

        # Tab 3: Ask AI
        nav_panel(
          "Ask AI",
          layout_columns(
            col_widths = c(6, 6),

            card(
              h5("Ask Questions About Your Review"),

              selectInput(
                ns("qa_model"),
                "Model:",
                choices = c("Llama 3 (8B)" = "llama3",
                           "Mistral (7B)" = "mistral",
                           "BioMistral (7B)" = "biomistral"),
                selected = "llama3"
              ),

              textAreaInput(
                ns("question"),
                "Your Question:",
                rows = 3,
                placeholder = "e.g., What is the typical ICER threshold for NICE submissions?"
              ),

              actionButton(
                ns("ask_ai"),
                "Ask AI",
                class = "btn-primary w-100"
              ),

              hr(),

              h6("Example Questions:"),
              tags$ul(
                tags$li("What is the typical ICER threshold for NICE?"),
                tags$li("How do I calculate EVPPI?"),
                tags$li("What is matching-adjusted indirect comparison?"),
                tags$li("Explain target trial emulation in simple terms")
              )
            ),

            card(
              h5("AI Response"),
              uiOutput(ns("ai_response")),
              hr(),
              actionButton(ns("copy_response"), "Copy Response", class = "btn-sm")
            )
          )
        ),

        # Tab 4: Settings & Models
        nav_panel(
          "Settings",
          card(
            h5("Ollama Connection"),

            textInput(
              ns("ollama_url"),
              "Ollama Server URL:",
              value = "http://ollama:11434",
              width = "100%"
            ),

            actionButton(ns("test_connection"), "Test Connection"),

            verbatimTextOutput(ns("connection_status")),

            hr(),

            h5("Installed Models"),

            actionButton(ns("refresh_models"), "Refresh"),

            DTOutput(ns("models_table")),

            hr(),

            h5("Install New Model"),

            selectInput(
              ns("model_to_install"),
              "Model:",
              choices = c(
                "Llama 3 (8B) - General purpose" = "llama3",
                "Mistral (7B) - Fast" = "mistral",
                "BioMistral (7B) - Biomedical" = "biomistral",
                "Mixtral (8x7B) - Advanced" = "mixtral:8x7b",
                "Nomic Embed - Embeddings" = "nomic-embed-text"
              )
            ),

            actionButton(ns("install_model"), "Install Model"),

            helpText("Note: Models are 4-26GB. Installation may take 5-30 minutes.")
          )
        )
      )
    )
  )
}

#' AI Assistant Server
ai_assistant_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    ai_state <- reactiveValues(
      screening_results = NULL,
      extracted_data = NULL,
      models = NULL,
      ai_response_text = ""
    )

    # Helper: Call Ollama API
    call_ollama <- function(endpoint, body) {
      tryCatch({
        response <- POST(
          paste0(input$ollama_url, "/api/", endpoint),
          body = toJSON(body, auto_unbox = TRUE),
          content_type_json(),
          timeout(300)  # 5 minute timeout
        )

        if (status_code(response) == 200) {
          return(content(response, as = "parsed"))
        } else {
          return(list(error = paste("HTTP", status_code(response))))
        }
      }, error = function(e) {
        return(list(error = as.character(e)))
      })
    }

    # Test connection
    observeEvent(input$test_connection, {
      result <- call_ollama("tags", list())

      if (!is.null(result$error)) {
        output$connection_status <- renderPrint({
          cat("✗ Connection failed:\n")
          cat(result$error)
        })
      } else {
        output$connection_status <- renderPrint({
          cat("✓ Connected successfully\n")
          cat("Models available:", length(result$models))
        })
      }
    })

    # Refresh models
    observeEvent(input$refresh_models, {
      result <- call_ollama("tags", list())

      if (!is.null(result$error)) {
        showNotification("Failed to fetch models", type = "error")
      } else {
        ai_state$models <- result$models
      }
    })

    # Display models table
    output$models_table <- renderDT({
      req(ai_state$models)

      models_df <- data.frame(
        Model = sapply(ai_state$models, function(m) m$name),
        Size = sapply(ai_state$models, function(m) {
          size_bytes <- m$size
          if (size_bytes > 1e9) {
            paste0(round(size_bytes / 1e9, 1), " GB")
          } else {
            paste0(round(size_bytes / 1e6, 0), " MB")
          }
        })
      )

      datatable(models_df, options = list(pageLength = 10))
    })

    # Install model
    observeEvent(input$install_model, {
      model <- input$model_to_install

      showModal(modalDialog(
        title = "Installing Model",
        paste("Installing", model, "..."),
        "This may take 5-30 minutes depending on model size and internet speed.",
        easyClose = FALSE,
        footer = NULL
      ))

      # Call pull endpoint (this is simplified - in production use async)
      result <- call_ollama("pull", list(name = model))

      removeModal()

      if (!is.null(result$error)) {
        showNotification(paste("Installation failed:", result$error), type = "error")
      } else {
        showNotification(paste("Model", model, "installed successfully!"), type = "message")
        # Refresh models list
        click("refresh_models")
      }
    })

    # Citation screening
    observeEvent(input$start_screening, {
      req(input$citations_file)
      req(input$inclusion_criteria)

      # Read citations file
      citations <- tryCatch({
        read.csv(input$citations_file$datapath, stringsAsFactors = FALSE)
      }, error = function(e) {
        showNotification("Error reading citations file", type = "error")
        return(NULL)
      })

      req(citations)

      withProgress(message = "AI Screening in progress", value = 0, {
        results_list <- list()

        for (i in 1:nrow(citations)) {
          setProgress(i / nrow(citations), detail = paste("Citation", i, "of", nrow(citations)))

          # Call AI for screening decision
          prompt <- paste0(
            "Inclusion Criteria:\n", input$inclusion_criteria, "\n\n",
            "Study Title: ", citations$title[i], "\n\n",
            "Abstract: ", citations$abstract[i], "\n\n",
            "Decision (INCLUDE/EXCLUDE/UNCERTAIN):\n",
            "Confidence (0-100):\n",
            "Reasoning:"
          )

          response <- call_ollama("generate", list(
            model = input$screening_model,
            prompt = prompt,
            system = "You are an expert systematic reviewer. Screen citations conservatively.",
            options = list(temperature = 0.3)
          ))

          # Parse response (simplified)
          decision <- "uncertain"
          confidence <- 50

          if (!is.null(response$response)) {
            text <- tolower(response$response)
            if (grepl("include", text) && !grepl("exclude", text)) {
              decision <- "include"
            } else if (grepl("exclude", text)) {
              decision <- "exclude"
            }
          }

          results_list[[i]] <- data.frame(
            id = citations$id[i],
            title = citations$title[i],
            decision = decision,
            confidence = confidence,
            needs_review = confidence < input$confidence_threshold
          )
        }

        ai_state$screening_results <- do.call(rbind, results_list)
        showNotification("Screening complete!", type = "message")
      })
    })

    # Display screening results
    output$screening_results <- renderDT({
      req(ai_state$screening_results)

      datatable(
        ai_state$screening_results,
        options = list(pageLength = 25),
        filter = "top"
      ) %>%
        formatStyle(
          'decision',
          backgroundColor = styleEqual(
            c('include', 'exclude', 'uncertain'),
            c('#d4edda', '#f8d7da', '#fff3cd')
          )
        )
    })

    # Data extraction
    observeEvent(input$extract_data, {
      req(input$study_text)
      req(input$fields_to_extract)

      withProgress(message = "Extracting data...", {
        fields_str <- paste(input$fields_to_extract, collapse = ", ")

        prompt <- paste0(
          "Extract the following fields from this study:\n",
          fields_str, "\n\n",
          "Study Text:\n", input$study_text, "\n\n",
          "Return as JSON:\n",
          "{\n  \"field_name\": value\n}"
        )

        response <- call_ollama("generate", list(
          model = input$extraction_model,
          prompt = prompt,
          system = "You are a data extraction expert. Return precise JSON.",
          options = list(temperature = 0.2)
        ))

        # Parse JSON from response
        if (!is.null(response$response)) {
          # Try to extract JSON
          json_text <- response$response
          extracted <- tryCatch({
            fromJSON(json_text)
          }, error = function(e) {
            list(error = "Failed to parse JSON")
          })

          ai_state$extracted_data <- extracted
        }
      })
    })

    # Display extracted data
    output$extracted_data_table <- renderDT({
      req(ai_state$extracted_data)

      df <- data.frame(
        Field = names(ai_state$extracted_data),
        Value = as.character(unlist(ai_state$extracted_data))
      )

      datatable(df, options = list(pageLength = 20))
    })

    output$extracted_data_json <- renderPrint({
      req(ai_state$extracted_data)
      cat(toJSON(ai_state$extracted_data, auto_unbox = TRUE, pretty = TRUE))
    })

    # Ask AI
    observeEvent(input$ask_ai, {
      req(input$question)

      withProgress(message = "AI is thinking...", {
        response <- call_ollama("generate", list(
          model = input$qa_model,
          prompt = input$question,
          system = "You are a health economics and HTA expert. Provide clear, accurate answers.",
          options = list(temperature = 0.7)
        ))

        if (!is.null(response$response)) {
          ai_state$ai_response_text <- response$response
        } else {
          ai_state$ai_response_text <- "Error: No response received"
        }
      })
    })

    output$ai_response <- renderUI({
      req(ai_state$ai_response_text)

      tags$div(
        class = "ai-response-box",
        style = "background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff;",
        tags$p(ai_state$ai_response_text)
      )
    })

    # Initialize: Load models on startup
    observe({
      result <- call_ollama("tags", list())
      if (!is.null(result$models)) {
        ai_state$models <- result$models
      }
    })
  })
}
