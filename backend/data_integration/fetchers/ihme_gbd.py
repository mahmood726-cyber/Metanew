"""
IHME Global Burden of Disease (GBD) Data Loader

Loads GBD data from IHME's GBD Results Tool downloads.
IHME GBD provides comprehensive estimates of:
- Disease burden (DALYs, YLLs, YLDs)
- Mortality
- Incidence and prevalence
- Risk factors

Data Source: https://vizhub.healthdata.org/gbd-results/

Note: IHME doesn't provide a public API, so this loader works with
downloaded CSV/XLSX files from the GBD Results Tool.

Value: £20k (authoritative disease burden data)

Dependencies:
- pandas: Data manipulation
- numpy: Numerical operations
"""

import logging
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
from pathlib import Path
import pandas as pd
import numpy as np

logger = logging.getLogger(__name__)


# ==================== ENUMS ====================

class GBDMeasure(Enum):
    """GBD measures"""
    DEATHS = "Deaths"
    DALYS = "DALYs"
    YLLS = "YLLs"
    YLDS = "YLDs"
    INCIDENCE = "Incidence"
    PREVALENCE = "Prevalence"


class GBDMetric(Enum):
    """GBD metrics"""
    NUMBER = "Number"
    RATE = "Rate"
    PERCENT = "Percent"


class GBDAge(Enum):
    """GBD age groups"""
    ALL_AGES = "All ages"
    AGE_STANDARDIZED = "Age-standardized"
    UNDER_5 = "Under 5"
    AGES_5_14 = "5-14 years"
    AGES_15_49 = "15-49 years"
    AGES_50_69 = "50-69 years"
    AGES_70_PLUS = "70+ years"


# ==================== DATA CLASSES ====================

@dataclass
class GBDDataPoint:
    """Single GBD data point"""
    measure: str
    location: str
    location_id: int
    sex: str
    age: str
    cause: str
    metric: str
    year: int
    val: float
    upper: Optional[float] = None
    lower: Optional[float] = None


@dataclass
class GBDDataset:
    """Complete GBD dataset"""
    measure: str
    data_points: List[GBDDataPoint]
    metadata: Dict[str, Any] = field(default_factory=dict)
    load_timestamp: datetime = field(default_factory=datetime.now)

    def to_dataframe(self) -> pd.DataFrame:
        """Convert to pandas DataFrame"""
        if not self.data_points:
            return pd.DataFrame()

        records = []
        for dp in self.data_points:
            records.append({
                "measure": dp.measure,
                "location": dp.location,
                "location_id": dp.location_id,
                "sex": dp.sex,
                "age": dp.age,
                "cause": dp.cause,
                "metric": dp.metric,
                "year": dp.year,
                "value": dp.val,
                "upper": dp.upper,
                "lower": dp.lower
            })

        return pd.DataFrame(records)


# ==================== IHME GBD DATA LOADER ====================

class IHMEGBDLoader:
    """
    IHME Global Burden of Disease Data Loader

    Loads GBD data from downloaded CSV/XLSX files from:
    https://vizhub.healthdata.org/gbd-results/

    IHME doesn't provide a public API, so users must:
    1. Visit GBD Results Tool
    2. Select measures, locations, years
    3. Download CSV/XLSX
    4. Load with this class

    Value: £20k (authoritative disease burden estimates)
    """

    # Standard column mappings for GBD downloads
    COLUMN_MAPPINGS = {
        "measure_name": "measure",
        "location_name": "location",
        "location_id": "location_id",
        "sex_name": "sex",
        "age_name": "age",
        "cause_name": "cause",
        "metric_name": "metric",
        "year": "year",
        "val": "val",
        "upper": "upper",
        "lower": "lower"
    }

    def __init__(self, data_dir: Optional[Path] = None):
        """
        Initialize IHME GBD loader

        Args:
            data_dir: Directory containing GBD download files
        """
        self.data_dir = data_dir or Path("./data/gbd")
        self.data_dir.mkdir(parents=True, exist_ok=True)

    def load_from_csv(
        self,
        file_path: Path,
        filters: Optional[Dict[str, Any]] = None
    ) -> GBDDataset:
        """
        Load GBD data from CSV file

        Args:
            file_path: Path to GBD CSV file
            filters: Optional filters (e.g., {"location": "United States"})

        Returns:
            GBDDataset with loaded data
        """
        logger.info(f"Loading GBD data from {file_path}")

        try:
            # Read CSV
            df = pd.read_csv(file_path)

            # Apply filters
            if filters:
                for col, value in filters.items():
                    if col in df.columns:
                        if isinstance(value, list):
                            df = df[df[col].isin(value)]
                        else:
                            df = df[df[col] == value]

            # Parse data points
            data_points = []
            for _, row in df.iterrows():
                try:
                    data_point = self._parse_row(row)
                    if data_point:
                        data_points.append(data_point)
                except Exception as e:
                    logger.warning(f"Failed to parse row: {e}")
                    continue

            # Get measure
            measure = df["measure_name"].iloc[0] if "measure_name" in df.columns else "Unknown"

            dataset = GBDDataset(
                measure=measure,
                data_points=data_points,
                metadata={
                    "source_file": str(file_path),
                    "total_records": len(data_points)
                }
            )

            logger.info(f"Loaded {len(data_points)} GBD data points")
            return dataset

        except Exception as e:
            logger.error(f"Failed to load GBD data from {file_path}: {e}")
            return GBDDataset(measure="Unknown", data_points=[])

    def load_from_excel(
        self,
        file_path: Path,
        sheet_name: Optional[str] = None,
        filters: Optional[Dict[str, Any]] = None
    ) -> GBDDataset:
        """
        Load GBD data from Excel file

        Args:
            file_path: Path to GBD Excel file
            sheet_name: Sheet name (None = first sheet)
            filters: Optional filters

        Returns:
            GBDDataset with loaded data
        """
        logger.info(f"Loading GBD data from {file_path}")

        try:
            # Read Excel
            df = pd.read_excel(file_path, sheet_name=sheet_name or 0)

            # Apply filters
            if filters:
                for col, value in filters.items():
                    if col in df.columns:
                        if isinstance(value, list):
                            df = df[df[col].isin(value)]
                        else:
                            df = df[df[col] == value]

            # Parse data points
            data_points = []
            for _, row in df.iterrows():
                try:
                    data_point = self._parse_row(row)
                    if data_point:
                        data_points.append(data_point)
                except Exception as e:
                    logger.warning(f"Failed to parse row: {e}")
                    continue

            # Get measure
            measure = df["measure_name"].iloc[0] if "measure_name" in df.columns else "Unknown"

            dataset = GBDDataset(
                measure=measure,
                data_points=data_points,
                metadata={
                    "source_file": str(file_path),
                    "total_records": len(data_points)
                }
            )

            logger.info(f"Loaded {len(data_points)} GBD data points")
            return dataset

        except Exception as e:
            logger.error(f"Failed to load GBD data from {file_path}: {e}")
            return GBDDataset(measure="Unknown", data_points=[])

    def load_multiple_files(
        self,
        file_paths: List[Path],
        filters: Optional[Dict[str, Any]] = None
    ) -> Dict[str, GBDDataset]:
        """
        Load multiple GBD files

        Args:
            file_paths: List of file paths
            filters: Optional filters

        Returns:
            Dict mapping file names to datasets
        """
        datasets = {}

        for file_path in file_paths:
            # Determine file type
            if file_path.suffix.lower() == ".csv":
                dataset = self.load_from_csv(file_path, filters)
            elif file_path.suffix.lower() in [".xlsx", ".xls"]:
                dataset = self.load_from_excel(file_path, filters=filters)
            else:
                logger.warning(f"Unsupported file type: {file_path}")
                continue

            datasets[file_path.name] = dataset

        return datasets

    def get_disease_burden(
        self,
        dataset: GBDDataset,
        location: str,
        cause: Optional[str] = None,
        year: Optional[int] = None
    ) -> pd.DataFrame:
        """
        Extract disease burden for specific location

        Args:
            dataset: GBD dataset
            location: Location name
            cause: Specific cause (None = all causes)
            year: Specific year (None = all years)

        Returns:
            DataFrame with disease burden data
        """
        df = dataset.to_dataframe()

        if df.empty:
            return df

        # Filter
        df = df[df["location"] == location]

        if cause:
            df = df[df["cause"] == cause]

        if year:
            df = df[df["year"] == year]

        return df

    def compare_locations(
        self,
        dataset: GBDDataset,
        locations: List[str],
        cause: str,
        year: int
    ) -> pd.DataFrame:
        """
        Compare disease burden across locations

        Args:
            dataset: GBD dataset
            locations: List of location names
            cause: Cause name
            year: Year

        Returns:
            DataFrame with comparison
        """
        df = dataset.to_dataframe()

        if df.empty:
            return df

        # Filter
        df = df[df["location"].isin(locations)]
        df = df[df["cause"] == cause]
        df = df[df["year"] == year]

        # Pivot for comparison
        comparison = df.pivot_table(
            index="location",
            columns="age",
            values="value",
            aggfunc="mean"
        )

        return comparison

    def calculate_summary_statistics(
        self,
        dataset: GBDDataset,
        group_by: List[str] = None
    ) -> pd.DataFrame:
        """
        Calculate summary statistics for GBD data

        Args:
            dataset: GBD dataset
            group_by: Columns to group by (default: ["location", "year"])

        Returns:
            DataFrame with summary statistics
        """
        df = dataset.to_dataframe()

        if df.empty:
            return df

        if group_by is None:
            group_by = ["location", "year"]

        # Calculate statistics
        summary = df.groupby(group_by).agg({
            "value": ["mean", "median", "min", "max", "std"],
            "upper": "mean",
            "lower": "mean"
        }).reset_index()

        return summary

    def _parse_row(self, row: pd.Series) -> Optional[GBDDataPoint]:
        """
        Parse a single row from GBD data

        Args:
            row: Row from DataFrame

        Returns:
            GBDDataPoint or None if invalid
        """
        try:
            # Map columns
            data = {}
            for gbd_col, std_col in self.COLUMN_MAPPINGS.items():
                if gbd_col in row.index:
                    data[std_col] = row[gbd_col]

            # Required fields
            required = ["measure", "location", "year", "val"]
            if not all(field in data for field in required):
                return None

            data_point = GBDDataPoint(
                measure=data["measure"],
                location=data["location"],
                location_id=int(data.get("location_id", 0)),
                sex=data.get("sex", "Both"),
                age=data.get("age", "All ages"),
                cause=data.get("cause", "All causes"),
                metric=data.get("metric", "Number"),
                year=int(data["year"]),
                val=float(data["val"]),
                upper=float(data["upper"]) if "upper" in data and pd.notna(data["upper"]) else None,
                lower=float(data["lower"]) if "lower" in data and pd.notna(data["lower"]) else None
            )

            return data_point

        except Exception as e:
            logger.warning(f"Failed to parse GBD row: {e}")
            return None


# ==================== EXAMPLE USAGE ====================

if __name__ == "__main__":
    print("=" * 60)
    print("IHME GBD Data Loader Example")
    print("=" * 60)

    # Initialize loader
    loader = IHMEGBDLoader()

    print("\n📋 IHME GBD Data Loader")
    print("To use this loader:")
    print("1. Visit https://vizhub.healthdata.org/gbd-results/")
    print("2. Select measures, locations, years, causes")
    print("3. Download CSV or Excel file")
    print("4. Load with this class")

    print("\nExample usage:")
    print("""
    # Load DALYs data
    dataset = loader.load_from_csv(
        file_path=Path("./data/gbd/IHME_GBD_2019_DALYS.csv"),
        filters={
            "location": ["United States", "United Kingdom"],
            "year": [2019, 2020]
        }
    )

    # Get disease burden for UK
    uk_burden = loader.get_disease_burden(
        dataset=dataset,
        location="United Kingdom",
        year=2019
    )

    # Compare countries
    comparison = loader.compare_locations(
        dataset=dataset,
        locations=["United States", "United Kingdom"],
        cause="Cardiovascular diseases",
        year=2019
    )
    """)

    print("\n✓ IHME GBD Loader Complete")
    print("  Value: £20k (authoritative disease burden data)")
    print("  Note: Requires manual download from GBD Results Tool")
