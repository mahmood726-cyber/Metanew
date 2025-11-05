"""
Comprehensive Tests for Cache Manager
Tests for caching functionality and cache operations
"""
import pytest
import time
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock


class TestCacheManager:
    """Test cache manager functionality"""

    @pytest.fixture
    def cache_manager(self):
        """Create cache manager instance"""
        from cache.cache_manager import CacheManager
        return CacheManager()

    def test_cache_manager_initialization(self, cache_manager):
        """Test cache manager can be initialized"""
        assert cache_manager is not None

    def test_set_and_get_value(self, cache_manager):
        """Test setting and getting cache values"""
        key = "test_key"
        value = "test_value"

        cache_manager.set(key, value)
        retrieved = cache_manager.get(key)

        assert retrieved == value

    def test_get_nonexistent_key_returns_none(self, cache_manager):
        """Test getting nonexistent key returns None"""
        result = cache_manager.get("nonexistent_key_12345")

        assert result is None

    def test_cache_expiration(self, cache_manager):
        """Test cache entries expire after TTL"""
        key = "expiring_key"
        value = "expiring_value"
        ttl = 1  # 1 second

        cache_manager.set(key, value, ttl=ttl)

        # Should exist immediately
        assert cache_manager.get(key) == value

        # Wait for expiration
        time.sleep(ttl + 0.5)

        # Should be None after expiration
        assert cache_manager.get(key) is None

    def test_delete_key(self, cache_manager):
        """Test deleting cache keys"""
        key = "delete_key"
        value = "delete_value"

        cache_manager.set(key, value)
        assert cache_manager.get(key) == value

        cache_manager.delete(key)
        assert cache_manager.get(key) is None

    def test_clear_all_cache(self, cache_manager):
        """Test clearing all cache entries"""
        cache_manager.set("key1", "value1")
        cache_manager.set("key2", "value2")

        cache_manager.clear()

        assert cache_manager.get("key1") is None
        assert cache_manager.get("key2") is None

    def test_cache_hit_tracking(self, cache_manager):
        """Test cache hit/miss tracking"""
        key = "tracked_key"
        value = "tracked_value"

        cache_manager.set(key, value)

        # Hit
        cache_manager.get(key)

        # Miss
        cache_manager.get("nonexistent")

        stats = cache_manager.get_stats()
        assert "hits" in stats or "hit_count" in stats
        assert "misses" in stats or "miss_count" in stats

    def test_cache_with_complex_objects(self, cache_manager):
        """Test caching complex Python objects"""
        key = "complex_key"
        value = {
            "nested": {
                "data": [1, 2, 3],
                "string": "test"
            },
            "number": 42
        }

        cache_manager.set(key, value)
        retrieved = cache_manager.get(key)

        assert retrieved == value
        assert retrieved["nested"]["data"] == [1, 2, 3]


class TestCacheDecorator:
    """Test cache decorator functionality"""

    def test_cache_decorator_basic(self):
        """Test basic cache decorator usage"""
        from cache.cache_manager import cache_result

        call_count = 0

        @cache_result(ttl=60)
        def expensive_function(x):
            nonlocal call_count
            call_count += 1
            return x * 2

        # First call - should execute function
        result1 = expensive_function(5)
        assert result1 == 10
        assert call_count == 1

        # Second call - should use cache
        result2 = expensive_function(5)
        assert result2 == 10
        assert call_count == 1  # Not incremented

    def test_cache_decorator_with_different_args(self):
        """Test cache decorator with different arguments"""
        from cache.cache_manager import cache_result

        @cache_result(ttl=60)
        def add(a, b):
            return a + b

        result1 = add(1, 2)
        result2 = add(3, 4)

        assert result1 == 3
        assert result2 == 7
        # Different args should give different results


class TestCacheStatistics:
    """Test cache statistics tracking"""

    @pytest.fixture
    def cache_manager(self):
        """Create fresh cache manager"""
        from cache.cache_manager import CacheManager
        manager = CacheManager()
        manager.clear()
        return manager

    def test_get_cache_statistics(self, cache_manager):
        """Test retrieving cache statistics"""
        stats = cache_manager.get_stats()

        assert stats is not None
        assert isinstance(stats, dict)

    def test_cache_size_tracking(self, cache_manager):
        """Test cache size is tracked"""
        cache_manager.set("key1", "value1")
        cache_manager.set("key2", "value2")

        stats = cache_manager.get_stats()

        assert "size" in stats or "total_keys" in stats
        size = stats.get("size") or stats.get("total_keys")
        assert size >= 2

    def test_hit_rate_calculation(self, cache_manager):
        """Test hit rate calculation"""
        # Set values
        cache_manager.set("key1", "value1")
        cache_manager.set("key2", "value2")

        # Create hits and misses
        cache_manager.get("key1")  # Hit
        cache_manager.get("key2")  # Hit
        cache_manager.get("nonexistent1")  # Miss
        cache_manager.get("nonexistent2")  # Miss

        stats = cache_manager.get_stats()

        assert "hit_rate" in stats or ("hits" in stats and "misses" in stats)


class TestCachePatternsMatching:
    """Test cache pattern matching and bulk operations"""

    @pytest.fixture
    def cache_manager(self):
        """Create cache manager"""
        from cache.cache_manager import CacheManager
        return CacheManager()

    def test_delete_by_pattern(self, cache_manager):
        """Test deleting cache keys by pattern"""
        # Set keys with pattern
        cache_manager.set("user:1:profile", "data1")
        cache_manager.set("user:2:profile", "data2")
        cache_manager.set("product:1:info", "data3")

        # Delete all user keys
        cache_manager.delete_pattern("user:*")

        # User keys should be gone
        assert cache_manager.get("user:1:profile") is None
        assert cache_manager.get("user:2:profile") is None

        # Product key should remain
        assert cache_manager.get("product:1:info") == "data3"

    def test_get_keys_by_pattern(self, cache_manager):
        """Test getting keys by pattern"""
        cache_manager.set("ml:model:1", "data1")
        cache_manager.set("ml:model:2", "data2")
        cache_manager.set("api:route:1", "data3")

        keys = cache_manager.keys("ml:model:*")

        assert len(keys) == 2
        assert "ml:model:1" in keys
        assert "ml:model:2" in keys


class TestCacheEviction:
    """Test cache eviction policies"""

    def test_lru_eviction(self):
        """Test LRU cache eviction"""
        from cache.cache_manager import LRUCache

        cache = LRUCache(max_size=2)

        cache.set("key1", "value1")
        cache.set("key2", "value2")
        cache.set("key3", "value3")  # Should evict key1

        assert cache.get("key1") is None  # Evicted
        assert cache.get("key2") == "value2"
        assert cache.get("key3") == "value3"

    def test_ttl_eviction(self):
        """Test TTL-based eviction"""
        from cache.cache_manager import CacheManager

        cache = CacheManager()
        cache.set("key1", "value1", ttl=1)

        assert cache.get("key1") == "value1"

        time.sleep(1.5)

        assert cache.get("key1") is None


class TestCacheNamespacing:
    """Test cache namespacing"""

    def test_namespaced_cache(self):
        """Test cache with namespaces"""
        from cache.cache_manager import CacheManager

        cache = CacheManager(namespace="test_namespace")

        cache.set("key1", "value1")

        # Should be accessible in this namespace
        assert cache.get("key1") == "value1"


class TestConcurrentCacheAccess:
    """Test concurrent cache access"""

    def test_thread_safe_operations(self):
        """Test cache operations are thread-safe"""
        from cache.cache_manager import CacheManager
        import threading

        cache = CacheManager()
        results = []

        def write_to_cache(i):
            cache.set(f"key{i}", f"value{i}")
            results.append(cache.get(f"key{i}"))

        threads = [threading.Thread(target=write_to_cache, args=(i,)) for i in range(10)]

        for thread in threads:
            thread.start()

        for thread in threads:
            thread.join()

        # All operations should have succeeded
        assert len(results) == 10
        assert None not in results


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
