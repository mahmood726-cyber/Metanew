"""
Input Sanitization Utilities
Prevents XSS, SQL injection, and other injection attacks
"""
import bleach
import re
from typing import Any, Dict, List, Union
from backend.utils.logging_config import get_logger

logger = get_logger(__name__)

# Allowed HTML tags (none for API - we're strict!)
ALLOWED_TAGS = []
ALLOWED_ATTRIBUTES = {}

# Maximum string lengths
MAX_STRING_LENGTH = 10000
MAX_STUDY_ID_LENGTH = 100
MAX_TREATMENT_NAME_LENGTH = 200


def sanitize_string(value: str, max_length: int = MAX_STRING_LENGTH) -> str:
    """
    Sanitize a string value

    - Removes HTML/script tags
    - Limits length
    - Removes control characters

    Args:
        value: String to sanitize
        max_length: Maximum allowed length

    Returns:
        Sanitized string
    """
    if not isinstance(value, str):
        return str(value)

    # Remove HTML tags
    cleaned = bleach.clean(
        value,
        tags=ALLOWED_TAGS,
        attributes=ALLOWED_ATTRIBUTES,
        strip=True
    )

    # Remove control characters (except newline, tab, carriage return)
    cleaned = re.sub(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]', '', cleaned)

    # Limit length
    if len(cleaned) > max_length:
        logger.warning(f"String truncated from {len(cleaned)} to {max_length} characters")
        cleaned = cleaned[:max_length]

    return cleaned.strip()


def sanitize_study_id(study_id: str) -> str:
    """
    Sanitize study ID

    Allows: alphanumeric, underscore, hyphen, period
    """
    if not isinstance(study_id, str):
        study_id = str(study_id)

    # Remove unwanted characters
    cleaned = re.sub(r'[^a-zA-Z0-9_\-.]', '', study_id)

    # Limit length
    if len(cleaned) > MAX_STUDY_ID_LENGTH:
        cleaned = cleaned[:MAX_STUDY_ID_LENGTH]

    return cleaned


def sanitize_treatment_name(treatment: str) -> str:
    """
    Sanitize treatment name

    Allows: alphanumeric, spaces, hyphen, parentheses, common units
    """
    if not isinstance(treatment, str):
        treatment = str(treatment)

    # Allow alphanumeric, spaces, and common punctuation
    cleaned = re.sub(r'[^a-zA-Z0-9\s\-()\/.,]', '', treatment)

    # Limit length
    if len(cleaned) > MAX_TREATMENT_NAME_LENGTH:
        cleaned = cleaned[:MAX_TREATMENT_NAME_LENGTH]

    return cleaned.strip()


def sanitize_numeric(value: Any, allow_negative: bool = True, allow_float: bool = True) -> Union[int, float, None]:
    """
    Sanitize and validate numeric value

    Args:
        value: Value to sanitize
        allow_negative: Whether to allow negative numbers
        allow_float: Whether to allow floating point numbers

    Returns:
        Sanitized number or None if invalid
    """
    try:
        if allow_float:
            num = float(value)
        else:
            num = int(value)

        # Check for NaN, Inf
        if not isinstance(num, (int, float)) or (isinstance(num, float) and (num != num or abs(num) == float('inf'))):
            logger.warning(f"Invalid numeric value: {value}")
            return None

        # Check negative
        if not allow_negative and num < 0:
            logger.warning(f"Negative value not allowed: {num}")
            return None

        return num

    except (ValueError, TypeError):
        logger.warning(f"Could not convert to number: {value}")
        return None


def sanitize_dict(data: Dict[str, Any], sanitize_keys: bool = False) -> Dict[str, Any]:
    """
    Recursively sanitize dictionary values

    Args:
        data: Dictionary to sanitize
        sanitize_keys: Whether to sanitize dictionary keys

    Returns:
        Sanitized dictionary
    """
    if not isinstance(data, dict):
        return {}

    sanitized = {}

    for key, value in data.items():
        # Sanitize key if requested
        clean_key = sanitize_string(str(key), max_length=100) if sanitize_keys else key

        # Sanitize value based on type
        if isinstance(value, str):
            sanitized[clean_key] = sanitize_string(value)
        elif isinstance(value, dict):
            sanitized[clean_key] = sanitize_dict(value, sanitize_keys)
        elif isinstance(value, list):
            sanitized[clean_key] = sanitize_list(value)
        elif isinstance(value, (int, float)):
            sanitized[clean_key] = sanitize_numeric(value)
        else:
            # Pass through other types (bool, None, etc.)
            sanitized[clean_key] = value

    return sanitized


def sanitize_list(data: List[Any]) -> List[Any]:
    """
    Recursively sanitize list values

    Args:
        data: List to sanitize

    Returns:
        Sanitized list
    """
    if not isinstance(data, list):
        return []

    sanitized = []

    for item in data:
        if isinstance(item, str):
            sanitized.append(sanitize_string(item))
        elif isinstance(item, dict):
            sanitized.append(sanitize_dict(item))
        elif isinstance(item, list):
            sanitized.append(sanitize_list(item))
        elif isinstance(item, (int, float)):
            sanitized.append(sanitize_numeric(item))
        else:
            sanitized.append(item)

    return sanitized


def validate_email(email: str) -> bool:
    """
    Validate email format

    Args:
        email: Email address to validate

    Returns:
        True if valid email format
    """
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_url(url: str, allow_http: bool = False) -> bool:
    """
    Validate URL format

    Args:
        url: URL to validate
        allow_http: Whether to allow HTTP (vs HTTPS only)

    Returns:
        True if valid URL format
    """
    if allow_http:
        pattern = r'^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    else:
        pattern = r'^https://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

    return bool(re.match(pattern, url))


class InputSanitizer:
    """
    Context manager for input sanitization

    Example:
        with InputSanitizer() as sanitizer:
            clean_data = sanitizer.sanitize_dict(user_input)
    """

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        pass

    @staticmethod
    def sanitize_dict(data: Dict[str, Any]) -> Dict[str, Any]:
        return sanitize_dict(data)

    @staticmethod
    def sanitize_string(value: str) -> str:
        return sanitize_string(value)

    @staticmethod
    def sanitize_numeric(value: Any) -> Union[int, float, None]:
        return sanitize_numeric(value)
