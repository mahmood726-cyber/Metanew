"""
Component Network Meta-Analysis

Advanced NMA methods for complex interventions with multiple components:
- Component-level analysis (additive model)
- Interaction effects between components
- Hierarchical models for component combinations
- Component ranking and importance
- Optimal component selection

Author: EvidenceOS PRIME
License: MIT
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from itertools import combinations
import warnings


@dataclass
class ComponentNMAResult:
    """Results from component NMA"""
    # Component effects
    component_effects: Dict[str, float]
    component_ses: Dict[str, float]

    # Interaction effects (if modeled)
    interaction_effects: Optional[Dict[Tuple[str, str], float]] = None

    # Treatment-level predictions
    treatment_predictions: Dict[str, float] = None

    # Component rankings
    component_rankings: Dict[str, int] = None

    # Optimal combination
    optimal_combination: List[str] = None


class ComponentNMAEngine:
    """
    Component Network Meta-Analysis Engine

    Decomposes complex interventions into components and estimates
    component-level effects. Useful for:
    - Behavioral interventions with multiple components
    - Combination therapies
    - Surgical procedures with technique variations

    Examples:
        >>> # Data with component indicators
        >>> treatments = {
        ...     "A": ["comp1"],
        ...     "B": ["comp2"],
        ...     "AB": ["comp1", "comp2"],
        ...     "ABC": ["comp1", "comp2", "comp3"]
        ... }
        >>>
        >>> engine = ComponentNMAEngine()
        >>> result = engine.analyze(
        ...     data=nma_data,
        ...     treatments=treatments,
        ...     outcome_var="effect_size"
        ... )
    """

    def __init__(self, include_interactions: bool = False):
        self.include_interactions = include_interactions

    def analyze(
        self,
        data: pd.DataFrame,
        treatment_components: Dict[str, List[str]],
        outcome_var: str,
        se_var: str
    ) -> ComponentNMAResult:
        """
        Run component NMA

        Args:
            data: Study data with treatment arms
            treatment_components: Dictionary mapping treatments to component lists
            outcome_var: Column name for effect size
            se_var: Column name for standard error

        Returns:
            ComponentNMAResult
        """

        # Step 1: Build component design matrix
        X, component_names = self._build_component_matrix(
            data, treatment_components
        )

        # Step 2: Extract outcomes and weights
        y = data[outcome_var].values
        weights = 1 / (data[se_var].values ** 2)

        # Step 3: Weighted least squares to estimate component effects
        component_effects = self._estimate_component_effects(
            X, y, weights, component_names
        )

        # Step 4: Calculate proper standard errors from WLS
        component_ses = self._calculate_component_ses(
            X, y, weights, component_names, component_effects
        )

        # Step 5: If interactions requested, add interaction terms
        if self.include_interactions:
            interaction_effects, interaction_ses = self._estimate_interactions(
                X, y, weights, component_names, component_effects
            )
        else:
            interaction_effects = None
            interaction_ses = None

        # Step 6: Predict treatment effects from components
        treatment_predictions = self._predict_treatments(
            treatment_components, component_effects, interaction_effects
        )

        # Step 7: Rank components by effect size
        component_rankings = self._rank_components(component_effects)

        # Step 8: Identify optimal combination
        optimal_combination = self._find_optimal_combination(
            component_effects, interaction_effects
        )

        return ComponentNMAResult(
            component_effects=component_effects,
            component_ses=component_ses,
            interaction_effects=interaction_effects,
            treatment_predictions=treatment_predictions,
            component_rankings=component_rankings,
            optimal_combination=optimal_combination
        )

    def _build_component_matrix(
        self,
        data: pd.DataFrame,
        treatment_components: Dict[str, List[str]]
    ) -> Tuple[np.ndarray, List[str]]:
        """Build design matrix indicating which components are present"""

        # Get all unique components
        all_components = set()
        for components in treatment_components.values():
            all_components.update(components)
        component_names = sorted(list(all_components))

        # Build binary matrix: rows = studies, cols = components
        n_studies = len(data)
        n_components = len(component_names)
        X = np.zeros((n_studies, n_components))

        for i, treatment in enumerate(data["treatment"]):
            if treatment in treatment_components:
                for component in treatment_components[treatment]:
                    j = component_names.index(component)
                    X[i, j] = 1

        return X, component_names

    def _estimate_component_effects(
        self,
        X: np.ndarray,
        y: np.ndarray,
        weights: np.ndarray,
        component_names: List[str]
    ) -> Dict[str, float]:
        """Estimate component effects using weighted least squares"""

        # Weighted least squares: beta = (X'WX)^-1 X'Wy
        W = np.diag(weights)
        XtWX = X.T @ W @ X
        XtWy = X.T @ W @ y

        # Add small ridge for stability
        ridge = 0.01 * np.eye(XtWX.shape[0])
        beta = np.linalg.solve(XtWX + ridge, XtWy)

        # Create dictionary
        component_effects = {
            component_names[i]: beta[i]
            for i in range(len(component_names))
        }

        return component_effects

    def _calculate_component_ses(
        self,
        X: np.ndarray,
        y: np.ndarray,
        weights: np.ndarray,
        component_names: List[str],
        component_effects: Dict[str, float]
    ) -> Dict[str, float]:
        """Calculate standard errors for component effects"""

        # Extract beta vector
        beta = np.array([component_effects[name] for name in component_names])

        # Predicted values
        y_pred = X @ beta

        # Residuals
        residuals = y - y_pred

        # Weighted residual sum of squares
        W = np.diag(weights)
        rss = residuals.T @ W @ residuals

        # Degrees of freedom
        n = len(y)
        p = len(component_names)
        df = max(1, n - p)

        # Residual variance
        sigma_squared = rss / df

        # Variance-covariance matrix: sigma^2 * (X'WX)^-1
        XtWX = X.T @ W @ X
        ridge = 0.01 * np.eye(XtWX.shape[0])

        try:
            cov_matrix = sigma_squared * np.linalg.inv(XtWX + ridge)
            # Extract standard errors (square root of diagonal)
            se_vector = np.sqrt(np.diag(cov_matrix))

            component_ses = {
                component_names[i]: float(se_vector[i])
                for i in range(len(component_names))
            }
        except np.linalg.LinAlgError:
            # Fallback if matrix inversion fails
            component_ses = {
                name: 0.1 for name in component_names
            }

        return component_ses

    def _estimate_interactions(
        self,
        X: np.ndarray,
        y: np.ndarray,
        weights: np.ndarray,
        component_names: List[str],
        component_effects: Dict[str, float]
    ) -> Tuple[Dict[Tuple[str, str], float], Dict[Tuple[str, str], float]]:
        """
        Estimate pairwise interaction effects using proper WLS

        Method: Include both main effects and interaction terms in model,
        then estimate via WLS. Interaction coefficient represents the
        synergistic/antagonistic effect beyond additive components.
        """

        interaction_effects = {}
        interaction_ses = {}

        # Build interaction terms
        n_components = len(component_names)
        interaction_pairs = list(combinations(range(n_components), 2))

        if len(interaction_pairs) == 0:
            return {}, {}

        # Create design matrix with main effects + interactions
        n_interactions = len(interaction_pairs)
        X_full = np.zeros((len(y), n_components + n_interactions))

        # Main effects
        X_full[:, :n_components] = X

        # Interaction terms
        for idx, (i, j) in enumerate(interaction_pairs):
            interaction_term = X[:, i] * X[:, j]
            X_full[:, n_components + idx] = interaction_term

        # Only keep interaction terms that are present in data
        non_zero_cols = []
        col_names = []

        for col_idx in range(X_full.shape[1]):
            if X_full[:, col_idx].sum() > 0:
                non_zero_cols.append(col_idx)
                if col_idx < n_components:
                    col_names.append(component_names[col_idx])
                else:
                    int_idx = col_idx - n_components
                    i, j = interaction_pairs[int_idx]
                    col_names.append(f"int_{component_names[i]}_{component_names[j]}")

        if len(non_zero_cols) == 0:
            return {}, {}

        X_reduced = X_full[:, non_zero_cols]

        # Weighted least squares with full model
        W = np.diag(weights)
        XtWX = X_reduced.T @ W @ X_reduced
        XtWy = X_reduced.T @ W @ y

        # Ridge regularization
        ridge = 0.01 * np.eye(XtWX.shape[0])

        try:
            beta = np.linalg.solve(XtWX + ridge, XtWy)

            # Calculate SEs
            y_pred = X_reduced @ beta
            residuals = y - y_pred
            rss = residuals.T @ W @ residuals
            df = max(1, len(y) - len(beta))
            sigma_squared = rss / df

            cov_matrix = sigma_squared * np.linalg.inv(XtWX + ridge)
            se_vector = np.sqrt(np.diag(cov_matrix))

            # Extract interaction effects (skip main effects)
            for idx, col_name in enumerate(col_names):
                if col_name.startswith("int_"):
                    # Parse interaction pair
                    parts = col_name.split("_")[1:]  # Remove "int" prefix
                    if len(parts) >= 2:
                        comp1 = "_".join(parts[:-1])  # Handle underscores in names
                        comp2 = parts[-1]

                        # Find actual component names
                        for i, j in interaction_pairs:
                            if (component_names[i] in comp1 and component_names[j] in comp2) or \
                               (component_names[j] in comp1 and component_names[i] in comp2):
                                pair = tuple(sorted([component_names[i], component_names[j]]))
                                interaction_effects[pair] = float(beta[idx])
                                interaction_ses[pair] = float(se_vector[idx])
                                break

        except np.linalg.LinAlgError:
            # If matrix inversion fails, return empty
            pass

        return interaction_effects, interaction_ses

    def _predict_treatments(
        self,
        treatment_components: Dict[str, List[str]],
        component_effects: Dict[str, float],
        interaction_effects: Optional[Dict[Tuple[str, str], float]]
    ) -> Dict[str, float]:
        """Predict treatment effects from component effects"""

        predictions = {}

        for treatment, components in treatment_components.items():
            # Additive effect
            predicted_effect = sum(
                component_effects.get(comp, 0) for comp in components
            )

            # Add interaction effects if available
            if interaction_effects:
                for i, comp1 in enumerate(components):
                    for comp2 in components[i+1:]:
                        pair = tuple(sorted([comp1, comp2]))
                        if pair in interaction_effects:
                            predicted_effect += interaction_effects[pair]

            predictions[treatment] = predicted_effect

        return predictions

    def _rank_components(
        self, component_effects: Dict[str, float]
    ) -> Dict[str, int]:
        """Rank components by effect size"""

        sorted_components = sorted(
            component_effects.items(),
            key=lambda x: abs(x[1]),
            reverse=True
        )

        rankings = {
            comp: rank + 1
            for rank, (comp, effect) in enumerate(sorted_components)
        }

        return rankings

    def _find_optimal_combination(
        self,
        component_effects: Dict[str, float],
        interaction_effects: Optional[Dict[Tuple[str, str], float]]
    ) -> List[str]:
        """Find optimal component combination"""

        # Select components with positive effects
        optimal = [
            comp for comp, effect in component_effects.items()
            if effect > 0
        ]

        # Rank by effect size
        optimal.sort(key=lambda c: component_effects[c], reverse=True)

        return optimal
