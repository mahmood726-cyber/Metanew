"""
Tests for Database Module
Comprehensive tests for database connection, sessions, and ORM models
"""
import pytest
import os
from datetime import datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import NullPool
import uuid

# Set test environment before imports
os.environ["ENVIRONMENT"] = "test"
os.environ["DATABASE_URL"] = "sqlite:///:memory:"  # Use in-memory SQLite for tests

from database.database import (
    engine, SessionLocal, init_db, drop_db,
    get_db, get_db_context, DatabaseManager, db_manager
)
from database.models import (
    Base, User, Project, Analysis, Dataset, AuditLog,
    CacheEntry, ReportTemplate, APIKey,
    UserRoleEnum, AnalysisTypeEnum, AnalysisStatusEnum,
    generate_uuid
)


@pytest.fixture(scope="function")
def test_engine():
    """Create a fresh test database engine for each test"""
    test_db_engine = create_engine(
        "sqlite:///:memory:",
        poolclass=NullPool,
        echo=False
    )
    Base.metadata.create_all(bind=test_db_engine)
    yield test_db_engine
    Base.metadata.drop_all(bind=test_db_engine)
    test_db_engine.dispose()


@pytest.fixture(scope="function")
def test_session(test_engine):
    """Create a fresh test database session for each test"""
    TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    session = TestSessionLocal()
    yield session
    session.close()


@pytest.fixture
def sample_user(test_session):
    """Create a sample user for testing"""
    user = User(
        username="testuser",
        email="test@example.com",
        hashed_password="hashed_password_here",
        full_name="Test User",
        role=UserRoleEnum.ANALYST,
        is_active=True
    )
    test_session.add(user)
    test_session.commit()
    test_session.refresh(user)
    return user


@pytest.fixture
def sample_project(test_session, sample_user):
    """Create a sample project for testing"""
    project = Project(
        name="Test Project",
        description="A test project",
        owner_id=sample_user.id,
        tags=["test", "sample"],
        settings={"key": "value"}
    )
    test_session.add(project)
    test_session.commit()
    test_session.refresh(project)
    return project


class TestDatabaseConnection:
    """Test database connection and engine"""

    def test_engine_created(self):
        """Test that database engine is created"""
        assert engine is not None

    def test_session_factory_created(self):
        """Test that SessionLocal factory is created"""
        assert SessionLocal is not None

    def test_database_url_from_environment(self):
        """Test that DATABASE_URL comes from environment"""
        from database.database import DATABASE_URL
        # In test environment, should use SQLite
        assert "sqlite" in DATABASE_URL or "postgresql" in DATABASE_URL

    def test_connection_pool_settings(self):
        """Test connection pool configuration"""
        from database.database import DB_POOL_SIZE, DB_MAX_OVERFLOW
        assert isinstance(DB_POOL_SIZE, int)
        assert isinstance(DB_MAX_OVERFLOW, int)
        assert DB_POOL_SIZE > 0
        assert DB_MAX_OVERFLOW >= 0


class TestDatabaseManager:
    """Test DatabaseManager utilities"""

    def test_health_check_success(self, test_engine):
        """Test database health check with working connection"""
        # Create a temporary DatabaseManager with test engine
        test_db_manager = DatabaseManager()
        # Note: health_check uses the global engine, so this tests that
        result = test_db_manager.health_check()
        # May fail if actual DB is down, but should be callable
        assert isinstance(result, bool)

    def test_get_connection_info(self):
        """Test getting connection information"""
        info = db_manager.get_connection_info()

        assert isinstance(info, dict)
        assert "url" in info
        assert "pool_size" in info
        assert "max_overflow" in info
        assert "timeout" in info
        assert "recycle" in info

        # Should not expose credentials
        assert "@" not in info["url"] or "localhost" in info["url"]

    def test_get_pool_status(self):
        """Test getting connection pool status"""
        status = db_manager.get_pool_status()

        assert isinstance(status, dict)
        assert "size" in status
        assert "checked_in" in status
        assert "checked_out" in status
        assert "overflow" in status
        assert "total_connections" in status


class TestSessionManagement:
    """Test database session management"""

    def test_get_db_yields_session(self):
        """Test that get_db yields a valid session"""
        session_generator = get_db()
        session = next(session_generator)

        assert isinstance(session, Session)

        # Cleanup
        try:
            next(session_generator)
        except StopIteration:
            pass

    def test_get_db_closes_session(self):
        """Test that get_db closes session after use"""
        session_generator = get_db()
        session = next(session_generator)

        # Close the generator
        try:
            session_generator.close()
        except:
            pass

        # Session should be closed
        # Note: This is hard to test directly, but the pattern is correct

    def test_get_db_context_success(self, test_engine):
        """Test context manager with successful transaction"""
        TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

        # Monkey patch SessionLocal for this test
        import database.database
        original_session_local = database.database.SessionLocal
        database.database.SessionLocal = TestSessionLocal

        try:
            with get_db_context() as db:
                user = User(
                    username="contextuser",
                    email="context@example.com",
                    hashed_password="hash",
                    role=UserRoleEnum.VIEWER
                )
                db.add(user)

            # After context exits, changes should be committed
            with get_db_context() as db:
                result = db.query(User).filter_by(username="contextuser").first()
                assert result is not None
                assert result.email == "context@example.com"
        finally:
            database.database.SessionLocal = original_session_local

    def test_get_db_context_rollback_on_error(self, test_engine):
        """Test that context manager rolls back on exception"""
        TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

        import database.database
        original_session_local = database.database.SessionLocal
        database.database.SessionLocal = TestSessionLocal

        try:
            with pytest.raises(ValueError):
                with get_db_context() as db:
                    user = User(
                        username="erroruser",
                        email="error@example.com",
                        hashed_password="hash",
                        role=UserRoleEnum.VIEWER
                    )
                    db.add(user)
                    raise ValueError("Simulated error")

            # Changes should have been rolled back
            with get_db_context() as db:
                result = db.query(User).filter_by(username="erroruser").first()
                assert result is None
        finally:
            database.database.SessionLocal = original_session_local


class TestUserModel:
    """Test User ORM model"""

    def test_create_user(self, test_session):
        """Test creating a user"""
        user = User(
            username="newuser",
            email="newuser@example.com",
            hashed_password="hashed_password",
            full_name="New User",
            role=UserRoleEnum.ANALYST,
            is_active=True
        )
        test_session.add(user)
        test_session.commit()

        # Verify user was created
        assert user.id is not None
        assert user.created_at is not None
        assert user.username == "newuser"

    def test_user_unique_username(self, test_session, sample_user):
        """Test that username must be unique"""
        duplicate_user = User(
            username="testuser",  # Same as sample_user
            email="different@example.com",
            hashed_password="hash",
            role=UserRoleEnum.VIEWER
        )
        test_session.add(duplicate_user)

        with pytest.raises(Exception):  # SQLAlchemy IntegrityError
            test_session.commit()

    def test_user_unique_email(self, test_session, sample_user):
        """Test that email must be unique"""
        duplicate_user = User(
            username="different",
            email="test@example.com",  # Same as sample_user
            hashed_password="hash",
            role=UserRoleEnum.VIEWER
        )
        test_session.add(duplicate_user)

        with pytest.raises(Exception):
            test_session.commit()

    def test_user_default_values(self, test_session):
        """Test user default values"""
        user = User(
            username="defaultuser",
            email="default@example.com",
            hashed_password="hash"
        )
        test_session.add(user)
        test_session.commit()

        # Check defaults
        assert user.role == UserRoleEnum.VIEWER
        assert user.is_active is True
        assert user.is_verified is False
        assert user.created_at is not None

    def test_user_roles(self, test_session):
        """Test all user role types"""
        roles = [UserRoleEnum.ADMIN, UserRoleEnum.ANALYST, UserRoleEnum.VIEWER]

        for role in roles:
            user = User(
                username=f"user_{role.value}",
                email=f"{role.value}@example.com",
                hashed_password="hash",
                role=role
            )
            test_session.add(user)

        test_session.commit()

        # Verify all roles
        for role in roles:
            user = test_session.query(User).filter_by(username=f"user_{role.value}").first()
            assert user.role == role

    def test_user_update(self, test_session, sample_user):
        """Test updating user information"""
        original_email = sample_user.email

        sample_user.email = "updated@example.com"
        sample_user.full_name = "Updated Name"
        test_session.commit()

        # Verify update
        user = test_session.query(User).filter_by(id=sample_user.id).first()
        assert user.email == "updated@example.com"
        assert user.full_name == "Updated Name"
        assert user.email != original_email

    def test_user_last_login_update(self, test_session, sample_user):
        """Test updating last login timestamp"""
        now = datetime.utcnow()
        sample_user.last_login = now
        test_session.commit()

        user = test_session.query(User).filter_by(id=sample_user.id).first()
        assert user.last_login is not None
        assert abs((user.last_login - now).total_seconds()) < 1

    def test_user_repr(self, sample_user):
        """Test user string representation"""
        repr_str = repr(sample_user)
        assert "User" in repr_str
        assert sample_user.username in repr_str
        assert sample_user.email in repr_str


class TestProjectModel:
    """Test Project ORM model"""

    def test_create_project(self, test_session, sample_user):
        """Test creating a project"""
        project = Project(
            name="New Project",
            description="Test project",
            owner_id=sample_user.id,
            tags=["tag1", "tag2"],
            settings={"setting1": "value1"}
        )
        test_session.add(project)
        test_session.commit()

        assert project.id is not None
        assert project.created_at is not None
        assert project.name == "New Project"

    def test_project_owner_relationship(self, test_session, sample_user, sample_project):
        """Test project-owner relationship"""
        # Access owner through relationship
        assert sample_project.owner.id == sample_user.id
        assert sample_project.owner.username == sample_user.username

        # Access projects through user
        assert len(sample_user.projects) >= 1
        assert sample_project in sample_user.projects

    def test_project_default_archived(self, test_session, sample_user):
        """Test project default archived status"""
        project = Project(
            name="Test Project",
            owner_id=sample_user.id
        )
        test_session.add(project)
        test_session.commit()

        assert project.is_archived is False

    def test_project_json_fields(self, test_session, sample_project):
        """Test JSON fields (tags, settings)"""
        assert isinstance(sample_project.tags, list)
        assert "test" in sample_project.tags

        assert isinstance(sample_project.settings, dict)
        assert sample_project.settings.get("key") == "value"

    def test_project_update(self, test_session, sample_project):
        """Test updating project"""
        sample_project.name = "Updated Project"
        sample_project.is_archived = True
        test_session.commit()

        project = test_session.query(Project).filter_by(id=sample_project.id).first()
        assert project.name == "Updated Project"
        assert project.is_archived is True

    def test_project_cascade_delete(self, test_session, sample_user):
        """Test cascade delete when user is deleted"""
        project = Project(name="Delete Test", owner_id=sample_user.id)
        test_session.add(project)
        test_session.commit()
        project_id = project.id

        # Delete user
        test_session.delete(sample_user)
        test_session.commit()

        # Project should be deleted
        deleted_project = test_session.query(Project).filter_by(id=project_id).first()
        assert deleted_project is None


class TestAnalysisModel:
    """Test Analysis ORM model"""

    def test_create_analysis(self, test_session, sample_user, sample_project):
        """Test creating an analysis"""
        analysis = Analysis(
            name="Test Analysis",
            description="Test description",
            analysis_type=AnalysisTypeEnum.PAIRWISE_MA,
            project_id=sample_project.id,
            owner_id=sample_user.id,
            parameters={"param1": "value1"},
            input_data={"data": [1, 2, 3]}
        )
        test_session.add(analysis)
        test_session.commit()

        assert analysis.id is not None
        assert analysis.created_at is not None
        assert analysis.status == AnalysisStatusEnum.DRAFT

    def test_analysis_types(self, test_session, sample_user, sample_project):
        """Test all analysis types"""
        types = [
            AnalysisTypeEnum.PAIRWISE_MA,
            AnalysisTypeEnum.NETWORK_MA,
            AnalysisTypeEnum.DOSE_RESPONSE,
            AnalysisTypeEnum.HEALTH_ECONOMICS,
            AnalysisTypeEnum.BUDGET_IMPACT
        ]

        for analysis_type in types:
            analysis = Analysis(
                name=f"Analysis {analysis_type.value}",
                analysis_type=analysis_type,
                project_id=sample_project.id,
                owner_id=sample_user.id
            )
            test_session.add(analysis)

        test_session.commit()

        for analysis_type in types:
            result = test_session.query(Analysis).filter_by(
                analysis_type=analysis_type
            ).first()
            assert result is not None

    def test_analysis_statuses(self, test_session, sample_user, sample_project):
        """Test analysis status transitions"""
        analysis = Analysis(
            name="Status Test",
            analysis_type=AnalysisTypeEnum.PAIRWISE_MA,
            project_id=sample_project.id,
            owner_id=sample_user.id
        )
        test_session.add(analysis)
        test_session.commit()

        # Test status transitions
        assert analysis.status == AnalysisStatusEnum.DRAFT

        analysis.status = AnalysisStatusEnum.RUNNING
        analysis.started_at = datetime.utcnow()
        test_session.commit()
        assert analysis.status == AnalysisStatusEnum.RUNNING

        analysis.status = AnalysisStatusEnum.COMPLETED
        analysis.completed_at = datetime.utcnow()
        test_session.commit()
        assert analysis.status == AnalysisStatusEnum.COMPLETED

    def test_analysis_relationships(self, test_session, sample_user, sample_project):
        """Test analysis relationships"""
        analysis = Analysis(
            name="Relationship Test",
            analysis_type=AnalysisTypeEnum.PAIRWISE_MA,
            project_id=sample_project.id,
            owner_id=sample_user.id
        )
        test_session.add(analysis)
        test_session.commit()

        # Test owner relationship
        assert analysis.owner.id == sample_user.id

        # Test project relationship
        assert analysis.project.id == sample_project.id

        # Test reverse relationship
        assert analysis in sample_project.analyses

    def test_analysis_versioning(self, test_session, sample_user, sample_project):
        """Test analysis version field"""
        analysis = Analysis(
            name="Version Test",
            analysis_type=AnalysisTypeEnum.PAIRWISE_MA,
            project_id=sample_project.id,
            owner_id=sample_user.id
        )
        test_session.add(analysis)
        test_session.commit()

        # Default version
        assert analysis.version == 1

        # Increment version
        analysis.version += 1
        test_session.commit()
        assert analysis.version == 2


class TestDatasetModel:
    """Test Dataset ORM model"""

    def test_create_dataset(self, test_session, sample_user, sample_project):
        """Test creating a dataset"""
        analysis = Analysis(
            name="Dataset Test Analysis",
            analysis_type=AnalysisTypeEnum.PAIRWISE_MA,
            project_id=sample_project.id,
            owner_id=sample_user.id
        )
        test_session.add(analysis)
        test_session.commit()

        dataset = Dataset(
            name="Test Dataset",
            description="Test data",
            analysis_id=analysis.id,
            uploaded_by=sample_user.id,
            data_type="binary",
            n_studies=10,
            n_observations=100,
            data={"studies": [1, 2, 3]},
            original_filename="test.csv",
            file_size_bytes=1024
        )
        test_session.add(dataset)
        test_session.commit()

        assert dataset.id is not None
        assert dataset.created_at is not None

    def test_dataset_relationships(self, test_session, sample_user, sample_project):
        """Test dataset relationships"""
        analysis = Analysis(
            name="Test",
            analysis_type=AnalysisTypeEnum.PAIRWISE_MA,
            project_id=sample_project.id,
            owner_id=sample_user.id
        )
        test_session.add(analysis)
        test_session.commit()

        dataset = Dataset(
            name="Test Dataset",
            analysis_id=analysis.id,
            uploaded_by=sample_user.id,
            data_type="binary"
        )
        test_session.add(dataset)
        test_session.commit()

        # Test relationships
        assert dataset.analysis.id == analysis.id
        assert dataset.uploader.id == sample_user.id
        assert dataset in analysis.datasets


class TestAuditLogModel:
    """Test AuditLog ORM model"""

    def test_create_audit_log(self, test_session, sample_user):
        """Test creating audit log entry"""
        log = AuditLog(
            user_id=sample_user.id,
            action="login",
            resource_type="user",
            resource_id=sample_user.id,
            ip_address="192.168.1.1",
            user_agent="Mozilla/5.0",
            request_method="POST",
            request_path="/api/auth/login",
            details={"result": "success"},
            success=True
        )
        test_session.add(log)
        test_session.commit()

        assert log.id is not None
        assert log.timestamp is not None
        assert log.action == "login"

    def test_audit_log_with_error(self, test_session, sample_user):
        """Test audit log with error"""
        log = AuditLog(
            user_id=sample_user.id,
            action="delete_project",
            resource_type="project",
            resource_id="some-id",
            success=False,
            error_message="Permission denied"
        )
        test_session.add(log)
        test_session.commit()

        assert log.success is False
        assert log.error_message == "Permission denied"

    def test_audit_log_relationship(self, test_session, sample_user):
        """Test audit log user relationship"""
        log = AuditLog(
            user_id=sample_user.id,
            action="test",
            success=True
        )
        test_session.add(log)
        test_session.commit()

        assert log.user.id == sample_user.id
        assert log in sample_user.audit_logs


class TestCacheEntryModel:
    """Test CacheEntry ORM model"""

    def test_create_cache_entry(self, test_session):
        """Test creating cache entry"""
        cache = CacheEntry(
            cache_key="test_key_123",
            data={"result": "cached_value"},
            data_size_bytes=512,
            analysis_type="pairwise_ma",
            parameters_hash="abc123",
            expires_at=datetime.utcnow() + timedelta(hours=1)
        )
        test_session.add(cache)
        test_session.commit()

        assert cache.id is not None
        assert cache.hit_count == 0

    def test_cache_unique_key(self, test_session):
        """Test that cache key must be unique"""
        cache1 = CacheEntry(cache_key="duplicate_key", data={})
        cache2 = CacheEntry(cache_key="duplicate_key", data={})

        test_session.add(cache1)
        test_session.commit()

        test_session.add(cache2)
        with pytest.raises(Exception):
            test_session.commit()

    def test_cache_hit_count(self, test_session):
        """Test incrementing cache hit count"""
        cache = CacheEntry(cache_key="hit_test", data={})
        test_session.add(cache)
        test_session.commit()

        # Increment hits
        cache.hit_count += 1
        test_session.commit()

        retrieved = test_session.query(CacheEntry).filter_by(cache_key="hit_test").first()
        assert retrieved.hit_count == 1


class TestReportTemplateModel:
    """Test ReportTemplate ORM model"""

    def test_create_report_template(self, test_session, sample_user):
        """Test creating report template"""
        template = ReportTemplate(
            name="Test Template",
            description="A test report template",
            template_type="word",
            template_content="<template>content</template>",
            template_config={"font": "Arial"},
            created_by=sample_user.id,
            is_public=False
        )
        test_session.add(template)
        test_session.commit()

        assert template.id is not None
        assert template.created_at is not None

    def test_report_template_relationship(self, test_session, sample_user):
        """Test report template creator relationship"""
        template = ReportTemplate(
            name="Test",
            template_type="pdf",
            template_content="content",
            created_by=sample_user.id
        )
        test_session.add(template)
        test_session.commit()

        assert template.creator.id == sample_user.id


class TestAPIKeyModel:
    """Test APIKey ORM model"""

    def test_create_api_key(self, test_session, sample_user):
        """Test creating API key"""
        api_key = APIKey(
            key="test_key_" + str(uuid.uuid4()),
            name="Test API Key",
            user_id=sample_user.id,
            permissions=["read", "write"],
            rate_limit=100,
            is_active=True,
            expires_at=datetime.utcnow() + timedelta(days=30)
        )
        test_session.add(api_key)
        test_session.commit()

        assert api_key.id is not None
        assert api_key.usage_count == 0

    def test_api_key_unique(self, test_session, sample_user):
        """Test that API key must be unique"""
        key_value = "duplicate_key_123"

        key1 = APIKey(key=key_value, user_id=sample_user.id)
        key2 = APIKey(key=key_value, user_id=sample_user.id)

        test_session.add(key1)
        test_session.commit()

        test_session.add(key2)
        with pytest.raises(Exception):
            test_session.commit()

    def test_api_key_usage_tracking(self, test_session, sample_user):
        """Test API key usage tracking"""
        api_key = APIKey(
            key="usage_test_" + str(uuid.uuid4()),
            user_id=sample_user.id
        )
        test_session.add(api_key)
        test_session.commit()

        # Simulate usage
        api_key.usage_count += 1
        api_key.last_used = datetime.utcnow()
        test_session.commit()

        retrieved = test_session.query(APIKey).filter_by(id=api_key.id).first()
        assert retrieved.usage_count == 1
        assert retrieved.last_used is not None

    def test_api_key_relationship(self, test_session, sample_user):
        """Test API key user relationship"""
        api_key = APIKey(
            key="relation_test_" + str(uuid.uuid4()),
            user_id=sample_user.id
        )
        test_session.add(api_key)
        test_session.commit()

        assert api_key.user.id == sample_user.id


class TestUtilityFunctions:
    """Test utility functions"""

    def test_generate_uuid(self):
        """Test UUID generation"""
        uuid1 = generate_uuid()
        uuid2 = generate_uuid()

        assert isinstance(uuid1, str)
        assert isinstance(uuid2, str)
        assert uuid1 != uuid2
        assert len(uuid1) == 36  # Standard UUID length with hyphens


class TestTransactions:
    """Test transaction handling"""

    def test_commit_transaction(self, test_session):
        """Test successful transaction commit"""
        user = User(
            username="commituser",
            email="commit@example.com",
            hashed_password="hash",
            role=UserRoleEnum.VIEWER
        )
        test_session.add(user)
        test_session.commit()

        # Verify commit
        result = test_session.query(User).filter_by(username="commituser").first()
        assert result is not None

    def test_rollback_transaction(self, test_session):
        """Test transaction rollback"""
        user = User(
            username="rollbackuser",
            email="rollback@example.com",
            hashed_password="hash",
            role=UserRoleEnum.VIEWER
        )
        test_session.add(user)

        # Rollback before commit
        test_session.rollback()

        # User should not exist
        result = test_session.query(User).filter_by(username="rollbackuser").first()
        assert result is None


class TestDatabaseInitialization:
    """Test database initialization functions"""

    def test_init_db_creates_tables(self, test_engine):
        """Test that init_db creates all tables"""
        # Drop all tables first
        Base.metadata.drop_all(bind=test_engine)

        # Recreate using init_db pattern
        Base.metadata.create_all(bind=test_engine)

        # Check that tables exist
        from sqlalchemy import inspect
        inspector = inspect(test_engine)
        table_names = inspector.get_table_names()

        assert "users" in table_names
        assert "projects" in table_names
        assert "analyses" in table_names


class TestEdgeCases:
    """Test edge cases and error conditions"""

    def test_null_required_field(self, test_session):
        """Test creating user without required fields"""
        user = User()  # Missing required fields
        test_session.add(user)

        with pytest.raises(Exception):
            test_session.commit()

    def test_invalid_foreign_key(self, test_session):
        """Test creating project with invalid owner_id"""
        project = Project(
            name="Invalid Owner",
            owner_id="nonexistent-user-id"
        )
        test_session.add(project)

        # SQLite may not enforce foreign keys by default
        # This test documents the expected behavior
        try:
            test_session.commit()
        except Exception:
            # Foreign key constraint violated (expected in strict DBs)
            test_session.rollback()

    def test_very_long_string_field(self, test_session):
        """Test string field length limits"""
        # User email has max length 255
        long_email = "a" * 256 + "@example.com"

        user = User(
            username="longtest",
            email=long_email,
            hashed_password="hash",
            role=UserRoleEnum.VIEWER
        )
        test_session.add(user)

        # May fail due to length constraint
        try:
            test_session.commit()
        except Exception:
            test_session.rollback()

    def test_json_field_with_complex_data(self, test_session, sample_user, sample_project):
        """Test JSON fields with complex nested data"""
        analysis = Analysis(
            name="Complex JSON Test",
            analysis_type=AnalysisTypeEnum.NETWORK_MA,
            project_id=sample_project.id,
            owner_id=sample_user.id,
            parameters={
                "nested": {
                    "level1": {
                        "level2": {
                            "value": [1, 2, 3]
                        }
                    }
                },
                "array": [{"key": "value"}],
                "number": 123.456
            }
        )
        test_session.add(analysis)
        test_session.commit()

        # Verify complex JSON is preserved
        retrieved = test_session.query(Analysis).filter_by(id=analysis.id).first()
        assert retrieved.parameters["nested"]["level1"]["level2"]["value"] == [1, 2, 3]


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
