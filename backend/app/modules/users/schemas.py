from pydantic import BaseModel


class UserCreateSchema(BaseModel):
    """Schema para crear un User."""
    # Agregá los campos requeridos
    # name: str
    pass


class UserUpdateSchema(BaseModel):
    """Schema para actualizar un User (todos los campos opcionales)."""
    # name: str | None = None
    pass


class UserResponseSchema(BaseModel):
    """Schema de respuesta al cliente."""
    id: int
    # name: str

    model_config = {"from_attributes": True}
