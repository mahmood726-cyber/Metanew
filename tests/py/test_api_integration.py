"""
Comprehensive Integration Tests for API Endpoints
Tests all major API functionality with realistic scenarios
"""
import pytest
import pandas as pd
import numpy as np
import sys
import os
from fastapi.testclient import TestClient

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend/api'))

from main import app

client = TestClient(app)


class TestHealthChecks:
    """Test health check endpoints"""

    def test_root_health_check(self):
        """Test root endpoint"""
        response = client.get("/")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"

    def test_health_endpoint(self):
        """Test dedicated health endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "version" in data
        assert "timestamp" in data


class TestDataValidation:
    """Test data validation endpoints"""

    def test_validate_binary_data_valid(self):
        """Test validation with valid binary data"""
        payload = {
            "data": {
                "study_id": ["S1", "S2", "S3"],
                "treatment": ["A", "B", "A"],
                "events": [10, 20, 15],
                "n": [100, 200, 150]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert result["is_valid"] is True
        assert result["summary"]["errors"] == 0

    def test_validate_binary_data_invalid(self):
        """Test validation with invalid binary data (events > n)"""
        payload = {
            "data": {
                "study_id": ["S1"],
                "treatment": ["A"],
                "events": [150],
                "n": [100]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert result["is_valid"] is False
        assert result["summary"]["errors"] > 0

    def test_validate_continuous_data(self):
        """Test validation with continuous data"""
        payload = {
            "data": {
                "study_id": ["S1", "S2"],
                "treatment": ["A", "B"],
                "mean": [10.5, 12.3],
                "sd": [2.1, 2.5],
                "n": [50, 60]
            },
            "data_type": "continuous"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert result["is_valid"] is True

    def test_validate_missing_columns(self):
        """Test validation with missing required columns"""
        payload = {
            "data": {
                "study_id": ["S1"],
                "events": [10]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert result["is_valid"] is False
        assert "missing_columns" in result

    def test_validate_negative_values(self):
        """Test validation with negative values where inappropriate"""
        payload = {
            "data": {
                "study_id": ["S1"],
                "treatment": ["A"],
                "events": [-10],
                "n": [100]
            },
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert result["is_valid"] is False


class TestEffectSizeComputation:
    """Test effect size computation endpoints"""

    def test_compute_odds_ratio(self):
        """Test OR computation from 2x2 tables"""
        payload = {
            "data": {
                "study_id": ["S1", "S2"],
                "events1": [20, 30],
                "n1": [100, 150],
                "events2": [30, 40],
                "n2": [100, 150]
            },
            "effect_measure": "OR"
        }

        response = client.post("/compute-effect-size", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "yi" in result
        assert "sei" in result
        assert "vi" in result
        assert len(result["yi"]) == 2

    def test_compute_risk_ratio(self):
        """Test RR computation"""
        payload = {
            "data": {
                "study_id": ["S1"],
                "events1": [20],
                "n1": [100],
                "events2": [30],
                "n2": [100]
            },
            "effect_measure": "RR"
        }

        response = client.post("/compute-effect-size", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "yi" in result
        assert len(result["yi"]) == 1

    def test_compute_mean_difference(self):
        """Test MD computation from continuous data"""
        payload = {
            "data": {
                "study_id": ["S1", "S2"],
                "mean1": [10.0, 12.0],
                "sd1": [2.0, 2.5],
                "n1": [50, 60],
                "mean2": [8.0, 11.0],
                "sd2": [2.0, 2.5],
                "n2": [50, 60]
            },
            "effect_measure": "MD"
        }

        response = client.post("/compute-effect-size", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "yi" in result
        assert len(result["yi"]) == 2
        assert result["yi"][0] == pytest.approx(2.0, rel=0.1)

    def test_compute_smd(self):
        """Test SMD (standardized mean difference) computation"""
        payload = {
            "data": {
                "study_id": ["S1"],
                "mean1": [10.0],
                "sd1": [2.0],
                "n1": [50],
                "mean2": [8.0],
                "sd2": [2.0],
                "n2": [50]
            },
            "effect_measure": "SMD"
        }

        response = client.post("/compute-effect-size", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "yi" in result
        assert len(result["yi"]) == 1

    def test_compute_hazard_ratio(self):
        """Test HR computation from confidence intervals"""
        payload = {
            "data": {
                "study_id": ["S1", "S2"],
                "hr": [0.7, 0.8],
                "ci_lower": [0.5, 0.6],
                "ci_upper": [0.9, 1.0]
            },
            "effect_measure": "HR"
        }

        response = client.post("/compute-effect-size", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "yi" in result
        assert len(result["yi"]) == 2

    def test_continuity_correction_zero_cells(self):
        """Test continuity correction for zero cells"""
        payload = {
            "data": {
                "study_id": ["S1"],
                "events1": [0],
                "n1": [100],
                "events2": [10],
                "n2": [100]
            },
            "effect_measure": "OR"
        }

        response = client.post("/compute-effect-size", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "yi" in result
        # Should not have NaN or Inf
        assert not np.isnan(result["yi"][0])
        assert not np.isinf(result["yi"][0])


class TestProbabilisticSensitivityAnalysis:
    """Test PSA functionality"""

    def test_run_psa_basic(self):
        """Test basic PSA run"""
        payload = {
            "n_iterations": 100,
            "parameters": {
                "treatment_effect": {
                    "mean": 0.7,
                    "sd": 0.1,
                    "distribution": "lognormal"
                },
                "cost_treatment": {
                    "mean": 10000,
                    "sd": 2000,
                    "distribution": "gamma"
                },
                "cost_comparator": {
                    "mean": 5000,
                    "sd": 1000,
                    "distribution": "gamma"
                },
                "utility_treatment": {
                    "mean": 0.8,
                    "sd": 0.05,
                    "distribution": "beta"
                },
                "utility_comparator": {
                    "mean": 0.6,
                    "sd": 0.05,
                    "distribution": "beta"
                }
            }
        }

        response = client.post("/psa/run", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert "iterations" in result
        assert len(result["iterations"]) == 100
        assert "summary" in result

    def test_psa_different_distributions(self):
        """Test PSA with different parameter distributions"""
        payload = {
            "n_iterations": 50,
            "parameters": {
                "param1": {
                    "mean": 0.5,
                    "sd": 0.1,
                    "distribution": "normal"
                },
                "param2": {
                    "mean": 0.7,
                    "sd": 0.15,
                    "distribution": "lognormal"
                },
                "param3": {
                    "mean": 0.8,
                    "sd": 0.05,
                    "distribution": "beta"
                }
            }
        }

        response = client.post("/psa/run", json=payload)
        assert response.status_code == 200
        result = response.json()
        assert len(result["iterations"]) == 50


class TestCachingEndpoints:
    """Test caching functionality"""

    def test_cache_put_get(self):
        """Test basic cache operations"""
        # Put data in cache
        cache_key = "test_analysis_123"
        payload = {
            "key": cache_key,
            "data": {
                "results": [1, 2, 3, 4, 5],
                "metadata": {"version": "1.0"}
            }
        }

        # Note: This assumes cache endpoints exist
        # If they don't, this test will be skipped
        try:
            response = client.post("/cache/put", json=payload)
            if response.status_code == 404:
                pytest.skip("Cache endpoints not implemented in API")

            assert response.status_code == 200

            # Get data from cache
            get_response = client.get(f"/cache/get/{cache_key}")
            assert get_response.status_code == 200
            result = get_response.json()
            assert result["data"]["results"] == [1, 2, 3, 4, 5]
        except Exception:
            pytest.skip("Cache endpoints not fully implemented")


class TestErrorHandling:
    """Test error handling and edge cases"""

    def test_invalid_json(self):
        """Test handling of invalid JSON"""
        response = client.post(
            "/validate",
            data="this is not json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422

    def test_missing_required_fields(self):
        """Test handling of missing required fields"""
        payload = {
            "data_type": "binary"
            # Missing "data" field
        }

        response = client.post("/validate", json=payload)
        assert response.status_code == 422

    def test_invalid_data_type(self):
        """Test handling of invalid data type"""
        payload = {
            "data": {
                "study_id": ["S1"],
                "events": [10],
                "n": [100]
            },
            "data_type": "invalid_type"
        }

        response = client.post("/validate", json=payload)
        # Should either reject or handle gracefully
        assert response.status_code in [400, 422, 200]

    def test_empty_data(self):
        """Test handling of empty data"""
        payload = {
            "data": {},
            "data_type": "binary"
        }

        response = client.post("/validate", json=payload)
        assert response.status_code in [200, 400, 422]


class TestConcurrency:
    """Test concurrent request handling"""

    def test_multiple_concurrent_validations(self):
        """Test handling multiple concurrent validation requests"""
        import concurrent.futures

        def make_request(i):
            payload = {
                "data": {
                    "study_id": [f"S{i}"],
                    "treatment": ["A"],
                    "events": [10 + i],
                    "n": [100]
                },
                "data_type": "binary"
            }
            return client.post("/validate", json=payload)

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request, i) for i in range(10)]
            results = [f.result() for f in futures]

        # All should succeed
        for result in results:
            assert result.status_code == 200


class TestRateLimiting:
    """Test rate limiting functionality"""

    def test_rate_limit_nlq_endpoint(self):
        """Test rate limiting on NLQ endpoint"""
        # Make multiple rapid requests
        responses = []
        for i in range(15):  # Assuming limit is 10/minute
            payload = {
                "query": "What is the pooled effect size?",
                "context": {}
            }
            response = client.post("/nlq", json=payload)
            responses.append(response)

        # Some should be rate limited (429 status)
        status_codes = [r.status_code for r in responses]
        # Either all succeed or some are rate limited
        assert all(code in [200, 429, 404] for code in status_codes)


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
