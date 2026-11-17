import datetime
import uuid
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text, select
from app.config import Settings, settings
from app.db.models import AudioUsage, User
from app.db.session import get_engine, get_sessionmaker
from app.main import app
from app.services.usage import bandwidth_guard


@pytest.mark.asyncio
async def test_health_endpoint_response_format(client):
    res = await client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert data["version"] == "1.0.0"
    assert isinstance(data["uptime_seconds"], int)
    assert data["uptime_seconds"] >= 0
    assert data["db"] == "ok"
    assert "cache" in data
    # Ensure no secrets or file paths are returned
    for key in ("secret", "token", "password", "path"):
        assert key not in str(data).lower()


@pytest.mark.asyncio
async def test_ready_endpoint_status(client, test_db_path):
    # When DB is at migration head, /ready returns 200
    res = await client.get("/ready")
    assert res.status_code == 200
    assert res.json() == {"status": "ready"}

    # Simulate outdated migration head
    engine = get_engine()
    async with engine.connect() as conn:
        await conn.execute(text("UPDATE alembic_version SET version_num = '0000_fake';"))
        await conn.commit()

    try:
        res_fail = await client.get("/ready")
        assert res_fail.status_code == 503
        assert res_fail.json() == {"status": "not_ready"}
    finally:
        from app.db.session import get_expected_migration_heads
        head = list(get_expected_migration_heads())[0]
        async with engine.connect() as conn:
            await conn.execute(text(f"UPDATE alembic_version SET version_num = '{head}';"))
            await conn.commit()


def test_production_startup_checks():
    # 1. Invalid secret length
    s1 = Settings(APP_ENV="production", HOST="127.0.0.1", APP_JWT_SECRET="short")
    with pytest.raises(ValueError, match="at least 32 characters"):
        s1.validate_production_config()

    # 2. Non-loopback host in production
    s2 = Settings(
        APP_ENV="production",
        HOST="0.0.0.0",
        APP_JWT_SECRET="valid-secret-key-that-is-at-least-32-chars-long!",
    )
    with pytest.raises(ValueError, match="HOST must be 127.0.0.1"):
        s2.validate_production_config()

    # 3. Wildcard CORS in production
    s3 = Settings(
        APP_ENV="production",
        HOST="127.0.0.1",
        APP_JWT_SECRET="valid-secret-key-that-is-at-least-32-chars-long!",
        CORS_ORIGINS="https://music.example.com,*",
    )
    with pytest.raises(ValueError, match="wildcard"):
        s3.validate_production_config()

    # 4. Valid production settings pass
    s_valid = Settings(
        APP_ENV="production",
        HOST="127.0.0.1",
        APP_JWT_SECRET="valid-secret-key-that-is-at-least-32-chars-long!",
        CORS_ORIGINS="https://music.example.com",
    )
    s_valid.validate_production_config()  # Should not raise


@pytest.mark.asyncio
async def test_graceful_shutdown_flushes_bandwidth(test_db_path):
    user_id = str(uuid.uuid4())
    today = datetime.datetime.now(datetime.timezone.utc).date()
    now = datetime.datetime.now(datetime.timezone.utc)

    # Insert user so foreign key constraint succeeds
    sm = get_sessionmaker()
    async with sm() as session:
        user = User(
            id=user_id,
            email=f"shutdown_{user_id[:6]}@example.com",
            password_hash="fakehash123",
            is_active=True,
            created_at=now,
        )
        session.add(user)
        await session.commit()

    # Record bytes into in-memory unflushed buffer
    await bandwidth_guard.record_bytes(user_id, 2048)
    assert (user_id, today) in bandwidth_guard._unflushed
    assert bandwidth_guard._unflushed[(user_id, today)] >= 2048

    # Simulate shutdown
    await bandwidth_guard.stop()

    # Verify bytes flushed to database
    async with sm() as session:
        res = await session.execute(
            select(AudioUsage.bytes).where(
                AudioUsage.user_id == user_id, AudioUsage.day == today
            )
        )
        flushed_bytes = res.scalar_one_or_none()
        assert flushed_bytes is not None
        assert flushed_bytes >= 2048
