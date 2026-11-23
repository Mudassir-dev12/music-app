import asyncio
import time
from unittest.mock import AsyncMock, MagicMock
import pytest
from fastapi import HTTPException
from app.cache.memory import MemoryCache
from app.config import settings
from app.services.stream_resolver import StreamResolver
from app.sources.models import ResolvedStream


@pytest.fixture
def memory_cache():
    return MemoryCache()


@pytest.fixture
def mock_source():
    source = MagicMock()
    source.resolve_stream = AsyncMock(
        return_value=ResolvedStream(
            url="https://audio.example.com/stream.mp4",
            headers={"User-Agent": "test"},
            content_type="audio/mp4",
        )
    )
    return source


@pytest.fixture
def resolver(mock_source, memory_cache):
    res = StreamResolver(mock_source)
    res.cache = memory_cache
    return res


@pytest.mark.asyncio
async def test_single_flight_concurrent_resolves(resolver, mock_source):
    # Simulate slow resolve
    async def slow_resolve(video_id: str):
        await asyncio.sleep(0.05)
        return ResolvedStream(
            url=f"https://audio.example.com/{video_id}.mp4",
            headers={},
            content_type="audio/mp4",
        )

    mock_source.resolve_stream.side_effect = slow_resolve

    # Launch 5 concurrent requests for same video_id
    tasks = [asyncio.create_task(resolver.get_stream("test_vid_1")) for _ in range(5)]
    results = await asyncio.gather(*tasks)

    assert len(results) == 5
    for r in results:
        assert r.url == "https://audio.example.com/test_vid_1.mp4"

    # Only 1 upstream call should have been made
    assert mock_source.resolve_stream.call_count == 1


@pytest.mark.asyncio
async def test_negative_cache_on_failure(resolver, mock_source):
    mock_source.resolve_stream.side_effect = Exception("Upstream connection refused")

    with pytest.raises(HTTPException) as exc_info:
        await resolver.get_stream("broken_vid")
    assert exc_info.value.status_code == 502

    # Second call should hit negative cache directly without calling upstream again
    mock_source.resolve_stream.reset_mock()
    with pytest.raises(HTTPException) as exc_info2:
        await resolver.get_stream("broken_vid")
    assert exc_info2.value.status_code == 502
    assert mock_source.resolve_stream.call_count == 0

    # Invalidate negative cache
    await resolver.invalidate("broken_vid")
    mock_source.resolve_stream.side_effect = None
    mock_source.resolve_stream.return_value = ResolvedStream(
        url="https://audio.example.com/broken_vid.mp4",
        headers={},
        content_type="audio/mp4",
    )

    result = await resolver.get_stream("broken_vid")
    assert result.url == "https://audio.example.com/broken_vid.mp4"
    assert mock_source.resolve_stream.call_count == 1


@pytest.mark.asyncio
async def test_refresh_ahead_triggers_when_stale(resolver, mock_source):
    # Prime cache with old timestamp
    old_time = time.time() - (settings.STREAM_URL_TTL * settings.URL_REFRESH_AHEAD_RATIO + 10)
    data = {
        "url": "https://audio.example.com/old.mp4",
        "headers": {},
        "content_type": "audio/mp4",
        "_cached_at": old_time,
    }
    await resolver.cache.set("stream:refresh_vid", data, ttl=settings.STREAM_URL_TTL)

    # First get returns immediately with old data, but triggers background refresh
    result = await resolver.get_stream("refresh_vid")
    assert result.url == "https://audio.example.com/old.mp4"

    # Wait for background task to complete
    await asyncio.sleep(0.05)
    assert mock_source.resolve_stream.call_count >= 1


@pytest.mark.asyncio
async def test_prefetch_saturation_does_not_block_real_playback(resolver, mock_source):
    # Splay slow resolves
    async def slow_resolve(video_id: str):
        await asyncio.sleep(0.1)
        return ResolvedStream(
            url=f"https://audio.example.com/{video_id}.mp4",
            headers={},
            content_type="audio/mp4",
        )

    mock_source.resolve_stream.side_effect = slow_resolve

    # Fill all prefetch concurrency slots
    prefetch_tasks = [
        asyncio.create_task(resolver.get_stream(f"prefetch_{i}", is_prefetch=True))
        for i in range(settings.PREFETCH_CONCURRENCY)
    ]

    # Give prefetch tasks time to acquire slots
    await asyncio.sleep(0.01)

    # Real play request should execute without waiting for prefetch queue
    t0 = time.monotonic()
    real_play = await resolver.get_stream("real_play_vid", is_prefetch=False)
    elapsed = time.monotonic() - t0

    assert real_play.url == "https://audio.example.com/real_play_vid.mp4"
    # Should complete in roughly ~0.1s (its own resolve time), not waiting for serial prefetch
    assert elapsed < 0.25

    await asyncio.gather(*prefetch_tasks)

