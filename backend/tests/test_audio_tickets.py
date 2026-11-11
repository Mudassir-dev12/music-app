import datetime
import logging
from unittest.mock import AsyncMock, patch
import uuid
import httpx
import jwt
import pytest
from httpx import AsyncClient
import respx
from sqlalchemy import select
from app.auth.tokens import create_access_token
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import User
from app.db.session import get_sessionmaker
from app.routes.audio import stream_resolver
from app.services.usage import bandwidth_guard
from app.sources.models import ResolvedStream


@pytest.mark.asyncio
async def test_audio_ticket_lifecycle_and_validation(client: AsyncClient, caplog):
    caplog.set_level(logging.INFO)
    email = f"ticket_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"
    reg = await client.post("/auth/register", json={"email": email, "password": pwd})
    assert reg.status_code == 201
    data = reg.json()
    access_token = data["access_token"]
    user_id = data["user"]["id"]
    auth_headers = {"Authorization": f"Bearer {access_token}"}

    vid = "ticket12345"
    other_vid = "other123456"

    # Bad video_id on ticket endpoint -> 400
    r_bad = await client.post("/audio/bad-id/ticket", headers=auth_headers)
    assert r_bad.status_code == 400

    # Unauthenticated ticket request -> 401
    r_unauth = await client.post(f"/audio/{vid}/ticket")
    assert r_unauth.status_code == 401

    # Valid ticket issuance
    r_ticket = await client.post(f"/audio/{vid}/ticket", headers=auth_headers)
    assert r_ticket.status_code == 200
    t_body = r_ticket.json()
    assert t_body["expires_in"] == settings.AUDIO_TICKET_TTL_SECONDS
    assert t_body["url"].startswith(f"/audio/{vid}?t=")
    ticket = t_body["url"].split("?t=", 1)[1]

    upstream_url = "https://upstream.googlevideo.com/videoplayback?secret=ticket_upstream"
    mock_resolved = ResolvedStream(url=upstream_url, headers={}, content_type="audio/mp4")
    audio_bytes = b"0123456789" * 20

    with patch.object(stream_resolver, "get_stream", new_callable=AsyncMock) as mock_get_stream:
        mock_get_stream.return_value = mock_resolved
        with respx.mock(assert_all_called=False) as respx_mock:
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    200,
                    content=audio_bytes,
                    headers={"Content-Type": "audio/mp4", "Content-Length": str(len(audio_bytes))},
                )
            )
            respx_mock.head(upstream_url).mock(
                return_value=httpx.Response(
                    200,
                    headers={"Content-Type": "audio/mp4", "Content-Length": str(len(audio_bytes))},
                )
            )

            # 1. Valid ticket plays 200 without Authorization header
            r_play = await client.get(t_body["url"])
            assert r_play.status_code == 200
            assert r_play.content == audio_bytes
            assert r_play.headers.get("referrer-policy") == "no-referrer"

            # 2. Valid ticket HEAD -> 200 with Referrer-Policy
            r_head = await client.head(t_body["url"])
            assert r_head.status_code == 200
            assert r_head.headers.get("referrer-policy") == "no-referrer"

            # 3. Valid ticket plays 206 with Range
            respx_mock.get(upstream_url).mock(
                return_value=httpx.Response(
                    206,
                    content=audio_bytes[:100],
                    headers={
                        "Content-Type": "audio/mp4",
                        "Content-Length": "100",
                        "Content-Range": f"bytes 0-99/{len(audio_bytes)}",
                    },
                )
            )
            r_range = await client.get(t_body["url"], headers={"Range": "bytes=0-99"})
            assert r_range.status_code == 206
            assert len(r_range.content) == 100
            assert r_range.headers.get("referrer-policy") == "no-referrer"

    # 4. Bandwidth is counted against the ticket's user
    await bandwidth_guard.flush()
    r_usage = await client.get("/me/usage", headers=auth_headers)
    assert r_usage.status_code == 200
    assert r_usage.json()["today_bytes"] >= len(audio_bytes) + 100

    # 5. Ticket never appears in captured logs
    assert ticket not in caplog.text
    assert f"t={ticket}" not in caplog.text

    # 6. Ticket for another video -> 401
    r_other_vid = await client.get(f"/audio/{other_vid}?t={ticket}")
    assert r_other_vid.status_code == 401

    # 7. Missing both Authorization and ?t= -> 401
    r_neither = await client.get(f"/audio/{vid}")
    assert r_neither.status_code == 401

    # 8. Access token used as ?t= -> 401
    r_access_as_ticket = await client.get(f"/audio/{vid}?t={access_token}")
    assert r_access_as_ticket.status_code == 401

    # 9. Ticket used as Bearer token on /me, /search, /audio, /audio/ticket -> 401
    ticket_bearer = {"Authorization": f"Bearer {ticket}"}
    assert (await client.get("/me", headers=ticket_bearer)).status_code == 401
    assert (await client.get("/search?q=test", headers=ticket_bearer)).status_code == 401
    assert (await client.get(f"/audio/{vid}", headers=ticket_bearer)).status_code == 401
    assert (await client.post(f"/audio/{vid}/ticket", headers=ticket_bearer)).status_code == 401

    # 10. Tampered ticket -> 401
    tampered = ticket[:-4] + ("aaaa" if not ticket.endswith("aaaa") else "bbbb")
    assert (await client.get(f"/audio/{vid}?t={tampered}")).status_code == 401

    # 11. Expired ticket -> 401
    now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
    expired_ticket = jwt.encode(
        {
            "sub": user_id,
            "vid": vid,
            "typ": "audio",
            "iat": now_ts - 1000,
            "exp": now_ts - 10,
            "iss": settings.JWT_ISSUER,
            "aud": settings.JWT_AUDIENCE,
            "jti": uuid.uuid4().hex,
        },
        settings.APP_JWT_SECRET,
        algorithm="HS256",
    )
    assert (await client.get(f"/audio/{vid}?t={expired_ticket}")).status_code == 401

    # 12. Wrong typ -> 401
    wrong_typ_ticket = jwt.encode(
        {
            "sub": user_id,
            "vid": vid,
            "typ": "other",
            "iat": now_ts,
            "exp": now_ts + 600,
            "iss": settings.JWT_ISSUER,
            "aud": settings.JWT_AUDIENCE,
            "jti": uuid.uuid4().hex,
        },
        settings.APP_JWT_SECRET,
        algorithm="HS256",
    )
    assert (await client.get(f"/audio/{vid}?t={wrong_typ_ticket}")).status_code == 401

    # 13. Inactive user with valid ticket -> 401
    async with get_sessionmaker()() as db:
        res = await db.execute(select(User).where(User.id == user_id))
        u = res.scalar_one()
        u.is_active = False
        await db.commit()
    await get_cache().delete(f"uact:{user_id}")
    assert (await client.get(t_body["url"])).status_code == 401

