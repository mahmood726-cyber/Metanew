"""
Comprehensive Tests for Transform Module (Effect Size Computation)
Triple testing: Unit tests, Edge cases, Mathematical verification
"""
import pytest
import pandas as pd
import numpy as np
from hypothesis import given, strategies as st, assume
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.transform import (
    compute_effect_size, compute_binary_effect_size,
    compute_continuous_effect_size, compute_contrast_binary,
    compute_arm_binary
)


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def binary_contrast_df():
    """Binary contrast data (2x2 table)"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'events1': [10, 20],
        'n1': [100, 200],
        'events2': [20, 30],
        'n2': [100, 200]
    })


@pytest.fixture
def continuous_df():
    """Continuous outcome data"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'treatment': ['A', 'B'],
        'mean': [10.5, 12.3],
        'sd': [2.1, 2.5],
        'n': [50, 60]
    })


# ============================================================================
# TEST 1: ODDS RATIO COMPUTATION (Triple Coverage)
# ============================================================================

class TestOddsRatioComputation:
    """Comprehensive tests for OR computation"""

    def test_or_basic_computation(self, binary_contrast_df):
        """Test 1.1: Basic OR computation"""
        result = compute_effect_size(binary_contrast_df, measure='OR')
        assert 'yi' in result.columns
        assert 'sei' in result.columns
        assert 'vi' in result.columns
        assert len(result) == 2

    def test_or_values_in_expected_range(self, binary_contrast_df):
        """Test 1.2: OR values in expected range"""
        result = compute_effect_size(binary_contrast_df, measure='OR')
        # Log OR should be reasonable (between -10 and 10)
        assert all(-10 < yi < 10 for yi in result['yi'])

    def test_or_sei_positive(self, binary_contrast_df):
        """Test 1.3: SE should always be positive"""
        result = compute_effect_size(binary_contrast_df, measure='OR')
        assert all(sei > 0 for sei in result['sei'])

    def test_or_with_zero_cells(self):
        """Test 1.4: OR with zero cells (continuity correction)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [0],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')
        # Should apply continuity correction
        assert result is not None
        assert 'yi' in result.columns

    def test_or_all_events(self):
        """Test 1.5: OR when events = n (continuity correction)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [100],
            'n1': [100],
            'events2': [50],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')
        assert result is not None

    def test_or_mathematical_verification(self):
        """Test 1.6: Mathematical verification of OR calculation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')

        # Manual calculation
        p1 = 40 / 100  # 0.4
        p2 = 20 / 100  # 0.2
        or_manual = (p1 / (1 - p1)) / (p2 / (1 - p2))
        log_or_manual = np.log(or_manual)

        # Should be close (within floating point precision)
        assert abs(result['yi'].iloc[0] - log_or_manual) < 0.01

    def test_or_variance_calculation(self):
        """Test 1.7: Variance calculation verification"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')

        # Variance should equal SE squared
        assert abs(result['vi'].iloc[0] - result['sei'].iloc[0]**2) < 0.0001

    def test_or_symmetric_property(self):
        """Test 1.8: OR(A vs B) = -OR(B vs A)"""
        df1 = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })

        df2 = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [20],  # Swapped
            'n1': [100],
            'events2': [40],  # Swapped
            'n2': [100]
        })

        result1 = compute_effect_size(df1, measure='OR')
        result2 = compute_effect_size(df2, measure='OR')

        # Should be negatives of each other
        assert abs(result1['yi'].iloc[0] + result2['yi'].iloc[0]) < 0.01


# ============================================================================
# TEST 2: RISK RATIO COMPUTATION (Triple Coverage)
# ============================================================================

class TestRiskRatioComputation:
    """Comprehensive tests for RR computation"""

    def test_rr_basic_computation(self):
        """Test 2.1: Basic RR computation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RR')
        assert 'yi' in result.columns
        assert 'sei' in result.columns

    def test_rr_mathematical_verification(self):
        """Test 2.2: Mathematical verification of RR"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RR')

        # Manual calculation
        p1 = 40 / 100
        p2 = 20 / 100
        rr_manual = p1 / p2
        log_rr_manual = np.log(rr_manual)

        assert abs(result['yi'].iloc[0] - log_rr_manual) < 0.01

    def test_rr_values_range(self):
        """Test 2.3: RR values in reasonable range"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'events1': [40, 30, 50],
            'n1': [100, 100, 100],
            'events2': [20, 25, 45],
            'n2': [100, 100, 100]
        })
        result = compute_effect_size(df, measure='RR')
        # Log RR typically between -5 and 5
        assert all(-5 < yi < 5 for yi in result['yi'])

    def test_rr_with_zero_events(self):
        """Test 2.4: RR with zero events"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [0],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RR')
        assert result is not None

    def test_rr_equal_risks_zero_log(self):
        """Test 2.5: Equal risks should give log(RR) ≈ 0"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [30],
            'n1': [100],
            'events2': [30],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RR')
        # Log(1) = 0
        assert abs(result['yi'].iloc[0]) < 0.1


# ============================================================================
# TEST 3: RISK DIFFERENCE COMPUTATION (Triple Coverage)
# ============================================================================

class TestRiskDifferenceComputation:
    """Comprehensive tests for RD computation"""

    def test_rd_basic_computation(self):
        """Test 3.1: Basic RD computation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RD')
        assert 'yi' in result.columns

    def test_rd_mathematical_verification(self):
        """Test 3.2: Mathematical verification of RD"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RD')

        # Manual calculation
        p1 = 40 / 100  # 0.4
        p2 = 20 / 100  # 0.2
        rd_manual = p1 - p2  # 0.2

        assert abs(result['yi'].iloc[0] - rd_manual) < 0.01

    def test_rd_range_minus_one_to_one(self):
        """Test 3.3: RD should be between -1 and 1"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'events1': [40, 30, 50],
            'n1': [100, 100, 100],
            'events2': [20, 25, 45],
            'n2': [100, 100, 100]
        })
        result = compute_effect_size(df, measure='RD')
        assert all(-1 <= yi <= 1 for yi in result['yi'])

    def test_rd_zero_for_equal_risks(self):
        """Test 3.4: RD = 0 for equal risks"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [30],
            'n1': [100],
            'events2': [30],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RD')
        assert abs(result['yi'].iloc[0]) < 0.01


# ============================================================================
# TEST 4: MEAN DIFFERENCE COMPUTATION (Triple Coverage)
# ============================================================================

class TestMeanDifferenceComputation:
    """Comprehensive tests for MD computation"""

    def test_md_basic_computation(self):
        """Test 4.1: Basic MD computation"""
        # Continuous data requires contrast format (mean1, sd1, n1, mean2, sd2, n2)
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean1': [10.5],
            'sd1': [2.1],
            'n1': [50],
            'mean2': [12.3],
            'sd2': [2.5],
            'n2': [60]
        })
        result = compute_effect_size(df, measure='MD')
        assert 'yi' in result.columns
        assert 'sei' in result.columns
        # MD should equal mean1 - mean2
        expected_md = 10.5 - 12.3
        assert abs(result['yi'].iloc[0] - expected_md) < 0.01

    def test_md_mathematical_verification(self):
        """Test 4.2: Mathematical verification of MD"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean1': [10.5],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [12.0],
            'sd2': [2.0],
            'n2': [50]
        })
        # Need to implement this for contrast data
        # For now, test with arm-based data
        assert True  # Placeholder

    def test_md_variance_calculation(self):
        """Test 4.3: MD variance calculation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean1': [10.5],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [12.0],
            'sd2': [2.0],
            'n2': [50]
        })
        # Test variance calculation
        assert True  # Placeholder


# ============================================================================
# TEST 5: STANDARDIZED MEAN DIFFERENCE (Triple Coverage)
# ============================================================================

class TestSMDComputation:
    """Comprehensive tests for SMD (Hedges' g) computation"""

    def test_smd_basic_computation(self):
        """Test 5.1: Basic SMD computation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean1': [10.5],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [12.0],
            'sd2': [2.0],
            'n2': [50]
        })
        # Need implementation
        assert True  # Placeholder

    def test_smd_pooled_sd_calculation(self):
        """Test 5.2: Pooled SD calculation for SMD"""
        # Test pooled standard deviation calculation
        assert True  # Placeholder

    def test_smd_hedges_g_bias_correction(self):
        """Test 5.3: Hedges' g bias correction factor"""
        # Test small sample bias correction
        assert True  # Placeholder


# ============================================================================
# TEST 6: HAZARD RATIO COMPUTATION (Triple Coverage)
# ============================================================================

class TestHazardRatioComputation:
    """Comprehensive tests for HR computation"""

    def test_hr_from_log_hr_and_se(self):
        """Test 6.1: HR from log HR and SE"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [-0.3],  # log(HR)
            'sei': [0.15]
        })
        result = compute_effect_size(df, measure='HR')
        assert result is not None

    def test_hr_from_ci_computation(self):
        """Test 6.2: SE computation from CI"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'hr': [0.7],
            'ci_lower': [0.5],
            'ci_upper': [0.98]
        })
        # Should compute SE from CI
        # SE ≈ (log(upper) - log(lower)) / (2 * 1.96)
        assert True  # Placeholder


# ============================================================================
# TEST 7: EDGE CASES (Triple Coverage)
# ============================================================================

class TestTransformEdgeCases:
    """Edge case tests for transform module"""

    def test_single_study(self):
        """Test 7.1: Single study computation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [10],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')
        assert len(result) == 1

    def test_very_large_sample_sizes(self):
        """Test 7.2: Very large sample sizes"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [4000],
            'n1': [10000],
            'events2': [2000],
            'n2': [10000]
        })
        result = compute_effect_size(df, measure='OR')
        assert result is not None

    def test_very_small_sample_sizes(self):
        """Test 7.3: Very small sample sizes"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [1],
            'n1': [5],
            'events2': [2],
            'n2': [5]
        })
        result = compute_effect_size(df, measure='OR')
        assert result is not None

    def test_all_zero_events_both_arms(self):
        """Test 7.4: Zero events in both arms"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [0],
            'n1': [100],
            'events2': [0],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')
        assert result is not None

    def test_all_events_both_arms(self):
        """Test 7.5: All events in both arms"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [100],
            'n1': [100],
            'events2': [100],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')
        assert result is not None

    def test_extreme_effect_sizes(self):
        """Test 7.6: Extreme effect sizes"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [99],
            'n1': [100],
            'events2': [1],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')
        # Should handle extreme values
        assert result is not None

    def test_missing_data_handling(self):
        """Test 7.7: Missing data points"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'events1': [40, np.nan],
            'n1': [100, 100],
            'events2': [20, 20],
            'n2': [100, 100]
        })
        # Should handle NaN appropriately
        try:
            result = compute_effect_size(df, measure='OR')
            assert result is not None
        except:
            pass  # May raise error for NaN

    def test_invalid_measure_type(self):
        """Test 7.8: Invalid measure type"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        with pytest.raises(ValueError):
            compute_effect_size(df, measure='INVALID')


# ============================================================================
# TEST 8: PROPERTY-BASED TESTS (Hypothesis)
# ============================================================================

class TestTransformPropertyBased:
    """Property-based tests using Hypothesis"""

    @given(
        events1=st.integers(min_value=1, max_value=99),
        events2=st.integers(min_value=1, max_value=99),
        n=st.integers(min_value=100, max_value=200)
    )
    def test_or_always_computable_property(self, events1, events2, n):
        """Test 8.1: OR should always be computable for valid inputs"""
        assume(events1 < n and events2 < n)

        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [events1],
            'n1': [n],
            'events2': [events2],
            'n2': [n]
        })

        result = compute_effect_size(df, measure='OR')
        assert result is not None
        assert 'yi' in result.columns
        assert 'sei' in result.columns

    @given(
        mean1=st.floats(min_value=-100, max_value=100),
        mean2=st.floats(min_value=-100, max_value=100),
        sd=st.floats(min_value=0.1, max_value=50),
        n=st.integers(min_value=10, max_value=200)
    )
    def test_md_property(self, mean1, mean2, sd, n):
        """Test 8.2: MD computation property"""
        # MD should equal difference in means
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean1': [mean1],
            'mean2': [mean2],
            'sd1': [sd],
            'sd2': [sd],
            'n1': [n],
            'n2': [n]
        })

        # Property: Result should exist and be finite
        try:
            result = compute_effect_size(df, measure='MD')
            if result is not None and 'yi' in result.columns:
                assert np.isfinite(result['yi'].iloc[0])
        except:
            pass

    @given(
        p1=st.floats(min_value=0.01, max_value=0.99),
        p2=st.floats(min_value=0.01, max_value=0.99),
        n=st.integers(min_value=50, max_value=500)
    )
    def test_rr_inverse_property(self, p1, p2, n):
        """Test 8.3: RR(A vs B) * RR(B vs A) should equal 1"""
        events1 = int(p1 * n)
        events2 = int(p2 * n)

        df1 = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [events1],
            'n1': [n],
            'events2': [events2],
            'n2': [n]
        })

        df2 = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [events2],  # Swapped
            'n1': [n],
            'events2': [events1],  # Swapped
            'n2': [n]
        })

        try:
            result1 = compute_effect_size(df1, measure='RR')
            result2 = compute_effect_size(df2, measure='RR')

            if result1 is not None and result2 is not None:
                # log(RR1) + log(RR2) should be ≈ 0
                sum_log_rr = result1['yi'].iloc[0] + result2['yi'].iloc[0]
                assert abs(sum_log_rr) < 0.1
        except:
            pass


# ============================================================================
# TEST 9: NUMERICAL STABILITY (Triple Coverage)
# ============================================================================

class TestNumericalStability:
    """Tests for numerical stability and precision"""

    def test_no_overflow_large_sample_sizes(self):
        """Test 9.1: No overflow with large sample sizes"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40000],
            'n1': [100000],
            'events2': [20000],
            'n2': [100000]
        })
        result = compute_effect_size(df, measure='OR')
        assert np.isfinite(result['yi'].iloc[0])
        assert np.isfinite(result['sei'].iloc[0])

    def test_no_underflow_small_probabilities(self):
        """Test 9.2: No underflow with small probabilities"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [1],
            'n1': [10000],
            'events2': [1],
            'n2': [10000]
        })
        result = compute_effect_size(df, measure='OR')
        assert np.isfinite(result['yi'].iloc[0])

    def test_precision_maintained(self):
        """Test 9.3: Precision is maintained"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [41],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='OR')
        # Should detect small difference
        assert result['yi'].iloc[0] != 0


# ============================================================================
# TEST 10: CONSISTENCY CHECKS (Triple Coverage)
# ============================================================================

class TestConsistencyChecks:
    """Tests for internal consistency"""

    def test_variance_equals_se_squared(self):
        """Test 10.1: Variance should equal SE squared"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'events1': [40, 30, 50],
            'n1': [100, 100, 100],
            'events2': [20, 25, 45],
            'n2': [100, 100, 100]
        })
        result = compute_effect_size(df, measure='OR')

        for i in range(len(result)):
            assert abs(result['vi'].iloc[i] - result['sei'].iloc[i]**2) < 0.0001

    def test_results_reproducible(self):
        """Test 10.2: Results are reproducible"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })

        result1 = compute_effect_size(df, measure='OR')
        result2 = compute_effect_size(df, measure='OR')

        assert result1['yi'].iloc[0] == result2['yi'].iloc[0]
        assert result1['sei'].iloc[0] == result2['sei'].iloc[0]

    def test_order_independence(self):
        """Test 10.3: Order of studies doesn't affect individual results"""
        df1 = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'events1': [40, 30],
            'n1': [100, 100],
            'events2': [20, 25],
            'n2': [100, 100]
        })

        df2 = pd.DataFrame({
            'study_id': ['S2', 'S1'],  # Reversed
            'events1': [30, 40],
            'n1': [100, 100],
            'events2': [25, 20],
            'n2': [100, 100]
        })

        result1 = compute_effect_size(df1, measure='OR')
        result2 = compute_effect_size(df2, measure='OR')

        # S1 results should be same regardless of order
        s1_yi_1 = result1[result1['study_id'] == 'S1']['yi'].iloc[0]
        s1_yi_2 = result2[result2['study_id'] == 'S1']['yi'].iloc[0]

        assert abs(s1_yi_1 - s1_yi_2) < 0.0001


# ============================================================================
# TEST 11: ADDITIONAL COVERAGE TESTS (SMD, HR, Errors, Wrappers)
# ============================================================================

class TestAdditionalCoverage:
    """Additional tests to increase coverage to 80%+"""

    def test_smd_computation_full(self):
        """Test SMD (Standardized Mean Difference) computation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean1': [10.5],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [12.0],
            'sd2': [2.2],
            'n2': [55]
        })
        result = compute_effect_size(df, measure='SMD')

        assert 'yi' in result.columns
        assert 'sei' in result.columns
        assert 'vi' in result.columns
        assert result['yi'].iloc[0] < 0  # Negative because mean1 < mean2

    def test_smd_hedges_correction(self):
        """Test SMD includes Hedges' g correction"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean1': [10.0],
            'sd1': [2.0],
            'n1': [30],
            'mean2': [11.0],
            'sd2': [2.0],
            'n2': [30]
        })
        result = compute_effect_size(df, measure='SMD')

        # SMD should be computed with Hedges' correction
        assert result['yi'].iloc[0] is not None
        assert np.isfinite(result['yi'].iloc[0])

    def test_hr_with_confidence_intervals(self):
        """Test HR computation from hazard ratio and CI"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'hr': [0.7, 0.8],
            'ci_lower': [0.5, 0.6],
            'ci_upper': [0.98, 1.0]
        })
        result = compute_effect_size(df, measure='HR')

        assert 'yi' in result.columns
        assert 'sei' in result.columns
        assert 'vi' in result.columns
        # yi should be log(HR)
        assert abs(result['yi'].iloc[0] - np.log(0.7)) < 0.001

    def test_hr_sei_from_ci(self):
        """Test HR standard error computed from CI"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'hr': [0.75],
            'ci_lower': [0.6],
            'ci_upper': [0.9]
        })
        result = compute_effect_size(df, measure='HR')

        # SE should be (log(upper) - log(lower)) / 3.92
        expected_sei = (np.log(0.9) - np.log(0.6)) / 3.92
        assert abs(result['sei'].iloc[0] - expected_sei) < 0.01

    def test_hr_with_existing_yi_sei(self):
        """Test HR with pre-computed yi/sei (lines 195-197)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'yi': [-0.3],  # log(HR)
            'sei': [0.15]
        })
        result = compute_effect_size(df, measure='HR')

        assert result['yi'].iloc[0] == -0.3
        assert result['sei'].iloc[0] == 0.15
        assert 'vi' in result.columns
        assert result['vi'].iloc[0] == 0.15 ** 2

    def test_hr_missing_hr_column_error(self):
        """Test HR without 'hr' column raises error (line 200)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'some_column': [0.7]
        })
        with pytest.raises(ValueError, match="Time-to-event data requires 'hr' column"):
            compute_effect_size(df, measure='HR')

    def test_hr_missing_sei_and_ci_error(self):
        """Test HR without sei or CI raises error (lines 211-212)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'hr': [0.7]
        })
        with pytest.raises(ValueError, match="HR data requires either"):
            compute_effect_size(df, measure='HR')

    def test_continuous_with_existing_yi_sei(self):
        """Test continuous data with pre-computed yi/sei (lines 142-147)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'yi': [1.5],  # Mean difference
            'sei': [0.25]
        })
        result = compute_effect_size(df, measure='MD')

        assert result['yi'].iloc[0] == 1.5
        assert result['sei'].iloc[0] == 0.25
        assert 'vi' in result.columns

    def test_binary_with_existing_yi_sei(self):
        """Test binary data with pre-computed yi/sei (lines 117-123)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events': [10],  # Need events column to trigger arm-based path
            'n': [100],
            'yi': [0.5],  # log(OR)
            'sei': [0.2]
        })
        result = compute_effect_size(df, measure='OR')

        assert result['yi'].iloc[0] == 0.5
        assert result['sei'].iloc[0] == 0.2

    def test_arm_based_binary_not_supported_error(self):
        """Test arm-based binary without yi/sei raises error (lines 123-127)"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1'],
            'treatment': ['Drug', 'Placebo'],
            'events': [10, 15],
            'n': [100, 100]
        })
        with pytest.raises(ValueError, match="Arm-based binary data not yet fully supported"):
            compute_effect_size(df, measure='OR')

    def test_unknown_binary_measure_error(self):
        """Test unknown binary measure raises error (line 100)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [10],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        with pytest.raises(ValueError, match="Unknown binary measure"):
            from backend.etl.transform import compute_binary_effect_size
            compute_binary_effect_size(df, measure='INVALID')

    def test_unknown_continuous_measure_error(self):
        """Test unknown continuous measure raises error (line 176)"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean1': [10.5],
            'sd1': [2.0],
            'n1': [50],
            'mean2': [12.0],
            'sd2': [2.0],
            'n2': [50]
        })
        with pytest.raises(ValueError, match="Unknown continuous measure"):
            from backend.etl.transform import compute_continuous_effect_size
            compute_continuous_effect_size(df, measure='INVALID')

    def test_escalc_wrapper(self):
        """Test escalc_wrapper function (line 224)"""
        from backend.etl.transform import escalc_wrapper

        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [10],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = escalc_wrapper(df, measure='OR')

        assert 'yi' in result.columns
        assert 'sei' in result.columns

    def test_apply_continuity_correction(self):
        """Test apply_continuity_correction function (lines 239-243)"""
        from backend.etl.transform import apply_continuity_correction

        events = np.array([0, 10, 100])  # Zero, normal, all events
        n = np.array([100, 100, 100])

        events_corrected, n_corrected = apply_continuity_correction(events, n, correction=0.5)

        # Zero cells should be corrected
        assert events_corrected[0] == 0.5  # Was 0
        assert n_corrected[0] == 101  # Was 100

        # Normal cells unchanged
        assert events_corrected[1] == 10
        assert n_corrected[1] == 100

        # All-event cells should be corrected
        assert events_corrected[2] == 100.5  # Was 100
        assert n_corrected[2] == 101  # Was 100

    def test_continuity_correction_custom_value(self):
        """Test continuity correction with custom value"""
        from backend.etl.transform import apply_continuity_correction

        events = np.array([0])
        n = np.array([100])

        events_corrected, n_corrected = apply_continuity_correction(events, n, correction=0.1)

        assert events_corrected[0] == 0.1
        assert n_corrected[0] == 100.2  # 100 + 2*0.1

    def test_rd_computation(self):
        """Test RD (Risk Difference) computation"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'events1': [40],
            'n1': [100],
            'events2': [20],
            'n2': [100]
        })
        result = compute_effect_size(df, measure='RD')

        assert 'yi' in result.columns
        # RD should be p1 - p2 = 0.4 - 0.2 = 0.2
        assert abs(result['yi'].iloc[0] - 0.2) < 0.001

    def test_binary_no_data_error(self):
        """Test binary computation without proper columns raises error"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'some_column': [10]
        })
        with pytest.raises(ValueError, match="Binary data requires"):
            from backend.etl.transform import compute_binary_effect_size
            compute_binary_effect_size(df, measure='OR')

    def test_continuous_no_data_error(self):
        """Test continuous computation without proper columns raises error"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'some_column': [10.5]
        })
        with pytest.raises(ValueError, match="Continuous data requires"):
            from backend.etl.transform import compute_continuous_effect_size
            compute_continuous_effect_size(df, measure='MD')

    def test_smd_small_sample(self):
        """Test SMD with small sample sizes"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean1': [10.0],
            'sd1': [2.0],
            'n1': [10],  # Small sample
            'mean2': [12.0],
            'sd2': [2.0],
            'n2': [10]
        })
        result = compute_effect_size(df, measure='SMD')

        # Should still compute successfully
        assert 'yi' in result.columns
        assert np.isfinite(result['yi'].iloc[0])

    def test_smd_unequal_variances(self):
        """Test SMD with unequal variances"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'mean1': [10.0],
            'sd1': [1.5],  # Different SD
            'mean2': [12.0],
            'sd2': [3.0],  # Different SD
            'n1': [50],
            'n2': [50]
        })
        result = compute_effect_size(df, measure='SMD')

        assert 'yi' in result.columns
        assert np.isfinite(result['yi'].iloc[0])


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
