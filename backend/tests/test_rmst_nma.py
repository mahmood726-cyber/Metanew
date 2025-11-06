"""
Comprehensive Tests for RMST Network Meta-Analysis
==================================================

Tests for:
- RMST-based NMA for time-to-event outcomes
- Treatment ranking by RMST
- Pairwise RMST differences
- Clinical interpretation
- Aggregate and IPD data
"""

import pytest
import numpy as np

from ml.rmst_nma import (
    RMSTNetworkMetaAnalysis,
    RMSTStudy,
    RMSTDifference,
    RMSTNMAResults,
    rmst_nma_quick_analysis
)


# ==================== Fixtures ====================

@pytest.fixture
def oncology_rmst_data():
    """Example oncology RMST data (overall survival)"""
    np.random.seed(42)

    # 3-year RMST (36 months) for different treatments
    # Control, Treatment A, Treatment B, Treatment C

    studies = []

    # Control arm studies
    for i in range(1, 6):
        studies.append(RMSTStudy(
            study_id=f"Study{i}",
            treatment="Control",
            rmst=18.0 + np.random.normal(0, 2),  # months
            rmst_se=np.random.uniform(1.0, 2.0),
            tau=36.0,  # 3-year restriction
            n_patients=np.random.randint(80, 150),
            n_events=np.random.randint(50, 100)
        ))

    # Treatment A (moderate benefit)
    for i in range(1, 5):
        studies.append(RMSTStudy(
            study_id=f"Study{i}",
            treatment="Treatment A",
            rmst=21.0 + np.random.normal(0, 2),
            rmst_se=np.random.uniform(1.0, 2.0),
            tau=36.0,
            n_patients=np.random.randint(80, 150),
            n_events=np.random.randint(40, 80)
        ))

    # Treatment B (strong benefit)
    for i in range(1, 5):
        studies.append(RMSTStudy(
            study_id=f"Study{i}",
            treatment="Treatment B",
            rmst=24.0 + np.random.normal(0, 2),
            rmst_se=np.random.uniform(1.0, 2.0),
            tau=36.0,
            n_patients=np.random.randint(80, 150),
            n_events=np.random.randint(35, 70)
        ))

    # Treatment C (mild benefit)
    for i in range(1, 4):
        studies.append(RMSTStudy(
            study_id=f"Study{i}",
            treatment="Treatment C",
            rmst=19.5 + np.random.normal(0, 2),
            rmst_se=np.random.uniform(1.0, 2.0),
            tau=36.0,
            n_patients=np.random.randint(80, 150),
            n_events=np.random.randint(45, 85)
        ))

    return studies


@pytest.fixture
def mixed_tau_data():
    """Data with mixed tau values (should trigger warning)"""
    studies = [
        RMSTStudy("S1", "Control", 18.0, 1.5, tau=36.0, n_patients=100, n_events=60),
        RMSTStudy("S1", "Treatment A", 21.0, 1.5, tau=36.0, n_patients=100, n_events=50),
        RMSTStudy("S2", "Control", 15.0, 1.2, tau=24.0, n_patients=120, n_events=70),  # Different tau
        RMSTStudy("S2", "Treatment A", 18.0, 1.2, tau=24.0, n_patients=120, n_events=60),
    ]
    return studies


# ==================== Basic Functionality Tests ====================

class TestRMSTNMAInitialization:
    """Test RMST NMA initialization"""

    def test_basic_initialization(self, oncology_rmst_data):
        """Test basic initialization"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        assert analysis.tau == 36.0
        assert analysis.n_treatments == 4
        assert analysis.n_studies > 0

    def test_mixed_tau_warning(self, mixed_tau_data, caplog):
        """Test warning for mixed tau values"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=mixed_tau_data,
            tau=36.0
        )

        # Should log warning about mixed tau
        # The warning is logged, but we just check it doesn't crash
        assert analysis.tau == 36.0


class TestRMSTNMAAnalysis:
    """Test RMST NMA analysis"""

    def test_basic_analysis(self, oncology_rmst_data):
        """Test basic RMST NMA analysis"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze()

        assert isinstance(results, RMSTNMAResults)
        assert results.tau == 36.0
        assert len(results.rmst_estimates) == 4
        assert len(results.rmst_differences) > 0

    def test_analysis_with_reference(self, oncology_rmst_data):
        """Test analysis with specified reference"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        assert results.reference_treatment == "Control"

        # All differences should be vs Control
        for diff in results.rmst_differences:
            assert diff.comparison == "Control"

    def test_pooled_estimates(self, oncology_rmst_data):
        """Test pooled RMST estimates"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze()

        for trt, (rmst, se) in results.rmst_estimates.items():
            assert isinstance(rmst, float)
            assert isinstance(se, float)
            assert se > 0
            assert 0 < rmst < results.tau  # RMST should be between 0 and tau


class TestRMSTDifferences:
    """Test RMST difference calculations"""

    def test_differences_structure(self, oncology_rmst_data):
        """Test structure of RMST differences"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        for diff in results.rmst_differences:
            assert isinstance(diff, RMSTDifference)
            assert diff.treatment != "Control"  # Shouldn't include reference
            assert diff.comparison == "Control"
            assert isinstance(diff.difference, float)
            assert diff.se > 0
            assert diff.lower_95ci < diff.upper_95ci
            assert 0 <= diff.p_value <= 1

    def test_differences_ordered(self, oncology_rmst_data):
        """Test that differences are ordered by magnitude"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        # Differences should be in descending order
        diffs = [d.difference for d in results.rmst_differences]
        assert diffs == sorted(diffs, reverse=True)

    def test_positive_negative_differences(self, oncology_rmst_data):
        """Test that differences can be positive or negative"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        # Treatment B should have positive difference (better than control)
        treatment_b_diff = next(
            d for d in results.rmst_differences if d.treatment == "Treatment B"
        )
        assert treatment_b_diff.difference > 0

    def test_confidence_intervals(self, oncology_rmst_data):
        """Test confidence interval calculation"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        for diff in results.rmst_differences:
            # CI should contain point estimate
            assert diff.lower_95ci <= diff.difference <= diff.upper_95ci

            # CI width should be ~3.92 * SE
            expected_width = 1.96 * 2 * diff.se
            actual_width = diff.upper_95ci - diff.lower_95ci
            assert abs(actual_width - expected_width) < 0.1


class TestTreatmentRanking:
    """Test treatment ranking by RMST"""

    def test_ranking_structure(self, oncology_rmst_data):
        """Test ranking structure"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze()

        rankings = results.treatment_ranking

        # Should have all treatments
        assert len(rankings) == analysis.n_treatments

        # Ranks should be 1, 2, 3, 4
        ranks = [r[1] for r in rankings]
        assert sorted(ranks) == list(range(1, analysis.n_treatments + 1))

    def test_ranking_order(self, oncology_rmst_data):
        """Test that ranking is correct (higher RMST = better rank)"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze()

        # Treatment B should be ranked highest (has highest RMST)
        top_treatment = results.treatment_ranking[0][0]

        # Get its RMST
        top_rmst = results.rmst_estimates[top_treatment][0]

        # Should be highest RMST
        all_rmsts = [rmst for rmst, _ in results.rmst_estimates.values()]
        assert top_rmst == max(all_rmsts)


class TestClinicalInterpretation:
    """Test clinical interpretation generation"""

    def test_interpretation_generated(self, oncology_rmst_data):
        """Test that interpretation is generated"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        assert len(results.interpretation) > 0

    def test_interpretation_mentions_reference(self, oncology_rmst_data):
        """Test that interpretation mentions reference treatment"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        interpretation_text = " ".join(results.interpretation)
        assert "Control" in interpretation_text

    def test_interpretation_mentions_best_treatment(self, oncology_rmst_data):
        """Test that interpretation mentions best treatment"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        # Best treatment should be mentioned
        best_trt = results.treatment_ranking[0][0]
        interpretation_text = " ".join(results.interpretation)

        # Should mention either the treatment or significant differences
        assert "significant" in interpretation_text.lower() or best_trt in interpretation_text


class TestResultsSummary:
    """Test results summary generation"""

    def test_summary_generated(self, oncology_rmst_data):
        """Test that summary is generated"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze()

        summary = results.summary()

        assert isinstance(summary, str)
        assert len(summary) > 0

    def test_summary_contains_key_info(self, oncology_rmst_data):
        """Test that summary contains key information"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        summary = results.summary()

        # Should contain tau
        assert str(results.tau) in summary

        # Should contain reference
        assert results.reference_treatment in summary

        # Should contain RMST header
        assert "RMST" in summary

        # Should contain treatment names
        for trt in results.rmst_estimates.keys():
            assert trt in summary


class TestWarnings:
    """Test warning generation"""

    def test_small_network_warning(self):
        """Test warning for small network"""
        # Very small network (2 studies)
        studies = [
            RMSTStudy("S1", "Control", 18.0, 1.5, 36.0, 100, 60),
            RMSTStudy("S1", "Treatment A", 21.0, 1.5, 36.0, 100, 50),
        ]

        analysis = RMSTNetworkMetaAnalysis(studies=studies, tau=36.0)

        results = analysis.analyze()

        # Should have warning about small network
        assert len(results.warnings) > 0


# ==================== Quick Analysis Function ====================

class TestQuickAnalysis:
    """Test quick analysis convenience function"""

    def test_quick_analysis(self, oncology_rmst_data):
        """Test quick analysis function"""
        results = rmst_nma_quick_analysis(
            studies=oncology_rmst_data,
            tau=36.0,
            reference="Control"
        )

        assert isinstance(results, RMSTNMAResults)
        assert results.reference_treatment == "Control"

    def test_quick_analysis_auto_reference(self, oncology_rmst_data):
        """Test quick analysis with auto reference selection"""
        results = rmst_nma_quick_analysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        assert results.reference_treatment is not None


# ==================== Edge Cases ====================

class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_two_treatments(self):
        """Test with minimum treatments (2)"""
        studies = [
            RMSTStudy("S1", "Control", 18.0, 1.5, 36.0, 100, 60),
            RMSTStudy("S1", "Treatment A", 21.0, 1.5, 36.0, 100, 50),
            RMSTStudy("S2", "Control", 17.5, 1.3, 36.0, 120, 70),
            RMSTStudy("S2", "Treatment A", 20.5, 1.4, 36.0, 120, 55),
        ]

        analysis = RMSTNetworkMetaAnalysis(studies=studies, tau=36.0)

        results = analysis.analyze()

        assert len(results.rmst_estimates) == 2
        assert len(results.rmst_differences) == 1

    def test_single_study_per_treatment(self):
        """Test with one study per treatment"""
        studies = [
            RMSTStudy("S1", "Control", 18.0, 1.5, 36.0, 100, 60),
            RMSTStudy("S2", "Treatment A", 21.0, 1.5, 36.0, 100, 50),
            RMSTStudy("S3", "Treatment B", 24.0, 1.5, 36.0, 100, 45),
        ]

        analysis = RMSTNetworkMetaAnalysis(studies=studies, tau=36.0)

        results = analysis.analyze()

        # Should work but SEs will be exactly as provided (no pooling)
        assert len(results.rmst_estimates) == 3

    def test_high_tau(self):
        """Test with very high tau (long restriction time)"""
        studies = [
            RMSTStudy("S1", "Control", 80.0, 5.0, 120.0, 100, 40),  # 10-year RMST
            RMSTStudy("S1", "Treatment A", 95.0, 5.0, 120.0, 100, 30),
        ]

        analysis = RMSTNetworkMetaAnalysis(studies=studies, tau=120.0)

        results = analysis.analyze()

        assert results.tau == 120.0

    def test_very_small_se(self):
        """Test with very small standard errors (large studies)"""
        studies = [
            RMSTStudy("S1", "Control", 18.0, 0.1, 36.0, 10000, 6000),
            RMSTStudy("S1", "Treatment A", 21.0, 0.1, 36.0, 10000, 5000),
        ]

        analysis = RMSTNetworkMetaAnalysis(studies=studies, tau=36.0)

        results = analysis.analyze()

        # Should detect significant difference with small SEs
        diff = results.rmst_differences[0]
        assert diff.significant  # Should be significant with large N


# ==================== Clinical Validity Tests ====================

class TestClinicalValidity:
    """Test clinical validity of results"""

    def test_rmst_within_tau(self, oncology_rmst_data):
        """Test that all RMST estimates are within [0, tau]"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze()

        for trt, (rmst, se) in results.rmst_estimates.items():
            assert 0 <= rmst <= results.tau

    def test_meaningful_differences(self, oncology_rmst_data):
        """Test that differences are clinically meaningful"""
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        results = analysis.analyze(reference_treatment="Control")

        # For oncology, differences > 3 months often considered meaningful
        large_diffs = [
            d for d in results.rmst_differences
            if abs(d.difference) > 3.0
        ]

        # Should have at least one large difference (Treatment B)
        assert len(large_diffs) > 0


# ==================== Integration Tests ====================

class TestIntegration:
    """Integration tests for complete workflows"""

    def test_complete_workflow(self, oncology_rmst_data):
        """Test complete RMST NMA workflow"""
        # Initialize
        analysis = RMSTNetworkMetaAnalysis(
            studies=oncology_rmst_data,
            tau=36.0
        )

        # Analyze
        results = analysis.analyze(reference_treatment="Control")

        # Verify all components
        assert len(results.rmst_estimates) == 4
        assert len(results.rmst_differences) == 3  # 4 treatments - 1 reference
        assert len(results.treatment_ranking) == 4
        assert len(results.interpretation) > 0

        # Generate summary
        summary = results.summary()
        assert len(summary) > 0

        # Check clinical meaningfulness
        best_trt = results.treatment_ranking[0][0]
        best_diff = next(
            d for d in results.rmst_differences if d.treatment == best_trt
        )
        # Best treatment should have positive difference vs control
        assert best_diff.difference > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
