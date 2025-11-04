"""
Retry utilities with exponential backoff
For handling transient failures in external services
"""
import time
import functools
from typing import Callable, Type, Tuple, Optional
from backend.utils.logging_config import get_logger

logger = get_logger(__name__)


def retry_with_backoff(
    max_retries: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 60.0,
    exponential_base: float = 2.0,
    exceptions: Tuple[Type[Exception], ...] = (Exception,),
    logger_name: Optional[str] = None
):
    """
    Decorator for retrying functions with exponential backoff

    Args:
        max_retries: Maximum number of retry attempts
        base_delay: Initial delay in seconds
        max_delay: Maximum delay between retries
        exponential_base: Base for exponential backoff (2 = double each time)
        exceptions: Tuple of exceptions to catch and retry
        logger_name: Optional logger name for logging retries

    Example:
        @retry_with_backoff(max_retries=3, base_delay=1.0)
        def fetch_data():
            response = requests.get("https://api.example.com/data")
            response.raise_for_status()
            return response.json()
    """
    def decorator(func: Callable):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            delay = base_delay
            last_exception = None

            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)

                except exceptions as e:
                    last_exception = e

                    if attempt == max_retries:
                        logger.error(
                            f"Function {func.__name__} failed after {max_retries + 1} attempts",
                            extra={
                                "function": func.__name__,
                                "attempts": max_retries + 1,
                                "error": str(e)
                            }
                        )
                        raise

                    # Log retry attempt
                    logger.warning(
                        f"Function {func.__name__} failed (attempt {attempt + 1}/{max_retries + 1}), "
                        f"retrying in {delay:.1f}s",
                        extra={
                            "function": func.__name__,
                            "attempt": attempt + 1,
                            "max_attempts": max_retries + 1,
                            "delay": delay,
                            "error": str(e)
                        }
                    )

                    # Wait before retrying
                    time.sleep(min(delay, max_delay))

                    # Exponential backoff
                    delay *= exponential_base

            # This should never be reached, but just in case
            if last_exception:
                raise last_exception

        return wrapper
    return decorator


# Convenience decorators for common scenarios

def retry_on_network_error(max_retries: int = 3):
    """Retry on network-related errors"""
    import requests
    return retry_with_backoff(
        max_retries=max_retries,
        base_delay=2.0,
        exceptions=(
            requests.RequestException,
            ConnectionError,
            TimeoutError,
        )
    )


def retry_on_redis_error(max_retries: int = 2):
    """Retry on Redis connection errors"""
    import redis
    return retry_with_backoff(
        max_retries=max_retries,
        base_delay=0.5,
        max_delay=5.0,
        exceptions=(redis.RedisError, ConnectionError)
    )


def retry_on_db_error(max_retries: int = 2):
    """Retry on database errors"""
    return retry_with_backoff(
        max_retries=max_retries,
        base_delay=1.0,
        max_delay=10.0,
        exceptions=(ConnectionError, TimeoutError)
    )
