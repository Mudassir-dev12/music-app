import json
from pathlib import Path
import pytest
from app.services.discovery_normalizer import (
    extract_best_thumbnail,
    normalize_album,
    normalize_artist,
    normalize_charts,
    normalize_home_shelves,
    normalize_lyrics,
    normalize_media_item,
    normalize_mood_categories,
    normalize_mood_playlists,
    normalize_playlist,
    normalize_radio_tracks,
    upscale_thumbnail,
)
from app.sources.models import AlbumDetail, ArtistDetail, Lyrics, PlaylistDetail

FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures" / "ytm"


def load_fixture(name: str):
    return json.loads((FIXTURES_DIR / name).read_text(encoding="utf-8"))


def test_upscale_thumbnail():
    url = "https://yt3.ggpht.com/abc=w120-h120-l90-rj"
    upscaled = upscale_thumbnail(url)
    assert "=w544-h544-l90-rj" in upscaled

    custom = extract_best_thumbnail([{"url": url, "width": 120, "height": 120}], target_size=1200)
    assert "=w1200-h1200-l90-rj" in custom


def test_normalize_search_songs_fixture():
    raw = load_fixture("search_songs.json")
    items = [normalize_media_item(r, default_type="song") for r in raw]
    items = [it for it in items if it]
    assert len(items) > 0
    first = items[0]
    assert first.type == "song"
    assert first.id
    assert first.title
    assert first.track is not None
    assert first.track.video_id == first.id


def test_normalize_search_albums_fixture():
    raw = load_fixture("search_albums.json")
    items = [normalize_media_item(r, default_type="album") for r in raw]
    items = [it for it in items if it]
    assert len(items) > 0
    first = items[0]
    assert first.type == "album"
    assert first.id


def test_normalize_search_artists_fixture():
    raw = load_fixture("search_artists.json")
    items = [normalize_media_item(r, default_type="artist") for r in raw]
    items = [it for it in items if it]
    assert len(items) > 0
    first = items[0]
    assert first.type == "artist"
    assert first.id


def test_normalize_search_playlists_fixture():
    raw = load_fixture("search_playlists.json")
    items = [normalize_media_item(r, default_type="playlist") for r in raw]
    items = [it for it in items if it]
    assert len(items) > 0
    first = items[0]
    assert first.type == "playlist"
    assert first.id


def test_normalize_home_shelves_fixture():
    raw = load_fixture("home.json")
    shelves = normalize_home_shelves(raw)
    assert len(shelves) > 0
    assert len(shelves) <= 8
    # At least one shelf should be marked 'top_picks' if it has album or song
    has_top_picks = any(s.key == "top_picks" for s in shelves)
    assert has_top_picks
    for s in shelves:
        assert len(s.items) <= 12
        assert s.title


def test_normalize_charts_fixture():
    raw = load_fixture("charts.json")
    shelves = normalize_charts(raw)
    assert len(shelves) > 0
    keys = [s.key for s in shelves]
    assert any("charts_" in k for k in keys)


def test_normalize_mood_categories_and_playlists_fixture():
    raw_cats = load_fixture("mood_categories.json")
    sections = normalize_mood_categories(raw_cats)
    assert len(sections) > 0
    assert sections[0].title
    assert len(sections[0].categories) > 0
    assert sections[0].categories[0].params

    raw_pls = load_fixture("mood_playlists.json")
    pls = normalize_mood_playlists("Chill", raw_pls)
    assert len(pls) > 0
    assert pls[0].type == "playlist"


def test_normalize_album_fixture():
    raw = load_fixture("album.json")
    album = normalize_album(raw)
    assert isinstance(album, AlbumDetail)
    assert album.id
    assert album.title
    assert len(album.artists) > 0
    assert len(album.tracks) > 0
    # Track numbers must be positive integers
    assert album.tracks[0].track_number == 1


def test_normalize_artist_fixture():
    raw = load_fixture("artist.json")
    artist = normalize_artist(raw)
    assert isinstance(artist, ArtistDetail)
    assert artist.id
    assert artist.name


def test_normalize_playlist_fixture():
    raw = load_fixture("playlist.json")
    pl = normalize_playlist(raw)
    assert isinstance(pl, PlaylistDetail)
    assert pl.id
    assert pl.title
    assert len(pl.tracks) > 0


def test_normalize_watch_radio_fixture():
    raw = load_fixture("watch_radio.json")
    # Take first track video_id as current_vid
    first_vid = raw["tracks"][0].get("videoId")
    radio_tracks = normalize_radio_tracks(raw, current_video_id=first_vid)
    assert len(radio_tracks) > 0
    # current_vid must be excluded
    assert all(t.video_id != first_vid for t in radio_tracks)


def test_normalize_lyrics_synced_and_plain():
    raw_synced = load_fixture("lyrics_synced.json")
    synced = normalize_lyrics("test_vid_1", raw_synced)
    assert synced.synced is True
    assert len(synced.lines) > 0
    assert synced.lines[0].start_ms == 0
    assert synced.lines[1].start_ms == 3500

    raw_plain = load_fixture("lyrics.json")
    plain = normalize_lyrics("test_vid_2", raw_plain)
    assert plain.synced is False
    assert len(plain.lines) > 0
    assert plain.lines[0].start_ms is None


def test_defensive_normalization_messy_variants():
    # 1. Broken / empty media item
    assert normalize_media_item({}) is None
    assert normalize_media_item(None) is None
    assert normalize_media_item({"title": "No ID"}) is None

    # 2. Broken album with None tracks and weird artist
    messy_album = {
        "browseId": "MPREb_test",
        "title": "Messy Album",
        "artists": None,
        "tracks": [
            None,
            {"title": "Track with no ID"},
            {"videoId": "goodTrk0001", "title": "Good Track", "duration": "3:20"},
        ],
    }
    alb = normalize_album(messy_album)
    assert alb is not None
    assert len(alb.tracks) == 1
    assert alb.tracks[0].video_id == "goodTrk0001"
    assert alb.tracks[0].track_number == 1

    # 3. Messy lyrics with empty strings
    empty_lyrics = normalize_lyrics("vid_empty", "")
    assert empty_lyrics.synced is False
    assert len(empty_lyrics.lines) == 0
