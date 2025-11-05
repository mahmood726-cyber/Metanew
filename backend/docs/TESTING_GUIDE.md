# Testing Guide - EvidenceOS PRIME

## Overview

Comprehensive testing infrastructure for the EvidenceOS PRIME backend, focusing on ML/AI components and API endpoints. Target: **80% code coverage**.

## Table of Contents

1. [Test Organization](#test-organization)
2. [Running Tests](#running-tests)
3. [Test Coverage](#test-coverage)
4. [Writing Tests](#writing-tests)
5. [CI/CD Integration](#cicd-integration)
6. [Troubleshooting](#troubleshooting)

---

## Test Organization

### Directory Structure

```
backend/
├── tests/
│   ├── __init__.py
│   ├── test_predictive_models.py      # ML prediction tests (650+ lines)
│   ├── test_explainable_ai.py         # SHAP/LIME tests (550+ lines)
│   ├── test_ml_integration.py         # End-to-end ML tests (700+ lines)
│   └── conftest.py                    # Shared fixtures (coming soon)
├── pytest.ini                         # Pytest configuration
├── .coveragerc                        # Coverage configuration
├── run_all_tests.sh                   # Comprehensive test runner
└── run_ml_tests.sh                    # ML-specific test runner
```

### Test Categories

#### 1. **Unit Tests** (`test_predictive_models.py`, `test_explainable_ai.py`)

Tests for individual components in isolation:

- **ML Predictive Models** (test_predictive_models.py)
  - `TestPredictionResult` - Dataclass functionality
  - `TestHeterogeneityPredictor` - Heterogeneity prediction
  - `TestPublicationBiasDetector` - Publication bias detection
  - `TestStudyQualityPredictor` - Study quality assessment
  - `TestEffectSizePredictor` - Effect size prediction
  - `TestEdgeCases` - Edge cases and error handling
  - `TestGlobalInstances` - Module-level instances

- **Explainable AI** (test_explainable_ai.py)
  - `TestExplanationResult` - Explanation dataclass
  - `TestModelExplainerInitialization` - Explainer setup
  - `TestSHAPExplanations` - SHAP interpretability
  - `TestLIMEExplanations` - LIME interpretability
  - `TestGlobalFeatureImportance` - Feature importance
  - `TestComprehensiveExplanations` - Multi-method explanations
  - `TestPatientSpecificExplanations` - Clinical narratives
  - `TestFallbackMechanisms` - Graceful degradation

#### 2. **Integration Tests** (`test_ml_integration.py`)

Tests for end-to-end workflows:

- `TestMLHealth` - ML system health monitoring
- `TestCaching` - Redis cache functionality
- `TestHeterogeneityPrediction` - Heterogeneity prediction API
- `TestPublicationBias` - Publication bias detection API
- `TestStudyQuality` - Study quality prediction API
- `TestAnalysisRecommendations` - Recommendation engine API
- `TestEffectDirection` - Effect direction prediction API
- `TestCacheManagement` - Cache management API
- `TestEndToEnd` - Complete ML workflow
- `TestPerformance` - Performance benchmarks

### Test Markers

Use pytest markers to categorize and filter tests:

```python
@pytest.mark.unit          # Unit tests
@pytest.mark.integration   # Integration tests
@pytest.mark.slow          # Tests that take >5 seconds
@pytest.mark.requires_redis    # Requires Redis to be running
@pytest.mark.requires_shap     # Requires SHAP library
@pytest.mark.requires_lime     # Requires LIME library
@pytest.mark.requires_ml       # Requires ML libraries
```

---

## Running Tests

### Quick Start

**Run all tests:**
```bash
cd backend
./run_all_tests.sh
```

**Run ML integration tests only:**
```bash
./run_ml_tests.sh
```

**Run specific test file:**
```bash
pytest tests/test_predictive_models.py -v
```

**Run specific test class:**
```bash
pytest tests/test_predictive_models.py::TestHeterogeneityPredictor -v
```

**Run specific test function:**
```bash
pytest tests/test_predictive_models.py::TestHeterogeneityPredictor::test_extract_features_basic -v
```

### Advanced Usage

**Run only unit tests:**
```bash
pytest tests/ -m unit -v
```

**Run only integration tests:**
```bash
pytest tests/ -m integration -v
```

**Skip slow tests:**
```bash
pytest tests/ -m "not slow" -v
```

**Run tests requiring Redis:**
```bash
# Make sure Redis is running first
redis-cli ping  # Should return PONG
pytest tests/ -m requires_redis -v
```

**Run with coverage:**
```bash
pytest tests/ --cov=ml --cov=api --cov=cache --cov-report=html
```

**Run in parallel (faster):**
```bash
pytest tests/ -n auto  # Requires pytest-xdist
```

**Run with detailed output:**
```bash
pytest tests/ -vv --tb=long
```

---

## Test Coverage

### Coverage Targets

| Module | Target | Current | Status |
|--------|--------|---------|--------|
| `ml/predictive_models.py` | 80% | TBD | 🚧 In Progress |
| `ml/explainable_ai.py` | 80% | TBD | 🚧 In Progress |
| `ml/rag_system.py` | 70% | TBD | 📋 Planned |
| `ml/mlops_infrastructure.py` | 70% | TBD | 📋 Planned |
| `ml/automl.py` | 75% | TBD | 📋 Planned |
| `api/ml_routes.py` | 85% | ~60% | ✅ Partial |
| `cache/ml_cache.py` | 90% | ~70% | ✅ Partial |

### Generating Coverage Reports

**Terminal report:**
```bash
pytest tests/ --cov=ml --cov-report=term-missing
```

**HTML report (recommended):**
```bash
pytest tests/ --cov=ml --cov-report=html
open htmlcov/index.html  # Open in browser
```

**JSON report (for CI/CD):**
```bash
pytest tests/ --cov=ml --cov-report=json
```

**XML report (for tools like SonarQube):**
```bash
pytest tests/ --cov=ml --cov-report=xml
```

### Coverage Commands

**Check current coverage:**
```bash
pytest tests/ --cov=ml --cov=api --cov=cache --cov-report=term
```

**Find uncovered lines:**
```bash
pytest tests/ --cov=ml --cov-report=term-missing
```

**Generate badge:**
```bash
coverage-badge -o coverage.svg -f
```

---

## Writing Tests

### Test Structure

Follow this structure for new tests:

```python
"""
Unit Tests for [Module Name]
Brief description of what's being tested
"""

import pytest
import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.your_module import YourClass, your_function


# =====================================================================
# FIXTURES
# =====================================================================

@pytest.fixture
def sample_data():
    """Fixture description"""
    return {"key": "value"}


# =====================================================================
# TEST: Class or Functionality
# =====================================================================

class TestYourClass:
    """Test YourClass functionality"""

    def test_initialization(self):
        """Test object initialization"""
        obj = YourClass()
        assert obj is not None

    def test_main_functionality(self, sample_data):
        """Test main functionality"""
        obj = YourClass()
        result = obj.process(sample_data)
        assert result is not None
        assert isinstance(result, dict)

    def test_edge_case(self):
        """Test edge case handling"""
        obj = YourClass()
        with pytest.raises(ValueError):
            obj.process(None)
```

### Fixtures

Use fixtures for reusable test data:

```python
@pytest.fixture
def sample_studies():
    """Sample studies dataframe"""
    return pd.DataFrame({
        'study_id': ['s1', 's2', 's3'],
        'n': [100, 200, 150],
        'yi': [0.5, 0.6, 0.4]
    })

@pytest.fixture
def trained_model(sample_studies):
    """Pre-trained model for testing"""
    X, y = prepare_data(sample_studies)
    model = RandomForestClassifier()
    model.fit(X, y)
    return model
```

### Parametrization

Test multiple cases efficiently:

```python
@pytest.mark.parametrize("input,expected", [
    (5, 'Low'),
    (15, 'High'),
    (10, 'Moderate'),
])
def test_heterogeneity_levels(input, expected):
    """Test different heterogeneity levels"""
    result = categorize_heterogeneity(input)
    assert result == expected
```

### Mocking

Mock external dependencies:

```python
from unittest.mock import Mock, patch

def test_api_call_with_mock():
    """Test API call with mocked response"""
    with patch('requests.post') as mock_post:
        mock_post.return_value.json.return_value = {'result': 'success'}

        result = call_external_api()
        assert result['result'] == 'success'
        mock_post.assert_called_once()
```

### Async Tests

Test async functions:

```python
import pytest

@pytest.mark.asyncio
async def test_async_prediction():
    """Test async prediction endpoint"""
    result = await async_predict(data)
    assert result is not None
```

---

## Best Practices

### 1. Test Naming

Use descriptive names:

✅ **Good:**
```python
def test_heterogeneity_prediction_with_high_variance_studies():
    """Test that high variance in sample sizes predicts high heterogeneity"""
```

❌ **Bad:**
```python
def test_1():
    """Test something"""
```

### 2. Arrange-Act-Assert (AAA) Pattern

```python
def test_prediction():
    # Arrange
    data = create_test_data()
    predictor = HeterogeneityPredictor()

    # Act
    result = predictor.predict(data)

    # Assert
    assert result.prediction == 'High'
    assert result.confidence > 0.8
```

### 3. Test Independence

Each test should be independent:

✅ **Good:**
```python
def test_feature_1():
    obj = MyClass()  # Fresh instance
    result = obj.do_something()
    assert result == expected

def test_feature_2():
    obj = MyClass()  # Fresh instance
    result = obj.do_something_else()
    assert result == expected
```

❌ **Bad:**
```python
obj = MyClass()  # Shared state!

def test_feature_1():
    result = obj.do_something()
    assert result == expected

def test_feature_2():
    result = obj.do_something_else()  # Depends on test_feature_1!
    assert result == expected
```

### 4. Test Edge Cases

Always test edge cases:

```python
def test_empty_input():
    """Test with empty DataFrame"""
    predictor = HeterogeneityPredictor()
    with pytest.raises(ValueError):
        predictor.predict(pd.DataFrame())

def test_single_study():
    """Test with single study"""
    predictor = HeterogeneityPredictor()
    result = predictor.predict(single_study_df)
    assert isinstance(result, PredictionResult)

def test_extreme_values():
    """Test with extreme feature values"""
    predictor = HeterogeneityPredictor()
    result = predictor.predict(extreme_values_df)
    assert 0 <= result.confidence <= 1
```

### 5. Test Error Handling

```python
def test_invalid_input_raises_error():
    """Test that invalid input raises appropriate error"""
    predictor = HeterogeneityPredictor()

    with pytest.raises(ValueError, match="yi and sei required"):
        predictor.predict({'invalid': 'data'})
```

### 6. Use Appropriate Assertions

```python
# Exact equality
assert result == expected

# Approximate equality (for floats)
assert abs(result - expected) < 0.001
# or
assert result == pytest.approx(expected, rel=1e-3)

# Type checking
assert isinstance(result, PredictionResult)

# Collection membership
assert 'feature1' in result.features_used

# Boolean assertions
assert result.is_trained
assert not result.has_errors
```

---

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r backend/requirements.txt

      - name: Run tests
        run: |
          cd backend
          ./run_all_tests.sh

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./backend/coverage.xml
```

### Pre-commit Hook

Add to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: pytest
        name: pytest
        entry: pytest
        language: system
        pass_filenames: false
        always_run: true
        args: [tests/, -v, --tb=short]
```

---

## Troubleshooting

### Common Issues

#### 1. Import Errors

**Problem:** `ModuleNotFoundError: No module named 'ml'`

**Solution:**
```bash
# Add backend to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:/path/to/backend"

# Or run from backend directory
cd backend
pytest tests/
```

#### 2. Redis Connection Errors

**Problem:** `redis.exceptions.ConnectionError: Error 111 connecting to localhost:6379`

**Solution:**
```bash
# Start Redis
docker-compose up -d redis

# Or install locally
sudo systemctl start redis-server

# Or skip Redis tests
pytest tests/ -m "not requires_redis"
```

#### 3. Missing Dependencies

**Problem:** `ModuleNotFoundError: No module named 'shap'`

**Solution:**
```bash
pip install -r backend/requirements.txt

# Or install individually
pip install shap lime xgboost lightgbm catboost
```

#### 4. Slow Tests

**Problem:** Tests take too long

**Solution:**
```bash
# Run only fast tests
pytest tests/ -m "not slow"

# Run in parallel
pip install pytest-xdist
pytest tests/ -n auto

# Use smaller datasets in fixtures
```

#### 5. Flaky Tests

**Problem:** Tests pass/fail inconsistently

**Solution:**
```python
# Set random seeds
np.random.seed(42)
random.seed(42)

# Use pytest-rerunfailures
pytest tests/ --reruns 3

# Add timeouts
@pytest.mark.timeout(10)
def test_slow_operation():
    ...
```

---

## Metrics and Reporting

### Test Metrics

Track these metrics:

- **Total Tests:** Number of test functions
- **Pass Rate:** Percentage of passing tests
- **Coverage:** Code coverage percentage
- **Duration:** Total test execution time
- **Flakiness:** Tests that fail intermittently

### Coverage Metrics

- **Line Coverage:** % of lines executed
- **Branch Coverage:** % of code branches tested
- **Function Coverage:** % of functions called

### Example Output

```
====== test session starts ======
collected 127 items

tests/test_predictive_models.py::TestHeterogeneityPredictor::test_initialization PASSED
tests/test_predictive_models.py::TestHeterogeneityPredictor::test_extract_features_basic PASSED
...

---------- coverage: platform linux, python 3.11.0 -----------
Name                              Stmts   Miss  Cover   Missing
---------------------------------------------------------------
ml/predictive_models.py            350     35    90%   45-48, 112-115
ml/explainable_ai.py               280     42    85%   78-82, 156-160
ml/rag_system.py                   420    126    70%   Multiple ranges
cache/ml_cache.py                  185     19    90%   145-148
---------------------------------------------------------------
TOTAL                             1235    222    82%

====== 127 passed in 45.23s ======
```

---

## Future Improvements

### Phase 2 (Current)
- [ ] Unit tests for RAG system
- [ ] Unit tests for MLOps infrastructure
- [ ] Unit tests for AutoML
- [ ] Increase coverage to 80%

### Phase 3 (Next)
- [ ] Frontend R tests
- [ ] Load testing with locust/k6
- [ ] Security testing (OWASP Top 10)
- [ ] Mutation testing with mutmut

### Phase 4 (Future)
- [ ] Visual regression testing
- [ ] Accessibility testing
- [ ] API contract testing
- [ ] Chaos engineering tests

---

## Resources

- [Pytest Documentation](https://docs.pytest.org/)
- [Coverage.py Documentation](https://coverage.readthedocs.io/)
- [Python Testing Best Practices](https://realpython.com/pytest-python-testing/)
- [ML Testing Best Practices](https://madewithml.com/courses/mlops/testing/)

---

**Last Updated:** 2025-01-05
**Version:** 2.0.0
**Maintained by:** EvidenceOS PRIME Team
