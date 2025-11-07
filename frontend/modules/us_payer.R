# =============================================================================
# EVIDENCEOS PRIME - US PAYER REQUIREMENTS MODULE
# =============================================================================
# Purpose: US payer evidence requirements (ICER, AMCP, Medicare/Medicaid)
# Quality: Production-ready with US health system standards
# Version: 1.0 - Complete Implementation
# US Compliance: ICER Value Framework, AMCP Format v4.1, CMS requirements
# =============================================================================

#' ICER Value Assessment Framework
#'
#' @description
#' Institute for Clinical and Economic Review (ICER) value framework standards.
#' Updated to reflect 2020-2023 framework revisions.
#'
#' @export
ICER_VALUE_FRAMEWORK <- list(

  cost_effectiveness_thresholds = list(
    base = list(
      lower = 50000,   # $50,000/QALY
      middle = 100000, # $100,000/QALY (base case)
      upper = 150000,  # $150,000/QALY
      higher = 175000  # $175,000/QALY (higher threshold introduced 2020)
    ),
    health_benefit_price_benchmark = "ICER target price for value at $100k-150k/QALY",
    budget_impact_threshold = 915000000  # $915M over 5 years triggers affordability concerns
  ),

  value_domains = list(
    comparative_clinical_effectiveness = list(
      required = TRUE,
      elements = c("efficacy", "safety", "patient_experience")
    ),
    incremental_cost_effectiveness = list(
      required = TRUE,
      perspectives = c("healthcare_sector", "societal"),
      time_horizon = "lifetime_preferred"
    ),
    other_benefits = list(
      reduction_in_uncertainty = "Value of reducing clinical uncertainty",
      insurance_value = "Protection against catastrophic costs",
      severity_of_disease = "Disproportionate impact on quality of life",
      novel_mechanism = "First in class with new mechanism",
      public_health_impact = "Spillover effects to population"
    ),
    contextual_considerations = list(
      unmet_need = "Availability of alternative treatments",
      equity = "Impact on disadvantaged populations",
      innovation = "Potential for future development"
    )
  ),

  evidence_requirements = list(
    clinical_evidence = "RCT preferred, RWE supplemental",
    economic_model = "Transparent model with all assumptions documented",
    budget_impact = "5-year budget impact required",
    uncertainty_analysis = "PSA and scenario analysis required"
  ),

  voting_framework = list(
    clinical_effectiveness = "High, Comparable/Incremental, Low certainty",
    long_term_value = "High, Intermediate, Low value for money",
    short_term_affordability = "Affordable, Not affordable at budget threshold"
  )
)


#' AMCP Format Requirements
#'
#' @description
#' Academy of Managed Care Pharmacy (AMCP) Format for Formulary Submissions v4.1.
#'
#' @export
AMCP_FORMAT_V4 <- list(

  dossier_sections = list(
    section_1 = "Executive Summary",
    section_2 = "Product & Clinical Overview",
    section_3 = "Disease & Epidemiology",
    section_4 = "Treatment Guidelines & Algorithms",
    section_5 = "Efficacy Evidence",
    section_6 = "Safety Evidence",
    section_7 = "Economic Evidence",
    section_8 = "Budget Impact",
    section_9 = "References & Appendices"
  ),

  section_7_requirements = list(
    pharmacoeconomic_studies = "Published and unpublished studies",
    model_description = "Structure, assumptions, data sources",
    perspective = "US payer perspective required",
    time_horizon = "Adequate to capture relevant outcomes",
    discounting = "3% annually for costs and outcomes",
    comparators = "Relevant alternative treatments",
    sensitivity_analysis = "One-way, multi-way, probabilistic",
    results = "Base case, scenarios, subgroups"
  ),

  section_8_requirements = list(
    budget_impact_analysis = "Required",
    time_horizon = "3-5 years",
    perspective = "Payer perspective",
    eligible_population = "Plan-specific estimates",
    market_uptake = "Realistic uptake assumptions",
    cost_offsets = "Include relevant medical cost offsets"
  )
)


#' Run US Payer Cost-Effectiveness Analysis
#'
#' @description
#' Performs cost-effectiveness analysis from US payer perspective following
#' ICER and AMCP standards.
#'
#' @param params Model parameters
#' @param base_prob_prog Baseline progression probability
#' @param base_prob_death Baseline death probability
#' @param hr_progression Hazard ratio for progression
#' @param hr_death Hazard ratio for death
#' @param payer_type Payer type ("commercial", "medicare", "medicaid")
#' @param include_productivity Whether to include productivity costs
#'
#' @return US payer CEA results
#' @export
#'
#' @examples
#' \dontrun{
#' us_payer_cea <- run_us_payer_cea(
#'   params = model_params,
#'   base_prob_prog = 0.05,
#'   base_prob_death = 0.01,
#'   hr_progression = list(hr = 0.65, source = "trial"),
#'   hr_death = list(hr = 0.75, source = "trial"),
#'   payer_type = "commercial"
#' )
#' }
run_us_payer_cea <- function(params,
                             base_prob_prog,
                             base_prob_death,
                             hr_progression,
                             hr_death,
                             payer_type = "commercial",
                             include_productivity = FALSE) {

  # Source enhanced model if not loaded
  if (!exists("run_markov_model_enhanced", mode = "function")) {
    source("frontend/modules/enhanced_he_model.R", local = TRUE)
  }

  # ==========================================================================
  # CONFIGURE US PAYER PERSPECTIVE
  # ==========================================================================

  # US standard: 3% discount rate for both costs and outcomes
  params$discount_rate_costs <- 0.03
  params$discount_rate_health <- 0.03

  # Cost perspective
  if (payer_type == "commercial") {
    params$cost_perspective <- "commercial_payer"
  } else if (payer_type == "medicare") {
    params$cost_perspective <- "medicare"
  } else if (payer_type == "medicaid") {
    params$cost_perspective <- "medicaid"
  } else {
    stop("payer_type must be 'commercial', 'medicare', or 'medicaid'")
  }

  # Productivity costs (optional, for societal perspective)
  if (include_productivity) {
    message("Including productivity costs for societal perspective")
    params$include_productivity_costs <- TRUE
  }

  # ==========================================================================
  # RUN BASE CASE ANALYSIS
  # ==========================================================================

  message(paste0("Running US payer CEA from ", payer_type, " perspective..."))

  base_results <- run_markov_model_enhanced(
    params = params,
    base_prob_prog = base_prob_prog,
    base_prob_death = base_prob_death,
    hr_progression = hr_progression,
    hr_death = hr_death,
    validate_inputs = TRUE,
    jurisdiction = NULL  # US doesn't use EU jurisdiction configs
  )

  # ==========================================================================
  # ICER VALUE ASSESSMENT
  # ==========================================================================

  icer_assessment <- assess_icer_value(
    icer = base_results$icer,
    incremental_qalys = base_results$incremental_qalys,
    incremental_costs = base_results$incremental_costs
  )

  # ==========================================================================
  # HEALTH BENEFIT PRICE BENCHMARK
  # ==========================================================================

  health_benefit_price <- calculate_health_benefit_price(
    incremental_qalys = base_results$incremental_qalys,
    incremental_costs = base_results$incremental_costs,
    treatment_cost = params$cost_treatment %||% params$cost_stable,
    target_threshold = 150000  # ICER upper threshold
  )

  # ==========================================================================
  # COMPILE US PAYER RESULTS
  # ==========================================================================

  us_payer_results <- list(
    base_results = base_results,
    payer_type = payer_type,
    icer_assessment = icer_assessment,
    health_benefit_price = health_benefit_price,
    discount_rate = 0.03,
    include_productivity = include_productivity
  )

  class(us_payer_results) <- c("us_payer_cea", "list")
  return(us_payer_results)
}


#' Assess ICER Value
#'
#' @description
#' Assesses value according to ICER framework thresholds.
#'
#' @param icer Incremental cost-effectiveness ratio
#' @param incremental_qalys Incremental QALYs
#' @param incremental_costs Incremental costs
#'
#' @return ICER value assessment
#' @export
assess_icer_value <- function(icer, incremental_qalys, incremental_costs) {

  thresholds <- ICER_VALUE_FRAMEWORK$cost_effectiveness_thresholds$base

  # Value rating
  if (!is.finite(icer)) {
    if (incremental_costs < 0 && incremental_qalys > 0) {
      value_rating <- "DOMINANT - Treatment less costly and more effective"
      color_code <- "green"
    } else {
      value_rating <- "DOMINATED - Treatment more costly and less effective"
      color_code <- "red"
    }

  } else if (icer < thresholds$lower) {
    value_rating <- "HIGH VALUE - ICER below $50,000/QALY"
    color_code <- "green"

  } else if (icer <= thresholds$middle) {
    value_rating <- "INTERMEDIATE VALUE - ICER $50,000-$100,000/QALY"
    color_code <- "yellow"

  } else if (icer <= thresholds$upper) {
    value_rating <- "MODERATE VALUE - ICER $100,000-$150,000/QALY"
    color_code <- "orange"

  } else if (icer <= thresholds$higher) {
    value_rating <- "LOW VALUE - ICER $150,000-$175,000/QALY"
    color_code <- "orange"

  } else {
    value_rating <- "POOR VALUE - ICER exceeds $175,000/QALY"
    color_code <- "red"
  }

  # ICER voting recommendation
  if (!is.finite(icer) && incremental_qalys > 0) {
    voting_recommendation <- "HIGH long-term value"
  } else if (icer < thresholds$middle) {
    voting_recommendation <- "HIGH long-term value"
  } else if (icer <= thresholds$upper) {
    voting_recommendation <- "INTERMEDIATE long-term value"
  } else {
    voting_recommendation <- "LOW long-term value"
  }

  assessment <- list(
    icer = icer,
    value_rating = value_rating,
    color_code = color_code,
    voting_recommendation = voting_recommendation,
    meets_50k = if (is.finite(icer)) icer < thresholds$lower else (incremental_qalys > 0),
    meets_100k = if (is.finite(icer)) icer < thresholds$middle else (incremental_qalys > 0),
    meets_150k = if (is.finite(icer)) icer < thresholds$upper else (incremental_qalys > 0)
  )

  return(assessment)
}


#' Calculate Health Benefit Price Benchmark
#'
#' @description
#' Calculates ICER Health Benefit Price Benchmark: the price at which
#' the intervention would meet specific cost-effectiveness thresholds.
#'
#' @param incremental_qalys Incremental QALYs
#' @param incremental_costs Current incremental costs
#' @param treatment_cost Current treatment cost
#' @param target_threshold Target ICER threshold (default $150,000/QALY)
#'
#' @return Health benefit price benchmark
#' @export
calculate_health_benefit_price <- function(incremental_qalys,
                                           incremental_costs,
                                           treatment_cost,
                                           target_threshold = 150000) {

  # Current ICER
  current_icer <- incremental_costs / incremental_qalys

  # Target incremental cost at threshold
  target_incremental_cost <- incremental_qalys * target_threshold

  # Required price reduction
  price_reduction <- incremental_costs - target_incremental_cost

  # Health benefit price (current price minus required reduction)
  health_benefit_price <- treatment_cost - price_reduction

  # Percent discount
  percent_discount <- (price_reduction / treatment_cost) * 100

  benchmark <- list(
    current_price = treatment_cost,
    health_benefit_price = health_benefit_price,
    required_price_reduction = price_reduction,
    percent_discount = percent_discount,
    target_threshold = target_threshold,
    interpretation = if (price_reduction > 0) {
      paste0("To meet $", format(target_threshold, big.mark = ","),
             "/QALY threshold, price should be reduced by ",
             round(percent_discount, 1), "% to $",
             format(round(health_benefit_price), big.mark = ","))
    } else {
      paste0("Current price already meets $", format(target_threshold, big.mark = ","),
             "/QALY threshold")
    }
  )

  return(benchmark)
}


#' Run US Payer Budget Impact Analysis
#'
#' @description
#' Performs budget impact analysis from US payer perspective following
#' AMCP Format requirements.
#'
#' @param params Base model parameters
#' @param bia_params Budget impact parameters (see details)
#' @param payer_type Payer type
#' @param plan_size Plan enrollment size
#' @param time_horizon Time horizon in years (default 5)
#'
#' @details
#' bia_params structure:
#' \itemize{
#'   \item eligible_population_pct: Percent of plan eligible for treatment
#'   \item treated_population_pct: Percent of eligible who get treated
#'   \item market_share_year1: Market share in year 1
#'   \item market_share_year_final: Market share in final year
#'   \item displacement_pattern: Which products displaced
#' }
#'
#' @return US payer BIA results
#' @export
run_us_payer_bia <- function(params,
                             bia_params,
                             payer_type = "commercial",
                             plan_size = 1000000,
                             time_horizon = 5) {

  # Source BIA module if not loaded
  if (!exists("run_budget_impact_analysis", mode = "function")) {
    source("frontend/modules/budget_impact.R", local = TRUE)
  }

  # ==========================================================================
  # ESTIMATE ELIGIBLE POPULATION
  # ==========================================================================

  eligible_pct <- bia_params$eligible_population_pct %||% 0.001  # 0.1% default
  treated_pct <- bia_params$treated_population_pct %||% 0.50     # 50% treated

  eligible_population <- plan_size * eligible_pct
  treated_population <- eligible_population * treated_pct

  message(paste0("Plan size: ", format(plan_size, big.mark = ","),
                " | Eligible: ", format(round(eligible_population), big.mark = ","),
                " | Treated: ", format(round(treated_population), big.mark = ",")))

  # ==========================================================================
  # CONFIGURE BIA PARAMETERS
  # ==========================================================================

  bia_params_configured <- list(
    population_size = eligible_population,
    incident_patients_year1 = treated_population * 0.20,  # 20% incident
    prevalence_rate = eligible_pct,
    market_share_year1 = bia_params$market_share_year1 %||% 0.10,
    market_share_year_final = bia_params$market_share_year_final %||% 0.30,
    displacement = bia_params$displacement_pattern %||% list(comparator1 = 1.0),
    time_horizon = time_horizon,
    uptake_pattern = "sigmoid"
  )

  # ==========================================================================
  # RUN BUDGET IMPACT ANALYSIS
  # ==========================================================================

  bia_results <- run_budget_impact_analysis(
    params = params,
    bia_params = bia_params_configured,
    ce_results = NULL
  )

  # ==========================================================================
  # ASSESS AFFORDABILITY (ICER THRESHOLD)
  # ==========================================================================

  five_year_budget_impact <- sum(bia_results$incremental_budget_impact)

  affordability_threshold <- ICER_VALUE_FRAMEWORK$cost_effectiveness_thresholds$budget_impact_threshold

  affordability_assessment <- if (five_year_budget_impact > affordability_threshold) {
    paste0("AFFORDABILITY CONCERN - 5-year budget impact ($",
           format(round(five_year_budget_impact), big.mark = ","),
           ") exceeds ICER threshold ($915M)")
  } else {
    paste0("AFFORDABLE - 5-year budget impact ($",
           format(round(five_year_budget_impact), big.mark = ","),
           ") within ICER threshold")
  }

  # ==========================================================================
  # COMPILE RESULTS
  # ==========================================================================

  us_payer_bia_results <- list(
    bia_results = bia_results,
    payer_type = payer_type,
    plan_size = plan_size,
    eligible_population = eligible_population,
    five_year_budget_impact = five_year_budget_impact,
    affordability_threshold = affordability_threshold,
    affordability_assessment = affordability_assessment,
    per_member_per_month = calculate_pmpm(five_year_budget_impact, plan_size, time_horizon)
  )

  class(us_payer_bia_results) <- c("us_payer_bia", "list")
  return(us_payer_bia_results)
}


#' Calculate Per Member Per Month (PMPM)
#'
#' @description
#' Calculates PMPM cost metric commonly used by US payers.
#'
#' @param total_cost Total cost over time period
#' @param plan_size Plan enrollment
#' @param years Number of years
#'
#' @return PMPM cost
#' @export
calculate_pmpm <- function(total_cost, plan_size, years) {

  total_months <- years * 12
  total_member_months <- plan_size * total_months

  pmpm <- total_cost / total_member_months

  return(pmpm)
}


#' Generate AMCP Dossier Economic Section
#'
#' @description
#' Generates economic evidence section (Section 7) for AMCP Format dossier.
#'
#' @param ce_results Cost-effectiveness results
#' @param bia_results Budget impact results
#' @param payer_type Payer type
#'
#' @return AMCP Section 7 summary
#' @export
generate_amcp_economic_section <- function(ce_results, bia_results = NULL, payer_type = "commercial") {

  section_7 <- list()

  # ==========================================================================
  # 7.1 SUMMARY OF ECONOMIC EVIDENCE
  # ==========================================================================

  section_7$summary <- list(
    perspective = paste0("US ", payer_type, " payer"),
    time_horizon = paste0(ce_results$time_horizon, " years"),
    discount_rate = "3% annually for costs and outcomes",
    model_type = "Markov cohort model",
    comparators = "Standard of care"
  )

  # ==========================================================================
  # 7.2 COST-EFFECTIVENESS RESULTS
  # ==========================================================================

  section_7$cost_effectiveness <- list(
    incremental_costs = ce_results$incremental_costs,
    incremental_qalys = ce_results$incremental_qalys,
    icer = ce_results$icer,
    interpretation = if (is.finite(ce_results$icer)) {
      paste0("ICER: $", format(round(ce_results$icer), big.mark = ","), " per QALY gained")
    } else {
      if (ce_results$incremental_qalys > 0) "Dominant strategy" else "Dominated strategy"
    }
  )

  # ==========================================================================
  # 7.3 BUDGET IMPACT (if available)
  # ==========================================================================

  if (!is.null(bia_results)) {
    section_7$budget_impact <- list(
      five_year_total = sum(bia_results$incremental_budget_impact),
      pmpm = bia_results$per_member_per_month %||% NA,
      time_horizon = paste0(bia_results$bia_results$time_horizon, " years")
    )
  }

  # ==========================================================================
  # 7.4 SENSITIVITY ANALYSES
  # ==========================================================================

  if (!is.null(ce_results$psa_results)) {
    section_7$sensitivity <- list(
      probabilistic = "Probabilistic sensitivity analysis conducted",
      cost_effective_probability_50k = ce_results$psa_results$prob_cost_effective_50k %||% NA,
      cost_effective_probability_100k = ce_results$psa_results$prob_cost_effective_100k %||% NA,
      cost_effective_probability_150k = ce_results$psa_results$prob_cost_effective_150k %||% NA
    )
  }

  # ==========================================================================
  # FORMAT AS TEXT
  # ==========================================================================

  amcp_text <- format_amcp_section(section_7)

  results <- list(
    section_7 = section_7,
    amcp_formatted_text = amcp_text
  )

  return(results)
}


#' Format AMCP Section
#'
#' @description
#' Formats AMCP section as text.
#'
#' @param section Section content
#'
#' @return Formatted text
#' @keywords internal
format_amcp_section <- function(section) {

  text <- paste0(
    "==============================================================================\n",
    "AMCP FORMAT v4.1 - SECTION 7: ECONOMIC EVIDENCE\n",
    "==============================================================================\n\n",
    "7.1 ECONOMIC MODEL OVERVIEW\n",
    "------------------------------------------------------------------------------\n",
    "Perspective:     ", section$summary$perspective, "\n",
    "Time Horizon:    ", section$summary$time_horizon, "\n",
    "Discount Rate:   ", section$summary$discount_rate, "\n",
    "Model Type:      ", section$summary$model_type, "\n\n",
    "7.2 COST-EFFECTIVENESS RESULTS\n",
    "------------------------------------------------------------------------------\n",
    "Incremental Costs:  $", format(round(section$cost_effectiveness$incremental_costs), big.mark = ","), "\n",
    "Incremental QALYs:  ", round(section$cost_effectiveness$incremental_qalys, 3), "\n",
    "ICER:               ", section$cost_effectiveness$interpretation, "\n\n"
  )

  if (!is.null(section$budget_impact)) {
    text <- paste0(text,
      "7.3 BUDGET IMPACT ANALYSIS\n",
      "------------------------------------------------------------------------------\n",
      "5-Year Total: $", format(round(section$budget_impact$five_year_total), big.mark = ","), "\n"
    )
    if (!is.na(section$budget_impact$pmpm)) {
      text <- paste0(text,
        "PMPM:         $", round(section$budget_impact$pmpm, 2), "\n"
      )
    }
    text <- paste0(text, "\n")
  }

  if (!is.null(section$sensitivity)) {
    text <- paste0(text,
      "7.4 SENSITIVITY ANALYSIS\n",
      "------------------------------------------------------------------------------\n",
      "Probabilistic Sensitivity Analysis: Conducted\n"
    )
    if (!is.na(section$sensitivity$cost_effective_probability_100k)) {
      text <- paste0(text,
        "Probability cost-effective at $100,000/QALY: ",
        round(section$sensitivity$cost_effective_probability_100k * 100, 1), "%\n"
      )
    }
    text <- paste0(text, "\n")
  }

  text <- paste0(text,
    "==============================================================================\n"
  )

  return(text)
}


#' Print US Payer CEA Results
#'
#' @description
#' Prints formatted US payer cost-effectiveness results.
#'
#' @param us_payer_results US payer CEA results
#'
#' @export
print_us_payer_cea <- function(us_payer_results) {

  if (!inherits(us_payer_results, "us_payer_cea")) {
    stop("us_payer_results must be output from run_us_payer_cea()")
  }

  cat("\n")
  cat("==============================================================================\n")
  cat("  US PAYER COST-EFFECTIVENESS ANALYSIS\n")
  cat("==============================================================================\n\n")

  cat(sprintf("Payer Type: %s\n", toupper(us_payer_results$payer_type)))
  cat(sprintf("Discount Rate: %.1f%% (costs and outcomes)\n", us_payer_results$discount_rate * 100))
  cat(sprintf("Productivity Costs: %s\n\n", ifelse(us_payer_results$include_productivity, "INCLUDED", "EXCLUDED")))

  # Base results
  base <- us_payer_results$base_results

  cat("COST-EFFECTIVENESS RESULTS\n")
  cat("------------------------------------------------------------------------------\n")
  cat(sprintf("Incremental Costs:  $%s\n", format(round(base$incremental_costs), big.mark = ",")))
  cat(sprintf("Incremental QALYs:  %.3f\n", base$incremental_qalys))

  if (is.finite(base$icer)) {
    cat(sprintf("ICER:               $%s per QALY\n\n", format(round(base$icer), big.mark = ",")))
  } else {
    if (base$incremental_qalys > 0) {
      cat("ICER:               DOMINANT (less costly, more effective)\n\n")
    } else {
      cat("ICER:               DOMINATED (more costly, less effective)\n\n")
    }
  }

  # ICER value assessment
  cat("ICER VALUE ASSESSMENT\n")
  cat("------------------------------------------------------------------------------\n")
  icer_assess <- us_payer_results$icer_assessment
  cat(sprintf("%s\n", icer_assess$value_rating))
  cat(sprintf("ICER Voting: %s\n\n", icer_assess$voting_recommendation))

  # Health benefit price
  cat("HEALTH BENEFIT PRICE BENCHMARK\n")
  cat("------------------------------------------------------------------------------\n")
  hbp <- us_payer_results$health_benefit_price
  cat(sprintf("%s\n", hbp$interpretation))

  cat("==============================================================================\n\n")

  invisible(us_payer_results)
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# =============================================================================
# END OF US PAYER REQUIREMENTS MODULE
# =============================================================================
