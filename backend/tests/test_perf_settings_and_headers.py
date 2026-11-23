import uuid
import httpx
from httpx import AsyncClient
import pytest
from app.config import Settings, settings


def test_perf_settings_startup_validation():
    # Valid default settings should pass
    valid_s = Settings(
        APP_JWT_SECRET="a" * 32,
        URL_REFRESH_AHEAD_RATIO=0.8,
        URL_REFRESH_MAX_CONCURRENT=1,
        URL_NEGATIVE_TTL_SECONDS=30,
        HEAD_BYTES=262144,
        HEAD_CACHE_MB=32,
        HEAD_CACHE_TTL_SECONDS=21600,
        PREFETCH_CONCURRENCY=2,
        PREFETCH_MAX_PER_MIN=30,
        PREFETCH_GLOBAL_MB_PER_DAY=300,
    )
    valid_s.validate_perf_config()

    # Invalid ratio < 0.1
    with pytest.raises(ValueError, match="URL_REFRESH_AHEAD_RATIO"):
        s = Settings(APP_JWT_SECRET="a" * 32, URL_REFRESH_AHEAD_RATIO=0.05)
        s.validate_perf_config()

    # Invalid negative TTL <= 0
    with pytest.raises(ValueError, match="URL_NEGATIVE_TTL_SECONDS"):
        s = Settings(APP_JWT_SECRET="a" * 32, URL_NEGATIVE_TTL_SECONDS=-1)
        s.validate_perf_config()

    # Invalid head bytes <= 0
    with pytest.raises(ValueError, match="HEAD_BYTES"):
        s = Settings(APP_JWT_SECRET="a" * 32, HEAD_BYTES=0)
        s.validate_perf_config()


@pytest.mark.asyncio
async def test_headers_and_logs_never_contain_upstream_url(client: AsyncClient):
    uid = uuid.uuid4().hex[:8]
    reg = await client.post(
        "/auth/register",
        json={"email": f"headers_{uid}@example.com", "password": "Password123!"},
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Single ticket
    resp_ticket = await client.post("/audio/dQw4w9WgXcQ/ticket", headers=headers)
    assert resp_ticket.status_code == 200
    st_header = resp_ticket.headers.get("Server-Timing", "")
    assert "ticket;dur=" in st_header
    assert "http" not in st_header
    assert "googlevideo" not in st_header

    # 2. Batch tickets
    resp_batch = await client.post("/audio/tickets", json={"video_ids": ["dQw4w9WgXcQ"]}, headers=headers)
    assert resp_batch.status_code == 200
    st_batch = resp_batch.headers.get("Server-Timing", "")
    assert "ticket;dur=" in st_batch
    assert "http" not in st_batch
    assert "googlevideo" not in st_batch
