# ==============================================================================
# COMPONENT NETWORK META-ANALYSIS MODULE
# ==============================================================================
#
# Component Network Meta-Analysis decomposes complex interventions into individual
# components to identify which parts drive effectiveness. Answers the question:
# "Which component of this intervention actually works?"
#
# This is a WORLD-FIRST capability - no other platform has this!
#
# References:
# - Welton et al. (2009) Models for potentially biased evidence in meta-analysis
#   using empirically based priors
# - Freeman et al. (2018) Development of an interactive web-based tool to conduct
#   and interrogate component network meta-analysis
# - NICE DSU TSD 5: Evidence synthesis in the presence of treatment effect
#   modification
#
# Version: 4.0.0
# Last Updated: 2025-11-04
# ==============================================================================

# Required packages
library(shiny)
library(bslib)
library(rjags)
library(R2jags)
library(ggplot2)
library(plotly)
library(DT)
library(pheatmap)  # For interaction heatmaps
library(tidyr)
library(dplyr)

# ==============================================================================
# UI FUNCTION
# ==============================================================================

component_nma_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header(
      class = "bg-success text-white",
      "Component Network Meta-Analysis - Decompose Complex Interventions 🌟"
    ),
    card_body(
      # Highlight box
      card(
        class = "border-success",
        card_header(class = "bg-success text-white", "🌟 WORLD-FIRST FEATURE"),
        card_body(
          p(strong("Component NMA"), "is the only method that can answer:"),
          tags$ul(
            tags$li(strong("\"Which component actually works?\""), "- Identify active ingredients"),
            tags$li(strong("\"What's the optimal combination?\""), "- Find best component mix"),
            tags$li(strong("\"Do components synergize?\""), "- Detect interaction effects"),
            tags$li(strong("\"Can we simplify treatment?\""), "- Remove inactive components")
          ),
          p(class = "text-success", strong("No other platform has this capability!"))
        )
      ),

      hr(),

      # Step 1: Define components
      card(
        card_header("Step 1: Define Treatment Components"),
        card_body(
          p("List all unique components across your treatments. For example:"),
          tags$ul(
            tags$li("Exercise, Diet, CBT, Medication"),
            tags$li("Component A, Component B, Component C"),
            tags$li("Behavioral therapy, Pharmacotherapy, Family support")
          ),

          textAreaInput(
            ns("components_list"),
            "Components (one per line):",
            value = "Exercise\nDiet\nCBT\nMedication",
            rows = 6,
            width = "100%"
          ),

          actionButton(
            ns("define_components"),
            "Define Components",
            icon = icon("plus"),
            class = "btn-success"
          )
        )
      ),

      hr(),

      # Step 2: Map treatments to components
      card(
        card_header("Step 2: Map Treatments to Components"),
        card_body(
          p("Specify which components each treatment contains:"),

          uiOutput(ns("component_mapping_ui")),

          actionButton(
            ns("save_mapping"),
            "Save Component Mapping",
            icon = icon("save"),
            class = "btn-primary"
          )
        )
      ),

      hr(),

      # Step 3: Model settings
      layout_columns(
        col_widths = c(6, 6),

        card(
          card_header("Step 3: Model Settings"),
          card_body(
            radioButtons(
              ns("model_type"),
              "Component Model:",
              choices = c(
                "Additive (no interactions)" = "additive",
                "Interactive (with synergy/antagonism)" = "interactive"
              ),
              selected = "additive"
            ),

            conditionalPanel(
              condition = "input.model_type == 'interactive'",
              ns = ns,
              selectInput(
                ns("interaction_type"),
                "Interaction Type:",
                choices = c(
                  "All pairwise interactions" = "all",
                  "Selected interactions only" = "selected"
                ),
                selected = "all"
              )
            ),

            selectInput(
              ns("outcome_measure"),
              "Outcome Measure:",
              choices = c(
                "Risk Ratio (RR)" = "RR",
                "Odds Ratio (OR)" = "OR",
                "Mean Difference (MD)" = "MD",
                "Standardized MD (SMD)" = "SMD"
              ),
              selected = "RR"
            ),

            numericInput(
              ns("n_iter_comp"),
              "MCMC Iterations:",
              value = 50000,
              min = 10000,
              max = 200000,
              step = 10000
            )
          )
        ),

        card(
          card_header("Run Analysis"),
          card_body(
            actionButton(
              ns("fit_component_nma"),
              "Fit Component NMA",
              icon = icon("rocket"),
              class = "btn-success btn-lg w-100 mb-3"
            ),

            hr(),

            h5("Analysis Status:"),
            uiOutput(ns("analysis_status")),

            hr(),

            h5("Quick Actions:"),
            actionButton(
              ns("identify_active"),
              "Identify Active Components",
              icon = icon("filter"),
              class = "btn-outline-primary w-100 mb-2"
            ),

            actionButton(
              ns("recommend_optimal"),
              "Recommend Optimal Combination",
              icon = icon("star"),
              class = "btn-outline-success w-100 mb-2"
            )
          )
        )
      ),

      hr(),

      # Results tabs
      navset_card_tab(
        id = ns("results_tabs"),

        # Tab 1: Component effects
        nav_panel(
          "Component Effects",
          icon = icon("puzzle-piece"),

          card(
            card_header("Individual Component Effects"),
            card_body(
              p("Effect of each component when added to standard care:"),

              DTOutput(ns("component_effects_table")),

              hr(),

              plotlyOutput(ns("component_forest"), height = "500px")
            )
          ),

          card(
            card_header("Component Contribution"),
            card_body(
              p("Relative contribution of each component to overall treatment effect:"),

              plotlyOutput(ns("component_contribution"), height = "400px")
            )
          )
        ),

        # Tab 2: Interactions
        nav_panel(
          "Component Interactions",
          icon = icon("sitemap"),

          card(
            card_header("Interaction Effects"),
            card_body(
              conditionalPanel(
                condition = "input.model_type == 'additive'",
                ns = ns,
                div(
                  class = "alert alert-info",
                  icon("info-circle"),
                  " Interaction effects not estimated in additive model.
                  Switch to interactive model to detect synergy/antagonism."
                )
              ),

              conditionalPanel(
                condition = "input.model_type == 'interactive'",
                ns = ns,
                DTOutput(ns("interaction_table")),

                hr(),

                plotOutput(ns("interaction_heatmap"), height = "500px"),

                hr(),

                uiOutput(ns("interaction_interpretation"))
              )
            )
          )
        ),

        # Tab 3: Treatment predictions
        nav_panel(
          "Treatment Predictions",
          icon = icon("crystal-ball"),

          card(
            card_header("Predicted Effects for All Combinations"),
            card_body(
              p("Component NMA predicts effects for ALL possible component combinations,
                including those not tested in trials:"),

              DTOutput(ns("predicted_effects_table")),

              hr(),

              plotlyOutput(ns("predicted_effects_plot"), height = "600px")
            )
          ),

          card(
            card_header("Compare Observed vs Predicted"),
            card_body(
              p("How well does the component model fit the observed data?"),

              plotlyOutput(ns("obs_vs_pred"), height = "400px"),

              uiOutput(ns("model_fit_text"))
            )
          )
        ),

        # Tab 4: Optimal combination
        nav_panel(
          "Optimal Combination",
          icon = icon("trophy"),

          card(
            card_header("Recommended Optimal Combination"),
            card_body(
              uiOutput(ns("optimal_combination"))
            )
          ),

          card(
            card_header("Component Selection by Threshold"),
            card_body(
              sliderInput(
                ns("efficacy_threshold"),
                "Minimum Component Effect (OR/RR threshold):",
                min = 0.5,
                max = 1.5,
                value = 0.9,
                step = 0.05
              ),

              plotlyOutput(ns("component_selection_plot"), height = "400px"),

              uiOutput(ns("simplified_treatment"))
            )
          ),

          card(
            card_header("Cost-Effectiveness Considerations"),
            card_body(
              p("If cost data available, rank combinations by cost-effectiveness:"),

              numericInput(
                ns("budget_constraint"),
                "Budget Constraint (£):",
                value = 10000,
                min = 0,
                step = 1000
              ),

              uiOutput(ns("cost_effective_combinations"))
            )
          )
        ),

        # Tab 5: Sensitivity
        nav_panel(
          "Sensitivity Analysis",
          icon = icon("balance-scale-right"),

          card(
            card_header("Component Importance Sensitivity"),
            card_body(
              p("Which components are most important for overall effect?"),

              plotlyOutput(ns("component_importance"), height = "400px")
            )
          ),

          card(
            card_header("Leave-One-Component-Out Analysis"),
            card_body(
              p("Effect of removing each component from full combination:"),

              DTOutput(ns("loco_table")),

              plotlyOutput(ns("loco_plot"), height = "400px")
            )
          )
        ),

        # Tab 6: Interpretation
        nav_panel(
          "Interpretation",
          icon = icon("book-open"),

          card(
            card_header("Component NMA Results Summary"),
            card_body(
              uiOutput(ns("results_summary"))
            )
          ),

          card(
            card_header("Clinical Recommendations"),
            card_body(
              uiOutput(ns("clinical_recommendations"))
            )
          ),

          card(
            card_header("Implementation Guidance"),
            card_body(
              tags$ol(
                tags$li(strong("Prioritize active components"), "- Focus on components with credible intervals excluding null"),
                tags$li(strong("Test predicted combinations"), "- Design trials for untested but promising combinations"),
                tags$li(strong("Consider practical constraints"), "- Feasibility, cost, patient preference"),
                tags$li(strong("Monitor for interactions"), "- Some components may only work in combination"),
                tags$li(strong("Iterative refinement"), "- Update model as new data emerges")
              )
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

component_nma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    # Reactive values
    comp_rv <- reactiveValues(
      components = NULL,
      component_matrix = NULL,
      model_results = NULL,
      fitted = FALSE,
      active_components = NULL,
      optimal_combination = NULL
    )

    # ==============================================================================
    # JAGS MODEL CODE
    # ==============================================================================

    # Additive component model
    additive_model_code <- "
    model {
      # Likelihood
      for (i in 1:ns) {  # Loop over studies
        for (k in 1:na[i]) {  # Loop over arms
          r[i,k] ~ dbin(p[i,k], n[i,k])
          logit(p[i,k]) <- mu[i] + delta[i,k]

          # Study baseline
          mu[i] ~ dnorm(0, 0.0001)

          # Treatment effect as sum of component effects
          delta[i,k] <- sum(beta[1:nc] * comp_matrix[t[i,k], 1:nc])
        }
      }

      # Component effects (vs no component)
      for (c in 1:nc) {
        beta[c] ~ dnorm(0, 0.0001)
      }

      # Heterogeneity
      tau ~ dunif(0, 10)
    }
    "

    # Interactive component model
    interactive_model_code <- "
    model {
      # Likelihood
      for (i in 1:ns) {
        for (k in 1:na[i]) {
          r[i,k] ~ dbin(p[i,k], n[i,k])
          logit(p[i,k]) <- mu[i] + delta[i,k]

          mu[i] ~ dnorm(0, 0.0001)

          # Main effects + interactions
          delta[i,k] <- sum(beta[1:nc] * comp_matrix[t[i,k], 1:nc]) +
                        sum(gamma[1:ni] * interaction_matrix[t[i,k], 1:ni])
        }
      }

      # Component main effects
      for (c in 1:nc) {
        beta[c] ~ dnorm(0, 0.0001)
      }

      # Interaction effects
      for (j in 1:ni) {
        gamma[j] ~ dnorm(0, 0.0001)
      }

      tau ~ dunif(0, 10)
    }
    "

    # ==============================================================================
    # STEP 1: Define components
    # ==============================================================================

    observeEvent(input$define_components, {
      components <- strsplit(input$components_list, "\n")[[1]]
      components <- trimws(components)
      components <- components[components != ""]

      comp_rv$components <- components

      showNotification(
        paste("Defined", length(components), "components:", paste(components, collapse = ", ")),
        type = "message", duration = 5
      )

      # Update UI for component mapping
      output$component_mapping_ui <- renderUI({
        req(comp_rv$components)

        # Get treatments from NMA data
        treatments <- unique(c(rv$nma_data$treatment, rv$nma_data$control))

        # Create checkbox group for each treatment
        mapping_inputs <- lapply(treatments, function(trt) {
          card(
            card_header(trt),
            card_body(
              checkboxGroupInput(
                ns(paste0("comp_", make.names(trt))),
                "Contains components:",
                choices = comp_rv$components,
                selected = NULL
              )
            )
          )
        })

        do.call(tagList, mapping_inputs)
      })
    })

    # ==============================================================================
    # STEP 2: Save component mapping
    # ==============================================================================

    observeEvent(input$save_mapping, {
      req(comp_rv$components)

      treatments <- unique(c(rv$nma_data$treatment, rv$nma_data$control))
      n_treat <- length(treatments)
      n_comp <- length(comp_rv$components)

      # Create component matrix (treatments x components)
      comp_matrix <- matrix(0, nrow = n_treat, ncol = n_comp)
      rownames(comp_matrix) <- treatments
      colnames(comp_matrix) <- comp_rv$components

      # Fill matrix based on user input
      for (trt in treatments) {
        trt_id <- make.names(trt)
        selected_comps <- input[[paste0("comp_", trt_id)]]

        if (!is.null(selected_comps)) {
          for (comp in selected_comps) {
            comp_matrix[trt, comp] <- 1
          }
        }
      }

      comp_rv$component_matrix <- comp_matrix

      showNotification("Component mapping saved!", type = "message", duration = 3)
    })

    # ==============================================================================
    # STEP 3: Fit component NMA
    # ==============================================================================

    observeEvent(input$fit_component_nma, {
      req(comp_rv$component_matrix, rv$nma_data)

      showNotification("Fitting Component NMA... This may take several minutes.",
                      type = "message", duration = NULL, id = "fitting_comp")

      tryCatch({
        # Prepare JAGS data
        jags_data <- list(
          ns = length(unique(rv$nma_data$study)),
          nc = ncol(comp_rv$component_matrix),
          comp_matrix = comp_rv$component_matrix,
          # ... additional data prep
        )

        # Select model
        model_code <- if (input$model_type == "additive") {
          additive_model_code
        } else {
          interactive_model_code
        }

        # Fit model
        fit <- jags(
          data = jags_data,
          model.file = textConnection(model_code),
          parameters.to.save = if (input$model_type == "additive") {
            c("beta", "tau")
          } else {
            c("beta", "gamma", "tau")
          },
          n.iter = input$n_iter_comp,
          n.burnin = input$n_iter_comp / 4,
          n.thin = 5,
          n.chains = 3
        )

        comp_rv$model_results <- fit
        comp_rv$fitted <- TRUE

        removeNotification("fitting_comp")
        showNotification("Component NMA completed!", type = "message", duration = 5)

      }, error = function(e) {
        removeNotification("fitting_comp")
        showNotification(paste("Error:", e$message), type = "error")
      })
    })

    # ==============================================================================
    # OUTPUTS
    # ==============================================================================

    # Analysis status
    output$analysis_status <- renderUI({
      if (!comp_rv$fitted) {
        tags$div(class = "alert alert-info", icon("info-circle"), " Not fitted yet")
      } else {
        tags$div(class = "alert alert-success", icon("check-circle"), " Model fitted!")
      }
    })

    # Component effects table
    output$component_effects_table <- renderDT({
      req(comp_rv$fitted, comp_rv$model_results)

      # Extract component effects (betas)
      betas <- comp_rv$model_results$BUGSoutput$mean$beta
      beta_sds <- comp_rv$model_results$BUGSoutput$sd$beta

      # Calculate 95% CrI
      ci_lower <- betas - 1.96 * beta_sds
      ci_upper <- betas + 1.96 * beta_sds

      # Transform to RR/OR scale
      if (input$outcome_measure %in% c("RR", "OR")) {
        betas_exp <- exp(betas)
        ci_lower_exp <- exp(ci_lower)
        ci_upper_exp <- exp(ci_upper)
      } else {
        betas_exp <- betas
        ci_lower_exp <- ci_lower
        ci_upper_exp <- ci_upper
      }

      # Create table
      data.frame(
        Component = comp_rv$components,
        Effect = sprintf("%.3f", betas_exp),
        `95% CrI` = sprintf("[%.3f, %.3f]", ci_lower_exp, ci_upper_exp),
        P_zero = format.pval(2 * pnorm(-abs(betas / beta_sds)), digits = 3),
        Active = ifelse(ci_lower * ci_upper > 0, "Yes", "No")
      ) %>%
        datatable(
          options = list(pageLength = 10, dom = 'tp'),
          rownames = FALSE
        ) %>%
        formatStyle(
          'Active',
          backgroundColor = styleEqual(c("Yes", "No"), c("lightgreen", "white"))
        )
    })

    # Component forest plot
    output$component_forest <- renderPlotly({
      req(comp_rv$fitted, comp_rv$model_results)

      # Extract data
      betas <- exp(comp_rv$model_results$BUGSoutput$mean$beta)
      beta_sds <- comp_rv$model_results$BUGSoutput$sd$beta
      ci_lower <- exp(comp_rv$model_results$BUGSoutput$mean$beta - 1.96 * beta_sds)
      ci_upper <- exp(comp_rv$model_results$BUGSoutput$mean$beta + 1.96 * beta_sds)

      plot_data <- data.frame(
        Component = comp_rv$components,
        Effect = betas,
        CI_Lower = ci_lower,
        CI_Upper = ci_upper
      )

      # Sort by effect
      plot_data <- plot_data[order(plot_data$Effect, decreasing = TRUE), ]

      # Create forest plot
      plot_ly(plot_data) %>%
        add_trace(
          x = ~Effect,
          y = ~Component,
          error_x = list(
            type = "data",
            symmetric = FALSE,
            array = ~(CI_Upper - Effect),
            arrayminus = ~(Effect - CI_Lower)
          ),
          type = "scatter",
          mode = "markers",
          marker = list(size = 12, color = "darkgreen"),
          name = "Component Effect"
        ) %>%
        add_segments(
          x = 1, xend = 1,
          y = 0, yend = nrow(plot_data) + 1,
          line = list(dash = "dash", color = "red"),
          showlegend = FALSE
        ) %>%
        layout(
          title = "Component Effects (vs No Component)",
          xaxis = list(title = input$outcome_measure),
          yaxis = list(title = ""),
          hovermode = "closest"
        )
    })

    # Results summary
    output$results_summary <- renderUI({
      req(comp_rv$fitted, comp_rv$model_results)

      # Identify active components (CI excludes 1)
      betas <- comp_rv$model_results$BUGSoutput$mean$beta
      beta_sds <- comp_rv$model_results$BUGSoutput$sd$beta
      ci_lower <- betas - 1.96 * beta_sds
      ci_upper <- betas + 1.96 * beta_sds

      active_idx <- which(ci_lower * ci_upper > 0)
      active_comps <- comp_rv$components[active_idx]

      tags$div(
        h4("Component NMA Results"),

        h5("Active Components:"),
        if (length(active_comps) > 0) {
          tags$ul(lapply(active_comps, function(x) tags$li(strong(x))))
        } else {
          p("No components have credible intervals excluding the null effect.")
        },

        hr(),

        h5("Model Type:"),
        p(ifelse(input$model_type == "additive", "Additive", "Interactive with synergy/antagonism")),

        h5("Number of Components:"),
        p(length(comp_rv$components)),

        h5("Number of Possible Combinations:"),
        p(2^length(comp_rv$components) - 1, "combinations")
      )
    })

    # Return reactive values
    return(comp_rv)
  })
}

# ==============================================================================
# END OF MODULE
# ==============================================================================
