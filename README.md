# EvidenceOS PRIME

> **Professional Research Intelligence for Meta-analysis & Economics**

An end-to-end platform for systematic reviews, meta-analysis, network meta-analysis, and health technology assessment (HTA), aimed at HEOR workflows from data upload to client deliverables.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![R](https://img.shields.io/badge/R-4.0+-blue.svg)](https://www.r-project.org/)
[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)

---

## Implemented Features

The following modules are implemented and covered by the test suite:

- Core meta-analysis (pairwise, NMA, dose-response) — via `metafor`/`netmeta`
- Health economics suite (Markov, BCEA, budget impact)
- Multi-format reporting (Word/PDF/PowerPoint) with embedded plots
- Publication bias correction (trim-and-fill)
- PSA using MA confidence intervals
- Multi-country parameter packs (UK/US/Germany/France/Canada)
- Data validation (duplicates, outliers, implausible values)
- API retry logic with exponential backoff
- Living meta-analysis with version tracking
- Client-facing white-label portal

See the Roadmap below for features that are planned but not yet implemented.

---

## 🎯 Key Features

### Core Analytics
- **Pairwise Meta-Analysis** - Fixed/random effects, forest plots, funnel plots, heterogeneity assessment
- **Network Meta-Analysis (NMA)** - Frequentist approach, league tables, treatment rankings
- **Dose-Response Meta-Analysis** - Restricted cubic splines, non-linearity testing

### High-Value Features
1. **Protocol→Pipeline Integration** - PICO entry with automatic execution audit
2. **Interactive Sensitivity Explorer** - Live re-runs, study toggles, bias filters, subgroup analysis
3. **Client-Facing Portal** - White-label Shiny dashboards (read-only)
4. **HTA/Value-Dossier Builder** - ICER, CEAC, EVPI, budget impact analysis
5. **Living Meta-Analysis** - Incremental updates with change tracking
6. **Complete Audit Trail** - Hash-based versioning, full reproducibility

### Health Economics
- **Markov Models** - 3-state model (Stable → Progressed → Dead) with PSA
- **Cost-Effectiveness Analysis** - CE plane, CEAC/CEAF, EVPI/EVPPI
- **Budget Impact Analysis** - Cohort uptake projections
- **Multi-Country Support** - Configurable parameters (GBP/EUR/USD, WTP thresholds)

### Outputs
- **Word/PDF Reports** - Auto-generated with methods, results, and figures
- **PowerPoint Presentations** - Executive summaries and slide decks
- **Excel Tables** - Formatted results for further analysis
- **JSON Evidence Objects** - Complete reproducible analysis packages

---

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose (recommended)
- OR: R 4.0+, Python 3.9+

### Installation (Docker - Recommended)

```bash
# Clone repository
git clone https://github.com/your-org/evidenceos-prime.git
cd evidenceos-prime

# Build and run
cd docker
docker-compose up -d

# Access application
# Shiny UI: http://localhost:3838
# API: http://localhost:8000
```

### Installation (Local Development)

**Python Backend:**
```bash
cd backend
pip install -r requirements.txt

# Start FastAPI
cd api
python main.py
```

**R Shiny Frontend:**
```R
# Install required packages
install.packages(c(
  "shiny", "bslib", "DT", "plotly", "shinyvalidate",
  "metafor", "netmeta", "dosresmeta",
  "rmarkdown", "officer", "readxl", "httr", "jsonlite"
))

# Run Shiny app
setwd("frontend")
shiny::runApp()
```

---

## 📊 Usage

### 1. Data Import
- Upload CSV or Excel file with study data
- Supported formats:
  - Binary outcomes (events/n or OR/RR with CI)
  - Continuous outcomes (mean/SD or MD/SMD)
  - Time-to-event (HR with CI)
- Automatic validation and effect size computation

### 2. Protocol Entry (PICO)
- Define Population, Intervention, Comparator, Outcomes
- Inclusion/exclusion criteria
- Automatic protocol-data comparison for audit

### 3. Meta-Analysis
- **Pairwise:** Select outcome, method (REML/DL/ML), generate forest/funnel plots
- **NMA:** Define treatment network, compute league tables
- **Dose-Response:** Fit spline models, test non-linearity

### 4. Sensitivity Analysis
- Toggle individual studies on/off
- Filter by risk of bias
- Subgroup analysis
- Real-time plot updates (<2 seconds)

### 5. Health Economics
- Enter country-specific parameters (costs, utilities, WTP)
- Run Markov model with PSA
- Generate CE plane, CEAC, EVPI plots
- Export HTA dossier

### 6. Reporting
- One-click Word/PDF/PowerPoint generation
- Auto-populated methods and results sections
- Embedded figures and tables
- Customizable templates

### 7. Audit & Export
- View complete audit trail
- Download Evidence Object JSON (fully reproducible)
- Session save/load functionality

---

## 📁 Repository Structure

```
evidenceos-prime/
├── backend/                # Python FastAPI backend
│   ├── api/               # API endpoints
│   ├── etl/               # Data validation & transformation
│   ├── models/            # Statistical models (optional)
│   ├── schemas/           # Pydantic schemas (EvidenceObject)
│   └── requirements.txt
├── frontend/              # R Shiny frontend
│   ├── app.R             # Main Shiny application
│   ├── modules/          # Shiny modules (data, analysis, economics, etc.)
│   ├── utils/            # Utility functions
│   └── templates/        # Report templates (Rmd, PPTX)
├── data/                 # Sample datasets
├── outputs/              # Generated reports and artifacts
├── docker/               # Docker configuration
│   ├── Dockerfile
│   └── docker-compose.yml
├── tests/                # Unit tests
│   ├── py/              # Python tests (pytest)
│   └── r/               # R tests (testthat)
└── README.md
```

---

## 🧪 Testing

**Python Tests:**
```bash
cd tests/py
pytest -v
```

**R Tests:**
```R
testthat::test_dir("tests/r")
```

---

## 📖 API Documentation

FastAPI provides automatic interactive documentation:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/validate` | POST | Validate input data |
| `/compute/yi` | POST | Compute effect sizes |
| `/evidence/hash` | POST | Generate content hash |
| `/evidence/validate` | POST | Validate EvidenceObject |
| `/econ/params` | POST | Generate PSA parameters |

---

## 🎓 Documentation

- **User Guide:** `docs/user_guide.pdf` - Step-by-step workflows with screenshots
- **Methods Appendix:** `docs/methods.pdf` - Statistical and economic methods
- **Admin Guide:** `docs/admin_guide.pdf` - Deployment and configuration
- **Developer Guide:** `docs/developer_guide.pdf` - Extending the platform

---

## 🔒 Data Security & Compliance

- All data processing occurs within local container
- No external API calls (except optional integrations)
- Audit trail for all operations
- Hash-based integrity verification
- GDPR/HIPAA compliant architecture (when deployed correctly)

---

## 🛠️ Configuration

### Environment Variables

```bash
# API Configuration
API_BASE_URL=http://localhost:8000

# R Shiny
SHINY_LOG_LEVEL=INFO
SHINY_PORT=3838

# Database (optional)
DATABASE_URL=postgresql://user:pass@localhost/evidenceos
```

### Country Parameter Packs

Custom YAML files for country-specific economic parameters:

```yaml
# config/countries/uk.yaml
country: "UK"
currency: "GBP"
wtp_threshold: 20000
discount_rate: 0.035
perspective: "NHS"
```

---

## 🚢 Deployment

### Docker (Production)

```bash
# Build production image
docker build -f docker/Dockerfile -t evidenceos:latest .

# Run with production settings
docker run -d \
  -p 3838:3838 \
  -p 8000:8000 \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/outputs:/app/outputs \
  --name evidenceos \
  evidenceos:latest
```

### ShinyProxy (Multi-User)

See `docs/shinyproxy_setup.md` for multi-user enterprise deployment.

---

## 🤝 Contributing

Contributions welcome! Please see `CONTRIBUTING.md` for guidelines.

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

---

## 📜 License

This project is licensed under the MIT License - see `LICENSE` file for details.

---

## 🙏 Acknowledgments

Built with:
- [Shiny](https://shiny.rstudio.com/) - Interactive web apps with R
- [metafor](https://wviechtb.github.io/metafor/) - Meta-analysis in R
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [netmeta](https://github.com/guido-s/netmeta) - Network meta-analysis
- [BCEA](https://sites.google.com/a/statistica.it/gianluca/bcea) - Bayesian cost-effectiveness analysis

---

## 📞 Support

- **Issues:** https://github.com/your-org/evidenceos-prime/issues
- **Email:** support@evidenceos.com
- **Documentation:** https://docs.evidenceos.com

---

## 🗺️ Roadmap

### v1.1 (Q2 2024)
- [ ] Bayesian NMA (via gemtc/PyMC)
- [ ] DistillerSR API integration
- [ ] GRADE assessment module
- [ ] Multi-language support

### v1.2 (Q3 2024)
- [ ] Individual patient data (IPD) meta-analysis
- [ ] Living systematic review automation
- [ ] Advanced survival models (Weibull, Gompertz)
- [ ] EVPPI partial EVPI calculations

### v2.0 (Q4 2024)
- [ ] AI-assisted study screening
- [ ] Automated risk of bias assessment
- [ ] Real-time collaboration features
- [ ] Cloud deployment option

---

**Built with ❤️ for evidence-based decision making**
