import asyncio
import logging
import time
from typing import Dict, List, Literal, Optional
from fastapi import APIRouter, Body, Depends, Header, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.tokens import create_audio_ticket
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import audio_rate_limiter, rate_limiter
from app.routes.tracks import validate_video_id
from app.services.audio_proxy import AudioProxy
from app.services.head_cache import head_cache
from app.services.stream_resolver import StreamResolver, get_stream_resolver
from app.services.usage import bandwidth_guard

logger = logging.getLogger("music_app.audio_routes")

router = APIRouter(prefix="/audio", tags=["audio"])

stream_resolver = get_stream_resolver()
audio_proxy = AudioProxy(stream_resolver)


class AudioTicketIn(BaseModel):
    purpose: Literal["stream", "download"] = "stream"


class AudioTicketOut(BaseModel):
    url: str
    expires_in: int
    purpose: str = "stream"
    remaining_download_mb: Optional[int] = None
    max_track_mb: Optional[int] = None


class AudioBatchTicketIn(BaseModel):
    video_ids: List[str]
    purpose: Literal["stream", "download"] = "stream"


class AudioPrefetchIn(BaseModel):
    video_ids: List[str]
    head: bool = True


async def _execute_prefetch_background(user_id: str, video_ids: List[str], fetch_head: bool) -> None:
    for vid in video_ids:
        # Respect global daily prefetch budget
        if await bandwidth_guard.is_prefetch_daily_budget_exceeded():
            logger.info("Global prefetch daily budget reached. Halting background prefetch.")
            break

        # Respect server concurrency
        if audio_proxy._semaphore.locked() or audio_proxy._semaphore._value < (settings.MAX_CONCURRENT_STREAMS * 0.2):
            logger.info("Server busy. Halting background prefetch.")
            break

        try:
            # 1. Resolve stream URL
            stream_info = await stream_resolver.get_stream(vid, is_prefetch=True)

            # 2. Optionally fetch and store head bytes
            if fetch_head and not head_cache.has(vid):
                head_range = f"bytes=0-{settings.HEAD_BYTES - 1}"
                resp = await audio_proxy._fetch_upstream(
                    audio_proxy._client, stream_info, head_range, method="GET"
                )
                if resp.status_code in (200, 206):
                    head_data = await resp.aread()
                    total_size = None
                    if "content-range" in resp.headers:
                        try:
                            total_size = int(resp.headers["content-range"].split("/")[-1])
                        except Exception:
                            pass
                    elif "content-length" in resp.headers:
                        try:
                            total_size = int(resp.headers["content-length"])
                        except Exception:
                            pass

                    if total_size and total_size > 1024 and len(head_data) > 0:
                        content_type = resp.headers.get("content-type", "audio/mp4")
                        etag = resp.headers.get("etag")
                        head_cache.put(
                            video_id=vid,
                            head_bytes=head_data,
                            total_size=total_size,
                            content_type=content_type,
                            etag=etag,
                        )
                        await bandwidth_guard.record_prefetch_bytes(len(head_data))
                await resp.aclose()
        except Exception as e:
            logger.debug(f"Background prefetch failed for {vid}: {e}")


@router.post("/tickets")
async def create_batch_tickets(
    batch_in: AudioBatchTicketIn,
    response: Response,
    user: User = Depends(rate_limiter),
):
    t0 = time.monotonic()
    if not (1 <= len(batch_in.video_ids) <= 10):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="video_ids must contain between 1 and 10 items.",
        )

    for vid in batch_in.video_ids:
        validate_video_id(vid)

    result = {}
    for vid in batch_in.video_ids:
        ticket, expires_in = create_audio_ticket(user.id, vid, purpose=batch_in.purpose)
        result[vid] = {
            "ticket": ticket,
            "expires_in": expires_in,
            "url": f"/audio/{vid}?t={ticket}",
        }

    dur = (time.monotonic() - t0) * 1000
    response.headers["Server-Timing"] = f"ticket;dur={dur:.1f}"
    return result


@router.post("/prefetch", status_code=status.HTTP_202_ACCEPTED)
async def prefetch_audio(
    prefetch_in: AudioPrefetchIn,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    if not (1 <= len(prefetch_in.video_ids) <= 5):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="video_ids must contain between 1 and 5 items.",
        )

    # 1. Per-user prefetch rate limit
    cache = get_cache()
    current_minute = int(time.time() // 60)
    rate_key = f"prefetch:rate:{user.id}:{current_minute}"
    count = await cache.incr(rate_key, ttl=60)
    if count > settings.PREFETCH_MAX_PER_MIN:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Prefetch rate limit reached. Please try again shortly.",
            headers={"Retry-After": "60"},
        )

    # 2. Check if user's streaming quota is exhausted
    if settings.DAILY_AUDIO_MB_PER_USER > 0:
        daily_limit = settings.DAILY_AUDIO_MB_PER_USER * 1024 * 1024
        user_today = await bandwidth_guard.get_user_today_bytes(user.id, db)
        if user_today >= daily_limit:
            return JSONResponse(
                status_code=status.HTTP_202_ACCEPTED,
                content={"statuses": {vid: "skipped" for vid in prefetch_in.video_ids}},
            )

    # 3. Check if server is busy or global prefetch budget reached
    server_busy = (
        audio_proxy._semaphore.locked()
        or audio_proxy._semaphore._value < (settings.MAX_CONCURRENT_STREAMS * 0.2)
        or await bandwidth_guard.is_prefetch_daily_budget_exceeded()
    )
    if server_busy:
        return JSONResponse(
            status_code=status.HTTP_202_ACCEPTED,
            content={"statuses": {vid: "skipped" for vid in prefetch_in.video_ids}},
        )

    # 4. Classify statuses
    statuses: Dict[str, str] = {}
    queued_ids: List[str] = []

    for vid in prefetch_in.video_ids:
        try:
            validate_video_id(vid)
        except HTTPException:
            statuses[vid] = "invalid"
            continue

        is_warm = await stream_resolver.is_warm(vid)
        has_head = head_cache.has(vid) if prefetch_in.head else True

        if is_warm and has_head:
            statuses[vid] = "warm"
        else:
            statuses[vid] = "queued"
            queued_ids.append(vid)

    # 5. Launch background resolution for queued items
    if queued_ids:
        asyncio.create_task(_execute_prefetch_background(user.id, queued_ids, prefetch_in.head))

    return JSONResponse(
        status_code=status.HTTP_202_ACCEPTED,
        content={"statuses": statuses},
    )


@router.post("/{video_id:path}/ticket", response_model=AudioTicketOut)
async def create_ticket(
    video_id: str,
    response: Response,
    ticket_in: Optional[AudioTicketIn] = Body(None),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    t0 = time.monotonic()
    validate_video_id(video_id)
    purpose = ticket_in.purpose if ticket_in else "stream"
    # Pre-resolve stream in the background immediately so it is ready before GET arrives
    asyncio.create_task(stream_resolver.get_stream(video_id))
    ticket, expires_in = create_audio_ticket(user.id, video_id, purpose=purpose)

    remaining_download_mb: Optional[int] = None
    max_track_mb: Optional[int] = None
    if purpose == "download":
        limit_bytes = settings.DAILY_DOWNLOAD_MB_PER_USER * 1024 * 1024
        used_bytes = await bandwidth_guard.get_user_today_download_bytes(user.id, db)
        remaining_bytes = max(0, limit_bytes - used_bytes)
        remaining_download_mb = remaining_bytes // (1024 * 1024)
        max_track_mb = settings.MAX_DOWNLOAD_TRACK_MB

    dur = (time.monotonic() - t0) * 1000
    response.headers["Server-Timing"] = f"ticket;dur={dur:.1f}"

    return AudioTicketOut(
        url=f"/audio/{video_id}?t={ticket}",
        expires_in=expires_in,
        purpose=purpose,
        remaining_download_mb=remaining_download_mb,
        max_track_mb=max_track_mb,
    )


@router.head("/{video_id:path}")
async def head_audio(
    video_id: str,
    range: str | None = Header(None),
    user: User = Depends(audio_rate_limiter),
):
    validate_video_id(video_id)
    return await audio_proxy.handle_head(video_id, range_header=range)


@router.get("/{video_id:path}")
async def get_audio(
    video_id: str,
    request: Request,
    range: str | None = Header(None),
    user: User = Depends(audio_rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    validate_video_id(video_id)
    purpose = getattr(request.state, "ticket_purpose", "stream")
    return await audio_proxy.proxy_stream(
        video_id=video_id,
        user_id=user.id,
        db=db,
        range_header=range,
        purpose=purpose,
    )
