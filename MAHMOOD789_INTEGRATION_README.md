# Mahmood789 Repository Integration - Quick Start Guide

## Overview

This integration brings **19 production-ready Shiny apps** and **650+ meta-analysis datasets** into EvidenceOS PRIME, creating the most comprehensive meta-analysis platform available.

## What's Included

### 📊 Datasets (650+ total)

| Repository | Count | Description |
|------------|-------|-------------|
| **Pairwise70** | 501 | Cochrane pairwise meta-analyses |
| **NMA51** | 51 | Network meta-analysis datasets |
| **NMArepo** | 100+ | Additional NMA networks |
| **DTA70** | 76 | Diagnostic test accuracy studies |

### 🎯 Shiny Apps (19 total)

#### AI-Powered Apps (4)
- **AI-Powered Bayesian Analysis** - Bayesian MA with AI interpretation
- **AI Results Interpretation (SMD)** - GPT-powered SMD interpretation
- **AI Results Interpretation (OR/RR)** - AI-powered binary outcome interpretation
- **AI NMA Interpretation** - Network meta-analysis AI insights

#### Pairwise Meta-Analysis (4)
- **Pairwise OR/RR** - Odds ratio and risk ratio meta-analysis
- **Pairwise SMD** - Standardized mean difference
- **Hazard Ratio** - Time-to-event meta-analysis
- **Proportions** - Single-arm meta-analysis

#### Network Meta-Analysis (5)
- **NMA (ROR)** - Ratio of odds ratios network MA
- **NMA (HR)** - Hazard ratio network MA
- **NMA with Meta-Regression** - Advanced NMA with covariates
- **Bayesian NMA (SMD)** - Bayesian continuous outcome NMA
- **Frequentist NMA (SMD/MD)** - Advanced frequentist NMA

#### Specialized Apps (5)
- **Diagnostic Test Accuracy** - DTA meta-analysis
- **Dose-Response** - Non-linear dose-response curves
- **KM Curve Extraction** - Extract data from Kaplan-Meier curves
- **Multilevel Meta-Analysis** - Three-level hierarchical models
- **Annualised Event Rates** - Time-to-event visualizations

#### Utility Apps (4)
- **Data Format Converter** - Convert between MA formats
- **Effect Size Converter** - Convert between effect measures
- **Risk of Bias Assessment** - ROB visualization
- **Median/IQR Converter** - Statistical conversions

## Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Run the deployment script
cd /home/user/Metanew
./scripts/deploy_mahmood789_integration.sh
```

The script will:
1. Check prerequisites
2. Build Docker image
3. Test the deployment
4. Launch apps on http://localhost:3838

### Option 2: Manual Docker Build

```bash
# Build the image
cd /home/user/Metanew
docker build -f docker/shiny-apps/Dockerfile -t evidenceos/shiny-apps:latest .

# Run standalone
docker run -d -p 3838:3838 --name shiny-apps evidenceos/shiny-apps:latest

# Access at http://localhost:3838
```

### Option 3: ShinyProxy Multi-App Hosting

```bash
# Start ShinyProxy with all apps
cd /home/user/Metanew
docker-compose -f docker-compose.shinyproxy.yml up -d

# Access at http://localhost:8080
# Default credentials: admin / changeme
```

## Configuration

### API Keys for AI Apps

Set environment variables for AI-powered features:

```bash
export GOOGLE_API_KEY="your_google_gemini_key"
export OPENAI_API_KEY="your_openai_key"
```

Or in docker-compose.yml:

```yaml
environment:
  - GOOGLE_API_KEY=your_key_here
  - OPENAI_API_KEY=your_key_here
```

### ShinyProxy Settings

Edit `docker/shiny-proxy/application.yml` to configure:
- Authentication (LDAP, OAuth, etc.)
- User access controls
- Resource limits per app
- Container settings

## Using the Dataset Catalog

### API Endpoints

The dataset catalog API provides programmatic access to all datasets:

```bash
# List all datasets
curl http://localhost:8000/datasets/

# Get summary statistics
curl http://localhost:8000/datasets/summary

# Filter by source
curl http://localhost:8000/datasets/?source=Pairwise70

# Search datasets
curl http://localhost:8000/datasets/search/aspirin

# Get specific dataset
curl http://localhost:8000/datasets/CD002042_pub6_data

# Get recommended apps
curl http://localhost:8000/datasets/CD002042_pub6_data/apps
```

### Shiny UI Integration

The dataset browser is integrated into the main EvidenceOS frontend:

```r
# In your Shiny app
source("frontend/modules/dataset_browser.R")

# UI
dataset_browser_ui("browser")

# Server
dataset <- dataset_browser_server("browser", api_base_url = "http://localhost:8000")
```

## App Access URLs

### Standalone Mode (port 3838)

All apps are available at: `http://localhost:3838/[app-name]/`

Example:
- http://localhost:3838/786MIIIBayesianLLM/
- http://localhost:3838/PairwiseSMD/

### ShinyProxy Mode (port 8080)

Apps are accessed through ShinyProxy UI: http://localhost:8080

Each app has a unique URL like:
- http://localhost:8080/app/ai-bayesian
- http://localhost:8080/app/pairwise-smd

## Loading Datasets in Apps

### Pairwise70 Datasets

```r
# Load the package
library(Pairwise70)

# List all datasets
data(package = "Pairwise70")

# Load a specific dataset
data(CD002042_pub6_data)

# Use in metafor
library(metafor)
res <- rma(measure = "OR",
           ai = Experimental.cases,
           n1i = Experimental.N,
           ci = Control.cases,
           n2i = Control.N,
           data = CD002042_pub6_data)
```

### NMA51 Datasets

```r
# Load from data files
nma_data <- readRDS("/path/to/NMA51/data-raw/dataset.rds")

# Or use nmadatasets package
library(nmadatasets)
```

## Troubleshooting

### Docker Build Issues

If build fails:

```bash
# Check Docker logs
docker logs evidenceos-shiny-apps

# Rebuild without cache
docker build --no-cache -f docker/shiny-apps/Dockerfile -t evidenceos/shiny-apps:latest .
```

### App Not Loading

1. Check container is running: `docker ps`
2. Check logs: `docker logs evidenceos-shiny-apps`
3. Verify port mapping: `docker port evidenceos-shiny-apps`
4. Test Shiny Server: `curl http://localhost:3838/`

### Missing R Packages

The Dockerfile installs all required packages. If an app fails:

```bash
# Enter the container
docker exec -it evidenceos-shiny-apps bash

# Install missing package
R -e "install.packages('package_name')"
```

### Dataset Not Found

1. Verify dataset exists: `ls external_integrations/*/data/`
2. Check API response: `curl http://localhost:8000/datasets/summary`
3. Re-scan datasets by restarting API

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ShinyProxy (Port 8080)                    │
│              Multi-User App Hosting & Authentication         │
└───────────────────────────────┬─────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
    ┌───────────▼──────────┐       ┌───────────▼──────────┐
    │  Shiny Apps Container │       │  FastAPI Backend     │
    │  (Port 3838)          │       │  (Port 8000)         │
    │                       │       │                      │
    │  - 19 Shiny Apps      │◄──────┤  - Dataset Catalog   │
    │  - 650+ Datasets      │       │  - Meta-analysis API │
    └───────────────────────┘       └──────────────────────┘
```

## Performance Tuning

### Resource Limits

Adjust container resources in `application.yml`:

```yaml
container-memory-limit: 4G    # Increase for large NMAs
container-cpu-limit: 2.0      # More CPUs for Bayesian apps
```

### Concurrent Users

ShinyProxy spawns separate containers per user:
- Light apps (utilities): 10-20 concurrent users per host
- Heavy apps (NMA, Bayesian): 5-10 concurrent users per host

### Dataset Caching

Enable Redis caching for dataset metadata:

```bash
# Start Redis
docker run -d -p 6379:6379 redis:alpine

# Configure in FastAPI
REDIS_URL=redis://localhost:6379
```

## Production Deployment

### Security

1. **Change default passwords** in `application.yml`
2. **Enable HTTPS** with reverse proxy (Nginx/Traefik)
3. **Set up authentication** (LDAP, OAuth, SAML)
4. **Secure API keys** using Docker secrets
5. **Network isolation** - use Docker networks

### Scaling

1. **Kubernetes**: Deploy apps as Pods
2. **Load balancing**: Use Nginx/HAProxy
3. **Horizontal scaling**: Add more ShinyProxy instances
4. **Persistent storage**: Mount volumes for user data

### Monitoring

```bash
# View logs
docker logs -f evidenceos-shiny-apps

# Monitor resource usage
docker stats evidenceos-shiny-apps

# Health check
curl http://localhost:3838/
```

## Support

- **Integration Plan**: `/home/user/Metanew/INTEGRATION_PLAN.md`
- **API Documentation**: http://localhost:8000/docs
- **Deployment Script**: `scripts/deploy_mahmood789_integration.sh`

## Changelog

### v1.0.0 (2025-11-04)

- ✅ Integrated 786-MIII-Meta-analysis (19 apps)
- ✅ Integrated Pairwise70 (501 datasets)
- ✅ Integrated NMA51 (51 datasets)
- ✅ Integrated NMArepo (100+ datasets)
- ✅ Integrated DTA70 (76 datasets)
- ✅ Created Docker configuration
- ✅ Created ShinyProxy setup
- ✅ Built dataset catalog API
- ✅ Built dataset browser UI
- ✅ Created deployment automation

## License

- **Shiny Apps**: See original Mahmood789 repositories
- **Datasets**:
  - Pairwise70: MIT License + Cochrane data terms
  - NMA51: Check package license
  - NMArepo: Check package license
  - DTA70: Check package license

## Acknowledgments

- **Mahmood Arai** (Mahmood789) - Original app and dataset author
- **Cochrane Collaboration** - Source of Pairwise70 systematic reviews
- **EvidenceOS PRIME Team** - Integration and deployment

---

**🚀 Ready to deploy? Run: `./scripts/deploy_mahmood789_integration.sh`**
