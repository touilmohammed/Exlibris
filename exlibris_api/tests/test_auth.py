from core.database import get_db_connection


def test_signup_success(client, unique_email, cleanup_test_user):
    email = unique_email

    try:
        response = client.post(
            "/auth/signup",
            json={
                "email": email,
                "nom_utilisateur": "auth_test_user",
                "mot_de_passe": "test1234",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["ok"] is True
        assert "user_id" in data

        conn = get_db_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                """
                SELECT email, mot_de_passe_hash, email_verifie
                FROM Utilisateur
                WHERE email = %s
                """,
                (email,),
            )
            row = cur.fetchone()
            assert row is not None
            assert row[0] == email
            assert row[1] is not None
            assert row[1] != ""
            assert int(row[2]) == 0
        finally:
            conn.close()

    finally:
        cleanup_test_user(email)


def test_signup_duplicate_email(client, unique_email, cleanup_test_user):
    email = unique_email

    try:
        first = client.post(
            "/auth/signup",
            json={
                "email": email,
                "nom_utilisateur": "dup_user_1",
                "mot_de_passe": "test1234",
            },
        )
        assert first.status_code == 200

        second = client.post(
            "/auth/signup",
            json={
                "email": email,
                "nom_utilisateur": "dup_user_2",
                "mot_de_passe": "test1234",
            },
        )
        assert second.status_code == 409
        assert second.json()["detail"] == "Email déjà utilisé"

    finally:
        cleanup_test_user(email)


def test_login_rejects_wrong_password(client, confirmed_user):
    response = client.post(
        "/auth/login",
        json={
            "email": confirmed_user["email"],
            "mot_de_passe": "wrong_password",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Identifiants invalides"


def test_login_success_returns_token(client, confirmed_user):
    response = client.post(
        "/auth/login",
        json={
            "email": confirmed_user["email"],
            "mot_de_passe": confirmed_user["password"],
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert data["user_id"] == confirmed_user["user_id"]


def test_protected_profile_requires_token(client):
    response = client.get("/me/profile")
    assert response.status_code == 401
    assert response.json()["detail"] == "Token manquant"


def test_protected_profile_with_valid_token(client, confirmed_user):
    response = client.get("/me/profile", headers=confirmed_user["auth_headers"])
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == confirmed_user["email"]
    assert data["id"] == confirmed_user["user_id"]