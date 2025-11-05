"""
Comprehensive Unit Tests for Rules Engine
Tests recommendation system for analysis strategies and quality assessment
"""
import pytest
import pandas as pd
import numpy as np
from typing import List

from ml.rules_engine import (
    RecommendationPriority,
    Recommendation,
    AnalysisRecommender
)


# ============================================================================
# Fixtures
# ============================================================================

@pytest.fixture
def clean_study_data():
    """Create clean study data with no issues"""
    return pd.DataFrame({
        'study_id': [f'study_{i}' for i in range(10)],
        'yi': np.random.randn(10),
        'vi': np.random.uniform(0.01, 0.1, 10),
        'n': [150, 200, 180, 220, 190, 210, 175, 195, 185, 205],
        'year': [2020, 2019, 2021, 2020, 2022, 2021, 2020, 2019, 2021, 2022],
        'risk_of_bias': ['Low'] * 10
    })


@pytest.fixture
def problematic_study_data():
    """Create study data with multiple issues"""
    data = {
        'study_id': [f'study_{i}' for i in range(3)] + ['study_1'],  # Duplicate
        'yi': [0.5, 0.4, 5.0, 0.6],  # Outlier at index 2
        'vi': [0.05, 0.04, 0.06, 0.05],
        'n': [30, 25, 35, 40],  # All small studies
        'year': [2000, 2015, 2020, 2022],  # Wide year range
        'risk_of_bias': ['High', 'Low', 'Medium', 'High'],  # Mixed
        'treatment': ['A', 'B', 'C', 'A']  # Multiple interventions
    }

    # Create missing data
    df = pd.DataFrame(data)
    df.loc[0, 'vi'] = np.nan  # 25% missing
    return df


@pytest.fixture
def small_study_set():
    """Create dataset with too few studies"""
    return pd.DataFrame({
        'study_id': ['study_1', 'study_2', 'study_3'],
        'yi': [0.5, 0.4, 0.6],
        'vi': [0.05, 0.04, 0.06],
        'n': [100, 120, 110]
    })


@pytest.fixture
def industry_funded_studies():
    """Create dataset with industry funding"""
    return pd.DataFrame({
        'study_id': [f'study_{i}' for i in range(10)],
        'yi': np.random.randn(10),
        'vi': np.random.uniform(0.01, 0.1, 10),
        'n': [80] * 10,  # Small studies
        'industry_funded': [True] * 7 + [False] * 3  # 70% industry funded
    })


# ============================================================================
# Dataclass Tests
# ============================================================================

def test_recommendation_priority_enum():
    """Test RecommendationPriority enum"""
    assert RecommendationPriority.CRITICAL.value == "critical"
    assert RecommendationPriority.HIGH.value == "high"
    assert RecommendationPriority.MEDIUM.value == "medium"
    assert RecommendationPriority.LOW.value == "low"
    assert RecommendationPriority.INFO.value == "info"


def test_recommendation_dataclass():
    """Test Recommendation dataclass creation"""
    rec = Recommendation(
        title="Test Recommendation",
        description="This is a test",
        rationale="Because we need to test",
        priority=RecommendationPriority.HIGH,
        action_items=["Do this", "Do that"],
        estimated_impact="High",
        category="test"
    )

    assert rec.title == "Test Recommendation"
    assert rec.priority == RecommendationPriority.HIGH
    assert len(rec.action_items) == 2
    assert rec.estimated_impact == "High"
    assert rec.category == "test"


# ============================================================================
# AnalysisRecommender Tests - Clean Data
# ============================================================================

def test_analysis_recommender_initialization():
    """Test AnalysisRecommender initialization"""
    recommender = AnalysisRecommender()
    assert recommender is not None


def test_clean_data_recommendations(clean_study_data):
    """Test recommendations for clean data (should have minimal issues)"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(clean_study_data)

    assert isinstance(recommendations, list)

    # Clean data should have only method recommendations, not quality issues
    categories = [rec.category for rec in recommendations]
    assert 'data_quality' not in categories or len([c for c in categories if c == 'data_quality']) == 0


def test_recommendations_sorted_by_priority(clean_study_data):
    """Test that recommendations are sorted by priority"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(clean_study_data)

    # Check sorting
    priority_order = {
        RecommendationPriority.CRITICAL: 0,
        RecommendationPriority.HIGH: 1,
        RecommendationPriority.MEDIUM: 2,
        RecommendationPriority.LOW: 3,
        RecommendationPriority.INFO: 4
    }

    for i in range(len(recommendations) - 1):
        assert (priority_order[recommendations[i].priority] <=
                priority_order[recommendations[i + 1].priority])


# ============================================================================
# Data Quality Checks
# ============================================================================

def test_missing_data_detection(problematic_study_data):
    """Test detection of missing data"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should detect missing data
    missing_recs = [r for r in recommendations if 'Missing Data' in r.title]
    assert len(missing_recs) > 0
    assert missing_recs[0].priority == RecommendationPriority.HIGH
    assert 'vi' in missing_recs[0].description


def test_duplicate_studies_detection(problematic_study_data):
    """Test detection of duplicate studies"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should detect duplicate study_id
    dup_recs = [r for r in recommendations if 'Duplicate' in r.title]
    assert len(dup_recs) > 0
    assert dup_recs[0].priority == RecommendationPriority.CRITICAL
    assert "1 duplicate" in dup_recs[0].description


def test_outlier_detection():
    """Test detection of outlier studies"""
    # Create data with clear outlier (need enough variance for z-score >3)
    data = pd.DataFrame({
        'study_id': [f'study_{i}' for i in range(20)],
        'yi': [0.5, 0.4, 0.6, 0.45, 0.55, 0.5, 0.48, 0.52, 0.49, 0.51,
               0.47, 0.53, 0.50, 0.46, 0.54, 0.48, 0.52, 0.49, 0.51, 5.0],  # 5.0 is clear outlier (>3 SD)
        'vi': [0.05] * 20,
        'n': [100] * 20,
        'year': [2020] * 20
    })

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(data)

    # Should detect outlier (yi=5.0 is >3 standard deviations from mean ~0.5)
    outlier_recs = [r for r in recommendations if 'Outlier' in r.title]
    assert len(outlier_recs) > 0
    assert outlier_recs[0].priority == RecommendationPriority.MEDIUM


# ============================================================================
# Sample Size Checks
# ============================================================================

def test_small_number_of_studies(small_study_set):
    """Test detection of too few studies"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(small_study_set)

    # Should flag small number of studies
    small_n_recs = [r for r in recommendations if 'Small Number' in r.title]
    assert len(small_n_recs) > 0
    assert small_n_recs[0].priority == RecommendationPriority.HIGH
    assert '3 studies' in small_n_recs[0].description


def test_small_individual_studies(problematic_study_data):
    """Test detection of many small studies"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should flag small study sizes (n<50)
    small_studies_recs = [r for r in recommendations if 'Many Small Studies' in r.title]
    assert len(small_studies_recs) > 0
    assert small_studies_recs[0].priority == RecommendationPriority.MEDIUM


# ============================================================================
# Heterogeneity Checks
# ============================================================================

def test_wide_year_range_detection(problematic_study_data):
    """Test detection of wide publication year range"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should flag wide year range (2000-2022 = 22 years)
    year_recs = [r for r in recommendations if 'Publication Year Range' in r.title]
    assert len(year_recs) > 0
    assert year_recs[0].priority == RecommendationPriority.MEDIUM
    assert '22 years' in year_recs[0].description


def test_mixed_risk_of_bias(problematic_study_data):
    """Test detection of mixed risk of bias"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should flag mixed risk of bias
    rob_recs = [r for r in recommendations if 'Mixed Risk of Bias' in r.title]
    assert len(rob_recs) > 0
    assert rob_recs[0].priority == RecommendationPriority.HIGH


def test_multiple_interventions(problematic_study_data):
    """Test detection of multiple interventions"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should flag multiple interventions
    intervention_recs = [r for r in recommendations if 'Multiple Interventions' in r.title]
    assert len(intervention_recs) > 0
    assert intervention_recs[0].priority == RecommendationPriority.HIGH


# ============================================================================
# Publication Bias Checks
# ============================================================================

def test_limited_publication_bias_assessment(clean_study_data):
    """Test detection of limited ability to assess publication bias"""
    # Create small dataset (n<10)
    small_data = clean_study_data.iloc[:8].copy()

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(small_data)

    # Should flag limited assessment
    bias_recs = [r for r in recommendations if 'Limited Ability' in r.title or 'Publication Bias' in r.title]
    assert len(bias_recs) > 0


def test_predominance_of_small_studies(industry_funded_studies):
    """Test detection of predominance of small studies"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(industry_funded_studies)

    # Should flag predominance of small studies (median n=80)
    small_recs = [r for r in recommendations if 'Predominance of Small Studies' in r.title]
    assert len(small_recs) > 0
    assert small_recs[0].priority == RecommendationPriority.HIGH


def test_industry_funding_detection(industry_funded_studies):
    """Test detection of high industry funding"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(industry_funded_studies)

    # Should flag high proportion of industry funding
    funding_recs = [r for r in recommendations if 'Industry-Funded' in r.title]
    assert len(funding_recs) > 0
    assert funding_recs[0].priority == RecommendationPriority.HIGH
    assert '7/10' in funding_recs[0].description


# ============================================================================
# Analysis Method Recommendations
# ============================================================================

def test_random_effects_recommendation(clean_study_data):
    """Test recommendation for random-effects model"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(clean_study_data)

    # Should recommend random-effects
    re_recs = [r for r in recommendations if 'Random-Effects' in r.title]
    assert len(re_recs) > 0
    assert re_recs[0].priority == RecommendationPriority.HIGH


def test_heterogeneity_method_recommendation(clean_study_data):
    """Test recommendation for heterogeneity estimation method"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(clean_study_data)

    # Should recommend heterogeneity estimation method
    het_recs = [r for r in recommendations if 'Heterogeneity Estimation' in r.title]
    assert len(het_recs) > 0
    assert 'REML' in het_recs[0].description


def test_binary_outcome_effect_measure(clean_study_data):
    """Test effect measure recommendation for binary outcomes"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(
        clean_study_data,
        outcome_type="binary"
    )

    # Should recommend effect measure for binary outcomes
    effect_recs = [r for r in recommendations if 'Effect Measure Selection' in r.title]
    assert len(effect_recs) > 0
    assert 'Binary Outcomes' in effect_recs[0].title


def test_continuous_outcome_no_binary_recommendation(clean_study_data):
    """Test no binary-specific recommendations for continuous outcomes"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(
        clean_study_data,
        outcome_type="continuous"
    )

    # Should NOT have binary-specific recommendations
    binary_recs = [r for r in recommendations if 'Binary Outcomes' in r.title]
    assert len(binary_recs) == 0


# ============================================================================
# Sensitivity Analysis Recommendations
# ============================================================================

def test_risk_of_bias_sensitivity(problematic_study_data):
    """Test recommendation for risk of bias sensitivity analysis"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should recommend sensitivity analysis for high-risk studies
    sens_recs = [r for r in recommendations if 'Risk of Bias Sensitivity' in r.title]
    assert len(sens_recs) > 0
    assert sens_recs[0].priority == RecommendationPriority.HIGH


# ============================================================================
# Comprehensive Scenario Tests
# ============================================================================

def test_all_checks_executed(problematic_study_data):
    """Test that all check methods are executed"""
    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(problematic_study_data)

    # Should have recommendations from multiple categories
    categories = set(rec.category for rec in recommendations)

    # Expecting multiple categories
    assert len(categories) >= 3
    assert 'data_quality' in categories
    assert 'sample_size' in categories
    assert 'heterogeneity' in categories


def test_comprehensive_analysis_with_all_issues():
    """Test comprehensive analysis with all possible issues"""
    # Create data with all issues
    data = pd.DataFrame({
        'study_id': ['s1', 's2', 's3', 's3'],  # Duplicate
        'yi': [0.5, 0.4, 10.0, 0.6],  # Outlier
        'vi': [0.05, np.nan, 0.06, 0.05],  # Missing
        'n': [20, 25, 30, 35],  # Small studies, few studies
        'year': [2000, 2010, 2020, 2022],  # Wide range
        'risk_of_bias': ['High', 'Low', 'Medium', 'High'],  # Mixed
        'treatment': ['A', 'B', 'C', 'D'],  # Multiple
        'industry_funded': [True, True, True, False]  # High industry funding
    })

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(data)

    # Should have many recommendations
    assert len(recommendations) >= 8

    # Check for critical issues
    critical_recs = [r for r in recommendations if r.priority == RecommendationPriority.CRITICAL]
    assert len(critical_recs) > 0

    # Check for high priority issues
    high_recs = [r for r in recommendations if r.priority == RecommendationPriority.HIGH]
    assert len(high_recs) > 0


def test_minimal_issues_dataset():
    """Test analysis of dataset with minimal issues"""
    # Create ideal dataset
    data = pd.DataFrame({
        'study_id': [f'study_{i}' for i in range(15)],
        'yi': np.random.normal(0.5, 0.1, 15),  # No outliers
        'vi': np.random.uniform(0.01, 0.05, 15),
        'n': [200] * 15,  # Large studies
        'year': [2020, 2021, 2022] * 5,  # Recent, narrow range
        'risk_of_bias': ['Low'] * 15,  # All low risk
        'treatment': ['A'] * 15  # Single intervention
    })

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(data)

    # Should have mostly method recommendations, no critical issues
    critical_recs = [r for r in recommendations if r.priority == RecommendationPriority.CRITICAL]
    assert len(critical_recs) == 0

    # Should have some method recommendations
    method_recs = [r for r in recommendations if r.category == 'analysis_method']
    assert len(method_recs) > 0


# ============================================================================
# Edge Cases
# ============================================================================

def test_empty_dataframe():
    """Test handling of empty DataFrame"""
    empty_df = pd.DataFrame()
    recommender = AnalysisRecommender()

    # Should handle gracefully
    recommendations = recommender.analyze_data_and_recommend(empty_df)
    assert isinstance(recommendations, list)


def test_single_study():
    """Test handling of single study"""
    single_study = pd.DataFrame({
        'study_id': ['study_1'],
        'yi': [0.5],
        'vi': [0.05],
        'n': [100]
    })

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(single_study)

    # Should flag small number of studies
    assert len(recommendations) > 0
    small_n_recs = [r for r in recommendations if 'Small Number' in r.title]
    assert len(small_n_recs) > 0


def test_missing_optional_columns(clean_study_data):
    """Test handling when optional columns are missing"""
    # Remove optional columns
    df = clean_study_data[['study_id', 'yi', 'vi']].copy()

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(df)

    # Should still provide recommendations
    assert len(recommendations) > 0
    # But no sample size or year-based recommendations
    sample_recs = [r for r in recommendations if 'sample' in r.title.lower()]
    year_recs = [r for r in recommendations if 'year' in r.title.lower()]
    assert len(sample_recs) == 0
    assert len(year_recs) == 0


def test_all_missing_yi():
    """Test handling when all effect sizes are missing"""
    df = pd.DataFrame({
        'study_id': ['s1', 's2', 's3'],
        'yi': [np.nan, np.nan, np.nan],
        'vi': [0.05, 0.04, 0.06],
        'n': [100, 120, 110]
    })

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(df)

    # Should detect high missing data
    missing_recs = [r for r in recommendations if 'Missing' in r.title]
    assert len(missing_recs) > 0


# ============================================================================
# Integration Tests
# ============================================================================

def test_recommendation_structure_completeness():
    """Test that all recommendations have complete structure"""
    data = pd.DataFrame({
        'study_id': ['s1', 's2', 's3'],
        'yi': [0.5, 0.4, 10.0],
        'vi': [0.05, 0.04, 0.06],
        'n': [30, 25, 35]
    })

    recommender = AnalysisRecommender()
    recommendations = recommender.analyze_data_and_recommend(data)

    # Check every recommendation has required fields
    for rec in recommendations:
        assert isinstance(rec.title, str) and len(rec.title) > 0
        assert isinstance(rec.description, str) and len(rec.description) > 0
        assert isinstance(rec.rationale, str) and len(rec.rationale) > 0
        assert isinstance(rec.priority, RecommendationPriority)
        assert isinstance(rec.action_items, list) and len(rec.action_items) > 0
        assert isinstance(rec.estimated_impact, str)
        assert isinstance(rec.category, str) and len(rec.category) > 0


def test_different_outcome_types():
    """Test recommendations for different outcome types"""
    df = pd.DataFrame({
        'study_id': [f's{i}' for i in range(10)],
        'yi': np.random.randn(10),
        'vi': np.random.uniform(0.01, 0.1, 10),
        'n': [150] * 10
    })

    recommender = AnalysisRecommender()

    # Test all outcome types
    for outcome_type in ['binary', 'continuous', 'time_to_event']:
        recommendations = recommender.analyze_data_and_recommend(df, outcome_type=outcome_type)
        assert isinstance(recommendations, list)
        assert len(recommendations) > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
