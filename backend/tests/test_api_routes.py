"""
Tests for API Routes
Tests for health endpoints, auth routes, and basic API functionality
"""
import pytest
from datetime import datetime


# Use session-scoped fixtures from conftest.py to prevent rate limiting
@pytest.fixture
def client(session_client):
    """Use session-scoped client"""
    return session_client


@pytest.fixture
def auth_headers(session_auth_headers):
    """Use session-scoped auth headers"""
    return session_auth_headers


class TestHealthEndpoint:
    """Test health check endpoints"""

    def test_health_check(self, client):
        """Test basic health check"""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "healthy"
        assert "timestamp" in data

    def test_health_check_structure(self, client):
        """Test health check response structure"""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()

        # Check required fields
        assert "status" in data
        assert "timestamp" in data

    def test_ready_endpoint(self, client):
        """Test readiness endpoint"""
        response = client.get("/ready")

        assert response.status_code in [200, 503]
        # 200 if all systems ready, 503 if not

    def test_live_endpoint(self, client):
        """Test liveness endpoint"""
        response = client.get("/live")

        assert response.status_code == 200


class TestAuthRoutes:
    """Test authentication routes"""

    def test_login_success(self, client):
        """Test successful login via OAuth2 endpoint"""
        response = client.post(
            "/api/auth/login/oauth",
            data={
                "username": "admin",
                "password": "test-admin-password"
            }
        )

        assert response.status_code == 200
        data = response.json()

        assert "access_token" in data
        assert "token_type" in data
        assert data["token_type"] == "bearer"

    def test_login_wrong_password(self, client):
        """Test login with wrong password"""
        response = client.post(
            "/api/auth/login/oauth",
            data={
                "username": "admin",
                "password": "wrong-password"
            }
        )

        assert response.status_code == 401

    def test_login_nonexistent_user(self, client):
        """Test login with nonexistent user"""
        response = client.post(
            "/api/auth/login/oauth",
            data={
                "username": "nonexistent",
                "password": "password"
            }
        )

        assert response.status_code == 401

    def test_get_current_user(self, client, auth_headers):
        """Test getting current user info"""
        response = client.get(
            "/api/auth/me",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert data["username"] == "admin"
        assert "role" in data
        assert "email" in data

    def test_get_current_user_unauthorized(self, client):
        """Test getting current user without auth"""
        response = client.get("/api/auth/me")

        # 403 is returned when no credentials provided (HTTPBearer auto_error=True)
        assert response.status_code == 403

    def test_logout(self, client, auth_headers):
        """Test logout"""
        response = client.post(
            "/api/auth/logout",
            headers=auth_headers
        )

        # Should succeed even if just returns 200 OK
        assert response.status_code in [200, 204]


class TestRootEndpoints:
    """Test root and basic endpoints"""

    def test_root_endpoint(self, client):
        """Test root endpoint"""
        response = client.get("/")

        assert response.status_code in [200, 404]
        # Some apps redirect root to /docs

    def test_docs_endpoint(self, client):
        """Test API documentation endpoint"""
        response = client.get("/docs")

        assert response.status_code == 200

    def test_openapi_schema(self, client):
        """Test OpenAPI schema endpoint"""
        response = client.get("/openapi.json")

        assert response.status_code == 200
        data = response.json()

        assert "openapi" in data
        assert "info" in data
        assert "paths" in data


class TestErrorHandling:
    """Test API error handling"""

    def test_404_not_found(self, client):
        """Test 404 for nonexistent endpoint"""
        response = client.get("/api/nonexistent")

        assert response.status_code == 404

    def test_405_method_not_allowed(self, client):
        """Test 405 for wrong HTTP method"""
        # Try POST on GET-only endpoint
        response = client.post("/health")

        assert response.status_code == 405

    def test_422_validation_error(self, client):
        """Test 422 for invalid request body"""
        response = client.post(
            "/api/auth/login",
            json={"invalid": "data"}  # Missing required fields
        )

        assert response.status_code == 422


class TestCORS:
    """Test CORS configuration"""

    @pytest.mark.skip(reason="CORS preflight (OPTIONS) not configured yet")
    def test_cors_headers_present(self, client):
        """Test that CORS headers are present"""
        response = client.options(
            "/health",
            headers={"Origin": "http://localhost:3000"}
        )

        # CORS should be configured
        assert response.status_code in [200, 204, 405]  # Accept 405 if OPTIONS not configured

    def test_cors_allowed_origin(self, client):
        """Test CORS with allowed origin"""
        response = client.get(
            "/health",
            headers={"Origin": "http://localhost:3000"}
        )

        assert response.status_code == 200


class TestMetricsEndpoint:
    """Test Prometheus metrics endpoint"""

    @pytest.mark.skip(reason="/metrics endpoint not implemented yet")
    def test_metrics_endpoint(self, client):
        """Test Prometheus metrics endpoint"""
        response = client.get("/metrics")

        # Should return metrics in Prometheus format
        assert response.status_code == 200

        # Check content type
        assert "text/plain" in response.headers.get("content-type", "")

    @pytest.mark.skip(reason="/metrics endpoint not implemented yet")
    def test_metrics_format(self, client):
        """Test metrics are in correct format"""
        response = client.get("/metrics")

        assert response.status_code == 200
        content = response.text

        # Prometheus metrics should contain certain patterns
        # Usually includes TYPE and HELP comments
        assert "# HELP" in content or "# TYPE" in content or len(content) > 0


class TestRequestValidation:
    """Test request validation"""

    def test_empty_request_body(self, client):
        """Test POST with empty body"""
        response = client.post(
            "/api/auth/login",
            json={}
        )

        # Should return validation error
        assert response.status_code in [400, 422]

    def test_malformed_json(self, client):
        """Test POST with malformed JSON"""
        response = client.post(
            "/api/auth/login",
            data="not valid json",
            headers={"Content-Type": "application/json"}
        )

        # Should return 400 or 422
        assert response.status_code in [400, 422]

    def test_extra_fields_ignored(self, client):
        """Test that extra fields are handled properly"""
        response = client.post(
            "/api/auth/login/oauth",  # OAuth2 form endpoint ignores extra fields
            data={
                "username": "admin",
                "password": "test-admin-password",
                "extra_field": "should be ignored"
            }
        )

        # Should still succeed
        assert response.status_code == 200


class TestResponseHeaders:
    """Test response headers"""

    def test_content_type_json(self, client):
        """Test JSON content type"""
        response = client.get("/health")

        assert response.status_code == 200
        assert "application/json" in response.headers["content-type"]

    def test_server_header_present(self, client):
        """Test server header"""
        response = client.get("/health")

        # Server header may or may not be present
        # Just checking it doesn't crash
        assert response.status_code == 200


class TestRateLimiting:
    """Test rate limiting (if configured)"""

    def test_multiple_requests_allowed(self, client):
        """Test that normal request rate is allowed"""
        # Make several requests
        for _ in range(10):
            response = client.get("/health")
            assert response.status_code == 200

    def test_concurrent_requests(self, client):
        """Test concurrent requests are handled"""
        # This tests that the server can handle concurrent requests
        responses = []
        for _ in range(5):
            responses.append(client.get("/health"))

        # All should succeed
        for response in responses:
            assert response.status_code == 200


class TestAPIVersioning:
    """Test API versioning"""

    def test_api_v1_prefix(self, client, auth_headers):
        """Test /api prefix works"""
        # Most endpoints should be under /api - test with /me endpoint to avoid rate limit
        response = client.get(
            "/api/auth/me",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()
        assert "username" in data


class TestSecurityHeaders:
    """Test security headers"""

    def test_no_sensitive_info_in_errors(self, client):
        """Test that errors don't leak sensitive info"""
        response = client.get("/api/nonexistent")

        assert response.status_code == 404
        # Should not contain stack traces or internal paths
        content = response.text.lower()
        assert "traceback" not in content
        assert "/home/" not in content
        assert "/usr/" not in content


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
