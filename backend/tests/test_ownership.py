from unittest.mock import AsyncMock, patch
import uuid
import pytest
from httpx import AsyncClient
from app.sources.models import Artist, Track


def make_mock_track(video_id: str, title: str = "Track") -> Track:
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
async def test_ownership_isolation_between_users(client: AsyncClient):
    # 1. Register User A
    email_a = f"usera_{uuid.uuid4().hex[:8]}@example.com"
    reg_a = await client.post("/auth/register", json={"email": email_a, "password": "ValidPassword123!"})
    token_a = reg_a.json()["access_token"]
    headers_a = {"Authorization": f"Bearer {token_a}"}

    # 2. Register User B
    email_b = f"userb_{uuid.uuid4().hex[:8]}@example.com"
    reg_b = await client.post("/auth/register", json={"email": email_b, "password": "ValidPassword123!"})
    token_b = reg_b.json()["access_token"]
    headers_b = {"Authorization": f"Bearer {token_b}"}

    trk = make_mock_track("ownerTrk001")
    with patch("app.services.tracks.default_ytmusic_source.get_track", return_value=trk):
        # User A creates playlist, likes track, and logs history
        r_pl_a = await client.post("/me/playlists", headers=headers_a, json={"name": "User A Playlist"})
        pl_a_id = r_pl_a.json()["id"]

        await client.post(f"/me/playlists/{pl_a_id}/tracks", headers=headers_a, json={"video_ids": [trk.video_id]})
        await client.put(f"/me/likes/{trk.video_id}", headers=headers_a)
        await client.post("/me/history", headers=headers_a, json={"video_id": trk.video_id, "listened_seconds": 60, "client_event_id": "ev_a_1"})

    # --- User B tests accessing User A's data ---

    # B cannot read A's playlist -> 404 (not 403)
    r_get_pl = await client.get(f"/me/playlists/{pl_a_id}", headers=headers_b)
    assert r_get_pl.status_code == 404

    # B cannot patch A's playlist -> 404
    r_patch_pl = await client.patch(f"/me/playlists/{pl_a_id}", headers=headers_b, json={"name": "Hacked"})
    assert r_patch_pl.status_code == 404

    # B cannot delete A's playlist -> 404
    r_del_pl = await client.delete(f"/me/playlists/{pl_a_id}", headers=headers_b)
    assert r_del_pl.status_code == 404

    # B cannot add tracks to A's playlist -> 404
    r_add_trk = await client.post(f"/me/playlists/{pl_a_id}/tracks", headers=headers_b, json={"video_ids": [trk.video_id]})
    assert r_add_trk.status_code == 404

    # B cannot reorder A's playlist -> 404
    r_reorder = await client.put(f"/me/playlists/{pl_a_id}/tracks/reorder", headers=headers_b, json={"video_ids": [trk.video_id]})
    assert r_reorder.status_code == 404

    # B cannot delete tracks from A's playlist -> 404
    r_del_trk = await client.delete(f"/me/playlists/{pl_a_id}/tracks/{trk.video_id}", headers=headers_b)
    assert r_del_trk.status_code == 404

    # B's playlist list is empty
    r_b_pls = await client.get("/me/playlists", headers=headers_b)
    assert len(r_b_pls.json()) == 0

    # B's likes are empty
    r_b_likes = await client.get("/me/likes", headers=headers_b)
    assert len(r_b_likes.json()["items"]) == 0
    r_b_like_ids = await client.get("/me/likes/ids", headers=headers_b)
    assert len(r_b_like_ids.json()["ids"]) == 0

    # B's history is empty
    r_b_hist = await client.get("/me/history", headers=headers_b)
    assert len(r_b_hist.json()["items"]) == 0
    r_b_recent = await client.get("/me/recent", headers=headers_b)
    assert len(r_b_recent.json()) == 0

    # --- Unauthenticated requests must be 401 ---
    assert (await client.get("/me/playlists")).status_code == 401
    assert (await client.post("/me/playlists", json={"name": "No Auth"})).status_code == 401
    assert (await client.get(f"/me/playlists/{pl_a_id}")).status_code == 401
    assert (await client.get("/me/likes")).status_code == 401
    assert (await client.get("/me/likes/ids")).status_code == 401
    assert (await client.put(f"/me/likes/{trk.video_id}")).status_code == 401
    assert (await client.get("/me/history")).status_code == 401
    assert (await client.get("/me/recent")).status_code == 401
    assert (await client.post("/me/history", json={"video_id": trk.video_id, "listened_seconds": 10, "client_event_id": "none"})).status_code == 401
