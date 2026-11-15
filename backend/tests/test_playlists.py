from unittest.mock import AsyncMock, patch
import uuid
import pytest
from httpx import AsyncClient
from app.config import settings
from app.sources.models import Artist, Track


def make_mock_track(video_id: str, title: str = "Playlist Track", thumb: str = "https://thumb.com/1.jpg") -> Track:
    return Track(
        video_id=video_id,
        title=title,
        artists=[Artist(name="Test Artist")],
        artist="Test Artist",
        album="Test Album",
        album_id="alb123",
        duration_seconds=200,
        thumbnail=thumb,
        is_explicit=False,
    )


@pytest.mark.asyncio
async def test_playlists_crud_and_limits(client: AsyncClient):
    email = f"pl_crud_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create playlist
    r_create = await client.post(
        "/playlists",
        headers=headers,
        json={"name": "My Favorites", "description": "Good songs"},
    )
    assert r_create.status_code == 201
    pl = r_create.json()
    assert pl["name"] == "My Favorites"
    assert pl["track_count"] == 0
    pl_id = pl["id"]

    # 2. Patch playlist
    r_patch = await client.patch(
        f"/playlists/{pl_id}",
        headers=headers,
        json={"name": "Renamed Favorites", "description": "Updated"},
    )
    assert r_patch.status_code == 200
    assert r_patch.json()["name"] == "Renamed Favorites"
    assert r_patch.json()["description"] == "Updated"

    # 3. Limit test (MAX_PLAYLISTS_PER_USER)
    orig_max = settings.MAX_PLAYLISTS_PER_USER
    settings.MAX_PLAYLISTS_PER_USER = 1
    try:
        r_over = await client.post(
            "/playlists",
            headers=headers,
            json={"name": "Another Playlist"},
        )
        assert r_over.status_code == 409
        assert "Maximum playlist limit" in r_over.json()["detail"]
    finally:
        settings.MAX_PLAYLISTS_PER_USER = orig_max

    # 4. Delete playlist
    r_del = await client.delete(f"/playlists/{pl_id}", headers=headers)
    assert r_del.status_code == 204

    # 5. Get after delete -> 404
    r_get = await client.get(f"/playlists/{pl_id}", headers=headers)
    assert r_get.status_code == 404


@pytest.mark.asyncio
async def test_playlist_tracks_add_skip_duplicates_and_cover_thumbs(client: AsyncClient):
    email = f"pl_trk_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create playlist
    pl = (await client.post("/playlists", headers=headers, json={"name": "Test Tracks"})).json()
    pl_id = pl["id"]

    # Mock tracks with thumbnails
    t1 = make_mock_track("trkPl000001", "Song 1", "https://thumb/1.jpg")
    t2 = make_mock_track("trkPl000002", "Song 2", "https://thumb/2.jpg")
    t3 = make_mock_track("trkPl000003", "Song 3", "https://thumb/3.jpg")
    t4 = make_mock_track("trkPl000004", "Song 4", "https://thumb/4.jpg")
    t5 = make_mock_track("trkPl000005", "Song 5", "https://thumb/5.jpg")

    with patch("app.services.tracks.default_ytmusic_source.get_track", side_effect=[t1, t2, t3, t4, t5]):
        # Add 3 tracks
        r_add1 = await client.post(
            f"/playlists/{pl_id}/tracks",
            headers=headers,
            json={"video_ids": [t1.video_id, t2.video_id, t3.video_id]},
        )
        assert r_add1.status_code == 200
        res1 = r_add1.json()
        assert res1["added"] == 3
        assert res1["skipped"] == []

        # Add again with 1 duplicate and 2 new
        r_add2 = await client.post(
            f"/playlists/{pl_id}/tracks",
            headers=headers,
            json={"video_ids": [t2.video_id, t4.video_id, t5.video_id]},
        )
        assert r_add2.status_code == 200
        res2 = r_add2.json()
        assert res2["added"] == 2
        assert res2["skipped"] == [t2.video_id]

    # Verify playlist detail has 5 tracks, and 4 cover thumbnails (for 2x2 mosaic)
    r_detail = await client.get(f"/playlists/{pl_id}", headers=headers)
    assert r_detail.status_code == 200
    detail = r_detail.json()
    assert detail["track_count"] == 5
    assert len(detail["cover_thumbnails"]) == 4
    assert detail["cover_thumbnails"] == [
        "https://thumb/1.jpg",
        "https://thumb/2.jpg",
        "https://thumb/3.jpg",
        "https://thumb/4.jpg",
    ]


@pytest.mark.asyncio
async def test_playlist_reorder_and_remove(client: AsyncClient):
    email = f"pl_reorder_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    pl = (await client.post("/playlists", headers=headers, json={"name": "Reorder Test"})).json()
    pl_id = pl["id"]

    v1, v2, v3 = "ordTrk00001", "ordTrk00002", "ordTrk00003"
    t1 = make_mock_track(v1, "S1")
    t2 = make_mock_track(v2, "S2")
    t3 = make_mock_track(v3, "S3")

    with patch("app.services.tracks.default_ytmusic_source.get_track", side_effect=[t1, t2, t3]):
        await client.post(f"/playlists/{pl_id}/tracks", headers=headers, json={"video_ids": [v1, v2, v3]})

    # Reorder: Reverse order [v3, v2, v1]
    r_ord = await client.put(f"/playlists/{pl_id}/order", headers=headers, json={"video_ids": [v3, v2, v1]})
    assert r_ord.status_code == 204

    r_check = await client.get(f"/playlists/{pl_id}", headers=headers)
    items = r_check.json()["tracks"]["items"]
    assert [it["track"]["video_id"] for it in items] == [v3, v2, v1]
    assert [it["position"] for it in items] == [1, 2, 3]

    # Invalid reorder: missing id -> 422
    r_bad_set = await client.put(f"/playlists/{pl_id}/order", headers=headers, json={"video_ids": [v3, v1]})
    assert r_bad_set.status_code == 422

    # Remove track v2
    r_rem = await client.delete(f"/playlists/{pl_id}/tracks/{v2}", headers=headers)
    assert r_rem.status_code == 204

    r_after_rem = await client.get(f"/playlists/{pl_id}", headers=headers)
    items_after = r_after_rem.json()["tracks"]["items"]
    assert len(items_after) == 2
    assert [it["track"]["video_id"] for it in items_after] == [v3, v1]
    assert [it["position"] for it in items_after] == [1, 2]
