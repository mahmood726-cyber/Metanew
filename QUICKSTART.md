# Quick Start Guide - EvidenceOS PRIME

## 5-Minute Setup

### Option 1: GitHub Codespaces (Fastest)

```bash
# 1. Click "Code" → "Create codespace on [branch]"
# 2. Wait for container to build (~5 minutes first time)
# 3. Run in terminal:
docker-compose up -d

# 4. Click on forwarded ports in VS Code
# Shiny App: Port 3838
# AI Copilot API: Port 8001
```

### Option 2: Docker (Local Development)

```bash
# 1. Clone the repository
git clone https://github.com/your-org/evidenceos-prime.git
cd evidenceos-prime

# 2. Start the application
docker-compose up -d

# 3. Wait 30 seconds for services to start

# 4. Open your browser
# Shiny App: http://localhost:3838
# AI Copilot API: http://localhost:8001/docs
```

### Option 3: Docker (Legacy - Single Container)

```bash
# 1. Navigate to docker directory
cd docker

# 2. Start the application
docker-compose up -d

# 3. Wait 30 seconds for services to start

# 4. Open your browser
# Shiny App: http://localhost:3838
# Main API: http://localhost:8000/docs
```

### Option 4: Local Development (No Docker)

**Terminal 1 - Python Backend:**
```bash
cd backend
pip install -r requirements.txt
cd api
python main.py
```

**Terminal 2 - R Shiny:**
```R
# In R console
setwd("frontend")
shiny::runApp(port = 3838)
```

---

## First Analysis (10 Minutes)

### 1. Load Sample Data
1. Open http://localhost:3838
2. Go to "Data" tab
3. Click "Choose CSV or Excel file"
4. Select `data/sample_binary.csv`
5. Click "Validate Data"
6. Click "Compute Effect Sizes" (if needed)

### 2. Run Meta-Analysis
1. Go to "Analysis" → "Pairwise MA"
2. Select Outcome: "Mortality"
3. Method: "REML"
4. Click "Run Analysis"
5. View forest plot, funnel plot, and summary statistics

### 3. Generate Report
1. Go to "Reports" tab
2. Enter report title: "My First Meta-Analysis"
3. Select format: "Word"
4. Select sections to include
5. Click "Generate Report"
6. Find report in `outputs/` directory

---

## Sample Workflows

### Workflow 1: Standard Pairwise MA

```
Data Import → Validation → Compute Yi →
Pairwise MA → Forest Plot → Generate Report
```

**Time:** <5 minutes

### Workflow 2: Network Meta-Analysis

```
Data Import (multi-arm) → Validation →
NMA Setup → Run NMA → League Table →
Rankings → Generate Report
```

**Time:** ~10 minutes

### Workflow 3: Full HTA Analysis

```
Data Import → Protocol Entry → Pairwise MA →
Extract HR → HE Parameters → Run Markov Model →
PSA → BCEA Analysis → Generate HTA Dossier
```

**Time:** ~20 minutes

---

## Sample Data Files

- `data/sample_binary.csv` - Binary outcomes (OR/RR)
- `data/sample_continuous.csv` - Continuous outcomes (MD/SMD)
- `data/sample_tte.csv` - Time-to-event (HR)

---

## Common Issues

### Port Already in Use
```bash
# Change ports in docker-compose.yml
ports:
  - "3839:3838"  # Change 3838 to 3839
  - "8001:8000"  # Change 8000 to 8001
```

### API Not Connecting
```bash
# Check API is running
curl http://localhost:8000/health

# Restart Docker container
docker-compose restart
```

### Missing R Packages
```R
# Install all required packages
source("install_packages.R")
```

---

## Next Steps

1. Read full documentation in README.md
2. Try sensitivity analysis with sample data
3. Customize report templates in `frontend/templates/`
4. Add your own data
5. Configure country-specific HE parameters

---

## Support

- Documentation: See README.md
- Issues: https://github.com/your-org/evidenceos-prime/issues
- Email: support@evidenceos.com

---

**Happy Analyzing! 🎉**
