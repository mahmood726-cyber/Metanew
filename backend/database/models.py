"""
Database Models for EvidenceOS PRIME
SQLAlchemy ORM models for PostgreSQL
"""
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, Text, JSON,
    ForeignKey, UniqueConstraint, Index, Enum as SQLEnum
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum
import uuid


Base = declarative_base()


def generate_uuid():
    """Generate UUID for primary keys"""
    return str(uuid.uuid4())


class UserRoleEnum(enum.Enum):
    """User role enumeration"""
    ADMIN = "admin"
    ANALYST = "analyst"
    VIEWER = "viewer"


class AnalysisTypeEnum(enum.Enum):
    """Analysis type enumeration"""
    PAIRWISE_MA = "pairwise_ma"
    NETWORK_MA = "network_ma"
    DOSE_RESPONSE = "dose_response"
    HEALTH_ECONOMICS = "health_economics"
    BUDGET_IMPACT = "budget_impact"


class AnalysisStatusEnum(enum.Enum):
    """Analysis status enumeration"""
    DRAFT = "draft"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class User(Base):
    """User model"""
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=generate_uuid)
    username = Column(String(100), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255))
    role = Column(SQLEnum(UserRoleEnum), nullable=False, default=UserRoleEnum.VIEWER)
    is_active = Column(Boolean, default=True, nullable=False)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    last_login = Column(DateTime(timezone=True))

    # Relationships
    projects = relationship("Project", back_populates="owner", cascade="all, delete-orphan")
    analyses = relationship("Analysis", back_populates="owner", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="user")

    def __repr__(self):
        return f"<User(username='{self.username}', email='{self.email}', role='{self.role}')>"


class Project(Base):
    """Project model - groups related analyses"""
    __tablename__ = "projects"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    is_archived = Column(Boolean, default=False)

    # Metadata
    tags = Column(JSON)  # Store tags as JSON array
    settings = Column(JSON)  # Store project settings

    # Relationships
    owner = relationship("User", back_populates="projects")
    analyses = relationship("Analysis", back_populates="project", cascade="all, delete-orphan")

    # Indexes
    __table_args__ = (
        Index('idx_project_owner', 'owner_id'),
        Index('idx_project_created', 'created_at'),
    )

    def __repr__(self):
        return f"<Project(name='{self.name}', owner='{self.owner.username}')>"


class Analysis(Base):
    """Analysis model - stores analysis configurations and results"""
    __tablename__ = "analyses"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    analysis_type = Column(SQLEnum(AnalysisTypeEnum), nullable=False)
    status = Column(SQLEnum(AnalysisStatusEnum), default=AnalysisStatusEnum.DRAFT)

    # Foreign keys
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False)

    # Analysis data (stored as JSON)
    input_data = Column(JSON)  # Raw input data
    parameters = Column(JSON)  # Analysis parameters
    results = Column(JSON)  # Analysis results
    plots = Column(JSON)  # Plot configurations/data

    # Protocol information
    protocol = Column(JSON)  # PICO, search strategy, etc.

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))

    # Versioning and audit
    version = Column(Integer, default=1)
    content_hash = Column(String(64))  # SHA256 hash for integrity

    # Relationships
    project = relationship("Project", back_populates="analyses")
    owner = relationship("User", back_populates="analyses")
    datasets = relationship("Dataset", back_populates="analysis", cascade="all, delete-orphan")

    # Indexes
    __table_args__ = (
        Index('idx_analysis_project', 'project_id'),
        Index('idx_analysis_owner', 'owner_id'),
        Index('idx_analysis_type', 'analysis_type'),
        Index('idx_analysis_status', 'status'),
        Index('idx_analysis_created', 'created_at'),
    )

    def __repr__(self):
        return f"<Analysis(name='{self.name}', type='{self.analysis_type}', status='{self.status}')>"


class Dataset(Base):
    """Dataset model - stores uploaded datasets"""
    __tablename__ = "datasets"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    description = Column(Text)

    # Foreign keys
    analysis_id = Column(String, ForeignKey("analyses.id"))
    uploaded_by = Column(String, ForeignKey("users.id"), nullable=False)

    # Dataset metadata
    data_type = Column(String(50))  # binary, continuous, tte, etc.
    n_studies = Column(Integer)
    n_observations = Column(Integer)

    # Data storage
    data = Column(JSON)  # Actual data stored as JSON
    data_url = Column(String(500))  # Alternative: URL to external storage

    # File information
    original_filename = Column(String(255))
    file_size_bytes = Column(Integer)
    file_hash = Column(String(64))  # SHA256 hash

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    analysis = relationship("Analysis", back_populates="datasets")
    uploader = relationship("User")

    # Indexes
    __table_args__ = (
        Index('idx_dataset_analysis', 'analysis_id'),
        Index('idx_dataset_uploader', 'uploaded_by'),
    )

    def __repr__(self):
        return f"<Dataset(name='{self.name}', type='{self.data_type}', n_studies={self.n_studies})>"


class AuditLog(Base):
    """Audit log model - tracks all important operations"""
    __tablename__ = "audit_logs"

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.id"))
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Action details
    action = Column(String(100), nullable=False)  # e.g., "login", "create_analysis", "delete_project"
    resource_type = Column(String(50))  # e.g., "analysis", "project", "user"
    resource_id = Column(String)  # ID of affected resource

    # Request details
    ip_address = Column(String(45))  # IPv4 or IPv6
    user_agent = Column(String(500))
    request_method = Column(String(10))  # GET, POST, etc.
    request_path = Column(String(500))

    # Additional details
    details = Column(JSON)  # Flexible JSON field for action-specific details
    success = Column(Boolean, default=True)
    error_message = Column(Text)

    # Relationships
    user = relationship("User", back_populates="audit_logs")

    # Indexes
    __table_args__ = (
        Index('idx_audit_user', 'user_id'),
        Index('idx_audit_timestamp', 'timestamp'),
        Index('idx_audit_action', 'action'),
        Index('idx_audit_resource', 'resource_type', 'resource_id'),
    )

    def __repr__(self):
        return f"<AuditLog(user='{self.user_id}', action='{self.action}', timestamp='{self.timestamp}')>"


class CacheEntry(Base):
    """Cache entry model - for persistent distributed caching"""
    __tablename__ = "cache_entries"

    id = Column(String, primary_key=True, default=generate_uuid)
    cache_key = Column(String(255), unique=True, nullable=False, index=True)

    # Cache data
    data = Column(JSON)  # Cached data as JSON
    data_size_bytes = Column(Integer)

    # Metadata
    analysis_type = Column(String(50))
    parameters_hash = Column(String(64))  # Hash of parameters used

    # Timestamps and TTL
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    accessed_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    expires_at = Column(DateTime(timezone=True))

    # Statistics
    hit_count = Column(Integer, default=0)

    # Indexes
    __table_args__ = (
        Index('idx_cache_key', 'cache_key'),
        Index('idx_cache_expires', 'expires_at'),
        Index('idx_cache_accessed', 'accessed_at'),
    )

    def __repr__(self):
        return f"<CacheEntry(key='{self.cache_key}', hits={self.hit_count})>"


class ReportTemplate(Base):
    """Report template model - stores custom report templates"""
    __tablename__ = "report_templates"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    description = Column(Text)

    # Template details
    template_type = Column(String(50))  # word, pdf, powerpoint, html
    template_content = Column(Text)  # Template markup/content
    template_config = Column(JSON)  # Configuration options

    # Ownership
    created_by = Column(String, ForeignKey("users.id"))
    is_public = Column(Boolean, default=False)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    creator = relationship("User")

    def __repr__(self):
        return f"<ReportTemplate(name='{self.name}', type='{self.template_type}')>"


class APIKey(Base):
    """API key model - for programmatic access"""
    __tablename__ = "api_keys"

    id = Column(String, primary_key=True, default=generate_uuid)
    key = Column(String(64), unique=True, nullable=False, index=True)
    name = Column(String(255))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)

    # Permissions and limits
    permissions = Column(JSON)  # Array of allowed permissions
    rate_limit = Column(Integer)  # Requests per minute
    is_active = Column(Boolean, default=True)

    # Usage tracking
    last_used = Column(DateTime(timezone=True))
    usage_count = Column(Integer, default=0)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True))

    # Relationships
    user = relationship("User")

    # Indexes
    __table_args__ = (
        Index('idx_apikey_key', 'key'),
        Index('idx_apikey_user', 'user_id'),
    )

    def __repr__(self):
        return f"<APIKey(name='{self.name}', user='{self.user_id}')>"
