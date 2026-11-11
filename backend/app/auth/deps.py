import datetime
from typing import Optional
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.tokens import verify_access_token
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import User
from app.db.session import get_db_session

security = HTTPBearer(auto_error=False)


def get_client_ip(request: Request) -> str:
    if settings.TRUST_FORWARDED_FOR:
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            # First IP in comma-separated list
            return forwarded.split(",")[0].strip()
    if request.client and request.client.host:
        return request.client.host
    return "127.0.0.1"


async def get_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db_session),
) -> User:
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials were not provided.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    try:
        payload = verify_access_token(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token claims.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    cache = get_cache()
    cache_key = f"uact:{user_id}"
    cached_user = await cache.get(cache_key)

    if cached_user == "inactive":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is deactivated.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    elif isinstance(cached_user, dict):
        user = User(
            id=cached_user["id"],
            email=cached_user["email"],
            display_name=cached_user.get("display_name"),
            created_at=datetime.datetime.fromisoformat(cached_user["created_at"]),
            is_active=cached_user.get("is_active", True),
        )
    else:
        res = await db.execute(select(User).where(User.id == user_id))
        user = res.scalar_one_or_none()
        if not user or not user.is_active:
            await cache.set(cache_key, "inactive", ttl=30)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User account is inactive or not found.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        user_dict = {
            "id": user.id,
            "email": user.email,
            "display_name": user.display_name,
            "created_at": (
                user.created_at.isoformat()
                if hasattr(user.created_at, "isoformat")
                else str(user.created_at)
            ),
            "is_active": user.is_active,
        }
        await cache.set(cache_key, user_dict, ttl=30)

    request.state.user_id = user.id
    return user
