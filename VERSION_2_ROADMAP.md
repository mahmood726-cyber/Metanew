# Version 2 — "Operate & Scale"

**Timeline:** 3–4 months after v1
**Goal:** Turn one-client build into repeatable, configurable product
**Stack:** R + Python only, single Docker image deployment

---

## 🎯 Goals

1. Make the platform **repeatable and configurable** for multiple clients
2. Add **most-requested features** from early users without scope bloat
3. Maintain **single Docker image** deployment (R Shiny + FastAPI)
4. Add depth to health economics and systematic review workflows

---

## 🚀 Headline Features

### 1. Protocol→Pipeline v2 (✨ NEW)

**Current State:** Basic PICO entry only
**Enhancement:**

- **PICO/eligibility UI templates** with common patterns
- **Locked protocol snapshots** - freeze protocol, track deviations
- **Protocol/Execution diff report** embedded in Word/PDF outputs
- **PRISMA counters** (manual input + auto-tally from data uploads)
- **Deviation logging** with justifications and timestamps

**Files to Create:**
```
frontend/modules/protocol_v2.R (300 lines)
frontend/utils/prisma_helpers.R (150 lines)
templates/protocol_diff_appendix.Rmd (100 lines)
```

**Acceptance Criteria:**
- [ ] Protocol can be locked with SHA-256 hash
- [ ] Deviations are logged with timestamps and reasons
- [ ] Diff report shows protocol vs actual execution
- [ ] PRISMA flow diagram auto-generates from data counts

---

### 2. HTA/Health Economics v2 (⭐ MAJOR)

**Current State:** 3-state Markov only
**Enhancements:**

#### a) Partitioned Survival Model
- **PFS/OS/PD** workflow (progression-free, overall, progressed disease)
- **Parametric survival fitting** using `flexsurv` package
- Curve types: Weibull, log-normal, log-logistic, Gompertz, gamma, gen-gamma
- **Arm-based** (fit each arm) **and HR-based** workflows
- **AIC/BIC model selection** with diagnostic plots
- **Area under curve QALY** calculations

#### b) Budget Impact v2
- **Uptake scenarios** with S-curves, linear, or custom
- **Price erosion** over time (patent expiry, competition)
- **Line extensions** (new indications added sequentially)
- **Multi-payer budgets** (NHS, CCGs, private mix)
- **Tornado diagrams** for one-way sensitivity

#### c) Country Packs v2
- Expand from 5 to **8 countries**:
  - Existing: UK, US, Germany, France, Canada
  - **NEW:** Italy, Spain, Australia
- **Detailed cost catalogs** (hospitalization, procedures, drugs)
- **Local utility norms** by age/sex/condition
- **Currency conversion helpers** with date-locked exchange rates
- **Discount conventions** per jurisdiction (costs vs benefits)

**Files to Create:**
```
frontend/modules/survival_ps.R (400 lines)
  - ps_ui(), ps_server()
  - fit_parametric_survival()
  - plot_survival_curves()
  - calculate_area_qalys()

frontend/modules/he_budget_impact_v2.R (300 lines)
  - uptake_scenarios()
  - price_erosion_model()
  - multi_payer_budget()

config/countries/italy.yaml
config/countries/spain.yaml
config/countries/australia.yaml

frontend/utils/survival_helpers.R (200 lines)
  - aic_bic_table()
  - diagnostic_plots()
  - extrapolation_checks()
```

**Acceptance Criteria:**
- [ ] PS model fits 6 parametric curves, selects best by AIC
- [ ] PS plots pass-through actual KM data points
- [ ] Budget impact handles 3 price scenarios over 5 years
- [ ] Italy/Spain/Australia configs load with local costs
- [ ] Currency conversion uses date-locked rates

---

### 3. Interactive Sensitivity & Scenario Explorer v2

**Current State:** Basic sensitivity module exists
**Enhancements:**

- **Scenario presets**:
  - "Low heterogeneity" (I² < 25%)
  - "Medium heterogeneity" (25% < I² < 75%)
  - "High heterogeneity" (I² > 75%)
  - "Exclude high ROB" (remove Cochrane ROB > 3)
  - "Fixed effects only"
  - "Leave-one-out extremes"

- **Scenario save/load**:
  - Save current analysis state as named scenario
  - Load previous scenarios
  - Persist scenarios in SQLite registry

- **One-click Scenario Compare**:
  - Select 2 scenarios → side-by-side diff table
  - Shows: Δ pooled effect, Δ I², Δ ICER, Δ prob cost-effective
  - **Watermark figures** showing "Scenario A vs B"
  - Export comparison to PowerPoint section

**Files to Create:**
```
frontend/modules/scenarios.R (350 lines)
  - scenario_presets()
  - save_scenario()
  - load_scenario()
  - compare_scenarios()

backend/db/scenario_registry.py (150 lines)
  - ScenarioModel (SQLAlchemy)
  - save_to_db(), load_from_db()

templates/scenario_comparison.Rmd (120 lines)
```

**Acceptance Criteria:**
- [ ] User can save current state as "Scenario A"
- [ ] Preset "Exclude high ROB" filters correctly
- [ ] Compare renders diff table + side-by-side forest plots
- [ ] Export to PPT works (4 slides: title, table, 2 plots)

---

### 4. Client-Facing Portal v2 (🔐 SECURITY)

**Current State:** Basic white-label portal
**Enhancements:**

- **Role-based access**:
  - **Analyst** (edit/re-run)
  - **Reviewer** (comment/suggest)
  - **Client** (read-only)

- **Tokenized share links**:
  - Generate time-limited tokens (1 week, 1 month, never expire)
  - Track who viewed what, when
  - Revoke tokens

- **One-click "Publish Snapshot"**:
  - Freeze current results
  - Generate immutable content hash
  - Share link to frozen snapshot (never changes)
  - Audit log of all snapshots

**Files to Create:**
```
frontend/modules/portal_publish.R (200 lines)
  - publish_snapshot()
  - generate_share_token()
  - revoke_token()

backend/db/portal_access.py (180 lines)
  - PortalUser, PortalToken models
  - check_access()
  - log_view()

frontend/modules/portal_viewer.R (250 lines)
  - role-specific UI
  - comment system (reviewer role)
```

**Acceptance Criteria:**
- [ ] Analyst can publish snapshot with one click
- [ ] Generated share link works for 7 days
- [ ] Client role cannot see "Re-run" button
- [ ] View log shows who accessed when

---

### 5. Audit & Versioning v2 (📊 ANALYTICS)

**Current State:** SHA-256 hashing, audit trail exists
**Enhancements:**

- **SQLite audit database**:
  - Store every analysis run
  - Link runs to projects, users, scenarios
  - Track parameter changes

- **Run lineage graph**:
  - Visualize which runs derived from which
  - Show "Run B derived from Run A + updated data"
  - Export lineage as PNG/SVG

- **Deterministic content hash verification**:
  - Verify EvidenceObject hash matches contents
  - Flag if data was tampered with
  - Re-compute hash on demand

**Files to Create:**
```
backend/db/audit_db.py (250 lines)
  - AuditRun, AuditLog models
  - record_run()
  - get_lineage()

frontend/modules/audit_lineage.R (200 lines)
  - plot_lineage_graph()
  - verify_hash_ui()

frontend/modules/run_registry.R (180 lines)
  - list_all_runs()
  - search_runs()
  - tag_run()
```

**Acceptance Criteria:**
- [ ] Every MA run is logged in SQLite
- [ ] Lineage graph shows parent-child relationships
- [ ] Hash verification detects tampered EvidenceObject
- [ ] Search finds runs by outcome, date, tags

---

### 6. Living Meta-Analysis v2 (🔄 AUTOMATION)

**Current State:** Manual update workflow
**Enhancements:**

- **"New data arrived?" workflow**:
  - Upload CSV with new studies
  - Auto-detect: new studies vs updates to existing
  - Append to dataset
  - Re-fit models automatically
  - Generate **Δ results panel**

- **Delta Watch**:
  - Show: old pooled effect → new pooled effect
  - Highlight: Δ > X% (user-defined threshold)
  - Show: Δ ICER, Δ prob cost-effective
  - Alert if conclusions changed

- **Scheduled reminders** (optional):
  - Local cron inside container
  - Email reminder: "Check for new studies"
  - Or: manual "Remind me in 3 months" button

**Files to Create:**
```
frontend/modules/living_ma_v2.R (400 lines)
  - detect_new_studies()
  - append_and_refit()
  - delta_report_ui()
  - set_reminder()

backend/scheduler/living_cron.py (150 lines)
  - cron job setup
  - email_reminder() (optional SMTP)
```

**Acceptance Criteria:**
- [ ] Upload with 2 new studies → auto-appends
- [ ] Delta panel shows: old effect, new effect, difference
- [ ] Alert triggers if pooled effect changes > 15%
- [ ] Manual reminder sets next check date

---

## 🏗️ Architecture/Tech Upgrades

### Caching Layer (Performance)
```python
# backend/cache/evidence_cache.py (200 lines)
from diskcache import Cache

cache = Cache("./cache/evidence")

@cache.memoize(typed=True, expire=86400)
def run_metafor(yi, vi, method="REML"):
    ...
```

**Key:** Cache keyed by EvidenceObject content hash
**Storage:** Feather/Parquet for fast serialization
**Invalidation:** Invalidate if hash changes

### Results Registry (SQLite)
```python
# backend/db/results_registry.py
class ResultsRun(Base):
    id: int
    evidence_id: str
    content_hash: str
    created_at: datetime
    owner: str
    tags: List[str]
    outcome: str
    pooled_effect: float
    ...
```

**Purpose:** Quick search/filter of past runs without reloading files

### Shiny Modules Refactor
- Convert all modules to **strict moduleServer pattern**
- Each module returns **reactive list** of outputs
- **Plug-and-play** feature toggles in config

**Example:**
```r
# config/features.yaml
features:
  living_ma: true
  portal_publish: true
  bayesian_nma: false  # v3 only
```

---

## 📦 Deliverables

### New Tabs in UI
- **Scenarios** - Save, load, compare scenarios
- **Country Packs** - Select country, view parameters, compare
- **Lineage** - View run history, lineage graph, search

### New Rmd Templates
- **Protocol Diff Appendix** - Protocol vs execution comparison
- **Scenario Pack** - Multi-scenario comparison report

### Demo Datasets
- **4 new demo datasets**:
  1. Multi-outcome oncology trial (for PS model)
  2. Multi-arm vaccine trial (for NMA stress test)
  3. Dose-response meta-regression dataset
  4. Living MA with 3 update waves

### Documentation
- **Vignettes** (4):
  1. "Partitioned Survival Walkthrough"
  2. "Budget Impact Scenarios"
  3. "Living Meta-Analysis Setup"
  4. "Multi-Country HTA Submission"

---

## ✅ Success Criteria (Acceptance)

### Partitioned Survival
- [ ] Fits pass unit tests on 3 reference datasets (NICE TAs)
- [ ] AIC selects log-normal for dataset A (known correct)
- [ ] Extrapolation plots show 20-year horizon
- [ ] QALY calculation matches published TA within 0.5%

### Scenario Compare
- [ ] Renders Word/PPT **under 60 seconds** for 10-study MA
- [ ] Diff table shows correct Δ pooled effect
- [ ] Side-by-side forest plots have proper labels

### Country Flip
- [ ] UK → US flips ICER from £20k to $100k correctly
- [ ] Italy config loads costs in EUR
- [ ] All 8 country configs pass YAML validation

### Living Update
- [ ] Adding 3 studies to 8-study MA shows correct Δ pooled effect
- [ ] Δ ICER changes by expected amount (manually calculated)
- [ ] Audit entry records: who, when, what changed

---

## ⚠️ Risks & Guardrails

### Scope Creep Prevention
- ✋ **ONE** new model type: Partitioned Survival (not Markov extensions)
- ✋ No Bayesian NMA (that's v3)
- ✋ No EVPPI (that's v3)
- ✋ No auto-search PubMed (that's v3)

### Performance Guardrails
- Cache every heavy fit (MA models, PS models)
- Warn if NMA network > 15 treatments
- Timeout PS fitting if > 5 minutes per curve
- Limit scenario compare to 3 scenarios max

### Testing Requirements
- Unit tests for PS model (5 test cases)
- Integration test for living update workflow
- Load test: 100-study MA completes in < 10s

---

## 💰 Pricing Guidance

### For Existing v1 Clients
- **v2 Upgrade Fee:** £8,000–£12,000 one-time
- **Value:** 6 major features + performance improvements

### For New Clients
- **v2 One-off:** £20,000–£30,000 (includes setup + training)
- **v2 Annual Licence:** £10,000–£15,000/year + £5k onboarding

### Enterprise Tier (5+ users)
- £25,000–£40,000/year
- Includes: v2 features + priority support + quarterly updates

---

## 🛠️ Development Estimates

| Feature | Effort (hours) | Priority |
|---------|---------------|----------|
| Protocol v2 + PRISMA | 25 | HIGH |
| Partitioned Survival | 40 | HIGH |
| Budget Impact v2 | 20 | MEDIUM |
| Country Packs (3 new) | 15 | MEDIUM |
| Scenario Compare | 20 | HIGH |
| Portal v2 (roles) | 30 | MEDIUM |
| Audit v2 (lineage) | 25 | MEDIUM |
| Living MA v2 | 30 | MEDIUM |
| Caching layer | 15 | HIGH (performance) |
| SQLite registry | 12 | MEDIUM |

**Total:** ~232 hours (~6 weeks full-time or 3-4 months part-time)

---

## 📝 Claude-Ready Prompts

### Partitioned Survival
```
Implement `frontend/modules/survival_ps.R` for partitioned survival
with `flexsurv`, returning survival curves, restricted mean QALYs,
and a tidy PSA sampler hook. Include fit_parametric_survival()
function that fits 6 curves (Weibull, log-normal, log-logistic,
Gompertz, gamma, gen-gamma) and selects best by AIC. Return list
with: fitted_models, aic_table, qalys_pfs, qalys_pd, survival_plots.
```

### Scenario Compare
```
Add `frontend/modules/scenario_compare.R` that takes two EvidenceObjects
and produces a diff table + pptx section via `officer`. Include:
- compare_scenarios(obj1, obj2) → diff_table
- plot_side_by_side(obj1, obj2) → 2-panel forest plot
- export_comparison_pptx() → 4-slide deck
```

### Audit Lineage
```
Create `backend/db/audit_db.py` with SQLAlchemy models for AuditRun
(id, evidence_id, created_at, parent_run_id, tags, parameters).
Add get_lineage(run_id) function that returns parent→child graph
as dict. Add plot_lineage_graph() in R that uses `visNetwork`.
```

---

## 🔄 Migration & Backward Compatibility

### EvidenceObject Schema
- **v1.0 → v1.1:** Add optional fields:
  - `protocol_version`
  - `deviations: List[Deviation]`
  - `scenarios: List[Scenario]`

- **v1.1 → v2.0:** Add:
  - `survival_results: Dict[str, PartitionedSurvival]`
  - `scenario_comparisons: List[ComparisonResult]`
  - `audit_lineage: LineageGraph`

### Backward Compatibility
```python
# backend/schemas/evidence_object.py
class EvidenceObject(BaseModel):
    ...
    protocol_version: Optional[str] = "1.0"  # Default for old objects
    survival_results: Optional[Dict] = None  # v2 only

    @validator("protocol_version", pre=True, always=True)
    def set_default_protocol_version(cls, v):
        return v or "1.0"
```

---

## 📅 Release Plan

### Month 1
- Weeks 1-2: Partitioned Survival + unit tests
- Weeks 3-4: Scenario Compare + Scenario Registry

### Month 2
- Weeks 1-2: Budget Impact v2 + Country Packs (3 new)
- Weeks 3-4: Portal v2 (roles + tokens)

### Month 3
- Weeks 1-2: Audit v2 (lineage graph + SQLite)
- Weeks 3-4: Living MA v2 + caching layer

### Month 4 (polish)
- Week 1: Integration testing + bug fixes
- Week 2: Documentation + vignettes
- Week 3-4: Demo datasets + training materials

---

## ✨ What v2 Unlocks

After v2, you can:
1. **Bid on oncology HTAs** (need partitioned survival)
2. **Handle multi-scenario tenders** (scenario compare)
3. **Offer living evidence contracts** (recurring revenue)
4. **White-label for consultancies** (portal + branding)
5. **Compete with OPEN Health / Source HE** on deliverables

**Market Position:** Top-tier HEOR software, £50-75k contract value
