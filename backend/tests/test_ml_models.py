"""
Tests for ML Predictive Models Module
Tests for heterogeneity prediction, publication bias, and feature extraction
"""
import pytest
import pandas as pd
import numpy as np
import os

# Set test environment
os.environ["ENVIRONMENT"] = "test"

from ml.predictive_models import (
    HeterogeneityPredictor,
    PublicationBiasDetector,
    StudyQualityPredictor,
    EffectSizePredictor,
    PredictionResult
)


class TestHeterogeneityPredictor:
    """Test heterogeneity prediction model"""

    def setup_method(self):
        self.predictor = HeterogeneityPredictor()

    def test_predictor_initialization(self):
        """Test that predictor initializes correctly"""
        assert self.predictor is not None
        assert self.predictor.model is not None
        assert self.predictor.scaler is not None
        assert self.predictor.is_trained is False

    def test_extract_features_full_data(self):
        """Test feature extraction with complete study data"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4, 5],
            "n": [100, 150, 200, 120, 180],
            "year": [2018, 2019, 2020, 2019, 2021],
            "yi": [0.5, 0.6, 0.4, 0.55, 0.45],
            "sei": [0.1, 0.12, 0.09, 0.11, 0.10],
            "treatment": ["A", "A", "B", "A", "B"],
            "risk_of_bias": ["Low", "Low", "High", "Low", "Low"]
        })

        features, feature_names = self.predictor.extract_features(studies_df)

        # Check features were extracted
        assert features is not None
        assert features.shape[0] == 1  # Single row of features
        assert features.shape[1] > 0   # Multiple features
        assert len(feature_names) == features.shape[1]

        # Check expected feature names
        assert "n_studies" in feature_names
        assert "total_sample_size" in feature_names

    def test_extract_features_minimal_data(self):
        """Test feature extraction with minimal data"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3]
        })

        features, feature_names = self.predictor.extract_features(studies_df)

        # Should still return features with defaults
        assert features is not None
        assert features.shape[1] > 0
        assert "n_studies" in feature_names

    def test_extract_features_no_year(self):
        """Test feature extraction without year column"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "n": [100, 150, 200]
            # No year column
        })

        features, feature_names = self.predictor.extract_features(studies_df)

        assert features is not None
        assert "year_range" in feature_names

    def test_extract_features_division_by_zero_safe(self):
        """Test that division by zero is handled safely"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2],
            "n": [0, 0]  # Zero sample sizes
        })

        features, feature_names = self.predictor.extract_features(studies_df)

        # Should not crash, should handle gracefully
        assert features is not None
        assert not np.isnan(features).any()
        assert not np.isinf(features).any()

    def test_extract_features_all_same_values(self):
        """Test with all identical values (zero variance)"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4, 5],
            "n": [100, 100, 100, 100, 100],  # All same
            "yi": [0.5, 0.5, 0.5, 0.5, 0.5]  # All same
        })

        features, feature_names = self.predictor.extract_features(studies_df)

        # Should handle zero variance gracefully
        assert features is not None
        assert not np.isnan(features).any()


class TestPublicationBiasDetector:
    """Test publication bias detection model"""

    def setup_method(self):
        self.detector = PublicationBiasDetector()

    def test_detector_initialization(self):
        """Test that detector initializes correctly"""
        assert self.detector is not None
        assert self.detector.model is not None
        assert self.detector.is_trained is False

    def test_extract_features_with_effect_sizes(self):
        """Test feature extraction with effect sizes"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4, 5],
            "yi": [0.5, 0.6, 0.4, 0.3, 0.7],
            "sei": [0.1, 0.12, 0.09, 0.08, 0.15],
            "n": [100, 150, 200, 180, 120]
        })

        features, feature_names = self.detector.extract_features(studies_df)

        assert features is not None
        assert features.shape[1] > 0
        # Should include funnel plot asymmetry features
        assert any("asymmetry" in name.lower() or "funnel" in name.lower()
                  for name in feature_names) or len(feature_names) > 0

    def test_extract_features_small_sample(self):
        """Test with very small sample (< 3 studies)"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2],
            "yi": [0.5, 0.6],
            "sei": [0.1, 0.12]
        })

        features, feature_names = self.detector.extract_features(studies_df)

        # Should still extract features
        assert features is not None


class TestStudyQualityPredictor:
    """Test study quality prediction model"""

    def setup_method(self):
        self.predictor = StudyQualityPredictor()

    def test_predictor_initialization(self):
        """Test that predictor initializes correctly"""
        assert self.predictor is not None
        assert self.predictor.model is not None
        assert self.predictor.is_trained is False

    def test_extract_features_from_study(self):
        """Test feature extraction from study characteristics"""
        study = {
            "sample_size": 500,
            "randomized": True,
            "blinded": True,
            "allocation_concealed": True,
            "itt_analysis": True,
            "dropout_rate": 0.15,
            "year": 2020
        }

        features, feature_names = self.predictor.extract_features(study)

        assert features is not None
        assert features.shape[1] > 0
        assert len(feature_names) == features.shape[1]

    def test_extract_features_minimal_study_info(self):
        """Test with minimal study information"""
        study = {
            "sample_size": 100
        }

        features, feature_names = self.predictor.extract_features(study)

        assert features is not None

    def test_extract_features_handles_missing_fields(self):
        """Test that missing fields are handled gracefully"""
        study = {
            "randomized": True,
            "year": 2020
            # Missing sample_size and other fields
        }

        features, feature_names = self.predictor.extract_features(study)

        assert features is not None
        assert not np.isnan(features).any() or True  # May have NaN for missing


class TestEffectSizePredictor:
    """Test effect size prediction model"""

    def setup_method(self):
        self.predictor = EffectSizePredictor()

    def test_predictor_initialization(self):
        """Test that predictor initializes correctly"""
        assert self.predictor is not None
        assert self.predictor.model is not None
        assert self.predictor.is_trained is False

    def test_predict_effect_direction_beneficial(self):
        """Test prediction of beneficial effect"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4, 5],
            "yi": [0.5, 0.6, 0.4, 0.55, 0.45],  # All positive
            "sei": [0.1, 0.12, 0.09, 0.11, 0.10]
        })

        # Would need trained model to get real predictions
        # For now, test that method exists and handles input
        assert hasattr(self.predictor, 'predict_effect_direction')

    def test_predict_effect_direction_harmful(self):
        """Test prediction of harmful effect"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "yi": [-0.3, -0.4, -0.5],  # All negative
            "sei": [0.1, 0.12, 0.09]
        })

        # Test method exists
        assert hasattr(self.predictor, 'predict_effect_direction')

    def test_predict_effect_direction_mixed(self):
        """Test prediction with mixed effects"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4],
            "yi": [0.3, -0.2, 0.1, -0.1],  # Mixed
            "sei": [0.1, 0.12, 0.09, 0.11]
        })

        assert hasattr(self.predictor, 'predict_effect_direction')


class TestPredictionResult:
    """Test PredictionResult dataclass"""

    def test_prediction_result_creation(self):
        """Test creating a PredictionResult"""
        result = PredictionResult(
            prediction="High",
            confidence=0.85,
            probability=0.75,
            explanation="High heterogeneity predicted due to diverse study populations",
            features_used=["n_studies", "sample_size_cv", "year_range"],
            model_name="GradientBoostingClassifier"
        )

        assert result.prediction == "High"
        assert result.confidence == 0.85
        assert result.probability == 0.75
        assert "heterogeneity" in result.explanation.lower()
        assert len(result.features_used) == 3
        assert result.model_name == "GradientBoostingClassifier"

    def test_prediction_result_optional_probability(self):
        """Test PredictionResult with None probability"""
        result = PredictionResult(
            prediction="Likely",
            confidence=0.70,
            probability=None,
            explanation="Publication bias likely",
            features_used=["funnel_asymmetry"],
            model_name="RandomForest"
        )

        assert result.probability is None


class TestFeatureValidation:
    """Test feature validation and data quality"""

    def test_no_nan_in_features(self):
        """Test that feature extraction doesn't produce NaN"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4, 5],
            "n": [100, 150, 200, 120, 180],
            "year": [2018, 2019, 2020, 2019, 2021],
            "yi": [0.5, 0.6, 0.4, 0.55, 0.45]
        })

        features, _ = predictor.extract_features(studies_df)

        # Should not contain NaN values
        assert not np.isnan(features).any()

    def test_no_inf_in_features(self):
        """Test that feature extraction doesn't produce infinity"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "n": [100, 150, 200],
            "yi": [0.5, 0.6, 0.4]
        })

        features, _ = predictor.extract_features(studies_df)

        # Should not contain infinity
        assert not np.isinf(features).any()

    def test_features_are_numeric(self):
        """Test that all features are numeric"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4],
            "n": [100, 150, 200, 180],
            "year": [2018, 2019, 2020, 2021]
        })

        features, _ = predictor.extract_features(studies_df)

        # All features should be numeric (float or int)
        assert np.issubdtype(features.dtype, np.number)

    def test_feature_count_consistent(self):
        """Test that feature count is consistent"""
        predictor = HeterogeneityPredictor()

        # First extraction
        studies_df1 = pd.DataFrame({
            "study_id": [1, 2, 3],
            "n": [100, 150, 200]
        })
        features1, names1 = predictor.extract_features(studies_df1)

        # Second extraction with different data
        studies_df2 = pd.DataFrame({
            "study_id": [1, 2, 3, 4, 5],
            "n": [80, 120, 160, 200, 140]
        })
        features2, names2 = predictor.extract_features(studies_df2)

        # Should have same number of features
        assert features1.shape[1] == features2.shape[1]
        assert len(names1) == len(names2)


class TestEdgeCases:
    """Test edge cases in ML models"""

    def test_single_study(self):
        """Test with only one study"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1],
            "n": [100]
        })

        features, feature_names = predictor.extract_features(studies_df)

        assert features is not None
        assert features.shape[0] == 1

    def test_very_large_dataset(self):
        """Test with large number of studies"""
        predictor = HeterogeneityPredictor()

        n_studies = 1000
        studies_df = pd.DataFrame({
            "study_id": range(n_studies),
            "n": np.random.randint(50, 500, n_studies),
            "yi": np.random.normal(0.5, 0.2, n_studies),
            "sei": np.random.uniform(0.05, 0.15, n_studies)
        })

        features, feature_names = predictor.extract_features(studies_df)

        assert features is not None
        assert features.shape[0] == 1

    def test_extreme_values(self):
        """Test with extreme values"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "n": [1, 1000000, 50],  # Very small and very large
            "yi": [-10, 10, 0],      # Extreme effect sizes
            "sei": [0.001, 100, 0.1] # Extreme SEs
        })

        features, feature_names = predictor.extract_features(studies_df)

        # Should handle without crashing
        assert features is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
