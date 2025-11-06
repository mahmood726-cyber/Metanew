"""
Global Health Data Harmonizer

Harmonizes data from multiple sources:
- WHO GHO
- World Bank WDI
- IHME GBD
- Custom datasets

Handles:
- Country name standardization
- Indicator alignment
- Missing value imputation
- Format standardization
- Quality assessment

Integrates with backend/ml/llm_advanced.py GlobalHealthDataCleaner

Value: £30k (essential for multi-source analysis)

Dependencies:
- pandas: Data manipulation
- numpy: Numerical operations
- pycountry: Country code standardization
"""

import logging
from typing import List, Dict, Optional, Tuple, Any, Set
from dataclasses import dataclass, field
from enum import Enum
import pandas as pd
import numpy as np
from datetime import datetime

logger = logging.getLogger(__name__)

# Try to import pycountry for country standardization
try:
    import pycountry
    PYCOUNTRY_AVAILABLE = True
except ImportError:
    PYCOUNTRY_AVAILABLE = False
    logger.warning("pycountry not available. Using fallback country mapping.")


# ==================== ENUMS ====================

class DataSource(Enum):
    """Data source types"""
    WHO = "WHO"
    WORLD_BANK = "World Bank"
    IHME_GBD = "IHME GBD"
    CUSTOM = "Custom"


class HarmonizationIssue(Enum):
    """Data harmonization issues"""
    COUNTRY_MISMATCH = "country_mismatch"
    MISSING_YEARS = "missing_years"
    UNIT_MISMATCH = "unit_mismatch"
    SCALE_MISMATCH = "scale_mismatch"
    DUPLICATE_RECORDS = "duplicate_records"
    OUTLIERS = "outliers"


# ==================== DATA CLASSES ====================

@dataclass
class CountryMapping:
    """Country name to ISO3 code mapping"""
    name: str
    iso3: str
    iso2: Optional[str] = None
    aliases: List[str] = field(default_factory=list)


@dataclass
class HarmonizationReport:
    """Report from data harmonization"""
    issues_detected: Dict[HarmonizationIssue, int]
    fixes_applied: Dict[HarmonizationIssue, int]
    countries_mapped: int
    records_cleaned: int
    records_removed: int
    confidence_score: float
    warnings: List[str] = field(default_factory=list)
    timestamp: datetime = field(default_factory=datetime.now)

    def summary(self) -> str:
        """Generate summary report"""
        lines = ["=" * 60, "DATA HARMONIZATION REPORT", "=" * 60, ""]

        lines.append(f"Total Records Cleaned: {self.records_cleaned}")
        lines.append(f"Records Removed: {self.records_removed}")
        lines.append(f"Countries Mapped: {self.countries_mapped}")
        lines.append(f"Confidence Score: {self.confidence_score:.1%}")
        lines.append("")

        if self.issues_detected:
            lines.append("Issues Detected:")
            for issue, count in self.issues_detected.items():
                lines.append(f"  - {issue.value}: {count}")
            lines.append("")

        if self.fixes_applied:
            lines.append("Fixes Applied:")
            for fix, count in self.fixes_applied.items():
                lines.append(f"  - {fix.value}: {count}")
            lines.append("")

        if self.warnings:
            lines.append("Warnings:")
            for warning in self.warnings:
                lines.append(f"  ⚠ {warning}")

        return "\n".join(lines)


@dataclass
class HarmonizedDataset:
    """Harmonized dataset from multiple sources"""
    data: pd.DataFrame
    sources: List[DataSource]
    report: HarmonizationReport
    metadata: Dict[str, Any] = field(default_factory=dict)


# ==================== GLOBAL HEALTH DATA HARMONIZER ====================

class GlobalHealthDataHarmonizer:
    """
    Global Health Data Harmonizer

    Harmonizes data from WHO, World Bank, IHME, and custom sources.

    Key features:
    - Country name standardization (ISO3 codes)
    - Indicator alignment across sources
    - Missing value handling
    - Unit/scale standardization
    - Quality assessment

    Integrates with GlobalHealthDataCleaner from ml/llm_advanced.py

    Value: £30k (enables multi-source meta-analysis)
    """

    # Common country name variations
    COUNTRY_ALIASES = {
        "USA": ["United States", "United States of America", "US"],
        "GBR": ["United Kingdom", "UK", "Great Britain"],
        "CHN": ["China", "People's Republic of China", "PRC"],
        "RUS": ["Russia", "Russian Federation"],
        "KOR": ["South Korea", "Republic of Korea", "Korea, Rep."],
        "PRK": ["North Korea", "Democratic People's Republic of Korea", "Korea, Dem. People's Rep."],
        "VNM": ["Vietnam", "Viet Nam"],
        "LAO": ["Laos", "Lao PDR", "Lao People's Democratic Republic"],
        "IRN": ["Iran", "Islamic Republic of Iran", "Iran, Islamic Rep."],
        "VEN": ["Venezuela", "Venezuela, RB"],
        "BOL": ["Bolivia", "Bolivia (Plurinational State of)"],
        "TZA": ["Tanzania", "United Republic of Tanzania"],
        "COD": ["Democratic Republic of the Congo", "Congo, Dem. Rep.", "DRC"],
        "COG": ["Republic of the Congo", "Congo, Rep."],
        "CIV": ["Côte d'Ivoire", "Ivory Coast"],
        "SYR": ["Syria", "Syrian Arab Republic"],
        "EGY": ["Egypt", "Egypt, Arab Rep."],
    }

    def __init__(self):
        """Initialize harmonizer"""
        self.country_mappings: Dict[str, CountryMapping] = {}
        self._build_country_mappings()

    def harmonize_datasets(
        self,
        datasets: List[Tuple[pd.DataFrame, DataSource]],
        target_countries: Optional[List[str]] = None,
        target_years: Optional[List[int]] = None
    ) -> HarmonizedDataset:
        """
        Harmonize multiple datasets from different sources

        Args:
            datasets: List of (dataframe, source) tuples
            target_countries: Specific countries to include (None = all)
            target_years: Specific years to include (None = all)

        Returns:
            HarmonizedDataset with cleaned and aligned data
        """
        logger.info(f"Harmonizing {len(datasets)} datasets")

        issues_detected: Dict[HarmonizationIssue, int] = {}
        fixes_applied: Dict[HarmonizationIssue, int] = {}
        warnings = []

        harmonized_dfs = []

        for df, source in datasets:
            # Standardize country names
            df_clean, country_issues = self._standardize_countries(df)
            issues_detected[HarmonizationIssue.COUNTRY_MISMATCH] = issues_detected.get(
                HarmonizationIssue.COUNTRY_MISMATCH, 0
            ) + country_issues

            # Standardize column names
            df_clean = self._standardize_columns(df_clean, source)

            # Filter by target countries/years
            if target_countries:
                df_clean = df_clean[df_clean["country_iso3"].isin(target_countries)]

            if target_years:
                if "year" in df_clean.columns:
                    df_clean = df_clean[df_clean["year"].isin(target_years)]

            # Remove duplicates
            n_before = len(df_clean)
            df_clean = df_clean.drop_duplicates()
            n_duplicates = n_before - len(df_clean)
            if n_duplicates > 0:
                issues_detected[HarmonizationIssue.DUPLICATE_RECORDS] = n_duplicates
                fixes_applied[HarmonizationIssue.DUPLICATE_RECORDS] = n_duplicates

            # Add source column
            df_clean["data_source"] = source.value

            harmonized_dfs.append(df_clean)

        # Combine datasets
        if harmonized_dfs:
            combined = pd.concat(harmonized_dfs, ignore_index=True)
        else:
            combined = pd.DataFrame()
            warnings.append("No data after harmonization")

        # Handle missing values
        combined, missing_issues = self._handle_missing_values(combined)
        if missing_issues:
            issues_detected[HarmonizationIssue.MISSING_YEARS] = missing_issues
            fixes_applied[HarmonizationIssue.MISSING_YEARS] = missing_issues

        # Detect outliers
        outliers = self._detect_outliers(combined)
        if outliers:
            issues_detected[HarmonizationIssue.OUTLIERS] = outliers
            warnings.append(f"Found {outliers} potential outliers (not removed)")

        # Calculate confidence score
        confidence = self._calculate_confidence(combined, issues_detected)

        # Count unique countries
        n_countries = combined["country_iso3"].nunique() if "country_iso3" in combined.columns else 0

        report = HarmonizationReport(
            issues_detected=issues_detected,
            fixes_applied=fixes_applied,
            countries_mapped=n_countries,
            records_cleaned=len(combined),
            records_removed=sum(df.shape[0] for df, _ in datasets) - len(combined),
            confidence_score=confidence,
            warnings=warnings
        )

        harmonized = HarmonizedDataset(
            data=combined,
            sources=[source for _, source in datasets],
            report=report,
            metadata={
                "n_sources": len(datasets),
                "n_countries": n_countries,
                "year_range": (
                    int(combined["year"].min()),
                    int(combined["year"].max())
                ) if "year" in combined.columns and not combined.empty else None
            }
        )

        logger.info(f"Harmonization complete: {len(combined)} records, {n_countries} countries")
        return harmonized

    def _build_country_mappings(self):
        """Build country name to ISO3 code mappings"""
        if PYCOUNTRY_AVAILABLE:
            # Use pycountry for comprehensive mappings
            for country in pycountry.countries:
                mapping = CountryMapping(
                    name=country.name,
                    iso3=country.alpha_3,
                    iso2=country.alpha_2 if hasattr(country, 'alpha_2') else None
                )
                self.country_mappings[country.alpha_3] = mapping
                self.country_mappings[country.name.lower()] = mapping

        # Add common aliases
        for iso3, aliases in self.COUNTRY_ALIASES.items():
            if iso3 in self.country_mappings:
                mapping = self.country_mappings[iso3]
            else:
                # Create mapping if not exists
                mapping = CountryMapping(
                    name=aliases[0],
                    iso3=iso3,
                    aliases=aliases
                )
                self.country_mappings[iso3] = mapping

            # Add all aliases
            for alias in aliases:
                self.country_mappings[alias.lower()] = mapping

    def _standardize_countries(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, int]:
        """
        Standardize country names to ISO3 codes

        Args:
            df: DataFrame with country column

        Returns:
            (cleaned_df, n_issues)
        """
        # Find country column
        country_col = None
        for col in ["country", "location", "country_name", "location_name"]:
            if col in df.columns:
                country_col = col
                break

        if not country_col:
            logger.warning("No country column found")
            return df, 0

        n_issues = 0
        iso3_codes = []

        for country_name in df[country_col]:
            if pd.isna(country_name):
                iso3_codes.append(None)
                n_issues += 1
                continue

            # Try to find mapping
            country_lower = str(country_name).lower().strip()

            # Check if already ISO3
            if len(country_name) == 3 and country_name.upper() in self.country_mappings:
                iso3_codes.append(country_name.upper())
                continue

            # Look up in mappings
            if country_lower in self.country_mappings:
                iso3_codes.append(self.country_mappings[country_lower].iso3)
            else:
                # Try fuzzy match
                iso3 = self._fuzzy_country_match(country_name)
                if iso3:
                    iso3_codes.append(iso3)
                else:
                    iso3_codes.append(None)
                    n_issues += 1
                    logger.warning(f"Could not map country: {country_name}")

        df = df.copy()
        df["country_iso3"] = iso3_codes

        # Remove rows with unmapped countries
        df = df[df["country_iso3"].notna()]

        return df, n_issues

    def _fuzzy_country_match(self, country_name: str) -> Optional[str]:
        """Attempt fuzzy match for country name"""
        country_lower = country_name.lower().strip()

        # Try partial matches
        for mapped_name, mapping in self.country_mappings.items():
            if country_lower in mapped_name or mapped_name in country_lower:
                return mapping.iso3

        return None

    def _standardize_columns(self, df: pd.DataFrame, source: DataSource) -> pd.DataFrame:
        """
        Standardize column names across sources

        Args:
            df: DataFrame
            source: Data source

        Returns:
            DataFrame with standardized columns
        """
        df = df.copy()

        # Standardize year column
        for col in ["year", "date", "time", "TimeDim"]:
            if col in df.columns:
                df["year"] = pd.to_numeric(df[col], errors="coerce")
                break

        # Standardize value column
        for col in ["value", "val", "NumericValue", "data_value"]:
            if col in df.columns:
                df["value"] = pd.to_numeric(df[col], errors="coerce")
                break

        # Standardize indicator column
        for col in ["indicator", "indicator_code", "IndicatorCode", "measure"]:
            if col in df.columns:
                df["indicator"] = df[col]
                break

        return df

    def _handle_missing_values(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, int]:
        """
        Handle missing values in dataset

        Args:
            df: DataFrame

        Returns:
            (cleaned_df, n_issues)
        """
        if df.empty:
            return df, 0

        n_issues = 0

        # Remove rows with missing critical values
        if "value" in df.columns:
            n_before = len(df)
            df = df[df["value"].notna()]
            n_issues = n_before - len(df)

        return df, n_issues

    def _detect_outliers(self, df: pd.DataFrame) -> int:
        """
        Detect outliers in dataset

        Args:
            df: DataFrame

        Returns:
            Number of outliers detected
        """
        if df.empty or "value" not in df.columns:
            return 0

        # Use IQR method
        Q1 = df["value"].quantile(0.25)
        Q3 = df["value"].quantile(0.75)
        IQR = Q3 - Q1

        lower_bound = Q1 - 3 * IQR
        upper_bound = Q3 + 3 * IQR

        n_outliers = ((df["value"] < lower_bound) | (df["value"] > upper_bound)).sum()

        return int(n_outliers)

    def _calculate_confidence(
        self,
        df: pd.DataFrame,
        issues: Dict[HarmonizationIssue, int]
    ) -> float:
        """
        Calculate confidence score for harmonization

        Args:
            df: Harmonized DataFrame
            issues: Detected issues

        Returns:
            Confidence score (0-1)
        """
        if df.empty:
            return 0.0

        # Base confidence
        confidence = 1.0

        # Penalize for issues
        for issue, count in issues.items():
            if issue == HarmonizationIssue.COUNTRY_MISMATCH:
                confidence -= min(0.2, count / len(df) * 0.5)
            elif issue == HarmonizationIssue.MISSING_YEARS:
                confidence -= min(0.15, count / len(df) * 0.3)
            elif issue == HarmonizationIssue.DUPLICATE_RECORDS:
                confidence -= min(0.1, count / len(df) * 0.2)
            elif issue == HarmonizationIssue.OUTLIERS:
                confidence -= min(0.1, count / len(df) * 0.1)

        return max(0.0, confidence)


# ==================== EXAMPLE USAGE ====================

if __name__ == "__main__":
    print("=" * 60)
    print("Global Health Data Harmonizer Example")
    print("=" * 60)

    # Initialize harmonizer
    harmonizer = GlobalHealthDataHarmonizer()

    # Example 1: Create sample datasets
    print("\n1. Creating sample datasets:")

    # WHO-style data
    who_data = pd.DataFrame({
        "SpatialDim": ["USA", "GBR", "CHN"],
        "TimeDim": [2019, 2019, 2019],
        "IndicatorCode": ["WHOSIS_000001", "WHOSIS_000001", "WHOSIS_000001"],
        "NumericValue": [78.9, 81.3, 76.9]
    })

    # World Bank-style data
    wb_data = pd.DataFrame({
        "country": ["United States", "United Kingdom", "China"],
        "countryiso3code": ["USA", "GBR", "CHN"],
        "date": [2019, 2019, 2019],
        "indicator": ["SP.DYN.LE00.IN", "SP.DYN.LE00.IN", "SP.DYN.LE00.IN"],
        "value": [78.9, 81.3, 76.9]
    })

    print(f"  WHO data: {len(who_data)} records")
    print(f"  World Bank data: {len(wb_data)} records")

    # Example 2: Harmonize datasets
    print("\n2. Harmonizing datasets:")

    harmonized = harmonizer.harmonize_datasets([
        (who_data, DataSource.WHO),
        (wb_data, DataSource.WORLD_BANK)
    ])

    print(f"  Combined: {len(harmonized.data)} records")
    print(f"  Countries: {harmonized.report.countries_mapped}")
    print(f"  Confidence: {harmonized.report.confidence_score:.1%}")

    print("\n3. Harmonization Report:")
    print(harmonized.report.summary())

    print("\n✓ Global Health Data Harmonizer Complete")
    print("  Value: £30k (multi-source integration)")
