# ── Handlers de eventos externos ──────────────────────────────────────────────
# Registrá aquí los eventos de otros módulos a los que este módulo reacciona.
# Los handlers se suscriben en core/lifespan.py

# Ejemplo: reaccionar cuando se crea un usuario
# async def on_user_created(payload: dict):
#     pass  # lógica aquí

# ── Registro (llamar desde core/lifespan.py) ──────────────────────────────────
def register_handlers():
    pass
    # bus.subscribe("user.created", on_user_created)
