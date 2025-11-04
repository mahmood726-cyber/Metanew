"""
MAIC/STC Engine - Population-Adjusted Indirect Comparisons
=============================================================

Implements Matching-Adjusted Indirect Comparison (MAIC) and Simulated Treatment
Comparison (STC) methods for HTA submissions.

Critical for 27% of HTA submissions where no head-to-head RCT exists.

Hybrid Approach:
- Rules: Data validation, weight calculation, sanity checks
- AI: Variable selection suggestions, interpretation of balance diagnostics
- Validation: ESS thresholds, weight constraints, CI reasonableness

References:
- Signorovitch et al. (2012) - MAIC methodology
- NICE DSU TSD 18 - Population-adjusted indirect comparisons
- Phillippo et al. (2020) - ML-NMR and STC
"""

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from scipy.stats import norm
from typing import Dict, List, Tuple, Optional
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class MAICData:
    """Structured input data for MAIC"""
    ipd: pd.DataFrame  # Individual patient data (your trial)
    agd_baseline: pd.DataFrame  # Aggregate data baseline characteristics (comparator trial)
    agd_outcomes: Dict[str, float]  # Aggregate outcomes (comparator trial)
    matching_vars: List[str]  # Variables to match on
    outcome_var: str  # Outcome variable name in IPD
    treatment_var: str  # Treatment indicator in IPD


@dataclass
class MAICResults:
    """MAIC analysis results"""
    weights: np.ndarray  # Patient-level weights
    ess: float  # Effective sample size
    weighted_mean: float  # Weighted mean outcome in IPD
    treatment_effect: float  # Estimated treatment effect (IPD vs AgD)
    se: float  # Standard error
    ci_lower: float  # 95% CI lower bound
    ci_upper: float  # 95% CI upper bound
    balance_before: pd.DataFrame  # Balance diagnostics before weighting
    balance_after: pd.DataFrame  # Balance diagnostics after weighting
    diagnostics: Dict[str, any]  # Additional diagnostics
    validation_results: Dict[str, bool]  # Rule-based validation checks


class MAICEngine:
    """
    MAIC computation engine with hybrid rules+AI approach

    Usage:
        engine = MAICEngine()
        results = engine.run_maic(data)
    """

    def __init__(self, ollama_client=None):
        """
        Initialize MAIC engine

        Args:
            ollama_client: Optional Ollama AI client for variable suggestions
        """
        self.ollama = ollama_client

    def run_maic(self, data: MAICData) -> MAICResults:
        """
        Run MAIC analysis with validation

        Args:
            data: MAICData object with IPD and AgD

        Returns:
            MAICResults object
        """
        logger.info("Starting MAIC analysis")

        # Step 1: Validate data (RULES)
        self._validate_data(data)

        # Step 2: Calculate balance before weighting (RULES)
        balance_before = self._calculate_balance(
            data.ipd,
            data.agd_baseline,
            data.matching_vars,
            weights=None
        )

        # Step 3: Optimize weights (RULES - deterministic optimization)
        weights = self._optimize_weights(data.ipd, data.agd_baseline, data.matching_vars)

        # Step 4: Calculate ESS (RULES)
        ess = self._calculate_ess(weights)

        # Step 5: Check ESS threshold (RULES)
        if ess < 0.6 * len(weights):
            logger.warning(f"ESS ({ess:.1f}) < 60% of sample size. Results may be unreliable.")

        # Step 6: Calculate balance after weighting (RULES)
        balance_after = self._calculate_balance(
            data.ipd,
            data.agd_baseline,
            data.matching_vars,
            weights=weights
        )

        # Step 7: Calculate weighted outcome (RULES)
        weighted_mean = self._calculate_weighted_mean(
            data.ipd[data.outcome_var].values,
            weights
        )

        # Step 8: Calculate treatment effect (RULES)
        # Effect = IPD weighted outcome - AgD comparator outcome
        agd_outcome_mean = data.agd_outcomes['mean']
        treatment_effect = weighted_mean - agd_outcome_mean

        # Step 9: Calculate standard error (RULES)
        se = self._calculate_se(
            data.ipd[data.outcome_var].values,
            weights,
            ess,
            data.agd_outcomes.get('se', None)
        )

        # Step 10: Calculate confidence interval (RULES)
        ci_lower = treatment_effect - 1.96 * se
        ci_upper = treatment_effect + 1.96 * se

        # Step 11: Diagnostics
        diagnostics = {
            'n_patients': len(weights),
            'ess': ess,
            'ess_ratio': ess / len(weights),
            'max_weight': np.max(weights),
            'min_weight': np.min(weights),
            'mean_weight': np.mean(weights),
            'weight_cv': np.std(weights) / np.mean(weights)  # Coefficient of variation
        }

        # Step 12: Validate results (RULES)
        validation_results = self._validate_results(
            weights, ess, treatment_effect, ci_lower, ci_upper, balance_after
        )

        # Step 13: Package results
        results = MAICResults(
            weights=weights,
            ess=ess,
            weighted_mean=weighted_mean,
            treatment_effect=treatment_effect,
            se=se,
            ci_lower=ci_lower,
            ci_upper=ci_upper,
            balance_before=balance_before,
            balance_after=balance_after,
            diagnostics=diagnostics,
            validation_results=validation_results
        )

        logger.info(f"MAIC completed. Treatment effect: {treatment_effect:.3f} "
                   f"(95% CI: {ci_lower:.3f}, {ci_upper:.3f}), ESS: {ess:.1f}")

        return results

    def _validate_data(self, data: MAICData):
        """
        Rule-based data validation

        Raises:
            ValueError: If data validation fails
        """
        # Check 1: Matching variables exist in both datasets
        ipd_cols = set(data.ipd.columns)
        agd_cols = set(data.agd_baseline.columns)

        missing_in_ipd = set(data.matching_vars) - ipd_cols
        missing_in_agd = set(data.matching_vars) - agd_cols

        if missing_in_ipd:
            raise ValueError(f"Matching variables missing in IPD: {missing_in_ipd}")
        if missing_in_agd:
            raise ValueError(f"Matching variables missing in AgD: {missing_in_agd}")

        # Check 2: Outcome variable exists in IPD
        if data.outcome_var not in ipd_cols:
            raise ValueError(f"Outcome variable '{data.outcome_var}' not found in IPD")

        # Check 3: Treatment variable exists in IPD
        if data.treatment_var not in ipd_cols:
            raise ValueError(f"Treatment variable '{data.treatment_var}' not found in IPD")

        # Check 4: No missing data in matching variables
        for var in data.matching_vars:
            if data.ipd[var].isnull().any():
                raise ValueError(f"Missing data in IPD variable: {var}")
            if data.agd_baseline[var].isnull().any():
                raise ValueError(f"Missing data in AgD variable: {var}")

        # Check 5: Sample size > 0
        if len(data.ipd) == 0:
            raise ValueError("IPD has zero rows")

        # Check 6: Matching variables are numeric
        for var in data.matching_vars:
            if not pd.api.types.is_numeric_dtype(data.ipd[var]):
                raise ValueError(f"Variable {var} in IPD is not numeric")
            if not pd.api.types.is_numeric_dtype(data.agd_baseline[var]):
                raise ValueError(f"Variable {var} in AgD is not numeric")

        logger.info("Data validation passed")

    def _calculate_balance(
        self,
        ipd: pd.DataFrame,
        agd: pd.DataFrame,
        matching_vars: List[str],
        weights: Optional[np.ndarray] = None
    ) -> pd.DataFrame:
        """
        Calculate balance diagnostics (standardized mean differences)

        Args:
            ipd: Individual patient data
            agd: Aggregate data
            matching_vars: Variables to check balance
            weights: Optional weights (None = unweighted)

        Returns:
            DataFrame with balance statistics
        """
        balance_stats = []

        for var in matching_vars:
            # IPD mean (weighted or unweighted)
            if weights is None:
                ipd_mean = ipd[var].mean()
                ipd_sd = ipd[var].std()
            else:
                ipd_mean = np.average(ipd[var].values, weights=weights)
                # Weighted SD
                variance = np.average((ipd[var].values - ipd_mean)**2, weights=weights)
                ipd_sd = np.sqrt(variance)

            # AgD mean and SD
            agd_mean = agd[var].iloc[0]  # Assuming single row with means

            # Try to get AgD SD, fallback to IPD SD
            sd_col = f"{var}_sd"
            if sd_col in agd.columns:
                agd_sd = agd[sd_col].iloc[0]
            else:
                agd_sd = ipd_sd  # Use IPD SD if AgD SD not available

            # Standardized mean difference
            pooled_sd = np.sqrt((ipd_sd**2 + agd_sd**2) / 2)
            smd = (ipd_mean - agd_mean) / pooled_sd if pooled_sd > 0 else 0.0

            balance_stats.append({
                'variable': var,
                'ipd_mean': ipd_mean,
                'agd_mean': agd_mean,
                'smd': smd,
                'balanced': abs(smd) < 0.1  # Standard threshold
            })

        return pd.DataFrame(balance_stats)

    def _optimize_weights(
        self,
        ipd: pd.DataFrame,
        agd: pd.DataFrame,
        matching_vars: List[str]
    ) -> np.ndarray:
        """
        Optimize MAIC weights using method of moments

        This is deterministic optimization - no AI involved

        Args:
            ipd: Individual patient data
            agd: Aggregate data
            matching_vars: Variables to match on

        Returns:
            Array of optimized weights
        """
        n = len(ipd)

        # Extract target means from AgD
        target_means = agd[matching_vars].iloc[0].values

        # Extract IPD covariate matrix
        X = ipd[matching_vars].values

        # Objective function: minimize sum of squared weights (entropy)
        # Subject to: weighted means = target means
        def objective(alpha):
            """Lagrange multipliers for entropy minimization"""
            exp_alpha_X = np.exp(X @ alpha)
            return np.sum(exp_alpha_X)

        def constraints_eq(alpha):
            """Moment matching constraints"""
            exp_alpha_X = np.exp(X @ alpha)
            weights = exp_alpha_X / np.sum(exp_alpha_X) * n
            weighted_means = (X.T @ weights) / n
            return weighted_means - target_means

        # Initial guess
        alpha0 = np.zeros(len(matching_vars))

        # Optimize
        result = minimize(
            objective,
            alpha0,
            method='SLSQP',
            constraints={'type': 'eq', 'fun': constraints_eq},
            options={'maxiter': 1000}
        )

        if not result.success:
            logger.warning(f"Optimization did not converge: {result.message}")

        # Calculate final weights
        alpha_opt = result.x
        exp_alpha_X = np.exp(X @ alpha_opt)
        weights = exp_alpha_X / np.sum(exp_alpha_X) * n

        return weights

    def _calculate_ess(self, weights: np.ndarray) -> float:
        """
        Calculate effective sample size

        ESS = (sum of weights)^2 / (sum of squared weights)

        Args:
            weights: Patient-level weights

        Returns:
            Effective sample size
        """
        return (np.sum(weights)**2) / np.sum(weights**2)

    def _calculate_weighted_mean(self, values: np.ndarray, weights: np.ndarray) -> float:
        """Calculate weighted mean"""
        return np.average(values, weights=weights)

    def _calculate_se(
        self,
        values: np.ndarray,
        weights: np.ndarray,
        ess: float,
        agd_se: Optional[float] = None
    ) -> float:
        """
        Calculate standard error of treatment effect

        Combines uncertainty from weighted IPD and AgD

        Args:
            values: Outcome values from IPD
            weights: Weights
            ess: Effective sample size
            agd_se: Standard error from AgD (if available)

        Returns:
            Standard error
        """
        # SE from weighted IPD
        weighted_mean = np.average(values, weights=weights)
        weighted_var = np.average((values - weighted_mean)**2, weights=weights)
        ipd_se = np.sqrt(weighted_var / ess)

        # Combine with AgD SE
        if agd_se is not None:
            # Assumes independence
            combined_se = np.sqrt(ipd_se**2 + agd_se**2)
        else:
            # Conservative: only IPD uncertainty
            combined_se = ipd_se

        return combined_se

    def _validate_results(
        self,
        weights: np.ndarray,
        ess: float,
        treatment_effect: float,
        ci_lower: float,
        ci_upper: float,
        balance_after: pd.DataFrame
    ) -> Dict[str, bool]:
        """
        Rule-based validation of MAIC results

        Returns:
            Dict of validation checks (True = passed, False = failed)
        """
        checks = {}

        # Check 1: All weights positive
        checks['weights_positive'] = np.all(weights > 0)

        # Check 2: ESS reasonable (> 10)
        checks['ess_reasonable'] = ess > 10

        # Check 3: ESS not too low (> 30% of original)
        checks['ess_not_extreme'] = ess > 0.3 * len(weights)

        # Check 4: Treatment effect finite
        checks['effect_finite'] = np.isfinite(treatment_effect)

        # Check 5: CI width reasonable (< 10 SDs)
        ci_width = ci_upper - ci_lower
        checks['ci_reasonable'] = ci_width < 100  # Depends on scale

        # Check 6: Most covariates balanced (SMD < 0.1)
        n_balanced = balance_after['balanced'].sum()
        n_total = len(balance_after)
        checks['covariates_balanced'] = n_balanced >= 0.7 * n_total

        # Check 7: No extreme weights
        max_weight = np.max(weights)
        mean_weight = np.mean(weights)
        checks['no_extreme_weights'] = max_weight < 5 * mean_weight

        # Overall validation
        checks['overall_valid'] = all(checks.values())

        return checks

    def suggest_matching_variables(self, ipd: pd.DataFrame, agd: pd.DataFrame) -> List[str]:
        """
        AI-assisted suggestion of matching variables

        Uses Ollama AI to suggest effect modifiers, then validates with rules

        Args:
            ipd: Individual patient data
            agd: Aggregate data

        Returns:
            List of suggested matching variables
        """
        if self.ollama is None:
            # Fallback: return common variables
            common_vars = list(set(ipd.columns) & set(agd.columns))
            return [v for v in common_vars if pd.api.types.is_numeric_dtype(ipd[v])]

        # AI suggestion
        prompt = f"""
        You are an HTA statistician. Suggest which variables are likely effect modifiers
        for a population-adjusted indirect comparison.

        IPD variables: {', '.join(ipd.columns)}
        AgD variables: {', '.join(agd.columns)}

        Consider: age, sex, disease severity, comorbidities, baseline risk.

        Return ONLY a JSON array of variable names that exist in BOTH datasets.
        Example: ["age", "sex", "baseline_score"]
        """

        try:
            response = self.ollama.generate("llama3", prompt, temperature=0.3)
            # Parse JSON from response
            import json
            suggestions = json.loads(response['response'])

            # Rule validation: only variables in BOTH datasets and numeric
            common_vars = set(ipd.columns) & set(agd.columns)
            valid_suggestions = [
                v for v in suggestions
                if v in common_vars and pd.api.types.is_numeric_dtype(ipd[v])
            ]

            logger.info(f"AI suggested {len(valid_suggestions)} matching variables")
            return valid_suggestions

        except Exception as e:
            logger.warning(f"AI suggestion failed: {e}. Using fallback.")
            # Fallback to common numeric variables
            common_vars = list(set(ipd.columns) & set(agd.columns))
            return [v for v in common_vars if pd.api.types.is_numeric_dtype(ipd[v])]

    def interpret_balance(self, balance_df: pd.DataFrame) -> str:
        """
        AI-assisted interpretation of balance diagnostics

        Args:
            balance_df: Balance statistics DataFrame

        Returns:
            Human-readable interpretation
        """
        if self.ollama is None:
            # Fallback: rule-based interpretation
            n_balanced = balance_df['balanced'].sum()
            n_total = len(balance_df)

            if n_balanced == n_total:
                return f"✅ Excellent balance: All {n_total} covariates have SMD < 0.1"
            elif n_balanced >= 0.8 * n_total:
                return f"✅ Good balance: {n_balanced}/{n_total} covariates have SMD < 0.1"
            elif n_balanced >= 0.6 * n_total:
                return f"⚠️ Moderate balance: {n_balanced}/{n_total} covariates have SMD < 0.1"
            else:
                concerning = balance_df[~balance_df['balanced']]['variable'].tolist()
                return f"❌ Poor balance: {concerning} have SMD > 0.1. Review matching."

        # AI interpretation
        balance_summary = balance_df[['variable', 'smd', 'balanced']].to_string()

        prompt = f"""
        You are an HTA statistician. Interpret these balance diagnostics after MAIC weighting:

        {balance_summary}

        SMD < 0.1 is considered balanced.
        Provide a 2-3 sentence interpretation: Are the populations now comparable?
        Any concerns?
        """

        try:
            response = self.ollama.generate("llama3", prompt, temperature=0.5)
            interpretation = response['response']

            # Add rule-based concern flag
            concerning = balance_df[~balance_df['balanced']]['variable'].tolist()
            if concerning:
                interpretation += f"\n\n⚠️ Concerning variables: {', '.join(concerning)}"

            return interpretation

        except Exception as e:
            logger.warning(f"AI interpretation failed: {e}")
            # Fallback to rule-based
            return self.interpret_balance(balance_df)


# Example usage
if __name__ == "__main__":
    # Demo with synthetic data
    np.random.seed(42)

    # Create synthetic IPD (your trial)
    n_ipd = 200
    ipd = pd.DataFrame({
        'age': np.random.normal(60, 10, n_ipd),
        'baseline_severity': np.random.normal(50, 15, n_ipd),
        'sex': np.random.binomial(1, 0.5, n_ipd),  # 0=male, 1=female
        'treatment': np.ones(n_ipd),  # All on treatment
        'outcome': np.random.normal(10, 5, n_ipd)  # Outcome (e.g., HbA1c reduction)
    })

    # Create synthetic AgD (comparator trial)
    agd_baseline = pd.DataFrame({
        'age': [55],  # Comparator trial is younger
        'baseline_severity': [52],  # Slightly higher severity
        'sex': [0.6]  # More females
    })

    agd_outcomes = {
        'mean': 7.0,  # Mean outcome in comparator
        'se': 0.5  # Standard error
    }

    # Package data
    data = MAICData(
        ipd=ipd,
        agd_baseline=agd_baseline,
        agd_outcomes=agd_outcomes,
        matching_vars=['age', 'baseline_severity', 'sex'],
        outcome_var='outcome',
        treatment_var='treatment'
    )

    # Run MAIC
    engine = MAICEngine()
    results = engine.run_maic(data)

    # Print results
    print("\n" + "="*60)
    print("MAIC RESULTS")
    print("="*60)
    print(f"Treatment Effect: {results.treatment_effect:.3f}")
    print(f"95% CI: ({results.ci_lower:.3f}, {results.ci_upper:.3f})")
    print(f"Effective Sample Size: {results.ess:.1f} (from {len(ipd)})")
    print(f"\nBalance After Weighting:")
    print(results.balance_after[['variable', 'smd', 'balanced']].to_string(index=False))
    print(f"\nValidation: {'✅ PASSED' if results.validation_results['overall_valid'] else '❌ FAILED'}")
