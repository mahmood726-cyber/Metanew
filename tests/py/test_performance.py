"""
Performance and Load Tests
Tests for performance benchmarks, load handling, and scalability
"""
import pytest
import pandas as pd
import numpy as np
import sys
import os
import time
from concurrent.futures import ThreadPoolExecutor
from fastapi.testclient import TestClient

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))
sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend/api'))

from etl.validate import validate_table
from etl.transform import compute_effect_size
from cache.cache_manager import CacheManager
from main import app

client = TestClient(app)


@pytest.fixture
def perf_cache_manager(tmp_path):
    """Create cache manager for performance tests"""
    cache_dir = tmp_path / "perf_cache"
    cache_dir.mkdir()
    return CacheManager(str(cache_dir))


class TestDataProcessingPerformance:
    """Test performance of data processing operations"""

    def test_validation_performance_small(self):
        """Test validation performance with small dataset (10 studies)"""
        data = pd.DataFrame({
            'study_id': [f'Study{i}' for i in range(10)],
            'treatment': ['A'] * 10,
            'events': np.random.randint(10, 50, 10),
            'n': np.random.randint(60, 200, 10)
        })

        start = time.time()
        result = validate_table(data, 'binary')
        elapsed = time.time() - start

        assert result.is_valid is True
        assert elapsed < 0.1  # Should be very fast
        print(f"✓ Small dataset validation: {elapsed*1000:.2f}ms")

    def test_validation_performance_medium(self):
        """Test validation performance with medium dataset (100 studies)"""
        np.random.seed(42)
        data = pd.DataFrame({
            'study_id': [f'Study{i}' for i in range(100)],
            'treatment': ['A'] * 100,
            'events': np.random.randint(10, 50, 100),
            'n': np.random.randint(60, 200, 100)
        })
        # Ensure valid data
        data['events'] = data[['events', 'n']].min(axis=1) - 5

        start = time.time()
        result = validate_table(data, 'binary')
        elapsed = time.time() - start

        assert result.is_valid is True
        assert elapsed < 0.5  # Should complete quickly
        print(f"✓ Medium dataset validation: {elapsed*1000:.2f}ms")

    def test_validation_performance_large(self):
        """Test validation performance with large dataset (1000 studies)"""
        np.random.seed(42)
        data = pd.DataFrame({
            'study_id': [f'Study{i}' for i in range(1000)],
            'treatment': ['A'] * 1000,
            'events': np.random.randint(10, 50, 1000),
            'n': np.random.randint(60, 200, 1000)
        })
        # Ensure valid data
        data['events'] = data[['events', 'n']].min(axis=1) - 5

        start = time.time()
        result = validate_table(data, 'binary')
        elapsed = time.time() - start

        assert result.is_valid is True
        assert elapsed < 2.0  # Should complete in reasonable time
        print(f"✓ Large dataset validation: {elapsed*1000:.2f}ms")

    def test_effect_size_computation_performance(self):
        """Test effect size computation performance"""
        np.random.seed(42)
        sizes = [10, 50, 100, 500]

        for size in sizes:
            data = pd.DataFrame({
                'study_id': [f'Study{i}' for i in range(size)],
                'treatment': ['A'] * size,
                'events1': np.random.randint(10, 50, size),
                'n1': np.random.randint(60, 200, size),
                'events2': np.random.randint(10, 50, size),
                'n2': np.random.randint(60, 200, size)
            })
            # Ensure valid data
            data['events1'] = data[['events1', 'n1']].min(axis=1) - 5
            data['events2'] = data[['events2', 'n2']].min(axis=1) - 5

            start = time.time()
            result = compute_effect_size(data, 'OR')
            elapsed = time.time() - start

            assert len(result) == size
            print(f"✓ Effect size computation ({size} studies): {elapsed*1000:.2f}ms")

            # Should scale linearly (rough check)
            assert elapsed < size * 0.01  # ~10ms per study max


class TestAPIPerformance:
    """Test API endpoint performance"""

    def test_health_check_performance(self):
        """Test health check endpoint performance"""
        times = []
        for _ in range(10):
            start = time.time()
            response = client.get("/")
            elapsed = time.time() - start
            times.append(elapsed)
            assert response.status_code == 200

        avg_time = np.mean(times)
        assert avg_time < 0.05  # Should be very fast (< 50ms)
        print(f"✓ Health check avg: {avg_time*1000:.2f}ms")

    def test_validation_api_performance(self):
        """Test validation API endpoint performance"""
        payload = {
            "data": {
                "study_id": [f"S{i}" for i in range(50)],
                "treatment": ["A"] * 50,
                "events": [10] * 50,
                "n": [100] * 50
            },
            "data_type": "binary"
        }

        times = []
        for _ in range(5):
            start = time.time()
            response = client.post("/validate", json=payload)
            elapsed = time.time() - start
            times.append(elapsed)
            assert response.status_code == 200

        avg_time = np.mean(times)
        print(f"✓ Validation API avg (50 studies): {avg_time*1000:.2f}ms")
        assert avg_time < 1.0  # Should complete quickly

    def test_effect_size_api_performance(self):
        """Test effect size computation API performance"""
        payload = {
            "data": {
                "study_id": [f"S{i}" for i in range(50)],
                "events1": [20] * 50,
                "n1": [100] * 50,
                "events2": [30] * 50,
                "n2": [100] * 50
            },
            "effect_measure": "OR"
        }

        times = []
        for _ in range(5):
            start = time.time()
            response = client.post("/compute-effect-size", json=payload)
            elapsed = time.time() - start
            times.append(elapsed)
            assert response.status_code == 200

        avg_time = np.mean(times)
        print(f"✓ Effect size API avg (50 studies): {avg_time*1000:.2f}ms")


class TestCachingPerformance:
    """Test caching performance and speedup"""

    def test_cache_write_performance(self, perf_cache_manager):
        """Test cache write performance"""
        data = {"results": list(range(1000)), "metadata": {"version": "1.0"}}

        times = []
        for i in range(10):
            start = time.time()
            perf_cache_manager.put(f"test_key_{i}", data)
            elapsed = time.time() - start
            times.append(elapsed)

        avg_time = np.mean(times)
        print(f"✓ Cache write avg: {avg_time*1000:.2f}ms")
        assert avg_time < 0.1  # Should be fast

    def test_cache_read_performance(self, perf_cache_manager):
        """Test cache read performance"""
        data = {"results": list(range(1000)), "metadata": {"version": "1.0"}}
        perf_cache_manager.put("test_key", data)

        times = []
        for _ in range(100):
            start = time.time()
            result = perf_cache_manager.get("test_key")
            elapsed = time.time() - start
            times.append(elapsed)
            assert result is not None

        avg_time = np.mean(times)
        print(f"✓ Cache read avg: {avg_time*1000:.2f}ms")
        assert avg_time < 0.05  # Should be very fast

    def test_cache_speedup_vs_computation(self, perf_cache_manager):
        """Test cache provides significant speedup"""
        np.random.seed(42)
        data = pd.DataFrame({
            'study_id': [f'Study{i}' for i in range(100)],
            'treatment': ['A'] * 100,
            'events1': np.random.randint(10, 50, 100),
            'n1': np.random.randint(60, 200, 100),
            'events2': np.random.randint(10, 50, 100),
            'n2': np.random.randint(60, 200, 100)
        })
        data['events1'] = data[['events1', 'n1']].min(axis=1) - 5
        data['events2'] = data[['events2', 'n2']].min(axis=1) - 5

        # Time computation without cache
        start = time.time()
        result = compute_effect_size(data, 'OR')
        compute_time = time.time() - start

        # Cache the result
        cache_key = "test_speedup"
        perf_cache_manager.put(cache_key, result.to_dict())

        # Time retrieval from cache
        start = time.time()
        cached_result = perf_cache_manager.get(cache_key)
        cache_time = time.time() - start

        speedup = compute_time / cache_time
        print(f"✓ Computation time: {compute_time*1000:.2f}ms")
        print(f"✓ Cache retrieval time: {cache_time*1000:.2f}ms")
        print(f"✓ Speedup: {speedup:.1f}x")

        assert speedup > 5  # Cache should be at least 5x faster


class TestConcurrentLoadPerformance:
    """Test performance under concurrent load"""

    def test_concurrent_validations(self):
        """Test handling concurrent validation requests"""
        def validate_request(i):
            payload = {
                "data": {
                    "study_id": [f"S{i}"],
                    "treatment": ["A"],
                    "events": [10 + i % 20],
                    "n": [100]
                },
                "data_type": "binary"
            }
            start = time.time()
            response = client.post("/validate", json=payload)
            elapsed = time.time() - start
            return elapsed, response.status_code

        # Run 20 concurrent requests
        start_total = time.time()
        with ThreadPoolExecutor(max_workers=10) as executor:
            results = list(executor.map(validate_request, range(20)))
        total_time = time.time() - start_total

        # Check all succeeded
        statuses = [r[1] for r in results]
        times = [r[0] for r in results]

        success_rate = sum(1 for s in statuses if s == 200) / len(statuses)
        avg_time = np.mean(times)

        print(f"✓ Concurrent requests: {len(results)} in {total_time:.2f}s")
        print(f"✓ Success rate: {success_rate:.1%}")
        print(f"✓ Avg request time: {avg_time*1000:.2f}ms")

        assert success_rate >= 0.8  # At least 80% should succeed (some may be rate limited)

    def test_sustained_load_performance(self):
        """Test performance under sustained load"""
        def make_request():
            payload = {
                "data": {
                    "study_id": ["S1"],
                    "treatment": ["A"],
                    "events": [10],
                    "n": [100]
                },
                "data_type": "binary"
            }
            start = time.time()
            response = client.post("/validate", json=payload)
            elapsed = time.time() - start
            return elapsed, response.status_code

        # Run 100 requests with some concurrency
        num_requests = 100
        batch_size = 5

        all_times = []
        all_statuses = []

        start_total = time.time()
        for i in range(0, num_requests, batch_size):
            with ThreadPoolExecutor(max_workers=batch_size) as executor:
                results = list(executor.map(lambda x: make_request(), range(batch_size)))

            times = [r[0] for r in results]
            statuses = [r[1] for r in results]
            all_times.extend(times)
            all_statuses.extend(statuses)

        total_time = time.time() - start_total

        success_rate = sum(1 for s in all_statuses if s == 200) / len(all_statuses)
        avg_time = np.mean(all_times)
        p95_time = np.percentile(all_times, 95)

        print(f"✓ Sustained load: {num_requests} requests in {total_time:.2f}s")
        print(f"✓ Throughput: {num_requests/total_time:.1f} req/s")
        print(f"✓ Success rate: {success_rate:.1%}")
        print(f"✓ Avg response time: {avg_time*1000:.2f}ms")
        print(f"✓ P95 response time: {p95_time*1000:.2f}ms")


class TestMemoryPerformance:
    """Test memory usage and efficiency"""

    def test_large_dataset_memory_usage(self):
        """Test memory usage with large datasets"""
        import tracemalloc

        np.random.seed(42)
        # Create large dataset (1000 studies)
        data = pd.DataFrame({
            'study_id': [f'Study{i}' for i in range(1000)],
            'treatment': ['A'] * 1000,
            'events': np.random.randint(10, 50, 1000),
            'n': np.random.randint(60, 200, 1000)
        })

        tracemalloc.start()
        start_mem = tracemalloc.get_traced_memory()[0]

        # Process data
        result = validate_table(data, 'binary')

        end_mem = tracemalloc.get_traced_memory()[0]
        mem_used = (end_mem - start_mem) / 1024 / 1024  # MB

        tracemalloc.stop()

        print(f"✓ Memory used for 1000 studies: {mem_used:.2f}MB")
        assert mem_used < 100  # Should use less than 100MB

    def test_cache_memory_efficiency(self, perf_cache_manager):
        """Test cache doesn't cause memory leaks"""
        import tracemalloc

        tracemalloc.start()
        start_mem = tracemalloc.get_traced_memory()[0]

        # Add many items to cache
        for i in range(100):
            data = {"results": list(range(100)), "id": i}
            perf_cache_manager.put(f"key_{i}", data)

        mid_mem = tracemalloc.get_traced_memory()[0]

        # Retrieve items
        for i in range(100):
            _ = perf_cache_manager.get(f"key_{i}")

        end_mem = tracemalloc.get_traced_memory()[0]

        mem_during = (mid_mem - start_mem) / 1024 / 1024  # MB
        mem_after = (end_mem - start_mem) / 1024 / 1024  # MB

        tracemalloc.stop()

        print(f"✓ Memory during caching: {mem_during:.2f}MB")
        print(f"✓ Memory after retrieval: {mem_after:.2f}MB")

        # Memory shouldn't grow excessively
        assert mem_after < mem_during * 2


class TestScalabilityBenchmarks:
    """Benchmark scalability with different dataset sizes"""

    def test_scalability_validation(self):
        """Test validation scalability across different sizes"""
        sizes = [10, 50, 100, 500, 1000]
        times = []

        np.random.seed(42)

        for size in sizes:
            data = pd.DataFrame({
                'study_id': [f'Study{i}' for i in range(size)],
                'treatment': ['A'] * size,
                'events': np.random.randint(10, 50, size),
                'n': np.random.randint(60, 200, size)
            })
            data['events'] = data[['events', 'n']].min(axis=1) - 5

            start = time.time()
            result = validate_table(data, 'binary')
            elapsed = time.time() - start
            times.append(elapsed)

            assert result.is_valid is True
            print(f"✓ Validation ({size:>4} studies): {elapsed*1000:>7.2f}ms")

        # Check if roughly linear scaling
        # Time per study should be relatively constant
        time_per_study = [t/s for t, s in zip(times, sizes)]
        max_time_per_study = max(time_per_study)
        min_time_per_study = min(time_per_study)

        # Variance should be reasonable (within 10x)
        assert max_time_per_study / min_time_per_study < 10

    def test_scalability_effect_size_computation(self):
        """Test effect size computation scalability"""
        sizes = [10, 50, 100, 500]
        times = []

        np.random.seed(42)

        for size in sizes:
            data = pd.DataFrame({
                'study_id': [f'Study{i}' for i in range(size)],
                'treatment': ['A'] * size,
                'events1': np.random.randint(10, 50, size),
                'n1': np.random.randint(60, 200, size),
                'events2': np.random.randint(10, 50, size),
                'n2': np.random.randint(60, 200, size)
            })
            data['events1'] = data[['events1', 'n1']].min(axis=1) - 5
            data['events2'] = data[['events2', 'n2']].min(axis=1) - 5

            start = time.time()
            result = compute_effect_size(data, 'OR')
            elapsed = time.time() - start
            times.append(elapsed)

            assert len(result) == size
            print(f"✓ Effect size ({size:>3} studies): {elapsed*1000:>7.2f}ms")


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
