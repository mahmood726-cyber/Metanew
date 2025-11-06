"""
Authentication API Endpoints
Routes for login, token refresh, user management, etc.

Enhanced with:
- JWT refresh tokens with rotation
- Token blacklisting for logout
- Comprehensive rate limiting
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr
from typing import List
import logging
from slowapi import Limiter
from slowapi.util import get_remote_address

from auth.auth_manager import (
    auth_manager,
    User,
    UserCreate,
    Token,
    UserRole,
)
from auth.dependencies import (
    get_current_user,
    get_current_active_user,
    RoleChecker,
)

# Configure logging
logger = logging.getLogger(__name__)

# Rate limiting for auth endpoints
limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/auth", tags=["authentication"])


class LoginRequest(BaseModel):
    """Login request model"""
    username: str
    password: str


class LoginResponse(BaseModel):
    """Login response model"""
    user: User
    token: Token


class ChangePasswordRequest(BaseModel):
    """Change password request model"""
    old_password: str
    new_password: str


class ResetPasswordResponse(BaseModel):
    """Reset password response model"""
    username: str
    temporary_password: str


@router.post("/login", response_model=LoginResponse)
@limiter.limit("5/minute")  # Strict rate limit for login - brute force protection
async def login(request: Request, credentials: LoginRequest):
    """
    Authenticate user and return access token
    Rate limited to 5 attempts per minute to prevent brute force attacks

    Default users:
    - Username: admin, Password: from ADMIN_INITIAL_PASSWORD env var
    - Username: analyst, Password: from ANALYST_INITIAL_PASSWORD env var
    """
    # Authenticate user
    user = auth_manager.authenticate_user(credentials.username, credentials.password)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Generate tokens
    tokens = auth_manager.generate_tokens(user)

    # Convert user to response model (without password hash)
    user_response = User(**user.dict())

    return LoginResponse(user=user_response, token=tokens)


@router.post("/login/oauth", response_model=Token)
@limiter.limit("5/minute")  # Strict rate limit for OAuth login - brute force protection
async def login_oauth(request: Request, form_data: OAuth2PasswordRequestForm = Depends()):
    """
    OAuth2 compatible token endpoint
    Used by some client libraries that expect OAuth2 format
    Rate limited to 5 attempts per minute to prevent brute force attacks
    """
    user = auth_manager.authenticate_user(form_data.username, form_data.password)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    tokens = auth_manager.generate_tokens(user)
    return tokens


@router.post("/refresh", response_model=Token)
@limiter.limit("10/minute")  # Rate limit for token refresh
async def refresh_token(request: Request, refresh_token: str):
    """
    Refresh access token using refresh token

    Enhanced with:
    - Token rotation (new refresh token after 24 hours)
    - Automatic cleanup of rotated tokens
    - Blacklist verification

    Rate limited to 10 attempts per minute
    """
    # Try enhanced token manager first
    try:
        from auth.token_manager import token_manager

        try:
            new_tokens = token_manager.refresh_access_token(refresh_token)

            # Convert to Token response model
            return Token(
                access_token=new_tokens["access_token"],
                token_type=new_tokens["token_type"],
                refresh_token=new_tokens.get("refresh_token")  # May include new refresh token
            )
        except Exception as e:
            logger.warning(f"Enhanced token refresh failed: {e}, falling back to auth_manager")
            # Fall back to original auth_manager
            new_tokens = auth_manager.refresh_access_token(refresh_token)
    except ImportError:
        # Fall back to original auth_manager if token_manager not available
        new_tokens = auth_manager.refresh_access_token(refresh_token)

    if not new_tokens:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return new_tokens


@router.get("/me", response_model=User)
async def get_current_user_info(
    current_user: User = Depends(get_current_active_user)
):
    """
    Get current authenticated user information
    """
    return current_user


@router.post("/change-password")
@limiter.limit("10/minute")  # Rate limit for password changes
async def change_password(
    request: Request,
    password_data: ChangePasswordRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Change current user's password
    Rate limited to 10 attempts per minute
    """
    success = auth_manager.change_password(
        current_user.username,
        password_data.old_password,
        password_data.new_password
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid old password"
        )

    return {"message": "Password changed successfully"}


@router.post("/logout")
async def logout(
    request: Request,
    current_user: User = Depends(get_current_active_user)
):
    """
    Logout current user

    Enhanced with:
    - Token blacklisting (prevents replay attacks)
    - Revokes both access and refresh tokens
    - Client should discard tokens after this call

    Security: Blacklisted tokens cannot be used even if not expired
    """
    # Try to blacklist tokens using enhanced token manager
    try:
        from auth.token_manager import token_manager

        # Extract token from Authorization header
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            access_token = auth_header[7:]  # Remove "Bearer " prefix

            # Blacklist the access token
            token_manager.blacklist_token(access_token)

            logger.info(f"✓ User {current_user.username} logged out - token blacklisted")

            return {
                "message": "Logged out successfully",
                "detail": "Tokens have been revoked and blacklisted"
            }
    except ImportError:
        logger.warning("Enhanced token manager not available, logout without blacklisting")
    except Exception as e:
        logger.error(f"Token blacklisting failed: {e}")

    # Fallback response
    return {
        "message": "Logged out successfully",
        "detail": "Please discard your tokens"
    }


# Admin-only endpoints

@router.post(
    "/users",
    response_model=User,
    dependencies=[Depends(RoleChecker([UserRole.ADMIN]))]
)
async def create_user(user_data: UserCreate):
    """
    Create a new user (Admin only)
    """
    try:
        user = auth_manager.create_user(user_data)
        return user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get(
    "/users",
    response_model=List[User],
    dependencies=[Depends(RoleChecker([UserRole.ADMIN]))]
)
async def list_users():
    """
    List all users (Admin only)
    """
    users = auth_manager.list_users()
    return users


@router.get(
    "/users/{username}",
    response_model=User,
    dependencies=[Depends(RoleChecker([UserRole.ADMIN]))]
)
async def get_user(username: str):
    """
    Get user by username (Admin only)
    """
    user = auth_manager.get_user(username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User '{username}' not found"
        )
    return user


@router.post(
    "/users/{username}/reset-password",
    response_model=ResetPasswordResponse,
    dependencies=[Depends(RoleChecker([UserRole.ADMIN]))]
)
async def reset_user_password(username: str):
    """
    Reset user password (Admin only)
    Returns temporary password that user should change
    """
    temp_password = auth_manager.reset_password(username)

    if not temp_password:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User '{username}' not found"
        )

    return ResetPasswordResponse(
        username=username,
        temporary_password=temp_password
    )


@router.post(
    "/users/{username}/deactivate",
    dependencies=[Depends(RoleChecker([UserRole.ADMIN]))]
)
async def deactivate_user(username: str):
    """
    Deactivate user account (Admin only)
    """
    success = auth_manager.deactivate_user(username)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User '{username}' not found"
        )

    return {"message": f"User '{username}' deactivated"}


@router.post(
    "/users/{username}/activate",
    dependencies=[Depends(RoleChecker([UserRole.ADMIN]))]
)
async def activate_user(username: str):
    """
    Activate user account (Admin only)
    """
    success = auth_manager.activate_user(username)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User '{username}' not found"
        )

    return {"message": f"User '{username}' activated"}


@router.get("/roles")
async def list_roles():
    """
    List available user roles and their permissions
    """
    from auth.auth_manager import ROLE_PERMISSIONS

    return {
        "roles": [
            {
                "name": role,
                "permissions": perms
            }
            for role, perms in ROLE_PERMISSIONS.items()
        ]
    }
