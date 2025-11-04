# Advanced Health Economics Features
# Value of Information (VOI) analysis and Budget Impact Model (BIM)

library(BCEA)

#' Calculate Expected Value of Perfect Information (EVPI)
#'
#' @param psa_results PSA results from markov model
#' @param wtp_threshold Willingness-to-pay threshold
#' @param n_patients Number of patients affected
#' @return List with EVPI results
calculate_evpi <- function(psa_results, wtp_threshold = 30000, n_patients = 10000) {
  if (is.null(psa_results) || nrow(psa_results) == 0) {
    return(list(error = "No PSA results available"))
  }

  tryCatch({
    # Extract costs and effects for each arm
    # Assuming psa_results has columns: iteration, arm, total_cost, total_qalys

    arms <- unique(psa_results$arm)
    if (length(arms) != 2) {
      return(list(error = "EVPI requires exactly 2 arms"))
    }

    # Reshape data
    costs_matrix <- matrix(0, nrow = nrow(psa_results) / 2, ncol = 2)
    effects_matrix <- matrix(0, nrow = nrow(psa_results) / 2, ncol = 2)

    for (i in 1:length(arms)) {
      arm_data <- psa_results[psa_results$arm == arms[i], ]
      costs_matrix[, i] <- arm_data$total_cost
      effects_matrix[, i] <- arm_data$total_qalys
    }

    # Calculate NMB for each iteration
    nmb_matrix <- effects_matrix * wtp_threshold - costs_matrix

    # Maximum NMB with current information (expected)
    expected_nmb <- apply(nmb_matrix, 2, mean)
    max_expected_nmb <- max(expected_nmb)
    optimal_arm_expected <- arms[which.max(expected_nmb)]

    # Maximum NMB with perfect information (known in each iteration)
    max_nmb_per_iteration <- apply(nmb_matrix, 1, max)
    expected_max_nmb <- mean(max_nmb_per_iteration)

    # EVPI per patient
    evpi_per_patient <- expected_max_nmb - max_expected_nmb

    # Population EVPI
    evpi_population <- evpi_per_patient * n_patients

    return(list(
      evpi_per_patient = evpi_per_patient,
      evpi_population = evpi_population,
      n_patients = n_patients,
      wtp_threshold = wtp_threshold,
      optimal_arm = optimal_arm_expected,
      expected_nmb = max_expected_nmb,
      perfect_info_nmb = expected_max_nmb,
      interpretation = if (evpi_per_patient > 1000) {
        "High EVPI suggests further research could be valuable"
      } else if (evpi_per_patient > 100) {
        "Moderate EVPI - consider additional research"
      } else {
        "Low EVPI - current evidence may be sufficient"
      }
    ))

  }, error = function(e) {
    return(list(error = paste("EVPI calculation error:", e$message)))
  })
}

#' Calculate Expected Value of Partial Perfect Information (EVPPI)
#'
#' @param psa_results PSA results
#' @param parameter_name Parameter(s) to assess (single name or vector of names)
#' @param wtp_threshold WTP threshold
#' @param n_patients Number of patients
#' @param method Method for multi-parameter EVPPI ("gam", "loess", "linear")
#' @return List with EVPPI results
calculate_evppi <- function(psa_results, parameter_name, wtp_threshold = 30000,
                            n_patients = 10000, method = "gam") {
  # EVPPI using nonparametric regression
  # Supports single or multiple parameters

  tryCatch({
    # Check if parameters exist
    missing_params <- parameter_name[!parameter_name %in% names(psa_results)]
    if (length(missing_params) > 0) {
      return(list(error = paste("Parameters not found:", paste(missing_params, collapse = ", "))))
    }

    # Calculate NMB
    arms <- unique(psa_results$arm)
    nmb_by_iteration <- sapply(split(psa_results, psa_results$iteration), function(iter_data) {
      nmb <- iter_data$total_qalys * wtp_threshold - iter_data$total_cost
      max(nmb)
    })

    # Single parameter EVPPI
    if (length(parameter_name) == 1) {
      # Get parameter values
      param_values <- psa_results[[parameter_name]][psa_results$arm == arms[1]]

      # Nonparametric regression (loess)
      fit <- loess(nmb_by_iteration ~ param_values, span = 0.75)
      predicted_nmb <- predict(fit)

      # EVPPI
      evppi_per_patient <- mean(predicted_nmb) - mean(nmb_by_iteration)
      evppi_population <- evppi_per_patient * n_patients

      return(list(
        parameters = parameter_name,
        n_parameters = 1,
        evppi_per_patient = evppi_per_patient,
        evppi_population = evppi_population,
        n_patients = n_patients,
        wtp_threshold = wtp_threshold,
        method = "loess"
      ))

    } else {
      # Multi-parameter EVPPI using GAM or other methods

      # Extract parameter values for first arm
      param_data <- psa_results[psa_results$arm == arms[1], parameter_name, drop = FALSE]

      if (method == "gam") {
        # Generalized Additive Model for multi-parameter smoothing
        library(mgcv)

        # Build formula
        formula_str <- paste("nmb_by_iteration ~",
                            paste0("s(", parameter_name, ")", collapse = " + "))
        formula_obj <- as.formula(formula_str)

        # Fit GAM
        df_gam <- cbind(data.frame(nmb_by_iteration = nmb_by_iteration), param_data)
        fit <- gam(formula_obj, data = df_gam)
        predicted_nmb <- predict(fit)

      } else if (method == "loess") {
        # Multi-dimensional loess (limited to 2-3 parameters)
        if (length(parameter_name) > 3) {
          return(list(error = "LOESS limited to 3 parameters. Use method='gam' for more."))
        }

        formula_str <- paste("nmb_by_iteration ~", paste(parameter_name, collapse = " + "))
        formula_obj <- as.formula(formula_str)

        df_loess <- cbind(data.frame(nmb_by_iteration = nmb_by_iteration), param_data)
        fit <- loess(formula_obj, data = df_loess, span = 0.75)
        predicted_nmb <- predict(fit)

      } else if (method == "linear") {
        # Linear regression (fast but less accurate)
        formula_str <- paste("nmb_by_iteration ~", paste(parameter_name, collapse = " + "))
        formula_obj <- as.formula(formula_str)

        df_lm <- cbind(data.frame(nmb_by_iteration = nmb_by_iteration), param_data)
        fit <- lm(formula_obj, data = df_lm)
        predicted_nmb <- predict(fit)
      }

      # EVPPI for parameter group
      evppi_per_patient <- mean(predicted_nmb) - mean(nmb_by_iteration)
      evppi_population <- evppi_per_patient * n_patients

      return(list(
        parameters = parameter_name,
        n_parameters = length(parameter_name),
        evppi_per_patient = evppi_per_patient,
        evppi_population = evppi_population,
        n_patients = n_patients,
        wtp_threshold = wtp_threshold,
        method = method,
        interpretation = interpret_evppi(evppi_per_patient, length(parameter_name))
      ))
    }

  }, error = function(e) {
    return(list(error = paste("EVPPI calculation error:", e$message)))
  })
}

#' Interpret EVPPI value
#' @param evppi_value EVPPI per patient
#' @param n_params Number of parameters
#' @return Interpretation string
interpret_evppi <- function(evppi_value, n_params) {
  if (evppi_value < 0) {
    return("Negative EVPPI (likely numerical error - check model)")
  }

  threshold <- if (n_params == 1) 500 else 1000

  if (evppi_value > threshold * 2) {
    return("Very high EVPPI - further research on these parameters highly valuable")
  } else if (evppi_value > threshold) {
    return("High EVPPI - additional research on these parameters recommended")
  } else if (evppi_value > threshold / 2) {
    return("Moderate EVPPI - consider research if feasible")
  } else {
    return("Low EVPPI - current evidence likely sufficient for these parameters")
  }
}

#' Run budget impact model
#'
#' @param intervention_cost Cost per patient for intervention
#' @param comparator_cost Cost per patient for comparator
#' @param n_patients_yr1 Number of patients in year 1
#' @param market_share_yr1 Market share in year 1 (0-1)
#' @param market_share_yr5 Market share in year 5 (0-1)
#' @param n_years Number of years (default: 5)
#' @param discount_rate Discount rate for costs
#' @return List with budget impact results
calculate_budget_impact <- function(intervention_cost, comparator_cost, n_patients_yr1,
                                   market_share_yr1 = 0.1, market_share_yr5 = 0.5,
                                   n_years = 5, discount_rate = 0.035) {

  tryCatch({
    # Projected market uptake (linear interpolation)
    market_share <- seq(market_share_yr1, market_share_yr5, length.out = n_years)

    # Patient growth (assume 2% annual growth)
    growth_rate <- 0.02
    n_patients <- n_patients_yr1 * (1 + growth_rate)^(0:(n_years - 1))

    # Calculate costs for each year
    results <- data.frame(
      year = 1:n_years,
      n_patients = round(n_patients),
      market_share = market_share,
      n_intervention = round(n_patients * market_share),
      n_comparator = round(n_patients * (1 - market_share))
    )

    # Intervention scenario costs
    results$intervention_scenario_cost <-
      results$n_intervention * intervention_cost +
      results$n_comparator * comparator_cost

    # Comparator scenario costs (all patients on comparator)
    results$comparator_scenario_cost <- results$n_patients * comparator_cost

    # Incremental budget impact
    results$incremental_cost <- results$intervention_scenario_cost - results$comparator_scenario_cost

    # Discounted costs
    discount_factor <- 1 / (1 + discount_rate)^(0:(n_years - 1))
    results$discount_factor <- discount_factor
    results$incremental_cost_discounted <- results$incremental_cost * discount_factor

    # Total budget impact
    total_undiscounted <- sum(results$incremental_cost)
    total_discounted <- sum(results$incremental_cost_discounted)

    return(list(
      yearly_results = results,
      total_undiscounted = total_undiscounted,
      total_discounted = total_discounted,
      intervention_cost = intervention_cost,
      comparator_cost = comparator_cost,
      n_years = n_years,
      discount_rate = discount_rate,
      summary_stats = list(
        avg_annual_impact = mean(results$incremental_cost),
        peak_year = which.max(results$incremental_cost),
        peak_impact = max(results$incremental_cost)
      )
    ))

  }, error = function(e) {
    return(list(error = paste("Budget impact calculation error:", e$message)))
  })
}

#' Plot EVPI curve across WTP thresholds
#'
#' @param psa_results PSA results
#' @param wtp_range Vector of WTP thresholds to evaluate
#' @param n_patients Number of patients
#' @return ggplot object
plot_evpi_curve <- function(psa_results, wtp_range = seq(0, 50000, by = 5000), n_patients = 10000) {
  library(ggplot2)

  # Calculate EVPI for each WTP
  evpi_results <- lapply(wtp_range, function(wtp) {
    result <- calculate_evpi(psa_results, wtp_threshold = wtp, n_patients = n_patients)
    data.frame(
      wtp = wtp,
      evpi_per_patient = result$evpi_per_patient,
      evpi_population = result$evpi_population
    )
  })

  evpi_df <- do.call(rbind, evpi_results)

  ggplot(evpi_df, aes(x = wtp, y = evpi_per_patient)) +
    geom_line(color = "#0066CC", size = 1.2) +
    geom_area(alpha = 0.3, fill = "#0066CC") +
    scale_x_continuous(labels = scales::comma) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Expected Value of Perfect Information (EVPI)",
      subtitle = sprintf("Population size: %s patients", scales::comma(n_patients)),
      x = "Willingness-to-Pay Threshold (£/QALY)",
      y = "EVPI per Patient (£)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold")
    )
}

#' Plot budget impact over time
#'
#' @param bim_results Results from calculate_budget_impact()
#' @return ggplot object
plot_budget_impact <- function(bim_results) {
  library(ggplot2)
  library(tidyr)

  if (!is.null(bim_results$error)) {
    return(NULL)
  }

  df <- bim_results$yearly_results

  # Reshape for plotting
  df_long <- df %>%
    select(year, intervention_scenario_cost, comparator_scenario_cost, incremental_cost) %>%
    pivot_longer(
      cols = -year,
      names_to = "cost_type",
      values_to = "cost"
    ) %>%
    mutate(
      cost_type = factor(cost_type,
                        levels = c("comparator_scenario_cost", "intervention_scenario_cost", "incremental_cost"),
                        labels = c("Comparator Scenario", "Intervention Scenario", "Incremental Budget Impact"))
    )

  ggplot(df_long, aes(x = year, y = cost / 1e6, fill = cost_type)) +
    geom_bar(stat = "identity", position = "dodge") +
    scale_fill_manual(values = c("#999999", "#0066CC", "#FF6B35")) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = "Budget Impact Analysis",
      subtitle = sprintf("Total %d-year impact: £%s M (discounted)",
                        bim_results$n_years,
                        format(round(bim_results$total_discounted / 1e6, 2), nsmall = 2)),
      x = "Year",
      y = "Cost (£ Millions)",
      fill = "Scenario"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
}

#' Format EVPI results for display
#'
#' @param evpi_result Result from calculate_evpi()
#' @return HTML tags
format_evpi_display <- function(evpi_result) {
  if (!is.null(evpi_result$error)) {
    return(tags$div(class = "alert alert-warning", evpi_result$error))
  }

  tags$div(
    class = "evpi-results",
    h5("Value of Information Analysis"),

    tags$div(
      class = "row",
      tags$div(
        class = "col-md-6",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body",
            h6("EVPI per Patient"),
            tags$h4(sprintf("£%s", format(round(evpi_result$evpi_per_patient, 0), big.mark = ","))),
            tags$p(class = "text-muted", evpi_result$interpretation)
          )
        )
      ),
      tags$div(
        class = "col-md-6",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body",
            h6(sprintf("Population EVPI (%s patients)", format(evpi_result$n_patients, big.mark = ","))),
            tags$h4(sprintf("£%s M", format(round(evpi_result$evpi_population / 1e6, 2), nsmall = 2)))
          )
        )
      )
    ),

    hr(),

    tags$p(
      strong("Optimal decision:"), evpi_result$optimal_arm,
      " at £", format(evpi_result$wtp_threshold, big.mark = ","), "/QALY"
    ),
    tags$p(
      strong("Expected NMB:"), "£", format(round(evpi_result$expected_nmb, 0), big.mark = ",")
    )
  )
}

#' Format budget impact results for display
#'
#' @param bim_result Result from calculate_budget_impact()
#' @return HTML tags
format_bim_display <- function(bim_result) {
  if (!is.null(bim_result$error)) {
    return(tags$div(class = "alert alert-warning", bim_result$error))
  }

  df <- bim_result$yearly_results

  tags$div(
    class = "bim-results",
    h5("Budget Impact Model"),

    # Summary cards
    tags$div(
      class = "row mb-3",
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Total Impact (Discounted)"),
            tags$h4(sprintf("£%s M", format(round(bim_result$total_discounted / 1e6, 2), nsmall = 2)))
          )
        )
      ),
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Average Annual Impact"),
            tags$h4(sprintf("£%s M", format(round(bim_result$summary_stats$avg_annual_impact / 1e6, 2), nsmall = 2)))
          )
        )
      ),
      tags$div(
        class = "col-md-4",
        tags$div(
          class = "card",
          tags$div(
            class = "card-body text-center",
            h6("Peak Year"),
            tags$h4(sprintf("Year %d", bim_result$summary_stats$peak_year))
          )
        )
      )
    ),

    # Yearly breakdown table
    h6("Yearly Breakdown"),
    tags$div(
      class = "table-responsive",
      tags$table(
        class = "table table-striped table-sm",
        tags$thead(
          tags$tr(
            tags$th("Year"),
            tags$th("Patients"),
            tags$th("Market Share"),
            tags$th("Incremental Impact (£M)")
          )
        ),
        tags$tbody(
          lapply(1:nrow(df), function(i) {
            row <- df[i, ]
            tags$tr(
              tags$td(row$year),
              tags$td(format(row$n_patients, big.mark = ",")),
              tags$td(sprintf("%.1f%%", row$market_share * 100)),
              tags$td(sprintf("£%.2f", row$incremental_cost / 1e6))
            )
          })
        )
      )
    )
  )
}
