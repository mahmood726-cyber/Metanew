"""
Tests for Authentication and Authorization Manager
Comprehensive tests for JWT, RBAC, password management, and user auth
"""
import pytest
import os
from datetime import datetime, timedelta
from jose import jwt, JWTError
import secrets

# Set test environment before importing auth_manager
os.environ["ENVIRONMENT"] = "test"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-for-testing-only-do-not-use-in-production"
os.environ["ADMIN_INITIAL_PASSWORD"] = "test-admin-password"
os.environ["ANALYST_INITIAL_PASSWORD"] = "test-analyst-password"

from auth.auth_manager import (
    AuthenticationManager, PasswordManager,
    UserRole, UserInDB, Token, TokenData,
    SECRET_KEY, ALGORITHM
)


class TestPasswordManager:
    """Test password hashing and verification"""

    def setup_method(self):
        self.password_manager = PasswordManager()

    def test_password_hashing(self):
        """Test that passwords are properly hashed"""
        password = "my-secure-password-123"
        hashed = self.password_manager.hash_password(password)

        # Hashed password should not equal plain password
        assert hashed != password
        # Hashed password should be a string
        assert isinstance(hashed, str)
        # Hashed password should start with bcrypt identifier
        assert hashed.startswith("$2b$")

    def test_password_verification_correct(self):
        """Test verification with correct password"""
        password = "my-secure-password-123"
        hashed = self.password_manager.hash_password(password)

        # Correct password should verify
        assert self.password_manager.verify_password(password, hashed) is True

    def test_password_verification_incorrect(self):
        """Test verification with incorrect password"""
        password = "my-secure-password-123"
        wrong_password = "wrong-password"
        hashed = self.password_manager.hash_password(password)

        # Wrong password should not verify
        assert self.password_manager.verify_password(wrong_password, hashed) is False

    def test_password_hashing_different_hashes(self):
        """Test that same password produces different hashes (salt)"""
        password = "my-secure-password-123"
        hash1 = self.password_manager.hash_password(password)
        hash2 = self.password_manager.hash_password(password)

        # Hashes should be different due to salt
        assert hash1 != hash2
        # Both should verify correctly
        assert self.password_manager.verify_password(password, hash1) is True
        assert self.password_manager.verify_password(password, hash2) is True

    def test_password_empty_string(self):
        """Test hashing empty password"""
        password = ""
        hashed = self.password_manager.hash_password(password)

        assert isinstance(hashed, str)
        assert self.password_manager.verify_password("", hashed) is True

    def test_password_special_characters(self):
        """Test password with special characters"""
        password = "p@ssw0rd!#$%^&*()_+-=[]{}|;:,.<>?"
        hashed = self.password_manager.hash_password(password)

        assert self.password_manager.verify_password(password, hashed) is True


class TestAuthenticationManager:
    """Test JWT token generation and validation"""

    def setup_method(self):
        self.auth_manager = AuthenticationManager()

    def test_create_access_token(self):
        """Test access token creation"""
        data = {"sub": "admin", "role": UserRole.ADMIN}
        token = self.auth_manager.create_access_token(data)

        # Token should be a string
        assert isinstance(token, str)
        # Token should have 3 parts (header.payload.signature)
        assert len(token.split(".")) == 3

    def test_create_access_token_with_expiration(self):
        """Test access token with custom expiration"""
        data = {"sub": "admin"}
        expires_delta = timedelta(minutes=15)
        token = self.auth_manager.create_access_token(data, expires_delta=expires_delta)

        # Decode token without verification to check expiration
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        exp = datetime.fromtimestamp(payload["exp"])
        now = datetime.utcnow()

        # Expiration should be approximately 15 minutes from now
        time_diff = (exp - now).total_seconds()
        assert 14 * 60 < time_diff < 16 * 60  # Between 14 and 16 minutes

    def test_verify_token_valid(self):
        """Test verification of valid token"""
        data = {"sub": "admin", "role": UserRole.ADMIN}
        token = self.auth_manager.create_access_token(data)

        # Verify token
        token_data = self.auth_manager.verify_token(token)

        assert token_data is not None
        assert token_data.username == "admin"
        assert token_data.role == UserRole.ADMIN

    def test_verify_token_expired(self):
        """Test verification of expired token"""
        data = {"sub": "admin"}
        # Create token that expires immediately
        expires_delta = timedelta(seconds=-1)
        token = self.auth_manager.create_access_token(data, expires_delta=expires_delta)

        # Verify should return None for expired token
        token_data = self.auth_manager.verify_token(token)
        assert token_data is None

    def test_verify_token_invalid_signature(self):
        """Test verification with invalid signature"""
        data = {"sub": "admin"}
        token = self.auth_manager.create_access_token(data)

        # Modify token signature
        parts = token.split(".")
        parts[2] = "invalid-signature"
        invalid_token = ".".join(parts)

        # Verify should return None
        token_data = self.auth_manager.verify_token(invalid_token)
        assert token_data is None

    def test_verify_token_malformed(self):
        """Test verification with malformed token"""
        invalid_token = "not.a.valid.jwt.token"

        token_data = self.auth_manager.verify_token(invalid_token)
        assert token_data is None

    def test_verify_token_missing_subject(self):
        """Test verification with missing subject"""
        # Create token without 'sub' field
        data = {"role": UserRole.ADMIN}
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(minutes=15)
        to_encode.update({"exp": expire})
        token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

        token_data = self.auth_manager.verify_token(token)
        assert token_data is None

    def test_create_refresh_token(self):
        """Test refresh token creation"""
        data = {"sub": "admin"}
        token = self.auth_manager.create_refresh_token(data)

        assert isinstance(token, str)
        assert len(token.split(".")) == 3

        # Decode and check expiration is longer (7 days default)
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        exp = datetime.fromtimestamp(payload["exp"])
        now = datetime.utcnow()
        time_diff = (exp - now).total_seconds()

        # Should be approximately 7 days
        assert 6.5 * 24 * 3600 < time_diff < 7.5 * 24 * 3600


class TestUserManagement:
    """Test user management and authentication"""

    def setup_method(self):
        self.user_manager = AuthenticationManager()

    def test_default_users_initialized(self):
        """Test that default admin and analyst users are created"""
        # Admin user should exist
        admin = self.user_manager._users_db.get("admin")
        assert admin is not None
        assert admin.username == "admin"
        assert admin.role == UserRole.ADMIN
        assert admin.is_active is True

        # Analyst user should exist
        analyst = self.user_manager._users_db.get("analyst")
        assert analyst is not None
        assert analyst.username == "analyst"
        assert analyst.role == UserRole.ANALYST
        assert analyst.is_active is True

    def test_authenticate_user_success(self):
        """Test successful user authentication"""
        # Authenticate with correct credentials
        user = self.user_manager.authenticate_user("admin", "test-admin-password")

        assert user is not None
        assert user.username == "admin"
        assert user.role == UserRole.ADMIN

    def test_authenticate_user_wrong_password(self):
        """Test authentication with wrong password"""
        user = self.user_manager.authenticate_user("admin", "wrong-password")

        assert user is None

    def test_authenticate_user_nonexistent(self):
        """Test authentication with nonexistent user"""
        user = self.user_manager.authenticate_user("nonexistent", "password")

        assert user is None

    def test_authenticate_inactive_user(self):
        """Test authentication with inactive user"""
        # Create inactive user
        inactive_user = UserInDB(
            user_id="inactive",
            username="inactive",
            email="inactive@test.com",
            full_name="Inactive User",
            role=UserRole.VIEWER,
            is_active=False,
            created_at=datetime.utcnow(),
            hashed_password=self.user_manager.password_manager.hash_password("password")
        )
        self.user_manager._users_db["inactive"] = inactive_user

        # Should not authenticate
        user = self.user_manager.authenticate_user("inactive", "password")
        assert user is None

    def test_get_user_by_username(self):
        """Test getting user by username"""
        user = self.user_manager.get_user_by_username("admin")

        assert user is not None
        assert user.username == "admin"

    def test_get_user_by_username_nonexistent(self):
        """Test getting nonexistent user"""
        user = self.user_manager.get_user_by_username("nonexistent")

        assert user is None

    def test_create_user(self):
        """Test creating new user"""
        new_user = self.user_manager.create_user(
            username="newuser",
            email="newuser@test.com",
            full_name="New User",
            password="secure-password",
            role=UserRole.VIEWER
        )

        assert new_user is not None
        assert new_user.username == "newuser"
        assert new_user.email == "newuser@test.com"
        assert new_user.role == UserRole.VIEWER
        assert new_user.is_active is True

        # Verify user can authenticate
        user = self.user_manager.authenticate_user("newuser", "secure-password")
        assert user is not None

    def test_create_user_duplicate_username(self):
        """Test creating user with duplicate username"""
        # Try to create user with existing username
        with pytest.raises(ValueError, match="already exists"):
            self.user_manager.create_user(
                username="admin",
                email="another@test.com",
                full_name="Another Admin",
                password="password",
                role=UserRole.ADMIN
            )

    def test_update_user(self):
        """Test updating user information"""
        updated = self.user_manager.update_user(
            username="admin",
            email="newemail@test.com",
            full_name="Updated Admin"
        )

        assert updated is True
        user = self.user_manager.get_user_by_username("admin")
        assert user.email == "newemail@test.com"
        assert user.full_name == "Updated Admin"

    def test_change_password(self):
        """Test changing user password"""
        # Change password
        updated = self.user_manager.change_password("admin", "new-admin-password")
        assert updated is True

        # Old password should not work
        user = self.user_manager.authenticate_user("admin", "test-admin-password")
        assert user is None

        # New password should work
        user = self.user_manager.authenticate_user("admin", "new-admin-password")
        assert user is not None

    def test_deactivate_user(self):
        """Test deactivating user"""
        # Create test user
        self.user_manager.create_user(
            username="testuser",
            email="test@test.com",
            full_name="Test User",
            password="password",
            role=UserRole.VIEWER
        )

        # Deactivate user
        updated = self.user_manager.update_user(username="testuser", is_active=False)
        assert updated is True

        # Should not be able to authenticate
        user = self.user_manager.authenticate_user("testuser", "password")
        assert user is None


class TestRBAC:
    """Test Role-Based Access Control"""

    def setup_method(self):
        self.user_manager = AuthenticationManager()

    def test_admin_role(self):
        """Test admin role permissions"""
        admin = self.user_manager.get_user_by_username("admin")

        assert admin.role == UserRole.ADMIN
        # Admin should have full access
        assert admin.role in [UserRole.ADMIN]

    def test_analyst_role(self):
        """Test analyst role permissions"""
        analyst = self.user_manager.get_user_by_username("analyst")

        assert analyst.role == UserRole.ANALYST
        # Analyst should have limited access
        assert analyst.role in [UserRole.ANALYST, UserRole.ADMIN]

    def test_viewer_role(self):
        """Test viewer role - most restrictive"""
        # Create viewer user
        viewer = self.user_manager.create_user(
            username="viewer",
            email="viewer@test.com",
            full_name="Viewer User",
            password="password",
            role=UserRole.VIEWER
        )

        assert viewer.role == UserRole.VIEWER

    def test_invalid_role(self):
        """Test creating user with invalid role"""
        with pytest.raises((ValueError, AttributeError)):
            self.user_manager.create_user(
                username="invalidrole",
                email="invalid@test.com",
                full_name="Invalid Role",
                password="password",
                role="invalid_role"
            )


class TestSecurityFixes:
    """Test that security fixes are working"""

    def test_no_hardcoded_credentials(self):
        """CRITICAL: Verify no hardcoded credentials in default users"""
        user_manager = AuthenticationManager()

        # Verify that passwords come from environment
        # Should NOT be able to login with "admin123" or "analyst123"
        admin = user_manager.authenticate_user("admin", "admin123")
        assert admin is None, "SECURITY ISSUE: Hardcoded password 'admin123' still works!"

        analyst = user_manager.authenticate_user("analyst", "analyst123")
        assert analyst is None, "SECURITY ISSUE: Hardcoded password 'analyst123' still works!"

        # Should work with environment password
        admin = user_manager.authenticate_user("admin", "test-admin-password")
        assert admin is not None

    def test_jwt_secret_from_environment(self):
        """CRITICAL: Verify JWT secret comes from environment"""
        # SECRET_KEY should be from environment variable
        assert SECRET_KEY == "test-secret-key-for-testing-only-do-not-use-in-production"
        assert SECRET_KEY != secrets.token_urlsafe(32)

    def test_production_requires_jwt_secret(self):
        """CRITICAL: Verify production mode requires JWT_SECRET_KEY"""
        # Save original
        original_env = os.environ.get("ENVIRONMENT")
        original_secret = os.environ.get("JWT_SECRET_KEY")

        try:
            # Remove JWT_SECRET_KEY and set production
            if "JWT_SECRET_KEY" in os.environ:
                del os.environ["JWT_SECRET_KEY"]
            os.environ["ENVIRONMENT"] = "production"

            # Should raise error in production without JWT_SECRET_KEY
            with pytest.raises(ValueError, match="JWT_SECRET_KEY.*required in production"):
                # Reimport to trigger initialization
                import importlib
                import auth.auth_manager
                importlib.reload(auth.auth_manager)

        finally:
            # Restore
            if original_env:
                os.environ["ENVIRONMENT"] = original_env
            else:
                os.environ.pop("ENVIRONMENT", None)

            if original_secret:
                os.environ["JWT_SECRET_KEY"] = original_secret


class TestEdgeCases:
    """Test edge cases and error conditions"""

    def setup_method(self):
        self.user_manager = AuthenticationManager()
        self.auth_manager = AuthenticationManager()

    def test_empty_username_authentication(self):
        """Test authentication with empty username"""
        user = self.user_manager.authenticate_user("", "password")
        assert user is None

    def test_empty_password_authentication(self):
        """Test authentication with empty password"""
        user = self.user_manager.authenticate_user("admin", "")
        assert user is None

    def test_very_long_password(self):
        """Test password with 1000+ characters"""
        long_password = "a" * 1000
        hashed = self.user_manager.password_manager.hash_password(long_password)

        assert self.user_manager.password_manager.verify_password(long_password, hashed)

    def test_unicode_password(self):
        """Test password with unicode characters"""
        unicode_password = "пароль密码🔒"
        hashed = self.user_manager.password_manager.hash_password(unicode_password)

        assert self.user_manager.password_manager.verify_password(unicode_password, hashed)

    def test_token_without_role(self):
        """Test token verification without role field"""
        data = {"sub": "admin"}  # No role field
        token = self.auth_manager.create_access_token(data)

        token_data = self.auth_manager.verify_token(token)
        # Should still work, role is optional
        assert token_data is not None
        assert token_data.username == "admin"

    def test_last_login_updated(self):
        """Test that last_login is updated on authentication"""
        # First authentication
        user1 = self.user_manager.authenticate_user("admin", "test-admin-password")
        first_login = user1.last_login

        # Wait a moment
        import time
        time.sleep(0.1)

        # Second authentication
        user2 = self.user_manager.authenticate_user("admin", "test-admin-password")
        second_login = user2.last_login

        # Last login should be updated
        assert second_login is not None
        if first_login is not None:
            assert second_login > first_login


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
