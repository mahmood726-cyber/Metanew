"""
End-to-End Workflow Tests for EvidenceOS PRIME
Tests complete analysis workflows from data upload to report generation
"""
import pytest
import requests
import pandas as pd
import time
from typing import Dict, Any


API_BASE_URL = "http://localhost:8000"
AI_API_BASE_URL = "http://localhost:8001"
TEST_TIMEOUT = 30


@pytest.fixture(scope="module")
def api_services():
    """Ensure both APIs are available"""
    # Check main API
    for i in range(30):
        try:
            r = requests.get(f"{API_BASE_URL}/health", timeout=2)
            if r.status_code == 200:
                break
        except requests.ConnectionError:
            if i == 29:
                pytest.skip("Main API not available")
            time.sleep(1)

    # Check AI API
    for i in range(30):
        try:
            r = requests.get(f"{AI_API_BASE_URL}/health", timeout=2)
            if r.status_code == 200:
                break
        except requests.ConnectionError:
            if i == 29:
                pytest.skip("AI API not available")
            time.sleep(1)

    return {
        "main_api": API_BASE_URL,
        "ai_api": AI_API_BASE_URL
    }


# ============================================================================
# E2E TEST: Complete Meta-Analysis Workflow
# ============================================================================

class TestCompleteMetaAnalysisWorkflow:
    """Test complete workflow from data validation to evidence export"""

    @pytest.fixture
    def trial_data(self):
        """Sample RCT data for meta-analysis"""
        return {
            "data": [
                # Study 1: Treatment vs Control
                {"study_id": "Smith2020", "author": "Smith", "year": 2020,
                 "treatment": "Intervention", "events": 45, "n": 200},
                {"study_id": "Smith2020", "author": "Smith", "year": 2020,
                 "treatment": "Control", "events": 65, "n": 200},

                # Study 2
                {"study_id": "Jones2019", "author": "Jones", "year": 2019,
                 "treatment": "Intervention", "events": 32, "n": 150},
                {"study_id": "Jones2019", "author": "Jones", "year": 2019,
                 "treatment": "Control", "events": 48, "n": 150},

                # Study 3
                {"study_id": "Lee2021", "author": "Lee", "year": 2021,
                 "treatment": "Intervention", "events": 28, "n": 180},
                {"study_id": "Lee2021", "author": "Lee", "year": 2021,
                 "treatment": "Control", "events": 42, "n": 180},

                # Study 4
                {"study_id": "Wang2018", "author": "Wang", "year": 2018,
                 "treatment": "Intervention", "events": 19, "n": 100},
                {"study_id": "Wang2018", "author": "Wang", "year": 2018,
                 "treatment": "Control", "events": 31, "n": 100},

                # Study 5
                {"study_id": "Kumar2022", "author": "Kumar", "year": 2022,
                 "treatment": "Intervention", "events": 52, "n": 220},
                {"study_id": "Kumar2022", "author": "Kumar", "year": 2022,
                 "treatment": "Control", "events": 71, "n": 220},
            ],
            "data_type": "binary"
        }

    def test_step1_validate_data(self, api_services, trial_data):
        """Step 1: Validate uploaded data"""
        response = requests.post(
            f"{api_services['main_api']}/validate",
            json=trial_data,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        # Should pass validation
        assert result["is_valid"] is True
        assert result["summary"]["errors"] == 0

        # Should have warnings or info about data characteristics
        assert "summary" in result
        print(f"\n✓ Step 1: Data validated - {len(trial_data['data'])} records")

    def test_step2_compute_effect_sizes(self, api_services, trial_data):
        """Step 2: Compute effect sizes (odds ratios)"""
        # Reshape data to contrast format for effect size computation
        studies = {}
        for row in trial_data["data"]:
            sid = row["study_id"]
            if sid not in studies:
                studies[sid] = {}
            studies[sid][row["treatment"]] = {"events": row["events"], "n": row["n"]}

        contrast_data = []
        for sid, arms in studies.items():
            if "Intervention" in arms and "Control" in arms:
                contrast_data.append({
                    "study_id": sid,
                    "events1": arms["Intervention"]["events"],
                    "n1": arms["Intervention"]["n"],
                    "events2": arms["Control"]["events"],
                    "n2": arms["Control"]["n"]
                })

        payload = {
            "data": contrast_data,
            "measure": "OR"
        }

        response = requests.post(
            f"{api_services['main_api']}/compute/yi",
            json=payload,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        assert result["measure"] == "OR"
        assert result["n_observations"] == 5
        assert len(result["data"]) == 5

        # Check that effect sizes were computed
        for obs in result["data"]:
            assert "yi" in obs
            assert "sei" in obs
            assert obs["yi"] is not None
            assert obs["sei"] > 0

        print(f"\n✓ Step 2: Effect sizes computed for {len(result['data'])} studies")
        return result["data"]

    def test_step3_ai_interpretation(self, api_services):
        """Step 3: AI interprets heterogeneity"""
        # Simulated meta-analysis results
        heterogeneity_params = {
            "i2": 42.3,
            "tau2": 0.035,
            "q_stat": 7.12,
            "q_pval": 0.13,
            "n_studies": 5
        }

        response = requests.get(
            f"{api_services['ai_api']}/interpret/heterogeneity",
            params=heterogeneity_params,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        assert "interpretation" in result
        assert "q_test" in result
        assert "suggestions" in result

        # Should identify moderate heterogeneity
        assert "moderate" in result["interpretation"].lower()

        print(f"\n✓ Step 3: AI interpreted heterogeneity (I² = {heterogeneity_params['i2']}%)")

    def test_step4_nlq_forest_plot_request(self, api_services):
        """Step 4: Natural language query for forest plot"""
        query = {
            "query": "Show me a forest plot for the mortality outcome",
            "context": {
                "current_outcome": "mortality",
                "n_studies": 5
            }
        }

        response = requests.post(
            f"{api_services['ai_api']}/nlq",
            json=query,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        assert result["action"] == "show_forest"
        assert result["confidence"] > 0.5
        assert "forest" in result["explanation"].lower()

        print(f"\n✓ Step 4: AI parsed query -> action: {result['action']}")

    def test_step5_create_evidence_object(self, api_services, trial_data):
        """Step 5: Create and validate evidence object"""
        evidence_object = {
            "evidence_id": "E2E_TEST_001",
            "version": "1.0.0",
            "protocol": {
                "protocol_id": "PROTO_001",
                "title": "Intervention for mortality reduction",
                "population": "Adults with high cardiovascular risk",
                "intervention": "Novel intervention",
                "comparator": "Standard care",
                "outcomes": ["All-cause mortality", "Cardiovascular mortality"],
                "inclusion_criteria": ["RCTs", "Adults ≥18 years"],
                "exclusion_criteria": ["Observational studies"]
            },
            "studies": [
                {"study_id": "Smith2020", "author": "Smith", "year": 2020},
                {"study_id": "Jones2019", "author": "Jones", "year": 2019},
                {"study_id": "Lee2021", "author": "Lee", "year": 2021},
                {"study_id": "Wang2018", "author": "Wang", "year": 2018},
                {"study_id": "Kumar2022", "author": "Kumar", "year": 2022},
            ],
            "observations": []
        }

        # Validate evidence object
        response = requests.post(
            f"{api_services['main_api']}/evidence/validate",
            json=evidence_object,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        assert result["valid"] is True
        assert result["n_studies"] == 5
        assert result["has_protocol"] is True

        # Compute hash
        hash_response = requests.post(
            f"{api_services['main_api']}/evidence/hash",
            json=evidence_object,
            timeout=TEST_TIMEOUT
        )

        assert hash_response.status_code == 200
        hash_result = hash_response.json()

        assert "content_hash" in hash_result
        assert len(hash_result["content_hash"]) == 64

        print(f"\n✓ Step 5: Evidence object created and validated")
        print(f"  - Evidence ID: {result['evidence_id']}")
        print(f"  - Hash: {hash_result['content_hash'][:16]}...")


# ============================================================================
# E2E TEST: Health Economics Workflow
# ============================================================================

class TestHealthEconomicsWorkflow:
    """Test complete health economics workflow"""

    def test_step1_generate_psa_parameters(self, api_services):
        """Step 1: Generate PSA parameters from meta-analysis"""
        # Simulating meta-analysis results fed into economic model
        ma_results = {
            "n_iterations": 1000,
            "hr_progression": 0.65,  # From meta-analysis
            "hr_death": 0.75,
            "cost_treatment": 18000,
            "seed": 12345
        }

        response = requests.post(
            f"{api_services['main_api']}/econ/params",
            json=ma_results,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        assert result["n_iterations"] == 1000
        assert "parameters" in result

        # Check all required parameters were sampled
        required_params = ["hr_progression", "hr_death", "utility_stable",
                          "utility_progressed", "cost_treatment"]
        for param in required_params:
            assert param in result["parameters"]
            assert len(result["parameters"][param]) == 1000

        print(f"\n✓ Step 1: Generated {result['n_iterations']} PSA samples")

    def test_step2_interpret_icer(self, api_services):
        """Step 2: Interpret ICER result"""
        icer_result = {
            "icer": 22500,
            "ci_lower": 18000,
            "ci_upper": 28000,
            "wtp": 30000
        }

        response = requests.get(
            f"{api_services['ai_api']}/interpret/icer",
            params=icer_result,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        assert "interpretation" in result
        assert "confidence_interval" in result

        # ICER below threshold should be identified as likely cost-effective
        assert "cost-effective" in result["interpretation"].lower()

        print(f"\n✓ Step 2: ICER interpreted (£{icer_result['icer']}/QALY)")

    def test_step3_nlq_ceac_request(self, api_services):
        """Step 3: Natural language query for CEAC"""
        query = {
            "query": "What's the probability of being cost-effective at £30,000?",
            "context": {
                "has_psa_results": True,
                "wtp_threshold": 30000
            }
        }

        response = requests.post(
            f"{api_services['ai_api']}/nlq",
            json=query,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        # Should recognize CEAC-related query
        assert result["action"] in ["show_ceac", "check_cost_effective_at_threshold"]
        assert result["confidence"] > 0.6

        print(f"\n✓ Step 3: AI parsed CEAC query -> {result['action']}")


# ============================================================================
# E2E TEST: Error Recovery Workflow
# ============================================================================

class TestErrorRecoveryWorkflow:
    """Test that system handles errors gracefully"""

    def test_invalid_data_validation_recovery(self, api_services):
        """Test validation catches errors and provides helpful messages"""
        bad_data = {
            "data": [
                {"study_id": "BadStudy", "treatment": "A", "events": 200, "n": 100},
                {"study_id": "BadStudy", "treatment": "A", "events": 50, "n": 100},  # Duplicate
            ],
            "data_type": "binary"
        }

        response = requests.post(
            f"{api_services['main_api']}/validate",
            json=bad_data,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        # Should detect multiple errors
        assert result["is_valid"] is False
        assert result["summary"]["errors"] >= 2

        # Should provide specific problem descriptions
        problems = result["problems"]
        assert len(problems) >= 2

        # Check for events > n error
        assert any("events" in str(p).lower() and "exceed" in str(p).lower()
                  for p in problems)

        # Check for duplicate error
        assert any("duplicate" in str(p).lower() for p in problems)

        print(f"\n✓ Error recovery: Detected {len(problems)} validation problems")

    def test_unimplemented_endpoint_handling(self, api_services):
        """Test that unimplemented endpoints return proper 501"""
        response = requests.post(
            f"{api_services['main_api']}/meta/bayes",
            json={"data": []},
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 501
        error = response.json()

        assert "Not Implemented" in str(error)
        assert "alternatives" in str(error).lower() or "alternative" in str(error).lower()

        print(f"\n✓ Error recovery: Unimplemented endpoint returned 501")

    def test_nlq_unknown_query_handling(self, api_services):
        """Test that unknown queries are handled gracefully"""
        query = {
            "query": "xyz abc nonsense query that makes no sense",
            "context": {}
        }

        response = requests.post(
            f"{api_services['ai_api']}/nlq",
            json=query,
            timeout=TEST_TIMEOUT
        )

        assert response.status_code == 200
        result = response.json()

        assert result["action"] == "unknown"
        assert result["confidence"] == 0.0
        assert "don't understand" in result["explanation"].lower()

        print(f"\n✓ Error recovery: Unknown query handled gracefully")


# ============================================================================
# PERFORMANCE TEST: Response Times
# ============================================================================

@pytest.mark.slow
class TestPerformance:
    """Test API performance under load"""

    def test_validation_response_time(self, api_services):
        """Test validation completes quickly"""
        data = {
            "data": [
                {"study_id": f"Study{i}", "treatment": "A", "events": 10, "n": 100}
                for i in range(50)  # 50 studies
            ],
            "data_type": "binary"
        }

        start = time.time()
        response = requests.post(
            f"{api_services['main_api']}/validate",
            json=data,
            timeout=TEST_TIMEOUT
        )
        elapsed = time.time() - start

        assert response.status_code == 200
        assert elapsed < 5.0  # Should complete in < 5 seconds

        print(f"\n✓ Performance: Validated 50 studies in {elapsed:.2f}s")

    def test_effect_size_computation_time(self, api_services):
        """Test effect size computation is performant"""
        data = {
            "data": [
                {
                    "study_id": f"Study{i}",
                    "events1": 10 + i, "n1": 100,
                    "events2": 20 + i, "n2": 100
                }
                for i in range(20)
            ],
            "measure": "OR"
        }

        start = time.time()
        response = requests.post(
            f"{api_services['main_api']}/compute/yi",
            json=data,
            timeout=TEST_TIMEOUT
        )
        elapsed = time.time() - start

        assert response.status_code == 200
        assert elapsed < 3.0  # Should be fast

        print(f"\n✓ Performance: Computed effect sizes for 20 studies in {elapsed:.2f}s")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s", "--tb=short"])
