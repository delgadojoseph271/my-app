# shared/base_model.py
from datetime import datetime
from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """
    Clase base para todos los modelos SQLAlchemy del proyecto.
    Provee columnas comunes que todas las tablas deben tener.
    """

    pass


class TimestampMixin:
    """
    Mixin que agrega created_at y updated_at a cualquier modelo.
    Se usan server_default y onupdate para que la DB los maneje,
    no Python — más confiable en entornos con múltiples workers.
    """

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    update_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class BaseModel(Base, TimestampMixin):
    """
    Modelo base concreto: id + timestamps.
    Todos los modelos del proyecto heredan de este.
    """

    __abstract__ = True

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
