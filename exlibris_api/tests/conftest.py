from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from main import app
from core.database import get_db_connection


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def unique_email() -> str:
    return f"test_{uuid.uuid4().hex[:10]}@example.com"


@pytest.fixture
def cleanup_test_user():
    """
    Fournit une fonction utilitaire pour supprimer un utilisateur de test par email.
    """
    def _cleanup(email: str) -> None:
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute("SELECT id_utilisateur FROM Utilisateur WHERE email = %s", (email,))
            row = cur.fetchone()
            if row:
                user_id = row[0]
                cur.execute("DELETE FROM Utilisateur WHERE id_utilisateur = %s", (user_id,))
                conn.commit()
        finally:
            conn.close()

    return _cleanup


@pytest.fixture
def confirmed_user(client: TestClient, unique_email: str, cleanup_test_user):
    """
    Crée un utilisateur confirmé prêt à être utilisé dans les tests.
    """
    email = unique_email
    password = "test1234"
    username = "pytest_user"

    try:
        signup_resp = client.post(
            "/auth/signup",
            json={
                "email": email,
                "nom_utilisateur": username,
                "mot_de_passe": password,
            },
        )
        assert signup_resp.status_code == 200, signup_resp.text

        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                """
                SELECT u.id_utilisateur, ev.code
                FROM Utilisateur u
                JOIN email_verification ev ON ev.user_id = u.id_utilisateur
                WHERE u.email = %s
                ORDER BY ev.created_at DESC
                LIMIT 1
                """,
                (email,),
            )
            row = cur.fetchone()
            assert row is not None
            user_id, code = row
        finally:
            conn.close()

        confirm_resp = client.post(
            "/auth/confirm",
            json={
                "email": email,
                "code": code,
            },
        )
        assert confirm_resp.status_code == 200, confirm_resp.text

        login_resp = client.post(
            "/auth/login",
            json={
                "email": email,
                "mot_de_passe": password,
            },
        )
        assert login_resp.status_code == 200, login_resp.text
        token = login_resp.json()["token"]

        yield {
            "email": email,
            "password": password,
            "username": username,
            "user_id": user_id,
            "token": token,
            "auth_headers": {"Authorization": f"Bearer {token}"},
        }

    finally:
        cleanup_test_user(email)