# Known Issues & Limitations: Phase 3-4

**Date:** 2025-11-03
**Version:** v2.3.0 (Phase 3-4)
**Status:** Development/Framework

---

## 🎯 Overview

This document catalogs all known issues, limitations, and TODOs for the newly implemented Phase 3-4 features. These are **NOT bugs** but rather documented limitations of the current implementation.

---

## 📊 Phase 3: Advanced Analytics

### 3.4 Advanced Publication Bias ⚠️

#### Missing Dependencies
**Issue:** Requires external R packages not in base distribution
**Impact:** Features will fail if packages not installed
**Affected Methods:**
- p-uniform → Requires `puniform` package
- p-uniform* → Requires `puniform` package
- Selection Models (3PSM/4PSM) → Requires `weightr` package

**Workaround:**
```r
install.packages(c("puniform", "weightr"))
```

**Error Handling:** ✅ Wrapped in tryCatch with user-friendly messages

---

#### p-curve Minimum Studies
**Issue:** p-curve requires ≥10 studies with significant p-values (p < 0.05)
**Impact:** Will return error if insufficient significant studies
**Expected Behavior:**
- < 10 significant studies → Error message: "p-curve requires at least 10 significant studies"
- No significant studies → Method unavailable

**Workaround:** Use other methods (PET-PEESE, Egger's test) when < 10 significant studies

**Error Handling:** ✅ Checks study count, shows user-friendly error

---

#### Selection Model Convergence
**Issue:** Vevea-Hedges selection models may not converge with:
- Very sparse data (< 10 studies)
- Extreme heterogeneity
- Unusual p-value distributions

**Impact:** Method will fail for some datasets

**Expected Behavior:**
- Convergence failure → Error caught, user notified
- Suggests: "Try different prior specifications or use other methods"

**Workaround:** Use PET-PEESE or p-curve as alternatives

**Error Handling:** ✅ tryCatch wraps all model fitting

---

#### Method-Specific Limitations
1. **Egger's Test:**
   - Low power with < 10 studies
   - Sensitive to heterogeneity
   - May show false positives

2. **Trim-and-Fill:**
   - Assumes symmetric funnel plot
   - May over-impute studies
   - Not suitable for all bias patterns

3. **PET-PEESE:**
   - Assumes linear relationship
   - May overcorrect with few studies
   - Sensitive to outliers

**Status:** Documented in help text ✅

---

### 3.5 Customizable Report Templates ✅ (Updated 2025-11-03)

#### Report Generation Backend - NOW IMPLEMENTED
**Status:** ✅ Word document generation fully functional
**Update:** All 22 section rendering functions now pull real data from reactive values
**Current State:**
- Template creation: ✅ Fully functional
- Template management: ✅ Fully functional
- Save/load templates: ✅ Fully functional
- **Word report generation:** ✅ **NOW COMPLETE**
- PDF/HTML/PowerPoint: ⚠️ Still placeholder (low priority)

**Implemented Functions:**
```r
generate_word_report()    # ✅ COMPLETE - uses officer package
render_ma_results_section()    # ✅ Pulls pairwise_results
render_he_results_section()    # ✅ Pulls he_results
render_heterogeneity_section() # ✅ I², tau², Q statistics
render_exec_summary_section()  # ✅ Comprehensive summary
# + 18 more sections fully implemented
```

**What's Included:**
- Executive summary with pooled effects, CIs, p-values
- Meta-analysis results with detailed statistics
- Heterogeneity assessment (I², tau², Q-test)
- Health economic results (ICER, costs, QALYs)
- All 22 section types with proper null checking
- Formatted output with clinical interpretations

**Remaining Limitations:**
- Section ordering: ⚠️ Manual (drag-drop not implemented - low priority)
- Figure embedding: ⚠️ Placeholder text only (complex, would require plot generation)
- PDF/HTML generation: ⚠️ Not implemented (rmarkdown integration needed)
- Custom branding: ⚠️ Logo/color application not complete

**Priority:** Low (core Word generation with real data now works)

---

### 3.6 Study-Level Annotations ⚠️

#### Tag Cloud Visualization
**Issue:** Uses simple barplot instead of true word cloud
**Impact:** Less visually appealing than expected
**Current State:** Bar chart of top 10 tags

**Ideal State:** True word cloud with size ∝ frequency

**Reason:** Avoids dependency on `wordcloud2` package

**Workaround:** Current visualization is functional, just less aesthetic

**TODO:**
```r
# Option 1: Add wordcloud2 dependency
# library(wordcloud2)
# wordcloud2(tag_freq_df)

# Option 2: Use ggplot2 for better bar chart
# With colors, spacing, rotated labels
```

---

#### Bulk Operations
**Issue:** Partially implemented
**Impact:** Some bulk actions don't work yet
**Current State:**
- Bulk export: ✅ Works
- Bulk tag: ⚠️ UI exists, logic incomplete
- Bulk flag: ⚠️ UI exists, logic incomplete
- Bulk delete: ⚠️ UI exists, logic incomplete

**TODO:**
```r
observeEvent(input$bulk_tag, {
  # Get selected rows from DT
  # Apply tag to all selected studies
  # Save updates
})
```

---

## 🧬 Phase 4: Methodological Extensions

### 4.1 GRADE Assessment Module ✅

#### Fully Functional
**Status:** ✅ Complete and ready for use
**Known Limitations:** None critical

**Minor Limitation:**
- Auto-detection requires prior meta-analysis
- If no prior analysis, auto-suggestions show "N/A"

**Impact:** Minimal - user can still manually assess

---

### 4.2 Bayesian Network Meta-Analysis ⚠️⚠️⚠️ (Updated 2025-11-03)

#### **CRITICAL: SIMULATION ONLY**
**Issue:** ⚠️ **NO ACTUAL BAYESIAN BACKEND IMPLEMENTED**
**Impact:** 🔴 **ALL RESULTS ARE SIMULATED FOR DEMONSTRATION PURPOSES**
**Status:** Framework/scaffold only

**SAFETY UPDATE (2025-11-03):**
✅ **Prominent warning banner now displayed in UI**
- Yellow/red styling with high visibility
- Clear messaging: "DEMO MODE - SIMULATION ONLY"
- Warns users NOT to use for real analysis, publications, or decisions
- Prevents misuse and accidental reliance on simulated data

**What Works:**
- ✅ Complete UI with all controls
- ✅ Prior specifications
- ✅ MCMC settings
- ✅ All visualizations (rankogram, SUCRA, trace plots)
- ✅ Convergence diagnostics display
- ✅ League tables, probability statements
- ✅ **Warning banner preventing misuse**

**What Doesn't Work:**
- ❌ **Actual MCMC sampling** (uses simulated data)
- ❌ **Real posterior distributions** (uses `arima.sim` to fake autocorrelation)
- ❌ **True treatment rankings** (uses random probabilities)
- ❌ **Genuine convergence** (R-hat and ESS are simulated)

**Current Implementation:**
```r
run_bayesian_nma_simulation <- function(...) {
  # This is a SIMULATION - not real MCMC!
  # Uses: arima.sim(), rnorm(), runif()
  # Generates fake posterior samples with autocorrelation
  # Returns: Plausible-looking but SIMULATED results
}
```

**TODO for Production:**
```r
# Option 1: brms (R, Stan backend) ⭐ RECOMMENDED
library(brms)
model <- brm(
  yi | se(sei) ~ 0 + treatment + (1 | study),
  data = network_data,
  prior = c(
    prior(normal(0, 1.5), class = "b"),
    prior(half_cauchy(0, 0.5), class = "sd")
  ),
  chains = 4,
  iter = 10000,
  warmup = 5000
)

# Option 2: PyMC (Python, via reticulate)
# Requires Python setup
# More flexible but more complex

# Option 3: R2jags (R, JAGS backend)
# Mature but slower than Stan

# Option 4: rstan (R, Stan directly)
# Most control but steeper learning curve
```

**Estimated Effort:** 40-80 hours for full backend integration

**Priority:** HIGH if Bayesian NMA needed for regulatory submissions

**Workaround:** Use for UI/UX testing and demonstration only. For actual analysis, use frequentist NMA module.

---

### 4.3 IPD Meta-Analysis ⚠️⚠️ (Updated 2025-11-03)

#### **FRAMEWORK ONLY**
**Issue:** ⚠️ **NO ACTUAL STATISTICAL MODELS IMPLEMENTED**
**Impact:** 🟡 **Results are placeholders**
**Status:** UI framework complete, statistical backend needed

**SAFETY UPDATE (2025-11-03):**
✅ **Prominent warning banner now displayed in UI**
- Yellow/red styling with danger border
- Clear messaging: "FRAMEWORK ONLY - NOT PRODUCTION READY"
- Warns users NOT to use for real analysis, publications, or decisions
- Explains full implementation requires lme4/glmer backend

**What Works:**
- ✅ Data import (CSV, RDS, Rdata)
- ✅ Variable specification UI
- ✅ Method selection (one-stage vs two-stage)
- ✅ Outcome type selection
- ✅ Covariate selection
- ✅ Results display structure
- ✅ **Warning banner preventing misuse**

**What Doesn't Work:**
- ❌ **Actual mixed effects models** (returns simulated results)
- ❌ **Real parameter estimates** (uses rnorm())
- ❌ **Genuine heterogeneity** (simulated)
- ❌ **True forest plots** (placeholder)
- ❌ **Survival analysis** (Cox models not implemented)

**Current Implementation:**
```r
run_one_stage_ipd <- function(...) {
  # TODO: Full implementation
  # Placeholder returns simulated results
  list(
    treatment_effect = rnorm(1, 0.5, 0.1),  # Fake!
    ci_lower = rnorm(1, 0.2, 0.05),         # Fake!
    p_value = runif(1, 0.001, 0.05)         # Fake!
  )
}
```

**TODO for Production:**
```r
# One-stage approach with lme4
library(lme4)

# Binary outcome
model <- glmer(
  outcome ~ treatment + age + sex + (1 + treatment | study_id),
  data = ipd_data,
  family = binomial(),
  control = glmerControl(optimizer = "bobyqa")
)

# Continuous outcome
model <- lmer(
  outcome ~ treatment + age + sex + (1 + treatment | study_id),
  data = ipd_data
)

# Time-to-event
library(survival)
library(coxme)
model <- coxme(
  Surv(time, event) ~ treatment + age + sex + (1 | study_id),
  data = ipd_data
)
```

**Estimated Effort:** 60-100 hours for full implementation

**Priority:** MEDIUM - Only needed if IPD data available

**Workaround:** Use for UI demonstration. For actual IPD analysis, use external statistical software (SAS, Stata, R directly).

---

### 4.4 Partitioned Survival Analysis ⚠️⚠️ (Updated 2025-11-03)

#### **FRAMEWORK ONLY**
**Issue:** ⚠️ **NO ACTUAL PARAMETRIC CURVE FITTING**
**Impact:** 🟡 **Curve fit statistics are simulated**
**Status:** UI complete, survival backend needed

**SAFETY UPDATE (2025-11-03):**
✅ **Prominent warning banner now displayed in UI**
- Yellow/red styling with danger border
- Clear messaging: "FRAMEWORK ONLY - NOT PRODUCTION READY"
- Warns users NOT to use for HTA submissions or decision-making
- Explains full implementation requires flexsurv backend

**What Works:**
- ✅ State definition UI
- ✅ Data upload (PFS, OS)
- ✅ Distribution selection
- ✅ Utility input fields
- ✅ Time horizon specification
- ✅ Visualization structure
- ✅ **Warning banner preventing misuse**

**What Doesn't Work:**
- ❌ **Actual survival curve fitting** (returns fake AIC/BIC)
- ❌ **Real extrapolation** (uses random values)
- ❌ **Genuine area under curve** (simulated)
- ❌ **True QALY calculations** (placeholder)
- ❌ **Parametric models** (no flexsurv integration)

**Current Implementation:**
```r
fit_parametric_curves <- function(...) {
  # TODO: Actual curve fitting using flexsurv
  # Placeholder returns simulated fit statistics
  data.frame(
    Distribution = distributions,
    AIC = runif(length(distributions), 500, 700),  # Fake!
    BIC = runif(length(distributions), 510, 720)   # Fake!
  )
}
```

**TODO for Production:**
```r
# Parametric survival models with flexsurv
library(flexsurv)

# Fit multiple distributions
distributions <- c("exp", "weibull", "lnorm", "llogis", "gompertz", "gengamma")

fits <- lapply(distributions, function(dist) {
  flexsurvreg(
    Surv(time, event) ~ treatment,
    data = pfs_data,
    dist = dist
  )
})

# Compare AIC/BIC
aic_values <- sapply(fits, AIC)
bic_values <- sapply(fits, BIC)

# Select best fit
best_model <- fits[[which.min(aic_values)]]

# Extrapolate
times <- seq(0, 120, by = 1)  # 10 years in months
predictions <- summary(best_model, t = times)
```

**Estimated Effort:** 40-60 hours for full implementation

**Priority:** MEDIUM - Needed for HTA submissions with survival data

**Workaround:** Use for UI demonstration. For actual partitioned survival, use Excel models or specialized HTA software.

---

## 📋 Summary of Implementation Status

| Module | UI | Backend | Status | Production Ready? |
|--------|----|---------| -------|-------------------|
| **Phase 3** |
| 3.4 Pub Bias | ✅ 100% | ✅ 90% | ⚠️ Needs packages | 🟡 Yes, with deps |
| 3.5 Reports | ✅ 100% | ⚠️ 50% | ⚠️ Partial | 🟡 Templates only |
| 3.6 Annotations | ✅ 100% | ✅ 90% | ⚠️ Minor issues | 🟢 Yes |
| **Phase 4** |
| 4.1 GRADE | ✅ 100% | ✅ 100% | ✅ Complete | 🟢 Yes |
| 4.2 Bayesian NMA | ✅ 100% | ❌ 0% | 🔴 Simulation | 🔴 NO - Demo only |
| 4.3 IPD MA | ✅ 100% | ❌ 10% | 🔴 Framework | 🔴 NO - Demo only |
| 4.4 Partition | ✅ 100% | ❌ 10% | 🔴 Framework | 🔴 NO - Demo only |

**Legend:**
- 🟢 **Production Ready:** Can be used with real data
- 🟡 **Conditional:** Works with caveats
- 🔴 **Not Ready:** Framework/demo only

---

## 🔧 Required Actions for Production

### Immediate (P0)
1. **Install R Packages:**
   ```r
   install.packages(c("puniform", "weightr", "colourpicker"))
   ```

2. **Document Limitations:**
   - Add warning banners to Bayesian NMA, IPD, Partition Survival UIs
   - State clearly: "DEMONSTRATION MODE - Simulation only"

### Short-term (P1) - 2-4 weeks
1. **Complete Report Templates:**
   - Implement `generate_word_report()` with officer
   - Pull actual data from rv reactive values
   - Test with sample reports

2. **Fix Annotations:**
   - Complete bulk operations logic
   - Improve tag cloud visualization

### Medium-term (P2) - 2-3 months
1. **Implement Bayesian NMA Backend:**
   - Choose backend (brms recommended)
   - Integrate with existing UI
   - Validate against published examples

2. **Implement IPD MA Backend:**
   - Integrate lme4 for mixed models
   - Add survival analysis with coxme
   - Test with sample IPD datasets

3. **Implement Partition Survival Backend:**
   - Integrate flexsurv for curve fitting
   - Implement AUC calculations
   - Add QALY computations

---

## 📖 References for Full Implementation

### Bayesian NMA
- **brms documentation:** https://paul-buerkner.github.io/brms/
- **Dias et al. (2013):** "Evidence synthesis for decision making 2: A generalized linear modeling framework"
- **NICE TSD 2-5:** Technical Support Documents on NMA

### IPD Meta-Analysis
- **lme4 documentation:** https://cran.r-project.org/web/packages/lme4/
- **Riley et al. (2010):** "Meta-analysis of individual participant data"
- **Debray et al. (2015):** "Get real in individual participant data (IPD) meta-analysis"

### Partitioned Survival
- **flexsurv documentation:** https://cran.r-project.org/web/packages/flexsurv/
- **Latimer (2013):** "Survival analysis for economic evaluations"
- **Williams et al. (2017):** "Cost-effectiveness analysis in R using a multi-state modeling survival analysis framework"

---

## ✅ What's Actually Production-Ready?

### Fully Functional Modules
1. ✅ **GRADE Assessment** - Complete and tested
2. ✅ **Study Annotations** - Core functionality works
3. ✅ **Report Templates** - Template management works (generation partial)
4. ✅ **Publication Bias** - All methods work (with required packages)

### Demo/Framework Modules
1. ⚠️ **Bayesian NMA** - Beautiful UI, simulation backend
2. ⚠️ **IPD MA** - Complete UI, placeholder backend
3. ⚠️ **Partition Survival** - Full UI, mock calculations

**Recommendation:** Deploy Phases 1-3 + GRADE (4.1) to production. Keep Bayesian NMA, IPD, and Partition Survival as "Coming Soon" features with demo mode.

---

**Last Updated:** 2025-11-03
**Version:** 1.0
**Next Review:** After user testing (2-4 weeks)
