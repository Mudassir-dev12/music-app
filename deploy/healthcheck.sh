#!/usr/bin/env bash
# deploy/healthcheck.sh - Watchdog for Melodia backend health
set -Eeuo pipefail

PORT=8610
COUNTER_FILE="/run/melodia-health.count"

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            PORT="$2"
            shift 2
            ;;
        --counter-file)
            COUNTER_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Fallback counter directory if /run is not writable
if [[ ! -w "$(dirname "${COUNTER_FILE}")" ]]; then
    COUNTER_FILE="${TMPDIR:-/tmp}/melodia-health.count"
fi

URL="http://127.0.0.1:${PORT}/health"
COUNT=0
if [[ -f "${COUNTER_FILE}" ]]; then
    COUNT=$(cat "${COUNTER_FILE}" 2>/dev/null || echo 0)
fi

# Check /health endpoint with 5 second timeout
if curl -fsS -m 5 "${URL}" >/dev/null 2>&1; then
    # Health check succeeded; reset counter
    if [[ "${COUNT}" -ne 0 ]]; then
        echo 0 > "${COUNTER_FILE}" 2>/dev/null || true
    fi
    exit 0
else
    # Health check failed
    COUNT=$((COUNT + 1))
    echo "${COUNT}" > "${COUNTER_FILE}" 2>/dev/null || true

    if command -v logger >/dev/null 2>&1; then
        logger -t melodia-health "Health check failed (attempt ${COUNT}/3) for ${URL}"
    fi

    if [[ "${COUNT}" -ge 3 ]]; then
        if command -v logger >/dev/null 2>&1; then
            logger -t melodia-health "Melodia backend failed 3 consecutive health checks. Restarting melodia-backend..."
        fi
        echo 0 > "${COUNTER_FILE}" 2>/dev/null || true
        # Restart melodia-backend ONLY
        systemctl restart melodia-backend
    fi
    exit 1
fi
