import datetime
from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.db.models import Playlist, PlaylistTrack, Track as TrackModel, User
from app.db.session import get_db_session
from app.pagination import decode_cursor, encode_cursor
from app.ratelimit import rate_limiter
from app.schemas.user_data import (
    PlaylistAddResult,
    PlaylistAddTracks,
    PlaylistCreate,
    PlaylistDetailOut,
    PlaylistOut,
    PlaylistReorder,
    PlaylistTrackItem,
    PlaylistTracksPage,
    PlaylistUpdate,
)
from app.services.tracks import db_track_to_source_model, ensure_track_exists

router = APIRouter(prefix="/playlists", tags=["playlists"])


async def get_cover_thumbnails(db: AsyncSession, playlist_id: str) -> List[str]:
    stmt = (
        select(TrackModel.thumbnail)
        .join(PlaylistTrack, PlaylistTrack.video_id == TrackModel.video_id)
        .where(PlaylistTrack.playlist_id == playlist_id)
        .order_by(PlaylistTrack.position.asc())
        .limit(4)
    )
    res = await db.execute(stmt)
    return [t for t in res.scalars().all() if t]


async def get_playlist_stats(db: AsyncSession, playlist_id: str) -> tuple[int, int]:
    stmt = (
        select(
            func.count(PlaylistTrack.video_id),
            func.coalesce(func.sum(TrackModel.duration_seconds), 0),
        )
        .join(TrackModel, PlaylistTrack.video_id == TrackModel.video_id)
        .where(PlaylistTrack.playlist_id == playlist_id)
    )
    res = await db.execute(stmt)
    count, duration = res.one()
    return count, duration


@router.get("", response_model=List[PlaylistOut])
async def list_playlists(
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = (
        select(Playlist)
        .where(Playlist.user_id == user.id)
        .order_by(Playlist.updated_at.desc(), Playlist.id.desc())
    )
    res = await db.execute(stmt)
    playlists = res.scalars().all()

    out = []
    for pl in playlists:
        thumbs = await get_cover_thumbnails(db, pl.id)
        count, duration = await get_playlist_stats(db, pl.id)
        out.append(
            PlaylistOut(
                id=pl.id,
                name=pl.name,
                description=pl.description,
                track_count=count,
                duration_seconds=duration,
                cover_thumbnails=thumbs,
                created_at=pl.created_at,
                updated_at=pl.updated_at,
            )
        )
    return out


@router.post("", response_model=PlaylistOut, status_code=status.HTTP_201_CREATED)
async def create_playlist(
    data: PlaylistCreate,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    count_stmt = select(func.count(Playlist.id)).where(Playlist.user_id == user.id)
    count = await db.scalar(count_stmt) or 0
    if count >= settings.MAX_PLAYLISTS_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Maximum playlist limit ({settings.MAX_PLAYLISTS_PER_USER}) reached.",
        )

    now = datetime.datetime.now(datetime.timezone.utc)
    new_pl = Playlist(
        id=str(uuid.uuid4()),
        user_id=user.id,
        name=data.name,
        description=data.description,
        created_at=now,
        updated_at=now,
    )
    db.add(new_pl)
    await db.commit()
    await db.refresh(new_pl)

    return PlaylistOut(
        id=new_pl.id,
        name=new_pl.name,
        description=new_pl.description,
        track_count=0,
        duration_seconds=0,
        cover_thumbnails=[],
        created_at=new_pl.created_at,
        updated_at=new_pl.updated_at,
    )


@router.get("/{id}", response_model=PlaylistDetailOut)
async def get_playlist(
    id: str,
    limit: int = Query(50, ge=1, le=100),
    cursor: Optional[str] = Query(None),
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = select(Playlist).where(Playlist.id == id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found.",
        )

    thumbs = await get_cover_thumbnails(db, pl.id)
    count, duration = await get_playlist_stats(db, pl.id)

    track_stmt = (
        select(PlaylistTrack, TrackModel)
        .join(TrackModel, PlaylistTrack.video_id == TrackModel.video_id)
        .where(PlaylistTrack.playlist_id == pl.id)
    )

    if cursor:
        cursor_data = decode_cursor(cursor)
        if not cursor_data or "position" not in cursor_data:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid pagination cursor format.",
            )
        try:
            c_pos = int(cursor_data["position"])
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid cursor position.",
            ) from e
        track_stmt = track_stmt.where(PlaylistTrack.position > c_pos)

    track_stmt = track_stmt.order_by(PlaylistTrack.position.asc()).limit(limit + 1)
    track_res = await db.execute(track_stmt)
    rows = track_res.all()

    items = []
    has_more = len(rows) > limit
    page_rows = rows[:limit]

    for pt, trk in page_rows:
        items.append(
            PlaylistTrackItem(
                position=pt.position,
                added_at=pt.added_at,
                track=db_track_to_source_model(trk),
            )
        )

    next_cursor = None
    if has_more and page_rows:
        last_pt = page_rows[-1][0]
        next_cursor = encode_cursor({"position": last_pt.position})

    return PlaylistDetailOut(
        id=pl.id,
        name=pl.name,
        description=pl.description,
        track_count=count,
        duration_seconds=duration,
        cover_thumbnails=thumbs,
        created_at=pl.created_at,
        updated_at=pl.updated_at,
        tracks=PlaylistTracksPage(items=items, next_cursor=next_cursor),
    )


@router.patch("/{id}", response_model=PlaylistOut)
async def update_playlist(
    id: str,
    data: PlaylistUpdate,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = select(Playlist).where(Playlist.id == id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found.",
        )

    if data.name is not None:
        pl.name = data.name
    if data.description is not None:
        pl.description = data.description

    pl.updated_at = datetime.datetime.now(datetime.timezone.utc)
    await db.commit()
    await db.refresh(pl)

    thumbs = await get_cover_thumbnails(db, pl.id)
    count, duration = await get_playlist_stats(db, pl.id)
    return PlaylistOut(
        id=pl.id,
        name=pl.name,
        description=pl.description,
        track_count=count,
        duration_seconds=duration,
        cover_thumbnails=thumbs,
        created_at=pl.created_at,
        updated_at=pl.updated_at,
    )


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_playlist(
    id: str,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = select(Playlist).where(Playlist.id == id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found.",
        )

    await db.delete(pl)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{id}/tracks", response_model=PlaylistAddResult)
async def add_tracks_to_playlist(
    id: str,
    data: PlaylistAddTracks,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = select(Playlist).where(Playlist.id == id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found.",
        )

    # 1. Fetch current tracks and max position
    current_res = await db.execute(
        select(PlaylistTrack.video_id, PlaylistTrack.position)
        .where(PlaylistTrack.playlist_id == id)
        .order_by(PlaylistTrack.position.asc())
    )
    current_rows = current_res.all()
    existing_vids = {r[0] for r in current_rows}
    current_max_pos = max([r[1] for r in current_rows], default=0)

    # 2. Separate duplicates vs to_add
    skipped = []
    to_add = []
    seen = set(existing_vids)
    for vid in data.video_ids:
        if vid in seen:
            skipped.append(vid)
        else:
            to_add.append(vid)
            seen.add(vid)

    # 3. Check track limit
    if len(existing_vids) + len(to_add) > settings.MAX_TRACKS_PER_PLAYLIST:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Playlist cannot exceed {settings.MAX_TRACKS_PER_PLAYLIST} tracks.",
        )

    # 4. Ensure each new track exists in tracks table
    for vid in to_add:
        await ensure_track_exists(db, vid)

    # 5. Insert new PlaylistTrack rows
    now = datetime.datetime.now(datetime.timezone.utc)
    for idx, vid in enumerate(to_add, start=1):
        db.add(
            PlaylistTrack(
                playlist_id=id,
                video_id=vid,
                position=current_max_pos + idx,
                added_at=now,
            )
        )
    pl.updated_at = now
    await db.commit()

    return PlaylistAddResult(added=len(to_add), skipped=skipped)


@router.delete("/{id}/tracks/{video_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_track_from_playlist(
    id: str,
    video_id: str,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = select(Playlist).where(Playlist.id == id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found.",
        )

    del_stmt = (
        delete(PlaylistTrack)
        .where(
            PlaylistTrack.playlist_id == id,
            PlaylistTrack.video_id == video_id,
        )
        .execution_options(synchronize_session=False)
    )
    await db.execute(del_stmt)
    await db.flush()

    # Renumber remaining tracks
    rem_res = await db.execute(
        select(PlaylistTrack)
        .where(PlaylistTrack.playlist_id == id)
        .order_by(PlaylistTrack.position.asc())
    )
    remaining = rem_res.scalars().all()
    # Temporary negative to avoid unique constraint collisions
    for idx, pt in enumerate(remaining, start=1):
        pt.position = -idx
    await db.flush()
    for idx, pt in enumerate(remaining, start=1):
        pt.position = idx
    await db.flush()

    now = datetime.datetime.now(datetime.timezone.utc)
    pl.updated_at = now
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put("/{id}/order", status_code=status.HTTP_204_NO_CONTENT)
async def reorder_playlist_tracks(
    id: str,
    data: PlaylistReorder,
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    stmt = select(Playlist).where(Playlist.id == id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found.",
        )

    pts_res = await db.execute(
        select(PlaylistTrack).where(PlaylistTrack.playlist_id == id)
    )
    pts = pts_res.scalars().all()
    current_vids = [pt.video_id for pt in pts]

    if (
        len(data.video_ids) != len(current_vids)
        or set(data.video_ids) != set(current_vids)
        or len(set(data.video_ids)) != len(data.video_ids)
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="video_ids must contain exactly the current set of tracks in the playlist.",
        )

    vid_to_pt = {pt.video_id: pt for pt in pts}
    # Pass 1: negative positions to avoid unique collision
    for idx, vid in enumerate(data.video_ids, start=1):
        vid_to_pt[vid].position = -idx
    await db.flush()

    # Pass 2: final positive positions
    for idx, vid in enumerate(data.video_ids, start=1):
        vid_to_pt[vid].position = idx
    await db.flush()

    now = datetime.datetime.now(datetime.timezone.utc)
    pl.updated_at = now
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
