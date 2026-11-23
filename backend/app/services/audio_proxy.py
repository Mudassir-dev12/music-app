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
from app.services.head_cache import head_cache
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
        proxy_url = getattr(settings, "UPSTREAM_PROXY", None) or None
        self._client = httpx.AsyncClient(
            proxy=proxy_url,
            timeout=30.0,
            follow_redirects=True,
            limits=httpx.Limits(max_keepalive_connections=20, max_connections=50),
        )

    async def aclose(self) -> None:
        await self._client.aclose()

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
        # 1. Check disk cache first
        if audio_cache.is_cached(video_id):
            total_size = audio_cache.get_size(video_id)
            headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
                "Content-Type": "audio/mp4",
                "X-Audio-Cache": "HIT",
                "X-Cache": "disk",
                "X-Accel-Buffering": "no",
            }
            if range_header:
                start, end, length = self._parse_range(range_header, total_size)
                headers["Content-Length"] = str(length)
                headers["Content-Range"] = f"bytes {start}-{end}/{total_size}"
                return Response(status_code=206, headers=headers)
            else:
                headers["Content-Length"] = str(total_size)
                return Response(status_code=200, headers=headers)

        # 2. Check head cache
        head_entry = head_cache.get(video_id)
        if head_entry:
            total_size = head_entry.total_size
            headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
                "Content-Type": head_entry.content_type,
                "X-Audio-Cache": "HIT",
                "X-Cache": "head",
                "X-Accel-Buffering": "no",
            }
            if range_header:
                start, end, length = self._parse_range(range_header, total_size)
                headers["Content-Length"] = str(length)
                headers["Content-Range"] = f"bytes {start}-{end}/{total_size}"
                return Response(status_code=206, headers=headers)
            else:
                headers["Content-Length"] = str(total_size)
                return Response(status_code=200, headers=headers)

        # 3. Fallback to upstream HEAD
        stream_info = await self.resolver.get_stream(video_id)
        resp = await self._fetch_upstream(
            self._client, stream_info, range_header, method="HEAD"
        )
        if resp.status_code in (403, 404, 410):
            await resp.aclose()
            await self.resolver.invalidate(video_id)
            stream_info = await self.resolver.get_stream(video_id)
            resp = await self._fetch_upstream(
                self._client, stream_info, range_header, method="HEAD"
            )

        headers = {
            "Accept-Ranges": "bytes",
            "Cache-Control": "private, no-store",
            "Referrer-Policy": "no-referrer",
            "X-Cache": "miss",
            "X-Accel-Buffering": "no",
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
            await bandwidth_guard.check_download_limits(user_id, db)
            await self._acquire_download_slot(user_id)
            download_slot_acquired = True
        else:
            await bandwidth_guard.check_limits(user_id, db)
            self._acquire_semaphore_nonblocking()
            semaphore_acquired = True

        # 1. Check Disk Cache First
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
                "X-Cache": "disk",
                "X-Accel-Buffering": "no",
                "Server-Timing": f"disk;dur={((time.monotonic() - start_time)*1000):.1f}",
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

        # 2. Check Head Cache (Instant First Bytes + Stitched Stream)
        head_entry = head_cache.get(video_id) if not is_download else None
        can_use_head = (
            head_entry is not None
            and (range_header is None or range_header.startswith("bytes=0-"))
        )

        if can_use_head and head_entry:
            total_size = head_entry.total_size
            start, end, length = self._parse_range(range_header, total_size)
            head_len = min(len(head_entry.head_bytes), length)
            head_slice = head_entry.head_bytes[:head_len]

            status_code = 206 if range_header else 200
            res_headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
                "Content-Type": head_entry.content_type,
                "Content-Length": str(length),
                "X-Audio-Cache": "HIT",
                "X-Cache": "head",
                "X-Accel-Buffering": "no",
                "Server-Timing": f"head;dur={((time.monotonic() - start_time)*1000):.1f}",
            }
            if range_header:
                res_headers["Content-Range"] = f"bytes {start}-{end}/{total_size}"

            async def stitched_content_iterator() -> AsyncGenerator[bytes, None]:
                bytes_sent = 0
                upstream_resp_stitched: Optional[httpx.Response] = None
                try:
                    # Send head bytes immediately
                    bytes_sent += len(head_slice)
                    yield head_slice

                    # If more bytes needed, stream remainder from upstream
                    if head_len < length:
                        remainder_start = start + head_len
                        remainder_range = f"bytes={remainder_start}-{end}"
                        stream_info = await self.resolver.get_stream(video_id)
                        upstream_resp_stitched = await self._fetch_upstream(
                            self._client, stream_info, remainder_range, method="GET"
                        )
                        if upstream_resp_stitched.status_code in (403, 404, 410):
                            await upstream_resp_stitched.aclose()
                            await self.resolver.invalidate(video_id)
                            stream_info = await self.resolver.get_stream(video_id)
                            upstream_resp_stitched = await self._fetch_upstream(
                                self._client, stream_info, remainder_range, method="GET"
                            )

                        if upstream_resp_stitched.status_code in (200, 206):
                            async for chunk in upstream_resp_stitched.aiter_bytes(chunk_size=65536):
                                bytes_sent += len(chunk)
                                yield chunk
                        else:
                            logger.warning(
                                f"Stitched upstream remainder failed status {upstream_resp_stitched.status_code} for {video_id}"
                            )
                except Exception as ex:
                    logger.warning(f"Error in stitched audio iterator for {video_id}: {ex}")
                finally:
                    if upstream_resp_stitched:
                        await upstream_resp_stitched.aclose()
                    self._release_semaphore()
                    if bytes_sent > 0:
                        await bandwidth_guard.record_bytes(user_id, bytes_sent)

            return StreamingResponse(
                stitched_content_iterator(),
                status_code=status_code,
                headers=res_headers,
            )

        # 3. Fallback to Upstream Resolution & Streaming
        upstream_resp: Optional[httpx.Response] = None
        try:
            is_url_cached = await self.resolver.is_warm(video_id)
            t_res = time.monotonic()
            stream_info = await self.resolver.get_stream(video_id)
            res_dur = (time.monotonic() - t_res) * 1000

            t_conn = time.monotonic()
            upstream_resp = await self._fetch_upstream(
                self._client, stream_info, range_header, method="GET"
            )

            # Handle upstream 403/404/410 expiry retry
            if upstream_resp.status_code in (403, 404, 410):
                await upstream_resp.aclose()
                head_cache.remove(video_id)
                await self.resolver.invalidate(video_id)
                stream_info = await self.resolver.get_stream(video_id)
                upstream_resp = await self._fetch_upstream(
                    self._client, stream_info, range_header, method="GET"
                )

            conn_dur = (time.monotonic() - t_conn) * 1000

            if upstream_resp.status_code not in (200, 206):
                await upstream_resp.aclose()
                if is_download:
                    await self._release_download_slot(user_id)
                    download_slot_acquired = False
                else:
                    self._release_semaphore()
                    semaphore_acquired = False
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
                    await self._release_download_slot(user_id)
                    download_slot_acquired = False
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail="Audio file exceeds maximum download track size limit.",
                    )

            # Response headers
            cache_tag = "url" if is_url_cached else "miss"
            res_headers = {
                "Accept-Ranges": "bytes",
                "Cache-Control": "private, no-store",
                "Referrer-Policy": "no-referrer",
                "X-Audio-Cache": "MISS",
                "X-Cache": cache_tag,
                "X-Accel-Buffering": "no",
                "Server-Timing": f"resolve;dur={res_dur:.1f}, connect;dur={conn_dur:.1f}",
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
            should_cache_disk = (
                range_header is None or range_header.startswith("bytes=0-")
            ) and upstream_resp.status_code in (200, 206)

            if should_cache_disk:
                try:
                    part_path = audio_cache.get_part_path(video_id)
                    cache_file = open(part_path, "wb")
                except Exception as ce:
                    logger.warning(f"Could not open cache file {part_path}: {ce}")
                    cache_file = None

            # Collect head bytes to populate head_cache
            head_buffer = bytearray()
            should_tee_head = (
                not is_download
                and (range_header is None or range_header.startswith("bytes=0-"))
            )

            # Determine upstream total size
            total_size_calc = None
            if "content-range" in upstream_resp.headers:
                try:
                    total_size_calc = int(upstream_resp.headers["content-range"].split("/")[-1])
                except Exception:
                    pass
            elif "content-length" in upstream_resp.headers and not range_header:
                try:
                    total_size_calc = int(upstream_resp.headers["content-length"])
                except Exception:
                    pass

            upstream_etag = upstream_resp.headers.get("etag")

            async def content_iterator() -> AsyncGenerator[bytes, None]:
                bytes_sent = 0
                stream_completed = False
                try:
                    async for chunk in upstream_resp.aiter_bytes(chunk_size=65536):
                        bytes_sent += len(chunk)
                        if cache_file:
                            cache_file.write(chunk)
                        if should_tee_head and len(head_buffer) < settings.HEAD_BYTES:
                            needed = settings.HEAD_BYTES - len(head_buffer)
                            head_buffer.extend(chunk[:needed])
                        yield chunk
                    stream_completed = True
                finally:
                    # Finalize head cache if we captured head bytes of a real audio file
                    if should_tee_head and len(head_buffer) > 0 and total_size_calc and total_size_calc > 1024:
                        try:
                            head_cache.put(
                                video_id=video_id,
                                head_bytes=bytes(head_buffer),
                                total_size=total_size_calc,
                                content_type=res_headers.get("Content-Type", "audio/mp4"),
                                etag=upstream_etag,
                            )
                        except Exception as e:
                            logger.debug(f"Failed to populate head cache for {video_id}: {e}")

                    # Finalize disk cache
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
                                audio_cache.prune_if_needed()
                            elif part_path and part_path.is_file():
                                part_path.unlink()
                        except Exception as e:
                            logger.warning(f"Error finalizing cache file for {video_id}: {e}")

                    await upstream_resp.aclose()
                    if is_download:
                        await self._release_download_slot(user_id)
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
            if download_slot_acquired:
                await self._release_download_slot(user_id)
            elif semaphore_acquired:
                self._release_semaphore()
            raise
