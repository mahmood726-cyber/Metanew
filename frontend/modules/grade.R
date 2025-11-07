# GRADE Quality Assessment Module
# Reference: Guyatt et al. (2008-2011) GRADE: an emerging consensus on rating quality of evidence
# Journal of Clinical Epidemiology series

library(shiny)
library(bslib)
library(DT)
library(ggplot2)

grade_ui <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      col_widths = c(5, 7),

      # Left panel: GRADE assessment entry
      card(
        card_header("GRADE Quality Assessment"),
        helpText("Assess quality of evidence using GRADE approach. Quality starts at HIGH for RCTs, LOW for observational studies."),

        selectInput(ns("outcome_select"), "Select Outcome", choices = NULL),

        selectInput(ns("starting_quality"), "Starting Quality of Evidence",
                    choices = c("High (RCTs)" = "High",
                                "Low (Observational)" = "Low"),
                    selected = "High"),

        hr(),
        h5("Factors that DECREASE quality"),

        # Domain 1: Risk of Bias
        div(
          class = "mb-3",
          strong("1. Risk of Bias"),
          selectInput(ns("rob_rating"), "Downgrade for RoB?",
                      choices = c("Not serious" = 0,
                                  "Serious (-1)" = -1,
                                  "Very serious (-2)" = -2)),
          textAreaInput(ns("rob_rationale"), "Rationale", rows = 2,
                        placeholder = "e.g., Most studies at high risk of bias in ≥1 domain")
        ),

        # Domain 2: Inconsistency
        div(
          class = "mb-3",
          strong("2. Inconsistency (Heterogeneity)"),
          selectInput(ns("inconsistency_rating"), "Downgrade for inconsistency?",
                      choices = c("Not serious" = 0,
                                  "Serious (-1)" = -1,
                                  "Very serious (-2)" = -2)),
          textAreaInput(ns("inconsistency_rationale"), "Rationale", rows = 2,
                        placeholder = "e.g., I² > 75%, wide variation in point estimates")
        ),

        # Domain 3: Indirectness
        div(
          class = "mb-3",
          strong("3. Indirectness"),
          selectInput(ns("indirectness_rating"), "Downgrade for indirectness?",
                      choices = c("Not serious" = 0,
                                  "Serious (-1)" = -1,
                                  "Very serious (-2)" = -2)),
          textAreaInput(ns("indirectness_rationale"), "Rationale", rows = 2,
                        placeholder = "e.g., PICO differences, surrogate outcomes")
        ),

        # Domain 4: Imprecision
        div(
          class = "mb-3",
          strong("4. Imprecision"),
          selectInput(ns("imprecision_rating"), "Downgrade for imprecision?",
                      choices = c("Not serious" = 0,
                                  "Serious (-1)" = -1,
                                  "Very serious (-2)" = -2)),
          textAreaInput(ns("imprecision_rationale"), "Rationale", rows = 2,
                        placeholder = "e.g., Wide CI, small sample size, few events")
        ),

        # Domain 5: Publication Bias
        div(
          class = "mb-3",
          strong("5. Publication Bias"),
          selectInput(ns("publication_bias_rating"), "Downgrade for publication bias?",
                      choices = c("Not detected" = 0,
                                  "Suspected (-1)" = -1,
                                  "Very likely (-2)" = -2)),
          textAreaInput(ns("publication_bias_rationale"), "Rationale", rows = 2,
                        placeholder = "e.g., Egger's test p < 0.05, funnel plot asymmetry")
        ),

        hr(),
        h5("Factors that INCREASE quality (for observational studies only)"),

        div(
          class = "mb-3",
          checkboxInput(ns("large_effect"), "Large effect (+1 or +2)", FALSE),
          helpText("RR > 2 or < 0.5 (+1); RR > 5 or < 0.2 (+2)"),

          checkboxInput(ns("dose_response"), "Dose-response gradient (+1)", FALSE),
          helpText("Evidence of dose-response relationship"),

          checkboxInput(ns("confounding_reduces"), "All plausible confounding would reduce effect (+1)", FALSE),
          helpText("Residual confounding works against observed effect")
        ),

        hr(),
        div(
          class = "d-flex gap-2",
          actionButton(ns("btn_save"), "Save GRADE Assessment",
                       class = "btn-success flex-fill", icon = icon("save")),
          actionButton(ns("btn_auto_fill"), "Auto-Fill from MA Results",
                       class = "btn-info flex-fill", icon = icon("magic"))
        )
      ),

      # Right panel: Summary and evidence profile
      card(
        card_header("GRADE Summary"),
        navset_card_tab(
          nav_panel(
            "Quality Rating",
            icon = icon("certificate"),
            uiOutput(ns("quality_badge")),
            hr(),
            verbatimTextOutput(ns("grade_summary"))
          ),
          nav_panel(
            "Evidence Profile",
            icon = icon("table"),
            DTOutput(ns("evidence_profile_table")),
            hr(),
            downloadButton(ns("download_profile"), "Download Evidence Profile",
                           class = "btn-sm btn-primary")
          ),
          nav_panel(
            "Summary of Findings",
            icon = icon("file-alt"),
            uiOutput(ns("sof_table")),
            hr(),
            helpText("Summary of Findings (SoF) table for systematic review reporting")
          ),
          nav_panel(
            "Quality Across Outcomes",
            icon = icon("chart-bar"),
            plotOutput(ns("quality_plot"), height = "400px"),
            hr(),
            verbatimTextOutput(ns("quality_summary_text"))
          )
        )
      )
    )
  )
}

grade_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values for GRADE assessments
    grade_assessments <- reactiveVal(list())

    # Update outcome choices
    observe({
      if (!is.null(rv$pairwise_results)) {
        outcomes <- names(rv$pairwise_results)
        updateSelectInput(session, "outcome_select", choices = outcomes)
      }
    })

    # Load existing assessment when outcome selected
    observeEvent(input$outcome_select, {
      req(input$outcome_select)
      assessments <- grade_assessments()

      if (input$outcome_select %in% names(assessments)) {
        grade <- assessments[[input$outcome_select]]
        updateSelectInput(session, "starting_quality", selected = grade$starting_quality)
        updateSelectInput(session, "rob_rating", selected = as.character(grade$rob_downgrade))
        updateTextAreaInput(session, "rob_rationale", value = grade$rob_rationale)
        updateSelectInput(session, "inconsistency_rating", selected = as.character(grade$inconsistency_downgrade))
        updateTextAreaInput(session, "inconsistency_rationale", value = grade$inconsistency_rationale)
        updateSelectInput(session, "indirectness_rating", selected = as.character(grade$indirectness_downgrade))
        updateTextAreaInput(session, "indirectness_rationale", value = grade$indirectness_rationale)
        updateSelectInput(session, "imprecision_rating", selected = as.character(grade$imprecision_downgrade))
        updateTextAreaInput(session, "imprecision_rationale", value = grade$imprecision_rationale)
        updateSelectInput(session, "publication_bias_rating", selected = as.character(grade$publication_bias_downgrade))
        updateTextAreaInput(session, "publication_bias_rationale", value = grade$publication_bias_rationale)
        updateCheckboxInput(session, "large_effect", value = grade$large_effect_upgrade)
        updateCheckboxInput(session, "dose_response", value = grade$dose_response_upgrade)
        updateCheckboxInput(session, "confounding_reduces", value = grade$confounding_upgrade)
      }
    })

    # Auto-fill from MA results
    observeEvent(input$btn_auto_fill, {
      req(input$outcome_select)
      req(rv$pairwise_results)

      ma_result <- rv$pairwise_results[[input$outcome_select]]
      req(ma_result)

      # Auto-assess inconsistency based on I²
      if (ma_result$i_squared < 40) {
        inconsistency <- 0
        inconsistency_text <- sprintf("Low heterogeneity (I² = %.1f%%)", ma_result$i_squared)
      } else if (ma_result$i_squared < 75) {
        inconsistency <- -1
        inconsistency_text <- sprintf("Moderate heterogeneity (I² = %.1f%%), point estimates vary considerably", ma_result$i_squared)
      } else {
        inconsistency <- -2
        inconsistency_text <- sprintf("Substantial heterogeneity (I² = %.1f%%), large variation in effects", ma_result$i_squared)
      }

      updateSelectInput(session, "inconsistency_rating", selected = as.character(inconsistency))
      updateTextAreaInput(session, "inconsistency_rationale", value = inconsistency_text)

      # Auto-assess imprecision based on CI width and sample size
      ci_width <- ma_result$ci_upper - ma_result$ci_lower
      if (ma_result$n_studies < 5 || ci_width > 1.5) {
        imprecision <- -1
        imprecision_text <- sprintf("Few studies (k=%d) and/or wide CI (%.2f to %.2f)",
                                     ma_result$n_studies, ma_result$ci_lower, ma_result$ci_upper)
        updateSelectInput(session, "imprecision_rating", selected = as.character(imprecision))
        updateTextAreaInput(session, "imprecision_rationale", value = imprecision_text)
      }

      # Auto-assess publication bias from Egger's test
      if (!is.null(ma_result$egger_test)) {
        if (ma_result$egger_test$p_value < 0.05) {
          pub_bias <- -1
          pub_bias_text <- sprintf("Egger's test significant (p = %.3f), funnel plot asymmetry detected",
                                    ma_result$egger_test$p_value)
        } else {
          pub_bias <- 0
          pub_bias_text <- sprintf("Egger's test not significant (p = %.3f)",
                                    ma_result$egger_test$p_value)
        }
        updateSelectInput(session, "publication_bias_rating", selected = as.character(pub_bias))
        updateTextAreaInput(session, "publication_bias_rationale", value = pub_bias_text)
      }

      # Check for large effect
      pooled_or <- exp(ma_result$pooled_effect)  # Assuming log scale
      if (pooled_or > 2 || pooled_or < 0.5) {
        updateCheckboxInput(session, "large_effect", value = TRUE)
      }

      showNotification("✓ Auto-filled GRADE assessment from MA results. Please review and adjust as needed.",
                       type = "message", duration = 5)
    })

    # Save assessment
    observeEvent(input$btn_save, {
      req(input$outcome_select)

      # Calculate downgrades and upgrades
      downgrades <- as.numeric(input$rob_rating) +
                    as.numeric(input$inconsistency_rating) +
                    as.numeric(input$indirectness_rating) +
                    as.numeric(input$imprecision_rating) +
                    as.numeric(input$publication_bias_rating)

      # Upgrades only apply if starting from Low quality (observational)
      upgrades <- 0
      if (input$starting_quality == "Low") {
        upgrades <- (if (input$large_effect) 1 else 0) +
                    (if (input$dose_response) 1 else 0) +
                    (if (input$confounding_reduces) 1 else 0)
      }

      # Calculate final quality
      final_quality <- calculate_final_grade_quality(input$starting_quality, downgrades, upgrades)

      assessment <- list(
        outcome = input$outcome_select,
        starting_quality = input$starting_quality,
        rob_downgrade = as.numeric(input$rob_rating),
        rob_rationale = input$rob_rationale,
        inconsistency_downgrade = as.numeric(input$inconsistency_rating),
        inconsistency_rationale = input$inconsistency_rationale,
        indirectness_downgrade = as.numeric(input$indirectness_rating),
        indirectness_rationale = input$indirectness_rationale,
        imprecision_downgrade = as.numeric(input$imprecision_rating),
        imprecision_rationale = input$imprecision_rationale,
        publication_bias_downgrade = as.numeric(input$publication_bias_rating),
        publication_bias_rationale = input$publication_bias_rationale,
        large_effect_upgrade = input$large_effect,
        dose_response_upgrade = input$dose_response,
        confounding_upgrade = input$confounding_reduces,
        total_downgrades = downgrades,
        total_upgrades = upgrades,
        final_quality = final_quality,
        timestamp = Sys.time()
      )

      # Save to assessments
      assessments <- grade_assessments()
      assessments[[input$outcome_select]] <- assessment
      grade_assessments(assessments)

      # Save to rv
      if (is.null(rv$grade_assessments)) {
        rv$grade_assessments <- list()
      }
      rv$grade_assessments[[input$outcome_select]] <- assessment

      showNotification(
        sprintf("✓ GRADE assessment saved for %s: %s quality",
                input$outcome_select, final_quality),
        type = "message",
        duration = 3
      )
    })

    # Quality badge
    output$quality_badge <- renderUI({
      assessments <- grade_assessments()
      req(input$outcome_select)
      req(input$outcome_select %in% names(assessments))

      grade <- assessments[[input$outcome_select]]
      quality <- grade$final_quality

      badge_color <- switch(quality,
                            "High" = "success",
                            "Moderate" = "info",
                            "Low" = "warning",
                            "Very Low" = "danger")

      badge_icon <- switch(quality,
                           "High" = "check-circle",
                           "Moderate" = "info-circle",
                           "Low" = "exclamation-triangle",
                           "Very Low" = "times-circle")

      div(
        class = "text-center p-4",
        h2(class = paste0("text-", badge_color),
           icon(badge_icon), " ", quality, " Quality"),
        h5(class = "text-muted", "Quality of Evidence"),
        hr(),
        p(sprintf("Starting: %s | Downgrades: %d | Upgrades: %d",
                  grade$starting_quality, abs(grade$total_downgrades), grade$total_upgrades))
      )
    })

    # GRADE summary
    output$grade_summary <- renderPrint({
      assessments <- grade_assessments()
      req(input$outcome_select)
      req(input$outcome_select %in% names(assessments))

      grade <- assessments[[input$outcome_select]]

      cat("GRADE QUALITY ASSESSMENT\n")
      cat(sprintf("Outcome: %s\n", grade$outcome))
      cat(sprintf("=======================%s\n\n", paste(rep("=", nchar(grade$outcome)), collapse = "")))

      cat(sprintf("Starting quality: %s\n", grade$starting_quality))
      cat("\nFactors decreasing quality:\n")
      if (grade$rob_downgrade != 0) {
        cat(sprintf("  Risk of bias: %d\n", grade$rob_downgrade))
        cat(sprintf("    → %s\n", grade$rob_rationale))
      }
      if (grade$inconsistency_downgrade != 0) {
        cat(sprintf("  Inconsistency: %d\n", grade$inconsistency_downgrade))
        cat(sprintf("    → %s\n", grade$inconsistency_rationale))
      }
      if (grade$indirectness_downgrade != 0) {
        cat(sprintf("  Indirectness: %d\n", grade$indirectness_downgrade))
        cat(sprintf("    → %s\n", grade$indirectness_rationale))
      }
      if (grade$imprecision_downgrade != 0) {
        cat(sprintf("  Imprecision: %d\n", grade$imprecision_downgrade))
        cat(sprintf("    → %s\n", grade$imprecision_rationale))
      }
      if (grade$publication_bias_downgrade != 0) {
        cat(sprintf("  Publication bias: %d\n", grade$publication_bias_downgrade))
        cat(sprintf("    → %s\n", grade$publication_bias_rationale))
      }

      if (grade$total_upgrades > 0) {
        cat("\nFactors increasing quality:\n")
        if (grade$large_effect_upgrade) cat("  Large effect: +1\n")
        if (grade$dose_response_upgrade) cat("  Dose-response gradient: +1\n")
        if (grade$confounding_upgrade) cat("  Confounding reduces effect: +1\n")
      }

      cat(sprintf("\nFINAL QUALITY: %s\n", toupper(grade$final_quality)))
    })

    # Evidence profile table
    output$evidence_profile_table <- renderDT({
      assessments <- grade_assessments()
      req(length(assessments) > 0)

      # Build evidence profile
      profile_df <- do.call(rbind, lapply(names(assessments), function(outcome) {
        grade <- assessments[[outcome]]
        data.frame(
          Outcome = outcome,
          Starting_Quality = grade$starting_quality,
          Risk_of_Bias = format_grade_domain(grade$rob_downgrade),
          Inconsistency = format_grade_domain(grade$inconsistency_downgrade),
          Indirectness = format_grade_domain(grade$indirectness_downgrade),
          Imprecision = format_grade_domain(grade$imprecision_downgrade),
          Publication_Bias = format_grade_domain(grade$publication_bias_downgrade),
          Final_Quality = grade$final_quality,
          stringsAsFactors = FALSE
        )
      }))

      datatable(
        profile_df,
        options = list(
          pageLength = 10,
          dom = 't',
          scrollX = TRUE
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          "Final_Quality",
          backgroundColor = styleEqual(
            c("High", "Moderate", "Low", "Very Low"),
            c("#90EE90", "#87CEEB", "#FFD700", "#FF6B6B")
          )
        )
    })

    # Summary of Findings table
    output$sof_table <- renderUI({
      assessments <- grade_assessments()
      req(length(assessments) > 0)
      req(rv$pairwise_results)

      sof_rows <- lapply(names(assessments), function(outcome) {
        grade <- assessments[[outcome]]
        ma_result <- rv$pairwise_results[[outcome]]

        if (!is.null(ma_result)) {
          tags$tr(
            tags$td(strong(outcome)),
            tags$td(sprintf("%.2f (%.2f to %.2f)",
                            ma_result$pooled_effect,
                            ma_result$ci_lower,
                            ma_result$ci_upper)),
            tags$td(sprintf("%d studies", ma_result$n_studies)),
            tags$td(
              style = sprintf("background-color: %s;",
                              switch(grade$final_quality,
                                     "High" = "#90EE90",
                                     "Moderate" = "#87CEEB",
                                     "Low" = "#FFD700",
                                     "Very Low" = "#FF6B6B")),
              grade$final_quality
            ),
            tags$td(create_grade_reasoning_text(grade))
          )
        }
      })

      tags$table(
        class = "table table-bordered table-sm",
        tags$thead(
          tags$tr(
            tags$th("Outcome"),
            tags$th("Effect Estimate (95% CI)"),
            tags$th("№ of Studies"),
            tags$th("Quality of Evidence"),
            tags$th("Comments")
          )
        ),
        tags$tbody(
          sof_rows
        )
      )
    })

    # Quality across outcomes plot
    output$quality_plot <- renderPlot({
      assessments <- grade_assessments()
      req(length(assessments) > 0)

      quality_df <- do.call(rbind, lapply(names(assessments), function(outcome) {
        grade <- assessments[[outcome]]
        data.frame(
          Outcome = outcome,
          Quality = factor(grade$final_quality,
                           levels = c("Very Low", "Low", "Moderate", "High")),
          stringsAsFactors = FALSE
        )
      }))

      ggplot(quality_df, aes(x = Outcome, y = 1, fill = Quality)) +
        geom_tile(color = "white", size = 1.5, height = 0.8) +
        scale_fill_manual(values = c(
          "Very Low" = "#FF6B6B",
          "Low" = "#FFD700",
          "Moderate" = "#87CEEB",
          "High" = "#90EE90"
        )) +
        labs(
          title = "Quality of Evidence Across Outcomes",
          subtitle = "GRADE assessment",
          x = "",
          y = ""
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(size = 14, face = "bold"),
          axis.text.y = element_blank(),
          axis.ticks.y = element_blank(),
          panel.grid = element_blank(),
          legend.position = "bottom"
        ) +
        coord_flip()
    })

    # Quality summary text
    output$quality_summary_text <- renderPrint({
      assessments <- grade_assessments()
      req(length(assessments) > 0)

      qualities <- sapply(assessments, function(x) x$final_quality)

      cat("QUALITY SUMMARY ACROSS OUTCOMES\n")
      cat("================================\n\n")
      cat(sprintf("Total outcomes assessed: %d\n\n", length(qualities)))
      cat("Distribution:\n")
      cat(sprintf("  High quality: %d (%.0f%%)\n",
                  sum(qualities == "High"), 100 * mean(qualities == "High")))
      cat(sprintf("  Moderate quality: %d (%.0f%%)\n",
                  sum(qualities == "Moderate"), 100 * mean(qualities == "Moderate")))
      cat(sprintf("  Low quality: %d (%.0f%%)\n",
                  sum(qualities == "Low"), 100 * mean(qualities == "Low")))
      cat(sprintf("  Very low quality: %d (%.0f%%)\n",
                  sum(qualities == "Very Low"), 100 * mean(qualities == "Very Low")))
    })

    # Download evidence profile
    output$download_profile <- downloadHandler(
      filename = function() {
        paste0("grade_evidence_profile_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        assessments <- grade_assessments()
        profile_df <- do.call(rbind, lapply(names(assessments), function(outcome) {
          grade <- assessments[[outcome]]
          data.frame(
            Outcome = outcome,
            Starting_Quality = grade$starting_quality,
            RoB_Downgrade = grade$rob_downgrade,
            RoB_Rationale = grade$rob_rationale,
            Inconsistency_Downgrade = grade$inconsistency_downgrade,
            Inconsistency_Rationale = grade$inconsistency_rationale,
            Indirectness_Downgrade = grade$indirectness_downgrade,
            Indirectness_Rationale = grade$indirectness_rationale,
            Imprecision_Downgrade = grade$imprecision_downgrade,
            Imprecision_Rationale = grade$imprecision_rationale,
            Publication_Bias_Downgrade = grade$publication_bias_downgrade,
            Publication_Bias_Rationale = grade$publication_bias_rationale,
            Final_Quality = grade$final_quality,
            stringsAsFactors = FALSE
          )
        }))
        write.csv(profile_df, file, row.names = FALSE)
      }
    )

    return(reactive(grade_assessments()))
  })
}

# Helper function: Calculate final GRADE quality
calculate_final_grade_quality <- function(starting, downgrades, upgrades) {
  # Quality levels: 4 = High, 3 = Moderate, 2 = Low, 1 = Very Low
  start_level <- if (starting == "High") 4 else 2

  final_level <- start_level + downgrades + upgrades

  # Cap at 1-4
  final_level <- max(1, min(4, final_level))

  c("Very Low", "Low", "Moderate", "High")[final_level]
}

# Helper function: Format GRADE domain for table
format_grade_domain <- function(downgrade) {
  if (downgrade == 0) {
    "Not serious"
  } else if (downgrade == -1) {
    "Serious ↓"
  } else {
    "Very serious ↓↓"
  }
}

# Helper function: Create reasoning text for SoF table
create_grade_reasoning_text <- function(grade) {
  reasons <- c()
  if (grade$rob_downgrade != 0) reasons <- c(reasons, "risk of bias")
  if (grade$inconsistency_downgrade != 0) reasons <- c(reasons, "inconsistency")
  if (grade$indirectness_downgrade != 0) reasons <- c(reasons, "indirectness")
  if (grade$imprecision_downgrade != 0) reasons <- c(reasons, "imprecision")
  if (grade$publication_bias_downgrade != 0) reasons <- c(reasons, "publication bias")

  if (length(reasons) > 0) {
    paste("Downgraded for:", paste(reasons, collapse = ", "))
  } else {
    "No serious concerns"
  }
}
