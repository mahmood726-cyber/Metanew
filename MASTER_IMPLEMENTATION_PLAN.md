# MASTER IMPLEMENTATION PLAN
## 21 Killer Features with Hybrid Rule-Based + AI Approach

**Date:** November 4, 2025
**Approach:** Hybrid (Rule-Based NLP + Ollama AI)
**Goal:** Minimize hallucinations, maximize accuracy, production-grade quality

---

## HYBRID APPROACH PHILOSOPHY

### Why Hybrid (Rules + AI)?

**Problem with Pure AI:**
- Hallucinations (makes up data that doesn't exist)
- Inconsistent outputs (same input → different output)
- Hard to debug and explain
- Compliance issues for HTA submissions

**Problem with Pure Rules:**
- Brittle (breaks on edge cases)
- Requires exhaustive pattern matching
- Can't handle natural language variation
- Misses context and nuance

**Hybrid Solution:**
```
1. Rules for DETERMINISTIC tasks (data extraction, validation)
2. AI for INTERPRETATION tasks (screening decisions, reasoning)
3. Rules VALIDATE AI outputs (sanity checks, constraints)
4. AI ASSISTS rules (handle edge cases, improve recall)
```

### Example: Citation Screening

**Pure AI Approach:**
```
AI: "This study looks relevant" →
Problem: Why? Based on what criteria? Can't audit decision.
```

**Pure Rule Approach:**
```
IF ("diabetes" in title) AND ("RCT" in text) → Include
Problem: Misses "randomized controlled trial", "T2DM", "type 2 diabetes"
```

**Hybrid Approach:**
```
1. RULES: Extract PICO elements (regex + NLP)
   - Population: "adults with type 2 diabetes" → Extract: ["adults", "type 2 diabetes"]
   - Study design: "RCT" → Match: ["RCT", "randomized", "randomised"]

2. AI: Interpret complex criteria
   - "Is 'metformin 1000mg' within scope of 'metformin'?" → AI: Yes
   - "Is 'cardiovascular mortality' within scope of 'mortality'?" → AI: Yes

3. RULES: Validate AI decision
   - IF AI says "Include" BUT no population match → Flag for review
   - IF AI confidence < 80% → Automatic human review
   - IF AI extracts sample size > 1,000,000 → Obviously wrong, reject

4. OUTPUT: Structured + explainable
   - Decision: Include
   - Confidence: 92%
   - Matched criteria: [Population ✓, Intervention ✓, Outcome ✓, RCT ✓]
   - AI reasoning: "Study tests metformin vs placebo in diabetic adults for CV outcomes"
   - Rule validation: All checks passed
```

**Result:**
- ✅ High accuracy (95%+ sensitivity from AI)
- ✅ Explainable (rule-based matching)
- ✅ Auditable (structured output)
- ✅ Reduced hallucinations (rule validation)

---

## IMPLEMENTATION PHASES

### Phase 1: Critical HTA Methods (Weeks 1-16)
**Focus:** Features pharma MUST have for HTA submissions
**Investment:** £120-150k (2 developers × 4 months)
**Revenue Impact:** £500k-1M/year

| # | Feature | Approach | Priority | Weeks |
|---|---------|----------|----------|-------|
| 1 | MAIC/STC | Rules + Stats | ⭐⭐⭐⭐⭐ | 4-5 |
| 2 | Target Trial Emulation | Rules + AI | ⭐⭐⭐⭐⭐ | 6-8 |
| 3 | Multi-State Models | Stats + AI | ⭐⭐⭐⭐⭐ | 5-6 |
| 4 | HTA Dossier Generator | Rules + AI | ⭐⭐⭐⭐⭐ | 6-8 |

### Phase 2: AI & Automation (Weeks 17-28)
**Focus:** Time savings through automation
**Investment:** £50-80k (ML engineer × 3 months)
**Revenue Impact:** +£200k/year (AI premium)

| # | Feature | Approach | Priority | Weeks |
|---|---------|----------|----------|-------|
| 5 | AI Citation Screening (Enhanced) | Rules + AI | ⭐⭐⭐⭐⭐ | 2-3 |
| 6 | AI Data Extraction (Enhanced) | Rules + AI | ⭐⭐⭐⭐⭐ | 2-3 |
| 7 | Automated Living Reviews | Rules + AI | ⭐⭐⭐⭐ | 3-4 |
| 8 | PRISMA 2020 Compliance | Rules | ⭐⭐⭐ | 2 |

### Phase 3: Statistical Methods (Weeks 29-40)
**Focus:** Advanced methods for complex analyses

| # | Feature | Approach | Priority | Weeks |
|---|---------|----------|----------|-------|
| 9 | Propensity Score Methods | Stats + AI | ⭐⭐⭐⭐ | 4-5 |
| 10 | IPD Meta-Analysis | Stats | ⭐⭐⭐ | 3-4 |
| 11 | Threshold Analysis (Enhanced) | Stats | ⭐⭐⭐ | 2-3 |
| 12 | Survival Extrapolation Validation | Stats + AI | ⭐⭐⭐⭐ | 3-4 |
| 13 | Component NMA | Stats | ⭐⭐⭐ | 4-5 |

### Phase 4: Usability & Collaboration (Weeks 41-52)

| # | Feature | Approach | Priority | Weeks |
|---|---------|----------|----------|-------|
| 14 | Reference Manager Integration | Rules | ⭐⭐⭐ | 3-4 |
| 15 | Interactive Visualizations | UI | ⭐⭐⭐ | 3-4 |
| 16 | CE Planes Enhanced | Stats | ⭐⭐ | 1-2 |
| 17 | Real-Time Collaboration | Infrastructure | ⭐⭐⭐ | 6-8 |

### Phase 5: Advanced & Specialized (Weeks 53+)

| # | Feature | Approach | Priority | Weeks |
|---|---------|----------|----------|-------|
| 18 | REML Methods | Stats | ⭐⭐ | 1 |
| 19 | Enhanced Dose-Response | Stats | ⭐⭐ | 2-3 |
| 20 | Federated Data Analysis | Infrastructure | ⭐⭐ | 8-10 |
| 21 | Advanced Budget Impact | Stats | ⭐⭐ | 2-3 |

---

## DETAILED FEATURE SPECIFICATIONS

### Feature 1: MAIC/STC (Population-Adjusted Indirect Comparisons)

**Purpose:** Enable indirect comparisons when no head-to-head RCT exists

**Hybrid Approach:**

**RULES (Deterministic):**
```r
# 1. Data Validation
validate_maic_data <- function(ipd, agd) {
  # Rule: IPD must have all matching variables
  # Rule: Sample size must be > 0
  # Rule: Covariates must be numeric
  # Rule: No missing data in key variables

  checks <- list(
    ipd_complete = all(!is.na(ipd[, matching_vars])),
    agd_complete = all(!is.na(agd[, matching_vars])),
    n_positive = all(ipd$n > 0) && all(agd$n > 0),
    covariate_numeric = all(sapply(ipd[, matching_vars], is.numeric))
  )

  if (!all(unlist(checks))) {
    stop("Data validation failed: ",
         paste(names(checks)[!unlist(checks)], collapse = ", "))
  }
}

# 2. Propensity Score Calculation (deterministic)
calculate_ps <- function(ipd, agd_means) {
  # Use logistic regression (deterministic given data)
  ps_model <- glm(treatment ~ covariates, family = binomial, data = ipd)
  ps <- predict(ps_model, type = "response")
  return(ps)
}

# 3. Calculate Weights (deterministic)
calculate_maic_weights <- function(ipd, agd_means) {
  # Method of moments matching
  # This is pure math - no AI needed

  weights <- optimize_weights(ipd, agd_means)

  # Rule: Check effective sample size
  ess <- (sum(weights))^2 / sum(weights^2)

  if (ess < 0.6 * nrow(ipd)) {
    warning("ESS < 60% of original sample. Results may be unreliable.")
  }

  return(list(weights = weights, ess = ess))
}
```

**AI (Interpretation):**
```r
# AI assists with:
# 1. Suggesting matching variables
suggest_matching_vars <- function(ipd, agd, ollama_client) {
  prompt <- paste0(
    "IPD variables: ", paste(names(ipd), collapse = ", "), "\n",
    "AgD variables: ", paste(names(agd), collapse = ", "), "\n",
    "Which variables are likely effect modifiers for this comparison?\n",
    "Consider: age, sex, disease severity, comorbidities.\n",
    "Return as JSON array."
  )

  ai_suggestions <- ollama_client$generate("llama3", prompt)

  # Rule validation: AI can only suggest variables that exist in BOTH datasets
  valid_suggestions <- intersect(ai_suggestions, intersect(names(ipd), names(agd)))

  return(valid_suggestions)
}

# 2. Interpreting balance diagnostics
interpret_balance <- function(balance_stats, ollama_client) {
  prompt <- paste0(
    "Standardized mean differences:\n",
    paste(balance_stats$variable, balance_stats$smd, collapse = "\n"), "\n",
    "Interpret the balance. Are these populations now comparable?"
  )

  interpretation <- ollama_client$generate("llama3", prompt)

  # Rule check: If any SMD > 0.1, flag as concerning
  concerning <- balance_stats$variable[abs(balance_stats$smd) > 0.1]

  return(list(
    ai_interpretation = interpretation,
    rule_based_concern = concerning
  ))
}
```

**Validation Layer:**
```r
# Rules validate AI and statistical outputs
validate_maic_results <- function(results) {
  checks <- list(
    # Rule: Weights must be positive
    positive_weights = all(results$weights > 0),

    # Rule: ESS must be reasonable
    ess_reasonable = results$ess > 10,

    # Rule: Treatment effect must be finite
    effect_finite = is.finite(results$treatment_effect),

    # Rule: Confidence interval must not be impossibly wide
    ci_reasonable = (results$upper_ci - results$lower_ci) < 100
  )

  if (!all(unlist(checks))) {
    return(list(
      valid = FALSE,
      failed_checks = names(checks)[!unlist(checks)],
      message = "Results failed validation. Review inputs."
    ))
  }

  return(list(valid = TRUE, message = "All validation checks passed"))
}
```

**Implementation Timeline:** Weeks 1-5

**Files to Create:**
- `frontend/modules/maic_stc.R` (500+ lines)
- `backend/stats/maic_engine.py` (300+ lines)
- `tests/test_maic.R` (200+ lines)

---

### Feature 2: AI Citation Screening (Enhanced with Rules)

**Current:** Basic AI screening (already implemented)

**Enhancement:** Add rule-based validation and structured extraction

**Hybrid Approach:**

**RULES (Extract Structured Criteria):**
```r
# 1. Parse inclusion criteria into structured format
parse_pico <- function(criteria_text) {
  # Rule-based extraction using regex + medical ontologies

  population <- extract_population(criteria_text)
  # Patterns: "adults", "patients with", "age > 18"
  # Ontology: Map "T2D" → "type 2 diabetes"

  intervention <- extract_intervention(criteria_text)
  # Patterns: drug names, procedures, interventions
  # Ontology: Map "metformin" → ["metformin", "glucophage", "fortamet"]

  comparator <- extract_comparator(criteria_text)
  # Patterns: "vs", "versus", "compared to"

  outcome <- extract_outcome(criteria_text)
  # Patterns: mortality, CV events, QoL
  # Ontology: "CV events" → ["MI", "stroke", "cardiovascular death"]

  study_design <- extract_study_design(criteria_text)
  # Patterns: "RCT", "randomized", "controlled trial"

  return(list(
    population = population,
    intervention = intervention,
    comparator = comparator,
    outcome = outcome,
    study_design = study_design
  ))
}

# 2. Rule-based matching
rule_based_match <- function(citation, pico) {
  matches <- list()

  # Population matching
  matches$population <- any(sapply(pico$population$terms, function(term) {
    grepl(term, citation$title, ignore.case = TRUE) ||
    grepl(term, citation$abstract, ignore.case = TRUE)
  }))

  # Intervention matching (with synonyms)
  matches$intervention <- any(sapply(pico$intervention$all_terms, function(term) {
    grepl(term, citation$abstract, ignore.case = TRUE)
  }))

  # Study design matching
  matches$study_design <- any(sapply(pico$study_design$patterns, function(pattern) {
    grepl(pattern, citation$title, ignore.case = TRUE) ||
    grepl(pattern, citation$abstract, ignore.case = TRUE)
  }))

  # Calculate rule-based score (0-100)
  rule_score <- (sum(unlist(matches)) / length(matches)) * 100

  return(list(
    matches = matches,
    score = rule_score,
    all_matched = all(unlist(matches))
  ))
}
```

**AI (Semantic Understanding):**
```python
# AI handles nuanced interpretation
class HybridCitationScreener:
    def __init__(self, ollama_client, rule_engine):
        self.ai = ollama_client
        self.rules = rule_engine

    def screen_citation(self, citation, pico):
        # Step 1: Rule-based extraction
        rule_result = self.rules.match(citation, pico)

        # Step 2: If rules are uncertain, ask AI
        if rule_result['score'] < 80:
            ai_result = self.ai_screen(citation, pico)
        else:
            ai_result = None  # Trust rules

        # Step 3: Combine results
        final_decision = self.combine_decisions(rule_result, ai_result)

        # Step 4: Validate
        validated = self.validate_decision(final_decision, citation)

        return validated

    def ai_screen(self, citation, pico):
        """AI for semantic understanding"""
        prompt = f"""
        Inclusion Criteria:
        {pico.to_text()}

        Study:
        Title: {citation.title}
        Abstract: {citation.abstract}

        Question 1: Does the population match? Consider synonyms and related conditions.
        Question 2: Does the intervention match? Consider dosing variations.
        Question 3: Is the study design appropriate?

        Answer YES/NO for each, with brief reasoning.
        """

        response = self.ai.generate("llama3", prompt, temperature=0.3)

        # Parse AI response
        parsed = self.parse_ai_response(response)

        return parsed

    def combine_decisions(self, rule_result, ai_result):
        """Combine rule-based and AI results"""

        # Strategy 1: If rules say definite yes/no, trust them
        if rule_result['all_matched']:
            return {
                'decision': 'include',
                'confidence': 95,
                'method': 'rule_based',
                'matches': rule_result['matches']
            }

        if rule_result['score'] == 0:
            return {
                'decision': 'exclude',
                'confidence': 90,
                'method': 'rule_based',
                'matches': rule_result['matches']
            }

        # Strategy 2: If rules uncertain, use AI
        if ai_result:
            # Combine rule score and AI confidence
            combined_confidence = (rule_result['score'] * 0.4 +
                                  ai_result['confidence'] * 0.6)

            # Rules override AI if conflict
            if rule_result['score'] > 80 and ai_result['confidence'] < 60:
                decision = 'include' if rule_result['score'] > 80 else 'uncertain'
                method = 'rule_override'
            else:
                decision = ai_result['decision']
                method = 'hybrid'

            return {
                'decision': decision,
                'confidence': combined_confidence,
                'method': method,
                'rule_matches': rule_result['matches'],
                'ai_reasoning': ai_result['reasoning']
            }

        return {
            'decision': 'uncertain',
            'confidence': rule_result['score'],
            'method': 'rule_based',
            'matches': rule_result['matches']
        }

    def validate_decision(self, decision, citation):
        """Rule-based validation of final decision"""

        # Validation rule 1: Can't include if study design doesn't match
        if (decision['decision'] == 'include' and
            'study_design' in decision['rule_matches'] and
            not decision['rule_matches']['study_design']):

            decision['decision'] = 'exclude'
            decision['validation_override'] = True
            decision['reason'] = "Study design does not match inclusion criteria"

        # Validation rule 2: Flag low confidence for human review
        if decision['confidence'] < 70:
            decision['needs_review'] = True
            decision['review_reason'] = "Low confidence - human review required"

        # Validation rule 3: Check for exclusion keywords
        exclusion_keywords = ['animal', 'rat', 'mouse', 'in vitro', 'review article']
        text_lower = (citation['title'] + ' ' + citation['abstract']).lower()

        for keyword in exclusion_keywords:
            if keyword in text_lower:
                decision['decision'] = 'exclude'
                decision['validation_override'] = True
                decision['reason'] = f"Exclusion keyword found: {keyword}"
                break

        return decision
```

**Implementation Timeline:** Weeks 17-19 (enhancement of existing)

**Expected Performance:**
- **Sensitivity:** 97% (up from 95% with rules validation)
- **Specificity:** 75% (up from 65% with rule-based filtering)
- **False negatives:** <3% (critical - we don't miss relevant studies)
- **Explainability:** 100% (every decision has structured reasoning)

---

## HALLUCINATION PREVENTION STRATEGIES

### Strategy 1: Constrained Outputs

**Problem:** AI makes up data
**Solution:** Force structured outputs with validation

```python
# Bad: Free text
ai_response = ai.generate("Extract sample size from: '500 patients enrolled'")
# AI might say: "The sample size was 750 patients" ← HALLUCINATION

# Good: Constrained with validation
prompt = """
Extract ONLY the sample size number from this text: '500 patients enrolled'
Return as JSON: {"sample_size": <number>}
If not found, return: {"sample_size": null}
"""

response = ai.generate(prompt)
extracted = json.loads(response)

# Validation rule
if extracted['sample_size'] is not None:
    if not (10 <= extracted['sample_size'] <= 1000000):
        # Rule: Sample size must be reasonable
        extracted['sample_size'] = None
        extracted['validation_error'] = "Sample size out of reasonable range"
```

### Strategy 2: Multi-Step Verification

**Problem:** AI jumps to conclusions
**Solution:** Break down into verifiable steps

```python
# Bad: Single-step extraction
"Extract all data from this study" → AI makes mistakes

# Good: Multi-step with verification
def extract_with_verification(study_text):
    # Step 1: Extract (AI)
    extraction = ai.extract_data(study_text)

    # Step 2: Find source quotes (Rules)
    quotes = find_supporting_quotes(study_text, extraction)

    # Step 3: Verify (Rules)
    for field, value in extraction.items():
        if field not in quotes or not quotes[field]:
            # No supporting quote found - AI likely hallucinated
            extraction[field] = None
            extraction[field + '_error'] = "No supporting evidence in text"

    return extraction
```

### Strategy 3: Confidence Calibration

**Problem:** AI overconfident
**Solution:** Calibrate confidence with validation

```python
def calibrated_confidence(ai_confidence, rule_score):
    """
    Adjust AI confidence based on rule-based validation
    """
    # If rules strongly agree with AI, increase confidence
    if rule_score > 80 and ai_confidence > 70:
        calibrated = min(95, ai_confidence + 10)

    # If rules disagree with AI, decrease confidence
    elif rule_score < 30 and ai_confidence > 70:
        calibrated = max(50, ai_confidence - 30)

    # If rules uncertain, trust AI but cap confidence
    else:
        calibrated = min(ai_confidence, 85)

    return calibrated
```

### Strategy 4: Human-in-the-Loop Triggers

**Problem:** Automated errors compound
**Solution:** Automatic human review for high-risk decisions

```python
def needs_human_review(decision):
    """
    Trigger human review for high-risk cases
    """
    triggers = []

    # Trigger 1: Low confidence
    if decision['confidence'] < 70:
        triggers.append("Low confidence")

    # Trigger 2: Rule-AI disagreement
    if decision['method'] == 'rule_override':
        triggers.append("Rule-AI conflict")

    # Trigger 3: High-impact decision
    if decision['decision'] == 'exclude' and decision['rule_matches']['intervention']:
        # Intervention matches but AI says exclude - risky!
        triggers.append("Potential false negative")

    # Trigger 4: Validation warnings
    if 'validation_override' in decision:
        triggers.append("Validation override")

    decision['needs_review'] = len(triggers) > 0
    decision['review_triggers'] = triggers

    return decision
```

---

## IMPLEMENTATION SCHEDULE

### Month 1 (Weeks 1-4): Foundation
- Week 1: Enhanced citation screening with rules
- Week 2: Data extraction validation layer
- Week 3: MAIC/STC core algorithm
- Week 4: MAIC/STC UI and testing

### Month 2 (Weeks 5-8): Critical HTA
- Week 5: Target Trial Emulation protocol builder
- Week 6: Target Trial Emulation causal inference
- Week 7: Multi-State Models core
- Week 8: Multi-State Models UI

### Month 3 (Weeks 9-12): HTA Dossier
- Week 9: Dossier templates (NICE, CADTH)
- Week 10: Auto-population from analyses
- Week 11: Compliance checking
- Week 12: Testing and validation

### Month 4 (Weeks 13-16): Automation
- Week 13: Automated living reviews
- Week 14: PRISMA compliance checker
- Week 15: Reference manager integration
- Week 16: Buffer/testing/docs

**CHECKPOINT: Phase 1 Complete**
- Demo to beta customers
- Gather feedback
- Adjust priorities for Phase 2

### Month 5-6: Phase 2 features
### Month 7-9: Phase 3 features
### Month 10-12: Phase 4-5 features

---

## TESTING STRATEGY

### Unit Tests (Per Feature)
```r
# Example: MAIC validation tests
test_that("MAIC validates input data", {
  # Test: Reject negative sample sizes
  ipd <- data.frame(age = 65, n = -10)
  expect_error(validate_maic_data(ipd))

  # Test: Reject missing covariates
  ipd <- data.frame(age = NA, n = 100)
  expect_error(validate_maic_data(ipd))

  # Test: Accept valid data
  ipd <- data.frame(age = 65, sex = 0.5, n = 250)
  expect_silent(validate_maic_data(ipd))
})
```

### Integration Tests (Cross-Feature)
```r
test_that("AI screening integrates with data extraction", {
  # Screen citation
  screening_result <- screen_citation(citation, criteria)

  # If included, extract data
  if (screening_result$decision == "include") {
    extraction_result <- extract_data(citation)

    # Validate extraction matches screening
    expect_true(extraction_result$study_design %in% criteria$study_designs)
  }
})
```

### Validation Studies (Against Gold Standard)
```python
def run_validation_study(citations_with_truth, screener):
    """
    Validate AI screening against human decisions
    """
    results = []

    for citation in citations_with_truth:
        # AI decision
        ai_decision = screener.screen(citation)

        # Human decision (ground truth)
        human_decision = citation['human_decision']

        # Compare
        results.append({
            'citation_id': citation['id'],
            'ai_decision': ai_decision['decision'],
            'human_decision': human_decision,
            'match': ai_decision['decision'] == human_decision,
            'confidence': ai_decision['confidence']
        })

    # Calculate metrics
    sensitivity = calculate_sensitivity(results)
    specificity = calculate_specificity(results)

    # CRITICAL: Sensitivity must be >= 95%
    assert sensitivity >= 0.95, f"Sensitivity too low: {sensitivity}"

    return {
        'sensitivity': sensitivity,
        'specificity': specificity,
        'accuracy': calculate_accuracy(results)
    }
```

---

## SUCCESS METRICS

### Feature Completion Metrics:
- [ ] All 21 features implemented
- [ ] 95%+ test coverage
- [ ] Validation studies completed
- [ ] Documentation complete
- [ ] Beta tested by 5+ customers

### Performance Metrics:
- [ ] AI screening: 97%+ sensitivity
- [ ] Data extraction: 85%+ accuracy
- [ ] MAIC: Reproduces published examples within 1%
- [ ] Dossier generation: 80%+ completeness
- [ ] Speed: 70%+ time savings vs manual

### Business Metrics:
- [ ] 10+ paying customers using new features
- [ ] £500k+ ARR from HTA Pro tier
- [ ] <5% churn rate
- [ ] NPS > 50

---

## NEXT STEPS

### This Week:
1. Review and approve this plan
2. Prioritize features (confirm Phase 1 list)
3. Set up development environment
4. Create feature branch structure

### Next 2 Weeks:
5. Implement enhanced citation screening
6. Add rule-based validation layer
7. Test on 1,000 citations with known outcomes
8. Measure sensitivity/specificity

### Month 1:
9. Complete MAIC/STC implementation
10. Begin Target Trial Emulation
11. Set up beta customer program
12. Weekly demos and feedback

---

**Ready to Start Implementation?**

Next step: Begin with Feature 5 (Enhanced AI Citation Screening) since we already have the Ollama foundation. This will establish the hybrid pattern for all other features.

Shall I proceed with implementation?
