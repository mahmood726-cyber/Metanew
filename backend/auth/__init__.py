"""
Authentication and Authorization Module
"""
from .auth_manager import (
    auth_manager,
    User,
    UserCreate,
    UserRole,
    Permission,
    Token,
)
from .dependencies import (
    get_current_user,
    get_current_active_user,
    get_optional_user,
    RoleChecker,
    PermissionChecker,
    require_admin,
    require_analyst_or_admin,
    require_any_authenticated,
)

__all__ = [
    "auth_manager",
    "User",
    "UserCreate",
    "UserRole",
    "Permission",
    "Token",
    "get_current_user",
    "get_current_active_user",
    "get_optional_user",
    "RoleChecker",
    "PermissionChecker",
    "require_admin",
    "require_analyst_or_admin",
    "require_any_authenticated",
]
