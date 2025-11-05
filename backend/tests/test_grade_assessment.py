"""
Tests for GRADE Assessment System
"""
import pytest
import pandas as pd
from ml.grade_assessment import (
    GRADEAssessor,
    StudyDesign,
    EvidenceQuality,
    GRADEAssessment
)


@pytest.fixture
def grade_assessor():
    """Create GRADE assessor instance"""
    return GRADEAssessor()


@pytest.fixture
def sample_meta_results():
    """Sample meta-analysis results"""
    return {
        "pooled_effect": 0.75,
        "ci_lower": 0.60,
        "ci_upper": 0.95,
        "i_squared": 45.2,
        "p_heterogeneity": 0.12,
        "p_value": 0.003,
        "publication_bias_detected": False
    }


@pytest.fixture
def sample_study_data():
    """Sample study data"""
    return pd.DataFrame({
        "study_id": ["Study1", "Study2", "Study3"],
        "year": [2020, 2021, 2022],
        "n_treatment": [100, 150, 120],
        "n_control": [100, 150, 120]
    })


@pytest.fixture
def sample_rob_assessments():
    """Sample ROB assessments"""
    return [
        {"overall_judgment": "Low", "study_id": "Study1"},
        {"overall_judgment": "Some concerns", "study_id": "Study2"},
        {"overall_judgment": "Low", "study_id": "Study3"}
    ]


class TestGRADEBasic:
    """Basic GRADE functionality tests"""

    def test_assessor_initialization(self, grade_assessor):
        """Test assessor initializes correctly"""
        assert grade_assessor is not None

    def test_rct_starting_quality(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test RCT starts at High quality"""
        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            study_design=StudyDesign.RCT
        )

        assert assessment.starting_quality == EvidenceQuality.HIGH

    def test_observational_starting_quality(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test observational starts at Low quality"""
        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            study_design=StudyDesign.OBSERVATIONAL
        )

        assert assessment.starting_quality == EvidenceQuality.LOW

    def test_assessment_has_all_domains(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test assessment includes all required domains"""
        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            study_design=StudyDesign.RCT
        )

        assert assessment.risk_of_bias is not None
        assert assessment.inconsistency is not None
        assert assessment.indirectness is not None
        assert assessment.imprecision is not None
        assert assessment.publication_bias is not None

    def test_final_quality_calculated(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test final quality is calculated"""
        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            study_design=StudyDesign.RCT
        )

        assert assessment.final_quality in [
            EvidenceQuality.HIGH,
            EvidenceQuality.MODERATE,
            EvidenceQuality.LOW,
            EvidenceQuality.VERY_LOW
        ]


class TestGRADEDomains:
    """Test individual GRADE domain assessments"""

    def test_low_heterogeneity_no_downgrade(self, grade_assessor):
        """Test low heterogeneity doesn't downgrade"""
        meta_results = {
            "i_squared": 25.0,
            "p_heterogeneity": 0.25,
            "pooled_effect": 0.75,
            "ci_lower": 0.60,
            "ci_upper": 0.95
        }

        inconsistency = grade_assessor._assess_inconsistency(meta_results)

        assert inconsistency.downgrade == 0
        assert inconsistency.rating == "No serious"

    def test_high_heterogeneity_downgrades(self, grade_assessor):
        """Test high heterogeneity downgrades quality"""
        meta_results = {
            "i_squared": 80.0,
            "p_heterogeneity": 0.001,
            "pooled_effect": 0.75,
            "ci_lower": 0.60,
            "ci_upper": 0.95
        }

        inconsistency = grade_assessor._assess_inconsistency(meta_results)

        assert inconsistency.downgrade == -2
        assert inconsistency.rating == "Very serious"

    def test_wide_ci_imprecision(self, grade_assessor, sample_study_data):
        """Test wide confidence interval downgrades for imprecision"""
        meta_results = {
            "pooled_effect": 0.75,
            "ci_lower": 0.2,  # Very wide CI
            "ci_upper": 2.5,
            "i_squared": 0
        }

        imprecision = grade_assessor._assess_imprecision(meta_results, sample_study_data)

        assert imprecision.downgrade < 0  # Should downgrade

    def test_precise_estimate_no_downgrade(self, grade_assessor):
        """Test precise estimate doesn't downgrade"""
        meta_results = {
            "pooled_effect": 0.75,
            "ci_lower": 0.70,  # Narrow CI
            "ci_upper": 0.80,
            "i_squared": 0
        }

        study_data = pd.DataFrame({
            "study_id": ["S1", "S2", "S3"],
            "n_treatment": [1000, 1000, 1000],  # Large sample
            "n_control": [1000, 1000, 1000]
        })

        imprecision = grade_assessor._assess_imprecision(meta_results, study_data)

        assert imprecision.downgrade == 0


class TestGRADEWithROB:
    """Test GRADE with ROB assessments"""

    def test_high_rob_downgrades(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test high risk of bias downgrades quality"""
        rob_assessments = [
            {"overall_judgment": "High"},
            {"overall_judgment": "High"},
            {"overall_judgment": "Some concerns"}
        ]

        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            rob_assessments=rob_assessments,
            study_design=StudyDesign.RCT
        )

        assert assessment.risk_of_bias.downgrade < 0
        assert assessment.final_quality != EvidenceQuality.HIGH

    def test_low_rob_no_downgrade(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test low risk of bias doesn't downgrade"""
        rob_assessments = [
            {"overall_judgment": "Low"},
            {"overall_judgment": "Low"},
            {"overall_judgment": "Low"}
        ]

        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            rob_assessments=rob_assessments,
            study_design=StudyDesign.RCT
        )

        assert assessment.risk_of_bias.downgrade == 0


class TestGRADEUpgrading:
    """Test GRADE upgrading factors (observational only)"""

    def test_large_effect_upgrades(self, grade_assessor):
        """Test large effect size upgrades observational studies"""
        meta_results = {
            "pooled_effect": 6.0,  # Very large effect (RR > 5)
            "ci_lower": 4.0,
            "ci_upper": 9.0,
            "i_squared": 0
        }

        large_effect = grade_assessor._assess_large_effect(meta_results)

        assert large_effect is not None
        assert large_effect.downgrade > 0  # Actually upgrade (positive)

    def test_no_upgrade_for_small_effect(self, grade_assessor):
        """Test small effects don't upgrade"""
        meta_results = {
            "pooled_effect": 1.5,  # Small effect
            "ci_lower": 1.2,
            "ci_upper": 1.8,
            "i_squared": 0
        }

        large_effect = grade_assessor._assess_large_effect(meta_results)

        assert large_effect is None  # No upgrade


class TestGRADEOutput:
    """Test GRADE output formats"""

    def test_to_dict_format(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test conversion to dictionary format"""
        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            study_design=StudyDesign.RCT
        )

        result_dict = grade_assessor.to_dict(assessment)

        # Check required fields
        assert "outcome" in result_dict
        assert "final_quality" in result_dict
        assert "confidence" in result_dict
        assert "domains" in result_dict
        assert "summary" in result_dict

        # Check domains
        assert "risk_of_bias" in result_dict["domains"]
        assert "inconsistency" in result_dict["domains"]
        assert "imprecision" in result_dict["domains"]

    def test_summary_generated(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test summary text is generated"""
        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            study_design=StudyDesign.RCT
        )

        assert assessment.summary != ""
        assert "GRADE Assessment" in assessment.summary

    def test_confidence_in_range(self, grade_assessor, sample_meta_results, sample_study_data):
        """Test confidence score is between 0 and 1"""
        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=sample_meta_results,
            study_data=sample_study_data,
            study_design=StudyDesign.RCT
        )

        assert 0.0 <= assessment.confidence <= 1.0


class TestGRADEEdgeCases:
    """Test edge cases and error handling"""

    def test_minimal_data(self, grade_assessor):
        """Test with minimal data"""
        meta_results = {
            "pooled_effect": 0.75
        }

        study_data = pd.DataFrame({
            "study_id": ["S1"]
        })

        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=meta_results,
            study_data=study_data,
            study_design=StudyDesign.RCT
        )

        assert assessment.final_quality is not None

    def test_few_studies(self, grade_assessor):
        """Test with very few studies"""
        meta_results = {
            "pooled_effect": 0.75,
            "ci_lower": 0.60,
            "ci_upper": 0.95,
            "i_squared": 0
        }

        study_data = pd.DataFrame({
            "study_id": ["S1", "S2"],
            "n_treatment": [50, 50],
            "n_control": [50, 50]
        })

        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=meta_results,
            study_data=study_data,
            study_design=StudyDesign.RCT
        )

        # With few studies, should consider publication bias undetected
        assert assessment.publication_bias.rating == "Undetected"


class TestGRADEIntegration:
    """Integration tests"""

    def test_complete_workflow_high_quality(self, grade_assessor):
        """Test complete workflow resulting in high quality"""
        # Perfect RCT data
        meta_results = {
            "pooled_effect": 0.70,
            "ci_lower": 0.65,
            "ci_upper": 0.75,
            "i_squared": 10.0,
            "p_heterogeneity": 0.35,
            "publication_bias_detected": False
        }

        study_data = pd.DataFrame({
            "study_id": ["S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10"],
            "n_treatment": [500] * 10,
            "n_control": [500] * 10
        })

        rob_assessments = [{"overall_judgment": "Low"}] * 10

        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=meta_results,
            study_data=study_data,
            rob_assessments=rob_assessments,
            study_design=StudyDesign.RCT
        )

        # Should maintain high quality
        assert assessment.final_quality == EvidenceQuality.HIGH

    def test_complete_workflow_low_quality(self, grade_assessor):
        """Test complete workflow resulting in low quality"""
        # Poor quality data
        meta_results = {
            "pooled_effect": 0.50,
            "ci_lower": 0.1,  # Very wide
            "ci_upper": 2.5,
            "i_squared": 85.0,  # High heterogeneity
            "p_heterogeneity": 0.001,
            "publication_bias_detected": True
        }

        study_data = pd.DataFrame({
            "study_id": ["S1", "S2"],
            "n_treatment": [30, 25],  # Small samples
            "n_control": [30, 25]
        })

        rob_assessments = [
            {"overall_judgment": "High"},
            {"overall_judgment": "High"}
        ]

        assessment = grade_assessor.assess_outcome(
            outcome="Mortality",
            meta_analysis_results=meta_results,
            study_data=study_data,
            rob_assessments=rob_assessments,
            study_design=StudyDesign.RCT
        )

        # Should be downgraded significantly
        assert assessment.final_quality in [EvidenceQuality.LOW, EvidenceQuality.VERY_LOW]
        assert assessment.overall_downgrade < -2


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
