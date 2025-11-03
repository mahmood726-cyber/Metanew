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

    # Enhanced duplicate detection
    if "study_id" in df.columns and "treatment" in df.columns:
        duplicates = df.groupby(["study_id", "treatment"]).size()
        if (duplicates > 1).any():
            dup_pairs = duplicates[duplicates > 1]
            # List specific duplicates
            for (study, treatment), count in dup_pairs.items():
                problems.append(ValidationProblem(
                    severity="error",
                    field="study_id",
                    message=f"Duplicate entry: study '{study}', treatment '{treatment}' appears {count} times",
                    study_id=str(study)
                ))

    # Check for implausible values
    problems.extend(check_implausible_values(df, data_type))

    # Check for outliers
    problems.extend(detect_outliers(df, data_type))

    # Check multi-arm trial consistency
    problems.extend(validate_multi_arm_trial(df))

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
            row_num = idx + 2  # +2 because Excel is 1-indexed and has header row

            # Check events <= n
            if pd.notna(row.get("events")) and pd.notna(row.get("n")):
                if row["events"] > row["n"]:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="events",
                        message=f"Row {row_num}, Study '{study_id}': Events ({row['events']}) exceeds sample size n ({row['n']}). Check your data entry.",
                        study_id=str(study_id)
                    ))

                # Check for negative values
                if row["events"] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="events",
                        message=f"Row {row_num}, Study '{study_id}': Events cannot be negative (got {row['events']}). Use non-negative integers only.",
                        study_id=str(study_id)
                    ))

                if row["n"] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="n",
                        message=f"Row {row_num}, Study '{study_id}': Sample size n cannot be negative (got {row['n']}). Use positive integers only.",
                        study_id=str(study_id)
                    ))

                # Check for zero cells
                if row["events"] == 0 or row["events"] == row["n"]:
                    problems.append(ValidationProblem(
                        severity="info",
                        field="events",
                        message=f"Row {row_num}, Study '{study_id}': Zero cell detected (events={row['events']}, n={row['n']}). Continuity correction (+0.5) will be applied automatically.",
                        study_id=str(study_id)
                    ))

    # Validate effect size data if present
    if has_yi:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")
            row_num = idx + 2

            if pd.notna(row.get("sei")):
                if row["sei"] <= 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="sei",
                        message=f"Row {row_num}, Study '{study_id}': Standard error (sei) must be positive (got {row['sei']}). Check your calculations.",
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
            message="Continuous data requires either (mean, sd, n) or (yi, sei) columns. Please include columns: mean, sd, n OR yi, sei."
        ))
        return problems

    if has_raw:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")
            row_num = idx + 2  # +2 because Excel is 1-indexed and has header row

            # Check SD is positive
            if pd.notna(row.get("sd")):
                if row["sd"] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="sd",
                        message=f"Row {row_num}, Study '{study_id}': Standard deviation (sd) cannot be negative (got {row['sd']}). Check your data entry.",
                        study_id=str(study_id)
                    ))
                elif row["sd"] == 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="sd",
                        message=f"Row {row_num}, Study '{study_id}': Standard deviation (sd) cannot be zero (got {row['sd']}). SD must be positive.",
                        study_id=str(study_id)
                    ))

            # Check n is positive integer
            if pd.notna(row.get("n")):
                if row["n"] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="n",
                        message=f"Row {row_num}, Study '{study_id}': Sample size (n) cannot be negative (got {row['n']}). Use positive integers only.",
                        study_id=str(study_id)
                    ))
                elif row["n"] == 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="n",
                        message=f"Row {row_num}, Study '{study_id}': Sample size (n) cannot be zero (got {row['n']}). N must be at least 1.",
                        study_id=str(study_id)
                    ))

    # Validate effect size data if present
    if has_yi:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")
            row_num = idx + 2

            if pd.notna(row.get("sei")):
                if row["sei"] <= 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="sei",
                        message=f"Row {row_num}, Study '{study_id}': Standard error (sei) must be positive (got {row['sei']}). Check your calculations.",
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
            message="Time-to-event data requires either 'hr' (hazard ratio) or 'yi' (log hazard ratio) column. Please include hr column OR yi and sei columns."
        ))
        return problems

    if has_hr:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")
            row_num = idx + 2  # +2 because Excel is 1-indexed and has header row

            # Check HR is positive
            if pd.notna(row.get("hr")):
                if row["hr"] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="hr",
                        message=f"Row {row_num}, Study '{study_id}': Hazard ratio (hr) cannot be negative (got {row['hr']}). HR must be positive.",
                        study_id=str(study_id)
                    ))
                elif row["hr"] == 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="hr",
                        message=f"Row {row_num}, Study '{study_id}': Hazard ratio (hr) cannot be zero (got {row['hr']}). HR must be positive.",
                        study_id=str(study_id)
                    ))

            # Check CI bounds if present
            if has_ci and pd.notna(row.get("ci_lower")) and pd.notna(row.get("ci_upper")):
                if row["ci_lower"] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="ci_lower",
                        message=f"Row {row_num}, Study '{study_id}': Confidence interval lower bound cannot be negative (got {row['ci_lower']}).",
                        study_id=str(study_id)
                    ))
                if row["ci_upper"] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="ci_upper",
                        message=f"Row {row_num}, Study '{study_id}': Confidence interval upper bound cannot be negative (got {row['ci_upper']}).",
                        study_id=str(study_id)
                    ))
                if row["ci_lower"] >= row["ci_upper"]:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="ci",
                        message=f"Row {row_num}, Study '{study_id}': Confidence interval lower bound ({row['ci_lower']}) >= upper bound ({row['ci_upper']}). CI bounds are reversed or equal.",
                        study_id=str(study_id)
                    ))

    # Validate effect size data if present
    if has_yi:
        for idx, row in df.iterrows():
            study_id = row.get("study_id", f"row_{idx}")
            row_num = idx + 2

            if pd.notna(row.get("sei")):
                if row["sei"] <= 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field="sei",
                        message=f"Row {row_num}, Study '{study_id}': Standard error (sei) must be positive (got {row['sei']}). Check your calculations.",
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


def check_implausible_values(df: pd.DataFrame, data_type: str) -> List[ValidationProblem]:
    """
    Check for implausible values that may indicate data entry errors
    """
    problems = []

    for idx, row in df.iterrows():
        study_id = row.get("study_id", f"row_{idx}")
        row_num = idx + 2  # +2 because Excel is 1-indexed and has header row

        # Check effect sizes (log scale) - unlikely to be > |10|
        if "yi" in df.columns and pd.notna(row.get("yi")):
            if abs(row["yi"]) > 10:
                problems.append(ValidationProblem(
                    severity="warning",
                    field="yi",
                    message=f"Row {row_num}, Study '{study_id}': Extreme effect size ({row['yi']:.2f}). This may indicate a data entry error. Typical values are between -10 and 10.",
                    study_id=str(study_id)
                ))

        # Check standard errors - should be positive and reasonable
        if "sei" in df.columns and pd.notna(row.get("sei")):
            if row["sei"] > 10:
                problems.append(ValidationProblem(
                    severity="warning",
                    field="sei",
                    message=f"Row {row_num}, Study '{study_id}': Very large standard error ({row['sei']:.2f}). This suggests very high uncertainty or possible error.",
                    study_id=str(study_id)
                ))
            if row["sei"] < 0.001:
                problems.append(ValidationProblem(
                    severity="warning",
                    field="sei",
                    message=f"Row {row_num}, Study '{study_id}': Very small standard error ({row['sei']:.4f}). This suggests unusually high precision or possible error.",
                    study_id=str(study_id)
                ))

        # Check hazard ratios - should be positive and typically < 100
        if "hr" in df.columns and pd.notna(row.get("hr")):
            if row["hr"] > 100:
                problems.append(ValidationProblem(
                    severity="warning",
                    field="hr",
                    message=f"Row {row_num}, Study '{study_id}': Extreme hazard ratio ({row['hr']:.2f}). This may indicate a data entry error.",
                    study_id=str(study_id)
                ))

        # Check sample sizes - warn if very small (< 10 per arm)
        if "n" in df.columns and pd.notna(row.get("n")):
            if row["n"] < 10:
                problems.append(ValidationProblem(
                    severity="warning",
                    field="n",
                    message=f"Row {row_num}, Study '{study_id}': Small sample size (n={row['n']}). Results may have low precision.",
                    study_id=str(study_id)
                ))

        # Check event rates for binary data
        if data_type == "binary" and "events" in df.columns and "n" in df.columns:
            if pd.notna(row.get("events")) and pd.notna(row.get("n")) and row.get("n") > 0:
                event_rate = row["events"] / row["n"]
                if event_rate > 0.95:
                    problems.append(ValidationProblem(
                        severity="info",
                        field="events",
                        message=f"Row {row_num}, Study '{study_id}': Very high event rate ({event_rate*100:.1f}%). This is informational only.",
                        study_id=str(study_id)
                    ))

        # Check for negative values where they shouldn't be
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        for col in ["n", "events", "sd", "sei", "vi", "hr"]:
            if col in numeric_cols and pd.notna(row.get(col)):
                if row[col] < 0:
                    problems.append(ValidationProblem(
                        severity="error",
                        field=col,
                        message=f"Row {row_num}, Study '{study_id}': Column '{col}' cannot be negative (got {row[col]}). Please check your data.",
                        study_id=str(study_id)
                    ))

        # Check utilities if present (should be 0-1)
        for col in df.columns:
            if "utility" in col.lower() or "qol" in col.lower():
                if pd.notna(row.get(col)):
                    if row[col] < 0 or row[col] > 1:
                        problems.append(ValidationProblem(
                            severity="error",
                            field=col,
                            message=f"Row {row_num}, Study '{study_id}': Utility/QOL value must be between 0 and 1 (got {row[col]}). Please use values on 0-1 scale.",
                            study_id=str(study_id)
                        ))

    return problems


def detect_outliers(df: pd.DataFrame, data_type: str) -> List[ValidationProblem]:
    """
    Detect potential outliers using IQR method
    """
    problems = []

    # Only check if we have enough data points
    if len(df) < 5:
        return problems

    # Check effect sizes for outliers
    if "yi" in df.columns:
        yi_values = df["yi"].dropna()
        if len(yi_values) >= 5:
            Q1 = yi_values.quantile(0.25)
            Q3 = yi_values.quantile(0.75)
            IQR = Q3 - Q1
            lower_bound = Q1 - 3 * IQR  # Using 3*IQR for extreme outliers
            upper_bound = Q3 + 3 * IQR

            for idx, row in df.iterrows():
                if pd.notna(row.get("yi")):
                    study_id = row.get("study_id", f"row_{idx}")
                    row_num = idx + 2
                    if row["yi"] < lower_bound or row["yi"] > upper_bound:
                        problems.append(ValidationProblem(
                            severity="warning",
                            field="yi",
                            message=f"Row {row_num}, Study '{study_id}': Potential outlier detected. Effect size = {row['yi']:.3f} (outside 3×IQR bounds). Consider sensitivity analysis excluding this study.",
                            study_id=str(study_id)
                        ))

    # Check sample sizes for outliers
    if "n" in df.columns:
        n_values = df["n"].dropna()
        if len(n_values) >= 5:
            median_n = n_values.median()
            for idx, row in df.iterrows():
                if pd.notna(row.get("n")):
                    study_id = row.get("study_id", f"row_{idx}")
                    row_num = idx + 2
                    # Flag if sample size is > 10x or < 0.1x median
                    if row["n"] > median_n * 10:
                        problems.append(ValidationProblem(
                            severity="info",
                            field="n",
                            message=f"Row {row_num}, Study '{study_id}': Unusually large sample size (n={row['n']}, median={median_n:.0f}). This study may dominate the meta-analysis.",
                            study_id=str(study_id)
                        ))
                    elif row["n"] < median_n * 0.1 and row["n"] > 0:
                        problems.append(ValidationProblem(
                            severity="info",
                            field="n",
                            message=f"Row {row_num}, Study '{study_id}': Unusually small sample size (n={row['n']}, median={median_n:.0f}). This study will have low weight.",
                            study_id=str(study_id)
                        ))

    return problems


def validate_multi_arm_trial(df: pd.DataFrame) -> List[ValidationProblem]:
    """
    Validate multi-arm trials for consistency
    """
    problems = []

    if "study_id" not in df.columns or "treatment" not in df.columns:
        return problems

    # Identify multi-arm trials
    study_arm_counts = df.groupby("study_id").size()
    multi_arm_studies = study_arm_counts[study_arm_counts > 2].index.tolist()

    for study_id in multi_arm_studies:
        study_data = df[df["study_id"] == study_id]

        # Check if all arms have same outcome variable
        if "outcome" in df.columns:
            outcomes = study_data["outcome"].unique()
            if len(outcomes) > 1:
                problems.append(ValidationProblem(
                    severity="warning",
                    field="outcome",
                    message=f"Multi-arm trial has different outcomes: {', '.join(outcomes)}",
                    study_id=str(study_id)
                ))

        # Check for reasonable variance homogeneity
        if "sei" in df.columns:
            seis = study_data["sei"].dropna()
            if len(seis) > 1:
                sei_ratio = seis.max() / seis.min()
                if sei_ratio > 5:
                    problems.append(ValidationProblem(
                        severity="info",
                        field="sei",
                        message=f"Large variance heterogeneity across arms (ratio={sei_ratio:.1f})",
                        study_id=str(study_id)
                    ))

    return problems
