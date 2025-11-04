# EvidenceOS PRIME - Mahmood789 Repository Integration Plan

## Executive Summary

This document outlines the integration of **Mahmood789's meta-analysis repositories** into EvidenceOS PRIME, adding:
- **19+ production-ready Shiny apps** for comprehensive meta-analysis
- **501 Cochrane pairwise datasets** (Pairwise70)
- **51+ NMA datasets** (NMA51)
- **100+ NMA networks** (NMArepo)
- **76 diagnostic test accuracy datasets** (DTA70)

**Total Value**: ~650+ datasets + 19 specialized apps = Industry-leading meta-analysis platform

---

## 1. Repository Audit - Completed ✓

### 1.1 Successfully Cloned Repositories

| Repository | Location | Description | Status |
|------------|----------|-------------|--------|
| **786-MIII-Meta-analysis** | `external_integrations/786-MIII-Meta-analysis/` | Main Shiny apps collection | ✓ Cloned |
| **Pairwise70** | Inside 786-MIII | 501 Cochrane datasets (R package) | ✓ Included |
| **NMA51** | `external_integrations/NMA51/` | 51 NMA datasets (R package) | ✓ Cloned |
| **NMArepo** | `external_integrations/NMArepo/` | Network meta-analysis datasets | ✓ Cloned |
| **DTA70** | Inside 786-MIII | Diagnostic test accuracy datasets | ✓ Included |

### 1.2 Shiny Apps Inventory (19 Apps)

#### AI-Powered Apps (3 apps)
1. **786MIIIBayesianLLM** - Bayesian meta-analysis with AI interpretation
2. **786MIIILLMresultsSMD** - GPT-powered SMD results interpretation
3. **786MIIIORRRLLM** - AI interpretation for OR/RR meta-analysis
4. **786MIINMALLM** - AI-powered NMA interpretation

#### Pairwise Meta-Analysis (4 apps)
5. **MIII786MasroorPairwiseRROR** - OR/RR pairwise meta-analysis (208KB - comprehensive)
6. **PairwiseSMD** - SMD pairwise meta-analysis (160KB)
7. **Hazard ratio meta app** - Time-to-event meta-analysis
8. **Prop app** - Proportions meta-analysis

#### Network Meta-Analysis (5 apps)
9. **786-MIIIRRORNMA** - ROR network meta-analysis
10. **786MIIIHRNMA** - Hazard ratio NMA
11. **786MIIINMAmetaregression** - NMA with meta-regression (124KB - advanced)
12. **NMA Bayseian SMD** - Bayesian NMA for SMD
13. **NMASMDMDFreqadvanced** - Advanced frequentist NMA

#### Specialized Apps (5 apps)
14. **DTA** - Diagnostic test accuracy meta-analysis
15. **Dose response app** - Dose-response meta-analysis
16. **KM curve project** - Kaplan-Meier curve extraction/meta-analysis
17. **Multilevel meta-analysis** - Multilevel/hierarchical meta-analysis
18. **786MIIIAnnualisedPlot** - Annualized event rate plots

#### Utility Apps (2 apps)
19. **786MIIIConversion** - Data format conversion tools
20. **Dataconversionmeta** - Meta-analysis data converters
21. **786MIIIROB** - Risk of bias assessment
22. **MedianIQRconversion** - Median/IQR to mean/SD conversion

### 1.3 Dataset Inventory

#### Pairwise70 (501 datasets)
- **Source**: Cochrane Systematic Reviews (CD000028 - CD016278)
- **Format**: R package with .rda files
- **Studies**: ~50,000+ individual RCTs
- **Data**: Binary outcomes (events/n) and continuous outcomes (mean/SD/n)
- **Status**: Ready for integration ✓

#### NMA51 (51+ datasets)
- **Source**: Network meta-analysis studies
- **Format**: R package structure
- **Data-raw**: 34 source files identified
- **Status**: Package structure present, needs dataset catalog ✓

#### NMArepo (100+ networks)
- **Source**: Comprehensive NMA dataset repository
- **Format**: R package with datasets.R
- **Status**: Ready for integration ✓

#### DTA70 (76 datasets)
- **Source**: Diagnostic test accuracy studies
- **Format**: R package
- **Status**: Included in 786-MIII repository ✓

---

## 2. Integration Architecture

### 2.1 Directory Structure

```
/home/user/Metanew/
├── external_integrations/
│   ├── 786-MIII-Meta-analysis/          # Main Shiny apps
│   │   ├── [19 Shiny app .R files]
│   │   └── external_integrations/       # Datasets included
│   │       ├── Pairwise70/             # 501 Cochrane datasets
│   │       ├── DTA70/                  # 76 DTA datasets
│   │       ├── NMA51/                  # 51 NMA datasets
│   │       └── NMArepo/                # 100+ NMA networks
│   ├── NMA51/                           # Standalone clone
│   └── NMArepo/                         # Standalone clone
│
├── docker/
│   ├── shiny-apps/                      # NEW: Shiny apps container
│   │   ├── Dockerfile
│   │   └── install_packages.R
│   └── shiny-proxy/                     # NEW: ShinyProxy config
│       └── application.yml
│
├── backend/api/
│   └── dataset_catalog.py              # NEW: Dataset catalog API
│
└── frontend/modules/
    └── dataset_browser.R                # NEW: Dataset browser UI
```

### 2.2 Component Design

#### A. Docker Container for Shiny Apps
- **Base Image**: `rocker/shiny:4.3.2`
- **R Packages**: metafor, netmeta, meta, gemtc, dosresmeta, etc.
- **LLM Integrations**: httr, jsonlite for OpenAI/Google APIs
- **Apps Location**: `/srv/shiny-server/`
- **Port**: 3838

#### B. ShinyProxy Multi-App Host
- **Container Orchestration**: Docker Swarm or Kubernetes
- **Network**: sp-net (isolated network)
- **Authentication**: LDAP/OAuth (optional)
- **App Isolation**: Each app in separate container instance

#### C. Dataset Catalog API
- **Framework**: FastAPI (Python)
- **Endpoints**:
  - `GET /datasets/pairwise` - List Pairwise70 datasets
  - `GET /datasets/nma` - List NMA datasets
  - `GET /datasets/dta` - List DTA datasets
  - `GET /datasets/{id}` - Get specific dataset metadata
  - `POST /datasets/{id}/load` - Load dataset into R format
- **Caching**: Redis for dataset metadata

#### D. Dataset Browser UI
- **Framework**: Shiny module
- **Features**:
  - Searchable/filterable dataset table
  - Preview dataset structure
  - Download datasets (CSV/RDA/JSON)
  - Launch appropriate meta-analysis app
  - View dataset provenance (DOI, citation)

---

## 3. Implementation Roadmap

### Phase 1: Docker Setup (Priority 1) ⏳
**Tasks**:
1. Create Dockerfile for Shiny apps
2. Install required R packages (metafor, netmeta, meta, etc.)
3. Copy 19 Shiny apps to container
4. Configure environment variables for API keys (GOOGLE_API_KEY, OPENAI_API_KEY)
5. Build and test Docker image

**Deliverables**:
- `docker/shiny-apps/Dockerfile`
- `docker/shiny-apps/install_packages.R`
- Working Docker image: `evidenceos/shiny-apps:latest`

### Phase 2: ShinyProxy Configuration (Priority 1) ⏳
**Tasks**:
1. Create ShinyProxy application.yml
2. Define 19 app specifications
3. Configure container networking
4. Set up authentication (optional)
5. Test multi-app deployment

**Deliverables**:
- `docker/shiny-proxy/application.yml`
- `docker/shiny-proxy/Dockerfile` (ShinyProxy server)
- `docker-compose.shinyproxy.yml`

### Phase 3: Dataset Catalog API (Priority 2)
**Tasks**:
1. Create FastAPI endpoints for dataset discovery
2. Parse Pairwise70/NMA51/NMArepo metadata
3. Implement dataset search/filter
4. Add dataset loading utilities
5. Cache dataset metadata in Redis

**Deliverables**:
- `backend/api/dataset_catalog.py`
- `backend/schemas/dataset.py`
- OpenAPI documentation at `/docs`

### Phase 4: Dataset Browser UI (Priority 2)
**Tasks**:
1. Create Shiny module for dataset browsing
2. Integrate with dataset catalog API
3. Add dataset preview functionality
4. Implement "Launch App" button for each dataset
5. Add download options (CSV/RDA/JSON)

**Deliverables**:
- `frontend/modules/dataset_browser.R`
- Integration into main Shiny UI

### Phase 5: Testing & Documentation (Priority 3)
**Tasks**:
1. Test all 19 Shiny apps individually
2. Test ShinyProxy multi-user access
3. Verify dataset loading from all sources
4. Create user documentation
5. Create admin deployment guide

**Deliverables**:
- Test results report
- `docs/SHINY_APPS_GUIDE.md`
- `docs/DATASET_CATALOG.md`
- `docs/DEPLOYMENT_SHINYPROXY.md`

---

## 4. Technical Specifications

### 4.1 Docker Image Requirements

#### Shiny Apps Image
```dockerfile
FROM rocker/shiny:4.3.2

# System dependencies
RUN apt-get update && apt-get install -y \\
    libcurl4-openssl-dev \\
    libssl-dev \\
    libxml2-dev \\
    libudunits2-dev \\
    libgdal-dev \\
    libgeos-dev \\
    libproj-dev

# R packages
RUN R -e "install.packages(c( \\
    'shiny', 'shinydashboard', 'DT', 'plotly', \\
    'metafor', 'netmeta', 'meta', 'gemtc', \\
    'dosresmeta', 'metaplus', 'metasens', \\
    'httr', 'jsonlite', 'devtools' \\
))"

# Install dataset packages
RUN R -e "devtools::install_github('Mahmood789/Pairwise70')"
RUN R -e "devtools::install_github('Mahmood789/NMA51')"

# Copy apps
COPY 786-MIII-Meta-analysis/*.R /srv/shiny-server/
```

### 4.2 ShinyProxy App Specification Template

```yaml
- id: app-name
  display-name: "App Display Name"
  description: "App description"
  container-cmd: ["R", "-e", "shiny::runApp('/srv/shiny-server/app.R', host='0.0.0.0', port=3838)"]
  container-image: evidenceos/shiny-apps:latest
  access-groups: [analysts, admins]
  container-network: sp-net
  container-env:
    GOOGLE_API_KEY: "${GOOGLE_API_KEY}"
    OPENAI_API_KEY: "${OPENAI_API_KEY}"
```

### 4.3 Dataset Catalog API Schema

```python
class Dataset(BaseModel):
    id: str
    name: str
    source: str  # "Pairwise70", "NMA51", "NMArepo", "DTA70"
    type: str  # "pairwise", "nma", "dta"
    n_studies: int
    outcome_type: str  # "binary", "continuous", "mixed"
    review_doi: Optional[str]
    description: Optional[str]
    created_at: datetime
```

---

## 5. App-to-Dataset Mapping

### Pairwise Apps → Pairwise70 Datasets (501 datasets)
- **MIII786MasroorPairwiseRROR** → Binary outcomes (OR/RR)
- **PairwiseSMD** → Continuous outcomes (SMD/MD)
- **Hazard ratio meta app** → Time-to-event outcomes
- **Prop app** → Proportions/rates

### NMA Apps → NMA51 + NMArepo Datasets (151 datasets)
- **786-MIIIRRORNMA** → ROR networks
- **786MIIIHRNMA** → Hazard ratio networks
- **NMA Bayseian SMD** → SMD networks (Bayesian)
- **NMASMDMDFreqadvanced** → SMD networks (Frequentist)
- **786MIIINMAmetaregression** → Networks with covariates

### Specialized Apps → Multiple Datasets
- **DTA** → DTA70 datasets (76 datasets)
- **Dose response app** → Dose-response datasets from Pairwise70
- **Multilevel meta-analysis** → Nested/hierarchical data from all sources

### AI Apps → All Datasets
- **786MIIIBayesianLLM** → Any dataset with AI interpretation
- **786MIIILLMresultsSMD** → SMD results (Pairwise70 + NMA)
- **786MIIIORRRLLM** → OR/RR results (Pairwise70)

---

## 6. Required R Packages

### Core Meta-Analysis
```r
install.packages(c(
  "metafor",      # Comprehensive meta-analysis
  "meta",         # Alternative meta-analysis
  "netmeta",      # Network meta-analysis (frequentist)
  "gemtc",        # Network meta-analysis (Bayesian)
  "dosresmeta",   # Dose-response meta-analysis
  "metaplus",     # Outlier detection
  "metasens"      # Sensitivity analysis
))
```

### Diagnostic Test Accuracy
```r
install.packages(c(
  "mada",         # Diagnostic meta-analysis
  "DTAplots"      # DTA visualizations
))
```

### Shiny & Visualization
```r
install.packages(c(
  "shiny", "shinydashboard", "bslib",
  "DT", "plotly", "ggplot2", "gridExtra"
))
```

### LLM Integration
```r
install.packages(c(
  "httr",         # HTTP requests to OpenAI/Google
  "jsonlite"      # JSON parsing
))
```

### Dataset Packages
```r
devtools::install_github("Mahmood789/Pairwise70")
devtools::install_github("Mahmood789/NMA51")
```

---

## 7. Environment Variables

### Required for AI-Powered Apps
```bash
# .env file
GOOGLE_API_KEY=your_google_gemini_api_key
OPENAI_API_KEY=your_openai_api_key
```

### ShinyProxy Configuration
```bash
SHINYPROXY_PORT=8080
DOCKER_NETWORK=sp-net
```

---

## 8. Deployment Options

### Option A: Docker Compose (Development/Small Teams)
```bash
cd /home/user/Metanew/docker
docker-compose -f docker-compose.shinyproxy.yml up -d
```

**Services**:
- ShinyProxy (port 8080)
- Redis (dataset cache)
- Nginx (reverse proxy)

### Option B: Kubernetes (Production/Enterprise)
- Deploy Shiny apps as Kubernetes Pods
- Use Ingress for routing
- Horizontal Pod Autoscaler for scaling
- Persistent volumes for datasets

### Option C: ShinyProxy Standalone
- Single ShinyProxy instance
- Docker containers for each app
- Suitable for 10-100 concurrent users

---

## 9. Performance Optimization

### Dataset Loading
- **Pre-load datasets**: Keep Pairwise70/NMA51 loaded in memory
- **Lazy loading**: Load datasets on-demand when app starts
- **Caching**: Cache frequently accessed datasets in Redis

### Container Optimization
- **Resource limits**: CPU (1-2 cores), Memory (2-4GB per app)
- **Container reuse**: Keep containers alive for 5 minutes after last use
- **Image optimization**: Multi-stage builds to reduce image size

---

## 10. Security Considerations

### API Key Management
- Store API keys in environment variables (not in code)
- Use Docker secrets or Kubernetes secrets
- Rotate keys regularly

### Network Isolation
- Shiny apps in isolated network (sp-net)
- Only ShinyProxy has external access
- No direct internet access from apps

### Data Privacy
- All datasets are public domain (Cochrane reviews)
- No patient-level data
- GDPR compliant

---

## 11. Success Metrics

### Integration Completion
- ✓ 19 Shiny apps deployed and accessible
- ✓ 501 Pairwise70 datasets available
- ✓ 51 NMA51 datasets available
- ✓ 100+ NMArepo datasets available
- ✓ 76 DTA70 datasets available
- ✓ Dataset catalog API functional
- ✓ Dataset browser UI integrated

### Performance Targets
- App launch time: <5 seconds
- Dataset loading: <2 seconds
- Concurrent users: 20+ per app
- Uptime: 99.5%

---

## 12. Next Steps

### Immediate Actions (Today)
1. ✓ Clone repositories - **COMPLETED**
2. ✓ Audit repository structure - **COMPLETED**
3. ⏳ Create Docker configuration - **IN PROGRESS**
4. ⏳ Create ShinyProxy configuration - **IN PROGRESS**

### This Week
5. Build Docker image for Shiny apps
6. Test 5 core apps individually
7. Deploy ShinyProxy with 5 apps
8. Create dataset catalog API (basic)

### Next Week
9. Deploy remaining 14 apps
10. Build dataset browser UI
11. Integration testing
12. Documentation

---

## 13. Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| R package dependencies conflicts | Medium | High | Use renv for package management |
| LLM API rate limits | High | Medium | Implement caching, rate limiting |
| Large dataset memory issues | Medium | High | Lazy loading, pagination |
| ShinyProxy configuration complexity | Low | Medium | Use docker-compose for dev, test thoroughly |
| App compatibility with EvidenceOS | Low | Low | Apps are standalone, minimal integration |

---

## 14. Maintenance Plan

### Weekly
- Monitor app performance metrics
- Check error logs
- Update dataset metadata cache

### Monthly
- Update R packages
- Review API key usage
- Test all apps end-to-end

### Quarterly
- Update datasets from Cochrane
- Add new apps from Mahmood789
- Performance optimization review

---

**Document Version**: 1.0
**Created**: 2025-11-04
**Last Updated**: 2025-11-04
**Status**: Active Development
**Owner**: EvidenceOS PRIME Team
