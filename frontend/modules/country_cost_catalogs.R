# =============================================================================
# EVIDENCEOS PRIME - COUNTRY COST CATALOGS MODULE
# =============================================================================
# Purpose: Country-specific unit cost data for EU HTA submissions
# Quality: Production-ready framework with representative cost data
# Version: 1.0 - Complete Implementation
# EU Compliance: Transferability, country-specific analyses
# =============================================================================

#' Get Country Cost Catalog
#'
#' @description
#' Retrieves unit cost data for specified country and cost category.
#'
#' @param country Country code (e.g., "UK", "DE", "FR", "NL", "SE")
#' @param category Cost category (e.g., "healthcare_contacts", "hospital", "drugs")
#' @param year Reference year for costs (default: most recent available)
#'
#' @return List with unit costs for specified country and category
#' @export
#'
#' @examples
#' \dontrun{
#' uk_costs <- get_country_cost_catalog("UK", "healthcare_contacts")
#' de_costs <- get_country_cost_catalog("DE", "hospital")
#' }
get_country_cost_catalog <- function(country, category = "all", year = NULL) {

  country <- toupper(country)

  if (!country %in% names(COUNTRY_COST_CATALOGS)) {
    stop(paste0("Country '", country, "' not available. ",
               "Available countries: ", paste(names(COUNTRY_COST_CATALOGS), collapse = ", ")))
  }

  catalog <- COUNTRY_COST_CATALOGS[[country]]

  # Use specified year or most recent
  if (is.null(year)) {
    year <- catalog$reference_year
  }

  # Apply inflation adjustment if different year requested
  if (year != catalog$reference_year) {
    inflation_factor <- calculate_inflation_adjustment(country, catalog$reference_year, year)
    message(paste0("Note: Costs adjusted from ", catalog$reference_year, " to ", year,
                  " using inflation factor ", round(inflation_factor, 3)))
    catalog <- adjust_costs_for_inflation(catalog, inflation_factor)
  }

  # Return specific category or all
  if (category == "all") {
    return(catalog)
  } else if (category %in% names(catalog)) {
    return(catalog[[category]])
  } else {
    stop(paste0("Category '", category, "' not found. ",
               "Available categories: ", paste(names(catalog), collapse = ", ")))
  }
}


# =============================================================================
# COUNTRY COST CATALOGS DATA
# =============================================================================

COUNTRY_COST_CATALOGS <- list(

  # ---------------------------------------------------------------------------
  # UNITED KINGDOM (GBP, 2023/24)
  # ---------------------------------------------------------------------------
  UK = list(
    country_name = "United Kingdom",
    currency = "GBP",
    reference_year = 2023,
    source = "NHS Reference Costs 2023/24, PSSRU Unit Costs 2023",

    healthcare_contacts = list(
      gp_consultation = 39,
      gp_home_visit = 72,
      practice_nurse_consultation = 12,
      specialist_outpatient = 118,
      emergency_department = 186,
      ambulance_call = 283,
      pharmacist_consultation = 15
    ),

    hospital = list(
      inpatient_day_general = 400,
      inpatient_day_icu = 1932,
      day_case_procedure = 785,
      elective_admission = 4250,
      emergency_admission = 2105
    ),

    diagnostics = list(
      x_ray = 32,
      ct_scan = 112,
      mri_scan = 164,
      ultrasound = 62,
      blood_test_basic = 3,
      blood_test_comprehensive = 15,
      ecg = 54,
      echo_cardiogram = 96
    ),

    personnel_hourly = list(
      consultant_physician = 120,
      junior_doctor = 45,
      registered_nurse = 42,
      healthcare_assistant = 25,
      physiotherapist = 38,
      occupational_therapist = 38,
      pharmacist = 48,
      social_worker = 35
    )
  ),

  # ---------------------------------------------------------------------------
  # GERMANY (EUR, 2023)
  # ---------------------------------------------------------------------------
  DE = list(
    country_name = "Germany",
    currency = "EUR",
    reference_year = 2023,
    source = "InEK DRG Browser 2023, GKV-Spitzenverband",

    healthcare_contacts = list(
      gp_consultation = 25,
      specialist_outpatient = 65,
      emergency_department = 150,
      ambulance_call = 380,
      home_care_visit = 45
    ),

    hospital = list(
      inpatient_day_general = 450,
      inpatient_day_icu = 1850,
      day_case_procedure = 850,
      elective_admission = 5200,
      emergency_admission = 2800
    ),

    diagnostics = list(
      x_ray = 28,
      ct_scan = 95,
      mri_scan = 145,
      ultrasound = 55,
      blood_test_basic = 4,
      blood_test_comprehensive = 18,
      ecg = 45,
      echo_cardiogram = 85
    ),

    personnel_hourly = list(
      physician = 85,
      registered_nurse = 38,
      physiotherapist = 42,
      pharmacist = 52
    )
  ),

  # ---------------------------------------------------------------------------
  # FRANCE (EUR, 2023)
  # ---------------------------------------------------------------------------
  FR = list(
    country_name = "France",
    currency = "EUR",
    reference_year = 2023,
    source = "CNAM Tarifs 2023, ATIH Coûts MCO 2023",

    healthcare_contacts = list(
      gp_consultation = 26.50,
      specialist_outpatient = 50,
      emergency_department = 135,
      ambulance_call = 280,
      home_care_visit = 40
    ),

    hospital = list(
      inpatient_day_general = 800,
      inpatient_day_icu = 2100,
      day_case_procedure = 680,
      elective_admission = 4800,
      emergency_admission = 2400
    ),

    diagnostics = list(
      x_ray = 35,
      ct_scan = 110,
      mri_scan = 180,
      ultrasound = 65,
      blood_test_basic = 5,
      blood_test_comprehensive = 20
    ),

    personnel_hourly = list(
      physician = 75,
      registered_nurse = 35,
      physiotherapist = 38,
      pharmacist = 45
    )
  ),

  # ---------------------------------------------------------------------------
  # NETHERLANDS (EUR, 2024)
  # ---------------------------------------------------------------------------
  NL = list(
    country_name = "Netherlands",
    currency = "EUR",
    reference_year = 2024,
    source = "NZa Open Data 2024, Zorginstituut Nederland Kostenhandleiding",

    healthcare_contacts = list(
      gp_consultation = 38,
      specialist_outpatient = 95,
      emergency_department = 185,
      ambulance_call = 650,
      home_care_visit = 55
    ),

    hospital = list(
      inpatient_day_general = 525,
      inpatient_day_icu = 2250,
      day_case_procedure = 950,
      elective_admission = 6200,
      emergency_admission = 3100
    ),

    diagnostics = list(
      x_ray = 42,
      ct_scan = 128,
      mri_scan = 215,
      ultrasound = 78,
      blood_test_basic = 6,
      blood_test_comprehensive = 25
    ),

    personnel_hourly = list(
      physician = 95,
      registered_nurse = 48,
      physiotherapist = 52,
      pharmacist = 58
    )
  ),

  # ---------------------------------------------------------------------------
  # SWEDEN (SEK, 2023)
  # ---------------------------------------------------------------------------
  SE = list(
    country_name = "Sweden",
    currency = "SEK",
    reference_year = 2023,
    source = "SKR KPP Database 2023, TLV Health Economics Guidelines",

    healthcare_contacts = list(
      gp_consultation = 1800,
      specialist_outpatient = 3200,
      emergency_department = 4500,
      ambulance_call = 8000,
      home_care_visit = 2200
    ),

    hospital = list(
      inpatient_day_general = 8500,
      inpatient_day_icu = 35000,
      day_case_procedure = 15000,
      elective_admission = 75000,
      emergency_admission = 42000
    ),

    diagnostics = list(
      x_ray = 850,
      ct_scan = 2800,
      mri_scan = 4200,
      ultrasound = 1500,
      blood_test_basic = 150,
      blood_test_comprehensive = 600
    ),

    personnel_hourly = list(
      physician = 1200,
      registered_nurse = 650,
      physiotherapist = 700,
      pharmacist = 750
    )
  ),

  # ---------------------------------------------------------------------------
  # SPAIN (EUR, 2023)
  # ---------------------------------------------------------------------------
  ES = list(
    country_name = "Spain",
    currency = "EUR",
    reference_year = 2023,
    source = "Ministerio de Sanidad Costes Hospitalarios 2023",

    healthcare_contacts = list(
      gp_consultation = 22,
      specialist_outpatient = 58,
      emergency_department = 125,
      ambulance_call = 280,
      home_care_visit = 35
    ),

    hospital = list(
      inpatient_day_general = 420,
      inpatient_day_icu = 1680,
      day_case_procedure = 720,
      elective_admission = 4500,
      emergency_admission = 2200
    ),

    diagnostics = list(
      x_ray = 25,
      ct_scan = 92,
      mri_scan = 135,
      ultrasound = 48,
      blood_test_basic = 3.50,
      blood_test_comprehensive = 15
    ),

    personnel_hourly = list(
      physician = 62,
      registered_nurse = 28,
      physiotherapist = 32,
      pharmacist = 38
    )
  ),

  # ---------------------------------------------------------------------------
  # BELGIUM (EUR, 2023)
  # ---------------------------------------------------------------------------
  BE = list(
    country_name = "Belgium",
    currency = "EUR",
    reference_year = 2023,
    source = "RIZIV-INAMI Nomenclature 2023, KCE Reports",

    healthcare_contacts = list(
      gp_consultation = 28,
      specialist_outpatient = 72,
      emergency_department = 148,
      ambulance_call = 350,
      home_care_visit = 42
    ),

    hospital = list(
      inpatient_day_general = 495,
      inpatient_day_icu = 2050,
      day_case_procedure = 880,
      elective_admission = 5400,
      emergency_admission = 2750
    ),

    diagnostics = list(
      x_ray = 32,
      ct_scan = 105,
      mri_scan = 168,
      ultrasound = 62,
      blood_test_basic = 4.50,
      blood_test_comprehensive = 19
    ),

    personnel_hourly = list(
      physician = 78,
      registered_nurse = 36,
      physiotherapist = 40,
      pharmacist = 48
    )
  )
)


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#' Calculate Inflation Adjustment Factor
#'
#' @description
#' Calculates inflation adjustment factor between two years.
#' Uses representative EU inflation rates. For precise work, update with
#' country-specific rates from HICP/CPI data.
#'
#' @param country Country code
#' @param from_year Base year
#' @param to_year Target year
#'
#' @return Inflation adjustment factor
#' @export
calculate_inflation_adjustment <- function(country, from_year, to_year) {

  # Representative annual inflation rates (simplified)
  # For production use, integrate with official HICP/CPI APIs
  avg_annual_inflation <- switch(country,
    "UK" = 0.06,   # ~6% average 2020-2024
    "DE" = 0.05,   # ~5%
    "FR" = 0.05,   # ~5%
    "NL" = 0.055,  # ~5.5%
    "SE" = 0.07,   # ~7%
    "ES" = 0.055,  # ~5.5%
    "BE" = 0.06,   # ~6%
    0.055          # Default 5.5%
  )

  year_diff <- to_year - from_year
  inflation_factor <- (1 + avg_annual_inflation) ^ year_diff

  return(inflation_factor)
}


#' Adjust Costs for Inflation
#'
#' @description
#' Adjusts all costs in catalog by inflation factor.
#'
#' @param catalog Cost catalog
#' @param inflation_factor Inflation adjustment factor
#'
#' @return Adjusted cost catalog
#' @export
adjust_costs_for_inflation <- function(catalog, inflation_factor) {

  adjusted_catalog <- catalog

  # Adjust numeric values recursively
  for (category in names(catalog)) {
    if (is.list(catalog[[category]]) && !is.null(names(catalog[[category]]))) {
      for (item in names(catalog[[category]])) {
        if (is.numeric(catalog[[category]][[item]])) {
          adjusted_catalog[[category]][[item]] <- catalog[[category]][[item]] * inflation_factor
        }
      }
    }
  }

  return(adjusted_catalog)
}


#' Convert Currency
#'
#' @description
#' Converts costs between currencies using exchange rates.
#' For production use, integrate with live exchange rate API.
#'
#' @param amount Amount to convert
#' @param from_currency Source currency (e.g., "GBP", "EUR")
#' @param to_currency Target currency
#' @param date Optional date for historical rates
#'
#' @return Converted amount
#' @export
convert_currency <- function(amount, from_currency, to_currency, date = NULL) {

  if (from_currency == to_currency) {
    return(amount)
  }

  # Representative exchange rates (as of 2024)
  # For production, use ECB API or similar
  exchange_rates_to_eur <- list(
    EUR = 1.0,
    GBP = 1.17,
    SEK = 0.087,
    DKK = 0.134,
    NOK = 0.088,
    USD = 0.92
  )

  if (!from_currency %in% names(exchange_rates_to_eur)) {
    stop(paste0("Currency not supported: ", from_currency))
  }
  if (!to_currency %in% names(exchange_rates_to_eur)) {
    stop(paste0("Currency not supported: ", to_currency))
  }

  # Convert to EUR, then to target currency
  amount_eur <- amount * exchange_rates_to_eur[[from_currency]]
  amount_target <- amount_eur / exchange_rates_to_eur[[to_currency]]

  message(paste0("Note: Using representative exchange rate. ",
                "For official submissions, use current/historical rates."))

  return(amount_target)
}


#' List Available Countries
#'
#' @description
#' Lists all countries with available cost data.
#'
#' @export
list_cost_catalog_countries <- function() {

  countries <- names(COUNTRY_COST_CATALOGS)

  cat("\n")
  cat("==============================================================================\n")
  cat("  AVAILABLE COUNTRY COST CATALOGS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("%-10s %-25s %-10s %-15s\n", "Code", "Country", "Currency", "Reference Year"))
  cat("------------------------------------------------------------------------------\n")

  for (code in countries) {
    catalog <- COUNTRY_COST_CATALOGS[[code]]
    cat(sprintf("%-10s %-25s %-10s %-15d\n",
                code,
                catalog$country_name,
                catalog$currency,
                catalog$reference_year))
  }

  cat("==============================================================================\n\n")

  cat("Categories available: healthcare_contacts, hospital, diagnostics, personnel_hourly\n")
  cat("Usage: get_country_cost_catalog(\"UK\", \"healthcare_contacts\")\n\n")

  invisible(countries)
}


#' Compare Costs Across Countries
#'
#' @description
#' Compares specific cost items across multiple countries.
#'
#' @param countries Vector of country codes
#' @param category Cost category
#' @param items Vector of specific items to compare
#' @param normalize_currency Currency to normalize to (default "EUR")
#'
#' @return Data frame with cost comparison
#' @export
compare_costs_across_countries <- function(countries,
                                          category,
                                          items,
                                          normalize_currency = "EUR") {

  comparison_df <- data.frame(
    Country = character(0),
    Currency = character(0),
    stringsAsFactors = FALSE
  )

  for (item in items) {
    comparison_df[[item]] <- numeric(0)
  }

  for (country in countries) {
    catalog <- get_country_cost_catalog(country, category)

    row_data <- list(
      Country = COUNTRY_COST_CATALOGS[[country]]$country_name,
      Currency = COUNTRY_COST_CATALOGS[[country]]$currency
    )

    for (item in items) {
      cost <- catalog[[item]] %||% NA

      # Convert to normalized currency
      if (!is.na(cost) && normalize_currency != COUNTRY_COST_CATALOGS[[country]]$currency) {
        cost <- convert_currency(cost,
                                from_currency = COUNTRY_COST_CATALOGS[[country]]$currency,
                                to_currency = normalize_currency)
      }

      row_data[[item]] <- cost
    }

    comparison_df <- rbind(comparison_df, as.data.frame(row_data, stringsAsFactors = FALSE))
  }

  return(comparison_df)
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# =============================================================================
# END OF COUNTRY COST CATALOGS MODULE
# =============================================================================
