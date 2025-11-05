"""
Authentication and Authorization Manager
Handles JWT token generation, validation, user authentication, and RBAC
"""
import os
import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict, List
from passlib.context import CryptContext
from jose import JWTError, jwt
from pydantic import BaseModel, EmailStr


# Configuration from environment variables
SECRET_KEY = os.getenv("JWT_SECRET_KEY", secrets.token_urlsafe(32))
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class UserRole:
    """User role definitions"""
    ADMIN = "admin"
    ANALYST = "analyst"
    VIEWER = "viewer"
    ALL_ROLES = [ADMIN, ANALYST, VIEWER]


class Permission:
    """Permission definitions"""
    # Data permissions
    READ_DATA = "read:data"
    WRITE_DATA = "write:data"
    DELETE_DATA = "delete:data"

    # Analysis permissions
    RUN_ANALYSIS = "run:analysis"
    EXPORT_RESULTS = "export:results"

    # Admin permissions
    MANAGE_USERS = "manage:users"
    MANAGE_SETTINGS = "manage:settings"
    VIEW_AUDIT_LOGS = "view:audit_logs"


# Role-Permission mapping
ROLE_PERMISSIONS = {
    UserRole.ADMIN: [
        Permission.READ_DATA,
        Permission.WRITE_DATA,
        Permission.DELETE_DATA,
        Permission.RUN_ANALYSIS,
        Permission.EXPORT_RESULTS,
        Permission.MANAGE_USERS,
        Permission.MANAGE_SETTINGS,
        Permission.VIEW_AUDIT_LOGS,
    ],
    UserRole.ANALYST: [
        Permission.READ_DATA,
        Permission.WRITE_DATA,
        Permission.RUN_ANALYSIS,
        Permission.EXPORT_RESULTS,
    ],
    UserRole.VIEWER: [
        Permission.READ_DATA,
    ],
}


class Token(BaseModel):
    """Token response model"""
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_in: int


class TokenData(BaseModel):
    """Token payload data"""
    username: Optional[str] = None
    user_id: Optional[str] = None
    role: Optional[str] = None
    permissions: List[str] = []


class User(BaseModel):
    """User model"""
    user_id: str
    username: str
    email: EmailStr
    full_name: Optional[str] = None
    role: str = UserRole.VIEWER
    is_active: bool = True
    created_at: datetime
    last_login: Optional[datetime] = None


class UserInDB(User):
    """User model with hashed password"""
    hashed_password: str


class UserCreate(BaseModel):
    """User creation model"""
    username: str
    email: EmailStr
    password: str
    full_name: Optional[str] = None
    role: str = UserRole.VIEWER


class PasswordManager:
    """Password hashing and verification"""

    @staticmethod
    def hash_password(password: str) -> str:
        """Hash a password"""
        return pwd_context.hash(password)

    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify a password against hash"""
        return pwd_context.verify(plain_password, hashed_password)

    @staticmethod
    def generate_random_password(length: int = 16) -> str:
        """Generate a secure random password"""
        return secrets.token_urlsafe(length)


class TokenManager:
    """JWT token creation and validation"""

    @staticmethod
    def create_access_token(
        data: Dict,
        expires_delta: Optional[timedelta] = None
    ) -> str:
        """Create JWT access token"""
        to_encode = data.copy()

        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access"
        })

        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt

    @staticmethod
    def create_refresh_token(data: Dict) -> str:
        """Create JWT refresh token"""
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)

        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "refresh"
        })

        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt

    @staticmethod
    def decode_token(token: str) -> Optional[Dict]:
        """Decode and validate JWT token"""
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            return payload
        except JWTError:
            return None

    @staticmethod
    def verify_token(token: str) -> bool:
        """Verify token is valid"""
        payload = TokenManager.decode_token(token)
        return payload is not None


class AuthenticationManager:
    """Main authentication manager"""

    def __init__(self):
        self.password_manager = PasswordManager()
        self.token_manager = TokenManager()
        # In production, this would use a database
        # For now, using in-memory storage
        self._users_db: Dict[str, UserInDB] = {}
        self._initialize_default_users()

    def _initialize_default_users(self):
        """Initialize default admin user"""
        # Default admin user (should be changed in production)
        default_admin = UserInDB(
            user_id="admin",
            username="admin",
            email="admin@evidenceos.local",
            full_name="System Administrator",
            role=UserRole.ADMIN,
            is_active=True,
            created_at=datetime.utcnow(),
            hashed_password=self.password_manager.hash_password("admin123")
        )
        self._users_db["admin"] = default_admin

        # Default analyst user
        default_analyst = UserInDB(
            user_id="analyst",
            username="analyst",
            email="analyst@evidenceos.local",
            full_name="Analyst User",
            role=UserRole.ANALYST,
            is_active=True,
            created_at=datetime.utcnow(),
            hashed_password=self.password_manager.hash_password("analyst123")
        )
        self._users_db["analyst"] = default_analyst

    def authenticate_user(
        self,
        username: str,
        password: str
    ) -> Optional[UserInDB]:
        """Authenticate user with username and password"""
        user = self._users_db.get(username)

        if not user:
            return None

        if not user.is_active:
            return None

        if not self.password_manager.verify_password(password, user.hashed_password):
            return None

        # Update last login
        user.last_login = datetime.utcnow()
        return user

    def create_user(self, user_data: UserCreate) -> User:
        """Create a new user"""
        if user_data.username in self._users_db:
            raise ValueError(f"User {user_data.username} already exists")

        if user_data.role not in UserRole.ALL_ROLES:
            raise ValueError(f"Invalid role: {user_data.role}")

        hashed_password = self.password_manager.hash_password(user_data.password)

        user = UserInDB(
            user_id=user_data.username,  # In production, use UUID
            username=user_data.username,
            email=user_data.email,
            full_name=user_data.full_name,
            role=user_data.role,
            is_active=True,
            created_at=datetime.utcnow(),
            hashed_password=hashed_password
        )

        self._users_db[user.username] = user
        return User(**user.dict())

    def get_user(self, username: str) -> Optional[User]:
        """Get user by username"""
        user = self._users_db.get(username)
        if user:
            return User(**user.dict())
        return None

    def get_user_permissions(self, role: str) -> List[str]:
        """Get permissions for a role"""
        return ROLE_PERMISSIONS.get(role, [])

    def generate_tokens(self, user: UserInDB) -> Token:
        """Generate access and refresh tokens for user"""
        permissions = self.get_user_permissions(user.role)

        token_data = {
            "sub": user.username,
            "user_id": user.user_id,
            "role": user.role,
            "permissions": permissions
        }

        access_token = self.token_manager.create_access_token(token_data)
        refresh_token = self.token_manager.create_refresh_token({
            "sub": user.username,
            "user_id": user.user_id
        })

        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60  # in seconds
        )

    def refresh_access_token(self, refresh_token: str) -> Optional[Token]:
        """Generate new access token from refresh token"""
        payload = self.token_manager.decode_token(refresh_token)

        if not payload or payload.get("type") != "refresh":
            return None

        username = payload.get("sub")
        user = self._users_db.get(username)

        if not user or not user.is_active:
            return None

        return self.generate_tokens(user)

    def verify_permission(self, user: User, required_permission: str) -> bool:
        """Check if user has required permission"""
        user_permissions = self.get_user_permissions(user.role)
        return required_permission in user_permissions

    def change_password(
        self,
        username: str,
        old_password: str,
        new_password: str
    ) -> bool:
        """Change user password"""
        user = self._users_db.get(username)

        if not user:
            return False

        if not self.password_manager.verify_password(old_password, user.hashed_password):
            return False

        user.hashed_password = self.password_manager.hash_password(new_password)
        return True

    def reset_password(self, username: str) -> Optional[str]:
        """Reset user password (admin only)"""
        user = self._users_db.get(username)

        if not user:
            return None

        new_password = self.password_manager.generate_random_password()
        user.hashed_password = self.password_manager.hash_password(new_password)
        return new_password

    def deactivate_user(self, username: str) -> bool:
        """Deactivate user account"""
        user = self._users_db.get(username)

        if not user:
            return False

        user.is_active = False
        return True

    def activate_user(self, username: str) -> bool:
        """Activate user account"""
        user = self._users_db.get(username)

        if not user:
            return False

        user.is_active = True
        return True

    def list_users(self) -> List[User]:
        """List all users"""
        return [User(**user.dict()) for user in self._users_db.values()]


# Global authentication manager instance
auth_manager = AuthenticationManager()
