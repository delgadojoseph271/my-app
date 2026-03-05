from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db
from app.modules.notifications.repository import NotificationRepository
from app.modules.notifications.service import NotificationService


def get_notifications_repository(
    db: AsyncSession = Depends(get_db),
) -> NotificationRepository:
    return NotificationRepository(db)


def get_notifications_service(
    repo: NotificationRepository = Depends(get_notifications_repository),
) -> NotificationService:
    return NotificationService(repo)
