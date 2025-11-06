"""
Comprehensive Tests for Global Health Data Integration

Tests for:
- WHO GHO API fetcher
- World Bank WDI API fetcher
- IHME GBD data loader
- Data harmonizer
- Cache manager
- Integration orchestrator
"""

import pytest
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime, timedelta
import tempfile
import shutil

# Import data integration components
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from data_integration.fetchers.who_gho import (
    WHOGHOFetcher,
    WHOIndicator,
    WHODataPoint,
    WHODataset
)

from data_integration.fetchers.world_bank import (
    WorldBankFetcher,
    WBIndicator,
    WBDataPoint,
    WBDataset
)

from data_integration.fetchers.ihme_gbd import (
    IHMEGBDLoader,
    GBDDataPoint,
    GBDDataset
)

from data_integration.cleaners.harmonizer import (
    GlobalHealthDataHarmonizer,
    DataSource,
    HarmonizedDataset
)

from data_integration.cache.cache_manager import (
    CacheManager,
    CacheEntry
)


# ==================== Fixtures ====================

@pytest.fixture
def sample_who_data():
    """Generate sample WHO data"""
    data_points = [
        WHODataPoint(
            indicator="WHOSIS_000001",
            country="United States",
            country_code="USA",
            year=2019,
            value=78.9,
            sex="Both"
        ),
        WHODataPoint(
            indicator="WHOSIS_000001",
            country="United Kingdom",
            country_code="GBR",
            year=2019,
            value=81.3,
            sex="Both"
        ),
        WHODataPoint(
            indicator="WHOSIS_000001",
            country="China",
            country_code="CHN",
            year=2019,
            value=76.9,
            sex="Both"
        )
    ]

    indicator = WHOIndicator(code="WHOSIS_000001", display="Life expectancy")

    return WHODataset(indicator=indicator, data_points=data_points)


@pytest.fixture
def sample_wb_data():
    """Generate sample World Bank data"""
    data_points = [
        WBDataPoint(
            indicator="SH.XPD.CHEX.GD.ZS",
            indicator_name="Health expenditure % GDP",
            country="United States",
            country_code="USA",
            year=2019,
            value=16.8
        ),
        WBDataPoint(
            indicator="SH.XPD.CHEX.GD.ZS",
            indicator_name="Health expenditure % GDP",
            country="United Kingdom",
            country_code="GBR",
            year=2019,
            value=10.2
        ),
        WBDataPoint(
            indicator="SH.XPD.CHEX.GD.ZS",
            indicator_name="Health expenditure % GDP",
            country="China",
            country_code="CHN",
            year=2019,
            value=5.4
        )
    ]

    indicator = WBIndicator(
        id="SH.XPD.CHEX.GD.ZS",
        name="Health expenditure % GDP"
    )

    return WBDataset(indicator=indicator, data_points=data_points)


@pytest.fixture
def sample_gbd_data():
    """Generate sample GBD data"""
    data_points = [
        GBDDataPoint(
            measure="DALYs",
            location="United States",
            location_id=102,
            sex="Both",
            age="All ages",
            cause="All causes",
            metric="Rate",
            year=2019,
            val=32500.5,
            upper=35000.0,
            lower=30000.0
        ),
        GBDDataPoint(
            measure="DALYs",
            location="United Kingdom",
            location_id=95,
            sex="Both",
            age="All ages",
            cause="All causes",
            metric="Rate",
            year=2019,
            val=28000.3,
            upper=30000.0,
            lower=26000.0
        )
    ]

    return GBDDataset(measure="DALYs", data_points=data_points)


@pytest.fixture
def temp_cache_dir():
    """Temporary directory for cache tests"""
    temp_dir = tempfile.mkdtemp()
    yield Path(temp_dir)
    shutil.rmtree(temp_dir)


# ==================== WHO GHO Fetcher Tests ====================

class TestWHOGHOFetcher:
    """Test WHO GHO API fetcher"""

    def test_initialization(self):
        """Test fetcher initialization"""
        fetcher = WHOGHOFetcher()
        assert fetcher is not None
        assert fetcher.config.base_url == "https://ghoapi.azureedge.net/api"

    def test_dataset_to_dataframe(self, sample_who_data):
        """Test WHO dataset conversion to DataFrame"""
        df = sample_who_data.to_dataframe()

        assert isinstance(df, pd.DataFrame)
        assert len(df) == 3
        assert "country" in df.columns
        assert "year" in df.columns
        assert "value" in df.columns

        # Check values
        usa_row = df[df["country_code"] == "USA"].iloc[0]
        assert usa_row["value"] == 78.9
        assert usa_row["year"] == 2019


# ==================== World Bank Fetcher Tests ====================

class TestWorldBankFetcher:
    """Test World Bank WDI API fetcher"""

    def test_initialization(self):
        """Test fetcher initialization"""
        fetcher = WorldBankFetcher()
        assert fetcher is not None
        assert fetcher.config.base_url == "https://api.worldbank.org/v2"

    def test_key_indicators_defined(self):
        """Test that key indicators are defined"""
        assert len(WorldBankFetcher.KEY_INDICATORS) > 0
        assert "SH.XPD.CHEX.GD.ZS" in WorldBankFetcher.KEY_INDICATORS
        assert "NY.GDP.PCAP.CD" in WorldBankFetcher.KEY_INDICATORS

    def test_dataset_to_dataframe(self, sample_wb_data):
        """Test World Bank dataset conversion to DataFrame"""
        df = sample_wb_data.to_dataframe()

        assert isinstance(df, pd.DataFrame)
        assert len(df) == 3
        assert "country" in df.columns
        assert "year" in df.columns
        assert "value" in df.columns

        # Check values
        usa_row = df[df["country_code"] == "USA"].iloc[0]
        assert usa_row["value"] == 16.8
        assert usa_row["year"] == 2019


# ==================== IHME GBD Loader Tests ====================

class TestIHMEGBDLoader:
    """Test IHME GBD data loader"""

    def test_initialization(self):
        """Test loader initialization"""
        loader = IHMEGBDLoader()
        assert loader is not None
        assert loader.data_dir.exists()

    def test_dataset_to_dataframe(self, sample_gbd_data):
        """Test GBD dataset conversion to DataFrame"""
        df = sample_gbd_data.to_dataframe()

        assert isinstance(df, pd.DataFrame)
        assert len(df) == 2
        assert "location" in df.columns
        assert "year" in df.columns
        assert "value" in df.columns
        assert "upper" in df.columns
        assert "lower" in df.columns

    def test_column_mappings(self):
        """Test column mapping definitions"""
        loader = IHMEGBDLoader()
        assert len(loader.COLUMN_MAPPINGS) > 0
        assert "measure_name" in loader.COLUMN_MAPPINGS
        assert "location_name" in loader.COLUMN_MAPPINGS


# ==================== Data Harmonizer Tests ====================

class TestGlobalHealthDataHarmonizer:
    """Test data harmonizer"""

    def test_initialization(self):
        """Test harmonizer initialization"""
        harmonizer = GlobalHealthDataHarmonizer()
        assert harmonizer is not None
        assert len(harmonizer.country_mappings) > 0

    def test_country_mappings(self):
        """Test country name mappings"""
        harmonizer = GlobalHealthDataHarmonizer()

        # Check common aliases
        assert "USA" in harmonizer.COUNTRY_ALIASES
        assert "GBR" in harmonizer.COUNTRY_ALIASES

    def test_harmonize_single_source(self, sample_who_data):
        """Test harmonization of single source"""
        harmonizer = GlobalHealthDataHarmonizer()

        df = sample_who_data.to_dataframe()

        harmonized = harmonizer.harmonize_datasets(
            datasets=[(df, DataSource.WHO)]
        )

        assert isinstance(harmonized, HarmonizedDataset)
        assert not harmonized.data.empty
        assert len(harmonized.sources) == 1

    def test_harmonize_multiple_sources(self, sample_who_data, sample_wb_data):
        """Test harmonization of multiple sources"""
        harmonizer = GlobalHealthDataHarmonizer()

        who_df = sample_who_data.to_dataframe()
        wb_df = sample_wb_data.to_dataframe()

        harmonized = harmonizer.harmonize_datasets(
            datasets=[
                (who_df, DataSource.WHO),
                (wb_df, DataSource.WORLD_BANK)
            ]
        )

        assert isinstance(harmonized, HarmonizedDataset)
        assert not harmonized.data.empty
        assert len(harmonized.sources) == 2

        # Check that data_source column exists
        assert "data_source" in harmonized.data.columns

    def test_confidence_score(self, sample_who_data):
        """Test confidence score calculation"""
        harmonizer = GlobalHealthDataHarmonizer()

        df = sample_who_data.to_dataframe()

        harmonized = harmonizer.harmonize_datasets(
            datasets=[(df, DataSource.WHO)]
        )

        assert 0.0 <= harmonized.report.confidence_score <= 1.0

    def test_harmonization_report(self, sample_who_data):
        """Test harmonization report generation"""
        harmonizer = GlobalHealthDataHarmonizer()

        df = sample_who_data.to_dataframe()

        harmonized = harmonizer.harmonize_datasets(
            datasets=[(df, DataSource.WHO)]
        )

        report_text = harmonized.report.summary()

        assert isinstance(report_text, str)
        assert len(report_text) > 0
        assert "HARMONIZATION REPORT" in report_text


# ==================== Cache Manager Tests ====================

class TestCacheManager:
    """Test cache manager"""

    def test_initialization(self, temp_cache_dir):
        """Test cache manager initialization"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        assert cache is not None
        assert cache.cache_dir.exists()
        assert cache.db_path.exists()

    def test_put_and_get(self, temp_cache_dir):
        """Test caching data"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        # Create sample data
        df = pd.DataFrame({
            "country": ["USA", "GBR"],
            "year": [2019, 2019],
            "value": [78.9, 81.3]
        })

        # Cache data
        success = cache.put(
            cache_key="test_data",
            data=df,
            source="WHO"
        )

        assert success

        # Retrieve data
        cached_df = cache.get("test_data", source="WHO")

        assert cached_df is not None
        assert len(cached_df) == len(df)
        assert list(cached_df.columns) == list(df.columns)

    def test_cache_expiry(self, temp_cache_dir):
        """Test cache expiration"""
        cache = CacheManager(
            cache_dir=temp_cache_dir,
            default_ttl_days=0  # Expire immediately
        )

        df = pd.DataFrame({"value": [1, 2, 3]})

        # Cache with very short TTL
        cache.put(
            cache_key="expiring_data",
            data=df,
            source="WHO",
            ttl=timedelta(seconds=-1)  # Already expired
        )

        # Try to retrieve (should be None)
        cached_df = cache.get("expiring_data", source="WHO")

        assert cached_df is None

    def test_cache_stats(self, temp_cache_dir):
        """Test cache statistics"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        df = pd.DataFrame({"value": [1, 2, 3]})

        cache.put("data1", df, source="WHO")
        cache.put("data2", df, source="WB")

        stats = cache.get_stats()

        assert stats.total_entries == 2
        assert stats.total_size_bytes > 0

    def test_cache_clear(self, temp_cache_dir):
        """Test cache clearing"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        df = pd.DataFrame({"value": [1, 2, 3]})

        cache.put("data1", df, source="WHO")
        cache.put("data2", df, source="WB")

        # Clear WHO cache only
        n_cleared = cache.clear(source="WHO")

        assert n_cleared == 1

        # Check that WHO is gone but WB remains
        assert cache.get("data1", source="WHO") is None
        assert cache.get("data2", source="WB") is not None

    def test_cache_delete(self, temp_cache_dir):
        """Test cache deletion"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        df = pd.DataFrame({"value": [1, 2, 3]})

        cache.put("data", df, source="WHO")

        success = cache.delete("data", source="WHO")

        assert success
        assert cache.get("data", source="WHO") is None


# ==================== Integration Tests ====================

class TestDataIntegration:
    """Integration tests for complete workflows"""

    def test_complete_harmonization_workflow(self, sample_who_data, sample_wb_data):
        """Test complete harmonization workflow"""
        harmonizer = GlobalHealthDataHarmonizer()

        who_df = sample_who_data.to_dataframe()
        wb_df = sample_wb_data.to_dataframe()

        # Harmonize
        harmonized = harmonizer.harmonize_datasets(
            datasets=[
                (who_df, DataSource.WHO),
                (wb_df, DataSource.WORLD_BANK)
            ],
            target_countries=["USA", "GBR"],
            target_years=[2019]
        )

        # Verify
        assert not harmonized.data.empty
        assert len(harmonized.sources) == 2
        assert harmonized.report.countries_mapped == 2

        # Check standardized columns
        assert "country_iso3" in harmonized.data.columns
        assert "year" in harmonized.data.columns

    def test_cache_hit_rate(self, temp_cache_dir):
        """Test cache hit rate calculation"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        df = pd.DataFrame({"value": [1, 2, 3]})

        # First access (miss)
        result = cache.get("data", source="WHO")
        assert result is None
        assert cache.misses == 1

        # Cache data
        cache.put("data", df, source="WHO")

        # Second access (hit)
        result = cache.get("data", source="WHO")
        assert result is not None
        assert cache.hits == 1

        # Check stats
        stats = cache.get_stats()
        assert stats.hit_rate == 0.5  # 1 hit, 1 miss


# ==================== Edge Cases ====================

class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_empty_dataset_harmonization(self):
        """Test harmonization with empty dataset"""
        harmonizer = GlobalHealthDataHarmonizer()

        empty_df = pd.DataFrame()

        harmonized = harmonizer.harmonize_datasets(
            datasets=[(empty_df, DataSource.WHO)]
        )

        assert harmonized.data.empty
        assert harmonized.report.confidence_score == 0.0

    def test_cache_empty_dataframe(self, temp_cache_dir):
        """Test caching empty DataFrame"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        empty_df = pd.DataFrame()

        success = cache.put("empty", empty_df, source="WHO")

        assert not success  # Should not cache empty data

    def test_cache_with_missing_values(self, temp_cache_dir):
        """Test caching data with missing values"""
        cache = CacheManager(cache_dir=temp_cache_dir)

        df = pd.DataFrame({
            "country": ["USA", "GBR", None],
            "value": [1.0, np.nan, 3.0]
        })

        success = cache.put("data_with_na", df, source="WHO")
        assert success

        cached_df = cache.get("data_with_na", source="WHO")
        assert cached_df is not None
        assert len(cached_df) == 3


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
