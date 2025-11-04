"""
MAIC Engine Test Suite
======================

Comprehensive tests for MAIC/STC implementation.

Tests:
1. Data validation
2. Weight calculation
3. ESS calculation
4. Balance diagnostics
5. Treatment effect estimation
6. Validation checks
7. Edge cases
8. Error handling
"""

import pytest
import numpy as np
import pandas as pd
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from backend.stats.maic_engine import MAICEngine, MAICData, MAICResults


class TestMAICDataValidation:
    """Test data validation rules"""

    def test_valid_data_passes(self):
        """Test that valid data passes validation"""
        np.random.seed(42)

        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, 100),
            'sex': np.random.binomial(1, 0.5, 100),
            'treatment': np.ones(100),
            'outcome': np.random.normal(10, 5, 100)
        })

        agd = pd.DataFrame({
            'age': [55],
            'sex': [0.6]
        })

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes={'mean': 7.0, 'se': 0.5},
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        # Should not raise exception
        engine._validate_data(data)

    def test_missing_variable_fails(self):
        """Test that missing variables are caught"""
        ipd = pd.DataFrame({
            'age': [60, 65, 70],
            'outcome': [10, 11, 12],
            'treatment': [1, 1, 1]
        })

        agd = pd.DataFrame({
            'age': [55],
            'sex': [0.5]  # sex not in IPD
        })

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes={'mean': 7.0},
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        with pytest.raises(ValueError, match="missing in IPD"):
            engine._validate_data(data)

    def test_missing_data_fails(self):
        """Test that missing data is caught"""
        ipd = pd.DataFrame({
            'age': [60, np.nan, 70],
            'sex': [0, 1, 0],
            'outcome': [10, 11, 12],
            'treatment': [1, 1, 1]
        })

        agd = pd.DataFrame({
            'age': [55],
            'sex': [0.5]
        })

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes={'mean': 7.0},
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        with pytest.raises(ValueError, match="Missing data"):
            engine._validate_data(data)

    def test_zero_rows_fails(self):
        """Test that empty IPD is caught"""
        ipd = pd.DataFrame({
            'age': [],
            'sex': [],
            'outcome': [],
            'treatment': []
        })

        agd = pd.DataFrame({
            'age': [55],
            'sex': [0.5]
        })

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes={'mean': 7.0},
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        with pytest.raises(ValueError, match="zero rows"):
            engine._validate_data(data)


class TestMAICWeightCalculation:
    """Test weight optimization"""

    def test_weights_sum_to_n(self):
        """Test that weights sum to sample size"""
        np.random.seed(42)

        n = 100
        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, n),
            'sex': np.random.binomial(1, 0.5, n)
        })

        agd = pd.DataFrame({
            'age': [55],
            'sex': [0.6]
        })

        engine = MAICEngine()
        weights = engine._optimize_weights(ipd, agd, ['age', 'sex'])

        # Weights should sum to n (within numerical precision)
        assert abs(weights.sum() - n) < 1e-6, f"Weights sum to {weights.sum()}, expected {n}"

    def test_weights_positive(self):
        """Test that all weights are positive"""
        np.random.seed(42)

        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, 50),
            'sex': np.random.binomial(1, 0.5, 50)
        })

        agd = pd.DataFrame({
            'age': [55],
            'sex': [0.6]
        })

        engine = MAICEngine()
        weights = engine._optimize_weights(ipd, agd, ['age', 'sex'])

        assert np.all(weights > 0), "Some weights are not positive"

    def test_weights_achieve_balance(self):
        """Test that weights achieve covariate balance"""
        np.random.seed(42)

        n = 200
        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, n),
            'sex': np.random.binomial(1, 0.5, n)
        })

        agd = pd.DataFrame({
            'age': [55],
            'sex': [0.6]
        })

        engine = MAICEngine()
        weights = engine._optimize_weights(ipd, agd, ['age', 'sex'])

        # Check weighted means match target
        weighted_age = np.average(ipd['age'].values, weights=weights)
        weighted_sex = np.average(ipd['sex'].values, weights=weights)

        # Should be close to AgD means (within 0.01)
        assert abs(weighted_age - 55) < 0.1, f"Weighted age {weighted_age}, target 55"
        assert abs(weighted_sex - 0.6) < 0.01, f"Weighted sex {weighted_sex}, target 0.6"


class TestMAICESS:
    """Test effective sample size calculation"""

    def test_ess_without_weights_equals_n(self):
        """Test that ESS of uniform weights equals n"""
        n = 100
        weights = np.ones(n)

        engine = MAICEngine()
        ess = engine._calculate_ess(weights)

        assert abs(ess - n) < 1e-6, f"ESS {ess}, expected {n}"

    def test_ess_with_extreme_weights_is_low(self):
        """Test that extreme weights reduce ESS"""
        # One huge weight, rest tiny
        weights = np.ones(100)
        weights[0] = 90
        weights[1:] = 10 / 99

        engine = MAICEngine()
        ess = engine._calculate_ess(weights)

        # ESS should be much less than 100
        assert ess < 50, f"ESS {ess} should be < 50 with extreme weights"

    def test_ess_formula_correct(self):
        """Test ESS formula: (sum w)^2 / (sum w^2)"""
        weights = np.array([1, 2, 3, 4, 5])

        engine = MAICEngine()
        ess = engine._calculate_ess(weights)

        # Manual calculation
        expected_ess = (np.sum(weights)**2) / np.sum(weights**2)

        assert abs(ess - expected_ess) < 1e-6


class TestMAICBalanceDiagnostics:
    """Test balance diagnostics calculation"""

    def test_balance_calculates_smd(self):
        """Test that SMD is calculated correctly"""
        ipd = pd.DataFrame({
            'age': [60, 65, 70, 55, 50],
            'sex': [0, 1, 1, 0, 1]
        })

        agd = pd.DataFrame({
            'age': [60],  # Same mean
            'sex': [0.6]  # Same mean
        })

        engine = MAICEngine()
        balance = engine._calculate_balance(ipd, agd, ['age', 'sex'], weights=None)

        # Check structure
        assert 'variable' in balance.columns
        assert 'smd' in balance.columns
        assert 'balanced' in balance.columns

        # Check all variables present
        assert set(balance['variable']) == {'age', 'sex'}

        # SMD should be close to 0 when means match
        age_smd = balance[balance['variable'] == 'age']['smd'].values[0]
        assert abs(age_smd) < 0.1, f"Age SMD {age_smd}, expected ~0"

    def test_balance_identifies_imbalance(self):
        """Test that imbalance is identified"""
        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, 100),
            'sex': np.random.binomial(1, 0.3, 100)  # 30% female
        })

        agd = pd.DataFrame({
            'age': [60],
            'sex': [0.7]  # 70% female - big difference
        })

        engine = MAICEngine()
        balance = engine._calculate_balance(ipd, agd, ['age', 'sex'], weights=None)

        # Sex should be imbalanced (SMD > 0.1)
        sex_row = balance[balance['variable'] == 'sex']
        assert abs(sex_row['smd'].values[0]) > 0.1, "Sex should be imbalanced"
        assert not sex_row['balanced'].values[0], "Sex should be flagged as imbalanced"


class TestMAICTreatmentEffect:
    """Test treatment effect estimation"""

    def test_treatment_effect_calculation(self):
        """Test that treatment effect is calculated correctly"""
        np.random.seed(42)

        n = 200
        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, n),
            'sex': np.random.binomial(1, 0.5, n),
            'treatment': np.ones(n),
            'outcome': np.random.normal(10, 5, n)  # Mean ~10
        })

        agd = pd.DataFrame({
            'age': [60],
            'sex': [0.5]
        })

        agd_outcomes = {'mean': 7.0, 'se': 0.5}  # Comparator mean = 7

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        results = engine.run_maic(data)

        # Treatment effect should be approximately 10 - 7 = 3
        # (with some variation due to reweighting)
        assert 2 < results.treatment_effect < 4, \
            f"Treatment effect {results.treatment_effect}, expected ~3"

        # CI should contain treatment effect
        assert results.ci_lower < results.treatment_effect < results.ci_upper

    def test_se_positive(self):
        """Test that standard error is positive"""
        np.random.seed(42)

        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, 100),
            'sex': np.random.binomial(1, 0.5, 100),
            'treatment': np.ones(100),
            'outcome': np.random.normal(10, 5, 100)
        })

        agd = pd.DataFrame({'age': [60], 'sex': [0.5]})
        agd_outcomes = {'mean': 7.0, 'se': 0.5}

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        results = engine.run_maic(data)

        assert results.se > 0, "Standard error must be positive"


class TestMAICValidation:
    """Test validation checks"""

    def test_validation_with_good_data(self):
        """Test that good data passes validation"""
        np.random.seed(42)

        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, 200),
            'sex': np.random.binomial(1, 0.5, 200),
            'treatment': np.ones(200),
            'outcome': np.random.normal(10, 5, 200)
        })

        agd = pd.DataFrame({'age': [58], 'sex': [0.55]})  # Similar to IPD
        agd_outcomes = {'mean': 9.0, 'se': 0.5}

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        results = engine.run_maic(data)

        # Should pass all validation checks
        assert results.validation_results['overall_valid'], \
            f"Validation failed: {results.validation_results}"

        assert results.validation_results['weights_positive']
        assert results.validation_results['ess_reasonable']
        assert results.validation_results['effect_finite']

    def test_validation_flags_poor_overlap(self):
        """Test that poor overlap is detected"""
        np.random.seed(42)

        # IPD: older patients (age 70-80)
        ipd = pd.DataFrame({
            'age': np.random.normal(75, 3, 100),
            'sex': np.random.binomial(1, 0.5, 100),
            'treatment': np.ones(100),
            'outcome': np.random.normal(10, 5, 100)
        })

        # AgD: much younger (age 40)
        agd = pd.DataFrame({'age': [40], 'sex': [0.5]})
        agd_outcomes = {'mean': 7.0, 'se': 0.5}

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        results = engine.run_maic(data)

        # ESS should be very low due to poor overlap
        assert results.ess < 0.5 * len(ipd), \
            f"ESS {results.ess} should be < 50 with poor overlap"

        # Should fail ESS validation
        assert not results.validation_results['ess_not_extreme'], \
            "Should flag extreme ESS reduction"


class TestMAICEndToEnd:
    """End-to-end integration tests"""

    def test_complete_maic_workflow(self):
        """Test complete MAIC workflow from data to results"""
        np.random.seed(42)

        # Create realistic synthetic data
        n_ipd = 250
        ipd = pd.DataFrame({
            'age': np.random.normal(62, 12, n_ipd),
            'sex': np.random.binomial(1, 0.45, n_ipd),
            'baseline_severity': np.random.normal(50, 15, n_ipd),
            'treatment': np.ones(n_ipd),
            'outcome': np.random.normal(10.5, 4.5, n_ipd)
        })

        agd = pd.DataFrame({
            'age': [58],
            'sex': [0.52],
            'baseline_severity': [48]
        })

        agd_outcomes = {'mean': 8.2, 'se': 0.6}

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age', 'sex', 'baseline_severity'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        # Run MAIC
        engine = MAICEngine()
        results = engine.run_maic(data)

        # Verify results structure
        assert isinstance(results, MAICResults)
        assert results.weights is not None
        assert results.ess > 0
        assert np.isfinite(results.treatment_effect)
        assert np.isfinite(results.ci_lower)
        assert np.isfinite(results.ci_upper)

        # Verify balance improved
        balance_before = results.balance_before
        balance_after = results.balance_after

        # Most covariates should improve balance
        improved = 0
        for var in ['age', 'sex', 'baseline_severity']:
            smd_before = abs(balance_before[balance_before['variable'] == var]['smd'].values[0])
            smd_after = abs(balance_after[balance_after['variable'] == var]['smd'].values[0])
            if smd_after < smd_before:
                improved += 1

        assert improved >= 2, "At least 2 covariates should improve balance"

        # Verify diagnostics
        assert 'n_patients' in results.diagnostics
        assert 'ess' in results.diagnostics
        assert results.diagnostics['ess'] == results.ess

    def test_maic_with_perfect_balance(self):
        """Test MAIC when IPD already matches AgD"""
        np.random.seed(42)

        # IPD already matches AgD means
        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, 200),
            'sex': np.random.binomial(1, 0.5, 200),
            'treatment': np.ones(200),
            'outcome': np.random.normal(10, 5, 200)
        })

        # AgD matches IPD means exactly
        agd = pd.DataFrame({
            'age': [60],
            'sex': [0.5]
        })

        agd_outcomes = {'mean': 7.0, 'se': 0.5}

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        results = engine.run_maic(data)

        # Weights should be close to uniform (all ~1.0)
        # With stochastic data, some variation is expected, so use atol=0.2
        assert np.allclose(results.weights, 1.0, atol=0.2), \
            f"Weights should be ~1.0 when no reweighting needed (range: {results.weights.min():.2f}-{results.weights.max():.2f})"

        # ESS should be close to n (>90%)
        assert results.ess > 0.9 * len(ipd), \
            f"ESS {results.ess:.1f} should be close to n={len(ipd)}"

        # Weight coefficient of variation should be low (<20%)
        weight_cv = np.std(results.weights) / np.mean(results.weights)
        assert weight_cv < 0.2, \
            f"Weight CV {weight_cv:.3f} should be < 0.2 when populations match"


class TestMAICEdgeCases:
    """Test edge cases and error handling"""

    def test_small_sample_size(self):
        """Test MAIC with very small sample"""
        ipd = pd.DataFrame({
            'age': [60, 65, 70],
            'sex': [0, 1, 1],
            'treatment': [1, 1, 1],
            'outcome': [10, 11, 12]
        })

        agd = pd.DataFrame({'age': [62], 'sex': [0.5]})
        agd_outcomes = {'mean': 9.0, 'se': 1.0}

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age', 'sex'],
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        results = engine.run_maic(data)

        # With n=3, optimization may fail (NaN results)
        # OR succeed with very low ESS
        # Both scenarios should fail validation
        assert not results.validation_results['overall_valid'], \
            "Validation should fail with n=3"

        # Either ESS is NaN or < 10
        assert np.isnan(results.ess) or results.ess < 10, \
            f"ESS should be NaN or < 10 with n=3, got {results.ess}"

    def test_single_matching_variable(self):
        """Test MAIC with only one matching variable"""
        np.random.seed(42)

        ipd = pd.DataFrame({
            'age': np.random.normal(60, 10, 100),
            'treatment': np.ones(100),
            'outcome': np.random.normal(10, 5, 100)
        })

        agd = pd.DataFrame({'age': [55]})
        agd_outcomes = {'mean': 7.0, 'se': 0.5}

        data = MAICData(
            ipd=ipd,
            agd_baseline=agd,
            agd_outcomes=agd_outcomes,
            matching_vars=['age'],  # Only one variable
            outcome_var='outcome',
            treatment_var='treatment'
        )

        engine = MAICEngine()
        results = engine.run_maic(data)

        # Should still work
        assert results.treatment_effect is not None
        assert results.validation_results['overall_valid']


def run_all_tests():
    """Run all tests and generate report"""
    print("="*70)
    print("MAIC ENGINE TEST SUITE")
    print("="*70)
    print()

    # Run pytest
    pytest_args = [
        __file__,
        '-v',           # Verbose
        '--tb=short',   # Short traceback
        '-x'            # Stop on first failure
    ]

    result = pytest.main(pytest_args)

    return result


if __name__ == "__main__":
    exit_code = run_all_tests()

    print()
    print("="*70)
    if exit_code == 0:
        print("✅ ALL TESTS PASSED")
    else:
        print("❌ SOME TESTS FAILED")
    print("="*70)

    exit(exit_code)
