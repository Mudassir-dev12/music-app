import asyncio
import uuid
from unittest.mock import AsyncMock, patch
import httpx
from httpx import AsyncClient
import pytest
from app.config import settings
from app.routes.audio import stream_resolver
from app.services.head_cache import head_cache
from app.services.usage import bandwidth_guard


@pytest.fixture
async def auth_headers(client: AsyncClient):
    uid = uuid.uuid4().hex[:8]
    reg = await client.post(
        "/auth/register",
        json={"email": f"batch_{uid}@example.com", "password": "Password123!"},
    )
    token = reg.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_batch_tickets_success_and_timing(client: AsyncClient, auth_headers):
    video_ids = ["dQw4w9WgXcQ", "9bZkp7q19f0", "kJQP7kiw5Fk"]
    resp = await client.post(
        "/audio/tickets",
        json={"video_ids": video_ids, "purpose": "stream"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()

    for vid in video_ids:
        assert vid in data
        assert "ticket" in data[vid]
        assert data[vid]["expires_in"] > 0
        assert data[vid]["url"] == f"/audio/{vid}?t={data[vid]['ticket']}"

    # Server-Timing header present
    assert "Server-Timing" in resp.headers
    assert "ticket;dur=" in resp.headers["Server-Timing"]


@pytest.mark.asyncio
async def test_batch_tickets_validation_limits(client: AsyncClient, auth_headers):
    # Empty list
    resp1 = await client.post(
        "/audio/tickets",
        json={"video_ids": []},
        headers=auth_headers,
    )
    assert resp1.status_code == 422

    # More than 10
    resp2 = await client.post(
        "/audio/tickets",
        json={"video_ids": [f"vid_{i:07d}1" for i in range(11)]},
        headers=auth_headers,
    )
    assert resp2.status_code == 422

    # Invalid video id format
    resp3 = await client.post(
        "/audio/tickets",
        json={"video_ids": ["invalid/id"]},
        headers=auth_headers,
    )
    assert resp3.status_code in (400, 422)


@pytest.mark.asyncio
async def test_prefetch_endpoint_statuses(client: AsyncClient, auth_headers):
    head_cache.clear()

    # Prime one video as warm
    await stream_resolver.cache.set(
        "stream:warm_vid_11",
        {"url": "https://example.com/audio.mp4", "headers": {}, "content_type": "audio/mp4"},
        ttl=300,
    )
    head_cache.put("warm_vid_11", b"x" * 200, total_size=5000)

    resp = await client.post(
        "/audio/prefetch",
        json={"video_ids": ["warm_vid_11", "cold_vid_22", "inv@lid!id"], "head": True},
        headers=auth_headers,
    )
    assert resp.status_code == 202
    statuses = resp.json()["statuses"]

    assert statuses["warm_vid_11"] == "warm"
    assert statuses["cold_vid_22"] == "queued"
    assert statuses["inv@lid!id"] == "invalid"

    # Ensure no tickets or URLs leaked in prefetch response
    for k, v in statuses.items():
        assert v in ("warm", "queued", "skipped", "rate_limited", "invalid")
        assert not str(v).startswith("http")

    head_cache.clear()


@pytest.mark.asyncio
async def test_prefetch_validation_max_5(client: AsyncClient, auth_headers):
    resp = await client.post(
        "/audio/prefetch",
        json={"video_ids": [f"vid_{i:07d}1" for i in range(6)]},
        headers=auth_headers,
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_prefetch_rate_limiting(client: AsyncClient, auth_headers, monkeypatch):
    monkeypatch.setattr(settings, "PREFETCH_MAX_PER_MIN", 2)

    # First request: 1 item (count=1 <= 2)
    r1 = await client.post(
        "/audio/prefetch",
        json={"video_ids": ["vid00000001"]},
        headers=auth_headers,
    )
    assert r1.status_code == 202

    # Second request: count=2 <= 2
    r2 = await client.post(
        "/audio/prefetch",
        json={"video_ids": ["vid00000002"]},
        headers=auth_headers,
    )
    assert r2.status_code == 202

    # Third request: count=3 > 2 -> 429
    r3 = await client.post(
        "/audio/prefetch",
        json={"video_ids": ["vid00000003"]},
        headers=auth_headers,
    )
    assert r3.status_code == 429
    assert "Retry-After" in r3.headers


@pytest.mark.asyncio
async def test_prefetch_skipped_when_budget_exceeded(client: AsyncClient, auth_headers, monkeypatch):
    monkeypatch.setattr(bandwidth_guard, "is_prefetch_daily_budget_exceeded", AsyncMock(return_value=True))

    resp = await client.post(
        "/audio/prefetch",
        json={"video_ids": ["vid00000001"]},
        headers=auth_headers,
    )
    assert resp.status_code == 202
    assert resp.json()["statuses"]["vid00000001"] == "skipped"
