# Global Health Data Integration Module
# R Shiny UI for WHO, World Bank, IHME Data Integration
#
# Features:
# - Multi-source data fetching
# - Country/indicator selection
# - Interactive visualizations
# - Data export for meta-analysis
#
# Value: £20k (user-friendly interface)
#
# Dependencies:
# - shiny: UI framework
# - reticulate: Python integration
# - plotly: Interactive plots
# - DT: Data tables

library(shiny)
library(reticulate)
library(plotly)
library(DT)

# ==================== Python Integration ====================

# Initialize Python integration
use_python(Sys.which("python3"))

# Import Python modules
global_health <- NULL

tryCatch({
  py_run_string("
import sys
sys.path.append('./backend')
from data_integration.global_health_integration import (
    GlobalHealthDataIntegration,
    IntegrationConfig,
    IntegrationRequest,
    IntegrationMode
)
")

  global_health <- import("data_integration.global_health_integration")
  message("✓ Python data integration module loaded")
}, error = function(e) {
  message("⚠ Python module not available: ", e$message)
})


# ==================== UI Components ====================

globalHealthDataUI <- function(id) {
  ns <- NS(id)

  tagList(
    h2("Global Health Data Integration"),
    p("Fetch and integrate data from WHO, World Bank, and IHME GBD"),

    fluidRow(
      # Left panel: Data source selection
      column(4,
        wellPanel(
          h4("Data Sources"),

          # WHO indicators
          checkboxInput(ns("use_who"), "WHO Global Health Observatory", value = TRUE),
          conditionalPanel(
            condition = sprintf("input['%s']", ns("use_who")),
            selectizeInput(
              ns("who_indicators"),
              "WHO Indicators:",
              choices = c(
                "Life Expectancy" = "WHOSIS_000001",
                "Infant Mortality" = "MDG_0000000001",
                "Under-5 Mortality" = "MDG_0000000026",
                "UHC Coverage" = "SA_0000001688",
                "Obesity Prevalence" = "NCD_BMI_30A"
              ),
              multiple = TRUE,
              selected = "WHOSIS_000001"
            )
          ),

          # World Bank indicators
          checkboxInput(ns("use_wb"), "World Bank WDI", value = TRUE),
          conditionalPanel(
            condition = sprintf("input['%s']", ns("use_wb")),
            selectizeInput(
              ns("wb_indicators"),
              "World Bank Indicators:",
              choices = c(
                "Health Expenditure % GDP" = "SH.XPD.CHEX.GD.ZS",
                "Health Expenditure per Capita" = "SH.XPD.CHEX.PC.CD",
                "GDP per Capita" = "NY.GDP.PCAP.CD",
                "Population" = "SP.POP.TOTL",
                "Life Expectancy" = "SP.DYN.LE00.IN",
                "Poverty Headcount" = "SI.POV.DDAY"
              ),
              multiple = TRUE,
              selected = c("SH.XPD.CHEX.GD.ZS", "NY.GDP.PCAP.CD")
            )
          ),

          hr(),

          # Country selection
          h4("Countries"),
          selectizeInput(
            ns("countries"),
            "Select Countries (ISO3 codes):",
            choices = c("USA", "GBR", "CHN", "IND", "BRA", "ZAF", "DEU", "FRA", "JPN", "KOR"),
            multiple = TRUE,
            selected = c("USA", "GBR", "CHN")
          ),

          # Year selection
          h4("Years"),
          sliderInput(
            ns("year_range"),
            "Year Range:",
            min = 2000,
            max = 2023,
            value = c(2015, 2020),
            step = 1,
            sep = ""
          ),

          hr(),

          # Integration options
          h4("Options"),
          checkboxInput(ns("use_cache"), "Use Cache (faster)", value = TRUE),
          checkboxInput(ns("use_llm_cleaning"), "AI-Powered Cleaning", value = FALSE),
          selectInput(
            ns("integration_mode"),
            "Integration Mode:",
            choices = c(
              "Fetch Only" = "FETCH_ONLY",
              "Basic Cleaning" = "CLEAN",
              "AI Cleaning" = "AI_CLEAN",
              "Full (Recommended)" = "FULL"
            ),
            selected = "FULL"
          ),

          hr(),

          # Action button
          actionButton(
            ns("fetch_data"),
            "Fetch Data",
            icon = icon("download"),
            class = "btn-primary btn-lg btn-block"
          )
        )
      ),

      # Right panel: Results
      column(8,
        # Integration status
        uiOutput(ns("integration_status")),

        # Tabs for different views
        tabsetPanel(
          id = ns("result_tabs"),

          # Data table
          tabPanel(
            "Data Table",
            br(),
            DTOutput(ns("data_table"))
          ),

          # Visualizations
          tabPanel(
            "Visualizations",
            br(),
            selectInput(
              ns("vis_indicator"),
              "Select Indicator:",
              choices = NULL
            ),
            plotlyOutput(ns("time_series_plot"), height = "400px"),
            br(),
            plotlyOutput(ns("country_comparison_plot"), height = "400px")
          ),

          # Summary statistics
          tabPanel(
            "Summary",
            br(),
            verbatimTextOutput(ns("integration_summary")),
            br(),
            h4("Data Quality"),
            verbatimTextOutput(ns("data_quality"))
          ),

          # Export
          tabPanel(
            "Export",
            br(),
            h4("Export Data"),
            p("Export integrated data for meta-analysis"),
            radioButtons(
              ns("export_format"),
              "Format:",
              choices = c("CSV", "Excel", "Parquet", "RData"),
              selected = "CSV",
              inline = TRUE
            ),
            downloadButton(ns("download_data"), "Download Data", class = "btn-primary"),
            br(), br(),
            h4("Export for Meta-Analysis"),
            p("Export ready for RevMan, CMA, or R meta packages"),
            downloadButton(ns("download_meta"), "Download Meta Format", class = "btn-success")
          )
        )
      )
    )
  )
}


# ==================== Server Logic ====================

globalHealthDataServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    values <- reactiveValues(
      integrated_data = NULL,
      integration_result = NULL
    )

    # Fetch data when button clicked
    observeEvent(input$fetch_data, {

      # Show progress
      withProgress(message = "Fetching data...", value = 0, {

        if (is.null(global_health)) {
          showNotification(
            "Python integration module not available. Please check installation.",
            type = "error",
            duration = 10
          )
          return()
        }

        tryCatch({
          incProgress(0.1, detail = "Initializing...")

          # Build configuration
          config <- global_health$IntegrationConfig(
            cache_dir = file.path(getwd(), "data", "cache"),
            use_cache = input$use_cache,
            mode = global_health[[paste0("IntegrationMode.", input$integration_mode)]],
            use_llm_cleaning = input$use_llm_cleaning
          )

          # Initialize integration system
          integration <- global_health$GlobalHealthDataIntegration(config)

          incProgress(0.2, detail = "Building request...")

          # Build request
          years <- seq(input$year_range[1], input$year_range[2])

          who_inds <- if (input$use_who && length(input$who_indicators) > 0) {
            as.list(input$who_indicators)
          } else {
            list()
          }

          wb_inds <- if (input$use_wb && length(input$wb_indicators) > 0) {
            as.list(input$wb_indicators)
          } else {
            list()
          }

          request <- global_health$IntegrationRequest(
            who_indicators = who_inds,
            wb_indicators = wb_inds,
            countries = as.list(input$countries),
            years = as.list(years),
            wide_format = FALSE
          )

          incProgress(0.3, detail = "Fetching from APIs...")

          # Fetch and integrate
          result <- integration$fetch_and_integrate(request)

          incProgress(0.8, detail = "Converting to R...")

          # Convert to R DataFrame
          df <- py_to_r(result$data)

          # Store results
          values$integrated_data <- df
          values$integration_result <- result

          incProgress(1.0, detail = "Complete!")

          showNotification(
            paste0("✓ Fetched ", nrow(df), " records from ", length(result$sources_used), " sources"),
            type = "message",
            duration = 5
          )

        }, error = function(e) {
          showNotification(
            paste("Error fetching data:", e$message),
            type = "error",
            duration = 10
          )
        })
      })
    })

    # Integration status
    output$integration_status <- renderUI({
      req(values$integration_result)

      result <- values$integration_result

      wellPanel(
        h4("Integration Complete ✓"),
        p(
          strong("Sources: "), paste(result$sources_used, collapse = ", "), br(),
          strong("Records: "), format(result$records_final, big.mark = ","), br(),
          strong("Countries: "), values$integration_result$metadata$countries, br(),
          strong("Quality Score: "), sprintf("%.1f%%", result$harmonization_confidence * 100)
        )
      )
    })

    # Data table
    output$data_table <- renderDT({
      req(values$integrated_data)

      datatable(
        values$integrated_data,
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          searching = TRUE
        ),
        filter = "top"
      )
    })

    # Update indicator choices for visualization
    observe({
      req(values$integrated_data)

      if ("indicator" %in% names(values$integrated_data)) {
        indicators <- unique(values$integrated_data$indicator)
        updateSelectInput(session, "vis_indicator", choices = indicators)
      }
    })

    # Time series plot
    output$time_series_plot <- renderPlotly({
      req(values$integrated_data, input$vis_indicator)

      df <- values$integrated_data

      if (!"year" %in% names(df) || !"value" %in% names(df)) {
        return(NULL)
      }

      # Filter by indicator
      if ("indicator" %in% names(df)) {
        df <- df[df$indicator == input$vis_indicator, ]
      }

      # Create plot
      p <- plot_ly(df, x = ~year, y = ~value, color = ~country_iso3,
                   type = "scatter", mode = "lines+markers") %>%
        layout(
          title = paste("Time Series:", input$vis_indicator),
          xaxis = list(title = "Year"),
          yaxis = list(title = "Value"),
          hovermode = "closest"
        )

      p
    })

    # Country comparison plot
    output$country_comparison_plot <- renderPlotly({
      req(values$integrated_data, input$vis_indicator)

      df <- values$integrated_data

      if (!"value" %in% names(df)) {
        return(NULL)
      }

      # Filter by indicator
      if ("indicator" %in% names(df)) {
        df <- df[df$indicator == input$vis_indicator, ]
      }

      # Get latest year
      if ("year" %in% names(df)) {
        latest_year <- max(df$year, na.rm = TRUE)
        df <- df[df$year == latest_year, ]
      }

      # Create bar plot
      p <- plot_ly(df, x = ~country_iso3, y = ~value, type = "bar") %>%
        layout(
          title = paste("Country Comparison:", input$vis_indicator),
          xaxis = list(title = "Country"),
          yaxis = list(title = "Value")
        )

      p
    })

    # Integration summary
    output$integration_summary <- renderPrint({
      req(values$integration_result)

      cat(py_to_r(values$integration_result$summary()))
    })

    # Data quality
    output$data_quality <- renderPrint({
      req(values$integrated_data)

      df <- values$integrated_data

      cat("Data Quality Assessment\n")
      cat("=======================\n\n")
      cat("Total Records:", nrow(df), "\n")
      cat("Variables:", ncol(df), "\n\n")

      # Missing values
      cat("Missing Values:\n")
      missing <- sapply(df, function(x) sum(is.na(x)))
      for (col in names(missing)) {
        if (missing[col] > 0) {
          pct <- missing[col] / nrow(df) * 100
          cat(sprintf("  %s: %d (%.1f%%)\n", col, missing[col], pct))
        }
      }

      if ("value" %in% names(df)) {
        cat("\nValue Statistics:\n")
        cat("  Min:", min(df$value, na.rm = TRUE), "\n")
        cat("  Max:", max(df$value, na.rm = TRUE), "\n")
        cat("  Mean:", mean(df$value, na.rm = TRUE), "\n")
        cat("  Median:", median(df$value, na.rm = TRUE), "\n")
      }
    })

    # Download data
    output$download_data <- downloadHandler(
      filename = function() {
        ext <- switch(input$export_format,
                     "CSV" = ".csv",
                     "Excel" = ".xlsx",
                     "Parquet" = ".parquet",
                     "RData" = ".RData")
        paste0("global_health_data_", Sys.Date(), ext)
      },
      content = function(file) {
        req(values$integrated_data)

        df <- values$integrated_data

        if (input$export_format == "CSV") {
          write.csv(df, file, row.names = FALSE)
        } else if (input$export_format == "Excel") {
          library(writexl)
          write_xlsx(df, file)
        } else if (input$export_format == "Parquet") {
          library(arrow)
          write_parquet(df, file)
        } else if (input$export_format == "RData") {
          save(df, file = file)
        }
      }
    )

    # Download meta format
    output$download_meta <- downloadHandler(
      filename = function() {
        paste0("meta_analysis_data_", Sys.Date(), ".csv")
      },
      content = function(file) {
        req(values$integrated_data)

        # Convert to meta-analysis format
        # (study, outcome, n, mean, sd, etc.)
        df <- values$integrated_data

        # TODO: Format conversion for RevMan/CMA
        write.csv(df, file, row.names = FALSE)
      }
    )
  })
}


# ==================== Standalone App (for testing) ====================

if (interactive()) {
  ui <- fluidPage(
    titlePanel("Global Health Data Integration"),
    globalHealthDataUI("test")
  )

  server <- function(input, output, session) {
    globalHealthDataServer("test")
  }

  shinyApp(ui, server)
}
