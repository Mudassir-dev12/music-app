import asyncio
from collections import defaultdict
import datetime
import logging
from typing import Tuple
from fastapi import HTTPException, status
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.db.models import AudioUsage, DownloadUsage
from app.db.session import get_sessionmaker

logger = logging.getLogger("music_app.usage")


class BandwidthGuard:
    def __init__(self):
        self._unflushed: dict[Tuple[str, datetime.date], int] = defaultdict(int)
        self._unflushed_downloads: dict[Tuple[str, datetime.date], int] = defaultdict(int)
        self._prefetch_daily_bytes: dict[datetime.date, int] = defaultdict(int)
        self._lock = asyncio.Lock()
        self._warned_80_percent: bool = False
        self._flush_task: asyncio.Task | None = None
        self._running: bool = False

    def start_background_flusher(self) -> None:
        if not self._running:
            self._running = True
            self._flush_task = asyncio.create_task(self._periodic_flush())

    async def stop(self) -> None:
        self._running = False
        if self._flush_task:
            self._flush_task.cancel()
            try:
                await self._flush_task
            except asyncio.CancelledError:
                pass
        await self.flush()

    async def record_bytes(self, user_id: str, byte_count: int) -> None:
        if byte_count <= 0:
            return
        today = datetime.datetime.now(datetime.timezone.utc).date()
        async with self._lock:
            self._unflushed[(user_id, today)] += byte_count

    async def record_download_bytes(self, user_id: str, byte_count: int) -> None:
        if byte_count <= 0:
            return
        today = datetime.datetime.now(datetime.timezone.utc).date()
        async with self._lock:
            self._unflushed_downloads[(user_id, today)] += byte_count

    async def record_prefetch_bytes(self, byte_count: int) -> None:
        if byte_count <= 0:
            return
        today = datetime.datetime.now(datetime.timezone.utc).date()
        async with self._lock:
            self._prefetch_daily_bytes[today] += byte_count

    async def get_prefetch_today_bytes(self) -> int:
        today = datetime.datetime.now(datetime.timezone.utc).date()
        async with self._lock:
            return self._prefetch_daily_bytes.get(today, 0)

    async def is_prefetch_daily_budget_exceeded(self) -> bool:
        limit = settings.PREFETCH_GLOBAL_MB_PER_DAY * 1024 * 1024
        today_bytes = await self.get_prefetch_today_bytes()
        return today_bytes >= limit

    async def flush(self) -> None:
        async with self._lock:
            if not self._unflushed and not self._unflushed_downloads:
                return
            to_flush = dict(self._unflushed)
            self._unflushed.clear()
            to_flush_downloads = dict(self._unflushed_downloads)
            self._unflushed_downloads.clear()

        try:
            sm = get_sessionmaker()
            async with sm() as session:
                for (user_id, day), byte_count in to_flush.items():
                    stmt = text(
                        """
                        INSERT INTO audio_usage (user_id, day, bytes)
                        VALUES (:user_id, :day, :bytes)
                        ON CONFLICT (user_id, day) DO UPDATE SET bytes = audio_usage.bytes + EXCLUDED.bytes;
                        """
                    )
                    await session.execute(
                        stmt, {"user_id": user_id, "day": day, "bytes": byte_count}
                    )
                for (user_id, day), byte_count in to_flush_downloads.items():
                    stmt = text(
                        """
                        INSERT INTO download_usage (user_id, day, bytes)
                        VALUES (:user_id, :day, :bytes)
                        ON CONFLICT (user_id, day) DO UPDATE SET bytes = download_usage.bytes + EXCLUDED.bytes;
                        """
                    )
                    await session.execute(
                        stmt, {"user_id": user_id, "day": day, "bytes": byte_count}
                    )
                await session.commit()
        except Exception as e:
            logger.error(f"Failed to flush audio usage counters to database: {e}")
            # Restore unflushed items on failure so we don't lose them
            async with self._lock:
                for k, v in to_flush.items():
                    self._unflushed[k] += v
                for k, v in to_flush_downloads.items():
                    self._unflushed_downloads[k] += v

    async def _periodic_flush(self) -> None:
        while self._running:
            try:
                await asyncio.sleep(15)
                await self.flush()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in periodic usage flush: {e}")

    async def get_user_today_bytes(self, user_id: str, db: AsyncSession) -> int:
        today = datetime.datetime.now(datetime.timezone.utc).date()
        res = await db.execute(
            select(AudioUsage.bytes).where(
                AudioUsage.user_id == user_id, AudioUsage.day == today
            )
        )
        db_bytes = res.scalar() or 0
        async with self._lock:
            unflushed = self._unflushed.get((user_id, today), 0)
        return db_bytes + unflushed

    async def get_month_global_bytes(self, db: AsyncSession) -> int:
        today = datetime.datetime.now(datetime.timezone.utc).date()
        first_of_month = today.replace(day=1)
        res = await db.execute(
            select(func.sum(AudioUsage.bytes)).where(AudioUsage.day >= first_of_month)
        )
        db_sum = res.scalar() or 0

        async with self._lock:
            unflushed_sum = sum(
                v for (u, d), v in self._unflushed.items() if d >= first_of_month
            )
        return int(db_sum) + unflushed_sum

    async def check_limits(self, user_id: str, db: AsyncSession) -> None:
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        today = now_utc.date()

        # Check Daily User Limit
        if settings.DAILY_AUDIO_MB_PER_USER > 0:
            daily_limit_bytes = settings.DAILY_AUDIO_MB_PER_USER * 1024 * 1024
            user_today = await self.get_user_today_bytes(user_id, db)
            if user_today >= daily_limit_bytes:
                tomorrow_utc = (now_utc + datetime.timedelta(days=1)).replace(
                    hour=0, minute=0, second=0, microsecond=0
                )
                retry_after = max(1, int((tomorrow_utc - now_utc).total_seconds()))
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Daily audio streaming bandwidth limit reached.",
                    headers={"Retry-After": str(retry_after)},
                )

        # Check Monthly Global Limit
        if settings.MONTHLY_AUDIO_GB_GLOBAL > 0:
            monthly_limit_bytes = (
                settings.MONTHLY_AUDIO_GB_GLOBAL * 1024 * 1024 * 1024
            )
            global_month = await self.get_month_global_bytes(db)

            # Warning at 80%
            if (
                not self._warned_80_percent
                and global_month >= int(monthly_limit_bytes * 0.8)
            ):
                logger.warning(
                    f"Global monthly bandwidth usage has exceeded 80% of limit "
                    f"({global_month} / {monthly_limit_bytes} bytes)."
                )
                self._warned_80_percent = True

            if global_month >= monthly_limit_bytes:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Monthly global audio bandwidth capacity reached.",
                    headers={"Retry-After": "3600"},
                )

    async def get_user_today_download_bytes(self, user_id: str, db: AsyncSession) -> int:
        today = datetime.datetime.now(datetime.timezone.utc).date()
        res = await db.execute(
            select(DownloadUsage.bytes).where(
                DownloadUsage.user_id == user_id, DownloadUsage.day == today
            )
        )
        db_bytes = res.scalar() or 0
        async with self._lock:
            unflushed = self._unflushed_downloads.get((user_id, today), 0)
        return db_bytes + unflushed

    async def check_download_limits(self, user_id: str, db: AsyncSession) -> None:
        # 1. Overall audio limits (daily streaming + monthly global)
        await self.check_limits(user_id, db)

        # 2. Daily Download Limit
        if settings.DAILY_DOWNLOAD_MB_PER_USER > 0:
            daily_limit_bytes = settings.DAILY_DOWNLOAD_MB_PER_USER * 1024 * 1024
            user_today = await self.get_user_today_download_bytes(user_id, db)
            if user_today >= daily_limit_bytes:
                now_utc = datetime.datetime.now(datetime.timezone.utc)
                tomorrow_utc = (now_utc + datetime.timedelta(days=1)).replace(
                    hour=0, minute=0, second=0, microsecond=0
                )
                retry_after = max(1, int((tomorrow_utc - now_utc).total_seconds()))
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Daily download bandwidth quota reached.",
                    headers={"Retry-After": str(retry_after)},
                )


bandwidth_guard = BandwidthGuard()
