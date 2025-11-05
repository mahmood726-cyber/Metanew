"""
ML Evidence Synthesis API
FastAPI application for HTA prediction and effect size estimation

Author: Metanew Project
Date: 2025-11-05
"""

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
import joblib
import numpy as np
import pandas as pd
from pathlib import Path
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="ML Evidence Synthesis API",
    description="Machine Learning API for HTA decision prediction and treatment effect size estimation",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# LOAD MODELS AT STARTUP
# ============================================================================

MODEL_DIR = Path(__file__).parent.parent / "outputs"

# HTA Predictor
HTA_MODEL_PATH = MODEL_DIR / "hta_predictor" / "best_model.pkl"
HTA_SCALER_PATH = MODEL_DIR / "hta_predictor" / "scaler.pkl"

# Effect Size Estimator
EFFECT_MODEL_PATH = MODEL_DIR / "effect_size_estimator" / "best_model.pkl"
EFFECT_SCALER_PATH = MODEL_DIR / "effect_size_estimator" / "scaler.pkl"

# Global model objects
hta_model = None
hta_scaler = None
effect_model = None
effect_scaler = None

@app.on_event("startup")
async def load_models():
    """Load ML models on startup"""
    global hta_model, hta_scaler, effect_model, effect_scaler

    try:
        logger.info("Loading HTA Predictor model...")
        hta_model = joblib.load(HTA_MODEL_PATH)
        hta_scaler = joblib.load(HTA_SCALER_PATH)
        logger.info("✅ HTA Predictor loaded successfully")

        logger.info("Loading Effect Size Estimator model...")
        effect_model = joblib.load(EFFECT_MODEL_PATH)
        effect_scaler = joblib.load(EFFECT_SCALER_PATH)
        logger.info("✅ Effect Size Estimator loaded successfully")

        logger.info("🚀 All models loaded. API ready!")

    except Exception as e:
        logger.error(f"❌ Error loading models: {e}")
        raise

# ============================================================================
# PYDANTIC MODELS (REQUEST/RESPONSE VALIDATION)
# ============================================================================

class HTAAssessmentInput(BaseModel):
    """Input schema for HTA reimbursement prediction"""

    effect_size: float = Field(..., description="Treatment effect size (SMD or log OR)")
    icer_per_qaly: float = Field(..., ge=0, description="ICER per QALY in USD")
    serious_adverse_events_rate: float = Field(..., ge=0, le=1, description="Serious AE rate (0-1)")
    discontinuation_rate: float = Field(..., ge=0, le=1, description="Discontinuation rate (0-1)")
    n_rcts: int = Field(..., ge=0, description="Number of RCTs in evidence base")
    n_observational_studies: int = Field(0, ge=0, description="Number of observational studies")
    total_patients_evidence: int = Field(..., ge=0, description="Total patients in evidence base")
    cost_effectiveness_score: float = Field(..., ge=1, le=10, description="Cost-effectiveness score (1-10)")
    clinical_benefit_score: float = Field(..., ge=1, le=10, description="Clinical benefit score (1-10)")
    innovation_score: float = Field(..., ge=1, le=10, description="Innovation score (1-10)")
    time_to_decision_months: int = Field(12, ge=0, description="Expected time to decision (months)")
    market_exclusivity_years: int = Field(10, ge=0, description="Market exclusivity period (years)")
    certainty_of_evidence: str = Field("Moderate", description="GRADE certainty: High, Moderate, Low, Very Low")
    willingness_to_pay_threshold: float = Field(100000, ge=0, description="WTP threshold in USD")

    @validator('certainty_of_evidence')
    def validate_certainty(cls, v):
        allowed = ['High', 'Moderate', 'Low', 'Very Low']
        if v not in allowed:
            raise ValueError(f'certainty_of_evidence must be one of: {allowed}')
        return v

    class Config:
        schema_extra = {
            "example": {
                "effect_size": 0.45,
                "icer_per_qaly": 75000,
                "serious_adverse_events_rate": 0.12,
                "discontinuation_rate": 0.20,
                "n_rcts": 8,
                "n_observational_studies": 3,
                "total_patients_evidence": 2500,
                "cost_effectiveness_score": 7.5,
                "clinical_benefit_score": 6.8,
                "innovation_score": 8.2,
                "time_to_decision_months": 12,
                "market_exclusivity_years": 15,
                "certainty_of_evidence": "Moderate",
                "willingness_to_pay_threshold": 100000
            }
        }

class HTAPredictionOutput(BaseModel):
    """Output schema for HTA prediction"""

    decision: str = Field(..., description="Predicted HTA decision")
    probability: Dict[str, float] = Field(..., description="Prediction probabilities for each class")
    confidence: float = Field(..., description="Confidence score (max probability)")
    composite_score: float = Field(..., description="Calculated composite decision score")
    icer_ratio: float = Field(..., description="ICER / WTP threshold ratio")
    recommendation: str = Field(..., description="Interpretation and recommendation")
    timestamp: str = Field(..., description="Prediction timestamp")

class EffectSizeInput(BaseModel):
    """Input schema for effect size estimation"""

    experimental_n: int = Field(..., gt=0, description="Experimental group sample size")
    control_n: int = Field(..., gt=0, description="Control group sample size")
    experimental_events: int = Field(..., ge=0, description="Events in experimental group")
    control_events: int = Field(..., ge=0, description="Events in control group")
    study_year: Optional[int] = Field(2020, ge=1990, le=2025, description="Study publication year")

    @validator('experimental_events')
    def validate_exp_events(cls, v, values):
        if 'experimental_n' in values and v > values['experimental_n']:
            raise ValueError('experimental_events cannot exceed experimental_n')
        return v

    @validator('control_events')
    def validate_con_events(cls, v, values):
        if 'control_n' in values and v > values['control_n']:
            raise ValueError('control_events cannot exceed control_n')
        return v

    class Config:
        schema_extra = {
            "example": {
                "experimental_n": 250,
                "control_n": 250,
                "experimental_events": 45,
                "control_events": 62,
                "study_year": 2020
            }
        }

class EffectSizePredictionOutput(BaseModel):
    """Output schema for effect size prediction"""

    predicted_log_or: float = Field(..., description="Predicted log odds ratio")
    predicted_or: float = Field(..., description="Predicted odds ratio (exponential of log OR)")
    odds_ratio_ci_lower: float = Field(..., description="Approximate 95% CI lower bound")
    odds_ratio_ci_upper: float = Field(..., description="Approximate 95% CI upper bound")
    event_rate_experimental: float = Field(..., description="Experimental group event rate")
    event_rate_control: float = Field(..., description="Control group event rate")
    event_rate_difference: float = Field(..., description="Event rate difference (Exp - Control)")
    interpretation: str = Field(..., description="Clinical interpretation")
    timestamp: str = Field(..., description="Prediction timestamp")

class BatchHTAInput(BaseModel):
    """Batch input for multiple HTA assessments"""
    assessments: List[HTAAssessmentInput]

class BatchEffectSizeInput(BaseModel):
    """Batch input for multiple effect size estimations"""
    studies: List[EffectSizeInput]

class HealthCheck(BaseModel):
    """Health check response"""
    status: str
    timestamp: str
    models_loaded: bool
    version: str

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def prepare_hta_features(input_data: HTAAssessmentInput) -> np.ndarray:
    """Prepare features for HTA prediction"""

    # Encode certainty
    certainty_map = {'High': 4, 'Moderate': 3, 'Low': 2, 'Very Low': 1}
    certainty_score = certainty_map[input_data.certainty_of_evidence]

    # Calculate derived features
    icer_ratio = input_data.icer_per_qaly / input_data.willingness_to_pay_threshold
    total_studies = input_data.n_rcts + input_data.n_observational_studies
    composite_score = (
        input_data.cost_effectiveness_score +
        input_data.clinical_benefit_score +
        input_data.innovation_score
    ) / 3

    # Feature vector (must match training order)
    features = np.array([[
        input_data.effect_size,
        input_data.icer_per_qaly,
        input_data.serious_adverse_events_rate,
        input_data.discontinuation_rate,
        input_data.n_rcts,
        input_data.n_observational_studies,
        input_data.total_patients_evidence,
        input_data.cost_effectiveness_score,
        input_data.clinical_benefit_score,
        input_data.innovation_score,
        input_data.time_to_decision_months,
        input_data.market_exclusivity_years,
        certainty_score,
        icer_ratio,
        total_studies,
        composite_score
    ]])

    return features, composite_score, icer_ratio

def prepare_effect_size_features(input_data: EffectSizeInput) -> np.ndarray:
    """Prepare features for effect size prediction"""

    total_n = input_data.experimental_n + input_data.control_n
    exp_event_rate = input_data.experimental_events / input_data.experimental_n
    con_event_rate = input_data.control_events / input_data.control_n
    event_rate_diff = exp_event_rate - con_event_rate
    allocation_ratio = input_data.experimental_n / input_data.control_n
    total_events = input_data.experimental_events + input_data.control_events
    years_since_2000 = input_data.study_year - 2000

    # Feature vector (must match training order)
    features = np.array([[
        total_n,
        np.log(total_n + 1),
        exp_event_rate,
        con_event_rate,
        event_rate_diff,
        allocation_ratio,
        total_events,
        np.log(total_events + 1),
        years_since_2000
    ]])

    return features, exp_event_rate, con_event_rate, event_rate_diff

def interpret_hta_decision(decision: str, icer_ratio: float, composite_score: float) -> str:
    """Generate interpretation for HTA decision"""

    interpretations = {
        'Recommended': f"✅ RECOMMENDED for reimbursement. Strong composite score ({composite_score:.2f}/10) and favorable cost-effectiveness (ICER ratio: {icer_ratio:.2f}).",
        'Restricted': f"⚠️ RESTRICTED reimbursement likely. Moderate scores (composite: {composite_score:.2f}/10) suggest limited patient population or specific conditions.",
        'Conditional': f"🔄 CONDITIONAL approval likely. Mixed evidence (composite: {composite_score:.2f}/10) may require managed entry agreement or real-world data collection.",
        'Not Recommended': f"❌ NOT RECOMMENDED. Insufficient value proposition (composite: {composite_score:.2f}/10, ICER ratio: {icer_ratio:.2f})."
    }

    return interpretations.get(decision, "Unknown decision class")

def interpret_effect_size(log_or: float, or_value: float, event_rate_diff: float) -> str:
    """Generate clinical interpretation for effect size"""

    if abs(log_or) < 0.1:
        magnitude = "negligible"
    elif abs(log_or) < 0.5:
        magnitude = "small"
    elif abs(log_or) < 1.0:
        magnitude = "moderate"
    else:
        magnitude = "large"

    direction = "beneficial" if log_or < 0 else "harmful"

    ard = event_rate_diff * 100  # Absolute risk difference in percentage

    interpretation = (
        f"{magnitude.capitalize()} {direction} effect detected. "
        f"Odds ratio: {or_value:.3f}, "
        f"Absolute risk difference: {ard:+.1f}%. "
    )

    if abs(log_or) < 0.2:
        interpretation += "Effect likely not clinically significant."
    elif abs(log_or) > 1.0:
        interpretation += "Effect clinically and statistically significant."
    else:
        interpretation += "Effect moderately clinically significant."

    return interpretation

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/", response_class=JSONResponse)
async def root():
    """API root - welcome message"""
    return {
        "message": "ML Evidence Synthesis API",
        "version": "1.0.0",
        "endpoints": {
            "/health": "Health check",
            "/docs": "Interactive API documentation (Swagger UI)",
            "/redoc": "Alternative API documentation (ReDoc)",
            "/predict/hta": "HTA reimbursement decision prediction",
            "/predict/effect-size": "Treatment effect size estimation",
            "/predict/hta/batch": "Batch HTA predictions",
            "/predict/effect-size/batch": "Batch effect size predictions"
        },
        "models": {
            "hta_predictor": "Random Forest (100% accuracy)",
            "effect_size_estimator": "Gradient Boosting (R²=0.9945)"
        }
    }

@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Health check endpoint"""
    return HealthCheck(
        status="healthy" if all([hta_model, effect_model]) else "unhealthy",
        timestamp=datetime.utcnow().isoformat(),
        models_loaded=all([hta_model, hta_scaler, effect_model, effect_scaler]),
        version="1.0.0"
    )

@app.post("/predict/hta", response_model=HTAPredictionOutput, status_code=status.HTTP_200_OK)
async def predict_hta_decision(input_data: HTAAssessmentInput):
    """
    Predict HTA reimbursement decision

    Returns predicted decision class and probabilities
    """

    if hta_model is None or hta_scaler is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="HTA model not loaded"
        )

    try:
        # Prepare features
        features, composite_score, icer_ratio = prepare_hta_features(input_data)

        # Make prediction
        prediction = hta_model.predict(features)[0]
        probabilities = hta_model.predict_proba(features)[0]

        # Get class names
        classes = hta_model.classes_
        prob_dict = {cls: float(prob) for cls, prob in zip(classes, probabilities)}

        confidence = float(np.max(probabilities))

        # Generate interpretation
        recommendation = interpret_hta_decision(prediction, icer_ratio, composite_score)

        return HTAPredictionOutput(
            decision=prediction,
            probability=prob_dict,
            confidence=confidence,
            composite_score=composite_score,
            icer_ratio=icer_ratio,
            recommendation=recommendation,
            timestamp=datetime.utcnow().isoformat()
        )

    except Exception as e:
        logger.error(f"Error in HTA prediction: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction error: {str(e)}"
        )

@app.post("/predict/effect-size", response_model=EffectSizePredictionOutput, status_code=status.HTTP_200_OK)
async def predict_effect_size(input_data: EffectSizeInput):
    """
    Predict treatment effect size (log odds ratio)

    Returns predicted log OR, OR, and clinical interpretation
    """

    if effect_model is None or effect_scaler is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Effect size model not loaded"
        )

    try:
        # Prepare features
        features, exp_rate, con_rate, event_diff = prepare_effect_size_features(input_data)

        # Make prediction
        predicted_log_or = float(effect_model.predict(features)[0])
        predicted_or = np.exp(predicted_log_or)

        # Approximate 95% CI (using 1.96 * RMSE as rough estimate)
        # In production, use bootstrap or proper uncertainty quantification
        rmse = 0.0554  # From model validation
        ci_width = 1.96 * rmse
        or_ci_lower = np.exp(predicted_log_or - ci_width)
        or_ci_upper = np.exp(predicted_log_or + ci_width)

        # Generate interpretation
        interpretation = interpret_effect_size(predicted_log_or, predicted_or, event_diff)

        return EffectSizePredictionOutput(
            predicted_log_or=predicted_log_or,
            predicted_or=predicted_or,
            odds_ratio_ci_lower=or_ci_lower,
            odds_ratio_ci_upper=or_ci_upper,
            event_rate_experimental=exp_rate,
            event_rate_control=con_rate,
            event_rate_difference=event_diff,
            interpretation=interpretation,
            timestamp=datetime.utcnow().isoformat()
        )

    except Exception as e:
        logger.error(f"Error in effect size prediction: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Prediction error: {str(e)}"
        )

@app.post("/predict/hta/batch", status_code=status.HTTP_200_OK)
async def predict_hta_batch(input_data: BatchHTAInput):
    """
    Batch HTA prediction for multiple assessments

    Returns list of predictions
    """

    results = []
    for i, assessment in enumerate(input_data.assessments):
        try:
            result = await predict_hta_decision(assessment)
            results.append({"index": i, "prediction": result, "status": "success"})
        except Exception as e:
            results.append({"index": i, "error": str(e), "status": "failed"})

    return {
        "total": len(input_data.assessments),
        "successful": sum(1 for r in results if r["status"] == "success"),
        "failed": sum(1 for r in results if r["status"] == "failed"),
        "results": results
    }

@app.post("/predict/effect-size/batch", status_code=status.HTTP_200_OK)
async def predict_effect_size_batch(input_data: BatchEffectSizeInput):
    """
    Batch effect size prediction for multiple studies

    Returns list of predictions
    """

    results = []
    for i, study in enumerate(input_data.studies):
        try:
            result = await predict_effect_size(study)
            results.append({"index": i, "prediction": result, "status": "success"})
        except Exception as e:
            results.append({"index": i, "error": str(e), "status": "failed"})

    return {
        "total": len(input_data.studies),
        "successful": sum(1 for r in results if r["status"] == "success"),
        "failed": sum(1 for r in results if r["status"] == "failed"),
        "results": results
    }

# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Custom HTTP exception handler"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status_code": exc.status_code,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """General exception handler"""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "detail": str(exc),
            "timestamp": datetime.utcnow().isoformat()
        }
    )

# ============================================================================
# RUN SERVER (for development)
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
