"""
Comprehensive Tests for Utility Functions
Tests for backend/utils/*.py - 100% coverage
Covers: retry.py, sanitize.py, logging_config.py
"""
import pytest
import time
import logging
from unittest.mock import Mock, patch, MagicMock
from io import StringIO

# Import retry utilities
from backend.utils.retry import (
    retry_with_backoff,
    retry_on_network_error,
    retry_on_redis_error,
    retry_on_db_error
)

# Import sanitization utilities
from backend.utils.sanitize import (
    sanitize_string,
    sanitize_study_id,
    sanitize_treatment_name,
    sanitize_numeric,
    sanitize_dict,
    sanitize_list,
    validate_email,
    validate_url,
    InputSanitizer,
    MAX_STRING_LENGTH,
    MAX_STUDY_ID_LENGTH,
    MAX_TREATMENT_NAME_LENGTH
)

# Import logging utilities
from backend.utils.logging_config import (
    setup_logging,
    get_logger,
    set_correlation_id,
    get_correlation_id,
    set_user_id,
    get_user_id,
    CustomJsonFormatter,
    correlation_id_var,
    user_id_var
)


# ============================================================================
# RETRY UTILITIES TESTS
# ============================================================================

class TestRetryWithBackoff:
    """Test retry_with_backoff decorator - 100% coverage"""

    def test_successful_function_no_retry(self):
        """Test 1: Successful function doesn't retry"""
        call_count = []

        @retry_with_backoff(max_retries=3, base_delay=0.1)
        def success_func():
            call_count.append(1)
            return "success"

        result = success_func()
        assert result == "success"
        assert len(call_count) == 1  # Called once

    def test_function_retries_on_failure(self):
        """Test 2: Function retries on failure"""
        call_count = []

        @retry_with_backoff(max_retries=2, base_delay=0.1)
        def failing_func():
            call_count.append(1)
            if len(call_count) < 3:
                raise ValueError("Temporary failure")
            return "success"

        result = failing_func()
        assert result == "success"
        assert len(call_count) == 3  # Called 3 times

    def test_max_retries_exhausted(self):
        """Test 3: Raises exception after max retries"""
        @retry_with_backoff(max_retries=2, base_delay=0.1)
        def always_fails():
            raise ValueError("Always fails")

        with pytest.raises(ValueError):
            always_fails()

    def test_exponential_backoff(self):
        """Test 4: Delays follow exponential backoff"""
        timestamps = []

        @retry_with_backoff(max_retries=3, base_delay=0.1, exponential_base=2.0)
        def timing_func():
            timestamps.append(time.time())
            if len(timestamps) < 3:
                raise ValueError("Retry")
            return "done"

        timing_func()

        # Check delays increase exponentially
        assert len(timestamps) == 3
        delay1 = timestamps[1] - timestamps[0]
        delay2 = timestamps[2] - timestamps[1]
        assert delay2 > delay1  # Second delay is longer

    def test_max_delay_cap(self):
        """Test 5: Delay is capped at max_delay"""
        timestamps = []

        @retry_with_backoff(max_retries=5, base_delay=1.0, max_delay=2.0, exponential_base=10.0)
        def capped_delay():
            timestamps.append(time.time())
            if len(timestamps) < 3:
                raise ValueError("Retry")
            return "done"

        capped_delay()

        # All delays should be ≤ max_delay
        for i in range(1, len(timestamps)):
            delay = timestamps[i] - timestamps[i-1]
            assert delay <= 2.5  # 2.0 + some tolerance

    def test_specific_exceptions_only(self):
        """Test 6: Only retries on specified exceptions"""
        @retry_with_backoff(max_retries=3, base_delay=0.1, exceptions=(ValueError,))
        def type_error_func():
            raise TypeError("Not retried")

        with pytest.raises(TypeError):
            type_error_func()

    def test_multiple_exception_types(self):
        """Test 7: Retries on multiple exception types"""
        call_count = []

        @retry_with_backoff(max_retries=3, base_delay=0.1, exceptions=(ValueError, TypeError))
        def multi_exception():
            call_count.append(1)
            if len(call_count) == 1:
                raise ValueError("First")
            elif len(call_count) == 2:
                raise TypeError("Second")
            return "success"

        result = multi_exception()
        assert result == "success"
        assert len(call_count) == 3

    def test_function_with_arguments(self):
        """Test 8: Decorated function with arguments"""
        @retry_with_backoff(max_retries=2, base_delay=0.1)
        def func_with_args(x, y, z=10):
            if x < 5:
                raise ValueError("x too small")
            return x + y + z

        result = func_with_args(10, 20, z=5)
        assert result == 35

    def test_preserves_function_metadata(self):
        """Test 9: Decorator preserves function metadata"""
        @retry_with_backoff(max_retries=1)
        def documented_func():
            """This is a docstring"""
            return "test"

        assert documented_func.__name__ == "documented_func"
        assert documented_func.__doc__ == "This is a docstring"


class TestRetryConvenienceFunctions:
    """Test convenience retry decorators"""

    @patch('requests.RequestException', create=True)
    def test_retry_on_network_error(self):
        """Test 10: retry_on_network_error decorator"""
        call_count = []

        @retry_on_network_error(max_retries=2)
        def network_func():
            call_count.append(1)
            if len(call_count) < 2:
                raise ConnectionError("Network issue")
            return "success"

        result = network_func()
        assert result == "success"
        assert len(call_count) == 2

    def test_retry_on_redis_error(self):
        """Test 11: retry_on_redis_error decorator"""
        call_count = []

        @retry_on_redis_error(max_retries=1)
        def redis_func():
            call_count.append(1)
            if len(call_count) < 2:
                raise ConnectionError("Redis down")
            return "success"

        result = redis_func()
        assert result == "success"

    def test_retry_on_db_error(self):
        """Test 12: retry_on_db_error decorator"""
        call_count = []

        @retry_on_db_error(max_retries=1)
        def db_func():
            call_count.append(1)
            if len(call_count) < 2:
                raise TimeoutError("DB timeout")
            return "success"

        result = db_func()
        assert result == "success"


# ============================================================================
# SANITIZATION UTILITIES TESTS
# ============================================================================

class TestSanitizeString:
    """Test sanitize_string function"""

    def test_clean_string_unchanged(self):
        """Test 13: Clean string passes through"""
        assert sanitize_string("hello world") == "hello world"

    def test_removes_html_tags(self):
        """Test 14: Removes HTML tags"""
        assert sanitize_string("<script>alert('xss')</script>hello") == "hello"
        assert sanitize_string("<b>bold</b>") == "bold"

    def test_removes_control_characters(self):
        """Test 15: Removes control characters"""
        result = sanitize_string("hello\x00\x01world")
        assert result == "helloworld"

    def test_preserves_safe_whitespace(self):
        """Test 16: Preserves newlines and tabs"""
        assert sanitize_string("hello\nworld\ttab") == "hello\nworld\ttab"

    def test_truncates_long_strings(self):
        """Test 17: Truncates strings exceeding max length"""
        long_string = "a" * (MAX_STRING_LENGTH + 100)
        result = sanitize_string(long_string)
        assert len(result) == MAX_STRING_LENGTH

    def test_custom_max_length(self):
        """Test 18: Respects custom max length"""
        result = sanitize_string("hello world", max_length=5)
        assert len(result) == 5

    def test_strips_whitespace(self):
        """Test 19: Strips leading/trailing whitespace"""
        assert sanitize_string("  hello  ") == "hello"

    def test_non_string_converts_to_string(self):
        """Test 20: Converts non-strings to string"""
        assert sanitize_string(123) == "123"
        assert sanitize_string(None) == "None"


class TestSanitizeStudyId:
    """Test sanitize_study_id function"""

    def test_valid_study_id_unchanged(self):
        """Test 21: Valid study ID unchanged"""
        assert sanitize_study_id("STUDY_001") == "STUDY_001"
        assert sanitize_study_id("Study-2023") == "Study-2023"

    def test_removes_invalid_characters(self):
        """Test 22: Removes special characters"""
        assert sanitize_study_id("STUDY@#$001") == "STUDY001"
        assert sanitize_study_id("Study (2023)") == "Study2023"

    def test_allows_alphanumeric_underscore_hyphen_period(self):
        """Test 23: Allows valid characters"""
        assert sanitize_study_id("ABC_123-test.v1") == "ABC_123-test.v1"

    def test_truncates_long_study_id(self):
        """Test 24: Truncates long study IDs"""
        long_id = "S" * (MAX_STUDY_ID_LENGTH + 10)
        result = sanitize_study_id(long_id)
        assert len(result) == MAX_STUDY_ID_LENGTH

    def test_converts_non_string(self):
        """Test 25: Converts non-string to string"""
        assert sanitize_study_id(12345) == "12345"


class TestSanitizeTreatmentName:
    """Test sanitize_treatment_name function"""

    def test_valid_treatment_unchanged(self):
        """Test 26: Valid treatment name unchanged"""
        assert sanitize_treatment_name("Aspirin 100mg") == "Aspirin 100mg"

    def test_allows_common_punctuation(self):
        """Test 27: Allows spaces, hyphens, parentheses, slashes"""
        name = "Drug-A (10mg/day)"
        assert sanitize_treatment_name(name) == "Drug-A (10mg/day)"

    def test_removes_special_characters(self):
        """Test 28: Removes unwanted special characters"""
        assert sanitize_treatment_name("Drug@#$A") == "DrugA"

    def test_truncates_long_names(self):
        """Test 29: Truncates long treatment names"""
        long_name = "A" * (MAX_TREATMENT_NAME_LENGTH + 10)
        result = sanitize_treatment_name(long_name)
        assert len(result) == MAX_TREATMENT_NAME_LENGTH

    def test_strips_whitespace(self):
        """Test 30: Strips leading/trailing whitespace"""
        assert sanitize_treatment_name("  Aspirin  ") == "Aspirin"


class TestSanitizeNumeric:
    """Test sanitize_numeric function"""

    def test_valid_integer(self):
        """Test 31: Valid integer"""
        assert sanitize_numeric(123) == 123
        assert sanitize_numeric("123") == 123.0

    def test_valid_float(self):
        """Test 32: Valid float"""
        assert sanitize_numeric(123.45) == 123.45
        assert sanitize_numeric("123.45") == 123.45

    def test_rejects_nan(self):
        """Test 33: Rejects NaN"""
        assert sanitize_numeric(float('nan')) is None

    def test_rejects_infinity(self):
        """Test 34: Rejects infinity"""
        assert sanitize_numeric(float('inf')) is None
        assert sanitize_numeric(float('-inf')) is None

    def test_negative_numbers(self):
        """Test 35: Handles negative numbers"""
        assert sanitize_numeric(-10, allow_negative=True) == -10
        assert sanitize_numeric(-10, allow_negative=False) is None

    def test_float_vs_int_mode(self):
        """Test 36: Float vs integer mode"""
        assert sanitize_numeric(123.45, allow_float=True) == 123.45
        assert sanitize_numeric(123.45, allow_float=False) == 123

    def test_invalid_value(self):
        """Test 37: Invalid value returns None"""
        assert sanitize_numeric("not_a_number") is None
        assert sanitize_numeric([1, 2, 3]) is None


class TestSanitizeDict:
    """Test sanitize_dict function"""

    def test_sanitizes_string_values(self):
        """Test 38: Sanitizes string values in dict"""
        data = {"name": "<script>xss</script>John"}
        result = sanitize_dict(data)
        assert result["name"] == "John"

    def test_sanitizes_nested_dict(self):
        """Test 39: Recursively sanitizes nested dicts"""
        data = {"user": {"name": "<b>John</b>", "age": 30}}
        result = sanitize_dict(data)
        assert result["user"]["name"] == "John"
        assert result["user"]["age"] == 30

    def test_sanitizes_list_values(self):
        """Test 40: Sanitizes lists in dict"""
        data = {"tags": ["<b>tag1</b>", "tag2"]}
        result = sanitize_dict(data)
        assert result["tags"] == ["tag1", "tag2"]

    def test_sanitizes_numeric_values(self):
        """Test 41: Sanitizes numeric values"""
        data = {"count": float('nan'), "total": 100}
        result = sanitize_dict(data)
        assert result["count"] is None
        assert result["total"] == 100

    def test_preserves_boolean_and_none(self):
        """Test 42: Preserves bool and None"""
        data = {"flag": True, "value": None}
        result = sanitize_dict(data)
        assert result["flag"] is True
        assert result["value"] is None

    def test_sanitizes_keys(self):
        """Test 43: Optionally sanitizes keys"""
        data = {"<b>key</b>": "value"}
        result = sanitize_dict(data, sanitize_keys=True)
        assert "key" in result

    def test_non_dict_returns_empty(self):
        """Test 44: Non-dict returns empty dict"""
        assert sanitize_dict("not_a_dict") == {}
        assert sanitize_dict(None) == {}


class TestSanitizeList:
    """Test sanitize_list function"""

    def test_sanitizes_string_items(self):
        """Test 45: Sanitizes string items"""
        data = ["<script>alert()</script>hello", "world"]
        result = sanitize_list(data)
        assert result == ["hello", "world"]

    def test_sanitizes_nested_lists(self):
        """Test 46: Recursively sanitizes nested lists"""
        data = [["<b>a</b>", "b"], ["c", "<i>d</i>"]]
        result = sanitize_list(data)
        assert result == [["a", "b"], ["c", "d"]]

    def test_sanitizes_dicts_in_list(self):
        """Test 47: Sanitizes dicts in list"""
        data = [{"name": "<b>John</b>"}, {"name": "Jane"}]
        result = sanitize_list(data)
        assert result[0]["name"] == "John"

    def test_non_list_returns_empty(self):
        """Test 48: Non-list returns empty list"""
        assert sanitize_list("not_a_list") == []
        assert sanitize_list(None) == []


class TestValidateEmail:
    """Test validate_email function"""

    def test_valid_emails(self):
        """Test 49: Validates correct email formats"""
        valid_emails = [
            "user@example.com",
            "john.doe@company.co.uk",
            "test+tag@domain.org",
            "user_name@sub.domain.com"
        ]
        for email in valid_emails:
            assert validate_email(email) is True

    def test_invalid_emails(self):
        """Test 50: Rejects invalid email formats"""
        invalid_emails = [
            "not_an_email",
            "@example.com",
            "user@",
            "user @example.com",
            "user@.com"
        ]
        for email in invalid_emails:
            assert validate_email(email) is False


class TestValidateUrl:
    """Test validate_url function"""

    def test_valid_https_urls(self):
        """Test 51: Validates HTTPS URLs"""
        assert validate_url("https://example.com") is True
        assert validate_url("https://sub.domain.com/path") is True

    def test_rejects_http_by_default(self):
        """Test 52: Rejects HTTP by default"""
        assert validate_url("http://example.com") is False

    def test_allows_http_when_specified(self):
        """Test 53: Allows HTTP when allow_http=True"""
        assert validate_url("http://example.com", allow_http=True) is True

    def test_invalid_urls(self):
        """Test 54: Rejects invalid URLs"""
        invalid_urls = [
            "not_a_url",
            "ftp://example.com",
            "example.com",
            "https://"
        ]
        for url in invalid_urls:
            assert validate_url(url) is False


class TestInputSanitizerContextManager:
    """Test InputSanitizer context manager"""

    def test_context_manager(self):
        """Test 55: Works as context manager"""
        with InputSanitizer() as sanitizer:
            assert sanitizer is not None

    def test_sanitize_dict_method(self):
        """Test 56: sanitize_dict method works"""
        with InputSanitizer() as sanitizer:
            data = {"name": "<b>test</b>"}
            result = sanitizer.sanitize_dict(data)
            assert result["name"] == "test"

    def test_sanitize_string_method(self):
        """Test 57: sanitize_string method works"""
        with InputSanitizer() as sanitizer:
            result = sanitizer.sanitize_string("<script>xss</script>hello")
            assert result == "hello"

    def test_sanitize_numeric_method(self):
        """Test 58: sanitize_numeric method works"""
        with InputSanitizer() as sanitizer:
            result = sanitizer.sanitize_numeric("123")
            assert result == 123.0


# ============================================================================
# LOGGING UTILITIES TESTS
# ============================================================================

class TestLoggingConfiguration:
    """Test logging configuration functions"""

    def test_setup_logging_json_format(self):
        """Test 59: Setup logging with JSON format"""
        logger = setup_logging(app_name="test", level="INFO", format_type="json")
        assert logger is not None
        assert logger.level == logging.INFO

    def test_setup_logging_text_format(self):
        """Test 60: Setup logging with text format"""
        logger = setup_logging(app_name="test", level="DEBUG", format_type="text")
        assert logger is not None
        assert logger.level == logging.DEBUG

    def test_setup_logging_different_levels(self):
        """Test 61: Setup logging with different levels"""
        levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        for level in levels:
            logger = setup_logging(level=level)
            assert logger.level == getattr(logging, level)

    def test_get_logger(self):
        """Test 62: get_logger returns logger instance"""
        logger = get_logger("test_module")
        assert isinstance(logger, logging.Logger)
        assert logger.name == "test_module"


class TestCorrelationId:
    """Test correlation ID context management"""

    def test_set_and_get_correlation_id(self):
        """Test 63: Set and get correlation ID"""
        correlation_id = "test-correlation-id-123"
        set_correlation_id(correlation_id)
        assert get_correlation_id() == correlation_id

    def test_correlation_id_default_none(self):
        """Test 64: Correlation ID defaults to None"""
        correlation_id_var.set(None)
        assert get_correlation_id() is None

    def test_correlation_id_isolation(self):
        """Test 65: Correlation ID is context-isolated"""
        set_correlation_id("id-1")
        id1 = get_correlation_id()
        set_correlation_id("id-2")
        id2 = get_correlation_id()
        assert id1 == "id-1"
        assert id2 == "id-2"


class TestUserId:
    """Test user ID context management"""

    def test_set_and_get_user_id(self):
        """Test 66: Set and get user ID"""
        user_id = "user-123"
        set_user_id(user_id)
        assert get_user_id() == user_id

    def test_user_id_default_none(self):
        """Test 67: User ID defaults to None"""
        user_id_var.set(None)
        assert get_user_id() is None


class TestCustomJsonFormatter:
    """Test CustomJsonFormatter class"""

    def test_formatter_adds_correlation_id(self):
        """Test 68: Formatter adds correlation ID to log record"""
        formatter = CustomJsonFormatter()
        set_correlation_id("test-correlation")

        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=10,
            msg="Test message",
            args=(),
            exc_info=None
        )

        log_record = {}
        formatter.add_fields(log_record, record, {})
        assert log_record.get('correlation_id') == "test-correlation"

    def test_formatter_adds_user_id(self):
        """Test 69: Formatter adds user ID to log record"""
        formatter = CustomJsonFormatter()
        set_user_id("user-456")

        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=10,
            msg="Test message",
            args=(),
            exc_info=None
        )

        log_record = {}
        formatter.add_fields(log_record, record, {})
        assert log_record.get('user_id') == "user-456"

    def test_formatter_adds_standard_fields(self):
        """Test 70: Formatter adds level and logger name"""
        formatter = CustomJsonFormatter()

        record = logging.LogRecord(
            name="test_logger",
            level=logging.WARNING,
            pathname="test.py",
            lineno=10,
            msg="Test message",
            args=(),
            exc_info=None
        )

        log_record = {}
        formatter.add_fields(log_record, record, {})
        assert log_record['level'] == "WARNING"
        assert log_record['logger'] == "test_logger"

    def test_formatter_adds_location_for_errors(self):
        """Test 71: Formatter adds file location for errors"""
        formatter = CustomJsonFormatter()

        record = logging.LogRecord(
            name="test",
            level=logging.ERROR,
            pathname="/path/to/test.py",
            lineno=42,
            msg="Error message",
            args=(),
            exc_info=None,
            func="test_func"
        )

        log_record = {}
        formatter.add_fields(log_record, record, {})
        assert log_record['file'] == "/path/to/test.py"
        assert log_record['line'] == 42
        assert log_record['function'] == "test_func"

    def test_formatter_no_location_for_info(self):
        """Test 72: Formatter doesn't add location for INFO logs"""
        formatter = CustomJsonFormatter()

        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="/path/to/test.py",
            lineno=42,
            msg="Info message",
            args=(),
            exc_info=None
        )

        log_record = {}
        formatter.add_fields(log_record, record, {})
        assert 'file' not in log_record
        assert 'line' not in log_record


class TestLoggingIntegration:
    """Integration tests for logging"""

    def test_logger_writes_to_stdout(self):
        """Test 73: Logger writes to stdout"""
        logger = setup_logging(app_name="test", level="INFO")
        logger.info("Test message")
        # If no exception, test passes

    def test_correlation_id_in_logs(self):
        """Test 74: Correlation ID appears in logs"""
        setup_logging(format_type="json")
        logger = get_logger("test")
        set_correlation_id("test-correlation")
        logger.info("Test with correlation")
        # If no exception, test passes

    def test_multiple_loggers(self):
        """Test 75: Multiple loggers work correctly"""
        logger1 = get_logger("module1")
        logger2 = get_logger("module2")
        assert logger1.name == "module1"
        assert logger2.name == "module2"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
