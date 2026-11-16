import re
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import rate_limiter
from app.services.discovery_service import default_discovery_service
from app.sources.models import (
    AlbumDetail,
    ArtistDetail,
    Lyrics,
    PlaylistDetail,
    WatchRadioResponse,
)

router = APIRouter(tags=["catalog"])

ID_REGEX = re.compile(r"^[A-Za-z0-9_-]{2,100}$")
VIDEO_ID_REGEX = re.compile(r"^[A-Za-z0-9_-]{11}$")


def validate_catalog_id(ident: str, name: str = "Identifier") -> str:
    if not ID_REGEX.match(ident):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid {name} format.",
        )
    return ident


def validate_video_id(video_id: str) -> str:
    if not VIDEO_ID_REGEX.match(video_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid video_id format. Expected 11 URL-safe characters.",
        )
    return video_id


@router.get("/albums/{browse_id}", response_model=AlbumDetail)
async def get_album_detail(
    browse_id: str,
    response: Response,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    validate_catalog_id(browse_id, "browse_id")
    res, cache_status = await default_discovery_service.get_album(db, browse_id=browse_id)
    response.headers["X-Cache"] = cache_status
    return res


@router.get("/artists/{channel_id}", response_model=ArtistDetail)
async def get_artist_detail(
    channel_id: str,
    response: Response,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    validate_catalog_id(channel_id, "channel_id")
    res, cache_status = await default_discovery_service.get_artist(db, channel_id=channel_id)
    response.headers["X-Cache"] = cache_status
    return res


@router.get("/ytplaylists/{playlist_id}", response_model=PlaylistDetail)
async def get_youtube_playlist(
    playlist_id: str,
    response: Response,
    limit: int = Query(100, ge=1, le=200),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    validate_catalog_id(playlist_id, "playlist_id")
    res, cache_status = await default_discovery_service.get_playlist(db, playlist_id=playlist_id, limit=limit)
    response.headers["X-Cache"] = cache_status
    return res


@router.get("/watch/{video_id}/radio", response_model=WatchRadioResponse)
async def get_watch_radio(
    video_id: str,
    response: Response,
    limit: int = Query(25, ge=1, le=50),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    validate_video_id(video_id)
    res, cache_status = await default_discovery_service.get_radio(db, video_id=video_id, limit=limit)
    response.headers["X-Cache"] = cache_status
    return res


@router.get("/lyrics/{video_id}", response_model=Lyrics)
async def get_lyrics(
    video_id: str,
    response: Response,
    user: User = Depends(rate_limiter),
):
    validate_video_id(video_id)
    res, cache_status = await default_discovery_service.get_lyrics(video_id=video_id)
    response.headers["X-Cache"] = cache_status
    return res
