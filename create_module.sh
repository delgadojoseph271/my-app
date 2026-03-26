#!/usr/bin/env bash
# =============================================================================
# create_module.sh — Generador de módulos para el monolito modular FastAPI
# =============================================================================
# Uso:
#   bash create_module.sh <nombre_modulo>
#   bash create_module.sh notifications
#   bash create_module.sh orders
#
# Genera en: backend/app/modules/<nombre>/
# =============================================================================

set -e

# ── Validación ────────────────────────────────────────────────────────────────
if [ -z "$1" ]; then
  echo ""
  echo "  ✗ Falta el nombre del módulo"
  echo "  Uso: bash create_module.sh <nombre>"
  echo "  Ej:  bash create_module.sh notifications"
  echo ""
  exit 1
fi

MODULE_NAME="$1"
MODULE_DIR="backend/app/modules/${MODULE_NAME}"

# Nombre en PascalCase para los nombres de clase (ej: notifications → Notification)
BASE_NAME="$(echo "${MODULE_NAME}" | sed 's/_\([a-z]\)/\U\1/g; s/^\([a-z]\)/\U\1/')"
# Versión singular para nombres de clase (orders → Order, users → User)
if [[ "${BASE_NAME}" == *"s" ]]; then
  CLASS_NAME="${BASE_NAME%s}"
else
  CLASS_NAME="${BASE_NAME}"
fi

if [ -d "$MODULE_DIR" ]; then
  echo ""
  echo "  ✗ El módulo '${MODULE_NAME}' ya existe en ${MODULE_DIR}"
  echo ""
  exit 1
fi

echo ""
echo "  Creando módulo: ${MODULE_NAME}"
echo "  Clases:         ${CLASS_NAME}, ${CLASS_NAME}Service, ${CLASS_NAME}Repository"
echo "  Directorio:     ${MODULE_DIR}"
echo ""

mkdir -p "${MODULE_DIR}"
mkdir -p "tests/modules/${MODULE_NAME}"

# ── __init__.py ───────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/__init__.py" << EOF
EOF

# ── models.py ─────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/models.py" << EOF
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Boolean
from app.shared.base_model import BaseModel


class ${CLASS_NAME}(BaseModel):
    __tablename__ = "${MODULE_NAME}"

    # BaseModel provee: id, created_at, updated_at
    # Agregá tus columnas aquí:
    # name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    # is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    pass
EOF

# ── schemas.py ────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/schemas.py" << EOF
from datetime import datetime
from pydantic import BaseModel


# ── Entrada ───────────────────────────────────────────────────────────────────
class ${CLASS_NAME}CreateSchema(BaseModel):
    """Schema para crear un ${CLASS_NAME}."""
    # Agregá los campos requeridos:
    # name: str
    pass


class ${CLASS_NAME}UpdateSchema(BaseModel):
    """Schema para actualizar un ${CLASS_NAME}. Todos los campos opcionales."""
    # name: str | None = None
    pass


# ── Salida ────────────────────────────────────────────────────────────────────
class ${CLASS_NAME}ResponseSchema(BaseModel):
    """
    Schema de respuesta al cliente.
    NUNCA incluir campos sensibles (passwords, tokens internos, etc.)
    """
    id: int
    created_at: datetime
    # name: str

    # Permite crear este schema directamente desde un objeto ORM
    model_config = {"from_attributes": True}
EOF

# ── repository.py ─────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/repository.py" << EOF
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from app.modules.${MODULE_NAME}.models import ${CLASS_NAME}
from app.shared.base_repository import BaseRepository


class ${CLASS_NAME}Repository(BaseRepository[${CLASS_NAME}]):
    def __init__(self, session: AsyncSession):
        super().__init__(${CLASS_NAME}, session)

    # Agregá queries específicas del dominio aquí.
    # BaseRepository ya provee: get_by_id, get_or_404, get_all, create, update, delete, exists
    #
    # Regla: usar flush(), NUNCA commit(). El commit lo hace get_db() al terminar el request.
    # Si hacés DELETE y luego SELECT en la misma sesión, agregá flush() después del DELETE:
    #
    # async def delete_by_name(self, name: str) -> None:
    #     await self.session.execute(
    #         delete(${CLASS_NAME}).where(${CLASS_NAME}.name == name)
    #     )
    #     await self.session.flush()  # ← persiste en la transacción sin commitear
    #
    # async def get_by_name(self, name: str) -> ${CLASS_NAME} | None:
    #     result = await self.session.execute(
    #         select(${CLASS_NAME}).where(${CLASS_NAME}.name == name)
    #     )
    #     return result.scalar_one_or_none()
EOF

# ── service.py ────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/service.py" << EOF
import logging
from app.modules.${MODULE_NAME}.repository import ${CLASS_NAME}Repository
from app.modules.${MODULE_NAME}.schemas import ${CLASS_NAME}CreateSchema, ${CLASS_NAME}UpdateSchema
from app.modules.${MODULE_NAME}.exceptions import ${CLASS_NAME}NotFoundException
from app.shared.event_bus import bus

logger = logging.getLogger(__name__)


class ${CLASS_NAME}Service:
    def __init__(self, repo: ${CLASS_NAME}Repository):
        self.repo = repo

    async def get_all(self) -> list:
        return await self.repo.get_all()

    async def get_by_id(self, id: int):
        return await self.repo.get_or_404(id)

    async def create(self, data: ${CLASS_NAME}CreateSchema):
        logger.info(f"Creando ${CLASS_NAME}")
        obj = await self.repo.create(data)
        # Fire-and-forget: efectos secundarios que no bloquean la respuesta
        await bus.publish("${MODULE_NAME}.created", {"id": obj.id})
        return obj

    async def update(self, id: int, data: ${CLASS_NAME}UpdateSchema):
        obj = await self.repo.get_or_404(id)
        return await self.repo.update(obj, data)

    async def delete(self, id: int) -> None:
        obj = await self.repo.get_or_404(id)
        await self.repo.delete(obj)
        await bus.publish("${MODULE_NAME}.deleted", {"id": id})
EOF

# ── router.py ─────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/router.py" << EOF
from fastapi import APIRouter, Depends, status
from app.modules.${MODULE_NAME}.schemas import (
    ${CLASS_NAME}CreateSchema,
    ${CLASS_NAME}UpdateSchema,
    ${CLASS_NAME}ResponseSchema,
)
from app.modules.${MODULE_NAME}.service import ${CLASS_NAME}Service
from app.modules.${MODULE_NAME}.dependencies import get_${MODULE_NAME}_service
from app.shared.response import ApiResponse

router = APIRouter(prefix="/${MODULE_NAME}", tags=["${MODULE_NAME}"])


@router.get("/", response_model=ApiResponse[list[${CLASS_NAME}ResponseSchema]])
async def list_all(
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
) -> ApiResponse[list[${CLASS_NAME}ResponseSchema]]:
    items = await service.get_all()
    return ApiResponse(data=[${CLASS_NAME}ResponseSchema.model_validate(i) for i in items])


@router.get("/{id}", response_model=ApiResponse[${CLASS_NAME}ResponseSchema])
async def get_one(
    id: int,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
) -> ApiResponse[${CLASS_NAME}ResponseSchema]:
    obj = await service.get_by_id(id)
    return ApiResponse(data=${CLASS_NAME}ResponseSchema.model_validate(obj))


@router.post(
    "/",
    response_model=ApiResponse[${CLASS_NAME}ResponseSchema],
    status_code=status.HTTP_201_CREATED,
)
async def create(
    data: ${CLASS_NAME}CreateSchema,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
) -> ApiResponse[${CLASS_NAME}ResponseSchema]:
    obj = await service.create(data)
    return ApiResponse(data=${CLASS_NAME}ResponseSchema.model_validate(obj))


@router.patch("/{id}", response_model=ApiResponse[${CLASS_NAME}ResponseSchema])
async def update(
    id: int,
    data: ${CLASS_NAME}UpdateSchema,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
) -> ApiResponse[${CLASS_NAME}ResponseSchema]:
    obj = await service.update(id, data)
    return ApiResponse(data=${CLASS_NAME}ResponseSchema.model_validate(obj))


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete(
    id: int,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
) -> None:
    await service.delete(id)


# Para endpoints protegidos, agregar:
# from app.modules.auth.dependencies import get_current_user, require_admin
# from app.modules.auth.models import User
#
# current_user: User = Depends(get_current_user)  → cualquier usuario autenticado
# _: User = Depends(require_admin)                → solo admins (lanza 403 si no)
EOF

# ── dependencies.py ───────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/dependencies.py" << EOF
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.infrastructure.database import get_db
from app.modules.${MODULE_NAME}.repository import ${CLASS_NAME}Repository
from app.modules.${MODULE_NAME}.service import ${CLASS_NAME}Service


def get_${MODULE_NAME}_repository(
    db: AsyncSession = Depends(get_db),
) -> ${CLASS_NAME}Repository:
    return ${CLASS_NAME}Repository(db)


def get_${MODULE_NAME}_service(
    repo: ${CLASS_NAME}Repository = Depends(get_${MODULE_NAME}_repository),
) -> ${CLASS_NAME}Service:
    return ${CLASS_NAME}Service(repo)
EOF

# ── exceptions.py ─────────────────────────────────────────────────────────────
# CORRECCIÓN: heredan de AppException (jerarquía del proyecto), no de Exception base
cat > "${MODULE_DIR}/exceptions.py" << EOF
from app.shared.exceptions import NotFoundException, AlreadyExistsException


class ${CLASS_NAME}NotFoundException(NotFoundException):
    detail = "${CLASS_NAME} no encontrado"


class ${CLASS_NAME}AlreadyExistsException(AlreadyExistsException):
    detail = "${CLASS_NAME} ya existe"
EOF

# ── events.py ─────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/events.py" << EOF
from app.shared.event_bus import bus


# Registrá aquí los eventos de otros módulos a los que este módulo reacciona.
# Los handlers se suscriben en core/lifespan.py
#
# Ejemplo: reaccionar cuando se registra un usuario
# async def on_user_registered(payload: dict):
#     user_id = payload["user_id"]
#     # lógica aquí
#
# def register_handlers():
#     bus.subscribe("user.registered", on_user_registered)

def register_handlers():
    pass
EOF

# ── Tests ─────────────────────────────────────────────────────────────────────
cat > "tests/modules/${MODULE_NAME}/__init__.py" << EOF
EOF

cat > "tests/modules/${MODULE_NAME}/test_service.py" << EOF
import pytest
from unittest.mock import AsyncMock, MagicMock
from app.modules.${MODULE_NAME}.service import ${CLASS_NAME}Service
from app.modules.${MODULE_NAME}.exceptions import ${CLASS_NAME}NotFoundException


def make_service(repo=None) -> ${CLASS_NAME}Service:
    """Construye el service con un repo falso (AsyncMock)."""
    return ${CLASS_NAME}Service(repo=repo or AsyncMock())


async def test_get_by_id_llama_al_repo():
    repo = AsyncMock()
    repo.get_or_404.return_value = MagicMock(id=1)

    result = await make_service(repo).get_by_id(1)

    repo.get_or_404.assert_called_once_with(1)
    assert result.id == 1


async def test_delete_llama_al_repo():
    repo = AsyncMock()
    repo.get_or_404.return_value = MagicMock(id=1)

    await make_service(repo).delete(1)

    repo.get_or_404.assert_called_once_with(1)
    repo.delete.assert_called_once()


# Agregá tests específicos del dominio aquí.
# Patrón para testear que algo falla correctamente:
#
# async def test_create_falla_si_nombre_existe():
#     repo = AsyncMock()
#     repo.get_by_nombre.return_value = MagicMock()  # ya existe
#
#     with pytest.raises(${CLASS_NAME}AlreadyExistsException):
#         await make_service(repo).create(MagicMock(nombre="duplicado"))
#
#     repo.create.assert_not_called()  # nunca intentó crear
EOF

cat > "tests/modules/${MODULE_NAME}/test_router.py" << EOF
import pytest
from httpx import AsyncClient


async def test_crear_retorna_201(client: AsyncClient, auth_headers: dict):
    response = await client.post(
        "/api/v1/${MODULE_NAME}/",
        json={},  # completar con campos reales del schema
        headers=auth_headers,
    )
    assert response.status_code == 201


async def test_obtener_inexistente_retorna_404(client: AsyncClient, auth_headers: dict):
    response = await client.get("/api/v1/${MODULE_NAME}/99999", headers=auth_headers)
    assert response.status_code == 404


# Agregá tests de integración HTTP aquí.
# Cada endpoint debe tener al menos:
#   - test del flujo exitoso (happy path)
#   - test del caso de error principal
EOF

# ── Instrucciones post-creación ───────────────────────────────────────────────
echo "  ✓ Archivos creados:"
echo ""
find "${MODULE_DIR}" -type f | sort | sed 's/^/    /'
find "tests/modules/${MODULE_NAME}" -type f | sort | sed 's/^/    /'
echo ""
echo "  ─────────────────────────────────────────────────────────────"
echo "  Pasos siguientes:"
echo ""
echo "  1. Completar models.py con las columnas reales"
echo ""
echo "  2. Importar el modelo en backend/migrations/env.py:"
echo ""
echo "       from app.modules.${MODULE_NAME}.models import ${CLASS_NAME}"
echo ""
echo "  3. Generar y aplicar la migración:"
echo ""
echo "       make migration name=create_${MODULE_NAME}_table"
echo "       # revisar el archivo generado antes de aplicar"
echo "       make migrate"
echo ""
echo "  4. Registrar el router en backend/app/main.py:"
echo ""
echo "       from app.modules.${MODULE_NAME}.router import router as ${MODULE_NAME}_router"
echo "       app.include_router(${MODULE_NAME}_router, prefix=\"/api/v1\")"
echo ""
echo "  5. (Opcional) Registrar handlers de eventos en core/lifespan.py:"
echo ""
echo "       from app.modules.${MODULE_NAME}.events import register_handlers as ${MODULE_NAME}_handlers"
echo "       ${MODULE_NAME}_handlers()"
echo ""
echo "  ─────────────────────────────────────────────────────────────"
echo "  Checklist antes del PR:"
echo ""
echo "    [ ] models.py hereda de BaseModel (no de Base)"
echo "    [ ] Modelo importado en migrations/env.py"
echo "    [ ] Migración generada y revisada"
echo "    [ ] Schemas de entrada y salida separados"
echo "    [ ] repository.py usa flush(), nunca commit()"
echo "    [ ] service.py no hace queries SQL directamente"
echo "    [ ] router.py no tiene lógica de negocio"
echo "    [ ] exceptions.py hereda de AppException"
echo "    [ ] Al menos un test unitario y uno de integración"
echo ""
echo "  ─────────────────────────────────────────────────────────────"
echo ""
