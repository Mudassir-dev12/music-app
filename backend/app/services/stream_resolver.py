import asyncio
import logging
from typing import Dict, Optional
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

    async def invalidate(self, video_id: str) -> None:
        cache_key = f"stream:{video_id}"
        await self.cache.delete(cache_key)

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
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Failed to resolve audio stream from upstream provider.",
                ) from e2

    async def get_stream(self, video_id: str) -> ResolvedStream:
        cache_key = f"stream:{video_id}"

        # 1. Check cache
        cached = await self.cache.get(cache_key)
        if cached:
            if isinstance(cached, dict):
                return ResolvedStream(**cached)
            return cached

        # 2. Single-flight lock/future coordination
        async with self._lock:
            # Re-check cache under lock
            cached = await self.cache.get(cache_key)
            if cached:
                if isinstance(cached, dict):
                    return ResolvedStream(**cached)
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
            # Cache the result
            await self.cache.set(
                cache_key,
                resolved.model_dump(),
                ttl=settings.STREAM_URL_TTL,
            )
            future.set_result(resolved)
            return resolved
        except Exception as exc:
            if not future.done():
                future.set_exception(exc)
            raise
        finally:
            async with self._lock:
                self._inflight.pop(video_id, None)
