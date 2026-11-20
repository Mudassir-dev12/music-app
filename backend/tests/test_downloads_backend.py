import asyncio
import datetime
from unittest.mock import AsyncMock, patch
import uuid
import httpx
import pytest
from httpx import AsyncClient
import respx

from app.auth.tokens import create_audio_ticket
from app.config import Settings, settings
from app.db.session import get_sessionmaker
from app.routes.audio import audio_proxy, stream_resolver
from app.services.audio_cache import audio_cache
from app.services.usage import bandwidth_guard
from app.sources.models import ResolvedStream


@pytest.mark.asyncio
async def test_ticket_purposes_and_claims(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    assert reg.status_code == 201
    token = reg.json()["access_token"]
    auth_headers = {"Authorization": f"Bearer {token}"}

    vid = "dlvid001122"

    # Default purpose (stream) without body
    res_stream_default = await client.post(f"/audio/{vid}/ticket", headers=auth_headers)
    assert res_stream_default.status_code == 200
    data_stream = res_stream_default.json()
    assert data_stream["purpose"] == "stream"
    assert data_stream["remaining_download_mb"] is None
    assert data_stream["max_track_mb"] is None
    assert data_stream["url"].startswith(f"/audio/{vid}?t=")

    # Explicit purpose stream
    res_stream = await client.post(
        f"/audio/{vid}/ticket", json={"purpose": "stream"}, headers=auth_headers
    )
    assert res_stream.status_code == 200
    assert res_stream.json()["purpose"] == "stream"

    # Purpose download
    res_dl = await client.post(
        f"/audio/{vid}/ticket", json={"purpose": "download"}, headers=auth_headers
    )
    assert res_dl.status_code == 200
    data_dl = res_dl.json()
    assert data_dl["purpose"] == "download"
    assert data_dl["remaining_download_mb"] == settings.DAILY_DOWNLOAD_MB_PER_USER
    assert data_dl["max_track_mb"] == settings.MAX_DOWNLOAD_TRACK_MB
    assert data_dl["url"].startswith(f"/audio/{vid}?t=")


@pytest.mark.asyncio
async def test_wrong_video_or_tampered_download_ticket(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    token = reg.json()["access_token"]
    user_id = reg.json()["user"]["id"]
    auth_headers = {"Authorization": f"Bearer {token}"}

    vid1 = "dlvid111111"
    vid2 = "dlvid222222"

    ticket, _ = create_audio_ticket(user_id, vid1, purpose="download")

    # Accessing vid2 with vid1 ticket -> 401
    res = await client.get(f"/audio/{vid2}?t={ticket}")
    assert res.status_code == 401
    assert "Invalid or expired audio ticket" in res.json()["detail"]

    # Tampered ticket -> 401
    res_tampered = await client.get(f"/audio/{vid1}?t={ticket}tampered")
    assert res_tampered.status_code == 401


@pytest.mark.asyncio
async def test_download_quota_and_both_counters_updated(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    token = reg.json()["access_token"]
    user_id = reg.json()["user"]["id"]
    auth_headers = {"Authorization": f"Bearer {token}"}

    vid = "dlquota1234"
    t_res = await client.post(f"/audio/{vid}/ticket", json={"purpose": "download"}, headers=auth_headers)
    assert t_res.status_code == 200
    ticket = t_res.json()["url"].split("?t=")[1]

    upstream_url = "https://upstream.googlevideo.com/playback/dlquota"
    mock_resolved = ResolvedStream(url=upstream_url, headers={}, content_type="audio/mp4")
    chunk_data = b"D" * 50000  # 50 KB

    with patch.object(stream_resolver, "get_stream", new_callable=AsyncMock) as mock_get_stream:
        mock_get_stream.return_value = mock_resolved
        with respx.mock(assert_all_called=False) as respx_mock:
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    200,
                    content=chunk_data,
                    headers={"Content-Type": "audio/mp4", "Content-Length": str(len(chunk_data))},
                )
            )

            get_res = await client.get(f"/audio/{vid}?t={ticket}")
            assert get_res.status_code == 200
            assert len(get_res.content) == 50000

    # Verify both audio_usage and download_usage counters in bandwidth_guard
    today = datetime.datetime.now(datetime.timezone.utc).date()
    sm = get_sessionmaker()
    async with sm() as db:
        today_audio = await bandwidth_guard.get_user_today_bytes(user_id, db)
        today_dl = await bandwidth_guard.get_user_today_download_bytes(user_id, db)
        assert today_audio >= 50000
        assert today_dl >= 50000

    # Flush and verify counters survive to database
    await bandwidth_guard.flush()
    async with sm() as db:
        today_audio_after = await bandwidth_guard.get_user_today_bytes(user_id, db)
        today_dl_after = await bandwidth_guard.get_user_today_download_bytes(user_id, db)
        assert today_audio_after >= 50000
        assert today_dl_after >= 50000


@pytest.mark.asyncio
async def test_download_quota_exhausted_returns_429(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    token = reg.json()["access_token"]
    user_id = reg.json()["user"]["id"]
    auth_headers = {"Authorization": f"Bearer {token}"}

    vid = "dl429quota1"
    ticket, _ = create_audio_ticket(user_id, vid, purpose="download")

    # Record enough download bytes to exceed quota
    orig_quota = settings.DAILY_DOWNLOAD_MB_PER_USER
    try:
        settings.DAILY_DOWNLOAD_MB_PER_USER = 1  # 1 MB
        await bandwidth_guard.record_download_bytes(user_id, 2 * 1024 * 1024)

        res = await client.get(f"/audio/{vid}?t={ticket}")
        assert res.status_code == 429
        assert "Retry-After" in res.headers
        assert "Daily download bandwidth quota reached" in res.json()["detail"]
    finally:
        settings.DAILY_DOWNLOAD_MB_PER_USER = orig_quota


@pytest.mark.asyncio
async def test_download_exceeds_max_track_size_returns_413(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    token = reg.json()["access_token"]
    user_id = reg.json()["user"]["id"]

    vid = "dl413size01"
    ticket, _ = create_audio_ticket(user_id, vid, purpose="download")

    upstream_url = "https://upstream.googlevideo.com/playback/dl413"
    mock_resolved = ResolvedStream(url=upstream_url, headers={}, content_type="audio/mp4")
    # 90 MB exceeds 80 MB cap
    huge_length = 90 * 1024 * 1024

    with patch.object(stream_resolver, "get_stream", new_callable=AsyncMock) as mock_get_stream:
        mock_get_stream.return_value = mock_resolved
        with respx.mock(assert_all_called=False) as respx_mock:
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    200,
                    headers={"Content-Type": "audio/mp4", "Content-Length": str(huge_length)},
                )
            )

            res = await client.get(f"/audio/{vid}?t={ticket}")
            assert res.status_code == 413
            assert "exceeds maximum download track size" in res.json()["detail"]


@pytest.mark.asyncio
async def test_download_concurrency_limits_per_user_and_global(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    token = reg.json()["access_token"]
    user_id = reg.json()["user"]["id"]

    orig_user_max = settings.MAX_CONCURRENT_DOWNLOADS_PER_USER
    try:
        settings.MAX_CONCURRENT_DOWNLOADS_PER_USER = 1

        # Slot 1 acquired manually
        await audio_proxy._acquire_download_slot(user_id)

        vid = "dlconcur012"
        ticket, _ = create_audio_ticket(user_id, vid, purpose="download")

        # Second concurrent download should be rejected with 429
        res = await client.get(f"/audio/{vid}?t={ticket}")
        assert res.status_code == 429
        assert res.headers.get("Retry-After") == "5"
        assert "Maximum concurrent downloads reached" in res.json()["detail"]

        # Release slot
        await audio_proxy._release_download_slot(user_id)
    finally:
        settings.MAX_CONCURRENT_DOWNLOADS_PER_USER = orig_user_max


@pytest.mark.asyncio
async def test_download_range_resume_and_bytes_counted(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    token = reg.json()["access_token"]
    user_id = reg.json()["user"]["id"]

    vid = "dlrange1234"
    ticket, _ = create_audio_ticket(user_id, vid, purpose="download")

    upstream_url = "https://upstream.googlevideo.com/playback/dlrange"
    mock_resolved = ResolvedStream(url=upstream_url, headers={}, content_type="audio/mp4")
    total_data = b"0123456789" * 1000  # 10,000 bytes
    range_slice = total_data[4000:8000]

    with patch.object(stream_resolver, "get_stream", new_callable=AsyncMock) as mock_get_stream:
        mock_get_stream.return_value = mock_resolved
        with respx.mock(assert_all_called=False) as respx_mock:
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    206,
                    content=range_slice,
                    headers={
                        "Content-Type": "audio/mp4",
                        "Content-Length": str(len(range_slice)),
                        "Content-Range": "bytes 4000-7999/10000",
                        "Accept-Ranges": "bytes",
                    },
                )
            )

            res = await client.get(f"/audio/{vid}?t={ticket}", headers={"Range": "bytes=4000-7999"})
            assert res.status_code == 206
            assert res.headers["Accept-Ranges"] == "bytes"
            assert res.headers["Content-Range"] == "bytes 4000-7999/10000"
            assert len(res.content) == 4000


@pytest.mark.asyncio
async def test_get_me_downloads_limits_endpoint(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    token = reg.json()["access_token"]
    auth_headers = {"Authorization": f"Bearer {token}"}

    res = await client.get("/me/downloads/limits", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["daily_download_mb_limit"] == settings.DAILY_DOWNLOAD_MB_PER_USER
    assert data["max_download_track_mb"] == settings.MAX_DOWNLOAD_TRACK_MB
    assert data["max_concurrent_downloads_per_user"] == settings.MAX_CONCURRENT_DOWNLOADS_PER_USER
    assert data["max_concurrent_downloads_global"] == settings.MAX_CONCURRENT_DOWNLOADS_GLOBAL
    assert data["remaining_download_mb"] == settings.DAILY_DOWNLOAD_MB_PER_USER


def test_download_settings_startup_validation():
    # Valid default settings pass
    s = Settings(
        APP_JWT_SECRET="valid-jwt-secret-at-least-32-characters-long",
        DAILY_DOWNLOAD_MB_PER_USER=500,
        MAX_DOWNLOAD_TRACK_MB=50,
        MAX_CONCURRENT_DOWNLOADS_PER_USER=2,
        MAX_CONCURRENT_DOWNLOADS_GLOBAL=4,
    )
    s.validate_download_config()

    # Negative or zero values fail
    with pytest.raises(ValueError, match="DAILY_DOWNLOAD_MB_PER_USER must be a positive integer"):
        s_bad = Settings(
            APP_JWT_SECRET="valid-jwt-secret-at-least-32-characters-long",
            DAILY_DOWNLOAD_MB_PER_USER=0,
        )
        s_bad.validate_download_config()

    with pytest.raises(ValueError, match="MAX_DOWNLOAD_TRACK_MB must be a positive integer"):
        s_bad2 = Settings(
            APP_JWT_SECRET="valid-jwt-secret-at-least-32-characters-long",
            MAX_DOWNLOAD_TRACK_MB=-10,
        )
        s_bad2.validate_download_config()

