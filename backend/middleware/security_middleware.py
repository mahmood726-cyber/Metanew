"""
Security Middleware for FastAPI

Implements:
- Rate limiting per endpoint
- Security headers (CSP, HSTS, etc.)
- Request logging and monitoring
- IP blocking

Usage:
    from middleware.security_middleware import add_security_middleware

    app = FastAPI()
    add_security_middleware(app)
"""

import logging
import time
from typing import Dict, Callable
from fastapi import FastAPI, Request, Response, HTTPException, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.middleware.cors import CORSMiddleware
from collections import defaultdict
from datetime import datetime, timedelta

from config.security import (
    CORSConfig,
    CSPConfig,
    HSTSConfig,
    RateLimitConfig,
    SecurityHeaders,
    IS_PRODUCTION
)

logger = logging.getLogger(__name__)


# ==================== RATE LIMITING ====================

class RateLimiter:
    """
    Sliding window rate limiter

    Tracks requests per client per endpoint and enforces limits.
    """

    def __init__(self):
        """Initialize rate limiter"""
        # Format: {client_key: {endpoint: [(timestamp, count)]}}
        self.requests: Dict[str, Dict[str, list]] = defaultdict(lambda: defaultdict(list))
        self.blocked_ips: set = set()

    def _get_client_key(self, request: Request) -> str:
        """Get unique client identifier"""
        # Try to get real IP from proxy headers
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            client_ip = forwarded_for.split(",")[0].strip()
        else:
            client_ip = request.client.host if request.client else "unknown"

        # Could also use API key or user ID for authenticated requests
        return client_ip

    def _cleanup_old_requests(self, client_key: str, endpoint: str, window: int):
        """Remove requests outside the time window"""
        current_time = time.time()
        cutoff_time = current_time - window

        if client_key in self.requests and endpoint in self.requests[client_key]:
            self.requests[client_key][endpoint] = [
                (ts, count) for ts, count in self.requests[client_key][endpoint]
                if ts > cutoff_time
            ]

    def check_rate_limit(
        self,
        request: Request,
        limit: int,
        window: int
    ) -> tuple[bool, Dict]:
        """
        Check if request exceeds rate limit

        Args:
            request: FastAPI request
            limit: Maximum requests allowed
            window: Time window in seconds

        Returns:
            (allowed, headers) - Whether request is allowed and rate limit headers
        """
        client_key = self._get_client_key(request)
        endpoint = request.url.path

        # Check if IP is blocked
        if client_key in self.blocked_ips:
            return False, {"X-RateLimit-Blocked": "true"}

        # Clean up old requests
        self._cleanup_old_requests(client_key, endpoint, window)

        # Count requests in window
        current_time = time.time()
        request_count = sum(
            count for ts, count in self.requests[client_key][endpoint]
            if ts > current_time - window
        )

        # Check limit
        allowed = request_count < limit

        # Add current request
        self.requests[client_key][endpoint].append((current_time, 1))

        # Calculate headers
        remaining = max(0, limit - request_count - 1)
        reset_time = int(current_time + window)

        headers = {
            RateLimitConfig.HEADERS["limit"]: str(limit),
            RateLimitConfig.HEADERS["remaining"]: str(remaining),
            RateLimitConfig.HEADERS["reset"]: str(reset_time),
        }

        return allowed, headers

    def block_ip(self, ip: str):
        """Block an IP address"""
        self.blocked_ips.add(ip)
        logger.warning(f"🚫 Blocked IP: {ip}")

    def unblock_ip(self, ip: str):
        """Unblock an IP address"""
        self.blocked_ips.discard(ip)
        logger.info(f"✓ Unblocked IP: {ip}")


# Global rate limiter instance
rate_limiter = RateLimiter()


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Rate limiting middleware

    Enforces per-endpoint rate limits.
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Process request with rate limiting"""

        # Get rate limit for this endpoint
        endpoint_path = request.url.path
        endpoint_limit = RateLimitConfig.ENDPOINT_LIMITS.get(endpoint_path)

        if endpoint_limit:
            limit, window = endpoint_limit

            # Check rate limit
            allowed, headers = rate_limiter.check_rate_limit(request, limit, window)

            if not allowed:
                logger.warning(f"⚠ Rate limit exceeded: {endpoint_path} by {request.client.host if request.client else 'unknown'}")

                return JSONResponse(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    content={
                        "detail": "Rate limit exceeded. Please try again later.",
                        "retry_after": headers.get(RateLimitConfig.HEADERS["reset"])
                    },
                    headers=headers
                )

        # Process request
        response = await call_next(request)

        # Add rate limit headers to response
        if endpoint_limit:
            _, headers = rate_limiter.check_rate_limit(request, *endpoint_limit)
            for key, value in headers.items():
                response.headers[key] = value

        return response


# ==================== SECURITY HEADERS ====================

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    Add security headers to all responses

    Implements CSP, HSTS, and other security headers.
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Add security headers to response"""

        response = await call_next(request)

        # Add standard security headers
        for header, value in SecurityHeaders.HEADERS.items():
            response.headers[header] = value

        # Add CSP header
        response.headers["Content-Security-Policy"] = CSPConfig.get_header_value()

        # Add HSTS header (production only)
        if HSTSConfig.ENABLED:
            response.headers["Strict-Transport-Security"] = HSTSConfig.get_header_value()

        return response


# ==================== REQUEST LOGGING ====================

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Log all requests for monitoring and debugging

    Logs request method, path, client IP, and response time.
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Log request details"""

        start_time = time.time()

        # Get client info
        client_ip = request.client.host if request.client else "unknown"
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            client_ip = forwarded_for.split(",")[0].strip()

        # Process request
        try:
            response = await call_next(request)
            status_code = response.status_code
        except Exception as e:
            logger.error(f"Request failed: {request.method} {request.url.path} - {e}")
            raise

        # Calculate response time
        process_time = time.time() - start_time

        # Log request
        log_level = logging.INFO if status_code < 400 else logging.WARNING
        logger.log(
            log_level,
            f"{request.method} {request.url.path} - {status_code} - {process_time:.3f}s - {client_ip}"
        )

        # Add response time header
        response.headers["X-Process-Time"] = f"{process_time:.3f}"

        return response


# ==================== HTTPS REDIRECT ====================

class HTTPSRedirectMiddleware(BaseHTTPMiddleware):
    """
    Redirect HTTP requests to HTTPS

    Only active in production.
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Redirect to HTTPS if needed"""

        # Only in production
        if not IS_PRODUCTION:
            return await call_next(request)

        # Check if request is HTTPS
        if request.url.scheme != "https":
            # Get HTTPS URL
            https_url = request.url.replace(scheme="https")

            logger.info(f"Redirecting to HTTPS: {request.url} -> {https_url}")

            return Response(
                status_code=status.HTTP_301_MOVED_PERMANENTLY,
                headers={"Location": str(https_url)}
            )

        return await call_next(request)


# ==================== INTEGRATION ====================

def add_security_middleware(app: FastAPI):
    """
    Add all security middleware to FastAPI application

    Args:
        app: FastAPI application instance
    """

    # 1. CORS middleware (must be first)
    app.add_middleware(
        CORSMiddleware,
        **CORSConfig.get_middleware_config()
    )
    logger.info("✓ CORS middleware added")

    # 2. HTTPS redirect (production only)
    if IS_PRODUCTION:
        app.add_middleware(HTTPSRedirectMiddleware)
        logger.info("✓ HTTPS redirect middleware added")

    # 3. Security headers
    app.add_middleware(SecurityHeadersMiddleware)
    logger.info("✓ Security headers middleware added")

    # 4. Rate limiting
    app.add_middleware(RateLimitMiddleware)
    logger.info("✓ Rate limiting middleware added")

    # 5. Request logging
    app.add_middleware(RequestLoggingMiddleware)
    logger.info("✓ Request logging middleware added")

    logger.info("🔒 All security middleware initialized")


# ==================== UTILITY FUNCTIONS ====================

def get_rate_limit_stats() -> Dict:
    """Get rate limiter statistics"""
    total_clients = len(rate_limiter.requests)
    total_endpoints = sum(len(endpoints) for endpoints in rate_limiter.requests.values())
    blocked_ips = len(rate_limiter.blocked_ips)

    return {
        "total_clients": total_clients,
        "total_endpoints_tracked": total_endpoints,
        "blocked_ips": blocked_ips,
        "blocked_ip_list": list(rate_limiter.blocked_ips)
    }


def block_ip(ip: str):
    """Block an IP address"""
    rate_limiter.block_ip(ip)


def unblock_ip(ip: str):
    """Unblock an IP address"""
    rate_limiter.unblock_ip(ip)


# Example usage
if __name__ == "__main__":
    from fastapi import FastAPI

    app = FastAPI()

    # Add security middleware
    add_security_middleware(app)

    @app.get("/test")
    async def test():
        return {"message": "Security middleware active"}

    @app.get("/stats")
    async def stats():
        return get_rate_limit_stats()

    print("✓ Security middleware example configured")
