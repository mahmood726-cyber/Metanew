"""
Structured Logging Configuration for EvidenceOS PRIME
JSON logging with correlation IDs and contextual information
"""
import logging
import sys
from typing import Optional
from pythonjsonlogger import jsonlogger
from contextvars import ContextVar


# Context variable for correlation ID
correlation_id_var: ContextVar[Optional[str]] = ContextVar('correlation_id', default=None)
user_id_var: ContextVar[Optional[str]] = ContextVar('user_id', default=None)


class CustomJsonFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter with correlation ID and user context"""

    def add_fields(self, log_record, record, message_dict):
        super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)

        # Add correlation ID if available
        correlation_id = correlation_id_var.get()
        if correlation_id:
            log_record['correlation_id'] = correlation_id

        # Add user ID if available
        user_id = user_id_var.get()
        if user_id:
            log_record['user_id'] = user_id

        # Add standard fields
        log_record['level'] = record.levelname
        log_record['logger'] = record.name

        # Add location info for errors
        if record.levelno >= logging.ERROR:
            log_record['file'] = record.pathname
            log_record['line'] = record.lineno
            log_record['function'] = record.funcName


def setup_logging(app_name: str = "evidenceos", level: str = "INFO", format_type: str = "json"):
    """
    Configure structured logging

    Args:
        app_name: Application name for logging context
        level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        format_type: Output format - "json" or "text"

    Returns:
        Configured logger instance
    """
    logger = logging.getLogger()

    # Remove existing handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)

    logger.setLevel(getattr(logging, level.upper()))

    # Create console handler
    handler = logging.StreamHandler(sys.stdout)

    if format_type == "json":
        # JSON formatter for production
        formatter = CustomJsonFormatter(
            '%(asctime)s %(name)s %(levelname)s %(message)s',
            rename_fields={
                "asctime": "timestamp",
                "levelname": "level",
                "name": "logger"
            }
        )
    else:
        # Text formatter for development
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(correlation_id)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )

    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # Silence noisy libraries
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)

    logger.info(f"{app_name} logging initialized", extra={
        "app_name": app_name,
        "log_level": level,
        "format": format_type
    })

    return logger


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance with the given name"""
    return logging.getLogger(name)


def set_correlation_id(correlation_id: str):
    """Set correlation ID for current context"""
    correlation_id_var.set(correlation_id)


def get_correlation_id() -> Optional[str]:
    """Get correlation ID from current context"""
    return correlation_id_var.get()


def set_user_id(user_id: str):
    """Set user ID for current context"""
    user_id_var.set(user_id)


def get_user_id() -> Optional[str]:
    """Get user ID from current context"""
    return user_id_var.get()
