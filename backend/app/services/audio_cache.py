import asyncio
import logging
import os
from pathlib import Path
from typing import AsyncGenerator, Optional
from app.config import settings

logger = logging.getLogger("music_app.audio_cache")


class AudioCacheManager:
    def __init__(self, cache_dir: Optional[str] = None, max_gb: Optional[int] = None):
        self.cache_dir = Path(cache_dir or settings.AUDIO_CACHE_DIR)
        self.max_bytes = (max_gb or settings.AUDIO_CACHE_MAX_GB) * 1024 * 1024 * 1024
        self._ensure_dir()

    def _ensure_dir(self) -> None:
        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            logger.error(f"Failed to create audio cache directory {self.cache_dir}: {e}")

    def _safe_name(self, video_id: str) -> str:
        # Allow alphanumeric, dashes, and underscores only
        return "".join(c for c in video_id if c.isalnum() or c in ("-", "_"))

    def get_file_path(self, video_id: str) -> Path:
        return self.cache_dir / f"{self._safe_name(video_id)}.m4a"

    def get_part_path(self, video_id: str) -> Path:
        return self.cache_dir / f"{self._safe_name(video_id)}.part"

    def is_cached(self, video_id: str) -> bool:
        path = self.get_file_path(video_id)
        try:
            return path.is_file() and path.stat().st_size > 0
        except OSError:
            return False

    def get_size(self, video_id: str) -> int:
        try:
            return self.get_file_path(video_id).stat().st_size
        except OSError:
            return 0

    def touch(self, video_id: str) -> None:
        try:
            path = self.get_file_path(video_id)
            if path.is_file():
                os.utime(path, None)
        except OSError:
            pass

    async def read_range(
        self,
        video_id: str,
        start: int = 0,
        length: Optional[int] = None,
        chunk_size: int = 65536,
    ) -> AsyncGenerator[bytes, None]:
        path = self.get_file_path(video_id)
        self.touch(video_id)
        bytes_to_read = length

        def _sync_read(f, amount):
            return f.read(amount)

        with open(path, mode="rb") as f:
            if start > 0:
                f.seek(start)
            while True:
                if bytes_to_read is not None and bytes_to_read <= 0:
                    break
                read_amount = (
                    min(chunk_size, bytes_to_read)
                    if bytes_to_read is not None
                    else chunk_size
                )
                chunk = await asyncio.to_thread(_sync_read, f, read_amount)
                if not chunk:
                    break
                if bytes_to_read is not None:
                    bytes_to_read -= len(chunk)
                yield chunk

    def prune_if_needed(self) -> None:
        try:
            files = list(self.cache_dir.glob("*.m4a")) + list(self.cache_dir.glob("*.part"))
            total_size = sum(f.stat().st_size for f in files if f.is_file())
            if total_size <= self.max_bytes:
                return

            target_size = int(self.max_bytes * 0.8)
            # Sort files by last access time (oldest first)
            files.sort(key=lambda f: f.stat().st_atime if f.is_file() else 0)

            for f in files:
                if total_size <= target_size:
                    break
                try:
                    size = f.stat().st_size
                    f.unlink()
                    total_size -= size
                    logger.info(f"Evicted cached audio {f.name} ({size} bytes)")
                except OSError:
                    pass
        except Exception as e:
            logger.warning(f"Error during audio cache pruning: {e}")


audio_cache = AudioCacheManager()
