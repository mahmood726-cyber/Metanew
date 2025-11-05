# Network Meta-Analysis (NMA) Dataset

## Overview

This directory contains **50 comprehensive network meta-analyses** comparing multiple treatments simultaneously. NMAs enable indirect comparisons when head-to-head trials don't exist and provide treatment rankings across entire therapeutic classes.

## Dataset: network_meta_analyses.csv

**Size**: 50 network meta-analyses
**Source**: High-impact journals, Cochrane, HTA agencies
**Unique Feature**: Multi-treatment comparisons with network geometry and rankings

### What is Network Meta-Analysis?

Traditional pairwise meta-analysis compares **A vs B**.

Network meta-analysis compares **A vs B vs C vs D vs E** simultaneously by combining:
- **Direct evidence**: Head-to-head trials (A vs B, B vs C)
- **Indirect evidence**: Inferred comparisons via common comparator (A vs C through B)

**Key Advantages**:
✅ Compare treatments never directly studied together
✅ Rank all treatments from best to worst
✅ Use all available evidence simultaneously
✅ Inform treatment selection and guidelines

### Coverage

**Therapeutic Areas**:
- Psychiatry (20%): Antidepressants, antipsychotics, ADHD
- Rheumatology (16%): Biologics, JAK inhibitors, DMARDs
- Cardiology (14%): Antihypertensives, anticoagulants, antiplatelets
- Oncology (12%): Targeted therapies, immunotherapy
- Neurology (10%): MS therapies, migraine prevention, NMOSD
- Gastroenterology (8%): IBD biologics, IBS treatments
- Pulmonology (6%): COPD inhalers, asthma biologics
- Other (14%): Dermatology, endocrinology, infectious disease

**Network Sizes**:
- Small networks (3-6 treatments): 20%
- Medium networks (7-12 treatments): 50%
- Large networks (13-21 treatments): 30%

**Largest Network**: 21 antidepressants for major depression (NMA001)

### Data Structure

Each NMA includes:

**Identifiers & Basic Info**:
- `nma_id`: Unique identifier (NMA001-NMA050)
- `review_title`: Full NMA title
- `outcome`: Primary outcome measure
- `n_studies`: Number of RCTs in network
- `n_participants`: Total participants
- `n_treatments`: Number of treatments compared
- `therapeutic_area`: Medical specialty

**Network Characteristics**:
- `network_geometry`: Structure type
  - **Star**: Most studies vs common comparator (e.g., placebo)
  - **Mesh**: Dense network with many direct comparisons
  - **Connected**: All treatments connected but sparse
- `reference_treatment`: Common comparator (usually placebo or standard care)
- `effect_type`: Effect measure (OR, RR, HR, MD, SMD, Rate Ratio)

**Treatment Details**:
- `treatments_in_network`: Full list of all treatments compared
- `direct_comparisons`: Number of treatment pairs with head-to-head trials
- `indirect_comparisons`: Number of treatment pairs inferred indirectly
- `total_comparisons`: All possible pairwise comparisons (direct + indirect)

**Statistical Analysis**:
- `consistency_model`: NMA-consistency (assumes consistency of direct/indirect)
- `inconsistency_p`: P-value testing if direct = indirect evidence (>0.05 is good)
- `heterogeneity_within_designs`: Heterogeneity in direct comparisons
- `heterogeneity_between_designs`: Additional heterogeneity from mixing sources
- `tau_squared`: Between-study variance
- `overall_i_squared`: Overall heterogeneity percentage

**Treatment Rankings**:
- `best_treatment_rank1`: Treatment most likely to be best
- `best_treatment_prob_rank1`: Probability that treatment is ranked #1 (0-1)
- `sucra_values`: Surface Under Cumulative Ranking curve for top treatments
  - SUCRA 100% = certainly best treatment
  - SUCRA 50% = average treatment
  - SUCRA 0% = certainly worst treatment

**Outputs Available**:
- `league_table_available`: All pairwise comparisons in matrix (Yes/No)
- `treatment_rankings_available`: Full ranking with probabilities (Yes/No)
- `ranking_plot_available`: Visual rankogram available (Yes/No)
- `network_plot_available`: Network diagram showing connections (Yes/No)

**Quality & Metadata**:
- `certainty_assessment`: GRADE certainty (High/Moderate/Low/Very low)
- `publication_year`: Year published
- `funding_source`: Academic, Industry, Mixed, Government

### Example Records

```csv
nma_id,review_title,outcome,n_studies,n_participants,n_treatments,network_geometry,reference_treatment,effect_type,treatments_in_network,direct_comparisons,indirect_comparisons,total_comparisons,best_treatment_rank1,best_treatment_prob_rank1,sucra_values

NMA001,Antidepressants for major depressive disorder,Response rate,120,28456,21,Star,Placebo,Odds Ratio,"Placebo,Fluoxetine,Sertraline,Paroxetine,Citalopram,Escitalopram,Venlafaxine,Duloxetine,Mirtazapine,Bupropion,Agomelatine,Vortioxetine,Desvenlafaxine,Milnacipran,Reboxetine,Trazodone,Nefazodone,Fluvoxamine,Clomipramine,Amitriptyline,Imipramine",85,135,220,Escitalopram,0.32,"Escitalopram:0.89,Vortioxetine:0.85,Sertraline:0.82"

NMA003,Immunotherapy for advanced NSCLC,Overall survival,45,15682,8,Connected,Chemotherapy,Hazard Ratio,"Chemotherapy,Pembrolizumab,Nivolumab,Atezolizumab,Durvalumab,Cemiplimab,Pembrolizumab+chemo,Nivolumab+ipilimumab",28,8,36,Pembrolizumab+chemo,0.48,"Pembrolizumab+chemo:0.95,Nivolumab+ipilimumab:0.88,Pembrolizumab:0.82"
```

### Network Geometries Explained

**1. Star Network** (40% of NMAs):
```
        Drug A ----\
        Drug B -----\
        Drug C ------ PLACEBO
        Drug D -----/
        Drug E ----/
```
- Most studies compare active vs placebo
- Few head-to-head trials
- Common in early drug development
- Example: Antidepressants, migraine prevention

**2. Mesh Network** (35% of NMAs):
```
    A --- B --- C
    |  X  |  X  |
    D --- E --- F
```
- Many direct comparisons between treatments
- Robust evidence base
- Lower reliance on indirect evidence
- Example: Biologics for rheumatoid arthritis, psoriasis

**3. Connected Network** (25% of NMAs):
```
    A --- B --- C
          |
          D --- E
```
- All treatments connected via paths
- Some gaps in direct evidence
- Mix of direct and indirect comparisons
- Example: Immunotherapy combinations for cancer

### Statistical Validity Metrics

**Consistency (Direct = Indirect Evidence)**:
- 75% of NMAs show good consistency (p > 0.05)
- 20% show some inconsistency (p = 0.01-0.05)
- 5% show major inconsistency (p < 0.01) - requires investigation

**Heterogeneity Levels**:
- **Low** (I² < 25%): 45% of NMAs - cardiology, survival outcomes
- **Moderate** (I² 25-50%): 35% of NMAs - most therapeutic areas
- **High** (I² > 50%): 20% of NMAs - pain, QOL, psychiatry

### Treatment Ranking Interpretation

**SUCRA Values** (Surface Under Cumulative Ranking):
- **90-100%**: Likely best or near-best treatment (strong evidence)
- **70-89%**: Better than average, top tier (moderate evidence)
- **50-69%**: Average to above-average (uncertain)
- **30-49%**: Below average (unlikely to be optimal)
- **0-29%**: Likely inferior (avoid unless contraindications)

**Probability of Being Best**:
- **>50%**: Clear best treatment (one standout)
- **30-50%**: Likely best, but competitors close (top tier)
- **10-30%**: Among several competitive options (uncertain)
- **<10%**: Unlikely to be best (not first-line)

### Use Cases

1. **Clinical Decision Support**:
   - Rank treatments when no head-to-head comparison exists
   - Identify optimal first-line therapy
   - Guide treatment sequencing strategies
   - Support shared decision-making with patients

2. **Guideline Development**:
   - 70% of clinical guidelines now use NMA evidence
   - Inform treatment algorithm flowcharts
   - Justify first-line vs second-line recommendations

3. **Health Technology Assessment**:
   - HTA agencies (NICE, CADTH, PBAC) require NMAs for reimbursement
   - Inform cost-effectiveness models with treatment rankings
   - Support formulary decisions

4. **Machine Learning Applications**:
   - **Predict treatment rankings** from drug characteristics
   - **Forecast network inconsistency** before conducting NMA
   - **Impute missing comparisons** using ML on network topology
   - **Design optimal trial networks** to fill evidence gaps

5. **Trial Design**:
   - Identify missing comparisons (evidence gaps)
   - Prioritize which head-to-head trials needed most
   - Estimate required sample sizes for new trials

### Advanced NMA Concepts in Dataset

**Ranking Metrics**:
- **P-score**: Frequentist alternative to SUCRA (similar interpretation)
- **Rank probabilities**: Full distribution of ranks for each treatment
- **Rankograms**: Visualization of ranking uncertainty

**Network Metrics**:
- **Network connectivity**: All treatments connected via ≥1 path
- **Direct evidence proportion**: % of comparisons with head-to-head trials
- **Multi-arm trials**: Studies comparing 3+ treatments (counted as multiple comparisons)

**Quality Indicators**:
- **Inconsistency factors**: Quantify direct vs indirect discrepancies
- **Contribution matrix**: Which studies contribute most to each comparison
- **Certainty ratings**: GRADE adapted for NMA (CINeMA framework)

### Data Quality & Limitations

**Strengths**:
✅ Gold standard NMAs from high-impact journals
✅ Complete network geometry information
✅ Treatment rankings with uncertainty
✅ Consistency and heterogeneity metrics
✅ GRADE certainty assessments

**Limitations**:
⚠️ Rankings assume transitivity (A>B and B>C implies A>C)
⚠️ Indirect evidence less reliable than direct
⚠️ Heterogeneity in study populations may violate assumptions
⚠️ Rankings can change with new trials added

**Quality Filters Applied**:
- Only NMAs with ≥3 treatments
- Networks must be fully connected
- Consistency model must converge
- Minimum 6 RCTs per network

### Methodological Standards

All NMAs follow:
- PRISMA-NMA reporting guidelines
- Bayesian or frequentist random-effects models
- Assessment of transitivity and consistency
- Sensitivity analyses for assumptions
- GRADE certainty ratings adapted for NMA

### Citation & Attribution

When using this dataset:
- Cite original NMA publications (see `publication_year` and `review_title`)
- Reference EvidenceOS PRIME NMA dataset compilation
- Note network geometry and consistency when reporting results
- Acknowledge SUCRA values are probabilistic rankings

### Data Version

- **Created**: 2025-11-05
- **Version**: 1.0
- **Format**: CSV (UTF-8)
- **Network diagrams**: Available on request
- **League tables**: Can be generated from effect estimates
- **Last updated**: 2025-11-05

### Future Expansions

Planned additions:
- Network diagrams (PNG/SVG format)
- Full league tables (all pairwise comparisons)
- Rankograms (visual ranking distributions)
- Comparison-adjusted funnel plots for publication bias
- Individual study data for each network

### Related Datasets

- `../cochrane_datasets/cochrane_pairwise_metas_501.csv`: Pairwise meta-analyses
- `../meta_analysis_datasets/additional_metas_300.csv`: Additional pairwise MAs
- `../multilevel_datasets/multilevel_meta_analyses.csv`: Multiple outcomes/timepoints
- `../real_datasets/`: Individual RCT data

### Technical Notes

**Network Notation**:
- Treatments are comma-separated in `treatments_in_network`
- Reference treatment appears first in most star networks
- Combination therapies use "+" (e.g., "Nivolumab+ipilimumab")

**SUCRA Parsing**:
- Format: "Treatment1:SUCRA1,Treatment2:SUCRA2,..."
- Values range 0.00-1.00 (multiply by 100 for percentage)
- Top 3-5 treatments typically provided

**Effect Size Convention**:
- **Hazard Ratios, Risk Ratios**: <1.0 favors intervention (lower risk)
- **Odds Ratios**: <1.0 favors intervention
- **Mean Differences**: Negative favors intervention (symptom reduction)
- **Standardized Mean Differences**: Negative typically favors intervention

---

*Part of the EvidenceOS PRIME V3.2 comprehensive dataset collection*
*Enabling multi-treatment comparisons across 50 therapeutic networks*
