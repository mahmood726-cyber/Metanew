"""
Component Network Meta-Analysis API Routes
==========================================

Endpoints for Component NMA analysis of complex interventions.

Endpoints:
- POST /api/cnma/analyze - Run Component NMA
- POST /api/cnma/predict - Predict treatment effect
- POST /api/cnma/dismantling - Analyze component removal
- POST /api/cnma/optimal-design - Find optimal treatment combination
- GET /api/cnma/example - Get example data
"""

from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field, validator
from typing import List, Dict, Optional, Any
from datetime import datetime
import logging
import numpy as np

from ml.component_nma import (
    ComponentNMAAnalysis,
    CNMAStudy,
    CNMAEngine,
    CNMAResults,
    ComponentEffect,
    ComponentContribution,
    TreatmentPrediction,
    DismantlingAnalysis,
    OptimalTreatmentDesign,
    create_component_matrix_from_dict,
    cnma_quick_fit
)
from auth import get_current_user, get_current_active_user, User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/cnma", tags=["component-nma"])


# ==================== Request/Response Models ====================

class CNMAStudyRequest(BaseModel):
    """Study for Component NMA"""
    study_id: str = Field(..., description="Study identifier")
    treatment_arm: str = Field(..., description="Treatment arm name")
    comparison_arm: str = Field(..., description="Comparison arm name (e.g., 'Control')")
    effect_size: float = Field(..., description="Effect size (log OR, SMD, etc.)")
    standard_error: float = Field(..., gt=0, description="Standard error")
    sample_size: int = Field(..., gt=0, description="Total sample size")
    design: str = Field(default="RCT", description="Study design")


class TreatmentComponentsRequest(BaseModel):
    """Define which components are in which treatments"""
    treatment_components: Dict[str, List[str]] = Field(
        ...,
        description="Map treatment names to list of component names"
    )

    @validator('treatment_components')
    def validate_treatments(cls, v):
        if len(v) < 3:
            raise ValueError("Need at least 3 treatments")

        # Check for empty component lists
        all_components = [comp for comps in v.values() for comp in comps]
        if len(set(all_components)) < 2:
            raise ValueError("Need at least 2 unique components")

        return v


class CNMAAnalysisRequest(BaseModel):
    """Request for Component NMA analysis"""
    studies: List[CNMAStudyRequest] = Field(..., min_items=2, description="Studies")
    treatment_components: TreatmentComponentsRequest = Field(..., description="Component definitions")
    engine: str = Field(default="freq", description="Estimation engine (bayes or freq)")
    include_interactions: bool = Field(default=False, description="Include component interactions")
    prior_scale: float = Field(default=2.5, gt=0, description="Prior scale (Bayesian only)")

    @validator('engine')
    def validate_engine(cls, v):
        if v not in ["bayes", "freq"]:
            raise ValueError("engine must be 'bayes' or 'freq'")
        return v


class ComponentEffectResponse(BaseModel):
    """Component effect result"""
    component_name: str
    mean_effect: float
    standard_error: float
    lower_95ci: float
    upper_95ci: float
    z_score: float
    p_value: float
    significant: bool


class ComponentContributionResponse(BaseModel):
    """Component contribution result"""
    component_name: str
    effect_size: float
    prevalence: float
    contribution: float
    importance: float
    rank: int


class InteractionEffectResponse(BaseModel):
    """Component interaction effect"""
    component_1: str
    component_2: str
    interaction_effect: float
    standard_error: float
    p_value: float
    significant: bool


class CNMAAnalysisResponse(BaseModel):
    """Component NMA analysis results"""
    # Component effects
    component_effects: List[ComponentEffectResponse]
    component_contributions: List[ComponentContributionResponse]

    # Model info
    model_type: str
    engine: str
    n_components: int
    n_treatments: int
    n_studies: int

    # Heterogeneity
    tau: float
    tau_se: Optional[float] = None
    i_squared: Optional[float] = None

    # Interactions
    interaction_effects: List[InteractionEffectResponse] = Field(default_factory=list)

    # Model fit
    aic: Optional[float] = None
    dic: Optional[float] = None

    # Summary
    warnings: List[str] = Field(default_factory=list)
    summary: str

    timestamp: datetime = Field(default_factory=datetime.utcnow)


class PredictTreatmentRequest(BaseModel):
    """Request to predict treatment effect"""
    component_combination: Dict[str, bool] = Field(
        ...,
        description="Map component names to presence (True/False)"
    )


class PredictTreatmentResponse(BaseModel):
    """Predicted treatment effect"""
    component_combination: Dict[str, bool]
    predicted_effect: float
    standard_error: float
    lower_95ci: float
    upper_95ci: float
    active_components: List[str]
    n_components: int


class DismantlingRequest(BaseModel):
    """Request for dismantling analysis"""
    full_treatment: str = Field(..., description="Treatment with all components")
    reduced_treatment: str = Field(..., description="Treatment with some components removed")


class DismantlingResponse(BaseModel):
    """Dismantling analysis result"""
    full_treatment: str
    reduced_treatment: str
    removed_components: List[str]
    expected_effect_loss: float
    standard_error: float
    z_score: float
    p_value: float
    significant: bool
    interpretation: str


class OptimalDesignRequest(BaseModel):
    """Request for optimal treatment design"""
    max_components: Optional[int] = Field(None, gt=0, description="Maximum number of components")
    cost_per_component: Optional[Dict[str, float]] = Field(None, description="Cost of each component")
    budget: Optional[float] = Field(None, gt=0, description="Budget constraint")


class OptimalDesignResponse(BaseModel):
    """Optimal treatment design"""
    optimal_components: List[str]
    predicted_effect: float
    standard_error: float
    n_components: int
    component_effects: List[ComponentEffectResponse]
    cost_effectiveness_ratio: Optional[float] = None
    recommendation: str


# ==================== Helper Functions ====================

def _convert_study_to_model(study_req: CNMAStudyRequest) -> CNMAStudy:
    """Convert API request to domain model"""
    return CNMAStudy(
        study_id=study_req.study_id,
        treatment_arm=study_req.treatment_arm,
        comparison_arm=study_req.comparison_arm,
        effect_size=study_req.effect_size,
        standard_error=study_req.standard_error,
        sample_size=study_req.sample_size,
        design=study_req.design
    )


def _convert_component_effect(comp_eff: ComponentEffect) -> ComponentEffectResponse:
    """Convert component effect to response"""
    return ComponentEffectResponse(
        component_name=comp_eff.component_name,
        mean_effect=comp_eff.mean_effect,
        standard_error=comp_eff.standard_error,
        lower_95ci=comp_eff.lower_95ci,
        upper_95ci=comp_eff.upper_95ci,
        z_score=comp_eff.z_score,
        p_value=comp_eff.p_value,
        significant=comp_eff.significant
    )


def _convert_results_to_response(results: CNMAResults) -> CNMAAnalysisResponse:
    """Convert CNMAResults to API response"""
    return CNMAAnalysisResponse(
        component_effects=[_convert_component_effect(ce) for ce in results.component_effects],
        component_contributions=[
            ComponentContributionResponse(
                component_name=cc.component_name,
                effect_size=cc.effect_size,
                prevalence=cc.prevalence,
                contribution=cc.contribution,
                importance=cc.importance,
                rank=cc.rank
            )
            for cc in results.component_contributions
        ],
        model_type=results.model_type,
        engine=results.engine,
        n_components=results.n_components,
        n_treatments=results.n_treatments,
        n_studies=results.n_studies,
        tau=results.tau,
        tau_se=results.tau_se,
        i_squared=results.i_squared,
        interaction_effects=[
            InteractionEffectResponse(
                component_1=ie.component_1,
                component_2=ie.component_2,
                interaction_effect=ie.interaction_effect,
                standard_error=ie.standard_error,
                p_value=ie.p_value,
                significant=ie.significant
            )
            for ie in results.interaction_effects
        ],
        aic=results.aic,
        dic=results.dic,
        warnings=results.warnings,
        summary=results.summary()
    )


# ==================== Endpoints ====================

@router.post("/analyze", response_model=CNMAAnalysisResponse)
async def analyze_component_nma(
    request: CNMAAnalysisRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Run Component Network Meta-Analysis

    Decomposes complex treatment effects into component contributions.
    Estimates the effect of each component using additive models.

    **Use Cases:**
    - Psychotherapy interventions (e.g., CBT components)
    - Behavioral interventions (e.g., weight loss programs)
    - Drug combination therapies
    - Surgical procedures with multiple steps
    - Public health interventions

    **Models:**
    - Additive: Effect = Σ(component effects)
    - Additive + Interactions: Effect = Σ(component effects) + Σ(interactions)

    **Engines:**
    - `freq`: Frequentist (weighted least squares)
    - `bayes`: Bayesian (MCMC approximation)

    **Returns:**
    - Component effects with confidence intervals
    - Component contributions (effect × prevalence)
    - Interaction effects (if requested)
    - Heterogeneity estimates
    - Model fit statistics
    """
    try:
        logger.info(
            f"User {current_user.username} requested Component NMA with "
            f"{len(request.studies)} studies"
        )

        # Convert to domain models
        studies = [_convert_study_to_model(s) for s in request.studies]

        # Create component matrix
        matrix, comp_names, trt_names = create_component_matrix_from_dict(
            request.treatment_components.treatment_components
        )

        # Run analysis
        engine = CNMAEngine.BAYESIAN if request.engine == "bayes" else CNMAEngine.FREQUENTIST

        analysis = ComponentNMAAnalysis(
            studies=studies,
            component_matrix=matrix,
            component_names=comp_names,
            treatment_names=trt_names
        )

        results = analysis.fit_additive(
            engine=engine,
            include_interactions=request.include_interactions,
            prior_scale=request.prior_scale
        )

        # Convert to response
        response = _convert_results_to_response(results)

        logger.info(
            f"Component NMA complete: {results.n_components} components, "
            f"τ={results.tau:.3f}"
        )

        return response

    except ValueError as e:
        logger.error(f"Validation error in Component NMA: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Error in Component NMA: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )


@router.post("/predict", response_model=PredictTreatmentResponse)
async def predict_treatment_effect(
    request: PredictTreatmentRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Predict treatment effect for a component combination

    Given a combination of components, predicts the expected treatment effect
    based on the fitted Component NMA model.

    **Example:**
    If components A, B, C have effects 0.3, 0.5, 0.2, then a treatment
    with components A+B would have predicted effect 0.3 + 0.5 = 0.8.

    **Note:** Requires a fitted CNMA model (call /analyze first).

    **Returns:**
    - Predicted effect with confidence interval
    - List of active components
    - Standard error accounting for uncertainty in component effects
    """
    try:
        logger.info("Treatment effect prediction requested")

        # This would require session storage of fitted models
        # For now, return error message
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Treatment prediction requires fitted model in session. "
                   "Please call /analyze first and use returned component effects."
        )

    except Exception as e:
        logger.error(f"Error in treatment prediction: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/dismantling", response_model=DismantlingResponse)
async def analyze_dismantling(
    request: DismantlingRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Analyze component removal (dismantling study)

    Estimates the expected effect of removing specific components from
    a treatment package.

    **Dismantling Studies:**
    Compare full treatment package against reduced version with some
    components removed to identify essential vs. inert components.

    **Example:**
    - Full: CBT + Exposure + Relaxation
    - Reduced: CBT + Exposure
    - Analysis: Tests if Relaxation adds significant benefit

    **Returns:**
    - Expected effect loss from component removal
    - Statistical test of component necessity
    - List of removed components
    """
    try:
        logger.info(f"Dismantling analysis: {request.full_treatment} vs {request.reduced_treatment}")

        # Would require fitted model from session
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Dismantling analysis requires fitted model in session. "
                   "Please call /analyze first."
        )

    except Exception as e:
        logger.error(f"Error in dismantling analysis: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/optimal-design", response_model=OptimalDesignResponse)
async def design_optimal_treatment(
    request: OptimalDesignRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Find optimal treatment combination

    Identifies the best combination of components to maximize treatment
    effect, subject to constraints.

    **Constraints:**
    - `max_components`: Limit number of components (e.g., for feasibility)
    - `budget`: Budget constraint (requires cost_per_component)
    - `cost_per_component`: Cost of each component

    **Algorithm:**
    Ranks components by effect size and selects top components
    subject to constraints.

    **Returns:**
    - Optimal component combination
    - Predicted effect
    - Cost-effectiveness ratio (if costs provided)
    """
    try:
        logger.info("Optimal treatment design requested")

        # Would require fitted model from session
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Optimal design requires fitted model in session. "
                   "Please call /analyze first."
        )

    except Exception as e:
        logger.error(f"Error in optimal design: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/example", response_model=CNMAAnalysisRequest)
async def get_example_cnma_data(
    current_user: User = Depends(get_current_user)
):
    """
    Get example Component NMA data

    Returns example data for smoking cessation interventions with
    multiple components (counseling, pharmacotherapy, group sessions, etc.)

    **Components:**
    - Written materials
    - Counseling
    - Individual sessions
    - Group sessions
    - Pharmacotherapy (NRT)

    **Treatments:**
    - Control (no intervention)
    - Self-help (written materials)
    - Brief advice (counseling)
    - Individual counseling
    - Group therapy
    - NRT alone
    - Counseling + NRT
    - Group + NRT
    """
    np.random.seed(123)

    # Define treatment components
    treatment_components = {
        "Control": [],
        "Self-help": ["Written materials"],
        "Brief advice": ["Counseling"],
        "Individual counseling": ["Counseling", "Individual sessions"],
        "Group therapy": ["Counseling", "Group sessions"],
        "NRT": ["Pharmacotherapy"],
        "Counseling + NRT": ["Counseling", "Pharmacotherapy"],
        "Group + NRT": ["Counseling", "Group sessions", "Pharmacotherapy"]
    }

    # Generate studies
    studies = []
    study_id = 1

    treatments = list(treatment_components.keys())
    active_treatments = [t for t in treatments if t != "Control"]

    for trt in active_treatments:
        # Each active treatment compared to control in 3-5 studies
        n_studies = np.random.randint(3, 6)

        for _ in range(n_studies):
            # Simulate effect based on components
            n_components = len(treatment_components[trt])
            base_effect = 0.3 * n_components  # Simple additive
            noise = np.random.normal(0, 0.2)

            effect = base_effect + noise
            se = np.random.uniform(0.15, 0.35)

            studies.append(CNMAStudyRequest(
                study_id=f"Study{study_id}",
                treatment_arm=trt,
                comparison_arm="Control",
                effect_size=round(effect, 3),
                standard_error=round(se, 3),
                sample_size=np.random.randint(100, 500),
                design="RCT"
            ))

            study_id += 1

    return CNMAAnalysisRequest(
        studies=studies,
        treatment_components=TreatmentComponentsRequest(
            treatment_components=treatment_components
        ),
        engine="freq",
        include_interactions=False,
        prior_scale=2.5
    )


@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "component-nma",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    }
