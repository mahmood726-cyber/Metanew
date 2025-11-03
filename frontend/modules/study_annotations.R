# Study-Level Annotations Module
# Add, edit, and manage custom annotations for individual studies
# Supports notes, tags, flags, and quality markers

library(shiny)
library(bslib)
library(DT)
library(jsonlite)


#' UI for Study Annotations Module
#'
#' @param id Module namespace ID
#' @export
study_annotations_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("📝 Study-Level Annotations"),
    p("Add custom notes, tags, and flags to individual studies for better organization and tracking"),

    layout_columns(
      col_widths = c(7, 5),

      # Left panel: Study table with annotations
      card(
        card_header("Studies & Annotations"),
        card_body(
          # Filters
          layout_columns(
            col_widths = c(4, 4, 4),
            selectInput(ns("filter_outcome"), "Filter by Outcome:",
                       choices = NULL, multiple = TRUE),
            selectInput(ns("filter_tag"), "Filter by Tag:",
                       choices = NULL, multiple = TRUE),
            selectInput(ns("filter_flag"), "Filter by Flag:",
                       choices = c("All Studies" = "all",
                                  "Flagged Only" = "flagged",
                                  "High Quality" = "high_quality",
                                  "Requires Review" = "review",
                                  "Excluded" = "excluded"))
          ),

          # Study table
          DTOutput(ns("study_table")),

          br(),

          # Bulk actions
          layout_columns(
            col_widths = c(3, 3, 3, 3),
            actionButton(ns("bulk_tag"), "Bulk Tag", icon = icon("tags")),
            actionButton(ns("bulk_flag"), "Bulk Flag", icon = icon("flag")),
            actionButton(ns("bulk_export"), "Export Annotations", icon = icon("download")),
            actionButton(ns("bulk_delete"), "Clear Selected", icon = icon("eraser"),
                        class = "btn-warning")
          )
        )
      ),

      # Right panel: Annotation editor
      card(
        card_header("Annotation Editor"),
        card_body(
          # Study info display
          div(
            id = ns("study_info_panel"),
            style = "background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 15px;",
            h5("Selected Study:", style = "margin-top: 0;"),
            textOutput(ns("selected_study_info")),
            hr(),
            textOutput(ns("selected_study_authors")),
            textOutput(ns("selected_study_year")),
            textOutput(ns("selected_study_n"))
          ),

          # Notes section
          h5("📋 Notes:"),
          textAreaInput(ns("study_notes"), NULL,
                       rows = 4,
                       placeholder = "Add detailed notes about this study..."),

          # Tags section
          h5("🏷️ Tags:"),
          selectizeInput(ns("study_tags"), NULL,
                        choices = NULL,
                        multiple = TRUE,
                        options = list(
                          create = TRUE,
                          placeholder = "Add tags (press Enter to create new)"
                        )),

          # Quick tags
          p(style = "font-size: 0.9em; color: #666;",
            "Quick tags:"),
          div(
            style = "margin-bottom: 10px;",
            actionButton(ns("tag_high_quality"), "High Quality",
                        size = "sm", class = "btn-outline-success"),
            actionButton(ns("tag_industry_funded"), "Industry Funded",
                        size = "sm", class = "btn-outline-warning"),
            actionButton(ns("tag_high_rob"), "High RoB",
                        size = "sm", class = "btn-outline-danger"),
            actionButton(ns("tag_registry"), "Registry Trial",
                        size = "sm", class = "btn-outline-info"),
            actionButton(ns("tag_real_world"), "Real World Data",
                        size = "sm", class = "btn-outline-secondary")
          ),

          # Flags section
          h5("🚩 Flags:"),
          checkboxGroupInput(ns("study_flags"), NULL,
                           choices = c(
                             "⭐ Key Study" = "key",
                             "⚠️ Requires Review" = "review",
                             "❌ Excluded from Synthesis" = "excluded",
                             "🔍 Quality Concerns" = "quality_concern",
                             "💰 Economic Data Available" = "has_economics",
                             "📊 IPD Available" = "has_ipd",
                             "🔓 Open Access" = "open_access"
                           )),

          # Quality rating
          h5("⭐ Quality Rating:"),
          sliderInput(ns("quality_rating"), NULL,
                     min = 1, max = 5, value = 3, step = 1,
                     ticks = TRUE),
          p(style = "font-size: 0.9em; color: #666;",
            "1 = Very Low, 2 = Low, 3 = Moderate, 4 = High, 5 = Very High"),

          # Confidence in results
          h5("🎯 Confidence in Results:"),
          selectInput(ns("confidence"), NULL,
                     choices = c("Very Low" = "very_low",
                                "Low" = "low",
                                "Moderate" = "moderate",
                                "High" = "high",
                                "Very High" = "very_high")),

          # Custom fields
          h5("➕ Custom Fields:"),
          textInput(ns("custom_field_1"), "Field 1:",
                   placeholder = "e.g., Trial Registration ID"),
          textInput(ns("custom_field_2"), "Field 2:",
                   placeholder = "e.g., Funding Source"),
          textInput(ns("custom_field_3"), "Field 3:",
                   placeholder = "e.g., Contact Author"),

          # Action buttons
          hr(),
          layout_columns(
            col_widths = c(6, 6),
            actionButton(ns("save_annotation"), "Save Annotation",
                        class = "btn-primary", icon = icon("save"),
                        style = "width: 100%;"),
            actionButton(ns("clear_annotation"), "Clear Form",
                        class = "btn-secondary", icon = icon("eraser"),
                        style = "width: 100%;")
          ),

          br(),
          textOutput(ns("save_status"))
        )
      )
    ),

    # Annotation summary statistics
    hr(),
    card(
      card_header("Annotation Summary"),
      card_body(
        layout_columns(
          col_widths = c(3, 3, 3, 3),
          value_box(
            title = "Total Studies",
            value = textOutput(ns("total_studies")),
            theme = "primary",
            showcase = icon("book")
          ),
          value_box(
            title = "Annotated Studies",
            value = textOutput(ns("annotated_studies")),
            theme = "success",
            showcase = icon("check-circle")
          ),
          value_box(
            title = "Flagged Studies",
            value = textOutput(ns("flagged_studies")),
            theme = "warning",
            showcase = icon("flag")
          ),
          value_box(
            title = "Unique Tags",
            value = textOutput(ns("unique_tags")),
            theme = "info",
            showcase = icon("tags")
          )
        ),
        br(),
        h5("Tag Cloud:"),
        plotOutput(ns("tag_cloud"), height = "200px"),
        br(),
        h5("Quality Distribution:"),
        plotOutput(ns("quality_dist"), height = "250px")
      )
    )
  )
}


#' Server Logic for Study Annotations Module
#'
#' @param id Module namespace ID
#' @param rv Reactive values from parent (must contain studies data)
#' @export
study_annotations_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive to store all annotations
    annotations <- reactiveVal(list())
    selected_study_id <- reactiveVal(NULL)

    # Load annotations from disk on startup
    observeEvent(rv$studies, {
      loaded_annotations <- load_annotations_from_disk()
      annotations(loaded_annotations)

      # Update filter choices
      all_tags <- unique(unlist(lapply(loaded_annotations, function(a) a$tags)))
      updateSelectizeInput(session, "study_tags", choices = all_tags, server = TRUE)
      updateSelectInput(session, "filter_tag", choices = all_tags)
    })


    # Render study table
    output$study_table <- renderDT({
      req(rv$studies)

      # Build study dataframe
      study_df <- rv$studies
      annot <- annotations()

      # Add annotation columns
      study_df$Notes <- sapply(study_df$study_id, function(id) {
        if (!is.null(annot[[id]]) && !is.null(annot[[id]]$notes)) {
          substr(annot[[id]]$notes, 1, 50)  # Truncate for display
        } else {
          ""
        }
      })

      study_df$Tags <- sapply(study_df$study_id, function(id) {
        if (!is.null(annot[[id]]) && length(annot[[id]]$tags) > 0) {
          paste(annot[[id]]$tags, collapse = ", ")
        } else {
          ""
        }
      })

      study_df$Flags <- sapply(study_df$study_id, function(id) {
        if (!is.null(annot[[id]]) && length(annot[[id]]$flags) > 0) {
          paste(length(annot[[id]]$flags), "flags")
        } else {
          ""
        }
      })

      study_df$Quality <- sapply(study_df$study_id, function(id) {
        if (!is.null(annot[[id]]) && !is.null(annot[[id]]$quality_rating)) {
          paste0("⭐", annot[[id]]$quality_rating, "/5")
        } else {
          ""
        }
      })

      # Apply filters
      if (!is.null(input$filter_tag) && length(input$filter_tag) > 0) {
        study_df <- study_df[sapply(study_df$study_id, function(id) {
          if (is.null(annot[[id]])) return(FALSE)
          any(input$filter_tag %in% annot[[id]]$tags)
        }), ]
      }

      if (input$filter_flag != "all") {
        study_df <- study_df[sapply(study_df$study_id, function(id) {
          if (is.null(annot[[id]])) return(FALSE)
          switch(input$filter_flag,
                flagged = length(annot[[id]]$flags) > 0,
                high_quality = !is.null(annot[[id]]$quality_rating) && annot[[id]]$quality_rating >= 4,
                review = "review" %in% annot[[id]]$flags,
                excluded = "excluded" %in% annot[[id]]$flags,
                TRUE)
        }), ]
      }

      datatable(
        study_df,
        selection = "single",
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          columnDefs = list(
            list(width = "150px", targets = which(names(study_df) == "Notes")),
            list(width = "120px", targets = which(names(study_df) == "Tags"))
          )
        ),
        rownames = FALSE
      )
    })


    # Load annotation into editor when study selected
    observeEvent(input$study_table_rows_selected, {
      req(input$study_table_rows_selected)
      req(rv$studies)

      row_idx <- input$study_table_rows_selected
      study_id <- rv$studies$study_id[row_idx]
      selected_study_id(study_id)

      # Load annotation if exists
      annot <- annotations()
      if (!is.null(annot[[study_id]])) {
        study_annot <- annot[[study_id]]

        updateTextAreaInput(session, "study_notes", value = study_annot$notes %||% "")
        updateSelectizeInput(session, "study_tags", selected = study_annot$tags %||% character(0))
        updateCheckboxGroupInput(session, "study_flags", selected = study_annot$flags %||% character(0))
        updateSliderInput(session, "quality_rating", value = study_annot$quality_rating %||% 3)
        updateSelectInput(session, "confidence", selected = study_annot$confidence %||% "moderate")
        updateTextInput(session, "custom_field_1", value = study_annot$custom_field_1 %||% "")
        updateTextInput(session, "custom_field_2", value = study_annot$custom_field_2 %||% "")
        updateTextInput(session, "custom_field_3", value = study_annot$custom_field_3 %||% "")
      } else {
        # Clear form for new annotation
        updateTextAreaInput(session, "study_notes", value = "")
        updateSelectizeInput(session, "study_tags", selected = character(0))
        updateCheckboxGroupInput(session, "study_flags", selected = character(0))
        updateSliderInput(session, "quality_rating", value = 3)
        updateSelectInput(session, "confidence", selected = "moderate")
        updateTextInput(session, "custom_field_1", value = "")
        updateTextInput(session, "custom_field_2", value = "")
        updateTextInput(session, "custom_field_3", value = "")
      }
    })


    # Display selected study info
    output$selected_study_info <- renderText({
      req(selected_study_id())
      req(rv$studies)

      study <- rv$studies[rv$studies$study_id == selected_study_id(), ]
      if (nrow(study) == 0) return("No study selected")

      paste("Study ID:", study$study_id[1])
    })

    output$selected_study_authors <- renderText({
      req(selected_study_id())
      req(rv$studies)

      study <- rv$studies[rv$studies$study_id == selected_study_id(), ]
      if (nrow(study) == 0 || is.null(study$author)) return("")

      paste("Authors:", study$author[1])
    })

    output$selected_study_year <- renderText({
      req(selected_study_id())
      req(rv$studies)

      study <- rv$studies[rv$studies$study_id == selected_study_id(), ]
      if (nrow(study) == 0 || is.null(study$year)) return("")

      paste("Year:", study$year[1])
    })

    output$selected_study_n <- renderText({
      req(selected_study_id())
      req(rv$studies)

      study <- rv$studies[rv$studies$study_id == selected_study_id(), ]
      if (nrow(study) == 0 || is.null(study$n1) || is.null(study$n2)) return("")

      paste("Sample Size:", study$n1[1] + study$n2[1])
    })


    # Quick tag buttons
    observeEvent(input$tag_high_quality, {
      current_tags <- input$study_tags
      if (!"High Quality" %in% current_tags) {
        updateSelectizeInput(session, "study_tags",
                           selected = c(current_tags, "High Quality"))
      }
    })

    observeEvent(input$tag_industry_funded, {
      current_tags <- input$study_tags
      if (!"Industry Funded" %in% current_tags) {
        updateSelectizeInput(session, "study_tags",
                           selected = c(current_tags, "Industry Funded"))
      }
    })

    observeEvent(input$tag_high_rob, {
      current_tags <- input$study_tags
      if (!"High RoB" %in% current_tags) {
        updateSelectizeInput(session, "study_tags",
                           selected = c(current_tags, "High RoB"))
      }
    })

    observeEvent(input$tag_registry, {
      current_tags <- input$study_tags
      if (!"Registry Trial" %in% current_tags) {
        updateSelectizeInput(session, "study_tags",
                           selected = c(current_tags, "Registry Trial"))
      }
    })

    observeEvent(input$tag_real_world, {
      current_tags <- input$study_tags
      if (!"Real World Data" %in% current_tags) {
        updateSelectizeInput(session, "study_tags",
                           selected = c(current_tags, "Real World Data"))
      }
    })


    # Save annotation
    observeEvent(input$save_annotation, {
      req(selected_study_id())

      # Create annotation object
      new_annotation <- list(
        study_id = selected_study_id(),
        notes = input$study_notes,
        tags = input$study_tags,
        flags = input$study_flags,
        quality_rating = input$quality_rating,
        confidence = input$confidence,
        custom_field_1 = input$custom_field_1,
        custom_field_2 = input$custom_field_2,
        custom_field_3 = input$custom_field_3,
        created_date = Sys.time(),
        modified_date = Sys.time()
      )

      # Update annotations
      current_annotations <- annotations()
      current_annotations[[selected_study_id()]] <- new_annotation
      annotations(current_annotations)

      # Save to disk
      save_annotations_to_disk(current_annotations)

      # Update tag choices
      all_tags <- unique(unlist(lapply(current_annotations, function(a) a$tags)))
      updateSelectizeInput(session, "study_tags", choices = all_tags, server = TRUE)
      updateSelectInput(session, "filter_tag", choices = all_tags)

      output$save_status <- renderText({
        paste("✓ Annotation saved at", format(Sys.time(), "%H:%M:%S"))
      })

      showNotification("Annotation saved successfully!", type = "message")
    })


    # Clear form
    observeEvent(input$clear_annotation, {
      updateTextAreaInput(session, "study_notes", value = "")
      updateSelectizeInput(session, "study_tags", selected = character(0))
      updateCheckboxGroupInput(session, "study_flags", selected = character(0))
      updateSliderInput(session, "quality_rating", value = 3)
      updateSelectInput(session, "confidence", selected = "moderate")
      updateTextInput(session, "custom_field_1", value = "")
      updateTextInput(session, "custom_field_2", value = "")
      updateTextInput(session, "custom_field_3", value = "")

      output$save_status <- renderText("")
    })


    # Summary statistics
    output$total_studies <- renderText({
      req(rv$studies)
      nrow(rv$studies)
    })

    output$annotated_studies <- renderText({
      length(annotations())
    })

    output$flagged_studies <- renderText({
      annot <- annotations()
      sum(sapply(annot, function(a) length(a$flags) > 0))
    })

    output$unique_tags <- renderText({
      annot <- annotations()
      all_tags <- unique(unlist(lapply(annot, function(a) a$tags)))
      length(all_tags)
    })


    # Tag cloud
    output$tag_cloud <- renderPlot({
      annot <- annotations()

      if (length(annot) == 0) {
        plot.new()
        text(0.5, 0.5, "No annotations yet")
        return()
      }

      all_tags <- unlist(lapply(annot, function(a) a$tags))
      if (length(all_tags) == 0) {
        plot.new()
        text(0.5, 0.5, "No tags yet")
        return()
      }

      tag_freq <- table(all_tags)
      tag_freq <- sort(tag_freq, decreasing = TRUE)

      # Simple bar plot (wordcloud2 would be better but requires additional package)
      par(mar = c(8, 4, 2, 1))
      barplot(head(tag_freq, 10),
             las = 2,
             col = "skyblue",
             border = NA,
             main = "Top 10 Most Used Tags",
             ylab = "Frequency")
    })


    # Quality distribution
    output$quality_dist <- renderPlot({
      annot <- annotations()

      if (length(annot) == 0) {
        plot.new()
        text(0.5, 0.5, "No quality ratings yet")
        return()
      }

      quality_ratings <- sapply(annot, function(a) a$quality_rating %||% NA)
      quality_ratings <- quality_ratings[!is.na(quality_ratings)]

      if (length(quality_ratings) == 0) {
        plot.new()
        text(0.5, 0.5, "No quality ratings yet")
        return()
      }

      quality_table <- table(factor(quality_ratings, levels = 1:5))

      barplot(quality_table,
             col = c("#d32f2f", "#f57c00", "#fbc02d", "#7cb342", "#388e3c"),
             border = NA,
             main = "Quality Rating Distribution",
             xlab = "Quality Rating",
             ylab = "Number of Studies",
             names.arg = c("1\nVery Low", "2\nLow", "3\nModerate", "4\nHigh", "5\nVery High"))
    })


    # Bulk export
    observeEvent(input$bulk_export, {
      annot <- annotations()

      if (length(annot) == 0) {
        showNotification("No annotations to export", type = "warning")
        return()
      }

      export_file <- file.path("outputs", paste0("annotations_export_", Sys.Date(), ".json"))
      jsonlite::write_json(annot, export_file, pretty = TRUE, auto_unbox = TRUE)

      showNotification(paste("Annotations exported to:", export_file), type = "message")
    })

  })
}


# ============================================================================
# Helper Functions
# ============================================================================

#' Load Annotations from Disk
#'
#' @return List of annotations
#' @keywords internal
load_annotations_from_disk <- function() {
  annotations_file <- "outputs/annotations/study_annotations.json"

  if (file.exists(annotations_file)) {
    tryCatch({
      jsonlite::read_json(annotations_file, simplifyVector = FALSE)
    }, error = function(e) {
      message("Error loading annotations:", e$message)
      list()
    })
  } else {
    list()
  }
}


#' Save Annotations to Disk
#'
#' @param annotations List of annotations
#' @keywords internal
save_annotations_to_disk <- function(annotations) {
  annotations_dir <- "outputs/annotations"
  dir.create(annotations_dir, showWarnings = FALSE, recursive = TRUE)

  annotations_file <- file.path(annotations_dir, "study_annotations.json")
  jsonlite::write_json(annotations, annotations_file, pretty = TRUE, auto_unbox = TRUE)
}


#' Null coalescing operator
#'
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}
