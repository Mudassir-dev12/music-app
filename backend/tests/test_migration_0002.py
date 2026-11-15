import os
import tempfile
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text


def test_migration_0002_upgrade_and_downgrade():
    from app.config import settings
    temp_dir = tempfile.mkdtemp()
    db_file = os.path.join(temp_dir, "migration_test.db")
    async_db_url = f"sqlite+aiosqlite:///{db_file}"
    sync_db_url = f"sqlite:///{db_file}"

    orig_url = settings.DATABASE_URL
    settings.DATABASE_URL = async_db_url

    try:
        alembic_cfg = Config(os.path.abspath(os.path.join(os.path.dirname(__file__), "../alembic.ini")))
        alembic_cfg.set_main_option("sqlalchemy.url", async_db_url)

        # 1. Migrate to 0001_init first
        command.upgrade(alembic_cfg, "0001_init")

        # 2. Insert dummy Phase 1/2 data into users, refresh_tokens, audio_usage
        engine = create_engine(sync_db_url)
        with engine.begin() as conn:
            conn.execute(
                text(
                    "INSERT INTO users (id, email, password_hash, display_name, is_active, created_at) "
                    "VALUES ('user-1', 'user1@example.com', 'hash123', 'User One', 1, '2026-01-01 00:00:00')"
                )
            )
            conn.execute(
                text(
                    "INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, created_at, expires_at) "
                    "VALUES ('tok-1', 'user-1', 'fam-1', 'hash1', '2026-01-01 00:00:00', '2026-02-01 00:00:00')"
                )
            )
            conn.execute(
                text(
                    "INSERT INTO audio_usage (user_id, day, bytes) "
                    "VALUES ('user-1', '2026-01-01', 1024)"
                )
            )

        # 3. Upgrade to 0002_user_data (must succeed with existing data!)
        command.upgrade(alembic_cfg, "0002_user_data")

        # 4. Verify all new tables and columns exist
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        expected_new = {"tracks", "play_history", "liked_tracks", "playlists", "playlist_tracks"}
        assert expected_new.issubset(set(tables))

        # Verify users data is unchanged
        with engine.begin() as conn:
            row = conn.execute(text("SELECT email FROM users WHERE id = 'user-1'")).fetchone()
            assert row is not None
            assert row[0] == "user1@example.com"

        # 5. Downgrade back to 0001_init
        command.downgrade(alembic_cfg, "0001_init")

        inspector = inspect(engine)
        tables_after_downgrade = inspector.get_table_names()
        for t in expected_new:
            assert t not in tables_after_downgrade
        assert "users" in tables_after_downgrade

        # Verify users data preserved
        with engine.begin() as conn:
            row = conn.execute(text("SELECT email FROM users WHERE id = 'user-1'")).fetchone()
            assert row is not None
            assert row[0] == "user1@example.com"

        # 6. Re-upgrade to head
        command.upgrade(alembic_cfg, "head")
        inspector = inspect(engine)
        assert expected_new.issubset(set(inspector.get_table_names()))

        engine.dispose()
    finally:
        settings.DATABASE_URL = orig_url
        try:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)
        except Exception:
            pass
