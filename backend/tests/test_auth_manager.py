"""
FIXED Tests for Authentication Manager
Comprehensive tests for auth, JWT, and RBAC with correct API usage
"""
import pytest
import os
from datetime import datetime, timedelta
from jose import jwt, JWTError

# Set test environment before imports
os.environ["ENVIRONMENT"] = "test"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-for-testing-only-do-not-use-in-production"
os.environ["ADMIN_INITIAL_PASSWORD"] = "test-admin-password"
os.environ["ANALYST_INITIAL_PASSWORD"] = "test-analyst-password"

from auth.auth_manager import (
    AuthenticationManager, PasswordManager, TokenManager,
    UserRole, UserInDB, UserCreate, Token, TokenData,
    SECRET_KEY, ALGORITHM
)


class TestPasswordManager:
    """Test password hashing and verification"""

    def setup_method(self):
        self.password_manager = PasswordManager()

    def test_password_hashing(self):
        """Test that password hashing works"""
        password = "my-secure-password-123"
        hashed = self.password_manager.hash_password(password)

        # Hashed password should be different from original
        assert hashed != password
        # Bcrypt hashes start with $2b$
        assert hashed.startswith("$2b$")

    def test_password_verification_correct(self):
        """Test password verification with correct password"""
        password = "test-password"
        hashed = self.password_manager.hash_password(password)

        assert self.password_manager.verify_password(password, hashed) is True

    def test_password_verification_incorrect(self):
        """Test password verification with wrong password"""
        password = "correct-password"
        hashed = self.password_manager.hash_password(password)

        assert self.password_manager.verify_password("wrong-password", hashed) is False

    def test_password_hashing_different_hashes(self):
        """Test that same password produces different hashes (salt)"""
        password = "same-password"
        hash1 = self.password_manager.hash_password(password)
        hash2 = self.password_manager.hash_password(password)

        # Different hashes due to random salt
        assert hash1 != hash2
        # But both should verify correctly
        assert self.password_manager.verify_password(password, hash1)
        assert self.password_manager.verify_password(password, hash2)

    def test_password_empty_string(self):
        """Test hashing empty string"""
        password = ""
        hashed = self.password_manager.hash_password(password)

        assert hashed is not None
        assert self.password_manager.verify_password("", hashed) is True

    def test_password_special_characters(self):
        """Test password with special characters"""
        password = "p@$$w0rd!#%&*()_+-=[]{}|;:',.<>?/~`"
        hashed = self.password_manager.hash_password(password)

        assert self.password_manager.verify_password(password, hashed) is True


class TestTokenManager:
    """Test JWT token generation and validation"""

    def test_create_access_token(self):
        """Test access token creation"""
        data = {"sub": "admin", "role": UserRole.ADMIN}
        token = TokenManager.create_access_token(data)

        # Token should be a string
        assert isinstance(token, str)
        # JWT tokens have 3 parts: header.payload.signature
        assert len(token.split(".")) == 3

    def test_create_access_token_with_custom_expiration(self):
        """Test token with custom expiration time"""
        data = {"sub": "admin"}
        custom_expiration = timedelta(minutes=60)

        token = TokenManager.create_access_token(data, expires_delta=custom_expiration)

        # Decode to check expiration
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        exp = datetime.fromtimestamp(payload["exp"])
        now = datetime.utcnow()

        # Should expire in approximately 60 minutes
        time_diff = (exp - now).total_seconds()
        assert 59 * 60 < time_diff < 61 * 60

    def test_verify_token_valid(self):
        """Test verification of valid token"""
        data = {"sub": "admin", "role": UserRole.ADMIN}
        token = TokenManager.create_access_token(data)

        # Verify the token
        assert TokenManager.verify_token(token) is True

    def test_decode_token_valid(self):
        """Test decoding valid token"""
        data = {"sub": "testuser", "role": UserRole.ANALYST}
        token = TokenManager.create_access_token(data)

        payload = TokenManager.decode_token(token)

        assert payload is not None
        assert payload["sub"] == "testuser"
        assert payload["role"] == UserRole.ANALYST

    def test_verify_token_expired(self):
        """Test that expired tokens are rejected"""
        data = {"sub": "admin"}
        # Create token that expired 1 second ago
        token = TokenManager.create_access_token(data, timedelta(seconds=-1))

        # Should be invalid
        assert TokenManager.verify_token(token) is False

    def test_verify_token_invalid_signature(self):
        """Test that tokens with invalid signatures are rejected"""
        data = {"sub": "admin"}
        token = TokenManager.create_access_token(data)

        # Modify the signature
        parts = token.split(".")
        parts[2] = "invalid_signature_here"
        invalid_token = ".".join(parts)

        assert TokenManager.verify_token(invalid_token) is False

    def test_verify_token_malformed(self):
        """Test that malformed tokens are rejected"""
        malformed_token = "not.a.valid.token"

        assert TokenManager.verify_token(malformed_token) is False

    def test_create_refresh_token(self):
        """Test refresh token creation"""
        data = {"sub": "admin"}
        token = TokenManager.create_refresh_token(data)

        assert isinstance(token, str)
        assert len(token.split(".")) == 3

        # Decode and check expiration (should be 7 days)
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        exp = datetime.fromtimestamp(payload["exp"])
        now = datetime.utcnow()

        time_diff = (exp - now).total_seconds()
        # Should be approximately 7 days
        assert 6.5 * 24 * 3600 < time_diff < 7.5 * 24 * 3600


class TestUserManagement:
    """Test user management and authentication"""

    def setup_method(self):
        self.auth_manager = AuthenticationManager()

    def test_default_users_initialized(self):
        """Test that default admin and analyst users are created"""
        # Admin user should exist
        admin = self.auth_manager._users_db.get("admin")
        assert admin is not None
        assert admin.username == "admin"
        assert admin.role == UserRole.ADMIN
        assert admin.is_active is True

        # Analyst user should exist
        analyst = self.auth_manager._users_db.get("analyst")
        assert analyst is not None
        assert analyst.username == "analyst"
        assert analyst.role == UserRole.ANALYST

    def test_authenticate_user_success(self):
        """Test successful user authentication"""
        user = self.auth_manager.authenticate_user("admin", "test-admin-password")

        assert user is not None
        assert user.username == "admin"
        assert user.role == UserRole.ADMIN

    def test_authenticate_user_wrong_password(self):
        """Test authentication with wrong password"""
        user = self.auth_manager.authenticate_user("admin", "wrong-password")

        assert user is None

    def test_authenticate_user_nonexistent(self):
        """Test authentication with nonexistent user"""
        user = self.auth_manager.authenticate_user("nonexistent", "password")

        assert user is None

    def test_authenticate_inactive_user(self):
        """Test that inactive users cannot authenticate"""
        # Deactivate admin user
        self.auth_manager.deactivate_user("admin")

        # Try to authenticate
        user = self.auth_manager.authenticate_user("admin", "test-admin-password")

        assert user is None

        # Reactivate for other tests
        self.auth_manager.activate_user("admin")

    def test_get_user(self):
        """Test getting user by username"""
        user = self.auth_manager.get_user("admin")

        assert user is not None
        assert user.username == "admin"
        assert user.role == UserRole.ADMIN

    def test_get_user_nonexistent(self):
        """Test getting nonexistent user"""
        user = self.auth_manager.get_user("nonexistent")

        assert user is None

    def test_create_user(self):
        """Test creating a new user"""
        user_data = UserCreate(
            username="newuser",
            email="newuser@example.com",
            password="secure-password-123",
            full_name="New User",
            role=UserRole.VIEWER
        )

        user = self.auth_manager.create_user(user_data)

        assert user.username == "newuser"
        assert user.email == "newuser@example.com"
        assert user.role == UserRole.VIEWER

    def test_create_user_duplicate_username(self):
        """Test that duplicate usernames are rejected"""
        user_data = UserCreate(
            username="admin",  # Already exists
            email="duplicate@example.com",
            password="password",
            role=UserRole.VIEWER
        )

        with pytest.raises(ValueError, match="already exists"):
            self.auth_manager.create_user(user_data)

    def test_change_password(self):
        """Test changing user password"""
        # Create a test user
        user_data = UserCreate(
            username="pwdtest",
            email="pwdtest@example.com",
            password="old-password",
            role=UserRole.VIEWER
        )
        self.auth_manager.create_user(user_data)

        # Change password
        success = self.auth_manager.change_password("pwdtest", "old-password", "new-password")

        assert success is True

        # Verify old password doesn't work
        user = self.auth_manager.authenticate_user("pwdtest", "old-password")
        assert user is None

        # Verify new password works
        user = self.auth_manager.authenticate_user("pwdtest", "new-password")
        assert user is not None

    def test_deactivate_user(self):
        """Test deactivating user"""
        # Create test user
        user_data = UserCreate(
            username="deactivatetest",
            email="deactivate@example.com",
            password="password",
            role=UserRole.VIEWER
        )
        self.auth_manager.create_user(user_data)

        # Deactivate
        success = self.auth_manager.deactivate_user("deactivatetest")
        assert success is True

        # Check user is inactive
        user = self.auth_manager._users_db.get("deactivatetest")
        assert user.is_active is False

    def test_last_login_updated(self):
        """Test that last_login is updated on authentication"""
        # Authenticate user
        user = self.auth_manager.authenticate_user("admin", "test-admin-password")

        assert user.last_login is not None


class TestRBAC:
    """Test Role-Based Access Control"""

    def setup_method(self):
        self.auth_manager = AuthenticationManager()

    def test_admin_permissions(self):
        """Test admin role permissions"""
        admin = self.auth_manager.get_user("admin")
        permissions = self.auth_manager.get_user_permissions(admin.role)

        # Admin should have all permissions
        assert "read:data" in permissions
        assert "write:data" in permissions
        assert "delete:data" in permissions
        assert "manage:users" in permissions
        assert len(permissions) >= 5  # Should have many permissions

    def test_analyst_permissions(self):
        """Test analyst role permissions"""
        analyst = self.auth_manager.get_user("analyst")
        permissions = self.auth_manager.get_user_permissions(analyst.role)

        # Analyst should have read/write but not user management
        assert "read:data" in permissions
        assert "write:data" in permissions
        assert "run:analysis" in permissions
        assert "manage:users" not in permissions

    def test_viewer_permissions(self):
        """Test viewer role (most restrictive)"""
        # Create viewer user
        user_data = UserCreate(
            username="viewer",
            email="viewer@example.com",
            password="password",
            role=UserRole.VIEWER
        )
        self.auth_manager.create_user(user_data)

        viewer = self.auth_manager.get_user("viewer")
        permissions = self.auth_manager.get_user_permissions(viewer.role)

        # Viewer should only have read permission
        assert "read:data" in permissions
        assert "write:data" not in permissions
        assert "delete:data" not in permissions
        assert "manage:users" not in permissions


class TestSecurityFixes:
    """Test that security fixes are working"""

    def test_no_hardcoded_credentials(self):
        """CRITICAL: Verify no hardcoded credentials in default users"""
        auth_manager = AuthenticationManager()

        # Should NOT be able to login with "admin123" or "analyst123"
        admin = auth_manager.authenticate_user("admin", "admin123")
        assert admin is None, "SECURITY ISSUE: Hardcoded password 'admin123' still works!"

        analyst = auth_manager.authenticate_user("analyst", "analyst123")
        assert analyst is None, "SECURITY ISSUE: Hardcoded password 'analyst123' still works!"

        # Should work with environment-provided passwords
        admin = auth_manager.authenticate_user("admin", "test-admin-password")
        assert admin is not None

        analyst = auth_manager.authenticate_user("analyst", "test-analyst-password")
        assert analyst is not None

    def test_jwt_secret_from_environment(self):
        """CRITICAL: Verify JWT secret comes from environment"""
        # SECRET_KEY should be the one we set in environment
        assert SECRET_KEY == "test-secret-key-for-testing-only-do-not-use-in-production"


class TestEdgeCases:
    """Test edge cases and error conditions"""

    def setup_method(self):
        self.auth_manager = AuthenticationManager()

    def test_empty_username_authentication(self):
        """Test authentication with empty username"""
        user = self.auth_manager.authenticate_user("", "password")
        assert user is None

    def test_empty_password_authentication(self):
        """Test authentication with empty password"""
        user = self.auth_manager.authenticate_user("admin", "")
        assert user is None

    def test_very_long_password(self):
        """Test password longer than bcrypt's 72-byte limit"""
        # Create user with very long password
        long_password = "a" * 1000

        user_data = UserCreate(
            username="longpwd",
            email="longpwd@example.com",
            password=long_password,
            role=UserRole.VIEWER
        )
        user = self.auth_manager.create_user(user_data)

        # Should be able to authenticate (password truncated to 72 bytes)
        auth_user = self.auth_manager.authenticate_user("longpwd", long_password)
        assert auth_user is not None

    def test_unicode_password(self):
        """Test password with Unicode characters"""
        unicode_password = "パスワード-密码-🔐-Пароль"

        user_data = UserCreate(
            username="unicode",
            email="unicode@example.com",
            password=unicode_password,
            role=UserRole.VIEWER
        )
        user = self.auth_manager.create_user(user_data)

        # Should be able to authenticate
        auth_user = self.auth_manager.authenticate_user("unicode", unicode_password)
        assert auth_user is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
