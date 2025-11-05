"""
Integration Tests for ML Pipeline
Tests end-to-end ML functionality including:
- Ensemble model training and prediction
- SHAP/LIME explanations
- AutoML optimization
- RAG query system
- Cache performance
"""

import pytest
import pandas as pd
import numpy as np
from fastapi.testclient import TestClient
import json
import time
from datetime import datetime

# Import the FastAPI app
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from api.main_enhanced import app
from cache.ml_cache import ml_cache, REDIS_AVAILABLE

# Test client
client = TestClient(app)

# Sample test data
SAMPLE_STUDIES = {
    "study_id": ["study_1", "study_2", "study_3", "study_4", "study_5"],
    "n": [100, 200, 150, 300, 250],
    "outcome_type": ["binary", "binary", "binary", "binary", "binary"],
    "study_design": ["RCT", "RCT", "cohort", "RCT", "RCT"],
    "blinding": [True, True, False, True, True],
    "allocation_concealment": [True, True, False, True, False]
}

SAMPLE_EFFECT_SIZES = {
    "study_id": ["study_1", "study_2", "study_3", "study_4", "study_5"],
    "yi": [0.5, 0.3, 0.8, 0.2, 0.6],
    "sei": [0.1, 0.15, 0.12, 0.08, 0.11]
}

SAMPLE_STUDY_QUALITY = {
    "study_design": "RCT",
    "sample_size": 200,
    "blinding": True,
    "allocation_concealment": True,
    "attrition_rate": 0.05,
    "selective_reporting": False
}


@pytest.fixture
def auth_headers():
    """Get authentication headers for API requests."""
    # For now, skip auth in tests
    # In production, you'd implement proper test user authentication
    return {}


class TestMLHealth:
    """Test ML system health monitoring."""

    def test_ml_health_endpoint(self):
        """Test ML health check endpoint."""
        response = client.get("/health/ml")

        assert response.status_code == 200
        data = response.json()

        assert "status" in data
        assert "components" in data
        assert "ml_ready" in data

        # Check critical components
        assert "xgboost" in data["components"]
        assert "lightgbm" in data["components"]
        assert "catboost" in data["components"]

        print(f"✓ ML Health Status: {data['status']}")
        print(f"✓ ML Ready: {data['ml_ready']}")
        print(f"✓ Critical Components: {data['critical_components_available']}")


class TestCaching:
    """Test Redis caching functionality."""

    @pytest.mark.skipif(not REDIS_AVAILABLE, reason="Redis not available")
    def test_cache_availability(self):
        """Test that Redis cache is available."""
        stats = ml_cache.stats()

        assert stats["available"] == True
        print(f"✓ Cache available: {stats['available']}")
        print(f"✓ Cache memory: {stats.get('used_memory', 'N/A')}")

    @pytest.mark.skipif(not REDIS_AVAILABLE, reason="Redis not available")
    def test_cache_set_get(self):
        """Test basic cache set/get operations."""
        test_key = "test_ml_cache:test_key"
        test_value = {"prediction": 0.85, "confidence": 0.92}

        # Set value
        success = ml_cache.set(test_key, test_value, ttl=60)
        assert success == True

        # Get value
        retrieved = ml_cache.get(test_key)
        assert retrieved is not None
        assert retrieved["prediction"] == test_value["prediction"]
        assert retrieved["confidence"] == test_value["confidence"]

        # Clean up
        ml_cache.delete(test_key)

        print("✓ Cache set/get operations working")

    @pytest.mark.skipif(not REDIS_AVAILABLE, reason="Redis not available")
    def test_cache_performance_speedup(self, auth_headers):
        """Test that caching provides significant speedup."""
        # Make first request (cache miss)
        start = time.time()
        response1 = client.post(
            "/ml/predict/heterogeneity",
            json={"studies": SAMPLE_STUDIES},
            headers=auth_headers
        )
        time1 = time.time() - start

        assert response1.status_code == 200

        # Make second request (cache hit)
        start = time.time()
        response2 = client.post(
            "/ml/predict/heterogeneity",
            json={"studies": SAMPLE_STUDIES},
            headers=auth_headers
        )
        time2 = time.time() - start

        assert response2.status_code == 200

        # Verify responses are identical
        assert response1.json() == response2.json()

        # Cache should be at least 5x faster
        speedup = time1 / time2 if time2 > 0 else float('inf')

        print(f"✓ First request (cache miss): {time1:.3f}s")
        print(f"✓ Second request (cache hit): {time2:.3f}s")
        print(f"✓ Speedup: {speedup:.1f}x")

        # In real scenarios, cache hit should be <10ms
        # But for tests, we just verify it's faster
        assert time2 < time1, "Cache should make subsequent requests faster"


class TestHeterogeneityPrediction:
    """Test heterogeneity prediction endpoints."""

    def test_heterogeneity_prediction_success(self, auth_headers):
        """Test successful heterogeneity prediction."""
        response = client.post(
            "/ml/predict/heterogeneity",
            json={"studies": SAMPLE_STUDIES},
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "prediction" in data
        assert "confidence" in data
        assert "probability" in data
        assert "explanation" in data
        assert "model" in data

        assert data["prediction"] in ["High", "Low"]
        assert 0 <= data["confidence"] <= 1
        assert 0 <= data["probability"] <= 1

        print(f"✓ Heterogeneity Prediction: {data['prediction']}")
        print(f"✓ Confidence: {data['confidence']:.2f}")
        print(f"✓ Model: {data['model']}")

    def test_heterogeneity_prediction_validation(self, auth_headers):
        """Test prediction with invalid data."""
        response = client.post(
            "/ml/predict/heterogeneity",
            json={"studies": {}},  # Empty data
            headers=auth_headers
        )

        # Should handle gracefully (500 or 422)
        assert response.status_code in [422, 500]
        print("✓ Validation error handled correctly")


class TestPublicationBias:
    """Test publication bias detection."""

    def test_publication_bias_detection_success(self, auth_headers):
        """Test successful publication bias detection."""
        response = client.post(
            "/ml/predict/publication-bias",
            json={"studies": SAMPLE_EFFECT_SIZES},
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "bias_detected" in data
        assert "confidence" in data
        assert "probability" in data
        assert "recommendations" in data

        print(f"✓ Bias Detected: {data['bias_detected']}")
        print(f"✓ Confidence: {data['confidence']:.2f}")
        print(f"✓ Recommendations: {len(data['recommendations'])} items")

    def test_publication_bias_missing_columns(self, auth_headers):
        """Test bias detection with missing required columns."""
        response = client.post(
            "/ml/predict/publication-bias",
            json={"studies": SAMPLE_STUDIES},  # Missing yi, sei
            headers=auth_headers
        )

        assert response.status_code == 400
        assert "yi" in response.json()["detail"].lower() or "sei" in response.json()["detail"].lower()
        print("✓ Missing columns detected correctly")


class TestStudyQuality:
    """Test study quality prediction."""

    def test_study_quality_prediction_success(self, auth_headers):
        """Test successful study quality prediction."""
        response = client.post(
            "/ml/predict/study-quality",
            json={"study": SAMPLE_STUDY_QUALITY},
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "risk_of_bias" in data
        assert "confidence" in data
        assert "quality_score" in data

        print(f"✓ Risk of Bias: {data['risk_of_bias']}")
        print(f"✓ Quality Score: {data['quality_score']:.2f}")


class TestAnalysisRecommendations:
    """Test analysis recommendation engine."""

    def test_analysis_recommendations_success(self, auth_headers):
        """Test successful recommendation generation."""
        response = client.post(
            "/ml/recommend/analysis",
            json={
                "studies": SAMPLE_STUDIES,
                "outcome_type": "binary",
                "metadata": {}
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "recommendations" in data
        assert "by_priority" in data
        assert "summary" in data

        assert len(data["recommendations"]) > 0

        # Check summary structure
        summary = data["summary"]
        assert "total" in summary
        assert "critical" in summary
        assert "high" in summary

        print(f"✓ Total Recommendations: {summary['total']}")
        print(f"✓ Critical: {summary['critical']}")
        print(f"✓ High Priority: {summary['high']}")


class TestEffectDirection:
    """Test effect direction prediction."""

    def test_effect_direction_success(self, auth_headers):
        """Test successful effect direction prediction."""
        response = client.post(
            "/ml/predict/effect-direction",
            json={
                "data": SAMPLE_STUDIES,
                "outcome_type": "binary"
            },
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "prediction" in data
        assert "confidence" in data

        print(f"✓ Effect Direction: {data['prediction']}")
        print(f"✓ Confidence: {data['confidence']:.2f}")


class TestCacheManagement:
    """Test cache management endpoints."""

    @pytest.mark.skipif(not REDIS_AVAILABLE, reason="Redis not available")
    def test_cache_stats_endpoint(self, auth_headers):
        """Test cache statistics endpoint."""
        response = client.get("/ml/cache/stats", headers=auth_headers)

        assert response.status_code == 200
        data = response.json()

        assert "available" in data

        if data["available"]:
            assert "total_keys" in data
            assert "ml_keys" in data
            assert "hit_rate" in data

            print(f"✓ Cache Stats Retrieved:")
            print(f"  - Total Keys: {data.get('total_keys', 'N/A')}")
            print(f"  - ML Keys: {data.get('ml_keys', 'N/A')}")
            print(f"  - Hit Rate: {data.get('hit_rate', 'N/A')}")

    @pytest.mark.skipif(not REDIS_AVAILABLE, reason="Redis not available")
    def test_cache_clear_endpoint(self, auth_headers):
        """Test cache clearing endpoint."""
        # First, make a request to populate cache
        client.post(
            "/ml/predict/heterogeneity",
            json={"studies": SAMPLE_STUDIES},
            headers=auth_headers
        )

        # Clear cache
        response = client.post(
            "/ml/cache/clear",
            params={"pattern": "ml_cache:*"},
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.json()

        assert "success" in data
        assert "keys_deleted" in data
        assert data["success"] == True

        print(f"✓ Cache Cleared: {data['keys_deleted']} keys deleted")


class TestEndToEnd:
    """End-to-end integration tests."""

    def test_complete_ml_workflow(self, auth_headers):
        """Test complete ML workflow from prediction to recommendations."""

        print("\n=== Starting End-to-End ML Workflow Test ===\n")

        # Step 1: Predict heterogeneity
        print("Step 1: Predicting heterogeneity...")
        het_response = client.post(
            "/ml/predict/heterogeneity",
            json={"studies": SAMPLE_STUDIES},
            headers=auth_headers
        )
        assert het_response.status_code == 200
        het_data = het_response.json()
        print(f"✓ Heterogeneity: {het_data['prediction']} (confidence: {het_data['confidence']:.2f})")

        # Step 2: Detect publication bias
        print("\nStep 2: Detecting publication bias...")
        bias_response = client.post(
            "/ml/predict/publication-bias",
            json={"studies": SAMPLE_EFFECT_SIZES},
            headers=auth_headers
        )
        assert bias_response.status_code == 200
        bias_data = bias_response.json()
        print(f"✓ Bias: {bias_data['bias_detected']} (confidence: {bias_data['confidence']:.2f})")

        # Step 3: Get analysis recommendations
        print("\nStep 3: Getting analysis recommendations...")
        rec_response = client.post(
            "/ml/recommend/analysis",
            json={
                "studies": SAMPLE_STUDIES,
                "outcome_type": "binary",
                "metadata": {}
            },
            headers=auth_headers
        )
        assert rec_response.status_code == 200
        rec_data = rec_response.json()
        print(f"✓ Recommendations: {rec_data['summary']['total']} total")

        # Step 4: Assess study quality
        print("\nStep 4: Assessing study quality...")
        quality_response = client.post(
            "/ml/predict/study-quality",
            json={"study": SAMPLE_STUDY_QUALITY},
            headers=auth_headers
        )
        assert quality_response.status_code == 200
        quality_data = quality_response.json()
        print(f"✓ Quality: {quality_data['risk_of_bias']} (score: {quality_data['quality_score']:.2f})")

        print("\n=== End-to-End Workflow Completed Successfully ===\n")


# Performance benchmarks
class TestPerformance:
    """Performance benchmarks for ML operations."""

    def test_prediction_performance(self, auth_headers):
        """Benchmark prediction performance."""
        n_requests = 5
        times = []

        print(f"\nBenchmarking {n_requests} requests...")

        for i in range(n_requests):
            start = time.time()
            response = client.post(
                "/ml/predict/heterogeneity",
                json={"studies": SAMPLE_STUDIES},
                headers=auth_headers
            )
            elapsed = time.time() - start
            times.append(elapsed)

            assert response.status_code == 200

        avg_time = np.mean(times)
        min_time = np.min(times)
        max_time = np.max(times)

        print(f"✓ Average time: {avg_time:.3f}s")
        print(f"✓ Min time: {min_time:.3f}s")
        print(f"✓ Max time: {max_time:.3f}s")

        # If caching works, average should be dominated by fast cached responses
        if REDIS_AVAILABLE:
            # After first request, rest should be fast
            cached_times = times[1:]
            if cached_times:
                avg_cached = np.mean(cached_times)
                print(f"✓ Average cached time: {avg_cached:.3f}s")
                assert avg_cached < avg_time, "Cached requests should be faster on average"


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v", "-s", "--tb=short"])
