from fastapi import APIRouter, Depends, status

from app.modules.auth.dependencies import (
    get_auth_service,
    get_current_user,
    require_admin,
)

from app.modules.auth.schemas import (
    AuthResponseSchema,
    LoginSchema,
    RefreshSchema,
    RegisterSchema,
    UserResponseSchema,
)
from app.modules.auth.service import AuthService
from app.modules.auth.models import User
from app.shared.response import ApiResponse


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=ApiResponse[AuthResponseSchema],
    status_code=status.HTTP_201_CREATED,
)
async def register(
    data: RegisterSchema, service: AuthService = Depends(get_auth_service)
) -> ApiResponse[AuthResponseSchema]:
    result = await service.register(data)
    return ApiResponse(data=result)


@router.post("/login", response_model=ApiResponse[AuthResponseSchema])
async def login(
    data: LoginSchema,
    service: AuthService = Depends(get_auth_service),
) -> ApiResponse[AuthResponseSchema]:
    result = await service.login(data)
    return ApiResponse(data=result)


@router.post(
    "/refresh",
    response_model=ApiResponse[AuthResponseSchema],
)
async def refresh(
    data: RefreshSchema, service: AuthService = Depends(get_auth_service)
) -> ApiResponse[AuthResponseSchema]:
    result = await service.refresh(data)
    return ApiResponse(data=result)


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def logout(
    data: RefreshSchema, service: AuthService = Depends(get_auth_service)
) -> None:
    # El access token expira solo.
    # Solo necesitamos el refresh token para invalidarlo en DB.
    await service.logout(data.refresh_token)


@router.post(
    "/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def logout_all(
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> None:
    """Cierra sesión en todos los dispositivos. Requiere estar autenticado."""
    await service.logout_all_devices(current_user.id)


# ── Endpoints que demuestran cómo usar los guards ────────────────────────────


@router.get("/me", response_model=ApiResponse[UserResponseSchema])
async def get_me(
    current_user: User = Depends(get_current_user),
) -> ApiResponse[UserResponseSchema]:
    """
    Endpoint protegido básico.
    get_current_user() verifica el JWT antes de llegar aquí.
    Si el token es inválido, FastAPI devuelve 401 automáticamente.
    """
    return ApiResponse(data=UserResponseSchema.model_validate(current_user))


@router.get(
    "/admin/users",
    response_model=ApiResponse[UserResponseSchema],
)
async def admin_only(
    _: User = Depends(require_admin),
) -> ApiResponse[dict]:
    """
    Endpoint solo para admins.
    require_admin() encadena get_current_user() + chequeo de rol.
    401 si no autenticado, 403 si autenticado pero no es admin.
    """
    return ApiResponse(data={"message": "Bienvenido, admin"})


# @router.get("/", response_model=list[AuthResponseSchema])
# async def list_auth(
#     service: AuthService = Depends(get_auth_service),
# ):
#     return await service.get_all()


# @router.get("/{id}", response_model=AuthResponseSchema)
# async def get_auth(
#     id: int,
#     service: AuthService = Depends(get_auth_service),
# ):
#     return await service.get_by_id(id)


# @router.post("/", response_model=AuthResponseSchema, status_code=status.HTTP_201_CREATED)
# async def create_auth(
#     data: AuthCreateSchema,
#     service: AuthService = Depends(get_auth_service),
# ):
#     return await service.create(data)


# @router.patch("/{id}", response_model=AuthResponseSchema)
# async def update_auth(
#     id: int,
#     data: AuthUpdateSchema,
#     service: AuthService = Depends(get_auth_service),
# ):
#     return await service.update(id, data)


# @router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
# async def delete_auth(
#     id: int,
#     service: AuthService = Depends(get_auth_service),
# ):
#     await service.delete(id)
