# PRISMA Flow Diagram Module
# Generates PRISMA 2020 compliant flow diagrams for systematic reviews

library(shiny)
library(ggplot2)
library(grid)

# UI
prisma_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(4, 8),

      # Left panel: Input counts
      card(
        card_header(
          div(
            icon("diagram-project"),
            " PRISMA Flow Diagram Builder"
          )
        ),

        p(class = "text-muted",
          "Create PRISMA 2020 compliant flow diagrams for your systematic review. ",
          "Enter counts manually or auto-detect from your data."),

        hr(),

        h5("Identification"),
        numericInput(
          ns("records_identified_databases"),
          tags$span(
            "Records from databases",
            bslib::tooltip(
              icon("circle-question"),
              "Total records retrieved from electronic database searches (e.g., PubMed, Embase)"
            )
          ),
          value = 0,
          min = 0
        ),

        numericInput(
          ns("records_identified_registers"),
          "Records from registers",
          value = 0,
          min = 0
        ),

        numericInput(
          ns("records_other_sources"),
          "Records from other sources",
          value = 0,
          min = 0
        ),

        numericInput(
          ns("records_removed_duplicates"),
          tags$span(
            "Records removed (duplicates)",
            bslib::tooltip(
              icon("circle-question"),
              "Number of duplicate records removed before screening"
            )
          ),
          value = 0,
          min = 0
        ),

        hr(),
        h5("Screening"),
        numericInput(
          ns("records_screened"),
          "Records screened",
          value = 0,
          min = 0
        ),

        numericInput(
          ns("records_excluded_screening"),
          "Records excluded at screening",
          value = 0,
          min = 0
        ),

        hr(),
        h5("Eligibility"),
        numericInput(
          ns("fulltext_assessed"),
          "Full-text articles assessed",
          value = 0,
          min = 0
        ),

        numericInput(
          ns("fulltext_excluded"),
          tags$span(
            "Full-text articles excluded",
            bslib::tooltip(
              icon("circle-question"),
              "Articles excluded after full-text review. Specify reasons below."
            )
          ),
          value = 0,
          min = 0
        ),

        textAreaInput(
          ns("exclusion_reasons"),
          "Exclusion reasons (one per line)",
          placeholder = "Wrong population (n=5)\nWrong intervention (n=3)\nWrong outcome (n=2)",
          rows = 3
        ),

        hr(),
        h5("Included"),
        div(
          class = "d-flex align-items-center mb-3",
          numericInput(
            ns("studies_included_manual"),
            "Studies included (manual)",
            value = 0,
            min = 0
          ),
          tags$span(class = "mx-2", "OR"),
          actionButton(
            ns("btn_auto_count"),
            "Auto-detect from data",
            icon = icon("wand-magic-sparkles"),
            class = "btn-outline-primary"
          )
        ),

        hr(),

        actionButton(
          ns("btn_generate"),
          "Generate PRISMA Diagram",
          icon = icon("diagram-project"),
          class = "btn-primary w-100 btn-lg"
        ),

        hr(),

        h6("Export Options"),
        div(
          class = "btn-group w-100",
          downloadButton(ns("download_png"), "PNG", class = "btn-outline-secondary"),
          downloadButton(ns("download_pdf"), "PDF", class = "btn-outline-secondary"),
          downloadButton(ns("download_svg"), "SVG", class = "btn-outline-secondary")
        )
      ),

      # Right panel: PRISMA diagram
      card(
        card_header("PRISMA 2020 Flow Diagram"),
        div(
          class = "alert alert-info mb-3",
          icon("info-circle"),
          tags$small(" PRISMA 2020 compliant diagram. ",
                     tags$a(href = "http://www.prisma-statement.org/", target = "_blank",
                            "Learn more about PRISMA"))
        ),
        plotOutput(ns("prisma_plot"), height = "800px"),
        hr(),
        h6("Counts Summary"),
        verbatimTextOutput(ns("counts_summary"))
      )
    )
  )
}

# Server
prisma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    prisma_plot_obj <- reactiveVal(NULL)

    # Auto-detect study count from data
    observeEvent(input$btn_auto_count, {
      req(rv$data)

      n_studies <- if ("study_id" %in% names(rv$data)) {
        length(unique(rv$data$study_id))
      } else {
        nrow(rv$data)
      }

      updateNumericInput(session, "studies_included_manual", value = n_studies)

      showNotification(
        sprintf("✓ Detected %d studies from uploaded data", n_studies),
        type = "message",
        duration = 3
      )
    })

    # Generate PRISMA diagram
    observeEvent(input$btn_generate, {

      tryCatch({

        # Calculate totals
        total_identified <- input$records_identified_databases +
          input$records_identified_registers +
          input$records_other_sources

        records_after_duplicates <- total_identified - input$records_removed_duplicates

        # Validation
        if (total_identified == 0) {
          showNotification(
            "Please enter at least the number of records identified",
            type = "warning",
            duration = 4
          )
          return()
        }

        # Create PRISMA plot
        p <- create_prisma_plot(
          n_identified_databases = input$records_identified_databases,
          n_identified_registers = input$records_identified_registers,
          n_other_sources = input$records_other_sources,
          n_duplicates = input$records_removed_duplicates,
          n_screened = input$records_screened,
          n_excluded_screening = input$records_excluded_screening,
          n_fulltext = input$fulltext_assessed,
          n_excluded_fulltext = input$fulltext_excluded,
          exclusion_reasons = input$exclusion_reasons,
          n_included = input$studies_included_manual
        )

        prisma_plot_obj(p)

        showNotification(
          "✓ PRISMA diagram generated successfully",
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        showNotification(
          paste("Error generating diagram:", e$message),
          type = "error",
          duration = 7
        )
      })
    })

    # Render PRISMA plot
    output$prisma_plot <- renderPlot({
      req(prisma_plot_obj())
      prisma_plot_obj()
    })

    # Counts summary
    output$counts_summary <- renderPrint({
      req(input$btn_generate)

      total_identified <- input$records_identified_databases +
        input$records_identified_registers +
        input$records_other_sources

      after_duplicates <- total_identified - input$records_removed_duplicates

      cat("PRISMA Flow Summary\n")
      cat("===================\n\n")
      cat(sprintf("Total identified:          %d\n", total_identified))
      cat(sprintf("  - Databases:             %d\n", input$records_identified_databases))
      cat(sprintf("  - Registers:             %d\n", input$records_identified_registers))
      cat(sprintf("  - Other sources:         %d\n", input$records_other_sources))
      cat(sprintf("\nDuplicates removed:        %d\n", input$records_removed_duplicates))
      cat(sprintf("Records screened:          %d\n", input$records_screened))
      cat(sprintf("Excluded at screening:     %d\n", input$records_excluded_screening))
      cat(sprintf("Full-text assessed:        %d\n", input$fulltext_assessed))
      cat(sprintf("Excluded at full-text:     %d\n", input$fulltext_excluded))
      cat(sprintf("\nStudies included in MA:    %d\n", input$studies_included_manual))
      cat(sprintf("\nAttrition rate:            %.1f%%\n",
                  100 * (1 - input$studies_included_manual / total_identified)))
    })

    # Download handlers
    output$download_png <- downloadHandler(
      filename = function() {
        paste0("prisma_diagram_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(prisma_plot_obj())
        png(file, width = 3000, height = 4000, res = 300)
        print(prisma_plot_obj())
        dev.off()
      }
    )

    output$download_pdf <- downloadHandler(
      filename = function() {
        paste0("prisma_diagram_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".pdf")
      },
      content = function(file) {
        req(prisma_plot_obj())
        pdf(file, width = 10, height = 13)
        print(prisma_plot_obj())
        dev.off()
      }
    )

    output$download_svg <- downloadHandler(
      filename = function() {
        paste0("prisma_diagram_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".svg")
      },
      content = function(file) {
        req(prisma_plot_obj())
        svg(file, width = 10, height = 13)
        print(prisma_plot_obj())
        dev.off()
      }
    )

    return(reactive({
      list(
        n_included = input$studies_included_manual,
        diagram = prisma_plot_obj()
      )
    }))
  })
}

# Helper: Create PRISMA diagram using ggplot2
create_prisma_plot <- function(n_identified_databases, n_identified_registers,
                                n_other_sources, n_duplicates, n_screened,
                                n_excluded_screening, n_fulltext,
                                n_excluded_fulltext, exclusion_reasons,
                                n_included) {

  # Calculate derived values
  total_identified <- n_identified_databases + n_identified_registers + n_other_sources
  after_duplicates <- total_identified - n_duplicates

  # Create dataframe for boxes
  boxes <- data.frame(
    x = c(2, 2, 6, 2, 6, 2, 6, 2),
    y = c(10, 8.5, 8.5, 7, 7, 5, 5, 3),
    width = 2,
    height = 0.8,
    label = c(
      sprintf("Records identified from:\nDatabases (n = %d)\nRegisters (n = %d)",
              n_identified_databases, n_identified_registers),
      sprintf("Records removed before\nscreening:\nDuplicate records (n = %d)",
              n_duplicates),
      sprintf("Records identified from:\nOther sources (n = %d)",
              n_other_sources),
      sprintf("Records screened\n(n = %d)",
              n_screened),
      sprintf("Records excluded\n(n = %d)",
              n_excluded_screening),
      sprintf("Reports assessed for\neligibility\n(n = %d)",
              n_fulltext),
      sprintf("Reports excluded:\n%s\n(Total n = %d)",
              ifelse(nchar(exclusion_reasons) > 0,
                     paste(strwrap(exclusion_reasons, 30), collapse = "\n"),
                     "See reasons"),
              n_excluded_fulltext),
      sprintf("Studies included in\nmeta-analysis\n(n = %d)",
              n_included)
    ),
    section = c("Identification", "Identification", "Identification",
                "Screening", "Screening",
                "Included", "Included", "Included"),
    stringsAsFactors = FALSE
  )

  # Create arrows
  arrows <- data.frame(
    x = c(2, 2, 2, 2),
    xend = c(2, 2, 2, 2),
    y = c(9.2, 7.7, 6.2, 4.2),
    yend = c(8.9, 7.4, 5.8, 3.8),
    stringsAsFactors = FALSE
  )

  # Create plot
  p <- ggplot() +
    # Draw boxes
    geom_rect(
      data = boxes,
      aes(xmin = x - width/2, xmax = x + width/2,
          ymin = y - height/2, ymax = y + height/2),
      fill = "white",
      color = "black",
      size = 1
    ) +
    # Add text
    geom_text(
      data = boxes,
      aes(x = x, y = y, label = label),
      size = 3,
      vjust = 0.5
    ) +
    # Add arrows
    geom_segment(
      data = arrows,
      aes(x = x, xend = xend, y = y, yend = yend),
      arrow = arrow(length = unit(0.2, "cm")),
      size = 0.8
    ) +
    # Add section labels
    annotate("text", x = 0.5, y = 10, label = "Identification",
             fontface = "bold", hjust = 0, size = 4) +
    annotate("text", x = 0.5, y = 7, label = "Screening",
             fontface = "bold", hjust = 0, size = 4) +
    annotate("text", x = 0.5, y = 3, label = "Included",
             fontface = "bold", hjust = 0, size = 4) +
    # Styling
    coord_cartesian(xlim = c(0, 8), ylim = c(2, 11)) +
    theme_void() +
    labs(title = "PRISMA 2020 Flow Diagram",
         subtitle = "Preferred Reporting Items for Systematic Reviews and Meta-Analyses") +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5, margin = margin(b = 20)),
      plot.margin = unit(c(1, 1, 1, 1), "cm")
    )

  return(p)
}
