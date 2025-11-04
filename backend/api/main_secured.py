"""
EvidenceOS PRIME FastAPI Backend - SECURED VERSION
Provides validation, computation, and utility endpoints for R frontend
WITH enhanced security: authentication, rate limiting, input sanitization
"""
from fastapi import FastAPI, HTTPException, Body, Depends, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from slow API import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from typing import Dict, List, Any, Optional
from pydantic import BaseModel
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from schemas.evidence_object import (
    EvidenceObject, ValidationResult, ValidationProblem,
    Observation, Study
)
from api.security import (
    limiter, get_current_user, get_current_active_admin, verify_api_key,
    authenticate_user, create_access_token, sanitize_input, validate_study_id,
    add_security_headers, audit_log, check_rate_limit_exceeded,
    get_cors_config, User, validate_positive, validate_probability
)

app = FastAPI(
    title="EvidenceOS PRIME API",
    description="Backend API for meta-analysis and health economics - SECURED",
    version="2.0.0",
    docs_url="/docs",  # Swagger UI
    redoc_url="/redoc"  # ReDoc
)

# Add rate limiter to app
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware with restricted origins (production-ready)
cors_config = get_cors_config()
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_config["allow_origins"],
    allow_credentials=cors_config["allow_credentials"],
    allow_methods=cors_config["allow_methods"],
    allow_headers=cors_config["allow_headers"],
    max_age=cors_config["max_age"]
)

# Trusted host middleware to prevent host header attacks
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["localhost", "127.0.0.1", "evidenceos.com", "*.evidenceos.com"]
)


# Request/Response models
class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int


class UserInfo(BaseModel):
    username: str
    role: str
    email: str


# Middleware to add security headers
@app.middleware("http")
async def add_security_headers_middleware(request: Request, call_next):
    """Add security headers to all responses"""
    response = await call_next(request)

    # Add security headers
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    return response


# ============================================================================
# AUTHENTICATION ENDPOINTS
# ============================================================================

@app.post("/auth/login", response_model=TokenResponse, tags=["Authentication"])
@limiter.limit("5/minute")  # Rate limit login attempts
async def login(request: Request, login_data: LoginRequest):
    """
    Authenticate user and return JWT token

    Rate limited to 5 attempts per minute per IP
    """
    username = sanitize_input(login_data.username, max_length=50)
    password = login_data.password  # Don't sanitize password (could contain special chars)

    # Check if user is rate limited (too many failed attempts)
    if check_rate_limit_exceeded(username, max_attempts=5, window_minutes=15):
        audit_log.log_event(
            "rate_limit_exceeded",
            username,
            request.client.host,
            "login_attempt",
            {"reason": "too_many_failed_attempts"}
        )
        raise HTTPException(
            status_code=429,
            detail="Too many failed login attempts. Please try again in 15 minutes."
        )

    # Authenticate user
    user = authenticate_user(username, password)

    if not user:
        # Log failed login
        audit_log.log_event(
            "failed_login",
            username,
            request.client.host,
            "login_attempt",
            {"reason": "invalid_credentials"}
        )
        raise HTTPException(status_code=401, detail="Invalid username or password")

    # Create access token
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role}
    )

    # Log successful login
    audit_log.log_event(
        "successful_login",
        username,
        request.client.host,
        "login",
        {"role": user.role}
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=3600  # 1 hour
    )


@app.get("/auth/me", response_model=UserInfo, tags=["Authentication"])
async def get_user_info(current_user: User = Depends(get_current_user)):
    """Get current user information"""
    return UserInfo(
        username=current_user.username,
        role=current_user.role,
        email=current_user.email
    )


@app.post("/auth/logout", tags=["Authentication"])
async def logout(request: Request, current_user: User = Depends(get_current_user)):
    """
    Logout user (client should discard token)
    """
    audit_log.log_event(
        "logout",
        current_user.username,
        request.client.host,
        "logout",
        {}
    )
    return {"message": "Logged out successfully"}


# ============================================================================
# HEALTH CHECK ENDPOINTS (Public - No Auth Required)
# ============================================================================

@app.get("/", tags=["Health"])
@limiter.limit("60/minute")
async def root(request: Request):
    """Health check endpoint"""
    return {
        "service": "EvidenceOS PRIME API (Secured)",
        "version": "2.0.0",
        "status": "operational",
        "timestamp": datetime.utcnow().isoformat(),
        "security": "enabled"
    }


@app.get("/health", tags=["Health"])
@limiter.limit("60/minute")
async def health_check(request: Request):
    """Detailed health check"""
    return {
        "status": "healthy",
        "python_version": sys.version,
        "timestamp": datetime.utcnow().isoformat(),
        "uptime": "running"
    }


# ============================================================================
# DATA VALIDATION ENDPOINTS (Requires Authentication)
# ============================================================================

@app.post("/validate", tags=["Data Validation"])
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

    **Requires Authentication**
    """
    from etl.validate import validate_table

    try:
        df = pd.DataFrame(data.get("data", []))
        data_type = sanitize_input(data.get("data_type", "binary"), max_length=20)

        # Validate study IDs
        if "study_id" in df.columns:
            df["study_id"] = df["study_id"].apply(lambda x: validate_study_id(str(x)))

        result = validate_table(df, data_type)

        # Log validation
        audit_log.log_event(
            "data_validation",
            current_user.username,
            request.client.host,
            "validate",
            {
                "data_type": data_type,
                "n_rows": len(df),
                "is_valid": result.is_valid
            }
        )

        return result.model_dump()

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/compute/yi", tags=["Effect Sizes"])
@limiter.limit("30/minute")
async def compute_effect_sizes(
    request: Request,
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Compute effect sizes (yi, sei) from raw data
    Handles binary (OR, RR), continuous (MD, SMD), and time-to-event (HR) data

    **Requires Authentication**
    """
    from etl.transform import compute_effect_size

    try:
        df = pd.DataFrame(data.get("data", []))
        measure = sanitize_input(data.get("measure", "OR"), max_length=10)

        # Validate measure
        valid_measures = ["OR", "RR", "RD", "MD", "SMD", "HR"]
        if measure not in valid_measures:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid measure. Must be one of: {', '.join(valid_measures)}"
            )

        result_df = compute_effect_size(df, measure)

        # Log computation
        audit_log.log_event(
            "effect_size_computation",
            current_user.username,
            request.client.host,
            "compute_yi",
            {
                "measure": measure,
                "n_observations": len(result_df)
            }
        )

        return {
            "data": result_df.to_dict(orient="records"),
            "measure": measure,
            "n_observations": len(result_df)
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ============================================================================
# EVIDENCE OBJECT ENDPOINTS (Requires Authentication)
# ============================================================================

@app.post("/evidence/hash", tags=["Evidence Objects"])
@limiter.limit("60/minute")
async def compute_evidence_hash(
    request: Request,
    evidence: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Compute content hash for EvidenceObject
    Used for integrity checking and reproducibility

    **Requires Authentication**
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


@app.post("/evidence/validate", tags=["Evidence Objects"])
@limiter.limit("30/minute")
async def validate_evidence_object(
    request: Request,
    evidence: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Validate complete EvidenceObject structure

    **Requires Authentication**
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


# ============================================================================
# HEALTH ECONOMICS ENDPOINTS (Requires Authentication)
# ============================================================================

@app.post("/econ/params", tags=["Health Economics"])
@limiter.limit("20/minute")
async def generate_psa_parameters(
    request: Request,
    params: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Generate PSA parameter distributions
    Returns sampled parameter sets for probabilistic sensitivity analysis

    **Requires Authentication**
    """
    try:
        n_iterations = min(int(params.get("n_iterations", 1000)), 10000)  # Cap at 10,000
        seed = params.get("seed", 42)

        np.random.seed(seed)

        # Validate input parameters
        hr_progression = validate_positive(params.get("hr_progression", 0.7), "hr_progression")
        hr_death = validate_positive(params.get("hr_death", 0.8), "hr_death")
        cost_treatment = validate_positive(params.get("cost_treatment", 10000), "cost_treatment")

        # Log-normal sampling for hazard ratios
        hr_prog_samples = np.random.lognormal(
            mean=np.log(hr_progression),
            sigma=0.2,
            size=n_iterations
        )

        hr_death_samples = np.random.lognormal(
            mean=np.log(hr_death),
            sigma=0.2,
            size=n_iterations
        )

        # Utility values (beta distribution)
        utility_stable = np.random.beta(80, 20, n_iterations)
        utility_progressed = np.random.beta(50, 50, n_iterations)

        # Costs (gamma distribution)
        cost_treatment_samples = np.random.gamma(
            shape=100,
            scale=cost_treatment / 100,
            size=n_iterations
        )

        audit_log.log_event(
            "psa_generation",
            current_user.username,
            request.client.host,
            "generate_psa",
            {"n_iterations": n_iterations}
        )

        return {
            "n_iterations": n_iterations,
            "parameters": {
                "hr_progression": hr_prog_samples.tolist(),
                "hr_death": hr_death_samples.tolist(),
                "utility_stable": utility_stable.tolist(),
                "utility_progressed": utility_progressed.tolist(),
                "cost_treatment": cost_treatment_samples.tolist()
            },
            "seed": seed
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# CONVERSION UTILITIES (Requires Authentication)
# ============================================================================

@app.post("/convert/or_to_rr", tags=["Utilities"])
@limiter.limit("60/minute")
async def convert_or_to_rr(
    request: Request,
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Convert odds ratios to risk ratios
    Uses control event rate

    **Requires Authentication**
    """
    try:
        or_value = validate_positive(data.get("or"), "or")
        control_event_rate = validate_probability(data.get("control_event_rate"), "control_event_rate")

        # Formula: RR = OR / (1 - CER + (CER * OR))
        rr = or_value / (1 - control_event_rate + (control_event_rate * or_value))

        return {
            "or": or_value,
            "rr": rr,
            "control_event_rate": control_event_rate
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ============================================================================
# ADMIN ENDPOINTS (Requires Admin Role)
# ============================================================================

@app.get("/admin/audit-log", tags=["Admin"])
@limiter.limit("10/minute")
async def get_audit_log(
    request: Request,
    limit: int = 100,
    admin_user: User = Depends(get_current_active_admin)
):
    """
    Get security audit log

    **Requires Admin Role**
    """
    logs = audit_log.get_recent_logs(limit=min(limit, 1000))
    return {
        "logs": logs,
        "count": len(logs)
    }


@app.get("/admin/stats", tags=["Admin"])
@limiter.limit("10/minute")
async def get_system_stats(
    request: Request,
    admin_user: User = Depends(get_current_active_admin)
):
    """
    Get system statistics

    **Requires Admin Role**
    """
    return {
        "total_requests": len(audit_log.logs),
        "unique_users": len(set(log["username"] for log in audit_log.logs if log["username"])),
        "timestamp": datetime.utcnow().isoformat()
    }


# ============================================================================
# BAYESIAN META-ANALYSIS (Placeholder)
# ============================================================================

@app.post("/meta/bayes", tags=["Meta-Analysis"])
@limiter.limit("5/minute")
async def bayesian_meta_analysis(
    request: Request,
    data: Dict[str, Any],
    current_user: User = Depends(get_current_user)
):
    """
    Optional Bayesian meta-analysis using PyMC
    Returns posterior distributions for pooled effect and heterogeneity

    **Status: Not Yet Implemented**
    **Requires Authentication**
    """
    try:
        return {
            "method": "bayesian",
            "message": "Bayesian analysis not yet implemented - use R for frequentist MA",
            "status": "pending",
            "planned_version": "3.0"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info",
        access_log=True
    )
