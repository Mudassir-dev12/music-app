import asyncio
import hashlib
from typing import Optional, Union
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import rate_limiter
from app.services.discovery_service import default_discovery_service
from app.services.stream_resolver import get_stream_resolver
from app.services.tracks import upsert_tracks
from app.sources.models import (
    SearchFilterResponse,
    SearchGroupedResponse,
    SearchResponse,
    SearchSuggestionsResponse,
)
from app.sources.ytmusic import YTMusicSource

router = APIRouter(tags=["search"])
ytmusic_source = YTMusicSource()


@router.get(
    "/search",
    response_model=Union[SearchResponse, SearchFilterResponse, SearchGroupedResponse],
)
async def search_music(
    response: Response,
    q: str = Query(..., min_length=1, max_length=100),
    filter: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=50),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    trimmed_q = q.strip()
    if not trimmed_q or len(trimmed_q) > 100:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Query must be between 1 and 100 non-whitespace characters.",
        )

    # 1. Filter = songs -> Phase 1/2 SearchResponse
    if filter == "songs":
        cache = get_cache()
        hash_key = hashlib.sha1(f"{trimmed_q}|{filter}|{limit}".encode("utf-8")).hexdigest()
        cache_key = f"search:{hash_key}"

        cached = await cache.get(cache_key)
        if cached:
            response.headers["X-Cache"] = "hit"
            search_res = SearchResponse(**cached) if isinstance(cached, dict) else cached
            await upsert_tracks(db, search_res.results)
            return search_res

        try:
            result = await ytmusic_source.search(
                query=trimmed_q,
                filter_type=filter,
                limit=limit,
            )
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Upstream music service error. Please try again.",
            ) from e
        response.headers["X-Cache"] = "miss"
        await cache.set(cache_key, result.model_dump(), ttl=settings.SEARCH_TTL)
        await upsert_tracks(db, result.results)

        # Pre-warm top 2 tracks in background for instant playback when clicked
        resolver = get_stream_resolver()
        for t in result.results[:2]:
            if getattr(t, "videoId", None):
                asyncio.create_task(resolver.get_stream(t.videoId))

        return result

    # 2. Filter in albums, artists, playlists
    elif filter in ("albums", "artists", "playlists"):
        res, cache_status = await default_discovery_service.search_filter(
            db=db,
            query=trimmed_q,
            filter_type=filter,
            limit=limit,
        )
        response.headers["X-Cache"] = cache_status

        # Pre-warm top 2 tracks from grouped songs in background
        if hasattr(res, "songs") and res.songs:
            resolver = get_stream_resolver()
            for t in res.songs[:2]:
                if getattr(t, "videoId", None):
                    asyncio.create_task(resolver.get_stream(t.videoId))

        return res

    # 3. No filter or empty filter -> Grouped search
    elif filter is None or filter == "":
        res, cache_status = await default_discovery_service.search_grouped(
            db=db,
            query=trimmed_q,
        )
        response.headers["X-Cache"] = cache_status

        # Pre-warm top 2 tracks from grouped songs in background
        if hasattr(res, "songs") and res.songs:
            resolver = get_stream_resolver()
            for t in res.songs[:2]:
                if getattr(t, "videoId", None):
                    asyncio.create_task(resolver.get_stream(t.videoId))

        return res

    # 4. Unknown filter
    else:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Filter '{filter}' is invalid. Allowed: 'songs', 'albums', 'artists', 'playlists'.",
        )


@router.get("/search/suggestions", response_model=SearchSuggestionsResponse)
async def get_search_suggestions(
    response: Response,
    q: str = Query(..., min_length=1, max_length=100),
    user: User = Depends(rate_limiter),
):
    trimmed_q = q.strip()
    if not trimmed_q or len(trimmed_q) > 100:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Query must be between 1 and 100 non-whitespace characters.",
        )

    res, cache_status = await default_discovery_service.get_suggestions(trimmed_q)
    response.headers["X-Cache"] = cache_status
    return res
