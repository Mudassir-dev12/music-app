import hashlib
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import rate_limiter
from app.services.tracks import upsert_tracks
from app.sources.models import SearchResponse
from app.sources.ytmusic import YTMusicSource

router = APIRouter(tags=["search"])
ytmusic_source = YTMusicSource()


@router.get("/search", response_model=SearchResponse)
async def search_music(
    q: str = Query(..., min_length=1, max_length=100),
    filter: str = Query("songs"),
    limit: int = Query(20, ge=1, le=50),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    trimmed_q = q.strip()
    if not trimmed_q or len(trimmed_q) > 100:
        raise HTTPException(
            status_code=422,
            detail="Query must be between 1 and 100 non-whitespace characters.",
        )

    if filter != "songs":
        raise HTTPException(
            status_code=422,
            detail=f"Filter '{filter}' is not supported in Phase 1 (only 'songs' is supported).",
        )

    cache = get_cache()
    hash_key = hashlib.sha1(f"{trimmed_q}|{filter}|{limit}".encode("utf-8")).hexdigest()
    cache_key = f"search:{hash_key}"

    cached = await cache.get(cache_key)
    if cached:
        search_res = SearchResponse(**cached) if isinstance(cached, dict) else cached
        await upsert_tracks(db, search_res.results)
        return search_res

    result = await ytmusic_source.search(
        query=trimmed_q,
        filter_type=filter,
        limit=limit,
    )

    await cache.set(cache_key, result.model_dump(), ttl=settings.SEARCH_TTL)
    await upsert_tracks(db, result.results)
    return result
