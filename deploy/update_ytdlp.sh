#!/usr/bin/env bash
# deploy/update_ytdlp.sh - Safe updater for yt-dlp with rollback
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/lib.sh
source "${SCRIPT_DIR}/lib.sh"

ROOT="/var/www/music-app"
USER="melodia"
APPLY=0

usage() {
    cat <<EOF
Usage: sudo bash deploy/update_ytdlp.sh [OPTIONS]

Options:
  --root DIR            Repository root path (default: /var/www/music-app)
  --user USER           Service user (default: melodia)
  --apply               Execute changes (default is dry-run)
  -h, --help            Show this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        --user) USER="$2"; shift 2 ;;
        --apply) APPLY=1; shift ;;
        -h|--help) usage ;;
        *) log_err "Unknown argument: $1"; exit 1 ;;
    esac
done

VENV_PYTHON="${ROOT}/backend/.venv/bin/python"
if [[ ! -x "${VENV_PYTHON}" && -x "${ROOT}/backend/.venv/Scripts/python.exe" ]]; then
    VENV_PYTHON="${ROOT}/backend/.venv/Scripts/python.exe"
fi
if [[ ! -x "${VENV_PYTHON}" ]]; then
    log_err "Python executable not found at: ${VENV_PYTHON}"
    exit 1
fi

CURRENT_VER=$("${VENV_PYTHON}" -m yt_dlp --version 2>/dev/null || echo "unknown")
log_info "Current yt-dlp version: ${CURRENT_VER}"

if [[ "${APPLY}" -eq 1 ]]; then
    log_info "Updating yt-dlp in virtual environment..."
    su -s /bin/bash "${USER}" -c "${VENV_PYTHON} -m pip install -U yt-dlp"

    NEW_VER=$("${VENV_PYTHON}" -m yt_dlp --version 2>/dev/null || echo "unknown")
    log_info "Installed yt-dlp version: ${NEW_VER}"

    # Run stream self-test
    log_info "Running audio stream self-test (app.tools.selftest_stream)..."
    if su -s /bin/bash "${USER}" -c "cd ${ROOT}/backend && ${VENV_PYTHON} -m app.tools.selftest_stream"; then
        log_info "Stream resolution self-test PASSED!"
        if [[ "${CURRENT_VER}" != "${NEW_VER}" ]]; then
            log_info "yt-dlp upgraded from ${CURRENT_VER} to ${NEW_VER}. Restarting melodia-backend..."
            systemctl restart melodia-backend
        else
            log_info "yt-dlp was already at the latest version. Service restart not needed."
        fi
    else
        log_err "Stream resolution self-test FAILED with new yt-dlp version! Rolling back to ${CURRENT_VER}..."
        su -s /bin/bash "${USER}" -c "${VENV_PYTHON} -m pip install yt-dlp==${CURRENT_VER}"
        log_err "Rolled back yt-dlp to version ${CURRENT_VER}."
        exit 1
    fi
else
    log_plan "Would execute: su -s /bin/bash ${USER} -c '${VENV_PYTHON} -m pip install -U yt-dlp'"
    log_plan "Would run self-test: su -s /bin/bash ${USER} -c '${VENV_PYTHON} -m app.tools.selftest_stream'"
    log_plan "Would restart melodia-backend if version changed and test passed"
    log_plan "Would roll back to ${CURRENT_VER} if self-test failed"
fi
