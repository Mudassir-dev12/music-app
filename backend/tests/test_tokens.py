import asyncio
import datetime
import uuid
import jwt
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from app.auth.tokens import create_access_token, hash_refresh_token
from app.config import settings
from app.db.models import RefreshToken, User
from app.db.session import get_sessionmaker


@pytest.mark.asyncio
async def test_access_token_validation(client: AsyncClient):
    email = f"tokens_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"

    reg = await client.post("/auth/register", json={"email": email, "password": pwd})
    data = reg.json()
    valid_token = data["access_token"]
    user_id = data["user"]["id"]

    # 1. Valid token passes
    r1 = await client.get("/me", headers={"Authorization": f"Bearer {valid_token}"})
    assert r1.status_code == 200
    assert r1.json()["id"] == user_id

    # 2. Missing authorization header
    r2 = await client.get("/me")
    assert r2.status_code == 401

    # 3. Expired token
    expired_payload = {
        "sub": user_id,
        "iat": int(datetime.datetime.now(datetime.timezone.utc).timestamp()) - 3600,
        "exp": int(datetime.datetime.now(datetime.timezone.utc).timestamp()) - 1800,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "typ": "access",
    }
    expired_tok = jwt.encode(expired_payload, settings.APP_JWT_SECRET, algorithm="HS256")
    r3 = await client.get("/me", headers={"Authorization": f"Bearer {expired_tok}"})
    assert r3.status_code == 401

    # 4. Wrong audience
    wrong_aud = dict(expired_payload, exp=int(datetime.datetime.now(datetime.timezone.utc).timestamp()) + 3600, aud="wrong-aud")
    tok_aud = jwt.encode(wrong_aud, settings.APP_JWT_SECRET, algorithm="HS256")
    r4 = await client.get("/me", headers={"Authorization": f"Bearer {tok_aud}"})
    assert r4.status_code == 401

    # 5. Wrong secret
    tok_wrong_sec = jwt.encode(dict(expired_payload, exp=int(datetime.datetime.now(datetime.timezone.utc).timestamp()) + 3600), "completely-different-secret-key-32chars", algorithm="HS256")
    r5 = await client.get("/me", headers={"Authorization": f"Bearer {tok_wrong_sec}"})
    assert r5.status_code == 401

    # 6. Tampered payload
    tampered = valid_token[:-4] + "abcd"
    r6 = await client.get("/me", headers={"Authorization": f"Bearer {tampered}"})
    assert r6.status_code == 401

    # 7. alg: none
    tok_none = jwt.encode({"sub": user_id, "typ": "access"}, key="", algorithm="none")
    r7 = await client.get("/me", headers={"Authorization": f"Bearer {tok_none}"})
    assert r7.status_code == 401

    # 8. Refresh token used as access token
    r8 = await client.get("/me", headers={"Authorization": f"Bearer {data['refresh_token']}"})
    assert r8.status_code == 401

    # 9. Previous secret works for verification
    prev_payload = {
        "sub": user_id,
        "iat": int(datetime.datetime.now(datetime.timezone.utc).timestamp()),
        "exp": int(datetime.datetime.now(datetime.timezone.utc).timestamp()) + 1800,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "typ": "access",
    }
    prev_tok = jwt.encode(prev_payload, settings.APP_JWT_SECRET_PREVIOUS, algorithm="HS256")
    r9 = await client.get("/me", headers={"Authorization": f"Bearer {prev_tok}"})
    assert r9.status_code == 200


@pytest.mark.asyncio
async def test_refresh_token_rotation_grace_and_reuse_detection(client: AsyncClient):
    email = f"rotation_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"

    reg = await client.post("/auth/register", json={"email": email, "password": pwd})
    data1 = reg.json()
    ref1 = data1["refresh_token"]

    # 1. First refresh -> succeeds and returns pair 2
    r_ref1 = await client.post("/auth/refresh", json={"refresh_token": ref1})
    assert r_ref1.status_code == 200
    data2 = r_ref1.json()
    ref2 = data2["refresh_token"]
    assert ref2 != ref1

    # 2. Present ref1 inside grace window -> rejected with 401, but does NOT revoke family
    settings.REFRESH_REUSE_GRACE_SECONDS = 10
    r_grace = await client.post("/auth/refresh", json={"refresh_token": ref1})
    assert r_grace.status_code == 401

    # Ref2 still works because inside grace period
    r_ref2 = await client.post("/auth/refresh", json={"refresh_token": ref2})
    assert r_ref2.status_code == 200
    data3 = r_ref2.json()
    ref3 = data3["refresh_token"]

    # 3. Simulate reuse outside grace window:
    # Update ref2's revoked_at to 20 seconds ago
    AsyncSessionLocal = get_sessionmaker()
    async with AsyncSessionLocal() as session:
        h2 = hash_refresh_token(ref2)
        res = await session.execute(select(RefreshToken).where(RefreshToken.token_hash == h2))
        t2 = res.scalar_one()
        past_time = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=30)
        t2.revoked_at = past_time
        await session.commit()

    # Replay ref2 after grace window -> triggers theft detection: family revoked!
    r_theft = await client.post("/auth/refresh", json={"refresh_token": ref2})
    assert r_theft.status_code == 401

    # Now ref3 (which was active) must ALSO be revoked and fail!
    r_ref3 = await client.post("/auth/refresh", json={"refresh_token": ref3})
    assert r_ref3.status_code == 401


@pytest.mark.asyncio
async def test_logout_idempotent_and_revocation(client: AsyncClient):
    email = f"logout_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"

    reg = await client.post("/auth/register", json={"email": email, "password": pwd})
    data = reg.json()
    ref = data["refresh_token"]

    # Logout
    r_logout1 = await client.post("/auth/logout", json={"refresh_token": ref})
    assert r_logout1.status_code == 204

    # Idempotent logout with same or random token
    r_logout2 = await client.post("/auth/logout", json={"refresh_token": ref})
    assert r_logout2.status_code == 204
    r_logout3 = await client.post("/auth/logout", json={"refresh_token": "random_unknown_token"})
    assert r_logout3.status_code == 204

    # Refreshing with logged out token fails
    r_ref = await client.post("/auth/refresh", json={"refresh_token": ref})
    assert r_ref.status_code == 401


@pytest.mark.asyncio
async def test_token_issuer_algo_previous_secret_and_deactivated_user(client: AsyncClient):
    email = f"tokedge_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"

    reg = await client.post("/auth/register", json={"email": email, "password": pwd})
    data = reg.json()
    user_id = data["user"]["id"]
    access_tok = data["access_token"]
    refresh_tok = data["refresh_token"]

    now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())

    # 1. Newly minted token is signed with APP_JWT_SECRET, NOT APP_JWT_SECRET_PREVIOUS
    with pytest.raises(jwt.InvalidSignatureError):
        jwt.decode(
            access_tok,
            settings.APP_JWT_SECRET_PREVIOUS,
            algorithms=["HS256"],
            issuer=settings.JWT_ISSUER,
            audience=settings.JWT_AUDIENCE,
        )

    # 2. Wrong issuer -> 401
    wrong_iss_tok = jwt.encode(
        {
            "sub": user_id,
            "iat": now_ts,
            "exp": now_ts + 600,
            "iss": "other-issuer",
            "aud": settings.JWT_AUDIENCE,
            "typ": "access",
        },
        settings.APP_JWT_SECRET,
        algorithm="HS256",
    )
    r_iss = await client.get("/me", headers={"Authorization": f"Bearer {wrong_iss_tok}"})
    assert r_iss.status_code == 401

    # 3. Wrong algorithm (HS512) -> 401
    other_alg_tok = jwt.encode(
        {
            "sub": user_id,
            "iat": now_ts,
            "exp": now_ts + 600,
            "iss": settings.JWT_ISSUER,
            "aud": settings.JWT_AUDIENCE,
            "typ": "access",
        },
        settings.APP_JWT_SECRET,
        algorithm="HS512",
    )
    r_alg = await client.get("/me", headers={"Authorization": f"Bearer {other_alg_tok}"})
    assert r_alg.status_code == 401

    # 4. Refresh token stored only as sha256 hash in DB, and expired refresh fails
    AsyncSessionLocal = get_sessionmaker()
    async with AsyncSessionLocal() as session:
        expected_hash = hash_refresh_token(refresh_tok)
        assert len(expected_hash) == 64
        assert expected_hash != refresh_tok
        res = await session.execute(select(RefreshToken).where(RefreshToken.token_hash == expected_hash))
        rt_row = res.scalar_one()
        rt_row.expires_at = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=1)
        await session.commit()

    r_exp_ref = await client.post("/auth/refresh", json={"refresh_token": refresh_tok})
    assert r_exp_ref.status_code == 401

    # 5. Deactivated user is rejected within cache window (once cache expires/clears)
    from app.cache.factory import get_cache
    async with AsyncSessionLocal() as session:
        res = await session.execute(select(User).where(User.id == user_id))
        u = res.scalar_one()
        u.is_active = False
        await session.commit()

    await get_cache().delete(f"uact:{user_id}")
    r_deact = await client.get("/me", headers={"Authorization": f"Bearer {access_tok}"})
    assert r_deact.status_code == 401
