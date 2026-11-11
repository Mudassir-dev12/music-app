import asyncio
import os
import secrets
import tempfile
import pytest
from httpx import ASGITransport, AsyncClient
from alembic import command
from alembic.config import Config
from app.config import settings

# Force fast test settings
settings.APP_ENV = "development"
settings.APP_JWT_SECRET = "test-secret-key-that-is-at-least-32-chars-long!"
settings.APP_JWT_SECRET_PREVIOUS = "previous-test-secret-that-is-32-chars-long!"
settings.ARGON2_MEMORY_KB = 512
settings.ARGON2_TIME_COST = 1
settings.ARGON2_PARALLELISM = 1
settings.RATE_LIMIT_PER_MIN = 120
settings.DAILY_AUDIO_MB_PER_USER = 1500
settings.MONTHLY_AUDIO_GB_GLOBAL = 1500


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
def test_db_path():
    temp_dir = tempfile.mkdtemp()
    db_file = os.path.join(temp_dir, "test.db")
    settings.DATABASE_URL = f"sqlite+aiosqlite:///{db_file}"
    from app.db.session import init_db
    init_db(settings.DATABASE_URL)

    # Run alembic migrations
    alembic_cfg = Config(os.path.abspath(os.path.join(os.path.dirname(__file__), "../alembic.ini")))
    alembic_cfg.set_main_option("sqlalchemy.url", settings.DATABASE_URL)
    command.upgrade(alembic_cfg, "head")

    yield db_file

    if os.path.exists(temp_dir):
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)


@pytest.fixture(autouse=True)
async def reset_cache():
    from app.cache.factory import get_cache
    cache = get_cache()
    if hasattr(cache, "_cache"):
        cache._cache.clear()


@pytest.fixture
async def client(test_db_path):
    from app.main import app
    from app.cache.factory import init_cache
    await init_cache()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac
