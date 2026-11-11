import asyncio
from unittest.mock import AsyncMock, patch
import uuid
import httpx
import pytest
from httpx import AsyncClient
import respx
from app.config import settings
from app.routes.audio import audio_proxy, stream_resolver
from app.services.stream_resolver import StreamResolver
from app.sources.models import ResolvedStream


@pytest.mark.asyncio
async def test_audio_video_id_validation(client: AsyncClient):
    email = f"audio_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Malformed video ids
    for bad_id in ["%2E%2E%2Fx", "abc;rm", "toolongvideoident12345", "short", "invalid$char"]:
        resp = await client.get(f"/audio/{bad_id}", headers=headers)
        assert resp.status_code == 400
        assert "Invalid video_id" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_audio_proxy_range_and_stream(client: AsyncClient):
    email = f"stream_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    vid = "12345678901"

    upstream_url = "https://upstream.googlevideo.com/videoplayback?id=secret_upstream_token"
    mock_resolved = ResolvedStream(
        url=upstream_url,
        headers={"User-Agent": "test-agent"},
        content_type="audio/mp4",
    )

    fake_audio_content = b"fake-audio-bytes-at-least-100-bytes-long" * 5

    with patch.object(stream_resolver, "get_stream", new_callable=AsyncMock) as mock_get_stream:
        mock_get_stream.return_value = mock_resolved

        with respx.mock(assert_all_called=False) as respx_mock:
            # 1. Full GET (no Range) -> 200
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    200,
                    content=fake_audio_content,
                    headers={"Content-Type": "audio/mp4", "Content-Length": str(len(fake_audio_content))},
                )
            )

            r_full = await client.get(f"/audio/{vid}", headers=headers)
            assert r_full.status_code == 200
            assert r_full.headers["Content-Type"] == "audio/mp4"
            assert upstream_url not in r_full.text
            assert "token" not in r_full.headers

            # 2. Range GET -> 206
            slice_bytes = fake_audio_content[0:100]
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    206,
                    content=slice_bytes,
                    headers={
                        "Content-Type": "audio/mp4",
                        "Content-Length": "100",
                        "Content-Range": f"bytes 0-99/{len(fake_audio_content)}",
                    },
                )
            )

            r_range = await client.get(
                f"/audio/{vid}", headers=dict(headers, Range="bytes=0-99")
            )
            assert r_range.status_code == 206
            assert r_range.headers["Content-Range"] == f"bytes 0-99/{len(fake_audio_content)}"
            assert len(r_range.content) == 100


@pytest.mark.asyncio
async def test_audio_upstream_403_retry_and_502(client: AsyncClient):
    email = f"retry_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    vid = "retry403tes"

    upstream_url_1 = "https://upstream.googlevideo.com/stream1"
    upstream_url_2 = "https://upstream.googlevideo.com/stream2"

    resolved_1 = ResolvedStream(url=upstream_url_1, headers={})
    resolved_2 = ResolvedStream(url=upstream_url_2, headers={})

    # Case 1: First attempt 403, second succeeds
    with patch.object(stream_resolver, "get_stream", side_effect=[resolved_1, resolved_2]):
        with patch.object(stream_resolver, "invalidate", new_callable=AsyncMock) as mock_invalidate:
            with respx.mock(assert_all_called=False) as respx_mock:
                respx_mock.get(upstream_url_1).mock(return_value=httpx.Response(403))
                respx_mock.get(upstream_url_2).mock(
                    return_value=httpx.Response(200, content=b"recovered_audio", headers={"Content-Type": "audio/mp4"})
                )

                resp = await client.get(f"/audio/{vid}", headers=headers)
                assert resp.status_code == 200
                assert resp.content == b"recovered_audio"
                mock_invalidate.assert_called_once_with(vid)

    # Case 2: Double failure gives 502
    with patch.object(stream_resolver, "get_stream", side_effect=[resolved_1, resolved_2]):
        with patch.object(stream_resolver, "invalidate", new_callable=AsyncMock):
            with respx.mock(assert_all_called=False) as respx_mock:
                respx_mock.get(upstream_url_1).mock(return_value=httpx.Response(403))
                respx_mock.get(upstream_url_2).mock(return_value=httpx.Response(403))

                resp_fail = await client.get(f"/audio/{vid}", headers=headers)
                assert resp_fail.status_code == 502


@pytest.mark.asyncio
async def test_audio_semaphore_concurrency(client: AsyncClient):
    email = f"sem_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Simulate semaphore full
    audio_proxy._semaphore._value = 0
    try:
        resp = await client.get("/audio/semtest1234", headers=headers)
        assert resp.status_code == 429
        assert resp.headers.get("Retry-After") == "5"
    finally:
        audio_proxy._semaphore._value = settings.MAX_CONCURRENT_STREAMS


@pytest.mark.asyncio
async def test_single_flight_resolution():
    mock_source = AsyncMock()
    mock_source.resolve_stream.return_value = ResolvedStream(url="https://flight.com/audio", headers={})

    resolver = StreamResolver(mock_source)

    # Run 10 concurrent get_stream calls for same video id
    tasks = [resolver.get_stream("flight12345") for _ in range(10)]
    results = await asyncio.gather(*tasks)

    # All returned the same stream
    for res in results:
        assert res.url == "https://flight.com/audio"

    # mock_source.resolve_stream must have been called exactly once!
    assert mock_source.resolve_stream.call_count == 1


@pytest.mark.asyncio
async def test_audio_disconnect_releases_semaphore_and_counts_partial_bytes_and_no_log_leaks(
    client: AsyncClient, caplog
):
    import logging
    from app.db.session import get_sessionmaker
    from app.services.usage import bandwidth_guard

    caplog.set_level(logging.INFO)
    pwd = "DisconnectPassword123!"
    email = f"disc_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": pwd})
    data = reg.json()
    token = data["access_token"]
    refresh_token = data["refresh_token"]
    user_id = data["user"]["id"]
    headers = {"Authorization": f"Bearer {token}"}

    upstream_url = "https://upstream.googlevideo.com/videoplayback?secret=leak_check_url"
    mock_resolved = ResolvedStream(url=upstream_url, headers={}, content_type="audio/mp4")

    class ChunkedStream(httpx.AsyncByteStream):
        async def __aiter__(self):
            yield b"A" * 65536
            yield b"B" * 65536
            yield b"C" * 65536

    initial_sem = audio_proxy._semaphore._value
    with patch.object(stream_resolver, "get_stream", new_callable=AsyncMock) as mock_get_stream:
        mock_get_stream.return_value = mock_resolved
        with respx.mock(assert_all_called=False) as respx_mock:
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    200,
                    stream=ChunkedStream(),
                    headers={"Content-Type": "audio/mp4"},
                )
            )

            async with get_sessionmaker()() as db:
                streaming_resp = await audio_proxy.proxy_stream(
                    video_id="disc1234567",
                    user_id=user_id,
                    db=db,
                )
                assert streaming_resp.status_code == 200
                # Semaphore is held while stream is open
                assert audio_proxy._semaphore._value == initial_sem - 1

                aiter = streaming_resp.body_iterator
                first_chunk = await anext(aiter)
                assert len(first_chunk) == 65536
                # Simulate client disconnecting after receiving only the first chunk
                await aiter.aclose()

    # Semaphore must be released after disconnect
    assert audio_proxy._semaphore._value == initial_sem

    # Only partial bytes (65536, not 196608) must be recorded in bandwidth_guard
    await bandwidth_guard.flush()
    u_resp = await client.get("/me/usage", headers=headers)
    assert u_resp.status_code == 200
    assert u_resp.json()["today_bytes"] == 65536

    # Secrets / upstream URLs must never appear in captured logs
    assert upstream_url not in caplog.text
    assert token not in caplog.text
    assert refresh_token not in caplog.text
    assert pwd not in caplog.text
