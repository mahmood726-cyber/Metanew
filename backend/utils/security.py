"""
Security utilities and middleware for EvidenceOS PRIME
Implements security best practices including headers, HTTPS, and input validation
"""
from fastapi import Request, HTTPException, status
from fastapi.responses import Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
from typing import Callable, Optional
import time
import hashlib
import secrets


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    Middleware to add security headers to all responses

    Implements OWASP security best practices
    """

    def __init__(self, app: ASGIApp, enable_hsts: bool = False):
        super().__init__(app)
        self.enable_hsts = enable_hsts

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Add security headers to response"""
        response = await call_next(request)

        # Content Security Policy
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
            "style-src 'self' 'unsafe-inline'; "
            "img-src 'self' data: https:; "
            "font-src 'self' data:; "
            "connect-src 'self'"
        )

        # X-Content-Type-Options
        response.headers["X-Content-Type-Options"] = "nosniff"

        # X-Frame-Options
        response.headers["X-Frame-Options"] = "DENY"

        # X-XSS-Protection
        response.headers["X-XSS-Protection"] = "1; mode=block"

        # Referrer-Policy
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

        # Permissions-Policy
        response.headers["Permissions-Policy"] = (
            "accelerometer=(), "
            "camera=(), "
            "geolocation=(), "
            "gyroscope=(), "
            "magnetometer=(), "
            "microphone=(), "
            "payment=(), "
            "usb=()"
        )

        # Strict-Transport-Security (only if HTTPS is enabled)
        if self.enable_hsts:
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains; preload"
            )

        # Remove server header for security
        response.headers.pop("Server", None)

        return response


class HTTPSRedirectMiddleware(BaseHTTPMiddleware):
    """Middleware to redirect HTTP requests to HTTPS"""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Redirect to HTTPS if not already"""
        # Check if request is HTTP
        if request.url.scheme == "http":
            # Build HTTPS URL
            https_url = request.url.replace(scheme="https")

            # Return redirect response
            return Response(
                status_code=status.HTTP_308_PERMANENT_REDIRECT,
                headers={"Location": str(https_url)}
            )

        return await call_next(request)


class RequestValidationMiddleware(BaseHTTPMiddleware):
    """
    Middleware to validate requests for security issues
    Checks for malicious patterns and enforces size limits
    """

    def __init__(
        self,
        app: ASGIApp,
        max_content_length: int = 100 * 1024 * 1024  # 100MB default
    ):
        super().__init__(app)
        self.max_content_length = max_content_length

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Validate request"""
        # Check content length
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > self.max_content_length:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Request body too large. Maximum size: {self.max_content_length} bytes"
            )

        # Check for suspicious patterns in path
        suspicious_patterns = [
            "../",  # Path traversal
            "..\\",  # Windows path traversal
            "<script",  # XSS attempt
            "javascript:",  # XSS attempt
            "onerror=",  # XSS attempt
            "onclick=",  # XSS attempt
        ]

        path_lower = request.url.path.lower()
        for pattern in suspicious_patterns:
            if pattern in path_lower:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Suspicious pattern detected in request"
                )

        return await call_next(request)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Simple rate limiting middleware
    Tracks requests per IP address
    """

    def __init__(
        self,
        app: ASGIApp,
        requests_per_minute: int = 60,
        cleanup_interval: int = 60
    ):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.cleanup_interval = cleanup_interval
        self.request_counts: dict = {}
        self.last_cleanup = time.time()

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Check rate limit"""
        # Get client IP
        client_ip = request.client.host if request.client else "unknown"

        # Cleanup old entries periodically
        current_time = time.time()
        if current_time - self.last_cleanup > self.cleanup_interval:
            self._cleanup_old_entries(current_time)
            self.last_cleanup = current_time

        # Check rate limit
        if client_ip in self.request_counts:
            count, timestamp = self.request_counts[client_ip]

            # If within the same minute
            if current_time - timestamp < 60:
                if count >= self.requests_per_minute:
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail="Rate limit exceeded. Please try again later.",
                        headers={"Retry-After": "60"}
                    )
                self.request_counts[client_ip] = (count + 1, timestamp)
            else:
                # Reset counter for new minute
                self.request_counts[client_ip] = (1, current_time)
        else:
            # First request from this IP
            self.request_counts[client_ip] = (1, current_time)

        response = await call_next(request)

        # Add rate limit headers
        response.headers["X-RateLimit-Limit"] = str(self.requests_per_minute)
        response.headers["X-RateLimit-Remaining"] = str(
            max(0, self.requests_per_minute - self.request_counts[client_ip][0])
        )

        return response

    def _cleanup_old_entries(self, current_time: float):
        """Remove entries older than 1 minute"""
        to_remove = [
            ip for ip, (_, timestamp) in self.request_counts.items()
            if current_time - timestamp > 60
        ]
        for ip in to_remove:
            del self.request_counts[ip]


class RequestIDMiddleware(BaseHTTPMiddleware):
    """
    Middleware to add unique request ID to each request
    Useful for logging and tracing
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Add request ID"""
        # Generate unique request ID
        request_id = secrets.token_hex(16)

        # Add to request state
        request.state.request_id = request_id

        # Process request
        response = await call_next(request)

        # Add request ID to response headers
        response.headers["X-Request-ID"] = request_id

        return response


# Security utility functions

def sanitize_input(text: str) -> str:
    """
    Sanitize user input to prevent XSS and injection attacks

    Args:
        text: Input text to sanitize

    Returns:
        Sanitized text
    """
    if not text:
        return text

    # Remove potentially dangerous characters
    dangerous_chars = ['<', '>', '"', "'", '&', '\x00']
    for char in dangerous_chars:
        text = text.replace(char, '')

    return text


def validate_file_path(file_path: str) -> bool:
    """
    Validate file path to prevent path traversal attacks

    Args:
        file_path: File path to validate

    Returns:
        True if path is safe, False otherwise
    """
    # Check for path traversal patterns
    dangerous_patterns = ['../', '..\\', '%2e%2e', '0x2e0x2e']

    file_path_lower = file_path.lower()
    for pattern in dangerous_patterns:
        if pattern in file_path_lower:
            return False

    return True


def generate_token(length: int = 32) -> str:
    """
    Generate secure random token

    Args:
        length: Token length in bytes

    Returns:
        Secure random token (hex string)
    """
    return secrets.token_hex(length)


def hash_value(value: str, salt: Optional[str] = None) -> str:
    """
    Hash a value using SHA-256

    Args:
        value: Value to hash
        salt: Optional salt

    Returns:
        Hashed value (hex string)
    """
    if salt:
        value = value + salt

    return hashlib.sha256(value.encode()).hexdigest()


def constant_time_compare(a: str, b: str) -> bool:
    """
    Compare two strings in constant time to prevent timing attacks

    Args:
        a: First string
        b: Second string

    Returns:
        True if strings are equal, False otherwise
    """
    return secrets.compare_digest(a.encode(), b.encode())


def validate_email(email: str) -> bool:
    """
    Basic email validation

    Args:
        email: Email address to validate

    Returns:
        True if email is valid, False otherwise
    """
    import re

    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_url(url: str) -> bool:
    """
    Validate URL format

    Args:
        url: URL to validate

    Returns:
        True if URL is valid, False otherwise
    """
    import re

    pattern = r'^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/.*)?$'
    return bool(re.match(pattern, url))


def mask_sensitive_data(data: str, visible_chars: int = 4) -> str:
    """
    Mask sensitive data for logging

    Args:
        data: Sensitive data to mask
        visible_chars: Number of characters to leave visible

    Returns:
        Masked data
    """
    if len(data) <= visible_chars:
        return "*" * len(data)

    return data[:visible_chars] + "*" * (len(data) - visible_chars)


# Export all security utilities
__all__ = [
    'SecurityHeadersMiddleware',
    'HTTPSRedirectMiddleware',
    'RequestValidationMiddleware',
    'RateLimitMiddleware',
    'RequestIDMiddleware',
    'sanitize_input',
    'validate_file_path',
    'generate_token',
    'hash_value',
    'constant_time_compare',
    'validate_email',
    'validate_url',
    'mask_sensitive_data',
]
