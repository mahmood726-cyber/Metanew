# Protocol Module - Enhanced with PRISMA 2020
library(shiny)
library(bslib)
library(DT)

protocol_ui <- function(id) {
  ns <- NS(id)

  layout_columns(
    col_widths = c(12),

    # Protocol Status Card
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex justify-content-between align-items-center",
        div(
          icon("file-text", class = "me-2"),
          "Research Protocol (PICO + PRISMA 2020)"
        ),
        div(
          uiOutput(ns("protocol_status_badge")),
          actionButton(ns("btn_lock"), "Lock Protocol", class = "btn-sm btn-warning ms-2"),
          actionButton(ns("btn_unlock"), "Unlock", class = "btn-sm btn-secondary ms-1")
        )
      ),
      navset_card_tab(
        id = ns("protocol_tabs"),

        # Tab 1: PICO Entry
        nav_panel(
          title = "PICO",
          icon = icon("clipboard-list"),
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("Population, Intervention, Comparator, Outcome"),
              textInput(ns("title"), "Protocol Title", placeholder = "e.g., Efficacy of Drug X vs Placebo in Type 2 Diabetes"),
              textInput(ns("version_label"), "Version", value = "1.0", placeholder = "1.0"),
              textAreaInput(ns("population"), "Population", rows = 3,
                            placeholder = "e.g., Adults ≥18 years with Type 2 Diabetes, HbA1c ≥7.5%"),
              textAreaInput(ns("intervention"), "Intervention", rows = 3,
                            placeholder = "e.g., Drug X 10mg once daily"),
              textAreaInput(ns("comparator"), "Comparator", rows = 3,
                            placeholder = "e.g., Placebo or standard care"),
              textAreaInput(ns("outcomes"), "Outcomes (comma-separated)", rows = 2,
                            placeholder = "e.g., HbA1c reduction, all-cause mortality, hypoglycemia")
            ),
            card(
              card_header("Inclusion/Exclusion Criteria"),
              textAreaInput(ns("inclusion"), "Inclusion Criteria (one per line)", rows = 5,
                            placeholder = "- Randomized controlled trials\n- Adults ≥18 years\n- Published 2010-2024"),
              textAreaInput(ns("exclusion"), "Exclusion Criteria (one per line)", rows = 5,
                            placeholder = "- Case reports\n- Non-English language\n- Pediatric populations"),
              actionButton(ns("btn_save"), "Save Protocol", class = "btn-primary w-100 mt-2")
            )
          )
        ),

        # Tab 2: PRISMA 2020 Checklist
        nav_panel(
          title = "PRISMA Checklist",
          icon = icon("tasks"),
          card(
            card_header("PRISMA 2020 Checklist - 27 Items"),
            p(class = "text-muted mb-3",
              "Track compliance with PRISMA 2020 reporting standards. Check items as you complete them."),
            uiOutput(ns("prisma_progress")),
            DTOutput(ns("prisma_table")),
            actionButton(ns("btn_save_prisma"), "Save Progress", class = "btn-success mt-2")
          )
        ),

        # Tab 3: Deviations Log
        nav_panel(
          title = "Deviations",
          icon = icon("exclamation-triangle"),
          card(
            card_header("Protocol Deviations Log"),
            p(class = "text-muted",
              "Document any deviations from the registered protocol with justification."),
            layout_columns(
              col_widths = c(8, 4),
              card(
                textInput(ns("dev_description"), "Deviation Description",
                          placeholder = "e.g., Changed exclusion criteria to include non-English studies"),
                textAreaInput(ns("dev_justification"), "Justification", rows = 3,
                              placeholder = "e.g., Too few English-only studies; all non-English abstracts had English translations"),
                dateInput(ns("dev_date"), "Date of Deviation", value = Sys.Date())
              ),
              card(
                actionButton(ns("btn_add_deviation"), "Add Deviation",
                             class = "btn-warning w-100 mb-2"),
                actionButton(ns("btn_clear_deviations"), "Clear All",
                             class = "btn-outline-secondary w-100")
              )
            ),
            hr(),
            DTOutput(ns("deviations_table"))
          )
        ),

        # Tab 4: PRISMA Flow Diagram
        nav_panel(
          title = "Flow Diagram",
          icon = icon("project-diagram"),
          card(
            card_header("PRISMA 2020 Flow Diagram Generator"),
            p(class = "text-muted mb-3",
              "Enter counts at each stage of your systematic review process."),
            layout_columns(
              col_widths = c(6, 6),
              card(
                card_header("Identification"),
                numericInput(ns("flow_databases"), "Records identified from databases", value = 0, min = 0),
                numericInput(ns("flow_registers"), "Records from registers", value = 0, min = 0),
                numericInput(ns("flow_other"), "Records from other sources", value = 0, min = 0),
                numericInput(ns("flow_duplicates"), "Duplicate records removed", value = 0, min = 0)
              ),
              card(
                card_header("Screening & Inclusion"),
                numericInput(ns("flow_screened"), "Records screened", value = 0, min = 0),
                numericInput(ns("flow_excluded_screen"), "Excluded at screening", value = 0, min = 0),
                numericInput(ns("flow_sought"), "Reports sought for retrieval", value = 0, min = 0),
                numericInput(ns("flow_not_retrieved"), "Reports not retrieved", value = 0, min = 0),
                numericInput(ns("flow_assessed"), "Reports assessed for eligibility", value = 0, min = 0),
                numericInput(ns("flow_excluded_full"), "Excluded at full-text", value = 0, min = 0),
                numericInput(ns("flow_included"), "Studies included in review", value = 0, min = 0)
              )
            ),
            hr(),
            actionButton(ns("btn_generate_flow"), "Generate Flow Diagram",
                         class = "btn-primary", icon = icon("magic")),
            downloadButton(ns("btn_download_flow"), "Download PNG",
                           class = "btn-secondary ms-2"),
            hr(),
            plotOutput(ns("flow_diagram_plot"), height = "600px")
          )
        )
      )
    )
  )
}

protocol_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values for protocol state
    protocol_locked <- reactiveVal(FALSE)
    prisma_checklist <- reactiveVal(create_prisma_checklist())
    deviations <- reactiveVal(data.frame(
      Date = character(),
      Description = character(),
      Justification = character(),
      stringsAsFactors = FALSE
    ))

    # Protocol status badge
    output$protocol_status_badge <- renderUI({
      if (protocol_locked()) {
        span(class = "badge bg-danger", icon("lock"), " Locked")
      } else {
        span(class = "badge bg-success", icon("unlock"), " Unlocked")
      }
    })

    # Save protocol (PICO)
    observeEvent(input$btn_save, {
      if (protocol_locked()) {
        showNotification("⚠ Protocol is locked. Unlock to make changes.",
                         type = "warning", duration = 3)
        return()
      }

      protocol <- list(
        protocol_id = paste0("PROT_", format(Sys.time(), "%Y%m%d_%H%M%S")),
        title = input$title,
        version = input$version_label,
        population = input$population,
        intervention = input$intervention,
        comparator = input$comparator,
        outcomes = strsplit(input$outcomes, ",")[[1]],
        inclusion_criteria = strsplit(input$inclusion, "\n")[[1]],
        exclusion_criteria = strsplit(input$exclusion, "\n")[[1]],
        created_at = Sys.time(),
        locked = protocol_locked(),
        prisma_checklist = prisma_checklist(),
        deviations = deviations()
      )

      rv$protocol <- protocol
      showNotification("✓ Protocol saved", type = "message", duration = 3)
    })

    # Lock protocol
    observeEvent(input$btn_lock, {
      showModal(modalDialog(
        title = "Lock Protocol",
        "Are you sure you want to lock this protocol? This should be done before data extraction begins. You can unlock it later to log deviations.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_lock"), "Lock Protocol", class = "btn-warning")
        )
      ))
    })

    observeEvent(input$confirm_lock, {
      protocol_locked(TRUE)
      removeModal()
      showNotification("✓ Protocol locked", type = "warning", duration = 3)

      # Update rv if protocol exists
      if (!is.null(rv$protocol)) {
        rv$protocol$locked <- TRUE
        rv$protocol$locked_at <- Sys.time()
      }
    })

    # Unlock protocol
    observeEvent(input$btn_unlock, {
      if (!protocol_locked()) {
        showNotification("Protocol is already unlocked", type = "message", duration = 2)
        return()
      }

      showModal(modalDialog(
        title = "Unlock Protocol",
        "Unlocking the protocol after locking should be documented as a deviation if data extraction has begun.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_unlock"), "Unlock", class = "btn-secondary")
        )
      ))
    })

    observeEvent(input$confirm_unlock, {
      protocol_locked(FALSE)
      removeModal()
      showNotification("✓ Protocol unlocked. Please document reason in Deviations tab if needed.",
                       type = "message", duration = 5)

      if (!is.null(rv$protocol)) {
        rv$protocol$locked <- FALSE
      }
    })

    # PRISMA Checklist
    output$prisma_table <- renderDT({
      df <- prisma_checklist()

      datatable(
        df,
        selection = 'none',
        editable = list(target = "cell", disable = list(columns = c(0, 1, 2))),
        options = list(
          pageLength = 27,
          dom = 't',
          columnDefs = list(
            list(width = '5%', targets = 0),
            list(width = '15%', targets = 1),
            list(width = '50%', targets = 2),
            list(width = '10%', targets = 3),
            list(width = '20%', targets = 4)
          )
        ),
        rownames = FALSE
      ) %>%
        formatStyle('Status', backgroundColor = styleEqual(
          c('Complete', 'Partial', 'Not Started'),
          c('#d4edda', '#fff3cd', '#f8d7da')
        ))
    })

    # Handle PRISMA table edits
    observeEvent(input$prisma_table_cell_edit, {
      info <- input$prisma_table_cell_edit
      df <- prisma_checklist()

      # Update the edited cell
      df[info$row, info$col] <- info$value

      prisma_checklist(df)
      showNotification("✓ Checklist updated", type = "message", duration = 2)
    })

    # PRISMA progress bar
    output$prisma_progress <- renderUI({
      df <- prisma_checklist()
      n_complete <- sum(df$Status == "Complete")
      n_total <- nrow(df)
      pct <- round(100 * n_complete / n_total)

      div(
        class = "mb-3",
        h5(paste0("Progress: ", n_complete, "/", n_total, " items (", pct, "%)")),
        tags$div(
          class = "progress",
          style = "height: 25px;",
          tags$div(
            class = "progress-bar bg-success",
            role = "progressbar",
            style = paste0("width: ", pct, "%"),
            `aria-valuenow` = pct,
            `aria-valuemin` = "0",
            `aria-valuemax` = "100",
            paste0(pct, "%")
          )
        )
      )
    })

    # Save PRISMA progress
    observeEvent(input$btn_save_prisma, {
      if (!is.null(rv$protocol)) {
        rv$protocol$prisma_checklist <- prisma_checklist()
        rv$protocol$prisma_updated_at <- Sys.time()
      }
      showNotification("✓ PRISMA checklist progress saved", type = "message", duration = 3)
    })

    # Add deviation
    observeEvent(input$btn_add_deviation, {
      if (input$dev_description == "") {
        showNotification("⚠ Please enter a deviation description",
                         type = "warning", duration = 3)
        return()
      }

      new_deviation <- data.frame(
        Date = as.character(input$dev_date),
        Description = input$dev_description,
        Justification = input$dev_justification,
        stringsAsFactors = FALSE
      )

      current_devs <- deviations()
      updated_devs <- rbind(current_devs, new_deviation)
      deviations(updated_devs)

      # Clear inputs
      updateTextInput(session, "dev_description", value = "")
      updateTextAreaInput(session, "dev_justification", value = "")

      showNotification("✓ Deviation logged", type = "warning", duration = 3)

      # Save to rv
      if (!is.null(rv$protocol)) {
        rv$protocol$deviations <- updated_devs
      }
    })

    # Clear deviations
    observeEvent(input$btn_clear_deviations, {
      showModal(modalDialog(
        title = "Clear All Deviations",
        "Are you sure you want to clear all deviations? This cannot be undone.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_clear_devs"), "Clear All", class = "btn-danger")
        )
      ))
    })

    observeEvent(input$confirm_clear_devs, {
      deviations(data.frame(
        Date = character(),
        Description = character(),
        Justification = character(),
        stringsAsFactors = FALSE
      ))
      removeModal()
      showNotification("✓ All deviations cleared", type = "message", duration = 3)
    })

    # Deviations table
    output$deviations_table <- renderDT({
      datatable(
        deviations(),
        options = list(pageLength = 10, dom = 'tp'),
        rownames = FALSE
      )
    })

    # Generate PRISMA flow diagram
    flow_diagram_plot <- reactiveVal(NULL)

    observeEvent(input$btn_generate_flow, {
      req(input$flow_included)

      # BUG FIX #4: Validate inputs before generating diagram
      total_identified <- input$flow_databases + input$flow_registers + input$flow_other

      if (total_identified == 0) {
        showNotification(
          "⚠ Please enter at least one record in the identification phase",
          type = "warning",
          duration = 5
        )
        return()
      }

      if (input$flow_included == 0) {
        showNotification(
          "⚠ Please enter the number of studies included in the review",
          type = "warning",
          duration = 5
        )
        return()
      }

      plot_obj <- create_prisma_flow_diagram(
        databases = input$flow_databases,
        registers = input$flow_registers,
        other = input$flow_other,
        duplicates = input$flow_duplicates,
        screened = input$flow_screened,
        excluded_screen = input$flow_excluded_screen,
        sought = input$flow_sought,
        not_retrieved = input$flow_not_retrieved,
        assessed = input$flow_assessed,
        excluded_full = input$flow_excluded_full,
        included = input$flow_included
      )

      flow_diagram_plot(plot_obj)
      showNotification("✓ Flow diagram generated", type = "message", duration = 3)
    })

    output$flow_diagram_plot <- renderPlot({
      req(flow_diagram_plot())
      flow_diagram_plot()
    })

    # Download flow diagram
    output$btn_download_flow <- downloadHandler(
      filename = function() {
        paste0("prisma_flow_", format(Sys.Time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(flow_diagram_plot())
        ggsave(file, flow_diagram_plot(), width = 10, height = 12, dpi = 300)
      }
    )

    return(reactive(rv$protocol))
  })
}

# Helper function to create PRISMA 2020 checklist
create_prisma_checklist <- function() {
  data.frame(
    Item = c(1:27),
    Section = c(
      "Title", "Abstract", "Introduction", "Introduction", "Methods", "Methods",
      "Methods", "Methods", "Methods", "Methods", "Methods", "Methods",
      "Methods", "Methods", "Methods", "Results", "Results", "Results",
      "Results", "Results", "Results", "Results", "Results", "Discussion",
      "Discussion", "Discussion", "Other"
    ),
    Description = c(
      "Identify the report as a systematic review",
      "See the PRISMA 2020 for Abstracts checklist",
      "Describe the rationale for the review",
      "Provide objectives and questions (PICO)",
      "Eligibility criteria",
      "Information sources",
      "Search strategy",
      "Selection process",
      "Data collection process",
      "Data items",
      "Study risk of bias assessment",
      "Effect measures",
      "Synthesis methods",
      "Reporting bias assessment",
      "Certainty assessment",
      "Study selection (flow diagram)",
      "Study characteristics",
      "Risk of bias in studies",
      "Results of individual studies",
      "Results of syntheses",
      "Reporting biases",
      "Certainty of evidence",
      "Additional analyses",
      "General interpretation",
      "Limitations",
      "Implications",
      "Registration and protocol"
    ),
    Status = rep("Not Started", 27),
    Notes = rep("", 27),
    stringsAsFactors = FALSE
  )
}

# Helper function to create PRISMA flow diagram
create_prisma_flow_diagram <- function(databases, registers, other, duplicates,
                                        screened, excluded_screen, sought, not_retrieved,
                                        assessed, excluded_full, included) {
  library(ggplot2)
  library(grid)

  # Calculate derived values
  total_identified <- databases + registers + other
  after_duplicates <- total_identified - duplicates

  # Create a simple flow diagram using ggplot2
  p <- ggplot() +
    theme_void() +
    xlim(0, 10) +
    ylim(0, 14) +

    # Identification section
    annotate("rect", xmin = 2, xmax = 8, ymin = 12.5, ymax = 13.5,
             fill = "#e3f2fd", color = "black", size = 1) +
    annotate("text", x = 5, y = 13,
             label = sprintf("Records identified from:\nDatabases (n=%d)\nRegisters (n=%d)\nOther (n=%d)\nTotal: n=%d",
                             databases, registers, other, total_identified),
             size = 3.5, fontface = "bold") +

    # Duplicates removed
    annotate("rect", xmin = 2, xmax = 8, ymin = 11, ymax = 12,
             fill = "#fff3cd", color = "black", size = 1) +
    annotate("text", x = 5, y = 11.5,
             label = sprintf("Records after duplicates removed\n(n=%d)", after_duplicates),
             size = 3.5) +

    # Screening
    annotate("rect", xmin = 2, xmax = 8, ymin = 9.5, ymax = 10.5,
             fill = "#e3f2fd", color = "black", size = 1) +
    annotate("text", x = 5, y = 10,
             label = sprintf("Records screened\n(n=%d)", screened),
             size = 3.5, fontface = "bold") +

    annotate("rect", xmin = 8.5, xmax = 9.5, ymin = 9.5, ymax = 10.5,
             fill = "#f8d7da", color = "black") +
    annotate("text", x = 9, y = 10,
             label = sprintf("Excluded\n(n=%d)", excluded_screen),
             size = 2.5) +

    # Retrieval
    annotate("rect", xmin = 2, xmax = 8, ymin = 8, ymax = 9,
             fill = "#fff3cd", color = "black", size = 1) +
    annotate("text", x = 5, y = 8.5,
             label = sprintf("Reports sought for retrieval\n(n=%d)", sought),
             size = 3.5) +

    annotate("rect", xmin = 8.5, xmax = 9.5, ymin = 8, ymax = 9,
             fill = "#f8d7da", color = "black") +
    annotate("text", x = 9, y = 8.5,
             label = sprintf("Not retrieved\n(n=%d)", not_retrieved),
             size = 2.5) +

    # Eligibility
    annotate("rect", xmin = 2, xmax = 8, ymin = 6.5, ymax = 7.5,
             fill = "#e3f2fd", color = "black", size = 1) +
    annotate("text", x = 5, y = 7,
             label = sprintf("Reports assessed for eligibility\n(n=%d)", assessed),
             size = 3.5, fontface = "bold") +

    annotate("rect", xmin = 8.5, xmax = 9.5, ymin = 6.5, ymax = 7.5,
             fill = "#f8d7da", color = "black") +
    annotate("text", x = 9, y = 7,
             label = sprintf("Excluded\n(n=%d)", excluded_full),
             size = 2.5) +

    # Included
    annotate("rect", xmin = 2, xmax = 8, ymin = 5, ymax = 6,
             fill = "#d4edda", color = "black", size = 1.5) +
    annotate("text", x = 5, y = 5.5,
             label = sprintf("Studies included in review\n(n=%d)", included),
             size = 4, fontface = "bold") +

    # Section headers
    annotate("text", x = 0.5, y = 13, label = "Identification",
             angle = 90, size = 4, fontface = "bold") +
    annotate("text", x = 0.5, y = 10, label = "Screening",
             angle = 90, size = 4, fontface = "bold") +
    annotate("text", x = 0.5, y = 7, label = "Included",
             angle = 90, size = 4, fontface = "bold") +

    # Arrows
    annotate("segment", x = 5, xend = 5, y = 12.5, yend = 12,
             arrow = arrow(length = unit(0.3, "cm")), size = 1) +
    annotate("segment", x = 5, xend = 5, y = 11, yend = 10.5,
             arrow = arrow(length = unit(0.3, "cm")), size = 1) +
    annotate("segment", x = 5, xend = 5, y = 9.5, yend = 9,
             arrow = arrow(length = unit(0.3, "cm")), size = 1) +
    annotate("segment", x = 5, xend = 5, y = 8, yend = 7.5,
             arrow = arrow(length = unit(0.3, "cm")), size = 1) +
    annotate("segment", x = 5, xend = 5, y = 6.5, yend = 6,
             arrow = arrow(length = unit(0.3, "cm")), size = 1) +

    # Title
    ggtitle("PRISMA 2020 Flow Diagram") +
    theme(plot.title = element_text(hjust = 0.5, size = 16, face = "bold"))

  return(p)
}
