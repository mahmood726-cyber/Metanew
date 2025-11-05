"""
Authentication API Endpoints
Routes for login, token refresh, user management, etc.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr
from typing import List

from backend.auth.auth_manager import (
    auth_manager,
    User,
    UserCreate,
    Token,
    UserRole,
)
from backend.auth.dependencies import (
    get_current_user,
    get_current_active_user,
    RoleChecker,
)

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
async def login(request: LoginRequest):
    """
    Authenticate user and return access token

    Default users:
    - Username: admin, Password: admin123 (Role: Admin)
    - Username: analyst, Password: analyst123 (Role: Analyst)
    """
    # Authenticate user
    user = auth_manager.authenticate_user(request.username, request.password)

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
async def login_oauth(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    OAuth2 compatible token endpoint
    Used by some client libraries that expect OAuth2 format
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
async def refresh_token(refresh_token: str):
    """
    Refresh access token using refresh token
    """
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
async def change_password(
    request: ChangePasswordRequest,
    current_user: User = Depends(get_current_active_user)
):
    """
    Change current user's password
    """
    success = auth_manager.change_password(
        current_user.username,
        request.old_password,
        request.new_password
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid old password"
        )

    return {"message": "Password changed successfully"}


@router.post("/logout")
async def logout(current_user: User = Depends(get_current_active_user)):
    """
    Logout current user
    (Client should discard tokens)
    """
    return {"message": "Logged out successfully"}


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
    from backend.auth.auth_manager import ROLE_PERMISSIONS

    return {
        "roles": [
            {
                "name": role,
                "permissions": perms
            }
            for role, perms in ROLE_PERMISSIONS.items()
        ]
    }
