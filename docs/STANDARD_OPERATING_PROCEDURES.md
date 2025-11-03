# Standard Operating Procedures (SOPs)
## EvidenceOS PRIME Meta-Analysis Platform

**Effective Date**: November 3, 2025
**Version**: 2.0
**Review Cycle**: Annual
**Compliance**: NICE DSU, Cochrane Handbook, ISPOR Guidelines

---

## Table of Contents

1. [SOP-001: Systematic Literature Search](#sop-001-systematic-literature-search)
2. [SOP-002: Study Selection and Data Extraction](#sop-002-study-selection-and-data-extraction)
3. [SOP-003: Risk of Bias Assessment](#sop-003-risk-of-bias-assessment)
4. [SOP-004: Data Upload and Validation](#sop-004-data-upload-and-validation)
5. [SOP-005: Pairwise Meta-Analysis](#sop-005-pairwise-meta-analysis)
6. [SOP-006: Network Meta-Analysis](#sop-006-network-meta-analysis)
7. [SOP-007: Publication Bias Assessment](#sop-007-publication-bias-assessment)
8. [SOP-008: Heterogeneity Assessment](#sop-008-heterogeneity-assessment)
9. [SOP-009: Sensitivity Analysis](#sop-009-sensitivity-analysis)
10. [SOP-010: Health Economic Analysis](#sop-010-health-economic-analysis)
11. [SOP-011: Results Export and Reporting](#sop-011-results-export-and-reporting)
12. [SOP-012: Quality Control and Review](#sop-012-quality-control-and-review)

---

## SOP-001: Systematic Literature Search

### 1.1 Purpose
To establish standardized procedures for conducting systematic literature searches for meta-analysis.

### 1.2 Scope
Applies to all meta-analyses conducted using EvidenceOS PRIME.

### 1.3 Responsibilities
- **Principal Investigator**: Approve search strategy
- **Information Specialist**: Conduct searches
- **Reviewers**: Screen results

### 1.4 Procedure

#### Step 1: Define Research Question (PICO)
- **Population**: Define target population
- **Intervention**: Specify intervention(s) of interest
- **Comparator**: Define comparator(s)
- **Outcome**: Identify outcomes of interest
- **Study Design**: Specify eligible study designs

**Documentation**: Record PICO in protocol

#### Step 2: Develop Search Strategy
- **Databases**: Minimum 3 major databases (MEDLINE, Embase, Cochrane CENTRAL)
- **Search Terms**: Combine MeSH terms and free text
- **Filters**: Apply appropriate filters (RCT, language, date)
- **Peer Review**: Have search strategy reviewed by second information specialist

**Example Search String (MEDLINE)**:
```
("heart failure"[MeSH] OR "cardiac failure"[tiab]) AND
("beta blocker*"[MeSH] OR "beta-adrenergic blocker*"[tiab]) AND
("randomized controlled trial"[pt] OR randomized[tiab])
```

**Documentation**: Save complete search strategies for all databases

#### Step 3: Execute Searches
- **Date**: Record search execution date
- **Results**: Export results to reference management software
- **Deduplication**: Remove duplicate records
- **Supplementary Searches**: Hand search references, trial registers

**Quality Check**: ✓ Search retrievesknown key studies

#### Step 4: Document Search Process
- **PRISMA Flow Diagram**: Use SOP-011 for automated generation
- **Search Log**: Record all databases, dates, hits
- **Deduplicated Total**: Report final number for screening

**Documentation Template**:
```
Database: MEDLINE via Ovid
Search Date: [Date]
Date Range: [Start] to [End]
Results: [N] records
After Deduplication: [N] records
```

### 1.5 Quality Control
- Second reviewer validates search strategy
- Spot check 10% of deduplication accuracy
- Verify known key studies retrieved

### 1.6 Documentation
- Protocol with approved search strategy
- Search log with all databases and results
- Reference library export
- PRISMA flow diagram

### 1.7 References
- Cochrane Handbook Chapter 6: Searching for studies
- PRESS Peer Review of Electronic Search Strategies
- PRISMA-S Extension for Search Reporting

---

## SOP-002: Study Selection and Data Extraction

### 2.1 Purpose
Standardize study selection and data extraction to ensure consistency and quality.

### 2.2 Procedure

#### Step 1: Screening Process
- **Title/Abstract Screening**: Two independent reviewers
- **Full-Text Screening**: Two independent reviewers
- **Disagreement Resolution**: Third reviewer arbiter

**Screening Criteria**:
- ✓ Meets PICO criteria
- ✓ Eligible study design
- ✓ Reports relevant outcomes
- ✓ Available full text
- ✓ Not duplicate publication

#### Step 2: Data Extraction
**Minimum Data Elements**:
- Study ID, first author, year
- Study design, sample size
- Population characteristics (age, sex, baseline severity)
- Intervention details (dose, duration, co-interventions)
- Comparator details
- Outcome measures (definition, timing, measurement tool)
- Effect estimates (mean ± SD, events/total, HR with CI, etc.)
- Risk of bias assessment data

**Tool**: Use standardized data extraction form

#### Step 3: Quality Checks
- Second reviewer extracts 10% of studies independently
- Compare extractions and resolve discrepancies
- Verify effect estimates by recalculation when possible

#### Step 4: Contact Authors
- If data missing or unclear, contact study authors
- Document all correspondence
- Set deadline for response (4 weeks)

### 2.3 Quality Control
- **Screening Agreement**: Calculate Cohen's kappa (target ≥ 0.70)
- **Extraction Agreement**: 100% agreement on numerical data after QC
- **Data Verification**: Spot check calculations

### 2.4 Documentation
- Screening log (included/excluded with reasons)
- Data extraction database
- Author contact log
- Discrepancy resolution log

---

## SOP-003: Risk of Bias Assessment

### 3.1 Purpose
Systematic assessment of risk of bias using Cochrane RoB 2.0 tool.

### 3.2 Procedure

#### Step 1: Tool Selection
- **RCTs**: Use RoB 2.0 tool (see `frontend/utils/rob2_tool.R`)
- **Non-RCTs**: Use ROBINS-I tool
- **Diagnostic Studies**: Use QUADAS-2 tool

#### Step 2: RoB 2.0 Assessment (RCTs)

**Five Domains**:
1. Bias arising from randomization process
2. Bias due to deviations from intended interventions
3. Bias due to missing outcome data
4. Bias in measurement of outcome
5. Bias in selection of reported result

**For Each Domain**:
- Answer signaling questions (Y/N/NI)
- Rate domain: Low / Some concerns / High
- Provide support for judgment

#### Step 3: Calculate Overall Risk
- **Low**: Low risk in all domains
- **Some concerns**: At least one "some concerns", no "high"
- **High**: At least one "high" risk domain

**R Code Example**:
```r
library(EvidenceOS)

# Create template
rob_template <- create_rob2_template(study_ids = c("Study1", "Study2"))

# Fill in assessments (manual or from database)
rob_data <- read.csv("rob_assessments.csv")

# Validate
validation <- validate_rob2(rob_data)
print(validation)

# Calculate overall risk for each study
rob_data$overall <- sapply(unique(rob_data$study_id), function(s) {
  study_data <- rob_data[rob_data$study_id == s, ]
  calculate_overall_rob2(study_data)
})
```

#### Step 4: Create Visualizations
```r
# Traffic light plot
rob2_traffic_light(rob_data)
ggsave("rob_traffic_light.png", width = 10, height = 8)

# Summary plot
rob2_summary(rob_data)
ggsave("rob_summary.png", width = 8, height = 6)
```

#### Step 5: Bias-Adjusted Analysis
```r
# Sensitivity analysis excluding high RoB studies
sensitivity <- rob2_sensitivity_analysis(
  ma = meta_result,
  rob_data = rob_data,
  exclude_risk = "High"
)

print(sensitivity$comparison)
```

### 3.3 Quality Control
- **Dual Assessment**: Two independent assessors for all studies
- **Disagreement Resolution**: Discussion to reach consensus
- **Third Reviewer**: For unresolved disagreements
- **Agreement Metric**: Calculate Cohen's kappa (target ≥ 0.60)

### 3.4 Documentation
- RoB 2.0 assessments for all studies (CSV format)
- Signaling question responses
- Support for judgments
- Traffic light plot
- Summary plot
- Disagreement resolution log

---

## SOP-004: Data Upload and Validation

### 4.1 Purpose
Ensure data quality through systematic validation before analysis.

### 4.2 Procedure

#### Step 1: Prepare Data File
**Required Columns** (for binary outcomes):
- `study_id`: Unique study identifier
- `treatment1`, `treatment2`: Treatment names
- `events1`, `events2`: Number of events
- `n1`, `n2`: Total sample sizes

**Optional Columns**:
- `year`: Publication year
- `author`: First author
- `outcome`: Outcome name
- `followup`: Follow-up duration

**Format**: CSV, Excel (.xlsx), or RevMan format

#### Step 2: Upload Data
```python
# Using API
import requests

files = {'file': open('metaanalysis_data.csv', 'rb')}
response = requests.post(
    'http://localhost:8000/api/ingest',
    files=files
)

data_id = response.json()['data_id']
```

#### Step 3: Automatic Validation
System automatically checks:
- ✓ Required columns present
- ✓ No missing values in critical fields
- ✓ Data types correct (numeric where expected)
- ✓ Logical consistency (events ≤ sample size)
- ✓ Range validity (probabilities 0-1, counts ≥ 0)
- ✓ Duplicate detection (same study reported multiple times)
- ✓ Outlier detection (values >3 IQR from median)

#### Step 4: Review Validation Report
```
VALIDATION REPORT
=================
File: metaanalysis_data.csv
Studies: 24
Outcome Type: Binary
Format Detected: Wide (arm-based)

CHECKS PASSED: ✓
- Required columns present
- No missing data in critical fields
- Data types valid
- Logical consistency maintained
- No duplicates detected

WARNINGS: ⚠️
- Study "Smith2020" has zero events in control arm (continuity correction will be applied)
- Outlier detected: Study "Jones2019" event rate (0.95) >3 IQR from median

RECOMMENDATIONS:
- Review outlier study for data extraction errors
- Verify zero-event studies are correctly reported
```

#### Step 5: Manual Review
- Verify flagged issues
- Check outliers against original publications
- Confirm zero-event handling appropriate
- Document any corrections made

#### Step 6: Approve Data
```python
# Mark data as validated
response = requests.post(
    f'http://localhost:8000/api/data/{data_id}/approve',
    json={'reviewer': 'user@example.com'}
)
```

### 4.3 Quality Control
- **Verification**: Second reviewer spot-checks 10% of uploaded data against source
- **Recalculation**: Verify effect estimates can be recalculated from raw data
- **Cross-Check**: Compare totals to PRISMA flow diagram

### 4.4 Documentation
- Data file (versioned)
- Validation report
- Corrections log (if any)
- Approval record with timestamp and reviewer

---

## SOP-005: Pairwise Meta-Analysis

### 5.1 Purpose
Conduct pairwise meta-analysis following Cochrane best practices.

### 5.2 Procedure

#### Step 1: Select Analysis Method
**Effect Measure**:
- Binary outcomes: OR, RR, or RD
- Continuous outcomes: MD or SMD
- Time-to-event: HR

**Model Selection**:
- Random-effects model (REML) - **DEFAULT**
- Fixed-effect model (only if no heterogeneity expected)

**Rationale**: Random-effects model accounts for between-study heterogeneity and provides more conservative estimates.

#### Step 2: Execute Meta-Analysis
```r
library(meta)

# Binary outcome example
ma <- metabin(
  event.e = data$events_exp,
  n.e = data$n_exp,
  event.c = data$events_ctrl,
  n.c = data$n_ctrl,
  studlab = data$study_id,
  data = data,
  sm = "OR",                  # Summary measure
  method = "MH",              # Mantel-Haenszel
  comb.fixed = FALSE,
  comb.random = TRUE,
  method.tau = "REML",        # REML estimation for τ²
  hakn = TRUE,                # Hartung-Knapp adjustment
  prediction = TRUE           # Prediction interval
)

# Print results
print(ma)
summary(ma)
```

#### Step 3: Assess Heterogeneity
**Metrics**:
- **τ²**: Between-study variance
- **I²**: Percentage of variation due to heterogeneity
  - 0-40%: Might not be important
  - 30-60%: Moderate heterogeneity
  - 50-90%: Substantial heterogeneity
  - 75-100%: Considerable heterogeneity
- **Cochran's Q**: Test for heterogeneity (p < 0.10 suggests heterogeneity)

**Interpretation**:
```r
cat("Heterogeneity Assessment:\n")
cat("τ² =", round(ma$tau^2, 4), "\n")
cat("I² =", round(ma$I2, 1), "%\n")
cat("Q = ", round(ma$Q, 2), ", p = ", format.pval(ma$pval.Q), "\n")

if (ma$I2 > 50) {
  cat("⚠️ Substantial heterogeneity detected. Consider:\n")
  cat("  - Subgroup analysis\n")
  cat("  - Meta-regression\n")
  cat("  - Sensitivity analysis\n")
}
```

#### Step 4: Calculate Prediction Interval
```r
library(EvidenceOS)

# Calculate prediction interval
pred_int <- pred_interval(ma, level = 0.95)
print(pred_int)

# Interpretation
cat("\nPrediction Interval Interpretation:\n")
cat("We expect 95% of future study effects to fall between",
    round(pred_int$lower, 3), "and", round(pred_int$upper, 3), "\n")
```

#### Step 5: Create Forest Plot
```r
# Standard forest plot
forest(ma,
       sortvar = -year,
       xlim = c(0.1, 10),
       label.left = "Favours control",
       label.right = "Favours treatment",
       col.square = "navy",
       col.diamond = "maroon",
       print.tau2 = TRUE,
       print.I2 = TRUE,
       print.pval.Q = TRUE,
       prediction = TRUE        # Show prediction interval
)
```

#### Step 6: Document Results
**Report Elements**:
- Number of studies and participants
- Effect estimate with 95% CI
- Heterogeneity statistics (τ², I², Q, p-value)
- Prediction interval
- Model used and justification
- Software and package versions

**Example Text**:
> "We included 24 RCTs with 12,486 participants. Random-effects meta-analysis showed a significant reduction in mortality (OR 0.75, 95% CI 0.64-0.89, p = 0.001). Moderate heterogeneity was observed (I² = 48%, τ² = 0.027, Q = 44.6, p = 0.042). The prediction interval (0.52-1.08) suggests that future studies might show benefit or no effect."

### 5.3 Quality Control Checklist
- ☐ Correct effect measure selected and justified
- ☐ Random-effects model used (unless justified otherwise)
- ☐ REML method for τ² estimation
- ☐ Hartung-Knapp adjustment applied
- ☐ Heterogeneity assessed and reported
- ☐ Prediction interval calculated
- ☐ Forest plot includes all required elements
- ☐ Results independently verified by second analyst

### 5.4 Documentation
- Analysis script (R code)
- Meta-analysis output (text file)
- Forest plot (high-resolution PNG or PDF)
- Results summary table
- Heterogeneity assessment
- Second analyst verification

---

## SOP-006: Network Meta-Analysis

### 6.1 Purpose
Conduct network meta-analysis with inconsistency assessment following NICE DSU TSD 4.

### 6.2 Procedure

#### Step 1: Network Diagram
```r
library(netmeta)

# Create network
net <- netmeta(
  TE = log_or,
  seTE = se_log_or,
  treat1 = treatment1,
  treat2 = treatment2,
  studlab = study_id,
  data = data,
  reference = "Placebo",
  sm = "OR"
)

# Plot network
netgraph(net,
         plastic = FALSE,
         thickness = "number.of.studies",
         multiarm = TRUE)
```

#### Step 2: Assess Network Connectivity
- Verify all treatments connected
- Identify multi-arm trials
- Check for star-shaped networks (may be problematic)

#### Step 3: Transitivity Assessment
**Critical Assumption**: Transitivity (similarity) assumes trials comparing different treatments are similar with respect to effect modifiers.

```r
library(EvidenceOS)

# Identify effect modifiers
effect_modifiers <- c("mean_age", "percent_male", "baseline_risk", "study_quality")

# Assess transitivity
transitivity <- assess_transitivity(
  data = data,
  effect_modifiers = effect_modifiers,
  treatment_var = "treatment1",
  study_var = "study_id",
  categorical = c("study_quality"),
  continuous = c("mean_age", "percent_male", "baseline_risk")
)

# Print assessment
print(transitivity)

# Visualize
plot_transitivity(transitivity)  # Overview
plot_transitivity(transitivity, variable = "mean_age")  # Specific variable

# Network coherence
coherence <- assess_network_coherence(net)
print(coherence)

# Generate report
transitivity_report <- create_transitivity_report(
  transitivity = transitivity,
  coherence = coherence,
  output_file = "transitivity_assessment.md"
)
```

**Interpretation**:
- **p < 0.05**: Strong evidence of heterogeneity across comparisons (transitivity concern)
- **p < 0.10**: Some evidence of heterogeneity (interpret with caution)
- **p ≥ 0.10**: No strong evidence against transitivity

**Action if Transitivity Violated**:
1. **Meta-regression**: Adjust for effect modifiers showing heterogeneity
2. **Subgroup analysis**: Stratify by problematic effect modifiers
3. **Sensitivity analysis**: Exclude studies with extreme values
4. **Cautious interpretation**: Acknowledge limitation in report

**Quality Check**: ✓ Effect modifiers identified a priori in protocol

#### Step 4: Consistency Model
```r
# Fit consistency model (assumption: no inconsistency)
net_consistency <- netmeta(
  TE = TE,
  seTE = seTE,
  treat1 = treatment1,
  treat2 = treatment2,
  studlab = study_id,
  data = data,
  reference = "Placebo",
  sm = "OR",
  comb.fixed = FALSE,
  comb.random = TRUE
)

# Extract results
netleague(net_consistency, bracket = "(", digits = 2)
```

#### Step 5: Inconsistency Assessment
**Method 1: Node-Splitting**
```r
library(EvidenceOS)

# Automated node-splitting for all comparisons
node_split_results <- node_splitting_all(
  data = data,
  reference = "Placebo",
  sm = "OR"
)

print(node_split_results)

# Check for significant inconsistency
inconsistent <- node_split_results[node_split_results$p_value < 0.05, ]

if (nrow(inconsistent) > 0) {
  cat("⚠️ INCONSISTENCY DETECTED in", nrow(inconsistent), "comparison(s):\n")
  print(inconsistent)
}
```

**Method 2: Design-by-Treatment Interaction**
```r
# Global inconsistency test
design_test <- design_by_treatment_test(
  data = data,
  reference = "Placebo",
  sm = "OR"
)

cat("Global inconsistency test p-value:", design_test$global_p_value, "\n")
```

#### Step 6: Handle Inconsistency
If inconsistency detected (p < 0.05):
1. **Investigate sources**: Check for effect modifiers, study differences
2. **Subgroup analysis**: Stratify by potential modifiers
3. **Meta-regression**: Adjust for study-level covariates
4. **Sensitivity analysis**: Exclude problematic studies
5. **Report findings**: Document inconsistency and actions taken

#### Step 7: Ranking Treatments
```r
# Calculate treatment rankings (SUCRA)
ranks <- netrank(net_consistency, small.values = "good")

# Plot rankings
plot(ranks)

# P-scores (alternative to SUCRA)
pscores <- netmeta::netposet(net_consistency)
```

#### Step 8: Report Results
**Required Elements**:
- Network diagram
- Number of studies, treatments, patients
- **Transitivity assessment** (effect modifiers, similarity across comparisons)
- Network coherence evaluation
- Consistency model results (league table)
- Inconsistency assessment (node-splitting, design-by-treatment)
- Treatment rankings (with uncertainty)
- Heterogeneity assessment (τ²)

### 6.3 Quality Control Checklist
- ☐ Network connectivity verified
- ☐ **Transitivity assumption assessed** with effect modifiers
- ☐ Network coherence evaluated
- ☐ Consistency assumption tested
- ☐ Inconsistency investigated if detected
- ☐ Treatment rankings calculated with uncertainty
- ☐ Results independently verified

### 6.4 Documentation
- Network diagram
- **Transitivity assessment report**
- Network coherence evaluation
- League table
- Node-splitting results
- Inconsistency assessment report
- Treatment ranking plots
- Verification by second analyst

---

## SOP-007: Publication Bias Assessment

### 7.1 Purpose
Systematically assess and correct for publication bias using multiple methods.

### 7.2 Procedure

#### Step 1: Funnel Plot
```r
# Visual inspection
funnel(ma, xlab = "Effect size (log OR)")

# Enhanced funnel plot with contours
funnel(ma,
       contour = c(0.90, 0.95, 0.99),
       col.contour = c("darkgray", "gray", "lightgray"))
legend("topright",
       c("p < 0.01", "p < 0.05", "p < 0.10"),
       fill = c("lightgray", "gray", "darkgray"))
```

**Interpretation**:
- Asymmetry suggests potential bias
- But can also indicate heterogeneity
- Visual inspection alone is insufficient

#### Step 2: Egger's Test
```r
# Regression test for funnel plot asymmetry
egger_test <- metabias(ma, method.bias = "linreg")

cat("Egger's test p-value:", egger_test$p.value, "\n")

if (egger_test$p.value < 0.10) {
  cat("⚠️ Egger's test suggests possible publication bias\n")
}
```

#### Step 3: PET-PEESE Analysis
```r
library(EvidenceOS)

# Extract effect sizes and variances
yi <- ma$TE
vi <- ma$seTE^2

# Run PET-PEESE
petpeese_result <- pet_peese(yi = yi, vi = vi, alpha = 0.10)

print(petpeese_result)

# Compare with conventional estimate
cat("\nConventional estimate:", round(ma$TE.random, 3), "\n")
cat("PET-PEESE estimate:", round(petpeese_result$recommended_estimate, 3), "\n")

# Create funnel plot with PET-PEESE lines
funnel_petpeese(yi, vi)
```

#### Step 4: Trim-and-Fill
```r
# Trim-and-fill imputation
tf <- trimfill(ma)

cat("Estimated missing studies:", tf$k0, "\n")
cat("Adjusted estimate:", round(tf$TE.random, 3),
    "(95% CI:", round(tf$lower.random, 3), "-", round(tf$upper.random, 3), ")\n")

# Funnel plot with imputed studies
funnel(tf, col.missing = "red", pch.missing = 24)
```

#### Step 5: Sensitivity Analysis
```r
# Contour-enhanced funnel plot to distinguish bias from heterogeneity
funnel(ma, contour = c(0.90, 0.95, 0.99))

# Check if studies fall in non-significance contour (suggests bias)
```

#### Step 6: Report Publication Bias Assessment
**Recommended Reporting**:
> "We assessed publication bias using funnel plots, Egger's test, and PET-PEESE. The funnel plot showed asymmetry, and Egger's test was significant (p = 0.042), suggesting possible small-study effects. PET-PEESE analysis estimated the bias-corrected effect as OR 0.68 (95% CI 0.52-0.89), compared to the conventional random-effects estimate of OR 0.75 (95% CI 0.64-0.89). Trim-and-fill imputed 3 missing studies, with adjusted estimate OR 0.72 (95% CI 0.61-0.85). While publication bias cannot be ruled out, the effect remains statistically significant after adjustment."

### 7.3 Decision Criteria
**When to report results as affected by publication bias**:
- Egger's test p < 0.10 AND
- PET-PEESE correction > 20% change AND
- Trim-and-fill imputes > 3 studies

**When to conduct formal bias adjustment**:
- ≥ 10 studies AND
- At least one bias indicator significant AND
- Effect still clinically meaningful after correction

### 7.4 Quality Control
- ☐ At least 10 studies for bias assessment
- ☐ Multiple methods used (funnel plot, Egger's, PET-PEESE, trim-and-fill)
- ☐ Results interpreted cautiously
- ☐ Effect remains after bias correction
- ☐ Limitations discussed

---

## SOP-008: Heterogeneity Assessment

*(Abbreviated - full details in main SOP document)*

**Step 1**: Calculate heterogeneity statistics (τ², I², Q)
**Step 2**: Investigate sources (subgroup analysis, meta-regression)
**Step 3**: Conduct sensitivity analyses
**Step 4**: Report findings with clinical interpretation

---

## SOP-009: Sensitivity Analysis

*(Abbreviated)*

**Mandatory Sensitivity Analyses**:
1. Fixed-effect vs random-effects model
2. Exclusion of high risk of bias studies
3. Exclusion of outliers (if present)
4. Different effect measures (OR vs RR)

---

## SOP-010: Health Economic Analysis

*(Abbreviated)*

**Step 1**: Define decision problem (interventions, comparators, outcomes)
**Step 2**: Build economic model (Markov, decision tree)
**Step 3**: Populate model with meta-analysis results
**Step 4**: Run probabilistic sensitivity analysis (1000+ iterations)
**Step 5**: Calculate ICER, EVPI, EVPPI
**Step 6**: Present cost-effectiveness plane and acceptability curves

---

## SOP-011: Results Export and Reporting

### 11.1 Purpose
Standardize export and reporting of meta-analysis results for manuscripts and reports.

### 11.2 Procedure

#### Step 1: Generate Summary Tables
```r
# Meta-analysis summary table
summary_table <- data.frame(
  analysis = "Primary analysis",
  k = ma$k,
  n = sum(ma$n.e + ma$n.c),
  effect = round(exp(ma$TE.random), 2),
  ci_lower = round(exp(ma$lower.random), 2),
  ci_upper = round(exp(ma$upper.random), 2),
  p_value = format.pval(ma$pval.random, digits = 3),
  i2 = paste0(round(ma$I2, 1), "%"),
  tau2 = round(ma$tau^2, 3)
)

write.csv(summary_table, "meta_analysis_results.csv")
```

#### Step 2: Export Figures
- Forest plot (600 DPI, PNG or TIFF)
- Funnel plot (600 DPI)
- Network diagram (if NMA)
- ROB summary plots (600 DPI)

#### Step 3: Generate PRISMA Flow Diagram
```r
library(PRISMAstatement)

# Data for flow diagram
flow_data <- read.csv("prisma_data.csv")

prisma_flowdiagram(
  found = flow_data$records_identified,
  found_other = flow_data$additional_records,
  no_dupes = flow_data$after_dedup,
  screened = flow_data$screened,
  screen_exclusions = flow_data$excluded_title_abstract,
  full_text = flow_data$full_text_assessed,
  full_text_exclusions = flow_data$excluded_full_text,
  included = flow_data$included
)

ggsave("prisma_flowchart.png", width = 8, height = 10, dpi = 600)
```

#### Step 4: Create Statistical Appendix
**Contents**:
- Detailed methods
- Effect size calculations with formulas
- Heterogeneity statistics
- Publication bias assessment results
- Sensitivity analysis results
- Software versions (R, packages)

#### Step 5: Export Data for Transparency
```r
# Export analysis data
write.csv(data, "analysis_data.csv", row.names = FALSE)

# Export full results object
saveRDS(ma, "meta_analysis_object.rds")

# Create reproducible script
writeLines(
  c("# Reproducible meta-analysis",
    "# Date: [DATE]",
    "# Software: R version X.X.X",
    "library(meta)",
    "data <- read.csv('analysis_data.csv')",
    "# ... (full analysis code)",
    ""),
  "reproducible_analysis.R"
)
```

### 11.3 PRISMA Checklist Compliance
Ensure all PRISMA 2020 items addressed:
- ☐ Title identifies as systematic review/meta-analysis
- ☐ Structured abstract
- ☐ Objectives with PICO
- ☐ Eligibility criteria
- ☐ Information sources
- ☐ Search strategy
- ☐ Selection process
- ☐ Data collection
- ☐ Risk of bias assessment
- ☐ Effect measures
- ☐ Synthesis methods
- ☐ Assessment of heterogeneity
- ☐ Assessment of publication bias
- ☐ Results of syntheses
- ☐ Limitations
- ☐ Funding sources

### 11.4 Documentation
- Summary tables (CSV)
- All figures (high resolution)
- PRISMA flow diagram
- Statistical appendix
- Analysis data
- Reproducible R script
- PRISMA checklist

---

## SOP-012: Quality Control and Review

### 12.1 Purpose
Ensure all analyses meet quality standards through systematic review.

### 12.2 Quality Control Checklist

#### Pre-Analysis
- ☐ Protocol registered (PROSPERO or similar)
- ☐ Search strategy peer-reviewed
- ☐ Data extraction form piloted
- ☐ RoB tool appropriate for study design

#### During Analysis
- ☐ Dual screening (Cohen's kappa ≥ 0.70)
- ☐ Dual data extraction (10% minimum)
- ☐ Dual RoB assessment
- ☐ Data validation checks passed
- ☐ Appropriate effect measure selected

#### Analysis Quality
- ☐ Random-effects model justified
- ☐ Heterogeneity assessed and reported
- ☐ Publication bias assessed (if ≥10 studies)
- ☐ Sensitivity analyses conducted
- ☐ Prediction intervals calculated

#### Results
- ☐ Forest plot includes all studies
- ☐ Effect estimates match calculated values
- ☐ CIs correctly calculated
- ☐ Results independently verified
- ☐ PRISMA checklist complete

#### Reporting
- ☐ PRISMA flow diagram
- ☐ Summary of findings table
- ☐ Risk of bias assessment
- ☐ Heterogeneity statistics
- ☐ Publication bias assessment
- ☐ Data availability statement

### 12.3 Independent Verification
**Second Analyst Reviews**:
1. Re-run analysis from raw data
2. Verify all effect estimates
3. Check heterogeneity calculations
4. Validate forest plot accuracy
5. Confirm conclusions supported by data

**Sign-off Requirements**:
- Primary analyst signature
- Second analyst verification
- Statistical reviewer approval (for regulatory submissions)

### 12.4 Documentation
- Completed QC checklist
- Verification report
- Discrepancy resolution log
- Sign-off records

---

## Appendices

### Appendix A: Software Requirements

**R Packages** (Minimum Versions):
- meta (>= 6.0-0)
- metafor (>= 4.0-0)
- netmeta (>= 2.8-0)
- BCEA (>= 2.4-0)

**Python Packages**:
- fastapi (>= 0.104.0)
- pandas (>= 2.1.0)
- pydantic (>= 2.4.0)

### Appendix B: Glossary of Terms

**CI**: Confidence Interval
**EVPI**: Expected Value of Perfect Information
**ICER**: Incremental Cost-Effectiveness Ratio
**NMA**: Network Meta-Analysis
**OR**: Odds Ratio
**PICO**: Population, Intervention, Comparator, Outcome
**PRISMA**: Preferred Reporting Items for Systematic Reviews and Meta-Analyses
**RCT**: Randomized Controlled Trial
**REML**: Restricted Maximum Likelihood
**RoB**: Risk of Bias
**RR**: Risk Ratio
**SMD**: Standardized Mean Difference

### Appendix C: Templates

Available templates:
- Data extraction form
- RoB 2.0 assessment form
- PRISMA checklist
- Protocol template
- Analysis report template

---

**Document Control**
- **SOP ID**: SOP-META-001 to SOP-META-012
- **Version**: 2.0
- **Effective Date**: November 3, 2025
- **Next Review**: November 3, 2026
- **Approved By**: [Pending]

---

*These SOPs are living documents and will be updated based on emerging best practices and regulatory requirements.*
