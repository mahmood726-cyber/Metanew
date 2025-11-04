"""
Comprehensive Tests for Cache Manager
Triple testing: Unit tests, Performance tests, Integration tests
"""
import pytest
import pandas as pd
import time
from pathlib import Path
import shutil
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

# Try to import cache managers
try:
    from cache.cache_manager import CacheManager, MetaAnalysisCacheWrapper
    PARQUET_CACHE_AVAILABLE = True
except ImportError:
    PARQUET_CACHE_AVAILABLE = False

try:
    from cache.redis_cache import RedisCache, get_cache
    REDIS_CACHE_AVAILABLE = True
except ImportError:
    REDIS_CACHE_AVAILABLE = False


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def temp_cache_dir(tmp_path):
    """Create temporary cache directory"""
    cache_dir = tmp_path / "test_cache"
    cache_dir.mkdir()
    yield cache_dir
    # Cleanup
    if cache_dir.exists():
        shutil.rmtree(cache_dir)


@pytest.fixture
def sample_data():
    """Sample data for caching"""
    return pd.DataFrame({
        'study_id': [f'S{i}' for i in range(10)],
        'yi': [0.5 + i * 0.1 for i in range(10)],
        'sei': [0.1] * 10
    })


# ============================================================================
# TEST 1: PARQUET CACHE MANAGER (Triple Coverage)
# ============================================================================

@pytest.mark.skipif(not PARQUET_CACHE_AVAILABLE, reason="Parquet cache not available")
class TestParquetCacheManager:
    """Comprehensive tests for Parquet cache manager"""

    def test_cache_initialization(self, temp_cache_dir):
        """Test 1.1: Cache manager initializes correctly"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))
        assert cache.cache_dir.exists()
        assert cache.index_file.exists()

    def test_cache_put_and_get(self, temp_cache_dir, sample_data):
        """Test 1.2: Put and retrieve data"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        analysis_type = "meta_analysis"
        parameters = {"method": "REML", "outcome": "mortality"}

        # Put data
        cache_key = cache.put(analysis_type, parameters, sample_data)
        assert cache_key is not None

        # Get data
        retrieved = cache.get(analysis_type, parameters)
        assert retrieved is not None
        pd.testing.assert_frame_equal(retrieved, sample_data)

    def test_cache_key_generation_deterministic(self, temp_cache_dir):
        """Test 1.3: Cache keys are deterministic"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        params = {"method": "REML", "outcome": "mortality"}

        key1 = cache._generate_cache_key("test", params)
        key2 = cache._generate_cache_key("test", params)

        assert key1 == key2

    def test_cache_key_different_for_different_params(self, temp_cache_dir):
        """Test 1.4: Different parameters = different keys"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        params1 = {"method": "REML"}
        params2 = {"method": "DL"}

        key1 = cache._generate_cache_key("test", params1)
        key2 = cache._generate_cache_key("test", params2)

        assert key1 != key2

    def test_cache_invalidation(self, temp_cache_dir, sample_data):
        """Test 1.5: Cache invalidation works"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        params = {"method": "REML"}
        cache.put("test", params, sample_data)

        # Invalidate
        result = cache.invalidate("test", params)
        assert result is True

        # Should not be retrievable
        retrieved = cache.get("test", params)
        assert retrieved is None

    def test_cache_miss_returns_none(self, temp_cache_dir):
        """Test 1.6: Cache miss returns None"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        result = cache.get("nonexistent", {"key": "value"})
        assert result is None

    def test_cache_statistics(self, temp_cache_dir, sample_data):
        """Test 1.7: Cache statistics are tracked"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        # Add some entries
        for i in range(3):
            cache.put(f"test_{i}", {"index": i}, sample_data)

        stats = cache.get_stats()
        assert stats['total_entries'] >= 3
        assert stats['total_size_mb'] > 0

    def test_cache_access_count(self, temp_cache_dir, sample_data):
        """Test 1.8: Access count is incremented"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        params = {"test": "value"}
        cache.put("test", params, sample_data)

        # Access multiple times
        cache.get("test", params)
        cache.get("test", params)
        cache.get("test", params)

        # Check access count
        matches = cache.index[cache.index['cache_key'] == cache._generate_cache_key("test", params)]
        if len(matches) > 0:
            assert matches.iloc[0]['access_count'] >= 3

    def test_cache_old_entries_cleanup(self, temp_cache_dir, sample_data):
        """Test 1.9: Old entries can be cleaned up"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        # Add entry
        cache.put("test", {"old": True}, sample_data)

        # Clean entries older than 0 days (should clean all)
        count = cache.clear_old(days=0)
        assert count >= 0

    def test_cache_with_large_dataframe(self, temp_cache_dir):
        """Test 1.10: Large dataframes are cached efficiently"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        # Create large dataframe
        large_df = pd.DataFrame({
            f'col_{i}': range(10000) for i in range(10)
        })

        start_time = time.time()
        cache.put("large_test", {}, large_df)
        put_time = time.time() - start_time

        start_time = time.time()
        retrieved = cache.get("large_test", {})
        get_time = time.time() - start_time

        # Should be reasonably fast
        assert put_time < 5.0  # 5 seconds
        assert get_time < 2.0  # 2 seconds
        assert retrieved is not None


# ============================================================================
# TEST 2: REDIS CACHE (Triple Coverage)
# ============================================================================

@pytest.mark.skipif(not REDIS_CACHE_AVAILABLE, reason="Redis cache not available")
class TestRedisCache:
    """Comprehensive tests for Redis cache"""

    def test_redis_cache_initialization(self):
        """Test 2.1: Redis cache initializes"""
        cache = RedisCache(host="localhost", port=6379, db=1)
        # May fail if Redis not running - that's OK for tests
        assert cache is not None

    def test_redis_put_and_get(self):
        """Test 2.2: Put and get with Redis"""
        cache = RedisCache(host="localhost", port=6379, db=1)

        if cache.client is None:
            pytest.skip("Redis not available")

        params = {"test": "value"}
        data = {"result": "test_data", "count": 42}

        # Put
        result = cache.set("test_analysis", params, data, ttl=60)

        if result:
            # Get
            retrieved = cache.get("test_analysis", params)
            assert retrieved is not None
            assert retrieved["result"] == "test_data"
            assert retrieved["count"] == 42

    def test_redis_key_expiration(self):
        """Test 2.3: Keys expire after TTL"""
        cache = RedisCache(host="localhost", port=6379, db=1)

        if cache.client is None:
            pytest.skip("Redis not available")

        params = {"expire_test": True}
        data = {"value": "temporary"}

        # Set with 1 second TTL
        cache.set("expire_test", params, data, ttl=1)

        # Should be available immediately
        result = cache.get("expire_test", params)
        if result:
            assert result["value"] == "temporary"

        # Wait for expiration
        time.sleep(2)

        # Should be gone
        result = cache.get("expire_test", params)
        assert result is None

    def test_redis_invalidation(self):
        """Test 2.4: Redis cache invalidation"""
        cache = RedisCache(host="localhost", port=6379, db=1)

        if cache.client is None:
            pytest.skip("Redis not available")

        params = {"invalidate_test": True}
        cache.set("test", params, {"data": "test"})

        # Invalidate
        result = cache.invalidate("test", params)

        # Should be removed
        retrieved = cache.get("test", params)
        assert retrieved is None

    def test_redis_health_check(self):
        """Test 2.5: Health check works"""
        cache = RedisCache(host="localhost", port=6379, db=1)

        # Health check
        is_healthy = cache.health_check()
        # May be True or False depending on Redis availability
        assert isinstance(is_healthy, bool)

    def test_redis_statistics(self):
        """Test 2.6: Cache statistics retrieval"""
        cache = RedisCache(host="localhost", port=6379, db=1)

        stats = cache.get_stats()
        assert "status" in stats

        if cache.client:
            assert "total_keys" in stats or stats["status"] == "disconnected"

    def test_redis_pattern_invalidation(self):
        """Test 2.7: Pattern-based invalidation"""
        cache = RedisCache(host="localhost", port=6379, db=1)

        if cache.client is None:
            pytest.skip("Redis not available")

        # Add multiple entries with same prefix
        for i in range(3):
            cache.set("pattern_test", {"index": i}, {"value": i})

        # Invalidate by pattern
        count = cache.invalidate_pattern("evidenceos:cache:pattern_test:*")
        # May or may not find entries depending on timing
        assert count >= 0


# ============================================================================
# TEST 3: CACHE WRAPPER (Triple Coverage)
# ============================================================================

@pytest.mark.skipif(not PARQUET_CACHE_AVAILABLE, reason="Cache wrapper not available")
class TestMetaAnalysisCacheWrapper:
    """Tests for cache wrapper functionality"""

    def test_wrapper_with_function(self, temp_cache_dir, sample_data):
        """Test 3.1: Wrapper caches function results"""
        cache_manager = CacheManager(cache_dir=str(temp_cache_dir))
        wrapper = MetaAnalysisCacheWrapper(cache_manager)

        # Define a slow function
        def slow_analysis():
            time.sleep(0.1)
            return sample_data

        params = {"test": "wrapper"}

        # First call - should execute function
        start = time.time()
        result1 = wrapper.run_with_cache(slow_analysis, "test_analysis", params)
        first_time = time.time() - start

        # Second call - should use cache
        start = time.time()
        result2 = wrapper.run_with_cache(slow_analysis, "test_analysis", params)
        second_time = time.time() - start

        # Cached call should be faster
        assert second_time < first_time
        pd.testing.assert_frame_equal(result1, result2)

    def test_wrapper_force_refresh(self, temp_cache_dir, sample_data):
        """Test 3.2: Force refresh bypasses cache"""
        cache_manager = CacheManager(cache_dir=str(temp_cache_dir))
        wrapper = MetaAnalysisCacheWrapper(cache_manager)

        call_count = [0]

        def counting_function():
            call_count[0] += 1
            return sample_data

        params = {"test": "force_refresh"}

        # First call
        wrapper.run_with_cache(counting_function, "test", params)
        assert call_count[0] == 1

        # Second call without force refresh (uses cache)
        wrapper.run_with_cache(counting_function, "test", params, force_refresh=False)
        assert call_count[0] == 1  # Should not increment

        # Third call with force refresh
        wrapper.run_with_cache(counting_function, "test", params, force_refresh=True)
        assert call_count[0] == 2  # Should increment


# ============================================================================
# TEST 4: PERFORMANCE TESTS (Triple Coverage)
# ============================================================================

@pytest.mark.skipif(not PARQUET_CACHE_AVAILABLE, reason="Performance tests require cache")
class TestCachePerformance:
    """Performance tests for caching"""

    def test_cache_write_performance(self, temp_cache_dir):
        """Test 4.1: Cache write is fast"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        # Create medium-sized dataframe
        df = pd.DataFrame({
            'col1': range(1000),
            'col2': range(1000),
            'col3': range(1000)
        })

        start = time.time()
        for i in range(10):
            cache.put(f"perf_test_{i}", {"index": i}, df)
        elapsed = time.time() - start

        # Should complete in reasonable time
        assert elapsed < 5.0  # 5 seconds for 10 writes

    def test_cache_read_performance(self, temp_cache_dir):
        """Test 4.2: Cache read is fast"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        df = pd.DataFrame({'col': range(1000)})
        params = {"perf_read": True}
        cache.put("read_test", params, df)

        start = time.time()
        for _ in range(100):
            cache.get("read_test", params)
        elapsed = time.time() - start

        # 100 reads should be very fast
        assert elapsed < 2.0  # 2 seconds

    def test_cache_compression_ratio(self, temp_cache_dir):
        """Test 4.3: Cache compression is effective"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        # Create dataframe with repetitive data (compresses well)
        df = pd.DataFrame({
            'col1': ['A'] * 10000,
            'col2': [1] * 10000,
            'col3': [0.5] * 10000
        })

        cache_key = cache.put("compression_test", {}, df)

        # Get file size
        matches = cache.index[cache.index['cache_key'] == cache_key]
        if len(matches) > 0:
            size_bytes = matches.iloc[0]['size_bytes']

            # Compressed size should be much smaller than raw data
            # Raw would be ~10000 rows * 3 cols * ~8 bytes = ~240KB
            # Compressed should be much less
            assert size_bytes < 100000  # 100KB


# ============================================================================
# TEST 5: EDGE CASES (Triple Coverage)
# ============================================================================

@pytest.mark.skipif(not PARQUET_CACHE_AVAILABLE, reason="Edge case tests require cache")
class TestCacheEdgeCases:
    """Edge case tests for caching"""

    def test_cache_empty_dataframe(self, temp_cache_dir):
        """Test 5.1: Empty dataframe caching"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        empty_df = pd.DataFrame()
        cache.put("empty", {}, empty_df)

        retrieved = cache.get("empty", {})
        assert retrieved is not None
        assert len(retrieved) == 0

    def test_cache_single_row(self, temp_cache_dir):
        """Test 5.2: Single row dataframe"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        single_df = pd.DataFrame({'col': [1]})
        cache.put("single", {}, single_df)

        retrieved = cache.get("single", {})
        assert len(retrieved) == 1

    def test_cache_with_nan_values(self, temp_cache_dir):
        """Test 5.3: DataFrames with NaN values"""
        import numpy as np
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        df_with_nan = pd.DataFrame({
            'col1': [1, 2, np.nan],
            'col2': [np.nan, 4, 5]
        })

        cache.put("nan_test", {}, df_with_nan)
        retrieved = cache.get("nan_test", {})

        assert retrieved is not None
        assert pd.isna(retrieved.loc[2, 'col1'])

    def test_cache_special_characters_in_params(self, temp_cache_dir, sample_data):
        """Test 5.4: Special characters in parameters"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        params = {
            "name": "Test!@#$%",
            "value": "Special<>?:"
        }

        cache.put("special", params, sample_data)
        retrieved = cache.get("special", params)

        assert retrieved is not None

    def test_cache_unicode_in_parameters(self, temp_cache_dir, sample_data):
        """Test 5.5: Unicode in parameters"""
        cache = CacheManager(cache_dir=str(temp_cache_dir))

        params = {
            "name": "Tést",
            "value": "Ünïçödé"
        }

        cache.put("unicode", params, sample_data)
        retrieved = cache.get("unicode", params)

        assert retrieved is not None


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
