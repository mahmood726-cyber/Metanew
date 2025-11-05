"""
Shared Test Fixtures and Configuration
Session-scoped fixtures to prevent rate limiting across test modules
"""
import pytest
import os
from fastapi.testclient import TestClient

# Set test environment variables before any imports
os.environ["ENVIRONMENT"] = "test"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-for-testing-only-do-not-use-in-production"
os.environ["ADMIN_INITIAL_PASSWORD"] = "test-admin-password"
os.environ["ANALYST_INITIAL_PASSWORD"] = "test-analyst-password"
os.environ["DATABASE_URL"] = "sqlite:///:memory:"

from api.main import app


@pytest.fixture(scope="session")
def session_client():
    """
    Session-scoped test client
    Shared across all test modules to prevent rate limiting
    """
    return TestClient(app)


@pytest.fixture(scope="session")
def session_admin_token(session_client):
    """
    Session-scoped admin authentication token
    Shared across all test modules to prevent rate limiting (5/min limit)
    """
    response = session_client.post(
        "/api/auth/login/oauth",
        data={"username": "admin", "password": "test-admin-password"}
    )
    if response.status_code != 200:
        pytest.skip(f"Unable to authenticate admin user: {response.status_code}")
    return response.json()["access_token"]


@pytest.fixture(scope="session")
def session_auth_headers(session_admin_token):
    """
    Session-scoped authentication headers
    Shared across all test modules to prevent rate limiting
    """
    return {"Authorization": f"Bearer {session_admin_token}"}
