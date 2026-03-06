# nombre-del-proyecto

Descripción en 1-2 líneas de qué hace el proyecto.

## Stack

- Backend: FastAPI 0.110, Python 3.12
- Mobile: Flutter 3.x, Dart 3.x
- DB: PostgreSQL 16, Redis 7

## Requisitos previos

- Docker y Docker Compose
- Python 3.12+
- Flutter SDK 3.x

## Levantar en local

```bash

cp .env.example .env
# Editar .env con tus valores locales
docker compose up -d            # Postgres + Redis + MinIO
cd backend && pip install -e ".[dev]"
alembic upgrade head
uvicorn app.main:app -- reload
```

## Estructura del proyecto

Ver [docs/architecture.md](docs/architecture.md)

## Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md)
