# EvidenceOS PRIME v4 Roadmap - "Intelligence & Integration"

**Timeline:** 6 months (post-v3)
**Goal:** Transform from consultancy tool → intelligent decision ecosystem
**Strategic Arc:** Automation → Augmentation → Ecosystem

---

## 🎯 Core Vision

Make EvidenceOS the **trusted analytical co-pilot** for evidence synthesis, health economics, and strategic insight. Move from static analysis tool to **continuous learning system** that thinks with the consultancy.

### Key Transformations

| From | To |
|------|-----|
| Single analysis | **Cross-project knowledge retention** |
| Static reports | **Living evidence streams** |
| Manual interpretation | **AI-assisted insights** |
| Solo deployment | **Federated multi-organization** |
| Fixed parameters | **Global market adaptation** |

---

## 📋 7 Major Feature Themes

### 1. AI Copilot & Insight Layer (Priority: HIGH)

**Duration:** 1 month
**Effort:** 80 hours

#### What It Does
- **Natural language queries:** "Show me the network plot for subgroup X" → auto-runs NMA/plot
- **Smart explanations:** Interpret I², heterogeneity, ICER outputs in plain English with citations
- **Methods coach:** Highlights unusual data patterns, suggests sensitivity runs
- **On-premise LLM:** No data leaves container (llama.cpp via reticulate)

#### Technical Implementation

**R Components:**
- `frontend/modules/ai_copilot.R` - Chat interface in Shiny
- `utils/nlq_parser.R` - Natural language to R command mapping
- `utils/insight_generator.R` - Statistical interpretation engine

**Python Components:**
- `backend/api/nlq.py` - FastAPI endpoint for LLM queries
- `backend/llm/llama_server.py` - Local LLM (quantized 7B model)
- `backend/llm/prompts.py` - Prompt templates for meta-analysis tasks

#### Example Queries
```
User: "Is there significant heterogeneity in the mortality outcome?"
Copilot: "Yes, I² = 67% indicates substantial heterogeneity (>50%).
         This suggests treatment effects vary across studies.
         Recommendation: Run subgroup analysis by risk of bias."

User: "Show me cost-effectiveness at £30k/QALY"
Copilot: [Generates CEAC plot + interpretation]
         "At £30,000/QALY, Drug X has 73% probability of being
         cost-effective. ICER = £24,567/QALY (95% CI: £18k-£32k)."

User: "Compare base case vs high ROB excluded"
Copilot: [Loads scenario comparison module]
         "Effect size decreased from 0.45 to 0.38 when excluding
         high ROB studies. This 15% reduction suggests risk of bias
         may inflate effects."
```

#### LLM Integration Architecture
```
┌─────────────────┐
│  Shiny UI       │
│  (R frontend)   │
└────────┬────────┘
         │ reticulate
         v
┌─────────────────┐      HTTP      ┌──────────────┐
│  R Backend      │ ────────────>  │ FastAPI      │
│  nlq_parser.R   │                │ /nlq endpoint│
└─────────────────┘                └──────┬───────┘
                                          │
                                          v
                                   ┌──────────────┐
                                   │ llama.cpp    │
                                   │ (quantized   │
                                   │  7B model)   │
                                   └──────────────┘
```

#### Acceptance Criteria
- ✅ AI copilot generates correct code snippets ≥95% of test prompts
- ✅ Responses include statistical citations (e.g., "Cochran's Q test p<0.10")
- ✅ No data leaves container (verified with network monitoring)
- ✅ Response time <5 seconds for standard queries
- ✅ Fallback to rule-based responses if LLM fails

#### Claude-Ready Prompt
```
Create backend/api/nlq.py FastAPI endpoint that:
1. Parses natural-language queries about meta-analysis
2. Maps to R Shiny actions via JSON response
3. Supports commands: run_meta, show_forest, run_icer, interpret_heterogeneity
4. Uses llama.cpp Python bindings for local LLM
5. Returns structured JSON: {action, parameters, explanation, confidence}
6. Include prompt templates for:
   - Interpreting I² values
   - Explaining ICER results
   - Recommending sensitivity analyses
```

---

### 2. Knowledge Graph of Evidence (Priority: HIGH)

**Duration:** 1 month
**Effort:** 60 hours

#### What It Does
- **Graph database:** Links studies, interventions, outcomes, parameters across projects
- **Deduplication:** Auto-detects reused studies → warns of duplication
- **Similarity search:** "Find similar analyses" → cross-project learning
- **Metadata export:** JSON-LD for HTA submission

#### Technical Implementation

**R Components:**
- `backend/graph/evidence_graph.R` - igraph construction from EvidenceObjects
- `frontend/modules/knowledge_graph_ui.R` - Interactive graph visualization
- `utils/graph_queries.R` - Query functions (find_similar, detect_duplicates)

**Python Components:**
- `backend/graph/nx_builder.py` - NetworkX graph construction
- `backend/graph/similarity.py` - Cosine similarity for PICO matching
- `backend/graph/export_jsonld.py` - JSON-LD schema.org export

#### Graph Schema
```
Nodes:
  - Study (study_id, year, author, journal)
  - Intervention (name, dose, duration)
  - Outcome (name, type, measure)
  - Parameter (name, value, source, uncertainty)
  - Analysis (analysis_id, date, analyst, project)

Edges:
  - Study -[INCLUDES]→ Intervention
  - Study -[MEASURES]→ Outcome
  - Analysis -[USES]→ Study
  - Intervention -[TARGETS]→ Outcome
  - Parameter -[DERIVED_FROM]→ Study
```

#### Example Queries
```r
# Find all studies using Drug X
find_studies_by_intervention("Drug X")

# Detect duplicate studies across projects
detect_study_overlap(project_id_1 = "PROJ_001", project_id_2 = "PROJ_002")

# Find similar analyses (PICO matching)
find_similar_analyses(
  population = "Type 2 Diabetes",
  intervention = "SGLT2 inhibitors",
  outcome = "HbA1c reduction",
  threshold = 0.8  # cosine similarity
)

# Export graph as JSON-LD
export_graph_jsonld(analysis_id = "ANAL_123",
                    schema = "https://schema.org/MedicalStudy")
```

#### UI Features
- **Network Visualization:** Interactive igraph plot (visNetwork)
- **Study Timeline:** Chronological view of evidence accrual
- **Reuse Dashboard:** Shows which studies appear in multiple projects
- **Export Panel:** Download graph as GraphML, JSON-LD, or RDF

#### Acceptance Criteria
- ✅ Graph detects duplicate study_ids across 3+ projects
- ✅ Similarity search returns relevant analyses (precision ≥80%)
- ✅ JSON-LD validates against schema.org/MedicalStudy
- ✅ Graph visualization supports 100+ nodes without lag
- ✅ Incremental updates (add study without full rebuild)

#### Claude-Ready Prompt
```
Implement frontend/modules/evidence_graph.R that:
1. Builds igraph from multiple EvidenceObjects stored in outputs/
2. Detects duplicate study_ids across projects
3. Calculates PICO similarity using cosine distance
4. Creates visNetwork interactive visualization with:
   - Node color by study type (RCT/observational)
   - Node size by sample size
   - Edge width by number of shared outcomes
5. Provides UI with:
   - "Find Similar" button
   - "Detect Duplicates" button
   - Export options (GraphML, JSON-LD)
6. Query interface: text input → filter graph by PICO terms
```

---

### 3. Federated & Multi-Client Deployment (Priority: MEDIUM)

**Duration:** 1 month
**Effort:** 50 hours

#### What It Does
- **Multi-tenant:** Each consultancy/team runs isolated node
- **Encrypted sync:** Optional aggregated metrics sync to HQ (no sensitive data)
- **Audit compliance:** Organization-level logging
- **Authentication:** Keycloak/ShinyProxy integration

#### Technical Implementation

**Deployment Options:**
```
Option A: Single Docker (current)
  - 1 consultancy, all users share instance
  - SQLite database
  - File-based sessions

Option B: ShinyProxy Multi-Tenant
  - Multiple isolated Shiny containers per user
  - Shared Postgres database (encrypted)
  - User authentication via LDAP/OAuth

Option C: Kubernetes (enterprise)
  - Helm chart for orchestration
  - Separate namespaces per organization
  - Encrypted inter-node sync (optional)
```

#### Architecture (Option B - Recommended)
```
                    ┌──────────────────┐
                    │  ShinyProxy      │
                    │  (auth gateway)  │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         v                   v                   v
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ Shiny Container│  │ Shiny Container│  │ Shiny Container│
│ User: alice    │  │ User: bob      │  │ User: charlie  │
└────────┬───────┘  └────────┬───────┘  └────────┬───────┘
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             v
                    ┌──────────────────┐
                    │  Postgres DB     │
                    │  (encrypted)     │
                    │  - users         │
                    │  - projects      │
                    │  - audit_log     │
                    └──────────────────┘
```

#### Configuration (application.yml for ShinyProxy)
```yaml
proxy:
  authentication: ldap
  ldap:
    url: ldap://ldap.company.com
    base-dn: dc=company,dc=com

  specs:
    - id: evidenceos-prime
      display-name: EvidenceOS PRIME
      container-image: evidenceos-prime:v4
      container-cmd: ["R", "-e", "shiny::runApp('/app')"]
      container-network: evidenceos-network
      container-env:
        DB_HOST: postgres
        DB_NAME: evidenceos
        USER_ID: "#{proxy.userId}"
        ORG_ID: "#{proxy.ldap.org}"
      access-groups: ["scientists", "analysts"]
```

#### Federated Sync (Optional HQ Aggregation)
```python
# backend/federation/sync.py
def aggregate_metrics(nodes):
    """
    Aggregate non-sensitive metrics from federated nodes
    Encrypted transmission, anonymized data
    """
    metrics = {
        "total_analyses": 0,
        "avg_turnaround_days": [],
        "common_interventions": defaultdict(int),
        "avg_heterogeneity": []
    }

    for node in nodes:
        # Fetch encrypted metrics from node API
        node_data = fetch_node_metrics(node.url, node.api_key)

        # Aggregate
        metrics["total_analyses"] += node_data["n_analyses"]
        metrics["avg_turnaround_days"].extend(node_data["turnaround"])

        # No PII, no study-level data

    return anonymize_and_report(metrics)
```

#### Acceptance Criteria
- ✅ ShinyProxy runs 3+ concurrent isolated Shiny instances
- ✅ User A cannot access User B's projects
- ✅ Audit log records all user actions with user_id
- ✅ Optional metrics sync transmits encrypted JSON
- ✅ Helm chart deploys on Kubernetes with 1 command

#### Claude-Ready Prompt
```
Create docker-compose.yml and ShinyProxy configuration that:
1. Runs ShinyProxy on port 8080
2. Spins up isolated Shiny containers per user
3. Connects to Postgres database (shared, row-level security by user_id)
4. Uses LDAP authentication (mockldap for testing)
5. Includes:
   - docker-compose.yml
   - application.yml (ShinyProxy config)
   - Dockerfile for Shiny app with USER_ID env var
6. Test with 2 users: alice, bob (different projects, no cross-access)
```

---

### 4. Advanced HTA & Market Access Suite (Priority: HIGH)

**Duration:** 1.5 months
**Effort:** 100 hours

#### What It Does
- **Stochastic Budget Impact v2:** Uncertainty + uptake scenarios
- **Global Cost Converter:** Currency, inflation, PPP adjustment (OECD API cache)
- **Launch Sequence Simulator:** Phased launch across markets
- **Value Story Generator:** Auto-generate payer slide deck

#### Features

##### 4.1 Stochastic Budget Impact Analysis
```r
# Current (v1): Deterministic BIA
budget_impact_simple(
  cost_per_patient = 10000,
  eligible_population = 50000,
  market_share = c(0.05, 0.10, 0.15)  # years 1-3
)

# v4: Stochastic BIA
budget_impact_stochastic(
  cost_per_patient = list(mean = 10000, sd = 1500, dist = "gamma"),
  eligible_population = list(mean = 50000, sd = 5000, dist = "normal"),
  market_share = list(
    year1 = list(mean = 0.05, alpha = 5, beta = 95),  # beta dist
    year2 = list(mean = 0.10, alpha = 10, beta = 90),
    year3 = list(mean = 0.15, alpha = 15, beta = 85)
  ),
  n_iterations = 10000,
  price_erosion = 0.02  # 2% annual price reduction
)

# Output: CEAC surface, percentile bands, tornado diagram
```

**Implementation:** Use `heemod` for Markov-based BIA + Monte Carlo

##### 4.2 Global Cost Converter
```r
# Convert UK costs to US, Germany, France with PPP + inflation
convert_costs_global(
  costs = list(
    drug_treatment = 15000,  # GBP
    hospitalization = 5000
  ),
  from_country = "UK",
  to_countries = c("US", "Germany", "France"),
  from_year = 2023,
  to_year = 2025,
  method = "PPP"  # or "market_exchange"
)

# Output:
# Country   Drug_Treatment  Hospitalization  Currency  Method
# US        $26,340         $8,780          USD       PPP
# Germany   €17,850         €5,950          EUR       PPP
# France    €16,800         €5,600          EUR       PPP
```

**Data Sources:**
- OECD PPP exchange rates (cached offline JSON)
- WHO-CHOICE unit costs
- NHS Reference Costs
- CMS Fee Schedules

**File:** `backend/economics/global_costs.R`
- Offline cache: `data/oecd_ppp_2010_2025.json`
- Auto-update: annual refresh from OECD API

##### 4.3 Launch Sequence Simulator
```r
# Simulate phased market entry
simulate_launch_sequence(
  markets = list(
    UK = list(launch_year = 1, price = 15000, uptake_curve = "sigmoid"),
    Germany = list(launch_year = 1.5, price = 17000, uptake_curve = "linear"),
    France = list(launch_year = 2, price = 16000, uptake_curve = "sigmoid"),
    Italy = list(launch_year = 2.5, price = 14000, uptake_curve = "step"),
    Spain = list(launch_year = 3, price = 13000, uptake_curve = "sigmoid")
  ),
  time_horizon = 10,  # years
  discount_rate = 0.035
)

# Output: Cumulative revenue by market, peak sales year, NPV
```

**Visualization:**
- Waterfall chart (cumulative revenue by market)
- Launch timeline Gantt chart
- NPV sensitivity to launch delays

##### 4.4 Value Story Generator (Auto-Slide Deck)
```r
# Auto-generate PowerPoint for payers
generate_value_story(
  analysis_id = "ANAL_123",
  target_audience = "NHS England",
  template = "NICE_HTA_2024",
  sections = c(
    "clinical_efficacy",      # Forest plot + interpretation
    "safety_profile",         # AE table
    "cost_effectiveness",     # CEAC + ICER
    "budget_impact",          # 3-year projection
    "patient_access",         # Unmet need + target population
    "value_proposition"       # 1-slide summary
  ),
  branding = load_branding("NHS_template")
)

# Output: outputs/value_story_ANAL_123_20251102.pptx
```

**Slide Templates:**
- **Slide 1:** Title (branded)
- **Slide 2:** Unmet Need (population stats + current SOC gaps)
- **Slide 3:** Clinical Efficacy (forest plot + RR/HR with CI)
- **Slide 4:** Safety (AE table, RR of serious AEs)
- **Slide 5:** Cost-Effectiveness (CEAC + ICER value)
- **Slide 6:** Budget Impact (3-year projection table + waterfall)
- **Slide 7:** Value Proposition (4 bullet points auto-generated)

**Auto-Generated Narrative Examples:**
```
"Drug X demonstrates a 35% relative risk reduction in mortality
(RR=0.65, 95% CI: 0.52-0.81, p<0.001) compared to standard care,
based on pooled evidence from 12 RCTs (n=8,456 patients).
Heterogeneity was low (I²=23%), indicating consistent effects
across studies."

"At a willingness-to-pay threshold of £30,000/QALY, Drug X has
a 78% probability of being cost-effective. The base-case ICER
of £24,567/QALY is well below the £30,000 threshold, with
probabilistic sensitivity analysis confirming robustness
(95% credible interval: £18,200-£32,400/QALY)."
```

#### Acceptance Criteria
- ✅ Stochastic BIA ICER distribution reproducible (same seed)
- ✅ Global cost converter matches OECD PPP within 2%
- ✅ Launch simulator handles 10 markets with different uptake curves
- ✅ Value story PPT generates all 7 slides in <10 seconds
- ✅ Auto-narrative matches manual interpretation (blind review ≥90%)

#### Claude-Ready Prompt
```
Create frontend/modules/bia_stochastic.R using heemod that:
1. Accepts stochastic parameter inputs (mean, sd, distribution type)
2. Runs Monte Carlo budget impact simulation (10k iterations)
3. Outputs:
   - CEAC surface plot (3D: WTP threshold × year × probability)
   - Percentile bands (5th, 25th, 50th, 75th, 95th) for budget
   - Tornado diagram (top 10 parameters by variance contribution)
4. Uses parallel processing (future package) for speed
5. UI with:
   - Parameter definition table (DT editable)
   - Distribution preview plots (ggplot density curves)
   - Results panel with downloadable CSV/PNG
```

---

### 5. Living Evidence v3 - Streaming Mode (Priority: MEDIUM)

**Duration:** 1 month
**Effort:** 70 hours

#### What It Does
- **PubMed/ClinicalTrials.gov feeds:** Auto-notify of new eligible studies
- **One-click ingestion:** New study → delta report (forest, NMA, CEAC shift)
- **Scheduled updates:** Nightly cron jobs within container
- **Alerting:** Email/Slack when new evidence changes conclusions

#### Technical Implementation

**Python Components:**
- `backend/feeds/pubmed_sync.py` - Entrez API queries
- `backend/feeds/clinicaltrials_sync.py` - ClinicalTrials.gov API
- `backend/feeds/alert_engine.py` - Compare new vs old results
- `backend/feeds/scheduler.py` - APScheduler for nightly jobs

**R Components:**
- `frontend/modules/living_evidence_ui.R` - Feed management interface
- `utils/delta_report.R` - Compare old/new meta-analysis
- `utils/email_alerts.R` - Send alert emails via blastula package

#### Workflow
```
1. User defines search criteria (PICO + date range)
   ↓
2. Scheduled job runs nightly:
   - Query PubMed Entrez API
   - Filter by PICO inclusion criteria
   - Check against existing study_ids in database
   ↓
3. New studies detected → Alert triggered
   ↓
4. User reviews new studies in Shiny UI:
   - Accept (add to analysis)
   - Reject (mark as excluded)
   - Defer (review later)
   ↓
5. If accepted → Auto-run delta analysis:
   - New forest plot vs old
   - ICER change (if HE model linked)
   - NMA ranking shift
   ↓
6. Generate delta report (PDF/Word)
```

#### Example Search Query
```r
define_living_search(
  search_id = "LIVE_001",
  database = "pubmed",
  query = '("diabetes mellitus, type 2"[MeSH] AND "SGLT2 inhibitors"[MeSH]
            AND "randomized controlled trial"[PT])',
  date_range = "last_30_days",
  inclusion_criteria = c(
    "Adults ≥18 years",
    "HbA1c outcome reported",
    "≥12 weeks duration"
  ),
  alert_threshold = list(
    new_studies = 1,          # Alert if ≥1 new study
    effect_change_pct = 10    # Alert if pooled effect changes >10%
  ),
  schedule = "daily",  # or "weekly", "monthly"
  notify = c("email", "slack")
)
```

#### Delta Report Format
```markdown
# Living Evidence Update - LIVE_001

**Date:** 2025-11-15
**New Studies:** 2
**Previous Analysis:** 2025-10-01 (n=12 studies)
**Updated Analysis:** 2025-11-15 (n=14 studies)

## New Studies Identified
1. Smith et al. 2025 (n=458) - published 2025-11-05
2. Jones et al. 2025 (n=612) - published 2025-11-10

## Effect Size Comparison
| Analysis | Pooled Effect (RR) | 95% CI | I² |
|----------|-------------------|--------|-----|
| Previous | 0.65 | 0.52-0.81 | 23% |
| Updated  | 0.68 | 0.56-0.82 | 28% |
| **Change** | **+0.03** | **-** | **+5%** |

**Interpretation:** New evidence suggests slightly smaller treatment
effect (+0.03 RR, 5% relative change). Heterogeneity remains low.
Conclusion unchanged: statistically significant benefit persists.

## Forest Plot Comparison
[Side-by-side forest plots: old vs new]

## Recommendation
✅ Update analysis accepted. Revised effect size remains statistically
   significant and clinically meaningful. Consider updating HTA dossier
   if submission pending.
```

#### Acceptance Criteria
- ✅ PubMed feed correctly flags ≥90% of new trials within 24h
- ✅ Delta report generates in <30 seconds for 20-study meta-analysis
- ✅ Alert threshold correctly triggers (test with simulated data)
- ✅ Email alerts include clickable link to Shiny review interface
- ✅ Handles API rate limits gracefully (retry with exponential backoff)

#### Claude-Ready Prompt
```
Create backend/feeds/pubmed_sync.py that:
1. Uses Biopython Entrez module to query PubMed
2. Accepts search parameters: query string, date range, max results
3. Returns list of PMIDs + metadata (title, authors, abstract, pub date)
4. Filters results by inclusion criteria using NLP:
   - Extract population (age, condition) from abstract
   - Extract intervention (drug class, dose) from title/abstract
   - Extract outcome (primary endpoint) from abstract
5. Compares PMIDs against existing study_ids in SQLite database
6. Returns list of NEW studies only
7. Runs as scheduled job (APScheduler) with configurable frequency
8. Logs all queries + results to audit table
```

---

### 6. Meta-Research & Benchmarking Analytics (Priority: LOW)

**Duration:** 1 month
**Effort:** 40 hours

#### What It Does
- **Internal KPI dashboards:** Turnaround time, analyses completed, heterogeneity trends
- **Cross-consultancy benchmarking:** Anonymized comparison vs industry
- **Predictive analytics:** Forecast time/cost savings per project
- **Quality metrics:** Track ROB trends, publication bias frequency

#### Dashboards

##### 6.1 Analyst Performance Dashboard
```r
# Metrics per analyst
analyst_dashboard(
  analyst_id = "ANAL_001",
  date_range = c("2025-01-01", "2025-12-31")
)

# Outputs:
# - Total analyses completed: 24
# - Avg turnaround time: 12 days (vs org avg: 15 days)
# - Avg heterogeneity (I²): 38% (vs org avg: 42%)
# - Publication bias detected: 3/24 (12.5%)
# - ROB high risk: 8/24 (33%)
```

**Visualizations:**
- Line chart: Analyses per month
- Box plot: Turnaround time distribution
- Heatmap: I² across outcomes
- Bar chart: ROB distribution (Low/Some/High)

##### 6.2 Organizational Benchmarking
```r
# Compare across consultancies (anonymized)
benchmark_organization(
  org_id = "ORG_123",
  metrics = c("turnaround_time", "avg_heterogeneity", "icer_distribution"),
  comparison_group = "all"  # or "industry_subset"
)

# Output:
# Metric                Your Org   Median   90th %ile
# Turnaround (days)      12         15       22
# Avg I²                 38%        45%      62%
# ICER < £30k/QALY       72%        65%      55%
#
# Interpretation: Your org is in top 25% for efficiency
```

##### 6.3 Predictive Analytics (Simple ML)
```python
# backend/analytics/predictive_model.py
from sklearn.ensemble import RandomForestRegressor

def predict_project_duration(project_features):
    """
    Predict project turnaround time based on features:
    - Number of studies
    - Number of outcomes
    - Analysis types (pairwise/NMA/dose-response)
    - HE model complexity (3-state vs partitioned survival)
    """
    model = load_model("outputs/turnaround_predictor.pkl")

    features = [
        project_features["n_studies"],
        project_features["n_outcomes"],
        int(project_features["has_nma"]),
        int(project_features["has_he_model"]),
        project_features["avg_study_size"]
    ]

    predicted_days = model.predict([features])[0]
    confidence_interval = calculate_prediction_interval(model, features)

    return {
        "predicted_days": round(predicted_days, 1),
        "ci_lower": round(confidence_interval[0], 1),
        "ci_upper": round(confidence_interval[1], 1)
    }

# Example usage in R via reticulate
predict_turnaround <- function(n_studies, n_outcomes, has_nma, has_he) {
  py$predict_project_duration(list(
    n_studies = n_studies,
    n_outcomes = n_outcomes,
    has_nma = has_nma,
    has_he_model = has_he,
    avg_study_size = 250  # default
  ))
}

# Result: "Predicted turnaround: 14.2 days (95% CI: 10.5 - 18.3)"
```

**Training Data:**
- Historical project data from audit log
- Features: study count, outcome count, analysis types, ROB distribution
- Target: actual turnaround time (first import to final report)
- Model: RandomForestRegressor (scikit-learn)
- Validation: 5-fold cross-validation, MAE <3 days

#### Acceptance Criteria
- ✅ Dashboards update in real-time as new analyses complete
- ✅ Benchmarking compares ≥3 organizations (anonymized IDs)
- ✅ Predictive model achieves MAE <3 days on test set
- ✅ Export benchmarking report as PDF with charts
- ✅ No PII or sensitive data in aggregated metrics

#### Claude-Ready Prompt
```
Create frontend/modules/analytics_dashboard.R that:
1. Queries SQLite audit log for completed analyses
2. Calculates KPIs:
   - Analyses per month (line chart)
   - Turnaround time distribution (box plot)
   - Avg I² by outcome type (heatmap)
   - ROB distribution (stacked bar chart)
3. Compares against organization benchmarks (if available)
4. Displays predicted turnaround for current project using predictive model
5. UI with:
   - Date range selector
   - Analyst filter dropdown
   - Export button (PDF report)
6. Uses plotly for interactive charts
```

---

### 7. Compliance & Audit v3 (Priority: MEDIUM)

**Duration:** 1 month
**Effort:** 60 hours

#### What It Does
- **21 CFR Part 11 compliance:** Digital signatures for regulated submissions
- **GxP audit trail:** Immutable log with user, timestamp, action, hash
- **Validation reports:** Auto-generated IQ/OQ/PQ documentation
- **SHA-512 hashing:** Content verification for all exported artifacts

#### Features

##### 7.1 Digital Signatures (21 CFR Part 11)
```r
# Sign an analysis before export
sign_analysis(
  analysis_id = "ANAL_123",
  user_id = "alice@company.com",
  password = "***",  # or PKI certificate
  reason = "Final HTA submission to NICE",
  location = "London, UK"
)

# Verification
verify_signature(
  file_path = "outputs/report_ANAL_123.docx"
)

# Output:
# ✓ Signature valid
# Signed by: alice@company.com
# Date: 2025-11-15 14:32:01 GMT
# Hash: SHA-512:a3b2c1d4e5f6...
# Reason: Final HTA submission to NICE
```

**Implementation:**
- Use `openssl` R package for signing
- Store signatures in SQLite audit table
- Embed signature metadata in exported documents (Word/PDF custom properties)

##### 7.2 Immutable Audit Trail
```sql
-- audit_log table schema
CREATE TABLE audit_log (
  log_id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id TEXT NOT NULL,
  action TEXT NOT NULL,  -- e.g., "analysis_created", "report_exported"
  analysis_id TEXT,
  details JSON,  -- Additional context
  content_hash TEXT,  -- SHA-512 of EvidenceObject
  signature TEXT,  -- Digital signature (if signed)
  ip_address TEXT,
  session_id TEXT,
  CONSTRAINT immutable CHECK (1 = 1)  -- Prevent DELETE/UPDATE
);

-- Trigger to prevent modification
CREATE TRIGGER prevent_audit_delete
BEFORE DELETE ON audit_log
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'Audit log records cannot be deleted');
END;

CREATE TRIGGER prevent_audit_update
BEFORE UPDATE ON audit_log
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'Audit log records cannot be modified');
END;
```

**Audit Actions Logged:**
- Data import (filename, rows, hash)
- Protocol creation/modification (version, locked status)
- Analysis execution (type, parameters, runtime)
- Report generation (format, sections, branding)
- Study selection (included/excluded, reason)
- Deviation logging (description, justification)

##### 7.3 Validation Reports (IQ/OQ/PQ)
```r
# Auto-generate validation documentation
generate_validation_report(
  type = "OQ",  # Installation Qualification, Operational Qualification, Performance Qualification
  software_version = "4.0.0",
  test_cases = load_test_cases("tests/oq_test_suite.csv"),
  output_path = "validation/OQ_Report_v4.0.0.pdf"
)

# OQ Test Cases (examples):
# 1. Meta-analysis calculation accuracy (compare to Cochrane)
# 2. ICER calculation reproducibility (same input → same output)
# 3. Publication bias detection (Egger's test matches metafor)
# 4. Budget impact Monte Carlo convergence (10k iterations)
# 5. Digital signature verification (signed doc validates)
```

**IQ Checklist:**
- Software installed correctly (R version, packages)
- Database schema created (SQLite tables)
- Configuration files present (countries YAML)
- Documentation accessible (README, user guide)

**OQ Test Results Table:**
```
Test ID   Description                  Expected        Actual          Status
OQ-001    Pooled RR (fixed-effects)   0.65 (0.52-0.81) 0.65 (0.52-0.81) PASS
OQ-002    I² calculation              42.3%           42.3%           PASS
OQ-003    ICER (base case)            £24,567         £24,567         PASS
OQ-004    Digital signature verify    Valid           Valid           PASS
OQ-005    Audit log immutability      DELETE fails    DELETE fails    PASS
```

##### 7.4 SHA-512 Content Hashing
```r
# Current (v1): SHA-256
hash_evidence_object <- function(eo) {
  digest::digest(eo, algo = "sha256")
}

# v4: SHA-512 (stronger)
hash_evidence_object_v4 <- function(eo) {
  digest::digest(eo, algo = "sha512")
}

# Verify hash
verify_evidence_hash(
  file_path = "outputs/evidence_ANAL_123.json",
  expected_hash = "a3b2c1d4e5f6..."
)
# Output: ✓ Hash verified - file integrity confirmed
```

**Hash Storage:**
- Store in audit log for every exported file
- Embed in document metadata (Word/PDF custom properties)
- Display in UI (show hash on export confirmation)

#### Acceptance Criteria
- ✅ Digital signature verifies on all exported reports
- ✅ Audit log prevents DELETE/UPDATE operations (tested with SQL)
- ✅ Validation report auto-generates with 20+ test cases
- ✅ SHA-512 hash matches between creation and verification
- ✅ 21 CFR Part 11 compliance checklist 100% complete

#### Claude-Ready Prompt
```
Create backend/audit/digital_signature.R that:
1. Uses openssl package to create RSA digital signatures
2. Accepts user_id, password/certificate, reason, location
3. Generates signature for EvidenceObject JSON
4. Stores signature in audit_log table with timestamp
5. Embeds signature in exported Word/PDF documents as custom property
6. Provides verify_signature() function that:
   - Extracts signature from document
   - Recomputes hash of content
   - Validates signature against stored public key
   - Returns: valid/invalid + signer details
7. UI with:
   - "Sign Analysis" button (requires password confirmation)
   - Signature status badge in header
   - Verification panel for uploaded documents
```

---

## 🏗 Architecture Evolution

### Current (v1-v3)
```
┌─────────────────┐
│  Shiny Frontend │
│  (R only)       │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  FastAPI Backend│
│  (Python)       │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  SQLite         │
│  (flat tables)  │
└─────────────────┘
```

### v4 Architecture
```
┌─────────────────────────────────────────────┐
│           Shiny Frontend (R)                │
│  ┌────────┐ ┌────────┐ ┌────────┐          │
│  │AI Pilot│ │ Graph  │ │ HTA    │          │
│  │        │ │  UI    │ │ Suite  │          │
│  └───┬────┘ └───┬────┘ └───┬────┘          │
└──────┼──────────┼──────────┼────────────────┘
       │          │          │
       │ reticulate│          │ HTTP
       v          v          v
┌──────────────────────────────────────────────┐
│         FastAPI Backend (Python)             │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ NLQ  │ │Graph │ │Feeds │ │ ML   │       │
│  │/nlq  │ │/sim  │ │/sync │ │/pred │       │
│  └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘       │
└─────┼────────┼────────┼────────┼────────────┘
      │        │        │        │
      v        v        v        v
┌──────────────────────────────────────────────┐
│  llama.cpp  NetworkX  APScheduler scikit-learn│
└──────────────────────────────────────────────┘
                      │
                      v
┌──────────────────────────────────────────────┐
│       SQLite + Parquet + igraph              │
│  ┌───────────┐ ┌──────────┐ ┌──────────┐    │
│  │ audit_log │ │evidence_ │ │ cache/   │    │
│  │ (append)  │ │ graph    │ │ .parquet │    │
│  └───────────┘ └──────────┘ └──────────┘    │
└──────────────────────────────────────────────┘
```

### Key Changes
| Component | v1-v3 | v4 |
|-----------|-------|-----|
| **Database** | SQLite flat tables | SQLite + igraph + Parquet |
| **Python Backend** | Simple validation API | FastAPI with NLQ, feeds, ML |
| **Computation** | Synchronous in Shiny | Async job queue (callr + rq) |
| **AI** | None | Local LLM (llama.cpp) |
| **Caching** | None | Parquet files keyed by hash |
| **Scheduling** | Manual | APScheduler for nightly jobs |
| **Security** | Basic auth | Digital signatures + PKI |

---

## 📊 Timeline & Effort Summary

| Phase | Duration | Effort (hrs) | Key Deliverables |
|-------|----------|--------------|------------------|
| **1. Architecture Upgrade** | 1 mo | 60 | EvidenceGraph + job queue |
| **2. AI Copilot Alpha** | 1 mo | 80 | NLQ for 3 core tasks |
| **3. HTA Suite v3** | 1.5 mo | 100 | Stochastic BIA, global costs, launch sim |
| **4. Living Evidence v3** | 1 mo | 70 | PubMed sync + delta reports |
| **5. Benchmark & Compliance** | 1 mo | 50 | KPI dashboards + digital signatures |
| **6. Final Polish & Docs** | 0.5 mo | 40 | Training materials, Helm chart |
| **TOTAL** | **6 months** | **400 hrs** | **v4 Release** |

**Cost Estimate:**
- Internal development: 400 hrs × £75/hr = **£30,000**
- External contractor: 400 hrs × £150/hr = **£60,000**
- ROI: v4 licensing £30-50k/year → Break-even in 1-2 years

---

## 🧪 Final Acceptance Criteria

### AI Copilot
- [ ] Generates correct code snippets ≥95% of test prompts
- [ ] Responses <5 seconds for standard queries
- [ ] No data leaves container (verified network logs)

### Knowledge Graph
- [ ] Detects duplicate study_ids across 3+ projects
- [ ] Similarity search precision ≥80%
- [ ] JSON-LD validates against schema.org

### Federation
- [ ] ShinyProxy runs 3+ concurrent isolated instances
- [ ] User A cannot access User B's projects (tested)

### HTA Suite
- [ ] Stochastic BIA reproducible (same seed)
- [ ] Global cost converter matches OECD PPP within 2%
- [ ] Value story generates 7 slides in <10 seconds

### Living Evidence
- [ ] PubMed feed flags ≥90% of new trials within 24h
- [ ] Delta report generates in <30 seconds

### Compliance
- [ ] Digital signatures verify on all reports
- [ ] Audit log prevents DELETE/UPDATE
- [ ] Validation report auto-generates 20+ test cases

---

## 💡 Post-v4 Options

Once v4 stabilizes, strategic choices:

### Option A: Open Source Core
- Release v1-v3 on GitHub under MIT license
- Keep v4 enterprise features (AI, federation) proprietary
- Build academic community → citations and contributions
- Publish methodology paper: *"A Modular R/Python Framework for Living HTA Automation"*

### Option B: Enterprise Licensing
- License v4 to HEOR consultancies (£30-50k/year per organization)
- Offer managed cloud deployment (£5-10k/month)
- Provide training and support (£2k/day)
- Target: 5-10 clients in year 1 → £150-500k revenue

### Option C: SaaS Platform
- Multi-tenant cloud version (AWS/Azure)
- Freemium model: v1-v2 free, v3-v4 paid
- Usage-based pricing: £50/analysis or £500/month unlimited
- Target: 100+ users in year 1 → £600k ARR

### Option D: Academic Partnership
- Collaborate with university (Oxford, LSE, York)
- Joint grant funding (NIHR, MRC)
- Publish methodology + case studies
- Train next generation of HTA analysts

---

## 📝 Next Steps

### Immediate (This Week)
1. **Review and approve v4 roadmap**
2. **Decide on priority features** (AI Copilot + HTA Suite recommended first)
3. **Set up development environment**:
   - Python venv with llama-cpp-python
   - R with igraph, heemod, future packages
   - Docker Compose for testing

### Short Term (Next Month)
4. **Scaffold v4 architecture**:
   - Create backend/api/nlq.py stub
   - Create frontend/modules/evidence_graph.R stub
   - Set up job queue (Python rq)
5. **Implement AI Copilot MVP**:
   - 3 commands: run_meta, show_forest, interpret_heterogeneity
   - Test with llama.cpp 7B model
6. **Build EvidenceGraph prototype**:
   - Load 3 sample projects
   - Detect duplicate studies
   - Visualize network

### Medium Term (3-6 Months)
7. **Complete all 7 feature themes**
8. **Comprehensive testing** (unit, integration, acceptance)
9. **Documentation** (API docs, user guide, video tutorials)
10. **Beta release** to 2-3 friendly consultancies

---

## 📚 Tech Stack Summary

### R Packages (New in v4)
- `igraph` - Evidence graph construction
- `heemod` - Stochastic health economic models
- `visNetwork` - Interactive network visualization
- `future` - Parallel processing
- `blastula` - Email alerts
- `callr` - Async R jobs

### Python Packages (New in v4)
- `llama-cpp-python` - Local LLM inference
- `networkx` - Graph algorithms
- `scikit-learn` - Predictive ML models
- `apscheduler` - Job scheduling
- `biopython` - PubMed Entrez API
- `rq` - Redis-based job queue

### Infrastructure (New in v4)
- **ShinyProxy** - Multi-tenant Shiny hosting
- **Postgres** - Shared database (optional, for federation)
- **Redis** - Job queue backend
- **Helm** - Kubernetes deployment

---

## 🎯 Strategic Positioning

### v1 (Current)
- **Value:** £40-50k (functional baseline)
- **Users:** Single consultancy, solo analyst
- **Features:** Core MA + HE + reporting

### v2 (3-4 months)
- **Value:** £50-75k (full-service)
- **Users:** Small team (2-5 analysts)
- **Features:** + Scenarios, Protocol v2, Country Packs

### v3 (6-8 months from v2)
- **Value:** £75-100k (research-grade)
- **Users:** Medium org (5-20 analysts)
- **Features:** + Bayesian NMA, VOI, Living Evidence v2

### v4 (6 months from v3)
- **Value:** £100-150k/year (enterprise ecosystem)
- **Users:** Large org (20+ analysts) or federated multi-org
- **Features:** + AI Copilot, Knowledge Graph, Global HTA, Compliance

**Total Journey:** 18-24 months from v1 → v4
**Revenue Potential:** £125-500k/year (depending on licensing model)

---

**Ready to start v4 scaffolding?** Let me know which feature to build first, and I'll generate the initial file stubs + Claude-ready prompts.
