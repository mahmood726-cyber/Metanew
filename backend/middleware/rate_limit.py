"""
Rate Limiting Middleware for EvidenceOS PRIME
Protects API from abuse and ensures fair usage
"""
from fastapi import Request, HTTPException
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from backend.config import settings
from backend.utils.logging_config import get_logger

logger = get_logger(__name__)

# Initialize limiter
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.RATE_LIMIT_PER_MINUTE}/minute"],
    storage_uri="memory://",  # Use Redis in production: redis://redis:6379
    strategy="fixed-window"
)


async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded):
    """
    Custom handler for rate limit exceeded

    Args:
        request: FastAPI request
        exc: RateLimitExceeded exception

    Returns:
        JSON response with 429 status
    """
    logger.warning(
        "Rate limit exceeded",
        extra={
            "client": request.client.host if request.client else None,
            "path": request.url.path,
            "limit": str(exc.detail)
        }
    )

    return HTTPException(
        status_code=429,
        detail={
            "error": "rate_limit_exceeded",
            "message": "Too many requests. Please try again later.",
            "retry_after": 60
        },
        headers={"Retry-After": "60"}
    )
