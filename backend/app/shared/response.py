# shared/response.py
from typing import TypeVar, Generic
from pydantic import BaseModel

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    """
    Envelope estándar para todas las respuestas de la API.

    Ejemplo de respuesta exitosa:
    {
        "success": true,
        "data": { "id": 1, "email": "..." },
        "message": null
    }

    Ejemplo de respuesta con mensaje:
    {
        "success": true,
        "data": null,
        "message": "Email de verificación enviado"
    }
    """

    success: bool = True
    data: T | None = None
    message: str | None = None


class PaginatedResponse(BaseModel, Generic[T]):
    """
    Respuesta paginada estándar.

    {
        "items": [...],
        "total": 100,
        "page": 1,
        "size": 20,
        "pages": 5
    }
    """

    items: list[T]
    total: int
    page: int
    size: int
    pages: int
