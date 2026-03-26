# Auth profesional con FastAPI — Guía completa

> Documentación de lo implementado: sistema de autenticación JWT con access + refresh tokens,
> hashing de passwords con bcrypt, guards de rutas, y suite de tests completa.

---

## Tabla de contenidos

1. [Arquitectura general](#1-arquitectura-general)
2. [Fundamentos de seguridad](#2-fundamentos-de-seguridad)
3. [Estructura del módulo auth](#3-estructura-del-módulo-auth)
4. [core/security.py — la capa criptográfica](#4-coresecuritypy--la-capa-criptográfica)
5. [Los modelos: User y RefreshToken](#5-los-modelos-user-y-refreshtoken)
6. [Schemas — contratos de entrada y salida](#6-schemas--contratos-de-entrada-y-salida)
7. [Repository — las queries](#7-repository--las-queries)
8. [Service — la lógica de negocio](#8-service--la-lógica-de-negocio)
9. [Dependencies y guards](#9-dependencies-y-guards)
10. [Router — los endpoints](#10-router--los-endpoints)
11. [Sistema de tests](#11-sistema-de-tests)
12. [Bugs encontrados y resueltos](#12-bugs-encontrados-y-resueltos)
13. [Decisiones de arquitectura](#13-decisiones-de-arquitectura)
14. [Checklist de seguridad](#14-checklist-de-seguridad)

---

## 1. Arquitectura general

El flujo completo de autenticación tiene cinco fases:

```
POST /register  →  hash password  →  crear User  →  generar tokens  →  201
POST /login     →  verify password (bcrypt)  →  generar tokens  →  200
GET  /me        →  Bearer token  →  decode JWT  →  buscar user  →  200
POST /refresh   →  verify JWT  →  buscar en DB  →  rotar token  →  200
POST /logout    →  borrar refresh token de DB  →  204
```

**Principio central**: el access token vive solo en memoria (no se guarda en DB). El refresh token sí se guarda porque necesita poder invalidarse en logout.

---

## 2. Fundamentos de seguridad

### Por qué bcrypt

Los hashes simples (MD5, SHA256) son tan rápidos que un atacante puede probar millones de combinaciones por segundo. bcrypt es deliberadamente lento — tarda ~100ms por verificación. Insignificante para un usuario, devastador para un ataque de fuerza bruta.

bcrypt nunca desencripta. Al verificar:
1. Extrae el salt del hash guardado
2. Vuelve a hashear el password recibido con ese mismo salt
3. Compara los dos hashes

El salt está embebido en el hash — por eso `verify_password` solo necesita los dos strings.

### Por qué dos tokens

| Token | Vida | Se guarda en DB | Invalidable |
|-------|------|-----------------|-------------|
| Access token | 30 min | No | No (expira solo) |
| Refresh token | 30 días | Sí | Sí (logout lo borra) |

Si solo hubiera un token de vida larga, no habría forma de invalidarlo sin mantener una blacklist. Con dos tokens: el access expira solo (corto), el refresh es revocable (en DB).

### Anatomía de un JWT

```
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI0MiIsImV4cCI6MTcxNH0.SflKxwRJSM
     HEADER                      PAYLOAD                   SIGNATURE
```

- **Header**: algoritmo usado (HS256). Legible por todos.
- **Payload**: datos (`sub`, `exp`, `type`). Legible por todos — nunca poner datos sensibles.
- **Signature**: HMAC-SHA256(header+payload, SECRET_KEY). Solo el servidor puede generarla y verificarla.

Si alguien modifica el payload, la firma no coincide y el token es rechazado.

### El campo `type` en el payload

```python
{"sub": "42", "exp": 1714000000, "type": "access"}  # access token
{"sub": "42", "exp": 1776000000, "type": "refresh"}  # refresh token
```

Sin este campo, cualquier token válido funcionaría en cualquier endpoint. Con él, `get_current_user` puede exigir `type == "access"` y el endpoint `/refresh` puede exigir `type == "refresh"`.

### El campo `jti` en el refresh token

```python
{"sub": "42", "exp": ..., "type": "refresh", "jti": "uuid-único"}
```

`jti` (JWT ID) es un campo estándar del spec JWT que garantiza unicidad. Sin él, dos tokens generados en el mismo segundo para el mismo usuario serían idénticos — causando `UNIQUE constraint` en la DB.

---

## 3. Estructura del módulo auth

```
backend/app/
├── core/
│   └── security.py          ← hash, verify, create_token, decode_token
├── modules/
│   └── auth/
│       ├── models.py         ← User, RefreshToken
│       ├── schemas.py        ← RegisterSchema, LoginSchema, AuthResponseSchema
│       ├── repository.py     ← UserRepository, RefreshTokenRepository
│       ├── service.py        ← register, login, refresh, logout
│       ├── router.py         ← POST /register /login /refresh /logout /me
│       ├── dependencies.py   ← get_current_user, require_admin
│       └── exceptions.py     ← EmailAlreadyExistsException, InvalidCredentialsException
└── tests/
    ├── conftest.py
    └── modules/auth/
        ├── test_service.py   ← tests unitarios con mocks
        └── test_router.py    ← tests de integración HTTP
```

**Regla de flujo** (solo en esta dirección):
```
router → dependencies → service → repository → DB
```

---

## 4. `core/security.py` — la capa criptográfica

Centraliza toda la criptografía. Ningún módulo importa `python-jose` o `passlib` directamente.

```python
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "exp": expire,
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

def create_refresh_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=30)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "exp": expire,
        "type": "refresh",
        "jti": str(uuid.uuid4()),  # garantiza unicidad entre tokens
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

def decode_token(token: str) -> dict[str, Any] | None:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    except JWTError:
        return None  # nunca lanza excepción — el caller decide qué hacer con None
```

**Por qué `timezone.utc`**: sin él, Python usa la hora local del servidor. Si el servidor está en UTC-5, hay una diferencia de 5 horas en la expiración.

**Por qué `decode_token` retorna `None` en vez de lanzar**: token expirado, firma inválida, y formato corrupto son tres cosas distintas pero con el mismo outcome — rechazar. El caller recibe `None` y lanza el 401.

**`_DUMMY_HASH` en el service**: se computa una sola vez al importar el módulo:
```python
_DUMMY_HASH = hash_password("dummy-password-for-timing-protection")
```
Si se computara dentro del método `login`, el primer request siempre tardaría más — que es exactamente lo que la protección de timing attack intenta evitar.

---

## 5. Los modelos: User y RefreshToken

```python
class User(BaseModel):
    __tablename__ = "users"
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(
        "RefreshToken", back_populates="user", cascade="all, delete-orphan"
    )

class RefreshToken(BaseModel):
    __tablename__ = "refresh_tokens"
    token: Mapped[str] = mapped_column(String(512), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    user: Mapped["User"] = relationship("User", back_populates="refresh_tokens")
```

**`index=True` en `email` y `token`**: sin índice, cada login hace un full table scan. Con índice, es O(log n).

**`expires_at` en `RefreshToken`**: permite limpieza periódica con Celery sin decodificar JWTs.

**`ondelete="CASCADE"`**: si se borra un User, PostgreSQL borra sus tokens automáticamente.

**Por qué User está en `auth/` y no en `users/`**: User es fundamentalmente una entidad de autenticación. Separarlo requeriría que `auth/` importe de `users/`, violando la regla de dependencias entre módulos. Si el negocio crece, `users/` puede tener un `UserProfile` con FK a `user_id`.

---

## 6. Schemas — contratos de entrada y salida

**Regla**: nunca el mismo schema para entrada y salida. El schema de entrada puede tener `password`. El de salida nunca debe tener `password_hash`.

```python
# Entrada
class RegisterSchema(BaseModel):
    email: EmailStr
    password: str
    name: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Mínimo 8 caracteres")
        return v

# Salida — nunca incluye password_hash
class UserResponseSchema(BaseModel):
    id: int
    email: str
    name: str
    is_active: bool
    created_at: datetime
    model_config = {"from_attributes": True}

class AuthResponseSchema(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponseSchema
```

`model_config = {"from_attributes": True}` permite crear el schema directamente desde un objeto ORM.

---

## 7. Repository — las queries

Solo SQL. Sin lógica de negocio. Usa `flush()`, nunca `commit()`.

```python
class UserRepository(BaseRepository[User]):
    async def get_by_email(self, email: str) -> User | None:
        result = await self.session.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

class RefreshTokenRepository(BaseRepository[RefreshToken]):
    async def save(self, token: str, user_id: int, expires_at: datetime) -> RefreshToken:
        expires_at_naive = expires_at.replace(tzinfo=None)  # SQLite no maneja timezone
        refresh = RefreshToken(token=token, user_id=user_id, expires_at=expires_at_naive)
        self.session.add(refresh)
        await self.session.flush()
        return refresh

    async def get_by_token(self, token: str) -> RefreshToken | None:
        result = await self.session.execute(
            select(RefreshToken).where(RefreshToken.token == token)
        )
        return result.scalar_one_or_none()

    async def delete_by_token(self, token: str) -> None:
        await self.session.execute(delete(RefreshToken).where(RefreshToken.token == token))
        await self.session.flush()  # ← crítico: sin esto el DELETE no persiste en la sesión

    async def delete_all_for_user(self, user_id: int) -> None:
        await self.session.execute(
            delete(RefreshToken).where(RefreshToken.user_id == user_id)
        )
        await self.session.flush()
```

**Por qué `flush()` y no `commit()`**: `flush()` envía el SQL y obtiene el `id` generado, pero dentro de la misma transacción. El `commit()` real lo hace `get_db()` al terminar el request. Si algo falla después del `flush`, todo se hace rollback automáticamente.

**`flush()` después de DELETE**: sin él, la misma sesión puede devolver datos desactualizados del cache de identidad de SQLAlchemy si se consulta después de borrar.

---

## 8. Service — la lógica de negocio

### Timing attack

```python
_DUMMY_HASH = hash_password("dummy-password-for-timing-protection")

async def login(self, data: LoginSchema) -> AuthResponseSchema:
    user = await self.user_repo.get_by_email(data.email)

    if not user:
        verify_password(data.password, _DUMMY_HASH)  # ← mismo tiempo aunque no exista
        raise InvalidCredentialsException()

    if not verify_password(data.password, user.password_hash):
        raise InvalidCredentialsException()
```

Sin esto, medir el tiempo de respuesta revela si el email existe (2ms) o la contraseña es incorrecta (100ms de bcrypt).

### Rotación de refresh tokens

```python
async def refresh(self, data: RefreshSchema) -> AuthResponseSchema:
    payload = decode_token(data.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise InvalidTokenException()

    db_token = await self.token_repo.get_by_token(data.refresh_token)

    if not db_token:
        # Token válido criptográficamente pero no está en DB → posible robo
        user_id = int(payload["sub"])
        await self.token_repo.delete_all_for_user(user_id)  # respuesta defensiva
        raise InvalidTokenException()

    # Rotación: el token viejo muere, nace uno nuevo
    await self.token_repo.delete_by_token(data.refresh_token)
    return await self._generate_and_save_tokens(user)
```

Si alguien roba un refresh token y lo usa, el usuario legítimo intenta renovar con el token ya rotado → sistema detecta el conflicto → invalida todo.

### Mensajes de error genéricos

```python
class InvalidCredentialsException(UnauthorizedException):
    detail = "Credenciales inválidas"  # mismo mensaje para email incorrecto Y password incorrecto
```

Si diferenciás los mensajes, le decís al atacante cuál de los dos acertó.

---

## 9. Dependencies y guards

```python
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    user_repo: UserRepository = Depends(get_user_repository),
) -> User:
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise InvalidCredentialsException()
    user = await user_repo.get_by_id(int(payload["sub"]))
    if not user or not user.is_active:
        raise InvalidCredentialsException()
    return user

async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_admin:
        raise ForbiddenException()  # 403, no 401 — autenticado pero sin permiso
    return current_user
```

**401 vs 403**: 401 = no autenticado, 403 = autenticado pero sin permiso. La distinción importa para el cliente.

**Composición de guards**: `require_admin` llama a `get_current_user` — no repite la lógica. Se encadenan.

---

## 10. Router — los endpoints

```python
router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=ApiResponse[AuthResponseSchema], status_code=201)
async def register(data: RegisterSchema, service: AuthService = Depends(get_auth_service)):
    return ApiResponse(data=await service.register(data))

@router.get("/me", response_model=ApiResponse[UserResponseSchema])
async def get_me(current_user: User = Depends(get_current_user)):
    return ApiResponse(data=UserResponseSchema.model_validate(current_user))

@router.post("/logout", status_code=204)
async def logout(data: RefreshSchema, service: AuthService = Depends(get_auth_service)):
    await service.logout(data.refresh_token)
    # No retorna body — 204 No Content
```

El router no tiene lógica. Solo traduce HTTP al service y devuelve la respuesta.

---

## 11. Sistema de tests

### Estructura

```
tests/
├── conftest.py              ← fixtures globales
└── modules/auth/
    ├── test_service.py      ← tests unitarios (sin DB, con mocks)
    └── test_router.py       ← tests de integración (HTTP real → DB real)
```

### Por qué dos tipos de tests

- **Unitarios**: prueban la lógica del service en aislamiento. Rápidos. Usan mocks en vez de DB.
- **Integración**: prueban el flujo completo HTTP → service → DB → response. Lentos pero más realistas.

Si un test unitario pasa pero el de integración falla → el problema está en el router, schemas, o la conexión entre capas.

### conftest.py — las claves

```python
# SQLite en memoria — no necesita Docker, se crea y destruye sola
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture(autouse=True)
async def clean_tables(engine):
    """Limpia datos entre tests truncando las tablas."""
    yield
    async with engine.begin() as conn:
        await conn.execute(text("DELETE FROM refresh_tokens"))  # ← primero FK
        await conn.execute(text("DELETE FROM users"))

@pytest_asyncio.fixture
async def client(session_factory) -> AsyncClient:
    """Reemplaza get_db con la sesión de prueba."""
    async def override_get_db():
        async with session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
```

**Por qué `clean_tables` en vez de rollback**: FastAPI usa su propia sesión con su propio commit. El rollback de una sesión externa no puede deshacer lo que otra sesión ya commiteó. Truncar las tablas es más directo.

**Orden del DELETE**: primero `refresh_tokens` (tiene FK hacia `users`), después `users`. Invertido causa error de foreign key.

### Tests unitarios — patrón con mocks

```python
def make_service(user_repo=None, token_repo=None):
    return AuthService(
        user_repo=user_repo or AsyncMock(),
        token_repo=token_repo or AsyncMock(),
    )

async def test_login_falla_con_email_inexistente():
    user_repo = AsyncMock()
    user_repo.get_by_email.return_value = None  # email no existe

    with pytest.raises(InvalidCredentialsException):
        await make_service(user_repo).login(MagicMock(email="x@x.com", password="pass"))
```

`AsyncMock` imita el repository pero no toca la DB. Se programa qué debe retornar cada llamada.

### Tests de integración — los más valiosos

```python
async def test_login_con_email_inexistente_retorna_mismo_error(client):
    """Verifica explícitamente que no filtramos información de seguridad."""
    response = await client.post("/api/v1/auth/login", json={
        "email": "noexiste@example.com", "password": "cualquier_cosa"
    })
    assert response.status_code == 401
    assert response.json()["detail"] == "Credenciales inválidas"  # mismo mensaje

async def test_refresh_token_usado_dos_veces_retorna_401(client, registered_user):
    """Verifica que la rotación de tokens funciona."""
    refresh_token = registered_user["refresh_token"]
    await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    response = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert response.status_code == 401
```

---

## 12. Bugs encontrados y resueltos

### `TypeVar` mal definido en `BaseRepository`

```python
# ❌ incorrecto
T = TypeVar('T', bound=BaseException)  # BaseException es para errores

# ✅ correcto
T = TypeVar('T', bound=BaseModel)  # BaseModel de SQLAlchemy
```

Causaba que SQLAlchemy retornara objetos con tipos incorrectos — de ahí el `'function' object has no attribute 'expires_at'`.

### `get_or_404` retornaba `None`

```python
# ❌ incorrecto
async def get_or_404(self, id: int) -> T:
    obj = await self.session.get(self.model, id)
    if obj is None:
        raise HTTPException(...)
    return None  # ← bug: siempre retorna None

# ✅ correcto
    return obj  # ← retorna el objeto encontrado
```

### `get_all` con `.limit()` en el lugar equivocado

```python
# ❌ incorrecto
select(self.model.limit(limit).offset(offset))  # limit() sobre el modelo

# ✅ correcto
select(self.model).limit(limit).offset(offset)  # limit() sobre la query
```

### `commit()` en el repository

```python
# ❌ incorrecto — rompe la transacción del request
await self.session.commit()

# ✅ correcto — el commit lo hace get_db() al terminar el request
await self.session.flush()
```

### DELETE sin `flush()` en tests

```python
# ❌ incorrecto — el DELETE no persiste en la sesión actual
await self.session.execute(delete(RefreshToken).where(...))

# ✅ correcto
await self.session.execute(delete(RefreshToken).where(...))
await self.session.flush()
```

### `UNIQUE constraint` en refresh_tokens

Dos tokens generados en el mismo segundo para el mismo usuario eran idénticos.

```python
# ✅ solución: agregar jti (JWT ID) al payload
"jti": str(uuid.uuid4())
```

### `can't compare offset-naive and offset-aware datetimes`

SQLite no guarda timezone info — devuelve datetimes sin timezone.

```python
# ✅ al leer de DB
expires_at = db_token.expires_at
if expires_at.tzinfo is None:
    expires_at = expires_at.replace(tzinfo=timezone.utc)

# ✅ al guardar en DB (normalizar antes)
expires_at_naive = expires_at.replace(tzinfo=None)
```

---

## 13. Decisiones de arquitectura

### Por qué `User` vive en `auth/` y no en `users/`

El event bus es para comunicación fire-and-forget (efectos secundarios que no bloquean la respuesta). No está diseñado para flujos sincrónicos donde el HTTP request está esperando una respuesta. Si `users/` tuviera que crear el usuario y `auth/` esperar el evento para generar tokens, no habría forma de retornar la respuesta sin callback o polling.

La regla: el event bus es para efectos secundarios. La lógica de negocio principal que tiene que responder al cliente es sincrónica y directa.

### Por qué el access token no se guarda en DB

Guardar el access token requeriría consultarlo en cada request — negando la ventaja principal de los JWT (verificación sin DB). La vida corta (30 min) es el mecanismo de invalidación. Si necesitás invalidación inmediata, la solución es una blacklist en Redis — con su propio costo operacional.

### Por qué SQLite en tests y no PostgreSQL

SQLite en memoria no necesita Docker, se crea y destruye sola, y es suficientemente compatible para nuestros propósitos. Los trade-offs (timezone handling diferente, TRUNCATE no disponible) son conocidos y manejables.

---

## 14. Checklist de seguridad

- [x] Passwords hasheados con bcrypt (nunca en texto plano)
- [x] `SECRET_KEY` generada con `openssl rand -hex 32`, solo en `.env`
- [x] Access token de vida corta (30 min)
- [x] Refresh token guardado en DB (invalidable en logout)
- [x] Campo `type` en JWT para distinguir access vs refresh
- [x] Campo `jti` en refresh token para garantizar unicidad
- [x] Protección de timing attack en login
- [x] Mensajes de error genéricos (no revelan si el email existe)
- [x] Rotación de refresh tokens (el viejo muere al usarse)
- [x] Respuesta defensiva ante reuso de token rotado
- [x] `is_active` verificado en login y refresh
- [x] 401 para no autenticado, 403 para sin permiso
- [x] `password_hash` ausente en todos los schemas de respuesta
- [x] Tests verifican explícitamente los comportamientos de seguridad

---

*Generado en base a la implementación del módulo auth — ver historial de git para cambios posteriores.*
