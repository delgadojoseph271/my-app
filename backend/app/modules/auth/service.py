from app.modules.auth.repository import AuthRepository
from app.modules.auth.schemas import AuthCreateSchema, AuthUpdateSchema
from app.modules.auth.exceptions import AuthNotFoundError
from app.shared.event_bus import bus


class AuthService:
    def __init__(self, repo: AuthRepository):
        self.repo = repo

    async def get_all(self) -> list:
        return await self.repo.get_all()

    async def get_by_id(self, id: int):
        return await self.repo.get_or_404(id)

    async def create(self, data: AuthCreateSchema):
        obj = await self.repo.create(data)
        await bus.publish("auth.created", {"id": obj.id})
        return obj

    async def update(self, id: int, data: AuthUpdateSchema):
        obj = await self.repo.get_or_404(id)
        return await self.repo.update(obj, data)

    async def delete(self, id: int) -> None:
        obj = await self.repo.get_or_404(id)
        await self.repo.delete(obj)
        await bus.publish("auth.deleted", {"id": id})
