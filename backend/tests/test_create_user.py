import os
import uuid
import pytest
from sqlalchemy import select
from app.config import settings
from app.db.models import RefreshToken, User
from app.db.session import get_sessionmaker
from app.tools.create_user import create_or_reset_user


@pytest.mark.asyncio
async def test_create_user_with_password_env(test_db_path):
    email = f"test_admin_{uuid.uuid4().hex[:6]}@example.com"
    password = "ValidSuperPassword123!"

    # Ensure registration disabled does not block tool
    orig_allow = settings.ALLOW_REGISTRATION
    settings.ALLOW_REGISTRATION = False

    try:
        code = await create_or_reset_user(
            email=email,
            password=password,
            reset_password=False,
            display_name="Admin Test",
        )
        assert code == 0

        # Verify user exists in database
        sm = get_sessionmaker()
        async with sm() as session:
            res = await session.execute(select(User).where(User.email == email))
            user = res.scalar_one_or_none()
            assert user is not None
            assert user.email == email
            assert user.display_name == "Admin Test"
            assert user.is_active is True
            assert user.password_hash != password
    finally:
        settings.ALLOW_REGISTRATION = orig_allow


@pytest.mark.asyncio
async def test_create_user_rejects_weak_password(test_db_path):
    email = f"weak_{uuid.uuid4().hex[:6]}@example.com"
    code = await create_or_reset_user(
        email=email,
        password="short",  # < 10 chars
        reset_password=False,
    )
    assert code == 1


@pytest.mark.asyncio
async def test_create_duplicate_user_without_reset_flag(test_db_path):
    email = f"dup_{uuid.uuid4().hex[:6]}@example.com"
    password = "StrongPassword12345!"

    code1 = await create_or_reset_user(email=email, password=password)
    assert code1 == 0

    # Try creating again without --reset-password
    code2 = await create_or_reset_user(email=email, password=password)
    assert code2 == 1


@pytest.mark.asyncio
async def test_reset_password_existing_and_nonexistent(test_db_path):
    email = f"reset_{uuid.uuid4().hex[:6]}@example.com"
    pw1 = "OldPassword12345!"
    pw2 = "NewPassword12345!"

    # Create initial user
    code = await create_or_reset_user(email=email, password=pw1)
    assert code == 0

    sm = get_sessionmaker()
    async with sm() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        # Add a refresh token to check revocation
        rf = RefreshToken(
            id=str(uuid.uuid4()),
            user_id=user.id,
            family_id=str(uuid.uuid4()),
            token_hash="tok_hash",
            created_at=user.created_at,
            expires_at=user.created_at,
        )
        session.add(rf)
        await session.commit()

        # Reset password
        code_reset = await create_or_reset_user(
            email=email,
            password=pw2,
            reset_password=True,
        )
        assert code_reset == 0

        # Check password hash updated and refresh tokens revoked
        async with sm() as session2:
            updated_user = (await session2.execute(select(User).where(User.email == email))).scalar_one()
            assert updated_user.password_hash != user.password_hash

            rfs = (await session2.execute(select(RefreshToken).where(RefreshToken.user_id == user.id))).scalars().all()
            assert len(rfs) == 0

    # Reset on nonexistent user
    code_nonexistent = await create_or_reset_user(
        email="nobody@example.com",
        password=pw2,
        reset_password=True,
    )
    assert code_nonexistent == 1

