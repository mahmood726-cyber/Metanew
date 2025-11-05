"""
Comprehensive Tests for Cache Manager
Tests for Parquet-based caching functionality
"""
import pytest
import pandas as pd
import numpy as np
import tempfile
import shutil
from pathlib import Path


class TestCacheManager:
    """Test cache manager functionality"""

    @pytest.fixture
    def temp_cache_dir(self):
        """Create temporary cache directory"""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)

    @pytest.fixture
    def cache_manager(self, temp_cache_dir):
        """Create cache manager instance"""
        from cache.cache_manager import CacheManager
        return CacheManager(cache_dir=temp_cache_dir)

    @pytest.fixture
    def sample_dataframe(self):
        """Create sample DataFrame for caching"""
        return pd.DataFrame({
            'study_id': [1, 2, 3, 4, 5],
            'effect_size': [0.5, 0.6, 0.4, 0.55, 0.45],
            'std_error': [0.1, 0.12, 0.09, 0.11, 0.10],
            'sample_size': [100, 150, 200, 120, 180]
        })

    def test_cache_manager_initialization(self, cache_manager):
        """Test cache manager can be initialized"""
        assert cache_manager is not None
        assert cache_manager.cache_dir.exists()

    def test_put_and_get_dataframe(self, cache_manager, sample_dataframe):
        """Test caching and retrieving DataFrames"""
        analysis_type = "meta_analysis"
        parameters = {"model": "random_effects", "method": "DL"}

        # Cache the data
        cache_key = cache_manager.put(analysis_type, parameters, sample_dataframe)

        # Retrieve it
        retrieved = cache_manager.get(analysis_type, parameters)

        assert retrieved is not None
        assert isinstance(retrieved, pd.DataFrame)
        assert len(retrieved) == len(sample_dataframe)
        pd.testing.assert_frame_equal(retrieved, sample_dataframe)

    def test_get_nonexistent_returns_none(self, cache_manager):
        """Test getting nonexistent cache returns None"""
        result = cache_manager.get("nonexistent_type", {"param": "value"})
        assert result is None

    def test_cache_key_generation_deterministic(self, cache_manager, sample_dataframe):
        """Test cache key generation is deterministic"""
        analysis_type = "meta_analysis"
        parameters = {"model": "random_effects", "method": "DL"}

        key1 = cache_manager.put(analysis_type, parameters, sample_dataframe)

        # Same parameters should generate same key
        key2 = cache_manager._generate_cache_key(analysis_type, parameters)

        assert key1 == key2

    def test_different_parameters_different_keys(self, cache_manager, sample_dataframe):
        """Test different parameters generate different cache keys"""
        analysis_type = "meta_analysis"

        key1 = cache_manager.put(analysis_type, {"model": "fixed"}, sample_dataframe)
        key2 = cache_manager.put(analysis_type, {"model": "random"}, sample_dataframe)

        assert key1 != key2

    def test_invalidate_cache(self, cache_manager, sample_dataframe):
        """Test invalidating cached entries"""
        analysis_type = "meta_analysis"
        parameters = {"model": "random_effects"}

        # Cache data
        cache_manager.put(analysis_type, parameters, sample_dataframe)
        assert cache_manager.get(analysis_type, parameters) is not None

        # Invalidate
        result = cache_manager.invalidate(analysis_type, parameters)
        assert result is True

        # Should be None after invalidation
        assert cache_manager.get(analysis_type, parameters) is None

    def test_invalidate_nonexistent_returns_false(self, cache_manager):
        """Test invalidating nonexistent cache returns False"""
        result = cache_manager.invalidate("nonexistent", {"param": "value"})
        assert result is False

    def test_cache_with_metadata(self, cache_manager, sample_dataframe):
        """Test caching with metadata"""
        analysis_type = "meta_analysis"
        parameters = {"model": "random_effects"}
        metadata = {"computation_time": 1.5, "n_studies": 5}

        cache_manager.put(analysis_type, parameters, sample_dataframe, metadata)

        # Verify it was cached
        retrieved = cache_manager.get(analysis_type, parameters)
        assert retrieved is not None

    def test_get_stats(self, cache_manager, sample_dataframe):
        """Test retrieving cache statistics"""
        # Add some cached data
        cache_manager.put("meta_analysis", {"model": "fixed"}, sample_dataframe)
        cache_manager.put("nma", {"model": "random"}, sample_dataframe)

        stats = cache_manager.get_stats()

        assert stats is not None
        assert isinstance(stats, dict)
        assert "total_entries" in stats
        assert "total_size_mb" in stats
        assert stats["total_entries"] >= 2

    def test_cache_access_tracking(self, cache_manager, sample_dataframe):
        """Test that cache access is tracked"""
        analysis_type = "meta_analysis"
        parameters = {"model": "random_effects"}

        # Cache data
        cache_manager.put(analysis_type, parameters, sample_dataframe)

        # Access multiple times
        cache_manager.get(analysis_type, parameters)
        cache_manager.get(analysis_type, parameters)
        cache_manager.get(analysis_type, parameters)

        # Check stats
        stats = cache_manager.get_stats()
        assert stats["total_entries"] >= 1

    def test_list_cached_analyses(self, cache_manager, sample_dataframe):
        """Test listing cached analyses"""
        cache_manager.put("meta_analysis", {"model": "fixed"}, sample_dataframe)
        cache_manager.put("meta_analysis", {"model": "random"}, sample_dataframe)
        cache_manager.put("nma", {"model": "random"}, sample_dataframe)

        # List all
        all_analyses = cache_manager.list_cached_analyses()
        assert len(all_analyses) >= 3

        # List filtered by type
        meta_analyses = cache_manager.list_cached_analyses("meta_analysis")
        assert len(meta_analyses) >= 2

    def test_clear_old_entries(self, cache_manager, sample_dataframe):
        """Test clearing old cache entries"""
        # Add entry
        cache_manager.put("meta_analysis", {"model": "fixed"}, sample_dataframe)

        # Clear entries older than 365 days (should keep current entry)
        cleared = cache_manager.clear_old(days=365)

        # Nothing should be cleared since entry is fresh
        assert cleared == 0

        # Entry should still exist
        result = cache_manager.get("meta_analysis", {"model": "fixed"})
        assert result is not None


class TestCacheWrapperIntegration:
    """Test cache wrapper for meta-analysis"""

    @pytest.fixture
    def temp_cache_dir(self):
        """Create temporary cache directory"""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)

    @pytest.fixture
    def cache_wrapper(self, temp_cache_dir):
        """Create cache wrapper instance"""
        from cache.cache_manager import CacheManager, MetaAnalysisCacheWrapper
        cache_manager = CacheManager(cache_dir=temp_cache_dir)
        return MetaAnalysisCacheWrapper(cache_manager)

    def test_wrapper_initialization(self, cache_wrapper):
        """Test wrapper can be initialized"""
        assert cache_wrapper is not None
        assert cache_wrapper.cache is not None

    def test_run_with_cache_first_run(self, cache_wrapper):
        """Test first run computes result"""
        call_count = 0

        def analysis_func():
            nonlocal call_count
            call_count += 1
            return pd.DataFrame({'result': [1, 2, 3]})

        result = cache_wrapper.run_with_cache(
            analysis_func,
            "test_analysis",
            {"param": "value"}
        )

        assert call_count == 1
        assert len(result) == 3

    def test_run_with_cache_second_run_uses_cache(self, cache_wrapper):
        """Test second run uses cached result"""
        call_count = 0

        def analysis_func():
            nonlocal call_count
            call_count += 1
            return pd.DataFrame({'result': [1, 2, 3]})

        # First run
        result1 = cache_wrapper.run_with_cache(
            analysis_func,
            "test_analysis",
            {"param": "value"}
        )

        # Second run - should use cache
        result2 = cache_wrapper.run_with_cache(
            analysis_func,
            "test_analysis",
            {"param": "value"}
        )

        # Function should only be called once
        assert call_count == 1
        pd.testing.assert_frame_equal(result1, result2)

    def test_force_refresh(self, cache_wrapper):
        """Test force refresh bypasses cache"""
        call_count = 0

        def analysis_func():
            nonlocal call_count
            call_count += 1
            return pd.DataFrame({'result': [call_count]})

        # First run
        result1 = cache_wrapper.run_with_cache(
            analysis_func,
            "test_analysis",
            {"param": "value"}
        )

        # Second run with force_refresh
        result2 = cache_wrapper.run_with_cache(
            analysis_func,
            "test_analysis",
            {"param": "value"},
            force_refresh=True
        )

        # Function should be called twice
        assert call_count == 2
        assert result1.iloc[0]['result'] == 1
        assert result2.iloc[0]['result'] == 2


class TestCacheCompression:
    """Test cache compression and storage"""

    @pytest.fixture
    def temp_cache_dir(self):
        """Create temporary cache directory"""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)

    @pytest.fixture
    def cache_manager(self, temp_cache_dir):
        """Create cache manager instance"""
        from cache.cache_manager import CacheManager
        return CacheManager(cache_dir=temp_cache_dir)

    def test_large_dataframe_caching(self, cache_manager):
        """Test caching large DataFrames"""
        # Create large DataFrame
        large_df = pd.DataFrame({
            'study_id': range(1000),
            'effect_size': np.random.randn(1000),
            'std_error': np.random.uniform(0.1, 0.5, 1000),
            'sample_size': np.random.randint(50, 500, 1000)
        })

        analysis_type = "large_meta_analysis"
        parameters = {"n_studies": 1000}

        # Cache it
        cache_manager.put(analysis_type, parameters, large_df)

        # Retrieve it
        retrieved = cache_manager.get(analysis_type, parameters)

        assert retrieved is not None
        assert len(retrieved) == 1000
        pd.testing.assert_frame_equal(retrieved, large_df)

    def test_compression_reduces_size(self, cache_manager, temp_cache_dir):
        """Test that Parquet compression reduces file size"""
        # Create DataFrame with repetitive data (compresses well)
        df = pd.DataFrame({
            'category': ['A'] * 500 + ['B'] * 500,
            'value': [1.0] * 500 + [2.0] * 500
        })

        cache_manager.put("test_analysis", {"param": "value"}, df)

        stats = cache_manager.get_stats()

        # Compressed size should be relatively small
        assert stats["total_size_mb"] < 1.0  # Should be much less than 1 MB


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
