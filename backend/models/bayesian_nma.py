"""
Bayesian Network Meta-Analysis using PyMC
Implements Bayesian random effects NMA with multiple priors
"""
import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple
import warnings

try:
    import pymc as pm
    import arviz as az
    PYMC_AVAILABLE = True
except ImportError:
    PYMC_AVAILABLE = False
    warnings.warn("PyMC not installed. Bayesian analysis will not be available.")


class BayesianNMA:
    """
    Bayesian Network Meta-Analysis

    Implements random effects NMA using PyMC with:
    - Vague, informative, and skeptical priors
    - MCMC sampling with convergence diagnostics
    - Posterior distributions for all treatment comparisons
    - League tables with credible intervals
    - SUCRA rankings
    """

    def __init__(self, data: pd.DataFrame, reference_treatment: str):
        """
        Initialize Bayesian NMA

        Args:
            data: DataFrame with columns: study_id, treatment, yi (effect size), sei (SE)
            reference_treatment: Name of reference treatment
        """
        if not PYMC_AVAILABLE:
            raise ImportError("PyMC is required for Bayesian analysis. Install with: pip install pymc")

        self.data = data.copy()
        self.reference_treatment = reference_treatment

        # Get unique treatments
        self.treatments = sorted(data['treatment'].unique())
        self.n_treatments = len(self.treatments)
        self.treatment_idx = {t: i for i, t in enumerate(self.treatments)}

        # Prepare data
        self._prepare_data()

    def _prepare_data(self):
        """Prepare data for PyMC model"""
        # Add treatment indices
        self.data['treatment_idx'] = self.data['treatment'].map(self.treatment_idx)

        # Sort by study and treatment
        self.data = self.data.sort_values(['study_id', 'treatment_idx'])

        # Get study information
        self.studies = self.data['study_id'].unique()
        self.n_studies = len(self.studies)

        # Create study index mapping
        self.study_idx = {s: i for i, s in enumerate(self.studies)}
        self.data['study_idx'] = self.data['study_id'].map(self.study_idx)

    def fit(
        self,
        n_iterations: int = 10000,
        n_chains: int = 4,
        n_tune: int = 2000,
        prior_type: str = "vague",
        tau_prior: float = 1.0,
        random_seed: int = 42
    ) -> Dict:
        """
        Fit Bayesian NMA model

        Args:
            n_iterations: Number of MCMC samples per chain
            n_chains: Number of MCMC chains
            n_tune: Number of tuning steps
            prior_type: Prior type ("vague", "informative", "skeptical")
            tau_prior: Prior for between-study heterogeneity
            random_seed: Random seed for reproducibility

        Returns:
            Dictionary with trace, summary, diagnostics, and results
        """
        # Set priors based on type
        if prior_type == "vague":
            mu_sd = 10  # Very wide prior on treatment effects
        elif prior_type == "informative":
            mu_sd = 2  # Moderately informative
        elif prior_type == "skeptical":
            mu_sd = 0.5  # Skeptical of large effects
        else:
            raise ValueError(f"Unknown prior_type: {prior_type}")

        # Build PyMC model
        with pm.Model() as model:
            # Priors for treatment effects (vs reference)
            mu = pm.Normal(
                "mu",
                mu=0,
                sigma=mu_sd,
                shape=self.n_treatments
            )

            # Prior for between-study heterogeneity
            tau = pm.HalfNormal("tau", sigma=tau_prior)

            # Study-specific random effects
            delta = pm.Normal(
                "delta",
                mu=0,
                sigma=tau,
                shape=self.n_studies
            )

            # Expected effect for each observation
            # theta_ij = mu_treatment + delta_study
            treatment_effects = mu[self.data['treatment_idx'].values]
            study_effects = delta[self.data['study_idx'].values]
            theta = treatment_effects + study_effects

            # Likelihood
            y_obs = pm.Normal(
                "y_obs",
                mu=theta,
                sigma=self.data['sei'].values,
                observed=self.data['yi'].values
            )

            # Sample posterior
            trace = pm.sample(
                draws=n_iterations,
                tune=n_tune,
                chains=n_chains,
                random_seed=random_seed,
                return_inferencedata=True,
                progressbar=True
            )

        # Compute summaries and diagnostics
        summary = az.summary(trace, var_names=["mu", "tau"])
        diagnostics = self._compute_diagnostics(trace)
        league_table = self._compute_league_table(trace)
        sucra = self._compute_sucra(trace)

        # Store results
        self.trace = trace
        self.model = model

        return {
            "trace": trace,
            "summary": summary.to_dict(orient="index"),
            "diagnostics": diagnostics,
            "league_table": league_table,
            "sucra": sucra,
            "n_effective": int(summary['ess_bulk'].mean()),
            "rhat_max": float(summary['r_hat'].max()),
            "convergence": "converged" if float(summary['r_hat'].max()) < 1.1 else "not converged"
        }

    def _compute_diagnostics(self, trace) -> Dict:
        """Compute MCMC diagnostics"""
        summary = az.summary(trace, var_names=["mu", "tau"])

        diagnostics = {
            "rhat": {
                "mean": float(summary['r_hat'].mean()),
                "max": float(summary['r_hat'].max()),
                "all_below_1.1": bool((summary['r_hat'] < 1.1).all())
            },
            "ess_bulk": {
                "mean": float(summary['ess_bulk'].mean()),
                "min": float(summary['ess_bulk'].min())
            },
            "ess_tail": {
                "mean": float(summary['ess_tail'].mean()),
                "min": float(summary['ess_tail'].min())
            },
            "divergences": int(trace.sample_stats.diverging.sum()),
            "warnings": []
        }

        # Add warnings
        if not diagnostics["rhat"]["all_below_1.1"]:
            diagnostics["warnings"].append("Rhat > 1.1 for some parameters. Model may not have converged.")

        if diagnostics["ess_bulk"]["min"] < 400:
            diagnostics["warnings"].append("Low effective sample size. Consider running more iterations.")

        if diagnostics["divergences"] > 0:
            diagnostics["warnings"].append(f"{diagnostics['divergences']} divergent transitions detected.")

        return diagnostics

    def _compute_league_table(self, trace) -> Dict:
        """Compute league table of treatment comparisons"""
        # Extract posterior samples for mu
        mu_samples = trace.posterior["mu"].values  # Shape: (chains, draws, n_treatments)
        mu_samples = mu_samples.reshape(-1, self.n_treatments)  # Flatten chains and draws

        league_table = {}

        for i, trt1 in enumerate(self.treatments):
            league_table[trt1] = {}

            for j, trt2 in enumerate(self.treatments):
                if i == j:
                    league_table[trt1][trt2] = "-"
                else:
                    # Compute difference (trt1 vs trt2)
                    diff = mu_samples[:, i] - mu_samples[:, j]

                    # Posterior summary
                    mean = float(np.mean(diff))
                    median = float(np.median(diff))
                    ci_lower = float(np.percentile(diff, 2.5))
                    ci_upper = float(np.percentile(diff, 97.5))

                    # Probability that trt1 > trt2
                    prob_superior = float((diff > 0).mean())

                    league_table[trt1][trt2] = {
                        "mean": round(mean, 3),
                        "median": round(median, 3),
                        "ci_lower": round(ci_lower, 3),
                        "ci_upper": round(ci_upper, 3),
                        "prob_superior": round(prob_superior, 3),
                        "formatted": f"{mean:.2f} ({ci_lower:.2f}, {ci_upper:.2f})"
                    }

        return league_table

    def _compute_sucra(self, trace) -> Dict:
        """
        Compute SUCRA (Surface Under the Cumulative Ranking curve)
        Higher SUCRA = better treatment ranking
        """
        # Extract posterior samples
        mu_samples = trace.posterior["mu"].values.reshape(-1, self.n_treatments)

        # For each sample, rank treatments (higher effect = better)
        ranks = np.zeros((mu_samples.shape[0], self.n_treatments))

        for i in range(mu_samples.shape[0]):
            # Rank treatments (1 = best, n_treatments = worst)
            ranks[i, :] = self.n_treatments - np.argsort(np.argsort(mu_samples[i, :]))

        # Compute SUCRA for each treatment
        sucra = {}
        for i, trt in enumerate(self.treatments):
            # SUCRA = (sum of probabilities of being rank 1, 2, ..., n-1) / (n-1)
            prob_ranks = [(ranks[:, i] <= r).mean() for r in range(1, self.n_treatments + 1)]
            sucra_value = np.mean(prob_ranks[:-1])  # Exclude last rank

            sucra[trt] = {
                "sucra": round(sucra_value, 3),
                "mean_rank": round(ranks[:, i].mean(), 2),
                "prob_best": round((ranks[:, i] == self.n_treatments).mean(), 3),
                "rank_probabilities": [round(p, 3) for p in prob_ranks]
            }

        # Sort by SUCRA (descending)
        sucra_sorted = dict(sorted(sucra.items(), key=lambda x: x[1]["sucra"], reverse=True))

        return sucra_sorted

    def plot_trace(self, var_names: Optional[List[str]] = None):
        """Plot MCMC trace plots"""
        if var_names is None:
            var_names = ["mu", "tau"]

        return az.plot_trace(self.trace, var_names=var_names)

    def plot_forest(self):
        """Plot forest plot of treatment effects"""
        return az.plot_forest(
            self.trace,
            var_names=["mu"],
            combined=True,
            figsize=(10, 6)
        )

    def plot_posterior(self, var_name: str = "mu"):
        """Plot posterior distributions"""
        return az.plot_posterior(self.trace, var_names=[var_name])

    def plot_network(self):
        """Plot network diagram (requires networkx)"""
        try:
            import networkx as nx
            import matplotlib.pyplot as plt

            # Create network graph
            G = nx.Graph()

            # Add nodes (treatments)
            G.add_nodes_from(self.treatments)

            # Add edges (comparisons in studies)
            for study in self.studies:
                study_data = self.data[self.data['study_id'] == study]
                treatments_in_study = study_data['treatment'].tolist()

                # Add edges for all pairwise comparisons in this study
                for i in range(len(treatments_in_study)):
                    for j in range(i + 1, len(treatments_in_study)):
                        if G.has_edge(treatments_in_study[i], treatments_in_study[j]):
                            G[treatments_in_study[i]][treatments_in_study[j]]['weight'] += 1
                        else:
                            G.add_edge(treatments_in_study[i], treatments_in_study[j], weight=1)

            # Plot
            plt.figure(figsize=(10, 8))
            pos = nx.spring_layout(G, k=2, iterations=50)

            # Draw nodes
            nx.draw_networkx_nodes(G, pos, node_size=3000, node_color='lightblue')

            # Draw edges with width proportional to number of studies
            edges = G.edges()
            weights = [G[u][v]['weight'] for u, v in edges]
            nx.draw_networkx_edges(G, pos, width=[w * 2 for w in weights])

            # Draw labels
            nx.draw_networkx_labels(G, pos, font_size=12, font_weight='bold')

            # Add edge labels (number of studies)
            edge_labels = {(u, v): G[u][v]['weight'] for u, v in G.edges()}
            nx.draw_networkx_edge_labels(G, pos, edge_labels, font_size=10)

            plt.title("Network Meta-Analysis: Treatment Network")
            plt.axis('off')
            plt.tight_layout()

            return plt.gcf()

        except ImportError:
            warnings.warn("networkx and matplotlib required for network plot")
            return None

    def get_comparison(self, treatment1: str, treatment2: str) -> Dict:
        """
        Get specific treatment comparison

        Args:
            treatment1: First treatment
            treatment2: Second treatment (reference)

        Returns:
            Dictionary with posterior summary for treatment1 vs treatment2
        """
        if treatment1 not in self.treatments or treatment2 not in self.treatments:
            raise ValueError(f"Treatment not found in data")

        idx1 = self.treatment_idx[treatment1]
        idx2 = self.treatment_idx[treatment2]

        # Extract posterior samples
        mu_samples = self.trace.posterior["mu"].values.reshape(-1, self.n_treatments)
        diff = mu_samples[:, idx1] - mu_samples[:, idx2]

        return {
            "comparison": f"{treatment1} vs {treatment2}",
            "mean": float(np.mean(diff)),
            "median": float(np.median(diff)),
            "sd": float(np.std(diff)),
            "ci_95": [float(np.percentile(diff, 2.5)), float(np.percentile(diff, 97.5))],
            "ci_90": [float(np.percentile(diff, 5)), float(np.percentile(diff, 95))],
            "prob_superior": float((diff > 0).mean()),
            "prob_equivalent": float(((diff > -0.1) & (diff < 0.1)).mean())  # Within ±0.1
        }

    def export_results(self) -> Dict:
        """Export all results for API/UI consumption"""
        if not hasattr(self, 'trace'):
            raise ValueError("Model must be fit before exporting results")

        summary = az.summary(self.trace, var_names=["mu", "tau"])

        results = {
            "treatments": self.treatments,
            "n_treatments": self.n_treatments,
            "n_studies": self.n_studies,
            "reference_treatment": self.reference_treatment,
            "treatment_effects": {},
            "heterogeneity": {},
            "convergence": self._compute_diagnostics(self.trace),
            "league_table": self._compute_league_table(self.trace),
            "sucra": self._compute_sucra(self.trace)
        }

        # Treatment effects vs reference
        for i, trt in enumerate(self.treatments):
            mu_summary = summary.loc[f"mu[{i}]"]
            results["treatment_effects"][trt] = {
                "mean": float(mu_summary["mean"]),
                "sd": float(mu_summary["sd"]),
                "hdi_95_lower": float(mu_summary["hdi_2.5%"]),
                "hdi_95_upper": float(mu_summary["hdi_97.5%"]),
                "ess_bulk": int(mu_summary["ess_bulk"]),
                "rhat": float(mu_summary["r_hat"])
            }

        # Heterogeneity
        tau_summary = summary.loc["tau"]
        results["heterogeneity"] = {
            "tau": float(tau_summary["mean"]),
            "tau_sd": float(tau_summary["sd"]),
            "tau_hdi_95": [float(tau_summary["hdi_2.5%"]), float(tau_summary["hdi_97.5%"])],
            "interpretation": self._interpret_tau(float(tau_summary["mean"]))
        }

        return results

    def _interpret_tau(self, tau: float) -> str:
        """Interpret between-study heterogeneity"""
        if tau < 0.1:
            return "Low heterogeneity"
        elif tau < 0.3:
            return "Moderate heterogeneity"
        elif tau < 0.5:
            return "Substantial heterogeneity"
        else:
            return "High heterogeneity"


# Example usage
def example_bayesian_nma():
    """Example of Bayesian NMA usage"""
    # Sample data
    data = pd.DataFrame({
        'study_id': ['S1', 'S1', 'S2', 'S2', 'S3', 'S3', 'S3'],
        'treatment': ['A', 'B', 'A', 'C', 'B', 'C', 'D'],
        'yi': [0.5, 0.8, 0.6, 0.9, 0.7, 0.85, 1.0],
        'sei': [0.1, 0.12, 0.11, 0.13, 0.1, 0.11, 0.14]
    })

    # Fit model
    nma = BayesianNMA(data, reference_treatment='A')
    results = nma.fit(n_iterations=5000, prior_type="vague")

    # Export results
    return nma.export_results()


if __name__ == "__main__":
    results = example_bayesian_nma()
    print("Bayesian NMA Results:")
    print(f"Convergence: {results['convergence']['rhat']}")
    print(f"\nSUCRA Rankings:")
    for trt, scores in results['sucra'].items():
        print(f"  {trt}: {scores['sucra']:.3f} (Mean rank: {scores['mean_rank']:.1f})")
