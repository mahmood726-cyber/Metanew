"""
Security module for EvidenceOS PRIME API
Includes authentication, rate limiting, input validation, and security headers
"""
from fastapi import HTTPException, Security, Depends, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from typing import Optional, Dict, Any
import hashlib
import secrets
import re
from datetime import datetime, timedelta
import jwt

# Rate limiter configuration
limiter = Limiter(key_func=get_remote_address)

# Security configuration
SECRET_KEY = secrets.token_urlsafe(32)  # In production, load from environment
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

# Simple in-memory user store (in production, use database)
USERS_DB = {
    "admin": {
        "username": "admin",
        "hashed_password": hashlib.sha256("changeme123".encode()).hexdigest(),
        "role": "admin",
        "email": "admin@evidenceos.com"
    },
    "analyst": {
        "username": "analyst",
        "hashed_password": hashlib.sha256("analyst123".encode()).hexdigest(),
        "role": "analyst",
        "email": "analyst@evidenceos.com"
    }
}

# API keys for service-to-service authentication
API_KEYS = {
    "dev_key_001": {"client": "development", "role": "developer"},
    "prod_key_001": {"client": "production", "role": "analyst"}
}

security_scheme = HTTPBearer()


class User:
    """User model"""
    def __init__(self, username: str, role: str, email: str):
        self.username = username
        self.role = role
        self.email = email


def hash_password(password: str) -> str:
    """Hash password using SHA256"""
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash"""
    return hash_password(plain_password) == hashed_password


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> dict:
    """Decode and verify JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def authenticate_user(username: str, password: str) -> Optional[User]:
    """Authenticate user with username and password"""
    user_data = USERS_DB.get(username)
    if not user_data:
        return None
    if not verify_password(password, user_data["hashed_password"]):
        return None
    return User(
        username=user_data["username"],
        role=user_data["role"],
        email=user_data["email"]
    )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security_scheme)
) -> User:
    """
    Get current user from JWT token
    Dependency for protected endpoints
    """
    token = credentials.credentials
    payload = decode_token(token)

    username = payload.get("sub")
    if username is None:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")

    user_data = USERS_DB.get(username)
    if user_data is None:
        raise HTTPException(status_code=401, detail="User not found")

    return User(
        username=user_data["username"],
        role=user_data["role"],
        email=user_data["email"]
    )


async def get_current_active_admin(current_user: User = Depends(get_current_user)) -> User:
    """
    Require admin role
    Dependency for admin-only endpoints
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


async def verify_api_key(x_api_key: str = Header(None)) -> Dict[str, Any]:
    """
    Verify API key from header
    Alternative to JWT for service-to-service authentication
    """
    if x_api_key is None:
        raise HTTPException(status_code=401, detail="API key required")

    api_key_data = API_KEYS.get(x_api_key)
    if api_key_data is None:
        raise HTTPException(status_code=401, detail="Invalid API key")

    return api_key_data


def sanitize_input(text: str, max_length: int = 1000, allow_special_chars: bool = False) -> str:
    """
    Sanitize user input to prevent XSS and injection attacks

    Args:
        text: Input text
        max_length: Maximum allowed length
        allow_special_chars: Whether to allow special characters

    Returns:
        Sanitized text

    Raises:
        HTTPException: If input is invalid
    """
    if not isinstance(text, str):
        raise HTTPException(status_code=400, detail="Input must be string")

    # Check length
    if len(text) > max_length:
        raise HTTPException(status_code=400, detail=f"Input exceeds maximum length of {max_length}")

    # Remove null bytes
    text = text.replace('\x00', '')

    # Check for SQL injection patterns
    sql_patterns = [
        r"(\s|^)(DROP|DELETE|INSERT|UPDATE|ALTER|CREATE)\s+",
        r"(\s|^)(UNION|SELECT)\s+(ALL|DISTINCT)?\s+",
        r"--",
        r"/\*.*\*/",
        r";\s*(DROP|DELETE|INSERT|UPDATE)"
    ]

    for pattern in sql_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            raise HTTPException(status_code=400, detail="Invalid input: potential SQL injection detected")

    # Check for XSS patterns
    xss_patterns = [
        r"<script[^>]*>.*?</script>",
        r"<iframe[^>]*>.*?</iframe>",
        r"javascript:",
        r"on\w+\s*=",  # Event handlers like onclick=
        r"<embed[^>]*>",
        r"<object[^>]*>"
    ]

    for pattern in xss_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            raise HTTPException(status_code=400, detail="Invalid input: potential XSS attack detected")

    # If not allowing special chars, restrict to alphanumeric and common punctuation
    if not allow_special_chars:
        if not re.match(r'^[a-zA-Z0-9\s\.,;:!?\-_()[\]{}\'\"]+$', text):
            raise HTTPException(status_code=400, detail="Invalid characters in input")

    return text.strip()


def validate_email(email: str) -> bool:
    """Validate email format"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def validate_study_id(study_id: str) -> str:
    """
    Validate and sanitize study ID
    Study IDs should be alphanumeric with limited special chars
    """
    if not isinstance(study_id, str):
        raise HTTPException(status_code=400, detail="Study ID must be string")

    if len(study_id) > 100:
        raise HTTPException(status_code=400, detail="Study ID too long")

    # Allow alphanumeric, hyphens, underscores, and spaces
    if not re.match(r'^[a-zA-Z0-9\s\-_]+$', study_id):
        raise HTTPException(status_code=400, detail="Invalid characters in study ID")

    return study_id.strip()


def add_security_headers(response_headers: dict) -> dict:
    """
    Add security headers to API responses

    Args:
        response_headers: Existing response headers

    Returns:
        Updated headers with security additions
    """
    security_headers = {
        # Prevent clickjacking
        "X-Frame-Options": "DENY",

        # XSS protection
        "X-Content-Type-Options": "nosniff",
        "X-XSS-Protection": "1; mode=block",

        # Content Security Policy
        "Content-Security-Policy": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'",

        # HTTPS enforcement (if behind reverse proxy)
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",

        # Referrer policy
        "Referrer-Policy": "strict-origin-when-cross-origin",

        # Permissions policy
        "Permissions-Policy": "geolocation=(), microphone=(), camera=()"
    }

    response_headers.update(security_headers)
    return response_headers


class SecurityAuditLog:
    """Simple security audit logging"""

    def __init__(self):
        self.logs = []

    def log_event(self, event_type: str, username: Optional[str], ip_address: str,
                  action: str, details: Optional[dict] = None):
        """Log security event"""
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "event_type": event_type,
            "username": username,
            "ip_address": ip_address,
            "action": action,
            "details": details or {}
        }
        self.logs.append(log_entry)

        # In production, write to file or database
        # For now, just keep in memory (with limit)
        if len(self.logs) > 1000:
            self.logs = self.logs[-1000:]

    def get_recent_logs(self, limit: int = 100) -> list:
        """Get recent security logs"""
        return self.logs[-limit:]

    def get_failed_login_attempts(self, username: str, minutes: int = 15) -> int:
        """Count failed login attempts for user in recent minutes"""
        cutoff = datetime.utcnow() - timedelta(minutes=minutes)
        count = 0

        for log in self.logs:
            if (log["event_type"] == "failed_login" and
                log["username"] == username and
                datetime.fromisoformat(log["timestamp"]) > cutoff):
                count += 1

        return count


# Global audit log instance
audit_log = SecurityAuditLog()


def check_rate_limit_exceeded(username: str, max_attempts: int = 5, window_minutes: int = 15) -> bool:
    """
    Check if user has exceeded failed login rate limit

    Args:
        username: Username to check
        max_attempts: Maximum failed attempts allowed
        window_minutes: Time window in minutes

    Returns:
        True if rate limit exceeded, False otherwise
    """
    attempts = audit_log.get_failed_login_attempts(username, window_minutes)
    return attempts >= max_attempts


# CORS configuration (more restrictive than current "*")
ALLOWED_ORIGINS = [
    "http://localhost:3838",
    "http://localhost:8000",
    "https://evidenceos.com",
    "https://app.evidenceos.com"
]

def get_cors_config():
    """Get CORS configuration for production"""
    return {
        "allow_origins": ALLOWED_ORIGINS,
        "allow_credentials": True,
        "allow_methods": ["GET", "POST", "PUT", "DELETE"],
        "allow_headers": ["*"],
        "max_age": 600  # Cache preflight requests for 10 minutes
    }


# Input validation schemas for common data types
def validate_numeric_range(value: float, min_val: float, max_val: float, field_name: str) -> float:
    """Validate numeric value is within range"""
    if not isinstance(value, (int, float)):
        raise HTTPException(status_code=400, detail=f"{field_name} must be numeric")

    if not (min_val <= value <= max_val):
        raise HTTPException(
            status_code=400,
            detail=f"{field_name} must be between {min_val} and {max_val}"
        )

    return float(value)


def validate_probability(value: float, field_name: str) -> float:
    """Validate value is a valid probability (0-1)"""
    return validate_numeric_range(value, 0.0, 1.0, field_name)


def validate_positive(value: float, field_name: str) -> float:
    """Validate value is positive"""
    if not isinstance(value, (int, float)):
        raise HTTPException(status_code=400, detail=f"{field_name} must be numeric")

    if value <= 0:
        raise HTTPException(status_code=400, detail=f"{field_name} must be positive")

    return float(value)
