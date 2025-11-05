#!/bin/bash
# Comprehensive Test Runner for EvidenceOS Backend
# Runs all unit tests, integration tests, and generates coverage reports

set -e  # Exit on error

echo "=========================================="
echo "EvidenceOS Backend - Comprehensive Test Suite"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check Python environment
echo "Checking Python environment..."
python --version
echo ""

# Check if Redis is running (optional but recommended)
echo "Checking Redis connection..."
redis-cli ping > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Redis is running${NC}"
    REDIS_AVAILABLE=true
else
    echo -e "${YELLOW}⚠ Redis is not running - some caching tests will be skipped${NC}"
    echo "  To start Redis: docker-compose up -d redis"
    REDIS_AVAILABLE=false
fi
echo ""

# Check ML libraries
echo "Checking ML library availability..."
python -c "import xgboost; print('✓ XGBoost:', xgboost.__version__)" 2>/dev/null || echo "⚠ XGBoost not available"
python -c "import lightgbm; print('✓ LightGBM:', lightgbm.__version__)" 2>/dev/null || echo "⚠ LightGBM not available"
python -c "import catboost; print('✓ CatBoost:', catboost.__version__)" 2>/dev/null || echo "⚠ CatBoost not available"
python -c "import shap; print('✓ SHAP:', shap.__version__)" 2>/dev/null || echo "⚠ SHAP not available"
python -c "import lime; print('✓ LIME installed')" 2>/dev/null || echo "⚠ LIME not available"
echo ""

# Create htmlcov directory if it doesn't exist
mkdir -p htmlcov

echo "=========================================="
echo "PHASE 1: Unit Tests"
echo "=========================================="
echo ""

# Run unit tests for ML modules
echo "Running ML Predictive Models tests..."
python -m pytest tests/test_predictive_models.py -v -m unit 2>&1 || echo -e "${YELLOW}Some tests skipped or failed${NC}"
echo ""

echo "Running Explainable AI tests..."
python -m pytest tests/test_explainable_ai.py -v -m unit 2>&1 || echo -e "${YELLOW}Some tests skipped or failed${NC}"
echo ""

echo "=========================================="
echo "PHASE 2: Integration Tests"
echo "=========================================="
echo ""

echo "Running ML Integration tests..."
if [ "$REDIS_AVAILABLE" = true ]; then
    python -m pytest tests/test_ml_integration.py -v 2>&1
else
    echo -e "${YELLOW}Skipping some Redis-dependent tests...${NC}"
    python -m pytest tests/test_ml_integration.py -v -m "not requires_redis" 2>&1 || echo -e "${YELLOW}Some tests skipped${NC}"
fi
echo ""

echo "=========================================="
echo "PHASE 3: Complete Test Suite with Coverage"
echo "=========================================="
echo ""

# Run all tests with coverage
echo "Running complete test suite..."
python -m pytest tests/ \
    -v \
    --cov=ml \
    --cov=api \
    --cov=cache \
    --cov-report=term-missing \
    --cov-report=html:htmlcov \
    --cov-report=json:coverage.json \
    --tb=short \
    --color=yes \
    2>&1 || TEST_RESULT=$?

echo ""
echo "=========================================="
echo "PHASE 4: Coverage Analysis"
echo "=========================================="
echo ""

# Check if coverage.json exists
if [ -f "coverage.json" ]; then
    echo "Coverage Summary:"
    echo ""

    # Extract coverage percentage using Python
    COVERAGE_PCT=$(python -c "
import json
with open('coverage.json') as f:
    data = json.load(f)
    total = data['totals']['percent_covered']
    print(f'{total:.1f}')
" 2>/dev/null || echo "N/A")

    echo "Total Coverage: ${COVERAGE_PCT}%"
    echo ""

    # Coverage target
    TARGET=80.0

    if [ "$COVERAGE_PCT" != "N/A" ]; then
        if (( $(echo "$COVERAGE_PCT >= $TARGET" | bc -l) )); then
            echo -e "${GREEN}✓ Coverage target met (>=${TARGET}%)${NC}"
        else
            echo -e "${YELLOW}⚠ Coverage below target (${COVERAGE_PCT}% < ${TARGET}%)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Coverage data not available${NC}"
fi

echo ""
echo "Detailed coverage report available at: htmlcov/index.html"
echo ""

echo "=========================================="
echo "PHASE 5: Test Summary"
echo "=========================================="
echo ""

# Count test files
TEST_FILES=$(find tests/ -name "test_*.py" | wc -l)
echo "Test Files: ${TEST_FILES}"

# Count test functions (approximate)
TEST_FUNCTIONS=$(grep -r "def test_" tests/ 2>/dev/null | wc -l)
echo "Test Functions: ~${TEST_FUNCTIONS}"

echo ""

# Final result
if [ ${TEST_RESULT:-0} -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo "✓ ALL TESTS PASSED!"
    echo -e "==========================================${NC}"
    exit 0
else
    echo -e "${YELLOW}=========================================="
    echo "⚠ SOME TESTS FAILED OR WERE SKIPPED"
    echo -e "==========================================${NC}"
    echo ""
    echo "Tips:"
    echo "  1. Check if all dependencies are installed: pip install -r requirements.txt"
    echo "  2. Start Redis if needed: docker-compose up -d redis"
    echo "  3. Review test output above for specific failures"
    echo "  4. Some tests may be intentionally skipped if optional libraries are missing"
    exit 1
fi
