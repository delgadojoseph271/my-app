from fastapi import APIRouter, Depends, status
from app.modules.notifications.schemas import (
    NotificationCreateSchema,
    NotificationUpdateSchema,
    NotificationResponseSchema,
)
from app.modules.notifications.service import NotificationService
from app.modules.notifications.dependencies import get_notifications_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/", response_model=list[NotificationResponseSchema])
async def list_notifications(
    service: NotificationService = Depends(get_notifications_service),
):
    return await service.get_all()


@router.get("/{id}", response_model=NotificationResponseSchema)
async def get_notification(
    id: int,
    service: NotificationService = Depends(get_notifications_service),
):
    return await service.get_by_id(id)


@router.post("/", response_model=NotificationResponseSchema, status_code=status.HTTP_201_CREATED)
async def create_notification(
    data: NotificationCreateSchema,
    service: NotificationService = Depends(get_notifications_service),
):
    return await service.create(data)


@router.patch("/{id}", response_model=NotificationResponseSchema)
async def update_notification(
    id: int,
    data: NotificationUpdateSchema,
    service: NotificationService = Depends(get_notifications_service),
):
    return await service.update(id, data)


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_notification(
    id: int,
    service: NotificationService = Depends(get_notifications_service),
):
    await service.delete(id)
