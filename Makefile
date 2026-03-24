# =============================================================================
# Makefile — Monolito Modular (FastAPI + Flutter)
# Correr siempre desde la raíz del monorepo (my-app/)
# =============================================================================
# Uso:
#   make <comando>
#   make help          → ver todos los comandos disponibles
# =============================================================================

.PHONY: help \
        infra-up infra-down infra-logs infra-ps \
        dev test lint format typecheck \
        migrate migration module \
        flutter-run flutter-test flutter-analyze flutter-clean feature \
        fix-script \
        setup

# ── Colores para la terminal ──────────────────────────────────────────────────
CYAN  = \033[0;36m
GREEN = \033[0;32m
YELLOW= \033[0;33m
RESET = \033[0m

# =============================================================================
# AYUDA
# =============================================================================

help: ## Muestra este menú de ayuda
	@echo ""
	@echo "  $(CYAN)Monolito Modular — Comandos disponibles$(RESET)"
	@echo ""
	@echo "  $(YELLOW)Infraestructura$(RESET)"
	@grep -E '^(infra)[^:]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*//' | while read cmd; do \
		desc=$$(grep "^$$cmd:.*##" $(MAKEFILE_LIST) | sed 's/.*## //'); \
		printf "    make %-25s %s\n" "$$cmd" "$$desc"; \
	done
	@echo ""
	@echo "  $(YELLOW)Backend (FastAPI)$(RESET)"
	@grep -E '^(dev|test|lint|format|typecheck|migrate|migration|module)[^:]*:.*##' $(MAKEFILE_LIST) | sed 's/:.*//' | while read cmd; do \
		desc=$$(grep "^$$cmd:.*##" $(MAKEFILE_LIST) | sed 's/.*## //'); \
		printf "    make %-25s %s\n" "$$cmd" "$$desc"; \
	done
	@echo ""
	@echo "  $(YELLOW)Mobile (Flutter)$(RESET)"
	@grep -E '^flutter[^:]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*//' | while read cmd; do \
		desc=$$(grep "^$$cmd:.*##" $(MAKEFILE_LIST) | sed 's/.*## //'); \
		printf "    make %-25s %s\n" "$$cmd" "$$desc"; \
	done
	@grep -E '^feature[^:]*:.*##' $(MAKEFILE_LIST) | sed 's/:.*//' | while read cmd; do \
		desc=$$(grep "^$$cmd:.*##" $(MAKEFILE_LIST) | sed 's/.*## //'); \
		printf "    make %-25s %s\n" "$$cmd" "$$desc"; \
	done
	@echo ""
	@echo "  $(YELLOW)Utilidades$(RESET)"
	@grep -E '^(fix-script|setup)[^:]*:.*##' $(MAKEFILE_LIST) | sed 's/:.*//' | while read cmd; do \
		desc=$$(grep "^$$cmd:.*##" $(MAKEFILE_LIST) | sed 's/.*## //'); \
		printf "    make %-25s %s\n" "$$cmd" "$$desc"; \
	done
	@echo ""
	@echo "  $(CYAN)Ejemplos con argumentos:$(RESET)"
	@echo "    make module name=orders"
	@echo "    make migration name=add_bio_to_users"
	@echo "    make feature name=notifications"
	@echo ""

# =============================================================================
# INFRAESTRUCTURA LOCAL (Docker)
# =============================================================================

infra-up: ## Levantar Postgres, Redis y MinIO en Docker
	@echo "$(GREEN)▶ Levantando infraestructura...$(RESET)"
	docker compose -f infra/docker/docker-compose.dev.yml up -d
	@echo "$(GREEN)✓ Infraestructura levantada$(RESET)"

infra-down: ## Apagar los contenedores
	@echo "$(YELLOW)▶ Apagando infraestructura...$(RESET)"
	docker compose -f infra/docker/docker-compose.dev.yml down

infra-logs: ## Ver los logs de los contenedores en tiempo real
	docker compose -f infra/docker/docker-compose.dev.yml logs -f

infra-ps: ## Ver el estado de los contenedores
	docker compose -f infra/docker/docker-compose.dev.yml ps

# =============================================================================
# BACKEND — FastAPI
# =============================================================================

dev: ## Arrancar el servidor FastAPI con hot reload
	@echo "$(GREEN)▶ Iniciando FastAPI en http://localhost:8000$(RESET)"
	@echo "$(CYAN)  Swagger: http://localhost:8000/docs$(RESET)"
	cd backend && .venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test: ## Correr todos los tests del backend
	@echo "$(GREEN)▶ Corriendo tests...$(RESET)"
	cd backend && .venv/bin/pytest -v --cov=app --cov-report=term-missing

test-fast: ## Correr tests sin reporte de cobertura (más rápido)
	cd backend && .venv/bin/pytest -v

lint: ## Verificar estilo de código con ruff
	@echo "$(GREEN)▶ Linting...$(RESET)"
	cd backend && .venv/bin/ruff check .

format: ## Formatear el código automáticamente con ruff
	@echo "$(GREEN)▶ Formateando código...$(RESET)"
	cd backend && .venv/bin/ruff format .
	cd backend && .venv/bin/ruff check . --fix

typecheck: ## Verificar tipos con mypy
	@echo "$(GREEN)▶ Type checking...$(RESET)"
	cd backend && .venv/bin/mypy app/

check: lint typecheck ## Correr lint + typecheck juntos (útil antes de un commit)

migrate: ## Aplicar todas las migraciones pendientes
	@echo "$(GREEN)▶ Aplicando migraciones...$(RESET)"
	cd backend && .venv/bin/alembic upgrade head
	@echo "$(GREEN)✓ Migraciones aplicadas$(RESET)"

migrate-down: ## Revertir la última migración
	@echo "$(YELLOW)▶ Revirtiendo última migración...$(RESET)"
	cd backend && .venv/bin/alembic downgrade -1

migrate-history: ## Ver el historial de migraciones
	cd backend && .venv/bin/alembic history

migrate-status: ## Ver en qué versión está la base de datos
	cd backend && .venv/bin/alembic current

migration: ## Generar una nueva migración (uso: make migration name=descripcion)
ifndef name
	@echo "$(YELLOW)  ✗ Falta el nombre. Uso: make migration name=add_bio_to_users$(RESET)"
	@exit 1
endif
	@echo "$(GREEN)▶ Generando migración: $(name)$(RESET)"
	cd backend && .venv/bin/alembic revision --autogenerate -m "$(name)"
	@echo "$(GREEN)✓ Revisá el archivo generado en backend/migrations/versions/$(RESET)"

module: ## Crear un módulo nuevo en el backend (uso: make module name=orders)
ifndef name
	@echo "$(YELLOW)  ✗ Falta el nombre. Uso: make module name=orders$(RESET)"
	@exit 1
endif
	@bash create_module.sh $(name)

# =============================================================================
# MOBILE — Flutter
# =============================================================================

flutter-run: ## Correr la app Flutter (elige dispositivo)
	cd mobile && flutter run

flutter-web: ## Correr la app Flutter en Chrome
	cd mobile && flutter run -d chrome

flutter-test: ## Correr los tests de Flutter
	@echo "$(GREEN)▶ Corriendo tests Flutter...$(RESET)"
	cd mobile && flutter test

flutter-analyze: ## Analizar el código Dart
	@echo "$(GREEN)▶ Analizando código Flutter...$(RESET)"
	cd mobile && flutter analyze

flutter-clean: ## Limpiar el build de Flutter
	@echo "$(YELLOW)▶ Limpiando build Flutter...$(RESET)"
	cd mobile && flutter clean && flutter pub get

flutter-deps: ## Actualizar dependencias de Flutter
	cd mobile && flutter pub get

feature: ## Crear una feature nueva en Flutter (uso: make feature name=notifications)
ifndef name
	@echo "$(YELLOW)  ✗ Falta el nombre. Uso: make feature name=notifications$(RESET)"
	@exit 1
endif
	@bash create_feature.sh $(name)

# =============================================================================
# UTILIDADES
# =============================================================================

fix-scripts: ## Arreglar line endings de los scripts bash (Windows → Unix)
	@echo "$(GREEN)▶ Arreglando line endings...$(RESET)"
	sed -i 's/\r//' create_module.sh create_feature.sh
	@echo "$(GREEN)✓ Scripts listos$(RESET)"

setup: ## Setup inicial completo del proyecto desde cero
	@echo "$(GREEN)▶ Setup inicial...$(RESET)"
	@echo ""
	@echo "  1. Arreglando scripts..."
	@sed -i 's/\r//' create_module.sh create_feature.sh 2>/dev/null || true
	@echo "  2. Levantando infraestructura..."
	@docker compose -f infra/docker/docker-compose.dev.yml up -d
	@echo "  3. Instalando dependencias del backend..."
	@cd backend && python3 -m venv .venv && .venv/bin/pip install -e ".[dev]" -q
	@echo "  4. Aplicando migraciones..."
	@cd backend && .venv/bin/alembic upgrade head
	@echo "  5. Instalando dependencias de Flutter..."
	@cd mobile && flutter pub get
	@echo ""
	@echo "$(GREEN)✓ Setup completo. Podés correr 'make dev' para arrancar el backend.$(RESET)"
	@echo ""
