# Melodia — Self-Hosted Music App (Phase 3)

> **Windows development notice:** This project is developed on Windows. The Flutter client is in `client/`. The FastAPI backend is in `backend/`. Use `python` (not `python3`) on Windows.

---

## Overview

Melodia is a self-hosted music streaming application running entirely on our own server (no Supabase or external backend-as-a-service).
- **Phase 1:** FastAPI backend (`backend/`), SQLite + Alembic, Argon2id accounts, HS256 JWT + rotating SHA-256 refresh tokens, `ytmusicapi` search/track metadata behind `MusicSource`, `yt-dlp` + `httpx` Range audio proxy, Redis/memory cache, per-user rate limit, bandwidth guard, and online SQLite backup CLI.
- **Phase 2:** Signed short-lived audio tickets (`POST /audio/{video_id}/ticket`), Flutter client (`client/`) with Apple Music-style design system, Riverpod state management, go_router navigation, just_audio + audio_service player, responsive phone/tablet/desktop layouts, full Now Playing + Queue panel, and theme selector.
- **Phase 3:** User data (no sign-in version) — Play history, likes, playlists, Library, Liked Songs, History, Settings screen, offline history outbox with pure-Dart RFC-4122 v4 UUID generator, and silent login via `SilentAuthStrategy` with release-mode safety guard.

---

## Security & Silent Login Notice (Phase 3–7)

During active development phases (Phases 3–7), interactive sign-in screens are paused to accelerate feature development.
- **The backend remains strictly multi-user and token-authenticated.** Every table is keyed by `user_id`, and endpoints enforce resource ownership (returning 404 for resources owned by others). **There is NO auth-bypass switch.**
- The client authenticates silently as a built-in account via `SilentAuthStrategy` using values supplied through `--dart-define` or `client/dart_defines.json` (which is **strictly gitignored**).
- **Safety Guard:** Release builds will refuse to start with `SilentAuthStrategy` unless explicitly opted-in with `--dart-define=ALLOW_SILENT_LOGIN_IN_RELEASE=true`.
- **Public Deployment Warning:** Never deploy release builds containing hardcoded `--dart-define` credentials to a publicly accessible server. Anyone with access to the client binary/web bundle could extract the compiled-in credentials. Multi-user sign-in screens and public account management return in Phase 8.

---

## Requirements

- **Flutter** >= 3.47.9 / Dart >= 3.13.7 (stable channel)
- **Python** >= 3.11 (Windows: use `python`, not `python3`)
- **SQLite** >= 3.35
- **git**
- Android SDK for Android builds (Android emulator or USB device)
- Xcode on macOS for iOS builds

---

## Quick start

### 1. Backend setup, migration, and run

```powershell
# Windows: create virtualenv and install deps
python -m venv backend\.venv
backend\.venv\Scripts\pip install -r backend\requirements.txt

# Configure backend/.env from backend/.env.example (set APP_JWT_SECRET >= 32 chars)
copy backend\.env.example backend\.env

# Apply database migrations
cd backend
.venv\Scripts\python -m alembic upgrade head

# Start the API (single worker, 127.0.0.1 only)
.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8610
```

### 2. Backend automated tests & smoke script

```powershell
cd backend
.venv\Scripts\pytest -q
```

### 3. Flutter Client

```powershell
cd client

# Fetch dependencies
flutter pub get

# Run on Windows desktop
flutter run -d windows

# Run on Android emulator (make sure one is running)
flutter run

# Run as web (Chrome required; not available on all machines)
# flutter run -d chrome --web-port 8611
```

---

## Flutter Client

The Flutter client lives in `client/`. It targets **Android, iOS, and Web**.

### Running locally

| Command | Notes |
|---|---|
| `flutter run -d windows` | Windows desktop app (always available on Windows dev machines) |
| `flutter run` | Android emulator / USB device |
| `flutter run -d chrome --web-port 8611` | Web (requires Chrome to be installed) |
| `flutter analyze` | Static analysis (from `client/`) |
| `flutter test` | Unit & widget tests |

> **Note:** Chrome is not available on all development machines. Use `-d windows` for quick iteration. Web builds are possible via `flutter build web`.

### Build commands

```bash
# Release web build
flutter build web --release \
  --dart-define=API_URL=http://your-server:8610 \
  --dart-define=APP_NAME=Melodia \
  --no-web-resources-cdn

# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release \
  --dart-define=API_URL=http://your-server:8610 \
  --dart-define=APP_NAME=Melodia
```

### `--dart-define` options

| Define | Default (web) | Default (non-web) | Description |
|---|---|---|---|
| `API_URL` | `http://127.0.0.1:8610` | `http://10.0.2.2:8610` | Backend API base URL |
| `APP_NAME` | `Melodia` | `Melodia` | Application display name |

> **Note:** `10.0.2.2` is the Android emulator loopback to the host machine. For physical devices or production, replace with the actual server address.

### Application ID

The application ID is currently `app.melodia`. **Change this to your own reverse-domain ID before publishing to app stores** (edit `client/android/app/build.gradle` and `client/ios/Runner.xcodeproj`).

### CORS

The backend `CORS_ORIGINS` must include the Flutter web dev port:

```
CORS_ORIGINS=http://localhost:8611,http://127.0.0.1:8611
```

For production, replace with your actual domain(s).

### Project structure

```
client/
  lib/
    core/
      config.dart          # API URL & app name from --dart-define
      result.dart          # Result<T> sealed class
      platform/
        media_session.dart       # Conditional import entry point
        media_session_stub.dart  # No-op for Android/iOS/Windows
        media_session_web.dart   # Web MediaSession API via package:web
    theme/
      tokens.dart          # MelodiaTokens ThemeExtension (colours, type, spacing)
      app_theme.dart       # ThemeData for dark + light modes
      theme_controller.dart # Riverpod Notifier, persists to SharedPreferences
    main.dart              # Entrypoint — ProviderScope + MelodiaApp
    app.dart               # Root MaterialApp (placeholder, expanded in later steps)
  tool/
    check_platform_imports.sh  # CI: reject dart:io/dart:html outside platform/
    check_literals.sh          # CI: reject raw Color/Colors/fontSize in lib/ui/
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
| `AUDIO_TICKET_TTL_SECONDS` | `7200` | Signed `/audio/{video_id}?t=` ticket lifetime in seconds |
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
| `MAX_PLAYLISTS_PER_USER` | `200` | Maximum playlists a user can create (`409` on limit) |
| `MAX_TRACKS_PER_PLAYLIST` | `5000` | Maximum tracks per playlist (`409` on limit) |
| `HISTORY_MAX_ITEMS_PER_USER` | `10000` | Play history items retained per user |
| `HISTORY_RETENTION_DAYS` | `365` | Play history retention period in days |

---

## API Endpoints (Phase 3)

All `/me/*` routes require a valid Bearer access token (`Authorization: Bearer <access_token>`).

### History
| Method | Path | Description |
|---|---|---|
| `POST` | `/me/history` | Record played track with `client_event_id` idempotency (201 created or 200 if already logged); server resolves and caches track metadata |
| `GET` | `/me/history` | Cursor-paginated listening history (`?limit=50&cursor=...`) |
| `GET` | `/me/recent` | Distinct recent tracks (`?limit=20`) |
| `DELETE` | `/me/history/{id}` | Delete a single history item (204) |
| `DELETE` | `/me/history` | Clear entire listening history (204) |

### Likes
| Method | Path | Description |
|---|---|---|
| `PUT` | `/me/likes/{video_id}` | Like a track (204; server resolves track metadata from music source if not yet cached; 502 on upstream failure; client-supplied metadata ignored) |
| `DELETE` | `/me/likes/{video_id}` | Unlike a track (204) |
| `GET` | `/me/likes` | Cursor-paginated liked tracks (`?limit=50&cursor=...`) |
| `GET` | `/me/likes/ids` | All liked video IDs for quick client-side heart state |

### Playlists
| Method | Path | Description |
|---|---|---|
| `POST` | `/me/playlists` | Create a playlist (`name`, optional `description`; 201 created, 409 if `MAX_PLAYLISTS_PER_USER` reached) |
| `GET` | `/me/playlists` | List user's playlists with computed `track_count`, `duration_seconds`, `cover_thumbnails` |
| `GET` | `/me/playlists/{id}` | Get playlist detail with cursor-paginated tracks (404 if not found or unowned) |
| `PATCH` | `/me/playlists/{id}` | Update playlist name or description (404 if not found or unowned) |
| `DELETE` | `/me/playlists/{id}` | Delete playlist (204) |
| `POST` | `/me/playlists/{id}/tracks` | Append tracks to playlist (`video_ids: List[str]`, duplicates skipped; 409 if `MAX_TRACKS_PER_PLAYLIST` reached) |
| `DELETE` | `/me/playlists/{id}/tracks/{video_id}` | Remove track from playlist and renumber positions (204) |
| `PUT` | `/me/playlists/{id}/tracks/reorder` | Reorder playlist tracks (`video_ids: List[str]` in new order; 204, also available at `/me/playlists/{id}/order`) |

---

## Architecture

The Flutter client communicates with the FastAPI backend over HTTPS/HTTP (`Authorization: Bearer <access_token>` and `Range` headers for audio seeking). The FastAPI app handles request-ID tagging and structured logging, authenticates JWT access tokens via `get_current_user`, enforces per-user fixed-window rate limits, serves metadata/search via `YTMusicSource` (cached in Redis or memory), and proxies audio bytes from upstream streams resolved by `yt-dlp` through a single-flight coordinator and concurrency semaphore while metering streamed bytes in memory and flushing them periodically to SQLite.

**Request flow:**
1. `Client` -> `RequestLoggingMiddleware` (assigns `X-Request-ID`, logs route/status/latency/hashed user ID)
2. `GET /health` -> cheap `SELECT 1` + cache backend status (public, unthrottled)
3. `/auth/*` -> Argon2id hash/verify (bounded by `HASH_CONCURRENCY` semaphore), login brute-force counters, opaque rotating refresh tokens stored as SHA-256 hashes in SQLite
4. `/search`, `/track/{video_id}` -> `get_current_user` -> `rate_limiter` -> cache lookup -> `YTMusicSource` (`anyio.to_thread`)
5. `/audio/{video_id}/ticket` -> `get_current_user` -> `rate_limiter` -> issues short-lived (`AUDIO_TICKET_TTL_SECONDS`) `HS256` JWT scoped to `sub`, `vid`, `typ="audio"`.
6. `/audio/{video_id}` (`GET`/`HEAD`) -> accepts Bearer access token OR `?t=<ticket>` -> `rate_limiter` -> `validate_video_id` -> `bandwidth_guard.check_limits` -> `MAX_CONCURRENT_STREAMS` semaphore -> `StreamResolver.get_stream` (single-flight + `yt-dlp`) -> `httpx` streaming proxy (`200`/`206`, `Referrer-Policy: no-referrer`, `403/404/410` single re-resolve retry) -> record sent bytes in `finally`.

### Flutter Client Design System & Player Architecture

- **Design system (`client/lib/theme/`):** Typed light and dark tokens (`tokens.dart` as `MelodiaTokens` ThemeExtension), `AppTheme` with Material 3 dark/light ThemeData, `ThemeController` (Riverpod AsyncNotifier, persisted to SharedPreferences; `system | light | dark`), and responsive breakpoints (`phone < 768`, `tablet 768–1023`, `desktop >= 1024`).
- **Audio ticket flow:** Browsers cannot attach `Authorization` headers to `<audio src>` requests. The client calls `POST /audio/{video_id}/ticket` with its Bearer access token (kept in memory) and plays `/audio/{video_id}?t=<ticket>`, caching tickets until 5 minutes before expiry.
- **Refresh Token Storage Trade-off (Web):** On web platforms, `flutter_secure_storage` falls back to browser storage (localStorage). This is acceptable for a first version, provided strict XSS prevention and sanitization are maintained. In a future production iteration, an `httpOnly` secure cookie for the refresh token would provide defense-in-depth against client-side script inspection.
- **Player:** `just_audio` + `audio_service` for cross-platform playback with lock-screen controls. Web MediaSession API access via conditional imports (`lib/core/platform/`).
- **State management:** Riverpod providers throughout; `Result<T>` sealed class for typed error handling.

---

## Legal note

Audio extraction from YouTube is intended strictly for private/educational use and is not compliant with YouTube's Terms of Service for public release. The backend isolates music metadata and stream resolution behind the [`MusicSource`](backend/app/sources/base.py) interface specifically so that a licensed catalog/stream provider can replace `YTMusicSource` in the future without changing the API routes, auth, caching, or client.

---

## Operating notes

- **Single uvicorn worker:** Because the in-memory cache, `HASH_CONCURRENCY` semaphore, `MAX_CONCURRENT_STREAMS` semaphore, single-flight map, and in-memory bandwidth counters are per-process, **always run a single uvicorn worker** (`--workers 1`).
- **Bandwidth guard:** `MONTHLY_AUDIO_GB_GLOBAL` defaults to `1500` GB (~30%). Streamed bytes are accumulated in memory and flushed to `audio_usage` every 15 seconds and on clean shutdown. A warning is logged once global usage crosses 80% of the monthly cap.
- **Backups:** Run `python -m app.tools.backup` from `backend/` (with `.venv` activated) to create a consistent online SQLite snapshot under `./backups/music-YYYYmmdd-HHMMSS.db` (mode `600`), pruning to the newest 7 snapshots by default (`--keep N`).
- **Moving to Postgres later:** Database access uses SQLAlchemy 2.x async and Alembic (`render_as_batch=True`). Update `DATABASE_URL` to a `postgresql+asyncpg://...` URL and run `alembic upgrade head`.

---

## Manual steps for the owner

1. **Generate `APP_JWT_SECRET`:**
   ```powershell
   python -c "import secrets; print(secrets.token_urlsafe(48))"
   ```
2. **Create `backend/.env` and choose an invite code:**
   ```powershell
   copy backend\.env.example backend\.env
   # Edit backend/.env: set APP_JWT_SECRET, REGISTRATION_INVITE_CODE, and CORS_ORIGINS
   ```
3. **Run Alembic migrations on the real database:**
   ```powershell
   cd backend
   .venv\Scripts\python -m alembic upgrade head
   ```
4. **Schedule daily SQLite backups (Windows Task Scheduler or cron on Linux):**
   ```powershell
   # Example: add to Windows Task Scheduler or run manually
   cd backend && .venv\Scripts\python -m app.tools.backup
   ```
5. **Configure reverse proxy (Nginx) and TLS:**
   Proxy your domain over HTTPS to `http://127.0.0.1:8610`, pass `X-Forwarded-For` / `X-Real-IP` (and set `TRUST_FORWARDED_FOR=true` in `backend/.env` if proxied), and disable response buffering (`proxy_buffering off;`) for `/audio/`.
6. **Confirm port `8610` is not reachable from outside:**
   Verify that only `127.0.0.1:8610` is bound and that your firewall blocks direct external access to port `8610`.
7. **YouTube `yt-dlp` datacenter IP notice:**
   YouTube may return `"Sign in to confirm you're not a bot"` or `403` on datacenter IPs. For private use if blocked, consider routing `yt-dlp` through a residential egress/VPN or providing a cookies file outside git.
8. **Export Figma frames for closer visual fidelity:**
   Export key Figma frames (`Listen Now`, `Browse`, `Library`, `Search`, `Now Playing`, `Mini Player`) as PNGs into `design-reference/` if you want future phases to refine pixel details against the Figma kit.
9. **Build Flutter for Android on a machine with Android SDK:**
   ```powershell
   cd client
   flutter build apk --debug
   # or for release:
   flutter build apk --release --dart-define=API_URL=http://your-server:8610
   ```
   Test background playback, lock-screen metadata, and remote controls on a physical device.
11. **Phase 3 VPS Database Migration & Upgrade:**
    When deploying Phase 3 to your VPS:
    ```bash
    # 1. Backup existing database
    cd /home/music/app/backend
    .venv/bin/python -m app.tools.backup

    # 2. Pull latest code
    git pull origin main

    # 3. Run database migration (0002_user_data)
    .venv/bin/alembic upgrade head

    # 4. Restart the music backend however it is started on your VPS
    ```
12. **Phase 3 Client Silent Login & Testing:**
    Create `client/dart_defines.json` (strictly gitignored) based on `client/dart_defines.example.json`:
    ```json
    {
      "API_URL": "http://127.0.0.1:8610",
      "APP_NAME": "Melodia",
      "LOCAL_EMAIL": "your-account@example.com",
      "LOCAL_PASSWORD": "YourStrongPassword123!"
    }
    ```
    For local web testing:
    ```powershell
    cd client
    flutter run -d chrome --web-port 8611 --dart-define-from-file=dart_defines.json
    ```
    For local desktop testing:
    ```powershell
    cd client
    flutter run -d windows --dart-define-from-file=dart_defines.json
    ```
