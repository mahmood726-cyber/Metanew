"""
Comprehensive tests for config utility - 100% Coverage
Target: 100% coverage of backend/utils/config.py
"""
import pytest
import os
import tempfile
import sys
from pathlib import Path
import yaml

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from utils.config import (
    APIConfig,
    CacheConfig,
    DatabaseConfig,
    SecurityConfig,
    AnalysisConfig,
    HealthEconomicsConfig,
    LoggingConfig,
    Config,
    ConfigManager,
    get_config,
    load_config,
    config_manager
)
from pydantic import ValidationError


class TestAPIConfig:
    """Test APIConfig schema"""

    def test_api_config_defaults(self):
        """Test default values"""
        config = APIConfig()
        assert config.host == "0.0.0.0"
        assert config.port == 8000
        assert config.workers == 1
        assert config.reload is False
        assert config.log_level == "info"
        assert "http://localhost:3838" in config.cors_origins
        assert config.rate_limit == "100/minute"
        assert config.enable_docs is True

    def test_api_config_custom(self):
        """Test custom values"""
        config = APIConfig(
            host="localhost",
            port=9000,
            workers=4,
            reload=True,
            log_level="DEBUG",
            cors_origins=["http://example.com"],
            rate_limit="200/minute",
            enable_docs=False
        )
        assert config.host == "localhost"
        assert config.port == 9000
        assert config.workers == 4
        assert config.reload is True
        assert config.log_level == "debug"  # Validated to lowercase
        assert config.cors_origins == ["http://example.com"]

    def test_api_port_validation(self):
        """Test port validation"""
        with pytest.raises(ValidationError):
            APIConfig(port=0)  # Too low
        with pytest.raises(ValidationError):
            APIConfig(port=70000)  # Too high

    def test_log_level_validation(self):
        """Test log level validation"""
        valid_levels = ['debug', 'info', 'warning', 'error', 'critical']
        for level in valid_levels:
            config = APIConfig(log_level=level.upper())
            assert config.log_level == level.lower()

        with pytest.raises(ValidationError):
            APIConfig(log_level='invalid')


class TestCacheConfig:
    """Test CacheConfig schema"""

    def test_cache_config_defaults(self):
        """Test default values"""
        config = CacheConfig()
        assert config.enabled is True
        assert config.cache_dir == "cache"
        assert config.ttl_seconds == 3600
        assert config.max_size_mb == 1000
        assert config.compression is True

    def test_cache_config_custom(self):
        """Test custom values"""
        config = CacheConfig(
            enabled=False,
            cache_dir="/custom/cache",
            ttl_seconds=7200,
            max_size_mb=500,
            compression=False
        )
        assert config.enabled is False
        assert config.cache_dir == "/custom/cache"
        assert config.ttl_seconds == 7200
        assert config.max_size_mb == 500
        assert config.compression is False

    def test_cache_ttl_validation(self):
        """Test TTL validation"""
        config = CacheConfig(ttl_seconds=0)  # Minimum valid
        assert config.ttl_seconds == 0

        with pytest.raises(ValidationError):
            CacheConfig(ttl_seconds=-1)  # Invalid

    def test_cache_max_size_validation(self):
        """Test max size validation"""
        with pytest.raises(ValidationError):
            CacheConfig(max_size_mb=0)  # Too low


class TestDatabaseConfig:
    """Test DatabaseConfig schema"""

    def test_database_config_defaults(self):
        """Test default values"""
        config = DatabaseConfig()
        assert config.enabled is False
        assert config.type == "sqlite"
        assert config.host is None
        assert config.port is None
        assert config.name == "evidenceos.db"
        assert config.user is None
        assert config.password is None
        assert config.pool_size == 5

    def test_database_config_postgres(self):
        """Test PostgreSQL configuration"""
        config = DatabaseConfig(
            enabled=True,
            type="postgresql",
            host="localhost",
            port=5432,
            name="evidenceos",
            user="admin",
            password="secret",
            pool_size=10
        )
        assert config.enabled is True
        assert config.type == "postgresql"
        assert config.host == "localhost"
        assert config.port == 5432
        assert config.pool_size == 10


class TestSecurityConfig:
    """Test SecurityConfig schema"""

    def test_security_config_defaults(self):
        """Test default values"""
        config = SecurityConfig()
        assert config.enable_auth is False
        assert config.secret_key == "change-me-in-production"
        assert config.token_expire_minutes == 60
        assert config.enable_https is False
        assert config.allowed_hosts == ["*"]
        assert config.max_request_size_mb == 100

    def test_security_config_production(self):
        """Test production security config"""
        config = SecurityConfig(
            enable_auth=True,
            secret_key="supersecretkey123",
            token_expire_minutes=30,
            enable_https=True,
            allowed_hosts=["example.com", "api.example.com"],
            max_request_size_mb=50
        )
        assert config.enable_auth is True
        assert config.secret_key == "supersecretkey123"
        assert config.token_expire_minutes == 30
        assert config.enable_https is True
        assert len(config.allowed_hosts) == 2


class TestAnalysisConfig:
    """Test AnalysisConfig schema"""

    def test_analysis_config_defaults(self):
        """Test default values"""
        config = AnalysisConfig()
        assert config.max_studies == 1000
        assert config.min_studies_meta_analysis == 2
        assert config.default_confidence_level == 0.95
        assert config.heterogeneity_threshold == 50.0
        assert config.publication_bias_min_studies == 10

    def test_analysis_config_custom(self):
        """Test custom values"""
        config = AnalysisConfig(
            max_studies=500,
            min_studies_meta_analysis=3,
            default_confidence_level=0.99,
            heterogeneity_threshold=75.0,
            publication_bias_min_studies=15
        )
        assert config.max_studies == 500
        assert config.min_studies_meta_analysis == 3
        assert config.default_confidence_level == 0.99

    def test_confidence_level_validation(self):
        """Test confidence level bounds"""
        with pytest.raises(ValidationError):
            AnalysisConfig(default_confidence_level=1.5)  # Too high
        with pytest.raises(ValidationError):
            AnalysisConfig(default_confidence_level=-0.1)  # Too low


class TestHealthEconomicsConfig:
    """Test HealthEconomicsConfig schema"""

    def test_he_config_defaults(self):
        """Test default values"""
        config = HealthEconomicsConfig()
        assert config.default_currency == "USD"
        assert config.default_wtp_threshold == 50000
        assert config.default_discount_rate == 0.03
        assert config.default_time_horizon == 10
        assert config.n_simulations == 1000

    def test_he_config_custom(self):
        """Test custom values"""
        config = HealthEconomicsConfig(
            default_currency="GBP",
            default_wtp_threshold=20000,
            default_discount_rate=0.035,
            default_time_horizon=5,
            n_simulations=5000
        )
        assert config.default_currency == "GBP"
        assert config.default_wtp_threshold == 20000
        assert config.default_discount_rate == 0.035
        assert config.n_simulations == 5000

    def test_n_simulations_validation(self):
        """Test minimum simulations"""
        with pytest.raises(ValidationError):
            HealthEconomicsConfig(n_simulations=50)  # Too few


class TestLoggingConfig:
    """Test LoggingConfig schema"""

    def test_logging_config_defaults(self):
        """Test default values"""
        config = LoggingConfig()
        assert config.level == "INFO"
        assert config.log_dir == "logs"
        assert config.log_to_file is True
        assert config.structured is False
        assert config.max_file_size_mb == 100
        assert config.backup_count == 5

    def test_logging_config_custom(self):
        """Test custom values"""
        config = LoggingConfig(
            level="DEBUG",
            log_dir="/var/log/evidenceos",
            log_to_file=False,
            structured=True,
            max_file_size_mb=50,
            backup_count=10
        )
        assert config.level == "DEBUG"
        assert config.log_dir == "/var/log/evidenceos"
        assert config.structured is True


class TestConfig:
    """Test main Config class"""

    def test_config_defaults(self):
        """Test default configuration"""
        config = Config()
        assert config.environment == "development"
        assert isinstance(config.api, APIConfig)
        assert isinstance(config.cache, CacheConfig)
        assert isinstance(config.database, DatabaseConfig)
        assert isinstance(config.security, SecurityConfig)
        assert isinstance(config.analysis, AnalysisConfig)
        assert isinstance(config.health_economics, HealthEconomicsConfig)
        assert isinstance(config.logging, LoggingConfig)

    def test_environment_validation(self):
        """Test environment validation"""
        valid_envs = ['development', 'staging', 'production', 'testing']
        for env in valid_envs:
            config = Config(environment=env.upper())
            assert config.environment == env.lower()

        with pytest.raises(ValidationError):
            Config(environment='invalid')

    def test_config_nested(self):
        """Test nested configuration"""
        config = Config(
            environment='production',
            api={'host': 'api.example.com', 'port': 443},
            cache={'enabled': True, 'ttl_seconds': 7200},
            security={'enable_auth': True, 'enable_https': True}
        )
        assert config.environment == 'production'
        assert config.api.host == 'api.example.com'
        assert config.api.port == 443
        assert config.cache.ttl_seconds == 7200
        assert config.security.enable_auth is True

    def test_config_get(self):
        """Test get method with dot notation"""
        config = Config()
        assert config.get('api.host') == '0.0.0.0'
        assert config.get('api.port') == 8000
        assert config.get('cache.enabled') is True
        assert config.get('nonexistent.key', 'default') == 'default'

    def test_config_set(self):
        """Test set method with dot notation"""
        config = Config()
        config.set('api.host', 'localhost')
        config.set('api.port', 9000)
        config.set('cache.enabled', False)

        assert config.api.host == 'localhost'
        assert config.api.port == 9000
        assert config.cache.enabled is False

    def test_config_from_yaml(self):
        """Test loading from YAML file"""
        yaml_content = {
            'environment': 'production',
            'api': {
                'host': 'api.example.com',
                'port': 443,
                'log_level': 'warning'
            },
            'cache': {
                'enabled': True,
                'ttl_seconds': 7200
            }
        }

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(yaml_content, f)
            yaml_path = f.name

        try:
            config = Config.from_yaml(yaml_path)
            assert config.environment == 'production'
            assert config.api.host == 'api.example.com'
            assert config.api.port == 443
            assert config.api.log_level == 'warning'
            assert config.cache.ttl_seconds == 7200
        finally:
            os.unlink(yaml_path)

    def test_config_to_yaml(self):
        """Test saving to YAML file"""
        config = Config(
            environment='production',
            api={'host': 'api.example.com', 'port': 443}
        )

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml_path = f.name

        try:
            config.to_yaml(yaml_path)

            # Load and verify
            with open(yaml_path, 'r') as f:
                saved_config = yaml.safe_load(f)

            assert saved_config['environment'] == 'production'
            assert saved_config['api']['host'] == 'api.example.com'
            assert saved_config['api']['port'] == 443
        finally:
            os.unlink(yaml_path)

    def test_config_from_env(self, monkeypatch):
        """Test loading from environment variables"""
        # Set environment variables
        monkeypatch.setenv('ENVIRONMENT', 'production')
        monkeypatch.setenv('API_HOST', 'api.example.com')
        monkeypatch.setenv('API_PORT', '443')
        monkeypatch.setenv('API_WORKERS', '4')
        monkeypatch.setenv('API_LOG_LEVEL', 'warning')
        monkeypatch.setenv('CACHE_ENABLED', 'true')
        monkeypatch.setenv('CACHE_DIR', '/tmp/cache')
        monkeypatch.setenv('CACHE_TTL_SECONDS', '7200')
        monkeypatch.setenv('DATABASE_ENABLED', 'true')
        monkeypatch.setenv('DATABASE_TYPE', 'postgresql')
        monkeypatch.setenv('DATABASE_HOST', 'localhost')
        monkeypatch.setenv('DATABASE_PORT', '5432')
        monkeypatch.setenv('DATABASE_NAME', 'evidenceos')
        monkeypatch.setenv('DATABASE_USER', 'admin')
        monkeypatch.setenv('DATABASE_PASSWORD', 'secret')
        monkeypatch.setenv('ENABLE_AUTH', 'true')
        monkeypatch.setenv('SECRET_KEY', 'supersecret')
        monkeypatch.setenv('ENABLE_HTTPS', 'true')

        config = Config.from_env()

        assert config.environment == 'production'
        assert config.api.host == 'api.example.com'
        assert config.api.port == 443
        assert config.api.workers == 4
        assert config.api.log_level == 'warning'
        assert config.cache.enabled is True
        assert config.cache.cache_dir == '/tmp/cache'
        assert config.cache.ttl_seconds == 7200
        assert config.database.enabled is True
        assert config.database.type == 'postgresql'
        assert config.database.host == 'localhost'
        assert config.database.port == 5432
        assert config.database.name == 'evidenceos'
        assert config.database.user == 'admin'
        assert config.database.password == 'secret'
        assert config.security.enable_auth is True
        assert config.security.secret_key == 'supersecret'
        assert config.security.enable_https is True

    def test_config_from_env_false_boolean(self, monkeypatch):
        """Test boolean false from environment"""
        monkeypatch.setenv('CACHE_ENABLED', 'false')
        config = Config.from_env()
        assert config.cache.enabled is False


class TestConfigManager:
    """Test ConfigManager singleton"""

    def test_singleton_pattern(self):
        """Test ConfigManager is a singleton"""
        manager1 = ConfigManager()
        manager2 = ConfigManager()
        assert manager1 is manager2

    def test_load_from_yaml(self):
        """Test loading config from YAML"""
        yaml_content = {
            'environment': 'testing',
            'api': {'host': 'testhost', 'port': 8888}
        }

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(yaml_content, f)
            yaml_path = f.name

        try:
            manager = ConfigManager()
            config = manager.load(yaml_path)
            assert config.environment == 'testing'
            assert config.api.host == 'testhost'
            assert config.api.port == 8888
        finally:
            os.unlink(yaml_path)

    def test_load_from_env_when_no_file(self, monkeypatch):
        """Test loading from env when config file doesn't exist"""
        monkeypatch.setenv('ENVIRONMENT', 'testing')
        monkeypatch.setenv('API_PORT', '9999')

        manager = ConfigManager()
        config = manager.load('/nonexistent/config.yaml')
        assert config.environment == 'testing'
        assert config.api.port == 9999

    def test_config_property(self):
        """Test config property"""
        manager = ConfigManager()
        config = manager.config
        assert isinstance(config, Config)

    def test_reload(self):
        """Test config reload"""
        manager = ConfigManager()

        # Load initial config
        config1 = manager.load()
        config1.environment = 'development'

        # Reload
        config2 = manager.reload()

        # Should be a fresh instance
        assert isinstance(config2, Config)


class TestGlobalFunctions:
    """Test module-level functions"""

    def test_get_config(self):
        """Test get_config function"""
        config = get_config()
        assert isinstance(config, Config)

    def test_load_config_with_yaml(self):
        """Test load_config with YAML file"""
        yaml_content = {'environment': 'testing', 'api': {'port': 7777}}

        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(yaml_content, f)
            yaml_path = f.name

        try:
            config = load_config(yaml_path)
            assert config.environment == 'testing'
            assert config.api.port == 7777
        finally:
            os.unlink(yaml_path)

    def test_load_config_without_path(self):
        """Test load_config without path (uses env)"""
        config = load_config()
        assert isinstance(config, Config)

    def test_config_manager_global(self):
        """Test global config_manager"""
        assert isinstance(config_manager, ConfigManager)


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/utils/config', '--cov-report=term-missing'])
