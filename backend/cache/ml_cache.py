"""
ML Prediction Caching Layer
Provides Redis-based caching for expensive ML operations
- SHAP computations (10-30 seconds each)
- Ensemble predictions (1-5 seconds each)
- AutoML results (minutes per optimization)
- RAG embeddings (1-3 seconds per query)

Expected Performance:
- Cache hit: <10ms
- Cache miss: original computation time
- Overall speedup: 10-100x for repeated queries
"""

import json
import hashlib
import pickle
import logging
from typing import Any, Callable, Optional, Union
from functools import wraps
import redis
from datetime import timedelta

logger = logging.getLogger(__name__)

# Redis connection
try:
    redis_client = redis.Redis(
        host='localhost',
        port=6379,
        db=0,
        decode_responses=False  # We'll use pickle for complex objects
    )
    redis_client.ping()
    REDIS_AVAILABLE = True
    logger.info("✓ Redis connection established for ML caching")
except (redis.ConnectionError, redis.RedisError) as e:
    REDIS_AVAILABLE = False
    redis_client = None
    logger.warning(f"⚠ Redis unavailable: {e}. ML caching disabled.")


def generate_cache_key(prefix: str, *args, **kwargs) -> str:
    """
    Generate a unique cache key from function arguments.

    Args:
        prefix: Cache key prefix (e.g., "shap", "ensemble")
        *args: Positional arguments to hash
        **kwargs: Keyword arguments to hash

    Returns:
        Unique cache key string
    """
    # Create a deterministic string representation
    key_data = {
        "args": str(args),
        "kwargs": {k: str(v) for k, v in sorted(kwargs.items())}
    }

    # Hash the data
    key_str = json.dumps(key_data, sort_keys=True)
    key_hash = hashlib.sha256(key_str.encode()).hexdigest()[:16]

    return f"ml_cache:{prefix}:{key_hash}"


def cache_ml_prediction(
    prefix: str,
    ttl: int = 3600,  # 1 hour default
    serialize: str = "pickle"  # "pickle" or "json"
):
    """
    Decorator to cache ML prediction results in Redis.

    Usage:
        @cache_ml_prediction(prefix="shap", ttl=7200)
        def compute_shap_values(model, data):
            # expensive computation
            return shap_values

    Args:
        prefix: Cache key prefix for namespacing
        ttl: Time to live in seconds (default 1 hour)
        serialize: Serialization method ("pickle" or "json")

    Returns:
        Decorated function with caching
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # If Redis unavailable, just call the function
            if not REDIS_AVAILABLE:
                logger.debug(f"Redis unavailable, computing {func.__name__} without cache")
                return func(*args, **kwargs)

            # Generate cache key
            cache_key = generate_cache_key(prefix, *args, **kwargs)

            try:
                # Try to get from cache
                cached_data = redis_client.get(cache_key)

                if cached_data is not None:
                    # Cache hit
                    if serialize == "pickle":
                        result = pickle.loads(cached_data)
                    else:
                        result = json.loads(cached_data)

                    logger.info(f"✓ Cache HIT for {prefix}: {cache_key[:32]}...")
                    return result

                # Cache miss - compute result
                logger.info(f"⚠ Cache MISS for {prefix}: {cache_key[:32]}...")
                result = func(*args, **kwargs)

                # Store in cache
                if serialize == "pickle":
                    serialized = pickle.dumps(result)
                else:
                    serialized = json.dumps(result)

                redis_client.setex(cache_key, ttl, serialized)
                logger.info(f"✓ Cached result for {prefix} (TTL: {ttl}s)")

                return result

            except Exception as e:
                # On any cache error, fall back to computation
                logger.error(f"Cache error for {prefix}: {e}")
                return func(*args, **kwargs)

        return wrapper
    return decorator


class MLCache:
    """
    ML Cache Manager for direct cache operations.
    """

    def __init__(self):
        self.redis = redis_client
        self.available = REDIS_AVAILABLE

    def get(self, key: str) -> Optional[Any]:
        """Get value from cache."""
        if not self.available:
            return None

        try:
            cached = self.redis.get(key)
            if cached:
                return pickle.loads(cached)
            return None
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None

    def set(self, key: str, value: Any, ttl: int = 3600) -> bool:
        """Set value in cache with TTL."""
        if not self.available:
            return False

        try:
            serialized = pickle.dumps(value)
            self.redis.setex(key, ttl, serialized)
            return True
        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False

    def delete(self, key: str) -> bool:
        """Delete key from cache."""
        if not self.available:
            return False

        try:
            self.redis.delete(key)
            return True
        except Exception as e:
            logger.error(f"Cache delete error: {e}")
            return False

    def clear_pattern(self, pattern: str) -> int:
        """
        Clear all keys matching pattern.

        Args:
            pattern: Redis pattern (e.g., "ml_cache:shap:*")

        Returns:
            Number of keys deleted
        """
        if not self.available:
            return 0

        try:
            keys = self.redis.keys(pattern)
            if keys:
                return self.redis.delete(*keys)
            return 0
        except Exception as e:
            logger.error(f"Cache clear pattern error: {e}")
            return 0

    def stats(self) -> dict:
        """Get cache statistics."""
        if not self.available:
            return {
                "available": False,
                "error": "Redis not available"
            }

        try:
            info = self.redis.info()
            ml_keys = len(self.redis.keys("ml_cache:*"))

            return {
                "available": True,
                "total_keys": info.get("db0", {}).get("keys", 0),
                "ml_keys": ml_keys,
                "used_memory": info.get("used_memory_human", "N/A"),
                "hit_rate": self._calculate_hit_rate(info),
                "connected_clients": info.get("connected_clients", 0),
                "uptime_days": info.get("uptime_in_days", 0)
            }
        except Exception as e:
            logger.error(f"Cache stats error: {e}")
            return {
                "available": False,
                "error": str(e)
            }

    def _calculate_hit_rate(self, info: dict) -> str:
        """Calculate cache hit rate percentage."""
        try:
            hits = info.get("keyspace_hits", 0)
            misses = info.get("keyspace_misses", 0)
            total = hits + misses

            if total == 0:
                return "0%"

            rate = (hits / total) * 100
            return f"{rate:.1f}%"
        except Exception:
            return "N/A"


# Global cache instance
ml_cache = MLCache()


# Example usage and pre-configured decorators
def cache_shap_computation(ttl: int = 7200):
    """Cache SHAP computations for 2 hours."""
    return cache_ml_prediction(prefix="shap", ttl=ttl, serialize="pickle")


def cache_ensemble_prediction(ttl: int = 3600):
    """Cache ensemble predictions for 1 hour."""
    return cache_ml_prediction(prefix="ensemble", ttl=ttl, serialize="json")


def cache_automl_results(ttl: int = 86400):
    """Cache AutoML optimization results for 24 hours."""
    return cache_ml_prediction(prefix="automl", ttl=ttl, serialize="pickle")


def cache_rag_query(ttl: int = 1800):
    """Cache RAG query results for 30 minutes."""
    return cache_ml_prediction(prefix="rag", ttl=ttl, serialize="json")


def cache_lime_computation(ttl: int = 7200):
    """Cache LIME computations for 2 hours."""
    return cache_ml_prediction(prefix="lime", ttl=ttl, serialize="pickle")


if __name__ == "__main__":
    # Test caching
    print("Testing ML Cache...")

    @cache_ensemble_prediction(ttl=60)
    def expensive_prediction(model_id: str, features: list):
        """Simulate expensive prediction."""
        import time
        print(f"Computing prediction for {model_id} with {len(features)} features...")
        time.sleep(2)  # Simulate computation
        return {"prediction": 0.85, "confidence": 0.92}

    # First call - cache miss (should take ~2 seconds)
    print("\n1st call (cache miss):")
    import time
    start = time.time()
    result1 = expensive_prediction("xgboost_v1", [1, 2, 3, 4, 5])
    print(f"Result: {result1}, Time: {time.time() - start:.3f}s")

    # Second call - cache hit (should take <10ms)
    print("\n2nd call (cache hit):")
    start = time.time()
    result2 = expensive_prediction("xgboost_v1", [1, 2, 3, 4, 5])
    print(f"Result: {result2}, Time: {time.time() - start:.3f}s")

    # Cache stats
    print("\nCache stats:")
    print(json.dumps(ml_cache.stats(), indent=2))
