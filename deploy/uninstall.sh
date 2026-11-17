#!/usr/bin/env bash
# deploy/uninstall.sh - Melodia VPS uninstallation script
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/lib.sh
source "${SCRIPT_DIR}/lib.sh"

ROOT="/var/www/music-app"
APPLY=0
RENDER_ONLY=""

usage() {
    cat <<EOF
Usage: sudo bash deploy/uninstall.sh [OPTIONS]

Options:
  --root DIR            Repository root path (default: /var/www/music-app)
  --render-only DIR     Run uninstaller in simulation mode against DIR
  --apply               Execute changes (default is dry-run)
  -h, --help            Show this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        --render-only) RENDER_ONLY="$2"; shift 2 ;;
        --apply) APPLY=1; shift ;;
        -h|--help) usage ;;
        *) log_err "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -n "${RENDER_ONLY}" ]]; then
    MANIFEST_FILE="${RENDER_ONLY}/manifest"
else
    MANIFEST_FILE="${ROOT}/deploy/.installed.manifest"
fi

if [[ ! -f "${MANIFEST_FILE}" ]]; then
    log_err "Manifest file not found: ${MANIFEST_FILE}"
    echo "Nothing to uninstall or install.sh was never run."
    exit 1
fi

log_info "Reading installed files from ${MANIFEST_FILE}..."

# 1. Stop and disable services
if [[ "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
    log_info "Stopping and disabling systemd units..."
    systemctl stop melodia-health.timer 2>/dev/null || true
    systemctl disable melodia-health.timer 2>/dev/null || true
    systemctl stop melodia-backend 2>/dev/null || true
    systemctl disable melodia-backend 2>/dev/null || true
else
    log_plan "Would stop and disable melodia-health.timer and melodia-backend.service"
fi

# 2. Remove files listed in manifest
NGINX_FILES_REMOVED=0
while IFS= read -r file_path || [[ -n "${file_path}" ]]; do
    [[ -z "${file_path}" ]] && continue
    if [[ -f "${file_path}" || -L "${file_path}" ]]; then
        if [[ "${file_path}" == *"/nginx/"* ]]; then
            NGINX_FILES_REMOVED=1
        fi
        if [[ -n "${RENDER_ONLY}" || "${APPLY}" -eq 1 ]]; then
            rm -f "${file_path}"
            log_info "Removed: ${file_path}"
        else
            log_plan "Would remove: ${file_path}"
        fi
    else
        log_info "Already absent: ${file_path}"
    fi
done < "${MANIFEST_FILE}"

# 3. Reload Nginx and systemd if applicable
if [[ "${APPLY}" -eq 1 && -z "${RENDER_ONLY}" ]]; then
    systemctl daemon-reload
    if [[ "${NGINX_FILES_REMOVED}" -eq 1 ]] && command -v nginx >/dev/null 2>&1; then
        log_info "Testing Nginx configuration (nginx -t)..."
        if nginx -t; then
            log_info "Reloading Nginx..."
            systemctl reload nginx
        else
            log_warn "Nginx test failed after file removal. Please verify /etc/nginx configuration."
        fi
    fi
    rm -f "${MANIFEST_FILE}"
    log_info "Uninstalled manifest removed."
elif [[ -n "${RENDER_ONLY}" ]]; then
    rm -f "${MANIFEST_FILE}"
    log_info "Render-only manifest removed."
fi

echo ""
echo "============================================================"
echo "          Melodia Backend Uninstallation Complete"
echo "============================================================"
echo "Project files and database (data/music.db) have been kept intact."
echo "If you wish to remove the system user as well, run:"
echo "   sudo userdel melodia"
echo "============================================================"

