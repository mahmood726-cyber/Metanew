# High-Resolution Plot Download Utilities
# Provides downloadHandler functions for all plot types with format selection
# Supports PNG, JPG, PDF, SVG at maximum resolution

library(shiny)
library(ggplot2)
library(plotly)

#' Create Plot Download UI Components
#'
#' @param id Namespace ID for the download controls
#' @param plot_name Name of the plot (e.g., "Forest Plot", "Funnel Plot")
#' @param default_width Default width in pixels (or inches for PDF)
#' @param default_height Default height in pixels (or inches for PDF)
#' @param formats Vector of supported formats (default: all)
#' @return tagList with download button and settings
#' @export
plot_download_ui <- function(id,
                             plot_name = "Plot",
                             default_width = 3000,
                             default_height = 2000,
                             formats = c("PNG", "JPG", "PDF", "SVG")) {
  ns <- NS(id)

  tagList(
    tags$div(
      class = "plot-download-controls",
      style = "margin-top: 15px; padding: 15px; background-color: #f8f9fa; border-radius: 5px;",

      tags$h5(
        icon("download"),
        paste("Download", plot_name),
        style = "margin-top: 0; color: #495057;"
      ),

      layout_columns(
        col_widths = c(3, 3, 2, 2, 2),

        selectInput(
          ns("format"),
          "Format",
          choices = formats,
          selected = formats[1]
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] != 'PDF'", ns("format")),
          numericInput(
            ns("width"),
            "Width (px)",
            value = default_width,
            min = 800,
            max = 8000,
            step = 100
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'PDF'", ns("format")),
          numericInput(
            ns("width_pdf"),
            "Width (in)",
            value = round(default_width / 300, 1),
            min = 5,
            max = 20,
            step = 0.5
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] != 'PDF'", ns("format")),
          numericInput(
            ns("height"),
            "Height (px)",
            value = default_height,
            min = 600,
            max = 6000,
            step = 100
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'PDF'", ns("format")),
          numericInput(
            ns("height_pdf"),
            "Height (in)",
            value = round(default_height / 300, 1),
            min = 4,
            max = 16,
            step = 0.5
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'PNG' || input['%s'] == 'JPG'",
                             ns("format"), ns("format")),
          numericInput(
            ns("dpi"),
            "DPI",
            value = 300,
            min = 72,
            max = 600,
            step = 50
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'JPG'", ns("format")),
          numericInput(
            ns("quality"),
            "Quality %",
            value = 95,
            min = 50,
            max = 100,
            step = 5
          )
        ),

        tags$div(
          style = "margin-top: 25px;",
          downloadButton(
            ns("download"),
            "Download",
            class = "btn-primary w-100",
            icon = icon("download")
          )
        )
      ),

      tags$small(
        class = "text-muted",
        tags$br(),
        "Tip: Use PNG (300+ DPI) for publications, SVG for presentations, PDF for print quality"
      )
    )
  )
}


#' Create Download Handler for Base R Plots
#'
#' @param plot_function Function that generates the plot (no arguments)
#' @param base_filename Base name for downloaded file (without extension)
#' @param input Shiny input object with format, width, height, dpi, quality
#' @return downloadHandler object
#' @export
create_base_plot_download_handler <- function(plot_function, base_filename, input) {
  downloadHandler(
    filename = function() {
      format <- tolower(input$format)
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      paste0(base_filename, "_", timestamp, ".", format)
    },

    content = function(file) {
      format <- tolower(input$format)

      # Get dimensions
      if (format == "pdf") {
        width <- input$width_pdf
        height <- input$height_pdf
      } else {
        width <- input$width
        height <- input$height
      }

      # Open graphics device
      if (format == "png") {
        png(
          file,
          width = width,
          height = height,
          res = input$dpi,
          type = "cairo"  # Better anti-aliasing
        )
      } else if (format == "jpg") {
        jpeg(
          file,
          width = width,
          height = height,
          res = input$dpi,
          quality = input$quality,
          type = "cairo"
        )
      } else if (format == "pdf") {
        pdf(
          file,
          width = width,
          height = height,
          useDingbats = FALSE  # Better compatibility
        )
      } else if (format == "svg") {
        svg(
          file,
          width = width / 96,  # Convert pixels to inches (96 DPI screen)
          height = height / 96
        )
      }

      # Generate plot
      tryCatch({
        plot_function()
      }, error = function(e) {
        # Close device even if plot fails
        dev.off()
        stop(paste("Plot generation failed:", e$message))
      })

      # Close device
      dev.off()
    }
  )
}


#' Create Download Handler for ggplot2 Plots
#'
#' @param plot_reactive Reactive expression that returns a ggplot object
#' @param base_filename Base name for downloaded file (without extension)
#' @param input Shiny input object with format, width, height, dpi
#' @return downloadHandler object
#' @export
create_ggplot_download_handler <- function(plot_reactive, base_filename, input) {
  downloadHandler(
    filename = function() {
      format <- tolower(input$format)
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      paste0(base_filename, "_", timestamp, ".", format)
    },

    content = function(file) {
      format <- tolower(input$format)
      plot_obj <- plot_reactive()

      if (is.null(plot_obj)) {
        stop("No plot available to download")
      }

      # Get dimensions
      if (format == "pdf") {
        width <- input$width_pdf
        height <- input$height_pdf
        units <- "in"
        dpi <- 300  # Standard for PDF
      } else {
        width <- input$width
        height <- input$height
        units <- "px"
        dpi <- if (format %in% c("png", "jpg")) input$dpi else 96
      }

      # Device type
      device <- switch(
        format,
        "png" = "png",
        "jpg" = "jpeg",
        "pdf" = "pdf",
        "svg" = "svg",
        "png"  # default
      )

      # Additional arguments
      device_args <- list()
      if (format == "jpg") {
        device_args$quality <- input$quality
      }

      # Save plot
      ggsave(
        filename = file,
        plot = plot_obj,
        device = device,
        width = width,
        height = height,
        units = units,
        dpi = dpi,
        bg = "white",  # Ensure white background
        device_args
      )
    }
  )
}


#' Create Download Handler for Plotly Plots (Static Export)
#'
#' Converts plotly to static image using orca or kaleido
#'
#' @param plotly_reactive Reactive expression that returns a plotly object
#' @param base_filename Base name for downloaded file (without extension)
#' @param input Shiny input object with format, width, height
#' @return downloadHandler object
#' @export
create_plotly_download_handler <- function(plotly_reactive, base_filename, input) {
  downloadHandler(
    filename = function() {
      format <- tolower(input$format)
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      paste0(base_filename, "_", timestamp, ".", format)
    },

    content = function(file) {
      format <- tolower(input$format)
      plot_obj <- plotly_reactive()

      if (is.null(plot_obj)) {
        stop("No plot available to download")
      }

      # Get dimensions
      width <- if (format == "pdf") input$width_pdf * 96 else input$width
      height <- if (format == "pdf") input$height_pdf * 96 else input$height

      # Try kaleido first (newer), fall back to orca
      tryCatch({
        if (requireNamespace("kaleido", quietly = TRUE)) {
          kaleido::save_image(
            plot_obj,
            file = file,
            format = format,
            width = width,
            height = height
          )
        } else if (requireNamespace("orca", quietly = TRUE)) {
          orca::orca(
            plot_obj,
            file = file,
            format = format,
            width = width,
            height = height
          )
        } else {
          # Fallback: Save as HTML and convert (requires webshot2)
          if (requireNamespace("webshot2", quietly = TRUE)) {
            temp_html <- tempfile(fileext = ".html")
            htmlwidgets::saveWidget(plot_obj, temp_html, selfcontained = TRUE)

            webshot2::webshot(
              temp_html,
              file = file,
              vwidth = width,
              vheight = height
            )

            unlink(temp_html)
          } else {
            stop("Please install 'kaleido', 'orca', or 'webshot2' package to download plotly plots.\nRun: install.packages(c('kaleido', 'webshot2'))")
          }
        }
      }, error = function(e) {
        stop(paste("Failed to export plotly plot:", e$message))
      })
    }
  )
}


#' Create Download Handler for metafor Forest Plots
#'
#' Special handler for metafor::forest() plots with custom sizing
#'
#' @param ma_result Meta-analysis result object (from run_pairwise_ma)
#' @param outcome_name Name of the outcome
#' @param input Shiny input object with format, width, height, dpi
#' @return downloadHandler object
#' @export
create_forest_download_handler <- function(ma_result, outcome_name, input) {
  create_base_plot_download_handler(
    plot_function = function() {
      # Use the existing create_forest_plot_static function if available
      if (exists("create_forest_plot_static")) {
        create_forest_plot_static(ma_result, outcome_name)
      } else {
        # Fallback to basic metafor forest plot
        library(metafor)

        if (!is.null(ma_result$model_object)) {
          forest(
            ma_result$model_object,
            slab = ma_result$data$study_id,
            xlab = "Effect Size",
            main = paste("Forest Plot:", outcome_name),
            cex = 0.8,
            psize = 1
          )
        } else {
          stop("No model object available for forest plot")
        }
      }
    },
    base_filename = paste0("forest_plot_", gsub("[^A-Za-z0-9_]", "_", outcome_name)),
    input = input
  )
}


#' Create Download Handler for Funnel Plots
#'
#' @param ma_result Meta-analysis result object
#' @param outcome_name Name of the outcome
#' @param input Shiny input object with format, width, height, dpi
#' @param show_trim_fill Whether to show trim-and-fill results
#' @return downloadHandler object
#' @export
create_funnel_download_handler <- function(ma_result, outcome_name, input, show_trim_fill = TRUE) {
  create_base_plot_download_handler(
    plot_function = function() {
      library(metafor)

      if (!is.null(ma_result$model_object)) {
        # Basic funnel plot
        funnel(
          ma_result$model_object,
          xlab = "Effect Size",
          ylab = "Standard Error",
          main = paste("Funnel Plot:", outcome_name),
          pch = 19,
          col = "steelblue"
        )

        # Add trim-and-fill if requested and available
        if (show_trim_fill && !is.null(ma_result$trim_fill)) {
          points(
            ma_result$trim_fill$yi_imputed,
            ma_result$trim_fill$sei_imputed,
            pch = 1,
            col = "red",
            cex = 1.2
          )
          legend(
            "topright",
            legend = c("Original studies", "Imputed studies"),
            pch = c(19, 1),
            col = c("steelblue", "red"),
            cex = 0.8
          )
        }
      } else {
        stop("No model object available for funnel plot")
      }
    },
    base_filename = paste0("funnel_plot_", gsub("[^A-Za-z0-9_]", "_", outcome_name)),
    input = input
  )
}


#' Quick Download Button (Simple Version)
#'
#' Simplified version with just format selection and download button
#'
#' @param id Namespace ID
#' @param formats Supported formats
#' @return tagList with minimal UI
#' @export
quick_download_ui <- function(id, formats = c("PNG", "JPG", "PDF", "SVG")) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(6, 6),

      selectInput(
        ns("format"),
        "Format",
        choices = formats,
        selected = "PNG"
      ),

      downloadButton(
        ns("download"),
        "Download Plot",
        class = "btn-sm btn-outline-primary",
        icon = icon("download"),
        style = "margin-top: 25px;"
      )
    )
  )
}
