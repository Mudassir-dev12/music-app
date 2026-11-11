from fastapi import APIRouter
from sqlalchemy import text
from app.cache.factory import get_cache
from app.config import settings
from app.db.session import get_engine

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check():
    cache_backend = get_cache().name
    db_status = "ok"

    try:
        async with get_engine().connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        db_status = "error"

    return {
        "status": "ok",
        "version": "1.0.0",
        "cache": cache_backend,
        "db": db_status,
        "env": settings.APP_ENV,
    }
