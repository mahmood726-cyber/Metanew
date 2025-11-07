# =============================================================================
# EVIDENCEOS PRIME - MULTI-JURISDICTION CONFIGURATION SYSTEM
# =============================================================================
# Purpose: Country-specific HTA requirements for 27+ jurisdictions
# Version: 1.0 - EU HTA Compliance
# Date: 2025-11-07
# =============================================================================

#' Get jurisdiction configuration
#'
#' @param jurisdiction ISO code or full name (e.g., "UK", "DE", "FR", "NL", "SE")
#' @return List of jurisdiction-specific requirements
#' @export
get_jurisdiction_config <- function(jurisdiction) {

  # Map common names to standard codes
  jurisdiction_map <- c(
    "UK" = "UK_NICE",
    "United Kingdom" = "UK_NICE",
    "NICE" = "UK_NICE",
    "DE" = "DE_IQWIG",
    "Germany" = "DE_IQWIG",
    "IQWiG" = "DE_IQWIG",
    "G-BA" = "DE_IQWIG",
    "FR" = "FR_HAS",
    "France" = "FR_HAS",
    "HAS" = "FR_HAS",
    "NL" = "NL_ZIN",
    "Netherlands" = "NL_ZIN",
    "ZIN" = "NL_ZIN",
    "SE" = "SE_TLV",
    "Sweden" = "SE_TLV",
    "TLV" = "SE_TLV",
    "ES" = "ES",
    "Spain" = "ES",
    "IT" = "IT",
    "Italy" = "IT",
    "PL" = "PL",
    "Poland" = "PL",
    "BE" = "BE_KCE",
    "Belgium" = "BE_KCE",
    "KCE" = "BE_KCE",
    "NO" = "NO",
    "Norway" = "NO",
    "DK" = "DK",
    "Denmark" = "DK",
    "FI" = "FI",
    "Finland" = "FI",
    "AT" = "AT",
    "Austria" = "AT",
    "PT" = "PT",
    "Portugal" = "PT",
    "IE" = "IE",
    "Ireland" = "IE"
  )

  # Normalize jurisdiction code
  if (jurisdiction %in% names(jurisdiction_map)) {
    jurisdiction <- jurisdiction_map[[jurisdiction]]
  }

  # Get configuration
  if (jurisdiction %in% names(JURISDICTION_CONFIGS)) {
    config <- JURISDICTION_CONFIGS[[jurisdiction]]
    config$code <- jurisdiction
    return(config)
  } else {
    warning(paste0("Jurisdiction '", jurisdiction, "' not found. Using generic European config."))
    config <- JURISDICTION_CONFIGS$EU_GENERIC
    config$code <- "EU_GENERIC"
    return(config)
  }
}

#' Global jurisdiction configurations
#' @keywords internal
JURISDICTION_CONFIGS <- list(

  # ===========================================================================
  # UNITED KINGDOM - NICE
  # ===========================================================================
  UK_NICE = list(
    name = "United Kingdom (NICE)",
    agency = "National Institute for Health and Care Excellence",

    # Discount rates
    discount_rate_costs = 0.035,
    discount_rate_health = 0.015,
    discount_differential = TRUE,
    discount_rationale = "NICE Reference Case: 3.5% costs, 1.5% health effects",

    # Cost perspective
    perspective_required = "NHS_PSS",
    perspective_allowed = c("NHS_PSS"),
    perspective_rationale = "NHS and Personal Social Services perspective mandatory",

    # Utility measurement
    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L", "EQ-5D"),
    utility_tariff = "UK_crosswalk",
    utility_rationale = "EQ-5D with UK population tariff mandatory",

    # Methods
    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = FALSE,
    budget_impact_required = FALSE,
    equity_analysis = FALSE,

    # Comparator
    comparator_type = "established_clinical_practice",

    # Enforcement level
    enforcement = "strict"  # strict, moderate, guidance
  ),

  # ===========================================================================
  # GERMANY - IQWiG / G-BA
  # ===========================================================================
  DE_IQWIG = list(
    name = "Germany (IQWiG/G-BA)",
    agency = "Institute for Quality and Efficiency in Health Care",

    # Discount rates
    discount_rate_costs = 0.03,
    discount_rate_health = 0.03,
    discount_differential = FALSE,
    discount_rationale = "3% for both costs and health effects",

    # Cost perspective
    perspective_required = "SHI",  # Statutory Health Insurance
    perspective_allowed = c("SHI", "healthcare_payer"),
    perspective_rationale = "Statutory health insurance perspective",

    # Utility measurement
    utility_instrument_required = NULL,  # Flexible
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L", "SF-6D", "HUI3"),
    utility_tariff = "German",
    utility_rationale = "Multiple instruments accepted, prefer German tariffs",

    # Methods
    psa_required = FALSE,  # Not always required for early benefit assessment
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = FALSE,
    budget_impact_required = FALSE,
    equity_analysis = FALSE,

    # Comparator
    comparator_type = "appropriate_comparator_therapy",

    # German-specific
    efficiency_frontier = TRUE,
    subgroup_analysis = "mandatory",
    direct_comparison_preferred = TRUE,

    # Enforcement level
    enforcement = "moderate"
  ),

  # ===========================================================================
  # FRANCE - HAS
  # ===========================================================================
  FR_HAS = list(
    name = "France (HAS)",
    agency = "Haute Autorité de Santé",

    # Discount rates
    discount_rate_costs = 0.025,
    discount_rate_health = 0.025,
    discount_differential = FALSE,
    discount_rationale = "2.5% for both costs and health effects (official)",

    # Cost perspective
    perspective_required = "societal",
    perspective_allowed = c("societal", "healthcare_payer", "collective"),
    perspective_rationale = "Societal perspective preferred, includes productivity costs",

    # Utility measurement
    utility_instrument_required = NULL,  # Flexible
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L", "SF-6D", "LY"),
    utility_tariff = "French",
    utility_rationale = "Multiple instruments accepted, LY sometimes preferred over QALY",

    # Methods
    psa_required = FALSE,  # Recommended but not mandatory
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = TRUE,  # Implicit through acceptability thresholds
    budget_impact_required = FALSE,
    equity_analysis = TRUE,  # Explicit requirement

    # Comparator
    comparator_type = "standard_care",

    # French-specific
    productivity_costs = TRUE,
    outcome_type_flexible = TRUE,  # Can use LY instead of QALY

    # Enforcement level
    enforcement = "moderate"
  ),

  # ===========================================================================
  # NETHERLANDS - ZIN
  # ===========================================================================
  NL_ZIN = list(
    name = "Netherlands (ZIN)",
    agency = "Zorginstituut Nederland",

    # Discount rates
    discount_rate_costs = 0.04,
    discount_rate_health = 0.015,
    discount_differential = TRUE,
    discount_rationale = "4% for costs, 1.5% for health effects",

    # Cost perspective
    perspective_required = c("healthcare", "societal"),  # BOTH required
    perspective_allowed = c("healthcare", "societal", "healthcare_payer"),
    perspective_rationale = "Both healthcare and societal perspectives required",

    # Utility measurement
    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L"),
    utility_tariff = "Dutch",
    utility_rationale = "EQ-5D with Dutch tariff preferred",

    # Methods
    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = TRUE,  # Proportional shortfall
    budget_impact_required = TRUE,
    equity_analysis = TRUE,

    # Comparator
    comparator_type = "standard_care",

    # Dutch-specific
    proportional_shortfall = TRUE,
    proportional_shortfall_alpha = 1.2,
    multi_perspective = TRUE,  # Both perspectives in parallel

    # Enforcement level
    enforcement = "strict"
  ),

  # ===========================================================================
  # SWEDEN - TLV
  # ===========================================================================
  SE_TLV = list(
    name = "Sweden (TLV)",
    agency = "Tandvårds- och läkemedelsförmånsverket",

    # Discount rates
    discount_rate_costs = 0.03,
    discount_rate_health = 0.03,
    discount_differential = FALSE,
    discount_rationale = "3% for both costs and health effects",

    # Cost perspective
    perspective_required = "healthcare_payer",
    perspective_allowed = c("healthcare_payer", "healthcare"),
    perspective_rationale = "Healthcare payer perspective",

    # Utility measurement
    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L"),
    utility_tariff = "Swedish",
    utility_rationale = "EQ-5D with Swedish tariff",

    # Methods
    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = TRUE,  # Similar to Dutch system
    budget_impact_required = FALSE,
    equity_analysis = TRUE,

    # Comparator
    comparator_type = "standard_treatment",

    # Swedish-specific
    severity_weighting_method = "proportional_shortfall",
    ethical_platform = TRUE,

    # Enforcement level
    enforcement = "strict"
  ),

  # ===========================================================================
  # BELGIUM - KCE
  # ===========================================================================
  BE_KCE = list(
    name = "Belgium (KCE)",
    agency = "Belgian Health Care Knowledge Centre",

    # Discount rates
    discount_rate_costs = 0.03,
    discount_rate_health = 0.015,
    discount_differential = TRUE,
    discount_rationale = "3% for costs, 1.5% for health effects",

    # Cost perspective
    perspective_required = NULL,  # Flexible
    perspective_allowed = c("healthcare_payer", "societal", "healthcare"),
    perspective_rationale = "Flexible, often societal perspective preferred",

    # Utility measurement
    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L", "SF-6D"),
    utility_tariff = "Belgian",
    utility_rationale = "EQ-5D preferred with Belgian tariff",

    # Methods
    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = FALSE,
    budget_impact_required = FALSE,
    equity_analysis = TRUE,

    # Comparator
    comparator_type = "standard_care",

    # Enforcement level
    enforcement = "moderate"
  ),

  # ===========================================================================
  # SPAIN
  # ===========================================================================
  ES = list(
    name = "Spain",
    agency = "Various regional agencies",

    discount_rate_costs = 0.03,
    discount_rate_health = 0.03,
    discount_differential = FALSE,

    perspective_required = "healthcare",
    perspective_allowed = c("healthcare", "healthcare_payer", "NHS"),

    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L"),
    utility_tariff = "Spanish",

    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = FALSE,
    budget_impact_required = FALSE,
    equity_analysis = FALSE,

    enforcement = "moderate"
  ),

  # ===========================================================================
  # ITALY
  # ===========================================================================
  IT = list(
    name = "Italy (AIFA)",
    agency = "Italian Medicines Agency",

    discount_rate_costs = 0.03,
    discount_rate_health = 0.03,
    discount_differential = FALSE,

    perspective_required = "NHS",
    perspective_allowed = c("NHS", "healthcare"),

    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L"),
    utility_tariff = "Italian",

    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = FALSE,
    budget_impact_required = TRUE,
    equity_analysis = FALSE,

    enforcement = "moderate"
  ),

  # ===========================================================================
  # POLAND
  # ===========================================================================
  PL = list(
    name = "Poland (AOTM)",
    agency = "Agency for Health Technology Assessment",

    discount_rate_costs = 0.05,
    discount_rate_health = 0.05,
    discount_differential = FALSE,

    perspective_required = "public_payer",
    perspective_allowed = c("public_payer", "healthcare"),

    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L"),
    utility_tariff = "Polish",

    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = FALSE,
    budget_impact_required = TRUE,
    equity_analysis = FALSE,

    enforcement = "strict"
  ),

  # ===========================================================================
  # NORWAY
  # ===========================================================================
  NO = list(
    name = "Norway",
    agency = "Norwegian Medicines Agency",

    discount_rate_costs = 0.04,
    discount_rate_health = 0.04,
    discount_differential = FALSE,

    perspective_required = "healthcare",
    perspective_allowed = c("healthcare", "healthcare_payer"),

    utility_instrument_required = "EQ-5D",
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L"),
    utility_tariff = "Norwegian",

    psa_required = TRUE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = TRUE,  # Similar to Sweden
    budget_impact_required = FALSE,
    equity_analysis = FALSE,

    proportional_shortfall = TRUE,

    enforcement = "moderate"
  ),

  # ===========================================================================
  # GENERIC EUROPEAN
  # ===========================================================================
  EU_GENERIC = list(
    name = "Generic European",
    agency = "European Union (Generic)",

    discount_rate_costs = 0.03,
    discount_rate_health = 0.03,
    discount_differential = FALSE,
    discount_rationale = "Generic 3% for both (common EU rate)",

    perspective_required = NULL,
    perspective_allowed = c("healthcare", "healthcare_payer", "societal", "NHS", "SHI"),
    perspective_rationale = "Flexible - varies by country",

    utility_instrument_required = NULL,
    utility_instrument_allowed = c("EQ-5D-3L", "EQ-5D-5L", "SF-6D", "HUI3"),
    utility_tariff = "Country-specific",
    utility_rationale = "Flexible - multiple instruments accepted",

    psa_required = FALSE,
    psa_min_iterations = 1000,
    half_cycle_correction = TRUE,
    age_weighting = FALSE,
    severity_weighting = FALSE,
    budget_impact_required = FALSE,
    equity_analysis = FALSE,

    enforcement = "guidance"  # Guidance only, not enforcement
  )
)

#' Validate parameters against jurisdiction requirements
#'
#' @param params Parameter list
#' @param jurisdiction Jurisdiction code
#' @param enforcement_level "strict", "moderate", or "guidance"
#' @return Validated params with warnings/errors as appropriate
#' @export
validate_jurisdiction_compliance <- function(params, jurisdiction,
                                            enforcement_level = NULL) {

  config <- get_jurisdiction_config(jurisdiction)

  # Override enforcement if specified
  if (is.null(enforcement_level)) {
    enforcement_level <- config$enforcement
  }

  # Validate discount rates
  params <- validate_jurisdiction_discount_rates(params, config, enforcement_level)

  # Validate perspective
  params <- validate_jurisdiction_perspective(params, config, enforcement_level)

  # Validate utility instrument
  params <- validate_jurisdiction_utility(params, config, enforcement_level)

  # Validate PSA
  params <- validate_jurisdiction_psa(params, config, enforcement_level)

  return(params)
}

#' @keywords internal
validate_jurisdiction_discount_rates <- function(params, config, enforcement) {

  has_diff <- !is.null(params$discount_rate_costs) && !is.null(params$discount_rate_health)
  has_single <- !is.null(params$discount_rate)

  if (!has_diff && !has_single) {
    stop("Discount rate(s) required. Provide either 'discount_rate' or both 'discount_rate_costs' and 'discount_rate_health'")
  }

  # Check if differential discounting is used/required
  if (config$discount_differential && has_single) {
    msg <- paste0(config$name, " uses differential discounting: ",
                 config$discount_rate_costs * 100, "% for costs, ",
                 config$discount_rate_health * 100, "% for health. ",
                 "Consider using discount_rate_costs and discount_rate_health parameters.")

    if (enforcement == "strict") {
      warning(msg)
    } else {
      message(paste0("Note: ", msg))
    }
  }

  # Check rates against jurisdiction standards
  if (has_diff) {
    check_rate(params$discount_rate_costs, config$discount_rate_costs,
              "costs", config$name, enforcement)
    check_rate(params$discount_rate_health, config$discount_rate_health,
              "health", config$name, enforcement)
  } else {
    expected <- config$discount_rate_costs  # Use costs rate as general guide
    check_rate(params$discount_rate, expected, "both", config$name, enforcement)
  }

  return(params)
}

#' @keywords internal
check_rate <- function(actual, expected, type, jurisdiction, enforcement) {

  if (is.null(actual) || is.null(expected)) return(invisible())

  diff <- abs(actual - expected)

  if (diff > 0.005) {  # More than 0.5% different
    msg <- paste0(jurisdiction, " typically uses ", expected * 100, "% for ", type, ". ",
                 "You specified ", actual * 100, "%. ",
                 "Consider alignment or provide justification.")

    if (enforcement == "strict") {
      warning(msg)
    } else {
      message(paste0("Note: ", msg))
    }
  }
}

#' @keywords internal
validate_jurisdiction_perspective <- function(params, config, enforcement) {

  if (is.null(params$cost_perspective)) {
    if (!is.null(config$perspective_required)) {
      if (length(config$perspective_required) == 1) {
        params$cost_perspective <- config$perspective_required
        message(paste0("✓ Using ", config$perspective_required, " perspective (", config$name, " default)"))
      } else {
        message(paste0("Note: ", config$name, " requires multiple perspectives: ",
                      paste(config$perspective_required, collapse = " + ")))
      }
    }
  }

  # Check if perspective is allowed
  if (!is.null(params$cost_perspective) && !is.null(config$perspective_allowed)) {
    if (!params$cost_perspective %in% config$perspective_allowed) {
      msg <- paste0(config$name, " typically uses perspectives: ",
                   paste(config$perspective_allowed, collapse = ", "), ". ",
                   "You specified '", params$cost_perspective, "'. ",
                   "Verify this is appropriate or provide justification.")

      if (enforcement == "strict") {
        warning(msg)
      } else {
        message(paste0("Note: ", msg))
      }
    }
  }

  return(params)
}

#' @keywords internal
validate_jurisdiction_utility <- function(params, config, enforcement) {

  if (is.null(params$utility_source)) {
    if (!is.null(config$utility_instrument_required)) {
      msg <- paste0(config$name, " requires documenting utility source. ",
                   "Recommended: ", paste(config$utility_instrument_allowed, collapse = ", "))
      message(paste0("Note: ", msg))
    }
    return(params)
  }

  # Check if instrument is allowed
  if (!is.null(config$utility_instrument_allowed)) {
    if (!params$utility_source %in% config$utility_instrument_allowed) {
      msg <- paste0(config$name, " typically uses: ",
                   paste(config$utility_instrument_allowed, collapse = ", "), ". ",
                   "You specified '", params$utility_source, "'. ",
                   "Verify this is appropriate or provide justification.")

      if (enforcement == "strict") {
        warning(msg)
      } else {
        message(paste0("Note: ", msg))
      }
    } else {
      message(paste0("✓ Utility source (", params$utility_source, ") accepted by ", config$name))
    }
  }

  return(params)
}

#' @keywords internal
validate_jurisdiction_psa <- function(params, config, enforcement) {

  if (config$psa_required) {
    if (is.null(params$n_iterations) || params$n_iterations == 0) {
      msg <- paste0(config$name, " requires PSA with at least ",
                   config$psa_min_iterations, " iterations")

      if (enforcement == "strict") {
        stop(msg)
      } else {
        warning(msg)
      }
    } else if (params$n_iterations < config$psa_min_iterations) {
      msg <- paste0(config$name, " recommends at least ",
                   config$psa_min_iterations, " PSA iterations. ",
                   "You specified ", params$n_iterations)

      if (enforcement == "strict") {
        warning(msg)
      } else {
        message(paste0("Note: ", msg))
      }
    }
  }

  return(params)
}

#' List all available jurisdictions
#' @export
list_jurisdictions <- function() {
  juris <- names(JURISDICTION_CONFIGS)

  cat("\n")
  cat("==================================================\n")
  cat("  AVAILABLE HTA JURISDICTIONS\n")
  cat("==================================================\n\n")

  for (j in juris) {
    config <- JURISDICTION_CONFIGS[[j]]
    cat(sprintf("%-15s %s\n", j, config$name))
  }

  cat("\n")
  cat("Use: get_jurisdiction_config(\"CODE\")\n")
  cat("==================================================\n\n")
}
