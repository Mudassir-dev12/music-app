import logging
import re
from typing import Any, List, Optional
from app.sources.models import (
    AlbumDetail,
    Artist,
    ArtistDetail,
    Lyrics,
    LyricsLine,
    MediaItem,
    MoodCategory,
    MoodSection,
    PlaylistDetail,
    Shelf,
    Track,
)
from app.sources.ytmusic import normalize_track_dict, parse_duration, upscale_thumbnail

logger = logging.getLogger("music_app.normalizer")


def extract_best_thumbnail(thumbnails: Any, target_size: int = 544) -> Optional[str]:
    """Finds the largest thumbnail in a list and upscales it."""
    if not thumbnails:
        return None
    url = None
    if isinstance(thumbnails, list) and len(thumbnails) > 0:
        # Sort by dimension if available
        sorted_thumbs = sorted(
            [t for t in thumbnails if isinstance(t, dict)],
            key=lambda t: (t.get("width") or 0) * (t.get("height") or 0),
            reverse=True,
        )
        if sorted_thumbs:
            url = sorted_thumbs[0].get("url")
        else:
            url = thumbnails[-1].get("url") if isinstance(thumbnails[-1], dict) else None
    elif isinstance(thumbnails, dict):
        url = thumbnails.get("url")
    elif isinstance(thumbnails, str):
        url = thumbnails

    if not url:
        return None

    # Upscale
    if "=w" in url and "-h" in url:
        return re.sub(r"=w\d+-h\d+[^=]*$", f"=w{target_size}-h{target_size}-l90-rj", url)
    if "=s" in url:
        return re.sub(r"=s\d+[^=]*$", f"=s{target_size}", url)
    return upscale_thumbnail(url)


def normalize_media_item(item: dict, default_type: Optional[str] = None) -> Optional[MediaItem]:
    """Defensively normalizes a raw YouTube Music result into a typed MediaItem."""
    if not isinstance(item, dict):
        return None

    raw_type = item.get("resultType") or item.get("type") or default_type
    if not raw_type:
        # Infer type from presence of identifiers
        if "videoId" in item:
            raw_type = "song"
        elif "browseId" in item and (item.get("browseId", "").startswith("MPRE") or "year" in item):
            raw_type = "album"
        elif "browseId" in item and item.get("browseId", "").startswith("UC"):
            raw_type = "artist"
        elif "playlistId" in item or (item.get("browseId", "").startswith("VL") or item.get("browseId", "").startswith("PL")):
            raw_type = "playlist"
        else:
            raw_type = "song"

    # Normalize type to one of "song", "album", "artist", "playlist"
    raw_type_str = str(raw_type).lower()
    if raw_type_str in ("song", "video", "track"):
        item_type = "song"
    elif raw_type_str in ("album", "single", "ep"):
        item_type = "album"
    elif raw_type_str in ("artist",):
        item_type = "artist"
    elif raw_type_str in ("playlist",):
        item_type = "playlist"
    else:
        logger.debug(f"Skipping media item with unknown type: {raw_type}")
        return None

    # Determine ID
    item_id = None
    if item_type == "song":
        item_id = item.get("videoId") or item.get("id")
    elif item_type == "album":
        item_id = item.get("browseId") or item.get("id")
    elif item_type == "artist":
        item_id = item.get("browseId") or item.get("channelId") or item.get("id")
    elif item_type == "playlist":
        item_id = item.get("playlistId") or item.get("id") or item.get("browseId")

    if not item_id or not isinstance(item_id, str):
        return None

    # Title
    title = str(item.get("title") or "Unknown")

    # Subtitle
    subtitle = None
    artists = item.get("artists")
    if isinstance(artists, list):
        artist_names = [a.get("name") for a in artists if isinstance(a, dict) and a.get("name")]
        if artist_names:
            subtitle = ", ".join(artist_names)
    elif isinstance(artists, str):
        subtitle = artists

    if not subtitle:
        if item.get("author"):
            author = item["author"]
            subtitle = author.get("name") if isinstance(author, dict) else str(author)
        elif item.get("subscribers"):
            subtitle = str(item["subscribers"])
        elif item.get("itemCount"):
            subtitle = f"{item['itemCount']} tracks"

    # Year
    year = None
    if item.get("year"):
        try:
            year = int(str(item["year"])[:4])
        except (ValueError, TypeError):
            pass

    # Thumbnail
    thumb = extract_best_thumbnail(item.get("thumbnails"))

    # Explicit
    is_explicit = bool(item.get("isExplicit") or item.get("explicit") or False)

    # For songs, attach full Track
    track = None
    if item_type == "song":
        track = normalize_track_dict(item)

    return MediaItem(
        type=item_type,
        id=item_id,
        title=title,
        subtitle=subtitle,
        thumbnail=thumb,
        track=track,
        year=year,
        is_explicit=is_explicit,
    )


def normalize_album(raw: dict, album_id: Optional[str] = None) -> Optional[AlbumDetail]:
    """Defensively normalizes ytmusicapi.get_album output."""
    if not isinstance(raw, dict):
        return None

    resolved_id = album_id or raw.get("browseId") or raw.get("audioPlaylistId") or raw.get("id") or ""
    title = str(raw.get("title") or "Unknown Album")

    # Artists
    artists: List[Artist] = []
    raw_artists = raw.get("artists")
    if isinstance(raw_artists, list):
        for a in raw_artists:
            if isinstance(a, dict) and a.get("name"):
                artists.append(Artist(id=a.get("id"), name=str(a["name"])))
            elif isinstance(a, str):
                artists.append(Artist(id=None, name=a))
    if not artists:
        artists = [Artist(id=None, name="Unknown Artist")]

    # Year
    year = None
    if raw.get("year"):
        try:
            year = int(str(raw["year"])[:4])
        except (ValueError, TypeError):
            pass

    album_type = str(raw.get("type") or "Album")
    thumbnail = extract_best_thumbnail(raw.get("thumbnails"), target_size=544)
    description = raw.get("description")

    # Tracks
    tracks: List[Track] = []
    raw_tracks = raw.get("tracks") or []
    total_seconds = 0
    if isinstance(raw_tracks, list):
        current_num = 1
        for t in raw_tracks:
            if not isinstance(t, dict):
                continue
            # ensure album info is propagated
            t_copy = dict(t)
            t_copy.setdefault("album", {"name": title, "id": resolved_id})
            trk = normalize_track_dict(t_copy)
            if trk:
                trk_number = t.get("trackNumber") or t.get("index")
                if trk_number is not None:
                    try:
                        trk.track_number = int(trk_number)
                    except (ValueError, TypeError):
                        trk.track_number = current_num
                else:
                    trk.track_number = current_num
                current_num += 1
                tracks.append(trk)
                if trk.duration_seconds:
                    total_seconds += trk.duration_seconds

    track_count = raw.get("trackCount") or len(tracks)

    return AlbumDetail(
        id=resolved_id,
        title=title,
        artists=artists,
        year=year,
        album_type=album_type,
        thumbnail=thumbnail,
        track_count=int(track_count),
        duration_seconds=total_seconds,
        tracks=tracks,
        description=str(description) if description else None,
    )


def normalize_artist(raw: dict) -> Optional[ArtistDetail]:
    """Defensively normalizes ytmusicapi.get_artist output."""
    if not isinstance(raw, dict):
        return None

    channel_id = raw.get("channelId") or raw.get("id") or ""
    name = str(raw.get("name") or "Unknown Artist")
    description = raw.get("description")
    thumbnail = extract_best_thumbnail(raw.get("thumbnails"), target_size=1200)

    # Top songs
    top_songs: List[Track] = []
    raw_songs = raw.get("songs")
    song_results = raw_songs.get("results") if isinstance(raw_songs, dict) else (raw_songs if isinstance(raw_songs, list) else [])
    if isinstance(song_results, list):
        for s in song_results:
            if isinstance(s, dict):
                trk = normalize_track_dict(s)
                if trk:
                    top_songs.append(trk)

    # Albums
    albums: List[MediaItem] = []
    raw_albums = raw.get("albums")
    alb_results = raw_albums.get("results") if isinstance(raw_albums, dict) else (raw_albums if isinstance(raw_albums, list) else [])
    if isinstance(alb_results, list):
        for a in alb_results:
            item = normalize_media_item(a, default_type="album")
            if item:
                albums.append(item)

    # Singles
    singles: List[MediaItem] = []
    raw_singles = raw.get("singles")
    single_results = raw_singles.get("results") if isinstance(raw_singles, dict) else (raw_singles if isinstance(raw_singles, list) else [])
    if isinstance(single_results, list):
        for s in single_results:
            item = normalize_media_item(s, default_type="album")
            if item:
                singles.append(item)

    # Related
    related: List[MediaItem] = []
    raw_related = raw.get("related")
    rel_results = raw_related.get("results") if isinstance(raw_related, dict) else (raw_related if isinstance(raw_related, list) else [])
    if isinstance(rel_results, list):
        for r in rel_results:
            item = normalize_media_item(r, default_type="artist")
            if item:
                related.append(item)

    return ArtistDetail(
        id=channel_id,
        name=name,
        description=str(description) if description else None,
        thumbnail=thumbnail,
        top_songs=top_songs,
        albums=albums,
        singles=singles,
        related=related,
    )


def normalize_playlist(raw: dict) -> Optional[PlaylistDetail]:
    """Defensively normalizes ytmusicapi.get_playlist output."""
    if not isinstance(raw, dict):
        return None

    playlist_id = raw.get("id") or ""
    title = str(raw.get("title") or "Unknown Playlist")
    description = raw.get("description")
    thumbnail = extract_best_thumbnail(raw.get("thumbnails"), target_size=544)

    author_name = None
    author_obj = raw.get("author")
    if isinstance(author_obj, dict):
        author_name = author_obj.get("name")
    elif isinstance(author_obj, str):
        author_name = author_obj

    tracks: List[Track] = []
    raw_tracks = raw.get("tracks") or []
    if isinstance(raw_tracks, list):
        for idx, t in enumerate(raw_tracks, start=1):
            if isinstance(t, dict):
                trk = normalize_track_dict(t)
                if trk:
                    trk.track_number = idx
                    tracks.append(trk)

    track_count = raw.get("trackCount") or len(tracks)

    return PlaylistDetail(
        id=playlist_id,
        title=title,
        description=str(description) if description else None,
        thumbnail=thumbnail,
        author=author_name,
        track_count=int(track_count),
        tracks=tracks,
    )


def normalize_lyrics(video_id: str, raw_lyrics: Any) -> Lyrics:
    """Normalizes timed or plain lyrics into a typed Lyrics model."""
    if not raw_lyrics:
        return Lyrics(video_id=video_id, synced=False, lines=[])

    # Case 1: Dict or object with timed lines
    lines: List[LyricsLine] = []
    is_synced = False
    source = None

    if isinstance(raw_lyrics, dict):
        source = raw_lyrics.get("source")
        raw_lines = raw_lyrics.get("lines")
        if isinstance(raw_lines, list) and len(raw_lines) > 0 and isinstance(raw_lines[0], dict) and "start" in raw_lines[0]:
            is_synced = True
            for line_dict in raw_lines:
                text = str(line_dict.get("text") or "").strip()
                start_val = line_dict.get("start")
                start_ms = None
                if start_val is not None:
                    try:
                        # Could be in ms or seconds
                        val = float(start_val)
                        start_ms = int(val if val > 1000 else val * 1000)
                    except (ValueError, TypeError):
                        pass
                lines.append(LyricsLine(text=text, start_ms=start_ms))
        elif "lyrics" in raw_lyrics:
            raw_text = str(raw_lyrics["lyrics"])
            for line in raw_text.splitlines():
                stripped = line.strip()
                if stripped:
                    lines.append(LyricsLine(text=stripped))
    elif hasattr(raw_lyrics, "lines") and getattr(raw_lyrics, "lines"):
        # TimedLyrics from ytmusicapi
        is_synced = True
        source = getattr(raw_lyrics, "source", None)
        for line_obj in raw_lyrics.lines:
            text = str(getattr(line_obj, "text", "")).strip()
            start = getattr(line_obj, "start", None)
            start_ms = None
            if start is not None:
                try:
                    val = float(start)
                    start_ms = int(val if val > 1000 else val * 1000)
                except (ValueError, TypeError):
                    pass
            lines.append(LyricsLine(text=text, start_ms=start_ms))
    elif hasattr(raw_lyrics, "lyrics"):
        source = getattr(raw_lyrics, "source", None)
        raw_text = str(getattr(raw_lyrics, "lyrics", ""))
        for line in raw_text.splitlines():
            stripped = line.strip()
            if stripped:
                lines.append(LyricsLine(text=stripped))
    elif isinstance(raw_lyrics, str):
        for line in raw_lyrics.splitlines():
            stripped = line.strip()
            if stripped:
                lines.append(LyricsLine(text=stripped))

    return Lyrics(
        video_id=video_id,
        source=source,
        synced=is_synced,
        lines=lines,
    )


def normalize_home_shelves(raw_home: list) -> List[Shelf]:
    """Normalizes ytmusicapi.get_home output to at most 8 Shelves of up to 12 items."""
    if not isinstance(raw_home, list):
        return []

    shelves: List[Shelf] = []
    has_marked_top_picks = False

    for idx, section in enumerate(raw_home):
        if not isinstance(section, dict):
            continue

        title = section.get("title")
        if not title:
            continue

        raw_contents = section.get("contents") or []
        if not isinstance(raw_contents, list) or not raw_contents:
            continue

        items: List[MediaItem] = []
        for c in raw_contents:
            if isinstance(c, dict):
                item = normalize_media_item(c)
                if item:
                    items.append(item)
            if len(items) >= 12:
                break

        if not items:
            continue

        # First suitable album/song shelf is marked 'top_picks'
        if not has_marked_top_picks and any(it.type in ("album", "song") for it in items):
            key = "top_picks"
            has_marked_top_picks = True
        else:
            slug = re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")
            key = f"shelf_{slug}" if slug else f"shelf_{idx}"

        shelves.append(
            Shelf(
                key=key,
                title=title,
                subtitle=section.get("subtitle"),
                items=items,
                has_more=bool(section.get("browseId") or len(raw_contents) > 12),
            )
        )

        if len(shelves) >= 8:
            break

    return shelves


def normalize_charts(raw_charts: dict) -> List[Shelf]:
    """Normalizes ytmusicapi.get_charts output into Shelves."""
    if not isinstance(raw_charts, dict):
        return []

    shelves: List[Shelf] = []
    category_defs = [
        ("videos", "Top Music Videos", "song"),
        ("songs", "Top Songs", "song"),
        ("trending", "Trending", "song"),
        ("artists", "Top Artists", "artist"),
    ]

    for key, title, def_type in category_defs:
        block = raw_charts.get(key)
        items_raw = []
        if isinstance(block, dict):
            items_raw = block.get("items") or []
        elif isinstance(block, list):
            items_raw = block

        items: List[MediaItem] = []
        for item_dict in items_raw[:12]:
            if isinstance(item_dict, dict):
                m_item = normalize_media_item(item_dict, default_type=def_type)
                if m_item:
                    items.append(m_item)
        if items:
            shelves.append(Shelf(key=f"charts_{key}", title=title, items=items))

    return shelves


def normalize_mood_categories(raw_categories: dict) -> List[MoodSection]:
    """Normalizes ytmusicapi.get_mood_categories output into MoodSections."""
    if not isinstance(raw_categories, dict):
        return []

    sections: List[MoodSection] = []
    for sec_title, cat_list in raw_categories.items():
        if not isinstance(cat_list, list):
            continue
        categories: List[MoodCategory] = []
        for cat in cat_list:
            if isinstance(cat, dict) and cat.get("title") and cat.get("params"):
                categories.append(
                    MoodCategory(
                        title=str(cat["title"]),
                        params=str(cat["params"]),
                    )
                )
        if categories:
            sections.append(MoodSection(title=str(sec_title), categories=categories))

    return sections


def normalize_mood_playlists(title: str, raw_playlists: list) -> List[MediaItem]:
    """Normalizes ytmusicapi.get_mood_playlists output."""
    if not isinstance(raw_playlists, list):
        return []

    items: List[MediaItem] = []
    for p in raw_playlists:
        if isinstance(p, dict):
            item = normalize_media_item(p, default_type="playlist")
            if item:
                items.append(item)
    return items


def normalize_radio_tracks(raw_watch: dict, current_video_id: str) -> List[Track]:
    """Normalizes similar tracks from get_watch_playlist, excluding current_video_id."""
    if not isinstance(raw_watch, dict):
        return []

    tracks_raw = raw_watch.get("tracks") or []
    tracks: List[Track] = []
    if isinstance(tracks_raw, list):
        for t in tracks_raw:
            if isinstance(t, dict):
                trk = normalize_track_dict(t)
                if trk and trk.video_id != current_video_id:
                    tracks.append(trk)
    return tracks
