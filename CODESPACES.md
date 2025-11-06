# 🚀 GitHub Codespaces Quick Start Guide

## EvidenceOS PRIME - Meta-Analysis & HTA Platform

This guide will help you get EvidenceOS PRIME running quickly in GitHub Codespaces.

---

## ⚡ Quick Start (60 seconds to running app!)

Once your Codespace is created, run:

```bash
./quick-start.sh
```

This script will:
- ✅ Build Docker images (with caching)
- ✅ Start all services
- ✅ Wait for health checks
- ✅ Display access URLs

**That's it!** Your application will be available at the forwarded ports.

---

## 🌐 Accessing the Application

### Option 1: Ports Tab (Recommended)
1. Click the **"Ports"** tab in VS Code
2. Find port **3838** (Shiny Frontend)
3. Click the **🌐 globe icon** or **"Open in Browser"**
4. The frontend will open in a new tab

### Option 2: Port Forwarding URLs
Codespaces automatically generates URLs:
- **Frontend**: `https://<your-codespace>-3838.app.github.dev`
- **Backend API**: `https://<your-codespace>-8001.app.github.dev`
- **API Docs**: `https://<your-codespace>-8001.app.github.dev/docs`

---

## 🎯 What You Get

### Core Features
✅ **Pairwise Meta-Analysis**
   - Forest plots, funnel plots
   - Heterogeneity assessment (I², τ²)
   - Publication bias detection

✅ **Network Meta-Analysis**
   - League tables with point estimates
   - P-score rankings
   - Node-splitting for inconsistency

✅ **Dose-Response Meta-Analysis**
   - Restricted cubic splines
   - Non-linearity testing
   - Dose-specific predictions

✅ **Health Economics Analysis**
   - Incremental cost-effectiveness ratio (ICER)
   - Cost-effectiveness acceptability curves (CEAC)
   - Expected value of perfect information (EVPI)
   - Budget impact modeling

### V2 Features (NEW!)
✅ **Scenario Presets Library** - 17 pre-configured templates
✅ **Parquet Caching** - 10-100x faster re-analysis
✅ **Protocol Diff Comparison** - Track changes over time
✅ **AI Copilot** - Natural language queries
✅ **Complete Audit Trail** - Full reproducibility

---

## 🛠️ Manual Setup (Alternative)

If you prefer manual control:

### 1. Build Images
```bash
docker-compose build --parallel
```

### 2. Start Services
```bash
docker-compose up -d
```

### 3. Check Status
```bash
docker-compose ps
```

### 4. View Logs
```bash
# All services
docker-compose logs -f

# Frontend only
docker-compose logs -f shiny-frontend

# Backend only
docker-compose logs -f ai-backend
```

---

## 🔧 Useful Commands

### Service Management
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View service status
docker-compose ps

# View resource usage
docker stats
```

### Logs & Debugging
```bash
# Follow all logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific service
docker-compose logs -f shiny-frontend
docker-compose logs -f ai-backend

# Search logs for errors
docker-compose logs | grep -i error
```

### Shell Access
```bash
# Access frontend container
docker exec -it evidenceos-shiny-frontend bash

# Access backend container
docker exec -it evidenceos-ai-backend bash

# Run R console in frontend
docker exec -it evidenceos-shiny-frontend R
```

---

## 📊 Performance Optimizations

### What We've Optimized for Codespaces

1. **Parallel R Package Compilation** (`Ncpus=4`)
   - 4x faster R package installation
   - Reduces frontend build time from ~10min to ~3min

2. **Docker Layer Caching**
   - Subsequent builds use cached layers
   - Second build typically takes <30 seconds

3. **Multi-stage Builds**
   - Smaller final images
   - Faster container startup

4. **.dockerignore Optimization**
   - Excludes unnecessary files from build context
   - Faster context transfer

5. **Devcontainer Prebuilds**
   - GitHub can prebuild your environment
   - Near-instant Codespace creation after first build

---

## 🎓 Usage Examples

### Example 1: Quick Demo with Presets
1. Open `http://localhost:3838`
2. Go to **"V2 Features"** tab
3. Click **"Scenario Presets"**
4. Select **"Cardiovascular RCT Network"**
5. Click **"Load Preset"**
6. Navigate to **"Network Meta-Analysis"** tab
7. Click **"Run NMA"**
8. View league table and forest plots!

### Example 2: Upload Your Data
1. Go to **"Data Import"** tab
2. Click **"Browse"** and upload CSV
3. Map columns to study characteristics
4. Go to **"Protocol"** tab
5. Define PICO framework
6. Run analysis in respective tab

### Example 3: AI Copilot
1. Go to **"AI Copilot"** tab
2. Type: *"Show me the pooled effect size for all cardiovascular studies"*
3. AI will query your data and provide structured response
4. Try: *"Which study has the highest weight?"*

### Example 4: Generate Reports
1. Complete any analysis
2. Go to **"Reporting"** tab
3. Select format (Word, PDF, PowerPoint)
4. Click **"Generate Report"**
5. Download from outputs directory

---

## 🐛 Troubleshooting

### Services Won't Start
```bash
# Check Docker is running
docker ps

# Check logs for errors
docker-compose logs

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Frontend 502 Bad Gateway
This usually means R is still loading packages (first startup takes 30-60s):
```bash
# Wait for health check
docker-compose logs -f shiny-frontend

# Look for: "Shiny Server starting on port 3838"
```

### Backend Not Responding
```bash
# Check backend logs
docker-compose logs -f ai-backend

# Restart backend only
docker-compose restart ai-backend
```

### Port Already in Use
```bash
# Check what's using the port
lsof -i :3838
lsof -i :8001

# Stop conflicting service or change ports in docker-compose.yml
```

### Out of Memory
R packages can use 2-4GB during build:
```bash
# Increase Docker memory limit
# Edit Docker Desktop settings > Resources > Memory

# Or use fewer Ncpus in frontend/Dockerfile
# Change Ncpus=4 to Ncpus=2
```

---

## 📈 Performance Expectations

### First Build (Cold Start)
- **Backend**: ~2 minutes
- **Frontend**: ~3-5 minutes (with Ncpus=4)
- **Total**: ~5-7 minutes

### Subsequent Builds (Cached)
- **Backend**: ~10 seconds
- **Frontend**: ~15 seconds
- **Total**: ~30 seconds

### Runtime Performance
- **Application Startup**: 30-60 seconds
- **Data Upload**: Instant (<100MB files)
- **Pairwise Meta-Analysis**: 1-3 seconds
- **Network Meta-Analysis**: 5-15 seconds
- **Dose-Response**: 10-30 seconds
- **Report Generation**: 10-20 seconds

---

## 🔐 Security Notes

### Running in Codespaces
- Codespaces provides isolated containerized environments
- All ports are private by default
- You can make ports public if needed (use caution)

### Production Deployment
This setup is optimized for **development/testing**. For production:
- Enable nginx reverse proxy (`docker-compose --profile production up -d`)
- Add SSL certificates
- Configure authentication
- Set up proper database (PostgreSQL)
- Review security settings in docker-compose.yml

---

## 📚 Additional Resources

### Documentation
- **Main README**: `/README.md` - Full project documentation
- **API Docs**: `http://localhost:8001/docs` - Interactive API documentation
- **User Guide**: Check frontend Help section

### Architecture
```
┌─────────────────┐
│  User Browser   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────┐
│ Shiny Frontend  │────▶│ AI Backend   │
│   (Port 3838)   │     │ (Port 8001)  │
└─────────────────┘     └──────────────┘
         │
         ▼
┌─────────────────┐
│ Parquet Cache   │
│  (File System)  │
└─────────────────┘
```

### Technology Stack
- **Frontend**: R Shiny 4.3.2
- **Backend**: Python 3.11 + FastAPI
- **Analysis**: metafor, netmeta, dosresmeta, BCEA
- **Caching**: PyArrow Parquet with Snappy compression
- **Deployment**: Docker + Docker Compose

---

## 💡 Pro Tips

### Speed Up Workflows
1. **Enable Parquet Caching** in V2 Features tab
   - First run: Normal speed
   - Re-runs: 10-100x faster!

2. **Use Scenario Presets** for common analyses
   - 17 pre-configured templates
   - One-click analysis setup

3. **Leverage AI Copilot** for data exploration
   - Natural language queries
   - Structured JSON responses

### Development Tips
```bash
# Watch logs in real-time
docker-compose logs -f | grep -E "ERROR|WARNING"

# Monitor resource usage
docker stats --no-stream

# Quick restart after code changes
docker-compose restart shiny-frontend

# Clean up old images
docker system prune -a
```

### Codespaces-Specific
- **Prebuilds**: Enable in repo settings for instant launches
- **Dotfiles**: Customize your shell environment
- **Extensions**: VS Code extensions persist across sessions
- **Secrets**: Use Codespaces secrets for API keys

---

## 🎉 You're Ready!

Run `./quick-start.sh` and start analyzing!

For questions or issues:
- Check logs: `docker-compose logs -f`
- Review troubleshooting section above
- Check GitHub Issues

Happy analyzing! 📊✨
