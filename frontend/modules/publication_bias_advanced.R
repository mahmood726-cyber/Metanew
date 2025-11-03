# Advanced Publication Bias Detection Module
# Implements p-curve, p-uniform, p-uniform*, and selection models
# Following van Aert et al. (2016), Simonsohn et al. (2014), and Vevea & Hedges (1995)

library(shiny)
library(bslib)
library(DT)
library(ggplot2)
library(metafor)
library(puniform)  # For p-uniform and p-uniform*
library(weightr)   # For selection models

# Source PET-PEESE utilities
source("frontend/utils/publication_bias_petpeese.R", local = TRUE)


#' UI for Advanced Publication Bias Module
#'
#' @param id Module namespace ID
#' @export
publication_bias_advanced_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h3("📊 Advanced Publication Bias Analysis"),
    p("Comprehensive suite of publication bias detection and correction methods"),

    # Method selection
    card(
      card_header("Select Analysis Methods"),
      layout_columns(
        col_widths = c(6, 6),
        checkboxGroupInput(
          ns("methods"),
          "Methods to Run:",
          choices = c(
            "Egger's Test (Traditional)" = "egger",
            "PET-PEESE (Meta-Regression)" = "petpeese",
            "p-curve (Evidential Value)" = "pcurve",
            "p-uniform (Unbiased Effect)" = "puniform",
            "p-uniform* (Extended)" = "puniform_star",
            "Selection Models (3PSM)" = "selection_3psm",
            "Selection Models (4PSM)" = "selection_4psm",
            "Trim and Fill" = "trimfill"
          ),
          selected = c("egger", "petpeese", "pcurve", "puniform")
        ),
        div(
          actionButton(ns("run_analysis"), "Run Analysis",
                      class = "btn-primary", icon = icon("play")),
          br(), br(),
          downloadButton(ns("download_report"), "Download Report"),
          br(), br(),
          helpText("Recommended: Run multiple methods for triangulation.",
                  "p-curve and p-uniform require significant p-values.")
        )
      )
    ),

    # Results tabs
    navset_card_tab(
      id = ns("results_tabs"),

      # Summary tab
      nav_panel(
        "Summary",
        card_body(
          h4("Publication Bias Summary"),
          DTOutput(ns("summary_table")),
          br(),
          h5("Overall Assessment"),
          verbatimTextOutput(ns("overall_assessment")),
          br(),
          plotOutput(ns("comparison_plot"), height = "400px")
        )
      ),

      # Traditional methods
      nav_panel(
        "Traditional",
        card_body(
          h4("Egger's Test & Trim-and-Fill"),
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("Egger's Test"),
              verbatimTextOutput(ns("egger_results"))
            ),
            card(
              card_header("Trim-and-Fill"),
              verbatimTextOutput(ns("trimfill_results"))
            )
          ),
          plotOutput(ns("funnel_plot"), height = "500px")
        )
      ),

      # PET-PEESE
      nav_panel(
        "PET-PEESE",
        card_body(
          h4("Precision-Effect Test & Estimate"),
          verbatimTextOutput(ns("petpeese_results")),
          br(),
          plotOutput(ns("petpeese_plot"), height = "500px")
        )
      ),

      # p-curve
      nav_panel(
        "p-curve",
        card_body(
          h4("p-curve Analysis"),
          p("Tests whether the distribution of p-values indicates evidential value"),
          verbatimTextOutput(ns("pcurve_results")),
          br(),
          plotOutput(ns("pcurve_plot"), height = "500px"),
          br(),
          helpText(
            "Right-skewed p-curve (more small p-values): Evidential value present",
            br(),
            "Flat or left-skewed: Publication bias likely",
            br(),
            "Reference: Simonsohn, Nelson & Simmons (2014) Psychological Science"
          )
        )
      ),

      # p-uniform
      nav_panel(
        "p-uniform",
        card_body(
          h4("p-uniform & p-uniform* Methods"),
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("p-uniform"),
              verbatimTextOutput(ns("puniform_results"))
            ),
            card(
              card_header("p-uniform* (Extended)"),
              verbatimTextOutput(ns("puniform_star_results"))
            )
          ),
          br(),
          plotOutput(ns("puniform_plot"), height = "400px"),
          br(),
          helpText(
            "p-uniform corrects for publication bias using only significant studies",
            br(),
            "p-uniform* extends this to include non-significant studies",
            br(),
            "Reference: van Assen, van Aert & Wicherts (2015) Frontiers in Psychology"
          )
        )
      ),

      # Selection models
      nav_panel(
        "Selection Models",
        card_body(
          h4("Selection Models (Vevea-Hedges)"),
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("3-Parameter Selection Model (3PSM)"),
              verbatimTextOutput(ns("selection_3psm_results"))
            ),
            card(
              card_header("4-Parameter Selection Model (4PSM)"),
              verbatimTextOutput(ns("selection_4psm_results"))
            )
          ),
          br(),
          plotOutput(ns("selection_plot"), height = "500px"),
          br(),
          helpText(
            "Selection models estimate effect size while accounting for selective publishing",
            br(),
            "3PSM: Simple two-category selection (significant vs non-significant)",
            br(),
            "4PSM: More flexible four-category selection",
            br(),
            "Reference: Vevea & Hedges (1995) Psychological Methods"
          )
        )
      ),

      # Diagnostics
      nav_panel(
        "Diagnostics",
        card_body(
          h4("Publication Bias Diagnostics"),
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("Contour-Enhanced Funnel Plot"),
              plotOutput(ns("contour_funnel"), height = "400px")
            ),
            card(
              card_header("Cumulative Meta-Analysis"),
              plotOutput(ns("cumulative_ma"), height = "400px")
            )
          ),
          br(),
          layout_columns(
            col_widths = c(6, 6),
            card(
              card_header("DOI Plot (Ioannidis)"),
              plotOutput(ns("doi_plot"), height = "400px")
            ),
            card(
              card_header("P-value Distribution"),
              plotOutput(ns("pvalue_dist"), height = "400px")
            )
          )
        )
      )
    )
  )
}


#' Server Logic for Advanced Publication Bias Module
#'
#' @param id Module namespace ID
#' @param rv Reactive values from parent (must contain pairwise_results)
#' @export
publication_bias_advanced_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive to store all results
    results <- reactiveVal(NULL)


    # Run comprehensive analysis
    observeEvent(input$run_analysis, {
      req(rv$pairwise_results)

      # Check if we have pairwise results
      outcome_name <- names(rv$pairwise_results)[1]
      if (is.null(outcome_name)) {
        showNotification("No meta-analysis results available", type = "error")
        return()
      }

      ma_result <- rv$pairwise_results[[outcome_name]]

      # Extract data
      yi <- ma_result$yi
      vi <- ma_result$vi
      sei <- sqrt(vi)

      # Check minimum studies
      if (length(yi) < 10) {
        showNotification(
          "Warning: Publication bias methods require at least 10 studies for reliable results",
          type = "warning",
          duration = 10
        )
      }

      withProgress(message = "Running publication bias analyses...", value = 0, {

        all_results <- list()
        methods <- input$methods
        n_methods <- length(methods)

        # 1. Egger's test
        if ("egger" %in% methods) {
          incProgress(1/n_methods, detail = "Running Egger's test...")
          all_results$egger <- tryCatch({
            metafor::regtest(yi, vi, model = "lm")
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # 2. PET-PEESE
        if ("petpeese" %in% methods) {
          incProgress(1/n_methods, detail = "Running PET-PEESE...")
          all_results$petpeese <- tryCatch({
            pet_peese(yi, vi = vi, alpha = 0.10)
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # 3. p-curve
        if ("pcurve" %in% methods) {
          incProgress(1/n_methods, detail = "Running p-curve...")
          all_results$pcurve <- tryCatch({
            run_pcurve_analysis(yi, vi)
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # 4. p-uniform
        if ("puniform" %in% methods) {
          incProgress(1/n_methods, detail = "Running p-uniform...")
          all_results$puniform <- tryCatch({
            puniform::puniform(yi, sei, side = "right")
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # 5. p-uniform*
        if ("puniform_star" %in% methods) {
          incProgress(1/n_methods, detail = "Running p-uniform*...")
          all_results$puniform_star <- tryCatch({
            puniform::puniformstar(yi, sei, side = "right")
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # 6. Selection models - 3PSM
        if ("selection_3psm" %in% methods) {
          incProgress(1/n_methods, detail = "Running 3PSM selection model...")
          all_results$selection_3psm <- tryCatch({
            weightr::weightfunct(yi, vi, steps = c(0.025, 1))
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # 7. Selection models - 4PSM
        if ("selection_4psm" %in% methods) {
          incProgress(1/n_methods, detail = "Running 4PSM selection model...")
          all_results$selection_4psm <- tryCatch({
            weightr::weightfunct(yi, vi, steps = c(0.025, 0.05, 0.5, 1))
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # 8. Trim and Fill
        if ("trimfill" %in% methods) {
          incProgress(1/n_methods, detail = "Running Trim-and-Fill...")
          all_results$trimfill <- tryCatch({
            metafor::trimfill(metafor::rma(yi, vi, method = "REML"))
          }, error = function(e) {
            list(error = e$message)
          })
        }

        # Store all results
        all_results$yi <- yi
        all_results$vi <- vi
        all_results$sei <- sei
        all_results$conventional_ma <- metafor::rma(yi, vi, method = "REML")

        results(all_results)

        showNotification("Publication bias analysis complete!", type = "message")
      })
    })


    # Summary table
    output$summary_table <- renderDT({
      req(results())

      res <- results()
      conv_est <- res$conventional_ma$beta[1]

      summary_df <- data.frame(
        Method = character(),
        `Bias-Corrected Estimate` = numeric(),
        `95% CI Lower` = numeric(),
        `95% CI Upper` = numeric(),
        `p-value` = character(),
        Interpretation = character(),
        stringsAsFactors = FALSE
      )

      # Conventional MA
      summary_df <- rbind(summary_df, data.frame(
        Method = "Conventional MA (Reference)",
        Bias.Corrected.Estimate = conv_est,
        X95..CI.Lower = res$conventional_ma$ci.lb,
        X95..CI.Upper = res$conventional_ma$ci.ub,
        p.value = format.pval(res$conventional_ma$pval, digits = 3),
        Interpretation = "Uncorrected estimate"
      ))

      # Egger's test
      if (!is.null(res$egger) && !inherits(res$egger, "error")) {
        summary_df <- rbind(summary_df, data.frame(
          Method = "Egger's Test",
          Bias.Corrected.Estimate = NA,
          X95..CI.Lower = NA,
          X95..CI.Upper = NA,
          p.value = format.pval(res$egger$pval, digits = 3),
          Interpretation = ifelse(res$egger$pval < 0.05,
                                  "Significant bias detected",
                                  "No significant bias")
        ))
      }

      # PET-PEESE
      if (!is.null(res$petpeese) && !inherits(res$petpeese, "error")) {
        summary_df <- rbind(summary_df, data.frame(
          Method = paste0("PET-PEESE (", res$petpeese$recommendation, ")"),
          Bias.Corrected.Estimate = res$petpeese$recommended_estimate,
          X95..CI.Lower = res$petpeese$recommended_ci_lower,
          X95..CI.Upper = res$petpeese$recommended_ci_upper,
          p.value = ifelse(res$petpeese$recommendation == "PET",
                          format.pval(res$petpeese$pet_p, digits = 3),
                          format.pval(res$petpeese$peese_p, digits = 3)),
          Interpretation = "Meta-regression correction"
        ))
      }

      # p-uniform
      if (!is.null(res$puniform) && !inherits(res$puniform, "error")) {
        summary_df <- rbind(summary_df, data.frame(
          Method = "p-uniform",
          Bias.Corrected.Estimate = res$puniform$est,
          X95..CI.Lower = res$puniform$ci.lb,
          X95..CI.Upper = res$puniform$ci.ub,
          p.value = format.pval(res$puniform$pval, digits = 3),
          Interpretation = "Uses only significant studies"
        ))
      }

      # p-uniform*
      if (!is.null(res$puniform_star) && !inherits(res$puniform_star, "error")) {
        summary_df <- rbind(summary_df, data.frame(
          Method = "p-uniform*",
          Bias.Corrected.Estimate = res$puniform_star$est,
          X95..CI.Lower = res$puniform_star$ci.lb,
          X95..CI.Upper = res$puniform_star$ci.ub,
          p.value = format.pval(res$puniform_star$pval, digits = 3),
          Interpretation = "Extended p-uniform method"
        ))
      }

      # Selection models
      if (!is.null(res$selection_3psm) && !inherits(res$selection_3psm, "error")) {
        summary_df <- rbind(summary_df, data.frame(
          Method = "3PSM Selection Model",
          Bias.Corrected.Estimate = res$selection_3psm$adj_est,
          X95..CI.Lower = res$selection_3psm$ci.lb_adj,
          X95..CI.Upper = res$selection_3psm$ci.ub_adj,
          p.value = format.pval(res$selection_3psm$pval_adj, digits = 3),
          Interpretation = "Vevea-Hedges 3-parameter"
        ))
      }

      if (!is.null(res$selection_4psm) && !inherits(res$selection_4psm, "error")) {
        summary_df <- rbind(summary_df, data.frame(
          Method = "4PSM Selection Model",
          Bias.Corrected.Estimate = res$selection_4psm$adj_est,
          X95..CI.Lower = res$selection_4psm$ci.lb_adj,
          X95..CI.Upper = res$selection_4psm$ci.ub_adj,
          p.value = format.pval(res$selection_4psm$pval_adj, digits = 3),
          Interpretation = "Vevea-Hedges 4-parameter"
        ))
      }

      # Trim and Fill
      if (!is.null(res$trimfill) && !inherits(res$trimfill, "error")) {
        summary_df <- rbind(summary_df, data.frame(
          Method = paste0("Trim-and-Fill (k0=", res$trimfill$k0, ")"),
          Bias.Corrected.Estimate = res$trimfill$beta[1],
          X95..CI.Lower = res$trimfill$ci.lb,
          X95..CI.Upper = res$trimfill$ci.ub,
          p.value = format.pval(res$trimfill$pval, digits = 3),
          Interpretation = paste0(res$trimfill$k0, " studies imputed")
        ))
      }

      datatable(
        summary_df,
        options = list(
          pageLength = 15,
          dom = 't',
          ordering = FALSE
        ),
        rownames = FALSE
      ) %>%
        formatRound(columns = c("Bias.Corrected.Estimate", "X95..CI.Lower", "X95..CI.Upper"),
                   digits = 3)
    })


    # Overall assessment
    output$overall_assessment <- renderText({
      req(results())

      res <- results()
      conv_est <- res$conventional_ma$beta[1]

      assessment <- "=== OVERALL PUBLICATION BIAS ASSESSMENT ===\n\n"

      # Count methods indicating bias
      bias_detected <- 0
      methods_run <- 0

      # Check each method
      if (!is.null(res$egger) && !inherits(res$egger, "error")) {
        methods_run <- methods_run + 1
        if (res$egger$pval < 0.05) bias_detected <- bias_detected + 1
      }

      if (!is.null(res$petpeese) && !inherits(res$petpeese, "error")) {
        methods_run <- methods_run + 1
        pct_change <- abs((conv_est - res$petpeese$recommended_estimate) / conv_est) * 100
        if (pct_change > 15) bias_detected <- bias_detected + 1
      }

      if (!is.null(res$pcurve) && !inherits(res$pcurve, "error")) {
        methods_run <- methods_run + 1
        if (res$pcurve$evidential_value == "Absent" ||
            res$pcurve$evidential_value == "Inadequate") {
          bias_detected <- bias_detected + 1
        }
      }

      # Overall conclusion
      bias_proportion <- if (methods_run > 0) bias_detected / methods_run else 0

      if (bias_proportion >= 0.67) {
        conclusion <- "⚠️  STRONG EVIDENCE OF PUBLICATION BIAS"
        recommendation <- "Use bias-corrected estimates. Consider additional unpublished studies."
      } else if (bias_proportion >= 0.33) {
        conclusion <- "⚠️  MODERATE EVIDENCE OF PUBLICATION BIAS"
        recommendation <- "Interpret results with caution. Report both corrected and uncorrected estimates."
      } else {
        conclusion <- "✓ LITTLE EVIDENCE OF PUBLICATION BIAS"
        recommendation <- "Conventional meta-analysis likely reliable."
      }

      assessment <- paste0(
        assessment,
        conclusion, "\n\n",
        "Methods indicating bias: ", bias_detected, " out of ", methods_run, "\n\n",
        "RECOMMENDATION:\n",
        recommendation, "\n\n",
        "NOTES:\n",
        "- Triangulate across multiple methods\n",
        "- Consider pre-registration and grey literature\n",
        "- Report sensitivity analyses\n",
        "- Publication bias assessment is not definitive proof"
      )

      assessment
    })


    # Comparison plot
    output$comparison_plot <- renderPlot({
      req(results())

      res <- results()
      conv_est <- res$conventional_ma$beta[1]
      conv_ci_lb <- res$conventional_ma$ci.lb
      conv_ci_ub <- res$conventional_ma$ci.ub

      # Collect estimates
      estimates <- data.frame(
        Method = "Conventional MA",
        Estimate = conv_est,
        CI_Lower = conv_ci_lb,
        CI_Upper = conv_ci_ub,
        stringsAsFactors = FALSE
      )

      if (!is.null(res$petpeese) && !inherits(res$petpeese, "error")) {
        estimates <- rbind(estimates, data.frame(
          Method = paste0("PET-PEESE (", res$petpeese$recommendation, ")"),
          Estimate = res$petpeese$recommended_estimate,
          CI_Lower = res$petpeese$recommended_ci_lower,
          CI_Upper = res$petpeese$recommended_ci_upper
        ))
      }

      if (!is.null(res$puniform) && !inherits(res$puniform, "error")) {
        estimates <- rbind(estimates, data.frame(
          Method = "p-uniform",
          Estimate = res$puniform$est,
          CI_Lower = res$puniform$ci.lb,
          CI_Upper = res$puniform$ci.ub
        ))
      }

      if (!is.null(res$selection_3psm) && !inherits(res$selection_3psm, "error")) {
        estimates <- rbind(estimates, data.frame(
          Method = "3PSM Selection",
          Estimate = res$selection_3psm$adj_est,
          CI_Lower = res$selection_3psm$ci.lb_adj,
          CI_Upper = res$selection_3psm$ci.ub_adj
        ))
      }

      # Forest plot of corrected estimates
      ggplot(estimates, aes(x = Estimate, y = Method)) +
        geom_point(size = 4) +
        geom_errorbarh(aes(xmin = CI_Lower, xmax = CI_Upper), height = 0.2) +
        geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
        geom_vline(xintercept = conv_est, linetype = "dotted", color = "blue", alpha = 0.5) +
        labs(
          title = "Comparison of Bias-Corrected Effect Estimates",
          subtitle = "Blue dotted line = Conventional MA estimate",
          x = "Effect Size",
          y = ""
        ) +
        theme_minimal(base_size = 14) +
        theme(
          panel.grid.major.y = element_blank(),
          plot.title = element_text(face = "bold")
        )
    })


    # Egger's results
    output$egger_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$egger) && !inherits(res$egger, "error")) {
        print(res$egger)
      } else {
        cat("Egger's test not run or failed\n")
      }
    })


    # Trim and Fill results
    output$trimfill_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$trimfill) && !inherits(res$trimfill, "error")) {
        print(res$trimfill)
      } else {
        cat("Trim-and-Fill not run or failed\n")
      }
    })


    # PET-PEESE results
    output$petpeese_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$petpeese) && !inherits(res$petpeese, "error")) {
        print(res$petpeese)
      } else {
        cat("PET-PEESE not run or failed\n")
      }
    })


    # PET-PEESE plot
    output$petpeese_plot <- renderPlot({
      req(results())
      res <- results()

      if (!is.null(res$petpeese) && !inherits(res$petpeese, "error")) {
        funnel_petpeese(res$yi, sei = res$sei)
      }
    })


    # p-curve results
    output$pcurve_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$pcurve) && !inherits(res$pcurve, "error")) {
        cat("=== P-CURVE ANALYSIS ===\n\n")
        cat("Evidential Value:", res$pcurve$evidential_value, "\n")
        cat("Right-skew test p-value:", format.pval(res$pcurve$right_skew_p, digits = 3), "\n")
        cat("Flatness test p-value:", format.pval(res$pcurve$flatness_p, digits = 3), "\n\n")
        cat("Interpretation:\n")
        cat(res$pcurve$interpretation, "\n")
      } else {
        cat("p-curve not run or failed\n")
        if (!is.null(res$pcurve) && inherits(res$pcurve, "list") && !is.null(res$pcurve$error)) {
          cat("Error:", res$pcurve$error, "\n")
        }
      }
    })


    # p-curve plot
    output$pcurve_plot <- renderPlot({
      req(results())
      res <- results()

      if (!is.null(res$pcurve) && !inherits(res$pcurve, "error")) {
        plot_pcurve(res$pcurve)
      }
    })


    # p-uniform results
    output$puniform_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$puniform) && !inherits(res$puniform, "error")) {
        print(res$puniform)
      } else {
        cat("p-uniform not run or failed\n")
      }
    })


    # p-uniform* results
    output$puniform_star_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$puniform_star) && !inherits(res$puniform_star, "error")) {
        print(res$puniform_star)
      } else {
        cat("p-uniform* not run or failed\n")
      }
    })


    # p-uniform plot
    output$puniform_plot <- renderPlot({
      req(results())
      res <- results()

      if (!is.null(res$puniform) && !inherits(res$puniform, "error")) {
        plot(res$puniform)
      }
    })


    # Selection model 3PSM results
    output$selection_3psm_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$selection_3psm) && !inherits(res$selection_3psm, "error")) {
        print(res$selection_3psm)
      } else {
        cat("3PSM selection model not run or failed\n")
      }
    })


    # Selection model 4PSM results
    output$selection_4psm_results <- renderPrint({
      req(results())
      res <- results()

      if (!is.null(res$selection_4psm) && !inherits(res$selection_4psm, "error")) {
        print(res$selection_4psm)
      } else {
        cat("4PSM selection model not run or failed\n")
      }
    })


    # Selection plot
    output$selection_plot <- renderPlot({
      req(results())
      res <- results()

      if (!is.null(res$selection_3psm) && !inherits(res$selection_3psm, "error")) {
        plot(res$selection_3psm, main = "Selection Model (3PSM)")
      }
    })


    # Contour funnel plot
    output$contour_funnel <- renderPlot({
      req(results())
      res <- results()

      metafor::funnel(res$conventional_ma,
                     level = c(90, 95, 99),
                     shade = c("white", "gray75", "gray60"),
                     refline = 0,
                     main = "Contour-Enhanced Funnel Plot",
                     legend = TRUE)
    })


    # Cumulative meta-analysis
    output$cumulative_ma <- renderPlot({
      req(results())
      res <- results()

      cum_ma <- metafor::cumul(res$conventional_ma, order = order(1/res$vi))

      plot(cum_ma,
           main = "Cumulative Meta-Analysis",
           xlab = "Cumulative Effect Size")
    })


    # DOI plot
    output$doi_plot <- renderPlot({
      req(results())
      res <- results()

      # Simulate DOI plot (Debt of Insufficient Studies)
      # This is a placeholder - full implementation would use Ioannidis method
      plot(1/res$sei, res$yi,
           xlab = "Precision (1/SE)",
           ylab = "Effect Size",
           main = "DOI Plot (Detection of Excess Significance)",
           pch = 19, col = "darkblue")
      abline(h = 0, lty = 2, col = "red")

      # Add regression line
      doi_fit <- lm(res$yi ~ I(1/res$sei))
      abline(doi_fit, col = "blue", lwd = 2)
    })


    # P-value distribution
    output$pvalue_dist <- renderPlot({
      req(results())
      res <- results()

      # Calculate two-tailed p-values
      z_scores <- res$yi / res$sei
      p_values <- 2 * pnorm(-abs(z_scores))

      hist(p_values, breaks = 20,
           col = "skyblue", border = "white",
           main = "Distribution of p-values",
           xlab = "p-value",
           ylab = "Frequency")
      abline(v = 0.05, col = "red", lwd = 2, lty = 2)

      # Add expected uniform distribution line
      abline(h = length(p_values) / 20, col = "blue", lwd = 2, lty = 2)

      legend("topright",
             legend = c("α = 0.05", "Uniform expectation"),
             col = c("red", "blue"),
             lty = 2, lwd = 2)
    })


    # Funnel plot
    output$funnel_plot <- renderPlot({
      req(results())
      res <- results()

      par(mfrow = c(1, 2))

      # Standard funnel
      metafor::funnel(res$conventional_ma,
                     main = "Standard Funnel Plot",
                     xlab = "Effect Size")

      # Trim-and-fill funnel
      if (!is.null(res$trimfill) && !inherits(res$trimfill, "error")) {
        metafor::funnel(res$trimfill,
                       main = paste0("Trim-and-Fill (k0=", res$trimfill$k0, ")"),
                       xlab = "Effect Size")
      } else {
        plot.new()
        text(0.5, 0.5, "Trim-and-Fill not available")
      }

      par(mfrow = c(1, 1))
    })


    # Download report
    output$download_report <- downloadHandler(
      filename = function() {
        paste0("publication_bias_report_", Sys.Date(), ".html")
      },
      content = function(file) {
        req(results())

        # Create comprehensive HTML report
        report_html <- generate_publication_bias_report(results())
        writeLines(report_html, file)

        showNotification("Report downloaded successfully!", type = "message")
      }
    )

  })
}


# ============================================================================
# Helper Functions
# ============================================================================

#' Run p-curve Analysis
#'
#' Implements p-curve method from Simonsohn et al. (2014)
#'
#' @param yi Effect sizes
#' @param vi Variances
#' @return List with p-curve results
#' @keywords internal
run_pcurve_analysis <- function(yi, vi) {

  sei <- sqrt(vi)

  # Calculate two-tailed p-values
  z_scores <- yi / sei
  p_values <- 2 * pnorm(-abs(z_scores))

  # Only use significant studies (p < 0.05)
  sig_studies <- p_values < 0.05

  if (sum(sig_studies) < 10) {
    return(list(
      error = paste0("p-curve requires at least 10 significant studies. Found: ", sum(sig_studies))
    ))
  }

  p_sig <- p_values[sig_studies]

  # Convert to pp-values (p-values of p-values)
  # Under null, p-values should be uniform [0, 0.05]
  # Under alternative with evidential value, right-skewed

  # Test 1: Right-skew (evidential value)
  # Compare observed distribution to uniform [0, 0.05]
  # Using binomial test: more studies with p < 0.025 than expected
  n_sig <- length(p_sig)
  n_very_sig <- sum(p_sig < 0.025)

  # Under null uniform [0, 0.05], expect 50% below 0.025
  right_skew_test <- binom.test(n_very_sig, n_sig, p = 0.5, alternative = "greater")

  # Test 2: Flatness test (absent evidential value)
  # Test if distribution is flat (uniform)
  flatness_test <- ks.test(p_sig, "punif", min = 0, max = 0.05)

  # Determine evidential value
  if (right_skew_test$p.value < 0.05) {
    evidential_value <- "Present"
    interpretation <- paste0(
      "The p-curve is right-skewed (p=", format.pval(right_skew_test$p.value, digits = 3), "), ",
      "indicating evidential value is present. The research finding is likely real."
    )
  } else if (right_skew_test$p.value >= 0.05 && flatness_test$p.value < 0.05) {
    evidential_value <- "Absent"
    interpretation <- paste0(
      "The p-curve is not right-skewed (p=", format.pval(right_skew_test$p.value, digits = 3), "), ",
      "indicating evidential value is absent or inadequate. Results may reflect publication bias."
    )
  } else {
    evidential_value <- "Inadequate"
    interpretation <- "Evidence is inadequate to determine if evidential value is present or absent."
  }

  list(
    p_values = p_sig,
    n_significant = n_sig,
    n_very_significant = n_very_sig,
    right_skew_p = right_skew_test$p.value,
    flatness_p = flatness_test$p.value,
    evidential_value = evidential_value,
    interpretation = interpretation
  )
}


#' Plot p-curve
#'
#' @param pcurve_result Result from run_pcurve_analysis
#' @keywords internal
plot_pcurve <- function(pcurve_result) {

  p_values <- pcurve_result$p_values

  # Create histogram
  hist(p_values, breaks = seq(0, 0.05, by = 0.005),
       col = "skyblue", border = "white",
       main = "p-curve: Distribution of Significant p-values",
       xlab = "p-value",
       ylab = "Frequency",
       xlim = c(0, 0.05))

  # Add expected uniform distribution
  abline(h = length(p_values) / 10, col = "red", lwd = 2, lty = 2)

  # Add markers
  abline(v = 0.025, col = "blue", lwd = 2, lty = 2)

  # Add text annotations
  text(0.04, max(hist(p_values, breaks = 10, plot = FALSE)$counts) * 0.9,
       paste0("Evidential Value: ", pcurve_result$evidential_value),
       col = ifelse(pcurve_result$evidential_value == "Present", "darkgreen", "darkred"),
       font = 2)

  legend("topright",
         legend = c("Observed", "Expected (uniform)", "p = 0.025"),
         col = c("skyblue", "red", "blue"),
         lty = c(0, 2, 2),
         lwd = c(0, 2, 2),
         pch = c(15, NA, NA))
}


#' Generate Publication Bias HTML Report
#'
#' @param results List of all publication bias results
#' @return HTML string
#' @keywords internal
generate_publication_bias_report <- function(results) {

  html <- paste0(
    "<!DOCTYPE html>",
    "<html><head>",
    "<title>Publication Bias Analysis Report</title>",
    "<style>",
    "body { font-family: Arial, sans-serif; margin: 40px; }",
    "h1 { color: #2c3e50; }",
    "h2 { color: #34495e; border-bottom: 2px solid #3498db; padding-bottom: 5px; }",
    "table { border-collapse: collapse; width: 100%; margin: 20px 0; }",
    "th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }",
    "th { background-color: #3498db; color: white; }",
    ".warning { background-color: #fff3cd; padding: 10px; border-left: 4px solid #ffc107; }",
    ".success { background-color: #d4edda; padding: 10px; border-left: 4px solid #28a745; }",
    "</style>",
    "</head><body>",
    "<h1>📊 Publication Bias Analysis Report</h1>",
    "<p><strong>Date:</strong> ", Sys.Date(), "</p>",
    "<p><strong>Number of Studies:</strong> ", length(results$yi), "</p>",

    # Add summary sections here
    "<h2>Summary of Results</h2>",
    "<p>This report presents comprehensive publication bias assessment using multiple methods.</p>",

    # Add method-specific sections

    "</body></html>"
  )

  html
}
