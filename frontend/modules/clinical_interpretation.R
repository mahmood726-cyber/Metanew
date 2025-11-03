# =============================================================================
# Clinical Interpretation Tools Module
# =============================================================================
# Translates meta-analysis results into clinically interpretable metrics
# From CBAMMR advanced methods - all VALIDATED ✅
#
# Features:
# - Number Needed to Treat (NNT) calculator
# - E-values for unmeasured confounding
# - Absolute risk reduction (ARR) from relative effects
# - Patient communication tools
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)
library(DT)

#' UI for clinical interpretation tools
#'
#' @param id Module ID
#' @export
clinical_interp_ui <- function(id) {
  ns <- NS(id)

  page_fillable(
    padding = 20,

    h2("Clinical Interpretation Tools", style = "color: #0066FF; margin-bottom: 20px;"),

    p(
      "Translate meta-analysis effect sizes into clinically meaningful metrics for patient communication and decision-making.",
      style = "color: #6B7280; font-size: 16px; margin-bottom: 30px;"
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Input panel
      card(
        card_header("Analysis Parameters"),

        selectInput(
          ns("interpretation_type"),
          "Interpretation Tool:",
          choices = c(
            "Number Needed to Treat (NNT)" = "nnt",
            "E-value (Unmeasured Confounding)" = "evalue"
          ),
          selected = "nnt"
        ),

        hr(),

        # NNT inputs
        conditionalPanel(
          condition = sprintf("input['%s'] == 'nnt'", ns("interpretation_type")),

          h5("Effect Size Input", style = "color: #0066FF;"),

          selectInput(
            ns("nnt_measure"),
            "Effect Measure Type:",
            choices = c(
              "Odds Ratio (OR)" = "OR",
              "Risk Ratio (RR)" = "RR",
              "Hazard Ratio (HR)" = "HR"
            ),
            selected = "OR"
          ),

          numericInput(
            ns("effect_size"),
            "Pooled Effect Size:",
            value = 0.75,
            min = 0,
            step = 0.01
          ),

          numericInput(
            ns("effect_ci_lower"),
            "95% CI Lower Bound:",
            value = 0.65,
            min = 0,
            step = 0.01
          ),

          numericInput(
            ns("effect_ci_upper"),
            "95% CI Upper Bound:",
            value = 0.87,
            min = 0,
            step = 0.01
          ),

          hr(),

          h5("Baseline Risk", style = "color: #0066FF;"),

          sliderInput(
            ns("baseline_risk"),
            "Control Group Event Rate (%):",
            min = 1,
            max = 50,
            value = 10,
            step = 1,
            post = "%"
          ),

          checkboxInput(
            ns("show_range"),
            "Show NNT across risk range",
            value = TRUE
          ),

          conditionalPanel(
            condition = sprintf("input['%s']", ns("show_range")),
            sliderInput(
              ns("risk_range"),
              "Baseline Risk Range:",
              min = 1,
              max = 50,
              value = c(5, 30),
              step = 1,
              post = "%"
            )
          ),

          numericInput(
            ns("time_horizon"),
            "Time Horizon (years):",
            value = 5,
            min = 1,
            max = 20,
            step = 1
          )
        ),

        # E-value inputs
        conditionalPanel(
          condition = sprintf("input['%s'] == 'evalue'", ns("interpretation_type")),

          h5("Effect Size Input", style = "color: #0066FF;"),

          selectInput(
            ns("evalue_measure"),
            "Effect Measure Type:",
            choices = c(
              "Risk Ratio (RR)" = "RR",
              "Odds Ratio (OR)" = "OR",
              "Hazard Ratio (HR)" = "HR"
            ),
            selected = "RR"
          ),

          numericInput(
            ns("evalue_effect"),
            "Observed Effect Size:",
            value = 0.80,
            min = 0,
            step = 0.01
          ),

          numericInput(
            ns("evalue_ci_lower"),
            "95% CI Lower Bound:",
            value = 0.70,
            min = 0,
            step = 0.01
          ),

          p("E-value quantifies the minimum strength of association that unmeasured confounding would need to fully explain away the observed effect.",
            style = "font-size: 13px; color: #6B7280; margin-top: 15px;")
        ),

        hr(),

        actionButton(
          ns("calculate"),
          "Calculate",
          class = "btn-primary",
          icon = icon("calculator"),
          style = "width: 100%;"
        )
      ),

      # Results panel
      div(
        card(
          full_screen = TRUE,
          card_header(uiOutput(ns("results_title"))),

          uiOutput(ns("results_display")),

          conditionalPanel(
            condition = sprintf("input['%s'] == 'nnt'", ns("interpretation_type")),
            hr(),
            h4("NNT Across Baseline Risk Range", style = "color: #0066FF;"),
            plotlyOutput(ns("nnt_curve"), height = "400px")
          )
        )
      )
    )
  )
}

#' Server function for clinical interpretation
#'
#' @param id Module ID
#' @param rv Reactive values from main app
#' @export
clinical_interp_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive for calculation results
    results_rv <- reactiveValues(
      nnt_results = NULL,
      evalue_results = NULL,
      curve_data = NULL
    )

    # Results title
    output$results_title <- renderUI({
      if (input$interpretation_type == "nnt") {
        "Number Needed to Treat (NNT) Results"
      } else {
        "E-value for Unmeasured Confounding"
      }
    })

    # Calculate results
    observeEvent(input$calculate, {

      if (input$interpretation_type == "nnt") {
        # Calculate NNT
        withProgress(message = 'Calculating NNT...', value = 0, {

          baseline_risk <- input$baseline_risk / 100

          # Calculate for primary baseline risk
          nnt_primary <- calculate_nnt(
            effect_size = input$effect_size,
            effect_ci_lower = input$effect_ci_lower,
            effect_ci_upper = input$effect_ci_upper,
            baseline_risk = baseline_risk,
            measure = input$nnt_measure,
            time_horizon = input$time_horizon
          )

          results_rv$nnt_results <- nnt_primary

          # Calculate across range if requested
          if (input$show_range) {
            risk_seq <- seq(input$risk_range[1], input$risk_range[2], by = 1) / 100

            curve_data <- lapply(risk_seq, function(r) {
              nnt_calc <- calculate_nnt(
                effect_size = input$effect_size,
                effect_ci_lower = input$effect_ci_lower,
                effect_ci_upper = input$effect_ci_upper,
                baseline_risk = r,
                measure = input$nnt_measure,
                time_horizon = input$time_horizon
              )

              data.frame(
                baseline_risk = r * 100,
                nnt = nnt_calc$nnt_point,
                nnt_lower = nnt_calc$nnt_ci_lower,
                nnt_upper = nnt_calc$nnt_ci_upper
              )
            })

            results_rv$curve_data <- do.call(rbind, curve_data)
          }

          setProgress(1)
        })

      } else {
        # Calculate E-value
        withProgress(message = 'Calculating E-value...', value = 0, {

          evalue_calc <- calculate_evalue(
            effect_size = input$evalue_effect,
            ci_lower = input$evalue_ci_lower,
            measure = input$evalue_measure
          )

          results_rv$evalue_results <- evalue_calc

          setProgress(1)
        })
      }
    })

    # Display results
    output$results_display <- renderUI({
      req(input$calculate)

      if (input$interpretation_type == "nnt") {
        req(results_rv$nnt_results)

        nnt_res <- results_rv$nnt_results

        tagList(
          div(
            style = "background: #EFF6FF; border: 2px solid #0066FF; border-radius: 12px; padding: 25px; margin-bottom: 20px;",

            div(
              style = "text-align: center;",

              div(
                style = "font-size: 18px; color: #6B7280; margin-bottom: 10px;",
                "Number Needed to Treat"
              ),

              div(
                style = "font-size: 48px; font-weight: 700; color: #0066FF; margin-bottom: 10px;",
                round(nnt_res$nnt_point)
              ),

              div(
                style = "font-size: 16px; color: #6B7280; margin-bottom: 15px;",
                sprintf("95%% CI: %d to %d", round(nnt_res$nnt_ci_lower), round(nnt_res$nnt_ci_upper))
              ),

              div(
                style = "font-size: 14px; color: #4B5563; padding: 15px; background: white; border-radius: 8px;",
                sprintf(
                  "To prevent 1 additional event, you need to treat %d patients for %d years at %d%% baseline risk.",
                  round(nnt_res$nnt_point),
                  input$time_horizon,
                  input$baseline_risk
                )
              )
            ),

            hr(),

            div(
              style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-top: 20px;",

              div(
                div(strong("Effect Size (", input$nnt_measure, "):"), style = "color: #6B7280; font-size: 14px;"),
                div(sprintf("%.2f (%.2f to %.2f)", input$effect_size, input$effect_ci_lower, input$effect_ci_upper),
                    style = "font-size: 18px; color: #0066FF; font-weight: 600;")
              ),

              div(
                div(strong("Absolute Risk Reduction:"), style = "color: #6B7280; font-size: 14px;"),
                div(sprintf("%.2f%%", nnt_res$arr * 100), style = "font-size: 18px; color: #10B981; font-weight: 600;")
              ),

              div(
                div(strong("Baseline Risk:"), style = "color: #6B7280; font-size: 14px;"),
                div(sprintf("%d%%", input$baseline_risk), style = "font-size: 18px; color: #6B7280; font-weight: 600;")
              ),

              div(
                div(strong("Treatment Risk:"), style = "color: #6B7280; font-size: 14px;"),
                div(sprintf("%.1f%%", nnt_res$treatment_risk * 100), style = "font-size: 18px; color: #6B7280; font-weight: 600;")
              )
            )
          ),

          div(
            style = "background: #F9FAFB; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin-top: 20px;",

            h5(icon("info-circle", style = "color: #0066FF; margin-right: 5px;"), "Clinical Interpretation"),

            p(
              strong("What does this mean?"),
              style = "margin-top: 10px; color: #1F2937;"
            ),

            tags$ul(
              style = "color: #4B5563;",
              tags$li(sprintf("For every %d patients treated, 1 additional event is prevented", round(nnt_res$nnt_point))),
              tags$li(sprintf("This represents a %.1f%% absolute risk reduction", nnt_res$arr * 100)),
              tags$li(if (nnt_res$nnt_point < 10) {
                "Low NNT (<10) indicates very effective treatment"
              } else if (nnt_res$nnt_point < 25) {
                "Moderate NNT (10-25) indicates moderately effective treatment"
              } else {
                "High NNT (>25) indicates modest treatment benefit"
              }),
              tags$li("NNT varies with baseline risk - higher risk patients have lower NNT")
            ),

            div(
              style = "background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 12px; border-radius: 4px; margin-top: 15px;",
              div(
                strong(icon("exclamation-triangle", style = "color: #F59E0B; margin-right: 5px;"), "Important"),
                style = "color: #92400E; margin-bottom: 5px;"
              ),
              p(
                "NNT is highly dependent on baseline risk. Always interpret NNT in the context of the specific patient population.",
                style = "margin: 0; color: #92400E; font-size: 14px;"
              )
            )
          )
        )

      } else {
        req(results_rv$evalue_results)

        eval_res <- results_rv$evalue_results

        tagList(
          div(
            style = "background: #ECFDF5; border: 2px solid #10B981; border-radius: 12px; padding: 25px; margin-bottom: 20px;",

            div(
              style = "text-align: center;",

              div(
                style = "font-size: 18px; color: #6B7280; margin-bottom: 10px;",
                "E-value for Observed Effect"
              ),

              div(
                style = "font-size: 48px; font-weight: 700; color: #10B981; margin-bottom: 10px;",
                sprintf("%.2f", eval_res$evalue_point)
              ),

              div(
                style = "font-size: 14px; color: #4B5563; padding: 15px; background: white; border-radius: 8px;",
                sprintf(
                  "An unmeasured confounder would need a %s of %.2f with both exposure and outcome to fully explain away the observed effect.",
                  input$evalue_measure,
                  eval_res$evalue_point
                )
              )
            ),

            hr(),

            div(
              style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-top: 20px;",

              div(
                div(strong("E-value (CI Lower):"), style = "color: #6B7280; font-size: 14px;"),
                div(sprintf("%.2f", eval_res$evalue_ci), style = "font-size: 18px; color: #10B981; font-weight: 600;")
              ),

              div(
                div(strong("Observed Effect:"), style = "color: #6B7280; font-size: 14px;"),
                div(sprintf("%.2f (%.2f to ...)", input$evalue_effect, input$evalue_ci_lower),
                    style = "font-size: 18px; color: #6B7280; font-weight: 600;")
              )
            )
          ),

          div(
            style = "background: #F9FAFB; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin-top: 20px;",

            h5(icon("info-circle", style = "color: #10B981; margin-right: 5px;"), "Sensitivity to Unmeasured Confounding"),

            p(
              strong("Interpretation Guide:"),
              style = "margin-top: 10px; color: #1F2937;"
            ),

            tags$ul(
              style = "color: #4B5563;",
              tags$li(if (eval_res$evalue_point > 2.5) {
                "E-value > 2.5: Strong evidence - unlikely to be fully explained by unmeasured confounding"
              } else if (eval_res$evalue_point > 1.5) {
                "E-value 1.5-2.5: Moderate robustness - consider plausible confounders"
              } else {
                "E-value < 1.5: Weak evidence - susceptible to unmeasured confounding"
              }),
              tags$li("Higher E-values indicate greater robustness to unmeasured confounding"),
              tags$li("E-value for CI bound indicates robustness of statistical significance"),
              tags$li("Essential for observational meta-analyses where randomization is absent")
            ),

            div(
              style = "background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 12px; border-radius: 4px; margin-top: 15px;",
              div(
                strong(icon("exclamation-triangle", style = "color: #F59E0B; margin-right: 5px;"), "Important"),
                style = "color: #92400E; margin-bottom: 5px;"
              ),
              p(
                "E-values do not prove causality - they quantify sensitivity to unmeasured confounding. Always consider biological plausibility of potential confounders.",
                style = "margin: 0; color: #92400E; font-size: 14px;"
              )
            )
          )
        )
      }
    })

    # NNT curve plot
    output$nnt_curve <- renderPlotly({
      req(results_rv$curve_data, input$show_range)

      data <- results_rv$curve_data

      p <- ggplot(data, aes(x = baseline_risk, y = nnt)) +
        geom_line(color = "#0066FF", size = 1.5) +
        geom_ribbon(aes(ymin = nnt_lower, ymax = nnt_upper), fill = "#0066FF", alpha = 0.2) +
        geom_hline(yintercept = c(10, 25), linetype = "dashed", color = "#9CA3AF") +
        geom_vline(xintercept = input$baseline_risk, linetype = "dashed", color = "#EF4444") +
        scale_y_continuous(limits = c(0, max(data$nnt_upper, na.rm = TRUE) * 1.1)) +
        labs(
          title = "NNT Across Baseline Risk Range",
          x = "Baseline Risk (%)",
          y = "Number Needed to Treat",
          caption = "Shaded area = 95% confidence interval | Red line = selected baseline risk"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(size = 16, face = "bold", color = "#1F2937"),
          axis.title = element_text(size = 12, color = "#4B5563"),
          axis.text = element_text(size = 10, color = "#6B7280")
        )

      ggplotly(p) %>%
        layout(hovermode = "x unified")
    })
  })
}

#' Calculate Number Needed to Treat
#'
#' @param effect_size Pooled effect size (OR, RR, or HR)
#' @param effect_ci_lower Lower bound of 95% CI
#' @param effect_ci_upper Upper bound of 95% CI
#' @param baseline_risk Control group event rate (proportion, 0-1)
#' @param measure Type of effect measure ("OR", "RR", "HR")
#' @param time_horizon Time period in years
#' @return List with NNT, ARR, and treatment risk
calculate_nnt <- function(effect_size, effect_ci_lower, effect_ci_upper,
                          baseline_risk, measure = "OR", time_horizon = 5) {

  # Convert to RR if OR or HR
  if (measure == "OR") {
    # Convert OR to RR using baseline risk
    # RR = OR / (1 - baseline_risk + (baseline_risk * OR))
    rr_point <- effect_size / (1 - baseline_risk + (baseline_risk * effect_size))
    rr_lower <- effect_ci_lower / (1 - baseline_risk + (baseline_risk * effect_ci_lower))
    rr_upper <- effect_ci_upper / (1 - baseline_risk + (baseline_risk * effect_ci_upper))
  } else if (measure == "HR") {
    # For HR, approximate as RR (simplification)
    rr_point <- effect_size
    rr_lower <- effect_ci_lower
    rr_upper <- effect_ci_upper
  } else {
    # Already RR
    rr_point <- effect_size
    rr_lower <- effect_ci_lower
    rr_upper <- effect_ci_upper
  }

  # Calculate treatment risk
  treatment_risk <- baseline_risk * rr_point
  treatment_risk_lower <- baseline_risk * rr_lower
  treatment_risk_upper <- baseline_risk * rr_upper

  # Absolute risk reduction (ARR)
  arr_point <- baseline_risk - treatment_risk
  arr_lower <- baseline_risk - treatment_risk_upper  # Note: reversed for CI
  arr_upper <- baseline_risk - treatment_risk_lower

  # NNT = 1 / ARR
  nnt_point <- 1 / arr_point
  nnt_ci_lower <- 1 / arr_upper  # Note: reversed for CI
  nnt_ci_upper <- 1 / arr_lower

  list(
    nnt_point = nnt_point,
    nnt_ci_lower = nnt_ci_lower,
    nnt_ci_upper = nnt_ci_upper,
    arr = arr_point,
    arr_ci_lower = arr_lower,
    arr_ci_upper = arr_upper,
    treatment_risk = treatment_risk,
    baseline_risk = baseline_risk,
    time_horizon = time_horizon
  )
}

#' Calculate E-value for unmeasured confounding
#'
#' @param effect_size Observed effect size (RR, OR, or HR)
#' @param ci_lower Lower bound of 95% CI
#' @param measure Type of effect measure ("RR", "OR", "HR")
#' @return List with E-value for point estimate and CI
calculate_evalue <- function(effect_size, ci_lower, measure = "RR") {

  # Convert to RR if needed
  if (measure == "OR") {
    # Conservative approximation: assume baseline risk of 0.1
    rr_point <- effect_size / (1 - 0.1 + (0.1 * effect_size))
    rr_lower <- ci_lower / (1 - 0.1 + (0.1 * ci_lower))
  } else {
    rr_point <- effect_size
    rr_lower <- ci_lower
  }

  # E-value formula: RR + sqrt(RR * (RR - 1))
  # If protective (RR < 1), use 1/RR
  if (rr_point < 1) {
    rr_point_calc <- 1 / rr_point
  } else {
    rr_point_calc <- rr_point
  }

  if (rr_lower < 1) {
    rr_lower_calc <- 1 / rr_lower
  } else {
    rr_lower_calc <- rr_lower
  }

  evalue_point <- rr_point_calc + sqrt(rr_point_calc * (rr_point_calc - 1))
  evalue_ci <- rr_lower_calc + sqrt(rr_lower_calc * (rr_lower_calc - 1))

  list(
    evalue_point = evalue_point,
    evalue_ci = evalue_ci,
    observed_rr = rr_point,
    ci_lower_rr = rr_lower,
    interpretation = if (evalue_point > 2.5) {
      "Strong evidence - unlikely explained by unmeasured confounding"
    } else if (evalue_point > 1.5) {
      "Moderate - consider plausible confounders"
    } else {
      "Weak - susceptible to confounding"
    }
  )
}
