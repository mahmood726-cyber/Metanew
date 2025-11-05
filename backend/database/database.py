"""
Database Connection and Session Management
Handles PostgreSQL connection pooling and session lifecycle
"""
import os
from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import NullPool, QueuePool
from contextlib import contextmanager
import logging

from .models import Base

logger = logging.getLogger(__name__)

# Get database configuration from environment
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://evidenceos_user:password@localhost:5432/evidenceos"
)

# Connection pool settings
DB_POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "10"))
DB_MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "20"))
DB_POOL_TIMEOUT = int(os.getenv("DB_POOL_TIMEOUT", "30"))
DB_POOL_RECYCLE = int(os.getenv("DB_POOL_RECYCLE", "3600"))

# Create engine
engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=DB_POOL_SIZE,
    max_overflow=DB_MAX_OVERFLOW,
    pool_timeout=DB_POOL_TIMEOUT,
    pool_recycle=DB_POOL_RECYCLE,
    pool_pre_ping=True,  # Enable connection health checks
    echo=os.getenv("LOG_SQL_QUERIES", "false").lower() == "true",  # SQL logging
)

# Create session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)


def init_db():
    """
    Initialize database - create all tables
    Use this for development/testing
    In production, use Alembic migrations
    """
    try:
        logger.info("Initializing database...")
        Base.metadata.create_all(bind=engine)
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {str(e)}")
        raise


def drop_db():
    """
    Drop all tables - WARNING: This will delete all data!
    Only use for testing/development
    """
    logger.warning("Dropping all database tables...")
    Base.metadata.drop_all(bind=engine)
    logger.info("All tables dropped")


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency for database sessions
    Yields a database session and ensures it's closed after use

    Usage:
        @app.get("/items")
        def get_items(db: Session = Depends(get_db)):
            return db.query(Item).all()
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@contextmanager
def get_db_context():
    """
    Context manager for database sessions
    Use for non-FastAPI contexts

    Usage:
        with get_db_context() as db:
            users = db.query(User).all()
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


class DatabaseManager:
    """Database management utilities"""

    @staticmethod
    def health_check() -> bool:
        """Check if database is accessible"""
        try:
            with engine.connect() as conn:
                conn.execute("SELECT 1")
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {str(e)}")
            return False

    @staticmethod
    def get_connection_info() -> dict:
        """Get database connection information"""
        return {
            "url": DATABASE_URL.split("@")[-1],  # Don't expose credentials
            "pool_size": DB_POOL_SIZE,
            "max_overflow": DB_MAX_OVERFLOW,
            "timeout": DB_POOL_TIMEOUT,
            "recycle": DB_POOL_RECYCLE,
        }

    @staticmethod
    def get_pool_status() -> dict:
        """Get connection pool status"""
        pool = engine.pool
        return {
            "size": pool.size(),
            "checked_in": pool.checkedin(),
            "checked_out": pool.checkedout(),
            "overflow": pool.overflow(),
            "total_connections": pool.size() + pool.overflow(),
        }


# Global database manager instance
db_manager = DatabaseManager()
