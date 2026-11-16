import asyncio
import functools
import logging
import time
from typing import Any, Awaitable, Callable, Dict, Optional, Tuple, TypeVar
import anyio
from fastapi import HTTPException, status
from app.cache.factory import get_cache
from app.config import settings

logger = logging.getLogger("music_app.upstream")

T = TypeVar("T")


class UpstreamRateLimitExceeded(Exception):
    def __init__(self, retry_after: int = 60):
        self.retry_after = retry_after
        super().__init__(f"Upstream per-minute rate limit exceeded. Retry after {retry_after}s.")


class UpstreamLimiter:
    """Controls concurrency and rate limits for upstream calls to protect server IP."""

    def __init__(
        self,
        max_concurrent: Optional[int] = None,
        max_per_minute: Optional[int] = None,
    ):
        self._max_concurrent = max_concurrent or settings.YTM_MAX_CONCURRENT_UPSTREAM
        self._max_per_minute = max_per_minute or settings.YTM_MAX_UPSTREAM_PER_MIN
        self._semaphore = asyncio.Semaphore(self._max_concurrent)
        self._call_timestamps: list[float] = []
        self._lock = asyncio.Lock()

    def update_limits(self, max_concurrent: Optional[int] = None, max_per_minute: Optional[int] = None) -> None:
        if max_concurrent is not None:
            self._max_concurrent = max_concurrent
            self._semaphore = asyncio.Semaphore(max_concurrent)
        if max_per_minute is not None:
            self._max_per_minute = max_per_minute

    async def acquire(self) -> None:
        async with self._lock:
            now = time.time()
            # Prune timestamps older than 60 seconds
            self._call_timestamps = [t for t in self._call_timestamps if now - t < 60.0]
            if len(self._call_timestamps) >= self._max_per_minute:
                oldest = self._call_timestamps[0]
                retry_after = max(1, int(60.0 - (now - oldest)))
                raise UpstreamRateLimitExceeded(retry_after=retry_after)

            # Record call timestamp
            self._call_timestamps.append(now)

    @property
    def semaphore(self) -> asyncio.Semaphore:
        return self._semaphore


class UpstreamCoordinator:
    """Coordinates upstream fetches with single-flight, stale-while-error cache and concurrency limits."""

    def __init__(self, limiter: Optional[UpstreamLimiter] = None):
        self.limiter = limiter or UpstreamLimiter()
        self._inflight: Dict[str, asyncio.Future[Any]] = {}
        self._lock = asyncio.Lock()
        self._last_stale_warning: float = 0.0

    def _log_stale_warning(self, key: str, reason: str) -> None:
        now = time.time()
        if now - self._last_stale_warning >= 60.0:
            self._last_stale_warning = now
            logger.warning(f"Upstream refresh failed for key '{key}' ({reason}). Serving stale cached data.")

    async def execute(
        self,
        cache_key: str,
        ttl: int,
        fetcher: Callable[[], Awaitable[T]],
    ) -> Tuple[T, str]:
        """
        Executes or retrieves cached data.
        Returns (data, cache_status) where cache_status is 'hit', 'miss', or 'stale'.
        """
        cache = get_cache()
        cached_entry = await cache.get(cache_key)
        now = time.time()

        # 1. Fresh cache hit
        if cached_entry and isinstance(cached_entry, dict) and "data" in cached_entry and "fresh_until" in cached_entry:
            fresh_until = cached_entry["fresh_until"]
            if now <= fresh_until:
                return cached_entry["data"], "hit"

        # 2. Check if already in-flight
        future_to_await: Optional[asyncio.Future[Any]] = None
        is_initiator = False

        async with self._lock:
            # Re-check cache under lock
            cached_entry = await cache.get(cache_key)
            if cached_entry and isinstance(cached_entry, dict) and "data" in cached_entry and "fresh_until" in cached_entry:
                if time.time() <= cached_entry["fresh_until"]:
                    return cached_entry["data"], "hit"

            if cache_key in self._inflight:
                future_to_await = self._inflight[cache_key]
            else:
                loop = asyncio.get_running_loop()
                future_to_await = loop.create_future()
                self._inflight[cache_key] = future_to_await
                is_initiator = True

        if not is_initiator:
            try:
                res = await future_to_await
                return res, "hit"
            except Exception as e:
                # If leader failed and we have stale cached data, serve stale
                if cached_entry and isinstance(cached_entry, dict) and "data" in cached_entry:
                    self._log_stale_warning(cache_key, str(e))
                    return cached_entry["data"], "stale"
                raise

        # 3. Initiator performs the upstream fetch
        try:
            # Acquire per-minute limiter
            try:
                await self.limiter.acquire()
            except UpstreamRateLimitExceeded as rle:
                if cached_entry and isinstance(cached_entry, dict) and "data" in cached_entry:
                    self._log_stale_warning(cache_key, "rate limit exceeded")
                    future_to_await.set_result(cached_entry["data"])
                    return cached_entry["data"], "stale"
                future_to_await.set_exception(
                    HTTPException(
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                        detail="Music service is busy, please retry shortly.",
                        headers={"Retry-After": str(rle.retry_after)},
                    )
                )
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Music service is busy, please retry shortly.",
                    headers={"Retry-After": str(rle.retry_after)},
                )

            # Concurrency semaphore
            async with self.limiter.semaphore:
                # Execute fetcher with transient retry
                result = await self._run_with_retry(fetcher)

            # Store in cache: { "data": ..., "fresh_until": now + ttl }
            total_ttl = ttl + settings.STALE_EXTRA_TTL
            entry_to_store = {
                "data": result,
                "fresh_until": time.time() + ttl,
            }
            await cache.set(cache_key, entry_to_store, ttl=total_ttl)
            future_to_await.set_result(result)
            return result, "miss"

        except Exception as e:
            # Check for stale fallback
            if cached_entry and isinstance(cached_entry, dict) and "data" in cached_entry:
                self._log_stale_warning(cache_key, str(e))
                if not future_to_await.done():
                    future_to_await.set_result(cached_entry["data"])
                return cached_entry["data"], "stale"

            if not future_to_await.done():
                if isinstance(e, HTTPException):
                    future_to_await.set_exception(e)
                else:
                    future_to_await.set_exception(
                        HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail="Upstream music service error. Please try again.",
                        )
                    )

            if isinstance(e, HTTPException):
                raise
            logger.error(f"Upstream fetch failed for '{cache_key}': {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Upstream music service error. Please try again.",
            ) from e

        finally:
            async with self._lock:
                self._inflight.pop(cache_key, None)

    async def _run_with_retry(self, fetcher: Callable[[], Awaitable[T]]) -> T:
        try:
            return await fetcher()
        except HTTPException:
            raise
        except Exception as first_err:
            logger.warning(f"Upstream call attempt 1 failed: {first_err}. Retrying once...")
            try:
                return await fetcher()
            except HTTPException:
                raise
            except Exception as second_err:
                logger.error(f"Upstream call attempt 2 failed: {second_err}.")
                raise second_err


async def run_in_worker(func: Callable[..., T], *args: Any, **kwargs: Any) -> T:
    """Runs a blocking call in a worker thread via anyio.to_thread.run_sync."""
    return await anyio.to_thread.run_sync(functools.partial(func, *args, **kwargs))


# Global default upstream coordinator instance
default_upstream_coordinator = UpstreamCoordinator()
