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
        card_header("Report Settings"),
        navset_card_pill(
          nav_panel(
            title = "Content",
            textInput(ns("report_title"), "Report Title", "Meta-Analysis Report"),
            textInput(ns("author"), "Author", Sys.getenv("USER")),
            selectInput(ns("format"), "Format",
                        choices = c("Word" = "word", "PDF" = "pdf", "PowerPoint" = "pptx")),
            checkboxGroupInput(ns("sections"), "Include Sections",
                               choices = c("Protocol", "Methods", "Results", "Forest Plots",
                                           "Heterogeneity", "Economics", "Methods Appendix", "Appendices"),
                               selected = c("Methods", "Results", "Forest Plots"))
          ),
          nav_panel(
            title = "Branding",
            icon = icon("palette"),
            fileInput(ns("brand_logo"), "Upload Logo (PNG/JPG)",
                      accept = c("image/png", "image/jpeg", "image/jpg")),
            textInput(ns("brand_company"), "Company/Organization Name",
                      placeholder = "e.g., Your Consultancy Ltd"),
            textInput(ns("brand_subtitle"), "Report Subtitle",
                      placeholder = "e.g., Health Technology Assessment"),
            selectInput(ns("brand_color_scheme"), "Color Scheme",
                        choices = c("Professional Blue" = "blue",
                                    "Corporate Green" = "green",
                                    "Clinical Purple" = "purple",
                                    "NICE Orange" = "orange",
                                    "Custom" = "custom")),
            conditionalPanel(
              condition = "input.brand_color_scheme == 'custom'",
              ns = ns,
              textInput(ns("brand_primary_color"), "Primary Color (Hex)", value = "#0066CC",
                        placeholder = "#0066CC"),
              textInput(ns("brand_secondary_color"), "Secondary Color (Hex)", value = "#003366",
                        placeholder = "#003366")
            ),
            textInput(ns("brand_footer_text"), "Footer Text",
                      value = "Confidential - For review purposes only",
                      placeholder = "e.g., Confidential"),
            actionButton(ns("btn_preview_branding"), "Preview Branding",
                         class = "btn-outline-primary w-100 mt-2")
          )
        ),
        hr(),
        actionButton(ns("btn_generate"), "Generate Report", class = "btn-success w-100",
                     icon = icon("file-export"))
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

    # Reactive branding settings
    branding <- reactive({
      get_branding_settings(input)
    })

    # Preview branding
    observeEvent(input$btn_preview_branding, {
      brand <- branding()

      preview_text <- sprintf(
        "Company: %s\nColor Scheme: %s\nPrimary Color: %s\nSecondary Color: %s\nFooter: %s",
        ifelse(brand$company == "", "Not set", brand$company),
        brand$color_scheme,
        brand$primary_color,
        brand$secondary_color,
        brand$footer_text
      )

      showModal(modalDialog(
        title = "Branding Preview",
        div(
          style = sprintf("background-color: %s; color: white; padding: 20px; border-radius: 5px;",
                          brand$primary_color),
          h4(ifelse(brand$company != "", brand$company, "Your Company Name")),
          p(ifelse(brand$subtitle != "", brand$subtitle, "Report Subtitle"))
        ),
        hr(),
        pre(preview_text),
        footer = modalButton("Close")
      ))
    })

    observeEvent(input$btn_generate, {

      withProgress(message = "Generating report...", {

        tryCatch({
          timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
          filename <- paste0("report_", timestamp)

          # Get branding
          brand <- branding()

          if (input$format == "word") {
            filepath <- generate_word_report(rv, input, filename, brand)
          } else if (input$format == "pdf") {
            filepath <- generate_pdf_report(rv, input, filename, brand)
          } else if (input$format == "pptx") {
            filepath <- generate_pptx_report(rv, input, filename, brand)
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

generate_word_report <- function(rv, input, filename, brand = NULL) {
  doc <- read_docx()

  # Branded Title page
  if (!is.null(brand)) {
    # Add logo if provided
    if (!is.null(brand$logo_path) && file.exists(brand$logo_path)) {
      doc <- doc %>%
        body_add_img(src = brand$logo_path, width = 2, height = 1) %>%
        body_add_break()
    }

    # Company name
    if (brand$company != "") {
      doc <- doc %>%
        body_add_par(brand$company, style = "heading 1")
    }

    # Report title
    doc <- doc %>%
      body_add_par(input$report_title, style = "heading 2")

    # Subtitle
    if (brand$subtitle != "") {
      doc <- doc %>%
        body_add_par(brand$subtitle, style = "heading 3")
    }

    # Metadata
    doc <- doc %>%
      body_add_par(paste("Author:", input$author)) %>%
      body_add_par(paste("Date:", format(Sys.time(), "%Y-%m-%d")))

    # Footer text
    if (brand$footer_text != "") {
      doc <- doc %>%
        body_add_break() %>%
        body_add_par(brand$footer_text, style = "Normal") %>%
        slip_in_text(brand$footer_text, style = "centered", pos = "before")
    }

    doc <- doc %>% body_add_break()

  } else {
    # Default title page
    doc <- doc %>%
      body_add_par(input$report_title, style = "heading 1") %>%
      body_add_par(paste("Author:", input$author)) %>%
      body_add_par(paste("Date:", format(Sys.time(), "%Y-%m-%d"))) %>%
      body_add_break()
  }

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

  # Methods Appendix
  if ("Methods Appendix" %in% input$sections) {
    doc <- add_methods_appendix(doc, rv)
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

generate_pdf_report <- function(rv, input, filename, brand = NULL) {
  # Use rmarkdown to generate PDF
  filepath <- file.path("outputs", paste0(filename, ".pdf"))

  # Build RMarkdown content dynamically with branding
  if (!is.null(brand) && brand$company != "") {
    title_text <- paste0(brand$company, ": ", input$report_title)
    subtitle_text <- brand$subtitle
  } else {
    title_text <- input$report_title
    subtitle_text <- ""
  }

  rmd_lines <- c(
    "---",
    sprintf('title: "%s"', title_text),
    ifelse(subtitle_text != "", sprintf('subtitle: "%s"', subtitle_text), ""),
    sprintf('author: "%s"', input$author),
    sprintf('date: "%s"', format(Sys.time(), "%Y-%m-%d")),
    "output: pdf_document",
    "---",
    ""
  )

  # Remove empty lines
  rmd_lines <- rmd_lines[rmd_lines != ""]

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

generate_pptx_report <- function(rv, input, filename, brand = NULL) {
  pres <- read_pptx()

  # Branded Title slide
  if (!is.null(brand)) {
    title_text <- ifelse(brand$company != "",
                         paste0(brand$company, "\n", input$report_title),
                         input$report_title)
    subtitle_text <- ifelse(brand$subtitle != "",
                            paste0(brand$subtitle, "\n", input$author),
                            input$author)
  } else {
    title_text <- input$report_title
    subtitle_text <- input$author
  }

  pres <- pres %>%
    add_slide(layout = "Title Slide", master = "Office Theme") %>%
    ph_with(value = title_text, location = ph_location_type(type = "ctrTitle")) %>%
    ph_with(value = subtitle_text, location = ph_location_type(type = "subTitle"))

  # Add logo to title slide if provided
  if (!is.null(brand) && !is.null(brand$logo_path) && file.exists(brand$logo_path)) {
    pres <- pres %>%
      ph_with(value = external_img(brand$logo_path),
              location = ph_location(left = 8, top = 0.5, width = 1.5, height = 0.75),
              use_loc_size = TRUE)
  }

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

# ============================================================================
# METHODS APPENDIX GENERATOR
# Auto-generates comprehensive methods appendix for HTA submissions
# ============================================================================

add_methods_appendix <- function(doc, rv) {
  doc <- doc %>%
    body_add_break() %>%
    body_add_par("APPENDIX A: DETAILED METHODS", style = "heading 1") %>%
    body_add_par("This appendix provides detailed methodology for the systematic review and meta-analysis, formatted for HTA submission requirements.")

  # BUG FIX #6: Check if any data exists before attempting to generate appendix
  if (is.null(rv$protocol) && is.null(rv$pairwise_results) &&
      is.null(rv$nma_results) && is.null(rv$he_results)) {
    doc <- doc %>%
      body_add_par("No analysis data available. Please run analyses before generating the methods appendix.",
                   style = "Normal")
    return(doc)
  }

  # 1. Search Strategy
  doc <- doc %>%
    body_add_par("A.1 Search Strategy", style = "heading 2")

  if (!is.null(rv$protocol)) {
    doc <- doc %>%
      body_add_par("A.1.1 Protocol Details", style = "heading 3") %>%
      body_add_par(sprintf("Protocol Title: %s", rv$protocol$title)) %>%
      body_add_par(sprintf("Protocol Version: %s", rv$protocol$version)) %>%
      body_add_par(sprintf("Protocol Date: %s", format(rv$protocol$created_at, "%Y-%m-%d"))) %>%
      body_add_par(sprintf("Protocol Status: %s",
                           ifelse(is.null(rv$protocol$locked) || !rv$protocol$locked,
                                  "Unlocked (modifications allowed)",
                                  paste0("Locked on ", format(rv$protocol$locked_at, "%Y-%m-%d")))))

    # Deviations
    if (!is.null(rv$protocol$deviations) && nrow(rv$protocol$deviations) > 0) {
      doc <- doc %>%
        body_add_par("A.1.2 Protocol Deviations", style = "heading 3") %>%
        body_add_par(sprintf("Number of deviations logged: %d", nrow(rv$protocol$deviations)))

      for (i in seq_len(nrow(rv$protocol$deviations))) {
        dev <- rv$protocol$deviations[i, ]
        doc <- doc %>%
          body_add_par(sprintf("Deviation %d (%s):", i, dev$Date), style = "heading 4") %>%
          body_add_par(sprintf("Description: %s", dev$Description)) %>%
          body_add_par(sprintf("Justification: %s", dev$Justification))
      }
    } else {
      doc <- doc %>%
        body_add_par("A.1.2 Protocol Deviations", style = "heading 3") %>%
        body_add_par("No deviations from the registered protocol were made during conduct of this review.")
    }
  } else {
    doc <- doc %>%
      body_add_par("No protocol information available.")
  }

  # 2. Eligibility Criteria
  doc <- doc %>%
    body_add_par("A.2 Eligibility Criteria (PICO)", style = "heading 2")

  if (!is.null(rv$protocol)) {
    doc <- doc %>%
      body_add_par("A.2.1 Population", style = "heading 3") %>%
      body_add_par(rv$protocol$population) %>%
      body_add_par("A.2.2 Intervention", style = "heading 3") %>%
      body_add_par(rv$protocol$intervention) %>%
      body_add_par("A.2.3 Comparator", style = "heading 3") %>%
      body_add_par(rv$protocol$comparator) %>%
      body_add_par("A.2.4 Outcomes", style = "heading 3") %>%
      body_add_par(paste(rv$protocol$outcomes, collapse = ", "))

    doc <- doc %>%
      body_add_par("A.2.5 Inclusion Criteria", style = "heading 3")

    for (criterion in rv$protocol$inclusion_criteria) {
      if (nchar(trimws(criterion)) > 0) {
        doc <- doc %>% body_add_par(paste("•", criterion))
      }
    }

    doc <- doc %>%
      body_add_par("A.2.6 Exclusion Criteria", style = "heading 3")

    for (criterion in rv$protocol$exclusion_criteria) {
      if (nchar(trimws(criterion)) > 0) {
        doc <- doc %>% body_add_par(paste("•", criterion))
      }
    }
  }

  # 3. Study Selection
  doc <- doc %>%
    body_add_par("A.3 Study Selection Process", style = "heading 2")

  if (!is.null(rv$data)) {
    n_studies <- length(unique(rv$data$study_id))
    n_arms <- nrow(rv$data)

    doc <- doc %>%
      body_add_par(sprintf("A total of %d unique studies were included, contributing %d treatment arms.",
                           n_studies, n_arms)) %>%
      body_add_par("Study selection was performed according to PRISMA 2020 guidelines:") %>%
      body_add_par("• Records identified through database searches were de-duplicated") %>%
      body_add_par("• Titles and abstracts were screened independently by two reviewers") %>%
      body_add_par("• Full-text articles were assessed for eligibility") %>%
      body_add_par("• Disagreements were resolved by consensus or third-party adjudication")
  } else {
    doc <- doc %>%
      body_add_par("No study data available.")
  }

  # 4. Data Extraction
  doc <- doc %>%
    body_add_par("A.4 Data Extraction", style = "heading 2") %>%
    body_add_par("Data were extracted using a standardized form. Extracted items included:") %>%
    body_add_par("• Study characteristics: author, year, country, design, sample size") %>%
    body_add_par("• Population characteristics: demographics, disease severity, baseline risk") %>%
    body_add_par("• Intervention details: dose, duration, mode of administration") %>%
    body_add_par("• Outcome data: events, sample sizes, means, standard deviations, hazard ratios") %>%
    body_add_par("• Quality/risk of bias indicators") %>%
    body_add_par("Data extraction was performed independently by two reviewers with cross-checking for accuracy.")

  # 5. Statistical Methods
  doc <- doc %>%
    body_add_par("A.5 Statistical Analysis Methods", style = "heading 2")

  # Pairwise MA methods
  if (!is.null(rv$pairwise_results) && length(rv$pairwise_results) > 0) {
    doc <- doc %>%
      body_add_par("A.5.1 Pairwise Meta-Analysis", style = "heading 3") %>%
      body_add_par("Effect Size Calculation:", style = "heading 4")

    first_result <- rv$pairwise_results[[1]]
    if (!is.null(first_result$measure)) {
      doc <- doc %>%
        body_add_par(sprintf("Effect measure: %s", first_result$measure))
    } else {
      doc <- doc %>%
        body_add_par("Effect measure: Standardized Mean Difference or Risk Ratio (as appropriate)")
    }

    doc <- doc %>%
      body_add_par("Pooling Method:", style = "heading 4") %>%
      body_add_par("Random-effects meta-analysis using the Restricted Maximum Likelihood (REML) estimator was performed. The REML method is preferred over DerSimonian-Laird as it does not underestimate between-study variance.") %>%
      body_add_par("The pooled effect size was calculated as a weighted average of individual study effects, with weights equal to the inverse of the within-study plus between-study variance:") %>%
      body_add_par("Weight_i = 1 / (v_i + τ²)") %>%
      body_add_par("Where v_i is the within-study variance and τ² is the between-study variance (tau-squared).")

    doc <- doc %>%
      body_add_par("Heterogeneity Assessment:", style = "heading 4") %>%
      body_add_par("Between-study heterogeneity was quantified using:") %>%
      body_add_par("• I² statistic: Percentage of total variation due to heterogeneity rather than chance") %>%
      body_add_par("  - I² < 25%: Low heterogeneity") %>%
      body_add_par("  - I² 25-50%: Moderate heterogeneity") %>%
      body_add_par("  - I² 50-75%: Substantial heterogeneity") %>%
      body_add_par("  - I² > 75%: Considerable heterogeneity") %>%
      body_add_par("• τ² (tau-squared): Absolute between-study variance") %>%
      body_add_par("• Cochran's Q test: Statistical test of heterogeneity (p < 0.10 indicates significant heterogeneity)")

    doc <- doc %>%
      body_add_par("Publication Bias:", style = "heading 4") %>%
      body_add_par("Publication bias was assessed using:") %>%
      body_add_par("• Funnel plots (visual inspection for asymmetry)") %>%
      body_add_par("• Egger's regression test (when ≥10 studies available)") %>%
      body_add_par("• Trim-and-fill method for sensitivity analysis")
  }

  # NMA methods
  if (!is.null(rv$nma_results) && length(rv$nma_results) > 0) {
    doc <- doc %>%
      body_add_par("A.5.2 Network Meta-Analysis", style = "heading 3") %>%
      body_add_par("Network meta-analysis was conducted using frequentist methods with a graph-theoretical approach (netmeta R package). The NMA synthesizes both direct and indirect evidence to compare multiple treatments simultaneously.") %>%
      body_add_par("Assumptions:", style = "heading 4") %>%
      body_add_par("• Homogeneity: Treatment effects are assumed consistent across studies") %>%
      body_add_par("• Similarity: Studies are sufficiently similar to be pooled") %>%
      body_add_par("• Transitivity: Characteristics that modify relative treatment effects are balanced across comparisons") %>%
      body_add_par("• Consistency: Direct and indirect evidence agree") %>%
      body_add_par("Network Geometry:", style = "heading 4") %>%
      body_add_par("The network geometry was assessed using network plots showing all pairwise comparisons. Nodes represent treatments, edges represent direct comparisons, and edge thickness is proportional to the number of studies.")
  }

  # Dose-response methods
  if (!is.null(rv$dr_results) && length(rv$dr_results) > 0) {
    doc <- doc %>%
      body_add_par("A.5.3 Dose-Response Meta-Analysis", style = "heading 3") %>%
      body_add_par("Dose-response relationships were modeled using restricted cubic splines with 3 knots placed at the 10th, 50th, and 90th percentiles of the dose distribution. This flexible approach allows for non-linear dose-response curves while avoiding overfitting.")
  }

  # 6. Health Economic Methods
  doc <- doc %>%
    body_add_par("A.6 Health Economic Evaluation Methods", style = "heading 2")

  if (!is.null(rv$he_results)) {
    doc <- doc %>%
      body_add_par("A.6.1 Model Structure", style = "heading 3") %>%
      body_add_par("A 3-state Markov cohort model was constructed with health states:") %>%
      body_add_par("• Stable disease (no progression)") %>%
      body_add_par("• Progressed disease") %>%
      body_add_par("• Death (absorbing state)") %>%
      body_add_par("The model used a cycle length of 1 month and a time horizon consistent with HTA guidelines.") %>%
      body_add_par("A.6.2 Model Parameters", style = "heading 3") %>%
      body_add_par("Transition Probabilities:", style = "heading 4") %>%
      body_add_par("Transition probabilities were derived from:") %>%
      body_add_par("• Progression risk: Meta-analysis pooled estimates") %>%
      body_add_par("• Mortality risk: Published literature and life tables") %>%
      body_add_par("Costs:", style = "heading 4") %>%
      body_add_par("All costs are presented in GBP (£) and inflated to current year prices using the NHS Cost Inflation Index. Resource use was multiplied by unit costs from NHS Reference Costs.") %>%
      body_add_par("Utilities:", style = "heading 4") %>%
      body_add_par("Health state utility values (HSUVs) were obtained from published EQ-5D-5L studies. Utilities were applied to each health state to calculate quality-adjusted life years (QALYs).") %>%
      body_add_par("A.6.3 Discounting", style = "heading 3") %>%
      body_add_par("Future costs and QALYs were discounted at 3.5% per annum in the base case, in line with NICE guidelines. Alternative discount rates (0%, 1.5%) were explored in scenario analysis.") %>%
      body_add_par("A.6.4 Probabilistic Sensitivity Analysis", style = "heading 3") %>%
      body_add_par("Probabilistic sensitivity analysis (PSA) was performed using Monte Carlo simulation with 10,000 iterations. Parameter distributions:") %>%
      body_add_par("• Transition probabilities: Beta distributions") %>%
      body_add_par("• Costs: Gamma distributions") %>%
      body_add_par("• Utilities: Beta distributions") %>%
      body_add_par("• Relative treatment effects: Normal distributions") %>%
      body_add_par("PSA results were presented as cost-effectiveness acceptability curves (CEAC) showing the probability of cost-effectiveness across different willingness-to-pay thresholds.")
  } else {
    doc <- doc %>%
      body_add_par("No health economic model was constructed for this analysis.")
  }

  # 7. Software
  doc <- doc %>%
    body_add_par("A.7 Statistical Software", style = "heading 2") %>%
    body_add_par(sprintf("All analyses were conducted using R version %s.%s (%s).",
                         R.version$major, R.version$minor, R.version$version.string)) %>%
    body_add_par("Key R packages used:") %>%
    body_add_par("• metafor: Meta-analysis using mixed-effects models (Wolfgang Viechtbauer)") %>%
    body_add_par("• netmeta: Network meta-analysis (Gerta Rücker, Guido Schwarzer)") %>%
    body_add_par("• dosresmeta: Dose-response meta-analysis (Alessio Crippa, Nicola Orsini)") %>%
    body_add_par("• BCEA: Bayesian cost-effectiveness analysis (Gianluca Baio)") %>%
    body_add_par("• ggplot2: Data visualization (Hadley Wickham)") %>%
    body_add_par("• officer: Microsoft Word document generation (David Gohel)")

  # 8. Quality Assessment
  doc <- doc %>%
    body_add_par("A.8 Risk of Bias Assessment", style = "heading 2") %>%
    body_add_par("Risk of bias was assessed using the Cochrane Risk of Bias 2.0 tool for randomized controlled trials. Each study was evaluated across five domains:") %>%
    body_add_par("• Bias arising from the randomization process") %>%
    body_add_par("• Bias due to deviations from intended interventions") %>%
    body_add_par("• Bias due to missing outcome data") %>%
    body_add_par("• Bias in measurement of the outcome") %>%
    body_add_par("• Bias in selection of the reported result") %>%
    body_add_par("Overall risk of bias was categorized as Low, Some Concerns, or High.") %>%
    body_add_par("Sensitivity analyses excluded studies at high risk of bias to assess the robustness of findings.")

  # 9. Reporting Standards
  doc <- doc %>%
    body_add_par("A.9 Reporting Standards", style = "heading 2") %>%
    body_add_par("This systematic review and meta-analysis was conducted and reported according to:") %>%
    body_add_par("• PRISMA 2020 (Preferred Reporting Items for Systematic Reviews and Meta-Analyses)") %>%
    body_add_par("• Cochrane Handbook for Systematic Reviews of Interventions (version 6.3)") %>%
    body_add_par("• NICE Guide to the Methods of Technology Appraisal (2013)") %>%
    body_add_par("• ISPOR guidelines for cost-effectiveness analysis")

  if (!is.null(rv$protocol$prisma_checklist)) {
    prisma_complete <- sum(rv$protocol$prisma_checklist$Status == "Complete")
    prisma_total <- nrow(rv$protocol$prisma_checklist)
    prisma_pct <- round(100 * prisma_complete / prisma_total)

    doc <- doc %>%
      body_add_par(sprintf("PRISMA 2020 Checklist Compliance: %d/%d items complete (%d%%)",
                           prisma_complete, prisma_total, prisma_pct))
  }

  # 10. Data Availability
  doc <- doc %>%
    body_add_par("A.10 Data Availability", style = "heading 2") %>%
    body_add_par("All data extracted from included studies are available in the supplementary materials. Analysis code (R scripts) is available upon reasonable request to ensure reproducibility.")

  return(doc)
}

# ============================================================================
# BRANDING HELPER FUNCTIONS
# ============================================================================

get_branding_settings <- function(input) {
  # Define color scheme presets
  color_schemes <- list(
    blue = list(primary = "#0066CC", secondary = "#003366"),
    green = list(primary = "#2E7D32", secondary = "#1B5E20"),
    purple = list(primary = "#7B1FA2", secondary = "#4A148C"),
    orange = list(primary = "#F57C00", secondary = "#E65100"),
    custom = list(
      primary = ifelse(!is.null(input$brand_primary_color),
                       input$brand_primary_color, "#0066CC"),
      secondary = ifelse(!is.null(input$brand_secondary_color),
                         input$brand_secondary_color, "#003366")
    )
  )

  # Get selected color scheme
  scheme <- input$brand_color_scheme
  if (is.null(scheme)) scheme <- "blue"

  colors <- color_schemes[[scheme]]

  # Process logo upload
  logo_path <- NULL
  if (!is.null(input$brand_logo)) {
    logo_info <- input$brand_logo
    if (!is.null(logo_info$datapath) && file.exists(logo_info$datapath)) {
      # BUG FIX #3: Add unique user prefix to prevent collision
      logo_ext <- tools::file_ext(logo_info$name)
      user_prefix <- gsub("[^[:alnum:]]", "_", Sys.getenv("USER"))  # Sanitize username
      unique_id <- format(Sys.time(), "%Y%m%d_%H%M%S_%OS3")  # Add milliseconds
      logo_filename <- paste0("logo_", user_prefix, "_", unique_id, ".", logo_ext)
      logo_path <- file.path("outputs", logo_filename)

      # Create outputs directory if it doesn't exist
      if (!dir.exists("outputs")) {
        dir.create("outputs", recursive = TRUE)
      }

      file.copy(logo_info$datapath, logo_path, overwrite = FALSE)  # Don't overwrite
    }
  }

  # Return branding settings list
  list(
    company = ifelse(!is.null(input$brand_company), input$brand_company, ""),
    subtitle = ifelse(!is.null(input$brand_subtitle), input$brand_subtitle, ""),
    color_scheme = scheme,
    primary_color = colors$primary,
    secondary_color = colors$secondary,
    footer_text = ifelse(!is.null(input$brand_footer_text),
                         input$brand_footer_text,
                         "Confidential - For review purposes only"),
    logo_path = logo_path
  )
}
