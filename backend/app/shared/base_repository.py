# backend/app/shared/base_repository.py
from typing import Generic, TypeVar, Type, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status
from app.shared.base_model import BaseModel

# ← bound=BaseModel, no BaseException
T = TypeVar("T", bound=BaseModel)


class BaseRepository(Generic[T]):
    """
    Repository genérico con operaciones CRUD básicas.
    Uso:
        class UserRepository(BaseRepository[User]):
            def __init__(self, session: AsyncSession):
                super().__init__(User, session)
    """

    def __init__(self, model: Type[T], session: AsyncSession) -> None:
        self.model = model
        self.session = session

    async def get_by_id(self, id: int) -> T | None:
        """Devuelve el objeto o None si no existe."""
        return await self.session.get(self.model, id)

    async def get_or_404(self, id: int) -> T:
        """Devuelve el objeto o lanza HTTP 404 si no existe."""
        obj = await self.session.get(self.model, id)
        if obj is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"{self.model.__name__} con id {id} no encontrado",
            )
        return obj  # ← antes retornaba None aquí

    async def get_all(self, limit: int = 100, offset: int = 0) -> list[T]:
        """Devuelve todos los registros con paginación básica."""
        result = await self.session.execute(
            select(self.model)  # ← .limit() va sobre la query, no el modelo
            .limit(limit)
            .offset(offset)
            .order_by(self.model.created_at.desc())
        )
        return list(result.scalars().all())

    async def create(self, data: Any) -> T:
        """
        Crea un nuevo registro.
        data puede ser un schema Pydantic o un dict.
        No commitea — el commit lo maneja get_db() al terminar el request.
        """
        if hasattr(data, "model_dump"):
            data_dict = data.model_dump(exclude_unset=True)
        else:
            data_dict = data

        obj = self.model(**data_dict)
        self.session.add(obj)
        await (
            self.session.flush()
        )  # ← flush, no commit: obtiene id sin cerrar transacción
        await self.session.refresh(obj)
        return obj

    async def update(self, obj: T, data: Any) -> T:
        """
        Actualiza solo los campos enviados en el request.
        exclude_unset=True evita pisar campos no enviados con None.
        """
        if hasattr(data, "model_dump"):
            data_dict = data.model_dump(exclude_unset=True)
        else:
            data_dict = data

        for field, value in data_dict.items():
            setattr(obj, field, value)

        await self.session.flush()  # ← flush, no commit
        await self.session.refresh(obj)
        return obj

    async def delete(self, obj: T) -> None:
        """Elimina un objeto de la base de datos."""
        await self.session.delete(obj)
        await self.session.flush()  # ← flush, no commit

    async def exists(self, id: int) -> bool:
        """Verifica si un registro existe sin traer todos sus datos."""
        obj = await self.session.get(self.model, id)
        return obj is not None
