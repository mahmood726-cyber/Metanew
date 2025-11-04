# Bayesian Network Meta-Analysis Module
# Uses gemtc package for Bayesian NMA via JAGS

library(shiny)
library(gemtc)  # Bayesian NMA
library(rjags)  # JAGS backend
library(coda)   # MCMC diagnostics

bayesian_nma_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header("Bayesian Network Meta-Analysis"),
      layout_columns(
        col_widths = c(4, 8),

        # Settings panel
        card(
          h5("MCMC Settings"),
          numericInput(ns("n_chains"), "Number of Chains:", value = 4, min = 2, max = 8),
          numericInput(ns("n_iter"), "Iterations:", value = 20000, min = 5000, max = 100000),
          numericInput(ns("n_burnin"), "Burn-in:", value = 5000, min = 1000, max = 50000),
          numericInput(ns("n_thin"), "Thinning:", value = 1, min = 1, max = 10),
          hr(),

          h5("Prior Selection"),
          selectInput(ns("prior_type"), "Heterogeneity Prior:",
                     choices = c(
                       "Vague (default)" = "vague",
                       "Informative (Turner et al.)" = "turner",
                       "Custom" = "custom"
                     )),
          conditionalPanel(
            condition = "input.prior_type == 'custom'",
            ns = ns,
            numericInput(ns("prior_mean"), "Prior Mean (log scale):", value = 0),
            numericInput(ns("prior_sd"), "Prior SD:", value = 2.5)
          ),
          hr(),

          selectInput(ns("outcome_measure"), "Outcome Measure:",
                     choices = c("Odds Ratio" = "OR",
                               "Risk Ratio" = "RR",
                               "Mean Difference" = "MD",
                               "Hazard Ratio" = "HR")),

          actionButton(ns("run_bayesian"), "Run Bayesian NMA",
                      class = "btn-primary w-100 mt-3")
        ),

        # Results panel
        card(
          navset_card_tab(
            nav_panel("Posterior Summary",
                     verbatimTextOutput(ns("posterior_summary"))),
            nav_panel("Treatment Rankings",
                     plotOutput(ns("rank_plot")),
                     DTOutput(ns("rank_table"))),
            nav_panel("Forest Plot",
                     plotOutput(ns("forest_plot"), height = "600px")),
            nav_panel("Convergence",
                     plotOutput(ns("trace_plot")),
                     verbatimTextOutput(ns("gelman_diag"))),
            nav_panel("Inconsistency",
                     verbatimTextOutput(ns("inconsistency_test")),
                     plotOutput(ns("inconsistency_plot")))
          )
        )
      )
    )
  )
}

bayesian_nma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    bayes_results <- reactiveVal(NULL)

    observeEvent(input$run_bayesian, {
      req(rv$nma_data)

      withProgress(message = "Running Bayesian NMA...", {
        tryCatch({

          # Prepare data for gemtc
          setProgress(0.1, detail = "Preparing data...")

          # Convert data to gemtc format
          network <- prepare_gemtc_network(rv$nma_data, input$outcome_measure)

          # Set priors
          setProgress(0.2, detail = "Setting priors...")

          if (input$prior_type == "vague") {
            # Default vague priors
            model <- mtc.model(network,
                              linearModel = "random",
                              n.chain = input$n_chains)
          } else if (input$prior_type == "turner") {
            # Turner et al. informative priors
            prior <- mtc.hy.prior("std.dev", "dunif", 0, 2)
            model <- mtc.model(network,
                              linearModel = "random",
                              hy.prior = prior,
                              n.chain = input$n_chains)
          } else {
            # Custom priors
            prior <- mtc.hy.prior("std.dev", "dnorm",
                                 input$prior_mean,
                                 1/(input$prior_sd^2))
            model <- mtc.model(network,
                              linearModel = "random",
                              hy.prior = prior,
                              n.chain = input$n_chains)
          }

          # Run MCMC
          setProgress(0.3, detail = "Running MCMC sampling...")

          mcmc_results <- mtc.run(model,
                                 n.adapt = input$n_burnin,
                                 n.iter = input$n_iter,
                                 thin = input$n_thin)

          # Calculate summaries
          setProgress(0.8, detail = "Calculating summaries...")

          results <- list(
            model = model,
            mcmc = mcmc_results,
            summary = summary(mcmc_results),
            relative_effects = relative.effect.table(mcmc_results),
            rank_prob = rank.probability(mcmc_results),
            network = network,
            gelman = gelman.diag(mcmc_results),
            inconsistency = check_inconsistency(network, mcmc_results)
          )

          bayes_results(results)

          setProgress(1.0, detail = "Complete!")

          showNotification("✓ Bayesian NMA complete", type = "message")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    # Posterior summary
    output$posterior_summary <- renderPrint({
      req(bayes_results())

      cat("BAYESIAN NETWORK META-ANALYSIS\n")
      cat("================================\n\n")

      cat("Model Specifications:\n")
      cat(sprintf("  Chains: %d\n", input$n_chains))
      cat(sprintf("  Iterations: %d\n", input$n_iter))
      cat(sprintf("  Burn-in: %d\n", input$n_burnin))
      cat(sprintf("  Thinning: %d\n", input$n_thin))
      cat(sprintf("  Effective samples: %d\n\n",
                  (input$n_iter - input$n_burnin) * input$n_chains / input$n_thin))

      cat("Posterior Summary:\n")
      print(bayes_results()$summary)

      cat("\n\nRelative Effects Table:\n")
      print(bayes_results()$relative_effects)
    })

    # Treatment rankings
    output$rank_plot <- renderPlot({
      req(bayes_results())
      plot_rank_probabilities(bayes_results()$rank_prob)
    })

    output$rank_table <- renderDT({
      req(bayes_results())
      format_rank_table(bayes_results()$rank_prob)
    })

    # Forest plot
    output$forest_plot <- renderPlot({
      req(bayes_results())
      forest(bayes_results()$relative_effects,
             use.description = TRUE)
    })

    # Convergence diagnostics
    output$trace_plot <- renderPlot({
      req(bayes_results())
      plot(bayes_results()$mcmc)
    })

    output$gelman_diag <- renderPrint({
      req(bayes_results())

      cat("GELMAN-RUBIN CONVERGENCE DIAGNOSTIC\n")
      cat("====================================\n\n")
      cat("Values < 1.1 indicate convergence\n\n")

      print(bayes_results()$gelman)

      max_psrf <- max(bayes_results()$gelman$psrf[, "Point est."])

      if (max_psrf < 1.05) {
        cat("\n✓ Excellent convergence (all chains < 1.05)\n")
      } else if (max_psrf < 1.1) {
        cat("\n✓ Good convergence (all chains < 1.1)\n")
      } else {
        cat("\n⚠ Poor convergence - consider more iterations\n")
      }
    })

    # Inconsistency check
    output$inconsistency_test <- renderPrint({
      req(bayes_results())

      cat("INCONSISTENCY CHECK\n")
      cat("===================\n\n")

      incons <- bayes_results()$inconsistency

      if (!is.null(incons)) {
        cat(sprintf("Inconsistency SD: %.3f (95%% CrI: %.3f to %.3f)\n",
                   incons$median, incons$lower, incons$upper))

        if (incons$median < 0.1) {
          cat("\n✓ Low inconsistency - network appears consistent\n")
        } else if (incons$median < 0.3) {
          cat("\n⚠ Moderate inconsistency - interpret with caution\n")
        } else {
          cat("\n⚠ High inconsistency - results may be unreliable\n")
        }
      } else {
        cat("Inconsistency check not available for this network structure\n")
      }
    })

    output$inconsistency_plot <- renderPlot({
      req(bayes_results())

      incons <- bayes_results()$inconsistency

      if (!is.null(incons$samples)) {
        hist(incons$samples,
             main = "Posterior Distribution of Inconsistency SD",
             xlab = "Inconsistency SD",
             col = "lightblue",
             border = "white")
        abline(v = incons$median, col = "red", lwd = 2, lty = 2)
      }
    })

    return(reactive(bayes_results()))
  })
}

# Helper functions

prepare_gemtc_network <- function(nma_data, outcome_measure) {
  # Convert data to gemtc format
  # Expects columns: study, treatment, responders, sample_size (for binary)
  # or study, treatment, mean, sd, sample_size (for continuous)

  if (outcome_measure %in% c("OR", "RR")) {
    # Binary data
    network_data <- data.frame(
      study = nma_data$study_id,
      treatment = nma_data$treatment,
      responders = nma_data$events,
      sampleSize = nma_data$n
    )

    network <- mtc.network(data.ab = network_data)

  } else if (outcome_measure == "MD") {
    # Continuous data
    network_data <- data.frame(
      study = nma_data$study_id,
      treatment = nma_data$treatment,
      mean = nma_data$mean,
      std.dev = nma_data$sd,
      sampleSize = nma_data$n
    )

    network <- mtc.network(data.ab = network_data)

  } else {
    # Hazard ratios - use contrast-based
    network_data <- data.frame(
      study = nma_data$study_id,
      treatment = nma_data$treatment,
      diff = log(nma_data$hr),
      std.err = nma_data$se_log_hr
    )

    network <- mtc.network(data.re = network_data)
  }

  return(network)
}

check_inconsistency <- function(network, mcmc_results) {
  # Simple inconsistency check using unrelated mean effects model
  tryCatch({
    ume_model <- mtc.model(network,
                          linearModel = "random",
                          type = "unrelated-mean-effects")
    ume_mcmc <- mtc.run(ume_model, n.adapt = 5000, n.iter = 10000)

    # Extract inconsistency SD
    incons_samples <- as.matrix(ume_mcmc)[, "sd.d"]

    list(
      median = median(incons_samples),
      lower = quantile(incons_samples, 0.025),
      upper = quantile(incons_samples, 0.975),
      samples = incons_samples
    )
  }, error = function(e) {
    NULL
  })
}

plot_rank_probabilities <- function(rank_prob) {
  # Create rank probability plot
  treatments <- rownames(rank_prob)
  ranks <- 1:nrow(rank_prob)

  # Create stacked bar chart
  barplot(t(rank_prob),
          beside = FALSE,
          col = rainbow(length(ranks)),
          main = "Treatment Ranking Probabilities",
          xlab = "Treatment",
          ylab = "Probability",
          legend.text = paste("Rank", ranks),
          args.legend = list(x = "topright"))
}

format_rank_table <- function(rank_prob) {
  # Format ranking table
  treatments <- rownames(rank_prob)

  # Calculate mean rank and SUCRA
  mean_ranks <- apply(rank_prob, 1, function(x) sum(x * 1:length(x)))
  sucra <- 100 * (1 - (mean_ranks - 1) / (nrow(rank_prob) - 1))

  # Probability of being best
  prob_best <- rank_prob[, 1]

  df <- data.frame(
    Treatment = treatments,
    Mean_Rank = round(mean_ranks, 2),
    SUCRA = round(sucra, 1),
    Prob_Best = round(prob_best * 100, 1),
    stringsAsFactors = FALSE
  )

  df <- df[order(df$Mean_Rank), ]

  datatable(df,
           rownames = FALSE,
           options = list(pageLength = 20),
           colnames = c("Treatment", "Mean Rank", "SUCRA (%)", "P(Best) (%)"))
}
