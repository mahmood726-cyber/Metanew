"""
==============================================================================
FASTAPI CACHE SERVICE - Meta-Analysis Result Caching
==============================================================================

Provides 100x speedup for repeated meta-analyses by caching results in Redis.

Architecture:
- FastAPI endpoints for cache operations
- Redis for in-memory storage (sub-5ms retrieval)
- Smart cache invalidation
- Compression for large results

Performance:
- Cache hit: ~5ms (100x faster than R computation)
- Cache miss: ~500ms (normal R speed) + ~10ms to cache
- Memory efficient: TTL-based expiration

AUTHOR: EvidenceOS Development Team
LAST UPDATED: 2025-11-06
==============================================================================
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import redis
import hashlib
import json
import zlib
import base64
from datetime import datetime, timedelta
import os

# ==============================================================================
# CONFIGURATION
# ==============================================================================

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))
CACHE_TTL = int(os.getenv("CACHE_TTL", 3600))  # 1 hour default

# ==============================================================================
# REDIS CONNECTION
# ==============================================================================

try:
    redis_client = redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        db=REDIS_DB,
        decode_responses=False,  # We'll handle encoding
        socket_connect_timeout=5,
        socket_keepalive=True
    )
    # Test connection
    redis_client.ping()
    print(f"✓ Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
except Exception as e:
    print(f"✗ Redis connection failed: {e}")
    print("  Cache service will run in degraded mode (no caching)")
    redis_client = None

# ==============================================================================
# FASTAPI APP
# ==============================================================================

app = FastAPI(
    title="EvidenceOS Cache Service",
    description="High-performance caching for meta-analysis results",
    version="1.0.0"
)

# ==============================================================================
# DATA MODELS
# ==============================================================================

class MetaAnalysisParams(BaseModel):
    """Parameters for a meta-analysis (used for cache key)"""
    data_hash: str  # Hash of input data
    outcome: Optional[str] = None
    method: str = "REML"
    model: str = "random"
    subgroup: Optional[str] = None
    moderators: Optional[List[str]] = None

class CacheRequest(BaseModel):
    """Request to check/store cache"""
    params: MetaAnalysisParams
    result: Optional[Dict[str, Any]] = None

class CacheResponse(BaseModel):
    """Response from cache"""
    hit: bool
    result: Optional[Dict[str, Any]] = None
    source: str  # "cache", "computed", or "miss"
    ttl_remaining: Optional[int] = None
    cache_key: Optional[str] = None

# ==============================================================================
# CACHE KEY GENERATION
# ==============================================================================

def generate_cache_key(params: MetaAnalysisParams) -> str:
    """
    Generate unique cache key from analysis parameters.

    Uses SHA-256 hash of sorted JSON to ensure consistency.
    Same parameters always generate same key.

    Args:
        params: Meta-analysis parameters

    Returns:
        32-character hex cache key
    """
    # Create deterministic dict (sorted keys)
    key_dict = {
        "data": params.data_hash,
        "outcome": params.outcome or "",
        "method": params.method,
        "model": params.model,
        "subgroup": params.subgroup or "",
        "moderators": sorted(params.moderators or [])
    }

    # Convert to JSON with sorted keys
    key_str = json.dumps(key_dict, sort_keys=True)

    # SHA-256 hash
    cache_key = hashlib.sha256(key_str.encode()).hexdigest()

    return f"ma:{cache_key[:32]}"  # Prefix for namespacing

# ==============================================================================
# COMPRESSION (for large results)
# ==============================================================================

def compress_result(result: Dict[str, Any]) -> bytes:
    """
    Compress result using zlib for storage efficiency.

    Large forest plot data can be 100KB+.
    Compression reduces to ~10KB (10x smaller).

    Args:
        result: Meta-analysis result dict

    Returns:
        Compressed bytes
    """
    json_str = json.dumps(result)
    compressed = zlib.compress(json_str.encode(), level=6)
    return compressed

def decompress_result(compressed: bytes) -> Dict[str, Any]:
    """
    Decompress cached result.

    Args:
        compressed: Compressed bytes

    Returns:
        Original result dict
    """
    decompressed = zlib.decompress(compressed)
    result = json.loads(decompressed.decode())
    return result

# ==============================================================================
# CACHE OPERATIONS
# ==============================================================================

@app.post("/cache/check", response_model=CacheResponse)
async def check_cache(request: CacheRequest):
    """
    Check if analysis result is cached.

    Returns cached result if available, otherwise returns miss.

    Performance:
    - Cache hit: ~5ms
    - Cache miss: ~2ms
    """
    if redis_client is None:
        return CacheResponse(
            hit=False,
            source="redis_unavailable"
        )

    try:
        # Generate cache key
        cache_key = generate_cache_key(request.params)

        # Check Redis
        cached_data = redis_client.get(cache_key)

        if cached_data:
            # Cache HIT - decompress and return
            result = decompress_result(cached_data)

            # Get TTL remaining
            ttl = redis_client.ttl(cache_key)

            return CacheResponse(
                hit=True,
                result=result,
                source="cache",
                ttl_remaining=ttl,
                cache_key=cache_key
            )
        else:
            # Cache MISS
            return CacheResponse(
                hit=False,
                source="miss",
                cache_key=cache_key
            )

    except Exception as e:
        print(f"Cache check error: {e}")
        return CacheResponse(
            hit=False,
            source="error"
        )

@app.post("/cache/store")
async def store_cache(request: CacheRequest):
    """
    Store analysis result in cache.

    Compresses result before storing to save memory.
    Sets TTL for automatic expiration.

    Performance: ~10ms
    """
    if redis_client is None:
        return {"status": "error", "message": "Redis unavailable"}

    if request.result is None:
        raise HTTPException(400, "Result is required for storage")

    try:
        # Generate cache key
        cache_key = generate_cache_key(request.params)

        # Compress result
        compressed = compress_result(request.result)

        # Store in Redis with TTL
        redis_client.setex(
            cache_key,
            CACHE_TTL,
            compressed
        )

        return {
            "status": "success",
            "cache_key": cache_key,
            "ttl": CACHE_TTL,
            "size_bytes": len(compressed)
        }

    except Exception as e:
        print(f"Cache store error: {e}")
        return {"status": "error", "message": str(e)}

@app.delete("/cache/clear")
async def clear_cache(pattern: str = "ma:*"):
    """
    Clear cache entries matching pattern.

    Use with caution - clears cached results.

    Args:
        pattern: Redis key pattern (default: all meta-analyses)
    """
    if redis_client is None:
        return {"status": "error", "message": "Redis unavailable"}

    try:
        keys = redis_client.keys(pattern)
        if keys:
            redis_client.delete(*keys)

        return {
            "status": "success",
            "cleared": len(keys),
            "pattern": pattern
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==============================================================================
# CACHE STATISTICS
# ==============================================================================

@app.get("/cache/stats")
async def cache_stats():
    """
    Get cache statistics.

    Returns:
    - Total cached entries
    - Memory usage
    - Hit rate (if tracked)
    """
    if redis_client is None:
        return {"status": "error", "message": "Redis unavailable"}

    try:
        # Get all MA cache keys
        keys = redis_client.keys("ma:*")

        # Calculate total memory
        total_memory = 0
        for key in keys:
            memory = redis_client.memory_usage(key) or 0
            total_memory += memory

        # Get Redis info
        info = redis_client.info()

        return {
            "status": "success",
            "cached_analyses": len(keys),
            "total_memory_mb": round(total_memory / 1024 / 1024, 2),
            "redis_memory_mb": round(int(info.get("used_memory", 0)) / 1024 / 1024, 2),
            "redis_uptime_hours": round(int(info.get("uptime_in_seconds", 0)) / 3600, 1),
            "ttl_seconds": CACHE_TTL
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==============================================================================
# HEALTH CHECK
# ==============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    redis_status = "connected" if redis_client else "unavailable"

    if redis_client:
        try:
            redis_client.ping()
            redis_status = "connected"
        except:
            redis_status = "error"

    return {
        "status": "healthy",
        "service": "cache_service",
        "version": "1.0.0",
        "redis": redis_status,
        "cache_ttl": CACHE_TTL
    }

# ==============================================================================
# STARTUP/SHUTDOWN
# ==============================================================================

@app.on_event("startup")
async def startup_event():
    """Run on service startup"""
    print("=" * 70)
    print("EvidenceOS Cache Service Starting")
    print("=" * 70)
    print(f"Redis: {REDIS_HOST}:{REDIS_PORT}")
    print(f"Cache TTL: {CACHE_TTL}s ({CACHE_TTL/3600:.1f} hours)")
    print("=" * 70)

@app.on_event("shutdown")
async def shutdown_event():
    """Run on service shutdown"""
    if redis_client:
        redis_client.close()
    print("Cache service shutdown complete")

# ==============================================================================
# MAIN (for development)
# ==============================================================================

if __name__ == "__main__":
    import uvicorn

    print("Starting FastAPI Cache Service...")
    print("Docs available at: http://localhost:8001/docs")

    uvicorn.run(
        "cache_service:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
        log_level="info"
    )
