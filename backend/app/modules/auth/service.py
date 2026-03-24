# backend/app/modules/auth/service.py
import logging
from datetime import datetime, timedelta, timezone

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.modules.auth.exceptions import (
    EmailAlreadyExistsException,
    InvalidCredentialsException,
    InvalidTokenException,
)
from app.modules.auth.models import User
from app.modules.auth.repository import RefreshTokenRepository, UserRepository
from app.modules.auth.schemas import (
    AuthResponseSchema,
    LoginSchema,
    RefreshSchema,
    RegisterSchema,
    UserResponseSchema,
)
from app.shared.event_bus import bus

logger = logging.getLogger(__name__)

# Cuánto vive el refresh token — debe coincidir con create_refresh_token()
_REFRESH_TOKEN_DAYS = 30

# Hash de un password ficticio para el timing attack.
# Se usa cuando el email no existe — así bcrypt tarda igual que si existiera.
_DUMMY_HASH = hash_password("dummy-password-for-timing-protection")


class AuthService:
    def __init__(
        self,
        user_repo: UserRepository,
        token_repo: RefreshTokenRepository,
    ):
        self.user_repo = user_repo
        self.token_repo = token_repo

    # ── Register ─────────────────────────────────────────────────────────────

    async def register(self, data: RegisterSchema) -> AuthResponseSchema:
        logger.info(f"Registro: email={data.email}")

        existing = await self.user_repo.get_by_email(data.email)
        if existing:
            raise EmailAlreadyExistsException()

        # Nunca guardamos el password en texto plano
        user = await self.user_repo.create(
            {
                "email": data.email,
                "name": data.name,
                "password_hash": hash_password(data.password),
            }
        )

        tokens = await self._generate_and_save_tokens(user)

        # Efecto secundario: notificaciones, analytics, etc.
        # Fire-and-forget — no bloquea la respuesta
        await bus.publish(
            "user.registered",
            {
                "user_id": user.id,
                "email": user.email,
            },
        )

        logger.info(f"Usuario registrado: id={user.id}")
        return tokens

    # ── Login ─────────────────────────────────────────────────────────────────

    async def login(self, data: LoginSchema) -> AuthResponseSchema:
        user = await self.user_repo.get_by_email(data.email)

        if not user:
            # El email no existe, pero corremos verify_password igual
            # para que el tiempo de respuesta sea idéntico al caso
            # donde el email existe pero la contraseña es incorrecta.
            # Sin esto, un atacante puede enumerar emails midiendo tiempos.
            verify_password(data.password, _DUMMY_HASH)
            raise InvalidCredentialsException()

        if not verify_password(data.password, user.password_hash):
            raise InvalidCredentialsException()

        if not user.is_active:
            # Mismo mensaje genérico — no revelamos por qué falla
            raise InvalidCredentialsException()

        logger.info(f"Login exitoso: user_id={user.id}")
        return await self._generate_and_save_tokens(user)

    # ── Refresh ───────────────────────────────────────────────────────────────

    async def refresh(self, data: RefreshSchema) -> AuthResponseSchema:
        # Paso 1: verificar que el JWT es válido criptográficamente
        payload = decode_token(data.refresh_token)

        if not payload or payload.get("type") != "refresh":
            raise InvalidTokenException()

        # Paso 2: verificar que el token existe en DB (no fue invalidado)
        db_token = await self.token_repo.get_by_token(data.refresh_token)

        if not db_token:
            # El token no está en DB pero es criptográficamente válido.
            # Esto puede significar que fue robado y ya rotado.
            # Respuesta defensiva: invalidar TODOS los tokens del usuario.
            user_id = int(payload["sub"])
            await self.token_repo.delete_all_for_user(user_id)
            logger.warning(f"Reuso de refresh token detectado: user_id={user_id}")
            raise InvalidTokenException()

        # Paso 3: verificar que el token no expiró en DB
        # (doble chequeo — el JWT ya lo verifica, pero por si acaso)
        expires_at = db_token.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            await self.token_repo.delete_by_token(data.refresh_token)
            raise InvalidTokenException()

        # Paso 4: obtener el usuario
        user = await self.user_repo.get_or_404(db_token.user_id)

        if not user.is_active:
            raise InvalidTokenException()

        # Paso 5: rotación — el token viejo muere, nace uno nuevo
        await self.token_repo.delete_by_token(data.refresh_token)
        logger.info(f"Refresh token rotado: user_id={user.id}")

        return await self._generate_and_save_tokens(user)

    # ── Logout ────────────────────────────────────────────────────────────────

    async def logout(self, refresh_token: str) -> None:
        """
        Invalida el refresh token en DB.
        El access token expira solo — no hay nada que hacer con él.
        Si el token no existe (ya fue invalidado), no es un error.
        """
        await self.token_repo.delete_by_token(refresh_token)
        logger.info("Logout: refresh token invalidado")

    async def logout_all_devices(self, user_id: int) -> None:
        """Cierra sesión en todos los dispositivos del usuario."""
        await self.token_repo.delete_all_for_user(user_id)
        logger.info(f"Logout total: user_id={user_id}")

    # ── Helper privado ────────────────────────────────────────────────────────

    async def _generate_and_save_tokens(self, user: User) -> AuthResponseSchema:
        """
        Genera access + refresh token y persiste el refresh en DB.
        Método privado — solo se llama desde register, login y refresh.
        """
        access_token = create_access_token(user.id)
        refresh_token = create_refresh_token(user.id)
        expires_at = datetime.now(timezone.utc) + timedelta(days=_REFRESH_TOKEN_DAYS)

        await self.token_repo.save(
            token=refresh_token,
            user_id=user.id,
            expires_at=expires_at,
        )

        return AuthResponseSchema(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserResponseSchema.model_validate(user),
        )
