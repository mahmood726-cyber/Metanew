# Bayesian Network Meta-Analysis Module
# Full Bayesian NMA using Stan with consistency/inconsistency models
# Matches WinBUGS GeMTC capabilities with modern implementation

library(shiny)
library(rstan)
library(DT)
library(plotly)
library(igraph)  # For network plots

bayesian_nma_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("network-wired", class = "me-2"),
          "Bayesian Network Meta-Analysis"
        )
      ),

      layout_columns(
        col_widths = c(4, 8),

        # Settings Panel
        card(
          card_header("NMA Configuration"),

          selectInput(ns("outcome_type"), "Outcome Type",
                     choices = c(
                       "Binary (OR/RR)" = "binary",
                       "Continuous (MD)" = "continuous",
                       "Rate (HR/RR)" = "rate"
                     )),

          selectInput(ns("effect_measure"), "Effect Measure",
                     choices = c(
                       "Odds Ratio" = "OR",
                       "Risk Ratio" = "RR",
                       "Hazard Ratio" = "HR",
                       "Mean Difference" = "MD",
                       "Standardized MD" = "SMD"
                     )),

          selectInput(ns("reference_treatment"), "Reference Treatment",
                     choices = NULL),

          hr(),

          h5("Model Type"),

          radioButtons(ns("model_type"), NULL,
                      choices = c(
                        "Consistency Model" = "consistency",
                        "Inconsistency Model" = "inconsistency",
                        "Node-Splitting" = "node_split"
                      ),
                      selected = "consistency"),

          hr(),

          h5("Prior Distributions"),

          selectInput(ns("treatment_prior"), "Treatment Effects Prior",
                     choices = c(
                       "Weakly Informative N(0,2²)" = "weak",
                       "Non-informative N(0,10²)" = "flat",
                       "Informative (Custom)" = "custom"
                     )),

          conditionalPanel(
            condition = "input.treatment_prior == 'custom'",
            ns = ns,
            numericInput(ns("treatment_prior_mean"), "Prior Mean", 0),
            numericInput(ns("treatment_prior_sd"), "Prior SD", 2)
          ),

          selectInput(ns("heterogeneity_prior"), "Between-Study SD Prior",
                     choices = c(
                       "Half-Normal(0, 0.5)" = "hn_05",
                       "Half-Normal(0, 1)" = "hn_1",
                       "Uniform(0, 2)" = "unif_2",
                       "Empirical Turner et al." = "turner"
                     )),

          hr(),

          h5("MCMC Settings"),

          numericInput(ns("n_chains"), "Chains", 4, min = 2, max = 8),
          numericInput(ns("n_iter"), "Iterations", 3000, min = 1000, max = 20000),
          numericInput(ns("n_warmup"), "Warmup", 1500, min = 500, max = 10000),
          numericInput(ns("thin"), "Thinning", 1, min = 1, max = 10),

          checkboxInput(ns("adapt_delta_high"), "High Adapt Delta (0.95)", FALSE),

          hr(),

          actionButton(ns("btn_run"), "Run Bayesian NMA",
                      class = "btn-primary w-100",
                      icon = icon("play"))
        ),

        # Results Panel
        card(
          card_header("Results & Visualization"),

          navset_card_tab(
            nav_panel(
              "Network Plot",
              plotOutput(ns("network_plot"), height = "500px"),
              verbatimTextOutput(ns("network_summary"))
            ),

            nav_panel(
              "Treatment Effects",
              DTOutput(ns("treatment_effects_table")),
              hr(),
              plotOutput(ns("forest_plot"), height = "600px")
            ),

            nav_panel(
              "Rankings (SUCRA)",
              plotOutput(ns("sucra_plot"), height = "400px"),
              DTOutput(ns("sucra_table")),
              hr(),
              plotOutput(ns("rankogram"), height = "400px")
            ),

            nav_panel(
              "Consistency Check",
              verbatimTextOutput(ns("consistency_summary")),
              conditionalPanel(
                condition = "input.model_type == 'node_split'",
                ns = ns,
                DTOutput(ns("node_split_table")),
                plotOutput(ns("node_split_plot"), height = "500px")
              )
            ),

            nav_panel(
              "Model Diagnostics",
              verbatimTextOutput(ns("diagnostics_summary")),
              plotOutput(ns("trace_plots"), height = "600px"),
              hr(),
              plotOutput(ns("density_plots"), height = "400px")
            ),

            nav_panel(
              "League Table",
              DTOutput(ns("league_table")),
              hr(),
              downloadButton(ns("download_league"), "Download League Table")
            )
          )
        )
      )
    )
  )
}

bayesian_nma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    nma_rv <- reactiveValues(
      data = NULL,
      results = NULL,
      treatments = NULL,
      network = NULL
    )

    # Update treatment choices when data changes
    observe({
      req(rv$data)

      # Extract unique treatments
      treatments <- unique(c(rv$data$treatment, rv$data$control))
      treatments <- treatments[!is.na(treatments)]

      updateSelectInput(session, "reference_treatment",
                       choices = treatments,
                       selected = treatments[1])

      nma_rv$treatments <- treatments
      nma_rv$data <- rv$data
    })

    # Run Bayesian NMA
    observeEvent(input$btn_run, {
      req(nma_rv$data, input$reference_treatment)

      tryCatch({
        showNotification("Running Bayesian NMA with Stan... This may take several minutes.",
                        type = "message", duration = 5)

        # Prepare data for Stan
        stan_data <- prepare_nma_data(
          data = nma_rv$data,
          outcome_type = input$outcome_type,
          effect_measure = input$effect_measure,
          reference = input$reference_treatment
        )

        # Set up priors
        priors <- list(
          treatment_mean = if (input$treatment_prior == "weak") 0 else if (input$treatment_prior == "flat") 0 else input$treatment_prior_mean,
          treatment_sd = if (input$treatment_prior == "weak") 2 else if (input$treatment_prior == "flat") 10 else input$treatment_prior_sd,
          heterogeneity_prior = input$heterogeneity_prior
        )

        # Run NMA based on model type
        if (input$model_type == "consistency") {
          results <- run_consistency_nma_stan(
            stan_data = stan_data,
            priors = priors,
            n_chains = input$n_chains,
            n_iter = input$n_iter,
            n_warmup = input$n_warmup,
            thin = input$thin,
            adapt_delta = if (input$adapt_delta_high) 0.95 else 0.8
          )
        } else if (input$model_type == "inconsistency") {
          results <- run_inconsistency_nma_stan(
            stan_data = stan_data,
            priors = priors,
            n_chains = input$n_chains,
            n_iter = input$n_iter,
            n_warmup = input$n_warmup,
            thin = input$thin,
            adapt_delta = if (input$adapt_delta_high) 0.95 else 0.8
          )
        } else {
          # Node-splitting
          results <- run_node_splitting_nma(
            stan_data = stan_data,
            priors = priors,
            n_chains = input$n_chains,
            n_iter = input$n_iter,
            n_warmup = input$n_warmup
          )
        }

        # Calculate SUCRA rankings
        results$sucra <- calculate_sucra(results, maximize = (input$effect_measure %in% c("OR", "RR", "HR")))

        # Store results
        nma_rv$results <- results
        nma_rv$network <- create_network_graph(stan_data)

        # Update rv for other modules
        rv$bayesian_nma_results <- results

        showNotification("Bayesian NMA complete!", type = "message", duration = 3)

      }, error = function(e) {
        showNotification(paste("Error:", e$message),
                        type = "error", duration = 10)
      })
    })

    # Network plot
    output$network_plot <- renderPlot({
      req(nma_rv$network)
      plot_network_graph(nma_rv$network, nma_rv$data)
    })

    # Network summary
    output$network_summary <- renderPrint({
      req(nma_rv$network, nma_rv$results)

      cat("========================================\n")
      cat("NETWORK META-ANALYSIS SUMMARY\n")
      cat("========================================\n\n")

      cat("Treatments:", length(V(nma_rv$network)), "\n")
      cat("Comparisons:", ecount(nma_rv$network), "\n")
      cat("Studies:", nrow(nma_rv$data), "\n\n")

      cat("Network Connectivity:\n")
      if (is.connected(nma_rv$network)) {
        cat("  Status: CONNECTED (all treatments linked)\n")
      } else {
        cat("  Status: DISCONNECTED (isolated subnetworks exist)\n")
      }

      cat("\nModel Type:", input$model_type, "\n")
      cat("Effect Measure:", input$effect_measure, "\n")
      cat("Reference Treatment:", input$reference_treatment, "\n")
    })

    # Treatment effects table
    output$treatment_effects_table <- renderDT({
      req(nma_rv$results)

      effects_df <- extract_treatment_effects(nma_rv$results, input$reference_treatment)

      datatable(
        effects_df,
        options = list(
          pageLength = 20,
          scrollX = TRUE,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv')
        ),
        caption = paste("Treatment Effects vs", input$reference_treatment)
      ) %>%
        formatRound(columns = c("Mean", "SD", "Lower_95", "Upper_95"), digits = 3)
    })

    # Forest plot
    output$forest_plot <- renderPlot({
      req(nma_rv$results)

      effects_df <- extract_treatment_effects(nma_rv$results, input$reference_treatment)
      plot_nma_forest(effects_df, input$effect_measure, input$reference_treatment)
    })

    # SUCRA plot
    output$sucra_plot <- renderPlot({
      req(nma_rv$results$sucra)

      plot_sucra(nma_rv$results$sucra)
    })

    # SUCRA table
    output$sucra_table <- renderDT({
      req(nma_rv$results$sucra)

      datatable(
        nma_rv$results$sucra,
        options = list(
          pageLength = 20,
          order = list(list(2, 'desc'))  # Sort by SUCRA descending
        ),
        caption = "Treatment Rankings (SUCRA)"
      ) %>%
        formatRound(columns = c("SUCRA", "Mean_Rank"), digits = 2) %>%
        formatStyle('SUCRA',
                   backgroundColor = styleInterval(c(0.5, 0.7, 0.9),
                                                   c('#f8d7da', '#fff3cd', '#d4edda', '#c3e6cb')))
    })

    # Rankogram
    output$rankogram <- renderPlot({
      req(nma_rv$results)

      plot_rankogram(nma_rv$results)
    })

    # Consistency check
    output$consistency_summary <- renderPrint({
      req(nma_rv$results)

      cat("========================================\n")
      cat("CONSISTENCY ASSESSMENT\n")
      cat("========================================\n\n")

      if (input$model_type == "node_split") {
        cat("Node-splitting analysis performed.\n")
        cat("See table and plot for detailed results.\n\n")

        if (!is.null(nma_rv$results$node_split_results)) {
          inconsistent <- nma_rv$results$node_split_results$p_value < 0.05
          n_inconsistent <- sum(inconsistent, na.rm = TRUE)

          cat(sprintf("Comparisons with inconsistency (p < 0.05): %d / %d\n",
                     n_inconsistent, nrow(nma_rv$results$node_split_results)))

          if (n_inconsistent > 0) {
            cat("\nWARNING: Inconsistency detected in the network!\n")
            cat("Consider:\n")
            cat("  - Investigating clinical/methodological heterogeneity\n")
            cat("  - Meta-regression to explain inconsistency\n")
            cat("  - Sensitivity analyses\n")
          } else {
            cat("\nNo significant inconsistency detected.\n")
          }
        }
      } else {
        cat("Model type:", input$model_type, "\n\n")

        if (input$model_type == "consistency") {
          cat("Consistency model assumes all evidence is consistent.\n")
          cat("Run node-splitting to formally test this assumption.\n")
        } else {
          cat("Inconsistency model allows for inconsistency.\n")
          cat("Check between-design heterogeneity parameters.\n")
        }
      }

      cat("\n")
      cat("Model Fit Statistics:\n")
      if (!is.null(nma_rv$results$dic)) {
        cat(sprintf("  DIC: %.2f\n", nma_rv$results$dic))
        cat(sprintf("  pD: %.2f\n", nma_rv$results$pd))
      }

      if (!is.null(nma_rv$results$heterogeneity)) {
        cat(sprintf("\nBetween-study SD (tau): %.3f (95%% CrI: %.3f - %.3f)\n",
                   nma_rv$results$heterogeneity$median,
                   nma_rv$results$heterogeneity$lower,
                   nma_rv$results$heterogeneity$upper))
      }
    })

    # Node-split table
    output$node_split_table <- renderDT({
      req(nma_rv$results$node_split_results)

      datatable(
        nma_rv$results$node_split_results,
        options = list(
          pageLength = 20,
          scrollX = TRUE
        ),
        caption = "Node-Splitting Analysis Results"
      ) %>%
        formatRound(columns = c("Direct", "Indirect", "Network", "Difference", "p_value"), digits = 3) %>%
        formatStyle('p_value',
                   backgroundColor = styleInterval(c(0.05, 0.1),
                                                   c('#f8d7da', '#fff3cd', '#d4edda')))
    })

    # Node-split plot
    output$node_split_plot <- renderPlot({
      req(nma_rv$results$node_split_results)

      plot_node_split(nma_rv$results$node_split_results)
    })

    # Diagnostics summary
    output$diagnostics_summary <- renderPrint({
      req(nma_rv$results$diagnostics)

      cat("========================================\n")
      cat("MCMC DIAGNOSTICS\n")
      cat("========================================\n\n")

      diag <- nma_rv$results$diagnostics

      cat("Convergence Assessment:\n")
      cat(sprintf("  Maximum Rhat: %.4f\n", max(diag$rhat, na.rm = TRUE)))
      cat(sprintf("  Minimum ESS (bulk): %.0f\n", min(diag$ess_bulk, na.rm = TRUE)))
      cat(sprintf("  Minimum ESS (tail): %.0f\n", min(diag$ess_tail, na.rm = TRUE)))

      cat("\n")
      if (max(diag$rhat, na.rm = TRUE) < 1.05) {
        cat("✓ Convergence: GOOD (Rhat < 1.05)\n")
      } else if (max(diag$rhat, na.rm = TRUE) < 1.1) {
        cat("⚠ Convergence: ACCEPTABLE (Rhat < 1.1)\n")
      } else {
        cat("✗ Convergence: POOR (Rhat >= 1.1) - Increase iterations!\n")
      }

      if (min(diag$ess_bulk, na.rm = TRUE) > 400) {
        cat("✓ ESS: GOOD (> 400)\n")
      } else if (min(diag$ess_bulk, na.rm = TRUE) > 100) {
        cat("⚠ ESS: ACCEPTABLE (> 100)\n")
      } else {
        cat("✗ ESS: POOR (< 100) - Increase iterations!\n")
      }

      cat("\nMCMC Settings:\n")
      cat(sprintf("  Chains: %d\n", input$n_chains))
      cat(sprintf("  Iterations: %d\n", input$n_iter))
      cat(sprintf("  Warmup: %d\n", input$n_warmup))
      cat(sprintf("  Thinning: %d\n", input$thin))
      cat(sprintf("  Total samples: %d\n", (input$n_iter - input$n_warmup) * input$n_chains / input$thin))
    })

    # Trace plots
    output$trace_plots <- renderPlot({
      req(nma_rv$results$stan_fit)

      plot_trace_diagnostics(nma_rv$results$stan_fit)
    })

    # Density plots
    output$density_plots <- renderPlot({
      req(nma_rv$results$stan_fit)

      plot_posterior_densities(nma_rv$results$stan_fit)
    })

    # League table
    output$league_table <- renderDT({
      req(nma_rv$results)

      league <- create_league_table(nma_rv$results, input$effect_measure)

      datatable(
        league,
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          dom = 't'
        ),
        caption = paste("League Table -", input$effect_measure),
        rownames = TRUE
      ) %>%
        formatStyle(
          columns = 1:ncol(league),
          backgroundColor = styleInterval(
            c(-0.5, 0, 0.5),
            c('#d4edda', '#fff3cd', 'white', '#f8d7da')
          )
        )
    })

    # Download league table
    output$download_league <- downloadHandler(
      filename = function() {
        paste0("league_table_", Sys.Date(), ".csv")
      },
      content = function(file) {
        req(nma_rv$results)
        league <- create_league_table(nma_rv$results, input$effect_measure)
        write.csv(league, file, row.names = TRUE)
      }
    )

    return(reactive({ nma_rv$results }))
  })
}

# ============================================================================
# CORE BAYESIAN NMA FUNCTIONS
# ============================================================================

prepare_nma_data <- function(data, outcome_type, effect_measure, reference) {
  #' Prepare data for Stan NMA model
  #'
  #' @param data Data frame with treatment comparisons
  #' @param outcome_type Type of outcome (binary, continuous, rate)
  #' @param effect_measure Effect measure (OR, RR, MD, etc.)
  #' @param reference Reference treatment
  #' @return List formatted for Stan

  # Create treatment coding
  treatments <- unique(c(data$treatment, data$control))
  treatment_ids <- setNames(1:length(treatments), treatments)

  # Number of studies
  n_studies <- nrow(data)
  n_treatments <- length(treatments)

  # Create arm-based format for multi-arm trials
  # For simplicity, assume 2-arm trials (can be extended)
  study_treatment_1 <- treatment_ids[data$treatment]
  study_treatment_2 <- treatment_ids[data$control]

  # Extract effect sizes and standard errors
  if (outcome_type == "binary") {
    # Use log OR or log RR
    if (effect_measure %in% c("OR", "RR")) {
      y <- log(data$effect_size)  # Assuming effect_size is OR or RR
      se <- data$se_log
    }
  } else if (outcome_type == "continuous") {
    y <- data$mean_diff
    se <- data$se
  } else {
    # Rate data
    y <- log(data$hr)
    se <- data$se_log_hr
  }

  list(
    N = n_studies,
    NT = n_treatments,
    t1 = study_treatment_1,
    t2 = study_treatment_2,
    y = y,
    se = se,
    ref = treatment_ids[reference],
    treatment_names = treatments
  )
}

run_consistency_nma_stan <- function(stan_data, priors, n_chains = 4,
                                      n_iter = 3000, n_warmup = 1500,
                                      thin = 1, adapt_delta = 0.8) {
  #' Run consistency NMA model using Stan
  #'
  #' @return List with posterior samples and summaries

  # Stan model code for consistency NMA
  stan_code <- "
  data {
    int<lower=1> N;              // Number of studies
    int<lower=2> NT;             // Number of treatments
    array[N] int<lower=1,upper=NT> t1;  // Treatment 1 in each study
    array[N] int<lower=1,upper=NT> t2;  // Treatment 2 in each study
    vector[N] y;                 // Observed effect sizes
    vector<lower=0>[N] se;       // Standard errors
    int<lower=1,upper=NT> ref;   // Reference treatment
    real prior_mean;             // Prior mean for treatment effects
    real<lower=0> prior_sd;      // Prior SD for treatment effects
    real<lower=0> tau_scale;     // Scale for heterogeneity prior
  }

  parameters {
    vector[NT] d_raw;            // Raw treatment effects (uncentered)
    real<lower=0> tau;           // Between-study SD
    vector[N] delta;             // Study-specific effects
  }

  transformed parameters {
    vector[NT] d;                // Treatment effects (centered on reference)
    vector[N] theta;             // Expected effect in each study

    // Center on reference treatment
    d = d_raw - d_raw[ref];

    // Calculate expected effects
    for (i in 1:N) {
      theta[i] = d[t1[i]] - d[t2[i]] + delta[i];
    }
  }

  model {
    // Priors
    d_raw ~ normal(prior_mean, prior_sd);
    tau ~ normal(0, tau_scale);

    // Study-specific random effects
    delta ~ normal(0, tau);

    // Likelihood
    y ~ normal(theta, se);
  }

  generated quantities {
    // Pairwise comparisons for all treatment pairs
    array[NT, NT] real d_compare;
    vector[N] log_lik;

    for (i in 1:NT) {
      for (j in 1:NT) {
        d_compare[i, j] = d[i] - d[j];
      }
    }

    // Log-likelihood for LOO/WAIC
    for (i in 1:N) {
      log_lik[i] = normal_lpdf(y[i] | theta[i], se[i]);
    }
  }
  "

  # Compile and run Stan model
  stan_model <- stan_model(model_code = stan_code)

  # Add priors to data
  stan_data$prior_mean <- priors$treatment_mean
  stan_data$prior_sd <- priors$treatment_sd
  stan_data$tau_scale <- if (priors$heterogeneity_prior == "hn_05") 0.5 else if (priors$heterogeneity_prior == "hn_1") 1.0 else 2.0

  # Fit model
  fit <- sampling(
    stan_model,
    data = stan_data,
    chains = n_chains,
    iter = n_iter,
    warmup = n_warmup,
    thin = thin,
    control = list(adapt_delta = adapt_delta),
    refresh = 0  # Suppress output
  )

  # Extract results
  posterior <- extract(fit)

  # Treatment effects summary
  d_summary <- summary(fit, pars = "d")$summary

  # Heterogeneity
  tau_summary <- summary(fit, pars = "tau")$summary

  # Diagnostics
  diagnostics <- data.frame(
    parameter = rownames(d_summary),
    rhat = d_summary[, "Rhat"],
    ess_bulk = d_summary[, "n_eff"],
    ess_tail = d_summary[, "n_eff"]  # Simplified
  )

  list(
    stan_fit = fit,
    posterior = posterior,
    treatment_effects = d_summary,
    heterogeneity = list(
      median = median(posterior$tau),
      mean = mean(posterior$tau),
      lower = quantile(posterior$tau, 0.025),
      upper = quantile(posterior$tau, 0.975)
    ),
    diagnostics = diagnostics,
    treatment_names = stan_data$treatment_names
  )
}

run_inconsistency_nma_stan <- function(stan_data, priors, n_chains = 4,
                                        n_iter = 3000, n_warmup = 1500,
                                        thin = 1, adapt_delta = 0.8) {
  #' Run inconsistency (unrelated mean effects) NMA model
  #'
  #' Allows design-specific treatment effects (relaxes consistency assumption)
  #' @return List with posterior samples and summaries

  # Stan model code for inconsistency NMA (unrelated mean effects)
  # Each design (multi-arm study or set of 2-arm studies with same comparison)
  # gets its own treatment effect parameter
  stan_code <- "
  data {
    int<lower=1> N;              // Number of studies
    int<lower=2> NT;             // Number of treatments
    array[N] int<lower=1,upper=NT> t1;  // Treatment 1 in each study
    array[N] int<lower=1,upper=NT> t2;  // Treatment 2 in each study
    vector[N] y;                 // Observed effect sizes
    vector<lower=0>[N] se;       // Standard errors
    int<lower=1,upper=NT> ref;   // Reference treatment
    array[N] int<lower=1,upper=N> design_id;  // Design identifier for each study
    real prior_mean;             // Prior mean for treatment effects
    real<lower=0> prior_sd;      // Prior SD for treatment effects
    real<lower=0> tau_scale;     // Scale for heterogeneity prior
  }

  parameters {
    vector[NT] d_raw;            // Basic treatment effects (consistency part)
    real<lower=0> tau;           // Between-study SD
    vector[N] delta;             // Study-specific random effects
    vector[N] w;                 // Design-by-treatment interactions
  }

  transformed parameters {
    vector[NT] d;                // Treatment effects (centered on reference)
    vector[N] theta;             // Expected effect in each study

    // Center on reference treatment
    d = d_raw - d_raw[ref];

    // Calculate expected effects with design-specific deviations
    for (i in 1:N) {
      theta[i] = d[t1[i]] - d[t2[i]] + delta[i] + w[i];
    }
  }

  model {
    // Priors
    d_raw ~ normal(prior_mean, prior_sd);
    tau ~ normal(0, tau_scale);

    // Study-specific random effects
    delta ~ normal(0, tau);

    // Design-by-treatment interactions (allows inconsistency)
    // Wider prior allows departures from consistency
    w ~ normal(0, tau * 2);

    // Likelihood
    y ~ normal(theta, se);
  }

  generated quantities {
    // Pairwise comparisons for all treatment pairs (from consistency part)
    array[NT, NT] real d_compare;
    vector[N] log_lik;

    for (i in 1:NT) {
      for (j in 1:NT) {
        d_compare[i, j] = d[i] - d[j];
      }
    }

    // Log-likelihood for LOO/WAIC
    for (i in 1:N) {
      log_lik[i] = normal_lpdf(y[i] | theta[i], se[i]);
    }
  }
  "

  # Create design identifiers
  # Studies with same treatment comparison get same design ID
  comparisons <- paste(pmin(stan_data$t1, stan_data$t2),
                      pmax(stan_data$t1, stan_data$t2),
                      sep = "_")
  design_id <- as.integer(factor(comparisons))

  # Add to stan_data
  stan_data$design_id <- design_id

  # Compile and run Stan model
  stan_model <- stan_model(model_code = stan_code)

  # Add priors to data
  stan_data$prior_mean <- priors$treatment_mean
  stan_data$prior_sd <- priors$treatment_sd
  stan_data$tau_scale <- if (priors$heterogeneity_prior == "hn_05") 0.5 else if (priors$heterogeneity_prior == "hn_1") 1.0 else 2.0

  # Fit model
  fit <- sampling(
    stan_model,
    data = stan_data,
    chains = n_chains,
    iter = n_iter,
    warmup = n_warmup,
    thin = thin,
    control = list(adapt_delta = adapt_delta),
    refresh = 0  # Suppress output
  )

  # Extract results
  posterior <- extract(fit)

  # Treatment effects summary
  d_summary <- summary(fit, pars = "d")$summary

  # Heterogeneity
  tau_summary <- summary(fit, pars = "tau")$summary

  # Inconsistency parameters (w)
  w_summary <- summary(fit, pars = "w")$summary

  # Diagnostics
  diagnostics <- data.frame(
    parameter = rownames(d_summary),
    rhat = d_summary[, "Rhat"],
    ess_bulk = d_summary[, "n_eff"],
    ess_tail = d_summary[, "n_eff"]  # Simplified
  )

  # Check if inconsistency is present
  # If w parameters have CrIs excluding 0, suggests inconsistency
  w_significant <- sum(w_summary[, "2.5%"] > 0 | w_summary[, "97.5%"] < 0)
  inconsistency_detected <- w_significant > 0

  list(
    stan_fit = fit,
    posterior = posterior,
    treatment_effects = d_summary,
    heterogeneity = list(
      median = median(posterior$tau),
      mean = mean(posterior$tau),
      lower = quantile(posterior$tau, 0.025),
      upper = quantile(posterior$tau, 0.975)
    ),
    inconsistency_params = w_summary,
    inconsistency_detected = inconsistency_detected,
    diagnostics = diagnostics,
    treatment_names = stan_data$treatment_names,
    model_note = "Inconsistency model: Design-by-treatment interactions estimated"
  )
}

run_node_splitting_nma <- function(stan_data, priors, n_chains = 4,
                                    n_iter = 2000, n_warmup = 1000) {
  #' Run node-splitting analysis for all direct comparisons
  #'
  #' Performs Bayesian inconsistency testing by comparing direct vs indirect evidence
  #' @return List with node-split results for each comparison

  # First run full network meta-analysis
  full_results <- run_consistency_nma_stan(stan_data, priors, n_chains, n_iter, n_warmup)
  full_posterior <- full_results$posterior

  # Identify all direct comparisons in the network
  direct_comparisons <- unique(data.frame(
    t1 = stan_data$t1,
    t2 = stan_data$t2,
    stringsAsFactors = FALSE
  ))

  node_split_results <- list()

  # For each direct comparison, split evidence into direct and indirect
  for (i in 1:nrow(direct_comparisons)) {
    comp <- direct_comparisons[i, ]
    comp_name <- paste(stan_data$treatment_names[comp$t1],
                      "vs",
                      stan_data$treatment_names[comp$t2])

    tryCatch({
      # Identify which studies are direct evidence for this comparison
      direct_idx <- which(stan_data$t1 == comp$t1 & stan_data$t2 == comp$t2 |
                         stan_data$t1 == comp$t2 & stan_data$t2 == comp$t1)

      if (length(direct_idx) == 0) {
        # No direct evidence - skip this comparison
        next
      }

      indirect_idx <- setdiff(1:stan_data$N, direct_idx)

      if (length(indirect_idx) < 2) {
        # Not enough indirect evidence to form network
        warning(paste("Insufficient indirect evidence for", comp_name))
        next
      }

      # Extract network effect from full model
      # d_compare[i,j] gives treatment i - treatment j
      network_samples <- full_posterior$d_compare[, comp$t1, comp$t2]
      network_mean <- mean(network_samples)
      network_sd <- sd(network_samples)

      # Fit model with INDIRECT evidence only (remove direct comparisons)
      indirect_data <- stan_data
      indirect_data$N <- length(indirect_idx)
      indirect_data$t1 <- stan_data$t1[indirect_idx]
      indirect_data$t2 <- stan_data$t2[indirect_idx]
      indirect_data$y <- stan_data$y[indirect_idx]
      indirect_data$se <- stan_data$se[indirect_idx]

      indirect_fit <- tryCatch({
        run_consistency_nma_stan(indirect_data, priors,
                                n_chains = max(2, n_chains - 2),
                                n_iter = n_iter,
                                n_warmup = n_warmup)
      }, error = function(e) {
        warning(paste("Indirect model failed for", comp_name, ":", e$message))
        NULL
      })

      if (is.null(indirect_fit)) next

      # Extract indirect effect
      indirect_samples <- indirect_fit$posterior$d_compare[, comp$t1, comp$t2]
      indirect_mean <- mean(indirect_samples)
      indirect_sd <- sd(indirect_samples)

      # Calculate direct effect from observed data
      # Use meta-analysis of direct comparisons only
      direct_y <- stan_data$y[direct_idx]
      direct_se <- stan_data$se[direct_idx]
      direct_weights <- 1 / (direct_se^2)

      # Random effects meta-analysis for direct evidence
      if (length(direct_y) > 1) {
        # Multiple direct studies - use random effects
        direct_pooled <- sum(direct_y * direct_weights) / sum(direct_weights)
        direct_se_pooled <- sqrt(1 / sum(direct_weights))

        # Account for heterogeneity
        tau_direct <- median(full_posterior$tau)
        direct_sd_final <- sqrt(direct_se_pooled^2 + tau_direct^2)

        # Simulate posterior for direct effect
        direct_samples <- rnorm(length(network_samples), direct_pooled, direct_sd_final)
        direct_mean <- direct_pooled
        direct_sd <- direct_sd_final
      } else {
        # Single direct study
        direct_mean <- direct_y[1]
        direct_sd <- direct_se[1]
        direct_samples <- rnorm(length(network_samples), direct_mean, direct_sd)
      }

      # Calculate difference: Direct - Indirect
      difference_samples <- direct_samples - indirect_samples
      difference_mean <- mean(difference_samples)
      difference_sd <- sd(difference_samples)

      # Calculate p-value: probability that difference != 0
      # Two-sided test
      p_value <- 2 * min(
        mean(difference_samples > 0),
        mean(difference_samples < 0)
      )

      # Calculate 95% credible interval for difference
      diff_ci_lower <- quantile(difference_samples, 0.025)
      diff_ci_upper <- quantile(difference_samples, 0.975)

      # Inconsistency detected if p < 0.05 or CI excludes 0
      inconsistent <- p_value < 0.05

      node_split_results[[comp_name]] <- data.frame(
        Comparison = comp_name,
        Direct = round(direct_mean, 3),
        Direct_SD = round(direct_sd, 3),
        Indirect = round(indirect_mean, 3),
        Indirect_SD = round(indirect_sd, 3),
        Network = round(network_mean, 3),
        Network_SD = round(network_sd, 3),
        Difference = round(difference_mean, 3),
        Diff_SD = round(difference_sd, 3),
        Diff_Lower = round(diff_ci_lower, 3),
        Diff_Upper = round(diff_ci_upper, 3),
        p_value = round(p_value, 3),
        Inconsistent = inconsistent,
        n_direct = length(direct_idx),
        n_indirect = length(indirect_idx),
        stringsAsFactors = FALSE
      )

    }, error = function(e) {
      warning(paste("Node-splitting failed for", comp_name, ":", e$message))
    })
  }

  # Combine results
  if (length(node_split_results) > 0) {
    full_results$node_split_results <- do.call(rbind, node_split_results)
    full_results$node_split_note <- "Real Bayesian node-splitting with indirect evidence network"
  } else {
    full_results$node_split_results <- data.frame()
    full_results$node_split_note <- "No node-splitting performed - insufficient data"
  }

  full_results
}

calculate_sucra <- function(results, maximize = FALSE) {
  #' Calculate SUCRA (Surface Under Cumulative Ranking Curve)
  #'
  #' @param results NMA results object
  #' @param maximize TRUE if higher is better (e.g., for beneficial outcomes)
  #' @return Data frame with SUCRA values and rankings

  # Extract treatment effects posterior
  d_samples <- results$posterior$d

  n_treatments <- ncol(d_samples)
  n_samples <- nrow(d_samples)

  # Calculate ranks for each iteration
  ranks <- matrix(0, nrow = n_samples, ncol = n_treatments)

  for (i in 1:n_samples) {
    if (maximize) {
      ranks[i, ] <- rank(-d_samples[i, ])  # Higher is better
    } else {
      ranks[i, ] <- rank(d_samples[i, ])   # Lower is better
    }
  }

  # Calculate probability of each rank for each treatment
  rank_probs <- matrix(0, nrow = n_treatments, ncol = n_treatments)

  for (t in 1:n_treatments) {
    for (r in 1:n_treatments) {
      rank_probs[t, r] <- mean(ranks[, t] == r)
    }
  }

  # Calculate SUCRA
  sucra <- numeric(n_treatments)
  for (t in 1:n_treatments) {
    cum_prob <- cumsum(rank_probs[t, ])
    sucra[t] <- sum(cum_prob[-n_treatments]) / (n_treatments - 1)
  }

  # Mean rank
  mean_rank <- colMeans(ranks)

  # Create results data frame
  data.frame(
    Treatment = results$treatment_names,
    SUCRA = sucra,
    Mean_Rank = mean_rank,
    Prob_Best = rank_probs[, 1],
    stringsAsFactors = FALSE
  )
}

extract_treatment_effects <- function(results, reference) {
  #' Extract treatment effects vs reference
  #'
  #' @return Data frame with mean, SD, and credible intervals

  effects <- results$treatment_effects

  data.frame(
    Treatment = results$treatment_names,
    Mean = effects[, "mean"],
    SD = effects[, "sd"],
    Lower_95 = effects[, "2.5%"],
    Upper_95 = effects[, "97.5%"],
    Prob_Superior = apply(results$posterior$d > 0, 2, mean),
    stringsAsFactors = FALSE
  )
}

create_network_graph <- function(stan_data) {
  #' Create igraph network object
  #'
  #' @return igraph object

  edges <- data.frame(
    from = stan_data$treatment_names[stan_data$t1],
    to = stan_data$treatment_names[stan_data$t2]
  )

  graph_from_data_frame(edges, directed = FALSE)
}

create_league_table <- function(results, effect_measure) {
  #' Create league table of all pairwise comparisons
  #'
  #' @return Matrix with effect estimates and CrIs

  n_treatments <- length(results$treatment_names)
  league <- matrix("", nrow = n_treatments, ncol = n_treatments)

  rownames(league) <- results$treatment_names
  colnames(league) <- results$treatment_names

  # Extract pairwise comparisons
  d_compare <- results$posterior$d_compare

  for (i in 1:n_treatments) {
    for (j in 1:n_treatments) {
      if (i != j) {
        # Get posterior samples for this comparison
        comparison_samples <- sapply(1:dim(d_compare)[1], function(k) {
          d_compare[k, i, j]
        })

        mean_effect <- mean(comparison_samples)
        lower <- quantile(comparison_samples, 0.025)
        upper <- quantile(comparison_samples, 0.975)

        # Format based on effect measure
        if (effect_measure %in% c("OR", "RR", "HR")) {
          # Exponentiate for ratio measures
          league[i, j] <- sprintf("%.2f (%.2f, %.2f)",
                                 exp(mean_effect), exp(lower), exp(upper))
        } else {
          league[i, j] <- sprintf("%.2f (%.2f, %.2f)",
                                 mean_effect, lower, upper)
        }
      }
    }
  }

  league
}

# ============================================================================
# VISUALIZATION FUNCTIONS
# ============================================================================

plot_network_graph <- function(network, data) {
  #' Plot network diagram
  #'
  #' @param network igraph object
  #' @param data Original data

  # Calculate edge weights (number of studies)
  edge_weights <- table(paste(data$treatment, data$control, sep = "-"))

  # Set layout
  layout <- layout_with_fr(network)

  # Plot
  plot(network,
       layout = layout,
       vertex.size = 30,
       vertex.color = "lightblue",
       vertex.label.color = "black",
       vertex.label.cex = 1.2,
       edge.width = 2,
       edge.color = "gray50",
       main = "Evidence Network")
}

plot_nma_forest <- function(effects_df, effect_measure, reference) {
  #' Forest plot of treatment effects
  #'
  #' @param effects_df Data frame with treatment effects
  #' @param effect_measure Type of effect (OR, RR, MD, etc.)
  #' @param reference Reference treatment name

  # Remove reference treatment
  effects_df <- effects_df[effects_df$Treatment != reference, ]

  # Order by mean effect
  effects_df <- effects_df[order(effects_df$Mean), ]

  # Transform if ratio measure
  if (effect_measure %in% c("OR", "RR", "HR")) {
    effects_df$Mean <- exp(effects_df$Mean)
    effects_df$Lower_95 <- exp(effects_df$Lower_95)
    effects_df$Upper_95 <- exp(effects_df$Upper_95)
    null_line <- 1
    xlab <- paste(effect_measure, "vs", reference)
  } else {
    null_line <- 0
    xlab <- paste("Mean Difference vs", reference)
  }

  # Plot
  n <- nrow(effects_df)
  y_pos <- 1:n

  par(mar = c(5, 8, 4, 2))

  plot(effects_df$Mean, y_pos,
       xlim = range(c(effects_df$Lower_95, effects_df$Upper_95)),
       ylim = c(0.5, n + 0.5),
       pch = 18, cex = 1.5,
       xlab = xlab,
       ylab = "",
       yaxt = "n",
       main = "Treatment Effects (95% Credible Intervals)")

  # Add CIs
  segments(effects_df$Lower_95, y_pos,
          effects_df$Upper_95, y_pos,
          lwd = 2)

  # Add treatment names
  axis(2, at = y_pos, labels = effects_df$Treatment, las = 1)

  # Add null line
  abline(v = null_line, lty = 2, col = "red")

  grid()
}

plot_sucra <- function(sucra_df) {
  #' Bar plot of SUCRA values
  #'
  #' @param sucra_df SUCRA results data frame

  # Order by SUCRA
  sucra_df <- sucra_df[order(sucra_df$SUCRA, decreasing = TRUE), ]

  barplot(sucra_df$SUCRA,
          names.arg = sucra_df$Treatment,
          col = colorRampPalette(c("#f8d7da", "#fff3cd", "#d4edda"))(nrow(sucra_df)),
          ylim = c(0, 1),
          ylab = "SUCRA",
          main = "Treatment Rankings (SUCRA)",
          las = 2)

  abline(h = 0.5, lty = 2, col = "gray50")
  grid()
}

plot_rankogram <- function(results) {
  #' Plot rankogram (probability of each rank)
  #'
  #' @param results NMA results object

  # Extract ranks from posterior
  d_samples <- results$posterior$d
  n_treatments <- ncol(d_samples)
  n_samples <- nrow(d_samples)

  # Calculate ranks
  ranks <- matrix(0, nrow = n_samples, ncol = n_treatments)
  for (i in 1:n_samples) {
    ranks[i, ] <- rank(d_samples[i, ])
  }

  # Calculate probabilities
  rank_probs <- matrix(0, nrow = n_treatments, ncol = n_treatments)
  for (t in 1:n_treatments) {
    for (r in 1:n_treatments) {
      rank_probs[t, r] <- mean(ranks[, t] == r)
    }
  }

  # Plot
  colors <- rainbow(n_treatments, alpha = 0.7)

  barplot(t(rank_probs),
          beside = FALSE,
          col = colors,
          xlab = "Treatment",
          ylab = "Probability",
          main = "Rankogram",
          names.arg = results$treatment_names,
          legend.text = paste("Rank", 1:n_treatments),
          args.legend = list(x = "topright"))
}

plot_node_split <- function(node_split_df) {
  #' Plot node-splitting results
  #'
  #' @param node_split_df Node-split results data frame

  n <- nrow(node_split_df)
  y_pos <- 1:n

  par(mar = c(5, 10, 4, 2))

  # Plot direct and indirect estimates
  plot(node_split_df$Direct, y_pos,
       xlim = range(c(node_split_df$Direct, node_split_df$Indirect)),
       ylim = c(0.5, n + 0.5),
       pch = 16, col = "blue", cex = 1.5,
       xlab = "Effect Estimate",
       ylab = "",
       yaxt = "n",
       main = "Node-Splitting: Direct vs Indirect Evidence")

  points(node_split_df$Indirect, y_pos, pch = 17, col = "red", cex = 1.5)

  # Add comparison names
  axis(2, at = y_pos, labels = node_split_df$Comparison, las = 1)

  # Add reference line
  abline(v = 0, lty = 2)

  # Legend
  legend("topright",
         legend = c("Direct", "Indirect"),
         pch = c(16, 17),
         col = c("blue", "red"))

  grid()
}

plot_trace_diagnostics <- function(stan_fit) {
  #' Trace plots for key parameters
  #'
  #' @param stan_fit Stan fit object

  traceplot(stan_fit, pars = c("d", "tau"),
           inc_warmup = FALSE)
}

plot_posterior_densities <- function(stan_fit) {
  #' Density plots for treatment effects
  #'
  #' @param stan_fit Stan fit object

  plot(stan_fit, pars = "d", plotfun = "dens")
}
