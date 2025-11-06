"""
Tests for Bayesian Meta-Analysis Module
"""
import pytest
import numpy as np
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../../backend'))

# Check if PyMC is available
try:
    from models.bayesian_meta import BayesianMetaAnalysis, simple_bayesian_ma
    PYMC_AVAILABLE = True
except ImportError:
    PYMC_AVAILABLE = False


@pytest.mark.skipif(not PYMC_AVAILABLE, reason="PyMC not installed")
class TestBayesianMetaAnalysis:
    """Test suite for Bayesian meta-analysis"""

    @pytest.fixture
    def sample_data(self):
        """Sample effect sizes and standard errors"""
        # Simulated log odds ratios from 5 studies
        yi = np.array([0.5, 0.7, 0.3, 0.6, 0.4])
        sei = np.array([0.1, 0.15, 0.12, 0.11, 0.14])
        return yi, sei

    def test_basic_fit(self, sample_data):
        """Test basic Bayesian meta-analysis fit"""
        yi, sei = sample_data

        bma = BayesianMetaAnalysis()
        results = bma.fit(yi, sei, n_samples=500, random_seed=42)

        # Check that all expected keys are present
        assert "mu_mean" in results
        assert "mu_hdi_lower" in results
        assert "mu_hdi_upper" in results
        assert "tau_mean" in results
        assert "tau2_mean" in results
        assert "i2_mean" in results
        assert "converged" in results

        # Check that values are reasonable
        assert 0 < results["mu_mean"] < 1  # Should be around 0.5
        assert results["tau_mean"] >= 0  # Tau must be non-negative
        assert 0 <= results["i2_mean"] <= 100  # I² is a percentage

    def test_convergence(self, sample_data):
        """Test that MCMC converges (Rhat < 1.01)"""
        yi, sei = sample_data

        results = simple_bayesian_ma(yi, sei, n_samples=1000, random_seed=42)

        # Check convergence diagnostics
        assert results["converged"] is True
        assert results["rhat_mu"] < 1.01
        assert results["rhat_tau"] < 1.01

    def test_credible_intervals(self, sample_data):
        """Test that credible intervals are properly ordered"""
        yi, sei = sample_data

        results = simple_bayesian_ma(yi, sei, n_samples=500, random_seed=42)

        # HDI lower should be less than mean, mean less than upper
        assert results["mu_hdi_lower"] < results["mu_mean"] < results["mu_hdi_upper"]
        assert results["tau_hdi_lower"] < results["tau_mean"] < results["tau_hdi_upper"]

    def test_posterior_probability(self, sample_data):
        """Test posterior probability calculation"""
        yi, sei = sample_data

        bma = BayesianMetaAnalysis()
        bma.fit(yi, sei, n_samples=500, random_seed=42)

        # Probability that effect is positive
        prob_pos = bma.posterior_probability(0, direction="greater")
        assert 0 <= prob_pos <= 1

        # Should be high since all effects are positive
        assert prob_pos > 0.9

    def test_forest_plot_data(self, sample_data):
        """Test forest plot data extraction"""
        yi, sei = sample_data
        study_ids = [f"Study {i+1}" for i in range(len(yi))]

        bma = BayesianMetaAnalysis()
        bma.fit(yi, sei, n_samples=500, random_seed=42)

        plot_data = bma.forest_plot_data(study_ids=study_ids)

        assert "study_estimates" in plot_data
        assert "pooled_estimate" in plot_data
        assert len(plot_data["study_estimates"]) == len(yi)

        # Check that all studies have estimates and intervals
        for study in plot_data["study_estimates"]:
            assert "study_id" in study
            assert "mean" in study
            assert "hdi_lower" in study
            assert "hdi_upper" in study

    def test_invalid_inputs(self):
        """Test that invalid inputs raise appropriate errors"""
        bma = BayesianMetaAnalysis()

        # Mismatched lengths
        with pytest.raises(ValueError):
            bma.fit(yi=np.array([0.5, 0.7]), sei=np.array([0.1]))

        # Negative standard errors
        with pytest.raises(ValueError):
            bma.fit(yi=np.array([0.5, 0.7]), sei=np.array([-0.1, 0.1]))

        # Non-finite values
        with pytest.raises(ValueError):
            bma.fit(yi=np.array([0.5, np.inf]), sei=np.array([0.1, 0.1]))

    def test_single_study(self):
        """Test that single study works (though not recommended)"""
        yi = np.array([0.5])
        sei = np.array([0.1])

        results = simple_bayesian_ma(yi, sei, n_samples=500, random_seed=42)

        assert "mu_mean" in results
        # With single study, posterior should be close to observed
        assert abs(results["mu_mean"] - 0.5) < 0.2

    def test_heterogeneous_data(self):
        """Test with highly heterogeneous data"""
        # Create heterogeneous data (large between-study variance)
        yi = np.array([0.1, 0.5, 0.9, 0.2, 0.8])
        sei = np.array([0.1, 0.1, 0.1, 0.1, 0.1])

        results = simple_bayesian_ma(yi, sei, n_samples=1000, random_seed=42)

        # Should detect high heterogeneity
        assert results["i2_mean"] > 50  # Substantial heterogeneity
        assert results["tau2_mean"] > 0.01  # Non-trivial between-study variance

    def test_homogeneous_data(self):
        """Test with homogeneous data"""
        # Create homogeneous data (small between-study variance)
        yi = np.array([0.5, 0.51, 0.49, 0.50, 0.52])
        sei = np.array([0.1, 0.1, 0.1, 0.1, 0.1])

        results = simple_bayesian_ma(yi, sei, n_samples=1000, random_seed=42)

        # Should detect low heterogeneity
        assert results["i2_mean"] < 50  # Low to moderate heterogeneity

    def test_reproducibility(self, sample_data):
        """Test that results are reproducible with same seed"""
        yi, sei = sample_data

        results1 = simple_bayesian_ma(yi, sei, n_samples=500, random_seed=42)
        results2 = simple_bayesian_ma(yi, sei, n_samples=500, random_seed=42)

        # Results should be identical with same seed
        assert abs(results1["mu_mean"] - results2["mu_mean"]) < 0.01
        assert abs(results1["tau_mean"] - results2["tau_mean"]) < 0.01

    def test_sample_sizes(self, sample_data):
        """Test that different sample sizes work"""
        yi, sei = sample_data

        # Small sample size
        results_small = simple_bayesian_ma(yi, sei, n_samples=100, random_seed=42)
        assert results_small["n_samples"] == 400  # 100 * 4 chains

        # Large sample size
        results_large = simple_bayesian_ma(yi, sei, n_samples=2000, random_seed=42)
        assert results_large["n_samples"] == 8000  # 2000 * 4 chains

    def test_ess(self, sample_data):
        """Test that effective sample size is reasonable"""
        yi, sei = sample_data

        results = simple_bayesian_ma(yi, sei, n_samples=1000, random_seed=42)

        # ESS should be substantial (at least 10% of total samples)
        min_ess = 0.1 * results["n_samples"]
        assert results["ess_bulk_mu"] > min_ess
        assert results["ess_bulk_tau"] > min_ess

    @pytest.mark.slow
    def test_many_studies(self):
        """Test with large number of studies"""
        # Create data for 50 studies
        np.random.seed(42)
        yi = np.random.normal(0.5, 0.2, 50)
        sei = np.random.uniform(0.05, 0.15, 50)

        results = simple_bayesian_ma(yi, sei, n_samples=500, random_seed=42)

        assert results["converged"] is True
        assert results["n_studies"] == 50
        assert len(results["theta_means"]) == 50


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
