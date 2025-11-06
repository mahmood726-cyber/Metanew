"""
Tests for Arm-Based Binary Data Computation
"""
import pytest
import pandas as pd
import numpy as np
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.transform import compute_arm_binary, _identify_control_arm


class TestArmBasedComputation:
    """Test suite for arm-based effect size computation"""

    @pytest.fixture
    def two_arm_data(self):
        """Sample two-arm trial data"""
        return pd.DataFrame({
            'study_id': ['Study1', 'Study1', 'Study2', 'Study2'],
            'treatment': ['Intervention', 'Control', 'Treatment A', 'Placebo'],
            'events': [45, 65, 32, 48],
            'n': [200, 200, 150, 150]
        })

    @pytest.fixture
    def multi_arm_data(self):
        """Sample multi-arm trial data"""
        return pd.DataFrame({
            'study_id': ['Study1', 'Study1', 'Study1', 'Study2', 'Study2', 'Study2'],
            'treatment': ['Drug A', 'Drug B', 'Placebo', 'Treatment', 'Active Control', 'Placebo'],
            'events': [30, 35, 45, 20, 25, 35],
            'n': [100, 100, 100, 80, 80, 80]
        })

    def test_two_arm_computation(self, two_arm_data):
        """Test basic two-arm trial computation"""
        result = compute_arm_binary(two_arm_data, measure="OR")

        # Should have 2 contrasts (one per study)
        assert len(result) == 2

        # Should have yi, sei, vi columns
        assert "yi" in result.columns
        assert "sei" in result.columns
        assert "vi" in result.columns

        # All values should be finite
        assert np.all(np.isfinite(result["yi"]))
        assert np.all(np.isfinite(result["sei"]))
        assert np.all(result["sei"] > 0)

    def test_multi_arm_computation(self, multi_arm_data):
        """Test multi-arm trial computation"""
        result = compute_arm_binary(multi_arm_data, measure="OR")

        # Should have 4 contrasts (2 per study, each comparing to placebo)
        assert len(result) == 4

        # Check that placebo is used as control
        assert all("Placebo" in str(result["control"].values))

    def test_control_identification_explicit(self):
        """Test that explicit control labels are identified"""
        treatments = np.array(['Drug A', 'Placebo', 'Drug B'])
        control = _identify_control_arm(treatments)
        assert control == 'Placebo'

        treatments = np.array(['Treatment', 'Standard Care'])
        control = _identify_control_arm(treatments)
        assert control == 'Standard Care'

        treatments = np.array(['Active', 'Control'])
        control = _identify_control_arm(treatments)
        assert control == 'Control'

    def test_control_identification_alphabetical(self):
        """Test alphabetical fallback for control identification"""
        treatments = np.array(['Drug B', 'Drug A', 'Drug C'])
        control = _identify_control_arm(treatments)
        assert control == 'Drug A'  # First alphabetically

    def test_control_identification_case_insensitive(self):
        """Test that control identification is case-insensitive"""
        treatments = np.array(['DRUG A', 'placebo', 'DRUG B'])
        control = _identify_control_arm(treatments)
        assert control == 'placebo'

    def test_missing_columns(self):
        """Test error handling for missing required columns"""
        df = pd.DataFrame({
            'study_id': ['Study1', 'Study1'],
            'treatment': ['A', 'B']
            # Missing 'events' and 'n'
        })

        with pytest.raises(ValueError, match="Missing required columns"):
            compute_arm_binary(df)

    def test_single_arm_study_skipped(self):
        """Test that single-arm studies are skipped"""
        df = pd.DataFrame({
            'study_id': ['Study1', 'Study2'],  # Study2 has only one arm
            'treatment': ['Treatment', 'Control'],
            'events': [10, 20],
            'n': [100, 100]
        })

        with pytest.raises(ValueError, match="No valid study contrasts"):
            compute_arm_binary(df)

    def test_different_measures(self, two_arm_data):
        """Test computation with different effect measures"""
        # Test OR
        result_or = compute_arm_binary(two_arm_data, measure="OR")
        assert "yi" in result_or.columns

        # Test RR
        result_rr = compute_arm_binary(two_arm_data, measure="RR")
        assert "yi" in result_rr.columns

        # Results should be different
        assert not np.allclose(result_or["yi"].values, result_rr["yi"].values)

    def test_zero_events_handling(self):
        """Test handling of zero events (continuity correction)"""
        df = pd.DataFrame({
            'study_id': ['Study1', 'Study1'],
            'treatment': ['Treatment', 'Control'],
            'events': [0, 10],  # Zero events in treatment arm
            'n': [100, 100]
        })

        result = compute_arm_binary(df, measure="OR")

        # Should handle zero cells with continuity correction
        assert np.all(np.isfinite(result["yi"]))
        assert np.all(np.isfinite(result["sei"]))

    def test_preserves_study_information(self, two_arm_data):
        """Test that study information is preserved"""
        result = compute_arm_binary(two_arm_data, measure="OR")

        # Should preserve study_id
        assert "study_id" in result.columns
        assert set(result["study_id"]) == {'Study1', 'Study2'}

        # Should have treatment and control information
        assert "treatment" in result.columns
        assert "control" in result.columns

    def test_contrast_creation(self, multi_arm_data):
        """Test that contrasts are correctly created"""
        result = compute_arm_binary(multi_arm_data, measure="OR")

        # Check Study1 contrasts
        study1_contrasts = result[result["study_id"] == "Study1"]
        assert len(study1_contrasts) == 2  # Drug A vs Placebo, Drug B vs Placebo

        # Check that both compare to Placebo
        assert all(study1_contrasts["control"] == "Placebo")

    def test_consistency_with_contrast_method(self):
        """Test that arm-based and contrast-based methods give same results"""
        # Arm-based data
        arm_df = pd.DataFrame({
            'study_id': ['Study1', 'Study1'],
            'treatment': ['Treatment', 'Control'],
            'events': [45, 65],
            'n': [200, 200]
        })

        # Manually create contrast data
        contrast_df = pd.DataFrame({
            'study_id': ['Study1'],
            'events1': [45],
            'n1': [200],
            'events2': [65],
            'n2': [200]
        })

        from etl.transform import compute_contrast_binary

        result_arm = compute_arm_binary(arm_df, measure="OR")
        result_contrast = compute_contrast_binary(contrast_df, measure="OR")

        # Effect sizes should match (within floating point precision)
        assert np.allclose(result_arm["yi"].values[0], result_contrast["yi"].values[0], atol=0.001)
        assert np.allclose(result_arm["sei"].values[0], result_contrast["sei"].values[0], atol=0.001)

    def test_already_has_effect_sizes(self):
        """Test that data with existing yi/sei is returned unchanged"""
        df = pd.DataFrame({
            'study_id': ['Study1', 'Study2'],
            'yi': [0.5, 0.7],
            'sei': [0.1, 0.15]
        })

        result = compute_arm_binary(df, measure="OR")

        # Should return data with vi added
        assert "vi" in result.columns
        assert np.allclose(result["vi"], result["sei"] ** 2)


class TestControlIdentification:
    """Test suite specifically for control arm identification logic"""

    def test_common_control_terms(self):
        """Test identification of common control terms"""
        control_examples = [
            (['A', 'Placebo', 'B'], 'Placebo'),
            (['Drug', 'Control', 'Other'], 'Control'),
            (['Treatment', 'Standard Care'], 'Standard Care'),
            (['Active', 'Usual Care'], 'Usual Care'),
            (['X', 'Standard of Care', 'Y'], 'Standard of Care'),
            (['A', 'Comparator', 'B'], 'Comparator'),
            (['Drug', 'Reference', 'Other'], 'Reference'),
        ]

        for treatments, expected_control in control_examples:
            result = _identify_control_arm(np.array(treatments))
            assert result == expected_control

    def test_partial_matching(self):
        """Test that control terms work with partial matching"""
        # "Placebo" should match "Placebo Group"
        treatments = np.array(['Drug A', 'Placebo Group', 'Drug B'])
        control = _identify_control_arm(treatments)
        assert control == 'Placebo Group'

    def test_no_control_term(self):
        """Test alphabetical fallback when no control term present"""
        treatments = np.array(['Zeta Drug', 'Alpha Drug', 'Beta Drug'])
        control = _identify_control_arm(treatments)
        assert control == 'Alpha Drug'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
