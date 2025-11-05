"""
REST API for EvidenceOS ML Models

Deploy all ML models as REST API endpoints.

Features:
- FastAPI framework for high performance
- Automatic OpenAPI documentation
- CORS support for web clients
- Model hot-reloading
- Request validation with Pydantic

V3.0 ENHANCEMENT - ML API Deployment

Author: EvidenceOS PRIME
License: MIT
"""

from typing import List, Dict, Optional
from pathlib import Path
import sys

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent.parent))

try:
    from fastapi import FastAPI, HTTPException, BackgroundTasks
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel, Field
    import uvicorn
    FASTAPI_AVAILABLE = True
except ImportError:
    FASTAPI_AVAILABLE = False
    print("⚠️  FastAPI not installed. Install with: pip install fastapi uvicorn pydantic")

# Import ML models
try:
    from ml.pico_extractor_ml import MLPICOExtractor
    from ml.risk_of_bias_classifier import MLRiskOfBiasClassifier
    from ml.heterogeneity_predictor import MLHeterogeneityPredictor
    from ml.effect_size_estimator import MLEffectSizeEstimator
    from ml.publication_bias_detector import MLPublicationBiasDetector
    ML_MODELS_AVAILABLE = True
except ImportError as e:
    ML_MODELS_AVAILABLE = False
    print(f"⚠️  ML models not available: {e}")


# ============================================================================
# Pydantic Models for Request/Response Validation
# ============================================================================

class PICORequest(BaseModel):
    """Request for PICO extraction"""
    abstract: str = Field(..., description="Abstract text to extract PICO from")

class PICOResponse(BaseModel):
    """Response from PICO extraction"""
    population: List[str]
    intervention: List[str]
    comparator: List[str]
    outcome: List[str]
    sample_size: Optional[int]
    confidence: float
    method: str


class RoBRequest(BaseModel):
    """Request for Risk of Bias prediction"""
    year: int = Field(..., ge=1990, le=2030)
    n_intervention: int = Field(..., gt=0)
    n_comparator: int = Field(..., gt=0)
    follow_up_months: int = Field(..., gt=0)
    age_mean: Optional[float] = 65
    percent_male: Optional[float] = 50
    journal: Optional[str] = "Other"

class RoBResponse(BaseModel):
    """Response from Risk of Bias prediction"""
    random_sequence_generation: str
    allocation_concealment: str
    blinding_participants: str
    blinding_outcome: str
    incomplete_outcome_data: str
    selective_reporting: str
    overall_risk: str
    confidence: float
    method: str


class HeterogeneityRequest(BaseModel):
    """Request for heterogeneity prediction"""
    n_studies: int = Field(..., gt=0)
    n_total_min: int = Field(..., gt=0)
    n_total_max: int = Field(..., gt=0)
    intervention_types: int = Field(..., gt=0)
    age_range: Optional[float] = 15
    follow_up_range: Optional[float] = 24
    rob_variance: Optional[float] = 0.3
    geographic_diversity: Optional[int] = 5

class HeterogeneityResponse(BaseModel):
    """Response from heterogeneity prediction"""
    i_squared: float
    tau_squared: float
    recommended_model: str
    confidence: float
    method: str


class EffectSizeRequest(BaseModel):
    """Request for effect size prediction"""
    year: int = Field(..., ge=1990, le=2030)
    sample_size: int = Field(..., gt=0)
    age_mean: Optional[float] = 65
    percent_male: Optional[float] = 50
    follow_up_months: Optional[int] = 24
    effect_type: str = Field("HR", pattern="^(HR|RR|OR)$")

class EffectSizeResponse(BaseModel):
    """Response from effect size prediction"""
    effect_type: str
    point_estimate: float
    ci_lower: float
    ci_upper: float
    confidence: float
    method: str


class PublicationBiasRequest(BaseModel):
    """Request for publication bias detection"""
    n_studies: int = Field(..., gt=0)
    sample_sizes: List[int]
    effect_sizes: List[float]
    standard_errors: List[float]
    industry_funding_prop: Optional[float] = 0.5
    p_values: Optional[List[float]] = None

class PublicationBiasResponse(BaseModel):
    """Response from publication bias detection"""
    bias_present: bool
    probability: float
    confidence: float
    recommended_method: str
    imputed_studies: int
    egger_p_value: Optional[float]
    method: str


class HealthResponse(BaseModel):
    """API health check response"""
    status: str
    models_loaded: Dict[str, bool]
    version: str


# ============================================================================
# FastAPI Application
# ============================================================================

if FASTAPI_AVAILABLE:
    app = FastAPI(
        title="EvidenceOS ML API",
        description="REST API for EvidenceOS machine learning models",
        version="3.0.0",
        docs_url="/docs",
        redoc_url="/redoc"
    )

    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # In production, specify allowed origins
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Global model instances
    models = {
        'pico': None,
        'rob': None,
        'heterogeneity': None,
        'effect_size': None,
        'publication_bias': None
    }

    @app.on_event("startup")
    async def load_models():
        """Load all ML models on startup"""
        print("🚀 Loading ML models...")

        if not ML_MODELS_AVAILABLE:
            print("⚠️  ML models not available")
            return

        try:
            # PICO Extractor
            models['pico'] = MLPICOExtractor()
            if Path('models/pico_extractor.pkl').exists():
                models['pico'].load_model('models/pico_extractor.pkl')
                print("   ✅ PICO Extractor loaded")
            else:
                print("   ⚠️  PICO Extractor not trained")

            # RoB Classifier
            models['rob'] = MLRiskOfBiasClassifier()
            if Path('models/rob_classifier.pkl').exists():
                models['rob'].load_model('models/rob_classifier.pkl')
                print("   ✅ RoB Classifier loaded")
            else:
                print("   ⚠️  RoB Classifier not trained")

            # Heterogeneity Predictor
            models['heterogeneity'] = MLHeterogeneityPredictor()
            if Path('models/heterogeneity_predictor.pkl').exists():
                models['heterogeneity'].load_model('models/heterogeneity_predictor.pkl')
                print("   ✅ Heterogeneity Predictor loaded")
            else:
                print("   ⚠️  Heterogeneity Predictor not trained")

            # Effect Size Estimator
            models['effect_size'] = MLEffectSizeEstimator()
            if Path('models/effect_size_estimator.pkl').exists():
                models['effect_size'].load_model('models/effect_size_estimator.pkl')
                print("   ✅ Effect Size Estimator loaded")
            else:
                print("   ⚠️  Effect Size Estimator not trained")

            # Publication Bias Detector
            models['publication_bias'] = MLPublicationBiasDetector()
            if Path('models/publication_bias_detector.pkl').exists():
                models['publication_bias'].load_model('models/publication_bias_detector.pkl')
                print("   ✅ Publication Bias Detector loaded")
            else:
                print("   ⚠️  Publication Bias Detector not trained")

            print("✅ All available models loaded\n")

        except Exception as e:
            print(f"❌ Error loading models: {e}")

    # ========================================================================
    # API Endpoints
    # ========================================================================

    @app.get("/", response_model=HealthResponse)
    async def root():
        """API root - health check"""
        return HealthResponse(
            status="healthy",
            models_loaded={
                'pico': models['pico'] is not None and models['pico'].is_trained,
                'rob': models['rob'] is not None and models['rob'].is_trained,
                'heterogeneity': models['heterogeneity'] is not None and models['heterogeneity'].is_trained,
                'effect_size': models['effect_size'] is not None and models['effect_size'].is_trained,
                'publication_bias': models['publication_bias'] is not None and models['publication_bias'].is_trained
            },
            version="3.0.0"
        )

    @app.post("/pico/extract", response_model=PICOResponse)
    async def extract_pico(request: PICORequest):
        """Extract PICO elements from abstract"""
        if models['pico'] is None:
            raise HTTPException(status_code=503, detail="PICO Extractor not loaded")

        pico = models['pico'].extract(request.abstract)

        return PICOResponse(
            population=pico.population,
            intervention=pico.intervention,
            comparator=pico.comparator,
            outcome=pico.outcome,
            sample_size=pico.sample_size,
            confidence=pico.confidence,
            method='ml' if models['pico'].is_trained else 'rule-based'
        )

    @app.post("/rob/predict", response_model=RoBResponse)
    async def predict_rob(request: RoBRequest):
        """Predict Risk of Bias"""
        if models['rob'] is None:
            raise HTTPException(status_code=503, detail="RoB Classifier not loaded")

        study_features = request.dict()
        rob = models['rob'].predict(study_features)

        return RoBResponse(
            random_sequence_generation=rob.random_sequence_generation,
            allocation_concealment=rob.allocation_concealment,
            blinding_participants=rob.blinding_participants,
            blinding_outcome=rob.blinding_outcome,
            incomplete_outcome_data=rob.incomplete_outcome_data,
            selective_reporting=rob.selective_reporting,
            overall_risk=rob.overall_risk,
            confidence=rob.confidence,
            method=rob.method
        )

    @app.post("/heterogeneity/predict", response_model=HeterogeneityResponse)
    async def predict_heterogeneity(request: HeterogeneityRequest):
        """Predict meta-analysis heterogeneity"""
        if models['heterogeneity'] is None:
            raise HTTPException(status_code=503, detail="Heterogeneity Predictor not loaded")

        meta_features = request.dict()
        het = models['heterogeneity'].predict(meta_features)

        return HeterogeneityResponse(
            i_squared=het.i_squared,
            tau_squared=het.tau_squared,
            recommended_model=het.recommended_model,
            confidence=het.confidence,
            method=het.method
        )

    @app.post("/effect-size/predict", response_model=EffectSizeResponse)
    async def predict_effect_size(request: EffectSizeRequest):
        """Predict treatment effect size"""
        if models['effect_size'] is None:
            raise HTTPException(status_code=503, detail="Effect Size Estimator not loaded")

        study_features = request.dict(exclude={'effect_type'})
        effect = models['effect_size'].predict(study_features, effect_type=request.effect_type)

        return EffectSizeResponse(
            effect_type=effect.effect_type,
            point_estimate=effect.point_estimate,
            ci_lower=effect.ci_lower,
            ci_upper=effect.ci_upper,
            confidence=effect.confidence,
            method=effect.method
        )

    @app.post("/publication-bias/detect", response_model=PublicationBiasResponse)
    async def detect_publication_bias(request: PublicationBiasRequest):
        """Detect publication bias in meta-analysis"""
        if models['publication_bias'] is None:
            raise HTTPException(status_code=503, detail="Publication Bias Detector not loaded")

        ma_data = request.dict()
        pred = models['publication_bias'].predict(ma_data)

        return PublicationBiasResponse(
            bias_present=pred.bias_present,
            probability=pred.probability,
            confidence=pred.confidence,
            recommended_method=pred.recommended_method,
            imputed_studies=pred.imputed_studies,
            egger_p_value=pred.egger_p_value,
            method=pred.method
        )


# ============================================================================
# Run Server
# ============================================================================

def run_server(host: str = "0.0.0.0", port: int = 8000, reload: bool = False):
    """
    Run the ML API server

    Args:
        host: Host to bind to
        port: Port to bind to
        reload: Enable auto-reload for development
    """
    if not FASTAPI_AVAILABLE:
        print("❌ FastAPI not installed")
        print("   Install with: pip install fastapi uvicorn pydantic")
        return

    print(f"""
╔═══════════════════════════════════════════════════════════════╗
║              EvidenceOS ML API Server                         ║
║                                                               ║
║  Starting server at: http://{host}:{port}                    ║
║  API Documentation: http://{host}:{port}/docs                ║
║  Alternative docs: http://{host}:{port}/redoc                ║
║                                                               ║
║  Available endpoints:                                         ║
║    POST /pico/extract          - Extract PICO elements        ║
║    POST /rob/predict           - Predict Risk of Bias         ║
║    POST /heterogeneity/predict - Predict I² heterogeneity     ║
║    POST /effect-size/predict   - Predict treatment effects    ║
║    POST /publication-bias/detect - Detect publication bias    ║
║                                                               ║
║  Press CTRL+C to stop                                         ║
╚═══════════════════════════════════════════════════════════════╝
    """)

    uvicorn.run(
        "ml_api:app",
        host=host,
        port=port,
        reload=reload,
        log_level="info"
    )


if __name__ == "__main__":
    run_server(reload=True)
