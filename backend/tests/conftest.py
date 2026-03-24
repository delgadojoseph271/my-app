# backend/tests/conftest.py
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.main import app
from app.infrastructure.database import get_db
from app.shared.base_model import Base

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="session")
def engine():
    return create_async_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
    )


@pytest.fixture(scope="session")
def session_factory(engine):
    return async_sessionmaker(engine, expire_on_commit=False)


@pytest_asyncio.fixture(scope="session", autouse=True)
async def create_tables(engine):
    """Crea las tablas una vez para toda la sesión."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture(autouse=True)
async def clean_tables(engine):
    """
    Limpia los datos entre tests truncando las tablas.
    autouse=True → se ejecuta automáticamente antes de cada test.
    Esto reemplaza el enfoque de rollback que no funcionaba
    porque FastAPI usaba su propia sesión con su propio commit.
    """
    yield  # el test corre aquí
    # después del test, borrar todos los datos
    async with engine.begin() as conn:
        # SQLite no tiene TRUNCATE, usamos DELETE
        await conn.execute(text("DELETE FROM refresh_tokens"))
        await conn.execute(text("DELETE FROM users"))


@pytest_asyncio.fixture
async def client(session_factory) -> AsyncClient:
    """
    Cliente HTTP que reemplaza get_db con la sesión de prueba.
    """

    async def override_get_db():
        async with session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest.fixture
def user_data() -> dict:
    return {
        "email": "test@example.com",
        "password": "password123",
        "name": "Usuario Test",
    }


@pytest_asyncio.fixture
async def registered_user(client: AsyncClient, user_data: dict) -> dict:
    response = await client.post("/api/v1/auth/register", json=user_data)
    assert response.status_code == 201
    return response.json()["data"]


@pytest_asyncio.fixture
async def auth_headers(registered_user: dict) -> dict:
    token = registered_user["access_token"]
    return {"Authorization": f"Bearer {token}"}
