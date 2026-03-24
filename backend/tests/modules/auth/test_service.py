# backend/tests/modules/auth/test_service.py
import pytest
from unittest.mock import AsyncMock, MagicMock
from app.modules.auth.service import AuthService
from app.modules.auth.exceptions import (
    EmailAlreadyExistsException,
    InvalidCredentialsException,
    InvalidTokenException,
)
from app.modules.auth.models import User
from app.core.security import hash_password


# ── Helpers ───────────────────────────────────────────────────────────────────


def make_service(
    user_repo: AsyncMock | None = None,
    token_repo: AsyncMock | None = None,
) -> AuthService:
    """
    Construye un AuthService con repos falsos.
    AsyncMock es un objeto que imita el repo pero no toca la DB.
    Podés programarle qué debe retornar en cada llamada.
    """
    return AuthService(
        user_repo=user_repo or AsyncMock(),
        token_repo=token_repo or AsyncMock(),
    )


def make_user(**kwargs) -> User:
    """Crea un User falso con valores por defecto."""
    user = MagicMock(spec=User)
    user.id = kwargs.get("id", 1)
    user.email = kwargs.get("email", "test@example.com")
    user.name = kwargs.get("name", "Test User")
    user.password_hash = kwargs.get("password_hash", hash_password("password123"))
    user.is_active = kwargs.get("is_active", True)
    user.is_admin = kwargs.get("is_admin", False)
    return user


# ── Tests: register ───────────────────────────────────────────────────────────


async def test_register_crea_usuario_y_retorna_tokens():
    """Flujo feliz: registro exitoso devuelve access y refresh token."""
    user_repo = AsyncMock()
    token_repo = AsyncMock()

    # Programamos el mock: get_by_email retorna None (email no existe)
    user_repo.get_by_email.return_value = None
    # create retorna un usuario falso
    user_repo.create.return_value = make_user()

    service = make_service(user_repo, token_repo)
    result = await service.register(
        MagicMock(
            email="nuevo@example.com",
            password="password123",
            name="Nuevo Usuario",
        )
    )

    assert result.access_token
    assert result.refresh_token
    # Verificamos que SÍ intentó guardar el refresh token en DB
    token_repo.save.assert_called_once()
    # Verificamos que SÍ intentó crear el usuario
    user_repo.create.assert_called_once()


async def test_register_falla_si_email_existe():
    """Si el email ya está registrado, debe lanzar EmailAlreadyExistsException."""
    user_repo = AsyncMock()
    # get_by_email retorna un usuario → email ya existe
    user_repo.get_by_email.return_value = make_user()

    service = make_service(user_repo)

    with pytest.raises(EmailAlreadyExistsException):
        await service.register(
            MagicMock(
                email="existe@example.com",
                password="password123",
                name="Ya Existe",
            )
        )

    # Si el email existe, nunca debe intentar crear el usuario
    user_repo.create.assert_not_called()


# ── Tests: login ──────────────────────────────────────────────────────────────


async def test_login_exitoso_retorna_tokens():
    """Login con credenciales correctas devuelve tokens."""
    user_repo = AsyncMock()
    token_repo = AsyncMock()
    user_repo.get_by_email.return_value = make_user(
        password_hash=hash_password("password123")
    )

    service = make_service(user_repo, token_repo)
    result = await service.login(
        MagicMock(
            email="test@example.com",
            password="password123",
        )
    )

    assert result.access_token
    assert result.refresh_token


async def test_login_falla_con_password_incorrecto():
    """Password incorrecto lanza InvalidCredentialsException."""
    user_repo = AsyncMock()
    user_repo.get_by_email.return_value = make_user(
        password_hash=hash_password("password123")
    )

    service = make_service(user_repo)

    with pytest.raises(InvalidCredentialsException):
        await service.login(
            MagicMock(
                email="test@example.com",
                password="password_INCORRECTA",
            )
        )


async def test_login_falla_con_email_inexistente():
    """Email que no existe lanza InvalidCredentialsException — mismo error que password incorrecto."""
    user_repo = AsyncMock()
    user_repo.get_by_email.return_value = None  # email no existe

    service = make_service(user_repo)

    with pytest.raises(InvalidCredentialsException):
        await service.login(
            MagicMock(
                email="noexiste@example.com",
                password="cualquier_cosa",
            )
        )


async def test_login_falla_si_usuario_inactivo():
    """Usuario desactivado no puede hacer login."""
    user_repo = AsyncMock()
    user_repo.get_by_email.return_value = make_user(
        password_hash=hash_password("password123"),
        is_active=False,  # ← usuario inactivo
    )

    service = make_service(user_repo)

    with pytest.raises(InvalidCredentialsException):
        await service.login(
            MagicMock(
                email="test@example.com",
                password="password123",
            )
        )


# ── Tests: refresh ────────────────────────────────────────────────────────────


async def test_refresh_con_token_inexistente_en_db_invalida_todos():
    """
    Token criptográficamente válido pero no está en DB →
    posible robo → invalidar TODOS los tokens del usuario.
    """
    from app.core.security import create_refresh_token

    user_repo = AsyncMock()
    token_repo = AsyncMock()

    # El token es válido criptográficamente (firma correcta)
    valid_token = create_refresh_token(user_id=1)
    # Pero NO está en DB → fue rotado o robado
    token_repo.get_by_token.return_value = None

    service = make_service(user_repo, token_repo)

    with pytest.raises(InvalidTokenException):
        await service.refresh(MagicMock(refresh_token=valid_token))

    # La respuesta defensiva: borrar TODOS los tokens del usuario
    token_repo.delete_all_for_user.assert_called_once_with(1)
