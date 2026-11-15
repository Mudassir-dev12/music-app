import datetime
from unittest.mock import AsyncMock, patch
import uuid
import pytest
from httpx import AsyncClient
from app.config import settings
from app.db.models import PlayHistory
from app.db.session import get_sessionmaker
from app.services.history import prune_user_history, reset_prune_cache
from app.sources.models import Artist, Track


def make_mock_track(video_id: str, title: str = "Test Track", duration: int = 180) -> Track:
    return Track(
        video_id=video_id,
        title=title,
        artists=[Artist(name="Test Artist")],
        artist="Test Artist",
        album="Test Album",
        album_id="alb123",
        duration_seconds=duration,
        thumbnail="https://example.com/thumb.jpg",
        is_explicit=False,
    )


@pytest.mark.asyncio
async def test_history_lifecycle_and_idempotency(client: AsyncClient):
    email = f"hist_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    vid = "histTrack01"
    mock_trk = make_mock_track(vid, "History Song", 200)

    with patch("app.services.tracks.default_ytmusic_source.get_track", new=AsyncMock(return_value=mock_trk)):
        # 1. First record (201 Created)
        ev_id = str(uuid.uuid4())
        resp1 = await client.post(
            "/me/history",
            headers=headers,
            json={"video_id": vid, "listened_seconds": 45, "client_event_id": ev_id},
        )
        assert resp1.status_code == 201
        data1 = resp1.json()
        assert data1["track"]["video_id"] == vid
        assert data1["listened_seconds"] == 45
        hist_id = data1["id"]

        # 2. Second record with same client_event_id (idempotent, 200 OK)
        resp2 = await client.post(
            "/me/history",
            headers=headers,
            json={"video_id": vid, "listened_seconds": 120, "client_event_id": ev_id},
        )
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert data2["id"] == hist_id
        assert data2["listened_seconds"] == 45  # Not overwritten

        # 3. Listened seconds clamping (duration=200, input=250 > 230 -> clamped to 200)
        ev_id_clamp = str(uuid.uuid4())
        resp_clamp = await client.post(
            "/me/history",
            headers=headers,
            json={"video_id": vid, "listened_seconds": 250, "client_event_id": ev_id_clamp},
        )
        assert resp_clamp.status_code == 201
        assert resp_clamp.json()["listened_seconds"] == 200

        # 4. Validation errors: negative and > 86400
        r_neg = await client.post(
            "/me/history",
            headers=headers,
            json={"video_id": vid, "listened_seconds": -5, "client_event_id": "neg_ev"},
        )
        assert r_neg.status_code == 422

        r_huge = await client.post(
            "/me/history",
            headers=headers,
            json={"video_id": vid, "listened_seconds": 90000, "client_event_id": "huge_ev"},
        )
        assert r_huge.status_code == 422


@pytest.mark.asyncio
async def test_history_pagination_and_tampered_cursor(client: AsyncClient):
    email = f"hist_page_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    tracks = [make_mock_track(f"vidPg{i:06d}", f"Track {i}") for i in range(5)]
    with patch("app.services.tracks.default_ytmusic_source.get_track", side_effect=tracks):
        for trk in tracks:
            r = await client.post(
                "/me/history",
                headers=headers,
                json={"video_id": trk.video_id, "listened_seconds": 30, "client_event_id": str(uuid.uuid4())},
            )
            assert r.status_code == 201

    # Page 1 with limit=2
    r_p1 = await client.get("/me/history?limit=2", headers=headers)
    assert r_p1.status_code == 200
    p1_data = r_p1.json()
    assert len(p1_data["items"]) == 2
    assert p1_data["next_cursor"] is not None

    # Page 2
    r_p2 = await client.get(f"/me/history?limit=2&cursor={p1_data['next_cursor']}", headers=headers)
    assert r_p2.status_code == 200
    p2_data = r_p2.json()
    assert len(p2_data["items"]) == 2
    assert p2_data["next_cursor"] is not None

    # Tampered cursor
    r_tampered = await client.get("/me/history?cursor=invalid_base64_tampered_cursor", headers=headers)
    assert r_tampered.status_code == 422


@pytest.mark.asyncio
async def test_recent_tracks_distinct_order(client: AsyncClient):
    email = f"recent_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    t1 = make_mock_track("recentTrk01", "Song 1")
    t2 = make_mock_track("recentTrk02", "Song 2")

    with patch("app.services.tracks.default_ytmusic_source.get_track", side_effect=[t1, t2]):
        # Play t1, then t2, then t1 again
        r_p1 = await client.post("/me/history", headers=headers, json={"video_id": t1.video_id, "listened_seconds": 30, "client_event_id": "ev1"})
        assert r_p1.status_code == 201
        r_p2 = await client.post("/me/history", headers=headers, json={"video_id": t2.video_id, "listened_seconds": 30, "client_event_id": "ev2"})
        assert r_p2.status_code == 201
        r_p3 = await client.post("/me/history", headers=headers, json={"video_id": t1.video_id, "listened_seconds": 30, "client_event_id": "ev3"})
        assert r_p3.status_code == 201

    r_recent = await client.get("/me/recent", headers=headers)
    assert r_recent.status_code == 200
    recent_tracks = r_recent.json()
    # Distinct tracks: t1 played most recently, so order should be [t1, t2]
    assert len(recent_tracks) == 2
    assert recent_tracks[0]["video_id"] == t1.video_id
    assert recent_tracks[1]["video_id"] == t2.video_id


@pytest.mark.asyncio
async def test_history_delete_one_and_clear_all(client: AsyncClient):
    email = f"hist_del_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    t1 = make_mock_track("delHistTr01")
    with patch("app.services.tracks.default_ytmusic_source.get_track", return_value=t1):
        r1 = await client.post("/me/history", headers=headers, json={"video_id": t1.video_id, "listened_seconds": 30, "client_event_id": "ev_del1"})
        assert r1.status_code == 201
        hist_id = r1.json()["id"]

    # Delete single item
    r_del1 = await client.delete(f"/me/history/{hist_id}", headers=headers)
    assert r_del1.status_code == 204

    r_list = await client.get("/me/history", headers=headers)
    assert len(r_list.json()["items"]) == 0

    # Add two and clear all
    with patch("app.services.tracks.default_ytmusic_source.get_track", return_value=t1):
        await client.post("/me/history", headers=headers, json={"video_id": t1.video_id, "listened_seconds": 30, "client_event_id": "ev_del2"})
        await client.post("/me/history", headers=headers, json={"video_id": t1.video_id, "listened_seconds": 30, "client_event_id": "ev_del3"})

    r_clear = await client.delete("/me/history", headers=headers)
    assert r_clear.status_code == 204

    r_empty = await client.get("/me/history", headers=headers)
    assert len(r_empty.json()["items"]) == 0


@pytest.mark.asyncio
async def test_history_pruning_count_and_age(client: AsyncClient):
    email = f"prune_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    user_id = reg.json()["user"]["id"]
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    t = make_mock_track("pruneTrk001")
    with patch("app.services.tracks.default_ytmusic_source.get_track", return_value=t):
        for i in range(5):
            r = await client.post(
                "/me/history",
                headers=headers,
                json={"video_id": t.video_id, "listened_seconds": 30, "client_event_id": f"p_ev_{i}"},
            )
            assert r.status_code == 201

    # Directly test prune_user_history with count limit = 2
    orig_max = settings.HISTORY_MAX_ITEMS_PER_USER
    settings.HISTORY_MAX_ITEMS_PER_USER = 2
    try:
        reset_prune_cache()
        async with get_sessionmaker()() as db:
            await prune_user_history(db, user_id, force=True)

        r_check = await client.get("/me/history", headers=headers)
        assert len(r_check.json()["items"]) == 2
    finally:
        settings.HISTORY_MAX_ITEMS_PER_USER = orig_max


@pytest.mark.asyncio
async def test_history_write_rate_limit(client: AsyncClient):
    import time
    from app.cache.factory import get_cache

    email = f"rl_hist_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    user_id = reg.json()["user"]["id"]
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    cache = get_cache()
    now = int(time.time())
    minute_bucket = now // 60
    key = f"rl:hw:{user_id}:{minute_bucket}"

    # Artificially set counter to 120
    await cache.set(key, 120, ttl=60)

    # Next write triggers 429
    r_limited = await client.post(
        "/me/history",
        headers=headers,
        json={"video_id": "histTrack01", "listened_seconds": 30, "client_event_id": "rl_ev"},
    )
    assert r_limited.status_code == 429
    assert "Retry-After" in r_limited.headers
