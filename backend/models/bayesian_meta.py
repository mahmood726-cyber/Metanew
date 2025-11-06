"""
Bayesian Meta-Analysis Module
Full Bayesian random-effects meta-analysis using PyMC
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple, Any
import warnings

try:
    import pymc as pm
    import arviz as az
    PYMC_AVAILABLE = True
except ImportError:
    PYMC_AVAILABLE = False
    warnings.warn(
        "PyMC not installed. Install with: pip install pymc arviz"
    )


class BayesianMetaAnalysis:
    """
    Bayesian random-effects meta-analysis

    Uses hierarchical Bayesian model with half-Cauchy prior on heterogeneity
    Based on: Gelman (2006) and Higgins et al. (2009) recommendations
    """

    def __init__(self):
        self.model = None
        self.trace = None
        self.summary = None

    def fit(
        self,
        yi: np.ndarray,
        sei: np.ndarray,
        n_samples: int = 2000,
        n_tune: int = 1000,
        n_chains: int = 4,
        target_accept: float = 0.95,
        random_seed: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Fit Bayesian random-effects meta-analysis model

        Model specification:
        - yi ~ Normal(theta_i, sei^2)  [Observed effect sizes]
        - theta_i ~ Normal(mu, tau^2)  [Study-specific true effects]
        - mu ~ Normal(0, 10)           [Pooled effect (vague prior)]
        - tau ~ HalfCauchy(0, 1)       [Between-study SD (recommended prior)]

        Args:
            yi: Effect sizes (e.g., log odds ratios)
            sei: Standard errors
            n_samples: Number of posterior samples per chain
            n_tune: Number of tuning steps
            n_chains: Number of MCMC chains
            target_accept: Target acceptance rate for NUTS sampler
            random_seed: Random seed for reproducibility

        Returns:
            Dictionary with posterior samples and diagnostics
        """
        if not PYMC_AVAILABLE:
            raise ImportError(
                "PyMC is not installed. Install with: pip install pymc arviz"
            )

        # Convert to numpy arrays
        yi = np.asarray(yi, dtype=float)
        sei = np.asarray(sei, dtype=float)
        n_studies = len(yi)

        # Validate inputs
        if len(sei) != n_studies:
            raise ValueError("yi and sei must have the same length")
        if np.any(sei <= 0):
            raise ValueError("Standard errors must be positive")
        if np.any(~np.isfinite(yi)) or np.any(~np.isfinite(sei)):
            raise ValueError("yi and sei must be finite")

        # Build Bayesian hierarchical model
        with pm.Model() as self.model:
            # Priors
            # Pooled effect (population mean)
            mu = pm.Normal("mu", mu=0, sigma=10)

            # Between-study heterogeneity (half-Cauchy recommended by Gelman)
            tau = pm.HalfCauchy("tau", beta=1)

            # Study-specific true effects
            theta = pm.Normal("theta", mu=mu, sigma=tau, shape=n_studies)

            # Likelihood: observed effect sizes
            pm.Normal(
                "yi_obs",
                mu=theta,
                sigma=sei,
                observed=yi
            )

            # Sample from posterior
            self.trace = pm.sample(
                draws=n_samples,
                tune=n_tune,
                chains=n_chains,
                target_accept=target_accept,
                random_seed=random_seed,
                return_inferencedata=True,
                progressbar=False  # Disable for API use
            )

        # Compute summary statistics
        self.summary = az.summary(
            self.trace,
            var_names=["mu", "tau"],
            hdi_prob=0.95
        )

        # Extract posterior samples
        posterior = self.trace.posterior
        mu_samples = posterior["mu"].values.flatten()
        tau_samples = posterior["tau"].values.flatten()
        theta_samples = posterior["theta"].values.reshape(-1, n_studies)

        # Compute derived quantities
        tau2_samples = tau_samples ** 2  # Between-study variance

        # Compute I² (proportion of variation due to heterogeneity)
        # I² = tau² / (tau² + v̄), where v̄ is typical within-study variance
        v_bar = np.mean(sei ** 2)
        i2_samples = 100 * tau2_samples / (tau2_samples + v_bar)

        # Compute prediction interval for new study
        # theta_new ~ Normal(mu, tau)
        theta_new_samples = np.random.normal(mu_samples, tau_samples)

        # Convergence diagnostics
        rhat = az.rhat(self.trace, var_names=["mu", "tau"])
        ess_bulk = az.ess(self.trace, var_names=["mu", "tau"], method="bulk")
        ess_tail = az.ess(self.trace, var_names=["mu", "tau"], method="tail")

        # Package results
        results = {
            # Posterior summaries
            "mu_mean": float(np.mean(mu_samples)),
            "mu_median": float(np.median(mu_samples)),
            "mu_sd": float(np.std(mu_samples)),
            "mu_hdi_lower": float(np.percentile(mu_samples, 2.5)),
            "mu_hdi_upper": float(np.percentile(mu_samples, 97.5)),

            "tau_mean": float(np.mean(tau_samples)),
            "tau_median": float(np.median(tau_samples)),
            "tau_sd": float(np.std(tau_samples)),
            "tau_hdi_lower": float(np.percentile(tau_samples, 2.5)),
            "tau_hdi_upper": float(np.percentile(tau_samples, 97.5)),

            "tau2_mean": float(np.mean(tau2_samples)),
            "tau2_median": float(np.median(tau2_samples)),

            "i2_mean": float(np.mean(i2_samples)),
            "i2_median": float(np.median(i2_samples)),
            "i2_hdi_lower": float(np.percentile(i2_samples, 2.5)),
            "i2_hdi_upper": float(np.percentile(i2_samples, 97.5)),

            # Prediction interval for new study
            "prediction_mean": float(np.mean(theta_new_samples)),
            "prediction_hdi_lower": float(np.percentile(theta_new_samples, 2.5)),
            "prediction_hdi_upper": float(np.percentile(theta_new_samples, 97.5)),

            # Probability that pooled effect > 0
            "prob_positive": float(np.mean(mu_samples > 0)),

            # Study-specific posterior means
            "theta_means": [float(np.mean(theta_samples[:, i])) for i in range(n_studies)],
            "theta_hdi_lower": [float(np.percentile(theta_samples[:, i], 2.5)) for i in range(n_studies)],
            "theta_hdi_upper": [float(np.percentile(theta_samples[:, i], 97.5)) for i in range(n_studies)],

            # Convergence diagnostics
            "rhat_mu": float(rhat["mu"].values),
            "rhat_tau": float(rhat["tau"].values),
            "ess_bulk_mu": float(ess_bulk["mu"].values),
            "ess_bulk_tau": float(ess_bulk["tau"].values),
            "ess_tail_mu": float(ess_tail["mu"].values),
            "ess_tail_tau": float(ess_tail["tau"].values),

            # Diagnostics interpretation
            "converged": float(rhat["mu"].values) < 1.01 and float(rhat["tau"].values) < 1.01,

            # Samples (for plotting)
            "mu_samples": mu_samples.tolist(),
            "tau_samples": tau_samples.tolist(),
            "i2_samples": i2_samples.tolist(),

            # Model info
            "n_studies": n_studies,
            "n_samples": n_samples * n_chains,
            "n_chains": n_chains
        }

        return results

    def compare_to_frequentist(
        self,
        yi: np.ndarray,
        sei: np.ndarray,
        frequentist_results: Dict[str, float]
    ) -> Dict[str, Any]:
        """
        Compare Bayesian results to frequentist meta-analysis

        Args:
            yi: Effect sizes
            sei: Standard errors
            frequentist_results: Results from frequentist MA (metafor)
                Should include: pooled_effect, tau2, i2

        Returns:
            Comparison dictionary
        """
        # Run Bayesian analysis if not already done
        if self.trace is None:
            bayes_results = self.fit(yi, sei)
        else:
            # Extract from existing results
            posterior = self.trace.posterior
            mu_samples = posterior["mu"].values.flatten()
            tau_samples = posterior["tau"].values.flatten()

            bayes_results = {
                "mu_mean": float(np.mean(mu_samples)),
                "tau2_mean": float(np.mean(tau_samples ** 2)),
                "i2_mean": float(np.mean(100 * tau_samples**2 / (tau_samples**2 + np.mean(sei**2))))
            }

        comparison = {
            "frequentist_pooled_effect": frequentist_results.get("pooled_effect"),
            "bayesian_pooled_effect": bayes_results["mu_mean"],
            "difference_pooled": abs(
                frequentist_results.get("pooled_effect", 0) - bayes_results["mu_mean"]
            ),

            "frequentist_tau2": frequentist_results.get("tau2"),
            "bayesian_tau2": bayes_results["tau2_mean"],
            "difference_tau2": abs(
                frequentist_results.get("tau2", 0) - bayes_results["tau2_mean"]
            ),

            "frequentist_i2": frequentist_results.get("i2"),
            "bayesian_i2": bayes_results["i2_mean"],
            "difference_i2": abs(
                frequentist_results.get("i2", 0) - bayes_results["i2_mean"]
            ),

            "agreement": "good" if abs(
                frequentist_results.get("pooled_effect", 0) - bayes_results["mu_mean"]
            ) < 0.1 else "fair"
        }

        return comparison

    def posterior_probability(
        self,
        threshold: float,
        direction: str = "greater"
    ) -> float:
        """
        Compute posterior probability that pooled effect exceeds threshold

        Args:
            threshold: Threshold value (on same scale as effect sizes)
            direction: "greater" or "less"

        Returns:
            Posterior probability (0 to 1)
        """
        if self.trace is None:
            raise ValueError("Model must be fit first")

        posterior = self.trace.posterior
        mu_samples = posterior["mu"].values.flatten()

        if direction == "greater":
            prob = np.mean(mu_samples > threshold)
        elif direction == "less":
            prob = np.mean(mu_samples < threshold)
        else:
            raise ValueError("direction must be 'greater' or 'less'")

        return float(prob)

    def forest_plot_data(self, study_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        """
        Extract data for forest plot with Bayesian credible intervals

        Args:
            study_ids: Optional list of study identifiers

        Returns:
            Dictionary with plot data
        """
        if self.trace is None:
            raise ValueError("Model must be fit first")

        posterior = self.trace.posterior
        mu_samples = posterior["mu"].values.flatten()
        theta_samples = posterior["theta"].values

        n_studies = theta_samples.shape[-1]

        if study_ids is None:
            study_ids = [f"Study {i+1}" for i in range(n_studies)]

        # Study-specific estimates
        study_estimates = []
        for i in range(n_studies):
            theta_i = theta_samples[:, :, i].flatten()
            study_estimates.append({
                "study_id": study_ids[i],
                "mean": float(np.mean(theta_i)),
                "hdi_lower": float(np.percentile(theta_i, 2.5)),
                "hdi_upper": float(np.percentile(theta_i, 97.5))
            })

        # Pooled estimate
        pooled = {
            "mean": float(np.mean(mu_samples)),
            "hdi_lower": float(np.percentile(mu_samples, 2.5)),
            "hdi_upper": float(np.percentile(mu_samples, 97.5))
        }

        return {
            "study_estimates": study_estimates,
            "pooled_estimate": pooled,
            "n_studies": n_studies
        }


def simple_bayesian_ma(
    yi: np.ndarray,
    sei: np.ndarray,
    n_samples: int = 2000,
    random_seed: Optional[int] = None
) -> Dict[str, Any]:
    """
    Convenience function for quick Bayesian meta-analysis

    Args:
        yi: Effect sizes
        sei: Standard errors
        n_samples: Number of posterior samples
        random_seed: Random seed

    Returns:
        Results dictionary
    """
    bma = BayesianMetaAnalysis()
    results = bma.fit(
        yi=yi,
        sei=sei,
        n_samples=n_samples,
        random_seed=random_seed
    )
    return results
