from datetime import datetime
from sqlalchemy import Boolean, DateTime, ForeignKey, String, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.shared.base_model import BaseModel


class User(BaseModel):
    __tablename__ = "users"

    name: Mapped[str] = mapped_column(String(255), unique=False, nullable=False)
    email: Mapped[str] = mapped_column(
        String(255), unique=True, nullable=False, index=True
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # Relación: un User tiene muchos RefreshToken
    # cascade="all, delete-orphan" → si borrás el User, se borran sus tokens
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(
        "RefreshToken", back_populates="user", cascade="all, delete-orphan"
    )


class RefreshToken(BaseModel):
    __tablename__ = "refresh_tokens"

    # El token en sí — indexado porque vamos a buscar por él en cada refresh
    token: Mapped[str] = mapped_column(
        String(512), unique=True, nullable=False, index=True
    )

    # Cuándo expira — lo guardamos para poder hacer limpieza periódica
    # sin necesidad de decodificar el JWT
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    # Relación inversa: cada RefreshToken pertenece a un User
    user: Mapped["User"] = relationship("User", back_populates="refresh_tokens")
    pass


class Auth(BaseModel):
    __tablename__ = "auth"

    # Agregá tus columnas aquí
    # Ejemplo:
    # name: Mapped[str] = mapped_column(String(255))
    # is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    pass
