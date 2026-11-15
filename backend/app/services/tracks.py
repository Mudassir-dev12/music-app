import datetime
import json
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models import Track as TrackModel
from app.sources.models import Artist, Track as TrackSourceModel
from app.sources.ytmusic import YTMusicSource


def db_track_to_source_model(db_track: TrackModel) -> TrackSourceModel:
    artists_raw = json.loads(db_track.artists_json) if db_track.artists_json else []
    return TrackSourceModel(
        video_id=db_track.video_id,
        title=db_track.title,
        artists=[Artist(**a) for a in artists_raw],
        artist=db_track.artist,
        album=db_track.album,
        album_id=db_track.album_id,
        duration_seconds=db_track.duration_seconds,
        thumbnail=db_track.thumbnail,
        is_explicit=db_track.is_explicit,
    )


async def upsert_track(db: AsyncSession, track: TrackSourceModel) -> TrackModel:
    now = datetime.datetime.now(datetime.timezone.utc)
    artists_json = json.dumps([a.model_dump() for a in track.artists])
    stmt = sqlite_insert(TrackModel).values(
        video_id=track.video_id,
        title=track.title,
        artist=track.artist,
        artists_json=artists_json,
        album=track.album,
        album_id=track.album_id,
        duration_seconds=track.duration_seconds,
        thumbnail=track.thumbnail,
        is_explicit=track.is_explicit,
        updated_at=now,
    ).on_conflict_do_update(
        index_elements=["video_id"],
        set_={
            "title": track.title,
            "artist": track.artist,
            "artists_json": artists_json,
            "album": track.album,
            "album_id": track.album_id,
            "duration_seconds": track.duration_seconds,
            "thumbnail": track.thumbnail,
            "is_explicit": track.is_explicit,
            "updated_at": now,
        },
    )
    await db.execute(stmt)
    await db.commit()
    res = await db.execute(select(TrackModel).where(TrackModel.video_id == track.video_id))
    return res.scalar_one()


async def upsert_tracks(db: AsyncSession, tracks: List[TrackSourceModel]) -> None:
    if not tracks:
        return
    now = datetime.datetime.now(datetime.timezone.utc)
    for track in tracks:
        artists_json = json.dumps([a.model_dump() for a in track.artists])
        stmt = sqlite_insert(TrackModel).values(
            video_id=track.video_id,
            title=track.title,
            artist=track.artist,
            artists_json=artists_json,
            album=track.album,
            album_id=track.album_id,
            duration_seconds=track.duration_seconds,
            thumbnail=track.thumbnail,
            is_explicit=track.is_explicit,
            updated_at=now,
        ).on_conflict_do_update(
            index_elements=["video_id"],
            set_={
                "title": track.title,
                "artist": track.artist,
                "artists_json": artists_json,
                "album": track.album,
                "album_id": track.album_id,
                "duration_seconds": track.duration_seconds,
                "thumbnail": track.thumbnail,
                "is_explicit": track.is_explicit,
                "updated_at": now,
            },
        )
        await db.execute(stmt)
    await db.commit()


async def ensure_track_exists(
    db: AsyncSession,
    video_id: str,
    source: YTMusicSource,
) -> TrackModel:
    res = await db.execute(select(TrackModel).where(TrackModel.video_id == video_id))
    existing = res.scalar_one_or_none()
    if existing:
        return existing

    try:
        source_track = await source.get_track(video_id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Upstream track lookup failed. Please try again.",
        ) from e

    return await upsert_track(db, source_track)
