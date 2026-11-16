import os
from typing import List
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    APP_ENV: str = "production"
    HOST: str = "127.0.0.1"
    PORT: int = 8610
    CORS_ORIGINS: str = ""

    DATABASE_URL: str = "sqlite+aiosqlite:///./data/music.db"

    APP_JWT_SECRET: str = ""
    APP_JWT_SECRET_PREVIOUS: str = ""
    JWT_ISSUER: str = "music-app"
    JWT_AUDIENCE: str = "music-app-api"
    ACCESS_TOKEN_TTL_MIN: int = 15
    REFRESH_TOKEN_TTL_DAYS: int = 30
    REFRESH_REUSE_GRACE_SECONDS: int = 10
    AUDIO_TICKET_TTL_SECONDS: int = 7200

    ALLOW_REGISTRATION: bool = True
    REGISTRATION_INVITE_CODE: str = ""
    MAX_USERS: int = 100

    ARGON2_MEMORY_KB: int = 47104
    ARGON2_TIME_COST: int = 1
    ARGON2_PARALLELISM: int = 1
    HASH_CONCURRENCY: int = 2

    LOGIN_MAX_FAILURES: int = 5
    LOGIN_WINDOW_SECONDS: int = 900
    TRUST_FORWARDED_FOR: bool = False

    REDIS_URL: str = ""

    MAX_CONCURRENT_STREAMS: int = 20
    RATE_LIMIT_PER_MIN: int = 120
    DAILY_AUDIO_MB_PER_USER: int = 1500
    MONTHLY_AUDIO_GB_GLOBAL: int = 1500

    STREAM_URL_TTL: int = 3000
    SEARCH_TTL: int = 900
    META_TTL: int = 86400

    # Phase 3: User Data Limits
    MAX_PLAYLISTS_PER_USER: int = 200
    MAX_TRACKS_PER_PLAYLIST: int = 5000
    HISTORY_MAX_ITEMS_PER_USER: int = 10000
    HISTORY_RETENTION_DAYS: int = 365

    # Phase 4: Discovery, Upstream Limiter & Cache TTLs
    YTMUSIC_LOCATION: str = "US"
    YTMUSIC_LANGUAGE: str = "en"
    YTM_MAX_CONCURRENT_UPSTREAM: int = 4
    YTM_MAX_UPSTREAM_PER_MIN: int = 60
    TTL_HOME: int = 1800
    TTL_CHARTS: int = 3600
    TTL_MOODS: int = 86400
    TTL_ALBUM: int = 21600
    TTL_ARTIST: int = 21600
    TTL_PLAYLIST: int = 3600
    TTL_LYRICS: int = 604800
    TTL_SUGGEST: int = 600
    TTL_RADIO: int = 900
    STALE_EXTRA_TTL: int = 86400

    @property
    def cors_origins_list(self) -> List[str]:
        if not self.CORS_ORIGINS:
            return []
        origins = [orig.strip() for orig in self.CORS_ORIGINS.split(",") if orig.strip()]
        if self.APP_ENV == "production" and "*" in origins:
            raise ValueError("Wildcard '*' CORS origin is not permitted in production mode.")
        return origins

    def validate_jwt_secret(self) -> None:
        if not self.APP_JWT_SECRET or len(self.APP_JWT_SECRET) < 32:
            raise ValueError(
                "APP_JWT_SECRET must be set and be at least 32 characters long. "
                "Startup aborted."
            )


settings = Settings()
