# GitHub Codespaces Setup Guide

This project is now configured for **instant startup in GitHub Codespaces**! 🚀

## Quick Start (3 Simple Steps)

### 1. Open in Codespaces
Click the "Code" button on GitHub → "Codespaces" → "Create codespace on [your-branch]"

### 2. Wait for Automatic Setup
The devcontainer will automatically:
- Install Python 3.11 and R 4.3
- Install all Python dependencies (FastAPI, pandas, etc.)
- Install all R packages (shiny, metafor, netmeta, BCEA, etc.)
- Set up directories and permissions
- Start all services automatically

⏱️ **First-time setup takes ~5-10 minutes** (subsequent starts are instant)

### 3. Access the Application
Once setup completes, you'll see:
- **Shiny App**: Click the notification to open http://localhost:3838
- **AI Copilot API**: http://localhost:8001/docs
- **Legacy API**: http://localhost:8000/docs

---

## Manual Control (Optional)

### Start Services Manually
```bash
bash .devcontainer/start.sh
```

### Stop All Services
```bash
pkill -f uvicorn && pkill -f shiny
```

### View Logs
```bash
# AI Copilot Backend
tail -f outputs/ai-backend.log

# Legacy Backend
tail -f outputs/backend.log

# Shiny Frontend
tail -f outputs/shiny.log
```

### Restart Individual Services

**Restart AI Backend:**
```bash
cd backend/api
uvicorn nlq:app --host 0.0.0.0 --port 8001 --reload
```

**Restart Legacy Backend:**
```bash
cd backend/api
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**Restart Shiny:**
```bash
cd frontend
R -e "shiny::runApp(port=3838, host='0.0.0.0')"
```

---

## What's Running?

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Shiny Frontend | 3838 | http://localhost:3838 | Main web interface |
| AI Copilot API | 8001 | http://localhost:8001/docs | Natural language queries, intelligent suggestions |
| Legacy API | 8000 | http://localhost:8000/docs | Data validation, effect size computation |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│         Shiny Frontend (R)                   │
│         Port 3838                            │
│  - Interactive dashboards                    │
│  - Meta-analysis workflows                   │
│  - Health economics models                   │
└───────────────┬─────────────────────────────┘
                │
                ├──────────────┬───────────────┐
                │              │               │
        ┌───────▼───────┐ ┌───▼──────────┐   │
        │ AI Copilot    │ │ Legacy API   │   │
        │ FastAPI       │ │ FastAPI      │   │
        │ Port 8001     │ │ Port 8000    │   │
        │ - NLQ         │ │ - Validation │   │
        │ - Suggestions │ │ - Compute    │   │
        └───────────────┘ └──────────────┘   │
                                              │
                                    ┌─────────▼─────┐
                                    │ Data & Outputs│
                                    └───────────────┘
```

---

## Troubleshooting

### Port Already in Use
If you see "port already in use" errors:
```bash
# Kill all processes and restart
pkill -f uvicorn && pkill -f shiny
bash .devcontainer/start.sh
```

### Services Not Starting
Check the logs:
```bash
ls -la outputs/
cat outputs/ai-backend.log
cat outputs/backend.log
cat outputs/shiny.log
```

### Missing R Packages
If R packages are missing:
```bash
Rscript -e "install.packages(c('shiny', 'metafor', 'netmeta', 'BCEA'), repos='https://cloud.r-project.org/')"
```

### Missing Python Packages
```bash
cd backend
pip install -r requirements.txt
cd api
pip install -r requirements.txt
```

### Permission Errors
```bash
chmod -R 777 outputs data frontend/outputs frontend/data
```

---

## Running Tests

### Python Tests
```bash
cd backend/api
pytest test_nlq_api.py -v
```

### R Tests (if available)
```bash
cd tests/r
Rscript run_tests.R
```

---

## Development Workflow

### 1. Make Code Changes
- Frontend: Edit files in `frontend/`
- Backend: Edit files in `backend/api/`

### 2. Auto-Reload
Both FastAPI and Shiny support hot reloading:
- **FastAPI**: Automatically reloads when you save Python files
- **Shiny**: Refresh browser to see R changes

### 3. Test Your Changes
- Use the Shiny web interface at http://localhost:3838
- Test API endpoints at http://localhost:8001/docs

### 4. Commit and Push
```bash
git add .
git commit -m "Your descriptive message"
git push
```

---

## Docker Compose Alternative

If you prefer Docker Compose over Codespaces:

```bash
docker-compose up -d
```

This will:
- Build both frontend and backend containers
- Start all services
- Expose the same ports (3838, 8001, 8000)

---

## Features Available in Codespaces

✅ **Automatic Environment Setup**
- Python 3.11 with FastAPI
- R 4.3 with Shiny and statistical packages
- All system dependencies

✅ **Automatic Port Forwarding**
- Shiny app accessible in browser
- API docs available instantly

✅ **Persistent Storage**
- `outputs/` directory for generated reports
- `data/` directory for uploaded files

✅ **VS Code Extensions**
- Python language support
- R language support
- Docker support
- Linting and formatting

✅ **Integrated Terminal**
- Run commands directly
- Monitor logs in real-time

---

## Next Steps

1. ✅ Open Codespace
2. ✅ Wait for automatic setup
3. 📊 Open http://localhost:3838
4. 🧪 Try the sample workflows:
   - Upload `data/sample_binary.csv`
   - Run a pairwise meta-analysis
   - Generate a report

---

## Support

- **Documentation**: See [README.md](README.md) and [QUICKSTART.md](QUICKSTART.md)
- **Issues**: Report bugs on GitHub Issues
- **Logs**: Check `outputs/*.log` files for debugging

---

**🎉 Happy Coding in Codespaces!**
