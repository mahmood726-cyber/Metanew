"""
Comprehensive API Tests for EvidenceOS PRIME
Tests all endpoints with various scenarios
"""
import pytest
from fastapi.testclient import TestClient
import sys
import os

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from backend.api.main_improved import app

@pytest.fixture
def client():
    """Test client fixture"""
    return TestClient(app)


@pytest.fixture
def valid_binary_data():
    """Valid binary data for testing"""
    return {
        "data": [
            {"study_id": "S1", "treatment": "A", "events": 10, "n": 100},
            {"study_id": "S2", "treatment": "B", "events": 20, "n": 200}
        ],
        "data_type": "binary"
    }


@pytest.fixture
def invalid_binary_data():
    """Invalid binary data (events > n)"""
    return {
        "data": [
            {"study_id": "S1", "treatment": "A", "events": 150, "n": 100}
        ],
        "data_type": "binary"
    }


# ============================================================================
# HEALTH CHECK TESTS
# ============================================================================

class TestHealthChecks:
    """Test suite for health check endpoints"""

    def test_root_endpoint(self, client):
        """Test root endpoint returns service info"""
        response = client.get("/")
        assert response.status_code == 200

        data = response.json()
        assert "service" in data
        assert "version" in data
        assert "status" in data
        assert data["status"] == "operational"

    def test_health_check(self, client):
        """Test basic health check"""
        response = client.get("/health")
        assert response.status_code == 200

        data = response.json()
        assert data["status"] == "healthy"
        assert "version" in data
        assert "python_version" in data

    def test_liveness_probe(self, client):
        """Test Kubernetes liveness probe"""
        response = client.get("/health/live")
        assert response.status_code == 200
        assert response.json()["status"] == "alive"

    def test_readiness_probe(self, client):
        """Test Kubernetes readiness probe"""
        response = client.get("/health/ready")
        assert response.status_code in [200, 503]  # May be unhealthy without Redis

        data = response.json()
        assert "status" in data
        assert "checks" in data

    def test_correlation_id_in_response(self, client):
        """Test that correlation ID is added to responses"""
        response = client.get("/health")
        assert "X-Correlation-ID" in response.headers


# ============================================================================
# VALIDATION TESTS
# ============================================================================

class TestValidation:
    """Test suite for data validation endpoint"""

    def test_validate_valid_binary_data(self, client, valid_binary_data):
        """Test validation with valid binary data"""
        response = client.post("/validate", json=valid_binary_data)
        assert response.status_code == 200

        data = response.json()
        assert data["is_valid"] is True
        assert data["summary"]["errors"] == 0
        assert "problems" in data

    def test_validate_invalid_binary_data(self, client, invalid_binary_data):
        """Test validation with events > n"""
        response = client.post("/validate", json=invalid_binary_data)
        assert response.status_code == 200

        data = response.json()
        assert data["is_valid"] is False
        assert data["summary"]["errors"] > 0
        assert len(data["problems"]) > 0

    def test_validate_empty_data(self, client):
        """Test validation with empty data"""
        response = client.post("/validate", json={
            "data": [],
            "data_type": "binary"
        })
        assert response.status_code in [400, 422]

    def test_validate_missing_required_columns(self, client):
        """Test validation with missing required columns"""
        response = client.post("/validate", json={
            "data": [
                {"events": 10, "n": 100}  # Missing study_id, treatment
            ],
            "data_type": "binary"
        })
        assert response.status_code in [400, 422]

    def test_validate_continuous_data(self, client):
        """Test validation with continuous data"""
        response = client.post("/validate", json={
            "data": [
                {"study_id": "S1", "treatment": "A", "mean": 10.5, "sd": 2.3, "n": 50},
                {"study_id": "S2", "treatment": "B", "mean": 12.1, "sd": 2.8, "n": 60}
            ],
            "data_type": "continuous"
        })
        assert response.status_code == 200
        data = response.json()
        assert "is_valid" in data

    def test_validate_duplicate_detection(self, client):
        """Test duplicate detection"""
        response = client.post("/validate", json={
            "data": [
                {"study_id": "S1", "treatment": "A", "events": 10, "n": 100},
                {"study_id": "S1", "treatment": "A", "events": 15, "n": 100}  # Duplicate
            ],
            "data_type": "binary"
        })
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] is False
        assert any("duplicate" in p.get("message", "").lower() for p in data.get("problems", []))


# ============================================================================
# EFFECT SIZE COMPUTATION TESTS
# ============================================================================

class TestEffectSizeComputation:
    """Test suite for effect size computation"""

    def test_compute_effect_sizes_binary_or(self, client):
        """Test computing odds ratios"""
        response = client.post("/compute/yi", json={
            "data": [
                {"study_id": "S1", "events1": 10, "n1": 100, "events2": 20, "n2": 100}
            ],
            "measure": "OR"
        })
        assert response.status_code == 200

        data = response.json()
        assert "data" in data
        assert data["measure"] == "OR"
        assert data["n_observations"] > 0

    def test_compute_effect_sizes_empty_data(self, client):
        """Test computation with empty data"""
        response = client.post("/compute/yi", json={
            "data": [],
            "measure": "OR"
        })
        assert response.status_code in [400, 404]

    def test_compute_effect_sizes_invalid_measure(self, client):
        """Test computation with invalid measure"""
        response = client.post("/compute/yi", json={
            "data": [
                {"study_id": "S1", "events1": 10, "n1": 100, "events2": 20, "n2": 100}
            ],
            "measure": "INVALID"
        })
        assert response.status_code == 400


# ============================================================================
# EVIDENCE OBJECT TESTS
# ============================================================================

class TestEvidenceObject:
    """Test suite for evidence object endpoints"""

    def test_compute_evidence_hash(self, client):
        """Test computing evidence object hash"""
        response = client.post("/evidence/hash", json={
            "evidence_id": "TEST001",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        })
        assert response.status_code == 200

        data = response.json()
        assert "content_hash" in data
        assert "evidence_id" in data
        assert len(data["content_hash"]) == 64  # SHA-256 hash

    def test_validate_evidence_object(self, client):
        """Test validating evidence object"""
        response = client.post("/evidence/validate", json={
            "evidence_id": "TEST001",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        })
        assert response.status_code == 200

        data = response.json()
        assert data["valid"] is True
        assert "content_hash" in data
        assert data["n_studies"] == 0
        assert data["n_observations"] == 0

    def test_validate_invalid_evidence_object(self, client):
        """Test validation with invalid evidence object"""
        response = client.post("/evidence/validate", json={
            # Missing required fields
            "version": "1.0.0"
        })
        assert response.status_code in [400, 422]


# ============================================================================
# HEALTH ECONOMICS TESTS
# ============================================================================

class TestHealthEconomics:
    """Test suite for health economics endpoints"""

    def test_generate_psa_parameters(self, client):
        """Test PSA parameter generation"""
        response = client.post("/econ/params", json={
            "n_iterations": 1000,
            "hr_progression": 0.7,
            "hr_death": 0.8,
            "cost_treatment": 10000,
            "seed": 42
        })
        assert response.status_code == 200

        data = response.json()
        assert data["n_iterations"] == 1000
        assert "parameters" in data
        assert "hr_progression" in data["parameters"]
        assert len(data["parameters"]["hr_progression"]) == 1000

    def test_psa_parameters_validation(self, client):
        """Test PSA parameter validation"""
        # Too few iterations
        response = client.post("/econ/params", json={
            "n_iterations": 50
        })
        assert response.status_code in [400, 422]

        # Too many iterations
        response = client.post("/econ/params", json={
            "n_iterations": 200000
        })
        assert response.status_code in [400, 422]


# ============================================================================
# UTILITY TESTS
# ============================================================================

class TestUtilities:
    """Test suite for utility endpoints"""

    def test_convert_or_to_rr(self, client):
        """Test OR to RR conversion"""
        response = client.post("/convert/or_to_rr", json={
            "or": 2.0,
            "control_event_rate": 0.2
        })
        assert response.status_code == 200

        data = response.json()
        assert "rr" in data
        assert data["or"] == 2.0
        assert data["control_event_rate"] == 0.2
        assert data["rr"] > 0

    def test_convert_or_to_rr_invalid_cer(self, client):
        """Test conversion with invalid control event rate"""
        response = client.post("/convert/or_to_rr", json={
            "or": 2.0,
            "control_event_rate": 1.5  # Invalid (> 1)
        })
        assert response.status_code in [400, 422]

    def test_convert_or_to_rr_missing_params(self, client):
        """Test conversion with missing parameters"""
        response = client.post("/convert/or_to_rr", json={
            "or": 2.0
            # Missing control_event_rate
        })
        assert response.status_code in [400, 422]

    def test_format_league_table(self, client):
        """Test league table formatting"""
        response = client.post("/format/league_table", json={
            "treatments": ["A", "B", "C"],
            "effects": {
                "A_vs_B": {"est": 1.5, "ci_lower": 1.2, "ci_upper": 1.8},
                "A_vs_C": {"est": 1.8, "ci_lower": 1.4, "ci_upper": 2.2}
            }
        })
        assert response.status_code == 200

        data = response.json()
        assert "league_table" in data
        assert len(data["treatments"]) == 3

    def test_format_league_table_empty_treatments(self, client):
        """Test league table with empty treatments"""
        response = client.post("/format/league_table", json={
            "treatments": [],
            "effects": {}
        })
        assert response.status_code in [400, 422]


# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

class TestErrorHandling:
    """Test suite for error handling"""

    def test_404_not_found(self, client):
        """Test 404 for non-existent endpoint"""
        response = client.get("/nonexistent")
        assert response.status_code == 404

    def test_method_not_allowed(self, client):
        """Test 405 for wrong HTTP method"""
        response = client.get("/validate")  # Should be POST
        assert response.status_code == 405

    def test_malformed_json(self, client):
        """Test error handling for malformed JSON"""
        response = client.post(
            "/validate",
            data="not valid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422

    def test_cors_headers(self, client):
        """Test CORS headers are present"""
        response = client.options("/validate")
        # CORS headers should be present
        assert "access-control-allow-origin" in response.headers or response.status_code == 405


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

class TestIntegration:
    """Integration tests for complete workflows"""

    def test_complete_validation_workflow(self, client):
        """Test complete validation workflow"""
        # 1. Validate data
        validation_response = client.post("/validate", json={
            "data": [
                {"study_id": "S1", "treatment": "A", "events": 10, "n": 100},
                {"study_id": "S2", "treatment": "B", "events": 20, "n": 200}
            ],
            "data_type": "binary"
        })
        assert validation_response.status_code == 200
        assert validation_response.json()["is_valid"] is True

        # 2. Compute effect sizes
        computation_response = client.post("/compute/yi", json={
            "data": [
                {"study_id": "S1", "events1": 10, "n1": 100, "events2": 20, "n2": 100}
            ],
            "measure": "OR"
        })
        assert computation_response.status_code == 200

    def test_health_economics_workflow(self, client):
        """Test health economics workflow"""
        # Generate PSA parameters
        psa_response = client.post("/econ/params", json={
            "n_iterations": 1000,
            "hr_progression": 0.7,
            "hr_death": 0.8,
            "cost_treatment": 10000,
            "seed": 42
        })
        assert psa_response.status_code == 200

        psa_data = psa_response.json()
        assert len(psa_data["parameters"]["hr_progression"]) == 1000


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
