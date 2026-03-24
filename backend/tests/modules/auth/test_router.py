# backend/tests/modules/auth/test_router.py
from httpx import AsyncClient


# ── Register ──────────────────────────────────────────────────────────────────


async def test_register_retorna_201_con_tokens(client: AsyncClient, user_data: dict):
    response = await client.post("/api/v1/auth/register", json=user_data)

    assert response.status_code == 201
    body = response.json()["data"]
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["user"]["email"] == user_data["email"]
    # Verificar que nunca exponemos el password_hash
    assert "password_hash" not in body["user"]


async def test_register_con_email_duplicado_retorna_409(
    client: AsyncClient, user_data: dict
):
    # Primer registro — debe funcionar
    await client.post("/api/v1/auth/register", json=user_data)
    # Segundo registro con el mismo email — debe fallar
    response = await client.post("/api/v1/auth/register", json=user_data)

    assert response.status_code == 409


async def test_register_con_password_corto_retorna_422(
    client: AsyncClient, user_data: dict
):
    user_data["password"] = "corto"  # menos de 8 caracteres
    response = await client.post("/api/v1/auth/register", json=user_data)

    # 422 = Unprocessable Entity — validación de Pydantic
    assert response.status_code == 422


async def test_register_con_email_invalido_retorna_422(
    client: AsyncClient, user_data: dict
):
    user_data["email"] = "esto-no-es-un-email"
    response = await client.post("/api/v1/auth/register", json=user_data)

    assert response.status_code == 422


# ── Login ─────────────────────────────────────────────────────────────────────


async def test_login_exitoso_retorna_tokens(
    client: AsyncClient, registered_user: dict, user_data: dict
):
    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": user_data["email"],
            "password": user_data["password"],
        },
    )

    assert response.status_code == 200
    body = response.json()["data"]
    assert body["access_token"]
    assert body["token_type"] == "bearer"


async def test_login_con_password_incorrecto_retorna_401(
    client: AsyncClient, registered_user: dict, user_data: dict
):
    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": user_data["email"],
            "password": "password_INCORRECTA",
        },
    )

    assert response.status_code == 401
    # El mensaje es genérico — no revela si el email existe
    assert response.json()["detail"] == "Credenciales inválidas"


async def test_login_con_email_inexistente_retorna_mismo_error(
    client: AsyncClient,
):
    """
    Email inexistente debe dar el mismo error que password incorrecto.
    Si diera un error distinto, estaríamos filtrando información.
    """
    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "noexiste@example.com",
            "password": "cualquier_cosa",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Credenciales inválidas"


# ── Endpoints protegidos ──────────────────────────────────────────────────────


async def test_get_me_con_token_valido_retorna_usuario(
    client: AsyncClient, auth_headers: dict, user_data: dict
):
    response = await client.get("/api/v1/auth/me", headers=auth_headers)

    assert response.status_code == 200
    assert response.json()["data"]["email"] == user_data["email"]


async def test_get_me_sin_token_retorna_401(client: AsyncClient):
    response = await client.get("/api/v1/auth/me")

    assert response.status_code == 401


async def test_get_me_con_token_invalido_retorna_401(client: AsyncClient):
    response = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer token.falso.aqui"},
    )

    assert response.status_code == 401


# ── Refresh y logout ──────────────────────────────────────────────────────────


async def test_refresh_genera_nuevos_tokens(client: AsyncClient, registered_user: dict):
    refresh_token = registered_user["refresh_token"]

    response = await client.post(
        "/api/v1/auth/refresh",
        json={
            "refresh_token": refresh_token,
        },
    )

    assert response.status_code == 200
    new_tokens = response.json()["data"]
    # Los nuevos tokens deben ser distintos — rotación funcionando
    assert new_tokens["access_token"] != registered_user["access_token"]
    assert new_tokens["refresh_token"] != refresh_token


async def test_refresh_token_usado_dos_veces_retorna_401(
    client: AsyncClient, registered_user: dict
):
    """El mismo refresh token no puede usarse dos veces — rotación."""
    refresh_token = registered_user["refresh_token"]

    # Primer uso — válido
    await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})

    # Segundo uso — el token ya fue rotado, debe fallar
    response = await client.post(
        "/api/v1/auth/refresh",
        json={
            "refresh_token": refresh_token,
        },
    )

    assert response.status_code == 401


async def test_logout_invalida_el_refresh_token(
    client: AsyncClient, registered_user: dict
):
    refresh_token = registered_user["refresh_token"]

    # Logout
    response = await client.post(
        "/api/v1/auth/logout",
        json={
            "refresh_token": refresh_token,
        },
    )
    assert response.status_code == 204

    # Intentar usar el refresh token después del logout
    response = await client.post(
        "/api/v1/auth/refresh",
        json={
            "refresh_token": refresh_token,
        },
    )
    assert response.status_code == 401
