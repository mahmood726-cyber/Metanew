"""
Redis-based Distributed Cache for EvidenceOS PRIME
Provides fast, distributed caching with automatic serialization
"""
import redis
import json
from typing import Optional, Any, Dict
import hashlib
from datetime import timedelta
from backend.config import settings
from backend.utils.logging_config import get_logger
from backend.utils.retry import retry_on_redis_error
from backend.exceptions import CacheError

logger = get_logger(__name__)


class RedisCache:
    """
    Redis-based distributed cache with automatic retry and error handling

    Features:
    - Automatic JSON serialization/deserialization
    - Configurable TTL
    - Connection pooling
    - Automatic retry on connection failures
    - Graceful degradation (returns None on cache miss)
    """

    def __init__(
        self,
        host: str = None,
        port: int = None,
        db: int = None,
        password: str = None
    ):
        """
        Initialize Redis cache

        Args:
            host: Redis host (defaults to settings.REDIS_HOST)
            port: Redis port (defaults to settings.REDIS_PORT)
            db: Redis database number (defaults to settings.REDIS_DB)
            password: Redis password (defaults to settings.REDIS_PASSWORD)
        """
        self.host = host or settings.REDIS_HOST
        self.port = port or settings.REDIS_PORT
        self.db = db or settings.REDIS_DB
        self.password = password or settings.REDIS_PASSWORD

        try:
            self.client = redis.Redis(
                host=self.host,
                port=self.port,
                db=self.db,
                password=self.password,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_keepalive=True,
                health_check_interval=30,
                retry_on_timeout=True,
                max_connections=50
            )

            # Test connection
            self.client.ping()
            logger.info(f"Redis cache connected: {self.host}:{self.port}/{self.db}")

        except redis.RedisError as e:
            logger.error(f"Failed to connect to Redis: {e}")
            # Initialize without client - graceful degradation
            self.client = None

    def _generate_key(self, analysis_type: str, parameters: Dict[str, Any]) -> str:
        """
        Generate deterministic cache key from analysis parameters

        Args:
            analysis_type: e.g., "meta_analysis", "nma", "he_model"
            parameters: Analysis configuration

        Returns:
            SHA256 hash as cache key
        """
        param_str = json.dumps(parameters, sort_keys=True, default=str)
        key_input = f"{analysis_type}:{param_str}"
        hash_value = hashlib.sha256(key_input.encode()).hexdigest()
        return f"evidenceos:cache:{analysis_type}:{hash_value}"

    @retry_on_redis_error(max_retries=2)
    def get(self, analysis_type: str, parameters: Dict[str, Any]) -> Optional[Dict]:
        """
        Retrieve cached value

        Args:
            analysis_type: Type of analysis
            parameters: Analysis parameters

        Returns:
            Cached dictionary or None if not found/error
        """
        if not self.client or not settings.ENABLE_CACHE:
            return None

        try:
            key = self._generate_key(analysis_type, parameters)
            data = self.client.get(key)

            if data:
                logger.info(f"Cache hit: {analysis_type}", extra={
                    "analysis_type": analysis_type,
                    "cache_key": key[:32]
                })
                return json.loads(data)
            else:
                logger.debug(f"Cache miss: {analysis_type}", extra={
                    "analysis_type": analysis_type
                })
                return None

        except (redis.RedisError, json.JSONDecodeError) as e:
            logger.warning(f"Cache get failed: {e}", extra={
                "analysis_type": analysis_type,
                "error": str(e)
            })
            return None

    @retry_on_redis_error(max_retries=2)
    def set(
        self,
        analysis_type: str,
        parameters: Dict[str, Any],
        value: Dict[str, Any],
        ttl: Optional[int] = None
    ) -> bool:
        """
        Set cached value with TTL

        Args:
            analysis_type: Type of analysis
            parameters: Analysis parameters
            value: Value to cache (must be JSON serializable)
            ttl: Time to live in seconds (defaults to settings.CACHE_TTL)

        Returns:
            True if successful, False otherwise
        """
        if not self.client or not settings.ENABLE_CACHE:
            return False

        try:
            key = self._generate_key(analysis_type, parameters)
            ttl = ttl or settings.CACHE_TTL

            serialized = json.dumps(value, default=str)
            self.client.setex(key, ttl, serialized)

            logger.info(f"Cache set: {analysis_type}", extra={
                "analysis_type": analysis_type,
                "cache_key": key[:32],
                "ttl": ttl
            })

            return True

        except (redis.RedisError, TypeError, ValueError) as e:
            logger.warning(f"Cache set failed: {e}", extra={
                "analysis_type": analysis_type,
                "error": str(e)
            })
            return False

    @retry_on_redis_error(max_retries=2)
    def invalidate(self, analysis_type: str, parameters: Dict[str, Any]) -> bool:
        """
        Invalidate (delete) cached value

        Args:
            analysis_type: Type of analysis
            parameters: Analysis parameters

        Returns:
            True if key was deleted, False otherwise
        """
        if not self.client:
            return False

        try:
            key = self._generate_key(analysis_type, parameters)
            deleted = self.client.delete(key)

            logger.info(f"Cache invalidated: {analysis_type}", extra={
                "analysis_type": analysis_type,
                "cache_key": key[:32],
                "deleted": bool(deleted)
            })

            return bool(deleted)

        except redis.RedisError as e:
            logger.warning(f"Cache invalidate failed: {e}")
            return False

    @retry_on_redis_error(max_retries=2)
    def invalidate_pattern(self, pattern: str) -> int:
        """
        Invalidate all keys matching pattern

        Args:
            pattern: Redis key pattern (e.g., "evidenceos:cache:meta_analysis:*")

        Returns:
            Number of keys deleted
        """
        if not self.client:
            return 0

        try:
            count = 0
            for key in self.client.scan_iter(match=pattern, count=100):
                self.client.delete(key)
                count += 1

            logger.info(f"Cache pattern invalidated: {pattern}", extra={
                "pattern": pattern,
                "count": count
            })

            return count

        except redis.RedisError as e:
            logger.warning(f"Cache pattern invalidate failed: {e}")
            return 0

    def get_stats(self) -> Dict[str, Any]:
        """
        Get cache statistics

        Returns:
            Dictionary with cache stats or error info
        """
        if not self.client:
            return {"status": "disconnected"}

        try:
            info = self.client.info("stats")
            memory = self.client.info("memory")

            return {
                "status": "connected",
                "total_keys": self.client.dbsize(),
                "hits": info.get("keyspace_hits", 0),
                "misses": info.get("keyspace_misses", 0),
                "hit_rate": self._calculate_hit_rate(
                    info.get("keyspace_hits", 0),
                    info.get("keyspace_misses", 0)
                ),
                "memory_used_mb": memory.get("used_memory", 0) / (1024 * 1024),
                "memory_peak_mb": memory.get("used_memory_peak", 0) / (1024 * 1024)
            }

        except redis.RedisError as e:
            logger.error(f"Failed to get cache stats: {e}")
            return {"status": "error", "error": str(e)}

    @staticmethod
    def _calculate_hit_rate(hits: int, misses: int) -> float:
        """Calculate cache hit rate percentage"""
        total = hits + misses
        if total == 0:
            return 0.0
        return round((hits / total) * 100, 2)

    def health_check(self) -> bool:
        """
        Check if Redis connection is healthy

        Returns:
            True if healthy, False otherwise
        """
        if not self.client:
            return False

        try:
            return self.client.ping()
        except redis.RedisError:
            return False

    def close(self):
        """Close Redis connection"""
        if self.client:
            self.client.close()
            logger.info("Redis cache connection closed")


# Global cache instance
_cache_instance = None


def get_cache() -> RedisCache:
    """Get or create global cache instance"""
    global _cache_instance
    if _cache_instance is None:
        _cache_instance = RedisCache()
    return _cache_instance
