# =============================================================================
# EVIDENCEOS PRIME - COMPREHENSIVE VALIDATION FRAMEWORK
# =============================================================================
# Purpose: Centralized input validation, error handling, and quality checks
# Quality: Production-ready with comprehensive edge case handling
# Version: 1.0 - Full Implementation
# =============================================================================

#' Validate numeric parameter with bounds checking
#'
#' @param value Numeric value to validate
#' @param param_name Parameter name for error messages
#' @param min_value Minimum allowed value (inclusive)
#' @param max_value Maximum allowed value (inclusive)
#' @param required Whether parameter is required (cannot be NULL/NA)
#' @param allow_zero Whether zero is an acceptable value
#' @return Validated numeric value or error
#' @export
validate_numeric <- function(value, param_name, min_value = -Inf, max_value = Inf,
                             required = TRUE, allow_zero = TRUE) {

  # Check if required
  if (required && (is.null(value) || length(value) == 0)) {
    stop(paste0("Parameter '", param_name, "' is required but was not provided."))
  }

  # Allow NULL for optional parameters
  if (!required && is.null(value)) {
    return(NULL)
  }

  # Check if numeric
  if (!is.numeric(value)) {
    stop(paste0("Parameter '", param_name, "' must be numeric. Received type: ", class(value)[1]))
  }

  # Check for NA
  if (any(is.na(value))) {
    stop(paste0("Parameter '", param_name, "' contains NA values."))
  }

  # Check for infinite values
  if (any(is.infinite(value))) {
    stop(paste0("Parameter '", param_name, "' contains infinite values."))
  }

  # Check zero constraint
  if (!allow_zero && any(value == 0)) {
    stop(paste0("Parameter '", param_name, "' cannot be zero."))
  }

  # Check bounds
  if (any(value < min_value)) {
    stop(paste0("Parameter '", param_name, "' must be >= ", min_value,
                ". Received minimum value: ", min(value)))
  }

  if (any(value > max_value)) {
    stop(paste0("Parameter '", param_name, "' must be <= ", max_value,
                ". Received maximum value: ", max(value)))
  }

  return(value)
}

#' Validate probability parameter
#'
#' @param value Probability value to validate
#' @param param_name Parameter name for error messages
#' @param required Whether parameter is required
#' @return Validated probability in [0, 1]
#' @export
validate_probability <- function(value, param_name, required = TRUE) {
  value <- validate_numeric(value, param_name, min_value = 0, max_value = 1,
                           required = required, allow_zero = TRUE)
  return(value)
}

#' Validate hazard ratio parameter
#'
#' @param value Hazard ratio to validate
#' @param param_name Parameter name for error messages
#' @param required Whether parameter is required
#' @return Validated HR (must be positive)
#' @export
validate_hazard_ratio <- function(value, param_name, required = TRUE) {
  value <- validate_numeric(value, param_name, min_value = 0, max_value = Inf,
                           required = required, allow_zero = FALSE)

  # Warning for extreme values
  if (!is.null(value)) {
    if (any(value < 0.1)) {
      warning(paste0("Parameter '", param_name, "' has HR < 0.1 (very strong protective effect). ",
                    "Please verify this is correct."))
    }
    if (any(value > 10)) {
      warning(paste0("Parameter '", param_name, "' has HR > 10 (very strong harmful effect). ",
                    "Please verify this is correct."))
    }
  }

  return(value)
}

#' Validate utility parameter
#'
#' @param value Utility value to validate
#' @param param_name Parameter name for error messages
#' @param required Whether parameter is required
#' @param nice_compliant Whether to check NICE EQ-5D requirements
#' @param utility_source Source of utility values (e.g., "EQ-5D-3L", "EQ-5D-5L", "SF-6D", "HUI3")
#' @return Validated utility in [0, 1]
#' @export
validate_utility <- function(value, param_name, required = TRUE,
                             nice_compliant = FALSE, utility_source = NULL) {
  value <- validate_probability(value, param_name, required)

  # Warning for unusual values
  if (!is.null(value)) {
    if (any(value > 0.95)) {
      message(paste0("Note: ", param_name, " is very high (>0.95). ",
                    "Verify this represents a near-perfect health state."))
    }
  }

  # NICE compliance: Check for EQ-5D source
  if (nice_compliant && !is.null(utility_source)) {
    valid_eq5d_sources <- c("EQ-5D-3L", "EQ-5D-5L", "EQ-5D", "EQ5D")

    if (!utility_source %in% valid_eq5d_sources) {
      warning(paste0("NICE Reference Case requires EQ-5D-based utilities. ",
                    "Received source: '", utility_source, "'. ",
                    "If using mapped utilities, provide justification in submission."))
    }
  }

  return(value)
}

#' Validate utility sources for all health states (NICE-specific)
#'
#' @param params Parameter list to validate
#' @param nice_compliant Whether to enforce NICE reference case
#' @return Validated params with utility_source metadata
#' @export
validate_utility_sources <- function(params, nice_compliant = FALSE) {

  # Check if utility_source is provided
  if (is.null(params$utility_source)) {
    if (nice_compliant) {
      stop(paste0("NICE Reference Case requires documenting utility sources. ",
                 "Please provide 'utility_source' parameter (e.g., 'EQ-5D-3L', 'EQ-5D-5L'). ",
                 "This should specify the preference-based measure used."))
    } else {
      message("Note: No utility_source specified. For NICE submissions, document the source (e.g., EQ-5D-3L).")
      params$utility_source <- "unspecified"
    }
  }

  # Validate against NICE requirements
  if (nice_compliant) {
    valid_eq5d <- c("EQ-5D-3L", "EQ-5D-5L", "EQ-5D", "EQ5D")

    if (!params$utility_source %in% valid_eq5d) {
      # Allow with strong warning for mapped utilities
      if (grepl("mapped|derived|estimated", params$utility_source, ignore.case = TRUE)) {
        warning(paste0("Using mapped/derived utilities from: ", params$utility_source, ". ",
                      "NICE Reference Case prefers directly measured EQ-5D. ",
                      "Provide justification for mapping approach in submission."))
      } else {
        warning(paste0("NICE Reference Case requires EQ-5D-based utilities. ",
                      "Received: '", params$utility_source, "'. ",
                      "Valid options: ", paste(valid_eq5d, collapse = ", "), ". ",
                      "If using alternative measures, provide strong justification."))
      }
    } else {
      message(paste0("✓ Using EQ-5D utilities (source: ", params$utility_source, ")"))
    }

    # Check for UK population tariff
    if (is.null(params$utility_tariff)) {
      message("Note: Consider specifying 'utility_tariff' (e.g., 'UK_crosswalk', 'UK_TTO') for transparency.")
      params$utility_tariff <- "unspecified"
    }
  }

  return(params)
}

#' Validate cost parameter
#'
#' @param value Cost value to validate
#' @param param_name Parameter name for error messages
#' @param required Whether parameter is required
#' @param max_reasonable Maximum reasonable cost (for warnings)
#' @return Validated cost (must be non-negative)
#' @export
validate_cost <- function(value, param_name, required = TRUE, max_reasonable = 1000000) {
  value <- validate_numeric(value, param_name, min_value = 0, max_value = Inf,
                           required = required, allow_zero = TRUE)

  # Warning for very high costs
  if (!is.null(value) && any(value > max_reasonable)) {
    warning(paste0("Parameter '", param_name, "' exceeds £", format(max_reasonable, big.mark = ","),
                  ". Maximum value: £", format(max(value), big.mark = ","),
                  ". Please verify this is correct."))
  }

  return(value)
}

#' Validate time horizon
#'
#' @param value Time horizon to validate
#' @param param_name Parameter name for error messages
#' @param min_cycles Minimum number of cycles
#' @param max_cycles Maximum number of cycles
#' @return Validated time horizon (integer)
#' @export
validate_time_horizon <- function(value, param_name = "time_horizon",
                                  min_cycles = 1, max_cycles = 100) {
  value <- validate_numeric(value, param_name, min_value = min_cycles,
                           max_value = max_cycles, required = TRUE, allow_zero = FALSE)

  # Must be integer
  if (value != round(value)) {
    stop(paste0("Parameter '", param_name, "' must be an integer. Received: ", value))
  }

  return(as.integer(value))
}

#' Validate discount rate (NICE-compliant)
#'
#' @param value Discount rate to validate
#' @param param_name Parameter name for error messages
#' @param nice_compliant Whether to enforce NICE reference case rates
#' @param rate_type Type of rate: "costs" or "health" (for NICE differential discounting)
#' @return Validated discount rate in [0, 0.2]
#' @export
validate_discount_rate <- function(value, param_name = "discount_rate",
                                   nice_compliant = FALSE,
                                   rate_type = NULL) {
  value <- validate_numeric(value, param_name, min_value = 0, max_value = 0.2,
                           required = TRUE, allow_zero = TRUE)

  # NICE compliance checks
  if (nice_compliant) {
    if (!is.null(rate_type)) {
      if (rate_type == "costs" && abs(value - 0.035) > 0.001) {
        stop(paste0("NICE Reference Case requires 3.5% discount rate for costs. ",
                   "Received: ", value * 100, "%"))
      }
      if (rate_type == "health" && abs(value - 0.015) > 0.001) {
        stop(paste0("NICE Reference Case requires 1.5% discount rate for health effects. ",
                   "Received: ", value * 100, "%"))
      }
    }
  }

  # Warning for unusual values
  if (!nice_compliant && value > 0.1) {
    warning(paste0("Discount rate of ", value * 100, "% is higher than typical NICE guidance. ",
                  "Please verify this is appropriate for your jurisdiction."))
  }

  return(value)
}

#' Validate differential discounting parameters (NICE-specific)
#'
#' @param params Parameter list to validate
#' @param nice_compliant Whether to enforce NICE reference case
#' @return Validated params with discount_rate_costs and discount_rate_health
#' @export
validate_differential_discounting <- function(params, nice_compliant = FALSE) {

  # Check if using new differential discounting or old single rate
  has_differential <- !is.null(params$discount_rate_costs) || !is.null(params$discount_rate_health)
  has_single <- !is.null(params$discount_rate)

  if (has_differential) {
    # Using differential discounting (NICE Reference Case)
    if (is.null(params$discount_rate_costs)) {
      stop("When using differential discounting, 'discount_rate_costs' is required")
    }
    if (is.null(params$discount_rate_health)) {
      stop("When using differential discounting, 'discount_rate_health' is required")
    }

    params$discount_rate_costs <- validate_discount_rate(
      params$discount_rate_costs,
      "discount_rate_costs",
      nice_compliant = nice_compliant,
      rate_type = "costs"
    )

    params$discount_rate_health <- validate_discount_rate(
      params$discount_rate_health,
      "discount_rate_health",
      nice_compliant = nice_compliant,
      rate_type = "health"
    )

    # Set single rate to NULL to avoid confusion
    params$discount_rate <- NULL

    message(paste0("✓ Using differential discounting: ",
                  params$discount_rate_costs * 100, "% (costs), ",
                  params$discount_rate_health * 100, "% (health effects)"))

  } else if (has_single) {
    # Using single discount rate (legacy/non-NICE)
    params$discount_rate <- validate_discount_rate(params$discount_rate, "discount_rate")

    if (nice_compliant) {
      warning(paste0("NICE Reference Case requires differential discounting. ",
                    "Converting single rate (", params$discount_rate * 100,
                    "%) to NICE-compliant rates (3.5% costs, 1.5% health)."))
      params$discount_rate_costs <- 0.035
      params$discount_rate_health <- 0.015
      params$discount_rate <- NULL
    } else {
      # Use same rate for both
      params$discount_rate_costs <- params$discount_rate
      params$discount_rate_health <- params$discount_rate
      message(paste0("Note: Using single discount rate (", params$discount_rate * 100,
                    "%) for both costs and health effects. ",
                    "Consider using differential discounting for NICE submissions."))
    }
  } else {
    stop("Either 'discount_rate' or both 'discount_rate_costs' and 'discount_rate_health' must be provided")
  }

  return(params)
}

#' Validate cost perspective (NICE-specific)
#'
#' @param params Parameter list to validate
#' @param nice_compliant Whether to enforce NICE reference case
#' @return Validated params with cost_perspective set
#' @export
validate_cost_perspective <- function(params, nice_compliant = FALSE) {

  # Default to NHS/PSS for NICE compliance
  if (is.null(params$cost_perspective)) {
    if (nice_compliant) {
      params$cost_perspective <- "NHS_PSS"
      message("✓ Using NHS/PSS perspective (NICE Reference Case default)")
    } else {
      params$cost_perspective <- "NHS_PSS"
      message("Note: Defaulting to NHS/PSS perspective. Specify 'cost_perspective' explicitly if needed.")
    }
  }

  # Validate perspective value
  valid_perspectives <- c("NHS_PSS", "NHS", "PSS", "societal", "payer", "healthcare_system")

  if (!params$cost_perspective %in% valid_perspectives) {
    stop(paste0("Invalid cost_perspective: '", params$cost_perspective, "'. ",
               "Valid options: ", paste(valid_perspectives, collapse = ", ")))
  }

  # NICE compliance check
  if (nice_compliant) {
    if (params$cost_perspective != "NHS_PSS") {
      stop(paste0("NICE Reference Case requires NHS/PSS perspective. ",
                 "Received: '", params$cost_perspective, "'"))
    }

    # Check for productivity costs (not allowed in NHS/PSS)
    productivity_cost_params <- c("cost_productivity_loss", "cost_absenteeism",
                                  "cost_presenteeism", "cost_caregiver_time",
                                  "cost_lost_earnings")

    found_productivity <- intersect(productivity_cost_params, names(params))

    if (length(found_productivity) > 0) {
      warning(paste0("NHS/PSS perspective detected productivity costs: ",
                    paste(found_productivity, collapse = ", "), ". ",
                    "These costs should be excluded from base case and presented in scenario analysis only. ",
                    "Consider setting these to 0 or removing them."))
    }
  }

  # Warning for non-NHS/PSS perspectives
  if (!nice_compliant && params$cost_perspective != "NHS_PSS") {
    message(paste0("Note: Using '", params$cost_perspective, "' perspective. ",
                  "NICE requires NHS/PSS perspective for UK submissions."))
  }

  return(params)
}

#' Validate WTP threshold
#'
#' @param value WTP threshold to validate
#' @param param_name Parameter name for error messages
#' @return Validated WTP threshold
#' @export
validate_wtp_threshold <- function(value, param_name = "wtp_threshold") {
  value <- validate_numeric(value, param_name, min_value = 0, max_value = Inf,
                           required = TRUE, allow_zero = FALSE)

  # Informational message about common thresholds
  if (value < 10000) {
    message(paste0("WTP threshold of £", format(value, big.mark = ","),
                  " is below typical NICE thresholds (£20,000-£30,000)."))
  } else if (value > 100000) {
    message(paste0("WTP threshold of £", format(value, big.mark = ","),
                  " is above typical NICE thresholds (£20,000-£30,000)."))
  }

  return(value)
}

#' Validate PSA parameters
#'
#' @param n_sim Number of simulations
#' @param param_name Parameter name
#' @return Validated number of simulations
#' @export
validate_psa_sims <- function(n_sim, param_name = "n_sim") {
  n_sim <- validate_numeric(n_sim, param_name, min_value = 100, max_value = 100000,
                            required = TRUE, allow_zero = FALSE)

  n_sim <- as.integer(n_sim)

  # Performance warnings
  if (n_sim > 10000) {
    message(paste0("Running PSA with ", format(n_sim, big.mark = ","),
                  " simulations. This may take several minutes."))
  }

  # Recommendation for precision
  if (n_sim < 1000) {
    warning(paste0("PSA with only ", n_sim, " simulations may have high Monte Carlo error. ",
                  "Consider using at least 1,000 simulations for stable results."))
  }

  return(n_sim)
}

#' Validate Markov trace matrix
#'
#' @param trace Markov trace matrix
#' @param param_name Parameter name for error messages
#' @param tolerance Tolerance for row sum validation
#' @return TRUE if valid, error otherwise
#' @export
validate_markov_trace <- function(trace, param_name = "trace", tolerance = 0.001) {

  # Check if matrix
  if (!is.matrix(trace)) {
    stop(paste0("Parameter '", param_name, "' must be a matrix."))
  }

  # Check dimensions
  if (nrow(trace) < 2) {
    stop(paste0("Parameter '", param_name, "' must have at least 2 rows (time points)."))
  }

  if (ncol(trace) < 2) {
    stop(paste0("Parameter '", param_name, "' must have at least 2 columns (states)."))
  }

  # Check for NA or infinite values
  if (any(is.na(trace))) {
    stop(paste0("Parameter '", param_name, "' contains NA values."))
  }

  if (any(is.infinite(trace))) {
    stop(paste0("Parameter '", param_name, "' contains infinite values."))
  }

  # Check bounds [0, 1]
  if (any(trace < 0)) {
    stop(paste0("Parameter '", param_name, "' contains negative values (probabilities must be in [0,1])."))
  }

  if (any(trace > 1)) {
    stop(paste0("Parameter '", param_name, "' contains values > 1 (probabilities must be in [0,1])."))
  }

  # Check row sums equal 1
  row_sums <- rowSums(trace)
  if (any(abs(row_sums - 1.0) > tolerance)) {
    bad_rows <- which(abs(row_sums - 1.0) > tolerance)
    stop(paste0("Parameter '", param_name, "' has rows that don't sum to 1.0. ",
                "First problematic row: ", bad_rows[1],
                " (sum = ", round(row_sums[bad_rows[1]], 6), ")"))
  }

  return(TRUE)
}

#' Validate survival data for PSM
#'
#' @param data Survival data frame
#' @return TRUE if valid, error otherwise
#' @export
validate_survival_data <- function(data) {

  # Required columns
  required_cols <- c("time", "event")
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    stop(paste0("Survival data missing required columns: ",
                paste(missing_cols, collapse = ", ")))
  }

  # Validate time
  if (any(data$time < 0, na.rm = TRUE)) {
    stop("Survival time cannot be negative.")
  }

  if (any(is.na(data$time))) {
    stop("Survival time contains NA values.")
  }

  # Validate event (must be 0 or 1)
  unique_events <- unique(data$event[!is.na(data$event)])
  if (!all(unique_events %in% c(0, 1))) {
    stop(paste0("Event indicator must be 0 (censored) or 1 (event occurred). ",
                "Found values: ", paste(unique_events, collapse = ", ")))
  }

  # Check for sufficient events
  n_events <- sum(data$event == 1, na.rm = TRUE)
  if (n_events < 10) {
    warning(paste0("Only ", n_events, " events observed. ",
                  "Parametric survival models may be unstable with few events. ",
                  "Consider using more data or simpler models."))
  }

  # Check for sufficient follow-up
  max_time <- max(data$time, na.rm = TRUE)
  if (max_time < 1) {
    warning("Maximum follow-up time is less than 1 unit. Verify time scale is appropriate.")
  }

  return(TRUE)
}

#' Safe wrapper for model execution with comprehensive error handling
#'
#' @param expr Expression to evaluate
#' @param error_message Custom error message
#' @param progress_message Progress message to display
#' @return Result of expression or error list
#' @export
safe_execute <- function(expr, error_message = "An error occurred",
                        progress_message = NULL) {

  if (!is.null(progress_message)) {
    message(progress_message)
  }

  tryCatch({
    result <- eval(expr, envir = parent.frame())

    # Check if result is NULL
    if (is.null(result)) {
      warning(paste0(error_message, ": Result is NULL"))
    }

    return(result)

  }, error = function(e) {
    error_details <- list(
      success = FALSE,
      error_message = error_message,
      technical_details = as.character(e),
      timestamp = Sys.time()
    )

    warning(paste0(error_message, ": ", e$message))

    return(error_details)
  })
}

#' Format number for display
#'
#' @param value Numeric value
#' @param digits Number of decimal places
#' @param big_mark Thousands separator
#' @param prefix Prefix (e.g., "£" for currency)
#' @return Formatted string
#' @export
format_number <- function(value, digits = 0, big_mark = ",", prefix = "") {
  if (is.na(value) || is.null(value) || !is.finite(value)) {
    return("N/A")
  }

  formatted <- format(round(value, digits), big.mark = big_mark, nsmall = digits)
  paste0(prefix, formatted)
}

#' Format ICER for display
#'
#' @param icer ICER value
#' @return Formatted ICER string
#' @export
format_icer <- function(icer) {
  if (is.na(icer) || is.null(icer)) {
    return("N/A")
  }

  if (!is.finite(icer)) {
    return("Dominated/Dominates")
  }

  if (icer < 0) {
    return("Cost-saving")
  }

  paste0("£", format(round(icer), big.mark = ","), "/QALY")
}

#' Check for package availability and install if missing
#'
#' @param package_name Package name
#' @param quiet Suppress messages
#' @return TRUE if available, FALSE otherwise
#' @export
ensure_package <- function(package_name, quiet = FALSE) {
  if (!requireNamespace(package_name, quietly = TRUE)) {
    if (!quiet) {
      message(paste0("Package '", package_name, "' not found. ",
                    "Some functionality may be limited."))
    }
    return(FALSE)
  }
  return(TRUE)
}

#' Validate model results structure
#'
#' @param results Model results object
#' @param required_fields Required fields in results
#' @return TRUE if valid, error otherwise
#' @export
validate_model_results <- function(results, required_fields = c("icer", "inc_costs", "inc_qalys")) {

  if (is.null(results)) {
    stop("Model results object is NULL.")
  }

  if (!is.list(results)) {
    stop("Model results must be a list object.")
  }

  # Check required fields
  missing_fields <- setdiff(required_fields, names(results))

  if (length(missing_fields) > 0) {
    stop(paste0("Model results missing required fields: ",
                paste(missing_fields, collapse = ", ")))
  }

  # Validate key numeric fields
  if (!is.null(results$icer) && !is.finite(results$icer)) {
    warning("ICER is not finite. Check for division by zero or negative QALYs.")
  }

  return(TRUE)
}

#' Create progress message with timestamp
#'
#' @param message Message to display
#' @param level Message level (info, warning, error)
#' @export
log_progress <- function(message, level = "info") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level,
                  "info" = "ℹ",
                  "warning" = "⚠",
                  "error" = "✖",
                  "success" = "✓",
                  "▶")

  cat(paste0("[", timestamp, "] ", prefix, " ", message, "\n"))
}
