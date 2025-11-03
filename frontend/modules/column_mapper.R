# Column Mapping Wizard Module
# Visual interface for mapping data columns to required format
# Part of Phase 2+v2 implementation - Critical UX improvement

library(shiny)
library(bslib)
library(DT)

# UI
column_mapper_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # Header
      card(
        card_header(
          tags$div(
            class = "d-flex justify-content-between align-items-center",
            tags$h4(class = "mb-0", icon("arrows-left-right"), " Column Mapping Wizard"),
            actionButton(ns("btn_help"), icon("circle-question"),
                        class = "btn-sm btn-outline-secondary")
          )
        ),

        card_body(
          p(class = "text-muted",
            "Map your data columns to the required format for meta-analysis. The wizard ",
            "auto-detects common formats (Covidence, RevMan, DistillerSR) and provides a ",
            "visual interface to customize mappings."
          ),

          layout_columns(
            col_widths = c(4, 4, 4),

            selectInput(ns("template_select"), "Load Template",
                       choices = c(
                         "Auto-Detect" = "auto",
                         "Covidence Export" = "covidence",
                         "RevMan 5" = "revman",
                         "DistillerSR" = "distiller",
                         "Generic Binary" = "generic_binary",
                         "Generic Continuous" = "generic_continuous",
                         "Custom Mapping" = "custom"
                       )),

            actionButton(ns("btn_auto_map"), "Auto-Map Columns",
                        icon = icon("wand-magic-sparkles"),
                        class = "btn-primary w-100 mt-4"),

            actionButton(ns("btn_reset_map"), "Reset Mapping",
                        icon = icon("rotate-left"),
                        class = "btn-secondary w-100 mt-4")
          )
        )
      )
    ),

    # Mapping interface
    layout_columns(
      col_widths = c(12),

      card(
        card_header("Column Mapping"),

        card_body(
          uiOutput(ns("mapping_interface")),

          hr(),

          layout_columns(
            col_widths = c(6, 6),

            actionButton(ns("btn_apply_mapping"), "Apply Mapping",
                        icon = icon("check"),
                        class = "btn-success btn-lg w-100"),

            actionButton(ns("btn_save_template"), "Save as Template",
                        icon = icon("floppy-disk"),
                        class = "btn-info btn-lg w-100")
          )
        )
      )
    ),

    # Preview
    layout_columns(
      col_widths = c(12),

      card(
        card_header(
          tags$h5(class = "mb-0", icon("eye"), " Data Preview (After Mapping)")
        ),

        card_body(
          DTOutput(ns("preview_table")),
          hr(),
          uiOutput(ns("validation_messages"))
        )
      )
    )
  )
}

# Server
column_mapper_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    current_mapping <- reactiveVal(list())
    mapped_data <- reactiveVal(NULL)
    validation_results <- reactiveVal(NULL)

    # Help modal
    observeEvent(input$btn_help, {
      showModal(modalDialog(
        title = tags$h4(icon("circle-question"), " Column Mapping Wizard Help"),
        size = "l",

        tags$div(
          tags$h5("What is Column Mapping?"),
          tags$p("The Column Mapping Wizard helps you import data from various sources by ",
                "translating your column names to the format required for meta-analysis."),

          tags$hr(),

          tags$h5("How to Use:"),
          tags$ol(
            tags$li("Upload your data file in the Data Import tab"),
            tags$li("Select a template (Auto-Detect, Covidence, RevMan, etc.) or choose Custom"),
            tags$li("Click 'Auto-Map Columns' to automatically match columns"),
            tags$li("Review the mappings - adjust dropdowns if needed"),
            tags$li("Check the preview table to verify correct mapping"),
            tags$li("Click 'Apply Mapping' to transform your data"),
            tags$li("Optionally, save your custom mapping as a template for reuse")
          ),

          tags$hr(),

          tags$h5("Supported Formats:"),
          tags$ul(
            tags$li(tags$strong("Covidence:"), " Extractions from Covidence systematic review software"),
            tags$li(tags$strong("RevMan 5:"), " Data from Cochrane's Review Manager"),
            tags$li(tags$strong("DistillerSR:"), " Exports from Evidence Partners DistillerSR"),
            tags$li(tags$strong("Generic Binary:"), " Standard 2×2 table format (events, n)"),
            tags$li(tags$strong("Generic Continuous:"), " Mean/SD format for continuous outcomes")
          ),

          tags$hr(),

          tags$h5("Required Columns:"),
          tags$p(tags$strong("For Binary Data:")),
          tags$ul(
            tags$li("study_id: Unique study identifier"),
            tags$li("events_exp: Number of events in experimental group"),
            tags$li("n_exp: Sample size in experimental group"),
            tags$li("events_ctrl: Number of events in control group"),
            tags$li("n_ctrl: Sample size in control group")
          ),

          tags$p(tags$strong("For Continuous Data:")),
          tags$ul(
            tags$li("study_id: Unique study identifier"),
            tags$li("mean_exp: Mean in experimental group"),
            tags$li("sd_exp: Standard deviation in experimental group"),
            tags$li("n_exp: Sample size in experimental group"),
            tags$li("mean_ctrl: Mean in control group"),
            tags$li("sd_ctrl: Standard deviation in control group"),
            tags$li("n_ctrl: Sample size in control group")
          )
        ),

        footer = modalButton("Close")
      ))
    })

    # Auto-map columns
    observeEvent(input$btn_auto_map, {
      req(rv$data)

      tryCatch({
        # Detect template
        template <- if (input$template_select == "auto") {
          detect_template(names(rv$data))
        } else {
          input$template_select
        }

        # Get mapping rules
        mapping <- get_template_mapping(template)

        # Apply fuzzy matching
        detected_mapping <- auto_match_columns(names(rv$data), mapping)

        current_mapping(detected_mapping)

        showNotification(
          paste("Auto-mapped columns using", template, "template"),
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        showNotification(
          paste("Error auto-mapping:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Reset mapping
    observeEvent(input$btn_reset_map, {
      current_mapping(list())
      mapped_data(NULL)
      validation_results(NULL)
    })

    # Render mapping interface
    output$mapping_interface <- renderUI({
      req(rv$data)

      available_cols <- c("(Not Mapped)" = "", names(rv$data))
      mapping <- current_mapping()

      # Required fields based on data type
      required_fields <- list(
        binary = c("study_id", "events_exp", "n_exp", "events_ctrl", "n_ctrl"),
        continuous = c("study_id", "mean_exp", "sd_exp", "n_exp", "mean_ctrl", "sd_ctrl", "n_ctrl"),
        network = c("study_id", "treatment1", "treatment2", "TE", "seTE")
      )

      # Create dropdowns for each required field
      fields_ui <- lapply(required_fields$binary, function(field) {
        current_value <- mapping[[field]] %||% ""

        tags$div(
          class = "mb-3",
          tags$label(
            class = "form-label",
            tags$strong(field),
            if (field %in% c("study_id", "events_exp", "n_exp", "events_ctrl", "n_ctrl")) {
              tags$span(class = "text-danger", " *")
            }
          ),
          selectInput(ns(paste0("map_", field)),
                     label = NULL,
                     choices = available_cols,
                     selected = current_value,
                     width = "100%")
        )
      })

      tagList(
        tags$p(tags$strong("Map Your Columns:"), " Select which column from your data corresponds to each required field."),
        tags$p(class = "text-muted small", tags$span(class = "text-danger", "*"), " Required field"),

        layout_columns(
          col_widths = c(6, 6),

          # Left column: Study and experimental
          tagList(
            tags$h6("Study & Experimental Group"),
            fields_ui[[1]],  # study_id
            fields_ui[[2]],  # events_exp
            fields_ui[[3]]   # n_exp
          ),

          # Right column: Control
          tagList(
            tags$h6("Control Group"),
            fields_ui[[4]],  # events_ctrl
            fields_ui[[5]]   # n_ctrl
          )
        )
      )
    })

    # Apply mapping
    observeEvent(input$btn_apply_mapping, {
      req(rv$data)

      tryCatch({
        # Collect mapping from inputs
        mapping <- list(
          study_id = input$map_study_id,
          events_exp = input$map_events_exp,
          n_exp = input$map_n_exp,
          events_ctrl = input$map_events_ctrl,
          n_ctrl = input$map_n_ctrl
        )

        # Validate mapping
        validation <- validate_mapping(mapping, rv$data)

        if (!validation$valid) {
          validation_results(validation)
          showNotification(
            paste("Mapping validation failed:", validation$message),
            type = "warning",
            duration = 10
          )
          return()
        }

        # Apply mapping to data
        mapped <- apply_column_mapping(rv$data, mapping)

        mapped_data(mapped)
        validation_results(validation)

        showNotification(
          "Mapping applied successfully! Check the preview below.",
          type = "message",
          duration = 5
        )

      }, error = function(e) {
        showNotification(
          paste("Error applying mapping:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Save template
    observeEvent(input$btn_save_template, {
      showModal(modalDialog(
        title = "Save Mapping Template",
        textInput(ns("template_name"), "Template Name",
                 placeholder = "e.g., My Custom Format"),
        textAreaInput(ns("template_description"), "Description (Optional)",
                     placeholder = "Describe when to use this template..."),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("btn_save_confirm"), "Save", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_confirm, {
      # Collect current mapping
      mapping <- list(
        name = input$template_name,
        description = input$template_description,
        mappings = list(
          study_id = input$map_study_id,
          events_exp = input$map_events_exp,
          n_exp = input$map_n_exp,
          events_ctrl = input$map_events_ctrl,
          n_ctrl = input$map_n_ctrl
        )
      )

      # Save to disk
      if (!dir.exists("outputs/column_templates")) {
        dir.create("outputs/column_templates", recursive = TRUE)
      }

      filename <- paste0("outputs/column_templates/",
                        gsub(" ", "_", tolower(input$template_name)), ".json")
      jsonlite::write_json(mapping, filename, pretty = TRUE, auto_unbox = TRUE)

      showNotification(
        paste("Template saved:", input$template_name),
        type = "message",
        duration = 5
      )

      removeModal()
    })

    # Preview table
    output$preview_table <- renderDT({
      req(mapped_data())

      df <- mapped_data()

      datatable(
        head(df, 20),
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 't'
        ),
        rownames = FALSE,
        class = "display stripe hover"
      )
    })

    # Validation messages
    output$validation_messages <- renderUI({
      req(validation_results())

      results <- validation_results()

      if (results$valid) {
        tags$div(
          class = "alert alert-success",
          icon("check-circle"), " ",
          tags$strong("Validation Passed!"),
          " All required columns are mapped correctly. ",
          "Click the 'Data' tab to view your mapped data."
        )
      } else {
        tags$div(
          class = "alert alert-warning",
          icon("exclamation-triangle"), " ",
          tags$strong("Validation Issues:"),
          tags$ul(
            lapply(results$errors, function(err) tags$li(err))
          )
        )
      }
    })

    # Return reactive values
    return(reactive({
      list(
        mapped_data = mapped_data(),
        mapping = current_mapping()
      )
    }))
  })
}

# Helper: Detect template from column names
detect_template <- function(column_names) {
  # Covidence patterns
  if (any(grepl("Covidence", column_names, ignore.case = TRUE)) ||
      any(grepl("Study ID", column_names, ignore.case = TRUE))) {
    return("covidence")
  }

  # RevMan patterns
  if (any(grepl("Study", column_names)) &&
      any(grepl("Events.1|Events.2", column_names))) {
    return("revman")
  }

  # DistillerSR patterns
  if (any(grepl("Refid|Reference ID", column_names, ignore.case = TRUE))) {
    return("distiller")
  }

  # Generic binary
  if (any(grepl("events", column_names, ignore.case = TRUE)) &&
      any(grepl("^n$|total", column_names, ignore.case = TRUE))) {
    return("generic_binary")
  }

  # Generic continuous
  if (any(grepl("mean", column_names, ignore.case = TRUE)) &&
      any(grepl("sd|standard", column_names, ignore.case = TRUE))) {
    return("generic_continuous")
  }

  return("custom")
}

# Helper: Get template mapping rules
get_template_mapping <- function(template) {
  templates <- list(
    covidence = list(
      study_id = c("Study ID", "StudyID", "study_id"),
      events_exp = c("Events (Intervention)", "events_intervention", "events.intervention"),
      n_exp = c("Total (Intervention)", "n_intervention", "total_intervention"),
      events_ctrl = c("Events (Control)", "events_control", "events.control"),
      n_ctrl = c("Total (Control)", "n_control", "total_control")
    ),

    revman = list(
      study_id = c("Study", "Study ID", "StudyID"),
      events_exp = c("Events.1", "Events 1", "events1"),
      n_exp = c("Total.1", "Total 1", "total1"),
      events_ctrl = c("Events.2", "Events 2", "events2"),
      n_ctrl = c("Total.2", "Total 2", "total2")
    ),

    distiller = list(
      study_id = c("Refid", "Reference ID", "study_id"),
      events_exp = c("Outcome events - Intervention", "events_int"),
      n_exp = c("Sample size - Intervention", "n_int"),
      events_ctrl = c("Outcome events - Control", "events_ctrl"),
      n_ctrl = c("Sample size - Control", "n_ctrl")
    ),

    generic_binary = list(
      study_id = c("study_id", "study", "id", "author", "first_author"),
      events_exp = c("events_exp", "events_intervention", "events1", "r1", "events.e"),
      n_exp = c("n_exp", "n_intervention", "n1", "total1", "n.e"),
      events_ctrl = c("events_ctrl", "events_control", "events2", "r2", "events.c"),
      n_ctrl = c("n_ctrl", "n_control", "n2", "total2", "n.c")
    ),

    generic_continuous = list(
      study_id = c("study_id", "study", "id", "author"),
      mean_exp = c("mean_exp", "mean_intervention", "mean1", "mean.e"),
      sd_exp = c("sd_exp", "sd_intervention", "sd1", "sd.e"),
      n_exp = c("n_exp", "n_intervention", "n1", "n.e"),
      mean_ctrl = c("mean_ctrl", "mean_control", "mean2", "mean.c"),
      sd_ctrl = c("sd_ctrl", "sd_control", "sd2", "sd.c"),
      n_ctrl = c("n_ctrl", "n_control", "n2", "n.c")
    )
  )

  return(templates[[template]] %||% list())
}

# Helper: Auto-match columns using fuzzy matching
auto_match_columns <- function(data_columns, template_mapping) {
  matched <- list()

  for (field in names(template_mapping)) {
    patterns <- template_mapping[[field]]

    # Exact match first
    exact_match <- intersect(patterns, data_columns)

    if (length(exact_match) > 0) {
      matched[[field]] <- exact_match[1]
      next
    }

    # Fuzzy match (case-insensitive)
    for (pattern in patterns) {
      fuzzy_match <- data_columns[grepl(pattern, data_columns, ignore.case = TRUE)]

      if (length(fuzzy_match) > 0) {
        matched[[field]] <- fuzzy_match[1]
        break
      }
    }
  }

  return(matched)
}

# Helper: Validate mapping
validate_mapping <- function(mapping, data) {
  errors <- character(0)

  # Check required fields
  required <- c("study_id", "events_exp", "n_exp", "events_ctrl", "n_ctrl")

  for (field in required) {
    if (is.null(mapping[[field]]) || mapping[[field]] == "") {
      errors <- c(errors, paste("Required field", field, "is not mapped"))
    } else if (!mapping[[field]] %in% names(data)) {
      errors <- c(errors, paste("Mapped column", mapping[[field]], "does not exist in data"))
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    message = if (length(errors) > 0) paste(errors, collapse = "; ") else "Valid"
  ))
}

# Helper: Apply column mapping
apply_column_mapping <- function(data, mapping) {
  # Create new dataframe with mapped columns
  mapped_data <- data.frame(
    study_id = data[[mapping$study_id]],
    events_exp = as.numeric(data[[mapping$events_exp]]),
    n_exp = as.numeric(data[[mapping$n_exp]]),
    events_ctrl = as.numeric(data[[mapping$events_ctrl]]),
    n_ctrl = as.numeric(data[[mapping$n_ctrl]]),
    stringsAsFactors = FALSE
  )

  return(mapped_data)
}

# Utility: Null coalescing operator
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}
