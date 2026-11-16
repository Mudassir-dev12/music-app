import re
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import rate_limiter
from app.services.discovery_service import default_discovery_service
from app.sources.models import (
    ChartsResponse,
    HomeResponse,
    MoodPlaylistsResponse,
    MoodsResponse,
)

router = APIRouter(prefix="/discover", tags=["discover"])

REGION_REGEX = re.compile(r"^[A-Z]{2}$")
PARAMS_REGEX = re.compile(r"^[A-Za-z0-9_-]{1,100}$")


@router.get("/home", response_model=HomeResponse)
async def get_home_feed(
    response: Response,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    res, cache_status = await default_discovery_service.get_home(db)
    response.headers["X-Cache"] = cache_status
    return res


@router.get("/charts", response_model=ChartsResponse)
async def get_charts(
    response: Response,
    region: Optional[str] = Query(None),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    target_region = (region or settings.YTMUSIC_LOCATION).upper()
    if not REGION_REGEX.match(target_region):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid region code. Expected two uppercase letters (e.g. 'US', 'PK').",
        )

    res, cache_status = await default_discovery_service.get_charts(db, region=target_region)
    response.headers["X-Cache"] = cache_status
    return res


@router.get("/moods", response_model=MoodsResponse)
async def get_moods(
    response: Response,
    user: User = Depends(rate_limiter),
):
    res, cache_status = await default_discovery_service.get_moods()
    response.headers["X-Cache"] = cache_status
    return res


@router.get("/moods/{params}/playlists", response_model=MoodPlaylistsResponse)
async def get_mood_playlists(
    params: str,
    response: Response,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    if not PARAMS_REGEX.match(params):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid mood params identifier.",
        )

    res, cache_status = await default_discovery_service.get_mood_playlists(db, params=params)
    response.headers["X-Cache"] = cache_status
    return res
