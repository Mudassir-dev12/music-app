#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Source environment guard
# shellcheck source=/dev/null
source "$SCRIPT_DIR/env.sh"

echo "=========================================="
echo " Starting Melodia Smoke Test with Real Net"
echo "=========================================="

# 2. Pick a free port
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
echo "Selected free port: $PORT"

# 3. Setup temporary throwaway database
TMP_DB="$ROOT/.tmp/smoke_test_$$.db"
export DATABASE_URL="sqlite+aiosqlite:///$TMP_DB"
export APP_ENV="development"
export APP_JWT_SECRET=$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')
export REGISTRATION_INVITE_CODE="INVITE_$(python3 -c 'import secrets; print(secrets.token_hex(6))')"
export REDIS_URL=""
export DAILY_AUDIO_MB_PER_USER=1500
export MONTHLY_AUDIO_GB_GLOBAL=1500
export CORS_ORIGINS="http://localhost:8081"

echo "Applying Alembic migrations to throwaway database..."
(
    cd "$ROOT/backend"
    "$ROOT/backend/.venv/bin/python3" -m alembic upgrade head >/dev/null 2>&1
)

# 4. Start backend server
echo "Starting backend server on 127.0.0.1:$PORT..."
(
    cd "$ROOT/backend"
    exec "$ROOT/backend/.venv/bin/python3" -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT" --log-level warning
) &
SERVER_PID=$!

cleanup() {
    echo "Stopping test server (PID: $SERVER_PID)..."
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    rm -f "$TMP_DB" "$TMP_DB-wal" "$TMP_DB-shm"
    echo "Cleaned up test database and processes."
}
trap cleanup EXIT INT TERM

# Wait for server to become responsive
READY=0
for i in {1..30}; do
    if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 0.5
done

if [ "$READY" -ne 1 ]; then
    echo "FAIL: Server failed to start within 15 seconds"
    exit 1
fi

echo "Server is ready. Running checks..."

# Run test runner python script against the live server
"$ROOT/backend/.venv/bin/python3" - <<EOF
import sys
import time
import httpx

base_url = "http://127.0.0.1:$PORT"
invite_code = "$REGISTRATION_INVITE_CODE"

def report(check_num, desc, passed, extra=""):
    status = "PASS" if passed else "FAIL"
    print(f"Check {check_num:2d} [{status}]: {desc} {extra}")
    if not passed:
        sys.exit(1)

with httpx.Client(base_url=base_url, timeout=30.0) as client:
    # 1. GET /health
    r1 = client.get("/health")
    data1 = r1.json()
    p1 = (r1.status_code == 200 and data1.get("cache") == "memory" and data1.get("db") == "ok")
    report(1, "GET /health -> 200, cache: memory, db: ok", p1)

    # 2. POST /auth/register
    email = "smoke_user@example.com"
    # Weak password -> 422
    r_weak = client.post("/auth/register", json={"email": email, "password": "weak"})
    p_weak = (r_weak.status_code == 422)

    # Wrong invite code -> 403
    r_wrong_inv = client.post("/auth/register", json={"email": email, "password": "ValidPassword123!", "invite_code": "WRONG"})
    p_wrong_inv = (r_wrong_inv.status_code == 403)

    # Correct register -> 201
    r_reg = client.post("/auth/register", json={"email": email, "password": "ValidPassword123!", "invite_code": invite_code})
    p_reg = (r_reg.status_code == 201)
    reg_data = r_reg.json()
    access_token = reg_data.get("access_token")
    refresh_token = reg_data.get("refresh_token")

    # Same email again -> 409
    r_dup = client.post("/auth/register", json={"email": email, "password": "ValidPassword123!", "invite_code": invite_code})
    p_dup = (r_dup.status_code == 409)

    report(2, "POST /auth/register validation (weak=422, wrong_code=403, ok=201, dup=409)", (p_weak and p_wrong_inv and p_reg and p_dup))

    # 3. POST /auth/login
    r_wrong_pwd = client.post("/auth/login", json={"email": email, "password": "WrongPassword123!"})
    p_wrong_pwd = (r_wrong_pwd.status_code == 401)

    r_login = client.post("/auth/login", json={"email": email, "password": "ValidPassword123!"})
    p_login = (r_login.status_code == 200 and "access_token" in r_login.json() and "refresh_token" in r_login.json())
    login_data = r_login.json()
    access_token = login_data["access_token"]
    refresh_token = login_data["refresh_token"]

    report(3, "POST /auth/login (wrong_pwd=401, correct=200 with tokens)", (p_wrong_pwd and p_login))

    # 4. GET /me
    r_no_tok = client.get("/me")
    p_no_tok = (r_no_tok.status_code == 401)

    r_me = client.get("/me", headers={"Authorization": f"Bearer {access_token}"})
    p_me = (r_me.status_code == 200 and r_me.json().get("email") == email)
    report(4, "GET /me (without token=401, with token=200)", (p_no_tok and p_me))

    # 5. POST /auth/refresh
    r_ref = client.post("/auth/refresh", json={"refresh_token": refresh_token})
    p_ref = (r_ref.status_code == 200)
    new_data = r_ref.json()
    old_refresh = refresh_token
    access_token = new_data["access_token"]
    refresh_token = new_data["refresh_token"]

    # Old token now fails
    time.sleep(0.1)
    r_old_ref = client.post("/auth/refresh", json={"refresh_token": old_refresh})
    p_old_fail = (r_old_ref.status_code == 401)
    report(5, "POST /auth/refresh (rotation succeeds, old token fails with 401)", (p_ref and p_old_fail))

    auth_headers = {"Authorization": f"Bearer {access_token}"}

    # 6. GET /search?q=believer imagine dragons&limit=5
    t0 = time.perf_counter()
    r_s1 = client.get("/search?q=believer imagine dragons&limit=5", headers=auth_headers)
    dur1 = time.perf_counter() - t0

    p_s1 = (r_s1.status_code == 200)
    res_list = r_s1.json().get("results", [])
    p_s_valid = len(res_list) >= 1 and len(res_list) <= 5
    first_track = res_list[0] if res_list else {}
    target_vid = first_track.get("video_id")
    p_vid_len = (target_vid and len(target_vid) == 11)
    p_meta = bool(first_track.get("title") and first_track.get("artist") and first_track.get("thumbnail"))

    # Repeat search to verify cache speedup
    t1 = time.perf_counter()
    r_s2 = client.get("/search?q=believer imagine dragons&limit=5", headers=auth_headers)
    dur2 = time.perf_counter() - t1

    report(6, "GET /search (returns 1-5 results with 11-char ID; second call cached)", 
           (p_s1 and p_s_valid and p_vid_len and p_meta and dur2 <= dur1),
           f"(call1={dur1*1000:.1f}ms, call2={dur2*1000:.1f}ms)")

    # 7. GET /track/{id}
    r_track = client.get(f"/track/{target_vid}", headers=auth_headers)
    p_track = (r_track.status_code == 200 and r_track.json().get("video_id") == target_vid)
    report(7, f"GET /track/{target_vid} -> 200", p_track)

    # 7b. POST /audio/{id}/ticket -> 200 and mismatched video_id with ticket -> 401
    r_ticket = client.post(f"/audio/{target_vid}/ticket", headers=auth_headers)
    ticket_data = r_ticket.json() if r_ticket.status_code == 200 else {}
    ticket_url = ticket_data.get("url", "")
    other_vid = "aaaaaaaaaaa" if target_vid != "aaaaaaaaaaa" else "bbbbbbbbbbb"
    ticket_q = ticket_url.split("?", 1)[1] if "?" in ticket_url else ""
    r_ticket_mismatch = client.get(f"/audio/{other_vid}?{ticket_q}") if ticket_q else None
    p_ticket = (
        r_ticket.status_code == 200
        and ticket_url.startswith(f"/audio/{target_vid}?t=")
        and ticket_data.get("expires_in", 0) > 0
        and r_ticket_mismatch is not None
        and r_ticket_mismatch.status_code == 401
    )
    report(8, f"POST /audio/{target_vid}/ticket -> 200 & wrong video_id -> 401", p_ticket)

    # 8. GET /audio/{id} with Range: bytes=0-1023
    r_audio = client.get(f"/audio/{target_vid}", headers={**auth_headers, "Range": "bytes=0-1023"})
    p_a_status = (r_audio.status_code == 206)
    p_a_cr = ("content-range" in r_audio.headers)
    ct = r_audio.headers.get("content-type", "")
    p_a_ct = ct.startswith("audio/")
    p_a_len = (len(r_audio.content) == 1024)
    # Check ftyp if MP4
    p_ftyp = True
    if "mp4" in ct:
        p_ftyp = (r_audio.content[4:8] == b"ftyp")

    report(9, f"GET /audio/{target_vid} Range: bytes=0-1023 (status=206, len=1024, audio type, ftyp check)", 
           (p_a_status and p_a_cr and p_a_ct and p_a_len and p_ftyp))

    # 9b. GET {ticket_url} with Range: bytes=0-1023 and NO Authorization header -> 206, 1024 bytes
    r_ticket_audio = client.get(ticket_url, headers={"Range": "bytes=0-1023"})
    p_ta = (
        r_ticket_audio.status_code == 206
        and len(r_ticket_audio.content) == 1024
        and r_ticket_audio.headers.get("referrer-policy") == "no-referrer"
    )
    report(10, f"GET {target_vid}?t=<ticket> Range: bytes=0-1023 (no Auth header -> 206, 1024 bytes)", p_ta)

    # 9. GET /audio/{id} with Range: bytes=1000000-1000999 (seeking)
    r_seek = client.get(f"/audio/{target_vid}", headers={**auth_headers, "Range": "bytes=1000000-1000999"})
    p_seek = (r_seek.status_code == 206 and len(r_seek.content) == 1000)
    report(11, f"GET /audio/{target_vid} Range: bytes=1000000-1000999 (seeking -> 206)", p_seek)

    # 10. HEAD /audio/{id} -> 200 with Accept-Ranges
    r_head = client.head(f"/audio/{target_vid}", headers=auth_headers)
    p_head = (r_head.status_code == 200 and r_head.headers.get("accept-ranges") == "bytes")
    report(12, f"HEAD /audio/{target_vid} -> 200 with Accept-Ranges: bytes", p_head)

    # 11. Usage flush & check
    print("Waiting 16 seconds for background bandwidth flush...")
    time.sleep(16)
    r_usage = client.get("/me/usage", headers=auth_headers)
    p_usage = (r_usage.status_code == 200 and r_usage.json().get("today_bytes", 0) > 0)
    report(13, "GET /me/usage shows today_bytes > 0 after background flush", p_usage, f"({r_usage.json().get('today_bytes')} bytes)")

    # 12. CORS preflight
    r_cors = client.options("/search", headers={
        "Origin": "http://localhost:8081",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "authorization,range"
    })
    p_cors = ("access-control-allow-origin" in r_cors.headers)
    report(14, "CORS preflight for http://localhost:8081 allowed", p_cors)

    # 13. Malformed video id -> 400
    r_bad_vid = client.get("/audio/not-a-valid-id", headers=auth_headers)
    p_bad_vid = (r_bad_vid.status_code == 400)
    report(15, "GET /audio/not-a-valid-id -> 400", p_bad_vid)

    # --- Phase 3 User Data Checks ---
    # 14. Like track & check liked ids
    r_like = client.put(f"/me/likes/{target_vid}", headers=auth_headers)
    r_likes_ids = client.get("/me/likes/ids", headers=auth_headers)
    p_like = (r_like.status_code == 204 and r_likes_ids.status_code == 200 and target_vid in r_likes_ids.json().get("ids", []))
    report(16, f"PUT /me/likes/{target_vid} -> 204 & GET /me/likes/ids contains track", p_like)

    # 15. Create playlist, add track & read back
    r_pl_create = client.post("/me/playlists", headers=auth_headers, json={"name": "Smoke Playlist", "description": "Smoke check"})
    pl_id = r_pl_create.json().get("id") if r_pl_create.status_code == 201 else None
    r_pl_add = client.post(f"/me/playlists/{pl_id}/tracks", headers=auth_headers, json={"video_ids": [target_vid]}) if pl_id else None
    r_pl_get = client.get(f"/me/playlists/{pl_id}", headers=auth_headers) if pl_id else None
    p_playlist = (
        r_pl_create.status_code == 201
        and r_pl_add.status_code == 200
        and r_pl_add.json().get("added") == 1
        and r_pl_get.status_code == 200
        and r_pl_get.json().get("track_count") == 1
        and len(r_pl_get.json().get("tracks", {}).get("items", [])) == 1
    )
    report(17, f"POST /me/playlists -> 201, POST /me/playlists/{pl_id}/tracks -> 200, GET /me/playlists/{pl_id} verified", p_playlist)

    # 16. Log history entry twice with same client_event_id (idempotent: 201 then 200) & GET /me/recent
    ev_smoke = "smoke_ev_unique_01"
    r_hist1 = client.post("/me/history", headers=auth_headers, json={"video_id": target_vid, "listened_seconds": 35, "client_event_id": ev_smoke})
    r_hist2 = client.post("/me/history", headers=auth_headers, json={"video_id": target_vid, "listened_seconds": 35, "client_event_id": ev_smoke})
    r_recent = client.get("/me/recent", headers=auth_headers)
    p_history = (
        r_hist1.status_code == 201
        and r_hist2.status_code == 200
        and r_recent.status_code == 200
        and any(t.get("video_id") == target_vid for t in r_recent.json())
    )
    report(18, "POST /me/history idempotent (201 then 200) & GET /me/recent returns track", p_history)

    # 17. Logout and refresh fails
    r_logout = client.post("/auth/logout", json={"refresh_token": refresh_token})
    p_logout = (r_logout.status_code == 204)
    r_ref_after = client.post("/auth/refresh", json={"refresh_token": refresh_token})
    p_revoked = (r_ref_after.status_code == 401)
    report(19, "POST /auth/logout revokes token, subsequent refresh fails (401)", (p_logout and p_revoked))

print("\nAll 19 smoke tests PASSED successfully!")
EOF
