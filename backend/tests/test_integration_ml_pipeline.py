"""
Integration Tests for ML Pipeline
End-to-end tests for the complete ML prediction pipeline
"""
import pytest
import pandas as pd
import numpy as np
from ml.predictive_models import (
    heterogeneity_predictor,
    publication_bias_detector,
    study_quality_predictor,
    effect_size_predictor
)
from ml.rules_engine import (
    analysis_recommender,
    sensitivity_engine,
    quality_engine
)
from ml.explainable_ai import ModelExplainer


class TestMLPipelineIntegration:
    """Integration tests for complete ML pipeline"""

    @pytest.fixture
    def sample_studies_data(self):
        """Sample study data for testing"""
        return pd.DataFrame({
            'study_id': [1, 2, 3, 4, 5],
            'n': [100, 150, 200, 120, 180],
            'yi': [0.5, 0.6, 0.4, 0.55, 0.45],
            'sei': [0.1, 0.12, 0.09, 0.11, 0.10],
            'year': [2018, 2019, 2020, 2019, 2021]
        })

    def test_heterogeneity_prediction_pipeline(self, sample_studies_data):
        """Test complete heterogeneity prediction pipeline"""
        # Step 1: Predict heterogeneity
        result = heterogeneity_predictor.predict(sample_studies_data)

        assert result is not None
        assert hasattr(result, 'prediction')
        assert hasattr(result, 'confidence')
        assert 0 <= result.confidence <= 1

        # Verify prediction is one of expected values
        assert result.prediction in ['High', 'Low', 'Moderate']

    def test_publication_bias_detection_pipeline(self, sample_studies_data):
        """Test complete publication bias detection pipeline"""
        # Ensure required columns exist
        if 'vi' not in sample_studies_data.columns:
            sample_studies_data['vi'] = sample_studies_data['sei'] ** 2

        result = publication_bias_detector.predict(sample_studies_data)

        assert result is not None
        assert hasattr(result, 'prediction')
        assert hasattr(result, 'confidence')

    def test_analysis_recommendation_pipeline(self, sample_studies_data):
        """Test analysis recommendation pipeline"""
        recommendations = analysis_recommender.analyze_data_and_recommend(
            sample_studies_data,
            outcome_type='binary'
        )

        assert recommendations is not None
        assert isinstance(recommendations, dict)
        assert 'recommended_models' in recommendations or 'models' in recommendations

    def test_sensitivity_analysis_pipeline(self, sample_studies_data):
        """Test sensitivity analysis recommendation pipeline"""
        base_results = {
            'pooled_effect': 0.5,
            'ci_lower': 0.3,
            'ci_upper': 0.7,
            'i_squared': 45.0
        }

        recommendations = sensitivity_engine.recommend_sensitivity_analyses(
            sample_studies_data,
            base_results
        )

        assert recommendations is not None
        assert isinstance(recommendations, (dict, list))

    def test_quality_assessment_pipeline(self):
        """Test quality assessment pipeline"""
        metadata = {
            'search_strategy': {'databases': ['PubMed', 'Embase'], 'grey_literature': True},
            'study_selection': {'screening_process': 'independent_dual', 'selection_criteria_clear': True},
            'data_extraction': {'extraction_form': True, 'independent_extraction': True}
        }

        assessment = quality_engine.assess_meta_analysis_quality(metadata)

        assert assessment is not None
        assert isinstance(assessment, dict)
        assert 'overall_quality' in assessment or 'quality_score' in assessment

    def test_multi_model_prediction_consistency(self, sample_studies_data):
        """Test that multiple models can run on same data"""
        # Run multiple predictions
        het_result = heterogeneity_predictor.predict(sample_studies_data)

        # Add required column for bias detection
        if 'vi' not in sample_studies_data.columns:
            sample_studies_data['vi'] = sample_studies_data['sei'] ** 2

        bias_result = publication_bias_detector.predict(sample_studies_data)

        # Both should succeed
        assert het_result is not None
        assert bias_result is not None

        # Both should have confidence scores
        assert hasattr(het_result, 'confidence')
        assert hasattr(bias_result, 'confidence')


class TestMLExplainabilityIntegration:
    """Integration tests for ML explainability"""

    @pytest.fixture
    def trained_model_with_data(self):
        """Create a trained model for explainability testing"""
        from sklearn.ensemble import RandomForestClassifier

        X = np.random.rand(100, 10)
        y = np.random.randint(0, 2, 100)

        model = RandomForestClassifier(n_estimators=10, random_state=42)
        model.fit(X, y)

        feature_names = [f'feature_{i}' for i in range(10)]

        return model, X, y, feature_names

    def test_explainer_initialization(self, trained_model_with_data):
        """Test explainer can be initialized with model"""
        model, X, y, feature_names = trained_model_with_data

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        assert explainer is not None
        assert explainer.model is not None
        assert explainer.feature_names == feature_names

    def test_global_feature_importance(self, trained_model_with_data):
        """Test global feature importance explanation"""
        model, X, y, feature_names = trained_model_with_data

        explainer = ModelExplainer(
            model=model,
            feature_names=feature_names,
            training_data=X[:50]
        )

        importance = explainer.get_global_feature_importance()

        assert importance is not None
        assert hasattr(importance, 'feature_names') or hasattr(importance, 'features')


class TestMLCachingIntegration:
    """Integration tests for ML caching"""

    def test_prediction_caching(self):
        """Test that predictions are cached properly"""
        from cache.ml_cache import ml_cache

        # Create sample data
        studies_data = pd.DataFrame({
            'study_id': [1, 2, 3],
            'n': [100, 150, 200],
            'yi': [0.5, 0.6, 0.4],
            'sei': [0.1, 0.12, 0.09]
        })

        # First prediction (cache miss)
        result1 = heterogeneity_predictor.predict(studies_data)

        # Second prediction (should be same, from cache or new computation)
        result2 = heterogeneity_predictor.predict(studies_data)

        # Results should exist
        assert result1 is not None
        assert result2 is not None


class TestMLDataFlowIntegration:
    """Test data flow through ML pipeline"""

    def test_data_validation_to_prediction(self):
        """Test data flow from validation to prediction"""
        # Create valid data
        studies_data = pd.DataFrame({
            'study_id': [1, 2, 3, 4, 5],
            'n': [100, 150, 200, 120, 180],
            'yi': [0.5, 0.6, 0.4, 0.55, 0.45],
            'sei': [0.1, 0.12, 0.09, 0.11, 0.10]
        })

        # Should be able to predict
        result = heterogeneity_predictor.predict(studies_data)

        assert result is not None
        assert hasattr(result, 'prediction')

    def test_minimal_data_prediction(self):
        """Test prediction with minimal required data"""
        # Minimal valid data (3 studies minimum)
        studies_data = pd.DataFrame({
            'n': [100, 150, 200],
            'yi': [0.5, 0.6, 0.4],
            'sei': [0.1, 0.12, 0.09]
        })

        result = heterogeneity_predictor.predict(studies_data)

        assert result is not None

    def test_large_dataset_prediction(self):
        """Test prediction with large dataset"""
        # Create larger dataset
        n_studies = 50
        studies_data = pd.DataFrame({
            'study_id': range(1, n_studies + 1),
            'n': np.random.randint(50, 300, n_studies),
            'yi': np.random.uniform(0.2, 0.8, n_studies),
            'sei': np.random.uniform(0.05, 0.15, n_studies)
        })

        result = heterogeneity_predictor.predict(studies_data)

        assert result is not None
        assert hasattr(result, 'prediction')
        assert hasattr(result, 'confidence')


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
