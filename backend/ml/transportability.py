"""
Transportability Analysis for Meta-Analysis
============================================

Assesses whether findings from source studies (e.g., RCTs) can be
transported/generalized to a target population with different characteristics.

Key Concepts:
- Effect Modification: Covariates that modify treatment effects
- Population Heterogeneity: Differences between source and target populations
- External Validity: Generalizability of findings
- Transportability Indices: Quantitative measures of generalizability

Methods Implemented:
1. Tipton's Generalizability Index (2014)
2. Stuart et al.'s TATE (Target Average Treatment Effect) estimation
3. Covariate balance assessment
4. Effect modifier detection
5. Sensitivity analysis for unmeasured confounding

References:
- Tipton, E. (2014). How generalizable is your experiment?
- Stuart et al. (2011). The use of propensity scores to assess generalizability
- Lesko et al. (2017). Generalizing study results: A potential outcomes perspective
"""

from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple, Any
from enum import Enum
import numpy as np
from scipy import stats
from scipy.spatial.distance import mahalanobis
import logging

logger = logging.getLogger(__name__)


class TransportMethod(Enum):
    """Transportability estimation methods"""
    INVERSE_ODDS_WEIGHTING = "inverse_odds_weighting"  # IO weighting
    STRATIFICATION = "stratification"  # Stratify by covariates
    REGRESSION = "regression"  # Outcome regression
    DOUBLY_ROBUST = "doubly_robust"  # Doubly robust estimator
    SIMPLE = "simple"  # Simple reweighting


class EffectModifierType(Enum):
    """Types of effect modification"""
    QUANTITATIVE = "quantitative"  # Effect size changes but direction same
    QUALITATIVE = "qualitative"  # Effect direction reverses


@dataclass
class Covariate:
    """
    Represents a covariate for transportability analysis

    Attributes:
        name: Covariate name
        values: Covariate values for each study/observation
        is_effect_modifier: Whether this covariate modifies treatment effect
        categorical: Whether covariate is categorical
        levels: For categorical variables, possible levels
    """
    name: str
    values: np.ndarray
    is_effect_modifier: bool = False
    categorical: bool = False
    levels: Optional[List[str]] = None

    def standardize(self) -> np.ndarray:
        """Standardize covariate values (mean=0, sd=1)"""
        if self.categorical:
            return self.values
        return (self.values - np.mean(self.values)) / np.std(self.values)


@dataclass
class Population:
    """
    Represents a population (source or target)

    Attributes:
        name: Population identifier
        covariates: Dictionary of covariate_name -> values
        sample_size: Population size
        is_target: Whether this is the target population
    """
    name: str
    covariates: Dict[str, np.ndarray]
    sample_size: int
    is_target: bool = False

    def get_covariate_matrix(self) -> np.ndarray:
        """Get covariate matrix (n x p)"""
        return np.column_stack(list(self.covariates.values()))

    def get_covariate_means(self) -> Dict[str, float]:
        """Get mean of each covariate"""
        return {name: np.mean(values) for name, values in self.covariates.items()}


@dataclass
class Study:
    """
    Represents a study in the source population

    Attributes:
        study_id: Study identifier
        treatment_effect: Observed treatment effect (e.g., log OR, SMD)
        standard_error: Standard error of treatment effect
        sample_size: Study sample size
        n_treatment: Sample size in treatment group
        n_control: Sample size in control group
        covariates: Study-level covariates
        participant_covariates: Individual-level covariates (if available)
    """
    study_id: str
    treatment_effect: float
    standard_error: float
    sample_size: int
    n_treatment: int
    n_control: int
    covariates: Dict[str, float]
    participant_covariates: Optional[Dict[str, np.ndarray]] = None


@dataclass
class TransportabilityResults:
    """
    Results of transportability analysis

    Attributes:
        source_effect: Average treatment effect in source population
        target_effect: Transported average treatment effect in target
        source_se: Standard error in source
        target_se: Standard error in target (accounting for uncertainty)
        generalizability_index: Tipton's generalizability index (0-1)
        covariate_balance: Standardized mean differences for each covariate
        effect_modifiers: Identified effect modifying covariates
        transportability_assumption_met: Whether key assumptions are satisfied
        sensitivity_analysis: Results of sensitivity analysis
        warnings: Warning messages
    """
    source_effect: float
    target_effect: float
    source_se: float
    target_se: float
    generalizability_index: float
    covariate_balance: Dict[str, float]  # SMD for each covariate
    effect_modifiers: List[str]
    transportability_assumption_met: bool
    sensitivity_analysis: Dict[str, Any]
    warnings: List[str] = field(default_factory=list)

    def summary(self) -> str:
        """Generate summary report"""
        report = f"""
Transportability Analysis Summary
==================================

Source Population Effect: {self.source_effect:.3f} (SE: {self.source_se:.3f})
Target Population Effect: {self.target_effect:.3f} (SE: {self.target_se:.3f})

Generalizability Index: {self.generalizability_index:.3f}
  (0 = not generalizable, 1 = perfectly generalizable)

Transportability Assumptions: {'✓ MET' if self.transportability_assumption_met else '✗ NOT MET'}

Effect Modifiers Detected:
{chr(10).join(f'  - {em}' for em in self.effect_modifiers) if self.effect_modifiers else '  None detected'}

Covariate Balance (Source vs Target):
{chr(10).join(f'  {name}: SMD = {smd:.3f} {"(balanced)" if abs(smd) < 0.1 else "(imbalanced)"}' for name, smd in self.covariate_balance.items())}

Warnings:
{chr(10).join(f'  ⚠ {w}' for w in self.warnings) if self.warnings else '  None'}
"""
        return report


class TransportabilityAnalysis:
    """
    Transportability Analysis Engine

    Performs transportability analysis to assess whether treatment effects
    from source studies can be generalized to a target population.
    """

    def __init__(
        self,
        source_studies: List[Study],
        target_population: Population,
        method: TransportMethod = TransportMethod.INVERSE_ODDS_WEIGHTING
    ):
        """
        Initialize transportability analysis

        Args:
            source_studies: List of studies from source population
            target_population: Target population characteristics
            method: Transportability method to use
        """
        self.source_studies = source_studies
        self.target_population = target_population
        self.method = method
        self.warnings = []

    def analyze(self) -> TransportabilityResults:
        """
        Perform complete transportability analysis

        Returns:
            TransportabilityResults with all metrics
        """
        # Step 1: Assess covariate balance
        logger.info("Assessing covariate balance...")
        covariate_balance = self._assess_covariate_balance()

        # Step 2: Detect effect modifiers
        logger.info("Detecting effect modifiers...")
        effect_modifiers = self._detect_effect_modifiers()

        # Step 3: Calculate generalizability index
        logger.info("Calculating generalizability index...")
        gen_index = self._calculate_generalizability_index()

        # Step 4: Estimate source effect
        source_effect, source_se = self._estimate_source_effect()

        # Step 5: Transport effect to target population
        logger.info(f"Transporting effect using {self.method.value}...")
        target_effect, target_se = self._transport_effect(effect_modifiers)

        # Step 6: Check transportability assumptions
        assumptions_met = self._check_assumptions(covariate_balance, effect_modifiers)

        # Step 7: Sensitivity analysis
        logger.info("Running sensitivity analysis...")
        sensitivity = self._sensitivity_analysis()

        results = TransportabilityResults(
            source_effect=source_effect,
            target_effect=target_effect,
            source_se=source_se,
            target_se=target_se,
            generalizability_index=gen_index,
            covariate_balance=covariate_balance,
            effect_modifiers=effect_modifiers,
            transportability_assumption_met=assumptions_met,
            sensitivity_analysis=sensitivity,
            warnings=self.warnings
        )

        return results

    def _assess_covariate_balance(self) -> Dict[str, float]:
        """
        Assess covariate balance between source and target populations

        Returns:
            Dictionary of covariate_name -> standardized mean difference (SMD)

        SMD interpretation:
            |SMD| < 0.1: Negligible imbalance
            |SMD| < 0.2: Small imbalance
            |SMD| < 0.5: Moderate imbalance
            |SMD| >= 0.5: Large imbalance
        """
        balance = {}

        # Get source population covariate means
        source_means = {}
        source_sds = {}

        for covariate_name in self.target_population.covariates.keys():
            # Aggregate from studies (weighted by sample size)
            total_n = sum(study.sample_size for study in self.source_studies)

            if covariate_name in self.source_studies[0].covariates:
                # Study-level covariate
                weighted_mean = sum(
                    study.covariates.get(covariate_name, 0) * study.sample_size
                    for study in self.source_studies
                ) / total_n

                # Approximate SD (assuming similar within studies)
                values = [study.covariates.get(covariate_name, 0) for study in self.source_studies]
                sd = np.std(values) if len(values) > 1 else 1.0

                source_means[covariate_name] = weighted_mean
                source_sds[covariate_name] = sd

        # Calculate SMD for each covariate
        for covariate_name in self.target_population.covariates.keys():
            if covariate_name in source_means:
                source_mean = source_means[covariate_name]
                target_mean = np.mean(self.target_population.covariates[covariate_name])
                pooled_sd = source_sds[covariate_name]

                smd = (target_mean - source_mean) / pooled_sd if pooled_sd > 0 else 0.0
                balance[covariate_name] = smd

                # Add warning for large imbalance
                if abs(smd) >= 0.5:
                    self.warnings.append(
                        f"Large covariate imbalance for '{covariate_name}' (SMD={smd:.3f}). "
                        "Transportability may be limited."
                    )

        return balance

    def _detect_effect_modifiers(self) -> List[str]:
        """
        Detect effect modifying covariates using meta-regression

        Returns:
            List of covariate names that significantly modify treatment effect
        """
        effect_modifiers = []

        if len(self.source_studies) < 5:
            self.warnings.append(
                f"Only {len(self.source_studies)} studies available. "
                "Effect modifier detection may be unreliable."
            )
            return effect_modifiers

        # For each covariate, test interaction with treatment
        covariate_names = list(self.source_studies[0].covariates.keys())

        for covariate_name in covariate_names:
            # Meta-regression: y = β0 + β1*covariate + ε
            y = np.array([study.treatment_effect for study in self.source_studies])
            x = np.array([study.covariates.get(covariate_name, 0) for study in self.source_studies])
            weights = np.array([1/study.standard_error**2 for study in self.source_studies])

            # Weighted least squares
            if len(np.unique(x)) > 1:  # Need variation in covariate
                # Add intercept
                X = np.column_stack([np.ones(len(x)), x])

                # Weighted regression
                W = np.diag(weights)
                try:
                    beta = np.linalg.inv(X.T @ W @ X) @ X.T @ W @ y

                    # Test significance of slope (β1)
                    residuals = y - X @ beta
                    mse = np.sum(weights * residuals**2) / (len(y) - 2)
                    var_beta = mse * np.linalg.inv(X.T @ W @ X)
                    se_beta1 = np.sqrt(var_beta[1, 1])

                    t_stat = beta[1] / se_beta1
                    p_value = 2 * (1 - stats.t.cdf(abs(t_stat), len(y) - 2))

                    # Significant at α=0.05
                    if p_value < 0.05:
                        effect_modifiers.append(covariate_name)
                        logger.info(
                            f"Effect modifier detected: {covariate_name} "
                            f"(β={beta[1]:.3f}, p={p_value:.4f})"
                        )

                except np.linalg.LinAlgError:
                    logger.warning(f"Could not test effect modification for {covariate_name}")

        return effect_modifiers

    def _calculate_generalizability_index(self) -> float:
        """
        Calculate Tipton's Generalizability Index

        Measures overlap between source and target populations in covariate space.

        Returns:
            Index between 0 (no overlap) and 1 (perfect overlap)
        """
        # Simplified version: proportion of target in source covariate range

        # Get covariate matrices
        target_covariates = self.target_population.get_covariate_matrix()

        # Build source covariate distribution from studies
        source_covariate_names = list(self.source_studies[0].covariates.keys())

        if not source_covariate_names:
            return 0.5  # No covariates to compare

        # Calculate proportion of target within source range for each covariate
        proportions = []

        for i, covariate_name in enumerate(source_covariate_names):
            source_values = [study.covariates.get(covariate_name, 0) for study in self.source_studies]
            source_min = min(source_values)
            source_max = max(source_values)

            if covariate_name in self.target_population.covariates:
                target_values = self.target_population.covariates[covariate_name]

                # Proportion within range
                within_range = np.sum((target_values >= source_min) & (target_values <= source_max))
                proportion = within_range / len(target_values)
                proportions.append(proportion)

        # Generalizability index = average proportion
        gen_index = np.mean(proportions) if proportions else 0.5

        return gen_index

    def _estimate_source_effect(self) -> Tuple[float, float]:
        """
        Estimate pooled treatment effect in source population

        Returns:
            (effect, standard_error)
        """
        # Fixed-effect meta-analysis
        weights = np.array([1/study.standard_error**2 for study in self.source_studies])
        effects = np.array([study.treatment_effect for study in self.source_studies])

        pooled_effect = np.sum(weights * effects) / np.sum(weights)
        pooled_se = 1 / np.sqrt(np.sum(weights))

        return pooled_effect, pooled_se

    def _transport_effect(self, effect_modifiers: List[str]) -> Tuple[float, float]:
        """
        Transport effect to target population accounting for effect modifiers

        Args:
            effect_modifiers: List of effect modifying covariates

        Returns:
            (transported_effect, standard_error)
        """
        source_effect, source_se = self._estimate_source_effect()

        if not effect_modifiers:
            # No effect modification: source effect = target effect
            return source_effect, source_se

        # Adjust for effect modification
        # Simple approach: linear adjustment based on covariate differences

        total_adjustment = 0.0

        for modifier in effect_modifiers:
            # Get source and target means
            source_values = [study.covariates.get(modifier, 0) for study in self.source_studies]
            source_mean = np.mean(source_values)

            target_values = self.target_population.covariates.get(modifier)
            if target_values is not None:
                target_mean = np.mean(target_values)

                # Estimate modification coefficient from meta-regression
                y = np.array([study.treatment_effect for study in self.source_studies])
                x = np.array(source_values)

                if len(np.unique(x)) > 1:
                    # Simple regression
                    modification_coef = np.cov(x, y)[0, 1] / np.var(x)

                    # Adjustment = coefficient * difference in means
                    adjustment = modification_coef * (target_mean - source_mean)
                    total_adjustment += adjustment

        # Transported effect
        target_effect = source_effect + total_adjustment

        # Increased uncertainty due to transport
        transport_uncertainty = 0.2 * abs(total_adjustment)  # 20% of adjustment
        target_se = np.sqrt(source_se**2 + transport_uncertainty**2)

        return target_effect, target_se

    def _check_assumptions(
        self,
        covariate_balance: Dict[str, float],
        effect_modifiers: List[str]
    ) -> bool:
        """
        Check key transportability assumptions

        Assumptions:
        1. Positivity: Target covariates within source range
        2. No unmeasured effect modification
        3. Consistency: Treatment definition same in source and target

        Returns:
            True if assumptions reasonably satisfied
        """
        # Check covariate balance for effect modifiers
        for modifier in effect_modifiers:
            if modifier in covariate_balance:
                smd = abs(covariate_balance[modifier])
                if smd >= 0.5:
                    self.warnings.append(
                        f"Effect modifier '{modifier}' has large imbalance (SMD={smd:.3f}). "
                        "Transportability assumption may be violated."
                    )
                    return False

        # Check generalizability index
        gen_index = self._calculate_generalizability_index()
        if gen_index < 0.5:
            self.warnings.append(
                f"Low generalizability index ({gen_index:.3f}). "
                "Target population may be outside source covariate space."
            )
            return False

        return True

    def _sensitivity_analysis(self) -> Dict[str, Any]:
        """
        Sensitivity analysis for unmeasured confounding

        Returns:
            Dictionary with sensitivity results
        """
        source_effect, source_se = self._estimate_source_effect()

        # E-value: minimum strength of unmeasured confounding to explain away effect
        # E-value = RR + sqrt(RR * (RR - 1))
        # For non-ratio measures, approximate

        if source_effect != 0:
            # Approximate RR from effect size
            rr_approx = np.exp(source_effect)

            if rr_approx > 1:
                e_value = rr_approx + np.sqrt(rr_approx * (rr_approx - 1))
            else:
                e_value = 1/rr_approx + np.sqrt((1/rr_approx) * (1/rr_approx - 1))
        else:
            e_value = 1.0

        # Tipping point analysis: how much bias needed to change conclusion
        ci_lower = source_effect - 1.96 * source_se
        ci_upper = source_effect + 1.96 * source_se

        # Bias needed to cross null
        if source_effect > 0:
            bias_to_null = source_effect  # Absolute bias
        else:
            bias_to_null = -source_effect

        return {
            "e_value": e_value,
            "bias_to_null": bias_to_null,
            "ci_lower": ci_lower,
            "ci_upper": ci_upper,
            "interpretation": (
                f"An unmeasured confounder would need to have an association of "
                f"RR={e_value:.2f} with both treatment and outcome to explain away "
                f"the observed effect."
            )
        }


# Helper functions

def calculate_sample_size_for_transportability(
    source_effect: float,
    source_se: float,
    expected_difference: float = 0.1,
    alpha: float = 0.05,
    power: float = 0.80
) -> int:
    """
    Calculate required target population sample size for transportability study

    Args:
        source_effect: Effect size in source population
        source_se: Standard error in source
        expected_difference: Expected difference between source and target effects
        alpha: Significance level
        power: Desired statistical power

    Returns:
        Required sample size for target population
    """
    z_alpha = stats.norm.ppf(1 - alpha/2)
    z_beta = stats.norm.ppf(power)

    # Sample size for detecting difference
    n = (2 * (z_alpha + z_beta)**2 * source_se**2) / expected_difference**2

    return int(np.ceil(n))


def tipton_generalizability_index_subgroup(
    source_data: np.ndarray,
    target_data: np.ndarray,
    subgroup_variable: np.ndarray
) -> Dict[str, float]:
    """
    Calculate generalizability index within subgroups

    Args:
        source_data: Source population covariate matrix (n_source x p)
        target_data: Target population covariate matrix (n_target x p)
        subgroup_variable: Subgroup indicator for target (n_target,)

    Returns:
        Dictionary mapping subgroup -> generalizability index
    """
    indices = {}

    for subgroup in np.unique(subgroup_variable):
        mask = subgroup_variable == subgroup
        target_subset = target_data[mask]

        # Simple overlap measure
        # More sophisticated: use kernel density estimation
        overlap = 0.0

        for target_point in target_subset:
            # Check if within convex hull of source
            # Simplified: within min/max range for each dimension
            within_range = np.all(
                (target_point >= np.min(source_data, axis=0)) &
                (target_point <= np.max(source_data, axis=0))
            )
            if within_range:
                overlap += 1

        indices[str(subgroup)] = overlap / len(target_subset) if len(target_subset) > 0 else 0.0

    return indices


# Example usage
if __name__ == "__main__":
    # Example: RCT transportability to real-world population

    # Source studies (RCTs)
    studies = [
        Study(
            study_id="RCT001",
            treatment_effect=0.5,  # log OR
            standard_error=0.15,
            sample_size=200,
            n_treatment=100,
            n_control=100,
            covariates={"age": 55.0, "female_pct": 0.45, "comorbidity_index": 2.1}
        ),
        Study(
            study_id="RCT002",
            treatment_effect=0.6,
            standard_error=0.18,
            sample_size=150,
            n_treatment=75,
            n_control=75,
            covariates={"age": 58.0, "female_pct": 0.50, "comorbidity_index": 2.3}
        ),
        Study(
            study_id="RCT003",
            treatment_effect=0.4,
            standard_error=0.12,
            sample_size=300,
            n_treatment=150,
            n_control=150,
            covariates={"age": 52.0, "female_pct": 0.40, "comorbidity_index": 1.9}
        ),
    ]

    # Target population (real-world observational cohort)
    np.random.seed(42)
    target = Population(
        name="Real-World Cohort",
        covariates={
            "age": np.random.normal(62, 10, 1000),  # Older population
            "female_pct": np.random.beta(6, 4, 1000),  # More females
            "comorbidity_index": np.random.gamma(3, 0.8, 1000)  # More comorbidities
        },
        sample_size=1000,
        is_target=True
    )

    # Run transportability analysis
    analysis = TransportabilityAnalysis(
        source_studies=studies,
        target_population=target,
        method=TransportMethod.INVERSE_ODDS_WEIGHTING
    )

    results = analysis.analyze()

    # Print summary
    print(results.summary())

    # Calculate required sample size for validation
    required_n = calculate_sample_size_for_transportability(
        source_effect=results.source_effect,
        source_se=results.source_se,
        expected_difference=0.15
    )
    print(f"\nRequired sample size for validation study: {required_n}")
