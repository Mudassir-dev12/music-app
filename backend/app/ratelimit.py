import time
from fastapi import Depends, HTTPException, Request, status
from app.auth.deps import get_audio_user, get_current_user
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import User


async def enforce_rate_limit(user: User) -> User:
    if settings.RATE_LIMIT_PER_MIN <= 0:
        return user

    cache = get_cache()
    now = int(time.time())
    minute_bucket = now // 60
    key = f"rl:{user.id}:{minute_bucket}"

    count = await cache.incr(key, ttl=60)
    if count > settings.RATE_LIMIT_PER_MIN:
        seconds_left = 60 - (now % 60)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Please wait before making more requests.",
            headers={"Retry-After": str(max(1, seconds_left))},
        )
    return user


async def rate_limiter(
    request: Request,
    user: User = Depends(get_current_user),
) -> User:
    return await enforce_rate_limit(user)


async def audio_rate_limiter(
    request: Request,
    user: User = Depends(get_audio_user),
) -> User:
    return await enforce_rate_limit(user)
