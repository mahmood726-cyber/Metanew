"""
Performance Monitoring and Benchmarking System
Track and report performance metrics in real-time
"""

import time
import psutil
import functools
from typing import Callable, Any, Dict, List
from collections import defaultdict
from datetime import datetime
import threading
import json


class PerformanceMonitor:
    """
    Comprehensive performance monitoring system

    Features:
    - Function execution timing
    - Memory usage tracking
    - CPU usage tracking
    - Request throughput
    - Real-time metrics
    """

    def __init__(self):
        self.metrics = defaultdict(list)
        self.counters = defaultdict(int)
        self.lock = threading.Lock()
        self.start_time = time.time()

    def timing_decorator(self, func: Callable) -> Callable:
        """Decorator to measure function execution time"""
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            start = time.perf_counter()

            try:
                result = func(*args, **kwargs)
                status = "success"
                return result
            except Exception as e:
                status = "error"
                raise
            finally:
                elapsed = (time.perf_counter() - start) * 1000  # Convert to ms

                with self.lock:
                    func_name = f"{func.__module__}.{func.__name__}"
                    self.metrics[f"{func_name}.time"].append(elapsed)
                    self.counters[f"{func_name}.{status}"] += 1

        return wrapper

    def record_metric(self, name: str, value: float):
        """Record a custom metric"""
        with self.lock:
            self.metrics[name].append(value)

    def increment_counter(self, name: str, amount: int = 1):
        """Increment a counter"""
        with self.lock:
            self.counters[name] += amount

    def get_stats(self, func_name: str = None) -> Dict:
        """Get statistics for a function or all functions"""
        with self.lock:
            if func_name:
                metric_key = f"{func_name}.time"
                if metric_key not in self.metrics:
                    return {}

                times = self.metrics[metric_key]
                return self._calculate_stats(times)

            # Return all stats
            all_stats = {}
            for key, times in self.metrics.items():
                if key.endswith(".time"):
                    func = key.replace(".time", "")
                    all_stats[func] = self._calculate_stats(times)

            return all_stats

    def _calculate_stats(self, times: List[float]) -> Dict:
        """Calculate statistics from timing data"""
        if not times:
            return {}

        times_sorted = sorted(times)
        n = len(times)

        return {
            "count": n,
            "min_ms": round(min(times), 2),
            "max_ms": round(max(times), 2),
            "mean_ms": round(sum(times) / n, 2),
            "median_ms": round(times_sorted[n // 2], 2),
            "p95_ms": round(times_sorted[int(n * 0.95)], 2),
            "p99_ms": round(times_sorted[int(n * 0.99)], 2),
        }

    def get_system_metrics(self) -> Dict:
        """Get current system performance metrics"""
        process = psutil.Process()

        return {
            "cpu_percent": psutil.cpu_percent(interval=0.1),
            "memory_mb": process.memory_info().rss / 1024 / 1024,
            "memory_percent": process.memory_percent(),
            "threads": process.num_threads(),
            "uptime_seconds": time.time() - self.start_time
        }

    def get_counters(self) -> Dict:
        """Get all counters"""
        with self.lock:
            return dict(self.counters)

    def get_full_report(self) -> Dict:
        """Get comprehensive performance report"""
        return {
            "timestamp": datetime.now().isoformat(),
            "uptime_seconds": time.time() - self.start_time,
            "function_stats": self.get_stats(),
            "system_metrics": self.get_system_metrics(),
            "counters": self.get_counters()
        }

    def reset(self):
        """Reset all metrics"""
        with self.lock:
            self.metrics.clear()
            self.counters.clear()
            self.start_time = time.time()


# Global performance monitor instance
perf_monitor = PerformanceMonitor()


# Convenience decorators
def monitor_performance(func: Callable) -> Callable:
    """Decorator to monitor function performance"""
    return perf_monitor.timing_decorator(func)


def benchmark(iterations: int = 1000):
    """
    Decorator to benchmark a function

    Usage:
    @benchmark(iterations=1000)
    def my_function():
        pass
    """
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            print(f"\n{'='*60}")
            print(f"Benchmarking: {func.__name__}")
            print(f"Iterations: {iterations}")
            print(f"{'='*60}\n")

            times = []
            for i in range(iterations):
                start = time.perf_counter()
                result = func(*args, **kwargs)
                elapsed = (time.perf_counter() - start) * 1000
                times.append(elapsed)

                if (i + 1) % 100 == 0:
                    print(f"Progress: {i + 1}/{iterations}")

            # Calculate statistics
            times_sorted = sorted(times)
            n = len(times)

            stats = {
                "iterations": n,
                "min_ms": round(min(times), 4),
                "max_ms": round(max(times), 4),
                "mean_ms": round(sum(times) / n, 4),
                "median_ms": round(times_sorted[n // 2], 4),
                "p95_ms": round(times_sorted[int(n * 0.95)], 4),
                "p99_ms": round(times_sorted[int(n * 0.99)], 4),
                "total_ms": round(sum(times), 2)
            }

            print(f"\n{'='*60}")
            print("Benchmark Results:")
            print(f"{'='*60}")
            for key, value in stats.items():
                print(f"{key:20s}: {value}")
            print(f"{'='*60}\n")

            return result

        return wrapper
    return decorator


class PerformanceContext:
    """Context manager for measuring code blocks"""

    def __init__(self, name: str):
        self.name = name
        self.start_time = None

    def __enter__(self):
        self.start_time = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        elapsed = (time.perf_counter() - self.start_time) * 1000
        perf_monitor.record_metric(f"{self.name}.time", elapsed)


# Convenience function
def measure(name: str):
    """
    Context manager to measure code block execution time

    Usage:
    with measure("my_operation"):
        # code to measure
        pass
    """
    return PerformanceContext(name)


# Performance comparison utility
def compare_performance(funcs: List[Callable], iterations: int = 100, *args, **kwargs):
    """
    Compare performance of multiple functions

    Args:
        funcs: List of functions to compare
        iterations: Number of iterations per function
        *args, **kwargs: Arguments to pass to functions

    Returns:
        Dict with comparison results
    """
    results = {}

    for func in funcs:
        times = []
        for _ in range(iterations):
            start = time.perf_counter()
            func(*args, **kwargs)
            elapsed = (time.perf_counter() - start) * 1000
            times.append(elapsed)

        avg_time = sum(times) / len(times)
        results[func.__name__] = {
            "avg_ms": round(avg_time, 4),
            "min_ms": round(min(times), 4),
            "max_ms": round(max(times), 4)
        }

    # Calculate speedup
    if len(results) > 1:
        baseline = list(results.values())[0]["avg_ms"]
        for name, data in results.items():
            speedup = baseline / data["avg_ms"]
            data["speedup"] = f"{speedup:.2f}x"

    return results
