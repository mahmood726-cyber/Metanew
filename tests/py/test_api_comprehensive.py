"""
Comprehensive tests for FastAPI endpoints
"""
import pytest
from fastapi.testclient import TestClient
import sys
import os
import json

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from api.main import app

client = TestClient(app)


class TestHealthEndpoints:
    """Tests for health check endpoints"""

    def test_root_endpoint(self):
        """Test root endpoint returns service info"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["service"] == "EvidenceOS PRIME API"
        assert data["status"] == "operational"
        assert "timestamp" in data

    def test_health_endpoint(self):
        """Test health endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "python_version" in data
        assert "timestamp" in data


class TestValidationEndpoint:
    """Tests for /validate endpoint"""

    def test_validate_binary_data_valid(self):
        """Test validation with valid binary data"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "treatment": "A",
                    "events": 10,
                    "n": 100
                },
                {
                    "study_id": "S2",
                    "treatment": "B",
                    "events": 20,
                    "n": 200
                }
            ],
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] == True
        assert data["summary"]["errors"] == 0

    def test_validate_binary_data_events_exceed_n(self):
        """Test validation catches events > n"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "treatment": "A",
                    "events": 150,
                    "n": 100
                }
            ],
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] == False
        assert data["summary"]["errors"] > 0

    def test_validate_missing_required_columns(self):
        """Test validation catches missing columns"""
        payload = {
            "data": [
                {
                    "events": 10,
                    "n": 100
                }
            ],
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] == False

    def test_validate_continuous_data(self):
        """Test validation of continuous data"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "treatment": "A",
                    "mean": 10.5,
                    "sd": 2.0,
                    "n": 50
                }
            ],
            "data_type": "continuous"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] == True

    def test_validate_negative_sd(self):
        """Test validation catches negative SD"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "treatment": "A",
                    "mean": 10.0,
                    "sd": -2.0,
                    "n": 50
                }
            ],
            "data_type": "continuous"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] == False

    def test_validate_empty_data(self):
        """Test validation with empty data"""
        payload = {
            "data": [],
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] == False

    def test_validate_duplicates(self):
        """Test detection of duplicate entries"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "treatment": "A",
                    "events": 10,
                    "n": 100
                },
                {
                    "study_id": "S1",
                    "treatment": "A",
                    "events": 15,
                    "n": 100
                }
            ],
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        # Should detect duplicate study_id + treatment
        assert data["summary"]["errors"] > 0


class TestComputeEffectSizes:
    """Tests for /compute/yi endpoint"""

    def test_compute_or(self):
        """Test OR computation"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "events1": 10,
                    "n1": 100,
                    "events2": 5,
                    "n2": 100
                }
            ],
            "measure": "OR"
        }

        response = client.post("/compute/yi", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["measure"] == "OR"
        assert len(data["data"]) == 1
        assert "yi" in data["data"][0]
        assert "sei" in data["data"][0]

    def test_compute_rr(self):
        """Test RR computation"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "events1": 10,
                    "n1": 100,
                    "events2": 5,
                    "n2": 100
                }
            ],
            "measure": "RR"
        }

        response = client.post("/compute/yi", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["measure"] == "RR"

    def test_compute_md(self):
        """Test MD computation"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "mean1": 10.0,
                    "sd1": 2.0,
                    "n1": 50,
                    "mean2": 8.0,
                    "sd2": 2.0,
                    "n2": 50
                }
            ],
            "measure": "MD"
        }

        response = client.post("/compute/yi", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["measure"] == "MD"

    def test_compute_hr(self):
        """Test HR computation"""
        payload = {
            "data": [
                {
                    "study_id": "S1",
                    "hr": 0.7,
                    "ci_lower": 0.5,
                    "ci_upper": 0.98
                }
            ],
            "measure": "HR"
        }

        response = client.post("/compute/yi", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["measure"] == "HR"

    def test_compute_invalid_data(self):
        """Test error handling for invalid data"""
        payload = {
            "data": [
                {
                    "study_id": "S1"
                    # Missing required fields
                }
            ],
            "measure": "OR"
        }

        response = client.post("/compute/yi", json=payload)
        assert response.status_code == 400


class TestEvidenceObjectEndpoints:
    """Tests for Evidence Object endpoints"""

    def test_compute_hash(self):
        """Test hash computation"""
        payload = {
            "evidence_id": "TEST001",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        }

        response = client.post("/evidence/hash", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "content_hash" in data
        assert len(data["content_hash"]) == 64  # SHA256 hex length

    def test_hash_deterministic(self):
        """Test that hash is deterministic"""
        payload = {
            "evidence_id": "TEST001",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        }

        response1 = client.post("/evidence/hash", json=payload)
        response2 = client.post("/evidence/hash", json=payload)

        hash1 = response1.json()["content_hash"]
        hash2 = response2.json()["content_hash"]
        assert hash1 == hash2

    def test_hash_changes_with_data(self):
        """Test that hash changes when data changes"""
        payload1 = {
            "evidence_id": "TEST001",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        }

        payload2 = {
            "evidence_id": "TEST002",  # Different ID
            "version": "1.0.0",
            "studies": [],
            "observations": []
        }

        response1 = client.post("/evidence/hash", json=payload1)
        response2 = client.post("/evidence/hash", json=payload2)

        hash1 = response1.json()["content_hash"]
        hash2 = response2.json()["content_hash"]
        assert hash1 != hash2

    def test_validate_evidence_object(self):
        """Test evidence object validation"""
        payload = {
            "evidence_id": "TEST001",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        }

        response = client.post("/evidence/validate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["valid"] == True
        assert "evidence_id" in data
        assert "content_hash" in data

    def test_validate_invalid_evidence_object(self):
        """Test validation of invalid evidence object"""
        payload = {
            # Missing required fields
            "version": "1.0.0"
        }

        response = client.post("/evidence/validate", json=payload)
        assert response.status_code == 400


class TestPSAParameters:
    """Tests for /econ/params endpoint"""

    def test_generate_psa_defaults(self):
        """Test PSA parameter generation with defaults"""
        payload = {
            "n_iterations": 100,
            "hr_progression": 0.7,
            "hr_death": 0.8
        }

        response = client.post("/econ/params", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["n_iterations"] == 100
        assert "parameters" in data
        assert "hr_progression" in data["parameters"]
        assert len(data["parameters"]["hr_progression"]) == 100

    def test_psa_deterministic_seed(self):
        """Test that same seed produces same results"""
        payload = {
            "n_iterations": 50,
            "hr_progression": 0.7,
            "seed": 12345
        }

        response1 = client.post("/econ/params", json=payload)
        response2 = client.post("/econ/params", json=payload)

        params1 = response1.json()["parameters"]["hr_progression"]
        params2 = response2.json()["parameters"]["hr_progression"]

        assert params1 == params2

    def test_psa_distributions_valid(self):
        """Test that PSA distributions are valid"""
        payload = {
            "n_iterations": 100,
            "hr_progression": 0.7,
            "cost_treatment": 10000
        }

        response = client.post("/econ/params", json=payload)
        data = response.json()

        # Check HR values are positive
        hr_values = data["parameters"]["hr_progression"]
        assert all(v > 0 for v in hr_values)

        # Check utilities are between 0 and 1
        utility_values = data["parameters"]["utility_stable"]
        assert all(0 <= v <= 1 for v in utility_values)

        # Check costs are positive
        cost_values = data["parameters"]["cost_treatment"]
        assert all(v >= 0 for v in cost_values)


class TestConversionEndpoints:
    """Tests for conversion utilities"""

    def test_convert_or_to_rr(self):
        """Test OR to RR conversion"""
        payload = {
            "or": 2.0,
            "control_event_rate": 0.2
        }

        response = client.post("/convert/or_to_rr", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "rr" in data
        assert data["or"] == 2.0
        # RR should be less than OR when CER < 0.5
        assert data["rr"] < data["or"]

    def test_convert_missing_parameters(self):
        """Test conversion with missing parameters"""
        payload = {
            "or": 2.0
            # Missing control_event_rate
        }

        response = client.post("/convert/or_to_rr", json=payload)
        assert response.status_code == 400


class TestLeagueTableFormatting:
    """Tests for /format/league_table endpoint"""

    def test_format_league_table(self):
        """Test league table formatting"""
        payload = {
            "treatments": ["A", "B", "C"],
            "effects": {
                "A_vs_B": {"est": 1.2, "ci_lower": 0.9, "ci_upper": 1.6},
                "A_vs_C": {"est": 1.5, "ci_lower": 1.1, "ci_upper": 2.0},
                "B_vs_C": {"est": 1.25, "ci_lower": 0.95, "ci_upper": 1.65}
            }
        }

        response = client.post("/format/league_table", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "league_table" in data
        assert "treatments" in data
        # Check symmetric structure
        assert "A" in data["league_table"]
        assert "B" in data["league_table"]["A"]

    def test_league_table_diagonal(self):
        """Test league table has dashes on diagonal"""
        payload = {
            "treatments": ["A", "B"],
            "effects": {
                "A_vs_B": {"est": 1.2, "ci_lower": 0.9, "ci_upper": 1.6}
            }
        }

        response = client.post("/format/league_table", json=payload)
        data = response.json()
        # Diagonal should be "-"
        assert data["league_table"]["A"]["A"] == "-"
        assert data["league_table"]["B"]["B"] == "-"


class TestBayesianEndpoint:
    """Tests for Bayesian meta-analysis endpoint"""

    def test_bayesian_not_implemented(self):
        """Test that Bayesian endpoint returns not implemented message"""
        payload = {
            "data": [],
            "method": "bayesian"
        }

        response = client.post("/meta/bayes", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "pending"
        assert "not yet implemented" in data["message"].lower()


class TestErrorHandling:
    """Tests for error handling"""

    def test_invalid_json(self):
        """Test handling of invalid JSON"""
        response = client.post(
            "/validate",
            data="invalid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422  # Unprocessable Entity

    def test_missing_endpoint(self):
        """Test 404 for missing endpoint"""
        response = client.get("/nonexistent")
        assert response.status_code == 404

    def test_method_not_allowed(self):
        """Test GET on POST-only endpoint"""
        response = client.get("/validate")
        assert response.status_code == 405


class TestCORSHeaders:
    """Tests for CORS configuration"""

    def test_cors_headers_present(self):
        """Test that CORS headers are present"""
        response = client.options("/", headers={"Origin": "http://localhost:3838"})
        # CORS should allow the request
        assert response.status_code in [200, 204]


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short', '--cov=api.main'])
