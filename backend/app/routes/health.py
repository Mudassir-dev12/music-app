import time
from fastapi import APIRouter, Response, status
from sqlalchemy import text
from app.cache.factory import get_cache
from app.db.session import check_database_at_head, get_engine

router = APIRouter(tags=["health"])

_START_TIME = time.time()


@router.get("/health")
async def health_check():
    cache_backend = get_cache().name
    db_status = "ok"

    try:
        async with get_engine().connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        db_status = "error"

    overall_status = "ok" if db_status == "ok" else "error"

    return {
        "status": overall_status,
        "version": "1.0.0",
        "uptime_seconds": int(time.time() - _START_TIME),
        "db": db_status,
        "cache": cache_backend,
    }


@router.get("/ready")
async def readiness_check(response: Response):
    try:
        await check_database_at_head()
        return {"status": "ready"}
    except Exception:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready"}
