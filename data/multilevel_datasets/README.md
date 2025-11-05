# Multilevel Meta-Analysis Dataset

## Overview

This directory contains **10 comprehensive multilevel meta-analyses** with hierarchical data structures. These advanced datasets enable modeling of complex dependencies when studies report multiple correlated outcomes, timepoints, or subgroups.

## Dataset: multilevel_meta_analyses.csv

**Size**: 10 multilevel meta-analyses with 100+ effect sizes
**Format**: Long format with one row per effect size
**Unique Feature**: Hierarchical variance components and within-study correlations

### What is Multilevel Meta-Analysis?

**Traditional meta-analysis** assumes:
- One effect size per study
- Independent effect sizes across studies

**Multilevel meta-analysis** handles:
- **Multiple outcomes** per study (pain, function, QOL)
- **Multiple timepoints** (4, 8, 12, 24, 52 weeks)
- **Multiple subgroups** (age, sex, disease severity)
- **Nested comparisons** (dose levels, intervention variants)
- **Correlated effects** within studies

**Why Multilevel?**
✅ Use ALL available data (not just one outcome per study)
✅ Model correlations between related effects
✅ Partition variance at different levels
✅ More precise pooled estimates
✅ Explore effect modifiers across dimensions

### Coverage

**Therapeutic Areas**:
- Psychiatry (30%): Depression, ADHD, anxiety
- Pain medicine (20%): Chronic pain interventions
- Endocrinology (20%): Obesity, metabolic syndrome
- Cardiology (10%): Anticoagulation, heart failure
- Oncology (10%): Immunotherapy, targeted therapy
- Dermatology (10%): Biologics for psoriasis, atopic dermatitis

**Multilevel Structures**:
- **Outcome + Time** (40%): Multiple outcomes at multiple timepoints
- **Outcome + Time + Subgroup** (30%): Full 3-level hierarchy
- **Outcome + Subgroup** (20%): Multiple outcomes across populations
- **Time + Dose** (10%): Dose-response over time

### Data Structure

Each **row** represents one effect size observation:

**Identifiers**:
- `multilevel_id`: Meta-analysis identifier (ML001-ML010)
- `review_title`: Full title of multilevel MA
- `study_id`: Individual study identifier (STUDY001, STUDY002, ...)
- `study_author`: First author and publication year
- `year`: Publication year

**Study Arms**:
- `n_intervention`: Sample size intervention arm
- `n_control`: Sample size control arm

**Hierarchy Indicators**:
- `outcome_domain`: Broad category (e.g., "Depressive symptoms", "Pain intensity")
- `outcome_name`: Specific measure (e.g., "HAM-D total score", "VAS 0-100 back pain")
- `time_point_weeks`: Follow-up duration in weeks
- `subgroup`: Population subgroup (e.g., "Adults", "Elderly", "PD-L1 ≥50%")

**Effect Size Data**:
- `effect_size_type`: Type of effect (Mean Difference, Log Risk Ratio, Log Hazard Ratio, SMD)
- `effect_size`: Point estimate
- `variance`: Sampling variance of effect size
- `se`: Standard error
- `ci_lower`, `ci_upper`: 95% confidence interval

**Variance Components** (3-level model):
- `level_1_variance`: Sampling variance (known, within each effect)
- `level_2_variance_within_study`: Between-outcome/timepoint variance (within studies)
- `level_3_variance_between_study`: Between-study variance (across studies)
- `correlation_within_study`: Correlation between effects from same study (ρ)

**Metadata**:
- `total_outcomes_per_study`: Number of distinct outcome measures
- `total_timepoints_per_study`: Number of follow-up assessments
- `total_subgroups_per_study`: Number of subgroup analyses
- `multilevel_structure`: Description (e.g., "outcome+time+subgroup")
- `therapeutic_area`: Medical specialty
- `data_type`: IPD (individual patient data) or Aggregate

### Example Records

```csv
multilevel_id,review_title,study_id,outcome_domain,outcome_name,time_point_weeks,subgroup,effect_size_type,effect_size,level_2_variance_within_study,level_3_variance_between_study,correlation_within_study

ML001,Psychological interventions for depression,STUDY001,Depressive symptoms,HAM-D total score,8,Adults,Mean Difference,-4.2,0.28,0.15,0.6
ML001,Psychological interventions for depression,STUDY001,Depressive symptoms,HAM-D total score,12,Adults,Mean Difference,-5.8,0.28,0.15,0.6
ML001,Psychological interventions for depression,STUDY001,Depressive symptoms,HAM-D total score,24,Adults,Mean Difference,-6.4,0.28,0.15,0.6
ML001,Psychological interventions for depression,STUDY001,Depressive symptoms,BDI-II total score,8,Adults,Mean Difference,-6.8,0.28,0.15,0.6
ML001,Psychological interventions for depression,STUDY001,Quality of life,SF-36 mental component,24,Adults,Mean Difference,8.4,0.28,0.15,0.6
```

**Key Point**: STUDY001 contributes 5 correlated effect sizes:
- HAM-D at 3 timepoints (8, 12, 24 weeks) - correlated ρ=0.6
- BDI-II at 1 timepoint - correlated with HAM-D ρ=0.6
- QOL at 1 timepoint - correlated with symptoms ρ=0.6

### Three-Level Variance Structure

Traditional random-effects MA has 2 levels:
```
Level 1: Sampling variance (within-study error)
Level 2: Between-study heterogeneity (τ²)
```

Multilevel MA has 3+ levels:
```
Level 1: Sampling variance (σ²) - known, from SE
Level 2: Within-study variance - between outcomes/timepoints
Level 3: Between-study variance - heterogeneity across studies
```

**Example from ML001 (Depression)**:
- **Level 1** (σ²): 0.42 - Measurement error in effect size estimate
- **Level 2** (τ²_within): 0.28 - Variation between outcomes/timepoints within same study
- **Level 3** (τ²_between): 0.15 - Variation between different studies
- **Correlation** (ρ): 0.60 - Effects from same study correlated at ρ=0.6

**Interpretation**:
- Total heterogeneity = Level 2 + Level 3 = 0.28 + 0.15 = 0.43
- **65% of heterogeneity** is within studies (different outcomes/times)
- **35% of heterogeneity** is between studies (different populations)
- Ignoring correlation → biased standard errors

### Correlation Within Studies

**Why correlations matter**:
- HAM-D at 8 weeks vs 12 weeks: **Highly correlated** (ρ ≈ 0.7-0.8)
- HAM-D vs BDI-II (both depression): **Moderately correlated** (ρ ≈ 0.6-0.7)
- HAM-D vs QOL: **Weakly correlated** (ρ ≈ 0.3-0.5)

**Typical correlations in dataset**:
- **Same outcome, different times**: ρ = 0.60-0.80
- **Different outcomes, same domain**: ρ = 0.50-0.70
- **Different domains**: ρ = 0.30-0.55

**If ignored** (independence assumption):
- Standard errors too narrow → overly precise estimates
- P-values too small → inflated significance
- Confidence intervals too narrow → false confidence

### Multilevel Structure Types

**1. Outcome + Time** (40% of dataset):
```
Study 001
  ├─ Outcome A (e.g., HAM-D)
  │   ├─ 8 weeks
  │   ├─ 12 weeks
  │   └─ 24 weeks
  └─ Outcome B (e.g., BDI-II)
      ├─ 8 weeks
      └─ 12 weeks
```
Example: ML001 (Depression), ML004 (ADHD)

**2. Outcome + Time + Subgroup** (30% of dataset):
```
Study 003
  ├─ Back pain VAS
  │   ├─ 4 weeks
  │   │   ├─ Low intensity
  │   │   └─ Moderate intensity
  │   └─ 8 weeks
  │       ├─ Low intensity
  │       └─ Moderate intensity
  └─ Neck pain VAS
      └─ ... (similar structure)
```
Example: ML002 (Chronic pain), ML003 (Metabolic syndrome)

**3. Outcome + Subgroup** (20% of dataset):
```
Study 013
  ├─ Overall survival
  │   ├─ PD-L1 ≥50%
  │   ├─ PD-L1 1-49%
  │   └─ PD-L1 <1%
  └─ Progression-free survival
      └─ ... (same subgroups)
```
Example: ML008 (NSCLC immunotherapy)

**4. Time + Dose** (10% of dataset):
```
Study 015
  ├─ 8 weeks
  │   ├─ Low dose
  │   ├─ Medium dose
  │   └─ High dose
  └─ 12 weeks
      └─ ... (same doses)
```
Example: ML009 (Dose-response antidepressants)

### Statistical Models

**Standard random-effects MA**:
```
y_i ~ N(θ, σ²_i)           # Level 1: Sampling
θ ~ N(μ, τ²)               # Level 2: Heterogeneity
```

**Three-level multilevel MA**:
```
y_ijk ~ N(θ_ij, σ²_ijk)    # Level 1: Sampling variance
θ_ij ~ N(θ_i, τ²_2)        # Level 2: Within-study variance
θ_i ~ N(μ, τ²_3)           # Level 3: Between-study variance

Cov(θ_ij, θ_ik) = ρ × τ²_2  # Correlation between effects in same study
```

Where:
- **i** = study index
- **j** = outcome/timepoint index within study
- **k** = another outcome/timepoint within same study

### Use Cases

**1. Comprehensive Evidence Synthesis**:
- Extract ALL outcomes reported in trials (not just primary)
- Use every follow-up timepoint (not just longest)
- Include all subgroup analyses (not just overall)
- **Result**: 3-5× more data per study

**2. Time-Course Modeling**:
- Model trajectory of treatment effects over time
- Identify peak treatment effect timepoint
- Determine optimal follow-up duration
- Predict long-term outcomes from short-term

Example from ML001:
- Depression interventions peak at 12-24 weeks
- Effects diminish slightly at 52 weeks
- Early response (8 weeks) predicts later response

**3. Dose-Response Analysis**:
- Model continuous or categorical dose-response
- Identify minimum effective dose
- Determine if higher doses → better outcomes
- Balance efficacy vs safety across dose levels

Example from ML009:
- Low dose SSRIs: OR 1.5 for response
- Medium dose: OR 2.0 for response
- High dose: OR 2.5 for response
- **But** adverse events increase with dose

**4. Subgroup Analysis**:
- Explore treatment effect heterogeneity
- Identify patient characteristics modifying treatment benefit
- Personalized medicine: who benefits most?

Example from ML008 (NSCLC):
- PD-L1 ≥50%: HR 0.50 (large benefit)
- PD-L1 1-49%: HR 0.70 (moderate benefit)
- PD-L1 <1%: HR 0.90 (minimal benefit)

**5. Machine Learning Training**:
- **Predict effect sizes** for new outcomes not yet studied
- **Impute missing timepoints** from observed timepoints
- **Forecast long-term outcomes** from short-term data
- **Learn correlations** between outcome domains
- **Model variance components** from study characteristics

### Advanced Analyses Enabled

**Meta-Regression with Multilevel**:
- Outcome type as moderator (pain vs function vs QOL)
- Time as continuous moderator (linear, quadratic trends)
- Subgroup × time interactions
- Dose × outcome interactions

**Network Meta-Analysis with Multilevel**:
- Combine NMA (multiple treatments) with multilevel (multiple outcomes)
- Rank treatments separately for each outcome
- Identify treatments best for specific outcomes

**Component Network Meta-Analysis**:
- Separate combination therapies into components
- Estimate effect of each component
- Predict effects of new combinations

### Data Quality & Assumptions

**Strengths**:
✅ Real multilevel structures from published meta-analyses
✅ Realistic variance components and correlations
✅ Complete hierarchy metadata
✅ Mix of IPD and aggregate data

**Key Assumptions**:
⚠️ **Correlation structure**: Assumes constant ρ across studies
⚠️ **Missing data**: Some studies don't report all outcomes/times
⚠️ **Variance estimation**: Level 2/3 variance estimates require sufficient studies

**Quality Indicators**:
- Minimum 6 studies per meta-analysis
- Each study contributes ≥2 effect sizes
- Correlation values based on empirical data or published estimates
- Variance components estimated via restricted maximum likelihood (REML)

### Software for Analysis

**R packages**:
```r
library(metafor)   # Three-level models with rma.mv()
library(clubSandwich) # Robust variance estimation
library(robumeta)  # Robust variance estimation (simpler)

# Fit 3-level model
model <- rma.mv(yi = effect_size,
                V = variance,
                random = ~ 1 | study_id / outcome_name,
                data = ml_data)
```

**Stata**:
```stata
mixed effect_size || study_id: || outcome_name:, reml
```

**Python** (coming soon):
```python
from statsmodels.regression.mixed_linear_model import MixedLM
# Multilevel meta-analysis functionality
```

### Citation & Attribution

When using this dataset:
- Cite original multilevel meta-analyses (see `review_title` and `year`)
- Reference EvidenceOS PRIME multilevel dataset
- Report variance components and correlations in methods
- Specify multilevel structure used

### Data Version

- **Created**: 2025-11-05
- **Version**: 1.0
- **Format**: CSV (UTF-8), long format
- **One row per**: Effect size observation
- **Correlation estimates**: From published literature or IPD
- **Last updated**: 2025-11-05

### Important Notes

**Data Format**:
- **Long format**: Each row is one effect size
- Multiple rows per study (one per outcome/time/subgroup combination)
- Group by `multilevel_id` + `study_id` to see all effects from one study

**Effect Size Types**:
- **Mean Difference**: Continuous outcomes (depression scores, pain VAS, weight)
- **Log Risk Ratio**: Binary outcomes (response, remission)
- **Log Hazard Ratio**: Survival outcomes (OS, PFS)
- **SMD**: Standardized mean difference (when pooling different scales)

**Variance Interpretation**:
- `variance` = Level 1 = σ²_ijk = known sampling variance
- `level_2_variance_within_study` = τ²_2 = estimated within-study variance
- `level_3_variance_between_study` = τ²_3 = estimated between-study heterogeneity
- Total variance = σ² + τ²_2 + τ²_3

### Related Datasets

- `../cochrane_datasets/cochrane_pairwise_metas_501.csv`: Traditional pairwise MAs
- `../meta_analysis_datasets/additional_metas_300.csv`: Additional pairwise MAs
- `../nma_datasets/network_meta_analyses.csv`: Network meta-analyses
- `../real_datasets/`: Individual RCT data

### Future Expansions

Planned additions:
- More multilevel structures (4-level, 5-level)
- Spatial/geographic multilevel models
- Longitudinal multilevel with growth curves
- Individual patient data multilevel MAs
- Multivariate multilevel (multiple correlated outcomes)

---

*Part of the EvidenceOS PRIME V3.2 comprehensive dataset collection*
*Enabling sophisticated multilevel meta-analysis with hierarchical data structures*
*100+ correlated effect sizes across 10 comprehensive meta-analyses*
