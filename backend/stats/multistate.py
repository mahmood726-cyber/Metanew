"""
Multi-State Models Framework

Advanced multi-state survival models for complex disease progression:
- Illness-death models
- Progressive models (e.g., Stable → Progression → Death)
- Competing risks
- Semi-Markov and non-Markov models
- Transition probability estimation
- State occupancy probabilities
- Integration with meta-analysis HRs

Author: EvidenceOS PRIME
License: MIT
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, field
from scipy.integrate import odeint
from scipy.stats import weibull_min, expon, norm


@dataclass
class MultiStateModel:
    """Multi-state model specification"""
    states: List[str]
    transitions: List[Tuple[str, str]]  # (from_state, to_state)
    transition_rates: Dict[Tuple[str, str], float]
    time_horizon: float = 10.0
    cycle_length: float = 1.0


@dataclass
class MultiStateResult:
    """Results from multi-state model"""
    state_occupancy: pd.DataFrame  # Time x State probabilities
    transition_probs: Dict[Tuple[str, str], np.ndarray]
    expected_lifetime: Dict[str, float]
    life_years: Dict[str, float]

    # For HTA
    qalys_per_state: Optional[Dict[str, float]] = None
    costs_per_state: Optional[Dict[str, float]] = None


class MultiStateEngine:
    """
    Multi-State Model Engine

    Implements flexible multi-state survival models including:
    - 3-state illness-death (Stable → Progression → Death)
    - 4-state models with competing events
    - Arbitrary state space models

    Examples:
        >>> model_spec = MultiStateModel(
        ...     states=["Stable", "Progressed", "Dead"],
        ...     transitions=[
        ...         ("Stable", "Progressed"),
        ...         ("Stable", "Dead"),
        ...         ("Progressed", "Dead")
        ...     ],
        ...     transition_rates={
        ...         ("Stable", "Progressed"): 0.15,
        ...         ("Stable", "Dead"): 0.05,
        ...         ("Progressed", "Dead"): 0.30
        ...     },
        ...     time_horizon=10
        ... )
        >>> engine = MultiStateEngine(model_spec)
        >>> result = engine.run_model()
    """

    def __init__(self, model: MultiStateModel):
        self.model = model
        self.n_states = len(model.states)
        self.state_idx = {state: i for i, state in enumerate(model.states)}

    def run_model(
        self,
        initial_state: str = None,
        utilities: Optional[Dict[str, float]] = None,
        costs: Optional[Dict[str, float]] = None,
        discount_rate: float = 0.03
    ) -> MultiStateResult:
        """
        Run multi-state model simulation

        Args:
            initial_state: Starting state (default: first state)
            utilities: Utility values per state (for QALY calculation)
            costs: Cost per cycle per state
            discount_rate: Annual discount rate

        Returns:
            MultiStateResult with state occupancies and outcomes
        """
        if initial_state is None:
            initial_state = self.model.states[0]

        # Time grid
        n_cycles = int(self.model.time_horizon / self.model.cycle_length)
        time_grid = np.linspace(0, self.model.time_horizon, n_cycles + 1)

        # Build transition matrix
        Q = self._build_rate_matrix()

        # Solve Kolmogorov forward equations
        state_probs = self._solve_kolmogorov(Q, initial_state, time_grid)

        # Create DataFrame
        state_occupancy_df = pd.DataFrame(
            state_probs,
            columns=self.model.states,
            index=time_grid
        )

        # Calculate transition probabilities
        transition_probs = self._calculate_transition_probs(Q, time_grid)

        # Expected lifetime in each state
        expected_lifetime = self._calculate_expected_lifetime(state_occupancy_df)

        # Life years (area under state occupancy curve)
        life_years = self._calculate_life_years(state_occupancy_df)

        # QALYs and costs if utilities/costs provided
        if utilities:
            qalys = self._calculate_qalys(
                state_occupancy_df, utilities, discount_rate
            )
        else:
            qalys = None

        if costs:
            total_costs = self._calculate_costs(
                state_occupancy_df, costs, discount_rate
            )
        else:
            total_costs = None

        return MultiStateResult(
            state_occupancy=state_occupancy_df,
            transition_probs=transition_probs,
            expected_lifetime=expected_lifetime,
            life_years=life_years,
            qalys_per_state=qalys,
            costs_per_state=total_costs
        )

    def _build_rate_matrix(self) -> np.ndarray:
        """Build transition rate matrix Q"""
        Q = np.zeros((self.n_states, self.n_states))

        # Fill in transition rates
        for (from_state, to_state), rate in self.model.transition_rates.items():
            i = self.state_idx[from_state]
            j = self.state_idx[to_state]
            Q[i, j] = rate

        # Diagonal: negative sum of outgoing rates
        for i in range(self.n_states):
            Q[i, i] = -np.sum(Q[i, :])

        return Q

    def _solve_kolmogorov(
        self, Q: np.ndarray, initial_state: str, time_grid: np.ndarray
    ) -> np.ndarray:
        """Solve Kolmogorov forward equations"""

        # Initial distribution
        p0 = np.zeros(self.n_states)
        p0[self.state_idx[initial_state]] = 1.0

        # ODE: dp/dt = p * Q
        def dpdt(p, t):
            return p @ Q

        # Solve
        solution = odeint(dpdt, p0, time_grid)

        return solution

    def _calculate_transition_probs(
        self, Q: np.ndarray, time_grid: np.ndarray
    ) -> Dict[Tuple[str, str], np.ndarray]:
        """Calculate transition probabilities over time"""
        from scipy.linalg import expm

        trans_probs = {}

        for i, from_state in enumerate(self.model.states):
            for j, to_state in enumerate(self.model.states):
                if i != j and (from_state, to_state) in self.model.transitions:
                    # P(t) = exp(Q*t)
                    probs = np.array([
                        expm(Q * t)[i, j] for t in time_grid
                    ])
                    trans_probs[(from_state, to_state)] = probs

        return trans_probs

    def _calculate_expected_lifetime(
        self, state_occupancy: pd.DataFrame
    ) -> Dict[str, float]:
        """Calculate expected time in each state"""
        expected = {}

        for state in self.model.states:
            # Integrate state occupancy over time (trapezoidal rule)
            time_in_state = np.trapz(
                state_occupancy[state].values,
                state_occupancy.index.values
            )
            expected[state] = time_in_state

        return expected

    def _calculate_life_years(
        self, state_occupancy: pd.DataFrame
    ) -> Dict[str, float]:
        """Calculate life years per state"""
        # Same as expected lifetime
        return self._calculate_expected_lifetime(state_occupancy)

    def _calculate_qalys(
        self,
        state_occupancy: pd.DataFrame,
        utilities: Dict[str, float],
        discount_rate: float
    ) -> Dict[str, float]:
        """Calculate QALYs per state"""
        qalys = {}

        for state in self.model.states:
            if state in utilities:
                # Utility-weighted life years
                utility = utilities[state]
                time_in_state = state_occupancy[state].values
                time_grid = state_occupancy.index.values

                # Discount factors
                discount_factors = np.exp(-discount_rate * time_grid)

                # QALYs = integral of utility * state_prob * discount
                qaly = np.trapz(
                    utility * time_in_state * discount_factors,
                    time_grid
                )
                qalys[state] = qaly

        return qalys

    def _calculate_costs(
        self,
        state_occupancy: pd.DataFrame,
        costs: Dict[str, float],
        discount_rate: float
    ) -> Dict[str, float]:
        """Calculate total costs per state"""
        total_costs = {}

        for state in self.model.states:
            if state in costs:
                cost_per_cycle = costs[state]
                time_in_state = state_occupancy[state].values
                time_grid = state_occupancy.index.values

                # Discount factors
                discount_factors = np.exp(-discount_rate * time_grid)

                # Total cost
                total_cost = np.trapz(
                    cost_per_cycle * time_in_state * discount_factors,
                    time_grid
                )
                total_costs[state] = total_cost

        return total_costs

    def from_hr_meta_analysis(
        self,
        baseline_rates: Dict[Tuple[str, str], float],
        hazard_ratios: Dict[Tuple[str, str], float]
    ) -> 'MultiStateModel':
        """
        Create multi-state model from meta-analysis hazard ratios

        Args:
            baseline_rates: Baseline transition rates (control arm)
            hazard_ratios: HR from meta-analysis for each transition

        Returns:
            Updated MultiStateModel with HR-adjusted rates
        """
        adjusted_rates = {}

        for transition, baseline_rate in baseline_rates.items():
            if transition in hazard_ratios:
                hr = hazard_ratios[transition]
                adjusted_rates[transition] = baseline_rate * hr
            else:
                adjusted_rates[transition] = baseline_rate

        # Update model
        self.model.transition_rates = adjusted_rates

        return self.model


# Example usage
if __name__ == "__main__":
    # 3-state illness-death model
    model = MultiStateModel(
        states=["Stable", "Progressed", "Dead"],
        transitions=[
            ("Stable", "Progressed"),
            ("Stable", "Dead"),
            ("Progressed", "Dead")
        ],
        transition_rates={
            ("Stable", "Progressed"): 0.15,
            ("Stable", "Dead"): 0.02,
            ("Progressed", "Dead"): 0.25
        },
        time_horizon=10,
        cycle_length=0.25
    )

    engine = MultiStateEngine(model)

    result = engine.run_model(
        utilities={"Stable": 0.85, "Progressed": 0.60, "Dead": 0.0},
        costs={"Stable": 5000, "Progressed": 15000, "Dead": 0},
        discount_rate=0.03
    )

    print("State Occupancy:")
    print(result.state_occupancy.head())
    print("\nExpected Lifetime:")
    print(result.expected_lifetime)
    print("\nQALYs:")
    print(result.qalys_per_state)
