"""
World Bank World Development Indicators (WDI) API Fetcher

Fetches development indicators from World Bank API:
- Economic indicators (GDP, GNI, poverty)
- Health expenditure
- Demographics
- Infrastructure
- Education

API Documentation: https://datahelpdesk.worldbank.org/knowledgebase/articles/889392

Value: £30k (essential for health economics and LMIC research)

Dependencies:
- requests: HTTP requests
- pandas: Data manipulation
- numpy: Numerical operations
"""

import logging
import time
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import requests
import pandas as pd
import numpy as np

logger = logging.getLogger(__name__)


# ==================== ENUMS ====================

class WBIndicatorCategory(Enum):
    """World Bank indicator categories"""
    ECONOMY = "economy"
    HEALTH = "health"
    EDUCATION = "education"
    DEMOGRAPHICS = "demographics"
    INFRASTRUCTURE = "infrastructure"
    ENVIRONMENT = "environment"
    POVERTY = "poverty"


class WBIncomeLevel(Enum):
    """World Bank income classifications"""
    LOW = "LIC"
    LOWER_MIDDLE = "LMC"
    UPPER_MIDDLE = "UMC"
    HIGH = "HIC"


class WBRegion(Enum):
    """World Bank regions"""
    EAS = "EAS"  # East Asia & Pacific
    ECS = "ECS"  # Europe & Central Asia
    LCN = "LCN"  # Latin America & Caribbean
    MEA = "MEA"  # Middle East & North Africa
    NAC = "NAC"  # North America
    SAS = "SAS"  # South Asia
    SSF = "SSF"  # Sub-Saharan Africa


# ==================== DATA CLASSES ====================

@dataclass
class WBIndicator:
    """World Bank indicator metadata"""
    id: str
    name: str
    source: Optional[str] = None
    source_note: Optional[str] = None
    source_organization: Optional[str] = None
    unit: Optional[str] = None
    topics: List[str] = field(default_factory=list)


@dataclass
class WBCountry:
    """World Bank country metadata"""
    id: str  # ISO3 code
    name: str
    iso2_code: str
    region: Optional[str] = None
    income_level: Optional[str] = None
    capital_city: Optional[str] = None
    longitude: Optional[float] = None
    latitude: Optional[float] = None


@dataclass
class WBDataPoint:
    """Single World Bank data point"""
    indicator: str
    indicator_name: str
    country: str
    country_code: str
    year: int
    value: float
    unit: Optional[str] = None
    decimal: int = 0


@dataclass
class WBDataset:
    """Complete World Bank dataset"""
    indicator: WBIndicator
    data_points: List[WBDataPoint]
    metadata: Dict[str, Any] = field(default_factory=dict)
    fetch_timestamp: datetime = field(default_factory=datetime.now)

    def to_dataframe(self) -> pd.DataFrame:
        """Convert to pandas DataFrame"""
        if not self.data_points:
            return pd.DataFrame()

        records = []
        for dp in self.data_points:
            records.append({
                "indicator": dp.indicator,
                "indicator_name": dp.indicator_name,
                "country": dp.country,
                "country_code": dp.country_code,
                "year": dp.year,
                "value": dp.value,
                "unit": dp.unit,
                "decimal": dp.decimal
            })

        return pd.DataFrame(records)


@dataclass
class WBFetchConfig:
    """Configuration for World Bank API fetcher"""
    base_url: str = "https://api.worldbank.org/v2"
    format: str = "json"
    per_page: int = 1000
    timeout: int = 30
    max_retries: int = 3
    retry_delay: float = 1.0
    rate_limit_delay: float = 0.3


# ==================== WORLD BANK WDI API FETCHER ====================

class WorldBankFetcher:
    """
    World Bank World Development Indicators API Fetcher

    Fetches development indicators from World Bank WDI API.

    Key indicators for health economics:
    - SH.XPD.CHEX.GD.ZS: Current health expenditure (% of GDP)
    - SH.XPD.CHEX.PC.CD: Current health expenditure per capita (USD)
    - SH.MED.PHYS.ZS: Physicians per 1000 people
    - SP.DYN.LE00.IN: Life expectancy at birth
    - NY.GDP.PCAP.CD: GDP per capita (USD)
    - SI.POV.DDAY: Poverty headcount ratio at $2.15/day

    Value: £30k (essential for health economics research)
    """

    # Key health & economics indicators
    KEY_INDICATORS = {
        # Health expenditure
        "SH.XPD.CHEX.GD.ZS": "Health expenditure (% of GDP)",
        "SH.XPD.CHEX.PC.CD": "Health expenditure per capita (USD)",
        "SH.XPD.GHED.GD.ZS": "Government health expenditure (% of GDP)",
        "SH.XPD.OOPC.CH.ZS": "Out-of-pocket health expenditure (%)",

        # Health workforce
        "SH.MED.PHYS.ZS": "Physicians (per 1000 people)",
        "SH.MED.NUMW.P3": "Nurses and midwives (per 1000 people)",
        "SH.MED.BEDS.ZS": "Hospital beds (per 1000 people)",

        # Demographics
        "SP.POP.TOTL": "Total population",
        "SP.DYN.LE00.IN": "Life expectancy at birth",
        "SP.DYN.TFRT.IN": "Fertility rate (births per woman)",
        "SP.POP.65UP.TO.ZS": "Population ages 65+ (%)",

        # Economics
        "NY.GDP.PCAP.CD": "GDP per capita (USD)",
        "NY.GNP.PCAP.CD": "GNI per capita (USD)",
        "SI.POV.DDAY": "Poverty headcount ratio at $2.15/day (%)",
        "SI.POV.NAHC": "Poverty headcount ratio (%)",
    }

    def __init__(self, config: Optional[WBFetchConfig] = None):
        """
        Initialize World Bank fetcher

        Args:
            config: Fetch configuration
        """
        self.config = config or WBFetchConfig()
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "EvidenceOS-PRIME/1.0",
            "Accept": "application/json"
        })

    def list_indicators(
        self,
        search_term: Optional[str] = None,
        source: Optional[str] = None
    ) -> List[WBIndicator]:
        """
        List available World Bank indicators

        Args:
            search_term: Search in indicator names
            source: Filter by source (e.g., "2" for WDI)

        Returns:
            List of available indicators
        """
        url = f"{self.config.base_url}/indicator"
        params = {
            "format": self.config.format,
            "per_page": self.config.per_page
        }

        if source:
            params["source"] = source

        try:
            response = self._make_request(url, params)
            data = response.json()

            if len(data) < 2:
                return []

            indicators = []
            for item in data[1]:
                indicator = WBIndicator(
                    id=item.get("id", ""),
                    name=item.get("name", ""),
                    source=item.get("source", {}).get("value"),
                    source_note=item.get("sourceNote"),
                    source_organization=item.get("sourceOrganization"),
                    unit=item.get("unit"),
                    topics=[t.get("value", "") for t in item.get("topics", [])]
                )

                # Filter by search term
                if search_term and search_term.lower() not in indicator.name.lower():
                    continue

                indicators.append(indicator)

            logger.info(f"Found {len(indicators)} World Bank indicators")
            return indicators

        except Exception as e:
            logger.error(f"Failed to list World Bank indicators: {e}")
            return []

    def list_countries(self) -> List[WBCountry]:
        """
        List all countries in World Bank database

        Returns:
            List of WBCountry objects
        """
        url = f"{self.config.base_url}/country"
        params = {
            "format": self.config.format,
            "per_page": self.config.per_page
        }

        try:
            response = self._make_request(url, params)
            data = response.json()

            if len(data) < 2:
                return []

            countries = []
            for item in data[1]:
                # Skip aggregates (regions, income groups)
                if item.get("region", {}).get("value") == "Aggregates":
                    continue

                country = WBCountry(
                    id=item.get("id", ""),
                    name=item.get("name", ""),
                    iso2_code=item.get("iso2Code", ""),
                    region=item.get("region", {}).get("value"),
                    income_level=item.get("incomeLevel", {}).get("value"),
                    capital_city=item.get("capitalCity"),
                    longitude=item.get("longitude"),
                    latitude=item.get("latitude")
                )
                countries.append(country)

            logger.info(f"Found {len(countries)} countries")
            return countries

        except Exception as e:
            logger.error(f"Failed to list countries: {e}")
            return []

    def fetch_indicator_data(
        self,
        indicator_code: str,
        countries: Optional[List[str]] = None,
        years: Optional[Tuple[int, int]] = None
    ) -> WBDataset:
        """
        Fetch data for a specific World Bank indicator

        Args:
            indicator_code: WB indicator code (e.g., "SH.XPD.CHEX.GD.ZS")
            countries: List of ISO3 country codes (None = all countries)
            years: Tuple of (start_year, end_year) (None = all years)

        Returns:
            WBDataset with indicator data
        """
        logger.info(f"Fetching World Bank indicator: {indicator_code}")

        # Build country string
        if countries:
            country_str = ";".join(countries)
        else:
            country_str = "all"

        # Build URL
        url = f"{self.config.base_url}/country/{country_str}/indicator/{indicator_code}"

        params = {
            "format": self.config.format,
            "per_page": self.config.per_page
        }

        if years:
            params["date"] = f"{years[0]}:{years[1]}"

        try:
            # Get indicator metadata
            indicator_meta = self._get_indicator_metadata(indicator_code)

            # Fetch data with pagination
            all_data_points = []
            page = 1

            while True:
                params["page"] = page
                response = self._make_request(url, params)
                data = response.json()

                if len(data) < 2 or not data[1]:
                    break

                # Parse data points
                for item in data[1]:
                    data_point = self._parse_data_point(item, indicator_code)
                    if data_point:
                        all_data_points.append(data_point)

                # Check if more pages
                metadata = data[0]
                total_pages = metadata.get("pages", 1)
                if page >= total_pages:
                    break

                page += 1
                time.sleep(self.config.rate_limit_delay)

            dataset = WBDataset(
                indicator=indicator_meta,
                data_points=all_data_points,
                metadata={"total_records": len(all_data_points)}
            )

            logger.info(f"Fetched {len(all_data_points)} data points for {indicator_code}")
            return dataset

        except Exception as e:
            logger.error(f"Failed to fetch World Bank indicator {indicator_code}: {e}")
            return WBDataset(
                indicator=WBIndicator(id=indicator_code, name=indicator_code),
                data_points=[]
            )

    def fetch_multiple_indicators(
        self,
        indicator_codes: List[str],
        countries: Optional[List[str]] = None,
        years: Optional[Tuple[int, int]] = None
    ) -> Dict[str, WBDataset]:
        """
        Fetch multiple indicators at once

        Args:
            indicator_codes: List of WB indicator codes
            countries: Filter by countries
            years: Filter by years (start_year, end_year)

        Returns:
            Dict mapping indicator codes to datasets
        """
        datasets = {}

        for indicator_code in indicator_codes:
            dataset = self.fetch_indicator_data(
                indicator_code=indicator_code,
                countries=countries,
                years=years
            )
            datasets[indicator_code] = dataset

            # Rate limiting
            time.sleep(self.config.rate_limit_delay)

        return datasets

    def fetch_country_profile(
        self,
        country_code: str,
        indicator_codes: Optional[List[str]] = None,
        years: Optional[Tuple[int, int]] = None
    ) -> pd.DataFrame:
        """
        Fetch comprehensive country development profile

        Args:
            country_code: ISO3 country code
            indicator_codes: Specific indicators (None = key indicators)
            years: Years to fetch (start, end) (None = recent years)

        Returns:
            DataFrame with country indicators
        """
        # Default key indicators if not specified
        if indicator_codes is None:
            indicator_codes = list(self.KEY_INDICATORS.keys())

        datasets = self.fetch_multiple_indicators(
            indicator_codes=indicator_codes,
            countries=[country_code],
            years=years
        )

        # Combine into single DataFrame
        dfs = []
        for indicator_code, dataset in datasets.items():
            df = dataset.to_dataframe()
            if not df.empty:
                dfs.append(df)

        if dfs:
            combined = pd.concat(dfs, ignore_index=True)
            return combined
        else:
            return pd.DataFrame()

    def fetch_income_group_data(
        self,
        income_level: WBIncomeLevel,
        indicator_codes: List[str],
        years: Optional[Tuple[int, int]] = None
    ) -> pd.DataFrame:
        """
        Fetch data for all countries in an income group

        Args:
            income_level: Income classification
            indicator_codes: Indicators to fetch
            years: Year range

        Returns:
            DataFrame with data for all countries in income group
        """
        # Get countries in income group
        all_countries = self.list_countries()
        income_countries = [
            c.id for c in all_countries
            if income_level.value in c.income_level if c.income_level
        ]

        logger.info(f"Found {len(income_countries)} countries in {income_level.value}")

        datasets = self.fetch_multiple_indicators(
            indicator_codes=indicator_codes,
            countries=income_countries,
            years=years
        )

        # Combine into single DataFrame
        dfs = []
        for indicator_code, dataset in datasets.items():
            df = dataset.to_dataframe()
            if not df.empty:
                dfs.append(df)

        if dfs:
            combined = pd.concat(dfs, ignore_index=True)
            return combined
        else:
            return pd.DataFrame()

    def _make_request(self, url: str, params: Dict[str, Any]) -> requests.Response:
        """
        Make HTTP request with retry logic

        Args:
            url: URL to request
            params: Query parameters

        Returns:
            Response object

        Raises:
            requests.RequestException: If request fails
        """
        for attempt in range(self.config.max_retries):
            try:
                response = self.session.get(
                    url,
                    params=params,
                    timeout=self.config.timeout
                )
                response.raise_for_status()
                return response

            except requests.RequestException as e:
                if attempt < self.config.max_retries - 1:
                    logger.warning(f"Request failed (attempt {attempt + 1}): {e}")
                    time.sleep(self.config.retry_delay * (2 ** attempt))
                else:
                    logger.error(f"Request failed after {self.config.max_retries} attempts: {e}")
                    raise

        raise requests.RequestException("Max retries exceeded")

    def _get_indicator_metadata(self, indicator_code: str) -> WBIndicator:
        """Get indicator metadata"""
        url = f"{self.config.base_url}/indicator/{indicator_code}"
        params = {"format": self.config.format}

        try:
            response = self._make_request(url, params)
            data = response.json()

            if len(data) >= 2 and data[1]:
                item = data[1][0]
                return WBIndicator(
                    id=item.get("id", indicator_code),
                    name=item.get("name", indicator_code),
                    source=item.get("source", {}).get("value"),
                    source_note=item.get("sourceNote"),
                    source_organization=item.get("sourceOrganization"),
                    unit=item.get("unit")
                )
        except Exception as e:
            logger.warning(f"Failed to get metadata for {indicator_code}: {e}")

        return WBIndicator(id=indicator_code, name=indicator_code)

    def _parse_data_point(self, item: Dict[str, Any], indicator_code: str) -> Optional[WBDataPoint]:
        """
        Parse World Bank API data point

        Args:
            item: Raw data item from API
            indicator_code: Indicator code

        Returns:
            Parsed WBDataPoint or None if invalid
        """
        try:
            value = item.get("value")
            if value is None:
                return None

            year = item.get("date")
            if year is None:
                return None

            year = int(year) if isinstance(year, str) else year

            data_point = WBDataPoint(
                indicator=indicator_code,
                indicator_name=item.get("indicator", {}).get("value", indicator_code),
                country=item.get("country", {}).get("value", ""),
                country_code=item.get("countryiso3code", ""),
                year=year,
                value=float(value),
                unit=item.get("unit"),
                decimal=item.get("decimal", 0)
            )

            return data_point

        except Exception as e:
            logger.warning(f"Failed to parse data point: {e}")
            return None


# ==================== EXAMPLE USAGE ====================

if __name__ == "__main__":
    print("=" * 60)
    print("World Bank WDI API Fetcher Example")
    print("=" * 60)

    # Initialize fetcher
    fetcher = WorldBankFetcher()

    # Example 1: List countries
    print("\n1. Listing countries:")
    countries = fetcher.list_countries()
    print(f"  Found {len(countries)} countries")
    for country in countries[:5]:
        print(f"  - {country.name} ({country.id}): {country.income_level}")

    # Example 2: Fetch health expenditure data
    print("\n2. Fetching health expenditure data:")
    dataset = fetcher.fetch_indicator_data(
        indicator_code="SH.XPD.CHEX.GD.ZS",  # Health expenditure % GDP
        countries=["USA", "GBR", "CHN"],
        years=(2015, 2020)
    )

    df = dataset.to_dataframe()
    if not df.empty:
        print(f"  Fetched {len(df)} records")
        print(df.head())

    # Example 3: Fetch country profile
    print("\n3. Fetching UK development profile:")
    uk_profile = fetcher.fetch_country_profile(
        country_code="GBR",
        years=(2018, 2020)
    )

    if not uk_profile.empty:
        print(f"  UK profile has {len(uk_profile)} data points")
        latest = uk_profile[uk_profile["year"] == uk_profile["year"].max()]
        print(latest[["indicator_name", "value", "year"]])

    # Example 4: Fetch LIC data
    print("\n4. Fetching Low Income Country health data:")
    lic_data = fetcher.fetch_income_group_data(
        income_level=WBIncomeLevel.LOW,
        indicator_codes=["SH.XPD.CHEX.GD.ZS", "SP.DYN.LE00.IN"],
        years=(2019, 2020)
    )

    if not lic_data.empty:
        print(f"  Fetched {len(lic_data)} records for LIC")
        print(lic_data.groupby("indicator_name")["value"].mean())

    print("\n✓ World Bank WDI Fetcher Complete")
    print("  Value: £30k (essential for health economics)")
