from datetime import datetime
from pydantic import BaseModel, EmailStr, field_validator


# ── Entrada ───────────────────────────────────────────────────────────────────
class RegisterSchema(BaseModel):
    email: EmailStr
    password: str
    name: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("La contraseña debe tener al menos 8 caracteres")
        return v

    @field_validator("name")
    @classmethod
    def name_not_rmpty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("El nombre no puede estar vacío")
        return v.strip()


class LoginSchema(BaseModel):
    email: EmailStr
    password: str


class RefreshSchema(BaseModel):
    refresh_token: str


# ── Salida ────────────────────────────────────────────────────────────────────


class UserResponseSchema(BaseModel):
    id: int
    email: str
    name: str
    is_active: bool
    created_at: datetime
    # from_attributes=True permite crear este schema desde un objeto ORM
    # sin esto, Pydantic no sabe leer atributos de SQLAlchemy
    model_config = {"from_attributes": True}


class AuthResponseSchema(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"  # estándar OAuth2
    user: UserResponseSchema


class AuthCreateSchema(BaseModel):
    """Schema para crear un Auth."""

    # Agregá los campos requeridos
    # name: str
    pass


class AuthUpdateSchema(BaseModel):
    """Schema para actualizar un Auth (todos los campos opcionales)."""

    # name: str | None = None
    pass
