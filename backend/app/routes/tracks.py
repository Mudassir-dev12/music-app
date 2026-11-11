import re
from fastapi import APIRouter, Depends, HTTPException, status
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import User
from app.ratelimit import rate_limiter
from app.routes.search import ytmusic_source
from app.sources.models import Track

router = APIRouter(prefix="/track", tags=["tracks"])
VIDEO_ID_REGEX = re.compile(r"^[A-Za-z0-9_-]{11}$")


def validate_video_id(video_id: str) -> None:
    if not VIDEO_ID_REGEX.match(video_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid video_id format. Expected 11 URL-safe characters.",
        )


@router.get("/{video_id:path}", response_model=Track)
async def get_track(
    video_id: str,
    user: User = Depends(rate_limiter),
):
    validate_video_id(video_id)

    cache = get_cache()
    cache_key = f"meta:{video_id}"

    cached = await cache.get(cache_key)
    if cached:
        if isinstance(cached, dict):
            return Track(**cached)
        return cached

    track = await ytmusic_source.get_track(video_id)
    await cache.set(cache_key, track.model_dump(), ttl=settings.META_TTL)
    return track
