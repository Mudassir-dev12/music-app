from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.schemas import UsageOut, UserOut
from app.config import settings
from app.db.models import User
from app.db.session import get_db_session
from app.ratelimit import rate_limiter
from app.services.usage import bandwidth_guard

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=UserOut)
async def get_me(user: User = Depends(rate_limiter)):
    return user


@router.get("/usage", response_model=UsageOut)
async def get_my_usage(
    user: User = Depends(rate_limiter),
    db: AsyncSession = Depends(get_db_session),
):
    today_bytes = await bandwidth_guard.get_user_today_bytes(user.id, db)
    daily_limit = (
        settings.DAILY_AUDIO_MB_PER_USER * 1024 * 1024
        if settings.DAILY_AUDIO_MB_PER_USER > 0
        else 0
    )

    global_month_bytes = await bandwidth_guard.get_month_global_bytes(db)
    global_limit = (
        settings.MONTHLY_AUDIO_GB_GLOBAL * 1024 * 1024 * 1024
        if settings.MONTHLY_AUDIO_GB_GLOBAL > 0
        else 0
    )

    return UsageOut(
        today_bytes=today_bytes,
        daily_limit_bytes=daily_limit,
        month_global_bytes=global_month_bytes,
        month_global_limit_bytes=global_limit,
    )
