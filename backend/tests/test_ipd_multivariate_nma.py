"""
Comprehensive Tests for IPD and Multivariate Network Meta-Analysis
===================================================================

Tests for:
- One-stage IPD NMA
- Two-stage IPD NMA
- Multivariate NMA with multiple outcomes
- Individual predictions
- Between-outcome correlations
- Joint rankings
"""

import pytest
import numpy as np
import pandas as pd

from ml.ipd_multivariate_nma import (
    IPDNetworkMetaAnalysis,
    MultivariateNetworkMetaAnalysis,
    IPDPatient,
    AggregateStudy,
    IPDNMAResults,
    MultivariateNMAResults,
    IPDNMAMethod,
    ipd_nma_quick_fit,
    multivariate_nma_quick_fit
)


# ==================== Fixtures ====================

@pytest.fixture
def ipd_patients():
    """Generate example IPD data"""
    np.random.seed(42)

    patients = []
    patient_id = 1

    # 3 studies, 3 treatments each
    for study_id in range(1, 4):
        for treatment in ["Control", "Treatment A", "Treatment B"]:
            n_patients = 50

            for _ in range(n_patients):
                # Simulate outcome
                baseline = 50
                trt_effect = {"Control": 0, "Treatment A": 5, "Treatment B": 8}.get(treatment, 0)

                outcome = baseline + trt_effect + np.random.normal(0, 10)

                patients.append(IPDPatient(
                    patient_id=f"P{patient_id}",
                    study_id=f"Study{study_id}",
                    treatment=treatment,
                    outcome=outcome,
                    covariates={
                        "age": np.random.normal(60, 10),
                        "sex": np.random.choice([0, 1]),
                        "baseline_severity": np.random.normal(50, 15)
                    }
                ))

                patient_id += 1

    return patients


@pytest.fixture
def multivariate_data():
    """Generate multivariate NMA data (multiple outcomes)"""
    np.random.seed(42)

    # 2 outcomes: efficacy and safety
    data = {
        "efficacy": [],
        "safety": []
    }

    treatments = ["Control", "Treatment A", "Treatment B", "Treatment C"]

    # Generate studies for each outcome
    for outcome in ["efficacy", "safety"]:
        for study_id in range(1, 6):
            # Each study has 2-3 arms
            n_arms = np.random.randint(2, 4)
            study_treatments = np.random.choice(treatments, n_arms, replace=False)

            for trt in study_treatments:
                # Effect depends on treatment and outcome
                if outcome == "efficacy":
                    base_effect = {"Control": 0, "Treatment A": 0.5, "Treatment B": 0.7, "Treatment C": 0.6}
                else:  # safety (lower is better)
                    base_effect = {"Control": 0, "Treatment A": -0.2, "Treatment B": -0.4, "Treatment C": -0.1}

                effect = base_effect.get(trt, 0) + np.random.normal(0, 0.2)
                se = np.random.uniform(0.1, 0.3)

                data[outcome].append({
                    "study": f"Study{study_id}",
                    "treatment": trt,
                    "effect": effect,
                    "se": se
                })

    return data


# ==================== IPD NMA Tests ====================

class TestIPDNMAInitialization:
    """Test IPD NMA initialization"""

    def test_basic_initialization(self, ipd_patients):
        """Test basic IPD NMA initialization"""
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        assert analysis.n_patients == len(ipd_patients)
        assert len(analysis.studies) == 3
        assert len(analysis.treatments) == 3

    def test_with_aggregate_data(self, ipd_patients):
        """Test initialization with both IPD and aggregate data"""
        aggregate = [
            AggregateStudy("AggStudy1", "Treatment A", "Control", 5.0, 1.0, 100),
            AggregateStudy("AggStudy2", "Treatment B", "Control", 7.0, 1.2, 120)
        ]

        analysis = IPDNetworkMetaAnalysis(
            ipd_data=ipd_patients,
            aggregate_data=aggregate
        )

        assert analysis.aggregate_data is not None
        assert len(analysis.aggregate_data) == 2


class TestOnStageIPDNMA:
    """Test one-stage IPD NMA"""

    def test_one_stage_basic(self, ipd_patients):
        """Test basic one-stage analysis"""
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        results = analysis.fit_one_stage()

        assert isinstance(results, IPDNMAResults)
        assert results.method == "one-stage"
        assert len(results.treatment_effects) > 0
        assert results.tau >= 0

    def test_one_stage_with_covariates(self, ipd_patients):
        """Test one-stage analysis with covariates"""
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        results = analysis.fit_one_stage(
            include_covariates=True,
            covariate_names=["age", "baseline_severity"]
        )

        assert results.covariate_effects is not None
        assert "age" in results.covariate_effects or "baseline_severity" in results.covariate_effects

    def test_treatment_effects_structure(self, ipd_patients):
        """Test treatment effects structure"""
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        results = analysis.fit_one_stage()

        for trt, (mean, se) in results.treatment_effects.items():
            assert isinstance(trt, str)
            assert isinstance(mean, float)
            assert isinstance(se, float)
            assert se > 0


class TestTwoStageIPDNMA:
    """Test two-stage IPD NMA"""

    def test_two_stage_basic(self, ipd_patients):
        """Test basic two-stage analysis"""
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        results = analysis.fit_two_stage()

        assert isinstance(results, IPDNMAResults)
        assert results.method == "two-stage"
        assert len(results.treatment_effects) > 0

    def test_two_stage_heterogeneity(self, ipd_patients):
        """Test heterogeneity estimation in two-stage"""
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        results = analysis.fit_two_stage()

        assert results.tau >= 0


class TestIPDNMAResults:
    """Test IPD NMA results"""

    def test_results_summary(self, ipd_patients):
        """Test results summary generation"""
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        results = analysis.fit_one_stage()

        summary = results.summary()

        assert isinstance(summary, str)
        assert len(summary) > 0
        assert "IPD NETWORK META-ANALYSIS" in summary

    def test_results_have_warnings(self, ipd_patients):
        """Test that warnings are included when appropriate"""
        # Create small dataset
        small_data = ipd_patients[:30]  # Very small

        analysis = IPDNetworkMetaAnalysis(ipd_data=small_data)

        results = analysis.fit_one_stage()

        # May have warnings about small sample
        assert isinstance(results.warnings, list)


# ==================== Multivariate NMA Tests ====================

class TestMultivariateNMAInitialization:
    """Test Multivariate NMA initialization"""

    def test_basic_initialization(self, multivariate_data):
        """Test basic multivariate NMA initialization"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        assert analysis.n_outcomes == 2
        assert len(analysis.outcome_names) == 2
        assert "efficacy" in analysis.outcome_names
        assert "safety" in analysis.outcome_names

    def test_treatment_extraction(self, multivariate_data):
        """Test that treatments are extracted correctly"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        assert len(analysis.treatments) > 0
        assert all(isinstance(t, str) for t in analysis.treatments)


class TestMultivariateNMAFitting:
    """Test multivariate NMA fitting"""

    def test_basic_fit(self, multivariate_data):
        """Test basic multivariate fit"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        results = analysis.fit()

        assert isinstance(results, MultivariateNMAResults)
        assert results.n_outcomes == 2

    def test_treatment_effects_structure(self, multivariate_data):
        """Test treatment effects structure for each outcome"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        results = analysis.fit()

        for outcome in results.outcome_names:
            assert outcome in results.treatment_effects
            trt_effects = results.treatment_effects[outcome]

            for trt, (mean, se) in trt_effects.items():
                assert isinstance(mean, float)
                assert isinstance(se, float)
                assert se > 0

    def test_correlation_estimation(self, multivariate_data):
        """Test between-outcome correlation estimation"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        results = analysis.fit(estimate_correlation=True)

        assert results.correlation_matrix is not None
        assert results.correlation_matrix.shape == (2, 2)

        # Diagonal should be 1
        assert np.allclose(np.diag(results.correlation_matrix), 1.0)

        # Off-diagonal should be in [-1, 1]
        off_diag = results.correlation_matrix[0, 1]
        assert -1 <= off_diag <= 1


class TestJointRankings:
    """Test joint treatment rankings across outcomes"""

    def test_joint_rankings_generated(self, multivariate_data):
        """Test that joint rankings are generated"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        results = analysis.fit()

        assert results.joint_rankings is not None
        assert isinstance(results.joint_rankings, pd.DataFrame)

    def test_rankings_structure(self, multivariate_data):
        """Test rankings dataframe structure"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        results = analysis.fit()

        rankings = results.joint_rankings

        assert "rank" in rankings.columns
        assert "treatment" in rankings.columns
        assert "utility" in rankings.columns

        # Ranks should be unique and consecutive
        ranks = sorted(rankings["rank"].tolist())
        assert ranks == list(range(1, len(ranks) + 1))


class TestMultivariateNMAResults:
    """Test multivariate NMA results"""

    def test_results_summary(self, multivariate_data):
        """Test results summary generation"""
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        results = analysis.fit()

        summary = results.summary()

        assert isinstance(summary, str)
        assert len(summary) > 0
        assert "MULTIVARIATE NMA" in summary
        assert str(results.n_outcomes) in summary


# ==================== Quick Fit Functions ====================

class TestQuickFitFunctions:
    """Test convenience quick fit functions"""

    def test_ipd_quick_fit_one_stage(self, ipd_patients):
        """Test IPD quick fit one-stage"""
        results = ipd_nma_quick_fit(
            ipd_data=ipd_patients,
            method=IPDNMAMethod.ONE_STAGE
        )

        assert isinstance(results, IPDNMAResults)
        assert results.method == "one-stage"

    def test_ipd_quick_fit_two_stage(self, ipd_patients):
        """Test IPD quick fit two-stage"""
        results = ipd_nma_quick_fit(
            ipd_data=ipd_patients,
            method=IPDNMAMethod.TWO_STAGE
        )

        assert isinstance(results, IPDNMAResults)
        assert results.method == "two-stage"

    def test_multivariate_quick_fit(self, multivariate_data):
        """Test multivariate NMA quick fit"""
        results = multivariate_nma_quick_fit(data=multivariate_data)

        assert isinstance(results, MultivariateNMAResults)


# ==================== Edge Cases ====================

class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_single_study_warning(self):
        """Test warning with single study"""
        # Single study IPD
        patients = [
            IPDPatient(f"P{i}", "Study1", "Control" if i < 25 else "Treatment",
                      50 + np.random.normal(0, 10), {})
            for i in range(50)
        ]

        analysis = IPDNetworkMetaAnalysis(ipd_data=patients)

        results = analysis.fit_one_stage()

        # Should work but may have warnings
        assert results is not None

    def test_minimal_multivariate_data(self):
        """Test with minimal multivariate data"""
        minimal_data = {
            "outcome1": [
                {"study": "S1", "treatment": "A", "effect": 0.5, "se": 0.1},
                {"study": "S1", "treatment": "B", "effect": 0.7, "se": 0.1}
            ],
            "outcome2": [
                {"study": "S1", "treatment": "A", "effect": 0.3, "se": 0.1},
                {"study": "S1", "treatment": "B", "effect": 0.4, "se": 0.1}
            ]
        }

        analysis = MultivariateNetworkMetaAnalysis(data=minimal_data)

        results = analysis.fit()

        assert results is not None
        assert results.n_outcomes == 2

    def test_large_heterogeneity(self, ipd_patients):
        """Test with large heterogeneity (high variance)"""
        # Add random noise to create heterogeneity
        for patient in ipd_patients:
            patient.outcome += np.random.normal(0, 20)

        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        results = analysis.fit_one_stage()

        # Should have high tau
        assert results.tau > 0


# ==================== Integration Tests ====================

class TestIntegration:
    """Integration tests for complete workflows"""

    def test_complete_ipd_workflow(self, ipd_patients):
        """Test complete IPD NMA workflow"""
        # Initialize
        analysis = IPDNetworkMetaAnalysis(ipd_data=ipd_patients)

        # Fit one-stage with covariates
        results_1stage = analysis.fit_one_stage(
            include_covariates=True,
            covariate_names=["age"]
        )

        # Verify results
        assert results_1stage.method == "one-stage"
        assert len(results_1stage.treatment_effects) > 0
        assert results_1stage.covariate_effects is not None

        # Summary
        summary = results_1stage.summary()
        assert len(summary) > 0

    def test_complete_multivariate_workflow(self, multivariate_data):
        """Test complete multivariate NMA workflow"""
        # Initialize
        analysis = MultivariateNetworkMetaAnalysis(data=multivariate_data)

        # Fit with correlation estimation
        results = analysis.fit(estimate_correlation=True)

        # Verify results
        assert results.n_outcomes == 2
        assert results.correlation_matrix is not None
        assert results.joint_rankings is not None

        # Summary
        summary = results.summary()
        assert len(summary) > 0
        assert "MULTIVARIATE NMA" in summary


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
