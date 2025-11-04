# IMPLEMENTATION PRIORITIES Q1-Q2 2026
## Immediate Action Plan for HTA Market Dominance

**Date:** November 4, 2025
**Timeline:** Next 6 months (Q1-Q2 2026)
**Goal:** Launch "HTA Pro" tier with killer features that justify £50,000-100,000/year pricing

---

## EXECUTIVE SUMMARY

Based on research of 2024-2025 HTA trends, I recommend focusing on **4 critical features** in Q1-Q2 2026 that will:
1. **Capture pharma HTA market** (£500k-1M revenue potential)
2. **Create competitive moat** (12-18 month lead on competitors)
3. **Meet regulatory requirements** (NICE, CADTH mandates)

**Total Investment:** £120,000-150,000 (2 developers × 6 months)
**Expected ROI:** 5-10x within 12 months

---

## Q1 2026: CRITICAL PATH (Weeks 1-13)

### Priority 1: MAIC/STC (Population-Adjusted Indirect Comparisons) ⭐⭐⭐⭐⭐

**Why This First:**
- **Table stakes** for pharma HTA submissions (27% of French HTA, 24% of NICE use MAIC)
- **High willingness to pay:** Pharma pays £20,000-50,000 per submission
- **Competitive gap:** Only DistillerSR has this, Covidence doesn't
- **Quick win:** 4-5 weeks implementation

**Implementation Timeline:**
- **Weeks 1-2:** Core MAIC algorithm (propensity scores, effective sample size)
- **Weeks 3-4:** STC implementation (regression-based approach)
- **Week 5:** Diagnostics (balance plots, ESS warnings, sensitivity)
- **Week 6:** UI (data upload, matching variables, results display)
- **Week 7:** Testing against published examples (validate accuracy)

**Deliverables:**
```r
# File: frontend/modules/maic_stc.R
maic_stc_ui()      # User interface
maic_analysis()    # MAIC calculation
stc_analysis()     # STC calculation
plot_balance()     # Before/after balance
calculate_ess()    # Effective sample size
```

**Success Criteria:**
- ✅ Reproduce results from NICE DSU TSD 18 examples
- ✅ ESS calculation matches published papers
- ✅ Balance diagnostics pass validation
- ✅ Beta test with 2 pharma partners

**Revenue Impact:**
- **Target:** 5-10 pharma customers in Year 1
- **Pricing:** £20,000/submission OR £75,000/year unlimited
- **Revenue:** £375,000-750,000

---

### Priority 2: AI-Powered Citation Screening ⭐⭐⭐⭐⭐

**Why This Second:**
- **Massive time savings:** 70% reduction (6 weeks → 2 weeks)
- **Universal need:** EVERY systematic review needs screening
- **Competitive moat:** Only EPPI-Reviewer has ML screening
- **Marketing gold:** "AI-powered" = cutting edge

**Implementation Timeline:**
- **Weeks 8-9:** Backend ML pipeline (PubMedBERT fine-tuning, active learning)
- **Weeks 10-11:** UI (upload citations, label training set, review predictions)
- **Week 12:** Integration (connect to screening workflow)
- **Week 13:** Validation study (compare to human screening on 5 reviews)

**Technical Stack:**
```python
# backend/ai/screening_classifier.py
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import torch

# Use PubMedBERT (420M parameters, trained on PubMed)
model_name = "microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext"

class ActiveLearningScreener:
    def __init__(self):
        self.model = AutoModelForSequenceClassification.from_pretrained(...)
        self.tokenizer = AutoTokenizer.from_pretrained(...)

    def train_on_labeled(self, labeled_citations):
        # Fine-tune on user's labels (100-200 examples)
        pass

    def predict_with_uncertainty(self, unlabeled_citations):
        # Predict + uncertainty scores
        # Prioritize uncertain ones for human review
        pass

    def active_learning_loop(self):
        # 1. User labels 50 citations (25 include, 25 exclude)
        # 2. Train model
        # 3. Predict on remaining 10,000 citations
        # 4. Present 50 most uncertain for labeling
        # 5. Repeat until confident
        pass
```

**UI Workflow:**
1. Upload citations (RIS, BibTeX, or API from PubMed)
2. Label training set (50-100 citations)
3. Model trains (5-10 min)
4. Review predictions with confidence scores
5. Validate on random sample (calculate sensitivity/specificity)
6. Export included/excluded with AI flagging

**Success Criteria:**
- ✅ >95% sensitivity (don't miss relevant studies)
- ✅ 50-70% specificity (reduce workload significantly)
- ✅ Validation on 5 real systematic reviews
- ✅ PRISMA-compliant reporting

**Revenue Impact:**
- **Target:** 50 academic + 10 pharma customers
- **Pricing:** £5,000/year premium for AI features
- **Revenue:** £250,000-300,000

**Regulatory Compliance:**
- Follow NICE AI Position Statement (October 2024)
- Document model training and validation
- Human-in-the-loop required (never fully automated)
- Transparency in AI decision-making

---

## Q2 2026: POWER FEATURES (Weeks 14-26)

### Priority 3: HTA Dossier Generator ⭐⭐⭐⭐⭐

**Why This Third:**
- **Massive time savings:** 80% reduction (6 weeks → 1 week)
- **High value:** Saves £20,000-40,000 in consulting fees
- **Sticky:** Once pharma uses this, they won't switch platforms
- **Recurring revenue:** Each new drug needs new dossier

**Implementation Timeline:**
- **Weeks 14-15:** NICE STA template (150 pages)
- **Weeks 16-17:** CADTH CDR template (200 pages)
- **Weeks 18-19:** Auto-population from analyses (MA, Markov, BIM)
- **Weeks 20-21:** Tables and figures (proper formatting per agency)
- **Weeks 22-23:** Compliance checker (verify all sections complete)
- **Week 24:** Testing with real submissions (2-3 pharma partners)

**Templates to Build:**
1. **NICE STA (Single Technology Appraisal)** - UK
2. **CADTH CDR (Common Drug Review)** - Canada
3. **PBAC Submission** - Australia
4. **IQWiG Dossier** - Germany
5. **HAS Submission** - France

**Auto-Populated Sections:**
```
Section 1: Executive Summary
  → Pull from user input (1-2 pages)

Section 5: Clinical Evidence
  5.1 Systematic Review Methods
    → Pull from search strategy, PICO, inclusion/exclusion
  5.2 Study Selection
    → Pull PRISMA flow diagram
  5.3 Study Characteristics
    → Pull baseline characteristics tables
  5.4 Risk of Bias
    → Pull RoB assessments
  5.5 Meta-Analysis Results
    → Pull forest plots, summary estimates

Section 6: Cost-Effectiveness
  6.1 Model Structure
    → Pull Markov model diagram
  6.2 Parameters
    → Pull parameter tables (costs, utilities, transitions)
  6.3 Results
    → Pull ICER, CEAC, EVPI tables/figures

Section 7: Budget Impact
  → Pull BIM 5-year projection table

Appendices (10-15)
  → Auto-generate all required appendices
```

**Success Criteria:**
- ✅ NICE template 100% compliant (all required sections)
- ✅ Tables/figures properly formatted per agency
- ✅ Cross-references working (e.g., "See Appendix 5.1")
- ✅ 2 pharma companies successfully submit dossiers

**Revenue Impact:**
- **Pricing Model:**
  - Option A: £10,000-15,000 per dossier (one-time)
  - Option B: £50,000/year unlimited dossiers (subscription)
- **Target:** 10-15 pharma companies
- **Revenue:** £500,000-750,000

---

### Priority 4: Target Trial Emulation (TTE) for RWD ⭐⭐⭐⭐⭐

**Why This Fourth:**
- **Regulatory mandate:** Required by NICE (2022), CADTH (2024), EUnetHTA (2024)
- **Zero competition:** NO other platform offers this
- **First-mover advantage:** 12-18 month lead
- **High complexity = high barriers = defensible moat**

**Implementation Timeline:**
- **Weeks 25-26:** Protocol builder (structured template)
- **Weeks 27-28:** Causal diagram editor (DAG visualization)
- **Weeks 29-30:** Propensity score methods (matching, IPTW)
- **Weeks 31-32:** G-formula for time-varying confounding
- **Weeks 33-34:** Sensitivity analyses (E-values, tipping point)
- **Weeks 35-36:** NICE-compliant reporting templates

**Technical Components:**
```r
# File: frontend/modules/target_trial_emulation.R

# 1. Protocol Builder
tte_protocol_ui <- function(id) {
  # Hernán & Robins framework (7 components)
  # 1. Eligibility criteria
  # 2. Treatment strategies
  # 3. Assignment procedures
  # 4. Start of follow-up (time zero)
  # 5. End of follow-up
  # 6. Outcomes
  # 7. Causal contrast (estimand)
}

# 2. Causal Diagram (DAG)
dag_editor <- function() {
  # Visual editor for causal diagrams
  # - Drag-and-drop variables
  # - Draw arrows (causal paths)
  # - Identify confounders, mediators, colliders
  # - Export to DOT format
}

# 3. Propensity Score Analysis
library(WeightIt)

ps_methods <- function(data, treatment, confounders) {
  # Calculate propensity scores
  ps <- glm(treatment ~ confounders, family=binomial)

  # Method 1: Matching
  matched <- matchit(treatment ~ confounders, data=data)

  # Method 2: IPTW (Inverse Probability of Treatment Weighting)
  weights <- weightit(treatment ~ confounders, data=data,
                     estimand="ATE")  # Average Treatment Effect

  # Method 3: Doubly Robust
  # Combine PS weighting + outcome regression
}

# 4. G-formula (Time-Varying Confounding)
gformula_analysis <- function(data) {
  # For longitudinal data with time-varying confounding
  # Estimate counterfactual outcomes under different treatment strategies
}

# 5. Sensitivity Analysis
calculate_evalue <- function(observed_rr) {
  # E-value: How strong would unmeasured confounding need to be?
  evalue <- observed_rr + sqrt(observed_rr * (observed_rr - 1))
}
```

**Success Criteria:**
- ✅ Reproduce TTE example from NICE RWE Framework
- ✅ Validate against published TTE studies (5 examples)
- ✅ Balance diagnostics pass (SMD <0.1 after weighting)
- ✅ 1-2 pharma companies successfully submit RWD to HTA

**Revenue Impact:**
- **Pricing:** £15,000-20,000 per RWD submission
- **Target:** 5-10 pharma RWE teams
- **Revenue:** £75,000-200,000

**Strategic Value:**
- **First mover:** Be the FIRST platform to offer TTE
- **Credibility:** Get NICE endorsement
- **Publications:** Publish methodology paper in Value in Health
- **Training:** Offer TTE certification course (£2,000/person)

---

## DEVELOPMENT RESOURCES

### Team Requirements:

**Team Member 1: Senior R Developer**
- Focus: MAIC/STC, TTE, statistical methods
- Skills: R, Shiny, statistics (propensity scores, causal inference)
- Cost: £60,000-80,000 (6 months)

**Team Member 2: ML Engineer**
- Focus: AI screening, data extraction
- Skills: Python, PyTorch/TensorFlow, transformers, NLP
- Cost: £50,000-70,000 (6 months)

**Team Member 3: Full-Stack Developer (Part-Time)**
- Focus: HTA dossier generator, UI/UX improvements
- Skills: R Shiny, officer package, document generation
- Cost: £30,000-40,000 (3 months full-time equivalent)

**Total Budget:** £140,000-190,000

---

## VALIDATION & TESTING

### Phase 1: Internal Validation (Weeks 1-13)
- Reproduce published examples
- Unit tests for all functions
- Integration tests

### Phase 2: Beta Testing (Weeks 14-26)
- **Recruit 5-10 beta customers:**
  - 2-3 pharma companies
  - 2-3 academic groups
  - 1-2 consulting firms

- **Beta Program Benefits:**
  - Free access for 6 months
  - Co-development input
  - Case study and testimonial

### Phase 3: Publications (Months 7-12)
- **Methodology Papers:**
  1. "AI for Citation Screening: Validation Study"
  2. "Target Trial Emulation Platform for HTA"
  3. Submit to Value in Health, PharmacoEconomics

- **Conference Presentations:**
  1. ISPOR Europe 2026
  2. Cochrane Colloquium 2026
  3. NICE Scientific Advice meetings

---

## MARKETING & GTM STRATEGY

### Positioning:
**"The Only HTA Platform with AI + Advanced Causal Inference"**

### Target Segments:

**1. Pharmaceutical Companies (Primary)**
- **Size:** 500+ companies globally doing HTA submissions
- **Personas:**
  - HTA Directors
  - HEOR (Health Economics & Outcomes Research) Managers
  - Medical Affairs Directors
- **Pain Points:**
  - No direct head-to-head trials → need MAIC/STC
  - RWD requirements → need TTE
  - Tight submission deadlines → need automation
- **Value Prop:** "Submit to NICE, CADTH, PBAC in 1/4 the time at 1/2 the cost"

**2. HTA Consulting Firms (Secondary)**
- **Size:** 100+ firms (Evidera, ICON, IQVIA, Analysis Group, etc.)
- **Pain Points:** Need to scale (more clients, same team)
- **Value Prop:** "Handle 2x more clients with same headcount"

**3. Academic Health Economics (Tertiary)**
- **Size:** 500+ universities worldwide
- **Pain Points:** Limited resources, junior researchers
- **Value Prop:** "PhD students can run complex analyses independently"

### Pricing Strategy:

**Tier 1: Academic ($0-2,000/year)**
- Core features only
- No AI, no MAIC/STC, no TTE
- Freemium to build user base

**Tier 2: Professional (£15,000-25,000/year)**
- All features except AI screening
- Unlimited users within organization
- Target: Academic + small consulting

**Tier 3: HTA Pro (£50,000-100,000/year)**
- All features including AI and MAIC/STC/TTE
- Priority support
- HTA dossier generator
- Training and certification
- Target: Pharma and large consulting

**Tier 4: Enterprise (£150,000-300,000/year)**
- Multi-tenant
- White label option
- Dedicated account manager
- Custom integrations
- Target: Large pharma, CROs

### Launch Plan:

**Month 1-3 (Q1 2026):**
- Build MAIC/STC + AI screening
- Recruit beta customers (5-10)
- Soft launch to beta

**Month 4-6 (Q2 2026):**
- Build HTA dossier + TTE
- Beta feedback and iteration
- Validation studies

**Month 7 (July 2026):**
- **Public Launch at ISPOR Europe 2026**
- Press release
- Product demos
- Booth with live demos

**Month 8-12:**
- Sales ramp-up
- Case studies from beta customers
- Publications

---

## SUCCESS METRICS

### Technical Metrics:
- ✅ MAIC/STC: Reproduce 5/5 published examples within 1% accuracy
- ✅ AI Screening: >95% sensitivity, >50% specificity on validation set
- ✅ TTE: Pass NICE RWE Framework requirements
- ✅ Dossier Generator: 2+ successful HTA submissions

### Business Metrics (12 months):
- **Customers:** 15-25 paying customers
- **Revenue:** £500,000-1,000,000 ARR
- **Churn:** <10%
- **NPS:** >50

### Market Metrics:
- **Brand Awareness:** Top 3 platform mentioned in ISPOR surveys
- **Publications:** 2+ peer-reviewed papers
- **Partnerships:** NICE, CADTH, or ISPOR endorsement

---

## RISK MITIGATION

### Risk 1: AI Accuracy Not Sufficient
**Mitigation:**
- Set threshold at 95% sensitivity (miss <5% of studies)
- Always keep human-in-the-loop
- Offer "AI-assisted" not "fully automated"

### Risk 2: MAIC/STC Too Complex
**Mitigation:**
- Extensive documentation and tutorials
- Offer training workshops (£2,000/person)
- Provide consultation service (£5,000/project)

### Risk 3: HTA Agencies Don't Accept TTE
**Mitigation:**
- Follow NICE/CADTH guidelines exactly
- Get pre-approval from NICE Scientific Advice
- Publish validation study

### Risk 4: Competitors Copy Features
**Mitigation:**
- Move fast (12-18 month lead)
- File patents on AI methods
- Build network effects (data improves AI)
- Long-term contracts (3-year)

---

## DECISION POINT: GO/NO-GO

### Go Decision Criteria:
- ✅ Research validates market need (DONE - see HTA_KILLER_FEATURES_2025.md)
- ✅ Technical feasibility confirmed (DONE - all methods have R packages)
- ✅ Budget approved (£140-190k for 6 months)
- ✅ Team hired (2-3 developers)
- ✅ 2+ beta customers committed

### No-Go Criteria:
- ❌ Cannot hire ML engineer with NLP experience
- ❌ Beta customers say "not interested"
- ❌ NICE rejects AI approach
- ❌ Competitors announce same features

---

## NEXT STEPS (Week 1)

### Immediate Actions:

1. **Customer Validation (Week 1)**
   - Interview 10 pharma HTA directors
   - Questions:
     - "How much do you currently pay for MAIC/STC analyses?"
     - "Would you pay £50-100k/year for an integrated platform?"
     - "What's your biggest pain point in HTA submissions?"

2. **Hire Team (Weeks 1-2)**
   - Post job ads:
     - Senior R Developer (Shiny, statistics)
     - ML Engineer (NLP, transformers)
   - Screen candidates
   - Make offers

3. **Set Up Development (Week 2)**
   - GitHub project board
   - Sprint planning (2-week sprints)
   - CI/CD pipeline
   - Staging environment

4. **Beta Recruitment (Weeks 2-4)**
   - Reach out to network
   - Target: 2 pharma, 2 academic, 1 consulting
   - Sign beta agreements (free access for feedback)

5. **Start Development (Week 3)**
   - Sprint 1: MAIC core algorithm
   - Daily standups
   - Weekly demos to beta customers

---

## CONCLUSION

This 6-month plan will transform EvidenceOS PRIME from a **good systematic review platform** (£160k value) into the **#1 HTA submission platform globally** (£5-10M value).

**The key insight:** HTA market will pay **10-50x more** than academic market because:
1. Higher stakes (£100M+ drug revenues)
2. Regulatory requirements (must submit to NICE/CADTH)
3. Time pressure (submission deadlines)
4. Expertise shortage (need tools to enable junior staff)

**Success Formula:**
```
Existing Platform (£160k value)
+ MAIC/STC (pharma table stakes)
+ AI Screening (70% time savings)
+ HTA Dossier Generator (80% time savings)
+ Target Trial Emulation (regulatory requirement)
= £5-10M platform value
```

**Recommended Decision: GO** ✅

---

**Document Prepared By:** Strategic Product Analysis
**Date:** November 4, 2025
**Status:** READY FOR LEADERSHIP REVIEW
**Required Approval:** CEO, CTO, Head of Product
**Timeline:** Decision needed by December 1, 2025 to hit Q1 2026 start
