import asyncio
import logging
import time
from typing import Dict, Optional, Set
from fastapi import HTTPException, status
from app.cache.factory import get_cache
from app.config import settings
from app.sources.base import MusicSource
from app.sources.models import ResolvedStream

logger = logging.getLogger("music_app.stream_resolver")

_default_stream_resolver: Optional["StreamResolver"] = None


def get_stream_resolver() -> "StreamResolver":
    global _default_stream_resolver
    if _default_stream_resolver is None:
        from app.sources.ytmusic import YTMusicSource
        _default_stream_resolver = StreamResolver(YTMusicSource())
    return _default_stream_resolver


class StreamResolver:
    def __init__(self, source: MusicSource):
        self.source = source
        self.cache = get_cache()
        self._inflight: Dict[str, asyncio.Future[ResolvedStream]] = {}
        self._lock = asyncio.Lock()
        self._prefetch_semaphore = asyncio.Semaphore(settings.PREFETCH_CONCURRENCY)
        self._refresh_semaphore = asyncio.Semaphore(settings.URL_REFRESH_MAX_CONCURRENT)
        self._refreshing: Set[str] = set()

    async def invalidate(self, video_id: str) -> None:
        try:
            from app.services.head_cache import head_cache
            head_cache.remove(video_id)
        except Exception:
            pass
        cache_key = f"stream:{video_id}"
        neg_key = f"stream:neg:{video_id}"
        await self.cache.delete(cache_key)
        await self.cache.delete(neg_key)

    async def is_warm(self, video_id: str) -> bool:
        cache_key = f"stream:{video_id}"
        cached = await self.cache.get(cache_key)
        return cached is not None

    async def _resolve_with_retry(self, video_id: str) -> ResolvedStream:
        try:
            return await self.source.resolve_stream(video_id)
        except Exception as e1:
            logger.warning(
                f"Stream resolution attempt 1 failed for video {video_id}: {e1}. Retrying once..."
            )
            try:
                return await self.source.resolve_stream(video_id)
            except Exception as e2:
                logger.error(
                    f"Stream resolution attempt 2 failed for video {video_id}: {e2}."
                )
                # Record negative cache on failure
                try:
                    neg_key = f"stream:neg:{video_id}"
                    await self.cache.set(neg_key, True, ttl=settings.URL_NEGATIVE_TTL_SECONDS)
                except Exception as neg_err:
                    logger.debug(f"Failed to set negative cache: {neg_err}")

                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Failed to resolve audio stream from upstream provider.",
                ) from e2

    def _trigger_refresh_ahead(self, video_id: str, cached_data: dict) -> None:
        cached_at = cached_data.get("_cached_at")
        if not cached_at or video_id in self._refreshing:
            return

        elapsed = time.time() - cached_at
        refresh_threshold = settings.STREAM_URL_TTL * settings.URL_REFRESH_AHEAD_RATIO
        if elapsed >= refresh_threshold:
            asyncio.create_task(self._background_refresh(video_id))

    async def _background_refresh(self, video_id: str) -> None:
        if video_id in self._refreshing:
            return
        if self._refresh_semaphore.locked():
            return

        async with self._refresh_semaphore:
            self._refreshing.add(video_id)
            try:
                logger.info(f"Triggering refresh-ahead for video {video_id}")
                resolved = await self.source.resolve_stream(video_id)
                cache_key = f"stream:{video_id}"
                data = resolved.model_dump()
                data["_cached_at"] = time.time()
                await self.cache.set(cache_key, data, ttl=settings.STREAM_URL_TTL)
            except Exception as e:
                logger.warning(f"Background refresh-ahead failed for {video_id}: {e}")
            finally:
                self._refreshing.discard(video_id)

    async def get_stream(self, video_id: str, is_prefetch: bool = False) -> ResolvedStream:
        neg_key = f"stream:neg:{video_id}"
        is_neg = await self.cache.get(neg_key)
        if is_neg:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Stream resolution recently failed. Please try again later.",
            )

        cache_key = f"stream:{video_id}"

        # 1. Check cache
        cached = await self.cache.get(cache_key)
        if cached:
            if isinstance(cached, dict):
                self._trigger_refresh_ahead(video_id, cached)
                cached_copy = {k: v for k, v in cached.items() if not k.startswith("_")}
                return ResolvedStream(**cached_copy)
            return cached

        # If prefetch, gate by prefetch semaphore so speculative work never delays real playback
        if is_prefetch:
            async with self._prefetch_semaphore:
                return await self._get_stream_coordinated(video_id)
        else:
            return await self._get_stream_coordinated(video_id)

    async def _get_stream_coordinated(self, video_id: str) -> ResolvedStream:
        cache_key = f"stream:{video_id}"

        # Single-flight lock/future coordination
        async with self._lock:
            # Re-check cache under lock
            cached = await self.cache.get(cache_key)
            if cached:
                if isinstance(cached, dict):
                    self._trigger_refresh_ahead(video_id, cached)
                    cached_copy = {k: v for k, v in cached.items() if not k.startswith("_")}
                    return ResolvedStream(**cached_copy)
                return cached

            future = self._inflight.get(video_id)
            if future is None:
                loop = asyncio.get_running_loop()
                future = loop.create_future()
                self._inflight[video_id] = future
                is_leader = True
            else:
                is_leader = False

        if not is_leader:
            # Wait for leader to finish
            return await asyncio.shield(future)

        # Leader executes resolution
        try:
            resolved = await self._resolve_with_retry(video_id)
            if not resolved:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Failed to resolve audio stream from upstream provider.",
                )
            # Cache the result with timestamp
            data = resolved.model_dump()
            data["_cached_at"] = time.time()
            await self.cache.set(
                cache_key,
                data,
                ttl=settings.STREAM_URL_TTL,
            )
            future.set_result(resolved)
            return resolved
        except Exception as exc:
            if not future.done():
                future.set_exception(exc)
            try:
                future.exception()
            except Exception:
                pass
            raise
        finally:
            async with self._lock:
                self._inflight.pop(video_id, None)
