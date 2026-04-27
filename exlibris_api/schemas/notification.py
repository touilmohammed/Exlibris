from pydantic import BaseModel

NotificationDataValue = str | int | float | bool | None


class NotificationOut(BaseModel):
    id: str
    type: str
    title: str
    message: str
    data: dict[str, NotificationDataValue]
    created_at: str
