from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db
from app.modules.users.repository import UserRepository
from app.modules.users.service import UserService


def get_users_repository(
    db: AsyncSession = Depends(get_db),
) -> UserRepository:
    return UserRepository(db)


def get_users_service(
    repo: UserRepository = Depends(get_users_repository),
) -> UserService:
    return UserService(repo)
