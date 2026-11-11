import asyncio
from concurrent.futures import ThreadPoolExecutor
import argon2
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, VerificationError, InvalidHashError
from app.config import settings

# Thread pool for CPU-bound hashing guarded by semaphore
_hash_executor = ThreadPoolExecutor(max_workers=4)
_hash_semaphore = asyncio.Semaphore(settings.HASH_CONCURRENCY)

COMMON_PASSWORDS = {
    "1234567890",
    "password123",
    "password1234",
    "qwertyuiop",
    "12345678901",
    "123456789012",
    "admin123456",
    "administrator",
    "welcome1234",
    "welcome12345",
    "letmein1234",
    "iloveyou1234",
}


def get_hasher() -> PasswordHasher:
    return PasswordHasher(
        time_cost=settings.ARGON2_TIME_COST,
        memory_cost=settings.ARGON2_MEMORY_KB,
        parallelism=settings.ARGON2_PARALLELISM,
        type=argon2.Type.ID if hasattr(argon2, "Type") else 2,
    )


# Precompute a dummy hash for constant-time comparison on unknown email
_dummy_hasher = PasswordHasher(
    time_cost=settings.ARGON2_TIME_COST,
    memory_cost=settings.ARGON2_MEMORY_KB,
    parallelism=settings.ARGON2_PARALLELISM,
)
_DUMMY_HASH = _dummy_hasher.hash("dummy_constant_time_password_123")


def validate_password_strength(password: str, email: str | None = None) -> None:
    if len(password) < 10:
        raise ValueError("Password must be at least 10 characters long.")
    if len(password) > 128:
        raise ValueError("Password must not exceed 128 characters.")
    if email and password.strip().lower() == email.strip().lower():
        raise ValueError("Password cannot be identical to the email address.")
    if password.lower() in COMMON_PASSWORDS:
        raise ValueError("Password is too common and insecure.")


def _hash_sync(password: str) -> str:
    hasher = get_hasher()
    return hasher.hash(password)


async def hash_password(password: str) -> str:
    async with _hash_semaphore:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(_hash_executor, _hash_sync, password)


def _verify_sync(password: str, hashed: str) -> tuple[bool, bool]:
    hasher = get_hasher()
    try:
        valid = hasher.verify(hashed, password)
        needs_rehash = hasher.check_needs_rehash(hashed)
        return valid, needs_rehash
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False, False


async def verify_password(password: str, hashed: str) -> tuple[bool, bool]:
    async with _hash_semaphore:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(_hash_executor, _verify_sync, password, hashed)


async def verify_dummy() -> None:
    """Run dummy verify for timing attack protection when email is not found."""
    await verify_password("dummy_password", _DUMMY_HASH)
