# GRADE Assessment Module
# Grading of Recommendations, Assessment, Development and Evaluations
# Implements GRADE framework for assessing certainty of evidence
# Reference: Guyatt et al. (2011) BMJ; GRADE Working Group guidelines

library(shiny)
library(bslib)
library(DT)
library(ggplot2)


#' UI for GRADE Assessment Module
#'
#' @param id Module namespace ID
#' @export
grade_assessment_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("🎓 GRADE Assessment"),
    p("Systematic assessment of certainty of evidence using GRADE methodology"),

    # Info box
    card(
      card_header("About GRADE"),
      card_body(
        p(
          "GRADE (Grading of Recommendations, Assessment, Development and Evaluations) ",
          "is a systematic approach to rating the certainty of evidence in systematic reviews.",
          br(),
          "Evidence starts at HIGH (RCTs) or LOW (observational) and can be downgraded or upgraded ",
          "based on specific criteria."
        ),
        layout_columns(
          col_widths = c(6, 6),
          div(
            h5("⬇️ Downgrade for:"),
            tags$ul(
              tags$li("Risk of bias"),
              tags$li("Inconsistency"),
              tags$li("Indirectness"),
              tags$li("Imprecision"),
              tags$li("Publication bias")
            )
          ),
          div(
            h5("⬆️ Upgrade for:"),
            tags$ul(
              tags$li("Large effect"),
              tags$li("Dose-response gradient"),
              tags$li("All plausible confounding would reduce effect")
            )
          )
        )
      )
    ),

    # Outcome selection
    card(
      card_header("Select Outcome"),
      card_body(
        layout_columns(
          col_widths = c(8, 4),
          selectInput(ns("outcome"), "Outcome to Assess:",
                     choices = NULL),
          actionButton(ns("start_assessment"), "Start Assessment",
                      class = "btn-primary", icon = icon("play"))
        )
      )
    ),

    # Assessment panels
    conditionalPanel(
      condition = sprintf("input['%s'] > 0", ns("start_assessment")),
      ns = ns,

      # Step 1: Initial certainty
      card(
        card_header("Step 1: Initial Certainty of Evidence"),
        card_body(
          radioButtons(ns("initial_certainty"), "Study Design:",
                      choices = c(
                        "Randomized Controlled Trials (start at HIGH)" = "rct",
                        "Observational Studies (start at LOW)" = "observational",
                        "Case Series/Reports (start at VERY LOW)" = "case_series"
                      ),
                      selected = "rct"),
          helpText("RCTs start at HIGH certainty; observational studies start at LOW")
        )
      ),

      # Step 2: Downgrading factors
      card(
        card_header("Step 2: Assess Downgrading Factors"),
        card_body(
          # Risk of Bias
          h5("1️⃣ Risk of Bias"),
          p("Limitations in study design or execution"),
          radioButtons(ns("rob_downgrade"), NULL,
                      choices = c(
                        "No serious limitations" = "0",
                        "Serious limitations (-1)" = "1",
                        "Very serious limitations (-2)" = "2"
                      ),
                      selected = "0"),
          textAreaInput(ns("rob_rationale"), "Justification:",
                       rows = 2,
                       placeholder = "Explain your rating..."),

          hr(),

          # Inconsistency
          h5("2️⃣ Inconsistency"),
          p("Unexplained heterogeneity or variability in results"),
          radioButtons(ns("inconsistency_downgrade"), NULL,
                      choices = c(
                        "No serious inconsistency" = "0",
                        "Serious inconsistency (-1)" = "1",
                        "Very serious inconsistency (-2)" = "2"
                      ),
                      selected = "0"),
          textAreaInput(ns("inconsistency_rationale"), "Justification:",
                       rows = 2),
          # Auto-detection
          div(
            style = "background-color: #e3f2fd; padding: 10px; border-radius: 5px; margin-top: 10px;",
            h6("📊 Auto-detected Heterogeneity:", style = "margin-top: 0;"),
            textOutput(ns("heterogeneity_info")),
            helpText("I² > 50% may indicate serious inconsistency; I² > 75% very serious")
          ),

          hr(),

          # Indirectness
          h5("3️⃣ Indirectness"),
          p("Differences in PICO (population, intervention, comparator, outcomes)"),
          radioButtons(ns("indirectness_downgrade"), NULL,
                      choices = c(
                        "Direct evidence" = "0",
                        "Some indirectness (-1)" = "1",
                        "Serious indirectness (-2)" = "2"
                      ),
                      selected = "0"),
          textAreaInput(ns("indirectness_rationale"), "Justification:",
                       rows = 2),

          hr(),

          # Imprecision
          h5("4️⃣ Imprecision"),
          p("Wide confidence intervals or few participants/events"),
          radioButtons(ns("imprecision_downgrade"), NULL,
                      choices = c(
                        "Precise estimate" = "0",
                        "Serious imprecision (-1)" = "1",
                        "Very serious imprecision (-2)" = "2"
                      ),
                      selected = "0"),
          textAreaInput(ns("imprecision_rationale"), "Justification:",
                       rows = 2),
          # Auto-detection
          div(
            style = "background-color: #e3f2fd; padding: 10px; border-radius: 5px; margin-top: 10px;",
            h6("📊 Auto-detected Precision:", style = "margin-top: 0;"),
            textOutput(ns("precision_info")),
            helpText("Wide CI crossing 1.0 or small sample size may indicate imprecision")
          ),

          hr(),

          # Publication Bias
          h5("5️⃣ Publication Bias"),
          p("Suspected selective reporting of studies or outcomes"),
          radioButtons(ns("publication_bias_downgrade"), NULL,
                      choices = c(
                        "No suspected publication bias" = "0",
                        "Suspected publication bias (-1)" = "1",
                        "Strong suspicion of publication bias (-2)" = "2"
                      ),
                      selected = "0"),
          textAreaInput(ns("publication_bias_rationale"), "Justification:",
                       rows = 2),
          # Auto-detection
          div(
            style = "background-color: #e3f2fd; padding: 10px; border-radius: 5px; margin-top: 10px;",
            h6("📊 Auto-detected Publication Bias:", style = "margin-top: 0;"),
            textOutput(ns("pub_bias_info")),
            helpText("Egger's test p < 0.10 or funnel plot asymmetry suggests bias")
          )
        )
      ),

      # Step 3: Upgrading factors
      card(
        card_header("Step 3: Assess Upgrading Factors (Observational Studies Only)"),
        card_body(
          p("These factors only apply to observational studies that started at LOW certainty"),

          # Large effect
          h5("⬆️ Large Effect Magnitude"),
          radioButtons(ns("large_effect_upgrade"), NULL,
                      choices = c(
                        "No large effect" = "0",
                        "Large effect (RR > 2 or < 0.5) (+1)" = "1",
                        "Very large effect (RR > 5 or < 0.2) (+2)" = "2"
                      ),
                      selected = "0"),
          textAreaInput(ns("large_effect_rationale"), "Justification:",
                       rows = 2),

          hr(),

          # Dose-response
          h5("⬆️ Dose-Response Gradient"),
          radioButtons(ns("dose_response_upgrade"), NULL,
                      choices = c(
                        "No dose-response gradient" = "0",
                        "Evidence of dose-response (+1)" = "1"
                      ),
                      selected = "0"),
          textAreaInput(ns("dose_response_rationale"), "Justification:",
                       rows = 2),

          hr(),

          # Plausible confounding
          h5("⬆️ All Plausible Confounding Would Reduce Effect"),
          radioButtons(ns("confounding_upgrade"), NULL,
                      choices = c(
                        "Not applicable" = "0",
                        "Plausible confounding would reduce effect (+1)" = "1"
                      ),
                      selected = "0"),
          textAreaInput(ns("confounding_rationale"), "Justification:",
                       rows = 2)
        )
      ),

      # Final assessment
      card(
        card_header("Final GRADE Assessment"),
        card_body(
          actionButton(ns("calculate_grade"), "Calculate Final Grade",
                      class = "btn-success btn-lg", icon = icon("calculator")),
          br(), br(),

          # Results display
          div(
            id = ns("grade_results"),
            layout_columns(
              col_widths = c(4, 8),

              # Grade badge
              div(
                style = "text-align: center; padding: 30px;",
                h3("Final Grade:"),
                uiOutput(ns("final_grade_badge"))
              ),

              # Calculation breakdown
              div(
                h4("Calculation:"),
                verbatimTextOutput(ns("grade_calculation")),
                br(),
                h4("Summary:"),
                verbatimTextOutput(ns("grade_summary"))
              )
            ),

            hr(),

            # Evidence profile table
            h4("Evidence Profile:"),
            DTOutput(ns("evidence_profile")),

            br(),

            # Summary of Findings table
            h4("Summary of Findings:"),
            DTOutput(ns("sof_table")),

            hr(),

            # Action buttons
            layout_columns(
              col_widths = c(4, 4, 4),
              downloadButton(ns("download_grade"), "Download Assessment",
                           style = "width: 100%;"),
              actionButton(ns("save_grade"), "Save Assessment",
                          class = "btn-primary", style = "width: 100%;"),
              actionButton(ns("export_grade_table"), "Export SoF Table",
                          class = "btn-info", style = "width: 100%;")
            )
          )
        )
      )
    ),

    # Saved assessments
    hr(),
    card(
      card_header("Saved GRADE Assessments"),
      card_body(
        DTOutput(ns("saved_grades_table")),
        br(),
        actionButton(ns("load_saved"), "Load Selected", icon = icon("folder-open")),
        actionButton(ns("delete_saved"), "Delete Selected",
                    class = "btn-danger", icon = icon("trash"))
      )
    )
  )
}


#' Server Logic for GRADE Assessment Module
#'
#' @param id Module namespace ID
#' @param rv Reactive values from parent (must contain pairwise_results)
#' @export
grade_assessment_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    grade_result <- reactiveVal(NULL)
    saved_grades <- reactiveVal(list())

    # Update outcome choices
    observe({
      req(rv$pairwise_results)
      outcome_choices <- names(rv$pairwise_results)
      updateSelectInput(session, "outcome", choices = outcome_choices)
    })

    # Load saved assessments
    observeEvent(rv$initialized, {
      loaded_grades <- load_saved_grades()
      saved_grades(loaded_grades)
    })


    # Display heterogeneity info
    output$heterogeneity_info <- renderText({
      req(input$outcome)
      req(rv$pairwise_results)

      ma_result <- rv$pairwise_results[[input$outcome]]
      if (is.null(ma_result)) return("No results available")

      i2 <- ma_result$I2
      tau2 <- ma_result$tau2

      paste0(
        "I² = ", round(i2, 1), "%, ",
        "τ² = ", round(tau2, 3), "\n",
        "Suggestion: ",
        if (i2 < 40) {
          "Low heterogeneity - no downgrade needed"
        } else if (i2 < 75) {
          "Moderate-substantial heterogeneity - consider -1 downgrade"
        } else {
          "Considerable heterogeneity - consider -1 or -2 downgrade"
        }
      )
    })


    # Display precision info
    output$precision_info <- renderText({
      req(input$outcome)
      req(rv$pairwise_results)

      ma_result <- rv$pairwise_results[[input$outcome]]
      if (is.null(ma_result)) return("No results available")

      ci_lower <- ma_result$ci.lb
      ci_upper <- ma_result$ci.ub
      estimate <- ma_result$beta

      ci_width <- ci_upper - ci_lower

      paste0(
        "Pooled estimate: ", round(estimate, 3),
        " (95% CI: ", round(ci_lower, 3), " to ", round(ci_upper, 3), ")\n",
        "CI width: ", round(ci_width, 3), "\n",
        "Total N: ", sum(ma_result$n1 + ma_result$n2, na.rm = TRUE), "\n",
        "Suggestion: ",
        if (ci_width > 0.5 || (estimate > 0 && ci_lower < 0) || (estimate < 0 && ci_upper > 0)) {
          "Wide CI or crosses null - consider -1 or -2 downgrade"
        } else if (sum(ma_result$n1 + ma_result$n2, na.rm = TRUE) < 400) {
          "Small sample size - consider -1 downgrade"
        } else {
          "Adequate precision - no downgrade needed"
        }
      )
    })


    # Display publication bias info
    output$pub_bias_info <- renderText({
      req(input$outcome)
      req(rv$pairwise_results)

      ma_result <- rv$pairwise_results[[input$outcome]]
      if (is.null(ma_result)) return("No results available")

      # Check if Egger's test was run
      if (!is.null(ma_result$egger_p)) {
        egger_p <- ma_result$egger_p
        paste0(
          "Egger's test p = ", format.pval(egger_p, digits = 3), "\n",
          "Suggestion: ",
          if (egger_p < 0.05) {
            "Significant asymmetry - consider -1 or -2 downgrade"
          } else if (egger_p < 0.10) {
            "Borderline asymmetry - consider -1 downgrade"
          } else {
            "No significant asymmetry detected"
          }
        )
      } else {
        "Run publication bias analysis in Meta-Analysis tab first"
      }
    })


    # Calculate final GRADE
    observeEvent(input$calculate_grade, {

      # Starting point
      initial <- switch(input$initial_certainty,
                       rct = 4,           # HIGH
                       observational = 2,  # LOW
                       case_series = 1)    # VERY LOW

      # Downgrading
      downgrade_rob <- as.numeric(input$rob_downgrade)
      downgrade_inconsistency <- as.numeric(input$inconsistency_downgrade)
      downgrade_indirectness <- as.numeric(input$indirectness_downgrade)
      downgrade_imprecision <- as.numeric(input$imprecision_downgrade)
      downgrade_pubias <- as.numeric(input$publication_bias_downgrade)

      total_downgrade <- downgrade_rob + downgrade_inconsistency +
                        downgrade_indirectness + downgrade_imprecision +
                        downgrade_pubias

      # Upgrading (only for observational studies)
      if (input$initial_certainty == "observational") {
        upgrade_effect <- as.numeric(input$large_effect_upgrade)
        upgrade_dose <- as.numeric(input$dose_response_upgrade)
        upgrade_confound <- as.numeric(input$confounding_upgrade)

        total_upgrade <- upgrade_effect + upgrade_dose + upgrade_confound
      } else {
        total_upgrade <- 0
      }

      # Final score
      final_score <- initial - total_downgrade + total_upgrade

      # Ensure within bounds
      final_score <- max(1, min(4, final_score))

      # Convert to grade
      final_grade <- switch(as.character(final_score),
                           "4" = "HIGH",
                           "3" = "MODERATE",
                           "2" = "LOW",
                           "1" = "VERY LOW")

      # Store result
      grade_result(list(
        outcome = input$outcome,
        initial = input$initial_certainty,
        initial_score = initial,
        downgrades = list(
          rob = downgrade_rob,
          inconsistency = downgrade_inconsistency,
          indirectness = downgrade_indirectness,
          imprecision = downgrade_imprecision,
          publication_bias = downgrade_pubias
        ),
        upgrades = list(
          large_effect = if (input$initial_certainty == "observational") as.numeric(input$large_effect_upgrade) else 0,
          dose_response = if (input$initial_certainty == "observational") as.numeric(input$dose_response_upgrade) else 0,
          confounding = if (input$initial_certainty == "observational") as.numeric(input$confounding_upgrade) else 0
        ),
        rationales = list(
          rob = input$rob_rationale,
          inconsistency = input$inconsistency_rationale,
          indirectness = input$indirectness_rationale,
          imprecision = input$imprecision_rationale,
          publication_bias = input$publication_bias_rationale,
          large_effect = input$large_effect_rationale,
          dose_response = input$dose_response_rationale,
          confounding = input$confounding_rationale
        ),
        total_downgrade = total_downgrade,
        total_upgrade = total_upgrade,
        final_score = final_score,
        final_grade = final_grade,
        date = Sys.Date()
      ))

      showNotification(paste("GRADE Assessment Complete:", final_grade), type = "message")
    })


    # Display final grade badge
    output$final_grade_badge <- renderUI({
      req(grade_result())

      grade <- grade_result()$final_grade

      color <- switch(grade,
                     "HIGH" = "success",
                     "MODERATE" = "info",
                     "LOW" = "warning",
                     "VERY LOW" = "danger")

      symbol <- switch(grade,
                      "HIGH" = "⊕⊕⊕⊕",
                      "MODERATE" = "⊕⊕⊕○",
                      "LOW" = "⊕⊕○○",
                      "VERY LOW" = "⊕○○○")

      div(
        style = paste0("font-size: 24px; padding: 20px; background-color: ",
                      switch(color,
                             "success" = "#d4edda",
                             "info" = "#d1ecf1",
                             "warning" = "#fff3cd",
                             "danger" = "#f8d7da"),
                      "; border-radius: 10px; border: 2px solid ",
                      switch(color,
                             "success" = "#28a745",
                             "info" = "#17a2b8",
                             "warning" = "#ffc107",
                             "danger" = "#dc3545")),
        h2(symbol, style = "margin: 0;"),
        h3(grade, style = "margin: 10px 0 0 0;")
      )
    })


    # Grade calculation breakdown
    output$grade_calculation <- renderPrint({
      req(grade_result())

      grade <- grade_result()

      cat("=== GRADE CALCULATION ===\n\n")

      cat("Starting Point:\n")
      cat("  Study design:", switch(grade$initial,
                                   rct = "RCTs",
                                   observational = "Observational",
                                   case_series = "Case series"), "\n")
      cat("  Initial certainty:", c("VERY LOW", "LOW", "MODERATE", "HIGH")[grade$initial_score], "\n\n")

      cat("Downgrading Factors:\n")
      cat("  Risk of bias:       -", grade$downgrades$rob, "\n")
      cat("  Inconsistency:      -", grade$downgrades$inconsistency, "\n")
      cat("  Indirectness:       -", grade$downgrades$indirectness, "\n")
      cat("  Imprecision:        -", grade$downgrades$imprecision, "\n")
      cat("  Publication bias:   -", grade$downgrades$publication_bias, "\n")
      cat("  TOTAL DOWNGRADE:    -", grade$total_downgrade, "\n\n")

      if (grade$total_upgrade > 0) {
        cat("Upgrading Factors:\n")
        cat("  Large effect:       +", grade$upgrades$large_effect, "\n")
        cat("  Dose-response:      +", grade$upgrades$dose_response, "\n")
        cat("  Confounding:        +", grade$upgrades$confounding, "\n")
        cat("  TOTAL UPGRADE:      +", grade$total_upgrade, "\n\n")
      }

      cat("FINAL GRADE:", grade$final_grade, "\n")
      cat("  (Score:", grade$final_score, "/ 4)\n")
    })


    # Grade summary
    output$grade_summary <- renderPrint({
      req(grade_result())

      grade <- grade_result()

      cat("=== GRADE SUMMARY ===\n\n")

      cat("Outcome:", grade$outcome, "\n")
      cat("Certainty:", grade$final_grade, "\n\n")

      cat("Interpretation:\n")
      interpretation <- switch(grade$final_grade,
        "HIGH" = "We are very confident that the true effect lies close to the estimate.",
        "MODERATE" = "We are moderately confident in the effect estimate. The true effect is likely close to the estimate, but there is a possibility it is substantially different.",
        "LOW" = "Our confidence in the effect estimate is limited. The true effect may be substantially different from the estimate.",
        "VERY LOW" = "We have very little confidence in the effect estimate. The true effect is likely to be substantially different from the estimate."
      )
      cat(interpretation, "\n")
    })


    # Evidence profile table
    output$evidence_profile <- renderDT({
      req(grade_result())

      grade <- grade_result()

      profile_df <- data.frame(
        Domain = c("Risk of bias", "Inconsistency", "Indirectness",
                  "Imprecision", "Publication bias"),
        Rating = c(
          switch(as.character(grade$downgrades$rob),
                "0" = "Not serious",
                "1" = "Serious",
                "2" = "Very serious"),
          switch(as.character(grade$downgrades$inconsistency),
                "0" = "Not serious",
                "1" = "Serious",
                "2" = "Very serious"),
          switch(as.character(grade$downgrades$indirectness),
                "0" = "Not serious",
                "1" = "Serious",
                "2" = "Very serious"),
          switch(as.character(grade$downgrades$imprecision),
                "0" = "Not serious",
                "1" = "Serious",
                "2" = "Very serious"),
          switch(as.character(grade$downgrades$publication_bias),
                "0" = "Not detected",
                "1" = "Suspected",
                "2" = "Strongly suspected")
        ),
        Downgrade = c(
          grade$downgrades$rob,
          grade$downgrades$inconsistency,
          grade$downgrades$indirectness,
          grade$downgrades$imprecision,
          grade$downgrades$publication_bias
        ),
        Explanation = c(
          grade$rationales$rob,
          grade$rationales$inconsistency,
          grade$rationales$indirectness,
          grade$rationales$imprecision,
          grade$rationales$publication_bias
        ),
        stringsAsFactors = FALSE
      )

      datatable(
        profile_df,
        options = list(
          pageLength = 5,
          dom = 't',
          columnDefs = list(
            list(width = "150px", targets = 0),
            list(width = "100px", targets = 1),
            list(width = "80px", targets = 2)
          )
        ),
        rownames = FALSE
      )
    })


    # Summary of Findings table
    output$sof_table <- renderDT({
      req(grade_result())
      req(rv$pairwise_results)

      grade <- grade_result()
      ma_result <- rv$pairwise_results[[grade$outcome]]

      sof_df <- data.frame(
        Outcome = grade$outcome,
        `N Studies` = length(ma_result$yi),
        `N Participants` = sum(ma_result$n1 + ma_result$n2, na.rm = TRUE),
        `Effect Estimate` = paste0(round(ma_result$beta, 3),
                                   " (", round(ma_result$ci.lb, 3),
                                   " to ", round(ma_result$ci.ub, 3), ")"),
        `Certainty` = grade$final_grade,
        Interpretation = switch(grade$final_grade,
          "HIGH" = "⊕⊕⊕⊕",
          "MODERATE" = "⊕⊕⊕○",
          "LOW" = "⊕⊕○○",
          "VERY LOW" = "⊕○○○"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )

      datatable(
        sof_df,
        options = list(
          pageLength = 5,
          dom = 't'
        ),
        rownames = FALSE
      )
    })


    # Save assessment
    observeEvent(input$save_grade, {
      req(grade_result())

      current_grades <- saved_grades()
      grade_id <- paste0("grade_", Sys.time())
      current_grades[[grade_id]] <- grade_result()
      saved_grades(current_grades)

      save_grades_to_disk(current_grades)

      showNotification("GRADE assessment saved!", type = "message")
    })


    # Display saved grades
    output$saved_grades_table <- renderDT({
      grades <- saved_grades()

      if (length(grades) == 0) {
        return(data.frame(
          Outcome = character(),
          Grade = character(),
          Date = character()
        ))
      }

      grades_df <- do.call(rbind, lapply(names(grades), function(id) {
        g <- grades[[id]]
        data.frame(
          ID = id,
          Outcome = g$outcome,
          Grade = g$final_grade,
          Date = as.character(g$date),
          stringsAsFactors = FALSE
        )
      }))

      datatable(
        grades_df,
        selection = "single",
        options = list(pageLength = 10),
        rownames = FALSE
      )
    })


    # Download assessment
    output$download_grade <- downloadHandler(
      filename = function() {
        paste0("GRADE_assessment_", Sys.Date(), ".html")
      },
      content = function(file) {
        req(grade_result())

        html_report <- generate_grade_report(grade_result())
        writeLines(html_report, file)
      }
    )

  })
}


# ============================================================================
# Helper Functions
# ============================================================================

#' Load Saved GRADE Assessments
#'
#' @return List of saved assessments
#' @keywords internal
load_saved_grades <- function() {
  grades_file <- "outputs/grade/saved_grades.rds"

  if (file.exists(grades_file)) {
    tryCatch({
      readRDS(grades_file)
    }, error = function(e) {
      list()
    })
  } else {
    list()
  }
}


#' Save GRADE Assessments to Disk
#'
#' @param grades List of GRADE assessments
#' @keywords internal
save_grades_to_disk <- function(grades) {
  grades_dir <- "outputs/grade"
  dir.create(grades_dir, showWarnings = FALSE, recursive = TRUE)

  grades_file <- file.path(grades_dir, "saved_grades.rds")
  saveRDS(grades, grades_file)
}


#' Generate GRADE HTML Report
#'
#' @param grade_result GRADE assessment result
#' @return HTML string
#' @keywords internal
generate_grade_report <- function(grade_result) {

  paste0(
    "<!DOCTYPE html>",
    "<html><head>",
    "<title>GRADE Assessment Report</title>",
    "<style>",
    "body { font-family: Arial, sans-serif; margin: 40px; max-width: 800px; }",
    "h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }",
    "h2 { color: #34495e; margin-top: 30px; }",
    ".grade-badge { font-size: 48px; text-align: center; padding: 30px; ",
    "background-color: #f8f9fa; border-radius: 10px; margin: 20px 0; }",
    "table { border-collapse: collapse; width: 100%; margin: 20px 0; }",
    "th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }",
    "th { background-color: #3498db; color: white; }",
    ".high { background-color: #d4edda; }",
    ".moderate { background-color: #d1ecf1; }",
    ".low { background-color: #fff3cd; }",
    ".very-low { background-color: #f8d7da; }",
    "</style>",
    "</head><body>",

    "<h1>GRADE Assessment Report</h1>",
    "<p><strong>Date:</strong> ", as.character(grade_result$date), "</p>",
    "<p><strong>Outcome:</strong> ", grade_result$outcome, "</p>",

    "<div class='grade-badge'>",
    "<h2 style='margin:0;'>", grade_result$final_grade, "</h2>",
    "</div>",

    "<h2>Assessment Summary</h2>",
    "<p>Starting point: ", switch(grade_result$initial,
                                  rct = "RCTs (HIGH)",
                                  observational = "Observational (LOW)",
                                  case_series = "Case series (VERY LOW)"), "</p>",
    "<p>Total downgrades: -", grade_result$total_downgrade, "</p>",
    "<p>Total upgrades: +", grade_result$total_upgrade, "</p>",

    "</body></html>"
  )
}
