"""
Tests for validation module
"""
import pytest
import pandas as pd
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.validate import validate_table, validate_binary_data


def test_validate_binary_data_valid():
    """Test validation with valid binary data"""
    df = pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'treatment': ['A', 'B'],
        'events': [10, 20],
        'n': [100, 200]
    })

    result = validate_table(df, 'binary')
    assert result.is_valid == True
    assert result.summary['errors'] == 0


def test_validate_binary_data_events_exceeds_n():
    """Test validation when events exceed n"""
    df = pd.DataFrame({
        'study_id': ['S1'],
        'treatment': ['A'],
        'events': [150],
        'n': [100]
    })

    result = validate_table(df, 'binary')
    assert result.is_valid == False
    assert result.summary['errors'] > 0


def test_validate_missing_required_columns():
    """Test validation with missing required columns"""
    df = pd.DataFrame({
        'events': [10, 20],
        'n': [100, 200]
    })

    result = validate_table(df, 'binary')
    assert result.is_valid == False


def test_validate_effect_size_data():
    """Test validation with effect size data"""
    df = pd.DataFrame({
        'study_id': ['S1', 'S2'],
        'treatment': ['A', 'B'],
        'yi': [0.5, 0.7],
        'sei': [0.1, 0.15]
    })

    result = validate_table(df, 'effect_size')
    assert result.is_valid == True


def test_validate_negative_se():
    """Test validation with negative standard error"""
    df = pd.DataFrame({
        'study_id': ['S1'],
        'treatment': ['A'],
        'yi': [0.5],
        'sei': [-0.1]
    })

    result = validate_table(df, 'binary')
    assert result.is_valid == False


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
