# Reporting Module - Word/PDF/PPT Exports
library(shiny)
library(rmarkdown)
library(officer)

reporting_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header("Generate Reports"),
    layout_columns(
      col_widths = c(4, 8),
      card(
        h5("Report Settings"),
        textInput(ns("report_title"), "Report Title", "Meta-Analysis Report"),
        textInput(ns("author"), "Author", Sys.getenv("USER")),
        selectInput(ns("format"), "Format",
                    choices = c("Word" = "word", "PDF" = "pdf", "PowerPoint" = "pptx")),
        checkboxGroupInput(ns("sections"), "Include Sections",
                           choices = c("Protocol", "Methods", "Results", "Forest Plots",
                                       "Heterogeneity", "Economics", "Appendices"),
                           selected = c("Methods", "Results", "Forest Plots")),
        actionButton(ns("btn_generate"), "Generate Report", class = "btn-success w-100")
      ),
      card(
        h5("Generated Reports"),
        DTOutput(ns("reports_table"))
      )
    )
  )
}

reporting_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    reports <- reactiveVal(data.frame(
      File = character(),
      Format = character(),
      Created = character(),
      stringsAsFactors = FALSE
    ))

    observeEvent(input$btn_generate, {

      withProgress(message = "Generating report...", {

        tryCatch({
          timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
          filename <- paste0("report_", timestamp)

          if (input$format == "word") {
            filepath <- generate_word_report(rv, input, filename)
          } else if (input$format == "pdf") {
            filepath <- generate_pdf_report(rv, input, filename)
          } else if (input$format == "pptx") {
            filepath <- generate_pptx_report(rv, input, filename)
          }

          # Add to reports list
          new_report <- data.frame(
            File = basename(filepath),
            Format = toupper(input$format),
            Created = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
            stringsAsFactors = FALSE
          )
          reports(rbind(reports(), new_report))

          showNotification(paste("✓ Report generated:", filepath), type = "message", duration = 10)

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    output$reports_table <- renderDT({
      datatable(reports(), options = list(pageLength = 10))
    })

    return(reactive(reports()))
  })
}

generate_word_report <- function(rv, input, filename) {
  doc <- read_docx()

  # Title page
  doc <- doc %>%
    body_add_par(input$report_title, style = "heading 1") %>%
    body_add_par(paste("Author:", input$author)) %>%
    body_add_par(paste("Date:", format(Sys.time(), "%Y-%m-%d"))) %>%
    body_add_break()

  # Methods
  if ("Methods" %in% input$sections) {
    doc <- doc %>%
      body_add_par("Methods", style = "heading 2") %>%
      body_add_par("Meta-analysis performed using random-effects model (REML).")
  }

  # Results
  if ("Results" %in% input$sections && !is.null(rv$pairwise_results)) {
    doc <- doc %>%
      body_add_par("Results", style = "heading 2")

    for (outcome in names(rv$pairwise_results)) {
      result <- rv$pairwise_results[[outcome]]
      doc <- doc %>%
        body_add_par(paste("Outcome:", outcome), style = "heading 3") %>%
        body_add_par(sprintf("Pooled effect: %.3f (95%% CI: %.3f to %.3f)",
                             result$pooled_effect, result$ci_lower, result$ci_upper))
    }
  }

  # Save
  filepath <- file.path("outputs", paste0(filename, ".docx"))
  print(doc, target = filepath)
  return(filepath)
}

generate_pdf_report <- function(rv, input, filename) {
  # Use rmarkdown to generate PDF
  filepath <- file.path("outputs", paste0(filename, ".pdf"))

  rmd_content <- sprintf('
---
title: "%s"
author: "%s"
date: "%s"
output: pdf_document
---

# Methods

Meta-analysis performed using random-effects model.

# Results

Results would be inserted here.
', input$report_title, input$author, format(Sys.time(), "%Y-%m-%d"))

  temp_rmd <- tempfile(fileext = ".Rmd")
  writeLines(rmd_content, temp_rmd)

  render(temp_rmd, output_file = filepath, quiet = TRUE)
  return(filepath)
}

generate_pptx_report <- function(rv, input, filename) {
  pres <- read_pptx()

  # Title slide
  pres <- pres %>%
    add_slide(layout = "Title Slide", master = "Office Theme") %>%
    ph_with(value = input$report_title, location = ph_location_type(type = "ctrTitle")) %>%
    ph_with(value = input$author, location = ph_location_type(type = "subTitle"))

  # Results slide
  pres <- pres %>%
    add_slide(layout = "Title and Content", master = "Office Theme") %>%
    ph_with(value = "Results", location = ph_location_type(type = "title"))

  filepath <- file.path("outputs", paste0(filename, ".pptx"))
  print(pres, target = filepath)
  return(filepath)
}
