from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.modules.auth.models import Auth
from app.shared.base_repository import BaseRepository


class AuthRepository(BaseRepository[Auth]):
    def __init__(self, session: AsyncSession):
        super().__init__(Auth, session)

    # Agregá queries específicas del módulo aquí
    # Ejemplo:
    # async def get_by_name(self, name: str) -> Auth | None:
    #     result = await self.session.execute(
    #         select(Auth).where(Auth.name == name)
    #     )
    #     return result.scalar_one_or_none()
