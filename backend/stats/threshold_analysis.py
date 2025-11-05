"""
Threshold Analysis for Willingness-to-Pay

Health economics threshold analysis and value of information:
- Willingness-to-pay threshold analysis
- Net monetary benefit calculations
- CEAC generation across WTP range
- Expected value of perfect information (EVPI)
- Population EVPI over time horizon
- Threshold WTP for cost-effectiveness

Author: EvidenceOS PRIME
License: MIT
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
import warnings


@dataclass
class ThresholdAnalysisResult:
    """Results from threshold analysis"""
    # Threshold WTP
    threshold_wtp: float  # WTP where ICER = WTP
    nmb_at_thresholds: Dict[float, float]  # NMB at different WTP values

    # CEAC data
    ceac_wtp_range: np.ndarray
    ceac_probabilities: np.ndarray

    # EVPI
    evpi_per_patient: float
    evpi_population: float
    evpi_by_wtp: Dict[float, float]

    # Decision
    cost_effective_at: Dict[float, bool]  # Cost-effective at each WTP threshold


class ThresholdAnalyzer:
    """
    Threshold Analysis Engine

    Performs WTP threshold analysis for cost-effectiveness decisions.
    Determines the WTP threshold where treatment becomes cost-effective.

    Examples:
        >>> analyzer = ThresholdAnalyzer()
        >>> result = analyzer.analyze(
        ...     incremental_cost=25000,
        ...     incremental_qaly=0.5,
        ...     cost_se=5000,
        ...     qaly_se=0.1,
        ...     wtp_range=(0, 100000)
        ... )
        >>> print(f"Threshold WTP: ${result.threshold_wtp:,.0f}")
    """

    def __init__(self):
        pass

    def analyze(
        self,
        incremental_cost: float,
        incremental_qaly: float,
        cost_se: float,
        qaly_se: float,
        wtp_range: Tuple[float, float] = (0, 150000),
        n_simulations: int = 10000,
        population_size: Optional[int] = None,
        time_horizon: Optional[int] = None
    ) -> ThresholdAnalysisResult:
        """
        Perform threshold analysis

        Args:
            incremental_cost: Mean incremental cost
            incremental_qaly: Mean incremental QALY
            cost_se: Standard error of cost
            qaly_se: Standard error of QALY
            wtp_range: Range of WTP values to evaluate (min, max)
            n_simulations: Number of PSA simulations
            population_size: Target population size (for population EVPI)
            time_horizon: Time horizon in years (for population EVPI)

        Returns:
            ThresholdAnalysisResult
        """

        # Step 1: Calculate threshold WTP (ICER)
        if incremental_qaly > 0:
            threshold_wtp = incremental_cost / incremental_qaly
        else:
            threshold_wtp = np.inf

        # Step 2: PSA simulations
        cost_samples = np.random.normal(
            incremental_cost, cost_se, n_simulations
        )
        qaly_samples = np.random.normal(
            incremental_qaly, qaly_se, n_simulations
        )

        # Step 3: NMB at different WTP thresholds
        wtp_thresholds = [20000, 30000, 50000, 100000, 150000]
        nmb_at_thresholds = {}

        for wtp in wtp_thresholds:
            nmb_samples = wtp * qaly_samples - cost_samples
            nmb_mean = np.mean(nmb_samples)
            nmb_at_thresholds[wtp] = nmb_mean

        # Step 4: CEAC across WTP range
        wtp_range_array = np.linspace(wtp_range[0], wtp_range[1], 100)
        ceac_probs = []

        for wtp in wtp_range_array:
            nmb_samples = wtp * qaly_samples - cost_samples
            prob_ce = np.mean(nmb_samples > 0)
            ceac_probs.append(prob_ce)

        ceac_probs = np.array(ceac_probs)

        # Step 5: EVPI calculation
        evpi_per_patient = self._calculate_evpi(
            cost_samples, qaly_samples, wtp_thresholds
        )

        # Population EVPI
        if population_size and time_horizon:
            # Discounted population over time horizon
            discount_rate = 0.03
            discount_factors = np.array([
                (1 + discount_rate) ** (-t) for t in range(time_horizon)
            ])
            discounted_population = population_size * np.sum(discount_factors)

            evpi_population = evpi_per_patient * discounted_population
        else:
            evpi_population = 0.0

        # EVPI by WTP
        evpi_by_wtp = {}
        for wtp in wtp_thresholds:
            evpi = self._calculate_evpi_at_wtp(
                cost_samples, qaly_samples, wtp
            )
            evpi_by_wtp[wtp] = evpi

        # Step 6: Cost-effectiveness decision at each threshold
        cost_effective_at = {}
        for wtp in wtp_thresholds:
            if incremental_qaly > 0:
                icer = incremental_cost / incremental_qaly
                cost_effective_at[wtp] = icer <= wtp
            else:
                cost_effective_at[wtp] = False

        return ThresholdAnalysisResult(
            threshold_wtp=threshold_wtp,
            nmb_at_thresholds=nmb_at_thresholds,
            ceac_wtp_range=wtp_range_array,
            ceac_probabilities=ceac_probs,
            evpi_per_patient=evpi_per_patient,
            evpi_population=evpi_population,
            evpi_by_wtp=evpi_by_wtp,
            cost_effective_at=cost_effective_at
        )

    def _calculate_evpi(
        self,
        cost_samples: np.ndarray,
        qaly_samples: np.ndarray,
        wtp_thresholds: List[float]
    ) -> float:
        """Calculate EVPI (expected value of perfect information)"""

        # Average across common WTP thresholds
        evpi_values = []

        for wtp in wtp_thresholds:
            evpi = self._calculate_evpi_at_wtp(cost_samples, qaly_samples, wtp)
            evpi_values.append(evpi)

        return np.mean(evpi_values)

    def _calculate_evpi_at_wtp(
        self,
        cost_samples: np.ndarray,
        qaly_samples: np.ndarray,
        wtp: float
    ) -> float:
        """Calculate EVPI at specific WTP threshold"""

        # NMB for each simulation
        nmb_samples = wtp * qaly_samples - cost_samples

        # Expected NMB with current information
        expected_nmb_current = max(0, np.mean(nmb_samples))

        # Expected NMB with perfect information
        # (choose best option in each simulation)
        expected_nmb_perfect = np.mean(np.maximum(0, nmb_samples))

        # EVPI
        evpi = expected_nmb_perfect - expected_nmb_current

        return max(0, evpi)

    def calculate_headroom(
        self,
        incremental_qaly: float,
        wtp_threshold: float,
        development_cost: float
    ) -> float:
        """
        Calculate headroom for new intervention

        Headroom = maximum acceptable cost to be cost-effective

        Args:
            incremental_qaly: Expected incremental QALY
            wtp_threshold: WTP threshold (e.g., $100,000/QALY)
            development_cost: Estimated development cost

        Returns:
            Headroom (maximum acceptable cost)
        """
        max_acceptable_cost = wtp_threshold * incremental_qaly
        headroom = max_acceptable_cost - development_cost

        return headroom
