"""
EvidenceOS PRIME - Utilities Package
Provides logging, error handling, and common utilities
"""

from .logger import (
    setup_logger,
    get_logger,
    default_logger,
    LoggerMixin,
    log_function_call,
    log_execution_time,
    log_api_request,
    log_error,
    log_validation_error,
    log_cache_operation
)

from .errors import (
    EvidenceOSError,
    DataValidationError,
    DataIngestionError,
    DataTransformationError,
    AnalysisError,
    MetaAnalysisError,
    InsufficientDataError,
    HealthEconomicsError,
    CacheError,
    CacheReadError,
    CacheWriteError,
    ConfigurationError,
    APIError,
    InvalidRequestError,
    ResourceNotFoundError,
    RateLimitError,
    create_error_response,
    map_error_to_status_code,
    handle_error,
    ErrorContext,
    validate_required_fields,
    validate_field_type,
    validate_numeric_range
)

__all__ = [
    # Logger
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
    # Errors
    'EvidenceOSError',
    'DataValidationError',
    'DataIngestionError',
    'DataTransformationError',
    'AnalysisError',
    'MetaAnalysisError',
    'InsufficientDataError',
    'HealthEconomicsError',
    'CacheError',
    'CacheReadError',
    'CacheWriteError',
    'ConfigurationError',
    'APIError',
    'InvalidRequestError',
    'ResourceNotFoundError',
    'RateLimitError',
    'create_error_response',
    'map_error_to_status_code',
    'handle_error',
    'ErrorContext',
    'validate_required_fields',
    'validate_field_type',
    'validate_numeric_range',
]
