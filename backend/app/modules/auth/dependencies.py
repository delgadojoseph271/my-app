from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession


from app.core.security import decode_token
from app.infrastructure.database import get_db
from app.modules.auth.exceptions import InvalidCredentialsException
from app.modules.auth.models import User
from app.modules.auth.repository import RefreshTokenRepository, UserRepository
from app.shared.exceptions import ForbiddenException

from app.modules.auth.service import AuthService

# tokenUrl le dice a Swagger dónde está el endpoint de login.
# Solo sirve para la UI de documentación — no afecta la validación.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

# ── Repositories ──────────────────────────────────────────────────────────────


def get_user_repository(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)


def get_token_repository(db: AsyncSession = Depends(get_db)) -> RefreshTokenRepository:
    return RefreshTokenRepository(db)


# ── Service ───────────────────────────────────────────────────────────────────


def get_auth_service(
    user_repo: UserRepository = Depends(get_user_repository),
    token_repo: RefreshTokenRepository = Depends(get_token_repository),
) -> "AuthService":  # string porque AuthService se importa abajo
    from app.modules.auth.service import AuthService

    return AuthService(user_repo, token_repo)


# ── Guards ────────────────────────────────────────────────────────────────────


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    user_repo: UserRepository = Depends(get_user_repository),
) -> User:
    """
    Guard base: cualquier usuario autenticado y activo.
    Se usa como Depends() en cualquier endpoint protegido.
    """
    payload = decode_token(token)
    # None significa token inválido, expirado, o manipulado
    if not payload or payload.get("type") != "access":
        raise InvalidCredentialsException()

    user_id = payload.get("sub")
    if not user_id:
        raise InvalidCredentialsException()

    user = await user_repo.get_by_id(int(user_id))

    if not user_id:
        raise InvalidCredentialsException()

    return user


async def require_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    """
    Guard compuesto: extiende get_current_user añadiendo chequeo de rol.
    Si el usuario no es admin, lanza 403 Forbidden (no 401).
    La distinción importa: 401 = no autenticado, 403 = autenticado pero sin permiso.
    """
    if not current_user.is_admin:
        raise ForbiddenException()
    return current_user
