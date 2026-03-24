from fastapi import status


class AppException(Exception):
    """
    Excepción base de la aplicación.
    Todos los errores de dominio heredan de esta clase.

    status_code: el HTTP status que se devuelve al cliente
    detail:      el mensaje de error
    """

    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    detail: str = "Error interno del servidor"

    def __init__(self, detail: str | None = None):
        self.detail = detail or self.__class__.detail
        super().__init__(self.detail)


class NotFoundException(AppException):
    status_code = status.HTTP_404_NOT_FOUND
    detail = "Recurso no encontrado"


class AlreadyExistsException(AppException):
    status_code = status.HTTP_409_CONFLICT
    detail = "El recurso ya existe"


class UnauthorizedException(AppException):
    status_code = status.HTTP_401_UNAUTHORIZED
    detail = "No autenticado"


class ForbiddenException(AppException):
    status_code = status.HTTP_403_FORBIDDEN
    detail = "Sin permisos para esta acción"


class ValidationException(AppException):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    detail = "Error de validación"
