# ML Prediction Caching Guide

## Overview

EvidenceOS PRIME implements Redis-based caching for expensive ML operations, providing **10-100x speedup** for repeated queries.

## Architecture

### Components

1. **Redis Cache** (`backend/cache/ml_cache.py`)
   - Handles all caching operations
   - Automatic serialization (JSON/pickle)
   - Configurable TTL (Time To Live)
   - Pattern-based key management

2. **Cached ML Operations** (`backend/api/ml_routes.py`)
   - Heterogeneity prediction (1 hour cache)
   - Publication bias detection (1 hour cache)
   - Study quality prediction (1 hour cache)
   - Effect direction prediction (1 hour cache)
   - Analysis recommendations (30 min cache)

3. **Cache Management API**
   - `GET /ml/cache/stats` - Cache statistics and hit rates
   - `POST /ml/cache/clear` - Clear cache by pattern

## Performance

### Without Cache
- SHAP computation: **10-30 seconds**
- Ensemble prediction: **1-5 seconds**
- AutoML optimization: **minutes**
- RAG query: **1-3 seconds**

### With Cache (Hit)
- All operations: **<10ms** (1000x faster!)

### Expected Hit Rates
- Development: 30-50%
- Production: 60-80%
- Target: >80%

## Installation

### 1. Install Redis

**Docker (Recommended):**
```bash
docker run -d -p 6379:6379 --name redis redis:7-alpine
```

**Ubuntu/Debian:**
```bash
sudo apt-get install redis-server
sudo systemctl start redis-server
```

**macOS:**
```bash
brew install redis
brew services start redis
```

### 2. Install Python Dependencies
```bash
pip install redis==5.0.1 hiredis==2.3.2
```

### 3. Verify Installation
```bash
redis-cli ping
# Should return: PONG
```

## Usage

### Automatic Caching

The caching layer works **automatically** for all ML endpoints. No code changes required!

```python
# First request (cache miss)
response = client.post("/ml/predict/heterogeneity", json=data)
# Takes ~2 seconds

# Second request (cache hit)
response = client.post("/ml/predict/heterogeneity", json=data)
# Takes <10ms (200x faster!)
```

### Manual Caching

Use decorators for custom functions:

```python
from cache.ml_cache import cache_ml_prediction

@cache_ml_prediction(prefix="my_operation", ttl=3600)
def expensive_operation(data):
    # Your expensive computation
    return result
```

### Pre-configured Decorators

```python
from cache.ml_cache import (
    cache_shap_computation,      # 2 hours TTL
    cache_ensemble_prediction,   # 1 hour TTL
    cache_automl_results,        # 24 hours TTL
    cache_rag_query,             # 30 min TTL
    cache_lime_computation       # 2 hours TTL
)

@cache_shap_computation()
def compute_shap_values(model, data):
    # Expensive SHAP computation
    return shap_values
```

## Cache Management

### View Statistics

**API:**
```bash
curl http://localhost:8000/ml/cache/stats
```

**Response:**
```json
{
  "available": true,
  "total_keys": 1250,
  "ml_keys": 847,
  "used_memory": "12.5MB",
  "hit_rate": "82.3%",
  "connected_clients": 3,
  "uptime_days": 7
}
```

### Clear Cache

**Clear all ML cache:**
```bash
curl -X POST http://localhost:8000/ml/cache/clear?pattern=ml_cache:*
```

**Clear specific cache:**
```bash
# SHAP only
curl -X POST http://localhost:8000/ml/cache/clear?pattern=ml_cache:shap:*

# Ensemble predictions only
curl -X POST http://localhost:8000/ml/cache/clear?pattern=ml_cache:ensemble:*
```

### Python API

```python
from cache.ml_cache import ml_cache

# Get statistics
stats = ml_cache.stats()
print(f"Hit rate: {stats['hit_rate']}")

# Manual get/set
ml_cache.set("my_key", {"data": "value"}, ttl=3600)
result = ml_cache.get("my_key")

# Delete key
ml_cache.delete("my_key")

# Clear pattern
deleted = ml_cache.clear_pattern("ml_cache:shap:*")
print(f"Deleted {deleted} keys")
```

## Cache Keys

Keys are automatically generated using SHA256 hash of function arguments:

```
ml_cache:{prefix}:{hash}
```

Examples:
```
ml_cache:shap:a3f2e8c9d1b4a5e6
ml_cache:ensemble:7b3d9e2f1c4a8d5b
ml_cache:rag:4e8a2c7f9b3d1e5a
```

## TTL (Time To Live) Strategy

| Operation | TTL | Rationale |
|-----------|-----|-----------|
| SHAP | 2 hours | Expensive, stable results |
| Ensemble Prediction | 1 hour | Moderate cost, may change |
| AutoML Results | 24 hours | Very expensive, stable |
| RAG Query | 30 min | Moderate cost, may update |
| LIME | 2 hours | Expensive, stable results |

## Graceful Degradation

The cache system automatically falls back to uncached operation if:
- Redis is unavailable
- Cache connection fails
- Cache retrieval errors

**No user-facing errors!** Operations continue normally, just slower.

```python
if not REDIS_AVAILABLE:
    logger.warning("Redis unavailable. ML caching disabled.")
    # Operations still work, just uncached
```

## Monitoring

### Key Metrics

1. **Hit Rate**: Percentage of requests served from cache
   - Target: >80% in production
   - Low hit rate (<50%) may indicate:
     - Highly variable queries
     - TTL too short
     - Cache size too small

2. **Memory Usage**: Redis memory consumption
   - Monitor with `ml_cache.stats()`
   - Configure Redis `maxmemory` policy

3. **Response Time**:
   - Cache hit: <10ms
   - Cache miss: 1-30 seconds
   - Monitor with Prometheus metrics

### Prometheus Metrics (Future)

```python
# To be implemented
ml_cache_hits_total{operation="shap"}
ml_cache_misses_total{operation="shap"}
ml_cache_latency_seconds{operation="shap"}
```

## Troubleshooting

### Issue: Cache not working

**Check Redis connection:**
```bash
redis-cli ping
# Should return: PONG
```

**Check Python client:**
```python
from cache.ml_cache import REDIS_AVAILABLE, ml_cache
print(f"Redis available: {REDIS_AVAILABLE}")
print(ml_cache.stats())
```

### Issue: Low hit rate

**Possible causes:**
1. TTL too short → Increase TTL
2. High query variability → Normal, expected
3. Cache cleared frequently → Review clear policies
4. Redis memory full → Increase memory or set eviction policy

### Issue: Memory usage high

**Solutions:**
1. Reduce TTL for less-used operations
2. Implement LRU eviction:
   ```bash
   redis-cli config set maxmemory-policy allkeys-lru
   redis-cli config set maxmemory 2gb
   ```
3. Clear old cache periodically

## Best Practices

### 1. Cache Expensive Operations Only

✅ **Good:**
- SHAP computations (10-30s)
- Ensemble predictions (1-5s)
- AutoML optimization (minutes)

❌ **Bad:**
- Simple lookups (<100ms)
- Database queries (use DB caching)
- Static data (use in-memory cache)

### 2. Set Appropriate TTL

```python
# Stable, expensive → Long TTL (hours)
@cache_shap_computation(ttl=7200)  # 2 hours

# Dynamic, moderate cost → Short TTL (minutes)
@cache_rag_query(ttl=1800)  # 30 minutes
```

### 3. Use Descriptive Prefixes

```python
@cache_ml_prediction(prefix="shap_values")      # Good
@cache_ml_prediction(prefix="lime_weights")     # Good
@cache_ml_prediction(prefix="cache")            # Bad - too generic
```

### 4. Monitor Hit Rates

- Log cache hits/misses
- Track with Prometheus
- Alert on low hit rates (<50%)

### 5. Handle Cache Failures Gracefully

```python
try:
    result = cached_function(data)
except Exception as e:
    logger.error(f"Cache error: {e}")
    # Fall back to uncached computation
    result = uncached_function(data)
```

## Configuration

### Redis Configuration

**`docker-compose.yml`:**
```yaml
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"
  volumes:
    - redis_data:/data
  command: >
    redis-server
    --maxmemory 2gb
    --maxmemory-policy allkeys-lru
    --save 900 1
    --save 300 10
```

### Environment Variables

```bash
# .env
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=  # Optional
REDIS_MAX_CONNECTIONS=50
```

## Testing

### Unit Tests

```bash
python -m pytest tests/test_ml_integration.py::TestCaching -v
```

### Manual Testing

```python
# backend/cache/ml_cache.py
if __name__ == "__main__":
    # Run standalone tests
    python cache/ml_cache.py
```

### Load Testing

```python
# Test cache under load
for i in range(1000):
    response = client.post("/ml/predict/heterogeneity", json=data)
    print(f"Request {i}: {response.elapsed.total_seconds():.3f}s")
```

## Production Deployment

### 1. Redis High Availability

Use Redis Sentinel or Redis Cluster for HA:

```yaml
redis-sentinel:
  image: redis:7-alpine
  command: redis-sentinel /etc/redis/sentinel.conf
```

### 2. Monitoring

- Prometheus + Grafana
- Redis metrics
- Cache hit rate alerts

### 3. Backup

```bash
# Redis persistence
redis-cli BGSAVE

# Copy snapshot
cp /var/lib/redis/dump.rdb /backup/
```

### 4. Scaling

- Vertical: Increase Redis memory
- Horizontal: Redis Cluster for sharding

## Security

### 1. Redis Authentication

```bash
# Enable requirepass
redis-cli config set requirepass "your_strong_password"
```

### 2. Network Security

- Bind to localhost only (unless using cluster)
- Use firewall rules
- Enable TLS for remote connections

### 3. Access Control

```python
# Use different Redis DBs for different environments
REDIS_DB = {
    "development": 0,
    "staging": 1,
    "production": 2
}
```

## Roadmap

### Phase 1 (Current): ✅
- [x] Basic caching infrastructure
- [x] Prediction endpoint caching
- [x] Cache management API
- [x] Statistics and monitoring

### Phase 2 (Next):
- [ ] Prometheus metrics integration
- [ ] Cache warming strategies
- [ ] Distributed cache invalidation
- [ ] Cache preloading for common queries

### Phase 3 (Future):
- [ ] Redis Cluster support
- [ ] Multi-level caching (Redis + in-memory)
- [ ] Intelligent cache eviction
- [ ] ML-powered cache prediction

## Support

For issues or questions:
- GitHub Issues: [link]
- Documentation: [link]
- Discord: [link]

---

**Last Updated**: 2025-01-05
**Version**: 2.0.0
**Author**: EvidenceOS PRIME Team
