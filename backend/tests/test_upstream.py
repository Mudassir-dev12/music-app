import asyncio
import time
from unittest.mock import AsyncMock
import pytest
from fastapi import HTTPException
from app.services.upstream import (
    UpstreamCoordinator,
    UpstreamLimiter,
    UpstreamRateLimitExceeded,
)


@pytest.mark.asyncio
async def test_upstream_cache_fresh_hit():
    coordinator = UpstreamCoordinator()
    key = "test:fresh:1"
    fetch_mock = AsyncMock(return_value={"msg": "hello"})

    # 1. First fetch is a miss
    val, status = await coordinator.execute(key, ttl=100, fetcher=fetch_mock)
    assert status == "miss"
    assert val == {"msg": "hello"}
    assert fetch_mock.call_count == 1

    # 2. Second fetch within fresh window is a hit
    val2, status2 = await coordinator.execute(key, ttl=100, fetcher=fetch_mock)
    assert status2 == "hit"
    assert val2 == {"msg": "hello"}
    assert fetch_mock.call_count == 1


@pytest.mark.asyncio
async def test_upstream_single_flight_coalescing():
    coordinator = UpstreamCoordinator()
    key = "test:singleflight:1"
    call_count = 0

    async def slow_fetch():
        nonlocal call_count
        call_count += 1
        await asyncio.sleep(0.05)
        return {"data": 42}

    # Launch 10 concurrent requests for same key
    tasks = [coordinator.execute(key, ttl=50, fetcher=slow_fetch) for _ in range(10)]
    results = await asyncio.gather(*tasks)

    # Exactly 1 call was made to fetcher
    assert call_count == 1
    assert len(results) == 10
    # First is miss, others are hits
    statuses = [r[1] for r in results]
    assert "miss" in statuses
    assert all(r[0] == {"data": 42} for r in results)


@pytest.mark.asyncio
async def test_upstream_stale_while_error_fallback():
    coordinator = UpstreamCoordinator()
    key = "test:stale:1"

    # Pre-populate cache with an expired fresh_until (stale)
    cache = coordinator.limiter  # get cache
    from app.cache.factory import get_cache
    c = get_cache()
    await c.set(key, {"data": {"v": "old_data"}, "fresh_until": time.time() - 10}, ttl=1000)

    # Fetcher fails with an upstream exception
    fail_mock = AsyncMock(side_effect=Exception("YouTube network failure"))

    val, status = await coordinator.execute(key, ttl=50, fetcher=fail_mock)
    # Stale data returned gracefully with status 'stale'
    assert status == "stale"
    assert val == {"v": "old_data"}


@pytest.mark.asyncio
async def test_upstream_limiter_rate_limit_and_503():
    limiter = UpstreamLimiter(max_concurrent=2, max_per_minute=2)
    coordinator = UpstreamCoordinator(limiter=limiter)

    fetch_mock = AsyncMock(return_value={"ok": True})

    # Call 1 & 2 succeed
    await coordinator.execute("test:rl:1", ttl=50, fetcher=fetch_mock)
    await coordinator.execute("test:rl:2", ttl=50, fetcher=fetch_mock)

    # Call 3 exceeds per-minute limit and has no stale cache -> 503
    with pytest.raises(HTTPException) as exc_info:
        await coordinator.execute("test:rl:3", ttl=50, fetcher=fetch_mock)

    assert exc_info.value.status_code == 503
    assert "Retry-After" in exc_info.value.headers


@pytest.mark.asyncio
async def test_upstream_transient_retry():
    coordinator = UpstreamCoordinator()
    key = "test:retry:1"
    attempts = 0

    async def flaky_fetch():
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            raise ConnectionResetError("Transient network drop")
        return {"recovered": True}

    val, status = await coordinator.execute(key, ttl=50, fetcher=flaky_fetch)
    assert attempts == 2
    assert status == "miss"
    assert val == {"recovered": True}
