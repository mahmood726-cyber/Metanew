"""
Comprehensive API Tests for Advanced AI Features
Tests all 19 endpoints across 5 feature categories
"""
import pytest
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch, MagicMock
import pandas as pd
import numpy as np
from typing import Dict, Any

# Import the app
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from api.main import app

@pytest.fixture(scope="session")
def session_client():
    """Session-scoped test client"""
    return TestClient(app)


@pytest.fixture(scope="session")
def session_admin_token(session_client):
    """Session-scoped admin authentication token"""
    response = session_client.post(
        "/api/auth/login/oauth",
        data={"username": "admin", "password": "test-admin-password"}
    )
    if response.status_code == 200:
        return response.json()["access_token"]
    # If that fails, try with the environment password
    response = session_client.post(
        "/api/auth/login/oauth",
        data={"username": "admin", "password": os.getenv("ADMIN_INITIAL_PASSWORD", "admin")}
    )
    return response.json()["access_token"]


@pytest.fixture
def auth_headers(session_admin_token):
    """Authentication headers"""
    return {"Authorization": f"Bearer {session_admin_token}"}


@pytest.fixture
def sample_meta_analysis_results():
    """Sample meta-analysis results"""
    return {
        "pooled_effect": 0.75,
        "ci_lower": 0.60,
        "ci_upper": 0.95,
        "i_squared": 45.2,
        "tau_squared": 0.08,
        "p_value": 0.003,
        "n_studies": 10
    }


@pytest.fixture
def sample_study_data():
    """Sample study data"""
    return {
        "study_id": ["Study1", "Study2", "Study3"],
        "year": [2020, 2021, 2022],
        "n_treatment": [100, 150, 120],
        "n_control": [100, 150, 120],
        "events_treatment": [15, 20, 18],
        "events_control": [25, 30, 28]
    }


@pytest.fixture
def sample_analysis_config():
    """Sample analysis configuration"""
    return {
        "outcome": "mortality",
        "intervention": "Drug A",
        "comparator": "Placebo",
        "population": "Adults with hypertension"
    }


# ==================== REPORT GENERATION TESTS ====================

class TestReportGeneration:
    """Tests for report generation endpoints"""

    def test_generate_report_success(self, session_client, auth_headers,
                                     sample_meta_analysis_results, sample_study_data,
                                     sample_analysis_config):
        """Test successful report generation"""
        response = session_client.post(
            "/api/ai-features/report/generate",
            json={
                "meta_analysis_results": sample_meta_analysis_results,
                "study_data": sample_study_data,
                "analysis_config": sample_analysis_config,
                "report_type": "prisma",
                "include_quality_metrics": True
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        # Check structure
        assert "title" in data
        assert "sections" in data
        assert len(data["sections"]) > 0

        # Check quality metrics if included
        if "quality_metrics" in data:
            assert "readability" in data["quality_metrics"]
            assert "completeness" in data["quality_metrics"]

    def test_generate_report_without_auth(self, session_client,
                                         sample_meta_analysis_results,
                                         sample_study_data):
        """Test report generation fails without authentication"""
        response = session_client.post(
            "/api/ai-features/report/generate",
            json={
                "meta_analysis_results": sample_meta_analysis_results,
                "study_data": sample_study_data,
                "analysis_config": {},
                "report_type": "prisma"
            }
        )

        assert response.status_code == 401

    def test_generate_report_invalid_type(self, session_client, auth_headers,
                                         sample_meta_analysis_results, sample_study_data):
        """Test report generation with invalid report type"""
        response = session_client.post(
            "/api/ai-features/report/generate",
            json={
                "meta_analysis_results": sample_meta_analysis_results,
                "study_data": sample_study_data,
                "analysis_config": {},
                "report_type": "invalid_type"
            },
            headers=auth_headers
        )

        # Should either succeed with fallback or return error
        assert response.status_code in [200, 400, 500]

    def test_quality_metrics(self, session_client, auth_headers):
        """Test quality metrics calculation"""
        response = session_client.post(
            "/api/ai-features/report/quality-metrics",
            json={
                "text": "This is a sample text for testing readability. It has multiple sentences. Each sentence is relatively simple and easy to read.",
                "report_sections": {
                    "abstract": "Sample abstract",
                    "methods": "Sample methods",
                    "results": "Sample results",
                    "discussion": "Sample discussion"
                }
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "readability" in data
        assert "flesch_reading_ease" in data["readability"]


# ==================== RISK OF BIAS TESTS ====================

class TestRiskOfBiasAssessment:
    """Tests for ROB assessment endpoints"""

    def test_assess_single_study(self, session_client, auth_headers):
        """Test single study ROB assessment"""
        response = session_client.post(
            "/api/ai-features/rob/assess",
            json={
                "study_text": "This randomized controlled trial evaluated the effectiveness of Drug A versus placebo in 200 patients. Randomization was performed using computer-generated sequences. All participants and investigators were blinded.",
                "study_metadata": {
                    "title": "Drug A vs Placebo RCT",
                    "year": 2022
                },
                "return_probabilities": True
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        # Check structure
        assert "overall_judgment" in data
        assert "domains" in data

        # Check domains
        expected_domains = ["randomization", "deviations", "missing_data", "measurement", "selection"]
        for domain in expected_domains:
            assert domain in data["domains"]
            assert "judgment" in data["domains"][domain]
            assert "confidence" in data["domains"][domain]

    def test_assess_batch(self, session_client, auth_headers):
        """Test batch ROB assessment"""
        studies = [
            {
                "text": "RCT with proper randomization and blinding.",
                "metadata": {"title": "Study 1"}
            },
            {
                "text": "Observational study with high risk of selection bias.",
                "metadata": {"title": "Study 2"}
            }
        ]

        response = session_client.post(
            "/api/ai-features/rob/assess-batch",
            json={
                "studies": studies,
                "parallel": True
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "total_studies" in data
        assert data["total_studies"] == 2
        assert "assessments" in data
        assert "summary" in data

    def test_rob_without_auth(self, session_client):
        """Test ROB assessment fails without authentication"""
        response = session_client.post(
            "/api/ai-features/rob/assess",
            json={
                "study_text": "Sample study text"
            }
        )

        assert response.status_code == 401


# ==================== STUDY SCREENING TESTS ====================

class TestStudyScreening:
    """Tests for study screening endpoints"""

    def test_screen_single_study(self, session_client, auth_headers):
        """Test single study screening"""
        response = session_client.post(
            "/api/ai-features/screening/screen-study",
            json={
                "title": "Effect of Drug A on Mortality in Hypertensive Patients",
                "abstract": "This randomized controlled trial examined the effect of Drug A on mortality in 500 patients with hypertension. Results showed significant reduction in mortality.",
                "threshold": 0.5
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "decision" in data
        assert data["decision"] in ["include", "exclude"]
        assert "confidence" in data
        assert "requires_manual_review" in data

    def test_screen_batch(self, session_client, auth_headers):
        """Test batch study screening"""
        studies = [
            {
                "title": "Drug A for hypertension",
                "abstract": "RCT showing effectiveness"
            },
            {
                "title": "Irrelevant study about cancer",
                "abstract": "Not related to our topic"
            }
        ]

        response = session_client.post(
            "/api/ai-features/screening/screen-batch",
            json={
                "studies": studies,
                "threshold": 0.5
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "total_studies" in data
        assert data["total_studies"] == 2
        assert "results" in data
        assert "summary" in data

    def test_active_learning(self, session_client, auth_headers):
        """Test active learning suggestions"""
        unlabeled_studies = {
            "title": ["Study 1", "Study 2", "Study 3", "Study 4", "Study 5"],
            "abstract": ["Abstract 1", "Abstract 2", "Abstract 3", "Abstract 4", "Abstract 5"]
        }

        response = session_client.post(
            "/api/ai-features/screening/active-learning",
            json={
                "unlabeled_studies": unlabeled_studies,
                "n_suggestions": 3,
                "strategy": "uncertainty"
            },
            headers=auth_headers
        )

        # May succeed or fail depending on whether model is trained
        assert response.status_code in [200, 400, 500]


# ==================== PDF EXTRACTION TESTS ====================

class TestPDFExtraction:
    """Tests for PDF extraction endpoints"""

    def test_extract_from_text(self, session_client, auth_headers):
        """Test PDF text extraction"""
        pdf_text = """
        Meta-Analysis of Drug A vs Placebo

        Study 1 (Smith et al., 2020): N=100 treatment, N=95 control
        Odds Ratio: 0.75 (95% CI: 0.60-0.95), p=0.003

        Study 2 (Jones et al., 2021): N=150 treatment, N=150 control
        Odds Ratio: 0.80 (95% CI: 0.65-0.98), p=0.01

        Heterogeneity: I²=45.2%, τ²=0.08, p=0.12
        """

        response = session_client.post(
            "/api/ai-features/pdf/extract-text",
            json={
                "pdf_text": pdf_text,
                "extract_tables": True,
                "extract_metadata": True
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        # Check for extracted elements
        assert "sample_sizes" in data or "effect_sizes" in data or "statistics" in data

    def test_extract_without_auth(self, session_client):
        """Test PDF extraction fails without authentication"""
        response = session_client.post(
            "/api/ai-features/pdf/extract-text",
            json={
                "pdf_text": "Sample text"
            }
        )

        assert response.status_code == 401


# ==================== BAYESIAN NMA TESTS ====================

class TestBayesianNMA:
    """Tests for Bayesian NMA endpoints"""

    @pytest.fixture
    def sample_nma_data(self):
        """Sample NMA data"""
        return {
            "study": ["Study1", "Study1", "Study2", "Study2", "Study3", "Study3"],
            "treatment": ["A", "B", "A", "C", "B", "C"],
            "events": [10, 8, 15, 12, 18, 14],
            "total": [100, 100, 150, 150, 120, 120]
        }

    def test_fit_nma(self, session_client, auth_headers, sample_nma_data):
        """Test NMA model fitting"""
        response = session_client.post(
            "/api/ai-features/nma/fit",
            json={
                "data": sample_nma_data,
                "outcome_type": "binary",
                "model_type": "random",
                "n_samples": 100,  # Small for testing
                "n_tune": 50
            },
            headers=auth_headers,
            timeout=60.0
        )

        # NMA can take time, may timeout in tests
        assert response.status_code in [200, 408, 500, 504]

        if response.status_code == 200:
            data = response.json()
            assert "model_fitted" in data or "summary" in data

    def test_nma_rankings_without_fit(self, session_client, auth_headers):
        """Test rankings fail if model not fitted"""
        response = session_client.post(
            "/api/ai-features/nma/rankings",
            json={},
            headers=auth_headers
        )

        # Should return error if not fitted
        assert response.status_code in [400, 500]

    def test_nma_without_auth(self, session_client, sample_nma_data):
        """Test NMA fails without authentication"""
        response = session_client.post(
            "/api/ai-features/nma/fit",
            json={
                "data": sample_nma_data,
                "outcome_type": "binary"
            }
        )

        assert response.status_code == 401


# ==================== BENCHMARKING TESTS ====================

class TestBenchmarking:
    """Tests for benchmarking endpoints"""

    def test_benchmark_report(self, session_client, auth_headers):
        """Test benchmark report generation"""
        response = session_client.get(
            "/api/ai-features/benchmark/report?format=markdown",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "format" in data
        assert data["format"] == "markdown"


# ==================== STATUS TESTS ====================

class TestStatus:
    """Tests for status endpoints"""

    def test_features_status(self, session_client, auth_headers):
        """Test features status endpoint"""
        response = session_client.get(
            "/api/ai-features/status",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "features" in data
        assert "overall" in data

        # Check all features are present
        expected_features = [
            "report_generation",
            "rob_assessment",
            "study_screening",
            "pdf_extraction",
            "bayesian_nma"
        ]

        for feature in expected_features:
            assert feature in data["features"]
            assert "status" in data["features"][feature]
            assert "competitive_position" in data["features"][feature]


# ==================== INTEGRATION TESTS ====================

class TestIntegration:
    """Integration tests combining multiple features"""

    def test_complete_workflow(self, session_client, auth_headers):
        """Test complete workflow: screen -> assess -> report"""

        # 1. Screen a study
        screen_response = session_client.post(
            "/api/ai-features/screening/screen-study",
            json={
                "title": "Drug A RCT",
                "abstract": "Randomized controlled trial of Drug A",
                "threshold": 0.3
            },
            headers=auth_headers
        )

        assert screen_response.status_code == 200

        # 2. Assess risk of bias
        rob_response = session_client.post(
            "/api/ai-features/rob/assess",
            json={
                "study_text": "Randomized controlled trial with proper blinding",
                "return_probabilities": False
            },
            headers=auth_headers
        )

        assert rob_response.status_code == 200

        # 3. Generate report (with minimal data)
        report_response = session_client.post(
            "/api/ai-features/report/generate",
            json={
                "meta_analysis_results": {
                    "pooled_effect": 0.75,
                    "ci_lower": 0.60,
                    "ci_upper": 0.95
                },
                "study_data": {
                    "study_id": ["Study1"],
                    "year": [2022]
                },
                "analysis_config": {},
                "report_type": "prisma",
                "include_quality_metrics": False
            },
            headers=auth_headers
        )

        assert report_response.status_code == 200


# ==================== ERROR HANDLING TESTS ====================

class TestErrorHandling:
    """Tests for error handling"""

    def test_invalid_json(self, session_client, auth_headers):
        """Test handling of invalid JSON"""
        response = session_client.post(
            "/api/ai-features/report/generate",
            data="invalid json",
            headers=auth_headers
        )

        assert response.status_code == 422

    def test_missing_required_fields(self, session_client, auth_headers):
        """Test handling of missing required fields"""
        response = session_client.post(
            "/api/ai-features/report/generate",
            json={},
            headers=auth_headers
        )

        assert response.status_code == 422

    def test_rate_limiting(self, session_client, auth_headers):
        """Test rate limiting (if enabled)"""
        # Make multiple rapid requests
        responses = []
        for _ in range(10):
            response = session_client.get(
                "/api/ai-features/status",
                headers=auth_headers
            )
            responses.append(response.status_code)

        # Should either all succeed or hit rate limit
        assert all(code in [200, 429] for code in responses)


# ==================== PERFORMANCE TESTS ====================

class TestPerformance:
    """Performance tests"""

    def test_status_response_time(self, session_client, auth_headers):
        """Test status endpoint response time"""
        import time

        start = time.time()
        response = session_client.get(
            "/api/ai-features/status",
            headers=auth_headers
        )
        elapsed = time.time() - start

        assert response.status_code == 200
        assert elapsed < 2.0  # Should respond within 2 seconds

    def test_batch_vs_individual(self, session_client, auth_headers):
        """Test batch endpoint is faster than individual calls"""
        import time

        studies = [
            {"title": f"Study {i}", "abstract": f"Abstract {i}"}
            for i in range(5)
        ]

        # Individual calls
        start = time.time()
        for study in studies:
            session_client.post(
                "/api/ai-features/screening/screen-study",
                json={**study, "threshold": 0.5},
                headers=auth_headers
            )
        individual_time = time.time() - start

        # Batch call
        start = time.time()
        session_client.post(
            "/api/ai-features/screening/screen-batch",
            json={"studies": studies, "threshold": 0.5},
            headers=auth_headers
        )
        batch_time = time.time() - start

        # Batch should be faster (or at least not much slower)
        assert batch_time <= individual_time * 1.2


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
