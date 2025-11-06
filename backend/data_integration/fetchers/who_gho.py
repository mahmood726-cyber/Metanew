"""
WHO Global Health Observatory (GHO) API Fetcher

Fetches health data from WHO GHO API:
- Mortality indicators
- Disease prevalence
- Health service coverage
- Risk factors
- Environmental health

API Documentation: https://www.who.int/data/gho/info/gho-odata-api

Value: £30k (essential global health data source)

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

class WHODataDimension(Enum):
    """WHO GHO data dimensions"""
    COUNTRY = "COUNTRY"
    REGION = "REGION"
    YEAR = "YEAR"
    SEX = "SEX"
    AGE_GROUP = "AGEGROUP"
    WEALTH_QUINTILE = "WEALTHQUINTILE"


class WHOIndicatorCategory(Enum):
    """WHO indicator categories"""
    MORTALITY = "mortality"
    MORBIDITY = "morbidity"
    HEALTH_SYSTEMS = "health_systems"
    RISK_FACTORS = "risk_factors"
    ENVIRONMENTAL = "environmental"
    DEMOGRAPHICS = "demographics"


# ==================== DATA CLASSES ====================

@dataclass
class WHOIndicator:
    """WHO GHO indicator metadata"""
    code: str
    display: str
    category: Optional[WHOIndicatorCategory] = None
    language: str = "en"
    url: Optional[str] = None


@dataclass
class WHODataPoint:
    """Single WHO data point"""
    indicator: str
    country: str
    country_code: str
    year: int
    value: float
    sex: Optional[str] = None
    age_group: Optional[str] = None
    dimensions: Dict[str, str] = field(default_factory=dict)
    low: Optional[float] = None  # Lower bound
    high: Optional[float] = None  # Upper bound
    comments: Optional[str] = None


@dataclass
class WHODataset:
    """Complete WHO dataset"""
    indicator: WHOIndicator
    data_points: List[WHODataPoint]
    metadata: Dict[str, Any] = field(default_factory=dict)
    fetch_timestamp: datetime = field(default_factory=datetime.now)

    def to_dataframe(self) -> pd.DataFrame:
        """Convert to pandas DataFrame"""
        if not self.data_points:
            return pd.DataFrame()

        records = []
        for dp in self.data_points:
            record = {
                "indicator": dp.indicator,
                "country": dp.country,
                "country_code": dp.country_code,
                "year": dp.year,
                "value": dp.value,
                "sex": dp.sex,
                "age_group": dp.age_group,
                "low": dp.low,
                "high": dp.high,
                "comments": dp.comments
            }
            # Add dimension columns
            for dim_key, dim_value in dp.dimensions.items():
                record[f"dim_{dim_key}"] = dim_value

            records.append(record)

        return pd.DataFrame(records)


@dataclass
class WHOFetchConfig:
    """Configuration for WHO API fetcher"""
    base_url: str = "https://ghoapi.azureedge.net/api"
    timeout: int = 30
    max_retries: int = 3
    retry_delay: float = 1.0
    rate_limit_delay: float = 0.5  # Delay between requests


# ==================== WHO GHO API FETCHER ====================

class WHOGHOFetcher:
    """
    WHO Global Health Observatory API Fetcher

    Fetches health data from WHO GHO OData API.

    Example indicators:
    - WHOSIS_000001: Life expectancy at birth
    - MDG_0000000001: Infant mortality rate
    - MDG_0000000026: Under-five mortality rate
    - NCD_BMI_30A: Obesity prevalence
    - SA_0000001688: Universal health coverage

    Value: £30k (essential for global health research)
    """

    def __init__(self, config: Optional[WHOFetchConfig] = None):
        """
        Initialize WHO GHO fetcher

        Args:
            config: Fetch configuration
        """
        self.config = config or WHOFetchConfig()
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "EvidenceOS-PRIME/1.0",
            "Accept": "application/json"
        })

    def list_indicators(
        self,
        category: Optional[WHOIndicatorCategory] = None,
        search_term: Optional[str] = None
    ) -> List[WHOIndicator]:
        """
        List available WHO GHO indicators

        Args:
            category: Filter by category
            search_term: Search in indicator names

        Returns:
            List of available indicators
        """
        url = f"{self.config.base_url}/Indicator"

        try:
            response = self._make_request(url)
            data = response.json()

            indicators = []
            for item in data.get("value", []):
                indicator = WHOIndicator(
                    code=item.get("IndicatorCode", ""),
                    display=item.get("IndicatorName", ""),
                    url=item.get("IndicatorUrl")
                )

                # Filter by search term
                if search_term and search_term.lower() not in indicator.display.lower():
                    continue

                indicators.append(indicator)

            logger.info(f"Found {len(indicators)} WHO indicators")
            return indicators

        except Exception as e:
            logger.error(f"Failed to list WHO indicators: {e}")
            return []

    def fetch_indicator_data(
        self,
        indicator_code: str,
        countries: Optional[List[str]] = None,
        years: Optional[List[int]] = None,
        sex: Optional[str] = None
    ) -> WHODataset:
        """
        Fetch data for a specific WHO indicator

        Args:
            indicator_code: WHO indicator code (e.g., "WHOSIS_000001")
            countries: List of ISO3 country codes (None = all countries)
            years: List of years (None = all available years)
            sex: Filter by sex ("MALE", "FEMALE", "BTSX" for both)

        Returns:
            WHODataset with indicator data
        """
        logger.info(f"Fetching WHO indicator: {indicator_code}")

        # Build OData filter
        filters = []
        if countries:
            country_filter = " or ".join([f"SpatialDim eq '{c}'" for c in countries])
            filters.append(f"({country_filter})")
        if years:
            year_filter = " or ".join([f"TimeDim eq {y}" for y in years])
            filters.append(f"({year_filter})")
        if sex:
            filters.append(f"Dim1 eq '{sex}'")

        filter_str = " and ".join(filters) if filters else ""

        url = f"{self.config.base_url}/{indicator_code}"
        if filter_str:
            url += f"?$filter={filter_str}"

        try:
            response = self._make_request(url)
            data = response.json()

            # Parse data points
            data_points = []
            for item in data.get("value", []):
                try:
                    data_point = self._parse_data_point(item, indicator_code)
                    if data_point:
                        data_points.append(data_point)
                except Exception as e:
                    logger.warning(f"Failed to parse data point: {e}")
                    continue

            # Get indicator metadata
            indicator_meta = WHOIndicator(
                code=indicator_code,
                display=data.get("@odata.context", indicator_code)
            )

            dataset = WHODataset(
                indicator=indicator_meta,
                data_points=data_points,
                metadata={"total_records": len(data_points)}
            )

            logger.info(f"Fetched {len(data_points)} data points for {indicator_code}")
            return dataset

        except Exception as e:
            logger.error(f"Failed to fetch WHO indicator {indicator_code}: {e}")
            return WHODataset(
                indicator=WHOIndicator(code=indicator_code, display=indicator_code),
                data_points=[]
            )

    def fetch_multiple_indicators(
        self,
        indicator_codes: List[str],
        countries: Optional[List[str]] = None,
        years: Optional[List[int]] = None
    ) -> Dict[str, WHODataset]:
        """
        Fetch multiple indicators at once

        Args:
            indicator_codes: List of WHO indicator codes
            countries: Filter by countries
            years: Filter by years

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
        years: Optional[List[int]] = None
    ) -> pd.DataFrame:
        """
        Fetch comprehensive country health profile

        Args:
            country_code: ISO3 country code
            indicator_codes: Specific indicators (None = default set)
            years: Years to fetch (None = most recent)

        Returns:
            DataFrame with country health indicators
        """
        # Default key indicators if not specified
        if indicator_codes is None:
            indicator_codes = [
                "WHOSIS_000001",  # Life expectancy
                "MDG_0000000001",  # Infant mortality
                "MDG_0000000026",  # Under-5 mortality
                "SA_0000001688",  # UHC coverage
                "NCD_BMI_30A",  # Obesity
                "M_Est_smk_curr_std",  # Smoking prevalence
            ]

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

    def _make_request(self, url: str) -> requests.Response:
        """
        Make HTTP request with retry logic

        Args:
            url: URL to request

        Returns:
            Response object

        Raises:
            requests.RequestException: If request fails
        """
        for attempt in range(self.config.max_retries):
            try:
                response = self.session.get(
                    url,
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

    def _parse_data_point(self, item: Dict[str, Any], indicator_code: str) -> Optional[WHODataPoint]:
        """
        Parse WHO API data point

        Args:
            item: Raw data item from API
            indicator_code: Indicator code

        Returns:
            Parsed WHODataPoint or None if invalid
        """
        try:
            # Extract core fields
            value = item.get("NumericValue")
            if value is None:
                return None

            year_str = item.get("TimeDim", "")
            year = int(year_str) if year_str.isdigit() else None
            if year is None:
                return None

            data_point = WHODataPoint(
                indicator=indicator_code,
                country=item.get("SpatialDim", ""),
                country_code=item.get("SpatialDim", ""),
                year=year,
                value=float(value),
                sex=item.get("Dim1"),
                age_group=item.get("Dim2"),
                low=item.get("Low"),
                high=item.get("High"),
                comments=item.get("Comments")
            )

            # Extract additional dimensions
            for key, val in item.items():
                if key.startswith("Dim"):
                    data_point.dimensions[key] = val

            return data_point

        except Exception as e:
            logger.warning(f"Failed to parse data point: {e}")
            return None


# ==================== EXAMPLE USAGE ====================

if __name__ == "__main__":
    print("=" * 60)
    print("WHO GHO API Fetcher Example")
    print("=" * 60)

    # Initialize fetcher
    fetcher = WHOGHOFetcher()

    # Example 1: List indicators
    print("\n1. Listing mortality indicators:")
    indicators = fetcher.list_indicators(search_term="mortality")
    for ind in indicators[:5]:
        print(f"  - {ind.code}: {ind.display}")

    # Example 2: Fetch life expectancy data
    print("\n2. Fetching life expectancy data:")
    dataset = fetcher.fetch_indicator_data(
        indicator_code="WHOSIS_000001",  # Life expectancy
        countries=["USA", "GBR", "CHN"],
        years=[2015, 2016, 2017, 2018, 2019, 2020]
    )

    df = dataset.to_dataframe()
    if not df.empty:
        print(f"  Fetched {len(df)} records")
        print(df.head())

    # Example 3: Fetch country profile
    print("\n3. Fetching UK health profile:")
    uk_profile = fetcher.fetch_country_profile(
        country_code="GBR",
        years=[2019, 2020]
    )

    if not uk_profile.empty:
        print(f"  UK profile has {len(uk_profile)} indicators")
        print(uk_profile.groupby("indicator")["value"].mean())

    print("\n✓ WHO GHO Fetcher Complete")
    print("  Value: £30k (essential global health data)")
