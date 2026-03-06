# ADR 001 - Monolito modular en vez de microservicios

** Fecha :** 2024-03-15
** Estado :** Aceptado

## Contexto

Proyecto nuevo sin equipo definido. Incertidumbre en los límites de los dominios.

## Decisión

Usar monolito modular con event_bus interno.

## Consecuencias

✓ Menor complejidad operacional al inicio
✓ Fácil extracción futura a microservicios
X Límite de escala horizontal del proceso único
