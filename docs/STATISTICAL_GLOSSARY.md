# Statistical Terms Glossary
## EvidenceOS PRIME - Meta-Analysis Reference

**Purpose**: Quick reference for statistical terms used in meta-analysis.
**Audience**: Users of all levels - from beginners to advanced.

---

## Effect Size Measures

### Odds Ratio (OR)
**What it is**: Ratio of the odds of an event in the treatment group to the odds in the control group.
**Range**: 0 to ∞
**Interpretation**:
- OR = 1.0: No difference between groups
- OR < 1.0: Treatment reduces odds (beneficial for adverse events)
- OR > 1.0: Treatment increases odds (beneficial for positive outcomes)

**Example**: OR = 0.72 means treatment reduces odds by 28% [(1-0.72) × 100%]

**When to use**: Binary outcomes (yes/no, alive/dead, event/no event)

---

### Risk Ratio (RR) / Relative Risk
**What it is**: Ratio of risk in treatment group to risk in control group.
**Range**: 0 to ∞
**Interpretation**: Similar to OR, but more intuitive for clinicians
**Example**: RR = 0.80 means 20% risk reduction

**Note**: OR and RR are similar when events are rare (<10%), but diverge with common events.

---

### Mean Difference (MD)
**What it is**: Difference in means between treatment and control groups.
**Range**: -∞ to +∞
**Units**: Same as outcome measure (e.g., mmHg for blood pressure)
**Interpretation**: Direct difference on original scale

**Example**: MD = -10 mmHg means treatment lowers blood pressure by 10 mmHg on average

**When to use**: Continuous outcomes measured on same scale

---

### Standardized Mean Difference (SMD) / Hedges' g
**What it is**: Mean difference divided by pooled standard deviation.
**Range**: -∞ to +∞
**Units**: Standard deviation units (dimensionless)
**Interpretation**:
- SMD = 0.2: Small effect
- SMD = 0.5: Medium effect
- SMD = 0.8: Large effect

**When to use**: Continuous outcomes measured on different scales (e.g., different depression questionnaires)

---

### Hazard Ratio (HR)
**What it is**: Ratio of hazard rates (instantaneous risk) between groups.
**Range**: 0 to ∞
**Interpretation**: Similar to RR, but for time-to-event data
**Example**: HR = 0.70 means 30% reduction in hazard

**When to use**: Survival analysis, time-to-event outcomes

---

## Heterogeneity Measures

### τ² (tau-squared)
**What it is**: Between-study variance in true effects.
**Range**: 0 to ∞
**Units**: Squared units of effect size
**Interpretation**:
- τ² = 0: All studies share same true effect
- Higher τ²: Greater variability in true effects

**Why it matters**: Used to calculate prediction intervals and weights in random-effects models.

---

### I² (I-squared)
**What it is**: Percentage of total variation due to heterogeneity (not chance).
**Range**: 0% to 100%
**Interpretation** (Cochrane Handbook):
- 0-40%: Low heterogeneity
- 30-60%: Moderate heterogeneity
- 50-90%: Substantial heterogeneity
- 75-100%: Considerable heterogeneity

**Formula**: I² = 100% × (Q - df) / Q, where Q = Cochran's Q statistic

**Example**: I² = 65% means 65% of variation is due to true differences between studies, 35% is due to sampling error.

**Why it matters**: Helps decide if pooling studies is appropriate and whether to explore sources of heterogeneity.

---

### Cochran's Q Test
**What it is**: Statistical test for heterogeneity.
**Null hypothesis**: All studies share the same true effect.
**Interpretation**:
- p < 0.10: Significant heterogeneity (use α = 0.10, not 0.05)
- p ≥ 0.10: No strong evidence of heterogeneity

**Limitation**: Low power with few studies, high power with many studies.
**Recommendation**: Use I² in conjunction with Q test.

---

## Methods for τ² Estimation

### REML (Restricted Maximum Likelihood)
**What it is**: Statistical method for estimating between-study variance (τ²).
**Advantages**:
- Less biased than DerSimonian-Laird
- Better performance with small number of studies
- Accounts for uncertainty in estimating mean effect

**Recommendation**: **Default choice** for most meta-analyses (Cochrane Handbook, Viechtbauer 2005).

---

### DerSimonian-Laird (DL)
**What it is**: Classic non-iterative method for estimating τ².
**Advantages**: Simple, fast, widely used historically
**Disadvantages**:
- Can be biased (especially with few studies)
- Underestimates τ² on average
- Doesn't account for uncertainty

**Recommendation**: Use REML instead (DL retained for historical comparisons).

---

### Maximum Likelihood (ML)
**What it is**: Maximizes likelihood function to estimate τ².
**Difference from REML**: Doesn't adjust for degrees of freedom.
**When to use**: Mainly for sensitivity analyses or when comparing nested models.

---

### Empirical Bayes (EB)
**What it is**: Bayesian-inspired approach using observed data.
**When to use**: Alternative to REML, similar performance.

---

### Hunter-Schmidt (HS)
**What it is**: Method from psychometric tradition.
**When to use**: Rare in medical meta-analysis, more common in organizational psychology.

---

## Model Types

### Random-Effects Model
**Assumption**: Studies estimate different but related true effects.
**Interpretation**: Estimates the *average* true effect across studies.
**Weights**: Incorporates both within-study variance and τ².

**When to use**: **Nearly always** - assumes studies differ (realistic for most meta-analyses).

**Advantages**:
- More conservative (wider confidence intervals)
- Appropriate even if I² = 0%
- Generalizable beyond included studies

---

### Fixed-Effect Model
**Assumption**: All studies share one single true effect.
**Interpretation**: Estimates the *common* true effect.
**Weights**: Based only on within-study variance (study size).

**When to use**: **Rarely** - only if you're certain all studies estimate exactly the same effect.

**Disadvantages**:
- Too narrow confidence intervals if heterogeneity exists
- Results only apply to included studies
- Sensitive to large studies

**Cochrane recommendation**: Use random-effects unless specific reason not to.

---

## Confidence Intervals vs. Prediction Intervals

### Confidence Interval (CI)
**What it estimates**: Where the *average* true effect likely is.
**Typical level**: 95%
**Interpretation**: "We are 95% confident the average true effect is between X and Y."

**Example**: Pooled OR = 0.72, 95% CI [0.58, 0.91]
→ Average effect reduces odds by 9-42%

---

### Prediction Interval (PI)
**What it estimates**: Where *individual study* true effects likely are.
**Typical level**: 95%
**Interpretation**: "We expect 95% of true effects in similar studies to fall between X and Y."

**Formula**: PI = θ ± t(k-2) × √(τ² + SE²)
*where θ = pooled effect, k = number of studies, τ² = between-study variance*

**Example**: Pooled OR = 0.72, 95% PI [0.42, 1.21]
→ Future studies could show anything from 58% risk reduction to 21% risk increase!

**Why it matters**:
- More realistic than CI for clinical decision-making
- Shows full range of plausible effects
- Accounts for heterogeneity

**Reference**: Riley et al. (2011) BMJ

---

## Publication Bias Methods

### Funnel Plot
**What it is**: Scatter plot of effect size vs. precision (1/SE).
**Expected shape**: Symmetric inverted funnel
**Asymmetry suggests**: Publication bias (or heterogeneity, or small-study effects)

**Limitation**: Visual inspection only, subjective.

---

### Egger's Test
**What it is**: Regression test for funnel plot asymmetry.
**Null hypothesis**: No small-study effects (funnel plot symmetric).
**Interpretation**:
- p < 0.10: Evidence of asymmetry (use α = 0.10)
- p ≥ 0.10: No strong evidence of bias

**Limitation**: Low power with <10 studies, affected by heterogeneity.

---

### Trim-and-Fill
**What it is**: Imputes missing studies to make funnel plot symmetric.
**Output**: Adjusted pooled effect estimate.
**Limitation**: Strong assumptions, can over-correct.

---

### PET-PEESE (Precision-Effect Test and Precision-Effect Estimate with Standard Error)
**What it is**: Modern regression-based bias correction (Stanley & Doucouliagos 2014).

**PET**: Regresses effect size on standard error → intercept estimates bias-corrected effect
**PEESE**: Regresses effect size on variance → used when PET finds effect

**Selection rule**:
- If PET p-value ≥ 0.10: Use PET estimate
- If PET p-value < 0.10: Use PEESE estimate

**Advantages over trim-and-fill**:
- Better statistical properties
- Automatic method selection
- Provides confidence intervals

**Recommendation**: Preferred modern method for bias correction.

---

## Network Meta-Analysis Terms

### Transitivity (Similarity)
**What it is**: Assumption that trials comparing different treatments are similar regarding effect modifiers.
**Example**: If age modifies treatment effect, trials of A vs. B and B vs. C should have similar age distributions.
**How to assess**: Compare effect modifier distributions across comparisons (EvidenceOS does this automatically!).
**If violated**: Indirect comparisons may be biased.

---

### Consistency
**What it is**: Agreement between direct and indirect evidence.
**Example**:
- Direct: A vs. B shows OR = 0.80
- Indirect (via C): A vs. B shows OR = 0.82
- Consistent!

**How to test**: Node-splitting, design-by-treatment interaction.

---

### Inconsistency
**What it is**: Disagreement between direct and indirect evidence.
**Example**:
- Direct: A vs. B shows OR = 0.80
- Indirect: A vs. B shows OR = 1.20
- Inconsistent!

**Causes**: Transitivity violation, effect modification, bias.
**Action**: Investigate sources, meta-regression, sensitivity analysis.

---

### Node-Splitting
**What it is**: Separates direct vs. indirect evidence for a comparison.
**Output**: p-value for inconsistency.
**Interpretation**:
- p < 0.05: Significant inconsistency
- p ≥ 0.05: No strong evidence of inconsistency

**Reference**: NICE DSU TSD 4 (Dias et al. 2010)

---

### SUCRA (Surface Under the Cumulative Ranking Curve)
**What it is**: Probability-based treatment ranking (0% to 100%).
**Interpretation**:
- SUCRA = 100%: Treatment always ranks best
- SUCRA = 0%: Treatment always ranks worst
- SUCRA = 50%: Average ranking

**Example**: Treatment A has SUCRA = 85% → ranks in top positions 85% of the time.

**Caution**: Rankings can be misleading if effects are similar. Always report effect estimates and confidence intervals!

---

### League Table
**What it is**: Matrix showing all pairwise treatment comparisons.
**Format**: Upper triangle = OR (95% CI), Lower triangle = opposite comparison.
**Interpretation**: Compares every treatment to every other treatment.

---

## Adjustment Methods

### Hartung-Knapp Adjustment
**What it is**: Adjustment for uncertainty in estimating τ².
**Effect**: Wider confidence intervals (more conservative).
**When to use**: Small meta-analyses (k < 30 studies).
**Recommendation**: **Enabled by default** in EvidenceOS (Cochrane Handbook recommendation).

**Reference**: Hartung & Knapp (2001), IntHout et al. (2014)

---

### Continuity Correction
**What it is**: Adding 0.5 to all cells when studies have zero events.
**Why needed**: Cannot calculate log OR/RR with zero cells.
**Default**: Applied automatically to studies with zero events.

**Alternative**: Exclude double-zero studies (events = 0 in both groups).

---

## Health Economics Terms

### ICER (Incremental Cost-Effectiveness Ratio)
**What it is**: Cost per additional unit of benefit.
**Formula**: ICER = (Cost_Treatment - Cost_Control) / (Effect_Treatment - Effect_Control)
**Units**: £ per QALY (or $ per QALY)

**Interpretation**:
- ICER < £20,000/QALY: Cost-effective (NICE threshold, UK)
- ICER < $50,000/QALY: Cost-effective (US informal threshold)

---

### QALY (Quality-Adjusted Life Year)
**What it is**: Life year adjusted for quality of life (0 = death, 1 = perfect health).
**Example**: Living 10 years at 0.8 quality = 8 QALYs.

---

### CEAC (Cost-Effectiveness Acceptability Curve)
**What it is**: Probability treatment is cost-effective at different willingness-to-pay thresholds.
**X-axis**: Willingness-to-pay (£/QALY)
**Y-axis**: Probability cost-effective

---

### EVPI (Expected Value of Perfect Information)
**What it is**: Maximum amount worth paying to eliminate all uncertainty.
**Units**: £ (or $)
**Use**: Prioritize future research - if EVPI > cost of RCT, research is worthwhile.

**Reference**: Claxton (1999)

---

## Risk of Bias (RoB 2.0)

### RoB 2.0 Domains
1. **Randomization process**: Was allocation sequence random and concealed?
2. **Deviations from intended interventions**: Were there protocol deviations?
3. **Missing outcome data**: Were outcomes available for all participants?
4. **Measurement of outcome**: Was outcome measurement appropriate?
5. **Selection of reported result**: Was result likely selectively reported?

### Ratings
- **Low risk**: Bias unlikely to seriously alter results
- **Some concerns**: Bias raises some doubt about results
- **High risk**: Bias seriously weakens confidence in results

### Overall Risk Algorithm (Sterne et al. 2019)
- Any domain "High" → Overall "High"
- Any domain "Some concerns" → Overall "Some concerns"
- All domains "Low" → Overall "Low"

---

## Common Abbreviations

| Abbreviation | Full Term |
|--------------|-----------|
| CI | Confidence Interval |
| PI | Prediction Interval |
| OR | Odds Ratio |
| RR | Risk Ratio / Relative Risk |
| HR | Hazard Ratio |
| MD | Mean Difference |
| SMD | Standardized Mean Difference |
| REML | Restricted Maximum Likelihood |
| DL | DerSimonian-Laird |
| NMA | Network Meta-Analysis |
| RoB | Risk of Bias |
| SUCRA | Surface Under Cumulative Ranking Curve |
| ICER | Incremental Cost-Effectiveness Ratio |
| QALY | Quality-Adjusted Life Year |
| EVPI | Expected Value of Perfect Information |
| CEAC | Cost-Effectiveness Acceptability Curve |
| NICE | National Institute for Health and Care Excellence (UK) |
| PICO | Population, Intervention, Comparator, Outcome |

---

## Key References

### Meta-Analysis Methods
- DerSimonian R, Laird N (1986). Meta-analysis in clinical trials. *Controlled Clinical Trials* 7:177-188.
- Hartung J, Knapp G (2001). A refined method for the meta-analysis of controlled clinical trials. *Statistics in Medicine* 20:3875-3889.
- Riley RD et al. (2011). Interpretation of random effects meta-analyses. *BMJ* 342:d549.

### Publication Bias
- Egger M et al. (1997). Bias in meta-analysis detected by a simple, graphical test. *BMJ* 315:629-634.
- Stanley TD, Doucouliagos H (2014). Meta-regression approximations to reduce publication selection bias. *Research Synthesis Methods* 5:60-78.

### Network Meta-Analysis
- Dias S et al. (2010). Checking consistency in mixed treatment comparison meta-analysis. *Statistics in Medicine* 29:932-944.
- Jansen JP et al. (2013). Is network meta-analysis as valid as standard pairwise meta-analysis? *BMJ* 347:f4539.
- Salanti G (2012). Indirect and mixed-treatment comparison, network, or multiple-treatments meta-analysis. *J Clin Epidemiol* 65:707-715.

### Risk of Bias
- Sterne JAC et al. (2019). RoB 2: a revised tool for assessing risk of bias in randomised trials. *BMJ* 366:l4898.

### Health Economics
- Claxton K (1999). The irrelevance of inference: a decision-making approach to the stochastic evaluation of health care technologies. *J Health Econ* 18:341-364.
- Briggs A et al. (2006). *Decision Modelling for Health Economic Evaluation*. Oxford University Press.

---

**Last Updated**: November 3, 2025
**Version**: 2.1.0
**For more details**: See EvidenceOS PRIME Quick Start Guide

