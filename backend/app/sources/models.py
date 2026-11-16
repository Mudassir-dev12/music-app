from typing import List, Literal, Optional
from pydantic import BaseModel

ItemType = Literal["song", "album", "artist", "playlist"]


class Artist(BaseModel):
    id: Optional[str] = None
    name: str


class Track(BaseModel):
    video_id: str
    title: str
    artists: List[Artist]
    artist: str
    album: Optional[str] = None
    album_id: Optional[str] = None
    duration_seconds: Optional[int] = None
    thumbnail: Optional[str] = None
    is_explicit: bool = False
    track_number: Optional[int] = None


class SearchResponse(BaseModel):
    query: str
    filter: str
    results: List[Track]


class ResolvedStream(BaseModel):
    url: str
    headers: dict[str, str] = {}
    content_type: Optional[str] = "audio/mp4"


# Phase 4 Discovery Models

class MediaItem(BaseModel):
    type: str  # "song" | "album" | "artist" | "playlist"
    id: str
    title: str
    subtitle: Optional[str] = None
    thumbnail: Optional[str] = None
    track: Optional[Track] = None
    year: Optional[int] = None
    is_explicit: Optional[bool] = None


class Shelf(BaseModel):
    key: str
    title: str
    subtitle: Optional[str] = None
    items: List[MediaItem]
    has_more: bool = False


class AlbumDetail(BaseModel):
    id: str
    title: str
    artists: List[Artist]
    year: Optional[int] = None
    album_type: str = "Album"
    thumbnail: Optional[str] = None
    track_count: int = 0
    duration_seconds: int = 0
    tracks: List[Track]
    description: Optional[str] = None


class ArtistDetail(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    thumbnail: Optional[str] = None
    top_songs: List[Track] = []
    albums: List[MediaItem] = []
    singles: List[MediaItem] = []
    related: List[MediaItem] = []


class PlaylistDetail(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    thumbnail: Optional[str] = None
    author: Optional[str] = None
    track_count: int = 0
    tracks: List[Track] = []


class LyricsLine(BaseModel):
    text: str
    start_ms: Optional[int] = None


class Lyrics(BaseModel):
    video_id: str
    source: Optional[str] = None
    synced: bool = False
    lines: List[LyricsLine] = []


class SearchSuggestionsResponse(BaseModel):
    suggestions: List[str]


class SearchFilterResponse(BaseModel):
    query: str
    filter: str
    results: List[MediaItem]


class SearchGroupedResponse(BaseModel):
    query: str
    top_result: Optional[MediaItem] = None
    sections: List[Shelf]


class HomeResponse(BaseModel):
    shelves: List[Shelf]


class ChartsResponse(BaseModel):
    shelves: List[Shelf]


class MoodCategory(BaseModel):
    title: str
    params: str


class MoodSection(BaseModel):
    title: str
    categories: List[MoodCategory]


class MoodsResponse(BaseModel):
    sections: List[MoodSection]


class MoodPlaylistsResponse(BaseModel):
    title: str
    items: List[MediaItem]


class WatchRadioResponse(BaseModel):
    tracks: List[Track]
