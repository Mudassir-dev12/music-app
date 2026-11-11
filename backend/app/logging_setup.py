import hashlib
import logging
import sys
import time
import uuid
from typing import Callable
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("music_app")


def setup_logging(level: str = "INFO") -> None:
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    handler.setFormatter(formatter)
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    if not logger.handlers:
        logger.addHandler(handler)
    # Ensure root/uvicorn does not duplicate or leak
    logging.getLogger("uvicorn.access").handlers = []


def hash_id(val: str | None) -> str:
    if not val:
        return "anon"
    return hashlib.sha256(val.encode("utf-8")).hexdigest()[:12]


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        req_id = request.headers.get("X-Request-ID")
        if not req_id:
            req_id = uuid.uuid4().hex
        request.state.request_id = req_id

        start_time = time.perf_counter()
        user_id_hash = "anon"

        try:
            response = await call_next(request)
        except Exception:
            duration_ms = (time.perf_counter() - start_time) * 1000.0
            logger.error(
                f"req_id={req_id} method={request.method} path={request.url.path} "
                f"status=500 duration_ms={duration_ms:.2f} user={user_id_hash} - Unhandled Exception"
            )
            raise

        duration_ms = (time.perf_counter() - start_time) * 1000.0
        # If user was authenticated, their user_id might be stored in request.state.user_id
        if hasattr(request.state, "user_id") and request.state.user_id:
            user_id_hash = hash_id(str(request.state.user_id))

        response.headers["X-Request-ID"] = req_id

        # Redact any accidental logging of sensitive query params (e.g. if any)
        path = request.url.path
        logger.info(
            f"req_id={req_id} method={request.method} path={path} "
            f"status={response.status_code} duration_ms={duration_ms:.2f} user={user_id_hash}"
        )
        return response
