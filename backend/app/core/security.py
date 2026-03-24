from datetime import datetime, timedelta, timezone
from typing import Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.core.config import settings
import uuid


# CryptContext maneja el algoritmo internamente.
# deprecated="auto" migra hashes viejos a bcrypt en el próximo login.

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ── Passwords ────────────────────────────────────────────────────────────────
def hash_password(plain: str) -> str:
    """
    Transforma la contraseña en un hash irreversible.
    Cada llamada genera un salt distinto → dos hashes del mismo
    password son siempre diferentes.
    """
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """
    Extrae el salt del hash guardado, re-hashea el plain con ese mismo
    salt y compara. Nunca desencripta.
    """
    return pwd_context.verify(plain, hashed)


# ── JWT ──────────────────────────────────────────────────────────────────────


def create_access_token(user_id: int) -> int:
    """
    Token de vida corta. No se guarda en DB.
    Si lo interceptan, expira en ACCESS_TOKEN_EXPIRE_MINUTES.
    """
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload: dict[str, Any] = {
        "sub": str(user_id),  # 'sub' es el campo estándar de JWT para el sujeto
        "exp": expire,
        "type": "access",  # distinguimos el tipo para no mezclar tokens
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def create_refresh_token(user_id: int) -> str:
    """
    Token de vida larga. SÍ se guarda en DB para poder invalidarlo.
    """
    expire = datetime.now(timezone.utc) + timedelta(days=30)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "exp": expire,
        "type": "refresh",
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def decode_token(token: str) -> dict[str, Any] | None:
    """
    Devuelve el payload si el token es válido y no expiró.
    Devuelve None en cualquier caso de error — nunca lanza excepción.
    El caller decide qué hacer con None.
    """
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    except JWTError:
        return None
