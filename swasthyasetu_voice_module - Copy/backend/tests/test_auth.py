"""
Tests for doctor/dashboard authentication: login issues a JWT, admin
endpoints reject requests without a valid token, and accept requests with
one. Uses an isolated in-memory SQLite DB so it doesn't touch the dev DB
file used by `python -m app.main` / seed_demo_data.py.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

from app.database.database import Base, get_db
from app.models.models import DoctorUser
from app.utils.security import hash_password
import app.main as app_main


@pytest.fixture()
def client():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app_main.app.dependency_overrides[get_db] = override_get_db

    # Seed one doctor account directly, bypassing the HTTP layer.
    db = TestingSessionLocal()
    db.add(
        DoctorUser(
            name="Dr. Test",
            username="dr.test",
            hashed_password=hash_password("secretpw"),
            role="doctor",
        )
    )
    db.commit()
    db.close()

    with TestClient(app_main.app) as test_client:
        yield test_client

    app_main.app.dependency_overrides.clear()


def test_login_with_correct_credentials_returns_token(client):
    response = client.post("/api/v1/auth/login", json={"username": "dr.test", "password": "secretpw"})
    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["doctor"]["username"] == "dr.test"
    assert body["doctor"]["role"] == "doctor"


def test_login_with_wrong_password_is_rejected(client):
    response = client.post("/api/v1/auth/login", json={"username": "dr.test", "password": "wrong"})
    assert response.status_code == 401


def test_login_with_unknown_username_is_rejected(client):
    response = client.post("/api/v1/auth/login", json={"username": "nobody", "password": "secretpw"})
    assert response.status_code == 401


def test_admin_endpoint_requires_auth(client):
    response = client.get("/api/v1/admin/dashboard")
    assert response.status_code == 401


def test_admin_endpoint_accepts_valid_token(client):
    login = client.post("/api/v1/auth/login", json={"username": "dr.test", "password": "secretpw"})
    token = login.json()["access_token"]
    response = client.get("/api/v1/admin/dashboard", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200


def test_me_endpoint_returns_current_doctor(client):
    login = client.post("/api/v1/auth/login", json={"username": "dr.test", "password": "secretpw"})
    token = login.json()["access_token"]
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["username"] == "dr.test"
