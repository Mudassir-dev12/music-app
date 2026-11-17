#!/usr/bin/env bash
# deploy/deploy.sh - Melodia automated update script with rollback guard
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/lib.sh
source "${SCRIPT_DIR}/lib.sh"

ROOT="/var/www/music-app"
REF="main"
PORT=8610
USER="melodia"
APPLY=0

usage() {
    cat <<EOF
Usage: sudo bash deploy/deploy.sh [OPTIONS]

Options:
  --root DIR            Repository root path (default: /var/www/music-app)
  --ref BRANCH/TAG      Git branch or tag to deploy (default: main)
  --port PORT           Internal backend port (default: 8610)
  --user USER           Service user (default: melodia)
  --apply               Execute changes (default is dry-run)
  -h, --help            Show this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        --ref) REF="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --user) USER="$2"; shift 2 ;;
        --apply) APPLY=1; shift ;;
        -h|--help) usage ;;
        *) log_err "Unknown argument: $1"; exit 1 ;;
    esac
done

cd "${ROOT}"

# 1. Check working tree is clean
log_info "Step 1: Checking git working tree status..."
if ! git diff --quiet || ! git diff --staged --quiet; then
    log_err "Working tree at ${ROOT} is not clean. Aborting deployment."
    exit 1
fi

VENV_PYTHON="${ROOT}/backend/.venv/bin/python"
if [[ ! -x "${VENV_PYTHON}" && -x "${ROOT}/backend/.venv/Scripts/python.exe" ]]; then
    VENV_PYTHON="${ROOT}/backend/.venv/Scripts/python.exe"
fi

# 2. Run backup tool as service user
log_info "Step 2: Creating database backup before deployment..."
if [[ "${APPLY}" -eq 1 ]]; then
    BACKUP_OUT=$(su -s /bin/bash "${USER}" -c "cd ${ROOT}/backend && ${VENV_PYTHON} -m app.tools.backup" || true)
    echo "${BACKUP_OUT}"
else
    log_plan "Would execute database backup via: su -s /bin/bash ${USER} -c '${VENV_PYTHON} -m app.tools.backup'"
fi

# 3. Record current commit
OLD_COMMIT=$(git rev-parse HEAD)
log_info "Current commit: ${OLD_COMMIT}"

# 4. Pull latest changes
if [[ "${APPLY}" -eq 1 ]]; then
    log_info "Step 3: Pulling changes from origin/${REF}..."
    git pull --ff-only origin "${REF}"
    NEW_COMMIT=$(git rev-parse HEAD)
    log_info "Updated to commit: ${NEW_COMMIT}"

    # 5. Check if dependencies changed
    if git diff --name-only "${OLD_COMMIT}" "${NEW_COMMIT}" | grep -E -q "backend/requirements"; then
        log_info "Step 4: Requirements changed. Updating virtual environment dependencies..."
        "${ROOT}/backend/.venv/bin/pip" install -r "${ROOT}/backend/requirements.txt"
    else
        log_info "Step 4: Dependencies unchanged."
    fi

    # 6. Apply database migrations
    log_info "Step 5: Applying database migrations..."
    su -s /bin/bash "${USER}" -c "cd ${ROOT}/backend && ${VENV_PYTHON} -m alembic upgrade head"

    # 7. Restart melodia-backend service
    log_info "Step 6: Restarting melodia-backend service..."
    systemctl restart melodia-backend

    # 8. Readiness health check with automatic rollback
    log_info "Step 7: Verifying readiness endpoint (http://127.0.0.1:${PORT}/ready)..."
    READY_OK=0
    for i in {1..30}; do
        if curl -fsS -m 2 "http://127.0.0.1:${PORT}/ready" >/dev/null 2>&1; then
            READY_OK=1
            break
        fi
        sleep 1
    done

    if [[ "${READY_OK}" -eq 1 ]]; then
        log_info "Deployment succeeded! Backend is healthy and ready on commit ${NEW_COMMIT}."
    else
        log_err "Readiness check failed after 30 seconds! Rolling back to ${OLD_COMMIT}..."
        git checkout "${OLD_COMMIT}"
        systemctl restart melodia-backend
        log_err "============================================================"
        log_err "CRITICAL: Deployment failed. Code has been rolled back to ${OLD_COMMIT}."
        log_err "The database backup was created before migration."
        log_err "If database downgrade is required, inspect the backup file or run:"
        log_err "  cd ${ROOT}/backend && ${VENV_PYTHON} -m alembic downgrade <previous_revision>"
        log_err "============================================================"
        exit 1
    fi
else
    log_plan "Would git pull --ff-only origin ${REF}"
    log_plan "Would run alembic upgrade head"
    log_plan "Would restart melodia-backend and poll /ready for 30s"
    log_plan "Would automatically rollback git commit if /ready fails"
fi
