from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.modules.notifications.models import Notification
from app.shared.base_repository import BaseRepository


class NotificationRepository(BaseRepository[Notification]):
    def __init__(self, session: AsyncSession):
        super().__init__(Notification, session)

    # Agregá queries específicas del módulo aquí
    # Ejemplo:
    # async def get_by_name(self, name: str) -> Notification | None:
    #     result = await self.session.execute(
    #         select(Notification).where(Notification.name == name)
    #     )
    #     return result.scalar_one_or_none()
