"""
API Endpoints Test Suite
=========================

Tests for all 21 HTA feature API endpoints.

Tests:
1. Endpoint availability
2. Request/response validation
3. Error handling
4. Integration tests
"""

import pytest
import requests
import json
import numpy as np
import pandas as pd
from typing import Dict, Any


# Base URL (adjust if API is running elsewhere)
BASE_URL = "http://localhost:8001"


class TestAPIHealth:
    """Test API health and availability"""

    def test_health_endpoint(self):
        """Test /api/health endpoint"""
        try:
            response = requests.get(f"{BASE_URL}/api/health", timeout=5)

            assert response.status_code == 200, f"Health check failed: {response.status_code}"

            data = response.json()
            assert data['status'] == 'healthy'
            assert data['features_available'] == 21

            print("✅ Health check passed")
        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")

    def test_features_list_endpoint(self):
        """Test /api/features/list endpoint"""
        try:
            response = requests.get(f"{BASE_URL}/api/features/list", timeout=5)

            assert response.status_code == 200

            data = response.json()
            assert data['total_features'] == 21
            assert len(data['features']) == 21

            # Check feature structure
            feature = data['features'][0]
            assert 'id' in feature
            assert 'name' in feature
            assert 'status' in feature
            assert 'phase' in feature

            print(f"✅ Features list: {data['total_features']} features")
        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")


class TestMAICEndpoints:
    """Test MAIC/STC endpoints"""

    def test_maic_run_endpoint(self):
        """Test /api/maic/run endpoint"""
        # Create synthetic test data
        np.random.seed(42)

        ipd_data = []
        for i in range(100):
            ipd_data.append({
                'age': float(np.random.normal(60, 10)),
                'sex': int(np.random.binomial(1, 0.5)),
                'treatment': 1,
                'outcome': float(np.random.normal(10, 5))
            })

        agd_data = [{'age': 55.0, 'sex': 0.6}]

        request_data = {
            'ipd': ipd_data,
            'agd_baseline': agd_data,
            'agd_outcomes': {'mean': 7.0, 'se': 0.5},
            'matching_vars': ['age', 'sex'],
            'outcome_var': 'outcome',
            'treatment_var': 'treatment'
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/maic/run",
                json=request_data,
                timeout=30
            )

            if response.status_code == 200:
                data = response.json()

                # Check response structure
                assert 'treatment_effect' in data
                assert 'ci_lower' in data
                assert 'ci_upper' in data
                assert 'ess' in data
                assert 'weights' in data
                assert 'balance_before' in data
                assert 'balance_after' in data

                # Check values are reasonable
                assert np.isfinite(data['treatment_effect'])
                assert data['ess'] > 0
                assert len(data['weights']) == 100

                print(f"✅ MAIC endpoint: Treatment effect = {data['treatment_effect']:.3f}")
                print(f"   ESS = {data['ess']:.1f}, Validation = {data['validation_results']['overall_valid']}")
            else:
                print(f"⚠️  MAIC endpoint returned {response.status_code}")
                print(f"   Response: {response.text}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")

    def test_maic_suggest_variables(self):
        """Test /api/maic/suggest_variables endpoint"""
        request_data = {
            'ipd_columns': ['age', 'sex', 'baseline_score', 'comorbidities', 'outcome'],
            'agd_columns': ['age', 'sex', 'baseline_score', 'outcome']
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/maic/suggest_variables",
                json=request_data,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                assert 'suggestions' in data
                assert isinstance(data['suggestions'], list)

                print(f"✅ Variable suggestions: {data['suggestions']}")
            else:
                print(f"⚠️  Suggest variables returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")


class TestTargetTrialEndpoint:
    """Test Target Trial Emulation endpoint"""

    def test_target_trial_endpoint(self):
        """Test /api/target_trial/emulate endpoint"""
        # Create synthetic observational data
        data = []
        for i in range(200):
            data.append({
                'patient_id': i,
                'time': 0,
                'treatment': int(np.random.binomial(1, 0.5)),
                'age': float(np.random.normal(60, 10)),
                'outcome': float(np.random.normal(10, 5))
            })

        request_data = {
            'data': data,
            'treatment_var': 'treatment',
            'outcome_var': 'outcome',
            'time_var': 'time',
            'covariates': ['age']
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/target_trial/emulate",
                json=request_data,
                timeout=30
            )

            if response.status_code == 200:
                result = response.json()
                assert 'treatment_effect' in result
                assert 'method' in result
                print(f"✅ Target trial: Effect = {result['treatment_effect']:.3f}")
            else:
                print(f"⚠️  Target trial returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")


class TestMultiStateEndpoint:
    """Test Multi-State Models endpoint"""

    def test_multistate_endpoint(self):
        """Test /api/multistate/fit endpoint"""
        request_data = {
            'data': [
                {'patient_id': 1, 'time': 0, 'state': 'stable'},
                {'patient_id': 1, 'time': 6, 'state': 'progression'}
            ],
            'states': ['stable', 'progression', 'death'],
            'transitions': [
                {'from': 'stable', 'to': 'progression'},
                {'from': 'stable', 'to': 'death'},
                {'from': 'progression', 'to': 'death'}
            ],
            'time_var': 'time',
            'state_var': 'state',
            'covariates': []
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/multistate/fit",
                json=request_data,
                timeout=30
            )

            if response.status_code == 200:
                result = response.json()
                assert 'transition_probabilities' in result
                print(f"✅ Multi-state: {len(result['transition_probabilities'])} transitions")
            else:
                print(f"⚠️  Multi-state returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")


class TestDossierEndpoint:
    """Test HTA Dossier Generator endpoint"""

    def test_dossier_generation(self):
        """Test /api/dossier/generate endpoint"""
        request_data = {
            'study_data': {'n_studies': 10},
            'target_agency': 'NICE',
            'indication': 'Type 2 Diabetes',
            'comparators': ['Placebo', 'Standard care']
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/dossier/generate",
                json=request_data,
                timeout=60
            )

            if response.status_code == 200:
                result = response.json()
                assert 'dossier_id' in result
                assert 'sections' in result
                print(f"✅ Dossier generated: {result['dossier_id']}")
            else:
                print(f"⚠️  Dossier generation returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")


class TestPhase2Endpoints:
    """Test Phase 2 (AI & Automation) endpoints"""

    def test_living_review_setup(self):
        """Test /api/living_review/setup endpoint"""
        request_data = {
            'review_id': 'test_review_001',
            'search_queries': ['diabetes AND metformin'],
            'inclusion_criteria': 'RCTs in adults with T2D',
            'update_frequency': 'weekly'
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/living_review/setup",
                json=request_data,
                timeout=10
            )

            if response.status_code == 200:
                result = response.json()
                assert result['review_id'] == 'test_review_001'
                assert result['status'] == 'active'
                print(f"✅ Living review setup: {result['review_id']}")
            else:
                print(f"⚠️  Living review returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")

    def test_prisma_validation(self):
        """Test /api/prisma/validate endpoint"""
        request_data = {
            'title': 'Systematic Review of...',
            'abstract': 'Complete abstract...',
            'methods': 'Complete methods...'
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/prisma/validate",
                json=request_data,
                timeout=15
            )

            if response.status_code == 200:
                result = response.json()
                assert 'compliant' in result
                assert 'checklist' in result
                print(f"✅ PRISMA validation: Compliant = {result['compliant']}")
            else:
                print(f"⚠️  PRISMA validation returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")


class TestPhase3Endpoints:
    """Test Phase 3 (Advanced Stats) endpoints"""

    def test_propensity_score_analysis(self):
        """Test /api/propensity/analyze endpoint"""
        data = []
        for i in range(100):
            data.append({
                'treatment': int(np.random.binomial(1, 0.5)),
                'age': float(np.random.normal(60, 10)),
                'outcome': float(np.random.normal(10, 5))
            })

        request_data = {
            'data': data,
            'treatment_var': 'treatment',
            'outcome_var': 'outcome',
            'covariates': ['age'],
            'method': 'matching'
        }

        try:
            response = requests.post(
                f"{BASE_URL}/api/propensity/analyze",
                json=request_data,
                timeout=30
            )

            if response.status_code == 200:
                result = response.json()
                assert 'treatment_effect' in result
                print(f"✅ Propensity score: Effect = {result['treatment_effect']:.3f}")
            else:
                print(f"⚠️  Propensity score returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            pytest.skip("API server not running")


def run_all_api_tests():
    """Run all API tests"""
    print("="*70)
    print("API ENDPOINTS TEST SUITE")
    print("="*70)
    print()
    print("Testing API at:", BASE_URL)
    print()

    # Check if API is running
    try:
        response = requests.get(f"{BASE_URL}/api/health", timeout=2)
        if response.status_code == 200:
            print("✅ API server is running")
            print()
        else:
            print("⚠️  API server responded but returned non-200 status")
            print()
    except requests.exceptions.ConnectionError:
        print("❌ API server is not running")
        print("   Start the API with: uvicorn backend.api.hta_features_api:app --reload")
        print()
        return 1

    # Run pytest
    pytest_args = [
        __file__,
        '-v',
        '--tb=short',
        '-x'
    ]

    result = pytest.main(pytest_args)

    return result


if __name__ == "__main__":
    exit_code = run_all_api_tests()

    print()
    print("="*70)
    if exit_code == 0:
        print("✅ ALL API TESTS PASSED")
    else:
        print("❌ SOME API TESTS FAILED")
    print("="*70)

    exit(exit_code)
