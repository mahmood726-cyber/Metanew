"""
Integration tests for EvidenceOS PRIME API
Tests full API workflows and service interactions
"""
import pytest
import requests
import pandas as pd
import time
from typing import Dict, Any


# Test configuration
API_BASE_URL = "http://localhost:8000"
AI_API_BASE_URL = "http://localhost:8001"
TEST_TIMEOUT = 10


@pytest.fixture(scope="module")
def api_client():
    """Wait for API to be ready and return base URL"""
    max_retries = 30
    for i in range(max_retries):
        try:
            response = requests.get(f"{API_BASE_URL}/health", timeout=2)
            if response.status_code == 200:
                break
        except requests.ConnectionError:
            if i == max_retries - 1:
                pytest.skip("API not available")
            time.sleep(1)
    return API_BASE_URL


@pytest.fixture(scope="module")
def ai_api_client():
    """Wait for AI API to be ready and return base URL"""
    max_retries = 30
    for i in range(max_retries):
        try:
            response = requests.get(f"{AI_API_BASE_URL}/health", timeout=2)
            if response.status_code == 200:
                break
        except requests.ConnectionError:
            if i == max_retries - 1:
                pytest.skip("AI API not available")
            time.sleep(1)
    return AI_API_BASE_URL


@pytest.fixture
def sample_binary_data():
    """Sample binary outcome data for testing"""
    return {
        "data": [
            {"study_id": "Study1", "treatment": "A", "events": 10, "n": 100},
            {"study_id": "Study1", "treatment": "B", "events": 20, "n": 100},
            {"study_id": "Study2", "treatment": "A", "events": 15, "n": 120},
            {"study_id": "Study2", "treatment": "B", "events": 25, "n": 120},
            {"study_id": "Study3", "treatment": "A", "events": 8, "n": 80},
            {"study_id": "Study3", "treatment": "B", "events": 18, "n": 80},
        ],
        "data_type": "binary"
    }


@pytest.fixture
def sample_continuous_data():
    """Sample continuous outcome data for testing"""
    return {
        "data": [
            {"study_id": "Study1", "treatment": "A", "mean": 5.2, "sd": 1.1, "n": 50},
            {"study_id": "Study1", "treatment": "B", "mean": 6.1, "sd": 1.2, "n": 50},
            {"study_id": "Study2", "treatment": "A", "mean": 4.8, "sd": 1.0, "n": 60},
            {"study_id": "Study2", "treatment": "B", "mean": 5.9, "sd": 1.3, "n": 60},
        ],
        "data_type": "continuous"
    }


# ============================================================================
# HEALTH CHECK TESTS
# ============================================================================

def test_main_api_health_check(api_client):
    """Test main API health endpoint"""
    response = requests.get(f"{api_client}/health", timeout=TEST_TIMEOUT)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "python_version" in data
    assert "timestamp" in data


def test_ai_api_health_check(ai_api_client):
    """Test AI API health endpoint"""
    response = requests.get(f"{ai_api_client}/health", timeout=TEST_TIMEOUT)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data


def test_main_api_root(api_client):
    """Test main API root endpoint"""
    response = requests.get(f"{api_client}/", timeout=TEST_TIMEOUT)
    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "EvidenceOS PRIME API"
    assert data["status"] == "operational"


# ============================================================================
# DATA VALIDATION TESTS
# ============================================================================

def test_validate_binary_data_success(api_client, sample_binary_data):
    """Test successful validation of binary data"""
    response = requests.post(
        f"{api_client}/validate",
        json=sample_binary_data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["is_valid"] is True
    assert data["summary"]["errors"] == 0


def test_validate_binary_data_with_errors(api_client):
    """Test validation catches errors"""
    bad_data = {
        "data": [
            {"study_id": "Study1", "treatment": "A", "events": 150, "n": 100},  # events > n
        ],
        "data_type": "binary"
    }
    response = requests.post(
        f"{api_client}/validate",
        json=bad_data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["is_valid"] is False
    assert data["summary"]["errors"] > 0


def test_validate_missing_required_columns(api_client):
    """Test validation detects missing required columns"""
    incomplete_data = {
        "data": [
            {"events": 10, "n": 100},  # Missing study_id and treatment
        ],
        "data_type": "binary"
    }
    response = requests.post(
        f"{api_client}/validate",
        json=incomplete_data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["is_valid"] is False
    assert any("missing" in str(p).lower() for p in data["problems"])


def test_validate_empty_data(api_client):
    """Test validation handles empty data"""
    empty_data = {
        "data": [],
        "data_type": "binary"
    }
    response = requests.post(
        f"{api_client}/validate",
        json=empty_data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["is_valid"] is False


# ============================================================================
# EFFECT SIZE COMPUTATION TESTS
# ============================================================================

def test_compute_effect_sizes_binary_or(api_client):
    """Test effect size computation for binary data (OR)"""
    data = {
        "data": [
            {
                "study_id": "Study1",
                "events1": 10, "n1": 100,
                "events2": 20, "n2": 100
            },
            {
                "study_id": "Study2",
                "events1": 15, "n1": 120,
                "events2": 25, "n2": 120
            },
        ],
        "measure": "OR"
    }
    response = requests.post(
        f"{api_client}/compute/yi",
        json=data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    result = response.json()
    assert result["measure"] == "OR"
    assert result["n_observations"] == 2
    assert "data" in result
    # Check that yi and sei were computed
    assert "yi" in result["data"][0]
    assert "sei" in result["data"][0]


def test_compute_effect_sizes_continuous_md(api_client, sample_continuous_data):
    """Test effect size computation for continuous data (MD)"""
    # Transform data to contrast format
    data = {
        "data": [
            {
                "study_id": "Study1",
                "mean1": 5.2, "sd1": 1.1, "n1": 50,
                "mean2": 6.1, "sd2": 1.2, "n2": 50
            },
        ],
        "measure": "MD"
    }
    response = requests.post(
        f"{api_client}/compute/yi",
        json=data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    result = response.json()
    assert result["measure"] == "MD"
    assert "yi" in result["data"][0]


def test_compute_effect_sizes_invalid_measure(api_client):
    """Test effect size computation with invalid measure"""
    data = {
        "data": [{"study_id": "Study1"}],
        "measure": "INVALID"
    }
    response = requests.post(
        f"{api_client}/compute/yi",
        json=data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 400


# ============================================================================
# EVIDENCE OBJECT TESTS
# ============================================================================

def test_compute_evidence_hash(api_client):
    """Test evidence object hash computation"""
    evidence = {
        "evidence_id": "TEST_001",
        "version": "1.0.0",
        "studies": [],
        "observations": []
    }
    response = requests.post(
        f"{api_client}/evidence/hash",
        json=evidence,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert "content_hash" in data
    assert len(data["content_hash"]) == 64  # SHA256 hash


def test_validate_evidence_object(api_client):
    """Test evidence object validation"""
    evidence = {
        "evidence_id": "TEST_002",
        "version": "1.0.0",
        "studies": [],
        "observations": []
    }
    response = requests.post(
        f"{api_client}/evidence/validate",
        json=evidence,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["valid"] is True
    assert data["n_studies"] == 0
    assert data["n_observations"] == 0


# ============================================================================
# HEALTH ECONOMICS TESTS
# ============================================================================

def test_generate_psa_parameters(api_client):
    """Test PSA parameter generation"""
    params = {
        "n_iterations": 100,
        "hr_progression": 0.7,
        "hr_death": 0.8,
        "cost_treatment": 15000,
        "seed": 42
    }
    response = requests.post(
        f"{api_client}/econ/params",
        json=params,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["n_iterations"] == 100
    assert "parameters" in data
    assert len(data["parameters"]["hr_progression"]) == 100
    assert len(data["parameters"]["cost_treatment"]) == 100


def test_convert_or_to_rr(api_client):
    """Test OR to RR conversion"""
    data = {
        "or": 2.0,
        "control_event_rate": 0.2
    }
    response = requests.post(
        f"{api_client}/convert/or_to_rr",
        json=data,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    result = response.json()
    assert "rr" in result
    assert result["or"] == 2.0
    assert result["rr"] < result["or"]  # RR should be less extreme than OR


# ============================================================================
# NOT IMPLEMENTED ENDPOINT TESTS
# ============================================================================

def test_bayesian_endpoint_returns_501(api_client):
    """Test that Bayesian endpoint properly returns 501 Not Implemented"""
    response = requests.post(
        f"{api_client}/meta/bayes",
        json={"data": []},
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 501
    data = response.json()
    assert "Not Implemented" in str(data)


# ============================================================================
# AI COPILOT TESTS
# ============================================================================

def test_nlq_endpoint_forest_plot(ai_api_client):
    """Test natural language query for forest plot"""
    query = {
        "query": "Show me the forest plot",
        "context": {"current_outcome": "mortality"}
    }
    response = requests.post(
        f"{ai_api_client}/nlq",
        json=query,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["action"] == "show_forest"
    assert data["confidence"] > 0


def test_nlq_endpoint_heterogeneity(ai_api_client):
    """Test natural language query for heterogeneity interpretation"""
    query = {
        "query": "Is there significant heterogeneity?",
        "context": {}
    }
    response = requests.post(
        f"{ai_api_client}/nlq",
        json=query,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert data["action"] == "interpret_heterogeneity"


def test_interpret_heterogeneity_endpoint(ai_api_client):
    """Test heterogeneity interpretation endpoint"""
    params = {
        "i2": 67.3,
        "tau2": 0.042,
        "q_stat": 33.5,
        "q_pval": 0.002,
        "n_studies": 12
    }
    response = requests.get(
        f"{ai_api_client}/interpret/heterogeneity",
        params=params,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert "interpretation" in data
    assert "suggestions" in data
    assert len(data["suggestions"]) > 0


def test_interpret_icer_endpoint(ai_api_client):
    """Test ICER interpretation endpoint"""
    params = {
        "icer": 25000,
        "ci_lower": 15000,
        "ci_upper": 35000,
        "wtp": 30000
    }
    response = requests.get(
        f"{ai_api_client}/interpret/icer",
        params=params,
        timeout=TEST_TIMEOUT
    )
    assert response.status_code == 200
    data = response.json()
    assert "interpretation" in data
    assert "confidence_interval" in data


# ============================================================================
# CORS SECURITY TESTS
# ============================================================================

def test_cors_headers_present(api_client):
    """Test that CORS headers are properly configured"""
    # Preflight request
    headers = {
        "Origin": "http://localhost:3838",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "Content-Type"
    }
    response = requests.options(
        f"{api_client}/validate",
        headers=headers,
        timeout=TEST_TIMEOUT
    )
    # Check CORS headers are present
    assert "access-control-allow-origin" in response.headers
    assert "access-control-allow-methods" in response.headers


# ============================================================================
# RATE LIMITING TESTS
# ============================================================================

@pytest.mark.slow
def test_rate_limiting_enforced(ai_api_client):
    """Test that rate limiting is enforced on AI endpoints"""
    # Make rapid requests to trigger rate limit
    query = {"query": "test query"}
    responses = []

    for i in range(15):  # Limit is 10/minute
        response = requests.post(
            f"{ai_api_client}/nlq",
            json=query,
            timeout=TEST_TIMEOUT
        )
        responses.append(response)
        if response.status_code == 429:
            break

    # Should get 429 Too Many Requests
    status_codes = [r.status_code for r in responses]
    assert 429 in status_codes, "Rate limiting not enforced"


# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

def test_malformed_json_returns_400(api_client):
    """Test that malformed JSON returns 400"""
    response = requests.post(
        f"{api_client}/validate",
        data="invalid json",
        headers={"Content-Type": "application/json"},
        timeout=TEST_TIMEOUT
    )
    assert response.status_code in [400, 422]


def test_missing_required_field_returns_422(api_client):
    """Test that missing required fields return 422"""
    response = requests.post(
        f"{api_client}/validate",
        json={},  # Missing required fields
        timeout=TEST_TIMEOUT
    )
    assert response.status_code in [400, 422]


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
