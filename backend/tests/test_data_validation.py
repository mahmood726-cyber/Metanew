"""
Tests for Data Validation and ETL Processing
Comprehensive tests for data validation, transformation, and loading
"""
import pytest
import pandas as pd
import numpy as np
from pydantic import ValidationError
from typing import Dict, List, Any
import os

# Set test environment
os.environ["ENVIRONMENT"] = "test"

# Import Pydantic models for validation
from api.ml_routes import (
    StudyData,
    HeterogeneityPredictionRequest,
    PublicationBiasRequest,
    StudyQualityRequest,
    RecommendationRequest,
    LLMQueryRequest,
    StudyDeduplicationRequest
)

# Import ML feature extraction
from ml.predictive_models import (
    HeterogeneityPredictor,
    PublicationBiasDetector,
    StudyQualityPredictor,
    PredictionResult
)


class TestStudyDataValidation:
    """Test validation of study data inputs"""

    def test_valid_study_data(self):
        """Test valid study data passes validation"""
        data = StudyData(
            data={
                "study_id": [1, 2, 3],
                "n": [100, 150, 200],
                "yi": [0.5, 0.6, 0.4],
                "sei": [0.1, 0.12, 0.09]
            },
            outcome_type="binary"
        )

        assert data.outcome_type == "binary"
        assert "study_id" in data.data
        assert len(data.data["study_id"]) == 3

    def test_outcome_type_default(self):
        """Test outcome_type defaults to binary"""
        data = StudyData(
            data={
                "study_id": [1, 2],
                "n": [100, 150]
            }
        )

        assert data.outcome_type == "binary"

    def test_empty_data_allowed(self):
        """Test that empty data dict is allowed (for some endpoints)"""
        data = StudyData(data={})
        assert data.data == {}

    def test_study_data_with_various_outcome_types(self):
        """Test all valid outcome types"""
        outcome_types = ["binary", "continuous", "time_to_event"]

        for outcome_type in outcome_types:
            data = StudyData(
                data={"study_id": [1]},
                outcome_type=outcome_type
            )
            assert data.outcome_type == outcome_type


class TestHeterogeneityPredictionRequest:
    """Test heterogeneity prediction request validation"""

    def test_valid_heterogeneity_request(self):
        """Test valid request"""
        request = HeterogeneityPredictionRequest(
            studies={
                "study_id": [1, 2, 3],
                "n": [100, 150, 200],
                "year": [2018, 2019, 2020]
            }
        )

        assert "study_id" in request.studies
        assert len(request.studies["n"]) == 3

    def test_heterogeneity_request_minimal_data(self):
        """Test request with minimal valid data"""
        request = HeterogeneityPredictionRequest(
            studies={
                "study_id": [1]
            }
        )

        assert request.studies is not None

    def test_heterogeneity_request_with_all_fields(self):
        """Test request with comprehensive study data"""
        request = HeterogeneityPredictionRequest(
            studies={
                "study_id": [1, 2, 3],
                "n": [100, 150, 200],
                "yi": [0.5, 0.6, 0.4],
                "sei": [0.1, 0.12, 0.09],
                "year": [2018, 2019, 2020],
                "treatment": ["A", "A", "B"],
                "risk_of_bias": ["Low", "Low", "High"]
            }
        )

        assert len(request.studies) == 7


class TestPublicationBiasRequest:
    """Test publication bias request validation"""

    def test_valid_publication_bias_request(self):
        """Test valid request with yi and sei"""
        request = PublicationBiasRequest(
            studies={
                "study_id": [1, 2, 3, 4, 5],
                "yi": [0.5, 0.6, 0.4, 0.7, 0.3],
                "sei": [0.1, 0.12, 0.09, 0.15, 0.08]
            }
        )

        assert "yi" in request.studies
        assert "sei" in request.studies
        assert len(request.studies["yi"]) == 5

    def test_publication_bias_missing_yi(self):
        """Test that request allows missing yi (validation happens in endpoint)"""
        request = PublicationBiasRequest(
            studies={
                "study_id": [1, 2, 3],
                "sei": [0.1, 0.12, 0.09]
            }
        )

        # Pydantic doesn't enforce yi/sei, endpoint does
        assert "sei" in request.studies
        assert "yi" not in request.studies


class TestStudyQualityRequest:
    """Test study quality prediction request validation"""

    def test_valid_study_quality_request(self):
        """Test valid request with study characteristics"""
        request = StudyQualityRequest(
            study={
                "sample_size": 500,
                "randomized": True,
                "blinded": True,
                "allocation_concealed": True,
                "itt_analysis": True,
                "dropout_rate": 0.15,
                "year": 2020
            }
        )

        assert request.study["sample_size"] == 500
        assert request.study["randomized"] is True

    def test_study_quality_minimal_data(self):
        """Test with minimal study info"""
        request = StudyQualityRequest(
            study={
                "sample_size": 100
            }
        )

        assert request.study["sample_size"] == 100

    def test_study_quality_various_data_types(self):
        """Test that various data types are accepted"""
        request = StudyQualityRequest(
            study={
                "string_field": "RCT",
                "int_field": 500,
                "float_field": 0.15,
                "bool_field": True,
                "list_field": ["item1", "item2"]
            }
        )

        assert request.study["string_field"] == "RCT"
        assert request.study["bool_field"] is True


class TestRecommendationRequest:
    """Test analysis recommendation request validation"""

    def test_valid_recommendation_request(self):
        """Test valid request"""
        request = RecommendationRequest(
            studies={
                "study_id": [1, 2, 3],
                "n": [100, 150, 200]
            },
            outcome_type="binary",
            metadata={"protocol": "PRISMA"}
        )

        assert request.outcome_type == "binary"
        assert request.metadata["protocol"] == "PRISMA"

    def test_recommendation_request_defaults(self):
        """Test default values"""
        request = RecommendationRequest(
            studies={"study_id": [1]}
        )

        assert request.outcome_type == "binary"
        assert request.metadata == {}

    def test_recommendation_request_all_outcome_types(self):
        """Test all outcome types"""
        for outcome in ["binary", "continuous", "time_to_event"]:
            request = RecommendationRequest(
                studies={"study_id": [1]},
                outcome_type=outcome
            )
            assert request.outcome_type == outcome


class TestLLMQueryRequest:
    """Test LLM query request validation"""

    def test_valid_llm_query(self):
        """Test valid LLM query"""
        request = LLMQueryRequest(
            query="What is heterogeneity?",
            context={"i_squared": 75},
            style="academic"
        )

        assert request.query == "What is heterogeneity?"
        assert request.context["i_squared"] == 75
        assert request.style == "academic"

    def test_llm_query_defaults(self):
        """Test default values"""
        request = LLMQueryRequest(
            query="Test query"
        )

        assert request.context == {}
        assert request.style == "academic"

    def test_llm_query_empty_string(self):
        """Test query can be empty string"""
        request = LLMQueryRequest(query="")
        assert request.query == ""

    def test_llm_query_various_styles(self):
        """Test different writing styles"""
        styles = ["academic", "clinical", "plain", "technical"]

        for style in styles:
            request = LLMQueryRequest(
                query="test",
                style=style
            )
            assert request.style == style


class TestStudyDeduplicationRequest:
    """Test study deduplication request validation"""

    def test_valid_deduplication_request(self):
        """Test valid deduplication request"""
        request = StudyDeduplicationRequest(
            studies=[
                {
                    "study_id": "1",
                    "title": "Study A",
                    "authors": ["Smith J"],
                    "year": 2020,
                    "doi": "10.1234/test"
                },
                {
                    "study_id": "2",
                    "title": "Study B",
                    "authors": ["Jones M"],
                    "year": 2021
                }
            ]
        )

        assert len(request.studies) == 2
        assert request.studies[0]["title"] == "Study A"

    def test_deduplication_empty_list(self):
        """Test with empty study list"""
        request = StudyDeduplicationRequest(studies=[])
        assert request.studies == []

    def test_deduplication_minimal_study_info(self):
        """Test with minimal study information"""
        request = StudyDeduplicationRequest(
            studies=[
                {"study_id": "1"},
                {"study_id": "2"}
            ]
        )

        assert len(request.studies) == 2


class TestFeatureExtraction:
    """Test feature extraction from study data"""

    def test_heterogeneity_feature_extraction_full_data(self):
        """Test feature extraction with complete study data"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3, 4, 5],
            "n": [100, 150, 200, 120, 180],
            "year": [2018, 2019, 2020, 2019, 2021],
            "yi": [0.5, 0.6, 0.4, 0.55, 0.45],
            "sei": [0.1, 0.12, 0.09, 0.11, 0.10],
            "treatment": ["A", "A", "B", "A", "B"],
            "risk_of_bias": ["Low", "Low", "High", "Low", "Low"]
        })

        features, feature_names = predictor.extract_features(studies_df)

        assert features.shape[1] > 0
        assert len(feature_names) == features.shape[1]
        assert "n_studies" in feature_names
        assert "total_sample_size" in feature_names

    def test_heterogeneity_feature_extraction_minimal_data(self):
        """Test feature extraction with minimal data"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3]
        })

        features, feature_names = predictor.extract_features(studies_df)

        # Should still return features with defaults
        assert features.shape[1] > 0
        assert "n_studies" in feature_names

    def test_feature_extraction_handles_missing_columns(self):
        """Test that missing columns are handled gracefully"""
        predictor = HeterogeneityPredictor()

        studies_df = pd.DataFrame({
            "study_id": [1, 2],
            "n": [100, 150]
            # Missing: year, yi, treatment, risk_of_bias
        })

        features, feature_names = predictor.extract_features(studies_df)

        assert features is not None
        assert len(feature_names) > 0

    def test_feature_extraction_division_by_zero_protection(self):
        """Test that division by zero is prevented"""
        predictor = HeterogeneityPredictor()

        # Create data that could cause division by zero
        studies_df = pd.DataFrame({
            "study_id": [1],
            "n": [0]  # Zero sample size
        })

        features, feature_names = predictor.extract_features(studies_df)

        # Should not raise error, should handle gracefully
        assert features is not None
        assert not np.isnan(features).any()


class TestDataFrameConversion:
    """Test conversion of dict to DataFrame"""

    def test_dict_to_dataframe_conversion(self):
        """Test converting request data dict to DataFrame"""
        data_dict = {
            "study_id": [1, 2, 3],
            "n": [100, 150, 200],
            "yi": [0.5, 0.6, 0.4]
        }

        df = pd.DataFrame(data_dict)

        assert len(df) == 3
        assert "study_id" in df.columns
        assert df["n"].sum() == 450

    def test_empty_dict_to_dataframe(self):
        """Test converting empty dict"""
        df = pd.DataFrame({})

        assert len(df) == 0
        assert len(df.columns) == 0

    def test_unequal_length_arrays(self):
        """Test that unequal length arrays raise error"""
        data_dict = {
            "study_id": [1, 2, 3],
            "n": [100, 150]  # Different length
        }

        with pytest.raises(ValueError):
            pd.DataFrame(data_dict)

    def test_dataframe_with_missing_values(self):
        """Test DataFrame with NaN values"""
        data_dict = {
            "study_id": [1, 2, 3],
            "n": [100, np.nan, 200],
            "yi": [0.5, 0.6, np.nan]
        }

        df = pd.DataFrame(data_dict)

        assert df["n"].isna().sum() == 1
        assert df["yi"].isna().sum() == 1


class TestDataQualityChecks:
    """Test data quality validation"""

    def test_required_columns_for_publication_bias(self):
        """Test that yi and sei are required for publication bias"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "n": [100, 150, 200]
            # Missing yi, sei
        })

        # Check if required columns exist
        has_yi = 'yi' in studies_df.columns
        has_sei = 'sei' in studies_df.columns

        assert has_yi is False
        assert has_sei is False

    def test_minimum_studies_count(self):
        """Test checking minimum number of studies"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2]  # Only 2 studies
        })

        n_studies = len(studies_df)
        min_required = 3

        assert n_studies < min_required

    def test_detect_outliers_in_effect_sizes(self):
        """Test detecting outlier effect sizes"""
        yi_values = np.array([0.5, 0.6, 0.4, 0.55, 0.58, 0.52, 100.0])  # 100.0 is extreme outlier

        mean = yi_values.mean()
        std = yi_values.std()
        z_scores = np.abs((yi_values - mean) / std)

        # Values with |z-score| > 2 are potential outliers
        outliers = z_scores > 2

        assert outliers.sum() > 0  # Should detect at least one outlier

    def test_detect_negative_sample_sizes(self):
        """Test detecting invalid negative sample sizes"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "n": [100, -50, 200]  # -50 is invalid
        })

        invalid = studies_df['n'] < 0

        assert invalid.sum() > 0

    def test_detect_negative_standard_errors(self):
        """Test detecting invalid negative standard errors"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "sei": [0.1, -0.05, 0.12]  # -0.05 is invalid
        })

        invalid = studies_df['sei'] < 0

        assert invalid.sum() > 0

    def test_year_range_validation(self):
        """Test validating study year ranges"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "year": [2020, 2025, 1800]  # 2025 future, 1800 too old
        })

        current_year = 2024
        too_old = studies_df['year'] < 1900
        in_future = studies_df['year'] > current_year

        assert too_old.sum() > 0
        assert in_future.sum() > 0


class TestInputSanitization:
    """Test input sanitization and safety"""

    def test_string_length_limits(self):
        """Test that very long strings are handled"""
        very_long_string = "A" * 100000

        request = LLMQueryRequest(
            query=very_long_string
        )

        # Should accept but may be truncated by application
        assert len(request.query) == 100000

    def test_special_characters_in_strings(self):
        """Test handling special characters"""
        special_chars = "Test <script>alert('xss')</script> test"

        request = LLMQueryRequest(
            query=special_chars
        )

        # Pydantic accepts it, sanitization should happen in application
        assert "<script>" in request.query

    def test_numeric_type_coercion(self):
        """Test that numeric strings are not auto-converted"""
        request = StudyQualityRequest(
            study={
                "year": "2020",  # String instead of int
                "sample_size": "500"
            }
        )

        # Pydantic accepts Any type in dict
        assert request.study["year"] == "2020"

    def test_sql_injection_patterns(self):
        """Test that SQL injection patterns are passed through (should be escaped later)"""
        sql_injection = "1; DROP TABLE users--"

        request = LLMQueryRequest(
            query=sql_injection
        )

        # Pydantic doesn't sanitize, just validates structure
        assert "DROP TABLE" in request.query


class TestErrorHandling:
    """Test error handling for invalid data"""

    def test_missing_required_field_in_pydantic(self):
        """Test that missing required fields raise ValidationError"""
        with pytest.raises(ValidationError):
            # Missing required 'query' field
            LLMQueryRequest()

    def test_invalid_data_type_in_pydantic(self):
        """Test that invalid types raise ValidationError"""
        with pytest.raises(ValidationError):
            # query must be string, not int
            LLMQueryRequest(query=12345)

    def test_invalid_nested_structure(self):
        """Test invalid nested data structure"""
        with pytest.raises(ValidationError):
            # studies should be dict, not list
            HeterogeneityPredictionRequest(studies=[1, 2, 3])

    def test_none_values_handling(self):
        """Test handling of None values"""
        request = StudyQualityRequest(
            study={
                "sample_size": None,
                "year": 2020
            }
        )

        assert request.study["sample_size"] is None

    def test_infinity_values(self):
        """Test handling infinity values"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "yi": [0.5, np.inf, 0.4]  # Infinity
        })

        has_inf = np.isinf(studies_df['yi']).any()
        assert has_inf == True  # Use == instead of is for numpy bool


class TestDataTransformations:
    """Test data transformation operations"""

    def test_standardization_of_features(self):
        """Test feature standardization"""
        from sklearn.preprocessing import StandardScaler

        features = np.array([[100, 200], [150, 250], [200, 300]])
        scaler = StandardScaler()

        scaled = scaler.fit_transform(features)

        # Mean should be approximately 0
        assert np.abs(scaled.mean()) < 0.01

    def test_handling_single_unique_value(self):
        """Test standardization with single unique value (zero variance)"""
        from sklearn.preprocessing import StandardScaler

        features = np.array([[100, 100], [100, 100], [100, 100]])
        scaler = StandardScaler()

        # Should handle zero variance gracefully
        scaled = scaler.fit_transform(features)

        # Should be zeros (or handle gracefully without NaN)
        assert not np.isnan(scaled).any()

    def test_log_transformation(self):
        """Test log transformation for skewed data"""
        values = np.array([1, 10, 100, 1000])

        log_values = np.log(values)

        assert len(log_values) == len(values)
        assert all(log_values < values)

    def test_log_transformation_with_zeros(self):
        """Test log transformation with zero values"""
        values = np.array([0, 1, 10, 100])

        # Should handle zeros by adding small constant
        log_values = np.log(values + 1e-10)

        assert not np.isnan(log_values).any()
        assert not np.isinf(log_values).any()


class TestEdgeCases:
    """Test edge cases in data validation"""

    def test_single_study(self):
        """Test with only one study"""
        studies_df = pd.DataFrame({
            "study_id": [1],
            "n": [100]
        })

        assert len(studies_df) == 1

    def test_very_large_dataset(self):
        """Test with large number of studies"""
        n_studies = 10000

        studies_df = pd.DataFrame({
            "study_id": range(n_studies),
            "n": np.random.randint(50, 500, n_studies)
        })

        assert len(studies_df) == n_studies

    def test_unicode_in_study_data(self):
        """Test Unicode characters in study data"""
        request = StudyDeduplicationRequest(
            studies=[
                {
                    "study_id": "1",
                    "title": "Étude française avec caractères spéciaux 中文",
                    "authors": ["José García", "李明"]
                }
            ]
        )

        assert "français" in request.studies[0]["title"]

    def test_empty_strings_in_data(self):
        """Test empty strings in data fields"""
        request = StudyQualityRequest(
            study={
                "title": "",
                "authors": "",
                "sample_size": 100
            }
        )

        assert request.study["title"] == ""

    def test_duplicate_study_ids(self):
        """Test detection of duplicate study IDs"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 2, 3],  # 2 is duplicate
            "n": [100, 150, 160, 200]
        })

        duplicates = studies_df['study_id'].duplicated()

        assert duplicates.sum() > 0

    def test_mixed_data_types_in_column(self):
        """Test mixed data types in DataFrame column"""
        # DataFrame allows mixed types
        df = pd.DataFrame({
            "study_id": [1, "2", 3.0, "four"]
        })

        assert len(df) == 4
        assert df["study_id"].dtype == object


class TestBoundaryValues:
    """Test boundary and extreme values"""

    def test_zero_sample_size(self):
        """Test zero sample size"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "n": [0, 100, 200]
        })

        zeros = studies_df['n'] == 0
        assert zeros.sum() > 0

    def test_very_large_sample_size(self):
        """Test very large sample size"""
        studies_df = pd.DataFrame({
            "study_id": [1],
            "n": [1000000000]  # 1 billion
        })

        assert studies_df['n'].iloc[0] == 1000000000

    def test_very_small_effect_size(self):
        """Test very small effect size near zero"""
        studies_df = pd.DataFrame({
            "study_id": [1, 2, 3],
            "yi": [1e-10, 0.0, -1e-10]
        })

        assert abs(studies_df['yi'].iloc[0]) < 1e-9

    def test_very_large_standard_error(self):
        """Test very large standard error"""
        studies_df = pd.DataFrame({
            "study_id": [1],
            "sei": [1000.0]  # Very large SE
        })

        assert studies_df['sei'].iloc[0] == 1000.0

    def test_maximum_integer_value(self):
        """Test maximum integer values"""
        max_val = 2**31 - 1  # Max 32-bit int

        studies_df = pd.DataFrame({
            "study_id": [1],
            "n": [max_val]
        })

        assert studies_df['n'].iloc[0] == max_val


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
