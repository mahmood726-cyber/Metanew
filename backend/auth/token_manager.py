"""
Enhanced JWT Token Management with Refresh Tokens

Features:
- Access + Refresh token pairs
- Token rotation on schedule
- Token blacklist for logout
- Secure cookie storage support
- Automatic cleanup of expired tokens

Security improvements over basic JWT:
- Short-lived access tokens (15 minutes)
- Long-lived refresh tokens (7 days)
- Token blacklisting prevents replay attacks
- Automatic rotation prevents token theft
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Optional, Set
from jose import JWTError, jwt
from passlib.context import CryptContext
import secrets
import hashlib

logger = logging.getLogger(__name__)

# Configuration
SECRET_KEY = "your-secret-key-here"  # Should be loaded from environment
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7
TOKEN_ROTATION_DAYS = 1  # Rotate tokens every day


class TokenManager:
    """
    Enhanced JWT token management with refresh tokens and blacklisting

    Features:
    - Access/refresh token pairs
    - Token blacklist for logout
    - Automatic token rotation
    - Expiration tracking
    - Secure token generation

    Usage:
        manager = TokenManager()

        # Login - create token pair
        tokens = manager.create_token_pair(user_data={"sub": user.email, "role": "admin"})

        # Refresh - exchange refresh token for new access token
        new_access = manager.refresh_access_token(refresh_token)

        # Logout - blacklist tokens
        manager.blacklist_token(access_token)
        manager.blacklist_token(refresh_token)

        # Verify - check token validity
        payload = manager.verify_token(access_token, token_type="access")
    """

    def __init__(self, secret_key: str = SECRET_KEY):
        """Initialize token manager"""
        self.secret_key = secret_key
        self.blacklist: Set[str] = set()  # Token blacklist (hashed tokens)
        self.refresh_tokens: Dict[str, Dict] = {}  # Store refresh token metadata

        logger.info("✓ Token manager initialized with refresh token support")

    def _hash_token(self, token: str) -> str:
        """Hash token for secure storage in blacklist"""
        return hashlib.sha256(token.encode()).hexdigest()

    def create_access_token(
        self,
        data: Dict,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """
        Create access token (short-lived)

        Args:
            data: Payload data (user_id, email, role, etc.)
            expires_delta: Custom expiration (default: 15 minutes)

        Returns:
            JWT access token
        """
        to_encode = data.copy()

        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access",
            "jti": secrets.token_urlsafe(16)  # Unique token ID
        })

        encoded_jwt = jwt.encode(to_encode, self.secret_key, algorithm=ALGORITHM)
        return encoded_jwt

    def create_refresh_token(
        self,
        data: Dict,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """
        Create refresh token (long-lived)

        Args:
            data: Payload data (user_id, email)
            expires_delta: Custom expiration (default: 7 days)

        Returns:
            JWT refresh token
        """
        to_encode = data.copy()

        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)

        # Generate unique token ID
        jti = secrets.token_urlsafe(32)

        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "refresh",
            "jti": jti
        })

        encoded_jwt = jwt.encode(to_encode, self.secret_key, algorithm=ALGORITHM)

        # Store refresh token metadata for rotation tracking
        self.refresh_tokens[jti] = {
            "user": data.get("sub"),
            "issued": datetime.utcnow(),
            "expires": expire,
            "rotated": False
        }

        return encoded_jwt

    def create_token_pair(self, user_data: Dict) -> Dict:
        """
        Create access + refresh token pair

        Args:
            user_data: User information (sub, email, role, etc.)

        Returns:
            Dictionary with access_token, refresh_token, token_type, expires_in
        """
        access_token = self.create_access_token(data=user_data)
        refresh_token = self.create_refresh_token(data=user_data)

        logger.info(f"✓ Created token pair for user: {user_data.get('sub')}")

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # Seconds
            "refresh_expires_in": REFRESH_TOKEN_EXPIRE_DAYS * 24 * 3600
        }

    def verify_token(
        self,
        token: str,
        token_type: str = "access"
    ) -> Optional[Dict]:
        """
        Verify and decode token

        Args:
            token: JWT token to verify
            token_type: Expected token type ("access" or "refresh")

        Returns:
            Decoded payload if valid, None otherwise

        Raises:
            JWTError: If token is invalid
        """
        # Check blacklist first
        token_hash = self._hash_token(token)
        if token_hash in self.blacklist:
            logger.warning("⚠ Attempted use of blacklisted token")
            raise JWTError("Token has been revoked")

        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[ALGORITHM])

            # Verify token type
            if payload.get("type") != token_type:
                logger.warning(f"⚠ Token type mismatch: expected {token_type}, got {payload.get('type')}")
                raise JWTError(f"Invalid token type")

            # Check if refresh token has been rotated
            if token_type == "refresh":
                jti = payload.get("jti")
                if jti in self.refresh_tokens and self.refresh_tokens[jti].get("rotated"):
                    logger.warning("⚠ Attempted use of rotated refresh token")
                    raise JWTError("Refresh token has been rotated")

            return payload

        except JWTError as e:
            logger.error(f"✗ Token verification failed: {e}")
            raise

    def refresh_access_token(self, refresh_token: str) -> Dict:
        """
        Exchange refresh token for new access token

        Args:
            refresh_token: Valid refresh token

        Returns:
            New access token

        Raises:
            JWTError: If refresh token is invalid
        """
        # Verify refresh token
        payload = self.verify_token(refresh_token, token_type="refresh")

        if not payload:
            raise JWTError("Invalid refresh token")

        # Check if token should be rotated (older than TOKEN_ROTATION_DAYS)
        issued_at = datetime.fromtimestamp(payload.get("iat"))
        should_rotate = (datetime.utcnow() - issued_at).days >= TOKEN_ROTATION_DAYS

        # Create new access token
        user_data = {
            "sub": payload.get("sub"),
            "email": payload.get("email"),
            "role": payload.get("role")
        }
        access_token = self.create_access_token(data=user_data)

        result = {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60
        }

        # If token should be rotated, issue new refresh token
        if should_rotate:
            new_refresh_token = self.create_refresh_token(data=user_data)

            # Mark old refresh token as rotated
            old_jti = payload.get("jti")
            if old_jti in self.refresh_tokens:
                self.refresh_tokens[old_jti]["rotated"] = True

            result["refresh_token"] = new_refresh_token
            result["refresh_expires_in"] = REFRESH_TOKEN_EXPIRE_DAYS * 24 * 3600

            logger.info(f"✓ Rotated refresh token for user: {payload.get('sub')}")

        logger.info(f"✓ Refreshed access token for user: {payload.get('sub')}")

        return result

    def blacklist_token(self, token: str) -> bool:
        """
        Add token to blacklist (for logout)

        Args:
            token: Token to blacklist

        Returns:
            True if successfully blacklisted
        """
        try:
            # Decode to get expiration
            payload = jwt.decode(token, self.secret_key, algorithms=[ALGORITHM])

            # Hash and add to blacklist
            token_hash = self._hash_token(token)
            self.blacklist.add(token_hash)

            # If refresh token, mark as rotated
            if payload.get("type") == "refresh":
                jti = payload.get("jti")
                if jti in self.refresh_tokens:
                    self.refresh_tokens[jti]["rotated"] = True

            logger.info(f"✓ Token blacklisted: {payload.get('jti', 'unknown')[:8]}...")
            return True

        except JWTError as e:
            logger.error(f"✗ Failed to blacklist token: {e}")
            return False

    def cleanup_expired_tokens(self):
        """
        Remove expired tokens from blacklist and refresh token storage
        Should be run periodically (e.g., daily cron job)
        """
        current_time = datetime.utcnow()

        # Clean up expired refresh tokens
        expired_refresh = [
            jti for jti, meta in self.refresh_tokens.items()
            if meta["expires"] < current_time
        ]

        for jti in expired_refresh:
            del self.refresh_tokens[jti]

        logger.info(f"✓ Cleaned up {len(expired_refresh)} expired refresh tokens")

        # Note: Blacklist cleanup requires storing expiration times
        # For production, consider using Redis with TTL for automatic cleanup

    def get_stats(self) -> Dict:
        """
        Get token manager statistics

        Returns:
            Dictionary with blacklist size, refresh tokens, etc.
        """
        active_refresh = sum(
            1 for meta in self.refresh_tokens.values()
            if not meta["rotated"] and meta["expires"] > datetime.utcnow()
        )

        return {
            "blacklist_size": len(self.blacklist),
            "total_refresh_tokens": len(self.refresh_tokens),
            "active_refresh_tokens": active_refresh,
            "access_token_ttl_minutes": ACCESS_TOKEN_EXPIRE_MINUTES,
            "refresh_token_ttl_days": REFRESH_TOKEN_EXPIRE_DAYS,
            "rotation_interval_days": TOKEN_ROTATION_DAYS
        }


# Global token manager instance
token_manager = TokenManager()


# Utility functions for FastAPI integration

def create_tokens_for_user(user_data: Dict) -> Dict:
    """
    Create access and refresh tokens for user

    Args:
        user_data: User information

    Returns:
        Token pair dictionary
    """
    return token_manager.create_token_pair(user_data)


def verify_access_token(token: str) -> Optional[Dict]:
    """
    Verify access token

    Args:
        token: Access token to verify

    Returns:
        Decoded payload or None
    """
    try:
        return token_manager.verify_token(token, token_type="access")
    except JWTError:
        return None


def refresh_user_token(refresh_token: str) -> Optional[Dict]:
    """
    Refresh user's access token

    Args:
        refresh_token: Valid refresh token

    Returns:
        New token(s) or None
    """
    try:
        return token_manager.refresh_access_token(refresh_token)
    except JWTError:
        return None


def logout_user(access_token: str, refresh_token: Optional[str] = None) -> bool:
    """
    Logout user by blacklisting tokens

    Args:
        access_token: User's access token
        refresh_token: User's refresh token (optional)

    Returns:
        True if successful
    """
    success = token_manager.blacklist_token(access_token)

    if refresh_token:
        success = success and token_manager.blacklist_token(refresh_token)

    return success


# Example usage
if __name__ == "__main__":
    # Create token manager
    manager = TokenManager()

    # Create tokens for user
    user_data = {
        "sub": "user@example.com",
        "email": "user@example.com",
        "role": "admin"
    }

    tokens = manager.create_token_pair(user_data)
    print("Access Token:", tokens["access_token"][:50] + "...")
    print("Refresh Token:", tokens["refresh_token"][:50] + "...")

    # Verify access token
    payload = manager.verify_token(tokens["access_token"], token_type="access")
    print("\nVerified payload:", payload)

    # Refresh access token
    new_tokens = manager.refresh_access_token(tokens["refresh_token"])
    print("\nNew access token:", new_tokens["access_token"][:50] + "...")

    # Blacklist tokens (logout)
    manager.blacklist_token(tokens["access_token"])
    manager.blacklist_token(tokens["refresh_token"])

    try:
        manager.verify_token(tokens["access_token"], token_type="access")
    except JWTError as e:
        print(f"\n✓ Blacklisted token rejected: {e}")

    # Get stats
    stats = manager.get_stats()
    print("\nToken Manager Stats:", stats)
