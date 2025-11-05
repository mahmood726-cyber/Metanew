#!/bin/bash
# Run ML Integration Tests

echo "=========================================="
echo "EvidenceOS ML Integration Tests"
echo "=========================================="
echo ""

# Check if Redis is running
echo "Checking Redis connection..."
redis-cli ping > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Redis is running"
else
    echo "⚠ Redis is not running - caching tests will be skipped"
    echo "  To start Redis: docker-compose up -d redis"
fi

echo ""
echo "Running tests..."
echo ""

# Run pytest with verbose output
cd /home/user/Metanew/backend
python -m pytest tests/test_ml_integration.py -v -s --tb=short --color=yes

# Check exit code
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ All tests passed!"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "✗ Some tests failed"
    echo "=========================================="
    exit 1
fi
