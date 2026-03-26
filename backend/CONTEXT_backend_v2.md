# CONTEXT.md — Backend (FastAPI)

> Contexto técnico del backend. Mantenerlo actualizado al agregar módulos, cambiar patrones o tomar decisiones de arquitectura.

---

## Tabla de contenidos

1. [Stack y versiones](#1-stack-y-versiones)
2. [Estructura de carpetas](#2-estructura-de-carpetas)
3. [Capa core/](#3-capa-core)
   - config.py
   - security.py ⬜
   - logging.py ⬜
   - middleware.py ⬜
   - lifespan.py
4. [Capa infrastructure/](#4-capa-infrastructure)
5. [Capa shared/](#5-capa-shared)
6. [Patrón de módulo](#6-patrón-de-módulo)
7. [Sistema de eventos — event_bus](#7-sistema-de-eventos--event_bus)
8. [Inyección de dependencias — FastAPI Depends()](#8-inyección-de-dependencias--fastapi-depends)
9. [Sistema de migraciones — Alembic](#9-sistema-de-migraciones--alembic)
10. [Autenticación JWT](#10-autenticación-jwt)
11. [Workers y tareas asíncronas — Celery](#11-workers-y-tareas-asíncronas--celery)
12. [Sistema de errores](#12-sistema-de-errores)
13. [Testing](#13-testing)
14. [Linting y tipos](#14-linting-y-tipos)
15. [Variables de entorno](#15-variables-de-entorno)
16. [Módulos existentes](#16-módulos-existentes)
17. [Extracción a microservicio](#17-extracción-a-microservicio)
18. [Convenciones de código](#18-convenciones-de-código)
19. [Comandos](#19-comandos)

---

## 1. Stack y versiones

| Capa | Tecnología | Versión |
|------|-----------|---------|
| Framework | FastAPI | ≥ 0.110 |
| Runtime | Python | 3.12 |
| ORM | SQLAlchemy (async) | ≥ 2.0 |
| Driver async (runtime) | asyncpg | latest |
| Driver sync (migraciones) | psycopg2-binary | latest |
| Migraciones | Alembic | latest |
| Base de datos | PostgreSQL | 16 |
| Cache / broker | Redis | 7 |
| Storage | MinIO (S3-compatible) | latest |
| Validación | Pydantic v2 + pydantic-settings | — |
| Auth | python-jose + passlib[bcrypt] | — |
| Workers | Celery + Redis broker | — |
| Mensajería (futuro) | RabbitMQ / aio-pika | — |
| Testing | pytest + pytest-asyncio + httpx | — |
| Linting | ruff | — |
| Tipos | mypy | — |

**pyproject.toml — sección crítica:**

```toml
[tool.setuptools.packages.find]
include = ["app*", "workers*"]
# migrations/ se excluye del paquete — Alembic la maneja directamente
```

---

## 2. Estructura de carpetas

```
backend/
├── app/
│   ├── core/                      ← CONFIG
│   │   ├── config.py              ← Settings (pydantic-settings, lee .env)
│   │   ├── security.py            ← JWT encode/decode, hash de passwords  ⬜ pendiente
│   │   ├── logging.py             ← configuración global del logger        ⬜ pendiente
│   │   ├── middleware.py          ← CORS, rate limiting, request ID        ⬜ pendiente
│   │   └── lifespan.py            ← startup/shutdown + registro de event handlers
│   │
│   ├── infrastructure/            ← INFRA — adaptadores técnicos
│   │   ├── database.py            ← AsyncEngine + get_db dependency
│   │   ├── cache.py               ← Redis con aioredis
│   │   ├── messaging.py           ← RabbitMQ con aio-pika (para futura migración)
│   │   ├── storage.py             ← MinIO/S3 con aiobotocore
│   │   ├── email.py               ← FastMail
│   │   └── celery.py              ← configuración del cliente Celery
│   │
│   ├── shared/                    ← SHARED
│   │   ├── base_model.py          ← Base + TimestampMixin + BaseModel (abstract)
│   │   ├── base_repository.py     ← BaseRepository[T] con CRUD genérico
│   │   ├── base_service.py        ← BaseService con logging estandarizado
│   │   ├── event_bus.py           ← EventBus singleton (pub/sub in-process)
│   │   ├── exceptions.py          ← AppException y jerarquía de errores
│   │   ├── response.py            ← ApiResponse[T] y PaginatedResponse[T]
│   │   └── pagination.py          ← PaginationParams + get_pagination()
│   │
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── models.py
│   │   │   ├── schemas.py
│   │   │   ├── repository.py
│   │   │   ├── service.py
│   │   │   ├── router.py
│   │   │   ├── dependencies.py
│   │   │   └── exceptions.py
│   │   └── <modulo>/              ← misma estructura exacta
│   │
│   └── main.py                    ← FastAPI app + lifespan + routers
│
├── workers/                       ← CELERY
│   ├── celery_app.py              ← instancia Celery (importa desde infrastructure/celery.py)
│   ├── tasks.py                   ← definición de tareas
│   └── beat_schedule.py           ← tareas periódicas (cron)
│
├── migrations/                    ← ALEMBIC
│   ├── env.py                     ← inyecta DATABASE_URL, importa todos los modelos
│   ├── script.py.mako
│   └── versions/
│
├── tests/
│   ├── conftest.py
│   └── modules/
│
├── pyproject.toml
├── .env.example
└── Dockerfile
```

### Regla de dependencia entre capas

```
modules/ → shared/ → infrastructure/ → core/
```

Nunca al revés. Si `shared/` necesita importar algo de `modules/`, ese código está en el lugar equivocado.

---

## 3. Capa core/

### config.py

Todas las variables de entorno se leen desde aquí. **Nunca usar `os.environ` directamente** fuera de este archivo.

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    DEBUG: bool = False

    # Base de datos
    DATABASE_URL: str

    # Cache / Celery
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    # Storage
    S3_ENDPOINT: str | None = None   # None = AWS S3 real
    S3_BUCKET: str = "my-app"
    S3_ACCESS_KEY: str = ""
    S3_SECRET_KEY: str = ""
    S3_PUBLIC_URL: str = ""

    # JWT
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    model_config = {"env_file": ".env"}

settings = Settings()
```

### security.py — ⬜ pendiente de implementar

Centraliza toda la criptografía: generación y verificación de JWT, y hashing de passwords. **Ningún módulo debe importar `python-jose` o `passlib` directamente** — todo pasa por aquí.

```python
# core/security.py
from datetime import datetime, timedelta, timezone
from typing import Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.core.config import settings

# ── Passwords ────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(plain: str) -> str:
    """Hashea una contraseña con bcrypt."""
    return pwd_context.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    """Verifica una contraseña contra su hash."""
    return pwd_context.verify(plain, hashed)

# ── JWT ──────────────────────────────────────────────────────
def create_access_token(subject: str | int, extra: dict[str, Any] | None = None) -> str:
    """
    Genera un access token JWT.
    subject: normalmente el user_id.
    extra: campos adicionales a incluir en el payload (ej: {"role": "admin"}).
    """
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {"sub": str(subject), "exp": expire, "type": "access"}
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

def create_refresh_token(subject: str | int) -> str:
    """Genera un refresh token JWT con vida más larga."""
    expire = datetime.now(timezone.utc) + timedelta(days=30)
    payload = {"sub": str(subject), "exp": expire, "type": "refresh"}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

def decode_token(token: str) -> dict[str, Any] | None:
    """
    Decodifica y valida un JWT.
    Devuelve el payload si es válido, None si expiró o es inválido.
    """
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    except JWTError:
        return None
```

---

### logging.py — ⬜ pendiente de implementar

Configura el logger global de la app. Se llama una sola vez en `main.py` o en el `lifespan`. Todos los módulos usan `logging.getLogger(__name__)` — nunca `print()`.

```python
# core/logging.py
import logging
import sys
from app.core.config import settings

def setup_logging() -> None:
    """
    Configura el logger raíz de la aplicación.
    - En desarrollo: formato legible con colores en consola.
    - En producción: formato JSON estructurado para ingestión por herramientas como Datadog.
    """
    log_level = logging.DEBUG if settings.DEBUG else logging.INFO

    # Formato desarrollo — legible para humanos
    dev_format = "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s"

    # TODO (producción): reemplazar con un formatter JSON
    # from pythonjsonlogger import jsonlogger
    # formatter = jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(name)s %(message)s")

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter(dev_format))

    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    root_logger.handlers.clear()
    root_logger.addHandler(handler)

    # Silenciar librerías verbosas en producción
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.DEBUG if settings.DEBUG else logging.WARNING
    )
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)

# Uso en main.py o lifespan:
# from app.core.logging import setup_logging
# setup_logging()
```

---

### middleware.py — ⬜ pendiente de implementar

Define y registra los middlewares de la app: CORS, request ID, y opcionalmente rate limiting. Se aplican a **todos** los requests antes de llegar a los routers.

```python
# core/middleware.py
import uuid
import time
import logging
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from app.core.config import settings

logger = logging.getLogger(__name__)


def register_middlewares(app: FastAPI) -> None:
    """
    Registra todos los middlewares en la app FastAPI.
    Se llama en main.py antes de registrar los routers.
    El orden importa: el último en registrarse es el primero en ejecutarse.
    """

    # ── CORS ─────────────────────────────────────────────────
    # Ajustar allow_origins según el entorno
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if settings.DEBUG else ["https://tudominio.com"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Request ID + logging de requests ─────────────────────
    app.add_middleware(RequestLoggingMiddleware)

    # ── Rate limiting (implementar cuando sea necesario) ──────
    # app.add_middleware(RateLimitMiddleware, max_requests=100, window_seconds=60)


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Agrega un ID único a cada request y loggea duración y status.
    El request_id se puede propagar a los logs del service para trazabilidad.
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = str(uuid.uuid4())[:8]
        request.state.request_id = request_id
        start = time.perf_counter()

        response = await call_next(request)

        duration_ms = (time.perf_counter() - start) * 1000
        logger.info(
            f"[{request_id}] {request.method} {request.url.path} "
            f"→ {response.status_code} ({duration_ms:.1f}ms)"
        )

        response.headers["X-Request-ID"] = request_id
        return response


# TODO: implementar cuando el tráfico lo justifique
# class RateLimitMiddleware(BaseHTTPMiddleware):
#     """Rate limiting por IP usando Redis."""
#     async def dispatch(self, request: Request, call_next) -> Response:
#         ip = request.client.host
#         redis = await get_redis()
#         count = await redis.incr(f"rate:{ip}")
#         await redis.expire(f"rate:{ip}", self.window_seconds)
#         if count > self.max_requests:
#             return JSONResponse(status_code=429, content={"detail": "Too many requests"})
#         return await call_next(request)
```

---

### lifespan.py

Startup y shutdown de la app. Los handlers del `event_bus` se registran aquí para que estén activos antes del primer request.

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.shared.event_bus import bus
from app.modules.notifications.events import on_user_registered

@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──────────────────────────────────────
    bus.subscribe("user.registered", on_user_registered)
    # bus.subscribe("order.created", on_order_created)
    yield
    # ── Shutdown ─────────────────────────────────────
    await engine.dispose()
```

---

## 4. Capa infrastructure/

Aísla los detalles técnicos de servicios externos. Si cambiás de PostgreSQL a MySQL o de MinIO a AWS S3, solo tocás estos archivos — el resto del código no sabe la diferencia.

### database.py

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,    # verifica conexiones antes de usarlas
    echo=settings.DEBUG,
)

AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

async def get_db() -> AsyncSession:
    """Dependency de FastAPI: una sesión por request con rollback automático."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

### cache.py — Redis

```python
import redis.asyncio as aioredis
from app.core.config import settings

async def get_redis() -> aioredis.Redis:
    return aioredis.from_url(settings.REDIS_URL, decode_responses=True, max_connections=20)

# Patrones de uso:
#
# TTL (sesiones, tokens temporales):
#   await redis.setex(f"session:{token}", 3600, user_id)
#
# Cache de respuesta:
#   cached = await redis.get(f"user:{user_id}")
#   if cached: return json.loads(cached)
#
# Rate limiting:
#   count = await redis.incr(f"rate:{ip}")
#   await redis.expire(f"rate:{ip}", 60)
#   if count > 100: raise TooManyRequestsError()
```

### storage.py — MinIO / S3

```python
import aiobotocore.session
from app.core.config import settings

async def upload_file(key: str, data: bytes, content_type: str) -> str:
    """Sube un archivo y devuelve la URL pública."""
    session = aiobotocore.session.get_session()
    async with session.create_client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT,
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
    ) as client:
        await client.put_object(
            Bucket=settings.S3_BUCKET, Key=key, Body=data, ContentType=content_type
        )
        return f"{settings.S3_PUBLIC_URL}/{key}"
```

### celery.py — configuración del cliente Celery

Centraliza la configuración de Celery. `workers/celery_app.py` importa desde aquí para no duplicar la config.

```python
# infrastructure/celery.py
from celery import Celery
from app.core.config import settings

def create_celery_app() -> Celery:
    app = Celery(
        "worker",
        broker=settings.CELERY_BROKER_URL,
        backend=settings.CELERY_RESULT_BACKEND,
        include=["workers.tasks"],
    )
    app.conf.update(
        task_serializer="json",
        accept_content=["json"],
        result_serializer="json",
        timezone="America/Panama",
        enable_utc=True,
        task_acks_late=True,           # confirma recibo solo después de ejecutar
        worker_prefetch_multiplier=1,  # una tarea a la vez por worker
        task_track_started=True,
    )
    return app

celery_app = create_celery_app()

# workers/celery_app.py importa desde aquí:
# from app.infrastructure.celery import celery_app
```

---

### messaging.py — RabbitMQ (para cuando el bus evolucione)

```python
import aio_pika, json
from app.core.config import settings

async def publish_message(exchange: str, routing_key: str, payload: dict):
    """Publica en RabbitMQ — reemplaza al EventBus in-process al escalar."""
    connection = await aio_pika.connect_robust(settings.RABBITMQ_URL)
    async with connection:
        channel = await connection.channel()
        exch = await channel.declare_exchange(
            exchange, aio_pika.ExchangeType.TOPIC, durable=True
        )
        await exch.publish(
            aio_pika.Message(
                json.dumps(payload).encode(),
                delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
            ),
            routing_key=routing_key,
        )
```

---

## 5. Capa shared/

Lo que todos los módulos pueden usar pero que no pertenece a ninguno en particular.

### base_model.py

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy import DateTime, func

class Base(DeclarativeBase): pass

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

class BaseModel(Base, TimestampMixin):
    __abstract__ = True   # ← crítico: sin esto SQLAlchemy intenta crear tabla "basemodel"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
```

Todos los modelos heredan de `BaseModel` y solo declaran sus propios campos. `id`, `created_at`, `updated_at` vienen incluidos.

### base_repository.py

```python
T = TypeVar("T", bound=BaseModel)

class BaseRepository(Generic[T]):
    def __init__(self, model: Type[T], session: AsyncSession):
        self.model = model
        self.session = session

    async def get_by_id(self, id: int) -> T | None
    async def get_or_404(self, id: int) -> T           # lanza HTTP 404 si no existe
    async def get_all(self, limit, offset) -> list[T]
    async def create(self, data: Any) -> T
    async def update(self, obj: T, data: Any) -> T     # usa exclude_unset=True
    async def delete(self, obj: T) -> None
    async def exists(self, id: int) -> bool
```

Los repos de módulo heredan de `BaseRepository[MiModelo]` y solo agregan queries propias del dominio.

> **`exclude_unset=True` en update:** si el cliente manda `{"name": "Juan"}` sin incluir el `email`, el email no se pisa. Solo se actualizan los campos enviados.

### event_bus.py

```python
class EventBus:
    def __init__(self):
        self._handlers: dict[str, list[Callable]] = defaultdict(list)

    def subscribe(self, event: str, handler: Callable) -> None:
        self._handlers[event].append(handler)

    async def publish(self, event: str, payload: Any = None) -> None:
        for handler in self._handlers.get(event, []):
            try:
                await handler(payload)
            except Exception as e:
                # Un handler que falla no rompe el flujo principal
                logger.error(f"Error en handler '{handler.__name__}': {e}")

bus = EventBus()  # singleton global
```

### exceptions.py

```python
class AppException(Exception):
    status_code: int = 500
    detail: str = "Error interno"

class NotFoundException(AppException):       status_code = 404
class AlreadyExistsException(AppException):  status_code = 409
class UnauthorizedException(AppException):   status_code = 401
class ForbiddenException(AppException):      status_code = 403
class ValidationException(AppException):     status_code = 422
```

Handler global en `main.py`:

```python
@app.exception_handler(AppException)
async def app_exception_handler(request, exc: AppException):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
```

### response.py

```python
class ApiResponse(BaseModel, Generic[T]):
    success: bool = True
    data: T | None = None
    message: str | None = None

class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    size: int
    pages: int
```

### pagination.py

```python
def get_pagination(
    page: int = Query(default=1, ge=1),
    size: int = Query(default=20, ge=1, le=100),
) -> PaginationParams: ...

# Uso: GET /users?page=2&size=10
```

---

## 6. Patrón de módulo

Cada módulo en `modules/X/` tiene exactamente 7 archivos con responsabilidades estrictas.

### Responsabilidad de cada capa

| Archivo | Responsabilidad | Lo que NO hace |
|---------|----------------|----------------|
| `router.py` | HTTP: valida entrada, llama al service, devuelve respuesta | Lógica de negocio, queries SQL |
| `service.py` | Reglas de negocio, orquestación, publicar eventos | Queries SQL, HTTP |
| `repository.py` | Queries SQL con SQLAlchemy | Reglas de negocio, HTTP |
| `models.py` | Definición de tablas SQLAlchemy | — |
| `schemas.py` | Validación de entrada/salida con Pydantic | — |
| `dependencies.py` | Construcción del grafo service → repo → db | — |
| `exceptions.py` | Excepciones propias del dominio | — |

### router.py

```python
router = APIRouter(prefix="/users", tags=["users"])

@router.post("/", response_model=ApiResponse[UserResponseSchema], status_code=201)
async def create_user(
    data: UserCreateSchema,
    service: UserService = Depends(get_user_service),
):
    user = await service.create_user(data)
    return ApiResponse(data=UserResponseSchema.model_validate(user))

@router.get("/{user_id}", response_model=ApiResponse[UserResponseSchema])
async def get_user(user_id: int, service: UserService = Depends(get_user_service)):
    user = await service.get_by_id(user_id)
    return ApiResponse(data=UserResponseSchema.model_validate(user))
```

### schemas.py

```python
class UserCreateSchema(BaseModel):
    email: EmailStr
    name: str
    password: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Mínimo 8 caracteres")
        return v

class UserResponseSchema(BaseModel):
    id: int
    email: str
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}  # permite crear desde ORM objects
```

### service.py

```python
class UserService(BaseService):
    def __init__(self, repo: UserRepository):
        self.repo = repo

    async def create_user(self, data: UserCreateSchema) -> User:
        self._log_action("create_user", f"email={data.email}")

        existing = await self.repo.get_by_email(data.email)
        if existing:
            raise EmailAlreadyExistsException()

        data.password_hash = hash_password(data.password)
        user = await self.repo.create(data)

        await bus.publish("user.registered", {"user_id": user.id, "email": user.email})
        return user
```

### repository.py

```python
class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession):
        super().__init__(User, session)

    # Solo queries específicas del dominio
    async def get_by_email(self, email: str) -> User | None:
        result = await self.session.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()
```

### dependencies.py

```python
def get_user_repository(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)

def get_user_service(
    repo: UserRepository = Depends(get_user_repository),
) -> UserService:
    return UserService(repo)

# FastAPI resuelve la cadena: Request → get_db() → get_user_repository() → get_user_service()
```

### exceptions.py

```python
class UserNotFoundException(NotFoundException):
    detail = "Usuario no encontrado"

class EmailAlreadyExistsException(AlreadyExistsException):
    detail = "Ya existe una cuenta con este email"
```

---

## 7. Sistema de eventos — event_bus

### El problema que resuelve

Los módulos necesitan comunicarse sin acoplarse. Cuando `auth` registra un usuario, `notifications` tiene que enviar un email — pero `auth` no puede importar `NotificationService` directamente.

> **Regla absoluta:** un módulo NUNCA importa clases de otro módulo. Toda comunicación entre módulos ocurre a través del `event_bus`.

### Flujo

```
auth/service.py
  → bus.publish("user.registered", payload)
    → EventBus entrega a todos los handlers suscritos
      → notifications/events.py: on_user_registered(payload)
      → analytics/events.py: on_user_registered(payload)
```

### Módulo que emite

```python
# modules/auth/service.py
from app.shared.event_bus import bus

async def register(self, data):
    user = await self.repo.create(data)
    await bus.publish("user.registered", {
        "user_id": user.id,
        "email": user.email,
        "name": user.name,
    })
    return user
```

### Módulo que reacciona

```python
# modules/notifications/events.py
from app.shared.event_bus import bus

async def on_user_registered(payload: dict):
    await NotificationService().send_welcome_email(
        payload["email"], payload["name"]
    )

# Se registra en core/lifespan.py al arrancar la app:
bus.subscribe("user.registered", on_user_registered)
```

### Evolución del bus según la escala

| Etapa | Implementación |
|-------|---------------|
| Monolito modular (ahora) | `EventBus` in-process en memoria |
| Crecimiento intermedio | Redis Pub/Sub |
| Microservicios | RabbitMQ (`aio-pika`) o Kafka |

Al migrar, el `service.py` no cambia — sigue llamando a `bus.publish()`. Solo cambia la implementación interna del bus.

> Diseñar los handlers para ser **idempotentes** desde el principio. En el bus in-process la entrega es única, pero en Kafka/RabbitMQ puede repetirse.

---

## 8. Inyección de dependencias — FastAPI Depends()

FastAPI tiene DI nativo basado en funciones. Cada módulo define su cadena en `dependencies.py`.

### Cadena de dependencias

```python
# HTTP Request
#   → get_db()                  ← abre sesión AsyncSession
#     → get_user_repository()   ← construye UserRepository(session)
#       → get_user_service()    ← construye UserService(repo)
#         → endpoint()          ← recibe service listo para usar
```

### Dependencias de seguridad

```python
# modules/auth/dependencies.py
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    repo: UserRepository = Depends(get_user_repository),
) -> User:
    payload = decode_jwt_token(token)
    if not payload:
        raise UnauthorizedException()
    return await repo.get_or_404(payload["user_id"])

async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_admin:
        raise ForbiddenException()
    return current_user

# Uso en endpoints:
@router.get("/admin/users")
async def list_all_users(
    _: User = Depends(require_admin),           # solo admins
    service: UserService = Depends(get_user_service),
): ...

@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return ApiResponse(data=UserResponseSchema.model_validate(current_user))
```

---

## 9. Sistema de migraciones — Alembic

Alembic usa `psycopg2` (sync) en migraciones aunque el runtime use `asyncpg`. **Es intencional** — Alembic no necesita async para migraciones secuenciales y mezclar drivers causó problemas.

### migrations/env.py — completo

```python
from logging.config import fileConfig
from sqlalchemy import create_engine, pool
from alembic import context
from app.shared.base_model import Base
from app.core.config import settings

# ── Importar TODOS los modelos aquí ────────────────────────────────────
# Sin estos imports, Alembic no detecta las tablas en --autogenerate
from app.modules.auth.models import User, RefreshToken
# from app.modules.orders.models import Order    ← agregar al crear módulo

config = context.config
config.set_main_option(
    "sqlalchemy.url",
    settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql+psycopg2"),
)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata,
                      literal_binds=True, dialect_opts={"paramstyle": "named"})
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = create_engine(
        settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql+psycopg2"),
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

### Flujo al crear un módulo nuevo

```bash
# 1. Crear el módulo
make module name=orders

# 2. Completar models.py con los campos reales

# 3. Agregar el import en migrations/env.py
from app.modules.orders.models import Order

# 4. Generar la migración
make migration name=create_orders_tables

# 5. Revisar el archivo generado en migrations/versions/ — siempre

# 6. Aplicar
make migrate

# 7. Registrar el router en app/main.py
app.include_router(orders_router, prefix="/api/v1")
```

### Data migration — cuando hay que mover datos

```python
def upgrade() -> None:
    # 1. Agregar columna nullable primero
    op.add_column("users", sa.Column("full_name", sa.String(200), nullable=True))

    # 2. Poblar con datos existentes
    op.execute("UPDATE users SET full_name = name WHERE full_name IS NULL")

    # 3. Hacer NOT NULL después de poblar
    op.alter_column("users", "full_name", nullable=False)

    # 4. Borrar columna vieja en una MIGRACIÓN SEPARADA (más seguro)
    # op.drop_column("users", "name")
```

### Reglas críticas de migraciones

- Nunca modificar una migración ya mergeada a `main`. Crear una nueva que corrija el estado.
- Nunca modificar la base de datos en producción manualmente. Todo pasa por Alembic.
- Siempre revisar el archivo generado antes de aplicar — Alembic puede equivocarse con renombres.
- Las migraciones corren en CI/CD antes de que el nuevo código esté activo.

---

## 10. Autenticación JWT

### Flujo completo

```
POST /api/v1/auth/register  →  crea User  →  devuelve access_token + refresh_token
POST /api/v1/auth/login     →  verifica password  →  devuelve tokens
POST /api/v1/auth/refresh   →  verifica refresh_token en DB  →  nuevo access_token
POST /api/v1/auth/logout    →  invalida refresh_token en DB
```

### Dónde vive cada pieza

| Responsabilidad | Archivo |
|----------------|---------|
| Generar y decodificar JWT | `core/security.py` → `create_access_token()`, `decode_token()` |
| Hashear y verificar passwords | `core/security.py` → `hash_password()`, `verify_password()` |
| Dependency de autenticación | `modules/auth/dependencies.py` → `get_current_user()` |
| Guardar refresh token en DB | `modules/auth/repository.py` |
| Lógica de registro/login | `modules/auth/service.py` |

### Tokens

- `access_token`: vida corta (15-60 min), verificado en cada request con la `SECRET_KEY`
- `refresh_token`: vida larga (30 días), guardado en DB, invalidable manualmente en logout
- `SECRET_KEY`: generado con `openssl rand -hex 32`, solo en `.env`, nunca en código

### Dependencias de seguridad

```python
# modules/auth/dependencies.py
from app.core.security import decode_token

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    repo: UserRepository = Depends(get_user_repository),
) -> User:
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise UnauthorizedException()
    return await repo.get_or_404(int(payload["sub"]))

async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_admin:
        raise ForbiddenException()
    return current_user
```

### Proteger un endpoint

```python
@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return ApiResponse(data=UserResponseSchema.model_validate(current_user))

@router.delete("/{user_id}")
async def delete_user(
    user_id: int,
    _: User = Depends(require_admin),           # solo admins
    service: UserService = Depends(get_user_service),
):
    await service.delete(user_id)
```

---

## 11. Workers y tareas asíncronas — Celery

### Cuándo usar Celery

| Situación | Solución |
|-----------|---------|
| Respuesta inmediata requerida | FastAPI async directamente |
| Tarea que puede tardar segundos | Celery task con `.delay()` |
| Tarea programada (cron) | Celery Beat |
| Tarea que tarda minutos/horas | Celery con result backend en Redis |

### workers/celery_app.py

```python
from celery import Celery
from app.core.config import settings

celery_app = Celery(
    "worker",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["workers.tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    timezone="America/Panama",
    enable_utc=True,
    task_acks_late=True,           # confirma recibo solo después de ejecutar
    worker_prefetch_multiplier=1,  # una tarea a la vez por worker
)
```

### workers/tasks.py

```python
from workers.celery_app import celery_app

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_welcome_email_task(self, user_email: str, user_name: str):
    try:
        send_email(to=user_email, subject=f"Bienvenido, {user_name}", ...)
    except Exception as exc:
        # Reintenta con backoff: 60s, 120s, 240s
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))

@celery_app.task
def process_uploaded_image_task(image_bytes: bytes, user_id: int):
    thumbnail = create_thumbnail(image_bytes, size=(200, 200))
    url = upload_file(f"avatars/{user_id}/thumb.jpg", thumbnail, "image/jpeg")
    update_user_avatar(user_id, url)
```

### Disparar desde un service

```python
# service.py — despacha sin esperar
from workers.tasks import send_welcome_email_task

class AuthService:
    async def register(self, data):
        user = await self.repo.create(data)
        send_welcome_email_task.delay(user.email, user.name)  # retorna inmediato
        return user
```

### workers/beat_schedule.py — tareas periódicas

```python
from celery.schedules import crontab

CELERY_BEAT_SCHEDULE = {
    "cleanup-expired-sessions": {
        "task": "workers.tasks.cleanup_expired_sessions",
        "schedule": crontab(hour=2, minute=0),   # cada día a las 2:00 AM
    },
    "sync-external-api": {
        "task": "workers.tasks.sync_external_api",
        "schedule": crontab(minute=0),            # cada hora
    },
    "refresh-cache": {
        "task": "workers.tasks.refresh_dashboard_cache",
        "schedule": 300.0,                        # cada 5 minutos
    },
}
```

### Arrancar los workers

```bash
# Worker principal
celery -A workers.celery_app worker --loglevel=info --concurrency=4

# Beat (scheduler — solo una instancia siempre)
celery -A workers.celery_app beat --loglevel=info

# Monitor visual (opcional)
celery -A workers.celery_app flower --port=5555
```

---

## 12. Sistema de errores

### Jerarquía completa

```
Exception
└── AppException  (status=500)
    ├── NotFoundException       (404)
    ├── AlreadyExistsException  (409)
    ├── UnauthorizedException   (401)
    ├── ForbiddenException      (403)
    └── ValidationException     (422)
```

### Formato de respuesta

Todos los errores devuelven el mismo formato:

```json
{ "detail": "Mensaje legible para el cliente" }
```

### Excepciones de módulo

```python
# modules/users/exceptions.py
class UserNotFoundException(NotFoundException):
    detail = "Usuario no encontrado"

class EmailAlreadyExistsException(AlreadyExistsException):
    detail = "Ya existe una cuenta con este email"

# Se lanza en el service — FastAPI lo convierte a HTTP 404/409 automáticamente
raise UserNotFoundException()
```

---

## 13. Testing

### Estructura

```
tests/
├── conftest.py              ← fixtures globales (db, client, auth headers)
└── modules/
    └── auth/
        ├── test_router.py   ← tests de integración HTTP
        └── test_service.py  ← tests unitarios de lógica
```

### conftest.py

```python
@pytest.fixture
async def session() -> AsyncSession:
    # sesión de test con rollback automático al terminar

@pytest.fixture
async def client(session) -> AsyncClient:
    # httpx AsyncClient con override de get_db → session de test

@pytest.fixture
async def auth_headers(client) -> dict:
    # registra un usuario de test y devuelve los headers de autenticación
    response = await client.post("/api/v1/auth/login", json={...})
    token = response.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}
```

### test_router.py — test de integración

```python
async def test_create_user_returns_201(client):
    response = await client.post("/api/v1/users/", json={
        "email": "test@test.com", "name": "Test", "password": "password123"
    })
    assert response.status_code == 201
    assert response.json()["data"]["email"] == "test@test.com"

async def test_create_duplicate_user_returns_409(client):
    data = {"email": "dup@test.com", "name": "Dup", "password": "password123"}
    await client.post("/api/v1/users/", json=data)
    response = await client.post("/api/v1/users/", json=data)
    assert response.status_code == 409
```

### Convención

- Tests de router: flujo HTTP completo (request → response)
- Tests de service: lógica de negocio con mocks del repository
- Cada módulo nuevo necesita al menos un test por endpoint

---

## 14. Linting y tipos

### ruff — reemplaza black + isort + flake8

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP"]
```

```bash
make lint      # solo verifica
make format    # verifica + arregla automáticamente
```

### mypy — tipado estricto

```toml
[tool.mypy]
python_version = "3.12"
strict = true
ignore_missing_imports = true
```

```bash
make typecheck
make check     # lint + typecheck juntos (correr antes de cada commit)
```

---

## 15. Variables de entorno

### .env (local, NO en git)

```env
# App
ENVIRONMENT=development
DEBUG=true
SECRET_KEY=<openssl rand -hex 32>

# Base de datos
DATABASE_URL=postgresql+asyncpg://devuser:devpass@localhost:5432/appdb

# Redis
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/1
CELERY_RESULT_BACKEND=redis://localhost:6379/2

# Storage (MinIO local)
S3_ENDPOINT=http://localhost:9000
S3_BUCKET=dev-bucket
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_PUBLIC_URL=http://localhost:9000/dev-bucket

# Email (opcional)
MAIL_SERVER=smtp.gmail.com
MAIL_USERNAME=your@email.com
MAIL_PASSWORD=app-specific-password
MAIL_FROM=noreply@yourdomain.com
```

### Regla

Cada variable nueva → agregar a `.env.example` con valor de ejemplo **inmediatamente**. Ese archivo es el contrato con el equipo.

---

## 16. Módulos existentes

| Módulo | Estado | Endpoints principales |
|--------|--------|-----------------------|
| `auth` | 🔄 En progreso | POST /register, POST /login, POST /refresh, POST /logout |

> Actualizar esta tabla al agregar módulos.

---

## 17. Extracción a microservicio

### Cuándo vale la pena

Un módulo se extrae cuando necesita escalar independientemente, tiene un equipo propio, o el ciclo de deployment del monolito es demasiado lento. No hay que apresurarse.

### Por qué es fácil en este diseño

Cada módulo ya cumple estas condiciones desde el día uno:
- **Router propio** → se convierte en el `main.py` del microservicio
- **Repository propio** → accede a su porción de datos sin queries cruzadas
- **Sin imports entre módulos** → la única dependencia es el `event_bus`
- **Eventos propios** → define qué emite y qué consume

### Paso a paso: extraer `notifications/`

```bash
# 1. Copiar el módulo a un nuevo repositorio
mkdir ../notifications-service
cp -r backend/app/modules/notifications/ ../notifications-service/app/
cp -r backend/app/shared/               ../notifications-service/app/
cp -r backend/app/infrastructure/       ../notifications-service/app/
cp -r backend/app/core/                 ../notifications-service/app/
```

```python
# 2. Crear el main.py del nuevo servicio
@asynccontextmanager
async def lifespan(app: FastAPI):
    await start_consumer()  # escucha RabbitMQ en vez del bus in-process
    yield

app = FastAPI(title="Notifications Service")
app.include_router(notifications_router, prefix="/api/v1")
```

```python
# 3. En el monolito: cambiar bus.publish() → publish_message() (RabbitMQ)
# El service.py no cambia — solo la implementación del bus
await publish_message(
    exchange="user.events",
    routing_key="user.registered",
    payload={"user_id": user.id, "email": user.email},
)
```

```bash
# 4. Borrar el módulo del monolito
rm -rf backend/app/modules/notifications/
# El resto del monolito no sabe que desapareció
```

---

## 18. Convenciones de código

| Elemento | Convención | Ejemplo |
|----------|-----------|---------|
| Variables y funciones | snake_case | `get_user_by_email` |
| Clases | PascalCase | `UserService` |
| Schemas Pydantic | sufijo `Schema` | `UserCreateSchema`, `UserResponseSchema` |
| Modelos SQLAlchemy | sin sufijo | `User`, `RefreshToken` |
| Excepciones de módulo | hereda de shared | `UserNotFoundException(NotFoundException)` |
| Archivos | snake_case | `base_repository.py` |
| URLs de endpoints | kebab-case | `/api/v1/refresh-token` |
| Respuestas | siempre `ApiResponse[T]` o `PaginatedResponse[T]` | — |
| Eventos del bus | `dominio.accion` | `"user.registered"`, `"order.created"` |

### Anti-patrones a evitar

- Poner lógica de negocio en el router
- Hacer queries SQL en el service
- Importar clases de otro módulo directamente
- Usar `os.environ` fuera de `config.py`
- Modificar migraciones ya mergeadas

---

## 19. Comandos

```bash
# Desarrollo
make dev                          # FastAPI con hot reload en :8000
                                  # Swagger: http://localhost:8000/docs

# Tests
make test                         # pytest con cobertura
make test-fast                    # sin cobertura (más rápido)

# Calidad de código
make lint                         # ruff check
make format                       # ruff format + fix
make typecheck                    # mypy
make check                        # lint + typecheck juntos

# Migraciones
make migrate                      # alembic upgrade head
make migrate-down                 # alembic downgrade -1
make migrate-history              # ver historial
make migrate-status               # versión actual de la DB
make migration name=descripcion   # generar migración nueva

# Módulos
make module name=orders           # crear módulo con create_module.sh

# Workers
celery -A workers.celery_app worker --loglevel=info --concurrency=4
celery -A workers.celery_app beat  --loglevel=info
celery -A workers.celery_app flower --port=5555

# Infraestructura
make infra-up                     # levantar Postgres + Redis + MinIO
make infra-down
make infra-logs
make infra-ps
```

---

*Última actualización: ver historial de git de este archivo.*
