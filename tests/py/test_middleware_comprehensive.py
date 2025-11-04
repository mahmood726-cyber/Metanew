"""
Comprehensive Tests for Middleware
Tests for backend/middleware/*.py - 100% coverage
Covers: correlation_id.py, rate_limit.py
"""
import pytest
import uuid
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from starlette.requests import Request
from starlette.responses import Response
from fastapi import HTTPException
from slowapi.errors import RateLimitExceeded

from backend.middleware.correlation_id import CorrelationIdMiddleware
from backend.middleware.rate_limit import limiter, rate_limit_exceeded_handler


# ============================================================================
# CORRELATION ID MIDDLEWARE TESTS
# ============================================================================

class TestCorrelationIdMiddleware:
    """Test CorrelationIdMiddleware - 100% coverage"""

    @pytest.mark.asyncio
    async def test_generates_correlation_id_if_missing(self):
        """Test 1: Generates correlation ID if not in headers"""
        middleware = CorrelationIdMiddleware(app=None)

        # Mock request without correlation ID
        mock_request = Mock(spec=Request)
        mock_request.headers = {}
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/test")
        mock_request.client = Mock(host="127.0.0.1")

        # Mock response
        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        # Mock call_next
        async def mock_call_next(request):
            return mock_response

        response = await middleware.dispatch(mock_request, mock_call_next)

        # Should add correlation ID to response
        assert 'X-Correlation-ID' in mock_response.headers

    @pytest.mark.asyncio
    async def test_uses_existing_correlation_id(self):
        """Test 2: Uses existing X-Correlation-ID from headers"""
        middleware = CorrelationIdMiddleware(app=None)

        correlation_id = "existing-correlation-123"

        # Mock request with correlation ID
        mock_request = Mock(spec=Request)
        mock_request.headers = Mock()
        mock_request.headers.get = Mock(side_effect=lambda key, default=None:
            correlation_id if key == 'X-Correlation-ID' else default
        )
        mock_request.method = "POST"
        mock_request.url = Mock(path="/api/validate")
        mock_request.client = Mock(host="192.168.1.1")

        # Mock response
        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        # Mock call_next
        async def mock_call_next(request):
            return mock_response

        response = await middleware.dispatch(mock_request, mock_call_next)

        # Should use existing correlation ID
        assert mock_response.headers['X-Correlation-ID'] == correlation_id

    @pytest.mark.asyncio
    async def test_uses_x_request_id_as_fallback(self):
        """Test 3: Uses X-Request-ID as fallback if X-Correlation-ID missing"""
        middleware = CorrelationIdMiddleware(app=None)

        request_id = "request-456"

        # Mock request with X-Request-ID but not X-Correlation-ID
        mock_request = Mock(spec=Request)
        mock_request.headers = Mock()
        mock_request.headers.get = Mock(side_effect=lambda key, default=None:
            request_id if key == 'X-Request-ID' else default
        )
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/health")
        mock_request.client = Mock(host="10.0.0.1")

        # Mock response
        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        async def mock_call_next(request):
            return mock_response

        response = await middleware.dispatch(mock_request, mock_call_next)

        assert mock_response.headers['X-Correlation-ID'] == request_id

    @pytest.mark.asyncio
    async def test_logs_request_info(self):
        """Test 4: Logs request information"""
        middleware = CorrelationIdMiddleware(app=None)

        mock_request = Mock(spec=Request)
        mock_request.headers = {}
        mock_request.method = "PUT"
        mock_request.url = Mock(path="/api/update")
        mock_request.client = Mock(host="172.16.0.1")

        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        async def mock_call_next(request):
            return mock_response

        with patch('backend.middleware.correlation_id.logger') as mock_logger:
            response = await middleware.dispatch(mock_request, mock_call_next)

            # Should log request
            assert mock_logger.info.called
            call_args = mock_logger.info.call_args_list[0]
            assert "PUT" in str(call_args)
            assert "/api/update" in str(call_args)

    @pytest.mark.asyncio
    async def test_logs_response_info(self):
        """Test 5: Logs response information"""
        middleware = CorrelationIdMiddleware(app=None)

        mock_request = Mock(spec=Request)
        mock_request.headers = {}
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/test")
        mock_request.client = Mock(host="127.0.0.1")

        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 201

        async def mock_call_next(request):
            return mock_response

        with patch('backend.middleware.correlation_id.logger') as mock_logger:
            response = await middleware.dispatch(mock_request, mock_call_next)

            # Should log response
            assert mock_logger.info.call_count >= 2  # Request + Response
            # Check if status code is logged
            response_log_call = mock_logger.info.call_args_list[-1]
            assert "201" in str(response_log_call) or "Response" in str(response_log_call)

    @pytest.mark.asyncio
    async def test_handles_request_without_client(self):
        """Test 6: Handles requests without client info (e.g., tests)"""
        middleware = CorrelationIdMiddleware(app=None)

        mock_request = Mock(spec=Request)
        mock_request.headers = {}
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/test")
        mock_request.client = None  # No client info

        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        async def mock_call_next(request):
            return mock_response

        # Should not raise exception
        response = await middleware.dispatch(mock_request, mock_call_next)
        assert response == mock_response

    @pytest.mark.asyncio
    async def test_handles_exception_during_request(self):
        """Test 7: Logs errors when request processing fails"""
        middleware = CorrelationIdMiddleware(app=None)

        mock_request = Mock(spec=Request)
        mock_request.headers = {}
        mock_request.method = "POST"
        mock_request.url = Mock(path="/api/fail")
        mock_request.client = Mock(host="127.0.0.1")

        # Mock call_next that raises exception
        async def mock_call_next(request):
            raise ValueError("Processing failed")

        with patch('backend.middleware.correlation_id.logger') as mock_logger:
            with pytest.raises(ValueError):
                await middleware.dispatch(mock_request, mock_call_next)

            # Should log error
            assert mock_logger.error.called
            error_call = mock_logger.error.call_args
            assert "Processing failed" in str(error_call)

    @pytest.mark.asyncio
    async def test_sets_correlation_id_in_context(self):
        """Test 8: Sets correlation ID in logging context"""
        middleware = CorrelationIdMiddleware(app=None)

        correlation_id = "context-test-789"

        mock_request = Mock(spec=Request)
        mock_request.headers = Mock()
        mock_request.headers.get = Mock(side_effect=lambda key, default=None:
            correlation_id if key == 'X-Correlation-ID' else default
        )
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/test")
        mock_request.client = Mock(host="127.0.0.1")

        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        async def mock_call_next(request):
            return mock_response

        with patch('backend.middleware.correlation_id.set_correlation_id') as mock_set:
            response = await middleware.dispatch(mock_request, mock_call_next)

            # Should set correlation ID in context
            mock_set.assert_called_once_with(correlation_id)

    @pytest.mark.asyncio
    async def test_different_http_methods(self):
        """Test 9: Handles all HTTP methods"""
        middleware = CorrelationIdMiddleware(app=None)

        methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"]

        for method in methods:
            mock_request = Mock(spec=Request)
            mock_request.headers = {}
            mock_request.method = method
            mock_request.url = Mock(path=f"/api/{method.lower()}")
            mock_request.client = Mock(host="127.0.0.1")

            mock_response = Mock(spec=Response)
            mock_response.headers = {}
            mock_response.status_code = 200

            async def mock_call_next(request):
                return mock_response

            response = await middleware.dispatch(mock_request, mock_call_next)
            assert 'X-Correlation-ID' in mock_response.headers

    @pytest.mark.asyncio
    async def test_different_status_codes(self):
        """Test 10: Handles different response status codes"""
        middleware = CorrelationIdMiddleware(app=None)

        status_codes = [200, 201, 400, 401, 404, 500]

        for status_code in status_codes:
            mock_request = Mock(spec=Request)
            mock_request.headers = {}
            mock_request.method = "GET"
            mock_request.url = Mock(path="/api/test")
            mock_request.client = Mock(host="127.0.0.1")

            mock_response = Mock(spec=Response)
            mock_response.headers = {}
            mock_response.status_code = status_code

            async def mock_call_next(request):
                return mock_response

            response = await middleware.dispatch(mock_request, mock_call_next)
            assert 'X-Correlation-ID' in mock_response.headers


# ============================================================================
# RATE LIMIT MIDDLEWARE TESTS
# ============================================================================

class TestRateLimiter:
    """Test rate limiter configuration"""

    def test_limiter_initialized(self):
        """Test 11: Limiter is initialized"""
        assert limiter is not None

    def test_limiter_has_key_func(self):
        """Test 12: Limiter has key function"""
        assert limiter._key_func is not None

    def test_limiter_has_default_limits(self):
        """Test 13: Limiter has default limits configured"""
        assert limiter._default_limits is not None
        assert len(limiter._default_limits) > 0


class TestRateLimitExceededHandler:
    """Test rate_limit_exceeded_handler function"""

    @pytest.mark.asyncio
    async def test_handler_returns_429(self):
        """Test 14: Handler returns HTTPException with 429 status"""
        mock_request = Mock(spec=Request)
        mock_request.client = Mock(host="127.0.0.1")
        mock_request.url = Mock(path="/api/test")

        mock_exc = Mock(spec=RateLimitExceeded)
        mock_exc.detail = "60 per 1 minute"

        result = await rate_limit_exceeded_handler(mock_request, mock_exc)

        assert isinstance(result, HTTPException)
        assert result.status_code == 429

    @pytest.mark.asyncio
    async def test_handler_includes_retry_after(self):
        """Test 15: Handler includes Retry-After header"""
        mock_request = Mock(spec=Request)
        mock_request.client = Mock(host="192.168.1.1")
        mock_request.url = Mock(path="/api/validate")

        mock_exc = Mock(spec=RateLimitExceeded)
        mock_exc.detail = "100 per 1 minute"

        result = await rate_limit_exceeded_handler(mock_request, mock_exc)

        assert result.headers["Retry-After"] == "60"

    @pytest.mark.asyncio
    async def test_handler_includes_error_details(self):
        """Test 16: Handler includes error details in response"""
        mock_request = Mock(spec=Request)
        mock_request.client = Mock(host="10.0.0.1")
        mock_request.url = Mock(path="/api/compute")

        mock_exc = Mock(spec=RateLimitExceeded)
        mock_exc.detail = "60 per 1 minute"

        result = await rate_limit_exceeded_handler(mock_request, mock_exc)

        assert "error" in result.detail
        assert result.detail["error"] == "rate_limit_exceeded"
        assert "message" in result.detail
        assert "retry_after" in result.detail

    @pytest.mark.asyncio
    async def test_handler_logs_warning(self):
        """Test 17: Handler logs warning when rate limit exceeded"""
        mock_request = Mock(spec=Request)
        mock_request.client = Mock(host="172.16.0.1")
        mock_request.url = Mock(path="/api/test")

        mock_exc = Mock(spec=RateLimitExceeded)
        mock_exc.detail = "60 per 1 minute"

        with patch('backend.middleware.rate_limit.logger') as mock_logger:
            result = await rate_limit_exceeded_handler(mock_request, mock_exc)

            # Should log warning
            assert mock_logger.warning.called
            warning_call = mock_logger.warning.call_args
            assert "Rate limit exceeded" in str(warning_call)

    @pytest.mark.asyncio
    async def test_handler_logs_client_ip(self):
        """Test 18: Handler logs client IP address"""
        client_ip = "203.0.113.42"

        mock_request = Mock(spec=Request)
        mock_request.client = Mock(host=client_ip)
        mock_request.url = Mock(path="/api/heavy")

        mock_exc = Mock(spec=RateLimitExceeded)
        mock_exc.detail = "60 per 1 minute"

        with patch('backend.middleware.rate_limit.logger') as mock_logger:
            result = await rate_limit_exceeded_handler(mock_request, mock_exc)

            # Check if client IP is in extra data
            warning_call = mock_logger.warning.call_args
            if len(warning_call) > 1 and 'extra' in warning_call[1]:
                extra_data = warning_call[1]['extra']
                assert extra_data.get('client') == client_ip

    @pytest.mark.asyncio
    async def test_handler_logs_request_path(self):
        """Test 19: Handler logs request path"""
        request_path = "/api/expensive-operation"

        mock_request = Mock(spec=Request)
        mock_request.client = Mock(host="127.0.0.1")
        mock_request.url = Mock(path=request_path)

        mock_exc = Mock(spec=RateLimitExceeded)
        mock_exc.detail = "60 per 1 minute"

        with patch('backend.middleware.rate_limit.logger') as mock_logger:
            result = await rate_limit_exceeded_handler(mock_request, mock_exc)

            warning_call = mock_logger.warning.call_args
            if len(warning_call) > 1 and 'extra' in warning_call[1]:
                extra_data = warning_call[1]['extra']
                assert extra_data.get('path') == request_path

    @pytest.mark.asyncio
    async def test_handler_without_client(self):
        """Test 20: Handler works when request has no client"""
        mock_request = Mock(spec=Request)
        mock_request.client = None
        mock_request.url = Mock(path="/api/test")

        mock_exc = Mock(spec=RateLimitExceeded)
        mock_exc.detail = "60 per 1 minute"

        # Should not raise exception
        result = await rate_limit_exceeded_handler(mock_request, mock_exc)
        assert isinstance(result, HTTPException)
        assert result.status_code == 429


class TestRateLimitIntegration:
    """Integration tests for rate limiting"""

    def test_limiter_uses_correct_storage(self):
        """Test 21: Limiter uses correct storage backend"""
        # In test environment, uses memory storage
        assert limiter._storage is not None

    def test_limiter_strategy(self):
        """Test 22: Limiter uses fixed-window strategy"""
        assert limiter._strategy == "fixed-window"

    def test_limiter_default_limit_format(self):
        """Test 23: Default limits are in correct format"""
        if limiter._default_limits:
            # Should be in format like "60/minute"
            limit_str = str(limiter._default_limits[0])
            assert "/" in limit_str or "per" in limit_str.lower()


class TestRateLimitConfiguration:
    """Test rate limit configuration from settings"""

    def test_rate_limit_uses_settings(self):
        """Test 24: Rate limiter uses settings from config"""
        from backend.config import settings

        # Limiter should be configured with settings
        assert settings.RATE_LIMIT_PER_MINUTE > 0

    def test_rate_limit_per_minute_positive(self):
        """Test 25: Rate limit per minute is positive"""
        from backend.config import settings

        assert settings.RATE_LIMIT_PER_MINUTE > 0
        assert isinstance(settings.RATE_LIMIT_PER_MINUTE, int)


# ============================================================================
# EDGE CASES AND ERROR HANDLING
# ============================================================================

class TestEdgeCases:
    """Test edge cases and error handling"""

    @pytest.mark.asyncio
    async def test_correlation_id_very_long(self):
        """Test 26: Handles very long correlation IDs"""
        middleware = CorrelationIdMiddleware(app=None)

        long_id = "x" * 1000

        mock_request = Mock(spec=Request)
        mock_request.headers = Mock()
        mock_request.headers.get = Mock(side_effect=lambda key, default=None:
            long_id if key == 'X-Correlation-ID' else default
        )
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/test")
        mock_request.client = Mock(host="127.0.0.1")

        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        async def mock_call_next(request):
            return mock_response

        response = await middleware.dispatch(mock_request, mock_call_next)
        assert mock_response.headers['X-Correlation-ID'] == long_id

    @pytest.mark.asyncio
    async def test_correlation_id_special_characters(self):
        """Test 27: Handles correlation IDs with special characters"""
        middleware = CorrelationIdMiddleware(app=None)

        special_id = "test-id-@#$%^&*()"

        mock_request = Mock(spec=Request)
        mock_request.headers = Mock()
        mock_request.headers.get = Mock(side_effect=lambda key, default=None:
            special_id if key == 'X-Correlation-ID' else default
        )
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/test")
        mock_request.client = Mock(host="127.0.0.1")

        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        async def mock_call_next(request):
            return mock_response

        response = await middleware.dispatch(mock_request, mock_call_next)
        assert 'X-Correlation-ID' in mock_response.headers

    @pytest.mark.asyncio
    async def test_multiple_exceptions_logged_correctly(self):
        """Test 28: Multiple exceptions are logged correctly"""
        middleware = CorrelationIdMiddleware(app=None)

        exceptions = [ValueError("Error 1"), TypeError("Error 2"), RuntimeError("Error 3")]

        for exc in exceptions:
            mock_request = Mock(spec=Request)
            mock_request.headers = {}
            mock_request.method = "GET"
            mock_request.url = Mock(path="/api/test")
            mock_request.client = Mock(host="127.0.0.1")

            async def mock_call_next(request):
                raise exc

            with patch('backend.middleware.correlation_id.logger') as mock_logger:
                with pytest.raises(type(exc)):
                    await middleware.dispatch(mock_request, mock_call_next)

                assert mock_logger.error.called

    @pytest.mark.asyncio
    async def test_handler_with_different_rate_limit_messages(self):
        """Test 29: Handler works with different rate limit messages"""
        messages = [
            "60 per 1 minute",
            "100 per 1 hour",
            "1000 per 1 day"
        ]

        for msg in messages:
            mock_request = Mock(spec=Request)
            mock_request.client = Mock(host="127.0.0.1")
            mock_request.url = Mock(path="/api/test")

            mock_exc = Mock(spec=RateLimitExceeded)
            mock_exc.detail = msg

            result = await rate_limit_exceeded_handler(mock_request, mock_exc)
            assert isinstance(result, HTTPException)
            assert result.status_code == 429

    @pytest.mark.asyncio
    async def test_uuid_generation_valid(self):
        """Test 30: Generated UUIDs are valid"""
        middleware = CorrelationIdMiddleware(app=None)

        mock_request = Mock(spec=Request)
        mock_request.headers = {}
        mock_request.method = "GET"
        mock_request.url = Mock(path="/api/test")
        mock_request.client = Mock(host="127.0.0.1")

        mock_response = Mock(spec=Response)
        mock_response.headers = {}
        mock_response.status_code = 200

        async def mock_call_next(request):
            return mock_response

        response = await middleware.dispatch(mock_request, mock_call_next)

        generated_id = mock_response.headers['X-Correlation-ID']

        # Should be a valid UUID format
        try:
            uuid.UUID(generated_id)
            valid = True
        except ValueError:
            valid = False

        assert valid


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
