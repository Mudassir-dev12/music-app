import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models import PlayHistory, Track as TrackModel, User
from app.db.session import get_db_session
from app.pagination import decode_cursor, encode_cursor
from app.ratelimit import history_write_rate_limiter, rate_limiter
from app.schemas.user_data import HistoryCreate, HistoryItemOut, HistoryPageOut
from app.services.history import prune_user_history
from app.services.tracks import db_track_to_source_model, ensure_track_exists
from app.sources.models import Track as TrackSourceModel

router = APIRouter(prefix="/me", tags=["history"])


@router.post("/history", response_model=HistoryItemOut)
async def record_history(
    data: HistoryCreate,
    response: Response,
    user: User = Depends(history_write_rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    # 1. Idempotency check on client_event_id for this user
    existing_stmt = (
        select(PlayHistory, TrackModel)
        .join(TrackModel, PlayHistory.video_id == TrackModel.video_id)
        .where(
            PlayHistory.user_id == user.id,
            PlayHistory.client_event_id == data.client_event_id,
        )
    )
    existing_res = await db.execute(existing_stmt)
    existing_row = existing_res.first()
    if existing_row:
        hist, trk = existing_row
        response.status_code = status.HTTP_200_OK
        return HistoryItemOut(
            id=hist.id,
            played_at=hist.played_at,
            listened_seconds=hist.listened_seconds,
            track=db_track_to_source_model(trk),
        )

    # 2. Ensure track exists (resolves via source adapter if needed)
    track_model = await ensure_track_exists(db, data.video_id)

    # 3. Validate and clamp listened_seconds
    if data.listened_seconds > 86400:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="listened_seconds cannot exceed 86400.",
        )
    if track_model.duration_seconds and data.listened_seconds > track_model.duration_seconds + 30:
        actual_listened = track_model.duration_seconds
    else:
        actual_listened = data.listened_seconds

    # 4. Insert new record
    now = datetime.datetime.now(datetime.timezone.utc)
    new_hist = PlayHistory(
        user_id=user.id,
        video_id=data.video_id,
        listened_seconds=actual_listened,
        client_event_id=data.client_event_id,
        played_at=now,
    )
    db.add(new_hist)
    await db.commit()
    await db.refresh(new_hist)

    # 5. Opportunistic pruning
    await prune_user_history(db, user.id)

    response.status_code = status.HTTP_201_CREATED
    return HistoryItemOut(
        id=new_hist.id,
        played_at=new_hist.played_at,
        listened_seconds=new_hist.listened_seconds,
        track=db_track_to_source_model(track_model),
    )


@router.get("/history", response_model=HistoryPageOut)
async def get_history(
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = Query(None),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = (
        select(PlayHistory, TrackModel)
        .join(TrackModel, PlayHistory.video_id == TrackModel.video_id)
        .where(PlayHistory.user_id == user.id)
    )

    if cursor:
        cursor_data = decode_cursor(cursor)
        if not cursor_data or "played_at" not in cursor_data or "id" not in cursor_data:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid pagination cursor format.",
            )
        try:
            c_played_at = datetime.datetime.fromisoformat(cursor_data["played_at"])
            c_id = int(cursor_data["id"])
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid pagination cursor data.",
            ) from e

        stmt = stmt.where(
            (PlayHistory.played_at < c_played_at)
            | ((PlayHistory.played_at == c_played_at) & (PlayHistory.id < c_id))
        )

    stmt = stmt.order_by(PlayHistory.played_at.desc(), PlayHistory.id.desc()).limit(limit + 1)
    res = await db.execute(stmt)
    rows = res.all()

    items = []
    has_more = len(rows) > limit
    page_rows = rows[:limit]

    for hist, trk in page_rows:
        items.append(
            HistoryItemOut(
                id=hist.id,
                played_at=hist.played_at,
                listened_seconds=hist.listened_seconds,
                track=db_track_to_source_model(trk),
            )
        )

    next_cursor = None
    if has_more and page_rows:
        last_hist = page_rows[-1][0]
        next_cursor = encode_cursor(
            {
                "played_at": last_hist.played_at.isoformat(),
                "id": last_hist.id,
            }
        )

    return HistoryPageOut(items=items, next_cursor=next_cursor)


@router.get("/recent", response_model=List[TrackSourceModel])
async def get_recent_tracks(
    limit: int = Query(20, ge=1, le=50),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    subq = (
        select(
            PlayHistory.video_id,
            func.max(PlayHistory.played_at).label("max_played_at"),
        )
        .where(PlayHistory.user_id == user.id)
        .group_by(PlayHistory.video_id)
        .order_by(func.max(PlayHistory.played_at).desc())
        .limit(limit)
    ).subquery()

    stmt = (
        select(TrackModel)
        .join(subq, TrackModel.video_id == subq.c.video_id)
        .order_by(subq.c.max_played_at.desc())
    )
    res = await db.execute(stmt)
    return [db_track_to_source_model(t) for t in res.scalars().all()]


@router.delete("/history/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_history_item(
    id: int,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = (
        delete(PlayHistory)
        .where(
            PlayHistory.user_id == user.id,
            PlayHistory.id == id,
        )
        .execution_options(synchronize_session=False)
    )
    await db.execute(stmt)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/history", status_code=status.HTTP_204_NO_CONTENT)
async def clear_history(
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = (
        delete(PlayHistory)
        .where(PlayHistory.user_id == user.id)
        .execution_options(synchronize_session=False)
    )
    await db.execute(stmt)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
