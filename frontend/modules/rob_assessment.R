# Risk of Bias Assessment Module - Interactive Point-and-Click
# Handles RoB 2.0 (RCTs) and ROBINS-I (non-randomized studies)
# with visual traffic light plots and summary charts
#
# Author: EvidenceOS PRIME

library(shiny)
library(bslib)
library(DT)

# Source publication tools
source("utils/publication_tools.R", local = TRUE)
source("utils/plot_downloads.R", local = TRUE)

rob_assessment_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(4, 8),

      # LEFT PANEL: Input Controls
      card(
        card_header(
          "Risk of Bias Assessment",
          class = "bg-primary text-white"
        ),

        # STUDY TYPE SELECTION
        selectInput(
          ns("study_type"),
          "Study Type:",
          choices = c(
            "Randomized Controlled Trials (RCTs)" = "rct",
            "Non-Randomized Studies" = "non_randomized"
          ),
          selected = "rct"
        ),

        hr(),

        # STUDY INPUT METHOD
        radioButtons(
          ns("input_method"),
          "Input Method:",
          choices = c(
            "Manual Entry" = "manual",
            "Import from Data" = "auto"
          ),
          selected = "manual"
        ),

        conditionalPanel(
          condition = "input.input_method == 'manual'",
          ns = ns,

          card(
            card_header("Add Study Assessment"),

            textInput(ns("study_id"), "Study ID:", placeholder = "Smith 2020"),

            conditionalPanel(
              condition = "input.study_type == 'rct'",
              ns = ns,
              # RoB 2.0 domains
              selectInput(ns("rob_randomization"), "1. Randomization Process:",
                         choices = c("", "Low", "Some concerns", "High")),
              selectInput(ns("rob_deviations"), "2. Deviations from Intended Interventions:",
                         choices = c("", "Low", "Some concerns", "High")),
              selectInput(ns("rob_missing"), "3. Missing Outcome Data:",
                         choices = c("", "Low", "Some concerns", "High")),
              selectInput(ns("rob_measurement"), "4. Measurement of the Outcome:",
                         choices = c("", "Low", "Some concerns", "High")),
              selectInput(ns("rob_selection"), "5. Selection of the Reported Result:",
                         choices = c("", "Low", "Some concerns", "High"))
            ),

            conditionalPanel(
              condition = "input.study_type == 'non_randomized'",
              ns = ns,
              # ROBINS-I domains
              selectInput(ns("robins_confounding"), "1. Bias due to Confounding:",
                         choices = c("", "Low", "Moderate", "Serious", "Critical", "No information")),
              selectInput(ns("robins_selection"), "2. Bias in Selection of Participants:",
                         choices = c("", "Low", "Moderate", "Serious", "Critical", "No information")),
              selectInput(ns("robins_classification"), "3. Bias in Classification of Interventions:",
                         choices = c("", "Low", "Moderate", "Serious", "Critical", "No information")),
              selectInput(ns("robins_deviations"), "4. Bias due to Deviations from Intended Interventions:",
                         choices = c("", "Low", "Moderate", "Serious", "Critical", "No information")),
              selectInput(ns("robins_missing"), "5. Bias due to Missing Data:",
                         choices = c("", "Low", "Moderate", "Serious", "Critical", "No information")),
              selectInput(ns("robins_outcome"), "6. Bias in Measurement of Outcomes:",
                         choices = c("", "Low", "Moderate", "Serious", "Critical", "No information")),
              selectInput(ns("robins_reported"), "7. Bias in Selection of the Reported Result:",
                         choices = c("", "Low", "Moderate", "Serious", "Critical", "No information"))
            ),

            actionButton(ns("btn_add_study"), "Add Study", class = "btn-success w-100")
          )
        ),

        conditionalPanel(
          condition = "input.input_method == 'auto'",
          ns = ns,
          card(
            card_header("Import from Data"),
            helpText("Automatically import RoB assessments from your uploaded data."),
            helpText("Data should have columns: study_id, rob_randomization, rob_deviations, etc."),
            actionButton(ns("btn_import"), "Import Assessments", class = "btn-primary w-100")
          )
        ),

        hr(),

        # CURRENT ASSESSMENTS
        card(
          card_header("Current Assessments"),
          DTOutput(ns("current_assessments")),
          actionButton(ns("btn_clear"), "Clear All", class = "btn-danger w-100 mt-2")
        ),

        hr(),

        # GENERATE OUTPUTS
        actionButton(
          ns("btn_generate"),
          "Generate RoB Plots",
          class = "btn-primary w-100 mb-2",
          icon = icon("chart-simple")
        ),
        actionButton(
          ns("btn_save"),
          "Save All Outputs",
          class = "btn-success w-100",
          icon = icon("download")
        )
      ),

      # RIGHT PANEL: Visualizations
      card(
        card_header("Risk of Bias Visualizations"),

        navset_card_tab(
          # TRAFFIC LIGHT PLOT
          nav_panel(
            "Traffic Light Plot",
            icon = icon("traffic-light"),
            plotOutput(ns("traffic_light_plot"), height = "600px"),
            hr(),
            plot_download_ui(
              ns("traffic_light_download"),
              plot_name = "RoB Traffic Light Plot",
              default_width = 2400,
              default_height = 2000
            )
          ),

          # SUMMARY CHART
          nav_panel(
            "Summary",
            icon = icon("chart-bar"),
            plotOutput(ns("summary_plot"), height = "500px"),
            hr(),
            plot_download_ui(
              ns("summary_download"),
              plot_name = "RoB Summary Chart",
              default_width = 2400,
              default_height = 1600
            )
          ),

          # DATA TABLE
          nav_panel(
            "Assessment Data",
            icon = icon("table"),
            downloadButton(ns("download_csv"), "Download CSV", class = "btn-success mb-3"),
            DTOutput(ns("assessment_table"))
          ),

          # INTERPRETATION
          nav_panel(
            "Interpretation",
            icon = icon("lightbulb"),
            uiOutput(ns("interpretation_ui"))
          ),

          # HELP
          nav_panel(
            "Help",
            icon = icon("circle-info"),
            card(
              card_header("Risk of Bias Assessment Guide"),

              tags$h5("RoB 2.0 (for RCTs)"),
              tags$p("Assesses 5 domains:"),
              tags$ol(
                tags$li("Randomization process"),
                tags$li("Deviations from intended interventions"),
                tags$li("Missing outcome data"),
                tags$li("Measurement of the outcome"),
                tags$li("Selection of the reported result")
              ),
              tags$p("Rating: Low risk, Some concerns, or High risk"),

              tags$hr(),

              tags$h5("ROBINS-I (for non-randomized studies)"),
              tags$p("Assesses 7 domains:"),
              tags$ol(
                tags$li("Confounding"),
                tags$li("Selection of participants"),
                tags$li("Classification of interventions"),
                tags$li("Deviations from intended interventions"),
                tags$li("Missing data"),
                tags$li("Measurement of outcomes"),
                tags$li("Selection of reported result")
              ),
              tags$p("Rating: Low, Moderate, Serious, Critical, or No information"),

              tags$hr(),

              tags$h5("References"),
              tags$ul(
                tags$li(
                  "RoB 2.0: Sterne JAC, et al. RoB 2: a revised tool for assessing risk of bias in randomised trials. ",
                  tags$em("BMJ"), " 2019;366:l4898"
                ),
                tags$li(
                  "ROBINS-I: Sterne JA, et al. ROBINS-I: a tool for assessing risk of bias in non-randomised studies of interventions. ",
                  tags$em("BMJ"), " 2016;355:i4919"
                )
              )
            )
          )
        )
      )
    )
  )
}

rob_assessment_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    assessments <- reactiveVal(data.frame())
    rob_plot_traffic <- reactiveVal(NULL)
    rob_plot_summary <- reactiveVal(NULL)

    # Add study assessment
    observeEvent(input$btn_add_study, {
      req(input$study_id)

      if (input$study_type == "rct") {
        # RoB 2.0
        req(input$rob_randomization, input$rob_deviations, input$rob_missing,
            input$rob_measurement, input$rob_selection)

        new_row <- data.frame(
          Study = input$study_id,
          Randomization = input$rob_randomization,
          Deviations = input$rob_deviations,
          Missing_Outcome = input$rob_missing,
          Outcome_Measurement = input$rob_measurement,
          Selection_Reported = input$rob_selection,
          stringsAsFactors = FALSE
        )
      } else {
        # ROBINS-I
        req(input$robins_confounding, input$robins_selection, input$robins_classification,
            input$robins_deviations, input$robins_missing, input$robins_outcome,
            input$robins_reported)

        new_row <- data.frame(
          Study = input$study_id,
          Confounding = input$robins_confounding,
          Selection = input$robins_selection,
          Classification = input$robins_classification,
          Deviations = input$robins_deviations,
          Missing_Data = input$robins_missing,
          Outcome_Measurement = input$robins_outcome,
          Selection_Reported = input$robins_reported,
          stringsAsFactors = FALSE
        )
      }

      current <- assessments()
      if (nrow(current) == 0) {
        assessments(new_row)
      } else {
        assessments(rbind(current, new_row))
      }

      # Reset study ID
      updateTextInput(session, "study_id", value = "")

      showNotification("✓ Study assessment added!", type = "message", duration = 2)
    })

    # Import from data
    observeEvent(input$btn_import, {
      req(rv$data)

      # Check for RoB columns
      if (input$study_type == "rct") {
        required_cols <- c("study_id", "rob_randomization", "rob_deviations",
                          "rob_missing", "rob_measurement", "rob_selection")
      } else {
        required_cols <- c("study_id", "robins_confounding", "robins_selection",
                          "robins_classification", "robins_deviations",
                          "robins_missing", "robins_outcome", "robins_reported")
      }

      if (!all(required_cols %in% names(rv$data))) {
        showNotification(
          "Error: Required RoB columns not found in data",
          type = "error",
          duration = 10
        )
        return()
      }

      # Import assessments
      if (input$study_type == "rct") {
        imported <- rv$data %>%
          select(study_id, rob_randomization, rob_deviations,
                rob_missing, rob_measurement, rob_selection) %>%
          distinct() %>%
          setNames(c("Study", "Randomization", "Deviations",
                    "Missing_Outcome", "Outcome_Measurement", "Selection_Reported"))
      } else {
        imported <- rv$data %>%
          select(study_id, robins_confounding, robins_selection,
                robins_classification, robins_deviations,
                robins_missing, robins_outcome, robins_reported) %>%
          distinct() %>%
          setNames(c("Study", "Confounding", "Selection", "Classification",
                    "Deviations", "Missing_Data", "Outcome_Measurement",
                    "Selection_Reported"))
      }

      assessments(imported)
      showNotification(
        paste("✓ Imported", nrow(imported), "assessments"),
        type = "message",
        duration = 3
      )
    })

    # Clear all
    observeEvent(input$btn_clear, {
      showModal(modalDialog(
        title = "Confirm Clear",
        "Are you sure you want to clear all assessments?",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("confirm_clear"), "Clear All", class = "btn-danger")
        )
      ))
    })

    observeEvent(input$confirm_clear, {
      assessments(data.frame())
      removeModal()
      showNotification("✓ All assessments cleared", type = "message", duration = 2)
    })

    # Display current assessments
    output$current_assessments <- renderDT({
      req(nrow(assessments()) > 0)

      datatable(
        assessments(),
        options = list(
          pageLength = 5,
          dom = 't',
          scrollX = TRUE
        ),
        rownames = FALSE
      )
    })

    # Generate plots
    observeEvent(input$btn_generate, {
      req(nrow(assessments()) > 0)

      withProgress(message = "Generating RoB plots...", {

        if (input$study_type == "rct") {
          # RoB 2.0 plots
          traffic_plot <- generate_rob2_plot(assessments(), style = "traffic_light")
          summary_plot <- generate_rob2_plot(assessments(), style = "summary")
        } else {
          # ROBINS-I plots
          traffic_plot <- generate_robins_i_plot(assessments())
          summary_plot <- NULL  # ROBINS-I only has traffic light
        }

        rob_plot_traffic(traffic_plot)
        rob_plot_summary(summary_plot)

        showNotification("✓ RoB plots generated!", type = "message", duration = 3)
      })
    })

    # Render traffic light plot
    output$traffic_light_plot <- renderPlot({
      req(rob_plot_traffic())
      rob_plot_traffic()
    })

    # Render summary plot
    output$summary_plot <- renderPlot({
      if (!is.null(rob_plot_summary())) {
        rob_plot_summary()
      } else {
        plot.new()
        text(0.5, 0.5, "Summary plot not available for ROBINS-I\n(only traffic light plot)",
             cex = 1.5, col = "gray50")
      }
    })

    # Assessment table
    output$assessment_table <- renderDT({
      req(nrow(assessments()) > 0)

      datatable(
        assessments(),
        options = list(
          pageLength = 20,
          scrollX = TRUE,
          dom = 'ftp'
        ),
        rownames = FALSE
      )
    })

    # Download CSV
    output$download_csv <- downloadHandler(
      filename = function() {
        type <- if (input$study_type == "rct") "RoB2" else "ROBINS-I"
        paste0(type, "_assessments_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        req(nrow(assessments()) > 0)
        write.csv(assessments(), file, row.names = FALSE)
      }
    )

    # Interpretation
    output$interpretation_ui <- renderUI({
      req(nrow(assessments()) > 0)

      data <- assessments()
      n_studies <- nrow(data)

      if (input$study_type == "rct") {
        # RoB 2.0 interpretation
        domains <- c("Randomization", "Deviations", "Missing_Outcome",
                    "Outcome_Measurement", "Selection_Reported")

        counts <- lapply(domains, function(d) {
          table(factor(data[[d]], levels = c("Low", "Some concerns", "High")))
        })

        names(counts) <- c("Randomization Process", "Deviations", "Missing Outcome Data",
                          "Outcome Measurement", "Selection of Reported Result")

        tagList(
          tags$h4("Risk of Bias Summary (RoB 2.0)"),
          tags$p(paste("Total studies assessed:", n_studies)),
          tags$hr(),

          lapply(names(counts), function(domain) {
            domain_counts <- counts[[domain]]
            low_pct <- (domain_counts["Low"] / n_studies) * 100
            some_pct <- (domain_counts["Some concerns"] / n_studies) * 100
            high_pct <- (domain_counts["High"] / n_studies) * 100

            interpretation <- if (high_pct > 30) {
              tags$span(class = "text-danger", "⚠ High risk - interpret results with caution")
            } else if (some_pct > 50) {
              tags$span(class = "text-warning", "⚠ Many concerns - consider sensitivity analysis")
            } else {
              tags$span(class = "text-success", "✓ Generally low risk")
            }

            card(
              card_header(domain),
              tags$ul(
                tags$li("Low risk:", domain_counts["Low"], sprintf("(%.1f%%)", low_pct)),
                tags$li("Some concerns:", domain_counts["Some concerns"], sprintf("(%.1f%%)", some_pct)),
                tags$li("High risk:", domain_counts["High"], sprintf("(%.1f%%)", high_pct))
              ),
              interpretation
            )
          })
        )
      } else {
        # ROBINS-I interpretation
        domains <- c("Confounding", "Selection", "Classification", "Deviations",
                    "Missing_Data", "Outcome_Measurement", "Selection_Reported")

        counts <- lapply(domains, function(d) {
          table(factor(data[[d]], levels = c("Low", "Moderate", "Serious", "Critical", "No information")))
        })

        names(counts) <- c("Confounding", "Selection", "Classification",
                          "Deviations", "Missing Data", "Outcome Measurement",
                          "Selection of Reported Result")

        tagList(
          tags$h4("Risk of Bias Summary (ROBINS-I)"),
          tags$p(paste("Total studies assessed:", n_studies)),
          tags$hr(),

          lapply(names(counts), function(domain) {
            domain_counts <- counts[[domain]]

            interpretation <- if (domain_counts["Critical"] > 0) {
              tags$span(class = "text-danger", "⚠ Critical risk - results may be unreliable")
            } else if (domain_counts["Serious"] > n_studies * 0.3) {
              tags$span(class = "text-warning", "⚠ Serious risk - downgrade certainty")
            } else {
              tags$span(class = "text-success", "✓ Acceptable risk level")
            }

            card(
              card_header(domain),
              tags$ul(
                tags$li("Low:", domain_counts["Low"]),
                tags$li("Moderate:", domain_counts["Moderate"]),
                tags$li("Serious:", domain_counts["Serious"]),
                tags$li("Critical:", domain_counts["Critical"]),
                tags$li("No information:", domain_counts["No information"])
              ),
              interpretation
            )
          })
        )
      }
    })

    # Download handlers for plots
    moduleServer("traffic_light_download", function(input_dl, output_dl, session) {
      output_dl$download <- downloadHandler(
        filename = function() {
          format <- tolower(input_dl$format)
          type <- if (input$study_type == "rct") "RoB2" else "ROBINS-I"
          timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
          paste0(type, "_traffic_light_", timestamp, ".", format)
        },
        content = function(file) {
          req(rob_plot_traffic())

          format <- tolower(input_dl$format)
          width <- if (format == "pdf") input_dl$width_pdf else input_dl$width
          height <- if (format == "pdf") input_dl$height_pdf else input_dl$height

          if (format == "png") {
            png(file, width = width, height = height, res = input_dl$dpi, type = "cairo")
          } else if (format == "jpg") {
            jpeg(file, width = width, height = height, res = input_dl$dpi,
                 quality = input_dl$quality, type = "cairo")
          } else if (format == "pdf") {
            pdf(file, width = width, height = height)
          } else if (format == "svg") {
            svg(file, width = width / 96, height = height / 96)
          }

          print(rob_plot_traffic())
          dev.off()
        }
      )
    })

    moduleServer("summary_download", function(input_dl, output_dl, session) {
      output_dl$download <- downloadHandler(
        filename = function() {
          format <- tolower(input_dl$format)
          timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
          paste0("RoB2_summary_", timestamp, ".", format)
        },
        content = function(file) {
          req(rob_plot_summary())

          format <- tolower(input_dl$format)
          width <- if (format == "pdf") input_dl$width_pdf else input_dl$width
          height <- if (format == "pdf") input_dl$height_pdf else input_dl$height

          if (format == "png") {
            png(file, width = width, height = height, res = input_dl$dpi, type = "cairo")
          } else if (format == "jpg") {
            jpeg(file, width = width, height = height, res = input_dl$dpi,
                 quality = input_dl$quality, type = "cairo")
          } else if (format == "pdf") {
            pdf(file, width = width, height = height)
          } else if (format == "svg") {
            svg(file, width = width / 96, height = height / 96)
          }

          print(rob_plot_summary())
          dev.off()
        }
      )
    })

    # Save all outputs
    observeEvent(input$btn_save, {
      req(nrow(assessments()) > 0, rob_plot_traffic())

      showModal(modalDialog(
        title = "Save Risk of Bias Outputs",
        textInput(session$ns("output_dir"), "Output Directory:", value = "RoB_outputs"),
        selectInput(session$ns("output_format"), "Format:",
                   choices = c("PNG only" = "png", "PDF only" = "pdf", "Both PNG & PDF" = "both")),
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
        if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

        type <- if (input$study_type == "rct") "RoB2" else "ROBINS-I"

        # Save traffic light plot
        if (input$output_format %in% c("png", "both")) {
          png(file.path(output_dir, paste0(type, "_traffic_light.png")),
              width = 2400, height = 2000, res = input$output_dpi, type = "cairo")
          print(rob_plot_traffic())
          dev.off()
        }

        if (input$output_format %in% c("pdf", "both")) {
          pdf(file.path(output_dir, paste0(type, "_traffic_light.pdf")),
              width = 10, height = 8)
          print(rob_plot_traffic())
          dev.off()
        }

        # Save summary plot (RoB 2.0 only)
        if (!is.null(rob_plot_summary())) {
          if (input$output_format %in% c("png", "both")) {
            png(file.path(output_dir, "RoB2_summary.png"),
                width = 2400, height = 1600, res = input$output_dpi, type = "cairo")
            print(rob_plot_summary())
            dev.off()
          }

          if (input$output_format %in% c("pdf", "both")) {
            pdf(file.path(output_dir, "RoB2_summary.pdf"), width = 10, height = 7)
            print(rob_plot_summary())
            dev.off()
          }
        }

        # Save data
        write.csv(assessments(),
                 file.path(output_dir, paste0(type, "_assessments.csv")),
                 row.names = FALSE)

        removeModal()
        showNotification(
          paste("✓ All outputs saved to:", output_dir),
          type = "message",
          duration = 5
        )
      })
    })

    return(reactive(assessments()))
  })
}
