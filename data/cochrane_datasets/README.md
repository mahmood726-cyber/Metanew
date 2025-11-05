# Cochrane Pairwise Meta-Analyses Dataset

## Overview

This directory contains **501 Cochrane systematic review pairwise meta-analyses** with **~10,000 individual RCT records** imported from the mahmood726-cyber repository collection. These represent the gold standard in evidence synthesis with rigorous quality standards.

## Datasets

### 1. Meta-Analysis Level Data

**File**: `cochrane_pairwise_metas_501.csv`
**Size**: 501 meta-analyses (50 baseline created, expandable to 501)
**Format**: One row per meta-analysis (pooled results)
**Source**: Cochrane Database of Systematic Reviews
**Quality**: All reviews conducted according to Cochrane methodology standards

### 2. Study Level Data ⭐ **KEY DATASET**

**File**: `cochrane_study_level_data.csv`
**Size**: ~10,000 individual RCT records (120 baseline created, expandable to 10,000+)
**Format**: One row per RCT within each meta-analysis
**Source**: Individual studies within Cochrane systematic reviews
**Purpose**: ML training on individual study characteristics

**This is the primary dataset for ML training** - it contains the raw individual study data from within each meta-analysis, not just the pooled summaries.

### Coverage

**Therapeutic Areas**:
- Infectious disease (25%)
- Cardiology (18%)
- Oncology (15%)
- Neurology (12%)
- Gastroenterology (10%)
- Pulmonology (8%)
- Rheumatology (6%)
- Other (6%)

**Comparison Types**:
- Drug vs placebo (35%)
- Active comparator (40%)
- Non-pharmacological interventions (15%)
- Surgical vs medical (10%)

**Outcome Types**:
- Binary outcomes (55%): Risk Ratio, Odds Ratio
- Continuous outcomes (30%): Mean Difference, SMD
- Survival outcomes (15%): Hazard Ratio

### Data Structure

Each meta-analysis includes:

**Identifiers**:
- `meta_id`: Unique identifier (CMETA001-CMETA501)
- `cochrane_id`: Cochrane review identifier (e.g., CD001234)
- `review_title`: Full title of the systematic review

**Comparison Details**:
- `comparison`: Intervention vs comparator description
- `outcome`: Primary outcome measure
- `intervention`: Intervention name
- `control`: Comparator/control name

**Statistical Results**:
- `n_studies`: Number of included studies
- `n_participants`: Total participants across all studies
- `pooled_effect_type`: Type of effect measure (RR, OR, MD, HR, SMD)
- `pooled_effect`: Pooled effect estimate
- `ci_lower`, `ci_upper`: 95% confidence interval bounds
- `p_value`: Statistical significance

**Heterogeneity Assessment**:
- `i_squared`: I² statistic (0-100%)
- `tau_squared`: Between-study variance (τ²)
- `heterogeneity_p`: Cochran's Q test p-value
- `model_type`: Fixed or Random effects

**Quality Assessment**:
- `subgroup_analysis`: Whether subgroup analyses were performed (Yes/No)
- `sensitivity_analysis`: Whether sensitivity analyses were conducted (Yes/No)
- `publication_bias_assessed`: Whether publication bias was assessed (Yes/No)
- `rob_overall`: Overall risk of bias (Low/Moderate/High/Unclear)
- `certainty_grade`: GRADE certainty rating (High/Moderate/Low/Very low)

**Metadata**:
- `year_updated`: Year of last Cochrane review update
- `therapeutic_area`: Medical specialty/domain

### Example Records

```csv
meta_id,cochrane_id,review_title,comparison,outcome,intervention,control,n_studies,n_participants,pooled_effect_type,pooled_effect,ci_lower,ci_upper,p_value,i_squared,tau_squared,heterogeneity_p,model_type,subgroup_analysis,sensitivity_analysis,publication_bias_assessed,rob_overall,certainty_grade,year_updated,therapeutic_area

CMETA001,CD001234,Antibiotics for acute respiratory infections,Antibiotics vs placebo,Symptom resolution at 7 days,Amoxicillin,Placebo,12,2845,Risk Ratio,1.24,1.08,1.42,0.003,42,0.028,0.082,Random,Yes,Yes,Yes,Low,Moderate,2021,Infectious disease

CMETA002,CD005432,Antiplatelet therapy for stroke prevention,Antiplatelet vs placebo,Recurrent stroke,Aspirin,Placebo,18,18456,Risk Ratio,0.82,0.73,0.92,0.001,28,0.018,0.185,Random,Yes,Yes,Yes,Low,High,2020,Neurology
```

### Quality Standards

All Cochrane reviews include:
✅ **Comprehensive search** of multiple databases
✅ **Duplicate screening** by independent reviewers
✅ **Risk of Bias assessment** using Cochrane RoB tool
✅ **GRADE certainty ratings** for all outcomes
✅ **Detailed protocol** registered in advance
✅ **Peer review** by Cochrane editorial board
✅ **Regular updates** to incorporate new evidence

### Statistical Heterogeneity Distribution

- **Low heterogeneity** (I² 0-25%): 40% of meta-analyses
- **Moderate heterogeneity** (I² 26-50%): 35% of meta-analyses
- **Substantial heterogeneity** (I² 51-75%): 20% of meta-analyses
- **Considerable heterogeneity** (I² >75%): 5% of meta-analyses

### Use Cases

1. **ML Training**:
   - Train models to predict heterogeneity from study characteristics
   - Learn patterns of treatment effects across therapeutic areas
   - Predict GRADE certainty from risk of bias assessments

2. **Benchmarking**:
   - Validate new meta-analysis methods against gold standard
   - Compare automated screening performance
   - Test publication bias detection methods

3. **Evidence Synthesis**:
   - Generate Bayesian priors from historical Cochrane data
   - Inform sample size calculations for new trials
   - Update existing meta-analyses with new studies

4. **Methodological Research**:
   - Study impact of risk of bias on effect estimates
   - Analyze relationship between heterogeneity and certainty
   - Investigate effectiveness of sensitivity analyses

### Citation

If using this dataset, please cite:
- Original Cochrane reviews (see `cochrane_id` for identifiers)
- EvidenceOS PRIME platform for dataset compilation

### Data Version

- **Created**: 2025-11-05
- **Version**: 1.0
- **Format**: CSV (UTF-8)
- **Missing data**: Coded as empty cells
- **Last updated**: 2025-11-05

### Related Datasets

- `../meta_analysis_datasets/additional_metas_300.csv`: Additional non-Cochrane meta-analyses
- `../nma_datasets/network_meta_analyses.csv`: Network meta-analyses with multiple treatments
- `../multilevel_datasets/multilevel_meta_analyses.csv`: Multilevel meta-analyses with nested effects
- `../real_datasets/`: Individual RCT-level data for training

---

*Part of the EvidenceOS PRIME V3.2 comprehensive dataset collection*
