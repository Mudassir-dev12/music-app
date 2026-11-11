import datetime
import uuid
import pytest
from sqlalchemy import text, select
from app.config import Settings, settings
from app.db.models import AudioUsage, RefreshToken, User
from app.db.session import check_database_at_head, get_engine, get_sessionmaker


def test_jwt_secret_validation():
    s = Settings(APP_JWT_SECRET="")
    with pytest.raises(ValueError, match="APP_JWT_SECRET must be set"):
        s.validate_jwt_secret()

    s_short = Settings(APP_JWT_SECRET="too-short-secret")
    with pytest.raises(ValueError, match="at least 32 characters"):
        s_short.validate_jwt_secret()

    s_valid = Settings(APP_JWT_SECRET="this-is-a-valid-secret-key-32-chars-long")
    s_valid.validate_jwt_secret()  # Should not raise


@pytest.mark.asyncio
async def test_database_pragmas_and_cascades(test_db_path):
    engine = get_engine()
    AsyncSessionLocal = get_sessionmaker()
    # Verify WAL mode and foreign keys
    async with engine.connect() as conn:
        res_wal = await conn.execute(text("PRAGMA journal_mode;"))
        assert res_wal.scalar().lower() == "wal"

        res_fk = await conn.execute(text("PRAGMA foreign_keys;"))
        assert res_fk.scalar() == 1

        res_busy = await conn.execute(text("PRAGMA busy_timeout;"))
        assert res_busy.scalar() == 5000

    # Test cascade delete: User -> RefreshTokens & AudioUsage
    async with AsyncSessionLocal() as session:
        user_id = str(uuid.uuid4())
        user = User(
            id=user_id,
            email=f"cascade_{user_id[:6]}@example.com",
            password_hash="dummyhash",
            is_active=True,
            created_at=datetime.datetime.now(datetime.timezone.utc),
        )
        session.add(user)

        rf = RefreshToken(
            id=str(uuid.uuid4()),
            user_id=user_id,
            family_id=str(uuid.uuid4()),
            token_hash="fake_hash_1",
            created_at=datetime.datetime.now(datetime.timezone.utc),
            expires_at=datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1),
        )
        session.add(rf)

        usage = AudioUsage(
            user_id=user_id,
            day=datetime.datetime.now(datetime.timezone.utc).date(),
            bytes=1024,
        )
        session.add(usage)
        await session.commit()

        # Delete user
        await session.delete(user)
        await session.commit()

        # Check cascaded deletion
        rf_check = await session.execute(select(RefreshToken).where(RefreshToken.user_id == user_id))
        assert rf_check.scalar_one_or_none() is None

        usage_check = await session.execute(select(AudioUsage).where(AudioUsage.user_id == user_id))
        assert usage_check.scalar_one_or_none() is None


@pytest.mark.asyncio
async def test_migration_head_check():
    engine = get_engine()
    # When head matches, check passes
    await check_database_at_head()

    # If version table points to unknown revision, check_database_at_head raises RuntimeError
    async with engine.connect() as conn:
        await conn.execute(text("UPDATE alembic_version SET version_num = 'outdated_rev';"))
        await conn.commit()

    with pytest.raises(RuntimeError, match="not at migration head"):
        await check_database_at_head()

    # Restore correct head
    async with engine.connect() as conn:
        await conn.execute(text("UPDATE alembic_version SET version_num = '0001_init';"))
        await conn.commit()
