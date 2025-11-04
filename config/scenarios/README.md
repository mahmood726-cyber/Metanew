# Scenario Presets Library

This directory contains pre-configured sensitivity analysis scenarios for meta-analysis.

## Purpose

Scenario presets allow rapid sensitivity analysis by applying common variations to the base case analysis. This helps assess robustness of findings to methodological choices and study characteristics.

## Available Scenarios

### Standard Analysis
- **base_case.yaml**: Standard analysis with default REML random effects method

### Sensitivity Analyses (Study Characteristics)
- **high_quality_only.yaml**: Restrict to low risk of bias studies
- **large_studies_only.yaml**: Restrict to studies with n >= 100 per arm
- **recent_studies.yaml**: Restrict to studies published since 2015
- **rcts_only.yaml**: Restrict to randomized controlled trials

### Sensitivity Analyses (Statistical Methods)
- **fixed_effect.yaml**: Use fixed effect model instead of random effects
- **dl_method.yaml**: Use DerSimonian-Laird method instead of REML

### Advanced Analyses
- **leave_one_out.yaml**: Influence analysis excluding each study iteratively
- **trim_and_fill_adjusted.yaml**: Adjust pooled estimate for publication bias
- **subgroup_by_rob.yaml**: Subgroup analysis comparing ROB levels

### Boundary Scenarios
- **conservative.yaml**: Most restrictive assumptions (high quality, large, recent RCTs)
- **optimistic.yaml**: Most inclusive assumptions (all studies, fixed effect)

## How to Use

### In R Shiny Interface

1. Navigate to "Sensitivity Analysis" tab
2. Click "Load Preset" dropdown
3. Select desired scenario
4. Review settings (optionally modify)
5. Click "Run Scenario"
6. Compare results with base case

### Programmatically in R

```r
library(yaml)

# Load scenario
scenario <- yaml::read_yaml("config/scenarios/high_quality_only.yaml")

# Apply to meta-analysis
ma_result <- run_meta_analysis(
  data = my_data,
  method = scenario$meta_analysis$method,
  model = scenario$meta_analysis$model,
  # ... other settings from scenario
)
```

### Via API

```python
import requests
import yaml

# Load scenario
with open("config/scenarios/base_case.yaml") as f:
    scenario = yaml.safe_load(f)

# Send to API
response = requests.post(
    "http://localhost:8000/meta/analyze",
    json={
        "data": my_data,
        "settings": scenario["meta_analysis"]
    }
)
```

## Creating Custom Scenarios

To create a custom scenario:

1. Copy an existing scenario file (e.g., `base_case.yaml`)
2. Rename it (e.g., `my_custom_scenario.yaml`)
3. Modify the settings as needed
4. Update `name`, `description`, and `notes` fields
5. Save in this directory
6. Scenario will automatically appear in "Load Preset" dropdown

### Scenario File Structure

```yaml
name: Scenario Name
description: Brief description (1 sentence)
category: standard|sensitivity|subgroup|statistical|publication_bias
author: Your Name
version: 1.0
created_date: YYYY-MM-DD

meta_analysis:
  method: REML|DL|ML|FE
  model: random|fixed
  measure: auto|OR|RR|MD|SMD|HR

inclusion:
  min_sample_size: null or number
  max_sample_size: null or number
  exclude_high_rob: true|false
  allowed_rob_levels: [low, unclear, high] or null
  min_year: null or year
  max_year: null or year
  allowed_designs: [RCT, cohort, case-control] or null

subgroup:
  enabled: true|false
  variable: null or column name
  test_interaction: true|false

meta_regression:
  enabled: true|false
  moderators: []

publication_bias:
  egger_test: true|false
  trim_and_fill: true|false
  taf_method: L0|R0|Q0
  taf_side: right|left
  use_taf_estimate: true|false

reporting:
  forest_plot: true|false
  funnel_plot: true|false
  heterogeneity_stats: true|false
  influence_analysis: true|false

notes: |
  Multi-line notes explaining rationale and interpretation guidance.
```

## Best Practices

1. **Always start with base case**: Compare all sensitivity analyses to the base case
2. **Run multiple scenarios**: Assess robustness across multiple dimensions
3. **Document deviations**: If custom scenarios deviate from presets, document why
4. **Report transparently**: In publications, report all scenarios run (not just favorable ones)
5. **Interpret in context**: Large changes may indicate fragile evidence; investigate causes

## Scenario Categories

- **standard**: Base case or standard analysis
- **sensitivity**: Variations in inclusion criteria
- **statistical**: Variations in statistical methods
- **subgroup**: Subgroup or stratified analyses
- **publication_bias**: Publication bias adjustments
- **boundary**: Conservative/optimistic extreme scenarios

## Version History

- v1.0 (2025-11-04): Initial scenario library with 12 presets

## References

- Cochrane Handbook for Systematic Reviews of Interventions (Chapter 10: Sensitivity Analysis)
- PRISMA Statement (2020): Reporting sensitivity analyses
- IntHout J, et al. (2014). "The Hartung-Knapp-Sidik-Jonkman method for random effects meta-analysis"
- Viechtbauer W. (2010). "Conducting meta-analyses in R with the metafor package"
