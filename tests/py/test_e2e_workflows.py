"""
End-to-End Workflow Tests
Tests complete workflows from data upload through analysis to reporting
"""
import pytest
import pandas as pd
import numpy as np
import sys
import os
import json
from pathlib import Path

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.validate import validate_table
from etl.transform import compute_effect_size
from cache.cache_manager import CacheManager


@pytest.fixture
def cache_manager(tmp_path):
    """Create a temporary cache manager for testing"""
    cache_dir = tmp_path / "cache"
    cache_dir.mkdir()
    return CacheManager(str(cache_dir))


@pytest.fixture
def sample_binary_data():
    """Create sample binary outcome data"""
    return pd.DataFrame({
        'study_id': ['Study1', 'Study2', 'Study3', 'Study4', 'Study5'],
        'treatment': ['TreatA', 'TreatA', 'TreatA', 'TreatA', 'TreatA'],
        'events1': [20, 25, 18, 30, 22],
        'n1': [100, 120, 90, 150, 110],
        'events2': [30, 35, 28, 45, 32],
        'n2': [100, 120, 90, 150, 110],
        'year': [2018, 2019, 2019, 2020, 2020],
        'risk_of_bias': ['Low', 'Low', 'Moderate', 'Low', 'Moderate']
    })


@pytest.fixture
def sample_continuous_data():
    """Create sample continuous outcome data"""
    return pd.DataFrame({
        'study_id': ['Study1', 'Study2', 'Study3', 'Study4'],
        'treatment': ['TreatA', 'TreatA', 'TreatA', 'TreatA'],
        'mean1': [10.5, 11.2, 9.8, 10.9],
        'sd1': [2.1, 2.3, 1.9, 2.2],
        'n1': [50, 60, 45, 55],
        'mean2': [8.3, 9.1, 8.5, 9.0],
        'sd2': [2.0, 2.2, 2.1, 2.1],
        'n2': [50, 60, 45, 55],
        'year': [2018, 2019, 2020, 2020]
    })


@pytest.fixture
def sample_tte_data():
    """Create sample time-to-event data"""
    return pd.DataFrame({
        'study_id': ['Study1', 'Study2', 'Study3'],
        'treatment': ['TreatA', 'TreatA', 'TreatA'],
        'hr': [0.7, 0.65, 0.75],
        'ci_lower': [0.5, 0.45, 0.55],
        'ci_upper': [0.9, 0.85, 0.95],
        'year': [2018, 2019, 2020]
    })


class TestBinaryOutcomeWorkflow:
    """Test complete workflow for binary outcome meta-analysis"""

    def test_binary_workflow_complete(self, sample_binary_data):
        """Test full binary outcome workflow: validate → transform → cache"""
        # Step 1: Validate data
        validation_result = validate_table(sample_binary_data, 'binary')
        assert validation_result.is_valid is True
        assert validation_result.summary['errors'] == 0
        print(f"✓ Validation passed: {validation_result.summary}")

        # Step 2: Compute effect sizes (OR)
        effect_data = compute_effect_size(sample_binary_data, 'OR')
        assert 'yi' in effect_data.columns
        assert 'sei' in effect_data.columns
        assert 'vi' in effect_data.columns
        assert len(effect_data) == 5
        assert not effect_data['yi'].isna().any()
        print(f"✓ Effect sizes computed: {len(effect_data)} studies")

        # Step 3: Verify effect sizes are reasonable
        # log(OR) should be between -5 and 5 for reasonable data
        assert all(effect_data['yi'].between(-5, 5))
        assert all(effect_data['sei'] > 0)
        print(f"✓ Effect sizes within reasonable bounds")

        # Step 4: Simulate meta-analysis (simplified - would call R in real app)
        # Calculate inverse-variance weighted mean
        weights = 1 / effect_data['vi']
        pooled_effect = np.sum(weights * effect_data['yi']) / np.sum(weights)
        pooled_se = np.sqrt(1 / np.sum(weights))

        assert not np.isnan(pooled_effect)
        assert not np.isnan(pooled_se)
        assert pooled_se > 0
        print(f"✓ Pooled effect: {pooled_effect:.3f} (SE: {pooled_se:.3f})")

    def test_binary_workflow_with_subgroups(self, sample_binary_data):
        """Test binary workflow with subgroup analysis"""
        # Validate
        validation_result = validate_table(sample_binary_data, 'binary')
        assert validation_result.is_valid is True

        # Transform
        effect_data = compute_effect_size(sample_binary_data, 'OR')

        # Subgroup by risk of bias
        for rob_level in effect_data['risk_of_bias'].unique():
            subgroup = effect_data[effect_data['risk_of_bias'] == rob_level]
            assert len(subgroup) > 0
            assert all(subgroup['sei'] > 0)
            print(f"✓ Subgroup '{rob_level}': {len(subgroup)} studies")

    def test_binary_workflow_risk_ratio(self, sample_binary_data):
        """Test binary workflow with RR instead of OR"""
        validation_result = validate_table(sample_binary_data, 'binary')
        assert validation_result.is_valid is True

        # Compute RR instead of OR
        effect_data = compute_effect_size(sample_binary_data, 'RR')
        assert 'yi' in effect_data.columns
        assert len(effect_data) == 5
        print(f"✓ Risk ratios computed for {len(effect_data)} studies")


class TestContinuousOutcomeWorkflow:
    """Test complete workflow for continuous outcome meta-analysis"""

    def test_continuous_workflow_md(self, sample_continuous_data):
        """Test workflow with mean difference"""
        # Validate
        validation_result = validate_table(sample_continuous_data, 'continuous')
        assert validation_result.is_valid is True
        print(f"✓ Validation passed")

        # Compute MD
        effect_data = compute_effect_size(sample_continuous_data, 'MD')
        assert 'yi' in effect_data.columns
        assert len(effect_data) == 4
        print(f"✓ Mean differences computed for {len(effect_data)} studies")

        # Verify MD values make sense (should be difference in means)
        for i, row in effect_data.iterrows():
            expected_md = sample_continuous_data.loc[i, 'mean1'] - sample_continuous_data.loc[i, 'mean2']
            assert row['yi'] == pytest.approx(expected_md, rel=0.01)

    def test_continuous_workflow_smd(self, sample_continuous_data):
        """Test workflow with standardized mean difference"""
        validation_result = validate_table(sample_continuous_data, 'continuous')
        assert validation_result.is_valid is True

        # Compute SMD
        effect_data = compute_effect_size(sample_continuous_data, 'SMD')
        assert 'yi' in effect_data.columns
        assert len(effect_data) == 4
        print(f"✓ Standardized mean differences computed")

        # SMD should be roughly MD / pooled SD
        # Should be reasonable values (typically -3 to 3)
        assert all(effect_data['yi'].between(-5, 5))


class TestTimeToEventWorkflow:
    """Test complete workflow for time-to-event meta-analysis"""

    def test_tte_workflow_complete(self, sample_tte_data):
        """Test full time-to-event workflow"""
        # Validate
        validation_result = validate_table(sample_tte_data, 'time_to_event')
        assert validation_result.is_valid is True
        print(f"✓ TTE data validation passed")

        # Compute effect sizes from HR and CI
        effect_data = compute_effect_size(sample_tte_data, 'HR')
        assert 'yi' in effect_data.columns
        assert len(effect_data) == 3
        print(f"✓ Hazard ratios processed for {len(effect_data)} studies")

        # Verify HR conversion to log scale
        for i, row in effect_data.iterrows():
            expected_log_hr = np.log(sample_tte_data.loc[i, 'hr'])
            assert row['yi'] == pytest.approx(expected_log_hr, rel=0.01)


class TestCachingWorkflow:
    """Test workflow with caching integration"""

    def test_cache_analysis_results(self, sample_binary_data, cache_manager):
        """Test caching of analysis results"""
        # Run analysis
        validation_result = validate_table(sample_binary_data, 'binary')
        effect_data = compute_effect_size(sample_binary_data, 'OR')

        # Create analysis result
        analysis_result = {
            'validation': {
                'is_valid': validation_result.is_valid,
                'errors': validation_result.summary['errors']
            },
            'effect_sizes': effect_data.to_dict('records'),
            'n_studies': len(effect_data)
        }

        # Cache the result
        cache_key = "binary_or_analysis_v1"
        cache_manager.put(cache_key, analysis_result)
        print(f"✓ Results cached with key: {cache_key}")

        # Retrieve from cache
        cached_result = cache_manager.get(cache_key)
        assert cached_result is not None
        assert cached_result['n_studies'] == 5
        assert len(cached_result['effect_sizes']) == 5
        print(f"✓ Results retrieved from cache")

    def test_cache_invalidation_on_data_change(self, sample_binary_data, cache_manager):
        """Test that cache is invalidated when data changes"""
        # Cache first analysis
        effect_data1 = compute_effect_size(sample_binary_data, 'OR')
        cache_key1 = cache_manager.generate_cache_key(
            "binary_or",
            sample_binary_data.to_dict()
        )
        cache_manager.put(cache_key1, {'results': effect_data1.to_dict()})

        # Modify data
        modified_data = sample_binary_data.copy()
        modified_data.loc[0, 'events1'] = 50  # Changed value

        # New cache key should be different
        cache_key2 = cache_manager.generate_cache_key(
            "binary_or",
            modified_data.to_dict()
        )
        assert cache_key1 != cache_key2
        print(f"✓ Cache key changed after data modification")


class TestErrorRecoveryWorkflows:
    """Test workflows with errors and recovery"""

    def test_workflow_with_invalid_data_recovery(self):
        """Test workflow handles invalid data gracefully"""
        invalid_data = pd.DataFrame({
            'study_id': ['S1'],
            'treatment': ['A'],
            'events1': [150],  # Invalid: events > n
            'n1': [100],
            'events2': [30],
            'n2': [100]
        })

        # Validation should catch this
        validation_result = validate_table(invalid_data, 'binary')
        assert validation_result.is_valid is False
        assert validation_result.summary['errors'] > 0
        print(f"✓ Invalid data detected: {validation_result.summary['errors']} errors")

        # Workflow should not proceed to effect size computation
        # (In real app, this would show error to user)

    def test_workflow_with_zero_cells(self):
        """Test workflow handles zero cells with continuity correction"""
        zero_cell_data = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'treatment': ['A', 'B'],
            'events1': [0, 5],  # Zero cell
            'n1': [100, 100],
            'events2': [10, 15],
            'n2': [100, 100]
        })

        validation_result = validate_table(zero_cell_data, 'binary')
        assert validation_result.is_valid is True

        # Should apply continuity correction
        effect_data = compute_effect_size(zero_cell_data, 'OR')
        assert not effect_data['yi'].isna().any()
        assert not effect_data['yi'].isinf().any()
        print(f"✓ Zero cells handled with continuity correction")

    def test_workflow_with_missing_data(self):
        """Test workflow handles missing data"""
        data_with_missing = pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'treatment': ['A', 'B', None],  # Missing treatment
            'events1': [20, 25, 18],
            'n1': [100, 120, 90],
            'events2': [30, 35, 28],
            'n2': [100, 120, None]  # Missing n2
        })

        validation_result = validate_table(data_with_missing, 'binary')
        # Should detect missing values
        assert validation_result.is_valid is False


class TestMultiAnalysisWorkflows:
    """Test workflows involving multiple analysis types"""

    def test_parallel_analyses(self, sample_binary_data):
        """Test running multiple analyses on same data"""
        validation_result = validate_table(sample_binary_data, 'binary')
        assert validation_result.is_valid is True

        # Compute both OR and RR
        effect_or = compute_effect_size(sample_binary_data, 'OR')
        effect_rr = compute_effect_size(sample_binary_data, 'RR')

        assert len(effect_or) == len(effect_rr)
        assert len(effect_or) == 5

        # Both should have valid effect sizes
        assert not effect_or['yi'].isna().any()
        assert not effect_rr['yi'].isna().any()
        print(f"✓ Parallel analyses (OR and RR) completed")

    def test_sensitivity_analysis_workflow(self, sample_binary_data):
        """Test sensitivity analysis workflow (leave-one-out)"""
        validation_result = validate_table(sample_binary_data, 'binary')
        assert validation_result.is_valid is True

        effect_data = compute_effect_size(sample_binary_data, 'OR')

        # Simulate leave-one-out sensitivity analysis
        n_studies = len(effect_data)
        sensitivity_results = []

        for i in range(n_studies):
            # Remove one study
            sensitivity_data = effect_data.drop(index=i)

            # Calculate pooled effect without this study
            weights = 1 / sensitivity_data['vi']
            pooled_effect = np.sum(weights * sensitivity_data['yi']) / np.sum(weights)

            sensitivity_results.append({
                'excluded_study': effect_data.loc[i, 'study_id'],
                'pooled_effect': pooled_effect
            })

        assert len(sensitivity_results) == n_studies
        print(f"✓ Leave-one-out sensitivity analysis: {len(sensitivity_results)} iterations")


class TestHealthEconomicsWorkflow:
    """Test health economics analysis workflows"""

    def test_basic_he_workflow(self):
        """Test basic HE model workflow"""
        # Define treatment and comparator costs/utilities
        treatment = {
            'cost': 15000,
            'qaly': 1.5,
            'label': 'New Treatment'
        }

        comparator = {
            'cost': 10000,
            'qaly': 1.2,
            'label': 'Standard Care'
        }

        # Calculate ICER
        incremental_cost = treatment['cost'] - comparator['cost']
        incremental_qaly = treatment['qaly'] - comparator['qaly']
        icer = incremental_cost / incremental_qaly

        assert incremental_cost == 5000
        assert incremental_qaly == pytest.approx(0.3)
        assert icer == pytest.approx(16666.67, rel=0.01)
        print(f"✓ ICER calculated: £{icer:,.2f}/QALY")

        # Check if cost-effective at £20,000 WTP threshold
        is_cost_effective = icer < 20000
        assert is_cost_effective is True
        print(f"✓ Treatment is cost-effective at £20k WTP threshold")

    def test_psa_workflow(self):
        """Test probabilistic sensitivity analysis workflow"""
        np.random.seed(42)  # For reproducibility

        n_iterations = 1000

        # Sample parameters from distributions
        treatment_effect = np.random.lognormal(mean=-0.3, sigma=0.15, size=n_iterations)
        cost_treatment = np.random.gamma(shape=25, scale=400, size=n_iterations)
        cost_comparator = np.random.gamma(shape=16, scale=312.5, size=n_iterations)

        # Calculate incremental outcomes for each iteration
        incremental_costs = cost_treatment - cost_comparator

        # For simplicity, assume utility gain from treatment effect
        incremental_qalys = (1 - treatment_effect) * 0.5

        # Calculate ICER for each iteration
        icers = incremental_costs / incremental_qalys

        # Calculate probability cost-effective at different WTP thresholds
        wtp_threshold = 20000
        prob_cost_effective = np.mean(icers < wtp_threshold)

        assert 0 <= prob_cost_effective <= 1
        print(f"✓ PSA completed: {n_iterations} iterations")
        print(f"✓ Probability cost-effective at £{wtp_threshold}: {prob_cost_effective:.2%}")


class TestReportingWorkflow:
    """Test reporting and output generation workflows"""

    def test_json_output_workflow(self, sample_binary_data):
        """Test JSON evidence object creation"""
        validation_result = validate_table(sample_binary_data, 'binary')
        effect_data = compute_effect_size(sample_binary_data, 'OR')

        # Create evidence object
        evidence_object = {
            'version': '1.0',
            'analysis_type': 'meta_analysis',
            'outcome_type': 'binary',
            'effect_measure': 'OR',
            'n_studies': len(effect_data),
            'studies': effect_data.to_dict('records'),
            'validation': {
                'is_valid': validation_result.is_valid,
                'errors': validation_result.summary['errors'],
                'warnings': validation_result.summary.get('warnings', 0)
            }
        }

        # Verify JSON serializable
        json_str = json.dumps(evidence_object, indent=2)
        assert len(json_str) > 0

        # Verify can be deserialized
        reloaded = json.loads(json_str)
        assert reloaded['n_studies'] == 5
        print(f"✓ Evidence object created and serialized")


class TestPerformanceWorkflows:
    """Test performance of workflows with larger datasets"""

    def test_large_dataset_workflow(self):
        """Test workflow with larger dataset (100 studies)"""
        import time

        # Generate large dataset
        np.random.seed(42)
        n_studies = 100

        large_data = pd.DataFrame({
            'study_id': [f'Study{i}' for i in range(n_studies)],
            'treatment': ['TreatA'] * n_studies,
            'events1': np.random.randint(10, 50, n_studies),
            'n1': np.random.randint(60, 200, n_studies),
            'events2': np.random.randint(15, 60, n_studies),
            'n2': np.random.randint(60, 200, n_studies)
        })

        # Ensure events <= n
        large_data['events1'] = large_data[['events1', 'n1']].min(axis=1) - 5
        large_data['events2'] = large_data[['events2', 'n2']].min(axis=1) - 5

        start_time = time.time()

        # Run validation
        validation_result = validate_table(large_data, 'binary')
        assert validation_result.is_valid is True

        # Compute effect sizes
        effect_data = compute_effect_size(large_data, 'OR')
        assert len(effect_data) == n_studies

        elapsed = time.time() - start_time

        print(f"✓ Large dataset workflow ({n_studies} studies) completed in {elapsed:.3f}s")
        assert elapsed < 5.0  # Should complete in reasonable time


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
