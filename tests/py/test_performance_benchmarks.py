"""
Performance benchmarking suite for EvidenceOS PRIME
Tests system performance under various load conditions
"""
import pytest
import pandas as pd
import numpy as np
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from etl.validate import validate_table
from etl.transform import compute_effect_size
from cache.cache_manager import CacheManager
import tempfile
import shutil


class BenchmarkResult:
    """Store benchmark results"""
    def __init__(self, name, duration, operations, rate):
        self.name = name
        self.duration = duration
        self.operations = operations
        self.rate = rate  # ops/second

    def __repr__(self):
        return f"{self.name}: {self.operations} ops in {self.duration:.3f}s ({self.rate:.1f} ops/sec)"


class PerformanceBenchmarks:
    """Performance benchmarking test suite"""

    @pytest.fixture
    def small_dataset(self):
        """Small dataset (10 studies)"""
        return pd.DataFrame({
            'study_id': [f'S{i}' for i in range(10)],
            'treatment': ['A'] * 10,
            'events1': np.random.randint(10, 50, 10),
            'n1': np.random.randint(100, 200, 10),
            'events2': np.random.randint(10, 50, 10),
            'n2': np.random.randint(100, 200, 10)
        })

    @pytest.fixture
    def medium_dataset(self):
        """Medium dataset (100 studies)"""
        return pd.DataFrame({
            'study_id': [f'S{i}' for i in range(100)],
            'treatment': ['A'] * 100,
            'events1': np.random.randint(10, 50, 100),
            'n1': np.random.randint(100, 200, 100),
            'events2': np.random.randint(10, 50, 100),
            'n2': np.random.randint(100, 200, 100)
        })

    @pytest.fixture
    def large_dataset(self):
        """Large dataset (1000 studies)"""
        return pd.DataFrame({
            'study_id': [f'S{i}' for i in range(1000)],
            'treatment': ['A'] * 1000,
            'events1': np.random.randint(10, 50, 1000),
            'n1': np.random.randint(100, 200, 1000),
            'events2': np.random.randint(10, 50, 1000),
            'n2': np.random.randint(100, 200, 1000)
        })

    @pytest.fixture
    def xlarge_dataset(self):
        """Extra large dataset (5000 studies) for stress testing"""
        return pd.DataFrame({
            'study_id': [f'S{i}' for i in range(5000)],
            'treatment': ['A'] * 5000,
            'events1': np.random.randint(10, 50, 5000),
            'n1': np.random.randint(100, 200, 5000),
            'events2': np.random.randint(10, 50, 5000),
            'n2': np.random.randint(100, 200, 5000)
        })

    def benchmark(self, func, name, iterations=10):
        """Run benchmark and return results"""
        start = time.time()
        for _ in range(iterations):
            func()
        duration = time.time() - start
        rate = iterations / duration
        return BenchmarkResult(name, duration, iterations, rate)

    # ===========================================
    # VALIDATION BENCHMARKS
    # ===========================================

    def test_validate_small_dataset(self, small_dataset, benchmark_results=[]):
        """Benchmark validation with small dataset"""
        def validate():
            validate_table(small_dataset, "binary")

        result = self.benchmark(validate, "Validate 10 studies", iterations=100)
        print(result)
        assert result.rate > 50  # Should handle 50+ validations/sec

    def test_validate_medium_dataset(self, medium_dataset):
        """Benchmark validation with medium dataset"""
        def validate():
            validate_table(medium_dataset, "binary")

        result = self.benchmark(validate, "Validate 100 studies", iterations=50)
        print(result)
        assert result.rate > 10  # Should handle 10+ validations/sec

    def test_validate_large_dataset(self, large_dataset):
        """Benchmark validation with large dataset"""
        def validate():
            validate_table(large_dataset, "binary")

        result = self.benchmark(validate, "Validate 1000 studies", iterations=10)
        print(result)
        assert result.rate > 1  # Should handle 1+ validation/sec

    # ===========================================
    # EFFECT SIZE COMPUTATION BENCHMARKS
    # ===========================================

    def test_compute_or_small(self, small_dataset):
        """Benchmark OR computation with small dataset"""
        def compute():
            compute_effect_size(small_dataset, "OR")

        result = self.benchmark(compute, "Compute OR (10 studies)", iterations=100)
        print(result)
        assert result.rate > 100  # Should handle 100+ computations/sec

    def test_compute_or_medium(self, medium_dataset):
        """Benchmark OR computation with medium dataset"""
        def compute():
            compute_effect_size(medium_dataset, "OR")

        result = self.benchmark(compute, "Compute OR (100 studies)", iterations=50)
        print(result)
        assert result.rate > 20  # Should handle 20+ computations/sec

    def test_compute_or_large(self, large_dataset):
        """Benchmark OR computation with large dataset"""
        def compute():
            compute_effect_size(large_dataset, "OR")

        result = self.benchmark(compute, "Compute OR (1000 studies)", iterations=10)
        print(result)
        assert result.rate > 2  # Should handle 2+ computations/sec

    # ===========================================
    # CACHE PERFORMANCE BENCHMARKS
    # ===========================================

    def test_cache_write_performance(self, medium_dataset):
        """Benchmark cache write performance"""
        temp_dir = tempfile.mkdtemp()
        try:
            cm = CacheManager(cache_dir=temp_dir)

            start = time.time()
            for i in range(50):
                cm.put(f"test_{i}", {"id": i}, medium_dataset)
            duration = time.time() - start

            rate = 50 / duration
            print(f"Cache write: 50 ops in {duration:.3f}s ({rate:.1f} ops/sec)")
            assert rate > 5  # Should handle 5+ writes/sec

        finally:
            shutil.rmtree(temp_dir)

    def test_cache_read_performance(self, medium_dataset):
        """Benchmark cache read performance"""
        temp_dir = tempfile.mkdtemp()
        try:
            cm = CacheManager(cache_dir=temp_dir)

            # Write once
            cm.put("test", {"id": 1}, medium_dataset)

            # Read many times
            start = time.time()
            for _ in range(100):
                cm.get("test", {"id": 1})
            duration = time.time() - start

            rate = 100 / duration
            print(f"Cache read: 100 ops in {duration:.3f}s ({rate:.1f} ops/sec)")
            assert rate > 50  # Should handle 50+ reads/sec

        finally:
            shutil.rmtree(temp_dir)

    def test_cache_vs_recompute(self, medium_dataset):
        """Compare cache read vs recomputation speedup"""
        temp_dir = tempfile.mkdtemp()
        try:
            cm = CacheManager(cache_dir=temp_dir)

            # Measure recomputation time
            start = time.time()
            for _ in range(10):
                compute_effect_size(medium_dataset, "OR")
            recompute_time = time.time() - start

            # Cache once
            result = compute_effect_size(medium_dataset, "OR")
            cm.put("test", {"measure": "OR"}, result)

            # Measure cache read time
            start = time.time()
            for _ in range(10):
                cm.get("test", {"measure": "OR"})
            cache_time = time.time() - start

            speedup = recompute_time / cache_time
            print(f"Cache speedup: {speedup:.1f}x faster")
            assert speedup > 5  # Cache should be 5x+ faster

        finally:
            shutil.rmtree(temp_dir)

    # ===========================================
    # CONCURRENT OPERATIONS BENCHMARKS
    # ===========================================

    def test_concurrent_validations(self, medium_dataset):
        """Benchmark concurrent validation operations"""
        def validate_task(task_id):
            validate_table(medium_dataset, "binary")
            return task_id

        start = time.time()
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = [executor.submit(validate_task, i) for i in range(20)]
            results = [f.result() for f in as_completed(futures)]
        duration = time.time() - start

        rate = 20 / duration
        print(f"Concurrent validation: 20 ops in {duration:.3f}s ({rate:.1f} ops/sec)")
        assert rate > 5  # Should handle 5+ concurrent ops/sec
        assert len(results) == 20  # All tasks completed

    def test_concurrent_effect_size_computation(self, medium_dataset):
        """Benchmark concurrent effect size computations"""
        def compute_task(task_id):
            compute_effect_size(medium_dataset, "OR")
            return task_id

        start = time.time()
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = [executor.submit(compute_task, i) for i in range(20)]
            results = [f.result() for f in as_completed(futures)]
        duration = time.time() - start

        rate = 20 / duration
        print(f"Concurrent computation: 20 ops in {duration:.3f}s ({rate:.1f} ops/sec)")
        assert rate > 5  # Should handle 5+ concurrent ops/sec
        assert len(results) == 20  # All tasks completed

    # ===========================================
    # MEMORY USAGE BENCHMARKS
    # ===========================================

    def test_memory_efficiency_large_dataset(self, large_dataset):
        """Test memory usage doesn't explode with large datasets"""
        import psutil
        import os

        process = psutil.Process(os.getpid())
        mem_before = process.memory_info().rss / 1024 / 1024  # MB

        # Perform multiple operations
        for _ in range(10):
            validate_table(large_dataset, "binary")
            compute_effect_size(large_dataset, "OR")

        mem_after = process.memory_info().rss / 1024 / 1024  # MB
        mem_increase = mem_after - mem_before

        print(f"Memory increase: {mem_increase:.1f} MB")
        assert mem_increase < 500  # Should not increase by more than 500MB

    # ===========================================
    # SCALABILITY TESTS
    # ===========================================

    def test_scalability_validation(self):
        """Test validation scales linearly with dataset size"""
        sizes = [10, 100, 1000]
        times = []

        for size in sizes:
            df = pd.DataFrame({
                'study_id': [f'S{i}' for i in range(size)],
                'treatment': ['A'] * size,
                'events1': np.random.randint(10, 50, size),
                'n1': np.random.randint(100, 200, size),
                'events2': np.random.randint(10, 50, size),
                'n2': np.random.randint(100, 200, size)
            })

            start = time.time()
            validate_table(df, "binary")
            duration = time.time() - start
            times.append(duration)

        # Check scalability (time should scale roughly linearly)
        time_per_study_10 = times[0] / 10
        time_per_study_100 = times[1] / 100
        time_per_study_1000 = times[2] / 1000

        print(f"Time per study: 10={time_per_study_10:.6f}s, 100={time_per_study_100:.6f}s, 1000={time_per_study_1000:.6f}s")

        # Time per study should not increase more than 2x across scales
        assert time_per_study_1000 / time_per_study_10 < 2

    # ===========================================
    # API ENDPOINT BENCHMARKS (requires running server)
    # ===========================================

    @pytest.mark.skipif(True, reason="Requires running server")
    def test_api_endpoint_throughput(self):
        """Benchmark API endpoint throughput"""
        import requests

        payload = {
            "data": [
                {
                    "study_id": f"S{i}",
                    "treatment": "A",
                    "events": 10,
                    "n": 100
                } for i in range(50)
            ],
            "data_type": "binary"
        }

        start = time.time()
        for _ in range(20):
            response = requests.post("http://localhost:8000/validate", json=payload)
            assert response.status_code == 200
        duration = time.time() - start

        rate = 20 / duration
        print(f"API throughput: 20 requests in {duration:.3f}s ({rate:.1f} req/sec)")
        assert rate > 5  # Should handle 5+ requests/sec


# ===========================================
# BENCHMARK REPORT GENERATOR
# ===========================================

class BenchmarkReport:
    """Generate benchmark report"""

    @staticmethod
    def generate_report(results: list):
        """Generate markdown report from benchmark results"""
        report = "# EvidenceOS PRIME Performance Benchmark Report\n\n"
        report += f"**Generated:** {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n"

        report += "## Summary\n\n"
        report += "| Benchmark | Operations | Duration (s) | Rate (ops/sec) | Status |\n"
        report += "|-----------|------------|--------------|----------------|---------|\n"

        for result in results:
            status = "✅ PASS" if result.rate > 1 else "⚠️ SLOW"
            report += f"| {result.name} | {result.operations} | {result.duration:.3f} | {result.rate:.1f} | {status} |\n"

        report += "\n## Performance Targets\n\n"
        report += "- **Validation:** 10+ ops/sec for 100-study datasets\n"
        report += "- **Effect Size Computation:** 20+ ops/sec for 100-study datasets\n"
        report += "- **Cache Read:** 50+ ops/sec\n"
        report += "- **Cache Write:** 5+ ops/sec\n"
        report += "- **Concurrent Operations:** 5+ ops/sec with 4 workers\n"

        return report


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short', '-s'])
