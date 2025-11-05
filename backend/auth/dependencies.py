"""
FastAPI Authentication Dependencies
Dependencies for protecting routes with authentication and authorization
"""
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .auth_manager import (
    auth_manager,
    TokenManager,
    User,
    UserRole,
    Permission
)

# Security scheme for JWT bearer tokens
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """
    Dependency to get current authenticated user from JWT token
    Raises 401 if token is invalid or user not found
    """
    token = credentials.credentials

    # Decode token
    payload = TokenManager.decode_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check token type
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Get username from token
    username: str = payload.get("sub")
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Get user from database
    user = auth_manager.get_user(username)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check if user is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )

    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Dependency to get current active user
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user"
        )
    return current_user


class RoleChecker:
    """
    Dependency class to check if user has required role
    Usage:
        @app.get("/admin", dependencies=[Depends(RoleChecker([UserRole.ADMIN]))])
    """

    def __init__(self, allowed_roles: list[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, user: User = Depends(get_current_user)) -> User:
        if user.role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"User role '{user.role}' not authorized. Required roles: {self.allowed_roles}"
            )
        return user


class PermissionChecker:
    """
    Dependency class to check if user has required permission
    Usage:
        @app.get("/data", dependencies=[Depends(PermissionChecker(Permission.READ_DATA))])
    """

    def __init__(self, required_permission: str):
        self.required_permission = required_permission

    def __call__(self, user: User = Depends(get_current_user)) -> User:
        if not auth_manager.verify_permission(user, self.required_permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission denied. Required permission: {self.required_permission}"
            )
        return user


# Convenience dependencies for common role checks
require_admin = Depends(RoleChecker([UserRole.ADMIN]))
require_analyst_or_admin = Depends(RoleChecker([UserRole.ANALYST, UserRole.ADMIN]))
require_any_authenticated = Depends(get_current_active_user)


# Convenience dependencies for common permission checks
require_read_data = Depends(PermissionChecker(Permission.READ_DATA))
require_write_data = Depends(PermissionChecker(Permission.WRITE_DATA))
require_run_analysis = Depends(PermissionChecker(Permission.RUN_ANALYSIS))
require_manage_users = Depends(PermissionChecker(Permission.MANAGE_USERS))


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    )
) -> Optional[User]:
    """
    Dependency to optionally get current user
    Returns None if no valid token provided
    Useful for endpoints that have different behavior for authenticated vs anonymous users
    """
    if not credentials:
        return None

    try:
        token = credentials.credentials
        payload = TokenManager.decode_token(token)

        if not payload or payload.get("type") != "access":
            return None

        username = payload.get("sub")
        if not username:
            return None

        user = auth_manager.get_user(username)
        return user if user and user.is_active else None

    except Exception:
        return None
