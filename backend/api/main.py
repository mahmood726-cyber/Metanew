"""
EvidenceOS PRIME FastAPI Backend - Enhanced with Security
Provides validation, computation, and utility endpoints for R frontend
Includes authentication, authorization, security headers, and rate limiting
"""
from fastapi import FastAPI, HTTPException, Body, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from typing import Dict, List, Any, Optional
import sys
import pandas as pd
import numpy as np
from datetime import datetime
import os
import logging
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from schemas.evidence_object import (
    EvidenceObject, ValidationResult, ValidationProblem,
    Observation, Study
)
from auth import (
    get_current_user,
    User,
    Permission,
    PermissionChecker,
)
from api.auth_routes import router as auth_router
from api.ml_routes import router as ml_router

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Rate limiting
limiter = Limiter(key_func=get_remote_address)

# Get configuration from environment
ENVIRONMENT = os.getenv("APP_ENV", "development")
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3838,http://localhost:8000"
).split(",")
ENABLE_AUTH = os.getenv("ENABLE_AUTH", "true").lower() == "true"

app = FastAPI(
    title="EvidenceOS PRIME API",
    description="Backend API for meta-analysis and health economics with enterprise security",
    version="2.0.0",
    docs_url="/docs" if ENVIRONMENT == "development" else None,  # Disable docs in production
    redoc_url="/redoc" if ENVIRONMENT == "development" else None,
)

# Add rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware with restrictions
if ENVIRONMENT == "development":
    # Allow all in development
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    # Restrict in production
    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
        max_age=3600,
    )

# Trusted host middleware (optional, for production)
if ENVIRONMENT == "production":
    trusted_hosts = os.getenv("TRUSTED_HOSTS", "").split(",")
    if trusted_hosts:
        app.add_middleware(
            TrustedHostMiddleware,
            allowed_hosts=trusted_hosts
        )


# Security headers middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Add security headers to all responses"""
    response = await call_next(request)

    # Security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    if ENVIRONMENT == "production":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self'; "
            "style-src 'self' 'unsafe-inline'; "
            "img-src 'self' data: https:; "
            "font-src 'self'; "
            "connect-src 'self'; "
            "frame-ancestors 'none'"
        )

    return response


# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all requests for audit purposes"""
    start_time = datetime.utcnow()

    # Log request
    logger.info(f"Request: {request.method} {request.url.path}")

    try:
        response = await call_next(request)
        duration = (datetime.utcnow() - start_time).total_seconds()

        logger.info(
            f"Response: {request.method} {request.url.path} "
            f"Status: {response.status_code} Duration: {duration:.3f}s"
        )

        return response

    except Exception as e:
        logger.error(f"Request failed: {request.method} {request.url.path} Error: {str(e)}")
        raise


# Include authentication routes with /api prefix
app.include_router(auth_router, prefix="/api")

# Include AI/ML routes with /api prefix
app.include_router(ml_router, prefix="/api")


# Health check endpoints (no auth required)

@app.get("/")
@limiter.limit("60/minute")
async def root(request: Request):
    """Health check endpoint"""
    return {
        "service": "EvidenceOS PRIME API",
        "version": "2.0.0",
        "status": "operational",
        "environment": ENVIRONMENT,
        "auth_enabled": ENABLE_AUTH,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/health")
@limiter.limit("60/minute")
async def health_check(request: Request):
    """Detailed health check"""
    return {
        "status": "healthy",
        "version": "2.0.0",
        "python_version": sys.version,
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/ready")
@limiter.limit("60/minute")
async def readiness_check(request: Request):
    """Kubernetes readiness probe - checks if app is ready to serve traffic"""
    # Check critical dependencies
    try:
        # Could add database connectivity check, etc.
        return {
            "status": "ready",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Readiness check failed: {str(e)}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "not_ready",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )


@app.get("/live")
@limiter.limit("60/minute")
async def liveness_check(request: Request):
    """Kubernetes liveness probe - checks if app is alive"""
    return {
        "status": "alive",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/health/ml")
@limiter.limit("60/minute")
async def ml_health_check(request: Request):
    """ML/AI system health check"""
    try:
        # Check ML module availability
        ml_status = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "components": {}
        }

        # Check advanced gradient boosting libraries
        try:
            import xgboost
            ml_status["components"]["xgboost"] = {
                "available": True,
                "version": xgboost.__version__
            }
        except ImportError:
            ml_status["components"]["xgboost"] = {"available": False}

        try:
            import lightgbm
            ml_status["components"]["lightgbm"] = {
                "available": True,
                "version": lightgbm.__version__
            }
        except ImportError:
            ml_status["components"]["lightgbm"] = {"available": False}

        try:
            import catboost
            ml_status["components"]["catboost"] = {
                "available": True,
                "version": catboost.__version__
            }
        except ImportError:
            ml_status["components"]["catboost"] = {"available": False}

        # Check explainable AI
        try:
            import shap
            ml_status["components"]["shap"] = {
                "available": True,
                "version": shap.__version__
            }
        except ImportError:
            ml_status["components"]["shap"] = {"available": False}

        try:
            import lime
            ml_status["components"]["lime"] = {"available": True}
        except ImportError:
            ml_status["components"]["lime"] = {"available": False}

        # Check AutoML
        try:
            import optuna
            ml_status["components"]["optuna"] = {
                "available": True,
                "version": optuna.__version__
            }
        except ImportError:
            ml_status["components"]["optuna"] = {"available": False}

        # Check MLOps
        try:
            import mlflow
            ml_status["components"]["mlflow"] = {
                "available": True,
                "version": mlflow.__version__
            }
        except ImportError:
            ml_status["components"]["mlflow"] = {"available": False}

        try:
            import evidently
            ml_status["components"]["evidently"] = {
                "available": True,
                "version": evidently.__version__
            }
        except ImportError:
            ml_status["components"]["evidently"] = {"available": False}

        # Check RAG system
        try:
            import chromadb
            ml_status["components"]["chromadb"] = {
                "available": True,
                "version": chromadb.__version__
            }
        except ImportError:
            ml_status["components"]["chromadb"] = {"available": False}

        try:
            from sentence_transformers import SentenceTransformer
            ml_status["components"]["sentence_transformers"] = {"available": True}
        except ImportError:
            ml_status["components"]["sentence_transformers"] = {"available": False}

        # Check local LLM
        try:
            from llama_cpp import Llama
            from ml.llm_integration import llm_manager
            ml_status["components"]["llama_cpp"] = {"available": True}
            ml_status["components"]["llm_loaded"] = llm_manager.is_loaded if hasattr(llm_manager, 'is_loaded') else False
        except ImportError:
            ml_status["components"]["llama_cpp"] = {"available": False}
            ml_status["components"]["llm_loaded"] = False

        # Overall ML health
        critical_components = ["xgboost", "lightgbm", "catboost", "shap", "lime"]
        critical_available = sum(1 for c in critical_components if ml_status["components"].get(c, {}).get("available", False))

        ml_status["critical_components_available"] = f"{critical_available}/{len(critical_components)}"
        ml_status["ml_ready"] = critical_available >= 3  # At least 3 out of 5

        if ml_status["ml_ready"]:
            ml_status["status"] = "healthy"
        elif critical_available > 0:
            ml_status["status"] = "degraded"
        else:
            ml_status["status"] = "unavailable"

        return ml_status

    except Exception as e:
        logger.error(f"ML health check failed: {str(e)}")
        return {
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


# Data validation endpoints

@app.post("/validate")
@limiter.limit("30/minute")
async def validate_data(
    request: Request,
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Validate input data table
    Expects: {"data": [...], "data_type": "binary|continuous|tte"}
    Returns: ValidationResult with problems and normalized data

    Requires: READ_DATA permission
    """
    from etl.validate import validate_table

    try:
        logger.info(f"Validation request from user: {current_user.username}")

        df = pd.DataFrame(data.get("data", []))
        data_type = data.get("data_type", "binary")

        result = validate_table(df, data_type)

        return result.model_dump()

    except Exception as e:
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/compute-effect-size")
@limiter.limit("30/minute")
async def compute_effect_sizes(
    request: Request,
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Compute effect sizes (yi, sei) from raw data
    Handles binary (OR, RR), continuous (MD, SMD), and time-to-event (HR) data

    Requires: RUN_ANALYSIS permission
    """
    from etl.transform import compute_effect_size

    try:
        logger.info(f"Effect size computation from user: {current_user.username}")

        df = pd.DataFrame(data.get("data", []))
        measure = data.get("effect_measure", "OR")

        result_df = compute_effect_size(df, measure)

        return {
            "data": result_df.to_dict(orient="records"),
            "yi": result_df['yi'].tolist(),
            "sei": result_df['sei'].tolist(),
            "vi": result_df['vi'].tolist(),
            "measure": measure,
            "n_observations": len(result_df)
        }

    except Exception as e:
        logger.error(f"Effect size computation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))


# PSA endpoint

@app.post("/psa/run")
@limiter.limit("10/minute")
async def run_psa(
    request: Request,
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Run Probabilistic Sensitivity Analysis
    Generate parameter distributions and sample for Monte Carlo simulation

    Requires: RUN_ANALYSIS permission
    """
    try:
        logger.info(f"PSA request from user: {current_user.username}")

        n_iterations = data.get("n_iterations", 1000)
        if n_iterations > 10000:
            raise ValueError("Maximum 10,000 iterations allowed")

        seed = data.get("seed", 42)
        parameters = data.get("parameters", {})

        np.random.seed(seed)

        # Sample parameters based on distributions
        results = {"iterations": []}

        for i in range(n_iterations):
            iteration = {"iteration": i}

            for param_name, param_config in parameters.items():
                dist = param_config.get("distribution", "normal")
                mean = param_config.get("mean", 0)
                sd = param_config.get("sd", 1)

                if dist == "normal":
                    value = np.random.normal(mean, sd)
                elif dist == "lognormal":
                    value = np.random.lognormal(np.log(mean), sd)
                elif dist == "beta":
                    # Use method of moments to get alpha, beta from mean, sd
                    alpha = mean * ((mean * (1 - mean) / (sd ** 2)) - 1)
                    beta = (1 - mean) * ((mean * (1 - mean) / (sd ** 2)) - 1)
                    value = np.random.beta(alpha, beta)
                elif dist == "gamma":
                    shape = (mean / sd) ** 2
                    scale = (sd ** 2) / mean
                    value = np.random.gamma(shape, scale)
                else:
                    value = np.random.normal(mean, sd)

                iteration[param_name] = float(value)

            results["iterations"].append(iteration)

        # Calculate summary statistics
        results["summary"] = {
            "n_iterations": n_iterations,
            "parameters": list(parameters.keys()),
            "seed": seed
        }

        return results

    except Exception as e:
        logger.error(f"PSA error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))


# Evidence object endpoints

@app.post("/evidence/hash")
@limiter.limit("30/minute")
async def compute_evidence_hash(
    request: Request,
    evidence: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
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
        logger.error(f"Hash computation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/evidence/validate")
@limiter.limit("30/minute")
async def validate_evidence_object(
    request: Request,
    evidence: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
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
        logger.error(f"Evidence validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Validation failed: {str(e)}")


# Utility endpoints

@app.post("/convert/or_to_rr")
async def convert_or_to_rr(
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
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
async def format_league_table(
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
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


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle all unhandled exceptions"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)

    # Don't leak internal details in production
    if ENVIRONMENT == "production":
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"}
        )
    else:
        return JSONResponse(
            status_code=500,
            content={"detail": str(exc)}
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info",
        access_log=True
    )
