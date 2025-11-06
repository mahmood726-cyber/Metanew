"""
Security Configuration for Metanew Platform

Centralized security settings for:
- CORS (Cross-Origin Resource Sharing)
- CSP (Content Security Policy)
- HSTS (HTTP Strict Transport Security)
- Rate limiting
- Authentication

Production-ready security hardening based on OWASP recommendations.
"""

import os
from typing import List
from enum import Enum


class Environment(Enum):
    """Deployment environment"""
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    TEST = "test"


# ==================== ENVIRONMENT ====================

# Determine current environment
env_value = os.getenv("ENVIRONMENT", "development")
# Handle test environment (pytest sets this)
if env_value not in ["development", "staging", "production", "test"]:
    env_value = "development"
ENVIRONMENT = Environment(env_value)

# Is production environment
IS_PRODUCTION = ENVIRONMENT == Environment.PRODUCTION


# ==================== CORS CONFIGURATION ====================

class CORSConfig:
    """
    CORS (Cross-Origin Resource Sharing) configuration

    Controls which origins can access the API.
    Strict whitelist in production, permissive in development.
    """

    # Allowed origins (whitelist)
    # Production: Only allow specific domains
    # Development: Allow localhost for testing
    if IS_PRODUCTION:
        ALLOWED_ORIGINS = [
            "https://metanew.org",
            "https://www.metanew.org",
            "https://app.metanew.org",
            # Add your production domains here
        ]
    else:
        ALLOWED_ORIGINS = [
            "http://localhost:3000",  # React dev server
            "http://localhost:8000",  # FastAPI
            "http://localhost:8080",  # R Shiny
            "http://127.0.0.1:3000",
            "http://127.0.0.1:8000",
            "http://127.0.0.1:8080",
        ]

    # Allow credentials (cookies, authorization headers)
    ALLOW_CREDENTIALS = True

    # Allowed methods
    ALLOW_METHODS = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]

    # Allowed headers
    ALLOW_HEADERS = [
        "Accept",
        "Accept-Language",
        "Content-Type",
        "Authorization",
        "X-Requested-With",
        "X-CSRF-Token",
    ]

    # Expose headers (headers client can access)
    EXPOSE_HEADERS = [
        "X-Total-Count",
        "X-Page-Count",
        "X-RateLimit-Limit",
        "X-RateLimit-Remaining",
        "X-RateLimit-Reset",
    ]

    # Max age for preflight cache (seconds)
    MAX_AGE = 600  # 10 minutes

    @classmethod
    def get_middleware_config(cls) -> dict:
        """Get configuration for FastAPI CORSMiddleware"""
        return {
            "allow_origins": cls.ALLOWED_ORIGINS,
            "allow_credentials": cls.ALLOW_CREDENTIALS,
            "allow_methods": cls.ALLOW_METHODS,
            "allow_headers": cls.ALLOW_HEADERS,
            "expose_headers": cls.EXPOSE_HEADERS,
            "max_age": cls.MAX_AGE,
        }


# ==================== CSP CONFIGURATION ====================

class CSPConfig:
    """
    Content Security Policy (CSP) configuration

    Prevents XSS, clickjacking, and other code injection attacks.
    """

    # CSP directives
    DIRECTIVES = {
        "default-src": ["'self'"],
        "script-src": ["'self'", "'unsafe-inline'"],  # Remove 'unsafe-inline' in production with nonce
        "style-src": ["'self'", "'unsafe-inline'"],
        "img-src": ["'self'", "data:", "https:"],
        "font-src": ["'self'", "data:"],
        "connect-src": ["'self'"],
        "frame-ancestors": ["'none'"],  # Prevent clickjacking
        "base-uri": ["'self'"],
        "form-action": ["'self'"],
    }

    # Report violations (optional)
    REPORT_URI = None  # Set to "/api/csp-report" to log violations

    @classmethod
    def get_header_value(cls) -> str:
        """Generate CSP header value"""
        directives = []
        for directive, values in cls.DIRECTIVES.items():
            values_str = " ".join(values)
            directives.append(f"{directive} {values_str}")

        if cls.REPORT_URI:
            directives.append(f"report-uri {cls.REPORT_URI}")

        return "; ".join(directives)


# ==================== HSTS CONFIGURATION ====================

class HSTSConfig:
    """
    HTTP Strict Transport Security (HSTS) configuration

    Forces HTTPS connections and prevents downgrade attacks.
    """

    # Enable HSTS in production only
    ENABLED = IS_PRODUCTION

    # Max age (seconds) - 1 year
    MAX_AGE = 31536000

    # Include subdomains
    INCLUDE_SUBDOMAINS = True

    # Preload (submit to browser HSTS preload list)
    PRELOAD = True

    @classmethod
    def get_header_value(cls) -> str:
        """Generate HSTS header value"""
        parts = [f"max-age={cls.MAX_AGE}"]

        if cls.INCLUDE_SUBDOMAINS:
            parts.append("includeSubDomains")

        if cls.PRELOAD:
            parts.append("preload")

        return "; ".join(parts)


# ==================== RATE LIMITING ====================

class RateLimitConfig:
    """
    Rate limiting configuration

    Prevents abuse and ensures fair usage.
    Implements sliding window rate limiting.
    """

    # Global rate limits (requests per time window)
    GLOBAL_LIMIT = 1000  # requests
    GLOBAL_WINDOW = 3600  # 1 hour (seconds)

    # Per-endpoint rate limits (requests per minute)
    # Format: {"endpoint_path": (limit, window_seconds)}
    ENDPOINT_LIMITS = {
        # Authentication
        "/api/auth/login": (5, 60),  # 5 per minute
        "/api/auth/register": (3, 60),  # 3 per minute
        "/api/auth/refresh": (10, 60),  # 10 per minute

        # AI Features (expensive operations)
        "/api/ai-features/report/generate": (10, 3600),  # 10 per hour
        "/api/ai-features/nma/fit": (5, 3600),  # 5 per hour
        "/api/ai-features/benchmark/all": (2, 3600),  # 2 per hour

        # ROB and Screening (moderate)
        "/api/ai-features/rob/assess": (30, 60),  # 30 per minute
        "/api/ai-features/rob/assess-batch": (5, 60),  # 5 per minute
        "/api/ai-features/screening/screen-study": (60, 60),  # 60 per minute
        "/api/ai-features/screening/screen-batch": (10, 60),  # 10 per minute

        # PDF extraction (moderate)
        "/api/ai-features/pdf/extract-text": (20, 60),  # 20 per minute
        "/api/ai-features/pdf/extract-file": (10, 60),  # 10 per minute

        # GRADE assessment
        "/api/ai-features/grade/assess": (20, 60),  # 20 per minute

        # Regular operations (generous)
        "/api/projects": (100, 60),  # 100 per minute
        "/api/studies": (100, 60),  # 100 per minute
    }

    # Rate limit by user tier (future enhancement)
    TIER_LIMITS = {
        "free": {"multiplier": 1.0},
        "basic": {"multiplier": 2.0},
        "pro": {"multiplier": 5.0},
        "enterprise": {"multiplier": 10.0},
    }

    # Response headers
    HEADERS = {
        "limit": "X-RateLimit-Limit",
        "remaining": "X-RateLimit-Remaining",
        "reset": "X-RateLimit-Reset",
    }


# ==================== JWT CONFIGURATION ====================

class JWTConfig:
    """
    JWT (JSON Web Token) configuration

    Settings for token generation and validation.
    """

    # Secret key (MUST be set from environment in production)
    SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")

    # Algorithm
    ALGORITHM = "HS256"

    # Token expiration
    ACCESS_TOKEN_EXPIRE_MINUTES = 15  # Short-lived
    REFRESH_TOKEN_EXPIRE_DAYS = 7  # Long-lived

    # Token rotation interval
    ROTATION_INTERVAL_DAYS = 1

    # Issuer
    ISSUER = "metanew.org"

    # Audience
    AUDIENCE = "metanew-api"

    @classmethod
    def validate_config(cls):
        """Validate JWT configuration"""
        if IS_PRODUCTION and cls.SECRET_KEY == "your-secret-key-change-in-production":
            raise ValueError("JWT_SECRET_KEY must be set in production!")


# ==================== HTTPS CONFIGURATION ====================

class HTTPSConfig:
    """
    HTTPS enforcement configuration

    Ensures all connections use HTTPS in production.
    """

    # Enforce HTTPS (production only)
    ENFORCE = IS_PRODUCTION

    # Redirect HTTP to HTTPS
    REDIRECT_HTTP = IS_PRODUCTION

    # SSL certificate paths (for production deployment)
    SSL_CERT_PATH = os.getenv("SSL_CERT_PATH", "/etc/ssl/certs/cert.pem")
    SSL_KEY_PATH = os.getenv("SSL_KEY_PATH", "/etc/ssl/private/key.pem")

    # SSL verification
    VERIFY_SSL = IS_PRODUCTION


# ==================== OTHER SECURITY HEADERS ====================

class SecurityHeaders:
    """
    Additional security headers

    Various security headers to harden the application.
    """

    HEADERS = {
        # Prevent MIME type sniffing
        "X-Content-Type-Options": "nosniff",

        # Enable XSS protection
        "X-XSS-Protection": "1; mode=block",

        # Prevent clickjacking
        "X-Frame-Options": "DENY",

        # Referrer policy
        "Referrer-Policy": "strict-origin-when-cross-origin",

        # Permissions policy (formerly Feature-Policy)
        "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
    }


# ==================== SESSION CONFIGURATION ====================

class SessionConfig:
    """
    Session management configuration

    Settings for secure session handling.
    """

    # Session cookie settings
    COOKIE_NAME = "metanew_session"
    COOKIE_MAX_AGE = 3600  # 1 hour
    COOKIE_SECURE = IS_PRODUCTION  # HTTPS only
    COOKIE_HTTPONLY = True  # Not accessible via JavaScript
    COOKIE_SAMESITE = "lax"  # CSRF protection

    # Session secret key
    SECRET_KEY = os.getenv("SESSION_SECRET_KEY", "session-secret-change-in-production")

    @classmethod
    def validate_config(cls):
        """Validate session configuration"""
        if IS_PRODUCTION and cls.SECRET_KEY == "session-secret-change-in-production":
            raise ValueError("SESSION_SECRET_KEY must be set in production!")


# ==================== VALIDATION ====================

def validate_security_config():
    """
    Validate all security configuration

    Raises ValueError if critical settings are misconfigured.
    """
    errors = []

    # Validate JWT config
    try:
        JWTConfig.validate_config()
    except ValueError as e:
        errors.append(str(e))

    # Validate session config
    try:
        SessionConfig.validate_config()
    except ValueError as e:
        errors.append(str(e))

    # Validate CORS in production
    if IS_PRODUCTION:
        if "http://localhost" in str(CORSConfig.ALLOWED_ORIGINS):
            errors.append("Localhost should not be in CORS allowed origins in production")

    # Validate HTTPS in production
    if IS_PRODUCTION and not HTTPSConfig.ENFORCE:
        errors.append("HTTPS must be enforced in production")

    if errors:
        raise ValueError(f"Security configuration errors:\n" + "\n".join(f"  - {e}" for e in errors))

    return True


# ==================== INITIALIZATION ====================

# Validate on import (in production)
if IS_PRODUCTION:
    try:
        validate_security_config()
        print("✓ Security configuration validated successfully")
    except ValueError as e:
        print(f"✗ Security configuration validation failed:\n{e}")
        raise


# ==================== EXPORT ====================

__all__ = [
    "Environment",
    "ENVIRONMENT",
    "IS_PRODUCTION",
    "CORSConfig",
    "CSPConfig",
    "HSTSConfig",
    "RateLimitConfig",
    "JWTConfig",
    "HTTPSConfig",
    "SecurityHeaders",
    "SessionConfig",
    "validate_security_config",
]


# Example usage
if __name__ == "__main__":
    print("=== Metanew Security Configuration ===\n")
    print(f"Environment: {ENVIRONMENT.value}")
    print(f"Production: {IS_PRODUCTION}\n")

    print("CORS Configuration:")
    print(f"  Allowed origins: {len(CORSConfig.ALLOWED_ORIGINS)}")
    for origin in CORSConfig.ALLOWED_ORIGINS:
        print(f"    - {origin}")

    print(f"\nCSP Header:\n  {CSPConfig.get_header_value()[:100]}...")

    print(f"\nHSTS Enabled: {HSTSConfig.ENABLED}")
    if HSTSConfig.ENABLED:
        print(f"  Header: {HSTSConfig.get_header_value()}")

    print(f"\nRate Limiting:")
    print(f"  Global: {RateLimitConfig.GLOBAL_LIMIT} requests / {RateLimitConfig.GLOBAL_WINDOW}s")
    print(f"  Endpoints configured: {len(RateLimitConfig.ENDPOINT_LIMITS)}")

    print(f"\nJWT Configuration:")
    print(f"  Algorithm: {JWTConfig.ALGORITHM}")
    print(f"  Access token TTL: {JWTConfig.ACCESS_TOKEN_EXPIRE_MINUTES} minutes")
    print(f"  Refresh token TTL: {JWTConfig.REFRESH_TOKEN_EXPIRE_DAYS} days")

    print("\n✓ Security configuration loaded successfully")
