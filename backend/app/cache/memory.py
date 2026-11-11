import asyncio
from collections import OrderedDict
import time
from typing import Any
from app.cache.base import Cache


class MemoryCache:
    def __init__(self, max_size: int = 1000):
        self.name: str = "memory"
        self._max_size = max_size
        self._cache: OrderedDict[str, tuple[Any, float | None]] = OrderedDict()
        self._lock = asyncio.Lock()

    def _cleanup_expired(self) -> None:
        now = time.time()
        expired_keys = [
            k for k, (_, exp) in self._cache.items() if exp is not None and exp < now
        ]
        for k in expired_keys:
            del self._cache[k]

    async def get(self, key: str) -> Any | None:
        async with self._lock:
            if key not in self._cache:
                return None
            val, exp = self._cache[key]
            if exp is not None and exp < time.time():
                del self._cache[key]
                return None
            self._cache.move_to_end(key)
            return val

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        async with self._lock:
            now = time.time()
            if key in self._cache:
                del self._cache[key]
            elif len(self._cache) >= self._max_size:
                # Evict expired first, then LRU
                self._cleanup_expired()
                if len(self._cache) >= self._max_size:
                    self._cache.popitem(last=False)

            exp = (now + ttl) if ttl is not None else None
            self._cache[key] = (value, exp)

    async def delete(self, key: str) -> None:
        async with self._lock:
            if key in self._cache:
                del self._cache[key]

    async def incr(self, key: str, ttl: int) -> int:
        async with self._lock:
            now = time.time()
            if key in self._cache:
                val, exp = self._cache[key]
                if exp is not None and exp < now:
                    new_val = 1
                    exp = now + ttl
                else:
                    new_val = int(val) + 1
                    # Keep existing exp or set if None
                    if exp is None:
                        exp = now + ttl
            else:
                if len(self._cache) >= self._max_size:
                    self._cleanup_expired()
                    if len(self._cache) >= self._max_size:
                        self._cache.popitem(last=False)
                new_val = 1
                exp = now + ttl

            self._cache[key] = (new_val, exp)
            self._cache.move_to_end(key)
            return new_val
