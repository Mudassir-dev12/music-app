import datetime
import re
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator
from app.sources.models import Track

VIDEO_ID_REGEX = re.compile(r"^[A-Za-z0-9_-]{11}$")


class HistoryCreate(BaseModel):
    video_id: str
    listened_seconds: int = Field(ge=0)
    client_event_id: str

    @field_validator("video_id")
    @classmethod
    def validate_video_id(cls, v: str) -> str:
        if not VIDEO_ID_REGEX.match(v):
            raise ValueError("video_id must be 11 URL-safe characters.")
        return v

    @field_validator("client_event_id")
    @classmethod
    def validate_client_event_id(cls, v: str) -> str:
        trimmed = v.strip()
        if not (1 <= len(trimmed) <= 64):
            raise ValueError("client_event_id must be between 1 and 64 characters.")
        for ch in trimmed:
            if ord(ch) < 32 and ch not in ("\t", "\n", "\r"):
                raise ValueError("client_event_id contains invalid control characters.")
        return trimmed


class HistoryItemOut(BaseModel):
    id: int
    played_at: datetime.datetime
    listened_seconds: int
    track: Track


class HistoryPageOut(BaseModel):
    items: List[HistoryItemOut]
    next_cursor: Optional[str] = None


class LikedItemOut(BaseModel):
    liked_at: datetime.datetime
    track: Track


class LikedPageOut(BaseModel):
    items: List[LikedItemOut]
    next_cursor: Optional[str] = None


class LikedIdsOut(BaseModel):
    ids: List[str]


class PlaylistCreate(BaseModel):
    name: str
    description: Optional[str] = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        trimmed = v.strip()
        if not (1 <= len(trimmed) <= 100):
            raise ValueError("name must be between 1 and 100 characters.")
        for ch in trimmed:
            if ord(ch) < 32 and ch not in ("\t", "\n", "\r"):
                raise ValueError("name contains invalid control characters.")
        return trimmed

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        trimmed = v.strip()
        if len(trimmed) > 300:
            raise ValueError("description cannot exceed 300 characters.")
        for ch in trimmed:
            if ord(ch) < 32 and ch not in ("\t", "\n", "\r"):
                raise ValueError("description contains invalid control characters.")
        return trimmed


class PlaylistUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        trimmed = v.strip()
        if not (1 <= len(trimmed) <= 100):
            raise ValueError("name must be between 1 and 100 characters.")
        for ch in trimmed:
            if ord(ch) < 32 and ch not in ("\t", "\n", "\r"):
                raise ValueError("name contains invalid control characters.")
        return trimmed

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        trimmed = v.strip()
        if len(trimmed) > 300:
            raise ValueError("description cannot exceed 300 characters.")
        for ch in trimmed:
            if ord(ch) < 32 and ch not in ("\t", "\n", "\r"):
                raise ValueError("description contains invalid control characters.")
        return trimmed


class PlaylistTrackItem(BaseModel):
    position: int
    added_at: datetime.datetime
    track: Track


class PlaylistTracksPage(BaseModel):
    items: List[PlaylistTrackItem]
    next_cursor: Optional[str] = None


class PlaylistOut(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    track_count: int
    duration_seconds: int
    cover_thumbnails: List[str]
    created_at: datetime.datetime
    updated_at: datetime.datetime


class PlaylistDetailOut(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    track_count: int
    duration_seconds: int
    cover_thumbnails: List[str]
    created_at: datetime.datetime
    updated_at: datetime.datetime
    tracks: PlaylistTracksPage


class PlaylistAddTracks(BaseModel):
    video_ids: List[str] = Field(min_length=1, max_length=100)

    @field_validator("video_ids")
    @classmethod
    def validate_video_ids(cls, v: List[str]) -> List[str]:
        for vid in v:
            if not VIDEO_ID_REGEX.match(vid):
                raise ValueError(f"Invalid video_id: '{vid}'")
        return v


class PlaylistAddResult(BaseModel):
    added: int
    skipped: List[str]


class PlaylistReorder(BaseModel):
    video_ids: List[str]

    @field_validator("video_ids")
    @classmethod
    def validate_video_ids(cls, v: List[str]) -> List[str]:
        for vid in v:
            if not VIDEO_ID_REGEX.match(vid):
                raise ValueError(f"Invalid video_id: '{vid}'")
        return v
