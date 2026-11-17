import asyncio
from typing import Literal, Optional
from fastapi import APIRouter, Body, Depends, Header, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.tokens import create_audio_ticket
from app.config import settings
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import audio_rate_limiter, rate_limiter
from app.routes.search import ytmusic_source
from app.routes.tracks import validate_video_id
from app.services.audio_proxy import AudioProxy
from app.services.stream_resolver import StreamResolver, get_stream_resolver
from app.services.usage import bandwidth_guard

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


@router.post("/{video_id:path}/ticket", response_model=AudioTicketOut)
async def create_ticket(
    video_id: str,
    ticket_in: Optional[AudioTicketIn] = Body(None),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
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
