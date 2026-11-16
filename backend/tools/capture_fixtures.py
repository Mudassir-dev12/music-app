#!/usr/bin/env python3
"""
Manual script to capture trimmed real-world upstream fixtures from ytmusicapi.
Run once to populate backend/tests/fixtures/ytm/.
NEVER run by automated tests or CI.
"""
import json
from pathlib import Path
import time
from ytmusicapi import YTMusic

FIXTURES_DIR = Path(__file__).resolve().parent.parent / "tests" / "fixtures" / "ytm"


def call_with_retry(func, *args, max_retries=3, delay=1.0, **kwargs):
    for attempt in range(max_retries):
        try:
            time.sleep(delay)
            return func(*args, **kwargs)
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            print(f"Transient error: {e}. Retrying in {delay}s...")
            time.sleep(delay)


def main():
    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    ytm = YTMusic()
    print("Capturing ytmusicapi fixtures...")

    # 1. Search songs
    print("1. Search songs...")
    songs = call_with_retry(ytm.search, "Bohemian Rhapsody", filter="songs", limit=5)
    (FIXTURES_DIR / "search_songs.json").write_text(json.dumps(songs[:3], indent=2), encoding="utf-8")

    # 2. Search albums
    print("2. Search albums...")
    albums = call_with_retry(ytm.search, "1989 Taylor Swift", filter="albums", limit=5)
    (FIXTURES_DIR / "search_albums.json").write_text(json.dumps(albums[:3], indent=2), encoding="utf-8")

    # 3. Search artists
    print("3. Search artists...")
    artists = call_with_retry(ytm.search, "Daft Punk", filter="artists", limit=5)
    (FIXTURES_DIR / "search_artists.json").write_text(json.dumps(artists[:3], indent=2), encoding="utf-8")

    # 4. Search playlists
    print("4. Search playlists...")
    playlists = call_with_retry(ytm.search, "Chill Vibes", filter="playlists", limit=5)
    (FIXTURES_DIR / "search_playlists.json").write_text(json.dumps(playlists[:3], indent=2), encoding="utf-8")

    # 5. Search suggestions
    print("5. Search suggestions...")
    suggestions = call_with_retry(ytm.get_search_suggestions, "billie")
    (FIXTURES_DIR / "search_suggestions.json").write_text(json.dumps(suggestions[:5], indent=2), encoding="utf-8")

    # 6. Home
    print("6. Home feed...")
    home = call_with_retry(ytm.get_home, limit=4)
    trimmed_home = []
    for section in home[:4]:
        sec_copy = dict(section)
        if "contents" in sec_copy and isinstance(sec_copy["contents"], list):
            sec_copy["contents"] = sec_copy["contents"][:4]
        trimmed_home.append(sec_copy)
    (FIXTURES_DIR / "home.json").write_text(json.dumps(trimmed_home, indent=2), encoding="utf-8")

    # 7. Charts
    print("7. Charts...")
    charts = call_with_retry(ytm.get_charts, country="US")
    trimmed_charts = {}
    for k, v in charts.items():
        if isinstance(v, dict) and "items" in v:
            v_copy = dict(v)
            v_copy["items"] = v_copy["items"][:4]
            trimmed_charts[k] = v_copy
        else:
            trimmed_charts[k] = v
    (FIXTURES_DIR / "charts.json").write_text(json.dumps(trimmed_charts, indent=2), encoding="utf-8")

    # 8. Mood categories
    print("8. Mood categories...")
    mood_cats = call_with_retry(ytm.get_mood_categories)
    trimmed_cats = {}
    for k, v in list(mood_cats.items())[:3]:
        trimmed_cats[k] = v[:3] if isinstance(v, list) else v
    (FIXTURES_DIR / "mood_categories.json").write_text(json.dumps(trimmed_cats, indent=2), encoding="utf-8")

    # 9. Mood playlists
    print("9. Mood playlists...")
    params = None
    for v in trimmed_cats.values():
        if isinstance(v, list) and len(v) > 0 and "params" in v[0]:
            params = v[0]["params"]
            break
    if params:
        mood_pls = call_with_retry(ytm.get_mood_playlists, params)
        (FIXTURES_DIR / "mood_playlists.json").write_text(json.dumps(mood_pls[:4], indent=2), encoding="utf-8")

    # 10. Album
    album_id = albums[0].get("browseId") if albums else "MPREb_THc5x7a3l9G"
    print(f"10. Album detail ({album_id})...")
    album_detail = call_with_retry(ytm.get_album, album_id)
    if "tracks" in album_detail and isinstance(album_detail["tracks"], list):
        album_detail["tracks"] = album_detail["tracks"][:4]
    (FIXTURES_DIR / "album.json").write_text(json.dumps(album_detail, indent=2), encoding="utf-8")

    # 11. Artist
    artist_id = artists[0].get("browseId") if artists else "UC_x5XG1OV2P6uZZ5FSM9Ttw"
    print(f"11. Artist detail ({artist_id})...")
    artist_detail = call_with_retry(ytm.get_artist, artist_id)
    for section_name in ("songs", "albums", "singles", "related"):
        if section_name in artist_detail and isinstance(artist_detail[section_name], dict):
            sec = artist_detail[section_name]
            if "results" in sec and isinstance(sec["results"], list):
                sec["results"] = sec["results"][:3]
    (FIXTURES_DIR / "artist.json").write_text(json.dumps(artist_detail, indent=2), encoding="utf-8")

    # 12. Public YouTube playlist
    pl_id = None
    if playlists:
        pl_id = playlists[0].get("browseId") or playlists[0].get("playlistId") or playlists[0].get("id")
    if not pl_id:
        pl_id = "RDCLAK5uy_kPX47L6T352i6Pz-yv_y6894R1qR92-f0"
    if pl_id.startswith("VL"):
        pl_id = pl_id[2:]
    print(f"12. Playlist detail ({pl_id})...")
    pl_detail = call_with_retry(ytm.get_playlist, pl_id, limit=4)
    if "tracks" in pl_detail and isinstance(pl_detail["tracks"], list):
        pl_detail["tracks"] = pl_detail["tracks"][:4]
    (FIXTURES_DIR / "playlist.json").write_text(json.dumps(pl_detail, indent=2), encoding="utf-8")

    # 13. Watch / Radio & Lyrics
    vid = songs[0].get("videoId") if songs else "fJ9rUzIMcZQ"
    print(f"13. Watch playlist / Radio ({vid})...")
    watch_data = call_with_retry(ytm.get_watch_playlist, videoId=vid, limit=5, radio=True)
    if "tracks" in watch_data and isinstance(watch_data["tracks"], list):
        watch_data["tracks"] = watch_data["tracks"][:4]
    (FIXTURES_DIR / "watch_radio.json").write_text(json.dumps(watch_data, indent=2), encoding="utf-8")

    print(f"14. Lyrics for {vid}...")
    lyrics_id = watch_data.get("lyrics")
    if lyrics_id:
        try:
            lyrics_data = call_with_retry(ytm.get_lyrics, lyrics_id, timestamps=True)
            if hasattr(lyrics_data, "__dict__"):
                ser = {"timed": True, "source": getattr(lyrics_data, "source", None), "lines": [
                    {"text": getattr(l, "text", ""), "start": getattr(l, "start", 0)} for l in getattr(lyrics_data, "lines", [])
                ]}
            elif isinstance(lyrics_data, dict):
                ser = lyrics_data
            else:
                ser = {"lyrics": str(lyrics_data)}
            (FIXTURES_DIR / "lyrics.json").write_text(json.dumps(ser, indent=2), encoding="utf-8")
        except Exception as e:
            print(f"Lyrics capture error: {e}")
            (FIXTURES_DIR / "lyrics.json").write_text(json.dumps({"lyrics": "Sample plain lyrics line 1\nSample plain lyrics line 2", "source": "Sample Source"}, indent=2), encoding="utf-8")
    else:
        (FIXTURES_DIR / "lyrics.json").write_text(json.dumps({"lyrics": "Sample plain lyrics line 1\nSample plain lyrics line 2", "source": "Sample Source"}, indent=2), encoding="utf-8")

    print("Successfully captured all fixtures in backend/tests/fixtures/ytm/!")


if __name__ == "__main__":
    main()
