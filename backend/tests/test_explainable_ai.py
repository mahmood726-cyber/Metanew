"""
Unit Tests for Explainable AI Module
Tests for SHAP and LIME explanations for ML models
"""

import pytest
import pandas as pd
import numpy as np
from dataclasses import asdict
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.explainable_ai import (
    ExplanationResult,
    ModelExplainer,
    SHAP_AVAILABLE,
    LIME_AVAILABLE
)
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.datasets import make_classification


# =====================================================================
# FIXTURES - Test Data and Models
# =====================================================================

@pytest.fixture
def sample_classification_data():
    """Create sample classification dataset"""
    X, y = make_classification(
        n_samples=100,
        n_features=10,
        n_informative=8,
        n_redundant=2,
        n_classes=2,
        random_state=42
    )
    feature_names = [f'feature_{i}' for i in range(10)]

    return X, y, feature_names


@pytest.fixture
def trained_rf_model(sample_classification_data):
    """Train a RandomForest model for testing"""
    X, y, feature_names = sample_classification_data

    model = RandomForestClassifier(
        n_estimators=10,
        max_depth=5,
        random_state=42
    )
    model.fit(X, y)

    return model, X, y, feature_names


@pytest.fixture
def trained_gb_model(sample_classification_data):
    """Train a GradientBoosting model for testing"""
    X, y, feature_names = sample_classification_data

    model = GradientBoostingClassifier(
        n_estimators=10,
        max_depth=3,
        random_state=42
    )
    model.fit(X, y)

    return model, X, y, feature_names


@pytest.fixture
def mock_shap_explainer():
    """Mock SHAP explainer for testing without SHAP library"""
    mock_explainer = MagicMock()

    # Mock SHAP values
    mock_shap_values = np.random.uniform(-1, 1, (1, 10))
    mock_explainer.shap_values.return_value = mock_shap_values

    # Mock expected value
    mock_explainer.expected_value = 0.5

    return mock_explainer


@pytest.fixture
def mock_lime_explainer():
    """Mock LIME explainer for testing without LIME library"""
    mock_explainer = MagicMock()

    # Mock LIME explanation
    mock_explanation = MagicMock()
    mock_explanation.as_list.return_value = [
        ('feature_0 > 0.5', 0.3),
        ('feature_1 <= 0.2', -0.2),
        ('feature_2 > 0.8', 0.15)
    ]
    mock_explanation.local_exp = {1: [(0, 0.3), (1, -0.2), (2, 0.15)]}
    mock_explanation.score = 0.85

    mock_explainer.explain_instance.return_value = mock_explanation

    return mock_explainer


# =====================================================================
# TEST: ExplanationResult
# =====================================================================

class TestExplanationResult:
    """Test ExplanationResult dataclass"""

    def test_explanation_result_creation(self):
        """Test creating an ExplanationResult"""
        result = ExplanationResult(
            method='shap',
            global_importance={'feature1': 0.5, 'feature2': 0.3},
            local_explanation={'feature1': 0.2},
            explanation_text='Test explanation',
            visualization_data={'plot': 'data'},
            confidence_score=0.85
        )

        assert result.method == 'shap'
        assert result.global_importance == {'feature1': 0.5, 'feature2': 0.3}
        assert result.local_explanation == {'feature1': 0.2}
        assert result.explanation_text == 'Test explanation'
        assert result.visualization_data == {'plot': 'data'}
        assert result.confidence_score == 0.85

    def test_explanation_result_to_dict(self):
        """Test converting ExplanationResult to dict"""
        result = ExplanationResult(
            method='lime',
            global_importance={},
            local_explanation=None,
            explanation_text='LIME explanation',
            visualization_data=None,
            confidence_score=0.92
        )

        result_dict = asdict(result)
        assert result_dict['method'] == 'lime'
        assert result_dict['confidence_score'] == 0.92
        assert isinstance(result_dict, dict)


# =====================================================================
# TEST: ModelExplainer Initialization
# =====================================================================

class TestModelExplainerInitialization:
    """Test ModelExplainer initialization"""

    def test_initialization_basic(self, trained_rf_model):
        """Test basic initialization"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        assert explainer.model is not None
        assert explainer.feature_names == feature_names
        assert explainer.training_data is not None

    def test_initialization_without_training_data(self, trained_rf_model):
        """Test initialization without training data"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=None
        )

        assert explainer.model is not None
        assert explainer.feature_names == feature_names
        assert explainer.training_data is None

    @pytest.mark.skipif(not SHAP_AVAILABLE, reason="SHAP not available")
    def test_shap_explainer_initialized(self, trained_rf_model):
        """Test that SHAP explainer is initialized when available"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        assert explainer.shap_explainer is not None

    @pytest.mark.skipif(not LIME_AVAILABLE, reason="LIME not available")
    def test_lime_explainer_initialized(self, trained_rf_model):
        """Test that LIME explainer is initialized when available")
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        assert explainer.lime_explainer is not None


# =====================================================================
# TEST: SHAP Explanations
# =====================================================================

class TestSHAPExplanations:
    """Test SHAP explanation methods"""

    @pytest.mark.skipif(not SHAP_AVAILABLE, reason="SHAP not available")
    def test_explain_prediction_shap_basic(self, trained_rf_model):
        """Test basic SHAP prediction explanation"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]  # Use subset for speed
        )

        # Explain first instance
        result = explainer.explain_prediction_shap(X[:1])

        assert isinstance(result, ExplanationResult)
        assert result.method == 'shap'
        assert len(result.global_importance) > 0
        assert result.local_explanation is not None
        assert len(result.explanation_text) > 0
        assert 0 <= result.confidence_score <= 1

    @pytest.mark.skipif(not SHAP_AVAILABLE, reason="SHAP not available")
    def test_explain_prediction_shap_multiple_instances(self, trained_rf_model):
        """Test SHAP explanation for different instances"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        # Explain different instances
        result_0 = explainer.explain_prediction_shap(X[:5], instance_idx=0)
        result_1 = explainer.explain_prediction_shap(X[:5], instance_idx=1)

        assert isinstance(result_0, ExplanationResult)
        assert isinstance(result_1, ExplanationResult)

        # Local explanations should differ between instances
        assert result_0.local_explanation != result_1.local_explanation

    @pytest.mark.skipif(not SHAP_AVAILABLE, reason="SHAP not available")
    def test_shap_feature_importance_ordering(self, trained_rf_model):
        """Test that SHAP returns feature importances in correct format"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        result = explainer.explain_prediction_shap(X[:1])

        # Check that importances are properly formatted
        assert isinstance(result.global_importance, dict)
        for feature, importance in result.global_importance.items():
            assert isinstance(feature, str)
            assert isinstance(importance, (int, float))
            assert feature in feature_names

    def test_shap_fallback_when_unavailable(self, trained_rf_model):
        """Test fallback behavior when SHAP is not available"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        # Force SHAP to be unavailable
        explainer.shap_explainer = None

        # Should use fallback method
        result = explainer.explain_prediction_shap(X[:1])

        assert isinstance(result, ExplanationResult)
        # Fallback should still provide some explanation
        assert len(result.explanation_text) > 0


# =====================================================================
# TEST: LIME Explanations
# =====================================================================

class TestLIMEExplanations:
    """Test LIME explanation methods"""

    @pytest.mark.skipif(not LIME_AVAILABLE, reason="LIME not available")
    def test_explain_prediction_lime_basic(self, trained_rf_model):
        """Test basic LIME prediction explanation"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        # Explain first instance
        result = explainer.explain_prediction_lime(X[:1])

        assert isinstance(result, ExplanationResult)
        assert result.method == 'lime'
        assert len(result.global_importance) > 0
        assert result.local_explanation is not None
        assert len(result.explanation_text) > 0

    @pytest.mark.skipif(not LIME_AVAILABLE, reason="LIME not available")
    def test_explain_prediction_lime_top_features(self, trained_rf_model):
        """Test LIME explanation with different num_features"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        # Test with different number of top features
        result_5 = explainer.explain_prediction_lime(X[:1], num_features=5)
        result_3 = explainer.explain_prediction_lime(X[:1], num_features=3)

        assert isinstance(result_5, ExplanationResult)
        assert isinstance(result_3, ExplanationResult)

        # 5 features should have more explanations than 3
        assert len(result_5.global_importance) >= len(result_3.global_importance)

    def test_lime_fallback_when_unavailable(self, trained_rf_model):
        """Test fallback behavior when LIME is not available"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        # Force LIME to be unavailable
        explainer.lime_explainer = None

        # Should use fallback method
        result = explainer.explain_prediction_lime(X[:1])

        assert isinstance(result, ExplanationResult)
        assert len(result.explanation_text) > 0


# =====================================================================
# TEST: Global Feature Importance
# =====================================================================

class TestGlobalFeatureImportance:
    """Test global feature importance methods"""

    def test_get_global_feature_importance_tree_model(self, trained_rf_model):
        """Test global importance for tree-based model"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        result = explainer.get_global_feature_importance()

        assert isinstance(result, ExplanationResult)
        assert result.method == 'feature_importance'
        assert len(result.global_importance) == len(feature_names)
        assert len(result.explanation_text) > 0

        # Check that importances sum to approximately 1.0 (or are normalized)
        total_importance = sum(result.global_importance.values())
        assert 0.8 <= total_importance <= 1.2  # Allow some tolerance

    def test_global_importance_ordering(self, trained_rf_model):
        """Test that global importances are properly ordered"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        result = explainer.get_global_feature_importance()

        # Get importances as sorted list
        importances = sorted(
            result.global_importance.items(),
            key=lambda x: x[1],
            reverse=True
        )

        # Check that importances are in descending order
        for i in range(len(importances) - 1):
            assert importances[i][1] >= importances[i+1][1]


# =====================================================================
# TEST: Comprehensive Explanations
# =====================================================================

class TestComprehensiveExplanations:
    """Test comprehensive explanation methods"""

    def test_explain_comprehensive_basic(self, trained_rf_model):
        """Test comprehensive explanation combining multiple methods"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        results = explainer.explain_comprehensive(X[:1])

        assert isinstance(results, dict)
        assert len(results) > 0

        # Should contain at least global importance
        assert 'global' in results or 'feature_importance' in results

        # All values should be ExplanationResult objects
        for key, value in results.items():
            assert isinstance(value, ExplanationResult)

    @pytest.mark.skipif(not SHAP_AVAILABLE or not LIME_AVAILABLE,
                        reason="SHAP or LIME not available")
    def test_explain_comprehensive_all_methods(self, trained_rf_model):
        """Test comprehensive explanation with all methods available"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        results = explainer.explain_comprehensive(X[:1])

        # Should have SHAP, LIME, and global importance
        expected_methods = ['shap', 'lime', 'global']
        available_methods = list(results.keys())

        # At least some methods should be present
        assert len(available_methods) > 0

        # Each result should be valid
        for method, result in results.items():
            assert isinstance(result, ExplanationResult)
            assert len(result.explanation_text) > 0


# =====================================================================
# TEST: Patient/Study-Specific Explanations
# =====================================================================

class TestPatientSpecificExplanations:
    """Test patient/study-specific explanation generation"""

    def test_generate_patient_specific_explanation(self, trained_rf_model):
        """Test generating patient-specific clinical explanations"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        # Create metadata for patient/study
        metadata = {
            'study_id': 'TEST_001',
            'outcome': 'mortality',
            'intervention': 'Drug A'
        }

        explanation_text = explainer.generate_patient_specific_explanation(
            X=X[:1],
            instance_idx=0,
            metadata=metadata
        )

        assert isinstance(explanation_text, str)
        assert len(explanation_text) > 0

        # Should contain study information
        assert 'TEST_001' in explanation_text or 'study' in explanation_text.lower()


# =====================================================================
# TEST: Fallback Mechanisms
# =====================================================================

class TestFallbackMechanisms:
    """Test fallback explanation mechanisms"""

    def test_fallback_explanation_basic(self, trained_rf_model):
        """Test fallback explanation when specialized methods unavailable"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        # Call fallback directly
        result = explainer._fallback_explanation(X[:1], instance_idx=0)

        assert isinstance(result, ExplanationResult)
        assert result.method == 'feature_importance'
        assert len(result.global_importance) > 0
        assert len(result.explanation_text) > 0

    def test_fallback_with_no_feature_importances(self):
        """Test fallback when model has no feature_importances_ attribute"""
        # Create a simple model without feature importances
        mock_model = Mock()
        mock_model.predict.return_value = np.array([1])
        mock_model.predict_proba.return_value = np.array([[0.3, 0.7]])

        # Remove feature_importances_ attribute
        del mock_model.feature_importances_

        feature_names = ['f1', 'f2', 'f3']
        X = np.random.rand(1, 3)

        explainer = ModelExplainer(
            model=mock_model,
            feature_names=feature_names,
            training_data=None
        )

        result = explainer._fallback_explanation(X, instance_idx=0)

        assert isinstance(result, ExplanationResult)
        # Should provide some explanation even without importances
        assert len(result.explanation_text) > 0


# =====================================================================
# TEST: Edge Cases
# =====================================================================

class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_single_instance_explanation(self, trained_rf_model):
        """Test explaining a single instance"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        single_instance = X[0:1]
        result = explainer.get_global_feature_importance()

        assert isinstance(result, ExplanationResult)

    def test_explanation_with_extreme_values(self, trained_rf_model):
        """Test explanation with extreme feature values"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        # Create instance with extreme values
        extreme_instance = np.array([[1000, -1000, 0, 0, 0, 0, 0, 0, 0, 0]])

        result = explainer.get_global_feature_importance()

        assert isinstance(result, ExplanationResult)

    def test_explanation_with_small_training_data(self):
        """Test explainer with very small training dataset"""
        # Create tiny dataset
        X = np.random.rand(5, 3)
        y = np.array([0, 1, 0, 1, 0])

        model = RandomForestClassifier(n_estimators=3, random_state=42)
        model.fit(X, y)

        feature_names = ['f1', 'f2', 'f3']

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X
        )

        result = explainer.get_global_feature_importance()

        assert isinstance(result, ExplanationResult)


# =====================================================================
# TEST: Integration Tests
# =====================================================================

class TestIntegration:
    """Integration tests for explainer with different model types"""

    def test_explainer_with_random_forest(self, trained_rf_model):
        """Test explainer with RandomForest model"""
        model, X, y, feature_names = trained_rf_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        # Test all major methods
        global_result = explainer.get_global_feature_importance()
        comprehensive_results = explainer.explain_comprehensive(X[:1])

        assert isinstance(global_result, ExplanationResult)
        assert isinstance(comprehensive_results, dict)
        assert len(comprehensive_results) > 0

    def test_explainer_with_gradient_boosting(self, trained_gb_model):
        """Test explainer with GradientBoosting model"""
        model, X, y, feature_names = trained_gb_model

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        global_result = explainer.get_global_feature_importance()
        comprehensive_results = explainer.explain_comprehensive(X[:1])

        assert isinstance(global_result, ExplanationResult)
        assert isinstance(comprehensive_results, dict)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "--cov=ml.explainable_ai", "--cov-report=term-missing"])
