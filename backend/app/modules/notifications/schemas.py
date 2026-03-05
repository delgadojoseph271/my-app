from pydantic import BaseModel


class NotificationCreateSchema(BaseModel):
    """Schema para crear un Notification."""
    # Agregá los campos requeridos
    # name: str
    pass


class NotificationUpdateSchema(BaseModel):
    """Schema para actualizar un Notification (todos los campos opcionales)."""
    # name: str | None = None
    pass


class NotificationResponseSchema(BaseModel):
    """Schema de respuesta al cliente."""
    id: int
    # name: str

    model_config = {"from_attributes": True}
