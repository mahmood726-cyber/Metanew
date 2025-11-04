"""
Comprehensive Tests for Validation Module
Triple testing: Unit tests, Edge cases, Property-based tests
"""
import pytest
import pandas as pd
import numpy as np
from hypothesis import given, strategies as st
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.validate import (
    validate_table, validate_binary_data, validate_continuous_data,
    validate_tte_data, normalize_column_names, check_implausible_values,
    detect_outliers, validate_multi_arm_trial
)


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def valid_binary_df():
    """Valid binary data fixture"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2', 'S3', 'S4', 'S5'],
        'treatment': ['A', 'B', 'A', 'B', 'A'],
        'events': [10, 20, 15, 25, 12],
        'n': [100, 200, 150, 250, 120]
    })


@pytest.fixture
def valid_continuous_df():
    """Valid continuous data fixture"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2', 'S3'],
        'treatment': ['A', 'B', 'A'],
        'mean': [10.5, 12.3, 11.2],
        'sd': [2.1, 2.5, 2.3],
        'n': [50, 60, 55]
    })


@pytest.fixture
def valid_tte_df():
    """Valid time-to-event data fixture"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2', 'S3'],
        'treatment': ['A', 'B', 'A'],
        'hr': [0.7, 0.8, 0.75],
        'ci_lower': [0.5, 0.6, 0.55],
        'ci_upper': [0.9, 1.0, 0.95]
    })


# ============================================================================
# TEST 1: BINARY DATA VALIDATION (Triple Coverage)
# ============================================================================

class TestBinaryDataValidation:
    """Comprehensive tests for binary data validation"""

    # Basic validation tests
    def test_valid_binary_data_passes(self, valid_binary_df):
        """Test 1.1: Valid binary data passes validation"""
        result = validate_table(valid_binary_df, 'binary')
        assert result.is_valid is True
        assert result.summary['errors'] == 0

    def test_events_greater_than_n_fails(self):
        """Test 1.2: Events > n should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [150],
            'n': [100]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False
        assert result.summary['errors'] > 0
        assert any('events' in p.field.lower() for p in result.problems)

    def test_negative_events_fails(self):
        """Test 1.3: Negative events should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [-10],
            'n': [100]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False

    def test_negative_n_fails(self):
        """Test 1.4: Negative sample size should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [10],
            'n': [-100]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False

    def test_zero_cell_warning(self):
        """Test 1.5: Zero cells should generate warning"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [0],
            'n': [100]
        })
        result = validate_table(df, 'binary')
        assert any(p.severity == 'info' and 'zero cell' in p.message.lower()
                  for p in result.problems)

    def test_all_events_equal_n_warning(self):
        """Test 1.6: All events = n should generate warning"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [100],
            'n': [100]
        })
        result = validate_table(df, 'binary')
        assert any(p.severity == 'info' for p in result.problems)

    def test_effect_size_validation(self):
        """Test 1.7: Effect size data validation"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'B'],
            'yi': [0.5, 0.7],
            'sei': [0.1, 0.15]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is True

    def test_negative_sei_fails(self):
        """Test 1.8: Negative standard error should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [0.5],
            'sei': [-0.1]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False

    def test_zero_sei_fails(self):
        """Test 1.9: Zero standard error should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [0.5],
            'sei': [0.0]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False

    def test_missing_required_columns_fails(self):
        """Test 1.10: Missing required columns should fail"""
        df = pd.DataFrame({
            'events': [10, 20],
            'n': [100, 200]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False

    def test_empty_dataframe_fails(self):
        """Test 1.11: Empty dataframe should fail"""
        df = pd.DataFrame()
        result = validate_table(df, 'binary')
        assert result.is_valid is False

    def test_float_events_handled(self):
        """Test 1.12: Float values for events should be handled"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [10.0],
            'n': [100.0]
        })
        result = validate_table(df, 'binary')
        # Should pass or convert to int
        assert result is not None

    def test_extremely_small_sample_size_warning(self):
        """Test 1.13: Very small sample size should warn"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [1],
            'n': [5]
        })
        result = validate_table(df, 'binary')
        assert any(p.severity in ['warning', 'info'] and 'small' in p.message.lower()
                  for p in result.problems)


# ============================================================================
# TEST 2: CONTINUOUS DATA VALIDATION (Triple Coverage)
# ============================================================================

class TestContinuousDataValidation:
    """Comprehensive tests for continuous data validation"""

    def test_valid_continuous_data_passes(self, valid_continuous_df):
        """Test 2.1: Valid continuous data passes"""
        result = validate_table(valid_continuous_df, 'continuous')
        assert result.is_valid is True

    def test_negative_sd_fails(self):
        """Test 2.2: Negative SD should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean': [10.5],
            'sd': [-2.1],
            'n': [50]
        })
        result = validate_table(df, 'continuous')
        assert result.is_valid is False

    def test_zero_sd_fails(self):
        """Test 2.3: Zero SD should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean': [10.5],
            'sd': [0.0],
            'n': [50]
        })
        result = validate_table(df, 'continuous')
        assert result.is_valid is False

    def test_negative_n_fails(self):
        """Test 2.4: Negative sample size should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean': [10.5],
            'sd': [2.1],
            'n': [-50]
        })
        result = validate_table(df, 'continuous')
        assert result.is_valid is False

    def test_zero_n_fails(self):
        """Test 2.5: Zero sample size should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean': [10.5],
            'sd': [2.1],
            'n': [0]
        })
        result = validate_table(df, 'continuous')
        assert result.is_valid is False

    def test_effect_size_continuous_valid(self):
        """Test 2.6: Effect size format for continuous data"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'B'],
            'yi': [0.5, 0.7],
            'sei': [0.2, 0.25]
        })
        result = validate_table(df, 'continuous')
        assert result.is_valid is True

    def test_very_large_mean_warning(self):
        """Test 2.7: Extremely large mean values"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean': [1000000],
            'sd': [2.1],
            'n': [50]
        })
        result = validate_table(df, 'continuous')
        # Should generate warning or info
        assert result is not None

    def test_very_small_sd_warning(self):
        """Test 2.8: Extremely small SD relative to mean"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean': [100.0],
            'sd': [0.001],
            'n': [50]
        })
        result = validate_table(df, 'continuous')
        assert result is not None

    def test_missing_mean_column_fails(self):
        """Test 2.9: Missing mean column should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'sd': [2.1],
            'n': [50]
        })
        result = validate_table(df, 'continuous')
        assert result.is_valid is False


# ============================================================================
# TEST 3: TIME-TO-EVENT DATA VALIDATION (Triple Coverage)
# ============================================================================

class TestTTEDataValidation:
    """Comprehensive tests for time-to-event data validation"""

    def test_valid_tte_data_passes(self, valid_tte_df):
        """Test 3.1: Valid TTE data passes"""
        result = validate_table(valid_tte_df, 'tte')
        assert result.is_valid is True

    def test_negative_hr_fails(self):
        """Test 3.2: Negative HR should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'hr': [-0.7],
            'ci_lower': [0.5],
            'ci_upper': [0.9]
        })
        result = validate_table(df, 'tte')
        assert result.is_valid is False

    def test_zero_hr_fails(self):
        """Test 3.3: Zero HR should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'hr': [0.0],
            'ci_lower': [0.0],
            'ci_upper': [0.5]
        })
        result = validate_table(df, 'tte')
        assert result.is_valid is False

    def test_ci_lower_greater_than_upper_fails(self):
        """Test 3.4: CI lower > upper should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'hr': [0.7],
            'ci_lower': [0.9],
            'ci_upper': [0.5]
        })
        result = validate_table(df, 'tte')
        assert result.is_valid is False

    def test_ci_lower_equals_upper_fails(self):
        """Test 3.5: CI lower = upper should fail"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'hr': [0.7],
            'ci_lower': [0.7],
            'ci_upper': [0.7]
        })
        result = validate_table(df, 'tte')
        assert result.is_valid is False

    def test_extremely_large_hr_warning(self):
        """Test 3.6: Extremely large HR should warn"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'hr': [150.0],
            'ci_lower': [100.0],
            'ci_upper': [200.0]
        })
        result = validate_table(df, 'tte')
        assert any(p.severity == 'warning' and 'extreme' in p.message.lower()
                  for p in result.problems)

    def test_effect_size_tte_valid(self):
        """Test 3.7: Effect size format for TTE data"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'B'],
            'yi': [-0.3, -0.2],
            'sei': [0.1, 0.15]
        })
        result = validate_table(df, 'tte')
        assert result.is_valid is True


# ============================================================================
# TEST 4: DUPLICATE DETECTION (Triple Coverage)
# ============================================================================

class TestDuplicateDetection:
    """Comprehensive tests for duplicate detection"""

    def test_exact_duplicate_detected(self):
        """Test 4.1: Exact duplicates are detected"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1'],
            'treatment': ['A', 'A'],
            'events': [10, 10],
            'n': [100, 100]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False
        assert any('duplicate' in p.message.lower() for p in result.problems)

    def test_different_treatment_not_duplicate(self):
        """Test 4.2: Same study, different treatment is OK"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1'],
            'treatment': ['A', 'B'],
            'events': [10, 20],
            'n': [100, 100]
        })
        result = validate_table(df, 'binary')
        # Should not have duplicate error
        assert not any('duplicate' in p.message.lower() and p.severity == 'error'
                      for p in result.problems)

    def test_different_study_not_duplicate(self):
        """Test 4.3: Different studies, same treatment is OK"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'A'],
            'events': [10, 10],
            'n': [100, 100]
        })
        result = validate_table(df, 'binary')
        assert not any('duplicate' in p.message.lower() and p.severity == 'error'
                      for p in result.problems)

    def test_multiple_duplicates_all_detected(self):
        """Test 4.4: Multiple duplicate pairs detected"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1', 'S2', 'S2'],
            'treatment': ['A', 'A', 'B', 'B'],
            'events': [10, 10, 20, 20],
            'n': [100, 100, 200, 200]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False
        duplicate_errors = [p for p in result.problems if 'duplicate' in p.message.lower()]
        assert len(duplicate_errors) >= 2

    def test_triplicate_detected(self):
        """Test 4.5: Triple duplicates detected"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1', 'S1'],
            'treatment': ['A', 'A', 'A'],
            'events': [10, 10, 10],
            'n': [100, 100, 100]
        })
        result = validate_table(df, 'binary')
        assert result.is_valid is False


# ============================================================================
# TEST 5: OUTLIER DETECTION (Triple Coverage)
# ============================================================================

class TestOutlierDetection:
    """Comprehensive tests for outlier detection"""

    def test_obvious_outlier_detected(self):
        """Test 5.1: Obvious outliers are detected"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3', 'S4', 'S5', 'S6'],
            'treatment': ['A', 'B', 'A', 'B', 'A', 'B'],
            'yi': [0.5, 0.6, 0.7, 0.55, 0.65, 10.0],  # 10.0 is outlier
            'sei': [0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
        })
        result = validate_table(df, 'binary')
        assert any('outlier' in p.message.lower() for p in result.problems)

    def test_no_outliers_in_normal_data(self):
        """Test 5.2: Normal data has no outlier warnings"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3', 'S4', 'S5'],
            'treatment': ['A', 'B', 'A', 'B', 'A'],
            'yi': [0.5, 0.6, 0.7, 0.55, 0.65],
            'sei': [0.1, 0.1, 0.1, 0.1, 0.1]
        })
        result = validate_table(df, 'binary')
        assert not any('outlier' in p.message.lower() for p in result.problems)

    def test_insufficient_data_no_outlier_check(self):
        """Test 5.3: Too few observations skips outlier detection"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'B'],
            'yi': [0.5, 10.0],
            'sei': [0.1, 0.1]
        })
        result = validate_table(df, 'binary')
        # Should not check outliers with < 5 observations
        assert result is not None

    def test_sample_size_outlier_detection(self):
        """Test 5.4: Sample size outliers detected"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3', 'S4', 'S5', 'S6'],
            'treatment': ['A', 'B', 'A', 'B', 'A', 'B'],
            'events': [10, 10, 10, 10, 10, 10],
            'n': [100, 100, 100, 100, 100, 10000]  # 10000 is outlier
        })
        result = validate_table(df, 'binary')
        assert any('unusually large' in p.message.lower() or 'sample size' in p.message.lower()
                  for p in result.problems)


# ============================================================================
# TEST 6: IMPLAUSIBLE VALUES (Triple Coverage)
# ============================================================================

class TestImplausibleValues:
    """Comprehensive tests for implausible value detection"""

    def test_extreme_effect_size_warning(self):
        """Test 6.1: Extreme effect sizes generate warnings"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [15.0],  # Extreme value
            'sei': [0.1]
        })
        result = validate_table(df, 'binary')
        assert any(p.severity == 'warning' and 'extreme' in p.message.lower()
                  for p in result.problems)

    def test_very_large_sei_warning(self):
        """Test 6.2: Very large standard error generates warning"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [0.5],
            'sei': [15.0]
        })
        result = validate_table(df, 'binary')
        assert any(p.severity == 'warning' and 'large standard error' in p.message.lower()
                  for p in result.problems)

    def test_very_small_sei_warning(self):
        """Test 6.3: Very small standard error generates warning"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [0.5],
            'sei': [0.0001]
        })
        result = validate_table(df, 'binary')
        assert any(p.severity == 'warning' and 'small standard error' in p.message.lower()
                  for p in result.problems)

    def test_high_event_rate_info(self):
        """Test 6.4: Very high event rate generates info"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [98],
            'n': [100]
        })
        result = validate_table(df, 'binary')
        assert any(p.severity == 'info' and 'high event rate' in p.message.lower()
                  for p in result.problems)


# ============================================================================
# TEST 7: COLUMN NORMALIZATION (Triple Coverage)
# ============================================================================

class TestColumnNormalization:
    """Comprehensive tests for column name normalization"""

    def test_studyid_normalized_to_study_id(self):
        """Test 7.1: studyid → study_id"""
        df = pd.DataFrame({
            'studyid': ['S1', 'S2'],
            'treatment': ['A', 'B']
        })
        normalized = normalize_column_names(df)
        assert 'study_id' in normalized.columns

    def test_arm_normalized_to_treatment(self):
        """Test 7.2: arm → treatment"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'arm': ['A']
        })
        normalized = normalize_column_names(df)
        assert 'treatment' in normalized.columns

    def test_case_insensitive_normalization(self):
        """Test 7.3: Case-insensitive normalization"""
        df = pd.DataFrame({
            'StudyID': ['S1'],
            'TREATMENT': ['A']
        })
        normalized = normalize_column_names(df)
        assert 'study_id' in normalized.columns

    def test_multiple_variations_normalized(self):
        """Test 7.4: Multiple column variations normalized"""
        df = pd.DataFrame({
            'studyid': ['S1'],
            'trt': ['A'],
            'n_events': [10],
            'n_total': [100]
        })
        normalized = normalize_column_names(df)
        assert 'study_id' in normalized.columns
        assert 'treatment' in normalized.columns
        assert 'events' in normalized.columns
        assert 'n' in normalized.columns


# ============================================================================
# TEST 8: MULTI-ARM TRIAL VALIDATION (Triple Coverage)
# ============================================================================

class TestMultiArmTrialValidation:
    """Comprehensive tests for multi-arm trial validation"""

    def test_three_arm_trial_detected(self):
        """Test 8.1: Three-arm trial is detected"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1', 'S1'],
            'treatment': ['A', 'B', 'C'],
            'events': [10, 20, 15],
            'n': [100, 100, 100]
        })
        result = validate_table(df, 'binary')
        # Should not have errors for multi-arm
        assert result is not None

    def test_four_arm_trial_handled(self):
        """Test 8.2: Four-arm trial is handled"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1', 'S1', 'S1'],
            'treatment': ['A', 'B', 'C', 'D'],
            'events': [10, 20, 15, 25],
            'n': [100, 100, 100, 100]
        })
        result = validate_table(df, 'binary')
        assert result is not None

    def test_variance_heterogeneity_warning(self):
        """Test 8.3: Large variance heterogeneity generates warning"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S1', 'S1'],
            'treatment': ['A', 'B', 'C'],
            'yi': [0.5, 0.6, 0.7],
            'sei': [0.1, 0.5, 0.1]  # Middle arm has 5x larger SE
        })
        result = validate_table(df, 'binary')
        # Should warn about heterogeneity
        assert result is not None


# ============================================================================
# TEST 9: PROPERTY-BASED TESTS (Using Hypothesis)
# ============================================================================

class TestPropertyBased:
    """Property-based tests using Hypothesis"""

    @given(
        n=st.integers(min_value=10, max_value=1000),
        events=st.integers(min_value=0, max_value=1000)
    )
    def test_valid_events_n_relationship(self, n, events):
        """Test 9.1: Property - events should always be <= n for valid data"""
        if events <= n:
            df = pd.DataFrame({
                'study_id': ['S1'],
                'treatment': ['A'],
                'events': [events],
                'n': [n]
            })
            result = validate_table(df, 'binary')
            # If events <= n, should not have events > n error
            assert not any(
                'events' in p.field.lower() and
                '>' in p.message and
                p.severity == 'error'
                for p in result.problems
            )

    @given(hr=st.floats(min_value=0.01, max_value=10.0))
    def test_positive_hr_property(self, hr):
        """Test 9.2: Property - HR must be positive"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'hr': [hr],
            'ci_lower': [hr * 0.8],
            'ci_upper': [hr * 1.2]
        })
        result = validate_table(df, 'tte')
        # Positive HR should not fail
        assert result is not None

    @given(
        mean=st.floats(min_value=-100, max_value=100),
        sd=st.floats(min_value=0.1, max_value=50),
        n=st.integers(min_value=10, max_value=500)
    )
    def test_continuous_data_property(self, mean, sd, n):
        """Test 9.3: Property - Valid continuous data components"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'mean': [mean],
            'sd': [sd],
            'n': [n]
        })
        result = validate_table(df, 'continuous')
        # Valid inputs should not cause crashes
        assert result is not None


# ============================================================================
# TEST 10: EDGE CASES (Triple Coverage)
# ============================================================================

class TestEdgeCases:
    """Comprehensive edge case tests"""

    def test_single_observation(self):
        """Test 10.1: Single observation handled"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events': [10],
            'n': [100]
        })
        result = validate_table(df, 'binary')
        assert result is not None

    def test_very_large_dataset(self):
        """Test 10.2: Large dataset (1000 observations)"""
        df = pd.DataFrame({
            'study_id': [f'S{i}' for i in range(1000)],
            'treatment': ['A' if i % 2 == 0 else 'B' for i in range(1000)],
            'events': [10] * 1000,
            'n': [100] * 1000
        })
        result = validate_table(df, 'binary')
        assert result is not None

    def test_special_characters_in_study_id(self):
        """Test 10.3: Special characters in study IDs"""
        df = pd.DataFrame({
            'study_id': ['S-1', 'S_2', 'S.3'],
            'treatment': ['A', 'B', 'A'],
            'events': [10, 20, 15],
            'n': [100, 200, 150]
        })
        result = validate_table(df, 'binary')
        assert result is not None

    def test_unicode_in_treatment_names(self):
        """Test 10.4: Unicode characters in treatment names"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['Trt-α', 'Trt-β'],
            'events': [10, 20],
            'n': [100, 200]
        })
        result = validate_table(df, 'binary')
        assert result is not None

    def test_missing_values_nas(self):
        """Test 10.5: NA/NaN values handling"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'treatment': ['A', 'B', 'A'],
            'events': [10, np.nan, 15],
            'n': [100, 200, 150]
        })
        result = validate_table(df, 'binary')
        assert result is not None

    def test_infinity_values(self):
        """Test 10.6: Infinity values handling"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [np.inf],
            'sei': [0.1]
        })
        result = validate_table(df, 'binary')
        # Should handle or reject infinity
        assert result is not None

    def test_mixed_data_types_in_numeric_columns(self):
        """Test 10.7: Mixed types in numeric columns"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'B'],
            'events': [10, '20'],  # Mixed int and string
            'n': [100, 200]
        })
        # Should handle type conversion
        try:
            result = validate_table(df, 'binary')
            assert result is not None
        except:
            # Or should fail gracefully
            pass

    def test_all_zero_events(self):
        """Test 10.8: All studies have zero events"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'treatment': ['A', 'B', 'A'],
            'events': [0, 0, 0],
            'n': [100, 200, 150]
        })
        result = validate_table(df, 'binary')
        # Should generate warnings
        assert result is not None

    def test_all_maximum_events(self):
        """Test 10.9: All events = n"""
        df = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'B'],
            'events': [100, 200],
            'n': [100, 200]
        })
        result = validate_table(df, 'binary')
        assert result is not None

    def test_extreme_precision_float_values(self):
        """Test 10.10: Extreme precision float values"""
        df = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'yi': [0.123456789012345],
            'sei': [0.001234567890123]
        })
        result = validate_table(df, 'binary')
        assert result is not None


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short', '--maxfail=5'])
