# PRISMA Diagram Generator Module - Interactive Point-and-Click
# Allows users to create PRISMA 2020 flow diagrams and checklists
# with visual preview and export options
#
# Author: EvidenceOS PRIME
# Dependencies: shiny, bslib (loaded in app.R)
# Utilities: publication_tools.R, plot_downloads.R (sourced in app.R)

prisma_generator_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(4, 8),

      # LEFT PANEL: Input Controls
      card(
        card_header(
          "PRISMA 2020 Flow Diagram",
          class = "bg-primary text-white"
        ),

        # IDENTIFICATION
        card(
          card_header("1. Identification"),
          numericInput(
            ns("n_identified"),
            "Records identified through database searching:",
            value = 0,
            min = 0,
            step = 1
          ),
          numericInput(
            ns("n_other"),
            "Records identified through other sources:",
            value = 0,
            min = 0,
            step = 1
          ),
          tags$div(
            class = "alert alert-info",
            tags$strong("Total: "),
            textOutput(ns("total_identified"), inline = TRUE)
          )
        ),

        # SCREENING
        card(
          card_header("2. Screening"),
          numericInput(
            ns("n_duplicates"),
            "Duplicate records removed:",
            value = 0,
            min = 0,
            step = 1
          ),
          tags$div(
            class = "alert alert-success",
            tags$strong("After duplicates: "),
            textOutput(ns("after_duplicates"), inline = TRUE)
          ),
          numericInput(
            ns("n_excluded_screening"),
            "Records excluded at screening:",
            value = 0,
            min = 0,
            step = 1
          ),
          tags$div(
            class = "alert alert-success",
            tags$strong("Full-text assessed: "),
            textOutput(ns("full_text_assessed"), inline = TRUE)
          )
        ),

        # ELIGIBILITY
        card(
          card_header("3. Eligibility"),
          numericInput(
            ns("n_excluded_full_text"),
            "Full-text articles excluded:",
            value = 0,
            min = 0,
            step = 1
          ),
          textAreaInput(
            ns("exclusion_reasons"),
            "Exclusion reasons (one per line):",
            placeholder = "Wrong population: 15\nWrong intervention: 12\nWrong outcome: 8",
            rows = 3
          )
        ),

        # INCLUDED
        card(
          card_header("4. Included"),
          numericInput(
            ns("n_included"),
            "Studies included in qualitative synthesis:",
            value = 0,
            min = 0,
            step = 1
          ),
          numericInput(
            ns("n_meta_analysis"),
            "Studies included in meta-analysis:",
            value = 0,
            min = 0,
            step = 1
          )
        ),

        hr(),

        # ACTION BUTTONS
        actionButton(
          ns("btn_generate"),
          "Generate PRISMA Diagram",
          class = "btn-primary w-100 mb-2",
          icon = icon("diagram-project")
        ),
        actionButton(
          ns("btn_checklist"),
          "Generate PRISMA Checklist",
          class = "btn-secondary w-100 mb-2",
          icon = icon("list-check")
        ),
        actionButton(
          ns("btn_save"),
          "Save All Outputs",
          class = "btn-success w-100",
          icon = icon("download")
        )
      ),

      # RIGHT PANEL: Preview and Outputs
      card(
        card_header("PRISMA Outputs"),

        navset_card_tab(
          # PRISMA DIAGRAM
          nav_panel(
            "Flow Diagram",
            icon = icon("diagram-project"),
            plotOutput(ns("prisma_plot"), height = "700px"),
            hr(),
            plot_download_ui(
              ns("prisma_download"),
              plot_name = "PRISMA Flow Diagram",
              default_width = 2400,
              default_height = 2400
            )
          ),

          # PRISMA CHECKLIST
          nav_panel(
            "Checklist",
            icon = icon("list-check"),
            downloadButton(ns("download_checklist_csv"), "Download CSV", class = "btn-sm btn-success mb-3"),
            downloadButton(ns("download_checklist_html"), "Download HTML", class = "btn-sm btn-primary mb-3"),
            DTOutput(ns("checklist_table"))
          ),

          # STATISTICS
          nav_panel(
            "Statistics",
            icon = icon("chart-simple"),
            card(
              card_header("Search & Screening Statistics"),
              uiOutput(ns("statistics_summary"))
            )
          ),

          # HELP
          nav_panel(
            "Help",
            icon = icon("circle-info"),
            card(
              card_header("How to Use"),
              tags$h5("PRISMA 2020 Flow Diagram"),
              tags$p("Fill in the numbers at each stage of your systematic review:"),
              tags$ol(
                tags$li(tags$strong("Identification:"), " Total records found from all sources"),
                tags$li(tags$strong("Screening:"), " Records after removing duplicates and initial screening"),
                tags$li(tags$strong("Eligibility:"), " Full-text articles assessed and excluded"),
                tags$li(tags$strong("Included:"), " Final number of studies in review and meta-analysis")
              ),
              tags$hr(),
              tags$h5("Tips"),
              tags$ul(
                tags$li("Numbers should flow logically (e.g., excluded cannot exceed screened)"),
                tags$li("Click 'Generate' to preview the diagram"),
                tags$li("Download in PNG, PDF, or SVG format"),
                tags$li("Export the checklist to track your reporting")
              ),
              tags$hr(),
              tags$h5("Reference"),
              tags$p(
                "Page MJ, McKenzie JE, Bossuyt PM, et al. The PRISMA 2020 statement: an updated guideline for reporting systematic reviews. ",
                tags$em("BMJ"), " 2021;372:n71. ",
                tags$a(href = "https://doi.org/10.1136/bmj.n71", target = "_blank", "doi:10.1136/bmj.n71")
              )
            )
          )
        )
      )
    )
  )
}

prisma_generator_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    prisma_data_reactive <- reactiveVal(NULL)
    checklist_reactive <- reactiveVal(NULL)

    # Automatic calculations
    output$total_identified <- renderText({
      format(input$n_identified + input$n_other, big.mark = ",")
    })

    output$after_duplicates <- renderText({
      val <- input$n_identified + input$n_other - input$n_duplicates
      format(max(0, val), big.mark = ",")
    })

    output$full_text_assessed <- renderText({
      val <- input$n_identified + input$n_other - input$n_duplicates - input$n_excluded_screening
      format(max(0, val), big.mark = ",")
    })

    # Generate PRISMA diagram
    observeEvent(input$btn_generate, {
      withProgress(message = "Generating PRISMA diagram...", {

        # Parse exclusion reasons
        exclusion_reasons <- NULL
        if (nchar(trimws(input$exclusion_reasons)) > 0) {
          lines <- strsplit(input$exclusion_reasons, "\n")[[1]]
          exclusion_reasons <- list()
          for (line in lines) {
            if (grepl(":", line)) {
              parts <- strsplit(line, ":")[[1]]
              reason <- trimws(parts[1])
              count <- as.numeric(trimws(parts[2]))
              if (!is.na(count)) {
                exclusion_reasons[[reason]] <- count
              }
            }
          }
        }

        # Create PRISMA data
        prisma_data <- create_prisma_data(
          n_identified = input$n_identified,
          n_other = input$n_other,
          n_duplicates = input$n_duplicates,
          n_screened = input$n_identified + input$n_other - input$n_duplicates,
          n_excluded_screening = input$n_excluded_screening,
          n_full_text = input$n_identified + input$n_other - input$n_duplicates - input$n_excluded_screening,
          n_excluded_full_text = input$n_excluded_full_text,
          exclusion_reasons = exclusion_reasons,
          n_included = input$n_included,
          n_meta_analysis = input$n_meta_analysis
        )

        prisma_data_reactive(prisma_data)

        showNotification("✓ PRISMA diagram generated!", type = "message", duration = 3)
      })
    })

    # Generate checklist
    observeEvent(input$btn_checklist, {
      checklist <- generate_prisma_checklist()
      checklist_reactive(checklist)
      showNotification("✓ PRISMA checklist generated!", type = "message", duration = 3)
    })

    # Render PRISMA plot
    output$prisma_plot <- renderPlot({
      req(prisma_data_reactive())

      generate_prisma_diagram(prisma_data_reactive())
    })

    # Render checklist table
    output$checklist_table <- renderDT({
      req(checklist_reactive())

      datatable(
        checklist_reactive(),
        options = list(
          pageLength = 27,
          dom = 'ftp',
          scrollY = "600px",
          scrollCollapse = TRUE
        ),
        rownames = FALSE,
        editable = list(target = "cell", disable = list(columns = c(0, 1, 2, 3)))
      )
    })

    # Statistics summary
    output$statistics_summary <- renderUI({
      req(prisma_data_reactive())
      data <- prisma_data_reactive()

      screening_rate <- (data$screening$excluded_screening / data$screening$after_duplicates) * 100
      full_text_rate <- (data$eligibility$excluded_full_text / data$screening$full_text_assessed) * 100
      inclusion_rate <- (data$included$qualitative / data$screening$full_text_assessed) * 100

      tagList(
        tags$div(
          class = "row",
          tags$div(
            class = "col-md-6",
            value_box(
              title = "Total Records Identified",
              value = format(data$identification$total, big.mark = ","),
              showcase = icon("database"),
              theme = "primary"
            )
          ),
          tags$div(
            class = "col-md-6",
            value_box(
              title = "After Duplicates Removed",
              value = format(data$screening$after_duplicates, big.mark = ","),
              showcase = icon("filter"),
              theme = "info"
            )
          )
        ),

        tags$div(
          class = "row mt-3",
          tags$div(
            class = "col-md-4",
            value_box(
              title = "Screening Exclusion Rate",
              value = sprintf("%.1f%%", screening_rate),
              showcase = icon("percent"),
              theme = "warning"
            )
          ),
          tags$div(
            class = "col-md-4",
            value_box(
              title = "Full-Text Exclusion Rate",
              value = sprintf("%.1f%%", full_text_rate),
              showcase = icon("percent"),
              theme = "warning"
            )
          ),
          tags$div(
            class = "col-md-4",
            value_box(
              title = "Final Inclusion Rate",
              value = sprintf("%.1f%%", inclusion_rate),
              showcase = icon("check"),
              theme = "success"
            )
          )
        ),

        tags$div(
          class = "row mt-3",
          tags$div(
            class = "col-md-6",
            value_box(
              title = "Studies in Review",
              value = format(data$included$qualitative, big.mark = ","),
              showcase = icon("book"),
              theme = "success"
            )
          ),
          tags$div(
            class = "col-md-6",
            value_box(
              title = "Studies in Meta-Analysis",
              value = format(data$included$quantitative, big.mark = ","),
              showcase = icon("chart-line"),
              theme = "success"
            )
          )
        )
      )
    })

    # Download checklist CSV
    output$download_checklist_csv <- downloadHandler(
      filename = function() {
        paste0("PRISMA_checklist_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(checklist_reactive())
        write.csv(checklist_reactive(), file, row.names = FALSE)
      }
    )

    # Download checklist HTML
    output$download_checklist_html <- downloadHandler(
      filename = function() {
        paste0("PRISMA_checklist_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".html")
      },
      content = function(file) {
        req(checklist_reactive())

        # Create simple HTML table
        html_content <- paste0(
          "<!DOCTYPE html><html><head>",
          "<style>",
          "table { border-collapse: collapse; width: 100%; }",
          "th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }",
          "th { background-color: #4CAF50; color: white; }",
          "tr:nth-child(even) { background-color: #f2f2f2; }",
          "</style></head><body>",
          "<h1>PRISMA 2020 Checklist</h1>",
          "<table>",
          "<tr><th>Section</th><th>Item</th><th>Topic</th><th>Description</th><th>Completed</th><th>Page</th></tr>"
        )

        for (i in 1:nrow(checklist_reactive())) {
          row <- checklist_reactive()[i, ]
          html_content <- paste0(
            html_content,
            "<tr>",
            "<td>", row$Section, "</td>",
            "<td>", row$Item, "</td>",
            "<td>", row$Topic, "</td>",
            "<td>", row$Description, "</td>",
            "<td>", row$Completed, "</td>",
            "<td>", row$Page, "</td>",
            "</tr>"
          )
        }

        html_content <- paste0(html_content, "</table></body></html>")
        writeLines(html_content, file)
      }
    )

    # PRISMA plot download handler
    moduleServer("prisma_download", function(input_dl, output_dl, session) {
      output_dl$download <- downloadHandler(
        filename = function() {
          format <- tolower(input_dl$format)
          timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
          paste0("PRISMA_diagram_", timestamp, ".", format)
        },
        content = function(file) {
          req(prisma_data_reactive())

          format <- tolower(input_dl$format)

          # Get dimensions
          if (format == "pdf") {
            width <- input_dl$width_pdf
            height <- input_dl$height_pdf
          } else {
            width <- input_dl$width
            height <- input_dl$height
          }

          # Open graphics device
          if (format == "png") {
            png(file, width = width, height = height, res = input_dl$dpi, type = "cairo")
          } else if (format == "jpg") {
            jpeg(file, width = width, height = height, res = input_dl$dpi,
                 quality = input_dl$quality, type = "cairo")
          } else if (format == "pdf") {
            pdf(file, width = width, height = height, useDingbats = FALSE)
          } else if (format == "svg") {
            svg(file, width = width / 96, height = height / 96)
          }

          # Generate plot
          print(generate_prisma_diagram(prisma_data_reactive()))

          dev.off()
        }
      )
    })

    # Save all outputs
    observeEvent(input$btn_save, {
      req(prisma_data_reactive())

      showModal(modalDialog(
        title = "Save PRISMA Outputs",
        textInput(session$ns("output_dir"), "Output Directory:", value = "PRISMA_outputs"),
        selectInput(session$ns("output_format"), "Format:",
                   choices = c("PNG only" = "png",
                              "PDF only" = "pdf",
                              "Both PNG & PDF" = "both")),
        numericInput(session$ns("output_dpi"), "DPI (for PNG):", value = 300, min = 72, max = 600),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("confirm_save"), "Save", class = "btn-success")
        )
      ))
    })

    observeEvent(input$confirm_save, {
      withProgress(message = "Saving outputs...", {
        output_dir <- input$output_dir

        if (!dir.exists(output_dir)) {
          dir.create(output_dir, recursive = TRUE)
        }

        # Save diagram
        if (input$output_format %in% c("png", "both")) {
          png(file.path(output_dir, "PRISMA_diagram.png"),
              width = 2400, height = 2400, res = input$output_dpi, type = "cairo")
          print(generate_prisma_diagram(prisma_data_reactive()))
          dev.off()
        }

        if (input$output_format %in% c("pdf", "both")) {
          pdf(file.path(output_dir, "PRISMA_diagram.pdf"),
              width = 10, height = 10)
          print(generate_prisma_diagram(prisma_data_reactive()))
          dev.off()
        }

        # Save checklist if available
        if (!is.null(checklist_reactive())) {
          write.csv(checklist_reactive(),
                   file.path(output_dir, "PRISMA_checklist.csv"),
                   row.names = FALSE)
        }

        removeModal()
        showNotification(
          paste("✓ All outputs saved to:", output_dir),
          type = "message",
          duration = 5
        )
      })
    })

    return(reactive(prisma_data_reactive()))
  })
}
