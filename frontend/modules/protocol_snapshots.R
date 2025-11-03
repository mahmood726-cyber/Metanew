# Protocol Snapshots Module
# Version locking and deviation tracking for research protocols
# Part of Phase 2+v2 implementation - supports PROSPERO/OSF pre-registration

library(shiny)
library(bslib)
library(DT)
library(jsonlite)
library(diffobj)

# UI
protocol_snapshots_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(12),

      # Header card
      card(
        card_header(
          tags$div(
            class = "d-flex justify-content-between align-items-center",
            tags$h4(class = "mb-0", icon("camera"), " Protocol Snapshots & Version Control"),
            actionButton(ns("btn_help"), icon("circle-question"),
                        class = "btn-sm btn-outline-secondary")
          )
        ),

        card_body(
          p(class = "text-muted",
            "Lock your protocol at key milestones (e.g., pre-registration, before data extraction, ",
            "before analysis) to create an audit trail. Generate deviation reports comparing ",
            "planned protocol vs. actual execution for transparency and regulatory compliance."
          ),

          layout_columns(
            col_widths = c(6, 6),

            # Create snapshot
            card(
              card_header("Create New Snapshot", class = "bg-primary text-white"),
              textInput(ns("snapshot_label"), "Snapshot Label",
                       placeholder = "e.g., Pre-Registration, Before Analysis"),
              selectInput(ns("snapshot_milestone"), "Milestone",
                         choices = c(
                           "Protocol Registration" = "registration",
                           "Before Data Extraction" = "pre_extraction",
                           "Before Analysis" = "pre_analysis",
                           "Before Reporting" = "pre_reporting",
                           "Final/Publication" = "final",
                           "Custom" = "custom"
                         )),
              textAreaInput(ns("snapshot_notes"), "Notes (Optional)",
                           placeholder = "Document rationale, changes, or context...",
                           rows = 3),
              actionButton(ns("btn_create_snapshot"), "Create Snapshot",
                          icon = icon("camera"),
                          class = "btn-primary w-100 btn-lg mt-2")
            ),

            # Load snapshot
            card(
              card_header("Load Snapshot", class = "bg-secondary text-white"),
              uiOutput(ns("snapshot_selector")),
              actionButton(ns("btn_view_snapshot"), "View Snapshot",
                          icon = icon("eye"),
                          class = "btn-secondary w-100 mb-2"),
              actionButton(ns("btn_restore_snapshot"), "Restore to Protocol",
                          icon = icon("rotate-left"),
                          class = "btn-warning w-100 mb-2"),
              actionButton(ns("btn_delete_snapshot"), "Delete Snapshot",
                          icon = icon("trash"),
                          class = "btn-danger w-100")
            )
          )
        )
      )
    ),

    # Snapshot list
    layout_columns(
      col_widths = c(12),

      card(
        card_header(
          tags$h5(class = "mb-0", icon("list"), " Saved Snapshots")
        ),
        card_body(
          DTOutput(ns("snapshots_table")),
          hr(),
          p(class = "text-muted small",
            icon("info-circle"),
            " Snapshots are immutable records of your protocol at specific timepoints. ",
            "Use the deviation report tool to compare snapshots."
          )
        )
      )
    ),

    # Deviation report
    layout_columns(
      col_widths = c(12),

      card(
        card_header(
          tags$h5(class = "mb-0", icon("code-compare"), " Deviation Report")
        ),

        card_body(
          p(class = "text-muted",
            "Compare a baseline snapshot (e.g., pre-registration) against the current protocol ",
            "or another snapshot to document and explain deviations."
          ),

          layout_columns(
            col_widths = c(5, 5, 2),

            selectInput(ns("baseline_snapshot"), "Baseline (Planned)",
                       choices = NULL),

            selectInput(ns("comparison_snapshot"), "Comparison (Actual)",
                       choices = c("Current Protocol" = "current")),

            actionButton(ns("btn_generate_deviation"), "Generate Report",
                        icon = icon("file-alt"),
                        class = "btn-success btn-lg w-100 mt-4")
          ),

          hr(),

          uiOutput(ns("deviation_output"))
        )
      )
    )
  )
}

# Server
protocol_snapshots_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    snapshots <- reactiveVal(list())
    deviation_report <- reactiveVal(NULL)

    # Initialize: Load existing snapshots from disk
    observe({
      if (dir.exists("outputs/protocol_snapshots")) {
        files <- list.files("outputs/protocol_snapshots", pattern = "\\.json$", full.names = TRUE)

        if (length(files) > 0) {
          loaded_snapshots <- lapply(files, function(f) {
            tryCatch(jsonlite::read_json(f), error = function(e) NULL)
          })

          loaded_snapshots <- Filter(Negate(is.null), loaded_snapshots)
          snapshots(loaded_snapshots)
        }
      }
    })

    # Help modal
    observeEvent(input$btn_help, {
      showModal(modalDialog(
        title = tags$h4(icon("circle-question"), " Protocol Snapshots Help"),
        size = "l",

        tags$div(
          tags$h5("What are Protocol Snapshots?"),
          tags$p("Protocol snapshots are immutable records of your research protocol at specific timepoints. ",
                "They enable:",
                tags$ul(
                  tags$li("Pre-registration compliance (PROSPERO, OSF, ClinicalTrials.gov)"),
                  tags$li("Transparent documentation of protocol amendments"),
                  tags$li("Audit trails for regulatory submissions (FDA, EMA)"),
                  tags$li("Deviation tracking for systematic review guidelines (PRISMA)")
                )),

          tags$hr(),

          tags$h5("Recommended Workflow:"),
          tags$ol(
            tags$li(tags$strong("Snapshot 1: Protocol Registration"),
                   " - After finalizing PICO and search strategy, before data extraction"),
            tags$li(tags$strong("Snapshot 2: Before Data Extraction"),
                   " - Lock selection criteria and data fields"),
            tags$li(tags$strong("Snapshot 3: Before Analysis"),
                   " - Lock analysis plan, subgroups, sensitivity analyses"),
            tags$li(tags$strong("Snapshot 4: Final/Publication"),
                   " - Document final protocol with all amendments"),
            tags$li(tags$strong("Generate Deviation Report"),
                   " - Compare Snapshot 1 vs. Current to document all changes")
          ),

          tags$hr(),

          tags$h5("Best Practices:"),
          tags$ul(
            tags$li("Create snapshots BEFORE making protocol changes, not after"),
            tags$li("Use descriptive labels that indicate milestone/date"),
            tags$li("Document rationale for deviations in the notes field"),
            tags$li("Generate deviation reports for manuscript methods section"),
            tags$li("Store snapshots with your study files for reproducibility")
          )
        ),

        footer = modalButton("Close")
      ))
    })

    # Create snapshot
    observeEvent(input$btn_create_snapshot, {
      req(rv$protocol)

      # Validate label
      if (input$snapshot_label == "") {
        showNotification(
          "Please provide a snapshot label",
          type = "warning",
          duration = 5
        )
        return()
      }

      tryCatch({
        # Create snapshot object
        snapshot <- list(
          snapshot_id = paste0("SNAP_", format(Sys.time(), "%Y%m%d_%H%M%S")),
          label = input$snapshot_label,
          milestone = input$snapshot_milestone,
          created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
          created_by = Sys.getenv("USER"),
          notes = input$snapshot_notes,
          protocol = rv$protocol
        )

        # Save to disk
        if (!dir.exists("outputs/protocol_snapshots")) {
          dir.create("outputs/protocol_snapshots", recursive = TRUE)
        }

        filename <- paste0("outputs/protocol_snapshots/", snapshot$snapshot_id, ".json")
        jsonlite::write_json(snapshot, filename, pretty = TRUE, auto_unbox = TRUE)

        # Update reactive list
        current_snapshots <- snapshots()
        current_snapshots[[length(current_snapshots) + 1]] <- snapshot
        snapshots(current_snapshots)

        showNotification(
          paste("Snapshot created:", snapshot$label),
          type = "message",
          duration = 5
        )

        # Clear inputs
        updateTextInput(session, "snapshot_label", value = "")
        updateTextAreaInput(session, "snapshot_notes", value = "")

      }, error = function(e) {
        showNotification(
          paste("Error creating snapshot:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Snapshot selector
    output$snapshot_selector <- renderUI({
      current_snapshots <- snapshots()

      if (length(current_snapshots) == 0) {
        return(p(class = "text-muted", "No snapshots created yet."))
      }

      choices <- setNames(
        sapply(current_snapshots, function(s) s$snapshot_id),
        sapply(current_snapshots, function(s) paste0(s$label, " (", s$created_at, ")"))
      )

      selectInput(ns("selected_snapshot"), "Select Snapshot", choices = choices)
    })

    # Snapshots table
    output$snapshots_table <- renderDT({
      current_snapshots <- snapshots()

      if (length(current_snapshots) == 0) {
        return(data.frame(
          Message = "No snapshots created yet. Create your first snapshot above."
        ))
      }

      df <- data.frame(
        Label = sapply(current_snapshots, function(s) s$label),
        Milestone = sapply(current_snapshots, function(s) s$milestone),
        Created = sapply(current_snapshots, function(s) s$created_at),
        Created_By = sapply(current_snapshots, function(s) s$created_by),
        Notes = sapply(current_snapshots, function(s) {
          notes <- s$notes
          if (is.null(notes) || notes == "") return("-")
          if (nchar(notes) > 50) return(paste0(substr(notes, 1, 47), "..."))
          return(notes)
        }),
        stringsAsFactors = FALSE
      )

      datatable(
        df,
        options = list(
          pageLength = 5,
          order = list(list(2, 'desc')),  # Sort by Created descending
          dom = 't'
        ),
        rownames = FALSE,
        class = "display stripe hover"
      )
    })

    # View snapshot
    observeEvent(input$btn_view_snapshot, {
      req(input$selected_snapshot)

      current_snapshots <- snapshots()
      snapshot <- Find(function(s) s$snapshot_id == input$selected_snapshot, current_snapshots)

      if (is.null(snapshot)) {
        showNotification("Snapshot not found", type = "error", duration = 5)
        return()
      }

      # Display snapshot in modal
      showModal(modalDialog(
        title = tags$h4(icon("camera"), " ", snapshot$label),
        size = "l",

        tags$div(
          tags$p(tags$strong("Milestone: "), snapshot$milestone),
          tags$p(tags$strong("Created: "), snapshot$created_at),
          tags$p(tags$strong("Created By: "), snapshot$created_by),
          tags$p(tags$strong("Notes: "), snapshot$notes %||% "None"),

          tags$hr(),

          tags$h5("Protocol Snapshot:"),
          tags$pre(
            style = "background-color: #f5f5f5; padding: 15px; border-radius: 5px; max-height: 400px; overflow-y: auto;",
            jsonlite::toJSON(snapshot$protocol, pretty = TRUE, auto_unbox = TRUE)
          )
        ),

        footer = modalButton("Close")
      ))
    })

    # Restore snapshot
    observeEvent(input$btn_restore_snapshot, {
      req(input$selected_snapshot)

      showModal(modalDialog(
        title = "Confirm Restore",
        "Are you sure you want to restore this snapshot to the current protocol? This will overwrite your current protocol settings.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_restore"), "Yes, Restore", class = "btn-warning")
        )
      ))
    })

    observeEvent(input$confirm_restore, {
      req(input$selected_snapshot)

      current_snapshots <- snapshots()
      snapshot <- Find(function(s) s$snapshot_id == input$selected_snapshot, current_snapshots)

      if (!is.null(snapshot)) {
        rv$protocol <- snapshot$protocol

        showNotification(
          paste("Protocol restored from snapshot:", snapshot$label),
          type = "message",
          duration = 5
        )
      }

      removeModal()
    })

    # Delete snapshot
    observeEvent(input$btn_delete_snapshot, {
      req(input$selected_snapshot)

      showModal(modalDialog(
        title = "Confirm Delete",
        "Are you sure you want to delete this snapshot? This action cannot be undone.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_delete"), "Yes, Delete", class = "btn-danger")
        )
      ))
    })

    observeEvent(input$confirm_delete, {
      req(input$selected_snapshot)

      tryCatch({
        # Delete from disk
        filename <- paste0("outputs/protocol_snapshots/", input$selected_snapshot, ".json")
        if (file.exists(filename)) {
          file.remove(filename)
        }

        # Remove from reactive list
        current_snapshots <- snapshots()
        current_snapshots <- Filter(function(s) s$snapshot_id != input$selected_snapshot,
                                    current_snapshots)
        snapshots(current_snapshots)

        showNotification(
          "Snapshot deleted",
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        showNotification(
          paste("Error deleting snapshot:", e$message),
          type = "error",
          duration = 10
        )
      })

      removeModal()
    })

    # Update deviation report selectors
    observe({
      current_snapshots <- snapshots()

      if (length(current_snapshots) > 0) {
        choices <- setNames(
          sapply(current_snapshots, function(s) s$snapshot_id),
          sapply(current_snapshots, function(s) paste0(s$label, " (", s$created_at, ")"))
        )

        updateSelectInput(session, "baseline_snapshot", choices = choices)

        comparison_choices <- c("Current Protocol" = "current", choices)
        updateSelectInput(session, "comparison_snapshot", choices = comparison_choices)
      }
    })

    # Generate deviation report
    observeEvent(input$btn_generate_deviation, {
      req(input$baseline_snapshot)

      tryCatch({
        # Get baseline snapshot
        current_snapshots <- snapshots()
        baseline <- Find(function(s) s$snapshot_id == input$baseline_snapshot, current_snapshots)

        if (is.null(baseline)) {
          showNotification("Baseline snapshot not found", type = "error", duration = 5)
          return()
        }

        # Get comparison (current protocol or another snapshot)
        if (input$comparison_snapshot == "current") {
          comparison_protocol <- rv$protocol
          comparison_label <- "Current Protocol"
        } else {
          comparison_snap <- Find(function(s) s$snapshot_id == input$comparison_snapshot,
                                 current_snapshots)
          if (is.null(comparison_snap)) {
            showNotification("Comparison snapshot not found", type = "error", duration = 5)
            return()
          }
          comparison_protocol <- comparison_snap$protocol
          comparison_label <- comparison_snap$label
        }

        # Generate deviation report
        report <- generate_deviation_report(
          baseline_protocol = baseline$protocol,
          baseline_label = baseline$label,
          comparison_protocol = comparison_protocol,
          comparison_label = comparison_label
        )

        deviation_report(report)

        showNotification(
          "Deviation report generated",
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        showNotification(
          paste("Error generating report:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Render deviation report output
    output$deviation_output <- renderUI({
      req(deviation_report())

      report <- deviation_report()

      tagList(
        tags$div(
          class = "alert alert-info",
          tags$h6(icon("info-circle"), " Deviation Summary"),
          tags$p(paste("Total deviations:", report$n_deviations)),
          tags$p(paste("Critical deviations:", report$n_critical)),
          tags$p(paste("Minor deviations:", report$n_minor))
        ),

        card(
          card_header("Detailed Deviation Report"),

          navset_card_tab(
            nav_panel(
              "Summary Table",
              DTOutput(ns("deviation_table"))
            ),
            nav_panel(
              "Full Comparison",
              verbatimTextOutput(ns("full_diff"))
            )
          )
        ),

        card(
          card_header("Export Deviation Report"),
          card_body(
            layout_columns(
              col_widths = c(6, 6),
              downloadButton(ns("download_deviation_csv"), "CSV Report",
                           class = "btn-primary w-100"),
              downloadButton(ns("download_deviation_docx"), "DOCX Report",
                           class = "btn-secondary w-100")
            )
          )
        )
      )
    })

    # Deviation table
    output$deviation_table <- renderDT({
      req(deviation_report())

      df <- deviation_report()$deviations_table

      datatable(
        df,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 'Bfrtip'
        ),
        rownames = FALSE,
        class = "display stripe hover"
      )
    })

    # Full diff output
    output$full_diff <- renderText({
      req(deviation_report())
      deviation_report()$full_diff_text
    })

    # Download handlers
    output$download_deviation_csv <- downloadHandler(
      filename = function() {
        paste0("protocol_deviation_report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(deviation_report())
        write.csv(deviation_report()$deviations_table, file, row.names = FALSE)
      }
    )

    output$download_deviation_docx <- downloadHandler(
      filename = function() {
        paste0("protocol_deviation_report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
      },
      content = function(file) {
        req(deviation_report())

        report_text <- c(
          "PROTOCOL DEVIATION REPORT",
          paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
          "",
          paste("Baseline:", deviation_report()$baseline_label),
          paste("Comparison:", deviation_report()$comparison_label),
          "",
          "=" %R% 60,
          "",
          "SUMMARY:",
          paste("Total deviations:", deviation_report()$n_deviations),
          paste("Critical deviations:", deviation_report()$n_critical),
          paste("Minor deviations:", deviation_report()$n_minor),
          "",
          "DETAILED DEVIATIONS:",
          "",
          capture.output(print(deviation_report()$deviations_table)),
          "",
          "FULL COMPARISON:",
          "",
          deviation_report()$full_diff_text
        )

        writeLines(report_text, file)
      }
    )

    # Return reactive values
    return(reactive({
      list(
        snapshots = snapshots(),
        deviation_report = deviation_report()
      )
    }))
  })
}

# Helper: Generate deviation report
generate_deviation_report <- function(baseline_protocol, baseline_label,
                                     comparison_protocol, comparison_label) {

  # Find differences between protocols
  deviations <- list()

  # Compare key fields
  fields_to_compare <- c("pico_population", "pico_intervention", "pico_comparison",
                        "pico_outcome", "inclusion_criteria", "exclusion_criteria",
                        "search_strategy", "databases", "date_range",
                        "study_design", "analysis_plan", "subgroups",
                        "sensitivity_analyses")

  for (field in fields_to_compare) {
    baseline_val <- baseline_protocol[[field]] %||% ""
    comparison_val <- comparison_protocol[[field]] %||% ""

    if (!identical(baseline_val, comparison_val)) {
      severity <- determine_severity(field)

      deviations[[length(deviations) + 1]] <- list(
        field = field,
        severity = severity,
        baseline = as.character(baseline_val),
        comparison = as.character(comparison_val),
        change_type = if (baseline_val == "") "Added" else if (comparison_val == "") "Removed" else "Modified"
      )
    }
  }

  # Build deviations table
  if (length(deviations) > 0) {
    deviations_df <- data.frame(
      Field = sapply(deviations, function(d) d$field),
      Severity = sapply(deviations, function(d) d$severity),
      Change_Type = sapply(deviations, function(d) d$change_type),
      Baseline = sapply(deviations, function(d) truncate_text(d$baseline, 50)),
      Comparison = sapply(deviations, function(d) truncate_text(d$comparison, 50)),
      stringsAsFactors = FALSE
    )
  } else {
    deviations_df <- data.frame(
      Message = "No deviations detected. Protocols are identical."
    )
  }

  # Generate full diff text
  full_diff <- compare_protocols_text(baseline_protocol, comparison_protocol)

  # Count deviations by severity
  n_deviations <- length(deviations)
  n_critical <- sum(sapply(deviations, function(d) d$severity == "Critical"))
  n_minor <- sum(sapply(deviations, function(d) d$severity == "Minor"))

  return(list(
    baseline_label = baseline_label,
    comparison_label = comparison_label,
    n_deviations = n_deviations,
    n_critical = n_critical,
    n_minor = n_minor,
    deviations_table = deviations_df,
    full_diff_text = full_diff
  ))
}

# Helper: Determine deviation severity
determine_severity <- function(field) {
  critical_fields <- c("pico_population", "pico_intervention", "pico_comparison",
                      "pico_outcome", "inclusion_criteria", "exclusion_criteria")

  if (field %in% critical_fields) {
    return("Critical")
  } else {
    return("Minor")
  }
}

# Helper: Truncate text
truncate_text <- function(text, max_length) {
  if (is.null(text) || text == "") return("-")
  if (nchar(text) > max_length) {
    return(paste0(substr(text, 1, max_length - 3), "..."))
  }
  return(text)
}

# Helper: Compare protocols as text
compare_protocols_text <- function(protocol1, protocol2) {
  json1 <- jsonlite::toJSON(protocol1, pretty = TRUE, auto_unbox = TRUE)
  json2 <- jsonlite::toJSON(protocol2, pretty = TRUE, auto_unbox = TRUE)

  # Simple text diff
  lines1 <- strsplit(json1, "\n")[[1]]
  lines2 <- strsplit(json2, "\n")[[1]]

  max_lines <- max(length(lines1), length(lines2))

  diff_text <- character(0)

  for (i in 1:max_lines) {
    line1 <- if (i <= length(lines1)) lines1[i] else ""
    line2 <- if (i <= length(lines2)) lines2[i] else ""

    if (line1 != line2) {
      diff_text <- c(diff_text, paste0("< ", line1), paste0("> ", line2), "")
    }
  }

  if (length(diff_text) == 0) {
    return("No differences detected.")
  }

  return(paste(diff_text, collapse = "\n"))
}

# Utility: Null coalescing operator
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (is.character(x) && x == "")) y else x
}

# Utility: String repetition
`%R%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
}
