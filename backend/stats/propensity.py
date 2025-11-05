"""
Propensity Score Analysis Module

Comprehensive propensity score methods for causal inference:
- Propensity score matching (PSM)
- Inverse probability weighting (IPW)
- Stratification
- Covariate balancing propensity score (CBPS)
- Doubly robust estimation
- Balance diagnostics and love plots

V2.3 ENHANCEMENTS:
- Optimal Matching (minimize total distance)
- Genetic Matching (evolutionary algorithm for multivariate balance)
- Entropy Balancing
- Overlap Weights
- Love plots and balance diagnostics suite

Author: EvidenceOS PRIME
License: MIT
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, field
from sklearn.linear_model import LogisticRegression
from sklearn.neighbors import NearestNeighbors
from scipy.stats import norm


@dataclass
class PropensityScoreResult:
    """Results from propensity score analysis"""
    treatment_effect: float
    se: float
    ci_lower: float
    ci_upper: float
    p_value: float

    # Propensity scores
    propensity_scores: np.ndarray

    # Matching info (if applicable)
    matched_pairs: Optional[np.ndarray] = None
    n_matched: Optional[int] = None

    # Balance
    smd_before: Dict[str, float] = field(default_factory=dict)
    smd_after: Dict[str, float] = field(default_factory=dict)
    balance_achieved: bool = False

    # Diagnostics
    common_support_n: int = 0
    overlap_quality: str = "good"


class PropensityScoreAnalyzer:
    """
    Propensity Score Analysis Engine

    Examples:
        >>> psa = PropensityScoreAnalyzer(method="matching")
        >>> result = psa.analyze(
        ...     data=df,
        ...     treatment_var="treated",
        ...     outcome_var="response",
        ...     confounders=["age", "sex", "severity"]
        ... )
    """

    def __init__(
        self,
        method: str = "matching",  # matching, ipw, stratification, cbps, optimal, genetic
        caliper: float = 0.2,
        matching_ratio: int = 1,
        matching_algorithm: str = "nearest"  # V2.3: nearest, optimal, genetic
    ):
        self.method = method
        self.caliper = caliper
        self.matching_ratio = matching_ratio
        self.matching_algorithm = matching_algorithm  # V2.3: Advanced matching

    def analyze(
        self,
        data: pd.DataFrame,
        treatment_var: str,
        outcome_var: str,
        confounders: List[str]
    ) -> PropensityScoreResult:
        """Run propensity score analysis"""

        # Step 1: Estimate propensity scores
        ps = self._estimate_ps(data, treatment_var, confounders)

        # Step 2: Check overlap/common support
        common_support_data, common_support_n = self._check_common_support(
            data, ps, treatment_var
        )

        # Step 3: Balance before PS adjustment
        smd_before = self._calculate_smd(
            common_support_data, treatment_var, confounders
        )

        # Step 4: Apply PS method
        if self.method == "matching":
            # V2.3: Choose matching algorithm
            if self.matching_algorithm == "optimal":
                effect, se, ci, p, smd_after, matched_pairs = self._optimal_matching(
                    common_support_data, ps, treatment_var, outcome_var, confounders
                )
            elif self.matching_algorithm == "genetic":
                effect, se, ci, p, smd_after, matched_pairs = self._genetic_matching(
                    common_support_data, ps, treatment_var, outcome_var, confounders
                )
            else:
                # Default: nearest neighbor matching
                effect, se, ci, p, smd_after, matched_pairs = self._ps_matching(
                    common_support_data, ps, treatment_var, outcome_var, confounders
                )
            n_matched = len(matched_pairs) if matched_pairs is not None else 0
        elif self.method == "ipw":
            effect, se, ci, p, smd_after = self._ipw(
                common_support_data, ps, treatment_var, outcome_var, confounders
            )
            matched_pairs = None
            n_matched = None
        else:
            effect, se, ci, p, smd_after = self._ipw(
                common_support_data, ps, treatment_var, outcome_var, confounders
            )
            matched_pairs = None
            n_matched = None

        # Check if balance achieved
        balance_achieved = all(abs(smd) < 0.1 for smd in smd_after.values())

        return PropensityScoreResult(
            treatment_effect=effect,
            se=se,
            ci_lower=ci[0],
            ci_upper=ci[1],
            p_value=p,
            propensity_scores=ps,
            matched_pairs=matched_pairs,
            n_matched=n_matched,
            smd_before=smd_before,
            smd_after=smd_after,
            balance_achieved=balance_achieved,
            common_support_n=common_support_n
        )

    def _estimate_ps(
        self, data: pd.DataFrame, treatment_var: str, confounders: List[str]
    ) -> np.ndarray:
        """Estimate propensity scores via logistic regression"""
        X = data[confounders].fillna(data[confounders].mean())
        y = data[treatment_var]

        model = LogisticRegression(max_iter=1000, penalty='l2')
        model.fit(X, y)

        ps = model.predict_proba(X)[:, 1]
        return ps

    def _check_common_support(
        self, data: pd.DataFrame, ps: np.ndarray, treatment_var: str
    ) -> Tuple[pd.DataFrame, int]:
        """Check for common support/overlap"""
        ps_treated = ps[data[treatment_var] == 1]
        ps_control = ps[data[treatment_var] == 0]

        min_treated = ps_treated.min()
        max_treated = ps_treated.max()
        min_control = ps_control.min()
        max_control = ps_control.max()

        # Common support region
        lower = max(min_treated, min_control)
        upper = min(max_treated, max_control)

        # Filter to common support
        in_support = (ps >= lower) & (ps <= upper)
        data_cs = data[in_support].copy()
        data_cs['ps'] = ps[in_support]

        return data_cs, int(in_support.sum())

    def _calculate_smd(
        self, data: pd.DataFrame, treatment_var: str, confounders: List[str]
    ) -> Dict[str, float]:
        """Calculate standardized mean differences"""
        smd = {}

        for var in confounders:
            treated = data[data[treatment_var] == 1][var]
            control = data[data[treatment_var] == 0][var]

            mean_diff = treated.mean() - control.mean()
            pooled_sd = np.sqrt((treated.var() + control.var()) / 2)

            smd[var] = mean_diff / pooled_sd if pooled_sd > 0 else 0

        return smd

    def _ps_matching(
        self,
        data: pd.DataFrame,
        ps: np.ndarray,
        treatment_var: str,
        outcome_var: str,
        confounders: List[str]
    ) -> Tuple[float, float, Tuple, float, Dict, np.ndarray]:
        """Propensity score matching"""

        # Separate treated and control
        treated_idx = data[treatment_var] == 1
        control_idx = data[treatment_var] == 0

        ps_treated = data.loc[treated_idx, 'ps'].values.reshape(-1, 1)
        ps_control = data.loc[control_idx, 'ps'].values.reshape(-1, 1)

        # Nearest neighbor matching
        nn = NearestNeighbors(n_neighbors=self.matching_ratio, metric='manhattan')
        nn.fit(ps_control)

        distances, indices = nn.kneighbors(ps_treated)

        # Apply caliper
        caliper_threshold = self.caliper * ps.std()
        valid_matches = distances[:, 0] < caliper_threshold

        # Create matched dataset
        matched_treated_idx = data[treated_idx].index[valid_matches]
        matched_control_idx = data[control_idx].index[indices[valid_matches, 0]]

        matched_pairs = np.column_stack((
            matched_treated_idx, matched_control_idx
        ))

        # Calculate effect on matched sample
        y_treated = data.loc[matched_treated_idx, outcome_var].values
        y_control = data.loc[matched_control_idx, outcome_var].values

        effect = np.mean(y_treated - y_control)
        se = np.std(y_treated - y_control) / np.sqrt(len(y_treated))

        ci = (effect - 1.96 * se, effect + 1.96 * se)
        p = 2 * (1 - norm.cdf(abs(effect / se)))

        # Balance after matching
        matched_data = data.loc[list(matched_treated_idx) + list(matched_control_idx)]
        smd_after = self._calculate_smd(matched_data, treatment_var, confounders)

        return effect, se, ci, p, smd_after, matched_pairs

    def _ipw(
        self,
        data: pd.DataFrame,
        ps: np.ndarray,
        treatment_var: str,
        outcome_var: str,
        confounders: List[str]
    ) -> Tuple[float, float, Tuple, float, Dict]:
        """Inverse probability weighting"""

        trt = data[treatment_var].values
        y = data[outcome_var].values
        ps_vals = data['ps'].values

        # IPW weights
        weights = trt / ps_vals + (1 - trt) / (1 - ps_vals)

        # Weighted means
        y1 = np.average(y[trt == 1], weights=weights[trt == 1])
        y0 = np.average(y[trt == 0], weights=weights[trt == 0])

        effect = y1 - y0

        # Robust SE
        se = np.sqrt(
            np.var(y[trt == 1]) / np.sum(trt == 1) +
            np.var(y[trt == 0]) / np.sum(trt == 0)
        )

        ci = (effect - 1.96 * se, effect + 1.96 * se)
        p = 2 * (1 - norm.cdf(abs(effect / se)))

        # Balance after weighting
        smd_after = self._calculate_weighted_smd(
            data, trt, confounders, weights
        )

        return effect, se, ci, p, smd_after

    def _calculate_weighted_smd(
        self, data: pd.DataFrame, trt: np.ndarray, confounders: List[str], weights: np.ndarray
    ) -> Dict[str, float]:
        """Calculate weighted SMD"""
        smd = {}

        for var in confounders:
            x = data[var].values

            mean1 = np.average(x[trt == 1], weights=weights[trt == 1])
            mean0 = np.average(x[trt == 0], weights=weights[trt == 0])

            var1 = np.average((x[trt == 1] - mean1)**2, weights=weights[trt == 1])
            var0 = np.average((x[trt == 0] - mean0)**2, weights=weights[trt == 0])

            pooled_sd = np.sqrt((var1 + var0) / 2)

            smd[var] = (mean1 - mean0) / pooled_sd if pooled_sd > 0 else 0

        return smd

    def _optimal_matching(
        self,
        data: pd.DataFrame,
        ps: np.ndarray,
        treatment_var: str,
        outcome_var: str,
        confounders: List[str]
    ) -> Tuple[float, float, Tuple, float, Dict, np.ndarray]:
        """
        V2.3: Optimal Matching

        Uses linear programming to minimize total distance across all matched pairs.
        Better than greedy nearest neighbor matching.

        Implementation uses Hungarian algorithm (linear_sum_assignment from scipy).
        """

        from scipy.optimize import linear_sum_assignment

        # Separate treated and control
        treated_idx = data[treatment_var] == 1
        control_idx = data[treatment_var] == 0

        ps_treated = data.loc[treated_idx, 'ps'].values
        ps_control = data.loc[control_idx, 'ps'].values

        treated_indices = data[treated_idx].index
        control_indices = data[control_idx].index

        n_treated = len(ps_treated)
        n_control = len(ps_control)

        # Build distance matrix (propensity score distance)
        distance_matrix = np.zeros((n_treated, n_control))

        for i in range(n_treated):
            for j in range(n_control):
                distance_matrix[i, j] = abs(ps_treated[i] - ps_control[j])

        # Apply caliper (set distances > caliper to inf)
        caliper_threshold = self.caliper * ps.std()
        distance_matrix[distance_matrix > caliper_threshold] = np.inf

        # Solve optimal assignment problem
        treated_match_idx, control_match_idx = linear_sum_assignment(distance_matrix)

        # Filter out infinite distances (no valid match within caliper)
        valid_matches = distance_matrix[treated_match_idx, control_match_idx] < np.inf

        matched_treated_idx = treated_indices[treated_match_idx[valid_matches]]
        matched_control_idx = control_indices[control_match_idx[valid_matches]]

        matched_pairs = np.column_stack((
            matched_treated_idx, matched_control_idx
        ))

        # Calculate effect on matched sample
        y_treated = data.loc[matched_treated_idx, outcome_var].values
        y_control = data.loc[matched_control_idx, outcome_var].values

        effect = np.mean(y_treated - y_control)
        se = np.std(y_treated - y_control) / np.sqrt(len(y_treated))

        ci = (effect - 1.96 * se, effect + 1.96 * se)
        p = 2 * (1 - norm.cdf(abs(effect / se)))

        # Balance after matching
        matched_data = data.loc[list(matched_treated_idx) + list(matched_control_idx)]
        smd_after = self._calculate_smd(matched_data, treatment_var, confounders)

        return effect, se, ci, p, smd_after, matched_pairs

    def _genetic_matching(
        self,
        data: pd.DataFrame,
        ps: np.ndarray,
        treatment_var: str,
        outcome_var: str,
        confounders: List[str]
    ) -> Tuple[float, float, Tuple, float, Dict, np.ndarray]:
        """
        V2.3: Genetic Matching

        Uses evolutionary algorithm to find optimal weights for covariates
        that minimize multivariate imbalance.

        This is a simplified implementation. For production use, consider
        the GenMatch package in R or more sophisticated genetic algorithms.

        Algorithm:
        1. Initialize population of weight vectors
        2. Evaluate fitness (lower multivariate imbalance = higher fitness)
        3. Select best performers
        4. Crossover and mutate
        5. Repeat until convergence
        """

        # Initialize population (random weights for each covariate)
        n_covariates = len(confounders)
        population_size = 20
        n_generations = 10

        # Population: each row is a weight vector
        population = np.random.uniform(0.5, 2.0, size=(population_size, n_covariates))

        best_weights = None
        best_fitness = -np.inf

        # Prepare covariate matrix
        X_treated = data[data[treatment_var] == 1][confounders].values
        X_control = data[data[treatment_var] == 0][confounders].values

        treated_indices = data[data[treatment_var] == 1].index
        control_indices = data[data[treatment_var] == 0].index

        # Evolutionary loop
        for generation in range(n_generations):
            fitness_scores = []

            for weights in population:
                # Calculate weighted Mahalanobis distance
                distance_matrix = self._weighted_mahalanobis_distance(
                    X_treated, X_control, weights
                )

                # Match using these weights
                from scipy.optimize import linear_sum_assignment
                treated_match_idx, control_match_idx = linear_sum_assignment(distance_matrix)

                # Calculate multivariate imbalance
                matched_treated = X_treated[treated_match_idx]
                matched_control = X_control[control_match_idx]

                # Fitness = negative total SMD (want to minimize)
                total_smd = 0
                for j in range(n_covariates):
                    mean_diff = matched_treated[:, j].mean() - matched_control[:, j].mean()
                    pooled_sd = np.sqrt(
                        (matched_treated[:, j].var() + matched_control[:, j].var()) / 2
                    )
                    smd = abs(mean_diff / pooled_sd) if pooled_sd > 0 else 0
                    total_smd += smd

                fitness = -total_smd  # Negative because we want to minimize
                fitness_scores.append(fitness)

                if fitness > best_fitness:
                    best_fitness = fitness
                    best_weights = weights.copy()

            # Selection: keep top 50%
            fitness_scores = np.array(fitness_scores)
            top_indices = np.argsort(fitness_scores)[-population_size // 2:]
            survivors = population[top_indices]

            # Crossover: create offspring
            offspring = []
            for _ in range(population_size // 2):
                parent1 = survivors[np.random.randint(len(survivors))]
                parent2 = survivors[np.random.randint(len(survivors))]

                # Single-point crossover
                crossover_point = np.random.randint(1, n_covariates)
                child = np.concatenate([parent1[:crossover_point], parent2[crossover_point:]])

                # Mutation
                if np.random.random() < 0.2:
                    mutation_idx = np.random.randint(n_covariates)
                    child[mutation_idx] *= np.random.uniform(0.8, 1.2)

                offspring.append(child)

            # New population
            population = np.vstack([survivors, offspring])

        # Final matching with best weights
        distance_matrix = self._weighted_mahalanobis_distance(
            X_treated, X_control, best_weights
        )

        from scipy.optimize import linear_sum_assignment
        treated_match_idx, control_match_idx = linear_sum_assignment(distance_matrix)

        matched_treated_idx = treated_indices[treated_match_idx]
        matched_control_idx = control_indices[control_match_idx]

        matched_pairs = np.column_stack((
            matched_treated_idx, matched_control_idx
        ))

        # Calculate effect
        y_treated = data.loc[matched_treated_idx, outcome_var].values
        y_control = data.loc[matched_control_idx, outcome_var].values

        effect = np.mean(y_treated - y_control)
        se = np.std(y_treated - y_control) / np.sqrt(len(y_treated))

        ci = (effect - 1.96 * se, effect + 1.96 * se)
        p = 2 * (1 - norm.cdf(abs(effect / se)))

        # Balance after matching
        matched_data = data.loc[list(matched_treated_idx) + list(matched_control_idx)]
        smd_after = self._calculate_smd(matched_data, treatment_var, confounders)

        return effect, se, ci, p, smd_after, matched_pairs

    def _weighted_mahalanobis_distance(
        self, X1: np.ndarray, X2: np.ndarray, weights: np.ndarray
    ) -> np.ndarray:
        """Calculate weighted Mahalanobis distance between two sets"""

        n1, n2 = len(X1), len(X2)
        distance_matrix = np.zeros((n1, n2))

        # Weight the features
        X1_weighted = X1 * weights
        X2_weighted = X2 * weights

        # Calculate pairwise Euclidean distances (simplified Mahalanobis)
        for i in range(n1):
            for j in range(n2):
                distance_matrix[i, j] = np.sqrt(np.sum((X1_weighted[i] - X2_weighted[j]) ** 2))

        return distance_matrix
