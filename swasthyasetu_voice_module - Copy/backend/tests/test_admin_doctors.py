"""
Tests for admin-only doctor account management: creating, listing, and
activating/deactivating doctor_users rows. Mirrors the fixture pattern in
test_auth.py (isolated in-memory SQLite DB), but seeds both a plain "doctor"
and an "admin" account so role-gating can be exercised.
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

    db = TestingSessionLocal()
    db.add(
        DoctorUser(
            name="Dr. Test",
            username="dr.test",
            hashed_password=hash_password("secretpw"),
            role="doctor",
        )
    )
    db.add(
        DoctorUser(
            name="Admin Test",
            username="admin.test",
            hashed_password=hash_password("adminpw123"),
            role="admin",
        )
    )
    db.commit()
    db.close()

    with TestClient(app_main.app) as test_client:
        yield test_client

    app_main.app.dependency_overrides.clear()


def _token(client, username, password):
    response = client.post("/api/v1/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200
    return response.json()["access_token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_doctor_cannot_create_doctor(client):
    token = _token(client, "dr.test", "secretpw")
    response = client.post(
        "/api/v1/admin/doctors",
        headers=_auth(token),
        json={"name": "Dr. New", "username": "dr.new", "password": "newpassword"},
    )
    assert response.status_code == 403


def test_admin_can_create_doctor(client):
    token = _token(client, "admin.test", "adminpw123")
    response = client.post(
        "/api/v1/admin/doctors",
        headers=_auth(token),
        json={
            "name": "Dr. New",
            "username": "dr.new",
            "password": "newpassword",
            "speciality": "Pediatrics",
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["username"] == "dr.new"
    assert body["role"] == "doctor"
    assert body["is_active"] is True

    # The new account can immediately log in.
    login = client.post("/api/v1/auth/login", json={"username": "dr.new", "password": "newpassword"})
    assert login.status_code == 200


def test_admin_can_create_another_admin(client):
    token = _token(client, "admin.test", "adminpw123")
    response = client.post(
        "/api/v1/admin/doctors",
        headers=_auth(token),
        json={"name": "Second Admin", "username": "admin.two", "password": "adminpw456", "role": "admin"},
    )
    assert response.status_code == 201
    assert response.json()["role"] == "admin"


def test_create_doctor_rejects_duplicate_username(client):
    token = _token(client, "admin.test", "adminpw123")
    response = client.post(
        "/api/v1/admin/doctors",
        headers=_auth(token),
        json={"name": "Dupe", "username": "dr.test", "password": "somepassword"},
    )
    assert response.status_code == 409


def test_create_doctor_rejects_short_password(client):
    token = _token(client, "admin.test", "adminpw123")
    response = client.post(
        "/api/v1/admin/doctors",
        headers=_auth(token),
        json={"name": "Short PW", "username": "dr.short", "password": "short"},
    )
    assert response.status_code == 400


def test_create_doctor_requires_auth(client):
    response = client.post(
        "/api/v1/admin/doctors",
        json={"name": "No Auth", "username": "dr.noauth", "password": "somepassword"},
    )
    assert response.status_code == 401


def test_admin_can_list_doctors(client):
    token = _token(client, "admin.test", "adminpw123")
    response = client.get("/api/v1/admin/doctors", headers=_auth(token))
    assert response.status_code == 200
    usernames = {d["username"] for d in response.json()}
    assert {"dr.test", "admin.test"} <= usernames


def test_doctor_cannot_list_doctors(client):
    token = _token(client, "dr.test", "secretpw")
    response = client.get("/api/v1/admin/doctors", headers=_auth(token))
    assert response.status_code == 403


def test_admin_can_deactivate_and_reactivate_doctor(client):
    admin_token = _token(client, "admin.test", "adminpw123")
    create = client.post(
        "/api/v1/admin/doctors",
        headers=_auth(admin_token),
        json={"name": "Toggle Me", "username": "dr.toggle", "password": "togglepass"},
    )
    doctor_id = create.json()["id"]

    deactivate = client.patch(
        f"/api/v1/admin/doctors/{doctor_id}/status",
        headers=_auth(admin_token),
        json={"is_active": False},
    )
    assert deactivate.status_code == 200
    assert deactivate.json()["is_active"] is False

    # Deactivated account can no longer log in.
    login = client.post("/api/v1/auth/login", json={"username": "dr.toggle", "password": "togglepass"})
    assert login.status_code == 403

    reactivate = client.patch(
        f"/api/v1/admin/doctors/{doctor_id}/status",
        headers=_auth(admin_token),
        json={"is_active": True},
    )
    assert reactivate.status_code == 200
    assert reactivate.json()["is_active"] is True


def test_admin_cannot_deactivate_self(client):
    admin_token = _token(client, "admin.test", "adminpw123")
    me = client.get("/api/v1/auth/me", headers=_auth(admin_token))
    admin_id = me.json()["id"]

    response = client.patch(
        f"/api/v1/admin/doctors/{admin_id}/status",
        headers=_auth(admin_token),
        json={"is_active": False},
    )
    assert response.status_code == 400
