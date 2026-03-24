from contextlib import asynccontextmanager
from fastapi import FastAPI

from app.infrastructure.database import engine
from sqlalchemy import text


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))
    yield
    # Shutdown
    await engine.dispose()
