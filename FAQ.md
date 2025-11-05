# EvidenceOS PRIME - Frequently Asked Questions

**Last Updated:** 2025-01-05
**Version:** 2.0

---

## 📚 Table of Contents

1. [General Questions](#general-questions)
2. [Getting Started](#getting-started)
3. [ML/AI Features](#mlai-features)
4. [Technical Questions](#technical-questions)
5. [Troubleshooting](#troubleshooting)
6. [Data Privacy & Security](#data-privacy--security)
7. [Performance & Optimization](#performance--optimization)

---

## General Questions

### What is EvidenceOS PRIME?

EvidenceOS PRIME is an advanced platform for systematic reviews and meta-analyses, featuring world-class ML/AI capabilities for evidence synthesis, prediction, and decision support.

**Key Features:**
- 📊 Meta-analysis with advanced statistics
- 🤖 ML-powered predictions (XGBoost, LightGBM, CatBoost)
- 🔍 Explainable AI (SHAP, LIME)
- 💬 RAG-based literature Q&A
- ⚡ AutoML with Bayesian optimization
- 🚀 10-100x faster with Redis caching

### Who should use EvidenceOS PRIME?

- **Researchers** conducting systematic reviews and meta-analyses
- **Healthcare decision makers** evaluating treatment effectiveness
- **Meta-analysts** seeking ML-powered insights
- **Evidence synthesis teams** needing efficient workflows
- **Regulatory bodies** requiring rigorous analysis

### Do I need coding skills?

**No!** All features are accessible through an intuitive web interface. No Python, R, or command-line knowledge required.

### Is EvidenceOS PRIME free?

The core platform is open-source (MIT license). Advanced features and support options available for enterprise users.

---

## Getting Started

### How do I install EvidenceOS PRIME?

**Option 1: Docker (Recommended)**
```bash
git clone https://github.com/your-org/evidenceos-prime
cd evidenceos-prime
docker-compose up
```

**Option 2: Manual Installation**
See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed instructions.

### What are the system requirements?

**Minimum:**
- 4 GB RAM
- 2 CPU cores
- 10 GB disk space
- Docker 20.10+ or Python 3.10+

**Recommended:**
- 8 GB RAM
- 4 CPU cores
- 50 GB disk space
- Redis for caching

### How long does setup take?

- **Docker setup:** 5-10 minutes (including download)
- **Manual setup:** 15-30 minutes
- **First-time data upload:** 2-5 minutes

### Where can I find tutorials?

- **User Guide:** [ML_USER_GUIDE.md](ML_USER_GUIDE.md)
- **Video tutorials:** Available in `/docs/videos/`
- **Example datasets:** Available in `/data/examples/`

---

## ML/AI Features

### Which ML models are available?

**Gradient Boosting Models:**
- **XGBoost** - Best all-around, handles missing data
- **LightGBM** - Fastest, ideal for large datasets
- **CatBoost** - Best for categorical features

**Ensemble Strategies:**
- Single model
- Voting (average predictions)
- Stacking (meta-learner combines models)

### How do I choose the right model?

| Dataset Size | Recommended Model | Reason |
|--------------|-------------------|--------|
| <100 samples | XGBoost | Best with small data |
| 100-1,000 | XGBoost or CatBoost | Balanced |
| >1,000 | LightGBM | Fastest |
| Many categories | CatBoost | Native categorical support |

### What's the difference between SHAP and LIME?

**SHAP** (SHapley Additive exPlanations):
- ✅ Theoretically grounded (game theory)
- ✅ Consistent across models
- ⏱️ Slower computation
- 🎯 Global and local explanations

**LIME** (Local Interpretable Model-agnostic Explanations):
- ✅ Model-agnostic
- ✅ Faster computation
- ⏱️ Can be inconsistent
- 🎯 Local explanations only

**Recommendation:** Use both and ensure they agree on top features.

### How long does AutoML take?

- **20 trials:** 30-40 minutes
- **50 trials:** 1-2 hours
- **100 trials:** 2-4 hours

**Factors affecting speed:**
- Dataset size
- Number of features
- Models being optimized
- Hardware (CPU vs GPU)

### Can I use my own models?

Yes! You can:
1. Import pretrained models (`.pkl` format)
2. Register custom models in the model registry
3. Use models for predictions and explainability

---

## Technical Questions

### What programming languages are used?

**Backend:**
- Python 3.11 (ML, API, data processing)
- FastAPI (web framework)

**Frontend:**
- R (Shiny framework)
- JavaScript (UI enhancements)

**Infrastructure:**
- Docker & Docker Compose
- Redis (caching)
- PostgreSQL (database)

### Can I run this on my laptop?

Yes! EvidenceOS PRIME runs on:
- **MacOS** (M1/M2 or Intel)
- **Windows** (10/11)
- **Linux** (Ubuntu 20.04+, Debian, Fedora)

**Minimum specs:** 4 GB RAM, 2 cores, 10 GB disk

### Does it require internet?

**No!** EvidenceOS PRIME runs entirely offline:
- ✅ All ML processing is local
- ✅ RAG uses local Llama 3 models
- ✅ No external API calls
- ✅ Perfect for sensitive data

**Optional internet for:**
- Downloading Docker images (first time)
- Installing dependencies
- Fetching study metadata from PubMed (optional feature)

### How is caching implemented?

**Redis Caching:**
- Automatic caching of expensive operations
- Configurable TTL (Time To Live)
- 10-100x speed improvement
- Graceful fallback if Redis unavailable

**Cache Durations:**
- Predictions: 1 hour
- Recommendations: 30 minutes
- RAG queries: 1 hour
- SHAP/LIME: 2 hours

### Can I use this in production?

**Yes!** EvidenceOS PRIME is production-ready:
- ✅ Comprehensive testing (250+ tests, 40% coverage)
- ✅ Docker containerization
- ✅ Health checks and monitoring
- ✅ CI/CD pipeline (GitHub Actions)
- ✅ Security scanning (Bandit, Safety)
- ✅ Scalable architecture

---

## Troubleshooting

### "Model training failed"

**Likely causes:**
1. Insufficient data (<50 rows)
2. Missing target variable
3. Non-numeric features
4. Too many missing values (>80%)

**Solutions:**
```bash
# Check data format
head -20 your_data.csv

# Ensure numeric features
# Remove rows with excessive missing values
# Verify target variable exists
```

### "Redis connection failed"

**Cause:** Redis server not running

**Solution:**
```bash
# Start Redis
redis-server

# Or using Docker
docker run -d -p 6379:6379 redis:7-alpine

# Verify
redis-cli ping
# Should return: PONG
```

### "Out of memory" errors

**Causes:**
1. Dataset too large
2. Too many models in ensemble
3. AutoML with too many trials

**Solutions:**
- Use LightGBM (most memory-efficient)
- Reduce number of features
- Use subset of data for initial exploration
- Decrease AutoML trials

### Slow predictions

**Cause:** Caching not enabled

**Solution:**
```bash
# 1. Start Redis
redis-server

# 2. Check cache stats in UI
# Navigate to ML/AI → Settings → Cache Stats

# 3. Verify Redis connection
curl http://localhost:8000/health/ml
```

### RAG answers are irrelevant

**Causes:**
1. Poor retrieval (wrong mode)
2. Insufficient context in abstracts
3. Studies not relevant to question

**Solutions:**
- Use **Hybrid** mode instead of TF-IDF
- Upload complete abstracts (not just titles)
- Rephrase question with more specific terms
- Verify studies are relevant

### Docker build fails

**Common issues:**

**Issue 1: Port already in use**
```bash
# Find process using port 8000
lsof -i :8000

# Kill process
kill -9 <PID>
```

**Issue 2: Disk space**
```bash
# Check disk space
df -h

# Clean Docker
docker system prune -a
```

**Issue 3: Memory limit**
```bash
# Increase Docker memory
# Docker Desktop → Settings → Resources → Memory (8 GB)
```

---

## Data Privacy & Security

### Is my data secure?

**Yes!** Security features:
- ✅ All processing is local (no cloud uploads)
- ✅ No external API calls
- ✅ Data never leaves your infrastructure
- ✅ HTTPS encryption available
- ✅ Authentication & authorization (enterprise version)

### Can I use this for HIPAA-compliant projects?

**Yes!** EvidenceOS PRIME can be HIPAA-compliant because:
- All data stays on your servers
- No external data transmission
- Audit logging available
- Access controls supported

**Note:** Consult your compliance officer for final approval.

### Where is my data stored?

**Local storage locations:**
- Study data: `/data/studies/`
- Models: `/data/model_registry/`
- Cache: Redis (in-memory + persistence)
- Logs: `/logs/`

**Database:** PostgreSQL (configurable location)

### Can I delete my data?

**Yes!** You have full control:
```bash
# Delete specific study data
rm -rf data/studies/study_id_*

# Clear cache
redis-cli FLUSHALL

# Delete models
rm -rf data/model_registry/*
```

---

## Performance & Optimization

### How can I speed up predictions?

1. **Enable Redis caching**
   - 10-100x speedup for repeated queries
   - Install: `docker run -d -p 6379:6379 redis:7-alpine`

2. **Use appropriate model**
   - LightGBM for large datasets
   - XGBoost for small/medium datasets

3. **Reduce features**
   - Use only informative features
   - Remove highly correlated features (r > 0.9)

4. **Optimize hardware**
   - Use SSD instead of HDD
   - Add more RAM (8 GB recommended)
   - Use GPU for neural embeddings (optional)

### How can I optimize AutoML?

**Faster AutoML:**
- Reduce trials (20 instead of 50)
- Optimize fewer models (1-2 instead of 3)
- Use smaller dataset for exploration
- Use LightGBM (fastest model)

**Better results:**
- Increase trials (50-100)
- Use all 3 models
- Use complete dataset
- Use longer timeout per trial

### What's the maximum dataset size?

**Depends on available RAM:**
- **4 GB RAM:** Up to 50,000 studies
- **8 GB RAM:** Up to 200,000 studies
- **16 GB RAM:** Up to 1 million studies

**For larger datasets:**
- Use LightGBM (most efficient)
- Process in batches
- Consider distributed computing

### How can I monitor performance?

**Built-in monitoring:**
```bash
# Health check
curl http://localhost:8000/health/detailed

# Cache stats
curl http://localhost:8000/ml/cache/stats

# System metrics
docker stats
```

**Production monitoring (enterprise):**
- Prometheus metrics
- Grafana dashboards
- Alerting via email/Slack

---

## Getting Help

### Where can I report bugs?

**GitHub Issues:** https://github.com/your-org/evidenceos-prime/issues

**Include:**
1. Error message
2. Steps to reproduce
3. System info (`python --version`, `docker --version`)
4. Logs (`logs/ml.log`)

### How can I request features?

**GitHub Discussions:** https://github.com/your-org/evidenceos-prime/discussions

**Feature request template:**
1. Use case
2. Expected behavior
3. Why it would be valuable
4. Mockups/examples (if applicable)

### Is there a community forum?

**Yes!**
- **Discord:** https://discord.gg/evidenceos
- **Slack:** https://evidenceos.slack.com
- **GitHub Discussions:** For long-form discussions

### Can I get professional support?

**Enterprise support available:**
- Priority bug fixes
- Custom feature development
- Training & onboarding
- Dedicated support channel

Contact: support@evidenceos.com

---

## Additional Resources

### Documentation
- [ML User Guide](ML_USER_GUIDE.md) - Comprehensive guide to ML features
- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Installation & setup
- [Production Runbook](PRODUCTION_RUNBOOK.md) - Production deployment
- [Testing Guide](backend/docs/TESTING_GUIDE.md) - Running tests
- [Caching Guide](backend/docs/CACHING_GUIDE.md) - Performance optimization

### Tutorials
- Video: "Getting Started with EvidenceOS" (15 min)
- Video: "ML Features Deep Dive" (30 min)
- Video: "AutoML Optimization Tutorial" (20 min)

### Scientific Papers
- [XGBoost](https://arxiv.org/abs/1603.02754) - Chen & Guestrin, 2016
- [SHAP](https://arxiv.org/abs/1705.07874) - Lundberg & Lee, 2017
- [LIME](https://arxiv.org/abs/1602.04938) - Ribeiro et al., 2016

---

**Last Updated:** 2025-01-05
**Version:** 2.0
**License:** MIT

For more help, visit our [documentation](https://docs.evidenceos.com) or join our [community](https://discord.gg/evidenceos).
