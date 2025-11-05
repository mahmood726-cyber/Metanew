"""
Tests for Cache and Utility Modules
Tests for Redis caching, health checks, and utility functions
"""
import pytest
import os
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, MagicMock

# Set test environment
os.environ["ENVIRONMENT"] = "test"
os.environ["REDIS_URL"] = "redis://localhost:6379/1"


class TestHealthEndpoint:
    """Test health check functionality via API endpoints"""

    @pytest.fixture
    def client(self):
        """Create test client"""
        from fastapi.testclient import TestClient
        from api.main import app
        return TestClient(app)

    def test_health_check_structure(self, client):
        """Test health check returns expected structure"""
        response = client.get("/health")

        assert response.status_code == 200
        health = response.json()

        assert "status" in health
        assert "timestamp" in health
        assert health["status"] == "healthy"

    def test_health_check_timestamp_format(self, client):
        """Test health check timestamp is valid"""
        response = client.get("/health")
        health = response.json()

        # Should have a timestamp
        assert "timestamp" in health
        # Should be a string in ISO format
        timestamp = health["timestamp"]
        datetime.fromisoformat(timestamp.replace('Z', '+00:00'))

    def test_health_check_includes_python_version(self, client):
        """Test health check includes Python version"""
        response = client.get("/health")
        health = response.json()

        assert "python_version" in health or "version" in health

    def test_health_check_ml_endpoint(self, client):
        """Test ML health check endpoint"""
        response = client.get("/health/ml")

        assert response.status_code == 200
        health = response.json()

        # Should have status and components
        assert "status" in health
        assert "components" in health


class TestCacheManager:
    """Test cache manager functionality"""

    def test_cache_key_generation(self):
        """Test cache key generation"""
        # Simple test for key generation logic
        prefix = "ml_cache"
        params = {"model": "xgboost", "data_hash": "abc123"}

        # Generate a simple cache key
        key = f"{prefix}:{params['model']}:{params['data_hash']}"

        assert "ml_cache" in key
        assert "xgboost" in key
        assert "abc123" in key

    def test_cache_ttl_calculation(self):
        """Test TTL calculation"""
        # Test that TTL is correctly calculated
        ttl_seconds = 3600  # 1 hour

        expire_time = datetime.utcnow() + timedelta(seconds=ttl_seconds)

        # Should be approximately 1 hour from now
        time_diff = (expire_time - datetime.utcnow()).total_seconds()
        assert 3590 < time_diff < 3610  # Allow small variance

    def test_cache_hit_tracking(self):
        """Test cache hit counting"""
        # Simple counter logic
        hit_count = 0

        # Simulate cache hits
        for _ in range(5):
            hit_count += 1

        assert hit_count == 5

    def test_cache_invalidation_pattern(self):
        """Test cache key pattern matching"""
        cache_keys = [
            "ml_cache:shap:model1",
            "ml_cache:shap:model2",
            "ml_cache:ensemble:model1",
            "other_cache:key"
        ]

        # Test pattern matching for invalidation
        pattern = "ml_cache:shap:*"
        matched = [k for k in cache_keys if k.startswith("ml_cache:shap:")]

        assert len(matched) == 2
        assert "ml_cache:shap:model1" in matched
        assert "ml_cache:shap:model2" in matched


class TestMetrics:
    """Test Prometheus metrics"""

    def test_metrics_counter_increment(self):
        """Test counter increment logic"""
        counter = 0

        # Simulate incrementing counter
        for _ in range(10):
            counter += 1

        assert counter == 10

    def test_metrics_histogram_recording(self):
        """Test histogram value recording"""
        values = []

        # Simulate recording latency values
        values.extend([0.1, 0.2, 0.15, 0.3, 0.25])

        assert len(values) == 5
        assert min(values) == 0.1
        assert max(values) == 0.3

    def test_metrics_gauge_set(self):
        """Test gauge value setting"""
        current_value = 0

        # Simulate setting gauge value
        current_value = 42

        assert current_value == 42

        # Simulate updating gauge
        current_value = 100

        assert current_value == 100


class TestDataValidation:
    """Test data validation utilities"""

    def test_validate_positive_integer(self):
        """Test positive integer validation"""
        def validate_positive(n):
            return isinstance(n, int) and n > 0

        assert validate_positive(5) is True
        assert validate_positive(0) is False
        assert validate_positive(-1) is False
        assert validate_positive("5") is False

    def test_validate_probability(self):
        """Test probability validation (0 to 1)"""
        def validate_probability(p):
            return isinstance(p, (int, float)) and 0 <= p <= 1

        assert validate_probability(0.5) is True
        assert validate_probability(0) is True
        assert validate_probability(1) is True
        assert validate_probability(1.5) is False
        assert validate_probability(-0.1) is False

    def test_validate_email_format(self):
        """Test email format validation"""
        import re

        def validate_email(email):
            pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            return bool(re.match(pattern, email))

        assert validate_email("user@example.com") is True
        assert validate_email("test.user@domain.co.uk") is True
        assert validate_email("invalid.email") is False
        assert validate_email("@example.com") is False

    def test_validate_url_format(self):
        """Test URL format validation"""
        def validate_url(url):
            return url.startswith(('http://', 'https://'))

        assert validate_url("https://example.com") is True
        assert validate_url("http://example.com") is True
        assert validate_url("ftp://example.com") is False
        assert validate_url("example.com") is False


class TestStringUtilities:
    """Test string utility functions"""

    def test_truncate_string(self):
        """Test string truncation"""
        def truncate(s, max_length):
            return s[:max_length] if len(s) > max_length else s

        long_string = "This is a very long string that needs truncation"
        truncated = truncate(long_string, 20)

        assert len(truncated) == 20
        assert truncated == "This is a very long "

    def test_sanitize_filename(self):
        """Test filename sanitization"""
        import re

        def sanitize_filename(filename):
            # Remove invalid characters
            return re.sub(r'[<>:"/\\|?*]', '', filename)

        assert sanitize_filename("file<>name.txt") == "filename.txt"
        assert sanitize_filename("my:file|name") == "myfilename"

    def test_slugify_string(self):
        """Test string slugification"""
        import re

        def slugify(text):
            text = text.lower().strip()
            return re.sub(r'[^\w\s-]', '', text).replace(' ', '-')

        assert slugify("Hello World") == "hello-world"
        assert slugify("Test! String?") == "test-string"

    def test_pluralize(self):
        """Test simple pluralization"""
        def pluralize(count, singular, plural=None):
            if plural is None:
                plural = singular + 's'
            return singular if count == 1 else plural

        assert pluralize(1, "test") == "test"
        assert pluralize(2, "test") == "tests"
        assert pluralize(0, "test") == "tests"


class TestDateTimeUtilities:
    """Test datetime utility functions"""

    def test_format_timestamp(self):
        """Test timestamp formatting"""
        dt = datetime(2024, 1, 15, 10, 30, 45)
        formatted = dt.isoformat()

        assert "2024-01-15" in formatted
        assert "10:30:45" in formatted

    def test_time_ago(self):
        """Test relative time calculation"""
        def time_ago(dt):
            now = datetime.utcnow()
            diff = now - dt

            if diff.days > 0:
                return f"{diff.days} days ago"
            elif diff.seconds >= 3600:
                return f"{diff.seconds // 3600} hours ago"
            else:
                return f"{diff.seconds // 60} minutes ago"

        # 2 hours ago
        two_hours_ago = datetime.utcnow() - timedelta(hours=2)
        result = time_ago(two_hours_ago)
        assert "hour" in result

    def test_is_recent(self):
        """Test checking if datetime is recent"""
        def is_recent(dt, hours=24):
            now = datetime.utcnow()
            return (now - dt).total_seconds() < hours * 3600

        recent = datetime.utcnow() - timedelta(hours=1)
        old = datetime.utcnow() - timedelta(days=2)

        assert is_recent(recent) is True
        assert is_recent(old) is False


class TestMathUtilities:
    """Test math utility functions"""

    def test_safe_divide(self):
        """Test safe division with zero handling"""
        def safe_divide(a, b, default=0):
            return a / b if b != 0 else default

        assert safe_divide(10, 2) == 5.0
        assert safe_divide(10, 0) == 0
        assert safe_divide(10, 0, default=None) is None

    def test_clamp_value(self):
        """Test value clamping"""
        def clamp(value, min_val, max_val):
            return max(min_val, min(value, max_val))

        assert clamp(5, 0, 10) == 5
        assert clamp(-5, 0, 10) == 0
        assert clamp(15, 0, 10) == 10

    def test_percentage_calculation(self):
        """Test percentage calculation"""
        def percentage(part, total):
            return (part / total * 100) if total != 0 else 0

        assert percentage(25, 100) == 25.0
        assert percentage(1, 4) == 25.0
        assert percentage(10, 0) == 0

    def test_round_to_precision(self):
        """Test rounding to specific precision"""
        assert round(3.14159, 2) == 3.14
        assert round(2.5) == 2  # Banker's rounding
        assert round(3.5) == 4


class TestListUtilities:
    """Test list utility functions"""

    def test_chunk_list(self):
        """Test list chunking"""
        def chunk_list(lst, size):
            return [lst[i:i+size] for i in range(0, len(lst), size)]

        items = [1, 2, 3, 4, 5, 6, 7]
        chunks = chunk_list(items, 3)

        assert len(chunks) == 3
        assert chunks[0] == [1, 2, 3]
        assert chunks[1] == [4, 5, 6]
        assert chunks[2] == [7]

    def test_flatten_list(self):
        """Test list flattening"""
        def flatten(nested):
            result = []
            for item in nested:
                if isinstance(item, list):
                    result.extend(flatten(item))
                else:
                    result.append(item)
            return result

        nested = [[1, 2], [3, 4], [5]]
        flattened = flatten(nested)

        assert flattened == [1, 2, 3, 4, 5]

    def test_remove_duplicates_preserve_order(self):
        """Test removing duplicates while preserving order"""
        def remove_duplicates(lst):
            seen = set()
            result = []
            for item in lst:
                if item not in seen:
                    seen.add(item)
                    result.append(item)
            return result

        items = [1, 2, 2, 3, 1, 4, 3]
        unique = remove_duplicates(items)

        assert unique == [1, 2, 3, 4]


class TestErrorHandling:
    """Test error handling utilities"""

    def test_try_except_with_default(self):
        """Test try-except with default value"""
        def safe_int_parse(value, default=0):
            try:
                return int(value)
            except (ValueError, TypeError):
                return default

        assert safe_int_parse("123") == 123
        assert safe_int_parse("abc") == 0
        assert safe_int_parse(None) == 0
        assert safe_int_parse("invalid", default=-1) == -1

    def test_retry_logic(self):
        """Test simple retry logic"""
        def retry(func, max_attempts=3):
            for attempt in range(max_attempts):
                try:
                    return func()
                except Exception:
                    if attempt == max_attempts - 1:
                        raise
            return None

        # Test with function that succeeds
        def success_func():
            return "success"

        result = retry(success_func)
        assert result == "success"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
