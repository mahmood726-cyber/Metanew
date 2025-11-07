# GRADE (Grading of Recommendations Assessment, Development and Evaluation) Module
# Systematic assessment of certainty of evidence
# Follows GRADE methodology for evidence quality rating

library(shiny)

grade_assessment_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("star-half-alt", class = "me-2"),
          "GRADE Certainty of Evidence Assessment"
        )
      ),

      layout_columns(
        col_widths = c(5, 7),

        # Assessment panel
        card(
          card_header("Evidence Profile"),

          selectInput(ns("outcome_select"), "Select Outcome",
                     choices = NULL),

          hr(),

          h5("1. Study Design (Starting Point)"),
          selectInput(ns("study_design"), "Type of Evidence",
                     choices = c(
                       "Randomized Trials" = "rct",
                       "Observational Studies" = "observational",
                       "Case Series/Case Reports" = "case_series"
                     ),
                     selected = "rct"),

          div(class = "alert alert-info small",
              "• RCTs start at HIGH quality",
              br(),
              "• Observational studies start at LOW quality",
              br(),
              "• Case series start at VERY LOW quality"),

          hr(),

          h5("2. Factors Decreasing Certainty"),

          # Risk of bias
          card(
            card_header("Risk of Bias"),
            sliderInput(ns("rob_rating"), NULL,
                       min = 0, max = 2, value = 0, step = 1,
                       ticks = TRUE),
            div(class = "small text-muted",
                "0 = No serious limitations | 1 = Serious (-1) | 2 = Very serious (-2)")
          ),

          # Inconsistency
          card(
            card_header("Inconsistency (Heterogeneity)"),
            sliderInput(ns("inconsistency_rating"), NULL,
                       min = 0, max = 2, value = 0, step = 1,
                       ticks = TRUE),
            div(class = "small text-muted",
                "Based on I², prediction intervals, visual inspection")
          ),

          # Indirectness
          card(
            card_header("Indirectness"),
            sliderInput(ns("indirectness_rating"), NULL,
                       min = 0, max = 2, value = 0, step = 1,
                       ticks = TRUE),
            div(class = "small text-muted",
                "PICO differences, indirect comparisons, surrogate outcomes")
          ),

          # Imprecision
          card(
            card_header("Imprecision"),
            sliderInput(ns("imprecision_rating"), NULL,
                       min = 0, max = 2, value = 0, step = 1,
                       ticks = TRUE),
            div(class = "small text-muted",
                "Wide CIs, small sample size, few events")
          ),

          # Publication bias
          card(
            card_header("Publication Bias"),
            sliderInput(ns("publication_bias_rating"), NULL,
                       min = 0, max = 2, value = 0, step = 1,
                       ticks = TRUE),
            div(class = "small text-muted",
                "Funnel plot asymmetry, small study effects")
          ),

          hr(),

          h5("3. Factors Increasing Certainty"),
          p(class = "small text-muted", "(Only for observational studies)"),

          checkboxInput(ns("large_effect"), "Large magnitude of effect (RR > 2 or < 0.5)", FALSE),
          checkboxInput(ns("dose_response"), "Dose-response gradient present", FALSE),
          checkboxInput(ns("confounders_reduce"), "All plausible confounders would reduce effect", FALSE),

          hr(),

          actionButton(ns("btn_assess"), "Calculate GRADE Rating",
                      class = "btn-primary w-100",
                      icon = icon("calculator"))
        ),

        # Results panel
        card(
          card_header("GRADE Assessment Results"),

          navset_card_tab(
            nav_panel("Summary",
                     uiOutput(ns("grade_summary"))),
            nav_panel("Evidence Profile",
                     uiOutput(ns("evidence_profile"))),
            nav_panel("SoF Table",
                     uiOutput(ns("sof_table"))),
            nav_panel("Guidance",
                     uiOutput(ns("grade_guidance")))
          )
        )
      )
    )
  )
}

grade_assessment_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    grade_result <- reactiveVal(NULL)

    # Update outcome choices
    observe({
      req(rv$pairwise_results)
      outcomes <- names(rv$pairwise_results)
      updateSelectInput(session, "outcome_select", choices = outcomes)
    })

    # Perform GRADE assessment
    observeEvent(input$btn_assess, {
      req(input$outcome_select)

      # Calculate GRADE rating
      result <- calculate_grade_rating(
        study_design = input$study_design,
        rob = input$rob_rating,
        inconsistency = input$inconsistency_rating,
        indirectness = input$indirectness_rating,
        imprecision = input$imprecision_rating,
        publication_bias = input$publication_bias_rating,
        large_effect = input$large_effect,
        dose_response = input$dose_response,
        confounders_reduce = input$confounders_reduce,
        ma_result = rv$pairwise_results[[input$outcome_select]]
      )

      grade_result(result)
      rv$grade_assessment <- result

      showNotification(
        sprintf("GRADE rating: %s certainty", result$final_rating),
        type = "message"
      )
    })

    # GRADE summary
    output$grade_summary <- renderUI({
      req(grade_result())
      result <- grade_result()

      # Determine color
      rating_color <- switch(result$final_rating,
        "Very low" = "danger",
        "Low" = "warning",
        "Moderate" = "info",
        "High" = "success",
        "secondary"
      )

      # Determine interpretation
      interpretation <- switch(result$final_rating,
        "Very low" = "We have very little confidence in the effect estimate",
        "Low" = "Our confidence in the effect estimate is limited",
        "Moderate" = "We are moderately confident in the effect estimate",
        "High" = "We are very confident that the true effect is close to the estimated effect",
        "Uncertain"
      )

      tagList(
        h3("GRADE Assessment Results"),

        # Final rating badge
        div(
          class = paste0("alert alert-", rating_color, " text-center"),
          h2(
            span(class = paste0("badge bg-", rating_color), result$final_rating),
            " Certainty of Evidence"
          )
        ),

        p(class = "lead", interpretation),

        hr(),

        h4("Rating Breakdown"),

        tags$table(
          class = "table table-bordered",
          tags$tr(
            tags$th("Starting Quality"),
            tags$td(result$starting_quality),
            tags$td(result$starting_score, class = "text-center fw-bold")
          ),
          tags$tr(
            tags$th("Risk of Bias"),
            tags$td(sprintf("-%d", input$rob_rating)),
            tags$td(ifelse(input$rob_rating > 0, icon("arrow-down", class = "text-danger"), "-"))
          ),
          tags$tr(
            tags$th("Inconsistency"),
            tags$td(sprintf("-%d", input$inconsistency_rating)),
            tags$td(ifelse(input$inconsistency_rating > 0, icon("arrow-down", class = "text-danger"), "-"))
          ),
          tags$tr(
            tags$th("Indirectness"),
            tags$td(sprintf("-%d", input$indirectness_rating)),
            tags$td(ifelse(input$indirectness_rating > 0, icon("arrow-down", class = "text-danger"), "-"))
          ),
          tags$tr(
            tags$th("Imprecision"),
            tags$td(sprintf("-%d", input$imprecision_rating)),
            tags$td(ifelse(input$imprecision_rating > 0, icon("arrow-down", class = "text-danger"), "-"))
          ),
          tags$tr(
            tags$th("Publication Bias"),
            tags$td(sprintf("-%d", input$publication_bias_rating)),
            tags$td(ifelse(input$publication_bias_rating > 0, icon("arrow-down", class = "text-danger"), "-"))
          ),
          if (result$upgrade_points > 0) {
            tags$tr(
              tags$th("Upgrades (Observational)"),
              tags$td(sprintf("+%d", result$upgrade_points)),
              tags$td(icon("arrow-up", class = "text-success"))
            )
          },
          tags$tr(
            class = "table-primary fw-bold",
            tags$th("Final Score"),
            tags$td(""),
            tags$td(result$final_score, class = "text-center")
          )
        ),

        hr(),

        h5("Justification"),
        p(result$justification)
      )
    })

    # Evidence profile
    output$evidence_profile <- renderUI({
      req(grade_result())
      result <- grade_result()

      tagList(
        h4("GRADE Evidence Profile"),

        p("Detailed assessment of factors affecting certainty:"),

        # Risk of Bias
        card(
          card_header("Risk of Bias"),
          if (input$rob_rating == 0) {
            div(class = "alert alert-success", icon("check"), " No serious limitations detected")
          } else if (input$rob_rating == 1) {
            div(class = "alert alert-warning", icon("exclamation-triangle"), " Serious limitations present (downgrade -1)")
          } else {
            div(class = "alert alert-danger", icon("times"), " Very serious limitations present (downgrade -2)")
          },
          p(class = "small", result$rob_justification)
        ),

        # Inconsistency
        card(
          card_header("Inconsistency"),
          if (!is.null(result$ma_result)) {
            tagList(
              p(sprintf("I² = %.1f%%", result$ma_result$i_squared)),
              p(sprintf("τ² = %.3f", result$ma_result$tau_squared)),
              if (result$ma_result$i_squared < 40) {
                div(class = "alert alert-success", "Low heterogeneity")
              } else if (result$ma_result$i_squared < 75) {
                div(class = "alert alert-warning", "Moderate heterogeneity - consider downgrading")
              } else {
                div(class = "alert alert-danger", "High heterogeneity - downgrade recommended")
              }
            )
          } else {
            p("Meta-analysis results not available for automated assessment.")
          }
        ),

        # Other domains...
        card(
          card_header("Imprecision"),
          if (!is.null(result$ma_result)) {
            tagList(
              p(sprintf("95%% CI: %.3f to %.3f", exp(result$ma_result$ci_lower), exp(result$ma_result$ci_upper))),
              p(sprintf("Number of studies: %d", result$ma_result$n_studies)),
              if (result$ma_result$n_studies < 5) {
                div(class = "alert alert-warning", "Small number of studies - consider downgrading for imprecision")
              }
            )
          }
        )
      )
    })

    # Summary of Findings (SoF) table
    output$sof_table <- renderUI({
      req(grade_result())
      result <- grade_result()

      tagList(
        h4("Summary of Findings Table"),
        p("GRADE summary table following Cochrane standards:"),

        div(
          class = "table-responsive",
          tags$table(
            class = "table table-bordered table-sm",
            style = "font-size: 0.9em;",

            # Header
            tags$thead(
              class = "table-light",
              tags$tr(
                tags$th("Outcome", style = "width: 20%;"),
                tags$th("Studies (Participants)", style = "width: 15%;"),
                tags$th("Effect Estimate (95% CI)", style = "width: 20%;"),
                tags$th("Absolute Effect", style = "width: 15%;"),
                tags$th("Certainty", style = "width: 15%;"),
                tags$th("Importance", style = "width: 15%;")
              )
            ),

            # Body
            tags$tbody(
              tags$tr(
                tags$td(strong(input$outcome_select)),
                tags$td(
                  if (!is.null(result$ma_result)) {
                    sprintf("%d studies", result$ma_result$n_studies)
                  } else {
                    "N/A"
                  }
                ),
                tags$td(
                  if (!is.null(result$ma_result)) {
                    sprintf("%.3f (%.3f to %.3f)",
                           exp(result$ma_result$pooled_effect),
                           exp(result$ma_result$ci_lower),
                           exp(result$ma_result$ci_upper))
                  } else {
                    "N/A"
                  }
                ),
                tags$td("-"),  # Absolute effect calculation would go here
                tags$td(
                  span(class = paste0("badge bg-", switch(result$final_rating,
                    "Very low" = "danger",
                    "Low" = "warning",
                    "Moderate" = "info",
                    "High" = "success"
                  )), result$final_rating)
                ),
                tags$td("Critical")  # Importance rating
              )
            )
          )
        ),

        hr(),

        h5("Explanatory Footnotes"),
        tags$ol(
          tags$li(result$justification),
          if (input$rob_rating > 0) tags$li("Downgraded for risk of bias"),
          if (input$inconsistency_rating > 0) tags$li("Downgraded for inconsistency"),
          if (input$indirectness_rating > 0) tags$li("Downgraded for indirectness"),
          if (input$imprecision_rating > 0) tags$li("Downgraded for imprecision"),
          if (input$publication_bias_rating > 0) tags$li("Downgraded for publication bias")
        )
      )
    })

    # GRADE guidance
    output$grade_guidance <- renderUI({
      tagList(
        h4("GRADE Methodology Guidance"),

        card(
          card_header("Assessment Criteria"),

          h5("Risk of Bias"),
          tags$ul(
            tags$li("Review individual study ROB assessments"),
            tags$li("Consider: randomization, allocation concealment, blinding, incomplete data"),
            tags$li("Downgrade if most information comes from studies with high/unclear ROB")
          ),

          h5("Inconsistency"),
          tags$ul(
            tags$li("I² > 50-60% suggests important inconsistency"),
            tags$li("Wide prediction intervals"),
            tags$li("Point estimates and CIs show poor overlap"),
            tags$li("Statistical test for heterogeneity (p < 0.10)")
          ),

          h5("Indirectness"),
          tags$ul(
            tags$li("Population differs from target (age, disease severity)"),
            tags$li("Intervention differs from question of interest"),
            tags$li("Comparator not relevant to decision"),
            tags$li("Indirect comparison (no head-to-head trials)"),
            tags$li("Surrogate outcomes used")
          ),

          h5("Imprecision"),
          tags$ul(
            tags$li("Small sample size (< 400 for dichotomous outcomes)"),
            tags$li("Few events (< 300)"),
            tags$li("CI crosses clinically important thresholds"),
            tags$li("CI includes both benefit and harm")
          ),

          h5("Publication Bias"),
          tags$ul(
            tags$li("Asymmetry in funnel plot"),
            tags$li("Known unpublished studies"),
            tags$li("High risk of selective reporting"),
            tags$li("Industry funding without independent analysis")
          )
        ),

        card(
          card_header("Upgrades (Observational Studies Only)"),

          tags$ul(
            tags$li(strong("Large effect: "), "RR > 2 or < 0.5 (+1); RR > 5 or < 0.2 (+2)"),
            tags$li(strong("Dose-response: "), "Clear gradient observed (+1)"),
            tags$li(strong("Confounding: "), "All plausible confounding would reduce effect (+1)")
          )
        )
      )
    })

    return(reactive(grade_result()))
  })
}

#' Calculate GRADE rating
#' @param ... GRADE assessment parameters
#' @return List with GRADE results
calculate_grade_rating <- function(study_design, rob, inconsistency, indirectness,
                                    imprecision, publication_bias,
                                    large_effect = FALSE, dose_response = FALSE,
                                    confounders_reduce = FALSE, ma_result = NULL) {

  # Starting quality based on study design
  starting_score <- switch(study_design,
    "rct" = 4,              # High
    "observational" = 2,     # Low
    "case_series" = 1,      # Very low
    2
  )

  starting_quality <- switch(study_design,
    "rct" = "HIGH",
    "observational" = "LOW",
    "case_series" = "VERY LOW",
    "LOW"
  )

  # Apply downgrades
  final_score <- starting_score - rob - inconsistency - indirectness - imprecision - publication_bias

  # Apply upgrades (only for observational studies)
  upgrade_points <- 0
  if (study_design == "observational") {
    if (large_effect) upgrade_points <- upgrade_points + 1
    if (dose_response) upgrade_points <- upgrade_points + 1
    if (confounders_reduce) upgrade_points <- upgrade_points + 1
    final_score <- final_score + upgrade_points
  }

  # Ensure score stays within bounds
  final_score <- max(1, min(4, final_score))

  # Convert score to rating
  final_rating <- switch(as.character(final_score),
    "4" = "High",
    "3" = "Moderate",
    "2" = "Low",
    "1" = "Very low",
    "Low"
  )

  # Generate justification
  justification <- generate_grade_justification(
    study_design, rob, inconsistency, indirectness, imprecision, publication_bias,
    large_effect, dose_response, confounders_reduce, final_rating
  )

  # ROB justification
  rob_justification <- if (rob == 0) {
    "No serious risk of bias detected in included studies."
  } else if (rob == 1) {
    "Some concerns about risk of bias due to potential issues with randomization, blinding, or selective reporting."
  } else {
    "Serious risk of bias concerns. Most evidence comes from studies at high risk of bias."
  }

  list(
    starting_quality = starting_quality,
    starting_score = starting_score,
    final_rating = final_rating,
    final_score = final_score,
    upgrade_points = upgrade_points,
    justification = justification,
    rob_justification = rob_justification,
    ma_result = ma_result
  )
}

#' Generate GRADE justification text
generate_grade_justification <- function(study_design, rob, inconsistency, indirectness,
                                         imprecision, publication_bias,
                                         large_effect, dose_response, confounders_reduce,
                                         final_rating) {

  components <- c()

  if (study_design == "rct") {
    components <- c(components, "Started with high-quality randomized trial evidence")
  } else if (study_design == "observational") {
    components <- c(components, "Started with low-quality observational study evidence")
  }

  if (rob > 0) {
    components <- c(components, sprintf("downgraded %d level(s) for risk of bias", rob))
  }
  if (inconsistency > 0) {
    components <- c(components, sprintf("downgraded %d level(s) for inconsistency", inconsistency))
  }
  if (indirectness > 0) {
    components <- c(components, sprintf("downgraded %d level(s) for indirectness", indirectness))
  }
  if (imprecision > 0) {
    components <- c(components, sprintf("downgraded %d level(s) for imprecision", imprecision))
  }
  if (publication_bias > 0) {
    components <- c(components, sprintf("downgraded %d level(s) for publication bias", publication_bias))
  }

  if (study_design == "observational") {
    if (large_effect) {
      components <- c(components, "upgraded 1 level for large magnitude of effect")
    }
    if (dose_response) {
      components <- c(components, "upgraded 1 level for dose-response gradient")
    }
    if (confounders_reduce) {
      components <- c(components, "upgraded 1 level as confounders would reduce observed effect")
    }
  }

  paste(components, collapse = "; ") %>%
    paste0(". Final rating: ", final_rating, " certainty of evidence.")
}
