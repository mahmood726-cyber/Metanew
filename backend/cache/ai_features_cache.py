"""
Caching layer for AI features to improve performance
Uses Redis for distributed caching with TTL support
"""
import logging
import hashlib
import json
from typing import Any, Callable, Dict, Optional
from functools import wraps
import pickle
import redis
from datetime import timedelta

logger = logging.getLogger(__name__)


class AIFeaturesCache:
    """
    High-performance caching for AI features

    Features:
    - Redis-based distributed caching
    - Automatic key generation from function arguments
    - TTL support for cache expiration
    - Fallback to in-memory cache if Redis unavailable
    - Cache statistics and monitoring
    """

    def __init__(
        self,
        redis_host: str = "localhost",
        redis_port: int = 6379,
        redis_db: int = 1,  # Use DB 1 for AI features
        default_ttl: int = 3600
    ):
        """Initialize cache with Redis connection"""
        self.default_ttl = default_ttl
        self.redis_client = None
        self.memory_cache: Dict[str, Any] = {}
        self.use_memory_fallback = False

        try:
            self.redis_client = redis.Redis(
                host=redis_host,
                port=redis_port,
                db=redis_db,
                decode_responses=False,  # We'll use pickle
                socket_timeout=5,
                socket_connect_timeout=5
            )
            # Test connection
            self.redis_client.ping()
            logger.info(f"✓ AI Features cache connected to Redis at {redis_host}:{redis_port}/db{redis_db}")
        except Exception as e:
            logger.warning(f"⚠ Redis unavailable: {e}. Using in-memory cache fallback.")
            self.use_memory_fallback = True

    def _generate_cache_key(self, prefix: str, *args, **kwargs) -> str:
        """Generate unique cache key from function arguments"""
        # Create a stable string representation
        key_parts = [prefix]

        # Add positional args
        for arg in args:
            if isinstance(arg, (dict, list)):
                key_parts.append(json.dumps(arg, sort_keys=True))
            else:
                key_parts.append(str(arg))

        # Add keyword args
        for k in sorted(kwargs.keys()):
            v = kwargs[k]
            if isinstance(v, (dict, list)):
                key_parts.append(f"{k}:{json.dumps(v, sort_keys=True)}")
            else:
                key_parts.append(f"{k}:{v}")

        # Hash the combined key
        key_string = "|".join(key_parts)
        key_hash = hashlib.sha256(key_string.encode()).hexdigest()[:16]

        return f"ai_cache:{prefix}:{key_hash}"

    def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        try:
            if self.use_memory_fallback:
                return self.memory_cache.get(key)

            value = self.redis_client.get(key)
            if value:
                return pickle.loads(value)
            return None
        except Exception as e:
            logger.warning(f"Cache get error: {e}")
            return None

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> bool:
        """Set value in cache with TTL"""
        try:
            ttl = ttl or self.default_ttl

            if self.use_memory_fallback:
                self.memory_cache[key] = value
                # Note: In-memory cache doesn't expire automatically
                return True

            pickled_value = pickle.dumps(value)
            self.redis_client.setex(key, ttl, pickled_value)
            return True
        except Exception as e:
            logger.warning(f"Cache set error: {e}")
            return False

    def delete(self, key: str) -> bool:
        """Delete key from cache"""
        try:
            if self.use_memory_fallback:
                self.memory_cache.pop(key, None)
                return True

            self.redis_client.delete(key)
            return True
        except Exception as e:
            logger.warning(f"Cache delete error: {e}")
            return False

    def clear_pattern(self, pattern: str) -> int:
        """Clear all keys matching pattern"""
        try:
            if self.use_memory_fallback:
                keys_to_delete = [k for k in self.memory_cache.keys() if pattern.replace("*", "") in k]
                for k in keys_to_delete:
                    del self.memory_cache[k]
                return len(keys_to_delete)

            keys = list(self.redis_client.scan_iter(match=pattern))
            if keys:
                return self.redis_client.delete(*keys)
            return 0
        except Exception as e:
            logger.warning(f"Cache clear error: {e}")
            return 0

    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        try:
            if self.use_memory_fallback:
                return {
                    "backend": "memory",
                    "keys": len(self.memory_cache),
                    "available": True
                }

            info = self.redis_client.info()
            return {
                "backend": "redis",
                "keys": self.redis_client.dbsize(),
                "memory_used": info.get("used_memory_human", "unknown"),
                "connected_clients": info.get("connected_clients", 0),
                "hits": info.get("keyspace_hits", 0),
                "misses": info.get("keyspace_misses", 0),
                "hit_rate": (
                    info.get("keyspace_hits", 0) /
                    max(info.get("keyspace_hits", 0) + info.get("keyspace_misses", 0), 1)
                ),
                "available": True
            }
        except Exception as e:
            logger.warning(f"Cache stats error: {e}")
            return {"backend": "none", "available": False, "error": str(e)}


# Global cache instance
ai_cache = AIFeaturesCache()


def cache_report_generation(ttl: int = 7200):
    """
    Cache decorator for report generation (2 hour default)
    Report generation is expensive (10-30 seconds)
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Generate cache key
            cache_key = ai_cache._generate_cache_key("report", *args, **kwargs)

            # Try to get from cache
            cached_result = ai_cache.get(cache_key)
            if cached_result is not None:
                logger.info(f"✓ Cache HIT for report generation: {cache_key[:32]}...")
                return cached_result

            # Cache miss - compute and store
            logger.info(f"⚠ Cache MISS for report generation: {cache_key[:32]}...")
            result = func(*args, **kwargs)
            ai_cache.set(cache_key, result, ttl=ttl)

            return result
        return wrapper
    return decorator


def cache_rob_assessment(ttl: int = 3600):
    """
    Cache decorator for ROB assessment (1 hour default)
    ROB assessment is moderately expensive (1-5 seconds per study)
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            cache_key = ai_cache._generate_cache_key("rob", *args, **kwargs)

            cached_result = ai_cache.get(cache_key)
            if cached_result is not None:
                logger.info(f"✓ Cache HIT for ROB assessment: {cache_key[:32]}...")
                return cached_result

            logger.info(f"⚠ Cache MISS for ROB assessment: {cache_key[:32]}...")
            result = func(*args, **kwargs)
            ai_cache.set(cache_key, result, ttl=ttl)

            return result
        return wrapper
    return decorator


def cache_screening(ttl: int = 1800):
    """
    Cache decorator for study screening (30 minute default)
    Screening is fast but frequently repeated
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            cache_key = ai_cache._generate_cache_key("screening", *args, **kwargs)

            cached_result = ai_cache.get(cache_key)
            if cached_result is not None:
                logger.debug(f"✓ Cache HIT for screening: {cache_key[:32]}...")
                return cached_result

            logger.debug(f"⚠ Cache MISS for screening: {cache_key[:32]}...")
            result = func(*args, **kwargs)
            ai_cache.set(cache_key, result, ttl=ttl)

            return result
        return wrapper
    return decorator


def cache_pdf_extraction(ttl: int = 7200):
    """
    Cache decorator for PDF extraction (2 hour default)
    PDF extraction is expensive (5-15 seconds)
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            cache_key = ai_cache._generate_cache_key("pdf", *args, **kwargs)

            cached_result = ai_cache.get(cache_key)
            if cached_result is not None:
                logger.info(f"✓ Cache HIT for PDF extraction: {cache_key[:32]}...")
                return cached_result

            logger.info(f"⚠ Cache MISS for PDF extraction: {cache_key[:32]}...")
            result = func(*args, **kwargs)
            ai_cache.set(cache_key, result, ttl=ttl)

            return result
        return wrapper
    return decorator


def cache_bayesian_nma(ttl: int = 14400):
    """
    Cache decorator for Bayesian NMA (4 hour default)
    NMA is very expensive (2-10 minutes)
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            cache_key = ai_cache._generate_cache_key("nma", *args, **kwargs)

            cached_result = ai_cache.get(cache_key)
            if cached_result is not None:
                logger.info(f"✓ Cache HIT for Bayesian NMA: {cache_key[:32]}...")
                return cached_result

            logger.info(f"⚠ Cache MISS for Bayesian NMA: {cache_key[:32]}...")
            result = func(*args, **kwargs)
            ai_cache.set(cache_key, result, ttl=ttl)

            return result
        return wrapper
    return decorator


def cache_benchmark(ttl: int = 86400):
    """
    Cache decorator for benchmarking (24 hour default)
    Benchmarks are very expensive and rarely change
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            cache_key = ai_cache._generate_cache_key("benchmark", *args, **kwargs)

            cached_result = ai_cache.get(cache_key)
            if cached_result is not None:
                logger.info(f"✓ Cache HIT for benchmark: {cache_key[:32]}...")
                return cached_result

            logger.info(f"⚠ Cache MISS for benchmark: {cache_key[:32]}...")
            result = func(*args, **kwargs)
            ai_cache.set(cache_key, result, ttl=ttl)

            return result
        return wrapper
    return decorator


# Utility functions for cache management

def clear_all_ai_cache():
    """Clear all AI features cache"""
    return ai_cache.clear_pattern("ai_cache:*")


def clear_feature_cache(feature: str):
    """Clear cache for specific feature"""
    return ai_cache.clear_pattern(f"ai_cache:{feature}:*")


def get_cache_stats() -> Dict[str, Any]:
    """Get AI features cache statistics"""
    return ai_cache.get_stats()


# Example usage:
if __name__ == "__main__":
    # Test cache
    @cache_report_generation(ttl=60)
    def generate_test_report(meta_results, study_data):
        return {"title": "Test Report", "sections": []}

    # First call - cache miss
    result1 = generate_test_report({"pooled_effect": 0.75}, {"study_id": ["S1"]})

    # Second call - cache hit
    result2 = generate_test_report({"pooled_effect": 0.75}, {"study_id": ["S1"]})

    assert result1 == result2

    print("Cache stats:", get_cache_stats())
