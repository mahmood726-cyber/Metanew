# ============================================================================
# IPD Meta-Analysis - Data Validation Module
# ============================================================================
# Validates and prepares individual patient data for meta-analysis
# Reference: Riley et al. (2010) BMJ, Debray et al. (2015)
# ============================================================================

library(dplyr)
library(tidyr)

#' Validate IPD Structure
#'
#' Checks if IPD data has required columns and correct data types
#'
#' @param ipd_data Data frame with individual patient data
#' @param study_var Name of study identifier column
#' @param patient_var Name of patient identifier column
#' @param outcome_var Name of outcome variable column
#' @param treatment_var Name of treatment variable column
#' @return List with is_valid (logical) and messages (character vector)
#' @export
validate_ipd_structure <- function(ipd_data,
                                   study_var = "study_id",
                                   patient_var = "patient_id",
                                   outcome_var = "outcome",
                                   treatment_var = "treatment") {

  messages <- character(0)
  is_valid <- TRUE

  # Check if data.frame
  if (!is.data.frame(ipd_data)) {
    messages <- c(messages, "Input must be a data.frame")
    return(list(is_valid = FALSE, messages = messages))
  }

  # Check required columns exist
  required_cols <- c(study_var, patient_var, outcome_var, treatment_var)
  missing_cols <- required_cols[!required_cols %in% names(ipd_data)]

  if (length(missing_cols) > 0) {
    messages <- c(messages, paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
    is_valid <- FALSE
  }

  if (!is_valid) {
    return(list(is_valid = FALSE, messages = messages))
  }

  # Check for missing values in key columns
  for (col in required_cols) {
    n_missing <- sum(is.na(ipd_data[[col]]))
    if (n_missing > 0) {
      messages <- c(messages, sprintf("Column '%s' has %d missing values (%.1f%%)",
                                     col, n_missing, 100 * n_missing / nrow(ipd_data)))
    }
  }

  # Check study_id and patient_id are not duplicated within studies
  duplicated_patients <- ipd_data %>%
    group_by(across(all_of(c(study_var, patient_var)))) %>%
    filter(n() > 1) %>%
    nrow()

  if (duplicated_patients > 0) {
    messages <- c(messages, sprintf("Warning: %d duplicate patient IDs found within studies", duplicated_patients))
    is_valid <- FALSE
  }

  # Check number of studies
  n_studies <- length(unique(ipd_data[[study_var]]))
  if (n_studies < 2) {
    messages <- c(messages, "IPD meta-analysis requires at least 2 studies")
    is_valid <- FALSE
  }

  # Check patients per study
  patients_per_study <- ipd_data %>%
    group_by(across(all_of(study_var))) %>%
    summarise(n = n(), .groups = "drop")

  min_patients <- min(patients_per_study$n)
  if (min_patients < 10) {
    messages <- c(messages, sprintf("Warning: Some studies have < 10 patients (min = %d)", min_patients))
  }

  # Check treatment variable
  n_treatments <- length(unique(ipd_data[[treatment_var]]))
  if (n_treatments < 2) {
    messages <- c(messages, "At least 2 treatment groups required")
    is_valid <- FALSE
  }

  # Summary statistics
  summary_stats <- list(
    n_patients = nrow(ipd_data),
    n_studies = n_studies,
    n_treatments = n_treatments,
    patients_per_study = patients_per_study
  )

  list(
    is_valid = is_valid,
    messages = messages,
    summary = summary_stats
  )
}


#' Harmonize Variables Across Studies
#'
#' Standardizes variable names and coding across studies
#'
#' @param ipd_data IPD data frame
#' @param mappings Named list of variable mappings
#' @return Harmonized data frame
#' @export
harmonize_variables <- function(ipd_data, mappings = NULL) {

  if (is.null(mappings)) {
    # Return as-is if no mappings provided
    return(ipd_data)
  }

  # Apply variable name mappings
  for (new_name in names(mappings)) {
    old_name <- mappings[[new_name]]

    if (old_name %in% names(ipd_data)) {
      ipd_data[[new_name]] <- ipd_data[[old_name]]

      # Remove old column if different from new name
      if (old_name != new_name) {
        ipd_data[[old_name]] <- NULL
      }
    }
  }

  return(ipd_data)
}


#' Check Data Quality
#'
#' Identifies potential data quality issues
#'
#' @param ipd_data IPD data frame
#' @param outcome_var Outcome variable name
#' @param treatment_var Treatment variable name
#' @param continuous_vars Vector of continuous variable names
#' @return List with quality issues and recommendations
#' @export
check_data_quality <- function(ipd_data,
                               outcome_var = "outcome",
                               treatment_var = "treatment",
                               continuous_vars = NULL) {

  issues <- list()

  # Check for outliers in continuous variables
  if (!is.null(continuous_vars)) {
    for (var in continuous_vars) {
      if (var %in% names(ipd_data) && is.numeric(ipd_data[[var]])) {

        # IQR method for outlier detection
        Q1 <- quantile(ipd_data[[var]], 0.25, na.rm = TRUE)
        Q3 <- quantile(ipd_data[[var]], 0.75, na.rm = TRUE)
        IQR <- Q3 - Q1
        lower_bound <- Q1 - 3 * IQR
        upper_bound <- Q3 + 3 * IQR

        n_outliers <- sum(ipd_data[[var]] < lower_bound | ipd_data[[var]] > upper_bound, na.rm = TRUE)

        if (n_outliers > 0) {
          issues[[paste0("outliers_", var)]] <- sprintf(
            "Variable '%s' has %d potential outliers (%.1f%%)",
            var, n_outliers, 100 * n_outliers / nrow(ipd_data)
          )
        }
      }
    }
  }

  # Check treatment balance within studies
  balance_check <- ipd_data %>%
    group_by(study_id, across(all_of(treatment_var))) %>%
    summarise(n = n(), .groups = "drop") %>%
    group_by(study_id) %>%
    mutate(
      total = sum(n),
      prop = n / total
    )

  imbalanced_studies <- balance_check %>%
    filter(prop < 0.2 | prop > 0.8) %>%
    distinct(study_id)

  if (nrow(imbalanced_studies) > 0) {
    issues$treatment_imbalance <- sprintf(
      "Warning: %d studies have severe treatment imbalance (>80%% in one group)",
      nrow(imbalanced_studies)
    )
  }

  # Check outcome distribution
  if (is.numeric(ipd_data[[outcome_var]])) {
    # Continuous outcome - check for normality
    shapiro_test <- tryCatch({
      shapiro.test(sample(ipd_data[[outcome_var]][!is.na(ipd_data[[outcome_var]])],
                         min(5000, sum(!is.na(ipd_data[[outcome_var]])))))
    }, error = function(e) NULL)

    if (!is.null(shapiro_test) && shapiro_test$p.value < 0.05) {
      issues$outcome_normality <- "Outcome may not be normally distributed (Shapiro-Wilk p < 0.05). Consider transformation."
    }

  } else if (is.logical(ipd_data[[outcome_var]]) || is.factor(ipd_data[[outcome_var]])) {
    # Binary outcome - check for rare events
    event_rate <- mean(as.numeric(ipd_data[[outcome_var]]), na.rm = TRUE)

    if (event_rate < 0.05 || event_rate > 0.95) {
      issues$rare_outcome <- sprintf(
        "Warning: Outcome is rare (event rate = %.1f%%). Consider Firth logistic regression.",
        event_rate * 100
      )
    }
  }

  list(
    n_issues = length(issues),
    issues = issues,
    recommendation = if (length(issues) > 0) {
      "Review data quality issues before proceeding with analysis"
    } else {
      "No major data quality issues detected"
    }
  )
}


#' Prepare IPD for Analysis
#'
#' Complete data preparation pipeline
#'
#' @param ipd_data Raw IPD data
#' @param study_var Study identifier
#' @param patient_var Patient identifier
#' @param outcome_var Outcome variable
#' @param treatment_var Treatment variable
#' @param covariates Vector of covariate names to include
#' @param outcome_type "binary", "continuous", "survival", or "count"
#' @return List with prepared data and metadata
#' @export
prepare_ipd_for_analysis <- function(ipd_data,
                                     study_var = "study_id",
                                     patient_var = "patient_id",
                                     outcome_var = "outcome",
                                     treatment_var = "treatment",
                                     covariates = NULL,
                                     outcome_type = "continuous") {

  # Step 1: Validate structure
  validation <- validate_ipd_structure(ipd_data, study_var, patient_var, outcome_var, treatment_var)

  if (!validation$is_valid) {
    stop("IPD validation failed:\n", paste(validation$messages, collapse = "\n"))
  }

  # Step 2: Select relevant columns
  cols_to_keep <- c(study_var, patient_var, outcome_var, treatment_var, covariates)
  cols_to_keep <- cols_to_keep[cols_to_keep %in% names(ipd_data)]

  ipd_clean <- ipd_data %>%
    select(all_of(cols_to_keep))

  # Step 3: Convert outcome based on type
  if (outcome_type == "binary") {
    # Ensure binary outcome is 0/1
    if (!is.numeric(ipd_clean[[outcome_var]])) {
      ipd_clean[[outcome_var]] <- as.numeric(as.factor(ipd_clean[[outcome_var]])) - 1
    }

  } else if (outcome_type == "survival") {
    # For survival, we need time and event
    # This is a simplified check - real implementation would be more complex
    if (!"time" %in% names(ipd_clean)) {
      stop("Survival analysis requires 'time' variable")
    }
    if (!"event" %in% names(ipd_clean)) {
      stop("Survival analysis requires 'event' variable")
    }
  }

  # Step 4: Handle missing data (complete case for now)
  n_before <- nrow(ipd_clean)
  ipd_clean <- ipd_clean %>%
    filter(complete.cases(.))
  n_after <- nrow(ipd_clean)
  n_missing <- n_before - n_after

  if (n_missing > 0) {
    warning(sprintf("Removed %d patients (%.1f%%) with missing data",
                   n_missing, 100 * n_missing / n_before))
  }

  # Step 5: Create study-level summary
  study_summary <- ipd_clean %>%
    group_by(across(all_of(study_var))) %>%
    summarise(
      n_patients = n(),
      n_treatments = length(unique(!!sym(treatment_var))),
      .groups = "drop"
    )

  # Return prepared data with metadata
  list(
    data = ipd_clean,
    study_var = study_var,
    patient_var = patient_var,
    outcome_var = outcome_var,
    treatment_var = treatment_var,
    covariates = covariates,
    outcome_type = outcome_type,
    n_patients = nrow(ipd_clean),
    n_studies = length(unique(ipd_clean[[study_var]])),
    n_removed = n_missing,
    study_summary = study_summary,
    validation = validation
  )
}
