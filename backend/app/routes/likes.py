import datetime
import re
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models import LikedTrack, Track as TrackModel, User
from app.db.session import get_db_session
from app.pagination import decode_cursor, encode_cursor
from app.ratelimit import rate_limiter
from app.schemas.user_data import LikedIdsOut, LikedItemOut, LikedPageOut
from app.services.tracks import db_track_to_source_model, ensure_track_exists

router = APIRouter(prefix="/me/likes", tags=["likes"])
VIDEO_ID_REGEX = re.compile(r"^[A-Za-z0-9_-]{11}$")


def validate_vid(video_id: str) -> str:
    if not VIDEO_ID_REGEX.match(video_id):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid video_id format. Expected 11 URL-safe characters.",
        )
    return video_id


@router.get("/ids", response_model=LikedIdsOut)
async def get_liked_ids(
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = (
        select(LikedTrack.video_id)
        .where(LikedTrack.user_id == user.id)
        .order_by(LikedTrack.liked_at.desc())
        .limit(10000)
    )
    res = await db.execute(stmt)
    return LikedIdsOut(ids=list(res.scalars().all()))


@router.get("", response_model=LikedPageOut)
async def get_likes(
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = Query(None),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = (
        select(LikedTrack, TrackModel)
        .join(TrackModel, LikedTrack.video_id == TrackModel.video_id)
        .where(LikedTrack.user_id == user.id)
    )

    if cursor:
        cursor_data = decode_cursor(cursor)
        if not cursor_data or "liked_at" not in cursor_data or "video_id" not in cursor_data:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid pagination cursor format.",
            )
        try:
            c_liked_at = datetime.datetime.fromisoformat(cursor_data["liked_at"])
            c_vid = cursor_data["video_id"]
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid pagination cursor data.",
            ) from e

        stmt = stmt.where(
            (LikedTrack.liked_at < c_liked_at)
            | ((LikedTrack.liked_at == c_liked_at) & (LikedTrack.video_id < c_vid))
        )

    stmt = stmt.order_by(LikedTrack.liked_at.desc(), LikedTrack.video_id.desc()).limit(limit + 1)
    res = await db.execute(stmt)
    rows = res.all()

    items = []
    has_more = len(rows) > limit
    page_rows = rows[:limit]

    for liked, trk in page_rows:
        items.append(
            LikedItemOut(
                liked_at=liked.liked_at,
                track=db_track_to_source_model(trk),
            )
        )

    next_cursor = None
    if has_more and page_rows:
        last_liked = page_rows[-1][0]
        next_cursor = encode_cursor(
            {
                "liked_at": last_liked.liked_at.isoformat(),
                "video_id": last_liked.video_id,
            }
        )

    return LikedPageOut(items=items, next_cursor=next_cursor)


@router.put("/{video_id}", status_code=status.HTTP_204_NO_CONTENT)
async def like_track(
    video_id: str,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    validate_vid(video_id)

    # 1. Ensure track exists (fetches metadata via source or raises 502)
    await ensure_track_exists(db, video_id)

    # 2. Check if already liked
    existing_stmt = select(LikedTrack).where(
        LikedTrack.user_id == user.id,
        LikedTrack.video_id == video_id,
    )
    existing_res = await db.execute(existing_stmt)
    if not existing_res.scalar_one_or_none():
        now = datetime.datetime.now(datetime.timezone.utc)
        db.add(LikedTrack(user_id=user.id, video_id=video_id, liked_at=now))
        await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{video_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unlike_track(
    video_id: str,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    validate_vid(video_id)

    stmt = delete(LikedTrack).where(
        LikedTrack.user_id == user.id,
        LikedTrack.video_id == video_id,
    )
    await db.execute(stmt)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
