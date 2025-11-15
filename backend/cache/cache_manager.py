"""
Parquet Caching Layer for EvidenceOS PRIME
Fast serialization/deserialization of analysis results
"""

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from pathlib import Path
from typing import Optional, Dict, Any, List
import hashlib
import json
import time
from datetime import datetime, timedelta


class CacheManager:
    """
    Manages Parquet-based caching for meta-analysis results

    Benefits:
    - 10-100x faster than CSV for large datasets
    - Compressed storage (60-90% size reduction)
    - Preserves data types
    - Fast filtering and querying
    """

    def __init__(self, cache_dir: str = "cache/parquet"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.index_file = self.cache_dir / "cache_index.parquet"
        self._index_dirty = False  # Track if index needs saving - MUST be before _load_index()
        self._access_count = 0  # Count accesses between saves
        self._load_index()

    def _load_index(self):
        """Load cache index or create new one"""
        if self.index_file.exists():
            self.index = pd.read_parquet(self.index_file)
            # Ensure proper dtypes after loading
            if 'access_count' in self.index.columns:
                self.index['access_count'] = self.index['access_count'].astype('int64')
            if 'size_bytes' in self.index.columns:
                self.index['size_bytes'] = self.index['size_bytes'].astype('int64')
        else:
            self.index = pd.DataFrame({
                'cache_key': pd.Series(dtype='str'),
                'file_path': pd.Series(dtype='str'),
                'created_at': pd.Series(dtype='datetime64[ns]'),
                'last_accessed': pd.Series(dtype='datetime64[ns]'),
                'access_count': pd.Series(dtype='int64'),
                'size_bytes': pd.Series(dtype='int64'),
                'analysis_type': pd.Series(dtype='str'),
                'metadata': pd.Series(dtype='str')
            })
            self._save_index()

    def _save_index(self, force: bool = False):
        """
        Save cache index to disk with write-back caching

        Args:
            force: Force immediate write even if not dirty
        """
        if not force and not self._index_dirty:
            return

        # Ensure dtypes before saving
        if len(self.index) > 0:
            self.index['access_count'] = self.index['access_count'].astype('int64')
            self.index['size_bytes'] = self.index['size_bytes'].astype('int64')
        self.index.to_parquet(self.index_file, compression='snappy')
        self._index_dirty = False

    def _generate_cache_key(self, analysis_type: str, parameters: Dict[str, Any]) -> str:
        """
        Generate deterministic cache key from analysis parameters

        Args:
            analysis_type: e.g., "meta_analysis", "nma", "he_model"
            parameters: Analysis configuration

        Returns:
            SHA256 hash as cache key
        """
        # Create deterministic JSON string
        param_str = json.dumps(parameters, sort_keys=True)
        key_input = f"{analysis_type}:{param_str}"
        return hashlib.sha256(key_input.encode()).hexdigest()

    def get(self, analysis_type: str, parameters: Dict[str, Any]) -> Optional[pd.DataFrame]:
        """
        Retrieve cached results

        Args:
            analysis_type: Type of analysis
            parameters: Analysis parameters

        Returns:
            Cached DataFrame or None if not found
        """
        cache_key = self._generate_cache_key(analysis_type, parameters)

        # Check if key exists in index
        matches = self.index[self.index['cache_key'] == cache_key]

        if len(matches) == 0:
            return None

        # Get file path
        file_path = Path(matches.iloc[0]['file_path'])

        if not file_path.exists():
            # File was deleted, remove from index
            self.index = self.index[self.index['cache_key'] != cache_key]
            self._save_index()
            return None

        # Update access statistics - OPTIMIZED: Combined update + write-back caching
        mask = self.index['cache_key'] == cache_key
        self.index.loc[mask, ['last_accessed', 'access_count']] = [
            datetime.now(),
            self.index.loc[mask, 'access_count'].values[0] + 1
        ]
        self._index_dirty = True
        self._access_count += 1

        # Only save index every 10 accesses (configurable)
        if self._access_count >= 10:
            self._save_index()
            self._access_count = 0

        # Load and return data
        try:
            return pd.read_parquet(file_path)
        except Exception as e:
            print(f"Error loading cache: {e}")
            return None

    def put(self, analysis_type: str, parameters: Dict[str, Any],
            data: pd.DataFrame, metadata: Optional[Dict] = None) -> str:
        """
        Cache analysis results

        Args:
            analysis_type: Type of analysis
            parameters: Analysis parameters
            data: Results DataFrame
            metadata: Optional metadata

        Returns:
            Cache key
        """
        cache_key = self._generate_cache_key(analysis_type, parameters)
        file_path = self.cache_dir / f"{cache_key}.parquet"

        # Write data to Parquet
        data.to_parquet(file_path, compression='snappy', index=False)

        # Get file size
        size_bytes = file_path.stat().st_size

        # Update index
        new_entry = pd.DataFrame([{
            'cache_key': cache_key,
            'file_path': str(file_path),
            'created_at': datetime.now(),
            'last_accessed': datetime.now(),
            'access_count': 0,
            'size_bytes': size_bytes,
            'analysis_type': analysis_type,
            'metadata': json.dumps(metadata or {})
        }])

        # Remove old entry if exists
        self.index = self.index[self.index['cache_key'] != cache_key]
        self.index = pd.concat([self.index, new_entry], ignore_index=True)
        self._index_dirty = True
        self._save_index(force=True)  # Always save immediately after put

        return cache_key

    def invalidate(self, analysis_type: str, parameters: Dict[str, Any]) -> bool:
        """
        Invalidate (delete) cached results

        Returns:
            True if cache was found and deleted
        """
        cache_key = self._generate_cache_key(analysis_type, parameters)

        # Find entry
        matches = self.index[self.index['cache_key'] == cache_key]

        if len(matches) == 0:
            return False

        # Delete file
        file_path = Path(matches.iloc[0]['file_path'])
        if file_path.exists():
            file_path.unlink()

        # Remove from index
        self.index = self.index[self.index['cache_key'] != cache_key]
        self._index_dirty = True
        self._save_index(force=True)  # Save immediately after invalidation

        return True

    def clear_old(self, days: int = 30) -> int:
        """
        Clear cache entries older than specified days

        Args:
            days: Age threshold in days

        Returns:
            Number of entries cleared
        """
        cutoff = datetime.now() - timedelta(days=days)

        old_entries = self.index[pd.to_datetime(self.index['last_accessed']) < cutoff]

        count = 0
        for _, row in old_entries.iterrows():
            file_path = Path(row['file_path'])
            if file_path.exists():
                file_path.unlink()
                count += 1

        # Update index
        self.index = self.index[pd.to_datetime(self.index['last_accessed']) >= cutoff]
        self._index_dirty = True
        self._save_index(force=True)  # Save immediately after cleanup

        return count

    def flush(self):
        """Manually flush index to disk"""
        self._save_index(force=True)

    def __del__(self):
        """Ensure index is saved on destruction"""
        try:
            self._save_index(force=True)
        except:
            pass  # Ignore errors during cleanup

    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        total_entries = len(self.index)
        total_size = self.index['size_bytes'].sum() if total_entries > 0 else 0

        stats = {
            'total_entries': total_entries,
            'total_size_mb': total_size / (1024 * 1024),
            'analysis_types': self.index['analysis_type'].value_counts().to_dict() if total_entries > 0 else {},
            'most_accessed': self.index.nlargest(5, 'access_count')[['cache_key', 'analysis_type', 'access_count']].to_dict('records') if total_entries > 0 else [],
            'oldest_entry': self.index['created_at'].min() if total_entries > 0 else None,
            'newest_entry': self.index['created_at'].max() if total_entries > 0 else None
        }

        return stats

    def list_cached_analyses(self, analysis_type: Optional[str] = None) -> List[Dict]:
        """
        List all cached analyses, optionally filtered by type

        Args:
            analysis_type: Filter by analysis type

        Returns:
            List of cache entries with metadata
        """
        df = self.index

        if analysis_type:
            df = df[df['analysis_type'] == analysis_type]

        return df.to_dict('records')


class MetaAnalysisCacheWrapper:
    """
    Wrapper for meta-analysis with automatic caching
    """

    def __init__(self, cache_manager: CacheManager):
        self.cache = cache_manager

    def run_with_cache(self, analysis_func, analysis_type: str,
                       parameters: Dict[str, Any], force_refresh: bool = False) -> pd.DataFrame:
        """
        Run analysis with caching

        Args:
            analysis_func: Function that performs analysis and returns DataFrame
            analysis_type: Type of analysis
            parameters: Analysis parameters
            force_refresh: Force re-computation even if cached

        Returns:
            Analysis results DataFrame
        """
        # Check cache first
        if not force_refresh:
            cached = self.cache.get(analysis_type, parameters)
            if cached is not None:
                print(f"✓ Cache hit for {analysis_type}")
                return cached

        # Run analysis
        print(f"→ Computing {analysis_type}...")
        start_time = time.time()
        results = analysis_func()
        elapsed = time.time() - start_time

        # Cache results
        metadata = {
            'computation_time': elapsed,
            'timestamp': datetime.now().isoformat()
        }
        self.cache.put(analysis_type, parameters, results, metadata)

        print(f"✓ Computed and cached in {elapsed:.2f}s")
        return results
