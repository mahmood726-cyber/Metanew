# =============================================================================
# Power Analysis Tools Module
# =============================================================================
# Comprehensive power and sample size planning for meta-analyses
# Addresses methodologist review: "Power analysis tools would be valuable"
#
# Features:
# - Power calculation for meta-analysis
# - Required number of studies calculation
# - Required total sample size
# - Power curves across effect sizes
# - Heterogeneity impact on power
# - Multiple outcome types (OR, RR, MD, SMD, HR)
# - Protocol planning support
# =============================================================================

library(shiny)
library(bslib)
library(ggplot2)
library(plotly)

#' UI for power analysis
#'
#' @param id Module ID
#' @export
power_analysis_ui <- function(id) {
  ns <- NS(id)

  page_fillable(
    padding = 20,

    h2("Power Analysis & Sample Size Planning", style = "color: #0066FF; margin-bottom: 20px;"),

    p(
      "Plan your systematic review by calculating required number of studies, ",
      "total sample size, and statistical power for detecting clinically meaningful effects.",
      style = "color: #6B7280; font-size: 16px; margin-bottom: 30px;"
    ),

    layout_columns(
      col_widths = c(4, 8),

      # Input panel
      card(
        card_header("Analysis Parameters"),

        selectInput(
          ns("calculation_type"),
          "What do you want to calculate?",
          choices = c(
            "Power (given effect size and # studies)" = "power",
            "Required # of studies (given power and effect)" = "n_studies",
            "Detectable effect size (given power and # studies)" = "effect_size"
          ),
          selected = "power"
        ),

        hr(),

        h5("Effect Measure", style = "color: #0066FF;"),

        selectInput(
          ns("measure"),
          "Outcome Type:",
          choices = c(
            "Odds Ratio (OR)" = "OR",
            "Risk Ratio (RR)" = "RR",
            "Mean Difference (MD)" = "MD",
            "Standardized Mean Difference (SMD)" = "SMD",
            "Hazard Ratio (HR)" = "HR",
            "Correlation (r)" = "COR"
          ),
          selected = "OR"
        ),

        # Conditional inputs based on calculation type
        conditionalPanel(
          condition = sprintf("input['%s'] == 'power'", ns("calculation_type")),

          numericInput(
            ns("power_n_studies"),
            "Expected number of studies:",
            value = 20,
            min = 2,
            max = 500
          ),

          numericInput(
            ns("power_effect_size"),
            "Expected effect size (e.g., OR = 0.75):",
            value = 0.75,
            min = 0,
            step = 0.01
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'n_studies'", ns("calculation_type")),

          sliderInput(
            ns("target_power"),
            "Target power:",
            min = 0.70,
            max = 0.99,
            value = 0.80,
            step = 0.01
          ),

          numericInput(
            ns("nstudies_effect_size"),
            "Minimum detectable effect size:",
            value = 0.75,
            min = 0,
            step = 0.01
          )
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'effect_size'", ns("calculation_type")),

          sliderInput(
            ns("es_target_power"),
            "Target power:",
            min = 0.70,
            max = 0.99,
            value = 0.80,
            step = 0.01
          ),

          numericInput(
            ns("es_n_studies"),
            "Expected number of studies:",
            value = 20,
            min = 2,
            max = 500
          )
        ),

        hr(),

        h5("Study Characteristics", style = "color: #0066FF;"),

        sliderInput(
          ns("avg_n_per_study"),
          "Average sample size per study:",
          min = 20,
          max = 1000,
          value = 100,
          step = 10
        ),

        sliderInput(
          ns("expected_i2"),
          "Expected heterogeneity (I²):",
          min = 0,
          max = 95,
          value = 50,
          step = 5,
          post = "%"
        ),

        sliderInput(
          ns("alpha"),
          "Significance level (α):",
          min = 0.01,
          max = 0.10,
          value = 0.05,
          step = 0.01
        ),

        selectInput(
          ns("test_type"),
          "Statistical test:",
          choices = c(
            "Two-sided" = "two.sided",
            "One-sided (superiority)" = "greater",
            "One-sided (non-inferiority)" = "less"
          ),
          selected = "two.sided"
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
          card_header("Results"),

          uiOutput(ns("power_results")),

          hr(),

          h4("Power Curve", style = "color: #0066FF; margin-top: 20px;"),
          plotlyOutput(ns("power_curve"), height = "400px"),

          hr(),

          h4("Interpretation & Recommendations", style = "color: #0066FF; margin-top: 20px;"),
          uiOutput(ns("interpretation"))
        )
      )
    )
  )
}

#' Server function for power analysis
#'
#' @param id Module ID
#' @param rv Reactive values from main app
#' @export
power_analysis_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive for power calculation results
    power_rv <- reactiveValues(
      results = NULL,
      curve_data = NULL
    )

    # Calculate power/sample size
    observeEvent(input$calculate, {

      withProgress(message = 'Calculating...', value = 0, {

        calc_type <- input$calculation_type
        measure <- input$measure
        alpha <- input$alpha
        i2 <- input$expected_i2 / 100
        avg_n <- input$avg_n_per_study

        # Convert I² to τ² (approximate)
        # τ² = I² / (1 - I²) * typical within-study variance
        tau2 <- (i2 / (1 - i2)) * 0.1  # Rough approximation

        if (calc_type == "power") {
          # Calculate power given n_studies and effect size
          n_studies <- input$power_n_studies
          effect_size <- input$power_effect_size

          # Convert effect size to standardized scale
          theta <- convert_to_theta(effect_size, measure)

          # Calculate power
          power_rv$results <- calculate_meta_power(
            theta = theta,
            n_studies = n_studies,
            avg_n = avg_n,
            tau2 = tau2,
            alpha = alpha,
            test_type = input$test_type
          )

          # Generate power curve across effect sizes
          power_rv$curve_data <- generate_power_curve_effect(
            n_studies = n_studies,
            avg_n = avg_n,
            tau2 = tau2,
            alpha = alpha,
            test_type = input$test_type,
            measure = measure
          )

        } else if (calc_type == "n_studies") {
          # Calculate required n_studies
          target_power <- input$target_power
          effect_size <- input$nstudies_effect_size

          theta <- convert_to_theta(effect_size, measure)

          power_rv$results <- calculate_required_n_studies(
            theta = theta,
            target_power = target_power,
            avg_n = avg_n,
            tau2 = tau2,
            alpha = alpha,
            test_type = input$test_type
          )

          # Generate power curve across number of studies
          power_rv$curve_data <- generate_power_curve_nstudies(
            theta = theta,
            avg_n = avg_n,
            tau2 = tau2,
            alpha = alpha,
            test_type = input$test_type,
            target_power = target_power
          )

        } else if (calc_type == "effect_size") {
          # Calculate minimum detectable effect size
          target_power <- input$es_target_power
          n_studies <- input$es_n_studies

          power_rv$results <- calculate_detectable_effect(
            target_power = target_power,
            n_studies = n_studies,
            avg_n = avg_n,
            tau2 = tau2,
            alpha = alpha,
            test_type = input$test_type,
            measure = measure
          )

          # Generate curve
          power_rv$curve_data <- generate_power_curve_effect(
            n_studies = n_studies,
            avg_n = avg_n,
            tau2 = tau2,
            alpha = alpha,
            test_type = input$test_type,
            measure = measure,
            highlight_power = target_power
          )
        }

        setProgress(1)
      })
    })

    # Render results
    output$power_results <- renderUI({
      req(power_rv$results)

      results <- power_rv$results
      calc_type <- input$calculation_type

      if (calc_type == "power") {
        div(
          style = "background: #EFF6FF; border: 2px solid #0066FF; border-radius: 12px; padding: 25px; margin-bottom: 20px;",

          div(
            style = "text-align: center;",

            div(
              style = "font-size: 18px; color: #6B7280; margin-bottom: 10px;",
              "Statistical Power"
            ),

            div(
              style = "font-size: 48px; font-weight: 700; color: #0066FF; margin-bottom: 10px;",
              sprintf("%.1f%%", results$power * 100)
            ),

            div(
              style = "font-size: 14px; color: #6B7280;",
              sprintf("With %d studies and effect size = %.2f",
                      input$power_n_studies, input$power_effect_size)
            )
          ),

          hr(),

          div(
            style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-top: 20px;",

            div(
              div(strong("Total Sample Size:"), style = "color: #6B7280; font-size: 14px;"),
              div(sprintf("%d participants", results$total_n), style = "font-size: 18px; color: #0066FF; font-weight: 600;")
            ),

            div(
              div(strong("Studies per Group:"), style = "color: #6B7280; font-size: 14px;"),
              div(sprintf("%d studies", input$power_n_studies), style = "font-size: 18px; color: #0066FF; font-weight: 600;")
            ),

            div(
              div(strong("Heterogeneity (I²):"), style = "color: #6B7280; font-size: 14px;"),
              div(sprintf("%d%%", input$expected_i2), style = "font-size: 18px; color: #0066FF; font-weight: 600;")
            ),

            div(
              div(strong("Significance Level:"), style = "color: #6B7280; font-size: 14px;"),
              div(sprintf("α = %.2f", input$alpha), style = "font-size: 18px; color: #0066FF; font-weight: 600;")
            )
          )
        )

      } else if (calc_type == "n_studies") {
        div(
          style = "background: #ECFDF5; border: 2px solid #10B981; border-radius: 12px; padding: 25px; margin-bottom: 20px;",

          div(
            style = "text-align: center;",

            div(
              style = "font-size: 18px; color: #6B7280; margin-bottom: 10px;",
              "Required Number of Studies"
            ),

            div(
              style = "font-size: 48px; font-weight: 700; color: #10B981; margin-bottom: 10px;",
              sprintf("%d studies", results$n_studies_required)
            ),

            div(
              style = "font-size: 14px; color: #6B7280;",
              sprintf("To achieve %.0f%% power for effect size = %.2f",
                      input$target_power * 100, input$nstudies_effect_size)
            )
          ),

          hr(),

          div(
            style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-top: 20px;",

            div(
              div(strong("Total Sample Size:"), style = "color: #6B7280; font-size: 14px;"),
              div(sprintf("%d participants", results$total_n), style = "font-size: 18px; color: #10B981; font-weight: 600;")
            ),

            div(
              div(strong("Per Study:"), style = "color: #6B7280; font-size: 14px;"),
              div(sprintf("%d participants", input$avg_n_per_study), style = "font-size: 18px; color: #10B981; font-weight: 600;")
            )
          )
        )

      } else {
        div(
          style = "background: #FEF3C7; border: 2px solid #F59E0B; border-radius: 12px; padding: 25px; margin-bottom: 20px;",

          div(
            style = "text-align: center;",

            div(
              style = "font-size: 18px; color: #6B7280; margin-bottom: 10px;",
              "Minimum Detectable Effect Size"
            ),

            div(
              style = "font-size: 48px; font-weight: 700; color: #F59E0B; margin-bottom: 10px;",
              sprintf("%.2f", results$min_effect_size)
            ),

            div(
              style = "font-size: 14px; color: #6B7280;",
              sprintf("With %d studies at %.0f%% power",
                      input$es_n_studies, input$es_target_power * 100)
            )
          )
        )
      }
    })

    # Render power curve
    output$power_curve <- renderPlotly({
      req(power_rv$curve_data)

      data <- power_rv$curve_data
      calc_type <- input$calculation_type

      if (calc_type == "power" || calc_type == "effect_size") {
        # Power vs effect size
        p <- ggplot(data, aes(x = effect_size, y = power)) +
          geom_line(color = "#0066FF", size = 1.5) +
          geom_hline(yintercept = 0.80, linetype = "dashed", color = "#EF4444") +
          annotate("text", x = max(data$effect_size) * 0.9, y = 0.82,
                   label = "80% power", color = "#EF4444") +
          scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
          labs(
            title = "Statistical Power Across Effect Sizes",
            x = paste("Effect Size (", input$measure, ")", sep = ""),
            y = "Power"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(size = 16, face = "bold", color = "#1F2937"),
            axis.title = element_text(size = 12, color = "#4B5563"),
            axis.text = element_text(size = 10, color = "#6B7280")
          )

      } else {
        # Power vs number of studies
        p <- ggplot(data, aes(x = n_studies, y = power)) +
          geom_line(color = "#10B981", size = 1.5) +
          geom_hline(yintercept = 0.80, linetype = "dashed", color = "#EF4444") +
          annotate("text", x = max(data$n_studies) * 0.9, y = 0.82,
                   label = "80% power", color = "#EF4444") +
          scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
          labs(
            title = "Statistical Power vs Number of Studies",
            x = "Number of Studies",
            y = "Power"
          ) +
          theme_minimal() +
          theme(
            plot.title = element_text(size = 16, face = "bold", color = "#1F2937"),
            axis.title = element_text(size = 12, color = "#4B5563"),
            axis.text = element_text(size = 10, color = "#6B7280")
          )
      }

      ggplotly(p) %>%
        layout(hovermode = "x unified")
    })

    # Render interpretation
    output$interpretation <- renderUI({
      req(power_rv$results)

      results <- power_rv$results
      calc_type <- input$calculation_type

      recommendations <- list()

      if (calc_type == "power") {
        power <- results$power

        if (power >= 0.80) {
          recommendations <- c(
            "✅ Your meta-analysis is adequately powered (≥80%) to detect the specified effect size.",
            "✅ The planned number of studies should provide reliable estimates.",
            sprintf("• With %d studies, you can detect an effect size of %.2f with %.0f%% confidence.",
                    input$power_n_studies, input$power_effect_size, power * 100)
          )
        } else {
          recommendations <- c(
            "⚠️ Your meta-analysis may be underpowered (<80%) for the specified effect size.",
            sprintf("• Current power: %.0f%% (target: 80%%)", power * 100),
            sprintf("• Consider searching for more studies or adjusting minimum effect size threshold."),
            sprintf("• Alternatively, accept lower power if this represents all available evidence.")
          )
        }

      } else if (calc_type == "n_studies") {
        n_req <- results$n_studies_required

        recommendations <- c(
          sprintf("✅ You need at least %d studies to achieve %.0f%% power.",
                  n_req, input$target_power * 100),
          sprintf("• This represents approximately %d total participants.",
                  results$total_n),
          sprintf("• If fewer studies are available, consider:"),
          "  - Individual patient data (IPD) meta-analysis",
          "  - Collaborative prospective meta-analysis",
          "  - Acknowledging power limitations in conclusions"
        )

      } else {
        mdes <- results$min_effect_size

        recommendations <- c(
          sprintf("✅ With %d studies, you can reliably detect effects of magnitude %.2f or larger.",
                  input$es_n_studies, mdes),
          "• Smaller effects may not be detected with adequate power.",
          "• Consider clinical significance: Is this effect size meaningful?",
          "• If smaller effects are important, more studies are needed."
        )
      }

      div(
        style = "background: #F9FAFB; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px;",

        lapply(recommendations, function(rec) {
          p(rec, style = "color: #4B5563; margin-bottom: 8px;")
        }),

        hr(),

        div(
          style = "background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 15px; border-radius: 6px; margin-top: 15px;",
          div(
            strong(icon("exclamation-triangle", style = "margin-right: 5px;"), "Important Note"),
            style = "color: #92400E; margin-bottom: 8px;"
          ),
          p(
            "Power calculations for meta-analysis are approximate and depend on assumptions about heterogeneity and study sizes. ",
            "Actual power may vary based on true between-study variance and distribution of study sizes.",
            style = "margin: 0; color: #92400E; font-size: 14px;"
          )
        )
      )
    })
  })
}

# Helper functions

#' Convert effect size to standardized theta
convert_to_theta <- function(effect_size, measure) {
  if (measure %in% c("OR", "RR", "HR")) {
    # Log scale for ratios
    return(log(effect_size))
  } else {
    # Direct scale for differences
    return(effect_size)
  }
}

#' Calculate meta-analysis power
calculate_meta_power <- function(theta, n_studies, avg_n, tau2, alpha, test_type) {

  # Typical within-study variance (approximate)
  # For binary: var ≈ 4/n, for continuous: var ≈ 1/n
  typical_var <- 4 / avg_n

  # Total variance = within-study var + between-study var
  total_var <- typical_var / n_studies + tau2

  # Standard error
  se <- sqrt(total_var)

  # Critical value
  z_alpha <- qnorm(1 - alpha/2)  # Two-sided by default

  # Non-centrality parameter
  ncp <- abs(theta) / se

  # Power
  power <- pnorm(ncp - z_alpha) + pnorm(-ncp - z_alpha)

  if (test_type == "greater") {
    z_alpha <- qnorm(1 - alpha)
    power <- pnorm(ncp - z_alpha)
  }

  list(
    power = power,
    total_n = n_studies * avg_n,
    se = se
  )
}

#' Calculate required number of studies
calculate_required_n_studies <- function(theta, target_power, avg_n, tau2, alpha, test_type) {

  # Binary search for required n_studies
  n_low <- 2
  n_high <- 1000

  while (n_high - n_low > 1) {
    n_mid <- floor((n_low + n_high) / 2)

    result <- calculate_meta_power(theta, n_mid, avg_n, tau2, alpha, test_type)

    if (result$power < target_power) {
      n_low <- n_mid
    } else {
      n_high <- n_mid
    }
  }

  list(
    n_studies_required = n_high,
    total_n = n_high * avg_n
  )
}

#' Calculate minimum detectable effect size
calculate_detectable_effect <- function(target_power, n_studies, avg_n, tau2, alpha, test_type, measure) {

  # Binary search for effect size
  theta_low <- 0.01
  theta_high <- 2.0

  while (theta_high - theta_low > 0.01) {
    theta_mid <- (theta_low + theta_high) / 2

    result <- calculate_meta_power(theta_mid, n_studies, avg_n, tau2, alpha, test_type)

    if (result$power < target_power) {
      theta_low <- theta_mid
    } else {
      theta_high <- theta_mid
    }
  }

  # Convert back to original scale
  if (measure %in% c("OR", "RR", "HR")) {
    min_effect <- exp(theta_high)
  } else {
    min_effect <- theta_high
  }

  list(
    min_effect_size = min_effect
  )
}

#' Generate power curve across effect sizes
generate_power_curve_effect <- function(n_studies, avg_n, tau2, alpha, test_type, measure, highlight_power = NULL) {

  if (measure %in% c("OR", "RR", "HR")) {
    effect_sizes <- seq(0.50, 0.95, by = 0.05)
  } else {
    effect_sizes <- seq(0.1, 1.0, by = 0.1)
  }

  powers <- sapply(effect_sizes, function(es) {
    theta <- convert_to_theta(es, measure)
    result <- calculate_meta_power(theta, n_studies, avg_n, tau2, alpha, test_type)
    result$power
  })

  data.frame(
    effect_size = effect_sizes,
    power = powers
  )
}

#' Generate power curve across number of studies
generate_power_curve_nstudies <- function(theta, avg_n, tau2, alpha, test_type, target_power) {

  n_studies_seq <- seq(5, 100, by = 5)

  powers <- sapply(n_studies_seq, function(n) {
    result <- calculate_meta_power(theta, n, avg_n, tau2, alpha, test_type)
    result$power
  })

  data.frame(
    n_studies = n_studies_seq,
    power = powers
  )
}
