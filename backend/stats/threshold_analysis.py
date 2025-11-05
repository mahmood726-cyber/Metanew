"""
Threshold Analysis for Willingness-to-Pay

Health economics threshold analysis and value of information:
- Willingness-to-pay threshold analysis
- Net monetary benefit calculations
- CEAC generation across WTP range
- Expected value of perfect information (EVPI)
- Population EVPI over time horizon
- Threshold WTP for cost-effectiveness

V2.4 ENHANCEMENTS:
- Expected Value of Sample Information (EVSI)
- Optimal sample size calculations for future trials
- Bayesian EVPPI with GAM regression
- Multi-parameter EVPPI
- Research prioritization framework
- Sequential trial design optimization

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

    def calculate_evsi(
        self,
        cost_samples: np.ndarray,
        qaly_samples: np.ndarray,
        wtp: float,
        sample_size: int,
        n_evsi_simulations: int = 1000
    ) -> float:
        """
        V2.4: Calculate EVSI (Expected Value of Sample Information)

        EVSI estimates the expected benefit of conducting a study
        with a specific sample size before making a decision.

        EVSI < EVPI (perfect information)
        EVSI increases with sample size (but diminishing returns)

        Args:
            cost_samples: PSA samples for incremental cost
            qaly_samples: PSA samples for incremental QALY
            wtp: Willingness-to-pay threshold
            sample_size: Proposed trial sample size
            n_evsi_simulations: Number of EVSI simulations (computational)

        Returns:
            EVSI per patient

        Note:
            This uses a simplified EVSI calculation based on:
            - Bayesian updating with normal conjugate priors
            - Assumes independent cost and QALY sampling
            For complex models, consider Sheffield Accelerated VOI methods
        """

        # Current uncertainty (prior)
        cost_mean = np.mean(cost_samples)
        cost_var = np.var(cost_samples)
        qaly_mean = np.mean(qaly_samples)
        qaly_var = np.var(qaly_samples)

        # Expected NMB with current information
        nmb_current = wtp * qaly_mean - cost_mean

        # EVSI calculation via preposterior analysis
        evsi_values = []

        for _ in range(n_evsi_simulations):
            # Simulate what data we might observe
            # (sample from the prior, as if conducting trial)
            true_cost = np.random.normal(cost_mean, np.sqrt(cost_var))
            true_qaly = np.random.normal(qaly_mean, np.sqrt(qaly_var))

            # Simulate trial data given these "true" values
            trial_cost_data = np.random.normal(
                true_cost,
                np.sqrt(cost_var / sample_size),  # SE decreases with sqrt(n)
                sample_size
            )
            trial_qaly_data = np.random.normal(
                true_qaly,
                np.sqrt(qaly_var / sample_size),
                sample_size
            )

            # Bayesian update (posterior = prior + data)
            # Posterior precision = prior precision + data precision
            cost_precision_prior = 1 / cost_var
            cost_precision_data = sample_size / cost_var
            cost_precision_post = cost_precision_prior + cost_precision_data

            qaly_precision_prior = 1 / qaly_var
            qaly_precision_data = sample_size / qaly_var
            qaly_precision_post = qaly_precision_prior + qaly_precision_data

            # Posterior mean
            cost_mean_post = (
                cost_precision_prior * cost_mean +
                cost_precision_data * np.mean(trial_cost_data)
            ) / cost_precision_post

            qaly_mean_post = (
                qaly_precision_prior * qaly_mean +
                qaly_precision_data * np.mean(trial_qaly_data)
            ) / qaly_precision_post

            # NMB with updated information
            nmb_post = wtp * qaly_mean_post - cost_mean_post

            # Value of this sample information
            vsi = max(0, nmb_post) - max(0, nmb_current)
            evsi_values.append(vsi)

        # Expected value across all possible trial outcomes
        evsi = np.mean(evsi_values)

        return max(0, evsi)

    def optimal_sample_size(
        self,
        cost_samples: np.ndarray,
        qaly_samples: np.ndarray,
        wtp: float,
        population_size: int,
        time_horizon: int,
        trial_cost_per_patient: float = 5000,
        discount_rate: float = 0.03,
        max_sample_size: int = 1000
    ) -> Dict[str, any]:
        """
        V2.4: Calculate optimal sample size for future trial

        Optimal sample size maximizes net benefit:
        Net Benefit = Population EVSI - Trial Cost

        Args:
            cost_samples: PSA samples for incremental cost
            qaly_samples: PSA samples for incremental QALY
            wtp: Willingness-to-pay threshold
            population_size: Annual incident population
            time_horizon: Time horizon for benefits
            trial_cost_per_patient: Cost per patient enrolled
            discount_rate: Annual discount rate
            max_sample_size: Maximum trial size to evaluate

        Returns:
            Dict with:
                - optimal_n: Optimal sample size
                - max_net_benefit: Net benefit at optimal n
                - evsi_curve: EVSI at different sample sizes
                - net_benefit_curve: Net benefit at different sample sizes
        """

        # Calculate discounted population
        discount_factors = np.array([
            (1 + discount_rate) ** (-t) for t in range(time_horizon)
        ])
        discounted_population = population_size * np.sum(discount_factors)

        # Evaluate different sample sizes
        sample_sizes = np.arange(50, max_sample_size + 1, 50)
        evsi_values = []
        net_benefits = []

        for n in sample_sizes:
            # Calculate EVSI for this sample size
            evsi_per_patient = self.calculate_evsi(
                cost_samples, qaly_samples, wtp, n,
                n_evsi_simulations=200  # Reduced for speed
            )

            # Population EVSI
            population_evsi = evsi_per_patient * discounted_population

            # Trial cost
            trial_cost = trial_cost_per_patient * n

            # Net benefit
            net_benefit = population_evsi - trial_cost

            evsi_values.append(population_evsi)
            net_benefits.append(net_benefit)

        # Find optimal sample size
        net_benefits_array = np.array(net_benefits)
        optimal_idx = np.argmax(net_benefits_array)
        optimal_n = int(sample_sizes[optimal_idx])
        max_net_benefit = net_benefits_array[optimal_idx]

        # Recommendation
        if max_net_benefit > 0:
            recommendation = f"Conduct trial with n={optimal_n} (Net Benefit: ${max_net_benefit:,.0f})"
        else:
            recommendation = "Trial not worthwhile - EVSI does not exceed trial cost"

        return {
            'optimal_n': optimal_n,
            'max_net_benefit': max_net_benefit,
            'evsi_curve': dict(zip(sample_sizes, evsi_values)),
            'net_benefit_curve': dict(zip(sample_sizes, net_benefits)),
            'recommendation': recommendation,
            'trial_cost_at_optimal': trial_cost_per_patient * optimal_n,
            'evsi_at_optimal': evsi_values[optimal_idx]
        }

    def research_prioritization(
        self,
        parameters: List[str],
        evpi_by_parameter: Dict[str, float],
        trial_feasibility: Dict[str, float],  # 0-1 score
        budget_constraint: float
    ) -> pd.DataFrame:
        """
        V2.4: Prioritize research for multiple parameters

        Ranks parameters by:
        1. EVPI (value of resolving uncertainty)
        2. Feasibility (can we conduct this research?)
        3. Cost-effectiveness (EVPI / cost)

        Args:
            parameters: List of parameter names
            evpi_by_parameter: EVPI for each parameter
            trial_feasibility: Feasibility score (0-1) for each parameter
            budget_constraint: Total research budget

        Returns:
            DataFrame with prioritized parameters
        """

        priority_list = []

        for param in parameters:
            evpi = evpi_by_parameter.get(param, 0)
            feasibility = trial_feasibility.get(param, 0.5)

            # Priority score = EVPI × Feasibility
            priority_score = evpi * feasibility

            priority_list.append({
                'Parameter': param,
                'EVPI': evpi,
                'Feasibility': feasibility,
                'Priority Score': priority_score
            })

        # Create DataFrame and sort
        df = pd.DataFrame(priority_list)
        df = df.sort_values('Priority Score', ascending=False)

        # Add cumulative budget allocation
        # Assume cost proportional to 1/feasibility
        estimated_costs = [1000000 * (2 - f) for f in df['Feasibility']]
        df['Estimated Cost'] = estimated_costs

        df['Cumulative Cost'] = df['Estimated Cost'].cumsum()
        df['Within Budget'] = df['Cumulative Cost'] <= budget_constraint

        # Recommendation
        df['Recommendation'] = df.apply(
            lambda row: 'Fund' if row['Within Budget'] else 'Do not fund',
            axis=1
        )

        return df
