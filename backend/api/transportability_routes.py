"""
Transportability Analysis API Routes
=====================================

Endpoints for assessing transportability of meta-analysis findings
from source populations to target populations.

Endpoints:
- POST /api/transportability/analyze - Perform transportability analysis
- GET /api/transportability/example - Get example transportability data
- POST /api/transportability/calculate-sample-size - Calculate required sample size
- POST /api/transportability/subgroup-analysis - Analyze by subgroups
"""

from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field, validator
from typing import List, Dict, Optional, Any
from datetime import datetime
import logging
import numpy as np

from ml.transportability import (
    TransportabilityAnalysis,
    TransportabilityResults,
    Study,
    Population,
    TransportMethod,
    calculate_sample_size_for_transportability,
    tipton_generalizability_index_subgroup
)
from auth import get_current_user, get_current_active_user, User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/transportability", tags=["transportability"])


# ==================== Request/Response Models ====================

class StudyRequest(BaseModel):
    """Study data for transportability analysis"""
    study_id: str = Field(..., description="Study identifier")
    treatment_effect: float = Field(..., description="Observed treatment effect (e.g., log OR, SMD)")
    standard_error: float = Field(..., gt=0, description="Standard error of treatment effect")
    sample_size: int = Field(..., gt=0, description="Total sample size")
    n_treatment: int = Field(..., gt=0, description="Sample size in treatment group")
    n_control: int = Field(..., gt=0, description="Sample size in control group")
    covariates: Dict[str, float] = Field(..., description="Study-level covariates")

    @validator('n_treatment', 'n_control')
    def validate_sample_sizes(cls, v, values):
        if 'sample_size' in values and 'n_treatment' in values:
            if values.get('n_treatment', 0) + v > values.get('sample_size', 0) + 10:
                raise ValueError("n_treatment + n_control should equal sample_size")
        return v


class PopulationRequest(BaseModel):
    """Target population data"""
    name: str = Field(..., description="Population identifier")
    covariates: Dict[str, List[float]] = Field(..., description="Covariate distributions")
    sample_size: int = Field(..., gt=0, description="Population size")

    @validator('covariates')
    def validate_covariates(cls, v, values):
        if not v:
            raise ValueError("At least one covariate required")

        sample_size = values.get('sample_size')
        for name, values_list in v.items():
            if len(values_list) != sample_size:
                raise ValueError(
                    f"Covariate '{name}' has {len(values_list)} values "
                    f"but sample_size is {sample_size}"
                )
        return v


class TransportabilityRequest(BaseModel):
    """Request for transportability analysis"""
    source_studies: List[StudyRequest] = Field(..., min_items=2, description="Source studies (RCTs)")
    target_population: PopulationRequest = Field(..., description="Target population")
    method: str = Field(
        default="inverse_odds_weighting",
        description="Transportability method",
        pattern="^(inverse_odds_weighting|stratification|regression|doubly_robust|simple)$"
    )

    @validator('method')
    def validate_method(cls, v):
        try:
            TransportMethod(v)
        except ValueError:
            raise ValueError(f"Invalid method: {v}")
        return v


class CovariateBalanceItem(BaseModel):
    """Covariate balance result"""
    covariate_name: str
    standardized_mean_difference: float
    balance_status: str  # "balanced", "small_imbalance", "moderate_imbalance", "large_imbalance"


class TransportabilityResponse(BaseModel):
    """Response from transportability analysis"""
    source_effect: float = Field(..., description="Average treatment effect in source")
    source_se: float = Field(..., description="Standard error in source")
    target_effect: float = Field(..., description="Transported effect in target")
    target_se: float = Field(..., description="Standard error in target")
    generalizability_index: float = Field(..., ge=0, le=1, description="Generalizability index (0-1)")
    covariate_balance: List[CovariateBalanceItem] = Field(..., description="Covariate balance results")
    effect_modifiers: List[str] = Field(..., description="Identified effect modifiers")
    transportability_assumption_met: bool = Field(..., description="Whether assumptions satisfied")
    sensitivity_analysis: Dict[str, Any] = Field(..., description="Sensitivity analysis results")
    warnings: List[str] = Field(default_factory=list, description="Warning messages")
    summary: str = Field(..., description="Text summary of results")
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class SampleSizeRequest(BaseModel):
    """Request for sample size calculation"""
    source_effect: float = Field(..., description="Effect size in source population")
    source_se: float = Field(..., gt=0, description="Standard error in source")
    expected_difference: float = Field(
        default=0.1,
        gt=0,
        description="Expected difference between source and target"
    )
    alpha: float = Field(default=0.05, gt=0, lt=1, description="Significance level")
    power: float = Field(default=0.80, gt=0, lt=1, description="Desired statistical power")


class SampleSizeResponse(BaseModel):
    """Response from sample size calculation"""
    required_sample_size: int = Field(..., description="Required target population sample size")
    source_effect: float
    expected_difference: float
    alpha: float
    power: float
    interpretation: str = Field(..., description="Interpretation of sample size")


class ExampleDataResponse(BaseModel):
    """Example transportability data"""
    source_studies: List[StudyRequest]
    target_population: PopulationRequest
    description: str
    use_case: str


# ==================== Helper Functions ====================

def _convert_study_request_to_model(study_req: StudyRequest) -> Study:
    """Convert API request to domain model"""
    return Study(
        study_id=study_req.study_id,
        treatment_effect=study_req.treatment_effect,
        standard_error=study_req.standard_error,
        sample_size=study_req.sample_size,
        n_treatment=study_req.n_treatment,
        n_control=study_req.n_control,
        covariates=study_req.covariates
    )


def _convert_population_request_to_model(pop_req: PopulationRequest) -> Population:
    """Convert API request to domain model"""
    # Convert list values to numpy arrays
    covariates_np = {
        name: np.array(values)
        for name, values in pop_req.covariates.items()
    }

    return Population(
        name=pop_req.name,
        covariates=covariates_np,
        sample_size=pop_req.sample_size,
        is_target=True
    )


def _convert_results_to_response(results: TransportabilityResults) -> TransportabilityResponse:
    """Convert domain model to API response"""

    # Convert covariate balance to response format
    balance_items = []
    for name, smd in results.covariate_balance.items():
        abs_smd = abs(smd)
        if abs_smd < 0.1:
            status = "balanced"
        elif abs_smd < 0.2:
            status = "small_imbalance"
        elif abs_smd < 0.5:
            status = "moderate_imbalance"
        else:
            status = "large_imbalance"

        balance_items.append(CovariateBalanceItem(
            covariate_name=name,
            standardized_mean_difference=smd,
            balance_status=status
        ))

    return TransportabilityResponse(
        source_effect=results.source_effect,
        source_se=results.source_se,
        target_effect=results.target_effect,
        target_se=results.target_se,
        generalizability_index=results.generalizability_index,
        covariate_balance=balance_items,
        effect_modifiers=results.effect_modifiers,
        transportability_assumption_met=results.transportability_assumption_met,
        sensitivity_analysis=results.sensitivity_analysis,
        warnings=results.warnings,
        summary=results.summary()
    )


# ==================== Endpoints ====================

@router.post("/analyze", response_model=TransportabilityResponse)
async def analyze_transportability(
    request: TransportabilityRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Perform transportability analysis

    Assesses whether treatment effects from source studies (e.g., RCTs)
    can be transported/generalized to a target population.

    **Method options:**
    - `inverse_odds_weighting`: Inverse odds weighting (recommended)
    - `stratification`: Stratification by covariates
    - `regression`: Outcome regression
    - `doubly_robust`: Doubly robust estimator
    - `simple`: Simple reweighting

    **Returns:**
    - Source and target population effects
    - Generalizability index (0=not generalizable, 1=perfectly generalizable)
    - Covariate balance assessment
    - Effect modifiers
    - Sensitivity analysis
    """
    try:
        logger.info(
            f"User {current_user.username} requested transportability analysis "
            f"with {len(request.source_studies)} studies"
        )

        # Convert requests to domain models
        studies = [_convert_study_request_to_model(s) for s in request.source_studies]
        target_pop = _convert_population_request_to_model(request.target_population)

        # Create analysis
        method = TransportMethod(request.method)
        analysis = TransportabilityAnalysis(
            source_studies=studies,
            target_population=target_pop,
            method=method
        )

        # Run analysis
        results = analysis.analyze()

        # Convert to response
        response = _convert_results_to_response(results)

        logger.info(
            f"Transportability analysis complete. "
            f"Generalizability index: {results.generalizability_index:.3f}"
        )

        return response

    except ValueError as e:
        logger.error(f"Validation error in transportability analysis: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Error in transportability analysis: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )


@router.post("/calculate-sample-size", response_model=SampleSizeResponse)
async def calculate_sample_size(
    request: SampleSizeRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Calculate required target population sample size

    Determines the sample size needed in the target population to detect
    a difference between source and target treatment effects.

    **Parameters:**
    - `source_effect`: Effect size observed in source population
    - `source_se`: Standard error in source
    - `expected_difference`: Expected difference between source and target (default: 0.1)
    - `alpha`: Significance level (default: 0.05)
    - `power`: Desired statistical power (default: 0.80)

    **Returns:**
    - Required sample size for target population
    """
    try:
        logger.info(f"Calculating sample size for transportability study")

        required_n = calculate_sample_size_for_transportability(
            source_effect=request.source_effect,
            source_se=request.source_se,
            expected_difference=request.expected_difference,
            alpha=request.alpha,
            power=request.power
        )

        interpretation = (
            f"To detect a difference of {request.expected_difference:.3f} between source and target "
            f"effects with {request.power*100:.0f}% power at α={request.alpha}, "
            f"you need approximately {required_n:,} participants in the target population."
        )

        response = SampleSizeResponse(
            required_sample_size=required_n,
            source_effect=request.source_effect,
            expected_difference=request.expected_difference,
            alpha=request.alpha,
            power=request.power,
            interpretation=interpretation
        )

        logger.info(f"Sample size calculation complete: n={required_n}")

        return response

    except Exception as e:
        logger.error(f"Error calculating sample size: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Calculation failed: {str(e)}"
        )


@router.get("/example", response_model=ExampleDataResponse)
async def get_example_data(
    current_user: User = Depends(get_current_user)
):
    """
    Get example transportability analysis data

    Returns a realistic example dataset for transportability analysis,
    demonstrating RCT results being transported to a real-world population.

    **Example:** Cardiovascular drug RCTs → Real-world elderly population
    """
    # Example: RCTs with younger, healthier patients → elderly real-world population
    studies = [
        StudyRequest(
            study_id="CardioRCT001",
            treatment_effect=0.48,  # log OR for mortality reduction
            standard_error=0.15,
            sample_size=200,
            n_treatment=100,
            n_control=100,
            covariates={
                "mean_age": 55.0,
                "female_proportion": 0.45,
                "comorbidity_index": 2.1,
                "baseline_risk": 0.15
            }
        ),
        StudyRequest(
            study_id="CardioRCT002",
            treatment_effect=0.55,
            standard_error=0.18,
            sample_size=150,
            n_treatment=75,
            n_control=75,
            covariates={
                "mean_age": 58.0,
                "female_proportion": 0.50,
                "comorbidity_index": 2.3,
                "baseline_risk": 0.18
            }
        ),
        StudyRequest(
            study_id="CardioRCT003",
            treatment_effect=0.42,
            standard_error=0.12,
            sample_size=300,
            n_treatment=150,
            n_control=150,
            covariates={
                "mean_age": 52.0,
                "female_proportion": 0.40,
                "comorbidity_index": 1.9,
                "baseline_risk": 0.12
            }
        ),
    ]

    # Target: Real-world elderly population (more comorbidities, higher baseline risk)
    np.random.seed(42)
    n_target = 1000

    target = PopulationRequest(
        name="Elderly Real-World Cohort",
        covariates={
            "mean_age": np.random.normal(68, 8, n_target).tolist(),  # Older
            "female_proportion": np.random.beta(6, 4, n_target).tolist(),  # More females
            "comorbidity_index": np.random.gamma(3.5, 0.7, n_target).tolist(),  # More comorbidities
            "baseline_risk": np.random.beta(3, 12, n_target).tolist()  # Higher baseline risk
        },
        sample_size=n_target
    )

    return ExampleDataResponse(
        source_studies=studies,
        target_population=target,
        description=(
            "Example: Cardiovascular drug RCTs transported to elderly real-world population. "
            "RCTs enrolled younger, healthier patients. Target population is older with "
            "more comorbidities and higher baseline risk."
        ),
        use_case="External validity assessment for real-world effectiveness"
    )


@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "transportability",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    }
