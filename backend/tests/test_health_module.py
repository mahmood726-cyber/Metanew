"""
Comprehensive Tests for Health Module
Tests for health check functionality and system status monitoring
"""
import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime
import psutil


class TestHealthStatus:
    """Test health status functions"""

    def test_get_health_status_basic(self):
        """Test basic health status retrieval"""
        from api.health import get_health_status

        status = get_health_status()

        assert status is not None
        assert isinstance(status, dict)
        assert "status" in status
        assert status["status"] in ["healthy", "degraded", "unhealthy"]

    def test_health_status_includes_timestamp(self):
        """Test that health status includes timestamp"""
        from api.health import get_health_status

        status = get_health_status()

        assert "timestamp" in status
        # Verify timestamp is a valid datetime string
        datetime.fromisoformat(status["timestamp"])

    def test_health_status_includes_version(self):
        """Test that health status includes version info"""
        from api.health import get_health_status

        status = get_health_status()

        assert "version" in status or "app_version" in status

    def test_health_status_includes_python_version(self):
        """Test that health status includes Python version"""
        from api.health import get_health_status

        status = get_health_status()

        assert "python_version" in status or "python" in status


class TestSystemMetrics:
    """Test system metrics collection"""

    def test_get_system_metrics(self):
        """Test system metrics retrieval"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert metrics is not None
        assert isinstance(metrics, dict)

    def test_cpu_metrics_present(self):
        """Test CPU metrics are included"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert "cpu_percent" in metrics or "cpu" in metrics

    def test_memory_metrics_present(self):
        """Test memory metrics are included"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert "memory_percent" in metrics or "memory" in metrics

    def test_disk_metrics_present(self):
        """Test disk metrics are included"""
        from api.health import get_system_metrics

        metrics = get_system_metrics()

        assert "disk_percent" in metrics or "disk" in metrics or "disk_usage" in metrics


class TestDependencyChecks:
    """Test dependency health checks"""

    def test_check_database_connectivity(self):
        """Test database connectivity check"""
        from api.health import check_database

        result = check_database()

        assert result is not None
        assert isinstance(result, dict)
        assert "status" in result or "available" in result

    def test_check_redis_connectivity(self):
        """Test Redis connectivity check"""
        from api.health import check_redis

        result = check_redis()

        assert result is not None
        assert isinstance(result, dict)
        assert "status" in result or "available" in result

    @patch('redis.Redis')
    def test_redis_check_handles_connection_error(self, mock_redis):
        """Test Redis check handles connection errors gracefully"""
        mock_redis.side_effect = Exception("Connection refused")

        from api.health import check_redis

        result = check_redis()

        assert result is not None
        # Should return error status, not crash
        assert "error" in result or "status" in result


class TestReadinessProbe:
    """Test Kubernetes readiness probe"""

    def test_readiness_check_healthy_system(self):
        """Test readiness when all systems healthy"""
        from api.health import check_readiness

        result = check_readiness()

        assert result is not None
        assert isinstance(result, dict)
        assert "ready" in result or "status" in result

    @patch('api.health.check_database')
    def test_readiness_check_unhealthy_database(self, mock_db_check):
        """Test readiness when database unhealthy"""
        mock_db_check.return_value = {"status": "unhealthy"}

        from api.health import check_readiness

        result = check_readiness()

        # Should indicate not ready
        assert result["ready"] is False or result["status"] == "not_ready"


class TestLivenessProbe:
    """Test Kubernetes liveness probe"""

    def test_liveness_check_returns_alive(self):
        """Test liveness probe returns alive status"""
        from api.health import check_liveness

        result = check_liveness()

        assert result is not None
        assert isinstance(result, dict)
        assert "alive" in result or "status" in result


class TestMLHealthCheck:
    """Test ML system health checks"""

    def test_ml_health_check(self):
        """Test ML system health status"""
        from api.health import check_ml_health

        result = check_ml_health()

        assert result is not None
        assert isinstance(result, dict)
        assert "status" in result

    def test_ml_models_loaded(self):
        """Test checking if ML models are loaded"""
        from api.health import check_ml_models_loaded

        result = check_ml_models_loaded()

        assert result is not None
        assert isinstance(result, dict)

    def test_ml_cache_status(self):
        """Test ML cache health status"""
        from api.health import check_ml_cache

        result = check_ml_cache()

        assert result is not None
        assert isinstance(result, dict)


class TestHealthEndpointIntegration:
    """Integration tests for health endpoints"""

    def test_health_endpoint_response_structure(self):
        """Test health endpoint returns proper structure"""
        from api.health import get_health_status

        status = get_health_status()

        # Should have all required fields
        required_fields = ["status", "timestamp"]
        for field in required_fields:
            assert field in status, f"Missing required field: {field}"

    def test_health_status_values_valid(self):
        """Test health status values are valid"""
        from api.health import get_health_status

        status = get_health_status()

        # Status should be one of valid values
        valid_statuses = ["healthy", "degraded", "unhealthy"]
        assert status["status"] in valid_statuses


class TestPerformanceMonitoring:
    """Test performance monitoring functions"""

    def test_get_response_times(self):
        """Test getting response time metrics"""
        from api.health import get_response_times

        metrics = get_response_times()

        assert metrics is not None
        assert isinstance(metrics, dict)

    def test_get_request_counts(self):
        """Test getting request count metrics"""
        from api.health import get_request_counts

        metrics = get_request_counts()

        assert metrics is not None
        assert isinstance(metrics, dict)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
