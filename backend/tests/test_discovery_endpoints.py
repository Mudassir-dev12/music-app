import json
from pathlib import Path
from unittest.mock import AsyncMock, patch
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from app.db.models import Track as TrackModel
from app.db.session import get_sessionmaker

FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures" / "ytm"


def load_fixture(name: str):
    return json.loads((FIXTURES_DIR / name).read_text(encoding="utf-8"))


async def get_auth_headers(client: AsyncClient) -> dict[str, str]:
    email = f"disc_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register",
        json={"email": email, "password": "ValidPassword123!"},
    )
    token = reg.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_search_songs_filter_and_tracks_upsert(client: AsyncClient):
    headers = await get_auth_headers(client)
    fixture_songs = load_fixture("search_songs.json")

    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.search",
        return_value=fixture_songs,
    ):
        res = await client.get("/search?q=Bohemian+Rhapsody&filter=songs", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data["query"] == "Bohemian Rhapsody"
        assert data["filter"] == "songs"
        assert len(data["results"]) > 0
        assert "X-Cache" in res.headers

        # Verify songs are upserted into SQLite tracks table
        first_vid = data["results"][0]["video_id"]
        async with get_sessionmaker()() as db:
            row = (await db.execute(select(TrackModel).where(TrackModel.video_id == first_vid))).scalar_one_or_none()
            assert row is not None
            assert row.title == data["results"][0]["title"]


@pytest.mark.asyncio
async def test_search_filter_albums_artists_playlists(client: AsyncClient):
    headers = await get_auth_headers(client)

    # 1. Albums
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.search",
        return_value=load_fixture("search_albums.json"),
    ):
        res_alb = await client.get("/search?q=1989&filter=albums", headers=headers)
        assert res_alb.status_code == 200
        data_alb = res_alb.json()
        assert data_alb["filter"] == "albums"
        assert len(data_alb["results"]) > 0
        assert data_alb["results"][0]["type"] == "album"

    # 2. Artists
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.search",
        return_value=load_fixture("search_artists.json"),
    ):
        res_art = await client.get("/search?q=Daft+Punk&filter=artists", headers=headers)
        assert res_art.status_code == 200
        data_art = res_art.json()
        assert data_art["filter"] == "artists"
        assert len(data_art["results"]) > 0
        assert data_art["results"][0]["type"] == "artist"

    # 3. Playlists
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.search",
        return_value=load_fixture("search_playlists.json"),
    ):
        res_pl = await client.get("/search?q=Chill&filter=playlists", headers=headers)
        assert res_pl.status_code == 200
        data_pl = res_pl.json()
        assert data_pl["filter"] == "playlists"
        assert len(data_pl["results"]) > 0
        assert data_pl["results"][0]["type"] == "playlist"


@pytest.mark.asyncio
async def test_search_grouped_no_filter(client: AsyncClient):
    headers = await get_auth_headers(client)
    fixture_grouped = load_fixture("search_songs.json") + load_fixture("search_albums.json")

    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.search",
        return_value=fixture_grouped,
    ):
        res = await client.get("/search?q=Queen", headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert data["query"] == "Queen"
        assert "sections" in data
        assert len(data["sections"]) > 0


@pytest.mark.asyncio
async def test_search_suggestions(client: AsyncClient):
    headers = await get_auth_headers(client)

    # 1. Success
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_search_suggestions",
        return_value=load_fixture("search_suggestions.json"),
    ):
        res = await client.get("/search/suggestions?q=billie", headers=headers)
        assert res.status_code == 200
        assert len(res.json()["suggestions"]) > 0

    # 2. Failure returns empty list, not 500/502
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_search_suggestions",
        side_effect=Exception("Upstream timeout"),
    ):
        res_fail = await client.get("/search/suggestions?q=unknown_term", headers=headers)
        assert res_fail.status_code == 200
        assert res_fail.json() == {"suggestions": []}


@pytest.mark.asyncio
async def test_discover_home_and_charts(client: AsyncClient):
    headers = await get_auth_headers(client)

    # 1. Home
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_home",
        return_value=load_fixture("home.json"),
    ):
        res_home = await client.get("/discover/home", headers=headers)
        assert res_home.status_code == 200
        shelves = res_home.json()["shelves"]
        assert len(shelves) > 0
        assert any(s["key"] == "top_picks" for s in shelves)

    # 2. Charts with valid region
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_charts",
        return_value=load_fixture("charts.json"),
    ):
        res_charts = await client.get("/discover/charts?region=US", headers=headers)
        assert res_charts.status_code == 200
        assert len(res_charts.json()["shelves"]) > 0

    # 3. Charts with invalid region -> 400
    res_bad_region = await client.get("/discover/charts?region=USA", headers=headers)
    assert res_bad_region.status_code == 400


@pytest.mark.asyncio
async def test_discover_moods_and_playlists(client: AsyncClient):
    headers = await get_auth_headers(client)

    # 1. Moods
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_mood_categories",
        return_value=load_fixture("mood_categories.json"),
    ):
        res_moods = await client.get("/discover/moods", headers=headers)
        assert res_moods.status_code == 200
        sections = res_moods.json()["sections"]
        assert len(sections) > 0

    # 2. Mood playlists with valid params
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_mood_playlists",
        return_value=load_fixture("mood_playlists.json"),
    ):
        res_pls = await client.get("/discover/moods/ggMPOg1uX1BsdnMxZ3E/playlists", headers=headers)
        assert res_pls.status_code == 200
        assert len(res_pls.json()["items"]) > 0

    # 3. Mood playlists with invalid params -> 400
    res_bad_params = await client.get("/discover/moods/bad%20params!/playlists", headers=headers)
    assert res_bad_params.status_code == 400


@pytest.mark.asyncio
async def test_album_and_artist_details(client: AsyncClient):
    headers = await get_auth_headers(client)

    # 1. Album detail
    alb_raw = load_fixture("album.json")
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_album",
        return_value=alb_raw,
    ):
        res_alb = await client.get("/albums/MPREb_K9GL6DCDUCq", headers=headers)
        assert res_alb.status_code == 200
        alb_data = res_alb.json()
        assert alb_data["title"] == "1989"
        assert len(alb_data["tracks"]) > 0

    # 2. Artist detail
    art_raw = load_fixture("artist.json")
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_artist",
        return_value=art_raw,
    ):
        res_art = await client.get("/artists/UCRr1xG_2WIDs18a6cIiCxeA", headers=headers)
        assert res_art.status_code == 200
        art_data = res_art.json()
        assert art_data["name"]

    # 3. Invalid IDs -> 400
    assert (await client.get("/albums/!", headers=headers)).status_code == 400
    assert (await client.get("/artists/!", headers=headers)).status_code == 400


@pytest.mark.asyncio
async def test_ytplaylist_and_radio(client: AsyncClient):
    headers = await get_auth_headers(client)

    # 1. Public YouTube playlist
    pl_raw = load_fixture("playlist.json")
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_playlist",
        return_value=pl_raw,
    ):
        res_pl = await client.get("/ytplaylists/PLE3uncMq8x3wU0IE3TxIVG1didfvxNUcr", headers=headers)
        assert res_pl.status_code == 200
        assert len(res_pl.json()["tracks"]) > 0

    # 2. Watch / Radio
    radio_raw = load_fixture("watch_radio.json")
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_watch_playlist",
        return_value=radio_raw,
    ):
        res_radio = await client.get("/watch/BSTsnWoslP4/radio", headers=headers)
        assert res_radio.status_code == 200
        assert len(res_radio.json()["tracks"]) > 0
        # Excludes BSTsnWoslP4
        assert all(t["video_id"] != "BSTsnWoslP4" for t in res_radio.json()["tracks"])

    # 3. Invalid IDs -> 400
    assert (await client.get("/ytplaylists/!", headers=headers)).status_code == 400
    assert (await client.get("/watch/short/radio", headers=headers)).status_code == 400


@pytest.mark.asyncio
async def test_lyrics_synced_and_404(client: AsyncClient):
    headers = await get_auth_headers(client)

    # 1. Synced lyrics
    watch_mock = {"lyrics": "MPLYlyrics_id_1"}
    lyrics_synced_raw = load_fixture("lyrics_synced.json")
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_watch_playlist",
        return_value=watch_mock,
    ), patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_lyrics",
        return_value=lyrics_synced_raw,
    ):
        res_lyr = await client.get("/lyrics/fJ9rUzIMcZQ", headers=headers)
        assert res_lyr.status_code == 200
        data = res_lyr.json()
        assert data["synced"] is True
        assert len(data["lines"]) > 0
        assert data["lines"][0]["start_ms"] == 0

    # 2. Track with no lyrics -> 404
    with patch(
        "app.services.discovery_service.default_discovery_service._ytm.get_watch_playlist",
        return_value={},  # no lyrics key
    ):
        res_404 = await client.get("/lyrics/nolyrics111", headers=headers)
        assert res_404.status_code == 404


@pytest.mark.asyncio
async def test_unauthenticated_requests_return_401(client: AsyncClient):
    assert (await client.get("/search?q=test")).status_code == 401
    assert (await client.get("/search/suggestions?q=test")).status_code == 401
    assert (await client.get("/discover/home")).status_code == 401
    assert (await client.get("/discover/charts")).status_code == 401
    assert (await client.get("/discover/moods")).status_code == 401
    assert (await client.get("/albums/browse123")).status_code == 401
    assert (await client.get("/artists/channel123")).status_code == 401
    assert (await client.get("/ytplaylists/playlist123")).status_code == 401
    assert (await client.get("/watch/BSTsnWoslP4/radio")).status_code == 401
    assert (await client.get("/lyrics/BSTsnWoslP4")).status_code == 401
