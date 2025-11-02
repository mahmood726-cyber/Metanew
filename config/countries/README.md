# Multi-Country Parameter Configuration Files

This directory contains health economic parameter configuration files for different countries/regions.

## Available Countries

- **uk.yaml** - United Kingdom (NICE methodology)
- **us.yaml** - United States (ICER framework)
- **germany.yaml** - Germany (IQWiG/GBA methodology)
- **france.yaml** - France (HAS methodology)
- **canada.yaml** - Canada (CADTH methodology)

## Configuration Structure

Each YAML file contains:

### 1. Basic Information
- Country name
- Currency and symbol

### 2. Willingness-to-Pay Thresholds
- Primary and secondary thresholds per QALY
- Special thresholds (e.g., end-of-life, rare diseases)

### 3. Discount Rates
- Discount rate for costs
- Discount rate for health benefits (QALYs)

### 4. Time Horizons
- Default analysis time horizon
- Lifetime horizon

### 5. Cost Parameters
- Drug costs (treatment and comparator)
- Health state costs
- Healthcare resource costs

### 6. Utility Values
- General population utility
- Disease-specific utilities
- Adverse event utilities

### 7. Population Parameters
- Eligible population size
- Market share projections

### 8. PSA Settings
- Number of iterations
- Distribution types for parameters

### 9. References
- Source documents for each parameter

## Usage in R

Load a country configuration using the `load_country_config()` function:

```r
# Load UK parameters
uk_params <- load_country_config("uk")

# Access specific parameters
wtp_threshold <- uk_params$wtp$primary_threshold  # £20,000
discount_rate <- uk_params$discounting$costs  # 0.035

# Use in health economic model
model_results <- run_markov_model(
  wtp_threshold = uk_params$wtp$primary_threshold,
  discount_rate = uk_params$discounting$costs,
  time_horizon = uk_params$time_horizon$default,
  cost_treatment = uk_params$costs$drug_treatment$default,
  ...
)
```

## Customization

These files provide **default values** based on published guidelines and reference costs.

**Important:** For actual submissions, you should:

1. **Update costs** to reflect:
   - Actual drug acquisition costs
   - Local/current healthcare resource costs
   - Indication-specific management costs

2. **Update utilities** based on:
   - Published literature for your indication
   - Patient-reported outcome data
   - Country-specific utility catalogs

3. **Validate parameters** with:
   - Local clinical experts
   - Published economic evaluations
   - HTA submission guidelines

## Parameter Sources

### UK (NICE)
- WTP thresholds: £20,000-£30,000 per QALY
- Discount rate: 3.5% for costs and benefits
- Source: NICE Guide to Methods of TA (2013)

### US (ICER)
- WTP thresholds: $100,000-$150,000 per QALY
- Discount rate: 3% for costs and benefits
- Source: ICER Value Assessment Framework

### Germany (IQWiG)
- No explicit WTP threshold
- Discount rate: 3% for costs and benefits
- Source: IQWiG General Methods 6.1

### France (HAS)
- No explicit WTP threshold
- Discount rate: 2.5% for costs and benefits
- Source: HAS Guide méthodologique

### Canada (CADTH)
- No explicit WTP threshold (~$50,000 CAD referenced)
- Discount rate: 1.5% for costs and benefits
- Source: CADTH Guidelines (2017)

## Adding New Countries

To add a new country configuration:

1. Copy an existing YAML file
2. Update all parameters based on local HTA agency guidelines
3. Document all sources in the references section
4. Update this README with the new country

## Version History

- v1.0 (2024) - Initial release with 5 countries
