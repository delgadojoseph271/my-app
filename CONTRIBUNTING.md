## Flujo de trabajo

1. Crear rama desde develop: git checkout -b feature/mi-feature
2. Hacer commits con Conventional Commits
3. Abrir PR hacia develop con el template completo
4. Esperar que CI pase (obligatorio)
5. Code review (si hay equipo)
6. Squash merge

## Convenciones de código

- Python: seguir ruff + mypy
- Dart: seguir flutter analyze + effective dart
- Tests: cobertura mínima 80% en modulos nuevos

## Crear un módulo nuevo

bash create_module.sh nombre_modulo

# Seguir los pasos que imprime el script

## Migraciones

Siempre generar con: alembic revision -- autogenerate -m "descripcion"
Nunca modificar migraciones ya mergeadas a main
