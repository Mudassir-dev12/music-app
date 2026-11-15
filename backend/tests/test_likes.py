from unittest.mock import AsyncMock, patch
import uuid
import pytest
from httpx import AsyncClient
from app.sources.models import Artist, Track


def make_mock_track(video_id: str, title: str = "Liked Track") -> Track:
    return Track(
        video_id=video_id,
        title=title,
        artists=[Artist(name="Test Artist")],
        artist="Test Artist",
        album="Test Album",
        album_id="alb123",
        duration_seconds=180,
        thumbnail="https://example.com/thumb.jpg",
        is_explicit=False,
    )


@pytest.mark.asyncio
async def test_likes_lifecycle_and_idempotency(client: AsyncClient):
    email = f"likes_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    vid = "likedTrk001"
    trk = make_mock_track(vid)

    with patch("app.services.tracks.default_ytmusic_source.get_track", return_value=trk):
        # 1. Like track
        r1 = await client.put(f"/me/likes/{vid}", headers=headers)
        assert r1.status_code == 204

        # 2. Idempotent like
        r2 = await client.put(f"/me/likes/{vid}", headers=headers)
        assert r2.status_code == 204

    # 3. Check liked ids
    r_ids = await client.get("/me/likes/ids", headers=headers)
    assert r_ids.status_code == 200
    assert r_ids.json()["ids"] == [vid]

    # 4. Check liked page
    r_page = await client.get("/me/likes", headers=headers)
    assert r_page.status_code == 200
    page_data = r_page.json()
    assert len(page_data["items"]) == 1
    assert page_data["items"][0]["track"]["video_id"] == vid

    # 5. Unlike track
    r_del1 = await client.delete(f"/me/likes/{vid}", headers=headers)
    assert r_del1.status_code == 204

    # 6. Idempotent unlike
    r_del2 = await client.delete(f"/me/likes/{vid}", headers=headers)
    assert r_del2.status_code == 204

    # 7. Check empty
    r_ids2 = await client.get("/me/likes/ids", headers=headers)
    assert r_ids2.json()["ids"] == []


@pytest.mark.asyncio
async def test_likes_upstream_failure_502(client: AsyncClient):
    email = f"likes_fail_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    vid = "failTrk0001"
    with patch(
        "app.services.tracks.default_ytmusic_source.get_track",
        side_effect=RuntimeError("Upstream connection dropped"),
    ):
        r_fail = await client.put(f"/me/likes/{vid}", headers=headers)
        assert r_fail.status_code == 502
        assert "Upstream track lookup failed" in r_fail.json()["detail"]

    # Nothing was written
    r_ids = await client.get("/me/likes/ids", headers=headers)
    assert vid not in r_ids.json()["ids"]
