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
    DAILY_AUDIO_MB_PER_USER: int = 68266
    MONTHLY_AUDIO_GB_GLOBAL: int = 2048

    STREAM_URL_TTL: int = 21600
    SEARCH_TTL: int = 900
    META_TTL: int = 86400
    UPSTREAM_PROXY: str = ""

    # Audio Disk Cache
    AUDIO_CACHE_DIR: str = "/var/www/music-app/data/audio_cache"
    AUDIO_CACHE_MAX_GB: int = 15

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

    # Phase 5: Download Quota & Concurrency Limits
    DAILY_DOWNLOAD_MB_PER_USER: int = 1000
    MAX_DOWNLOAD_TRACK_MB: int = 80
    MAX_CONCURRENT_DOWNLOADS_PER_USER: int = 2
    MAX_CONCURRENT_DOWNLOADS_GLOBAL: int = 4

    # Phase 6: Voice LLM Fallback (disabled by default)
    VOICE_LLM_ENABLED: bool = False
    VOICE_LLM_PROVIDER: str = "openai"
    VOICE_LLM_API_KEY: str = ""
    VOICE_LLM_MODEL: str = "gpt-4o-mini"
    VOICE_RATE_LIMIT_PER_MIN: int = 10

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

    def validate_download_config(self) -> None:
        errors = []
        for name in [
            "DAILY_DOWNLOAD_MB_PER_USER",
            "MAX_DOWNLOAD_TRACK_MB",
            "MAX_CONCURRENT_DOWNLOADS_PER_USER",
            "MAX_CONCURRENT_DOWNLOADS_GLOBAL",
        ]:
            val = getattr(self, name, None)
            if not isinstance(val, int) or isinstance(val, bool) or val <= 0:
                errors.append(f"{name} must be a positive integer (found: {val}).")
        if errors:
            raise ValueError("\n".join(errors))

    def validate_production_config(self) -> None:
        errors = []
        if not self.APP_JWT_SECRET or len(self.APP_JWT_SECRET) < 32:
            errors.append("APP_JWT_SECRET must be set and be at least 32 characters long.")
        if self.APP_ENV == "production":
            if self.HOST != "127.0.0.1":
                errors.append(f"In production mode, HOST must be 127.0.0.1 (found: {self.HOST}).")
            if self.CORS_ORIGINS:
                origins = [orig.strip() for orig in self.CORS_ORIGINS.split(",") if orig.strip()]
                if "*" in origins:
                    errors.append("In production mode, CORS_ORIGINS must not contain wildcard '*'.")
        try:
            self.validate_download_config()
        except ValueError as e:
            errors.append(str(e))
        if errors:
            raise ValueError("\n".join(errors))


settings = Settings()
