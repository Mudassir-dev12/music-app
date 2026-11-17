#!/usr/bin/env bash
# deploy/tests/render_test.sh - Render-only mode tests for Melodia deploy kit
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TEST_TMP="${REPO_ROOT}/.tmp/render_test_$$"
mkdir -p "${TEST_TMP}"

cleanup() {
    rm -rf "${TEST_TMP}"
}
trap cleanup EXIT

echo "=== Running Deploy Kit Render Tests ==="

RENDER_DIR="${TEST_TMP}/rendered_1"
mkdir -p "${RENDER_DIR}"

# 1. Run install in render-only mode
echo "Running install.sh --render-only..."
bash "${REPO_ROOT}/deploy/install.sh" \
    --domain "music-api.example.com" \
    --email "admin@example.com" \
    --port 8610 \
    --user "melodia" \
    --root "/var/www/music-app" \
    --render-only "${RENDER_DIR}"

# 2. Check service file
SERVICE_FILE="${RENDER_DIR}/etc/systemd/system/melodia-backend.service"
if [[ ! -f "${SERVICE_FILE}" ]]; then
    echo "FAIL: Service file was not rendered!" >&2
    exit 1
fi

echo "Checking melodia-backend.service contents..."
grep -q "User=melodia" "${SERVICE_FILE}" || { echo "FAIL: User=melodia missing in service file"; exit 1; }
grep -q "ExecStart=/var/www/music-app/backend/.venv/bin/python -m uvicorn app.main:app" "${SERVICE_FILE}" || { echo "FAIL: ExecStart path invalid in service file"; exit 1; }
grep -q "Restart=always" "${SERVICE_FILE}" || { echo "FAIL: Restart=always missing in service file"; exit 1; }

# Assert every path in ReadWritePaths is prepared
RW_LINE=$(grep "^ReadWritePaths=" "${SERVICE_FILE}")
for expected_path in "/var/www/music-app/data" "/var/www/music-app/backups" "/var/www/music-app/.tmp" "/var/www/music-app/.home" "/var/www/music-app/.cache"; do
    if [[ "${RW_LINE}" != *"${expected_path}"* ]]; then
        echo "FAIL: Expected path ${expected_path} missing from ReadWritePaths!" >&2
        exit 1
    fi
done
echo "PASS: melodia-backend.service validated."

# 3. Check Nginx files
NGINX_SITE="${RENDER_DIR}/etc/nginx/sites-available/music-api.conf"
NGINX_LIMITS="${RENDER_DIR}/etc/nginx/conf.d/melodia-limits.conf"

echo "Checking Nginx site and limits configuration..."
[[ -f "${NGINX_SITE}" ]] || { echo "FAIL: Nginx site file not found!"; exit 1; }
[[ -f "${NGINX_LIMITS}" ]] || { echo "FAIL: Nginx limits file not found!"; exit 1; }

# Nginx site must contain domain and port and no other server_name
grep -q "server_name music-api.example.com;" "${NGINX_SITE}" || { echo "FAIL: server_name missing in nginx site"; exit 1; }
grep -q "proxy_pass http://127.0.0.1:8610;" "${NGINX_SITE}" || { echo "FAIL: proxy_pass missing in nginx site"; exit 1; }
grep -q "proxy_buffering off;" "${NGINX_SITE}" || { echo "FAIL: proxy_buffering off missing"; exit 1; }

# Ensure no other server_name exists
SN_COUNT=$(grep -c "server_name " "${NGINX_SITE}" || true)
if [[ "${SN_COUNT}" -ne 1 ]]; then
    echo "FAIL: Found unexpected extra server_name entries (${SN_COUNT})!" >&2
    exit 1
fi

# Limits file defines both zones
grep -q "zone=melodia_auth:2m rate=10r/m;" "${NGINX_LIMITS}" || { echo "FAIL: zone=melodia_auth missing in limits"; exit 1; }
grep -q "zone=melodia_api:5m rate=300r/m;" "${NGINX_LIMITS}" || { echo "FAIL: zone=melodia_api missing in limits"; exit 1; }
echo "PASS: Nginx configuration validated."

# 4. Check manifest lists every rendered file
MANIFEST="${RENDER_DIR}/manifest"
[[ -f "${MANIFEST}" ]] || { echo "FAIL: Manifest file not created!"; exit 1; }

while IFS= read -r f || [[ -n "$f" ]]; do
    [[ -z "$f" ]] && continue
    if [[ ! -e "$f" && ! -L "$f" ]]; then
        echo "FAIL: Manifest entry does not exist: $f" >&2
        exit 1
    fi
done < "${MANIFEST}"
echo "PASS: Manifest file accurately lists rendered files."

# 5. Check idempotence (running render twice produces identical files)
RENDER_DIR_2="${TEST_TMP}/rendered_2"
bash "${REPO_ROOT}/deploy/install.sh" \
    --domain "music-api.example.com" \
    --email "admin@example.com" \
    --port 8610 \
    --user "melodia" \
    --root "/var/www/music-app" \
    --render-only "${RENDER_DIR_2}"

# Compare rendered configs (excluding manifest which contains absolute paths to unique dirs)
diff -r -u -x manifest "${RENDER_DIR}" "${RENDER_DIR_2}" || { echo "FAIL: Render output is not idempotent!"; exit 1; }

# Re-running into same directory produces identical manifest and files
MANIFEST_BEFORE=$(cat "${RENDER_DIR_2}/manifest")
bash "${REPO_ROOT}/deploy/install.sh" \
    --domain "music-api.example.com" \
    --email "admin@example.com" \
    --port 8610 \
    --user "melodia" \
    --root "/var/www/music-app" \
    --render-only "${RENDER_DIR_2}"
MANIFEST_AFTER=$(cat "${RENDER_DIR_2}/manifest")
[[ "${MANIFEST_BEFORE}" == "${MANIFEST_AFTER}" ]] || { echo "FAIL: In-place re-render manifest differs!"; exit 1; }
echo "PASS: Render output is idempotent."

# 6. Check uninstall in render-only mode
echo "Testing uninstall in render-only mode..."
bash "${REPO_ROOT}/deploy/uninstall.sh" --render-only "${RENDER_DIR}" --apply

# Verify rendered files were removed
if [[ -f "${SERVICE_FILE}" || -f "${NGINX_SITE}" || -f "${NGINX_LIMITS}" ]]; then
    echo "FAIL: Files still exist after uninstall!" >&2
    exit 1
fi
echo "PASS: Uninstall cleanly removed manifest-tracked files."

# 7. Check that a broken template causes failure
echo "Testing failure detection on broken template..."
BROKEN_TMPL="${TEST_TMP}/broken.tmpl"
echo "Some text with {{UNREPLACED_VARIABLE}}" > "${BROKEN_TMPL}"

# shellcheck source=deploy/lib.sh
source "${REPO_ROOT}/deploy/lib.sh"
if render_template "${BROKEN_TMPL}" "${TEST_TMP}/broken_out.txt" "PORT=8000" 2>/dev/null; then
    echo "FAIL: render_template should have failed on unreplaced variable!" >&2
    exit 1
fi
echo "PASS: Broken template correctly triggers failure."

echo ""
echo "=== All deploy render tests PASSED! ==="
