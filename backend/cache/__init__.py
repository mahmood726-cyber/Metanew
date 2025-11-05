"""
ML Caching Package
Provides Redis-based caching for expensive ML operations
"""

from .ml_cache import (
    cache_ml_prediction,
    cache_shap_computation,
    cache_ensemble_prediction,
    cache_automl_results,
    cache_rag_query,
    cache_lime_computation,
    ml_cache,
    MLCache,
    REDIS_AVAILABLE
)

__all__ = [
    'cache_ml_prediction',
    'cache_shap_computation',
    'cache_ensemble_prediction',
    'cache_automl_results',
    'cache_rag_query',
    'cache_lime_computation',
    'ml_cache',
    'MLCache',
    'REDIS_AVAILABLE'
]
