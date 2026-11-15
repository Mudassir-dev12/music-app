import datetime
import time
from typing import Dict
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.db.models import PlayHistory

_last_prune: Dict[str, float] = {}


def reset_prune_cache() -> None:
    _last_prune.clear()


async def prune_user_history(
    db: AsyncSession,
    user_id: str,
    force: bool = False,
) -> None:
    now_ts = time.time()
    if not force:
        last = _last_prune.get(user_id, 0)
        if now_ts - last < 3600:
            return

    _last_prune[user_id] = now_ts

    # 1. Age retention cutoff (naive UTC to match SQLite storage)
    if settings.HISTORY_RETENTION_DAYS > 0:
        cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(
            days=settings.HISTORY_RETENTION_DAYS
        )
        stmt_age = (
            delete(PlayHistory)
            .where(
                PlayHistory.user_id == user_id,
                PlayHistory.played_at < cutoff,
            )
            .execution_options(synchronize_session=False)
        )
        await db.execute(stmt_age)

    # 2. Count limit
    if settings.HISTORY_MAX_ITEMS_PER_USER > 0:
        subq = (
            select(PlayHistory.id)
            .where(PlayHistory.user_id == user_id)
            .order_by(PlayHistory.played_at.desc(), PlayHistory.id.desc())
            .limit(settings.HISTORY_MAX_ITEMS_PER_USER)
        ).scalar_subquery()

        stmt_count = (
            delete(PlayHistory)
            .where(
                PlayHistory.user_id == user_id,
                PlayHistory.id.not_in(subq),
            )
            .execution_options(synchronize_session=False)
        )
        await db.execute(stmt_count)

    await db.commit()
