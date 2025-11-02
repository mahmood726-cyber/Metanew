# Country Configuration Loader
# Load health economic parameters from YAML config files

library(yaml)

#' Load country-specific health economic parameters
#'
#' @param country Country code (uk, us, germany, france, canada)
#' @return List of parameters from YAML file
#' @export
load_country_config <- function(country = "uk") {
  # Construct file path
  config_file <- file.path("config", "countries", paste0(tolower(country), ".yaml"))

  # Check if file exists
  if (!file.exists(config_file)) {
    available_countries <- list.files("config/countries", pattern = "\\.yaml$")
    available_countries <- gsub("\\.yaml$", "", available_countries)

    stop(sprintf(
      "Configuration file not found for country '%s'.\nAvailable countries: %s",
      country,
      paste(available_countries, collapse = ", ")
    ))
  }

  # Load YAML
  config <- tryCatch({
    yaml::read_yaml(config_file)
  }, error = function(e) {
    stop(sprintf("Error loading config file for %s: %s", country, e$message))
  })

  # Add metadata
  config$config_file <- config_file
  config$loaded_at <- Sys.time()

  message(sprintf("✓ Loaded %s parameters from %s", config$country, basename(config_file)))

  return(config)
}

#' List available country configurations
#'
#' @return Character vector of available country codes
#' @export
list_available_countries <- function() {
  config_dir <- "config/countries"

  if (!dir.exists(config_dir)) {
    return(character(0))
  }

  yaml_files <- list.files(config_dir, pattern = "\\.yaml$", full.names = FALSE)
  countries <- gsub("\\.yaml$", "", yaml_files)

  # Load country names
  country_info <- lapply(countries, function(code) {
    config <- load_country_config(code)
    data.frame(
      code = code,
      name = config$country,
      currency = config$currency,
      wtp_threshold = config$wtp$primary_threshold,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, country_info)
}

#' Apply country config to HE parameters
#'
#' Converts country config to format expected by HE modules
#'
#' @param config Country configuration list
#' @param overrides Named list of parameter overrides
#' @return List formatted for HE modules
#' @export
config_to_he_params <- function(config, overrides = list()) {
  he_params <- list(
    # Model settings
    time_horizon = config$time_horizon$default,
    discount_rate = config$discounting$costs,
    wtp_threshold = config$wtp$primary_threshold,
    n_iterations = config$psa$n_iterations,

    # Costs
    cost_treatment = config$costs$drug_treatment$default,
    cost_comparator = config$costs$drug_comparator$default,
    cost_stable = config$costs$health_state_stable$default,
    cost_progressed = config$costs$health_state_progressed$default,

    # Utilities
    utility_stable = config$utilities$stable_disease,
    utility_progressed = config$utilities$progressed_disease,

    # Population (for budget impact)
    population_size = config$population$eligible_population,
    market_share_year1 = config$population$market_share_year1,
    market_share_year5 = config$population$market_share_year5,

    # Metadata
    country = config$country,
    currency = config$currency,
    currency_symbol = config$currency_symbol
  )

  # Apply any overrides
  for (param_name in names(overrides)) {
    he_params[[param_name]] <- overrides[[param_name]]
  }

  return(he_params)
}

#' Create summary table of country parameters
#'
#' @param countries Vector of country codes to compare
#' @return Data frame comparing key parameters
#' @export
compare_country_params <- function(countries = c("uk", "us", "germany", "france", "canada")) {
  comparison <- lapply(countries, function(country) {
    config <- load_country_config(country)

    data.frame(
      Country = config$country,
      Currency = config$currency,
      WTP_Primary = sprintf("%s%s", config$currency_symbol,
                           format(config$wtp$primary_threshold, big.mark = ",")),
      Discount_Rate = sprintf("%.1f%%", config$discounting$costs * 100),
      Time_Horizon = sprintf("%d years", config$time_horizon$default),
      Drug_Cost = sprintf("%s%s", config$currency_symbol,
                         format(config$costs$drug_treatment$default, big.mark = ",")),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, comparison)
}
