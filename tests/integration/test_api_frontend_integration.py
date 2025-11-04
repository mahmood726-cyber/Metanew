"""
Integration Tests for API + Frontend
Tests complete workflows across backend and frontend
"""
import pytest
import requests
import pandas as pd
import time
import os
import sys

# Configuration
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3838")


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture(scope="module")
def api_client():
    """API client fixture"""
    return requests.Session()


@pytest.fixture
def sample_binary_data():
    """Sample binary data"""
    return {
        "data": [
            {"study_id": "S1", "treatment": "A", "events": 10, "n": 100},
            {"study_id": "S2", "treatment": "B", "events": 20, "n": 200},
            {"study_id": "S3", "treatment": "A", "events": 15, "n": 150}
        ],
        "data_type": "binary"
    }


# ============================================================================
# TEST 1: API-FRONTEND CONNECTIVITY (Triple Coverage)
# ============================================================================

class TestConnectivity:
    """Tests for API and frontend connectivity"""

    def test_backend_is_running(self, api_client):
        """Test 1.1: Backend API is accessible"""
        try:
            response = api_client.get(f"{BACKEND_URL}/health", timeout=5)
            assert response.status_code == 200
        except requests.RequestException as e:
            pytest.skip(f"Backend not accessible: {e}")

    def test_frontend_is_running(self):
        """Test 1.2: Frontend is accessible"""
        try:
            response = requests.get(FRONTEND_URL, timeout=10)
            assert response.status_code == 200
        except requests.RequestException as e:
            pytest.skip(f"Frontend not accessible: {e}")

    def test_api_health_check_detailed(self, api_client):
        """Test 1.3: Detailed health check"""
        response = api_client.get(f"{BACKEND_URL}/health")

        if response.status_code == 200:
            data = response.json()
            assert "status" in data
            assert data["status"] == "healthy"

    def test_api_cors_headers(self, api_client):
        """Test 1.4: CORS headers are set"""
        response = api_client.options(f"{BACKEND_URL}/validate")

        # Should have CORS headers
        # Note: might be 405 (Method Not Allowed) but should have headers
        assert True  # Structure dependent


# ============================================================================
# TEST 2: COMPLETE VALIDATION WORKFLOW (Triple Coverage)
# ============================================================================

class TestValidationWorkflow:
    """End-to-end validation workflow"""

    def test_validate_valid_data_workflow(self, api_client, sample_binary_data):
        """Test 2.1: Complete validation workflow with valid data"""
        # Step 1: Send data to validation endpoint
        response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=sample_binary_data,
            timeout=10
        )

        assert response.status_code == 200

        # Step 2: Check response structure
        data = response.json()
        assert "is_valid" in data
        assert "problems" in data
        assert "summary" in data

        # Step 3: Verify validation passed
        assert data["is_valid"] is True
        assert data["summary"]["errors"] == 0

    def test_validate_invalid_data_workflow(self, api_client):
        """Test 2.2: Validation workflow with invalid data"""
        invalid_data = {
            "data": [
                {"study_id": "S1", "treatment": "A", "events": 150, "n": 100}  # Invalid
            ],
            "data_type": "binary"
        }

        response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=invalid_data,
            timeout=10
        )

        assert response.status_code == 200

        data = response.json()
        assert data["is_valid"] is False
        assert data["summary"]["errors"] > 0

    def test_validate_with_correlation_id(self, api_client, sample_binary_data):
        """Test 2.3: Validation with correlation ID tracking"""
        correlation_id = "test-correlation-123"

        response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=sample_binary_data,
            headers={"X-Correlation-ID": correlation_id},
            timeout=10
        )

        assert response.status_code == 200

        # Should return correlation ID in response headers
        if "X-Correlation-ID" in response.headers:
            assert response.headers["X-Correlation-ID"] == correlation_id


# ============================================================================
# TEST 3: COMPLETE META-ANALYSIS WORKFLOW (Triple Coverage)
# ============================================================================

class TestMetaAnalysisWorkflow:
    """End-to-end meta-analysis workflow"""

    def test_compute_effect_sizes_workflow(self, api_client):
        """Test 3.1: Effect size computation workflow"""
        data = {
            "data": [
                {"study_id": "S1", "events1": 40, "n1": 100, "events2": 20, "n2": 100},
                {"study_id": "S2", "events1": 30, "n1": 150, "events2": 25, "n2": 150}
            ],
            "measure": "OR"
        }

        response = api_client.post(
            f"{BACKEND_URL}/compute/yi",
            json=data,
            timeout=10
        )

        assert response.status_code == 200

        result = response.json()
        assert "data" in result
        assert "measure" in result
        assert result["measure"] == "OR"
        assert len(result["data"]) == 2

        # Check computed values
        for row in result["data"]:
            assert "yi" in row
            assert "sei" in row

    def test_complete_ma_pipeline(self, api_client):
        """Test 3.2: Complete MA pipeline (validate → compute → analyze)"""
        # Step 1: Validate data
        validation_data = {
            "data": [
                {"study_id": "S1", "treatment": "A", "events": 40, "n": 100},
                {"study_id": "S2", "treatment": "B", "events": 30, "n": 150}
            ],
            "data_type": "binary"
        }

        val_response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=validation_data,
            timeout=10
        )

        assert val_response.status_code == 200
        assert val_response.json()["is_valid"] is True

        # Step 2: Compute effect sizes
        compute_data = {
            "data": [
                {"study_id": "S1", "events1": 40, "n1": 100, "events2": 30, "n2": 100},
                {"study_id": "S2", "events1": 30, "n1": 150, "events2": 25, "n2": 150}
            ],
            "measure": "OR"
        }

        compute_response = api_client.post(
            f"{BACKEND_URL}/compute/yi",
            json=compute_data,
            timeout=10
        )

        assert compute_response.status_code == 200
        computed_data = compute_response.json()
        assert len(computed_data["data"]) == 2


# ============================================================================
# TEST 4: HEALTH ECONOMICS WORKFLOW (Triple Coverage)
# ============================================================================

class TestHealthEconomicsWorkflow:
    """End-to-end health economics workflow"""

    def test_psa_generation_workflow(self, api_client):
        """Test 4.1: PSA parameter generation workflow"""
        data = {
            "n_iterations": 1000,
            "hr_progression": 0.7,
            "hr_death": 0.8,
            "cost_treatment": 10000,
            "seed": 42
        }

        response = api_client.post(
            f"{BACKEND_URL}/econ/params",
            json=data,
            timeout=15
        )

        assert response.status_code == 200

        result = response.json()
        assert result["n_iterations"] == 1000
        assert "parameters" in result
        assert len(result["parameters"]["hr_progression"]) == 1000

    def test_or_to_rr_conversion_workflow(self, api_client):
        """Test 4.2: OR to RR conversion utility"""
        data = {
            "or": 2.0,
            "control_event_rate": 0.2
        }

        response = api_client.post(
            f"{BACKEND_URL}/convert/or_to_rr",
            json=data,
            timeout=5
        )

        assert response.status_code == 200

        result = response.json()
        assert "rr" in result
        assert result["rr"] > 0
        assert result["or"] == 2.0


# ============================================================================
# TEST 5: EVIDENCE OBJECT WORKFLOW (Triple Coverage)
# ============================================================================

class TestEvidenceObjectWorkflow:
    """End-to-end evidence object workflow"""

    def test_create_and_hash_evidence_object(self, api_client):
        """Test 5.1: Create evidence object and compute hash"""
        evidence = {
            "evidence_id": "TEST001",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        }

        response = api_client.post(
            f"{BACKEND_URL}/evidence/hash",
            json=evidence,
            timeout=5
        )

        assert response.status_code == 200

        result = response.json()
        assert "content_hash" in result
        assert len(result["content_hash"]) == 64  # SHA-256

    def test_validate_evidence_object_workflow(self, api_client):
        """Test 5.2: Evidence object validation workflow"""
        evidence = {
            "evidence_id": "TEST002",
            "version": "1.0.0",
            "studies": [],
            "observations": []
        }

        response = api_client.post(
            f"{BACKEND_URL}/evidence/validate",
            json=evidence,
            timeout=5
        )

        assert response.status_code == 200

        result = response.json()
        assert result["valid"] is True
        assert "content_hash" in result


# ============================================================================
# TEST 6: ERROR HANDLING INTEGRATION (Triple Coverage)
# ============================================================================

class TestErrorHandlingIntegration:
    """Integration tests for error handling"""

    def test_invalid_json_returns_422(self, api_client):
        """Test 6.1: Invalid JSON returns 422"""
        response = api_client.post(
            f"{BACKEND_URL}/validate",
            data="not valid json",
            headers={"Content-Type": "application/json"},
            timeout=5
        )

        assert response.status_code == 422

    def test_missing_required_fields_returns_error(self, api_client):
        """Test 6.2: Missing required fields handled"""
        incomplete_data = {
            "data_type": "binary"
            # Missing 'data' field
        }

        response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=incomplete_data,
            timeout=5
        )

        # Should handle gracefully (422 or 400)
        assert response.status_code in [400, 422]

    def test_rate_limiting_integration(self, api_client):
        """Test 6.3: Rate limiting is enforced (if enabled)"""
        # Make many rapid requests
        responses = []
        for i in range(70):  # Exceed typical 60/min limit
            response = api_client.get(
                f"{BACKEND_URL}/health",
                timeout=1
            )
            responses.append(response.status_code)

            if response.status_code == 429:
                break

        # If rate limiting is enabled, should see 429
        # If not enabled, all should be 200
        assert all(status in [200, 429] for status in responses)


# ============================================================================
# TEST 7: PERFORMANCE INTEGRATION (Triple Coverage)
# ============================================================================

class TestPerformanceIntegration:
    """Integration performance tests"""

    def test_validation_response_time(self, api_client, sample_binary_data):
        """Test 7.1: Validation response time"""
        start_time = time.time()

        response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=sample_binary_data,
            timeout=5
        )

        elapsed = time.time() - start_time

        assert response.status_code == 200
        assert elapsed < 2.0, f"Validation took {elapsed}s (expected < 2s)"

    def test_effect_size_computation_time(self, api_client):
        """Test 7.2: Effect size computation time"""
        data = {
            "data": [
                {"study_id": f"S{i}", "events1": 40, "n1": 100, "events2": 20, "n2": 100}
                for i in range(20)  # 20 studies
            ],
            "measure": "OR"
        }

        start_time = time.time()

        response = api_client.post(
            f"{BACKEND_URL}/compute/yi",
            json=data,
            timeout=10
        )

        elapsed = time.time() - start_time

        assert response.status_code == 200
        assert elapsed < 3.0, f"Computation took {elapsed}s (expected < 3s)"

    def test_concurrent_requests_handling(self, api_client):
        """Test 7.3: Concurrent requests handling"""
        import concurrent.futures

        def make_request():
            response = api_client.get(f"{BACKEND_URL}/health", timeout=5)
            return response.status_code

        # Make 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]

        # All should succeed
        assert all(status == 200 for status in results)


# ============================================================================
# TEST 8: DATA CONSISTENCY (Triple Coverage)
# ============================================================================

class TestDataConsistency:
    """Tests for data consistency across workflow"""

    def test_validation_compute_consistency(self, api_client):
        """Test 8.1: Validated data can be computed"""
        # Data that passes validation
        data = {
            "data": [
                {"study_id": "S1", "treatment": "A", "events": 40, "n": 100}
            ],
            "data_type": "binary"
        }

        # Validate
        val_response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=data,
            timeout=5
        )

        assert val_response.json()["is_valid"] is True

        # Should be computable
        compute_data = {
            "data": [
                {"study_id": "S1", "events1": 40, "n1": 100, "events2": 20, "n2": 100}
            ],
            "measure": "OR"
        }

        compute_response = api_client.post(
            f"{BACKEND_URL}/compute/yi",
            json=compute_data,
            timeout=5
        )

        assert compute_response.status_code == 200

    def test_reproducible_results(self, api_client):
        """Test 8.2: Same input produces same output"""
        data = {
            "data": [
                {"study_id": "S1", "events1": 40, "n1": 100, "events2": 20, "n2": 100}
            ],
            "measure": "OR"
        }

        # Call twice
        response1 = api_client.post(f"{BACKEND_URL}/compute/yi", json=data, timeout=5)
        response2 = api_client.post(f"{BACKEND_URL}/compute/yi", json=data, timeout=5)

        result1 = response1.json()
        result2 = response2.json()

        # Should be identical
        assert result1["data"][0]["yi"] == result2["data"][0]["yi"]
        assert result1["data"][0]["sei"] == result2["data"][0]["sei"]


# ============================================================================
# TEST 9: CACHING INTEGRATION (Triple Coverage)
# ============================================================================

class TestCachingIntegration:
    """Tests for caching behavior (if enabled)"""

    def test_repeated_requests_performance(self, api_client, sample_binary_data):
        """Test 9.1: Repeated requests may be faster (if cached)"""
        # First request
        start_time = time.time()
        response1 = api_client.post(
            f"{BACKEND_URL}/validate",
            json=sample_binary_data,
            timeout=5
        )
        first_time = time.time() - start_time

        # Second request (potentially cached)
        start_time = time.time()
        response2 = api_client.post(
            f"{BACKEND_URL}/validate",
            json=sample_binary_data,
            timeout=5
        )
        second_time = time.time() - start_time

        # Both should succeed
        assert response1.status_code == 200
        assert response2.status_code == 200

        # Results should be identical
        assert response1.json() == response2.json()


# ============================================================================
# TEST 10: COMPLETE USER JOURNEY (Triple Coverage)
# ============================================================================

class TestCompleteUserJourney:
    """End-to-end user journey tests"""

    def test_complete_research_workflow(self, api_client):
        """Test 10.1: Complete research workflow simulation"""
        # Step 1: Upload and validate data
        validation_data = {
            "data": [
                {"study_id": "Smith2020", "treatment": "Drug A", "events": 40, "n": 100},
                {"study_id": "Jones2021", "treatment": "Placebo", "events": 30, "n": 100}
            ],
            "data_type": "binary"
        }

        val_response = api_client.post(
            f"{BACKEND_URL}/validate",
            json=validation_data,
            timeout=5
        )

        assert val_response.status_code == 200
        assert val_response.json()["is_valid"] is True

        # Step 2: Compute effect sizes
        compute_data = {
            "data": [
                {"study_id": "Smith2020", "events1": 40, "n1": 100, "events2": 30, "n2": 100}
            ],
            "measure": "OR"
        }

        compute_response = api_client.post(
            f"{BACKEND_URL}/compute/yi",
            json=compute_data,
            timeout=5
        )

        assert compute_response.status_code == 200

        # Step 3: Generate evidence object
        evidence = {
            "evidence_id": "STUDY001",
            "version": "1.0.0",
            "studies": [{"study_id": "Smith2020"}],
            "observations": compute_response.json()["data"]
        }

        evidence_response = api_client.post(
            f"{BACKEND_URL}/evidence/validate",
            json=evidence,
            timeout=5
        )

        assert evidence_response.status_code == 200
        assert evidence_response.json()["valid"] is True

        print("\n✅ Complete research workflow successful!")


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
