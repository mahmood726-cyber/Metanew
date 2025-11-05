"""
Enhanced Health Check Endpoints
Comprehensive system health monitoring for production
"""
from fastapi import APIRouter, Response, status
from datetime import datetime
import psutil
import sys
import importlib
from typing import Dict, Any, Set
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/health", tags=["health"])

# SECURITY: Whitelist of allowed ML libraries to prevent code injection
ALLOWED_ML_LIBRARIES: Set[str] = {
    'numpy', 'pandas', 'scipy',
    'xgboost', 'lightgbm', 'catboost',
    'shap', 'lime', 'optuna',
    'mlflow', 'evidently',
    'sentence_transformers', 'chromadb',
    'scikit-learn', 'sklearn'
}


def get_system_metrics() -> Dict[str, Any]:
    """Get system resource metrics"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')

        return {
            "cpu": {
                "percent": cpu_percent,
                "count": psutil.cpu_count(),
                "status": "healthy" if cpu_percent < 80 else "degraded"
            },
            "memory": {
                "total_gb": round(memory.total / (1024**3), 2),
                "used_gb": round(memory.used / (1024**3), 2),
                "percent": memory.percent,
                "available_gb": round(memory.available / (1024**3), 2),
                "status": "healthy" if memory.percent < 80 else "degraded"
            },
            "disk": {
                "total_gb": round(disk.total / (1024**3), 2),
                "used_gb": round(disk.used / (1024**3), 2),
                "percent": disk.percent,
                "free_gb": round(disk.free / (1024**3), 2),
                "status": "healthy" if disk.percent < 90 else "degraded"
            }
        }
    except Exception as e:
        logger.error(f"Failed to get system metrics: {str(e)}")
        return {"error": str(e)}


def check_redis_health() -> Dict[str, Any]:
    """Check Redis connectivity and health"""
    try:
        import redis
        r = redis.Redis(host='localhost', port=6379, decode_responses=True)
        r.ping()

        info = r.info()
        return {
            "status": "healthy",
            "connected": True,
            "version": info.get('redis_version', 'unknown'),
            "uptime_days": info.get('uptime_in_days', 0),
            "connected_clients": info.get('connected_clients', 0),
            "used_memory_mb": round(info.get('used_memory', 0) / (1024**2), 2),
            "keys_count": r.dbsize()
        }
    except Exception as e:
        logger.warning(f"Redis health check failed: {str(e)}")
        return {
            "status": "unavailable",
            "connected": False,
            "error": str(e)
        }


def check_database_health() -> Dict[str, Any]:
    """Check database connectivity"""
    try:
        from database.database import engine
        from sqlalchemy import text

        with engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            result.fetchone()

        return {
            "status": "healthy",
            "connected": True,
            "driver": "postgresql"
        }
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        return {
            "status": "unavailable",
            "connected": False,
            "error": str(e)
        }


def check_ml_libraries() -> Dict[str, Any]:
    """Check ML library availability"""
    ml_libs = {}

    libs_to_check = [
        'numpy', 'pandas', 'scikit-learn', 'scipy',
        'xgboost', 'lightgbm', 'catboost',
        'shap', 'lime', 'optuna',
        'mlflow', 'evidently',
        'sentence_transformers', 'chromadb'
    ]

    for lib_name in libs_to_check:
        # SECURITY FIX: Validate library name against whitelist
        if lib_name not in ALLOWED_ML_LIBRARIES:
            logger.warning(f"Attempted to check non-whitelisted library: {lib_name}")
            ml_libs[lib_name] = {
                "available": False,
                "version": None,
                "error": "Library not in whitelist"
            }
            continue

        try:
            # SECURITY FIX: Use importlib instead of __import__
            if lib_name == 'scikit-learn':
                lib = importlib.import_module('sklearn')
            else:
                lib = importlib.import_module(lib_name)

            ml_libs[lib_name] = {
                "available": True,
                "version": getattr(lib, '__version__', 'unknown')
            }
        except ImportError as e:
            ml_libs[lib_name] = {
                "available": False,
                "version": None,
                "error": str(e)
            }
        except Exception as e:
            logger.error(f"Error checking library {lib_name}: {e}")
            ml_libs[lib_name] = {
                "available": False,
                "version": None,
                "error": "Unexpected error"
            }

    available_count = sum(1 for lib in ml_libs.values() if lib['available'])
    total_count = len(ml_libs)

    return {
        "libraries": ml_libs,
        "available": available_count,
        "total": total_count,
        "percentage": round((available_count / total_count) * 100, 1),
        "status": "healthy" if available_count >= total_count * 0.8 else "degraded"
    }


@router.get("")
async def health_check():
    """
    Basic health check endpoint
    Returns 200 if service is alive
    """
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "EvidenceOS PRIME Backend",
        "version": "2.0"
    }


@router.get("/live")
async def liveness_probe():
    """
    Kubernetes liveness probe
    Returns 200 if process is alive
    """
    return {"status": "alive"}


@router.get("/ready")
async def readiness_probe(response: Response):
    """
    Kubernetes readiness probe
    Returns 200 if ready to serve traffic
    """
    checks = {
        "redis": check_redis_health(),
        "database": check_database_health(),
        "ml_libraries": check_ml_libraries()
    }

    # Determine overall readiness
    redis_ok = checks["redis"]["status"] == "healthy"
    db_ok = checks["database"]["status"] == "healthy"
    ml_ok = checks["ml_libraries"]["percentage"] >= 80

    is_ready = redis_ok and db_ok and ml_ok

    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "status": "ready" if is_ready else "not_ready",
        "checks": checks,
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/detailed")
async def detailed_health_check():
    """
    Comprehensive health check with all system metrics
    """
    checks = {
        "system": get_system_metrics(),
        "redis": check_redis_health(),
        "database": check_database_health(),
        "ml_libraries": check_ml_libraries(),
        "python": {
            "version": sys.version,
            "platform": sys.platform
        }
    }

    # Calculate overall health score
    health_scores = []

    # System health (CPU, Memory, Disk)
    if "cpu" in checks["system"]:
        health_scores.append(1 if checks["system"]["cpu"]["status"] == "healthy" else 0.5)
        health_scores.append(1 if checks["system"]["memory"]["status"] == "healthy" else 0.5)
        health_scores.append(1 if checks["system"]["disk"]["status"] == "healthy" else 0.5)

    # Redis health
    health_scores.append(1 if checks["redis"]["status"] == "healthy" else 0)

    # Database health
    health_scores.append(1 if checks["database"]["status"] == "healthy" else 0)

    # ML libraries health
    health_scores.append(1 if checks["ml_libraries"]["percentage"] >= 80 else 0.5)

    overall_score = sum(health_scores) / len(health_scores)

    if overall_score >= 0.9:
        overall_status = "healthy"
    elif overall_score >= 0.6:
        overall_status = "degraded"
    else:
        overall_status = "unhealthy"

    return {
        "status": overall_status,
        "health_score": round(overall_score * 100, 1),
        "timestamp": datetime.utcnow().isoformat(),
        "service": "EvidenceOS PRIME Backend",
        "version": "2.0",
        "checks": checks
    }


@router.get("/ml")
async def ml_health_check():
    """
    ML-specific health check
    Checks all ML components and libraries
    """
    ml_checks = check_ml_libraries()

    # Test basic ML operations
    try:
        import numpy as np
        import pandas as pd

        # Quick ML operation test
        X = np.random.randn(100, 5)
        df = pd.DataFrame(X)

        ml_checks["operations"] = {
            "numpy_test": "passed",
            "pandas_test": "passed",
            "status": "healthy"
        }
    except Exception as e:
        ml_checks["operations"] = {
            "status": "failed",
            "error": str(e)
        }

    return {
        "status": ml_checks["status"],
        "timestamp": datetime.utcnow().isoformat(),
        **ml_checks
    }
