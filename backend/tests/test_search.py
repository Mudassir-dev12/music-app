from unittest.mock import AsyncMock, patch
import uuid
import pytest
from httpx import AsyncClient
from app.sources.models import Artist, SearchResponse, Track
from app.sources.ytmusic import normalize_track_dict


def test_normalize_track_fixtures():
    # 1. Missing videoId -> skipped (None)
    assert normalize_track_dict({"title": "No ID"}) is None

    # 2. Messy fixture: string artists, odd duration, query params thumbnail
    raw = {
        "videoId": "abc12345678",
        "title": "Messy Track",
        "artists": "Lone Artist",
        "album": {"name": "Great Album", "id": "alb123"},
        "duration": "4:20",
        "thumbnails": [{"url": "https://lh3.googleusercontent.com/test=w120-h120-l90", "width": 120, "height": 120}],
        "isExplicit": True,
    }
    track = normalize_track_dict(raw)
    assert track is not None
    assert track.video_id == "abc12345678"
    assert track.artist == "Lone Artist"
    assert track.artists[0].name == "Lone Artist"
    assert track.duration_seconds == 260
    assert track.album == "Great Album"
    assert "=w544-h544-l90-rj" in track.thumbnail
    assert track.is_explicit is True

    # 3. None/missing artists defaults gracefully
    raw_no_art = {
        "videoId": "xyz98765432",
        "title": "No Artist Track",
        "artists": None,
    }
    track2 = normalize_track_dict(raw_no_art)
    assert track2 is not None
    assert track2.artist == "Unknown Artist"
    assert track2.is_explicit is False


@pytest.mark.asyncio
async def test_search_endpoint_caching_and_validation(client: AsyncClient):
    email = f"search_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Bad q / limit
    r_empty_q = await client.get("/search?q=&limit=10", headers=headers)
    assert r_empty_q.status_code == 422

    r_bad_limit = await client.get("/search?q=test&limit=100", headers=headers)
    assert r_bad_limit.status_code == 422

    # 2. Unsupported filter
    r_filter = await client.get("/search?q=test&filter=invalid", headers=headers)
    assert r_filter.status_code == 422

    # 3. Search caching check
    mock_track = Track(
        video_id="mock1234567",
        title="Mock Song",
        artists=[Artist(name="Mock Artist")],
        artist="Mock Artist",
    )
    mock_res = SearchResponse(query="believer", filter="songs", results=[mock_track])

    with patch("app.routes.search.ytmusic_source.search", new_callable=AsyncMock) as mock_search:
        mock_search.return_value = mock_res

        # Call 1: calls source
        resp1 = await client.get("/search?q=believer&filter=songs&limit=10", headers=headers)
        assert resp1.status_code == 200
        assert mock_search.call_count == 1

        # Call 2: served from cache, does NOT call source
        resp2 = await client.get("/search?q=believer&filter=songs&limit=10", headers=headers)
        assert resp2.status_code == 200
        assert mock_search.call_count == 1
