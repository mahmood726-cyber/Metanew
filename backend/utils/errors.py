"""
Custom exception classes and error handling utilities for EvidenceOS PRIME
Provides consistent error handling across the application
"""
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
from fastapi.responses import JSONResponse


class EvidenceOSError(Exception):
    """Base exception class for all EvidenceOS errors"""

    def __init__(
        self,
        message: str,
        error_code: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None
    ):
        self.message = message
        self.error_code = error_code or self.__class__.__name__
        self.details = details or {}
        super().__init__(self.message)

    def to_dict(self) -> Dict[str, Any]:
        """Convert error to dictionary"""
        return {
            'error': self.error_code,
            'message': self.message,
            'details': self.details
        }


# Data-related errors

class DataValidationError(EvidenceOSError):
    """Raised when data validation fails"""

    def __init__(
        self,
        message: str,
        field: Optional[str] = None,
        value: Optional[Any] = None,
        details: Optional[Dict[str, Any]] = None
    ):
        if field:
            details = details or {}
            details['field'] = field
            if value is not None:
                details['value'] = str(value)

        super().__init__(
            message=message,
            error_code="DATA_VALIDATION_ERROR",
            details=details
        )


class DataIngestionError(EvidenceOSError):
    """Raised when data ingestion fails"""

    def __init__(self, message: str, file_path: Optional[str] = None):
        details = {}
        if file_path:
            details['file_path'] = file_path

        super().__init__(
            message=message,
            error_code="DATA_INGESTION_ERROR",
            details=details
        )


class DataTransformationError(EvidenceOSError):
    """Raised when data transformation fails"""

    def __init__(self, message: str, operation: Optional[str] = None):
        details = {}
        if operation:
            details['operation'] = operation

        super().__init__(
            message=message,
            error_code="DATA_TRANSFORMATION_ERROR",
            details=details
        )


# Analysis errors

class AnalysisError(EvidenceOSError):
    """Base class for analysis-related errors"""
    pass


class MetaAnalysisError(AnalysisError):
    """Raised when meta-analysis fails"""

    def __init__(
        self,
        message: str,
        n_studies: Optional[int] = None,
        model_type: Optional[str] = None
    ):
        details = {}
        if n_studies is not None:
            details['n_studies'] = n_studies
        if model_type:
            details['model_type'] = model_type

        super().__init__(
            message=message,
            error_code="META_ANALYSIS_ERROR",
            details=details
        )


class InsufficientDataError(AnalysisError):
    """Raised when insufficient data for analysis"""

    def __init__(
        self,
        message: str,
        required: Optional[int] = None,
        provided: Optional[int] = None
    ):
        details = {}
        if required is not None:
            details['required'] = required
        if provided is not None:
            details['provided'] = provided

        super().__init__(
            message=message,
            error_code="INSUFFICIENT_DATA_ERROR",
            details=details
        )


class HealthEconomicsError(AnalysisError):
    """Raised when health economics calculation fails"""

    def __init__(self, message: str, calculation: Optional[str] = None):
        details = {}
        if calculation:
            details['calculation'] = calculation

        super().__init__(
            message=message,
            error_code="HEALTH_ECONOMICS_ERROR",
            details=details
        )


# Cache errors

class CacheError(EvidenceOSError):
    """Base class for cache-related errors"""
    pass


class CacheReadError(CacheError):
    """Raised when cache read fails"""

    def __init__(self, message: str, cache_key: Optional[str] = None):
        details = {}
        if cache_key:
            details['cache_key'] = cache_key

        super().__init__(
            message=message,
            error_code="CACHE_READ_ERROR",
            details=details
        )


class CacheWriteError(CacheError):
    """Raised when cache write fails"""

    def __init__(self, message: str, cache_key: Optional[str] = None):
        details = {}
        if cache_key:
            details['cache_key'] = cache_key

        super().__init__(
            message=message,
            error_code="CACHE_WRITE_ERROR",
            details=details
        )


# Configuration errors

class ConfigurationError(EvidenceOSError):
    """Raised when configuration is invalid"""

    def __init__(self, message: str, config_key: Optional[str] = None):
        details = {}
        if config_key:
            details['config_key'] = config_key

        super().__init__(
            message=message,
            error_code="CONFIGURATION_ERROR",
            details=details
        )


# API errors

class APIError(EvidenceOSError):
    """Base class for API-related errors"""
    pass


class InvalidRequestError(APIError):
    """Raised when API request is invalid"""

    def __init__(self, message: str, parameter: Optional[str] = None):
        details = {}
        if parameter:
            details['parameter'] = parameter

        super().__init__(
            message=message,
            error_code="INVALID_REQUEST_ERROR",
            details=details
        )


class ResourceNotFoundError(APIError):
    """Raised when requested resource is not found"""

    def __init__(self, message: str, resource_type: Optional[str] = None):
        details = {}
        if resource_type:
            details['resource_type'] = resource_type

        super().__init__(
            message=message,
            error_code="RESOURCE_NOT_FOUND_ERROR",
            details=details
        )


class RateLimitError(APIError):
    """Raised when rate limit is exceeded"""

    def __init__(self, message: str = "Rate limit exceeded"):
        super().__init__(
            message=message,
            error_code="RATE_LIMIT_ERROR"
        )


# Error handlers for FastAPI

def create_error_response(
    error: EvidenceOSError,
    status_code: int = status.HTTP_400_BAD_REQUEST
) -> JSONResponse:
    """
    Create JSON error response

    Args:
        error: EvidenceOS error
        status_code: HTTP status code

    Returns:
        JSON response with error details
    """
    return JSONResponse(
        status_code=status_code,
        content=error.to_dict()
    )


def map_error_to_status_code(error: EvidenceOSError) -> int:
    """
    Map error type to HTTP status code

    Args:
        error: EvidenceOS error

    Returns:
        HTTP status code
    """
    error_status_map = {
        DataValidationError: status.HTTP_422_UNPROCESSABLE_ENTITY,
        DataIngestionError: status.HTTP_400_BAD_REQUEST,
        DataTransformationError: status.HTTP_500_INTERNAL_SERVER_ERROR,
        MetaAnalysisError: status.HTTP_500_INTERNAL_SERVER_ERROR,
        InsufficientDataError: status.HTTP_422_UNPROCESSABLE_ENTITY,
        HealthEconomicsError: status.HTTP_500_INTERNAL_SERVER_ERROR,
        CacheReadError: status.HTTP_500_INTERNAL_SERVER_ERROR,
        CacheWriteError: status.HTTP_500_INTERNAL_SERVER_ERROR,
        ConfigurationError: status.HTTP_500_INTERNAL_SERVER_ERROR,
        InvalidRequestError: status.HTTP_400_BAD_REQUEST,
        ResourceNotFoundError: status.HTTP_404_NOT_FOUND,
        RateLimitError: status.HTTP_429_TOO_MANY_REQUESTS,
    }

    return error_status_map.get(
        type(error),
        status.HTTP_500_INTERNAL_SERVER_ERROR
    )


def handle_error(error: Exception) -> JSONResponse:
    """
    Handle any exception and return appropriate response

    Args:
        error: Exception to handle

    Returns:
        JSON error response
    """
    if isinstance(error, EvidenceOSError):
        status_code = map_error_to_status_code(error)
        return create_error_response(error, status_code)

    # Handle standard HTTP exceptions
    if isinstance(error, HTTPException):
        return JSONResponse(
            status_code=error.status_code,
            content={
                'error': 'HTTP_ERROR',
                'message': error.detail,
                'details': {}
            }
        )

    # Handle unknown errors
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            'error': 'INTERNAL_SERVER_ERROR',
            'message': 'An unexpected error occurred',
            'details': {
                'error_type': type(error).__name__,
                'error_message': str(error)
            }
        }
    )


# Context manager for error handling

class ErrorContext:
    """
    Context manager for consistent error handling

    Usage:
        with ErrorContext("Processing data", logger=logger):
            # Your code here
            process_data()
    """

    def __init__(
        self,
        operation: str,
        logger=None,
        reraise: bool = True
    ):
        self.operation = operation
        self.logger = logger
        self.reraise = reraise

    def __enter__(self):
        if self.logger:
            self.logger.debug(f"Starting: {self.operation}")
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is not None:
            if self.logger:
                self.logger.error(
                    f"Error in {self.operation}: {exc_val}",
                    exc_info=True
                )

            if self.reraise:
                return False  # Re-raise exception

        if self.logger:
            self.logger.debug(f"Completed: {self.operation}")

        return False


# Utility functions

def validate_required_fields(data: dict, required_fields: list) -> None:
    """
    Validate that required fields are present

    Args:
        data: Data dictionary
        required_fields: List of required field names

    Raises:
        DataValidationError: If required fields are missing
    """
    missing_fields = [f for f in required_fields if f not in data]

    if missing_fields:
        raise DataValidationError(
            message=f"Missing required fields: {', '.join(missing_fields)}",
            details={'missing_fields': missing_fields}
        )


def validate_field_type(
    data: dict,
    field: str,
    expected_type: type
) -> None:
    """
    Validate field type

    Args:
        data: Data dictionary
        field: Field name
        expected_type: Expected type

    Raises:
        DataValidationError: If field type is invalid
    """
    if field in data and not isinstance(data[field], expected_type):
        raise DataValidationError(
            message=f"Invalid type for field '{field}'",
            field=field,
            details={
                'expected_type': expected_type.__name__,
                'actual_type': type(data[field]).__name__
            }
        )


def validate_numeric_range(
    value: float,
    field: str,
    min_value: Optional[float] = None,
    max_value: Optional[float] = None
) -> None:
    """
    Validate numeric value is within range

    Args:
        value: Value to validate
        field: Field name
        min_value: Minimum allowed value
        max_value: Maximum allowed value

    Raises:
        DataValidationError: If value is out of range
    """
    if min_value is not None and value < min_value:
        raise DataValidationError(
            message=f"{field} must be >= {min_value}",
            field=field,
            value=value
        )

    if max_value is not None and value > max_value:
        raise DataValidationError(
            message=f"{field} must be <= {max_value}",
            field=field,
            value=value
        )


# Export all error classes and utilities
__all__ = [
    # Base
    'EvidenceOSError',
    # Data errors
    'DataValidationError',
    'DataIngestionError',
    'DataTransformationError',
    # Analysis errors
    'AnalysisError',
    'MetaAnalysisError',
    'InsufficientDataError',
    'HealthEconomicsError',
    # Cache errors
    'CacheError',
    'CacheReadError',
    'CacheWriteError',
    # Config errors
    'ConfigurationError',
    # API errors
    'APIError',
    'InvalidRequestError',
    'ResourceNotFoundError',
    'RateLimitError',
    # Handlers
    'create_error_response',
    'map_error_to_status_code',
    'handle_error',
    'ErrorContext',
    # Validators
    'validate_required_fields',
    'validate_field_type',
    'validate_numeric_range',
]
