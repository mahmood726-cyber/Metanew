"""
Prometheus Metrics for Production Monitoring
Exposes application metrics in Prometheus format
"""
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi import APIRouter, Response
import time
import psutil
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/metrics", tags=["metrics"])

# ============================================================================
# Request Metrics
# ============================================================================

http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

# ============================================================================
# ML Model Metrics
# ============================================================================

ml_predictions_total = Counter(
    'ml_predictions_total',
    'Total ML predictions made',
    ['model_type', 'model_name']
)

ml_prediction_duration_seconds = Histogram(
    'ml_prediction_duration_seconds',
    'ML prediction duration in seconds',
    ['model_type']
)

ml_training_total = Counter(
    'ml_training_total',
    'Total ML model training jobs',
    ['model_type', 'status']
)

ml_training_duration_seconds = Histogram(
    'ml_training_duration_seconds',
    'ML model training duration in seconds',
    ['model_type']
)

# ============================================================================
# Cache Metrics
# ============================================================================

cache_hits_total = Counter(
    'cache_hits_total',
    'Total cache hits',
    ['cache_type']
)

cache_misses_total = Counter(
    'cache_misses_total',
    'Total cache misses',
    ['cache_type']
)

cache_size_bytes = Gauge(
    'cache_size_bytes',
    'Current cache size in bytes'
)

cache_keys_total = Gauge(
    'cache_keys_total',
    'Total number of keys in cache'
)

# ============================================================================
# Database Metrics
# ============================================================================

db_connections_active = Gauge(
    'db_connections_active',
    'Number of active database connections'
)

db_query_duration_seconds = Histogram(
    'db_query_duration_seconds',
    'Database query duration in seconds',
    ['query_type']
)

db_errors_total = Counter(
    'db_errors_total',
    'Total database errors',
    ['error_type']
)

# ============================================================================
# System Metrics
# ============================================================================

system_cpu_percent = Gauge(
    'system_cpu_percent',
    'CPU usage percentage'
)

system_memory_bytes = Gauge(
    'system_memory_bytes',
    'Memory usage in bytes',
    ['type']
)

system_disk_bytes = Gauge(
    'system_disk_bytes',
    'Disk usage in bytes',
    ['type']
)

# ============================================================================
# Application Metrics
# ============================================================================

app_info = Gauge(
    'app_info',
    'Application information',
    ['version', 'environment']
)

active_users = Gauge(
    'active_users',
    'Number of currently active users'
)

# ============================================================================
# Helper Functions
# ============================================================================

def update_system_metrics():
    """Update system resource metrics"""
    try:
        # CPU
        cpu_percent = psutil.cpu_percent(interval=0.1)
        system_cpu_percent.set(cpu_percent)

        # Memory
        memory = psutil.virtual_memory()
        system_memory_bytes.labels(type='total').set(memory.total)
        system_memory_bytes.labels(type='used').set(memory.used)
        system_memory_bytes.labels(type='available').set(memory.available)

        # Disk
        disk = psutil.disk_usage('/')
        system_disk_bytes.labels(type='total').set(disk.total)
        system_disk_bytes.labels(type='used').set(disk.used)
        system_disk_bytes.labels(type='free').set(disk.free)

    except Exception as e:
        logger.error(f"Failed to update system metrics: {str(e)}")


def update_cache_metrics():
    """Update Redis cache metrics"""
    try:
        import redis
        r = redis.Redis(host='localhost', port=6379, decode_responses=True)

        if r.ping():
            info = r.info()
            cache_size_bytes.set(info.get('used_memory', 0))
            cache_keys_total.set(r.dbsize())
    except Exception as e:
        logger.debug(f"Redis not available for metrics: {str(e)}")


# ============================================================================
# Metrics Endpoint
# ============================================================================

@router.get("")
async def metrics():
    """
    Prometheus metrics endpoint
    Exposes all application metrics in Prometheus format
    """
    # Update dynamic metrics
    update_system_metrics()
    update_cache_metrics()

    # Set application info
    app_info.labels(version='2.0', environment='production').set(1)

    # Generate Prometheus format
    metrics_output = generate_latest()
    return Response(
        content=metrics_output,
        media_type=CONTENT_TYPE_LATEST
    )


# ============================================================================
# Middleware Helper
# ============================================================================

class MetricsMiddleware:
    """
    Middleware to automatically track request metrics
    Use in main.py: app.add_middleware(MetricsMiddleware)
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        method = scope["method"]
        path = scope["path"]

        # Skip metrics endpoint itself
        if path == "/metrics":
            await self.app(scope, receive, send)
            return

        start_time = time.time()
        status_code = 500  # Default to error

        async def send_wrapper(message):
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            # Record metrics
            duration = time.time() - start_time
            http_requests_total.labels(
                method=method,
                endpoint=path,
                status=status_code
            ).inc()
            http_request_duration_seconds.labels(
                method=method,
                endpoint=path
            ).observe(duration)


# ============================================================================
# Context Managers for Tracking
# ============================================================================

class track_prediction:
    """Context manager to track ML predictions"""

    def __init__(self, model_type: str, model_name: str):
        self.model_type = model_type
        self.model_name = model_name
        self.start_time = None

    def __enter__(self):
        self.start_time = time.time()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        duration = time.time() - self.start_time
        ml_predictions_total.labels(
            model_type=self.model_type,
            model_name=self.model_name
        ).inc()
        ml_prediction_duration_seconds.labels(
            model_type=self.model_type
        ).observe(duration)


class track_training:
    """Context manager to track ML training"""

    def __init__(self, model_type: str):
        self.model_type = model_type
        self.start_time = None
        self.status = "success"

    def __enter__(self):
        self.start_time = time.time()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is not None:
            self.status = "failure"

        duration = time.time() - self.start_time
        ml_training_total.labels(
            model_type=self.model_type,
            status=self.status
        ).inc()
        ml_training_duration_seconds.labels(
            model_type=self.model_type
        ).observe(duration)


class track_cache:
    """Context manager to track cache operations"""

    def __init__(self, cache_type: str):
        self.cache_type = cache_type
        self.hit = False

    def __enter__(self):
        return self

    def mark_hit(self):
        self.hit = True

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.hit:
            cache_hits_total.labels(cache_type=self.cache_type).inc()
        else:
            cache_misses_total.labels(cache_type=self.cache_type).inc()


# ============================================================================
# Usage Examples
# ============================================================================

"""
Usage in your code:

# Track predictions
from api.metrics import track_prediction

with track_prediction(model_type="xgboost", model_name="heterogeneity_predictor"):
    predictions = model.predict(X)

# Track training
from api.metrics import track_training

with track_training(model_type="lightgbm"):
    model.fit(X_train, y_train)

# Track cache
from api.metrics import track_cache

with track_cache(cache_type="predictions") as cache_tracker:
    value = redis_client.get(key)
    if value is not None:
        cache_tracker.mark_hit()
"""
