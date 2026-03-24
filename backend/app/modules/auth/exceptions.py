from app.shared.exceptions import AlreadyExistsException, UnauthorizedException


class AuthNotFoundError(Exception):
    def __init__(self, id: int):
        self.id = id
        super().__init__(f"Auth con id {id} no encontrado")


class AuthAlreadyExistsError(Exception):
    def __init__(self, detail: str = ""):
        super().__init__(f"Auth ya existe. {detail}".strip())


class EmailAlreadyExistsException(AlreadyExistsException):
    detail = "Ya existe una cuenta con este email"


class InvalidCredentialsException(UnauthorizedException):
    # Mensaje genérico intencional — no revelamos si el email existe o no
    detail = "Credenciales inválidas"


class InvalidTokenException(UnauthorizedException):
    detail = "Token inválido o expirado"
