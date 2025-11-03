"""
Automated tests for AI Copilot NLQ API
Tests rule-based parser, statistical interpreter, and API endpoints
Run with: pytest test_nlq_api.py -v
"""

import pytest
from fastapi.testclient import TestClient
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from nlq import app, RuleBasedNLQParser, StatisticalInterpreter

client = TestClient(app)


# ============================================================================
# TEST RULE-BASED NLQ PARSER
# ============================================================================

class TestRuleBasedNLQParser:
    """Test suite for rule-based natural language query parser"""

    @pytest.fixture
    def parser(self):
        return RuleBasedNLQParser()

    def test_run_meta_analysis(self, parser):
        """Test pattern matching for meta-analysis queries"""
        queries = [
            "Run meta-analysis",
            "perform meta analysis",
            "execute MA",
            "do meta-analysis"
        ]

        for query in queries:
            response = parser.parse(query)
            assert response.action == "run_meta"
            assert response.confidence >= 0.85

    def test_show_forest_plot(self, parser):
        """Test pattern matching for forest plot queries"""
        queries = [
            "Show forest plot",
            "display the forest plot",
            "generate forest",
            "plot forest"
        ]

        for query in queries:
            response = parser.parse(query)
            assert response.action == "show_forest"
            assert response.confidence >= 0.85

    def test_heterogeneity_queries(self, parser):
        """Test pattern matching for heterogeneity queries"""
        queries = [
            "Is there significant heterogeneity?",
            "check heterogeneity",
            "assess heterogeneity",
            "what is the I-squared?"
        ]

        for query in queries:
            response = parser.parse(query)
            assert response.action == "interpret_heterogeneity"
            assert response.confidence >= 0.85

    def test_icer_queries(self, parser):
        """Test pattern matching for ICER queries"""
        queries = [
            "Calculate ICER",
            "compute the ICER",
            "what is the cost-effectiveness",
            "show me the icer"
        ]

        for query in queries:
            response = parser.parse(query)
            assert response.action == "run_icer"
            assert response.confidence >= 0.85

    def test_cost_effective_threshold(self, parser):
        """Test threshold extraction from queries"""
        query = "Is it cost-effective at £30,000/QALY?"
        response = parser.parse(query)

        assert response.action == "check_cost_effective_at_threshold"
        assert "wtp_threshold" in response.parameters
        assert response.parameters["wtp_threshold"] == 30000

    def test_threshold_with_k_notation(self, parser):
        """Test threshold extraction with 'k' notation"""
        query = "Check cost-effectiveness at £50k per QALY"
        response = parser.parse(query)

        assert "wtp_threshold" in response.parameters
        assert response.parameters["wtp_threshold"] == 50000

    def test_compare_scenarios(self, parser):
        """Test pattern matching for scenario comparison"""
        queries = [
            "Compare scenarios",
            "compare my analyses",
            "show scenario diff"
        ]

        for query in queries:
            response = parser.parse(query)
            assert response.action in ["compare_scenarios", "show_scenario_diff"]

    def test_unknown_query(self, parser):
        """Test handling of unrecognized queries"""
        query = "This is complete nonsense that should not match"
        response = parser.parse(query)

        assert response.action == "unknown"
        assert response.confidence == 0.0
        assert "don't understand" in response.explanation.lower()


# ============================================================================
# TEST STATISTICAL INTERPRETER
# ============================================================================

class TestStatisticalInterpreter:
    """Test suite for statistical interpretation engine"""

    def test_interpret_i2_low(self):
        """Test I² interpretation for low heterogeneity"""
        interpretation = StatisticalInterpreter.interpret_i2(15.0)

        assert "low" in interpretation.lower()
        assert "15.0%" in interpretation
        assert "Higgins" in interpretation  # Citation present

    def test_interpret_i2_moderate(self):
        """Test I² interpretation for moderate heterogeneity"""
        interpretation = StatisticalInterpreter.interpret_i2(35.0)

        assert "moderate" in interpretation.lower()
        assert "35.0%" in interpretation

    def test_interpret_i2_substantial(self):
        """Test I² interpretation for substantial heterogeneity"""
        interpretation = StatisticalInterpreter.interpret_i2(65.0)

        assert "substantial" in interpretation.lower()
        assert "subgroup" in interpretation.lower()  # Recommendation

    def test_interpret_i2_considerable(self):
        """Test I² interpretation for considerable heterogeneity"""
        interpretation = StatisticalInterpreter.interpret_i2(85.0)

        assert "considerable" in interpretation.lower()
        assert "pooling may not be appropriate" in interpretation.lower()

    def test_interpret_icer_dominant(self):
        """Test ICER interpretation when intervention is dominant"""
        interpretation = StatisticalInterpreter.interpret_icer(-5000, wtp=30000)

        assert "DOMINANT" in interpretation.upper()
        assert "cheaper and more effective" in interpretation.lower()

    def test_interpret_icer_below_threshold(self):
        """Test ICER interpretation when below WTP threshold"""
        interpretation = StatisticalInterpreter.interpret_icer(24567, wtp=30000)

        assert "below" in interpretation.lower()
        assert "likely cost-effective" in interpretation.lower()
        assert "NICE" in interpretation  # Citation

    def test_interpret_icer_above_threshold(self):
        """Test ICER interpretation when above WTP threshold"""
        interpretation = StatisticalInterpreter.interpret_icer(45000, wtp=30000)

        assert "exceeds" in interpretation.lower()
        assert "unlikely to be cost-effective" in interpretation.lower()

    def test_interpret_p_value_highly_significant(self):
        """Test p-value interpretation for p < 0.001"""
        interpretation = StatisticalInterpreter.interpret_p_value(0.0005)

        assert "highly statistically significant" in interpretation.lower()

    def test_interpret_p_value_significant(self):
        """Test p-value interpretation for p < 0.05"""
        interpretation = StatisticalInterpreter.interpret_p_value(0.03)

        assert "statistically significant" in interpretation.lower()

    def test_interpret_p_value_not_significant(self):
        """Test p-value interpretation for p >= 0.05"""
        interpretation = StatisticalInterpreter.interpret_p_value(0.15)

        assert "not statistically significant" in interpretation.lower()

    def test_suggest_sensitivity_high_heterogeneity(self):
        """Test sensitivity analysis suggestions for high I²"""
        suggestions = StatisticalInterpreter.suggest_sensitivity_analysis(
            i2=65.0,
            n_studies=15,
            has_high_rob=False
        )

        assert len(suggestions) > 0
        assert any("subgroup" in s.lower() for s in suggestions)

    def test_suggest_sensitivity_many_studies(self):
        """Test sensitivity suggestions with many studies"""
        suggestions = StatisticalInterpreter.suggest_sensitivity_analysis(
            i2=30.0,
            n_studies=25,
            has_high_rob=False
        )

        assert any("meta-regression" in s.lower() for s in suggestions)
        assert any("publication bias" in s.lower() for s in suggestions)

    def test_suggest_sensitivity_high_rob(self):
        """Test sensitivity suggestions with high ROB studies"""
        suggestions = StatisticalInterpreter.suggest_sensitivity_analysis(
            i2=30.0,
            n_studies=10,
            has_high_rob=True
        )

        assert any("risk of bias" in s.lower() for s in suggestions)


# ============================================================================
# TEST API ENDPOINTS
# ============================================================================

class TestAPIEndpoints:
    """Test suite for FastAPI endpoints"""

    def test_health_check(self):
        """Test /health endpoint"""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "llm_available" in data
        assert data["version"] == "4.0.0"

    def test_root_endpoint(self):
        """Test root / endpoint"""
        response = client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "endpoints" in data

    def test_nlq_endpoint_basic(self):
        """Test /nlq endpoint with basic query"""
        response = client.post(
            "/nlq",
            json={
                "query": "Show forest plot",
                "context": {},
                "user_id": "test_user"
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert data["action"] == "show_forest"
        assert data["confidence"] >= 0.8
        assert len(data["explanation"]) > 0

    def test_nlq_endpoint_with_context(self):
        """Test /nlq endpoint with analysis context"""
        response = client.post(
            "/nlq",
            json={
                "query": "Is there significant heterogeneity?",
                "context": {
                    "i_squared": 67.3,
                    "n_studies": 12,
                    "current_outcome": "mortality"
                },
                "user_id": "test_user"
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert data["action"] == "interpret_heterogeneity"
        assert data["parameters"].get("outcome") == "mortality"

    def test_nlq_endpoint_threshold_extraction(self):
        """Test /nlq endpoint extracts WTP threshold"""
        response = client.post(
            "/nlq",
            json={
                "query": "Is it cost-effective at £30,000/QALY?",
                "context": {},
                "user_id": "test_user"
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert "wtp_threshold" in data["parameters"]
        assert data["parameters"]["wtp_threshold"] == 30000

    def test_interpret_heterogeneity_endpoint(self):
        """Test /interpret/heterogeneity endpoint"""
        response = client.post(
            "/interpret/heterogeneity",
            params={
                "i2": 67.3,
                "tau2": 0.042,
                "q_stat": 33.5,
                "q_pval": 0.002,
                "n_studies": 12
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert "interpretation" in data
        assert "q_test" in data
        assert "suggestions" in data
        assert len(data["suggestions"]) > 0

    def test_interpret_icer_endpoint(self):
        """Test /interpret/icer endpoint"""
        response = client.post(
            "/interpret/icer",
            params={
                "icer": 24567,
                "ci_lower": 18200,
                "ci_upper": 32400,
                "wtp": 30000
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert "interpretation" in data
        assert "confidence_interval" in data
        assert "below" in data["interpretation"].lower()

    def test_nlq_endpoint_missing_query(self):
        """Test /nlq endpoint with missing query field"""
        response = client.post(
            "/nlq",
            json={"context": {}}
        )

        assert response.status_code == 422  # Validation error


# ============================================================================
# TEST EDGE CASES
# ============================================================================

class TestEdgeCases:
    """Test edge cases and boundary conditions"""

    def test_empty_query(self):
        """Test handling of empty query"""
        parser = RuleBasedNLQParser()
        response = parser.parse("")

        assert response.action == "unknown"
        assert response.confidence == 0.0

    def test_very_long_query(self):
        """Test handling of very long query"""
        parser = RuleBasedNLQParser()
        long_query = "show forest plot " * 100  # 1700 chars
        response = parser.parse(long_query)

        assert response.action == "show_forest"  # Should still match

    def test_case_insensitive_matching(self):
        """Test case-insensitive pattern matching"""
        parser = RuleBasedNLQParser()

        queries = [
            "SHOW FOREST PLOT",
            "Show Forest Plot",
            "show forest plot"
        ]

        for query in queries:
            response = parser.parse(query)
            assert response.action == "show_forest"

    def test_i2_edge_values(self):
        """Test I² interpretation at boundary values"""
        assert "low" in StatisticalInterpreter.interpret_i2(24.9).lower()
        assert "moderate" in StatisticalInterpreter.interpret_i2(25.0).lower()
        assert "substantial" in StatisticalInterpreter.interpret_i2(50.0).lower()
        assert "considerable" in StatisticalInterpreter.interpret_i2(75.0).lower()

    def test_negative_icer(self):
        """Test ICER interpretation with negative values"""
        interpretation = StatisticalInterpreter.interpret_icer(-10000)

        assert "dominant" in interpretation.lower()
        assert "negative" in interpretation.lower()

    def test_zero_icer(self):
        """Test ICER interpretation with zero value"""
        interpretation = StatisticalInterpreter.interpret_icer(0, wtp=30000)

        assert "dominant" in interpretation.lower()


# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

class TestPerformance:
    """Test performance and response times"""

    def test_rule_parser_speed(self):
        """Test rule-based parser responds in < 100ms"""
        import time
        parser = RuleBasedNLQParser()

        start = time.time()
        for _ in range(100):
            parser.parse("Show forest plot")
        end = time.time()

        avg_time = (end - start) / 100
        assert avg_time < 0.1, f"Average response time {avg_time*1000:.1f}ms exceeds 100ms"

    def test_api_endpoint_speed(self):
        """Test API endpoint responds in < 200ms"""
        import time

        start = time.time()
        for _ in range(50):
            client.post("/nlq", json={"query": "Show forest plot"})
        end = time.time()

        avg_time = (end - start) / 50
        assert avg_time < 0.2, f"Average API response time {avg_time*1000:.1f}ms exceeds 200ms"


# ============================================================================
# RUN TESTS
# ============================================================================

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
