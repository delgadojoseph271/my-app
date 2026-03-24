from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.core.middleware import add_cors_middleware
from app.core.lifespan import lifespan
from app.modules.auth.router import router as auth_router
from app.shared.exceptions import AppException

app = FastAPI(
    title="My App API",
    version="0.1.0",
    lifespan=lifespan,
)
add_cors_middleware(app=app)


# Handler global — convierte cualquier AppException en la respuesta HTTP correcta
@app.exception_handler(AppException)
async def app_exception_handler(request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )


app.include_router(auth_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "env": settings.ENVIRONMENT}
