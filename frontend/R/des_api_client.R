"""
DES API Client for R

R6 class providing easy access to Discrete Event Simulation API endpoints.

Features:
- Run simulations
- Probabilistic sensitivity analysis (PSA)
- Compare interventions
- Get example models
- Full error handling and logging

Usage:
    library(R6)
    library(httr)
    library(jsonlite)

    # Create client
    client <- DESClient$new(
      base_url = "http://localhost:8000",
      token = "your-jwt-token"
    )

    # Run simulation
    results <- client$run_simulation(
      pathway = list(
        pathway_id = "standard_care",
        pathway_name = "Standard Care",
        states = list(...),
        initial_state = "healthy"
      ),
      config = list(
        time_horizon = 10,
        n_patients = 1000
      )
    )

    # Get example model
    example <- client$get_example_model("3_state_model")
"""

library(R6)
library(httr)
library(jsonlite)

# DES API Client Class
DESClient <- R6Class(
  "DESClient",

  public = list(
    base_url = NULL,
    token = NULL,

    #' Initialize DES API client
    #'
    #' @param base_url Base URL of API (default: http://localhost:8000)
    #' @param token JWT authentication token
    initialize = function(base_url = "http://localhost:8000", token = NULL) {
      self$base_url <- paste0(base_url, "/api/des")
      self$token <- token

      message("✓ DES API client initialized: ", self$base_url)
    },

    #' Make HTTP request
    #'
    #' @param method HTTP method (GET or POST)
    #' @param endpoint API endpoint path
    #' @param body Request body (for POST)
    #' @return Parsed response
    .request = function(method, endpoint, body = NULL) {
      url <- paste0(self$base_url, endpoint)

      # Prepare headers
      headers <- add_headers(
        "Content-Type" = "application/json"
      )

      if (!is.null(self$token)) {
        headers <- add_headers(
          "Content-Type" = "application/json",
          "Authorization" = paste("Bearer", self$token)
        )
      }

      # Make request
      tryCatch({
        if (method == "GET") {
          response <- GET(url, headers, timeout(120))
        } else {
          response <- POST(
            url,
            headers,
            body = toJSON(body, auto_unbox = TRUE, null = "null"),
            encode = "raw",
            timeout(300)  # 5 minutes for long simulations
          )
        }

        # Check status
        if (status_code(response) >= 400) {
          error_content <- content(response, "text", encoding = "UTF-8")
          stop(sprintf("API error %d: %s", status_code(response), error_content))
        }

        # Parse response
        result <- content(response, "parsed", encoding = "UTF-8")
        return(result)

      }, error = function(e) {
        stop(sprintf("Request failed: %s", e$message))
      })
    },

    #' Run discrete event simulation
    #'
    #' @param pathway Patient pathway configuration
    #' @param config Simulation configuration
    #' @param resources Optional list of healthcare resources
    #' @return Simulation results
    #'
    #' @examples
    #' results <- client$run_simulation(
    #'   pathway = list(
    #'     pathway_id = "standard_care",
    #'     pathway_name = "Standard Care",
    #'     states = list(
    #'       list(state_id = "healthy", state_name = "Healthy",
    #'            utility = 1.0, cost_per_cycle = 100,
    #'            transition_probabilities = list(disease = 0.05, death = 0.01)),
    #'       list(state_id = "disease", state_name = "Disease",
    #'            utility = 0.7, cost_per_cycle = 5000,
    #'            transition_probabilities = list(death = 0.10)),
    #'       list(state_id = "death", state_name = "Death",
    #'            utility = 0.0, cost_per_cycle = 0, absorbing = TRUE)
    #'     ),
    #'     initial_state = "healthy",
    #'     time_horizon = 10
    #'   ),
    #'   config = list(
    #'     time_horizon = 10,
    #'     n_patients = 1000,
    #'     discount_rate_costs = 0.035,
    #'     discount_rate_qalys = 0.035,
    #'     willingness_to_pay = 30000
    #'   )
    #' )
    run_simulation = function(pathway, config, resources = NULL) {
      message("🚀 Running DES simulation...")

      body <- list(
        pathway = pathway,
        config = config
      )

      if (!is.null(resources)) {
        body$resources <- resources
      }

      result <- self$.request("POST", "/run", body)

      message(sprintf(
        "✓ Simulation complete: £%s, %.2f QALYs",
        format(result$total_costs, big.mark = ","),
        result$total_qalys
      ))

      return(result)
    },

    #' Run probabilistic sensitivity analysis
    #'
    #' @param pathway Patient pathway configuration
    #' @param config Simulation configuration (must include n_psa_iterations)
    #' @param resources Optional list of resources
    #' @return PSA results with mean, CI, and iterations
    #'
    #' @examples
    #' psa <- client$run_psa(
    #'   pathway = pathway,
    #'   config = list(
    #'     time_horizon = 10,
    #'     n_patients = 1000,
    #'     n_psa_iterations = 100
    #'   )
    #' )
    run_psa = function(pathway, config, resources = NULL) {
      message(sprintf("🎲 Running PSA: %d iterations...", config$n_psa_iterations))

      body <- list(
        pathway = pathway,
        config = config
      )

      if (!is.null(resources)) {
        body$resources <- resources
      }

      result <- self$.request("POST", "/run-psa", body)

      message(sprintf(
        "✓ PSA complete: Mean cost = £%s, Mean QALYs = %.2f, P(CE) = %.1f%%",
        format(result$mean_cost, big.mark = ","),
        result$mean_qalys,
        result$probability_cost_effective * 100
      ))

      return(result)
    },

    #' Compare multiple interventions
    #'
    #' @param pathways List of patient pathways to compare
    #' @param config Simulation configuration
    #' @param comparator_index Index of comparator pathway (default: 0)
    #' @return Comparison results with ICERs and decisions
    #'
    #' @examples
    #' comparison <- client$compare_interventions(
    #'   pathways = list(standard_care, intervention_a, intervention_b),
    #'   config = config,
    #'   comparator_index = 0
    #' )
    compare_interventions = function(pathways, config, comparator_index = 0) {
      message(sprintf("📊 Comparing %d interventions...", length(pathways)))

      body <- list(
        pathways = pathways,
        config = config,
        comparator_index = comparator_index
      )

      result <- self$.request("POST", "/compare-interventions", body)

      message("✓ Comparison complete")

      return(result)
    },

    #' Get system status
    #'
    #' @return System capabilities and configuration
    get_status = function() {
      result <- self$.request("GET", "/status", NULL)
      return(result)
    },

    #' List available example models
    #'
    #' @return List of example models with metadata
    list_examples = function() {
      result <- self$.request("GET", "/examples", NULL)
      return(result)
    },

    #' Get example model
    #'
    #' @param model_id Model identifier (3_state_model, 5_state_cancer, etc.)
    #' @return Pathway and config ready to use
    #'
    #' @examples
    #' # Get simple 3-state model
    #' example <- client$get_example_model("3_state_model")
    #' results <- client$run_simulation(example$pathway, example$config)
    get_example_model = function(model_id) {
      # This needs to be implemented on R side since Python examples
      # use internal models. For now, return pre-configured examples

      if (model_id == "3_state_model") {
        return(list(
          pathway = list(
            pathway_id = "3_state_model",
            pathway_name = "Simple 3-State Model",
            states = list(
              list(
                state_id = "healthy",
                state_name = "Healthy",
                utility = 1.0,
                cost_per_cycle = 100,
                transition_probabilities = list(disease = 0.05, death = 0.01)
              ),
              list(
                state_id = "disease",
                state_name = "Disease",
                utility = 0.7,
                cost_per_cycle = 5000,
                transition_probabilities = list(death = 0.10)
              ),
              list(
                state_id = "death",
                state_name = "Death",
                utility = 0.0,
                cost_per_cycle = 0,
                absorbing = TRUE
              )
            ),
            initial_state = "healthy",
            time_horizon = 10
          ),
          config = list(
            time_horizon = 10,
            n_patients = 1000,
            discount_rate_costs = 0.035,
            discount_rate_qalys = 0.035,
            willingness_to_pay = 30000
          )
        ))
      }

      stop(sprintf("Unknown model_id: %s", model_id))
    }
  )
)


# Helper Functions

#' Create DES client with authentication
#'
#' @param base_url API base URL
#' @param username Username for authentication
#' @param password Password for authentication
#' @return Authenticated DES client
#'
#' @export
create_des_client <- function(base_url = "http://localhost:8000",
                               username = NULL,
                               password = NULL) {
  token <- NULL

  if (!is.null(username) && !is.null(password)) {
    # Authenticate
    response <- POST(
      paste0(base_url, "/api/auth/login"),
      body = list(username = username, password = password),
      encode = "json"
    )

    if (status_code(response) == 200) {
      auth_data <- content(response, "parsed")
      token <- auth_data$token$access_token
      message("✓ Authenticated successfully")
    } else {
      warning("Authentication failed, using unauthenticated client")
    }
  }

  DESClient$new(base_url = base_url, token = token)
}


#' Format simulation results as data frame
#'
#' @param results Simulation results from run_simulation()
#' @return Data frame with results
#'
#' @export
format_simulation_results <- function(results) {
  data.frame(
    metric = c("Total Cost", "Total QALYs", "Total Patients", "Simulation Time"),
    value = c(
      sprintf("£%s", format(results$total_costs, big.mark = ",")),
      sprintf("%.2f", results$total_qalys),
      results$total_patients,
      sprintf("%.1f years", results$simulation_time)
    ),
    stringsAsFactors = FALSE
  )
}


#' Format state occupancy as data frame
#'
#' @param results Simulation results
#' @return Data frame with state occupancy percentages
#'
#' @export
format_state_occupancy <- function(results) {
  occupancy <- results$state_occupancy

  data.frame(
    state = names(occupancy),
    occupancy = unlist(occupancy),
    percentage = sprintf("%.1f%%", unlist(occupancy) * 100),
    stringsAsFactors = FALSE
  )
}


#' Format comparison results as data frame
#'
#' @param comparison Comparison results from compare_interventions()
#' @return Data frame with ICERs and decisions
#'
#' @export
format_comparison_results <- function(comparison) {
  comparisons <- comparison$comparisons

  do.call(rbind, lapply(comparisons, function(comp) {
    data.frame(
      intervention = comp$pathway_name,
      cost = sprintf("£%s", format(comp$total_costs, big.mark = ",")),
      qalys = sprintf("%.2f", comp$total_qalys),
      inc_cost = sprintf("£%s", format(comp$incremental_costs, big.mark = ",")),
      inc_qalys = sprintf("%.2f", comp$incremental_qalys),
      icer = if (!is.null(comp$icer)) sprintf("£%s", format(comp$icer, big.mark = ",")) else "—",
      decision = comp$decision,
      stringsAsFactors = FALSE
    )
  }))
}


# Example usage
if (FALSE) {
  # Load required libraries
  library(R6)
  library(httr)
  library(jsonlite)

  # Create client
  client <- create_des_client(
    base_url = "http://localhost:8000",
    username = "admin",
    password = "admin-password"
  )

  # Get example model
  example <- client$get_example_model("3_state_model")

  # Run simulation
  results <- client$run_simulation(example$pathway, example$config)

  # View results
  print(format_simulation_results(results))
  print(format_state_occupancy(results))

  # Run PSA
  psa_config <- example$config
  psa_config$n_psa_iterations <- 100

  psa <- client$run_psa(example$pathway, psa_config)

  # View PSA results
  cat(sprintf("Mean cost: £%s (95%% CI: £%s - £%s)\n",
              format(psa$mean_cost, big.mark = ","),
              format(psa$cost_95ci_lower, big.mark = ","),
              format(psa$cost_95ci_upper, big.mark = ",")))

  cat(sprintf("Mean QALYs: %.2f (95%% CI: %.2f - %.2f)\n",
              psa$mean_qalys,
              psa$qalys_95ci_lower,
              psa$qalys_95ci_upper))

  cat(sprintf("Probability cost-effective: %.1f%%\n",
              psa$probability_cost_effective * 100))
}
