import datetime
import hashlib
import secrets
import uuid
import jwt
from app.config import settings


def create_access_token(user_id: str) -> str:
    now = datetime.datetime.now(datetime.timezone.utc)
    exp = now + datetime.timedelta(minutes=settings.ACCESS_TOKEN_TTL_MIN)
    payload = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "jti": uuid.uuid4().hex,
        "typ": "access",
    }
    return jwt.encode(payload, settings.APP_JWT_SECRET, algorithm="HS256")


def verify_access_token(token: str) -> dict:
    options = {
        "require": ["exp", "iss", "aud", "sub"],
        "verify_signature": True,
        "verify_exp": True,
        "verify_iss": True,
        "verify_aud": True,
    }

    # Pin algorithm list strictly to HS256 (never accept none or asymmetric headers)
    secrets_to_try = [settings.APP_JWT_SECRET]
    if settings.APP_JWT_SECRET_PREVIOUS:
        secrets_to_try.append(settings.APP_JWT_SECRET_PREVIOUS)

    last_error: Exception | None = None
    for sec in secrets_to_try:
        try:
            payload = jwt.decode(
                token,
                sec,
                algorithms=["HS256"],
                issuer=settings.JWT_ISSUER,
                audience=settings.JWT_AUDIENCE,
                options=options,
            )
            if payload.get("typ") != "access":
                raise jwt.InvalidTokenError("Invalid token type claim")
            return payload
        except Exception as e:
            last_error = e

    raise last_error or jwt.InvalidTokenError("Token verification failed")


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
