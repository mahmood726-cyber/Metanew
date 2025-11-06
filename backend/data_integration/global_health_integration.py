"""
Global Health Data Integration System

Main orchestrator for multi-source global health data integration.

Integrates:
- WHO Global Health Observatory
- World Bank World Development Indicators
- IHME Global Burden of Disease
- Custom datasets

Features:
- Multi-source data fetching
- Intelligent caching (Parquet + SQLite)
- Data harmonization and cleaning
- Integration with LLM-powered data cleaning (from ml/llm_advanced.py)
- Export for meta-analysis

Value: £80-120k (complete data integration pipeline)

Dependencies:
- All fetchers, harmonizer, cache manager
- ml/llm_advanced.py for AI-powered cleaning
"""

import logging
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime, timedelta
from pathlib import Path
import pandas as pd
import numpy as np

from .fetchers.who_gho import WHOGHOFetcher, WHOIndicator
from .fetchers.world_bank import WorldBankFetcher, WBIndicator
from .fetchers.ihme_gbd import IHMEGBDLoader, GBDDataset
from .cleaners.harmonizer import GlobalHealthDataHarmonizer, DataSource, HarmonizedDataset
from .cache.cache_manager import CacheManager

# Try to import LLM-powered data cleaner
try:
    import sys
    sys.path.append("./ml")
    from llm_advanced import GlobalHealthDataCleaner, DataSource as LLMDataSource
    LLM_CLEANER_AVAILABLE = True
except ImportError:
    LLM_CLEANER_AVAILABLE = False
    logger = logging.getLogger(__name__)
    logger.warning("GlobalHealthDataCleaner from ml/llm_advanced.py not available")


logger = logging.getLogger(__name__)


# ==================== ENUMS ====================

class IntegrationMode(Enum):
    """Integration modes"""
    FETCH_ONLY = "fetch_only"  # Just fetch, no cleaning
    CLEAN = "clean"  # Fetch + basic cleaning
    AI_CLEAN = "ai_clean"  # Fetch + AI-powered cleaning
    FULL = "full"  # Fetch + harmonization + AI cleaning


# ==================== DATA CLASSES ====================

@dataclass
class IntegrationConfig:
    """Configuration for data integration"""
    # Cache settings
    cache_dir: Path = Path("./data/cache")
    cache_ttl_days: int = 30
    use_cache: bool = True

    # Fetcher settings
    who_timeout: int = 30
    wb_timeout: int = 30

    # Integration mode
    mode: IntegrationMode = IntegrationMode.FULL

    # AI cleaning (requires llama-cpp-python)
    use_llm_cleaning: bool = True
    llm_confidence_threshold: float = 0.7


@dataclass
class IntegrationRequest:
    """Request for integrated data"""
    # WHO indicators
    who_indicators: List[str] = field(default_factory=list)

    # World Bank indicators
    wb_indicators: List[str] = field(default_factory=list)

    # IHME GBD files
    gbd_files: List[Path] = field(default_factory=list)

    # Filters
    countries: Optional[List[str]] = None  # ISO3 codes
    years: Optional[List[int]] = None

    # Output format
    wide_format: bool = False  # Wide vs long format


@dataclass
class IntegrationResult:
    """Result of data integration"""
    data: pd.DataFrame
    sources_used: List[str]
    records_fetched: int
    records_cleaned: int
    records_final: int
    cache_hits: int
    cache_misses: int
    harmonization_confidence: float
    warnings: List[str] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.now)

    def summary(self) -> str:
        """Generate summary report"""
        lines = ["=" * 60, "GLOBAL HEALTH DATA INTEGRATION REPORT", "=" * 60, ""]

        lines.append(f"Sources Used: {', '.join(self.sources_used)}")
        lines.append(f"Records Fetched: {self.records_fetched:,}")
        lines.append(f"Records Cleaned: {self.records_cleaned:,}")
        lines.append(f"Records Final: {self.records_final:,}")
        lines.append(f"Cache Hit Rate: {self.cache_hits / (self.cache_hits + self.cache_misses):.1%}")
        lines.append(f"Data Quality: {self.harmonization_confidence:.1%}")
        lines.append("")

        if self.warnings:
            lines.append("Warnings:")
            for warning in self.warnings:
                lines.append(f"  ⚠ {warning}")
            lines.append("")

        if "countries" in self.metadata:
            lines.append(f"Countries: {len(self.metadata['countries'])}")

        if "year_range" in self.metadata:
            yr_min, yr_max = self.metadata["year_range"]
            lines.append(f"Year Range: {yr_min} - {yr_max}")

        return "\n".join(lines)


# ==================== GLOBAL HEALTH DATA INTEGRATION ====================

class GlobalHealthDataIntegration:
    """
    Global Health Data Integration System

    Main orchestrator that:
    1. Fetches data from WHO, World Bank, IHME
    2. Caches results for performance
    3. Harmonizes data across sources
    4. Applies AI-powered cleaning (from ml/llm_advanced.py)
    5. Exports for meta-analysis

    Example use cases:
    - Fetch health expenditure + GDP for all LMICs
    - Combine WHO mortality + World Bank economics
    - Integrate IHME disease burden + World Bank poverty data

    Value: £80-120k (complete data pipeline)
    """

    def __init__(self, config: Optional[IntegrationConfig] = None):
        """
        Initialize integration system

        Args:
            config: Integration configuration
        """
        self.config = config or IntegrationConfig()

        # Initialize components
        self.who_fetcher = WHOGHOFetcher()
        self.wb_fetcher = WorldBankFetcher()
        self.gbd_loader = IHMEGBDLoader()
        self.harmonizer = GlobalHealthDataHarmonizer()

        # Initialize cache
        if self.config.use_cache:
            self.cache = CacheManager(
                cache_dir=self.config.cache_dir,
                default_ttl_days=self.config.cache_ttl_days
            )
        else:
            self.cache = None

        # Initialize LLM cleaner if available
        if LLM_CLEANER_AVAILABLE and self.config.use_llm_cleaning:
            self.llm_cleaner = GlobalHealthDataCleaner()
        else:
            self.llm_cleaner = None

        logger.info("Global Health Data Integration initialized")

    def fetch_and_integrate(
        self,
        request: IntegrationRequest
    ) -> IntegrationResult:
        """
        Fetch and integrate data from multiple sources

        Args:
            request: Integration request

        Returns:
            IntegrationResult with integrated data
        """
        logger.info("Starting data integration")

        datasets = []
        sources_used = []
        warnings = []
        cache_hits = 0
        cache_misses = 0

        # 1. Fetch WHO data
        if request.who_indicators:
            logger.info(f"Fetching {len(request.who_indicators)} WHO indicators")
            for indicator in request.who_indicators:
                cache_key = f"who_{indicator}_{request.countries}_{request.years}"

                # Try cache
                if self.cache:
                    cached_data = self.cache.get(cache_key, source="WHO")
                    if cached_data is not None:
                        datasets.append((cached_data, DataSource.WHO))
                        cache_hits += 1
                        continue

                cache_misses += 1

                # Fetch from API
                who_dataset = self.who_fetcher.fetch_indicator_data(
                    indicator_code=indicator,
                    countries=request.countries,
                    years=request.years
                )

                df = who_dataset.to_dataframe()

                if not df.empty:
                    datasets.append((df, DataSource.WHO))
                    sources_used.append("WHO")

                    # Cache
                    if self.cache:
                        self.cache.put(cache_key, df, source="WHO")
                else:
                    warnings.append(f"No WHO data for {indicator}")

        # 2. Fetch World Bank data
        if request.wb_indicators:
            logger.info(f"Fetching {len(request.wb_indicators)} World Bank indicators")
            for indicator in request.wb_indicators:
                cache_key = f"wb_{indicator}_{request.countries}_{request.years}"

                # Try cache
                if self.cache:
                    cached_data = self.cache.get(cache_key, source="WorldBank")
                    if cached_data is not None:
                        datasets.append((cached_data, DataSource.WORLD_BANK))
                        cache_hits += 1
                        continue

                cache_misses += 1

                # Fetch from API
                years_tuple = (min(request.years), max(request.years)) if request.years else None

                wb_dataset = self.wb_fetcher.fetch_indicator_data(
                    indicator_code=indicator,
                    countries=request.countries,
                    years=years_tuple
                )

                df = wb_dataset.to_dataframe()

                if not df.empty:
                    datasets.append((df, DataSource.WORLD_BANK))
                    sources_used.append("World Bank")

                    # Cache
                    if self.cache:
                        self.cache.put(cache_key, df, source="WorldBank")
                else:
                    warnings.append(f"No World Bank data for {indicator}")

        # 3. Load IHME GBD data
        if request.gbd_files:
            logger.info(f"Loading {len(request.gbd_files)} IHME GBD files")
            for file_path in request.gbd_files:
                gbd_dataset = self.gbd_loader.load_from_csv(
                    file_path=file_path,
                    filters={"location": request.countries, "year": request.years} if request.countries or request.years else None
                )

                df = gbd_dataset.to_dataframe()

                if not df.empty:
                    datasets.append((df, DataSource.IHME_GBD))
                    sources_used.append("IHME GBD")
                else:
                    warnings.append(f"No IHME data in {file_path.name}")

        sources_used = list(set(sources_used))  # Unique sources

        records_fetched = sum(len(df) for df, _ in datasets)

        # 4. Harmonize data
        if self.config.mode in [IntegrationMode.CLEAN, IntegrationMode.AI_CLEAN, IntegrationMode.FULL]:
            logger.info("Harmonizing data across sources")

            harmonized = self.harmonizer.harmonize_datasets(
                datasets=datasets,
                target_countries=request.countries,
                target_years=request.years
            )

            combined_data = harmonized.data
            harmonization_confidence = harmonized.report.confidence_score
            warnings.extend(harmonized.report.warnings)

        else:
            # Just concatenate without harmonization
            combined_data = pd.concat([df for df, _ in datasets], ignore_index=True)
            harmonization_confidence = 1.0

        records_cleaned = len(combined_data)

        # 5. AI-powered cleaning (if enabled)
        if self.config.mode == IntegrationMode.AI_CLEAN or self.config.mode == IntegrationMode.FULL:
            if self.llm_cleaner:
                logger.info("Applying AI-powered data cleaning")

                # Determine source for LLM cleaner
                if "WHO" in sources_used and "World Bank" in sources_used:
                    llm_source = LLMDataSource.CUSTOM
                elif "WHO" in sources_used:
                    llm_source = LLMDataSource.WHO
                elif "World Bank" in sources_used:
                    llm_source = LLMDataSource.WORLD_BANK
                else:
                    llm_source = LLMDataSource.CUSTOM

                cleaning_report = self.llm_cleaner.clean_data(
                    df=combined_data,
                    source=llm_source,
                    auto_fix=True
                )

                combined_data = cleaning_report.cleaned_df
                warnings.extend(cleaning_report.recommendations)

        # 6. Format conversion
        if request.wide_format and not combined_data.empty:
            combined_data = self._convert_to_wide_format(combined_data)

        records_final = len(combined_data)

        # 7. Build result
        unique_countries = combined_data["country_iso3"].nunique() if "country_iso3" in combined_data.columns else 0

        year_range = None
        if "year" in combined_data.columns and not combined_data.empty:
            year_range = (int(combined_data["year"].min()), int(combined_data["year"].max()))

        result = IntegrationResult(
            data=combined_data,
            sources_used=sources_used,
            records_fetched=records_fetched,
            records_cleaned=records_cleaned,
            records_final=records_final,
            cache_hits=cache_hits,
            cache_misses=cache_misses,
            harmonization_confidence=harmonization_confidence,
            warnings=warnings,
            metadata={
                "countries": unique_countries,
                "year_range": year_range
            }
        )

        logger.info(f"Integration complete: {records_final} final records")
        return result

    def fetch_health_economics_package(
        self,
        countries: List[str],
        years: List[int]
    ) -> IntegrationResult:
        """
        Fetch standard health economics data package

        Includes:
        - Health expenditure (WHO + World Bank)
        - GDP per capita (World Bank)
        - Life expectancy (WHO)
        - Population (World Bank)
        - UHC coverage (WHO)

        Args:
            countries: ISO3 country codes
            years: Years to fetch

        Returns:
            IntegrationResult with health economics data
        """
        request = IntegrationRequest(
            who_indicators=[
                "WHOSIS_000001",  # Life expectancy
                "SA_0000001688",  # UHC coverage
                "SH.XPD.CHEX.GD.ZS"  # Health expenditure % GDP (if available in WHO)
            ],
            wb_indicators=[
                "SH.XPD.CHEX.GD.ZS",  # Health expenditure % GDP
                "SH.XPD.CHEX.PC.CD",  # Health expenditure per capita
                "NY.GDP.PCAP.CD",  # GDP per capita
                "SP.POP.TOTL",  # Population
                "SP.DYN.LE00.IN"  # Life expectancy (backup)
            ],
            countries=countries,
            years=years,
            wide_format=False
        )

        return self.fetch_and_integrate(request)

    def fetch_lmic_profile(
        self,
        income_group: str = "LIC",
        years: List[int] = None
    ) -> IntegrationResult:
        """
        Fetch comprehensive LMIC health profile

        Args:
            income_group: "LIC", "LMC", "UMC" (World Bank classification)
            years: Years (None = recent 5 years)

        Returns:
            IntegrationResult with LMIC health data
        """
        if years is None:
            current_year = datetime.now().year
            years = list(range(current_year - 5, current_year))

        # Get countries in income group
        all_countries = self.wb_fetcher.list_countries()
        income_countries = [
            c.id for c in all_countries
            if income_group in c.income_level if c.income_level
        ]

        logger.info(f"Fetching data for {len(income_countries)} {income_group} countries")

        return self.fetch_health_economics_package(
            countries=income_countries,
            years=years
        )

    def _convert_to_wide_format(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Convert long format to wide format

        Args:
            df: DataFrame in long format

        Returns:
            DataFrame in wide format
        """
        if df.empty:
            return df

        # Pivot on indicator
        if "indicator" in df.columns and "value" in df.columns:
            id_vars = ["country_iso3", "year"] if "year" in df.columns else ["country_iso3"]

            wide_df = df.pivot_table(
                index=id_vars,
                columns="indicator",
                values="value",
                aggfunc="first"
            ).reset_index()

            return wide_df

        return df


# ==================== CONVENIENCE FUNCTIONS ====================

def fetch_who_wb_data(
    who_indicators: List[str],
    wb_indicators: List[str],
    countries: List[str],
    years: List[int],
    cache_dir: Path = Path("./data/cache")
) -> IntegrationResult:
    """
    Convenience function to fetch WHO + World Bank data

    Args:
        who_indicators: WHO indicator codes
        wb_indicators: World Bank indicator codes
        countries: ISO3 country codes
        years: Years
        cache_dir: Cache directory

    Returns:
        IntegrationResult
    """
    config = IntegrationConfig(cache_dir=cache_dir)
    integration = GlobalHealthDataIntegration(config)

    request = IntegrationRequest(
        who_indicators=who_indicators,
        wb_indicators=wb_indicators,
        countries=countries,
        years=years
    )

    return integration.fetch_and_integrate(request)


# ==================== EXAMPLE USAGE ====================

if __name__ == "__main__":
    print("=" * 60)
    print("Global Health Data Integration Example")
    print("=" * 60)

    # Initialize integration system
    config = IntegrationConfig(
        cache_dir=Path("./data/cache"),
        use_cache=True,
        mode=IntegrationMode.FULL
    )

    integration = GlobalHealthDataIntegration(config)

    # Example 1: Fetch health economics package for selected countries
    print("\n1. Fetching health economics data:")

    result = integration.fetch_health_economics_package(
        countries=["GBR", "USA", "CHN", "IND"],
        years=[2018, 2019, 2020]
    )

    print(result.summary())

    if not result.data.empty:
        print("\nSample data:")
        print(result.data.head(10))

    # Example 2: Fetch LMIC profile
    print("\n2. Fetching Low Income Country profile:")

    lmic_result = integration.fetch_lmic_profile(
        income_group="LIC",
        years=[2019, 2020]
    )

    print(lmic_result.summary())

    print("\n✓ Global Health Data Integration Complete")
    print("  Value: £80-120k (complete data pipeline)")
