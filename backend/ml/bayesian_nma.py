"""
Bayesian Network Meta-Analysis using PyMC
Full Bayesian inference for network meta-analysis
"""
import logging
from typing import Dict, List, Any, Optional, Tuple
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


class BayesianNMA:
    """
    Bayesian Network Meta-Analysis using PyMC
    Implements arm-based and contrast-based models
    """

    def __init__(self, model_type: str = 'random'):
        """
        Initialize Bayesian NMA

        Args:
            model_type: 'fixed' or 'random' effects model
        """
        self.model_type = model_type
        self.model = None
        self.trace = None
        self.treatments = []

        try:
            import pymc as pm
            self.pm = pm
            self.pymc_available = True
            logger.info(f"✓ Bayesian NMA initialized (PyMC available, {model_type} effects)")
        except ImportError:
            self.pymc_available = False
            logger.warning("PyMC not installed. Install with: pip install pymc")

    def fit(
        self,
        data: pd.DataFrame,
        outcome_type: str = 'binary',
        n_samples: int = 2000,
        n_tune: int = 1000
    ) -> Dict[str, Any]:
        """
        Fit Bayesian NMA model

        Args:
            data: DataFrame with columns: study_id, treatment, n, events (for binary)
            outcome_type: 'binary', 'continuous', or 'rate'
            n_samples: Number of MCMC samples
            n_tune: Number of tuning samples

        Returns:
            Fit summary and diagnostics
        """
        if not self.pymc_available:
            return self._frequentist_fallback(data)

        logger.info(f"Fitting Bayesian NMA on {len(data)} arms from {data['study_id'].nunique()} studies...")

        # Get unique treatments
        self.treatments = sorted(data['treatment'].unique())
        n_treatments = len(self.treatments)

        # Encode treatments
        treat_idx = {t: i for i, t in enumerate(self.treatments)}
        data = data.copy()
        data['treat_idx'] = data['treatment'].map(treat_idx)

        # Build model
        with self.pm.Model() as model:
            # Treatment effects (relative to reference)
            if self.model_type == 'random':
                tau = self.pm.HalfNormal('tau', sigma=1)  # Between-study heterogeneity
                d = self.pm.Normal('d', mu=0, sigma=10, shape=n_treatments)
            else:
                d = self.pm.Normal('d', mu=0, sigma=10, shape=n_treatments)

            # Study baselines
            n_studies = data['study_id'].nunique()
            mu = self.pm.Normal('mu', mu=0, sigma=10, shape=n_studies)

            # Build likelihood based on outcome type
            if outcome_type == 'binary':
                # Binomial likelihood
                study_ids = pd.factorize(data['study_id'])[0]

                logit_p = mu[study_ids] + d[data['treat_idx'].values]

                if self.model_type == 'random':
                    # Add random effects
                    sigma_study = self.pm.HalfNormal('sigma_study', sigma=tau, shape=n_studies)
                    logit_p = logit_p + sigma_study[study_ids]

                p = self.pm.math.sigmoid(logit_p)

                y = self.pm.Binomial('y', n=data['n'].values, p=p, observed=data['events'].values)

            # Sample
            self.trace = self.pm.sample(
                n_samples,
                tune=n_tune,
                return_inferencedata=True,
                progressbar=False
            )

        self.model = model

        # Diagnostics
        rhat = self.pm.rhat(self.trace).to_array().values.flatten()
        mean_rhat = float(np.mean(rhat))
        max_rhat = float(np.max(rhat))

        logger.info(f"✓ MCMC complete (R-hat mean={mean_rhat:.3f}, max={max_rhat:.3f})")

        return {
            'status': 'converged' if max_rhat < 1.1 else 'check_convergence',
            'n_samples': n_samples,
            'n_treatments': n_treatments,
            'rhat_mean': mean_rhat,
            'rhat_max': max_rhat,
            'model_type': self.model_type
        }

    def get_treatment_effects(self, reference: Optional[str] = None) -> pd.DataFrame:
        """
        Get posterior treatment effects

        Args:
            reference: Reference treatment (default: first treatment)

        Returns:
            DataFrame with posterior summaries
        """
        if self.trace is None:
            raise ValueError("Model not fitted. Call fit() first.")

        # Extract treatment effects
        d_samples = self.trace.posterior['d'].values.reshape(-1, len(self.treatments))

        if reference is None:
            reference = self.treatments[0]

        ref_idx = self.treatments.index(reference)

        results = []
        for i, treatment in enumerate(self.treatments):
            if treatment == reference:
                # Reference treatment
                results.append({
                    'treatment': treatment,
                    'mean': 0.0,
                    'median': 0.0,
                    'sd': 0.0,
                    'ci_lower': 0.0,
                    'ci_upper': 0.0
                })
            else:
                # Relative to reference
                rel_effect = d_samples[:, i] - d_samples[:, ref_idx]

                results.append({
                    'treatment': treatment,
                    'mean': float(np.mean(rel_effect)),
                    'median': float(np.median(rel_effect)),
                    'sd': float(np.std(rel_effect)),
                    'ci_lower': float(np.percentile(rel_effect, 2.5)),
                    'ci_upper': float(np.percentile(rel_effect, 97.5))
                })

        return pd.DataFrame(results)

    def get_rankings(self) -> pd.DataFrame:
        """
        Get treatment rankings (SUCRA)

        Returns:
            DataFrame with ranking probabilities
        """
        if self.trace is None:
            raise ValueError("Model not fitted")

        d_samples = self.trace.posterior['d'].values.reshape(-1, len(self.treatments))

        # Rank treatments (higher is better)
        ranks = np.argsort(-d_samples, axis=1) + 1

        # Calculate rank probabilities
        results = []
        for i, treatment in enumerate(self.treatments):
            treat_ranks = ranks[:, i]
            rank_probs = [np.mean(treat_ranks == r) for r in range(1, len(self.treatments) + 1)]

            # SUCRA (Surface Under Cumulative Ranking curve)
            cumsum_probs = np.cumsum(rank_probs)
            sucra = np.sum(cumsum_probs[:-1]) / (len(self.treatments) - 1)

            results.append({
                'treatment': treatment,
                'sucra': float(sucra),
                'prob_rank_1': float(rank_probs[0]),
                'mean_rank': float(np.mean(treat_ranks))
            })

        return pd.DataFrame(results).sort_values('sucra', ascending=False)

    def get_heterogeneity(self) -> Dict[str, float]:
        """Get heterogeneity estimates"""
        if self.trace is None or self.model_type != 'random':
            return {}

        tau_samples = self.trace.posterior['tau'].values.flatten()

        return {
            'tau_mean': float(np.mean(tau_samples)),
            'tau_median': float(np.median(tau_samples)),
            'tau_ci_lower': float(np.percentile(tau_samples, 2.5)),
            'tau_ci_upper': float(np.percentile(tau_samples, 97.5))
        }

    def _frequentist_fallback(self, data: pd.DataFrame) -> Dict[str, Any]:
        """Frequentist NMA fallback when PyMC unavailable"""
        logger.warning("Using frequentist fallback. Install PyMC for Bayesian analysis.")

        self.treatments = sorted(data['treatment'].unique())

        return {
            'status': 'fallback_frequentist',
            'message': 'PyMC not available. Install with: pip install pymc',
            'n_treatments': len(self.treatments),
            'n_studies': data['study_id'].nunique()
        }

    def generate_league_table(self) -> pd.DataFrame:
        """
        Generate league table of all pairwise comparisons

        Returns:
            DataFrame with pairwise treatment effects
        """
        if self.trace is None:
            raise ValueError("Model not fitted")

        d_samples = self.trace.posterior['d'].values.reshape(-1, len(self.treatments))

        league = []
        for i, treat_i in enumerate(self.treatments):
            for j, treat_j in enumerate(self.treatments):
                if i <= j:
                    continue  # Upper triangle only

                # Calculate pairwise effect
                diff = d_samples[:, i] - d_samples[:, j]

                league.append({
                    'treatment_1': treat_i,
                    'treatment_2': treat_j,
                    'mean_diff': float(np.mean(diff)),
                    'ci_lower': float(np.percentile(diff, 2.5)),
                    'ci_upper': float(np.percentile(diff, 97.5)),
                    'prob_superior': float(np.mean(diff > 0))
                })

        return pd.DataFrame(league)
