# Melodia — Self-Hosted Music App (Phase 1 Foundation)

> **CRITICAL ENVIRONMENT NOTICE:** This project lives strictly inside `/var/www/music-app`. All development, virtualenvs, Node packages, caches (`.home/`, `.cache/`, `.config/`, `.local/`, `.tmp/`), SQLite data (`data/`), and backups (`backups/`) must remain inside `/var/www/music-app`. Always `source scripts/env.sh` before running any command. Never touch sibling `/var/www/*` directories or host system services.

---

## Overview

Melodia is a self-hosted music streaming application running entirely on our own VPS (no Supabase or external backend-as-a-service). Phase 1 delivers:
- A FastAPI backend (`backend/`) with its own account system (`POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /me`, `GET /me/usage`), Argon2id password hashing, HS256 access tokens, and rotating refresh tokens with reuse detection.
- A SQLite database managed via SQLAlchemy 2.x (async + `aiosqlite`) and Alembic migrations.
- Music search and track metadata via `ytmusicapi`, behind a swappable `MusicSource` interface (`sources/base.py`).
- An audio proxy (`/audio/{video_id}`) using `yt-dlp` stream resolution with single-flight locking, `httpx` streaming with HTTP `Range` (`206`) and `HEAD` support, concurrency semaphore, and a daily/monthly bandwidth guard.
- A Cache abstraction supporting Redis (when `REDIS_URL` is configured and reachable) or an in-memory LRU+TTL cache.
- A database backup CLI (`python -m app.tools.backup`).
- A minimal Expo Router + TypeScript shell (`app/`) verifying connectivity to `GET /health`.

---

## Requirements

- **Node.js** >= 20 (project-local Node `v22.23.5` is installed under `.local/node/bin`, automatically added to `PATH` by `scripts/env.sh`, satisfying both `yt-dlp` EJS `>= 22.0.0` and Expo SDK 58 `>= 22.13.0`)
- **Python** >= 3.11 (verified with Python 3.12.3)
- **SQLite** >= 3.35 (verified with SQLite 3.45.1)
- **git**

---

## Quick start

Always start by sourcing the environment guard from `/var/www/music-app`:

```bash
cd /var/www/music-app
source scripts/env.sh
```

### 1. Backend setup, migration, and run

```bash
# Virtualenv (already created at backend/.venv)
python3 -m venv backend/.venv
backend/.venv/bin/pip install -r backend/requirements.txt

# Configure backend/.env from backend/.env.example (set APP_JWT_SECRET >= 32 chars)
cp backend/.env.example backend/.env

# Apply database migrations (from backend/ or with PYTHONPATH=backend)
cd backend
.venv/bin/python -m alembic upgrade head

# Start the API (single worker, 127.0.0.1 only)
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8610
```

### 2. Backend automated tests & smoke script

```bash
cd /var/www/music-app
source scripts/env.sh

# Unit & integration tests (offline, mocked YouTube/HTTP, throwaway SQLite)
cd backend && .venv/bin/pytest -q

# Live smoke test (uses throwaway DB in .tmp/ and a free port)
cd /var/www/music-app && bash scripts/smoke.sh
```

### 3. Expo web shell

```bash
cd /var/www/music-app
source scripts/env.sh
cd app
cp .env.example .env
npx tsc --noEmit
npx expo export --platform web
```

---

## Environment variables

### Backend (`backend/.env`, see `backend/.env.example`)

| Variable | Default | Description |
|---|---|---|
| `APP_ENV` | `production` | `development` or `production` |
| `HOST` | `127.0.0.1` | Bind address (keep `127.0.0.1` behind reverse proxy) |
| `PORT` | `8610` | Listen port |
| `CORS_ORIGINS` | `""` | Comma-separated allowed origins (never `*` in production) |
| `DATABASE_URL` | `sqlite+aiosqlite:///./data/music.db` | SQLAlchemy async DB URL |
| `APP_JWT_SECRET` | *(required)* | Signing key for access JWTs (minimum 32 chars; startup fails fast if missing/short) |
| `APP_JWT_SECRET_PREVIOUS` | `""` | Optional previous JWT secret for zero-downtime key rotation (verify only) |
| `JWT_ISSUER` | `music-app` | JWT `iss` claim |
| `JWT_AUDIENCE` | `music-app-api` | JWT `aud` claim |
| `ACCESS_TOKEN_TTL_MIN` | `15` | Access token lifetime in minutes |
| `REFRESH_TOKEN_TTL_DAYS` | `30` | Refresh token lifetime in days |
| `REFRESH_REUSE_GRACE_SECONDS` | `10` | Grace window before replayed refresh token revokes whole token family |
| `ALLOW_REGISTRATION` | `true` | Enable/disable `POST /auth/register` |
| `REGISTRATION_INVITE_CODE` | `""` | If non-empty, `/auth/register` requires matching `invite_code` |
| `MAX_USERS` | `100` | Maximum registered users (`0` = unlimited) |
| `ARGON2_MEMORY_KB` | `47104` | Argon2id memory parameter (KB) |
| `ARGON2_TIME_COST` | `1` | Argon2id iterations |
| `ARGON2_PARALLELISM` | `1` | Argon2id parallelism |
| `HASH_CONCURRENCY` | `2` | Max concurrent Argon2 hashes via asyncio semaphore |
| `LOGIN_MAX_FAILURES` | `5` | Failed login threshold before `429` lockout (IP-only cap is `6x`) |
| `LOGIN_WINDOW_SECONDS` | `900` | Lockout window in seconds |
| `TRUST_FORWARDED_FOR` | `false` | Read first `X-Forwarded-For` IP only when behind trusted reverse proxy |
| `REDIS_URL` | `""` | Optional Redis URL; falls back to in-memory cache if unset or unreachable |
| `MAX_CONCURRENT_STREAMS` | `20` | Max simultaneous `/audio` streams (`429` when full) |
| `RATE_LIMIT_PER_MIN` | `120` | Per-user authenticated requests per minute |
| `DAILY_AUDIO_MB_PER_USER` | `1500` | Daily per-user `/audio` cap in MB (`0` = unlimited) |
| `MONTHLY_AUDIO_GB_GLOBAL` | `1500` | Global monthly `/audio` cap in GB (~30% of shared 5 TB VPS quota; `0` = unlimited) |
| `STREAM_URL_TTL` | `3000` | Cached upstream stream URL TTL in seconds |
| `SEARCH_TTL` | `900` | Cached search results TTL in seconds |
| `META_TTL` | `86400` | Cached track metadata TTL in seconds |

### Frontend (`app/.env`, see `app/.env.example`)

| Variable | Default | Description |
|---|---|---|
| `EXPO_PUBLIC_API_URL` | `http://127.0.0.1:8610` | Backend API base URL |
| `EXPO_PUBLIC_APP_NAME` | `Melodia` | Application display name |

---

## Architecture

The Expo client communicates with the FastAPI backend over HTTPS/HTTP (`Authorization: Bearer <access_token>` and `Range` headers for audio seeking). The FastAPI app handles request-ID tagging and structured logging (redacting secrets), authenticates JWT access tokens via `get_current_user`, enforces per-user fixed-window rate limits, serves metadata/search via `YTMusicSource` (cached in Redis or memory), and proxies audio bytes from upstream streams resolved by `yt-dlp` through a single-flight coordinator and concurrency semaphore while metering streamed bytes in memory and flushing them periodically to SQLite.

**Request flow:**
1. `Client` -> `RequestLoggingMiddleware` (assigns `X-Request-ID`, logs route/status/latency/hashed user ID)
2. `GET /health` -> cheap `SELECT 1` + cache backend status (public, unthrottled)
3. `/auth/*` -> Argon2id hash/verify (bounded by `HASH_CONCURRENCY` semaphore), login brute-force counters, opaque rotating refresh tokens stored as SHA-256 hashes in SQLite
4. `/search`, `/track/{video_id}` -> `get_current_user` -> `rate_limiter` -> cache lookup -> `YTMusicSource` (`anyio.to_thread`)
5. `/audio/{video_id}` -> `get_current_user` -> `rate_limiter` -> `validate_video_id` -> `bandwidth_guard.check_limits` -> `MAX_CONCURRENT_STREAMS` semaphore -> `StreamResolver.get_stream` (single-flight + `yt-dlp`) -> `httpx` streaming proxy (`200`/`206`, `403/404/410` single re-resolve retry) -> record sent bytes in `finally`.

---

## Legal note

Audio extraction from YouTube is intended strictly for private/educational use and is not compliant with YouTube's Terms of Service for public release. The backend isolates music metadata and stream resolution behind the [`MusicSource`](backend/app/sources/base.py) interface specifically so that a licensed catalog/stream provider can replace `YTMusicSource` in the future without changing the API routes, auth, caching, or client.

---

## Operating notes

- **Single uvicorn worker:** Because the in-memory cache, `HASH_CONCURRENCY` semaphore, `MAX_CONCURRENT_STREAMS` semaphore, single-flight map, and in-memory bandwidth counters are per-process, **always run a single uvicorn worker** (`--workers 1`).
- **Bandwidth guard:** The VPS shares a 5 TB/month transfer quota across multiple projects. `MONTHLY_AUDIO_GB_GLOBAL` defaults to `1500` GB (~30%). Streamed bytes are accumulated in memory and flushed to `audio_usage` every 15 seconds and on clean shutdown. A warning is logged once global usage crosses 80% of the monthly cap.
- **Backups:** Run `cd /var/www/music-app && source scripts/env.sh && backend/.venv/bin/python -m app.tools.backup` to create a consistent online SQLite snapshot under `./backups/music-YYYYmmdd-HHMMSS.db` (mode `600`), pruning to the newest 7 snapshots by default (`--keep N`).
- **Moving to Postgres later:** Database access uses SQLAlchemy 2.x async and Alembic (`render_as_batch=True`). Update `DATABASE_URL` to a `postgresql+asyncpg://...` URL, install `asyncpg` in `backend/.venv`, and run `alembic upgrade head` (note: update `audio_usage` upsert SQL in `services/usage.py` if dialect-specific adjustments are desired, though `ON CONFLICT (user_id, day) DO UPDATE` is standard SQLite/PostgreSQL syntax).

---

## Manual steps for the owner

1. **Generate `APP_JWT_SECRET`:**
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(48))"
   ```
2. **Create `backend/.env` and choose an invite code:**
   ```bash
   cp /var/www/music-app/backend/.env.example /var/www/music-app/backend/.env
   # Edit backend/.env: set APP_JWT_SECRET, REGISTRATION_INVITE_CODE, and CORS_ORIGINS
   chmod 600 /var/www/music-app/backend/.env
   ```
3. **Run Alembic migrations on the real database:**
   ```bash
   cd /var/www/music-app && source scripts/env.sh
   cd backend && .venv/bin/python -m alembic upgrade head
   ```
4. **Schedule daily SQLite backups via cron (do not edit system crontabs inside the project):**
   Add this line to the owner's crontab (`crontab -e`):
   ```cron
   15 3 * * * cd /var/www/music-app && . scripts/env.sh && backend/.venv/bin/python -m app.tools.backup
   ```
5. **Configure reverse proxy (Nginx) and TLS:**
   Proxy your domain over HTTPS to `http://127.0.0.1:8610`, pass `X-Forwarded-For` / `X-Real-IP` (and set `TRUST_FORWARDED_FOR=true` in `backend/.env` if proxied), and disable response buffering (`proxy_buffering off;`) for `/audio/`.
6. **Confirm port `8610` is not reachable from outside:**
   Verify `ss -tlnp | grep 8610` shows `127.0.0.1:8610` only (not `0.0.0.0:8610`) and firewall (`ufw status`) blocks direct external access to `8610`.
7. **YouTube `yt-dlp` datacenter IP notice:**
   Project-local `.local/node` is `v22.23.5` (supported by `yt-dlp` `EJS`). However, YouTube may return `"Sign in to confirm you're not a bot"` or `403` on datacenter IPs. For private use if blocked by YouTube, consider routing `yt-dlp` through a residential egress/VPN or providing a cookies file outside git.
