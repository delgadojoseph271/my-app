from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.modules.users.models import User
from app.shared.base_repository import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession):
        super().__init__(User, session)

    # Agregá queries específicas del módulo aquí
    # Ejemplo:
    # async def get_by_name(self, name: str) -> User | None:
    #     result = await self.session.execute(
    #         select(User).where(User.name == name)
    #     )
    #     return result.scalar_one_or_none()
