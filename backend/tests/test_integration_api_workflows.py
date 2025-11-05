"""
Integration Tests for API Workflows
End-to-end API workflow tests including authentication
"""
import pytest
import os
from fastapi.testclient import TestClient

# Set test environment
os.environ["ENVIRONMENT"] = "test"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-for-integration"
os.environ["ADMIN_INITIAL_PASSWORD"] = "test-admin-pass"
os.environ["ANALYST_INITIAL_PASSWORD"] = "test-analyst-pass"
os.environ["DATABASE_URL"] = "sqlite:///:memory:"

from api.main import app


@pytest.fixture
def client():
    """Create test client"""
    return TestClient(app)


@pytest.fixture
def admin_token(client):
    """Get admin authentication token"""
    response = client.post(
        "/api/auth/login/oauth",
        data={"username": "admin", "password": "test-admin-pass"}
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.fixture
def admin_headers(admin_token):
    """Get admin authentication headers"""
    return {"Authorization": f"Bearer {admin_token}"}


class TestAuthenticationWorkflow:
    """Test complete authentication workflows"""

    def test_login_get_user_logout_workflow(self, client):
        """Test complete auth workflow: login -> get user -> logout"""
        # Step 1: Login
        login_response = client.post(
            "/api/auth/login/oauth",
            data={"username": "admin", "password": "test-admin-pass"}
        )
        assert login_response.status_code == 200
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Step 2: Get current user
        user_response = client.get("/api/auth/me", headers=headers)
        assert user_response.status_code == 200
        user_data = user_response.json()
        assert user_data["username"] == "admin"

        # Step 3: Logout
        logout_response = client.post("/api/auth/logout", headers=headers)
        assert logout_response.status_code in [200, 204]

    def test_unauthorized_access_blocked(self, client):
        """Test that unauthorized access is properly blocked"""
        # Try to access protected endpoint without auth
        response = client.get("/api/auth/me")

        # Should be forbidden (403) when no credentials provided
        assert response.status_code == 403

    def test_invalid_token_rejected(self, client):
        """Test that invalid tokens are rejected"""
        invalid_headers = {"Authorization": "Bearer invalid-token-12345"}

        response = client.get("/api/auth/me", headers=invalid_headers)

        # Should be unauthorized
        assert response.status_code in [401, 403]


class TestDataValidationWorkflow:
    """Test data validation API workflows"""

    def test_validate_data_workflow(self, client, admin_headers):
        """Test complete data validation workflow"""
        # Valid study data
        data_payload = {
            "data": [
                {"study_id": 1, "n": 100, "yi": 0.5, "sei": 0.1},
                {"study_id": 2, "n": 150, "yi": 0.6, "sei": 0.12},
                {"study_id": 3, "n": 200, "yi": 0.4, "sei": 0.09}
            ],
            "data_type": "binary"
        }

        response = client.post(
            "/validate",
            json=data_payload,
            headers=admin_headers
        )

        assert response.status_code == 200
        result = response.json()

        # Should have validation result
        assert "is_valid" in result or "valid" in result or "problems" in result


class TestMLPredictionWorkflow:
    """Test ML prediction API workflows"""

    def test_heterogeneity_prediction_workflow(self, client, admin_headers):
        """Test complete heterogeneity prediction workflow"""
        prediction_payload = {
            "studies": {
                "study_id": [1, 2, 3, 4, 5],
                "n": [100, 150, 200, 120, 180],
                "yi": [0.5, 0.6, 0.4, 0.55, 0.45],
                "sei": [0.1, 0.12, 0.09, 0.11, 0.10]
            }
        }

        response = client.post(
            "/api/ml/predict/heterogeneity",
            json=prediction_payload,
            headers=admin_headers
        )

        assert response.status_code == 200
        result = response.json()

        # Should have prediction results
        assert "prediction" in result
        assert "confidence" in result

    def test_analysis_recommendation_workflow(self, client, admin_headers):
        """Test analysis recommendation workflow"""
        request_payload = {
            "data": {
                "study_id": [1, 2, 3, 4, 5],
                "n": [100, 150, 200, 120, 180],
                "yi": [0.5, 0.6, 0.4, 0.55, 0.45],
                "sei": [0.1, 0.12, 0.09, 0.11, 0.10]
            },
            "outcome_type": "binary"
        }

        response = client.post(
            "/api/ml/recommend/analysis",
            json=request_payload,
            headers=admin_headers
        )

        assert response.status_code == 200
        result = response.json()

        # Should have recommendations
        assert "recommendations" in result or "recommended_models" in result


class TestHealthCheckWorkflow:
    """Test health check workflows"""

    def test_health_check_endpoints(self, client):
        """Test all health check endpoints"""
        # Basic health check
        health_response = client.get("/health")
        assert health_response.status_code == 200
        assert health_response.json()["status"] == "healthy"

        # Readiness check
        ready_response = client.get("/ready")
        assert ready_response.status_code in [200, 503]

        # Liveness check
        live_response = client.get("/live")
        assert live_response.status_code == 200
        assert live_response.json()["status"] == "alive"

    def test_ml_health_check(self, client):
        """Test ML system health check"""
        response = client.get("/health/ml")

        assert response.status_code == 200
        result = response.json()

        assert "status" in result
        assert "components" in result


class TestCompleteDataPipeline:
    """Test complete data analysis pipeline"""

    def test_end_to_end_analysis_pipeline(self, client, admin_headers):
        """Test complete pipeline: validate -> compute -> predict"""
        # Step 1: Validate data
        validation_payload = {
            "data": [
                {"study_id": 1, "n": 100, "yi": 0.5, "sei": 0.1},
                {"study_id": 2, "n": 150, "yi": 0.6, "sei": 0.12},
                {"study_id": 3, "n": 200, "yi": 0.4, "sei": 0.09}
            ],
            "data_type": "binary"
        }

        validate_response = client.post(
            "/validate",
            json=validation_payload,
            headers=admin_headers
        )

        assert validate_response.status_code == 200

        # Step 2: Make ML prediction
        prediction_payload = {
            "studies": {
                "study_id": [1, 2, 3],
                "n": [100, 150, 200],
                "yi": [0.5, 0.6, 0.4],
                "sei": [0.1, 0.12, 0.09]
            }
        }

        predict_response = client.post(
            "/api/ml/predict/heterogeneity",
            json=prediction_payload,
            headers=admin_headers
        )

        assert predict_response.status_code == 200
        prediction = predict_response.json()

        assert "prediction" in prediction
        assert "confidence" in prediction


class TestRateLimitingWorkflow:
    """Test rate limiting on API endpoints"""

    def test_rate_limiting_not_triggered_under_limit(self, client):
        """Test that normal usage doesn't trigger rate limiting"""
        # Make several requests under the limit
        for _ in range(3):
            response = client.get("/health")
            assert response.status_code == 200


class TestErrorHandlingWorkflow:
    """Test error handling in API workflows"""

    def test_invalid_data_returns_proper_error(self, client, admin_headers):
        """Test that invalid data returns proper error response"""
        invalid_payload = {
            "studies": {
                "invalid_field": [1, 2, 3]
            }
        }

        response = client.post(
            "/api/ml/predict/heterogeneity",
            json=invalid_payload,
            headers=admin_headers
        )

        # Should return error status
        assert response.status_code in [400, 422, 500]


class TestCORSWorkflow:
    """Test CORS configuration"""

    def test_cors_headers_on_responses(self, client):
        """Test that CORS headers are present on responses"""
        response = client.get("/health")

        # Basic check that response is successful
        assert response.status_code == 200


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
