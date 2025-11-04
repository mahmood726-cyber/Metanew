"""
Comprehensive Tests for Custom Exceptions
Tests for backend/exceptions.py - 100% coverage
"""
import pytest
from backend.exceptions import (
    EvidenceOSError,
    ValidationError,
    ComputationError,
    DataNotFoundError,
    ConfigurationError,
    AuthenticationError,
    AuthorizationError,
    RateLimitError,
    ResourceExhaustedError,
    CacheError,
    ExternalServiceError
)


class TestEvidenceOSError:
    """Test base EvidenceOSError class"""

    def test_basic_error(self):
        """Test 1: Basic error with message"""
        error = EvidenceOSError("Something went wrong")
        assert str(error) == "Something went wrong"
        assert error.message == "Something went wrong"
        assert error.details == {}

    def test_error_with_details(self):
        """Test 2: Error with details dictionary"""
        details = {"code": 400, "field": "study_id"}
        error = EvidenceOSError("Error occurred", details=details)
        assert error.message == "Error occurred"
        assert error.details == details
        assert error.details["code"] == 400

    def test_error_inheritance(self):
        """Test 3: Error inherits from Exception"""
        error = EvidenceOSError("Test")
        assert isinstance(error, Exception)

    def test_error_can_be_raised(self):
        """Test 4: Error can be raised and caught"""
        with pytest.raises(EvidenceOSError) as exc_info:
            raise EvidenceOSError("Test error")
        assert "Test error" in str(exc_info.value)

    def test_error_details_none_converts_to_empty_dict(self):
        """Test 5: None details converts to empty dict"""
        error = EvidenceOSError("Test", details=None)
        assert error.details == {}


class TestValidationError:
    """Test ValidationError class"""

    def test_validation_error_basic(self):
        """Test 6: Basic validation error"""
        error = ValidationError(field="events", message="Events > n")
        assert error.field == "events"
        assert "Events > n" in str(error)
        assert error.study_id is None
        assert error.value is None

    def test_validation_error_with_study_id(self):
        """Test 7: Validation error with study ID"""
        error = ValidationError(
            field="n",
            message="n must be positive",
            study_id="STUDY_001"
        )
        assert error.field == "n"
        assert error.study_id == "STUDY_001"
        assert error.details["study_id"] == "STUDY_001"

    def test_validation_error_with_value(self):
        """Test 8: Validation error with invalid value"""
        error = ValidationError(
            field="events",
            message="Invalid value",
            value=-5
        )
        assert error.value == -5
        assert error.details["value"] == -5

    def test_validation_error_complete(self):
        """Test 9: Validation error with all parameters"""
        error = ValidationError(
            field="yi",
            message="Effect size invalid",
            study_id="STUDY_123",
            value=float('nan')
        )
        assert error.field == "yi"
        assert error.study_id == "STUDY_123"
        assert error.details["field"] == "yi"

    def test_validation_error_inheritance(self):
        """Test 10: ValidationError inherits from EvidenceOSError"""
        error = ValidationError("test", "message")
        assert isinstance(error, EvidenceOSError)
        assert isinstance(error, Exception)


class TestComputationError:
    """Test ComputationError class"""

    def test_computation_error_basic(self):
        """Test 11: Basic computation error"""
        error = ComputationError(
            operation="odds_ratio",
            message="Cannot compute OR with zero events"
        )
        assert error.operation == "odds_ratio"
        assert "Cannot compute OR" in str(error)

    def test_computation_error_with_data_info(self):
        """Test 12: Computation error with data info"""
        data_info = {"n_studies": 5, "measure": "OR"}
        error = ComputationError(
            operation="meta_analysis",
            message="Computation failed",
            data_info=data_info
        )
        assert error.data_info == data_info
        assert error.details["n_studies"] == 5
        assert error.details["operation"] == "meta_analysis"

    def test_computation_error_none_data_info(self):
        """Test 13: Computation error with None data_info"""
        error = ComputationError(
            operation="transform",
            message="Failed",
            data_info=None
        )
        assert error.data_info == {}

    def test_computation_error_inheritance(self):
        """Test 14: ComputationError inherits from EvidenceOSError"""
        error = ComputationError("test", "message")
        assert isinstance(error, EvidenceOSError)


class TestDataNotFoundError:
    """Test DataNotFoundError class"""

    def test_data_not_found_basic(self):
        """Test 15: Basic data not found error"""
        error = DataNotFoundError(resource="study")
        assert error.resource == "study"
        assert "study not found" in str(error)
        assert error.identifier is None

    def test_data_not_found_with_identifier(self):
        """Test 16: Data not found with identifier"""
        error = DataNotFoundError(
            resource="analysis",
            identifier="ANALYSIS_456"
        )
        assert error.resource == "analysis"
        assert error.identifier == "ANALYSIS_456"
        assert "ANALYSIS_456" in str(error)

    def test_data_not_found_details(self):
        """Test 17: Data not found details"""
        error = DataNotFoundError(
            resource="cache_entry",
            identifier="key_123"
        )
        assert error.details["resource"] == "cache_entry"
        assert error.details["identifier"] == "key_123"

    def test_data_not_found_inheritance(self):
        """Test 18: DataNotFoundError inherits from EvidenceOSError"""
        error = DataNotFoundError("test")
        assert isinstance(error, EvidenceOSError)


class TestConfigurationError:
    """Test ConfigurationError class"""

    def test_configuration_error_basic(self):
        """Test 19: Basic configuration error"""
        error = ConfigurationError(
            setting="REDIS_HOST",
            message="Redis host not configured"
        )
        assert error.setting == "REDIS_HOST"
        assert "Redis host" in str(error)

    def test_configuration_error_details(self):
        """Test 20: Configuration error details"""
        error = ConfigurationError(
            setting="DATABASE_URL",
            message="Invalid database URL"
        )
        assert error.details["setting"] == "DATABASE_URL"

    def test_configuration_error_inheritance(self):
        """Test 21: ConfigurationError inherits from EvidenceOSError"""
        error = ConfigurationError("test", "message")
        assert isinstance(error, EvidenceOSError)


class TestAuthenticationError:
    """Test AuthenticationError class"""

    def test_authentication_error_default(self):
        """Test 22: Authentication error with default message"""
        error = AuthenticationError()
        assert "Authentication required" in str(error)

    def test_authentication_error_custom_message(self):
        """Test 23: Authentication error with custom message"""
        error = AuthenticationError("Invalid API key")
        assert "Invalid API key" in str(error)

    def test_authentication_error_inheritance(self):
        """Test 24: AuthenticationError inherits from EvidenceOSError"""
        error = AuthenticationError()
        assert isinstance(error, EvidenceOSError)


class TestAuthorizationError:
    """Test AuthorizationError class"""

    def test_authorization_error_default(self):
        """Test 25: Authorization error with default message"""
        error = AuthorizationError()
        assert "Insufficient permissions" in str(error)

    def test_authorization_error_custom_message(self):
        """Test 26: Authorization error with custom message"""
        error = AuthorizationError("Access denied to resource")
        assert "Access denied" in str(error)

    def test_authorization_error_inheritance(self):
        """Test 27: AuthorizationError inherits from EvidenceOSError"""
        error = AuthorizationError()
        assert isinstance(error, EvidenceOSError)


class TestRateLimitError:
    """Test RateLimitError class"""

    def test_rate_limit_error_basic(self):
        """Test 28: Basic rate limit error"""
        error = RateLimitError(limit=60)
        assert "60 requests per minute" in str(error)
        assert error.details["limit"] == 60
        assert error.details["window"] == "minute"

    def test_rate_limit_error_custom_window(self):
        """Test 29: Rate limit error with custom window"""
        error = RateLimitError(limit=1000, window="hour")
        assert "1000 requests per hour" in str(error)
        assert error.details["window"] == "hour"

    def test_rate_limit_error_inheritance(self):
        """Test 30: RateLimitError inherits from EvidenceOSError"""
        error = RateLimitError(60)
        assert isinstance(error, EvidenceOSError)


class TestResourceExhaustedError:
    """Test ResourceExhaustedError class"""

    def test_resource_exhausted_basic(self):
        """Test 31: Basic resource exhausted error"""
        error = ResourceExhaustedError(
            resource="studies",
            limit=1000,
            current=1500
        )
        assert "studies limit exceeded" in str(error)
        assert "1500/1000" in str(error)

    def test_resource_exhausted_details(self):
        """Test 32: Resource exhausted details"""
        error = ResourceExhaustedError(
            resource="observations",
            limit=10000,
            current=15000
        )
        assert error.details["resource"] == "observations"
        assert error.details["limit"] == 10000
        assert error.details["current"] == 15000

    def test_resource_exhausted_inheritance(self):
        """Test 33: ResourceExhaustedError inherits from EvidenceOSError"""
        error = ResourceExhaustedError("test", 100, 200)
        assert isinstance(error, EvidenceOSError)


class TestCacheError:
    """Test CacheError class"""

    def test_cache_error_basic(self):
        """Test 34: Basic cache error"""
        error = CacheError(
            operation="get",
            message="Cache retrieval failed"
        )
        assert error.operation == "get"
        assert "Cache retrieval" in str(error)

    def test_cache_error_operations(self):
        """Test 35: Cache error with different operations"""
        operations = ["get", "set", "delete", "clear", "connect"]
        for op in operations:
            error = CacheError(operation=op, message=f"Failed {op}")
            assert error.operation == op
            assert error.details["operation"] == op

    def test_cache_error_inheritance(self):
        """Test 36: CacheError inherits from EvidenceOSError"""
        error = CacheError("test", "message")
        assert isinstance(error, EvidenceOSError)


class TestExternalServiceError:
    """Test ExternalServiceError class"""

    def test_external_service_error_basic(self):
        """Test 37: Basic external service error"""
        error = ExternalServiceError(
            service="OpenAI",
            message="API request failed"
        )
        assert error.service == "OpenAI"
        assert "API request failed" in str(error)
        assert error.status_code is None

    def test_external_service_error_with_status_code(self):
        """Test 38: External service error with status code"""
        error = ExternalServiceError(
            service="Redis",
            message="Connection refused",
            status_code=503
        )
        assert error.service == "Redis"
        assert error.status_code == 503
        assert error.details["status_code"] == 503

    def test_external_service_error_details(self):
        """Test 39: External service error details"""
        error = ExternalServiceError(
            service="Postgres",
            message="Database timeout",
            status_code=408
        )
        assert error.details["service"] == "Postgres"
        assert error.details["status_code"] == 408

    def test_external_service_error_inheritance(self):
        """Test 40: ExternalServiceError inherits from EvidenceOSError"""
        error = ExternalServiceError("test", "message")
        assert isinstance(error, EvidenceOSError)


class TestExceptionRaising:
    """Test exceptions can be raised and caught"""

    def test_raise_validation_error(self):
        """Test 41: Raise and catch ValidationError"""
        with pytest.raises(ValidationError) as exc_info:
            raise ValidationError("field", "message")
        assert exc_info.value.field == "field"

    def test_raise_computation_error(self):
        """Test 42: Raise and catch ComputationError"""
        with pytest.raises(ComputationError):
            raise ComputationError("op", "message")

    def test_raise_data_not_found_error(self):
        """Test 43: Raise and catch DataNotFoundError"""
        with pytest.raises(DataNotFoundError):
            raise DataNotFoundError("resource")

    def test_catch_as_base_exception(self):
        """Test 44: Catch derived exceptions as base EvidenceOSError"""
        with pytest.raises(EvidenceOSError):
            raise ValidationError("field", "message")

    def test_catch_as_exception(self):
        """Test 45: Catch as general Exception"""
        with pytest.raises(Exception):
            raise AuthenticationError("Test")


class TestExceptionChaining:
    """Test exception chaining and context"""

    def test_exception_from_another(self):
        """Test 46: Chain exceptions with 'from'"""
        try:
            try:
                raise ValueError("Original error")
            except ValueError as e:
                raise ComputationError("compute", "Failed computation") from e
        except ComputationError as exc:
            assert exc.__cause__ is not None
            assert isinstance(exc.__cause__, ValueError)

    def test_exception_traceback(self):
        """Test 47: Exceptions preserve traceback"""
        try:
            raise ValidationError("field", "Test error")
        except ValidationError as e:
            assert e.__traceback__ is not None


class TestErrorMessages:
    """Test error message formatting"""

    def test_error_messages_descriptive(self):
        """Test 48: Error messages are descriptive"""
        errors = [
            ValidationError("events", "Events exceed n", "S1", 150),
            ComputationError("OR", "Cannot compute OR with zero events"),
            DataNotFoundError("study", "STUDY_001"),
            RateLimitError(60, "minute"),
            ResourceExhaustedError("studies", 1000, 1500)
        ]

        for error in errors:
            msg = str(error)
            assert len(msg) > 5  # Not empty
            assert msg != ""


class TestErrorDetails:
    """Test error details dictionary"""

    def test_all_errors_have_details(self):
        """Test 49: All errors have details attribute"""
        errors = [
            EvidenceOSError("test"),
            ValidationError("f", "m"),
            ComputationError("o", "m"),
            DataNotFoundError("r"),
            ConfigurationError("s", "m"),
            AuthenticationError(),
            AuthorizationError(),
            RateLimitError(60),
            ResourceExhaustedError("r", 100, 200),
            CacheError("o", "m"),
            ExternalServiceError("s", "m")
        ]

        for error in errors:
            assert hasattr(error, 'details')
            assert isinstance(error.details, dict)

    def test_details_accessible(self):
        """Test 50: Error details are accessible"""
        error = ValidationError(
            field="yi",
            message="Invalid",
            study_id="S1",
            value=999
        )
        # Access via attribute
        assert error.details["field"] == "yi"
        assert error.details["study_id"] == "S1"
        # Access via property
        assert error.field == "yi"
        assert error.study_id == "S1"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
