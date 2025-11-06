"""
Comprehensive Tests for Component Network Meta-Analysis
========================================================

Tests for:
- Component NMA with additive models
- Component NMA with interactions
- Treatment prediction
- Dismantling analysis
- Optimal treatment design
- Component contribution analysis
- Edge cases and validation
"""

import pytest
import numpy as np
from dataclasses import dataclass

from ml.component_nma import (
    ComponentNMAAnalysis,
    CNMAStudy,
    CNMAEngine,
    CNMAResults,
    ComponentEffect,
    ComponentContribution,
    TreatmentPrediction,
    DismantlingAnalysis,
    OptimalTreatmentDesign,
    create_component_matrix_from_dict,
    cnma_quick_fit
)


# ==================== Fixtures ====================

@pytest.fixture
def smoking_cessation_components():
    """Example: Smoking cessation intervention components"""
    return {
        "Control": [],
        "Self-help": ["Written materials"],
        "Brief advice": ["Counseling"],
        "Individual counseling": ["Counseling", "Individual sessions"],
        "Group therapy": ["Counseling", "Group sessions"],
        "NRT": ["Pharmacotherapy"],
        "Counseling + NRT": ["Counseling", "Pharmacotherapy"],
        "Group + NRT": ["Counseling", "Group sessions", "Pharmacotherapy"]
    }


@pytest.fixture
def smoking_studies(smoking_cessation_components):
    """Generate example smoking cessation studies"""
    np.random.seed(42)

    studies = []
    treatments = list(smoking_cessation_components.keys())
    active_treatments = [t for t in treatments if t != "Control"]

    # Component effects (ground truth for simulation)
    component_effects = {
        "Written materials": 0.3,
        "Counseling": 0.5,
        "Individual sessions": 0.2,
        "Group sessions": 0.3,
        "Pharmacotherapy": 0.6
    }

    study_id = 1
    for trt in active_treatments:
        n_studies = np.random.randint(3, 6)

        for _ in range(n_studies):
            # Calculate true effect based on components
            components = smoking_cessation_components[trt]
            true_effect = sum(component_effects.get(c, 0) for c in components)

            # Add noise
            effect = true_effect + np.random.normal(0, 0.2)
            se = np.random.uniform(0.15, 0.35)

            studies.append(CNMAStudy(
                study_id=f"Study{study_id}",
                treatment_arm=trt,
                comparison_arm="Control",
                effect_size=effect,
                standard_error=se,
                sample_size=np.random.randint(100, 500)
            ))

            study_id += 1

    return studies


@pytest.fixture
def component_matrix(smoking_cessation_components):
    """Create component matrix"""
    matrix, comp_names, trt_names = create_component_matrix_from_dict(
        smoking_cessation_components
    )
    return matrix, comp_names, trt_names


# ==================== Basic Functionality Tests ====================

class TestComponentNMABasics:
    """Test basic Component NMA functionality"""

    def test_initialization(self, smoking_studies, component_matrix):
        """Test ComponentNMAAnalysis initialization"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        assert analysis.n_studies == len(smoking_studies)
        assert analysis.n_treatments == len(trt_names)
        assert analysis.n_components == len(comp_names)

    def test_frequentist_additive_model(self, smoking_studies, component_matrix):
        """Test frequentist additive model"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        assert isinstance(results, CNMAResults)
        assert results.model_type == "additive"
        assert results.engine == "freq"
        assert len(results.component_effects) == len(comp_names)
        assert len(results.component_contributions) == len(comp_names)

    def test_bayesian_additive_model(self, smoking_studies, component_matrix):
        """Test Bayesian additive model"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.BAYESIAN)

        assert results.model_type == "additive"
        assert results.engine == "bayes"
        assert results.tau > 0

    def test_additive_with_interactions(self, smoking_studies, component_matrix):
        """Test additive model with component interactions"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(
            engine=CNMAEngine.FREQUENTIST,
            include_interactions=True
        )

        assert results.model_type == "additive_with_interactions"
        assert len(results.interaction_effects) > 0


class TestComponentEffects:
    """Test component effect estimation"""

    def test_component_effects_structure(self, smoking_studies, component_matrix):
        """Test component effects have correct structure"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        for comp_eff in results.component_effects:
            assert isinstance(comp_eff, ComponentEffect)
            assert comp_eff.component_name in comp_names
            assert isinstance(comp_eff.mean_effect, float)
            assert comp_eff.standard_error > 0
            assert comp_eff.lower_95ci < comp_eff.upper_95ci
            assert 0 <= comp_eff.p_value <= 1

    def test_component_effects_reasonable(self, smoking_studies, component_matrix):
        """Test that component effects are in reasonable range"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Effects should be in reasonable range for smoking cessation (log OR)
        for comp_eff in results.component_effects:
            assert -2 < comp_eff.mean_effect < 2

    def test_significance_detection(self, smoking_studies, component_matrix):
        """Test significance detection works"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Should have at least some significant effects
        sig_count = sum(1 for ce in results.component_effects if ce.significant)
        assert sig_count > 0


class TestComponentContributions:
    """Test component contribution analysis"""

    def test_contributions_sum_to_effects(self, smoking_studies, component_matrix):
        """Test contributions are calculated correctly"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Check contributions structure
        for contrib in results.component_contributions:
            assert isinstance(contrib, ComponentContribution)
            assert contrib.contribution == contrib.effect_size * contrib.prevalence
            assert contrib.importance == abs(contrib.contribution)
            assert 0 <= contrib.prevalence <= 1

    def test_contributions_ranked(self, smoking_studies, component_matrix):
        """Test contributions are ranked correctly"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Ranks should be 1, 2, 3, ...
        ranks = [c.rank for c in results.component_contributions]
        assert ranks == list(range(1, len(results.component_contributions) + 1))

        # Importance should decrease with rank
        importances = [c.importance for c in results.component_contributions]
        assert importances == sorted(importances, reverse=True)


class TestTreatmentPrediction:
    """Test treatment effect prediction"""

    def test_predict_simple_combination(self, smoking_studies, component_matrix):
        """Test prediction for simple component combination"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Predict effect of Counseling + Pharmacotherapy
        prediction = analysis.predict_treatment({
            "Written materials": False,
            "Counseling": True,
            "Individual sessions": False,
            "Group sessions": False,
            "Pharmacotherapy": True
        })

        assert isinstance(prediction, TreatmentPrediction)
        assert len(prediction.active_components) == 2
        assert "Counseling" in prediction.active_components
        assert "Pharmacotherapy" in prediction.active_components
        assert prediction.standard_error > 0

    def test_predict_all_components(self, smoking_studies, component_matrix):
        """Test prediction with all components"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # All components active
        all_active = {comp: True for comp in comp_names}
        prediction = analysis.predict_treatment(all_active)

        assert len(prediction.active_components) == len(comp_names)

        # Effect should be sum of component effects
        expected_effect = sum(ce.mean_effect for ce in results.component_effects)
        assert abs(prediction.predicted_effect - expected_effect) < 0.01

    def test_predict_no_components(self, smoking_studies, component_matrix):
        """Test prediction with no components (control)"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # No components active
        none_active = {comp: False for comp in comp_names}
        prediction = analysis.predict_treatment(none_active)

        assert len(prediction.active_components) == 0
        assert abs(prediction.predicted_effect) < 0.01  # Should be near zero


class TestDismantlingAnalysis:
    """Test dismantling analysis functionality"""

    def test_dismantling_basic(self, smoking_studies, component_matrix):
        """Test basic dismantling analysis"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Dismantle: Group + NRT → Group therapy (remove NRT)
        result = analysis.analyze_dismantling(
            full_treatment="Group + NRT",
            reduced_treatment="Group therapy"
        )

        assert isinstance(result, DismantlingAnalysis)
        assert "Pharmacotherapy" in result.removed_components
        assert result.expected_effect_loss != 0
        assert result.standard_error > 0

    def test_dismantling_multiple_components(self, smoking_studies, component_matrix):
        """Test dismantling with multiple components removed"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Remove multiple components
        result = analysis.analyze_dismantling(
            full_treatment="Group + NRT",
            reduced_treatment="Control"
        )

        assert len(result.removed_components) > 1

    def test_dismantling_error_no_removal(self, smoking_studies, component_matrix):
        """Test error when no components removed"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Same treatment
        with pytest.raises(ValueError):
            analysis.analyze_dismantling(
                full_treatment="Group therapy",
                reduced_treatment="Group therapy"
            )


class TestOptimalDesign:
    """Test optimal treatment design"""

    def test_optimal_design_unconstrained(self, smoking_studies, component_matrix):
        """Test optimal design without constraints"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        optimal = analysis.design_optimal_treatment()

        assert isinstance(optimal, OptimalTreatmentDesign)
        assert len(optimal.optimal_components) > 0
        assert optimal.predicted_effect > 0  # Should have positive effect

    def test_optimal_design_max_components(self, smoking_studies, component_matrix):
        """Test optimal design with max components constraint"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        max_comp = 2
        optimal = analysis.design_optimal_treatment(max_components=max_comp)

        assert len(optimal.optimal_components) <= max_comp

    def test_optimal_design_with_costs(self, smoking_studies, component_matrix):
        """Test optimal design with cost constraints"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Define costs
        costs = {
            "Written materials": 10,
            "Counseling": 100,
            "Individual sessions": 200,
            "Group sessions": 150,
            "Pharmacotherapy": 300
        }

        optimal = analysis.design_optimal_treatment(
            cost_per_component=costs,
            budget=400
        )

        # Calculate total cost
        total_cost = sum(costs.get(comp, 0) for comp in optimal.optimal_components)
        assert total_cost <= 400

        assert optimal.cost_effectiveness_ratio is not None


class TestInteractionEffects:
    """Test component interaction effects"""

    def test_interaction_detection(self, smoking_studies, component_matrix):
        """Test that interactions are detected"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(
            engine=CNMAEngine.FREQUENTIST,
            include_interactions=True
        )

        # Should have n_choose_2 interactions
        n_expected = len(comp_names) * (len(comp_names) - 1) // 2
        assert len(results.interaction_effects) == n_expected

    def test_interaction_structure(self, smoking_studies, component_matrix):
        """Test interaction effect structure"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(
            engine=CNMAEngine.FREQUENTIST,
            include_interactions=True
        )

        for inter in results.interaction_effects:
            assert inter.component_1 in comp_names
            assert inter.component_2 in comp_names
            assert inter.component_1 != inter.component_2
            assert isinstance(inter.interaction_effect, float)
            assert inter.standard_error > 0


class TestConvenienceFunctions:
    """Test convenience functions"""

    def test_create_component_matrix(self, smoking_cessation_components):
        """Test component matrix creation"""
        matrix, comp_names, trt_names = create_component_matrix_from_dict(
            smoking_cessation_components
        )

        # Check dimensions
        assert matrix.shape == (len(comp_names), len(trt_names))

        # Check binary
        assert set(np.unique(matrix)) == {0, 1}

        # Check treatments
        assert set(trt_names) == set(smoking_cessation_components.keys())

    def test_quick_fit(self, smoking_studies, smoking_cessation_components):
        """Test quick fit function"""
        results = cnma_quick_fit(
            studies=smoking_studies,
            treatment_components=smoking_cessation_components,
            engine=CNMAEngine.FREQUENTIST
        )

        assert isinstance(results, CNMAResults)


class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_minimum_components(self):
        """Test with minimum number of components (2)"""
        # Simple 2-component system
        components = {
            "Control": [],
            "Treatment A": ["Component 1"],
            "Treatment B": ["Component 2"],
            "Treatment AB": ["Component 1", "Component 2"]
        }

        # Generate minimal studies
        studies = [
            CNMAStudy("S1", "Treatment A", "Control", 0.5, 0.1, 100),
            CNMAStudy("S2", "Treatment B", "Control", 0.6, 0.1, 100),
            CNMAStudy("S3", "Treatment AB", "Control", 1.1, 0.15, 100),
        ]

        matrix, comp_names, trt_names = create_component_matrix_from_dict(components)

        analysis = ComponentNMAAnalysis(
            studies=studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        assert len(results.component_effects) == 2

    def test_unbalanced_network(self):
        """Test with unbalanced component network"""
        components = {
            "Control": [],
            "Treatment A": ["Component 1"],
            "Treatment B": ["Component 1", "Component 2", "Component 3"],
        }

        studies = [
            CNMAStudy("S1", "Treatment A", "Control", 0.3, 0.1, 100),
            CNMAStudy("S2", "Treatment A", "Control", 0.4, 0.1, 100),
            CNMAStudy("S3", "Treatment B", "Control", 0.9, 0.15, 100),
        ]

        matrix, comp_names, trt_names = create_component_matrix_from_dict(components)

        analysis = ComponentNMAAnalysis(
            studies=studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        assert results is not None

    def test_high_heterogeneity_warning(self, smoking_studies, component_matrix):
        """Test warning for high heterogeneity"""
        matrix, comp_names, trt_names = component_matrix

        # Add high noise to studies
        for study in smoking_studies:
            study.effect_size += np.random.normal(0, 1.0)

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        # Should have high tau
        assert results.tau > 0.3


class TestResultsSummary:
    """Test results summary and presentation"""

    def test_summary_method(self, smoking_studies, component_matrix):
        """Test summary() method produces output"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        summary = results.summary()

        assert isinstance(summary, str)
        assert len(summary) > 0
        assert "COMPONENT NETWORK META-ANALYSIS" in summary
        assert "COMPONENT EFFECTS" in summary

    def test_summary_contains_key_info(self, smoking_studies, component_matrix):
        """Test summary contains key information"""
        matrix, comp_names, trt_names = component_matrix

        analysis = ComponentNMAAnalysis(
            studies=smoking_studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(engine=CNMAEngine.FREQUENTIST)

        summary = results.summary()

        # Should contain model info
        assert str(results.n_components) in summary
        assert str(results.n_treatments) in summary

        # Should contain component names
        for comp in comp_names:
            assert comp in summary


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
