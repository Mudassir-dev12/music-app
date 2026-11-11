import uuid
import pytest
from httpx import AsyncClient
from app.config import settings


@pytest.mark.asyncio
async def test_register_and_login_success(client: AsyncClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"

    # 1. Register
    reg_resp = await client.post(
        "/auth/register",
        json={"email": email, "password": pwd, "display_name": "Test User"},
    )
    assert reg_resp.status_code == 201
    data = reg_resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == email.lower()
    assert data["user"]["display_name"] == "Test User"
    assert pwd not in reg_resp.text

    # 2. Login
    login_resp = await client.post(
        "/auth/login",
        json={"email": email.upper(), "password": pwd},  # Case-insensitive
    )
    assert login_resp.status_code == 200
    login_data = login_resp.json()
    assert "access_token" in login_data
    assert "refresh_token" in login_data
    assert pwd not in login_resp.text


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient):
    email = f"dup_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"

    resp1 = await client.post(
        "/auth/register", json={"email": email, "password": pwd}
    )
    assert resp1.status_code == 201

    resp2 = await client.post(
        "/auth/register", json={"email": email, "password": pwd}
    )
    assert resp2.status_code == 409
    assert "already exists" in resp2.json()["detail"]


@pytest.mark.asyncio
async def test_password_validation(client: AsyncClient):
    email = "pass_test@example.com"

    # Too short (< 10)
    r1 = await client.post("/auth/register", json={"email": email, "password": "short"})
    assert r1.status_code == 422

    # Common password
    r2 = await client.post("/auth/register", json={"email": email, "password": "password123"})
    assert r2.status_code == 422

    # Equal to email
    r3 = await client.post("/auth/register", json={"email": email, "password": email})
    assert r3.status_code == 422


@pytest.mark.asyncio
async def test_invite_code_and_registration_disabled(client: AsyncClient):
    email = f"invite_{uuid.uuid4().hex[:8]}@example.com"

    # Require invite code
    settings.REGISTRATION_INVITE_CODE = "SECRET_INVITE_123"
    try:
        # Missing code
        r1 = await client.post(
            "/auth/register", json={"email": email, "password": "ValidPassword123!"}
        )
        assert r1.status_code == 403

        # Wrong code
        r2 = await client.post(
            "/auth/register",
            json={
                "email": email,
                "password": "ValidPassword123!",
                "invite_code": "WRONG_CODE",
            },
        )
        assert r2.status_code == 403

        # Correct code
        r3 = await client.post(
            "/auth/register",
            json={
                "email": email,
                "password": "ValidPassword123!",
                "invite_code": "SECRET_INVITE_123",
            },
        )
        assert r3.status_code == 201
    finally:
        settings.REGISTRATION_INVITE_CODE = ""

    # Registration disabled
    settings.ALLOW_REGISTRATION = False
    try:
        r4 = await client.post(
            "/auth/register",
            json={
                "email": f"disabled_{uuid.uuid4().hex[:8]}@example.com",
                "password": "ValidPassword123!",
            },
        )
        assert r4.status_code == 403
    finally:
        settings.ALLOW_REGISTRATION = True


@pytest.mark.asyncio
async def test_login_invalid_credentials_timing_and_lockout(client: AsyncClient):
    # Wrong password vs unknown email give identical response
    email = f"lockout_{uuid.uuid4().hex[:8]}@example.com"
    pwd = "ValidPassword123!"
    await client.post("/auth/register", json={"email": email, "password": pwd})

    # Unknown email
    r_unknown = await client.post(
        "/auth/login",
        json={"email": "nonexistent_random@example.com", "password": pwd},
    )
    # Wrong password
    r_wrong_pwd = await client.post(
        "/auth/login", json={"email": email, "password": "WrongPassword123!"}
    )

    assert r_unknown.status_code == 401
    assert r_wrong_pwd.status_code == 401
    assert r_unknown.json() == r_wrong_pwd.json()

    # Lockout after LOGIN_MAX_FAILURES
    settings.LOGIN_MAX_FAILURES = 3
    try:
        # Already had 1 failure for email
        await client.post(
            "/auth/login", json={"email": email, "password": "WrongPassword123!"}
        )
        await client.post(
            "/auth/login", json={"email": email, "password": "WrongPassword123!"}
        )
        # Next attempt triggers 429
        r_locked = await client.post(
            "/auth/login", json={"email": email, "password": "WrongPassword123!"}
        )
        assert r_locked.status_code == 429
        assert "Retry-After" in r_locked.headers

        # Success clears lockout once reset or allowed
        from app.cache.factory import get_cache
        from app.auth.service import get_email_hash, get_ip_hash
        cache = get_cache()
        ip_h = get_ip_hash("127.0.0.1")
        await cache.delete(f"lf:{get_email_hash(email)}:{ip_h}")
        await cache.delete(f"lf:ip:{ip_h}")

        r_ok = await client.post(
            "/auth/login", json={"email": email, "password": pwd}
        )
        assert r_ok.status_code == 200
    finally:
        settings.LOGIN_MAX_FAILURES = 5


@pytest.mark.asyncio
async def test_auth_edge_cases_and_no_secret_leaks(client: AsyncClient, caplog):
    import logging
    from sqlalchemy import select
    from app.db.models import User
    from app.db.session import get_sessionmaker

    caplog.set_level(logging.INFO)
    base_email = f"Edge_{uuid.uuid4().hex[:8]}@Example.COM"
    pwd = "SuperSecretPassword123!"

    # 1. Long password (> 128 chars) -> 422
    r_long = await client.post(
        "/auth/register",
        json={"email": base_email, "password": "a" * 129},
    )
    assert r_long.status_code == 422

    # 2. Register succeeds; duplicate with different casing -> 409
    r_ok = await client.post(
        "/auth/register",
        json={"email": base_email, "password": pwd},
    )
    assert r_ok.status_code == 201
    user_id = r_ok.json()["user"]["id"]

    r_dup_case = await client.post(
        "/auth/register",
        json={"email": base_email.lower(), "password": pwd},
    )
    assert r_dup_case.status_code == 409

    # 3. Verify plain password never appears in DB or captured logs
    async with get_sessionmaker()() as db:
        res = await db.execute(select(User).where(User.id == user_id))
        db_user = res.scalar_one()
        assert db_user.password_hash.startswith("$argon2id$")
        assert pwd not in db_user.password_hash
    assert pwd not in caplog.text

    # 4. Successful login clears failed-login counter
    settings.LOGIN_MAX_FAILURES = 3
    try:
        for _ in range(2):
            r_fail = await client.post(
                "/auth/login",
                json={"email": base_email, "password": "WrongPassword123!"},
            )
            assert r_fail.status_code == 401

        # Success clears counter
        r_login_ok = await client.post(
            "/auth/login",
            json={"email": base_email, "password": pwd},
        )
        assert r_login_ok.status_code == 200
        assert pwd not in caplog.text

        # Two more failures should NOT lock out (counter was reset)
        for _ in range(2):
            r_fail_again = await client.post(
                "/auth/login",
                json={"email": base_email, "password": "WrongPassword123!"},
            )
            assert r_fail_again.status_code == 401
    finally:
        settings.LOGIN_MAX_FAILURES = 5

    # 5. Inactive user login -> 401
    async with get_sessionmaker()() as db:
        res = await db.execute(select(User).where(User.id == user_id))
        db_user = res.scalar_one()
        db_user.is_active = False
        await db.commit()

    r_inactive = await client.post(
        "/auth/login",
        json={"email": base_email, "password": pwd},
    )
    assert r_inactive.status_code == 401

    # 6. MAX_USERS enforcement
    orig_max_users = settings.MAX_USERS
    settings.MAX_USERS = 1
    try:
        r_max = await client.post(
            "/auth/register",
            json={"email": f"over_{uuid.uuid4().hex[:8]}@example.com", "password": pwd},
        )
        assert r_max.status_code == 403
    finally:
        settings.MAX_USERS = orig_max_users


@pytest.mark.asyncio
async def test_registration_ip_rate_limit(client: AsyncClient):
    # 5 registrations per hour per client IP, 6th -> 429
    from app.cache.factory import get_cache
    from app.auth.service import get_ip_hash

    cache = get_cache()
    await cache.delete(f"reg:{get_ip_hash('127.0.0.1')}")

    for i in range(5):
        resp = await client.post(
            "/auth/register",
            json={"email": f"ipreg_{i}_{uuid.uuid4().hex[:6]}@example.com", "password": "ValidPassword123!"},
        )
        assert resp.status_code == 201

    resp_6 = await client.post(
        "/auth/register",
        json={"email": f"ipreg_6_{uuid.uuid4().hex[:6]}@example.com", "password": "ValidPassword123!"},
    )
    assert resp_6.status_code == 429
    assert "Retry-After" in resp_6.headers
