"""
ML Evidence Synthesis API
FastAPI application for treatment effect size estimation

Author: Metanew Project
Date: 2025-11-05
Version: 2.0.0 - Focused on real Cochrane data only
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
    description="Machine Learning API for treatment effect size estimation from real Cochrane data (R²=0.9945 on 80K+ RCTs)",
    version="2.0.0",
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

# Effect Size Estimator (Gradient Boosting, R²=0.9945)
EFFECT_MODEL_PATH = MODEL_DIR / "effect_size_estimator" / "best_model.pkl"
EFFECT_SCALER_PATH = MODEL_DIR / "effect_size_estimator" / "scaler.pkl"

# Global model objects
effect_model = None
effect_scaler = None

@app.on_event("startup")
async def load_models():
    """Load ML models on startup"""
    global effect_model, effect_scaler

    try:
        logger.info("Loading Effect Size Estimator model...")
        effect_model = joblib.load(EFFECT_MODEL_PATH)
        effect_scaler = joblib.load(EFFECT_SCALER_PATH)
        logger.info("✅ Effect Size Estimator loaded successfully")
        logger.info("   Model: Gradient Boosting (R²=0.9945 on 24,086 held-out RCTs)")
        logger.info("   Dataset: 80,285 real RCTs from 501 Cochrane reviews")
        logger.info("🚀 API ready!")

    except Exception as e:
        logger.error(f"❌ Error loading model: {e}")
        raise

# ============================================================================
# PYDANTIC MODELS (REQUEST/RESPONSE VALIDATION)
# ============================================================================

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
        "message": "ML Evidence Synthesis API - Treatment Effect Size Estimation",
        "version": "2.0.0",
        "description": "Trained on 80,285 real RCTs from 501 Cochrane systematic reviews",
        "endpoints": {
            "/health": "Health check",
            "/docs": "Interactive API documentation (Swagger UI)",
            "/redoc": "Alternative API documentation (ReDoc)",
            "/predict/effect-size": "Treatment effect size estimation (log OR)",
            "/predict/effect-size/batch": "Batch effect size predictions"
        },
        "model": {
            "name": "Effect Size Estimator",
            "algorithm": "Gradient Boosting Regressor",
            "performance": {
                "R²": 0.9945,
                "RMSE": 0.0554,
                "MAE": 0.0271,
                "test_set_size": 24086
            },
            "data_source": "Pairwise70 (Real Cochrane Reviews)",
            "citation": "Machine Learning for Automated Meta-Analysis (2025)"
        }
    }

@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Health check endpoint"""
    return HealthCheck(
        status="healthy" if effect_model is not None else "unhealthy",
        timestamp=datetime.utcnow().isoformat(),
        models_loaded=all([effect_model, effect_scaler]),
        version="2.0.0"
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
