# Scenario Presets Utility
# Functions for loading and applying pre-configured analysis scenarios

library(yaml)

#' Load scenario presets from YAML file
#'
#' @param presets_file Path to YAML file (default: data/scenario_presets.yaml)
#' @return List of scenario presets
load_scenario_presets <- function(presets_file = "data/scenario_presets.yaml") {
  if (!file.exists(presets_file)) {
    warning(paste("Presets file not found:", presets_file))
    return(list(presets = list(), metadata = list()))
  }

  tryCatch({
    yaml::read_yaml(presets_file)
  }, error = function(e) {
    warning(paste("Error loading presets:", e$message))
    return(list(presets = list(), metadata = list()))
  })
}


#' Get preset by ID
#'
#' @param preset_id Preset identifier (e.g., "base_case_standard")
#' @param presets_data Loaded presets data
#' @return Single preset configuration or NULL
get_preset_by_id <- function(preset_id, presets_data) {
  for (preset in presets_data$presets) {
    if (preset$id == preset_id) {
      return(preset)
    }
  }
  return(NULL)
}


#' Get presets by category
#'
#' @param category Category name (e.g., "Base Case", "Sensitivity")
#' @param presets_data Loaded presets data
#' @return List of presets in category
get_presets_by_category <- function(category, presets_data) {
  Filter(function(p) p$category == category, presets_data$presets)
}


#' Get list of all categories
#'
#' @param presets_data Loaded presets data
#' @return Character vector of unique categories
get_preset_categories <- function(presets_data) {
  unique(sapply(presets_data$presets, function(p) p$category))
}


#' Apply preset to reactive values
#'
#' @param preset Preset configuration
#' @param rv Shiny reactive values object
#' @param session Shiny session object
#' @return Updated rv object
apply_preset_to_rv <- function(preset, rv, session = NULL) {
  if (is.null(preset)) {
    return(rv)
  }

  # Apply filters
  if (!is.null(preset$filters)) {
    rv$scenario_filters <- preset$filters
  }

  # Apply estimator
  if (!is.null(preset$estimator)) {
    rv$meta_estimator <- preset$estimator
  }

  # Apply model type
  if (!is.null(preset$model_type)) {
    rv$meta_model_type <- preset$model_type
  }

  # Apply subgroup variable
  if (!is.null(preset$subgroup_variable)) {
    rv$meta_subgroup <- preset$subgroup_variable
  }

  # Apply health economics parameters
  if (!is.null(preset$he_parameters)) {
    rv$he_params <- preset$he_parameters
  }

  # Store preset metadata
  rv$active_preset_id <- preset$id
  rv$active_preset_name <- preset$name

  # Log action
  message(sprintf("Applied preset: %s (%s)", preset$name, preset$id))

  return(rv)
}


#' Create preset dropdown choices
#'
#' @param presets_data Loaded presets data
#' @return Named list suitable for selectInput choices
create_preset_choices <- function(presets_data) {
  categories <- get_preset_categories(presets_data)

  choices <- list("-- Select Preset --" = "")

  for (category in categories) {
    category_presets <- get_presets_by_category(category, presets_data)

    category_choices <- setNames(
      sapply(category_presets, function(p) p$id),
      sapply(category_presets, function(p) p$name)
    )

    choices[[category]] <- category_choices
  }

  return(choices)
}


#' Generate preset summary HTML
#'
#' @param preset Preset configuration
#' @return HTML summary for display
generate_preset_summary <- function(preset) {
  if (is.null(preset)) {
    return(div(class = "text-muted", "No preset selected"))
  }

  tags$div(
    class = "preset-summary",
    h5(preset$name),
    p(class = "text-muted", preset$description),
    hr(),

    # Filters
    if (!is.null(preset$filters)) {
      tagList(
        h6("Filters:"),
        tags$ul(
          if (!is.null(preset$filters$min_quality)) {
            tags$li(sprintf("Min quality: %s", preset$filters$min_quality))
          },
          if (!is.null(preset$filters$exclude_high_rob)) {
            tags$li(sprintf("Exclude high ROB: %s", preset$filters$exclude_high_rob))
          },
          if (!is.null(preset$filters$min_sample_size)) {
            tags$li(sprintf("Min sample size: %d", preset$filters$min_sample_size))
          }
        )
      )
    },

    # Estimator
    if (!is.null(preset$estimator)) {
      p(strong("Estimator:"), preset$estimator)
    },

    # Model type
    if (!is.null(preset$model_type)) {
      p(strong("Model:"), preset$model_type)
    },

    # Sensitivity analyses
    if (!is.null(preset$sensitivity_analyses) && length(preset$sensitivity_analyses) > 0) {
      tagList(
        hr(),
        h6("Recommended Sensitivity Analyses:"),
        tags$ul(
          lapply(preset$sensitivity_analyses, function(sa) tags$li(sa))
        )
      )
    },

    # HE parameters
    if (!is.null(preset$he_parameters)) {
      tagList(
        hr(),
        h6("Health Economics:"),
        tags$ul(
          if (!is.null(preset$he_parameters$perspective)) {
            tags$li(sprintf("Perspective: %s", preset$he_parameters$perspective))
          },
          if (!is.null(preset$he_parameters$time_horizon_years)) {
            tags$li(sprintf("Time horizon: %d years", preset$he_parameters$time_horizon_years))
          },
          if (!is.null(preset$he_parameters$wtp_threshold)) {
            tags$li(sprintf("WTP threshold: £%s/QALY",
                           format(preset$he_parameters$wtp_threshold, big.mark = ",")))
          }
        )
      )
    }
  )
}


#' Save current configuration as custom preset
#'
#' @param rv Reactive values with current configuration
#' @param preset_name Name for the custom preset
#' @param preset_description Description
#' @param output_file Path to save custom preset
#' @return TRUE if successful, FALSE otherwise
save_custom_preset <- function(rv, preset_name, preset_description, output_file = "data/custom_presets.yaml") {
  tryCatch({
    # Create custom preset structure
    custom_preset <- list(
      id = paste0("custom_", gsub("[^a-z0-9]", "_", tolower(preset_name))),
      name = preset_name,
      description = preset_description,
      category = "Custom",
      created = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      filters = rv$scenario_filters,
      estimator = rv$meta_estimator,
      model_type = rv$meta_model_type
    )

    if (!is.null(rv$meta_subgroup)) {
      custom_preset$subgroup_variable <- rv$meta_subgroup
    }

    if (!is.null(rv$he_params)) {
      custom_preset$he_parameters <- rv$he_params
    }

    # Load existing custom presets
    existing_presets <- list()
    if (file.exists(output_file)) {
      existing_data <- yaml::read_yaml(output_file)
      if (!is.null(existing_data$presets)) {
        existing_presets <- existing_data$presets
      }
    }

    # Append new preset
    existing_presets[[length(existing_presets) + 1]] <- custom_preset

    # Save to file
    output_data <- list(
      presets = existing_presets,
      metadata = list(
        version = "2.0.0",
        type = "custom",
        last_updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      )
    )

    yaml::write_yaml(output_data, output_file)

    message(sprintf("Custom preset saved: %s", preset_name))
    return(TRUE)

  }, error = function(e) {
    warning(paste("Error saving custom preset:", e$message))
    return(FALSE)
  })
}


#' Validate preset configuration
#'
#' @param preset Preset to validate
#' @return List with valid (TRUE/FALSE) and messages
validate_preset <- function(preset) {
  errors <- character()

  # Check required fields
  if (is.null(preset$id)) {
    errors <- c(errors, "Missing preset ID")
  }

  if (is.null(preset$name)) {
    errors <- c(errors, "Missing preset name")
  }

  # Validate estimator
  if (!is.null(preset$estimator)) {
    valid_estimators <- c("REML", "DL", "FE", "EB", "ML")
    if (!(preset$estimator %in% valid_estimators)) {
      errors <- c(errors, sprintf("Invalid estimator: %s", preset$estimator))
    }
  }

  # Validate model type
  if (!is.null(preset$model_type)) {
    valid_models <- c("random", "fixed")
    if (!(preset$model_type %in% valid_models)) {
      errors <- c(errors, sprintf("Invalid model type: %s", preset$model_type))
    }
  }

  # Validate HE parameters
  if (!is.null(preset$he_parameters)) {
    if (!is.null(preset$he_parameters$discount_rate_costs)) {
      if (preset$he_parameters$discount_rate_costs < 0 || preset$he_parameters$discount_rate_costs > 1) {
        errors <- c(errors, "Discount rate must be between 0 and 1")
      }
    }

    if (!is.null(preset$he_parameters$wtp_threshold)) {
      if (preset$he_parameters$wtp_threshold <= 0) {
        errors <- c(errors, "WTP threshold must be positive")
      }
    }
  }

  return(list(
    valid = length(errors) == 0,
    messages = errors
  ))
}
