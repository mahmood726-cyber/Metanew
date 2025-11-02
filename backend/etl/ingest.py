"""
Data ingestion module for EvidenceOS PRIME
Handles CSV/Excel file imports and parsing
"""
import pandas as pd
from typing import Optional, Dict, Any
import os


def read_data_file(file_path: str, **kwargs) -> pd.DataFrame:
    """
    Read data from CSV or Excel file

    Args:
        file_path: Path to data file
        **kwargs: Additional arguments for pandas readers

    Returns:
        DataFrame with imported data
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")

    file_ext = os.path.splitext(file_path)[1].lower()

    if file_ext == ".csv":
        df = pd.read_csv(file_path, **kwargs)
    elif file_ext in [".xls", ".xlsx"]:
        df = pd.read_excel(file_path, **kwargs)
    else:
        raise ValueError(f"Unsupported file format: {file_ext}")

    return df


def parse_revman_csv(file_path: str) -> pd.DataFrame:
    """
    Parse RevMan-exported CSV file
    Handles specific RevMan format quirks
    """
    # RevMan CSVs often have multiple header rows
    df = pd.read_csv(file_path, skiprows=1)

    # Clean column names
    df.columns = df.columns.str.strip()

    return df


def parse_distiller_export(file_path: str) -> pd.DataFrame:
    """
    Parse DistillerSR export file
    Future implementation for direct DistillerSR integration
    """
    # Placeholder - will be implemented based on DistillerSR API spec
    df = pd.read_csv(file_path)
    return df


def detect_data_format(df: pd.DataFrame) -> str:
    """
    Auto-detect data format (binary, continuous, or time-to-event)

    Returns:
        "binary", "continuous", or "tte"
    """
    columns = set(df.columns.str.lower())

    # Check for binary data indicators
    binary_indicators = {"events", "n", "r", "n_events"}
    if binary_indicators & columns:
        return "binary"

    # Check for continuous data indicators
    continuous_indicators = {"mean", "sd", "std"}
    if continuous_indicators & columns:
        return "continuous"

    # Check for time-to-event indicators
    tte_indicators = {"hr", "hazard", "loghr"}
    if tte_indicators & columns:
        return "tte"

    # Check if already has effect sizes
    if "yi" in columns and "sei" in columns:
        return "effect_size"

    return "unknown"


def ingest_and_prepare(
    file_path: str,
    data_type: Optional[str] = None,
    **kwargs
) -> Dict[str, Any]:
    """
    Complete ingestion and preparation pipeline

    Args:
        file_path: Path to data file
        data_type: Optional data type override
        **kwargs: Additional arguments

    Returns:
        Dictionary with data, metadata, and detected format
    """
    # Read file
    df = read_data_file(file_path, **kwargs)

    # Detect format if not specified
    if data_type is None:
        data_type = detect_data_format(df)

    # Basic cleaning
    df = df.dropna(how="all")  # Remove completely empty rows
    df = df.dropna(axis=1, how="all")  # Remove completely empty columns

    # Normalize column names
    from .validate import normalize_column_names
    df = normalize_column_names(df)

    result = {
        "data": df,
        "n_rows": len(df),
        "n_cols": len(df.columns),
        "columns": list(df.columns),
        "data_type": data_type,
        "file_path": file_path
    }

    return result
