from app.modules.notifications.repository import NotificationRepository
from app.modules.notifications.schemas import NotificationCreateSchema, NotificationUpdateSchema
from app.modules.notifications.exceptions import NotificationNotFoundError
from app.shared.event_bus import bus


class NotificationService:
    def __init__(self, repo: NotificationRepository):
        self.repo = repo

    async def get_all(self) -> list:
        return await self.repo.get_all()

    async def get_by_id(self, id: int):
        return await self.repo.get_or_404(id)

    async def create(self, data: NotificationCreateSchema):
        obj = await self.repo.create(data)
        await bus.publish("notifications.created", {"id": obj.id})
        return obj

    async def update(self, id: int, data: NotificationUpdateSchema):
        obj = await self.repo.get_or_404(id)
        return await self.repo.update(obj, data)

    async def delete(self, id: int) -> None:
        obj = await self.repo.get_or_404(id)
        await self.repo.delete(obj)
        await bus.publish("notifications.deleted", {"id": id})
