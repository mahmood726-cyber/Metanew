# Dataset Browser Module
# Browse and search integrated meta-analysis datasets
# From Pairwise70, NMA51, NMArepo, and DTA70

library(shiny)
library(bslib)
library(DT)
library(httr)
library(jsonlite)

# ===== UI =====

dataset_browser_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        class = "bg-primary text-white",
        h3("Meta-Analysis Dataset Catalog", class = "mb-0")
      ),
      card_body(
        # Summary statistics
        fluidRow(
          column(3, value_box(
            title = "Total Datasets",
            value = textOutput(ns("total_datasets")),
            showcase = icon("database"),
            theme = "primary"
          )),
          column(3, value_box(
            title = "Pairwise Datasets",
            value = textOutput(ns("pairwise_count")),
            showcase = icon("chart-bar"),
            theme = "success"
          )),
          column(3, value_box(
            title = "NMA Datasets",
            value = textOutput(ns("nma_count")),
            showcase = icon("project-diagram"),
            theme = "info"
          )),
          column(3, value_box(
            title = "DTA Datasets",
            value = textOutput(ns("dta_count")),
            showcase = icon("stethoscope"),
            theme = "warning"
          ))
        ),

        hr(),

        # Search and filter
        fluidRow(
          column(4,
            textInput(ns("search"), "Search datasets",
                     placeholder = "Enter keywords, DOI, or dataset name...")
          ),
          column(3,
            selectInput(ns("source_filter"), "Source",
                       choices = c("All" = "", "Pairwise70", "NMA51", "NMArepo", "DTA70"),
                       selected = "")
          ),
          column(3,
            selectInput(ns("type_filter"), "Type",
                       choices = c("All" = "", "Pairwise" = "pairwise", "NMA" = "nma", "DTA" = "dta"),
                       selected = "")
          ),
          column(2,
            br(),
            actionButton(ns("search_btn"), "Search", class = "btn-primary btn-block")
          )
        ),

        hr(),

        # Dataset table
        DTOutput(ns("dataset_table")),

        hr(),

        # Selected dataset details
        uiOutput(ns("dataset_details"))
      )
    )
  )
}


# ===== SERVER =====

dataset_browser_server <- function(id, api_base_url = "http://localhost:8000") {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    datasets <- reactiveVal(data.frame())
    summary_stats <- reactiveVal(list())
    selected_dataset <- reactiveVal(NULL)

    # Fetch summary statistics on load
    observe({
      tryCatch({
        response <- GET(paste0(api_base_url, "/datasets/summary"))

        if (status_code(response) == 200) {
          stats <- content(response, as = "parsed")
          summary_stats(stats)
        }
      }, error = function(e) {
        showNotification(paste("Error fetching summary:", e$message),
                        type = "error")
      })
    })

    # Fetch datasets
    fetch_datasets <- function(source = NULL, type = NULL, query = NULL) {
      tryCatch({
        url <- paste0(api_base_url, "/datasets/")

        # Build query parameters
        params <- list(limit = 500)

        if (!is.null(source) && source != "") {
          params$source <- source
        }

        if (!is.null(type) && type != "") {
          params$type <- type
        }

        if (!is.null(query) && query != "") {
          # Use search endpoint
          url <- paste0(api_base_url, "/datasets/search/", URLencode(query))
        }

        response <- GET(url, query = params)

        if (status_code(response) == 200) {
          data <- content(response, as = "parsed")

          # Convert to data frame
          df <- do.call(rbind, lapply(data, function(x) {
            data.frame(
              id = x$id %||% "",
              name = x$name %||% "",
              source = x$source %||% "",
              type = x$type %||% "",
              outcome_type = x$outcome_type %||% "",
              n_studies = x$n_studies %||% NA,
              description = x$description %||% "",
              review_doi = x$review_doi %||% "",
              stringsAsFactors = FALSE
            )
          }))

          datasets(df)
        } else {
          showNotification("Failed to fetch datasets", type = "error")
        }
      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error")
      })
    }

    # Initial load
    observe({
      fetch_datasets()
    })

    # Search button
    observeEvent(input$search_btn, {
      fetch_datasets(
        source = input$source_filter,
        type = input$type_filter,
        query = if (input$search != "") input$search else NULL
      )
    })

    # Summary statistics outputs
    output$total_datasets <- renderText({
      stats <- summary_stats()
      if (!is.null(stats$total_datasets)) {
        as.character(stats$total_datasets)
      } else {
        "..."
      }
    })

    output$pairwise_count <- renderText({
      stats <- summary_stats()
      if (!is.null(stats$by_type$pairwise)) {
        as.character(stats$by_type$pairwise)
      } else {
        "0"
      }
    })

    output$nma_count <- renderText({
      stats <- summary_stats()
      if (!is.null(stats$by_type$nma)) {
        as.character(stats$by_type$nma)
      } else {
        "0"
      }
    })

    output$dta_count <- renderText({
      stats <- summary_stats()
      if (!is.null(stats$by_type$dta)) {
        as.character(stats$by_type$dta)
      } else {
        "0"
      }
    })

    # Dataset table
    output$dataset_table <- renderDT({
      df <- datasets()

      if (nrow(df) == 0) {
        return(data.frame(Message = "No datasets found. Try adjusting your filters."))
      }

      # Format for display
      display_df <- df[, c("name", "source", "type", "outcome_type", "description")]
      names(display_df) <- c("Dataset", "Source", "Type", "Outcome Type", "Description")

      datatable(
        display_df,
        selection = "single",
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          dom = 'frtip',
          autoWidth = TRUE,
          columnDefs = list(
            list(width = '25%', targets = 0),
            list(width = '10%', targets = 1),
            list(width = '10%', targets = 2),
            list(width = '15%', targets = 3),
            list(width = '40%', targets = 4)
          )
        ),
        rownames = FALSE,
        class = "table-striped table-hover"
      )
    })

    # Show dataset details when row selected
    observeEvent(input$dataset_table_rows_selected, {
      df <- datasets()
      row_idx <- input$dataset_table_rows_selected

      if (length(row_idx) > 0 && row_idx <= nrow(df)) {
        dataset_id <- df$id[row_idx]

        # Fetch full dataset details
        tryCatch({
          response <- GET(paste0(api_base_url, "/datasets/", dataset_id))

          if (status_code(response) == 200) {
            dataset <- content(response, as = "parsed")
            selected_dataset(dataset)

            # Fetch recommended apps
            apps_response <- GET(paste0(api_base_url, "/datasets/", dataset_id, "/apps"))

            if (status_code(apps_response) == 200) {
              recommended_apps <- content(apps_response, as = "parsed")
              dataset$recommended_apps <- recommended_apps
              selected_dataset(dataset)
            }
          }
        }, error = function(e) {
          showNotification(paste("Error fetching dataset details:", e$message),
                          type = "error")
        })
      }
    })

    # Dataset details panel
    output$dataset_details <- renderUI({
      dataset <- selected_dataset()

      if (is.null(dataset)) {
        return(div(
          class = "alert alert-info",
          icon("info-circle"),
          " Select a dataset from the table above to view details and recommended apps."
        ))
      }

      tagList(
        h4(dataset$name),
        p(class = "text-muted", dataset$description),

        fluidRow(
          column(6,
            h5("Dataset Information"),
            tags$dl(
              tags$dt("ID:"), tags$dd(dataset$id),
              tags$dt("Source:"), tags$dd(dataset$source),
              tags$dt("Type:"), tags$dd(dataset$type),
              tags$dt("Outcome Type:"), tags$dd(dataset$outcome_type %||% "Not specified"),
              if (!is.null(dataset$n_studies)) {
                tagList(tags$dt("Number of Studies:"), tags$dd(dataset$n_studies))
              },
              if (!is.null(dataset$review_doi)) {
                tagList(
                  tags$dt("DOI:"),
                  tags$dd(tags$a(href = paste0("https://doi.org/", dataset$review_doi),
                                target = "_blank", dataset$review_doi))
                )
              }
            )
          ),
          column(6,
            h5("Recommended Apps"),
            if (!is.null(dataset$recommended_apps) && length(dataset$recommended_apps) > 0) {
              tagList(
                lapply(dataset$recommended_apps[1:min(5, length(dataset$recommended_apps))], function(app) {
                  badge_class <- switch(app$compatibility,
                    "perfect" = "bg-success",
                    "good" = "bg-info",
                    "possible" = "bg-secondary"
                  )

                  div(
                    class = "mb-2",
                    tags$span(class = paste("badge", badge_class), app$compatibility),
                    " ",
                    tags$strong(app$app_name),
                    br(),
                    tags$small(class = "text-muted", app$reason),
                    br(),
                    actionLink(
                      paste0("launch_", app$app_id),
                      "Launch App →",
                      class = "btn btn-sm btn-outline-primary mt-1"
                    )
                  )
                })
              )
            } else {
              p(class = "text-muted", "No specific app recommendations available.")
            }
          )
        ),

        hr(),

        fluidRow(
          column(6,
            actionButton(paste0("load_", dataset$id), "Load Dataset",
                        class = "btn-primary btn-block", icon = icon("download"))
          ),
          column(6,
            actionButton(paste0("export_", dataset$id), "Export Metadata",
                        class = "btn-secondary btn-block", icon = icon("file-export"))
          )
        )
      )
    })

    # Return selected dataset for use in other modules
    return(selected_dataset)
  })
}


# Helper function for null coalescing
`%||%` <- function(a, b) if (is.null(a)) b else a
