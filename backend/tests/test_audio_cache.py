import os
import shutil
import tempfile
import pytest
from pathlib import Path
from app.services.audio_cache import AudioCacheManager


@pytest.fixture
def temp_cache_dir():
    temp_dir = tempfile.mkdtemp(prefix="melodia_cache_test_")
    yield temp_dir
    shutil.rmtree(temp_dir, ignore_errors=True)


def test_audio_cache_basic_lifecycle(temp_cache_dir):
    mgr = AudioCacheManager(cache_dir=temp_cache_dir, max_gb=1)
    vid = "dQw4w9WgXcQ"

    assert not mgr.is_cached(vid)
    assert mgr.get_size(vid) == 0

    target = mgr.get_file_path(vid)
    target.write_bytes(b"dummy audio content 1234567890")

    assert mgr.is_cached(vid)
    assert mgr.get_size(vid) == len(b"dummy audio content 1234567890")


@pytest.mark.asyncio
async def test_audio_cache_read_range(temp_cache_dir):
    mgr = AudioCacheManager(cache_dir=temp_cache_dir, max_gb=1)
    vid = "test_range_vid"
    data = b"0123456789abcdefghijklmnopqrstuvwxyz" * 10
    mgr.get_file_path(vid).write_bytes(data)

    # 1. Full read
    chunks = []
    async for chunk in mgr.read_range(vid):
        chunks.append(chunk)
    assert b"".join(chunks) == data

    # 2. Slice read (start=10, length=20)
    slice_chunks = []
    async for chunk in mgr.read_range(vid, start=10, length=20, chunk_size=8):
        slice_chunks.append(chunk)
    assert b"".join(slice_chunks) == data[10:30]


def test_audio_cache_pruning(temp_cache_dir):
    # Set max 100 bytes
    mgr = AudioCacheManager(cache_dir=temp_cache_dir, max_gb=1)
    mgr.max_bytes = 100

    # Write 3 files of 50 bytes each = 150 bytes (exceeds 100 bytes)
    for i in range(3):
        p = mgr.get_file_path(f"track_{i}")
        p.write_bytes(b"x" * 50)
        os.utime(p, (1000 + i * 10, 1000 + i * 10))

    assert len(list(Path(temp_cache_dir).glob("*.m4a"))) == 3

    mgr.prune_if_needed()

    # Prunes oldest files until <= 80 bytes (target_size = 0.8 * 100 = 80)
    remaining = list(Path(temp_cache_dir).glob("*.m4a"))
    # Oldest (track_0) and second oldest (track_1) pruned, leaving at most 1 or 2
    assert len(remaining) <= 2
    total_remaining_size = sum(f.stat().st_size for f in remaining)
    assert total_remaining_size <= 80

