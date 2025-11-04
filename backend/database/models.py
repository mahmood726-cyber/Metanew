"""
Database models for multi-tenant EvidenceOS PRIME
Supports PostgreSQL with complete tenant isolation
"""
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Text, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

Base = declarative_base()


class Organization(Base):
    """Multi-tenant organization/company"""
    __tablename__ = "organizations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False, unique=True)
    subscription_tier = Column(String(50), default="starter")  # starter, professional, enterprise
    max_users = Column(Integer, default=5)
    max_projects = Column(Integer, default=50)
    storage_limit_gb = Column(Integer, default=10)

    # Billing
    stripe_customer_id = Column(String(100), unique=True, nullable=True)
    stripe_subscription_id = Column(String(100), nullable=True)
    subscription_status = Column(String(50), default="active")  # active, canceled, past_due

    # Contact
    admin_email = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=True)
    country = Column(String(100), default="US")

    # Settings
    settings = Column(JSONB, default={})
    branding = Column(JSONB, default={})  # logo_url, primary_color, etc.

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    trial_ends_at = Column(DateTime, nullable=True)

    # Relationships
    users = relationship("User", back_populates="organization", cascade="all, delete-orphan")
    projects = relationship("Project", back_populates="organization", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Organization {self.name} ({self.subscription_tier})>"


class User(Base):
    """User with organization membership"""
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False)
    username = Column(String(100), nullable=False, unique=True)
    email = Column(String(255), nullable=False, unique=True)
    hashed_password = Column(Text, nullable=False)
    role = Column(String(50), default="analyst")  # admin, analyst, viewer

    # Profile
    first_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=True)
    title = Column(String(100), nullable=True)

    # Status
    is_active = Column(Boolean, default=True)
    email_verified = Column(Boolean, default=False)
    last_login = Column(DateTime, nullable=True)

    # Security
    failed_login_attempts = Column(Integer, default=0)
    locked_until = Column(DateTime, nullable=True)
    password_changed_at = Column(DateTime, default=datetime.utcnow)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    organization = relationship("Organization", back_populates="users")
    projects = relationship("Project", back_populates="created_by_user")
    audit_logs = relationship("AuditLog", back_populates="user")

    def __repr__(self):
        return f"<User {self.username} ({self.role})>"


class Project(Base):
    """Meta-analysis project with evidence data"""
    __tablename__ = "projects"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Metadata
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    status = Column(String(50), default="draft")  # draft, in_progress, completed, archived
    project_type = Column(String(50), default="meta_analysis")  # meta_analysis, nma, dose_response, hta

    # Evidence data (stored as JSONB for flexibility)
    evidence_object = Column(JSONB, default={})
    protocol = Column(JSONB, default={})
    results = Column(JSONB, default={})

    # Analysis settings
    analysis_settings = Column(JSONB, default={})

    # Version control
    version = Column(Integer, default=1)
    content_hash = Column(String(64), nullable=True)

    # Collaboration
    shared_with = Column(JSONB, default=[])  # List of user IDs with access
    is_public = Column(Boolean, default=False)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)

    # Relationships
    organization = relationship("Organization", back_populates="projects")
    created_by_user = relationship("User", back_populates="projects")
    files = relationship("ProjectFile", back_populates="project", cascade="all, delete-orphan")
    versions = relationship("ProjectVersion", back_populates="project", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Project {self.name} ({self.status})>"


class ProjectFile(Base):
    """Files associated with projects (reports, data uploads, etc.)"""
    __tablename__ = "project_files"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False)

    # File info
    filename = Column(String(255), nullable=False)
    file_type = Column(String(50), nullable=False)  # csv, xlsx, pdf, docx, png
    file_path = Column(Text, nullable=False)  # Relative path in storage
    file_size_bytes = Column(Integer, nullable=False)
    mime_type = Column(String(100), nullable=True)

    # Metadata
    description = Column(Text, nullable=True)
    uploaded_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Security
    content_hash = Column(String(64), nullable=True)  # SHA256 for integrity

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    project = relationship("Project", back_populates="files")

    def __repr__(self):
        return f"<ProjectFile {self.filename}>"


class ProjectVersion(Base):
    """Version history for projects"""
    __tablename__ = "project_versions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False)
    version_number = Column(Integer, nullable=False)

    # Snapshot data
    evidence_object_snapshot = Column(JSONB, nullable=False)
    results_snapshot = Column(JSONB, nullable=True)
    content_hash = Column(String(64), nullable=False)

    # Metadata
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    change_description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    project = relationship("Project", back_populates="versions")

    def __repr__(self):
        return f"<ProjectVersion {self.project_id} v{self.version_number}>"


class AuditLog(Base):
    """Security and action audit log"""
    __tablename__ = "audit_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    # Event details
    event_type = Column(String(100), nullable=False)  # login, logout, project_created, etc.
    action = Column(String(255), nullable=False)
    resource_type = Column(String(50), nullable=True)  # project, user, organization
    resource_id = Column(UUID(as_uuid=True), nullable=True)

    # Context
    ip_address = Column(String(50), nullable=True)
    user_agent = Column(Text, nullable=True)
    details = Column(JSONB, default={})

    # Result
    status = Column(String(50), default="success")  # success, failure, error
    error_message = Column(Text, nullable=True)

    # Timestamps
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    user = relationship("User", back_populates="audit_logs")

    def __repr__(self):
        return f"<AuditLog {self.event_type} at {self.timestamp}>"


class UsageMetric(Base):
    """Track usage for billing and analytics"""
    __tablename__ = "usage_metrics"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    # Metric details
    metric_type = Column(String(100), nullable=False)  # meta_analysis_run, report_generated, api_call
    metric_value = Column(Float, default=1.0)
    unit = Column(String(50), default="count")  # count, bytes, minutes

    # Context
    project_id = Column(UUID(as_uuid=True), nullable=True)
    details = Column(JSONB, default={})

    # Timestamps
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    def __repr__(self):
        return f"<UsageMetric {self.metric_type} = {self.metric_value}>"


class APIKey(Base):
    """API keys for programmatic access"""
    __tablename__ = "api_keys"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Key details
    key_hash = Column(String(64), nullable=False, unique=True)  # SHA256 of actual key
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)

    # Permissions
    scopes = Column(JSONB, default=["read"])  # read, write, admin
    is_active = Column(Boolean, default=True)

    # Usage tracking
    last_used = Column(DateTime, nullable=True)
    usage_count = Column(Integer, default=0)

    # Expiration
    expires_at = Column(DateTime, nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<APIKey {self.name}>"


class Notification(Base):
    """User notifications"""
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Notification details
    notification_type = Column(String(100), nullable=False)  # info, warning, error, success
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    link = Column(Text, nullable=True)

    # Status
    is_read = Column(Boolean, default=False)
    read_at = Column(DateTime, nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    def __repr__(self):
        return f"<Notification {self.title}>"


# Index definitions for performance
from sqlalchemy import Index

Index("idx_projects_org_status", Project.organization_id, Project.status)
Index("idx_audit_logs_org_timestamp", AuditLog.organization_id, AuditLog.timestamp.desc())
Index("idx_usage_metrics_org_timestamp", UsageMetric.organization_id, UsageMetric.timestamp.desc())
Index("idx_users_org_active", User.organization_id, User.is_active)
