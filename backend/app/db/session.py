import os
from typing import AsyncGenerator, Optional, Tuple
from sqlalchemy import event, text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from app.config import settings

_current_url: Optional[str] = None
engine: Optional[AsyncEngine] = None
AsyncSessionLocal: Optional[async_sessionmaker[AsyncSession]] = None


def create_engine_and_sessionmaker(
    db_url: str,
) -> Tuple[AsyncEngine, async_sessionmaker[AsyncSession]]:
    if "sqlite" in db_url and ":///" in db_url:
        path = db_url.split(":///", 1)[1]
        dir_name = os.path.dirname(path)
        if dir_name:
            os.makedirs(dir_name, exist_ok=True)
            try:
                os.chmod(dir_name, 0o700)
            except OSError:
                pass

    eng = create_async_engine(
        db_url,
        echo=False,
        future=True,
    )

    @event.listens_for(eng.sync_engine, "connect")
    def set_sqlite_pragmas(dbapi_connection, connection_record):
        if "sqlite" in db_url:
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA journal_mode=WAL;")
            cursor.execute("PRAGMA foreign_keys=ON;")
            cursor.execute("PRAGMA busy_timeout=5000;")
            cursor.execute("PRAGMA synchronous=NORMAL;")
            cursor.close()

    sm = async_sessionmaker(
        bind=eng,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )
    return eng, sm


def init_db(database_url: Optional[str] = None) -> Tuple[AsyncEngine, async_sessionmaker[AsyncSession]]:
    global _current_url, engine, AsyncSessionLocal
    url = database_url or settings.DATABASE_URL
    if engine is None or url != _current_url:
        _current_url = url
        engine, AsyncSessionLocal = create_engine_and_sessionmaker(url)
    return engine, AsyncSessionLocal


# Initial creation
init_db()


def get_engine() -> AsyncEngine:
    eng, _ = init_db()
    return eng


def get_sessionmaker() -> async_sessionmaker[AsyncSession]:
    _, sm = init_db()
    return sm


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    _, sessionmaker = init_db()
    async with sessionmaker() as session:
        try:
            yield session
        finally:
            await session.close()


def ensure_db_permissions() -> None:
    if "sqlite" in settings.DATABASE_URL:
        url = settings.DATABASE_URL
        if ":///" in url:
            path = url.split(":///", 1)[1]
            dir_name = os.path.dirname(path)
            if dir_name and os.path.exists(dir_name):
                try:
                    os.chmod(dir_name, 0o700)
                except OSError:
                    pass
            if path and os.path.exists(path):
                try:
                    os.chmod(path, 0o600)
                except OSError:
                    pass


def get_expected_migration_heads() -> set[str]:
    """Finds expected migration heads from alembic.ini or fallback to latest known."""
    try:
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        ini_path = os.path.join(backend_dir, "alembic.ini")
        if os.path.exists(ini_path):
            from alembic.config import Config
            from alembic.script import ScriptDirectory
            cfg = Config(ini_path)
            script = ScriptDirectory.from_config(cfg)
            heads = set(script.get_heads())
            if heads:
                return heads
    except Exception:
        pass
    return {"0002_user_data"}


async def check_database_at_head() -> None:
    """Verifies that the database has the latest alembic migration applied."""
    eng, _ = init_db()
    ensure_db_permissions()
    expected_heads = get_expected_migration_heads()
    async with eng.connect() as conn:
        try:
            result = await conn.execute(text("SELECT version_num FROM alembic_version LIMIT 1"))
            row = result.fetchone()
            if not row or row[0] not in expected_heads:
                raise RuntimeError(
                    f"Database is not at migration head (found: {row[0] if row else 'none'}). "
                    "Run 'python -m alembic upgrade head' first."
                )
        except Exception as e:
            if isinstance(e, RuntimeError):
                raise
            raise RuntimeError(
                f"Database migration check failed: {e}. "
                "Ensure migrations are applied with 'python -m alembic upgrade head'."
            ) from e
