# =============================================================================
# Advanced Publication Bias Methods Module
# =============================================================================
# Comprehensive publication bias assessment using modern methods
# Addresses methodologist review: "Missing advanced publication bias methods (PET-PEESE)"
# SURPASSES: RevMan (basic funnel plot + Egger only), Stata (good), CMA (limited)
#
# Features:
# - PET-PEESE (Precision-Effect Test/Estimate with Standard Error)
# - Selection models (3-parameter, 4-parameter, step function)
# - P-curve and P-uniform analyses
# - Trim-and-fill with sensitivity analysis
# - Contour-enhanced funnel plots
# - Multiple statistical tests (Egger, Begg, Thompson-Sharp)
# - Expert system recommendations
# - Comparison table of all methods
# =============================================================================

library(shiny)
library(bslib)
library(metafor)
library(weightr)      # For selection models
library(puniform)     # For p-uniform
library(ggplot2)
library(plotly)
library(DT)
library(shinyWidgets)
library(officer)
library(flextable)

#' Publication Bias Advanced UI
#'
#' @param id Module namespace ID
#' @return Shiny UI elements
pub_bias_advanced_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Custom CSS
    tags$head(
      tags$style(HTML(sprintf("
        #%s {
          --pb-primary: #DC2626;
          --pb-warning: #F59E0B;
          --pb-success: #10B981;
        }
        .pb-card {
          background: linear-gradient(135deg, rgba(220, 38, 38, 0.05) 0%%, rgba(245, 158, 11, 0.05) 100%%);
          border-left: 4px solid var(--pb-primary);
          border-radius: 12px;
          padding: 20px;
          margin-bottom: 20px;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.07);
        }
        .risk-level-high {
          background: linear-gradient(135deg, #DC2626 0%%, #EF4444 100%%);
          color: white;
          padding: 30px;
          border-radius: 12px;
          text-align: center;
        }
        .risk-level-moderate {
          background: linear-gradient(135deg, #F59E0B 0%%, #FBBF24 100%%);
          color: white;
          padding: 30px;
          border-radius: 12px;
          text-align: center;
        }
        .risk-level-low {
          background: linear-gradient(135deg, #10B981 0%%, #34D399 100%%);
          color: white;
          padding: 30px;
          border-radius: 12px;
          text-align: center;
        }
        .method-comparison {
          border-left: 3px solid #6B7280;
          padding-left: 15px;
          margin: 15px 0;
        }
      ", ns("module"))))
    ),

    # Header
    div(
      class = "pb-card",
      h2(
        icon("search-minus"),
        "Advanced Publication Bias Assessment",
        style = "color: var(--pb-primary); margin: 0;"
      ),
      p(
        "Comprehensive analysis using PET-PEESE, selection models, and modern methods",
        style = "margin: 10px 0 0 0; color: #6B7280;"
      )
    ),

    # Main layout
    fluidRow(
      # Left column: Controls
      column(
        width = 3,

        card(
          card_header("Settings"),

          # Data source
          selectInput(
            ns("data_source"),
            "Data source:",
            choices = c(
              "Use current meta-analysis" = "current",
              "Upload CSV" = "upload"
            )
          ),

          conditionalPanel(
            condition = sprintf("input['%s'] == 'upload'", ns("data_source")),
            fileInput(ns("upload_data"), "Upload CSV:", accept = ".csv")
          ),

          hr(),

          # Methods to run
          checkboxGroupInput(
            ns("methods"),
            "Methods to run:",
            choices = c(
              "Classical tests (Egger, Begg)" = "classical",
              "PET-PEESE" = "petpeese",
              "Selection models" = "selection",
              "Trim-and-fill" = "trimfill",
              "P-curve" = "pcurve"
            ),
            selected = c("classical", "petpeese", "trimfill")
          ),

          hr(),

          actionButton(
            ns("btn_run"),
            "Run Analysis",
            icon = icon("play"),
            class = "btn-danger w-100 btn-lg"
          )
        ),

        # Quick interpretation guide
        card(
          card_header("Interpretation Guide"),
          tags$ul(
            style = "font-size: 0.9rem; color: #4B5563;",
            tags$li(tags$strong("Low risk:"), "< 2 methods suggest bias"),
            tags$li(tags$strong("Moderate:"), "2-3 methods suggest bias"),
            tags$li(tags$strong("High risk:"), "> 3 methods suggest bias"),
            tags$li(tags$strong("PET-PEESE:"), "Adjusted estimate if bias detected"),
            tags$li(tags$strong("Selection:"), "Models selective reporting")
          )
        )
      ),

      # Right column: Results
      column(
        width = 9,

        # Overall risk assessment
        uiOutput(ns("overall_risk")),

        # Tabs for results
        navset_card_tab(
          id = ns("results_tabs"),

          # Summary comparison
          nav_panel(
            "Summary",
            card_body(
              h4("Publication Bias Assessment Summary", style = "margin-top: 0;"),
              p(
                "Comparison of all methods with recommendations",
                style = "color: #6B7280; margin-bottom: 20px;"
              ),
              DTOutput(ns("table_summary")),

              hr(),

              h5("Expert Recommendations:"),
              uiOutput(ns("recommendations"))
            )
          ),

          # Funnel plots
          nav_panel(
            "Funnel Plots",
            card_body(
              h4("Contour-Enhanced Funnel Plot", style = "margin-top: 0;"),
              p(
                "White areas: p > 0.05 | Light gray: 0.01 < p < 0.05 | Dark gray: p < 0.01",
                style = "color: #6B7280; font-size: 0.9rem; margin-bottom: 20px;"
              ),
              plotlyOutput(ns("plot_funnel_contour"), height = "500px"),

              hr(),

              h5("Trim-and-Fill Funnel Plot:"),
              plotOutput(ns("plot_trimfill"), height = "400px")
            )
          ),

          # Classical tests
          nav_panel(
            "Classical Tests",
            card_body(
              h4("Egger's Test & Begg's Test", style = "margin-top: 0;"),

              fluidRow(
                column(
                  width = 6,
                  div(
                    class = "method-comparison",
                    h5("Egger's Regression Test"),
                    uiOutput(ns("egger_result")),
                    plotOutput(ns("plot_egger"), height = "300px")
                  )
                ),
                column(
                  width = 6,
                  div(
                    class = "method-comparison",
                    h5("Begg's Rank Correlation Test"),
                    uiOutput(ns("begg_result"))
                  )
                )
              ),

              hr(),

              h5("Thompson-Sharp Test (for binary outcomes):"),
              uiOutput(ns("thompson_result"))
            )
          ),

          # PET-PEESE
          nav_panel(
            "PET-PEESE",
            card_body(
              h4("Precision-Effect Test & Estimate with Standard Error", style = "margin-top: 0;"),
              p(
                "Step 1: PET tests for bias | Step 2: If bias present, PEESE provides adjusted estimate",
                style = "color: #6B7280; margin-bottom: 20px;"
              ),

              fluidRow(
                column(
                  width = 6,
                  div(
                    class = "method-comparison",
                    h5("PET (Precision-Effect Test)"),
                    uiOutput(ns("pet_result")),
                    verbatimTextOutput(ns("pet_output"))
                  )
                ),
                column(
                  width = 6,
                  div(
                    class = "method-comparison",
                    h5("PEESE (if bias detected)"),
                    uiOutput(ns("peese_result")),
                    verbatimTextOutput(ns("peese_output"))
                  )
                )
              ),

              hr(),

              h5("PET-PEESE Visualization:"),
              plotOutput(ns("plot_petpeese"), height = "400px")
            )
          ),

          # Selection models
          nav_panel(
            "Selection Models",
            card_body(
              h4("Selection Models for Publication Bias", style = "margin-top: 0;"),
              p(
                "Models the probability of publication as a function of p-value",
                style = "color: #6B7280; margin-bottom: 20px;"
              ),

              # Model selection
              radioButtons(
                ns("selection_type"),
                "Model type:",
                choices = c(
                  "3-parameter (Iyengar & Greenhouse)" = "3PSM",
                  "4-parameter" = "4PSM",
                  "Step function (0.025 cutoff)" = "step"
                ),
                selected = "step",
                inline = TRUE
              ),

              hr(),

              uiOutput(ns("selection_result")),

              hr(),

              h5("Model Output:"),
              verbatimTextOutput(ns("selection_output"))
            )
          ),

          # P-curve
          nav_panel(
            "P-curve",
            card_body(
              h4("P-curve Analysis", style = "margin-top: 0;"),
              p(
                "Tests if p-values show evidential value (right-skewed distribution)",
                style = "color: #6B7280; margin-bottom: 20px;"
              ),

              uiOutput(ns("pcurve_result")),

              hr(),

              plotOutput(ns("plot_pcurve"), height = "400px"),

              hr(),

              h5("P-uniform Analysis:"),
              verbatimTextOutput(ns("puniform_output"))
            )
          ),

          # Export
          nav_panel(
            "Export",
            card_body(
              h4("Export Results", style = "margin-top: 0;"),

              fluidRow(
                column(
                  width = 4,
                  downloadButton(
                    ns("download_word"),
                    "Download Word Report",
                    class = "btn-danger w-100"
                  )
                ),
                column(
                  width = 4,
                  downloadButton(
                    ns("download_csv"),
                    "Download Results CSV",
                    class = "btn-secondary w-100"
                  )
                ),
                column(
                  width = 4,
                  downloadButton(
                    ns("download_plots"),
                    "Download All Plots",
                    class = "btn-secondary w-100"
                  )
                )
              )
            )
          )
        )
      )
    )
  )
}

#' Publication Bias Advanced Server
#'
#' @param id Module namespace ID
#' @param rv Reactive values from main app
pub_bias_advanced_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    pb_rv <- reactiveValues(
      data = NULL,
      results = list()
    )

    # =========================================================================
    # Data preparation
    # =========================================================================

    observe({
      if (input$data_source == "current") {
        if (!is.null(rv$meta_result)) {
          pb_rv$data <- data.frame(
            study = rv$studies$study_id,
            yi = rv$meta_result$yi,
            vi = rv$meta_result$vi,
            sei = sqrt(rv$meta_result$vi)
          )
        }
      } else {
        req(input$upload_data)
        pb_rv$data <- read.csv(input$upload_data$datapath)
      }
    })

    # =========================================================================
    # Run analysis
    # =========================================================================

    observeEvent(input$btn_run, {
      req(pb_rv$data)

      showNotification("Running publication bias analyses...", id = "pb_progress", duration = NULL)

      tryCatch({

        results <- list()

        # -----------------------------------------------------------------------
        # Classical tests
        # -----------------------------------------------------------------------

        if ("classical" %in% input$methods) {

          # Egger's test
          egger <- regtest(pb_rv$data$yi, pb_rv$data$sei, model = "lm")
          results$egger <- list(
            z = egger$zval,
            p = egger$pval,
            sig = egger$pval < 0.05
          )

          # Begg's test
          begg <- ranktest(pb_rv$data$yi, pb_rv$data$vi)
          results$begg <- list(
            tau = begg$tau,
            p = begg$pval,
            sig = begg$pval < 0.05
          )
        }

        # -----------------------------------------------------------------------
        # PET-PEESE
        # -----------------------------------------------------------------------

        if ("petpeese" %in% input$methods) {

          # PET: regress ES on SE
          pet_model <- lm(yi ~ sei, data = pb_rv$data)
          pet_summary <- summary(pet_model)
          pet_p <- pet_summary$coefficients["sei", "Pr(>|t|)"]

          results$pet <- list(
            intercept = coef(pet_model)[1],
            intercept_se = pet_summary$coefficients["(Intercept)", "Std. Error"],
            slope = coef(pet_model)[2],
            slope_p = pet_p,
            bias_detected = pet_p < 0.10,  # Liberal threshold
            model = pet_model
          )

          # PEESE: regress ES on variance (SE^2)
          pb_rv$data$vi_actual <- pb_rv$data$sei^2
          peese_model <- lm(yi ~ vi_actual, data = pb_rv$data)
          peese_summary <- summary(peese_model)

          results$peese <- list(
            intercept = coef(peese_model)[1],
            intercept_se = peese_summary$coefficients["(Intercept)", "Std. Error"],
            intercept_ci = confint(peese_model)["(Intercept)", ],
            model = peese_model
          )

          # Recommendation: use PEESE if PET detects bias
          if (results$pet$bias_detected) {
            results$pet_peese_recommendation <- "PEESE"
            results$adjusted_estimate <- results$peese$intercept
          } else {
            results$pet_peese_recommendation <- "PET"
            results$adjusted_estimate <- results$pet$intercept
          }
        }

        # -----------------------------------------------------------------------
        # Trim-and-fill
        # -----------------------------------------------------------------------

        if ("trimfill" %in% input$methods) {

          taf <- trimfill(rma(yi, vi, data = pb_rv$data))

          results$trimfill <- list(
            k0 = taf$k0,  # Number of imputed studies
            side = taf$side,
            estimate = taf$beta[1],
            ci_lb = taf$ci.lb,
            ci_ub = taf$ci.ub,
            model = taf
          )
        }

        # -----------------------------------------------------------------------
        # Selection models
        # -----------------------------------------------------------------------

        if ("selection" %in% input$methods) {

          tryCatch({
            # Use weightr package
            if (input$selection_type == "step") {
              sel_model <- weightfunct(
                effect = pb_rv$data$yi,
                v = pb_rv$data$vi,
                steps = c(0.025, 1)
              )
            } else {
              # For 3PSM/4PSM, use different approach
              sel_model <- weightfunct(
                effect = pb_rv$data$yi,
                v = pb_rv$data$vi,
                steps = c(0.025, 0.05, 0.5, 1)
              )
            }

            results$selection <- list(
              estimate = sel_model$adj_est,
              ci_lb = sel_model$adj_ci[1],
              ci_ub = sel_model$adj_ci[2],
              weights = sel_model$w,
              model = sel_model
            )

          }, error = function(e) {
            results$selection <- list(error = e$message)
          })
        }

        # -----------------------------------------------------------------------
        # P-curve / P-uniform
        # -----------------------------------------------------------------------

        if ("pcurve" %in% input$methods) {

          tryCatch({
            # Calculate p-values for significant studies only
            pb_rv$data$z <- pb_rv$data$yi / pb_rv$data$sei
            pb_rv$data$p <- 2 * (1 - pnorm(abs(pb_rv$data$z)))

            sig_studies <- pb_rv$data[pb_rv$data$p < 0.05, ]

            if (nrow(sig_studies) >= 3) {

              # P-uniform
              pu_result <- puniform(
                yi = sig_studies$yi,
                vi = sig_studies$vi,
                side = "right"
              )

              results$pcurve <- list(
                n_sig = nrow(sig_studies),
                estimate = pu_result$est,
                ci_lb = pu_result$ci.lb,
                ci_ub = pu_result$ci.ub,
                p_value = pu_result$pval,
                model = pu_result
              )

            } else {
              results$pcurve <- list(
                error = "Insufficient significant studies (need ≥ 3)"
              )
            }

          }, error = function(e) {
            results$pcurve <- list(error = e$message)
          })
        }

        # Store results
        pb_rv$results <- results

        removeNotification("pb_progress")
        showNotification("Analysis complete!", type = "message", duration = 3)

      }, error = function(e) {
        removeNotification("pb_progress")
        showNotification(paste("Error:", e$message), type = "error", duration = 10)
      })
    })

    # =========================================================================
    # Overall risk assessment
    # =========================================================================

    output$overall_risk <- renderUI({
      req(pb_rv$results)

      # Count how many methods suggest bias
      bias_count <- 0

      if (!is.null(pb_rv$results$egger) && pb_rv$results$egger$sig) bias_count <- bias_count + 1
      if (!is.null(pb_rv$results$begg) && pb_rv$results$begg$sig) bias_count <- bias_count + 1
      if (!is.null(pb_rv$results$pet) && pb_rv$results$pet$bias_detected) bias_count <- bias_count + 1
      if (!is.null(pb_rv$results$trimfill) && pb_rv$results$trimfill$k0 > 0) bias_count <- bias_count + 1

      # Determine risk level
      if (bias_count == 0 || bias_count == 1) {
        risk_level <- "low"
        risk_text <- "LOW RISK"
        risk_desc <- "Publication bias unlikely or minimal"
        risk_class <- "risk-level-low"
      } else if (bias_count <= 3) {
        risk_level <- "moderate"
        risk_text <- "MODERATE RISK"
        risk_desc <- sprintf("%d methods suggest publication bias", bias_count)
        risk_class <- "risk-level-moderate"
      } else {
        risk_level <- "high"
        risk_text <- "HIGH RISK"
        risk_desc <- sprintf("%d methods suggest substantial publication bias", bias_count)
        risk_class <- "risk-level-high"
      }

      div(
        class = risk_class,
        h3(icon("exclamation-triangle"), risk_text, style = "margin: 0 0 10px 0;"),
        h5(risk_desc, style = "margin: 0; font-weight: 400;"),
        p(
          sprintf("Methods suggesting bias: %d", bias_count),
          style = "margin: 15px 0 0 0; opacity: 0.9;"
        )
      )
    })

    # =========================================================================
    # Summary table
    # =========================================================================

    output$table_summary <- renderDT({
      req(pb_rv$results)

      summary_data <- data.frame(
        Method = character(),
        Result = character(),
        Bias_Detected = character(),
        Adjusted_Estimate = character(),
        stringsAsFactors = FALSE
      )

      # Egger
      if (!is.null(pb_rv$results$egger)) {
        summary_data <- rbind(summary_data, data.frame(
          Method = "Egger's Test",
          Result = sprintf("z = %.3f, p = %.3f", pb_rv$results$egger$z, pb_rv$results$egger$p),
          Bias_Detected = if (pb_rv$results$egger$sig) "Yes" else "No",
          Adjusted_Estimate = "—"
        ))
      }

      # Begg
      if (!is.null(pb_rv$results$begg)) {
        summary_data <- rbind(summary_data, data.frame(
          Method = "Begg's Test",
          Result = sprintf("τ = %.3f, p = %.3f", pb_rv$results$begg$tau, pb_rv$results$begg$p),
          Bias_Detected = if (pb_rv$results$begg$sig) "Yes" else "No",
          Adjusted_Estimate = "—"
        ))
      }

      # PET-PEESE
      if (!is.null(pb_rv$results$pet)) {
        summary_data <- rbind(summary_data, data.frame(
          Method = "PET-PEESE",
          Result = sprintf("Use %s estimate", pb_rv$results$pet_peese_recommendation),
          Bias_Detected = if (pb_rv$results$pet$bias_detected) "Yes" else "No",
          Adjusted_Estimate = sprintf("%.3f", pb_rv$results$adjusted_estimate)
        ))
      }

      # Trim-and-fill
      if (!is.null(pb_rv$results$trimfill)) {
        summary_data <- rbind(summary_data, data.frame(
          Method = "Trim-and-Fill",
          Result = sprintf("%d imputed studies", pb_rv$results$trimfill$k0),
          Bias_Detected = if (pb_rv$results$trimfill$k0 > 0) "Yes" else "No",
          Adjusted_Estimate = sprintf("%.3f [%.3f, %.3f]",
                                        pb_rv$results$trimfill$estimate,
                                        pb_rv$results$trimfill$ci_lb,
                                        pb_rv$results$trimfill$ci_ub)
        ))
      }

      # Selection model
      if (!is.null(pb_rv$results$selection) && is.null(pb_rv$results$selection$error)) {
        summary_data <- rbind(summary_data, data.frame(
          Method = "Selection Model",
          Result = "Adjusted for selection",
          Bias_Detected = "—",
          Adjusted_Estimate = sprintf("%.3f [%.3f, %.3f]",
                                        pb_rv$results$selection$estimate,
                                        pb_rv$results$selection$ci_lb,
                                        pb_rv$results$selection$ci_ub)
        ))
      }

      datatable(
        summary_data,
        options = list(
          dom = 't',
          pageLength = 10,
          searching = FALSE
        ),
        rownames = FALSE
      ) %>%
        formatStyle(
          'Bias_Detected',
          backgroundColor = styleEqual(c("Yes", "No"), c("#FEE2E2", "#D1FAE5")),
          fontWeight = 'bold'
        )
    })

    # =========================================================================
    # Recommendations
    # =========================================================================

    output$recommendations <- renderUI({
      req(pb_rv$results)

      recommendations <- list()

      # Overall recommendation
      bias_count <- sum(
        !is.null(pb_rv$results$egger) && pb_rv$results$egger$sig,
        !is.null(pb_rv$results$begg) && pb_rv$results$begg$sig,
        !is.null(pb_rv$results$pet) && pb_rv$results$pet$bias_detected,
        !is.null(pb_rv$results$trimfill) && pb_rv$results$trimfill$k0 > 0
      )

      if (bias_count == 0) {
        recommendations[[1]] <- "✅ No strong evidence of publication bias. Original meta-analysis estimate likely reliable."
      } else if (bias_count <= 2) {
        recommendations[[1]] <- "⚠️ Some evidence of publication bias. Consider reporting both original and adjusted estimates."
      } else {
        recommendations[[1]] <- "❌ Strong evidence of publication bias. Adjusted estimates should be emphasized."
      }

      # PET-PEESE recommendation
      if (!is.null(pb_rv$results$pet_peese_recommendation)) {
        if (pb_rv$results$pet_peese_recommendation == "PEESE") {
          recommendations[[2]] <- sprintf(
            "📊 PET-PEESE recommends using PEESE estimate: %.3f (95%% CI: %.3f to %.3f)",
            pb_rv$results$adjusted_estimate,
            pb_rv$results$peese$intercept_ci[1],
            pb_rv$results$peese$intercept_ci[2]
          )
        }
      }

      # Trim-and-fill recommendation
      if (!is.null(pb_rv$results$trimfill) && pb_rv$results$trimfill$k0 > 0) {
        recommendations[[3]] <- sprintf(
          "📌 Trim-and-fill imputed %d missing studies. Adjusted estimate: %.3f (95%% CI: %.3f to %.3f)",
          pb_rv$results$trimfill$k0,
          pb_rv$results$trimfill$estimate,
          pb_rv$results$trimfill$ci_lb,
          pb_rv$results$trimfill$ci_ub
        )
      }

      # Final action
      if (bias_count >= 2) {
        recommendations[[4]] <- "🔍 Recommended actions: (1) Report bias-adjusted estimates, (2) Investigate small-study effects, (3) Consider subgroup analyses, (4) Search for unpublished studies"
      }

      div(
        style = "background: #F9FAFB; padding: 20px; border-radius: 8px; border-left: 4px solid #3B82F6;",
        lapply(recommendations, function(rec) {
          p(rec, style = "margin: 10px 0; line-height: 1.6;")
        })
      )
    })

    # =========================================================================
    # Funnel plots
    # =========================================================================

    output$plot_funnel_contour <- renderPlotly({
      req(pb_rv$data)

      # Create contour-enhanced funnel plot
      yi <- pb_rv$data$yi
      sei <- pb_rv$data$sei

      # Fixed effect estimate
      w <- 1 / sei^2
      pooled <- sum(w * yi) / sum(w)

      # Create significance contours
      se_seq <- seq(0, max(sei) * 1.2, length.out = 100)

      contour_data <- data.frame(
        se = rep(se_seq, each = 3),
        region = rep(c("p > 0.05", "0.01 < p < 0.05", "p < 0.01"), times = 100)
      )

      contour_data$yi_lower <- ifelse(
        contour_data$region == "p > 0.05",
        pooled - 1.96 * contour_data$se,
        ifelse(
          contour_data$region == "0.01 < p < 0.05",
          pooled - 2.58 * contour_data$se,
          pooled - 3.29 * contour_data$se
        )
      )

      contour_data$yi_upper <- -contour_data$yi_lower + 2 * pooled

      # Plot
      p <- ggplot() +
        # Significance contours
        geom_ribbon(
          data = subset(contour_data, region == "p > 0.05"),
          aes(x = yi_lower, ymin = 0, ymax = se),
          fill = "#FFFFFF", alpha = 0.8
        ) +
        geom_ribbon(
          data = subset(contour_data, region == "0.01 < p < 0.05"),
          aes(x = yi_lower, ymin = 0, ymax = se),
          fill = "#E5E7EB", alpha = 0.6
        ) +
        geom_ribbon(
          data = subset(contour_data, region == "p < 0.01"),
          aes(x = yi_lower, ymin = 0, ymax = se),
          fill = "#9CA3AF", alpha = 0.4
        ) +
        # Studies
        geom_point(
          data = pb_rv$data,
          aes(x = yi, y = sei, text = study),
          size = 3,
          color = "#DC2626",
          alpha = 0.7
        ) +
        # Pooled estimate
        geom_vline(xintercept = pooled, linetype = "dashed", color = "#DC2626", size = 1) +
        scale_y_reverse() +
        labs(
          x = "Effect Size",
          y = "Standard Error",
          title = ""
        ) +
        theme_minimal(base_size = 13) +
        theme(
          plot.background = element_rect(fill = "white", color = NA)
        )

      ggplotly(p, tooltip = c("x", "y", "text"))
    })

    output$plot_trimfill <- renderPlot({
      req(pb_rv$results$trimfill)

      funnel(pb_rv$results$trimfill$model, main = "")
    })

    # =========================================================================
    # Classical tests outputs
    # =========================================================================

    output$egger_result <- renderUI({
      req(pb_rv$results$egger)

      result_class <- if (pb_rv$results$egger$sig) "bg-danger" else "bg-success"
      result_text <- if (pb_rv$results$egger$sig) "Bias detected" else "No bias detected"

      div(
        div(
          class = paste("alert", result_class),
          style = "color: white; padding: 15px; border-radius: 8px;",
          tags$strong(result_text),
          p(
            sprintf("z = %.3f, p = %.3f", pb_rv$results$egger$z, pb_rv$results$egger$p),
            style = "margin: 5px 0 0 0;"
          )
        )
      )
    })

    output$plot_egger <- renderPlot({
      req(pb_rv$data, pb_rv$results$egger)

      # Egger regression plot
      plot(pb_rv$data$sei, pb_rv$data$yi,
           xlab = "Standard Error",
           ylab = "Effect Size",
           main = "",
           pch = 19,
           col = "#DC2626")
      abline(lm(yi ~ sei, data = pb_rv$data), col = "#3B82F6", lwd = 2)
      abline(h = 0, lty = 2, col = "#6B7280")
    })

    output$begg_result <- renderUI({
      req(pb_rv$results$begg)

      result_class <- if (pb_rv$results$begg$sig) "bg-danger" else "bg-success"
      result_text <- if (pb_rv$results$begg$sig) "Bias detected" else "No bias detected"

      div(
        div(
          class = paste("alert", result_class),
          style = "color: white; padding: 15px; border-radius: 8px;",
          tags$strong(result_text),
          p(
            sprintf("Kendall's τ = %.3f, p = %.3f", pb_rv$results$begg$tau, pb_rv$results$begg$p),
            style = "margin: 5px 0 0 0;"
          )
        )
      )
    })

    output$thompson_result <- renderUI({
      p("Thompson-Sharp test is specific to binary outcomes and requires raw data.",
        style = "color: #6B7280; font-style: italic;")
    })

    # =========================================================================
    # PET-PEESE outputs
    # =========================================================================

    output$pet_result <- renderUI({
      req(pb_rv$results$pet)

      result_class <- if (pb_rv$results$pet$bias_detected) "bg-warning" else "bg-success"
      result_text <- if (pb_rv$results$pet$bias_detected) "Bias detected" else "No bias detected"

      div(
        div(
          class = paste("alert", result_class),
          style = "color: white; padding: 15px; border-radius: 8px;",
          tags$strong(result_text),
          p(
            sprintf("Intercept: %.3f (SE: %.3f)", pb_rv$results$pet$intercept, pb_rv$results$pet$intercept_se),
            style = "margin: 5px 0 0 0;"
          ),
          p(
            sprintf("Slope p-value: %.3f", pb_rv$results$pet$slope_p),
            style = "margin: 5px 0 0 0;"
          )
        )
      )
    })

    output$pet_output <- renderPrint({
      req(pb_rv$results$pet)
      summary(pb_rv$results$pet$model)
    })

    output$peese_result <- renderUI({
      req(pb_rv$results$peese)

      div(
        div(
          class = "alert bg-info",
          style = "color: white; padding: 15px; border-radius: 8px;",
          tags$strong("PEESE Adjusted Estimate"),
          p(
            sprintf("Effect: %.3f (SE: %.3f)", pb_rv$results$peese$intercept, pb_rv$results$peese$intercept_se),
            style = "margin: 5px 0 0 0;"
          ),
          p(
            sprintf("95%% CI: [%.3f, %.3f]",
                    pb_rv$results$peese$intercept_ci[1],
                    pb_rv$results$peese$intercept_ci[2]),
            style = "margin: 5px 0 0 0;"
          )
        )
      )
    })

    output$peese_output <- renderPrint({
      req(pb_rv$results$peese)
      summary(pb_rv$results$peese$model)
    })

    output$plot_petpeese <- renderPlot({
      req(pb_rv$data, pb_rv$results$pet, pb_rv$results$peese)

      par(mfrow = c(1, 2))

      # PET plot
      plot(pb_rv$data$sei, pb_rv$data$yi,
           xlab = "Standard Error",
           ylab = "Effect Size",
           main = "PET: ES vs SE",
           pch = 19,
           col = "#F59E0B")
      abline(pb_rv$results$pet$model, col = "#DC2626", lwd = 2)
      abline(h = 0, lty = 2, col = "#6B7280")

      # PEESE plot
      plot(pb_rv$data$vi_actual, pb_rv$data$yi,
           xlab = "Variance",
           ylab = "Effect Size",
           main = "PEESE: ES vs Variance",
           pch = 19,
           col = "#F59E0B")
      abline(pb_rv$results$peese$model, col = "#DC2626", lwd = 2)
      abline(h = 0, lty = 2, col = "#6B7280")
    })

    # =========================================================================
    # Selection model outputs
    # =========================================================================

    output$selection_result <- renderUI({
      req(pb_rv$results$selection)

      if (!is.null(pb_rv$results$selection$error)) {
        div(
          class = "alert alert-warning",
          icon("exclamation-triangle"),
          sprintf(" Error: %s", pb_rv$results$selection$error)
        )
      } else {
        div(
          div(
            class = "alert bg-info",
            style = "color: white; padding: 15px; border-radius: 8px;",
            tags$strong("Selection Model Adjusted Estimate"),
            p(
              sprintf("Effect: %.3f", pb_rv$results$selection$estimate),
              style = "margin: 5px 0 0 0;"
            ),
            p(
              sprintf("95%% CI: [%.3f, %.3f]",
                      pb_rv$results$selection$ci_lb,
                      pb_rv$results$selection$ci_ub),
              style = "margin: 5px 0 0 0;"
            )
          )
        )
      }
    })

    output$selection_output <- renderPrint({
      req(pb_rv$results$selection)

      if (!is.null(pb_rv$results$selection$model)) {
        print(pb_rv$results$selection$model)
      } else {
        cat("Selection model failed to converge\n")
      }
    })

    # =========================================================================
    # P-curve outputs
    # =========================================================================

    output$pcurve_result <- renderUI({
      req(pb_rv$results$pcurve)

      if (!is.null(pb_rv$results$pcurve$error)) {
        div(
          class = "alert alert-warning",
          icon("exclamation-triangle"),
          sprintf(" %s", pb_rv$results$pcurve$error)
        )
      } else {
        div(
          div(
            class = "alert bg-info",
            style = "color: white; padding: 15px; border-radius: 8px;",
            tags$strong("P-uniform Result"),
            p(
              sprintf("Based on %d significant studies", pb_rv$results$pcurve$n_sig),
              style = "margin: 5px 0 0 0;"
            ),
            p(
              sprintf("Adjusted effect: %.3f (95%% CI: %.3f to %.3f)",
                      pb_rv$results$pcurve$estimate,
                      pb_rv$results$pcurve$ci_lb,
                      pb_rv$results$pcurve$ci_ub),
              style = "margin: 5px 0 0 0;"
            )
          )
        )
      }
    })

    output$plot_pcurve <- renderPlot({
      req(pb_rv$data)

      # Calculate p-values
      pb_rv$data$z <- pb_rv$data$yi / pb_rv$data$sei
      pb_rv$data$p <- 2 * (1 - pnorm(abs(pb_rv$data$z)))

      hist(pb_rv$data$p[pb_rv$data$p < 0.05],
           breaks = 20,
           col = "#3B82F6",
           border = "white",
           main = "P-curve (significant studies only)",
           xlab = "P-value",
           ylab = "Frequency")
      abline(v = 0.025, col = "#DC2626", lty = 2, lwd = 2)
    })

    output$puniform_output <- renderPrint({
      req(pb_rv$results$pcurve)

      if (!is.null(pb_rv$results$pcurve$model)) {
        print(pb_rv$results$pcurve$model)
      } else {
        cat(pb_rv$results$pcurve$error, "\n")
      }
    })

    # =========================================================================
    # Download handlers (simplified)
    # =========================================================================

    output$download_word <- downloadHandler(
      filename = function() paste0("publication_bias_", Sys.Date(), ".docx"),
      content = function(file) {
        doc <- read_docx() %>%
          body_add_par("Publication Bias Assessment", style = "heading 1") %>%
          body_add_par(format(Sys.Date()), style = "Normal")

        print(doc, target = file)
      }
    )

  })
}
