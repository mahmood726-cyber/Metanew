# Version 3 — "Enterprise & Insight"

**Timeline:** 6–8 months after v2 (9–12 months after v1)
**Goal:** Consultancy-grade at scale, advanced decision analytics
**Stack:** R + Python only, still containerized, add Bayesian & VOI

---

## 🎯 Goals

1. Make platform **enterprise-ready**: multi-team use, faster turnaround
2. Add **Bayesian & Value of Information** depth where it multiplies value
3. Enable **research-grade** outputs (publications, regulatory submissions)
4. Maintain **R + Python only** stack, single container deployment
5. Add **decision strength analytics** (CEAF, EVPPI, rank probabilities)

---

## 🚀 Headline Features

### 1. Network Meta-Analysis v3 (Bayesian) ⭐

**Current State:** Frequentist NMA only (netmeta)
**Enhancement:** Optional Bayesian backend

#### Features
- **PyMC or brms backend** for Bayesian NMA
- **Priors catalog**:
  - Informative priors (from literature)
  - Weakly informative (default)
  - Non-informative (sensitivity)
- **Convergence diagnostics**:
  - R-hat statistic (< 1.05 required)
  - Effective sample size (ESS)
  - Trace plots
  - Autocorrelation plots
- **Posterior summaries**:
  - Mean, median, SD, 95% CrI
  - Probability of superiority
  - Treatment rankings with uncertainty
  - **SUCRA** (Surface Under Cumulative Ranking curve)
- **League table** with posterior probabilities
- **Rank-o-gram** (rankogram) plots

#### Files to Create
```
backend/models/nma_bayes.py (500 lines)
  - BayesianNMA class
  - fit_pymc_nma()
  - extract_posteriors()
  - diagnostics_summary()
  - rank_probabilities()

frontend/modules/nma_bayes.R (400 lines)
  - nma_bayes_ui()
  - prior_selector()
  - diagnostics_viewer()
  - rankogram_plot()

config/priors/nma_priors.yaml (200 lines)
  - vague, weakly_informative, informative
  - per-parameter distributions
```

#### Acceptance Criteria
- [ ] Bayesian NMA reproduces Dias 2013 example within CrI
- [ ] R-hat < 1.05 for all parameters
- [ ] Rank probabilities sum to 1.0 per treatment
- [ ] SUCRA values match published reference
- [ ] Runs complete in < 5 minutes for 8-treatment network

---

### 2. HTA/Health Economics v3 (Decision Analytics) 💎

#### a) Cost-Effectiveness Acceptability Frontier (CEAF)
- **CEAF curve**: frontier of optimal treatments by WTP
- **Dominance analysis**: identify dominated treatments
- **Incremental analysis**: ICER ladder
- **Probabilistic dominance**: probability of dominance at each WTP

#### b) Expected Value of Information (VOI)
- **EVPI** (Expected Value of Perfect Information):
  - Per patient
  - Population level
  - Over decision horizon
- **EVPPI** (Expected Value of Perfect Partial Information):
  - By parameter groups (costs, utilities, efficacy)
  - Fast metamodel approximations (GAM-based)
  - Prioritize which parameters to research further
- **VOI plots**:
  - EVPI curve by WTP
  - EVPPI tornado chart
  - EVSI (if trial data added)

#### c) Budget Impact v3 (Advanced Scenarios)
- **Multi-payer budgets**:
  - NHS + Private insurance mix
  - Regional budget allocation
- **Tender scenarios**:
  - Price caps
  - Volume discounts
  - Outcome-based rebates
- **Price erosion models**:
  - Patent expiry dynamics
  - Generic competition curves
- **Launch/uptake curves**:
  - Bass diffusion model
  - S-curve with saturation
  - Regional variation

#### d) Probabilistic Sensitivity Analysis v3
- **Parameter correlation**:
  - Cholesky decomposition
  - Copulas for correlated parameters
- **Scenario-based PSA**:
  - Best case / Worst case / Most likely
  - Optimistic / Pessimistic bounds
- **Individual patient simulation** (optional):
  - Discrete event simulation
  - Heterogeneous patient cohorts

#### Files to Create
```
frontend/modules/voi.R (400 lines)
  - calculate_evpi()
  - calculate_evppi()
  - plot_ceaf()
  - plot_evpi_curve()
  - evppi_tornado()

frontend/modules/he_budget_impact_v3.R (350 lines)
  - multi_payer_model()
  - tender_scenarios()
  - price_erosion_dynamics()
  - diffusion_model()

backend/models/voi_metamodel.py (300 lines)
  - GAMMetamodel class
  - fit_gam()
  - fast_evppi_approximation()

frontend/utils/psa_advanced.R (250 lines)
  - cholesky_correlation()
  - copula_sampling()
  - scenario_psa()
```

#### Acceptance Criteria
- [ ] CEAF identifies correct frontier for 4-treatment comparison
- [ ] EVPI calculation matches BCEA package reference
- [ ] EVPPI approximation within 5% of full calculation
- [ ] Multi-payer budget handles 3 payer types correctly
- [ ] Tender scenario with volume discount calculates correctly

---

### 3. Living Evidence v3 (Automation) 🔄

**Current State:** Manual CSV upload for updates
**Enhancement:** Semi-automated search and alerts

#### Features
- **Search integration** (opt-in):
  - PubMed/Embase API search
  - Auto-detect new studies matching PICO
  - Store search results in queue
- **Alert thresholds**:
  - Pooled effect change > X% → email alert
  - SUCRA rank change → alert
  - New high-quality study (ROB low) → alert
- **Scheduled updates**:
  - Cron job: search monthly
  - Email summary of new studies found
  - "Review & update" workflow in UI
- **Delta watch dashboard**:
  - Historical trend of pooled effects
  - Cumulative evidence plot
  - Alert history log

#### Files to Create
```
backend/search/pubmed_client.py (300 lines)
  - PubMedSearch class
  - search_pico()
  - parse_abstracts()
  - deduplicate()

backend/search/embase_client.py (300 lines)
  - EmbaseSearch class (if API access)

backend/scheduler/living_scheduler.py (200 lines)
  - monthly_search_job()
  - send_alert_email()

frontend/modules/living_dashboard.R (350 lines)
  - cumulative_evidence_plot()
  - alert_history()
  - review_new_studies_ui()
```

#### Acceptance Criteria
- [ ] PubMed search with PICO returns correct results
- [ ] New study triggers alert if pooled effect changes > 15%
- [ ] Email alert sent successfully (SMTP configured)
- [ ] Delta dashboard shows last 6 months of updates

---

### 4. Method Guardrails & Quality Assurance 🛡️

#### Auto-Checks (Enhanced Validation)
- **Impossible SEs**: SEI < 0.0001 or SEI > 10
- **Duplicated study IDs**: Same study-treatment multiple times
- **Data clashes**: Reported yi ≠ calculated from raw data (events/n)
- **Inconsistent outcomes**: Same study reports different outcome names
- **Extreme values**: HR > 100, OR > 1000
- **Zero cells**: Warning if continuity correction needed
- **Sample size anomalies**: n < 5 or n > 100,000

#### Model Diagnostics Guard
- **Block publishing** if:
  - Bayesian NMA: R-hat > 1.05
  - Heterogeneity: I² > 95% (flag for review)
  - Egger's test: p < 0.01 (strong publication bias)
  - Network inconsistency: p < 0.05 (NMA)
- **Portal shows**:
  - Red banner: "Diagnostics failed - review before publishing"
  - Explanation: "R-hat = 1.12 (requires < 1.05)"
  - Suggest: "Try different priors or longer chains"

#### Files to Create
```
backend/etl/quality_checks.py (400 lines)
  - check_data_consistency()
  - check_impossible_values()
  - check_zero_cells()

frontend/modules/diagnostics_guard.R (250 lines)
  - diagnostic_status()
  - block_publish_if_failed()
  - diagnostic_suggestions()
```

#### Acceptance Criteria
- [ ] Portal blocks publish if R-hat > 1.05
- [ ] Data check flags SEI = 0.00001 as suspicious
- [ ] Zero cell warning appears for binary data
- [ ] Suggestion shown: "Try weakly informative priors"

---

### 5. Enterprise Quality of Life 🏢

#### User & Project Spaces
- **Namespaces inside container**:
  - `/workspace/user1/`, `/workspace/user2/`
  - Each user sees only their projects
- **Project organization**:
  - Create, archive, share projects
  - Tag projects: "client_XYZ", "oncology", "draft"

#### Run Management
- **Run tagging**: Tag runs with custom labels
- **Search runs**: By outcome, date, tags, client
- **Pin favorites**: Pin important runs to dashboard
- **Export bundle**: Export run + data + code as ZIP
- **Compare runs**: Select 2 runs → show diffs

#### Slide Builder for Sponsors
- **Pick charts workflow**:
  - Select 3-5 charts from results
  - Choose template (corporate, academic, payer)
  - Auto-compose PPT section
  - Add branded master slide
  - Export ready-to-present deck
- **Chart library**:
  - Forest plot, funnel plot, CEAC, NMA league table
  - Each chart has: title, caption, interpretation
- **Templates**:
  - NHS template (Arial, blue/white)
  - NICE template (official branding)
  - Generic corporate

#### Files to Create
```
backend/workspace/user_spaces.py (200 lines)
  - create_user_workspace()
  - list_user_projects()

frontend/modules/run_manager.R (300 lines)
  - search_runs_ui()
  - tag_run()
  - pin_run()
  - export_bundle()

frontend/modules/slide_builder.R (400 lines)
  - select_charts_ui()
  - choose_template()
  - compose_pptx()
  - add_branding()

templates/pptx/nhs_template.pptx
templates/pptx/nice_template.pptx
templates/pptx/corporate_template.pptx
```

#### Acceptance Criteria
- [ ] User1 cannot see User2's projects
- [ ] Search finds runs by tag "oncology"
- [ ] Pinned runs appear on dashboard
- [ ] Slide builder exports 10-slide deck in < 30s
- [ ] NHS template has correct branding/fonts

---

### 6. Country Packs v3 (Global Expansion) 🌍

**Current State:** 8 countries (UK, US, Germany, France, Canada, Italy, Spain, Australia)
**Enhancement:** Add 4-6 more + advanced features

#### New Countries
- **Netherlands** (ZIN methodology)
- **Sweden** (TLV)
- **Belgium** (KCE)
- **Switzerland** (BAG)
- **Japan** (MHLW)
- **South Korea** (HIRA)

#### Advanced Features
- **Currency conversion**:
  - Date-locked exchange rates
  - PPP adjustments
  - Inflation indexing
- **Local cost catalogs**:
  - Hospital costs by procedure
  - Drug costs by ATC code
  - Outpatient visit costs
- **Utility norms**:
  - Age/sex-specific norms
  - Condition-specific decrements
  - EQ-5D-3L vs 5L tariffs
- **Discount conventions**:
  - Costs vs benefits (may differ)
  - Time-varying discounts
  - Sensitivity ranges

#### Files to Create
```
config/countries/netherlands.yaml
config/countries/sweden.yaml
config/countries/belgium.yaml
config/countries/switzerland.yaml
config/countries/japan.yaml
config/countries/south_korea.yaml

frontend/utils/currency_converter.R (150 lines)
  - convert_currency()
  - get_exchange_rate()
  - ppp_adjustment()

config/cost_catalogs/uk_nhs_costs.yaml (500 lines)
config/cost_catalogs/us_medicare_costs.yaml (500 lines)
```

#### Acceptance Criteria
- [ ] Netherlands config loads ZIN WTP (€20k)
- [ ] Currency conversion: £100k → $130k (date 2024-01-01)
- [ ] UK NHS cost catalog has 50+ procedures
- [ ] EQ-5D-3L UK tariff loads correctly

---

## 🏗️ Architecture/Tech Upgrades

### Job Queue for Long Fits
```python
# backend/queue/job_queue.py
from rq import Queue
from redis import Redis

redis_conn = Redis()
queue = Queue(connection=redis_conn)

# Submit job
job = queue.enqueue(fit_bayesian_nma, args=(data,))

# R side: poll for completion
result <- poll_job_status(job_id)
```

**Use Cases:**
- Bayesian NMA (long MCMC chains)
- PSA with 10,000 iterations
- EVPPI calculation (GAM fitting)

### Posterior Cache Store
```
cache/posteriors/
  - {evidence_id}_{model_type}.feather (or parquet)
  - index.db (SQLite with: id, model, n_samples, created_at)
```

**Benefits:**
- Don't re-fit Bayesian model if hash unchanged
- Fast retrieval of posteriors for VOI
- Disk-efficient (Feather/Parquet compression)

### Templating System for Text Snippets
```r
# templates/text_snippets.yaml
interpretation:
  high_heterogeneity: |
    Substantial heterogeneity was observed (I² = {i_squared}%),
    suggesting caution in interpretation of pooled effects.

  significant_effect: |
    The pooled effect was statistically significant (p = {p_value}),
    with an estimated effect size of {effect_size} (95% CI:
    {ci_lower} to {ci_upper}).
```

**Use in Rmd:**
```r
snippet <- render_snippet("interpretation.significant_effect",
                          effect_size = 0.52, p_value = 0.003, ...)
```

---

## 📦 Deliverables

### New UI Panes
- **Diagnostics** (Bayesian convergence, model checks)
- **VOI** (EVPI, EVPPI, CEAF)
- **Delta Watch** (living evidence dashboard)
- **Slide Builder** (chart picker → PPT)
- **Run Manager** (search, tag, compare)

### Schema Extensions
```python
# Posterior summaries
class PosteriorSummary(BaseModel):
    parameter: str
    mean: float
    median: float
    sd: float
    ci_lower: float
    ci_upper: float
    rhat: Optional[float]
    ess: Optional[int]

# Extend EvidenceObject
class EvidenceObject(BaseModel):
    ...
    posteriors: Optional[Dict[str, PosteriorSummary]] = None
    diagnostics: Optional[DiagnosticsSummary] = None
    voi_results: Optional[VOIResults] = None
```

### Extended Methods Appendix
- Bayesian priors justification
- Convergence diagnostics
- VOI methodology
- Living evidence protocol

---

## ✅ Success Criteria (Acceptance)

### Bayesian NMA
- [ ] Reproduces Dias 2013 smoking cessation example
- [ ] Credible intervals within ±5% of published
- [ ] R-hat < 1.05 for all parameters
- [ ] Completes 4-chain × 10k iterations in < 10 min

### VOI Analysis
- [ ] CEAF correctly identifies frontier for NICE TA example
- [ ] EVPI calculation matches BCEA package (< 1% error)
- [ ] EVPPI approximation within 5% of full calculation
- [ ] EVPPI tornado shows correct parameter priorities
- [ ] Completes VOI analysis in < 90 seconds

### Delta Watch
- [ ] Triggers alert when pooled effect changes > 15%
- [ ] Email sent successfully (test with Mailtrap)
- [ ] Dashboard shows last 12 months of updates
- [ ] Cumulative evidence plot renders correctly

### Slide Builder
- [ ] Exports 10-slide deck in < 30 seconds
- [ ] NHS template has correct fonts/colors
- [ ] Charts are high-res PNG (300 dpi)
- [ ] No manual edits needed for client delivery

---

## ⚠️ Risks & Guardrails

### Bayesian Complexity
- ✋ Default to **frequentist** - Bayes is explicit toggle
- ✋ **Sample caps**: Max 20k iterations per chain
- ✋ **Timeouts**: Abort if MCMC takes > 15 minutes
- ✋ **Warning**: "Bayesian NMA is computationally intensive"

### VOI Computation Time
- ✋ Use **importance sampling** for EVPPI (not full nested MC)
- ✋ GAM **metamodel approximations** when possible
- ✋ **Progress bar**: Show "VOI calculation 40% complete"
- ✋ **Cache**: Store VOI results by EvidenceObject hash

### Enterprise UX Bloat
- ✋ Keep UI **modular** - hide advanced panels unless toggled
- ✋ "Simple mode" vs "Expert mode" toggle
- ✋ Default = Simple (80% of users)
- ✋ Expert unlocks: Bayesian, VOI, advanced diagnostics

### External API Dependencies
- ✋ PubMed/Embase search is **opt-in** (requires API key)
- ✋ Graceful degradation if API unavailable
- ✋ **Rate limiting**: Max 3 searches/hour
- ✋ Cache search results for 7 days

---

## 💰 Pricing Guidance

### v3 Upgrade Fee (from v2)
- **Existing clients:** £12,000–£18,000 one-time
- **Or:** +£5,000–£8,000/year on annual licence

### New Enterprise Deployments (v3 Stack)
- **One-off:** £30,000–£45,000 (includes setup + training)
- **Annual licence:** £15,000–£25,000/year + £5k onboarding

### Premium Tier (Research/Regulatory)
- **£30,000–£50,000/year**
- Includes: v3 features + Bayesian + VOI + priority support
- Target: Academic groups, CROs, large consultancies

### Per-Project Pricing (Alternative)
- **£3,000–£8,000 per HTA project**
- Unlimited runs, 1-year access
- Target: Pharma companies (occasional use)

---

## 🛠️ Development Estimates

| Feature | Effort (hours) | Priority |
|---------|---------------|----------|
| Bayesian NMA (PyMC) | 60 | HIGH |
| VOI (EVPI + EVPPI) | 50 | HIGH |
| CEAF + frontier | 25 | HIGH |
| Budget Impact v3 | 30 | MEDIUM |
| Living Evidence v3 | 40 | MEDIUM |
| Quality Guardrails | 30 | HIGH |
| User Spaces | 20 | MEDIUM |
| Run Manager | 25 | MEDIUM |
| Slide Builder | 35 | HIGH |
| Country Packs (6 new) | 30 | LOW |
| Job Queue | 20 | HIGH (Bayes deps) |
| Posterior Cache | 15 | MEDIUM |
| Text Templating | 10 | LOW |

**Total:** ~390 hours (~10 weeks full-time or 6-8 months part-time)

---

## 📝 Claude-Ready Prompts

### Bayesian NMA
```
Create `backend/models/nma_bayes.py` using PyMC for random-effects NMA
with treatment effects on log scale; return posterior means, SDs,
95% CrIs, rank probabilities, SUCRA, and diagnostics summary (R-hat, ESS).
Include prior selection: vague, weakly_informative, informative.
```

### VOI Analysis
```
Implement `frontend/modules/voi.R` wrapping `BCEA` to compute CEAF,
EVPI, EVPPI (parameter groups), with plots and a tidy summary list for
Rmd. Use GAM metamodel for fast EVPPI approximation (importance sampling).
Return: ceaf_curve, evpi_by_wtp, evppi_tornado, frontier_treatments.
```

### Delta Watch
```
Add `frontend/modules/delta_watch.R` that takes two EvidenceObjects and
flags changes exceeding thresholds for pooled effects, SUCRA ranks, and
ICERs. Show: old→new with Δ%, highlight if > threshold. Email alert via
SMTP if major change detected.
```

### Slide Builder
```
Create `frontend/modules/slide_builder.R` that lets user select 3-5
charts (forest, funnel, CEAC, league table) and compose a branded PPT
using officer::read_pptx() with master template. Add charts to content
slides with titles and captions. Export as .pptx ready for client.
```

---

## 🔄 Migration & Backward Compatibility

### EvidenceObject v3.0
```python
class EvidenceObject(BaseModel):
    # v1 fields
    evidence_id: str
    studies: List[Study]
    pairwise_results: Dict[str, PairwiseResult]

    # v2 fields (optional)
    survival_results: Optional[Dict] = None
    scenarios: Optional[List[Scenario]] = None

    # v3 fields (optional)
    posteriors: Optional[Dict[str, PosteriorSummary]] = None
    diagnostics: Optional[DiagnosticsSummary] = None
    voi_results: Optional[VOIResults] = None

    schema_version: str = "3.0"
```

### Cache Invalidation
```python
cache_key = f"{evidence_id}_{schema_version}_{content_hash}"
```

---

## 📅 Release Plan

### Months 1-2 (Bayesian Core)
- Weeks 1-3: PyMC NMA backend + priors
- Week 4-6: Convergence diagnostics + UI
- Weeks 7-8: Testing + reference validation

### Months 3-4 (VOI & Guardrails)
- Weeks 1-2: EVPI + CEAF
- Weeks 3-4: EVPPI (metamodel)
- Weeks 5-6: Quality guardrails
- Weeks 7-8: Diagnostics blocking

### Months 5-6 (Enterprise Features)
- Weeks 1-2: User spaces + run manager
- Weeks 3-4: Slide builder
- Weeks 5-6: Living evidence v3
- Weeks 7-8: Country packs expansion

### Months 7-8 (Polish & Deploy)
- Weeks 1-2: Integration testing
- Weeks 3-4: Documentation + vignettes
- Weeks 5-6: Performance optimization
- Weeks 7-8: Beta testing + bug fixes

---

## ✨ What v3 Unlocks

After v3, you can:

1. **Publish in top-tier journals** (Bayesian NMA is research-grade)
2. **Win large CRO contracts** (VOI analysis for trial design)
3. **Bid on regulatory submissions** (diagnostics + quality guardrails)
4. **Offer living evidence as service** (recurring £10-20k/year contracts)
5. **White-label for Big 4 consulting** (enterprise features + branding)
6. **Premium pricing** (£30-50k/project vs £20-30k for v2)

**Market Position:** Research-grade HEOR platform, competitive with ICON/Evidera/RTI in-house tools

---

## 🎯 Strategic Positioning

### v1 (PRIME)
- **Position:** Functional meta-analysis + basic HE
- **Buyers:** Small consultancies, academics
- **Price:** £40-50k one-off

### v2 (Operate & Scale)
- **Position:** Full-service HEOR platform
- **Buyers:** Mid-size consultancies, pharma (occasional)
- **Price:** £50-75k one-off or £15-25k/year

### v3 (Enterprise & Insight)
- **Position:** Research-grade decision analytics
- **Buyers:** Large consultancies, CROs, Big Pharma, academic centers
- **Price:** £75-100k one-off or £25-50k/year

**Target Revenue:**
- 5 v2 annual licences = £75-125k/year
- 2 v3 enterprise = £50-100k/year
- **Total: £125-225k/year recurring** (realistic after 18 months)

---

## 📚 Documentation Requirements

### Methods Appendix v3
- Bayesian MCMC methods
- Prior justification
- Convergence diagnostics interpretation
- VOI methodology and assumptions
- Living evidence protocol
- Quality assurance procedures

### User Guide Expansions
- "When to use Bayesian NMA" decision tree
- VOI interpretation guide
- Diagnostics troubleshooting
- Slide builder templates
- Multi-user collaboration guide

### Vignettes (4 new)
1. "Bayesian NMA Walkthrough (Smoking Cessation)"
2. "VOI Analysis for Trial Design"
3. "Living Evidence Service Setup"
4. "Enterprise Multi-User Deployment"

---

## 🏆 Success Metrics (Business)

### Technical
- [ ] Bayesian NMA passes validation on 3 published examples
- [ ] VOI analysis completes in < 90 seconds
- [ ] Quality guardrails catch 95%+ of data errors
- [ ] Slide builder used in 80%+ of projects

### Commercial
- [ ] 2+ enterprise deployments (£25k+/year each)
- [ ] 1+ academic research group using v3 for publications
- [ ] 1+ CRO using for trial design (VOI)
- [ ] Positive ROI on v3 development within 12 months

---

**v3 is the "Premium Tier" - research-grade, enterprise-ready, decision analytics platform.**
