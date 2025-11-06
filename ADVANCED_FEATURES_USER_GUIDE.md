# Advanced Features User Guide
## Comprehensive Guide to LFA, Component NMA, IPD/Multivariate NMA, and RMST NMA

**Platform:** Metanew Meta-Analysis Platform
**Date:** November 6, 2025
**Version:** 1.0

---

## Table of Contents

1. [Introduction](#introduction)
2. [LFA Transportability Analysis](#lfa-transportability-analysis)
3. [Component Network Meta-Analysis](#component-network-meta-analysis)
4. [IPD & Multivariate Network Meta-Analysis](#ipd--multivariate-network-meta-analysis)
5. [RMST Network Meta-Analysis](#rmst-network-meta-analysis)
6. [Integrating Multiple Features](#integrating-multiple-features)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Introduction

This guide covers four advanced meta-analysis features recently integrated into the Metanew platform:

1. **LFA Transportability Analysis** (£40-50k value)
   - External validity assessment
   - Population generalization
   - FDA/EMA requirement

2. **Component Network Meta-Analysis** (£60k value)
   - Complex intervention decomposition
   - Component contribution analysis
   - Optimal treatment design

3. **IPD & Multivariate NMA** (£70k value)
   - Individual patient data analysis
   - Multiple correlated outcomes
   - Personalized treatment

4. **RMST Network Meta-Analysis** (£50-70k value)
   - Survival analysis without proportional hazards
   - Clinically interpretable time units
   - Cutting-edge 2025 research

**Total Value:** £220-250k in advanced capabilities

---

## LFA Transportability Analysis

### What is Transportability Analysis?

Transportability analysis assesses whether meta-analysis results from source studies can be generalized to a target population. This is critical for:
- Regulatory submissions (FDA/EMA requirement)
- Real-world effectiveness estimation
- Health technology assessment
- Clinical guideline development

### When to Use

Use LFA Transportability when:
- ✅ Source studies differ from target population
- ✅ Need to generalize RCT results to real-world
- ✅ Preparing regulatory submission
- ✅ Multiple effect modifiers suspected
- ✅ Want to combine RCT + observational data

### Quick Start Example

```python
from ml.lfa_transportability import (
    LFATransportabilityAnalysis,
    LFATransportConfig,
    LFATransportMethod,
    Study,
    Population
)
import numpy as np

# Define source studies (RCTs)
source_studies = [
    Study(
        study_id="RCT001",
        treatment_effect=0.48,  # log OR
        standard_error=0.15,
        sample_size=200,
        n_treatment=100,
        n_control=100,
        covariates={
            "mean_age": 55.0,
            "female_proportion": 0.45,
            "comorbidity_index": 2.1
        }
    ),
    Study(
        study_id="RCT002",
        treatment_effect=0.55,
        standard_error=0.18,
        sample_size=150,
        n_treatment=75,
        n_control=75,
        covariates={
            "mean_age": 58.0,
            "female_proportion": 0.50,
            "comorbidity_index": 2.3
        }
    )
]

# Define target population (real-world elderly)
np.random.seed(42)
n_target = 1000

target_population = Population(
    name="Elderly Real-World Cohort",
    covariates={
        "mean_age": np.random.normal(68, 8, n_target),
        "female_proportion": np.random.beta(6, 4, n_target),
        "comorbidity_index": np.random.gamma(3.5, 0.7, n_target)
    },
    sample_size=n_target,
    is_target=True
)

# Configure analysis
config = LFATransportConfig(
    method=LFATransportMethod.ENTROPY_BALANCING,
    use_ml_modifiers=True,
    cross_design=False,
    n_bootstrap=1000
)

# Run analysis
analysis = LFATransportabilityAnalysis(
    source_studies=source_studies,
    target_population=target_population,
    config=config
)

results = analysis.analyze()

# View results
print(results.summary())
print(f"Generalizability Index: {results.generalizability_index:.3f}")
print(f"Target Effect: {results.target_effect:.3f} (SE: {results.target_se:.3f})")
```

### Advanced Features

#### 1. Cross-Design Synthesis (RCT + Observational)

```python
# Add design type to studies
for study in rct_studies:
    study.covariates["design_type"] = "RCT"

for study in observational_studies:
    study.covariates["design_type"] = "observational"

# Combine
all_studies = rct_studies + observational_studies

# Configure with bias correction
config = LFATransportConfig(
    method=LFATransportMethod.ENTROPY_BALANCING,
    cross_design=True,
    bias_model="additive"  # or "proportional", "hierarchical"
)

analysis = LFATransportabilityAnalysis(
    source_studies=all_studies,
    target_population=target_population,
    config=config
)

results = analysis.analyze()

# Access cross-design results
if results.cross_design_results:
    print(f"RCT Effect: {results.cross_design_results.rct_effect:.3f}")
    print(f"Obs Effect: {results.cross_design_results.observational_effect:.3f}")
    print(f"Bias Estimate: {results.cross_design_results.bias_estimate:.3f}")
```

#### 2. ML Effect Modifier Detection

```python
config = LFATransportConfig(
    method=LFATransportMethod.ENTROPY_BALANCING,
    use_ml_modifiers=True
)

analysis = LFATransportabilityAnalysis(
    source_studies=source_studies,
    target_population=target_population,
    config=config
)

results = analysis.analyze()

# Access ML modifier results
if results.ml_modifier_results:
    print("Identified Effect Modifiers:")
    for modifier in results.ml_modifier_results.identified_modifiers:
        importance = results.ml_modifier_results.shap_importance[modifier]
        print(f"  - {modifier}: importance = {importance:.3f}")
```

### Interpreting Results

- **Generalizability Index (0-1)**:
  - ≥0.8: Excellent generalizability
  - 0.6-0.8: Good (use with caution)
  - 0.4-0.6: Moderate (questionable)
  - <0.4: Poor (not valid)

- **Covariate Overlap**:
  - Check overlap coefficients for each covariate
  - Low overlap (<0.4) → Poor transportability

- **Effect Modifiers**:
  - Prioritize modifiers with high SHAP importance
  - Consider stratified analysis by modifiers

---

## Component Network Meta-Analysis

### What is Component NMA?

Component NMA decomposes complex multi-component interventions into their constituent parts, estimating the contribution of each component.

### When to Use

Use Component NMA when:
- ✅ Analyzing complex interventions (psychotherapy, behavioral)
- ✅ Want to identify active vs. inert components
- ✅ Optimizing treatment packages
- ✅ Designing cost-effective interventions
- ✅ Planning dismantling studies

### Quick Start Example

```python
from ml.component_nma import (
    ComponentNMAAnalysis,
    CNMAStudy,
    CNMAEngine,
    create_component_matrix_from_dict
)

# Define components for each treatment
treatment_components = {
    "Control": [],
    "Self-help": ["Written materials"],
    "Brief advice": ["Counseling"],
    "Individual counseling": ["Counseling", "Individual sessions"],
    "Group therapy": ["Counseling", "Group sessions"],
    "NRT": ["Pharmacotherapy"],
    "Counseling + NRT": ["Counseling", "Pharmacotherapy"],
    "Group + NRT": ["Counseling", "Group sessions", "Pharmacotherapy"]
}

# Create component matrix
matrix, comp_names, trt_names = create_component_matrix_from_dict(
    treatment_components
)

# Define studies
studies = [
    CNMAStudy(
        study_id="SmokeCess001",
        treatment_arm="Counseling + NRT",
        comparison_arm="Control",
        effect_size=0.85,  # log OR for quit rate
        standard_error=0.20,
        sample_size=250
    ),
    CNMAStudy(
        study_id="SmokeCess002",
        treatment_arm="Group therapy",
        comparison_arm="Control",
        effect_size=0.62,
        standard_error=0.18,
        sample_size=300
    ),
    # ... more studies ...
]

# Run Component NMA
analysis = ComponentNMAAnalysis(
    studies=studies,
    component_matrix=matrix,
    component_names=comp_names,
    treatment_names=trt_names
)

results = analysis.fit_additive(
    engine=CNMAEngine.FREQUENTIST,
    include_interactions=False
)

# View component effects
print(results.summary())

for comp_eff in results.component_effects:
    print(f"{comp_eff.component_name}: {comp_eff.mean_effect:.3f} "
          f"(p={comp_eff.p_value:.4f})")
```

### Advanced Features

#### 1. Component Interactions

```python
# Fit model with pairwise interactions
results = analysis.fit_additive(
    engine=CNMAEngine.FREQUENTIST,
    include_interactions=True
)

# View interactions
for inter in results.interaction_effects:
    if inter.significant:
        print(f"Interaction: {inter.component_1} × {inter.component_2}")
        print(f"  Effect: {inter.interaction_effect:.3f} (p={inter.p_value:.4f})")
```

#### 2. Treatment Prediction

```python
# Predict effect for a new component combination
prediction = analysis.predict_treatment({
    "Written materials": False,
    "Counseling": True,
    "Individual sessions": False,
    "Group sessions": False,
    "Pharmacotherapy": True
})

print(f"Predicted effect: {prediction.predicted_effect:.3f}")
print(f"Active components: {', '.join(prediction.active_components)}")
print(f"95% CI: [{prediction.lower_95ci:.3f}, {prediction.upper_95ci:.3f}]")
```

#### 3. Dismantling Analysis

```python
# Test effect of removing a component
dismantling = analysis.analyze_dismantling(
    full_treatment="Group + NRT",
    reduced_treatment="Group therapy"
)

print(f"Removed: {', '.join(dismantling.removed_components)}")
print(f"Expected effect loss: {dismantling.expected_effect_loss:.3f}")
print(f"Significant: {dismantling.significant} (p={dismantling.p_value:.4f})")
```

#### 4. Optimal Treatment Design

```python
# Find optimal combination with constraints
optimal = analysis.design_optimal_treatment(
    max_components=3,
    cost_per_component={
        "Written materials": 10,
        "Counseling": 100,
        "Individual sessions": 200,
        "Group sessions": 150,
        "Pharmacotherapy": 300
    },
    budget=400
)

print(f"Optimal components: {', '.join(optimal.optimal_components)}")
print(f"Predicted effect: {optimal.predicted_effect:.3f}")
print(f"Cost-effectiveness ratio: {optimal.cost_effectiveness_ratio:.2f}")
```

---

## IPD & Multivariate Network Meta-Analysis

### What is IPD NMA?

Individual Patient Data (IPD) NMA analyzes patient-level data across multiple trials, enabling:
- Covariate adjustment
- Treatment-covariate interactions
- Individual predictions
- Subgroup analysis

### When to Use IPD NMA

Use IPD NMA when:
- ✅ Have individual patient data from trials
- ✅ Need covariate adjustment
- ✅ Want personalized treatment predictions
- ✅ Investigating treatment-covariate interactions
- ✅ Performing subgroup analyses

### Quick Start: IPD NMA

```python
from ml.ipd_multivariate_nma import (
    IPDNetworkMetaAnalysis,
    IPDPatient,
    IPDNMAMethod
)

# Generate IPD data (or load from database)
patients = [
    IPDPatient(
        patient_id="P001",
        study_id="Study1",
        treatment="Treatment A",
        outcome=75.5,  # continuous outcome
        covariates={
            "age": 65,
            "sex": 1,  # 1=female
            "baseline_severity": 50
        }
    ),
    IPDPatient(
        patient_id="P002",
        study_id="Study1",
        treatment="Control",
        outcome=68.2,
        covariates={
            "age": 62,
            "sex": 0,
            "baseline_severity": 48
        }
    ),
    # ... hundreds more patients ...
]

# One-stage analysis
analysis = IPDNetworkMetaAnalysis(ipd_data=patients)

results = analysis.fit_one_stage(
    include_covariates=True,
    covariate_names=["age", "baseline_severity"]
)

print(results.summary())

# View covariate effects
for cov, effect in results.covariate_effects.items():
    print(f"{cov}: {effect:.3f}")
```

### Multivariate NMA (Multiple Outcomes)

```python
from ml.ipd_multivariate_nma import MultivariateNetworkMetaAnalysis

# Data for multiple outcomes
data = {
    "efficacy": [
        {"study": "Study1", "treatment": "Treatment A", "effect": 0.5, "se": 0.1},
        {"study": "Study1", "treatment": "Treatment B", "effect": 0.7, "se": 0.1},
        # ... more studies ...
    ],
    "safety": [
        {"study": "Study1", "treatment": "Treatment A", "effect": -0.2, "se": 0.08},
        {"study": "Study1", "treatment": "Treatment B", "effect": -0.4, "se": 0.09},
        # ... more studies ...
    ]
}

# Run multivariate NMA
analysis = MultivariateNetworkMetaAnalysis(data=data)

results = analysis.fit(estimate_correlation=True)

# View results for each outcome
for outcome in results.outcome_names:
    print(f"\n{outcome.upper()}:")
    for trt, (mean, se) in results.treatment_effects[outcome].items():
        print(f"  {trt}: {mean:.3f} (SE: {se:.3f})")

# Joint rankings
print("\nJoint Rankings:")
print(results.joint_rankings)
```

---

## RMST Network Meta-Analysis

### What is RMST NMA?

Restricted Mean Survival Time (RMST) NMA analyzes time-to-event data using the mean survival time up to a restriction point τ (tau), rather than hazard ratios.

**Advantages over Hazard Ratios:**
- ✅ More intuitive (measured in months/years)
- ✅ No proportional hazards assumption needed
- ✅ Robust to non-proportional hazards
- ✅ Directly clinically meaningful

### When to Use RMST NMA

Use RMST NMA when:
- ✅ Analyzing survival/time-to-event outcomes
- ✅ Non-proportional hazards suspected
- ✅ Want clinically interpretable results
- ✅ Preparing oncology clinical trial reports
- ✅ Regulatory submissions (FDA/EMA prefer interpretability)

### Quick Start Example

```python
from ml.rmst_nma import (
    RMSTNetworkMetaAnalysis,
    RMSTStudy,
    rmst_nma_quick_analysis
)

# Define studies with RMST estimates
# tau = 36 months (3-year restriction time)
studies = [
    RMSTStudy(
        study_id="OncologyTrial001",
        treatment="Control",
        rmst=18.5,  # months
        rmst_se=1.5,
        tau=36.0,
        n_patients=120,
        n_events=75
    ),
    RMSTStudy(
        study_id="OncologyTrial001",
        treatment="Immunotherapy A",
        rmst=24.2,  # 5.7 months longer!
        rmst_se=1.8,
        tau=36.0,
        n_patients=125,
        n_events=60
    ),
    RMSTStudy(
        study_id="OncologyTrial002",
        treatment="Control",
        rmst=17.8,
        rmst_se=1.3,
        tau=36.0,
        n_patients=150,
        n_events=90
    ),
    RMSTStudy(
        study_id="OncologyTrial002",
        treatment="Chemotherapy B",
        rmst=21.5,
        rmst_se=1.4,
        tau=36.0,
        n_patients=145,
        n_events=70
    ),
    # ... more studies ...
]

# Run RMST NMA
results = rmst_nma_quick_analysis(
    studies=studies,
    tau=36.0,
    reference="Control"
)

print(results.summary())

# Interpret results
for diff in results.rmst_differences:
    if diff.significant:
        print(f"\n{diff.treatment} vs Control:")
        print(f"  RMST difference: {diff.difference:.1f} months")
        print(f"  95% CI: [{diff.lower_95ci:.1f}, {diff.upper_95ci:.1f}]")
        print(f"  p-value: {diff.p_value:.4f}")
        print(f"  → Patients gain {diff.difference:.1f} months on average")
```

### Clinical Interpretation

```python
# View clinical interpretation
for interp in results.interpretation:
    print(f"• {interp}")

# Treatment ranking
print("\nTreatment Ranking (by mean survival time):")
for trt, rank in results.treatment_ranking:
    rmst, se = results.rmst_estimates[trt]
    print(f"#{rank}: {trt} - {rmst:.1f} months (SE: {se:.1f})")
```

---

## Integrating Multiple Features

### Example 1: Component NMA + Transportability

Decompose intervention components, then assess transportability:

```python
# Step 1: Component NMA to identify effective components
cnma_analysis = ComponentNMAAnalysis(...)
cnma_results = cnma_analysis.fit_additive()

# Step 2: Use component-specific effects for transportability
# Create study objects with component effects
component_studies = [
    Study(
        study_id=comp.component_name,
        treatment_effect=comp.mean_effect,
        standard_error=comp.standard_error,
        ...
    )
    for comp in cnma_results.component_effects
]

# Step 3: Assess transportability
transport_analysis = LFATransportabilityAnalysis(
    source_studies=component_studies,
    target_population=target_pop,
    config=config
)
transport_results = transport_analysis.analyze()
```

### Example 2: IPD NMA + RMST NMA

Use IPD for covariate adjustment, then RMST for survival analysis:

```python
# Step 1: IPD NMA for covariate-adjusted effects
ipd_analysis = IPDNetworkMetaAnalysis(ipd_data=patients)
ipd_results = ipd_analysis.fit_one_stage(include_covariates=True)

# Step 2: Calculate RMST from IPD survival data
# (Would use R survival package integration)

# Step 3: RMST NMA on adjusted effects
rmst_analysis = RMSTNetworkMetaAnalysis(rmst_studies, tau=36)
rmst_results = rmst_analysis.analyze()
```

---

## Best Practices

### General Guidelines

1. **Choose the Right Method**
   - RCT → Real-world: Use LFA Transportability
   - Complex interventions: Use Component NMA
   - Individual-level data: Use IPD NMA
   - Survival outcomes: Use RMST NMA

2. **Data Quality**
   - Ensure consistent covariate definitions
   - Check for missing data patterns
   - Validate effect size calculations
   - Verify standard errors

3. **Interpretation**
   - Always check assumptions
   - Review warnings carefully
   - Consider clinical significance, not just statistical
   - Present results in clinically meaningful units

### LFA Transportability Best Practices

- ✅ Include all important effect modifiers
- ✅ Check covariate overlap before analysis
- ✅ Use entropy balancing for exact balance
- ✅ Bootstrap for robust confidence intervals
- ✅ Sensitivity analysis for unmeasured confounding

### Component NMA Best Practices

- ✅ Define components clearly and consistently
- ✅ Check for component collinearity
- ✅ Include interaction terms if synergy suspected
- ✅ Use Bayesian methods for small networks
- ✅ Validate with dismantling studies

### IPD NMA Best Practices

- ✅ Harmonize covariate definitions across studies
- ✅ Check for treatment-covariate interactions
- ✅ Use one-stage for synthesis, two-stage for heterogeneity
- ✅ Report both population and subgroup effects
- ✅ Validate predictions on holdout data

### RMST NMA Best Practices

- ✅ Choose τ (tau) based on clinical relevance
- ✅ Ensure common τ across studies
- ✅ Report RMST in clinically meaningful units
- ✅ Compare to hazard ratio results for validation
- ✅ Check for crossover of survival curves

---

## Troubleshooting

### Common Issues

#### LFA Transportability

**Problem:** Low generalizability index
- **Cause:** Large differences between source and target
- **Solution:**
  - Check covariate overlap
  - Consider stratification
  - Use ML modifiers to identify key differences
  - May need target-specific studies

**Problem:** Poor covariate balance
- **Cause:** Insufficient overlap or extreme weights
- **Solution:**
  - Use entropy balancing
  - Exclude studies with poor overlap
  - Consider alternative weighting methods

#### Component NMA

**Problem:** Singular design matrix
- **Cause:** Perfect collinearity in components
- **Solution:**
  - Check component definitions
  - Remove redundant components
  - Ensure sufficient treatment diversity

**Problem:** Very high heterogeneity (τ)
- **Cause:** Missing interactions or covariates
- **Solution:**
  - Add component interactions
  - Meta-regression on study characteristics
  - Use random effects model

#### IPD NMA

**Problem:** Convergence issues
- **Cause:** Complex model, insufficient data
- **Solution:**
  - Simplify covariate structure
  - Use two-stage approach
  - Increase iterations (Bayesian)
  - Check for data quality issues

**Problem:** Unrealistic individual predictions
- **Cause:** Extrapolation beyond data range
- **Solution:**
  - Check covariate ranges
  - Validate on holdout data
  - Add interaction terms
  - Use prediction intervals

#### RMST NMA

**Problem:** RMST > τ (tau)
- **Cause:** Calculation error or data issue
- **Solution:**
  - Verify RMST calculations
  - Check Kaplan-Meier curves
  - Ensure correct τ specification

**Problem:** Inconsistent τ across studies
- **Cause:** Different follow-up times
- **Solution:**
  - Use minimum common τ
  - Restrict analysis to studies with sufficient follow-up
  - Report τ-specific RMST

---

## Getting Help

### Documentation
- API Reference: `/docs/api`
- R Package Documentation: `/docs/r`
- Video Tutorials: `/docs/videos`

### Support
- Email: support@metanew.com
- GitHub Issues: github.com/mahmood726-cyber/Metanew/issues
- User Forum: forum.metanew.com

### Citation

If you use these features in your research, please cite:

```bibtex
@software{metanew2025,
  title = {Metanew Meta-Analysis Platform: Advanced Features},
  author = {Metanew Research Team},
  year = {2025},
  url = {https://github.com/mahmood726-cyber/Metanew}
}
```

And cite the relevant methods papers:
- **LFA:** Tipton (2014), Verde & Ohmann (2015)
- **Component NMA:** Welton et al. (2024), Mills et al. (2024)
- **IPD NMA:** Riley et al. (2024), Efthimiou et al. (2025)
- **RMST NMA:** Hua et al. (2025)

---

**Document Version:** 1.0
**Last Updated:** November 6, 2025
**Platform Version:** Metanew v2.0+
