from typing import List, Optional
from pydantic import BaseModel


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


class SearchResponse(BaseModel):
    query: str
    filter: str
    results: List[Track]


class ResolvedStream(BaseModel):
    url: str
    headers: dict[str, str] = {}
    content_type: Optional[str] = "audio/mp4"
