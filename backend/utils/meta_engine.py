"""
Core Meta-Analysis Engine (Rules-Based)
========================================

Pure statistical methods for meta-analysis with NO AI/LLM components.
Extracted from Mahmood789/Finalmetapython repository.

Implements:
- Effect size calculations (OR, RR, SMD, MD, HR)
- Heterogeneity estimation (τ², Q, I², H²)
- Pooling methods (fixed-effect, random-effects)
- Multiple τ² estimators (DerSimonian-Laird, REML)

All methods are deterministic and based on established statistical theory.
"""

import numpy as np
import pandas as pd
from scipy.stats import norm, chi2
from typing import Dict, Tuple, Optional, Union

# ============================================================
# EFFECT SIZE CALCULATORS
# ============================================================

def odds_ratio(events_t: np.ndarray, n_t: np.ndarray,
               events_c: np.ndarray, n_c: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """
    Calculate log odds ratio and standard error.

    Parameters
    ----------
    events_t : array-like
        Number of events in treatment group
    n_t : array-like
        Total sample size in treatment group
    events_c : array-like
        Number of events in control group
    n_c : array-like
        Total sample size in control group

    Returns
    -------
    log_or : ndarray
        Log odds ratio
    se : ndarray
        Standard error of log odds ratio

    Notes
    -----
    SE formula: sqrt(1/a + 1/b + 1/c + 1/d)
    where a=events_t, b=n_t-events_t, c=events_c, d=n_c-events_c
    """
    or_val = (events_t / (n_t - events_t)) / (events_c / (n_c - events_c))
    log_or = np.log(or_val)
    se = np.sqrt(1/events_t + 1/(n_t-events_t) + 1/events_c + 1/(n_c-events_c))
    return log_or, se


def risk_ratio(events_t: np.ndarray, n_t: np.ndarray,
               events_c: np.ndarray, n_c: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """
    Calculate log risk ratio (relative risk) and standard error.

    Parameters
    ----------
    events_t : array-like
        Number of events in treatment group
    n_t : array-like
        Total sample size in treatment group
    events_c : array-like
        Number of events in control group
    n_c : array-like
        Total sample size in control group

    Returns
    -------
    log_rr : ndarray
        Log risk ratio
    se : ndarray
        Standard error of log risk ratio

    Notes
    -----
    SE formula: sqrt(1/events_t - 1/n_t + 1/events_c - 1/n_c)
    """
    rr = (events_t/n_t) / (events_c/n_c)
    log_rr = np.log(rr)
    se = np.sqrt(1/events_t - 1/n_t + 1/events_c - 1/n_c)
    return log_rr, se


def mean_difference(mean_t: np.ndarray, sd_t: np.ndarray, n_t: np.ndarray,
                   mean_c: np.ndarray, sd_c: np.ndarray, n_c: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """
    Calculate mean difference (MD) and standard error.

    Parameters
    ----------
    mean_t : array-like
        Mean in treatment group
    sd_t : array-like
        Standard deviation in treatment group
    n_t : array-like
        Sample size in treatment group
    mean_c : array-like
        Mean in control group
    sd_c : array-like
        Standard deviation in control group
    n_c : array-like
        Sample size in control group

    Returns
    -------
    md : ndarray
        Mean difference
    se : ndarray
        Standard error of mean difference
    """
    md = mean_t - mean_c
    se = np.sqrt((sd_t**2)/n_t + (sd_c**2)/n_c)
    return md, se


def standardized_mean_difference(mean_t: np.ndarray, sd_t: np.ndarray, n_t: np.ndarray,
                                 mean_c: np.ndarray, sd_c: np.ndarray, n_c: np.ndarray,
                                 method: str = "cohens_d") -> Tuple[np.ndarray, np.ndarray]:
    """
    Calculate standardized mean difference (SMD) and standard error.

    Parameters
    ----------
    mean_t : array-like
        Mean in treatment group
    sd_t : array-like
        Standard deviation in treatment group
    n_t : array-like
        Sample size in treatment group
    mean_c : array-like
        Mean in control group
    sd_c : array-like
        Standard deviation in control group
    n_c : array-like
        Sample size in control group
    method : str
        SMD method: "cohens_d" (default) or "hedges_g"

    Returns
    -------
    smd : ndarray
        Standardized mean difference
    se : ndarray
        Standard error of SMD

    Notes
    -----
    Cohen's d uses pooled SD: sqrt(((n1-1)*sd1² + (n2-1)*sd2²) / (n1+n2-2))
    Hedges' g applies small-sample correction factor
    """
    # Pooled standard deviation
    s_p = np.sqrt(((n_t-1)*sd_t**2 + (n_c-1)*sd_c**2) / (n_t+n_c-2))
    d = (mean_t - mean_c) / s_p

    # Standard error
    se = np.sqrt((n_t+n_c)/(n_t*n_c) + d**2/(2*(n_t+n_c)))

    # Hedges' g correction for small samples
    if method == "hedges_g":
        j = 1 - (3 / (4*(n_t+n_c-2) - 1))  # Correction factor
        d = d * j
        se = se * j

    return d, se


def hazard_ratio_from_ci(hr: np.ndarray, ci_low: np.ndarray,
                         ci_high: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """
    Calculate log hazard ratio and SE from reported HR and 95% CI.

    Parameters
    ----------
    hr : array-like
        Hazard ratio
    ci_low : array-like
        Lower bound of 95% CI
    ci_high : array-like
        Upper bound of 95% CI

    Returns
    -------
    log_hr : ndarray
        Log hazard ratio
    se : ndarray
        Standard error of log HR

    Notes
    -----
    SE = (log(CI_high) - log(CI_low)) / (2 * 1.96)
    """
    log_hr = np.log(hr)
    se = (np.log(ci_high) - np.log(ci_low)) / (2*1.96)
    return log_hr, se


# ============================================================
# HETEROGENEITY ESTIMATORS
# ============================================================

def dersimonian_laird_tau2(yi: np.ndarray, vi: np.ndarray) -> Tuple[float, float, int]:
    """
    DerSimonian-Laird estimator for τ² (between-study variance).

    Parameters
    ----------
    yi : array-like
        Effect sizes
    vi : array-like
        Sampling variances

    Returns
    -------
    tau2 : float
        Between-study variance (τ²)
    Q : float
        Cochran's Q statistic
    df : int
        Degrees of freedom (k-1)

    Notes
    -----
    Classic moment-based estimator. Fast but can be biased in small samples.
    """
    k = len(yi)
    wi = 1/vi
    ybar = np.sum(wi*yi) / np.sum(wi)
    Q = np.sum(wi*(yi-ybar)**2)
    df = k-1

    # Tau² formula: max(0, (Q-df) / (sum(wi) - sum(wi²)/sum(wi)))
    tau2 = max(0, (Q-df) / (np.sum(wi) - np.sum(wi**2)/np.sum(wi)))

    return tau2, Q, df


def restricted_ml_tau2(yi: np.ndarray, vi: np.ndarray,
                      maxiter: int = 100, tol: float = 1e-6) -> Tuple[float, float, int]:
    """
    Restricted Maximum Likelihood (REML) estimator for τ².

    Parameters
    ----------
    yi : array-like
        Effect sizes
    vi : array-like
        Sampling variances
    maxiter : int
        Maximum iterations (default: 100)
    tol : float
        Convergence tolerance (default: 1e-6)

    Returns
    -------
    tau2 : float
        Between-study variance (τ²)
    Q : float
        Cochran's Q statistic
    df : int
        Degrees of freedom (k-1)

    Notes
    -----
    Iterative algorithm using simplified Newton-Raphson.
    Generally more accurate than DerSimonian-Laird, especially for small k.
    """
    tau2 = 0.0
    k = len(yi)

    for _ in range(maxiter):
        wi = 1/(vi + tau2)
        ybar = np.sum(wi*yi) / np.sum(wi)

        # Newton-Raphson update
        num = np.sum(wi*(yi-ybar)**2) - (k-1)
        den = np.sum(wi) - np.sum(wi**2)/np.sum(wi)
        new_tau2 = tau2 + num/den

        # Ensure non-negative
        if new_tau2 < 0:
            new_tau2 = 0

        # Check convergence
        if abs(new_tau2 - tau2) < tol:
            break

        tau2 = new_tau2

    # Calculate final Q
    wi = 1/(vi + tau2)
    ybar = np.sum(wi*yi) / np.sum(wi)
    Q = np.sum(wi*(yi-ybar)**2)

    return tau2, Q, k-1


def heterogeneity_stats(Q: float, df: int) -> Tuple[float, float]:
    """
    Calculate I² and H² heterogeneity statistics.

    Parameters
    ----------
    Q : float
        Cochran's Q statistic
    df : int
        Degrees of freedom

    Returns
    -------
    I2 : float
        I² statistic (percentage of total variance due to heterogeneity)
    H2 : float
        H² statistic (ratio of total variance to sampling variance)

    Notes
    -----
    I² = max(0, (Q-df)/Q) * 100
    H² = Q/df

    Interpretation of I²:
    - 0-25%: Low heterogeneity
    - 25-50%: Moderate heterogeneity
    - 50-75%: Substantial heterogeneity
    - 75-100%: Considerable heterogeneity
    """
    I2 = max(0, (Q-df)/Q) * 100 if Q > df else 0
    H2 = Q/df if df > 0 else np.nan
    return I2, H2


# ============================================================
# META-ANALYSIS POOLING
# ============================================================

def meta_analysis(yi: np.ndarray, sei: np.ndarray,
                 method: str = "DL", model: str = "RE") -> Dict[str, Union[float, str]]:
    """
    Perform meta-analysis pooling with fixed or random effects.

    Parameters
    ----------
    yi : array-like
        Effect sizes (log scale for ratio measures)
    sei : array-like
        Standard errors
    method : str
        Heterogeneity estimator: "DL" (DerSimonian-Laird) or "REML" (default: "DL")
    model : str
        Model type: "FE" (fixed-effect) or "RE" (random-effects, default: "RE")

    Returns
    -------
    result : dict
        Dictionary with keys:
        - model: "FE" or "RE"
        - estimate: Pooled effect estimate
        - se: Standard error of pooled estimate
        - ci_lb: Lower 95% confidence bound
        - ci_ub: Upper 95% confidence bound
        - For RE models only:
            - tau2: Between-study variance
            - Q: Cochran's Q statistic
            - I2: I² heterogeneity statistic
            - H2: H² heterogeneity statistic
            - p_heterogeneity: P-value for heterogeneity test

    Examples
    --------
    >>> yi = np.array([0.5, 0.3, 0.7, 0.4])
    >>> sei = np.array([0.1, 0.15, 0.12, 0.09])
    >>> result = meta_analysis(yi, sei, method="REML", model="RE")
    >>> print(f"Pooled effect: {result['estimate']:.3f}")
    >>> print(f"I²: {result['I2']:.1f}%")
    """
    vi = sei**2

    if model == "FE":
        # Fixed-effect model
        wi = 1/vi
        mu = np.sum(wi*yi) / np.sum(wi)
        se = np.sqrt(1/np.sum(wi))
        ci_lb = mu - 1.96*se
        ci_ub = mu + 1.96*se

        return {
            "model": "FE",
            "estimate": float(mu),
            "se": float(se),
            "ci_lb": float(ci_lb),
            "ci_ub": float(ci_ub)
        }

    elif model == "RE":
        # Random-effects model
        if method == "DL":
            tau2, Q, df = dersimonian_laird_tau2(yi, vi)
        elif method == "REML":
            tau2, Q, df = restricted_ml_tau2(yi, vi)
        else:
            raise ValueError(f"Unknown method: {method}. Use 'DL' or 'REML'")

        wi = 1/(vi + tau2)
        mu = np.sum(wi*yi) / np.sum(wi)
        se = np.sqrt(1/np.sum(wi))
        ci_lb = mu - 1.96*se
        ci_ub = mu + 1.96*se

        I2, H2 = heterogeneity_stats(Q, df)
        p_het = 1 - chi2.cdf(Q, df) if df > 0 else np.nan

        return {
            "model": "RE",
            "method": method,
            "estimate": float(mu),
            "se": float(se),
            "ci_lb": float(ci_lb),
            "ci_ub": float(ci_ub),
            "tau2": float(tau2),
            "Q": float(Q),
            "df": int(df),
            "I2": float(I2),
            "H2": float(H2),
            "p_heterogeneity": float(p_het)
        }

    else:
        raise ValueError(f"Unknown model: {model}. Use 'FE' or 'RE'")


def subgroup_analysis(yi: np.ndarray, sei: np.ndarray, subgroups: np.ndarray,
                     method: str = "DL") -> Dict[str, any]:
    """
    Perform subgroup meta-analysis.

    Parameters
    ----------
    yi : array-like
        Effect sizes
    sei : array-like
        Standard errors
    subgroups : array-like
        Subgroup labels
    method : str
        Heterogeneity estimator: "DL" or "REML"

    Returns
    -------
    result : dict
        Dictionary with overall results and subgroup-specific results
    """
    unique_groups = np.unique(subgroups)
    subgroup_results = {}

    for group in unique_groups:
        mask = subgroups == group
        yi_sub = yi[mask]
        sei_sub = sei[mask]

        if len(yi_sub) > 0:
            subgroup_results[str(group)] = meta_analysis(yi_sub, sei_sub, method=method, model="RE")

    return {
        "n_subgroups": len(unique_groups),
        "subgroups": subgroup_results
    }


# ============================================================
# CONFIDENCE INTERVAL UTILITIES
# ============================================================

def backtransform_or(log_or: float, se: float) -> Dict[str, float]:
    """Back-transform log odds ratio to OR with 95% CI."""
    or_val = np.exp(log_or)
    ci_lb = np.exp(log_or - 1.96*se)
    ci_ub = np.exp(log_or + 1.96*se)
    return {"OR": or_val, "CI_lb": ci_lb, "CI_ub": ci_ub}


def backtransform_rr(log_rr: float, se: float) -> Dict[str, float]:
    """Back-transform log risk ratio to RR with 95% CI."""
    rr_val = np.exp(log_rr)
    ci_lb = np.exp(log_rr - 1.96*se)
    ci_ub = np.exp(log_rr + 1.96*se)
    return {"RR": rr_val, "CI_lb": ci_lb, "CI_ub": ci_ub}


def backtransform_hr(log_hr: float, se: float) -> Dict[str, float]:
    """Back-transform log hazard ratio to HR with 95% CI."""
    hr_val = np.exp(log_hr)
    ci_lb = np.exp(log_hr - 1.96*se)
    ci_ub = np.exp(log_hr + 1.96*se)
    return {"HR": hr_val, "CI_lb": ci_lb, "CI_ub": ci_ub}
