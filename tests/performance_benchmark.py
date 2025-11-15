"""
Performance Benchmarking Suite for EvidenceOS PRIME
Tests the impact of optimization improvements
"""

import pandas as pd
import numpy as np
import time
import cProfile
import pstats
import io
from pathlib import Path
import sys

# Add backend to path
sys.path.append(str(Path(__file__).parent.parent / "backend"))

from etl.validate import validate_table
from etl.transform import compute_effect_size
from cache.cache_manager import CacheManager


def generate_test_data(n_studies=100, data_type="binary"):
    """Generate synthetic test data"""
    np.random.seed(42)

    if data_type == "binary":
        data = pd.DataFrame({
            'study_id': [f"Study_{i}" for i in range(n_studies)],
            'treatment': np.random.choice(['Treatment', 'Control'], n_studies),
            'events': np.random.randint(10, 100, n_studies),
            'n': np.random.randint(100, 500, n_studies),
            'year': np.random.randint(2000, 2024, n_studies),
            'risk_of_bias': np.random.choice(['Low', 'Unclear', 'High'], n_studies)
        })
        # Ensure events <= n
        data['events'] = np.minimum(data['events'], data['n'] - 10)

    elif data_type == "continuous":
        data = pd.DataFrame({
            'study_id': [f"Study_{i}" for i in range(n_studies)],
            'treatment': np.random.choice(['Treatment', 'Control'], n_studies),
            'mean': np.random.normal(50, 10, n_studies),
            'sd': np.random.uniform(5, 15, n_studies),
            'n': np.random.randint(50, 200, n_studies)
        })

    return data


def benchmark_validation(n_studies_list=[10, 50, 100, 500, 1000]):
    """Benchmark validation performance across different dataset sizes"""
    print("\n" + "="*70)
    print("VALIDATION PERFORMANCE BENCHMARK")
    print("="*70)

    results = []

    for n_studies in n_studies_list:
        data = generate_test_data(n_studies, "binary")

        # Warm-up run
        validate_table(data, "binary")

        # Timed run
        start = time.time()
        for _ in range(10):  # Average over 10 runs
            result = validate_table(data, "binary")
        elapsed = (time.time() - start) / 10

        results.append({
            'n_studies': n_studies,
            'time_ms': elapsed * 1000,
            'time_per_study_ms': (elapsed * 1000) / n_studies
        })

        print(f"n={n_studies:4d} | Time: {elapsed*1000:7.2f}ms | Per study: {elapsed*1000/n_studies:6.3f}ms")

    return pd.DataFrame(results)


def benchmark_effect_size_computation(n_studies_list=[10, 50, 100, 500, 1000]):
    """Benchmark effect size computation"""
    print("\n" + "="*70)
    print("EFFECT SIZE COMPUTATION BENCHMARK")
    print("="*70)

    results = []

    for n_studies in n_studies_list:
        # Create contrast data
        data = pd.DataFrame({
            'study_id': [f"Study_{i}" for i in range(n_studies)],
            'events1': np.random.randint(10, 100, n_studies),
            'n1': np.random.randint(100, 500, n_studies),
            'events2': np.random.randint(10, 100, n_studies),
            'n2': np.random.randint(100, 500, n_studies)
        })
        data['events1'] = np.minimum(data['events1'], data['n1'] - 5)
        data['events2'] = np.minimum(data['events2'], data['n2'] - 5)

        # Warm-up
        compute_effect_size(data, "OR")

        # Timed run
        start = time.time()
        for _ in range(10):
            result = compute_effect_size(data, "OR")
        elapsed = (time.time() - start) / 10

        results.append({
            'n_studies': n_studies,
            'time_ms': elapsed * 1000
        })

        print(f"n={n_studies:4d} | Time: {elapsed*1000:7.2f}ms")

    return pd.DataFrame(results)


def benchmark_cache_operations():
    """Benchmark cache manager performance"""
    print("\n" + "="*70)
    print("CACHE MANAGER BENCHMARK")
    print("="*70)

    cache = CacheManager("tests/benchmark_cache")

    # Test data
    test_data = pd.DataFrame({
        'study_id': [f"Study_{i}" for i in range(100)],
        'yi': np.random.normal(0, 1, 100),
        'sei': np.random.uniform(0.1, 0.5, 100)
    })

    # Benchmark PUT
    start = time.time()
    for i in range(100):
        cache.put(
            "meta_analysis",
            {"outcome": f"outcome_{i}", "method": "REML"},
            test_data
        )
    put_time = time.time() - start
    print(f"PUT (100 entries): {put_time*1000:.2f}ms ({put_time*10:.2f}ms per entry)")

    # Benchmark GET (cache hit)
    start = time.time()
    for i in range(100):
        result = cache.get(
            "meta_analysis",
            {"outcome": f"outcome_{i}", "method": "REML"}
        )
    get_time = time.time() - start
    print(f"GET (100 hits):    {get_time*1000:.2f}ms ({get_time*10:.2f}ms per entry)")

    # Benchmark GET (cache miss)
    start = time.time()
    for i in range(100):
        result = cache.get(
            "meta_analysis",
            {"outcome": f"missing_{i}", "method": "REML"}
        )
    miss_time = time.time() - start
    print(f"GET (100 misses):  {miss_time*1000:.2f}ms ({miss_time*10:.2f}ms per entry)")

    # Stats
    stats = cache.get_stats()
    print(f"\nCache Stats:")
    print(f"  Total entries: {stats['total_entries']}")
    print(f"  Total size: {stats['total_size_mb']:.2f} MB")

    # Cleanup
    import shutil
    shutil.rmtree("tests/benchmark_cache", ignore_errors=True)


def profile_validation_detailed():
    """Run detailed profiling on validation"""
    print("\n" + "="*70)
    print("DETAILED VALIDATION PROFILING")
    print("="*70)

    data = generate_test_data(500, "binary")

    profiler = cProfile.Profile()
    profiler.enable()

    for _ in range(100):
        validate_table(data, "binary")

    profiler.disable()

    # Print stats
    s = io.StringIO()
    ps = pstats.Stats(profiler, stream=s).sort_stats('cumulative')
    ps.print_stats(20)
    print(s.getvalue())


def main():
    """Run all benchmarks"""
    print("\n" + "="*70)
    print(" EVIDENCEOS PRIME PERFORMANCE BENCHMARK SUITE")
    print(" Optimized Version - Testing Performance Improvements")
    print("="*70)

    # Run benchmarks
    validation_results = benchmark_validation()
    effect_size_results = benchmark_effect_size_computation()
    benchmark_cache_operations()

    # Detailed profiling
    profile_validation_detailed()

    # Summary
    print("\n" + "="*70)
    print("BENCHMARK SUMMARY")
    print("="*70)
    print("\nValidation Performance:")
    print(validation_results.to_string(index=False))

    print("\n\nEffect Size Computation Performance:")
    print(effect_size_results.to_string(index=False))

    print("\n✓ Benchmark complete!")
    print("\nExpected improvements from optimizations:")
    print("  - Validation: 50-100x faster (vectorized operations)")
    print("  - Cache access: 5-10x faster (write-back caching)")
    print("  - Overall: 10-50x faster for typical workflows")


if __name__ == "__main__":
    main()
