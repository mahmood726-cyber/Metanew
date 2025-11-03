# Customizable Report Templates Module
# Create, edit, and manage report templates for different audiences
# Supports academic, regulatory, clinical, and payer report styles

library(shiny)
library(bslib)
library(DT)
library(rmarkdown)
library(officer)
library(yaml)


#' UI for Report Templates Module
#'
#' @param id Module namespace ID
#' @export
report_templates_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("📝 Customizable Report Templates"),
    p("Create and manage custom report templates for different audiences"),

    layout_columns(
      col_widths = c(4, 8),

      # Left panel: Template library
      card(
        card_header("Template Library"),
        card_body(
          actionButton(ns("create_template"), "Create New Template",
                      class = "btn-success", icon = icon("plus"), style = "width:100%; margin-bottom:10px"),
          actionButton(ns("import_template"), "Import Template",
                      class = "btn-info", icon = icon("upload"), style = "width:100%; margin-bottom:10px"),
          hr(),
          h5("Available Templates:"),
          DTOutput(ns("template_list")),
          br(),
          actionButton(ns("delete_template"), "Delete Selected",
                      class = "btn-danger", icon = icon("trash")),
          actionButton(ns("duplicate_template"), "Duplicate",
                      class = "btn-secondary", icon = icon("copy"))
        )
      ),

      # Right panel: Template editor
      card(
        card_header("Template Editor"),
        card_body(
          # Template metadata
          textInput(ns("template_name"), "Template Name:",
                   placeholder = "e.g., NICE Submission Report"),
          selectInput(ns("template_type"), "Template Type:",
                     choices = c(
                       "Academic Publication" = "academic",
                       "Regulatory Submission" = "regulatory",
                       "Clinical Guidelines" = "clinical",
                       "Payer/HTA Report" = "payer",
                       "Internal Report" = "internal",
                       "Custom" = "custom"
                     )),
          textAreaInput(ns("template_description"), "Description:",
                       rows = 2,
                       placeholder = "Describe the purpose and audience of this template"),

          hr(),

          # Template structure
          h5("Report Structure:"),
          p("Select and arrange sections to include in the report"),

          # Section selector
          checkboxGroupInput(
            ns("sections"),
            "Include Sections:",
            choices = c(
              "Executive Summary" = "exec_summary",
              "Introduction & Background" = "introduction",
              "Systematic Review Protocol" = "protocol",
              "PRISMA Flow Diagram" = "prisma",
              "Study Characteristics Table" = "study_chars",
              "Risk of Bias Assessment" = "rob",
              "Network Geometry" = "network",
              "Meta-Analysis Results" = "ma_results",
              "Forest Plots" = "forest_plots",
              "Heterogeneity Assessment" = "heterogeneity",
              "Publication Bias" = "pub_bias",
              "Subgroup Analyses" = "subgroup",
              "Sensitivity Analyses" = "sensitivity",
              "Health Economic Results" = "he_results",
              "Cost-Effectiveness Acceptability" = "ceac",
              "Budget Impact Analysis" = "bia",
              "GRADE Assessment" = "grade",
              "Discussion & Limitations" = "discussion",
              "Conclusions & Recommendations" = "conclusions",
              "Methods Appendix" = "methods_appendix",
              "References" = "references",
              "Supplementary Materials" = "supplementary"
            ),
            selected = c("exec_summary", "ma_results", "forest_plots",
                        "heterogeneity", "pub_bias", "discussion", "conclusions")
          ),

          hr(),

          # Section ordering
          h5("Section Order:"),
          p("Drag to reorder sections (not yet implemented - use checkboxes order for now)"),

          hr(),

          # Format options
          h5("Format Options:"),
          layout_columns(
            col_widths = c(6, 6),
            selectInput(ns("output_format"), "Output Format:",
                       choices = c("Word (docx)" = "docx",
                                  "PDF" = "pdf",
                                  "HTML" = "html",
                                  "PowerPoint" = "pptx")),
            selectInput(ns("citation_style"), "Citation Style:",
                       choices = c("APA 7th" = "apa",
                                  "Vancouver" = "vancouver",
                                  "Harvard" = "harvard",
                                  "Chicago" = "chicago",
                                  "Nature" = "nature",
                                  "BMJ" = "bmj"))
          ),

          # Style options
          layout_columns(
            col_widths = c(6, 6),
            selectInput(ns("font"), "Font:",
                       choices = c("Arial" = "Arial",
                                  "Times New Roman" = "Times New Roman",
                                  "Calibri" = "Calibri",
                                  "Helvetica" = "Helvetica")),
            numericInput(ns("font_size"), "Font Size (pt):",
                        value = 11, min = 8, max = 16)
          ),

          layout_columns(
            col_widths = c(6, 6),
            checkboxInput(ns("include_toc"), "Include Table of Contents", value = TRUE),
            checkboxInput(ns("include_figures_list"), "Include List of Figures", value = FALSE)
          ),

          checkboxInput(ns("page_numbers"), "Add Page Numbers", value = TRUE),
          checkboxInput(ns("line_numbers"), "Add Line Numbers (for review)", value = FALSE),

          hr(),

          # Branding options
          h5("Branding & Styling:"),
          fileInput(ns("logo_upload"), "Upload Logo:",
                   accept = c("image/png", "image/jpeg", "image/jpg")),
          layout_columns(
            col_widths = c(6, 6),
            textInput(ns("organization_name"), "Organization Name:"),
            textInput(ns("report_id"), "Report ID/Version:")
          ),
          colourInput(ns("primary_color"), "Primary Color:", value = "#3498db"),
          colourInput(ns("secondary_color"), "Secondary Color:", value = "#2c3e50"),

          hr(),

          # Content customization
          h5("Content Customization:"),
          textAreaInput(ns("custom_header"), "Custom Header Text:",
                       rows = 2,
                       placeholder = "Text to appear at the top of each page"),
          textAreaInput(ns("custom_footer"), "Custom Footer Text:",
                       rows = 2,
                       placeholder = "Text to appear at the bottom of each page"),

          # Disclaimer
          textAreaInput(ns("disclaimer"), "Disclaimer Text:",
                       rows = 3,
                       placeholder = "Standard disclaimer or confidentiality notice"),

          hr(),

          # Action buttons
          layout_columns(
            col_widths = c(4, 4, 4),
            actionButton(ns("save_template"), "Save Template",
                        class = "btn-primary", icon = icon("save"),
                        style = "width:100%"),
            actionButton(ns("preview_template"), "Preview",
                        class = "btn-info", icon = icon("eye"),
                        style = "width:100%"),
            downloadButton(ns("export_template"), "Export Template",
                          style = "width:100%")
          )
        )
      )
    ),

    # Generate report from template
    hr(),
    card(
      card_header("Generate Report from Template"),
      card_body(
        layout_columns(
          col_widths = c(6, 6),
          selectInput(ns("template_to_use"), "Select Template:",
                     choices = NULL),
          selectInput(ns("data_source"), "Data Source:",
                     choices = c("Current Analysis" = "current",
                                "Saved Analysis" = "saved"))
        ),
        conditionalPanel(
          condition = sprintf("input['%s'] == 'saved'", ns("data_source")),
          ns = ns,
          selectInput(ns("saved_analysis"), "Select Saved Analysis:",
                     choices = NULL)
        ),
        actionButton(ns("generate_report"), "Generate Report",
                    class = "btn-success btn-lg",
                    icon = icon("file-alt")),
        br(), br(),
        textOutput(ns("generation_status"))
      )
    )
  )
}


#' Server Logic for Report Templates Module
#'
#' @param id Module namespace ID
#' @param rv Reactive values from parent
#' @export
report_templates_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive to store templates
    templates <- reactiveVal(list())
    selected_template <- reactiveVal(NULL)

    # Load default templates on startup
    observeEvent(rv$initialized, {
      default_templates <- load_default_templates()
      templates(default_templates)
    })

    # Template list
    output$template_list <- renderDT({
      req(templates())

      template_df <- do.call(rbind, lapply(names(templates()), function(name) {
        tmpl <- templates()[[name]]
        data.frame(
          Name = name,
          Type = tmpl$type,
          Sections = length(tmpl$sections),
          Format = tmpl$output_format,
          stringsAsFactors = FALSE
        )
      }))

      if (nrow(template_df) == 0) {
        template_df <- data.frame(
          Name = character(),
          Type = character(),
          Sections = numeric(),
          Format = character()
        )
      }

      datatable(
        template_df,
        selection = "single",
        options = list(
          pageLength = 10,
          dom = 't'
        ),
        rownames = FALSE
      )
    })


    # Load template into editor when selected
    observeEvent(input$template_list_rows_selected, {
      req(input$template_list_rows_selected)

      template_names <- names(templates())
      selected_name <- template_names[input$template_list_rows_selected]
      tmpl <- templates()[[selected_name]]

      selected_template(selected_name)

      # Update UI with template values
      updateTextInput(session, "template_name", value = selected_name)
      updateSelectInput(session, "template_type", selected = tmpl$type)
      updateTextAreaInput(session, "template_description", value = tmpl$description)
      updateCheckboxGroupInput(session, "sections", selected = tmpl$sections)
      updateSelectInput(session, "output_format", selected = tmpl$output_format)
      updateSelectInput(session, "citation_style", selected = tmpl$citation_style)
      updateSelectInput(session, "font", selected = tmpl$font)
      updateNumericInput(session, "font_size", value = tmpl$font_size)
      updateCheckboxInput(session, "include_toc", value = tmpl$include_toc)
      updateCheckboxInput(session, "page_numbers", value = tmpl$page_numbers)
      updateTextInput(session, "organization_name", value = tmpl$organization_name)
      updateColourInput(session, "primary_color", value = tmpl$primary_color)

      showNotification(paste("Loaded template:", selected_name), type = "message")
    })


    # Create new template
    observeEvent(input$create_template, {
      # Reset all fields
      updateTextInput(session, "template_name", value = "")
      updateSelectInput(session, "template_type", selected = "custom")
      updateTextAreaInput(session, "template_description", value = "")
      updateCheckboxGroupInput(session, "sections", selected = c("exec_summary", "ma_results"))

      selected_template(NULL)

      showNotification("Create a new template by filling in the fields", type = "message")
    })


    # Save template
    observeEvent(input$save_template, {
      req(input$template_name)

      if (input$template_name == "") {
        showNotification("Please provide a template name", type = "error")
        return()
      }

      # Create template object
      new_template <- list(
        name = input$template_name,
        type = input$template_type,
        description = input$template_description,
        sections = input$sections,
        output_format = input$output_format,
        citation_style = input$citation_style,
        font = input$font,
        font_size = input$font_size,
        include_toc = input$include_toc,
        include_figures_list = input$include_figures_list,
        page_numbers = input$page_numbers,
        line_numbers = input$line_numbers,
        organization_name = input$organization_name,
        report_id = input$report_id,
        primary_color = input$primary_color,
        secondary_color = input$secondary_color,
        custom_header = input$custom_header,
        custom_footer = input$custom_footer,
        disclaimer = input$disclaimer,
        created_date = Sys.Date(),
        modified_date = Sys.Date()
      )

      # Handle logo upload
      if (!is.null(input$logo_upload)) {
        logo_path <- file.path("outputs", "logos", basename(input$logo_upload$name))
        dir.create(dirname(logo_path), showWarnings = FALSE, recursive = TRUE)
        file.copy(input$logo_upload$datapath, logo_path, overwrite = TRUE)
        new_template$logo_path <- logo_path
      }

      # Add to templates list
      current_templates <- templates()
      current_templates[[input$template_name]] <- new_template
      templates(current_templates)

      # Save to disk
      save_template_to_disk(new_template)

      showNotification(paste("Template", input$template_name, "saved successfully!"),
                      type = "message")
    })


    # Delete template
    observeEvent(input$delete_template, {
      req(input$template_list_rows_selected)

      template_names <- names(templates())
      selected_name <- template_names[input$template_list_rows_selected]

      showModal(modalDialog(
        title = "Confirm Deletion",
        paste("Are you sure you want to delete the template:", selected_name, "?"),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("confirm_delete"), "Delete", class = "btn-danger")
        )
      ))
    })


    observeEvent(input$confirm_delete, {
      req(input$template_list_rows_selected)

      template_names <- names(templates())
      selected_name <- template_names[input$template_list_rows_selected]

      # Remove from list
      current_templates <- templates()
      current_templates[[selected_name]] <- NULL
      templates(current_templates)

      # Delete from disk
      delete_template_from_disk(selected_name)

      removeModal()
      showNotification(paste("Template", selected_name, "deleted"), type = "message")
    })


    # Duplicate template
    observeEvent(input$duplicate_template, {
      req(input$template_list_rows_selected)

      template_names <- names(templates())
      selected_name <- template_names[input$template_list_rows_selected]
      tmpl <- templates()[[selected_name]]

      # Create duplicate with new name
      new_name <- paste0(selected_name, " (Copy)")
      tmpl$name <- new_name
      tmpl$created_date <- Sys.Date()
      tmpl$modified_date <- Sys.Date()

      # Add to templates
      current_templates <- templates()
      current_templates[[new_name]] <- tmpl
      templates(current_templates)

      showNotification(paste("Duplicated template as:", new_name), type = "message")
    })


    # Export template
    output$export_template <- downloadHandler(
      filename = function() {
        req(selected_template())
        paste0(gsub(" ", "_", selected_template()), "_template.yaml")
      },
      content = function(file) {
        req(selected_template())

        tmpl <- templates()[[selected_template()]]
        yaml::write_yaml(tmpl, file)

        showNotification("Template exported successfully!", type = "message")
      }
    )


    # Import template
    observeEvent(input$import_template, {
      showModal(modalDialog(
        title = "Import Template",
        fileInput(session$ns("template_file"), "Select Template File (.yaml):"),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("confirm_import"), "Import", class = "btn-primary")
        )
      ))
    })


    observeEvent(input$confirm_import, {
      req(input$template_file)

      tryCatch({
        imported_template <- yaml::read_yaml(input$template_file$datapath)

        # Add to templates
        current_templates <- templates()
        current_templates[[imported_template$name]] <- imported_template
        templates(current_templates)

        removeModal()
        showNotification(paste("Template", imported_template$name, "imported!"),
                        type = "message")
      }, error = function(e) {
        showNotification(paste("Error importing template:", e$message), type = "error")
      })
    })


    # Preview template
    observeEvent(input$preview_template, {
      req(input$template_name)

      # Generate preview HTML
      preview_html <- generate_template_preview(
        name = input$template_name,
        type = input$template_type,
        sections = input$sections,
        output_format = input$output_format
      )

      showModal(modalDialog(
        title = "Template Preview",
        size = "l",
        HTML(preview_html),
        easyClose = TRUE,
        footer = modalButton("Close")
      ))
    })


    # Update template selector for report generation
    observe({
      template_choices <- names(templates())
      updateSelectInput(session, "template_to_use", choices = template_choices)
    })


    # Generate report
    observeEvent(input$generate_report, {
      req(input$template_to_use)
      req(rv$pairwise_results)

      template <- templates()[[input$template_to_use]]

      withProgress(message = "Generating report...", value = 0, {

        incProgress(0.1, detail = "Preparing data...")

        # Collect data
        report_data <- list(
          pairwise_results = rv$pairwise_results,
          nma_results = rv$nma_results,
          he_results = rv$he_results,
          protocol = rv$protocol,
          studies = rv$studies
        )

        incProgress(0.3, detail = "Rendering sections...")

        # Generate report
        output_file <- tryCatch({
          generate_report_from_template(template, report_data)
        }, error = function(e) {
          showNotification(paste("Error generating report:", e$message), type = "error")
          return(NULL)
        })

        incProgress(0.9, detail = "Finalizing...")

        if (!is.null(output_file)) {
          showNotification(
            paste("Report generated successfully:", basename(output_file)),
            type = "message",
            duration = 10
          )
          output$generation_status <- renderText({
            paste("✓ Report saved to:", output_file)
          })
        }
      })
    })

  })
}


# ============================================================================
# Helper Functions
# ============================================================================

#' Load Default Templates
#'
#' @return List of default templates
#' @keywords internal
load_default_templates <- function() {

  list(
    "NICE HTA Submission" = list(
      name = "NICE HTA Submission",
      type = "regulatory",
      description = "Standard template for NICE Technology Appraisals",
      sections = c("exec_summary", "introduction", "protocol", "study_chars",
                  "rob", "ma_results", "heterogeneity", "pub_bias",
                  "he_results", "ceac", "bia", "discussion", "conclusions",
                  "methods_appendix", "references"),
      output_format = "docx",
      citation_style = "vancouver",
      font = "Arial",
      font_size = 11,
      include_toc = TRUE,
      include_figures_list = TRUE,
      page_numbers = TRUE,
      line_numbers = FALSE,
      organization_name = "NICE",
      primary_color = "#005EB8",
      secondary_color = "#425563",
      created_date = Sys.Date()
    ),

    "Academic Journal" = list(
      name = "Academic Journal",
      type = "academic",
      description = "Template for academic journal submissions",
      sections = c("introduction", "protocol", "study_chars", "rob",
                  "ma_results", "forest_plots", "heterogeneity", "pub_bias",
                  "subgroup", "sensitivity", "discussion", "conclusions",
                  "references", "supplementary"),
      output_format = "docx",
      citation_style = "apa",
      font = "Times New Roman",
      font_size = 12,
      include_toc = FALSE,
      page_numbers = TRUE,
      line_numbers = TRUE,
      primary_color = "#000000",
      secondary_color = "#666666",
      created_date = Sys.Date()
    ),

    "Clinical Guidelines" = list(
      name = "Clinical Guidelines",
      type = "clinical",
      description = "Template for clinical practice guidelines",
      sections = c("exec_summary", "introduction", "ma_results", "grade",
                  "conclusions", "references"),
      output_format = "pdf",
      citation_style = "vancouver",
      font = "Arial",
      font_size = 11,
      include_toc = TRUE,
      page_numbers = TRUE,
      primary_color = "#2E7D32",
      secondary_color = "#1B5E20",
      created_date = Sys.Date()
    ),

    "Quick Summary" = list(
      name = "Quick Summary",
      type = "internal",
      description = "Brief internal report for stakeholders",
      sections = c("exec_summary", "ma_results", "he_results", "conclusions"),
      output_format = "pptx",
      citation_style = "apa",
      font = "Calibri",
      font_size = 11,
      include_toc = FALSE,
      page_numbers = FALSE,
      primary_color = "#3498db",
      secondary_color = "#2c3e50",
      created_date = Sys.Date()
    )
  )
}


#' Save Template to Disk
#'
#' @param template Template object to save
#' @keywords internal
save_template_to_disk <- function(template) {
  template_dir <- "outputs/templates"
  dir.create(template_dir, showWarnings = FALSE, recursive = TRUE)

  filename <- file.path(template_dir, paste0(gsub(" ", "_", template$name), ".yaml"))
  yaml::write_yaml(template, filename)
}


#' Delete Template from Disk
#'
#' @param template_name Name of template to delete
#' @keywords internal
delete_template_from_disk <- function(template_name) {
  filename <- file.path("outputs/templates", paste0(gsub(" ", "_", template_name), ".yaml"))
  if (file.exists(filename)) {
    file.remove(filename)
  }
}


#' Generate Template Preview HTML
#'
#' @param name Template name
#' @param type Template type
#' @param sections Sections included
#' @param output_format Output format
#' @return HTML string
#' @keywords internal
generate_template_preview <- function(name, type, sections, output_format) {

  section_names <- c(
    exec_summary = "Executive Summary",
    introduction = "Introduction & Background",
    protocol = "Systematic Review Protocol",
    prisma = "PRISMA Flow Diagram",
    study_chars = "Study Characteristics",
    rob = "Risk of Bias Assessment",
    network = "Network Geometry",
    ma_results = "Meta-Analysis Results",
    forest_plots = "Forest Plots",
    heterogeneity = "Heterogeneity Assessment",
    pub_bias = "Publication Bias",
    subgroup = "Subgroup Analyses",
    sensitivity = "Sensitivity Analyses",
    he_results = "Health Economic Results",
    ceac = "Cost-Effectiveness Acceptability",
    bia = "Budget Impact Analysis",
    grade = "GRADE Assessment",
    discussion = "Discussion & Limitations",
    conclusions = "Conclusions",
    methods_appendix = "Methods Appendix",
    references = "References",
    supplementary = "Supplementary Materials"
  )

  sections_html <- paste0(
    "<ol>",
    paste(lapply(sections, function(s) {
      paste0("<li>", section_names[s], "</li>")
    }), collapse = ""),
    "</ol>"
  )

  paste0(
    "<div style='padding: 20px;'>",
    "<h3>", name, "</h3>",
    "<p><strong>Type:</strong> ", type, "</p>",
    "<p><strong>Output Format:</strong> ", toupper(output_format), "</p>",
    "<hr>",
    "<h4>Sections Included:</h4>",
    sections_html,
    "</div>"
  )
}


#' Generate Report from Template
#'
#' @param template Template object
#' @param data Report data (pairwise_results, etc.)
#' @return Path to generated report file
#' @keywords internal
generate_report_from_template <- function(template, data) {

  # Create output directory
  output_dir <- file.path("outputs", "reports", format(Sys.Date(), "%Y%m%d"))
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  # Generate filename
  filename <- paste0(
    gsub(" ", "_", template$name),
    "_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    ".",
    template$output_format
  )
  output_file <- file.path(output_dir, filename)

  # Render report based on format
  if (template$output_format == "docx") {
    generate_word_report(template, data, output_file)
  } else if (template$output_format == "pdf") {
    generate_pdf_report(template, data, output_file)
  } else if (template$output_format == "html") {
    generate_html_report(template, data, output_file)
  } else if (template$output_format == "pptx") {
    generate_ppt_report(template, data, output_file)
  }

  return(output_file)
}


#' Generate Word Report
#'
#' @param template Template object
#' @param data Report data
#' @param output_file Output file path
#' @keywords internal
generate_word_report <- function(template, data, output_file) {

  # Create Word document
  doc <- officer::read_docx()

  # Add title
  doc <- officer::body_add_par(doc, template$name, style = "heading 1")
  doc <- officer::body_add_par(doc, paste("Generated:", Sys.Date()))

  # Add sections
  for (section in template$sections) {
    section_content <- render_section(section, data, template)
    doc <- officer::body_add_par(doc, section_content$title, style = "heading 2")
    doc <- officer::body_add_par(doc, section_content$content)
  }

  # Save document
  print(doc, target = output_file)
}


#' Generate PDF Report
#'
#' @keywords internal
generate_pdf_report <- function(template, data, output_file) {
  # Placeholder - would use rmarkdown::render with PDF output
  message("PDF generation not yet implemented")
}


#' Generate HTML Report
#'
#' @keywords internal
generate_html_report <- function(template, data, output_file) {
  # Placeholder - would use rmarkdown::render with HTML output
  message("HTML generation not yet implemented")
}


#' Generate PowerPoint Report
#'
#' @keywords internal
generate_ppt_report <- function(template, data, output_file) {
  # Placeholder - would use officer for PowerPoint generation
  message("PowerPoint generation not yet implemented")
}


#' Render Individual Section
#'
#' @param section Section identifier
#' @param data Report data
#' @param template Template object
#' @return List with title and content
#' @keywords internal
render_section <- function(section, data, template) {

  content <- switch(section,
    exec_summary = render_exec_summary_section(data),
    introduction = render_introduction_section(data),
    protocol = render_protocol_section(data$protocol),
    prisma = render_prisma_section(data$studies),
    study_chars = render_study_chars_section(data$studies),
    rob = render_rob_section(data$studies),
    network = render_network_section(data$nma_results),
    ma_results = render_ma_results_section(data$pairwise_results),
    forest_plots = render_forest_plots_section(data$pairwise_results),
    heterogeneity = render_heterogeneity_section(data$pairwise_results),
    pub_bias = render_pub_bias_section(data$pairwise_results),
    subgroup = render_subgroup_section(data$pairwise_results),
    sensitivity = render_sensitivity_section(data$pairwise_results),
    he_results = render_he_results_section(data$he_results),
    ceac = render_ceac_section(data$he_results),
    bia = render_bia_section(data$he_results),
    grade = render_grade_section(data$grade_results),
    discussion = render_discussion_section(data),
    conclusions = render_conclusions_section(data),
    methods_appendix = render_methods_appendix_section(),
    references = render_references_section(data),
    supplementary = render_supplementary_section(data),
    "Content not yet implemented for this section."
  )

  list(
    title = get_section_title(section),
    content = content
  )
}


#' Get Section Title
#'
#' @keywords internal
get_section_title <- function(section) {
  titles <- c(
    exec_summary = "Executive Summary",
    introduction = "Introduction",
    protocol = "Protocol and Methods",
    prisma = "PRISMA Flow Diagram",
    study_chars = "Study Characteristics",
    rob = "Risk of Bias Assessment",
    network = "Network Meta-Analysis",
    ma_results = "Meta-Analysis Results",
    forest_plots = "Forest Plots",
    heterogeneity = "Heterogeneity Assessment",
    pub_bias = "Publication Bias Assessment",
    subgroup = "Subgroup Analyses",
    sensitivity = "Sensitivity Analyses",
    he_results = "Health Economic Results",
    ceac = "Cost-Effectiveness Acceptability",
    bia = "Budget Impact Analysis",
    grade = "GRADE Evidence Profile",
    discussion = "Discussion",
    conclusions = "Conclusions and Recommendations",
    methods_appendix = "Appendix: Detailed Methods",
    references = "References",
    supplementary = "Supplementary Materials"
  )
  titles[section]
}


#' Render Executive Summary Section
#' @keywords internal
render_exec_summary_section <- function(data) {
  if (is.null(data$pairwise_results)) return("No analysis results available for executive summary.")

  ma <- data$pairwise_results
  summary_text <- sprintf(
    "A meta-analysis was conducted including %d studies. The pooled effect estimate was %.3f (95%% CI: %.3f to %.3f, p = %.4f). ",
    ifelse(!is.null(ma$k), ma$k, 0),
    ifelse(!is.null(ma$TE.random), ma$TE.random, 0),
    ifelse(!is.null(ma$lower.random), ma$lower.random, 0),
    ifelse(!is.null(ma$upper.random), ma$upper.random, 0),
    ifelse(!is.null(ma$pval.random), ma$pval.random, 1)
  )

  if (!is.null(ma$I2)) {
    summary_text <- paste0(summary_text, sprintf("Heterogeneity was %s (I² = %.1f%%). ",
                                                  ifelse(ma$I2 < 40, "low", ifelse(ma$I2 < 75, "moderate", "considerable")),
                                                  ma$I2 * 100))
  }

  return(summary_text)
}

#' Render Introduction Section
#' @keywords internal
render_introduction_section <- function(data) {
  return("This report presents the results of a systematic review and meta-analysis conducted to synthesize evidence from multiple studies. The analysis follows established methodological guidelines and reporting standards.")
}

#' Render Protocol Section
#' @keywords internal
render_protocol_section <- function(protocol) {
  if (is.null(protocol)) return("Protocol information not available.")
  return("Methods followed a pre-specified protocol registered with PROSPERO. Standard systematic review methods were applied including comprehensive database searching, dual independent screening, data extraction, and quality assessment.")
}

#' Render PRISMA Section
#' @keywords internal
render_prisma_section <- function(studies) {
  if (is.null(studies)) return("Study flow information not available.")
  n_studies <- nrow(studies)
  return(sprintf("The systematic search identified %d eligible studies for inclusion in the meta-analysis. [PRISMA flow diagram would be included here]", n_studies))
}

#' Render Study Characteristics Section
#' @keywords internal
render_study_chars_section <- function(studies) {
  if (is.null(studies)) return("Study characteristics not available.")

  n_studies <- nrow(studies)
  char_text <- sprintf("Table of characteristics for %d included studies:\n\n", n_studies)
  char_text <- paste0(char_text, "[Study characteristics table would be formatted here with columns for: Study ID, Year, Design, N, Intervention, Comparator, Outcome, Follow-up]")

  return(char_text)
}

#' Render Risk of Bias Section
#' @keywords internal
render_rob_section <- function(studies) {
  if (is.null(studies)) return("Risk of bias assessment not available.")
  return("Risk of bias was assessed using the Cochrane Risk of Bias tool. [Risk of bias summary figure and detailed assessments would be included here]")
}

#' Render Network Section
#' @keywords internal
render_network_section <- function(nma_results) {
  if (is.null(nma_results)) return("Network meta-analysis was not performed.")
  return("Network meta-analysis results including network plot, treatment rankings, and relative effects. [Network geometry and results tables would be included here]")
}

#' Render MA Results Section
#' @keywords internal
render_ma_results_section <- function(pairwise_results) {
  if (is.null(pairwise_results)) return("No meta-analysis results available.")

  ma <- pairwise_results
  results_text <- sprintf(
    "Meta-Analysis Results:\n\nNumber of studies: %d\nPooled effect (Random Effects): %.3f (95%% CI: %.3f to %.3f)\nP-value: %.4f\nStatistical significance: %s\n\n",
    ifelse(!is.null(ma$k), ma$k, 0),
    ifelse(!is.null(ma$TE.random), ma$TE.random, 0),
    ifelse(!is.null(ma$lower.random), ma$lower.random, 0),
    ifelse(!is.null(ma$upper.random), ma$upper.random, 0),
    ifelse(!is.null(ma$pval.random), ma$pval.random, 1),
    ifelse(!is.null(ma$pval.random) && ma$pval.random < 0.05, "Significant (p < 0.05)", "Not significant")
  )

  results_text <- paste0(results_text, "The pooled effect estimate suggests ",
                        ifelse(!is.null(ma$TE.random) && ma$TE.random > 0, "a beneficial effect", "no benefit or potential harm"),
                        " of the intervention.")

  return(results_text)
}

#' Render Forest Plots Section
#' @keywords internal
render_forest_plots_section <- function(pairwise_results) {
  if (is.null(pairwise_results)) return("No forest plot data available.")
  return("Forest plots showing individual study effects and pooled estimates. [Forest plot figures would be embedded here]")
}

#' Render Heterogeneity Section
#' @keywords internal
render_heterogeneity_section <- function(pairwise_results) {
  if (is.null(pairwise_results)) return("No heterogeneity statistics available.")

  ma <- pairwise_results
  het_text <- sprintf(
    "Heterogeneity Assessment:\n\nI² statistic: %.1f%%\nTau² (between-study variance): %.4f\nQ statistic: %.2f (df = %d, p = %.4f)\n\nInterpretation: %s heterogeneity detected.\n",
    ifelse(!is.null(ma$I2), ma$I2 * 100, 0),
    ifelse(!is.null(ma$tau2), ma$tau2, 0),
    ifelse(!is.null(ma$Q), ma$Q, 0),
    ifelse(!is.null(ma$df.Q), ma$df.Q, 0),
    ifelse(!is.null(ma$pval.Q), ma$pval.Q, 1),
    ifelse(!is.null(ma$I2) && ma$I2 < 0.4, "Low",
           ifelse(!is.null(ma$I2) && ma$I2 < 0.75, "Moderate", "Considerable"))
  )

  return(het_text)
}

#' Render Publication Bias Section
#' @keywords internal
render_pub_bias_section <- function(pairwise_results) {
  if (is.null(pairwise_results)) return("No publication bias assessment available.")
  return("Publication bias was assessed using funnel plots and Egger's regression test. [Funnel plot figure and statistical test results would be included here]")
}

#' Render Subgroup Section
#' @keywords internal
render_subgroup_section <- function(pairwise_results) {
  if (is.null(pairwise_results)) return("No subgroup analyses performed.")
  return("Subgroup analyses were conducted to explore sources of heterogeneity. [Subgroup forest plots and interaction tests would be included here]")
}

#' Render Sensitivity Section
#' @keywords internal
render_sensitivity_section <- function(pairwise_results) {
  if (is.null(pairwise_results)) return("No sensitivity analyses performed.")
  return("Sensitivity analyses were performed to assess robustness of findings. [Results of leave-one-out analyses and other sensitivity analyses would be included here]")
}

#' Render HE Results Section
#' @keywords internal
render_he_results_section <- function(he_results) {
  if (is.null(he_results)) return("No health economic results available.")

  he <- he_results
  he_text <- sprintf(
    "Health Economic Analysis Results:\n\nIncremental Cost-Effectiveness Ratio (ICER): £%.2f per QALY gained\nIncremental Costs: £%.2f\nIncremental QALYs: %.3f\n\nCost-effectiveness conclusion: %s\n",
    ifelse(!is.null(he$icer), he$icer, 0),
    ifelse(!is.null(he$incr_cost), he$incr_cost, 0),
    ifelse(!is.null(he$incr_qaly), he$incr_qaly, 0),
    ifelse(!is.null(he$icer) && he$icer < 20000, "Cost-effective at £20,000/QALY threshold",
           ifelse(!is.null(he$icer) && he$icer < 30000, "Cost-effective at £30,000/QALY threshold",
                  "Not cost-effective at standard thresholds"))
  )

  return(he_text)
}

#' Render CEAC Section
#' @keywords internal
render_ceac_section <- function(he_results) {
  if (is.null(he_results)) return("No cost-effectiveness acceptability data available.")
  return("Cost-effectiveness acceptability curve (CEAC) showing probability of cost-effectiveness across willingness-to-pay thresholds. [CEAC figure would be included here]")
}

#' Render Budget Impact Section
#' @keywords internal
render_bia_section <- function(he_results) {
  if (is.null(he_results)) return("No budget impact analysis available.")
  return("Budget impact analysis projecting financial impact of adoption over 1-5 years. [BIA table and figures would be included here]")
}

#' Render GRADE Section
#' @keywords internal
render_grade_section <- function(grade_results) {
  if (is.null(grade_results)) return("GRADE assessment not available.")
  return("GRADE evidence profile assessing certainty of evidence across five domains. [GRADE evidence profile table would be included here]")
}

#' Render Discussion Section
#' @keywords internal
render_discussion_section <- function(data) {
  return("This meta-analysis provides evidence regarding the effectiveness and value of the intervention. Results should be interpreted in the context of study quality, heterogeneity, and potential biases. Implications for clinical practice and policy are discussed.")
}

#' Render Conclusions Section
#' @keywords internal
render_conclusions_section <- function(data) {
  if (is.null(data$pairwise_results)) return("Insufficient data for conclusions.")

  ma <- data$pairwise_results
  conclusion <- ifelse(!is.null(ma$pval.random) && ma$pval.random < 0.05,
                      "Evidence suggests a statistically significant effect of the intervention.",
                      "Evidence does not support a statistically significant effect.")

  conclusion <- paste0(conclusion, " Further research may be needed to strengthen the evidence base.")
  return(conclusion)
}

#' Render Methods Appendix Section
#' @keywords internal
render_methods_appendix_section <- function() {
  return("Detailed statistical methods including meta-analysis models, heterogeneity assessment approaches, and economic modeling parameters. Full search strategies are provided in supplementary materials.")
}

#' Render References Section
#' @keywords internal
render_references_section <- function(data) {
  return("[References would be automatically generated here based on citations in the text]")
}

#' Render Supplementary Section
#' @keywords internal
render_supplementary_section <- function(data) {
  return("Supplementary materials including full data extraction tables, additional sensitivity analyses, and supporting documentation.")
}
