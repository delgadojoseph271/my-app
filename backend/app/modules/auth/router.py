from fastapi import APIRouter, Depends, status
from app.modules.auth.schemas import (
    AuthCreateSchema,
    AuthUpdateSchema,
    AuthResponseSchema,
)
from app.modules.auth.service import AuthService
from app.modules.auth.dependencies import get_auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/", response_model=list[AuthResponseSchema])
async def list_auth(
    service: AuthService = Depends(get_auth_service),
):
    return await service.get_all()


@router.get("/{id}", response_model=AuthResponseSchema)
async def get_auth(
    id: int,
    service: AuthService = Depends(get_auth_service),
):
    return await service.get_by_id(id)


@router.post("/", response_model=AuthResponseSchema, status_code=status.HTTP_201_CREATED)
async def create_auth(
    data: AuthCreateSchema,
    service: AuthService = Depends(get_auth_service),
):
    return await service.create(data)


@router.patch("/{id}", response_model=AuthResponseSchema)
async def update_auth(
    id: int,
    data: AuthUpdateSchema,
    service: AuthService = Depends(get_auth_service),
):
    return await service.update(id, data)


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_auth(
    id: int,
    service: AuthService = Depends(get_auth_service),
):
    await service.delete(id)
