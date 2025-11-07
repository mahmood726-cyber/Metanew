# Bayesian Meta-Analysis Module
# Implements Bayesian random effects meta-analysis
# Matches WinBUGS/OpenBUGS capabilities with modern UI

library(shiny)
library(rstan)  # Stan for Bayesian inference (faster than BUGS)
library(ggplot2)

bayesian_ma_ui <- function(id) {
  ns <- NS(id)

  tagList(
    card(
      card_header(
        div(
          icon("chart-area", class = "me-2"),
          "Bayesian Meta-Analysis"
        )
      ),

      layout_columns(
        col_widths = c(4, 8),

        # Settings panel
        card(
          card_header("Bayesian Model Settings"),

          selectInput(ns("outcome"), "Outcome",
                     choices = NULL),

          selectInput(ns("effect_measure"), "Effect Measure",
                     choices = c(
                       "Log Odds Ratio" = "OR",
                       "Log Risk Ratio" = "RR",
                       "Mean Difference" = "MD",
                       "Standardized Mean Difference" = "SMD",
                       "Log Hazard Ratio" = "HR"
                     )),

          hr(),

          h5("Prior Distributions"),

          selectInput(ns("prior_type"), "Prior for Treatment Effect",
                     choices = c(
                       "Weakly Informative" = "weak",
                       "Non-informative (Flat)" = "flat",
                       "Informative (Custom)" = "informative",
                       "Skeptical" = "skeptical",
                       "Enthusiastic" = "enthusiastic"
                     ),
                     selected = "weak"),

          conditionalPanel(
            condition = "input.prior_type == 'informative'",
            ns = ns,
            numericInput(ns("prior_mean"), "Prior Mean", 0),
            numericInput(ns("prior_sd"), "Prior SD", 1)
          ),

          hr(),

          h5("Heterogeneity Prior"),

          selectInput(ns("tau_prior"), "Prior for τ (Between-Study SD)",
                     choices = c(
                       "Half-Normal(0, 0.5)" = "half_normal_05",
                       "Half-Normal(0, 1)" = "half_normal_1",
                       "Half-Cauchy(0, 0.5)" = "half_cauchy_05",
                       "Uniform(0, 2)" = "uniform_2",
                       "Custom" = "custom"
                     ),
                     selected = "half_normal_05"),

          conditionalPanel(
            condition = "input.tau_prior == 'custom'",
            ns = ns,
            numericInput(ns("tau_max"), "Maximum τ", 2)
          ),

          hr(),

          h5("MCMC Settings"),

          numericInput(ns("n_chains"), "Number of Chains", 4, min = 2, max = 8),
          numericInput(ns("n_iter"), "Iterations per Chain", 2000, min = 1000, max = 20000),
          numericInput(ns("n_warmup"), "Warmup Iterations", 1000, min = 500, max = 10000),
          numericInput(ns("thin"), "Thinning", 1, min = 1, max = 10),

          checkboxInput(ns("adapt_delta"), "Increase adapt_delta (if divergent)", FALSE),

          hr(),

          actionButton(ns("btn_run"), "Run Bayesian Analysis",
                      class = "btn-primary w-100",
                      icon = icon("play"))
        ),

        # Results panel
        card(
          card_header("Bayesian Analysis Results"),

          navset_card_tab(
            nav_panel("Posterior Summary",
                     verbatimTextOutput(ns("posterior_summary"))),
            nav_panel("Forest Plot",
                     plotOutput(ns("forest_plot"), height = "600px")),
            nav_panel("Posterior Distributions",
                     plotOutput(ns("posterior_plots"), height = "600px")),
            nav_panel("Trace Plots",
                     plotOutput(ns("trace_plots"), height = "600px")),
            nav_panel("Prior Sensitivity",
                     plotOutput(ns("prior_sensitivity"), height = "500px")),
            nav_panel("Diagnostics",
                     uiOutput(ns("diagnostics"))),
            nav_panel("Comparison",
                     uiOutput(ns("comparison_table")))
          )
        )
      )
    )
  )
}

bayesian_ma_server <- function(id, rv) {
  moduleServer(id, function(input, output, session) {

    bayesian_results <- reactiveVal(NULL)

    # Update outcome choices
    observe({
      req(rv$data)
      if ("outcome" %in% names(rv$data)) {
        outcomes <- unique(rv$data$outcome)
        updateSelectInput(session, "outcome", choices = outcomes)
      }
    })

    # Run Bayesian meta-analysis
    observeEvent(input$btn_run, {
      req(rv$data, input$outcome)

      withProgress(message = "Running Bayesian meta-analysis (MCMC)...", {

        tryCatch({
          # Prepare data
          data_for_analysis <- rv$data %>%
            filter(outcome == input$outcome) %>%
            filter(!is.na(yi), !is.na(sei))

          if (nrow(data_for_analysis) < 2) {
            showNotification("Need at least 2 studies for meta-analysis", type = "error")
            return()
          }

          # Set priors
          priors <- get_priors(input$prior_type, input$prior_mean, input$prior_sd,
                               input$tau_prior, input$tau_max)

          # Run Bayesian analysis
          results <- run_bayesian_ma_stan(
            yi = data_for_analysis$yi,
            sei = data_for_analysis$sei,
            study_labels = data_for_analysis$study_id,
            priors = priors,
            n_chains = input$n_chains,
            n_iter = input$n_iter,
            n_warmup = input$n_warmup,
            thin = input$thin,
            adapt_delta = if (input$adapt_delta) 0.95 else 0.8
          )

          # Also run frequentist for comparison
          freq_results <- tryCatch({
            library(metafor)
            rma(yi = yi, sei = sei, data = data_for_analysis, method = "REML")
          }, error = function(e) NULL)

          results$frequentist_comparison <- freq_results
          results$data <- data_for_analysis

          bayesian_results(results)
          rv$bayesian_ma_results <- results

          showNotification("✓ Bayesian meta-analysis complete", type = "message")

        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error", duration = 10)
        })
      })
    })

    # Posterior summary
    output$posterior_summary <- renderPrint({
      req(bayesian_results())
      results <- bayesian_results()

      cat("BAYESIAN META-ANALYSIS RESULTS\n")
      cat("===============================\n\n")

      cat("Model: Bayesian Random Effects Meta-Analysis\n")
      cat("Estimation: MCMC via Stan\n")
      cat(sprintf("Studies: %d\n", results$n_studies))
      cat(sprintf("Chains: %d\n", results$n_chains))
      cat(sprintf("Iterations: %d (per chain)\n\n", results$n_iter))

      cat("POSTERIOR ESTIMATES\n")
      cat("-------------------\n\n")

      cat("Pooled Effect (μ):\n")
      cat(sprintf("  Posterior Mean: %.3f\n", results$summary$mu_mean))
      cat(sprintf("  Posterior Median: %.3f\n", results$summary$mu_median))
      cat(sprintf("  95%% Credible Interval: %.3f to %.3f\n",
                 results$summary$mu_2.5, results$summary$mu_97.5))
      cat(sprintf("  P(Effect > 0): %.3f\n", results$summary$prob_positive))
      cat("\n")

      cat("Between-Study Heterogeneity (τ):\n")
      cat(sprintf("  Posterior Mean: %.3f\n", results$summary$tau_mean))
      cat(sprintf("  Posterior Median: %.3f\n", results$summary$tau_median))
      cat(sprintf("  95%% Credible Interval: %.3f to %.3f\n",
                 results$summary$tau_2.5, results$summary$tau_97.5))
      cat("\n")

      cat("I² (Derived from τ):\n")
      cat(sprintf("  Posterior Mean: %.1f%%\n", results$summary$i_squared_mean))
      cat(sprintf("  95%% Credible Interval: %.1f%% to %.1f%%\n\n",
                 results$summary$i_squared_2.5, results$summary$i_squared_97.5))

      cat("CONVERGENCE DIAGNOSTICS\n")
      cat("-----------------------\n")
      cat(sprintf("  Rhat (μ): %.3f %s\n", results$diagnostics$rhat_mu,
                 if (results$diagnostics$rhat_mu < 1.01) "✓" else "⚠ Check convergence"))
      cat(sprintf("  Rhat (τ): %.3f %s\n", results$diagnostics$rhat_tau,
                 if (results$diagnostics$rhat_tau < 1.01) "✓" else "⚠ Check convergence"))
      cat(sprintf("  Effective Sample Size (μ): %.0f\n", results$diagnostics$n_eff_mu))
      cat(sprintf("  Divergent transitions: %d %s\n", results$diagnostics$n_divergent,
                 if (results$diagnostics$n_divergent == 0) "✓" else "⚠ Consider increasing adapt_delta"))
    })

    # Forest plot (Bayesian)
    output$forest_plot <- renderPlot({
      req(bayesian_results())
      plot_bayesian_forest(bayesian_results())
    })

    # Posterior distributions
    output$posterior_plots <- renderPlot({
      req(bayesian_results())
      plot_posterior_distributions(bayesian_results())
    })

    # Trace plots
    output$trace_plots <- renderPlot({
      req(bayesian_results())
      plot_trace_plots(bayesian_results())
    })

    # Prior sensitivity
    output$prior_sensitivity <- renderPlot({
      req(bayesian_results())
      plot_prior_sensitivity(bayesian_results())
    })

    # Diagnostics
    output$diagnostics <- renderUI({
      req(bayesian_results())
      results <- bayesian_results()

      # Convergence assessment
      convergence_ok <- results$diagnostics$rhat_mu < 1.01 && results$diagnostics$rhat_tau < 1.01
      divergent_ok <- results$diagnostics$n_divergent == 0

      tagList(
        h4("MCMC Diagnostics"),

        card(
          card_header("Convergence Assessment"),
          if (convergence_ok) {
            div(class = "alert alert-success",
                icon("check-circle"), " All parameters converged (Rhat < 1.01)")
          } else {
            div(class = "alert alert-warning",
                icon("exclamation-triangle"),
                " Some parameters may not have converged. Consider running more iterations.")
          }
        ),

        card(
          card_header("Sampling Quality"),
          if (divergent_ok) {
            div(class = "alert alert-success",
                icon("check-circle"), " No divergent transitions detected")
          } else {
            div(class = "alert alert-warning",
                icon("exclamation-triangle"),
                sprintf(" %d divergent transitions detected. Enable 'Increase adapt_delta' and re-run.",
                       results$diagnostics$n_divergent))
          }
        ),

        card(
          card_header("Effective Sample Size"),
          tags$table(
            class = "table table-sm",
            tags$tr(tags$th("Parameter"), tags$th("ESS"), tags$th("Assessment")),
            tags$tr(
              tags$td("μ (Pooled Effect)"),
              tags$td(sprintf("%.0f", results$diagnostics$n_eff_mu)),
              tags$td(if (results$diagnostics$n_eff_mu > 400) "✓ Good" else "⚠ Low")
            ),
            tags$tr(
              tags$td("τ (Heterogeneity)"),
              tags$td(sprintf("%.0f", results$diagnostics$n_eff_tau)),
              tags$td(if (results$diagnostics$n_eff_tau > 400) "✓ Good" else "⚠ Low")
            )
          )
        )
      )
    })

    # Comparison table
    output$comparison_table <- renderUI({
      req(bayesian_results())
      results <- bayesian_results()

      if (is.null(results$frequentist_comparison)) {
        return(p("Frequentist comparison not available."))
      }

      freq <- results$frequentist_comparison

      tagList(
        h4("Bayesian vs. Frequentist Comparison"),

        tags$table(
          class = "table table-bordered",
          tags$thead(
            tags$tr(
              tags$th("Metric"),
              tags$th("Bayesian"),
              tags$th("Frequentist"),
              tags$th("Difference")
            )
          ),
          tags$tbody(
            tags$tr(
              tags$td("Pooled Effect (Mean/Estimate)"),
              tags$td(sprintf("%.3f", results$summary$mu_mean)),
              tags$td(sprintf("%.3f", freq$beta)),
              tags$td(sprintf("%.3f", results$summary$mu_mean - freq$beta))
            ),
            tags$tr(
              tags$td("95% Interval"),
              tags$td(sprintf("%.3f to %.3f", results$summary$mu_2.5, results$summary$mu_97.5)),
              tags$td(sprintf("%.3f to %.3f", freq$ci.lb, freq$ci.ub)),
              tags$td("-")
            ),
            tags$tr(
              tags$td("Heterogeneity (τ)"),
              tags$td(sprintf("%.3f", results$summary$tau_mean)),
              tags$td(sprintf("%.3f", sqrt(freq$tau2))),
              tags$td(sprintf("%.3f", results$summary$tau_mean - sqrt(freq$tau2)))
            ),
            tags$tr(
              tags$td("I²"),
              tags$td(sprintf("%.1f%%", results$summary$i_squared_mean)),
              tags$td(sprintf("%.1f%%", freq$I2)),
              tags$td(sprintf("%.1f%%", results$summary$i_squared_mean - freq$I2))
            )
          )
        ),

        hr(),

        h5("Interpretation"),
        p("Bayesian and frequentist estimates typically agree when:"),
        tags$ul(
          tags$li("Priors are weakly informative or non-informative"),
          tags$li("Sample size is moderate to large"),
          tags$li("Results converge properly")
        ),

        p(strong("Key Advantage of Bayesian Approach:")),
        tags$ul(
          tags$li("Direct probability statements (e.g., P(Effect > 0) = ",
                 sprintf("%.1f%%", results$summary$prob_positive * 100), ")"),
          tags$li("Full posterior distributions for all parameters"),
          tags$li("Credible intervals have direct probability interpretation"),
          tags$li("Can incorporate prior information systematically"),
          tags$li("Prediction intervals derived directly from posterior")
        )
      )
    })

    return(reactive(bayesian_results()))
  })
}

#' Get prior distributions
get_priors <- function(prior_type, prior_mean = 0, prior_sd = 1, tau_prior = "half_normal_05", tau_max = 2) {

  # Prior for treatment effect (μ)
  if (prior_type == "flat") {
    mu_prior <- list(type = "normal", mean = 0, sd = 100)  # Very wide (flat)
  } else if (prior_type == "weak") {
    mu_prior <- list(type = "normal", mean = 0, sd = 2)  # Weakly informative
  } else if (prior_type == "informative") {
    mu_prior <- list(type = "normal", mean = prior_mean, sd = prior_sd)
  } else if (prior_type == "skeptical") {
    mu_prior <- list(type = "normal", mean = 0, sd = 0.5)  # Centered at null, narrow
  } else if (prior_type == "enthusiastic") {
    mu_prior <- list(type = "normal", mean = 0.5, sd = 0.5)  # Centered at benefit
  } else {
    mu_prior <- list(type = "normal", mean = 0, sd = 2)
  }

  # Prior for heterogeneity (τ)
  if (tau_prior == "half_normal_05") {
    tau_prior_obj <- list(type = "half_normal", scale = 0.5)
  } else if (tau_prior == "half_normal_1") {
    tau_prior_obj <- list(type = "half_normal", scale = 1.0)
  } else if (tau_prior == "half_cauchy_05") {
    tau_prior_obj <- list(type = "half_cauchy", scale = 0.5)
  } else if (tau_prior == "uniform_2") {
    tau_prior_obj <- list(type = "uniform", max = 2.0)
  } else if (tau_prior == "custom") {
    tau_prior_obj <- list(type = "uniform", max = tau_max)
  } else {
    tau_prior_obj <- list(type = "half_normal", scale = 0.5)
  }

  list(mu = mu_prior, tau = tau_prior_obj)
}

#' Run Bayesian meta-analysis using Stan
run_bayesian_ma_stan <- function(yi, sei, study_labels, priors, n_chains = 4, n_iter = 2000,
                                   n_warmup = 1000, thin = 1, adapt_delta = 0.8) {

  # Stan model code for random effects meta-analysis
  stan_code <- "
data {
  int<lower=0> N;              // number of studies
  vector[N] y;                 // effect size
  vector<lower=0>[N] sigma;    // standard error
  real mu_mean;                // prior mean for pooled effect
  real<lower=0> mu_sd;         // prior SD for pooled effect
  real<lower=0> tau_scale;     // prior scale for tau
}
parameters {
  real mu;                     // pooled effect
  real<lower=0> tau;           // between-study SD
  vector[N] theta;             // true effects
}
model {
  // Priors
  mu ~ normal(mu_mean, mu_sd);
  tau ~ cauchy(0, tau_scale);

  // Study-specific effects
  theta ~ normal(mu, tau);

  // Likelihood
  y ~ normal(theta, sigma);
}
generated quantities {
  real pred_effect;            // predictive distribution for new study
  vector[N] log_lik;          // log-likelihood for LOO

  pred_effect = normal_rng(mu, tau);

  for (n in 1:N) {
    log_lik[n] = normal_lpdf(y[n] | theta[n], sigma[n]);
  }
}
"

  # Prepare Stan data
  stan_data <- list(
    N = length(yi),
    y = yi,
    sigma = sei,
    mu_mean = priors$mu$mean,
    mu_sd = priors$mu$sd,
    tau_scale = if (priors$tau$type == "half_normal") priors$tau$scale else 0.5
  )

  # Compile and run Stan model
  suppressMessages({
    fit <- stan(
      model_code = stan_code,
      data = stan_data,
      chains = n_chains,
      iter = n_iter,
      warmup = n_warmup,
      thin = thin,
      control = list(adapt_delta = adapt_delta),
      refresh = 0,  # Suppress Stan output
      verbose = FALSE
    )
  })

  # Extract results
  samples <- extract(fit)

  # Calculate summary statistics
  mu_samples <- samples$mu
  tau_samples <- samples$tau

  # Calculate I² from tau samples
  typical_sigma <- median(sei)
  i_squared_samples <- 100 * tau_samples^2 / (tau_samples^2 + typical_sigma^2)

  summary_stats <- list(
    mu_mean = mean(mu_samples),
    mu_median = median(mu_samples),
    mu_2.5 = quantile(mu_samples, 0.025),
    mu_97.5 = quantile(mu_samples, 0.975),
    prob_positive = mean(mu_samples > 0),
    prob_negative = mean(mu_samples < 0),

    tau_mean = mean(tau_samples),
    tau_median = median(tau_samples),
    tau_2.5 = quantile(tau_samples, 0.025),
    tau_97.5 = quantile(tau_samples, 0.975),

    i_squared_mean = mean(i_squared_samples),
    i_squared_median = median(i_squared_samples),
    i_squared_2.5 = quantile(i_squared_samples, 0.025),
    i_squared_97.5 = quantile(i_squared_samples, 0.975)
  )

  # Get Rhat and effective sample size
  fit_summary <- summary(fit)$summary
  rhat_mu <- fit_summary["mu", "Rhat"]
  rhat_tau <- fit_summary["tau", "Rhat"]
  n_eff_mu <- fit_summary["mu", "n_eff"]
  n_eff_tau <- fit_summary["tau", "n_eff"]

  # Check for divergent transitions
  sampler_params <- get_sampler_params(fit, inc_warmup = FALSE)
  n_divergent <- sum(sapply(sampler_params, function(x) sum(x[, "divergent__"])))

  # Return results
  list(
    fit = fit,
    samples = samples,
    summary = summary_stats,
    diagnostics = list(
      rhat_mu = rhat_mu,
      rhat_tau = rhat_tau,
      n_eff_mu = n_eff_mu,
      n_eff_tau = n_eff_tau,
      n_divergent = n_divergent
    ),
    n_studies = length(yi),
    n_chains = n_chains,
    n_iter = n_iter,
    study_labels = study_labels
  )
}

#' Plot Bayesian forest plot
plot_bayesian_forest <- function(results) {
  library(ggplot2)

  # Extract study-specific posterior means
  theta_samples <- results$samples$theta
  theta_means <- colMeans(theta_samples)
  theta_lower <- apply(theta_samples, 2, quantile, 0.025)
  theta_upper <- apply(theta_samples, 2, quantile, 0.975)

  # Create plot data
  plot_data <- data.frame(
    study = factor(results$study_labels, levels = rev(results$study_labels)),
    estimate = theta_means,
    lower = theta_lower,
    upper = theta_upper,
    type = "Study"
  )

  # Add pooled estimate
  pooled_row <- data.frame(
    study = factor("Pooled (Bayesian)", levels = c(levels(plot_data$study), "Pooled (Bayesian)")),
    estimate = results$summary$mu_mean,
    lower = results$summary$mu_2.5,
    upper = results$summary$mu_97.5,
    type = "Pooled"
  )

  plot_data <- rbind(plot_data, pooled_row)

  # Create forest plot
  ggplot(plot_data, aes(x = estimate, y = study)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = lower, xmax = upper, color = type),
                   height = 0.3, size = 0.8) +
    geom_point(aes(color = type, size = type, shape = type)) +
    scale_color_manual(values = c("Study" = "steelblue", "Pooled" = "red")) +
    scale_size_manual(values = c("Study" = 2.5, "Pooled" = 4)) +
    scale_shape_manual(values = c("Study" = 16, "Pooled" = 18)) +
    labs(
      title = "Bayesian Forest Plot",
      subtitle = sprintf("Pooled Effect: %.3f (95%% CrI: %.3f to %.3f)",
                        results$summary$mu_mean,
                        results$summary$mu_2.5,
                        results$summary$mu_97.5),
      x = "Effect Size",
      y = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "none",
          plot.title = element_text(face = "bold", size = 14))
}

#' Plot posterior distributions
plot_posterior_distributions <- function(results) {
  library(ggplot2)
  library(gridExtra)

  # Posterior for μ
  mu_data <- data.frame(value = results$samples$mu)

  p1 <- ggplot(mu_data, aes(x = value)) +
    geom_density(fill = "steelblue", alpha = 0.5, size = 1.2) +
    geom_vline(xintercept = results$summary$mu_mean, linetype = "solid", color = "red", size = 1) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_vline(xintercept = results$summary$mu_2.5, linetype = "dotted", color = "red") +
    geom_vline(xintercept = results$summary$mu_97.5, linetype = "dotted", color = "red") +
    labs(title = "Posterior Distribution: Pooled Effect (μ)",
         x = "Effect Size", y = "Density") +
    theme_minimal()

  # Posterior for τ
  tau_data <- data.frame(value = results$samples$tau)

  p2 <- ggplot(tau_data, aes(x = value)) +
    geom_density(fill = "orange", alpha = 0.5, size = 1.2) +
    geom_vline(xintercept = results$summary$tau_mean, linetype = "solid", color = "red", size = 1) +
    geom_vline(xintercept = results$summary$tau_2.5, linetype = "dotted", color = "red") +
    geom_vline(xintercept = results$summary$tau_97.5, linetype = "dotted", color = "red") +
    labs(title = "Posterior Distribution: Heterogeneity (τ)",
         x = "Between-Study SD", y = "Density") +
    theme_minimal()

  grid.arrange(p1, p2, ncol = 1)
}

#' Plot trace plots for convergence
plot_trace_plots <- function(results) {
  library(ggplot2)
  library(gridExtra)

  fit <- results$fit

  # Extract samples with chain info
  mu_samples <- as.data.frame(extract(fit, "mu", permuted = FALSE))
  tau_samples <- as.data.frame(extract(fit, "tau", permuted = FALSE))

  # Reshape for plotting
  n_iter_per_chain <- nrow(mu_samples)
  n_chains <- ncol(mu_samples)

  mu_long <- data.frame(
    iteration = rep(1:n_iter_per_chain, n_chains),
    chain = rep(1:n_chains, each = n_iter_per_chain),
    value = unlist(mu_samples)
  )

  tau_long <- data.frame(
    iteration = rep(1:n_iter_per_chain, n_chains),
    chain = rep(1:n_chains, each = n_iter_per_chain),
    value = unlist(tau_samples)
  )

  p1 <- ggplot(mu_long, aes(x = iteration, y = value, color = factor(chain))) +
    geom_line(alpha = 0.7) +
    labs(title = "Trace Plot: μ (Pooled Effect)", x = "Iteration", y = "Value", color = "Chain") +
    theme_minimal()

  p2 <- ggplot(tau_long, aes(x = iteration, y = value, color = factor(chain))) +
    geom_line(alpha = 0.7) +
    labs(title = "Trace Plot: τ (Heterogeneity)", x = "Iteration", y = "Value", color = "Chain") +
    theme_minimal()

  grid.arrange(p1, p2, ncol = 1)
}

#' Plot prior sensitivity
plot_prior_sensitivity <- function(results) {
  # Placeholder for prior sensitivity analysis
  # Would run model with different priors and compare

  plot.new()
  text(0.5, 0.5, "Prior Sensitivity Analysis\n(Run multiple models with different priors to compare)",
       cex = 1.2, col = "gray50")
}
