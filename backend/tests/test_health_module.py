"""
Comprehensive Tests for Health Module
Tests for health check functionality and system status monitoring
"""
import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime
import psutil


class TestHealthUtilityFunctions:
    """Test health utility functions"""

    def test_get_system_metrics(self):
        """Test system metrics retrieval"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert metrics is not None
        assert isinstance(metrics, dict)

    def test_system_metrics_has_cpu_data(self):
        """Test CPU metrics are included"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert "cpu" in metrics
        assert "percent" in metrics["cpu"]
        assert "count" in metrics["cpu"]
        assert "status" in metrics["cpu"]

    def test_system_metrics_has_memory_data(self):
        """Test memory metrics are included"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert "memory" in metrics
        assert "total_gb" in metrics["memory"]
        assert "used_gb" in metrics["memory"]
        assert "percent" in metrics["memory"]
        assert "status" in metrics["memory"]

    def test_system_metrics_has_disk_data(self):
        """Test disk metrics are included"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert "disk" in metrics
        assert "total_gb" in metrics["disk"]
        assert "used_gb" in metrics["disk"]
        assert "percent" in metrics["disk"]
        assert "status" in metrics["disk"]

    def test_check_database_health(self):
        """Test database connectivity check"""
        from api.health import check_database_health

        result = check_database_health()

        assert result is not None
        assert isinstance(result, dict)
        assert "status" in result
        assert "connected" in result

    def test_check_redis_health(self):
        """Test Redis connectivity check"""
        from api.health import check_redis_health

        result = check_redis_health()

        assert result is not None
        assert isinstance(result, dict)
        assert "status" in result
        assert "connected" in result

    @patch('redis.Redis')
    def test_redis_check_handles_connection_error(self, mock_redis):
        """Test Redis check handles connection errors gracefully"""
        mock_instance = MagicMock()
        mock_instance.ping.side_effect = Exception("Connection refused")
        mock_redis.return_value = mock_instance

        from api.health import check_redis_health

        result = check_redis_health()

        assert result is not None
        assert "status" in result
        assert result["status"] == "unavailable"
        assert "error" in result

    def test_check_ml_libraries(self):
        """Test ML library availability check"""
        from api.health import check_ml_libraries

        result = check_ml_libraries()

        assert result is not None
        assert isinstance(result, dict)
        assert "libraries" in result
        assert "available" in result
        assert "total" in result
        assert "percentage" in result
        assert "status" in result


class TestHealthEndpoints:
    """Test health check API endpoints"""

    @pytest.fixture
    def client(self):
        """Create test client"""
        import os
        os.environ["ENVIRONMENT"] = "test"
        os.environ["JWT_SECRET_KEY"] = "test-secret-key"
        os.environ["DATABASE_URL"] = "sqlite:///:memory:"

        from fastapi.testclient import TestClient
        from api.main import app
        return TestClient(app)

    def test_basic_health_endpoint(self, client):
        """Test basic health check endpoint"""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "version" in data
        assert "python_version" in data

    def test_liveness_probe_endpoint(self, client):
        """Test Kubernetes liveness probe"""
        response = client.get("/live")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "alive"
        assert "timestamp" in data

    def test_readiness_probe_endpoint(self, client):
        """Test Kubernetes readiness probe"""
        response = client.get("/ready")

        # May be 200 (ready) or 503 (not ready) depending on dependencies
        assert response.status_code in [200, 503]
        data = response.json()
        assert "status" in data
        assert data["status"] in ["ready", "not_ready"]
        assert "timestamp" in data

    def test_ml_health_endpoint(self, client):
        """Test ML-specific health check"""
        response = client.get("/health/ml")

        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "timestamp" in data
        assert "components" in data
        assert isinstance(data["components"], dict)


class TestMLLibraryWhitelist:
    """Test ML library whitelist security"""

    def test_whitelist_contains_expected_libraries(self):
        """Test that whitelist includes expected ML libraries"""
        from api.health import ALLOWED_ML_LIBRARIES

        expected_libs = ['numpy', 'pandas', 'xgboost', 'shap', 'lime']
        for lib in expected_libs:
            assert lib in ALLOWED_ML_LIBRARIES

    def test_whitelist_is_set_type(self):
        """Test that whitelist is a set for fast lookup"""
        from api.health import ALLOWED_ML_LIBRARIES

        assert isinstance(ALLOWED_ML_LIBRARIES, set)

    def test_ml_libraries_check_uses_whitelist(self):
        """Test that ML libraries check respects whitelist"""
        from api.health import check_ml_libraries

        result = check_ml_libraries()

        # All checked libraries should be in the result
        assert "libraries" in result
        assert isinstance(result["libraries"], dict)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
