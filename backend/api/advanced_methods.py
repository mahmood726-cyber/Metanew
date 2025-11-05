"""
Advanced Methods API - FastAPI endpoints for new HTA/statistical methods

Exposes 21 killer features via REST API:
- MAIC/STC
- Target Trial Emulation
- Multi-State Models
- Propensity Score Analysis
- IPD Meta-Analysis
- AI Citation Screening
- AI Data Extraction
- Component NMA
- Threshold Analysis

Author: EvidenceOS PRIME
License: MIT
"""

from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel, Field
from typing import Dict, List, Optional, Tuple, Any
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from stats.maic_engine import MAICEngine, MAICConfig
from stats.target_trial import TargetTrialEmulator, TargetTrialProtocol
from stats.multistate import MultiStateEngine, MultiStateModel
from stats.propensity import PropensityScoreAnalyzer
from stats.ipd_ma import IPDMetaAnalyzer
from stats.threshold_analysis import ThresholdAnalyzer
from stats.component_nma import ComponentNMAEngine
from ml.citation_screening import CitationScreener
from ml.data_extraction import DataExtractor

import pandas as pd
import numpy as np

# Pydantic Models for API
class MAICRequest(BaseModel):
    ipd_data: List[Dict]
    target_summary: Dict[str, float]
    outcome_var: str
    treatment_var: str
    covariates: Optional[List[str]] = None
    outcome_type: str = "binary"
    config: Optional[Dict] = None


class PropensityScoreRequest(BaseModel):
    data: List[Dict]
    treatment_var: str
    outcome_var: str
    confounders: List[str]
    method: str = "matching"
    caliper: float = 0.2


class IPDMetaAnalysisRequest(BaseModel):
    ipd_data: List[Dict]
    outcome_var: str
    treatment_var: str
    study_var: str
    covariates: Optional[List[str]] = None
    method: str = "one_stage"


class ThresholdAnalysisRequest(BaseModel):
    incremental_cost: float
    incremental_qaly: float
    cost_se: float
    qaly_se: float
    wtp_range: Tuple[float, float] = (0, 150000)
    n_simulations: int = 10000
    population_size: Optional[int] = None
    time_horizon: Optional[int] = None


class CitationScreeningRequest(BaseModel):
    citations: List[Dict]
    labels: Optional[List[int]] = None  # For training
    title_col: str = "title"
    abstract_col: str = "abstract"
    mode: str = "predict"  # "train" or "predict"


class DataExtractionRequest(BaseModel):
    texts: List[str]
    study_ids: List[str]


class ComponentNMARequest(BaseModel):
    data: List[Dict]
    treatment_components: Dict[str, List[str]]
    outcome_var: str
    se_var: str
    include_interactions: bool = False


# Initialize FastAPI app
app = FastAPI(
    title="EvidenceOS PRIME - Advanced Methods API",
    description="Production-ready HTA and statistical methods",
    version="2.0.0"
)


@app.get("/")
async def root():
    """API health check"""
    return {
        "status": "online",
        "api_version": "2.0.0",
        "available_methods": [
            "MAIC/STC",
            "Target Trial Emulation",
            "Multi-State Models",
            "Propensity Score Analysis",
            "IPD Meta-Analysis",
            "AI Citation Screening",
            "AI Data Extraction",
            "Component NMA",
            "Threshold Analysis"
        ]
    }


@app.post("/maic/run")
async def run_maic(request: MAICRequest):
    """
    Run MAIC (Matching-Adjusted Indirect Comparison) analysis

    Performs population-adjusted indirect comparison using individual patient data.
    """
    try:
        # Convert to DataFrame
        ipd_df = pd.DataFrame(request.ipd_data)

        # Configure MAIC
        if request.config:
            config = MAICConfig(**request.config)
        else:
            config = MAICConfig()

        # Run MAIC
        engine = MAICEngine(config)
        result = engine.run_maic(
            ipd_data=ipd_df,
            target_summary=request.target_summary,
            outcome_var=request.outcome_var,
            treatment_var=request.treatment_var,
            covariates=request.covariates,
            outcome_type=request.outcome_type
        )

        # Convert result to dict
        return {
            "effect_estimate": float(result.effect_estimate),
            "effect_se": float(result.effect_se),
            "effect_ci_lower": float(result.effect_ci_lower),
            "effect_ci_upper": float(result.effect_ci_upper),
            "effect_p_value": float(result.effect_p_value),
            "weights": result.weights.tolist(),
            "ess": float(result.ess),
            "smd_before": result.smd_before,
            "smd_after": result.smd_after,
            "balance_achieved": result.balance_achieved,
            "selected_variables": result.selected_variables,
            "variable_importance": result.variable_importance,
            "validation_score": result.validation_score,
            "validation_checks": result.validation_checks,
            "n_ipd": result.n_ipd,
            "converged": result.converged,
            "warnings": result.warnings
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/propensity/analyze")
async def run_propensity_score_analysis(request: PropensityScoreRequest):
    """
    Run propensity score analysis

    Supports matching, IPW, and stratification methods.
    """
    try:
        data_df = pd.DataFrame(request.data)

        analyzer = PropensityScoreAnalyzer(
            method=request.method,
            caliper=request.caliper
        )

        result = analyzer.analyze(
            data=data_df,
            treatment_var=request.treatment_var,
            outcome_var=request.outcome_var,
            confounders=request.confounders
        )

        return {
            "treatment_effect": float(result.treatment_effect),
            "se": float(result.se),
            "ci_lower": float(result.ci_lower),
            "ci_upper": float(result.ci_upper),
            "p_value": float(result.p_value),
            "propensity_scores": result.propensity_scores.tolist(),
            "n_matched": result.n_matched,
            "smd_before": result.smd_before,
            "smd_after": result.smd_after,
            "balance_achieved": result.balance_achieved,
            "common_support_n": result.common_support_n
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ipd_ma/analyze")
async def run_ipd_meta_analysis(request: IPDMetaAnalysisRequest):
    """
    Run Individual Patient Data (IPD) meta-analysis

    Supports one-stage and two-stage approaches.
    """
    try:
        ipd_df = pd.DataFrame(request.ipd_data)

        analyzer = IPDMetaAnalyzer(
            method=request.method,
            outcome_type="continuous"
        )

        result = analyzer.analyze(
            ipd_data=ipd_df,
            outcome_var=request.outcome_var,
            treatment_var=request.treatment_var,
            study_var=request.study_var,
            covariates=request.covariates
        )

        return {
            "pooled_estimate": float(result.pooled_estimate),
            "pooled_se": float(result.pooled_se),
            "ci_lower": float(result.ci_lower),
            "ci_upper": float(result.ci_upper),
            "p_value": float(result.p_value),
            "tau_squared": float(result.tau_squared),
            "i_squared": float(result.i_squared),
            "q_statistic": float(result.q_statistic),
            "q_p_value": float(result.q_p_value),
            "study_estimates": result.study_estimates,
            "study_ses": result.study_ses,
            "covariate_effects": result.covariate_effects
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/threshold/analyze")
async def run_threshold_analysis(request: ThresholdAnalysisRequest):
    """
    Run threshold analysis for willingness-to-pay

    Calculates ICER threshold, CEAC, and EVPI.
    """
    try:
        analyzer = ThresholdAnalyzer()

        result = analyzer.analyze(
            incremental_cost=request.incremental_cost,
            incremental_qaly=request.incremental_qaly,
            cost_se=request.cost_se,
            qaly_se=request.qaly_se,
            wtp_range=request.wtp_range,
            n_simulations=request.n_simulations,
            population_size=request.population_size,
            time_horizon=request.time_horizon
        )

        return {
            "threshold_wtp": float(result.threshold_wtp),
            "nmb_at_thresholds": result.nmb_at_thresholds,
            "ceac_wtp_range": result.ceac_wtp_range.tolist(),
            "ceac_probabilities": result.ceac_probabilities.tolist(),
            "evpi_per_patient": float(result.evpi_per_patient),
            "evpi_population": float(result.evpi_population),
            "evpi_by_wtp": result.evpi_by_wtp,
            "cost_effective_at": result.cost_effective_at
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/citation/screen")
async def screen_citations(request: CitationScreeningRequest):
    """
    AI-powered citation screening

    Automates title/abstract screening for systematic reviews.
    """
    try:
        citations_df = pd.DataFrame(request.citations)

        screener = CitationScreener()

        if request.mode == "train" and request.labels:
            screener.train(
                citations=citations_df,
                labels=np.array(request.labels),
                title_col=request.title_col,
                abstract_col=request.abstract_col
            )
            return {"status": "model_trained"}

        elif request.mode == "predict":
            result = screener.screen(
                citations=citations_df,
                title_col=request.title_col,
                abstract_col=request.abstract_col
            )

            return {
                "predictions": result.predictions.tolist(),
                "probabilities": result.probabilities.tolist(),
                "certainty": result.certainty.tolist(),
                "estimated_precision": result.estimated_precision,
                "estimated_recall": result.estimated_recall,
                "n_include": result.n_include,
                "n_exclude": result.n_exclude,
                "high_priority_indices": result.high_priority_indices,
                "uncertain_indices": result.uncertain_indices,
                "prisma_stats": result.prisma_stats
            }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/extraction/extract")
async def extract_data(request: DataExtractionRequest):
    """
    AI-powered data extraction from study texts

    Extracts PICO, sample sizes, effect sizes, and risk of bias.
    """
    try:
        extractor = DataExtractor()

        result = extractor.extract_batch(
            texts=request.texts,
            study_ids=request.study_ids
        )

        # Convert to serializable format
        extracted = []
        for study in result.extracted_studies:
            extracted.append({
                "study_id": study.study_id,
                "author": study.author,
                "year": study.year,
                "population": study.population,
                "intervention": study.intervention,
                "comparator": study.comparator,
                "outcomes": study.outcomes,
                "n_total": study.n_total,
                "effect_sizes": study.effect_sizes,
                "confidence": study.confidence,
                "needs_review": study.needs_review
            })

        return {
            "extracted_studies": extracted,
            "n_successful": result.n_successful,
            "n_failed": result.n_failed,
            "n_needs_review": result.n_needs_review,
            "extraction_quality": result.extraction_quality,
            "common_issues": result.common_issues
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/component_nma/analyze")
async def run_component_nma(request: ComponentNMARequest):
    """
    Component network meta-analysis

    Decomposes complex interventions into components.
    """
    try:
        data_df = pd.DataFrame(request.data)

        engine = ComponentNMAEngine(
            include_interactions=request.include_interactions
        )

        result = engine.analyze(
            data=data_df,
            treatment_components=request.treatment_components,
            outcome_var=request.outcome_var,
            se_var=request.se_var
        )

        return {
            "component_effects": result.component_effects,
            "component_ses": result.component_ses,
            "interaction_effects": result.interaction_effects,
            "treatment_predictions": result.treatment_predictions,
            "component_rankings": result.component_rankings,
            "optimal_combination": result.optimal_combination
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
