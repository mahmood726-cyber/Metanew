# 🚀 EvidenceOS PRIME - GitHub Codespaces Quickstart

**Run the complete EvidenceOS PRIME platform in your browser with zero local setup!**

---

## ⚡ Quick Start (2 minutes)

### **Step 1: Open in Codespaces**

Click the button below or go to your GitHub repository and click **Code** → **Codespaces** → **Create codespace on [branch]**

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main)

### **Step 2: Wait for Setup**

The first time you create a Codespace, it will:
- ✅ Install R and Python dependencies (~3-5 minutes)
- ✅ Configure the environment automatically
- ✅ Set up all necessary directories

**Progress indicator:**
```
🚀 Setting up EvidenceOS PRIME in Codespaces...
📦 Updating package lists...
📊 Installing R and system dependencies...
🐍 Installing Python dependencies...
📈 Installing R packages...
✅ Setup complete!
```

### **Step 3: Start the Application**

Once setup is complete, run:

```bash
./scripts/start-codespaces.sh
```

**You'll see:**
```
🚀 Starting EvidenceOS PRIME in Codespaces...
🔧 Starting FastAPI Main Backend (port 8000)...
🤖 Starting AI Copilot Backend (port 8001)...
🎨 Starting Shiny Frontend (port 3838)...

✅ EvidenceOS PRIME is running!

📊 Access Points:
   🎨 Shiny UI: https://your-codespace-3838.preview.app.github.dev
   📡 API Docs: https://your-codespace-8000.preview.app.github.dev/docs
```

### **Step 4: Access the Application**

**Option A: Click the Port Link**
- In VS Code, click the **"Ports"** tab at the bottom
- Find port **3838** (Shiny Frontend)
- Click the **globe icon** 🌐 to open in browser

**Option B: Use the URL**
- Copy the URL from the terminal output
- Open in a new browser tab

---

## 📊 Application Components

### **1. Shiny Frontend (Port 3838)**
**What it is:** Interactive web UI for meta-analysis and health economics

**How to access:**
- Click **Ports** tab → Port 3838 → Globe icon 🌐
- Or use: `https://[codespace-name]-3838.preview.app.github.dev`

**Features:**
- Upload CSV/Excel data
- Run meta-analysis (pairwise, network, dose-response)
- Perform health economic analysis
- Generate reports (Word, PDF, PowerPoint)
- AI Copilot for natural language queries

### **2. Main API Backend (Port 8000)**
**What it is:** FastAPI backend for data validation and computation

**How to access:**
- API Docs: `https://[codespace-name]-8000.preview.app.github.dev/docs`
- Interactive Swagger UI for testing endpoints

**Key Endpoints:**
- `POST /validate` - Validate input data
- `POST /compute/yi` - Compute effect sizes
- `POST /meta/bayes` - Bayesian meta-analysis
- `POST /evidence/hash` - Generate evidence hash

### **3. AI Copilot Backend (Port 8001)**
**What it is:** Natural language query processing

**How to access:**
- Health check: `https://[codespace-name]-8001.preview.app.github.dev/health`
- API Docs: `https://[codespace-name]-8001.preview.app.github.dev/docs`

**Capabilities:**
- Natural language queries ("Show me the forest plot")
- Interpret heterogeneity statistics
- Explain ICER results

---

## 🎯 Common Tasks

### **View Logs**
```bash
# All logs
tail -f logs/*.log

# Specific service
tail -f logs/api-main.log    # Main API
tail -f logs/api-ai.log       # AI Copilot
tail -f logs/shiny.log        # Shiny Frontend
```

### **Stop Services**
```bash
./scripts/stop-codespaces.sh
```

### **Restart Services**
```bash
./scripts/stop-codespaces.sh && ./scripts/start-codespaces.sh
```

### **Run Tests**
```bash
# Integration tests
cd tests/integration
pytest -v

# Specific test file
pytest test_api_integration.py -v

# With coverage
pytest --cov=../../backend --cov-report=html
```

### **Check Service Health**
```bash
# Main API
curl http://localhost:8000/health

# AI Copilot
curl http://localhost:8001/health
```

---

## 📁 Working with Data

### **Upload Data**
1. Click **Explorer** in VS Code sidebar
2. Navigate to `data/` folder
3. Right-click → **Upload Files**
4. Upload your CSV/Excel files
5. Access them through the Shiny UI

### **Sample Data**
Sample datasets are in `data/` folder:
- `data/sample_binary.csv` - Binary outcome data
- `data/sample_continuous.csv` - Continuous outcome data
- `data/sample_tte.csv` - Time-to-event data

### **Outputs**
Generated reports are saved to `outputs/` folder:
- Word documents (`.docx`)
- PDF reports (`.pdf`)
- PowerPoint slides (`.pptx`)
- JSON evidence objects (`.json`)

---

## 🔧 Configuration

### **Environment Variables**

Edit `.env` file (created automatically from `.env.example`):

```bash
# CORS Configuration (already set for Codespaces)
ALLOWED_ORIGINS=https://*.github.dev,https://*.preview.app.github.dev

# API Configuration
API_PORT=8000
AI_API_PORT=8001
SHINY_PORT=3838

# Features
ENVIRONMENT=codespaces
DEBUG=false
```

### **Ports**

If you need to change ports, edit:
1. `.env` file - Update port numbers
2. `scripts/start-codespaces.sh` - Update port references
3. `.devcontainer/devcontainer.json` - Update `forwardPorts`

---

## 🐛 Troubleshooting

### **Issue: Services won't start**

**Solution 1: Check if ports are in use**
```bash
lsof -i:3838  # Shiny
lsof -i:8000  # Main API
lsof -i:8001  # AI Copilot
```

**Solution 2: Force stop and restart**
```bash
pkill -9 -f uvicorn
pkill -9 -f "R.*shiny"
./scripts/start-codespaces.sh
```

### **Issue: Port not forwarding**

**Solution:**
1. Click **Ports** tab in VS Code
2. Find the port (3838, 8000, or 8001)
3. Right-click → **Port Visibility** → **Public**
4. Click globe icon to open

### **Issue: R packages not loading**

**Solution: Reinstall R packages**
```bash
sudo Rscript -e "
  install.packages(c('shiny', 'bslib', 'metafor', 'netmeta'),
                   repos='https://cloud.r-project.org')
"
```

### **Issue: Python dependencies missing**

**Solution: Reinstall Python dependencies**
```bash
pip install -r backend/requirements.txt
pip install -r backend/api/requirements.txt
```

### **Issue: Can't access forwarded ports**

**Solution: Check Codespace settings**
1. Go to GitHub → Your repository → Settings → Codespaces
2. Ensure port visibility is set correctly
3. Try making ports **public** instead of **private**

### **Issue: Shiny app shows error**

**Solution: Check Shiny logs**
```bash
tail -100 logs/shiny.log
```

Common issues:
- Missing R packages → Reinstall (see above)
- Port already in use → Stop other services
- File permissions → Run `chmod -R 777 outputs data logs`

---

## 🧪 Running Tests

### **Unit Tests**
```bash
# Python tests
cd tests/py
pytest -v

# Specific test file
pytest test_bayesian_meta.py -v
```

### **Integration Tests**
```bash
# Start services first
./scripts/start-codespaces.sh

# In a new terminal
cd tests/integration
pytest -v

# With coverage
pytest --cov=../../backend --cov-report=term
```

### **E2E Tests**
```bash
cd tests/integration
pytest test_e2e_workflow.py -v -s
```

---

## 📦 Installing Additional Packages

### **Python Packages**
```bash
pip install package-name
# Add to requirements.txt to persist
echo "package-name==version" >> backend/requirements.txt
```

### **R Packages**
```bash
sudo Rscript -e "install.packages('package-name', repos='https://cloud.r-project.org')"
```

### **System Packages**
```bash
sudo apt-get update
sudo apt-get install package-name
```

---

## 💾 Saving Your Work

### **Codespaces Auto-Saves**
- Your code changes are automatically saved
- Outputs in `outputs/` folder persist
- Uploaded data in `data/` folder persists

### **Commit Changes**
```bash
git add .
git commit -m "Your changes"
git push
```

### **Download Files**
1. Right-click file in VS Code Explorer
2. Select **Download**

---

## 🚀 Performance Tips

### **Speed Up Codespace**
1. **Use 4-core machine** (Settings → Change machine type)
2. **Prebuild configuration** (for frequently used branches)
3. **Close unused tabs** in VS Code

### **Speed Up R Package Installation**
Already configured to use binary packages from Posit Package Manager

### **Reduce Memory Usage**
```bash
# Stop unused services
./scripts/stop-codespaces.sh
# Start only what you need
```

---

## 📚 Additional Resources

### **Documentation**
- [Main README](README.md) - Full project documentation
- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Production deployment
- [API Documentation](https://your-codespace-8000.preview.app.github.dev/docs) - Interactive API docs
- [V2 Features Guide](V2_FEATURES_GUIDE.md) - Latest features

### **Support**
- **Issues**: https://github.com/mahmood726-cyber/Metanew/issues
- **Discussions**: GitHub Discussions tab

---

## 🎉 You're All Set!

Your EvidenceOS PRIME instance is running in Codespaces!

**Next steps:**
1. ✅ Open port 3838 to access the Shiny UI
2. ✅ Upload your data or use sample datasets
3. ✅ Run meta-analysis and generate reports
4. ✅ Try the AI Copilot features

**Happy analyzing!** 📊🚀

---

## 📝 Quick Reference Card

```bash
# Start everything
./scripts/start-codespaces.sh

# Stop everything
./scripts/stop-codespaces.sh

# View logs
tail -f logs/shiny.log

# Run tests
cd tests/integration && pytest -v

# Access points
# Shiny UI:    Port 3838
# Main API:    Port 8000 /docs
# AI Copilot:  Port 8001 /health
```

---

**Pro Tip**: Bookmark your Codespace URL for quick access! The environment will pause after 30 minutes of inactivity and restart when you return.
