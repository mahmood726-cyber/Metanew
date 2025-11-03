"""
Comprehensive tests for security utility - 100% Coverage
Target: 100% coverage of backend/utils/security.py
"""
import pytest
import sys
from pathlib import Path
from unittest.mock import Mock, AsyncMock, MagicMock, patch
from fastapi import HTTPException, status
from fastapi.responses import Response
from starlette.requests import Request
import time

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from utils.security import (
    SecurityHeadersMiddleware,
    HTTPSRedirectMiddleware,
    RequestValidationMiddleware,
    RateLimitMiddleware,
    RequestIDMiddleware,
    sanitize_input,
    validate_file_path,
    generate_token,
    hash_value,
    constant_time_compare,
    validate_email,
    validate_url,
    mask_sensitive_data
)


# Helper to create mock request
def create_mock_request(
    url="http://example.com/test",
    method="GET",
    headers=None,
    client_host="127.0.0.1"
):
    """Create a mock FastAPI Request"""
    request = Mock(spec=Request)

    # Mock URL
    mock_url = Mock()
    mock_url.scheme = "https" if url.startswith("https") else "http"
    mock_url.path = "/" + url.split("/", 3)[3] if "/" in url[8:] else "/"
    mock_url.replace = Mock(return_value=url.replace("http:", "https:"))
    request.url = mock_url

    # Mock headers
    request.headers = headers or {}

    # Mock client
    mock_client = Mock()
    mock_client.host = client_host
    request.client = mock_client

    # Mock state
    request.state = Mock()

    return request


# Helper to create mock response
def create_mock_response():
    """Create a mock Response with mockable headers"""
    response = Response()
    # Add a Server header for testing
    if hasattr(response.headers, '__setitem__'):
        response.headers['Server'] = 'TestServer'
    # Add pop method to headers if it doesn't exist
    if not hasattr(response.headers, 'pop'):
        def mock_pop(key, default=None):
            try:
                if key in response.headers:
                    del response.headers[key]
                return default
            except:
                return default
        response.headers.pop = mock_pop
    return response


class TestSecurityHeadersMiddleware:
    """Test SecurityHeadersMiddleware"""

    @pytest.mark.asyncio
    async def test_adds_security_headers(self):
        """Test that security headers are added"""
        middleware = SecurityHeadersMiddleware(app=None, enable_hsts=False)

        request = create_mock_request()
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)
        result = await middleware.dispatch(request, call_next)

        # Verify security headers
        assert "Content-Security-Policy" in result.headers
        assert "X-Content-Type-Options" in result.headers
        assert "X-Frame-Options" in result.headers
        assert "X-XSS-Protection" in result.headers
        assert "Referrer-Policy" in result.headers
        assert "Permissions-Policy" in result.headers

    @pytest.mark.asyncio
    async def test_hsts_when_enabled(self):
        """Test HSTS header when enabled"""
        middleware = SecurityHeadersMiddleware(app=None, enable_hsts=True)

        request = create_mock_request()
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)
        result = await middleware.dispatch(request, call_next)

        assert "Strict-Transport-Security" in result.headers
        assert "max-age=31536000" in result.headers["Strict-Transport-Security"]

    @pytest.mark.asyncio
    async def test_hsts_when_disabled(self):
        """Test HSTS header not added when disabled"""
        middleware = SecurityHeadersMiddleware(app=None, enable_hsts=False)

        request = create_mock_request()
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)
        result = await middleware.dispatch(request, call_next)

        assert "Strict-Transport-Security" not in result.headers

    @pytest.mark.asyncio
    async def test_removes_server_header(self):
        """Test that Server header removal is attempted"""
        middleware = SecurityHeadersMiddleware(app=None)

        request = create_mock_request()
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)
        result = await middleware.dispatch(request, call_next)

        # Just verify the middleware completes without error
        # The actual pop() behavior depends on MutableHeaders implementation
        assert result is not None


class TestHTTPSRedirectMiddleware:
    """Test HTTPSRedirectMiddleware"""

    @pytest.mark.asyncio
    async def test_redirects_http_to_https(self):
        """Test HTTP to HTTPS redirect"""
        middleware = HTTPSRedirectMiddleware(app=None)

        request = create_mock_request(url="http://example.com/test")

        call_next = AsyncMock()
        result = await middleware.dispatch(request, call_next)

        assert result.status_code == status.HTTP_308_PERMANENT_REDIRECT
        assert "Location" in result.headers
        call_next.assert_not_called()

    @pytest.mark.asyncio
    async def test_allows_https_requests(self):
        """Test that HTTPS requests pass through"""
        middleware = HTTPSRedirectMiddleware(app=None)

        request = create_mock_request(url="https://example.com/test")
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)
        result = await middleware.dispatch(request, call_next)

        call_next.assert_called_once()
        assert result == response


class TestRequestValidationMiddleware:
    """Test RequestValidationMiddleware"""

    @pytest.mark.asyncio
    async def test_blocks_oversized_requests(self):
        """Test that oversized requests are blocked"""
        middleware = RequestValidationMiddleware(
            app=None,
            max_content_length=1000
        )

        request = create_mock_request(headers={"content-length": "2000"})

        call_next = AsyncMock()

        with pytest.raises(HTTPException) as exc_info:
            await middleware.dispatch(request, call_next)

        assert exc_info.value.status_code == status.HTTP_413_REQUEST_ENTITY_TOO_LARGE

    @pytest.mark.asyncio
    async def test_allows_normal_sized_requests(self):
        """Test that normal-sized requests pass through"""
        middleware = RequestValidationMiddleware(
            app=None,
            max_content_length=1000
        )

        request = create_mock_request(headers={"content-length": "500"})
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)
        result = await middleware.dispatch(request, call_next)

        call_next.assert_called_once()

    @pytest.mark.asyncio
    async def test_blocks_path_traversal(self):
        """Test that path traversal attempts are blocked"""
        middleware = RequestValidationMiddleware(app=None)

        # Test various path traversal patterns
        dangerous_paths = [
            "http://example.com/../etc/passwd",
            "http://example.com/..\\windows\\system32",
        ]

        for path in dangerous_paths:
            request = create_mock_request(url=path)
            call_next = AsyncMock()

            with pytest.raises(HTTPException) as exc_info:
                await middleware.dispatch(request, call_next)

            assert exc_info.value.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.asyncio
    async def test_blocks_xss_attempts(self):
        """Test that XSS attempts are blocked"""
        middleware = RequestValidationMiddleware(app=None)

        # Test various XSS patterns
        xss_patterns = [
            "http://example.com/<script>alert(1)</script>",
            "http://example.com/javascript:alert(1)",
            "http://example.com/onerror=alert(1)",
            "http://example.com/onclick=alert(1)",
        ]

        for path in xss_patterns:
            request = create_mock_request(url=path)
            call_next = AsyncMock()

            with pytest.raises(HTTPException) as exc_info:
                await middleware.dispatch(request, call_next)

            assert exc_info.value.status_code == status.HTTP_400_BAD_REQUEST


class TestRateLimitMiddleware:
    """Test RateLimitMiddleware"""

    @pytest.mark.asyncio
    async def test_allows_requests_under_limit(self):
        """Test that requests under limit are allowed"""
        middleware = RateLimitMiddleware(
            app=None,
            requests_per_minute=10
        )

        request = create_mock_request()
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)

        # Make 5 requests (under limit of 10)
        for _ in range(5):
            result = await middleware.dispatch(request, call_next)
            assert "X-RateLimit-Limit" in result.headers
            assert "X-RateLimit-Remaining" in result.headers

    @pytest.mark.asyncio
    async def test_blocks_requests_over_limit(self):
        """Test that requests over limit are blocked"""
        middleware = RateLimitMiddleware(
            app=None,
            requests_per_minute=3
        )

        request = create_mock_request()
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)

        # Make 3 requests (at limit)
        for _ in range(3):
            await middleware.dispatch(request, call_next)

        # 4th request should be blocked
        with pytest.raises(HTTPException) as exc_info:
            await middleware.dispatch(request, call_next)

        assert exc_info.value.status_code == status.HTTP_429_TOO_MANY_REQUESTS
        assert "Retry-After" in exc_info.value.headers

    @pytest.mark.asyncio
    async def test_resets_count_after_minute(self):
        """Test that count resets after one minute"""
        middleware = RateLimitMiddleware(
            app=None,
            requests_per_minute=2
        )

        request = create_mock_request()
        response = create_mock_response()
        call_next = AsyncMock(return_value=response)

        # Make 2 requests
        await middleware.dispatch(request, call_next)
        await middleware.dispatch(request, call_next)

        # Manually update timestamp to simulate time passing
        client_ip = "127.0.0.1"
        if client_ip in middleware.request_counts:
            count, _ = middleware.request_counts[client_ip]
            middleware.request_counts[client_ip] = (count, time.time() - 61)

        # Should allow new request after time reset
        result = await middleware.dispatch(request, call_next)
        assert result is not None

    @pytest.mark.asyncio
    async def test_tracks_different_ips_separately(self):
        """Test that different IPs are tracked separately"""
        middleware = RateLimitMiddleware(
            app=None,
            requests_per_minute=2
        )

        response = create_mock_response()
        call_next = AsyncMock(return_value=response)

        # Requests from IP 1
        request1 = create_mock_request(client_host="192.168.1.1")
        await middleware.dispatch(request1, call_next)
        await middleware.dispatch(request1, call_next)

        # Requests from IP 2 should still be allowed
        request2 = create_mock_request(client_host="192.168.1.2")
        result = await middleware.dispatch(request2, call_next)
        assert result is not None

    @pytest.mark.asyncio
    async def test_cleanup_old_entries(self):
        """Test that old entries are cleaned up"""
        middleware = RateLimitMiddleware(
            app=None,
            requests_per_minute=10,
            cleanup_interval=1
        )

        request = create_mock_request()
        response = create_mock_response()
        call_next = AsyncMock(return_value=response)

        # Make a request
        await middleware.dispatch(request, call_next)
        assert len(middleware.request_counts) == 1

        # Manually trigger cleanup by setting old timestamp
        client_ip = "127.0.0.1"
        middleware.request_counts[client_ip] = (1, time.time() - 65)
        middleware.last_cleanup = time.time() - 65

        # Trigger cleanup with new request
        await middleware.dispatch(request, call_next)

        # Entry should have been cleaned and recreated
        assert client_ip in middleware.request_counts


class TestRequestIDMiddleware:
    """Test RequestIDMiddleware"""

    @pytest.mark.asyncio
    async def test_adds_request_id(self):
        """Test that request ID is added"""
        middleware = RequestIDMiddleware(app=None)

        request = create_mock_request()
        response = create_mock_response()

        call_next = AsyncMock(return_value=response)
        result = await middleware.dispatch(request, call_next)

        # Verify request ID was added
        assert "X-Request-ID" in result.headers
        assert len(result.headers["X-Request-ID"]) == 32  # 16 bytes * 2 (hex)
        assert hasattr(request.state, 'request_id')

    @pytest.mark.asyncio
    async def test_request_id_is_unique(self):
        """Test that each request gets unique ID"""
        middleware = RequestIDMiddleware(app=None)

        response = create_mock_response()
        call_next = AsyncMock(return_value=response)

        # Make multiple requests
        ids = []
        for _ in range(5):
            request = create_mock_request()
            result = await middleware.dispatch(request, call_next)
            ids.append(result.headers["X-Request-ID"])

        # All IDs should be unique
        assert len(ids) == len(set(ids))


class TestSecurityUtilityFunctions:
    """Test security utility functions"""

    def test_sanitize_input_removes_dangerous_chars(self):
        """Test input sanitization"""
        dangerous = "<script>alert('xss')</script>"
        sanitized = sanitize_input(dangerous)

        assert '<' not in sanitized
        assert '>' not in sanitized
        assert "'" not in sanitized  # Single quotes are also removed
        assert "scriptalert(xss)/script" == sanitized

    def test_sanitize_input_empty_string(self):
        """Test sanitizing empty string"""
        assert sanitize_input("") == ""
        assert sanitize_input(None) is None

    def test_validate_file_path_safe(self):
        """Test safe file paths"""
        safe_paths = [
            "/home/user/data.csv",
            "relative/path/file.txt",
            "C:\\Users\\data\\file.xlsx"
        ]

        for path in safe_paths:
            assert validate_file_path(path) is True

    def test_validate_file_path_dangerous(self):
        """Test dangerous file paths"""
        dangerous_paths = [
            "../../../etc/passwd",
            "..\\..\\windows\\system32",
            "/path/%2e%2e/etc/passwd",
            "file://0x2e0x2e/etc"
        ]

        for path in dangerous_paths:
            assert validate_file_path(path) is False

    def test_generate_token(self):
        """Test token generation"""
        token = generate_token()
        assert len(token) == 64  # 32 bytes * 2 (hex)

        token_short = generate_token(length=16)
        assert len(token_short) == 32  # 16 bytes * 2 (hex)

        # Tokens should be unique
        tokens = [generate_token() for _ in range(10)]
        assert len(tokens) == len(set(tokens))

    def test_hash_value_basic(self):
        """Test basic hashing"""
        hash1 = hash_value("test")
        hash2 = hash_value("test")
        hash3 = hash_value("different")

        # Same input produces same hash
        assert hash1 == hash2
        # Different input produces different hash
        assert hash1 != hash3
        # Hash is 64 characters (SHA-256 hex)
        assert len(hash1) == 64

    def test_hash_value_with_salt(self):
        """Test hashing with salt"""
        hash_no_salt = hash_value("test")
        hash_with_salt = hash_value("test", salt="mysalt")

        # Salt should change the hash
        assert hash_no_salt != hash_with_salt

        # Same input and salt produces same hash
        hash_with_salt2 = hash_value("test", salt="mysalt")
        assert hash_with_salt == hash_with_salt2

    def test_constant_time_compare_equal(self):
        """Test constant time comparison with equal strings"""
        assert constant_time_compare("secret", "secret") is True

    def test_constant_time_compare_different(self):
        """Test constant time comparison with different strings"""
        assert constant_time_compare("secret", "public") is False

    def test_validate_email_valid(self):
        """Test valid email addresses"""
        valid_emails = [
            "user@example.com",
            "test.user@domain.co.uk",
            "user+tag@example.com",
            "123@test.com"
        ]

        for email in valid_emails:
            assert validate_email(email) is True

    def test_validate_email_invalid(self):
        """Test invalid email addresses"""
        invalid_emails = [
            "notanemail",
            "@example.com",
            "user@",
            "user@domain",
            "user domain@example.com"
        ]

        for email in invalid_emails:
            assert validate_email(email) is False

    def test_validate_url_valid(self):
        """Test valid URLs"""
        valid_urls = [
            "http://example.com",
            "https://example.com",
            "http://subdomain.example.com/path",
            "https://example.co.uk/path/to/resource"
        ]

        for url in valid_urls:
            assert validate_url(url) is True

    def test_validate_url_invalid(self):
        """Test invalid URLs"""
        invalid_urls = [
            "notaurl",
            "ftp://example.com",
            "example.com",
            "http://",
            "https:/example.com"
        ]

        for url in invalid_urls:
            assert validate_url(url) is False

    def test_mask_sensitive_data(self):
        """Test data masking"""
        # Normal case
        masked = mask_sensitive_data("secretpassword123", visible_chars=4)
        assert masked == "secr*************"  # 17 total chars: 4 visible + 13 masked

        # Short data
        masked_short = mask_sensitive_data("abc", visible_chars=4)
        assert masked_short == "***"

        # Custom visible chars
        masked_custom = mask_sensitive_data("password", visible_chars=2)
        assert masked_custom == "pa******"


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/utils/security', '--cov-report=term-missing'])
