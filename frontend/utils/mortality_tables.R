# Mortality Tables Utility
# Age/sex-adjusted background mortality rates
# Based on WHO Global Health Observatory data and national life tables

library(dplyr)

#' Get age/sex-adjusted annual mortality probability
#'
#' @param age Age in years (numeric or vector)
#' @param sex Sex ("male", "female", or "both")
#' @param country Country code (ISO3: "GBR", "USA", "DEU", "FRA", "CAN")
#' @param adjustment_factor Adjustment for comorbidities (default 1.0)
#' @return Annual mortality probability
get_mortality_rate <- function(age, sex = "both", country = "GBR", adjustment_factor = 1.0) {
  # Load mortality table
  mort_table <- get_mortality_table(country)

  # Handle vector input
  if (length(age) > 1) {
    return(sapply(age, function(a) {
      get_single_mortality_rate(a, sex, mort_table, adjustment_factor)
    }))
  }

  get_single_mortality_rate(age, sex, mort_table, adjustment_factor)
}

#' Internal function to get single mortality rate
get_single_mortality_rate <- function(age, sex, mort_table, adjustment_factor) {
  # Ensure age is within bounds
  age <- max(0, min(110, round(age)))

  # Get base mortality rate from table
  if (sex == "male") {
    base_rate <- mort_table$male[mort_table$age == age]
  } else if (sex == "female") {
    base_rate <- mort_table$female[mort_table$age == age]
  } else {  # both/average
    base_rate <- mort_table$both[mort_table$age == age]
  }

  # Apply adjustment factor for comorbidities
  adjusted_rate <- min(1.0, base_rate * adjustment_factor)

  return(adjusted_rate)
}

#' Get mortality table for specific country
#' @param country ISO3 country code
#' @return Data frame with age, male, female, both mortality rates
get_mortality_table <- function(country = "GBR") {
  # Return cached table if available
  if (exists(paste0(".mortality_table_", country), envir = .GlobalEnv)) {
    return(get(paste0(".mortality_table_", country), envir = .GlobalEnv))
  }

  # Generate mortality table based on Gompertz-Makeham model
  # These are approximate life tables based on 2020-2022 data
  table <- generate_mortality_table(country)

  # Cache the table
  assign(paste0(".mortality_table_", country), table, envir = .GlobalEnv)

  return(table)
}

#' Generate mortality table using Gompertz-Makeham model
#' @param country ISO3 country code
#' @return Data frame with mortality rates
generate_mortality_table <- function(country) {
  # Gompertz-Makeham parameters calibrated to national life tables
  # Format: alpha (age-independent), beta (initial mortality level), gamma (rate of increase)

  params <- list(
    GBR = list(  # United Kingdom
      male = list(alpha = 0.0001, beta = 0.00005, gamma = 0.09),
      female = list(alpha = 0.0001, beta = 0.00003, gamma = 0.085)
    ),
    USA = list(  # United States
      male = list(alpha = 0.00012, beta = 0.00006, gamma = 0.092),
      female = list(alpha = 0.00012, beta = 0.00004, gamma = 0.087)
    ),
    DEU = list(  # Germany
      male = list(alpha = 0.0001, beta = 0.00005, gamma = 0.089),
      female = list(alpha = 0.0001, beta = 0.00003, gamma = 0.084)
    ),
    FRA = list(  # France
      male = list(alpha = 0.00009, beta = 0.00004, gamma = 0.088),
      female = list(alpha = 0.00009, beta = 0.00003, gamma = 0.082)
    ),
    CAN = list(  # Canada
      male = list(alpha = 0.0001, beta = 0.00005, gamma = 0.09),
      female = list(alpha = 0.0001, beta = 0.00003, gamma = 0.085)
    )
  )

  if (!country %in% names(params)) {
    warning(paste("Country", country, "not found. Using GBR as default."))
    country <- "GBR"
  }

  country_params <- params[[country]]

  # Generate table for ages 0-110
  ages <- 0:110

  # Gompertz-Makeham: h(x) = alpha + beta * exp(gamma * x)
  # Annual mortality probability: q(x) = 1 - exp(-h(x))

  calc_mortality <- function(age, params) {
    hazard <- params$alpha + params$beta * exp(params$gamma * age)
    # Convert hazard to probability: p = 1 - exp(-h)
    prob <- 1 - exp(-hazard)
    # Cap at 1.0
    min(1.0, prob)
  }

  male_rates <- sapply(ages, function(a) calc_mortality(a, country_params$male))
  female_rates <- sapply(ages, function(a) calc_mortality(a, country_params$female))
  both_rates <- (male_rates + female_rates) / 2

  data.frame(
    age = ages,
    male = male_rates,
    female = female_rates,
    both = both_rates
  )
}

#' Calculate life expectancy from age
#' @param age Starting age
#' @param sex Sex ("male", "female", "both")
#' @param country Country code
#' @return Life expectancy in years
calculate_life_expectancy <- function(age, sex = "both", country = "GBR") {
  mort_table <- get_mortality_table(country)

  # Filter to ages >= starting age
  future_ages <- mort_table[mort_table$age >= age, ]

  # Get mortality rates
  if (sex == "male") {
    q_x <- future_ages$male
  } else if (sex == "female") {
    q_x <- future_ages$female
  } else {
    q_x <- future_ages$both
  }

  # Calculate survival probabilities
  # l(x+1) = l(x) * (1 - q(x))
  l_x <- numeric(length(q_x))
  l_x[1] <- 1.0
  for (i in 2:length(q_x)) {
    l_x[i] <- l_x[i-1] * (1 - q_x[i-1])
  }

  # Life expectancy = sum of survival probabilities
  # (approximately - assumes deaths occur at mid-interval)
  life_exp <- sum(l_x) - 0.5

  return(life_exp)
}

#' Get age-specific mortality for Markov model
#' @param base_age Starting age for cohort
#' @param sex Sex distribution
#' @param country Country
#' @param time_horizon Years to project
#' @return Vector of annual mortality probabilities over time horizon
get_markov_mortality_vector <- function(base_age, sex = "both", country = "GBR", time_horizon = 10) {
  ages <- base_age + (0:(time_horizon - 1))
  mortality_vec <- get_mortality_rate(ages, sex, country)
  return(mortality_vec)
}

#' Adjust mortality for disease/comorbidity
#' @param base_mortality Base mortality rate
#' @param smr Standardized mortality ratio (e.g., 1.5 = 50% higher mortality)
#' @return Adjusted mortality rate
adjust_mortality_smr <- function(base_mortality, smr) {
  # Apply SMR while ensuring probability stays <= 1
  adjusted <- base_mortality * smr
  return(pmin(adjusted, 0.999))
}

#' Create mortality adjustment table for UI
#' @return Data frame with common adjustment factors
get_mortality_adjustment_presets <- function() {
  data.frame(
    condition = c(
      "General population",
      "Mild chronic disease",
      "Moderate chronic disease",
      "Severe chronic disease",
      "Cancer (general)",
      "Cardiovascular disease",
      "Diabetes",
      "COPD",
      "Chronic kidney disease"
    ),
    smr = c(1.0, 1.2, 1.5, 2.0, 2.5, 1.8, 1.4, 2.0, 2.2),
    description = c(
      "No adjustment",
      "Slight increase in mortality risk",
      "Moderate increase in mortality risk",
      "Substantial increase in mortality risk",
      "Typical cancer population",
      "CVD with treatment",
      "Type 2 diabetes managed",
      "Chronic obstructive pulmonary disease",
      "CKD stages 3-4"
    ),
    stringsAsFactors = FALSE
  )
}

#' Plot mortality curves
#' @param country Country code
#' @param sex Sex to plot
#' @return ggplot object
plot_mortality_curve <- function(country = "GBR", sex = "both") {
  library(ggplot2)

  mort_table <- get_mortality_table(country)

  if (sex == "male") {
    mort_data <- data.frame(age = mort_table$age, mortality = mort_table$male, sex = "Male")
  } else if (sex == "female") {
    mort_data <- data.frame(age = mort_table$age, mortality = mort_table$female, sex = "Female")
  } else {
    mort_data <- rbind(
      data.frame(age = mort_table$age, mortality = mort_table$male, sex = "Male"),
      data.frame(age = mort_table$age, mortality = mort_table$female, sex = "Female")
    )
  }

  ggplot(mort_data, aes(x = age, y = mortality, color = sex)) +
    geom_line(size = 1.2) +
    scale_y_log10(labels = scales::percent) +
    labs(
      title = paste("Annual Mortality Probability -", country),
      x = "Age (years)",
      y = "Annual Mortality Probability (log scale)",
      color = "Sex"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
}

# Pre-load common tables on package load
.onLoad <- function(libname, pkgname) {
  # Pre-generate commonly used tables
  invisible(get_mortality_table("GBR"))
  invisible(get_mortality_table("USA"))
}
