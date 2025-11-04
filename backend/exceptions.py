"""
Custom Exception Hierarchy for EvidenceOS PRIME
Provides specific, structured error handling
"""
from typing import Optional, Dict, Any


class EvidenceOSError(Exception):
    """Base exception for all EvidenceOS errors"""

    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        self.message = message
        self.details = details or {}
        super().__init__(self.message)


class ValidationError(EvidenceOSError):
    """Data validation failed"""

    def __init__(
        self,
        field: str,
        message: str,
        study_id: Optional[str] = None,
        value: Optional[Any] = None
    ):
        self.field = field
        self.study_id = study_id
        self.value = value
        details = {
            "field": field,
            "study_id": study_id,
            "value": value
        }
        super().__init__(message, details)


class ComputationError(EvidenceOSError):
    """Statistical computation failed"""

    def __init__(self, operation: str, message: str, data_info: Optional[Dict] = None):
        self.operation = operation
        self.data_info = data_info or {}
        details = {
            "operation": operation,
            **self.data_info
        }
        super().__init__(message, details)


class DataNotFoundError(EvidenceOSError):
    """Required data not found"""

    def __init__(self, resource: str, identifier: Optional[str] = None):
        self.resource = resource
        self.identifier = identifier
        message = f"{resource} not found"
        if identifier:
            message += f": {identifier}"
        details = {"resource": resource, "identifier": identifier}
        super().__init__(message, details)


class ConfigurationError(EvidenceOSError):
    """Configuration or setup error"""

    def __init__(self, setting: str, message: str):
        self.setting = setting
        details = {"setting": setting}
        super().__init__(message, details)


class AuthenticationError(EvidenceOSError):
    """Authentication failed"""

    def __init__(self, message: str = "Authentication required"):
        super().__init__(message)


class AuthorizationError(EvidenceOSError):
    """Authorization/permission denied"""

    def __init__(self, message: str = "Insufficient permissions"):
        super().__init__(message)


class RateLimitError(EvidenceOSError):
    """Rate limit exceeded"""

    def __init__(self, limit: int, window: str = "minute"):
        message = f"Rate limit exceeded: {limit} requests per {window}"
        details = {"limit": limit, "window": window}
        super().__init__(message, details)


class ResourceExhaustedError(EvidenceOSError):
    """Resource limits exceeded"""

    def __init__(self, resource: str, limit: int, current: int):
        message = f"{resource} limit exceeded: {current}/{limit}"
        details = {"resource": resource, "limit": limit, "current": current}
        super().__init__(message, details)


class CacheError(EvidenceOSError):
    """Cache operation failed"""

    def __init__(self, operation: str, message: str):
        self.operation = operation
        details = {"operation": operation}
        super().__init__(message, details)


class ExternalServiceError(EvidenceOSError):
    """External service call failed"""

    def __init__(self, service: str, message: str, status_code: Optional[int] = None):
        self.service = service
        self.status_code = status_code
        details = {"service": service, "status_code": status_code}
        super().__init__(message, details)
