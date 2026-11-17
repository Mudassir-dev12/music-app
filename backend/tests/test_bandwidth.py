import datetime
import uuid
import pytest
from httpx import AsyncClient
from app.config import settings
from app.db.session import get_sessionmaker
from app.services.usage import BandwidthGuard, bandwidth_guard


@pytest.mark.asyncio
async def test_bandwidth_guard_daily_and_global_limits(client: AsyncClient):
    email = f"bw_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    data = reg.json()
    user_id = data["user"]["id"]
    token = data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    async with get_sessionmaker()() as db:
        # 1. Check within normal limits
        await bandwidth_guard.check_limits(user_id, db)

        # 2. Daily limit exceeded
        settings.DAILY_AUDIO_MB_PER_USER = 1  # 1 MB
        try:
            # Record 2 MB usage
            await bandwidth_guard.record_bytes(user_id, 2 * 1024 * 1024)

            with pytest.raises(Exception) as excinfo:
                await bandwidth_guard.check_limits(user_id, db)
            assert excinfo.value.status_code == 429
            assert "Daily audio" in excinfo.value.detail
            assert "Retry-After" in excinfo.value.headers
        finally:
            settings.DAILY_AUDIO_MB_PER_USER = 68266
            await bandwidth_guard.flush()

        # 3. Setting to 0 disables limit
        settings.DAILY_AUDIO_MB_PER_USER = 0
        try:
            await bandwidth_guard.check_limits(user_id, db)
        finally:
            settings.DAILY_AUDIO_MB_PER_USER = 68266

        # 4. Global monthly limit exceeded
        settings.DAILY_AUDIO_MB_PER_USER = 0
        settings.MONTHLY_AUDIO_GB_GLOBAL = 1  # 1 GB
        try:
            await bandwidth_guard.record_bytes(user_id, 2 * 1024 * 1024 * 1024)
            with pytest.raises(Exception) as excinfo_global:
                await bandwidth_guard.check_limits(user_id, db)
            assert excinfo_global.value.status_code == 503
            assert "Monthly global" in excinfo_global.value.detail
        finally:
            settings.DAILY_AUDIO_MB_PER_USER = 68266
            settings.MONTHLY_AUDIO_GB_GLOBAL = 2048
            await bandwidth_guard.flush()


@pytest.mark.asyncio
async def test_bandwidth_flush_survives_restart_and_usage_endpoint(client: AsyncClient):
    email = f"persist_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post("/auth/register", json={"email": email, "password": "ValidPassword123!"})
    token = reg.json()["access_token"]
    user_id = reg.json()["user"]["id"]
    headers = {"Authorization": f"Bearer {token}"}

    # Record 50,000 bytes
    await bandwidth_guard.record_bytes(user_id, 50000)

    # Flush to database
    await bandwidth_guard.flush()

    # Simulate restart with a brand new BandwidthGuard instance
    new_guard = BandwidthGuard()

    async with get_sessionmaker()() as db:
        persisted_today = await new_guard.get_user_today_bytes(user_id, db)
        assert persisted_today >= 50000

    # Test /me/usage endpoint
    u_resp = await client.get("/me/usage", headers=headers)
    assert u_resp.status_code == 200
    usage_data = u_resp.json()
    assert usage_data["today_bytes"] >= 50000
    assert usage_data["daily_limit_bytes"] > 0
    assert usage_data["month_global_bytes"] >= 50000
    assert usage_data["month_global_limit_bytes"] > 0
