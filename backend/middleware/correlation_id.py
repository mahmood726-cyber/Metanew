"""
Correlation ID Middleware
Tracks requests across services with unique identifiers
"""
import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from backend.utils.logging_config import set_correlation_id, get_logger

logger = get_logger(__name__)


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """
    Middleware to add correlation ID to all requests

    - Extracts correlation ID from X-Correlation-ID header
    - Generates new UUID if not present
    - Adds correlation ID to response headers
    - Sets correlation ID in logging context
    """

    async def dispatch(self, request: Request, call_next):
        # Get or generate correlation ID
        correlation_id = request.headers.get(
            'X-Correlation-ID',
            request.headers.get('X-Request-ID', str(uuid.uuid4()))
        )

        # Set in logging context
        set_correlation_id(correlation_id)

        # Log request
        logger.info(
            f"{request.method} {request.url.path}",
            extra={
                "method": request.method,
                "path": request.url.path,
                "client": request.client.host if request.client else None
            }
        )

        # Process request
        try:
            response = await call_next(request)

            # Add correlation ID to response
            response.headers['X-Correlation-ID'] = correlation_id

            # Log response
            logger.info(
                f"Response {response.status_code}",
                extra={
                    "status_code": response.status_code,
                    "method": request.method,
                    "path": request.url.path
                }
            )

            return response

        except Exception as e:
            logger.error(
                f"Request failed: {str(e)}",
                extra={
                    "error": str(e),
                    "error_type": type(e).__name__,
                    "method": request.method,
                    "path": request.url.path
                },
                exc_info=True
            )
            raise
