"""
Tests for Parquet Cache Manager (V2 Feature)
"""

import pytest
import pandas as pd
import tempfile
import shutil
from pathlib import Path
from cache_manager import CacheManager


@pytest.fixture
def temp_cache_dir():
    """Create temporary cache directory"""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir)


@pytest.fixture
def cache_manager(temp_cache_dir):
    """Create cache manager instance"""
    return CacheManager(cache_dir=temp_cache_dir)


@pytest.fixture
def sample_dataframe():
    """Create sample DataFrame for testing"""
    return pd.DataFrame({
        'study_id': ['S1', 'S2', 'S3', 'S4', 'S5'],
        'effect_size': [0.5, 0.6, 0.7, 0.8, 0.9],
        'se': [0.1, 0.12, 0.11, 0.13, 0.10],
        'n': [100, 120, 110, 130, 115]
    })


class TestCacheManager:
    """Test CacheManager functionality"""

    def test_initialization(self, cache_manager, temp_cache_dir):
        """Test cache manager initializes correctly"""
        assert cache_manager.cache_dir == Path(temp_cache_dir)
        assert cache_manager.cache_dir.exists()
        assert cache_manager.index_file.exists()

    def test_generate_cache_key(self, cache_manager):
        """Test deterministic cache key generation"""
        params1 = {"outcome": "mortality", "estimator": "REML", "n_studies": 10}
        params2 = {"n_studies": 10, "outcome": "mortality", "estimator": "REML"}
        params3 = {"outcome": "mortality", "estimator": "DL", "n_studies": 10}

        key1 = cache_manager._generate_cache_key("meta_analysis", params1)
        key2 = cache_manager._generate_cache_key("meta_analysis", params2)
        key3 = cache_manager._generate_cache_key("meta_analysis", params3)

        # Same parameters (different order) should give same key
        assert key1 == key2
        # Different parameters should give different key
        assert key1 != key3
        # Keys should be SHA256 hashes (64 characters)
        assert len(key1) == 64

    def test_put_and_get(self, cache_manager, sample_dataframe):
        """Test storing and retrieving from cache"""
        analysis_type = "meta_analysis"
        parameters = {"outcome": "mortality", "estimator": "REML"}

        # Put data in cache
        cache_key = cache_manager.put(analysis_type, parameters, sample_dataframe)
        assert cache_key is not None
        assert len(cache_key) == 64

        # Get data from cache
        cached_df = cache_manager.get(analysis_type, parameters)
        assert cached_df is not None
        pd.testing.assert_frame_equal(cached_df, sample_dataframe)

    def test_cache_miss(self, cache_manager):
        """Test cache miss returns None"""
        result = cache_manager.get("meta_analysis", {"outcome": "nonexistent"})
        assert result is None

    def test_cache_with_metadata(self, cache_manager, sample_dataframe):
        """Test caching with metadata"""
        metadata = {"computation_time": 12.5, "timestamp": "2025-01-03"}
        cache_key = cache_manager.put(
            "meta_analysis",
            {"outcome": "test"},
            sample_dataframe,
            metadata=metadata
        )

        # Check metadata in index
        matches = cache_manager.index[cache_manager.index['cache_key'] == cache_key]
        assert len(matches) == 1
        assert matches.iloc[0]['analysis_type'] == "meta_analysis"

    def test_access_statistics(self, cache_manager, sample_dataframe):
        """Test access count and last_accessed tracking"""
        params = {"outcome": "test"}
        cache_manager.put("meta_analysis", params, sample_dataframe)

        # First access
        cache_manager.get("meta_analysis", params)
        cache_key = cache_manager._generate_cache_key("meta_analysis", params)
        matches = cache_manager.index[cache_manager.index['cache_key'] == cache_key]
        assert matches.iloc[0]['access_count'] == 1

        # Second access
        cache_manager.get("meta_analysis", params)
        matches = cache_manager.index[cache_manager.index['cache_key'] == cache_key]
        assert matches.iloc[0]['access_count'] == 2

    def test_invalidate(self, cache_manager, sample_dataframe):
        """Test cache invalidation"""
        params = {"outcome": "test"}
        cache_manager.put("meta_analysis", params, sample_dataframe)

        # Verify cached
        assert cache_manager.get("meta_analysis", params) is not None

        # Invalidate
        result = cache_manager.invalidate("meta_analysis", params)
        assert result is True

        # Verify removed
        assert cache_manager.get("meta_analysis", params) is None

    def test_invalidate_nonexistent(self, cache_manager):
        """Test invalidating non-existent cache entry"""
        result = cache_manager.invalidate("meta_analysis", {"outcome": "nonexistent"})
        assert result is False

    def test_get_stats(self, cache_manager, sample_dataframe):
        """Test cache statistics"""
        # Empty cache
        stats = cache_manager.get_stats()
        assert stats['total_entries'] == 0
        assert stats['total_size_mb'] == 0

        # Add some entries
        cache_manager.put("meta_analysis", {"outcome": "mortality"}, sample_dataframe)
        cache_manager.put("nma", {"outcome": "efficacy"}, sample_dataframe)

        stats = cache_manager.get_stats()
        assert stats['total_entries'] == 2
        assert stats['total_size_mb'] > 0
        assert 'meta_analysis' in stats['analysis_types']
        assert 'nma' in stats['analysis_types']

    def test_clear_old(self, cache_manager, sample_dataframe):
        """Test clearing old cache entries"""
        # Add entries
        cache_manager.put("meta_analysis", {"outcome": "test1"}, sample_dataframe)
        cache_manager.put("meta_analysis", {"outcome": "test2"}, sample_dataframe)

        # Manually set old last_accessed
        cache_manager.index.loc[0, 'last_accessed'] = pd.Timestamp('2024-01-01')
        cache_manager._save_index()

        # Clear entries older than 30 days
        count = cache_manager.clear_old(days=30)
        assert count == 1

        stats = cache_manager.get_stats()
        assert stats['total_entries'] == 1

    def test_list_cached_analyses(self, cache_manager, sample_dataframe):
        """Test listing cached analyses"""
        # Empty list
        analyses = cache_manager.list_cached_analyses()
        assert len(analyses) == 0

        # Add entries
        cache_manager.put("meta_analysis", {"outcome": "mortality"}, sample_dataframe)
        cache_manager.put("nma", {"outcome": "efficacy"}, sample_dataframe)

        # List all
        analyses = cache_manager.list_cached_analyses()
        assert len(analyses) == 2

        # List by type
        ma_analyses = cache_manager.list_cached_analyses(analysis_type="meta_analysis")
        assert len(ma_analyses) == 1
        assert ma_analyses[0]['analysis_type'] == "meta_analysis"

    def test_multiple_analysis_types(self, cache_manager, sample_dataframe):
        """Test caching different analysis types"""
        # Add different analysis types
        cache_manager.put("meta_analysis", {"outcome": "mortality"}, sample_dataframe)
        cache_manager.put("nma", {"outcome": "efficacy"}, sample_dataframe)
        cache_manager.put("he_model", {"perspective": "NHS"}, sample_dataframe)

        # Retrieve each
        ma_result = cache_manager.get("meta_analysis", {"outcome": "mortality"})
        nma_result = cache_manager.get("nma", {"outcome": "efficacy"})
        he_result = cache_manager.get("he_model", {"perspective": "NHS"})

        assert ma_result is not None
        assert nma_result is not None
        assert he_result is not None

    def test_large_dataframe(self, cache_manager):
        """Test caching large DataFrame"""
        large_df = pd.DataFrame({
            'study_id': [f'S{i}' for i in range(1000)],
            'effect_size': [0.5 + i * 0.001 for i in range(1000)],
            'se': [0.1] * 1000,
            'n': [100] * 1000
        })

        cache_manager.put("meta_analysis", {"outcome": "large_test"}, large_df)
        cached_df = cache_manager.get("meta_analysis", {"outcome": "large_test"})

        assert cached_df is not None
        assert len(cached_df) == 1000
        pd.testing.assert_frame_equal(cached_df, large_df)

    def test_cache_overwrite(self, cache_manager, sample_dataframe):
        """Test overwriting existing cache entry"""
        params = {"outcome": "test"}

        # First write
        cache_manager.put("meta_analysis", params, sample_dataframe)
        stats1 = cache_manager.get_stats()

        # Modify DataFrame
        modified_df = sample_dataframe.copy()
        modified_df['effect_size'] = modified_df['effect_size'] * 2

        # Second write (should overwrite)
        cache_manager.put("meta_analysis", params, modified_df)
        stats2 = cache_manager.get_stats()

        # Should still have only 1 entry
        assert stats2['total_entries'] == 1

        # Should get modified version
        cached_df = cache_manager.get("meta_analysis", params)
        pd.testing.assert_frame_equal(cached_df, modified_df)


class TestPerformance:
    """Performance tests for caching"""

    def test_write_read_cycle(self, cache_manager, sample_dataframe):
        """Test complete write-read cycle is fast"""
        import time

        # Write
        start = time.time()
        cache_manager.put("meta_analysis", {"outcome": "perf_test"}, sample_dataframe)
        write_time = time.time() - start

        # Read
        start = time.time()
        result = cache_manager.get("meta_analysis", {"outcome": "perf_test"})
        read_time = time.time() - start

        assert result is not None
        # Write should be reasonably fast (< 1 second)
        assert write_time < 1.0
        # Read should be very fast (< 0.5 seconds)
        assert read_time < 0.5


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
