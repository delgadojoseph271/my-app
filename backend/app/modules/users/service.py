from app.modules.users.repository import UserRepository
from app.modules.users.schemas import UserCreateSchema, UserUpdateSchema
from app.modules.users.exceptions import UserNotFoundError
from app.shared.event_bus import bus


class UserService:
    def __init__(self, repo: UserRepository):
        self.repo = repo

    async def get_all(self) -> list:
        return await self.repo.get_all()

    async def get_by_id(self, id: int):
        return await self.repo.get_or_404(id)

    async def create(self, data: UserCreateSchema):
        obj = await self.repo.create(data)
        await bus.publish("users.created", {"id": obj.id})
        return obj

    async def update(self, id: int, data: UserUpdateSchema):
        obj = await self.repo.get_or_404(id)
        return await self.repo.update(obj, data)

    async def delete(self, id: int) -> None:
        obj = await self.repo.get_or_404(id)
        await self.repo.delete(obj)
        await bus.publish("users.deleted", {"id": id})
