# Reporting Module - Word/PDF/PPT Exports
library(shiny)
library(rmarkdown)
library(officer)

# Source plotting utilities for saving plots
source("utils/plotting.R", local = TRUE)

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
                             result$pooled_effect, result$ci_lower, result$ci_upper)) %>%
        body_add_par(sprintf("Heterogeneity: I² = %.1f%%, τ² = %.3f",
                             result$i_squared, result$tau_squared)) %>%
        body_add_par(sprintf("P-value: %.4f", result$p_value))
    }
  }

  # Forest Plots
  if ("Forest Plots" %in% input$sections && !is.null(rv$pairwise_results)) {
    doc <- doc %>%
      body_add_par("Forest Plots", style = "heading 2")

    for (outcome in names(rv$pairwise_results)) {
      result <- rv$pairwise_results[[outcome]]

      # Save forest plot as PNG
      plot_file <- tempfile(fileext = ".png")
      tryCatch({
        save_forest_plot(result, outcome, plot_file, width = 10, height = 8)

        # Embed the plot
        doc <- doc %>%
          body_add_par(paste("Figure: Forest plot for", outcome), style = "heading 3") %>%
          body_add_img(src = plot_file, width = 6.5, height = 5) %>%
          body_add_par(sprintf("Forest plot showing effect sizes and 95%% confidence intervals for %s. Box sizes are proportional to study weights (inverse variance).", outcome))

        # Clean up temp file
        unlink(plot_file)
      }, error = function(e) {
        message(sprintf("Could not embed forest plot for %s: %s", outcome, e$message))
      })
    }
  }

  # Heterogeneity
  if ("Heterogeneity" %in% input$sections && !is.null(rv$pairwise_results)) {
    doc <- doc %>%
      body_add_par("Heterogeneity Assessment", style = "heading 2")

    for (outcome in names(rv$pairwise_results)) {
      result <- rv$pairwise_results[[outcome]]
      doc <- doc %>%
        body_add_par(paste("Outcome:", outcome), style = "heading 3") %>%
        body_add_par(sprintf("I² statistic: %.1f%% (indicates %s heterogeneity)",
                             result$i_squared,
                             ifelse(result$i_squared < 25, "low",
                                    ifelse(result$i_squared < 50, "moderate", "high")))) %>%
        body_add_par(sprintf("τ² (between-study variance): %.3f", result$tau_squared)) %>%
        body_add_par(sprintf("Q statistic: %.2f (df = %d, p = %.4f)",
                             result$q_statistic, result$df, result$q_p_value))

      # Add funnel plot if available
      if (result$n_studies >= 10) {
        funnel_file <- tempfile(fileext = ".png")
        tryCatch({
          save_funnel_plot(result, outcome, funnel_file, width = 8, height = 8)

          doc <- doc %>%
            body_add_par("Figure: Funnel plot for publication bias assessment") %>%
            body_add_img(src = funnel_file, width = 5, height = 5)

          unlink(funnel_file)
        }, error = function(e) {
          message(sprintf("Could not embed funnel plot for %s: %s", outcome, e$message))
        })
      }
    }
  }

  # Economics
  if ("Economics" %in% input$sections && !is.null(rv$economic_results)) {
    doc <- doc %>%
      body_add_par("Health Economic Evaluation", style = "heading 2") %>%
      body_add_par(sprintf("Incremental Cost: £%.0f", rv$economic_results$incremental_cost)) %>%
      body_add_par(sprintf("Incremental QALYs: %.3f", rv$economic_results$incremental_qalys)) %>%
      body_add_par(sprintf("ICER: £%.0f per QALY", rv$economic_results$icer)) %>%
      body_add_par(sprintf("Probability cost-effective at £30,000/QALY: %.1f%%",
                           rv$economic_results$prob_cost_effective * 100))
  }

  # Save
  filepath <- file.path("outputs", paste0(filename, ".docx"))
  print(doc, target = filepath)
  return(filepath)
}

generate_pdf_report <- function(rv, input, filename) {
  # Use rmarkdown to generate PDF
  filepath <- file.path("outputs", paste0(filename, ".pdf"))

  # Build RMarkdown content dynamically
  rmd_lines <- c(
    "---",
    sprintf('title: "%s"', input$report_title),
    sprintf('author: "%s"', input$author),
    sprintf('date: "%s"', format(Sys.time(), "%Y-%m-%d")),
    "output: pdf_document",
    "---",
    ""
  )

  # Methods
  if ("Methods" %in% input$sections) {
    rmd_lines <- c(rmd_lines,
      "# Methods",
      "",
      "Meta-analysis performed using random-effects model (REML). Effect sizes were pooled using the DerSimonian-Laird estimator. Heterogeneity was assessed using I² and τ² statistics.",
      ""
    )
  }

  # Results
  if ("Results" %in% input$sections && !is.null(rv$pairwise_results)) {
    rmd_lines <- c(rmd_lines, "# Results", "")

    for (outcome in names(rv$pairwise_results)) {
      result <- rv$pairwise_results[[outcome]]
      rmd_lines <- c(rmd_lines,
        sprintf("## %s", outcome),
        "",
        sprintf("Pooled effect: %.3f (95%% CI: %.3f to %.3f)",
                result$pooled_effect, result$ci_lower, result$ci_upper),
        sprintf("Heterogeneity: I² = %.1f%%, τ² = %.3f",
                result$i_squared, result$tau_squared),
        sprintf("P-value: %.4f", result$p_value),
        ""
      )
    }
  }

  # Forest Plots
  if ("Forest Plots" %in% input$sections && !is.null(rv$pairwise_results)) {
    rmd_lines <- c(rmd_lines, "# Forest Plots", "")

    for (outcome in names(rv$pairwise_results)) {
      result <- rv$pairwise_results[[outcome]]
      plot_file <- tempfile(fileext = ".png")

      tryCatch({
        save_forest_plot(result, outcome, plot_file, width = 10, height = 8)
        rmd_lines <- c(rmd_lines,
          sprintf("## %s", outcome),
          "",
          sprintf("![](%s)", plot_file),
          "",
          sprintf("Forest plot showing effect sizes for %s. Box sizes are proportional to study weights.", outcome),
          ""
        )
      }, error = function(e) {
        message(sprintf("Could not save forest plot for %s: %s", outcome, e$message))
      })
    }
  }

  # Economics
  if ("Economics" %in% input$sections && !is.null(rv$economic_results)) {
    rmd_lines <- c(rmd_lines,
      "# Health Economic Evaluation",
      "",
      sprintf("Incremental Cost: £%.0f", rv$economic_results$incremental_cost),
      sprintf("Incremental QALYs: %.3f", rv$economic_results$incremental_qalys),
      sprintf("ICER: £%.0f per QALY", rv$economic_results$icer),
      ""
    )
  }

  temp_rmd <- tempfile(fileext = ".Rmd")
  writeLines(rmd_lines, temp_rmd)

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

  # Methods slide
  if ("Methods" %in% input$sections) {
    pres <- pres %>%
      add_slide(layout = "Title and Content", master = "Office Theme") %>%
      ph_with(value = "Methods", location = ph_location_type(type = "title")) %>%
      ph_with(value = "Meta-analysis performed using random-effects model (REML).\n\nEffect sizes pooled using DerSimonian-Laird estimator.\n\nHeterogeneity assessed using I² and τ² statistics.",
              location = ph_location_type(type = "body"))
  }

  # Results slides
  if ("Results" %in% input$sections && !is.null(rv$pairwise_results)) {
    for (outcome in names(rv$pairwise_results)) {
      result <- rv$pairwise_results[[outcome]]

      results_text <- sprintf(
        "Pooled effect: %.3f (95%% CI: %.3f to %.3f)\n\nHeterogeneity: I² = %.1f%%, τ² = %.3f\n\nP-value: %.4f\n\nNumber of studies: %d",
        result$pooled_effect, result$ci_lower, result$ci_upper,
        result$i_squared, result$tau_squared,
        result$p_value,
        result$n_studies
      )

      pres <- pres %>%
        add_slide(layout = "Title and Content", master = "Office Theme") %>%
        ph_with(value = paste("Results:", outcome), location = ph_location_type(type = "title")) %>%
        ph_with(value = results_text, location = ph_location_type(type = "body"))
    }
  }

  # Forest plot slides
  if ("Forest Plots" %in% input$sections && !is.null(rv$pairwise_results)) {
    for (outcome in names(rv$pairwise_results)) {
      result <- rv$pairwise_results[[outcome]]
      plot_file <- tempfile(fileext = ".png")

      tryCatch({
        save_forest_plot(result, outcome, plot_file, width = 10, height = 8)

        pres <- pres %>%
          add_slide(layout = "Title and Content", master = "Office Theme") %>%
          ph_with(value = paste("Forest Plot:", outcome), location = ph_location_type(type = "title")) %>%
          ph_with(value = external_img(plot_file),
                  location = ph_location(left = 1, top = 1.5, width = 8, height = 5),
                  use_loc_size = TRUE)

        unlink(plot_file)
      }, error = function(e) {
        message(sprintf("Could not embed forest plot for %s: %s", outcome, e$message))
      })
    }
  }

  # Economics slide
  if ("Economics" %in% input$sections && !is.null(rv$economic_results)) {
    econ_text <- sprintf(
      "Incremental Cost: £%.0f\n\nIncremental QALYs: %.3f\n\nICER: £%.0f per QALY\n\nProbability cost-effective at £30,000/QALY: %.1f%%",
      rv$economic_results$incremental_cost,
      rv$economic_results$incremental_qalys,
      rv$economic_results$icer,
      rv$economic_results$prob_cost_effective * 100
    )

    pres <- pres %>%
      add_slide(layout = "Title and Content", master = "Office Theme") %>%
      ph_with(value = "Health Economic Evaluation", location = ph_location_type(type = "title")) %>%
      ph_with(value = econ_text, location = ph_location_type(type = "body"))
  }

  filepath <- file.path("outputs", paste0(filename, ".pptx"))
  print(pres, target = filepath)
  return(filepath)
}
