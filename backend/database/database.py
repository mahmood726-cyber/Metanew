"""
Database connection and session management for EvidenceOS PRIME
Supports PostgreSQL with connection pooling and tenant isolation
"""
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
from contextlib import contextmanager
from typing import Generator
import os
from .models import Base

# Database configuration from environment
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://evidenceos:changeme@localhost:5432/evidenceos_db"
)

# Create engine with connection pooling
engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,  # Number of persistent connections
    max_overflow=40,  # Additional connections when pool is full
    pool_pre_ping=True,  # Verify connections before using
    pool_recycle=3600,  # Recycle connections after 1 hour
    echo=os.getenv("SQL_ECHO", "false").lower() == "true"  # SQL logging
)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def init_db():
    """
    Initialize database - create all tables
    Run this on first deployment
    """
    Base.metadata.create_all(bind=engine)
    print("✅ Database initialized successfully")


def get_db() -> Generator[Session, None, None]:
    """
    Dependency for FastAPI routes to get database session

    Usage:
        @app.get("/projects")
        def list_projects(db: Session = Depends(get_db)):
            projects = db.query(Project).all()
            return projects
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@contextmanager
def get_db_context():
    """
    Context manager for database session

    Usage:
        with get_db_context() as db:
            user = db.query(User).filter(User.id == user_id).first()
    """
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


class TenantSession:
    """
    Tenant-aware database session
    Automatically filters queries by organization_id
    """

    def __init__(self, db: Session, organization_id: str):
        self.db = db
        self.organization_id = organization_id

    def query(self, model):
        """Override query to add organization filter"""
        query = self.db.query(model)

        # If model has organization_id, filter by it
        if hasattr(model, 'organization_id'):
            query = query.filter(model.organization_id == self.organization_id)

        return query

    def add(self, instance):
        """Override add to set organization_id"""
        if hasattr(instance, 'organization_id') and not instance.organization_id:
            instance.organization_id = self.organization_id
        self.db.add(instance)

    def commit(self):
        """Commit transaction"""
        self.db.commit()

    def rollback(self):
        """Rollback transaction"""
        self.db.rollback()

    def close(self):
        """Close session"""
        self.db.close()


def get_tenant_db(organization_id: str) -> Generator[TenantSession, None, None]:
    """
    Get tenant-scoped database session

    Usage:
        @app.get("/projects")
        def list_projects(
            tenant_db: TenantSession = Depends(get_tenant_db_dependency),
            current_user: User = Depends(get_current_user)
        ):
            # Automatically filtered to current user's organization
            projects = tenant_db.query(Project).all()
            return projects
    """
    db = SessionLocal()
    try:
        tenant_session = TenantSession(db, organization_id)
        yield tenant_session
    finally:
        db.close()


# Event listeners for automatic timestamp updates
@event.listens_for(Base, 'before_update', propagate=True)
def receive_before_update(mapper, connection, target):
    """Automatically update updated_at timestamp"""
    if hasattr(target, 'updated_at'):
        from datetime import datetime
        target.updated_at = datetime.utcnow()


# Database health check
def check_db_health() -> dict:
    """
    Check database connectivity and return health status

    Returns:
        dict with status, connection_pool_size, etc.
    """
    try:
        with get_db_context() as db:
            # Simple query to test connection
            db.execute("SELECT 1")

        pool = engine.pool
        return {
            "status": "healthy",
            "pool_size": pool.size(),
            "checked_out": pool.checkedout(),
            "overflow": pool.overflow(),
            "database": engine.url.database
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }


# Migration helper (for Alembic)
def get_alembic_config():
    """Get Alembic configuration for migrations"""
    from alembic.config import Config
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", DATABASE_URL)
    return config


# Utility functions
def create_organization(db: Session, name: str, admin_email: str, **kwargs) -> 'Organization':
    """
    Create a new organization with default settings

    Args:
        db: Database session
        name: Organization name
        admin_email: Admin email address
        **kwargs: Additional organization attributes

    Returns:
        Created Organization object
    """
    from .models import Organization

    org = Organization(
        name=name,
        admin_email=admin_email,
        subscription_tier=kwargs.get('subscription_tier', 'starter'),
        max_users=kwargs.get('max_users', 5),
        max_projects=kwargs.get('max_projects', 50),
        storage_limit_gb=kwargs.get('storage_limit_gb', 10),
        **kwargs
    )
    db.add(org)
    db.commit()
    db.refresh(org)
    return org


def create_user(
    db: Session,
    organization_id: str,
    username: str,
    email: str,
    hashed_password: str,
    role: str = "analyst"
) -> 'User':
    """
    Create a new user within an organization

    Args:
        db: Database session
        organization_id: UUID of organization
        username: Unique username
        email: User email
        hashed_password: Pre-hashed password
        role: User role (admin, analyst, viewer)

    Returns:
        Created User object
    """
    from .models import User

    user = User(
        organization_id=organization_id,
        username=username,
        email=email,
        hashed_password=hashed_password,
        role=role
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def log_audit_event(
    db: Session,
    organization_id: str,
    user_id: str,
    event_type: str,
    action: str,
    **kwargs
):
    """
    Log an audit event

    Args:
        db: Database session
        organization_id: UUID of organization
        user_id: UUID of user (or None for system events)
        event_type: Type of event (login, project_created, etc.)
        action: Description of action
        **kwargs: Additional audit log fields
    """
    from .models import AuditLog

    log = AuditLog(
        organization_id=organization_id,
        user_id=user_id,
        event_type=event_type,
        action=action,
        **kwargs
    )
    db.add(log)
    db.commit()


def track_usage(
    db: Session,
    organization_id: str,
    user_id: str,
    metric_type: str,
    metric_value: float = 1.0,
    **kwargs
):
    """
    Track usage metric for billing

    Args:
        db: Database session
        organization_id: UUID of organization
        user_id: UUID of user
        metric_type: Type of metric (meta_analysis_run, etc.)
        metric_value: Metric value (default 1.0)
        **kwargs: Additional metric fields
    """
    from .models import UsageMetric

    metric = UsageMetric(
        organization_id=organization_id,
        user_id=user_id,
        metric_type=metric_type,
        metric_value=metric_value,
        **kwargs
    )
    db.add(metric)
    db.commit()
