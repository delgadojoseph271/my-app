from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Boolean
from app.shared.base_model import Base


class Auth(Base):
    __tablename__ = "auth"

    # Agregá tus columnas aquí
    # Ejemplo:
    # name: Mapped[str] = mapped_column(String(255))
    # is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    pass
