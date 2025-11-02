"""
Data transformation module for EvidenceOS PRIME
Computes effect sizes from raw data
"""
import pandas as pd
import numpy as np
from typing import Dict, Any, Optional


def compute_effect_size(df: pd.DataFrame, measure: str = "OR") -> pd.DataFrame:
    """
    Compute effect sizes (yi, sei, vi) from raw data

    Args:
        df: Input DataFrame with raw data
        measure: Effect measure - "OR", "RR", "RD", "MD", "SMD", "HR"

    Returns:
        DataFrame with yi (effect size), sei (standard error), vi (variance)
    """
    df_result = df.copy()

    if measure in ["OR", "RR", "RD"]:
        df_result = compute_binary_effect_size(df_result, measure)
    elif measure in ["MD", "SMD"]:
        df_result = compute_continuous_effect_size(df_result, measure)
    elif measure == "HR":
        df_result = compute_hr_effect_size(df_result)
    else:
        raise ValueError(f"Unknown measure: {measure}")

    return df_result


def compute_binary_effect_size(df: pd.DataFrame, measure: str = "OR") -> pd.DataFrame:
    """
    Compute effect sizes for binary outcomes

    Requires columns: events, n (or events1, n1, events2, n2 for comparative)
    Adds: yi (log OR/RR/RD), sei, vi
    """
    df_result = df.copy()

    # Check if data is in arm-based or contrast-based format
    has_arm_data = "events" in df.columns and "n" in df.columns
    has_contrast_data = all(col in df.columns for col in ["events1", "n1", "events2", "n2"])

    if has_contrast_data:
        # Contrast-based data (2x2 table per row)
        df_result = compute_contrast_binary(df_result, measure)
    elif has_arm_data:
        # Arm-based data (need to pair arms within studies)
        df_result = compute_arm_binary(df_result, measure)
    else:
        # Try to work with existing yi/sei if present
        if "yi" not in df_result.columns or "sei" not in df_result.columns:
            raise ValueError("Binary data requires (events, n) or (events1, n1, events2, n2) or (yi, sei)")

    return df_result


def compute_contrast_binary(df: pd.DataFrame, measure: str = "OR") -> pd.DataFrame:
    """Compute effect sizes from contrast (2x2) data"""
    df_result = df.copy()

    events1 = df_result["events1"].values
    n1 = df_result["n1"].values
    events2 = df_result["events2"].values
    n2 = df_result["n2"].values

    # Apply continuity correction for zero cells
    zero_cells = (events1 == 0) | (events1 == n1) | (events2 == 0) | (events2 == n2)
    if zero_cells.any():
        events1 = events1 + 0.5 * zero_cells
        events2 = events2 + 0.5 * zero_cells
        n1 = n1 + 1.0 * zero_cells
        n2 = n2 + 1.0 * zero_cells

    if measure == "OR":
        # Log odds ratio
        or_value = (events1 / (n1 - events1)) / (events2 / (n2 - events2))
        yi = np.log(or_value)
        vi = 1/events1 + 1/(n1-events1) + 1/events2 + 1/(n2-events2)

    elif measure == "RR":
        # Log risk ratio
        p1 = events1 / n1
        p2 = events2 / n2
        yi = np.log(p1 / p2)
        vi = (1 - p1)/(events1) + (1 - p2)/(events2)

    elif measure == "RD":
        # Risk difference
        p1 = events1 / n1
        p2 = events2 / n2
        yi = p1 - p2
        vi = (p1 * (1 - p1))/n1 + (p2 * (1 - p2))/n2

    else:
        raise ValueError(f"Unknown binary measure: {measure}")

    df_result["yi"] = yi
    df_result["vi"] = vi
    df_result["sei"] = np.sqrt(vi)

    return df_result


def compute_arm_binary(df: pd.DataFrame, measure: str = "OR") -> pd.DataFrame:
    """
    Compute effect sizes from arm-based data
    Requires grouping by study_id and comparing treatment arms
    """
    # This is more complex - need to identify intervention vs control within each study
    # For now, require user to specify or use contrast format

    if "yi" in df.columns and "sei" in df.columns:
        # Already has effect sizes
        if "vi" not in df.columns:
            df["vi"] = df["sei"] ** 2
        return df

    raise ValueError(
        "Arm-based binary data not yet fully supported. "
        "Please provide data in contrast format (events1, n1, events2, n2) "
        "or pre-computed effect sizes (yi, sei)"
    )


def compute_continuous_effect_size(df: pd.DataFrame, measure: str = "MD") -> pd.DataFrame:
    """
    Compute effect sizes for continuous outcomes

    Requires: mean, sd, n (or mean1, sd1, n1, mean2, sd2, n2)
    """
    df_result = df.copy()

    has_contrast = all(col in df.columns for col in ["mean1", "sd1", "n1", "mean2", "sd2", "n2"])

    if not has_contrast:
        # Check if already has yi/sei
        if "yi" in df.columns and "sei" in df.columns:
            if "vi" not in df.columns:
                df_result["vi"] = df_result["sei"] ** 2
            return df_result
        else:
            raise ValueError("Continuous data requires (mean1, sd1, n1, mean2, sd2, n2) or (yi, sei)")

    mean1 = df_result["mean1"].values
    sd1 = df_result["sd1"].values
    n1 = df_result["n1"].values
    mean2 = df_result["mean2"].values
    sd2 = df_result["sd2"].values
    n2 = df_result["n2"].values

    if measure == "MD":
        # Mean difference
        yi = mean1 - mean2
        # Pooled variance
        vi = (sd1**2 / n1) + (sd2**2 / n2)

    elif measure == "SMD":
        # Standardized mean difference (Hedges' g)
        # Pooled SD
        pooled_sd = np.sqrt(((n1 - 1) * sd1**2 + (n2 - 1) * sd2**2) / (n1 + n2 - 2))
        yi = (mean1 - mean2) / pooled_sd

        # Hedges correction
        j = 1 - 3 / (4 * (n1 + n2 - 2) - 1)
        yi = yi * j

        # Variance
        vi = ((n1 + n2) / (n1 * n2)) + (yi**2 / (2 * (n1 + n2)))

    else:
        raise ValueError(f"Unknown continuous measure: {measure}")

    df_result["yi"] = yi
    df_result["vi"] = vi
    df_result["sei"] = np.sqrt(vi)

    return df_result


def compute_hr_effect_size(df: pd.DataFrame) -> pd.DataFrame:
    """
    Compute effect sizes for time-to-event (hazard ratio) data

    Requires: hr and (ci_lower, ci_upper) or sei
    """
    df_result = df.copy()

    if "yi" in df.columns and "sei" in df.columns:
        # Already has effect sizes
        if "vi" not in df.columns:
            df_result["vi"] = df_result["sei"] ** 2
        return df_result

    if "hr" not in df.columns:
        raise ValueError("Time-to-event data requires 'hr' column")

    # Log hazard ratio
    df_result["yi"] = np.log(df_result["hr"])

    # Compute SE from CI if available
    if "ci_lower" in df.columns and "ci_upper" in df.columns:
        log_ci_lower = np.log(df_result["ci_lower"])
        log_ci_upper = np.log(df_result["ci_upper"])
        # SE = (log(upper) - log(lower)) / (2 * 1.96)
        df_result["sei"] = (log_ci_upper - log_ci_lower) / 3.92
    elif "sei" not in df.columns:
        raise ValueError("HR data requires either (ci_lower, ci_upper) or sei")

    df_result["vi"] = df_result["sei"] ** 2

    return df_result


def escalc_wrapper(df: pd.DataFrame, measure: str, **kwargs) -> pd.DataFrame:
    """
    Wrapper function that mimics metafor::escalc behavior
    For compatibility with R code expectations
    """
    return compute_effect_size(df, measure=measure)


def apply_continuity_correction(events: np.ndarray, n: np.ndarray, correction: float = 0.5) -> tuple:
    """
    Apply continuity correction to handle zero cells

    Args:
        events: Event counts
        n: Sample sizes
        correction: Correction value (default 0.5)

    Returns:
        Corrected events and n
    """
    zero_cells = (events == 0) | (events == n)
    events_corrected = events + correction * zero_cells
    n_corrected = n + (2 * correction) * zero_cells

    return events_corrected, n_corrected
