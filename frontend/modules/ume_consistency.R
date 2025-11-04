# ==============================================================================
# UME CONSISTENCY MODEL MODULE
# ==============================================================================
#
# Unrelated Mean Effects (UME) model for detecting inconsistency in Network
# Meta-Analysis. Alternative to design-by-treatment interaction model with
# better power for detecting inconsistency.
#
# References:
# - Dias et al. (2013) Evidence synthesis for decision making 4:
#   inconsistency in networks of evidence based on randomized controlled trials
# - NICE TSD 4: Inconsistency in Networks of Evidence Based on Randomised
#   Controlled Trials
#
# Version: 4.0.0
# Last Updated: 2025-11-04
# ==============================================================================

# Required packages
library(shiny)
library(bslib)
library(rjags)
library(R2jags)
library(coda)
library(ggplot2)
library(plotly)
library(DT)

# ==============================================================================
# UI FUNCTION
# ==============================================================================

ume_consistency_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      class = "bg-primary text-white",
      "UME Consistency Model - Advanced Inconsistency Detection"
    ),
    card_body(
      # Information panel
      card(
        card_header("What is UME?"),
        card_body(
          p("The Unrelated Mean Effects (UME) model is an alternative approach to detecting
            inconsistency in network meta-analysis. Unlike traditional node-splitting, UME:"),
          tags$ul(
            tags$li("Has better statistical power for detecting inconsistency"),
            tags$li("Tests all comparisons simultaneously (vs one-at-a-time)"),
            tags$li("Recommended by NICE TSD 4 for consistency assessment"),
            tags$li("Compares model fit between consistency and UME models")
          ),
          p(strong("Interpretation:"), "If UME model fits significantly better than consistency
            model, inconsistency is detected in the network.")
        )
      ),

      hr(),

      # Analysis settings
      layout_columns(
        col_widths = c(6, 6),

        # Column 1: Model settings
        card(
          card_header("Model Settings"),
          card_body(
            selectInput(
              ns("outcome_var"),
              "Outcome Variable:",
              choices = NULL  # Populated dynamically
            ),

            selectInput(
              ns("effect_measure"),
              "Effect Measure:",
              choices = c(
                "Risk Ratio (RR)" = "RR",
                "Odds Ratio (OR)" = "OR",
                "Risk Difference (RD)" = "RD",
                "Mean Difference (MD)" = "MD",
                "Standardized MD (SMD)" = "SMD",
                "Hazard Ratio (HR)" = "HR"
              ),
              selected = "RR"
            ),

            selectInput(
              ns("reference_treatment"),
              "Reference Treatment:",
              choices = NULL  # Populated dynamically
            ),

            numericInput(
              ns("n_adapt"),
              "Adaptation Iterations:",
              value = 5000,
              min = 1000,
              max = 50000,
              step = 1000
            ),

            numericInput(
              ns("n_iter"),
              "MCMC Iterations:",
              value = 50000,
              min = 10000,
              max = 200000,
              step = 10000
            ),

            numericInput(
              ns("n_burnin"),
              "Burn-in:",
              value = 20000,
              min = 5000,
              max = 100000,
              step = 5000
            ),

            numericInput(
              ns("n_thin"),
              "Thinning:",
              value = 5,
              min = 1,
              max = 20,
              step = 1
            ),

            numericInput(
              ns("n_chains"),
              "Number of Chains:",
              value = 3,
              min = 2,
              max = 5,
              step = 1
            )
          )
        ),

        # Column 2: Analysis actions
        card(
          card_header("Analysis"),
          card_body(
            actionButton(
              ns("fit_models"),
              "Fit Consistency & UME Models",
              icon = icon("play"),
              class = "btn-primary btn-lg w-100 mb-3"
            ),

            hr(),

            h5("Quick Actions:"),
            actionButton(
              ns("show_diagnostics"),
              "MCMC Diagnostics",
              icon = icon("chart-line"),
              class = "btn-outline-secondary w-100 mb-2"
            ),

            actionButton(
              ns("export_results"),
              "Export Results",
              icon = icon("download"),
              class = "btn-outline-secondary w-100 mb-2"
            ),

            hr(),

            h5("Model Status:"),
            uiOutput(ns("model_status"))
          )
        )
      ),

      hr(),

      # Results tabs
      navset_card_tab(
        id = ns("results_tabs"),

        # Tab 1: Model comparison
        nav_panel(
          "Model Comparison",
          icon = icon("balance-scale"),

          card(
            card_header("Deviance Comparison"),
            card_body(
              p("Lower deviance indicates better model fit. If UME model has substantially
                lower deviance, inconsistency is present."),

              DTOutput(ns("deviance_table"))
            )
          ),

          card(
            card_header("Inconsistency Test"),
            card_body(
              uiOutput(ns("inconsistency_test"))
            )
          ),

          card(
            card_header("Model Selection"),
            card_body(
              uiOutput(ns("model_selection"))
            )
          )
        ),

        # Tab 2: Treatment effects
        nav_panel(
          "Treatment Effects",
          icon = icon("chart-bar"),

          card(
            card_header("Consistency vs UME Estimates"),
            card_body(
              p("Comparison of treatment effect estimates under both models."),

              DTOutput(ns("effects_table")),

              hr(),

              plotlyOutput(ns("effects_forest"), height = "600px")
            )
          )
        ),

        # Tab 3: MCMC diagnostics
        nav_panel(
          "MCMC Diagnostics",
          icon = icon("stethoscope"),

          card(
            card_header("Convergence Diagnostics"),
            card_body(
              h5("Gelman-Rubin Statistic (R-hat)"),
              p("R-hat < 1.1 indicates convergence. Values > 1.1 suggest more iterations needed."),
              DTOutput(ns("gelman_table")),

              hr(),

              h5("Effective Sample Size (n.eff)"),
              p("Higher values indicate better mixing. Generally want n.eff > 1000."),
              DTOutput(ns("neff_table"))
            )
          ),

          card(
            card_header("Trace Plots"),
            card_body(
              p("Visual inspection of MCMC chains. Look for:"),
              tags$ul(
                tags$li("Good mixing (hairy caterpillar)"),
                tags$li("No trends or drift"),
                tags$li("Chains overlap")
              ),

              selectInput(
                ns("trace_parameter"),
                "Select Parameter:",
                choices = NULL  # Populated after model fit
              ),

              plotOutput(ns("trace_plot"), height = "400px")
            )
          ),

          card(
            card_header("Density Plots"),
            card_body(
              plotOutput(ns("density_plot"), height = "400px")
            )
          )
        ),

        # Tab 4: Interpretation
        nav_panel(
          "Interpretation",
          icon = icon("lightbulb"),

          card(
            card_header("UME Analysis Interpretation"),
            card_body(
              uiOutput(ns("interpretation_text"))
            )
          ),

          card(
            card_header("Recommendations"),
            card_body(
              uiOutput(ns("recommendations"))
            )
          )
        )
      )
    )
  )
}

# ==============================================================================
# SERVER FUNCTION
# ==============================================================================

ume_consistency_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values for this module
    ume_rv <- reactiveValues(
      consistency_model = NULL,
      ume_model = NULL,
      fitted = FALSE,
      comparison_results = NULL
    )

    # ==============================================================================
    # JAGS MODEL DEFINITIONS
    # ==============================================================================

    # Consistency model JAGS code
    consistency_model_code <- "
    model {
      # Likelihood
      for (i in 1:ns) {  # Loop over studies
        for (k in 1:na[i]) {  # Loop over arms
          # Binomial likelihood (for binary outcomes)
          r[i,k] ~ dbin(p[i,k], n[i,k])

          # Model for probabilities
          logit(p[i,k]) <- mu[i] + delta[i,k]

          # Study baseline effect
          mu[i] ~ dnorm(0, 0.0001)

          # Treatment effects
          delta[i,1] <- 0  # Reference arm

          for (j in 2:na[i]) {
            delta[i,j] ~ dnorm(d[t[i,1], t[i,j]], prec)
          }
        }
      }

      # Consistency constraint
      for (c in 1:(nt-1)) {
        for (k in (c+1):nt) {
          d[c,k] <- d_ref[k] - d_ref[c]
          d[k,c] <- d_ref[c] - d_ref[k]
        }
      }

      # Reference treatment effect (constrained to 0)
      d_ref[1] <- 0

      # Treatment effects vs reference
      for (k in 2:nt) {
        d_ref[k] ~ dnorm(0, 0.0001)
      }

      # Between-study heterogeneity
      tau ~ dunif(0, 10)
      tau2 <- tau * tau
      prec <- 1 / tau2
    }
    "

    # UME model JAGS code
    ume_model_code <- "
    model {
      # Likelihood
      for (i in 1:ns) {  # Loop over studies
        for (k in 1:na[i]) {  # Loop over arms
          # Binomial likelihood
          r[i,k] ~ dbin(p[i,k], n[i,k])

          # Model for probabilities
          logit(p[i,k]) <- mu[i] + delta[i,k]

          # Study baseline effect
          mu[i] ~ dnorm(0, 0.0001)

          # Treatment effects
          delta[i,1] <- 0  # Reference arm

          for (j in 2:na[i]) {
            # UME: Each design has unrelated mean effects
            delta[i,j] ~ dnorm(theta[design[i], t[i,1], t[i,j]], prec)
          }
        }
      }

      # Unrelated mean effects for each design
      for (d in 1:nd) {  # Loop over designs
        for (c in 1:(nt-1)) {
          for (k in (c+1):nt) {
            theta[d,c,k] ~ dnorm(0, 0.0001)  # Unrelated across designs
            theta[d,k,c] <- -theta[d,c,k]  # Symmetry
          }
        }
      }

      # Between-study heterogeneity
      tau ~ dunif(0, 10)
      tau2 <- tau * tau
      prec <- 1 / tau2
    }
    "

    # ==============================================================================
    # HELPER FUNCTIONS
    # ==============================================================================

    # Prepare data for JAGS
    prepare_nma_data_for_jags <- function(data, ref_treatment) {
      # Convert data to JAGS format
      # This is a simplified version - would need enhancement for production

      # Number of studies
      ns <- length(unique(data$study))

      # Number of treatments
      treatments <- unique(c(data$treatment, data$control))
      nt <- length(treatments)

      # Number of arms per study
      na <- tapply(data$treatment, data$study, function(x) length(unique(x)) + 1)

      # Treatment IDs
      t_ids <- match(treatments, treatments)

      # Events and sample sizes
      r <- matrix(NA, ns, max(na))
      n <- matrix(NA, ns, max(na))

      # Design IDs (for UME model)
      designs <- unique(paste(data$treatment, data$control, sep = "_"))
      nd <- length(designs)

      design_id <- match(paste(data$treatment, data$control, sep = "_"), designs)

      list(
        ns = ns,
        nt = nt,
        na = na,
        r = r,
        n = n,
        t = t_ids,
        nd = nd,
        design = design_id
      )
    }

    # ==============================================================================
    # REACTIVE: Fit models
    # ==============================================================================

    observeEvent(input$fit_models, {
      req(rv$nma_data)

      showNotification("Fitting consistency and UME models... This may take several minutes.",
                      type = "message", duration = NULL, id = "fitting")

      tryCatch({
        # Prepare data
        jags_data <- prepare_nma_data_for_jags(rv$nma_data, input$reference_treatment)

        # Fit consistency model
        showNotification("Fitting consistency model...", type = "message", id = "cons")

        consistency_fit <- jags(
          data = jags_data,
          model.file = textConnection(consistency_model_code),
          parameters.to.save = c("d_ref", "tau", "deviance"),
          n.iter = input$n_iter,
          n.burnin = input$n_burnin,
          n.thin = input$n_thin,
          n.chains = input$n_chains
        )

        # Fit UME model
        showNotification("Fitting UME model...", type = "message", id = "ume")

        ume_fit <- jags(
          data = jags_data,
          model.file = textConnection(ume_model_code),
          parameters.to.save = c("theta", "tau", "deviance"),
          n.iter = input$n_iter,
          n.burnin = input$n_burnin,
          n.thin = input$n_thin,
          n.chains = input$n_chains
        )

        # Store results
        ume_rv$consistency_model <- consistency_fit
        ume_rv$ume_model <- ume_fit
        ume_rv$fitted <- TRUE

        # Compare models
        ume_rv$comparison_results <- compare_models(consistency_fit, ume_fit)

        removeNotification("fitting")
        removeNotification("cons")
        removeNotification("ume")

        showNotification("Models fitted successfully!", type = "message", duration = 5)

      }, error = function(e) {
        removeNotification("fitting")
        removeNotification("cons")
        removeNotification("ume")
        showNotification(paste("Error fitting models:", e$message),
                        type = "error", duration = NULL)
      })
    })

    # Compare models
    compare_models <- function(consistency_fit, ume_fit) {
      # Extract deviances
      dev_consistency <- consistency_fit$BUGSoutput$mean$deviance
      dev_ume <- ume_fit$BUGSoutput$mean$deviance

      # Deviance difference
      dev_diff <- dev_consistency - dev_ume

      # Calculate p-value (chi-square test)
      # df = difference in number of parameters
      df <- (consistency_fit$BUGSoutput$n.parameters -
             ume_fit$BUGSoutput$n.parameters)
      p_value <- 1 - pchisq(dev_diff, df)

      # DIC comparison
      dic_consistency <- consistency_fit$BUGSoutput$DIC
      dic_ume <- ume_fit$BUGSoutput$DIC
      dic_diff <- dic_consistency - dic_ume

      list(
        dev_consistency = dev_consistency,
        dev_ume = dev_ume,
        dev_diff = dev_diff,
        df = df,
        p_value = p_value,
        dic_consistency = dic_consistency,
        dic_ume = dic_ume,
        dic_diff = dic_diff,
        inconsistency_detected = (p_value < 0.05)
      )
    }

    # ==============================================================================
    # OUTPUTS
    # ==============================================================================

    # Model status
    output$model_status <- renderUI({
      if (!ume_rv$fitted) {
        tags$div(
          class = "alert alert-info",
          icon("info-circle"), " Models not yet fitted."
        )
      } else {
        tags$div(
          class = "alert alert-success",
          icon("check-circle"), " Models fitted successfully!"
        )
      }
    })

    # Deviance comparison table
    output$deviance_table <- renderDT({
      req(ume_rv$fitted, ume_rv$comparison_results)

      comp <- ume_rv$comparison_results

      data.frame(
        Model = c("Consistency", "UME", "Difference"),
        Deviance = c(
          round(comp$dev_consistency, 2),
          round(comp$dev_ume, 2),
          round(comp$dev_diff, 2)
        ),
        DIC = c(
          round(comp$dic_consistency, 2),
          round(comp$dic_ume, 2),
          round(comp$dic_diff, 2)
        )
      ) %>%
        datatable(
          options = list(dom = 't', pageLength = 3),
          rownames = FALSE
        )
    })

    # Inconsistency test
    output$inconsistency_test <- renderUI({
      req(ume_rv$fitted, ume_rv$comparison_results)

      comp <- ume_rv$comparison_results

      if (comp$inconsistency_detected) {
        tags$div(
          class = "alert alert-warning",
          h4(icon("exclamation-triangle"), " Inconsistency Detected"),
          p(strong("Deviance Difference:"), round(comp$dev_diff, 2)),
          p(strong("P-value:"), format.pval(comp$p_value, digits = 3)),
          p("The UME model fits significantly better than the consistency model,
            indicating inconsistency in the network. Consider:"),
          tags$ul(
            tags$li("Node-splitting to identify problematic comparisons"),
            tags$li("Meta-regression to explain inconsistency"),
            tags$li("Sensitivity analyses excluding high risk of bias studies")
          )
        )
      } else {
        tags$div(
          class = "alert alert-success",
          h4(icon("check-circle"), " No Significant Inconsistency"),
          p(strong("Deviance Difference:"), round(comp$dev_diff, 2)),
          p(strong("P-value:"), format.pval(comp$p_value, digits = 3)),
          p("The consistency model fits adequately. No evidence of inconsistency detected.")
        )
      }
    })

    # Model selection recommendation
    output$model_selection <- renderUI({
      req(ume_rv$fitted, ume_rv$comparison_results)

      comp <- ume_rv$comparison_results

      if (comp$dic_diff > 5) {
        recommended <- "UME Model"
        reason <- "DIC difference > 5 strongly favors UME model"
      } else if (comp$dic_diff > 3) {
        recommended <- "UME Model"
        reason <- "DIC difference > 3 moderately favors UME model"
      } else {
        recommended <- "Consistency Model"
        reason <- "DIC difference < 3 suggests consistency model is adequate"
      }

      tags$div(
        h5("Recommended Model:", strong(recommended)),
        p(reason),
        p(strong("DIC Difference:"), round(comp$dic_diff, 2))
      )
    })

    # Interpretation text
    output$interpretation_text <- renderUI({
      req(ume_rv$fitted, ume_rv$comparison_results)

      comp <- ume_rv$comparison_results

      tags$div(
        h5("Understanding UME Analysis Results"),

        p("The UME (Unrelated Mean Effects) model allows treatment effects to differ
          across designs, while the consistency model assumes a single pooled effect for
          each treatment comparison."),

        h6("Key Findings:"),
        tags$ul(
          tags$li(strong("Deviance Difference:"), round(comp$dev_diff, 2),
                 "- A larger value indicates better fit of UME model"),
          tags$li(strong("P-value:"), format.pval(comp$p_value, digits = 3),
                 "- Tests statistical significance of deviance difference"),
          tags$li(strong("DIC Difference:"), round(comp$dic_diff, 2),
                 "- Penalized model fit metric (>3 suggests meaningful difference)")
        ),

        h6("Clinical Implications:"),
        if (comp$inconsistency_detected) {
          p("Inconsistency detected suggests that treatment effects vary across different
            study designs or populations. This may indicate:"),
          tags$ul(
            tags$li("Effect modification by study characteristics"),
            tags$li("Differences in study populations or interventions"),
            tags$li("Bias in some studies"),
            tags$li("Violations of transitivity assumption")
          )
        } else {
          p("No significant inconsistency detected. The network meta-analysis results can be
            interpreted with confidence, assuming transitivity holds.")
        }
      )
    })

    # Recommendations
    output$recommendations <- renderUI({
      req(ume_rv$fitted, ume_rv$comparison_results)

      comp <- ume_rv$comparison_results

      if (comp$inconsistency_detected) {
        tags$div(
          class = "alert alert-info",
          h5("Recommended Next Steps:"),
          tags$ol(
            tags$li("Perform node-splitting analysis to identify specific inconsistent comparisons"),
            tags$li("Investigate potential effect modifiers through meta-regression"),
            tags$li("Consider subgroup analyses by study characteristics"),
            tags$li("Assess risk of bias and conduct sensitivity analyses"),
            tags$li("Evaluate transitivity assumption for the network")
          )
        )
      } else {
        tags$div(
          class = "alert alert-success",
          h5("Network Appears Consistent:"),
          tags$ul(
            tags$li("Proceed with standard consistency model results"),
            tags$li("Report consistency assessment in manuscript"),
            tags$li("Consider additional sensitivity analyses as planned")
          )
        )
      }
    })

    # Return reactive values
    return(ume_rv)
  })
}

# ==============================================================================
# END OF MODULE
# ==============================================================================
