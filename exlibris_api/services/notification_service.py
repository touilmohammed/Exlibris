import asyncio
import logging
import threading
from datetime import datetime, timezone
from typing import Callable, Iterable, TypedDict
from uuid import uuid4

import anyio
from fastapi import WebSocket

NotificationDataValue = str | int | float | bool | None
NotificationData = dict[str, NotificationDataValue]


class NotificationPayload(TypedDict):
    id: str
    type: str
    title: str
    message: str
    data: NotificationData
    created_at: str

logger = logging.getLogger(__name__)

MAX_NOTIFICATIONS_PER_USER = 200


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def create_notification(
    *,
    event_type: str,
    title: str,
    message: str,
    data: NotificationData | None = None,
) -> NotificationPayload:
    return {
        "id": str(uuid4()),
        "type": event_type,
        "title": title,
        "message": message,
        "data": data or {},
        "created_at": _utc_now_iso(),
    }


class NotificationManager:
    def __init__(self) -> None:
        self._connections: dict[int, set[WebSocket]] = {}
        self._notifications: dict[int, list[NotificationPayload]] = {}
        self._lock = threading.Lock()

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        with self._lock:
            self._connections.setdefault(user_id, set()).add(websocket)
            existing = list(self._notifications.get(user_id, []))

        await websocket.send_json({"event": "init", "items": existing})

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        with self._lock:
            connections = self._connections.get(user_id)
            if not connections:
                return
            connections.discard(websocket)
            if not connections:
                self._connections.pop(user_id, None)

    def list_notifications(
        self,
        user_id: int,
        limit: int | None = None,
    ) -> list[NotificationPayload]:
        with self._lock:
            items = list(self._notifications.get(user_id, []))
        if limit is None:
            return items
        return items[-limit:]

    def _add_notification(
        self,
        user_id: int,
        notification: NotificationPayload,
    ) -> None:
        items = self._notifications.setdefault(user_id, [])
        items.append(notification)
        if len(items) > MAX_NOTIFICATIONS_PER_USER:
            del items[:-MAX_NOTIFICATIONS_PER_USER]

    def store(self, user_id: int, notification: NotificationPayload) -> None:
        with self._lock:
            self._add_notification(user_id, notification)

    async def push(
        self,
        user_id: int,
        notification: NotificationPayload,
    ) -> None:
        with self._lock:
            self._add_notification(user_id, notification)
            connections = list(self._connections.get(user_id, set()))

        if not connections:
            return

        payload = {"event": "notification", "item": notification}

        for websocket in connections:
            try:
                await websocket.send_json(payload)
            except Exception:
                self.disconnect(user_id, websocket)


notification_manager = NotificationManager()


def notify_user(
    user_id: int,
    notification: NotificationPayload,
) -> None:
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        try:
            anyio.from_thread.run(notification_manager.push, user_id, notification)
        except Exception:
            notification_manager.store(user_id, notification)
            logger.warning("Failed to push notification", exc_info=True)
        return

    try:
        loop.create_task(notification_manager.push(user_id, notification))
    except Exception:
        notification_manager.store(user_id, notification)
        logger.warning("Failed to schedule notification", exc_info=True)


def notify_users(
    user_ids: Iterable[int],
    notification_factory: Callable[[int], NotificationPayload],
) -> None:
    for user_id in user_ids:
        notification = notification_factory(user_id)
        notify_user(user_id, notification)
