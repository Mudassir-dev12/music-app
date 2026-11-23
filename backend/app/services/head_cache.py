from collections import OrderedDict
from dataclasses import dataclass, field
import logging
import threading
import time
from typing import Optional
from app.config import settings

logger = logging.getLogger("music_app.head_cache")


@dataclass
class HeadCacheEntry:
    video_id: str
    head_bytes: bytes
    total_size: int
    content_type: str
    etag: Optional[str] = None
    format_id: Optional[str] = None
    created_at: float = field(default_factory=time.time)
    last_accessed: float = field(default_factory=time.time)

    @property
    def size_bytes(self) -> int:
        return len(self.head_bytes)


class AudioHeadCache:
    """In-memory LRU cache storing the initial chunk (head) of audio tracks.

    Provides instant first bytes for playback without waiting for upstream CDN connection.
    Entries are validated against upstream metadata (total_size / etag) and discarded on mismatch.
    """

    def __init__(
        self,
        max_mb: Optional[int] = None,
        head_bytes: Optional[int] = None,
        ttl_seconds: Optional[int] = None,
    ):
        self._max_mb = max_mb or settings.HEAD_CACHE_MB
        self._max_bytes = self._max_mb * 1024 * 1024
        self._head_bytes = head_bytes or settings.HEAD_BYTES
        self._ttl_seconds = ttl_seconds or settings.HEAD_CACHE_TTL_SECONDS

        self._entries: OrderedDict[str, HeadCacheEntry] = OrderedDict()
        self._current_bytes: int = 0
        self._lock = threading.Lock()

    def get(self, video_id: str) -> Optional[HeadCacheEntry]:
        with self._lock:
            entry = self._entries.get(video_id)
            if entry is None:
                return None

            now = time.time()
            if now - entry.created_at > self._ttl_seconds:
                # Expired
                self._remove_entry(video_id)
                return None

            # Mark recently used
            entry.last_accessed = now
            self._entries.move_to_end(video_id)
            return entry

    def put(
        self,
        video_id: str,
        head_bytes: bytes,
        total_size: int,
        content_type: str = "audio/mp4",
        etag: Optional[str] = None,
        format_id: Optional[str] = None,
    ) -> HeadCacheEntry:
        sliced = head_bytes[: self._head_bytes]
        now = time.time()
        entry = HeadCacheEntry(
            video_id=video_id,
            head_bytes=sliced,
            total_size=total_size,
            content_type=content_type,
            etag=etag,
            format_id=format_id,
            created_at=now,
            last_accessed=now,
        )

        with self._lock:
            # If already exists, subtract old size
            if video_id in self._entries:
                self._current_bytes -= self._entries[video_id].size_bytes
                del self._entries[video_id]

            # Evict LRU entries if capacity exceeded
            entry_size = entry.size_bytes
            while self._current_bytes + entry_size > self._max_bytes and self._entries:
                oldest_id, oldest_entry = self._entries.popitem(last=False)
                self._current_bytes -= oldest_entry.size_bytes
                logger.debug(f"Evicted head cache entry {oldest_id} (freed {oldest_entry.size_bytes} bytes)")

            self._entries[video_id] = entry
            self._current_bytes += entry_size
            return entry

    def validate_or_discard(
        self,
        video_id: str,
        upstream_total_size: Optional[int] = None,
        upstream_etag: Optional[str] = None,
        upstream_format_id: Optional[str] = None,
    ) -> bool:
        with self._lock:
            entry = self._entries.get(video_id)
            if not entry:
                return False

            # Check total_size validator
            if upstream_total_size is not None and upstream_total_size > 0:
                if entry.total_size != upstream_total_size:
                    logger.info(
                        f"Head cache size mismatch for {video_id}: cached={entry.total_size}, upstream={upstream_total_size}. Discarding."
                    )
                    self._remove_entry(video_id)
                    return False

            # Check ETag validator if present
            if upstream_etag and entry.etag and entry.etag != upstream_etag:
                logger.info(f"Head cache ETag mismatch for {video_id}. Discarding.")
                self._remove_entry(video_id)
                return False

            # Check format_id if present
            if upstream_format_id and entry.format_id and entry.format_id != upstream_format_id:
                logger.info(f"Head cache format mismatch for {video_id}. Discarding.")
                self._remove_entry(video_id)
                return False

            return True

    def remove(self, video_id: str) -> None:
        with self._lock:
            self._remove_entry(video_id)

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()
            self._current_bytes = 0

    def has(self, video_id: str) -> bool:
        return self.get(video_id) is not None

    @property
    def total_bytes(self) -> int:
        with self._lock:
            return self._current_bytes

    @property
    def count(self) -> int:
        with self._lock:
            return len(self._entries)

    def _remove_entry(self, video_id: str) -> None:
        entry = self._entries.pop(video_id, None)
        if entry:
            self._current_bytes -= entry.size_bytes


head_cache = AudioHeadCache()
