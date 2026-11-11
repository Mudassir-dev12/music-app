from fastapi import APIRouter, Depends, Header, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.tokens import create_audio_ticket
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import audio_rate_limiter, rate_limiter
from app.routes.search import ytmusic_source
from app.routes.tracks import validate_video_id
from app.services.audio_proxy import AudioProxy
from app.services.stream_resolver import StreamResolver

router = APIRouter(prefix="/audio", tags=["audio"])

stream_resolver = StreamResolver(ytmusic_source)
audio_proxy = AudioProxy(stream_resolver)


class AudioTicketOut(BaseModel):
    url: str
    expires_in: int


@router.post("/{video_id:path}/ticket", response_model=AudioTicketOut)
async def create_ticket(
    video_id: str,
    user: User = Depends(rate_limiter),
):
    validate_video_id(video_id)
    ticket, expires_in = create_audio_ticket(user.id, video_id)
    return AudioTicketOut(
        url=f"/audio/{video_id}?t={ticket}",
        expires_in=expires_in,
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
    return await audio_proxy.proxy_stream(
        video_id=video_id,
        user_id=user.id,
        db=db,
        range_header=range,
    )
