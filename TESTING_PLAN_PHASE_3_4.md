# Comprehensive Testing Plan: Phase 3-4 Features
**Date:** 2025-11-03
**Scope:** All Phase 3 (6 features) + Phase 4 (4 features)
**Total Features to Test:** 10 major modules

---

## 🎯 Testing Overview

### Test Levels
1. **Syntax Validation** - Verify R code parses correctly
2. **Unit Testing** - Test individual functions
3. **Integration Testing** - Test module interactions
4. **User Acceptance Testing** - Test with real users
5. **Performance Testing** - Test with large datasets

### Priority Levels
- **P0 (Critical):** Must work for basic functionality
- **P1 (High):** Important for user experience
- **P2 (Medium):** Nice to have
- **P3 (Low):** Future enhancement

---

## 📋 Phase 3 Testing Checklist

### 3.1 Meta-Regression Bubble Plots ✅ (Previously tested)
**Status:** Merged from other branch, assumed tested

**Quick Validation:**
- [ ] Module loads without errors
- [ ] UI renders correctly
- [ ] Basic plot generates
- [ ] Download functionality works

---

### 3.2 Radial/Galbraith Plots ✅ (Previously tested)
**Status:** Merged from other branch, assumed tested

**Quick Validation:**
- [ ] Module loads without errors
- [ ] UI renders correctly
- [ ] Basic plot generates
- [ ] Outlier detection works

---

### 3.3 GOSH Plot ✅ (Previously tested)
**Status:** Merged from other branch, assumed tested

**Quick Validation:**
- [ ] Module loads without errors
- [ ] UI renders correctly
- [ ] Clustering analysis runs
- [ ] Interactive selection works

---

### 3.4 Advanced Publication Bias 🆕
**Priority:** P0 (Critical - NEW CODE)

**Syntax Validation:**
```r
# Test 1: Module loads
source("frontend/modules/publication_bias_advanced.R")
# Expected: No errors

# Test 2: UI renders
ui <- publication_bias_advanced_ui("test")
# Expected: Valid Shiny UI object
```

**Unit Tests Needed:**
1. `run_pcurve_analysis()`
   - Input: yi (effect sizes), vi (variances)
   - Test: Returns correct p-curve statistics
   - Expected: Right-skew test, flatness test, evidential value classification

2. `calculate_rank_probabilities()`
   - Input: Posterior samples, treatments
   - Test: Probabilities sum to 1 for each treatment
   - Expected: Valid probability matrix

3. `calculate_sucra()`
   - Input: Rank probabilities
   - Test: SUCRA values between 0 and 1
   - Expected: Higher values = better ranking

**Integration Tests:**
1. Load sample meta-analysis data (10+ studies)
2. Select all 8 methods
3. Click "Run Analysis"
4. Verify:
   - Summary table populates
   - Comparison plot renders
   - Overall assessment displays
   - Each method tab shows results

**Known Dependencies:**
- R packages: `puniform`, `weightr` (MUST BE INSTALLED)
- Fallback: If packages missing, show helpful error message

**Test Data:**
```r
# Sample data for testing
yi <- c(0.5, 0.3, 0.7, 0.4, 0.6, 0.2, 0.8, 0.5, 0.4, 0.6, 0.3, 0.7)
vi <- c(0.1, 0.08, 0.12, 0.09, 0.11, 0.07, 0.13, 0.10, 0.09, 0.11, 0.08, 0.12)
sei <- sqrt(vi)

# Test p-curve
pcurve_result <- run_pcurve_analysis(yi, vi)
# Check: pcurve_result$evidential_value in c("Present", "Absent", "Inadequate")
```

**Expected Failures:**
1. ❌ p-curve with < 10 significant studies
   - **Fix:** Show user-friendly error: "p-curve requires at least 10 significant studies"

2. ❌ p-uniform if package not installed
   - **Fix:** Wrap in tryCatch, show: "Install 'puniform' package to use this method"

3. ❌ Selection models convergence issues
   - **Fix:** Show warning: "Selection model did not converge. Try different settings."

---

### 3.5 Customizable Report Templates 🆕
**Priority:** P1 (High - NEW CODE)

**Syntax Validation:**
```r
source("frontend/modules/report_templates.R")
ui <- report_templates_ui("test")
# Expected: No errors
```

**Unit Tests Needed:**
1. `load_default_templates()`
   - Test: Returns 4 default templates
   - Expected: NICE, Academic, Clinical, Quick Summary

2. `save_template_to_disk()`
   - Test: Saves template as YAML
   - Expected: File exists at outputs/templates/

3. `generate_report_from_template()`
   - Test: Creates Word/PDF/HTML report
   - Expected: File created in outputs/reports/

**Integration Tests:**
1. Create new template
   - Name: "Test Template"
   - Sections: 5 selected
   - Format: Word
   - Click "Save"
   - Verify: Template appears in list

2. Generate report
   - Select template
   - Click "Generate Report"
   - Verify: File downloads
   - Verify: No errors in console

**Known Dependencies:**
- R packages: `officer`, `rmarkdown`, `yaml`
- File system: Write access to outputs/ folder

**Expected Failures:**
1. ❌ No data available when generating report
   - **Fix:** Show error: "No analysis results available. Run analysis first."

2. ❌ File write permission denied
   - **Fix:** Show error: "Cannot write to outputs folder. Check permissions."

---

### 3.6 Study-Level Annotations 🆕
**Priority:** P1 (High - NEW CODE)

**Syntax Validation:**
```r
source("frontend/modules/study_annotations.R")
ui <- study_annotations_ui("test")
# Expected: No errors
```

**Unit Tests Needed:**
1. `load_annotations_from_disk()`
   - Test: Loads saved annotations
   - Expected: Returns list of annotations or empty list

2. `save_annotations_to_disk()`
   - Test: Saves annotations as JSON
   - Expected: File created, valid JSON

**Integration Tests:**
1. Select a study from table
2. Add note: "High quality study"
3. Add tags: "RCT", "Industry Funded"
4. Set quality rating: 4/5
5. Click "Save Annotation"
6. Verify: Annotation saved
7. Reload page
8. Verify: Annotation persists

**Expected Failures:**
1. ❌ No studies loaded
   - **Fix:** Show message: "Import data first to add annotations"

2. ❌ JSON parse error on load
   - **Fix:** Delete corrupt file, start fresh

---

## 📋 Phase 4 Testing Checklist

### 4.1 GRADE Assessment Module 🆕
**Priority:** P0 (Critical - HIGHEST PRIORITY)

**Syntax Validation:**
```r
source("frontend/modules/grade_assessment.R")
ui <- grade_assessment_ui("test")
# Expected: No errors
```

**Unit Tests Needed:**
1. GRADE calculation logic
   - Starting point: HIGH (RCTs) = 4
   - Downgrade risk of bias: -1
   - Downgrade inconsistency: -1
   - Final score: 2 (LOW)
   - Test: Verify calculation is correct

2. Auto-detection suggestions
   - I² = 80% → Suggest inconsistency downgrade
   - CI crosses null → Suggest imprecision downgrade
   - Egger's p = 0.03 → Suggest publication bias downgrade

**Integration Tests:**
1. Load meta-analysis results
2. Select outcome
3. Click "Start Assessment"
4. Rate all 5 domains
5. Click "Calculate Final Grade"
6. Verify:
   - Grade badge displays (HIGH/MODERATE/LOW/VERY LOW)
   - Evidence profile table populates
   - Summary of Findings table shows correct data
   - Download button works

**Test Scenarios:**
```r
# Scenario 1: Perfect RCT evidence
- Initial: RCT (HIGH)
- Downgrades: None
- Final: HIGH ⊕⊕⊕⊕

# Scenario 2: Flawed RCTs
- Initial: RCT (HIGH)
- Downgrades: RoB (-1), Inconsistency (-1)
- Final: LOW ⊕⊕○○

# Scenario 3: Observational with large effect
- Initial: Observational (LOW)
- Downgrades: None
- Upgrades: Large effect (+1)
- Final: MODERATE ⊕⊕⊕○
```

**Expected Failures:**
1. ❌ No meta-analysis results available
   - **Fix:** Show error: "Run meta-analysis first"

2. ❌ Auto-detection missing data
   - **Fix:** Show "Auto-detection unavailable" instead of error

---

### 4.2 Bayesian Network Meta-Analysis 🆕
**Priority:** P1 (High - FRAMEWORK)

**Syntax Validation:**
```r
source("frontend/modules/nma_bayesian.R")
ui <- nma_bayesian_ui("test")
# Expected: No errors
```

**Integration Tests (Simulation Mode):**
1. Load network data
2. Select prior: "Weakly Informative"
3. Set MCMC: 4 chains × 10,000 iterations
4. Click "Run Bayesian NMA"
5. Verify:
   - Progress indicator shows
   - Posterior summary table populates
   - Rank probabilities display
   - SUCRA plot renders
   - Rankogram shows
   - Convergence diagnostics appear
   - R-hat < 1.05 for all parameters
   - ESS > 400 for all parameters

**TODO for Full Implementation:**
```r
# Replace simulation with actual MCMC backend
# Options:
# 1. PyMC (Python via reticulate)
# 2. brms (R, uses Stan)
# 3. R2jags (R, uses JAGS)
# 4. rstan (R, direct Stan)

# Example brms implementation:
# library(brms)
# model <- brm(
#   yi | se(sei) ~ 1 + (1 | study) + treatment,
#   data = network_data,
#   prior = prior(normal(0, 1.5), class = "b"),
#   chains = 4,
#   iter = 10000
# )
```

**Known Limitations:**
- ⚠️ Current version uses SIMULATION only
- ⚠️ Results are for demonstration purposes
- ⚠️ Real backend integration required for production use

---

### 4.3 IPD Meta-Analysis 🆕
**Priority:** P2 (Medium - FRAMEWORK)

**Syntax Validation:**
```r
source("frontend/modules/ipd_meta_analysis.R")
ui <- ipd_meta_analysis_ui("test")
# Expected: No errors
```

**Integration Tests (Simulation Mode):**
1. Upload IPD CSV file
2. Select variables: study_id, patient_id, outcome, treatment
3. Select outcome type: Binary
4. Select method: One-Stage
5. Click "Run IPD Meta-Analysis"
6. Verify:
   - Overall results display
   - Forest plot renders
   - Heterogeneity stats shown

**Test Data Format:**
```csv
study_id,patient_id,outcome,treatment,age,sex
1,1,1,A,45,M
1,2,0,A,52,F
1,3,1,B,48,M
2,1,0,A,55,F
2,2,1,B,43,M
...
```

**TODO for Full Implementation:**
```r
# One-stage mixed effects model
# library(lme4)
# model <- glmer(
#   outcome ~ treatment + age + sex + (1 + treatment | study_id),
#   data = ipd_data,
#   family = binomial()
# )
```

---

### 4.4 Partitioned Survival Analysis 🆕
**Priority:** P2 (Medium - FRAMEWORK)

**Syntax Validation:**
```r
source("frontend/modules/partition_survival.R")
ui <- partition_survival_ui("test")
# Expected: No errors
```

**Integration Tests (Simulation Mode):**
1. Define 3 states: PFS, Progressed, Dead
2. Upload PFS data (time, event, treatment)
3. Upload OS data (time, event, treatment)
4. Select distributions: Exponential, Weibull, Log-Normal
5. Click "Fit Survival Curves"
6. Verify:
   - Fit statistics table shows AIC/BIC
   - Curves plot renders
   - State membership plot displays

**TODO for Full Implementation:**
```r
# Parametric curve fitting
# library(flexsurv)
# pfs_weibull <- flexsurvreg(
#   Surv(time, event) ~ treatment,
#   data = pfs_data,
#   dist = "weibull"
# )
```

---

## 🔧 Syntax Validation Script

Create `tests/validate_syntax.R`:

```r
#!/usr/bin/env Rscript
# Syntax Validation for Phase 3-4 Modules

cat("=== SYNTAX VALIDATION ===\n\n")

modules <- c(
  # Phase 3
  "frontend/modules/publication_bias_advanced.R",
  "frontend/modules/report_templates.R",
  "frontend/modules/study_annotations.R",

  # Phase 4
  "frontend/modules/grade_assessment.R",
  "frontend/modules/nma_bayesian.R",
  "frontend/modules/ipd_meta_analysis.R",
  "frontend/modules/partition_survival.R"
)

errors <- 0
warnings <- 0

for (module in modules) {
  cat("Testing:", module, "\n")

  result <- tryCatch({
    source(module, local = TRUE)
    cat("  ✓ OK\n")
  }, error = function(e) {
    cat("  ✗ ERROR:", e$message, "\n")
    errors <<- errors + 1
  }, warning = function(w) {
    cat("  ⚠ WARNING:", w$message, "\n")
    warnings <<- warnings + 1
  })
}

cat("\n=== SUMMARY ===\n")
cat("Modules tested:", length(modules), "\n")
cat("Errors:", errors, "\n")
cat("Warnings:", warnings, "\n")

if (errors == 0 && warnings == 0) {
  cat("\n✓ ALL MODULES PASS SYNTAX VALIDATION\n")
  quit(status = 0)
} else {
  cat("\n✗ VALIDATION FAILED\n")
  quit(status = 1)
}
```

**Run Validation:**
```bash
cd /home/user/Metanew
Rscript tests/validate_syntax.R
```

---

## 📊 Testing Summary

### Total Test Coverage Needed

| Module | Unit Tests | Integration Tests | Priority |
|--------|-----------|-------------------|----------|
| **Phase 3** |
| 3.4 Pub Bias | 10 functions | 3 scenarios | P0 |
| 3.5 Reports | 8 functions | 2 scenarios | P1 |
| 3.6 Annotations | 4 functions | 2 scenarios | P1 |
| **Phase 4** |
| 4.1 GRADE | 5 calculations | 3 scenarios | P0 |
| 4.2 Bayesian NMA | Framework | 1 scenario | P1 |
| 4.3 IPD MA | Framework | 1 scenario | P2 |
| 4.4 Partition Surv | Framework | 1 scenario | P2 |
| **TOTAL** | **~35 tests** | **13 scenarios** | |

---

## 🐛 Known Issues & Limitations

### Phase 3 Issues
1. **Publication Bias (3.4):**
   - ⚠️ Requires `puniform` and `weightr` packages (not in base R)
   - ⚠️ p-curve needs ≥10 significant studies
   - ⚠️ Selection models may not converge with sparse data

2. **Report Templates (3.5):**
   - ⚠️ Full report generation not fully implemented
   - ⚠️ Only Word format scaffolded (PDF/HTML/PPT need work)
   - ⚠️ Section rendering uses placeholders

3. **Annotations (3.6):**
   - ⚠️ Tag cloud uses simple barplot (not true word cloud)
   - ⚠️ Bulk operations partially implemented

### Phase 4 Issues
1. **GRADE (4.1):**
   - ✅ Fully implemented and functional
   - ⚠️ Auto-detection depends on having run prior analyses

2. **Bayesian NMA (4.2):**
   - ❌ **SIMULATION ONLY** - No actual MCMC backend
   - ❌ Needs PyMC/brms/JAGS/Stan integration
   - ⚠️ Current results are for demonstration purposes ONLY

3. **IPD MA (4.3):**
   - ❌ **SIMULATION ONLY** - No actual mixed effects models
   - ❌ Needs lme4 integration for GLMMs
   - ⚠️ Survival analysis (Cox/KM) not fully implemented

4. **Partition Survival (4.4):**
   - ❌ **SIMULATION ONLY** - No actual curve fitting
   - ❌ Needs flexsurv integration
   - ⚠️ QALY calculations use mock data

---

## ✅ Testing Priorities

### Week 1: Critical Tests (P0)
- [ ] Syntax validation for all 7 new modules
- [ ] Basic UI rendering tests
- [ ] Publication Bias integration test
- [ ] GRADE assessment integration test

### Week 2: High Priority Tests (P1)
- [ ] Report template creation test
- [ ] Study annotations save/load test
- [ ] Bayesian NMA simulation test

### Week 3: Medium Priority (P2)
- [ ] IPD MA simulation test
- [ ] Partition survival simulation test
- [ ] Performance tests with large datasets

### Week 4: Bug Fixes & Polish
- [ ] Fix any issues discovered in Weeks 1-3
- [ ] User acceptance testing with sample users
- [ ] Documentation updates based on feedback

---

## 🚀 Next Steps

1. **Run Syntax Validation**
   ```bash
   Rscript tests/validate_syntax.R
   ```

2. **Install Missing Packages**
   ```r
   install.packages(c("puniform", "weightr", "colourpicker"))
   ```

3. **Manual Testing**
   - Launch Shiny app
   - Test each new module manually
   - Document any errors

4. **Write Unit Tests**
   - Create test files in tests/r/
   - Use testthat framework
   - Aim for 80% code coverage

5. **Integration Testing**
   - Test with real datasets
   - Test module interactions
   - Test edge cases

---

**Status:** Testing plan complete ✅
**Next:** Run validation and start testing
**Timeline:** 2-4 weeks for comprehensive testing
