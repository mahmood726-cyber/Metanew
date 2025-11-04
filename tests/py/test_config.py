"""
Comprehensive Tests for Configuration Management
Tests for backend/config.py - 100% coverage
"""
import pytest
import os
from unittest.mock import patch
from backend.config import Settings, get_settings, settings


class TestSettings:
    """Test Settings class - 100% coverage"""

    def test_default_settings(self):
        """Test 1: Default settings are loaded correctly"""
        s = Settings()
        assert s.API_V1_STR == "/api/v1"
        assert s.PROJECT_NAME == "EvidenceOS PRIME API"
        assert s.VERSION == "1.0.0"
        assert s.HOST == "0.0.0.0"
        assert s.PORT == 8000

    def test_security_settings(self):
        """Test 2: Security settings have secure defaults"""
        s = Settings()
        assert s.SECRET_KEY is not None
        assert len(s.SECRET_KEY) > 10
        assert s.ALGORITHM == "HS256"
        assert s.ACCESS_TOKEN_EXPIRE_MINUTES == 30

    def test_cors_settings(self):
        """Test 3: CORS settings are whitelisted (not *)"""
        s = Settings()
        assert isinstance(s.ALLOWED_ORIGINS, list)
        assert len(s.ALLOWED_ORIGINS) > 0
        assert "http://localhost:3838" in s.ALLOWED_ORIGINS
        assert "*" not in s.ALLOWED_ORIGINS  # Critical security check

    def test_rate_limit_settings(self):
        """Test 4: Rate limiting is configured"""
        s = Settings()
        assert s.RATE_LIMIT_PER_MINUTE == 60
        assert s.RATE_LIMIT_BURST == 100

    def test_redis_settings(self):
        """Test 5: Redis cache settings"""
        s = Settings()
        assert s.REDIS_HOST == "localhost"
        assert s.REDIS_PORT == 6379
        assert s.REDIS_DB == 0
        assert s.CACHE_TTL == 3600
        assert s.ENABLE_CACHE is True

    def test_logging_settings(self):
        """Test 6: Logging configuration"""
        s = Settings()
        assert s.LOG_LEVEL == "INFO"
        assert s.LOG_FORMAT in ["json", "text"]

    def test_monitoring_settings(self):
        """Test 7: Monitoring is enabled"""
        s = Settings()
        assert s.ENABLE_METRICS is True
        assert s.METRICS_PORT == 9090

    def test_api_key_settings(self):
        """Test 8: API key configuration"""
        s = Settings()
        assert s.API_KEY_HEADER == "X-API-Key"
        assert isinstance(s.VALID_API_KEYS, list)

    def test_file_upload_settings(self):
        """Test 9: File upload limits"""
        s = Settings()
        assert s.MAX_UPLOAD_SIZE == 10 * 1024 * 1024  # 10MB
        assert isinstance(s.ALLOWED_UPLOAD_EXTENSIONS, list)
        assert ".csv" in s.ALLOWED_UPLOAD_EXTENSIONS
        assert ".xlsx" in s.ALLOWED_UPLOAD_EXTENSIONS

    def test_analysis_limits(self):
        """Test 10: Analysis resource limits"""
        s = Settings()
        assert s.MAX_STUDIES == 1000
        assert s.MAX_OBSERVATIONS == 10000

    def test_feature_flags(self):
        """Test 11: Feature flags"""
        s = Settings()
        assert isinstance(s.ENABLE_BAYESIAN_MA, bool)
        assert s.ENABLE_AI_COPILOT is True

    @patch.dict(os.environ, {"API_V1_STR": "/api/v2", "PORT": "9000"})
    def test_environment_override(self):
        """Test 12: Environment variables override defaults"""
        # Clear cache
        get_settings.cache_clear()
        s = Settings()
        assert s.API_V1_STR == "/api/v2"
        assert s.PORT == 9000
        get_settings.cache_clear()

    @patch.dict(os.environ, {"LOG_LEVEL": "DEBUG", "ENABLE_CACHE": "false"})
    def test_environment_override_boolean_and_string(self):
        """Test 13: Environment variables override booleans and strings"""
        get_settings.cache_clear()
        s = Settings()
        assert s.LOG_LEVEL == "DEBUG"
        assert s.ENABLE_CACHE is False
        get_settings.cache_clear()

    @patch.dict(os.environ, {"MAX_STUDIES": "500", "RATE_LIMIT_PER_MINUTE": "120"})
    def test_environment_override_integers(self):
        """Test 14: Environment variables override integers"""
        get_settings.cache_clear()
        s = Settings()
        assert s.MAX_STUDIES == 500
        assert s.RATE_LIMIT_PER_MINUTE == 120
        get_settings.cache_clear()

    @patch.dict(os.environ, {"ALLOWED_ORIGINS": '["http://example.com","https://app.com"]'})
    def test_environment_override_list(self):
        """Test 15: Environment variables override lists"""
        get_settings.cache_clear()
        s = Settings()
        assert "http://example.com" in s.ALLOWED_ORIGINS
        assert "https://app.com" in s.ALLOWED_ORIGINS
        get_settings.cache_clear()

    def test_database_url_optional(self):
        """Test 16: Database URL is optional (None by default)"""
        s = Settings()
        assert s.DATABASE_URL is None

    def test_redis_password_optional(self):
        """Test 17: Redis password is optional"""
        s = Settings()
        assert s.REDIS_PASSWORD is None

    def test_config_class_attributes(self):
        """Test 18: Config class has correct attributes"""
        assert Settings.Config.env_file == ".env"
        assert Settings.Config.env_file_encoding == "utf-8"
        assert Settings.Config.case_sensitive is True


class TestGetSettings:
    """Test get_settings() function - caching behavior"""

    def test_get_settings_returns_settings(self):
        """Test 19: get_settings returns Settings instance"""
        s = get_settings()
        assert isinstance(s, Settings)

    def test_get_settings_cached(self):
        """Test 20: get_settings returns cached instance"""
        get_settings.cache_clear()
        s1 = get_settings()
        s2 = get_settings()
        assert s1 is s2  # Same instance due to lru_cache

    def test_get_settings_cache_clear(self):
        """Test 21: Cache can be cleared"""
        get_settings.cache_clear()
        s1 = get_settings()
        get_settings.cache_clear()
        s2 = get_settings()
        # After clearing cache, new instance is created
        assert isinstance(s1, Settings)
        assert isinstance(s2, Settings)


class TestModuleLevelSettings:
    """Test module-level settings variable"""

    def test_module_settings_available(self):
        """Test 22: Module-level settings is available"""
        assert settings is not None
        assert isinstance(settings, Settings)

    def test_module_settings_has_attributes(self):
        """Test 23: Module-level settings has all attributes"""
        assert hasattr(settings, 'API_V1_STR')
        assert hasattr(settings, 'PROJECT_NAME')
        assert hasattr(settings, 'REDIS_HOST')
        assert hasattr(settings, 'ENABLE_CACHE')
        assert hasattr(settings, 'MAX_STUDIES')


class TestSecurityValidation:
    """Security-focused tests"""

    def test_secret_key_not_empty(self):
        """Test 24: Secret key is never empty"""
        s = Settings()
        assert s.SECRET_KEY != ""
        assert s.SECRET_KEY is not None

    def test_cors_not_wildcard(self):
        """Test 25: CORS doesn't allow all origins (critical security)"""
        s = Settings()
        assert "*" not in s.ALLOWED_ORIGINS
        # Should be explicit list
        for origin in s.ALLOWED_ORIGINS:
            assert origin.startswith("http://") or origin.startswith("https://")

    def test_api_keys_list(self):
        """Test 26: API keys is a list (empty is ok for development)"""
        s = Settings()
        assert isinstance(s.VALID_API_KEYS, list)

    def test_algorithm_secure(self):
        """Test 27: Algorithm is secure (HS256 or better)"""
        s = Settings()
        assert s.ALGORITHM in ["HS256", "HS384", "HS512", "RS256"]

    def test_max_upload_size_reasonable(self):
        """Test 28: Upload size limit is reasonable (not too large)"""
        s = Settings()
        assert s.MAX_UPLOAD_SIZE <= 100 * 1024 * 1024  # Max 100MB
        assert s.MAX_UPLOAD_SIZE > 0


class TestValidation:
    """Test input validation and constraints"""

    def test_port_range(self):
        """Test 29: Port is in valid range"""
        s = Settings()
        assert 1 <= s.PORT <= 65535

    def test_metrics_port_range(self):
        """Test 30: Metrics port is in valid range"""
        s = Settings()
        assert 1 <= s.METRICS_PORT <= 65535

    def test_redis_port_range(self):
        """Test 31: Redis port is in valid range"""
        s = Settings()
        assert 1 <= s.REDIS_PORT <= 65535

    def test_cache_ttl_positive(self):
        """Test 32: Cache TTL is positive"""
        s = Settings()
        assert s.CACHE_TTL > 0

    def test_rate_limits_positive(self):
        """Test 33: Rate limits are positive"""
        s = Settings()
        assert s.RATE_LIMIT_PER_MINUTE > 0
        assert s.RATE_LIMIT_BURST > 0

    def test_analysis_limits_positive(self):
        """Test 34: Analysis limits are positive"""
        s = Settings()
        assert s.MAX_STUDIES > 0
        assert s.MAX_OBSERVATIONS > 0

    def test_token_expire_positive(self):
        """Test 35: Token expiration is positive"""
        s = Settings()
        assert s.ACCESS_TOKEN_EXPIRE_MINUTES > 0


# Property-based tests
@pytest.mark.property
class TestPropertiesSettings:
    """Property-based tests for settings"""

    def test_all_required_fields_present(self):
        """Test 36: All required configuration fields are present"""
        s = Settings()
        required_fields = [
            'API_V1_STR', 'PROJECT_NAME', 'VERSION', 'HOST', 'PORT',
            'SECRET_KEY', 'ALLOWED_ORIGINS', 'REDIS_HOST', 'LOG_LEVEL',
            'MAX_STUDIES', 'MAX_OBSERVATIONS'
        ]
        for field in required_fields:
            assert hasattr(s, field), f"Missing required field: {field}"

    def test_string_fields_not_empty(self):
        """Test 37: Important string fields are not empty"""
        s = Settings()
        string_fields = ['API_V1_STR', 'PROJECT_NAME', 'HOST', 'SECRET_KEY', 'LOG_LEVEL']
        for field in string_fields:
            value = getattr(s, field)
            assert value != "", f"{field} should not be empty"
            assert value is not None, f"{field} should not be None"

    def test_list_fields_are_lists(self):
        """Test 38: List fields are actually lists"""
        s = Settings()
        list_fields = ['ALLOWED_ORIGINS', 'VALID_API_KEYS', 'ALLOWED_UPLOAD_EXTENSIONS']
        for field in list_fields:
            value = getattr(s, field)
            assert isinstance(value, list), f"{field} should be a list"

    def test_boolean_fields_are_booleans(self):
        """Test 39: Boolean fields are actually booleans"""
        s = Settings()
        bool_fields = ['ENABLE_CACHE', 'ENABLE_METRICS', 'ENABLE_BAYESIAN_MA', 'ENABLE_AI_COPILOT']
        for field in bool_fields:
            value = getattr(s, field)
            assert isinstance(value, bool), f"{field} should be a boolean"

    def test_integer_fields_are_integers(self):
        """Test 40: Integer fields are actually integers"""
        s = Settings()
        int_fields = ['PORT', 'RATE_LIMIT_PER_MINUTE', 'REDIS_PORT', 'CACHE_TTL', 'MAX_STUDIES']
        for field in int_fields:
            value = getattr(s, field)
            assert isinstance(value, int), f"{field} should be an integer"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
