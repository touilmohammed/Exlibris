import uuid

from core.database import get_db_connection
from services.notification_service import notification_manager


def _create_confirmed_user(client, email: str) -> dict:
    password = "test1234"
    username = "pytest_user"

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

    return {
        "email": email,
        "password": password,
        "username": username,
        "user_id": user_id,
        "token": token,
        "auth_headers": {"Authorization": f"Bearer {token}"},
    }


def _clear_notifications(user_id: int) -> None:
    notification_manager._notifications.pop(user_id, None)
    notification_manager._connections.pop(user_id, None)


def test_notifications_empty(client, cleanup_test_user):
    email = f"test_{uuid.uuid4().hex[:10]}@example.com"

    try:
        user = _create_confirmed_user(client, email)
        _clear_notifications(user["user_id"])

        resp = client.get("/notifications/me", headers=user["auth_headers"])
        assert resp.status_code == 200
        assert resp.json() == []

    finally:
        cleanup_test_user(email)


def test_friend_request_creates_notification(client, cleanup_test_user):
    email_a = f"test_{uuid.uuid4().hex[:10]}@example.com"
    email_b = f"test_{uuid.uuid4().hex[:10]}@example.com"

    try:
        user_a = _create_confirmed_user(client, email_a)
        user_b = _create_confirmed_user(client, email_b)

        _clear_notifications(user_b["user_id"])

        send_resp = client.post(
            f"/friends/requests/{user_b['user_id']}",
            headers=user_a["auth_headers"],
        )
        assert send_resp.status_code == 200, send_resp.text

        notif_resp = client.get(
            "/notifications/me",
            headers=user_b["auth_headers"],
        )
        assert notif_resp.status_code == 200, notif_resp.text
        items = notif_resp.json()
        assert items, "Notification attendue"

        last_item = items[-1]
        assert last_item["type"] == "friend_request"
        assert last_item["data"]["from_user_id"] == user_a["user_id"]

    finally:
        cleanup_test_user(email_a)
        cleanup_test_user(email_b)


def test_notifications_ws_init(client, cleanup_test_user):
    email_a = f"test_{uuid.uuid4().hex[:10]}@example.com"
    email_b = f"test_{uuid.uuid4().hex[:10]}@example.com"

    try:
        user_a = _create_confirmed_user(client, email_a)
        user_b = _create_confirmed_user(client, email_b)

        _clear_notifications(user_b["user_id"])

        send_resp = client.post(
            f"/friends/requests/{user_b['user_id']}",
            headers=user_a["auth_headers"],
        )
        assert send_resp.status_code == 200, send_resp.text

        with client.websocket_connect(
            f"/notifications/ws?token={user_b['token']}"
        ) as websocket:
            payload = websocket.receive_json()
            assert payload["event"] == "init"
            items = payload["items"]
            assert items, "Notification attendue"
            assert items[-1]["type"] == "friend_request"

    finally:
        cleanup_test_user(email_a)
        cleanup_test_user(email_b)
