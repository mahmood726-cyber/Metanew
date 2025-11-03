"""
Centralized logging configuration for EvidenceOS PRIME
Provides structured logging with different levels and handlers
"""
import logging
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional
import json


class StructuredFormatter(logging.Formatter):
    """Custom formatter for structured JSON logging"""

    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON"""
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }

        # Add exception info if present
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)

        # Add extra fields
        if hasattr(record, 'user_id'):
            log_data['user_id'] = record.user_id
        if hasattr(record, 'request_id'):
            log_data['request_id'] = record.request_id

        return json.dumps(log_data)


class ColoredFormatter(logging.Formatter):
    """
    Colored formatter for console output
    Makes logs more readable in development
    """

    # ANSI color codes
    COLORS = {
        'DEBUG': '\033[36m',     # Cyan
        'INFO': '\033[32m',      # Green
        'WARNING': '\033[33m',   # Yellow
        'ERROR': '\033[31m',     # Red
        'CRITICAL': '\033[35m',  # Magenta
        'RESET': '\033[0m'       # Reset
    }

    def format(self, record: logging.LogRecord) -> str:
        """Format with colors"""
        color = self.COLORS.get(record.levelname, self.COLORS['RESET'])
        reset = self.COLORS['RESET']

        # Format timestamp
        timestamp = datetime.fromtimestamp(record.created).strftime('%Y-%m-%d %H:%M:%S')

        # Build log message
        log_message = (
            f"{color}{record.levelname:8s}{reset} "
            f"{timestamp} "
            f"[{record.name}:{record.funcName}:{record.lineno}] "
            f"{record.getMessage()}"
        )

        # Add exception if present
        if record.exc_info:
            log_message += f"\n{self.formatException(record.exc_info)}"

        return log_message


def setup_logger(
    name: str = "evidenceos",
    level: str = "INFO",
    log_to_file: bool = True,
    log_dir: Optional[str] = None,
    structured: bool = False
) -> logging.Logger:
    """
    Setup and configure logger

    Args:
        name: Logger name
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_to_file: Whether to log to file
        log_dir: Directory for log files (default: logs/)
        structured: Use structured JSON logging

    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper()))

    # Remove existing handlers to avoid duplicates
    logger.handlers.clear()

    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.DEBUG)

    if structured:
        console_formatter = StructuredFormatter()
    else:
        console_formatter = ColoredFormatter()

    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    # File handler
    if log_to_file:
        if log_dir is None:
            log_dir = Path(__file__).parent.parent.parent / "logs"
        else:
            log_dir = Path(log_dir)

        log_dir.mkdir(exist_ok=True)

        # Main log file
        log_file = log_dir / f"{name}.log"
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)

        if structured:
            file_formatter = StructuredFormatter()
        else:
            file_formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
            )

        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)

        # Error log file (ERROR and above only)
        error_log_file = log_dir / f"{name}_errors.log"
        error_handler = logging.FileHandler(error_log_file)
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(file_formatter)
        logger.addHandler(error_handler)

    return logger


def get_logger(name: str = "evidenceos") -> logging.Logger:
    """
    Get or create logger

    Args:
        name: Logger name

    Returns:
        Logger instance
    """
    return logging.getLogger(name)


# Create default logger
default_logger = setup_logger(
    name="evidenceos",
    level="INFO",
    log_to_file=True,
    structured=False
)


class LoggerMixin:
    """
    Mixin class to add logging capabilities to any class

    Usage:
        class MyClass(LoggerMixin):
            def my_method(self):
                self.logger.info("Doing something")
    """

    @property
    def logger(self) -> logging.Logger:
        """Get logger for this class"""
        name = f"evidenceos.{self.__class__.__name__}"
        return logging.getLogger(name)


# Utility functions for common logging patterns

def log_function_call(func):
    """
    Decorator to log function calls

    Usage:
        @log_function_call
        def my_function(arg1, arg2):
            pass
    """
    def wrapper(*args, **kwargs):
        logger = get_logger()
        logger.debug(f"Calling {func.__name__} with args={args}, kwargs={kwargs}")
        try:
            result = func(*args, **kwargs)
            logger.debug(f"{func.__name__} completed successfully")
            return result
        except Exception as e:
            logger.error(f"{func.__name__} failed with error: {str(e)}", exc_info=True)
            raise
    return wrapper


def log_execution_time(func):
    """
    Decorator to log execution time

    Usage:
        @log_execution_time
        def slow_function():
            time.sleep(2)
    """
    import time

    def wrapper(*args, **kwargs):
        logger = get_logger()
        start_time = time.time()
        logger.debug(f"Starting {func.__name__}")

        try:
            result = func(*args, **kwargs)
            execution_time = time.time() - start_time
            logger.info(f"{func.__name__} completed in {execution_time:.3f}s")
            return result
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(
                f"{func.__name__} failed after {execution_time:.3f}s: {str(e)}",
                exc_info=True
            )
            raise

    return wrapper


def log_api_request(method: str, path: str, status_code: int, duration: float):
    """
    Log API request

    Args:
        method: HTTP method
        path: Request path
        status_code: Response status code
        duration: Request duration in seconds
    """
    logger = get_logger("evidenceos.api")
    logger.info(
        f"{method} {path} - {status_code} - {duration:.3f}s"
    )


def log_error(error: Exception, context: Optional[dict] = None):
    """
    Log error with context

    Args:
        error: Exception to log
        context: Additional context information
    """
    logger = get_logger()
    message = f"Error occurred: {str(error)}"

    if context:
        message += f" | Context: {json.dumps(context)}"

    logger.error(message, exc_info=True)


def log_validation_error(field: str, value: any, expected: str):
    """
    Log validation error

    Args:
        field: Field name
        value: Invalid value
        expected: Expected format/type
    """
    logger = get_logger("evidenceos.validation")
    logger.warning(
        f"Validation failed for field '{field}': "
        f"got '{value}', expected {expected}"
    )


def log_cache_operation(operation: str, cache_key: str, success: bool):
    """
    Log cache operation

    Args:
        operation: Operation type (hit, miss, save, clear)
        cache_key: Cache key
        success: Whether operation succeeded
    """
    logger = get_logger("evidenceos.cache")
    status = "success" if success else "failure"
    logger.debug(f"Cache {operation} - {cache_key[:16]}... - {status}")


# Export commonly used functions
__all__ = [
    'setup_logger',
    'get_logger',
    'default_logger',
    'LoggerMixin',
    'log_function_call',
    'log_execution_time',
    'log_api_request',
    'log_error',
    'log_validation_error',
    'log_cache_operation',
    'StructuredFormatter',
    'ColoredFormatter'
]
