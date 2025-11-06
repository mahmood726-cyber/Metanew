# Data Validation and Preprocessing Utility
# Intelligent validation and automatic fixing of uploaded data
# Handles column renaming, missing data, structure validation
#
# Author: EvidenceOS PRIME
# Purpose: Make data upload user-friendly for non-R users

library(dplyr)
library(stringr)

# ============================================================================
# COLUMN NAME VALIDATION AND AUTO-FIXING
# ============================================================================

#' Clean and standardize column names to R-compatible format
#' @param df Data frame to clean
#' @param expected_columns Optional vector of expected column names
#' @return List with cleaned data and messages
clean_column_names <- function(df, expected_columns = NULL) {

  messages <- list()
  warnings <- list()
  original_names <- names(df)

  # Step 1: Basic cleaning (spaces, special characters)
  clean_names <- names(df) %>%
    # Replace spaces with underscores
    str_replace_all(" ", "_") %>%
    # Replace dots with underscores
    str_replace_all("\\.", "_") %>%
    # Remove special characters
    str_replace_all("[^A-Za-z0-9_]", "") %>%
    # Ensure starts with letter
    str_replace("^([0-9])", "X\\1") %>%
    # Convert to lowercase for consistency
    tolower()

  # Step 2: Check for duplicates and make unique
  if (any(duplicated(clean_names))) {
    warnings <- c(warnings, "Some column names were duplicated and have been made unique")
    clean_names <- make.unique(clean_names, sep = "_")
  }

  # Step 3: Apply standardized names if mapping is obvious
  # Common meta-analysis column patterns
  ma_patterns <- list(
    study_id = c("study", "studyid", "study_id", "id", "study_name", "studyname"),
    effect_size = c("effect", "es", "effect_size", "effectsize", "estimate", "mean_difference", "smd"),
    se = c("se", "standard_error", "stderr", "std_err", "standard_err"),
    ci_lower = c("ci_lower", "ci_low", "lower", "lb", "lci", "lower_ci"),
    ci_upper = c("ci_upper", "ci_high", "upper", "ub", "uci", "upper_ci"),
    n = c("n", "sample_size", "samplesize", "total_n", "totaln"),
    n1 = c("n1", "n_treat", "n_treatment", "n_intervention"),
    n2 = c("n2", "n_ctrl", "n_control", "n_placebo"),
    mean1 = c("mean1", "m1", "mean_treat", "mean_treatment"),
    mean2 = c("mean2", "m2", "mean_ctrl", "mean_control"),
    sd1 = c("sd1", "s1", "sd_treat", "sd_treatment"),
    sd2 = c("sd2", "s2", "sd_ctrl", "sd_control"),
    events1 = c("events1", "e1", "n_events_treat", "events_treatment"),
    events2 = c("events2", "e2", "n_events_ctrl", "events_control"),
    year = c("year", "pubyear", "pub_year", "publication_year"),
    author = c("author", "authors", "first_author", "firstauthor")
  )

  # Try to match columns to standard names
  renamed_cols <- clean_names
  for (standard_name in names(ma_patterns)) {
    pattern_matches <- ma_patterns[[standard_name]]
    for (i in seq_along(clean_names)) {
      if (clean_names[i] %in% pattern_matches) {
        if (!(standard_name %in% renamed_cols)) {  # Avoid duplicates
          messages <- c(messages, paste0("Renamed '", original_names[i], "' → '", standard_name, "'"))
          renamed_cols[i] <- standard_name
        }
      }
    }
  }

  # Apply cleaned names
  names(df) <- renamed_cols

  # Check for required columns if specified
  if (!is.null(expected_columns)) {
    missing_cols <- setdiff(expected_columns, names(df))
    if (length(missing_cols) > 0) {
      warnings <- c(warnings, paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
    }
  }

  return(list(
    data = df,
    original_names = original_names,
    new_names = renamed_cols,
    messages = messages,
    warnings = warnings,
    success = length(warnings) == 0
  ))
}

# ============================================================================
# MISSING DATA DETECTION AND HANDLING
# ============================================================================

#' Analyze missing data patterns and provide recommendations
#' @param df Data frame to analyze
#' @return List with missing data analysis and recommendations
analyze_missing_data <- function(df) {

  # Calculate missingness per column
  missing_per_col <- sapply(df, function(x) sum(is.na(x)) / length(x) * 100)

  # Calculate missingness per row
  missing_per_row <- apply(df, 1, function(x) sum(is.na(x)) / length(x) * 100)

  # Overall missingness
  total_cells <- nrow(df) * ncol(df)
  missing_cells <- sum(is.na(df))
  overall_missing_pct <- (missing_cells / total_cells) * 100

  # Identify columns with high missingness
  high_missing_cols <- names(missing_per_col[missing_per_col > 50])
  moderate_missing_cols <- names(missing_per_col[missing_per_col > 20 & missing_per_col <= 50])

  # Identify rows with high missingness
  high_missing_rows <- which(missing_per_row > 50)

  # Recommendations
  recommendations <- list()

  if (overall_missing_pct > 30) {
    recommendations <- c(recommendations,
      paste0("⚠ WARNING: High overall missingness (", round(overall_missing_pct, 1), "%)"))
  }

  if (length(high_missing_cols) > 0) {
    recommendations <- c(recommendations,
      paste0("Consider removing columns: ", paste(high_missing_cols, collapse = ", "),
             " (>50% missing)"))
  }

  if (length(high_missing_rows) > 0) {
    recommendations <- c(recommendations,
      paste0("Consider removing ", length(high_missing_rows),
             " studies with >50% missing data"))
  }

  if (overall_missing_pct > 0 && overall_missing_pct < 20) {
    recommendations <- c(recommendations,
      "✓ Moderate missingness - FIML or multiple imputation recommended")
  }

  if (overall_missing_pct == 0) {
    recommendations <- c(recommendations, "✓ No missing data detected")
  }

  return(list(
    overall_pct = overall_missing_pct,
    missing_per_col = missing_per_col,
    missing_per_row = missing_per_row,
    high_missing_cols = high_missing_cols,
    moderate_missing_cols = moderate_missing_cols,
    high_missing_rows = high_missing_rows,
    recommendations = recommendations,
    action_needed = overall_missing_pct > 30 || length(high_missing_cols) > 0
  ))
}

#' Auto-fix common missing data encodings
#' @param df Data frame to fix
#' @return Cleaned data frame
fix_missing_encodings <- function(df) {

  # Common missing data encodings
  missing_codes <- c("", " ", "NA", "N/A", "na", "n/a", "NULL", "null",
                     "-", "--", ".", "missing", "MISSING", "NaN", "nan",
                     "999", "9999", "-999", "-9999", "#N/A", "#NA")

  # Replace all missing codes with NA
  df <- df %>%
    mutate(across(everything(), ~ ifelse(. %in% missing_codes, NA, .)))

  # Convert numeric columns that were read as character
  for (col in names(df)) {
    if (is.character(df[[col]])) {
      # Try to convert to numeric
      numeric_attempt <- suppressWarnings(as.numeric(df[[col]]))
      if (!all(is.na(numeric_attempt)[!is.na(df[[col]])])) {
        # If conversion worked for non-NA values, use it
        df[[col]] <- numeric_attempt
      }
    }
  }

  return(df)
}

# ============================================================================
# DATA STRUCTURE VALIDATION
# ============================================================================

#' Validate meta-analysis data structure
#' @param df Data frame to validate
#' @param analysis_type Type of analysis (pairwise, network, masem)
#' @return List with validation results and suggestions
validate_ma_structure <- function(df, analysis_type = "pairwise") {

  errors <- list()
  warnings <- list()
  suggestions <- list()

  # Check minimum row count
  if (nrow(df) < 2) {
    errors <- c(errors, "Need at least 2 studies for meta-analysis")
  } else if (nrow(df) < 5) {
    warnings <- c(warnings, "Small number of studies - results may be unstable")
  }

  # Analysis-specific checks
  if (analysis_type == "pairwise") {
    required_cols <- c("study_id", "effect_size", "se")
    recommended_cols <- c("n", "year", "author")

    # Check for required columns
    missing_required <- setdiff(required_cols, names(df))
    if (length(missing_required) > 0) {
      errors <- c(errors, paste("Missing required columns:", paste(missing_required, collapse = ", ")))

      # Suggest alternatives
      if ("effect_size" %in% missing_required) {
        suggestions <- c(suggestions,
          "effect_size can be calculated from: mean1, mean2, sd1, sd2, n1, n2")
      }
      if ("se" %in% missing_required) {
        suggestions <- c(suggestions,
          "se can be calculated from confidence intervals: (ci_upper - ci_lower) / 3.92")
      }
    }

    # Check for recommended columns
    missing_recommended <- setdiff(recommended_cols, names(df))
    if (length(missing_recommended) > 0) {
      warnings <- c(warnings,
        paste("Missing recommended columns:", paste(missing_recommended, collapse = ", ")))
    }

    # Check data types
    if ("effect_size" %in% names(df) && !is.numeric(df$effect_size)) {
      errors <- c(errors, "effect_size must be numeric")
    }
    if ("se" %in% names(df) && !is.numeric(df$se)) {
      errors <- c(errors, "se (standard error) must be numeric")
    }

    # Check for invalid values
    if ("se" %in% names(df)) {
      if (any(df$se <= 0, na.rm = TRUE)) {
        errors <- c(errors, "Standard error (se) must be positive")
      }
    }
  }

  if (analysis_type == "network") {
    required_cols <- c("study_id", "treat1", "treat2", "effect_size", "se")

    missing_required <- setdiff(required_cols, names(df))
    if (length(missing_required) > 0) {
      errors <- c(errors, paste("Missing required columns:", paste(missing_required, collapse = ", ")))
    }
  }

  if (analysis_type == "masem") {
    required_cols <- c("study_id", "n", "cor_matrix")

    missing_required <- setdiff(required_cols, names(df))
    if (length(missing_required) > 0) {
      errors <- c(errors, paste("Missing required columns:", paste(missing_required, collapse = ", ")))
    }
  }

  return(list(
    valid = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    suggestions = suggestions,
    n_studies = nrow(df),
    n_variables = ncol(df)
  ))
}

# ============================================================================
# COMPREHENSIVE DATA PREPROCESSING PIPELINE
# ============================================================================

#' Complete preprocessing pipeline for uploaded data
#' @param df Raw data frame
#' @param analysis_type Type of analysis
#' @param expected_columns Optional expected column names
#' @return List with processed data and full report
preprocess_data <- function(df, analysis_type = "pairwise", expected_columns = NULL) {

  report <- list(
    original_rows = nrow(df),
    original_cols = ncol(df),
    steps = list()
  )

  # Step 1: Fix missing data encodings
  df <- fix_missing_encodings(df)
  report$steps$missing_fix <- "Fixed common missing data encodings"

  # Step 2: Clean and rename columns
  clean_result <- clean_column_names(df, expected_columns)
  df <- clean_result$data
  report$steps$column_cleaning <- clean_result$messages
  report$column_changes <- data.frame(
    original = clean_result$original_names,
    new = clean_result$new_names,
    changed = clean_result$original_names != clean_result$new_names
  )

  # Step 3: Analyze missing data
  missing_analysis <- analyze_missing_data(df)
  report$missing_data <- missing_analysis

  # Step 4: Remove rows/columns with extreme missingness if recommended
  if (missing_analysis$action_needed) {
    # Remove columns with >70% missing
    very_high_missing <- names(missing_analysis$missing_per_col[
      missing_analysis$missing_per_col > 70
    ])
    if (length(very_high_missing) > 0) {
      df <- df %>% select(-all_of(very_high_missing))
      report$steps$removed_cols <- paste("Removed columns with >70% missing:",
                                         paste(very_high_missing, collapse = ", "))
    }

    # Remove rows with >70% missing
    rows_to_remove <- which(missing_analysis$missing_per_row > 70)
    if (length(rows_to_remove) > 0) {
      df <- df[-rows_to_remove, ]
      report$steps$removed_rows <- paste("Removed", length(rows_to_remove),
                                         "studies with >70% missing data")
    }
  }

  # Step 5: Validate structure
  validation <- validate_ma_structure(df, analysis_type)
  report$validation <- validation

  # Step 6: Final report
  report$final_rows <- nrow(df)
  report$final_cols <- ncol(df)
  report$success <- validation$valid
  report$warnings <- c(clean_result$warnings, validation$warnings)
  report$errors <- validation$errors
  report$suggestions <- validation$suggestions

  return(list(
    data = df,
    report = report,
    success = validation$valid,
    has_warnings = length(report$warnings) > 0
  ))
}

# ============================================================================
# USER-FRIENDLY REPORT GENERATION
# ============================================================================

#' Generate human-readable preprocessing report
#' @param preprocess_result Result from preprocess_data()
#' @return Character vector with formatted report
generate_report_text <- function(preprocess_result) {

  report <- preprocess_result$report
  lines <- c()

  lines <- c(lines, "═══════════════════════════════════════")
  lines <- c(lines, "DATA PREPROCESSING REPORT")
  lines <- c(lines, "═══════════════════════════════════════\n")

  # Data dimensions
  lines <- c(lines, sprintf("Original data: %d studies × %d variables",
                           report$original_rows, report$original_cols))
  lines <- c(lines, sprintf("Processed data: %d studies × %d variables\n",
                           report$final_rows, report$final_cols))

  # Column changes
  if (nrow(report$column_changes) > 0) {
    changed <- report$column_changes[report$column_changes$changed, ]
    if (nrow(changed) > 0) {
      lines <- c(lines, "Column Name Changes:")
      for (i in 1:nrow(changed)) {
        lines <- c(lines, sprintf("  • '%s' → '%s'", changed$original[i], changed$new[i]))
      }
      lines <- c(lines, "")
    }
  }

  # Missing data
  if (report$missing_data$overall_pct > 0) {
    lines <- c(lines, sprintf("Missing Data: %.1f%% overall",
                             report$missing_data$overall_pct))
    for (rec in report$missing_data$recommendations) {
      lines <- c(lines, paste("  ", rec))
    }
    lines <- c(lines, "")
  }

  # Validation
  if (report$validation$valid) {
    lines <- c(lines, "✓ Data structure is valid for analysis\n")
  } else {
    lines <- c(lines, "✗ DATA VALIDATION FAILED\n")
    if (length(report$errors) > 0) {
      lines <- c(lines, "Errors:")
      for (err in report$errors) {
        lines <- c(lines, paste("  ✗", err))
      }
      lines <- c(lines, "")
    }
  }

  # Warnings
  if (length(report$warnings) > 0) {
    lines <- c(lines, "Warnings:")
    for (warn in report$warnings) {
      lines <- c(lines, paste("  ⚠", warn))
    }
    lines <- c(lines, "")
  }

  # Suggestions
  if (length(report$suggestions) > 0) {
    lines <- c(lines, "Suggestions:")
    for (sug in report$suggestions) {
      lines <- c(lines, paste("  →", sug))
    }
    lines <- c(lines, "")
  }

  lines <- c(lines, "═══════════════════════════════════════")

  return(paste(lines, collapse = "\n"))
}
