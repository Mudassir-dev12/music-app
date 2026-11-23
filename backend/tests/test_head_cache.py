import asyncio
import io
import time
from unittest.mock import AsyncMock, MagicMock
import httpx
import pytest
from app.config import settings
from app.services.audio_proxy import AudioProxy
from app.services.head_cache import AudioHeadCache, head_cache
from app.sources.models import ResolvedStream


def test_head_cache_put_get_and_slicing():
    cache = AudioHeadCache(max_mb=1, head_bytes=100, ttl_seconds=60)
    data = b"x" * 250
    entry = cache.put("test_vid_1", data, total_size=1000, content_type="audio/mp4", etag="etag1")

    assert entry.size_bytes == 100
    assert len(entry.head_bytes) == 100
    assert cache.has("test_vid_1")

    got = cache.get("test_vid_1")
    assert got is not None
    assert got.total_size == 1000
    assert got.etag == "etag1"


def test_head_cache_lru_eviction():
    # Cache capacity: 300 bytes max
    cache = AudioHeadCache(max_mb=1, head_bytes=100, ttl_seconds=60)
    cache._max_bytes = 250  # force 250 bytes limit

    cache.put("vid1", b"1" * 100, total_size=500)
    cache.put("vid2", b"2" * 100, total_size=500)
    assert cache.count == 2

    # Access vid1 to make vid2 the LRU
    cache.get("vid1")

    # Adding vid3 should evict vid2
    cache.put("vid3", b"3" * 100, total_size=500)
    assert cache.has("vid1")
    assert cache.has("vid3")
    assert not cache.has("vid2")


def test_head_cache_validation_mismatch_discards():
    cache = AudioHeadCache(max_mb=1, head_bytes=100, ttl_seconds=60)
    cache.put("vid1", b"1" * 100, total_size=500, etag="tagA")

    # Mismatch total size
    valid = cache.validate_or_discard("vid1", upstream_total_size=600, upstream_etag="tagA")
    assert not valid
    assert not cache.has("vid1")

    # Mismatch etag
    cache.put("vid2", b"2" * 100, total_size=500, etag="tagA")
    valid2 = cache.validate_or_discard("vid2", upstream_total_size=500, upstream_etag="tagB")
    assert not valid2
    assert not cache.has("vid2")


def test_head_cache_ttl_expiration():
    cache = AudioHeadCache(max_mb=1, head_bytes=100, ttl_seconds=1)
    entry = cache.put("vid1", b"1" * 100, total_size=500)
    entry.created_at = time.time() - 5  # artificially age it

    assert cache.get("vid1") is None
    assert cache.count == 0


@pytest.mark.asyncio
async def test_stitched_streaming_byte_exact(monkeypatch):
    full_audio = b"HEAD_PART_0123456789" + b"REMAINDER_AUDIO_DATA_BYTES" * 10
    total_len = len(full_audio)
    head_part = full_audio[:20]
    remainder_part = full_audio[20:]

    head_cache.clear()
    head_cache.put("vid_stitched", head_part, total_size=total_len, content_type="audio/mp4")

    # Mock resolver
    resolver = MagicMock()
    resolver.get_stream = AsyncMock(
        return_value=ResolvedStream(url="https://audio.example.com/audio.mp4", headers={})
    )
    resolver.is_warm = AsyncMock(return_value=True)

    proxy = AudioProxy(resolver)

    # Mock _fetch_upstream to return remainder_part when range starting at 20 is requested
    async def fake_fetch(client, stream_info, range_header, method="GET"):
        resp = MagicMock(spec=httpx.Response)
        resp.status_code = 206
        resp.headers = {
            "content-type": "audio/mp4",
            "content-length": str(len(remainder_part)),
            "content-range": f"bytes 20-{total_len-1}/{total_len}",
        }

        async def aiter_bytes(chunk_size=65536):
            yield remainder_part

        resp.aiter_bytes = aiter_bytes
        resp.aclose = AsyncMock()
        return resp

    monkeypatch.setattr(proxy, "_fetch_upstream", fake_fetch)

    # Call proxy_stream with no range (full stream)
    db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar.return_value = 0
    db.execute.return_value = mock_res
    monkeypatch.setattr("app.services.usage.bandwidth_guard.record_bytes", AsyncMock())
    user_id = "test_user_head"
    response = await proxy.proxy_stream("vid_stitched", user_id, db=db, range_header=None)

    assert response.headers["X-Cache"] == "head"
    assert response.headers["X-Accel-Buffering"] == "no"
    assert response.headers["Content-Length"] == str(total_len)
    assert "head;dur=" in response.headers["Server-Timing"]

    # Read streamed bytes
    chunks = []
    async for chunk in response.body_iterator:
        chunks.append(chunk)

    combined = b"".join(chunks)
    assert combined == full_audio
    assert len(combined) == total_len

    head_cache.clear()
    await proxy.aclose()


@pytest.mark.asyncio
async def test_range_request_bypasses_head_cache(monkeypatch):
    full_audio = b"0123456789" * 10
    head_cache.clear()
    head_cache.put("vid_range", full_audio[:20], total_size=len(full_audio))

    resolver = MagicMock()
    resolver.get_stream = AsyncMock(
        return_value=ResolvedStream(url="https://audio.example.com/audio.mp4", headers={})
    )
    resolver.is_warm = AsyncMock(return_value=True)

    proxy = AudioProxy(resolver)

    # Request Range: bytes=30-50
    range_slice = full_audio[30:51]

    async def fake_fetch(client, stream_info, range_header, method="GET"):
        resp = MagicMock(spec=httpx.Response)
        resp.status_code = 206
        resp.headers = {
            "content-type": "audio/mp4",
            "content-length": str(len(range_slice)),
            "content-range": f"bytes 30-50/{len(full_audio)}",
        }

        async def aiter_bytes(chunk_size=65536):
            yield range_slice

        resp.aiter_bytes = aiter_bytes
        resp.aclose = AsyncMock()
        return resp

    monkeypatch.setattr(proxy, "_fetch_upstream", fake_fetch)

    db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalar.return_value = 0
    db.execute.return_value = mock_res
    monkeypatch.setattr("app.services.usage.bandwidth_guard.record_bytes", AsyncMock())
    response = await proxy.proxy_stream("vid_range", "u1", db=db, range_header="bytes=30-50")
    # Range starting at 30 should bypass head cache (X-Cache: url or miss)
    assert response.headers["X-Cache"] != "head"
    assert response.headers["Content-Length"] == str(len(range_slice))

    chunks = []
    async for chunk in response.body_iterator:
        chunks.append(chunk)

    assert b"".join(chunks) == range_slice
    head_cache.clear()
    await proxy.aclose()
