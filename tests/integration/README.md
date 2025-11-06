# Integration & E2E Tests for EvidenceOS PRIME

Comprehensive integration and end-to-end tests for the EvidenceOS PRIME platform.

## Overview

This test suite covers:

- **API Integration Tests** (`test_api_integration.py`) - Tests individual API endpoints and service interactions
- **E2E Workflow Tests** (`test_e2e_workflow.py`) - Tests complete user workflows from start to finish

## Prerequisites

### 1. Install Test Dependencies

```bash
cd tests/integration
pip install -r requirements.txt
```

### 2. Start Services

The tests require both backend services to be running:

```bash
# From project root
docker-compose up -d

# Or manually:
# Terminal 1: Main API
cd backend/api
python main.py

# Terminal 2: AI Copilot API
cd backend/api
python nlq.py
```

Wait for services to be healthy (~30 seconds).

## Running Tests

### Run All Tests

```bash
pytest -v
```

### Run Specific Test Suite

```bash
# API integration tests only
pytest test_api_integration.py -v

# E2E workflow tests only
pytest test_e2e_workflow.py -v
```

### Run by Test Class

```bash
# Run complete meta-analysis workflow
pytest test_e2e_workflow.py::TestCompleteMetaAnalysisWorkflow -v

# Run health economics workflow
pytest test_e2e_workflow.py::TestHealthEconomicsWorkflow -v
```

### Run Specific Test

```bash
pytest test_api_integration.py::test_validate_binary_data_success -v
```

### Skip Slow Tests

```bash
pytest -v -m "not slow"
```

### Run with Coverage

```bash
pytest --cov=../../backend --cov-report=html
# View coverage report: open coverage_html/index.html
```

## Test Markers

Tests are tagged with markers for selective execution:

- `@pytest.mark.slow` - Long-running tests
- `@pytest.mark.integration` - Integration tests
- `@pytest.mark.e2e` - End-to-end tests
- `@pytest.mark.api` - Requires API services
- `@pytest.mark.performance` - Performance/load tests

Example:
```bash
# Run only E2E tests
pytest -v -m e2e

# Run everything except slow tests
pytest -v -m "not slow"
```

## Test Structure

### API Integration Tests (`test_api_integration.py`)

Tests each API endpoint individually:

1. **Health Checks** - Verify services are operational
2. **Data Validation** - Test validation logic for binary, continuous, and time-to-event data
3. **Effect Size Computation** - Test OR, RR, MD, SMD calculations
4. **Evidence Objects** - Test evidence object creation and validation
5. **Health Economics** - Test PSA parameter generation
6. **AI Copilot** - Test NLQ parsing and interpretation endpoints
7. **Security** - Test CORS and rate limiting
8. **Error Handling** - Test proper error responses

### E2E Workflow Tests (`test_e2e_workflow.py`)

Tests complete user workflows:

1. **Complete Meta-Analysis Workflow**
   - Upload and validate trial data
   - Compute effect sizes
   - AI interprets heterogeneity
   - Request forest plot via NLQ
   - Create and validate evidence object

2. **Health Economics Workflow**
   - Generate PSA parameters from MA results
   - Interpret ICER
   - Request CEAC via NLQ

3. **Error Recovery Workflow**
   - Test validation error handling
   - Test unimplemented endpoint handling
   - Test unknown query handling

4. **Performance Tests**
   - Test validation response times
   - Test effect size computation performance

## Expected Test Duration

- **Fast tests**: ~2 minutes
- **All tests**: ~5 minutes
- **With slow tests**: ~10 minutes

## Troubleshooting

### Services Not Available

If tests fail with "API not available":

```bash
# Check service health
curl http://localhost:8000/health
curl http://localhost:8001/health

# Check Docker containers
docker-compose ps

# View logs
docker-compose logs -f
```

### Port Conflicts

If ports 8000 or 8001 are in use:

```bash
# Find and kill process using port
lsof -ti:8000 | xargs kill -9
lsof -ti:8001 | xargs kill -9
```

### Rate Limiting Errors

If you hit rate limits during testing:

```bash
# Wait 60 seconds or restart services to reset rate limits
docker-compose restart
```

### Test Failures

View detailed output:

```bash
pytest -v -s --tb=long
```

## CI/CD Integration

These tests are automatically run in the CI/CD pipeline:

```yaml
# .github/workflows/ci-cd.yml
jobs:
  integration-test:
    runs-on: ubuntu-latest
    steps:
      - name: Start services
        run: docker-compose up -d
      - name: Run integration tests
        run: |
          cd tests/integration
          pytest -v --cov --junit-xml=results.xml
```

## Writing New Tests

### Test Template

```python
def test_my_new_feature(api_client):
    """Test description"""
    # Arrange
    data = {"key": "value"}

    # Act
    response = requests.post(
        f"{api_client}/endpoint",
        json=data,
        timeout=10
    )

    # Assert
    assert response.status_code == 200
    result = response.json()
    assert result["expected_key"] == "expected_value"
```

### Best Practices

1. **Use fixtures** for common setup (api_client, sample_data, etc.)
2. **Test one thing** per test function
3. **Use descriptive names** - `test_validate_binary_data_with_duplicate_entries`
4. **Add timeouts** to prevent hanging tests
5. **Clean up** after tests (delete temporary files, etc.)
6. **Mark slow tests** with `@pytest.mark.slow`

## Test Coverage Goals

- **API Endpoints**: 100% of endpoints tested
- **Error Cases**: All error paths tested
- **User Workflows**: All major workflows tested
- **Code Coverage**: Target >80% for backend code

## Contributing

When adding new features:

1. Add unit tests in `tests/py/` or `tests/r/`
2. Add integration tests in `tests/integration/`
3. Update this README if adding new test categories
4. Ensure tests pass before submitting PR

## Related Documentation

- [Main README](../../README.md) - Project overview
- [Deployment Guide](../../DEPLOYMENT_GUIDE.md) - Deployment instructions
- [API Documentation](http://localhost:8000/docs) - Interactive API docs (when running)
