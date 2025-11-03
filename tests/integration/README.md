# Integration Tests - EvidenceOS PRIME V2.0

## Overview
Comprehensive integration tests for the EvidenceOS PRIME platform, covering end-to-end workflows across Python backend and R frontend.

## Test Files

### Python Integration Tests
**File:** `test_full_stack.py`

Tests the complete Python stack:
- Data validation pipeline
- ETL transformation pipeline
- Cache layer integration
- API endpoints (validation, transformation)
- End-to-end analysis workflows
- Error handling
- Concurrent request handling
- Data persistence

### R-Python Bridge Tests
**File:** `test_r_python_bridge.R`

Tests R-Python integration:
- API connectivity from R
- Data serialization between R and Python
- Request/response handling
- Error handling across language boundaries
- Concurrent requests from R
- Cache bridge functionality

## Running Tests

### Python Integration Tests

#### Prerequisites
```bash
cd /path/to/Metanew
pip install -r requirements.txt
```

#### Run All Integration Tests
```bash
pytest tests/integration/test_full_stack.py -v
```

#### Run Specific Test Class
```bash
pytest tests/integration/test_full_stack.py::TestFullStackIntegration -v
```

#### Run with Coverage
```bash
pytest tests/integration/test_full_stack.py --cov=backend --cov-report=html
```

### R Integration Tests

#### Prerequisites
1. Start Python backend:
```bash
cd backend/api
uvicorn main:app --reload --port 8000
```

2. Install R dependencies:
```R
install.packages(c("testthat", "httr", "jsonlite"))
```

#### Run Tests
```R
# From R console
testthat::test_file("tests/integration/test_r_python_bridge.R")
```

Or from command line:
```bash
Rscript -e "testthat::test_file('tests/integration/test_r_python_bridge.R')"
```

## Test Coverage

### What's Tested

✅ **Data Validation**
- Schema validation
- Type checking
- Missing data detection
- Business rule validation

✅ **Data Transformation**
- Effect size computation (continuous & binary)
- Data standardization
- Format conversions

✅ **Caching Layer**
- Cache save/retrieve
- Cache invalidation
- Query parameter hashing
- Metadata storage

✅ **API Integration**
- REST endpoint functionality
- Request/response serialization
- Error handling
- Rate limiting compliance

✅ **R-Python Bridge**
- Cross-language data transfer
- JSON serialization
- HTTP communication
- Error propagation

✅ **Concurrent Operations**
- Multiple simultaneous requests
- Cache consistency
- Thread safety

### Coverage Metrics
Run coverage reports to verify:
```bash
pytest tests/integration/ --cov=backend --cov-report=term-missing
```

Target coverage: **>80%** for integration tests

## Continuous Integration

### GitHub Actions Example
```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.10'

    - name: Install dependencies
      run: |
        pip install -r requirements.txt

    - name: Run integration tests
      run: |
        pytest tests/integration/ -v --cov=backend
```

## Troubleshooting

### Common Issues

**1. Import Errors**
```
ModuleNotFoundError: No module named 'backend'
```
**Solution:** Ensure you're running from project root and backend is in PYTHONPATH

**2. API Connection Errors (R tests)**
```
Error: cannot open the connection
```
**Solution:** Start the Python backend API before running R tests

**3. Cache Permission Errors**
```
PermissionError: [Errno 13] Permission denied
```
**Solution:** Ensure write permissions in the cache directory

### Debug Mode
Run tests with verbose output:
```bash
pytest tests/integration/ -v -s --tb=short
```

## Best Practices

1. **Test Independence**: Each test should be independent and not rely on others
2. **Clean Up**: Use fixtures to ensure proper setup/teardown
3. **Realistic Data**: Use realistic test data that mirrors production scenarios
4. **Error Cases**: Always test both success and failure paths
5. **Documentation**: Keep test documentation up to date

## Future Enhancements

- [ ] Add performance benchmarking tests
- [ ] Implement load testing scenarios
- [ ] Add security testing (OWASP compliance)
- [ ] Create smoke tests for production deployments
- [ ] Add E2E UI testing with Selenium/Cypress
- [ ] Implement contract testing between R and Python

## Support

For issues or questions about integration tests, contact the development team or open an issue on GitHub.
