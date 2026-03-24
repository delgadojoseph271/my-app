from collections import defaultdict
from typing import Callable, Any
import logging

logger = logging.getLogger(__name__)


class EventBus:
    def __init__(self):
        self._handlers: dict[str, list[Callable]] = defaultdict(list)

    def subscribe(self, event: str, handler: Callable) -> None:
        self._handlers[event].append(handler)
        logger.debug(f"Handler '{handler.__name__}' suscrito a '{event}'")

    async def publish(self, event: str, payload: Any = None) -> None:
        handlers = self._handlers.get(event, [])
        if not handlers:
            logger.debug(f"Evento '{event}' publicado sin handlers suscritos")
            return
        for handler in handlers:
            try:
                await handler(payload)
            except Exception as e:
                # Un handler que falla no debe romper el flujo principal
                logger.error(
                    f"Error en handler '{handler.__name__}' para '{event}': {e}"
                )


bus = EventBus()
