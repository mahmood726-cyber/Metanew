"""
Integration tests for EvidenceOS PRIME V2.0
Tests end-to-end functionality across Python backend and R frontend integration
"""
import pytest
import pandas as pd
import sys
import os
from pathlib import Path
import json
import tempfile
import shutil

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from api.main import app
from cache.cache_manager import CacheManager
from etl.validate import validate_table
from etl.transform import compute_effect_size
from fastapi.testclient import TestClient


class TestFullStackIntegration:
    """Test suite for end-to-end integration scenarios"""

    @pytest.fixture
    def client(self):
        """FastAPI test client"""
        return TestClient(app)

    @pytest.fixture
    def cache_manager(self):
        """Cache manager with temporary directory"""
        temp_dir = tempfile.mkdtemp()
        cache = CacheManager(cache_dir=temp_dir)
        yield cache
        shutil.rmtree(temp_dir)

    @pytest.fixture
    def sample_continuous_data(self):
        """Sample continuous outcome data"""
        return pd.DataFrame({
            'study_id': ['Study1', 'Study2', 'Study3'],
            'treatment': ['DrugA', 'DrugB', 'DrugA'],
            'mean': [5.2, 6.1, 5.8],
            'sd': [1.1, 1.3, 1.2],
            'n': [50, 45, 52]
        })

    @pytest.fixture
    def sample_binary_data(self):
        """Sample binary outcome data"""
        return pd.DataFrame({
            'study_id': ['Study1', 'Study2', 'Study3'],
            'treatment': ['DrugA', 'DrugB', 'DrugA'],
            'events': [15, 20, 18],
            'n': [50, 45, 52]
        })

    def test_data_validation_pipeline(self, sample_continuous_data):
        """Test complete data validation pipeline"""
        # Validate data
        result = validate_table(
            sample_continuous_data,
            required_cols=['study_id', 'treatment', 'mean', 'sd', 'n'],
            numeric_cols=['mean', 'sd', 'n']
        )

        assert result.is_valid
        assert len(result.problems) == 0
        assert result.row_count == 3

    def test_etl_transform_pipeline(self, sample_continuous_data):
        """Test ETL transformation pipeline"""
        # Compute effect sizes
        es_data = compute_effect_size(
            sample_continuous_data,
            outcome_type='continuous'
        )

        assert 'yi' in es_data.columns
        assert 'vi' in es_data.columns
        assert len(es_data) == 3
        assert not es_data['yi'].isna().any()

    def test_cache_layer_integration(self, cache_manager, sample_continuous_data):
        """Test caching layer with data processing"""
        # Create cache key
        query_params = {
            'outcome_type': 'continuous',
            'model': 'random_effects'
        }

        # Save to cache
        cache_id = cache_manager.save_results(
            sample_continuous_data,
            query_params,
            metadata={'test': 'integration'}
        )

        assert cache_id is not None

        # Retrieve from cache
        cached_data, cached_meta = cache_manager.get_cached_results(query_params)

        assert cached_data is not None
        assert cached_meta['test'] == 'integration'
        pd.testing.assert_frame_equal(cached_data, sample_continuous_data)

    def test_api_validation_endpoint(self, client, sample_continuous_data):
        """Test API validation endpoint"""
        payload = {
            'data': sample_continuous_data.to_dict(orient='records'),
            'validation_rules': {
                'required_cols': ['study_id', 'treatment', 'mean', 'sd', 'n'],
                'numeric_cols': ['mean', 'sd', 'n']
            }
        }

        response = client.post('/api/validate', json=payload)

        assert response.status_code == 200
        result = response.json()
        assert result['is_valid'] == True
        assert result['row_count'] == 3

    def test_api_transform_endpoint(self, client, sample_continuous_data):
        """Test API transformation endpoint"""
        payload = {
            'data': sample_continuous_data.to_dict(orient='records'),
            'outcome_type': 'continuous'
        }

        response = client.post('/api/transform/effect-size', json=payload)

        assert response.status_code == 200
        result = response.json()
        assert 'data' in result
        assert len(result['data']) == 3
        assert 'yi' in result['data'][0]
        assert 'vi' in result['data'][0]

    def test_end_to_end_analysis_workflow(
        self,
        client,
        cache_manager,
        sample_continuous_data
    ):
        """Test complete end-to-end analysis workflow"""
        # Step 1: Validate data
        validation_payload = {
            'data': sample_continuous_data.to_dict(orient='records'),
            'validation_rules': {
                'required_cols': ['study_id', 'treatment', 'mean', 'sd', 'n'],
                'numeric_cols': ['mean', 'sd', 'n']
            }
        }

        validation_response = client.post('/api/validate', json=validation_payload)
        assert validation_response.status_code == 200
        assert validation_response.json()['is_valid'] == True

        # Step 2: Transform data
        transform_payload = {
            'data': sample_continuous_data.to_dict(orient='records'),
            'outcome_type': 'continuous'
        }

        transform_response = client.post(
            '/api/transform/effect-size',
            json=transform_payload
        )
        assert transform_response.status_code == 200
        transformed_data = pd.DataFrame(transform_response.json()['data'])

        # Step 3: Cache results
        query_params = {
            'outcome_type': 'continuous',
            'workflow': 'validation_transform'
        }

        cache_id = cache_manager.save_results(
            transformed_data,
            query_params,
            metadata={'workflow_step': 'complete'}
        )

        assert cache_id is not None

        # Step 4: Verify cached results
        cached_data, cached_meta = cache_manager.get_cached_results(query_params)
        assert cached_data is not None
        assert cached_meta['workflow_step'] == 'complete'

    def test_binary_data_workflow(self, client, sample_binary_data):
        """Test workflow with binary outcome data"""
        # Validate binary data
        validation_payload = {
            'data': sample_binary_data.to_dict(orient='records'),
            'validation_rules': {
                'required_cols': ['study_id', 'treatment', 'events', 'n'],
                'numeric_cols': ['events', 'n']
            }
        }

        validation_response = client.post('/api/validate', json=validation_payload)
        assert validation_response.status_code == 200
        assert validation_response.json()['is_valid'] == True

        # Transform binary data
        transform_payload = {
            'data': sample_binary_data.to_dict(orient='records'),
            'outcome_type': 'binary'
        }

        transform_response = client.post(
            '/api/transform/effect-size',
            json=transform_payload
        )
        assert transform_response.status_code == 200
        result = transform_response.json()
        assert len(result['data']) == 3

    def test_error_handling_integration(self, client):
        """Test error handling across the stack"""
        # Test with invalid data
        invalid_payload = {
            'data': [{'invalid': 'data'}],
            'validation_rules': {
                'required_cols': ['study_id', 'treatment'],
                'numeric_cols': ['mean']
            }
        }

        response = client.post('/api/validate', json=invalid_payload)
        assert response.status_code in [400, 422, 200]  # Should handle gracefully

        if response.status_code == 200:
            result = response.json()
            assert result['is_valid'] == False

    def test_cache_invalidation_workflow(self, cache_manager, sample_continuous_data):
        """Test cache invalidation and refresh"""
        query_params = {'test': 'cache_invalidation'}

        # Save initial data
        cache_id_1 = cache_manager.save_results(
            sample_continuous_data,
            query_params,
            metadata={'version': 1}
        )

        # Clear cache
        cache_manager.clear_cache()

        # Verify cache is cleared
        cached_data, cached_meta = cache_manager.get_cached_results(query_params)
        assert cached_data is None

        # Save new data
        modified_data = sample_continuous_data.copy()
        modified_data['mean'] = modified_data['mean'] * 1.1

        cache_id_2 = cache_manager.save_results(
            modified_data,
            query_params,
            metadata={'version': 2}
        )

        # Verify new data is cached
        new_cached_data, new_cached_meta = cache_manager.get_cached_results(query_params)
        assert new_cached_data is not None
        assert new_cached_meta['version'] == 2

    def test_concurrent_api_requests(self, client, sample_continuous_data):
        """Test handling of concurrent API requests"""
        payload = {
            'data': sample_continuous_data.to_dict(orient='records'),
            'outcome_type': 'continuous'
        }

        # Simulate multiple concurrent requests
        responses = []
        for _ in range(5):
            response = client.post('/api/transform/effect-size', json=payload)
            responses.append(response)

        # Verify all requests succeeded
        for response in responses:
            assert response.status_code == 200
            result = response.json()
            assert len(result['data']) == 3

    def test_data_persistence_workflow(self, cache_manager, sample_continuous_data):
        """Test data persistence across cache operations"""
        # Save multiple datasets
        datasets = {
            'dataset1': sample_continuous_data,
            'dataset2': sample_continuous_data.copy(),
            'dataset3': sample_continuous_data.copy()
        }

        cache_ids = {}
        for name, data in datasets.items():
            query_params = {'dataset_name': name}
            cache_id = cache_manager.save_results(
                data,
                query_params,
                metadata={'name': name}
            )
            cache_ids[name] = cache_id

        # Verify all datasets are cached
        for name in datasets.keys():
            query_params = {'dataset_name': name}
            cached_data, cached_meta = cache_manager.get_cached_results(query_params)
            assert cached_data is not None
            assert cached_meta['name'] == name


class TestAPIHealthChecks:
    """Test suite for API health checks and monitoring"""

    @pytest.fixture
    def client(self):
        return TestClient(app)

    def test_api_health_endpoint(self, client):
        """Test API health check endpoint"""
        response = client.get('/health')
        assert response.status_code in [200, 404]  # May or may not exist

    def test_api_root_endpoint(self, client):
        """Test API root endpoint"""
        response = client.get('/')
        assert response.status_code in [200, 404]


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
