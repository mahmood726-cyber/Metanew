"""
Tests for data transformation module
"""
import pytest
import pandas as pd
import numpy as np
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.transform import compute_effect_size, compute_binary_effect_size


def test_compute_or_from_2x2():
    """Test OR computation from 2x2 table"""
    df = pd.DataFrame({
        'study_id': ['S1'],
        'events1': [20],
        'n1': [100],
        'events2': [30],
        'n2': [100]
    })

    result = compute_effect_size(df, 'OR')

    assert 'yi' in result.columns
    assert 'sei' in result.columns
    assert 'vi' in result.columns
    assert result['yi'].iloc[0] < 0  # OR < 1, so log(OR) < 0


def test_compute_md_from_continuous():
    """Test mean difference computation"""
    df = pd.DataFrame({
        'study_id': ['S1'],
        'mean1': [10.0],
        'sd1': [2.0],
        'n1': [50],
        'mean2': [8.0],
        'sd2': [2.0],
        'n2': [50]
    })

    result = compute_effect_size(df, 'MD')

    assert 'yi' in result.columns
    assert result['yi'].iloc[0] == pytest.approx(2.0)


def test_compute_hr_from_ci():
    """Test HR effect size from confidence intervals"""
    df = pd.DataFrame({
        'study_id': ['S1'],
        'hr': [0.7],
        'ci_lower': [0.5],
        'ci_upper': [0.9]
    })

    result = compute_effect_size(df, 'HR')

    assert 'yi' in result.columns
    assert 'sei' in result.columns
    assert result['yi'].iloc[0] == pytest.approx(np.log(0.7))


def test_continuity_correction():
    """Test continuity correction for zero cells"""
    df = pd.DataFrame({
        'study_id': ['S1'],
        'events1': [0],
        'n1': [100],
        'events2': [10],
        'n2': [100]
    })

    result = compute_effect_size(df, 'OR')

    # Should apply continuity correction
    assert 'yi' in result.columns
    assert not np.isnan(result['yi'].iloc[0])
    assert not np.isinf(result['yi'].iloc[0])


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
