"""
Configuration Management for EvidenceOS PRIME
Centralized settings with environment variable support
"""
from pydantic_settings import BaseSettings
from typing import List, Optional
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings with environment variable support"""

    # API Configuration
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "EvidenceOS PRIME API"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "Backend API for meta-analysis and health economics"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Security
    SECRET_KEY: str = "CHANGE-ME-IN-PRODUCTION-USE-openssl-rand-hex-32"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # CORS - Whitelist specific origins
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3838",
        "http://localhost:3000",
        "http://127.0.0.1:3838"
    ]

    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_BURST: int = 100

    # Redis Cache
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    REDIS_PASSWORD: Optional[str] = None
    CACHE_TTL: int = 3600  # 1 hour
    ENABLE_CACHE: bool = True

    # Database (for future use)
    DATABASE_URL: Optional[str] = None

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"  # json or text

    # Monitoring
    ENABLE_METRICS: bool = True
    METRICS_PORT: int = 9090

    # API Keys for authentication
    API_KEY_HEADER: str = "X-API-Key"
    VALID_API_KEYS: List[str] = []  # Load from environment or secrets

    # File Upload
    MAX_UPLOAD_SIZE: int = 10 * 1024 * 1024  # 10MB
    ALLOWED_UPLOAD_EXTENSIONS: List[str] = [".csv", ".xlsx", ".json"]

    # Analysis Limits
    MAX_STUDIES: int = 1000
    MAX_OBSERVATIONS: int = 10000

    # Feature Flags
    ENABLE_BAYESIAN_MA: bool = False
    ENABLE_AI_COPILOT: bool = True

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()


settings = get_settings()
