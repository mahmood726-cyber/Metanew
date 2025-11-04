# TESTING STRATEGY - EvidenceOS PRIME
## Comprehensive Testing Plan

**Date:** November 4, 2025
**Status:** Python testing in progress

---

## TESTING PRIORITY

### Phase 1: Python Backend Testing ✅ **DO THIS FIRST**
**Why:** Can run entirely in current environment, no GUI needed
**Time:** 1-2 hours
**Tools:** pytest, Python 3.11

#### 1.1 MAIC Engine Tests ✅ COMPLETE
```bash
cd /home/user/Metanew
python -m pytest tests/test_maic_engine.py -v
```

**Status:** ✅ 20/20 tests passing (2.66 seconds)

#### 1.2 Other Backend Tests (if they exist)
```bash
# Check for other test files
find tests/ -name "test_*.py"

# Run all Python tests
python -m pytest tests/ -v --tb=short
```

#### 1.3 API Endpoint Tests
**Challenge:** Requires API server running

**Option A:** Mock testing (unit tests)
```bash
# Test without running server
python -m pytest tests/test_api_endpoints.py --mock
```

**Option B:** Integration testing (requires server)
```bash
# Terminal 1: Start API server
cd /home/user/Metanew/backend/api
uvicorn hta_features_api:app --reload --host 0.0.0.0 --port 8001

# Terminal 2: Run API tests
cd /home/user/Metanew
python tests/test_api_endpoints.py
```

---

### Phase 2: R Shiny Testing ⏳ **DO THIS SECOND**
**Why:** R Shiny app is the main user interface
**Time:** 2-4 hours
**Tools:** R testthat, shinytest2

#### 2.1 R Testing Setup

**Prerequisites:**
```R
# Install R testing packages
install.packages(c(
  "testthat",      # Unit testing framework
  "shinytest2",    # Shiny app testing
  "mockr"          # Mocking for isolated tests
))
```

**Create R test directory:**
```bash
cd /home/user/Metanew
mkdir -p tests/testthat
```

#### 2.2 Unit Tests for R Modules

**Example: Test MAIC UI module**
```R
# tests/testthat/test-maic_stc.R

library(testthat)
library(shiny)
source("../../frontend/modules/maic_stc.R")

test_that("MAIC UI renders without errors", {
  ui <- maic_stc_ui("test")
  expect_true(!is.null(ui))
  expect_s3_class(ui, "shiny.tag")
})

test_that("MAIC server function exists", {
  expect_true(is.function(maic_stc_server))
})
```

**Run R unit tests:**
```R
# From R console
library(testthat)
test_dir("tests/testthat")
```

Or from command line:
```bash
cd /home/user/Metanew
Rscript -e "testthat::test_dir('tests/testthat')"
```

#### 2.3 Shiny App Integration Tests

**Example: Test full app startup**
```R
# tests/testthat/test-app.R

library(shinytest2)

test_that("Main app starts without errors", {
  app <- AppDriver$new("../../frontend/app.R")

  # Check app loaded
  expect_true(!is.null(app))

  # Check for key UI elements
  app$expect_text("EvidenceOS PRIME")

  app$stop()
})
```

**Run Shiny tests:**
```R
# Requires browser
library(shinytest2)
test_app("frontend/app.R")
```

---

### Phase 3: GUI Testing with Selenium ⏳ **DO THIS LAST**
**Why:** End-to-end user workflows
**Time:** 4-8 hours
**Tools:** Selenium WebDriver, Python

#### 3.1 Selenium Setup

**Install Selenium:**
```bash
pip install selenium webdriver-manager
```

**Install browser driver:**
```bash
# Chrome
pip install webdriver-manager
# Driver will auto-download on first run
```

#### 3.2 GUI Test Framework

**Create test file:**
```python
# tests/test_gui_selenium.py

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service
import time

class TestEvidenceOSGUI:
    """End-to-end GUI tests for EvidenceOS PRIME"""

    @classmethod
    def setup_class(cls):
        """Start browser and navigate to app"""
        options = webdriver.ChromeOptions()
        options.add_argument('--headless')  # Run without GUI
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')

        service = Service(ChromeDriverManager().install())
        cls.driver = webdriver.Chrome(service=service, options=options)
        cls.driver.implicitly_wait(10)

        # Navigate to app (adjust port as needed)
        cls.driver.get("http://localhost:3838")

    def test_app_loads(self):
        """Test: Main page loads"""
        assert "EvidenceOS" in self.driver.title

    def test_data_import_tab(self):
        """Test: Can navigate to data import"""
        # Find and click data import tab
        tab = self.driver.find_element(By.LINK_TEXT, "Data Import")
        tab.click()

        # Wait for tab to load
        time.sleep(2)

        # Check for upload button
        upload = self.driver.find_element(By.ID, "data_import-upload")
        assert upload is not None

    def test_maic_workflow(self):
        """Test: MAIC analysis workflow"""
        # Navigate to MAIC tab
        tab = self.driver.find_element(By.LINK_TEXT, "MAIC/STC")
        tab.click()
        time.sleep(2)

        # Upload IPD file
        # (Implementation depends on your file upload structure)

        # Run analysis
        # (Click run button)

        # Check for results
        # (Verify treatment effect displayed)

    @classmethod
    def teardown_class(cls):
        """Close browser"""
        cls.driver.quit()
```

**Run Selenium tests:**
```bash
# Start R Shiny app first
cd /home/user/Metanew/frontend
R -e "shiny::runApp('app.R', port=3838, host='0.0.0.0')" &

# Wait for app to start
sleep 5

# Run Selenium tests
python -m pytest tests/test_gui_selenium.py -v
```

---

## TESTING CHECKLIST

### Python Backend ✅
- [x] MAIC engine (20 tests) - ✅ PASSING
- [ ] API health check
- [ ] Cache manager
- [ ] ETL pipeline
- [ ] Ollama client
- [ ] Hybrid screener

### R Shiny Frontend ⏳
- [ ] App starts without errors
- [ ] All modules load
- [ ] Data import works
- [ ] Meta-analysis runs
- [ ] MAIC/STC works
- [ ] Health economics works
- [ ] Reports generate

### GUI E2E ⏳
- [ ] Full workflow: Import → Analyze → Report
- [ ] MAIC workflow
- [ ] NMA workflow
- [ ] Health economics workflow
- [ ] Download reports

---

## TESTING COMMANDS QUICK REFERENCE

### Python
```bash
# All Python tests
python -m pytest tests/ -v

# Just MAIC tests (already passing)
python -m pytest tests/test_maic_engine.py -v

# With coverage
python -m pytest tests/ --cov=backend --cov-report=html
```

### R
```R
# Unit tests
testthat::test_dir("tests/testthat")

# Shiny tests
shinytest2::test_app("frontend/app.R")

# Run app manually
shiny::runApp("frontend/app.R", port=3838)
```

### Selenium
```bash
# Start app
cd frontend && R -e "shiny::runApp('app.R', port=3838)" &

# Run GUI tests
python -m pytest tests/test_gui_selenium.py -v
```

---

## RECOMMENDED APPROACH

### For Current Environment (Docker/CLI only):
1. ✅ **Complete all Python tests** (can do now)
2. ⏳ **Create R unit tests** (can write, may not run in Docker)
3. ⏳ **Document GUI tests** (need browser access)

### For Local Development (with GUI):
1. Download repo to local machine
2. Install R + required packages
3. Run R Shiny app locally
4. Run Selenium tests with browser

---

## WHAT TO DO NOW

**Immediate Next Steps:**

1. **Complete Python testing** ✅ (in progress)
   ```bash
   # Run all Python tests
   cd /home/user/Metanew
   python -m pytest tests/ -v --tb=short
   ```

2. **Try starting API server**
   ```bash
   cd /home/user/Metanew/backend/api
   python -c "from hta_features_api import app; print('API loads OK')"
   ```

3. **Check R app can load**
   ```bash
   cd /home/user/Metanew/frontend
   R -e "source('app.R'); print('App loads OK')" --vanilla
   ```

4. **Create testing report**
   - Document what passed
   - Document what failed
   - Document what needs GUI

---

## TOOLS SUMMARY

| Testing Type | Tool | Environment | Status |
|--------------|------|-------------|--------|
| Python unit | pytest | ✅ Docker/CLI | Ready |
| Python API | pytest + requests | ⚠️ Needs server | Partial |
| R unit | testthat | ⚠️ Needs R packages | TBD |
| R Shiny | shinytest2 | ❌ Needs GUI | Not ready |
| GUI E2E | Selenium | ❌ Needs browser | Not ready |

**Recommendation:** Complete Python tests now (environment ready), then download repo for R/GUI testing.

---

**Next:** Run all Python tests and create results report.
