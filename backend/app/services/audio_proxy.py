import asyncio
from collections import defaultdict
import logging
import time
from typing import AsyncGenerator, Optional
from fastapi import HTTPException, status
from fastapi.responses import Response, StreamingResponse
import httpx
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.services.audio_cache import audio_cache
from app.services.stream_resolver import StreamResolver
from app.services.usage import bandwidth_guard
from app.sources.models import ResolvedStream

logger = logging.getLogger("music_app.audio_proxy")


class AudioProxy:
    def __init__(self, resolver: StreamResolver):
        self.resolver = resolver
        self._semaphore = asyncio.Semaphore(settings.MAX_CONCURRENT_STREAMS)
        self._download_semaphore = asyncio.Semaphore(settings.MAX_CONCURRENT_DOWNLOADS_GLOBAL)
        self._user_downloads: dict[str, int] = defaultdict(int)
        self._download_lock = asyncio.Lock()

    def _acquire_semaphore_nonblocking(self) -> None:
        if self._semaphore.locked():
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Maximum concurrent audio streams reached. Please try again shortly.",
                headers={"Retry-After": "5"},
            )
        self._semaphore._value -= 1

    def _release_semaphore(self) -> None:
        self._semaphore.release()

    async def _acquire_download_slot(self, user_id: str) -> None:
        async with self._download_lock:
            if self._user_downloads[user_id] >= settings.MAX_CONCURRENT_DOWNLOADS_PER_USER:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Maximum concurrent downloads reached for your user account.",
                    headers={"Retry-After": "5"},
                )
            if self._download_semaphore.locked():
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Global maximum concurrent downloads reached. Please try again shortly.",
                    headers={"Retry-After": "5"},
                )
            self._download_semaphore._value -= 1
            self._user_downloads[user_id] += 1

    async def _release_download_slot(self, user_id: str) -> None:
        async with self._download_lock:
            if self._user_downloads[user_id] > 0:
                self._user_downloads[user_id] -= 1
            self._download_semaphore.release()

    def _parse_range(self, range_header: Optional[str], total_size: int) -> tuple[int, int, int]:
        if not range_header or not range_header.startswith("bytes="):
            return 0, total_size - 1, total_size
        try:
            parts = range_header.replace("bytes=", "").split("-")
            start = int(parts[0]) if parts[0] else 0
            end = int(parts[1]) if len(parts) > 1 and parts[1] else total_size - 1
            end = min(end, total_size - 1)
            start = max(0, min(start, end))
            length = end - start + 1
            return start, end, length
        except Exception:
            return 0, total_size - 1, total_size

    async def _fetch_upstream(
        self,
        client: httpx.AsyncClient,
        stream_info: ResolvedStream,
        range_header: Optional[str],
        method: str = "GET",
    ) -> httpx.Response:
        req_headers = dict(stream_info.headers) if stream_info.headers else {}
        if range_header:
            req_headers["Range"] = range_header

        request = client.build_request(method, stream_info.url, headers=req_headers)
        return await client.send(request, stream=True)

    async def handle_head(
        self,
        video_id: str,
        range_header: Optional[str] = None,
    ) -> Response:
        # Check disk cache first
        if audio_cache.is_cached(video_id):
            total_size = audio_cache.get_size(video_id)
            headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
                "Content-Type": "audio/mp4",
                "X-Audio-Cache": "HIT",
            }
            if range_header:
                start, end, length = self._parse_range(range_header, total_size)
                headers["Content-Length"] = str(length)
                headers["Content-Range"] = f"bytes {start}-{end}/{total_size}"
                return Response(status_code=206, headers=headers)
            else:
                headers["Content-Length"] = str(total_size)
                return Response(status_code=200, headers=headers)

        stream_info = await self.resolver.get_stream(video_id)

        proxy_url = getattr(settings, "UPSTREAM_PROXY", None) or None
        async with httpx.AsyncClient(proxy=proxy_url, timeout=10.0, follow_redirects=True) as client:
            resp = await self._fetch_upstream(
                client, stream_info, range_header, method="HEAD"
            )
            # If HEAD fails or gives 403, retry once
            if resp.status_code in (403, 404, 410):
                await resp.aclose()
                await self.resolver.invalidate(video_id)
                stream_info = await self.resolver.get_stream(video_id)
                resp = await self._fetch_upstream(
                    client, stream_info, range_header, method="HEAD"
                )

            headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
            }
            if "content-type" in resp.headers:
                headers["Content-Type"] = resp.headers["content-type"]
            elif stream_info.content_type:
                headers["Content-Type"] = stream_info.content_type

            if "content-length" in resp.headers:
                headers["Content-Length"] = resp.headers["content-length"]
            if "content-range" in resp.headers:
                headers["Content-Range"] = resp.headers["content-range"]

            status_code = resp.status_code if resp.status_code in (200, 206) else 200
            await resp.aclose()
            return Response(status_code=status_code, headers=headers)

    async def proxy_stream(
        self,
        video_id: str,
        user_id: str,
        db: AsyncSession,
        range_header: Optional[str] = None,
        purpose: str = "stream",
    ) -> Response:
        is_download = (purpose == "download")
        start_time = time.monotonic()
        semaphore_acquired = False
        download_slot_acquired = False

        if is_download:
            # 1. Download Bandwidth check
            await bandwidth_guard.check_download_limits(user_id, db)
            # 2. Download Concurrency check
            await self._acquire_download_slot(user_id)
            download_slot_acquired = True
        else:
            # 1. Bandwidth check
            await bandwidth_guard.check_limits(user_id, db)
            # 2. Concurrency check (non-blocking)
            self._acquire_semaphore_nonblocking()
            semaphore_acquired = True

        # 3. Check Disk Cache First (Instant SSD Delivery)
        if audio_cache.is_cached(video_id):
            total_size = audio_cache.get_size(video_id)
            if is_download and total_size > settings.MAX_DOWNLOAD_TRACK_MB * 1024 * 1024:
                if download_slot_acquired:
                    await self._release_download_slot(user_id)
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail="Audio file exceeds maximum download track size limit.",
                )

            start, end, length = self._parse_range(range_header, total_size)
            status_code = 206 if range_header else 200
            res_headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
                "Content-Type": "audio/mp4",
                "Content-Length": str(length),
                "X-Audio-Cache": "HIT",
            }
            if range_header:
                res_headers["Content-Range"] = f"bytes {start}-{end}/{total_size}"

            async def cached_content_iterator() -> AsyncGenerator[bytes, None]:
                bytes_sent = 0
                try:
                    async for chunk in audio_cache.read_range(video_id, start=start, length=length):
                        bytes_sent += len(chunk)
                        yield chunk
                finally:
                    if is_download:
                        await self._release_download_slot(user_id)
                        duration = time.monotonic() - start_time
                        logger.info(
                            f"Download finished: video_id={video_id} bytes={bytes_sent} duration={duration:.2f}s status={status_code}"
                        )
                        if bytes_sent > 0:
                            await bandwidth_guard.record_bytes(user_id, bytes_sent)
                            await bandwidth_guard.record_download_bytes(user_id, bytes_sent)
                    else:
                        self._release_semaphore()
                        if bytes_sent > 0:
                            await bandwidth_guard.record_bytes(user_id, bytes_sent)

            return StreamingResponse(
                cached_content_iterator(),
                status_code=status_code,
                headers=res_headers,
            )

        # 4. Fallback to Upstream Resolution & Streaming
        proxy_url = getattr(settings, "UPSTREAM_PROXY", None) or None
        client = httpx.AsyncClient(proxy=proxy_url, timeout=30.0, follow_redirects=True)
        upstream_resp: Optional[httpx.Response] = None

        try:
            # 5. Resolve stream
            stream_info = await self.resolver.get_stream(video_id)

            # 6. Request upstream
            upstream_resp = await self._fetch_upstream(
                client, stream_info, range_header, method="GET"
            )

            # 7. Handle upstream 403/404/410 expiry retry
            if upstream_resp.status_code in (403, 404, 410):
                logger.info(
                    f"Upstream returned {upstream_resp.status_code} for {video_id}, re-resolving stream..."
                )
                await upstream_resp.aclose()
                await self.resolver.invalidate(video_id)
                stream_info = await self.resolver.get_stream(video_id)
                upstream_resp = await self._fetch_upstream(
                    client, stream_info, range_header, method="GET"
                )

            if upstream_resp.status_code not in (200, 206):
                await upstream_resp.aclose()
                await client.aclose()
                if is_download:
                    await self._release_download_slot(user_id)
                    download_slot_acquired = False
                else:
                    self._release_semaphore()
                    semaphore_acquired = False
                logger.error(
                    f"Upstream stream failed with status {upstream_resp.status_code} for {video_id}"
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Upstream audio provider returned an error.",
                )

            if is_download:
                upstream_total_size = None
                if "content-range" in upstream_resp.headers:
                    try:
                        cr = upstream_resp.headers["content-range"]
                        if "/" in cr:
                            upstream_total_size = int(cr.split("/")[1])
                    except Exception:
                        pass
                elif "content-length" in upstream_resp.headers and not range_header:
                    try:
                        upstream_total_size = int(upstream_resp.headers["content-length"])
                    except Exception:
                        pass
                if upstream_total_size and upstream_total_size > settings.MAX_DOWNLOAD_TRACK_MB * 1024 * 1024:
                    await upstream_resp.aclose()
                    await client.aclose()
                    await self._release_download_slot(user_id)
                    download_slot_acquired = False
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail="Audio file exceeds maximum download track size limit.",
                    )

            # Filter response headers
            res_headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
                "X-Audio-Cache": "MISS",
            }
            if "content-type" in upstream_resp.headers:
                res_headers["Content-Type"] = upstream_resp.headers["content-type"]
            elif stream_info.content_type:
                res_headers["Content-Type"] = stream_info.content_type

            if "content-length" in upstream_resp.headers:
                res_headers["Content-Length"] = upstream_resp.headers["content-length"]
            if "content-range" in upstream_resp.headers:
                res_headers["Content-Range"] = upstream_resp.headers["content-range"]

            # Save to disk cache if streaming from start
            cache_file = None
            part_path = None
            should_cache = (
                range_header is None or range_header.startswith("bytes=0-")
            ) and upstream_resp.status_code in (200, 206)

            if should_cache:
                try:
                    part_path = audio_cache.get_part_path(video_id)
                    cache_file = open(part_path, "wb")
                except Exception as ce:
                    logger.warning(f"Could not open cache file {part_path}: {ce}")
                    cache_file = None

            async def content_iterator() -> AsyncGenerator[bytes, None]:
                bytes_sent = 0
                stream_completed = False
                try:
                    async for chunk in upstream_resp.aiter_bytes(chunk_size=65536):
                        bytes_sent += len(chunk)
                        if cache_file:
                            cache_file.write(chunk)
                        yield chunk
                    stream_completed = True
                finally:
                    if cache_file:
                        try:
                            cache_file.close()
                            if (
                                stream_completed
                                and part_path
                                and part_path.is_file()
                                and part_path.stat().st_size > 1024
                            ):
                                target_path = audio_cache.get_file_path(video_id)
                                part_path.rename(target_path)
                                logger.info(
                                    f"Successfully cached audio on disk for {video_id} ({bytes_sent} bytes)"
                                )
                                audio_cache.prune_if_needed()
                            elif part_path and part_path.is_file():
                                part_path.unlink()
                        except Exception as e:
                            logger.warning(f"Error finalizing cache file for {video_id}: {e}")

                    await upstream_resp.aclose()
                    await client.aclose()
                    if is_download:
                        await self._release_download_slot(user_id)
                        duration = time.monotonic() - start_time
                        logger.info(
                            f"Download finished: video_id={video_id} bytes={bytes_sent} duration={duration:.2f}s status={upstream_resp.status_code}"
                        )
                        if bytes_sent > 0:
                            await bandwidth_guard.record_bytes(user_id, bytes_sent)
                            await bandwidth_guard.record_download_bytes(user_id, bytes_sent)
                    else:
                        self._release_semaphore()
                        if bytes_sent > 0:
                            await bandwidth_guard.record_bytes(user_id, bytes_sent)

            return StreamingResponse(
                content_iterator(),
                status_code=upstream_resp.status_code,
                headers=res_headers,
            )

        except Exception:
            if upstream_resp:
                await upstream_resp.aclose()
            await client.aclose()
            if download_slot_acquired:
                await self._release_download_slot(user_id)
            elif semaphore_acquired:
                self._release_semaphore()
            raise
