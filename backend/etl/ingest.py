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


def parse_distiller_export(file_path: str, data_level: str = "extraction") -> pd.DataFrame:
    """
    Parse DistillerSR export file

    DistillerSR exports data in specific formats:
    - CSV exports have metadata rows at the top
    - Column headers include form/question structure
    - Multiple levels: study level, extraction level, quality assessment

    Args:
        file_path: Path to DistillerSR CSV export
        data_level: Type of export - "extraction", "quality", "screening"

    Returns:
        Cleaned DataFrame with normalized column names
    """
    # DistillerSR CSVs typically have metadata rows before data
    # Read first few rows to detect structure
    with open(file_path, 'r', encoding='utf-8') as f:
        first_lines = [f.readline() for _ in range(10)]

    # Find where actual data starts (look for "RefID" or "Study ID" column)
    header_row = 0
    for i, line in enumerate(first_lines):
        if 'RefID' in line or 'Study ID' in line or 'Reference' in line:
            header_row = i
            break

    # Read CSV starting from detected header
    df = pd.read_csv(file_path, skiprows=header_row, encoding='utf-8')

    # Clean column names
    df.columns = df.columns.str.strip()

    # DistillerSR uses nested column structure like: "Form Name -> Question"
    # Simplify these column names
    df.columns = [_simplify_distiller_column(col) for col in df.columns]

    # Map common DistillerSR columns to standard names
    column_mapping = {
        'RefID': 'study_id',
        'Reference': 'study_id',
        'Study ID': 'study_id',
        'Author': 'author',
        'Year': 'year',
        'Title': 'title',
        'Journal': 'journal',
        'DOI': 'doi',
        'PMID': 'pmid',
        'Study Design': 'design',
        'Risk of Bias': 'risk_of_bias',
        'Overall ROB': 'risk_of_bias'
    }

    # Rename columns
    for old_name, new_name in column_mapping.items():
        if old_name in df.columns:
            df.rename(columns={old_name: new_name}, inplace=True)

    # Remove completely empty rows (DistillerSR exports often have blank rows)
    df = df.dropna(how='all')

    # Remove metadata columns (columns starting with underscore or "Level")
    df = df[[col for col in df.columns if not col.startswith('_') and not col.startswith('Level')]]

    return df


def _simplify_distiller_column(column_name: str) -> str:
    """
    Simplify DistillerSR nested column names

    DistillerSR exports columns like:
    "Extraction Form -> Intervention Details -> Drug Name"

    This simplifies to: "Drug Name" or "Intervention_Drug_Name"

    Args:
        column_name: Original DistillerSR column name

    Returns:
        Simplified column name
    """
    # If no arrow separator, return as-is
    if '->' not in column_name:
        return column_name

    # Split by arrow and take meaningful parts
    parts = [p.strip() for p in column_name.split('->')]

    # Skip generic form names
    skip_terms = ['Extraction Form', 'Quality Assessment', 'Data Extraction', 'Form']
    parts = [p for p in parts if p not in skip_terms]

    # If only one part remains, use it
    if len(parts) == 1:
        return parts[0]

    # Otherwise join with underscore
    return '_'.join(parts).replace(' ', '_')


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
