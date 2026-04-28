from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect, status

from core.database import get_db_connection
from core.security import decode_access_token
from dependencies.auth import get_current_user_id
from schemas.notification import NotificationOut
from services.notification_service import notification_manager

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _get_user_id_from_websocket(websocket: WebSocket) -> int:
    token = websocket.query_params.get("token")

    if not token:
        auth_header = websocket.headers.get("authorization")
        if auth_header and auth_header.lower().startswith("bearer "):
            token = auth_header[7:]

    if not token:
        raise ValueError("missing_token")

    payload = decode_access_token(token)
    user_id_raw = payload.get("sub")
    if user_id_raw is None:
        raise ValueError("invalid_token")

    return int(user_id_raw)


def _suggestion_has_reason_column(cur) -> bool:
    cur.execute("SHOW COLUMNS FROM Suggestion LIKE 'raison'")
    return cur.fetchone() is not None


def _book_suggestion_notification_id(suggestion_id: int, created_at) -> str:
    created_key = created_at.strftime("%Y%m%d%H%M%S")
    return f"book-suggestion-{suggestion_id}-{created_key}"


def _list_book_suggestion_notifications(user_id: int, limit: int) -> list[dict]:
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        has_reason = _suggestion_has_reason_column(cur)
        reason_select = "COALESCE(s.raison, '')" if has_reason else "''"
        cur.execute(
            f"""
            SELECT
                s.id_suggestion,
                s.expediteur_id,
                u.nom_utilisateur,
                l.isbn,
                l.titre,
                COALESCE(l.auteur, ''),
                l.image_petite,
                {reason_select},
                s.date_suggestion
            FROM Suggestion s
            JOIN Utilisateur u ON u.id_utilisateur = s.expediteur_id
            JOIN Livre l ON l.isbn = s.livre_isbn
            WHERE s.destinataire_id = %s
              AND s.acceptee = 0
            ORDER BY s.date_suggestion DESC
            LIMIT %s
            """,
            (user_id, limit),
        )
        rows = cur.fetchall()
    finally:
        conn.close()

    notifications = []
    for row in rows:
        (
            suggestion_id,
            friend_id,
            friend_name,
            isbn,
            book_title,
            book_author,
            book_image,
            reason,
            created_at,
        ) = row

        reason = (reason or "").strip()
        notifications.append(
            {
                "id": _book_suggestion_notification_id(suggestion_id, created_at),
                "type": "book_suggestion",
                "title": f"{friend_name} te suggère un livre",
                "message": reason
                or f"{friend_name} pense que ce livre pourrait te plaire.",
                "data": {
                    "friend_id": friend_id,
                    "friend_name": friend_name,
                    "suggestion_id": suggestion_id,
                    "isbn": str(isbn),
                    "book_title": book_title,
                    "book_author": book_author,
                    "book_image": book_image,
                    "reason": reason,
                },
                "created_at": created_at.isoformat(),
            }
        )

    return notifications


@router.get("/me", response_model=list[NotificationOut])
def list_my_notifications(
    limit: int = Query(default=50, le=200),
    current_user_id: int = Depends(get_current_user_id),
):
    notifications = notification_manager.list_notifications(current_user_id, limit)
    notifications.extend(_list_book_suggestion_notifications(current_user_id, limit))

    by_id = {notification["id"]: notification for notification in notifications}
    return sorted(
        by_id.values(),
        key=lambda notification: notification["created_at"],
        reverse=True,
    )[:limit]


@router.websocket("/ws")
async def notifications_ws(websocket: WebSocket):
    try:
        user_id = _get_user_id_from_websocket(websocket)
    except Exception:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await notification_manager.connect(user_id, websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        notification_manager.disconnect(user_id, websocket)
