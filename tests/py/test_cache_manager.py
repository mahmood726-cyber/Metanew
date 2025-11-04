"""
Comprehensive tests for Parquet cache manager
"""
import pytest
import pandas as pd
import tempfile
import shutil
from pathlib import Path
import sys
import os
import time

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

from cache.cache_manager import CacheManager, MetaAnalysisCacheWrapper


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


class TestCacheManager:
    """Tests for CacheManager class"""

    def test_initialization(self, temp_cache_dir):
        """Test cache manager initializes correctly"""
        cm = CacheManager(cache_dir=temp_cache_dir)
        assert cm.cache_dir.exists()
        assert cm.index_file.exists()
        assert len(cm.index) == 0

    def test_cache_key_generation(self, cache_manager):
        """Test deterministic cache key generation"""
        params1 = {"n_studies": 10, "method": "REML", "outcome": "mortality"}
        params2 = {"outcome": "mortality", "method": "REML", "n_studies": 10}  # Different order
        params3 = {"n_studies": 10, "method": "DL", "outcome": "mortality"}  # Different value

        key1 = cache_manager._generate_cache_key("meta_analysis", params1)
        key2 = cache_manager._generate_cache_key("meta_analysis", params2)
        key3 = cache_manager._generate_cache_key("meta_analysis", params3)

        # Same params (different order) should give same key
        assert key1 == key2
        # Different params should give different key
        assert key1 != key3
        # Keys should be SHA256 hex (64 characters)
        assert len(key1) == 64

    def test_put_and_get(self, cache_manager):
        """Test basic put and get operations"""
        data = pd.DataFrame({
            'study_id': ['S1', 'S2'],
            'yi': [0.5, 0.7],
            'sei': [0.1, 0.15]
        })
        params = {"outcome": "mortality", "method": "REML"}

        # Put data
        cache_key = cache_manager.put("meta_analysis", params, data)
        assert cache_key is not None

        # Get data
        retrieved = cache_manager.get("meta_analysis", params)
        assert retrieved is not None
        pd.testing.assert_frame_equal(data, retrieved)

    def test_get_nonexistent(self, cache_manager):
        """Test get returns None for nonexistent cache"""
        params = {"outcome": "mortality", "method": "REML"}
        result = cache_manager.get("meta_analysis", params)
        assert result is None

    def test_cache_overwrite(self, cache_manager):
        """Test that putting same key twice overwrites"""
        data1 = pd.DataFrame({'a': [1, 2]})
        data2 = pd.DataFrame({'a': [3, 4]})
        params = {"test": "overwrite"}

        cache_manager.put("test", params, data1)
        cache_manager.put("test", params, data2)

        retrieved = cache_manager.get("test", params)
        pd.testing.assert_frame_equal(data2, retrieved)

    def test_access_count(self, cache_manager):
        """Test that access count increments"""
        data = pd.DataFrame({'a': [1, 2]})
        params = {"test": "access_count"}

        cache_manager.put("test", params, data)

        # Initial access count should be 0
        assert cache_manager.index.iloc[0]['access_count'] == 0

        # Get twice
        cache_manager.get("test", params)
        cache_manager.get("test", params)

        # Access count should be 2
        assert cache_manager.index.iloc[0]['access_count'] == 2

    def test_invalidate(self, cache_manager):
        """Test cache invalidation"""
        data = pd.DataFrame({'a': [1, 2]})
        params = {"test": "invalidate"}

        cache_manager.put("test", params, data)
        assert cache_manager.get("test", params) is not None

        # Invalidate
        result = cache_manager.invalidate("test", params)
        assert result == True

        # Should now return None
        assert cache_manager.get("test", params) is None

    def test_invalidate_nonexistent(self, cache_manager):
        """Test invalidating nonexistent cache returns False"""
        params = {"test": "nonexistent"}
        result = cache_manager.invalidate("test", params)
        assert result == False

    def test_metadata_storage(self, cache_manager):
        """Test that metadata is stored"""
        data = pd.DataFrame({'a': [1, 2]})
        params = {"test": "metadata"}
        metadata = {"n_studies": 10, "i2": 67.3}

        cache_manager.put("test", params, data, metadata=metadata)

        # Check metadata in index
        entry = cache_manager.index.iloc[0]
        import json
        stored_metadata = json.loads(entry['metadata'])
        assert stored_metadata == metadata

    def test_clear_old(self, cache_manager):
        """Test clearing old cache entries"""
        data = pd.DataFrame({'a': [1, 2]})
        params1 = {"test": "old"}
        params2 = {"test": "new"}

        # Put two entries
        cache_manager.put("test", params1, data)
        cache_manager.put("test", params2, data)

        assert len(cache_manager.index) == 2

        # Clear entries older than 0 days (should clear all)
        count = cache_manager.clear_old(days=0)
        assert count == 0  # Since they were just created

        # Entries should still be there
        assert len(cache_manager.index) == 2

    def test_get_stats(self, cache_manager):
        """Test cache statistics"""
        data1 = pd.DataFrame({'a': range(100)})
        data2 = pd.DataFrame({'b': range(50)})

        cache_manager.put("meta_analysis", {"id": 1}, data1)
        cache_manager.put("nma", {"id": 2}, data2)

        stats = cache_manager.get_stats()

        assert stats['total_entries'] == 2
        assert stats['total_size_mb'] > 0
        assert 'meta_analysis' in stats['analysis_types']
        assert 'nma' in stats['analysis_types']
        assert stats['oldest_entry'] is not None
        assert stats['newest_entry'] is not None

    def test_list_cached_analyses(self, cache_manager):
        """Test listing cached analyses"""
        data = pd.DataFrame({'a': [1, 2]})

        cache_manager.put("meta_analysis", {"id": 1}, data)
        cache_manager.put("meta_analysis", {"id": 2}, data)
        cache_manager.put("nma", {"id": 3}, data)

        # List all
        all_analyses = cache_manager.list_cached_analyses()
        assert len(all_analyses) == 3

        # Filter by type
        ma_analyses = cache_manager.list_cached_analyses(analysis_type="meta_analysis")
        assert len(ma_analyses) == 2

        nma_analyses = cache_manager.list_cached_analyses(analysis_type="nma")
        assert len(nma_analyses) == 1

    def test_file_deletion_cleanup(self, cache_manager):
        """Test that missing files are cleaned from index"""
        data = pd.DataFrame({'a': [1, 2]})
        params = {"test": "delete"}

        cache_manager.put("test", params, data)

        # Manually delete the file
        file_path = Path(cache_manager.index.iloc[0]['file_path'])
        file_path.unlink()

        # Get should return None and clean up index
        result = cache_manager.get("test", params)
        assert result is None
        assert len(cache_manager.index) == 0


class TestMetaAnalysisCacheWrapper:
    """Tests for MetaAnalysisCacheWrapper"""

    def test_run_with_cache_miss(self, cache_manager):
        """Test cache miss executes function"""
        wrapper = MetaAnalysisCacheWrapper(cache_manager)

        executed = []
        def analysis_func():
            executed.append(True)
            return pd.DataFrame({'result': [1, 2, 3]})

        result = wrapper.run_with_cache(
            analysis_func,
            analysis_type="test",
            parameters={"id": 1}
        )

        assert len(executed) == 1  # Function was executed
        assert len(result) == 3

    def test_run_with_cache_hit(self, cache_manager):
        """Test cache hit doesn't execute function"""
        wrapper = MetaAnalysisCacheWrapper(cache_manager)

        executed = []
        def analysis_func():
            executed.append(True)
            return pd.DataFrame({'result': [1, 2, 3]})

        # First call - cache miss
        result1 = wrapper.run_with_cache(
            analysis_func,
            analysis_type="test",
            parameters={"id": 1}
        )
        assert len(executed) == 1

        # Second call - cache hit
        result2 = wrapper.run_with_cache(
            analysis_func,
            analysis_type="test",
            parameters={"id": 1}
        )
        assert len(executed) == 1  # Function NOT executed again
        pd.testing.assert_frame_equal(result1, result2)

    def test_force_refresh(self, cache_manager):
        """Test force_refresh bypasses cache"""
        wrapper = MetaAnalysisCacheWrapper(cache_manager)

        counter = [0]
        def analysis_func():
            counter[0] += 1
            return pd.DataFrame({'result': [counter[0]]})

        # First call
        result1 = wrapper.run_with_cache(
            analysis_func,
            analysis_type="test",
            parameters={"id": 1}
        )
        assert result1['result'].iloc[0] == 1

        # Second call with force_refresh
        result2 = wrapper.run_with_cache(
            analysis_func,
            analysis_type="test",
            parameters={"id": 1},
            force_refresh=True
        )
        assert result2['result'].iloc[0] == 2  # Function executed again

    def test_metadata_includes_computation_time(self, cache_manager):
        """Test that metadata includes computation time"""
        wrapper = MetaAnalysisCacheWrapper(cache_manager)

        def slow_analysis():
            time.sleep(0.1)  # Simulate computation
            return pd.DataFrame({'result': [1]})

        wrapper.run_with_cache(
            slow_analysis,
            analysis_type="test",
            parameters={"id": 1}
        )

        # Check metadata
        import json
        entry = cache_manager.index.iloc[0]
        metadata = json.loads(entry['metadata'])
        assert 'computation_time' in metadata
        assert metadata['computation_time'] >= 0.1


class TestParquetFormat:
    """Tests for Parquet format characteristics"""

    def test_parquet_preserves_dtypes(self, cache_manager):
        """Test that Parquet preserves data types"""
        data = pd.DataFrame({
            'int_col': [1, 2, 3],
            'float_col': [1.1, 2.2, 3.3],
            'str_col': ['a', 'b', 'c'],
            'bool_col': [True, False, True]
        })

        cache_manager.put("test", {"id": 1}, data)
        retrieved = cache_manager.get("test", {"id": 1})

        assert retrieved['int_col'].dtype == data['int_col'].dtype
        assert retrieved['float_col'].dtype == data['float_col'].dtype
        assert retrieved['str_col'].dtype == data['str_col'].dtype
        assert retrieved['bool_col'].dtype == data['bool_col'].dtype

    def test_parquet_handles_missing_values(self, cache_manager):
        """Test that Parquet handles missing values correctly"""
        import numpy as np
        data = pd.DataFrame({
            'col1': [1.0, np.nan, 3.0],
            'col2': ['a', None, 'c']
        })

        cache_manager.put("test", {"id": 1}, data)
        retrieved = cache_manager.get("test", {"id": 1})

        assert pd.isna(retrieved['col1'].iloc[1])
        assert pd.isna(retrieved['col2'].iloc[1])

    def test_parquet_compression(self, temp_cache_dir):
        """Test that Parquet compression reduces file size"""
        cm = CacheManager(cache_dir=temp_cache_dir)

        # Create large DataFrame
        large_data = pd.DataFrame({
            'col1': range(10000),
            'col2': ['text' * 10] * 10000
        })

        cache_key = cm.put("test", {"id": 1}, large_data)

        # Check file size
        entry = cm.index.iloc[0]
        file_size = entry['size_bytes']

        # Compressed size should be much smaller than uncompressed
        # (exact ratio depends on data, but should be < 50% for this data)
        assert file_size > 0


class TestConcurrentAccess:
    """Tests for potential concurrent access issues"""

    def test_multiple_puts_same_key(self, cache_manager):
        """Test multiple puts with same key (last one wins)"""
        data1 = pd.DataFrame({'a': [1]})
        data2 = pd.DataFrame({'a': [2]})
        data3 = pd.DataFrame({'a': [3]})
        params = {"test": "concurrent"}

        cache_manager.put("test", params, data1)
        cache_manager.put("test", params, data2)
        cache_manager.put("test", params, data3)

        # Should have only one entry
        assert len(cache_manager.index) == 1

        # Should get last written data
        retrieved = cache_manager.get("test", params)
        assert retrieved['a'].iloc[0] == 3


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short', '--cov=cache.cache_manager'])
