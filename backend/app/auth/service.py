import datetime
import hashlib
import hmac
import uuid
from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.passwords import (
    hash_password,
    validate_password_strength,
    verify_dummy,
    verify_password,
)
from app.auth.schemas import LoginRequest, RegisterRequest, TokenPair, UserOut
from app.auth.tokens import (
    create_access_token,
    generate_refresh_token,
    hash_refresh_token,
)
from app.cache.factory import get_cache
from app.config import settings
from app.db.models import RefreshToken, User


def get_ip_hash(ip: str) -> str:
    secret = settings.APP_JWT_SECRET or "salt_default"
    return hashlib.sha256(f"{ip}:{secret}".encode("utf-8")).hexdigest()[:16]


def get_email_hash(email: str) -> str:
    return hashlib.sha256(email.strip().lower().encode("utf-8")).hexdigest()[:16]


class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.cache = get_cache()

    async def check_login_rate_limit(self, email: str, ip_hash: str) -> None:
        email_hash = get_email_hash(email)
        email_key = f"lf:{email_hash}:{ip_hash}"
        ip_key = f"lf:ip:{ip_hash}"

        cached_email_fails = await self.cache.get(email_key) or 0
        cached_ip_fails = await self.cache.get(ip_key) or 0

        max_email_fails = settings.LOGIN_MAX_FAILURES
        max_ip_fails = settings.LOGIN_MAX_FAILURES * 6

        if int(cached_email_fails) >= max_email_fails or int(cached_ip_fails) >= max_ip_fails:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many failed login attempts. Please try again later.",
                headers={"Retry-After": str(settings.LOGIN_WINDOW_SECONDS)},
            )

    async def record_login_failure(self, email: str, ip_hash: str) -> None:
        email_hash = get_email_hash(email)
        email_key = f"lf:{email_hash}:{ip_hash}"
        ip_key = f"lf:ip:{ip_hash}"

        await self.cache.incr(email_key, settings.LOGIN_WINDOW_SECONDS)
        await self.cache.incr(ip_key, settings.LOGIN_WINDOW_SECONDS)

    async def record_login_success(self, email: str, ip_hash: str) -> None:
        email_hash = get_email_hash(email)
        email_key = f"lf:{email_hash}:{ip_hash}"
        await self.cache.delete(email_key)

    async def register(
        self, req: RegisterRequest, client_ip: str, user_agent: str | None = None
    ) -> TokenPair:
        if not settings.ALLOW_REGISTRATION:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Registration is currently disabled.",
            )

        if settings.REGISTRATION_INVITE_CODE:
            if not req.invite_code or not hmac.compare_digest(
                req.invite_code.strip(), settings.REGISTRATION_INVITE_CODE.strip()
            ):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Invalid or missing invite code.",
                )

        ip_hash = get_ip_hash(client_ip)
        reg_limit_key = f"reg:{ip_hash}"
        reg_count = await self.cache.incr(reg_limit_key, 3600)
        if reg_count > 5:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Registration limit exceeded for this IP. Please try again later.",
                headers={"Retry-After": "3600"},
            )

        if settings.MAX_USERS > 0:
            user_count_res = await self.db.execute(select(func.count(User.id)))
            current_users = user_count_res.scalar() or 0
            if current_users >= settings.MAX_USERS:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="User limit reached on this server.",
                )

        normalized_email = req.email.strip().lower()

        try:
            validate_password_strength(req.password, normalized_email)
        except ValueError as e:
            raise HTTPException(
                status_code=422,
                detail=str(e),
            )

        existing = await self.db.execute(
            select(User).where(User.email == normalized_email)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email already exists.",
            )

        pwd_hash = await hash_password(req.password)
        now = datetime.datetime.now(datetime.timezone.utc)
        user = User(
            id=str(uuid.uuid4()),
            email=normalized_email,
            password_hash=pwd_hash,
            display_name=req.display_name.strip() if req.display_name else None,
            is_active=True,
            created_at=now,
            last_login_at=now,
        )
        self.db.add(user)
        await self.db.flush()

        raw_refresh = generate_refresh_token()
        refresh_obj = RefreshToken(
            id=str(uuid.uuid4()),
            user_id=user.id,
            family_id=str(uuid.uuid4()),
            token_hash=hash_refresh_token(raw_refresh),
            created_at=now,
            expires_at=now + datetime.timedelta(days=settings.REFRESH_TOKEN_TTL_DAYS),
            user_agent=user_agent[:200] if user_agent else None,
            ip_hash=ip_hash,
        )
        self.db.add(refresh_obj)
        await self.db.commit()
        await self.db.refresh(user)

        access_token = create_access_token(user.id)
        return TokenPair(
            access_token=access_token,
            refresh_token=raw_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_TTL_MIN * 60,
            user=UserOut.model_validate(user),
        )

    async def login(
        self, req: LoginRequest, client_ip: str, user_agent: str | None = None
    ) -> TokenPair:
        ip_hash = get_ip_hash(client_ip)
        normalized_email = req.email.strip().lower()

        await self.check_login_rate_limit(normalized_email, ip_hash)

        res = await self.db.execute(select(User).where(User.email == normalized_email))
        user = res.scalar_one_or_none()

        if not user:
            await verify_dummy()
            await self.record_login_failure(normalized_email, ip_hash)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        valid, needs_rehash = await verify_password(req.password, user.password_hash)
        if not valid:
            await self.record_login_failure(normalized_email, ip_hash)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if not user.is_active:
            await self.record_login_failure(normalized_email, ip_hash)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Account is inactive.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        await self.record_login_success(normalized_email, ip_hash)

        now = datetime.datetime.now(datetime.timezone.utc)
        user.last_login_at = now
        if needs_rehash:
            user.password_hash = await hash_password(req.password)

        raw_refresh = generate_refresh_token()
        refresh_obj = RefreshToken(
            id=str(uuid.uuid4()),
            user_id=user.id,
            family_id=str(uuid.uuid4()),
            token_hash=hash_refresh_token(raw_refresh),
            created_at=now,
            expires_at=now + datetime.timedelta(days=settings.REFRESH_TOKEN_TTL_DAYS),
            user_agent=user_agent[:200] if user_agent else None,
            ip_hash=ip_hash,
        )
        self.db.add(refresh_obj)
        await self.db.commit()
        await self.db.refresh(user)

        access_token = create_access_token(user.id)
        return TokenPair(
            access_token=access_token,
            refresh_token=raw_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_TTL_MIN * 60,
            user=UserOut.model_validate(user),
        )

    async def refresh(
        self, refresh_token_raw: str, client_ip: str, user_agent: str | None = None
    ) -> TokenPair:
        token_hash = hash_refresh_token(refresh_token_raw)
        res = await self.db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )
        token_obj = res.scalar_one_or_none()

        if not token_obj:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        now = datetime.datetime.now(datetime.timezone.utc)

        # Token expiration check
        expires_at = token_obj.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=datetime.timezone.utc)

        if expires_at < now:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token has expired.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Reuse detection
        if token_obj.revoked_at is not None:
            revoked_at = token_obj.revoked_at
            if revoked_at.tzinfo is None:
                revoked_at = revoked_at.replace(tzinfo=datetime.timezone.utc)

            time_since_revoked = (now - revoked_at).total_seconds()
            if time_since_revoked > settings.REFRESH_REUSE_GRACE_SECONDS:
                # Potential token theft: Revoke entire token family
                await self.db.execute(
                    update(RefreshToken)
                    .where(
                        RefreshToken.family_id == token_obj.family_id,
                        RefreshToken.revoked_at.is_(None),
                    )
                    .values(revoked_at=now)
                )
                await self.db.commit()
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid refresh token.",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            else:
                # Within grace period (concurrent requests), reject without revoking family
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid refresh token.",
                    headers={"WWW-Authenticate": "Bearer"},
                )

        # Fetch active user
        user_res = await self.db.execute(
            select(User).where(User.id == token_obj.user_id, User.is_active == True)
        )
        user = user_res.scalar_one_or_none()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User inactive or not found.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Rotate token
        new_token_id = str(uuid.uuid4())
        raw_refresh = generate_refresh_token()
        token_obj.revoked_at = now
        token_obj.replaced_by = new_token_id

        ip_hash = get_ip_hash(client_ip)
        new_refresh_obj = RefreshToken(
            id=new_token_id,
            user_id=user.id,
            family_id=token_obj.family_id,
            token_hash=hash_refresh_token(raw_refresh),
            created_at=now,
            expires_at=now + datetime.timedelta(days=settings.REFRESH_TOKEN_TTL_DAYS),
            user_agent=user_agent[:200] if user_agent else None,
            ip_hash=ip_hash,
        )
        self.db.add(new_refresh_obj)
        await self.db.commit()

        access_token = create_access_token(user.id)
        return TokenPair(
            access_token=access_token,
            refresh_token=raw_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_TTL_MIN * 60,
            user=UserOut.model_validate(user),
        )

    async def logout(self, refresh_token_raw: str) -> None:
        token_hash = hash_refresh_token(refresh_token_raw)
        res = await self.db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )
        token_obj = res.scalar_one_or_none()
        if token_obj:
            now = datetime.datetime.now(datetime.timezone.utc)
            await self.db.execute(
                update(RefreshToken)
                .where(
                    RefreshToken.family_id == token_obj.family_id,
                    RefreshToken.revoked_at.is_(None),
                )
                .values(revoked_at=now)
            )
            await self.db.commit()
        # Always idempotent (no error raised if token not found)
