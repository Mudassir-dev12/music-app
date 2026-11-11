import json
import logging
import time
from typing import Any
import redis.asyncio as aioredis
from app.cache.base import Cache

logger = logging.getLogger("music_app.cache.redis")


class RedisCache:
    def __init__(self, url: str):
        self.name: str = "redis"
        self._url = url
        self._client = aioredis.from_url(
            url,
            socket_connect_timeout=0.3,
            socket_timeout=0.3,
            decode_responses=True,
        )
        self._last_error_log = 0.0

    def _log_error(self, err: Exception) -> None:
        now = time.time()
        if now - self._last_error_log > 60.0:
            logger.warning(f"Redis cache error (degraded to miss): {err}")
            self._last_error_log = now

    async def get(self, key: str) -> Any | None:
        try:
            val = await self._client.get(key)
            if val is None:
                return None
            try:
                return json.loads(val)
            except Exception:
                return val
        except Exception as e:
            self._log_error(e)
            return None

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        try:
            val_str = json.dumps(value) if not isinstance(value, str) else value
            if ttl:
                await self._client.set(key, val_str, ex=ttl)
            else:
                await self._client.set(key, val_str)
        except Exception as e:
            self._log_error(e)

    async def delete(self, key: str) -> None:
        try:
            await self._client.delete(key)
        except Exception as e:
            self._log_error(e)

    async def incr(self, key: str, ttl: int) -> int:
        try:
            pipe = self._client.pipeline()
            pipe.incr(key)
            pipe.expire(key, ttl)
            res = await pipe.execute()
            return int(res[0])
        except Exception as e:
            self._log_error(e)
            return 1
