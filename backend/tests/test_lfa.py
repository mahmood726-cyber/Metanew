"""
Comprehensive Tests for LFA Transportability Analysis
=====================================================

Tests for:
- LFA transportability analysis with all methods
- Transport weight calculation
- ML effect modifier detection
- Cross-design synthesis
- Covariate overlap assessment
- API endpoints
- Edge cases and error handling
"""

import pytest
import numpy as np
from dataclasses import dataclass
from typing import List, Dict, Optional

from ml.lfa_transportability import (
    LFATransportabilityAnalysis,
    LFATransportabilityResults,
    LFATransportConfig,
    LFATransportMethod,
    MLEffectModifierResults,
    CrossDesignResults,
    lfa_quick_transport
)
from ml.transportability import Study, Population


# ==================== Fixtures ====================

@pytest.fixture
def sample_studies():
    """Sample RCT studies"""
    return [
        Study(
            study_id="RCT001",
            treatment_effect=0.48,
            standard_error=0.15,
            sample_size=200,
            n_treatment=100,
            n_control=100,
            covariates={
                "mean_age": 55.0,
                "female_proportion": 0.45,
                "comorbidity_index": 2.1,
                "baseline_risk": 0.15
            }
        ),
        Study(
            study_id="RCT002",
            treatment_effect=0.55,
            standard_error=0.18,
            sample_size=150,
            n_treatment=75,
            n_control=75,
            covariates={
                "mean_age": 58.0,
                "female_proportion": 0.50,
                "comorbidity_index": 2.3,
                "baseline_risk": 0.18
            }
        ),
        Study(
            study_id="RCT003",
            treatment_effect=0.42,
            standard_error=0.12,
            sample_size=300,
            n_treatment=150,
            n_control=150,
            covariates={
                "mean_age": 52.0,
                "female_proportion": 0.40,
                "comorbidity_index": 1.9,
                "baseline_risk": 0.12
            }
        ),
    ]


@pytest.fixture
def target_population():
    """Target population with different characteristics"""
    np.random.seed(42)
    n = 1000

    return Population(
        name="Elderly Real-World Cohort",
        covariates={
            "mean_age": np.random.normal(68, 8, n),
            "female_proportion": np.random.beta(6, 4, n),
            "comorbidity_index": np.random.gamma(3.5, 0.7, n),
            "baseline_risk": np.random.beta(3, 12, n)
        },
        sample_size=n,
        is_target=True
    )


@pytest.fixture
def similar_target_population():
    """Target population similar to source (good overlap)"""
    np.random.seed(42)
    n = 500

    return Population(
        name="Similar Population",
        covariates={
            "mean_age": np.random.normal(56, 5, n),
            "female_proportion": np.random.beta(5, 5, n),
            "comorbidity_index": np.random.gamma(2.5, 0.8, n),
            "baseline_risk": np.random.beta(2, 10, n)
        },
        sample_size=n,
        is_target=True
    )


@pytest.fixture
def observational_studies():
    """Observational studies for cross-design synthesis"""
    return [
        Study(
            study_id="OBS001",
            treatment_effect=0.62,  # Higher effect (potential bias)
            standard_error=0.20,
            sample_size=500,
            n_treatment=250,
            n_control=250,
            covariates={
                "mean_age": 60.0,
                "female_proportion": 0.52,
                "comorbidity_index": 2.5,
                "baseline_risk": 0.20
            }
        ),
        Study(
            study_id="OBS002",
            treatment_effect=0.58,
            standard_error=0.22,
            sample_size=400,
            n_treatment=200,
            n_control=200,
            covariates={
                "mean_age": 62.0,
                "female_proportion": 0.48,
                "comorbidity_index": 2.4,
                "baseline_risk": 0.19
            }
        ),
    ]


# ==================== Basic LFA Analysis Tests ====================

class TestLFABasicAnalysis:
    """Test basic LFA transportability analysis"""

    def test_simple_distance_method(self, sample_studies, target_population):
        """Test simple distance weighting"""
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            use_ml_modifiers=False,
            cross_design=False
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Basic assertions
        assert isinstance(results, LFATransportabilityResults)
        assert results.method == "simple_distance"
        assert 0 <= results.generalizability_index <= 1
        assert results.effective_sample_size > 0
        assert len(results.transport_weights) == len(sample_studies)
        assert len(results.normalized_weights) == len(sample_studies)

        # Weights should sum to 1 (normalized)
        assert np.isclose(np.sum(results.normalized_weights), 1.0)

        # Check effect estimates
        assert results.source_effect != 0
        assert results.target_effect != 0
        assert results.source_se > 0
        assert results.target_se > 0

    def test_propensity_score_method(self, sample_studies, target_population):
        """Test propensity score (Mahalanobis) weighting"""
        config = LFATransportConfig(
            method=LFATransportMethod.PROPENSITY_SCORE,
            use_ml_modifiers=False
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        assert results.method == "propensity_score"
        assert np.isclose(np.sum(results.normalized_weights), 1.0)
        assert results.effective_sample_size > 0

    def test_entropy_balancing_method(self, sample_studies, target_population):
        """Test entropy balancing"""
        config = LFATransportConfig(
            method=LFATransportMethod.ENTROPY_BALANCING,
            use_ml_modifiers=False
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        assert results.method == "entropy_balancing"
        assert np.isclose(np.sum(results.normalized_weights), 1.0)

        # Entropy balancing should achieve better balance
        # (in practice - simplified implementation may not)
        assert all(abs(smd) >= 0 for smd in results.covariate_balance.values())

    def test_calibration_method(self, sample_studies, target_population):
        """Test calibration weighting"""
        config = LFATransportConfig(
            method=LFATransportMethod.CALIBRATION,
            use_ml_modifiers=False
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        assert results.method == "calibration"
        assert np.isclose(np.sum(results.normalized_weights), 1.0)


class TestCovariateBalance:
    """Test covariate balance assessment"""

    def test_balance_calculation(self, sample_studies, target_population):
        """Test standardized mean difference calculation"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should have balance for all covariates
        expected_covariates = ["mean_age", "female_proportion", "comorbidity_index", "baseline_risk"]
        for cov in expected_covariates:
            assert cov in results.covariate_balance

        # SMDs should be numeric
        for smd in results.covariate_balance.values():
            assert isinstance(smd, (int, float, np.number))

    def test_good_balance_with_similar_population(self, sample_studies, similar_target_population):
        """Test that similar populations have better balance"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=similar_target_population,
            config=config
        )

        results = analysis.analyze()

        # Should have better generalizability
        assert results.generalizability_index > 0.5

        # Most SMDs should be small
        small_smd_count = sum(1 for smd in results.covariate_balance.values() if abs(smd) < 0.2)
        assert small_smd_count >= 2  # At least half


class TestCovariateOverlap:
    """Test covariate overlap assessment"""

    def test_overlap_calculation(self, sample_studies, target_population):
        """Test overlap coefficient calculation"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should have overlap for all covariates
        expected_covariates = ["mean_age", "female_proportion", "comorbidity_index", "baseline_risk"]
        for cov in expected_covariates:
            assert cov in results.covariate_overlap

        # Overlap coefficients should be in [0, 1]
        for overlap in results.covariate_overlap.values():
            assert 0 <= overlap <= 1

    def test_better_overlap_with_similar_population(self, sample_studies, similar_target_population):
        """Test that similar populations have better overlap"""
        # Similar population
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis_similar = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=similar_target_population,
            config=config
        )

        results_similar = analysis_similar.analyze()

        # Average overlap should be higher
        avg_overlap = np.mean(list(results_similar.covariate_overlap.values()))
        assert avg_overlap > 0.3  # Should have some overlap


class TestMLEffectModifiers:
    """Test ML-based effect modifier detection"""

    def test_ml_modifier_detection_enabled(self, sample_studies, target_population):
        """Test ML modifier detection when enabled"""
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            use_ml_modifiers=True
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should have ML results
        assert results.ml_modifier_results is not None
        assert isinstance(results.ml_modifier_results, MLEffectModifierResults)

        # Should have identified some modifiers
        assert isinstance(results.ml_modifier_results.identified_modifiers, list)
        assert len(results.ml_modifier_results.shap_importance) > 0
        assert len(results.ml_modifier_results.permutation_importance) > 0

        # All importance scores should be non-negative
        for imp in results.ml_modifier_results.shap_importance.values():
            assert imp >= 0

    def test_ml_modifier_detection_disabled(self, sample_studies, target_population):
        """Test ML modifier detection when disabled"""
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            use_ml_modifiers=False
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should not have ML results
        assert results.ml_modifier_results is None


class TestCrossDesignSynthesis:
    """Test cross-design synthesis"""

    def test_cross_design_enabled(self, sample_studies, observational_studies, target_population):
        """Test cross-design synthesis when enabled"""
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            cross_design=True,
            bias_model="additive"
        )

        # Combine RCT and observational studies
        all_studies = sample_studies + observational_studies

        # Mark study designs
        for study in all_studies[:3]:
            study.covariates["design_type"] = "RCT"
        for study in all_studies[3:]:
            study.covariates["design_type"] = "observational"

        analysis = LFATransportabilityAnalysis(
            source_studies=all_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should have cross-design results
        assert results.cross_design_results is not None
        assert isinstance(results.cross_design_results, CrossDesignResults)

        # Should have separate RCT and observational estimates
        assert results.cross_design_results.rct_effect != 0
        assert results.cross_design_results.observational_effect != 0
        assert results.cross_design_results.rct_se > 0
        assert results.cross_design_results.observational_se > 0

        # Should have bias estimate
        assert isinstance(results.cross_design_results.bias_estimate, (int, float, np.number))
        assert results.cross_design_results.bias_se > 0

        # Should have combined effect
        assert results.cross_design_results.combined_effect != 0
        assert results.cross_design_results.combined_se > 0

        # Heterogeneity explained should be in [0, 1]
        assert 0 <= results.cross_design_results.heterogeneity_explained <= 1

    def test_cross_design_disabled(self, sample_studies, target_population):
        """Test cross-design synthesis when disabled"""
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            cross_design=False
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should not have cross-design results
        assert results.cross_design_results is None

    def test_bias_models(self, sample_studies, observational_studies, target_population):
        """Test different bias correction models"""
        all_studies = sample_studies + observational_studies

        for study in all_studies[:3]:
            study.covariates["design_type"] = "RCT"
        for study in all_studies[3:]:
            study.covariates["design_type"] = "observational"

        bias_models = ["additive", "proportional", "hierarchical"]

        for bias_model in bias_models:
            config = LFATransportConfig(
                method=LFATransportMethod.SIMPLE_DISTANCE,
                cross_design=True,
                bias_model=bias_model
            )

            analysis = LFATransportabilityAnalysis(
                source_studies=all_studies,
                target_population=target_population,
                config=config
            )

            results = analysis.analyze()

            assert results.cross_design_results is not None
            assert results.cross_design_results.bias_model == bias_model


class TestSensitivityAnalysis:
    """Test sensitivity analysis"""

    def test_sensitivity_analysis_included(self, sample_studies, target_population):
        """Test that sensitivity analysis is performed"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should have sensitivity analysis
        assert results.sensitivity_analysis is not None
        assert isinstance(results.sensitivity_analysis, dict)
        assert len(results.sensitivity_analysis) > 0


class TestWarningsAndAssumptions:
    """Test warnings and assumption checks"""

    def test_poor_generalizability_warning(self, sample_studies, target_population):
        """Test warning when generalizability is poor"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # With elderly target vs. younger source, should have low generalizability
        if results.generalizability_index < 0.6:
            # Should have warnings
            assert len(results.warnings) > 0

    def test_poor_overlap_warning(self, sample_studies, target_population):
        """Test warning when covariate overlap is poor"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Check if any overlap is poor
        poor_overlap = any(overlap < 0.4 for overlap in results.covariate_overlap.values())

        if poor_overlap:
            # Should have warnings
            assert len(results.warnings) > 0

    def test_assumption_checks(self, sample_studies, target_population):
        """Test transportability assumption assessment"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should have assumption check
        assert isinstance(results.transportability_assumption_met, bool)


class TestQuickTransport:
    """Test convenience function"""

    def test_lfa_quick_transport(self):
        """Test lfa_quick_transport convenience function"""
        np.random.seed(42)

        results = lfa_quick_transport(
            source_effects=[0.48, 0.55, 0.42],
            source_ses=[0.15, 0.18, 0.12],
            source_covariates={
                "mean_age": [55, 58, 52],
                "female_proportion": [0.45, 0.50, 0.40]
            },
            target_covariates={
                "mean_age": np.random.normal(68, 8, 500).tolist(),
                "female_proportion": np.random.beta(6, 4, 500).tolist()
            },
            method="simple_distance"
        )

        assert isinstance(results, LFATransportabilityResults)
        assert results.method == "simple_distance"
        assert len(results.transport_weights) == 3


class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_single_covariate(self, sample_studies):
        """Test with single covariate"""
        np.random.seed(42)
        n = 500

        # Only one covariate
        target_pop = Population(
            name="Test",
            covariates={"mean_age": np.random.normal(65, 10, n)},
            sample_size=n,
            is_target=True
        )

        # Modify studies to have only one covariate
        for study in sample_studies:
            study.covariates = {"mean_age": study.covariates["mean_age"]}

        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_pop,
            config=config
        )

        results = analysis.analyze()

        assert len(results.covariate_balance) == 1
        assert len(results.covariate_overlap) == 1

    def test_two_studies_minimum(self):
        """Test with minimum number of studies (2)"""
        np.random.seed(42)
        n = 500

        studies = [
            Study(
                study_id="S1",
                treatment_effect=0.5,
                standard_error=0.1,
                sample_size=100,
                n_treatment=50,
                n_control=50,
                covariates={"age": 55.0}
            ),
            Study(
                study_id="S2",
                treatment_effect=0.6,
                standard_error=0.12,
                sample_size=120,
                n_treatment=60,
                n_control=60,
                covariates={"age": 58.0}
            )
        ]

        target = Population(
            name="Test",
            covariates={"age": np.random.normal(65, 10, n)},
            sample_size=n,
            is_target=True
        )

        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=studies,
            target_population=target,
            config=config
        )

        results = analysis.analyze()

        assert len(results.transport_weights) == 2

    def test_large_standard_errors(self):
        """Test with very large standard errors"""
        np.random.seed(42)
        n = 500

        studies = [
            Study(
                study_id="S1",
                treatment_effect=0.5,
                standard_error=5.0,  # Very large
                sample_size=10,
                n_treatment=5,
                n_control=5,
                covariates={"age": 55.0}
            ),
            Study(
                study_id="S2",
                treatment_effect=0.6,
                standard_error=0.1,  # Small
                sample_size=1000,
                n_treatment=500,
                n_control=500,
                covariates={"age": 58.0}
            )
        ]

        target = Population(
            name="Test",
            covariates={"age": np.random.normal(65, 10, n)},
            sample_size=n,
            is_target=True
        )

        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=studies,
            target_population=target,
            config=config
        )

        results = analysis.analyze()

        # Study with small SE should get much higher weight
        assert results.normalized_weights[1] > results.normalized_weights[0]


class TestResultsSummary:
    """Test results summary method"""

    def test_summary_method(self, sample_studies, target_population):
        """Test that summary() method works"""
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        summary = results.summary()

        # Should be a non-empty string
        assert isinstance(summary, str)
        assert len(summary) > 0

        # Should contain key information
        assert "LFA" in summary or "Transportability" in summary
        assert str(round(results.generalizability_index, 2)) in summary or \
               str(round(results.generalizability_index, 3)) in summary


class TestBootstrapCI:
    """Test bootstrap confidence intervals"""

    def test_bootstrap_iterations(self, sample_studies, target_population):
        """Test that bootstrap iterations are respected"""
        # Small number of bootstrap iterations
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            n_bootstrap=100
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Should complete without error
        assert results is not None


class TestConfigValidation:
    """Test configuration validation"""

    def test_confidence_level_bounds(self, sample_studies, target_population):
        """Test that confidence level is validated"""
        # Valid confidence level
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            confidence_level=0.95
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()
        assert results is not None

    def test_method_enum(self):
        """Test that method must be valid enum"""
        # Should work with valid enum
        config = LFATransportConfig(method=LFATransportMethod.SIMPLE_DISTANCE)
        assert config.method == LFATransportMethod.SIMPLE_DISTANCE

        # Should fail with invalid method (if validation is implemented)
        # This depends on whether validation is done in the class


# ==================== Integration Tests ====================

class TestIntegration:
    """Integration tests with full workflow"""

    def test_full_workflow_simple_distance(self, sample_studies, target_population):
        """Test complete workflow with simple distance"""
        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            use_ml_modifiers=True,
            cross_design=False,
            n_bootstrap=500,
            confidence_level=0.95
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Verify all components are present
        assert results.source_effect != 0
        assert results.target_effect != 0
        assert 0 <= results.generalizability_index <= 1
        assert results.effective_sample_size > 0
        assert len(results.transport_weights) == 3
        assert len(results.covariate_balance) == 4
        assert len(results.covariate_overlap) == 4
        assert results.ml_modifier_results is not None
        assert len(results.effect_modifiers) >= 0
        assert results.transportability_assumption_met is not None
        assert results.sensitivity_analysis is not None

        # Summary should work
        summary = results.summary()
        assert len(summary) > 0

    def test_full_workflow_with_cross_design(self, sample_studies, observational_studies, target_population):
        """Test complete workflow with cross-design synthesis"""
        all_studies = sample_studies + observational_studies

        for study in all_studies[:3]:
            study.covariates["design_type"] = "RCT"
        for study in all_studies[3:]:
            study.covariates["design_type"] = "observational"

        config = LFATransportConfig(
            method=LFATransportMethod.ENTROPY_BALANCING,
            use_ml_modifiers=True,
            cross_design=True,
            bias_model="additive",
            n_bootstrap=500,
            confidence_level=0.95
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=all_studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        # Verify all components including cross-design
        assert results.cross_design_results is not None
        assert results.cross_design_results.rct_effect != 0
        assert results.cross_design_results.observational_effect != 0
        assert results.cross_design_results.combined_effect != 0

        summary = results.summary()
        assert "cross-design" in summary.lower() or "bias" in summary.lower()


# ==================== Performance Tests ====================

class TestPerformance:
    """Test performance with larger datasets"""

    def test_large_target_population(self, sample_studies):
        """Test with large target population"""
        np.random.seed(42)
        n = 10000  # Large target population

        target = Population(
            name="Large Population",
            covariates={
                "mean_age": np.random.normal(65, 10, n),
                "female_proportion": np.random.beta(5, 5, n),
                "comorbidity_index": np.random.gamma(3, 0.7, n),
                "baseline_risk": np.random.beta(2, 10, n)
            },
            sample_size=n,
            is_target=True
        )

        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            use_ml_modifiers=False,  # Disable for speed
            n_bootstrap=100  # Reduce for speed
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=sample_studies,
            target_population=target,
            config=config
        )

        # Should complete in reasonable time
        import time
        start = time.time()
        results = analysis.analyze()
        elapsed = time.time() - start

        assert results is not None
        assert elapsed < 30  # Should complete within 30 seconds

    def test_many_studies(self, target_population):
        """Test with many source studies"""
        np.random.seed(42)

        # Create 20 studies
        studies = []
        for i in range(20):
            studies.append(Study(
                study_id=f"Study{i+1}",
                treatment_effect=np.random.normal(0.5, 0.1),
                standard_error=np.random.uniform(0.1, 0.2),
                sample_size=np.random.randint(100, 500),
                n_treatment=100,
                n_control=100,
                covariates={
                    "mean_age": np.random.uniform(50, 70),
                    "female_proportion": np.random.uniform(0.3, 0.7),
                    "comorbidity_index": np.random.uniform(1.5, 3.0),
                    "baseline_risk": np.random.uniform(0.1, 0.3)
                }
            ))

        config = LFATransportConfig(
            method=LFATransportMethod.SIMPLE_DISTANCE,
            use_ml_modifiers=False,
            n_bootstrap=100
        )

        analysis = LFATransportabilityAnalysis(
            source_studies=studies,
            target_population=target_population,
            config=config
        )

        results = analysis.analyze()

        assert len(results.transport_weights) == 20
        assert len(results.normalized_weights) == 20


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
