"""
Comprehensive tests for cache_manager - 100% Coverage
Target: 100% coverage of backend/cache/cache_manager.py
"""
import pytest
import pandas as pd
import tempfile
import shutil
from pathlib import Path
import sys
import time
from datetime import datetime, timedelta

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "backend"))

from cache.cache_manager import CacheManager, MetaAnalysisCacheWrapper


class TestCacheManager:
    """Test CacheManager class"""

    @pytest.fixture
    def temp_cache_dir(self):
        """Create temporary cache directory"""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir, ignore_errors=True)

    @pytest.fixture
    def cache_manager(self, temp_cache_dir):
        """Create cache manager instance"""
        return CacheManager(cache_dir=temp_cache_dir)

    @pytest.fixture
    def sample_data(self):
        """Create sample DataFrame for caching"""
        return pd.DataFrame({
            'study_id': ['S1', 'S2', 'S3'],
            'effect_size': [0.5, 0.6, 0.4],
            'se': [0.1, 0.12, 0.09]
        })

    def test_init_creates_cache_dir(self, temp_cache_dir):
        """Test that initialization creates cache directory"""
        cache = CacheManager(cache_dir=temp_cache_dir)
        assert Path(temp_cache_dir).exists()
        assert cache.cache_dir == Path(temp_cache_dir)

    def test_init_creates_index(self, cache_manager):
        """Test that initialization creates cache index"""
        assert cache_manager.index is not None
        assert isinstance(cache_manager.index, pd.DataFrame)
        assert 'cache_key' in cache_manager.index.columns
        assert 'file_path' in cache_manager.index.columns

    def test_load_index_existing(self, temp_cache_dir):
        """Test loading existing index"""
        # Create cache and add entry
        cache1 = CacheManager(cache_dir=temp_cache_dir)
        data = pd.DataFrame({'col': [1, 2]})
        cache1.put('test', {'param': 1}, data)

        # Create new instance - should load existing index
        cache2 = CacheManager(cache_dir=temp_cache_dir)
        assert len(cache2.index) == 1

    def test_generate_cache_key(self, cache_manager):
        """Test cache key generation"""
        key1 = cache_manager._generate_cache_key('meta_analysis', {'method': 'REML', 'outcome': 'mortality'})
        key2 = cache_manager._generate_cache_key('meta_analysis', {'method': 'REML', 'outcome': 'mortality'})
        key3 = cache_manager._generate_cache_key('meta_analysis', {'method': 'DL', 'outcome': 'mortality'})

        # Same parameters should produce same key
        assert key1 == key2
        # Different parameters should produce different key
        assert key1 != key3
        # Keys should be SHA256 hashes (64 hex characters)
        assert len(key1) == 64
        assert all(c in '0123456789abcdef' for c in key1)

    def test_put_and_get(self, cache_manager, sample_data):
        """Test caching and retrieving data"""
        analysis_type = 'meta_analysis'
        parameters = {'method': 'REML', 'outcome': 'mortality'}

        # Cache data
        cache_key = cache_manager.put(analysis_type, parameters, sample_data)
        assert cache_key is not None
        assert len(cache_key) == 64

        # Retrieve data
        retrieved = cache_manager.get(analysis_type, parameters)
        assert retrieved is not None
        assert len(retrieved) == len(sample_data)
        assert list(retrieved.columns) == list(sample_data.columns)
        pd.testing.assert_frame_equal(retrieved, sample_data)

    def test_get_nonexistent(self, cache_manager):
        """Test getting non-existent cache entry"""
        result = cache_manager.get('nonexistent', {'param': 'value'})
        assert result is None

    def test_put_with_metadata(self, cache_manager, sample_data):
        """Test caching with metadata"""
        metadata = {'user': 'test_user', 'version': '1.0'}
        cache_key = cache_manager.put('test', {'param': 1}, sample_data, metadata)

        # Check metadata was stored
        entry = cache_manager.index[cache_manager.index['cache_key'] == cache_key]
        assert len(entry) == 1
        assert '"user": "test_user"' in entry.iloc[0]['metadata']

    def test_put_updates_existing(self, cache_manager, sample_data):
        """Test that put overwrites existing cache entry"""
        params = {'test': 'value'}

        # Cache data twice with same parameters
        key1 = cache_manager.put('test', params, sample_data)
        key2 = cache_manager.put('test', params, sample_data)

        # Should have same key
        assert key1 == key2
        # Should have only one entry in index
        assert len(cache_manager.index) == 1

    def test_get_updates_access_stats(self, cache_manager, sample_data):
        """Test that get updates access statistics"""
        params = {'test': 'value'}
        cache_manager.put('test', params, sample_data)

        # Get initial stats
        entry = cache_manager.index[cache_manager.index['analysis_type'] == 'test']
        initial_count = entry.iloc[0]['access_count']

        # Access cache
        cache_manager.get('test', params)

        # Check stats updated
        entry = cache_manager.index[cache_manager.index['analysis_type'] == 'test']
        new_count = entry.iloc[0]['access_count']
        assert new_count == initial_count + 1

    def test_get_missing_file(self, cache_manager, sample_data, temp_cache_dir):
        """Test get when file is deleted but index entry exists"""
        params = {'test': 'value'}
        cache_key = cache_manager.put('test', params, sample_data)

        # Delete the file manually
        file_path = Path(temp_cache_dir) / f"{cache_key}.parquet"
        file_path.unlink()

        # Get should return None and clean up index
        result = cache_manager.get('test', params)
        assert result is None
        assert len(cache_manager.index) == 0

    def test_invalidate(self, cache_manager, sample_data):
        """Test cache invalidation"""
        params = {'test': 'value'}
        cache_key = cache_manager.put('test', params, sample_data)

        # Verify cached
        assert cache_manager.get('test', params) is not None

        # Invalidate
        result = cache_manager.invalidate('test', params)
        assert result is True

        # Verify removed
        assert cache_manager.get('test', params) is None
        assert len(cache_manager.index) == 0

    def test_invalidate_nonexistent(self, cache_manager):
        """Test invalidating non-existent cache entry"""
        result = cache_manager.invalidate('nonexistent', {'param': 'value'})
        assert result is False

    def test_clear_old(self, cache_manager, sample_data):
        """Test clearing old cache entries"""
        # Add entry
        cache_manager.put('test', {'param': 1}, sample_data)

        # Manually set last_accessed to old date
        old_date = datetime.now() - timedelta(days=60)
        cache_manager.index.loc[0, 'last_accessed'] = old_date
        cache_manager._save_index()

        # Clear entries older than 30 days
        count = cache_manager.clear_old(days=30)
        assert count == 1
        assert len(cache_manager.index) == 0

    def test_clear_old_keeps_recent(self, cache_manager, sample_data):
        """Test that clear_old keeps recent entries"""
        # Add entry
        cache_manager.put('test', {'param': 1}, sample_data)

        # Clear entries older than 30 days
        count = cache_manager.clear_old(days=30)
        assert count == 0
        assert len(cache_manager.index) == 1

    def test_get_stats_empty(self, cache_manager):
        """Test statistics on empty cache"""
        stats = cache_manager.get_stats()
        assert stats['total_entries'] == 0
        assert stats['total_size_mb'] == 0
        assert stats['analysis_types'] == {}

    def test_get_stats_with_data(self, cache_manager, sample_data):
        """Test statistics with cached data"""
        cache_manager.put('meta_analysis', {'method': 'REML'}, sample_data)
        cache_manager.put('nma', {'model': 'random'}, sample_data)

        stats = cache_manager.get_stats()
        assert stats['total_entries'] == 2
        assert stats['total_size_mb'] > 0
        assert 'meta_analysis' in stats['analysis_types']
        assert 'nma' in stats['analysis_types']
        assert stats['oldest_entry'] is not None
        assert stats['newest_entry'] is not None

    def test_get_stats_most_accessed(self, cache_manager, sample_data):
        """Test most accessed statistics"""
        params = {'test': 'value'}
        cache_manager.put('test', params, sample_data)

        # Access multiple times
        for _ in range(5):
            cache_manager.get('test', params)

        stats = cache_manager.get_stats()
        assert len(stats['most_accessed']) > 0
        assert stats['most_accessed'][0]['access_count'] == 5

    def test_list_cached_analyses_all(self, cache_manager, sample_data):
        """Test listing all cached analyses"""
        cache_manager.put('meta_analysis', {'method': 'REML'}, sample_data)
        cache_manager.put('nma', {'model': 'random'}, sample_data)

        analyses = cache_manager.list_cached_analyses()
        assert len(analyses) == 2

    def test_list_cached_analyses_filtered(self, cache_manager, sample_data):
        """Test listing filtered cached analyses"""
        cache_manager.put('meta_analysis', {'method': 'REML'}, sample_data)
        cache_manager.put('nma', {'model': 'random'}, sample_data)

        analyses = cache_manager.list_cached_analyses(analysis_type='meta_analysis')
        assert len(analyses) == 1
        assert analyses[0]['analysis_type'] == 'meta_analysis'

    def test_save_and_load_index_dtypes(self, cache_manager, sample_data):
        """Test that dtypes are preserved when saving/loading index"""
        cache_manager.put('test', {'param': 1}, sample_data)

        # Save and reload
        cache_manager._save_index()
        cache_manager._load_index()

        # Check dtypes
        assert cache_manager.index['access_count'].dtype == 'int64'
        assert cache_manager.index['size_bytes'].dtype == 'int64'

    def test_parquet_compression(self, cache_manager, temp_cache_dir):
        """Test that Parquet files use compression"""
        large_data = pd.DataFrame({
            'col': ['A' * 1000] * 100
        })

        cache_key = cache_manager.put('test', {'param': 1}, large_data)
        file_path = Path(temp_cache_dir) / f"{cache_key}.parquet"

        # Compressed size should be much smaller than uncompressed
        compressed_size = file_path.stat().st_size
        # Rough estimate: 100 rows * 1000 chars * 1 byte = 100KB uncompressed
        # With compression should be much less
        assert compressed_size < 50000  # Less than 50KB

    def test_cache_key_determinism(self, cache_manager):
        """Test that cache key generation is deterministic"""
        params = {'b': 2, 'a': 1, 'c': 3}  # Unsorted dict
        key1 = cache_manager._generate_cache_key('test', params)

        # Try with different dict order
        params2 = {'c': 3, 'a': 1, 'b': 2}
        key2 = cache_manager._generate_cache_key('test', params2)

        # Should be identical (json.dumps with sort_keys=True)
        assert key1 == key2


class TestMetaAnalysisCacheWrapper:
    """Test MetaAnalysisCacheWrapper class"""

    @pytest.fixture
    def temp_cache_dir(self):
        """Create temporary cache directory"""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir, ignore_errors=True)

    @pytest.fixture
    def cache_wrapper(self, temp_cache_dir):
        """Create cache wrapper instance"""
        cache_manager = CacheManager(cache_dir=temp_cache_dir)
        return MetaAnalysisCacheWrapper(cache_manager)

    def test_run_with_cache_first_time(self, cache_wrapper):
        """Test running analysis for first time (cache miss)"""
        call_count = 0

        def analysis_func():
            nonlocal call_count
            call_count += 1
            return pd.DataFrame({'result': [1, 2, 3]})

        result = cache_wrapper.run_with_cache(
            analysis_func,
            'test_analysis',
            {'param': 'value'},
            force_refresh=False
        )

        assert call_count == 1
        assert len(result) == 3

    def test_run_with_cache_hit(self, cache_wrapper):
        """Test running analysis with cache hit"""
        call_count = 0

        def analysis_func():
            nonlocal call_count
            call_count += 1
            return pd.DataFrame({'result': [1, 2, 3]})

        params = {'param': 'value'}

        # First run - cache miss
        result1 = cache_wrapper.run_with_cache(analysis_func, 'test', params)
        assert call_count == 1

        # Second run - cache hit
        result2 = cache_wrapper.run_with_cache(analysis_func, 'test', params)
        assert call_count == 1  # Should not call function again

        pd.testing.assert_frame_equal(result1, result2)

    def test_run_with_cache_force_refresh(self, cache_wrapper):
        """Test force refresh bypasses cache"""
        call_count = 0

        def analysis_func():
            nonlocal call_count
            call_count += 1
            return pd.DataFrame({'result': [call_count]})

        params = {'param': 'value'}

        # First run
        result1 = cache_wrapper.run_with_cache(analysis_func, 'test', params)
        assert call_count == 1

        # Force refresh
        result2 = cache_wrapper.run_with_cache(
            analysis_func, 'test', params, force_refresh=True
        )
        assert call_count == 2  # Should call function again

        # Results should be different
        assert result1.iloc[0, 0] != result2.iloc[0, 0]

    def test_run_with_cache_stores_timing(self, cache_wrapper):
        """Test that computation time is stored in metadata"""
        def slow_analysis():
            time.sleep(0.1)
            return pd.DataFrame({'result': [1]})

        cache_wrapper.run_with_cache(slow_analysis, 'test', {'param': 1})

        # Check metadata
        analyses = cache_wrapper.cache.list_cached_analyses()
        assert len(analyses) == 1
        import json
        metadata = json.loads(analyses[0]['metadata'])
        assert 'computation_time' in metadata
        assert metadata['computation_time'] > 0.1

    def test_run_with_cache_different_params(self, cache_wrapper):
        """Test that different parameters create different cache entries"""
        call_count = 0

        def analysis_func():
            nonlocal call_count
            call_count += 1
            return pd.DataFrame({'result': [call_count]})

        # Run with different parameters
        result1 = cache_wrapper.run_with_cache(analysis_func, 'test', {'param': 1})
        result2 = cache_wrapper.run_with_cache(analysis_func, 'test', {'param': 2})

        # Should call function twice
        assert call_count == 2

        # Should have 2 cache entries
        assert len(cache_wrapper.cache.index) == 2


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend/cache/cache_manager', '--cov-report=term-missing'])
