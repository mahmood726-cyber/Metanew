"""
EvidenceOS PRIME FastAPI Backend
Provides validation, computation, and utility endpoints for R frontend
"""
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, List, Any, Optional
import pandas as pd
import numpy as np
from datetime import datetime
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from schemas.evidence_object import (
    EvidenceObject, ValidationResult, ValidationProblem,
    Observation, Study
)

app = FastAPI(
    title="EvidenceOS PRIME API",
    description="Backend API for meta-analysis and health economics",
    version="1.0.0"
)

# CORS middleware for R Shiny
# Environment-based origin configuration for security
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3838,http://localhost:8000,http://127.0.0.1:3838"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # Restricted to configured origins
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
    max_age=3600,  # Cache preflight requests for 1 hour
)


@app.get("/")
def root():
    """Health check endpoint"""
    return {
        "service": "EvidenceOS PRIME API",
        "version": "1.0.0",
        "status": "operational",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/health")
def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "python_version": sys.version,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.post("/validate")
def validate_data(data: Dict[str, Any]):
    """
    Validate input data table
    Expects: {"data": [...], "data_type": "binary|continuous|tte"}
    Returns: ValidationResult with problems and normalized data
    """
    from etl.validate import validate_table

    try:
        df = pd.DataFrame(data.get("data", []))
        data_type = data.get("data_type", "binary")

        result = validate_table(df, data_type)

        return result.model_dump()

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/compute/yi")
def compute_effect_sizes(data: Dict[str, Any]):
    """
    Compute effect sizes (yi, sei) from raw data
    Handles binary (OR, RR), continuous (MD, SMD), and time-to-event (HR) data
    """
    from etl.transform import compute_effect_size

    try:
        df = pd.DataFrame(data.get("data", []))
        measure = data.get("measure", "OR")

        result_df = compute_effect_size(df, measure)

        return {
            "data": result_df.to_dict(orient="records"),
            "measure": measure,
            "n_observations": len(result_df)
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/meta/bayes")
def bayesian_meta_analysis(data: Dict[str, Any]):
    """
    Bayesian random-effects meta-analysis using PyMC

    Full hierarchical Bayesian model with half-Cauchy prior on heterogeneity.
    Returns posterior distributions for pooled effect (mu) and between-study SD (tau).

    Request body:
    {
        "yi": [0.5, 0.7, 0.3, ...],  # Effect sizes (log scale)
        "sei": [0.1, 0.15, 0.12, ...],  # Standard errors
        "n_samples": 2000,  # Optional: posterior samples per chain
        "n_chains": 4,  # Optional: number of MCMC chains
        "random_seed": 42  # Optional: for reproducibility
    }

    Returns:
    {
        "mu_mean": float,  # Posterior mean of pooled effect
        "mu_hdi_lower": float,  # 95% HDI lower bound
        "mu_hdi_upper": float,  # 95% HDI upper bound
        "tau2_mean": float,  # Between-study variance
        "i2_mean": float,  # I² statistic
        "prob_positive": float,  # P(mu > 0)
        "converged": bool,  # MCMC convergence status
        ...
    }
    """
    try:
        # Check if PyMC is available
        try:
            from models.bayesian_meta import simple_bayesian_ma
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "PyMC Not Available",
                    "message": "PyMC is not installed. Bayesian analysis requires PyMC.",
                    "install_instructions": "pip install 'pymc>=5.0' arviz",
                    "alternatives": [
                        "Use /meta/frequentist endpoint for REML/DL meta-analysis",
                        "Use metafor::rma() in R for frequentist analysis",
                        "Use brms package in R for Bayesian analysis"
                    ]
                }
            )

        # Extract data
        yi = np.array(data.get("yi", []))
        sei = np.array(data.get("sei", []))

        if len(yi) == 0 or len(sei) == 0:
            raise ValueError("yi and sei cannot be empty")

        if len(yi) != len(sei):
            raise ValueError("yi and sei must have the same length")

        # Optional parameters
        n_samples = data.get("n_samples", 2000)
        n_chains = data.get("n_chains", 4)
        random_seed = data.get("random_seed", None)

        # Run Bayesian meta-analysis
        results = simple_bayesian_ma(
            yi=yi,
            sei=sei,
            n_samples=n_samples,
            random_seed=random_seed
        )

        # Add method info
        results["method"] = "bayesian"
        results["model"] = "hierarchical_random_effects"
        results["prior_mu"] = "Normal(0, 10)"
        results["prior_tau"] = "HalfCauchy(0, 1)"
        results["timestamp"] = datetime.utcnow().isoformat()

        return results

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except ImportError as e:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "Dependency Missing",
                "message": str(e),
                "required": ["pymc>=5.0", "arviz"]
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/evidence/hash")
def compute_evidence_hash(evidence: Dict[str, Any]):
    """
    Compute content hash for EvidenceObject
    Used for integrity checking and reproducibility
    """
    try:
        eo = EvidenceObject(**evidence)
        hash_value = eo.compute_hash()

        return {
            "evidence_id": eo.evidence_id,
            "content_hash": hash_value,
            "timestamp": datetime.utcnow().isoformat()
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/evidence/validate")
def validate_evidence_object(evidence: Dict[str, Any]):
    """
    Validate complete EvidenceObject structure
    """
    try:
        eo = EvidenceObject(**evidence)
        eo.update_hash()

        return {
            "valid": True,
            "evidence_id": eo.evidence_id,
            "content_hash": eo.content_hash,
            "n_studies": len(eo.studies),
            "n_observations": len(eo.observations),
            "has_protocol": eo.protocol is not None,
            "has_economic_analysis": eo.economic_params is not None
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Validation failed: {str(e)}")


@app.post("/econ/params")
def generate_psa_parameters(params: Dict[str, Any]):
    """
    Generate PSA parameter distributions
    Returns sampled parameter sets for probabilistic sensitivity analysis
    """
    try:
        n_iterations = params.get("n_iterations", 1000)
        seed = params.get("seed", 42)

        np.random.seed(seed)

        # Example: generate distributions for key parameters
        # In production, these would be based on actual parameter uncertainty

        hr_progression = params.get("hr_progression", 0.7)
        hr_death = params.get("hr_death", 0.8)

        # Log-normal sampling for hazard ratios
        hr_prog_samples = np.random.lognormal(
            mean=np.log(hr_progression),
            sigma=0.2,  # Assumed SE on log scale
            size=n_iterations
        )

        hr_death_samples = np.random.lognormal(
            mean=np.log(hr_death),
            sigma=0.2,
            size=n_iterations
        )

        # Utility values (beta distribution)
        utility_stable = np.random.beta(80, 20, n_iterations)  # Mean ~0.8
        utility_progressed = np.random.beta(50, 50, n_iterations)  # Mean ~0.5

        # Costs (gamma distribution)
        cost_treatment = np.random.gamma(
            shape=100,
            scale=params.get("cost_treatment", 10000) / 100,
            size=n_iterations
        )

        return {
            "n_iterations": n_iterations,
            "parameters": {
                "hr_progression": hr_prog_samples.tolist(),
                "hr_death": hr_death_samples.tolist(),
                "utility_stable": utility_stable.tolist(),
                "utility_progressed": utility_progressed.tolist(),
                "cost_treatment": cost_treatment.tolist()
            },
            "seed": seed
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/convert/or_to_rr")
def convert_or_to_rr(data: Dict[str, Any]):
    """
    Convert odds ratios to risk ratios
    Uses control event rate
    """
    try:
        or_value = data.get("or")
        control_event_rate = data.get("control_event_rate")

        if or_value is None or control_event_rate is None:
            raise ValueError("Missing or or control_event_rate")

        # Formula: RR = OR / (1 - CER + (CER * OR))
        rr = or_value / (1 - control_event_rate + (control_event_rate * or_value))

        return {
            "or": or_value,
            "rr": rr,
            "control_event_rate": control_event_rate
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/format/league_table")
def format_league_table(data: Dict[str, Any]):
    """
    Format NMA results into league table structure
    """
    try:
        treatments = data.get("treatments", [])
        effects = data.get("effects", {})

        # Create symmetric league table
        league = {}
        for t1 in treatments:
            league[t1] = {}
            for t2 in treatments:
                if t1 == t2:
                    league[t1][t2] = "-"
                else:
                    key = f"{t1}_vs_{t2}"
                    if key in effects:
                        effect = effects[key]
                        league[t1][t2] = f"{effect['est']:.2f} ({effect['ci_lower']:.2f}, {effect['ci_upper']:.2f})"
                    else:
                        league[t1][t2] = "NA"

        return {"league_table": league, "treatments": treatments}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
