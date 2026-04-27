from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect, status

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


@router.get("/me", response_model=list[NotificationOut])
def list_my_notifications(
    limit: int = Query(default=50, le=200),
    current_user_id: int = Depends(get_current_user_id),
):
    return notification_manager.list_notifications(current_user_id, limit)


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
