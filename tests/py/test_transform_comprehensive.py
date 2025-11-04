"""
Comprehensive tests for data transformation module
"""
import pytest
import pandas as pd
import numpy as np
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.transform import (
    compute_effect_size,
    compute_binary_effect_size,
    compute_continuous_effect_size,
    compute_hr_effect_size,
    compute_contrast_binary,
    apply_continuity_correction
)


class TestBinaryEffectSizes:
    """Tests for binary outcome effect sizes"""

    def test_odds_ratio_basic(self):
        """Test basic OR calculation"""
        df = pd.DataFrame({
            'events1': [10, 20],
            'n1': [100, 200],
            'events2': [5, 15],
            'n2': [100, 200]
        })

        result = compute_contrast_binary(df, measure='OR')

        assert 'yi' in result.columns
        assert 'sei' in result.columns
        assert 'vi' in result.columns
        assert len(result) == 2
        # OR should be positive for these data
        assert all(result['yi'] > 0)

    def test_risk_ratio_basic(self):
        """Test basic RR calculation"""
        df = pd.DataFrame({
            'events1': [10, 20],
            'n1': [100, 200],
            'events2': [5, 15],
            'n2': [100, 200]
        })

        result = compute_contrast_binary(df, measure='RR')

        assert 'yi' in result.columns
        # RR should be log-transformed
        assert all(result['yi'] > 0)
        # SE should be positive
        assert all(result['sei'] > 0)

    def test_risk_difference_basic(self):
        """Test risk difference calculation"""
        df = pd.DataFrame({
            'events1': [10],
            'n1': [100],
            'events2': [5],
            'n2': [100]
        })

        result = compute_contrast_binary(df, measure='RD')

        # RD should be proportion difference
        expected_rd = (10/100) - (5/100)
        assert abs(result['yi'].iloc[0] - expected_rd) < 0.001

    def test_zero_cell_correction(self):
        """Test continuity correction for zero cells"""
        df = pd.DataFrame({
            'events1': [0],
            'n1': [100],
            'events2': [10],
            'n2': [100]
        })

        result = compute_contrast_binary(df, measure='OR')

        # Should not produce inf or nan
        assert np.isfinite(result['yi'].iloc[0])
        assert np.isfinite(result['sei'].iloc[0])

    def test_all_events_zero(self):
        """Test when all events are zero"""
        df = pd.DataFrame({
            'events1': [0, 0],
            'n1': [100, 200],
            'events2': [0, 0],
            'n2': [100, 200]
        })

        result = compute_contrast_binary(df, measure='OR')

        # Should apply correction and produce finite values
        assert all(np.isfinite(result['yi']))
        assert all(np.isfinite(result['sei']))


class TestContinuousEffectSizes:
    """Tests for continuous outcome effect sizes"""

    def test_mean_difference(self):
        """Test mean difference calculation"""
        df = pd.DataFrame({
            'mean1': [10.5],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [8.5],
            'sd2': [2.0],
            'n2': [50]
        })

        result = compute_continuous_effect_size(df, measure='MD')

        expected_md = 10.5 - 8.5
        assert abs(result['yi'].iloc[0] - expected_md) < 0.001
        assert result['sei'].iloc[0] > 0

    def test_standardized_mean_difference(self):
        """Test SMD (Hedges' g) calculation"""
        df = pd.DataFrame({
            'mean1': [10.0],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [8.0],
            'sd2': [2.0],
            'n2': [50]
        })

        result = compute_continuous_effect_size(df, measure='SMD')

        # SMD should be around 1.0 (standardized)
        assert 0.9 < result['yi'].iloc[0] < 1.1
        assert result['sei'].iloc[0] > 0

    def test_unequal_sample_sizes(self):
        """Test with unequal sample sizes"""
        df = pd.DataFrame({
            'mean1': [10.0],
            'sd1': [2.0],
            'n1': [30],
            'mean2': [8.0],
            'sd2': [3.0],
            'n2': [60]
        })

        result = compute_continuous_effect_size(df, measure='MD')

        assert np.isfinite(result['yi'].iloc[0])
        assert np.isfinite(result['sei'].iloc[0])

    def test_precomputed_effect_sizes(self):
        """Test that pre-computed yi/sei are preserved"""
        df = pd.DataFrame({
            'yi': [0.5, 0.7],
            'sei': [0.1, 0.15]
        })

        result = compute_continuous_effect_size(df, measure='MD')

        assert 'vi' in result.columns
        assert all(result['vi'] == result['sei'] ** 2)


class TestHazardRatioEffectSizes:
    """Tests for time-to-event (HR) effect sizes"""

    def test_hr_with_ci(self):
        """Test HR calculation from confidence intervals"""
        df = pd.DataFrame({
            'hr': [0.7],
            'ci_lower': [0.5],
            'ci_upper': [0.98]
        })

        result = compute_hr_effect_size(df)

        # yi should be log(HR)
        expected_yi = np.log(0.7)
        assert abs(result['yi'].iloc[0] - expected_yi) < 0.001
        assert result['sei'].iloc[0] > 0

    def test_hr_with_sei(self):
        """Test HR with pre-specified SE"""
        df = pd.DataFrame({
            'hr': [0.8],
            'sei': [0.15]
        })

        result = compute_hr_effect_size(df)

        expected_yi = np.log(0.8)
        assert abs(result['yi'].iloc[0] - expected_yi) < 0.001
        assert result['sei'].iloc[0] == 0.15

    def test_hr_multiple_studies(self):
        """Test multiple HRs"""
        df = pd.DataFrame({
            'hr': [0.7, 0.8, 0.9],
            'ci_lower': [0.5, 0.6, 0.7],
            'ci_upper': [0.98, 1.07, 1.15]
        })

        result = compute_hr_effect_size(df)

        assert len(result) == 3
        assert all(result['yi'] < 0)  # All HRs < 1, so log(HR) < 0
        assert all(result['sei'] > 0)

    def test_hr_missing_ci_and_sei(self):
        """Test that missing both CI and SE raises error"""
        df = pd.DataFrame({
            'hr': [0.7]
        })

        with pytest.raises(ValueError, match="requires either"):
            compute_hr_effect_size(df)


class TestContinuityCorrection:
    """Tests for continuity correction function"""

    def test_no_zero_cells(self):
        """Test no correction when no zero cells"""
        events = np.array([10, 20, 30])
        n = np.array([100, 200, 300])

        events_corr, n_corr = apply_continuity_correction(events, n)

        # No correction applied
        np.testing.assert_array_equal(events_corr, events)
        np.testing.assert_array_equal(n_corr, n)

    def test_zero_events(self):
        """Test correction for zero events"""
        events = np.array([0, 10, 20])
        n = np.array([100, 100, 100])

        events_corr, n_corr = apply_continuity_correction(events, n, correction=0.5)

        # First should be corrected
        assert events_corr[0] == 0.5
        assert n_corr[0] == 101.0
        # Others unchanged
        assert events_corr[1] == 10
        assert events_corr[2] == 20

    def test_all_events(self):
        """Test correction when events = n"""
        events = np.array([100, 10, 20])
        n = np.array([100, 100, 100])

        events_corr, n_corr = apply_continuity_correction(events, n, correction=0.5)

        # First should be corrected
        assert events_corr[0] == 100.5
        assert n_corr[0] == 101.0

    def test_custom_correction(self):
        """Test custom correction value"""
        events = np.array([0])
        n = np.array([100])

        events_corr, n_corr = apply_continuity_correction(events, n, correction=0.25)

        assert events_corr[0] == 0.25
        assert n_corr[0] == 100.5


class TestComputeEffectSize:
    """Tests for main compute_effect_size wrapper"""

    def test_auto_detect_binary(self):
        """Test auto-detection of binary data"""
        df = pd.DataFrame({
            'events1': [10],
            'n1': [100],
            'events2': [5],
            'n2': [100]
        })

        result = compute_effect_size(df, measure='OR')

        assert 'yi' in result.columns
        assert 'sei' in result.columns

    def test_auto_detect_continuous(self):
        """Test auto-detection of continuous data"""
        df = pd.DataFrame({
            'mean1': [10.0],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [8.0],
            'sd2': [2.0],
            'n2': [50]
        })

        result = compute_effect_size(df, measure='MD')

        assert 'yi' in result.columns

    def test_auto_detect_hr(self):
        """Test auto-detection of HR data"""
        df = pd.DataFrame({
            'hr': [0.7],
            'ci_lower': [0.5],
            'ci_upper': [0.98]
        })

        result = compute_effect_size(df, measure='HR')

        assert 'yi' in result.columns

    def test_invalid_measure(self):
        """Test that invalid measure raises error"""
        df = pd.DataFrame({
            'events1': [10],
            'n1': [100],
            'events2': [5],
            'n2': [100]
        })

        with pytest.raises(ValueError, match="Unknown measure"):
            compute_effect_size(df, measure='INVALID')


class TestEdgeCases:
    """Tests for edge cases and error handling"""

    def test_empty_dataframe(self):
        """Test with empty DataFrame"""
        df = pd.DataFrame()

        # Should handle gracefully or raise informative error
        with pytest.raises((ValueError, KeyError)):
            compute_effect_size(df, measure='OR')

    def test_single_row(self):
        """Test with single row"""
        df = pd.DataFrame({
            'events1': [10],
            'n1': [100],
            'events2': [5],
            'n2': [100]
        })

        result = compute_effect_size(df, measure='OR')
        assert len(result) == 1

    def test_missing_values(self):
        """Test handling of missing values"""
        df = pd.DataFrame({
            'events1': [10, np.nan],
            'n1': [100, 100],
            'events2': [5, 5],
            'n2': [100, 100]
        })

        result = compute_effect_size(df, measure='OR')

        # Should handle NaN appropriately
        assert len(result) == 2
        assert np.isnan(result['yi'].iloc[1])

    def test_negative_values(self):
        """Test that negative sample sizes are handled"""
        df = pd.DataFrame({
            'events1': [10],
            'n1': [-100],  # Invalid
            'events2': [5],
            'n2': [100]
        })

        # Should either handle or raise error
        # Implementation-dependent behavior


class TestVarianceCalculations:
    """Tests for variance calculations"""

    def test_vi_equals_sei_squared(self):
        """Test that vi = sei^2"""
        df = pd.DataFrame({
            'events1': [10, 20, 30],
            'n1': [100, 200, 300],
            'events2': [5, 15, 25],
            'n2': [100, 200, 300]
        })

        result = compute_effect_size(df, measure='OR')

        np.testing.assert_array_almost_equal(
            result['vi'],
            result['sei'] ** 2,
            decimal=10
        )

    def test_variance_positive(self):
        """Test that variance is always positive"""
        df = pd.DataFrame({
            'mean1': [10.0, 15.0, 20.0],
            'sd1': [2.0, 3.0, 4.0],
            'n1': [50, 60, 70],
            'mean2': [8.0, 12.0, 18.0],
            'sd2': [2.0, 3.0, 4.0],
            'n2': [50, 60, 70]
        })

        result = compute_effect_size(df, measure='MD')

        assert all(result['vi'] > 0)
        assert all(result['sei'] > 0)


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
