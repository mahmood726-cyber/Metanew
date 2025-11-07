# =============================================================================
# EVIDENCEOS PRIME - US COST CATALOG MODULE
# =============================================================================
# Purpose: United States unit cost data for payer submissions
# Quality: Production-ready framework with representative US cost data
# Version: 1.0 - Complete Implementation
# US Compliance: Medicare reimbursement rates, commercial payer costs
# =============================================================================

#' Get US Cost Catalog
#'
#' @description
#' Retrieves unit cost data for specified US payer and cost category.
#'
#' @param payer Payer type ("Medicare", "Medicaid", "Commercial", "VA")
#' @param category Cost category (e.g., "physician", "hospital", "drugs")
#' @param year Reference year for costs (default: most recent available)
#'
#' @return List with unit costs for specified payer and category
#' @export
#'
#' @examples
#' \dontrun{
#' medicare_costs <- get_us_cost_catalog("Medicare", "physician")
#' commercial_costs <- get_us_cost_catalog("Commercial", "hospital")
#' }
get_us_cost_catalog <- function(payer, category = "all", year = NULL) {

  payer <- toupper(payer)

  if (!payer %in% names(US_COST_CATALOGS)) {
    stop(paste0("Payer '", payer, "' not available. ",
               "Available payers: ", paste(names(US_COST_CATALOGS), collapse = ", ")))
  }

  catalog <- US_COST_CATALOGS[[payer]]

  # Use specified year or most recent
  if (is.null(year)) {
    year <- catalog$reference_year
  }

  # Apply inflation adjustment if different year requested
  if (year != catalog$reference_year) {
    inflation_factor <- calculate_us_inflation_adjustment(catalog$reference_year, year)
    message(paste0("Note: Costs adjusted from ", catalog$reference_year, " to ", year,
                  " using inflation factor ", round(inflation_factor, 3)))
    catalog <- adjust_us_costs_for_inflation(catalog, inflation_factor)
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
# US COST CATALOGS DATA
# =============================================================================

US_COST_CATALOGS <- list(

  # ---------------------------------------------------------------------------
  # MEDICARE (USD, 2024)
  # ---------------------------------------------------------------------------
  MEDICARE = list(
    payer_name = "Medicare",
    currency = "USD",
    reference_year = 2024,
    source = "Medicare Physician Fee Schedule 2024, IPPS Final Rule 2024",

    physician_services = list(
      office_visit_new_level3 = 118,      # CPT 99203
      office_visit_established_level3 = 93,  # CPT 99213
      office_visit_established_level4 = 134, # CPT 99214
      consultation_initial = 156,          # CPT 99243
      emergency_department_level3 = 186,   # CPT 99283
      emergency_department_level4 = 281    # CPT 99284
    ),

    hospital_inpatient = list(
      # MS-DRG weights × base rate ($6,105 in 2024)
      medical_admission_uncomplicated = 3050,  # DRG weight ~0.5
      medical_admission_with_cc = 5495,        # DRG weight ~0.9
      medical_admission_with_mcc = 8546,       # DRG weight ~1.4
      surgical_admission_uncomplicated = 7326, # DRG weight ~1.2
      surgical_admission_with_cc = 10976,      # DRG weight ~1.8
      surgical_admission_with_mcc = 18315,     # DRG weight ~3.0
      icu_day = 2500,                          # Per day ICU supplement
      general_ward_day = 800                   # Per day general ward
    ),

    hospital_outpatient = list(
      # APC rates
      clinic_visit = 125,                  # APC 5012
      emergency_visit_level3 = 186,        # APC 5013
      emergency_visit_level4 = 428,        # APC 5014
      observation_per_hour = 110,
      same_day_surgery = 1850,
      chemotherapy_administration = 165,
      radiation_therapy_single_area = 88
    ),

    diagnostic_tests = list(
      chest_xray = 38,
      ct_scan_head = 215,
      ct_scan_chest = 246,
      ct_scan_abdomen = 285,
      mri_brain = 465,
      mri_spine = 488,
      ultrasound_abdomen = 145,
      echocardiogram = 178,
      ekg = 16,
      blood_test_cbc = 11,
      blood_test_metabolic_panel = 14,
      blood_test_lipid_panel = 18
    ),

    procedures = list(
      colonoscopy_screening = 585,
      colonoscopy_diagnostic = 675,
      upper_endoscopy = 515,
      cardiac_catheterization = 1285,
      coronary_angiography = 1580,
      pacemaker_insertion = 3250,
      hip_replacement = 15850,
      knee_replacement = 14680
    ),

    drugs = list(
      # Part B drugs (physician-administered)
      chemotherapy_per_infusion = 2500,  # Average
      biologic_per_infusion = 5000,      # Average
      # Part D drugs (retail pharmacy) - average wholesale price
      generic_oral_daily = 1.50,
      brand_oral_daily = 15.00,
      specialty_oral_daily = 120.00
    ),

    post_acute = list(
      skilled_nursing_facility_per_day = 575,
      home_health_visit = 158,
      hospice_per_day = 195,
      inpatient_rehab_per_day = 885
    )
  ),

  # ---------------------------------------------------------------------------
  # MEDICAID (USD, 2024)
  # ---------------------------------------------------------------------------
  MEDICAID = list(
    payer_name = "Medicaid (National Average)",
    currency = "USD",
    reference_year = 2024,
    source = "Medicaid State Plan Rates (National Average)",
    note = "Rates vary significantly by state; these are national averages",

    physician_services = list(
      office_visit_new_level3 = 65,       # ~55% of Medicare
      office_visit_established_level3 = 50,
      office_visit_established_level4 = 72,
      emergency_department_level3 = 125,
      emergency_department_level4 = 190
    ),

    hospital_inpatient = list(
      medical_admission_uncomplicated = 2100,  # ~69% of Medicare avg
      medical_admission_with_cc = 3800,
      medical_admission_with_mcc = 5900,
      surgical_admission_uncomplicated = 5050,
      surgical_admission_with_cc = 7580,
      surgical_admission_with_mcc = 12650,
      icu_day = 1750,
      general_ward_day = 550
    ),

    hospital_outpatient = list(
      clinic_visit = 85,
      emergency_visit_level3 = 125,
      emergency_visit_level4 = 290,
      same_day_surgery = 1280,
      chemotherapy_administration = 115
    ),

    diagnostic_tests = list(
      chest_xray = 26,
      ct_scan_head = 145,
      ct_scan_chest = 165,
      mri_brain = 315,
      echocardiogram = 120,
      ekg = 11,
      blood_test_cbc = 7,
      blood_test_metabolic_panel = 9
    ),

    drugs = list(
      # Medicaid drug rebates result in lower net costs
      generic_oral_daily = 0.85,    # After rebates
      brand_oral_daily = 8.50,      # After rebates
      specialty_oral_daily = 75.00  # After rebates
    ),

    post_acute = list(
      skilled_nursing_facility_per_day = 385,
      home_health_visit = 105,
      hospice_per_day = 165
    )
  ),

  # ---------------------------------------------------------------------------
  # COMMERCIAL (USD, 2024)
  # ---------------------------------------------------------------------------
  COMMERCIAL = list(
    payer_name = "Commercial Payers (Average)",
    currency = "USD",
    reference_year = 2024,
    source = "FAIR Health Commercial Claims Database 2024, HCCI Analysis",
    note = "Represents average commercial insurance reimbursement rates",

    physician_services = list(
      office_visit_new_level3 = 195,       # ~165% of Medicare
      office_visit_established_level3 = 152,
      office_visit_established_level4 = 220,
      consultation_initial = 255,
      emergency_department_level3 = 485,
      emergency_department_level4 = 725
    ),

    hospital_inpatient = list(
      medical_admission_uncomplicated = 8500,   # Higher than Medicare
      medical_admission_with_cc = 15300,
      medical_admission_with_mcc = 23800,
      surgical_admission_uncomplicated = 20400,
      surgical_admission_with_cc = 30600,
      surgical_admission_with_mcc = 51000,
      icu_day = 5500,
      general_ward_day = 2200
    ),

    hospital_outpatient = list(
      clinic_visit = 205,
      emergency_visit_level3 = 485,
      emergency_visit_level4 = 1115,
      observation_per_hour = 285,
      same_day_surgery = 5100,
      chemotherapy_administration = 430,
      radiation_therapy_single_area = 230
    ),

    diagnostic_tests = list(
      chest_xray = 98,
      ct_scan_head = 560,
      ct_scan_chest = 640,
      ct_scan_abdomen = 740,
      mri_brain = 1210,
      mri_spine = 1270,
      ultrasound_abdomen = 378,
      echocardiogram = 463,
      ekg = 42,
      blood_test_cbc = 29,
      blood_test_metabolic_panel = 36,
      blood_test_lipid_panel = 47
    ),

    procedures = list(
      colonoscopy_screening = 1520,
      colonoscopy_diagnostic = 1755,
      upper_endoscopy = 1340,
      cardiac_catheterization = 3340,
      coronary_angiography = 4110,
      pacemaker_insertion = 8450,
      hip_replacement = 41200,
      knee_replacement = 38200
    ),

    drugs = list(
      # Commercial rates higher than Medicare
      chemotherapy_per_infusion = 4500,
      biologic_per_infusion = 9000,
      generic_oral_daily = 2.50,
      brand_oral_daily = 32.00,
      specialty_oral_daily = 250.00
    ),

    post_acute = list(
      skilled_nursing_facility_per_day = 650,
      home_health_visit = 180,
      hospice_per_day = 210,
      inpatient_rehab_per_day = 1350
    )
  ),

  # ---------------------------------------------------------------------------
  # VETERANS AFFAIRS (USD, 2024)
  # ---------------------------------------------------------------------------
  VA = list(
    payer_name = "Veterans Affairs",
    currency = "USD",
    reference_year = 2024,
    source = "VA Cost Data, Federal Supply Schedule",
    note = "VA integrated healthcare system - costs differ from fee-for-service",

    healthcare_utilization = list(
      primary_care_visit = 125,
      specialty_care_visit = 185,
      emergency_visit = 485,
      urgent_care_visit = 135,
      telehealth_visit = 45
    ),

    hospital_care = list(
      medical_admission_per_day = 1850,
      surgical_admission_per_day = 2450,
      icu_per_day = 4200,
      mental_health_admission_per_day = 950,
      substance_abuse_treatment_per_day = 425
    ),

    diagnostic_tests = list(
      chest_xray = 35,
      ct_scan_head = 195,
      ct_scan_chest = 225,
      mri_brain = 425,
      echocardiogram = 165,
      ekg = 15,
      blood_test_cbc = 10,
      blood_test_metabolic_panel = 13
    ),

    drugs = list(
      # VA negotiated pricing (Federal Supply Schedule)
      generic_oral_daily = 0.50,     # Lowest costs due to formulary + FSS
      brand_oral_daily = 5.00,
      specialty_oral_daily = 50.00
    ),

    post_acute = list(
      nursing_home_per_day = 385,
      home_based_primary_care_visit = 145,
      hospice_per_day = 175
    ),

    mental_health = list(
      # VA emphasis on mental health services
      individual_therapy_session = 95,
      group_therapy_session = 35,
      ptsd_treatment_session = 115,
      substance_abuse_counseling = 75
    )
  )
)


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#' Calculate US Inflation Adjustment Factor
#'
#' @description
#' Calculates inflation adjustment factor between two years using
#' US Medical Care CPI.
#'
#' @param from_year Base year
#' @param to_year Target year
#'
#' @return Inflation adjustment factor
#' @export
calculate_us_inflation_adjustment <- function(from_year, to_year) {

  # US Medical Care CPI average annual inflation (2020-2024 ~4%)
  avg_annual_inflation <- 0.04

  year_diff <- to_year - from_year
  inflation_factor <- (1 + avg_annual_inflation) ^ year_diff

  return(inflation_factor)
}


#' Adjust US Costs for Inflation
#'
#' @description
#' Adjusts all costs in catalog by inflation factor.
#'
#' @param catalog Cost catalog
#' @param inflation_factor Inflation adjustment factor
#'
#' @return Adjusted cost catalog
#' @export
adjust_us_costs_for_inflation <- function(catalog, inflation_factor) {

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


#' Convert Medicare to Commercial Rates
#'
#' @description
#' Converts Medicare rates to commercial payer equivalent using
#' typical reimbursement ratios.
#'
#' @param medicare_amount Medicare amount
#' @param service_type Service type ("physician", "hospital_inpatient", "hospital_outpatient")
#'
#' @return Estimated commercial amount
#' @export
convert_medicare_to_commercial <- function(medicare_amount, service_type = "physician") {

  # Typical commercial/Medicare ratios (varies by market)
  conversion_factors <- list(
    physician = 1.65,              # Commercial pays ~165% of Medicare
    hospital_inpatient = 2.20,     # Commercial pays ~220% of Medicare
    hospital_outpatient = 2.60,    # Commercial pays ~260% of Medicare
    diagnostic = 2.60,
    procedures = 2.40,
    post_acute = 1.13
  )

  if (!service_type %in% names(conversion_factors)) {
    warning(paste0("Unknown service type: ", service_type, ". Using 2.0 default."))
    factor <- 2.0
  } else {
    factor <- conversion_factors[[service_type]]
  }

  commercial_amount <- medicare_amount * factor

  message(paste0("Note: Medicare to commercial conversion using factor ", factor,
                ". Market rates vary."))

  return(commercial_amount)
}


#' List Available US Payers
#'
#' @description
#' Lists all payers with available cost data.
#'
#' @export
list_us_cost_catalog_payers <- function() {

  payers <- names(US_COST_CATALOGS)

  cat("\n")
  cat("==============================================================================\n")
  cat("  AVAILABLE US COST CATALOGS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("%-15s %-35s %-10s %-15s\n", "Code", "Payer", "Currency", "Reference Year"))
  cat("------------------------------------------------------------------------------\n")

  for (code in payers) {
    catalog <- US_COST_CATALOGS[[code]]
    cat(sprintf("%-15s %-35s %-10s %-15d\n",
                code,
                catalog$payer_name,
                catalog$currency,
                catalog$reference_year))
  }

  cat("==============================================================================\n\n")

  cat("Categories: physician_services, hospital_inpatient, hospital_outpatient,\n")
  cat("            diagnostic_tests, procedures, drugs, post_acute\n")
  cat("Usage: get_us_cost_catalog(\"Medicare\", \"physician_services\")\n\n")

  invisible(payers)
}


#' Compare Costs Across US Payers
#'
#' @description
#' Compares specific cost items across multiple US payers.
#'
#' @param payers Vector of payer codes
#' @param category Cost category
#' @param items Vector of specific items to compare
#'
#' @return Data frame with cost comparison
#' @export
compare_us_payer_costs <- function(payers,
                                   category,
                                   items) {

  comparison_df <- data.frame(
    Payer = character(0),
    Currency = character(0),
    stringsAsFactors = FALSE
  )

  for (item in items) {
    comparison_df[[item]] <- numeric(0)
  }

  for (payer in payers) {
    catalog <- get_us_cost_catalog(payer, category)

    row_data <- list(
      Payer = US_COST_CATALOGS[[payer]]$payer_name,
      Currency = US_COST_CATALOGS[[payer]]$currency
    )

    for (item in items) {
      cost <- catalog[[item]] %||% NA
      row_data[[item]] <- cost
    }

    comparison_df <- rbind(comparison_df, as.data.frame(row_data, stringsAsFactors = FALSE))
  }

  return(comparison_df)
}


#' Calculate PMPM from Annual Cost
#'
#' @description
#' Converts annual cost per patient to Per-Member-Per-Month (PMPM) metric.
#'
#' @param annual_cost_per_patient Annual cost per patient
#' @param prevalence_rate Disease prevalence in population (0-1)
#'
#' @return PMPM cost
#' @export
calculate_pmpm_from_annual <- function(annual_cost_per_patient, prevalence_rate) {

  # PMPM = (Annual cost × Prevalence) / 12 months
  pmpm <- (annual_cost_per_patient * prevalence_rate) / 12

  return(pmpm)
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# =============================================================================
# END OF US COST CATALOG MODULE
# =============================================================================
