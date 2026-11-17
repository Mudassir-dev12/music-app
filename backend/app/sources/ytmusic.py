import os
import re
import shutil
import time
from typing import Any, List, Optional
import anyio
from fastapi import HTTPException, status
import yt_dlp
from ytmusicapi import YTMusic
from app.sources.base import MusicSource
from app.sources.models import Artist, ResolvedStream, SearchResponse, Track


def parse_duration(duration_val: Any) -> Optional[int]:
    if isinstance(duration_val, (int, float)):
        return int(duration_val)
    if not isinstance(duration_val, str) or not duration_val.strip():
        return None
    parts = duration_val.strip().split(":")
    try:
        if len(parts) == 1:
            return int(parts[0])
        elif len(parts) == 2:
            return int(parts[0]) * 60 + int(parts[1])
        elif len(parts) == 3:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
    except ValueError:
        return None
    return None


def upscale_thumbnail(url: Optional[str]) -> Optional[str]:
    if not url:
        return None
    # Replaces =w...-h... with =w544-h544-l90-rj
    return re.sub(r"=w\d+-h\d+[^=]*$", "=w544-h544-l90-rj", url)


def normalize_track_dict(item: dict) -> Optional[Track]:
    video_id = item.get("videoId") or item.get("id")
    if not video_id or not isinstance(video_id, str):
        return None

    title = item.get("title") or "Unknown Title"

    # Normalize artists
    raw_artists = item.get("artists")
    artists: List[Artist] = []
    if isinstance(raw_artists, list):
        for a in raw_artists:
            if isinstance(a, dict) and a.get("name"):
                artists.append(Artist(id=a.get("id"), name=str(a["name"])))
            elif isinstance(a, str):
                artists.append(Artist(id=None, name=a))
    elif isinstance(raw_artists, str):
        artists.append(Artist(id=None, name=raw_artists))

    if not artists:
        artists = [Artist(id=None, name="Unknown Artist")]

    artist_name = ", ".join(a.name for a in artists)

    # Normalize album
    raw_album = item.get("album")
    album_name = None
    album_id = None
    if isinstance(raw_album, dict):
        album_name = raw_album.get("name")
        album_id = raw_album.get("id")
    elif isinstance(raw_album, str):
        album_name = raw_album

    # Normalize duration
    duration_val = item.get("duration_seconds")
    if duration_val is None:
        duration_val = parse_duration(item.get("duration"))

    # Normalize thumbnail
    thumbnails = item.get("thumbnails")
    thumb_url = None
    if isinstance(thumbnails, list) and thumbnails:
        # Pick largest thumbnail
        sorted_thumbs = sorted(
            thumbnails,
            key=lambda t: (t.get("width", 0) or 0) * (t.get("height", 0) or 0),
            reverse=True,
        )
        thumb_url = sorted_thumbs[0].get("url")
    elif isinstance(thumbnails, str):
        thumb_url = thumbnails

    thumb_url = upscale_thumbnail(thumb_url)

    # Normalize explicit
    is_explicit = bool(item.get("isExplicit") or item.get("explicit") or False)

    return Track(
        video_id=video_id,
        title=title,
        artists=artists,
        artist=artist_name,
        album=album_name,
        album_id=album_id,
        duration_seconds=duration_val,
        thumbnail=thumb_url,
        is_explicit=is_explicit,
    )


class YTMusicSource(MusicSource):
    def __init__(self):
        self._ytmusic = YTMusic()

    def _sync_search(self, query: str, filter_type: str, limit: int) -> list[dict]:
        last_exc = None
        for attempt in range(4):
            try:
                return self._ytmusic.search(query=query, filter=filter_type, limit=limit)
            except Exception as e:
                last_exc = e
                time.sleep(1.0 * (attempt + 1))
        if last_exc:
            raise last_exc
        return []

    def _sync_get_track(self, video_id: str) -> dict:
        for attempt in range(3):
            try:
                watch_data = self._ytmusic.get_watch_playlist(videoId=video_id, limit=1)
                tracks = watch_data.get("tracks", [])
                if tracks and len(tracks) > 0:
                    return tracks[0]
            except Exception:
                time.sleep(0.3)

        # Fallback to get_song
        for attempt in range(3):
            try:
                song_data = self._ytmusic.get_song(videoId=video_id)
                if song_data:
                    video_details = song_data.get("videoDetails", {})
                    return {
                        "videoId": video_details.get("videoId"),
                        "title": video_details.get("title"),
                        "artists": [{"name": video_details.get("author")}],
                        "duration_seconds": int(video_details.get("lengthSeconds", 0)) or None,
                        "thumbnails": video_details.get("thumbnail", {}).get("thumbnails", []),
                    }
            except Exception:
                time.sleep(0.3)

        return {}

    def _sync_resolve_stream(self, video_id: str) -> ResolvedStream:
        ydl_opts: dict[str, Any] = {
            "format": "bestaudio[ext=m4a]/bestaudio",
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
            "skip_download": True,
            "socket_timeout": 15,
            "retries": 2,
            "cachedir": False,
        }
        node_path = shutil.which("node")
        if node_path:
            ydl_opts["js_runtimes"] = {"node": {"path": node_path}}
        cookie_path = os.getenv("YTDLP_COOKIES_FILE", "/var/www/music-app/data/cookies.txt")
        if os.path.exists(cookie_path):
            ydl_opts["cookiefile"] = cookie_path
        proxy = os.getenv("YTDLP_PROXY")
        if proxy:
            ydl_opts["proxy"] = proxy
        url = f"https://www.youtube.com/watch?v={video_id}"
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                raise ValueError("Could not extract stream info from YouTube")

            stream_url = info.get("url")
            if not stream_url:
                raise ValueError("No stream URL in extracted info")

            http_headers = info.get("http_headers", {})
            ext = info.get("ext", "m4a")
            acodec = info.get("acodec", "")

            content_type = "audio/mp4"
            if "webm" in ext or "opus" in acodec:
                content_type = "audio/webm"
            elif "mp3" in ext or "mp3" in acodec:
                content_type = "audio/mpeg"

            return ResolvedStream(
                url=stream_url,
                headers=http_headers,
                content_type=content_type,
            )

    async def search(self, query: str, filter_type: str, limit: int) -> SearchResponse:
        if filter_type != "songs":
            raise HTTPException(
                status_code=422,
                detail=f"Filter '{filter_type}' is not supported in Phase 1 (only 'songs' is supported).",
            )

        raw_results = await anyio.to_thread.run_sync(
            self._sync_search, query, filter_type, limit
        )

        tracks: List[Track] = []
        for item in raw_results:
            normalized = normalize_track_dict(item)
            if normalized:
                tracks.append(normalized)

        return SearchResponse(
            query=query,
            filter=filter_type,
            results=tracks[:limit],
        )

    async def get_track(self, video_id: str) -> Track:
        raw_data = await anyio.to_thread.run_sync(self._sync_get_track, video_id)
        if not raw_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Track not found.",
            )
        track = normalize_track_dict(raw_data)
        if not track:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Track not found.",
            )
        return track

    async def resolve_stream(self, video_id: str) -> ResolvedStream:
        return await anyio.to_thread.run_sync(self._sync_resolve_stream, video_id)
