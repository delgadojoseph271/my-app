# backend/app/modules/auth/repository.py
from datetime import datetime, timezone
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.shared.base_repository import BaseRepository
from app.modules.auth.models import User, RefreshToken


class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession):
        super().__init__(User, session)

    async def get_by_email(self, email: str) -> User | None:
        result = await self.session.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()


class RefreshTokenRepository(BaseRepository[RefreshToken]):
    def __init__(self, session: AsyncSession):
        super().__init__(RefreshToken, session)

    async def get_by_token(self, token: str) -> RefreshToken | None:
        result = await self.session.execute(
            select(RefreshToken).where(RefreshToken.token == token)
        )
        obj = result.scalar_one_or_none()
        print(f"DEBUG get_by_token → type={type(obj)}, value={obj}")  # ← temporal
        return obj

    async def save(
        self, token: str, user_id: int, expires_at: datetime
    ) -> RefreshToken:
        """Guarda un refresh token nuevo en DB."""
        expires_at_naive = expires_at.replace(tzinfo=None)
        refresh = RefreshToken(
            token=token,
            user_id=user_id,
            expires_at=expires_at_naive,
        )
        self.session.add(refresh)
        await self.session.flush()  # obtiene el id sin commitear todavía
        return refresh

    async def delete_by_token(self, token: str) -> None:
        """Logout: invalida un token específico."""
        await self.session.execute(
            delete(RefreshToken).where(RefreshToken.token == token)
        )
        await self.session.flush()

    async def delete_all_for_user(self, user_id: int) -> None:
        """Logout de todos los dispositivos."""
        await self.session.execute(
            delete(RefreshToken).where(RefreshToken.user_id == user_id)
        )
        await self.session.flush()

    async def delete_expired(self) -> None:
        """Limpieza periódica — se llama desde una tarea Celery."""
        await self.session.execute(
            delete(RefreshToken).where(
                RefreshToken.expires_at < datetime.now(timezone.utc)
            )
        )
