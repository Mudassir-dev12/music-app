import asyncio
import uuid
import pytest
from httpx import AsyncClient
from app.cache.memory import MemoryCache
from app.cache.redis_cache import RedisCache
from app.config import settings


@pytest.mark.asyncio
async def test_memory_cache_lru_and_ttl():
    cache = MemoryCache(max_size=3)

    # Test TTL expiry
    await cache.set("k1", "v1", ttl=1)
    assert await cache.get("k1") == "v1"
    await asyncio.sleep(1.1)
    assert await cache.get("k1") is None

    # Test LRU eviction with max_size=3
    await cache.set("a", "1")
    await cache.set("b", "2")
    await cache.set("c", "3")
    # Touch 'a' so 'b' becomes least recently used
    assert await cache.get("a") == "1"
    # Insert 'd' -> 'b' should be evicted
    await cache.set("d", "4")
    assert await cache.get("b") is None
    assert await cache.get("a") == "1"
    assert await cache.get("c") == "3"
    assert await cache.get("d") == "4"

    # Test incr
    c1 = await cache.incr("counter", ttl=60)
    assert c1 == 1
    c2 = await cache.incr("counter", ttl=60)
    assert c2 == 2


@pytest.mark.asyncio
async def test_redis_cache_degradation():
    class BrokenRedis:
        async def get(self, *args, **kwargs):
            raise ConnectionError("Redis down")

        async def set(self, *args, **kwargs):
            raise ConnectionError("Redis down")

        async def delete(self, *args, **kwargs):
            raise ConnectionError("Redis down")

        def pipeline(self):
            raise ConnectionError("Redis down")

    rc = RedisCache("redis://localhost:6379/0")
    rc._client = BrokenRedis()

    # Broken calls gracefully degrade without raising
    assert await rc.get("some_key") is None
    await rc.set("some_key", "value", ttl=10)
    await rc.delete("some_key")
    incr_val = await rc.incr("some_key", ttl=10)
    assert incr_val == 1


@pytest.mark.asyncio
async def test_rate_limiting(client: AsyncClient):
    # Health endpoint is never limited
    for _ in range(10):
        h_resp = await client.get("/health")
        assert h_resp.status_code == 200

    # User rate limiting
    email = f"rl_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    token = reg.json()["access_token"]

    settings.RATE_LIMIT_PER_MIN = 3
    try:
        headers = {"Authorization": f"Bearer {token}"}
        r1 = await client.get("/me", headers=headers)
        assert r1.status_code == 200
        r2 = await client.get("/me", headers=headers)
        assert r2.status_code == 200
        r3 = await client.get("/me", headers=headers)
        assert r3.status_code == 200

        # 4th request exceeds RATE_LIMIT_PER_MIN
        r4 = await client.get("/me", headers=headers)
        assert r4.status_code == 429
        assert "Retry-After" in r4.headers
    finally:
        settings.RATE_LIMIT_PER_MIN = 120
