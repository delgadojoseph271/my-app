from fastapi import APIRouter, Depends, status
from app.modules.users.schemas import (
    UserCreateSchema,
    UserUpdateSchema,
    UserResponseSchema,
)
from app.modules.users.service import UserService
from app.modules.users.dependencies import get_users_service

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/", response_model=list[UserResponseSchema])
async def list_users(
    service: UserService = Depends(get_users_service),
):
    return await service.get_all()


@router.get("/{id}", response_model=UserResponseSchema)
async def get_user(
    id: int,
    service: UserService = Depends(get_users_service),
):
    return await service.get_by_id(id)


@router.post("/", response_model=UserResponseSchema, status_code=status.HTTP_201_CREATED)
async def create_user(
    data: UserCreateSchema,
    service: UserService = Depends(get_users_service),
):
    return await service.create(data)


@router.patch("/{id}", response_model=UserResponseSchema)
async def update_user(
    id: int,
    data: UserUpdateSchema,
    service: UserService = Depends(get_users_service),
):
    return await service.update(id, data)


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    id: int,
    service: UserService = Depends(get_users_service),
):
    await service.delete(id)
