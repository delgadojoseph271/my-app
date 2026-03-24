# infrastructure/cache.py

import redis.asyncio as aioredis
from app.core.config import settings

_redis_client: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis:
    global _redis_client
    if not _redis_client:
        _redis_client = aioredis.from_url(
            settings.REDIS_URL,
            decode_response=True,
            max_connections=20,
        )

    return _redis_client


# Patrones de uso comunes:
#
# Guardar sesión con TTL:
#   redis = await get_redis()
#   await redis.setex(f"session:{token}", 3600, user_id)
#
# Caché de respuesta:
#   cached = await redis.get(f"user:{user_id}")
#   if cached: return json.loads(cached)
#
# Rate limiting:
#   count = await redis.incr(f"rate:{ip}")
#   await redis.expire(f"rate:{ip}", 60)
#   if count > 100: raise TooManyRequestsError()
