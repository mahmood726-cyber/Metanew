"""
Data validation module for EvidenceOS PRIME
Validates and normalizes input data tables
"""
import pandas as pd
import numpy as np
from typing import List, Dict, Any
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from schemas.evidence_object import ValidationResult, ValidationProblem


def validate_table(df: pd.DataFrame, data_type: str = "binary") -> ValidationResult:
    """
    Validate input data table and return problems

    Args:
        df: Input DataFrame
        data_type: Type of data - "binary", "continuous", or "tte" (time-to-event)

    Returns:
        ValidationResult with problems and normalized data
    """
    problems = []

    # Check if DataFrame is empty
    if df.empty:
        problems.append(ValidationProblem(
            severity="error",
            field="data",
            message="Input data is empty"
        ))
        return ValidationResult(
            is_valid=False,
            problems=problems,
            summary={"errors": 1, "warnings": 0, "info": 0}
        )

    # Required columns based on data type
    required_cols = {
        "binary": ["study_id", "treatment"],
        "continuous": ["study_id", "treatment"],
        "tte": ["study_id", "treatment"]
    }

    # Check required columns
    missing_cols = []
    for col in required_cols.get(data_type, []):
        if col not in df.columns:
            missing_cols.append(col)

    if missing_cols:
        problems.append(ValidationProblem(
            severity="error",
            field="columns",
            message=f"Missing required columns: {', '.join(missing_cols)}"
        ))

    # Validate based on data type
    if data_type == "binary":
        problems.extend(validate_binary_data(df))
    elif data_type == "continuous":
        problems.extend(validate_continuous_data(df))
    elif data_type == "tte":
        problems.extend(validate_tte_data(df))

    # Check for duplicate study_id + treatment combinations
    if "study_id" in df.columns and "treatment" in df.columns:
        duplicates = df.groupby(["study_id", "treatment"]).size()
        if (duplicates > 1).any():
            dup_pairs = duplicates[duplicates > 1]
            problems.append(ValidationProblem(
                severity="warning",
                field="study_id",
                message=f"Duplicate study-treatment combinations found: {len(dup_pairs)}"
            ))

    # Summary statistics
    summary = {
        "errors": sum(1 for p in problems if p.severity == "error"),
        "warnings": sum(1 for p in problems if p.severity == "warning"),
        "info": sum(1 for p in problems if p.severity == "info")
    }

    is_valid = summary["errors"] == 0

    return ValidationResult(
        is_valid=is_valid,
        problems=problems,
        summary=summary
    )


def validate_binary_data(df: pd.DataFrame) -> List[ValidationProblem]:
    """Validate binary outcome data (events/n or yi/sei)"""
    problems = []

    # Check if either raw data (events, n) or effect size (yi, sei) is present
    has_raw = "events" in df.columns and "n" in df.columns
    has_yi = "yi" in df.columns and "sei" in df.columns

    if not has_raw and not has_yi:
        problems.append(ValidationProblem(
            severity="error",
            field="data",
            message="Binary data requires either (events, n) or (yi, sei) columns"
        ))
        return problems

    # Validate raw data if present
    if has_raw:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")

            # Check events <= n
            if pd.notna(row.get("events")) and pd.notna(row.get("n")):
                if row["events"] > row["n"]:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="events",
                        message=f"Events ({row['events']}) > n ({row['n']})",
                        study_id=str(study_id)
                    ))

                # Check for zero cells
                if row["events"] == 0 or row["events"] == row["n"]:
                    problems.append(ValidationProblem(
                        severity="info",
                        field="events",
                        message="Zero cell detected - continuity correction may be applied",
                        study_id=str(study_id)
                    ))

    # Validate effect size data if present
    if has_yi:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")

            if pd.notna(row.get("sei")):
                if row["sei"] <= 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="sei",
                        message=f"Standard error must be positive, got {row['sei']}",
                        study_id=str(study_id)
                    ))

    return problems


def validate_continuous_data(df: pd.DataFrame) -> List[ValidationProblem]:
    """Validate continuous outcome data (mean/sd/n or yi/sei)"""
    problems = []

    has_raw = all(col in df.columns for col in ["mean", "sd", "n"])
    has_yi = "yi" in df.columns and "sei" in df.columns

    if not has_raw and not has_yi:
        problems.append(ValidationProblem(
            severity="error",
            field="data",
            message="Continuous data requires either (mean, sd, n) or (yi, sei) columns"
        ))
        return problems

    if has_raw:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")

            # Check SD is positive
            if pd.notna(row.get("sd")):
                if row["sd"] <= 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="sd",
                        message=f"Standard deviation must be positive, got {row['sd']}",
                        study_id=str(study_id)
                    ))

            # Check n is positive integer
            if pd.notna(row.get("n")):
                if row["n"] <= 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="n",
                        message=f"Sample size must be positive, got {row['n']}",
                        study_id=str(study_id)
                    ))

    return problems


def validate_tte_data(df: pd.DataFrame) -> List[ValidationProblem]:
    """Validate time-to-event data (HR, CI, or yi/sei)"""
    problems = []

    has_hr = "hr" in df.columns
    has_ci = "ci_lower" in df.columns and "ci_upper" in df.columns
    has_yi = "yi" in df.columns and "sei" in df.columns

    if not has_hr and not has_yi:
        problems.append(ValidationProblem(
            severity="error",
            field="data",
            message="Time-to-event data requires hr or yi column"
        ))
        return problems

    if has_hr:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")

            # Check HR is positive
            if pd.notna(row.get("hr")):
                if row["hr"] <= 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="hr",
                        message=f"Hazard ratio must be positive, got {row['hr']}",
                        study_id=str(study_id)
                    ))

            # Check CI bounds if present
            if has_ci and pd.notna(row.get("ci_lower")) and pd.notna(row.get("ci_upper")):
                if row["ci_lower"] >= row["ci_upper"]:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="ci",
                        message=f"CI lower ({row['ci_lower']}) >= upper ({row['ci_upper']})",
                        study_id=str(study_id)
                    ))

    return problems


def normalize_column_names(df: pd.DataFrame) -> pd.DataFrame:
    """
    Normalize column names to standard format
    Handles common variations and typos
    """
    column_mapping = {
        "studyid": "study_id",
        "study": "study_id",
        "id": "study_id",
        "arm": "treatment",
        "trt": "treatment",
        "group": "treatment",
        "n_events": "events",
        "r": "events",
        "n_total": "n",
        "total": "n",
        "sample_size": "n",
        "std": "sd",
        "stderr": "sei",
        "se": "sei",
        "effect": "yi",
        "estimate": "yi"
    }

    df_normalized = df.copy()
    df_normalized.columns = [column_mapping.get(col.lower(), col) for col in df.columns]

    return df_normalized
