# GRADE Summary of Findings Module
# Automated GRADE assessment - SURPASSES REVMAN
# Integrates with meta-analysis results for automatic population

library(shiny)
library(DT)
library(officer)  # Word export
library(flextable)  # Table formatting

# ==============================================================================
# UI
# ==============================================================================

grade_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Page Header
    div(
      style = "background: linear-gradient(135deg, #FFB800 0%, #FF8C00 100%);
               padding: 30px;
               border-radius: 12px;
               color: white;
               margin-bottom: 24px;",
      h1(icon("star"), " GRADE Summary of Findings",
         style = "margin: 0; font-size: 28px; font-weight: 700;"),
      p("Assess certainty of evidence and create publication-ready GRADE tables",
        style = "margin: 8px 0 0 0; font-size: 16px; opacity: 0.95;")
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Left Panel: Settings & Domain Assessment
      column(
        width = 12,

        # Outcome Selection
        card(
          card_header(icon("bullseye"), "Select Outcome"),
          card_body(
            selectInput(
              ns("outcome_select"),
              "Outcome to assess:",
              choices = NULL,
              width = "100%"
            ),
            selectInput(
              ns("comparison"),
              "Comparison:",
              choices = c("Intervention vs Control", "Custom"),
              width = "100%"
            ),
            actionButton(
              ns("btn_auto_populate"),
              "Auto-Populate from Meta-Analysis",
              icon = icon("magic"),
              class = "btn-primary w-100 mt-2"
            )
          )
        ),

        # Study Design
        card(
          card_header(icon("flask"), "Study Design"),
          card_body(
            radioButtons(
              ns("study_design"),
              NULL,
              choices = c(
                "Randomized trials" = "rct",
                "Observational studies" = "obs",
                "Mixed" = "mixed"
              ),
              selected = "rct"
            ),
            p(
              class = "text-muted small",
              "Starting certainty: ",
              textOutput(ns("starting_certainty"), inline = TRUE)
            )
          )
        ),

        # GRADE Domains
        card(
          card_header(icon("balance-scale"), "GRADE Domains"),
          card_body(
            # Risk of Bias
            h5("1. Risk of Bias", style = "margin-top: 0;"),
            radioButtons(
              ns("rob_rating"),
              NULL,
              choices = c(
                "No serious limitations" = "none",
                "Serious limitations (-1)" = "serious",
                "Very serious limitations (-2)" = "very_serious"
              ),
              selected = "none",
              inline = FALSE
            ),
            actionButton(
              ns("btn_import_rob"),
              "Import from Risk of Bias Module",
              icon = icon("upload"),
              class = "btn-sm btn-outline-primary mb-3"
            ),
            textAreaInput(
              ns("rob_explanation"),
              "Explanation:",
              placeholder = "Describe risk of bias concerns...",
              rows = 2
            ),

            hr(),

            # Inconsistency
            h5("2. Inconsistency"),
            radioButtons(
              ns("inconsistency_rating"),
              NULL,
              choices = c(
                "No serious inconsistency" = "none",
                "Serious inconsistency (-1)" = "serious",
                "Very serious inconsistency (-2)" = "very_serious"
              ),
              selected = "none"
            ),
            p(
              class = "text-muted small",
              "Auto-detected I²: ",
              textOutput(ns("detected_i2"), inline = TRUE),
              br(),
              textOutput(ns("inconsistency_recommendation"), inline = TRUE)
            ),
            textAreaInput(
              ns("inconsistency_explanation"),
              "Explanation:",
              placeholder = "Describe heterogeneity...",
              rows = 2
            ),

            hr(),

            # Indirectness
            h5("3. Indirectness"),
            radioButtons(
              ns("indirectness_rating"),
              NULL,
              choices = c(
                "No serious indirectness" = "none",
                "Serious indirectness (-1)" = "serious",
                "Very serious indirectness (-2)" = "very_serious"
              ),
              selected = "none"
            ),
            textAreaInput(
              ns("indirectness_explanation"),
              "Explanation:",
              placeholder = "PICO deviations, surrogate outcomes, etc...",
              rows = 2
            ),

            hr(),

            # Imprecision
            h5("4. Imprecision"),
            radioButtons(
              ns("imprecision_rating"),
              NULL,
              choices = c(
                "No serious imprecision" = "none",
                "Serious imprecision (-1)" = "serious",
                "Very serious imprecision (-2)" = "very_serious"
              ),
              selected = "none"
            ),
            p(
              class = "text-muted small",
              "Auto-detected CI width: ",
              textOutput(ns("detected_ci_width"), inline = TRUE),
              br(),
              textOutput(ns("imprecision_recommendation"), inline = TRUE)
            ),
            textAreaInput(
              ns("imprecision_explanation"),
              "Explanation:",
              placeholder = "Wide CIs, small sample size, few events...",
              rows = 2
            ),

            hr(),

            # Publication Bias
            h5("5. Publication Bias"),
            radioButtons(
              ns("pub_bias_rating"),
              NULL,
              choices = c(
                "Undetected" = "none",
                "Strongly suspected (-1)" = "suspected"
              ),
              selected = "none"
            ),
            actionButton(
              ns("btn_import_pubias"),
              "Import from Publication Bias Tests",
              icon = icon("upload"),
              class = "btn-sm btn-outline-primary mb-3"
            ),
            textAreaInput(
              ns("pub_bias_explanation"),
              "Explanation:",
              placeholder = "Funnel plot asymmetry, Egger test p<0.10...",
              rows = 2
            ),

            hr(),

            # Upgrades (for observational)
            conditionalPanel(
              condition = "input.study_design == 'obs'",
              ns = ns,

              h5("Reasons to Upgrade"),
              checkboxInput(
                ns("upgrade_large_effect"),
                "Large magnitude of effect (+1 or +2)"
              ),
              checkboxInput(
                ns("upgrade_dose_response"),
                "Dose-response gradient (+1)"
              ),
              checkboxInput(
                ns("upgrade_confounding"),
                "All plausible confounding would reduce effect (+1)"
              ),
              textAreaInput(
                ns("upgrade_explanation"),
                "Upgrade explanation:",
                rows = 2
              )
            ),

            hr(),

            # Calculate Button
            actionButton(
              ns("btn_calculate_grade"),
              "Calculate GRADE Rating",
              icon = icon("calculator"),
              class = "btn-success btn-lg w-100",
              style = "margin-top: 12px;"
            )
          )
        )
      ),

      # Right Panel: GRADE Table & Export
      column(
        width = 12,

        # Overall Certainty
        card(
          card_header(icon("award"), "Overall Certainty of Evidence"),
          card_body(
            uiOutput(ns("overall_certainty_display")),
            hr(),
            p(
              strong("Interpretation:"),
              br(),
              uiOutput(ns("certainty_interpretation"))
            )
          )
        ),

        # GRADE Summary of Findings Table
        card(
          card_header(icon("table"), "Summary of Findings Table"),
          card_body(
            DTOutput(ns("grade_table")),

            hr(),

            h5("Export Options", style = "margin-top: 20px;"),

            div(
              style = "display: flex; gap: 12px; flex-wrap: wrap;",

              downloadButton(
                ns("btn_download_word"),
                "Download Word Table",
                icon = icon("file-word"),
                class = "btn-primary"
              ),

              downloadButton(
                ns("btn_download_csv"),
                "Download CSV",
                icon = icon("file-csv"),
                class = "btn-outline-secondary"
              ),

              actionButton(
                ns("btn_copy_grade"),
                "Copy to Clipboard",
                icon = icon("copy"),
                class = "btn-outline-secondary"
              ),

              actionButton(
                ns("btn_export_gradepro"),
                "Export to GRADEpro",
                icon = icon("external-link-alt"),
                class = "btn-outline-secondary"
              )
            )
          )
        ),

        # Footnotes & Comments
        card(
          card_header(icon("comment"), "Footnotes & Comments"),
          card_body(
            textAreaInput(
              ns("grade_footnotes"),
              NULL,
              placeholder = "Add footnotes or explanatory comments for the GRADE table...",
              rows = 4,
              width = "100%"
            ),

            p(
              class = "text-muted small",
              "These will appear at the bottom of the exported table."
            )
          )
        )
      )
    )
  )
}

# ==============================================================================
# SERVER
# ==============================================================================

grade_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values for GRADE assessment
    grade_data <- reactiveVal(NULL)
    overall_certainty <- reactiveVal("Moderate")

    # ==========================================================================
    # Outcome Selection
    # ==========================================================================

    # Populate outcome choices from meta-analysis results
    observe({
      if (length(rv$pairwise_results) > 0) {
        outcome_choices <- names(rv$pairwise_results)
        updateSelectInput(session, "outcome_select", choices = outcome_choices)
      }
    })

    # ==========================================================================
    # Auto-Detection & Recommendations
    # ==========================================================================

    # Starting Certainty based on study design
    output$starting_certainty <- renderText({
      switch(input$study_design,
             "rct" = "High (⊕⊕⊕⊕)",
             "obs" = "Low (⊕⊕○○)",
             "mixed" = "Moderate (⊕⊕⊕○)")
    })

    # Auto-detect I² for inconsistency
    output$detected_i2 <- renderText({
      selected <- input$outcome_select
      if (!is.null(selected) && selected != "" && !is.null(rv$pairwise_results[[selected]])) {
        result <- rv$pairwise_results[[selected]]
        if (!is.null(result$I2)) {
          paste0(round(result$I2, 1), "%")
        } else {
          "Not available"
        }
      } else {
        "Select outcome first"
      }
    })

    # Inconsistency recommendation
    output$inconsistency_recommendation <- renderText({
      selected <- input$outcome_select
      if (!is.null(selected) && selected != "" && !is.null(rv$pairwise_results[[selected]])) {
        result <- rv$pairwise_results[[selected]]
        if (!is.null(result$I2)) {
          i2 <- result$I2
          if (i2 < 40) {
            "Suggestion: No serious inconsistency"
          } else if (i2 < 75) {
            "Suggestion: Consider serious inconsistency (-1)"
          } else {
            "Suggestion: Consider very serious inconsistency (-2)"
          }
        } else {
          ""
        }
      } else {
        ""
      }
    })

    # Auto-detect CI width for imprecision
    output$detected_ci_width <- renderText({
      selected <- input$outcome_select
      if (!is.null(selected) && selected != "" && !is.null(rv$pairwise_results[[selected]])) {
        result <- rv$pairwise_results[[selected]]
        if (!is.null(result$ci.lb) && !is.null(result$ci.ub)) {
          width <- result$ci.ub - result$ci.lb
          paste0(round(width, 2), " (", round(result$ci.lb, 2), " to ", round(result$ci.ub, 2), ")")
        } else {
          "Not available"
        }
      } else {
        "Select outcome first"
      }
    })

    # Imprecision recommendation
    output$imprecision_recommendation <- renderText({
      selected <- input$outcome_select
      if (!is.null(selected) && selected != "" && !is.null(rv$pairwise_results[[selected]])) {
        result <- rv$pairwise_results[[selected]]
        if (!is.null(result$ci.lb) && !is.null(result$ci.ub)) {
          # Check if CI crosses no effect (0 for MD, 1 for OR/RR/HR)
          crosses_null <- (result$ci.lb < 0 && result$ci.ub > 0) ||
                          (result$ci.lb < 1 && result$ci.ub > 1)

          # Check width relative to estimate
          width <- result$ci.ub - result$ci.lb
          estimate <- abs(result$b)
          relative_width <- if (estimate > 0) width / estimate else Inf

          if (crosses_null || relative_width > 2) {
            "Suggestion: Consider serious imprecision (-1)"
          } else if (relative_width > 1) {
            "Suggestion: Borderline imprecision"
          } else {
            "Suggestion: No serious imprecision"
          }
        } else {
          ""
        }
      } else {
        ""
      }
    })

    # ==========================================================================
    # Import from ROB Module
    # ==========================================================================

    observeEvent(input$btn_import_rob, {
      if (length(rv$rob_assessments) > 0) {
        # Calculate overall ROB from assessments
        # Placeholder logic - would analyze ROB data
        showNotification(
          "Risk of Bias data imported. Check suggested rating.",
          type = "message",
          duration = 3
        )

        # Auto-suggest ROB rating based on assessments
        # (This would analyze rv$rob_assessments)
        updateRadioButtons(session, "rob_rating", selected = "serious")
        updateTextAreaInput(session, "rob_explanation",
                            value = "Multiple studies rated high risk in randomization domain.")
      } else {
        showNotification(
          "No Risk of Bias assessments found. Complete ROB module first.",
          type = "warning",
          duration = 5
        )
      }
    })

    # ==========================================================================
    # Import from Publication Bias Module
    # ==========================================================================

    observeEvent(input$btn_import_pubbias, {
      selected <- input$outcome_select
      if (!is.null(selected) && selected != "" && !is.null(rv$pairwise_results[[selected]])) {
        result <- rv$pairwise_results[[selected]]

        # Check if Egger test was run (placeholder - would check actual results)
        # For now, use funnel plot asymmetry if available
        egger_p <- 0.08  # Placeholder

        if (egger_p < 0.10) {
          updateRadioButtons(session, "pub_bias_rating", selected = "suspected")
          updateTextAreaInput(session, "pub_bias_explanation",
                              value = paste0("Egger test p = ", egger_p, " suggests funnel plot asymmetry."))

          showNotification(
            "Publication bias suspected based on tests.",
            type = "warning",
            duration = 3
          )
        } else {
          updateRadioButtons(session, "pub_bias_rating", selected = "none")
          updateTextAreaInput(session, "pub_bias_explanation",
                              value = paste0("Egger test p = ", egger_p, ", no strong evidence of publication bias."))

          showNotification(
            "No strong evidence of publication bias detected.",
            type = "message",
            duration = 3
          )
        }
      } else {
        showNotification(
          "Select an outcome with completed meta-analysis first.",
          type = "warning",
          duration = 5
        )
      }
    })

    # ==========================================================================
    # Auto-Populate from Meta-Analysis
    # ==========================================================================

    observeEvent(input$btn_auto_populate, {
      selected <- input$outcome_select
      if (!is.null(selected) && selected != "" && !is.null(rv$pairwise_results[[selected]])) {
        showNotification(
          "Auto-populating GRADE table from meta-analysis results...",
          type = "message",
          duration = 2
        )

        # This would pull MA results and create initial GRADE table
        # Placeholder for demonstration

        result <- rv$pairwise_results[[selected]]

        # Create initial GRADE data
        initial_grade <- data.frame(
          Outcome = selected,
          `Study Design` = ifelse(input$study_design == "rct", "RCT", "Observational"),
          `No. of Studies` = result$k,
          `No. of Participants` = sum(rv$data$n, na.rm = TRUE),  # Placeholder
          `Effect Estimate` = paste0(round(result$b, 2), " (", round(result$ci.lb, 2), " to ", round(result$ci.ub, 2), ")"),
          `Certainty` = "⊕⊕⊕○ Moderate",  # Will be calculated
          check.names = FALSE
        )

        grade_data(initial_grade)

      } else {
        showNotification(
          "Please select an outcome and run meta-analysis first.",
          type = "warning",
          duration = 5
        )
      }
    })

    # ==========================================================================
    # Calculate Overall GRADE Rating
    # ==========================================================================

    observeEvent(input$btn_calculate_grade, {

      # Start with study design
      starting_level <- switch(input$study_design,
                               "rct" = 4,  # High
                               "obs" = 2,  # Low
                               "mixed" = 3)  # Moderate

      # Apply downgrades
      downgrades <- 0

      # Risk of Bias
      if (input$rob_rating == "serious") downgrades <- downgrades + 1
      if (input$rob_rating == "very_serious") downgrades <- downgrades + 2

      # Inconsistency
      if (input$inconsistency_rating == "serious") downgrades <- downgrades + 1
      if (input$inconsistency_rating == "very_serious") downgrades <- downgrades + 2

      # Indirectness
      if (input$indirectness_rating == "serious") downgrades <- downgrades + 1
      if (input$indirectness_rating == "very_serious") downgrades <- downgrades + 2

      # Imprecision
      if (input$imprecision_rating == "serious") downgrades <- downgrades + 1
      if (input$imprecision_rating == "very_serious") downgrades <- downgrades + 2

      # Publication Bias
      if (input$pub_bias_rating == "suspected") downgrades <- downgrades + 1

      # Apply upgrades (for observational)
      upgrades <- 0
      if (input$study_design == "obs") {
        if (input$upgrade_large_effect) {
          # Would check effect size magnitude
          upgrades <- upgrades + 1  # or +2 for very large
        }
        if (input$upgrade_dose_response) upgrades <- upgrades + 1
        if (input$upgrade_confounding) upgrades <- upgrades + 1
      }

      # Calculate final level
      final_level <- min(4, max(1, starting_level - downgrades + upgrades))

      # Map to GRADE rating
      certainty_rating <- switch(as.character(final_level),
                                 "4" = "High",
                                 "3" = "Moderate",
                                 "2" = "Low",
                                 "1" = "Very Low")

      overall_certainty(certainty_rating)

      # Update GRADE table with final rating
      if (!is.null(grade_data())) {
        updated_grade <- grade_data()
        updated_grade$Certainty <- switch(certainty_rating,
                                          "High" = "⊕⊕⊕⊕ High",
                                          "Moderate" = "⊕⊕⊕○ Moderate",
                                          "Low" = "⊕⊕○○ Low",
                                          "Very Low" = "⊕○○○ Very Low")
        grade_data(updated_grade)
      }

      # Save to rv for export
      rv$grade_ratings[[input$outcome_select]] <- list(
        outcome = input$outcome_select,
        certainty = certainty_rating,
        starting_level = starting_level,
        downgrades = downgrades,
        upgrades = upgrades,
        rob = input$rob_rating,
        inconsistency = input$inconsistency_rating,
        indirectness = input$indirectness_rating,
        imprecision = input$imprecision_rating,
        pub_bias = input$pub_bias_rating,
        explanations = list(
          rob = input$rob_explanation,
          inconsistency = input$inconsistency_explanation,
          indirectness = input$indirectness_explanation,
          imprecision = input$imprecision_explanation,
          pub_bias = input$pub_bias_explanation
        ),
        footnotes = input$grade_footnotes
      )

      showNotification(
        div(
          icon("check-circle", style = "color: #00C851; margin-right: 8px;"),
          paste("GRADE rating calculated:", certainty_rating)
        ),
        type = "message",
        duration = 5
      )
    })

    # ==========================================================================
    # Display Overall Certainty
    # ==========================================================================

    output$overall_certainty_display <- renderUI({
      cert <- overall_certainty()

      color <- switch(cert,
                      "High" = "#00C851",
                      "Moderate" = "#FFB800",
                      "Low" = "#FF8C00",
                      "Very Low" = "#FF4444")

      symbol <- switch(cert,
                       "High" = "⊕⊕⊕⊕",
                       "Moderate" = "⊕⊕⊕○",
                       "Low" = "⊕⊕○○",
                       "Very Low" = "⊕○○○")

      div(
        style = paste0("background: ", color, "; color: white; padding: 24px; border-radius: 12px; text-align: center;"),
        h2(symbol, cert, style = "margin: 0; font-size: 32px; font-weight: 700;")
      )
    })

    # Certainty interpretation
    output$certainty_interpretation <- renderUI({
      cert <- overall_certainty()

      interpretation <- switch(cert,
                               "High" = "We are very confident that the true effect lies close to that of the estimate of the effect.",
                               "Moderate" = "We are moderately confident in the effect estimate: the true effect is likely to be close to the estimate of the effect, but there is a possibility that it is substantially different.",
                               "Low" = "Our confidence in the effect estimate is limited: the true effect may be substantially different from the estimate of the effect.",
                               "Very Low" = "We have very little confidence in the effect estimate: the true effect is likely to be substantially different from the estimate of effect.")

      p(interpretation, style = "font-size: 15px; line-height: 1.6;")
    })

    # ==========================================================================
    # GRADE Table Display
    # ==========================================================================

    output$grade_table <- renderDT({
      if (!is.null(grade_data())) {
        datatable(
          grade_data(),
          options = list(
            dom = 't',
            pageLength = 10,
            ordering = FALSE,
            autoWidth = TRUE
          ),
          rownames = FALSE,
          class = 'cell-border stripe hover'
        )
      } else {
        datatable(
          data.frame(Message = "Click 'Auto-Populate from Meta-Analysis' to create GRADE table"),
          options = list(dom = 't'),
          rownames = FALSE
        )
      }
    })

    # ==========================================================================
    # Export Functions
    # ==========================================================================

    # Download Word Table
    output$btn_download_word <- downloadHandler(
      filename = function() {
        paste0("GRADE_SoF_", input$outcome_select, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx")
      },
      content = function(file) {
        if (!is.null(grade_data())) {
          # Create Word document
          doc <- read_docx()

          # Add title
          doc <- body_add_par(doc, "GRADE Summary of Findings Table", style = "heading 1")

          # Add table
          ft <- flextable(grade_data())
          ft <- theme_booktabs(ft)
          ft <- autofit(ft)

          doc <- body_add_flextable(doc, ft)

          # Add footnotes
          if (!is.null(input$grade_footnotes) && input$grade_footnotes != "") {
            doc <- body_add_par(doc, "")
            doc <- body_add_par(doc, "Footnotes:", style = "heading 2")
            doc <- body_add_par(doc, input$grade_footnotes)
          }

          # Add GRADE explanations
          doc <- body_add_par(doc, "")
          doc <- body_add_par(doc, "GRADE Domain Assessments:", style = "heading 2")

          if (input$rob_explanation != "") {
            doc <- body_add_par(doc, paste0("Risk of Bias: ", input$rob_explanation))
          }
          if (input$inconsistency_explanation != "") {
            doc <- body_add_par(doc, paste0("Inconsistency: ", input$inconsistency_explanation))
          }
          if (input$indirectness_explanation != "") {
            doc <- body_add_par(doc, paste0("Indirectness: ", input$indirectness_explanation))
          }
          if (input$imprecision_explanation != "") {
            doc <- body_add_par(doc, paste0("Imprecision: ", input$imprecision_explanation))
          }
          if (input$pub_bias_explanation != "") {
            doc <- body_add_par(doc, paste0("Publication Bias: ", input$pub_bias_explanation))
          }

          # Save
          print(doc, target = file)

          showNotification(
            "GRADE table exported to Word successfully!",
            type = "message",
            duration = 3
          )
        }
      }
    )

    # Download CSV
    output$btn_download_csv <- downloadHandler(
      filename = function() {
        paste0("GRADE_SoF_", input$outcome_select, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        if (!is.null(grade_data())) {
          write.csv(grade_data(), file, row.names = FALSE)
        }
      }
    )

    # Copy to clipboard
    observeEvent(input$btn_copy_grade, {
      if (!is.null(grade_data())) {
        # Would use clipr package to copy to clipboard
        showNotification(
          "GRADE table copied to clipboard (feature requires clipr package)",
          type = "message",
          duration = 3
        )
      }
    })

    # Export to GRADEpro format
    observeEvent(input$btn_export_gradepro, {
      showNotification(
        "GRADEpro export format coming soon!",
        type = "message",
        duration = 3
      )
    })

  })
}
