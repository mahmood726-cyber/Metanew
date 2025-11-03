"""
Configuration management for EvidenceOS PRIME
Centralized configuration with environment variable support
"""
import os
from pathlib import Path
from typing import Any, Optional, Dict
from pydantic import BaseModel, Field, field_validator
import yaml


class APIConfig(BaseModel):
    """API configuration"""
    host: str = Field(default="0.0.0.0", description="API host")
    port: int = Field(default=8000, description="API port", ge=1, le=65535)
    workers: int = Field(default=1, description="Number of workers", ge=1)
    reload: bool = Field(default=False, description="Auto-reload on code changes")
    log_level: str = Field(default="info", description="Logging level")
    cors_origins: list[str] = Field(
        default=["http://localhost:3838", "http://127.0.0.1:3838"],
        description="Allowed CORS origins"
    )
    rate_limit: str = Field(default="100/minute", description="Rate limit")
    enable_docs: bool = Field(default=True, description="Enable API documentation")

    @field_validator('log_level')
    @classmethod
    def validate_log_level(cls, v):
        valid_levels = ['debug', 'info', 'warning', 'error', 'critical']
        if v.lower() not in valid_levels:
            raise ValueError(f"log_level must be one of {valid_levels}")
        return v.lower()


class CacheConfig(BaseModel):
    """Cache configuration"""
    enabled: bool = Field(default=True, description="Enable caching")
    cache_dir: str = Field(default="cache", description="Cache directory path")
    ttl_seconds: int = Field(default=3600, description="Cache TTL in seconds", ge=0)
    max_size_mb: int = Field(default=1000, description="Max cache size in MB", ge=1)
    compression: bool = Field(default=True, description="Enable cache compression")


class DatabaseConfig(BaseModel):
    """Database configuration"""
    enabled: bool = Field(default=False, description="Enable database")
    type: str = Field(default="sqlite", description="Database type")
    host: Optional[str] = Field(default=None, description="Database host")
    port: Optional[int] = Field(default=None, description="Database port")
    name: str = Field(default="evidenceos.db", description="Database name")
    user: Optional[str] = Field(default=None, description="Database user")
    password: Optional[str] = Field(default=None, description="Database password")
    pool_size: int = Field(default=5, description="Connection pool size", ge=1)


class SecurityConfig(BaseModel):
    """Security configuration"""
    enable_auth: bool = Field(default=False, description="Enable authentication")
    secret_key: str = Field(default="change-me-in-production", description="Secret key for tokens")
    token_expire_minutes: int = Field(default=60, description="Token expiration time", ge=1)
    enable_https: bool = Field(default=False, description="Enforce HTTPS")
    allowed_hosts: list[str] = Field(default=["*"], description="Allowed hosts")
    max_request_size_mb: int = Field(default=100, description="Max request size in MB", ge=1)


class AnalysisConfig(BaseModel):
    """Analysis configuration"""
    max_studies: int = Field(default=1000, description="Maximum number of studies", ge=1)
    min_studies_meta_analysis: int = Field(default=2, description="Min studies for MA", ge=2)
    default_confidence_level: float = Field(default=0.95, description="Default confidence level", ge=0, le=1)
    heterogeneity_threshold: float = Field(default=50.0, description="I² threshold for heterogeneity", ge=0, le=100)
    publication_bias_min_studies: int = Field(default=10, description="Min studies for publication bias tests", ge=3)


class HealthEconomicsConfig(BaseModel):
    """Health economics configuration"""
    default_currency: str = Field(default="USD", description="Default currency")
    default_wtp_threshold: int = Field(default=50000, description="Default WTP threshold")
    default_discount_rate: float = Field(default=0.03, description="Default discount rate", ge=0, le=1)
    default_time_horizon: int = Field(default=10, description="Default time horizon in years", ge=1)
    n_simulations: int = Field(default=1000, description="Number of PSA simulations", ge=100)


class LoggingConfig(BaseModel):
    """Logging configuration"""
    level: str = Field(default="INFO", description="Logging level")
    log_dir: str = Field(default="logs", description="Log directory")
    log_to_file: bool = Field(default=True, description="Enable file logging")
    structured: bool = Field(default=False, description="Use structured JSON logging")
    max_file_size_mb: int = Field(default=100, description="Max log file size in MB", ge=1)
    backup_count: int = Field(default=5, description="Number of log file backups", ge=0)


class Config(BaseModel):
    """Main application configuration"""
    environment: str = Field(default="development", description="Environment (development/production)")
    api: APIConfig = Field(default_factory=APIConfig)
    cache: CacheConfig = Field(default_factory=CacheConfig)
    database: DatabaseConfig = Field(default_factory=DatabaseConfig)
    security: SecurityConfig = Field(default_factory=SecurityConfig)
    analysis: AnalysisConfig = Field(default_factory=AnalysisConfig)
    health_economics: HealthEconomicsConfig = Field(default_factory=HealthEconomicsConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)

    @field_validator('environment')
    @classmethod
    def validate_environment(cls, v):
        valid_envs = ['development', 'staging', 'production', 'testing']
        if v.lower() not in valid_envs:
            raise ValueError(f"environment must be one of {valid_envs}")
        return v.lower()

    @classmethod
    def from_yaml(cls, yaml_path: str) -> 'Config':
        """
        Load configuration from YAML file

        Args:
            yaml_path: Path to YAML configuration file

        Returns:
            Config instance
        """
        with open(yaml_path, 'r') as f:
            config_dict = yaml.safe_load(f)
        return cls(**config_dict)

    @classmethod
    def from_env(cls) -> 'Config':
        """
        Load configuration from environment variables

        Returns:
            Config instance
        """
        config = cls()

        # API config
        if os.getenv('API_HOST'):
            config.api.host = os.getenv('API_HOST')
        if os.getenv('API_PORT'):
            config.api.port = int(os.getenv('API_PORT'))
        if os.getenv('API_WORKERS'):
            config.api.workers = int(os.getenv('API_WORKERS'))
        if os.getenv('API_LOG_LEVEL'):
            config.api.log_level = os.getenv('API_LOG_LEVEL')

        # Cache config
        if os.getenv('CACHE_ENABLED'):
            config.cache.enabled = os.getenv('CACHE_ENABLED').lower() == 'true'
        if os.getenv('CACHE_DIR'):
            config.cache.cache_dir = os.getenv('CACHE_DIR')
        if os.getenv('CACHE_TTL_SECONDS'):
            config.cache.ttl_seconds = int(os.getenv('CACHE_TTL_SECONDS'))

        # Database config
        if os.getenv('DATABASE_ENABLED'):
            config.database.enabled = os.getenv('DATABASE_ENABLED').lower() == 'true'
        if os.getenv('DATABASE_TYPE'):
            config.database.type = os.getenv('DATABASE_TYPE')
        if os.getenv('DATABASE_HOST'):
            config.database.host = os.getenv('DATABASE_HOST')
        if os.getenv('DATABASE_PORT'):
            config.database.port = int(os.getenv('DATABASE_PORT'))
        if os.getenv('DATABASE_NAME'):
            config.database.name = os.getenv('DATABASE_NAME')
        if os.getenv('DATABASE_USER'):
            config.database.user = os.getenv('DATABASE_USER')
        if os.getenv('DATABASE_PASSWORD'):
            config.database.password = os.getenv('DATABASE_PASSWORD')

        # Security config
        if os.getenv('ENABLE_AUTH'):
            config.security.enable_auth = os.getenv('ENABLE_AUTH').lower() == 'true'
        if os.getenv('SECRET_KEY'):
            config.security.secret_key = os.getenv('SECRET_KEY')
        if os.getenv('ENABLE_HTTPS'):
            config.security.enable_https = os.getenv('ENABLE_HTTPS').lower() == 'true'

        # Environment
        if os.getenv('ENVIRONMENT'):
            config.environment = os.getenv('ENVIRONMENT')

        return config

    def to_yaml(self, yaml_path: str):
        """
        Save configuration to YAML file

        Args:
            yaml_path: Path to save YAML configuration
        """
        with open(yaml_path, 'w') as f:
            yaml.dump(self.model_dump(), f, default_flow_style=False)

    def get(self, key: str, default: Any = None) -> Any:
        """
        Get configuration value by dot-notation key

        Args:
            key: Configuration key (e.g., 'api.host')
            default: Default value if key not found

        Returns:
            Configuration value
        """
        try:
            value = self
            for part in key.split('.'):
                value = getattr(value, part)
            return value
        except AttributeError:
            return default

    def set(self, key: str, value: Any):
        """
        Set configuration value by dot-notation key

        Args:
            key: Configuration key (e.g., 'api.host')
            value: Value to set
        """
        parts = key.split('.')
        obj = self
        for part in parts[:-1]:
            obj = getattr(obj, part)
        setattr(obj, parts[-1], value)


class ConfigManager:
    """Configuration manager singleton"""

    _instance: Optional['ConfigManager'] = None
    _config: Optional[Config] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def load(self, config_path: Optional[str] = None) -> Config:
        """
        Load configuration

        Args:
            config_path: Path to configuration file (YAML)

        Returns:
            Config instance
        """
        if config_path and Path(config_path).exists():
            self._config = Config.from_yaml(config_path)
        else:
            self._config = Config.from_env()

        return self._config

    @property
    def config(self) -> Config:
        """Get current configuration"""
        if self._config is None:
            self.load()
        return self._config

    def reload(self, config_path: Optional[str] = None):
        """Reload configuration"""
        self._config = None
        return self.load(config_path)


# Global config manager
config_manager = ConfigManager()


def get_config() -> Config:
    """
    Get application configuration

    Returns:
        Config instance
    """
    return config_manager.config


def load_config(config_path: Optional[str] = None) -> Config:
    """
    Load application configuration

    Args:
        config_path: Path to configuration file

    Returns:
        Config instance
    """
    return config_manager.load(config_path)


# Export
__all__ = [
    'Config',
    'APIConfig',
    'CacheConfig',
    'DatabaseConfig',
    'SecurityConfig',
    'AnalysisConfig',
    'HealthEconomicsConfig',
    'LoggingConfig',
    'ConfigManager',
    'get_config',
    'load_config',
    'config_manager',
]
