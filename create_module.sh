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
# Toma la primera letra en mayúscula y elimina la 's' final si existe
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

mkdir -p "${MODULE_DIR}/tests"

# ── __init__.py ───────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/__init__.py" << EOF
EOF

# ── models.py ─────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/models.py" << EOF
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Boolean
from app.shared.base_model import Base


class ${CLASS_NAME}(BaseModel):
    __tablename__ = "${MODULE_NAME}"

    # Agregá tus columnas aquí
    # Ejemplo:
    # name: Mapped[str] = mapped_column(String(255))
    # is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    pass
EOF

# ── schemas.py ────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/schemas.py" << EOF
from pydantic import BaseModel


class ${CLASS_NAME}CreateSchema(BaseModel):
    """Schema para crear un ${CLASS_NAME}."""
    # Agregá los campos requeridos
    # name: str
    pass


class ${CLASS_NAME}UpdateSchema(BaseModel):
    """Schema para actualizar un ${CLASS_NAME} (todos los campos opcionales)."""
    # name: str | None = None
    pass


class ${CLASS_NAME}ResponseSchema(BaseModel):
    """Schema de respuesta al cliente."""
    id: int
    # name: str

    model_config = {"from_attributes": True}
EOF

# ── repository.py ─────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/repository.py" << EOF
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.modules.${MODULE_NAME}.models import ${CLASS_NAME}
from app.shared.base_repository import BaseRepository


class ${CLASS_NAME}Repository(BaseRepository[${CLASS_NAME}]):
    def __init__(self, session: AsyncSession):
        super().__init__(${CLASS_NAME}, session)

    # Agregá queries específicas del módulo aquí
    # Ejemplo:
    # async def get_by_name(self, name: str) -> ${CLASS_NAME} | None:
    #     result = await self.session.execute(
    #         select(${CLASS_NAME}).where(${CLASS_NAME}.name == name)
    #     )
    #     return result.scalar_one_or_none()
EOF

# ── service.py ────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/service.py" << EOF
from app.modules.${MODULE_NAME}.repository import ${CLASS_NAME}Repository
from app.modules.${MODULE_NAME}.schemas import ${CLASS_NAME}CreateSchema, ${CLASS_NAME}UpdateSchema
from app.modules.${MODULE_NAME}.exceptions import ${CLASS_NAME}NotFoundError
from app.shared.event_bus import bus


class ${CLASS_NAME}Service:
    def __init__(self, repo: ${CLASS_NAME}Repository):
        self.repo = repo

    async def get_all(self) -> list:
        return await self.repo.get_all()

    async def get_by_id(self, id: int):
        return await self.repo.get_or_404(id)

    async def create(self, data: ${CLASS_NAME}CreateSchema):
        obj = await self.repo.create(data)
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

router = APIRouter(prefix="/${MODULE_NAME}", tags=["${MODULE_NAME}"])


@router.get("/", response_model=list[${CLASS_NAME}ResponseSchema])
async def list_${MODULE_NAME}(
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
):
    return await service.get_all()


@router.get("/{id}", response_model=${CLASS_NAME}ResponseSchema)
async def get_${CLASS_NAME,,}(
    id: int,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
):
    return await service.get_by_id(id)


@router.post("/", response_model=${CLASS_NAME}ResponseSchema, status_code=status.HTTP_201_CREATED)
async def create_${CLASS_NAME,,}(
    data: ${CLASS_NAME}CreateSchema,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
):
    return await service.create(data)


@router.patch("/{id}", response_model=${CLASS_NAME}ResponseSchema)
async def update_${CLASS_NAME,,}(
    id: int,
    data: ${CLASS_NAME}UpdateSchema,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
):
    return await service.update(id, data)


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_${CLASS_NAME,,}(
    id: int,
    service: ${CLASS_NAME}Service = Depends(get_${MODULE_NAME}_service),
):
    await service.delete(id)
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
cat > "${MODULE_DIR}/exceptions.py" << EOF
class ${CLASS_NAME}NotFoundError(Exception):
    def __init__(self, id: int):
        self.id = id
        super().__init__(f"${CLASS_NAME} con id {id} no encontrado")


class ${CLASS_NAME}AlreadyExistsError(Exception):
    def __init__(self, detail: str = ""):
        super().__init__(f"${CLASS_NAME} ya existe. {detail}".strip())
EOF

# ── events.py ─────────────────────────────────────────────────────────────────
cat > "${MODULE_DIR}/events.py" << EOF
from app.shared.event_bus import bus


# ── Handlers de eventos externos ──────────────────────────────────────────────
# Registrá aquí los eventos de otros módulos a los que este módulo reacciona.
# Los handlers se suscriben en core/lifespan.py

# Ejemplo: reaccionar cuando se crea un usuario
# async def on_user_created(payload: dict):
#     pass  # lógica aquí

# ── Registro (llamar desde core/lifespan.py) ──────────────────────────────────
def register_handlers():
    pass
    # bus.subscribe("user.created", on_user_created)
EOF

# ── tests/__init__.py + test base ─────────────────────────────────────────────
cat > "${MODULE_DIR}/tests/__init__.py" << EOF
EOF

cat > "${MODULE_DIR}/tests/test_${MODULE_NAME}.py" << EOF
import pytest
from unittest.mock import AsyncMock, MagicMock
from app.modules.${MODULE_NAME}.service import ${CLASS_NAME}Service
from app.modules.${MODULE_NAME}.schemas import ${CLASS_NAME}CreateSchema


@pytest.fixture
def mock_repo():
    return AsyncMock()


@pytest.fixture
def service(mock_repo):
    return ${CLASS_NAME}Service(mock_repo)


@pytest.mark.asyncio
async def test_get_by_id_calls_repo(service, mock_repo):
    mock_repo.get_or_404.return_value = MagicMock(id=1)
    result = await service.get_by_id(1)
    mock_repo.get_or_404.assert_called_once_with(1)
    assert result.id == 1


# Agregá más tests aquí
EOF

# ── Instrucciones post-creación ───────────────────────────────────────────────
echo "  ✓ Archivos creados:"
echo ""
find "${MODULE_DIR}" -type f | sort | sed 's/^/    /'
echo ""
echo "  ─────────────────────────────────────────────────────"
echo "  Pasos siguientes:"
echo ""
echo "  1. Registrar el router en backend/app/main.py:"
echo ""
echo "       from app.modules.${MODULE_NAME}.router import router as ${MODULE_NAME}_router"
echo "       app.include_router(${MODULE_NAME}_router, prefix=\"/api/v1\")"
echo ""
echo "  2. Registrar handlers en backend/app/core/lifespan.py:"
echo ""
echo "       from app.modules.${MODULE_NAME}.events import register_handlers as ${MODULE_NAME}_handlers"
echo "       ${MODULE_NAME}_handlers()"
echo ""
echo "  3. Importar el modelo en backend/migrations/env.py:"
echo ""
echo "       from app.modules.${MODULE_NAME}.models import ${CLASS_NAME}"
echo ""
echo "  4. Generar la migración:"
echo ""
echo "       alembic revision --autogenerate -m \"create_${MODULE_NAME}_table\""
echo "       alembic upgrade head"
echo ""
echo "  ─────────────────────────────────────────────────────"
echo ""
