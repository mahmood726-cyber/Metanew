# Validation Utilities
# R-based validation functions (fallback if Python API unavailable)

validate_required_columns <- function(data, required) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(paste("Missing required columns:", paste(missing, collapse = ", ")))
  }
  TRUE
}

validate_numeric_column <- function(data, column, min_val = NULL, max_val = NULL) {
  if (!column %in% names(data)) {
    return(FALSE)
  }

  values <- data[[column]]
  if (!is.numeric(values)) {
    warning(paste(column, "is not numeric"))
    return(FALSE)
  }

  if (!is.null(min_val) && any(values < min_val, na.rm = TRUE)) {
    warning(paste(column, "contains values below", min_val))
    return(FALSE)
  }

  if (!is.null(max_val) && any(values > max_val, na.rm = TRUE)) {
    warning(paste(column, "contains values above", max_val))
    return(FALSE)
  }

  TRUE
}

validate_effect_size_data <- function(data) {
  errors <- c()

  if (!all(c("yi", "sei") %in% names(data))) {
    errors <- c(errors, "Missing yi or sei columns")
  }

  if ("sei" %in% names(data)) {
    if (any(data$sei <= 0, na.rm = TRUE)) {
      errors <- c(errors, "Standard errors must be positive")
    }
  }

  if (length(errors) > 0) {
    stop(paste(errors, collapse = "; "))
  }

  TRUE
}

validate_binary_data <- function(data) {
  errors <- c()

  if ("events" %in% names(data) && "n" %in% names(data)) {
    if (any(data$events > data$n, na.rm = TRUE)) {
      errors <- c(errors, "Events cannot exceed n")
    }
    if (any(data$events < 0, na.rm = TRUE)) {
      errors <- c(errors, "Events must be non-negative")
    }
  }

  if (length(errors) > 0) {
    stop(paste(errors, collapse = "; "))
  }

  TRUE
}

check_missing_data <- function(data, warn = TRUE) {
  missing_summary <- sapply(data, function(col) sum(is.na(col)))
  missing_pct <- 100 * missing_summary / nrow(data)

  if (warn && any(missing_pct > 20)) {
    high_missing <- names(missing_pct)[missing_pct > 20]
    warning(paste("High missing data (>20%) in columns:",
                  paste(high_missing, collapse = ", ")))
  }

  list(
    count = missing_summary,
    percent = missing_pct
  )
}
