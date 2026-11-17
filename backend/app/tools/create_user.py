import argparse
import asyncio
import datetime
import getpass
import os
import sys
import uuid
from sqlalchemy import delete, select
from app.auth.passwords import hash_password, validate_password_strength
from app.db.models import RefreshToken, User
from app.db.session import get_sessionmaker


async def create_or_reset_user(
    email: str,
    password: str,
    reset_password: bool = False,
    display_name: str | None = None,
) -> int:
    normalized_email = email.strip().lower()

    try:
        validate_password_strength(password, normalized_email)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    sm = get_sessionmaker()
    async with sm() as session:
        result = await session.execute(
            select(User).where(User.email == normalized_email)
        )
        existing_user = result.scalar_one_or_none()

        if reset_password:
            if not existing_user:
                print(
                    f"Error: User with email '{normalized_email}' does not exist.",
                    file=sys.stderr,
                )
                return 1

            pwd_hash = await hash_password(password)
            existing_user.password_hash = pwd_hash
            # Revoke existing refresh tokens on password reset
            await session.execute(
                delete(RefreshToken).where(RefreshToken.user_id == existing_user.id)
            )
            await session.commit()
            print(f"Password reset for user: {existing_user.id} ({existing_user.email})")
            return 0
        else:
            if existing_user:
                print(
                    f"Error: User with email '{normalized_email}' already exists. Use --reset-password to update.",
                    file=sys.stderr,
                )
                return 1

            pwd_hash = await hash_password(password)
            now = datetime.datetime.now(datetime.timezone.utc)
            new_user = User(
                id=str(uuid.uuid4()),
                email=normalized_email,
                password_hash=pwd_hash,
                display_name=display_name.strip() if display_name else None,
                is_active=True,
                created_at=now,
                last_login_at=now,
            )
            session.add(new_user)
            await session.commit()
            print(f"User created: {new_user.id} ({new_user.email})")
            return 0


def main():
    parser = argparse.ArgumentParser(
        description="Melodia CLI tool to create or reset a user account."
    )
    parser.add_argument(
        "--email",
        type=str,
        required=True,
        help="Email address for the user account",
    )
    parser.add_argument(
        "--reset-password",
        action="store_true",
        help="Reset password for an existing user account",
    )
    parser.add_argument(
        "--password-env",
        type=str,
        default=None,
        help="Environment variable name containing the password for non-interactive use",
    )
    parser.add_argument(
        "--display-name",
        type=str,
        default=None,
        help="Optional display name for the user",
    )

    args = parser.parse_args()

    # Password acquisition: NEVER as a command-line argument
    if args.password_env:
        password = os.environ.get(args.password_env)
        if not password:
            print(
                f"Error: Environment variable '{args.password_env}' is not set or empty.",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        try:
            password = getpass.getpass("Password: ")
            confirm = getpass.getpass("Confirm password: ")
        except (KeyboardInterrupt, EOFError):
            print("\nAborted.", file=sys.stderr)
            sys.exit(1)

        if password != confirm:
            print("Error: Passwords do not match.", file=sys.stderr)
            sys.exit(1)

    code = asyncio.run(
        create_or_reset_user(
            email=args.email,
            password=password,
            reset_password=args.reset_password,
            display_name=args.display_name,
        )
    )
    sys.exit(code)


if __name__ == "__main__":
    main()
