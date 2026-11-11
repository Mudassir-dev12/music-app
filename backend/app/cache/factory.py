import logging
from typing import Optional
from app.cache.base import Cache
from app.cache.memory import MemoryCache
from app.cache.redis_cache import RedisCache
from app.config import settings

logger = logging.getLogger("music_app.cache")

_cache_instance: Optional[Cache] = None


async def init_cache() -> Cache:
    global _cache_instance
    if _cache_instance is not None:
        return _cache_instance

    if settings.REDIS_URL:
        try:
            rc = RedisCache(settings.REDIS_URL)
            # Test connectivity
            await rc._client.ping()
            logger.info("Cache backend: redis (connected to REDIS_URL)")
            _cache_instance = rc
            return _cache_instance
        except Exception as e:
            logger.warning(
                f"REDIS_URL provided but connection failed ({e}). Falling back to memory cache."
            )

    logger.info("Cache backend: memory")
    _cache_instance = MemoryCache()
    return _cache_instance


def get_cache() -> Cache:
    global _cache_instance
    if _cache_instance is None:
        _cache_instance = MemoryCache()
    return _cache_instance
